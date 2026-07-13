#!/usr/bin/env Rscript
# Privileged, serialized operator entry point for the SELECT-only MCP reader.
# Run from api/ after the ordinary migration runner has applied migration 044.

source("functions/mcp-readonly-contract.R", local = FALSE)
source("functions/mcp-readonly-provisioner.R", local = FALSE)
source("functions/mcp-readonly-provisioner-quarantine.R", local = FALSE)
source("functions/mcp-readonly-provisioner-recovery.R", local = FALSE)
source("functions/mcp-readonly-provisioner-secret.R", local = FALSE)

serialized <- identical(
  tolower(Sys.getenv("MCP_PROVISION_SERIALIZED", unset = "")),
  "true"
)
if (!serialized) {
  stop(
    "Set MCP_PROVISION_SERIALIZED=true only after stopping the MCP service",
    call. = FALSE
  )
}

admin <- mcp_readonly_admin_config()
password_output_path <- Sys.getenv("MCP_DB_PASSWORD_OUTPUT_FILE", unset = "")
if (!nzchar(password_output_path) || grepl("[\r\n]", password_output_path) ||
    !startsWith(password_output_path, "/")) {
  stop("MCP_DB_PASSWORD_OUTPUT_FILE must be an absolute path", call. = FALSE)
}

migration_path <- Sys.getenv(
  "MCP_MIGRATION_PATH",
  unset = file.path("..", "db", "migrations", "044_mcp_public_read_projections.sql")
)
if (!file.exists(migration_path)) {
  stop("Trusted migration 044 is unavailable", call. = FALSE)
}

conn <- DBI::dbConnect(
  RMariaDB::MariaDB(),
  host = admin$host,
  port = admin$port,
  dbname = admin$dbname,
  user = admin$user,
  password = admin$password
)
on.exit(DBI::dbDisconnect(conn), add = TRUE)

mcp_readonly_reconcile(
  conn = conn,
  database = admin$dbname,
  password_output_path = password_output_path,
  expected_definer = admin$expected_definer,
  migration_path = migration_path,
  serialized = serialized,
  recovery_conn_factory = function() {
    DBI::dbConnect(
      RMariaDB::MariaDB(),
      host = admin$host,
      port = admin$port,
      dbname = admin$dbname,
      user = admin$user,
      password = admin$password
    )
  }
)

cat("MCP SELECT-only principal provisioned and attested\n")
