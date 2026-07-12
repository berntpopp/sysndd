# api/tests/testthat/test-unit-admin-endpoint-services.R
#
# Unit tests for the admin_endpoints.R service extraction (issue #346, Wave 3).
# Host-runnable: sources each service directly and mocks its DB/job
# collaborators via injectable function parameters (default = the real
# global function), so these run without a live database. DB-state paths
# (raw `pool %>% tbl()` fetches) are out of scope here and guarded with
# skip_if_no_test_db() where exercised at all -- they are pre-existing,
# unmodified logic covered by test-endpoint-admin.R's structural checks and
# by test-unit-admin-ontology-mapping-endpoints.R.

source_api_file("functions/nddscore-admin-endpoint-helpers.R", local = FALSE)
# nddscore-import.R defines nddscore_default_zenodo_record_id(), called
# directly (not injected) by svc_admin_nddscore_import(); it degrades
# gracefully to a hardcoded default when no config.yml/API_CONFIG is present.
source_api_file("functions/nddscore-import.R", local = FALSE)
source_api_file("services/admin-ontology-endpoint-service.R", local = FALSE)
source_api_file("services/admin-diagnostics-endpoint-service.R", local = FALSE)
source_api_file("services/admin-nddscore-endpoint-service.R", local = FALSE)
source_api_file("services/admin-publication-refresh-endpoint-service.R", local = FALSE)

# A minimal fake plumber response object. Plumber's real PlumberResponse is
# reference-semantic (R6); an environment gives the same $status <- / $<-
# mutation-through-reference behavior so service functions that set
# res$status are testable without a real request cycle.
fake_res <- function() {
  e <- new.env()
  e$status <- 200L
  e$headers <- list()
  e$setHeader <- function(name, value) {
    e$headers[[name]] <- value
    invisible(NULL)
  }
  e
}

## -------------------------------------------------------------------##
## Diagnostics: OpenAPI single enhancement
## -------------------------------------------------------------------##

test_that("svc_admin_openapi_spec calls getApiSpec exactly once (no double enhancement)", {
  calls <- 0L
  fake_root <- list(getApiSpec = function() {
    calls <<- calls + 1L
    list(openapi = "3.0.0", info = list(title = "SysNDD API"))
  })

  result <- svc_admin_openapi_spec(fake_root)

  expect_equal(calls, 1L)
  expect_equal(result$openapi, "3.0.0")
})

## -------------------------------------------------------------------##
## Diagnostics: version / dates / SMTP
## -------------------------------------------------------------------##

test_that("svc_admin_api_version echoes the given version string", {
  expect_equal(svc_admin_api_version("1.2.3"), list(api_version = "1.2.3"))
})

test_that("svc_admin_annotation_dates prefers job history over file metadata", {
  history <- data.frame(
    operation = c("omim_update", "hgnc_update", "force_apply_ontology"),
    status = c("completed", "completed", "completed"),
    completed_at = c("2026-01-01 00:00:00", "2026-02-02 00:00:00", "2026-03-03 00:00:00"),
    stringsAsFactors = FALSE
  )

  result <- svc_admin_annotation_dates(
    data_dir = tempdir(),
    history_fn = function(n) history
  )

  expect_equal(result$omim_update, "2026-01-01 00:00:00")
  expect_equal(result$hgnc_update, "2026-02-02 00:00:00")
  # ontology_update looks up c("ontology_update", "force_apply_ontology")
  expect_equal(result$disease_ontology_update, "2026-03-03 00:00:00")
})

test_that("svc_admin_annotation_dates degrades to NA when history_fn errors and no files exist", {
  result <- svc_admin_annotation_dates(
    data_dir = tempdir(),
    history_fn = function(n) stop("job history unavailable")
  )

  expect_true(is.na(result$omim_update))
  expect_true(is.na(result$mondo_update))
})

test_that("svc_admin_smtp_test reports success on a working connection", {
  result <- svc_admin_smtp_test(
    req = list(), res = fake_res(),
    dw = list(mail_noreply_host = "smtp.example.com", mail_noreply_port = "25"),
    connect_fn = function(...) "fake-connection",
    close_fn = function(con) invisible(NULL)
  )

  expect_true(result$success)
  expect_equal(result$host, "smtp.example.com")
  expect_equal(result$port, 25L)
  expect_null(result$error)
})

test_that("svc_admin_smtp_test reports failure with the connection error message", {
  result <- svc_admin_smtp_test(
    req = list(), res = fake_res(),
    dw = list(mail_noreply_host = "smtp.example.com", mail_noreply_port = "25"),
    connect_fn = function(...) stop("Connection refused")
  )

  expect_false(result$success)
  expect_match(result$error, "Connection refused")
})

