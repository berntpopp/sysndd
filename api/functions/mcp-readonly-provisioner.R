# functions/mcp-readonly-provisioner.R
#
# Pure validation and planning helpers for the privileged MCP reader
# provisioner. Database mutation is intentionally kept in the operator script.

.mcp_readonly_abort <- function(message) {
  stop(message, call. = FALSE)
}

.mcp_readonly_scalar_text <- function(value, label) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
    .mcp_readonly_abort(paste0(label, " must be one nonempty string"))
  }
  if (grepl("[\r\n]", value)) {
    .mcp_readonly_abort(paste0(label, " must not contain a newline"))
  }
  value
}

mcp_readonly_reader_identity <- function() {
  list(user = "sysndd_mcp", host = "%")
}

mcp_readonly_validate_expected_definer <- function(value) {
  value <- .mcp_readonly_scalar_text(value, "expected view definer")
  parts <- strsplit(value, "@", fixed = TRUE)[[1L]]
  if (length(parts) != 2L || !nzchar(parts[[1L]]) || !nzchar(parts[[2L]])) {
    .mcp_readonly_abort("expected view definer must have user@host form")
  }
  value
}

.mcp_readonly_env_value <- function(getenv, name) {
  value <- unname(getenv(name, unset = ""))
  if (!is.character(value) || length(value) != 1L || is.na(value)) "" else value
}

.mcp_readonly_required_env <- function(getenv, name) {
  .mcp_readonly_scalar_text(.mcp_readonly_env_value(getenv, name), name)
}

.mcp_readonly_secret <- function(getenv, value_name, file_name) {
  value <- .mcp_readonly_env_value(getenv, value_name)
  path <- .mcp_readonly_env_value(getenv, file_name)
  supplied <- c(nzchar(value), nzchar(path))
  if (sum(supplied) != 1L) {
    .mcp_readonly_abort(paste0(
      "exactly one of ", value_name, " or ", file_name, " is required"
    ))
  }
  if (nzchar(value)) return(.mcp_readonly_scalar_text(value, value_name))

  path <- .mcp_readonly_scalar_text(path, file_name)
  if (!file.exists(path) || dir.exists(path)) {
    .mcp_readonly_abort(paste0(file_name, " must name a readable file"))
  }
  lines <- readLines(path, warn = FALSE)
  if (length(lines) != 1L) {
    .mcp_readonly_abort(paste0(file_name, " must contain exactly one line"))
  }
  .mcp_readonly_scalar_text(lines[[1L]], file_name)
}

mcp_readonly_admin_config <- function(getenv = Sys.getenv) {
  host <- .mcp_readonly_required_env(getenv, "MCP_ADMIN_DB_HOST")
  dbname <- .mcp_readonly_required_env(getenv, "MCP_ADMIN_DB_NAME")
  user <- .mcp_readonly_required_env(getenv, "MCP_ADMIN_DB_USER")
  port_text <- .mcp_readonly_required_env(getenv, "MCP_ADMIN_DB_PORT")
  if (!grepl("^[0-9]+$", port_text)) {
    .mcp_readonly_abort("MCP_ADMIN_DB_PORT must be an integer")
  }
  port <- suppressWarnings(as.integer(port_text))
  if (is.na(port) || port < 1L || port > 65535L) {
    .mcp_readonly_abort("MCP_ADMIN_DB_PORT must be between 1 and 65535")
  }

  list(
    host = host,
    port = port,
    dbname = dbname,
    user = user,
    password = .mcp_readonly_secret(
      getenv,
      "MCP_ADMIN_DB_PASSWORD",
      "MCP_ADMIN_DB_PASSWORD_FILE"
    ),
    expected_definer = mcp_readonly_validate_expected_definer(
      .mcp_readonly_required_env(getenv, "MCP_EXPECTED_VIEW_DEFINER")
    )
  )
}

