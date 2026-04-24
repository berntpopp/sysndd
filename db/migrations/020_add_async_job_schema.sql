-- Migration: 020_add_async_job_schema
-- Description: Adds durable async job and event storage for MySQL-backed workers

CREATE TABLE async_jobs (
    job_id CHAR(36) NOT NULL PRIMARY KEY,
    job_type VARCHAR(64) NOT NULL,
    queue_name VARCHAR(64) NOT NULL DEFAULT 'default',
    priority INT NOT NULL DEFAULT 100,
    status ENUM('queued', 'running', 'completed', 'failed', 'cancel_requested', 'cancelled') NOT NULL DEFAULT 'queued',
    request_hash CHAR(64) NOT NULL,
    request_payload_json JSON NOT NULL,
    submitted_by INT NULL,
    submitted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    scheduled_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    started_at DATETIME(6) NULL,
    completed_at DATETIME(6) NULL,
    claimed_by_worker VARCHAR(128) NULL,
    claim_token CHAR(36) NULL,
    worker_hostname VARCHAR(255) NULL,
    worker_pid INT NULL,
    last_heartbeat_at DATETIME(6) NULL,
    claim_expires_at DATETIME(6) NULL,
    attempt_count INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 1,
    next_attempt_at DATETIME(6) NULL,
    progress_pct DECIMAL(5, 2) NULL,
    progress_message TEXT NULL,
    last_error_code VARCHAR(128) NULL,
    last_error_message TEXT NULL,
    cancelled_by INT NULL,
    active_request_hash CHAR(64)
        GENERATED ALWAYS AS (
            CASE
                WHEN status IN ('queued', 'running', 'cancel_requested') THEN request_hash
                WHEN status = 'failed'
                     AND attempt_count < max_attempts
                     AND next_attempt_at IS NOT NULL THEN request_hash
                ELSE NULL
            END
        ) STORED,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    result_json JSON NULL,
    KEY idx_async_jobs_claim (status, queue_name, priority, scheduled_at, next_attempt_at, submitted_at),
    KEY idx_async_jobs_claim_expiry (status, claim_expires_at),
    KEY idx_async_jobs_history (submitted_at),
    UNIQUE KEY idx_async_jobs_active_request_hash (job_type, active_request_hash),
    CONSTRAINT fk_async_jobs_submitted_by
        FOREIGN KEY (submitted_by) REFERENCES user(user_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE async_job_events (
    event_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    job_id CHAR(36) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    event_message TEXT NULL,
    event_payload_json JSON NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    KEY idx_async_job_events_job_created (job_id, created_at),
    CONSTRAINT fk_async_job_events_job
        FOREIGN KEY (job_id) REFERENCES async_jobs(job_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
