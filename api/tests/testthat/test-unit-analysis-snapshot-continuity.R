# #679: partition continuity against the previous public snapshot. Additive
# diagnostics -- must never fail a refresh. SQL is exercised for real in
# test-integration-analysis-snapshot-continuity.R; here the query is injected.

source_api_file("functions/analysis-phenotype-missingness.R", local = FALSE, envir = globalenv())
source_api_file("functions/analysis-snapshot-coherence.R", local = FALSE, envir = globalenv())

continuity_clusters <- function(labels) {
  # the builder's cluster tibble shape: integer `cluster` + nested identifiers
  parts <- split(names(labels), labels)
  tibble::tibble(
    cluster = as.integer(names(parts)),
    identifiers = lapply(parts, function(ids) tibble::tibble(entity_id = as.integer(ids)))
  )
}

continuity_query <- function(snapshot_id, previous) {
  function(sql, params = list(), conn = NULL) {
    if (grepl("analysis_snapshot_manifest", sql, fixed = TRUE)) {
      if (is.null(snapshot_id)) return(data.frame(snapshot_id = integer()))
      return(data.frame(snapshot_id = snapshot_id))
    }
    data.frame(cluster_id = as.character(previous), entity_id = as.integer(names(previous)),
               stringsAsFactors = FALSE)
  }
}

labels <- stats::setNames(rep(1:3, times = c(40, 30, 30)), as.character(1:100))

test_that("identical membership reports ARI 1 and perfect per-cluster recovery", {
  res <- analysis_snapshot_phenotype_continuity(
    continuity_clusters(labels), query_fn = continuity_query(196L, labels)
  )
  expect_identical(res$status, "ok")
  expect_identical(res$previous_snapshot_id, 196L)
  expect_identical(res$n_common_entities, 100L)
  expect_equal(res$ari, 1)
  expect_equal(unlist(res$per_cluster_best_jaccard), c(`1` = 1, `2` = 1, `3` = 1))
})

test_that("continuity is label-invariant and restricted to the common entities", {
  relabelled <- stats::setNames(c(3L, 1L, 2L)[labels], names(labels))
  previous <- relabelled[1:90] # ten entities are new in this snapshot
  res <- analysis_snapshot_phenotype_continuity(
    continuity_clusters(labels), query_fn = continuity_query(144L, previous)
  )
  expect_identical(res$n_common_entities, 90L)
  expect_equal(res$ari, 1)
})

test_that("a re-split partition is reported as such", {
  resplit <- stats::setNames(rep(1:2, times = 50), names(labels))
  res <- analysis_snapshot_phenotype_continuity(
    continuity_clusters(labels), query_fn = continuity_query(144L, resplit)
  )
  expect_identical(res$status, "ok")
  expect_lt(res$ari, 0.2)
  expect_true(all(unlist(res$per_cluster_best_jaccard) < 0.6))
})

test_that("the preset's parameter_hash scopes the manifest lookup", {
  seen <- list()
  spy <- function(sql, params = list(), conn = NULL) {
    seen[[length(seen) + 1L]] <<- list(sql = sql, params = params)
    continuity_query(7L, labels)(sql, params, conn)
  }
  analysis_snapshot_phenotype_continuity(continuity_clusters(labels),
                                         parameter_hash = strrep("c", 64), query_fn = spy)
  expect_match(seen[[1]]$sql, "parameter_hash = ?", fixed = TRUE)
  expect_identical(seen[[1]]$params, list("phenotype_clusters", strrep("c", 64)))
  # the number of placeholders always equals the number of bound parameters
  for (call in seen) {
    expect_identical(lengths(regmatches(call$sql, gregexpr("?", call$sql, fixed = TRUE))),
                     length(call$params))
  }

  seen <- list()
  analysis_snapshot_phenotype_continuity(continuity_clusters(labels), query_fn = spy)
  expect_false(grepl("parameter_hash", seen[[1]]$sql, fixed = TRUE))
  expect_identical(seen[[1]]$params, list("phenotype_clusters"))
})

test_that("no previous snapshot and query failures degrade to a status, never an error", {
  none <- analysis_snapshot_phenotype_continuity(
    continuity_clusters(labels), query_fn = continuity_query(NULL, labels)
  )
  expect_identical(none$status, "no_previous_snapshot")
  expect_null(none$ari)

  broken <- analysis_snapshot_phenotype_continuity(
    continuity_clusters(labels), query_fn = function(...) stop("connection lost")
  )
  expect_identical(broken$status, "unavailable")
  expect_match(broken$message, "connection lost")
})
