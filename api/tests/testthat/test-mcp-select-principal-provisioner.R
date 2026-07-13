# tests/testthat/test-mcp-select-principal-provisioner.R

library(testthat)

source_api_file("functions/mcp-readonly-provisioner.R", local = FALSE)
source_api_file("functions/mcp-readonly-provisioner-quarantine.R", local = FALSE)
source_api_file("functions/mcp-readonly-provisioner-recovery.R", local = FALSE)
source_api_file("functions/mcp-readonly-provisioner-secret.R", local = FALSE)
source_api_file("functions/mcp-readonly-contract.R", local = FALSE)

.provisioner_env <- function(values) {
  force(values)
  function(name, unset = "") {
    if (name %in% names(values)) values[[name]] else unset
  }
}

test_that("the reader and expected definer identities fail closed", {
  expect_identical(
    mcp_readonly_reader_identity(),
    list(user = "sysndd_mcp", host = "%")
  )

  expect_identical(
    mcp_readonly_validate_expected_definer("schema_migrator@%"),
    "schema_migrator@%"
  )
  expect_error(mcp_readonly_validate_expected_definer(""), "expected view definer")
  expect_error(mcp_readonly_validate_expected_definer("missing-host"), "user@host")
  expect_error(mcp_readonly_validate_expected_definer("root@localhost\nextra"), "newline")
  expect_error(mcp_readonly_validate_expected_definer("@%"), "user@host")
})

test_that("session ids are bounded positive integers", {
  expect_identical(
    mcp_readonly_session_ids(data.frame(ID = c(7, 19))),
    c(7L, 19L)
  )
  expect_error(
    mcp_readonly_session_ids(data.frame(ID = c(0, 2))),
    "positive"
  )
  expect_error(
    mcp_readonly_session_ids(data.frame(ID = 2147483648)),
    "bounded"
  )
  expect_error(
    mcp_readonly_session_ids(data.frame(ID = "1; DROP USER")),
    "integer"
  )
})

test_that("account variants are normalized without weakening host matching", {
  variants <- data.frame(
    User = c("sysndd_mcp", "sysndd_mcp", "other"),
    Host = c("%", "localhost", "%"),
    account_locked = c("N", "Y", "N"),
    stringsAsFactors = FALSE
  )

  expect_identical(
    mcp_readonly_reader_variants(variants),
    data.frame(
      user = c("sysndd_mcp", "sysndd_mcp"),
      host = c("%", "localhost"),
      stringsAsFactors = FALSE
    )
  )
  expect_error(
    mcp_readonly_reader_variants(
      data.frame(User = "sysndd_mcp\n", Host = "%")
    ),
    "newline"
  )
})

test_that("generated password results require the fixed reader identity", {
  result <- data.frame(
    user = "sysndd_mcp",
    host = "%",
    `generated password` = "server-generated-secret",
    auth_factor = 1L,
    check.names = FALSE
  )
  expect_identical(
    mcp_readonly_generated_password(result),
    "server-generated-secret"
  )
  result$host <- "localhost"
  expect_error(mcp_readonly_generated_password(result), "fixed reader")
  result$host <- "%"
  result$auth_factor <- 2L
  expect_error(mcp_readonly_generated_password(result), "factor")
})

test_that("generated password is atomically persisted as an owner-only secret", {
  directory <- tempfile("mcp-secret-dir-")
  dir.create(directory, mode = "0700")
  withr::defer(unlink(directory, recursive = TRUE))
  path <- file.path(directory, "reader-password")

  expect_error(
    mcp_readonly_write_secret("relative/reader-password", "server-generated-secret"),
    "absolute"
  )

  expect_identical(
    mcp_readonly_write_secret(path, "server-generated-secret"),
    normalizePath(path)
  )
  expect_identical(readChar(path, file.info(path)$size), "server-generated-secret")
  expect_identical(
    bitwAnd(as.integer(file.info(path)$mode), as.integer(as.octmode("077"))),
    0L
  )

  unlink(path)
  file.symlink("missing-target", path)
  expect_error(
    mcp_readonly_write_secret(path, "replacement-secret"),
    "symbolic link"
  )
})

