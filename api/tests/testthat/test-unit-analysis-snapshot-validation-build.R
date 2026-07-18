library(testthat)

# Load the snapshot build/persist path + its dependencies into the global
# environment so analysis_snapshot_refresh and the mocked helpers resolve.
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/db-version.R", local = FALSE)
source_api_file("functions/analysis-snapshot-presets.R", local = FALSE)
source_api_file("functions/analysis-snapshot-repository.R", local = FALSE)
source_api_file("functions/analysis-snapshot-builder.R", local = FALSE)
source_api_file("functions/analyses-functions.R", local = FALSE)
source_api_file("functions/analysis-phenotype-functions.R", local = FALSE)
source_api_file("functions/analysis-cluster-validation.R", local = FALSE)

# The default local/PR test DB (sysndd_db_test) starts empty, so this DB-schema
# test skips gracefully unless the snapshot tables are present (repo convention,
# mirrors test-integration-entity-rename.R / test-unit-metadata-refresh.R). It
# still runs for real against an initialized DB.
skip_if_missing_analysis_snapshot_schema <- function(conn) {
  required_tables <- c(
    "analysis_snapshot_manifest",
    "analysis_snapshot_cluster",
    "analysis_snapshot_cluster_member",
    # analysis_snapshot_refresh() also reads the source-data-version view, which
    # is created by the full migration set (a real initialized DB) but NOT by the
    # partial ensure_test_analysis_snapshot_manifest_schema() helper that a sibling
    # test may leave behind. Without this sentinel the guard passes on a
    # partial schema and the refresh then fails on the missing view.
    "mcp_public_analysis_source_version"
  )
  missing_tables <- required_tables[!vapply(
    required_tables,
    function(table) DBI::dbExistsTable(conn, table),
    logical(1)
  )]
  if (length(missing_tables) > 0) {
    testthat::skip(paste(
      "Test database schema is not initialized; missing table(s):",
      paste(missing_tables, collapse = ", ")
    ))
  }
}

# testthat::local_mocked_bindings() cannot mock bindings that live in the global
# environment: repo functions are source()d into globalenv, which has no package
# namespace, so testthat (>= 3.2) aborts with "No packages loaded with pkgload".
# Stub the global binding directly instead and restore it when the calling frame
# exits, so a mock never leaks into a later test file sharing this R session.
stub_global_binding <- function(name, value, frame = parent.frame()) {
  had <- exists(name, envir = globalenv(), inherits = FALSE)
  old <- if (had) get(name, envir = globalenv(), inherits = FALSE) else NULL
  assign(name, value, envir = globalenv())
  withr::defer(
    if (had) {
      assign(name, old, envir = globalenv())
    } else if (exists(name, envir = globalenv(), inherits = FALSE)) {
      rm(list = name, envir = globalenv())
    },
    envir = frame
  )
}

test_that("functional snapshot persists validation + db release label", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_analysis_snapshot_schema(conn)
    # avoid the live STRING API: return a minimal visible-cluster tibble shaped like
    # gen_string_clust_obj's output (cluster, identifiers[hgnc_id], hash_filter, cluster_size)
    stub_global_binding("gen_string_clust_obj_mem", function(...) dplyr::tibble(
      cluster = 1L,
      identifiers = list(dplyr::tibble(hgnc_id = c("HGNC:1", "HGNC:2"))),
      hash_filter = "deadbeef", cluster_size = 2L
    ))
    stub_global_binding("validate_functional_clusters", function(...) list(
      per_cluster = dplyr::tibble(cluster_id = "1", jaccard_mean = 0.82,
                                  jaccard_n_resamples = 100L, bootstrap_seed = 42L),
      partition = list(validation_schema_version = "1.0", algorithm = "leiden", weighted = TRUE,
                       n_iterations = -1L, resolution_parameter = 1.0, modularity = 0.41,
                       modularity_scope = "full_partition", n_clusters = 1L, n_dropped_below_min_size = 0L,
                       partition_scope = "visible_top_level", resampling_scheme = "subsample",
                       subsample_fraction = 0.8, n_resamples = 100L, n_resamples_effective = 100L)
    ))
    stub_global_binding("db_version_get",
      function(...) list(version = "v3.2.0", commit = "abc1234", available = TRUE))
    res <- analysis_snapshot_refresh("functional_clusters",
             params = list(algorithm = "leiden"), conn = conn)
    man <- DBI::dbGetQuery(conn,
      "SELECT validation_json, db_release_version, db_release_commit
         FROM analysis_snapshot_manifest
        WHERE analysis_type = 'functional_clusters' ORDER BY snapshot_id DESC LIMIT 1")
    expect_false(is.na(man$validation_json))
    expect_match(man$validation_json, "visible_top_level")
    expect_equal(man$db_release_version, "v3.2.0")
  })
})
