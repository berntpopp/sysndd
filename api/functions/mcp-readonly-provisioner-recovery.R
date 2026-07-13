# functions/mcp-readonly-provisioner-recovery.R
#
# Independent fail-closed compensation for an incomplete reader rotation.

mcp_readonly_remove_secret <- function(path) {
  path <- .mcp_readonly_scalar_text(path, "MCP_DB_PASSWORD_OUTPUT_FILE")
  link_target <- Sys.readlink(path)
  exists <- file.exists(path) || (!is.na(link_target) && nzchar(link_target))
  if (!exists) return(invisible(TRUE))

  status <- unlink(path, force = TRUE)
  remaining_link <- Sys.readlink(path)
  if (!identical(status, 0L) || file.exists(path) ||
      (!is.na(remaining_link) && nzchar(remaining_link))) {
    .mcp_readonly_abort("could not remove incomplete MCP reader secret")
  }
  invisible(TRUE)
}

mcp_readonly_recover_incomplete <- function(
    conn,
    password_output_path,
    query_fn,
    execute_fn,
    quote_account_fn,
    recovery_conn_factory = NULL,
    disconnect_fn = function(conn) DBI::dbDisconnect(conn),
    remove_secret_fn = mcp_readonly_remove_secret) {
  secret_removed <- tryCatch(
    {
      remove_secret_fn(password_output_path)
      TRUE
    },
    error = function(e) FALSE
  )
  if (!secret_removed) {
    warning("Incomplete MCP reader secret could not be removed", call. = FALSE)
  }
  try(
    mcp_readonly_quarantine_reader(
      conn, query_fn, execute_fn, quote_account_fn, best_effort = TRUE
    ),
    silent = TRUE
  )

  if (is.null(recovery_conn_factory)) return(invisible(TRUE))
  recovery_conn <- tryCatch(recovery_conn_factory(), error = identity)
  if (inherits(recovery_conn, "error") || is.null(recovery_conn)) {
    warning(
      "MCP reader quarantine could not open an independent recovery session",
      call. = FALSE
    )
    return(invisible(FALSE))
  }
  on.exit(try(disconnect_fn(recovery_conn), silent = TRUE), add = TRUE)
  recovered <- tryCatch(
    {
      quarantine <- mcp_readonly_quarantine_reader(
        recovery_conn,
        query_fn,
        execute_fn,
        quote_account_fn,
        best_effort = TRUE
      )
      isTRUE(attr(quarantine, "quarantine_succeeded", exact = TRUE))
    },
    error = function(e) FALSE
  )
  if (!recovered) {
    warning(
      "MCP reader quarantine failed on the independent recovery session",
      call. = FALSE
    )
  }
  invisible(secret_removed && recovered)
}
