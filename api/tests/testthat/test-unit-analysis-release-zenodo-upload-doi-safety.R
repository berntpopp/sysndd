# Unit tests for the Codex round-2 hardening of the analysis-snapshot
# RELEASE Zenodo upload/DOI-record-back logic (#573 Slice C):
# api/functions/analysis-snapshot-release-zenodo-upload.R.
#
# Split out of the sibling test-unit-analysis-release-zenodo-upload.R (which
# covers the pre-existing upload/deposition-lifecycle behavior) to keep both
# files under the repo's 600-line soft ceiling -- mirrors the
# `-docs.R`/`-verify.R` and `comparisons-functions.R`/`comparisons-parsers.R`
# split precedent.
#
# Pure, DB-free, NO NETWORK: every HTTP boundary is an injectable seam
# (`patch`/`record_doi_fn`) so tests supply plain stub closures instead of a
# mocking library or a real network call.
#
# Covers:
# - item 2 (HIGH): `record_doi()`, `manual_doi_command()`, and
#   `print_doi_record_back()` all reject an invalid `--release-id` (a quote,
#   `;`, embedded newline, or `../` traversal shape) BEFORE building any
#   admin PATCH URL or printed shell command from it.
# - item 2 (HIGH) defense in depth: `manual_doi_command()` `shQuote()`s the
#   URL and JSON body it prints.
# - item 3 (MEDIUM): `print_doi_record_back()` never prints a populated PATCH
#   command for a DRAFT upload (published-only rule), regardless of whether
#   `--record-doi` was passed.

library(testthat)

source_api_file("functions/analysis-snapshot-release-zenodo-upload.R", local = FALSE)

# --------------------------------------------------------------------------- #
# record_doi / manual_doi_command -- release-id validation (Codex round-2
# item 2, HIGH): an invalid --release-id must be rejected BEFORE either
# builds the admin PATCH URL or the printed shell command from it.
# --------------------------------------------------------------------------- #

.invalid_release_ids_round2 <- list(
  quote = "asr_deadbeefcafeb' OR '1'='1",
  semicolon = "asr_deadbeefcafeb; rm -rf ~",
  newline = "asr_deadbeefcafeb\nrm -rf /",
  traversal = "../evil"
)

for (.label in names(.invalid_release_ids_round2)) {
  local({
    label <- .label
    bad_id <- .invalid_release_ids_round2[[label]]

    test_that(paste0("record_doi: rejects a release_id containing ", label, " before calling patch"), {
      called <- FALSE
      stub_patch <- function(method, url, token, body = NULL) {
        called <<- TRUE
        list()
      }
      expect_error(
        analysis_release_zenodo_record_doi(
          "http://localhost:7778", "admin-token", bad_id,
          doi_fields = list(zenodo_record_id = "1"), patch = stub_patch
        ),
        "Invalid analysis-snapshot release id"
      )
      expect_false(called)
    })

    test_that(paste0("manual_doi_command: rejects a release_id containing ", label, " before building any command"), {
      expect_error(
        analysis_release_zenodo_manual_doi_command(
          "http://localhost:7778", bad_id, doi_fields = list(zenodo_record_id = "1")
        ),
        "Invalid analysis-snapshot release id"
      )
    })
  })
}

test_that("record_doi: accepts a well-formed asr_<16 hex> release_id", {
  captured_url <- NULL
  stub_patch <- function(method, url, token, body = NULL) {
    captured_url <<- url
    list()
  }
  analysis_release_zenodo_record_doi(
    "http://localhost:7778", "admin-token", "asr_deadbeefcafebabe",
    doi_fields = list(zenodo_record_id = "1"), patch = stub_patch
  )
  expect_identical(captured_url, "http://localhost:7778/api/admin/analysis/releases/asr_deadbeefcafebabe/doi")
})

test_that("manual_doi_command: shQuote()s the URL and JSON body (defense in depth, Codex round-2 item 2)", {
  # A well-formed release_id can never itself carry shell metacharacters (the
  # validator rejects those), but a doi_fields VALUE is not release-id
  # shaped -- shQuote() on the whole JSON body means even an adversarial
  # field value cannot break out of the printed `curl` command's arguments.
  fields <- list(zenodo_record_id = "1' ; rm -rf ~ ; #")
  command <- analysis_release_zenodo_manual_doi_command(
    "http://localhost:7778", "asr_deadbeefcafebabe", doi_fields = fields
  )

  expected_url <- "http://localhost:7778/api/admin/analysis/releases/asr_deadbeefcafebabe/doi"
  expected_body_json <- as.character(jsonlite::toJSON(fields, auto_unbox = TRUE))

  expect_true(grepl(shQuote(expected_url), command, fixed = TRUE))
  expect_true(grepl(shQuote(expected_body_json), command, fixed = TRUE))
  # The dangerous value must never appear as a NAIVELY single-quoted,
  # unescaped argument -- that would let a POSIX shell split it into
  # multiple commands at the un-escaped `;`.
  expect_false(grepl("-d '1' ; rm -rf ~ ; #'", command, fixed = TRUE))
})

# --------------------------------------------------------------------------- #
# print_doi_record_back -- the CLI-facing DOI print step. Codex round-2
# item 2 (HIGH, release-id validation before ANY URL/command is built) and
# item 3 (MEDIUM, no populated PATCH command for a DRAFT).
# --------------------------------------------------------------------------- #

