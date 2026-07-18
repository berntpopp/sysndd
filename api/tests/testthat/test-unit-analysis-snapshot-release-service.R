# tests/testthat/test-unit-analysis-snapshot-release-service.R
#
# Unit tests for the analysis-snapshot RELEASE service layer (#573 Slice A /
# Task A5): api/services/analysis-snapshot-release-service.R.
#
# Pure unit tests, NO DATABASE. The A4 build orchestrator
# (`analysis_snapshot_release_build`) and the A3 repository functions
# (`analysis_release_list/get/get_file/get_bundle/publish/set_doi/
# delete_draft`) are entirely STUBBED: this file never sources
# `functions/analysis-snapshot-release.R` or
# `functions/analysis-snapshot-release-repository.R`, it only defines
# minimal stand-ins for the names the service calls, then reassigns them
# per-test via `with_release_mocks()`. This mirrors the established
# `test-unit-metadata-vocabulary-service.R` mocking pattern: source
# core/errors.R + the service with `source_api_file(local = FALSE)`, look up
# `environment(<a service fn>)` to find where the service's free-variable
# lookups resolve, then temporarily reassign bindings there.

library(testthat)

source_api_file("core/errors.R", local = FALSE)

# Minimal stand-ins for the A3/A4 functions the service calls, so the service
# file sources cleanly (its body only looks these names up at CALL time, but
# defining them up front keeps `with_release_mocks()`'s get/assign symmetric
# and self-documenting about the service's full dependency surface).
analysis_snapshot_release_build <- function(...) stop("stub: analysis_snapshot_release_build not mocked")
analysis_release_list <- function(...) stop("stub: analysis_release_list not mocked")
analysis_release_get <- function(...) stop("stub: analysis_release_get not mocked")
analysis_release_get_file <- function(...) stop("stub: analysis_release_get_file not mocked")
analysis_release_get_bundle <- function(...) stop("stub: analysis_release_get_bundle not mocked")
analysis_release_publish <- function(...) stop("stub: analysis_release_publish not mocked")
analysis_release_set_doi <- function(...) stop("stub: analysis_release_set_doi not mocked")
analysis_release_delete_draft <- function(...) stop("stub: analysis_release_delete_draft not mocked")
# Identity stand-in for the PUBLIC projection: the REAL allowlist behaviour is
# covered against the real function in the repository integration test; here the
# service tests only verify svc_release_list/get ROUTE through it.
analysis_release_public_head <- function(head) head

source_api_file("services/analysis-snapshot-release-service.R", local = FALSE)

# The environment the service functions were defined in (same top-level frame
# the stand-ins above and core/errors.R were sourced into).
release_svc_env <- environment(svc_release_build)

#' Temporarily reassign a set of names in `release_svc_env`, restoring the
#' previous bindings on exit (mirrors `with_repo_mocks()` in
#' test-unit-metadata-vocabulary-service.R).
with_release_mocks <- function(mocks, code) {
  originals <- list()
  for (name in names(mocks)) {
    originals[[name]] <- get(name, envir = release_svc_env)
    assign(name, mocks[[name]], envir = release_svc_env)
  }
  on.exit({
    for (name in names(originals)) {
      assign(name, originals[[name]], envir = release_svc_env)
    }
  }, add = TRUE)
  force(code)
}

#' Build a classed condition matching A4's `c(<name>, "error", "condition")`
#' shape (see functions/analysis-snapshot-release.R `.analysis_release_condition`).
release_condition <- function(class_name, message) {
  structure(
    class = c(class_name, "error", "condition"),
    list(message = message, call = NULL)
  )
}

#' Minimal Plumber-response stand-in: a settable `$status` + a `setHeader()`
#' that records headers (needed for the 503 + Retry-After lock path).
release_fake_res <- function() {
  res <- new.env()
  res$status <- NULL
  res$headers <- list()
  res$setHeader <- function(name, value) {
    res$headers[[name]] <- value
    invisible(NULL)
  }
  res
}

# =============================================================================
# svc_release_build
# =============================================================================

test_that("build success (created=TRUE) sets 201 and returns the head", {
  head <- list(release_id = "asr_abc123", status = "published")
  res <- release_fake_res()
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) list(release = head, created = TRUE)),
    {
      out <- svc_release_build(res)
      expect_equal(res$status, 201L)
      expect_identical(out, head)
    }
  )
})

test_that("build idempotent (created=FALSE) sets 200 and returns the SAME head, no error", {
  head <- list(release_id = "asr_dup456", status = "published")
  res <- release_fake_res()
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) list(release = head, created = FALSE)),
    {
      out <- svc_release_build(res)
      expect_equal(res$status, 200L)
      expect_identical(out, head)
    }
  )
})

