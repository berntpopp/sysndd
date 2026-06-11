-- 033_add_metadata_lookup_admin_columns.sql
-- Adds SysNDD-managed lifecycle columns to the small controlled-vocabulary
-- lookup tables so the new Admin "Manage Metadata" view can soft-delete and
-- order rows (issue #32).
--
-- Scope (see AGENTS.md "metadata-refresh" notes): only the genuinely
-- SysNDD-managed lookups gain an `is_active` soft-delete flag and a `sort`
-- column. Ontology-derived tables (phenotype_list/HPO, disease_ontology_set,
-- non_alt_loci_set/HGNC, variation_ontology_list/VariO, mode_of_inheritance_list/HPO)
-- already carry their own lifecycle columns and are refreshed from source, so
-- they are NOT touched here.
--
-- Columns are added with plain `ADD COLUMN`: the migration runner applies each
-- migration at most once (schema_version ledger) and the target DB is MySQL 8.4,
-- which does NOT support the MariaDB-only `ADD COLUMN IF NOT EXISTS` shortcut.

-- modifier_list: phenotype/variation modifiers (present, uncertain, ...).
-- SysNDD-managed; previously had no soft-delete or ordering column.
ALTER TABLE `modifier_list`
  ADD COLUMN `is_active` tinyint NOT NULL DEFAULT 1 AFTER `allowed_variation`;

ALTER TABLE `modifier_list`
  ADD COLUMN `sort` int DEFAULT NULL AFTER `is_active`;

-- ndd_entity_status_categories_list: classification categories
-- (Definitive, Moderate, Limited, Refuted, not applicable). SysNDD-managed.
ALTER TABLE `ndd_entity_status_categories_list`
  ADD COLUMN `is_active` tinyint NOT NULL DEFAULT 1 AFTER `category`;

ALTER TABLE `ndd_entity_status_categories_list`
  ADD COLUMN `sort` int DEFAULT NULL AFTER `is_active`;

-- Backfill `sort` from the existing primary keys so the admin table has a
-- stable initial ordering (NULLs sort last in the API query otherwise).
UPDATE `modifier_list` SET `sort` = `modifier_id` WHERE `sort` IS NULL;

UPDATE `ndd_entity_status_categories_list` SET `sort` = `category_id` WHERE `sort` IS NULL;
