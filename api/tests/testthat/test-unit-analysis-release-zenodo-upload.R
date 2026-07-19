# Unit tests for the analysis-snapshot RELEASE Zenodo upload/DOI-record-back
# logic (#573 Slice C / Task C2):
# api/functions/analysis-snapshot-release-zenodo-upload.R.
#
# Pure, DB-free, NO NETWORK: every HTTP boundary is an injectable seam
# (`http`/`put`/`patch`) so tests supply plain stub closures instead of a
# mocking library -- the direct R analog of the sibling
# `../nddscore/tests/test_sysndd_zenodo_upload.py`'s
# `monkeypatch.setattr(...requests.put, fake_put)` style.

library(testthat)

source_api_file("functions/analysis-snapshot-release-zenodo-upload.R", local = FALSE)

# --------------------------------------------------------------------------- #
# require_publish_confirmation -- the double-gate safety interlock
# --------------------------------------------------------------------------- #

test_that("require_publish_confirmation: publish=TRUE, confirm_publish=FALSE stops with the exact message", {
  expect_error(
    analysis_release_zenodo_require_publish_confirmation(TRUE, FALSE),
    "^--publish requires --confirm-publish$"
  )
})

test_that("require_publish_confirmation: publish=FALSE, confirm_publish=FALSE is a no-op", {
  expect_no_error(analysis_release_zenodo_require_publish_confirmation(FALSE, FALSE))
})

test_that("require_publish_confirmation: publish=TRUE, confirm_publish=TRUE is a no-op", {
  expect_no_error(analysis_release_zenodo_require_publish_confirmation(TRUE, TRUE))
})

# --------------------------------------------------------------------------- #
# resolve_api
# --------------------------------------------------------------------------- #

test_that("resolve_api: sandbox=TRUE returns the sandbox host, FALSE/default returns prod", {
  expect_identical(analysis_release_zenodo_resolve_api(TRUE), "https://sandbox.zenodo.org/api")
  expect_identical(analysis_release_zenodo_resolve_api(FALSE), "https://zenodo.org/api")
  expect_identical(analysis_release_zenodo_resolve_api(), "https://zenodo.org/api")
})

# --------------------------------------------------------------------------- #
# upload_bucket -- direct analog of the sibling's test #3
# --------------------------------------------------------------------------- #

test_that("upload_bucket: PUTs to {bucket}/{basename(archive)}, Bearer token, body is the archive file", {
  archive <- withr::local_tempfile()
  writeBin(charToRaw("abc"), archive)

  captured <- new.env()
  stub_put <- function(url, token, archive_path) {
    assign("url", url, envir = captured)
    assign("token", token, envir = captured)
    assign("bytes", readBin(archive_path, "raw", file.info(archive_path)$size), envir = captured)
  }

  result <- analysis_release_zenodo_upload_bucket(
    "https://zenodo.example/bucket", "token", archive, put = stub_put
  )

  expect_identical(get("url", envir = captured), paste0("https://zenodo.example/bucket/", basename(archive)))
  expect_identical(get("token", envir = captured), "token")
  expect_identical(get("bytes", envir = captured), charToRaw("abc"))
  expect_identical(result, paste0("https://zenodo.example/bucket/", basename(archive)))
})

test_that("upload_bucket: strips a trailing slash from bucket_url before building the target URL", {
  archive <- withr::local_tempfile()
  writeBin(charToRaw("xyz"), archive)
  captured_url <- NULL
  stub_put <- function(url, token, archive_path) captured_url <<- url

  analysis_release_zenodo_upload_bucket("https://zenodo.example/bucket/", "token", archive, put = stub_put)

  expect_identical(captured_url, paste0("https://zenodo.example/bucket/", basename(archive)))
})

# --------------------------------------------------------------------------- #
# get_or_create_deposition -- create path (POST, no id) vs reuse path (GET)
# --------------------------------------------------------------------------- #

test_that("get_or_create_deposition: NULL deposition_id -> POST .../deposit/depositions", {
  captured <- new.env()
  stub_http <- function(method, url, token, body = NULL) {
    assign("method", method, envir = captured)
    assign("url", url, envir = captured)
    assign("token", token, envir = captured)
    assign("body", body, envir = captured)
    list(id = 999, links = list(bucket = "https://bucket.example"))
  }

  result <- analysis_release_zenodo_get_or_create_deposition(
    "https://zenodo.org/api", "tok", deposition_id = NULL, http = stub_http
  )

  expect_identical(get("method", envir = captured), "POST")
  expect_identical(get("url", envir = captured), "https://zenodo.org/api/deposit/depositions")
  expect_identical(get("token", envir = captured), "tok")
  expect_identical(get("body", envir = captured), list())
  expect_identical(result$id, 999)
})

