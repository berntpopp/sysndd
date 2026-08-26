# Unit contracts for the focused review-save coordinator.

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/publication-write-preparation.R", local = FALSE)

review_write_service_path <- file.path(
  get_api_dir(), "services", "review-write-service.R"
)
if (file.exists(review_write_service_path)) {
  source_api_file("functions/db-transaction-scope.R", local = FALSE)
source_api_file("services/review-write-service.R", local = FALSE)
}

review_write_minimum_request <- function(phenotypes = tibble::tibble(),
                                         variation_ontology = tibble::tibble()) {
  list(
    method = "POST",
    review_data = list(entity_id = 1L, synopsis = "A valid synopsis."),
    publications = tibble::tibble(),
    phenotypes = phenotypes,
    variation_ontology = variation_ontology,
    re_review = FALSE,
    direct_approval = FALSE,
    review_user_id = 1L,
    db = "fake-pool"
  )
}

test_that("blank or null ontology identifiers fail before external preparation or mutation", {
  cases <- list(
    phenotype_tag_null = list(
      phenotypes = tibble::tibble(value = NA_character_),
      variation_ontology = tibble::tibble(),
      field = "phenotype_id"
    ),
    phenotype_explicit_null = list(
      phenotypes = tibble::tibble(phenotype_id = NA_character_, modifier_id = 1L),
      variation_ontology = tibble::tibble(),
      field = "phenotype_id"
    ),
    phenotype_empty = list(
      phenotypes = tibble::tibble(phenotype_id = "", modifier_id = 1L),
      variation_ontology = tibble::tibble(),
      field = "phenotype_id"
    ),
    phenotype_whitespace = list(
      phenotypes = tibble::tibble(phenotype_id = "   ", modifier_id = 1L),
      variation_ontology = tibble::tibble(),
      field = "phenotype_id"
    ),
    vario_tag_null = list(
      phenotypes = tibble::tibble(),
      variation_ontology = tibble::tibble(value = NA_character_),
      field = "vario_id"
    ),
    vario_explicit_null = list(
      phenotypes = tibble::tibble(),
      variation_ontology = tibble::tibble(vario_id = NA_character_, modifier_id = 1L),
      field = "vario_id"
    ),
    vario_empty = list(
      phenotypes = tibble::tibble(),
      variation_ontology = tibble::tibble(vario_id = "", modifier_id = 1L),
      field = "vario_id"
    ),
    vario_whitespace = list(
      phenotypes = tibble::tibble(),
      variation_ontology = tibble::tibble(vario_id = "  ", modifier_id = 1L),
      field = "vario_id"
    )
  )

  for (case in cases) {
    prepared <- FALSE
    mutated <- FALSE
    request <- review_write_minimum_request(
      phenotypes = case$phenotypes,
      variation_ontology = case$variation_ontology
    )
    request$prepare_fn <- function(...) {
      prepared <<- TRUE
      list()
    }
    request$mutation_fn <- function(...) {
      mutated <<- TRUE
      list(review_id = 1L)
    }
    request$transaction_runner <- function(...) stop("transaction must not start")

    expect_error(
      do.call(svc_review_write, request),
      class = "error_400",
      regexp = case$field
    )
    expect_false(prepared)
    expect_false(mutated)
  }
})

test_that("literal NULL ontology fields fail before tibble coercion or mutation", {
  cases <- list(
    phenotype_explicit = list(
      phenotypes = list(phenotype_id = NULL, modifier_id = 1L),
      variation_ontology = list(),
      field = "phenotype_id"
    ),
    phenotype_tag = list(
      phenotypes = list(value = NULL),
      variation_ontology = list(),
      field = "phenotype_id"
    ),
    vario_explicit = list(
      phenotypes = list(),
      variation_ontology = list(vario_id = NULL, modifier_id = 1L),
      field = "vario_id"
    ),
    vario_tag = list(
      phenotypes = list(),
      variation_ontology = list(value = NULL),
      field = "vario_id"
    )
  )

  for (case in cases) {
    prepared <- FALSE
    mutated <- FALSE
    request <- review_write_minimum_request(
      phenotypes = case$phenotypes,
      variation_ontology = case$variation_ontology
    )
    request$prepare_fn <- function(...) {
      prepared <<- TRUE
      list()
    }
    request$mutation_fn <- function(...) {
      mutated <<- TRUE
      list(review_id = 1L)
    }
    request$transaction_runner <- function(...) stop("transaction must not start")

    expect_error(
      do.call(svc_review_write, request),
      class = "error_400",
      regexp = case$field
    )
    expect_false(prepared)
    expect_false(mutated)
  }
})

