# Migration helper script for PowerShell
# Edit the variables below, then run: .\run_migration.ps1

# Old database connection
$DB_HOST = "localhost"
$DB_USER = "root"
$DB_PASSWORD = "your_root_password"
$DB_NAME = "jobs"

# New API connection
$API_URL = "http://localhost:8000"
# Get this from the .env file in the root directory (API_KEY_WEBSCRAPER or API_KEY_ADMIN)
$API_KEY = "aHpAvVqQ9Ceo5gP6WOU1x-vXOcqvGXr0je58X0oBOI-vFJ8b5W9GiN7R80f8Lf79"

# Install dependencies if needed
Write-Host "Checking dependencies..."
try {
    python -c "import mysql.connector" 2>$null
} catch {
    Write-Host "Installing dependencies..."
    pip install -r requirements.txt
}

# Run migration
Write-Host ""
Write-Host "Starting migration..."
Write-Host "Database: $DB_HOST/$DB_NAME"
Write-Host "API: $API_URL"
Write-Host ""

python migrate_old_data.py `
    --db-host $DB_HOST `
    --db-user $DB_USER `
    --db-password $DB_PASSWORD `
    --db-name $DB_NAME `
    --api-url $API_URL `
    --api-key $API_KEY

Write-Host ""
Write-Host "Migration complete!"
