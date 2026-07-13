# functions/mcp-readonly-provisioner-quarantine.R
#
# Atomic initial lock and best-effort failure compensation for the MCP reader.

.mcp_quarantine_call <- function(operation, best_effort, fallback = NULL) {
  if (!best_effort) return(operation())
  tryCatch(operation(), error = function(e) fallback)
}

mcp_readonly_quarantine_reader <- function(
    conn,
    query_fn,
    execute_fn,
    quote_account_fn,
    best_effort = FALSE) {
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
    data.frame(User = reader$user, Host = reader$host)
  )
  variants <- .mcp_quarantine_call(
    function() mcp_readonly_reader_variants(account_rows),
    best_effort,
    data.frame(user = reader$user, host = reader$host)
  )
  accounts <- mapply(
    function(user, host) quote_account_fn(conn, user, host),
    variants$user,
    variants$host,
    USE.NAMES = FALSE
  )

  if (length(accounts)) {
    lock_sql <- paste(
      "ALTER USER",
      paste(accounts, collapse = ", "),
      "ACCOUNT LOCK"
    )
    .mcp_quarantine_call(
      function() execute_fn(conn, lock_sql, list()),
      best_effort
    )
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
    data.frame()
  )
  if (nrow(role_rows)) {
    for (index in seq_len(nrow(role_rows))) {
      role <- quote_account_fn(
        conn, role_rows$FROM_USER[[index]], role_rows$FROM_HOST[[index]]
      )
      target <- quote_account_fn(
        conn, role_rows$TO_USER[[index]], role_rows$TO_HOST[[index]]
      )
      .mcp_quarantine_call(
        function() {
          execute_fn(conn, paste("REVOKE", role, "FROM", target), list())
        },
        best_effort
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
    data.frame()
  )
  reverse_proxy_accounts <- character()
  if (nrow(proxy_rows)) {
    for (index in seq_len(nrow(proxy_rows))) {
      proxy <- quote_account_fn(
        conn, proxy_rows$Proxied_user[[index]], proxy_rows$Proxied_host[[index]]
      )
      target <- quote_account_fn(
        conn, proxy_rows$User[[index]], proxy_rows$Host[[index]]
      )
      if (identical(as.character(proxy_rows$Proxied_user[[index]]), reader$user)) {
        reverse_proxy_accounts <- c(reverse_proxy_accounts, target)
      }
      .mcp_quarantine_call(
        function() {
          execute_fn(
            conn, paste("REVOKE PROXY ON", proxy, "FROM", target), list()
          )
        },
        best_effort
      )
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
    data.frame(ID = integer())
  )
  session_ids <- .mcp_quarantine_call(
    function() mcp_readonly_session_ids(session_rows),
    best_effort,
    integer()
  )
  for (session_id in session_ids) {
    .mcp_quarantine_call(
      function() execute_fn(conn, paste("KILL", session_id), list()),
      best_effort
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
      best_effort
    )
  }
  attr(variants, "quarantined_session_ids") <- session_ids
  variants
}
