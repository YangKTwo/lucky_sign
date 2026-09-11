-- Initial schema for lucky_sign
-- This migration establishes the baseline schema.
-- If upgrading from an existing database, use baseline-on-migrate.

CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(64) NOT NULL UNIQUE,
    nickname VARCHAR(32) NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    points INT NOT NULL DEFAULT 0,
    title VARCHAR(32) NOT NULL DEFAULT '签到萌新',
    streak_days INT NOT NULL DEFAULT 0,
    total_completed_days INT NOT NULL DEFAULT 0,
    miss_streak_days INT NOT NULL DEFAULT 0,
    avatar_url VARCHAR(512),
    last_checkin_date DATE,
    tag VARCHAR(16) NOT NULL DEFAULT 'NONE',
    role VARCHAR(16) NOT NULL DEFAULT 'USER',
    token_version BIGINT NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    version BIGINT DEFAULT 0,
    INDEX idx_users_email (email),
    INDEX idx_users_tag (tag)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS circles (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NOT NULL,
    owner_id BIGINT NOT NULL,
    max_members INT NOT NULL DEFAULT 10,
    member_count INT NOT NULL DEFAULT 0,
    invite_code VARCHAR(16) UNIQUE,
    status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_circles_invite_code (invite_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS circle_members (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    circle_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role VARCHAR(16) NOT NULL DEFAULT 'MEMBER',
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_circle_user (circle_id, user_id),
    INDEX idx_circle_members_circle (circle_id),
    INDEX idx_circle_members_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS daily_draws (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    draw_date DATE NOT NULL,
    level VARCHAR(8) NOT NULL,
    fortune_text VARCHAR(128) NOT NULL,
    task_id BIGINT NOT NULL,
    task_content VARCHAR(255) NOT NULL,
    base_points INT NOT NULL,
    lucky_star BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
    version BIGINT DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_date (user_id, draw_date),
    INDEX idx_daily_draws_user (user_id),
    INDEX idx_daily_draws_date (draw_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS checkin_records (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    draw_id BIGINT NOT NULL,
    checkin_date DATE NOT NULL,
    level VARCHAR(8) NOT NULL,
    task_content VARCHAR(255) NOT NULL,
    text_content VARCHAR(500),
    image_url VARCHAR(512),
    points_earned INT NOT NULL,
    streak_snapshot INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_checkin_date (user_id, checkin_date),
    INDEX idx_checkin_records_user (user_id),
    INDEX idx_checkin_records_date (checkin_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS task_items (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    content VARCHAR(255) NOT NULL,
    difficulty VARCHAR(16) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fortune_copies (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    level VARCHAR(8) NOT NULL,
    content VARCHAR(128) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fortune_copies_level (level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS circle_daily_stars (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    circle_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    star_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_circle_star_date (circle_id, star_date),
    INDEX idx_circle_daily_stars_circle (circle_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS points_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    change_type VARCHAR(32) NOT NULL,
    delta INT NOT NULL,
    balance INT NOT NULL,
    related_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_points_logs_user (user_id),
    INDEX idx_points_logs_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chat_messages (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    circle_id BIGINT NOT NULL,
    sender_id BIGINT,
    message_type VARCHAR(16) NOT NULL,
    content TEXT NOT NULL,
    related_checkin_id BIGINT,
    related_draw_id BIGINT,
    mentions JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_chat_messages_circle (circle_id),
    INDEX idx_chat_messages_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS checkin_ratings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    checkin_id BIGINT NOT NULL,
    rater_id BIGINT NOT NULL,
    score INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_checkin_rater (checkin_id, rater_id),
    INDEX idx_checkin_ratings_checkin (checkin_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS feedbacks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    content TEXT NOT NULL,
    contact VARCHAR(128),
    status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_feedbacks_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS email_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    recipient VARCHAR(128) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    template_name VARCHAR(64),
    status VARCHAR(16) NOT NULL,
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email_logs_recipient (recipient)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
