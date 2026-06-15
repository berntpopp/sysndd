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
    list(
      analysis_type = "functional_clusters",
      data_class = "curated_derived_analysis",
      params = list(algorithm = "leiden"),
      # "heavy": recursive STRING enrichment; staggered behind the cheap presets
      # at first-start to avoid worker-lease contention (#447, #440).
      weight = "heavy"
    ),
    list(
      analysis_type = "phenotype_clusters",
      data_class = "curated_derived_analysis",
      params = list(),
      weight = "light"
    ),
    list(
      analysis_type = "phenotype_correlations",
      data_class = "curated_derived_analysis",
      params = list(filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)"),
      weight = "light"
    ),
    list(
      analysis_type = "phenotype_functional_correlations",
      data_class = "curated_derived_analysis",
      params = list(algorithm = "leiden"),
      weight = "light"
    ),
    list(
      analysis_type = "gene_network_edges",
      data_class = "curated_derived_analysis",
      params = list(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L),
      weight = "light"
    )
  )
}

#' Bootstrap weight for a supported preset.
#'
#' "heavy" presets (currently only `functional_clusters`, with its recursive
#' STRING enrichment build) are staggered behind the cheap "light" presets at
#' first-start so a single small-host worker does not contend for the shared DB
#' pool / CPU and push the heavy build over its lease (#447). Unknown types fail
#' open to "light" so an unrecognized preset is never delayed.
#'
#' @param analysis_type Character analysis type.
#' @return "heavy" or "light".
#' @export
analysis_snapshot_preset_weight <- function(analysis_type) {
  at <- as.character(analysis_type[[1]])
  for (p in analysis_snapshot_supported_presets()) {
    if (identical(p$analysis_type, at)) {
      w <- p$weight
      if (is.null(w) || !nzchar(as.character(w[[1]]))) {
        return("light")
      }
      return(as.character(w[[1]]))
    }
  }
  "light"
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

  if (identical(analysis_type, "phenotype_correlations") && "filter" %in% supplied_names) {
    normalized_params$filter <- analysis_snapshot_normalize_filter_param(
      normalized_params$filter,
      preset$params$filter
    )
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
      sprintf(
        paste(
          "Unsupported parameters for analysis snapshot type: %s.",
          "Only supported public preset values are accepted.",
          "Phenotype correlation filters tolerate case and whitespace differences only."
        ),
        analysis_type
      ),
      fields = list(
        analysis_type = analysis_type,
        params = normalized_params,
        supported_params = preset$params
      )
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

analysis_snapshot_normalize_filter_param <- function(value, supported_value) {
  if (is.null(value) || length(value) == 0L || is.null(value[[1]])) {
    return(value)
  }
  value <- as.character(value[[1]])
  normalize <- function(x) {
    gsub("\\s+", "", tolower(trimws(as.character(x[[1]]))))
  }
  if (identical(normalize(value), normalize(supported_value))) {
    return(supported_value)
  }
  value
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
