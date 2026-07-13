config_path <- file.path(get_api_dir(), "functions", "mcp-readonly-config.R")
pool_path <- file.path(get_api_dir(), "bootstrap", "create_mcp_pool.R")
attestation_path <- file.path(get_api_dir(), "functions", "mcp-readonly-attestation.R")

.mcp_test_password_file <- tempfile("mcp-config-password-")
writeChar("unit-test-secret", .mcp_test_password_file, eos = NULL, useBytes = TRUE)
Sys.chmod(.mcp_test_password_file, mode = "0600", use_umask = FALSE)

load_sut <- function(path) {
  env <- new.env(parent = baseenv())
  loaded <- file.exists(path)
  if (loaded) source(path, local = env)
  list(loaded = loaded, env = env)
}

valid_mcp_env <- function(...) {
  values <- c(
    MCP_DB_HOST = "mysql",
    MCP_DB_PORT = "3306",
    MCP_DB_NAME = "sysndd_db",
    MCP_DB_USER = "sysndd_mcp",
    MCP_DB_PASSWORD = NA_character_,
    MCP_DB_PASSWORD_FILE = .mcp_test_password_file,
    MCP_DB_POOL_SIZE = "2",
    ...
  )
  values[!duplicated(names(values), fromLast = TRUE)]
}

with_mcp_env <- function(values, code) {
  all_names <- c(
    "MCP_DB_HOST", "MCP_DB_PORT", "MCP_DB_NAME", "MCP_DB_USER",
    "MCP_DB_PASSWORD", "MCP_DB_PASSWORD_FILE", "MCP_DB_POOL_SIZE",
    "MYSQL_HOST", "MYSQL_PORT", "MYSQL_DATABASE", "MYSQL_USER", "MYSQL_PASSWORD"
  )
  environment <- stats::setNames(rep(NA_character_, length(all_names)), all_names)
  environment[names(values)] <- values
  withr::with_envvar(environment, code)
}

expect_config_loaded <- function(sut) {
  expect_true(sut$loaded, info = "mcp-readonly-config.R must exist")
  if (!sut$loaded) return(FALSE)
  expect_true(
    base::exists("mcp_readonly_config", envir = sut$env, mode = "function", inherits = FALSE)
  )
}

test_that("MCP configuration accepts only complete dedicated environment input", {
  sut <- load_sut(config_path)
  if (!expect_config_loaded(sut)) return(invisible(NULL))

  config <- with_mcp_env(valid_mcp_env(), sut$env$mcp_readonly_config())

  expect_identical(config$host, "mysql")
  expect_identical(config$port, 3306L)
  expect_identical(config$dbname, "sysndd_db")
  expect_identical(config$user, "sysndd_mcp")
  expect_identical(config$password, "unit-test-secret")
  expect_identical(config$pool_size, 2L)
  expect_false(any(grepl("MYSQL|API_CONFIG|config.yml", names(config))))
})

test_that("ordinary API credentials and config files never satisfy MCP", {
  sut <- load_sut(config_path)
  if (!expect_config_loaded(sut)) return(invisible(NULL))

  api_env <- c(
    MYSQL_HOST = "mysql", MYSQL_PORT = "3306", MYSQL_DATABASE = "sysndd_db",
    MYSQL_USER = "api-user", MYSQL_PASSWORD = "api-secret"
  )
  withr::local_dir(withr::local_tempdir(pattern = "mcp-config-"))
  writeLines("default:\n  user: api-user\n  password: api-secret", "config.yml")

  expect_error(
    with_mcp_env(api_env, sut$env$mcp_readonly_config()),
    class = "mcp_config_error"
  )
})

test_that("MCP identity, connection fields, port and pool bounds fail closed", {
  sut <- load_sut(config_path)
  if (!expect_config_loaded(sut)) return(invisible(NULL))

  invalid <- list(
    c(MCP_DB_HOST = ""),
    c(MCP_DB_HOST = "mysql\nother"),
    c(MCP_DB_PORT = "0"),
    c(MCP_DB_PORT = "65536"),
    c(MCP_DB_PORT = "3306x"),
    c(MCP_DB_NAME = ""),
    c(MCP_DB_USER = "bernt"),
    c(MCP_DB_USER = "sysndd_mcp@%"),
    c(MCP_DB_POOL_SIZE = "0"),
    c(MCP_DB_POOL_SIZE = "6"),
    c(MCP_DB_POOL_SIZE = "2.5")
  )

  for (override in invalid) {
    expect_error(
      with_mcp_env(do.call(valid_mcp_env, as.list(override)), sut$env$mcp_readonly_config()),
      class = "mcp_config_error"
    )
  }
})

