-- Registration requires admin approval before login.
ALTER TABLE users
    ADD COLUMN approval_status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE' AFTER enabled,
    ADD COLUMN pending_circle_id BIGINT NULL AFTER approval_status;

UPDATE users SET approval_status = 'ACTIVE' WHERE approval_status IS NULL OR approval_status = '';

CREATE INDEX idx_users_approval_status ON users (approval_status);