test_that("grant attestation rejects every authority outside exact view SELECT", {
  projections <- c("mcp_public_gene", "mcp_public_entity")
  exact <- c(
    "GRANT USAGE ON *.* TO `sysndd_mcp`@`%`",
    "GRANT SELECT ON `sysndd_db`.`mcp_public_gene` TO `sysndd_mcp`@`%`",
    "GRANT SELECT ON `sysndd_db`.`mcp_public_entity` TO `sysndd_mcp`@`%`"
  )

  expect_true(mcp_readonly_grants_are_exact(exact, "sysndd_db", projections))
  expect_false(mcp_readonly_grants_are_exact(
    c(exact, "GRANT SELECT ON `sysndd_db`.* TO `sysndd_mcp`@`%`"),
    "sysndd_db",
    projections
  ))
  expect_false(mcp_readonly_grants_are_exact(
    c(exact, "GRANT INSERT ON `sysndd_db`.`mcp_public_gene` TO `sysndd_mcp`@`%`"),
    "sysndd_db",
    projections
  ))
  expect_false(mcp_readonly_grants_are_exact(
    c(exact, "GRANT PROXY ON ''@'' TO `sysndd_mcp`@`%`"),
    "sysndd_db",
    projections
  ))
  grant_option <- exact
  grant_option[[2L]] <- paste(grant_option[[2L]], "WITH GRANT OPTION")
  expect_false(mcp_readonly_grants_are_exact(
    grant_option,
    "sysndd_db",
    projections
  ))
  wrong_grantee <- exact
  wrong_grantee[[2L]] <- sub("`sysndd_mcp`@`%`", "`api_user`@`%`", wrong_grantee[[2L]], fixed = TRUE)
  expect_false(mcp_readonly_grants_are_exact(
    wrong_grantee,
    "sysndd_db",
    projections
  ))
})

test_that("administrator configuration has no ordinary database fallback", {
  values <- c(
    MCP_ADMIN_DB_HOST = "db-admin.internal",
    MCP_ADMIN_DB_PORT = "3307",
    MCP_ADMIN_DB_NAME = "sysndd_db",
    MCP_ADMIN_DB_USER = "security_operator",
    MCP_ADMIN_DB_PASSWORD = "operator-secret",
    MCP_EXPECTED_VIEW_DEFINER = "schema_migrator@%",
    MYSQL_USER = "must-not-be-used",
    MYSQL_PASSWORD = "must-not-be-used"
  )
  config <- mcp_readonly_admin_config(getenv = .provisioner_env(values))

  expect_identical(config$host, "db-admin.internal")
  expect_identical(config$port, 3307L)
  expect_identical(config$dbname, "sysndd_db")
  expect_identical(config$user, "security_operator")
  expect_identical(config$password, "operator-secret")
  expect_identical(config$expected_definer, "schema_migrator@%")

  expect_error(
    mcp_readonly_admin_config(getenv = .provisioner_env(values[FALSE])),
    "MCP_ADMIN_DB_HOST"
  )
})

test_that("administrator secret environment and file inputs are exclusive", {
  base <- c(
    MCP_ADMIN_DB_HOST = "mysql",
    MCP_ADMIN_DB_PORT = "3306",
    MCP_ADMIN_DB_NAME = "sysndd_db",
    MCP_ADMIN_DB_USER = "root",
    MCP_EXPECTED_VIEW_DEFINER = "schema_migrator@%"
  )
  secret <- tempfile()
  writeLines("file-secret", secret, useBytes = TRUE)
  withr::defer(unlink(secret))

  file_config <- mcp_readonly_admin_config(
    getenv = .provisioner_env(c(base, MCP_ADMIN_DB_PASSWORD_FILE = secret))
  )
  expect_identical(file_config$password, "file-secret")

  expect_error(
    mcp_readonly_admin_config(getenv = .provisioner_env(c(
      base,
      MCP_ADMIN_DB_PASSWORD = "env-secret",
      MCP_ADMIN_DB_PASSWORD_FILE = secret
    ))),
    "exactly one"
  )
})

