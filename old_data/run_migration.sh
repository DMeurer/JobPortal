#!/bin/bash
#
# Migration helper script
# Edit the variables below, then run: ./run_migration.sh
#

# Old database connection
DB_HOST="192.168.0.200"
DB_USER="root"
DB_PASSWORD="your_password_here"
DB_NAME="jobs"

# New API connection
API_URL="http://localhost:8000"
# Get this from the .env file in the root directory (API_KEY_WEBSCRAPER or API_KEY_ADMIN)
API_KEY="your_api_key_here"

# Install dependencies if needed
if ! python3 -c "import mysql.connector" 2>/dev/null; then
    echo "Installing dependencies..."
    pip install -r requirements.txt
fi

# Run migration
echo "Starting migration..."
echo "Database: $DB_HOST/$DB_NAME"
echo "API: $API_URL"
echo ""

python3 migrate_old_data.py \
    --db-host "$DB_HOST" \
    --db-user "$DB_USER" \
    --db-password "$DB_PASSWORD" \
    --db-name "$DB_NAME" \
    --api-url "$API_URL" \
    --api-key "$API_KEY"

echo ""
echo "Migration complete!"
