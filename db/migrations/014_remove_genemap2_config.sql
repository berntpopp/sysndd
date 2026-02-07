-- Remove omim_genemap2 from comparisons_config table
--
-- Phase 78: genemap2 download/parse moves to shared infrastructure
-- (Phase 76 download_genemap2() with 1-day TTL caching)
--
-- Background:
-- - genemap2.txt is now downloaded via shared omim-functions.R download_genemap2()
-- - Both ontology and comparisons systems share the same cached genemap2 file
-- - Only one download per day regardless of which system triggers it
-- - phenotype_hpoa removed separately in migration 015 (replaced by phenotype_to_genes.txt)
--
-- Migration removes omim_genemap2 row from comparisons_config because:
-- 1. URL contains plaintext OMIM API key (security risk to keep in database)
-- 2. Shared infrastructure uses OMIM_DOWNLOAD_KEY env var instead
-- 3. No UI consumes per-source last_updated field (comparisons_metadata tracks global status)
--
-- Idempotent: Uses stored procedure pattern

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_014_remove_genemap2_config()
BEGIN
    -- Remove omim_genemap2 from comparisons_config
    DELETE FROM comparisons_config WHERE source_name = 'omim_genemap2';
END //

CALL migrate_014_remove_genemap2_config() //

DROP PROCEDURE IF EXISTS migrate_014_remove_genemap2_config //

DELIMITER ;
