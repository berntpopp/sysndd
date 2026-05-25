# services/mcp-research-context-service.R
#
# Gene-level MCP research context aggregation over curated and analysis sections.

mcp_section_call <- function(name, fn) {
  tryCatch(
    list(status = "available", value = fn()),
    mcp_tool_error = function(e) {
      payload <- mcp_error_payload(e)
      status <- if (identical(payload$error$code, "temporarily_unavailable")) {
        "temporarily_unavailable"
      } else {
        "error"
      }
      list(status = status, value = payload)
    },
    error = function(e) {
      list(
        status = "temporarily_unavailable",
        value = mcp_error_payload(mcp_error("temporarily_unavailable", conditionMessage(e), list(section = name)))
      )
    }
  )
}

mcp_section_status <- function(call_result) {
  value_status <- call_result$value$section_status %||% NULL
  if (!is.null(value_status) && nzchar(as.character(value_status)[1])) {
    return(as.character(value_status)[1])
  }
  call_result$status
}

mcp_research_phenotype_status <- function(mode) {
  unavailable <- "temporarily_unavailable"
  available <- "available"
  tryCatch(
    switch(
      mode,
      correlations = if (isTRUE(mcp_analysis_repo_phenotype_correlations_cache_hit())) available else unavailable,
      clusters = if (isTRUE(mcp_analysis_repo_phenotype_cluster_cache_hit())) available else unavailable,
      phenotype_functional_correlations = {
        has_helper <- exists("generate_phenotype_functional_cluster_correlation", mode = "function")
        has_functional <- isTRUE(mcp_analysis_repo_functional_cluster_cache_hit(algorithm = "leiden"))
        has_phenotype <- isTRUE(mcp_analysis_repo_phenotype_cluster_cache_hit())
        if (has_helper && has_functional && has_phenotype) available else unavailable
      },
      unavailable
    ),
    error = function(e) unavailable
  )
}

mcp_gene_external_identifier_refs <- function(hgnc_id) {
  if (is.null(hgnc_id) || !nzchar(trimws(as.character(hgnc_id)[1]))) {
    return(list())
  }

  rows <- mcp_analysis_repo_get_gene_external_identifiers(hgnc_id)
  if (is.null(rows) || nrow(rows) == 0L) return(list())
  gene <- mcp_row_to_list(rows[1, , drop = FALSE])
  id_fields <- c(
    "omim_id",
    "ensembl_gene_id",
    "uniprot_ids",
    "STRING_id",
    "mgd_id",
    "rgd_id",
    "mane_select",
    "alphafold_id"
  )
  refs <- lapply(id_fields[id_fields %in% names(gene)], function(field) {
    value <- gene[[field]]
    if (is.null(value) || !nzchar(as.character(value))) return(NULL)
    c(
      mcp_analysis_provenance(
        "external_reference_identifier",
        "SysNDD gene metadata",
        "non_alt_loci_set",
        "sysndd_import_pipeline"
      ),
      list(field = field, value = value)
    )
  })
  Filter(Negate(is.null), refs)
}

