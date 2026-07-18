-- Migration: 045_add_analysis_snapshot_release
-- Description: Immutable, content-addressed public analysis-snapshot releases (#573).
--   A release freezes canonical-JSON copies of the active coherent public snapshots
--   (functional/phenotype clusters + phenotype-functional correlation) with per-file
--   SHA-256 checksums and dependency lineage. Retained indefinitely; a later refresh
--   mints a NEW release. DOI columns are additive external provenance.

CREATE TABLE IF NOT EXISTS `analysis_snapshot_release` (
  `release_id` VARCHAR(64) NOT NULL,
  `release_version` VARCHAR(32) DEFAULT NULL,
  `title` VARCHAR(255) DEFAULT NULL,
  `status` ENUM('draft','published') NOT NULL DEFAULT 'draft',
  `manifest_schema_version` VARCHAR(16) NOT NULL,
  `content_digest` CHAR(64) NOT NULL,
  `manifest_sha256` CHAR(64) NOT NULL,
  `bundle_sha256` CHAR(64) NOT NULL,
  `bundle_gzip` LONGBLOB NOT NULL,
  `bundle_bytes` BIGINT NOT NULL,
  `source_data_version` VARCHAR(128) DEFAULT NULL,
  `db_release_version` VARCHAR(64) DEFAULT NULL,
  `db_release_commit` VARCHAR(64) DEFAULT NULL,
  `scope_statement` TEXT DEFAULT NULL,
  `license` VARCHAR(64) NOT NULL DEFAULT 'CC-BY-4.0',
  `file_count` INT NOT NULL DEFAULT 0,
  `total_bytes` BIGINT NOT NULL DEFAULT 0,
  `created_by_user_id` INT DEFAULT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `published_at` DATETIME(6) DEFAULT NULL,
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `zenodo_record_id` VARCHAR(32) DEFAULT NULL,
  `zenodo_record_url` VARCHAR(255) DEFAULT NULL,
  `version_doi` VARCHAR(128) DEFAULT NULL,
  `concept_doi` VARCHAR(128) DEFAULT NULL,
  `last_error_message` TEXT DEFAULT NULL,
  PRIMARY KEY (`release_id`),
  KEY `idx_asr_status_created` (`status`, `created_at`),
  KEY `idx_asr_content_digest` (`content_digest`),
  CONSTRAINT `fk_asr_created_by`
    FOREIGN KEY (`created_by_user_id`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_member` (
  `release_id` VARCHAR(64) NOT NULL,
  `analysis_type` VARCHAR(64) NOT NULL,
  `parameter_hash` CHAR(64) NOT NULL,
  `snapshot_id` BIGINT NOT NULL,
  `input_hash` CHAR(64) NOT NULL,
  `payload_hash` CHAR(64) NOT NULL,
  `schema_version` VARCHAR(16) NOT NULL,
  `reproducibility_hash` CHAR(64) DEFAULT NULL,
  `role` ENUM('layer','dependency') NOT NULL DEFAULT 'layer',
  PRIMARY KEY (`release_id`, `analysis_type`, `parameter_hash`),
  KEY `idx_asrm_snapshot` (`snapshot_id`),
  CONSTRAINT `fk_asrm_release`
    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_file` (
  `release_id` VARCHAR(64) NOT NULL,
  `file_path` VARCHAR(255) NOT NULL,
  `content_sha256` CHAR(64) NOT NULL,
  `byte_size` INT NOT NULL,
  `media_type` VARCHAR(64) NOT NULL DEFAULT 'application/json',
  `content_gzip` LONGBLOB NOT NULL,
  PRIMARY KEY (`release_id`, `file_path`),
  KEY `idx_asrf_sha256` (`content_sha256`),
  CONSTRAINT `fk_asrf_release`
    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
