# tests/testthat/test-mcp-select-principal-proxy-quarantine.R

library(testthat)

source_api_file("functions/mcp-readonly-provisioner.R", local = FALSE)
source_api_file("functions/mcp-readonly-provisioner-quarantine.R", local = FALSE)
source_api_file("functions/mcp-readonly-provisioner-recovery.R", local = FALSE)
source_api_file("functions/mcp-readonly-provisioner-secret.R", local = FALSE)
source_api_file("functions/mcp-readonly-contract.R", local = FALSE)

.proxy_test_quote <- function(conn, user, host) {
  paste0("'", user, "'@'", host, "'")
}

test_that("quarantine revokes both PROXY directions before killing sessions", {
  executed <- character()
  proxy_query <- NULL
  session_query <- NULL

  query_fn <- function(conn, sql, params = list()) {
    if (grepl("FROM mysql.user", sql, fixed = TRUE)) {
      return(data.frame(User = "sysndd_mcp", Host = "%"))
    }
    if (grepl("mysql.role_edges", sql, fixed = TRUE)) return(data.frame())
    if (grepl("mysql.proxies_priv", sql, fixed = TRUE)) {
      proxy_query <<- list(sql = sql, params = params)
      return(data.frame(
        Host = c("%", "%"),
        User = c("sysndd_mcp", "reverse_proxy"),
        Proxied_host = c("%", "%"),
        Proxied_user = c("root", "sysndd_mcp"),
        stringsAsFactors = FALSE
      ))
    }
    if (grepl("PROCESSLIST_ID", sql, fixed = TRUE)) {
      session_query <<- list(sql = sql, params = params)
      expect_true(any(startsWith(executed, "REVOKE PROXY ON")))
      return(data.frame(ID = c(41L, 42L)))
    }
    stop("unexpected query: ", sql)
  }
  execute_fn <- function(conn, sql, params = list()) {
    executed <<- c(executed, sql)
    0L
  }

  variants <- mcp_readonly_quarantine_reader(
    conn = NULL,
    query_fn = query_fn,
    execute_fn = execute_fn,
    quote_account_fn = .proxy_test_quote
  )

  expect_match(proxy_query$sql, "User = ? OR Proxied_user = ?", fixed = TRUE)
  expect_identical(proxy_query$params, list("sysndd_mcp", "sysndd_mcp"))
  expect_true(grepl("performance_schema.variables_by_thread", session_query$sql, fixed = TRUE))
  expect_true(grepl("VARIABLE_NAME = 'proxy_user'", session_query$sql, fixed = TRUE))
  expect_identical(
    session_query$params,
    list("sysndd_mcp", "'reverse_proxy'@'%'")
  )
  expect_true(any(executed == "REVOKE PROXY ON 'root'@'%' FROM 'sysndd_mcp'@'%'"))
  expect_true(any(executed == "REVOKE PROXY ON 'sysndd_mcp'@'%' FROM 'reverse_proxy'@'%'"))
  expect_true(any(executed == "KILL 41"))
  expect_true(any(executed == "KILL 42"))
  expect_identical(attr(variants, "quarantined_session_ids", exact = TRUE), c(41L, 42L))
})

test_that("quarantine revokes role edges in both reader directions", {
  executed <- character()
  role_query <- NULL
  query_fn <- function(conn, sql, params = list()) {
    if (grepl("FROM mysql.user", sql, fixed = TRUE)) {
      return(data.frame(User = "sysndd_mcp", Host = "%"))
    }
    if (grepl("mysql.role_edges", sql, fixed = TRUE)) {
      role_query <<- list(sql = sql, params = params)
      return(data.frame(
        FROM_USER = c("hostile_role", "sysndd_mcp"),
        FROM_HOST = c("%", "%"),
        TO_USER = c("sysndd_mcp", "role_consumer"),
        TO_HOST = c("%", "%"),
        stringsAsFactors = FALSE
      ))
    }
    if (grepl("mysql.proxies_priv", sql, fixed = TRUE)) return(data.frame())
    if (grepl("PROCESSLIST_ID", sql, fixed = TRUE)) {
      return(data.frame(ID = integer()))
    }
    stop("unexpected query")
  }
  execute_fn <- function(conn, sql, params = list()) {
    executed <<- c(executed, sql)
    0L
  }

  mcp_readonly_quarantine_reader(
    NULL, query_fn, execute_fn, .proxy_test_quote
  )

  expect_match(role_query$sql, "TO_USER = ? OR FROM_USER = ?", fixed = TRUE)
  expect_identical(role_query$params, list("sysndd_mcp", "sysndd_mcp"))
  expect_true(any(executed == "REVOKE 'hostile_role'@'%' FROM 'sysndd_mcp'@'%'"))
  expect_true(any(executed == "REVOKE 'sysndd_mcp'@'%' FROM 'role_consumer'@'%'"))
})

