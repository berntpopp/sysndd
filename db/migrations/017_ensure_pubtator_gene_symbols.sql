-- Ensure gene_symbols column exists on pubtator_search_cache
--
-- Migration 005 added this column, but some deployments may have missed it
-- (e.g., the column was dropped or the migration didn't run).
-- This migration is idempotent: it only adds the column if it doesn't exist.

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_017_ensure_gene_symbols()
BEGIN
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
END //

CALL migrate_017_ensure_gene_symbols() //

DROP PROCEDURE IF EXISTS migrate_017_ensure_gene_symbols //
