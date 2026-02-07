-- Remove omim_genemap2 from comparisons_config table
--
-- Phase 78: genemap2 download/parse moves to shared infrastructure
-- (Phase 76 download_genemap2() with 1-day TTL caching)
--
-- Background:
-- - genemap2.txt is now downloaded via shared omim-functions.R download_genemap2()
-- - Both ontology and comparisons systems share the same cached genemap2 file
-- - Only one download per day regardless of which system triggers it
-- - phenotype_hpoa stays in comparisons_config (comparisons-only, not shared)
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

    -- Verify phenotype_hpoa is preserved (positive check)
    IF NOT EXISTS (
        SELECT 1 FROM comparisons_config WHERE source_name = 'phenotype_hpoa'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Migration error: phenotype_hpoa unexpectedly missing from comparisons_config';
    END IF;
END //

CALL migrate_014_remove_genemap2_config() //

DROP PROCEDURE IF EXISTS migrate_014_remove_genemap2_config //

DELIMITER ;
