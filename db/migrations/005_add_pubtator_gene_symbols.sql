-- Add gene_symbols column to pubtator_search_cache for pre-computed human gene symbols
--
-- This stores a comma-separated list of human gene symbols (from HGNC/non_alt_loci_set)
-- that are mentioned in each publication. Computed during pubtator_db_update by:
--   1. Extracting Gene annotations from pubtator_annotation_cache
--   2. Joining with non_alt_loci_set on normalized_id = entrez_id (NCBI Gene ID)
--   3. Aggregating unique gene symbols per search_id
--
-- This approach filters for human genes by using the HGNC gene list rather than
-- relying on species annotations, which may be context-dependent (e.g., mouse models).
--
-- Idempotent: Uses stored procedure to check column existence before ALTER

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_005_pubtator_gene_symbols()
BEGIN
    -- Add gene_symbols column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_search_cache'
          AND COLUMN_NAME = 'gene_symbols'
    ) THEN
        ALTER TABLE pubtator_search_cache
            ADD COLUMN gene_symbols TEXT NULL
            COMMENT 'Comma-separated human gene symbols from HGNC';
    END IF;

    -- Add index on search_id to annotation_cache if not exists (for faster joins)
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_annotation_cache'
          AND INDEX_NAME = 'idx_annotation_search_id'
    ) THEN
        CREATE INDEX idx_annotation_search_id
            ON pubtator_annotation_cache(search_id);
    END IF;

    -- Add index on type column for faster Gene filtering
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'pubtator_annotation_cache'
          AND INDEX_NAME = 'idx_annotation_type'
    ) THEN
        CREATE INDEX idx_annotation_type
            ON pubtator_annotation_cache(type);
    END IF;
END //

CALL migrate_005_pubtator_gene_symbols() //

DROP PROCEDURE IF EXISTS migrate_005_pubtator_gene_symbols //
