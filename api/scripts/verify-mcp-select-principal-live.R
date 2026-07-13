#!/usr/bin/env Rscript
# Disposable end-to-end proof for #552. The success phrase intentionally lives
# here for the static guard; only Make prints "MCP SELECT-only live verification PASS"
# after label-checked cleanup.

required <- c("DBI", "RMariaDB", "httr2", "jsonlite", "digest")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Verifier image is missing required packages", call. = FALSE)
`%||%` <- function(x, y) if (is.null(x)) y else x

source("functions/migration-manifest.R", local = FALSE)
source("functions/migration-runner.R", local = FALSE)
source("functions/mcp-readonly-config.R", local = FALSE)
source("functions/mcp-readonly-contract.R", local = FALSE)
source("functions/mcp-readonly-provisioner-secret.R", local = FALSE)
source("functions/mcp-readonly-provisioner-quarantine.R", local = FALSE)
source("functions/mcp-readonly-provisioner.R", local = FALSE)
source("functions/mcp-readonly-provisioner-recovery.R", local = FALSE)
source("functions/analysis-snapshot-presets.R", local = FALSE)
source("scripts/verify-mcp-select-principal-fixtures.R", local = FALSE)

phase <- Sys.getenv("MCP_VERIFY_PHASE", unset = "")
if (!phase %in% c("bootstrap", "verify")) stop("Unknown verifier phase", call. = FALSE)
verify_id <- Sys.getenv("MCP_VERIFY_ID", unset = "")
if (!grepl("^[a-f0-9]{32}$", verify_id)) stop("Invalid verification id", call. = FALSE)

required_env <- function(name) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value) || grepl("[\r\n]", value)) stop("Missing verifier input", call. = FALSE)
  value
}

admin_connect <- function(config = mcp_readonly_admin_config()) {
  DBI::dbConnect(
    RMariaDB::MariaDB(),
    host = config$host,
    port = config$port,
    dbname = config$dbname,
    user = config$user,
    password = config$password
  )
}

reader_connect <- function(password = NULL) {
  if (is.null(password)) {
    path <- required_env("MCP_DB_PASSWORD_FILE")
    password <- readChar(path, file.info(path)$size)
  }
  DBI::dbConnect(
    RMariaDB::MariaDB(),
    host = required_env("MCP_DB_HOST"),
    port = as.integer(required_env("MCP_DB_PORT")),
    dbname = required_env("MCP_DB_NAME"),
    user = "sysndd_mcp",
    password = password
  )
}

reverse_proxy_connect <- function(password) {
  DBI::dbConnect(
    RMariaDB::MariaDB(),
    host = required_env("MCP_DB_HOST"),
    port = as.integer(required_env("MCP_DB_PORT")),
    dbname = required_env("MCP_DB_NAME"),
    user = "mcp_reverse_proxy",
    password = password
  )
}

expect_error_matching <- function(code, pattern, label) {
  error <- tryCatch({
    force(code)
    NULL
  }, error = identity)
  if (is.null(error)) {
    stop(paste("Expected failure was not observed:", label), call. = FALSE)
  }
  if (!grepl(pattern, conditionMessage(error), ignore.case = TRUE)) {
    stop(
      paste("Unexpected failure for", label, "-", conditionMessage(error)),
      call. = FALSE
    )
  }
  invisible(error)
}

expect_reader_login_denied <- function(password, label) {
  connection <- NULL
  error <- tryCatch({
    connection <- reader_connect(password)
    NULL
  }, error = identity)
  on.exit(if (!is.null(connection)) DBI::dbDisconnect(connection), add = TRUE)
  if (is.null(error)) stop(paste("Obsolete credential still authenticated:", label), call. = FALSE)
  if (!grepl("access denied|authentication", conditionMessage(error), ignore.case = TRUE)) {
    stop(paste("Unexpected login failure for", label), call. = FALSE)
  }
  invisible(error)
}

apply_projection_migration <- function(conn) {
  migration <- required_env("MCP_MIGRATION_PATH")
  statements <- split_sql_statements(paste(readLines(migration, warn = FALSE), collapse = "\n"))
  for (statement in statements) DBI::dbExecute(conn, statement, immediate = TRUE)
}

