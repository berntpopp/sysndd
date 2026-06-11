#!/usr/bin/env Rscript

# ci-test-summary.R
#
# Helpers that turn a `testthat_results` object into a concise, classified
# end-of-run summary for `make ci-local` / GitHub Actions.
#
# Motivation (issue #360): a successful CI run prints many *expected* skips for
# the default local/PR profile (optional R packages, slow tests, live services).
# Mixed in with the per-test reporter output these look alarming and bury the
# final verdict. This helper does NOT suppress any per-test output and does NOT
# change pass/fail semantics — it only adds a short, human-readable summary at
# the very end that separates "expected local-profile skips" from anything that
# deserves a closer look.
#
# Verification is unchanged: failures and errors are still counted by the caller
# (`run-ci-tests.R`) and still fail the run. This file is presentation-only.

# Patterns for skips that are EXPECTED in the default local/PR profile.
#
# Each entry maps a human-readable bucket label to a case-insensitive regex
# matched against the testthat skip reason. Keep this list in sync with the
# skip helpers in `api/tests/testthat/helper-*.R` and the inline
# `skip_if_not_installed(...)` / `skip_if_not(...)` calls in the test files.
# Anything that does NOT match one of these patterns is reported as an
# "unexpected skip" so it stays visible.
expected_skip_buckets <- function() {
  list(
    # `skip_if_not_installed("ellmer"|"mcptools"|...)` -> "{pkg} is not installed";
    # `skip_if_not(<pkg>_available, ...)` and source-load guards for
    # ontologyIndex / hpo-functions / omim-functions / file-functions.
    "optional R package not installed" = paste(
      "is not installed",
      "not installed",
      "package not available",
      "could not be loaded",
      "requires additional dependencies",
      "function not loaded",
      "ellmer",
      "mcptools",
      "ontologyindex",
      "tidyverse",
      sep = "|"
    ),
    # `skip_if_not_slow_tests()` — slow lane runs nightly in GitHub Actions.
    "slow test (RUN_SLOW_TESTS unset)" = "run_slow_tests|slow test",
    # `skip_if_sysndd_api_not_running()` and integration tests that need a live
    # API/endpoint; expected when no local API process is up.
    "live SysNDD API not running" = paste(
      "sysndd api not running",
      "api not running",
      "api not available",
      "api not responding",
      "api error",
      "endpoint not accessible",
      "requires network access",
      "network access and live api",
      "live api",
      sep = "|"
    ),
    # `skip_if_no_test_db()` — expected only when the test DB container is down;
    # in `make ci-local` the DB is up so these should not appear.
    "test database unavailable" = "test database.*not available|sysndd_db_test",
    # `skip_if_mailpit_not_*` — Mailpit only runs in the nightly slow lane.
    "Mailpit not configured" = "mailpit",
    # httptest2 fixtures absent + offline: cannot record or replay.
    "no fixtures and no network" = "no fixtures|cannot record or mock|fixture not found|fixture file",
    # Integration tests gated on seeded auth/admin state or external creds
    # (JWT tokens, Gemini, seeded cached summaries). Not exercised by the
    # default local/PR profile.
    "auth/seed/credentials required" = paste(
      "requires authentication",
      "requires administrator",
      "requires valid jwt",
      "requires gemini",
      "requires seeded",
      "requires test fixture",
      "needs integration test",
      sep = "|"
    ),
    # Generic env/config gating left for completeness.
    "optional integration setting unset" =
      "environment variable|env( var)? (is )?(not )?set|not configured|integration .* disabled"
  )
}

# Extract every skip reason from a `testthat_results` object as a character
# vector. We read the per-expectation objects (class `expectation_skip`) rather
# than the aggregated data frame because the data frame does not carry the
# skip message text.
collect_skip_reasons <- function(results) {
  reasons <- character(0)
  for (test_result in results) {
    for (expectation in test_result$results) {
      if (inherits(expectation, "expectation_skip")) {
        # Reasons are emitted as "Reason: <text>"; strip the prefix for display.
        reason <- sub("^Reason:\\s*", "", conditionMessage(expectation))
        reasons <- c(reasons, reason)
      }
    }
  }
  reasons
}

# Classify a vector of skip reasons into expected buckets + an unexpected list.
classify_skips <- function(reasons) {
  buckets <- expected_skip_buckets()
  bucket_counts <- setNames(integer(length(buckets)), names(buckets))
  unexpected <- character(0)

  for (reason in reasons) {
    matched <- FALSE
    for (label in names(buckets)) {
      if (grepl(buckets[[label]], reason, ignore.case = TRUE)) {
        bucket_counts[[label]] <- bucket_counts[[label]] + 1L
        matched <- TRUE
        break
      }
    }
    if (!matched) {
      unexpected <- c(unexpected, reason)
    }
  }

  list(
    expected = bucket_counts[bucket_counts > 0],
    unexpected = unexpected
  )
}

# Print the classified skip summary. `mode` is the CI selection mode
# ("fast"/"full") and is shown for context only.
print_ci_test_summary <- function(results, mode = "full") {
  reasons <- collect_skip_reasons(results)

  cat("\n")
  cat("==================================================\n")
  cat(sprintf("CI test skip summary (%s profile)\n", mode))
  cat("==================================================\n")

  if (!length(reasons)) {
    cat("No tests were skipped.\n")
    return(invisible(NULL))
  }

  classified <- classify_skips(reasons)

  if (length(classified$expected)) {
    cat("Expected local-profile skips (not actionable):\n")
    for (label in names(classified$expected)) {
      cat(sprintf("  - %-38s x%d\n", label, classified$expected[[label]]))
    }
    cat(
      "  These are normal when running the default local/PR profile: optional\n",
      "  R packages (ellmer, mcptools, ontologyIndex, tidyverse) are absent,\n",
      "  RUN_SLOW_TESTS is unset, and live services (SysNDD API, Mailpit) are\n",
      "  not running. The nightly/full GitHub Actions lanes exercise them.\n",
      sep = ""
    )
  }

  if (length(classified$unexpected)) {
    cat("\nUnexpected skips (review these):\n")
    for (reason in unique(classified$unexpected)) {
      n <- sum(classified$unexpected == reason)
      cat(sprintf("  - %s x%d\n", reason, n))
    }
  }

  cat("\n")
  invisible(NULL)
}
