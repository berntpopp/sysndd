# Read-only NDDScore repository helpers.
#
# These functions serve the single active NDDScore release. Per-gene, per-HPO,
# and per-term reads go through the *_current views, whose release scope is
# controlled by nddscore_release.is_active. Sort and filter inputs are validated
# against local whitelists before any SQL is assembled. User values are always
# bound through db_execute_query() ? placeholders with unnamed parameter lists.

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0) {
    b
  } else {
    a
  }
}

.nddscore_gene_sort_cols <- c(
  hgnc_id = "`hgnc_id`",
  gene_symbol = "`gene_symbol`",
  ndd_score = "`ndd_score`",
  rank = "`rank`",
  percentile = "`percentile`",
  risk_tier = "`risk_tier`",
  confidence_tier = "`confidence_tier`",
  known_sysndd_gene = "`known_sysndd_gene`",
  n_predicted_hpo = "`n_predicted_hpo`"
)

.nddscore_hpo_sort_cols <- c(
  hgnc_id = "`hgnc_id`",
  gene_symbol = "`gene_symbol`",
  phenotype_id = "`phenotype_id`",
  phenotype_name = "`phenotype_name`",
  probability = "`probability`",
  rank_for_gene = "`rank_for_gene`",
  passes_default_threshold = "`passes_default_threshold`",
  term_auc_roc = "`term_auc_roc`",
  term_auc_pr = "`term_auc_pr`",
  term_training_support = "`term_training_support`"
)

.nddscore_gene_filter_cols <- c(
  "hgnc_id", "gene_symbol", "risk_tier", "confidence_tier",
  "known_sysndd_gene", "model_split", "top_inheritance_mode",
  "ndd_score_min", "ndd_score_max", "rank_min", "rank_max",
  "percentile_min", "percentile_max", "hpo_terms", "search"
)

.nddscore_hpo_filter_cols <- c(
  "hgnc_id", "gene_symbol", "phenotype_id", "phenotype_name",
  "passes_default_threshold", "search"
)

.nddscore_clamp_page <- function(page, page_size) {
  page <- suppressWarnings(as.integer(page %||% 1L))
  page_size <- suppressWarnings(as.integer(page_size %||% 25L))

  if (is.na(page) || page < 1L) {
    page <- 1L
  }
  if (is.na(page_size) || page_size < 1L) {
    page_size <- 25L
  }
  page_size <- min(page_size, 200L)

  list(
    page = page,
    page_size = page_size,
    limit = page_size,
    offset = (page - 1L) * page_size
  )
}

.nddscore_check_sort <- function(sort, allowed) {
  sort <- sort %||% names(allowed)[[1]]
  if (!is.character(sort) || length(sort) != 1L || is.na(sort) || !nzchar(sort)) {
    stop("Invalid sort column", call. = FALSE)
  }

  direction <- "ASC"
  column <- sort
  if (startsWith(column, "-")) {
    direction <- "DESC"
    column <- substring(column, 2L)
  }

  if (!column %in% names(allowed)) {
    stop(sprintf("Invalid sort column '%s'", column), call. = FALSE)
  }

  list(column = unname(allowed[[column]]), direction = direction)
}

.nddscore_check_filters <- function(filters, allowed) {
  if (is.null(filters)) {
    return(list())
  }
  if (!is.list(filters)) {
    stop("Filters must be a named list", call. = FALSE)
  }
  if (length(filters) == 0L) {
    return(filters)
  }
  filter_names <- names(filters)
  if (is.null(filter_names) || any(!nzchar(filter_names))) {
    stop("Filters must be a named list", call. = FALSE)
  }
  invalid <- setdiff(filter_names, allowed)
  if (length(invalid) > 0L) {
    stop(sprintf("Invalid filter column '%s'", invalid[[1]]), call. = FALSE)
  }
  filters
}

.nddscore_scalar_bool <- function(value) {
  if (is.logical(value)) {
    return(as.integer(isTRUE(value)))
  }
  if (is.numeric(value)) {
    return(as.integer(value[[1]] != 0))
  }

  value <- tolower(trimws(as.character(value[[1]])))
  if (value %in% c("true", "t", "yes", "y", "1")) {
    return(1L)
  }
  if (value %in% c("false", "f", "no", "n", "0")) {
    return(0L)
  }

  suppressWarnings(as.integer(value))
}

.nddscore_scalar_number <- function(value) {
  number <- suppressWarnings(as.numeric(value[[1]]))
  if (is.na(number) || !is.finite(number)) {
    return(NULL)
  }
  number
}

.nddscore_scalar_integer <- function(value) {
  number <- suppressWarnings(as.integer(value[[1]]))
  if (is.na(number)) {
    return(NULL)
  }
  number
}