projection_statement <- function(view) {
  sql <- paste(readLines(required_env("MCP_MIGRATION_PATH"), warn = FALSE), collapse = "\n")
  statements <- split_sql_statements(sql)
  selected <- statements[grepl(paste0("VIEW `", view, "` AS"), statements, fixed = TRUE)]
  if (length(selected) != 1L) stop("Could not isolate projection fixture", call. = FALSE)
  selected[[1]]
}

reconcile <- function(conn, expected_definer, execute_fn = mcp_verify_exec) {
  mcp_readonly_reconcile(
    conn = conn,
    database = required_env("MCP_DB_NAME"),
    password_output_path = required_env("MCP_DB_PASSWORD_OUTPUT_FILE"),
    expected_definer = expected_definer,
    migration_path = required_env("MCP_MIGRATION_PATH"),
    serialized = TRUE,
    query_fn = mcp_verify_query,
    execute_fn = execute_fn,
    recovery_conn_factory = admin_connect
  )
}

seed_hostile_authority <- function(
    conn,
    open_direct_session = FALSE,
    open_reverse_session = FALSE) {
  mcp_verify_exec(conn, "DROP USER IF EXISTS 'mcp_reverse_proxy'@'%'")
  mcp_verify_exec(conn, "DROP USER IF EXISTS 'sysndd_mcp'@'localhost'")
  mcp_verify_exec(conn, "DROP USER IF EXISTS 'sysndd_mcp'@'%'")
  mcp_verify_exec(conn, "DROP ROLE IF EXISTS 'mcp_hostile_role'@'%'")
  mcp_verify_exec(conn, "CREATE ROLE 'mcp_hostile_role'@'%'")
  invisible(mcp_verify_query(conn, "CREATE USER 'sysndd_mcp'@'localhost' IDENTIFIED BY RANDOM PASSWORD"))
  secondary <- mcp_verify_query(conn, "CREATE USER 'sysndd_mcp'@'%' IDENTIFIED BY RANDOM PASSWORD")
  primary <- mcp_verify_query(
    conn,
    paste(
      "ALTER USER 'sysndd_mcp'@'%' IDENTIFIED BY RANDOM PASSWORD",
      "RETAIN CURRENT PASSWORD"
    )
  )
  reverse <- mcp_verify_query(
    conn,
    paste(
      "CREATE USER 'mcp_reverse_proxy'@'%'",
      "IDENTIFIED WITH sha256_password BY RANDOM PASSWORD"
    )
  )
  valid_generated <- function(rows) nrow(rows) == 1L && "generated password" %in% names(rows)
  if (!valid_generated(primary) || !valid_generated(secondary) ||
      !valid_generated(reverse)) {
    stop("MySQL did not return the ephemeral hostile-session secret", call. = FALSE)
  }
  mcp_verify_exec(conn, "GRANT SELECT, INSERT, UPDATE, DELETE ON sysndd_verify.* TO 'sysndd_mcp'@'%'")
  mcp_verify_exec(conn, "GRANT SELECT ON sysndd_verify.ndd_entity_review TO 'mcp_hostile_role'@'%'")
  mcp_verify_exec(conn, "GRANT 'mcp_hostile_role'@'%' TO 'sysndd_mcp'@'%'")
  mcp_verify_exec(conn, "SET DEFAULT ROLE 'mcp_hostile_role'@'%' TO 'sysndd_mcp'@'%'")
  direct_session <- if (isTRUE(open_direct_session)) {
    reader_connect(primary[["generated password"]][[1]])
  } else {
    NULL
  }
  mcp_verify_exec(
    conn,
    "GRANT PROXY ON 'sysndd_mcp'@'%' TO 'mcp_reverse_proxy'@'%'"
  )
  reverse_session <- if (isTRUE(open_reverse_session)) {
    reverse_proxy_connect(reverse[["generated password"]][[1]])
  } else {
    NULL
  }
  mcp_verify_exec(conn, "GRANT PROXY ON 'root'@'%' TO 'sysndd_mcp'@'%'")
  # The reconciler must revoke both PROXY directions before the final surface.
  list(
    primary = primary[["generated password"]][[1]],
    secondary = secondary[["generated password"]][[1]],
    reverse = reverse[["generated password"]][[1]],
    direct_session = direct_session,
    reverse_session = reverse_session
  )
}

