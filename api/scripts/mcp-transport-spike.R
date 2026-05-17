#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

port <- as.integer(Sys.getenv("MCP_SPIKE_PORT", "8797"))
host <- "127.0.0.1"
endpoint <- Sys.getenv("MCP_SPIKE_ENDPOINT", sprintf("http://%s:%d", host, port))

required <- c("ellmer", "mcptools", "httr2", "jsonlite", "callr")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Missing required packages for MCP spike: ", paste(missing, collapse = ", "))
}

server_file <- tempfile("sysndd-mcp-spike-", fileext = ".R")
writeLines(c(
  "`%||%` <- function(x, y) if (is.null(x)) y else x",
  "library(ellmer)",
  "library(mcptools)",
  "library(jsonlite)",
  "tool <- ellmer::tool(function() {",
  "  jsonlite::toJSON(list(schema_version = '1.0', entity_count = 0L), auto_unbox = TRUE)",
  "}, name = 'get_sysndd_stats', description = 'Return a tiny read-only SysNDD stats payload')",
  sprintf("mcptools::mcp_server(tools = list(tool), type = 'http', host = '127.0.0.1', port = %d, session_tools = FALSE)", port)
), server_file)

proc <- callr::r_bg(function(path) source(path), args = list(server_file), supervise = TRUE)
on.exit({
  if (proc$is_alive()) proc$kill()
  unlink(server_file)
}, add = TRUE)

deadline <- Sys.time() + 15
ready <- FALSE
while (Sys.time() < deadline && !ready) {
  Sys.sleep(0.25)
  ready <- tryCatch({
    req <- httr2::request(endpoint) |>
      httr2::req_body_json(list(
        jsonrpc = "2.0",
        id = 0L,
        method = "initialize",
        params = list(
          protocolVersion = "2025-11-25",
          capabilities = list(),
          clientInfo = list(name = "sysndd-spike-readiness", version = "0.1.0")
        )
      ), auto_unbox = TRUE) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_timeout(2)
    resp <- httr2::req_perform(req)
    httr2::resp_status(resp) < 500L
  }, error = function(e) FALSE)
}
if (!ready) {
  stderr <- tryCatch(proc$read_error(), error = function(e) "")
  stdout <- tryCatch(proc$read_output(), error = function(e) "")
  stop("MCP spike server did not become reachable\nstdout:\n", stdout, "\nstderr:\n", stderr)
}

rpc <- function(method, params = NULL, id = 1L, extra_headers = list()) {
  body <- list(jsonrpc = "2.0", id = id, method = method)
  if (!is.null(params)) body$params <- params

  req <- httr2::request(endpoint) |>
    httr2::req_headers(
      `Content-Type` = "application/json",
      `MCP-Protocol-Version` = "2025-11-25"
    ) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_timeout(5)

  for (nm in names(extra_headers)) {
    req <- httr2::req_headers(req, .headers = setNames(list(extra_headers[[nm]]), nm))
  }

  resp <- httr2::req_perform(req)
  body_string <- httr2::resp_body_string(resp)
  list(
    status = httr2::resp_status(resp),
    headers = httr2::resp_headers(resp),
    body = jsonlite::fromJSON(body_string, simplifyVector = FALSE)
  )
}

init <- rpc("initialize", list(
  protocolVersion = "2025-11-25",
  capabilities = list(),
  clientInfo = list(name = "sysndd-spike", version = "0.1.0")
), 1L)
if (init$status >= 400L || is.null(init$body$result)) {
  stop("initialize failed")
}
session_id <- init$headers[["mcp-session-id"]]

headers <- if (!is.null(session_id)) list(`MCP-Session-Id` = session_id) else list()
listed <- rpc("tools/list", id = 2L, extra_headers = headers)
tools <- listed$body$result$tools %||% list()
tool_names <- vapply(tools, function(x) x$name %||% "", character(1))
if (!"get_sysndd_stats" %in% tool_names) {
  stop("tools/list did not expose get_sysndd_stats")
}

called <- rpc("tools/call", list(name = "get_sysndd_stats", arguments = list()), 3L, headers)
if (called$status >= 400L || is.null(called$body$result)) {
  stop("tools/call failed")
}

get_resp <- httr2::request(endpoint) |>
  httr2::req_method("GET") |>
  httr2::req_error(is_error = function(resp) FALSE) |>
  httr2::req_perform()
get_status <- httr2::resp_status(get_resp)
if (!get_status %in% c(200L, 405L)) {
  stop("GET returned unexpected status: ", get_status)
}

result <- called$body$result
has_structured <- !is.null(result$structuredContent)
has_text_json <- any(vapply(result$content %||% list(), function(item) {
  identical(item$type, "text") && grepl("^\\s*\\{", item$text %||% "")
}, logical(1)))
if (!has_structured && !has_text_json) {
  stop("Tool output is neither structuredContent nor JSON text")
}

cat(jsonlite::toJSON(list(
  ok = TRUE,
  mcptools_version = as.character(utils::packageVersion("mcptools")),
  session_header_issued = !is.null(session_id),
  get_status = get_status,
  output_mode = if (has_structured) "structuredContent" else "json_text"
), auto_unbox = TRUE, pretty = TRUE))
cat("\n")
