# services/mcp-service.R
#
# Service-layer validation and shaping for the read-only SysNDD MCP sidecar.

MCP_SCHEMA_VERSION <- "1.2"
MCP_ALLOWED_SEARCH_TYPES <- c("gene", "entity", "disease", "phenotype", "variant")
MCP_ALLOWED_ENTITY_CATEGORIES <- c("Definitive", "Moderate", "Limited", "Refuted")
MCP_MAX_ENTITY_BATCH_IDS <- 20L
MCP_MAX_GENE_BATCH <- 10L
MCP_ENTITY_PHENOTYPE_CAP <- 100L
MCP_ENTITY_VARIATION_CAP <- 100L
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
MCP_CACHE_TTLS <- list(
  get_sysndd_stats = 300L,
  search_sysndd = 60L,
  get_gene_context = 300L,
  get_entity_context = 300L,
  get_publication_context = 1800L
)

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

.mcp_cache <- new.env(parent = emptyenv())

mcp_error <- function(code, message, fields = list()) {
  structure(
    list(
      schema_version = MCP_SCHEMA_VERSION,
      error = c(list(code = code, message = message), fields)
    ),
    class = c("mcp_tool_error", "error", "condition")
  )
}

mcp_json_safe_value <- function(value) {
  if (inherits(value, "condition")) {
    return(list(message = conditionMessage(value), class = class(value)[[1]]))
  }
  if (is.list(value)) {
    return(lapply(value, mcp_json_safe_value))
  }
  if (is.environment(value) || is.function(value) || is.call(value) || is.name(value)) {
    return(as.character(value)[[1]])
  }
  value
}

mcp_error_payload <- function(error) {
  mcp_json_safe_value(unclass(error))
}

mcp_validate_no_raw_control <- function(value, argument) {
  if (grepl("(;|--|/\\*|\\*/|\\b(SELECT|INSERT|UPDATE|DELETE|DROP|ALTER|CALL|EXEC)\\b)", value, ignore.case = TRUE)) {
    stop(mcp_error("invalid_input", sprintf("%s contains unsupported control syntax", argument), list(argument = argument)))
  }
  invisible(TRUE)
}

mcp_validate_query <- function(query, min_chars = 2L, max_chars = 100L, argument = "query") {
  query <- trimws(as.character(query)[1])
  if (!nzchar(query) || nchar(query) < min_chars || nchar(query) > max_chars) {
    stop(mcp_error(
      "invalid_input",
      sprintf("%s must be between %d and %d characters", argument, min_chars, max_chars),
      list(argument = argument)
    ))
  }
  mcp_validate_no_raw_control(query, argument)
  query
}

mcp_validate_enum <- function(value, allowed, argument) {
  value <- as.character(value)[1]
  if (!value %in% allowed) {
    stop(mcp_error(
      "invalid_input",
      sprintf("%s must be one of: %s", argument, paste(allowed, collapse = ", ")),
      list(argument = argument)
    ))
  }
  value
}

mcp_validate_category <- function(category, argument = "category") {
  if (is.null(category) || !nzchar(trimws(as.character(category)[1]))) {
    return(NULL)
  }
  value <- as.character(category)[1]
  if (!value %in% MCP_ALLOWED_ENTITY_CATEGORIES) {
    stop(mcp_error(
      "invalid_input",
      sprintf("%s must be one of: %s", argument, paste(MCP_ALLOWED_ENTITY_CATEGORIES, collapse = ", ")),
      list(argument = argument, allowed_values = MCP_ALLOWED_ENTITY_CATEGORIES)
    ))
  }
  value
}

mcp_validate_mode <- function(value, allowed, argument, default) {
  if (is.null(value) || !nzchar(trimws(as.character(value)[1]))) {
    return(default)
  }
  mcp_validate_enum(value, allowed, argument)
}

mcp_response_modes <- function() c("minimal", "compact", "standard", "full")

mcp_default_abstract_mode <- function(response_mode) {
  if (identical(response_mode, "minimal")) "none" else "metadata"
}

mcp_default_synopsis_mode <- function(response_mode) {
  if (identical(response_mode, "minimal")) "none" else "excerpt"
}

mcp_validate_limit <- function(limit, default = 25L, max = 50L, name = "limit") {
  if (is.null(limit)) limit <- default
  limit <- suppressWarnings(as.integer(limit))
  if (is.na(limit) || limit < 1L || limit > max) {
    stop(mcp_error("invalid_input", sprintf("%s must be between 1 and %d", name, max), list(argument = name)))
  }
  limit
}

mcp_validate_offset <- function(offset) {
  offset <- if (is.null(offset)) 0L else suppressWarnings(as.integer(offset))
  if (is.na(offset) || offset < 0L) {
    stop(mcp_error("invalid_input", "offset must be a non-negative integer", list(argument = "offset")))
  }
  offset
}

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

mcp_normalize_gene_input <- function(gene) {
  gene <- mcp_validate_query(gene, min_chars = 1L, max_chars = 100L, argument = "gene")
  hgnc <- sub("^HGNC:", "", toupper(gene))
  if (grepl("^[0-9]+$", hgnc)) {
    return(list(kind = "hgnc_id", value = paste0("HGNC:", hgnc)))
  }
  list(kind = "symbol", value = toupper(gene))
}

mcp_normalize_pmid <- function(pmid) {
  value <- mcp_validate_query(pmid, min_chars = 1L, max_chars = 200L, argument = "pmid")
  match_pos <- regexpr("[0-9]{1,9}", value, perl = TRUE)
  if (identical(as.integer(match_pos[[1]]), -1L)) {
    stop(mcp_error("invalid_input", "pmid must contain a PubMed identifier", list(argument = "pmid")))
  }
  match <- regmatches(value, match_pos)
  paste0("PMID:", match)
}

mcp_truncate_text <- function(text, max_chars) {
  text <- if (is.null(text) || length(text) == 0L || is.na(text[1])) "" else as.character(text[1])
  max_chars <- as.integer(max_chars)
  truncated <- nchar(text) > max_chars
  list(text = substr(text, 1L, max_chars), truncated = truncated, max_chars = max_chars)
}

mcp_has_text <- function(text) {
  !is.null(text) && length(text) > 0L && !is.na(text[1]) && nzchar(trimws(as.character(text[1])))
}

mcp_full_text <- function(text) {
  text <- if (is.null(text) || length(text) == 0L || is.na(text[1])) "" else as.character(text[1])
  list(text = text, truncated = FALSE, max_chars = nchar(text))
}

mcp_first_row <- function(rows, not_found_message) {
  if (is.null(rows) || nrow(rows) == 0L) {
    stop(mcp_error("not_found", not_found_message))
  }
  rows[1, , drop = FALSE]
}

mcp_row_to_list <- function(row) {
  if (is.null(row) || nrow(row) == 0L) {
    return(list())
  }
  values <- as.list(row[1, , drop = TRUE])
  lapply(values, function(value) {
    if (inherits(value, "Date") || inherits(value, "POSIXt")) {
      return(as.character(value))
    }
    if (length(value) == 0L || is.na(value)) {
      return(NULL)
    }
    value
  })
}

mcp_rows_to_records <- function(rows) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(list())
  }
  unname(lapply(seq_len(nrow(rows)), function(i) mcp_row_to_list(rows[i, , drop = FALSE])))
}

mcp_drop_nested_schema_version <- function(item) {
  if (!is.list(item)) {
    return(item)
  }
  item$schema_version <- NULL
  item
}

mcp_compact_phenotypes <- function(rows) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(list())
  }
  modifier <- if ("modifier_name" %in% names(rows)) rows$modifier_name else rep("present", nrow(rows))
  modifier <- ifelse(is.na(modifier) | !nzchar(as.character(modifier)), "present", as.character(modifier))
  phenotype_id <- as.character(rows$phenotype_id)
  split_ids <- split(phenotype_id[!is.na(phenotype_id) & nzchar(phenotype_id)], modifier[!is.na(phenotype_id) & nzchar(phenotype_id)])
  lapply(split_ids, unique)
}

