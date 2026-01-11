# JobPortal

Multi-service job portal application with web scraping, API backend, and frontend dashboard.

## Quick Start

```bash
# Initialize (first time)
make init

# Start services
make up

# View logs
make logs

# Stop services
make down
```

See `make help` for all commands.

## Services

- **Backend**: FastAPI + PostgreSQL (port 8000)
- **Frontend**: Angular + ApexCharts (port 4200)
- **Runners**: Python job scrapers (cron scheduled)
- **Database**: PostgreSQL (port 5432)

## Configuration

Copy `.env.example` to `.env` and configure:

```env
# Database
POSTGRES_USER=jobportal_user
POSTGRES_PASSWORD=jobportal_password
POSTGRES_DB=jobportal

# API Keys (change in production)
API_KEY_ADMIN=...
API_KEY_WEBSCRAPER=...
API_KEY_FULLREAD=...
API_KEY_FRONTEND=...
```

## Access

- API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Frontend: http://localhost:4200
- Database: localhost:5432

## Repository Structure

This is the main repository using git submodules:

- `Backend/` → [JobPortal-Backend](https://github.com/DMeurer/JobPortal-Backend)
- `Frontend/` → [JobPortal-Frontend](https://github.com/DMeurer/JobPortal-Frontend)
- `Runners/` → [JobPortal-Runners](https://github.com/DMeurer/JobPortal-Runners)

### Working with Submodules

**Clone with submodules:**
```bash
git clone --recursive <main-repo-url>
```

**Update submodules:**
```bash
git submodule update --remote --merge
```

**Make changes in a submodule:**
```bash
cd Backend
# Make changes
git add .
git commit -m "Your changes"
git push origin main

# Update main repo reference
cd ..
git add Backend
git commit -m "Update Backend submodule"
git push
```

## Documentation

- `DOCKER_QUICKREF.md` - Docker commands reference
- `Makefile` - All available make commands
- Backend README: `Backend/README.md`
- Frontend README: `Frontend/README.md`
- Runners README: `Runners/README.md`
