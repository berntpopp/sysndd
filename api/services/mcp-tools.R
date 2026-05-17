# services/mcp-tools.R
#
# MCP tool and static resource registry for the read-only SysNDD sidecar.

library(ellmer)
library(jsonlite)

mcp_serialize_result <- function(value, output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  text <- jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", na = "null")
  structure(
    text,
    sysndd_mcp_payload = value,
    sysndd_mcp_output_mode = output_mode,
    class = c("sysndd_mcp_text_result", "character")
  )
}

mcp_tool_safe <- function(fn, output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  force(fn)
  force(output_mode)
  function(...) {
    tryCatch(
      mcp_serialize_result(fn(...), output_mode = output_mode),
      mcp_tool_error = function(e) {
        res <- mcp_serialize_result(unclass(e), output_mode = output_mode)
        attr(res, "sysndd_mcp_is_error") <- TRUE
        res
      },
      error = function(e) {
        res <- mcp_serialize_result(
          mcp_error("temporarily_unavailable", "MCP tool failed"),
          output_mode = output_mode
        )
        attr(res, "sysndd_mcp_is_error") <- TRUE
        res
      }
    )
  }
}

mcp_unknown_arg_error <- function(provided, expected) {
  unknown <- setdiff(provided[nzchar(provided)], expected)
  if (length(unknown) > 0L) {
    stop(mcp_error(
      "invalid_input",
      sprintf("Unknown parameter '%s'. Expected: %s", unknown[[1]], paste(expected, collapse = ", ")),
      list(argument = unknown[[1]], expected_arguments = expected)
    ))
  }
}

mcp_tool_args <- function(args, expected, required = character(), aliases = list()) {
  if (is.null(names(args))) names(args) <- rep("", length(args))
  for (alias in names(aliases)) {
    if (alias %in% names(args)) {
      canonical <- aliases[[alias]]
      if (!canonical %in% names(args)) args[[canonical]] <- args[[alias]]
      args[[alias]] <- NULL
    }
  }
  mcp_unknown_arg_error(names(args), expected)
  missing <- setdiff(required, names(args))
  if (length(missing) > 0L) {
    stop(mcp_error(
      "invalid_input",
      sprintf("Missing required parameter '%s'", missing[[1]]),
      list(argument = missing[[1]], expected_arguments = expected)
    ))
  }
  args
}

