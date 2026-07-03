# tests/testthat/test-unit-llm-batch-cluster-data.R
#
# Unit tests for the cluster-row -> cluster_data builder extracted from the LLM
# batch executor (llm-batch-cluster-data.R). Pure (no DB / no ellmer):
# generate_cluster_hash is stubbed for the fallback path.
#
# Host-runnable:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-llm-batch-cluster-data.R')"

library(testthat)
library(tibble)

source_cluster_data_env <- function() {
  env <- new.env(parent = globalenv())
  env$generate_cluster_hash <- function(identifiers, cluster_type) "GENERATED_FROM_IDS"
  source_api_file("functions/llm-batch-cluster-data.R", local = FALSE, envir = env)
  env
}

test_that("functional row extracts identifiers + hash from equals(hash,...) filter", {
  env <- source_cluster_data_env()
  row <- tibble::tibble(
    cluster = 1L,
    identifiers = list(tibble::tibble(symbol = c("A", "B"), hgnc_id = c("HGNC:1", "HGNC:2"))),
    hash_filter = "equals(hash,f556d8b467)"
  )
  out <- env$llm_batch_build_cluster_data(row, "functional", 1L)
  expect_true(out$ok)
  expect_equal(out$cluster_hash, "f556d8b467")
  expect_equal(out$cluster_data$identifiers$hgnc_id, c("HGNC:1", "HGNC:2"))
})

test_that("phenotype row keeps quali_inp_var and a bare hash_filter", {
  env <- source_cluster_data_env()
  row <- tibble::tibble(
    cluster = 2L,
    identifiers = list(tibble::tibble(entity_id = c(1L, 2L, 3L))),
    hash_filter = "175f540336",
    quali_inp_var = list(tibble::tibble(variable = "Seizure", `v.test` = 3.2, `p.value` = 0.01))
  )
  out <- env$llm_batch_build_cluster_data(row, "phenotype", 2L)
  expect_true(out$ok)
  expect_equal(out$cluster_hash, "175f540336")
  expect_equal(out$cluster_data$identifiers$entity_id, c(1L, 2L, 3L))
  expect_true(is.data.frame(out$cluster_data$quali_inp_var))
  expect_equal(out$cluster_data$quali_inp_var$variable, "Seizure")
})

test_that("functional row missing hgnc_id is not ok", {
  env <- source_cluster_data_env()
  row <- tibble::tibble(
    identifiers = list(tibble::tibble(symbol = "A")),
    hash_filter = "h"
  )
  out <- env$llm_batch_build_cluster_data(row, "functional", 1L)
  expect_false(out$ok)
  expect_match(out$reason, "hgnc_id")
})

test_that("row with no identifiers is not ok", {
  env <- source_cluster_data_env()
  row <- tibble::tibble(cluster = 1L)
  out <- env$llm_batch_build_cluster_data(row, "phenotype", 1L)
  expect_false(out$ok)
  expect_match(out$reason, "no identifiers")
})

test_that("no hash_filter falls back to generate_cluster_hash from identifiers", {
  env <- source_cluster_data_env()
  row <- tibble::tibble(
    identifiers = list(tibble::tibble(entity_id = c(5L, 6L)))
  )
  out <- env$llm_batch_build_cluster_data(row, "phenotype", 3L)
  expect_true(out$ok)
  expect_equal(out$cluster_hash, "GENERATED_FROM_IDS")
})
