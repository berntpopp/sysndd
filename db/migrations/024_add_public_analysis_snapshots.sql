-- Migration: 024_add_public_analysis_snapshots
-- Description: Durable public derived-analysis snapshots for API and MCP reads.

CREATE TABLE IF NOT EXISTS `analysis_snapshot_manifest` (
  `snapshot_id` BIGINT NOT NULL AUTO_INCREMENT,
  `analysis_type` VARCHAR(64) NOT NULL,
  `parameter_hash` CHAR(64) NOT NULL,
  `schema_version` VARCHAR(16) NOT NULL,
  `data_class` VARCHAR(64) NOT NULL,
  `status` ENUM('pending','validated','public_ready','superseded','failed') NOT NULL DEFAULT 'pending',
  `public_ready` TINYINT NOT NULL DEFAULT 0,
  `public_ready_slot` TINYINT
      GENERATED ALWAYS AS (CASE WHEN `public_ready` = 1 THEN 1 ELSE NULL END) STORED,
  `generated_by_job_id` CHAR(36) DEFAULT NULL,
  `generated_at` DATETIME(6) DEFAULT NULL,
  `activated_at` DATETIME(6) DEFAULT NULL,
  `superseded_at` DATETIME(6) DEFAULT NULL,
  `stale_after` DATETIME(6) DEFAULT NULL,
  `source_versions_json` JSON DEFAULT NULL,
  `source_data_version` VARCHAR(128) DEFAULT NULL,
  `parameters_json` JSON NOT NULL,
  `input_hash` CHAR(64) NOT NULL,
  `payload_hash` CHAR(64) NOT NULL,
  `algorithm_name` VARCHAR(64) DEFAULT NULL,
  `algorithm_version` VARCHAR(64) DEFAULT NULL,
  `package_versions_json` JSON DEFAULT NULL,
  `row_counts_json` JSON DEFAULT NULL,
  `warnings_json` JSON DEFAULT NULL,
  `last_error_message` TEXT DEFAULT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
      ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`snapshot_id`),
  UNIQUE KEY `idx_analysis_snapshot_public_ready`
      (`analysis_type`, `parameter_hash`, `public_ready_slot`),
  KEY `idx_analysis_snapshot_lookup`
      (`analysis_type`, `parameter_hash`, `public_ready`, `status`),
  KEY `idx_analysis_snapshot_generated_at` (`analysis_type`, `generated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_network_node` (
  `snapshot_id` BIGINT NOT NULL,
  `hgnc_id` VARCHAR(10) NOT NULL,
  `symbol` VARCHAR(50) DEFAULT NULL,
  `cluster_id` VARCHAR(32) DEFAULT NULL,
  `category` VARCHAR(64) DEFAULT NULL,
  `degree` INT DEFAULT NULL,
  `x` DOUBLE DEFAULT NULL,
  `y` DOUBLE DEFAULT NULL,
  `layout_x` DOUBLE DEFAULT NULL,
  `layout_y` DOUBLE DEFAULT NULL,
  `igraph_x` DOUBLE DEFAULT NULL,
  `igraph_y` DOUBLE DEFAULT NULL,
  `display_order` INT DEFAULT NULL,
  PRIMARY KEY (`snapshot_id`, `hgnc_id`),
  KEY `idx_analysis_snapshot_network_node_symbol` (`symbol`),
  CONSTRAINT `fk_analysis_snapshot_network_node_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_network_edge` (
  `snapshot_id` BIGINT NOT NULL,
  `edge_rank` INT NOT NULL,
  `source_hgnc_id` VARCHAR(10) NOT NULL,
  `target_hgnc_id` VARCHAR(10) NOT NULL,
  `confidence` DECIMAL(8,7) NOT NULL,
  PRIMARY KEY (`snapshot_id`, `edge_rank`),
  KEY `idx_analysis_snapshot_network_edge_source` (`snapshot_id`, `source_hgnc_id`),
  KEY `idx_analysis_snapshot_network_edge_target` (`snapshot_id`, `target_hgnc_id`),
  CONSTRAINT `fk_analysis_snapshot_network_edge_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_cluster` (
  `snapshot_id` BIGINT NOT NULL,
  `cluster_kind` VARCHAR(64) NOT NULL,
  `cluster_id` VARCHAR(64) NOT NULL,
  `cluster_hash` CHAR(64) DEFAULT NULL,
  `cluster_size` INT DEFAULT NULL,
  `label` VARCHAR(255) DEFAULT NULL,
  `metadata_json` JSON DEFAULT NULL,
  PRIMARY KEY (`snapshot_id`, `cluster_kind`, `cluster_id`),
  KEY `idx_analysis_snapshot_cluster_hash` (`cluster_hash`),
  CONSTRAINT `fk_analysis_snapshot_cluster_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_cluster_member` (
  `snapshot_id` BIGINT NOT NULL,
  `cluster_kind` VARCHAR(64) NOT NULL,
  `cluster_id` VARCHAR(64) NOT NULL,
  `member_rank` INT NOT NULL,
  `entity_id` INT DEFAULT NULL,
  `hgnc_id` VARCHAR(10) DEFAULT NULL,
  `symbol` VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (`snapshot_id`, `cluster_kind`, `cluster_id`, `member_rank`),
  KEY `idx_analysis_snapshot_cluster_member_gene` (`snapshot_id`, `hgnc_id`),
  KEY `idx_analysis_snapshot_cluster_member_entity` (`snapshot_id`, `entity_id`),
  CONSTRAINT `fk_analysis_snapshot_cluster_member_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_correlation` (
  `snapshot_id` BIGINT NOT NULL,
  `row_rank` INT NOT NULL,
  `correlation_kind` VARCHAR(64) NOT NULL,
  `x_key` VARCHAR(255) NOT NULL,
  `y_key` VARCHAR(255) NOT NULL,
  `value` DECIMAL(8,5) NOT NULL,
  `abs_value` DECIMAL(8,5) NOT NULL,
  `metadata_json` JSON DEFAULT NULL,
  PRIMARY KEY (`snapshot_id`, `row_rank`),
  KEY `idx_analysis_snapshot_correlation_x` (`snapshot_id`, `x_key`),
  KEY `idx_analysis_snapshot_correlation_y` (`snapshot_id`, `y_key`),
  CONSTRAINT `fk_analysis_snapshot_correlation_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
