.PHONY: help build up down logs restart clean migrate shell db-shell test

help: ## Show this help message
	@echo "Job Portal - Docker Management Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build all Docker containers
	docker-compose build

up: ## Start all services in background
	docker-compose up -d

down: ## Stop all services
	docker-compose down

logs: ## Show logs from all services
	docker-compose logs -f

restart: ## Restart all services
	docker-compose restart

clean: ## Stop and remove all containers, networks, and volumes
	docker-compose down -v

migrate: ## Run database migrations
	docker-compose exec backend alembic upgrade head

migrate-create: ## Create a new migration (use MSG="description")
	docker-compose exec backend alembic revision --autogenerate -m "$(MSG)"

shell: ## Open shell in backend container
	docker-compose exec backend bash

db-shell: ## Open PostgreSQL shell
	docker-compose exec postgres psql -U jobportal_user -d jobportal

status: ## Show status of all containers
	docker-compose ps

rebuild: ## Rebuild and restart all services
	docker-compose down
	docker-compose build --no-cache
	docker-compose up -d

dev: ## Start services in development mode (with logs)
	docker-compose up

backup-db: ## Backup database to backup.sql
	docker-compose exec postgres pg_dump -U jobportal_user jobportal > backup.sql
	@echo "Database backed up to backup.sql"

restore-db: ## Restore database from backup.sql
	docker-compose exec -T postgres psql -U jobportal_user jobportal < backup.sql
	@echo "Database restored from backup.sql"

test-api: ## Test API endpoints
	@echo "Testing API health..."
	curl http://localhost:8000/
	@echo "\n\nTesting companies endpoint..."
	curl http://localhost:8000/api/companies

run-scrapers: ## Run all scrapers manually
	docker-compose exec runners python /app/main.py

run-scraper: ## Run specific scraper (use SCRAPER=name)
	docker-compose exec runners python /app/main.py --scraper $(SCRAPER)

runner-logs: ## View runner logs
	docker-compose logs -f runners

runner-shell: ## Open shell in runners container
	docker-compose exec runners bash

runner-cron-status: ## View cron status and schedule
	docker-compose exec runners crontab -l

runner-restart: ## Restart runners container
	docker-compose restart runners

init: build up migrate ## Initialize project (build, start, migrate)
	@echo "Project initialized successfully!"
	@echo "API available at: http://localhost:8000"
	@echo "API docs at: http://localhost:8000/docs"
