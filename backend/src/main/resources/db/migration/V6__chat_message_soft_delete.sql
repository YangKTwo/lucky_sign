-- Soft-delete / recall metadata for chat messages
ALTER TABLE chat_messages
    ADD COLUMN deleted_at TIMESTAMP NULL,
    ADD COLUMN deleted_by BIGINT NULL,
    ADD COLUMN delete_reason VARCHAR(32) NULL;