run_bootstrap <- function() {
  conn <- admin_connect()
  on.exit(DBI::dbDisconnect(conn), add = TRUE)
  mcp_verify_exec(conn, "SET GLOBAL check_proxy_users = ON")
  mcp_verify_exec(conn, "SET GLOBAL sha256_password_proxy_users = ON")
  result <- run_migrations(
    migrations_dir = required_env("MCP_MIGRATIONS_DIR"),
    conn = conn,
    verbose = TRUE
  )
  if (result$total_applied != EXPECTED_MIGRATION_COUNT) {
    stop("Normal migration bootstrap did not apply 000-044", call. = FALSE)
  }
  expected_definer <- mcp_verify_query(conn, "SELECT CURRENT_USER() AS identity")$identity[[1]]
  if (!grepl("^[^@]+@[^@]+$", expected_definer)) stop("Invalid migrator identity", call. = FALSE)
  mcp_verify_seed_core(conn)
  mcp_verify_seed_analysis(conn)

  hostile_passwords <- seed_hostile_authority(conn, open_direct_session = TRUE)
  live_session <- hostile_passwords$direct_session
  on.exit(try(DBI::dbDisconnect(live_session), silent = TRUE), add = TRUE)
  mcp_verify_exec(conn, "SET GLOBAL mandatory_roles = '`mcp_hostile_role`@`%`'")
  on.exit(try(mcp_verify_exec(conn, "SET GLOBAL mandatory_roles = ''"), silent = TRUE), add = TRUE)
  expect_error_matching(
    reconcile(conn, expected_definer),
    "mandatory role|can't be revoked",
    "mandatory-role fixture"
  )
  mcp_verify_exec(conn, "SET GLOBAL mandatory_roles = ''")

  seed_hostile_authority(conn)
  malicious <- paste(
    "CREATE OR REPLACE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY DEFINER",
    "VIEW mcp_public_gene AS SELECT hgnc_id,symbol,name,omim_id,ensembl_gene_id,",
    "uniprot_ids,STRING_id,mgd_id,rgd_id,mane_select,alphafold_id",
    "FROM non_alt_loci_set WHERE status IN ('Approved','Withdrawn')"
  )
  mcp_verify_exec(conn, malicious)
  expect_error_matching(
    reconcile(conn, expected_definer),
    "view attestation",
    "same-shape malicious view"
  )
  apply_projection_migration(conn)

  wrong_definer <- "mcp_wrong_definer"
  mcp_verify_exec(conn, "DROP USER IF EXISTS 'mcp_wrong_definer'@'%'")
  mcp_verify_exec(conn, "CREATE USER 'mcp_wrong_definer'@'%' ACCOUNT LOCK")
  statement <- sub(
    "DEFINER = CURRENT_USER",
    "DEFINER = 'mcp_wrong_definer'@'%'",
    projection_statement("mcp_public_gene"),
    fixed = TRUE
  )
  mcp_verify_exec(conn, statement)
  expect_error_matching(
    reconcile(conn, expected_definer),
    "view attestation",
    "wrong definer"
  )
  apply_projection_migration(conn)

  hostile_passwords <- seed_hostile_authority(
    conn,
    open_direct_session = TRUE,
    open_reverse_session = TRUE
  )
  final_direct_session <- hostile_passwords$direct_session
  on.exit(try(DBI::dbDisconnect(final_direct_session), silent = TRUE), add = TRUE)
  reverse_session <- hostile_passwords$reverse_session
  on.exit(try(DBI::dbDisconnect(reverse_session), silent = TRUE), add = TRUE)
  reverse_identity <- mcp_verify_query(
    reverse_session,
    paste(
      "SELECT CURRENT_USER() AS effective_identity,",
      "USER() AS login_identity, @@proxy_user AS proxy_identity,",
      "CONNECTION_ID() AS connection_id"
    )
  )
  if (!identical(reverse_identity$effective_identity[[1L]], "sysndd_mcp@%") ||
      !grepl("^mcp_reverse_proxy@", reverse_identity$login_identity[[1L]]) ||
      is.na(reverse_identity$proxy_identity[[1L]])) {
    stop("Reverse PROXY fixture did not assume reader authority", call. = FALSE)
  }
  reverse_session_id <- reverse_identity$connection_id[[1L]]
  if (!identical(expected_definer, required_env("MCP_EXPECTED_VIEW_DEFINER"))) {
    stop("Verifier migration definer differs from provisioner input", call. = FALSE)
  }
  source("scripts/provision-mcp-readonly-principal.R", local = environment())
  mcp_readonly_provision_from_environment()
  reverse_error <- tryCatch({
    DBI::dbGetQuery(reverse_session, "SELECT CURRENT_USER()")
    NULL
  }, error = identity)
  if (is.null(reverse_error)) {
    stop("reverse PROXY session survived reconciliation", call. = FALSE)
  }
  surviving_reverse_session <- mcp_verify_query(
    conn,
    "SELECT COUNT(*) AS n FROM INFORMATION_SCHEMA.PROCESSLIST WHERE ID = ?",
    list(reverse_session_id)
  )$n[[1L]]
  surviving_reverse_grant <- mcp_verify_query(
    conn,
    paste(
      "SELECT COUNT(*) AS n FROM mysql.proxies_priv",
      "WHERE User = 'mcp_reverse_proxy' OR Proxied_user = 'sysndd_mcp'"
    )
  )$n[[1L]]
  if (surviving_reverse_session != 0 || surviving_reverse_grant != 0) {
    stop("Reverse PROXY authority survived reconciliation", call. = FALSE)
  }
  expect_reader_login_denied(hostile_passwords$primary, "obsolete primary password")
  expect_reader_login_denied(hostile_passwords$secondary, "obsolete secondary password")
  remaining <- mcp_verify_query(
    conn,
    paste(
      "SELECT COUNT(*) AS n FROM mysql.user",
      "WHERE User='sysndd_mcp' AND Host <> '%'"
    )
  )$n[[1]]
  if (remaining != 0) stop("Hostile reader variants survived provisioning", call. = FALSE)
  if (!identical(mcp_verify_query(conn, "SELECT @@GLOBAL.mandatory_roles AS roles")$roles[[1]], "")) {
    stop("Mandatory role fixture survived provisioning", call. = FALSE)
  }
  mcp_verify_exec(conn, "DROP USER 'mcp_reverse_proxy'@'%'")

  ambiguous_password <- NULL
  ambiguous_unlock <- function(conn, sql, params) {
    if (!grepl("ACCOUNT UNLOCK", sql, fixed = TRUE)) {
      return(mcp_verify_exec(conn, sql, params))
    }
    secret_path <- required_env("MCP_DB_PASSWORD_OUTPUT_FILE")
    ambiguous_password <<- readChar(secret_path, file.info(secret_path)$size)
    mcp_verify_exec(conn, sql, params)
    stop("simulated lost unlock acknowledgement", call. = FALSE)
  }
  expect_error_matching(
    reconcile(conn, expected_definer, execute_fn = ambiguous_unlock),
    "lost unlock acknowledgement",
    "ambiguous final unlock"
  )
  if (file.exists(required_env("MCP_DB_PASSWORD_OUTPUT_FILE"))) {
    stop("Incomplete rotation left the generated reader secret installed", call. = FALSE)
  }
  expect_reader_login_denied(ambiguous_password, "ambiguous unlock password")
  reconcile(conn, expected_definer)
  invisible(TRUE)
}

