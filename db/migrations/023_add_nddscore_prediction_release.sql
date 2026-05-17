-- Migration: 023_add_nddscore_prediction_release
-- Description: Adds the NDDScore machine-learning prediction layer: release metadata,
--              per-gene predictions, per-gene-HPO predictions, and per-HPO-term metadata,
--              plus *_current views resolving the single active release.
--              NDDScore is a model-derived prediction layer and is kept separate from
--              curated SysNDD evidence. DDL adapted from the Zenodo dataset's shipped
--              nddscore_schema.sql; collation forced to utf8mb4_unicode_ci (repo
--              convention, see migration 020); nddscore_release extended with SysNDD
--              provenance + operational columns. is_active is SysNDD-controlled.

CREATE TABLE IF NOT EXISTS `nddscore_release` (
  `release_id` VARCHAR(64) NOT NULL,
  `score_schema_version` VARCHAR(16) NOT NULL,
  `version` VARCHAR(32) DEFAULT NULL,
  `release_created_at` DATETIME(6) DEFAULT NULL,
  `n_genes` INT NOT NULL,
  `n_hpo_predictions` INT NOT NULL,
  `n_hpo_terms` INT NOT NULL,
  `n_features` INT NOT NULL,
  `hpo_threshold` DECIMAL(6,5) NOT NULL,
  `calibration_method` VARCHAR(64) DEFAULT NULL,
  `ndd_model_created_at` VARCHAR(64) DEFAULT NULL,
  `phenotype_model_created_at` VARCHAR(64) DEFAULT NULL,
  `inheritance_model_created_at` VARCHAR(64) DEFAULT NULL,
  `ndd_performance_json` JSON DEFAULT NULL,
  `phenotype_performance_json` JSON DEFAULT NULL,
  `inheritance_performance_json` JSON DEFAULT NULL,
  `data_versions_json` JSON DEFAULT NULL,
  `artifact_hashes_json` JSON DEFAULT NULL,
  `zenodo_record_url` VARCHAR(255) DEFAULT NULL,
  `version_doi` VARCHAR(128) DEFAULT NULL,
  `concept_doi` VARCHAR(128) DEFAULT NULL,
  `source_record_id` VARCHAR(32) DEFAULT NULL,
  `source_archive_name` VARCHAR(255) DEFAULT NULL,
  `source_archive_checksum` VARCHAR(64) DEFAULT NULL,
  `source_archive_bytes` BIGINT DEFAULT NULL,
  `is_active` TINYINT NOT NULL DEFAULT 0,
  `import_status` ENUM('pending','importing','validated','active','superseded','failed')
      NOT NULL DEFAULT 'pending',
  `imported_by` INT DEFAULT NULL,
  `import_job_id` CHAR(36) DEFAULT NULL,
  `import_started_at` DATETIME(6) DEFAULT NULL,
  `import_completed_at` DATETIME(6) DEFAULT NULL,
  `activated_at` DATETIME(6) DEFAULT NULL,
  `last_error_message` TEXT DEFAULT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
      ON UPDATE CURRENT_TIMESTAMP(6),
  `active_release_slot` TINYINT
      GENERATED ALWAYS AS (CASE WHEN `is_active` = 1 THEN 1 ELSE NULL END) STORED,
  PRIMARY KEY (`release_id`),
  UNIQUE KEY `idx_nddscore_release_active_slot` (`active_release_slot`),
  KEY `idx_nddscore_release_status` (`import_status`),
  CONSTRAINT `fk_nddscore_release_imported_by`
      FOREIGN KEY (`imported_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nddscore_gene_prediction` (
  `release_id` VARCHAR(64) NOT NULL,
  `hgnc_id` VARCHAR(10) NOT NULL,
  `gene_symbol` VARCHAR(50) NOT NULL,
  `ensembl_gene_id` VARCHAR(20) DEFAULT NULL,
  `ndd_score` DECIMAL(8,7) NOT NULL,
  `ndd_score_std` DECIMAL(8,7) DEFAULT NULL,
  `ndd_score_iqr` DECIMAL(8,7) DEFAULT NULL,
  `bag_agreement` DECIMAL(8,7) DEFAULT NULL,
  `rank` INT NOT NULL,
  `percentile` DECIMAL(8,5) NOT NULL,
  `risk_tier` VARCHAR(20) NOT NULL,
  `confidence_tier` VARCHAR(20) NOT NULL,
  `known_sysndd_gene` TINYINT DEFAULT NULL,
  `model_split` VARCHAR(20) DEFAULT NULL,
  `inheritance_ad_probability` DECIMAL(8,7) DEFAULT NULL,
  `inheritance_ar_probability` DECIMAL(8,7) DEFAULT NULL,
  `inheritance_xld_probability` DECIMAL(8,7) DEFAULT NULL,
  `inheritance_xlr_probability` DECIMAL(8,7) DEFAULT NULL,
  `top_inheritance_mode` VARCHAR(8) DEFAULT NULL,
  `called_inheritance_modes` JSON DEFAULT NULL,
  `n_predicted_hpo` INT NOT NULL DEFAULT 0,
  `top_hpo_predictions_json` JSON DEFAULT NULL,
  `shap_clinical` DOUBLE DEFAULT NULL,
  `shap_constraint` DOUBLE DEFAULT NULL,
  `shap_expression` DOUBLE DEFAULT NULL,
  `shap_network` DOUBLE DEFAULT NULL,
  `shap_conservation` DOUBLE DEFAULT NULL,
  `shap_other` DOUBLE DEFAULT NULL,
  `dominant_shap_group` VARCHAR(32) DEFAULT NULL,
  `top_features_json` JSON DEFAULT NULL,
  `prediction_note` TEXT DEFAULT NULL,
  PRIMARY KEY (`release_id`, `hgnc_id`),
  KEY `idx_nddscore_gene_symbol` (`release_id`, `gene_symbol`),
  KEY `idx_nddscore_gene_rank` (`release_id`, `rank`),
  KEY `idx_nddscore_gene_risk` (`release_id`, `risk_tier`),
  KEY `idx_nddscore_gene_confidence` (`release_id`, `confidence_tier`),
  CONSTRAINT `fk_nddscore_gene_release`
      FOREIGN KEY (`release_id`) REFERENCES `nddscore_release` (`release_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nddscore_hpo_prediction` (
  `release_id` VARCHAR(64) NOT NULL,
  `hgnc_id` VARCHAR(10) NOT NULL,
  `gene_symbol` VARCHAR(50) NOT NULL,
  `phenotype_id` VARCHAR(10) NOT NULL,
  `phenotype_name` VARCHAR(255) NOT NULL,
  `probability` DECIMAL(8,7) NOT NULL,
  `rank_for_gene` INT NOT NULL,
  `passes_default_threshold` TINYINT NOT NULL DEFAULT 1,
  `term_auc_roc` DECIMAL(8,7) DEFAULT NULL,
  `term_auc_pr` DECIMAL(8,7) DEFAULT NULL,
  `term_training_support` INT DEFAULT NULL,
  PRIMARY KEY (`release_id`, `hgnc_id`, `phenotype_id`),
  KEY `idx_nddscore_hpo_phenotype` (`release_id`, `phenotype_id`),
  KEY `idx_nddscore_hpo_probability` (`release_id`, `probability`),
  CONSTRAINT `fk_nddscore_hpo_gene`
      FOREIGN KEY (`release_id`, `hgnc_id`)
      REFERENCES `nddscore_gene_prediction` (`release_id`, `hgnc_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nddscore_hpo_term` (
  `release_id` VARCHAR(64) NOT NULL,
  `phenotype_id` VARCHAR(10) NOT NULL,
  `phenotype_name` VARCHAR(255) NOT NULL,
  `term_auc_roc` DECIMAL(8,7) DEFAULT NULL,
  `term_auc_pr` DECIMAL(8,7) DEFAULT NULL,
  `term_training_support` INT DEFAULT NULL,
  `is_in_ndd_subtree` TINYINT DEFAULT NULL,
  PRIMARY KEY (`release_id`, `phenotype_id`),
  CONSTRAINT `fk_nddscore_hpo_term_release`
      FOREIGN KEY (`release_id`) REFERENCES `nddscore_release` (`release_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE OR REPLACE VIEW `nddscore_gene_prediction_current` AS
SELECT gp.*
FROM `nddscore_gene_prediction` gp
JOIN `nddscore_release` r ON r.`release_id` = gp.`release_id`
WHERE r.`is_active` = 1;

CREATE OR REPLACE VIEW `nddscore_hpo_prediction_current` AS
SELECT hp.*
FROM `nddscore_hpo_prediction` hp
JOIN `nddscore_release` r ON r.`release_id` = hp.`release_id`
WHERE r.`is_active` = 1;

CREATE OR REPLACE VIEW `nddscore_hpo_term_current` AS
SELECT ht.*
FROM `nddscore_hpo_term` ht
JOIN `nddscore_release` r ON r.`release_id` = ht.`release_id`
WHERE r.`is_active` = 1;