test_that("stored projection definitions require the trusted query and definer", {
  trusted <- c(
    mcp_public_gene = "select hgnc_id from non_alt_loci_set",
    mcp_public_entity = "select entity_id from ndd_entity"
  )
  rows <- data.frame(
    TABLE_NAME = names(trusted),
    SECURITY_TYPE = c("DEFINER", "DEFINER"),
    DEFINER = c("schema_migrator@%", "schema_migrator@%"),
    VIEW_DEFINITION = unname(trusted),
    stringsAsFactors = FALSE
  )
  canonical_hashes <- vapply(
    trusted,
    mcp_readonly_canonical_view_hash,
    character(1),
    schema = "sysndd_db"
  )

  expect_true(mcp_readonly_views_are_exact(
    rows,
    expected_definer = "schema_migrator@%",
    trusted_definitions = trusted,
    canonical_hashes = canonical_hashes,
    database = "sysndd_db"
  ))

  wrong_query <- rows
  wrong_query$VIEW_DEFINITION[[1L]] <- "select hgnc_id from private_gene"
  expect_false(mcp_readonly_views_are_exact(
    wrong_query,
    expected_definer = "schema_migrator@%",
    trusted_definitions = trusted,
    canonical_hashes = canonical_hashes,
    database = "sysndd_db"
  ))

  wrong_definer <- rows
  wrong_definer$DEFINER[[1L]] <- "root@localhost"
  expect_false(mcp_readonly_views_are_exact(
    wrong_definer,
    expected_definer = "schema_migrator@%",
    trusted_definitions = trusted,
    canonical_hashes = canonical_hashes,
    database = "sysndd_db"
  ))

  canonical_rows <- rows
  canonical_rows$VIEW_DEFINITION <- c(
    "select hgnc_id from sysndd_db.non_alt_loci_set",
    "select entity_id from sysndd_db.ndd_entity"
  )
  installed_hashes <- vapply(
    canonical_rows$VIEW_DEFINITION,
    mcp_readonly_canonical_view_hash,
    character(1),
    schema = "sysndd_db"
  )
  names(installed_hashes) <- canonical_rows$TABLE_NAME
  expect_true(mcp_readonly_views_are_exact(
    canonical_rows,
    expected_definer = "schema_migrator@%",
    trusted_definitions = trusted,
    canonical_hashes = installed_hashes,
    database = "sysndd_db"
  ))
})

test_that("canonical hashes retain predicate grouping", {
  original <- "SELECT x FROM t WHERE a = 1 AND (b = 1 OR c = 1)"
  regrouped <- "SELECT x FROM t WHERE (a = 1 AND b = 1) OR c = 1"
  expect_false(identical(
    mcp_readonly_canonical_view_hash(original, "sysndd_db"),
    mcp_readonly_canonical_view_hash(regrouped, "sysndd_db")
  ))
})

test_that("stored projection columns and dependencies require exact order and set", {
  columns <- list(
    mcp_public_gene = c("hgnc_id", "symbol"),
    mcp_public_entity = "entity_id"
  )
  column_rows <- data.frame(
    TABLE_NAME = c("mcp_public_gene", "mcp_public_gene", "mcp_public_entity"),
    COLUMN_NAME = c("hgnc_id", "symbol", "entity_id"),
    ORDINAL_POSITION = c(1L, 2L, 1L),
    stringsAsFactors = FALSE
  )
  expect_true(mcp_readonly_columns_are_exact(column_rows, columns))
  expect_false(mcp_readonly_columns_are_exact(column_rows[-2L, ], columns))

  dependencies <- list(
    mcp_public_gene = "non_alt_loci_set",
    mcp_public_entity = c("ndd_entity", "mcp_public_gene")
  )
  dependency_rows <- data.frame(
    VIEW_NAME = c(
      "mcp_public_gene", "mcp_public_entity", "mcp_public_entity"
    ),
    TABLE_NAME = c("non_alt_loci_set", "ndd_entity", "mcp_public_gene"),
    stringsAsFactors = FALSE
  )
  expect_true(mcp_readonly_dependencies_are_exact(dependency_rows, dependencies))
  expect_false(mcp_readonly_dependencies_are_exact(
    rbind(dependency_rows, c("mcp_public_gene", "private_gene")),
    dependencies
  ))
})

