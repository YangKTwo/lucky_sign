# Flyway Migration Recovery Guide

## Problem: Failed V2 Migration (MySQL Compatibility)

If V2__security_enhancements.sql failed with an error like:

```
SQL State: 42000 Error Code: 1064
near 'IF NOT EXISTS token_version BIGINT NOT NULL DEFAULT 0'
```

This was caused by using MariaDB-specific `ADD COLUMN IF NOT EXISTS` syntax which is not supported by MySQL 8.

## Recovery Steps

### Step 1: Check Flyway Schema History

Connect to your MySQL database and check the failed migration:

```sql
SELECT * FROM flyway_schema_history WHERE success = 0;
```

### Step 2: Assess Partial Changes

Check which columns were partially added before the failure:

```sql
-- Check users table
SELECT COLUMN_NAME FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' 
AND COLUMN_NAME IN ('token_version', 'enabled');

-- Check daily_draws table
SELECT COLUMN_NAME FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'daily_draws' 
AND COLUMN_NAME = 'version';
```

### Step 3: Repair Flyway History

**Option A: Using Flyway CLI**

```bash
# If you have Flyway CLI installed
flyway -url=jdbc:mysql://host:3306/dbname -user=xxx -password=xxx repair
```

**Option B: Manual SQL (Simpler)**

Delete the failed migration record so Flyway will retry:

```sql
DELETE FROM flyway_schema_history WHERE version = '2' AND success = 0;
```

### Step 4: Redeploy

After repairing the history, redeploy the application. The fixed V2 migration now uses `information_schema` checks and prepared statements to safely add columns if they don't exist.

## Prevention

The V2 and V3 migrations have been rewritten to be:

1. **MySQL 8 Compatible**: No MariaDB-specific syntax
2. **Idempotent**: Uses `information_schema` checks before DDL operations
3. **Safe to Retry**: If interrupted, can be re-run after Flyway repair

## V3 Migration Notes

V3 renames tables and columns to match JPA entity definitions. It's also now idempotent - it checks if the old name exists before renaming.

## Production Checklist

- [ ] Run `flyway repair` or delete failed row from `flyway_schema_history`
- [ ] Verify JWT_SECRET and other environment variables are set
- [ ] Redeploy backend
- [ ] Monitor logs for successful migration completion