.nddscore_vector_values <- function(value) {
  if (is.null(value)) {
    return(character(0))
  }
  if (length(value) == 1L && is.character(value) && grepl(",", value, fixed = TRUE)) {
    value <- unlist(strsplit(value, ",", fixed = TRUE), use.names = FALSE)
  }
  value <- trimws(as.character(value))
  value[nzchar(value)]
}

.nddscore_empty <- function(result) {
  is.null(result) || nrow(result) == 0L
}

nddscore_repo_current_release <- function() {
  db_execute_query(
    "
      SELECT release_id, score_schema_version, version, release_created_at,
             n_genes, n_hpo_predictions, n_hpo_terms, n_features,
             hpo_threshold, calibration_method, ndd_model_created_at,
             phenotype_model_created_at, inheritance_model_created_at,
             ndd_performance_json, phenotype_performance_json,
             inheritance_performance_json, data_versions_json,
             artifact_hashes_json, zenodo_record_url, version_doi,
             concept_doi, source_record_id, source_archive_name,
             source_archive_checksum, source_archive_bytes, is_active,
             import_status, import_completed_at, activated_at
      FROM nddscore_release
      WHERE is_active = 1
      LIMIT 1",
    unname(list())
  )
}

nddscore_repo_genes <- function(
    filters = list(),
    sort = "rank",
    page = 1L,
    page_size = 25L) {
  filters <- .nddscore_check_filters(filters, .nddscore_gene_filter_cols)
  sort_spec <- .nddscore_check_sort(sort, .nddscore_gene_sort_cols)
  paging <- .nddscore_clamp_page(page, page_size)

  where <- character(0)
  params <- list()

  if (!is.null(filters$risk_tier) && nzchar(filters$risk_tier)) {
    where <- c(where, "`risk_tier` = ?")
    params <- c(params, list(filters$risk_tier))
  }
  if (!is.null(filters$confidence_tier) && nzchar(filters$confidence_tier)) {
    where <- c(where, "`confidence_tier` = ?")
    params <- c(params, list(filters$confidence_tier))
  }
  if (!is.null(filters$known_sysndd_gene) && nzchar(as.character(filters$known_sysndd_gene))) {
    where <- c(where, "`known_sysndd_gene` = ?")
    params <- c(params, list(.nddscore_scalar_bool(filters$known_sysndd_gene)))
  }
  if (!is.null(filters$model_split) && nzchar(filters$model_split)) {
    where <- c(where, "`model_split` = ?")
    params <- c(params, list(filters$model_split))
  }
  if (!is.null(filters$top_inheritance_mode) && nzchar(filters$top_inheritance_mode)) {
    where <- c(where, "`top_inheritance_mode` = ?")
    params <- c(params, list(filters$top_inheritance_mode))
  }
  if (!is.null(filters$ndd_score_min)) {
    ndd_score_min <- .nddscore_scalar_number(filters$ndd_score_min)
    if (!is.null(ndd_score_min)) {
      where <- c(where, "`ndd_score` >= ?")
      params <- c(params, list(ndd_score_min))
    }
  }
  if (!is.null(filters$ndd_score_max)) {
    ndd_score_max <- .nddscore_scalar_number(filters$ndd_score_max)
    if (!is.null(ndd_score_max)) {
      where <- c(where, "`ndd_score` <= ?")
      params <- c(params, list(ndd_score_max))
    }
  }
  if (!is.null(filters$rank_min)) {
    rank_min <- .nddscore_scalar_integer(filters$rank_min)
    if (!is.null(rank_min)) {
      where <- c(where, "`rank` >= ?")
      params <- c(params, list(rank_min))
    }
  }
  if (!is.null(filters$rank_max)) {
    rank_max <- .nddscore_scalar_integer(filters$rank_max)
    if (!is.null(rank_max)) {
      where <- c(where, "`rank` <= ?")
      params <- c(params, list(rank_max))
    }
  }
  if (!is.null(filters$percentile_min)) {
    percentile_min <- .nddscore_scalar_number(filters$percentile_min)
    if (!is.null(percentile_min)) {
      where <- c(where, "`percentile` >= ?")
      params <- c(params, list(percentile_min))
    }
  }
  if (!is.null(filters$percentile_max)) {
    percentile_max <- .nddscore_scalar_number(filters$percentile_max)
    if (!is.null(percentile_max)) {
      where <- c(where, "`percentile` <= ?")
      params <- c(params, list(percentile_max))
    }
  }
  if (!is.null(filters$hgnc_id) && nzchar(filters$hgnc_id)) {
    where <- c(where, "`hgnc_id` = ?")
    params <- c(params, list(filters$hgnc_id))
  }
  if (!is.null(filters$gene_symbol) && nzchar(filters$gene_symbol)) {
    where <- c(where, "UPPER(`gene_symbol`) = UPPER(?)")
    params <- c(params, list(filters$gene_symbol))
  }
  if (!is.null(filters$search) && nzchar(filters$search)) {
    where <- c(where, "(`hgnc_id` = ? OR UPPER(`gene_symbol`) LIKE UPPER(?))")
    params <- c(params, list(filters$search, paste0("%", filters$search, "%")))
  }
  hpo_terms <- .nddscore_vector_values(filters$hpo_terms)
  if (length(hpo_terms) > 0L) {
    hpo_clause <- paste(rep("JSON_SEARCH(`top_hpo_predictions_json`, 'one', ?) IS NOT NULL", length(hpo_terms)), collapse = " OR ")
    where <- c(where, paste0("(", hpo_clause, ")"))
    params <- c(params, as.list(hpo_terms))
  }

  where_sql <- if (length(where) > 0L) {
    paste("WHERE", paste(where, collapse = " AND "))
  } else {
    ""
  }

  count_sql <- paste(
    "SELECT COUNT(*) AS total",
    "FROM nddscore_gene_prediction_current",
    where_sql
  )
  count_result <- db_execute_query(count_sql, unname(params))
  total <- as.integer(count_result$total[[1]] %||% 0L)

  data_sql <- paste(
    "SELECT release_id, hgnc_id, gene_symbol, ensembl_gene_id, ndd_score,",
    "       ndd_score_std, ndd_score_iqr, bag_agreement, `rank`, percentile,",
    "       risk_tier, confidence_tier, known_sysndd_gene, model_split,",
    "       inheritance_ad_probability, inheritance_ar_probability,",
    "       inheritance_xld_probability, inheritance_xlr_probability,",
    "       top_inheritance_mode, called_inheritance_modes, n_predicted_hpo,",
    "       top_hpo_predictions_json, shap_clinical, shap_constraint,",
    "       shap_expression, shap_network, shap_conservation, shap_other,",
    "       dominant_shap_group, top_features_json, prediction_note",
    "FROM nddscore_gene_prediction_current",
    where_sql,
    sprintf("ORDER BY %s %s, `rank` ASC, `hgnc_id` ASC", sort_spec$column, sort_spec$direction),
    "LIMIT ? OFFSET ?"
  )
  data <- db_execute_query(
    data_sql,
    unname(c(params, list(paging$limit, paging$offset)))
  )

  list(
    data = data,
    total = total,
    page = paging$page,
    page_size = paging$page_size
  )
}

