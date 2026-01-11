#!/usr/bin/env python3
"""
Migration script to import old job data into the new JobPortal system.

This script connects to the old MySQL database and migrates all job listings
to the new system using the Backend API.

Usage:
    python migrate_old_data.py --db-host localhost:3306 --db-user root --db-password yourpass --api-url http://localhost:8000 --api-key your_api_key
"""

import argparse
import sys
from datetime import datetime, date
from typing import Dict, List, Optional
import mysql.connector
import requests


class OldDataMigrator:
    """Migrates data from the old MySQL database to the new API."""

    # Company mapping: old table prefix -> new company name
    COMPANY_MAPPING = {
        # 'bbraun': 'BBraun',
        # 'ep': 'Europapark',
        # 'kauth': 'Kauth',
        'kls': 'KLS',
        'ks': 'KarlStorz',
        # 'schwer': 'Schwer',
        # 'trelectronic': 'TRElectronic'
    }

    # Companies that should be marked as hidden
    HIDDEN_COMPANIES = {'Europapark', 'KarlsStorz', 'Schwer'}

    # Field mappings: old_field_name -> new_field_name
    # Each company may have different fields, so we map them here
    FIELD_MAPPINGS = {
        'bbraun': {
            'JobID': 'job_id',
            'Title': 'title',
            'urlTitle': 'url_title',
            'Function': 'function',
            'Level': 'level',
            'WorkLocation': 'work_location',
            'WorkLocationShort': 'work_location_short',
            'WorkLocationWithCoordinates': 'work_location_with_coordinates',
            'CoordinatesPrimary': 'coordinates_primary',
            'Country': 'country',
            'currency': 'currency',
            'supportedLocales': 'supported_locales',
            'unifiedUrlTitle': 'unified_url_title',
            'unifiedStandardEnd': 'unified_standard_end',
            'unifiedStandardStart': 'unified_standard_start',
            'DateAdded': 'date_added'
        },
        'ep': {
            'URL': 'url',
            'Title': 'title',
            'Function': 'function',
            'WorkLocation': 'work_location',
            'ContractType': 'contract_type',
            'Company': 'department',  # Using department field for company info
            'ContactPerson': 'contact_person',
            'ContactEmail': 'contact_email',
            'ContactPhone': 'contact_phone',
            'Description': 'description',
            'Offerings': 'offerings',
            'Tasks': 'tasks',
            'Qualifications': 'qualifications',
            'DateAdded': 'date_added'
        },
        'kauth': {
            'Title': 'title',
            'JobID': 'job_id',
            'URL': 'url',
            'city': 'work_location_short',
            'Contract_Type': 'contract_type',
            'Flexibility': 'flexibility',
            'Work_Location': 'work_location',
            'Job_Level': 'level',
            'ContactPerson': 'contact_person',
            'ContactPosition': 'description',  # Store contact position in description
            'DateAdded': 'date_added'
        },
        'kls': {
            'Title': 'title',
            'Function': 'function',
            'Level': 'level',
            'WorkLocation': 'work_location',
            'Flexibility': 'flexibility',
            'JobID': 'job_id',
            'ContractType': 'contract_type',
            'ContactPerson': 'contact_person',
            'Offerings': 'offerings',
            'Tasks': 'tasks',
            'Qualifications': 'qualifications',
            'DateAdded': 'date_added'
        },
        'ks': {
            'Title': 'title',
            'URL': 'url',
            'Function': 'function',
            'Level': 'level',
            'WorkLocation': 'work_location',
            'Flexibility': 'flexibility',
            'CompanyLocation': 'work_location_short',
            'DetailLocation': 'all_locations',
            'JobID': 'job_id',
            'PayRange': 'keywords',  # Store pay range in keywords
            'DateAdded': 'date_added'
        },
        'schwer': {
            'JobID': 'job_id',
            'Title': 'title',
            'ContractType': 'contract_type',
            'Level': 'level',
            'Keywords': 'keywords',
            'Description': 'description',
            'WorkLocation': 'work_location',
            'AllLocations': 'all_locations',
            'Flexibility': 'flexibility',
            'Department': 'department',
            'Company': 'contact_person',  # Store company info in contact_person
            'DateAdded': 'date_added'
        },
        'trelectronic': {
            'Title': 'title',
            'JobID': 'job_id',
            'URL': 'url',
            'city': 'work_location_short',
            'Contract_Type': 'contract_type',
            'Flexibility': 'flexibility',
            'Work_Location': 'work_location',
            'Job_Level': 'level',
            'ContactPerson': 'contact_person',
            'ContactPosition': 'description',
            'DateAdded': 'date_added'
        }
    }

    def __init__(self, db_host: str, db_user: str, db_password: str, db_name: str,
                 api_url: str, api_key: str):
        """Initialize the migrator."""
        self.db_config = {
            'host': db_host,
            'user': db_user,
            'password': db_password,
            'database': db_name
        }
        self.api_url = api_url.rstrip('/')
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({'X-API-Key': api_key})

        self.stats = {
            'total_jobs': 0,
            'total_dates': 0,
            'errors': 0,
            'by_company': {}
        }

    def connect_db(self):
        """Connect to the old MySQL database."""
        try:
            connection = mysql.connector.connect(**self.db_config)
            print(f"Connected to database at {self.db_config['host']}")
            return connection
        except mysql.connector.Error as err:
            print(f"Error connecting to database: {err}")
            sys.exit(1)

    def _parse_date(self, date_str: str) -> Optional[date]:
        """Parse various date formats."""
        if not date_str or date_str.strip() == '':
            return None

        # Try different date formats
        formats = [
            '%Y-%m-%d',
            '%Y/%m/%d',
            '%d.%m.%Y',
            '%d/%m/%Y',
            '%Y-%m-%d %H:%M:%S',
            '%Y/%m/%d %H:%M:%S'
        ]

        for fmt in formats:
            try:
                return datetime.strptime(date_str.strip(), fmt).date()
            except ValueError:
                continue

        # If all parsing fails, return None silently
        return None

    def map_job_fields(self, company_prefix: str, old_row: Dict) -> Dict:
        """Map old database fields to new API schema."""
        field_mapping = self.FIELD_MAPPINGS.get(company_prefix, {})
        new_data = {}

        for old_field, new_field in field_mapping.items():
            if old_field in old_row and old_row[old_field] is not None:
                value = old_row[old_field]

                # Special handling for date fields
                if new_field == 'date_added' and isinstance(value, (str, datetime)):
                    if isinstance(value, str):
                        parsed = self._parse_date(value)
                        if parsed:
                            new_data[new_field] = parsed.isoformat()
                    elif isinstance(value, datetime):
                        new_data[new_field] = value.date().isoformat()
                else:
                    new_data[new_field] = str(value) if value is not None else None

        return new_data

    def insert_job_via_api(self, company_name: str, job_data: Dict, scrape_date: date) -> bool:
        """Insert a job via the API."""
        url = f"{self.api_url}/api/jobs"

        # Check if company should be hidden
        is_hidden = company_name in self.HIDDEN_COMPANIES

        payload = {
            'company_name': company_name,
            'hidden': is_hidden,
            'scrape_date': scrape_date.isoformat(),
            **job_data
        }

        # Remove None values
        payload = {k: v for k, v in payload.items() if v is not None}

        try:
            response = self.session.post(url, json=payload)
            response.raise_for_status()
            result = response.json()
            return True
        except requests.exceptions.RequestException as e:
            print(f"  Error inserting job: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"  Response: {e.response.text}")
            return False

    def migrate_company(self, connection, company_prefix: str):
        """Migrate all jobs for a single company."""
        company_name = self.COMPANY_MAPPING[company_prefix]
        listings_table = f'jobs_{company_prefix}_listings'
        dates_table = f'jobs_{company_prefix}_dates'

        print(f"\n{'='*60}")
        print(f"Migrating {company_name}")
        print(f"{'='*60}")

        cursor = connection.cursor(dictionary=True)

        # Use JOIN query to get all jobs with their dates
        # This ensures we get every entry from the dates table
        query = f"""
            SELECT
                j.*,
                d.ScrapeDate,
                d.id as date_entry_id
            FROM {dates_table} d
            INNER JOIN {listings_table} j ON d.job_id = j.id
            ORDER BY j.id, d.ScrapeDate
        """

        cursor.execute(query)
        all_rows = cursor.fetchall()

        # Also get jobs that have NO dates in the dates table
        query_no_dates = f"""
            SELECT j.*
            FROM {listings_table} j
            LEFT JOIN {dates_table} d ON d.job_id = j.id
            WHERE d.id IS NULL
        """
        cursor.execute(query_no_dates)
        jobs_without_dates = cursor.fetchall()

        cursor.close()

        jobs_migrated = 0
        dates_migrated = 0
        errors = 0
        processed_jobs = set()

        # Process all rows from JOIN (jobs with dates)
        for row in all_rows:
            # Map fields to new schema (exclude our added columns)
            job_data = self.map_job_fields(company_prefix, row)

            # Parse the scrape date
            scrape_date_str = row.get('ScrapeDate')
            scrape_date = None

            if scrape_date_str:
                scrape_date = self._parse_date(scrape_date_str)

            # If date parsing failed, try to use DateAdded or today
            if not scrape_date:
                print(f"  Warning: Invalid or missing ScrapeDate: {scrape_date_str}. Skipping...")
                continue

                if 'date_added' in job_data and job_data['date_added']:
                    try:
                        scrape_date = datetime.fromisoformat(job_data['date_added']).date()
                    except:
                        scrape_date = date.today()
                else:
                    scrape_date = date.today()

            # Insert job with this scrape date
            success = self.insert_job_via_api(company_name, job_data, scrape_date)
            if success:
                dates_migrated += 1
            else:
                errors += 1

            # Track unique jobs
            job_id = row['id']
            if job_id not in processed_jobs:
                jobs_migrated += 1
                processed_jobs.add(job_id)

            if dates_migrated % 50 == 0:
                print(f"  Migrated {jobs_migrated} unique jobs ({dates_migrated} date entries)...", end='\r')

        # Process jobs without any date entries
        for row in jobs_without_dates:
            job_data = self.map_job_fields(company_prefix, row)

            # Use DateAdded or today
            scrape_date = date.today()
            if 'date_added' in job_data and job_data['date_added']:
                try:
                    scrape_date = datetime.fromisoformat(job_data['date_added']).date()
                except:
                    pass

            success = self.insert_job_via_api(company_name, job_data, scrape_date)
            if success:
                dates_migrated += 1
            else:
                errors += 1

            jobs_migrated += 1

        print(f"\n  Completed: {jobs_migrated} unique jobs, {dates_migrated} date entries, {errors} errors")

        self.stats['by_company'][company_name] = {
            'jobs': jobs_migrated,
            'dates': dates_migrated,
            'errors': errors
        }
        self.stats['total_jobs'] += jobs_migrated
        self.stats['total_dates'] += dates_migrated
        self.stats['errors'] += errors

    def migrate_all(self):
        """Migrate all companies from the old database."""
        connection = self.connect_db()

        try:
            for company_prefix in self.COMPANY_MAPPING.keys():
                try:
                    self.migrate_company(connection, company_prefix)
                except Exception as e:
                    print(f"\nError migrating {company_prefix}: {e}")
                    import traceback
                    traceback.print_exc()
        finally:
            connection.close()

        self.print_summary()

    def print_summary(self):
        """Print migration summary."""
        print(f"\n{'='*60}")
        print("MIGRATION SUMMARY")
        print(f"{'='*60}")

        for company_name, stats in self.stats['by_company'].items():
            print(f"{company_name:20} {stats['jobs']:5} jobs  {stats['dates']:6} dates  {stats['errors']:4} errors")

        print(f"{'-'*60}")
        print(f"{'TOTAL':20} {self.stats['total_jobs']:5} jobs  {self.stats['total_dates']:6} dates  {self.stats['errors']:4} errors")
        print(f"{'='*60}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Migrate old job data to new JobPortal system'
    )
    parser.add_argument('--db-host', required=True, help='MySQL database host')
    parser.add_argument('--db-user', required=True, help='MySQL database user')
    parser.add_argument('--db-password', required=True, help='MySQL database password')
    parser.add_argument('--db-name', default='jobs', help='MySQL database name (default: jobs)')
    parser.add_argument('--api-url', required=True, help='JobPortal API URL (e.g., http://localhost:8000)')
    parser.add_argument('--api-key', required=True, help='API key for authentication (needs write permission)')

    args = parser.parse_args()

    migrator = OldDataMigrator(
        db_host=args.db_host,
        db_user=args.db_user,
        db_password=args.db_password,
        db_name=args.db_name,
        api_url=args.api_url,
        api_key=args.api_key
    )

    migrator.migrate_all()


if __name__ == '__main__':
    main()
