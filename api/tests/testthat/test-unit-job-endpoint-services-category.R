# tests/testthat/test-unit-job-endpoint-services-category.R
#
# Host-runnable unit tests for the #574 (D2) category_filter / provenance /
# dedup-hash-payload coverage of job-functional-submission-service.R, split
# out of test-unit-job-endpoint-services.R (which keeps the base functional-
# clustering submit coverage) to keep both files under the 600-line ceiling
# after the #574 Codex-review-fix rounds grew this coverage. Shared fixtures
# live in job-endpoint-services-fixtures.R (explicitly sourced below,
# mirroring the sibling files). See test-unit-job-endpoint-services.R's
# header for the full split rationale (phenotype submission coverage lives in
# test-unit-job-endpoint-services-phenotype.R; maintenance-submission +
# query-endpoint services are covered in
# test-unit-job-endpoint-services-maintenance.R).
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

test_that("functional clustering: an explicit-null category_filter KEY (no genes) is supplied-but-empty -> error_400 (Codex round-4 review fix)", {
  # Bug: the branch used `category_supplied <- !is.null(category_filter)`, so a
  # present-but-null `category_filter` key (`{"category_filter":null}`) was
  # treated as ABSENT and silently resolved the all-NDD default instead of the
  # required supplied-empty 400 -- the category-side symmetry of the genes-null
  # fix. The branch now keys off `"category_filter" %in% names(req$argsBody)`
  # and rejects a NULL value explicitly. `list(category_filter = NULL)` KEEPS
  # the name (verified: "category_filter" %in% names(list(category_filter = NULL))).
  env <- job_endpoint_source_service("job-functional-submission-service.R")
  source_api_file("core/errors.R", local = FALSE, envir = env)
  env$pool <- job_endpoint_functional_pool(env)
  req <- list(
    argsBody = list(category_filter = NULL),
    user = list(user_id = NULL)
  )
  res <- job_endpoint_fake_res()

  expect_true("category_filter" %in% names(req$argsBody))
  expect_error(
    env$svc_job_submit_functional_clustering(req, res),
    class = "error_400"
  )
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
  captured_hash_params <- NULL
  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
                                            submitted_by = NULL, ...) {
    captured <<- request_payload
    captured_hash_params <<- hash_payload
    list(job = tibble::tibble(job_id = "j1"))
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

  # Codex round-3 fix: a category run's hash payload keeps `category_filter`
  # (selector-aware dedup) but still excludes `provenance`.
  expect_true("category_filter" %in% names(captured_hash_params))
  expect_identical(captured_hash_params$category_filter, "Definitive")
  expect_false("provenance" %in% names(captured_hash_params))
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
  captured_explicit_hash_params <- NULL
  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
                                            submitted_by = NULL, ...) {
    captured_explicit <<- request_payload
    captured_explicit_hash_params <<- hash_payload
    list(job = tibble::tibble(job_id = "j2"))
  }
  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())

  expect_false("category_filter" %in% names(captured_explicit))
  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
  expect_null(captured_explicit$provenance$selector$category_filter)
  expect_false("provenance" %in% names(captured_explicit_hash_params))
  expect_false("category_filter" %in% names(captured_explicit_hash_params))

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
  captured_no_arg_hash_params <- NULL
  env2$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
                                             submitted_by = NULL, ...) {
    captured_no_arg <<- request_payload
    captured_no_arg_hash_params <<- hash_payload
    list(job = tibble::tibble(job_id = "j3"))
  }
  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())

  expect_false("category_filter" %in% names(captured_no_arg))
  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
  expect_null(captured_no_arg$provenance$selector$category_filter)
  expect_false("provenance" %in% names(captured_no_arg_hash_params))
  expect_false("category_filter" %in% names(captured_no_arg_hash_params))
})

test_that("functional clustering: two explicit submits with different provenance source_data_version produce the SAME hash_params (Codex round 3)", {
  # The whole point of the fix: `source_data_version` (and the STRING cache
  # fingerprint) are time-varying provenance fields, so two otherwise-
  # identical submits observed at different moments (e.g. across a snapshot
  # refresh / deploy) must resolve to the IDENTICAL dedup identity -- only the
  # STORED payload (`provenance`) is allowed to differ.
  submit_and_capture <- function(source_data_version) {
    env <- job_endpoint_source_service("job-functional-submission-service.R")
    env$pool <- job_endpoint_functional_pool(env)
    env$analysis_string_cache_fingerprint <- function() "fp-test"
    env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
    env$clustering_cached_source_data_version <- function(...) source_data_version
    env$check_duplicate_job <- function(...) list(duplicate = FALSE)
    env$async_job_capacity_exceeded <- function(...) FALSE
    env$async_job_active_count <- function(...) 0L
    captured_hash_params <- NULL
    captured_provenance <- NULL
    env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
                                              submitted_by = NULL, ...) {
      captured_hash_params <<- hash_payload
      captured_provenance <<- request_payload$provenance
      list(job = tibble::tibble(job_id = "j-provenance"))
    }
    req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
    env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
    list(hash_params = captured_hash_params, provenance = captured_provenance)
  }

  run_a <- submit_and_capture("2026-01-01T00:00:00Z")
  run_b <- submit_and_capture("2026-07-18T00:00:00Z")

  # Different STORED provenance...
  expect_false(identical(run_a$provenance$source_data_version, run_b$provenance$source_data_version))
  # ...but IDENTICAL dedup hash payload (provenance excluded).
  expect_identical(run_a$hash_params, run_b$hash_params)
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
  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
                                            submitted_by = NULL, ...) {
    captured <<- request_payload
    list(job = tibble::tibble(job_id = "j-dup-genes"))
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
  submit_called <- FALSE
  env$async_job_service_submit <- function(...) {
    submit_called <<- TRUE
    NULL
  }
  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_functional_clustering(req, res)

  expect_equal(res$status, 503L)
  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
  expect_false(submit_called)
})
