# tests/testthat/test-unit-job-endpoint-services.R
#
# Host-runnable unit tests for the PUBLIC clustering submission service extracted
# from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
# submission-service.R. The sibling job-phenotype-submission-service.R coverage
# lives in test-unit-job-endpoint-services-phenotype.R (split out here, #574
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

#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
#' (#574 D2): reads `ndd_phenotype == 1` rows straight off `env$pool`'s fake
#' `ndd_entity_view`, mirroring what the real resolver's NULL branch
#' (`generate_ndd_hgnc_ids()`) would compute -- without needing the real
#' function (and its DB-query internals) sourced into these isolated envs.
job_endpoint_stub_all_ndd_universe <- function(env) {
  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
    testthat::expect_null(category_filter)
    tbl <- env$pool$tables$ndd_entity_view
    hgnc_ids <- unique(dplyr::pull(dplyr::filter(tbl, ndd_phenotype == 1), hgnc_id))
    list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids))
  }
}

#' Cheap provenance stubs (#574 D2): every submit path that reaches past dedup
#' now computes `intended_fingerprint`/`gene_list_sha256`/`source_data_version`
#' regardless of selector kind, so any test reaching that far needs these
#' three bare globals stubbed even when it does not care about their values.
job_endpoint_stub_clustering_provenance <- function(env) {
  env$analysis_string_cache_fingerprint <- function() "fp-test"
  env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
  env$clustering_cached_source_data_version <- function(...) "srcv-test"
}

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
  create_job_operation <- NULL
  create_job_params <- NULL
  env$create_job <- function(operation, params) {
    create_job_operation <<- operation
    create_job_params <<- params
    list(job_id = "new-job-1", status = "accepted", estimated_seconds = 30)
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_functional_clustering(req, res)
  expect_equal(res$status, 202)
  expect_equal(res$headers[["Retry-After"]], "5")
  expect_equal(out$job_id, "new-job-1")
  expect_equal(create_job_operation, "clustering")
  expect_setequal(
    names(create_job_params),
    # #574 D2: every submit path now carries a `provenance` block; explicit/
    # no-arg submits still omit `category_filter` (asserted separately below).
    c("genes", "algorithm", "category_links", "string_id_table", "provenance")
  )
  expect_false("category_filter" %in% names(create_job_params))
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
## job-functional-submission-service.R: category_filter (#574 D2)
## -------------------------------------------------------------------##

test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  # stop_for_bad_request() lives in core/errors.R, not sourced by the isolated
  # service env by default -- source it here so the real (non-stubbed)
  # mutual-exclusion guard in the service body can raise it.
  source_api_file("core/errors.R", local = FALSE, envir = env)
  env$pool <- job_endpoint_functional_pool(env)
  req <- list(
    argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive")),
    user = list(user_id = NULL)
  )
  res <- job_endpoint_fake_res()

  expect_error(
    env$svc_job_submit_functional_clustering(req, res),
    class = "error_400"
  )
})

test_that("functional clustering: an EMPTY genes array + category_filter still triggers mutual exclusion -> error_400 (Codex review fix)", {
  # Bug: mutual exclusion was previously gated on `has_genes` (a LENGTH
  # check), so `{"genes":[], "category_filter":["Definitive"]}` bypassed it
  # -- an empty-but-PRESENT `genes` key must still 400 when a category_filter
  # is also present. Presence (`genes_supplied <- !is.null(genes_in)`), not
  # length, is what mutual exclusion must gate on.
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  source_api_file("core/errors.R", local = FALSE, envir = env)
  env$pool <- job_endpoint_functional_pool(env)
  req <- list(
    argsBody = list(genes = list(), category_filter = list("Definitive")),
    user = list(user_id = NULL)
  )
  res <- job_endpoint_fake_res()

  expect_error(
    env$svc_job_submit_functional_clustering(req, res),
    class = "error_400"
  )
})

test_that("functional clustering: an explicit-null genes KEY + category_filter still triggers mutual exclusion -> error_400 (Codex round-2 review fix)", {
  # Bug: mutual exclusion was gated on `!is.null(genes_in)`, which cannot
  # distinguish an ABSENT `genes` key from an explicit JSON `null` (both
  # parse to a NULL `req$argsBody$genes`) -- so
  # `{"genes":null, "category_filter":["Definitive"]}` bypassed the guard and
  # a category job was silently accepted. `list(genes = NULL)` in base R
  # KEEPS the `genes` name with a NULL value (verified:
  # "genes" %in% names(list(genes = NULL)) is TRUE), so gating on
  # `names(req$argsBody)` instead of value-nullness catches this.
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  source_api_file("core/errors.R", local = FALSE, envir = env)
  env$pool <- job_endpoint_functional_pool(env)
  req <- list(
    argsBody = list(genes = NULL, category_filter = list("Definitive")),
    user = list(user_id = NULL)
  )
  res <- job_endpoint_fake_res()

  expect_true("genes" %in% names(req$argsBody)) # pin the base-R name-retention fact this test relies on
  expect_error(
    env$svc_job_submit_functional_clustering(req, res),
    class = "error_400"
  )
})

