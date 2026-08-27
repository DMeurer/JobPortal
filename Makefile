.PHONY: help build up down logs restart clean migrate shell db-shell test

help: ## Show this help message
	@echo "Job Portal - Docker Management Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build all Docker containers
	docker compose build

up: ## Start all services in background
	docker compose up -d

down: ## Stop all services
	docker compose down

logs: ## Show logs from all services
	docker compose logs -f

restart: ## Restart all services
	docker compose restart

clean: ## Stop and remove all containers, networks, and volumes
	docker compose down -v

migrate: ## Run database migrations
	docker compose exec backend alembic upgrade head

migrate-create: ## Create a new migration (use MSG="description")
	docker compose exec backend alembic revision --autogenerate -m "$(MSG)"

shell: ## Open shell in backend container
	docker compose exec backend bash

db-shell: ## Open PostgreSQL shell
	docker compose exec postgres psql -U jobportal_user -d jobportal

status: ## Show status of all containers
	docker compose ps

rebuild: ## Rebuild and restart all services
	docker compose down
	docker compose build --no-cache
	docker compose up -d

dev: ## Start services in development mode (with logs)
	docker compose up

backup-db: ## Backup database to backup.sql
	docker compose exec postgres pg_dump -U jobportal_user jobportal > backup.sql
	@echo "Database backed up to backup.sql"

restore-db: ## Restore database from backup.sql
	docker compose exec -T postgres psql -U jobportal_user jobportal < backup.sql
	@echo "Database restored from backup.sql"

refresh-stats: ## Rebuild the statistics materialized view (safe to run any time)
	docker compose exec -T postgres psql -U jobportal_user -d jobportal \
		-c "REFRESH MATERIALIZED VIEW CONCURRENTLY company_date_statistics"
	@echo "Statistics refreshed"

rebuild-stats: ## Force a blocking rebuild of the statistics view (use if refresh-stats fails)
	docker compose exec -T postgres psql -U jobportal_user -d jobportal \
		-c "REFRESH MATERIALIZED VIEW company_date_statistics"
	@echo "Statistics rebuilt"

stats-status: ## Show statistics view row count and how current it is
	@docker compose exec -T postgres psql -U jobportal_user -d jobportal -c \
		"SELECT (SELECT count(*) FROM company_date_statistics) AS view_rows, \
		        (SELECT max(scrape_date) FROM company_date_statistics) AS view_latest, \
		        (SELECT max(scrape_date) FROM inserts) AS data_latest, \
		        CASE WHEN (SELECT max(scrape_date) FROM company_date_statistics) \
		                = (SELECT max(scrape_date) FROM inserts) \
		             THEN 'current' ELSE 'STALE - run make refresh-stats' END AS state"

test-backend: ## Run backend tests
	docker compose exec -T -e PYTHONPATH=/app -w /app backend python -m pytest tests -q

test-frontend: ## Run frontend tests
	cd Frontend && npm test -- --watch=false

test-api: ## Test API endpoints
	@echo "Testing API health..."
	curl http://localhost:8000/
	@echo "\n\nTesting companies endpoint..."
	curl http://localhost:8000/api/companies

run-scrapers: ## Run all scrapers manually
	docker compose exec runners python /app/main.py

run-scraper: ## Run specific scraper (use SCRAPER=name)
	docker compose exec runners python /app/main.py --scraper $(SCRAPER)

runner-logs: ## View runner logs
	docker compose logs -f runners

runner-shell: ## Open shell in runners container
	docker compose exec runners bash

runner-cron-status: ## View cron status and schedule
	docker compose exec runners crontab -l

runner-restart: ## Restart runners container
	docker compose restart runners

init: build up migrate ## Initialize project (build, start, migrate)
	@echo "Project initialized successfully!"
	@echo "API available at: http://localhost:8000"
	@echo "API docs at: http://localhost:8000/docs"