test_that("unknown modifier IDs fail before mutation", {
  had_query <- exists("db_execute_query", envir = .GlobalEnv, inherits = FALSE)
  if (had_query) {
    previous_query <- base::get("db_execute_query", envir = .GlobalEnv, inherits = FALSE)
  }
  assign("db_execute_query", function(sql, params, conn) {
    if (grepl("phenotype_list", sql, fixed = TRUE)) {
      return(tibble::tibble(phenotype_id = "HP:0000001"))
    }
    if (grepl("modifier_list", sql, fixed = TRUE)) {
      return(tibble::tibble(modifier_id = 1L))
    }
    tibble::tibble()
  }, envir = .GlobalEnv)
  withr::defer({
    if (had_query) {
      assign("db_execute_query", previous_query, envir = .GlobalEnv)
    } else {
      rm("db_execute_query", envir = .GlobalEnv)
    }
  })

  mutated <- FALSE
  request <- review_write_minimum_request(
    phenotypes = tibble::tibble(phenotype_id = "HP:0000001", modifier_id = 999L)
  )
  request$prepare_fn <- review_write_prepare
  request$mutation_fn <- function(...) {
    mutated <<- TRUE
    list(review_id = 1L)
  }
  request$transaction_runner <- function(...) stop("transaction must not start")

  expect_error(
    do.call(svc_review_write, request),
    class = "error_400",
    regexp = "modifier_id"
  )
  expect_false(mutated)
})

test_that("invalid modifiers block publication preparation and classification", {
  had_query <- exists("db_execute_query", envir = .GlobalEnv, inherits = FALSE)
  if (had_query) {
    previous_query <- base::get("db_execute_query", envir = .GlobalEnv, inherits = FALSE)
  }
  assign("db_execute_query", function(sql, params, conn) {
    if (grepl("phenotype_list", sql, fixed = TRUE)) {
      return(tibble::tibble(phenotype_id = "HP:0000001"))
    }
    if (grepl("modifier_list", sql, fixed = TRUE)) {
      return(tibble::tibble(modifier_id = integer()))
    }
    tibble::tibble()
  }, envir = .GlobalEnv)
  withr::defer({
    if (had_query) {
      assign("db_execute_query", previous_query, envir = .GlobalEnv)
    } else {
      rm("db_execute_query", envir = .GlobalEnv)
    }
  })

  preparation_called <- FALSE
  classification_called <- FALSE
  previous_preparation <- publication_write_prepare
  previous_classification <- get0("genereviews_from_pmid", envir = .GlobalEnv)
  assign("publication_write_prepare", function(...) {
    preparation_called <<- TRUE
    tibble::tibble()
  }, envir = .GlobalEnv)
  assign("genereviews_from_pmid", function(...) {
    classification_called <<- TRUE
    FALSE
  }, envir = .GlobalEnv)
  withr::defer({
    assign("publication_write_prepare", previous_preparation, envir = .GlobalEnv)
    if (is.null(previous_classification)) {
      rm("genereviews_from_pmid", envir = .GlobalEnv)
    } else {
      assign("genereviews_from_pmid", previous_classification, envir = .GlobalEnv)
    }
  })

  request <- review_write_minimum_request(
    phenotypes = tibble::tibble(phenotype_id = "HP:0000001", modifier_id = 999L)
  )
  request$publications <- tibble::tibble(
    publication_id = "PMID:99999999",
    publication_type = "additional_references"
  )
  request$mutation_fn <- function(...) stop("mutation must not run")
  request$transaction_runner <- function(...) stop("transaction must not start")

  expect_error(do.call(svc_review_write, request), class = "error_400")
  expect_false(preparation_called)
  expect_false(classification_called)
})

test_that("missing modifier IDs fail before external preparation or mutation", {
  mutated <- FALSE
  request <- review_write_minimum_request(
    phenotypes = list(phenotype_id = "HP:0000001", modifier_id = NULL)
  )
  request$prepare_fn <- function(...) stop("preparation must not run")
  request$mutation_fn <- function(...) {
    mutated <<- TRUE
    list(review_id = 1L)
  }
  request$transaction_runner <- function(...) stop("transaction must not start")

  expect_error(
    do.call(svc_review_write, request),
    class = "error_400",
    regexp = "modifier_id"
  )
  expect_false(mutated)
})