mcp_score_for_tier <- function(tier) {
  switch(tier,
    exact_identifier = 1.0,
    exact_label = 0.95,
    prefix = 0.8,
    contains = 0.6,
    0.4
  )
}

mcp_resource_uri <- function(type, id) {
  sprintf("sysndd://%s/%s", type, id)
}

mcp_decorate_entity_records <- function(rows) {
  lapply(mcp_rows_to_records(rows), function(item) {
    c(item, list(
      resource_uri = mcp_resource_uri("entity", item$entity_id),
      suggested_tools = list("get_entity_context", "get_entities_context")
    ))
  })
}

mcp_recommended_citation <- function(pub, date_confidence = "unverified") {
  trusted_date <- date_confidence %in% c("pubmed_verified", "pubmed_partial")
  pieces <- c(
    pub$Lastname,
    pub$Title,
    pub$Journal,
    if (trusted_date) pub$Publication_date else NULL,
    pub$publication_id
  )
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  pieces <- as.character(pieces)
  pieces <- pieces[!is.na(pieces) & nzchar(trimws(pieces))]
  citation <- paste(pieces, collapse = ". ")
  if (!trusted_date) {
    citation <- paste0(citation, " (publication date unverified)")
  }
  citation
}

mcp_publication_date_quality <- function(publication_date, curation_dates = NULL,
                                         date_source = NULL) {
  source_value <- if (is.null(date_source) || length(date_source) == 0L ||
                      is.na(date_source[1]) || !nzchar(as.character(date_source[1]))) {
    NA_character_
  } else {
    as.character(date_source[1])
  }

  confidence <- if (!is.na(source_value)) {
    switch(source_value,
      pubmed = "pubmed_verified",
      pubmed_partial = "pubmed_partial",
      medline_date = "pubmed_partial",
      unknown = "unverified",
      "unverified"
    )
  } else {
    "unverified"
  }

  note <- switch(confidence,
    pubmed_verified = "Publication date parsed from a complete PubMed structured date.",
    pubmed_partial = "Publication date parsed from PubMed with day and/or month defaulted to 01.",
    "Publication date from the local publication table; provenance not yet verified."
  )
  list(
    confidence = confidence,
    note = note
  )
}

mcp_publication_record <- function(pub,
                                   abstract_mode = "excerpt",
                                   abstract_max_chars = 1000L,
                                   include_keywords = FALSE,
                                   date_quality = NULL) {
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", "excerpt")
  date_quality <- date_quality %||% mcp_publication_date_quality(
    pub$Publication_date, pub$curation_review_date, pub$publication_date_source
  )
  record <- list(
    publication_id = pub$publication_id,
    title = pub$Title,
    journal = pub$Journal,
    publication_date_sysndd_record = pub$Publication_date,
    publication_date_confidence = date_quality$confidence,
    publication_date_note = date_quality$note,
    sysndd_curation_date = pub$curation_review_date,
    first_author = pub$Lastname,
    publication_type = pub$publication_type,
    recommended_citation = mcp_recommended_citation(pub, date_quality$confidence),
    resource_uri = mcp_resource_uri("publication", pub$publication_id)
  )
  if (isTRUE(include_keywords)) record$keywords <- pub$Keywords

  if (!identical(abstract_mode, "none")) {
    record$abstract_available <- mcp_has_text(pub$Abstract)
    if (identical(abstract_mode, "excerpt")) {
      abstract <- mcp_truncate_text(pub$Abstract %||% "", abstract_max_chars)
      record$abstract_excerpt <- abstract$text
      record$abstract_truncated <- abstract$truncated
    }
  }

  record
}

mcp_apply_synopsis_mode <- function(entity, synopsis_mode = "excerpt", max_chars = 2500L) {
  synopsis_mode <- mcp_validate_mode(synopsis_mode, c("none", "excerpt", "full"), "synopsis_mode", "excerpt")
  review_date <- entity$review_date
  if (inherits(review_date, "Date") || inherits(review_date, "POSIXt")) review_date <- as.character(review_date)
  review <- list(review_date = review_date)
  if (!identical(synopsis_mode, "none")) {
    synopsis <- if (identical(synopsis_mode, "full")) {
      mcp_full_text(entity$synopsis)
    } else {
      mcp_truncate_text(entity$synopsis %||% "", max_chars)
    }
    review$synopsis <- synopsis$text
    review$synopsis_truncated <- synopsis$truncated
  }
  entity$synopsis <- NULL
  entity$review_date <- NULL
  list(entity = entity, review = review)
}

mcp_publication_ref <- function(pub) {
  list(
    publication_id = pub$publication_id,
    title = pub$title,
    recommended_citation = pub$recommended_citation,
    resource_uri = pub$resource_uri
  )
}

