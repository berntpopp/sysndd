# tests/testthat/test-integration-analysis-snapshot-continuity.R
#
# #679: analysis_snapshot_phenotype_continuity() against the REAL schema. The unit
# tests inject the query function, which proves the arithmetic but cannot see the SQL
# (column names, the public-ready predicate, parameter binding). Everything is written
# inside with_test_db_transaction() and rolled back.

source_api_file("functions/db-helpers.R", local = FALSE, envir = globalenv())
source_api_file("functions/analysis-phenotype-missingness.R", local = FALSE, envir = globalenv())
source_api_file("functions/analysis-snapshot-coherence.R", local = FALSE, envir = globalenv())

skip_if_missing_analysis_snapshot_schema <- function(conn) {
  needed <- c("analysis_snapshot_manifest", "analysis_snapshot_cluster",
              "analysis_snapshot_cluster_member")
  missing <- needed[!vapply(needed, function(t) DBI::dbExistsTable(conn, t), logical(1))]
  if (length(missing)) {
    testthat::skip(paste("analysis snapshot schema missing:", paste(missing, collapse = ", ")))
  }
}

test_that("continuity reads the latest public-ready phenotype snapshot from the real schema", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_analysis_snapshot_schema(conn)

    # activated far in the future so it is THE latest public-ready phenotype snapshot
    # regardless of any residue in the test database.
    DBI::dbExecute(conn,
      "INSERT INTO analysis_snapshot_manifest
         (analysis_type, parameter_hash, schema_version, data_class, status, public_ready,
          activated_at, parameters_json, input_hash, payload_hash)
       VALUES ('phenotype_clusters', ?, '1.0', 'public', 'public_ready', 1,
               '2999-01-01 00:00:00', '{}', ?, ?)",
      params = unname(list(strrep("c", 64), strrep("a", 64), strrep("b", 64))))
    snapshot_id <- as.integer(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id)

    previous <- stats::setNames(rep(c("1", "2"), each = 10), as.character(9000001:9000020))
    for (cl in unique(previous)) {
      DBI::dbExecute(conn,
        "INSERT INTO analysis_snapshot_cluster
           (snapshot_id, cluster_kind, cluster_id, cluster_hash, cluster_size)
         VALUES (?, 'phenotype', ?, ?, 10)",
        params = unname(list(snapshot_id, cl, strrep(cl, 64))))
    }
    rank <- stats::ave(seq_along(previous), previous, FUN = seq_along)
    for (i in seq_along(previous)) {
      DBI::dbExecute(conn,
        "INSERT INTO analysis_snapshot_cluster_member
           (snapshot_id, cluster_kind, cluster_id, member_rank, entity_id)
         VALUES (?, 'phenotype', ?, ?, ?)",
        params = unname(list(snapshot_id, previous[[i]], as.integer(rank[[i]]),
                             as.integer(names(previous)[[i]]))))
    }
    # a functional-kind row on the same snapshot must be ignored by the kind filter
    DBI::dbExecute(conn,
      "INSERT INTO analysis_snapshot_cluster
         (snapshot_id, cluster_kind, cluster_id, cluster_hash, cluster_size)
       VALUES (?, 'functional', '9', ?, 1)",
      params = unname(list(snapshot_id, strrep("f", 64))))
    DBI::dbExecute(conn,
      "INSERT INTO analysis_snapshot_cluster_member
         (snapshot_id, cluster_kind, cluster_id, member_rank, entity_id)
       VALUES (?, 'functional', '9', 1, 9000001)",
      params = unname(list(snapshot_id)))

    # The new partition: same two groups under swapped labels, plus one new entity.
    current <- tibble::tibble(
      cluster = c(1L, 2L),
      identifiers = list(
        tibble::tibble(entity_id = c(9000011:9000020, 9000099L)),
        tibble::tibble(entity_id = 9000001:9000010)
      )
    )
    res <- analysis_snapshot_phenotype_continuity(current, conn = conn)

    expect_identical(res$status, "ok", info = res$message)
    expect_identical(res$previous_snapshot_id, snapshot_id)
    expect_identical(res$n_common_entities, 20L)
    expect_identical(res$n_entities_previous, 20L)
    expect_equal(res$ari, 1)
  })
})
