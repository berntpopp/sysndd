-- 049_add_evidence_origin_review.sql
-- Additive: normalized `origin_review_id` on variation_ontology_evidence (issue #608).
--
-- WHY A COLUMN AND NOT A KEY INSIDE evidence_json:
--   The February 2026 import batches recorded which review each annotation was
--   written to. That fact is what separates an imported term still sitting on its
--   original review ("unchanged") from one carried into a later curator review
--   ("moved", i.e. laundered -- the term now wears a curator's name and a recent
--   review date while resting on unchanged machine evidence). Distinguishing those
--   is the whole point of the backfill, so it has to be queryable.
--   evidence_json cannot serve that: the hot read path
--   (api/functions/variation-provenance-repository.R) deliberately does NOT select
--   evidence_json, so a JSON key is reachable only from the evidence-detail
--   endpoint, one assertion at a time. A column makes
--   "which imported terms have moved" a single indexed join.
--
-- WHY NULLABLE:
--   Only import-derived evidence has an origin review. Curator suggestions and any
--   future source have none, and pre-049 rows read NULL. NOT NULL would force a
--   sentinel, which is a fabricated provenance record -- exactly what #608 exists
--   to stop.
--
-- WHY NO FOREIGN KEY TO ndd_entity_review:
--   Two independent reasons, both deliberate.
--   1. This is a historical audit fact, not a live reference. "The import wrote to
--      review N" stays true after review N is deleted or superseded. An FK would
--      make the audit trail deletable-by-cascade or block the delete outright --
--      both wrong for a provenance record.
--   2. Lock amplification. The backfill inserts ~8,083 evidence rows; an FK takes a
--      shared parent-row lock on ndd_entity_review for every one of them, held to
--      commit. ndd_entity_review is written by every review save, so that is a
--      direct contention path against live curation. See the backfill runbook's
--      adversarial review, finding 3.
--
-- Idempotent + restore-drift safe: the information_schema guards mirror migrations
-- 043 and 046. A rerun sees the column/index already present and no-ops; an absent
-- variation_ontology_evidence table (i.e. 047 never applied) is skipped rather than
-- erroring, matching the skip-not-error behaviour of migration 048.
-- Note: MySQL 8 has no `ADD COLUMN IF NOT EXISTS` (that is MariaDB-only), which is
-- why these are PREPARE/EXECUTE guards rather than inline IF NOT EXISTS clauses.

SET @vope_table_exists := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'variation_ontology_evidence'
);

SET @origin_col_exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'variation_ontology_evidence'
    AND COLUMN_NAME = 'origin_review_id'
);

SET @ddl := IF(@vope_table_exists = 1 AND @origin_col_exists = 0,
  'ALTER TABLE `variation_ontology_evidence` ADD COLUMN `origin_review_id` INT NULL AFTER `source_version`',
  'SELECT 1');

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @origin_idx_exists := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'variation_ontology_evidence'
    AND INDEX_NAME = 'idx_origin_review'
);

SET @ddl2 := IF(@vope_table_exists = 1 AND @origin_idx_exists = 0,
  'ALTER TABLE `variation_ontology_evidence` ADD KEY `idx_origin_review` (`origin_review_id`)',
  'SELECT 1');

PREPARE stmt2 FROM @ddl2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;
