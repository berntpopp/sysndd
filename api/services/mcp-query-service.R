# services/mcp-query-service.R
#
# MCP search and gene-level context services.

mcp_search_sysndd <- function(query, types = NULL, limit = 10L) {
  query <- mcp_validate_query(query)
  limit <- mcp_validate_limit(limit, default = 10L, max = 25L)
  if (is.null(types)) types <- MCP_ALLOWED_SEARCH_TYPES
  types <- unique(as.character(types))
  invisible(lapply(types, mcp_validate_enum, allowed = MCP_ALLOWED_SEARCH_TYPES, argument = "types"))
  query_tokens <- if (exists("mcp_search_tokens", mode = "function")) {
    mcp_search_tokens(query)
  } else {
    tokens <- unlist(strsplit(toupper(query), "[^A-Z0-9]+", perl = TRUE), use.names = FALSE)
    tokens <- tokens[!is.na(tokens) & nzchar(tokens)]
    unique(utils::head(tokens[nchar(tokens) > 1L | grepl("^[0-9]+$", tokens)], 6L))
  }

  rows_all <- mcp_repo_search(query, types, limit + 1L)
    total <- nrow(rows_all)
    rows <- rows_all[seq_len(min(total, limit)), , drop = FALSE]
    records <- lapply(mcp_rows_to_records(rows), function(item) {
      type <- item$type
      id <- item$id
      c(
        item[c("type", "id", "label", "description")],
        list(
          score = item$score %||% mcp_score_for_tier(item$match_tier %||% "contains"),
          rank_reason = item$match_tier %||% "contains",
          matched_field = item$matched_field %||% switch(type,
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
        has_more = total > limit,
        query_tokens = query_tokens,
        searched_types = types,
        zero_result_guidance = if (length(records) == 0L) {
          list(
            "Try an HGNC symbol or HGNC ID for genes.",
            "Try a MONDO/HPO identifier or fewer phrase terms.",
            "Broaden types or call get_sysndd_capabilities for discovery workflows."
          )
        } else {
          NULL
        }
      )
  )
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
  gene_row <- mcp_resolve_gene_one(gene)
    gene_obj <- mcp_row_to_list(gene_row)

    fetch_entities <- isTRUE(include_entities) || identical(expand, "entities")
    total_entities <- mcp_repo_count_gene_entities(gene_obj$hgnc_id)
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
    entity_has_more <- isTRUE(fetch_entities) && !is.null(total_entities) && length(entity_records) < total_entities
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
        entity_rows_included = isTRUE(fetch_entities),
        entity_has_more = entity_has_more,
        next_entity_offset = if (isTRUE(entity_has_more)) length(entity_records) else NULL,
        include_comparisons = isTRUE(include_comparisons),
        comparison_sources_note = "Set include_comparisons=true for external panel/source rows; this is not a gene-vs-gene comparator."
      )
    )
    if (!is.null(entity_details)) result$entity_details <- entity_details
  result
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
