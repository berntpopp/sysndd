-- Dedicated approved-public read surface for the fixed SELECT-only MCP principal.
-- The ordinary migration identity remains the definer; no MCP account or grant is
-- created here. Every view deliberately names its output columns and base gates.

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_gene` AS
SELECT nal.`hgnc_id`, nal.`symbol`, nal.`name`, nal.`omim_id`,
       nal.`ensembl_gene_id`, nal.`uniprot_ids`, nal.`STRING_id`, nal.`mgd_id`,
       nal.`rgd_id`, nal.`mane_select`, nal.`alphafold_id`
FROM `non_alt_loci_set` nal
WHERE nal.`status` = 'Approved';

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_hgnc_symbol` AS
SELECT hsl.`lookup_symbol`, hsl.`hgnc_id`, hsl.`symbol_type`
FROM `hgnc_symbol_lookup` hsl
JOIN `non_alt_loci_set` nal ON nal.`hgnc_id` = hsl.`hgnc_id`
WHERE nal.`status` = 'Approved';

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_entity` AS
SELECT e.`entity_id`, e.`hgnc_id`, nal.`symbol`, e.`disease_ontology_id_version`,
       d.`disease_ontology_name`, e.`hpo_mode_of_inheritance_term`,
       moi.`hpo_mode_of_inheritance_term_name`, moi.`inheritance_filter`,
       e.`ndd_phenotype`, b.`word_english` AS `ndd_phenotype_word`, e.`entry_date`,
       GREATEST(e.`entry_date`, s.`status_date`,
         COALESCE(MAX(r.`review_date`), e.`entry_date`)) AS `last_update`,
       sc.`category`, sc.`category_id`
FROM `ndd_entity` e
JOIN `non_alt_loci_set` nal ON nal.`hgnc_id` = e.`hgnc_id`
JOIN `disease_ontology_set` d
  ON d.`disease_ontology_id_version` = e.`disease_ontology_id_version`
JOIN `mode_of_inheritance_list` moi
  ON moi.`hpo_mode_of_inheritance_term` = e.`hpo_mode_of_inheritance_term`
JOIN `ndd_entity_status` s
  ON s.`entity_id` = e.`entity_id` AND s.`is_active` = 1 AND s.`status_approved` = 1
JOIN `ndd_entity_status_categories_list` sc ON sc.`category_id` = s.`category_id`
JOIN `boolean_list` b ON b.`logical` = e.`ndd_phenotype`
LEFT JOIN `ndd_entity_review` r
  ON r.`entity_id` = e.`entity_id` AND r.`is_primary` = 1 AND r.`review_approved` = 1
WHERE e.`is_active` = 1
  AND nal.`status` = 'Approved'
  AND d.`is_active` = 1
  AND moi.`is_active` = 1
  AND sc.`is_active` = 1
GROUP BY e.`entity_id`, e.`hgnc_id`, nal.`symbol`, e.`disease_ontology_id_version`,
         d.`disease_ontology_name`, e.`hpo_mode_of_inheritance_term`,
         moi.`hpo_mode_of_inheritance_term_name`, moi.`inheritance_filter`,
         e.`ndd_phenotype`, b.`word_english`, e.`entry_date`, s.`status_date`,
         sc.`category`, sc.`category_id`;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_disease` AS
SELECT d.`disease_ontology_id_version`, d.`disease_ontology_id`,
       d.`disease_ontology_name`, d.`disease_ontology_source`,
       d.`disease_ontology_is_specific`, d.`DOID`, d.`MONDO`, d.`Orphanet`, d.`EFO`
