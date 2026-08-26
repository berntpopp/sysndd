# The computed syndromicity block must reach metadata_json WITHOUT changing
# cluster_hash (#630). cluster_hash is a hash of the cluster's sorted entity_id
# set, so a new column cannot affect it -- but that is exactly the kind of
# claim that has to be locked by a test rather than asserted in a comment.

source_api_file("functions/analysis-snapshot-rows.R", local = FALSE)
source_api_file("functions/analysis-snapshot-builder.R", local = FALSE)

mk_clusters <- function() {
  tibble::tibble(
    cluster = "1",
    hash_filter = "abc123def456",
    cluster_size = 2L,
    identifiers = list(tibble::tibble(
      entity_id = c(1L, 2L),
      hgnc_id = c("HGNC:1", "HGNC:2"),
      symbol = c("A", "B")
    ))
  )
}

test_that("attaching syndromicity does not change cluster_hash", {
  before <- analysis_snapshot_build_cluster_rows(mk_clusters(), "phenotype")
  with_block <- mk_clusters()
  with_block$syndromicity <- list(list(
    cluster_call = "mixed", rule_version = "1.0", fraction_syndromic = 0.5
  ))
  after <- analysis_snapshot_build_cluster_rows(with_block, "phenotype")

  expect_identical(before$clusters$cluster_hash, after$clusters$cluster_hash)
  expect_identical(before$clusters$cluster_size, after$clusters$cluster_size)
  expect_identical(before$members$entity_id, after$members$entity_id)
})

test_that("the block reaches metadata_json intact", {
  with_block <- mk_clusters()
  with_block$syndromicity <- list(list(
    cluster_call = "mixed",
    fraction_syndromic = 0.658,
    thresholds = list(predominantly_syndromic = 0.75)
  ))
  md <- analysis_snapshot_build_cluster_rows(with_block, "phenotype")$clusters$metadata_json[[1]]
  parsed <- jsonlite::fromJSON(md, simplifyVector = FALSE)

  expect_equal(parsed$syndromicity$cluster_call, "mixed")
  expect_equal(parsed$syndromicity$fraction_syndromic, 0.658)
  # The thresholds must travel WITH the payload so a frozen downstream artifact
  # self-identifies rather than depending on the code that produced it.
  expect_equal(parsed$syndromicity$thresholds$predominantly_syndromic, 0.75)
})

test_that("a cluster with no members still builds", {
  empty <- tibble::tibble(
    cluster = "1", hash_filter = "abc", cluster_size = 0L,
    identifiers = list(tibble::tibble(
      entity_id = integer(), hgnc_id = character(), symbol = character()
    )),
    syndromicity = list(list(cluster_call = "insufficient_annotation"))
  )
  built <- analysis_snapshot_build_cluster_rows(empty, "phenotype")
  expect_equal(nrow(built$clusters), 1L)
  expect_equal(nrow(built$members), 0L)
})
