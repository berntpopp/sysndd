#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

required <- c("httr2", "jsonlite")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Missing required packages for MCP healthcheck: ", paste(missing, collapse = ", "))
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
  payload <- jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)
  if (!is.null(payload$error)) {
    stop("MCP ", method, " failed: ", payload$error$message %||% "unknown error")
  }
  payload
}

init <- rpc("initialize", list(
  protocolVersion = "2025-11-25",
  capabilities = list(),
  clientInfo = list(name = "sysndd-mcp-healthcheck", version = "0.1.0")
), 1L)
if (is.null(init$result$serverInfo$name)) {
  stop("MCP initialize did not return serverInfo")
}

listed <- rpc("tools/list", id = 2L)
tools <- listed$result$tools %||% list()
if (length(tools) == 0L) {
  stop("MCP tools/list returned no tools")
}

cat("MCP healthcheck OK\n")