## -------------------------------------------------------------------##
## Ontology: force_apply_ontology validation-before-submit / 404 / 409 / 410
## -------------------------------------------------------------------##

test_that("svc_admin_force_apply_ontology_prepare reads the job in full result mode", {
  seen_result_mode <- NULL
  res <- fake_res()

  svc_admin_force_apply_ontology_prepare(
    req = list(user_id = 1L), res = res, blocked_job_id = "job-1",
    assigned_user_id = NULL, pool = NULL,
    job_status_fn = function(job_id, result_mode) {
      seen_result_mode <<- result_mode
      list(error = "JOB_NOT_FOUND")
    }
  )

  expect_equal(seen_result_mode, "full")
})

test_that("svc_admin_force_apply_ontology_prepare 404s when the blocked job is not found", {
  res <- fake_res()

  result <- svc_admin_force_apply_ontology_prepare(
    req = list(), res = res, blocked_job_id = "missing", assigned_user_id = NULL,
    pool = NULL,
    job_status_fn = function(...) list(error = "JOB_NOT_FOUND")
  )

  expect_equal(res$status, 404L)
  expect_equal(result$early_return$error, "Blocked job not found")
})

test_that("svc_admin_force_apply_ontology_prepare 409s when the job is not completed", {
  res <- fake_res()

  result <- svc_admin_force_apply_ontology_prepare(
    req = list(), res = res, blocked_job_id = "job-1", assigned_user_id = NULL,
    pool = NULL,
    job_status_fn = function(...) list(status = "running")
  )

  expect_equal(res$status, 409L)
  expect_match(result$early_return$error, "not in completed state")
})

test_that("svc_admin_force_apply_ontology_prepare 409s when the completed job was not blocked", {
  res <- fake_res()

  result <- svc_admin_force_apply_ontology_prepare(
    req = list(), res = res, blocked_job_id = "job-1", assigned_user_id = NULL,
    pool = NULL,
    job_status_fn = function(...) list(status = "completed", result = list(status = "success"))
  )

  expect_equal(res$status, 409L)
  expect_match(result$early_return$error, "was not blocked")
})

test_that("svc_admin_force_apply_ontology_prepare 410s when the pending CSV is missing", {
  res <- fake_res()

  result <- svc_admin_force_apply_ontology_prepare(
    req = list(), res = res, blocked_job_id = "job-1", assigned_user_id = NULL,
    pool = NULL,
    job_status_fn = function(...) list(
      status = "completed",
      result = list(status = "blocked", pending_csv_path = "/no/such/file.csv")
    )
  )

  expect_equal(res$status, 410L)
  expect_match(result$early_return$error, "not found")
})

test_that("svc_admin_force_apply_ontology_prepare 410s when the pending CSV is stale (>48h)", {
  csv_path <- tempfile(fileext = ".csv")
  writeLines("a,b\n1,2", csv_path)
  Sys.setFileTime(csv_path, Sys.time() - as.difftime(49, units = "hours"))
  withr::defer(unlink(csv_path))

  res <- fake_res()

  result <- svc_admin_force_apply_ontology_prepare(
    req = list(), res = res, blocked_job_id = "job-1", assigned_user_id = NULL,
    pool = NULL,
    job_status_fn = function(...) list(
      status = "completed",
      result = list(status = "blocked", pending_csv_path = csv_path)
    )
  )

  expect_equal(res$status, 410L)
  expect_match(result$early_return$error, "stale")
})

test_that("svc_admin_force_apply_ontology_prepare does NOT marshal db_config into the job params (#535 S2b)", {
  # Post-S2b: the durable force_apply_ontology handler
  # (.async_job_run_force_apply_ontology) resolves DB creds at run time via
  # async_job_db_connect() from the worker's runtime config — no credential is
  # written into async_jobs.request_payload_json. The prior helper
  # .svc_admin_ontology_db_config() is removed.
  svc_src <- paste(
    deparse(body(svc_admin_force_apply_ontology_prepare)), collapse = "\n"
  )
  expect_false(grepl("db_config", svc_src, fixed = TRUE),
               info = "force_apply params must NOT carry db_config (creds resolved at run time)")
  expect_false(grepl(".svc_admin_ontology_db_config", svc_src, fixed = TRUE),
               info = "the credential-marshaling helper must no longer be referenced")
})

## -------------------------------------------------------------------##
## Ontology: HGNC transactional / FK-disabled behavior
## -------------------------------------------------------------------##

