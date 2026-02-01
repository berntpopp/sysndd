-- Migration: 009_ndd_database_comparison
-- Description: Create/update ndd_database_comparison table for external database comparisons
-- Required by: api/functions/comparisons-functions.R comparisons_update_async()
--
-- This table stores comparison data from 7+ external NDD gene databases:
-- - radboudumc_ID, gene2phenotype, panelapp, sfari, geisinger_DBD, omim_ndd, orphanet_id
--
-- Idempotent: Uses stored procedure with INFORMATION_SCHEMA checks
-- Handles both fresh installs AND existing tables from old backups
--
-- Best practice reference: https://gist.github.com/jeremyjarrell/6083251

DELIMITER //

DROP PROCEDURE IF EXISTS migrate_009_ndd_database_comparison //

CREATE PROCEDURE migrate_009_ndd_database_comparison()
BEGIN
    -- Step 1: Create table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
    ) THEN
        CREATE TABLE ndd_database_comparison (
            comparison_id INT AUTO_INCREMENT PRIMARY KEY,
            symbol VARCHAR(50) NULL COMMENT 'Gene symbol (uppercase)',
            hgnc_id VARCHAR(20) NULL COMMENT 'HGNC ID with prefix (e.g., HGNC:12345)',
            disease_ontology_id VARCHAR(100) NULL COMMENT 'Disease ID (OMIM:123456, ORPHA:1234, MONDO:0001234)',
            disease_ontology_name TEXT NULL COMMENT 'Disease name from source',
            inheritance VARCHAR(200) NULL COMMENT 'Mode of inheritance term(s)',
            category VARCHAR(100) NULL COMMENT 'Confidence/evidence category from source',
            pathogenicity_mode TEXT NULL COMMENT 'Pathogenicity mechanism/mode',
            phenotype TEXT NULL COMMENT 'HPO terms or phenotype description',
            publication_id TEXT NULL COMMENT 'Publication IDs (PMIDs)',
            list VARCHAR(50) NOT NULL COMMENT 'Source database name',
            version VARCHAR(500) NULL COMMENT 'Source version/date (can be long path/description)',
            import_date DATE NULL COMMENT 'Date of import',
            granularity VARCHAR(200) NULL COMMENT 'Data granularity description for source',
            INDEX idx_symbol (symbol),
            INDEX idx_hgnc_id (hgnc_id),
            INDEX idx_list (list),
            INDEX idx_import_date (import_date)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    END IF;

    -- Step 2: Add granularity column if missing (handles old backups)
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'granularity'
    ) THEN
        ALTER TABLE ndd_database_comparison
        ADD COLUMN granularity VARCHAR(200) NULL COMMENT 'Data granularity description for source';
    END IF;

    -- Step 3: Add indexes if missing (safe to run - MySQL ignores duplicate index creation errors)
    -- Using IF NOT EXISTS pattern for each index
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND INDEX_NAME = 'idx_symbol'
    ) THEN
        CREATE INDEX idx_symbol ON ndd_database_comparison (symbol);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND INDEX_NAME = 'idx_hgnc_id'
    ) THEN
        CREATE INDEX idx_hgnc_id ON ndd_database_comparison (hgnc_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND INDEX_NAME = 'idx_list'
    ) THEN
        CREATE INDEX idx_list ON ndd_database_comparison (list);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND INDEX_NAME = 'idx_import_date'
    ) THEN
        CREATE INDEX idx_import_date ON ndd_database_comparison (import_date);
    END IF;

END //

CALL migrate_009_ndd_database_comparison() //

DROP PROCEDURE IF EXISTS migrate_009_ndd_database_comparison //

DELIMITER ;

-- Step 4: Create or replace the comparison view (used by frontend)
-- This is outside the procedure because CREATE OR REPLACE VIEW is already idempotent
-- This view UNIONs:
--   1. SysNDD internal data from ndd_entity (approved active entities)
--   2. External database comparisons from ndd_database_comparison table
CREATE OR REPLACE VIEW ndd_database_comparison_view AS
-- SysNDD internal data (approved, active entities)
SELECT
    NULL AS comparison_id,
    n.symbol AS symbol,
    e.hgnc_id AS hgnc_id,
    e.disease_ontology_id_version AS disease_ontology_id,
    NULL AS disease_ontology_name,
    e.hpo_mode_of_inheritance_term AS inheritance,
    c.category AS category,
    '1' AS pathogenicity_mode,
    NULL AS phenotype,
    NULL AS publication_id,
    'SysNDD' AS list,
    'current' AS version,
    NULL AS import_date,
    NULL AS granularity
FROM ndd_entity e
JOIN ndd_entity_status_approved_view a ON e.entity_id = a.entity_id
JOIN ndd_entity_status_categories_list c ON a.category_id = c.category_id
LEFT JOIN non_alt_loci_set n ON e.hgnc_id = n.hgnc_id
WHERE e.is_active = 1
UNION ALL
-- External database comparisons
SELECT
    comparison_id,
    symbol,
    hgnc_id,
    disease_ontology_id,
    disease_ontology_name,
    inheritance,
    category,
    pathogenicity_mode,
    phenotype,
    publication_id,
    list,
    version,
    import_date,
    granularity
FROM ndd_database_comparison;
