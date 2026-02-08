-- Remove phenotype_hpoa from comparisons_config table
--
-- phenotype_to_genes.txt replaces phenotype.hpoa for NDD filtering in comparisons.
-- The phenotype_to_genes.txt file contains pre-propagated HPO hierarchy annotations,
-- so filtering for HP:0012759 (Neurodevelopmental abnormality) captures all
-- descendant terms automatically — no hardcoded HPO term list needed.
--
-- phenotype.hpoa is still available via download_hpoa() for ontology updates,
-- but is no longer needed in comparisons_config.
--
-- Idempotent: Uses stored procedure pattern

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_015_remove_phenotype_hpoa_from_comparisons()
BEGIN
    DELETE FROM comparisons_config WHERE source_name = 'phenotype_hpoa';
END //

CALL migrate_015_remove_phenotype_hpoa_from_comparisons() //

DROP PROCEDURE IF EXISTS migrate_015_remove_phenotype_hpoa_from_comparisons //

DELIMITER ;
