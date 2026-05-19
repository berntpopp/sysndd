# services/mcp-tool-registry.R
#
# MCP tool registry for the read-only SysNDD sidecar.

mcp_build_tool_registry <- function(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  search_sysndd_fun <- function(query = NULL, types = NULL, limit = NULL) {
    mcp_tool_safe(function() {
      if (is.null(query)) stop(mcp_error("invalid_input", "Missing required parameter 'query'", list(argument = "query")))
      mcp_search_sysndd(query = query, types = types, limit = limit)
    }, output_mode)()
  }
  get_gene_context_fun <- function(gene = NULL,
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
    mcp_tool_safe(function() {
      if (is.null(gene)) {
        stop(mcp_error("invalid_input", "Missing required parameter 'gene'", list(argument = "gene", expected_arguments = c("gene", "include_entities", "include_comparisons", "entity_limit", "response_mode", "synopsis_mode", "expand", "include_publications", "include_phenotypes", "include_variants", "publication_limit", "abstract_mode", "dedupe_publications"))))
      }
      mcp_get_gene_context(
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
      )
    }, output_mode)()
  }
  get_genes_context_fun <- function(genes = NULL,
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
    mcp_tool_safe(function() {
      if (is.null(genes)) {
        stop(mcp_error("invalid_input", "Missing required parameter 'genes'",
          list(argument = "genes")
        ))
      }
      mcp_get_genes_context(
        genes = genes,
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
      )
    }, output_mode)()
  }
  get_entity_context_fun <- function(entity_id = NULL,
                                     include_publications = TRUE,
                                     include_phenotypes = TRUE,
                                     include_variants = TRUE,
                                     publication_limit = NULL,
                                     response_mode = NULL,
                                     abstract_mode = NULL,
                                     synopsis_mode = NULL) {
    mcp_tool_safe(function() {
      if (is.null(entity_id)) stop(mcp_error("invalid_input", "Missing required parameter 'entity_id'", list(argument = "entity_id")))
      mcp_get_entity_context(
        entity_id = entity_id,
        include_publications = include_publications,
        include_phenotypes = include_phenotypes,
        include_variants = include_variants,
        publication_limit = publication_limit,
        response_mode = response_mode,
        abstract_mode = abstract_mode,
        synopsis_mode = synopsis_mode
      )
    }, output_mode)()
  }
  get_entities_context_fun <- function(entity_ids = NULL,
                                       include_publications = TRUE,
                                       include_phenotypes = TRUE,
                                       include_variants = TRUE,
                                       publication_limit = NULL,
                                       response_mode = NULL,
                                       abstract_mode = NULL,
                                       synopsis_mode = NULL,
                                       dedupe_publications = TRUE) {
    mcp_tool_safe(function() {
      if (is.null(entity_ids)) stop(mcp_error("invalid_input", "Missing required parameter 'entity_ids'", list(argument = "entity_ids")))
      mcp_get_entities_context(
        entity_ids = entity_ids,
        include_publications = include_publications,
        include_phenotypes = include_phenotypes,
        include_variants = include_variants,
        publication_limit = publication_limit,
        response_mode = response_mode,
        abstract_mode = abstract_mode,
        synopsis_mode = synopsis_mode,
        dedupe_publications = dedupe_publications
      )
    }, output_mode)()
  }
  list_gene_entities_fun <- function(gene = NULL, category = NULL, ndd_phenotype = "any", limit = NULL, offset = NULL) {
    mcp_tool_safe(function() {
      if (is.null(gene)) stop(mcp_error("invalid_input", "Missing required parameter 'gene'", list(argument = "gene")))
      mcp_list_gene_entities(
        gene = gene,
        category = category,
        ndd_phenotype = ndd_phenotype,
        limit = limit,
        offset = offset
      )
    }, output_mode)()
  }
  get_publication_context_fun <- function(pmid = NULL, abstract_max_chars = NULL, abstract_mode = NULL) {
    mcp_tool_safe(function() {
      if (is.null(pmid)) stop(mcp_error("invalid_input", "Missing required parameter 'pmid'", list(argument = "pmid")))
      mcp_get_publication_context(pmid = pmid, abstract_max_chars = abstract_max_chars, abstract_mode = abstract_mode)
    }, output_mode)()
  }
  get_publications_context_fun <- function(pmids = NULL, abstract_max_chars = NULL, abstract_mode = NULL) {
    mcp_tool_safe(function() {
      if (is.null(pmids)) stop(mcp_error("invalid_input", "Missing required parameter 'pmids'", list(argument = "pmids")))
      mcp_get_publications_context(pmids = pmids, abstract_max_chars = abstract_max_chars, abstract_mode = abstract_mode)
    }, output_mode)()
  }
  find_entities_by_phenotype_fun <- function(phenotype = NULL,
                                             modifier = "present",
                                             category = "Definitive",
                                             limit = NULL,
                                             offset = NULL) {
    mcp_tool_safe(function() {
      if (is.null(phenotype)) stop(mcp_error("invalid_input", "Missing required parameter 'phenotype'", list(argument = "phenotype")))
      mcp_find_entities_by_phenotype(
        phenotype = phenotype,
        modifier = modifier,
        category = category,
        limit = limit,
        offset = offset
      )
    }, output_mode)()
  }
  find_entities_by_disease_fun <- function(disease = NULL, limit = NULL, offset = NULL) {
    mcp_tool_safe(function() {
      if (is.null(disease)) stop(mcp_error("invalid_input", "Missing required parameter 'disease'", list(argument = "disease")))
      mcp_find_entities_by_disease(disease = disease, limit = limit, offset = offset)
    }, output_mode)()
  }
  get_sysndd_stats_fun <- function() {
    mcp_tool_safe(function() mcp_get_sysndd_stats(), output_mode)()
  }
  get_sysndd_capabilities_fun <- function() {
    mcp_tool_safe(function() mcp_get_sysndd_capabilities(), output_mode)()
  }

  tools <- list(
    ellmer::tool(
      search_sysndd_fun,
      "Search approved public SysNDD genes, entities, diseases, phenotypes, and variants. Example: search_sysndd({\"query\":\"PNKP\",\"types\":[\"gene\"],\"limit\":5}).",
      arguments = list(
        query = ellmer::type_string("Search query, 2-100 characters."),
        types = ellmer::type_array(ellmer::type_string("Optional type: gene, entity, disease, phenotype, or variant."), description = "Optional array of result types to search; default all supported types.", required = FALSE),
        limit = ellmer::type_integer("Maximum matches, default 10, max 25.", required = FALSE)
      ),
      name = "search_sysndd"
    ),
    ellmer::tool(
      get_gene_context_fun,
      "Get compact approved public context for a SysNDD gene. Example: get_gene_context({\"gene\":\"PNKP\",\"include_entities\":true,\"include_comparisons\":false,\"response_mode\":\"compact\"}) for the cheap path, or add \"expand\":\"entities\" for one-call entity detail.",
      arguments = list(
        gene = ellmer::type_string("Gene identifier such as PNKP, HGNC:1234, or bare HGNC ID."),
        include_entities = ellmer::type_boolean("Include compact entity rows; default true.", required = FALSE),
        include_comparisons = ellmer::type_boolean("Include comparison-source rows; default false for the cheap path.", required = FALSE),
        entity_limit = ellmer::type_integer("Entity cap, default 10, max 25; expand=entities detail fetches at most 20 IDs per call.", required = FALSE),
        response_mode = ellmer::type_string("minimal, compact, standard, or full; default compact.", required = FALSE),
        synopsis_mode = ellmer::type_string("none, excerpt, or full; default follows response_mode.", required = FALSE),
        expand = ellmer::type_string("none or entities; default none. Use entities for one-call gene plus entity detail.", required = FALSE),
        include_publications = ellmer::type_boolean("When expand=entities, include linked publications; default true.", required = FALSE),
        include_phenotypes = ellmer::type_boolean("When expand=entities, include HPO phenotype terms; default true.", required = FALSE),
        include_variants = ellmer::type_boolean("When expand=entities, include variation ontology terms; default true.", required = FALSE),
        publication_limit = ellmer::type_integer("When expand=entities, publication cap per entity, default 10, max 25.", required = FALSE),
        abstract_mode = ellmer::type_string("When expand=entities, none, metadata, or excerpt; default follows response_mode; minimal defaults none, otherwise metadata.", required = FALSE),
        dedupe_publications = ellmer::type_boolean("When expand=entities, deduplicate shared publications into top-level publications; default true.", required = FALSE)
      ),
      name = "get_gene_context"
    ),
    ellmer::tool(
      get_genes_context_fun,
      "Batch get compact approved public context for 1-10 SysNDD genes, preserving order with per-gene errors. Use expand=entities for one-call multi-gene detail (token-heavy on large batches). Example: get_genes_context({\"genes\":[\"CTCF\",\"MECP2\",\"SCN2A\"],\"expand\":\"entities\",\"abstract_mode\":\"metadata\"}).",
      arguments = list(
        genes = ellmer::type_array(ellmer::type_string("Gene identifier such as PNKP, HGNC:1234, or bare HGNC ID."), description = "Array of 1-10 gene identifiers."),
        include_entities = ellmer::type_boolean("Include compact entity rows per gene; default true.", required = FALSE),
        include_comparisons = ellmer::type_boolean("Include comparison-source rows; default false.", required = FALSE),
        entity_limit = ellmer::type_integer("Entity cap per gene, default 10, max 25.", required = FALSE),
        response_mode = ellmer::type_string("minimal, compact, standard, or full; default compact.", required = FALSE),
        synopsis_mode = ellmer::type_string("none, excerpt, or full; default follows response_mode.", required = FALSE),
        expand = ellmer::type_string("none or entities; default none. Use entities for one-call gene plus entity detail.", required = FALSE),
        include_publications = ellmer::type_boolean("When expand=entities, include linked publications; default true.", required = FALSE),
        include_phenotypes = ellmer::type_boolean("When expand=entities, include HPO phenotype terms; default true.", required = FALSE),
        include_variants = ellmer::type_boolean("When expand=entities, include variation ontology terms; default true.", required = FALSE),
        publication_limit = ellmer::type_integer("When expand=entities, publication cap per entity, default 10, max 25.", required = FALSE),
        abstract_mode = ellmer::type_string("When expand=entities, none, metadata, or excerpt; default follows response_mode; minimal defaults none, otherwise metadata.", required = FALSE),
        dedupe_publications = ellmer::type_boolean("Deduplicate shared publications into top-level publications across genes; default true.", required = FALSE)
      ),
      name = "get_genes_context"
    ),
    ellmer::tool(
      get_entity_context_fun,
      "Get compact approved public context for one SysNDD entity; use abstract_mode/synopsis_mode to control token cost. Example: get_entity_context({\"entity_id\":451,\"publication_limit\":5,\"abstract_mode\":\"metadata\"}).",
      arguments = list(
        entity_id = ellmer::type_integer("SysNDD entity ID."),
        include_publications = ellmer::type_boolean("Include linked publications; default true.", required = FALSE),
        include_phenotypes = ellmer::type_boolean("Include HPO phenotype terms; default true.", required = FALSE),
        include_variants = ellmer::type_boolean("Include variation ontology terms; default true.", required = FALSE),
        publication_limit = ellmer::type_integer("Publication cap, default 10, max 25.", required = FALSE),
        response_mode = ellmer::type_string("minimal, compact, standard, or full; default compact.", required = FALSE),
        abstract_mode = ellmer::type_string("none, metadata, or excerpt; default follows response_mode; minimal defaults none, otherwise metadata.", required = FALSE),
        synopsis_mode = ellmer::type_string("none, excerpt, or full; default follows response_mode.", required = FALSE)
      ),
      name = "get_entity_context"
    ),
    ellmer::tool(
      get_entities_context_fun,
      "Batch get compact approved public context for 1-20 SysNDD entity IDs, preserving order with per-ID errors and deduped publications. Example: get_entities_context({\"entity_ids\":[451,1317,1755],\"publication_limit\":3,\"abstract_mode\":\"metadata\"}).",
      arguments = list(
        entity_ids = ellmer::type_array(ellmer::type_integer("SysNDD entity ID."), description = "Array of 1-20 SysNDD entity IDs."),
        include_publications = ellmer::type_boolean("Include linked publications; default true.", required = FALSE),
        include_phenotypes = ellmer::type_boolean("Include HPO phenotype terms; default true.", required = FALSE),
        include_variants = ellmer::type_boolean("Include variation ontology terms; default true.", required = FALSE),
        publication_limit = ellmer::type_integer("Publication cap per entity, default 10, max 25.", required = FALSE),
        response_mode = ellmer::type_string("minimal, compact, standard, or full; default compact.", required = FALSE),
        abstract_mode = ellmer::type_string("none, metadata, or excerpt; default follows response_mode; minimal defaults none, otherwise metadata.", required = FALSE),
        synopsis_mode = ellmer::type_string("none, excerpt, or full; default follows response_mode.", required = FALSE),
        dedupe_publications = ellmer::type_boolean("Deduplicate shared publications into top-level publications; default true.", required = FALSE)
      ),
      name = "get_entities_context"
    ),
    ellmer::tool(
      list_gene_entities_fun,
      "List approved public SysNDD entities for one gene; pass returned entity_id values to get_entity_context or get_entities_context. Example: list_gene_entities({\"gene\":\"PNKP\",\"limit\":10}).",
      arguments = list(
        gene = ellmer::type_string("Gene identifier such as PNKP, HGNC:1234, or bare HGNC ID."),
        category = ellmer::type_string("Optional approved category filter; no category filter by default.", required = FALSE),
        ndd_phenotype = ellmer::type_string("yes, no, or any; default any.", required = FALSE),
        limit = ellmer::type_integer("Row cap, default 25, max 50.", required = FALSE),
        offset = ellmer::type_integer("Zero-based offset; default 0.", required = FALSE)
      ),
      name = "list_gene_entities"
    ),
    ellmer::tool(
      get_publication_context_fun,
      "Get publication metadata linked to approved primary reviews. Example: get_publication_context({\"pmid\":\"PMID:37130971\",\"abstract_mode\":\"metadata\"}).",
      arguments = list(
        pmid = ellmer::type_string("PMID:123, 123, or a PubMed URL."),
        abstract_max_chars = ellmer::type_integer("Abstract excerpt cap, default 2000, max 4000.", required = FALSE),
        abstract_mode = ellmer::type_string("none, metadata, or excerpt; default metadata.", required = FALSE)
      ),
      name = "get_publication_context"
    ),
    ellmer::tool(
      get_publications_context_fun,
      "Batch get publication metadata for 1-20 PMIDs, preserving request order with per-PMID errors. Example: get_publications_context({\"pmids\":[\"PMID:37130971\",\"30842225\"],\"abstract_mode\":\"metadata\"}).",
      arguments = list(
        pmids = ellmer::type_array(ellmer::type_string("PMID:123, 123, or a PubMed URL."), description = "Array of 1-20 PubMed identifiers."),
        abstract_max_chars = ellmer::type_integer("Abstract excerpt cap per publication, default 2000, max 4000.", required = FALSE),
        abstract_mode = ellmer::type_string("none, metadata, or excerpt; default metadata.", required = FALSE)
      ),
      name = "get_publications_context"
    ),
    ellmer::tool(
      find_entities_by_phenotype_fun,
      "Find approved public entities by HPO ID or phenotype text; pass returned entity_id values to get_entity_context or get_entities_context. Example: find_entities_by_phenotype({\"phenotype\":\"HP:0000252\",\"limit\":10}).",
      arguments = list(
        phenotype = ellmer::type_string("HPO ID or phenotype text."),
        modifier = ellmer::type_string("Modifier text such as present or excluded; default present.", required = FALSE),
        category = ellmer::type_string("Approved category filter; default Definitive.", required = FALSE),
        limit = ellmer::type_integer("Row cap, default 25, max 50.", required = FALSE),
        offset = ellmer::type_integer("Zero-based offset; default 0.", required = FALSE)
      ),
      name = "find_entities_by_phenotype"
    ),
    ellmer::tool(
      find_entities_by_disease_fun,
      "Find approved public entities by disease ontology identifier or name; pass returned entity_id values to get_entity_context or get_entities_context. Example: find_entities_by_disease({\"disease\":\"Rett syndrome\",\"limit\":10}).",
      arguments = list(
        disease = ellmer::type_string("Disease ontology ID or disease name."),
        limit = ellmer::type_integer("Row cap, default 25, max 50.", required = FALSE),
        offset = ellmer::type_integer("Zero-based offset; default 0.", required = FALSE)
      ),
      name = "find_entities_by_disease"
    ),
    ellmer::tool(
      get_sysndd_stats_fun,
      "Get capped aggregate SysNDD public counts. Example: get_sysndd_stats({}).",
      name = "get_sysndd_stats"
    ),
    ellmer::tool(
      get_sysndd_capabilities_fun,
      "Get SysNDD MCP capabilities: workflows, deferred-tool guidance, payload modes, limits, citations, resources, errors, prompts, and safety scope. Example: get_sysndd_capabilities({}).",
      name = "get_sysndd_capabilities"
    )
  )
  analysis_entries <- mcp_build_analysis_tool_entries(output_mode = output_mode)
  tools <- c(tools, analysis_entries$tools)

  list(
    tools = tools,
    resources = mcp_static_resources(),
    tool_functions = c(list(
      search_sysndd = search_sysndd_fun,
      get_gene_context = get_gene_context_fun,
      get_genes_context = get_genes_context_fun,
      get_entity_context = get_entity_context_fun,
      get_entities_context = get_entities_context_fun,
      list_gene_entities = list_gene_entities_fun,
      get_publication_context = get_publication_context_fun,
      get_publications_context = get_publications_context_fun,
      find_entities_by_phenotype = find_entities_by_phenotype_fun,
      find_entities_by_disease = find_entities_by_disease_fun,
      get_sysndd_stats = get_sysndd_stats_fun,
      get_sysndd_capabilities = get_sysndd_capabilities_fun
    ), analysis_entries$tool_functions)
  )
}
