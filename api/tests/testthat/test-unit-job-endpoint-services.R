# tests/testthat/test-unit-job-endpoint-services.R
#
# Host-runnable unit tests for the PUBLIC clustering submission services extracted
# from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
# submission-service.R and job-phenotype-submission-service.R. The maintenance-
# submission (job-maintenance-submission-service.R) and query-endpoint
# (job-query-endpoint-service.R) services are covered in the sibling
# test-unit-job-endpoint-services-maintenance.R. Shared fixtures live in
# job-endpoint-services-fixtures.R (explicitly sourced below). Split this way to keep
# every file under the 600-line ceiling (#535 S6).
#
# Each service is sourced directly into an isolated environment via sys.source()
# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
# async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
# gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
# exercise pure request/response logic without a live DB or mirai daemon pool.

# Resolve api_dir robustly so the file runs both under the full suite and a single-file
# testthat::test_file(), then source the shared fixtures.
if (exists("get_api_dir")) {
  api_dir <- get_api_dir()
} else {
  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
  if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
    api_dir <- normalizePath(getwd(), mustWork = FALSE)
  }
}
# local = TRUE keeps the shared helpers in this test file's environment (as if defined
# inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)

## -------------------------------------------------------------------##
## job-functional-submission-service.R
## -------------------------------------------------------------------##

job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
  tables <- list(
    non_alt_loci_set = tibble::tibble(
      symbol = c("A", "B"),
      hgnc_id = c("HGNC:1", "HGNC:3"),
      STRING_id = c("9606.P1", "9606.P2")
    )
  )
  if (!is.null(ndd_entity_view)) {
    tables$ndd_entity_view <- ndd_entity_view
  }
  job_endpoint_fake_pool(env, tables)
}

test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
    entity_id = 1:3,
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    ndd_phenotype = c(1L, 0L, 1L)
  ))
  captured <- NULL
  env$check_duplicate_job <- function(operation, params) {
    captured <<- params
    list(duplicate = TRUE, existing_job_id = "dup-1")
  }
  req <- list(argsBody = list(), user = list(user_id = NULL))
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_functional_clustering(req, res)

  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
  expect_equal(captured$algorithm, "leiden")
  expect_equal(res$status, 409)
  expect_equal(out$error, "DUPLICATE_JOB")
  expect_match(res$headers[["Location"]], "/api/jobs/dup-1/status")
})

job_endpoint_capture_functional_algorithm <- function(algorithm_body) {
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env)
  captured <- NULL
  env$check_duplicate_job <- function(operation, params) {
    captured <<- params
    list(duplicate = TRUE, existing_job_id = "dup-1")
  }
  req <- list(argsBody = list(genes = list("HGNC:9"), algorithm = algorithm_body), user = list(user_id = NULL))
  env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
  captured$algorithm
}

test_that("functional clustering: algorithm input is coerced to a lowercase scalar, invalid falls back to leiden", {
  expect_equal(job_endpoint_capture_functional_algorithm(list("WALKTRAP", "ignored")), "walktrap")
  expect_equal(job_endpoint_capture_functional_algorithm("bogus"), "leiden")
})

test_that("functional clustering: cache hit stores a completed job without calling create_job", {
  local_mocked_bindings(
    has_cache = function(f) function(...) TRUE,
    .package = "memoise"
  )
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env)
  env$gen_string_clust_obj_mem <- function(genes, algorithm = "leiden") {
    tibble::tibble(term_enrichment = list(tibble::tibble(category = "HPO")))
  }
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  store_args <- NULL
  env$async_job_service_store_completed <- function(...) {
    store_args <<- list(...)
    tibble::tibble(job_id = "cached-job-1")
  }
  create_job_called <- FALSE
  env$create_job <- function(...) {
    create_job_called <<- TRUE
  }
  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = 42L))
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_functional_clustering(req, res)

  expect_false(create_job_called)
  expect_equal(res$status, 202)
  expect_equal(res$headers[["Retry-After"]], "0")
  expect_equal(out$job_id, "cached-job-1")
  expect_equal(out$meta$llm_generation, "snapshot_refresh_owned")
  expect_equal(store_args$submitted_by, 42L)
})

