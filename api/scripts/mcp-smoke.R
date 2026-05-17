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

listed <- rpc("tools/list", id = 2L)
tools <- listed$result$tools %||% list()
tool_names <- vapply(tools, function(x) x$name %||% "", character(1))
required_tools <- c("search_sysndd", "get_gene_context", "get_entity_context", "get_publication_context", "get_publications_context")
missing_tools <- setdiff(required_tools, tool_names)
if (length(missing_tools) > 0L) {
  stop("MCP tools/list missing required tools: ", paste(missing_tools, collapse = ", "))
}

cat("MCP smoke OK: ", paste(sort(tool_names), collapse = ", "), "\n", sep = "")
