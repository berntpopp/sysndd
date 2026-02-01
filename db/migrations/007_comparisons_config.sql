-- Add comparisons configuration tables for admin-triggered data refresh
--
-- Creates two tables:
-- 1. comparisons_config - stores source URLs and configuration for each external database
-- 2. comparisons_metadata - tracks last refresh status and statistics
--
-- Design decisions:
-- - source_name: Unique identifier matching existing list values
-- - source_url: Full URL for data download (admin can edit via database)
-- - file_format: Determines which parser to use (pdf, csv, tsv, json, txt)
-- - is_active: Allows disabling sources without removing config
-- - Metadata table tracks refresh history for UI display
--
-- Idempotent: Uses stored procedure with IF NOT EXISTS checks

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_007_comparisons_config()
BEGIN
    -- Create comparisons_config table if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'comparisons_config'
    ) THEN
        CREATE TABLE comparisons_config (
            id INT AUTO_INCREMENT PRIMARY KEY,
            source_name VARCHAR(50) NOT NULL UNIQUE COMMENT 'Identifier matching list column in ndd_database_comparison',
            source_url TEXT NOT NULL COMMENT 'Full URL for data download',
            file_format VARCHAR(10) NOT NULL COMMENT 'Parser type: pdf, csv, csv.gz, tsv, json, txt',
            is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Whether to include in refresh',
            last_updated DATETIME NULL COMMENT 'Last successful download timestamp',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_source_name (source_name),
            INDEX idx_is_active (is_active)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

        -- Insert initial source configuration from ndd_databases_links.txt
        INSERT INTO comparisons_config (source_name, source_url, file_format) VALUES
            ('radboudumc_ID', 'https://order.radboudumc.nl/en/labproduct/pdf/10817820', 'pdf'),
            ('gene2phenotype', 'https://www.ebi.ac.uk/gene2phenotype/downloads/DDG2P.csv.gz', 'csv.gz'),
            ('panelapp', 'https://panelapp.genomicsengland.co.uk/panels/285/download/01234/', 'tsv'),
            ('sfari', 'https://gene.sfari.org//wp-content/themes/sfari-gene/utilities/download-csv.php?api-endpoint=genes', 'csv'),
            ('geisinger_DBD', 'https://dbd.geisingeradmi.org/downloads/DBD-Genes-Full-Data.csv', 'csv'),
            ('orphanet_id', 'https://id-genes.orphanet.app/es/index/sysid_index_1', 'json'),
            ('phenotype_hpoa', 'http://purl.obolibrary.org/obo/hp/hpoa/phenotype.hpoa', 'txt'),
            ('omim_genemap2', 'https://data.omim.org/downloads/9GJLEFvqSmWaImCijeRdVA/genemap2.txt', 'txt');
    END IF;

    -- Create comparisons_metadata table if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'comparisons_metadata'
    ) THEN
        CREATE TABLE comparisons_metadata (
            id INT AUTO_INCREMENT PRIMARY KEY,
            last_full_refresh DATETIME NULL COMMENT 'Timestamp of last successful full refresh',
            last_refresh_status VARCHAR(20) NOT NULL DEFAULT 'never' COMMENT 'Status: never, success, failed, running',
            last_refresh_error TEXT NULL COMMENT 'Error message if last refresh failed',
            sources_count INT NOT NULL DEFAULT 0 COMMENT 'Number of sources in last refresh',
            rows_imported INT NOT NULL DEFAULT 0 COMMENT 'Total rows imported in last refresh',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

        -- Insert initial metadata row
        INSERT INTO comparisons_metadata (last_refresh_status, sources_count, rows_imported)
        VALUES ('never', 0, 0);
    END IF;

END //

CALL migrate_007_comparisons_config() //

DROP PROCEDURE IF EXISTS migrate_007_comparisons_config //