test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
  req <- list(argsBody = list(genes = list("HGNC:1"), algorithm = "walktrap"), user = list(user_id = NULL))

  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env)
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env$async_job_capacity_exceeded <- function(...) TRUE
  env$async_job_active_count <- function(...) 99L
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_functional_clustering(req, res)
  expect_equal(res$status, 503)
  expect_equal(res$headers[["Retry-After"]], "60")
  expect_equal(out$error, "CAPACITY_EXCEEDED")

  env$async_job_capacity_exceeded <- function(...) FALSE
  create_job_operation <- NULL
  env$create_job <- function(operation, params) {
    create_job_operation <<- operation
    list(job_id = "new-job-1", status = "accepted", estimated_seconds = 30)
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_functional_clustering(req, res)
  expect_equal(res$status, 202)
  expect_equal(res$headers[["Retry-After"]], "5")
  expect_equal(out$job_id, "new-job-1")
  expect_equal(create_job_operation, "clustering")
})

test_that("functional clustering: admission throttle runs FIRST, before any DB/cache work", {
  # #535 S6 BLOCKER fix: a throttle block must short-circuit before the cache/dup/DB
  # path so an abusive caller cannot bypass the limit or grow async_jobs via cache
  # hits. The guard returning admitted=FALSE must return its response and touch nothing.
  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = NULL))
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  pool_touched <- FALSE
  env$pool <- structure(list(), class = "trap_pool")
  env$tbl.trap_pool <- function(src, from, ...) {
    pool_touched <<- TRUE
    stop("DB must not be touched when the throttle blocks")
  }
  create_job_called <- FALSE
  env$create_job <- function(...) {
    create_job_called <<- TRUE
    NULL
  }
  env$async_job_submit_admission_guard <- function(req, res) {
    res$status <- 429
    res$setHeader("Retry-After", "42")
    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_functional_clustering(req, res)
  expect_equal(res$status, 429)
  expect_equal(out$error, "RATE_LIMITED")
  expect_false(pool_touched)
  expect_false(create_job_called)
})

## -------------------------------------------------------------------##
## job-phenotype-submission-service.R
## -------------------------------------------------------------------##

job_endpoint_phenotype_single_entity_pool <- function(env) {
  job_endpoint_fake_pool(env, list(
    ndd_entity_view = tibble::tibble(
      entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1",
      ndd_phenotype = 1L, category = "Definitive"
    ),
    ndd_entity_review = tibble::tibble(
      review_id = 1L, entity_id = 1L, is_primary = 1L, review_approved = 1L
    ),
    ndd_review_phenotype_connect = tibble::tibble(
      review_id = 1L, entity_id = 1L, modifier_id = 1L,
      phenotype_id = "HP:0000001", hpo_mode_of_inheritance_term_name = "AD"
    ),
    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
    phenotype_list = tibble::tibble(phenotype_id = "HP:0000001", HPO_term = "Term1")
  ))
}

test_that("phenotype clustering: review set is gated on is_primary AND review_approved", {
  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
  env$pool <- job_endpoint_fake_pool(env, list(
    ndd_entity_view = tibble::tibble(
      entity_id = c(1L, 2L), hgnc_id = c("HGNC:1", "HGNC:2"), symbol = c("GENE1", "GENE2"),
      ndd_phenotype = c(1L, 1L), category = c("Definitive", "Definitive")
    ),
    # review_id 1: primary + approved (kept). review_id 2: primary but NOT
    # approved (must be dropped). review_id 3: approved but NOT primary
    # (must be dropped) — the #3/Codex-PR-2 guard this test protects.
    ndd_entity_review = tibble::tibble(
      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L),
      is_primary = c(1L, 1L, 0L), review_approved = c(1L, 0L, 1L)
    ),
    ndd_review_phenotype_connect = tibble::tibble(
      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L), modifier_id = c(1L, 1L, 1L),
      phenotype_id = c("HP:0000001", "HP:0000002", "HP:0000001"),
      hpo_mode_of_inheritance_term_name = c("AD", "AD", "AD")
    ),
    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
    phenotype_list = tibble::tibble(
      phenotype_id = c("HP:0000001", "HP:0000002"), HPO_term = c("Term1", "Term2")
    )
  ))
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env$async_job_capacity_exceeded <- function(...) FALSE
  env$async_job_active_count <- function(...) 0L
  captured_params <- NULL
  env$create_job <- function(operation, params) {
    captured_params <<- params
    list(job_id = "job-x", status = "accepted", estimated_seconds = 30)
  }
  req <- list(user = list(user_id = NULL))
  res <- job_endpoint_fake_res()

  env$svc_job_submit_phenotype_clustering(req, res)

  # Only review_id 1 (primary + approved) survives the gather step; review 2
  # (unapproved) and review 3 (not primary) must never reach the clustering
  # input, even though review 2 is attached to the same (otherwise-included)
  # entity_id as review 1.
  expect_equal(captured_params$ndd_entity_review_tbl$review_id, 1L)
})

