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

ALTER TABLE non_alt_loci_set ADD COLUMN gnomad_constraints TEXT NULL;
ALTER TABLE non_alt_loci_set ADD COLUMN alphafold_id VARCHAR(100) NULL;