nddscore_repo_gene_detail <- function(hgnc_id_or_symbol) {
  if (is.null(hgnc_id_or_symbol) || !is.character(hgnc_id_or_symbol) ||
      length(hgnc_id_or_symbol) != 1L || !nzchar(hgnc_id_or_symbol)) {
    stop("hgnc_id_or_symbol must be a non-empty string", call. = FALSE)
  }

  gene <- db_execute_query(
    "
      SELECT release_id, hgnc_id, gene_symbol, ensembl_gene_id, ndd_score,
             ndd_score_std, ndd_score_iqr, bag_agreement, `rank`, percentile,
             risk_tier, confidence_tier, known_sysndd_gene, model_split,
             inheritance_ad_probability, inheritance_ar_probability,
             inheritance_xld_probability, inheritance_xlr_probability,
             top_inheritance_mode, called_inheritance_modes, n_predicted_hpo,
             top_hpo_predictions_json, shap_clinical, shap_constraint,
             shap_expression, shap_network, shap_conservation, shap_other,
             dominant_shap_group, top_features_json, prediction_note
      FROM nddscore_gene_prediction_current
      WHERE hgnc_id = ? OR UPPER(gene_symbol) = UPPER(?)
      ORDER BY `rank` ASC
      LIMIT 1",
    unname(list(hgnc_id_or_symbol, hgnc_id_or_symbol))
  )

  if (.nddscore_empty(gene)) {
    return(list(
      gene = NULL,
      hpo_predictions = tibble::tibble()
    ))
  }

  hpo <- db_execute_query(
    "
      SELECT release_id, hgnc_id, gene_symbol, phenotype_id,
             phenotype_name, probability, rank_for_gene,
             passes_default_threshold, term_auc_roc, term_auc_pr,
             term_training_support
      FROM nddscore_hpo_prediction_current
      WHERE hgnc_id = ?
      ORDER BY rank_for_gene ASC, probability DESC, phenotype_id ASC",
    unname(list(gene$hgnc_id[[1]]))
  )

  list(
    gene = gene,
    hpo_predictions = hpo
  )
}

