#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

required <- c("httr2", "jsonlite")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Missing required packages for MCP smoke: ", paste(missing, collapse = ", "))
}

endpoint <- Sys.getenv("MCP_URL", "http://127.0.0.1:8787")
token <- Sys.getenv("MCP_BEARER_TOKEN", "")

rpc <- function(method, params = NULL, id = 1L) {
  body <- list(jsonrpc = "2.0", id = id, method = method)
  if (!is.null(params)) body$params <- params

  req <- httr2::request(endpoint) |>
    httr2::req_headers(
      `Content-Type` = "application/json",
      `MCP-Protocol-Version` = "2025-11-25"
    ) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_timeout(5)

  if (nzchar(token)) {
    req <- httr2::req_headers(req, Authorization = paste("Bearer", token))
  }

  resp <- httr2::req_perform(req)
  jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)
}

init <- rpc("initialize", list(
  protocolVersion = "2025-11-25",
  capabilities = list(),
  clientInfo = list(name = "sysndd-mcp-smoke", version = "0.1.0")
), 1L)
if (is.null(init$result)) stop("MCP initialize failed")
if (!grepl("SysNDD", init$result$instructions %||% "", fixed = TRUE)) {
  stop("MCP initialize did not return SysNDD-specific instructions")
}
if (!grepl("research", init$result$instructions %||% "", ignore.case = TRUE)) {
  stop("MCP initialize did not return research-use guidance")
}
if (is.null(init$result$capabilities$resources)) {
  stop("MCP initialize did not advertise resources capability")
}

listed <- rpc("tools/list", id = 2L)
tools <- listed$result$tools %||% list()
tool_names <- vapply(tools, function(x) x$name %||% "", character(1))
required_tools <- c("search_sysndd", "get_gene_context", "get_entity_context", "get_entities_context", "get_publication_context", "get_publications_context", "get_sysndd_capabilities")
missing_tools <- setdiff(required_tools, tool_names)
if (length(missing_tools) > 0L) {
  stop("MCP tools/list missing required tools: ", paste(missing_tools, collapse = ", "))
}

for (tool in tools) {
  if (!isTRUE(tool$annotations$readOnlyHint)) {
    stop("MCP tool missing readOnlyHint annotation: ", tool$name %||% "<unknown>")
  }
  if (is.null(tool$outputSchema)) {
    stop("MCP tool missing outputSchema: ", tool$name %||% "<unknown>")
  }
}

tool_by_name <- function(name) {
  matches <- tools[vapply(tools, function(tool) identical(tool$name, name), logical(1))]
  if (length(matches) != 1L) stop("Could not find tool metadata for ", name)
  matches[[1]]
}

search_schema <- tool_by_name("search_sysndd")$inputSchema
if (!nzchar(search_schema$properties$types$description %||% "")) {
  stop("search_sysndd types array description is blank")
}
pub_batch_schema <- tool_by_name("get_publications_context")$inputSchema
if (!nzchar(pub_batch_schema$properties$pmids$description %||% "")) {
  stop("get_publications_context pmids array description is blank")
}
entity_batch_schema <- tool_by_name("get_entities_context")$inputSchema
if (!nzchar(entity_batch_schema$properties$entity_ids$description %||% "")) {
  stop("get_entities_context entity_ids array description is blank")
}
gene_tool <- tool_by_name("get_gene_context")
if (!grepl("Example:", gene_tool$description %||% "", fixed = TRUE)) {
  stop("get_gene_context description is missing an example")
}
if (!is.null(gene_tool$inputSchema$properties$query) || !is.null(gene_tool$inputSchema$properties$symbol)) {
  stop("get_gene_context schema exposes deprecated gene aliases")
}
if (is.null(gene_tool$inputSchema$properties$response_mode)) {
  stop("get_gene_context schema is missing response_mode")
}
if (is.null(gene_tool$inputSchema$properties$synopsis_mode)) {
  stop("get_gene_context schema is missing synopsis_mode")
}
if (is.null(gene_tool$inputSchema$properties$expand)) {
  stop("get_gene_context schema is missing expand")
}
if (!grepl("default true", gene_tool$inputSchema$properties$include_entities$description %||% "", ignore.case = TRUE)) {
  stop("get_gene_context include_entities description is missing default")
}
entity_batch_tool <- tool_by_name("get_entities_context")
if (is.null(entity_batch_tool$inputSchema$properties$dedupe_publications)) {
  stop("get_entities_context schema is missing dedupe_publications")
}
pub_tool <- tool_by_name("get_publications_context")
if (is.null(pub_tool$inputSchema$properties$abstract_mode)) {
  stop("get_publications_context schema is missing abstract_mode")
}