reader_expect_denied <- function(conn, sql) {
  error <- tryCatch({
    DBI::dbGetQuery(conn, sql)
    NULL
  }, error = identity)
  if (is.null(error) || !grepl("denied|command denied", conditionMessage(error), ignore.case = TRUE)) {
    stop(paste("Reader operation unexpectedly succeeded:", sql), call. = FALSE)
  }
}

assert_reader_boundary <- function(admin, reader) {
  projections <- mcp_readonly_projection_names()
  for (projection in projections) {
    DBI::dbGetQuery(reader, sprintf("SELECT * FROM `%s` LIMIT 1", projection))
  }
  raw_tables <- setdiff(
    unique(unlist(mcp_readonly_projection_dependencies(), use.names = FALSE)),
    projections
  )
  for (table in raw_tables) {
    reader_expect_denied(reader, sprintf("SELECT * FROM `%s` LIMIT 1", table))
  }
  reader_expect_denied(reader, "SELECT * FROM async_jobs LIMIT 1")
  reader_expect_denied(reader, "SELECT * FROM results_csv_table LIMIT 1")
  for (verb in c("INSERT", "UPDATE", "DELETE")) {
    sql <- switch(
      verb,
      INSERT = "INSERT INTO mcp_public_gene (hgnc_id) VALUES ('HGNC:9999')",
      UPDATE = "UPDATE mcp_public_gene SET symbol='forbidden' LIMIT 1",
      DELETE = "DELETE FROM mcp_public_gene LIMIT 1"
    )
    reader_expect_denied(reader, sql)
  }
  reader_expect_denied(reader, "INSERT INTO ndd_entity_review (entity_id) VALUES (7001)")
  reader_expect_denied(reader, "UPDATE ndd_entity_status SET is_active=0 WHERE status_id=7001")
  reader_expect_denied(reader, "DELETE FROM analysis_snapshot_manifest LIMIT 1")

  visible <- paste(unlist(lapply(projections, function(view) {
    rows <- DBI::dbGetQuery(reader, sprintf("SELECT * FROM `%s`", view))
    jsonlite::toJSON(rows, dataframe = "rows", na = "null")
  })), collapse = "\n")
  forbidden <- c(
    "draft confidentiality sentinel", "secondary confidentiality sentinel",
    "inactive entity confidentiality sentinel", "cross_entity sentinel",
    "inactive NDDScore sentinel", "forbidden_top_level", "forbidden_nested",
    "confidential judge sentinel", "confidential reasoning sentinel"
  )
  if (any(vapply(forbidden, grepl, logical(1), x = visible, fixed = TRUE))) {
    stop("A confidentiality fixture crossed the projection boundary", call. = FALSE)
  }
  if (!grepl("approved synopsis sentinel", visible, fixed = TRUE)) {
    stop("Approved projection fixture is unexpectedly empty", call. = FALSE)
  }

  states <- list(
    snapshot_pending = "status='pending',public_ready=0",
    snapshot_failed = "status='failed',public_ready=0",
    snapshot_superseded = "status='superseded',public_ready=0",
    snapshot_stale = "stale_after=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND)",
    NULL_expiry = "stale_after=NULL",
    source_mismatch = "source_data_version=REPEAT('0',64)",
    old_schema = "schema_version='0.9'"
  )
  snapshot <- mcp_verify_query(
    admin,
    "SELECT snapshot_id FROM analysis_snapshot_manifest WHERE analysis_type='functional_clusters'"
  )$snapshot_id[[1]]
  for (state in names(states)) {
    DBI::dbExecute(admin, "START TRANSACTION")
    on.exit(try(DBI::dbExecute(admin, "ROLLBACK"), silent = TRUE), add = TRUE)
    DBI::dbExecute(admin, paste0(
      "UPDATE analysis_snapshot_manifest SET ", states[[state]], " WHERE snapshot_id=", snapshot
    ))
    child_count <- DBI::dbGetQuery(
      reader,
      sprintf("SELECT COUNT(*) AS n FROM mcp_public_analysis_cluster WHERE snapshot_id=%s", snapshot)
    )$n[[1]]
    llm_count <- DBI::dbGetQuery(reader, "SELECT COUNT(*) AS n FROM mcp_public_llm_cluster_summary")$n[[1]]
    if (child_count != 0 || llm_count != 0) stop("Manifest state failed closed incorrectly", call. = FALSE)
    DBI::dbExecute(admin, "ROLLBACK")
  }
}

