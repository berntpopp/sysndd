# tests/testthat/test-unit-job-endpoint-services.R
#
# Host-runnable unit tests for the job endpoint services extracted from
# endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
# submission-service.R, job-phenotype-submission-service.R, job-maintenance-
# submission-service.R, job-query-endpoint-service.R.
#
# Each service is sourced directly into an isolated environment via
# sys.source() (mirrors test-unit-job-status-result-mode.R), and every bare
# global name the service body references (pool, dw, check_duplicate_job,
# create_job, async_job_capacity_exceeded, async_job_active_count,
# async_job_service_store_completed, gen_string_clust_obj_mem,
# gen_mca_clust_obj_mem, log_warn, get_job_history, get_job_status, ...) is
# stubbed in that environment, so the tests exercise pure request/response
# logic without a live DB or mirai daemon pool.
#
# `pool %>% dplyr::tbl(name)` is faked with a small S3 dispatch trick: a
# "fake_pool" object wrapping a named list of tibbles, plus one `tbl.fake_pool`
# method registered in the environment the service was sourced into (S3
# dispatch finds it there). This needs no test DB / RSQLite, so every test
# here is a real PASS on host R.

library(dplyr)
library(tidyr)

## -------------------------------------------------------------------##
## Shared fixtures
## -------------------------------------------------------------------##

#' Source a service file into a fresh child-of-globalenv environment.
job_endpoint_source_service <- function(filename) {
  env <- new.env(parent = globalenv())
  sys.source(file.path(get_api_dir(), "services", filename), envir = env)
  env
}

#' Register `tbl.fake_pool` in `env` and build a fake pool over `tables`.
job_endpoint_fake_pool <- function(env, tables) {
  env$tbl.fake_pool <- function(src, from, ...) src$tables[[from]]
  structure(list(tables = tables), class = "fake_pool")
}