resources <- rpc("resources/list", id = 3L)
if (!is.null(resources$error)) stop("MCP resources/list failed: ", resources$error$message)
resource_uris <- vapply(resources$result$resources %||% list(), function(x) x$uri %||% "", character(1))
if (!"sysndd://schema/tool-guide" %in% resource_uris) {
  stop("MCP resources/list missing sysndd://schema/tool-guide")
}
tool_guide <- rpc("resources/read", list(uri = "sysndd://schema/tool-guide"), id = 4L)
if (!is.null(tool_guide$error)) stop("MCP resources/read failed: ", tool_guide$error$message)
if (!grepl("tool-guide", tool_guide$result$contents[[1]]$text %||% "", fixed = TRUE)) {
  stop("MCP resources/read returned unexpected tool-guide text")
}
overview <- rpc("resources/read", list(uri = "sysndd://schema/overview"), id = 41L)
if (!is.null(overview$error)) stop("MCP overview resource read failed: ", overview$error$message)
overview_text <- overview$result$contents[[1]]$text %||% ""
tool_guide_text <- tool_guide$result$contents[[1]]$text %||% ""
if (identical(overview_text, tool_guide_text) || grepl("schema/tool-guide", overview_text, fixed = TRUE)) {
  stop("MCP schema resources are not distinct")
}

prompts <- rpc("prompts/list", id = 42L)
if (!is.null(prompts$error)) stop("MCP prompts/list failed: ", prompts$error$message)
prompt_names <- vapply(prompts$result$prompts %||% list(), function(x) x$name %||% "", character(1))
if (!"sysndd_gene_evidence_summary" %in% prompt_names) {
  stop("MCP prompts/list missing sysndd_gene_evidence_summary")
}
prompt <- rpc("prompts/get", list(name = "sysndd_gene_evidence_summary", arguments = list(gene = "NAA10")), id = 43L)
if (!is.null(prompt$error)) stop("MCP prompts/get failed: ", prompt$error$message)
if (!grepl("recommended_citation", prompt$result$messages[[1]]$content$text %||% "", fixed = TRUE)) {
  stop("MCP prompt did not include citation guidance")
}

call_tool <- function(name, arguments, id) {
  rpc("tools/call", list(name = name, arguments = arguments), id = id)
}

capabilities <- call_tool("get_sysndd_capabilities", list(), id = 44L)
if (!is.null(capabilities$error)) stop("Capabilities returned JSON-RPC error: ", capabilities$error$message)
if (is.null(capabilities$result$structuredContent)) {
  stop("Capabilities response missing structuredContent despite outputSchema")
}
capabilities_payload <- jsonlite::fromJSON(capabilities$result$content[[1]]$text, simplifyVector = FALSE)
if (!"compact" %in% capabilities_payload$payload_modes$response_mode) {
  stop("Capabilities payload missing response_mode guidance")
}
if (!identical(capabilities_payload$limits$get_entities_context$max_entity_ids, 20L)) {
  stop("Capabilities payload missing get_entities_context max")
}

malformed_pmid <- call_tool("get_publication_context", list(pmid = "notapmid"), id = 5L)
if (!is.null(malformed_pmid$error)) stop("Malformed PMID returned JSON-RPC error: ", malformed_pmid$error$message)
if (!isTRUE(malformed_pmid$result$isError)) stop("Malformed PMID did not return a tool error result")
pmid_payload <- jsonlite::fromJSON(malformed_pmid$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(pmid_payload$error$code, "invalid_input") || !identical(pmid_payload$error$argument, "pmid")) {
  stop("Malformed PMID did not return invalid_input for pmid")
}

bad_category <- call_tool(
  "find_entities_by_phenotype",
  list(phenotype = "HP:0001250", category = "BogusCategory"),
  id = 6L
)
if (!is.null(bad_category$error)) stop("Invalid phenotype category returned JSON-RPC error: ", bad_category$error$message)
if (!isTRUE(bad_category$result$isError)) stop("Invalid phenotype category did not return a tool error result")
category_payload <- jsonlite::fromJSON(bad_category$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(category_payload$error$code, "invalid_input") || !identical(category_payload$error$argument, "category")) {
  stop("Invalid phenotype category did not return invalid_input for category")
}

