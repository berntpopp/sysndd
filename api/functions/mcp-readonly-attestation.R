# Fail-closed startup attestation for the dedicated MCP database principal.

.mcp_attestation_abort <- function(message) {
  stop(structure(
    list(message = message, call = NULL),
    class = c("mcp_attestation_error", "error", "condition")
  ))
}

.mcp_attestation_identifier <- function(value, label) {
  if (length(value) != 1L || is.na(value) ||
      !grepl("^[A-Za-z0-9_]+$", value)) {
    .mcp_attestation_abort(sprintf("Invalid trusted %s", label))
  }
  value
}

.mcp_attestation_query <- function(query_fn, conn, sql, label) {
  tryCatch(
    query_fn(conn, sql),
    error = function(e) {
      .mcp_attestation_abort(
        sprintf("MCP database %s attestation failed", label)
      )
    }
  )
}

.mcp_normalize_grants <- function(grants) {
  normalized <- trimws(gsub("\\s+", " ", as.character(grants)))
  normalized <- sub(";+$", "", normalized)
  sort(unique(normalized))
}

.mcp_attestation_scalar <- function(table, column) {
  if (!is.data.frame(table) || nrow(table) != 1L ||
      !column %in% names(table) || length(table[[column]]) != 1L ||
      is.na(table[[column]][[1]])) {
    .mcp_attestation_abort("MCP database identity response is malformed")
  }
  as.character(table[[column]][[1]])
}

.mcp_expected_grants <- function(dbname, projection_names) {
  account <- "`sysndd_mcp`@`%`"
  c(
    sprintf("GRANT USAGE ON *.* TO %s", account),
    sprintf(
      "GRANT SELECT ON `%s`.`%s` TO %s",
      dbname,
      projection_names,
      account
    )
  )
}

#' Attest the effective MCP database identity and SELECT-only surface.
#'
#' @param conn Dedicated MCP pool/connection.
#' @param dbname Validated database name.
#' @param projection_names Exact trusted projection-name contract.
#' @param query_fn Injectable DB query function.
#' @return TRUE invisibly when all checks succeed; otherwise aborts.
mcp_readonly_attest <- function(
    conn,
    dbname,
    projection_names,
    query_fn = DBI::dbGetQuery) {
  dbname <- .mcp_attestation_identifier(dbname, "database name")
  if (!is.character(projection_names) || length(projection_names) < 1L ||
      anyDuplicated(projection_names)) {
    .mcp_attestation_abort("Invalid trusted projection contract")
  }
  projection_names <- vapply(
    projection_names,
    .mcp_attestation_identifier,
    character(1),
    label = "projection name"
  )

  identity <- .mcp_attestation_query(
    query_fn,
    conn,
    paste(
      "SELECT CURRENT_USER() AS mcp_current_user,",
      "CURRENT_ROLE() AS mcp_current_role,",
      "@@GLOBAL.mandatory_roles AS mcp_mandatory_roles"
    ),
    "identity"
  )
  current_user <- .mcp_attestation_scalar(identity, "mcp_current_user")
  current_role <- .mcp_attestation_scalar(identity, "mcp_current_role")
  mandatory_roles <- .mcp_attestation_scalar(identity, "mcp_mandatory_roles")
  if (!identical(current_user, "sysndd_mcp@%") ||
      !identical(current_role, "NONE") ||
      nzchar(trimws(mandatory_roles))) {
    .mcp_attestation_abort("MCP database identity or role state is not exact")
  }

  grant_rows <- .mcp_attestation_query(
    query_fn,
    conn,
    "SHOW GRANTS FOR CURRENT_USER()",
    "grant"
  )
  actual_grants <- if (ncol(grant_rows) == 1L) grant_rows[[1]] else character()
  expected_grants <- .mcp_expected_grants(dbname, projection_names)
  if (!identical(
    .mcp_normalize_grants(actual_grants),
    .mcp_normalize_grants(expected_grants)
  )) {
    .mcp_attestation_abort("MCP database grants do not match the exact contract")
  }

  for (projection in projection_names) {
    sql <- sprintf("SELECT 1 FROM `%s`.`%s` LIMIT 0", dbname, projection)
    .mcp_attestation_query(query_fn, conn, sql, "projection")
  }

  TRUE
}
