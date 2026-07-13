# functions/mcp-readonly-provisioner-quarantine.R
#
# Atomic initial lock and best-effort failure compensation for the MCP reader.

.mcp_quarantine_call <- function(
    operation, best_effort, fallback = NULL, state = NULL) {
  if (!best_effort) return(operation())
  tryCatch(operation(), error = function(e) {
    if (!is.null(state)) state$failed <- TRUE
    fallback
  })
}

mcp_readonly_quarantine_reader <- function(
    conn,
    query_fn,
    execute_fn,
    quote_account_fn,
    best_effort = FALSE) {
  state <- new.env(parent = emptyenv())
  state$failed <- FALSE
  reader <- mcp_readonly_reader_identity()
  account_rows <- .mcp_quarantine_call(
    function() {
      query_fn(
        conn,
        "SELECT User, Host FROM mysql.user WHERE User = ? ORDER BY Host",
        list(reader$user)
      )
    },
    best_effort,
    data.frame(User = reader$user, Host = reader$host),
    state
  )
  if (!is.data.frame(account_rows) || !all(c("User", "Host") %in% names(account_rows))) {
    account_rows <- .mcp_quarantine_call(
      function() .mcp_readonly_abort("account rows must contain User and Host"),
      best_effort,
      data.frame(User = reader$user, Host = reader$host),
      state
    )
  }
  account_candidates <- list()
  if (nrow(account_rows)) {
    for (index in seq_len(nrow(account_rows))) {
      candidate <- .mcp_quarantine_call(
        function() {
          user <- mcp_readonly_validate_account_user(account_rows$User[[index]])
          host <- mcp_readonly_validate_account_host(account_rows$Host[[index]])
          if (!identical(user, reader$user)) return(NULL)
          list(user = user, host = host, quoted = quote_account_fn(conn, user, host))
        },
        best_effort,
        NULL,
        state
      )
      if (!is.null(candidate)) account_candidates[[length(account_candidates) + 1L]] <- candidate
    }
  }
  if (best_effort && !any(vapply(
    account_candidates,
    function(value) identical(value$user, reader$user) && identical(value$host, reader$host),
    logical(1)
  ))) {
    account_candidates[[length(account_candidates) + 1L]] <- list(
      user = reader$user,
      host = reader$host,
      quoted = quote_account_fn(conn, reader$user, reader$host)
    )
  }
  variants <- data.frame(
    user = vapply(account_candidates, `[[`, character(1), "user"),
    host = vapply(account_candidates, `[[`, character(1), "host"),
    stringsAsFactors = FALSE
  )
  accounts <- vapply(account_candidates, `[[`, character(1), "quoted")

  if (length(accounts)) {
    lock_groups <- if (best_effort) as.list(accounts) else list(accounts)
    for (account_group in lock_groups) {
      lock_sql <- paste(
        "ALTER USER", paste(account_group, collapse = ", "), "ACCOUNT LOCK"
      )
      .mcp_quarantine_call(
        function() execute_fn(conn, lock_sql, list()), best_effort, NULL, state
      )
    }
  }

  role_rows <- .mcp_quarantine_call(
    function() {
      query_fn(
        conn,
        paste(
          "SELECT FROM_USER, FROM_HOST, TO_USER, TO_HOST FROM mysql.role_edges",
          "WHERE TO_USER = ? OR FROM_USER = ?",
          "ORDER BY FROM_USER, FROM_HOST, TO_USER, TO_HOST"
        ),
        list(reader$user, reader$user)
      )
    },
    best_effort,
    data.frame(),
    state
  )
  if (nrow(role_rows)) {
    for (index in seq_len(nrow(role_rows))) {
      .mcp_quarantine_call(
        function() {
          role <- quote_account_fn(
            conn, role_rows$FROM_USER[[index]], role_rows$FROM_HOST[[index]]
          )
          target <- quote_account_fn(
            conn, role_rows$TO_USER[[index]], role_rows$TO_HOST[[index]]
          )
          execute_fn(conn, paste("REVOKE", role, "FROM", target), list())
        },
        best_effort,
        NULL,
        state
      )
    }
  }

  proxy_rows <- .mcp_quarantine_call(
    function() {
      query_fn(
        conn,
        paste(
          "SELECT Host, User, Proxied_host, Proxied_user FROM mysql.proxies_priv",
          "WHERE User = ? OR Proxied_user = ?",
          "ORDER BY User, Host, Proxied_user, Proxied_host"
        ),
        list(reader$user, reader$user)
      )
    },
    best_effort,
    data.frame(),
    state
  )
  reverse_proxy_accounts <- character()
  if (nrow(proxy_rows)) {
    for (index in seq_len(nrow(proxy_rows))) {
      reverse_account <- .mcp_quarantine_call(
        function() {
          proxied_user <- mcp_readonly_validate_account_user(
            proxy_rows$Proxied_user[[index]]
          )
          proxy <- quote_account_fn(
            conn, proxied_user, proxy_rows$Proxied_host[[index]]
          )
          target <- quote_account_fn(
            conn, proxy_rows$User[[index]], proxy_rows$Host[[index]]
          )
          execute_fn(
            conn, paste("REVOKE PROXY ON", proxy, "FROM", target), list()
          )
          if (identical(proxied_user, reader$user)) target else NULL
        },
        best_effort,
        NULL,
        state
      )
      if (!is.null(reverse_account)) {
        reverse_proxy_accounts <- c(reverse_proxy_accounts, reverse_account)
      }
    }
  }
  reverse_proxy_accounts <- unique(reverse_proxy_accounts)

  proxy_placeholders <- paste(rep("?", length(reverse_proxy_accounts)), collapse = ", ")
  proxy_predicate <- if (length(reverse_proxy_accounts)) {
    paste("OR pv.VARIABLE_VALUE IN (", proxy_placeholders, ")")
  } else {
    ""
  }
  session_rows <- .mcp_quarantine_call(
    function() {
      query_fn(
        conn,
        paste(
          "SELECT DISTINCT t.PROCESSLIST_ID AS ID",
          "FROM performance_schema.threads AS t",
          "LEFT JOIN performance_schema.variables_by_thread AS pv",
          "ON pv.THREAD_ID = t.THREAD_ID",
          "AND pv.VARIABLE_NAME = 'proxy_user'",
          "WHERE t.PROCESSLIST_ID IS NOT NULL",
          paste("AND (t.PROCESSLIST_USER = ?", proxy_predicate, ")"),
          "ORDER BY ID"
        ),
        c(list(reader$user), as.list(reverse_proxy_accounts))
      )
    },
    best_effort,
    data.frame(ID = integer()),
    state
  )
  if (best_effort && is.data.frame(session_rows) && "ID" %in% names(session_rows)) {
    session_ids <- integer()
    for (index in seq_len(nrow(session_rows))) {
      session_id <- .mcp_quarantine_call(
        function() mcp_readonly_session_ids(session_rows[index, , drop = FALSE]),
        TRUE,
        integer(),
        state
      )
      session_ids <- c(session_ids, session_id)
    }
  } else {
    session_ids <- .mcp_quarantine_call(
      function() mcp_readonly_session_ids(session_rows),
      best_effort,
      integer(),
      state
    )
  }
  for (session_id in session_ids) {
    .mcp_quarantine_call(
      function() execute_fn(conn, paste("KILL", session_id), list()),
      best_effort,
      NULL,
      state
    )
  }

  for (account in accounts) {
    .mcp_quarantine_call(
      function() {
        execute_fn(
          conn,
          paste("REVOKE ALL PRIVILEGES, GRANT OPTION FROM", account),
          list()
        )
      },
      best_effort,
      NULL,
      state
    )
  }
  attr(variants, "quarantined_session_ids") <- session_ids
  attr(variants, "quarantine_succeeded") <- !state$failed
  variants
}