FROM `disease_ontology_set` d
WHERE d.`is_active` = 1;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_phenotype` AS
SELECT p.`phenotype_id`, p.`HPO_term`, p.`HPO_term_definition`, p.`HPO_term_synonyms`
FROM `phenotype_list` p;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_variation` AS
SELECT v.`vario_id`, v.`vario_name`, v.`definition`
FROM `variation_ontology_list` v
WHERE v.`is_active` = 1 AND COALESCE(v.`obsolete`, 0) = 0;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_comparison` AS
SELECT e.`hgnc_id`, e.`disease_ontology_id_version` AS `disease_ontology_id`,
       e.`hpo_mode_of_inheritance_term` AS `inheritance`, sc.`category`,
       '1' AS `pathogenicity_mode`, 'SysNDD' AS `list`, 'current' AS `version`
FROM `ndd_entity` e
JOIN `non_alt_loci_set` nal ON nal.`hgnc_id` = e.`hgnc_id`
JOIN `disease_ontology_set` d
  ON d.`disease_ontology_id_version` = e.`disease_ontology_id_version`
JOIN `mode_of_inheritance_list` moi
  ON moi.`hpo_mode_of_inheritance_term` = e.`hpo_mode_of_inheritance_term`
JOIN `ndd_entity_status` s
  ON s.`entity_id` = e.`entity_id` AND s.`is_active` = 1 AND s.`status_approved` = 1
JOIN `ndd_entity_status_categories_list` sc ON sc.`category_id` = s.`category_id`
WHERE e.`is_active` = 1 AND e.`ndd_phenotype` = 1
  AND nal.`status` = 'Approved' AND d.`is_active` = 1
  AND moi.`is_active` = 1 AND sc.`is_active` = 1
UNION ALL
SELECT c.`hgnc_id`, c.`disease_ontology_id`, c.`inheritance`, c.`category`,
       c.`pathogenicity_mode`, c.`list`, c.`version`
FROM `ndd_database_comparison` c
JOIN `non_alt_loci_set` nal
  ON c.`hgnc_id` IS NOT NULL AND nal.`hgnc_id` = c.`hgnc_id`
WHERE nal.`status` = 'Approved';

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_comparison_metadata` AS
SELECT cm.`last_full_refresh`, cm.`last_refresh_status`, cm.`sources_count`,
       cm.`rows_imported`
FROM `comparisons_metadata` cm
WHERE cm.`id` = (SELECT MAX(latest.`id`) FROM `comparisons_metadata` latest);

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_review` AS
SELECT r.`review_id`, r.`entity_id`, r.`synopsis`, r.`review_date`
FROM `ndd_entity_review` r
JOIN `mcp_public_entity` e ON e.`entity_id` = r.`entity_id`
WHERE r.`is_primary` = 1 AND r.`review_approved` = 1;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_review_phenotype` AS
SELECT c.`review_phenotype_id`, c.`review_id`, c.`entity_id`, c.`phenotype_id`,
       c.`modifier_id`, p.`HPO_term`, ml.`modifier_name`, c.`phenotype_date`
FROM `ndd_review_phenotype_connect` c
JOIN `mcp_public_review` r
  ON r.`review_id` = c.`review_id` AND r.`entity_id` = c.`entity_id`
JOIN `mcp_public_entity` e ON e.`entity_id` = c.`entity_id`
JOIN `phenotype_list` p ON p.`phenotype_id` = c.`phenotype_id`
JOIN `modifier_list` ml ON ml.`modifier_id` = c.`modifier_id`
WHERE c.`is_active` = 1 AND ml.`is_active` = 1 AND ml.`allowed_phenotype` = 1;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_review_variation` AS
SELECT c.`review_vario_id`, c.`review_id`, c.`entity_id`, c.`vario_id`,
       c.`modifier_id`, v.`vario_name`, ml.`modifier_name`, c.`variation_ontology_date`
FROM `ndd_review_variation_ontology_connect` c
JOIN `mcp_public_review` r
  ON r.`review_id` = c.`review_id` AND r.`entity_id` = c.`entity_id`
JOIN `mcp_public_entity` e ON e.`entity_id` = c.`entity_id`
JOIN `variation_ontology_list` v ON v.`vario_id` = c.`vario_id`
JOIN `modifier_list` ml ON ml.`modifier_id` = c.`modifier_id`
WHERE c.`is_active` = 1 AND v.`is_active` = 1 AND COALESCE(v.`obsolete`, 0) = 0
  AND ml.`is_active` = 1 AND ml.`allowed_variation` = 1;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_review_publication` AS
SELECT rpj.`review_publication_id`, rpj.`review_id`, rpj.`entity_id`,
       rpj.`publication_id`, rpj.`publication_type`, p.`Title`, p.`Abstract`,
       p.`Publication_date`, p.`publication_date_source`, p.`Journal`, p.`Keywords`,
       p.`Lastname`, p.`Firstname`, r.`review_date` AS `curation_review_date`
FROM `ndd_review_publication_join` rpj
JOIN `mcp_public_review` r
  ON r.`review_id` = rpj.`review_id` AND r.`entity_id` = rpj.`entity_id`
