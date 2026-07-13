# Machine-readable database boundary for the SELECT-only MCP principal.

mcp_readonly_projection_columns <- function() {
  list(
    mcp_public_gene = c(
      "hgnc_id", "symbol", "name", "omim_id", "ensembl_gene_id",
      "uniprot_ids", "STRING_id", "mgd_id", "rgd_id", "mane_select", "alphafold_id"
    ),
    mcp_public_hgnc_symbol = c("lookup_symbol", "hgnc_id", "symbol_type"),
    mcp_public_entity = c(
      "entity_id", "hgnc_id", "symbol", "disease_ontology_id_version",
      "disease_ontology_name", "hpo_mode_of_inheritance_term",
      "hpo_mode_of_inheritance_term_name", "inheritance_filter", "ndd_phenotype",
      "ndd_phenotype_word", "entry_date", "last_update", "category", "category_id"
    ),
    mcp_public_disease = c(
      "disease_ontology_id_version", "disease_ontology_id", "disease_ontology_name",
      "disease_ontology_source", "disease_ontology_is_specific", "DOID", "MONDO",
      "Orphanet", "EFO"
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
      "snapshot_id", "analysis_type", "parameter_hash", "schema_version", "data_class",
      "generated_at", "activated_at", "stale_after", "source_data_version",
      "parameters_json", "payload_hash", "algorithm_name", "algorithm_version",
      "row_counts_json"
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
      "release_id", "score_schema_version", "version", "release_created_at", "n_genes",
      "n_hpo_predictions", "n_hpo_terms", "n_features", "hpo_threshold",
      "calibration_method", "ndd_model_created_at", "phenotype_model_created_at",
      "inheritance_model_created_at", "ndd_performance_json", "phenotype_performance_json",
      "inheritance_performance_json", "data_versions_json", "artifact_hashes_json",
      "zenodo_record_url", "version_doi", "concept_doi", "source_record_id",
      "import_completed_at", "activated_at"
    ),
    mcp_public_nddscore_gene_prediction = c(
      "release_id", "hgnc_id", "gene_symbol", "ensembl_gene_id", "ndd_score",
      "ndd_score_std", "ndd_score_iqr", "bag_agreement", "rank", "percentile",
      "risk_tier", "confidence_tier", "known_sysndd_gene", "model_split",
      "inheritance_ad_probability", "inheritance_ar_probability",
      "inheritance_xld_probability", "inheritance_xlr_probability", "top_inheritance_mode",
      "called_inheritance_modes", "n_predicted_hpo", "top_hpo_predictions_json",
      "shap_clinical", "shap_constraint", "shap_expression", "shap_network",
      "shap_conservation", "shap_other", "dominant_shap_group", "top_features_json",
      "prediction_note"
    ),
    mcp_public_nddscore_hpo_prediction = c(
      "release_id", "hgnc_id", "gene_symbol", "phenotype_id", "phenotype_name",
      "probability", "rank_for_gene", "passes_default_threshold", "term_auc_roc",
      "term_auc_pr", "term_training_support"
    )
  )
}

mcp_readonly_projection_names <- function() {
  names(mcp_readonly_projection_columns())
}

