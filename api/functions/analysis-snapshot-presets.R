ANALYSIS_SNAPSHOT_SCHEMA_VERSION <- "1.0"

analysis_snapshot_unsupported_parameter <- function(message, fields = list()) {
  rlang::abort(
    message = message,
    class = "analysis_snapshot_unsupported_parameter_error",
    !!!fields
  )
}

analysis_snapshot_supported_presets <- function() {
  list(
    list(analysis_type = "functional_clusters", data_class = "curated_derived_analysis", params = list(algorithm = "leiden")),
    list(analysis_type = "phenotype_clusters", data_class = "curated_derived_analysis", params = list()),
    list(analysis_type = "phenotype_correlations", data_class = "curated_derived_analysis", params = list(filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)")),
    list(analysis_type = "phenotype_functional_correlations", data_class = "curated_derived_analysis", params = list(algorithm = "leiden")),
    list(analysis_type = "gene_network_edges", data_class = "curated_derived_analysis", params = list(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L))
  )
}

analysis_snapshot_canonical_json <- function(value) {
  as.character(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", dataframe = "rows"))
}

analysis_snapshot_parameter_hash <- function(analysis_type, params) {
  digest::digest(
    paste0(analysis_type, ":", analysis_snapshot_canonical_json(params)),
    algo = "sha256",
    serialize = FALSE
  )
}

analysis_snapshot_normalize_params <- function(analysis_type, params = list()) {
  analysis_type <- as.character(analysis_type[[1]])
  if (is.null(params)) {
    params <- list()
  }
  if (!is.list(params)) {
    analysis_snapshot_unsupported_parameter(
      "Analysis snapshot parameters must be a list",
      fields = list(analysis_type = analysis_type)
    )
  }

  presets <- analysis_snapshot_supported_presets()
  preset <- NULL
  for (candidate in presets) {
    if (identical(candidate$analysis_type, analysis_type)) {
      preset <- candidate
      break
    }
  }

  if (is.null(preset)) {
    analysis_snapshot_unsupported_parameter(
      sprintf("Unsupported analysis snapshot type: %s", analysis_type),
      fields = list(analysis_type = analysis_type)
    )
  }

  normalized_params <- preset$params
  supported_names <- names(preset$params)
  supplied_names <- names(params)
  if (length(params) > 0L && (is.null(supplied_names) || any(is.na(supplied_names) | !nzchar(supplied_names)))) {
    analysis_snapshot_unsupported_parameter(
      "Analysis snapshot parameters must be named",
      fields = list(analysis_type = analysis_type)
    )
  }
  unsupported_names <- setdiff(supplied_names, supported_names)

  if (length(unsupported_names) > 0L) {
    analysis_snapshot_unsupported_parameter(
      sprintf("Unsupported analysis snapshot parameter: %s", paste(unsupported_names, collapse = ", ")),
      fields = list(analysis_type = analysis_type, parameters = unsupported_names)
    )
  }

  for (name in supplied_names) {
    normalized_params[[name]] <- params[[name]]
  }

  if (identical(analysis_type, "gene_network_edges")) {
    normalized_params$min_confidence <- analysis_snapshot_coerce_integer(
      normalized_params$min_confidence,
      "min_confidence",
      analysis_type
    )
    normalized_params$max_edges <- analysis_snapshot_coerce_integer(
      normalized_params$max_edges,
      "max_edges",
      analysis_type
    )
  }

  if (!identical(normalized_params, preset$params)) {
    analysis_snapshot_unsupported_parameter(
      sprintf("Unsupported parameters for analysis snapshot type: %s", analysis_type),
      fields = list(analysis_type = analysis_type, params = normalized_params)
    )
  }

  parameters_json <- analysis_snapshot_canonical_json(normalized_params)
  list(
    analysis_type = analysis_type,
    data_class = preset$data_class,
    params = normalized_params,
    parameters_json = parameters_json,
    parameter_hash = analysis_snapshot_parameter_hash(analysis_type, normalized_params)
  )
}

analysis_snapshot_coerce_integer <- function(value, field, analysis_type) {
  if (length(value) == 0L || is.null(value[[1]])) {
    analysis_snapshot_unsupported_parameter(
      sprintf("Unsupported integer value for %s", field),
      fields = list(analysis_type = analysis_type, parameter = field)
    )
  }
  coerced <- suppressWarnings(as.integer(value[[1]]))
  numeric_value <- suppressWarnings(as.numeric(value[[1]]))
  if (is.na(coerced) || is.na(numeric_value) || !identical(as.numeric(coerced), numeric_value)) {
    analysis_snapshot_unsupported_parameter(
      sprintf("Unsupported integer value for %s", field),
      fields = list(analysis_type = analysis_type, parameter = field)
    )
  }
  coerced
}