test_that("get_or_create_deposition: explicit deposition_id -> GET .../deposit/depositions/{id}", {
  captured <- new.env()
  stub_http <- function(method, url, token, body = NULL) {
    assign("method", method, envir = captured)
    assign("url", url, envir = captured)
    assign("body", body, envir = captured)
    list(id = 42)
  }

  result <- analysis_release_zenodo_get_or_create_deposition(
    "https://zenodo.org/api", "tok", deposition_id = 42, http = stub_http
  )

  expect_identical(get("method", envir = captured), "GET")
  expect_identical(get("url", envir = captured), "https://zenodo.org/api/deposit/depositions/42")
  expect_null(get("body", envir = captured))
  expect_identical(result$id, 42)
})

# --------------------------------------------------------------------------- #
# set_metadata
# --------------------------------------------------------------------------- #

test_that("set_metadata: PUTs to .../deposit/depositions/{id} with body {\"metadata\": ...}", {
  captured <- new.env()
  stub_http <- function(method, url, token, body = NULL) {
    assign("method", method, envir = captured)
    assign("url", url, envir = captured)
    assign("body", body, envir = captured)
    NULL
  }
  metadata <- list(title = "Test dataset", upload_type = "dataset")

  analysis_release_zenodo_set_metadata(
    "https://zenodo.org/api", "tok", 123, metadata, http = stub_http
  )

  expect_identical(get("method", envir = captured), "PUT")
  expect_identical(get("url", envir = captured), "https://zenodo.org/api/deposit/depositions/123")
  expect_identical(get("body", envir = captured), list(metadata = metadata))
})

# --------------------------------------------------------------------------- #
# publish_deposition
# --------------------------------------------------------------------------- #

test_that("publish_deposition: POSTs to .../deposit/depositions/{id}/actions/publish", {
  captured <- new.env()
  stub_http <- function(method, url, token, body = NULL) {
    assign("method", method, envir = captured)
    assign("url", url, envir = captured)
    list(doi = "10.5281/zenodo.999", conceptdoi = "10.5281/zenodo.998", links = list(html = "https://zenodo.org/record/999"))
  }

  result <- analysis_release_zenodo_publish_deposition(
    "https://zenodo.org/api", "tok", 999, http = stub_http
  )

  expect_identical(get("method", envir = captured), "POST")
  expect_identical(
    get("url", envir = captured), "https://zenodo.org/api/deposit/depositions/999/actions/publish"
  )
  expect_identical(result$doi, "10.5281/zenodo.999")
})

# --------------------------------------------------------------------------- #
# record_doi -- PATCH to the SysNDD admin endpoint, only non-empty fields
# --------------------------------------------------------------------------- #

test_that("record_doi: PATCH .../releases/<id>/doi, admin Bearer token, body has ONLY supplied non-empty fields", {
  captured <- new.env()
  stub_patch <- function(method, url, token, body = NULL) {
    assign("method", method, envir = captured)
    assign("url", url, envir = captured)
    assign("token", token, envir = captured)
    assign("body", body, envir = captured)
    list(release_id = "asr_test")
  }

  result <- analysis_release_zenodo_record_doi(
    "http://localhost:7778",
    "admin-token",
    "asr_deadbeefcafebabe",
    doi_fields = list(
      zenodo_record_id = "999",
      zenodo_record_url = "https://zenodo.org/record/999",
      version_doi = "10.5281/zenodo.999",
      concept_doi = NULL
    ),
    patch = stub_patch
  )

  expect_identical(get("method", envir = captured), "PATCH")
  expect_identical(
    get("url", envir = captured),
    "http://localhost:7778/api/admin/analysis/releases/asr_deadbeefcafebabe/doi"
  )
  expect_identical(get("token", envir = captured), "admin-token")

  body <- get("body", envir = captured)
  expect_setequal(names(body), c("zenodo_record_id", "zenodo_record_url", "version_doi"))
  expect_identical(body$zenodo_record_id, "999")
  expect_identical(body$zenodo_record_url, "https://zenodo.org/record/999")
  expect_identical(body$version_doi, "10.5281/zenodo.999")
  expect_false("concept_doi" %in% names(body))
  expect_identical(result$release_id, "asr_test")
})

