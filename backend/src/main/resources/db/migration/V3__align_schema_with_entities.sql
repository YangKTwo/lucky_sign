-- V3: Align Flyway schema with JPA entity definitions
-- MySQL 8 compatible with idempotent checks (no DELIMITER/PROCEDURE)
--
-- k2/k4 Items Implemented:
--   #1, #3: Three-state table rename logic
--   #4: CHANGE COLUMN three-state logic
--   #5: Dual-table merge with INSERT...WHERE NOT EXISTS
--   #7: Archive before DROP (documented in runbook)
--
-- THREE-STATE TABLE RENAME SEMANTICS:
--   - only old exists → RENAME
--   - only new exists → noop
--   - both exist → DO NOT RENAME; merge data; do NOT auto-DROP old

-- ========================================================================
-- TABLE RENAMES: Three-state logic
-- ========================================================================

-- === points_logs -> points_log ===
-- Check both tables to determine state
SET @old_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'points_logs'
);
SET @new_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'points_log'
);

-- State 1: only old exists → RENAME
SET @sql = IF(@old_exists > 0 AND @new_exists = 0,
    'RENAME TABLE points_logs TO points_log',
    'SELECT ''points_log: noop or merge required'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- State 3: both exist → MERGE (do NOT rename, do NOT auto-drop)
-- WARNING: INSERT...WHERE NOT EXISTS keeps new-table row on PK conflict.
-- If both tables have row with same ID, NEW table's row is preserved.
-- This is intentional: JPA's canonical table (points_log) takes precedence.
-- See runbook for manual verification before DROP.
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'INSERT INTO points_log (id, user_id, change_type, delta, balance_after, related_id, created_at)
     SELECT id, user_id, change_type, delta, 
            COALESCE(balance, balance_after, 0) AS balance_after,
            related_id, created_at
     FROM points_logs old
     WHERE NOT EXISTS (SELECT 1 FROM points_log new WHERE new.id = old.id)',
    'SELECT ''points: no merge needed'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === task_items -> tasks ===
SET @old_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'task_items'
);
SET @new_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tasks'
);