test_that("a caller-owned RMariaDB transaction is used directly without nested begin", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    transaction_starts <- 0L
    received_conn <- NULL

    result <- review_write_run_mutation(
      prepared = list(),
      db = conn,
      mutation_fn = function(prepared, txn_conn) {
        received_conn <<- txn_conn
        DBI::dbGetQuery(txn_conn, "SELECT 1 AS connected")
        list(review_id = 21L)
      },
      transaction_runner = function(...) {
        transaction_starts <<- transaction_starts + 1L
        stop("nested transaction must not start")
      }
    )

    expect_identical(received_conn, conn)
    expect_equal(transaction_starts, 0L)
    expect_equal(result$review_id, 21L)
  })
})

test_that("a pool-owned review save opens exactly one transaction and returns scalar success", {
  transaction_starts <- 0L
  received_conn <- NULL
  request <- review_write_minimum_request()
  request$prepare_fn <- function(...) list(prepared = TRUE)
  request$mutation_fn <- function(prepared, txn_conn, ...) {
    received_conn <<- txn_conn
    list(review_id = 42L)
  }
  request$transaction_runner <- function(code, pool_obj = NULL) {
    transaction_starts <<- transaction_starts + 1L
    expect_identical(pool_obj, "fake-pool")
    code("checked-out-connection")
  }

  result <- do.call(svc_review_write, request)

  expect_equal(transaction_starts, 1L)
  expect_identical(received_conn, "checked-out-connection")
  expect_type(result$status, "integer")
  expect_length(result$status, 1L)
  expect_identical(result$status, 200L)
  expect_type(result$message, "character")
  expect_length(result$message, 1L)
})

test_that("publication preparation fetches missing rows before persistence and starts no transaction", {
  fn <- publication_write_prepare
  calls <- character()
  mockery::stub(fn, "db_execute_query", function(...) {
    calls <<- c(calls, "lookup")
    tibble::tibble(publication_id = character())
  })
  mockery::stub(fn, "check_pmid", function(...) {
    calls <<- c(calls, "validate_pmid")
    TRUE
  })
  mockery::stub(fn, "info_from_pmid", function(...) {
    calls <<- c(calls, "fetch_pubmed")
    tibble::tibble(Title = "Fetched title")
  })

  prepared <- fn(
    tibble::tibble(
      publication_id = "PMID:101",
      publication_type = "additional_references"
    ),
    db = "fake-db"
  )

  expect_equal(calls, c("lookup", "validate_pmid", "fetch_pubmed"))
  expect_true("publication_id" %in% names(prepared))
  expect_false(grepl("db_execute_statement|db_with_transaction", paste(deparse(body(fn)), collapse = "")))
})

test_that("GeneReviews classification converts publication type candidates before persistence", {
  had_classifier <- exists("genereviews_from_pmid", envir = .GlobalEnv, inherits = FALSE)
  if (had_classifier) {
    previous_classifier <- base::get("genereviews_from_pmid", envir = .GlobalEnv, inherits = FALSE)
  }
  assign("genereviews_from_pmid", function(publication_id, check) {
    identical(publication_id, "PMID:101")
  }, envir = .GlobalEnv)
  withr::defer({
    if (had_classifier) {
      assign("genereviews_from_pmid", previous_classifier, envir = .GlobalEnv)
    } else {
      rm("genereviews_from_pmid", envir = .GlobalEnv)
    }
  })

  classified <- publication_write_classify_genereviews(tibble::tibble(
    publication_id = c("PMID:101", "PMID:102"),
    publication_type = c("additional_references", "gene_review")
  ))

  expect_equal(
    classified$publication_type,
    c("gene_review", "additional_references")
  )
})

test_that("unresolved publication input is rejected before the review mutation callback", {
  fn <- publication_write_prepare
  fetch_called <- FALSE
  mockery::stub(fn, "db_execute_query", function(...) {
    tibble::tibble(publication_id = character())
  })
  mockery::stub(fn, "check_pmid", function(...) FALSE)
  mockery::stub(fn, "info_from_pmid", function(...) {
    fetch_called <<- TRUE
    tibble::tibble()
  })

  expect_error(
    fn(
      tibble::tibble(publication_id = "PMID:999", publication_type = "additional_references"),
      db = "fake-db"
    ),
    class = "publication_fetch_error"
  )
  expect_false(fetch_called)
})
