# tests/testthat/test-mcp-select-principal-repository-contract.R

library(testthat)

source_api_file("functions/mcp-analysis-repository.R", local = FALSE)

test_that("snapshot metadata emits each approved field exactly once", {
  snapshot <- list(manifest = data.frame(
    snapshot_id = 1L,
    analysis_type = "functional_clusters",
    parameter_hash = "params",
    schema_version = "1.2",
    source_data_version = "source",
    payload_hash = "payload",
    generated_at = "2026-07-13T00:00:00Z",
    activated_at = "2026-07-13T00:01:00Z",
    stale_after = "2026-07-14T00:00:00Z",
    algorithm_name = "leiden",
    algorithm_version = "1",
    stringsAsFactors = FALSE
  ))

  fields <- names(mcp_analysis_repo_manifest_meta(snapshot)$snapshot)
  expect_identical(anyDuplicated(fields), 0L)
})
