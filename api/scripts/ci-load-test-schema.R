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

host <- Sys.getenv("MYSQL_HOST", "127.0.0.1")
port <- as.integer(Sys.getenv("MYSQL_PORT", "3306"))
dbname <- Sys.getenv("MYSQL_DATABASE", "sysndd_test")
user <- Sys.getenv("MYSQL_USER", "test")
password <- Sys.getenv("MYSQL_PASSWORD", "test")

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
  stop(sprintf("Expected the full schema, found only %d tables.", as.integer(tables)),
       call. = FALSE)
}
