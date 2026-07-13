# tests/testthat/test-mcp-select-principal-db-boundary.R

library(testthat)

test_that("MCP runtime never falls back to ordinary database credentials", {
  env <- new.env(parent = .GlobalEnv)
  sys.source(file.path(get_api_dir(), "functions", "db-helpers.R"), envir = env)

  prior_pool_exists <- base::exists("pool", envir = .GlobalEnv, inherits = FALSE)
  if (prior_pool_exists) prior_pool <- base::get("pool", envir = .GlobalEnv)
  if (prior_pool_exists) base::rm("pool", envir = .GlobalEnv)
  withr::defer({
    if (prior_pool_exists) base::assign("pool", prior_pool, envir = .GlobalEnv)
  })

  withr::local_envvar(c(
    SYSNDD_RUNTIME = "mcp",
    MYSQL_HOST = "ordinary-api-db",
    MYSQL_DATABASE = "ordinary-api-schema",
    MYSQL_USER = "ordinary-api-user",
    MYSQL_PASSWORD = "ordinary-api-password"
  ))

  expect_error(
    env$get_db_connection(),
    "dedicated MCP pool is unavailable",
    class = "mcp_database_boundary_error"
  )
})
