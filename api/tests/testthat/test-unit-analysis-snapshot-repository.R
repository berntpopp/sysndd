analysis_snapshot_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())

test_that("snapshot repository exposes expected public API", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

  expect_true(exists("analysis_snapshot_lock_name", mode = "function"))
  expect_true(exists("analysis_snapshot_get_public", mode = "function"))
  expect_true(exists("analysis_snapshot_create_manifest", mode = "function"))
  expect_true(exists("analysis_snapshot_activate", mode = "function"))
  expect_true(exists("analysis_snapshot_prune", mode = "function"))
})

test_that("snapshot lock names are scoped by hash and fit MySQL's 64-char GET_LOCK limit", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

  net <- analysis_snapshot_normalize_params(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400, max_edges = 10000)
  )
  net_lock <- analysis_snapshot_lock_name(net$analysis_type, net$parameter_hash)

  # Derived deterministically from the parameter hash (which already encodes the
  # analysis type + params); short prefix keeps it readable and unique.
  expect_equal(net_lock, paste0("asr:", substr(net$parameter_hash, 1, 56)))

  # Every supported preset's lock name MUST fit MySQL GET_LOCK()'s 64-char cap.
  # If it overflows, GET_LOCK fails (errno 4163) and the refresh job can never
  # build a snapshot -> permanent `snapshot_missing` on every analysis endpoint.
  locks <- vapply(analysis_snapshot_supported_presets(), function(p) {
    h <- analysis_snapshot_parameter_hash(p$analysis_type, p$params)
    analysis_snapshot_lock_name(p$analysis_type, h)
  }, character(1))
  expect_true(
    all(nchar(locks) <= 64),
    info = paste("lock name lengths:", paste(nchar(locks), collapse = ", "))
  )

  # Distinct presets still get distinct locks (per-(type,params) scoping preserved).
  expect_equal(length(unique(locks)), length(locks))
})

test_that("snapshot status helpers classify missing and stale rows", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

  expect_equal(analysis_snapshot_status_code(NULL), "snapshot_missing")
  stale <- list(stale_after = Sys.time() - 60)
  expect_equal(analysis_snapshot_status_code(stale), "snapshot_stale")
  fresh <- list(stale_after = Sys.time() + 60)
  expect_equal(analysis_snapshot_status_code(fresh), "available")
})

test_that("public snapshot reads include current source version for mismatch diagnostics", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)

  query_count <- 0L
  env$db_execute_query <- function(sql, params = list(), conn = NULL) {
    query_count <<- query_count + 1L
    if (grepl("FROM analysis_snapshot_manifest", sql, fixed = TRUE)) {
      return(tibble::tibble(
        snapshot_id = 1L,
        analysis_type = "phenotype_clusters",
        parameter_hash = "hash",
        schema_version = "1.0",
        data_class = "curated_derived_analysis",
        source_data_version = "old-source",
        stale_after = Sys.time() + 3600
      ))
    }
    tibble::tibble()
  }
  env$analysis_snapshot_source_data_version <- function(conn = NULL) "new-source"

  snapshot <- env$analysis_snapshot_get_public("phenotype_clusters", "hash")

  expect_equal(snapshot$status_code, "source_version_mismatch")
  expect_equal(snapshot$manifest$current_source_data_version[[1]], "new-source")
  expect_equal(query_count, 1L)
  expect_false("clusters" %in% names(snapshot))
})

test_that("snapshot API time strings preserve sub-second precision", {
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  timestamp <- as.POSIXct("2026-05-30 12:34:56.789", tz = "UTC")

  expect_equal(service_analysis_snapshot_time_string(timestamp), "2026-05-30T12:34:56.789Z")
})

test_that("manifest creation uses one checked-out pool connection for insert id lookup", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)

  events <- character()
  fake_pool <- NULL
  checked_out <- structure(
    list(label = "checked-out"),
    class = "DBIConnection",
    pool_metadata = list(valid = TRUE)
  )
  fake_pool <- structure(
    list(
      fetch = function() {
        events <<- c(events, "checkout")
        checked_out <<- structure(
          list(label = "checked-out"),
          class = "DBIConnection",
          pool_metadata = list(pool = fake_pool, valid = TRUE)
        )
        checked_out
      },
      release = function(object) {
        expect_identical(object, checked_out)
        events <<- c(events, "return")
      }
    ),
    class = "Pool"
  )

  env$db_execute_statement <- function(sql, params = list(), conn = NULL) {
    expect_identical(conn, checked_out)
    events <<- c(events, "insert")
    1L
  }
  env$db_execute_query <- function(sql, params = list(), conn = NULL) {
    expect_identical(conn, checked_out)
    events <<- c(events, "last_id")
    tibble::tibble(snapshot_id = 77)
  }

  snapshot_id <- env$analysis_snapshot_create_manifest(
    list(
      analysis_type = "gene_network_edges",
      parameter_hash = "abc",
      schema_version = "1.0",
      data_class = "curated_derived_analysis",
      status = "pending",
      parameters_json = "{}",
      input_hash = "input",
      payload_hash = "payload"
    ),
    conn = fake_pool
  )

  expect_equal(snapshot_id, 77)
  expect_equal(events, c("checkout", "insert", "last_id", "return"))
})