test_that("record_doi: an empty-string field is also dropped (never forwarded as an empty value)", {
  captured_body <- NULL
  stub_patch <- function(method, url, token, body = NULL) {
    captured_body <<- body
    list()
  }

  analysis_release_zenodo_record_doi(
    "http://localhost:7778", "admin-token", "asr_x",
    doi_fields = list(zenodo_record_id = "1", concept_doi = ""),
    patch = stub_patch
  )

  expect_setequal(names(captured_body), "zenodo_record_id")
})

test_that("record_doi: an NA_character_ field is dropped, not forwarded as null (nzchar(NA) gotcha)", {
  captured_body <- NULL
  stub_patch <- function(method, url, token, body = NULL) {
    captured_body <<- body
    list()
  }

  analysis_release_zenodo_record_doi(
    "http://localhost:7778", "admin-token", "asr_x",
    doi_fields = list(version_doi = "10.5281/zenodo.1", concept_doi = NA_character_),
    patch = stub_patch
  )

  expect_setequal(names(captured_body), "version_doi")
  expect_false("concept_doi" %in% names(captured_body))
})

# --------------------------------------------------------------------------- #
# manual_doi_command -- the printed fallback when --record-doi is not opted into
# --------------------------------------------------------------------------- #

test_that("manual_doi_command: contains the endpoint path, release id, and all 4 supplied fields", {
  command <- analysis_release_zenodo_manual_doi_command(
    "http://localhost:7778",
    "asr_deadbeefcafebabe",
    doi_fields = list(
      zenodo_record_id = "999",
      zenodo_record_url = "https://zenodo.org/record/999",
      version_doi = "10.5281/zenodo.999",
      concept_doi = "10.5281/zenodo.998"
    )
  )

  expect_true(grepl("/api/admin/analysis/releases/asr_deadbeefcafebabe/doi", command, fixed = TRUE))
  expect_true(grepl("curl -X PATCH", command, fixed = TRUE))
  expect_true(grepl("999", command, fixed = TRUE))
  expect_true(grepl("https://zenodo.org/record/999", command, fixed = TRUE))
  expect_true(grepl("10.5281/zenodo.999", command, fixed = TRUE))
  expect_true(grepl("10.5281/zenodo.998", command, fixed = TRUE))
  expect_true(grepl("zenodo_record_id", command, fixed = TRUE))
  expect_true(grepl("zenodo_record_url", command, fixed = TRUE))
  expect_true(grepl("version_doi", command, fixed = TRUE))
  expect_true(grepl("concept_doi", command, fixed = TRUE))
})

test_that("manual_doi_command: never auto-executes -- it only returns a string", {
  command <- analysis_release_zenodo_manual_doi_command(
    "http://localhost:7778", "asr_x", doi_fields = list(zenodo_record_id = "1")
  )
  expect_true(is.character(command))
  expect_length(command, 1L)
})

test_that("manual_doi_command: an NA_character_ field is omitted, not printed as null/NA (nzchar(NA) gotcha)", {
  command <- analysis_release_zenodo_manual_doi_command(
    "http://localhost:7778",
    "asr_deadbeefcafebabe",
    doi_fields = list(
      zenodo_record_id = "999",
      concept_doi = NA_character_
    )
  )

  expect_true(grepl("zenodo_record_id", command, fixed = TRUE))
  expect_false(grepl("concept_doi", command, fixed = TRUE))
  expect_false(grepl("null", command, fixed = TRUE))
  expect_false(grepl("\"NA\"", command, fixed = TRUE))
})

# --------------------------------------------------------------------------- #
# upload(): full orchestration with stubbed HTTP -- draft-only and publish
# --------------------------------------------------------------------------- #

# Deliberately uses plain `tempfile()`, NOT `withr::local_tempfile()`: the
# latter schedules cleanup via `withr::defer(..., envir = parent.frame())`,
# and `parent.frame()` evaluated INSIDE this helper resolves to this
# function's own (short-lived) call frame, not the calling `test_that()`
# block -- so the files would be deleted the instant this helper returns,
# before the caller can use them (same trap documented in
# `test-unit-analysis-release-zenodo-package.R`'s `make_well_formed_staging()`
# comment). Session tempdir cleanup at process exit is sufficient here.
.zenodo_upload_test_files <- function() {
  archive <- file.path(tempdir(), paste0("zenodo_upload_test_", as.integer(stats::runif(1, 1, 1e9)), ".tar.gz"))
  writeBin(charToRaw("archive bytes"), archive)
  metadata_path <- file.path(tempdir(), paste0("zenodo_upload_test_", as.integer(stats::runif(1, 1, 1e9)), ".json"))
  writeLines('{"title": "Test", "upload_type": "dataset"}', metadata_path)
  list(archive = archive, metadata_path = metadata_path)
}

