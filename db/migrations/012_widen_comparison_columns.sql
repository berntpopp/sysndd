-- Migration: 012_widen_comparison_columns
-- Description: Widen ndd_database_comparison columns to prevent truncation (#158)
--
-- Issue: Production Comparisons Data Refresh job failed with:
--   "Data too long for column 'publication_id' at row X"
--   "Data too long for column 'phenotype' at row Y"
--
-- Root cause: Databases restored from old backups have VARCHAR columns with
-- insufficient length limits (created before migration 009 established TEXT types).
--
-- Solution: Widen 8 columns to handle long concatenated data:
--   - version: VARCHAR(255) (bounded by filename length)
--   - publication_id: TEXT (concatenated PMIDs can be very long)
--   - phenotype: TEXT (concatenated HPO terms)
--   - disease_ontology_name: TEXT (long disease names from OMIM/Orphanet)
--   - inheritance: TEXT (multiple inheritance terms concatenated)
--   - pathogenicity_mode: TEXT (free-text pathogenicity descriptions)
--   - disease_ontology_id: TEXT (multiple IDs: OMIM:123456;ORPHA:1234;...)
--   - granularity: TEXT (detailed granularity descriptions)
--
-- Idempotent: Uses stored procedure with INFORMATION_SCHEMA checks.
-- On databases where migration 009 already ran, columns are already TEXT/VARCHAR(500)
-- and the checks will skip them. This migration only affects databases restored
-- from old backups where original narrow VARCHARs still exist.
--
-- Fixes: https://github.com/berntpopp/sysndd/issues/158

DELIMITER //

DROP PROCEDURE IF EXISTS migrate_012_widen_comparison_columns //

CREATE PROCEDURE migrate_012_widen_comparison_columns()
BEGIN
    -- Widen version column: VARCHAR(<255) -> VARCHAR(255)
    -- Reason: version strings come from filenames which can be long paths
    -- Keep as VARCHAR(255) since version is bounded data
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'version'
          AND DATA_TYPE = 'varchar'
          AND CHARACTER_MAXIMUM_LENGTH < 255
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN version VARCHAR(255) NULL COMMENT 'Source version/date (can be long path/description)';
    END IF;

    -- Widen publication_id column: VARCHAR -> TEXT
    -- Reason: concatenated PMIDs (e.g., "12345678,23456789,...") can be arbitrarily long
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'publication_id'
          AND DATA_TYPE = 'varchar'
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN publication_id TEXT NULL COMMENT 'Publication IDs (PMIDs)';
    END IF;

    -- Widen phenotype column: VARCHAR -> TEXT
    -- Reason: concatenated HPO terms can be very long
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'phenotype'
          AND DATA_TYPE = 'varchar'
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN phenotype TEXT NULL COMMENT 'HPO terms or phenotype description';
    END IF;

    -- Widen disease_ontology_name column: VARCHAR -> TEXT
    -- Reason: long disease names from OMIM/Orphanet
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'disease_ontology_name'
          AND DATA_TYPE = 'varchar'
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN disease_ontology_name TEXT NULL COMMENT 'Disease name from source';
    END IF;

    -- Widen inheritance column: VARCHAR -> TEXT
    -- Reason: multiple inheritance terms concatenated
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'inheritance'
          AND DATA_TYPE = 'varchar'
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN inheritance TEXT NULL COMMENT 'Mode of inheritance term(s)';
    END IF;

    -- Widen pathogenicity_mode column: VARCHAR -> TEXT
    -- Reason: free-text pathogenicity descriptions
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'pathogenicity_mode'
          AND DATA_TYPE = 'varchar'
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN pathogenicity_mode TEXT NULL COMMENT 'Pathogenicity mechanism/mode';
    END IF;

    -- Widen disease_ontology_id column: VARCHAR(<500) -> TEXT
    -- Reason: multiple disease IDs concatenated (OMIM:123456;ORPHA:1234;...)
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'disease_ontology_id'
          AND DATA_TYPE = 'varchar'
          AND (CHARACTER_MAXIMUM_LENGTH < 500 OR CHARACTER_MAXIMUM_LENGTH IS NULL)
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN disease_ontology_id TEXT NULL COMMENT 'Disease ID (OMIM:123456, ORPHA:1234, MONDO:0001234)';
    END IF;

    -- Widen granularity column: VARCHAR -> TEXT
    -- Reason: detailed granularity descriptions
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'granularity'
          AND DATA_TYPE = 'varchar'
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN granularity TEXT NULL COMMENT 'Data granularity description for source';
    END IF;

END //

CALL migrate_012_widen_comparison_columns() //

DROP PROCEDURE IF EXISTS migrate_012_widen_comparison_columns //

DELIMITER ;