#' Minimal Plumber-response stand-in: an environment with `$status` and a
#' `$setHeader()` that records every header set (mirrors the `res_env`
#' pattern in test-unit-pubtator-enrichment.R).
job_endpoint_fake_res <- function() {
  res <- new.env()
  res$status <- NULL
  res$headers <- list()
  res$setHeader <- function(name, value) {
    res$headers[[name]] <- value
    invisible(NULL)
  }
  res
}

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
  create_job_executor <- NULL
  env$create_job <- function(operation, params, executor_fn, timeout_ms = 1800000) {
    create_job_operation <<- operation
    create_job_executor <<- executor_fn
    list(job_id = "new-job-1", status = "accepted", estimated_seconds = 30)
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_submit_functional_clustering(req, res)
  expect_equal(res$status, 202)
  expect_equal(res$headers[["Retry-After"]], "5")
  expect_equal(out$job_id, "new-job-1")
  expect_equal(create_job_operation, "clustering")
  # The mirai executor closure is preserved anonymously/inline.
  expect_true(is.function(create_job_executor))
  expect_equal(names(formals(create_job_executor)), "params")
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
  env$create_job <- function(operation, params, executor_fn, timeout_ms = 1800000) {
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
  create_job_executor <- NULL
  env$create_job <- function(operation, params, executor_fn, timeout_ms = 1800000) {
    create_job_executor <<- executor_fn
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
  expect_true(is.function(create_job_executor))
  expect_equal(names(formals(create_job_executor)), "params")
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

## -------------------------------------------------------------------##
## job-maintenance-submission-service.R
## -------------------------------------------------------------------##

job_endpoint_ontology_pool <- function(env) {
  job_endpoint_fake_pool(env, list(
    non_alt_loci_set = tibble::tibble(symbol = "A", hgnc_id = "HGNC:1"),
    mode_of_inheritance_list = tibble::tibble(
      is_active = c(1L, 0L),
      hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0000007"),
      hpo_mode_of_inheritance_term_name = c("AD", "AR")
    )
  ))
}

job_endpoint_maintenance_env <- function(needs_pool) {
  env <- job_endpoint_source_service("job-maintenance-submission-service.R")
  if (needs_pool) {
    env$pool <- job_endpoint_ontology_pool(env)
  } else {
    env$dw <- list(dbname = "sysndd_db", host = "db", user = "sysndd", password = "s3cr3t", port = 3306L)
  }
  # hgnc/comparisons now dedupe via job-type single-flight (#535 S2b HIGH-4);
  # ontology_update still uses check_duplicate_job. Provide a no-duplicate
  # default for both seams so per-test overrides only set the case they exercise.
  env$async_job_service_duplicate_by_type <- function(...) list(duplicate = FALSE)
  env
}

# Table-driven: the three maintenance types share duplicate/new-submit flow,
# differing only in operation name and Retry-After (30 / 60 / 30 seconds).
job_endpoint_maintenance_specs <- list(
  list(fn = "svc_job_submit_ontology_update", op = "ontology_update", retry_after = "30", needs_pool = TRUE),
  list(fn = "svc_job_submit_hgnc_update", op = "hgnc_update", retry_after = "60", needs_pool = FALSE),
  list(fn = "svc_job_submit_comparisons_update", op = "comparisons_update", retry_after = "30", needs_pool = FALSE)
)

for (job_endpoint_spec in job_endpoint_maintenance_specs) {
  test_that(paste(job_endpoint_spec$op, ": duplicate job returns 409 with Location"), {
    env <- job_endpoint_maintenance_env(job_endpoint_spec$needs_pool)
    dup_id <- paste0("dup-", job_endpoint_spec$op)
    env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = dup_id)
    env$async_job_service_duplicate_by_type <- function(...) list(duplicate = TRUE, existing_job_id = dup_id)
    res <- job_endpoint_fake_res()

    out <- env[[job_endpoint_spec$fn]](res)

    expect_equal(res$status, 409)
    expect_equal(out$error, "DUPLICATE_JOB")
    expect_match(res$headers[["Location"]], paste0("/api/jobs/", dup_id, "/status"))
  })

  test_that(paste(job_endpoint_spec$op, ": new submit returns 202 with the expected Retry-After"), {
    env <- job_endpoint_maintenance_env(job_endpoint_spec$needs_pool)
    env$check_duplicate_job <- function(...) list(duplicate = FALSE)
    new_job_id <- paste0(job_endpoint_spec$op, "-1")
    create_job_executor <- NULL
    env$create_job <- function(operation, params, executor_fn, timeout_ms = 1800000) {
      create_job_executor <<- executor_fn
      list(job_id = new_job_id, status = "accepted", estimated_seconds = 30)
    }

    out <- {
      res <- job_endpoint_fake_res()
      env[[job_endpoint_spec$fn]](res)
    }

    expect_equal(res$status, 202)
    expect_equal(res$headers[["Retry-After"]], job_endpoint_spec$retry_after)
    expect_equal(out$job_id, new_job_id)
    # The mirai executor closure is preserved anonymously/inline.
    expect_true(is.function(create_job_executor))
    expect_equal(names(formals(create_job_executor)), "params")
  })
}

test_that("ontology update: create_job error surfaces as 503 with Retry-After", {
  env <- job_endpoint_maintenance_env(needs_pool = TRUE)
  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
  env$create_job <- function(...) list(error = "CAPACITY_EXCEEDED", retry_after = 60)
  res <- job_endpoint_fake_res()

  out <- env$svc_job_submit_ontology_update(res)

  expect_equal(res$status, 503)
  expect_equal(res$headers[["Retry-After"]], "60")
  expect_equal(out$error, "CAPACITY_EXCEEDED")
})

# Job-type single-flight (#535 S2b HIGH-4): the destructive maintenance submits
# dedupe on job_type ALONE — no db_config/password/payload reaches the dedup
# path — so a payload-schema change (dropping db_config) cannot open a
# deploy-window where two concurrent full-table-replace jobs run.
job_endpoint_single_flight_specs <- list(
  list(fn = "svc_job_submit_hgnc_update", op = "hgnc_update"),
  list(fn = "svc_job_submit_comparisons_update", op = "comparisons_update")
)

for (job_endpoint_spec in job_endpoint_single_flight_specs) {
  test_that(paste(job_endpoint_spec$op, ": dedupe is job-type single-flight (no credential/payload)"), {
    env <- job_endpoint_maintenance_env(needs_pool = FALSE)
    captured <- NULL
    env$async_job_service_duplicate_by_type <- function(...) {
      captured <<- list(...)
      list(duplicate = TRUE, existing_job_id = paste0("dup-", job_endpoint_spec$op))
    }
    res <- job_endpoint_fake_res()

    env[[job_endpoint_spec$fn]](res)

    # Only the job_type is passed to the dedup path (no params/credentials).
    expect_equal(captured[[1]], job_endpoint_spec$op)
    expect_false(any(grepl("s3cr3t", unlist(captured), fixed = TRUE)))
  })
}

## -------------------------------------------------------------------##
## job-query-endpoint-service.R — history
## -------------------------------------------------------------------##

job_endpoint_history_rows <- function(n = 2L) {
  if (n == 0L) {
    return(data.frame(
      job_id = character(0), operation = character(0), status = character(0),
      submitted_at = character(0), completed_at = character(0),
      duration_seconds = integer(0), error_message = character(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    job_id = paste0("job-", seq_len(n)),
    operation = rep("clustering", n),
    status = rep("completed", n),
    submitted_at = rep("2026-07-01T00:00:00Z", n),
    completed_at = rep("2026-07-01T00:05:00Z", n),
    duration_seconds = rep(300L, n),
    error_message = rep(NA_character_, n),
    stringsAsFactors = FALSE
  )
}

test_that("job history: limit clamps to [1, 100] and non-numeric falls back to 20", {
  env <- job_endpoint_source_service("job-query-endpoint-service.R")
  captured_limit <- NULL
  env$get_job_history <- function(limit) {
    captured_limit <<- limit
    job_endpoint_history_rows(0L)
  }

  env$svc_job_get_history(limit = 0)
  expect_equal(captured_limit, 20L)

  env$svc_job_get_history(limit = 500)
  expect_equal(captured_limit, 100L)

  # as.integer() on a non-numeric string warns (matches the original inline
  # handler's un-guarded as.integer(limit) coercion); assert it explicitly
  # instead of leaking it to the console.
  expect_warning(env$svc_job_get_history(limit = "not-a-number"), "NAs introduced")
  expect_equal(captured_limit, 20L)

  env$svc_job_get_history(limit = 50)
  expect_equal(captured_limit, 50L)
})

test_that("job history: shapes rows into a list (or an empty list) and reports meta count/limit", {
  env <- job_endpoint_source_service("job-query-endpoint-service.R")

  env$get_job_history <- function(limit) job_endpoint_history_rows(2L)
  out <- env$svc_job_get_history(limit = 20)
  expect_length(out$data, 2)
  expect_equal(out$data[[1]]$job_id, "job-1")
  expect_equal(out$meta$count, 2)
  expect_equal(out$meta$limit, 20L)

  env$get_job_history <- function(limit) job_endpoint_history_rows(0L)
  out <- env$svc_job_get_history(limit = 20)
  expect_equal(out$data, list())
  expect_equal(out$meta$count, 0)
})

## -------------------------------------------------------------------##
## job-query-endpoint-service.R — status
## -------------------------------------------------------------------##

test_that("job status: invalid result_mode (400), summary bypasses the gate (200), 404, and running Retry-After", {
  req <- list(user_role = NULL)

  env <- job_endpoint_source_service("job-query-endpoint-service.R")
  out <- env$svc_job_get_status("job-1", "bogus", req, job_endpoint_fake_res())
  expect_equal(out$error, "INVALID_RESULT_MODE")

  # Summary mode is a public read: it must never touch the full-result gate.
  gate_called <- FALSE
  env$async_job_repository_get <- function(...) {
    gate_called <<- TRUE
    NULL
  }
  env$get_job_status <- function(job_id, result_mode) {
    list(job_id = job_id, status = "completed", result = list(ok = TRUE))
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("job-1", "summary", req, res)
  expect_false(gate_called)
  expect_equal(res$status, 200)
  expect_equal(out$status, "completed")
  expect_null(res$headers[["Retry-After"]])

  env$get_job_status <- function(job_id, result_mode) list(error = "JOB_NOT_FOUND")
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("missing-job", "summary", req, res)
  expect_equal(res$status, 404)
  expect_equal(out$error, "JOB_NOT_FOUND")

  env$get_job_status <- function(job_id, result_mode) list(job_id = job_id, status = "running", retry_after = 7)
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("job-1", "summary", req, res)
  expect_equal(res$status, 200)
  expect_equal(res$headers[["Retry-After"]], "7")
  expect_equal(out$status, "running")
})

test_that("job status: full mode gates on access-verification failure (503) and role (403)", {
  req <- list(user_role = "Viewer")

  env <- job_endpoint_source_service("job-query-endpoint-service.R")
  env$async_job_repository_get <- function(job_id) stop("db unavailable")
  out <- env$svc_job_get_status("job-1", "full", req, job_endpoint_fake_res())
  expect_equal(out$error, "SERVICE_UNAVAILABLE")

  env$async_job_repository_get <- function(job_id) tibble::tibble(job_id = job_id, job_type = "hgnc_update")
  env$can_read_full_job_result <- function(job_type, user_role) FALSE
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("job-1", "full", req, res)
  expect_equal(res$status, 403)
  expect_equal(out$error, "FORBIDDEN")
})

test_that("job status: full mode skips the gate for an unknown id (404) and returns the result when authorized", {
  req <- list(user_role = NULL)

  env <- job_endpoint_source_service("job-query-endpoint-service.R")
  env$async_job_repository_get <- function(job_id) tibble::tibble(job_id = character(0), job_type = character(0))
  gate_called <- FALSE
  env$can_read_full_job_result <- function(job_type, user_role) {
    gate_called <<- TRUE
    FALSE
  }
  env$get_job_status <- function(job_id, result_mode) list(error = "JOB_NOT_FOUND")
  out <- env$svc_job_get_status("missing-job", "full", req, job_endpoint_fake_res())
  expect_false(gate_called)
  expect_equal(out$error, "JOB_NOT_FOUND")

  env$async_job_repository_get <- function(job_id) tibble::tibble(job_id = job_id, job_type = "clustering")
  env$can_read_full_job_result <- function(job_type, user_role) TRUE
  env$get_job_status <- function(job_id, result_mode) {
    list(job_id = job_id, status = "completed", result = list(cluster_count = 2))
  }
  res <- job_endpoint_fake_res()
  out <- env$svc_job_get_status("job-1", "full", req, res)
  expect_equal(res$status, 200)
  expect_equal(out$result$cluster_count, 2)
})
