## -------------------------------------------------------------------##
# api/bootstrap/create_pool.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Builds the shared DBI/pool object used by every repository,
# service and endpoint. Returns the pool so that the top-level
# composer in start_sysndd_api.R can bind it at the global scope
# without needing a super-assignment.
## -------------------------------------------------------------------##

#' Create the application-wide MariaDB connection pool.
#'
#' Pool sizing is driven by the `DB_POOL_SIZE` environment variable
#' (default 5). Single-threaded R rarely needs >1–2 concurrent
#' connections, but up to 5 accommodates burst load from mirai
#' workers. Keeping an explicit upper bound prevents unbounded
#' connection growth from exhausting MySQL's `max_connections`.
#'
#' @param dw A list from `config::get()` with `dbname`, `host`,
#'   `user`, `password`, `server`, `port`.
#' @return A pool object created by `pool::dbPool()`.
#' @export
bootstrap_create_pool <- function(dw) {
  pool_size <- as.integer(Sys.getenv("DB_POOL_SIZE", "5"))
  if (is.na(pool_size) || pool_size < 1L) {
    pool_size <- 5L
  }

  pool_obj <- pool::dbPool(
    drv = RMariaDB::MariaDB(),
    dbname = dw$dbname,
    host = dw$host,
    user = dw$user,
    password = dw$password,
    server = dw$server,
    port = dw$port,
    minSize = 1,
    maxSize = pool_size,
    idleTimeout = 60,
    validationInterval = 60
  )

  message(sprintf(
    "[%s] Database pool created (minSize=1, maxSize=%d)",
    Sys.time(), pool_size
  ))

  pool_obj
}
