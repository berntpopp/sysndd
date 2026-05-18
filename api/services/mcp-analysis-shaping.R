# services/mcp-analysis-shaping.R
#
# Analysis data-class, provenance, and response-budget helpers for MCP analysis tools.

MCP_ANALYSIS_DATA_CLASSES <- c(
  "curated_sysndd_evidence",
  "curated_derived_analysis",
  "ml_prediction",
  "llm_generated_summary",
  "external_reference_identifier",
  "operational_metadata"
)
MCP_ANALYSIS_RESPONSE_MODES <- c("minimal", "compact", "standard", "full", "diagnostics")
MCP_ANALYSIS_MODE_BUDGETS <- list(
  minimal = 4000L,
  compact = 12000L,
  standard = 24000L,
  full = 48000L,
  diagnostics = 6000L
)
MCP_GENE_RESEARCH_SECTIONS <- c(
  "curated",
  "comparison",
  "nddscore",
  "phenotype_clusters",
  "phenotype_correlations",
  "phenotype_functional_correlations",
  "gene_network",
  "cached_llm_summaries",
  "external_identifiers"
)

mcp_analysis_provenance <- function(data_class,
                                    source,
                                    source_table_or_view,
                                    generated_by,
                                    filters = list(),
                                    limitations = list()) {
  data_class <- mcp_validate_enum(data_class, MCP_ANALYSIS_DATA_CLASSES, "data_class")

  if (identical(data_class, "curated_sysndd_evidence")) {
    curation_effect <- "curated_evidence"
    not_evidence_tier <- FALSE
  } else {
    curation_effect <- "none"
    not_evidence_tier <- TRUE
  }

  class_limitations <- switch(
    data_class,
    ml_prediction = list(
      "ML prediction; model-derived; separate from curated SysNDD evidence; Not an evidence tier."
    ),
    llm_generated_summary = list(
      "LLM-generated cached summary; admin-generated; Cache-only; does not change curated SysNDD evidence."
    ),
    curated_derived_analysis = list(
      "Derived analysis for hypothesis generation; correlations, clusters, and networks are not causal claims."
    ),
    external_reference_identifier = list(
      "External reference identifier stored in SysNDD; no live external provider call was made by MCP."
    ),
    list()
  )

  list(
    schema_version = MCP_SCHEMA_VERSION,
    data_class = data_class,
    curation_effect = curation_effect,
    not_evidence_tier = not_evidence_tier,
    source = source,
    provenance = list(
      source_table_or_view = source_table_or_view,
      filters = filters,
      generated_by = generated_by
    ),
    limitations = c(class_limitations, limitations)
  )
}

mcp_analysis_response_budget <- function(response_mode = "compact",
                                         max_response_chars = "auto") {
  response_mode <- mcp_validate_enum(response_mode, MCP_ANALYSIS_RESPONSE_MODES, "response_mode")
  if (identical(max_response_chars, "auto") || is.null(max_response_chars)) {
    max_chars <- MCP_ANALYSIS_MODE_BUDGETS[[response_mode]]
  } else {
    max_chars <- suppressWarnings(as.integer(max_response_chars))
    if (is.na(max_chars) || max_chars < 1000L || max_chars > 80000L) {
      stop(mcp_error(
        "invalid_input",
        "max_response_chars must be 'auto' or an integer between 1000 and 80000",
        list(argument = "max_response_chars")
      ))
    }
  }

  list(
    response_mode = response_mode,
    max_response_chars = max_chars,
    diagnostics_only = identical(response_mode, "diagnostics"),
    total_chars = 0L,
    estimated_tokens = 0L,
    truncated = FALSE,
    dropped_records = 0L,
    dropped_summary = list()
  )
}

mcp_analysis_estimate_chars <- function(value) {
  nchar(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null"), type = "chars")
}

mcp_analysis_finalize_budget <- function(value, budget) {
  total_chars <- mcp_analysis_estimate_chars(value)
  budget$total_chars <- total_chars
  budget$estimated_tokens <- ceiling(total_chars / 4)
  budget$truncated <- isTRUE(budget$truncated) || total_chars > budget$max_response_chars
  budget
}

mcp_analysis_finalize_response_budget <- function(response, budget, max_iterations = 5L) {
  response$budget <- budget
  for (i in seq_len(max_iterations)) {
    next_budget <- mcp_analysis_finalize_budget(response, response$budget)
    if (identical(next_budget$total_chars, response$budget$total_chars)) {
      response$budget <- next_budget
      return(response)
    }
    response$budget <- next_budget
  }
  response
}

mcp_analysis_trim_records <- function(records,
                                      max_records,
                                      budget,
                                      label = "records") {
  total <- length(records)
  kept <- utils::head(records, max_records)
  dropped <- max(0L, total - length(kept))
  while (length(kept) > 1L && mcp_analysis_estimate_chars(kept) > budget$max_response_chars) {
    kept <- utils::head(kept, length(kept) - 1L)
    dropped <- dropped + 1L
  }
  if (dropped > 0L) {
    budget$truncated <- TRUE
    budget$dropped_records <- budget$dropped_records + dropped
    budget$dropped_summary <- c(
      budget$dropped_summary,
      list(list(section = label, dropped_records = dropped))
    )
  }
  budget <- mcp_analysis_finalize_budget(kept, budget)
  list(records = kept, budget = budget)
}

mcp_analysis_trim_sections <- function(sections,
                                       priority,
                                       budget) {
  kept <- sections
  ordered_names <- intersect(priority, names(kept))
  overflow_names <- setdiff(names(kept), ordered_names)
  drop_order <- rev(c(ordered_names, overflow_names))

  while (length(kept) > 1L && mcp_analysis_estimate_chars(kept) > budget$max_response_chars && length(drop_order) > 0L) {
    drop_name <- drop_order[[1]]
    drop_order <- drop_order[-1]
    if (!drop_name %in% names(kept)) next
    kept[[drop_name]] <- NULL
    budget$truncated <- TRUE
    budget$dropped_records <- budget$dropped_records + 1L
    budget$dropped_summary <- c(
      budget$dropped_summary,
      list(list(section = drop_name, dropped_section = TRUE))
    )
  }

  budget <- mcp_analysis_finalize_budget(kept, budget)
  list(sections = kept, budget = budget)
}
