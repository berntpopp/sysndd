-- Migration: 041_add_analysis_reproducibility
-- Description: Per-clustering-snapshot reproducibility bundle (#512). Stores the
--   gzipped canonical JSON of the inputs needed to INDEPENDENTLY recompute the
--   served separation metric (functional modularity / phenotype silhouette):
--   the full LCC edge list + complete membership (functional) or the MCA
--   coordinate matrix + membership (phenotype), plus params, the served metric,
--   and a SHA-256 reproducibility_hash over the canonical pre-gzip JSON.
--
-- One row per clustering snapshot (UNIQUE on snapshot_id). Cascades on delete of
-- the parent manifest row. `snapshot_id` is BIGINT to match
-- `analysis_snapshot_manifest.snapshot_id` (an INT reference would fail with
-- errno 1215 "Cannot add foreign key constraint").

CREATE TABLE IF NOT EXISTS `analysis_snapshot_reproducibility` (
  `reproducibility_id`   INT NOT NULL AUTO_INCREMENT,
  `snapshot_id`          BIGINT NOT NULL,
  `kind`                 VARCHAR(32) NOT NULL,
  `bundle_gzip_json`     LONGBLOB NOT NULL,
  `reproducibility_hash` CHAR(64) NOT NULL,
  `byte_size`            INT NOT NULL,
  `created_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`reproducibility_id`),
  UNIQUE KEY `uq_repro_snapshot` (`snapshot_id`),
  KEY `idx_repro_hash` (`reproducibility_hash`),
  CONSTRAINT `fk_repro_snapshot`
    FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
