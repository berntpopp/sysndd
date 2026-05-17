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

listed <- rpc("tools/list", id = 2L)
tools <- listed$result$tools %||% list()
tool_names <- vapply(tools, function(x) x$name %||% "", character(1))
required_tools <- c("search_sysndd", "get_gene_context", "get_entity_context", "get_entities_context", "get_publication_context", "get_publications_context")
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
if (is.null(gene_tool$inputSchema$properties$query)) {
  stop("get_gene_context schema is missing query alias")
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

call_tool <- function(name, arguments, id) {
  rpc("tools/call", list(name = name, arguments = arguments), id = id)
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

bad_gene_arg <- call_tool("get_gene_context", list(foo = "NAA10"), id = 9L)
if (!is.null(bad_gene_arg$error)) stop("Unknown gene arg returned JSON-RPC error: ", bad_gene_arg$error$message)
if (!isTRUE(bad_gene_arg$result$isError)) stop("Unknown gene arg did not return a tool error result")
bad_gene_payload <- jsonlite::fromJSON(bad_gene_arg$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(bad_gene_payload$error$code, "invalid_input") || !identical(bad_gene_payload$error$argument, "foo")) {
  stop("Unknown gene arg did not return invalid_input for foo")
}

cat("MCP smoke OK: ", paste(sort(tool_names), collapse = ", "), "\n", sep = "")
