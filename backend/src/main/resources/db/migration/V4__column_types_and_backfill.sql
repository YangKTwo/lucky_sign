-- V4: Fix column types/lengths/nullability to match JPA @Column annotations
-- MySQL 8 compatible with idempotent checks (no DELIMITER/PROCEDURE)
--
-- k2/k4 Items Implemented:
--   #8: Avoid long-lived DEFAULT 0; backfill then constrain
--   #9: VARCHAR shortening guards - check MAX(CHAR_LENGTH), fail loud
--
-- WARNING: VARCHAR shortening will FAIL if data exceeds target length.
-- This is intentional - no silent truncation. See error message for fix.

-- ========================================================================
-- VARCHAR SHORTENING GUARDS (k2 #9)
-- Pre-check data length before shortening. Migration fails if data too long.
-- ========================================================================

-- === email_logs.subject: VARCHAR(255) -> VARCHAR(128) ===
-- Check if any subject exceeds 128 characters
SET @max_len = (SELECT COALESCE(MAX(CHAR_LENGTH(subject)), 0) FROM email_logs);
SET @sql = IF(@max_len > 128,
    CONCAT('SELECT ''ERROR: email_logs.subject has data length ', @max_len, 
           ' which exceeds target VARCHAR(128). ',
           'Truncate with: UPDATE email_logs SET subject = LEFT(subject, 128) WHERE CHAR_LENGTH(subject) > 128; ',
           'Then re-run migration.'' AS error FROM nonexistent_table_to_fail_migration'),
    'SELECT ''email_logs.subject length OK'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === points_log.change_type: VARCHAR(32) -> VARCHAR(16) ===
-- Check if points_log exists first
SET @tbl_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'points_log'
);
SET @max_len = IF(@tbl_exists > 0,
    (SELECT COALESCE(MAX(CHAR_LENGTH(change_type)), 0) FROM points_log),
    0);
SET @sql = IF(@max_len > 16,
    CONCAT('SELECT ''ERROR: points_log.change_type has data length ', @max_len,
           ' which exceeds target VARCHAR(16). ',
           'Truncate with: UPDATE points_log SET change_type = LEFT(change_type, 16) WHERE CHAR_LENGTH(change_type) > 16; ',
           'Then re-run migration.'' AS error FROM nonexistent_table_to_fail_migration'),
    'SELECT ''points_log.change_type length OK'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ========================================================================
-- COLUMN TYPE MODIFICATIONS (idempotent - safe to re-run)
-- ========================================================================

-- chat_messages.content: TEXT NOT NULL -> VARCHAR(2000) nullable
-- Entity: @Column(length = 2000) with no nullable=false
-- TEXT to VARCHAR conversion - check length first
SET @max_len = (SELECT COALESCE(MAX(CHAR_LENGTH(content)), 0) FROM chat_messages);
SET @sql = IF(@max_len > 2000,
    CONCAT('SELECT ''ERROR: chat_messages.content has data length ', @max_len,
           ' which exceeds target VARCHAR(2000).'' AS error FROM nonexistent_table_to_fail_migration'),
    'ALTER TABLE chat_messages MODIFY COLUMN content VARCHAR(2000)');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- feedbacks.content: TEXT NOT NULL -> VARCHAR(1000) NOT NULL  
-- Entity: @Column(nullable = false, length = 1000)
SET @max_len = (SELECT COALESCE(MAX(CHAR_LENGTH(content)), 0) FROM feedbacks);
SET @sql = IF(@max_len > 1000,
    CONCAT('SELECT ''ERROR: feedbacks.content has data length ', @max_len,
           ' which exceeds target VARCHAR(1000).'' AS error FROM nonexistent_table_to_fail_migration'),
    'ALTER TABLE feedbacks MODIFY COLUMN content VARCHAR(1000) NOT NULL');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- email_logs.subject: VARCHAR(255) NOT NULL -> VARCHAR(128) NOT NULL
-- Entity: @Column(nullable = false, length = 128)
-- Length already checked above
ALTER TABLE email_logs MODIFY COLUMN subject VARCHAR(128) NOT NULL;

-- email_logs.error_message: TEXT -> VARCHAR(500)
-- Entity: @Column(length = 500)
SET @max_len = (SELECT COALESCE(MAX(CHAR_LENGTH(error_message)), 0) FROM email_logs);
SET @sql = IF(@max_len > 500,
    CONCAT('SELECT ''ERROR: email_logs.error_message has data length ', @max_len,
           ' which exceeds target VARCHAR(500).'' AS error FROM nonexistent_table_to_fail_migration'),
    'ALTER TABLE email_logs MODIFY COLUMN error_message VARCHAR(500)');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- points_log.change_type: VARCHAR(32) NOT NULL -> VARCHAR(16) NOT NULL
-- Entity: @Column(nullable = false, length = 16)
-- Only if table exists; length already checked above
SET @tbl_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'points_log'
);
SET @sql = IF(@tbl_exists > 0,
    'ALTER TABLE points_log MODIFY COLUMN change_type VARCHAR(16) NOT NULL',
    'SELECT ''points_log not found - skipping change_type modify'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ========================================================================
-- BACKFILL target_user_id (k2 #8)
-- ========================================================================

-- CheckinRating.targetUserId should be the owner of the checkin record being rated.
-- Join checkin_ratings with checkin_records to populate.
-- Only update where target_user_id is still default 0
UPDATE checkin_ratings cr
JOIN checkin_records r ON cr.checkin_id = r.id
SET cr.target_user_id = r.user_id
WHERE cr.target_user_id = 0;

-- k2 #8: Remove the DEFAULT 0 now that data is backfilled
-- (MySQL requires re-specifying the full column definition)
ALTER TABLE checkin_ratings MODIFY COLUMN target_user_id BIGINT NOT NULL;

-- ========================================================================
-- MIGRATION NOTES
-- ========================================================================
--
-- VARCHAR SHORTENING FAILURES:
-- If migration fails with "nonexistent_table_to_fail_migration" error,
-- it means data exceeds the target column length. The error message
-- includes the SQL to truncate the data. Run that SQL manually, then
-- delete the failed migration record and retry:
--   DELETE FROM flyway_schema_history WHERE version = '4' AND success = 0;
--
-- MENTIONS COLUMN (dropped in V3):
-- The `chat_messages.mentions` JSON column was replaced with
-- `mentioned_user_ids` VARCHAR(256). Original JSON data is discarded.
-- If needed, restore from backup before V3 runs.
--
-- IDEMPOTENCY:
-- V4 column MODIFYs are idempotent (safe to re-run).
-- Backfill UPDATE only affects rows where target_user_id = 0.
