#!/usr/bin/env Rscript
#
# Apply every migration to the CI test database.
#
# WHY THIS EXISTS
# ---------------
# CI provisions a real MySQL service container, but an EMPTY one. Every
# `test-integration-*.R` file guards itself with a `skip_if_missing_*_schema()`
# helper that calls `DBI::dbExistsTable()`, so on an empty database they all
# SKIP -- silently, and forever. That is how the entity-rename suite sat dormant
# long enough for two production defects to hide behind it (#638), and how a
# fixture that seeded nothing at all went unnoticed for as long as it did.
#
# The database is already there and the migrations are the project's own
# source of truth for the schema, so the fix is simply to run them. This is a
# real schema, not a mock: the same 51 migrations the API applies at startup,
# on the same MySQL image, so an integration test exercises the constraints,
# views and defaults it will actually meet in production.
#
# Verified against MySQL 8.4's DEFAULT sql_mode
# (ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,
# ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION) as the unprivileged
# service user, because a GitHub Actions service container cannot override the
# server's command line.
#
# Usage (from api/):
#   MYSQL_HOST=127.0.0.1 MYSQL_DATABASE=sysndd_test \
#   MYSQL_USER=test MYSQL_PASSWORD=test Rscript scripts/ci-load-test-schema.R
#
# Idempotent: the migration runner records applied migrations in
# `schema_version` and skips them on a second run.

suppressMessages({
  library(DBI)
  library(RMariaDB)
  library(dplyr)
  library(logger)
})

source("functions/logging-functions.R")
source("functions/db-helpers.R")
source("functions/migration-runner.R")
source("functions/migration-manifest.R")

# CI sets MYSQL_* (matching helper-db.R's own CI mode). Locally, fall back to
# config.yml's `sysndd_db_test` block, so `make test-db-schema` gives a
# developer the same schema-loaded database CI now gets.
local_config <- NULL
if (Sys.getenv("MYSQL_HOST", "") == "" && file.exists("config.yml")) {
  local_config <- tryCatch(
    config::get("sysndd_db_test", file = "config.yml"),
    error = function(e) NULL
  )
}

setting <- function(env_name, config_name, fallback) {
  value <- Sys.getenv(env_name, "")
  if (nzchar(value)) {
    return(value)
  }
  if (!is.null(local_config) && !is.null(local_config[[config_name]])) {
    return(as.character(local_config[[config_name]]))
  }
  fallback
}

host <- setting("MYSQL_HOST", "host", "127.0.0.1")
port <- as.integer(setting("MYSQL_PORT", "port", "3306"))
dbname <- setting("MYSQL_DATABASE", "dbname", "sysndd_test")
user <- setting("MYSQL_USER", "user", "test")
password <- setting("MYSQL_PASSWORD", "password", "test")

cat(sprintf("Loading schema into %s@%s:%d/%s\n", user, host, port, dbname))

conn <- DBI::dbConnect(
  RMariaDB::MariaDB(),
  dbname = dbname, host = host, user = user, password = password, port = port
)
run_migrations(migrations_dir = "db/migrations", conn = conn)

tables <- DBI::dbGetQuery(
  conn,
  "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema = ?",
  params = list(dbname)
)$n[[1]]

DBI::dbDisconnect(conn)

cat(sprintf("Schema loaded: %d tables\n", as.integer(tables)))

# Fail loudly rather than letting the test job proceed against a half-loaded
# database and report a wall of skips as success.
if (as.integer(tables) < 50L) {
  # Loudly, not quietly: a half-loaded database makes every integration file
  # skip on its dbExistsTable() guard and report a wall of skips as success.
  #
  # On a fresh database this cannot happen. It means `schema_version` already
  # records migrations whose tables are absent -- a database built ad hoc rather
  # than by the runner. Recreate it (the local target points at
  # config.yml's `sysndd_db_test`, which is disposable by definition):
  #
  #   DROP DATABASE <db>; CREATE DATABASE <db>;   then re-run this script.
  stop(
    sprintf(
      paste(
        "Expected the full schema, found only %d tables.",
        "`schema_version` records migrations whose tables do not exist, so the",
        "runner skipped them. Drop and recreate `%s`, then re-run."
      ),
      as.integer(tables), dbname
    ),
    call. = FALSE
  )
}
