-- Migration: 009_ndd_database_comparison
-- Description: Create the ndd_database_comparison table for external database comparisons
-- Required by: api/functions/comparisons-functions.R comparisons_update_async()
--
-- This table stores comparison data from 7+ external NDD gene databases:
-- - radboudumc_ID, gene2phenotype, panelapp, sfari, geisinger_DBD, omim_ndd, orphanet_id
--
-- Idempotent: Uses IF NOT EXISTS

-- Create ndd_database_comparison table if not exists
CREATE TABLE IF NOT EXISTS ndd_database_comparison (
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

-- Create or replace the comparison view (used by frontend)
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