test_that("build forwards layers/title/etc through to the orchestrator", {
  captured <- NULL
  res <- release_fake_res()
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) {
      captured <<- list(...)
      list(release = list(release_id = "asr_x"), created = TRUE)
    }),
    {
      svc_release_build(
        res,
        title = "My Title",
        scope_statement = "scope",
        license = "CC0-1.0",
        publish = FALSE,
        created_by = 7L,
        conn = "conn-stub"
      )
    }
  )
  expect_equal(captured$title, "My Title")
  expect_equal(captured$scope_statement, "scope")
  expect_equal(captured$license, "CC0-1.0")
  expect_false(captured$publish)
  expect_equal(captured$created_by, 7L)
  expect_equal(captured$conn, "conn-stub")
  expect_false("layers" %in% names(captured)) # NULL layers -> not forwarded, orchestrator uses its own default
})

release_build_condition_cases <- list(
  release_snapshot_not_available = "layer functional_clusters is not available for release: snapshot_missing",
  release_source_incoherent = "layer functional_clusters failed the hard coherence re-check: boom",
  release_reproducibility_missing = "layer phenotype_clusters has no reproducibility bundle; the release requires one",
  release_source_version_mismatch = "shared source_data_version mismatch across layers: v1 vs v2",
  release_dependency_lineage_mismatch = "layer phenotype_functional_correlations snapshot changed between read and insert"
)

test_that("build maps release_snapshot_not_available to a 400 carrying the reason", {
  res <- release_fake_res()
  msg <- release_build_condition_cases$release_snapshot_not_available
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_snapshot_not_available", msg))),
    {
      err <- tryCatch(svc_release_build(res), error = function(e) e)
      expect_s3_class(err, "error_400")
      expect_match(conditionMessage(err), "functional_clusters", fixed = TRUE)
      expect_match(conditionMessage(err), "snapshot_missing", fixed = TRUE)
    }
  )
})

test_that("build maps release_source_incoherent to a 400 carrying the reason", {
  res <- release_fake_res()
  msg <- release_build_condition_cases$release_source_incoherent
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_source_incoherent", msg))),
    {
      err <- tryCatch(svc_release_build(res), error = function(e) e)
      expect_s3_class(err, "error_400")
      expect_match(conditionMessage(err), "functional_clusters", fixed = TRUE)
      expect_match(conditionMessage(err), "hard coherence", fixed = TRUE)
    }
  )
})

test_that("build maps release_reproducibility_missing to a 400 carrying the reason", {
  res <- release_fake_res()
  msg <- release_build_condition_cases$release_reproducibility_missing
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_reproducibility_missing", msg))),
    {
      err <- tryCatch(svc_release_build(res), error = function(e) e)
      expect_s3_class(err, "error_400")
      expect_match(conditionMessage(err), "phenotype_clusters", fixed = TRUE)
      expect_match(conditionMessage(err), "reproducibility bundle", fixed = TRUE)
    }
  )
})

test_that("build maps release_source_version_mismatch to a 400 carrying the reason", {
  res <- release_fake_res()
  msg <- release_build_condition_cases$release_source_version_mismatch
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_source_version_mismatch", msg))),
    {
      err <- tryCatch(svc_release_build(res), error = function(e) e)
      expect_s3_class(err, "error_400")
      expect_match(conditionMessage(err), "v1 vs v2", fixed = TRUE)
    }
  )
})

test_that("build maps release_dependency_lineage_mismatch to a 400 carrying the reason", {
  res <- release_fake_res()
  msg <- release_build_condition_cases$release_dependency_lineage_mismatch
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_dependency_lineage_mismatch", msg))),
    {
      err <- tryCatch(svc_release_build(res), error = function(e) e)
      expect_s3_class(err, "error_400")
      expect_match(conditionMessage(err), "phenotype_functional_correlations", fixed = TRUE)
      expect_match(conditionMessage(err), "changed between read and insert", fixed = TRUE)
    }
  )
})

test_that("build maps release_lock_unavailable to a 503 + Retry-After (NOT a 400)", {
  res <- release_fake_res()
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) {
      stop(release_condition("release_lock_unavailable", "sources are being refreshed; retry shortly"))
    }),
    {
      out <- svc_release_build(res)
      expect_equal(res$status, 503L)
      expect_equal(res$headers[["Retry-After"]], "5")
      expect_equal(out$error, "release_lock_unavailable")
      expect_match(out$message, "refreshed", fixed = TRUE)
    }
  )
})