test_that("svc_admin_hgnc_update runs the delete+insert inside the FK-disabled transaction", {
  hgnc_data <- data.frame(hgnc_id = c("HGNC:1", "HGNC:2"), symbol = c("A1", "A2"),
                           stringsAsFactors = FALSE)
  executed <- list()
  transaction_calls <- 0L
  fk_guard_calls <- 0L

  result <- svc_admin_hgnc_update(
    req = list(), res = fake_res(),
    fetch_hgnc_fn = function() hgnc_data,
    transaction_fn = function(work) {
      transaction_calls <<- transaction_calls + 1L
      work("fake-txn-conn")
    },
    fk_guard_fn = function(conn, work) {
      fk_guard_calls <<- fk_guard_calls + 1L
      expect_equal(conn, "fake-txn-conn")
      work()
    },
    execute_fn = function(sql, params = list(), conn = NULL) {
      executed[[length(executed) + 1L]] <<- list(sql = sql, params = params, conn = conn)
      invisible(0L)
    }
  )

  expect_equal(transaction_calls, 1L)
  expect_equal(fk_guard_calls, 1L)
  # DELETE, then one INSERT per row
  expect_equal(length(executed), 3L)
  expect_match(executed[[1]]$sql, "DELETE FROM non_alt_loci_set")
  expect_match(executed[[2]]$sql, "INSERT INTO non_alt_loci_set")
  expect_equal(executed[[2]]$params, list("HGNC:1", "A1"))
  expect_equal(executed[[3]]$params, list("HGNC:2", "A2"))
  expect_equal(result$status, "Success")
})

test_that("svc_admin_hgnc_update skips the insert loop for an empty HGNC fetch", {
  executed <- list()

  result <- svc_admin_hgnc_update(
    req = list(), res = fake_res(),
    fetch_hgnc_fn = function() data.frame(hgnc_id = character(0), symbol = character(0)),
    transaction_fn = function(work) work("fake-txn-conn"),
    fk_guard_fn = function(conn, work) work(),
    execute_fn = function(sql, params = list(), conn = NULL) {
      executed[[length(executed) + 1L]] <<- sql
      invisible(0L)
    }
  )

  expect_equal(length(executed), 1L) # DELETE only, no INSERT
  expect_equal(result$status, "Success")
})

test_that("svc_admin_hgnc_update rolls back to a 500 when the transaction throws", {
  res <- fake_res()

  result <- svc_admin_hgnc_update(
    req = list(), res = res,
    fetch_hgnc_fn = function() data.frame(hgnc_id = "HGNC:1", symbol = "A1"),
    transaction_fn = function(work) stop("db unavailable"),
    fk_guard_fn = function(conn, work) work(),
    execute_fn = function(...) invisible(0L)
  )

  expect_equal(res$status, 500)
  expect_match(result$error, "Transaction rolled back")
  expect_match(result$details, "db unavailable")
})

## -------------------------------------------------------------------##
## Ontology: deprecated entities
## -------------------------------------------------------------------##

test_that("svc_admin_deprecated_entities reports zero when no mim2gene file exists", {
  empty_dir <- tempfile("admin-deprecated-empty-")
  dir.create(empty_dir)
  withr::defer(unlink(empty_dir, recursive = TRUE))

  result <- svc_admin_deprecated_entities(req = list(), res = fake_res(), pool = NULL,
                                           data_dir = paste0(empty_dir, "/"))

  expect_equal(result$deprecated_count, 0)
  expect_match(result$message, "No mim2gene.txt file found", fixed = TRUE)
})

test_that("svc_admin_deprecated_entities reports zero when no deprecated MIMs are found", {
  data_dir <- tempfile("admin-deprecated-mim2gene-")
  dir.create(data_dir)
  withr::defer(unlink(data_dir, recursive = TRUE))
  file.create(file.path(data_dir, "mim2gene.2026-01-01.txt"))

  result <- svc_admin_deprecated_entities(
    req = list(), res = fake_res(), pool = NULL, data_dir = paste0(data_dir, "/"),
    mim2gene_fn = function(path, include_moved_removed) "fake-mim2gene-data",
    deprecated_mims_fn = function(data) character(0)
  )

  expect_equal(result$deprecated_count, 0)
  expect_match(result$message, "No deprecated MIM numbers found")
})

