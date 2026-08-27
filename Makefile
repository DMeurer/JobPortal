.PHONY: help build up down logs restart clean migrate shell db-shell test

# Run psql/pg_dump inside the postgres container using the credentials the
# container was actually started with. These targets used to hardcode
# `jobportal_user`, which fails with `role "jobportal_user" does not exist`
# whenever POSTGRES_USER in .env says otherwise. Reading them from the
# container's own environment cannot drift from how the database was created.
PSQL      = docker compose exec -T postgres sh -c 'exec psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'
PSQL_TTY  = docker compose exec postgres sh -c 'exec psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'
PG_DUMP   = docker compose exec -T postgres sh -c 'exec pg_dump -U "$$POSTGRES_USER" "$$POSTGRES_DB"'

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
	$(PSQL_TTY)

status: ## Show status of all containers
	docker compose ps

rebuild: ## Rebuild and restart all services
	docker compose down
	docker compose build --no-cache
	docker compose up -d

dev: ## Start services in development mode (with logs)
	docker compose up

backup-db: ## Backup database to backup.sql
	$(PG_DUMP) > backup.sql
	@echo "Database backed up to backup.sql"

restore-db: ## Restore database from backup.sql
	$(PSQL) < backup.sql
	@echo "Database restored from backup.sql"

refresh-stats: ## Rebuild the statistics materialized view (safe to run any time)
	@echo "REFRESH MATERIALIZED VIEW CONCURRENTLY company_date_statistics;" | $(PSQL)
	@echo "Statistics refreshed"

rebuild-stats: ## Force a blocking rebuild of the statistics view (use if refresh-stats fails)
	@echo "REFRESH MATERIALIZED VIEW company_date_statistics;" | $(PSQL)
	@echo "Statistics rebuilt"

stats-status: ## Show statistics view row count and how current it is
	@echo "SELECT (SELECT count(*) FROM company_date_statistics) AS view_rows, \
	              (SELECT max(scrape_date) FROM company_date_statistics) AS view_latest, \
	              (SELECT max(scrape_date) FROM inserts) AS data_latest, \
	              CASE WHEN (SELECT max(scrape_date) FROM company_date_statistics) \
	                        = (SELECT max(scrape_date) FROM inserts) \
	                   THEN 'current' ELSE 'STALE - run make refresh-stats' END AS state;" | $(PSQL)

test-backend: ## Run backend tests (creates and drops its own jobportal_test database)
	@docker compose exec -T backend sh -c \
		'python -m pytest --version >/dev/null 2>&1 || pip install --quiet pytest httpx'
	docker compose exec -T -w /app -e PYTHONPATH=/app backend sh -c \
		'TEST_DATABASE_URL="postgresql://$$DATABASE_USER:$$DATABASE_PASSWORD@$$DATABASE_HOST:$$DATABASE_PORT/postgres" \
		 python -m pytest tests -q'

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
