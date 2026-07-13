mcp_select_expected_columns <- function() {
  list(
    mcp_public_gene = c(
      "hgnc_id", "symbol", "name", "omim_id", "ensembl_gene_id",
      "uniprot_ids", "STRING_id", "mgd_id", "rgd_id", "mane_select",
      "alphafold_id"
    ),
    mcp_public_hgnc_symbol = c("lookup_symbol", "hgnc_id", "symbol_type"),
    mcp_public_entity = c(
      "entity_id", "hgnc_id", "symbol", "disease_ontology_id_version",
      "disease_ontology_name", "hpo_mode_of_inheritance_term",
      "hpo_mode_of_inheritance_term_name", "inheritance_filter",
      "ndd_phenotype", "ndd_phenotype_word", "entry_date", "last_update",
      "category", "category_id"
    ),
    mcp_public_disease = c(
      "disease_ontology_id_version", "disease_ontology_id",
      "disease_ontology_name", "disease_ontology_source",
      "disease_ontology_is_specific", "DOID", "MONDO", "Orphanet", "EFO"
    ),
    mcp_public_phenotype = c(
      "phenotype_id", "HPO_term", "HPO_term_definition", "HPO_term_synonyms"
    ),
    mcp_public_variation = c("vario_id", "vario_name", "definition"),
    mcp_public_comparison = c(
      "hgnc_id", "disease_ontology_id", "inheritance", "category",
      "pathogenicity_mode", "list", "version"
    ),
    mcp_public_comparison_metadata = c(
      "last_full_refresh", "last_refresh_status", "sources_count", "rows_imported"
    ),
    mcp_public_review = c("review_id", "entity_id", "synopsis", "review_date"),
    mcp_public_review_phenotype = c(
      "review_phenotype_id", "review_id", "entity_id", "phenotype_id",
      "modifier_id", "HPO_term", "modifier_name", "phenotype_date"
    ),
    mcp_public_review_variation = c(
      "review_vario_id", "review_id", "entity_id", "vario_id", "modifier_id",
      "vario_name", "modifier_name", "variation_ontology_date"
    ),
    mcp_public_review_publication = c(
      "review_publication_id", "review_id", "entity_id", "publication_id",
      "publication_type", "Title", "Abstract", "Publication_date",
      "publication_date_source", "Journal", "Keywords", "Lastname", "Firstname",
      "curation_review_date"
    ),
    mcp_public_analysis_manifest = c(
      "snapshot_id", "analysis_type", "parameter_hash", "schema_version",
      "data_class", "generated_at", "activated_at", "stale_after",
      "source_data_version", "parameters_json", "payload_hash",
      "algorithm_name", "algorithm_version", "row_counts_json"
    ),
    mcp_public_analysis_network_node = c(
      "snapshot_id", "hgnc_id", "symbol", "cluster_id", "category", "degree",
      "x", "y", "layout_x", "layout_y", "igraph_x", "igraph_y", "display_order"
    ),
    mcp_public_analysis_network_edge = c(
      "snapshot_id", "edge_rank", "source_hgnc_id", "target_hgnc_id", "confidence"
    ),
    mcp_public_analysis_cluster = c(
      "snapshot_id", "cluster_kind", "cluster_id", "cluster_hash", "cluster_size",
      "label", "metadata_json"
    ),
    mcp_public_analysis_cluster_member = c(
      "snapshot_id", "cluster_kind", "cluster_id", "member_rank", "entity_id",
      "hgnc_id", "symbol"
    ),
    mcp_public_analysis_correlation = c(
      "snapshot_id", "row_rank", "correlation_kind", "x_key", "y_key", "value",
      "abs_value", "metadata_json"
    ),
    mcp_public_analysis_source_version = "source_data_version",
    mcp_public_llm_cluster_summary = c(
      "cache_id", "snapshot_id", "cluster_type", "cluster_number", "cluster_hash",
      "model_name", "prompt_version", "summary_json", "tags", "created_at", "validated_at"
    ),
    mcp_public_nddscore_release = c(
      "release_id", "score_schema_version", "version", "release_created_at",
      "n_genes", "n_hpo_predictions", "n_hpo_terms", "n_features", "hpo_threshold",
      "calibration_method", "ndd_model_created_at", "phenotype_model_created_at",
      "inheritance_model_created_at", "ndd_performance_json",
      "phenotype_performance_json", "inheritance_performance_json",
      "data_versions_json", "artifact_hashes_json", "zenodo_record_url", "version_doi",
      "concept_doi", "source_record_id", "import_completed_at", "activated_at"
    ),
    mcp_public_nddscore_gene_prediction = c(
      "release_id", "hgnc_id", "gene_symbol", "ensembl_gene_id", "ndd_score",
      "ndd_score_std", "ndd_score_iqr", "bag_agreement", "rank", "percentile",
      "risk_tier", "confidence_tier", "known_sysndd_gene", "model_split",
      "inheritance_ad_probability", "inheritance_ar_probability",
      "inheritance_xld_probability", "inheritance_xlr_probability",
      "top_inheritance_mode", "called_inheritance_modes", "n_predicted_hpo",
      "top_hpo_predictions_json", "shap_clinical", "shap_constraint",
      "shap_expression", "shap_network", "shap_conservation", "shap_other",
      "dominant_shap_group", "top_features_json", "prediction_note"
    ),
    mcp_public_nddscore_hpo_prediction = c(
      "release_id", "hgnc_id", "gene_symbol", "phenotype_id", "phenotype_name",
      "probability", "rank_for_gene", "passes_default_threshold", "term_auc_roc",
      "term_auc_pr", "term_training_support"
    )
  )
}

mcp_select_expected_dependencies <- function() {
  list(
    mcp_public_analysis_manifest = c(
      "analysis_snapshot_manifest", "mcp_public_analysis_source_version"
    ),
    mcp_public_analysis_network_node = c(
      "analysis_snapshot_network_node", "mcp_public_analysis_manifest"
    ),
    mcp_public_analysis_network_edge = c(
      "analysis_snapshot_network_edge", "mcp_public_analysis_manifest"
    ),
    mcp_public_analysis_cluster = c(
      "analysis_snapshot_cluster", "mcp_public_analysis_manifest"
    ),
    mcp_public_analysis_cluster_member = c(
      "analysis_snapshot_cluster_member", "mcp_public_analysis_manifest"
    ),
    mcp_public_analysis_correlation = c(
      "analysis_snapshot_correlation", "mcp_public_analysis_manifest"
    ),
    mcp_public_llm_cluster_summary = c(
      "llm_cluster_summary_cache", "mcp_public_analysis_cluster",
      "mcp_public_analysis_manifest"
    ),
    mcp_public_nddscore_gene_prediction = c(
      "nddscore_gene_prediction", "mcp_public_nddscore_release"
    ),
    mcp_public_nddscore_hpo_prediction = c(
      "nddscore_hpo_prediction", "mcp_public_nddscore_release"
    )
  )
}