test_that("failed view attestation leaves the reader quarantined", {
  migration <- file.path(
    get_api_dir(), "..", "db", "migrations",
    "044_mcp_public_read_projections.sql"
  )
  trusted <- mcp_readonly_trusted_view_definitions(migration)
  executed <- character()

  query_fn <- function(conn, sql, params = list()) {
    if (grepl("FROM mysql.user", sql, fixed = TRUE)) {
      return(data.frame(User = "sysndd_mcp", Host = "%"))
    }
    if (grepl("PROCESSLIST", sql, fixed = TRUE)) {
      return(data.frame(ID = integer()))
    }
    if (grepl("mysql.role_edges", sql, fixed = TRUE)) {
      return(data.frame(
        FROM_USER = character(), FROM_HOST = character(),
        TO_USER = character(), TO_HOST = character()
      ))
    }
    if (grepl("mysql.proxies_priv", sql, fixed = TRUE)) {
      return(data.frame(
        Host = character(), User = character(),
        Proxied_host = character(), Proxied_user = character()
      ))
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
        TABLE_NAME = names(trusted),
        SECURITY_TYPE = "DEFINER",
        DEFINER = "wrong_definer@%",
        VIEW_DEFINITION = unname(trusted),
        stringsAsFactors = FALSE
      ))
    }
    stop("unexpected query: ", sql)
  }
  execute_fn <- function(conn, sql, params = list()) {
    executed <<- c(executed, sql)
    0L
  }

  expect_error(
    mcp_readonly_reconcile(
      conn = NULL,
      database = "sysndd_db",
      password_output_path = "/secure/reader-password",
      expected_definer = "schema_migrator@%",
      migration_path = migration,
      serialized = TRUE,
      query_fn = query_fn,
      execute_fn = execute_fn,
      quote_account_fn = function(conn, user, host) {
        paste0("'", user, "'@'", host, "'")
      },
      write_secret_fn = function(path, password) path
    ),
    "view attestation"
  )
  expect_gte(sum(grepl("ACCOUNT LOCK", executed, fixed = TRUE)), 2L)
  expect_gte(sum(grepl("REVOKE ALL PRIVILEGES", executed, fixed = TRUE)), 2L)
  expect_false(any(grepl("ACCOUNT UNLOCK", executed, fixed = TRUE)))
  expect_false(any(grepl("password-sentinel", executed, fixed = TRUE)))
})