test_that("MCP password uses only the secure file source", {
  sut <- load_sut(config_path)
  if (!expect_config_loaded(sut)) return(invisible(NULL))

  secret_path <- tempfile("mcp-password-")
  writeChar("file-secret", secret_path, eos = NULL, useBytes = TRUE)
  Sys.chmod(secret_path, mode = "0600")
  on.exit(unlink(secret_path), add = TRUE)

  file_config <- with_mcp_env(
    valid_mcp_env(MCP_DB_PASSWORD = NA_character_, MCP_DB_PASSWORD_FILE = secret_path),
    sut$env$mcp_readonly_config()
  )
  expect_identical(file_config$password, "file-secret")

  expect_error(
    with_mcp_env(
      valid_mcp_env(
        MCP_DB_PASSWORD = "direct-secret",
        MCP_DB_PASSWORD_FILE = NA_character_
      ),
      sut$env$mcp_readonly_config()
    ),
    class = "mcp_config_error"
  )

  Sys.chmod(secret_path, mode = "0644")
  expect_error(
    with_mcp_env(
      valid_mcp_env(MCP_DB_PASSWORD = NA_character_, MCP_DB_PASSWORD_FILE = secret_path),
      sut$env$mcp_readonly_config()
    ),
    class = "mcp_config_error"
  )
})

test_that("configuration remains correct when get and exists are masked", {
  sut <- load_sut(config_path)
  if (!expect_config_loaded(sut)) return(invisible(NULL))

  sut$env$get <- function(...) stop("masked get called")
  sut$env$exists <- function(...) stop("masked exists called")

  expect_silent(with_mcp_env(valid_mcp_env(), sut$env$mcp_readonly_config()))
  source_text <- paste(readLines(config_path, warn = FALSE), collapse = "\n")
  expect_false(grepl("(?<!base::)\\b(get|exists)\\s*\\(", source_text, perl = TRUE))
})

test_that("dedicated MCP pool uses the validated bounded size", {
  sut <- load_sut(pool_path)
  expect_true(sut$loaded, info = "create_mcp_pool.R must exist")
  if (!sut$loaded) return(invisible(NULL))

  captured <- NULL
  factory <- function(...) {
    captured <<- list(...)
    structure(list(), class = "test_pool")
  }
  config <- list(
    host = "mysql", port = 3306L, dbname = "sysndd_db",
    user = "sysndd_mcp", password = "unit-test-secret", pool_size = 3L
  )

  pool <- sut$env$bootstrap_create_mcp_pool(config, pool_factory = factory, driver = "driver")

  expect_s3_class(pool, "test_pool")
  expect_identical(captured$host, "mysql")
  expect_identical(captured$port, 3306L)
  expect_identical(captured$dbname, "sysndd_db")
  expect_identical(captured$user, "sysndd_mcp")
  expect_identical(captured$password, "unit-test-secret")
  expect_identical(captured$minSize, 1L)
  expect_identical(captured$maxSize, 3L)
})

attestation_query <- function(overrides = list()) {
  force(overrides)
  queries <- character()
  query <- function(conn, sql) {
    queries <<- c(queries, sql)
    if (grepl("SHOW GRANTS", sql, fixed = TRUE)) {
      grants <- overrides$grants %||% c(
        "GRANT USAGE ON *.* TO `sysndd_mcp`@`%`",
        "GRANT SELECT ON `sysndd_db`.`mcp_public_gene` TO `sysndd_mcp`@`%`",
        "GRANT SELECT ON `sysndd_db`.`mcp_public_review` TO `sysndd_mcp`@`%`"
      )
      return(stats::setNames(data.frame(grants, check.names = FALSE), "Grants for sysndd_mcp@%"))
    }
    if (grepl("CURRENT_USER", sql, fixed = TRUE)) {
      return(data.frame(
        mcp_current_user = overrides$current_user %||% "sysndd_mcp@%",
        mcp_current_role = overrides$current_role %||% "NONE",
        mcp_mandatory_roles = overrides$mandatory_roles %||% "",
        check.names = FALSE
      ))
    }
    if (!is.null(overrides$projection_error) &&
        grepl(overrides$projection_error, sql, fixed = TRUE)) {
      stop("projection denied")
    }
    data.frame()
  }
  list(query = query, queries = function() queries)
}

expect_attestation_loaded <- function(sut) {
  expect_true(sut$loaded, info = "mcp-readonly-attestation.R must exist")
  if (!sut$loaded) return(FALSE)
  expect_true(
    base::exists("mcp_readonly_attest", envir = sut$env, mode = "function", inherits = FALSE)
  )
}

