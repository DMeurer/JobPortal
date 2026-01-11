-- Rollback Migration Script
--
-- This script removes all job entries created in the last N minutes.
-- Useful for testing the migration or rolling back if something goes wrong.
--
-- Usage:
--   1. Edit the @minutes_ago variable below to set how far back to delete
--   2. Run this script in your PostgreSQL database
--
-- Example: To delete entries from the last 30 minutes, set @minutes_ago = 30

-- Set how many minutes back to delete (CHANGE THIS VALUE)
-- Default: 60 minutes (1 hour)
DO $$
DECLARE
    minutes_ago INTEGER := 60;  -- CHANGE THIS VALUE
    cutoff_time TIMESTAMP;
    deleted_inserts INTEGER;
    deleted_jobs INTEGER;
    deleted_companies INTEGER;
BEGIN
    -- Calculate cutoff time
    cutoff_time := NOW() - (minutes_ago || ' minutes')::INTERVAL;

    RAISE NOTICE 'Deleting entries created after: %', cutoff_time;
    RAISE NOTICE '================================================';

    -- Delete from inserts table (scrape dates)
    DELETE FROM inserts
    WHERE created_at >= cutoff_time;

    GET DIAGNOSTICS deleted_inserts = ROW_COUNT;
    RAISE NOTICE 'Deleted % entries from inserts table', deleted_inserts;

    -- Delete from jobs table
    DELETE FROM jobs
    WHERE created_at >= cutoff_time;

    GET DIAGNOSTICS deleted_jobs = ROW_COUNT;
    RAISE NOTICE 'Deleted % entries from jobs table', deleted_jobs;

    -- Delete companies that have no jobs left
    DELETE FROM companies
    WHERE id NOT IN (SELECT DISTINCT company_id FROM jobs);

    GET DIAGNOSTICS deleted_companies = ROW_COUNT;
    RAISE NOTICE 'Deleted % orphaned companies', deleted_companies;

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Rollback complete!';
    RAISE NOTICE 'Total deleted: % inserts, % jobs, % companies',
                 deleted_inserts, deleted_jobs, deleted_companies;
END $$;