mcp_readonly_projection_dependencies <- function() {
  list(
    mcp_public_gene = "non_alt_loci_set",
    mcp_public_hgnc_symbol = c("hgnc_symbol_lookup", "non_alt_loci_set"),
    mcp_public_entity = c(
      "ndd_entity", "non_alt_loci_set", "disease_ontology_set",
      "mode_of_inheritance_list", "ndd_entity_status",
      "ndd_entity_status_categories_list", "boolean_list", "ndd_entity_review"
    ),
    mcp_public_disease = "disease_ontology_set",
    mcp_public_phenotype = "phenotype_list",
    mcp_public_variation = "variation_ontology_list",
    mcp_public_comparison = c(
      "ndd_entity", "ndd_entity_status", "ndd_entity_status_categories_list",
      "disease_ontology_set", "mode_of_inheritance_list", "non_alt_loci_set",
      "ndd_database_comparison"
    ),
    mcp_public_comparison_metadata = "comparisons_metadata",
    mcp_public_review = c("ndd_entity_review", "mcp_public_entity"),
    mcp_public_review_phenotype = c(
      "ndd_review_phenotype_connect", "mcp_public_review", "mcp_public_entity",
      "phenotype_list", "modifier_list"
    ),
    mcp_public_review_variation = c(
      "ndd_review_variation_ontology_connect", "mcp_public_review", "mcp_public_entity",
      "variation_ontology_list", "modifier_list"
    ),
    mcp_public_review_publication = c(
      "ndd_review_publication_join", "mcp_public_review", "mcp_public_entity", "publication"
    ),
    mcp_public_analysis_source_version = c(
      "ndd_entity_view", "ndd_entity_review", "ndd_review_phenotype_connect",
      "ndd_entity_status"
    ),
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
    mcp_public_nddscore_release = "nddscore_release",
    mcp_public_nddscore_gene_prediction = c(
      "nddscore_gene_prediction", "mcp_public_nddscore_release"
    ),
    mcp_public_nddscore_hpo_prediction = c(
      "nddscore_hpo_prediction", "mcp_public_nddscore_release"
    )
  )
}

mcp_readonly_llm_summary_json_keys <- function() {
  c(
    "summary", "key_themes", "pathways", "tags", "clinical_relevance", "confidence",
    "key_phenotype_themes", "notably_absent", "clinical_pattern", "syndrome_hints",
    "inheritance_patterns", "syndromicity", "data_quality_note"
  )
}

mcp_readonly_normalize_view_sql <- function(sql, schema = NULL) {
  sql <- gsub("`", "", as.character(sql), fixed = TRUE)
  sql <- tolower(sql)
  if (!is.null(schema) && length(schema) == 1L && !is.na(schema) && nzchar(schema)) {
    sql <- gsub(paste0(tolower(schema), "."), "", sql, fixed = TRUE)
  }
  sql <- gsub("_(utf8mb4|utf8mb3)(?=')", "", sql, perl = TRUE)
  sql <- gsub(
    "\\bas\\s+char\\s+(character\\s+set|charset)\\s+",
    "cast_character_set_",
    sql,
    perl = TRUE
  )
  sql <- gsub("\\bas\\s+[a-z_][a-z0-9_]*\\b", "", sql, perl = TRUE)
  sql <- gsub("[()]", "", sql, perl = TRUE)
  sql <- gsub("[[:space:]]+", "", trimws(sql), perl = TRUE)
  gsub("count\\*", "count0", sql, perl = TRUE)
}

mcp_readonly_trusted_view_definitions <- function(migration_path) {
  if (!is.character(migration_path) || length(migration_path) != 1L ||
    is.na(migration_path) || !file.exists(migration_path)) {
    stop("Trusted MCP projection migration is unavailable", call. = FALSE)
  }

  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
  statements <- trimws(unlist(strsplit(sql, ";", fixed = TRUE), use.names = FALSE))
  statements <- statements[grepl("CREATE\\s+OR\\s+REPLACE", statements,
    perl = TRUE, ignore.case = TRUE
  )]

  parsed <- lapply(statements, function(statement) {
    match <- regexec(
      "(?s)VIEW\\s+`([^`]+)`\\s+AS\\s+(.+)$",
      statement,
      perl = TRUE,
      ignore.case = TRUE
    )
    parts <- regmatches(statement, match)[[1L]]
    if (length(parts) != 3L) {
      stop("Could not parse a trusted MCP projection definition", call. = FALSE)
    }
    list(name = parts[[2L]], definition = mcp_readonly_normalize_view_sql(parts[[3L]]))
  })
  definitions <- setNames(
    vapply(parsed, `[[`, character(1), "definition"),
    vapply(parsed, `[[`, character(1), "name")
  )

  expected <- mcp_readonly_projection_names()
  if (!setequal(names(definitions), expected)) {
    stop("Trusted MCP projection names do not match the contract", call. = FALSE)
  }
  definitions[expected]
}

mcp_readonly_canonical_hash_runtime <- function() {
  list(database_family = "MySQL", major_minor = "8.4")
}

