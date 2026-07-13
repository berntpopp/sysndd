# Bounded database pool for the dedicated MCP principal.

#' Create the MCP database pool from validated dedicated configuration.
#'
#' @param config Output from mcp_readonly_config().
#' @param pool_factory Injectable pool constructor for unit tests.
#' @param driver Injectable MariaDB driver for unit tests.
#' @return A pool object.
bootstrap_create_mcp_pool <- function(
    config,
    pool_factory = pool::dbPool,
    driver = RMariaDB::MariaDB()) {
  required <- c("host", "port", "dbname", "user", "password", "pool_size")
  if (!is.list(config) || !all(required %in% names(config)) ||
      !identical(config$user, "sysndd_mcp") ||
      length(config$pool_size) != 1L || is.na(config$pool_size) ||
      config$pool_size < 1L || config$pool_size > 5L) {
    stop("Invalid dedicated MCP database configuration")
  }

  pool_factory(
    drv = driver,
    dbname = config$dbname,
    host = config$host,
    user = config$user,
    password = config$password,
    port = config$port,
    minSize = 1L,
    maxSize = as.integer(config$pool_size),
    idleTimeout = 60,
    validationInterval = 60
  )
}
