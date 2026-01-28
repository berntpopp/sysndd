-- Fix non_alt_loci_set columns to match current upstream HGNC schema
--
-- Two issues:
-- 1. HGNC renamed "rna_central_ids" (plural) to "rna_central_id" (singular).
--    DBI::dbAppendTable() requires exact column name matches.
-- 2. Several VARCHAR columns are too narrow for current HGNC data:
--    - rna_central_id: max 13 chars (was VARCHAR(10)), e.g. "URS00007E4F6E"
--    - omim_id: max 20 chars (was VARCHAR(10)), e.g. pipe-separated OMIM IDs
--
-- Idempotent: checks column state before altering.

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_hgnc_columns()
BEGIN
    -- Fix 1: Rename rna_central_ids -> rna_central_id (if old name exists)
    IF EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'non_alt_loci_set'
          AND COLUMN_NAME = 'rna_central_ids'
    ) THEN
        ALTER TABLE non_alt_loci_set
            CHANGE COLUMN rna_central_ids rna_central_id VARCHAR(30) NULL;

    -- Fix 1b: Widen rna_central_id if already renamed but still narrow
    ELSEIF EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'non_alt_loci_set'
          AND COLUMN_NAME = 'rna_central_id'
          AND CHARACTER_MAXIMUM_LENGTH < 30
    ) THEN
        ALTER TABLE non_alt_loci_set
            MODIFY COLUMN rna_central_id VARCHAR(30) NULL;
    END IF;

    -- Fix 2: Widen omim_id from VARCHAR(10) to VARCHAR(40)
    IF EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'non_alt_loci_set'
          AND COLUMN_NAME = 'omim_id'
          AND CHARACTER_MAXIMUM_LENGTH < 40
    ) THEN
        ALTER TABLE non_alt_loci_set
            MODIFY COLUMN omim_id VARCHAR(40) NULL;
    END IF;
END //

DELIMITER ;

CALL migrate_hgnc_columns();
DROP PROCEDURE IF EXISTS migrate_hgnc_columns;
