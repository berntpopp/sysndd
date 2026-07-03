# tests/testthat/test-unit-llm-judge-large-cluster.R
#
# Host-runnable coverage for the #490 judge changes that do NOT require ellmer:
#   - the phenotype judge prompt gains a relaxed high-level GESTALT bar for very
#     large, heterogeneous clusters (llm-judge-prompts.R only needs glue)
#   - generate_cluster_summary() accepts an authoritative cluster_hash param so
#     the generation log hash matches the cache hash (llm-client.R has no
#     ellmer call at source time)
#
# The fuller judge-prompt suite in test-unit-llm-judge-prompt.R sources
# llm-judge.R (which builds an ellmer type at source time) and is therefore
# container-only; this file keeps the pure pieces host-verifiable.
#
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-llm-judge-large-cluster.R')"

library(testthat)

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

suppressWarnings(suppressMessages({
  source_api_file("functions/llm-judge-prompts.R", local = FALSE)
  source_api_file("functions/llm-client.R", local = FALSE)
}))

test_that("LLM_JUDGE_LARGE_CLUSTER_THRESHOLD is a positive integer", {
  expect_true(is.numeric(LLM_JUDGE_LARGE_CLUSTER_THRESHOLD))
  expect_gt(LLM_JUDGE_LARGE_CLUSTER_THRESHOLD, 0)
})

test_that("large clusters get the relaxed-bar GESTALT instruction; small clusters do not", {
  big <- build_phenotype_judge_prompt(
    summary = list(summary = "x", confidence = "low"),
    cluster_data = list(identifiers = data.frame(entity_id = seq_len(1043)))
  )
  small <- build_phenotype_judge_prompt(
    summary = list(summary = "x", confidence = "low"),
    cluster_data = list(identifiers = data.frame(entity_id = 1:5))
  )
  expect_match(big, "RELAXED BAR", fixed = TRUE)
  expect_match(big, "HIGH-LEVEL GESTALT", fixed = TRUE)
  # Severe-error hard rejects still apply even under the relaxed bar.
  expect_match(big, "direction inversion", ignore.case = TRUE)
  expect_false(grepl("RELAXED BAR", small, fixed = TRUE))
})

test_that("generate_cluster_summary exposes an authoritative cluster_hash param (#490)", {
  expect_true("cluster_hash" %in% names(formals(generate_cluster_summary)))
  expect_null(eval(formals(generate_cluster_summary)$cluster_hash))
})
