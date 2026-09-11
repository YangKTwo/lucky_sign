-- Security enhancements for existing databases
-- Adds columns and constraints introduced in the security refactor

-- Add token_version and enabled columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- Add version column to daily_draws for optimistic locking
ALTER TABLE daily_draws ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;

-- Add unique constraint on checkin_records if not exists
-- MySQL syntax: check if index exists before adding
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
ALTER TABLE circles MODIFY COLUMN invite_code VARCHAR(16);