test_that("repository connections close direct fallback connections they create", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)

  events <- character()
  direct_conn <- structure(list(label = "direct"), class = "DBIConnection")
  env$get_db_connection <- function() {
    events <<- c(events, "connect")
    direct_conn
  }

  local_mocked_bindings(
    dbDisconnect = function(conn, ...) {
      expect_identical(conn, direct_conn)
      events <<- c(events, "disconnect")
      TRUE
    },
    .package = "DBI"
  )

  result <- env$analysis_snapshot_with_repository_connection(NULL, function(conn) {
    expect_identical(conn, direct_conn)
    events <<- c(events, "use")
    "ok"
  })

  expect_equal(result, "ok")
  expect_equal(events, c("connect", "use", "disconnect"))
})

test_that("snapshot row inserts batch through dbAppendTable", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)

  appends <- list()
  statements <- 0L
  env$db_execute_statement <- function(...) {
    statements <<- statements + 1L
    1L
  }

  local_mocked_bindings(
    dbAppendTable = function(conn, name, value, ...) {
      appends <<- c(appends, list(list(name = name, rows = nrow(value), columns = names(value))))
      TRUE
    },
    .package = "DBI"
  )

  fake_conn <- structure(list(label = "conn"), class = "DBIConnection")
  env$analysis_snapshot_insert_cluster_rows(
    42L,
    tibble::tibble(
      cluster_kind = c("phenotype", "phenotype"),
      cluster_id = c("3", "4"),
      cluster_hash = c("hash-3", "hash-4"),
      cluster_size = c(1L, 2L),
      label = c("A", "B"),
      metadata_json = c("{}", "{}")
    ),
    tibble::tibble(
      cluster_kind = c("phenotype", "phenotype"),
      cluster_id = c("3", "4"),
      member_rank = c(1L, 1L),
      entity_id = c(10L, 20L),
      hgnc_id = c("HGNC:1", "HGNC:2"),
      symbol = c("GENE1", "GENE2")
    ),
    conn = fake_conn
  )

  env$analysis_snapshot_insert_correlation_rows(
    42L,
    tibble::tibble(
      row_rank = c(1L, 2L),
      correlation_kind = c("phenotype", "phenotype"),
      x_key = c("A", "B"),
      y_key = c("B", "C"),
      value = c(0.4, 0.5),
      abs_value = c(0.4, 0.5),
      metadata_json = c("{}", "{}")
    ),
    conn = fake_conn
  )

  expect_equal(statements, 0L)
  expect_equal(
    vapply(appends, `[[`, character(1), "name"),
    c("analysis_snapshot_cluster", "analysis_snapshot_cluster_member", "analysis_snapshot_correlation")
  )
  expect_equal(vapply(appends, `[[`, integer(1), "rows"), c(2L, 2L, 2L))
})

test_that("snapshot activation supersedes old public row before activating target", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)

  state <- data.frame(
    snapshot_id = c(10, 11),
    analysis_type = c("phenotype_clusters", "phenotype_clusters"),
    parameter_hash = c("hash", "hash"),
    public_ready = c(1L, 0L),
    status = c("public_ready", "pending"),
    stringsAsFactors = FALSE
  )
  events <- character()
  env$db_execute_statement <- function(sql, params = list(), conn = NULL) {
    if (grepl("snapshot_id <>", sql, fixed = TRUE)) {
      events <<- c(events, "supersede")
      keep <- state$analysis_type == params[[1]] &
        state$parameter_hash == params[[2]] &
        state$public_ready == 1L &
        state$snapshot_id != params[[3]]
      state$public_ready[keep] <<- 0L
      state$status[keep] <<- "superseded"
      return(sum(keep))
    }

    if (grepl("public_ready = 1", sql, fixed = TRUE)) {
      events <<- c(events, "activate")
      target <- state$snapshot_id == params[[1]] &
        state$analysis_type == params[[2]] &
        state$parameter_hash == params[[3]]
      expect_lte(sum(state$public_ready == 1L), 0L)
      state$public_ready[target] <<- 1L
      state$status[target] <<- "public_ready"
      return(sum(target))
    }

    stop("unexpected statement")
  }

  result <- env$analysis_snapshot_activate(
    snapshot_id = 11L,
    analysis_type = "phenotype_clusters",
    parameter_hash = "hash",
    conn = structure(list(label = "conn"), class = "DBIConnection"),
    use_transaction = FALSE
  )

  expect_equal(result, 11L)
  expect_equal(events, c("supersede", "activate"))
  expect_equal(state$public_ready, c(0L, 1L))
  expect_equal(state$status, c("superseded", "public_ready"))
})

test_that("snapshot prune binds UTC timestamp text and never targets active public rows", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)

  seen_candidate_sql <- NULL
  seen_cutoff <- NULL
  deleted_ids <- NULL
  query_index <- 0L
  env$db_execute_query <- function(sql, params = list(), conn = NULL) {
    query_index <<- query_index + 1L
    if (query_index == 1L) {
      return(tibble::tibble(snapshot_id = 2L))
    }
    seen_candidate_sql <<- sql
    seen_cutoff <<- params[[3]]
    tibble::tibble(snapshot_id = c(1L, 2L, 3L))
  }
  env$db_execute_statement <- function(sql, params = list(), conn = NULL) {
    deleted_ids <<- unlist(params)
    length(deleted_ids)
  }

  result <- env$analysis_snapshot_prune(
    "phenotype_clusters",
    "hash",
    keep_public_ready = 1L,
    keep_superseded_days = 14L,
    conn = structure(list(label = "conn"), class = "DBIConnection")
  )

  expect_equal(result, 2L)
  expect_match(seen_candidate_sql, "status = 'superseded'", fixed = TRUE)
  expect_type(seen_cutoff, "character")
  expect_match(seen_cutoff, "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\.\\d{6}$")
  expect_equal(deleted_ids, c(1, 3))
})
