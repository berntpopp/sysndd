# services/mcp-service.R
#
# Service-layer validation and shaping for the read-only SysNDD MCP sidecar.

MCP_SCHEMA_VERSION <- "1.0"
MCP_ALLOWED_SEARCH_TYPES <- c("gene", "entity", "disease", "phenotype", "variant")
MCP_ALLOWED_ENTITY_CATEGORIES <- c("Definitive", "Moderate", "Limited", "Refuted")
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
    return(list(kind = "hgnc_id", value = hgnc))
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

mcp_recommended_citation <- function(pub) {
  pieces <- c(
    pub$Lastname,
    pub$Title,
    pub$Journal,
    pub$Publication_date,
    pub$publication_id
  )
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  pieces <- as.character(pieces)
  pieces <- pieces[!is.na(pieces) & nzchar(trimws(pieces))]
  paste(pieces, collapse = ". ")
}

mcp_publication_date_quality <- function(publication_date, curation_dates = NULL) {
  pub_date <- if (is.null(publication_date) || length(publication_date) == 0L || is.na(publication_date[1])) {
    ""
  } else {
    as.character(publication_date[1])
  }
  curation <- as.character(curation_dates)
  curation <- curation[!is.na(curation) & nzchar(curation)]
  matches_curation <- nzchar(pub_date) && any(pub_date == curation)
  list(
    matches_curation_date = matches_curation,
    confidence = if (matches_curation) "low" else "publication_table",
    note = if (matches_curation) {
      "Publication date comes from the local publication table and matches a linked SysNDD curation date; treat it as low-confidence until independently confirmed."
    } else {
      "Publication date from the local PubMed-derived publication table."
    }
  )
}