mcp_get_gene_research_context <- function(gene,
                                          sections = NULL,
                                          response_mode = "compact",
                                          max_response_chars = "auto",
                                          budget_strategy = "section_fair",
                                          entity_limit = 10L,
                                          publication_limit = 5L,
                                          include_cached_llm_summaries = TRUE,
                                          include_diagnostics = FALSE,
                                          dry_run = FALSE) {
  gene <- mcp_validate_query(gene, min_chars = 2L, max_chars = 100L, argument = "gene")
  budget <- mcp_analysis_response_budget(response_mode, max_response_chars)
  budget_strategy <- mcp_validate_enum(budget_strategy, c("section_fair", "scarcity_first"), "budget_strategy")
  entity_limit <- mcp_validate_limit(entity_limit, default = 10L, max = 25L, name = "entity_limit")
  publication_limit <- mcp_validate_limit(publication_limit, default = 5L, max = 25L, name = "publication_limit")
  sections <- sections %||% c(
    "curated",
    "comparison",
    "nddscore",
    "phenotype_correlations",
    "gene_network",
    "external_identifiers"
  )
  sections <- unique(as.character(sections))
  invalid <- setdiff(sections, MCP_GENE_RESEARCH_SECTIONS)
  if (length(invalid) > 0L) {
    stop(mcp_error(
      "invalid_input",
      sprintf("Unsupported section: %s", invalid[[1]]),
      list(argument = "sections", allowed_values = as.list(MCP_GENE_RESEARCH_SECTIONS))
    ))
  }

  section_status <- stats::setNames(as.list(rep("not_requested", length(MCP_GENE_RESEARCH_SECTIONS))), MCP_GENE_RESEARCH_SECTIONS)
  output_sections <- list()
  curated_response_mode <- if (identical(response_mode, "diagnostics")) "minimal" else response_mode

  curated <- mcp_section_call("curated", function() {
    mcp_get_gene_context(
      gene,
      include_entities = !isTRUE(dry_run),
      include_comparisons = FALSE,
      entity_limit = if (isTRUE(dry_run)) 1L else entity_limit,
      response_mode = curated_response_mode,
      expand = "none",
      publication_limit = if (isTRUE(dry_run)) 1L else publication_limit
    )
  })
  resolved_gene <- curated$value$gene %||% list()
  if ("curated" %in% sections) {
    section_status$curated <- curated$status
    output_sections$curated <- curated$value
  }

  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
    for (section in sections) {
      probe <- switch(
        section,
        curated = curated,
        comparison = mcp_section_call("comparison", function() {
          mcp_get_curation_comparison_context(gene = gene, response_mode = response_mode, dry_run = TRUE)
        }),
        nddscore = mcp_section_call("nddscore", function() {
          mcp_get_nddscore_context(gene = gene, response_mode = response_mode, dry_run = TRUE)
        }),
        phenotype_correlations = list(status = mcp_research_phenotype_status("correlations"), value = list()),
        phenotype_clusters = list(status = mcp_research_phenotype_status("clusters"), value = list()),
        phenotype_functional_correlations = list(
          status = mcp_research_phenotype_status("phenotype_functional_correlations"),
          value = list()
        ),
        gene_network = mcp_section_call("gene_network", function() {
          mcp_get_gene_network_context(gene = gene, response_mode = response_mode, dry_run = TRUE)
        }),
        cached_llm_summaries = list(
          status = if (!isTRUE(include_cached_llm_summaries)) {
            "disabled_by_request"
          } else {
            mcp_research_phenotype_status("clusters")
          },
          value = list()
        ),
        external_identifiers = mcp_section_call("external_identifiers", function() {
          mcp_gene_external_identifier_refs(resolved_gene$hgnc_id)
        })
      )
      section_status[[section]] <- mcp_section_status(probe)
    }
    dry_payload <- list(
      gene = resolved_gene,
      requested_sections = as.list(sections),
      section_status = section_status
    )
    dry_response <- list(
      schema_version = MCP_SCHEMA_VERSION,
      gene = resolved_gene,
      sections = list(),
      section_status = section_status,
      budget = mcp_analysis_finalize_budget(dry_payload, budget),
      recovery = list(retry_with = list(response_mode = "compact", sections = as.list(sections))),
      meta = list(
        response_mode = response_mode,
        budget_strategy = budget_strategy,
        dry_run = TRUE,
        include_diagnostics = include_diagnostics,
        llm_generation = "never",
        cached_llm_summaries = if (isTRUE(include_cached_llm_summaries)) "validated cache only" else "not_requested",
        live_external_provider_calls = "never"
      )
    )
    return(mcp_analysis_finalize_response_budget(dry_response, dry_response$budget))
  }

  if ("comparison" %in% sections) {
    comparison <- mcp_section_call("comparison", function() {
      mcp_get_curation_comparison_context(gene = gene, page_size = 25L, response_mode = response_mode)
    })
    section_status$comparison <- comparison$status
    output_sections$comparison <- comparison$value
  }
  if ("nddscore" %in% sections) {
    nddscore <- mcp_section_call("nddscore", function() {
      mcp_get_nddscore_context(gene = gene, response_mode = response_mode)
    })
    section_status$nddscore <- nddscore$status
    output_sections$nddscore <- nddscore$value
  }
  if ("phenotype_correlations" %in% sections) {
    phenotype <- mcp_section_call("phenotype_correlations", function() {
      mcp_get_phenotype_analysis_context(mode = "correlations", gene = gene, limit = 25L, response_mode = response_mode)
    })
    section_status$phenotype_correlations <- phenotype$status
    output_sections$phenotype_correlations <- phenotype$value
  }
  if ("phenotype_clusters" %in% sections) {
    clusters <- mcp_section_call("phenotype_clusters", function() {
      mcp_get_phenotype_analysis_context(mode = "clusters", gene = gene, limit = 25L, response_mode = response_mode)
    })
    section_status$phenotype_clusters <- clusters$status
    output_sections$phenotype_clusters <- clusters$value
  }
  if ("phenotype_functional_correlations" %in% sections) {
    pfc <- mcp_section_call("phenotype_functional_correlations", function() {
      mcp_get_phenotype_analysis_context(mode = "phenotype_functional_correlations", gene = gene, limit = 25L, response_mode = response_mode)
    })
    section_status$phenotype_functional_correlations <- pfc$status
    output_sections$phenotype_functional_correlations <- pfc$value
  }
  if ("gene_network" %in% sections) {
    network <- mcp_section_call("gene_network", function() {
      mcp_get_gene_network_context(gene = gene, response_mode = response_mode)
    })
    section_status$gene_network <- mcp_section_status(network)
    output_sections$gene_network <- network$value
  }
  if ("cached_llm_summaries" %in% sections) {
    if (!isTRUE(include_cached_llm_summaries)) {
      section_status$cached_llm_summaries <- "disabled_by_request"
    } else {
    cluster_records <- output_sections$phenotype_clusters$records %||% list()
    if (length(cluster_records) == 0L) {
      cluster_lookup <- mcp_section_call("phenotype_clusters_for_cached_llm_summaries", function() {
        mcp_get_phenotype_analysis_context(
          mode = "clusters",
          gene = gene,
          limit = 25L,
          include_cached_llm_summaries = FALSE,
          response_mode = "minimal"
        )
      })
      if (!identical(mcp_section_status(cluster_lookup), "available")) {
        section_status$cached_llm_summaries <- mcp_section_status(cluster_lookup)
        output_sections$cached_llm_summaries <- cluster_lookup$value
        cluster_records <- NULL
      } else {
        cluster_records <- cluster_lookup$value$records %||% list()
      }
    }
    if (!is.null(cluster_records)) {
    cluster_numbers <- unique(vapply(cluster_records, function(x) {
      suppressWarnings(as.integer(x$cluster %||% NA_integer_))
    }, integer(1)))
    cluster_numbers <- cluster_numbers[!is.na(cluster_numbers)]
    summaries <- mcp_section_call("cached_llm_summaries", function() {
      if (length(cluster_numbers) == 0L) {
        list(mcp_llm_cache_miss("phenotype"))
      } else {
        mcp_get_cached_llm_summaries("phenotype", cluster_numbers = cluster_numbers, limit = 5L)
      }
    })
    section_status$cached_llm_summaries <- summaries$status
    output_sections$cached_llm_summaries <- summaries$value
    }
    }
  }
  if ("external_identifiers" %in% sections) {
    external_identifiers <- mcp_section_call("external_identifiers", function() {
      mcp_gene_external_identifier_refs(resolved_gene$hgnc_id)
    })
    section_status$external_identifiers <- external_identifiers$status
    output_sections$external_identifiers <- external_identifiers$value
  }

  section_priority <- c(
    "curated",
    "nddscore",
    "external_identifiers",
    "comparison",
    "phenotype_clusters",
    "phenotype_correlations",
    "phenotype_functional_correlations",
    "gene_network",
    "cached_llm_summaries"
  )
  if (identical(budget_strategy, "scarcity_first")) {
    section_priority <- unique(c(
      "cached_llm_summaries",
      "gene_network",
      "phenotype_functional_correlations",
      section_priority
    ))
  }
  section_trimmed <- mcp_analysis_trim_sections(output_sections, priority = section_priority, budget = budget)
  dropped_sections <- vapply(
    Filter(function(item) isTRUE(item$dropped_section), section_trimmed$budget$dropped_summary),
    function(item) as.character(item$section %||% ""),
    character(1)
  )
  dropped_sections <- dropped_sections[nzchar(dropped_sections)]
  for (section in intersect(dropped_sections, names(section_status))) {
    section_status[[section]] <- "dropped_by_budget"
  }

  response <- list(
    schema_version = MCP_SCHEMA_VERSION,
    gene = resolved_gene,
    sections = section_trimmed$sections,
    section_status = section_status,
    budget = section_trimmed$budget,
    recovery = list(
      retry_with = list(
        response_mode = if (identical(response_mode, "minimal")) "compact" else "minimal",
        max_response_chars = "auto",
        sections = as.list(sections)
      )
    ),
    meta = list(
      response_mode = response_mode,
      budget_strategy = budget_strategy,
      dry_run = FALSE,
      include_diagnostics = include_diagnostics,
      llm_generation = "never",
      cached_llm_summaries = if (isTRUE(include_cached_llm_summaries)) "validated cache only" else "not_requested",
      live_external_provider_calls = "never"
    )
  )
  mcp_analysis_finalize_response_budget(response, response$budget)
}