mcp_readonly_session_ids <- function(rows) {
  if (!is.data.frame(rows) || !"ID" %in% names(rows)) {
    .mcp_readonly_abort("session rows must contain ID")
  }
  raw <- rows$ID
  if (is.character(raw) && any(!grepl("^[0-9]+$", raw))) {
    .mcp_readonly_abort("session id must be an integer")
  }
  numeric_ids <- suppressWarnings(as.numeric(raw))
  if (anyNA(numeric_ids) || any(numeric_ids != floor(numeric_ids))) {
    .mcp_readonly_abort("session id must be an integer")
  }
  if (any(numeric_ids <= 0)) {
    .mcp_readonly_abort("session id must be positive")
  }
  if (any(numeric_ids > .Machine$integer.max)) {
    .mcp_readonly_abort("session id must be bounded")
  }
  as.integer(numeric_ids)
}

mcp_readonly_reader_variants <- function(rows) {
  required <- c("User", "Host")
  if (!is.data.frame(rows) || !all(required %in% names(rows))) {
    .mcp_readonly_abort("account rows must contain User and Host")
  }
  for (value in c(rows$User, rows$Host)) {
    .mcp_readonly_scalar_text(value, "account identity")
  }
  reader <- mcp_readonly_reader_identity()$user
  selected <- rows[rows$User == reader, required, drop = FALSE]
  if (nrow(selected) == 0L) {
    return(data.frame(user = character(), host = character(), stringsAsFactors = FALSE))
  }
  data.frame(
    user = as.character(selected$User),
    host = as.character(selected$Host),
    stringsAsFactors = FALSE
  )
}

.mcp_readonly_normalize_grant <- function(grant) {
  toupper(gsub("[[:space:]]+", " ", trimws(grant)))
}

mcp_readonly_grants_are_exact <- function(grants, database, projections) {
  if (!is.character(grants) || anyNA(grants)) return(FALSE)
  database <- .mcp_readonly_scalar_text(database, "database")
  if (!is.character(projections) || anyNA(projections) || any(!nzchar(projections))) {
    return(FALSE)
  }
  account <- "`sysndd_mcp`@`%`"
  expected <- c(
    paste("GRANT USAGE ON *.* TO", account),
    paste0(
      "GRANT SELECT ON `", database, "`.`", projections, "` TO ", account
    )
  )
  actual_normalized <- sort(vapply(
    grants,
    .mcp_readonly_normalize_grant,
    character(1)
  ))
  expected_normalized <- sort(vapply(
    expected,
    .mcp_readonly_normalize_grant,
    character(1)
  ))
  identical(actual_normalized, expected_normalized)
}

.mcp_readonly_normalize_sql <- function(sql) {
  if (base::exists("mcp_readonly_normalize_view_sql", mode = "function")) {
    return(base::get("mcp_readonly_normalize_view_sql", mode = "function")(sql))
  }
  sql <- gsub("`", "", as.character(sql), fixed = TRUE)
  tolower(gsub("[[:space:]]+", " ", trimws(sql), perl = TRUE))
}

mcp_readonly_views_are_exact <- function(
    rows,
    expected_definer,
    trusted_definitions,
    canonical_hashes = NULL,
    database = NULL) {
  required <- c("TABLE_NAME", "SECURITY_TYPE", "DEFINER", "VIEW_DEFINITION")
  if (!is.data.frame(rows) || !all(required %in% names(rows))) return(FALSE)
  expected_definer <- mcp_readonly_validate_expected_definer(expected_definer)
  if (!is.character(trusted_definitions) || is.null(names(trusted_definitions))) {
    return(FALSE)
  }
  if (anyDuplicated(rows$TABLE_NAME) ||
      !identical(sort(as.character(rows$TABLE_NAME)), sort(names(trusted_definitions)))) {
    return(FALSE)
  }
  ordered <- rows[match(names(trusted_definitions), rows$TABLE_NAME), , drop = FALSE]
  if (any(toupper(ordered$SECURITY_TYPE) != "DEFINER")) return(FALSE)
  if (any(ordered$DEFINER != expected_definer)) return(FALSE)

  if (is.null(canonical_hashes) && is.null(database)) {
    actual <- vapply(
      ordered$VIEW_DEFINITION,
      .mcp_readonly_normalize_sql,
      character(1)
    )
    expected <- vapply(
      trusted_definitions,
      .mcp_readonly_normalize_sql,
      character(1)
    )
    return(identical(unname(actual), unname(expected)))
  }
  if (!is.character(canonical_hashes) || is.null(names(canonical_hashes)) ||
      !identical(sort(names(canonical_hashes)), sort(names(trusted_definitions))) ||
      !is.character(database) || length(database) != 1L || is.na(database)) {
    return(FALSE)
  }
  actual_hashes <- vapply(
    ordered$VIEW_DEFINITION,
    mcp_readonly_canonical_view_hash,
    character(1),
    schema = database
  )
  identical(unname(actual_hashes), unname(canonical_hashes[names(trusted_definitions)]))
}