test_that("svc_admin_deprecated_entities reports zero affected when no entities match", {
  data_dir <- tempfile("admin-deprecated-mim2gene-")
  dir.create(data_dir)
  withr::defer(unlink(data_dir, recursive = TRUE))
  file.create(file.path(data_dir, "mim2gene.2026-01-01.txt"))

  result <- svc_admin_deprecated_entities(
    req = list(), res = fake_res(), pool = NULL, data_dir = paste0(data_dir, "/"),
    mim2gene_fn = function(path, include_moved_removed) "fake-mim2gene-data",
    deprecated_mims_fn = function(data) c("612345"),
    check_entities_fn = function(pool, deprecated_mims) {
      tibble::tibble(entity_id = integer(0), disease_ontology_id = character(0))
    }
  )

  expect_equal(result$deprecated_count, 1)
  expect_equal(result$affected_entity_count, 0)
})

test_that("svc_admin_deprecated_entities returns a 500 when the lookup chain errors", {
  data_dir <- tempfile("admin-deprecated-mim2gene-")
  dir.create(data_dir)
  withr::defer(unlink(data_dir, recursive = TRUE))
  file.create(file.path(data_dir, "mim2gene.2026-01-01.txt"))
  res <- fake_res()

  result <- svc_admin_deprecated_entities(
    req = list(), res = res, pool = NULL, data_dir = paste0(data_dir, "/"),
    mim2gene_fn = function(path, include_moved_removed) stop("parse failed")
  )

  expect_equal(res$status, 500)
  expect_match(result$error, "Failed to check deprecated entities")
})

## -------------------------------------------------------------------##
## NDDScore: 409 (duplicate) / 202 (accepted)
## -------------------------------------------------------------------##

test_that("svc_admin_nddscore_import returns 202 accepted on a fresh submission", {
  res <- fake_res()

  result <- svc_admin_nddscore_import(
    req = list(body = list(record_id = "20258027"), user_id = 7L), res = res,
    submit_fn = function(job_type, request_payload, submitted_by) {
      expect_equal(job_type, "nddscore_import")
      expect_equal(request_payload$record_id, "20258027")
      list(
        duplicate = FALSE,
        job = data.frame(job_id = "job-abc", status = "queued", stringsAsFactors = FALSE)
      )
    }
  )

  expect_equal(res$status, 202L)
  expect_equal(result$job_id, "job-abc")
  expect_equal(result$status, "accepted")
  expect_equal(res$headers[["Location"]], "/api/jobs/job-abc/status")
})

test_that("svc_admin_nddscore_import returns 409 when a duplicate import is running", {
  res <- fake_res()

  result <- svc_admin_nddscore_import(
    req = list(body = list(), user_id = 7L), res = res,
    submit_fn = function(job_type, request_payload, submitted_by) {
      list(
        duplicate = TRUE,
        job = data.frame(job_id = "job-existing", status = "running", stringsAsFactors = FALSE)
      )
    }
  )

  expect_equal(res$status, 409L)
  expect_equal(result$status, "already_running")
  expect_equal(result$job_id, "job-existing")
})

test_that("svc_admin_nddscore_import defaults record_id to the configured default", {
  seen_payload <- NULL

  svc_admin_nddscore_import(
    req = list(body = list(), user_id = NULL), res = fake_res(),
    submit_fn = function(job_type, request_payload, submitted_by) {
      seen_payload <<- request_payload
      list(duplicate = FALSE, job = data.frame(job_id = "j", status = "queued"))
    }
  )

  expect_equal(seen_payload$record_id, nddscore_default_zenodo_record_id())
  expect_false(seen_payload$validate_only)
})

## -------------------------------------------------------------------##
## Publication refresh: invalid / empty / no-match / duplicate / capacity / success
## -------------------------------------------------------------------##

test_that("svc_admin_publication_refresh_validate_date rejects an invalid date", {
  result <- svc_admin_publication_refresh_validate_date("not-a-date")
  expect_false(result$valid)
  expect_match(result$error, "Invalid date format")
})

test_that("svc_admin_publication_refresh_validate_date accepts NULL/empty as no filter", {
  expect_true(svc_admin_publication_refresh_validate_date(NULL)$valid)
  expect_null(svc_admin_publication_refresh_validate_date(NULL)$date)
  expect_true(svc_admin_publication_refresh_validate_date("")$valid)
})

test_that("submit returns 400 on an invalid not_updated_since date", {
  res <- fake_res()

  result <- svc_admin_publication_refresh_submit(
    req = list(body = list(not_updated_since = "not-a-date")), res = res,
    dw = list()
  )

  expect_equal(res$status, 400)
  expect_match(result$error, "Invalid date format")
})