mcp_readonly_normalize_canonical_view_sql <- function(sql, schema) {
  if (!is.character(schema) || length(schema) != 1L || is.na(schema) || !nzchar(schema)) {
    stop("Canonical view normalization requires the current schema", call. = FALSE)
  }
  sql <- tolower(gsub("`", "", as.character(sql), fixed = TRUE))
  sql <- gsub(paste0(tolower(schema), "."), "", sql, fixed = TRUE)
  gsub("[[:space:]]+", "", trimws(sql), perl = TRUE)
}

mcp_readonly_canonical_view_hash <- function(sql, schema) {
  normalized <- mcp_readonly_normalize_canonical_view_sql(sql, schema)
  as.character(openssl::sha256(charToRaw(normalized)))
}

mcp_readonly_canonical_view_hashes <- function() {
  hashes <- c(
    mcp_public_analysis_cluster = "853a6521dbaf99a7569374644cc7503841d598b92bbee803b0c9a3ff0ca4f56a",
    mcp_public_analysis_cluster_member = "b664babbc5d55d4b12ed0e05d0c1a672ca13eb8d2c9658030998d349c7d9c562",
    mcp_public_analysis_correlation = "6e81875730ffc3062c81f6f45379f998ffb5f32146e9cdb9e049d677523e187e",
    mcp_public_analysis_manifest = "daf5d311338e979c5970cd547f4cf9615ae45635d6f29e6b99afee2162322e1d",
    mcp_public_analysis_network_edge = "45b2c219da158450bcdff204591cb57b3da712c08a2502c1207c5c8af0d4f640",
    mcp_public_analysis_network_node = "38294db942b51382336302c8aa1d43b5ff5a9434d0f069e348e5bb3fad096c25",
    mcp_public_analysis_source_version = "376a60bcd3a61422cd8609fe8943f498869d83684d518e969713269f74ccfb92",
    mcp_public_comparison = "9d6096f779f12c7e486cc405d6152483f0a84aa6d583314fc9b67ab2a31b96e8",
    mcp_public_comparison_metadata = "9d0398d0ac250b386970e26400ba6948b5acfcd8ab582fe4e812ea1a8fb91070",
    mcp_public_disease = "5122a87d4e5dd70433ca063ea6e553464245addbd1cd704a7de0af0eec4b21e1",
    mcp_public_entity = "3bb1727c4b96e22bfca80515e27cbf05ab740e2f932315d123ceb182022dcfdd",
    mcp_public_gene = "815c29add03b5df33aee541f5e307c6b5651ed635cc952267a8680e0d7eda2bb",
    mcp_public_hgnc_symbol = "53e707bf34951a9aa55cd027597735f36081853142f3c59f0f51cb5f533a3d35",
    mcp_public_llm_cluster_summary = "60a1c566be84d00354a61a06594545c0c0353f913e35d6f9faa6ff57b1cf4588",
    mcp_public_nddscore_gene_prediction = "968386c07100f86d9face99bb4776c5480ada3a2f21c221b3791e1399a0ed229",
    mcp_public_nddscore_hpo_prediction = "8d1ab672bfb2869b140cd85c53ae3b3bb17d47ce6c8d94b658ae744ca3595044",
    mcp_public_nddscore_release = "c676fd86a3e2b08c670f504f66b2ca85b85a00fb29e17436304a1f0423cbb6d3",
    mcp_public_phenotype = "8ebcec9600ad762d5e8a9bd67e355108c6ad25b8c23d47f61e5c63ce3da22055",
    mcp_public_review = "945fc423eb3c74587f900945173fc08d9951a33f25331bf7a6643346210bbcec",
    mcp_public_review_phenotype = "beacd69fae52ab8d5ca707366de21bc58fa366cc7a9cc0e07bd26e2a2b3a761b",
    mcp_public_review_publication = "a62902387e780323d65466eef1913d0739551a0c3e7dfb17a163e4dcb3a044be",
    mcp_public_review_variation = "a37114e422c2ec3ab1be4f544fbda443647339eb50e8ad4d0cf9271d62dd712b",
    mcp_public_variation = "4d9b49ea8940e4d5293a8623184571363bdbea2bf1656589db324591381d3365"
  )
  hashes[mcp_readonly_projection_names()]
}
