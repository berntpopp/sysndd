# db/config/db_sysid_source.R
#
# SysID source abstraction for the initial SysNDD import.
#
# The original SysID import (scripts 04, 05, 06, 07, 08) reads two tables —
# `disease` and `human_gene_disease_connect` — from the upstream SysID MySQL
# instance over an SSH tunnel. That source is no longer reproducible by anyone
# outside the original maintainers, which blocks a clean rebuild of the SysNDD
# database from scratch.
#
# To make the initial import reproducible (GitHub issue #33), this module lets a
# script read the same two tables from a *local SQLite snapshot* instead. The
# snapshot is a one-time, versionable artifact an operator builds once from the
# live SysID DB (see `db_sysid_export_to_sqlite()` and `db/README.md`), and then
# commits / archives so future rebuilds are deterministic and network-free.
#
# Selection is driven by config (`sysid_source: "sqlite" | "mysql"`), defaulting
# to SQLite when a snapshot file is present so reproducible rebuilds are the easy
# path.
#
# Pure helpers (mode/path resolution) are unit-tested in db/tests/. The actual
# DBI connections are NOT exercised on host CI because they need RSQLite /
# RMariaDB + a real snapshot/tunnel.

#' Decide which SysID source to use for the initial import.
#'
#' Resolution order:
#'   1. `SYSID_SOURCE` environment variable ("sqlite" | "mysql"), if set.
#'   2. `config$sysid_source`, if set in the loaded config.
#'   3. "sqlite" when a snapshot file exists at the resolved snapshot path.
#'   4. "mysql" otherwise (legacy SSH-tunnelled remote source).
#'
#' @param config Loaded config list (from `db_load_config()`); may be `NULL`.
#' @return One of "sqlite" or "mysql".
db_sysid_source_mode <- function(config = NULL) {
  env_mode <- tolower(Sys.getenv("SYSID_SOURCE", unset = ""))
  if (env_mode %in% c("sqlite", "mysql")) {
    return(env_mode)
  }

  cfg_mode <- if (!is.null(config)) tolower(config$sysid_source %||% "") else ""
  if (cfg_mode %in% c("sqlite", "mysql")) {
    return(cfg_mode)
  }

  if (file.exists(db_sysid_sqlite_path(config))) {
    return("sqlite")
  }

  "mysql"
}

#' Resolve the path to the local SysID SQLite snapshot.
#'
#' Order: `config$sysid_sqlite_path` (absolute or db/-relative), else the
#' default `db/data/sysid/sysid_snapshot.sqlite`.
#'
#' @param config Loaded config list; may be `NULL`.
#' @return Absolute, normalized path string.
db_sysid_sqlite_path <- function(config = NULL) {
  configured <- if (!is.null(config)) config$sysid_sqlite_path %||% "" else ""
  if (nzchar(configured)) {
    if (.db_is_absolute_path(configured)) {
      return(normalizePath(configured, mustWork = FALSE))
    }
    return(db_path(configured))
  }
  db_data_path("sysid", "sysid_snapshot.sqlite")
}

#' Open a DBI connection to the configured SysID source.
#'
#' For "sqlite", opens the local snapshot (read-only). For "mysql", opens a
#' connection to the SSH-tunnelled remote SysID database using the legacy config
#' keys. Callers are responsible for closing the connection with
#' `DBI::dbDisconnect()` (and tearing down any SSH tunnel they started).
#'
#' @param config Loaded config list (from `db_load_config()`).
#' @param mode Optional explicit mode override ("sqlite" | "mysql").
#' @return A DBI connection.
db_sysid_connect <- function(config, mode = db_sysid_source_mode(config)) {
  if (mode == "sqlite") {
    if (!requireNamespace("RSQLite", quietly = TRUE)) {
      stop("RSQLite is required to read the SysID SQLite snapshot.", call. = FALSE)
    }
    snapshot <- db_sysid_sqlite_path(config)
    if (!file.exists(snapshot)) {
      stop(
        "SysID SQLite snapshot not found: ", snapshot,
        "\nBuild it once with db_sysid_export_to_sqlite(), or set ",
        "sysid_source: mysql to use the live remote source.",
        call. = FALSE
      )
    }
    return(DBI::dbConnect(RSQLite::SQLite(), dbname = snapshot, flags = RSQLite::SQLITE_RO))
  }

  if (!requireNamespace("RMariaDB", quietly = TRUE)) {
    stop("RMariaDB is required to read the live SysID MySQL source.", call. = FALSE)
  }
  DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = config$dbname_sysid,
    user = config$user_sysid,
    password = config$password_sysid,
    host = config$server_sysid_local,
    port = as.integer(config$port_sysid_local)
  )
}

#' Read a SysID table from the connected source as a tibble/data.frame.
#'
#' Wraps the table read so call sites are source-agnostic. The two tables the
#' initial import needs are "disease" and "human_gene_disease_connect".
#'
#' @param conn DBI connection from `db_sysid_connect()`.
#' @param table Table name.
#' @return A data.frame of the table contents.
db_sysid_read_table <- function(conn, table) {
  DBI::dbReadTable(conn, table)
}

#' Export the SysID source tables to a local SQLite snapshot (one-time).
#'
#' OPERATOR HELPER. Run this once, with `mode = "mysql"` config pointed at the
#' live SysID DB, to produce the reproducible snapshot future rebuilds read.
#' Commit / archive the resulting file. By default it captures the two tables
#' the initial import consumes.
#'
#' @param config Loaded config list with live SysID MySQL credentials.
#' @param sqlite_path Destination snapshot path (defaults to the resolved
#'   snapshot path).
#' @param tables Character vector of SysID table names to capture.
#' @return The path to the written SQLite snapshot (invisibly).
db_sysid_export_to_sqlite <- function(config,
                                      sqlite_path = db_sysid_sqlite_path(config),
                                      tables = c("disease", "human_gene_disease_connect")) {
  if (!requireNamespace("RSQLite", quietly = TRUE)) {
    stop("RSQLite is required to write the SysID SQLite snapshot.", call. = FALSE)
  }
  dir.create(dirname(sqlite_path), recursive = TRUE, showWarnings = FALSE)

  src <- db_sysid_connect(config, mode = "mysql")
  on.exit(DBI::dbDisconnect(src), add = TRUE)

  dst <- DBI::dbConnect(RSQLite::SQLite(), dbname = sqlite_path)
  on.exit(DBI::dbDisconnect(dst), add = TRUE)

  for (table in tables) {
    data <- DBI::dbReadTable(src, table)
    DBI::dbWriteTable(dst, table, data, overwrite = TRUE)
    message("Wrote SysID table '", table, "' (", nrow(data), " rows) to snapshot.")
  }

  message("SysID SQLite snapshot written to: ", sqlite_path)
  invisible(sqlite_path)
}

# Minimal helpers ----------------------------------------------------------

# `%||%`: return `x` unless it is NULL, otherwise `y`. (rlang provides this but
# we avoid a hard dependency here.)
`%||%` <- function(x, y) if (is.null(x)) y else x

# Cross-platform absolute-path test (handles POSIX "/..." and Windows "C:\...").
.db_is_absolute_path <- function(path) {
  grepl("^(/|[A-Za-z]:[\\\\/])", path)
}