mcp_readonly_runtime_is_supported <- function(rows) {
  if (!is.data.frame(rows) || nrow(rows) != 1L ||
      !all(c("database_version", "database_family") %in% names(rows))) {
    return(FALSE)
  }
  version <- as.character(rows$database_version[[1L]])
  family <- as.character(rows$database_family[[1L]])
  !is.na(version) && !is.na(family) &&
    grepl("^8\\.4(?:\\.|$)", version) && grepl("MySQL", family, fixed = TRUE)
}

mcp_readonly_columns_are_exact <- function(rows, expected_columns) {
  required <- c("TABLE_NAME", "COLUMN_NAME", "ORDINAL_POSITION")
  if (!is.data.frame(rows) || !all(required %in% names(rows)) ||
      !is.list(expected_columns) || is.null(names(expected_columns))) {
    return(FALSE)
  }
  if (!setequal(unique(as.character(rows$TABLE_NAME)), names(expected_columns))) {
    return(FALSE)
  }
  actual <- lapply(names(expected_columns), function(view) {
    selected <- rows[rows$TABLE_NAME == view, , drop = FALSE]
    if (anyDuplicated(selected$ORDINAL_POSITION)) return(NULL)
    selected <- selected[order(selected$ORDINAL_POSITION), , drop = FALSE]
    as.character(selected$COLUMN_NAME)
  })
  names(actual) <- names(expected_columns)
  identical(actual, expected_columns)
}

mcp_readonly_dependencies_are_exact <- function(rows, expected_dependencies) {
  required <- c("VIEW_NAME", "TABLE_NAME")
  if (!is.data.frame(rows) || !all(required %in% names(rows)) ||
      !is.list(expected_dependencies) || is.null(names(expected_dependencies))) {
    return(FALSE)
  }
  if (!setequal(unique(as.character(rows$VIEW_NAME)), names(expected_dependencies))) {
    return(FALSE)
  }
  actual <- lapply(names(expected_dependencies), function(view) {
    sort(unique(as.character(rows$TABLE_NAME[rows$VIEW_NAME == view])))
  })
  names(actual) <- names(expected_dependencies)
  expected <- lapply(expected_dependencies, function(value) sort(unique(as.character(value))))
  identical(actual, expected)
}

mcp_readonly_quote_account <- function(conn, user, host) {
  user <- .mcp_readonly_scalar_text(user, "account user")
  host <- .mcp_readonly_scalar_text(host, "account host")
  quoted <- DBI::dbQuoteString(conn, c(user, host))
  paste0(as.character(quoted[[1L]]), "@", as.character(quoted[[2L]]))
}

.mcp_readonly_query <- function(query_fn, conn, sql, params = list()) {
  query_fn(conn, sql, params)
}

.mcp_readonly_execute <- function(execute_fn, conn, sql, params = list()) {
  execute_fn(conn, sql, params)
}

