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
    # #635: `publication_replace_for_review()` now also READS, to log a shrinking
    # publication set. That read must go through the caller's connection like every
    # other statement here, so it is captured into the same list and covered by the
    # all-identical assertion below rather than being stubbed away silently.
    mockery::stub(fn, "db_execute_query", function(sql, params, conn = NULL) {
      captured[[length(captured) + 1L]] <<- conn
      data.frame(n = 0L)
    })

    expect_silent(fn(12L, 4L, case$payload, conn = "caller-connection"))
    expect_true(length(captured) >= 2L)
    expect_true(all(vapply(captured, identical, logical(1), "caller-connection")))
  }
})

test_that("#635: the publication replace path reads its prior count on the caller's connection", {
  # The shrink warning is the only signal that a curated publication was dropped, and it
  # is only trustworthy if it counts the rows INSIDE the caller's transaction. Reading it
  # on the pool would race the very DELETE it is describing.
  fn <- publication_replace_for_review
  queries <- list()

  mockery::stub(fn, "db_with_transaction", function(...) {
    stop("replace path must not start a nested transaction")
  })
  mockery::stub(fn, "db_execute_statement", function(sql, params, conn = NULL) 1L)
  mockery::stub(fn, "db_execute_query", function(sql, params, conn = NULL) {
    queries[[length(queries) + 1L]] <<- list(sql = sql, params = params, conn = conn)
    data.frame(n = 3L)
  })

  # 3 existing -> 1 submitted, so this shrinks. `log_warn()` writes to the logger, not
  # an R warning condition, so there is nothing to muffle here.
  fn(
    12L, 4L,
    tibble::tibble(publication_id = "PMID:1", publication_type = "additional_references"),
    conn = "caller-connection"
  )

  expect_length(queries, 1L)
  expect_match(queries[[1L]]$sql, "COUNT\\(\\*\\)")
  expect_match(queries[[1L]]$sql, "ndd_review_publication_join")
  expect_identical(queries[[1L]]$conn, "caller-connection")
  expect_identical(queries[[1L]]$params, list(12L))
})

test_that("#635: a non-shrinking publication replace reads the count but does not warn", {
  fn <- publication_replace_for_review
  mockery::stub(fn, "db_with_transaction", function(...) stop("no nested transaction"))
  mockery::stub(fn, "db_execute_statement", function(sql, params, conn = NULL) 1L)
  mockery::stub(fn, "db_execute_query", function(sql, params, conn = NULL) data.frame(n = 1L))

  # 1 existing -> 2 submitted is growth; 0 existing -> 0 submitted is the first write.
  expect_silent(
    fn(
      12L, 4L,
      tibble::tibble(
        publication_id = c("PMID:1", "PMID:2"),
        publication_type = c("additional_references", "additional_references")
      ),
      conn = "caller-connection"
    )
  )
})