mcp_static_resources <- function() {
  resource_path <- "config/mcp/resources/sysndd-schema.md"
  text <- if (file.exists(resource_path)) {
    paste(readLines(resource_path, warn = FALSE), collapse = "\n")
  } else {
    paste(
      "# sysndd://schema/overview",
      "",
      "SysNDD represents approved public gene-disease-inheritance entities for neurodevelopmental disorder curation.",
      "",
      "# sysndd://schema/tool-guide",
      "",
      "Use search_sysndd, get_gene_context, get_entity_context, get_entities_context, get_publication_context, and get_publications_context for approved public evidence retrieval.",
      sep = "\n"
    )
  }
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

mcp_server_instructions <- function() {
  paste(
    "SysNDD MCP provides read-only access to approved public neurodevelopmental disorder gene-disease evidence.",
    "Canonical workflow: search_sysndd to resolve user text, get_gene_context for a gene overview, get_entity_context for one gene-disease-inheritance entity, then get_publication_context or get_publications_context for PMID evidence.",
    "Entity model: entities are gene-disease-inheritance curation records; one gene can have many entities with different diseases, inheritance modes, categories, and NDD phenotype flags.",
    "Use get_entities_context for 1-20 entity IDs when get_gene_context or a find tool returns multiple entities that need detail in one call.",
    "Use list_gene_entities when you need entity rows without full phenotype/publication expansion.",
    "Use find_entities_by_phenotype and find_entities_by_disease for constrained discovery from HPO or disease terms.",
    "Use get_publications_context for 2-20 PMIDs; it preserves request order and returns per-PMID errors rather than failing the whole batch.",
    "Publication dates are exposed as pubmed_publication_date; linked entity review dates are sysndd_curation_date.",
    "Publication outputs include recommended_citation, abstract_available, abstract_excerpt, and abstract_truncated for citation-safe summaries.",
    "Resource URIs such as sysndd://schema/overview and sysndd://schema/tool-guide are static documentation resources; payload sysndd://gene, entity, and publication URIs are stable identifiers, while tools are the model-facing retrieval path in v1.",
    "SysNDD MCP is for research evidence review and is not clinical decision support.",
    "Errors are JSON payloads with schema_version and error.code values such as invalid_input, not_found, ambiguous_query, and temporarily_unavailable.",
    "Limits are enforced by each tool. V1 is read-only and never exposes draft reviews, admin/user/job/log data, raw SQL, raw R execution, Gemini, or external provider calls.",
    sep = " "
  )
}

mcp_patch_mcptools_instructions <- function(instructions = mcp_server_instructions()) {
  if (!requireNamespace("mcptools", quietly = TRUE)) return(FALSE)
  ns <- asNamespace("mcptools")
  original <- getOption("sysndd.mcptools.capabilities_original")
  if (is.null(original)) {
    original <- base::get("capabilities", envir = ns)
    options(sysndd.mcptools.capabilities_original = list(original))
  } else {
    original <- original[[1]]
  }
  patched <- function(protocol_version = "2025-06-18") {
    res <- original(protocol_version = protocol_version)
    res$serverInfo$name <- "SysNDD read-only MCP"
    res$instructions <- instructions
    res
  }
  environment(patched) <- environment()
  assignInNamespace("capabilities", patched, ns = "mcptools")
  TRUE
}

mcp_tool_annotations <- function(title = NULL) {
  compact <- function(x) x[!vapply(x, is.null, logical(1))]
  compact(list(
    title = title,
    readOnlyHint = TRUE,
    destructiveHint = FALSE,
    idempotentHint = TRUE,
    openWorldHint = FALSE
  ))
}

mcp_output_schema <- function(name) {
  list(
    type = "object",
    properties = list(
      schema_version = list(type = "string", description = "SysNDD MCP payload schema version."),
      error = list(
        type = "object",
        description = "Present when the tool returns a recoverable application-level error.",
        properties = list(
          code = list(type = "string"),
          message = list(type = "string"),
          argument = list(type = "string")
        )
      )
    ),
    required = list("schema_version"),
    additionalProperties = TRUE,
    description = sprintf("Stable SysNDD MCP %s result envelope.", name)
  )
}

mcp_fill_array_descriptions <- function(input_schema) {
  props <- input_schema$properties
  if (is.null(props)) return(input_schema)
  for (name in names(props)) {
    prop <- props[[name]]
    if (identical(prop$type, "array") && !nzchar(prop$description %||% "")) {
      item_desc <- prop$items$description %||% ""
      prop$description <- if (nzchar(item_desc)) paste("Array of", item_desc) else sprintf("Array parameter '%s'.", name)
      props[[name]] <- prop
    }
  }
  input_schema$properties <- props
  input_schema
}

mcp_tool_metadata <- function(tools) {
  tool_as_json <- get("tool_as_json", envir = asNamespace("mcptools"))
  lapply(tools, function(tool) {
    item <- tool_as_json(tool)
    item$inputSchema <- mcp_fill_array_descriptions(item$inputSchema)
    item$annotations <- mcp_tool_annotations(title = item$name)
    item$outputSchema <- mcp_output_schema(item$name)
    item
  })
}

mcp_jsonrpc_response <- function(id, result = NULL, error = NULL) {
  if (!is.null(error)) return(list(jsonrpc = "2.0", id = id, error = error))
  list(jsonrpc = "2.0", id = id, result = result)
}

mcp_resource_metadata <- function(resource) {
  list(
    uri = resource$uri,
    name = resource$name,
    title = resource$name,
    description = if (identical(resource$uri, "sysndd://schema/tool-guide")) {
      "How to use SysNDD MCP tools, identifiers, resources, citations, and error envelopes."
    } else {
      "Overview of the approved public SysNDD MCP schema and entity model."
    },
    mimeType = resource$mime_type,
    annotations = list(audience = list("assistant"), priority = 0.8)
  )
}

mcp_handle_resources_list <- function(id) {
  resources <- lapply(mcp_static_resources(), mcp_resource_metadata)
  mcp_jsonrpc_response(id, result = list(resources = resources))
}

mcp_handle_resources_read <- function(id, uri) {
  resources <- mcp_static_resources()
  matches <- Filter(function(resource) identical(resource$uri, uri), resources)
  if (length(matches) == 0L) {
    return(mcp_jsonrpc_response(
      id,
      error = list(code = -32002L, message = "Resource not found", data = list(uri = uri))
    ))
  }
  resource <- matches[[1]]
  mcp_jsonrpc_response(
    id,
    result = list(contents = list(list(uri = resource$uri, mimeType = resource$mime_type, text = resource$text)))
  )
}

mcp_patch_mcptools_result_formatter <- function(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  if (!requireNamespace("mcptools", quietly = TRUE)) return(FALSE)
  ns <- asNamespace("mcptools")
  original <- getOption("sysndd.mcptools.as_tool_call_result_original")
  if (is.null(original)) {
    original <- base::get("as_tool_call_result", envir = ns)
    options(sysndd.mcptools.as_tool_call_result_original = list(original))
  } else {
    original <- original[[1]]
  }
  patched <- function(data, result) {
    if (inherits(result, "sysndd_mcp_text_result")) {
      payload <- attr(result, "sysndd_mcp_payload")
      body <- list(
        content = list(list(type = "text", text = as.character(result))),
        isError = isTRUE(attr(result, "sysndd_mcp_is_error"))
      )
      if (identical(attr(result, "sysndd_mcp_output_mode"), "structuredContent")) {
        body$structuredContent <- payload
      }
      return(mcp_jsonrpc_response(data$id, body))
    }
    original(data, result)
  }
  environment(patched) <- environment()
  assignInNamespace("as_tool_call_result", patched, ns = "mcptools")
  TRUE
}

mcp_patch_mcptools_protocol <- function(registry, instructions = mcp_server_instructions()) {
  if (!requireNamespace("mcptools", quietly = TRUE)) return(FALSE)
  ns <- asNamespace("mcptools")
  mcp_patch_mcptools_instructions(instructions)

  patched_tools <- function() mcp_tool_metadata(registry$tools)
  environment(patched_tools) <- environment()
  assignInNamespace("get_mcptools_tools_as_json", patched_tools, ns = "mcptools")

  original_handle <- getOption("sysndd.mcptools.handle_http_request_message_original")
  if (is.null(original_handle)) {
    original_handle <- base::get("handle_http_request_message", envir = ns)
    options(sysndd.mcptools.handle_http_request_message_original = list(original_handle))
  } else {
    original_handle <- original_handle[[1]]
  }
  patched_handle <- function(data) {
    if (identical(data$method, "resources/list")) {
      return(mcp_handle_resources_list(data$id))
    }
    if (identical(data$method, "resources/read")) {
      return(mcp_handle_resources_read(data$id, data$params$uri))
    }
    original_handle(data)
  }
  environment(patched_handle) <- environment()
  assignInNamespace("handle_http_request_message", patched_handle, ns = "mcptools")

  mcp_patch_mcptools_result_formatter(Sys.getenv("MCP_OUTPUT_MODE", "json_text"))
  TRUE
}

mcp_build_tool_registry <- function(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  search_sysndd_fun <- function(query, types = NULL, limit = NULL) {
    mcp_tool_safe(function() mcp_search_sysndd(query = query, types = types, limit = limit), output_mode)()
  }
  get_gene_context_fun <- function(gene = NULL, symbol = NULL, include_entities = TRUE, include_comparisons = TRUE, entity_limit = NULL) {
    if (is.null(gene) && !is.null(symbol)) gene <- symbol
    mcp_tool_safe(function() {
      if (is.null(gene)) {
        stop(mcp_error("invalid_input", "Missing required parameter 'gene'", list(argument = "gene", expected_arguments = c("gene", "symbol", "include_entities", "include_comparisons", "entity_limit"))))
      }
      mcp_get_gene_context(
        gene = gene,
        include_entities = include_entities,
        include_comparisons = include_comparisons,
        entity_limit = entity_limit
      )
    }, output_mode)()
  }
  get_entity_context_fun <- function(entity_id,
                                     include_publications = TRUE,
                                     include_phenotypes = TRUE,
                                     include_variants = TRUE,
                                     publication_limit = NULL) {
    mcp_tool_safe(function() {
      mcp_get_entity_context(
        entity_id = entity_id,
        include_publications = include_publications,
        include_phenotypes = include_phenotypes,
        include_variants = include_variants,
        publication_limit = publication_limit
      )
    }, output_mode)()
  }
  get_entities_context_fun <- function(entity_ids,
                                       include_publications = TRUE,
                                       include_phenotypes = TRUE,
                                       include_variants = TRUE,
                                       publication_limit = NULL) {
    mcp_tool_safe(function() {
      mcp_get_entities_context(
        entity_ids = entity_ids,
        include_publications = include_publications,
        include_phenotypes = include_phenotypes,
        include_variants = include_variants,
        publication_limit = publication_limit
      )
    }, output_mode)()
  }
  list_gene_entities_fun <- function(gene, category = NULL, ndd_phenotype = "any", limit = NULL, offset = NULL) {
    mcp_tool_safe(function() {
      mcp_list_gene_entities(
        gene = gene,
        category = category,
        ndd_phenotype = ndd_phenotype,
        limit = limit,
        offset = offset
      )
    }, output_mode)()
  }
  get_publication_context_fun <- function(pmid, abstract_max_chars = NULL) {
    mcp_tool_safe(function() mcp_get_publication_context(pmid = pmid, abstract_max_chars = abstract_max_chars), output_mode)()
  }
  get_publications_context_fun <- function(pmids, abstract_max_chars = NULL) {
    mcp_tool_safe(function() mcp_get_publications_context(pmids = pmids, abstract_max_chars = abstract_max_chars), output_mode)()
  }
  find_entities_by_phenotype_fun <- function(phenotype,
                                             modifier = "present",
                                             category = "Definitive",
                                             limit = NULL,
                                             offset = NULL) {
    mcp_tool_safe(function() {
      mcp_find_entities_by_phenotype(
        phenotype = phenotype,
        modifier = modifier,
        category = category,
        limit = limit,
        offset = offset
      )
    }, output_mode)()
  }
  find_entities_by_disease_fun <- function(disease, limit = NULL, offset = NULL) {
    mcp_tool_safe(function() mcp_find_entities_by_disease(disease = disease, limit = limit, offset = offset), output_mode)()
  }
  get_sysndd_stats_fun <- function() {
    mcp_tool_safe(function() mcp_get_sysndd_stats(), output_mode)()
  }
  get_gene_context_direct_fun <- function(...) {
    dots <- list(...)
    mcp_tool_safe(function() {
      args <- mcp_tool_args(
        dots,
        c("gene", "symbol", "include_entities", "include_comparisons", "entity_limit"),
        required = character(),
        aliases = list(symbol = "gene")
      )
      if (is.null(args$gene)) {
        stop(mcp_error("invalid_input", "Missing required parameter 'gene'", list(argument = "gene")))
      }
      mcp_get_gene_context(
        gene = args$gene,
        include_entities = args$include_entities %||% TRUE,
        include_comparisons = args$include_comparisons %||% TRUE,
        entity_limit = args$entity_limit
      )
    }, output_mode)()
  }

  tools <- list(
    ellmer::tool(
      search_sysndd_fun,
      "Search approved public SysNDD genes, entities, diseases, phenotypes, and variants.",
      arguments = list(
        query = ellmer::type_string("Search query, 2-100 characters."),
        types = ellmer::type_array(ellmer::type_string("Optional type: gene, entity, disease, phenotype, or variant."), description = "Optional array of result types to search.", required = FALSE),
        limit = ellmer::type_integer("Maximum matches, default 10, max 25.", required = FALSE)
      ),
      name = "search_sysndd"
    ),
    ellmer::tool(
      get_gene_context_fun,
      "Get compact approved public context for a SysNDD gene.",
      arguments = list(
        gene = ellmer::type_string("Gene symbol, HGNC:1234, or bare HGNC ID. The deprecated symbol alias is accepted."),
        include_entities = ellmer::type_boolean("Include compact entity rows.", required = FALSE),
        symbol = ellmer::type_string("Deprecated alias for gene.", required = FALSE),
        include_comparisons = ellmer::type_boolean("Include comparison-source rows.", required = FALSE),
        entity_limit = ellmer::type_integer("Entity cap, default 10, max 25.", required = FALSE)
      ),
      name = "get_gene_context"
    ),
    ellmer::tool(
      get_entity_context_fun,
      "Get compact approved public context for one SysNDD entity; use returned PMIDs with get_publication_context or get_publications_context.",
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
      get_entities_context_fun,
      "Batch get compact approved public context for 1-20 SysNDD entity IDs, preserving request order with per-ID errors.",
      arguments = list(
        entity_ids = ellmer::type_array(ellmer::type_integer("SysNDD entity ID."), description = "Array of 1-20 SysNDD entity IDs."),
        include_publications = ellmer::type_boolean("Include linked publications.", required = FALSE),
        include_phenotypes = ellmer::type_boolean("Include HPO phenotype terms.", required = FALSE),
        include_variants = ellmer::type_boolean("Include variation ontology terms.", required = FALSE),
        publication_limit = ellmer::type_integer("Publication cap per entity, default 10, max 25.", required = FALSE)
      ),
      name = "get_entities_context"
    ),
    ellmer::tool(
      list_gene_entities_fun,
      "List approved public SysNDD entities for one gene; pass returned entity_id values to get_entity_context or get_entities_context.",
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
      get_publications_context_fun,
      "Batch get publication metadata for 2-20 PMIDs, preserving request order with per-PMID errors.",
      arguments = list(
        pmids = ellmer::type_array(ellmer::type_string("PMID:123, 123, or a PubMed URL."), description = "Array of 2-20 PubMed identifiers."),
        abstract_max_chars = ellmer::type_integer("Abstract excerpt cap per publication, default 2000, max 4000.", required = FALSE)
      ),
      name = "get_publications_context"
    ),
    ellmer::tool(
      find_entities_by_phenotype_fun,
      "Find approved public entities by HPO ID or phenotype text; pass returned entity_id values to get_entity_context or get_entities_context.",
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
      "Find approved public entities by disease ontology identifier or name; pass returned entity_id values to get_entity_context or get_entities_context.",
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

  list(
    tools = tools,
    resources = mcp_static_resources(),
    tool_functions = list(
      search_sysndd = search_sysndd_fun,
      get_gene_context = get_gene_context_direct_fun,
      get_entity_context = get_entity_context_fun,
      get_entities_context = get_entities_context_fun,
      list_gene_entities = list_gene_entities_fun,
      get_publication_context = get_publication_context_fun,
      get_publications_context = get_publications_context_fun,
      find_entities_by_phenotype = find_entities_by_phenotype_fun,
      find_entities_by_disease = find_entities_by_disease_fun,
      get_sysndd_stats = get_sysndd_stats_fun
    )
  )
}
