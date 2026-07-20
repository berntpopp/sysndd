-- 046_add_analysis_snapshot_generator_provenance.sql
-- Additive: immutable generator provenance for analysis snapshots (issue #585).
-- Stored OUTSIDE every identity hash (payload_hash/input_hash/cluster_hash), so
-- it changes no membership, cluster_hash, or LLM summary. Nullable; pre-046
-- snapshots read NULL and omit the generator block. Idempotent + restore-drift
-- safe (information_schema guard mirrors migration 043).
SET @col_exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'analysis_snapshot_manifest'
    AND COLUMN_NAME = 'generator_json'
);
SET @ddl := IF(@col_exists = 0,
  'ALTER TABLE analysis_snapshot_manifest ADD COLUMN generator_json JSON NULL AFTER package_versions_json',
  'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