mcp_rpc <- function(method, params = NULL, id = 1L) {
  endpoint <- required_env("MCP_VERIFY_MCP_URL")
  if (grepl("token|password|secret", endpoint, ignore.case = TRUE)) {
    stop("Credential material appeared in MCP URL", call. = FALSE)
  }
  body <- list(jsonrpc = "2.0", id = id, method = method)
  if (!is.null(params)) body$params <- params
  response <- httr2::request(endpoint) |>
    httr2::req_headers(
      `Content-Type` = "application/json",
      `MCP-Protocol-Version` = "2025-11-25"
    ) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_timeout(20) |>
    httr2::req_perform()
  jsonlite::fromJSON(httr2::resp_body_string(response), simplifyVector = FALSE)
}

assert_all_tools <- function(forbidden_secrets) {
  initialized <- mcp_rpc(
    "initialize",
    list(
      protocolVersion = "2025-11-25", capabilities = list(),
      clientInfo = list(name = "mcp-select-principal-live", version = "1")
    )
  )
  if (is.null(initialized$result)) stop("MCP initialization failed", call. = FALSE)
  listed <- mcp_rpc("tools/list", id = 2L)
  tools <- listed$result$tools
  names <- vapply(tools, function(tool) tool$name, character(1))
  expected <- c(
    "search_sysndd", "get_gene_context", "get_genes_context",
    "get_entity_context", "get_entities_context", "list_gene_entities",
    "get_publication_context", "get_publications_context",
    "find_entities_by_phenotype", "find_entities_by_disease",
    "get_sysndd_stats", "get_sysndd_capabilities",
    "get_sysndd_analysis_catalog", "get_gene_research_context",
    "get_nddscore_context", "get_curation_comparison_context",
    "get_phenotype_analysis_context", "get_gene_network_context"
  )
  if (!identical(names, expected)) stop("Exact MCP tool inventory changed", call. = FALSE)
  calls <- list(
    search_sysndd = list(query = "LIVEGENE"),
    get_gene_context = list(gene = "LIVEGENE"),
    get_genes_context = list(genes = list("LIVEGENE")),
    get_entity_context = list(entity_id = 7001L),
    get_entities_context = list(entity_ids = list(7001L)),
    list_gene_entities = list(gene = "LIVEGENE"),
    get_publication_context = list(pmid = "PMID:7000001"),
    get_publications_context = list(pmids = list("PMID:7000001")),
    find_entities_by_phenotype = list(phenotype = "HP:7000001"),
    find_entities_by_disease = list(disease = "MONDO:7000001"),
    get_sysndd_stats = list(),
    get_sysndd_capabilities = list(),
    get_sysndd_analysis_catalog = list(),
    get_gene_research_context = list(gene = "LIVEGENE"),
    get_nddscore_context = list(gene = "LIVEGENE", mode = "gene"),
    get_curation_comparison_context = list(gene = "LIVEGENE", mode = "gene_sources"),
    get_phenotype_analysis_context = list(mode = "correlations", phenotype = "HP:7000001"),
    get_gene_network_context = list(gene = "LIVEGENE")
  )
  expected_text <- c(
    rep("LIVE", 10), "counts", "canonical_workflows", "analysis",
    "LIVEGENE", "LIVEGENE", "LiveSource", "HP:7000001", "LIVEGENE"
  )
  for (index in seq_along(names)) {
    result <- mcp_rpc(
      "tools/call",
      list(name = names[[index]], arguments = calls[[names[[index]]]]),
      id = index + 2L
    )
    text <- paste(vapply(result$result$content, function(item) item$text %||% "", character(1)), collapse = "\n")
    if (any(vapply(forbidden_secrets, grepl, logical(1), x = text, fixed = TRUE))) {
      stop("credential sentinel or reader secret entered MCP payload", call. = FALSE)
    }
    payload <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) list())
    top_keys <- paste(names(payload), collapse = ",")
    if (isTRUE(result$result$isError)) {
      stop(sprintf("MCP tool returned isError: %s [%s]", names[[index]], top_keys), call. = FALSE)
    }
    if (!nzchar(text)) stop(paste("MCP tool returned empty result:", names[[index]]), call. = FALSE)
    if (!is.null(payload$error)) {
      stop(sprintf("MCP tool returned error payload: %s [%s]", names[[index]], top_keys), call. = FALSE)
    }
    if (!grepl(expected_text[[index]], text, ignore.case = TRUE, fixed = TRUE)) {
      stop(sprintf("MCP tool response contract mismatch: %s [%s]", names[[index]], top_keys), call. = FALSE)
    }
  }
}

run_verify <- function() {
  secret_path <- required_env("MCP_DB_PASSWORD_FILE")
  reader_secret <- readChar(secret_path, file.info(secret_path)$size)
  admin_config <- mcp_readonly_admin_config()
  admin <- admin_connect(admin_config)
  reader <- reader_connect()
  on.exit(DBI::dbDisconnect(admin), add = TRUE)
  on.exit(DBI::dbDisconnect(reader), add = TRUE)
  assert_reader_boundary(admin, reader)
  secrets <- c(
    admin_config$password,
    required_env("MCP_CREDENTIAL_SENTINEL"),
    reader_secret
  )
  assert_all_tools(secrets)
  argv_raw <- readBin("/proc/self/cmdline", "raw", n = 65536L)
  argv <- paste(rawToChar(argv_raw, multiple = TRUE), collapse = "")
  if (any(vapply(secrets, grepl, logical(1), x = argv, fixed = TRUE))) {
    stop("Credential material appeared in process arguments", call. = FALSE)
  }
  cat("MCP_SELECT_VERIFY_OK\n")
}

if (identical(phase, "bootstrap")) run_bootstrap() else run_verify()