nddscore_repo_hpo <- function(
    filters = list(),
    sort = "-probability",
    page = 1L,
    page_size = 25L) {
  filters <- .nddscore_check_filters(filters, .nddscore_hpo_filter_cols)
  sort_spec <- .nddscore_check_sort(sort, .nddscore_hpo_sort_cols)
  paging <- .nddscore_clamp_page(page, page_size)

  where <- character(0)
  params <- list()

  if (!is.null(filters$hgnc_id) && nzchar(filters$hgnc_id)) {
    where <- c(where, "`hgnc_id` = ?")
    params <- c(params, list(filters$hgnc_id))
  }
  if (!is.null(filters$gene_symbol) && nzchar(filters$gene_symbol)) {
    where <- c(where, "UPPER(`gene_symbol`) = UPPER(?)")
    params <- c(params, list(filters$gene_symbol))
  }
  if (!is.null(filters$phenotype_id) && nzchar(filters$phenotype_id)) {
    where <- c(where, "`phenotype_id` = ?")
    params <- c(params, list(filters$phenotype_id))
  }
  if (!is.null(filters$phenotype_name) && nzchar(filters$phenotype_name)) {
    where <- c(where, "UPPER(`phenotype_name`) = UPPER(?)")
    params <- c(params, list(filters$phenotype_name))
  }
  if (!is.null(filters$passes_default_threshold) &&
      nzchar(as.character(filters$passes_default_threshold))) {
    where <- c(where, "`passes_default_threshold` = ?")
    params <- c(params, list(.nddscore_scalar_bool(filters$passes_default_threshold)))
  }
  if (!is.null(filters$search) && nzchar(filters$search)) {
    where <- c(
      where,
      paste(
        "(`hgnc_id` = ? OR `phenotype_id` = ?",
        "OR UPPER(`gene_symbol`) LIKE UPPER(?)",
        "OR UPPER(`phenotype_name`) LIKE UPPER(?))"
      )
    )
    params <- c(
      params,
      list(
        filters$search,
        filters$search,
        paste0("%", filters$search, "%"),
        paste0("%", filters$search, "%")
      )
    )
  }

  where_sql <- if (length(where) > 0L) {
    paste("WHERE", paste(where, collapse = " AND "))
  } else {
    ""
  }

  count_sql <- paste(
    "SELECT COUNT(*) AS total",
    "FROM nddscore_hpo_prediction_current",
    where_sql
  )
  count_result <- db_execute_query(count_sql, unname(params))
  total <- as.integer(count_result$total[[1]] %||% 0L)

  data_sql <- paste(
    "SELECT release_id, hgnc_id, gene_symbol, phenotype_id, phenotype_name,",
    "       probability, rank_for_gene, passes_default_threshold,",
    "       term_auc_roc, term_auc_pr, term_training_support",
    "FROM nddscore_hpo_prediction_current",
    where_sql,
    sprintf(
      "ORDER BY %s %s, `gene_symbol` ASC, `rank_for_gene` ASC",
      sort_spec$column,
      sort_spec$direction
    ),
    "LIMIT ? OFFSET ?"
  )
  data <- db_execute_query(
    data_sql,
    unname(c(params, list(paging$limit, paging$offset)))
  )

  list(
    data = data,
    total = total,
    page = paging$page,
    page_size = paging$page_size
  )
}

nddscore_repo_terms <- function() {
  db_execute_query(
    "
      SELECT release_id, phenotype_id, phenotype_name, term_auc_roc,
             term_auc_pr, term_training_support, is_in_ndd_subtree
      FROM nddscore_hpo_term_current
      ORDER BY phenotype_id ASC",
    unname(list())
  )
}

nddscore_repo_download_info <- function() {
  release <- nddscore_repo_current_release()
  if (.nddscore_empty(release)) {
    return(NULL)
  }

  list(
    release_id = release$release_id[[1]],
    version = release$version[[1]],
    score_schema_version = release$score_schema_version[[1]],
    record_url = release$zenodo_record_url[[1]],
    version_doi = release$version_doi[[1]],
    concept_doi = release$concept_doi[[1]],
    source_record_id = release$source_record_id[[1]],
    archive_name = release$source_archive_name[[1]],
    archive_checksum = release$source_archive_checksum[[1]],
    archive_bytes = as.numeric(release$source_archive_bytes[[1]]),
    counts = list(
      genes = as.integer(release$n_genes[[1]]),
      hpo_predictions = as.integer(release$n_hpo_predictions[[1]]),
      hpo_terms = as.integer(release$n_hpo_terms[[1]])
    ),
    imported_at = release$import_completed_at[[1]],
    activated_at = release$activated_at[[1]]
  )
}