test_that("functional clustering: an explicit-null genes KEY ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
  # Regression guard for the fix above: gating mutual exclusion on JSON key
  # presence must NOT change the pre-existing behavior for a null `genes`
  # value with no `category_filter` at all -- it must still fall through to
  # the all-NDD default exactly as before.
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
    list(duplicate = TRUE, existing_job_id = "dup-null-genes")
  }
  req <- list(argsBody = list(genes = NULL), user = list(user_id = NULL))
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_functional_clustering(req, res)

  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
  expect_equal(res$status, 409)
  expect_equal(out$error, "DUPLICATE_JOB")
})

test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
  # Regression guard for the fix above: gating mutual exclusion on
  # `genes_supplied` (key presence) must NOT change the pre-existing
  # behavior for an empty `genes` array with no `category_filter` at all --
  # it must still fall through to the all-NDD default exactly as before.
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
    list(duplicate = TRUE, existing_job_id = "dup-empty-genes")
  }
  req <- list(argsBody = list(genes = list()), user = list(user_id = NULL))
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_functional_clustering(req, res)

  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
  expect_equal(res$status, 409)
  expect_equal(out$error, "DUPLICATE_JOB")
})

test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env)
  job_endpoint_stub_clustering_provenance(env)
  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
    expect_identical(category_filter, list("Definitive"))
    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
  }
  env$check_duplicate_job <- function(operation, params) {
    expect_true("category_filter" %in% names(params))
    expect_identical(params$category_filter, "Definitive")
    list(duplicate = FALSE)
  }
  env$async_job_capacity_exceeded <- function(...) FALSE
  env$async_job_active_count <- function(...) 0L
  captured <- NULL
  env$create_job <- function(operation, params) {
    captured <<- params
    list(job_id = "j1", status = "accepted", estimated_seconds = 5)
  }
  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_functional_clustering(req, res)

  expect_equal(res$status, 202)
  expect_identical(captured$category_filter, "Definitive")
  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
  expect_identical(captured$provenance$selector$kind, "category")
  expect_identical(captured$provenance$selector$category_filter, "Definitive")
  expect_true(all(
    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
      names(captured$provenance)
  ))
})

test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
  # Explicit genes.
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env)
  job_endpoint_stub_clustering_provenance(env)
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env$async_job_capacity_exceeded <- function(...) FALSE
  env$async_job_active_count <- function(...) 0L
  captured_explicit <- NULL
  env$create_job <- function(operation, params) {
    captured_explicit <<- params
    list(job_id = "j2", status = "accepted", estimated_seconds = 5)
  }
  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())

  expect_false("category_filter" %in% names(captured_explicit))
  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
  expect_null(captured_explicit$provenance$selector$category_filter)

  # No-arg (all-NDD default).
  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
  ))
  job_endpoint_stub_clustering_provenance(env2)
  job_endpoint_stub_all_ndd_universe(env2)
  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env2$async_job_capacity_exceeded <- function(...) FALSE
  env2$async_job_active_count <- function(...) 0L
  captured_no_arg <- NULL
  env2$create_job <- function(operation, params) {
    captured_no_arg <<- params
    list(job_id = "j3", status = "accepted", estimated_seconds = 5)
  }
  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())

  expect_false("category_filter" %in% names(captured_no_arg))
  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
  expect_null(captured_no_arg$provenance$selector$category_filter)
})

test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
  # `gene_list_sha256` hashes sort(unique(...)), so `resolved_gene_count` must
  # be computed the same way -- otherwise a duplicate-gene payload
  # (`["HGNC:1","HGNC:1"]`) reports resolved_gene_count=2 alongside a
  # singleton sha256. The payload `genes` list itself must stay
  # byte-identical to the raw request (never deduped) -- only the COUNT
  # field changes.
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env)
  job_endpoint_stub_clustering_provenance(env)
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env$async_job_capacity_exceeded <- function(...) FALSE
  env$async_job_active_count <- function(...) 0L
  captured <- NULL
  env$create_job <- function(operation, params) {
    captured <<- params
    list(job_id = "j-dup-genes", status = "accepted", estimated_seconds = 5)
  }
  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
  res <- job_endpoint_fake_res()

  env$svc_job_submit_functional_clustering(req, res)

  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
})

test_that("functional clustering: request_hash is selector-aware for category_filter", {
  # Pure-function coverage of the underlying dedup identity: sourced directly
  # (not via the service env) since these are free functions in
  # functions/async-job-service.R, not bare globals the service references.
  hash_env <- new.env(parent = globalenv())
  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)

  h <- function(genes, algo, cf) {
    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
    hash_env$async_job_service_request_hash(
      "clustering",
      hash_env$async_job_service_payload_json(payload)
    )
  }
  g <- c("HGNC:1", "HGNC:5")

  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
})

test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  env$pool <- job_endpoint_functional_pool(env)
  env$analysis_string_cache_fingerprint <- function() "fp-test"
  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
  env$clustering_cached_source_data_version <- function(...) stop("boom")
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  create_job_called <- FALSE
  env$create_job <- function(...) {
    create_job_called <<- TRUE
    NULL
  }
  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_functional_clustering(req, res)

  expect_equal(res$status, 503L)
  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
  expect_false(create_job_called)
})

# job-phenotype-submission-service.R coverage lives in
# test-unit-job-endpoint-services-phenotype.R (split out to keep this file under
# the 600-line ceiling, #574 Codex-review-fix pass).