.captured_prints <- function() {
  out <- character(0)
  list(
    printer = function(...) out <<- c(out, paste0(..., collapse = "")),
    get = function() paste(out, collapse = "")
  )
}

.published_result <- list(
  deposition_id = 555,
  reserved_doi = "10.5281/zenodo.555",
  draft_url = "https://zenodo.org/deposit/555",
  published = TRUE,
  version_doi = "10.5281/zenodo.555",
  concept_doi = "10.5281/zenodo.554",
  record_url = "https://zenodo.org/record/555"
)

.draft_result <- list(
  deposition_id = 555,
  reserved_doi = "10.5281/zenodo.555",
  draft_url = "https://zenodo.org/deposit/555",
  published = FALSE,
  version_doi = NA_character_,
  concept_doi = NA_character_,
  record_url = NA_character_
)

test_that("print_doi_record_back: DRAFT upload prints NO populated PATCH command (Codex round-2 item 3, MEDIUM)", {
  captured <- .captured_prints()
  analysis_release_zenodo_print_doi_record_back(
    .draft_result, "asr_deadbeefcafebabe", "http://localhost:7778",
    record_doi = FALSE, printer = captured$printer
  )
  output <- captured$get()

  expect_false(grepl("curl -X PATCH", output, fixed = TRUE))
  expect_false(grepl("/doi", output, fixed = TRUE))
  expect_true(grepl("not published", output, fixed = TRUE) || grepl("Draft", output, fixed = TRUE))
  expect_true(grepl("--publish --confirm-publish", output, fixed = TRUE))
})

test_that("print_doi_record_back: DRAFT upload with --record-doi still prints NO PATCH command (published-only rule)", {
  # Even if the operator passed --record-doi, a draft's DOI is never final --
  # the published-only rule must win regardless of the record_doi flag.
  captured <- .captured_prints()
  withr::local_envvar(SYSNDD_ADMIN_TOKEN = "admin-token")
  analysis_release_zenodo_print_doi_record_back(
    .draft_result, "asr_deadbeefcafebabe", "http://localhost:7778",
    record_doi = TRUE, printer = captured$printer
  )
  output <- captured$get()

  expect_false(grepl("curl -X PATCH", output, fixed = TRUE))
  expect_false(grepl("DOI recorded on the SysNDD release head", output, fixed = TRUE))
})

test_that("print_doi_record_back: PUBLISHED upload without --record-doi prints the populated manual command", {
  captured <- .captured_prints()
  analysis_release_zenodo_print_doi_record_back(
    .published_result, "asr_deadbeefcafebabe", "http://localhost:7778",
    record_doi = FALSE, printer = captured$printer
  )
  output <- captured$get()

  expect_true(grepl("curl -X PATCH", output, fixed = TRUE))
  expect_true(grepl("10.5281/zenodo.555", output, fixed = TRUE))
})

test_that("print_doi_record_back: PUBLISHED upload with --record-doi and admin token auto-records via the injected seam (no manual command printed)", {
  captured <- .captured_prints()
  withr::local_envvar(SYSNDD_ADMIN_TOKEN = "admin-token")
  captured_call <- new.env()
  stub_record_doi_fn <- function(sysndd_api_base_url, admin_token, release_id, doi_fields) {
    assign("release_id", release_id, envir = captured_call)
    assign("doi_fields", doi_fields, envir = captured_call)
    list(release_id = release_id, version_doi = doi_fields$version_doi, zenodo_record_url = doi_fields$zenodo_record_url)
  }

  analysis_release_zenodo_print_doi_record_back(
    .published_result, "asr_deadbeefcafebabe", "http://localhost:7778",
    record_doi = TRUE, printer = captured$printer, record_doi_fn = stub_record_doi_fn
  )
  output <- captured$get()

  expect_false(grepl("curl -X PATCH", output, fixed = TRUE))
  expect_true(grepl("DOI recorded on the SysNDD release head", output, fixed = TRUE))
  expect_identical(get("release_id", envir = captured_call), "asr_deadbeefcafebabe")
  expect_identical(get("doi_fields", envir = captured_call)$version_doi, "10.5281/zenodo.555")
})

for (.label in names(.invalid_release_ids_round2)) {
  local({
    label <- .label
    bad_id <- .invalid_release_ids_round2[[label]]

    test_that(paste0(
      "print_doi_record_back: rejects a release_id containing ", label,
      " before building any URL/command (Codex round-2 item 2, HIGH)"
    ), {
      captured <- .captured_prints()
      expect_error(
        analysis_release_zenodo_print_doi_record_back(
          .published_result, bad_id, "http://localhost:7778",
          record_doi = FALSE, printer = captured$printer
        ),
        "Invalid analysis-snapshot release id"
      )
      # Nothing (no manual command, no partial URL) was ever printed before
      # the validator stopped the run.
      expect_false(grepl("curl", captured$get(), fixed = TRUE))
    })
  })
}

test_that("print_doi_record_back: no --release-id supplied prints guidance and never validates/builds anything", {
  captured <- .captured_prints()
  expect_no_error(
    analysis_release_zenodo_print_doi_record_back(
      .published_result, NULL, "http://localhost:7778",
      record_doi = FALSE, printer = captured$printer
    )
  )
  expect_true(grepl("No --release-id supplied", captured$get(), fixed = TRUE))
})