JOIN `mcp_public_entity` e ON e.`entity_id` = rpj.`entity_id`
JOIN `publication` p ON p.`publication_id` = rpj.`publication_id`
WHERE rpj.`is_reviewed` = 1;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_analysis_source_version` AS
SELECT SHA2(CONCAT_WS('|',
  (SELECT COUNT(*) FROM `ndd_entity_view`),
  (SELECT COUNT(*) FROM `ndd_entity_review` r
    WHERE r.`is_primary` = 1 AND r.`review_approved` = 1),
  COALESCE((SELECT DATE_FORMAT(MAX(r.`review_date`), '%Y-%m-%dT%H:%i:%s.%f')
    FROM `ndd_entity_review` r
    WHERE r.`is_primary` = 1 AND r.`review_approved` = 1), 'none'),
  (SELECT COUNT(*) FROM `ndd_review_phenotype_connect` rpc
    JOIN `ndd_entity_review` r ON r.`review_id` = rpc.`review_id`
    WHERE rpc.`is_active` = 1 AND r.`is_primary` = 1 AND r.`review_approved` = 1),
  COALESCE((SELECT DATE_FORMAT(MAX(rpc.`phenotype_date`), '%Y-%m-%dT%H:%i:%s.%f')
    FROM `ndd_review_phenotype_connect` rpc
    JOIN `ndd_entity_review` r ON r.`review_id` = rpc.`review_id`
    WHERE rpc.`is_active` = 1 AND r.`is_primary` = 1 AND r.`review_approved` = 1), 'none'),
  (SELECT COUNT(*) FROM `ndd_entity_status` s
    WHERE s.`is_active` = 1 AND s.`status_approved` = 1),
  COALESCE((SELECT DATE_FORMAT(MAX(s.`status_date`), '%Y-%m-%dT%H:%i:%s.%f')
    FROM `ndd_entity_status` s
    WHERE s.`is_active` = 1 AND s.`status_approved` = 1), 'none')
), 256) AS `source_data_version`;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_analysis_manifest` AS
SELECT m.`snapshot_id`, m.`analysis_type`, m.`parameter_hash`, m.`schema_version`,
       m.`data_class`, m.`generated_at`, m.`activated_at`, m.`stale_after`,
       m.`source_data_version`, m.`parameters_json`, m.`payload_hash`,
       m.`algorithm_name`, m.`algorithm_version`, m.`row_counts_json`
FROM `analysis_snapshot_manifest` m
JOIN `mcp_public_analysis_source_version` sv
  ON m.`source_data_version` = sv.`source_data_version`
WHERE m.`public_ready` = 1 AND m.`status` = 'public_ready'
  AND m.`stale_after` IS NOT NULL AND m.`stale_after` > UTC_TIMESTAMP()
  AND m.`source_data_version` = sv.`source_data_version`
  AND m.`schema_version` = '1.2';

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_analysis_network_node` AS
SELECT n.`snapshot_id`, n.`hgnc_id`, n.`symbol`, n.`cluster_id`, n.`category`,
       n.`degree`, n.`x`, n.`y`, n.`layout_x`, n.`layout_y`, n.`igraph_x`,
       n.`igraph_y`, n.`display_order`
FROM `analysis_snapshot_network_node` n
JOIN `mcp_public_analysis_manifest` m ON m.`snapshot_id` = n.`snapshot_id`;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_analysis_network_edge` AS
SELECT e.`snapshot_id`, e.`edge_rank`, e.`source_hgnc_id`, e.`target_hgnc_id`,
       e.`confidence`
FROM `analysis_snapshot_network_edge` e
JOIN `mcp_public_analysis_manifest` m ON m.`snapshot_id` = e.`snapshot_id`;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_analysis_cluster` AS
SELECT c.`snapshot_id`, c.`cluster_kind`, c.`cluster_id`, c.`cluster_hash`,
       c.`cluster_size`, c.`label`, c.`metadata_json`
FROM `analysis_snapshot_cluster` c
JOIN `mcp_public_analysis_manifest` m ON m.`snapshot_id` = c.`snapshot_id`;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_analysis_cluster_member` AS
SELECT cm.`snapshot_id`, cm.`cluster_kind`, cm.`cluster_id`, cm.`member_rank`,
       cm.`entity_id`, cm.`hgnc_id`, cm.`symbol`
