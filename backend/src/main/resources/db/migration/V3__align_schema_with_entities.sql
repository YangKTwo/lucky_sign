-- V3: Align Flyway schema with JPA entity definitions
-- This migration renames tables/columns to match @Entity/@Table/@Column annotations
-- MySQL 8 compatible with idempotent checks where possible

-- ===== Table renames (check if old table exists before renaming) =====

-- points_logs -> points_log (PointsLog entity: @Table(name = "points_log"))
SET @tbl_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'points_logs'
);
SET @sql = IF(@tbl_exists > 0,
    'RENAME TABLE points_logs TO points_log',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- task_items -> tasks (TaskItem entity: @Table(name = "tasks"))
SET @tbl_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'task_items'
);
SET @sql = IF(@tbl_exists > 0,
    'RENAME TABLE task_items TO tasks',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ===== Column renames in chat_messages =====

-- sender_id -> user_id (ChatMessage.userId)
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'sender_id'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE chat_messages CHANGE COLUMN sender_id user_id BIGINT',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- message_type -> type (ChatMessage.type)
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'message_type'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE chat_messages CHANGE COLUMN message_type type VARCHAR(16) NOT NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- related_checkin_id -> checkin_id (ChatMessage.checkinId)
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_messages'
      AND COLUMN_NAME = 'related_checkin_id'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE chat_messages CHANGE COLUMN related_checkin_id checkin_id BIGINT',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add nickname column (ChatMessage.nickname) if not exists
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

-- Add image_url column (ChatMessage.imageUrl) if not exists
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

-- Drop mentions column if exists (replaced by mentioned_user_ids)
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

-- Add mentioned_user_ids column if not exists
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

-- Drop related_draw_id if exists (not in entity)
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

-- ===== Column renames in points_log =====

-- balance -> balance_after (PointsLog.balanceAfter)
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'points_log'
      AND COLUMN_NAME = 'balance'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE points_log CHANGE COLUMN balance balance_after INT NOT NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ===== Column changes in checkin_ratings =====

-- rater_id -> rater_user_id (CheckinRating.raterUserId)
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'checkin_ratings'
      AND COLUMN_NAME = 'rater_id'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE checkin_ratings CHANGE COLUMN rater_id rater_user_id BIGINT NOT NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add target_user_id column if not exists (CheckinRating.targetUserId)
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

-- Update unique constraint to match entity (drop old, add new)
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

-- ===== Column changes in feedbacks =====

-- Add nickname column if not exists (Feedback.nickname)
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'feedbacks'
      AND COLUMN_NAME = 'nickname'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE feedbacks ADD COLUMN nickname VARCHAR(32) NOT NULL DEFAULT \'\' AFTER user_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Drop contact column if exists (not in entity)
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

-- Drop status column if exists (not in entity)
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

-- ===== Column changes in email_logs =====

-- recipient -> to_email (EmailLog.toEmail)
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'email_logs'
      AND COLUMN_NAME = 'recipient'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE email_logs CHANGE COLUMN recipient to_email VARCHAR(64) NOT NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add content column if not exists (EmailLog.content)
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'email_logs'
      AND COLUMN_NAME = 'content'
);
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE email_logs ADD COLUMN content VARCHAR(1000) NOT NULL DEFAULT \'\' AFTER subject',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Drop template_name if exists (not in entity)
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

-- ===== Drop tasks.created_at if exists (not in TaskItem entity) =====
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'tasks'
      AND COLUMN_NAME = 'created_at'
);
SET @sql = IF(@col_exists > 0,
    'ALTER TABLE tasks DROP COLUMN created_at',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
