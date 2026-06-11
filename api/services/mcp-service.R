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

# Return the first non-NA, non-empty value from a column-like vector, or NULL.
# Used to promote per-link scalar attributes (e.g. publication_type) to a
# top-level field without being defeated by a NULL leading join row (issue #353).
mcp_first_nonempty_value <- function(values) {
  if (is.null(values) || length(values) == 0L) {
    return(NULL)
  }
  values <- values[!is.na(values)]
  values <- values[nzchar(trimws(as.character(values)))]
  if (length(values) == 0L) {
    return(NULL)
  }
  values[[1]]
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
    exact_identifier = 1000,
    exact_label = 950,
    prefix = 800,
    contains = 600,
    400
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