test_that("startup attestation accepts only fixed identity, no roles and exact grants", {
  sut <- load_sut(attestation_path)
  if (!expect_attestation_loaded(sut)) return(invisible(NULL))
  stub <- attestation_query()

  expect_true(sut$env$mcp_readonly_attest(
    conn = structure(list(), class = "test_connection"),
    dbname = "sysndd_db",
    projection_names = c("mcp_public_gene", "mcp_public_review"),
    query_fn = stub$query
  ))

  queries <- stub$queries()
  expect_true(any(grepl("CURRENT_USER", queries, fixed = TRUE)))
  expect_true(any(grepl("CURRENT_ROLE", queries, fixed = TRUE)))
  expect_true(any(grepl("mandatory_roles", queries, fixed = TRUE)))
  expect_true(any(grepl("AS mcp_current_user", queries, fixed = TRUE)))
  expect_true(any(grepl("SHOW GRANTS", queries, fixed = TRUE)))
})

test_that("startup attestation rejects wrong identity, roles and missing or extra grants", {
  sut <- load_sut(attestation_path)
  if (!expect_attestation_loaded(sut)) return(invisible(NULL))

  cases <- list(
    list(current_user = "bernt@%"),
    list(current_user = "sysndd_mcp@localhost"),
    list(current_role = "reader_role@%"),
    list(mandatory_roles = "reader_role@%"),
    list(grants = c(
      "GRANT USAGE ON *.* TO `sysndd_mcp`@`%`",
      "GRANT SELECT ON `sysndd_db`.`mcp_public_gene` TO `sysndd_mcp`@`%`"
    )),
    list(grants = c(
      "GRANT USAGE ON *.* TO `sysndd_mcp`@`%`",
      "GRANT SELECT ON `sysndd_db`.`mcp_public_gene` TO `sysndd_mcp`@`%`",
      "GRANT SELECT ON `sysndd_db`.`mcp_public_review` TO `sysndd_mcp`@`%`",
      "GRANT SELECT ON `sysndd_db`.* TO `sysndd_mcp`@`%`"
    )),
    list(grants = c(
      "GRANT USAGE ON *.* TO `sysndd_mcp`@`%`",
      "GRANT SELECT, INSERT ON `sysndd_db`.`mcp_public_gene` TO `sysndd_mcp`@`%`",
      "GRANT SELECT ON `sysndd_db`.`mcp_public_review` TO `sysndd_mcp`@`%`"
    ))
  )

  for (case in cases) {
    expect_error(
      sut$env$mcp_readonly_attest(
        conn = structure(list(), class = "test_connection"),
        dbname = "sysndd_db",
        projection_names = c("mcp_public_gene", "mcp_public_review"),
        query_fn = attestation_query(case)$query
      ),
      class = "mcp_attestation_error"
    )
  }
})

test_that("startup attestation probes every approved projection", {
  sut <- load_sut(attestation_path)
  if (!expect_attestation_loaded(sut)) return(invisible(NULL))
  stub <- attestation_query()

  sut$env$mcp_readonly_attest(
    conn = structure(list(), class = "test_connection"),
    dbname = "sysndd_db",
    projection_names = c("mcp_public_gene", "mcp_public_review"),
    query_fn = stub$query
  )

  probes <- grep("LIMIT 0", stub$queries(), value = TRUE, fixed = TRUE)
  expect_length(probes, 2L)
  expect_true(any(grepl("`sysndd_db`.`mcp_public_gene`", probes, fixed = TRUE)))
  expect_true(any(grepl("`sysndd_db`.`mcp_public_review`", probes, fixed = TRUE)))

  denied <- attestation_query(list(projection_error = "mcp_public_review"))
  expect_error(
    sut$env$mcp_readonly_attest(
      conn = structure(list(), class = "test_connection"),
      dbname = "sysndd_db",
      projection_names = c("mcp_public_gene", "mcp_public_review"),
      query_fn = denied$query
    ),
    class = "mcp_attestation_error"
  )
})

test_that("MCP startup configures and attests before opening the listener", {
  script_path <- file.path(get_api_dir(), "start_sysndd_mcp.R")
  script <- paste(readLines(script_path, warn = FALSE), collapse = "\n")

  expect_match(script, 'source\\("functions/mcp-readonly-config.R"')
  expect_match(script, 'source\\("bootstrap/create_mcp_pool.R"')
  expect_match(script, 'source\\("functions/mcp-readonly-attestation.R"')
  expect_match(script, 'base::get\\("mcp_readonly_config"')
  expect_match(script, 'base::get\\("bootstrap_create_mcp_pool"')
  expect_match(script, 'base::get\\("mcp_readonly_attest"')
  expect_lt(regexpr("mcp_readonly_attest", script)[1], regexpr("mcp_server", script)[1])
  expect_false(grepl("config::get|API_CONFIG|bootstrap_create_pool|init_cache|bootstrap_bind_memoised", script))
  expect_match(script, "base::get")
  expect_match(script, "base::exists")
})