-- State 1: only old exists → RENAME
SET @sql = IF(@old_exists > 0 AND @new_exists = 0,
    'RENAME TABLE task_items TO tasks',
    'SELECT ''tasks: noop or merge required'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- State 3: both exist → MERGE
-- WARNING: Same PK conflict handling as points - new table row preserved.
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'INSERT INTO tasks (id, content, difficulty, enabled)
     SELECT id, content, difficulty, enabled
     FROM task_items old
     WHERE NOT EXISTS (SELECT 1 FROM tasks new WHERE new.id = old.id)',
    'SELECT ''tasks: no merge needed'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ========================================================================
-- COLUMN RENAMES: Three-state logic
-- ========================================================================

-- === chat_messages: sender_id -> user_id ===
SET @old_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'sender_id'
);
SET @new_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'user_id'
);
-- State 1: only old exists → CHANGE
SET @sql = IF(@old_exists > 0 AND @new_exists = 0,
    'ALTER TABLE chat_messages CHANGE COLUMN sender_id user_id BIGINT',
    'SELECT ''chat_messages.user_id: noop'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
-- State 2: both exist → align and drop old (with warning)
-- WARNING: Both sender_id and user_id exist. Copying sender_id to user_id where user_id is NULL.
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'UPDATE chat_messages SET user_id = sender_id WHERE user_id IS NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
-- Now safe to drop old (data preserved in new)
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'ALTER TABLE chat_messages DROP COLUMN sender_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === chat_messages: message_type -> type ===
SET @old_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'message_type'
);
SET @new_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'type'
);
SET @sql = IF(@old_exists > 0 AND @new_exists = 0,
    'ALTER TABLE chat_messages CHANGE COLUMN message_type type VARCHAR(16) NOT NULL',
    'SELECT ''chat_messages.type: noop'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'UPDATE chat_messages SET type = message_type WHERE type IS NULL OR type = ''''',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'ALTER TABLE chat_messages DROP COLUMN message_type',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === chat_messages: related_checkin_id -> checkin_id ===
SET @old_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'related_checkin_id'
);
SET @new_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'checkin_id'
);
SET @sql = IF(@old_exists > 0 AND @new_exists = 0,
    'ALTER TABLE chat_messages CHANGE COLUMN related_checkin_id checkin_id BIGINT',
    'SELECT ''chat_messages.checkin_id: noop'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'UPDATE chat_messages SET checkin_id = related_checkin_id WHERE checkin_id IS NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'ALTER TABLE chat_messages DROP COLUMN related_checkin_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === chat_messages: Add nickname if not exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'nickname'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE chat_messages ADD COLUMN nickname VARCHAR(64) AFTER user_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === chat_messages: Add image_url if not exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'image_url'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE chat_messages ADD COLUMN image_url VARCHAR(512) AFTER content',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === chat_messages: Drop mentions if exists ===
-- NOTE: mentions data is DISCARDED. See flyway-repair-notes.md for archival if needed.
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'mentions'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE chat_messages DROP COLUMN mentions',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === chat_messages: Add mentioned_user_ids if not exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'mentioned_user_ids'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE chat_messages ADD COLUMN mentioned_user_ids VARCHAR(256) AFTER checkin_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === chat_messages: Drop related_draw_id if exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'related_draw_id'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE chat_messages DROP COLUMN related_draw_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ========================================================================
-- COLUMN RENAMES IN points_log
-- ========================================================================

-- === points_log: balance -> balance_after ===
-- Only if points_log exists (may have just been renamed or created)
SET @tbl_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'points_log'
);
SET @old_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'points_log'
      AND COLUMN_NAME = 'balance'
);
SET @new_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'points_log'
      AND COLUMN_NAME = 'balance_after'
);
SET @sql = IF(@tbl_exists > 0 AND @old_exists > 0 AND @new_exists = 0,
    'ALTER TABLE points_log CHANGE COLUMN balance balance_after INT NOT NULL',
    'SELECT ''points_log.balance_after: noop'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
-- Handle both columns exist case
SET @sql = IF(@tbl_exists > 0 AND @old_exists > 0 AND @new_exists > 0,
    'UPDATE points_log SET balance_after = balance WHERE balance_after IS NULL OR balance_after = 0',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql = IF(@tbl_exists > 0 AND @old_exists > 0 AND @new_exists > 0,
    'ALTER TABLE points_log DROP COLUMN balance',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ========================================================================
-- COLUMN CHANGES IN checkin_ratings
-- ========================================================================

-- === checkin_ratings: rater_id -> rater_user_id ===
SET @old_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'checkin_ratings'
      AND COLUMN_NAME = 'rater_id'
);
SET @new_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'checkin_ratings'
      AND COLUMN_NAME = 'rater_user_id'
);
SET @sql = IF(@old_exists > 0 AND @new_exists = 0,
    'ALTER TABLE checkin_ratings CHANGE COLUMN rater_id rater_user_id BIGINT NOT NULL',
    'SELECT ''checkin_ratings.rater_user_id: noop'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'UPDATE checkin_ratings SET rater_user_id = rater_id WHERE rater_user_id IS NULL OR rater_user_id = 0',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'ALTER TABLE checkin_ratings DROP COLUMN rater_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === checkin_ratings: Add target_user_id if not exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'checkin_ratings'
      AND COLUMN_NAME = 'target_user_id'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE checkin_ratings ADD COLUMN target_user_id BIGINT NOT NULL DEFAULT 0 AFTER checkin_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === checkin_ratings: Update unique index ===
SET @idx_exists = (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'checkin_ratings'
      AND INDEX_NAME = 'uk_checkin_rater'
);
SET @sql = IF(@idx_exists > 0,
    'ALTER TABLE checkin_ratings DROP INDEX uk_checkin_rater',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists = (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'checkin_ratings'
      AND INDEX_NAME = 'uk_checkin_rater_user'
);
SET @sql = IF(@idx_exists = 0,
    'ALTER TABLE checkin_ratings ADD UNIQUE INDEX uk_checkin_rater_user (checkin_id, rater_user_id)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ========================================================================
-- COLUMN CHANGES IN feedbacks
-- ========================================================================

-- === feedbacks: Add nickname if not exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'feedbacks'
      AND COLUMN_NAME = 'nickname'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE feedbacks ADD COLUMN nickname VARCHAR(32) NOT NULL DEFAULT '''' AFTER user_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === feedbacks: Drop contact if exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'feedbacks'
      AND COLUMN_NAME = 'contact'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE feedbacks DROP COLUMN contact',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === feedbacks: Drop status if exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'feedbacks'
      AND COLUMN_NAME = 'status'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE feedbacks DROP COLUMN status',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ========================================================================
-- COLUMN CHANGES IN email_logs
-- ========================================================================

-- === email_logs: recipient -> to_email ===
SET @old_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'email_logs'
      AND COLUMN_NAME = 'recipient'
);
SET @new_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'email_logs'
      AND COLUMN_NAME = 'to_email'
);
SET @sql = IF(@old_exists > 0 AND @new_exists = 0,
    'ALTER TABLE email_logs CHANGE COLUMN recipient to_email VARCHAR(64) NOT NULL',
    'SELECT ''email_logs.to_email: noop'' AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'UPDATE email_logs SET to_email = recipient WHERE to_email IS NULL OR to_email = ''''',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql = IF(@old_exists > 0 AND @new_exists > 0,
    'ALTER TABLE email_logs DROP COLUMN recipient',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === email_logs: Add content if not exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'email_logs'
      AND COLUMN_NAME = 'content'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE email_logs ADD COLUMN content VARCHAR(1000) NOT NULL DEFAULT '''' AFTER subject',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- === email_logs: Drop template_name if exists ===
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'email_logs'
      AND COLUMN_NAME = 'template_name'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE email_logs DROP COLUMN template_name',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ========================================================================
-- DROP tasks.created_at if exists
-- ========================================================================

SET @tbl_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tasks'
);
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'tasks'
      AND COLUMN_NAME = 'created_at'
);
SET @sql = IF(@tbl_exists > 0 AND @col_exists > 0,
    'ALTER TABLE tasks DROP COLUMN created_at',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ========================================================================
-- MIGRATION NOTES (for runbook reference)
-- ========================================================================
--
-- DUAL-TABLE MERGE BEHAVIOR:
-- When both old and new tables exist (e.g., points_logs AND points_log):
-- 1. Migration does NOT rename (would fail with error 1050)
-- 2. Migration INSERTs from old to new WHERE NOT EXISTS by PK
-- 3. On PK conflict: NEW table row is PRESERVED (JPA canonical)
-- 4. Old table is NOT auto-dropped - requires manual verification
--
-- MANUAL STEPS AFTER DUAL-TABLE MERGE:
-- 1. Compare row counts: SELECT COUNT(*) FROM points_logs; SELECT COUNT(*) FROM points_log;
-- 2. Verify no data loss: old_count should equal or be less than new_count
-- 3. Backup old table: CREATE TABLE _bak_points_logs AS SELECT * FROM points_logs;
-- 4. Drop old table: DROP TABLE points_logs;
-- 5. Repeat for task_items/tasks if applicable
--
-- See deploy/flyway-repair-notes.md for complete runbook.
