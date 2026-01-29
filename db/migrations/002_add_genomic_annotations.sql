-- Add pre-annotated genomic data columns to non_alt_loci_set
-- gnomAD constraint scores (JSON) and AlphaFold model identifier
--
-- gnomad_constraints: JSON blob from gnomAD v4 GraphQL API containing
--   pLI, LOEUF, o/e ratios, Z-scores, expected/observed counts
--   Populated during HGNC update process (batch enrichment)
--
-- alphafold_id: Pre-computed AlphaFold model identifier (AF-{uniprot_id}-F1)
--   Derived from first UniProt ID during HGNC update process
--   Used by Phase 45 (3D protein structure viewer)
--
-- Idempotent: Uses stored procedure to check column existence before ALTER

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_002_genomic_annotations()
BEGIN
    -- Add gnomad_constraints column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'non_alt_loci_set'
          AND COLUMN_NAME = 'gnomad_constraints'
    ) THEN
        ALTER TABLE non_alt_loci_set ADD COLUMN gnomad_constraints TEXT NULL;
    END IF;

    -- Add alphafold_id column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'non_alt_loci_set'
          AND COLUMN_NAME = 'alphafold_id'
    ) THEN
        ALTER TABLE non_alt_loci_set ADD COLUMN alphafold_id VARCHAR(100) NULL;
    END IF;
END //

DELIMITER ;

CALL migrate_002_genomic_annotations();
DROP PROCEDURE IF EXISTS migrate_002_genomic_annotations;
