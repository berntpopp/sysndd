# services/mcp-tools.R
#
# MCP tool and static resource registry for the read-only SysNDD sidecar.

library(ellmer)
library(jsonlite)

mcp_serialize_result <- function(value, output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  if (identical(output_mode, "structuredContent")) return(value)
  jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", na = "null")
}

mcp_tool_safe <- function(fn, output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  force(fn)
  force(output_mode)
  function(...) {
    tryCatch(
      mcp_serialize_result(fn(...), output_mode = output_mode),
      mcp_tool_error = function(e) mcp_serialize_result(unclass(e), output_mode = output_mode),
      error = function(e) {
        mcp_serialize_result(
          mcp_error("temporarily_unavailable", "MCP tool failed"),
          output_mode = output_mode
        )
      }
    )
  }
}

mcp_static_resources <- function() {
  resource_path <- "config/mcp/resources/sysndd-schema.md"
  text <- if (file.exists(resource_path)) paste(readLines(resource_path, warn = FALSE), collapse = "\n") else ""
  list(
    list(
      uri = "sysndd://schema/overview",
      name = "SysNDD schema overview",
      mime_type = "text/markdown",
      text = sub("# sysndd://schema/tool-guide[\\s\\S]*$", "", text)
    ),
    list(
      uri = "sysndd://schema/tool-guide",
      name = "SysNDD MCP tool guide",
      mime_type = "text/markdown",
      text = sub("^[\\s\\S]*# sysndd://schema/tool-guide", "# sysndd://schema/tool-guide", text)
    )
  )
}