test_that("best-effort quarantine isolates malformed and hostile catalog rows", {
  executed <- character()
  session_query <- NULL
  query_fn <- function(conn, sql, params = list()) {
    if (grepl("FROM mysql.user", sql, fixed = TRUE)) {
      return(data.frame(
        User = I(list("sysndd_mcp", "sysndd_mcp", "sysndd_mcp")),
        Host = I(list("%", 7, "local'host"))
      ))
    }
    if (grepl("mysql.role_edges", sql, fixed = TRUE)) {
      return(data.frame(
        FROM_USER = I(list(7, "safe'role")),
        FROM_HOST = I(list("%", "%")),
        TO_USER = I(list("sysndd_mcp", "sysndd_mcp")),
        TO_HOST = I(list("%", "%"))
      ))
    }
    if (grepl("mysql.proxies_priv", sql, fixed = TRUE)) {
      return(data.frame(
        Host = I(list("%", "proxy'host")),
        User = I(list(7, "safe'proxy")),
        Proxied_host = I(list("%", "%")),
        Proxied_user = I(list("sysndd_mcp", "sysndd_mcp"))
      ))
    }
    if (grepl("PROCESSLIST_ID", sql, fixed = TRUE)) {
      session_query <<- list(sql = sql, params = params)
      return(data.frame(ID = I(list("not-an-id", "42"))))
    }
    stop("unexpected query: ", sql)
  }
  execute_fn <- function(conn, sql, params = list()) {
    executed <<- c(executed, sql)
    0L
  }

  variants <- expect_silent(mcp_readonly_quarantine_reader(
    conn = DBI::ANSI(),
    query_fn = query_fn,
    execute_fn = execute_fn,
    quote_account_fn = mcp_readonly_quote_account,
    best_effort = TRUE
  ))

  expect_true(any(executed == "ALTER USER 'sysndd_mcp'@'local''host' ACCOUNT LOCK"))
  expect_true(any(executed == "REVOKE 'safe''role'@'%' FROM 'sysndd_mcp'@'%'"))
  expect_true(any(executed == paste(
    "REVOKE PROXY ON 'sysndd_mcp'@'%'",
    "FROM 'safe''proxy'@'proxy''host'"
  )))
  expect_true(any(executed == "KILL 42"))
  expect_true(any(executed == paste(
    "REVOKE ALL PRIVILEGES, GRANT OPTION FROM",
    "'sysndd_mcp'@'local''host'"
  )))
  expect_identical(
    session_query$params,
    list("sysndd_mcp", "'safe''proxy'@'proxy''host'")
  )
  expect_false(isTRUE(attr(variants, "quarantine_succeeded", exact = TRUE)))
  expect_identical(attr(variants, "quarantined_session_ids", exact = TRUE), 42L)
})

.proxy_reconcile_fixture <- function() {
  migration <- file.path(
    get_api_dir(), "..", "db", "migrations",
    "044_mcp_public_read_projections.sql"
  )
  trusted <- mcp_readonly_trusted_view_definitions(migration)
  columns <- mcp_readonly_projection_columns()
  dependencies <- mcp_readonly_projection_dependencies()
  column_rows <- do.call(rbind, lapply(names(columns), function(view) {
    data.frame(
      TABLE_NAME = view,
      COLUMN_NAME = columns[[view]],
      ORDINAL_POSITION = seq_along(columns[[view]]),
      stringsAsFactors = FALSE
    )
  }))
  dependency_rows <- do.call(rbind, lapply(names(dependencies), function(view) {
    data.frame(
      VIEW_NAME = view,
      TABLE_NAME = dependencies[[view]],
      stringsAsFactors = FALSE
    )
  }))
  list(
    migration = migration,
    trusted = trusted,
    columns = column_rows,
    dependencies = dependency_rows
  )
}

