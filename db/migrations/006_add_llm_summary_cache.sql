-- Add LLM cluster summary cache tables for AI-generated summaries
--
-- Creates two tables:
-- 1. llm_cluster_summary_cache - stores validated LLM-generated summaries
-- 2. llm_generation_log - audit trail for all generation attempts (success + failure)
--
-- Design decisions:
-- - cluster_hash: SHA256 of sorted gene/entity IDs for cache invalidation
-- - is_current: marks newest version, old versions kept for history
-- - validation_status: pending/validated/rejected for admin workflow
-- - tags: JSON array for searchable keywords with multi-valued index
-- - generation_log: complete audit trail including failed attempts for debugging
--
-- Idempotent: Uses stored procedure with IF NOT EXISTS checks

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_006_llm_summary_cache()
BEGIN
    -- Create llm_cluster_summary_cache table if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'llm_cluster_summary_cache'
    ) THEN
        CREATE TABLE llm_cluster_summary_cache (
            cache_id INT AUTO_INCREMENT PRIMARY KEY,
            cluster_type ENUM('functional', 'phenotype') NOT NULL,
            cluster_number INT NOT NULL,
            cluster_hash VARCHAR(64) NOT NULL COMMENT 'SHA256 of sorted gene/entity IDs',
            model_name VARCHAR(50) NOT NULL,
            prompt_version VARCHAR(20) NOT NULL DEFAULT '1.0',
            summary_json JSON NOT NULL COMMENT 'Full structured response from LLM',
            tags JSON COMMENT 'Extracted tags for search/filtering',
            is_current BOOLEAN NOT NULL DEFAULT TRUE,
            validation_status ENUM('pending', 'validated', 'rejected') NOT NULL DEFAULT 'pending',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            validated_at TIMESTAMP NULL,
            validated_by INT NULL COMMENT 'user_id of validator',
            INDEX idx_cluster_hash (cluster_hash),
            INDEX idx_cluster_type_number (cluster_type, cluster_number),
            INDEX idx_validation_status (validation_status),
            INDEX idx_is_current (is_current)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    END IF;

    -- Create llm_generation_log table if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'llm_generation_log'
    ) THEN
        CREATE TABLE llm_generation_log (
            log_id INT AUTO_INCREMENT PRIMARY KEY,
            cluster_type ENUM('functional', 'phenotype') NOT NULL,
            cluster_number INT NOT NULL,
            cluster_hash VARCHAR(64) NOT NULL,
            model_name VARCHAR(50) NOT NULL,
            prompt_text TEXT NOT NULL,
            response_json JSON COMMENT 'Raw LLM response (success or partial)',
            validation_errors TEXT COMMENT 'Validation failure details',
            tokens_input INT,
            tokens_output INT,
            latency_ms INT,
            status ENUM('success', 'validation_failed', 'api_error', 'timeout') NOT NULL,
            error_message TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_log_cluster_hash (cluster_hash),
            INDEX idx_status (status),
            INDEX idx_created_at (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    END IF;

END //

CALL migrate_006_llm_summary_cache() //

DROP PROCEDURE IF EXISTS migrate_006_llm_summary_cache //

-- NOTE: Multi-valued index on tags JSON array (MySQL 8.0.17+) removed from migration
-- because CAST(... AS ... ARRAY) cannot be used inside stored procedures,
-- and the migration runner doesn't support statements after DELIMITER ;
-- To add this optimization manually, run:
-- CREATE INDEX idx_tags ON llm_cluster_summary_cache((CAST(tags AS CHAR(100) ARRAY)));
-- This enables efficient searching via MEMBER OF or JSON_CONTAINS