mcp_build_tool_registry <- function(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  search_sysndd_fun <- function(query, types = NULL, limit = NULL) {
    mcp_tool_safe(mcp_search_sysndd, output_mode)(query = query, types = types, limit = limit)
  }
  get_gene_context_fun <- function(gene, include_entities = TRUE, include_comparisons = TRUE, entity_limit = NULL) {
    mcp_tool_safe(mcp_get_gene_context, output_mode)(
      gene = gene,
      include_entities = include_entities,
      include_comparisons = include_comparisons,
      entity_limit = entity_limit
    )
  }
  get_entity_context_fun <- function(entity_id,
                                     include_publications = TRUE,
                                     include_phenotypes = TRUE,
                                     include_variants = TRUE,
                                     publication_limit = NULL) {
    mcp_tool_safe(mcp_get_entity_context, output_mode)(
      entity_id = entity_id,
      include_publications = include_publications,
      include_phenotypes = include_phenotypes,
      include_variants = include_variants,
      publication_limit = publication_limit
    )
  }
  list_gene_entities_fun <- function(gene, category = NULL, ndd_phenotype = "any", limit = NULL, offset = NULL) {
    mcp_tool_safe(mcp_list_gene_entities, output_mode)(
      gene = gene,
      category = category,
      ndd_phenotype = ndd_phenotype,
      limit = limit,
      offset = offset
    )
  }
  get_publication_context_fun <- function(pmid, abstract_max_chars = NULL) {
    mcp_tool_safe(mcp_get_publication_context, output_mode)(pmid = pmid, abstract_max_chars = abstract_max_chars)
  }
  find_entities_by_phenotype_fun <- function(phenotype,
                                             modifier = "present",
                                             category = "Definitive",
                                             limit = NULL,
                                             offset = NULL) {
    mcp_tool_safe(mcp_find_entities_by_phenotype, output_mode)(
      phenotype = phenotype,
      modifier = modifier,
      category = category,
      limit = limit,
      offset = offset
    )
  }
  find_entities_by_disease_fun <- function(disease, limit = NULL, offset = NULL) {
    mcp_tool_safe(mcp_find_entities_by_disease, output_mode)(disease = disease, limit = limit, offset = offset)
  }
  get_sysndd_stats_fun <- function() {
    mcp_tool_safe(mcp_get_sysndd_stats, output_mode)()
  }

  tools <- list(
    ellmer::tool(
      search_sysndd_fun,
      "Search approved public SysNDD genes, entities, diseases, phenotypes, and variants.",
      arguments = list(
        query = ellmer::type_string("Search query, 2-100 characters."),
        types = ellmer::type_array(ellmer::type_string("Optional type: gene, entity, disease, phenotype, or variant."), required = FALSE),
        limit = ellmer::type_integer("Maximum matches, default 10, max 25.", required = FALSE)
      ),
      name = "search_sysndd"
    ),
    ellmer::tool(
      get_gene_context_fun,
      "Get compact approved public context for a SysNDD gene.",
      arguments = list(
        gene = ellmer::type_string("Gene symbol, HGNC:1234, or bare HGNC ID."),
        include_entities = ellmer::type_boolean("Include compact entity rows.", required = FALSE),
        include_comparisons = ellmer::type_boolean("Include comparison-source rows.", required = FALSE),
        entity_limit = ellmer::type_integer("Entity cap, default 10, max 25.", required = FALSE)
      ),
      name = "get_gene_context"
    ),
    ellmer::tool(
      get_entity_context_fun,
      "Get compact approved public context for a SysNDD entity.",
      arguments = list(
        entity_id = ellmer::type_integer("SysNDD entity ID."),
        include_publications = ellmer::type_boolean("Include linked publications.", required = FALSE),
        include_phenotypes = ellmer::type_boolean("Include HPO phenotype terms.", required = FALSE),
        include_variants = ellmer::type_boolean("Include variation ontology terms.", required = FALSE),
        publication_limit = ellmer::type_integer("Publication cap, default 10, max 25.", required = FALSE)
      ),
      name = "get_entity_context"
    ),
    ellmer::tool(
      list_gene_entities_fun,
      "List approved public SysNDD entities for one gene.",
      arguments = list(
        gene = ellmer::type_string("Gene symbol, HGNC:1234, or bare HGNC ID."),
        category = ellmer::type_string("Optional approved category filter.", required = FALSE),
        ndd_phenotype = ellmer::type_string("yes, no, or any.", required = FALSE),
        limit = ellmer::type_integer("Row cap, default 25, max 50.", required = FALSE),
        offset = ellmer::type_integer("Zero-based offset.", required = FALSE)
      ),
      name = "list_gene_entities"
    ),
    ellmer::tool(
      get_publication_context_fun,
      "Get publication metadata linked to approved primary reviews.",
      arguments = list(
        pmid = ellmer::type_string("PMID:123, 123, or a PubMed URL."),
        abstract_max_chars = ellmer::type_integer("Abstract excerpt cap, default 2000, max 4000.", required = FALSE)
      ),
      name = "get_publication_context"
    ),
    ellmer::tool(
      find_entities_by_phenotype_fun,
      "Find approved public entities associated with HPO phenotype terms.",
      arguments = list(
        phenotype = ellmer::type_string("HPO ID or phenotype text."),
        modifier = ellmer::type_string("Modifier text such as present or excluded.", required = FALSE),
        category = ellmer::type_string("Approved category filter.", required = FALSE),
        limit = ellmer::type_integer("Row cap, default 25, max 50.", required = FALSE),
        offset = ellmer::type_integer("Zero-based offset.", required = FALSE)
      ),
      name = "find_entities_by_phenotype"
    ),
    ellmer::tool(
      find_entities_by_disease_fun,
      "Find approved public entities by disease ontology identifier or name.",
      arguments = list(
        disease = ellmer::type_string("Disease ontology ID or disease name."),
        limit = ellmer::type_integer("Row cap, default 25, max 50.", required = FALSE),
        offset = ellmer::type_integer("Zero-based offset.", required = FALSE)
      ),
      name = "find_entities_by_disease"
    ),
    ellmer::tool(
      get_sysndd_stats_fun,
      "Get capped aggregate SysNDD public counts.",
      name = "get_sysndd_stats"
    )
  )

  list(tools = tools, resources = mcp_static_resources())
}
