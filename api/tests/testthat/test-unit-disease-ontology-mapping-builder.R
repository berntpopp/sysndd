# test-unit-disease-ontology-mapping-builder.R
# Unit tests for disease-ontology-mapping-builder.R (B6) and
# download_mondo_sssom_full (B7) in mondo-functions.R.

library(testthat)
library(withr)
library(tibble)

source_api_file("functions/mondo-index-builder.R", local = FALSE)
source_api_file("functions/disease-ontology-mapping-builder.R", local = FALSE)

# ---------------------------------------------------------------------------
# B7: download_mondo_sssom_full URL resolution
# ---------------------------------------------------------------------------

# M1: Test the extracted .resolve_sssom_url() helper to exercise real URL resolution
# without making any network call (tests the precedence: arg > env > default).
test_that(".resolve_sssom_url returns explicit arg when provided", {
  source_api_file("functions/mondo-functions.R", local = FALSE)

  custom_url <- "https://example.com/custom.sssom.tsv"
  resolved   <- .resolve_sssom_url(sssom_url = custom_url)
  expect_equal(resolved, custom_url)
})

test_that(".resolve_sssom_url reads DISEASE_ONTOLOGY_MONDO_SSSOM_URL env over default", {
  source_api_file("functions/mondo-functions.R", local = FALSE)

  env_url  <- "https://example.com/env.sssom.tsv"
  resolved <- withr::with_envvar(
    list(DISEASE_ONTOLOGY_MONDO_SSSOM_URL = env_url),
    .resolve_sssom_url(sssom_url = NULL)
  )
  expect_equal(resolved, env_url)
})

test_that(".resolve_sssom_url falls back to built-in default when env is unset", {
  source_api_file("functions/mondo-functions.R", local = FALSE)

  resolved <- withr::with_envvar(
    list(DISEASE_ONTOLOGY_MONDO_SSSOM_URL = ""),
    .resolve_sssom_url(sssom_url = NULL)
  )
  expect_true(grepl("mondo\\.sssom\\.tsv", resolved),
    info = paste("expected mondo.sssom.tsv in default URL, got:", resolved))
  expect_true(grepl("^https://", resolved),
    info = "default URL must be https")
})

test_that(".resolve_sssom_url body references DISEASE_ONTOLOGY_MONDO_SSSOM_URL", {
  source_api_file("functions/mondo-functions.R", local = FALSE)

  # URL env-var lookup is now in .resolve_sssom_url(), not download_mondo_sssom_full
  fn_body <- deparse(body(.resolve_sssom_url))
  expect_true(any(grepl("DISEASE_ONTOLOGY_MONDO_SSSOM_URL", fn_body)))
})

test_that("download_mondo_sssom_full uses external_proxy_budget not hardcoded timeout", {
  source_api_file("functions/mondo-functions.R", local = FALSE)

  fn_body <- deparse(body(download_mondo_sssom_full))

  # Must use external_proxy_budget
  expect_true(any(grepl("external_proxy_budget", fn_body)))

  # Must NOT hardcode req_timeout with a literal number (e.g., req_timeout(30))
  hardcoded_timeout <- any(grepl("req_timeout\\s*\\(\\s*[0-9]", fn_body))
  expect_false(hardcoded_timeout)
})

test_that("download_mondo_sssom_full returns cached file when recent", {
  source_api_file("functions/file-functions.R", local = FALSE)
  source_api_file("functions/mondo-functions.R", local = FALSE)

  withr::with_tempdir({
    today       <- format(Sys.Date(), "%Y-%m-%d")
    cached_file <- paste0("mondo-full.", today, ".sssom.tsv")
    writeLines(c("# test", "subject_id\tpredicate_id\tobject_id"), cached_file)

    result <- download_mondo_sssom_full(output_path = getwd(), force = FALSE)
    expect_true(file.exists(result))
    expect_true(grepl("mondo-full", result))
  })
})

# ---------------------------------------------------------------------------
# B6 pure-R unit: disease_mapping_derive logic (no DB)
# ---------------------------------------------------------------------------