test_that("final attestation rejects reverse PROXY and surviving killed sessions", {
  fixture <- .proxy_reconcile_fixture()
  counts <- new.env(parent = emptyenv())
  counts$proxies <- 0L
  counts$sessions <- 0L

  query_fn <- function(conn, sql, params = list()) {
    if (grepl("FROM mysql.user", sql, fixed = TRUE)) {
      return(data.frame(User = "sysndd_mcp", Host = "%"))
    }
    if (grepl("mysql.role_edges", sql, fixed = TRUE)) {
      return(data.frame(
        FROM_USER = character(), FROM_HOST = character(),
        TO_USER = character(), TO_HOST = character()
      ))
    }
    if (grepl("mysql.proxies_priv", sql, fixed = TRUE)) {
      counts$proxies <- counts$proxies + 1L
      if (!grepl("User = ? OR Proxied_user = ?", sql, fixed = TRUE) ||
          !identical(params, list("sysndd_mcp", "sysndd_mcp"))) {
        stop("proxy attestation omitted the reverse direction")
      }
      row <- data.frame(
        Host = "%", User = "reverse_proxy",
        Proxied_host = "%", Proxied_user = "sysndd_mcp",
        stringsAsFactors = FALSE
      )
      if (counts$proxies == 1L) return(row)
      return(row)
    }
    if (grepl("PROCESSLIST_ID", sql, fixed = TRUE)) {
      counts$sessions <- counts$sessions + 1L
      return(data.frame(ID = 77L))
    }
    if (grepl("PROCESSLIST", sql, fixed = TRUE)) {
      counts$sessions <- counts$sessions + 1L
      if (!grepl("ID IN", sql, fixed = TRUE) || !77L %in% unlist(params)) {
        stop("session attestation omitted a previously killed proxy session")
      }
      return(data.frame(ID = 77L))
    }
    if (grepl("mandatory_roles", sql, fixed = TRUE)) {
      return(data.frame(mandatory_roles = ""))
    }
    if (grepl("database_version", sql, fixed = TRUE)) {
      return(data.frame(
        database_version = "8.4.10",
        database_family = "MySQL Community Server - GPL"
      ))
    }
    if (grepl("INFORMATION_SCHEMA.VIEWS", sql, fixed = TRUE)) {
      return(data.frame(
        TABLE_NAME = names(fixture$trusted), SECURITY_TYPE = "DEFINER",
        DEFINER = "schema_migrator@%",
        VIEW_DEFINITION = unname(fixture$trusted),
        stringsAsFactors = FALSE
      ))
    }
    if (grepl("INFORMATION_SCHEMA.COLUMNS", sql, fixed = TRUE)) {
      return(fixture$columns)
    }
    if (grepl("INFORMATION_SCHEMA.VIEW_TABLE_USAGE", sql, fixed = TRUE)) {
      return(fixture$dependencies)
    }
    if (grepl("IDENTIFIED BY RANDOM PASSWORD", sql, fixed = TRUE)) {
      return(data.frame(
        user = "sysndd_mcp", host = "%",
        `generated password` = "server-generated-secret", auth_factor = 1L,
        check.names = FALSE
      ))
    }
    if (grepl("SHOW GRANTS", sql, fixed = TRUE)) {
      grants <- c(
        "GRANT USAGE ON *.* TO `sysndd_mcp`@`%`",
        paste0(
          "GRANT SELECT ON `sysndd_db`.`", names(fixture$trusted),
          "` TO `sysndd_mcp`@`%`"
        )
      )
      return(data.frame(grant = grants))
    }
    stop("unexpected query: ", sql)
  }

  expect_error(
    mcp_readonly_reconcile(
      conn = NULL,
      database = "sysndd_db",
      password_output_path = "/secure/reader-password",
      expected_definer = "schema_migrator@%",
      migration_path = fixture$migration,
      serialized = TRUE,
      query_fn = query_fn,
      execute_fn = function(conn, sql, params = list()) 0L,
      quote_account_fn = .proxy_test_quote,
      write_secret_fn = function(path, password) path,
      canonical_hashes = vapply(
        fixture$trusted,
        mcp_readonly_canonical_view_hash,
        character(1),
        schema = "sysndd_db"
      )
    ),
    "retained role, proxy, or session authority"
  )
  expect_gte(counts$proxies, 2L)
  expect_gte(counts$sessions, 2L)
})

test_that("live verifier exercises an authenticated reverse-PROXY session", {
  script <- file.path(
    get_api_dir(), "scripts", "verify-mcp-select-principal-live.R"
  )
  text <- paste(readLines(script, warn = FALSE), collapse = "\n")

  expect_match(text, "SET GLOBAL check_proxy_users = ON", fixed = TRUE)
  expect_match(text, "SET GLOBAL sha256_password_proxy_users = ON", fixed = TRUE)
  expect_match(text, "CREATE USER 'mcp_reverse_proxy'@'%'", fixed = TRUE)
  expect_match(
    text,
    "GRANT PROXY ON 'sysndd_mcp'@'%' TO 'mcp_reverse_proxy'@'%'",
    fixed = TRUE
  )
  expect_match(text, "CURRENT_USER() AS effective_identity", fixed = TRUE)
  expect_match(text, "reverse PROXY session survived reconciliation", fixed = TRUE)
  direct_connect <- regexpr(
    "reader_connect(primary[[\"generated password\"]][[1]])",
    text,
    fixed = TRUE
  )[[1L]]
  forward_grant <- regexpr(
    "GRANT PROXY ON 'root'@'%' TO 'sysndd_mcp'@'%'",
    text,
    fixed = TRUE
  )[[1L]]
  reverse_grant <- regexpr(
    "GRANT PROXY ON 'sysndd_mcp'@'%' TO 'mcp_reverse_proxy'@'%'",
    text,
    fixed = TRUE
  )[[1L]]
  reverse_connect <- regexpr(
    "reverse_proxy_connect(reverse[[\"generated password\"]][[1]])",
    text,
    fixed = TRUE
  )[[1L]]
  expect_gt(direct_connect, 0L)
  expect_lt(direct_connect, forward_grant)
  expect_gt(reverse_connect, reverse_grant)
  expect_lt(reverse_connect, forward_grant)
})
