library(testthat)

# Load the snapshot build/persist path + its dependencies into the global
# environment so analysis_snapshot_refresh and the mocked helpers resolve.
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/db-version.R", local = FALSE)
source_api_file("functions/analysis-snapshot-presets.R", local = FALSE)
source_api_file("functions/analysis-snapshot-repository.R", local = FALSE)
# analysis_snapshot_prune(), which the write path calls to retire superseded
# snapshots (it consults the #573 release-reference guard).
source_api_file("functions/analysis-snapshot-prune-helpers.R", local = FALSE)
source_api_file("functions/analysis-snapshot-release-repository.R", local = FALSE)
# The #514 coherence gate the builder publishes through -- sourced BEFORE the
# builder, mirroring bootstrap/load_modules.R. Without it the build aborts with
# "could not find function analysis_snapshot_join_validated_clusters".
source_api_file("functions/analysis-snapshot-coherence.R", local = FALSE)
# #585 generator provenance: the builder calls
# analysis_snapshot_functional_applied_params() unguarded. Sourced BEFORE the
# builder, mirroring bootstrap/load_modules.R.
source_api_file("functions/analysis-snapshot-provenance-generator.R", local = FALSE)
source_api_file("functions/analysis-snapshot-builder.R", local = FALSE)
# #512 reproducibility bundle: the builder attaches one on every cluster layer.
source_api_file("functions/analysis-reproducibility.R", local = FALSE)
source_api_file("functions/analyses-functions.R", local = FALSE)
source_api_file("functions/analysis-phenotype-functions.R", local = FALSE)
# CLUSTER_LOGIC_VERSION, which the #585 generator-provenance completeness gate
# requires (it is fail-closed: an incomplete generator aborts the build).
source_api_file("functions/analysis-cache-fingerprint.R", local = FALSE)
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

# testthat::local_mocked_bindings() cannot mock a binding that does not live in
# a package namespace -- repo functions are source()d into a plain environment,
# so testthat (>= 3.2) aborts with "No packages loaded with pkgload". Stub the
# binding directly instead and restore it when the calling frame exits, so a
# mock never leaks into a later test file sharing this R session.
#
# WHICH environment matters, and getting it wrong fails silently.
# source_api_file(local = FALSE) sources into `envir = parent.frame()`, which at
# a test file's top level is testthat's per-file environment -- a CHILD of
# globalenv, not globalenv itself. A stub written to globalenv is therefore
# SHADOWED by the real function sourced into that child: the code under test
# calls the real implementation while the stub sits invisible one level up.
#
# That is not hypothetical. It is why this file's validate_functional_clusters
# stub did nothing and the build reached the live STRING path, failing with
# `object 'pool' not found` the first time #612 gave CI a real schema and this
# test stopped skipping. The failure was ASYMMETRIC and so read as a production
# bug: the gen_string_clust_obj_mem stub DID take effect, because that name is
# bound at API startup and is not among the files sourced above, so globalenv
# really was where it resolved.
#
# Resolve the target the way R resolves the call: walk up from the caller and
# stub where the name is already bound, stopping at globalenv so a name that
# only exists in an attached package is never written into a locked namespace.
.stub_target_env <- function(name, frame) {
  env <- frame
  repeat {
    if (identical(env, globalenv())) {
      return(globalenv())
    }
    if (exists(name, envir = env, inherits = FALSE)) {
      return(env)
    }
    parent <- parent.env(env)
    if (identical(parent, env) || identical(parent, emptyenv())) {
      return(globalenv())
    }
    env <- parent
  }
}

stub_binding <- function(name, value, frame = parent.frame()) {
  target <- .stub_target_env(name, frame)
  had <- exists(name, envir = target, inherits = FALSE)
  old <- if (had) get(name, envir = target, inherits = FALSE) else NULL
  assign(name, value, envir = target)
  withr::defer(
    if (had) {
      assign(name, old, envir = target)
    } else if (exists(name, envir = target, inherits = FALSE)) {
      rm(list = name, envir = target)
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
    stub_binding("gen_string_clust_obj_mem", function(...) dplyr::tibble(
      cluster = 1L,
      identifiers = list(dplyr::tibble(hgnc_id = c("HGNC:1", "HGNC:2"))),
      hash_filter = "deadbeef", cluster_size = 2L
    ))
    stub_binding("validate_functional_clusters", function(...) list(
      per_cluster = dplyr::tibble(cluster_id = "1", jaccard_mean = 0.82,
                                  jaccard_n_resamples = 100L, bootstrap_seed = 42L),
      partition = list(validation_schema_version = "1.0", algorithm = "leiden", weighted = TRUE,
                       n_iterations = -1L, resolution_parameter = 1.0, modularity = 0.41,
                       modularity_scope = "full_partition", n_clusters = 1L, n_dropped_below_min_size = 0L,
                       partition_scope = "visible_top_level", resampling_scheme = "subsample",
                       subsample_fraction = 0.8, n_resamples = 100L, n_resamples_effective = 100L)
    ))
    # analysis_snapshot_with_write_transaction() opens a REAL transaction on the
    # connection it is handed (db_with_transaction -> DBI::dbWithTransaction),
    # which is correct in production: it always receives a pool checkout or a
    # dedicated connection with no transaction open. Here the connection is
    # already inside with_test_db_transaction()'s BEGIN, and RMariaDB has no
    # nested transaction, so the real wrapper aborts with "Nested transactions
    # not supported". It is a thin BEGIN/COMMIT seam, not the subject of this
    # test -- run the write body directly and let the outer test transaction
    # provide atomicity and rollback. Do NOT "fix" this by making the production
    # helper use a SAVEPOINT: on the raw, autocommit connection production
    # actually passes, a SAVEPOINT would silently buy no atomicity at all.
    stub_binding("analysis_snapshot_with_write_transaction",
      function(conn, code) code(conn))
    stub_binding("db_version_get",
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
