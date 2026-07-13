# Dedicated, fail-closed database configuration for the MCP sidecar.

.mcp_config_abort <- function(message) {
  stop(structure(
    list(message = message, call = NULL),
    class = c("mcp_config_error", "error", "condition")
  ))
}

.mcp_env_value <- function(name) {
  env_reader <- base::get("Sys.getenv", envir = baseenv(), inherits = FALSE)
  value <- env_reader(name, unset = "")
  if (length(value) != 1L || is.na(value)) "" else value
}

.mcp_require_plain_value <- function(value, label) {
  if (!nzchar(value) || nchar(value, type = "bytes") > 4096L ||
      grepl("[\\r\\n\\x00]", value, perl = TRUE)) {
    .mcp_config_abort(sprintf("%s must be a nonempty single-line value", label))
  }
  value
}

.mcp_parse_bounded_integer <- function(value, label, minimum, maximum) {
  if (!grepl("^[0-9]+$", value)) {
    .mcp_config_abort(sprintf("%s must be an integer", label))
  }
  parsed <- suppressWarnings(as.integer(value))
  if (is.na(parsed) || parsed < minimum || parsed > maximum) {
    .mcp_config_abort(sprintf("%s is outside its allowed range", label))
  }
  parsed
}

.mcp_read_password_file <- function(path) {
  path <- .mcp_require_plain_value(path, "MCP_DB_PASSWORD_FILE")
  if (nzchar(Sys.readlink(path))) {
    .mcp_config_abort("MCP_DB_PASSWORD_FILE must not be a symbolic link")
  }

  normalized <- tryCatch(
    normalizePath(path, mustWork = TRUE),
    error = function(e) .mcp_config_abort("MCP_DB_PASSWORD_FILE is not readable")
  )
  info <- file.info(normalized)
  unsafe_mode <- bitwAnd(as.integer(info$mode[[1]]), strtoi("077", base = 8L)) != 0L
  if (nrow(info) != 1L || is.na(info$isdir[[1]]) || info$isdir[[1]] ||
      is.na(info$size[[1]]) || info$size[[1]] < 1L || info$size[[1]] > 4096L ||
      is.na(info$mode[[1]]) || unsafe_mode) {
    .mcp_config_abort("MCP_DB_PASSWORD_FILE must be an owner-only regular file")
  }

  connection <- file(normalized, open = "rb")
  on.exit(close(connection), add = TRUE)
  bytes <- readBin(connection, what = "raw", n = 4097L)
  if (length(bytes) < 1L || length(bytes) > 4096L ||
      any(bytes %in% as.raw(c(0L, 10L, 13L)))) {
    .mcp_config_abort("MCP database password file must contain one nonempty line")
  }
  rawToChar(bytes)
}

#' Read dedicated MCP database configuration from environment injection.
#'
#' This function intentionally has no config.yml or MYSQL_* fallback.
#' @return A validated list suitable for bootstrap_create_mcp_pool().
mcp_readonly_config <- function() {
  host <- .mcp_require_plain_value(.mcp_env_value("MCP_DB_HOST"), "MCP_DB_HOST")
  dbname <- .mcp_require_plain_value(.mcp_env_value("MCP_DB_NAME"), "MCP_DB_NAME")
  user <- .mcp_require_plain_value(.mcp_env_value("MCP_DB_USER"), "MCP_DB_USER")
  if (!identical(user, "sysndd_mcp")) {
    .mcp_config_abort("MCP_DB_USER must be the fixed sysndd_mcp identity")
  }
  if (!grepl("^[A-Za-z0-9_]+$", dbname)) {
    .mcp_config_abort("MCP_DB_NAME contains unsupported characters")
  }

  port <- .mcp_parse_bounded_integer(
    .mcp_env_value("MCP_DB_PORT"), "MCP_DB_PORT", 1L, 65535L
  )
  pool_size_text <- .mcp_env_value("MCP_DB_POOL_SIZE")
  if (!nzchar(pool_size_text)) pool_size_text <- "2"
  pool_size <- .mcp_parse_bounded_integer(
    pool_size_text, "MCP_DB_POOL_SIZE", 1L, 5L
  )

  if (nzchar(.mcp_env_value("MCP_DB_PASSWORD"))) {
    .mcp_config_abort(
      "MCP_DB_PASSWORD is not supported; use MCP_DB_PASSWORD_FILE"
    )
  }
  password_file <- .mcp_env_value("MCP_DB_PASSWORD_FILE")
  password <- .mcp_read_password_file(password_file)

  structure(
    list(
      host = host,
      port = port,
      dbname = dbname,
      user = user,
      password = password,
      pool_size = pool_size
    ),
    class = c("mcp_readonly_config", "list")
  )
}