symbol_alias <- call_tool("get_gene_context", list(symbol = "NAA10", entity_limit = 1L), id = 7L)
if (!is.null(symbol_alias$error)) stop("symbol alias returned JSON-RPC error: ", symbol_alias$error$message)
symbol_payload <- jsonlite::fromJSON(symbol_alias$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(symbol_payload$gene$symbol, "NAA10")) {
  stop("get_gene_context symbol alias did not resolve NAA10")
}

query_alias <- call_tool("get_gene_context", list(query = "NAA10", entity_limit = 1L), id = 8L)
if (!is.null(query_alias$error)) stop("query alias returned JSON-RPC error: ", query_alias$error$message)
query_payload <- jsonlite::fromJSON(query_alias$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(query_payload$gene$symbol, "NAA10")) {
  stop("get_gene_context query alias did not resolve NAA10")
}

cheap_gene <- call_tool(
  "get_gene_context",
  list(gene = "NAA10", include_comparisons = FALSE, entity_limit = 2L, response_mode = "compact"),
  id = 81L
)
if (!is.null(cheap_gene$error)) stop("cheap get_gene_context returned JSON-RPC error: ", cheap_gene$error$message)
cheap_gene_payload <- jsonlite::fromJSON(cheap_gene$result$content[[1]]$text, simplifyVector = FALSE)
if (length(cheap_gene_payload$comparison_sources %||% list()) != 0L) {
  stop("cheap get_gene_context returned comparison_sources")
}
if (is.null(cheap_gene_payload$meta$entity_total) || is.null(cheap_gene_payload$meta$entity_has_more)) {
  stop("get_gene_context did not report entity pagination metadata")
}
if (is.null(cheap_gene$result$structuredContent)) {
  stop("get_gene_context response missing structuredContent despite outputSchema")
}
entity_ids <- vapply(cheap_gene_payload$entities %||% list(), function(x) as.integer(x$entity_id), integer(1))
if (length(entity_ids) > 0L) {
  batch <- call_tool(
    "get_entities_context",
    list(entity_ids = as.list(entity_ids), publication_limit = 2L, abstract_mode = "metadata", dedupe_publications = TRUE),
    id = 82L
  )
  if (!is.null(batch$error)) stop("deduped get_entities_context returned JSON-RPC error: ", batch$error$message)
  batch_payload <- jsonlite::fromJSON(batch$result$content[[1]]$text, simplifyVector = FALSE)
  if (!isTRUE(batch_payload$meta$dedupe_publications)) {
    stop("get_entities_context did not report dedupe_publications")
  }
  if (length(batch_payload$entities) > 0L && !is.null(batch_payload$entities[[1]]$publications)) {
    stop("deduped get_entities_context kept nested publications")
  }
  if (length(batch_payload$publications) > 0L && !is.null(batch_payload$publications[[1]]$abstract_excerpt)) {
    stop("abstract_mode=metadata returned abstract_excerpt in batch payload")
  }
  expanded_gene <- call_tool(
    "get_gene_context",
    list(
      gene = "NAA10",
      entity_limit = 2L,
      response_mode = "compact",
      expand = "entities",
      abstract_mode = "metadata",
      publication_limit = 2L
    ),
    id = 83L
  )
  if (!is.null(expanded_gene$error)) stop("expanded get_gene_context returned JSON-RPC error: ", expanded_gene$error$message)
  expanded_payload <- jsonlite::fromJSON(expanded_gene$result$content[[1]]$text, simplifyVector = FALSE)
  if (!identical(expanded_payload$meta$expand, "entities") || is.null(expanded_payload$entity_details)) {
    stop("get_gene_context expand=entities did not return entity_details")
  }
  if (length(expanded_payload$entity_details$publications) > 0L &&
    !is.null(expanded_payload$entity_details$publications[[1]]$abstract_excerpt)) {
    stop("expanded get_gene_context metadata mode returned abstract_excerpt")
  }
}

bad_gene_arg <- call_tool("get_gene_context", list(foo = "NAA10"), id = 9L)
if (!is.null(bad_gene_arg$error)) stop("Unknown gene arg returned JSON-RPC error: ", bad_gene_arg$error$message)
if (!isTRUE(bad_gene_arg$result$isError)) stop("Unknown gene arg did not return a tool error result")
bad_gene_payload <- jsonlite::fromJSON(bad_gene_arg$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(bad_gene_payload$error$code, "invalid_input") || !identical(bad_gene_payload$error$argument, "foo")) {
  stop("Unknown gene arg did not return invalid_input for foo")
}

cat("MCP smoke OK: ", paste(sort(tool_names), collapse = ", "), "\n", sep = "")