test_that("upload(): draft-only flow (publish=FALSE) never calls publish_deposition", {
  files <- .zenodo_upload_test_files()
  publish_called <- FALSE

  fake_get_or_create <- function(api, token, deposition_id = NULL) {
    list(
      id = 111,
      links = list(bucket = "https://bucket.example/111", html = "https://zenodo.org/deposit/111"),
      metadata = list(prereserve_doi = list(doi = "10.5281/zenodo.111"))
    )
  }
  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
  fake_publish <- function(api, token, deposition_id) {
    publish_called <<- TRUE
    list()
  }

  result <- analysis_release_zenodo_upload(
    archive_path = files$archive,
    metadata_path = files$metadata_path,
    token = "tok",
    publish = FALSE,
    confirm_publish = FALSE,
    get_or_create_deposition = fake_get_or_create,
    set_metadata = fake_set_metadata,
    upload_bucket = fake_upload_bucket,
    publish_deposition = fake_publish
  )

  expect_false(publish_called)
  expect_identical(result$deposition_id, 111)
  expect_identical(result$reserved_doi, "10.5281/zenodo.111")
  expect_identical(result$draft_url, "https://zenodo.org/deposit/111")
  expect_false(result$published)
  expect_true(is.na(result$version_doi))
})

test_that("upload(): publish=TRUE + confirm_publish=TRUE publishes and fills version/concept DOI + record_url", {
  files <- .zenodo_upload_test_files()

  fake_get_or_create <- function(api, token, deposition_id = NULL) {
    list(id = 222, links = list(bucket = "https://bucket.example/222", html = "https://zenodo.org/deposit/222"))
  }
  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
  fake_publish <- function(api, token, deposition_id) {
    list(
      doi = "10.5281/zenodo.222",
      conceptdoi = "10.5281/zenodo.221",
      links = list(html = "https://zenodo.org/record/222")
    )
  }

  result <- analysis_release_zenodo_upload(
    archive_path = files$archive,
    metadata_path = files$metadata_path,
    token = "tok",
    publish = TRUE,
    confirm_publish = TRUE,
    get_or_create_deposition = fake_get_or_create,
    set_metadata = fake_set_metadata,
    upload_bucket = fake_upload_bucket,
    publish_deposition = fake_publish
  )

  expect_true(result$published)
  expect_identical(result$version_doi, "10.5281/zenodo.222")
  expect_identical(result$concept_doi, "10.5281/zenodo.221")
  expect_identical(result$record_url, "https://zenodo.org/record/222")
})

test_that("upload(): publish=TRUE without confirm_publish stops before any HTTP seam is invoked", {
  files <- .zenodo_upload_test_files()
  called <- FALSE
  fake_get_or_create <- function(...) {
    called <<- TRUE
    list(id = 1, links = list(bucket = "https://bucket.example"))
  }

  expect_error(
    analysis_release_zenodo_upload(
      archive_path = files$archive,
      metadata_path = files$metadata_path,
      token = "tok",
      publish = TRUE,
      confirm_publish = FALSE,
      get_or_create_deposition = fake_get_or_create
    ),
    "--publish requires --confirm-publish"
  )
  expect_false(called)
})

test_that("upload(): missing token stops with a clear message", {
  files <- .zenodo_upload_test_files()
  expect_error(
    analysis_release_zenodo_upload(
      archive_path = files$archive, metadata_path = files$metadata_path, token = ""
    ),
    "ZENODO_TOKEN"
  )
})

test_that("upload(): missing archive file stops with a clear message", {
  files <- .zenodo_upload_test_files()
  expect_error(
    analysis_release_zenodo_upload(
      archive_path = file.path(tempdir(), "does-not-exist.tar.gz"),
      metadata_path = files$metadata_path,
      token = "tok"
    ),
    "Archive does not exist"
  )
})

test_that("upload(): missing metadata file stops with a clear message", {
  files <- .zenodo_upload_test_files()
  expect_error(
    analysis_release_zenodo_upload(
      archive_path = files$archive,
      metadata_path = file.path(tempdir(), "does-not-exist.json"),
      token = "tok"
    ),
    "Metadata does not exist"
  )
})