test_that("phenotype clustering: duplicate job returns 409 with Location", {
  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
  env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = "dup-pheno")
  req <- list(user = list(user_id = NULL))
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_phenotype_clustering(req, res)

  expect_equal(res$status, 409)
  expect_equal(out$error, "DUPLICATE_JOB")
  expect_match(res$headers[["Location"]], "/api/jobs/dup-pheno/status")
})

test_that("phenotype clustering: cache hit stores a completed job without calling create_job", {
  local_mocked_bindings(
    has_cache = function(f) function(...) TRUE,
    .package = "memoise"
  )
  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env$gen_mca_clust_obj_mem <- function(df) {
    tibble::tibble(cluster = 1L, identifiers = list(tibble::tibble(entity_id = "1")))
  }
  store_args <- NULL
  env$async_job_service_store_completed <- function(...) {
    store_args <<- list(...)
    tibble::tibble(job_id = "cached-pheno-1")
  }
  create_job_called <- FALSE
  env$create_job <- function(...) create_job_called <<- TRUE
  req <- list(user = list(user_id = 7L))
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_phenotype_clustering(req, res)

  expect_false(create_job_called)
  expect_equal(res$status, 202)
  expect_equal(out$job_id, "cached-pheno-1")
  expect_equal(store_args$submitted_by, 7L)
})

test_that("phenotype clustering: capacity guard (503) then a cache miss under capacity (202)", {
  req <- list(user = list(user_id = NULL))

  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env$async_job_capacity_exceeded <- function(...) TRUE
  env$async_job_active_count <- function(...) 5L
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_phenotype_clustering(req, res)
  expect_equal(res$status, 503)
  expect_equal(res$headers[["Retry-After"]], "60")
  expect_equal(out$error, "CAPACITY_EXCEEDED")

  env$async_job_capacity_exceeded <- function(...) FALSE
  env$create_job <- function(operation, params) {
    list(job_id = "new-pheno-1", status = "accepted", estimated_seconds = 30)
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_phenotype_clustering(req, res)
  expect_equal(res$status, 202)
  expect_equal(res$headers[["Retry-After"]], "5")
  expect_equal(out$job_id, "new-pheno-1")
  # estimated_seconds is hardcoded to 60 for the new-submit response (matches
  # the original handler, which does not thread through create_job's value).
  expect_equal(out$estimated_seconds, 60)
})

test_that("phenotype clustering service source keeps is_primary filters paired with review_approved", {
  # Defense-in-depth mirror of test-unit-phenotype-clustering-approved-guard.R
  # (which scans endpoints/jobs_endpoints.R) now that the logic lives here.
  src <- readLines(file.path(get_api_dir(), "services", "job-phenotype-submission-service.R"), warn = FALSE)
  body <- paste(src, collapse = "\n")
  matches <- gregexpr("filter\\([^)]*is_primary[^)]*\\)", body)[[1]]
  if (matches[1] != -1) {
    lens <- attr(matches, "match.length")
    for (i in seq_along(matches)) {
      frag <- substr(body, matches[i], matches[i] + lens[i] - 1)
      expect_true(grepl("review_approved", frag),
                  info = paste("is_primary filter without review_approved:", frag))
    }
  }
  succeed()
})

test_that("phenotype clustering: admission throttle runs FIRST, before collecting tables", {
  # #535 S6 BLOCKER fix: the phenotype path otherwise collects five whole tables and
  # builds the MCA matrix before admission. A blocked caller must touch nothing.
  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
  pool_touched <- FALSE
  env$pool <- structure(list(), class = "trap_pool")
  env$tbl.trap_pool <- function(src, from, ...) {
    pool_touched <<- TRUE
    stop("DB must not be touched when the throttle blocks")
  }
  create_job_called <- FALSE
  env$create_job <- function(...) {
    create_job_called <<- TRUE
    NULL
  }
  env$async_job_submit_admission_guard <- function(req, res) {
    res$status <- 429
    res$setHeader("Retry-After", "42")
    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_phenotype_clustering(list(user = list(user_id = NULL)), res)
  expect_equal(res$status, 429)
  expect_equal(out$error, "RATE_LIMITED")
  expect_false(pool_touched)
  expect_false(create_job_called)
})