test_that("submit returns 400 when no PMIDs and no filter/all flag are given (empty request)", {
  res <- fake_res()

  result <- svc_admin_publication_refresh_submit(
    req = list(body = list()), res = res, dw = list()
  )

  expect_equal(res$status, 400)
  expect_match(result$error, "No PMIDs provided")
})

test_that("submit returns 200 'no match' when the date filter matches nothing", {
  res <- fake_res()

  result <- svc_admin_publication_refresh_submit(
    req = list(body = list(not_updated_since = "2024-01-01")), res = res, dw = list(),
    query_fn = function(sql, params = list()) {
      data.frame(publication_id = character(0))
    }
  )

  expect_equal(res$status, 200)
  expect_match(result$message, "No publications need refreshing")
})

test_that("submit returns 200 when explicit PMIDs don't intersect the date filter", {
  res <- fake_res()

  result <- svc_admin_publication_refresh_submit(
    req = list(body = list(pmids = list("999999"), not_updated_since = "2024-01-01")),
    res = res, dw = list(),
    query_fn = function(sql, params = list()) data.frame(publication_id = c("111", "222"))
  )

  expect_equal(res$status, 200)
  expect_match(result$message, "No matching publications need refreshing")
})

test_that("submit returns 'already_running' when a duplicate job exists", {
  res <- fake_res()

  result <- svc_admin_publication_refresh_submit(
    req = list(body = list(pmids = list("12345"))), res = res, dw = list(),
    duplicate_check_fn = function(operation, params) {
      expect_equal(operation, "publication_refresh")
      list(duplicate = TRUE, existing_job_id = "existing-job")
    },
    create_job_fn = function(...) stop("should not submit when duplicate")
  )

  expect_equal(result$status, "already_running")
  expect_equal(result$job_id, "existing-job")
})

test_that("submit returns 503 when job submission reports capacity exceeded", {
  res <- fake_res()

  result <- svc_admin_publication_refresh_submit(
    req = list(body = list(pmids = list("12345"))), res = res, dw = list(),
    duplicate_check_fn = function(...) list(duplicate = FALSE),
    create_job_fn = function(operation, params, ...) {
      list(error = "CAPACITY_EXCEEDED", message = "Too many jobs", retry_after = 60)
    }
  )

  expect_equal(res$status, 503)
  expect_equal(result$error, "CAPACITY_EXCEEDED")
})

test_that("submit succeeds with 202 and the 350ms-per-PMID estimate", {
  res <- fake_res()
  seen_params <- NULL

  result <- svc_admin_publication_refresh_submit(
    req = list(body = list(pmids = list("1", "2", "3"))), res = res,
    dw = list(dbname = "d", user = "u", password = "p", server = "s", host = "h", port = 3306L),
    duplicate_check_fn = function(...) list(duplicate = FALSE),
    create_job_fn = function(operation, params, ...) {
      seen_params <<- params
      list(job_id = "new-job", status = "accepted")
    }
  )

  expect_equal(res$status, 202)
  expect_equal(result$job_id, "new-job")
  # 350ms/PMID + overhead: ceiling(3 * 0.4) == 2
  expect_equal(result$estimated_seconds, 2)
  expect_equal(seen_params$pmids, list("1", "2", "3"))
  # #535 S2b: no DB credential in the payload — resolved at run time.
  expect_null(seen_params$db_config)
})

test_that("svc_admin_publication_refresh_estimate_seconds matches the 350ms rate-limit guard", {
  expect_equal(svc_admin_publication_refresh_estimate_seconds(character(0)), 0)
  expect_equal(svc_admin_publication_refresh_estimate_seconds(rep("x", 1L)), 1)
  expect_equal(svc_admin_publication_refresh_estimate_seconds(rep("x", 10L)), 4)
  # Mirrors functions/async-job-handlers.R's live Sys.sleep(0.35) per-PMID pacing.
  expect_equal(svc_admin_publication_refresh_estimate_seconds(rep("x", 100L)), 40)
})

test_that("submit resolves an opt-in all=true full-corpus refresh server-side", {
  res <- fake_res()
  seen_sql <- NULL

  result <- svc_admin_publication_refresh_submit(
    req = list(body = list(all = TRUE)), res = res, dw = list(),
    query_fn = function(sql, params = list()) {
      seen_sql <<- sql
      data.frame(publication_id = c("1", "2"))
    },
    duplicate_check_fn = function(...) list(duplicate = FALSE),
    create_job_fn = function(operation, params, ...) {
      expect_equal(params$pmids, c("1", "2"))
      list(job_id = "corpus-job", status = "accepted")
    }
  )

  expect_equal(res$status, 202)
  expect_match(seen_sql, "SELECT publication_id FROM publication")
})
