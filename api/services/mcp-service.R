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
  if (is.null(category) || !nzchar(trimws(as.character(category)[1]))) return(NULL)
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
  if (grepl("^[0-9]+$", hgnc)) return(list(kind = "hgnc_id", value = hgnc))
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

mcp_first_row <- function(rows, not_found_message) {
  if (is.null(rows) || nrow(rows) == 0L) {
    stop(mcp_error("not_found", not_found_message))
  }
  rows[1, , drop = FALSE]
}

mcp_row_to_list <- function(row) {
  if (is.null(row) || nrow(row) == 0L) return(list())
  values <- as.list(row[1, , drop = TRUE])
  lapply(values, function(value) {
    if (inherits(value, "Date") || inherits(value, "POSIXt")) return(as.character(value))
    if (length(value) == 0L || is.na(value)) return(NULL)
    value
  })
}

mcp_rows_to_records <- function(rows) {
  if (is.null(rows) || nrow(rows) == 0L) return(list())
  unname(lapply(seq_len(nrow(rows)), function(i) mcp_row_to_list(rows[i, , drop = FALSE])))
}

mcp_score_for_tier <- function(tier) {
  switch(
    tier,
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

mcp_cache_key <- function(name, args) {
  paste(name, jsonlite::toJSON(args, auto_unbox = TRUE, null = "null"), sep = ":")
}

mcp_cached <- function(name, args, ttl, fn) {
  key <- mcp_cache_key(name, args)
  cached <- .mcp_cache[[key]]
  now <- as.numeric(Sys.time())
  if (!is.null(cached) && cached$expires_at > now) return(cached$value)

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
    rows <- mcp_repo_search(query, types, limit)
    rows <- rows[seq_len(min(nrow(rows), limit)), , drop = FALSE]
    records <- lapply(mcp_rows_to_records(rows), function(item) {
      type <- item$type
      id <- item$id
      c(
        item[c("type", "id", "label", "description")],
        list(
          score = mcp_score_for_tier(item$match_tier %||% "contains"),
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
    list(schema_version = MCP_SCHEMA_VERSION, query = query, matches = records, meta = list(limit = limit, total = length(records)))
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
                                 include_comparisons = TRUE,
                                 entity_limit = 10L) {
  entity_limit <- mcp_validate_limit(entity_limit, default = 10L, max = 25L, name = "entity_limit")
  mcp_cached("get_gene_context", list(gene = gene, include_entities = include_entities, include_comparisons = include_comparisons, entity_limit = entity_limit), MCP_CACHE_TTLS$get_gene_context, function() {
    gene_row <- mcp_resolve_gene_one(gene)
    gene_obj <- mcp_row_to_list(gene_row)

    entities <- if (isTRUE(include_entities)) mcp_repo_get_gene_entities(gene_obj$hgnc_id, limit = entity_limit, offset = 0L) else tibble::tibble()
    entity_records <- lapply(mcp_rows_to_records(entities), function(item) {
      synopsis <- mcp_truncate_text(item$synopsis %||% "", 1500L)
      item$synopsis <- NULL
      c(item, list(
        synopsis_excerpt = synopsis$text,
        synopsis_truncated = synopsis$truncated,
        resource_uri = mcp_resource_uri("entity", item$entity_id)
      ))
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
                                   publication_limit = 10L) {
  entity_id <- suppressWarnings(as.integer(entity_id))
  if (is.na(entity_id) || entity_id < 1L) stop(mcp_error("invalid_input", "entity_id must be a positive integer", list(argument = "entity_id")))
  publication_limit <- mcp_validate_limit(publication_limit, default = 10L, max = 25L, name = "publication_limit")

  mcp_cached("get_entity_context", list(entity_id = entity_id, include_publications = include_publications, include_phenotypes = include_phenotypes, include_variants = include_variants, publication_limit = publication_limit), MCP_CACHE_TTLS$get_entity_context, function() {
    row <- mcp_first_row(mcp_repo_get_entity_context(entity_id), "Entity not found")
    entity <- mcp_row_to_list(row)
    synopsis <- mcp_truncate_text(entity$synopsis %||% "", 2500L)
    review <- list(synopsis = synopsis$text, synopsis_truncated = synopsis$truncated, review_date = entity$review_date)
    entity$synopsis <- NULL
    entity$review_date <- NULL

    pubs <- if (isTRUE(include_publications)) mcp_repo_get_entity_publications(entity_id, publication_limit) else tibble::tibble()
    pub_records <- lapply(mcp_rows_to_records(pubs), function(item) {
      abstract <- mcp_truncate_text(item$Abstract %||% "", 1000L)
      list(
        publication_id = item$publication_id,
        title = item$Title,
        journal = item$Journal,
        pubmed_publication_date = item$Publication_date,
        sysndd_curation_date = item$curation_review_date,
        first_author = item$Lastname,
        publication_type = item$publication_type,
        recommended_citation = mcp_recommended_citation(item),
        abstract_available = mcp_has_text(item$Abstract),
        abstract_excerpt = abstract$text,
        abstract_truncated = abstract$truncated,
        resource_uri = mcp_resource_uri("publication", item$publication_id)
      )
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

mcp_get_publication_context <- function(pmid, abstract_max_chars = 2000L) {
  publication_id <- mcp_normalize_pmid(pmid)
  abstract_max_chars <- mcp_validate_limit(abstract_max_chars, default = 2000L, max = 4000L, name = "abstract_max_chars")
  mcp_cached("get_publication_context", list(pmid = publication_id, abstract_max_chars = abstract_max_chars), MCP_CACHE_TTLS$get_publication_context, function() {
    rows <- mcp_repo_get_publication_context(publication_id)
    first <- mcp_first_row(rows, "Publication not found")
    pub <- mcp_row_to_list(first)
    abstract_available <- mcp_has_text(pub$Abstract)
    abstract <- mcp_truncate_text(pub$Abstract %||% "", abstract_max_chars)
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
    list(
      schema_version = MCP_SCHEMA_VERSION,
      publication_id = pub$publication_id,
      title = pub$Title,
      journal = pub$Journal,
      pubmed_publication_date = pub$Publication_date,
      first_author = pub$Lastname,
      keywords = pub$Keywords,
      recommended_citation = mcp_recommended_citation(pub),
      abstract_available = abstract_available,
      abstract_excerpt = abstract$text,
      abstract_truncated = abstract$truncated,
      linked_entities = linked_records,
      date_notes = list(
        pubmed_publication_date = "Publication date from the local PubMed-derived publication table.",
        sysndd_curation_date = "Primary approved SysNDD review date on linked entities."
      )
    )
  })
}

mcp_get_publications_context <- function(pmids, abstract_max_chars = 2000L) {
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

  publications <- lapply(pmids, function(pmid) {
    normalized <- tryCatch(mcp_normalize_pmid(pmid), mcp_tool_error = function(e) NA_character_)
    if (is.na(normalized)) {
      return(list(publication_id = as.character(pmid), error = unclass(mcp_error("invalid_input", "Invalid PMID"))$error))
    }

    tryCatch(
      mcp_get_publication_context(normalized, abstract_max_chars = abstract_max_chars),
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
      abstract_max_chars = abstract_max_chars
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
  list(schema_version = MCP_SCHEMA_VERSION, phenotype = phenotype, resolved_phenotypes = unique(mcp_rows_to_records(rows[c("phenotype_id", "HPO_term")])), entities = mcp_decorate_entity_records(rows), meta = list(limit = limit, offset = offset, total = nrow(rows), has_more = nrow(rows) == limit))
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