mcp_readonly_reconcile <- function(
    conn,
    database,
    password_output_path,
    expected_definer,
    migration_path,
    serialized = FALSE,
    query_fn = function(conn, sql, params) {
      if (length(params)) DBI::dbGetQuery(conn, sql, params = params) else DBI::dbGetQuery(conn, sql)
    },
    execute_fn = function(conn, sql, params) {
      if (length(params)) DBI::dbExecute(conn, sql, params = params) else DBI::dbExecute(conn, sql)
    },
    quote_account_fn = mcp_readonly_quote_account,
    write_secret_fn = mcp_readonly_write_secret,
    recovery_conn_factory = NULL,
    disconnect_fn = function(conn) DBI::dbDisconnect(conn),
    remove_secret_fn = mcp_readonly_remove_secret,
    canonical_hashes = mcp_readonly_canonical_view_hashes()) {
  if (!isTRUE(serialized)) {
    .mcp_readonly_abort("provisioning requires an explicitly serialized operator run")
  }
  database <- .mcp_readonly_scalar_text(database, "database")
  if (!grepl("^[A-Za-z0-9_]+$", database)) {
    .mcp_readonly_abort("database contains unsupported characters")
  }
  password_output_path <- .mcp_readonly_scalar_text(
    password_output_path,
    "MCP_DB_PASSWORD_OUTPUT_FILE"
  )
  expected_definer <- mcp_readonly_validate_expected_definer(expected_definer)
  trusted <- mcp_readonly_trusted_view_definitions(migration_path)
  completed <- FALSE
  on.exit({
    if (!completed) {
      mcp_readonly_recover_incomplete(
        conn = conn,
        password_output_path = password_output_path,
        query_fn = query_fn,
        execute_fn = execute_fn,
        quote_account_fn = quote_account_fn,
        recovery_conn_factory = recovery_conn_factory,
        disconnect_fn = disconnect_fn,
        remove_secret_fn = remove_secret_fn
      )
    }
  }, add = TRUE)
  variants <- mcp_readonly_quarantine_reader(
    conn, query_fn, execute_fn, quote_account_fn
  )

  mandatory <- .mcp_readonly_query(
    query_fn,
    conn,
    "SELECT @@GLOBAL.mandatory_roles AS mandatory_roles"
  )
  if (nrow(mandatory) != 1L || !"mandatory_roles" %in% names(mandatory) ||
      is.na(mandatory$mandatory_roles[[1L]]) ||
      nzchar(trimws(as.character(mandatory$mandatory_roles[[1L]])))) {
    .mcp_readonly_abort("global mandatory roles must be empty")
  }

  runtime_rows <- .mcp_readonly_query(
    query_fn,
    conn,
    paste(
      "SELECT @@version AS database_version,",
      "@@version_comment AS database_family"
    )
  )
  if (!mcp_readonly_runtime_is_supported(runtime_rows)) {
    .mcp_readonly_abort("MCP projection attestation requires MySQL 8.4")
  }

  view_rows <- .mcp_readonly_query(
    query_fn,
    conn,
    paste(
      "SELECT TABLE_NAME, SECURITY_TYPE, DEFINER, VIEW_DEFINITION",
      "FROM INFORMATION_SCHEMA.VIEWS",
      "WHERE TABLE_SCHEMA = ? AND TABLE_NAME LIKE 'mcp_public_%'",
      "ORDER BY TABLE_NAME"
    ),
    list(database)
  )
  if (!mcp_readonly_views_are_exact(
    view_rows,
    expected_definer,
    trusted,
    canonical_hashes = canonical_hashes,
    database = database
  )) {
    .mcp_readonly_abort("MCP projection view attestation failed")
  }

  column_rows <- .mcp_readonly_query(
    query_fn,
    conn,
    paste(
      "SELECT TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION",
      "FROM INFORMATION_SCHEMA.COLUMNS",
      "WHERE TABLE_SCHEMA = ? AND TABLE_NAME LIKE 'mcp_public_%'",
      "ORDER BY TABLE_NAME, ORDINAL_POSITION"
    ),
    list(database)
  )
  if (!mcp_readonly_columns_are_exact(
    column_rows,
    mcp_readonly_projection_columns()
  )) {
    .mcp_readonly_abort("MCP projection column attestation failed")
  }

  dependency_rows <- .mcp_readonly_query(
    query_fn,
    conn,
    paste(
      "SELECT VIEW_NAME, TABLE_NAME",
      "FROM INFORMATION_SCHEMA.VIEW_TABLE_USAGE",
      "WHERE VIEW_SCHEMA = ? AND VIEW_NAME LIKE 'mcp_public_%'",
      "ORDER BY VIEW_NAME, TABLE_NAME"
    ),
    list(database)
  )
  if (!mcp_readonly_dependencies_are_exact(
    dependency_rows,
    mcp_readonly_projection_dependencies()
  )) {
    .mcp_readonly_abort("MCP projection dependency attestation failed")
  }

  reader <- mcp_readonly_reader_identity()
  reader_account <- quote_account_fn(conn, reader$user, reader$host)
  if (nrow(variants)) {
    for (index in seq_len(nrow(variants))) {
      prior_account <- quote_account_fn(
        conn, variants$user[[index]], variants$host[[index]]
      )
      .mcp_readonly_execute(
        execute_fn,
        conn,
        paste("DROP USER", prior_account)
      )
    }
  }

  password_sql <- paste(
    "CREATE USER", reader_account,
    "IDENTIFIED BY RANDOM PASSWORD ACCOUNT LOCK"
  )
  generated_rows <- .mcp_readonly_query(
    query_fn,
    conn,
    password_sql
  )
  generated_password <- mcp_readonly_generated_password(generated_rows)

  projections <- mcp_readonly_projection_names()
  for (projection in projections) {
    grant_sql <- paste0(
      "GRANT SELECT ON `", database, "`.`", projection, "` TO ",
      reader_account
    )
    .mcp_readonly_execute(execute_fn, conn, grant_sql)
  }

  grant_rows <- .mcp_readonly_query(
    query_fn,
    conn,
    paste("SHOW GRANTS FOR", reader_account)
  )
  grants <- if (is.data.frame(grant_rows) && ncol(grant_rows) == 1L) {
    grant_rows[[1L]]
  } else {
    character()
  }
  if (!mcp_readonly_grants_are_exact(grants, database, projections)) {
    .mcp_readonly_abort("MCP reader grant attestation failed")
  }

  final_roles <- .mcp_readonly_query(
    query_fn,
    conn,
    paste(
      "SELECT FROM_USER, FROM_HOST, TO_USER, TO_HOST FROM mysql.role_edges",
      "WHERE TO_USER = ? OR FROM_USER = ?",
      "ORDER BY FROM_USER, FROM_HOST, TO_USER, TO_HOST"
    ),
    list(reader$user, reader$user)
  )
  final_proxies <- .mcp_readonly_query(
    query_fn,
    conn,
    paste(
      "SELECT Host, User, Proxied_host, Proxied_user FROM mysql.proxies_priv",
      "WHERE User = ? OR Proxied_user = ?",
      "ORDER BY User, Host, Proxied_user, Proxied_host"
    ),
    list(reader$user, reader$user)
  )
  quarantined_session_ids <- attr(
    variants, "quarantined_session_ids", exact = TRUE
  )
  if (is.null(quarantined_session_ids)) quarantined_session_ids <- integer()
  session_id_placeholders <- paste(
    rep("?", length(quarantined_session_ids)), collapse = ", "
  )
  session_id_predicate <- if (length(quarantined_session_ids)) {
    paste("OR ID IN (", session_id_placeholders, ")")
  } else {
    ""
  }
  final_sessions <- .mcp_readonly_query(
    query_fn,
    conn,
    paste(
      "SELECT ID FROM INFORMATION_SCHEMA.PROCESSLIST",
      paste("WHERE (USER = ?", session_id_predicate, ")"),
      "ORDER BY ID"
    ),
    c(list(reader$user), as.list(quarantined_session_ids))
  )
  if (nrow(final_roles) || nrow(final_proxies) || nrow(final_sessions)) {
    .mcp_readonly_abort("MCP reader retained role, proxy, or session authority")
  }

  write_secret_fn(password_output_path, generated_password)

  .mcp_readonly_execute(
    execute_fn, conn, paste("ALTER USER", reader_account, "ACCOUNT UNLOCK")
  )
  completed <- TRUE

  invisible(TRUE)
}
