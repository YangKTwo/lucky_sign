-- V4: Fix column types/lengths/nullability to match JPA @Column annotations
-- Also backfill target_user_id and handle data migration notes

-- ===== Column type fixes =====

-- chat_messages.content: TEXT NOT NULL -> VARCHAR(2000) nullable
-- Entity: @Column(length = 2000) with no nullable=false
ALTER TABLE chat_messages MODIFY COLUMN content VARCHAR(2000);

-- feedbacks.content: TEXT NOT NULL -> VARCHAR(1000) NOT NULL  
-- Entity: @Column(nullable = false, length = 1000)
ALTER TABLE feedbacks MODIFY COLUMN content VARCHAR(1000) NOT NULL;

-- email_logs.subject: VARCHAR(255) NOT NULL -> VARCHAR(128) NOT NULL
-- Entity: @Column(nullable = false, length = 128)
ALTER TABLE email_logs MODIFY COLUMN subject VARCHAR(128) NOT NULL;

-- email_logs.error_message: TEXT -> VARCHAR(500)
-- Entity: @Column(length = 500)
ALTER TABLE email_logs MODIFY COLUMN error_message VARCHAR(500);

-- points_log.change_type: VARCHAR(32) NOT NULL -> VARCHAR(16) NOT NULL
-- Entity: @Column(nullable = false, length = 16)
ALTER TABLE points_log MODIFY COLUMN change_type VARCHAR(16) NOT NULL;

-- ===== Backfill target_user_id =====
-- CheckinRating.targetUserId should be the owner of the checkin record being rated.
-- Join checkin_ratings with checkin_records to populate.

UPDATE checkin_ratings cr
JOIN checkin_records r ON cr.checkin_id = r.id
SET cr.target_user_id = r.user_id
WHERE cr.target_user_id = 0;

-- Remove the DEFAULT 0 now that data is backfilled
-- (MySQL requires re-specifying the full column definition)
ALTER TABLE checkin_ratings MODIFY COLUMN target_user_id BIGINT NOT NULL;

-- ===== Data Migration Notes =====
-- 
-- MENTIONS COLUMN DROP (V3):
-- The `chat_messages.mentions` JSON column was dropped and replaced with 
-- `mentioned_user_ids` VARCHAR(256). This is INTENTIONAL because:
-- 1. The JSON format was never standardized in production
-- 2. Entity uses simple comma-separated user IDs (String mentionedUserIds)
-- 3. Any existing mention data in JSON format is discarded
-- 
-- If production has valuable mention data, a pre-migration script should 
-- extract and convert JSON to comma-separated IDs before running V3.
--
-- IDEMPOTENCY NOTES:
-- V3 table/column renames are NOT idempotent. If re-running migrations on 
-- an already-aligned database, use Flyway baseline or repair.
-- V4 column MODIFYs are idempotent (safe to re-run).