test_that("disease_mapping_derive returns empty tibble with expected columns when no rows", {
  # Minimal mock connection that returns empty results
  mock_conn <- structure(list(), class = "MockDBConn")

  # Override dbGetQuery for empty data
  local({
    with_mocked_bindings(
      "dbGetQuery" = function(conn, sql, ...) {
        if (grepl("disease_ontology_set", sql)) {
          data.frame(disease_ontology_id = character(0L), stringsAsFactors = FALSE)
        } else if (grepl("mondo_xref", sql)) {
          data.frame(
            mondo_id = character(0L), target_prefix = character(0L),
            target_id = character(0L), target_id_upper = character(0L),
            target_label = character(0L), predicate = character(0L),
            origin = character(0L), source = character(0L),
            release_version = character(0L),
            stringsAsFactors = FALSE
          )
        } else {
          data.frame()
        }
      },
      .package = "DBI",
      {
        result <- disease_mapping_derive(mock_conn, MONDO_TARGET_ALLOWLIST)
        expect_true(is.data.frame(result))
        expect_true("disease_ontology_id" %in% names(result))
        expect_true("source" %in% names(result))
        expect_equal(nrow(result), 0L)
      }
    )
  })
})

test_that("disease_mapping_derive emits sysndd_native row for each disease_id", {
  mock_conn <- structure(list(), class = "MockDBConn")

  local({
    with_mocked_bindings(
      "dbGetQuery" = function(conn, sql, ...) {
        if (grepl("disease_ontology_set", sql)) {
          data.frame(
            disease_ontology_id = c("OMIM:618524", "Orphanet:530983"),
            stringsAsFactors = FALSE
          )
        } else {
          # Empty xref table
          data.frame(
            mondo_id = character(0L), target_prefix = character(0L),
            target_id = character(0L), target_id_upper = character(0L),
            target_label = character(0L), predicate = character(0L),
            origin = character(0L), source = character(0L),
            release_version = character(0L),
            stringsAsFactors = FALSE
          )
        }
      },
      .package = "DBI",
      {
        result <- disease_mapping_derive(mock_conn, MONDO_TARGET_ALLOWLIST)
        native_rows <- result[result$source == "sysndd_native", ]
        expect_equal(nrow(native_rows), 2L)
        expect_true("OMIM:618524" %in% native_rows$disease_ontology_id)
        expect_true("Orphanet:530983" %in% native_rows$disease_ontology_id)
      }
    )
  })
})

test_that("disease_mapping_derive resolves MONDO hub via xref lookup", {
  mock_conn <- structure(list(), class = "MockDBConn")

  local({
    with_mocked_bindings(
      "dbGetQuery" = function(conn, sql, ...) {
        if (grepl("disease_ontology_set", sql)) {
          data.frame(
            disease_ontology_id = "OMIM:618524",
            stringsAsFactors = FALSE
          )
        } else {
          # xref table: OMIM:618524 -> MONDO:0032745
          data.frame(
            mondo_id      = c("MONDO:0032745", "MONDO:0032745"),
            target_prefix = c("OMIM", "Orphanet"),
            target_id     = c("OMIM:618524", "Orphanet:530983"),
            target_id_upper = c("OMIM:618524", "ORPHANET:530983"),
            target_label  = c(NA_character_, "CTNNB1 syndrome label"),
            predicate     = c("equivalentTo", "exactMatch"),
            origin        = c("obo_xref", "sssom"),
            source        = c(NA_character_, "semapv:ManualMappingCuration"),
            release_version = c("2026-05-05", "2026-05-05"),
            stringsAsFactors = FALSE
          )
        }
      },
      .package = "DBI",
      {
        result <- disease_mapping_derive(mock_conn, MONDO_TARGET_ALLOWLIST)
        # Should have: native, MONDO hub, Orphanet downstream
        sources <- result$source
        expect_true("sysndd_native" %in% sources)
        expect_true(any(grepl("mondo_", sources)))
        # Should include the Orphanet cross-mapping
        expect_true(any(!is.na(result$target_id) & result$target_id == "Orphanet:530983"))
      }
    )
  })
})
