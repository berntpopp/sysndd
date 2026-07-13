library(testthat)

source_api_file("functions/mcp-readonly-provisioner.R", local = FALSE)

.admin_env <- function(values) {
  force(values)
  function(name, unset = "") {
    if (name %in% names(values)) values[[name]] else unset
  }
}

.admin_base <- c(
  MCP_ADMIN_DB_HOST = "mysql", MCP_ADMIN_DB_PORT = "3306",
  MCP_ADMIN_DB_NAME = "sysndd_db", MCP_ADMIN_DB_USER = "root",
  MCP_EXPECTED_VIEW_DEFINER = "schema_migrator@%"
)

test_that("administrator configuration has no ordinary database fallback", {
  secret <- tempfile("mcp-admin-password-")
  writeChar("operator-secret", secret, eos = NULL, useBytes = TRUE)
  Sys.chmod(secret, mode = "0600", use_umask = FALSE)
  withr::defer(unlink(secret))
  values <- c(
    MCP_ADMIN_DB_HOST = "db-admin.internal", MCP_ADMIN_DB_PORT = "3307",
    MCP_ADMIN_DB_NAME = "sysndd_db", MCP_ADMIN_DB_USER = "security_operator",
    MCP_ADMIN_DB_PASSWORD_FILE = secret,
    MCP_EXPECTED_VIEW_DEFINER = "schema_migrator@%",
    MYSQL_USER = "must-not-be-used", MYSQL_PASSWORD = "must-not-be-used"
  )
  config <- mcp_readonly_admin_config(getenv = .admin_env(values))

  expect_identical(config$host, "db-admin.internal")
  expect_identical(config$port, 3307L)
  expect_identical(config$dbname, "sysndd_db")
  expect_identical(config$user, "security_operator")
  expect_identical(config$password, "operator-secret")
  expect_identical(config$expected_definer, "schema_migrator@%")
  expect_error(mcp_readonly_admin_config(getenv = .admin_env(values[FALSE])), "MCP_ADMIN_DB_HOST")
  expect_error(mcp_readonly_admin_config(getenv = .admin_env(c(
    values[names(values) != "MCP_ADMIN_DB_PASSWORD_FILE"],
    MCP_ADMIN_DB_PASSWORD = "direct-secret"
  ))), "not supported")
})

test_that("administrator password file fails closed on unsafe metadata", {
  directory <- tempfile("mcp-admin-secret-")
  dir.create(directory, mode = "0700")
  withr::defer(unlink(directory, recursive = TRUE))
  secret <- file.path(directory, "password")
  writeChar("file-secret", secret, eos = NULL, useBytes = TRUE)
  Sys.chmod(secret, mode = "0600", use_umask = FALSE)

  read_config <- function(path) mcp_readonly_admin_config(
    getenv = .admin_env(c(.admin_base, MCP_ADMIN_DB_PASSWORD_FILE = path))
  )
  expect_identical(read_config(secret)$password, "file-secret")
  Sys.chmod(secret, mode = "0640", use_umask = FALSE)
  expect_error(read_config(secret), "owner-only regular file")
  Sys.chmod(secret, mode = "0600", use_umask = FALSE)
  link <- file.path(directory, "password-link")
  file.symlink(secret, link)
  expect_error(read_config(link), "symbolic link")
  expect_error(read_config(directory), "regular file")
})

test_that("administrator password file is one bounded line", {
  secret <- tempfile("mcp-admin-password-")
  withr::defer(unlink(secret))
  read_config <- function() mcp_readonly_admin_config(
    getenv = .admin_env(c(.admin_base, MCP_ADMIN_DB_PASSWORD_FILE = secret))
  )
  write_secret <- function(bytes) {
    writeBin(bytes, secret)
    Sys.chmod(secret, mode = "0600", use_umask = FALSE)
  }

  write_secret(charToRaw("line-one\nline-two"))
  expect_error(read_config(), "one nonempty line")
  write_secret(raw())
  expect_error(read_config(), "one nonempty line")
  write_secret(as.raw(rep(65L, 4097L)))
  expect_error(read_config(), "owner-only regular file|one nonempty line")
})
