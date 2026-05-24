library(testthat)
library(tibble)

source_llm_service_for_db_access_tests <- function() {
  env <- new.env(parent = globalenv())
  env$generate_cluster_hash <- function(...) "unused"
  env$validate_summary_entities <- function(...) list(valid = TRUE)
  env$get_default_gemini_model <- function() "gemini-test"
  env$get_db_connection <- function() structure(list(), class = "Pool")

  source_api_file("functions/llm-service.R", local = FALSE, envir = env)
  env
}

test_that("functional cluster data fetch queries pooled connections through DBI", {
  env <- source_llm_service_for_db_access_tests()
  db_calls <- character()

  env$gen_string_clust_obj_mem <- function(genes, algorithm = "leiden") {
    expect_equal(algorithm, "leiden")
    expect_equal(genes, c("HGNC:1", "HGNC:2"))

    tibble::tibble(
      cluster = 2L,
      identifiers = list(tibble::tibble(hgnc_id = genes, symbol = c("GENE1", "GENE2"))),
      hash_filter = "equals(hash,functional-hash)",
      term_enrichment = list(tibble::tibble(
        category = "GO",
        term_name = "synapse organization",
        p_value = 0.001,
        fdr = 0.01
      ))
    )
  }

  mockery::stub(
    env$fetch_functional_cluster_data,
    "DBI::dbGetQuery",
    function(conn, statement, ...) {
      db_calls <<- c(db_calls, statement)
      expect_s3_class(conn, "Pool")
      tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2"))
    }
  )

  result <- env$fetch_functional_cluster_data("functional-hash")

  expect_equal(length(db_calls), 1L)
  expect_equal(result$cluster_number, 2L)
  expect_equal(result$identifiers$hgnc_id, c("HGNC:1", "HGNC:2"))
  expect_equal(result$term_enrichment$term, "synapse organization")
})

test_that("llm service does not call dbGetQuery through the pool namespace", {
  source <- readLines(file.path(get_api_dir(), "functions", "llm-service.R"), warn = FALSE)

  expect_false(any(grepl("pool::dbGetQuery", source, fixed = TRUE)))
})

test_that("phenotype cluster data fetch uses the shared phenotype clustering helper", {
  env <- source_llm_service_for_db_access_tests()

  env$generate_phenotype_clusters <- function() {
    tibble::tibble(
      cluster = 4L,
      identifiers = list(tibble::tibble(
        entity_id = c(101L, 102L),
        hgnc_id = c("HGNC:1", "HGNC:2"),
        symbol = c("GENE1", "GENE2")
      )),
      hash_filter = "equals(hash,phenotype-hash)",
      cluster_size = 2L,
      quali_inp_var = list(tibble::tibble(
        variable = "Seizure",
        p.value = 0.01,
        v.test = 3.2
      ))
    )
  }

  result <- env$fetch_phenotype_cluster_data("phenotype-hash")

  expect_equal(result$cluster_number, 4L)
  expect_equal(result$identifiers$entity_id, c(101L, 102L))
  expect_equal(result$identifiers$symbol, c("GENE1", "GENE2"))
  expect_equal(result$quali_inp_var$variable, "Seizure")
})

test_that("on-demand summary generation uses configured default Gemini model", {
  env <- source_llm_service_for_db_access_tests()
  captured_model <- NULL

  env$generate_cluster_hash <- function(...) "summary-hash"
  env$get_cached_summary <- function(...) NULL
  env$generate_cluster_summary <- function(cluster_data, cluster_type, model, ...) {
    captured_model <<- model
    list(
      success = TRUE,
      summary = list(summary = "Generated summary", tags = character()),
      validation = list(is_valid = TRUE)
    )
  }
  env$calculate_derived_confidence <- function(...) list(score = "high")
  env$save_summary_to_cache <- function(cluster_type, cluster_number, cluster_hash,
                                        model_name, ...) {
    expect_equal(model_name, "gemini-test")
    123L
  }

  result <- env$get_or_generate_summary(
    cluster_data = list(
      identifiers = tibble::tibble(hgnc_id = c(1L, 2L)),
      term_enrichment = tibble::tibble(),
      cluster_number = 7L
    ),
    cluster_type = "functional"
  )

  expect_true(result$success)
  expect_equal(captured_model, "gemini-test")
})