mcp_publication_record <- function(pub,
                                   abstract_mode = "excerpt",
                                   abstract_max_chars = 1000L,
                                   include_keywords = FALSE,
                                   date_quality = NULL) {
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", "excerpt")
  date_quality <- date_quality %||% mcp_publication_date_quality(pub$Publication_date, pub$curation_review_date)
  record <- list(
    publication_id = pub$publication_id,
    title = pub$Title,
    journal = pub$Journal,
    pubmed_publication_date = pub$Publication_date,
    pubmed_publication_date_matches_curation_date = date_quality$matches_curation_date,
    pubmed_publication_date_confidence = date_quality$confidence,
    sysndd_curation_date = pub$curation_review_date,
    first_author = pub$Lastname,
    publication_type = pub$publication_type,
    recommended_citation = mcp_recommended_citation(pub),
    resource_uri = mcp_resource_uri("publication", pub$publication_id)
  )
  if (isTRUE(include_keywords)) record$keywords <- pub$Keywords

  if (!identical(abstract_mode, "none")) {
    record$abstract_available <- mcp_has_text(pub$Abstract)
    if (identical(abstract_mode, "excerpt")) {
      abstract <- mcp_truncate_text(pub$Abstract %||% "", abstract_max_chars)
      record$abstract_excerpt <- abstract$text
      record$abstract_truncated <- abstract$truncated
    } else {
      record$abstract_excerpt <- ""
      record$abstract_truncated <- FALSE
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
                                 synopsis_mode = NULL) {
  entity_limit <- mcp_validate_limit(entity_limit, default = 10L, max = 25L, name = "entity_limit")
  response_mode <- mcp_validate_mode(response_mode, c("compact", "standard", "full"), "response_mode", "compact")
  synopsis_mode <- mcp_validate_mode(synopsis_mode, c("none", "excerpt", "full"), "synopsis_mode", if (identical(response_mode, "compact")) "excerpt" else "full")
  mcp_cached("get_gene_context", list(gene = gene, include_entities = include_entities, include_comparisons = include_comparisons, entity_limit = entity_limit, response_mode = response_mode, synopsis_mode = synopsis_mode), MCP_CACHE_TTLS$get_gene_context, function() {
    gene_row <- mcp_resolve_gene_one(gene)
    gene_obj <- mcp_row_to_list(gene_row)

    entities <- if (isTRUE(include_entities)) mcp_repo_get_gene_entities(gene_obj$hgnc_id, limit = entity_limit, offset = 0L) else tibble::tibble()
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
    list(
      schema_version = MCP_SCHEMA_VERSION,
      gene = gene_obj,
      entity_summary = list(
        entity_count = length(entity_records),
        categories = unique(vapply(entity_records, function(x) x$category %||% "", character(1))),
        inheritance_modes = unique(vapply(entity_records, function(x) x$hpo_mode_of_inheritance_term_name %||% "", character(1))),
        disease_names = unique(vapply(entity_records, function(x) x$disease_ontology_name %||% "", character(1))),
        ndd_phenotype_flags = unique(vapply(entity_records, function(x) x$ndd_phenotype_word %||% "", character(1)))
      ),
      entities = entity_records,
      comparison_sources = mcp_rows_to_records(comparisons),
      resource_links = c(
        list(list(type = "gene", uri = mcp_resource_uri("gene", gene_obj$symbol))),
        lapply(entity_records, function(x) list(type = "entity", uri = x$resource_uri))
      )
    )
  })
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
  response_mode <- mcp_validate_mode(response_mode, c("compact", "standard", "full"), "response_mode", "standard")
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", if (identical(response_mode, "compact")) "metadata" else "excerpt")
  synopsis_mode <- mcp_validate_mode(synopsis_mode, c("none", "excerpt", "full"), "synopsis_mode", if (identical(response_mode, "compact")) "excerpt" else "full")

  mcp_cached("get_entity_context", list(entity_id = entity_id, include_publications = include_publications, include_phenotypes = include_phenotypes, include_variants = include_variants, publication_limit = publication_limit, response_mode = response_mode, abstract_mode = abstract_mode, synopsis_mode = synopsis_mode), MCP_CACHE_TTLS$get_entity_context, function() {
    row <- mcp_first_row(mcp_repo_get_entity_context(entity_id), "Entity not found")
    entity <- mcp_row_to_list(row)
    synopsis_parts <- mcp_apply_synopsis_mode(entity, synopsis_mode, 2500L)
    entity <- synopsis_parts$entity
    review <- synopsis_parts$review

    pubs <- if (isTRUE(include_publications)) mcp_repo_get_entity_publications(entity_id, publication_limit) else tibble::tibble()
    pub_records <- lapply(mcp_rows_to_records(pubs), function(item) {
      mcp_publication_record(item, abstract_mode = abstract_mode, abstract_max_chars = 1000L)
    })

    list(
      schema_version = MCP_SCHEMA_VERSION,
      entity = entity,
      status = list(category = entity$category, category_id = entity$category_id),
      review = review,
      phenotypes = if (isTRUE(include_phenotypes)) mcp_rows_to_records(mcp_repo_get_entity_phenotypes(entity_id)) else list(),
      variation_terms = if (isTRUE(include_variants)) mcp_rows_to_records(mcp_repo_get_entity_variation(entity_id)) else list(),
      publications = pub_records,
      suggested_followups = list("get_publication_context", "search_sysndd")
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
  if (length(raw_ids) > 20L) {
    stop(mcp_error("invalid_input", "entity_ids supports at most 20 IDs per call", list(argument = "entity_ids", max = 20L)))
  }
  publication_limit <- mcp_validate_limit(publication_limit, default = 10L, max = 25L, name = "publication_limit")
  response_mode <- mcp_validate_mode(response_mode, c("compact", "standard", "full"), "response_mode", "compact")
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", if (identical(response_mode, "compact")) "metadata" else "excerpt")
  synopsis_mode <- mcp_validate_mode(synopsis_mode, c("none", "excerpt", "full"), "synopsis_mode", if (identical(response_mode, "compact")) "excerpt" else "full")

  entities <- lapply(raw_ids, function(raw_id) {
    entity_id <- suppressWarnings(as.integer(raw_id))
    if (is.na(entity_id) || entity_id < 1L) {
      err <- unclass(mcp_error("invalid_input", "entity_id must be a positive integer", list(argument = "entity_id")))$error
      return(list(entity_id = as.character(raw_id), error = err))
    }

    tryCatch(
      mcp_get_entity_context(
        entity_id = entity_id,
        include_publications = include_publications,
        include_phenotypes = include_phenotypes,
        include_variants = include_variants,
        publication_limit = publication_limit,
        response_mode = response_mode,
        abstract_mode = abstract_mode,
        synopsis_mode = synopsis_mode
      ),
      mcp_tool_error = function(e) {
        list(entity_id = entity_id, error = unclass(e)$error)
      }
    )
  })

  publications <- list()
  if (isTRUE(dedupe_publications) && isTRUE(include_publications)) {
    seen <- new.env(parent = emptyenv())
    entities <- lapply(entities, function(item) {
      if (!is.null(item$error) || is.null(item$publications)) {
        return(item)
      }
      refs <- lapply(item$publications, function(pub) {
        key <- pub$publication_id %||% ""
        if (nzchar(key) && is.null(seen[[key]])) {
          seen[[key]] <- TRUE
          publications[[length(publications) + 1L]] <<- pub
        }
        mcp_publication_ref(pub)
      })
      item$publication_refs <- refs
      item$publications <- NULL
      item
    })
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
      max_entity_ids = 20L,
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

mcp_get_publication_context <- function(pmid, abstract_max_chars = 2000L, abstract_mode = "excerpt") {
  publication_id <- mcp_normalize_pmid(pmid)
  abstract_max_chars <- mcp_validate_limit(abstract_max_chars, default = 2000L, max = 4000L, name = "abstract_max_chars")
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", "excerpt")
  mcp_cached("get_publication_context", list(pmid = publication_id, abstract_max_chars = abstract_max_chars, abstract_mode = abstract_mode), MCP_CACHE_TTLS$get_publication_context, function() {
    rows <- mcp_repo_get_publication_context(publication_id)
    first <- mcp_first_row(rows, "Publication not found")
    pub <- mcp_row_to_list(first)
    date_quality <- mcp_publication_date_quality(pub$Publication_date, rows$curation_review_date)
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
          pubmed_publication_date = date_quality$note,
          sysndd_curation_date = "Primary approved SysNDD review date on linked entities."
        )
      )
    )
  })
}

mcp_get_publications_context <- function(pmids, abstract_max_chars = 2000L, abstract_mode = "excerpt") {
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
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"), "abstract_mode", "excerpt")

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
  list(schema_version = MCP_SCHEMA_VERSION, resolved_diseases = unique(mcp_rows_to_records(rows[c("disease_ontology_id_version", "disease_ontology_name")])), entities = mcp_decorate_entity_records(rows), meta = list(limit = limit, offset = offset, total = nrow(rows), has_more = nrow(rows) == limit))
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
      gene_summary = list("search_sysndd", "get_gene_context", "get_entities_context", "get_publications_context"),
      entity_detail = list("get_entity_context", "get_publications_context"),
      phenotype_discovery = list("find_entities_by_phenotype", "get_entities_context"),
      disease_discovery = list("find_entities_by_disease", "get_entities_context"),
      citation_pack = list("get_publications_context")
    ),
    payload_modes = list(
      response_mode = c("compact", "standard", "full"),
      abstract_mode = c("none", "metadata", "excerpt"),
      synopsis_mode = c("none", "excerpt", "full"),
      cheap_gene_example = list(gene = "PNKP", include_entities = TRUE, include_comparisons = FALSE, response_mode = "compact"),
      publication_metadata_example = list(pmids = list("PMID:37130971"), abstract_mode = "metadata")
    ),
    limits = list(
      search_sysndd = list(default_limit = 10L, max_limit = 25L),
      list_gene_entities = list(default_limit = 25L, max_limit = 50L),
      get_entity_context = list(default_publication_limit = 10L, max_publication_limit = 25L),
      get_entities_context = list(max_entity_ids = 20L, default_dedupe_publications = TRUE),
      get_publications_context = list(max_pmids = 20L, max_abstract_chars = 4000L)
    ),
    citation_contract = list(
      use_recommended_citation_verbatim = TRUE,
      date_fields = list("pubmed_publication_date", "sysndd_curation_date"),
      confidence_fields = list("pubmed_publication_date_confidence", "pubmed_publication_date_matches_curation_date"),
      abstract_fields = list("abstract_available", "abstract_excerpt", "abstract_truncated")
    ),
    resources = list(
      static = c("sysndd://schema/overview", "sysndd://schema/tool-guide"),
      record_uris_are_stable_identifiers = TRUE,
      parameterized_resource_templates = FALSE,
      retrieval_path = "Use tools for record retrieval in v1."
    ),
    prompts = c(
      "sysndd_gene_evidence_summary",
      "sysndd_entity_evidence_brief",
      "sysndd_publication_citation_pack",
      "sysndd_phenotype_entity_discovery"
    ),
    error_codes = c("invalid_input", "not_found", "ambiguous_query", "temporarily_unavailable"),
    safety = list(
      scope = "Read-only approved public SysNDD evidence for research review; not clinical decision support.",
      exclusions = c("draft reviews", "admin/user/job/log data", "raw SQL", "raw R", "Gemini", "external provider calls", "database writes")
    )
  )
}