test_that("build lets a non-release_* error propagate unmapped (500 path)", {
  res <- release_fake_res()
  with_release_mocks(
    list(analysis_snapshot_release_build = function(...) stop("boom: unexpected DB error")),
    {
      err <- tryCatch(svc_release_build(res), error = function(e) e)
      expect_false(inherits(err, "error_400"))
      expect_false(inherits(err, "http_problem_error"))
      expect_match(conditionMessage(err), "boom: unexpected DB error", fixed = TRUE)
    }
  )
})

# =============================================================================
# svc_release_publish
# =============================================================================

test_that("publish: unknown id -> 404", {
  with_release_mocks(
    list(
      analysis_release_publish = function(...) FALSE,
      analysis_release_get = function(...) NULL
    ),
    {
      expect_error(svc_release_publish("asr_missing"), class = "error_404")
    }
  )
})

test_that("publish: success returns the (now-published) head", {
  head <- list(release_id = "asr_pub1", status = "published")
  with_release_mocks(
    list(
      analysis_release_publish = function(...) TRUE,
      analysis_release_get = function(release_id, include_draft, conn = NULL) {
        expect_true(include_draft)
        head
      }
    ),
    {
      out <- svc_release_publish("asr_pub1")
      expect_identical(out, head)
    }
  )
})

# =============================================================================
# svc_release_set_doi
# =============================================================================

test_that("set_doi: unknown id -> 404", {
  with_release_mocks(
    list(
      analysis_release_set_doi = function(...) FALSE,
      analysis_release_get = function(...) NULL
    ),
    {
      expect_error(
        svc_release_set_doi("asr_missing", list(version_doi = "10.5281/zenodo.1")),
        class = "error_404"
      )
    }
  )
})

test_that("set_doi: success returns the updated head and forwards doi_fields verbatim", {
  head <- list(release_id = "asr_doi1", version_doi = "10.5281/zenodo.1")
  captured <- NULL
  with_release_mocks(
    list(
      analysis_release_set_doi = function(release_id, doi_fields, conn = NULL) {
        captured <<- doi_fields
        TRUE
      },
      analysis_release_get = function(...) head
    ),
    {
      out <- svc_release_set_doi("asr_doi1", list(version_doi = "10.5281/zenodo.1"))
      expect_identical(out, head)
      expect_equal(captured$version_doi, "10.5281/zenodo.1")
    }
  )
})

# =============================================================================
# svc_release_delete_draft
# =============================================================================

test_that("delete_draft: unknown id -> 404", {
  with_release_mocks(
    list(analysis_release_get = function(...) NULL),
    {
      expect_error(svc_release_delete_draft("asr_missing"), class = "error_404")
    }
  )
})

test_that("delete_draft: published release -> 400 with the exact reason message", {
  with_release_mocks(
    list(analysis_release_get = function(...) list(release_id = "asr_pub", status = "published")),
    {
      err <- tryCatch(svc_release_delete_draft("asr_pub"), error = function(e) e)
      expect_s3_class(err, "error_400")
      expect_equal(
        conditionMessage(err),
        "Cannot delete a published release; only drafts are deletable"
      )
    }
  )
})

test_that("delete_draft: draft release deletes and returns deleted=TRUE", {
  delete_called_with <- NULL
  with_release_mocks(
    list(
      analysis_release_get = function(...) list(release_id = "asr_draft1", status = "draft"),
      analysis_release_delete_draft = function(release_id, conn = NULL) {
        delete_called_with <<- release_id
        TRUE
      }
    ),
    {
      out <- svc_release_delete_draft("asr_draft1")
      expect_equal(out, list(deleted = TRUE, release_id = "asr_draft1"))
      expect_equal(delete_called_with, "asr_draft1")
    }
  )
})

# =============================================================================
# svc_release_list (public)
# =============================================================================

test_that("list: reads only status='published' from the repository and projects each head", {
  captured <- NULL
  rows <- list(list(release_id = "asr_1"), list(release_id = "asr_2"))
  with_release_mocks(
    list(analysis_release_list = function(status, limit, offset, conn = NULL) {
      captured <<- list(status = status, limit = limit, offset = offset)
      rows
    }),
    {
      out <- svc_release_list(limit = 10, offset = 5)
      expect_identical(out, rows) # identity projection stub -> verbatim
      expect_equal(captured$status, "published")
      expect_equal(captured$limit, 10L)
      expect_equal(captured$offset, 5L)
    }
  )
})

