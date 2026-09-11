-- V3: Align Flyway schema with JPA entity definitions
-- This migration renames tables/columns to match @Entity/@Table/@Column annotations

-- ===== Table renames =====

-- points_logs -> points_log (PointsLog entity: @Table(name = "points_log"))
RENAME TABLE points_logs TO points_log;

-- task_items -> tasks (TaskItem entity: @Table(name = "tasks"))
RENAME TABLE task_items TO tasks;

-- ===== Column renames in chat_messages =====

-- sender_id -> user_id (ChatMessage.userId)
ALTER TABLE chat_messages CHANGE COLUMN sender_id user_id BIGINT;

-- message_type -> type (ChatMessage.type)
ALTER TABLE chat_messages CHANGE COLUMN message_type type VARCHAR(16) NOT NULL;

-- related_checkin_id -> checkin_id (ChatMessage.checkinId)
ALTER TABLE chat_messages CHANGE COLUMN related_checkin_id checkin_id BIGINT;

-- Add nickname column (ChatMessage.nickname)
ALTER TABLE chat_messages ADD COLUMN nickname VARCHAR(64) AFTER user_id;

-- Add image_url column (ChatMessage.imageUrl)
ALTER TABLE chat_messages ADD COLUMN image_url VARCHAR(512) AFTER content;

-- mentions (JSON) -> mentioned_user_ids (VARCHAR) (ChatMessage.mentionedUserIds)
ALTER TABLE chat_messages DROP COLUMN mentions;
ALTER TABLE chat_messages ADD COLUMN mentioned_user_ids VARCHAR(256) AFTER checkin_id;

-- Drop related_draw_id (not in entity)
ALTER TABLE chat_messages DROP COLUMN related_draw_id;

-- ===== Column renames in points_log =====

-- balance -> balance_after (PointsLog.balanceAfter)
ALTER TABLE points_log CHANGE COLUMN balance balance_after INT NOT NULL;

-- ===== Column changes in checkin_ratings =====

-- rater_id -> rater_user_id (CheckinRating.raterUserId)
ALTER TABLE checkin_ratings CHANGE COLUMN rater_id rater_user_id BIGINT NOT NULL;

-- Add target_user_id column (CheckinRating.targetUserId)
ALTER TABLE checkin_ratings ADD COLUMN target_user_id BIGINT NOT NULL DEFAULT 0 AFTER checkin_id;

-- Update unique constraint to match entity
ALTER TABLE checkin_ratings DROP INDEX uk_checkin_rater;
ALTER TABLE checkin_ratings ADD UNIQUE INDEX uk_checkin_rater_user (checkin_id, rater_user_id);

-- ===== Column changes in feedbacks =====

-- Add nickname column (Feedback.nickname)
ALTER TABLE feedbacks ADD COLUMN nickname VARCHAR(32) NOT NULL DEFAULT '' AFTER user_id;

-- Drop contact and status columns (not in entity)
ALTER TABLE feedbacks DROP COLUMN contact;
ALTER TABLE feedbacks DROP COLUMN status;

-- ===== Column changes in email_logs =====

-- recipient -> to_email (EmailLog.toEmail)
ALTER TABLE email_logs CHANGE COLUMN recipient to_email VARCHAR(64) NOT NULL;

-- Add content column (EmailLog.content)
ALTER TABLE email_logs ADD COLUMN content VARCHAR(1000) NOT NULL DEFAULT '' AFTER subject;

-- Drop template_name (not in entity)
ALTER TABLE email_logs DROP COLUMN template_name;

-- ===== Drop tasks.created_at (not in TaskItem entity) =====
ALTER TABLE tasks DROP COLUMN created_at;
