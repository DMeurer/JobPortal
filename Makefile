.PHONY: help build up down logs restart clean migrate shell db-shell test update

# Run psql/pg_dump inside the postgres container using the credentials the
# container was actually started with. These targets used to hardcode
# `jobportal_user`, which fails with `role "jobportal_user" does not exist`
# whenever POSTGRES_USER in .env says otherwise. Reading them from the
# container's own environment cannot drift from how the database was created.
PSQL      = docker compose exec -T postgres sh -c 'exec psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'
PSQL_TTY  = docker compose exec postgres sh -c 'exec psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'
PG_DUMP   = docker compose exec -T postgres sh -c 'exec pg_dump -U "$$POSTGRES_USER" "$$POSTGRES_DB"'

#=Getting Started
help: ## Show this help message
ifeq ($(OS),Windows_NT)
	@pwsh -NoProfile -Command "Write-Output 'Job Portal - Docker Management Commands'; Write-Output ''; Write-Output 'Usage: make [target]'; Write-Output ''; Write-Output 'Targets:'"
	@pwsh -NoProfile -Command "Get-Content -LiteralPath '$(firstword $(MAKEFILE_LIST))' | ForEach-Object { if ($$_ -match '^#=(.+)$$') { Write-Output ''; Write-Output ($$Matches[1] + ':'); } elseif ($$_ -match '^([a-zA-Z_-]+):.*## (.*)$$') { '  {0,-20} {1}' -f $$Matches[1], $$Matches[2] } }"
else
	@printf '%s\n\n' 'Job Portal - Docker Management Commands' 'Usage: make [target]'
	@printf '%s\n' 'Targets:'
	@awk '/^#=/ { print ""; printf "%s:\n", substr($$0, 3); next } /^[a-zA-Z_-]+:.*## / { split($$0, parts, /:.*## /); printf "  %-20s %s\n", parts[1], parts[2] }' $(MAKEFILE_LIST)
endif

init: build up migrate ## Initialize project (build, start, migrate)
	@echo "Project initialized successfully!"
	@echo "API available at: http://localhost:8000"
	@echo "API docs at: http://localhost:8000/docs"

#=Repository
update: ## Fast-forward the repository and update pinned submodules
	git pull --ff-only --recurse-submodules
	git submodule sync --recursive
	git submodule update --init --recursive

#=Service Management
build: ## Build all Docker containers
	docker compose build

clean: ## Stop and remove all containers, networks, and volumes
	docker compose down -v

dev: ## Start services in development mode (with logs)
	docker compose up

down: ## Stop all services
	docker compose down

logs: ## Show logs from all services
	docker compose logs -f

rebuild: ## Rebuild and restart all services
	docker compose down
	docker compose build --no-cache
	docker compose up -d

restart: ## Restart all services
	docker compose restart

status: ## Show status of all containers
	docker compose ps

up: ## Start all services in background
	docker compose up -d

#=Database
backup-db: ## Backup database to backup.sql
	$(PG_DUMP) > backup.sql
	@echo "Database backed up to backup.sql"

db-shell: ## Open PostgreSQL shell
	$(PSQL_TTY)

migrate: ## Run database migrations
	docker compose exec backend alembic upgrade head

migrate-create: ## Create a new migration (use MSG="description")
	docker compose exec backend alembic revision --autogenerate -m "$(MSG)"

rebuild-stats: ## Force a blocking rebuild of the statistics view (use if refresh-stats fails)
	@echo "REFRESH MATERIALIZED VIEW company_date_statistics;" | $(PSQL)
	@echo "Statistics rebuilt"

refresh-stats: ## Rebuild the statistics materialized view (safe to run any time)
	@echo "REFRESH MATERIALIZED VIEW CONCURRENTLY company_date_statistics;" | $(PSQL)
	@echo "Statistics refreshed"

restore-db: ## Restore database from backup.sql
	$(PSQL) < backup.sql
	@echo "Database restored from backup.sql"

stats-status: ## Show statistics view row count and how current it is
	@echo "SELECT (SELECT count(*) FROM company_date_statistics) AS view_rows, \
	              (SELECT max(scrape_date) FROM company_date_statistics) AS view_latest, \
	              (SELECT max(scrape_date) FROM inserts) AS data_latest, \
	              CASE WHEN (SELECT max(scrape_date) FROM company_date_statistics) \
	                        = (SELECT max(scrape_date) FROM inserts) \
	                   THEN 'current' ELSE 'STALE - run make refresh-stats' END AS state;" | $(PSQL)

#=Runners
run-scraper: ## Run specific scraper (use SCRAPER=name)
	docker compose exec runners python /app/main.py --scraper $(SCRAPER)

run-scrapers: ## Run all scrapers manually
	docker compose exec runners python /app/main.py

runner-cron-status: ## View cron status and schedule
	docker compose exec runners crontab -l

runner-logs: ## View runner logs
	docker compose logs -f runners

runner-restart: ## Restart runners container
	docker compose restart runners

runner-shell: ## Open shell in runners container
	docker compose exec runners bash

#=Testing
test-api: ## Test API endpoints
	@echo "Testing API health..."
	curl http://localhost:8000/
	@echo "\n\nTesting companies endpoint..."
	curl http://localhost:8000/api/companies

test-backend: ## Run backend tests (creates and drops its own jobportal_test database)
	@docker compose exec -T backend sh -c \
		'python -m pytest --version >/dev/null 2>&1 || pip install --quiet pytest httpx'
	docker compose exec -T -w /app -e PYTHONPATH=/app backend sh -c \
		'TEST_DATABASE_URL="postgresql://$$DATABASE_USER:$$DATABASE_PASSWORD@$$DATABASE_HOST:$$DATABASE_PORT/postgres" \
		 python -m pytest tests -q'

test-frontend: ## Run frontend tests
	cd Frontend && npm test -- --watch=false

#=Development
shell: ## Open shell in backend container
	docker compose exec backend bash