test_that("list: clamps limit to [1,100] and offset to >=0 (L1)", {
  captured <- NULL
  capture_loader <- function(status, limit, offset, conn = NULL) {
    captured <<- list(limit = limit, offset = offset)
    list()
  }
  cases <- list(
    list(in_limit = -1, in_offset = -5, out_limit = 1L, out_offset = 0L),
    list(in_limit = 1e6, in_offset = 10, out_limit = 100L, out_offset = 10L),
    list(in_limit = "abc", in_offset = "xyz", out_limit = 50L, out_offset = 0L)
  )
  with_release_mocks(list(analysis_release_list = capture_loader), {
    for (case in cases) {
      svc_release_list(limit = case$in_limit, offset = case$in_offset)
      expect_equal(captured$limit, case$out_limit)
      expect_equal(captured$offset, case$out_offset)
    }
  })
})

test_that("list + get route heads through analysis_release_public_head (H1)", {
  marker <- list(release_id = "asr_projected", projected = TRUE)
  with_release_mocks(
    list(
      analysis_release_list = function(...) list(list(release_id = "asr_raw", created_by_user_id = 9L)),
      analysis_release_get = function(...) list(release_id = "asr_raw", created_by_user_id = 9L),
      analysis_release_public_head = function(head) marker
    ),
    {
      expect_identical(svc_release_list()[[1]], marker)
      expect_identical(svc_release_get("asr_raw"), marker)
    }
  )
})

# =============================================================================
# svc_release_get (public)
# =============================================================================

test_that("get: draft or unknown (stub returns NULL) -> 404, and include_draft is FALSE", {
  captured_include_draft <- NULL
  with_release_mocks(
    list(analysis_release_get = function(release_id, include_draft, conn = NULL) {
      captured_include_draft <<- include_draft
      NULL
    }),
    {
      expect_error(svc_release_get("asr_draft_or_missing"), class = "error_404")
    }
  )
  expect_false(captured_include_draft)
})

test_that("get: success returns the head", {
  head <- list(release_id = "asr_pub2", status = "published")
  with_release_mocks(
    list(analysis_release_get = function(...) head),
    {
      out <- svc_release_get("asr_pub2")
      expect_identical(out, head)
    }
  )
})

# =============================================================================
# svc_release_manifest (public)
# =============================================================================

test_that("manifest: unknown -> 404", {
  with_release_mocks(
    list(analysis_release_get_file = function(...) NULL),
    {
      expect_error(svc_release_manifest("asr_missing"), class = "error_404")
    }
  )
})

test_that("manifest: returns {bytes, media_type='application/json', content_sha256} and asks for manifest.json only", {
  captured_path <- NULL
  bytes <- charToRaw('{"release_id":"asr_1"}')
  with_release_mocks(
    list(analysis_release_get_file = function(release_id, file_path, include_draft, conn = NULL) {
      captured_path <<- file_path
      expect_false(include_draft)
      list(bytes = bytes, media_type = "application/json", content_sha256 = "abc123")
    }),
    {
      out <- svc_release_manifest("asr_1")
      expect_identical(out, list(bytes = bytes, media_type = "application/json", content_sha256 = "abc123"))
    }
  )
  expect_equal(captured_path, "manifest.json")
})

# =============================================================================
# svc_release_file (public)
# =============================================================================

test_that("file: unknown path -> 404", {
  with_release_mocks(
    list(analysis_release_get_file = function(...) NULL),
    {
      expect_error(svc_release_file("asr_1", "does/not/exist.json"), class = "error_404")
    }
  )
})

test_that("file: returns {bytes, media_type, content_sha256} for a known path", {
  bytes <- charToRaw("# README")
  with_release_mocks(
    list(analysis_release_get_file = function(release_id, file_path, include_draft, conn = NULL) {
      expect_false(include_draft)
      list(bytes = bytes, media_type = "text/markdown", content_sha256 = "def456")
    }),
    {
      out <- svc_release_file("asr_1", "README.md")
      expect_identical(out, list(bytes = bytes, media_type = "text/markdown", content_sha256 = "def456"))
    }
  )
})

# =============================================================================
# svc_release_bundle (public)
# =============================================================================

test_that("bundle: unknown -> 404", {
  with_release_mocks(
    list(analysis_release_get_bundle = function(...) NULL),
    {
      expect_error(svc_release_bundle("asr_missing"), class = "error_404")
    }
  )
})

test_that("bundle: returns {bytes, sha256, filename}", {
  bytes <- as.raw(c(1, 2, 3))
  with_release_mocks(
    list(analysis_release_get_bundle = function(release_id, include_draft, conn = NULL) {
      expect_false(include_draft)
      list(bytes = bytes, sha256 = "ghi789", filename = "asr_1.tar.gz")
    }),
    {
      out <- svc_release_bundle("asr_1")
      expect_identical(out, list(bytes = bytes, sha256 = "ghi789", filename = "asr_1.tar.gz"))
    }
  )
})