mcp_get_sysndd_analysis_catalog <- function(include_unavailable = FALSE,
                                            response_mode = "compact") {
  response_mode <- mcp_validate_enum(response_mode, c("minimal", "compact"), "response_mode")
  analyses <- list(
    list(
      analysis_id = "gene_research_context",
      tool = "get_gene_research_context",
      data_class = "operational_metadata",
      payload_shape = "mixed_labeled_sections",
      availability = "available",
      estimated_latency_class = "fast_to_medium",
      default_limits = list(entity_limit = 10L, publication_limit = 5L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", sections = list("curated", "nddscore"), response_mode = "compact")
    ),
    list(
      analysis_id = "nddscore",
      tool = "get_nddscore_context",
      data_class = "ml_prediction",
      availability = "available",
      estimated_latency_class = "fast",
      default_limits = list(page_size = 25L, max_page_size = 50L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", response_mode = "compact")
    ),
    list(
      analysis_id = "curation_comparisons",
      tool = "get_curation_comparison_context",
      data_class = "curated_derived_analysis",
      availability = "available",
      estimated_latency_class = "fast",
      default_limits = list(page_size = 25L, max_page_size = 50L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", mode = "gene_sources")
    ),
    list(
      analysis_id = "phenotype_analysis",
      tool = "get_phenotype_analysis_context",
      data_class = "curated_derived_analysis",
      availability = "local_analysis_or_cache",
      estimated_latency_class = "medium",
      default_limits = list(limit = 25L, max_limit = 50L, max_response_chars = "auto"),
      example_call = list(mode = "correlations", phenotype = "HP:0001250", response_mode = "compact")
    ),
    list(
      analysis_id = "gene_network",
      tool = "get_gene_network_context",
      data_class = "curated_derived_analysis",
      availability = "cache_hit_only",
      estimated_latency_class = "fast_on_cache_hit",
      default_limits = list(max_edges = 100L, hard_max_edges = 250L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", dry_run = TRUE)
    ),
    list(
      analysis_id = "cached_llm_summaries",
      tool = "get_gene_research_context",
      data_class = "llm_generated_summary",
      availability = "cache_only",
      estimated_latency_class = "fast",
      default_limits = list(limit = 5L, max_limit = 20L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", sections = list("phenotype_clusters", "cached_llm_summaries"))
    )
  )
  if (!isTRUE(include_unavailable)) {
    analyses <- Filter(function(x) !identical(x$availability, "unavailable"), analyses)
  }
  if (identical(response_mode, "minimal")) {
    analyses <- lapply(analyses, function(x) x[c("analysis_id", "tool", "data_class", "availability")])
  }
  list(
    schema_version = MCP_SCHEMA_VERSION,
    response_mode = response_mode,
    analyses = analyses,
    recommended_workflow = list(
      "Call get_sysndd_analysis_catalog first for scope and limits.",
      "Use get_gene_research_context(response_mode = 'compact', dry_run = TRUE) to preflight broad gene questions.",
      "Use focused analysis tools only for narrower follow-up."
    ),
    contract = list(
      llm_generation = "never",
      llm_summaries = "current validated cache only",
      live_external_providers = "never",
      evidence_boundary = "ML and LLM outputs do not change curated SysNDD evidence"
    )
  )
}

mcp_nddscore_release_record <- function(release) {
  if (is.null(release) || nrow(release) == 0L) return(NULL)
  keep <- intersect(
    c(
      "release_id", "score_schema_version", "version", "release_created_at",
      "n_genes", "n_hpo_predictions", "n_hpo_terms", "n_features",
      "hpo_threshold", "calibration_method", "version_doi", "concept_doi",
      "source_record_id", "import_completed_at", "activated_at"
    ),
    names(release)
  )
  mcp_rows_to_records(release[keep])[[1]]
}

mcp_get_nddscore_context <- function(gene = NULL,
                                     mode = NULL,
                                     risk_tier = NULL,
                                     confidence_tier = NULL,
                                     known_sysndd_gene = NULL,
                                     hpo_terms = NULL,
                                     search = NULL,
                                     sort = "rank",
                                     page = 1L,
                                     page_size = 25L,
                                     response_mode = "compact",
                                     max_response_chars = "auto",
                                     include_diagnostics = FALSE,
                                     dry_run = FALSE) {
  mode <- mode %||% if (!is.null(gene)) "gene" else "ranked_genes"
  mode <- mcp_validate_enum(mode, c("gene", "ranked_genes", "release"), "mode")
  budget <- mcp_analysis_response_budget(response_mode, max_response_chars)
  page <- suppressWarnings(as.integer(page %||% 1L))
  if (is.na(page) || page < 1L) {
    stop(mcp_error("invalid_input", "page must be a positive integer", list(argument = "page")))
  }
  page_size <- mcp_validate_limit(page_size, default = 25L, max = 50L, name = "page_size")
  release <- mcp_analysis_repo_current_release()
  if (is.null(release) || nrow(release) == 0L) {
    stop(mcp_error("temporarily_unavailable", "No active NDDScore release is available.", list(argument = "release")))
  }
  envelope <- mcp_analysis_provenance("ml_prediction", "NDDScore", "nddscore_*_current", "nddscore_model")
  release_record <- mcp_nddscore_release_record(release)

  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
    return(c(envelope, list(
      mode = mode,
      notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier.",
      release = release_record,
      rows = list(),
      meta = list(
        page = page,
        page_size = page_size,
        diagnostics_only = TRUE,
        include_diagnostics = include_diagnostics
      ),
      budget = mcp_analysis_finalize_budget(list(mode = mode, release = release_record), budget),
      recovery = list(retry_with = list(response_mode = "compact", page = page, page_size = page_size))
    )))
  }

  if (identical(mode, "release")) {
    payload <- list(
      release = release_record,
      notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier."
    )
    return(c(envelope, payload, list(budget = mcp_analysis_finalize_budget(payload, budget))))
  }

  if (identical(mode, "gene")) {
    if (is.null(gene)) {
      stop(mcp_error("invalid_input", "gene is required when mode is gene", list(argument = "gene")))
    }
    detail <- mcp_analysis_repo_get_nddscore_gene(gene)
    if (is.null(detail$gene) || nrow(detail$gene) == 0L) {
      stop(mcp_error("not_found", sprintf("NDDScore gene '%s' was not found.", gene), list(argument = "gene")))
    }
    payload <- list(
      notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier.",
      release = release_record,
      gene = mcp_rows_to_records(detail$gene)[[1]],
      hpo_predictions = if (is.null(detail$hpo_predictions)) list() else mcp_rows_to_records(detail$hpo_predictions)
    )
    return(c(envelope, payload, list(budget = mcp_analysis_finalize_budget(payload, budget))))
  }

  filters <- Filter(Negate(is.null), list(
    risk_tier = risk_tier,
    confidence_tier = confidence_tier,
    known_sysndd_gene = known_sysndd_gene,
    hpo_terms = hpo_terms,
    search = search
  ))
  result <- tryCatch(
    mcp_analysis_repo_get_nddscore_genes(filters = filters, sort = sort, page = page, page_size = page_size),
    error = function(e) stop(mcp_error("invalid_input", conditionMessage(e), list(argument = "sort_or_filter")))
  )
  records <- mcp_rows_to_records(result$data)
  trimmed <- mcp_analysis_trim_records(records, max_records = page_size, budget = budget, label = "nddscore_genes")
  c(envelope, list(
    notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier.",
    release = release_record,
    genes = trimmed$records,
    meta = list(
      total = result$total,
      page = result$page,
      page_size = result$page_size,
      has_more = result$page * result$page_size < result$total
    ),
    budget = trimmed$budget
  ))
}

mcp_analysis_hgnc_filter <- function(gene) {
  if (is.null(gene)) {
    return(NULL)
  }
  normalized <- mcp_normalize_gene_input(gene)
  if (identical(normalized$kind, "hgnc_id")) {
    return(normalized$value)
  }
  mcp_resolve_gene_one(gene)$hgnc_id[[1]]
}

mcp_get_curation_comparison_context <- function(gene = NULL,
                                                mode = NULL,
                                                sources = NULL,
                                                category = NULL,
                                                page = 1L,
                                                page_size = 25L,
                                                response_mode = "compact",
                                                max_response_chars = "auto",
                                                include_diagnostics = FALSE,
                                                dry_run = FALSE) {
  mode <- mode %||% if (!is.null(gene)) "gene_sources" else "browse"
  if (mode %in% c("source_overlap", "source_similarity")) {
    stop(mcp_error("unsupported_mode", "Comparison plot modes are not exposed through MCP v1.2; use gene_sources or browse.", list(argument = "mode")))
  }
  mode <- mcp_validate_enum(mode, c("gene_sources", "browse"), "mode")
  budget <- mcp_analysis_response_budget(response_mode, max_response_chars)
  page <- suppressWarnings(as.integer(page %||% 1L))
  if (is.na(page) || page < 1L) {
    stop(mcp_error("invalid_input", "page must be a positive integer", list(argument = "page")))
  }
  page_size <- mcp_validate_limit(page_size, default = 25L, max = 50L, name = "page_size")
  category <- if (is.null(category)) NULL else mcp_validate_query(category, min_chars = 1L, max_chars = 100L, argument = "category")

  hgnc_id <- mcp_analysis_hgnc_filter(gene)
  total <- mcp_analysis_repo_count_comparison_rows(hgnc_id = hgnc_id, sources = sources, category = category)
  meta <- mcp_analysis_repo_get_comparison_metadata()
  envelope <- mcp_analysis_provenance("curated_derived_analysis", "SysNDD comparison view", "ndd_database_comparison_view", "sysndd_import_pipeline")

  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
    return(c(envelope, list(
      mode = mode,
      rows = list(),
      comparison_metadata = if (isTRUE(include_diagnostics)) mcp_rows_to_records(meta) else list(),
      meta = list(total = total, page = page, page_size = page_size, has_more = page * page_size < total),
      budget = mcp_analysis_finalize_budget(list(total = total, page = page, page_size = page_size), budget),
      recovery = list(retry_with = list(response_mode = "compact", page = page, page_size = min(page_size, 25L)))
    )))
  }

  rows <- mcp_analysis_repo_get_comparison_rows(hgnc_id = hgnc_id, sources = sources, category = category, page = page, page_size = page_size)
  records <- mcp_rows_to_records(rows)
  trimmed <- mcp_analysis_trim_records(records, max_records = page_size, budget = budget, label = "comparison_rows")
  c(envelope, list(
    mode = mode,
    rows = trimmed$records,
    comparison_metadata = mcp_rows_to_records(meta),
    meta = list(total = total, page = page, page_size = page_size, has_more = page * page_size < total),
    budget = trimmed$budget,
    notice = "Comparison sources are cross-references and do not alter curated SysNDD classifications."
  ))
}

mcp_parse_json_field <- function(value, default = list()) {
  if (is.null(value) || length(value) == 0L || is.na(value[[1]]) || !nzchar(as.character(value[[1]]))) {
    return(default)
  }
  tryCatch(
    jsonlite::fromJSON(as.character(value[[1]]), simplifyVector = FALSE),
    error = function(e) default
  )
}

mcp_llm_cache_miss <- function(cluster_type, cluster_hash = NULL, cluster_number = NULL) {
  c(
    mcp_analysis_provenance("llm_generated_summary", "SysNDD LLM summary cache", "llm_cluster_summary_cache", "admin_llm_workflow"),
    list(
      summary_available = FALSE,
      cache_only = TRUE,
      cluster_type = cluster_type,
      cluster_hash = cluster_hash,
      cluster_number = cluster_number
    )
  )
}

mcp_get_cached_llm_summaries <- function(cluster_type,
                                         cluster_hashes = NULL,
                                         cluster_numbers = NULL,
                                         require_validated = TRUE,
                                         limit = 10L) {
  cluster_type <- mcp_validate_enum(cluster_type, c("functional", "phenotype"), "cluster_type")
  limit <- mcp_validate_limit(limit, default = 10L, max = 20L)
  rows <- mcp_analysis_repo_get_cached_llm_summaries(
    cluster_type = cluster_type,
    cluster_hashes = cluster_hashes,
    cluster_numbers = cluster_numbers,
    require_validated = require_validated,
    limit = limit
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(list(mcp_llm_cache_miss(
      cluster_type,
      cluster_hash = (cluster_hashes %||% list(NULL))[[1]],
      cluster_number = (cluster_numbers %||% list(NULL))[[1]]
    )))
  }

  lapply(seq_len(nrow(rows)), function(i) {
    row <- mcp_row_to_list(rows[i, , drop = FALSE])
    c(
      mcp_analysis_provenance("llm_generated_summary", "SysNDD LLM summary cache", "llm_cluster_summary_cache", "admin_llm_workflow"),
      list(
        summary_available = TRUE,
        cache_only = TRUE,
        cache_id = row$cache_id,
        cluster_type = row$cluster_type,
        cluster_number = row$cluster_number,
        cluster_hash = row$cluster_hash,
        model_name = row$model_name,
        prompt_version = row$prompt_version,
        validation_status = row$validation_status,
        created_at = row$created_at,
        validated_at = row$validated_at,
        tags = mcp_parse_json_field(row$tags, list()),
        summary = mcp_parse_json_field(row$summary_json, list())
      )
    )
  })
}

mcp_cache_key <- function(name, args) {
  paste(name, jsonlite::toJSON(args, auto_unbox = TRUE, null = "null"), sep = ":")
}

mcp_cached <- function(name, args, ttl, fn) {
  key <- mcp_cache_key(name, args)
  cached <- .mcp_cache[[key]]
  now <- as.numeric(Sys.time())
  if (!is.null(cached) && cached$expires_at > now) {
    return(cached$value)
  }

  value <- fn()
  if (!inherits(value, "mcp_tool_error")) {
    .mcp_cache[[key]] <- list(value = value, expires_at = now + ttl)
  }
  value
}

mcp_search_sysndd <- function(query, types = NULL, limit = 10L) {
  query <- mcp_validate_query(query)
  limit <- mcp_validate_limit(limit, default = 10L, max = 25L)
  if (is.null(types)) types <- MCP_ALLOWED_SEARCH_TYPES
  types <- unique(as.character(types))
  invisible(lapply(types, mcp_validate_enum, allowed = MCP_ALLOWED_SEARCH_TYPES, argument = "types"))

  mcp_cached("search_sysndd", list(query = query, types = types, limit = limit), MCP_CACHE_TTLS$search_sysndd, function() {
    rows_all <- mcp_repo_search(query, types, limit + 1L)
    total <- nrow(rows_all)
    rows <- rows_all[seq_len(min(total, limit)), , drop = FALSE]
    records <- lapply(mcp_rows_to_records(rows), function(item) {
      type <- item$type
      id <- item$id
      c(
        item[c("type", "id", "label", "description")],
        list(
          score = mcp_score_for_tier(item$match_tier %||% "contains"),
          rank_reason = item$match_tier %||% "contains",
          matched_field = switch(type,
            gene = "symbol_or_hgnc_id",
            entity = "entity_id_symbol_or_disease",
            disease = "disease_id_or_name",
            phenotype = "hpo_id_or_term",
            variant = "variation_id_or_name",
            "label_or_identifier"
          ),
          resource_uri = mcp_resource_uri(type, id),
          suggested_tools = switch(type,
            gene = list("get_gene_context", "list_gene_entities"),
            entity = list("get_entity_context"),
            disease = list("find_entities_by_disease"),
            phenotype = list("find_entities_by_phenotype"),
            variant = list("search_sysndd"),
            list("search_sysndd")
          )
        )
      )
    })
    list(
      schema_version = MCP_SCHEMA_VERSION,
      query = query,
      matches = records,
      meta = list(
        limit = limit,
        offset = 0L,
        returned = length(records),
        total = total,
        has_more = total > limit
      )
    )
  })
}

mcp_resolve_gene_one <- function(gene) {
  normalized <- mcp_normalize_gene_input(gene)
  rows <- mcp_repo_resolve_gene(normalized)
  if (nrow(rows) > 1L) {
    stop(mcp_error("ambiguous_query", "Gene input resolved to multiple records", list(choices = mcp_rows_to_records(rows))))
  }
  mcp_first_row(rows, "Gene not found")
}

mcp_get_gene_context <- function(gene,
                                 include_entities = TRUE,
                                 include_comparisons = FALSE,
                                 entity_limit = 10L,
                                 response_mode = "compact",
                                 synopsis_mode = NULL,
                                 expand = "none",
                                 include_publications = TRUE,
                                 include_phenotypes = TRUE,
                                 include_variants = TRUE,
                                 publication_limit = 10L,
                                 abstract_mode = NULL,
                                 dedupe_publications = TRUE) {
  entity_limit <- mcp_validate_limit(entity_limit, default = 10L, max = 25L, name = "entity_limit")
  response_mode <- mcp_validate_mode(response_mode, mcp_response_modes(), "response_mode", "compact")
  synopsis_mode <- mcp_validate_mode(synopsis_mode, c("none", "excerpt", "full"), "synopsis_mode", mcp_default_synopsis_mode(response_mode))
  expand <- mcp_validate_mode(expand, c("none", "entities"), "expand", "none")
  publication_limit <- mcp_validate_limit(publication_limit, default = 10L, max = 25L, name = "publication_limit")
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", mcp_default_abstract_mode(response_mode))
  mcp_cached("get_gene_context", list(
    gene = gene,
    include_entities = include_entities,
    include_comparisons = include_comparisons,
    entity_limit = entity_limit,
    response_mode = response_mode,
    synopsis_mode = synopsis_mode,
    expand = expand,
    include_publications = include_publications,
    include_phenotypes = include_phenotypes,
    include_variants = include_variants,
    publication_limit = publication_limit,
    abstract_mode = abstract_mode,
    dedupe_publications = dedupe_publications
  ), MCP_CACHE_TTLS$get_gene_context, function() {
    gene_row <- mcp_resolve_gene_one(gene)
    gene_obj <- mcp_row_to_list(gene_row)

    fetch_entities <- isTRUE(include_entities) || identical(expand, "entities")
    total_entities <- if (isTRUE(fetch_entities)) mcp_repo_count_gene_entities(gene_obj$hgnc_id) else NULL
    entity_fetch_limit <- if (identical(expand, "entities")) min(entity_limit, MCP_MAX_ENTITY_BATCH_IDS) else entity_limit
    entities <- if (isTRUE(fetch_entities)) {
      mcp_repo_get_gene_entities(gene_obj$hgnc_id, limit = entity_fetch_limit, offset = 0L)
    } else {
      tibble::tibble()
    }
    entity_records <- lapply(mcp_rows_to_records(entities), function(item) {
      synopsis <- if (identical(synopsis_mode, "none")) {
        NULL
      } else if (identical(synopsis_mode, "full")) {
        mcp_full_text(item$synopsis)
      } else {
        mcp_truncate_text(item$synopsis %||% "", 1500L)
      }
      item$synopsis <- NULL
      record <- c(item, list(resource_uri = mcp_resource_uri("entity", item$entity_id)))
      if (!is.null(synopsis)) {
        record$synopsis_excerpt <- synopsis$text
        record$synopsis_truncated <- synopsis$truncated
      }
      record
    })

    comparisons <- if (isTRUE(include_comparisons)) mcp_repo_get_gene_comparisons(gene_obj$hgnc_id, limit = 25L) else tibble::tibble()
    entity_has_more <- !is.null(total_entities) && length(entity_records) < total_entities
    entity_details <- NULL
    if (identical(expand, "entities")) {
      entity_ids <- vapply(entity_records, function(item) as.integer(item$entity_id %||% NA_integer_), integer(1))
      entity_ids <- entity_ids[!is.na(entity_ids)]
      entity_details <- if (length(entity_ids) > 0L) {
        mcp_drop_nested_schema_version(mcp_get_entities_context(
          entity_ids = entity_ids,
          include_publications = include_publications,
          include_phenotypes = include_phenotypes,
          include_variants = include_variants,
          publication_limit = publication_limit,
          response_mode = response_mode,
          abstract_mode = abstract_mode,
          synopsis_mode = synopsis_mode,
          dedupe_publications = dedupe_publications
        ))
      } else {
        list(
          schema_version = MCP_SCHEMA_VERSION,
          entities = list(),
          publications = list(),
          meta = list(requested = 0L, returned = 0L, errors = 0L, max_entity_ids = MCP_MAX_ENTITY_BATCH_IDS)
        )
      }
    }

    result <- list(
      schema_version = MCP_SCHEMA_VERSION,
      gene = gene_obj,
      entity_summary = list(
        entity_count = total_entities %||% length(entity_records),
        categories = unique(vapply(entity_records, function(x) x$category %||% "", character(1))),
        inheritance_modes = unique(vapply(entity_records, function(x) x$hpo_mode_of_inheritance_term_name %||% "", character(1))),
        disease_names = unique(vapply(entity_records, function(x) x$disease_ontology_name %||% "", character(1))),
        ndd_phenotype_flags = unique(vapply(entity_records, function(x) x$ndd_phenotype_word %||% "", character(1)))
      ),
      entities = if (isTRUE(include_entities) || identical(expand, "entities")) entity_records else list(),
      comparison_sources = mcp_rows_to_records(comparisons),
      resource_links = c(
        list(list(type = "gene", uri = mcp_resource_uri("gene", gene_obj$symbol))),
        lapply(entity_records, function(x) list(type = "entity", uri = x$resource_uri))
      ),
      suggested_followups = list("get_entities_context", "get_publications_context", "search_sysndd"),
      meta = list(
        response_mode = response_mode,
        synopsis_mode = synopsis_mode,
        abstract_mode = abstract_mode,
        expand = expand,
        entity_limit = entity_limit,
        entity_query_limit = entity_fetch_limit,
        entity_detail_limit = if (identical(expand, "entities")) MCP_MAX_ENTITY_BATCH_IDS else NULL,
        entity_detail_truncated_by_batch_cap = identical(expand, "entities") && entity_limit > MCP_MAX_ENTITY_BATCH_IDS,
        entity_offset = 0L,
        entity_returned = length(entity_records),
        entity_total = total_entities,
        entity_has_more = entity_has_more,
        next_entity_offset = if (isTRUE(entity_has_more)) length(entity_records) else NULL,
        include_comparisons = isTRUE(include_comparisons),
        comparison_sources_note = "Set include_comparisons=true for external panel/source rows; this is not a gene-vs-gene comparator."
      )
    )
    if (!is.null(entity_details)) result$entity_details <- entity_details
    result
  })
}

mcp_get_genes_context <- function(genes,
                                  include_entities = TRUE,
                                  include_comparisons = FALSE,
                                  entity_limit = NULL,
                                  response_mode = NULL,
                                  synopsis_mode = NULL,
                                  expand = NULL,
                                  include_publications = TRUE,
                                  include_phenotypes = TRUE,
                                  include_variants = TRUE,
                                  publication_limit = NULL,
                                  abstract_mode = NULL,
                                  dedupe_publications = TRUE) {
  if (is.null(genes)) {
    stop(mcp_error("invalid_input", "genes must contain at least one gene identifier",
      list(argument = "genes")
    ))
  }
  raw_genes <- as.character(unlist(genes, use.names = FALSE))
  raw_genes <- raw_genes[!is.na(raw_genes) & nzchar(trimws(raw_genes))]
  if (length(raw_genes) == 0L) {
    stop(mcp_error("invalid_input", "genes must contain at least one gene identifier",
      list(argument = "genes")
    ))
  }
  if (length(raw_genes) > MCP_MAX_GENE_BATCH) {
    stop(mcp_error(
      "invalid_input",
      sprintf("genes supports at most %d identifiers per call", MCP_MAX_GENE_BATCH),
      list(argument = "genes", max = MCP_MAX_GENE_BATCH)
    ))
  }

  results <- lapply(raw_genes, function(gene) {
    tryCatch(
      mcp_get_gene_context(
        gene = gene,
        include_entities = include_entities,
        include_comparisons = include_comparisons,
        entity_limit = entity_limit %||% 10L,
        response_mode = response_mode %||% "compact",
        synopsis_mode = synopsis_mode,
        expand = expand %||% "none",
        include_publications = include_publications,
        include_phenotypes = include_phenotypes,
        include_variants = include_variants,
        publication_limit = publication_limit %||% 10L,
        abstract_mode = abstract_mode,
        dedupe_publications = dedupe_publications
      ),
      mcp_tool_error = function(e) {
        list(requested_gene = gene, error = unclass(e)$error)
      }
    )
  })
  for (idx in seq_along(results)) {
    if (is.null(results[[idx]]$error)) {
      results[[idx]]$requested_gene <- raw_genes[[idx]]
    }
  }

  publications <- list()
  expanded <- identical(expand %||% "none", "entities")
  if (expanded && isTRUE(dedupe_publications)) {
    publication_map <- new.env(parent = emptyenv())
    publication_ids <- character()
    for (idx in seq_along(results)) {
      detail <- results[[idx]]$entity_details
      if (is.null(detail) || is.null(detail$publications)) next
      for (pub in detail$publications) {
        key <- pub$publication_id %||% ""
        if (nzchar(key) && is.null(publication_map[[key]])) {
          publication_map[[key]] <- pub
          publication_ids <- c(publication_ids, key)
        }
      }
    }
    publications <- lapply(publication_ids, function(key) publication_map[[key]])
  }

  returned <- sum(vapply(results, function(item) is.null(item$error), logical(1)))
  list(
    schema_version = MCP_SCHEMA_VERSION,
    genes = results,
    publications = publications,
    meta = list(
      requested = length(raw_genes),
      returned = returned,
      errors = length(raw_genes) - returned,
      max_genes = MCP_MAX_GENE_BATCH,
      expand = expand %||% "none",
      dedupe_publications = isTRUE(dedupe_publications),
      publication_shape = if (expanded && isTRUE(dedupe_publications)) {
        "top_level_deduplicated"
      } else {
        "nested_per_gene"
      },
      publication_count = length(publications)
    )
  )
}

mcp_get_entity_context <- function(entity_id,
                                   include_publications = TRUE,
                                   include_phenotypes = TRUE,
                                   include_variants = TRUE,
                                   publication_limit = 10L,
                                   response_mode = "standard",
                                   abstract_mode = NULL,
                                   synopsis_mode = NULL) {
  entity_id <- suppressWarnings(as.integer(entity_id))
  if (is.na(entity_id) || entity_id < 1L) stop(mcp_error("invalid_input", "entity_id must be a positive integer", list(argument = "entity_id")))
  publication_limit <- mcp_validate_limit(publication_limit, default = 10L, max = 25L, name = "publication_limit")
  response_mode <- mcp_validate_mode(response_mode, mcp_response_modes(), "response_mode", "compact")
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", mcp_default_abstract_mode(response_mode))
  synopsis_mode <- mcp_validate_mode(synopsis_mode, c("none", "excerpt", "full"), "synopsis_mode", mcp_default_synopsis_mode(response_mode))

  mcp_cached("get_entity_context", list(entity_id = entity_id, include_publications = include_publications, include_phenotypes = include_phenotypes, include_variants = include_variants, publication_limit = publication_limit, response_mode = response_mode, abstract_mode = abstract_mode, synopsis_mode = synopsis_mode), MCP_CACHE_TTLS$get_entity_context, function() {
    row <- mcp_first_row(mcp_repo_get_entity_context(entity_id), "Entity not found")
    entity <- mcp_row_to_list(row)
    synopsis_parts <- mcp_apply_synopsis_mode(entity, synopsis_mode, 2500L)
    entity <- synopsis_parts$entity
    review <- synopsis_parts$review

    pub_rows <- if (isTRUE(include_publications)) mcp_repo_get_entity_publications(entity_id, publication_limit + 1L) else tibble::tibble()
    publication_has_more <- isTRUE(include_publications) && nrow(pub_rows) > publication_limit
    pubs <- pub_rows[seq_len(min(nrow(pub_rows), publication_limit)), , drop = FALSE]
    pub_records <- lapply(mcp_rows_to_records(pubs), function(item) {
      mcp_publication_record(item, abstract_mode = abstract_mode, abstract_max_chars = 1000L)
    })
    phenotypes <- if (isTRUE(include_phenotypes)) mcp_compact_phenotypes(mcp_repo_get_entity_phenotypes(entity_id)) else list()
    variation_terms <- if (isTRUE(include_variants)) mcp_rows_to_records(mcp_repo_get_entity_variation(entity_id)) else list()

    list(
      schema_version = MCP_SCHEMA_VERSION,
      entity = entity,
      status = list(category = entity$category, category_id = entity$category_id),
      review = review,
      phenotypes = phenotypes,
      variation_terms = variation_terms,
      publications = pub_records,
      suggested_followups = list("get_publication_context", "search_sysndd"),
      meta = list(
        response_mode = response_mode,
        abstract_mode = abstract_mode,
        synopsis_mode = synopsis_mode,
        include_publications = isTRUE(include_publications),
        include_phenotypes = isTRUE(include_phenotypes),
        include_variants = isTRUE(include_variants),
        publication_limit = publication_limit,
        publication_returned = length(pub_records),
        publication_has_more = publication_has_more,
        phenotype_cap = MCP_ENTITY_PHENOTYPE_CAP,
        phenotype_returned = sum(vapply(phenotypes, length, integer(1))),
        phenotype_shape = "by_modifier_hpo_ids",
        phenotype_may_be_truncated = isTRUE(include_phenotypes) && sum(vapply(phenotypes, length, integer(1))) >= MCP_ENTITY_PHENOTYPE_CAP,
        variation_cap = MCP_ENTITY_VARIATION_CAP,
        variation_returned = length(variation_terms),
        variation_may_be_truncated = isTRUE(include_variants) && length(variation_terms) >= MCP_ENTITY_VARIATION_CAP
      )
    )
  })
}

mcp_get_entities_context <- function(entity_ids,
                                     include_publications = TRUE,
                                     include_phenotypes = TRUE,
                                     include_variants = TRUE,
                                     publication_limit = 10L,
                                     response_mode = "compact",
                                     abstract_mode = NULL,
                                     synopsis_mode = NULL,
                                     dedupe_publications = TRUE) {
  if (is.null(entity_ids)) {
    stop(mcp_error("invalid_input", "entity_ids must contain at least one entity ID", list(argument = "entity_ids")))
  }
  raw_ids <- unlist(entity_ids, use.names = FALSE)
  if (length(raw_ids) == 0L) {
    stop(mcp_error("invalid_input", "entity_ids must contain at least one entity ID", list(argument = "entity_ids")))
  }
  if (length(raw_ids) > MCP_MAX_ENTITY_BATCH_IDS) {
    stop(mcp_error("invalid_input", "entity_ids supports at most 20 IDs per call", list(argument = "entity_ids", max = MCP_MAX_ENTITY_BATCH_IDS)))
  }
  publication_limit <- mcp_validate_limit(publication_limit, default = 10L, max = 25L, name = "publication_limit")
  response_mode <- mcp_validate_mode(response_mode, mcp_response_modes(), "response_mode", "compact")
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", mcp_default_abstract_mode(response_mode))
  synopsis_mode <- mcp_validate_mode(synopsis_mode, c("none", "excerpt", "full"), "synopsis_mode", mcp_default_synopsis_mode(response_mode))

  entities <- lapply(raw_ids, function(raw_id) {
    entity_id <- suppressWarnings(as.integer(raw_id))
    if (is.na(entity_id) || entity_id < 1L) {
      err <- unclass(mcp_error("invalid_input", "entity_id must be a positive integer", list(argument = "entity_id")))$error
      return(list(entity_id = as.character(raw_id), error = err))
    }

    tryCatch(
      mcp_drop_nested_schema_version(mcp_get_entity_context(
        entity_id = entity_id,
        include_publications = include_publications,
        include_phenotypes = include_phenotypes,
        include_variants = include_variants,
        publication_limit = publication_limit,
        response_mode = response_mode,
        abstract_mode = abstract_mode,
        synopsis_mode = synopsis_mode
      )),
      mcp_tool_error = function(e) {
        list(entity_id = entity_id, error = unclass(e)$error)
      }
    )
  })

  publications <- list()
  if (isTRUE(dedupe_publications) && isTRUE(include_publications)) {
    publication_map <- new.env(parent = emptyenv())
    publication_ids <- character()
    deduped_entities <- vector("list", length(entities))
    for (idx in seq_along(entities)) {
      item <- entities[[idx]]
      if (!is.null(item$error) || is.null(item$publications)) {
        deduped_entities[[idx]] <- item
        next
      }
      refs <- vector("list", length(item$publications))
      for (pub_idx in seq_along(item$publications)) {
        pub <- item$publications[[pub_idx]]
        key <- pub$publication_id %||% ""
        if (nzchar(key) && is.null(publication_map[[key]])) {
          publication_map[[key]] <- pub
          publication_ids <- c(publication_ids, key)
        }
        refs[[pub_idx]] <- mcp_publication_ref(pub)
      }
      item$publication_refs <- refs
      item$publications <- NULL
      deduped_entities[[idx]] <- item
    }
    entities <- deduped_entities
    publications <- lapply(publication_ids, function(key) publication_map[[key]])
  }

  returned <- sum(vapply(entities, function(item) is.null(item$error), logical(1)))
  list(
    schema_version = MCP_SCHEMA_VERSION,
    entities = entities,
    publications = publications,
    meta = list(
      requested = length(raw_ids),
      returned = returned,
      errors = length(raw_ids) - returned,
      max_entity_ids = MCP_MAX_ENTITY_BATCH_IDS,
      response_mode = response_mode,
      abstract_mode = abstract_mode,
      synopsis_mode = synopsis_mode,
      include_publications = isTRUE(include_publications),
      include_phenotypes = isTRUE(include_phenotypes),
      include_variants = isTRUE(include_variants),
      publication_limit = publication_limit,
      phenotype_cap = MCP_ENTITY_PHENOTYPE_CAP,
      variation_cap = MCP_ENTITY_VARIATION_CAP,
      dedupe_publications = isTRUE(dedupe_publications),
      publication_shape = if (isTRUE(dedupe_publications) && isTRUE(include_publications)) "top_level_deduplicated" else "nested_per_entity",
      publication_count = length(publications)
    )
  )
}

mcp_list_gene_entities <- function(gene, category = NULL, ndd_phenotype = "any", limit = 25L, offset = 0L) {
  category <- mcp_validate_category(category)
  ndd_phenotype <- mcp_validate_enum(ndd_phenotype, c("yes", "no", "any"), "ndd_phenotype")
  limit <- mcp_validate_limit(limit, default = 25L, max = 50L)
  offset <- mcp_validate_offset(offset)
  gene_row <- mcp_resolve_gene_one(gene)
  gene_obj <- mcp_row_to_list(gene_row)
  rows <- mcp_repo_get_gene_entities(gene_obj$hgnc_id, category = category, ndd_phenotype = ndd_phenotype, limit = limit, offset = offset)
  total <- mcp_repo_count_gene_entities(gene_obj$hgnc_id, category = category, ndd_phenotype = ndd_phenotype)

  list(
    schema_version = MCP_SCHEMA_VERSION,
    gene = gene_obj,
    data = mcp_decorate_entity_records(rows),
    meta = list(total = total, limit = limit, offset = offset, has_more = offset + nrow(rows) < total)
  )
}

mcp_get_publication_context <- function(pmid, abstract_max_chars = 2000L, abstract_mode = "metadata") {
  publication_id <- mcp_normalize_pmid(pmid)
  abstract_max_chars <- mcp_validate_limit(abstract_max_chars, default = 2000L, max = 4000L, name = "abstract_max_chars")
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", "metadata")
  mcp_cached("get_publication_context", list(pmid = publication_id, abstract_max_chars = abstract_max_chars, abstract_mode = abstract_mode), MCP_CACHE_TTLS$get_publication_context, function() {
    rows <- mcp_repo_get_publication_context(publication_id)
    first <- mcp_first_row(rows, "Publication not found")
    pub <- mcp_row_to_list(first)
    date_quality <- mcp_publication_date_quality(
      pub$Publication_date, rows$curation_review_date, pub$publication_date_source
    )
    linked_cols <- intersect(
      c("entity_id", "symbol", "hgnc_id", "disease_ontology_name", "category", "curation_review_date"),
      names(rows)
    )
    linked <- rows[!is.na(rows$entity_id), linked_cols, drop = FALSE]
    linked_records <- lapply(mcp_rows_to_records(unique(linked)), function(item) {
      item$sysndd_curation_date <- item$curation_review_date
      item$curation_review_date <- NULL
      item
    })
    c(
      list(schema_version = MCP_SCHEMA_VERSION),
      mcp_publication_record(pub, abstract_mode = abstract_mode, abstract_max_chars = abstract_max_chars, include_keywords = TRUE, date_quality = date_quality),
      list(
        linked_entities = linked_records,
        date_notes = list(
          publication_date_sysndd_record = date_quality$note,
          sysndd_curation_date = "Primary approved SysNDD review date on linked entities."
        )
      )
    )
  })
}

mcp_get_publications_context <- function(pmids, abstract_max_chars = 2000L, abstract_mode = "metadata") {
  if (is.null(pmids)) {
    stop(mcp_error("invalid_input", "pmids must contain at least one PubMed identifier", list(argument = "pmids")))
  }
  pmids <- as.character(unlist(pmids, use.names = FALSE))
  pmids <- pmids[!is.na(pmids) & nzchar(trimws(pmids))]
  if (length(pmids) == 0L) {
    stop(mcp_error("invalid_input", "pmids must contain at least one PubMed identifier", list(argument = "pmids")))
  }
  if (length(pmids) > 20L) {
    stop(mcp_error("invalid_input", "pmids supports at most 20 identifiers per call", list(argument = "pmids", max = 20L)))
  }
  abstract_max_chars <- mcp_validate_limit(abstract_max_chars, default = 2000L, max = 4000L, name = "abstract_max_chars")
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", "metadata")

  publications <- lapply(pmids, function(pmid) {
    normalized <- tryCatch(mcp_normalize_pmid(pmid), mcp_tool_error = function(e) NA_character_)
    if (is.na(normalized)) {
      return(list(publication_id = as.character(pmid), error = unclass(mcp_error("invalid_input", "Invalid PMID"))$error))
    }

    tryCatch(
      mcp_get_publication_context(normalized, abstract_max_chars = abstract_max_chars, abstract_mode = abstract_mode),
      mcp_tool_error = function(e) {
        list(publication_id = normalized, error = unclass(e)$error)
      }
    )
  })

  returned <- sum(vapply(publications, function(item) is.null(item$error), logical(1)))
  list(
    schema_version = MCP_SCHEMA_VERSION,
    publications = publications,
    meta = list(
      requested = length(pmids),
      returned = returned,
      errors = length(pmids) - returned,
      max_pmids = 20L,
      abstract_max_chars = abstract_max_chars,
      abstract_mode = abstract_mode
    )
  )
}

mcp_find_entities_by_phenotype <- function(phenotype,
                                           modifier = "present",
                                           category = "Definitive",
                                           limit = 25L,
                                           offset = 0L) {
  phenotype <- mcp_validate_query(phenotype, min_chars = 2L, max_chars = 100L, argument = "phenotype")
  modifier <- mcp_validate_query(modifier, min_chars = 2L, max_chars = 30L, argument = "modifier")
  category <- mcp_validate_category(category)
  limit <- mcp_validate_limit(limit, default = 25L, max = 50L)
  offset <- mcp_validate_offset(offset)
  rows <- mcp_repo_find_entities_by_phenotype(phenotype, modifier, category, limit, offset)
  total <- mcp_repo_count_entities_by_phenotype(phenotype, modifier, category)
  list(
    schema_version = MCP_SCHEMA_VERSION,
    phenotype = phenotype,
    resolved_phenotypes = unique(mcp_rows_to_records(rows[c("phenotype_id", "HPO_term")])),
    entities = mcp_decorate_entity_records(rows),
    meta = list(limit = limit, offset = offset, returned = nrow(rows), total = total, has_more = offset + nrow(rows) < total)
  )
}

mcp_find_entities_by_disease <- function(disease, limit = 25L, offset = 0L) {
  disease <- mcp_validate_query(disease, min_chars = 2L, max_chars = 150L, argument = "disease")
  limit <- mcp_validate_limit(limit, default = 25L, max = 50L)
  offset <- mcp_validate_offset(offset)
  rows <- mcp_repo_find_entities_by_disease(disease, limit, offset)
  total <- mcp_repo_count_entities_by_disease(disease)
  list(
    schema_version = MCP_SCHEMA_VERSION,
    resolved_diseases = unique(mcp_rows_to_records(rows[c("disease_ontology_id_version", "disease_ontology_name")])),
    entities = mcp_decorate_entity_records(rows),
    meta = list(limit = limit, offset = offset, returned = nrow(rows), total = total, has_more = offset + nrow(rows) < total)
  )
}

mcp_get_sysndd_stats <- function() {
  mcp_cached("get_sysndd_stats", list(), MCP_CACHE_TTLS$get_sysndd_stats, function() {
    rows <- mcp_repo_get_stats()
    values <- stats::setNames(as.list(rows$value), rows$metric)
    list(schema_version = MCP_SCHEMA_VERSION, counts = values, generated_at = as.character(Sys.time()))
  })
}

mcp_get_sysndd_capabilities <- function() {
  list(
    schema_version = MCP_SCHEMA_VERSION,
    server = list(name = "SysNDD read-only MCP", schema_version = MCP_SCHEMA_VERSION),
    canonical_workflows = list(
      deferred_tool_hint = "If tools are deferred, load search_sysndd, get_gene_context, get_genes_context, get_entities_context, get_publications_context, and get_sysndd_capabilities before the first SysNDD call.",
      gene_summary = list("search_sysndd", "get_gene_context", "get_entities_context", "get_publications_context"),
      entity_detail = list("get_entity_context", "get_publications_context"),
      phenotype_discovery = list("find_entities_by_phenotype", "get_entities_context"),
      disease_discovery = list("find_entities_by_disease", "get_entities_context"),
      citation_pack = list("get_publications_context"),
      gene_comparison = list("get_genes_context")
    ),
    payload_modes = list(
      response_mode = mcp_response_modes(),
      abstract_mode = c("none", "metadata", "excerpt"),
      synopsis_mode = c("none", "excerpt", "full"),
      cheap_gene_example = list(gene = "PNKP", include_entities = TRUE, include_comparisons = FALSE, response_mode = "compact"),
      gene_expand_example = list(gene = "PNKP", expand = "entities", response_mode = "minimal", entity_limit = 10L),
      gene_expand_note = "expand=entities returns the gene plus entity detail in one call. Use response_mode=minimal for structure-first retrieval, then request abstract_mode=excerpt or synopsis_mode=full only when prose is needed.",
      metadata_mode_abstract_fields = list(includes = "abstract_available", omits = list("abstract_excerpt", "abstract_truncated")),
      publication_metadata_example = list(pmids = list("PMID:37130971"), abstract_mode = "metadata")
    ),
    payload_efficiency = list(
      minimal_mode = "response_mode=minimal drops default prose by setting synopsis_mode=none and abstract_mode=none unless explicitly overridden.",
      phenotype_shape = "Entity phenotypes are grouped as phenotypes.<modifier> = [HPO IDs] to avoid repeating entity_id and modifier on every row.",
      nested_schema_versions = "Batch and expanded payloads keep schema_version only at the outer envelope."
    ),
    mode_resolution = list(
      note = "response_mode derives conservative defaults for abstract_mode and synopsis_mode; an explicit abstract_mode or synopsis_mode argument always wins. The effective values are echoed back in each response's meta block.",
      minimal_defaults = list(abstract_mode = "none", synopsis_mode = "none"),
      compact_standard_defaults = list(abstract_mode = "metadata", synopsis_mode = "excerpt"),
      full_defaults = list(abstract_mode = "metadata", synopsis_mode = "excerpt")
    ),
    limits = list(
      search_sysndd = list(default_limit = 10L, max_limit = 25L),
      get_gene_context = list(default_entity_limit = 10L, max_entity_limit = 25L, max_entity_detail_expand_ids = MCP_MAX_ENTITY_BATCH_IDS),
      get_genes_context = list(max_genes = 10L, default_dedupe_publications = TRUE),
      list_gene_entities = list(default_limit = 25L, max_limit = 50L),
      get_entity_context = list(default_publication_limit = 10L, max_publication_limit = 25L),
      get_entities_context = list(max_entity_ids = 20L, default_dedupe_publications = TRUE),
      get_publications_context = list(max_pmids = 20L, max_abstract_chars = 4000L)
    ),
    performance = list(
      note = "cache_ttl_seconds is the in-process result cache window; cost_tier is a rough latency hint.",
      get_sysndd_stats = list(cache_ttl_seconds = 300L, cost_tier = "cheap"),
      search_sysndd = list(cache_ttl_seconds = 60L, cost_tier = "cheap"),
      get_gene_context = list(cache_ttl_seconds = 300L, cost_tier = "moderate"),
      get_entity_context = list(cache_ttl_seconds = 300L, cost_tier = "moderate"),
      get_publication_context = list(cache_ttl_seconds = 1800L, cost_tier = "moderate"),
      get_sysndd_capabilities = list(cache_ttl_seconds = 0L, cost_tier = "cheap")
    ),
    citation_contract = list(
      use_recommended_citation_verbatim = TRUE,
      date_fields = list("publication_date_sysndd_record", "sysndd_curation_date"),
      confidence_fields = list("publication_date_confidence"),
      confidence_values = c("pubmed_verified", "pubmed_partial", "unverified"),
      date_note = "publication_date_sysndd_record is the date stored in the SysNDD publication table. Trust it as a publication date only when publication_date_confidence is pubmed_verified or pubmed_partial; otherwise it may be an ingestion-date artifact and recommended_citation omits the year.",
      abstract_fields = list("abstract_available", "abstract_excerpt", "abstract_truncated"),
      abstract_mode_note = "metadata returns abstract_available only; excerpt returns abstract_excerpt and abstract_truncated when text is available."
    ),
    entity_categories = list(
      filter_values = MCP_ALLOWED_ENTITY_CATEGORIES,
      returned_values = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
      note = "category filters accept Definitive/Moderate/Limited/Refuted. Returned entity rows may also carry 'not applicable' for records outside the NDD curation scope; that value cannot be used as a filter."
    ),
    comparison_sources = list(
      availability = "Use get_gene_context(include_comparisons=true) for external panel/source rows.",
      note = "comparison_sources are source cross-references, not cross-gene biological comparisons."
    ),
    resources = list(
      static = c("sysndd://schema/overview", "sysndd://schema/tool-guide"),
      record_uris_are_stable_identifiers = TRUE,
      parameterized_resource_templates = FALSE,
      retrieval_path = "Use tools for record retrieval in v1."
    ),
    prompts = list(
      enabled_by_default = FALSE,
      enable_with = "MCP_ENABLE_PROMPTS=true",
      note = "MCP prompts are disabled by default because Claude and other agentic hosts do not invoke prompt templates during normal tool-calling flows; advertising unused prompts creates recurring client-quality warnings. Enable them only when a deployment intentionally wants user-invoked slash-command templates.",
      available_when_enabled = list(
        list(name = "sysndd_gene_evidence_summary",
             arguments = list(list(name = "gene", required = TRUE), list(name = "depth", required = FALSE))),
        list(name = "sysndd_entity_evidence_brief",
             arguments = list(list(name = "entity_id", required = TRUE), list(name = "depth", required = FALSE))),
        list(name = "sysndd_publication_citation_pack",
             arguments = list(list(name = "pmids", required = TRUE))),
        list(name = "sysndd_phenotype_entity_discovery",
             arguments = list(list(name = "phenotype", required = TRUE), list(name = "category", required = FALSE)))
      )
    ),
    error_codes = c("invalid_input", "not_found", "ambiguous_query", "temporarily_unavailable"),
    error_examples = list(
      invalid_input = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "invalid_input", message = "Unknown parameter 'symbol'. Expected: gene, include_entities, ...",
        argument = "symbol"
      )),
      not_found = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "not_found", message = "Gene not found"
      )),
      ambiguous_query = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "ambiguous_query", message = "Gene input resolved to multiple records",
        choices = list(
          list(symbol = "EXAMPLE1", hgnc_id = "HGNC:1"),
          list(symbol = "EXAMPLE2", hgnc_id = "HGNC:2")
        )
      )),
      temporarily_unavailable = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "temporarily_unavailable", message = "MCP tool failed"
      ))
    ),
    error_handling_note = "Recoverable errors arrive as a tool result with isError=true and an error.code; retry ambiguous_query by calling again with one of error.choices.",
    safety = list(
      scope = "Read-only approved public SysNDD evidence for research review; not clinical decision support.",
      exclusions = c("draft reviews", "admin/user/job/log data", "raw SQL", "raw R", "Gemini", "external provider calls", "database writes")
    )
  )
}
