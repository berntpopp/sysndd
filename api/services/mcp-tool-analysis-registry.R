# services/mcp-tool-analysis-registry.R
#
# Analysis and research-context MCP tool registrations.

mcp_analysis_tool_description <- function(label, extra = NULL) {
  paste(
    "Read-only", label,
    "Default response_mode is compact; use dry_run or diagnostics before broad exploration.",
    "max_response_chars defaults to auto and payloads may return dropped_summary.",
    "Derived analysis reads use public-ready snapshots only; no LLM generation.",
    extra %||% "",
    sep = " "
  )
}

mcp_build_analysis_tool_entries <- function(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  get_sysndd_analysis_catalog_fun <- function(include_unavailable = FALSE,
                                              response_mode = "compact") {
    mcp_tool_safe(function() {
      mcp_get_sysndd_analysis_catalog(include_unavailable = include_unavailable, response_mode = response_mode)
    }, output_mode)()
  }
  get_gene_research_context_fun <- function(gene = NULL,
                                            sections = NULL,
                                            response_mode = "compact",
                                            max_response_chars = "auto",
                                            budget_strategy = "section_fair",
                                            entity_limit = 10L,
                                            publication_limit = 5L,
                                            include_cached_llm_summaries = TRUE,
                                            include_diagnostics = FALSE,
                                            dry_run = FALSE) {
    mcp_tool_safe(function() {
      if (is.null(gene)) stop(mcp_error("invalid_input", "Missing required parameter 'gene'", list(argument = "gene")))
      mcp_get_gene_research_context(
        gene = gene,
        sections = sections,
        response_mode = response_mode,
        max_response_chars = max_response_chars,
        budget_strategy = budget_strategy,
        entity_limit = entity_limit,
        publication_limit = publication_limit,
        include_cached_llm_summaries = include_cached_llm_summaries,
        include_diagnostics = include_diagnostics,
        dry_run = dry_run
      )
    }, output_mode)()
  }
  get_nddscore_context_fun <- function(gene = NULL,
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
    mcp_tool_safe(function() {
      mcp_get_nddscore_context(
        gene = gene,
        mode = mode,
        risk_tier = risk_tier,
        confidence_tier = confidence_tier,
        known_sysndd_gene = known_sysndd_gene,
        hpo_terms = hpo_terms,
        search = search,
        sort = sort,
        page = page,
        page_size = page_size,
        response_mode = response_mode,
        max_response_chars = max_response_chars,
        include_diagnostics = include_diagnostics,
        dry_run = dry_run
      )
    }, output_mode)()
  }
  get_curation_comparison_context_fun <- function(gene = NULL,
                                                  mode = NULL,
                                                  sources = NULL,
                                                  category = NULL,
                                                  page = 1L,
                                                  page_size = 25L,
                                                  response_mode = "compact",
                                                  max_response_chars = "auto",
                                                  include_diagnostics = FALSE,
                                                  dry_run = FALSE) {
    mcp_tool_safe(function() {
      mcp_get_curation_comparison_context(
        gene = gene,
        mode = mode,
        sources = sources,
        category = category,
        page = page,
        page_size = page_size,
        response_mode = response_mode,
        max_response_chars = max_response_chars,
        include_diagnostics = include_diagnostics,
        dry_run = dry_run
      )
    }, output_mode)()
  }
  get_phenotype_analysis_context_fun <- function(mode = NULL,
                                                 gene = NULL,
                                                 phenotype = NULL,
                                                 min_abs_correlation = 0.3,
                                                 drop_diagonal = TRUE,
                                                 triangle_only = FALSE,
                                                 cluster_id = NULL,
                                                 limit = 25L,
                                                 include_cached_llm_summaries = TRUE,
                                                 response_mode = "compact",
                                                 max_response_chars = "auto",
                                                 include_diagnostics = FALSE,
                                                 dry_run = FALSE) {
    mcp_tool_safe(function() {
      if (is.null(mode)) stop(mcp_error("invalid_input", "Missing required parameter 'mode'", list(argument = "mode")))
      mcp_get_phenotype_analysis_context(
        mode = mode,
        gene = gene,
        phenotype = phenotype,
        min_abs_correlation = min_abs_correlation,
        drop_diagonal = drop_diagonal,
        triangle_only = triangle_only,
        cluster_id = cluster_id,
        limit = limit,
        include_cached_llm_summaries = include_cached_llm_summaries,
        response_mode = response_mode,
        max_response_chars = max_response_chars,
        include_diagnostics = include_diagnostics,
        dry_run = dry_run
      )
    }, output_mode)()
  }
  get_gene_network_context_fun <- function(gene = NULL,
                                           cluster_type = "clusters",
                                           min_confidence = 400L,
                                           max_edges = 100L,
                                           include_cached_llm_summaries = TRUE,
                                           response_mode = "compact",
                                           max_response_chars = "auto",
                                           include_diagnostics = FALSE,
                                           dry_run = FALSE) {
    mcp_tool_safe(function() {
      mcp_get_gene_network_context(
        gene = gene,
        cluster_type = cluster_type,
        min_confidence = min_confidence,
        max_edges = max_edges,
        include_cached_llm_summaries = include_cached_llm_summaries,
        response_mode = response_mode,
        max_response_chars = max_response_chars,
        include_diagnostics = include_diagnostics,
        dry_run = dry_run
      )
    }, output_mode)()
  }

  tools <- list(
    ellmer::tool(
      get_sysndd_analysis_catalog_fun,
      mcp_analysis_tool_description("analysis catalog.", "Use this first to inspect workflows, data classes, limits, and unavailable snapshot-only sections."),
      arguments = list(
        include_unavailable = ellmer::type_boolean("Include unavailable analysis entries; default false.", required = FALSE),
        response_mode = ellmer::type_string("minimal or compact; default compact.", required = FALSE)
      ),
      name = "get_sysndd_analysis_catalog"
    ),
    ellmer::tool(
      get_gene_research_context_fun,
      mcp_analysis_tool_description("gene research context.", "Cached LLM summaries are admin-generated cache-only and clearly labeled."),
      arguments = list(
        gene = ellmer::type_string("Gene identifier such as PNKP, HGNC:1234, or bare HGNC ID."),
        sections = ellmer::type_array(ellmer::type_string("Section name."), description = "Optional sections: curated, comparison, nddscore, phenotype_clusters, phenotype_correlations, phenotype_functional_correlations, gene_network, cached_llm_summaries, external_identifiers.", required = FALSE),
        response_mode = ellmer::type_string("minimal, compact, standard, full, or diagnostics; default compact.", required = FALSE),
        max_response_chars = ellmer::type_string("auto or an integer character budget; default auto.", required = FALSE),
        budget_strategy = ellmer::type_string("section_fair or scarcity_first; default section_fair.", required = FALSE),
        entity_limit = ellmer::type_integer("Curated entity cap, default 10, max 25.", required = FALSE),
        publication_limit = ellmer::type_integer("Curated publication cap per entity, default 5, max 25.", required = FALSE),
        include_cached_llm_summaries = ellmer::type_boolean("Use admin-generated validated cache only; default true.", required = FALSE),
        include_diagnostics = ellmer::type_boolean("Include diagnostics and section availability metadata; default false.", required = FALSE),
        dry_run = ellmer::type_boolean("Preflight section status without heavy payloads; default false.", required = FALSE)
      ),
      name = "get_gene_research_context"
    ),
    ellmer::tool(
      get_nddscore_context_fun,
      mcp_analysis_tool_description("NDDScore context.", "NDDScore is ML prediction, not curated evidence and not an evidence tier."),
      arguments = list(
        gene = ellmer::type_string("Optional gene identifier for mode=gene.", required = FALSE),
        mode = ellmer::type_string("gene, ranked_genes, or release; default gene when gene is supplied, otherwise ranked_genes.", required = FALSE),
        risk_tier = ellmer::type_string("Optional ranked_genes filter.", required = FALSE),
        confidence_tier = ellmer::type_string("Optional ranked_genes filter.", required = FALSE),
        known_sysndd_gene = ellmer::type_boolean("Optional ranked_genes filter.", required = FALSE),
        hpo_terms = ellmer::type_array(ellmer::type_string("HPO ID."), description = "Optional HPO term filters for ranked_genes.", required = FALSE),
        search = ellmer::type_string("Optional ranked_genes symbol/name search.", required = FALSE),
        sort = ellmer::type_string("rank, gene_symbol, risk_tier, confidence_tier, or score; default rank.", required = FALSE),
        page = ellmer::type_integer("One-based page, default 1.", required = FALSE),
        page_size = ellmer::type_integer("Page size, default 25, max 50.", required = FALSE),
        response_mode = ellmer::type_string("minimal, compact, standard, full, or diagnostics; default compact.", required = FALSE),
        max_response_chars = ellmer::type_string("auto or an integer character budget; default auto.", required = FALSE),
        include_diagnostics = ellmer::type_boolean("Include diagnostics metadata; default false.", required = FALSE),
        dry_run = ellmer::type_boolean("Preflight release/filter state without rows; default false.", required = FALSE)
      ),
      name = "get_nddscore_context"
    ),
    ellmer::tool(
      get_curation_comparison_context_fun,
      mcp_analysis_tool_description("curation comparison context.", "Comparison sources are cross-references and do not alter curated SysNDD classifications."),
      arguments = list(
        gene = ellmer::type_string("Optional gene identifier.", required = FALSE),
        mode = ellmer::type_string("gene_sources or browse; plot/raw modes are not exposed.", required = FALSE),
        sources = ellmer::type_array(ellmer::type_string("Comparison source name."), description = "Optional source filters.", required = FALSE),
        category = ellmer::type_string("Optional SysNDD category filter.", required = FALSE),
        page = ellmer::type_integer("One-based page, default 1.", required = FALSE),
        page_size = ellmer::type_integer("Page size, default 25, max 50.", required = FALSE),
        response_mode = ellmer::type_string("minimal, compact, standard, full, or diagnostics; default compact.", required = FALSE),
        max_response_chars = ellmer::type_string("auto or an integer character budget; default auto.", required = FALSE),
        include_diagnostics = ellmer::type_boolean("Include comparison metadata; default false.", required = FALSE),
        dry_run = ellmer::type_boolean("Preflight counts and metadata without rows; default false.", required = FALSE)
      ),
      name = "get_curation_comparison_context"
    ),
    ellmer::tool(
      get_phenotype_analysis_context_fun,
      mcp_analysis_tool_description("phenotype analysis context.", "Correlation and cluster rows come from public-ready snapshots; cached LLM summaries are admin-generated cache-only when included."),
      arguments = list(
        mode = ellmer::type_string("correlations, clusters, or phenotype_functional_correlations."),
        gene = ellmer::type_string("Optional gene identifier.", required = FALSE),
        phenotype = ellmer::type_string("Optional HPO ID or phenotype search.", required = FALSE),
        min_abs_correlation = ellmer::type_number("Correlation threshold from 0 to 1; default 0.3.", required = FALSE),
        drop_diagonal = ellmer::type_boolean("For correlation mode, omit self-correlations; default true.", required = FALSE),
        triangle_only = ellmer::type_boolean("For correlation mode, return one matrix triangle only; default false.", required = FALSE),
        cluster_id = ellmer::type_integer("Optional cluster identifier.", required = FALSE),
        limit = ellmer::type_integer("Record cap, default 25, max 50.", required = FALSE),
        include_cached_llm_summaries = ellmer::type_boolean("Use admin-generated validated cache only; default true.", required = FALSE),
        response_mode = ellmer::type_string("minimal, compact, standard, full, or diagnostics; default compact.", required = FALSE),
        max_response_chars = ellmer::type_string("auto or an integer character budget; default auto.", required = FALSE),
        include_diagnostics = ellmer::type_boolean("Include diagnostics metadata; default false.", required = FALSE),
        dry_run = ellmer::type_boolean("Preflight mode/snapshot state without rows; default false.", required = FALSE)
      ),
      name = "get_phenotype_analysis_context"
    ),
    ellmer::tool(
      get_gene_network_context_fun,
      mcp_analysis_tool_description("gene network context.", "Network data is public-ready snapshot-only; missing snapshots return a recoverable tool error or dry-run status."),
      arguments = list(
        gene = ellmer::type_string("Optional gene identifier.", required = FALSE),
        cluster_type = ellmer::type_string("Fixed stored snapshot key: clusters. Omit unless confirming fixed-key compatibility.", required = FALSE),
        min_confidence = ellmer::type_integer("Fixed stored snapshot key: 400. Other values return unsupported_parameter.", required = FALSE),
        max_edges = ellmer::type_integer("Response edge trim cap, default 100, max 250.", required = FALSE),
        include_cached_llm_summaries = ellmer::type_boolean("Use admin-generated validated cache only; default true.", required = FALSE),
        response_mode = ellmer::type_string("minimal, compact, standard, full, or diagnostics; default compact.", required = FALSE),
        max_response_chars = ellmer::type_string("auto or an integer character budget; default auto.", required = FALSE),
        include_diagnostics = ellmer::type_boolean("Include diagnostics metadata; default false.", required = FALSE),
        dry_run = ellmer::type_boolean("Preflight network snapshot state without rows; default false.", required = FALSE)
      ),
      name = "get_gene_network_context"
    )
  )

  list(
    tools = tools,
    tool_functions = list(
      get_sysndd_analysis_catalog = get_sysndd_analysis_catalog_fun,
      get_gene_research_context = get_gene_research_context_fun,
      get_nddscore_context = get_nddscore_context_fun,
      get_curation_comparison_context = get_curation_comparison_context_fun,
      get_phenotype_analysis_context = get_phenotype_analysis_context_fun,
      get_gene_network_context = get_gene_network_context_fun
    )
  )
}
