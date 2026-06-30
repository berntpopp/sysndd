library(testthat)

# Load the snapshot build/persist path + its dependencies into the global
# environment so analysis_snapshot_refresh and the mocked helpers resolve.
source_api_file("functions/db-version.R", local = FALSE)
source_api_file("functions/analysis-snapshot-presets.R", local = FALSE)
source_api_file("functions/analysis-snapshot-repository.R", local = FALSE)
source_api_file("functions/analysis-snapshot-builder.R", local = FALSE)
source_api_file("functions/analyses-functions.R", local = FALSE)
source_api_file("functions/analysis-phenotype-functions.R", local = FALSE)
source_api_file("functions/analysis-cluster-validation.R", local = FALSE)

test_that("functional snapshot persists validation + db release label", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    local_mocked_bindings(
      # avoid the live STRING API: return a minimal visible-cluster tibble shaped like
      # gen_string_clust_obj's output (cluster, identifiers[hgnc_id], hash_filter, cluster_size)
      gen_string_clust_obj_mem = function(...) dplyr::tibble(
        cluster = 1L,
        identifiers = list(dplyr::tibble(hgnc_id = c("HGNC:1", "HGNC:2"))),
        hash_filter = "deadbeef", cluster_size = 2L
      ),
      validate_functional_clusters = function(...) list(
        per_cluster = dplyr::tibble(cluster_id = "1", jaccard_mean = 0.82,
                                    jaccard_n_resamples = 100L, bootstrap_seed = 42L),
        partition = list(validation_schema_version = "1.0", algorithm = "leiden", weighted = TRUE,
                         n_iterations = -1L, resolution_parameter = 1.0, modularity = 0.41,
                         modularity_scope = "full_partition", n_clusters = 1L, n_dropped_below_min_size = 0L,
                         partition_scope = "visible_top_level", resampling_scheme = "subsample",
                         subsample_fraction = 0.8, n_resamples = 100L, n_resamples_effective = 100L)
      ),
      db_version_get = function(...) list(version = "v3.2.0", commit = "abc1234", available = TRUE),
      .env = globalenv()
    )
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