test_that("successful reconciliation grants exact views before final unlock", {
  migration <- file.path(
    get_api_dir(), "..", "db", "migrations",
    "044_mcp_public_read_projections.sql"
  )
  trusted <- mcp_readonly_trusted_view_definitions(migration)
  columns <- mcp_readonly_projection_columns()
  dependencies <- mcp_readonly_projection_dependencies()
  executed <- list()
  queried <- character()
  written <- list()
  query_counts <- new.env(parent = emptyenv())
  query_counts$roles <- 0L
  query_counts$proxies <- 0L
  query_counts$sessions <- 0L

  empty_roles <- function() data.frame(
    FROM_USER = character(), FROM_HOST = character(),
    TO_USER = character(), TO_HOST = character()
  )
  empty_proxies <- function() data.frame(
    Host = character(), User = character(),
    Proxied_host = character(), Proxied_user = character()
  )
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

  query_fn <- function(conn, sql, params = list()) {
    queried <<- c(queried, sql)
    if (grepl("FROM mysql.user", sql, fixed = TRUE)) {
      return(data.frame(
        User = c("sysndd_mcp", "sysndd_mcp"),
        Host = c("%", "localhost")
      ))
    }
    if (grepl("PROCESSLIST", sql, fixed = TRUE)) {
      query_counts$sessions <- query_counts$sessions + 1L
      if (query_counts$sessions == 1L) return(data.frame(ID = 11L))
      return(data.frame(ID = integer()))
    }
    if (grepl("mysql.role_edges", sql, fixed = TRUE)) {
      query_counts$roles <- query_counts$roles + 1L
      if (query_counts$roles == 1L) {
        return(data.frame(
          FROM_USER = "hostile_role", FROM_HOST = "%",
          TO_USER = "sysndd_mcp", TO_HOST = "%"
        ))
      }
      return(empty_roles())
    }
    if (grepl("mysql.proxies_priv", sql, fixed = TRUE)) {
      query_counts$proxies <- query_counts$proxies + 1L
      if (query_counts$proxies == 1L) {
        return(data.frame(
          Host = "%", User = "sysndd_mcp",
          Proxied_host = "%", Proxied_user = "root"
        ))
      }
      return(empty_proxies())
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
        TABLE_NAME = names(trusted), SECURITY_TYPE = "DEFINER",
        DEFINER = "schema_migrator@%", VIEW_DEFINITION = unname(trusted),
        stringsAsFactors = FALSE
      ))
    }
    if (grepl("INFORMATION_SCHEMA.COLUMNS", sql, fixed = TRUE)) {
      return(column_rows)
    }
    if (grepl("INFORMATION_SCHEMA.VIEW_TABLE_USAGE", sql, fixed = TRUE)) {
      return(dependency_rows)
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
          "GRANT SELECT ON `sysndd_db`.`", names(trusted),
          "` TO `sysndd_mcp`@`%`"
        )
      )
      return(data.frame(grant = grants))
    }
    stop("unexpected query: ", sql)
  }
  execute_fn <- function(conn, sql, params = list()) {
    executed[[length(executed) + 1L]] <<- list(sql = sql, params = params)
    0L
  }
  quote_fn <- function(conn, user, host) paste0("'", user, "'@'", host, "'")
  write_secret_fn <- function(path, password) {
    written$path <<- path
    written$password <<- password
    path
  }

  expect_true(mcp_readonly_reconcile(
    conn = NULL,
    database = "sysndd_db",
    password_output_path = "/secure/reader-password",
    expected_definer = "schema_migrator@%",
    migration_path = migration,
    serialized = TRUE,
    query_fn = query_fn,
    execute_fn = execute_fn,
    quote_account_fn = quote_fn,
    write_secret_fn = write_secret_fn,
    canonical_hashes = vapply(
      trusted,
      mcp_readonly_canonical_view_hash,
      character(1),
      schema = "sysndd_db"
    )
  ))

  sql <- vapply(executed, `[[`, character(1), "sql")
  expect_identical(sum(grepl("ACCOUNT LOCK", sql, fixed = TRUE)), 1L)
  lock_steps <- sql[
    grepl("^ALTER USER", sql) & grepl("ACCOUNT LOCK", sql, fixed = TRUE)
  ]
  expect_identical(
    lock_steps,
    paste(
      "ALTER USER 'sysndd_mcp'@'%',",
      "'sysndd_mcp'@'localhost' ACCOUNT LOCK"
    )
  )
  random_steps <- queried[grepl("IDENTIFIED BY RANDOM PASSWORD", queried, fixed = TRUE)]
  expect_length(random_steps, 1L)
  expect_true(startsWith(random_steps, "CREATE USER"))
  expect_false(grepl("?", random_steps, fixed = TRUE))
  expect_identical(written$path, "/secure/reader-password")
  expect_identical(written$password, "server-generated-secret")
  expect_false(any(grepl("server-generated-secret", c(sql, queried), fixed = TRUE)))
  expect_true(any(grepl("DROP USER 'sysndd_mcp'@'%'", sql, fixed = TRUE)))
  expect_true(any(grepl("DROP USER 'sysndd_mcp'@'localhost'", sql, fixed = TRUE)))
  expect_identical(sum(grepl("^GRANT SELECT ON", sql)), 23L)
  expect_match(tail(sql, 1L), "ACCOUNT UNLOCK", fixed = TRUE)
  expect_gt(which(grepl("ACCOUNT UNLOCK", sql, fixed = TRUE)), max(which(
    grepl("^GRANT SELECT ON", sql)
  )))
})

test_that("operator provisioner accepts secrets only through environment injection", {
  script <- file.path(
    get_api_dir(), "scripts", "provision-mcp-readonly-principal.R"
  )
  expect_true(file.exists(script))
  text <- paste(readLines(script, warn = FALSE), collapse = "\n")

  expect_match(text, "MCP_PROVISION_SERIALIZED", fixed = TRUE)
  expect_match(text, "mcp_readonly_admin_config", fixed = TRUE)
  expect_match(text, "MCP_DB_PASSWORD_OUTPUT_FILE", fixed = TRUE)
  expect_match(text, "startsWith(password_output_path, \"/\")", fixed = TRUE)
  expect_match(text, "mcp_readonly_reconcile", fixed = TRUE)
  expect_false(grepl("mcp_readonly_config", text, fixed = TRUE))
  expect_false(grepl("reader_password|IDENTIFIED BY \\?", text))
  expect_false(grepl("commandArgs|system2|system\\(", text))
  expect_false(grepl("MYSQL_PASSWORD|MYSQL_ROOT_PASSWORD", text, fixed = TRUE))
})
