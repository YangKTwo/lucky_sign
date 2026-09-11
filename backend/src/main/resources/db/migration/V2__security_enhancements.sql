-- Security enhancements for existing databases
-- Adds columns and constraints introduced in the security refactor
-- MySQL 8 compatible (no MariaDB-specific ADD COLUMN IF NOT EXISTS)

-- ===== Helper: Add column if not exists using information_schema =====

-- Add token_version column to users table
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'token_version'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN token_version BIGINT NOT NULL DEFAULT 0',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add enabled column to users table
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'enabled'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN enabled BOOLEAN NOT NULL DEFAULT TRUE',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add version column to daily_draws for optimistic locking
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'daily_draws'
      AND COLUMN_NAME = 'version'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE daily_draws ADD COLUMN version BIGINT DEFAULT 0',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add unique constraint on checkin_records if not exists
SET @constraint_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND TABLE_NAME = 'checkin_records'
      AND CONSTRAINT_NAME = 'uk_user_checkin_date'
);
SET @sql = IF(@constraint_exists = 0,
    'ALTER TABLE checkin_records ADD CONSTRAINT uk_user_checkin_date UNIQUE (user_id, checkin_date)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Increase invite_code column length to 16 for longer codes
-- MODIFY is idempotent (safe to re-run)
ALTER TABLE circles MODIFY COLUMN invite_code VARCHAR(16);
