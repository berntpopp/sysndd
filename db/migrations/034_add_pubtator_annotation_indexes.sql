-- Migration 034: PubtatorNDD annotation/search cache indexes
--
-- The gene-prioritization endpoint (`GET /api/publication/pubtator/genes`)
-- reads `pubtator_human_gene_entity_view`, which joins
-- `pubtator_search_cache` to `pubtator_annotation_cache` on `search_id`,
-- filters `a.type = 'Gene'`, and applies an EXISTS subquery on
-- `(search_id, type='Species', normalized_id='9606')`. The annotation cache
-- had only a PRIMARY key, so every request did a full table scan of all
-- annotation rows (10k+ and growing), which dominated the ~800ms latency.
--
-- Migration 005 intended to add `idx_annotation_search_id` / `idx_annotation_type`
-- via a stored procedure, but those indexes are absent on long-lived databases
-- (the out-of-band db-prep script `db/16_Rcommands_sysndd_db_pubtator_cache_table.R`
-- recreates the cache tables WITHOUT indexes, so any table rebuild dropped them
-- while schema_version still recorded 005 as applied). This migration restores
-- the indexes with composite definitions that supersede the 005 single-column
-- ones, and `db/16_...R` is updated in the same change so a pristine bootstrap
-- gets them too.
--
-- Indexes added:
--   pubtator_annotation_cache(search_id, type)        -- core join + Gene filter
--   pubtator_annotation_cache(type, normalized_id)    -- Species EXISTS + entrez join
--   pubtator_search_cache(query_id)                   -- query-scoped maintenance/backfill
--   pubtator_search_cache(date)                       -- date sort/filter on the table page
--
-- Idempotent: a stored procedure checks INFORMATION_SCHEMA before each
-- CREATE INDEX (MySQL 8.x has no CREATE INDEX IF NOT EXISTS). The procedure
-- guards the table's existence too, so the migration is a no-op on a DB where
-- the cache tables have not been created yet.

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_034_pubtator_annotation_indexes()
BEGIN
    -- idx_annotation_search_type (search_id, type) on pubtator_annotation_cache
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_annotation_cache'
    ) AND NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_annotation_cache'
          AND INDEX_NAME = 'idx_annotation_search_type'
    ) THEN
        CREATE INDEX idx_annotation_search_type
            ON pubtator_annotation_cache(search_id, type);
    END IF;

    -- idx_annotation_type_norm (type, normalized_id) on pubtator_annotation_cache
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_annotation_cache'
    ) AND NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_annotation_cache'
          AND INDEX_NAME = 'idx_annotation_type_norm'
    ) THEN
        CREATE INDEX idx_annotation_type_norm
            ON pubtator_annotation_cache(type, normalized_id);
    END IF;

    -- idx_search_query (query_id) on pubtator_search_cache
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_search_cache'
    ) AND NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_search_cache'
          AND INDEX_NAME = 'idx_search_query'
    ) THEN
        CREATE INDEX idx_search_query
            ON pubtator_search_cache(query_id);
    END IF;

    -- idx_search_date (date) on pubtator_search_cache
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_search_cache'
    ) AND NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_search_cache'
          AND INDEX_NAME = 'idx_search_date'
    ) THEN
        CREATE INDEX idx_search_date
            ON pubtator_search_cache(date);
    END IF;
END //

CALL migrate_034_pubtator_annotation_indexes() //

DROP PROCEDURE IF EXISTS migrate_034_pubtator_annotation_indexes //