FROM `analysis_snapshot_cluster_member` cm
JOIN `mcp_public_analysis_manifest` m ON m.`snapshot_id` = cm.`snapshot_id`;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_analysis_correlation` AS
SELECT c.`snapshot_id`, c.`row_rank`, c.`correlation_kind`, c.`x_key`, c.`y_key`,
       c.`value`, c.`abs_value`, c.`metadata_json`
FROM `analysis_snapshot_correlation` c
JOIN `mcp_public_analysis_manifest` m ON m.`snapshot_id` = c.`snapshot_id`;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_llm_cluster_summary` AS
SELECT c.`cache_id`, a.`snapshot_id`, c.`cluster_type`, c.`cluster_number`,
       c.`cluster_hash`, c.`model_name`, c.`prompt_version`,
       JSON_OBJECT(
         'summary', JSON_EXTRACT(c.`summary_json`, '$.summary'),
         'key_themes', JSON_EXTRACT(c.`summary_json`, '$.key_themes'),
         'pathways', JSON_EXTRACT(c.`summary_json`, '$.pathways'),
         'tags', JSON_EXTRACT(c.`summary_json`, '$.tags'),
         'clinical_relevance', JSON_EXTRACT(c.`summary_json`, '$.clinical_relevance'),
         'confidence', JSON_EXTRACT(c.`summary_json`, '$.confidence'),
         'key_phenotype_themes', JSON_EXTRACT(c.`summary_json`, '$.key_phenotype_themes'),
         'notably_absent', JSON_EXTRACT(c.`summary_json`, '$.notably_absent'),
         'clinical_pattern', JSON_EXTRACT(c.`summary_json`, '$.clinical_pattern'),
         'syndrome_hints', JSON_EXTRACT(c.`summary_json`, '$.syndrome_hints'),
         'inheritance_patterns', JSON_EXTRACT(c.`summary_json`, '$.inheritance_patterns'),
         'syndromicity', JSON_EXTRACT(c.`summary_json`, '$.syndromicity'),
         'data_quality_note', JSON_EXTRACT(c.`summary_json`, '$.data_quality_note')
       ) AS `summary_json`, c.`tags`, c.`created_at`, c.`validated_at`
FROM `llm_cluster_summary_cache` c
JOIN `mcp_public_analysis_cluster` a
  ON a.`cluster_kind` = c.`cluster_type`
 AND a.`cluster_id` = CAST(c.`cluster_number` AS CHAR CHARACTER SET utf8mb4)
     COLLATE utf8mb4_unicode_ci
 AND a.`cluster_hash` = c.`cluster_hash`
JOIN `mcp_public_analysis_manifest` m
  ON m.`snapshot_id` = a.`snapshot_id`
 AND m.`analysis_type` = CASE c.`cluster_type`
   WHEN 'functional' THEN 'functional_clusters'
   WHEN 'phenotype' THEN 'phenotype_clusters'
 END
WHERE c.`validation_status` = 'validated' AND c.`is_current` = 1
  AND c.`prompt_version` = '1.0';

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_nddscore_release` AS
SELECT r.`release_id`, r.`score_schema_version`, r.`version`, r.`release_created_at`,
       r.`n_genes`, r.`n_hpo_predictions`, r.`n_hpo_terms`, r.`n_features`,
       r.`hpo_threshold`, r.`calibration_method`, r.`ndd_model_created_at`,
       r.`phenotype_model_created_at`, r.`inheritance_model_created_at`,
       r.`ndd_performance_json`, r.`phenotype_performance_json`,
       r.`inheritance_performance_json`, r.`data_versions_json`,
       r.`artifact_hashes_json`, r.`zenodo_record_url`, r.`version_doi`, r.`concept_doi`,
       r.`source_record_id`, r.`import_completed_at`, r.`activated_at`
FROM `nddscore_release` r
WHERE r.`is_active` = 1 AND r.`import_status` = 'active';

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_nddscore_gene_prediction` AS
SELECT p.`release_id`, p.`hgnc_id`, p.`gene_symbol`, p.`ensembl_gene_id`,
       p.`ndd_score`, p.`ndd_score_std`, p.`ndd_score_iqr`, p.`bag_agreement`,
       p.`rank`, p.`percentile`, p.`risk_tier`, p.`confidence_tier`,
       p.`known_sysndd_gene`, p.`model_split`, p.`inheritance_ad_probability`,
       p.`inheritance_ar_probability`, p.`inheritance_xld_probability`,
       p.`inheritance_xlr_probability`, p.`top_inheritance_mode`,
       p.`called_inheritance_modes`, p.`n_predicted_hpo`, p.`top_hpo_predictions_json`,
       p.`shap_clinical`, p.`shap_constraint`, p.`shap_expression`, p.`shap_network`,
       p.`shap_conservation`, p.`shap_other`, p.`dominant_shap_group`,
       p.`top_features_json`, p.`prediction_note`
FROM `nddscore_gene_prediction` p
JOIN `mcp_public_nddscore_release` r ON r.`release_id` = p.`release_id`;

CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
VIEW `mcp_public_nddscore_hpo_prediction` AS
SELECT p.`release_id`, p.`hgnc_id`, p.`gene_symbol`, p.`phenotype_id`,
       p.`phenotype_name`, p.`probability`, p.`rank_for_gene`,
       p.`passes_default_threshold`, p.`term_auc_roc`, p.`term_auc_pr`,
       p.`term_training_support`
FROM `nddscore_hpo_prediction` p
JOIN `mcp_public_nddscore_release` r ON r.`release_id` = p.`release_id`;
