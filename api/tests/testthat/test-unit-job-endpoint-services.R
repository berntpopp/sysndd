# tests/testthat/test-unit-job-endpoint-services.R
#
# Host-runnable unit tests for the PUBLIC clustering submission service extracted
# from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
# submission-service.R (base coverage only). Its category_filter / provenance /
# dedup-hash-payload coverage (#574 D2) was split out to
# test-unit-job-endpoint-services-category.R to keep both files under the
# 600-line ceiling after the #574 Codex-review-fix rounds grew that coverage.
# The sibling job-phenotype-submission-service.R coverage lives in
# test-unit-job-endpoint-services-phenotype.R (split out here, #574
# Codex-review-fix pass, to keep both files under the 600-line ceiling after this
# file gained empty-genes/dedup-provenance coverage). The maintenance-submission
# (job-maintenance-submission-service.R) and query-endpoint
# (job-query-endpoint-service.R) services are covered in
# test-unit-job-endpoint-services-maintenance.R. Shared fixtures live in
# job-endpoint-services-fixtures.R (explicitly sourced below by every file in this
# family). Split this way to keep every file under the 600-line ceiling (#535 S6).
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

test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
    entity_id = 1:3,
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    ndd_phenotype = c(1L, 0L, 1L)
  ))
  job_endpoint_stub_all_ndd_universe(env)
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
  job_endpoint_stub_clustering_provenance(env)
  env$gen_string_clust_obj_mem <- function(genes, algorithm = "leiden") {
    clusters <- tibble::tibble(term_enrichment = list(tibble::tibble(category = "HPO")))
    # Set on the served membership, mirroring what the real STRING resolver
    # attaches (#514 channel observability) -- the cache-hit meta must carry
    # this through as `effective_fingerprint$weight_channel`.
    attr(clusters, "weight_channel") <- "experimental_database"
    clusters
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

  # #574 D2 review fix: the cache-hit `result` (the job's stored, served
  # payload -- distinct from `out`, the submit response) must carry the full
  # provenance block through `meta`, not just the two fields asserted above.
  result_meta <- store_args$result$meta
  expect_equal(result_meta$effective_fingerprint$weight_channel, "experimental_database")
  expect_equal(result_meta$selector$kind, "explicit")
  expect_equal(result_meta$gene_list_sha256, "sha-1") # job_endpoint_stub_clustering_provenance: paste0("sha-", length(genes))
  expect_equal(result_meta$source_data_version, "srcv-test") # job_endpoint_stub_clustering_provenance stub token

  # Codex round-3 fix: the cache-hit path also derives a provenance-free
  # `hash_payload` for the dedup identity, while `request_payload` (asserted
  # above via `result_meta`) keeps `provenance` in the STORED payload.
  expect_true("provenance" %in% names(store_args$request_payload))
  expect_false("provenance" %in% names(store_args$hash_payload))
  expect_false("category_filter" %in% names(store_args$hash_payload))
})

test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
  req <- list(argsBody = list(genes = list("HGNC:1"), algorithm = "walktrap"), user = list(user_id = NULL))

  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env)
  job_endpoint_stub_clustering_provenance(env)
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env$async_job_capacity_exceeded <- function(...) TRUE
  env$async_job_active_count <- function(...) 99L
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_functional_clustering(req, res)
  expect_equal(res$status, 503)
  expect_equal(res$headers[["Retry-After"]], "60")
  expect_equal(out$error, "CAPACITY_EXCEEDED")

  env$async_job_capacity_exceeded <- function(...) FALSE
  captured <- NULL
  # Cache-miss path calls `async_job_service_submit()` directly (not
  # `create_job()`, which is arity-guarded at exactly `(operation, params)`)
  # so it can thread a provenance-free `hash_payload` override alongside the
  # full `request_payload`.
  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
                                            submitted_by = NULL, ...) {
    captured <<- list(
      job_type = job_type,
      request_payload = request_payload,
      hash_payload = hash_payload
    )
    list(job = tibble::tibble(job_id = "new-job-1"))
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_functional_clustering(req, res)
  expect_equal(res$status, 202)
  expect_equal(res$headers[["Retry-After"]], "5")
  expect_equal(out$job_id, "new-job-1")
  expect_equal(captured$job_type, "clustering")
  expect_setequal(
    names(captured$request_payload),
    # #574 D2: every submit path now carries a `provenance` block; explicit/
    # no-arg submits still omit `category_filter` (asserted separately below).
    c("genes", "algorithm", "category_links", "string_id_table", "provenance")
  )
  expect_false("category_filter" %in% names(captured$request_payload))

  # Codex round-3 fix: the dedup HASH payload must exclude `provenance` (and
  # any absent `category_filter`) so the dedup identity stays byte-identical
  # to pre-#574, even though the STORED request payload
  # (`captured$request_payload`, asserted above) still carries `provenance`.
  expect_false("provenance" %in% names(captured$hash_payload))
  expect_false("category_filter" %in% names(captured$hash_payload))
  expect_identical(
    captured$hash_payload,
    list(
      genes = captured$request_payload$genes,
      algorithm = captured$request_payload$algorithm,
      category_links = captured$request_payload$category_links,
      string_id_table = captured$request_payload$string_id_table
    )
  )
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
  submit_called <- FALSE
  env$async_job_service_submit <- function(...) {
    submit_called <<- TRUE
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
  expect_false(submit_called)
})

# job-functional-submission-service.R's category_filter / provenance / dedup
# coverage (#574 D2) lives in test-unit-job-endpoint-services-category.R, and
# job-phenotype-submission-service.R coverage lives in
# test-unit-job-endpoint-services-phenotype.R (both split out to keep this
# file under the 600-line ceiling, #574 Codex-review-fix pass).
