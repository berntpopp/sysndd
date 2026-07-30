-- Migration: 047_add_variation_ontology_provenance
-- Description: Additive assertion + evidence tables recording where a variation-ontology
--   annotation came from (issue #608). An assertion is one (entity_id, vario_id, modifier_id)
--   claim carrying curator-facing state; evidence rows hang off it, one per source batch, so
--   two independent sources corroborating a term is representable. modifier_id is part of the
--   assertion identity because modifier_list defines both `present` (1) and `absent` (5) as
--   valid for variation, and those are two different claims.
--
--   These are deliberately NOT columns on the review-linked variation-ontology join table
--   (see api/functions/ontology-repository.R), because that table is DELETEd and re-INSERTed
--   wholesale on every review save, which would destroy a provenance column on every save.
--   There is deliberately no `curator` value in the evidence `source_type` ENUM: a
--   curator-authored annotation has no assertion row at all, so a curator evidence row could
--   never exist.
--
-- Charset ruling (read before "simplifying" this back to a static charset):
--   The `vario_id` FK column must exactly match the charset/collation of the referenced
--   variation_ontology_list.vario_id column, or MySQL refuses the FK with "Referencing column
--   ... and referenced column ... in foreign key constraint ... are incompatible." That
--   referenced column is NOT guaranteed to be the utf8mb3 the base schema
--   (000_initialize_base_schema.sql) declares: in this repo's own sysndd_db_test (MySQL
--   8.4.11), creation/restore drift has left it as `varchar(10)` with
--   CHARACTER_SET_NAME=utf8mb4, COLLATION_NAME=utf8mb4_0900_ai_ci — the same class of drift as
--   the documented disease_ontology_mapping collation trap (see AGENTS.md). Verified probes
--   against that database: `vario_id VARCHAR(10)` under a static
--   `DEFAULT CHARSET=utf8mb3` table fails FK creation with the incompatibility error above;
--   `vario_id VARCHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci` (matching the live
--   column) succeeds. Therefore this migration derives vario_id's charset/collation from
--   information_schema.COLUMNS at migration time and interpolates them into the CREATE TABLE
--   DDL, falling back to utf8mb3 / utf8mb3_general_ci (the base-schema default) only when the
--   lookup yields nothing (e.g. variation_ontology_list is absent). This makes the FK creatable
--   whether the target environment's variation_ontology_list is utf8mb3 (base schema /
--   production) or utf8mb4 (drifted). Only vario_id needs this treatment: the other three FKs
--   (entity_id -> ndd_entity, modifier_id -> modifier_list, confirmed_by -> user) are all on
--   INT columns, where charset is irrelevant. The table-level DEFAULT CHARSET stays utf8mb3;
--   the explicit per-column override on vario_id wins for that column only.
--
--   Because the DDL must be built dynamically for that reason anyway, both CREATE TABLE
--   statements use the repo's existing dynamic-DDL idiom (see 043_add_user_session_epoch.sql
--   and 046_add_analysis_snapshot_generator_provenance.sql): guard on an information_schema
--   existence count, PREPARE/EXECUTE/DEALLOCATE a @ddl variable built with CONCAT(). This is
--   idempotent and restore-drift safe: a rerun sees the table already present and no-ops.
--   ENUM/CHECK string literals inside the CONCAT() pieces use double quotes (not single quotes)
--   so they don't need escaping inside the single-quoted DDL fragments they live in.

SET @vario_charset := IFNULL((
  SELECT CHARACTER_SET_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'variation_ontology_list'
    AND COLUMN_NAME = 'vario_id'
), 'utf8mb3');

SET @vario_collation := IFNULL((
  SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'variation_ontology_list'
    AND COLUMN_NAME = 'vario_id'
), 'utf8mb3_general_ci');

SET @vopa_exists := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'variation_ontology_assertion'
);

SET @ddl := IF(@vopa_exists = 0, CONCAT(
  'CREATE TABLE `variation_ontology_assertion` (',
    '`assertion_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,',
    '`entity_id` INT NOT NULL,',
    '`vario_id` VARCHAR(10) CHARACTER SET ', @vario_charset, ' COLLATE ', @vario_collation, ' NOT NULL,',
    '`modifier_id` INT NOT NULL,',
    '`state` ENUM("suggested","active_unconfirmed","confirmed","rejected") NOT NULL,',
    '`confirmed_by` INT NULL,',
    '`confirmed_at` DATETIME NULL,',
    '`rejected_reason` VARCHAR(255) NULL,',
    '`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,',
    '`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,',
    'PRIMARY KEY (`assertion_id`),',
    'UNIQUE KEY `uq_assertion` (`entity_id`, `vario_id`, `modifier_id`),',
    'KEY `idx_state` (`state`),',
    'CONSTRAINT `chk_confirmed_attribution` CHECK (`state` <> "confirmed" OR (`confirmed_by` IS NOT NULL AND `confirmed_at` IS NOT NULL)),',
    'CONSTRAINT `fk_assertion_entity` FOREIGN KEY (`entity_id`) REFERENCES `ndd_entity` (`entity_id`),',
    'CONSTRAINT `fk_assertion_vario` FOREIGN KEY (`vario_id`) REFERENCES `variation_ontology_list` (`vario_id`),',
    'CONSTRAINT `fk_assertion_modifier` FOREIGN KEY (`modifier_id`) REFERENCES `modifier_list` (`modifier_id`),',
    'CONSTRAINT `fk_assertion_user` FOREIGN KEY (`confirmed_by`) REFERENCES `user` (`user_id`)',
  ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb3'
), 'SELECT 1');

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @vope_exists := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'variation_ontology_evidence'
);

SET @ddl2 := IF(@vope_exists = 0, CONCAT(
  'CREATE TABLE `variation_ontology_evidence` (',
    '`evidence_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,',
    '`assertion_id` INT UNSIGNED NOT NULL,',
    '`source_type` ENUM("literature","external_database") NOT NULL,',
    '`source_key` VARCHAR(64) NOT NULL,',
    '`batch_id` VARCHAR(64) NOT NULL,',
    '`source_version` VARCHAR(128) NULL,',
    '`evidence_summary` VARCHAR(255) NOT NULL,',
    '`evidence_strength` TINYINT UNSIGNED NULL,',
    '`evidence_json` JSON NULL,',
    '`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,',
    'PRIMARY KEY (`evidence_id`),',
    'UNIQUE KEY `uq_evidence` (`assertion_id`, `source_key`, `batch_id`),',
    'KEY `idx_strength` (`evidence_strength`),',
    'CONSTRAINT `chk_strength_range` CHECK (`evidence_strength` IS NULL OR `evidence_strength` BETWEEN 0 AND 4),',
    'CONSTRAINT `fk_evidence_assertion` FOREIGN KEY (`assertion_id`) REFERENCES `variation_ontology_assertion` (`assertion_id`) ON DELETE CASCADE',
  ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb3'
), 'SELECT 1');

PREPARE stmt2 FROM @ddl2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;
