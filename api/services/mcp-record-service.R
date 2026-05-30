# services/mcp-record-service.R
#
# MCP entity, publication, discovery, and stats services.

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
      c("entity_id", "symbol", "hgnc_id", "disease_ontology_name", "category", "publication_type", "curation_review_date"),
      names(rows)
    )
    linked <- rows[!is.na(rows$entity_id), linked_cols, drop = FALSE]
    linked_records <- lapply(mcp_rows_to_records(unique(linked)), function(item) {
      item$sysndd_curation_date <- item$curation_review_date
      item$curation_review_date <- NULL
      item
    })
    publication_type_values <- if ("publication_type" %in% names(rows)) rows$publication_type else character()
    c(
      list(schema_version = MCP_SCHEMA_VERSION),
      mcp_publication_record(pub, abstract_mode = abstract_mode, abstract_max_chars = abstract_max_chars, include_keywords = TRUE, date_quality = date_quality),
      list(
        linked_entities = linked_records,
        publication_types = unique(Filter(
          function(value) !is.null(value) && nzchar(as.character(value)),
          as.list(publication_type_values)
        )),
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
