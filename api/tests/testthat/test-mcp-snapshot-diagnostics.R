test_that("MCP gene network reports unsupported parameters before lookup", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-service.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-analysis-shaping.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-analysis-service.R"), local = TRUE)

  err <- expect_error(
    mcp_get_gene_network_context(cluster_type = "clusters", min_confidence = 700, max_edges = 100),
    class = "mcp_tool_error"
  )
  expect_equal(unclass(err)$error$code, "unsupported_parameter")
})

test_that("MCP phenotype correlations reject gene in global mode", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-analysis-shaping.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-analysis-service.R"), local = TRUE)

  err <- expect_error(
    mcp_get_phenotype_analysis_context(mode = "correlations", gene = "GRIN2A"),
    class = "mcp_tool_error"
  )
  expect_equal(unclass(err)$error$code, "invalid_input")
})

test_that("MCP snapshot diagnostics collapse filtered states to snapshot_missing", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-service.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-analysis-shaping.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-analysis-service.R"), local = TRUE)

  old_status <- get0("mcp_analysis_repo_public_snapshot_status", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "snapshot_stale", envir = .GlobalEnv)
  withr::defer({
    if (is.null(old_status)) {
      rm("mcp_analysis_repo_public_snapshot_status", envir = .GlobalEnv)
    } else {
      assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv)
    }
  })

  dry_run <- mcp_get_gene_network_context(dry_run = TRUE)
  expect_equal(dry_run$section_status, "snapshot_missing")
  expect_false(dry_run$meta$snapshot_available)

  err <- expect_error(
    mcp_get_gene_network_context(),
    class = "mcp_tool_error"
  )
  expect_equal(unclass(err)$error$code, "snapshot_missing")
})

test_that("MCP snapshot status reads only the eligible manifest projection", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path(api_dir, "functions", "analysis-snapshot-repository.R"), local = TRUE)
  source(file.path(api_dir, "functions", "mcp-analysis-cache-repository.R"), local = TRUE)
  source(file.path(api_dir, "functions", "mcp-analysis-repository.R"), local = TRUE)

  old_db <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  old_get_public <- get0("analysis_snapshot_get_public", envir = .GlobalEnv, ifnotfound = NULL)
  sql_seen <- character()
  assign("db_execute_query", function(query, params = list(), conn = NULL) {
    sql_seen <<- c(sql_seen, query)
    tibble::tibble()
  }, envir = .GlobalEnv)
  assign("analysis_snapshot_get_public", function(...) stop("full snapshot getter called"), envir = .GlobalEnv)
  withr::defer({
    if (is.null(old_db)) {
      rm("db_execute_query", envir = .GlobalEnv)
    } else {
      assign("db_execute_query", old_db, envir = .GlobalEnv)
    }
    if (is.null(old_get_public)) {
      rm("analysis_snapshot_get_public", envir = .GlobalEnv)
    } else {
      assign("analysis_snapshot_get_public", old_get_public, envir = .GlobalEnv)
    }
  })

  status <- mcp_analysis_repo_public_snapshot_status(
    "phenotype_correlations",
    list(),
    current_source_data_version = "new-source"
  )

  expect_equal(status, "snapshot_missing")
  expect_true(any(grepl("mcp_public_analysis_manifest", sql_seen, fixed = TRUE)))
  expect_false(any(grepl("analysis_snapshot_manifest", sql_seen, fixed = TRUE)))
})
