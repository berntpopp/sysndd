-- Migration 016: Fix ndd_database_comparison_view to match entity view filters
--
-- Problem: The SysNDD part of the comparison view UNION was missing both
-- is_active = 1 and ndd_phenotype = 1 filters. This caused:
--   - 4 inactive MONDO:0001071 entities to inflate Definitive count (1806 vs 1802)
--   - 1 non-NDD gene (GJA1) to appear as Limited (1254 vs 1253)
--   - Category counts in CurationComparisons/Table to differ from Home/Genes/Panels
--
-- Fix: Add WHERE is_active = 1 AND ndd_phenotype = 1 to the SysNDD SELECT,
-- matching the filters used by ndd_entity_view (which stats/panels/genes query).
--
-- Idempotent: Uses CREATE OR REPLACE VIEW (safe to run multiple times).
-- Works on both fresh installs (after 009) and existing databases.
-- Column structure matches the original view definition used by the R API.

CREATE OR REPLACE VIEW ndd_database_comparison_view AS
-- SysNDD internal data: approved, active, NDD-phenotype entities only
SELECT
  ndd_entity.hgnc_id AS hgnc_id,
  ndd_entity.disease_ontology_id_version AS disease_ontology_id,
  ndd_entity.hpo_mode_of_inheritance_term AS inheritance,
  ndd_entity_status_categories_list.category AS category,
  '1' AS pathogenicity_mode,
  'SysNDD' AS list,
  'current' AS version
FROM ndd_entity
JOIN ndd_entity_status_approved_view
  ON ndd_entity.entity_id = ndd_entity_status_approved_view.entity_id
JOIN ndd_entity_status_categories_list
  ON ndd_entity_status_approved_view.category_id = ndd_entity_status_categories_list.category_id
WHERE ndd_entity.is_active = 1
  AND ndd_entity.ndd_phenotype = 1

UNION ALL

-- External database comparisons (unchanged, UNION ALL safe: SysNDD and external are disjoint)
SELECT
  ndd_database_comparison.hgnc_id AS hgnc_id,
  ndd_database_comparison.disease_ontology_id AS disease_ontology_id,
  ndd_database_comparison.inheritance AS inheritance,
  ndd_database_comparison.category AS category,
  ndd_database_comparison.pathogenicity_mode AS pathogenicity_mode,
  ndd_database_comparison.list AS list,
  ndd_database_comparison.version AS version
FROM ndd_database_comparison;
