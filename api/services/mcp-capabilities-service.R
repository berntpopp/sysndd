# services/mcp-capabilities-service.R
#
# MCP capability metadata service.

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
      gene_comparison = list("get_genes_context"),
      analysis_catalog = list("get_sysndd_analysis_catalog"),
      gene_research = list("get_sysndd_analysis_catalog", "get_gene_research_context", "get_nddscore_context", "get_curation_comparison_context"),
      low_token_analysis = list(
        "get_sysndd_analysis_catalog",
        "get_gene_research_context(dry_run=true, response_mode='compact')",
        "focused follow-up tools with max_response_chars='auto'"
      )
    ),
    payload_modes = list(
      response_mode = mcp_response_modes(),
      analysis_response_mode = MCP_ANALYSIS_RESPONSE_MODES,
      max_response_chars = "auto by default for analysis tools; accepts integer character budgets for tighter payloads.",
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
      analysis_controls = "Use dry_run=true and include_diagnostics=true to inspect public-ready snapshot availability before broad exploration. Analysis payloads echo budget metadata, and dropped_summary records sections or rows omitted by max_response_chars.",
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
      get_gene_research_context = list(default_entity_limit = 10L, default_publication_limit = 5L, max_response_chars = "auto"),
      get_nddscore_context = list(default_page_size = 25L, max_page_size = 50L, max_response_chars = "auto"),
      get_curation_comparison_context = list(default_page_size = 25L, max_page_size = 50L, max_response_chars = "auto"),
      get_phenotype_analysis_context = list(default_limit = 25L, max_limit = 50L, max_response_chars = "auto"),
      get_gene_network_context = list(default_max_edges = 100L, max_edges = 250L, stored_snapshot = list(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L), max_response_chars = "auto"),
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
      get_sysndd_analysis_catalog = list(cache_ttl_seconds = 0L, cost_tier = "cheap"),
      get_gene_research_context = list(cache_ttl_seconds = 0L, cost_tier = "moderate", cheap_path = "dry_run=true"),
      get_nddscore_context = list(cache_ttl_seconds = 0L, cost_tier = "cheap"),
      get_gene_network_context = list(cache_ttl_seconds = 0L, cost_tier = "snapshot_only"),
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
    analysis_data_classes = list(
      curated_sysndd_evidence = list(curation_effect = "curated_evidence", not_evidence_tier = FALSE),
      curated_derived_analysis = list(curation_effect = "none", not_evidence_tier = TRUE),
      ml_prediction = list(curation_effect = "none", not_evidence_tier = TRUE, note = "NDDScore ML prediction is separate from curated SysNDD evidence."),
      llm_generated_summary = list(curation_effect = "none", not_evidence_tier = TRUE, note = "Admin-generated validated cache only; MCP never generates summaries."),
      external_reference_identifier = list(curation_effect = "none", not_evidence_tier = TRUE, note = "Stored identifiers only; no live external provider calls.")
    ),
    analysis_tools = list(
      catalog = "get_sysndd_analysis_catalog documents available analysis sections, data classes, and limits.",
      gene_research = "get_gene_research_context aggregates curated, ML prediction, public-ready snapshot analysis, cache-only LLM summaries, and stored external identifiers with section_status labels.",
      snapshot_reads = "Derived analysis tools read public-ready snapshots only and never compute STRING, phenotype clustering, fCoSE layouts, or correlations on request.",
      network_snapshot = "get_gene_network_context supports only the stored clusters/min_confidence=400/max_edges=10000 snapshot key; max_edges is a response trim cap.",
      guardrails = "No Gemini, no prompt/query exposure, no live external providers, no writes, no raw SQL/R tools."
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
        list(
          name = "sysndd_gene_evidence_summary",
          arguments = list(list(name = "gene", required = TRUE), list(name = "depth", required = FALSE))
        ),
        list(
          name = "sysndd_entity_evidence_brief",
          arguments = list(list(name = "entity_id", required = TRUE), list(name = "depth", required = FALSE))
        ),
        list(
          name = "sysndd_publication_citation_pack",
          arguments = list(list(name = "pmids", required = TRUE))
        ),
        list(
          name = "sysndd_phenotype_entity_discovery",
          arguments = list(list(name = "phenotype", required = TRUE), list(name = "category", required = FALSE))
        )
      )
    ),
    error_codes = c(
      "invalid_input",
      "not_found",
      "ambiguous_query",
      "temporarily_unavailable",
      "unsupported_parameter",
      "snapshot_missing",
      "snapshot_stale",
      "source_version_mismatch"
    ),
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
      )),
      unsupported_parameter = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "unsupported_parameter", message = "Unsupported parameters for analysis snapshot type: gene_network_edges"
      )),
      snapshot_missing = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "snapshot_missing", message = "Supported public-ready analysis snapshot is not currently available."
      )),
      snapshot_stale = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "snapshot_stale", message = "The active public analysis snapshot is stale and should be refreshed."
      )),
      source_version_mismatch = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "source_version_mismatch",
        message = "The active public analysis snapshot was built from a different public source-data version."
      ))
    ),
    error_handling_note = "Recoverable errors arrive as a tool result with isError=true and an error.code; retry ambiguous_query by calling again with one of error.choices.",
    safety = list(
      scope = "Read-only approved public SysNDD evidence for research review; not clinical decision support.",
      live_external_calls_disabled = TRUE,
      llm_generation_disabled = TRUE,
      cached_llm_summaries = "Admin-generated validated cache only; never represented as curated SysNDD evidence.",
      exclusions = c("draft reviews", "admin/user/job/log data", "raw SQL", "raw R", "Gemini", "external provider calls", "database writes")
    )
  )
}
