# Connection-participation contracts for the atomic review-save coordinator.

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)
source_api_file("functions/review-repository.R", local = FALSE)
source_api_file("functions/publication-repository.R", local = FALSE)
source_api_file("functions/phenotype-repository.R", local = FALSE)
source_api_file("functions/ontology-repository.R", local = FALSE)

test_that("review update and re-review marker use a supplied connection without nesting", {
  update_fn <- review_update
  marker_fn <- review_update_re_review_status
  captured <- list()

  mockery::stub(update_fn, "db_with_transaction", function(...) {
    stop("review_update must not start a nested transaction")
  })
  mockery::stub(update_fn, "db_execute_statement", function(sql, params, conn = NULL) {
    captured[[length(captured) + 1L]] <<- conn
    1L
  })
  mockery::stub(marker_fn, "db_execute_statement", function(sql, params, conn = NULL) {
    captured[[length(captured) + 1L]] <<- conn
    1L
  })

  expect_silent(update_fn(12L, list(synopsis = "updated"), conn = "caller-connection"))
  expect_silent(marker_fn(4L, 12L, conn = "caller-connection"))
  expect_true(all(vapply(captured, identical, logical(1), "caller-connection")))
})

test_that("review association replace paths participate in a supplied connection", {
  cases <- list(
    list(
      fn = publication_replace_for_review,
      payload = tibble::tibble(publication_id = "PMID:1", publication_type = "additional_references")
    ),
    list(
      fn = phenotype_replace_for_review,
      payload = tibble::tibble(phenotype_id = "HP:0000001", modifier_id = 1L)
    ),
    list(
      fn = variation_ontology_replace_for_review,
      payload = tibble::tibble(vario_id = "VariO:0001", modifier_id = 1L)
    )
  )

  for (case in cases) {
    fn <- case$fn
    captured <- list()
    mockery::stub(fn, "db_with_transaction", function(...) {
      stop("replace path must not start a nested transaction")
    })
    mockery::stub(fn, "db_execute_statement", function(sql, params, conn = NULL) {
      captured[[length(captured) + 1L]] <<- conn
      1L
    })

    expect_silent(fn(12L, 4L, case$payload, conn = "caller-connection"))
    expect_true(length(captured) >= 2L)
    expect_true(all(vapply(captured, identical, logical(1), "caller-connection")))
  }
})
