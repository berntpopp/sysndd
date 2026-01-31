# test-external-proxy-endpoints.R
# Tests for external proxy endpoint logic and error isolation
#
# These tests validate the aggregation pattern and error isolation logic used
# by the /api/external/gene/<symbol> endpoint. Tests use mock functions to
# simulate various success/failure scenarios without making real API calls.

# Load required packages
library(dplyr)
library(rlang)  # For %||% operator

# Source required files using helper-paths.R (loaded automatically by setup.R)
source_api_file("functions/external-proxy-functions.R", local = FALSE)
source_api_file("core/middleware.R", local = FALSE)

# ============================================================================
# Aggregation error isolation tests
# ============================================================================

describe("aggregation error isolation", {
  it("returns partial data when some sources fail", {
    # Simulate the aggregation logic pattern from external_endpoints.R
    sources <- list(
      gnomad = function() mock_gnomad_constraints_success("BRCA1"),
      uniprot = function() stop("UniProt timeout"),
      ensembl = function() mock_source_not_found("ensembl")
    )

    results <- list(sources = list(), errors = list())

    for (source_name in names(sources)) {
      result <- tryCatch({
        sources[[source_name]]()
      }, error = function(e) {
        list(error = TRUE, source = source_name, message = conditionMessage(e))
      })

      if (is.list(result) && isTRUE(result$error)) {
        results$errors[[source_name]] <- create_external_error(
          source_name, result$message
        )
      } else if (is.list(result) && isTRUE(result$found == FALSE)) {
        results$sources[[source_name]] <- list(found = FALSE)
      } else {
        results$sources[[source_name]] <- result
      }
    }

    # gnomAD succeeded, ensembl returned not-found, uniprot errored
    expect_equal(length(results$sources), 2)  # gnomad + ensembl (not found)
    expect_equal(length(results$errors), 1)   # uniprot
    expect_equal(results$errors$uniprot$source, "uniprot")
    expect_equal(results$sources$gnomad$source, "gnomad")
  })

  it("returns 503 structure when ALL sources fail", {
    sources <- list(
      gnomad = function() stop("gnomAD down"),
      uniprot = function() stop("UniProt down")
    )

    results <- list(sources = list(), errors = list())

    for (source_name in names(sources)) {
      result <- tryCatch({
        sources[[source_name]]()
      }, error = function(e) {
        list(error = TRUE, source = source_name, message = conditionMessage(e))
      })

      if (is.list(result) && isTRUE(result$error)) {
        results$errors[[source_name]] <- create_external_error(
          source_name, result$message
        )
      } else {
        results$sources[[source_name]] <- result
      }
    }

    # All failed - no sources, only errors
    expect_equal(length(results$sources), 0)
    expect_equal(length(results$errors), 2)
  })

  it("handles mixed success, not-found, and error gracefully", {
    sources <- list(
      gnomad = function() mock_gnomad_constraints_success("SHANK3"),
      uniprot = function() mock_source_not_found("uniprot"),
      alphafold = function() mock_source_error("alphafold"),
      mgi = function() stop("Network error"),
      rgd = function() mock_source_not_found("rgd")
    )

    results <- list(sources = list(), errors = list())

    for (source_name in names(sources)) {
      result <- tryCatch({
        sources[[source_name]]()
      }, error = function(e) {
        list(error = TRUE, source = source_name, message = conditionMessage(e))
      })

      if (is.list(result) && isTRUE(result$error)) {
        results$errors[[source_name]] <- create_external_error(
          source_name, result$message %||% "unavailable"
        )
      } else if (is.list(result) && isTRUE(result$found == FALSE)) {
        results$sources[[source_name]] <- list(found = FALSE)
      } else {
        results$sources[[source_name]] <- result
      }
    }

    # 1 success (gnomad) + 2 not-found (uniprot, rgd) = 3 in sources
    # 2 errors (alphafold returned error list, mgi threw exception)
    expect_equal(length(results$sources), 3)
    expect_equal(length(results$errors), 2)
    expect_true("alphafold" %in% names(results$errors))
    expect_true("mgi" %in% names(results$errors))
  })

  it("preserves successful data when other sources fail", {
    sources <- list(
      success = function() mock_gnomad_constraints_success("TP53"),
      fail = function() stop("Error")
    )

    results <- list(sources = list(), errors = list())

    for (source_name in names(sources)) {
      result <- tryCatch({
        sources[[source_name]]()
      }, error = function(e) {
        list(error = TRUE, source = source_name, message = conditionMessage(e))
      })

      if (is.list(result) && isTRUE(result$error)) {
        results$errors[[source_name]] <- create_external_error(
          source_name, result$message
        )
      } else {
        results$sources[[source_name]] <- result
      }
    }

    # Verify successful data is intact
    expect_equal(results$sources$success$gene_symbol, "TP53")
    expect_equal(results$sources$success$source, "gnomad")
    expect_true("constraints" %in% names(results$sources$success))
  })

  it("distinguishes between not-found and error states", {
    sources <- list(
      not_found = function() mock_source_not_found("test"),
      errored = function() stop("Test error")
    )

    results <- list(sources = list(), errors = list())

    for (source_name in names(sources)) {
      result <- tryCatch({
        sources[[source_name]]()
      }, error = function(e) {
        list(error = TRUE, source = source_name, message = conditionMessage(e))
      })

      if (is.list(result) && isTRUE(result$error)) {
        results$errors[[source_name]] <- create_external_error(
          source_name, result$message
        )
      } else if (is.list(result) && isTRUE(result$found == FALSE)) {
        results$sources[[source_name]] <- list(found = FALSE)
      } else {
        results$sources[[source_name]] <- result
      }
    }

    # not_found goes to sources (with found = FALSE)
    # errored goes to errors
    expect_true("not_found" %in% names(results$sources))
    expect_true("errored" %in% names(results$errors))
    expect_equal(results$sources$not_found$found, FALSE)
    expect_equal(results$errors$errored$source, "errored")
  })

  it("handles exceptions thrown by source functions", {
    sources <- list(
      exception = function() stop("Fatal error")
    )

    results <- list(sources = list(), errors = list())

    for (source_name in names(sources)) {
      result <- tryCatch({
        sources[[source_name]]()
      }, error = function(e) {
        list(error = TRUE, source = source_name, message = conditionMessage(e))
      })

      if (is.list(result) && isTRUE(result$error)) {
        results$errors[[source_name]] <- create_external_error(
          source_name, result$message
        )
      }
    }

    # Exception should be caught and converted to error object
    expect_equal(length(results$errors), 1)
    expect_equal(results$errors$exception$source, "exception")
    expect_equal(results$errors$exception$detail, "Fatal error")
  })
})

# ============================================================================
# AUTH_ALLOWLIST includes external endpoints
# ============================================================================

describe("AUTH_ALLOWLIST includes external endpoints", {
  it("contains external proxy paths", {
    # AUTH_ALLOWLIST loaded from middleware.R
    expect_true("/api/external/gene" %in% AUTH_ALLOWLIST)
    expect_true("/api/external/gnomad/constraints" %in% AUTH_ALLOWLIST)
    expect_true("/api/external/gnomad/variants" %in% AUTH_ALLOWLIST)
    expect_true("/api/external/uniprot/domains" %in% AUTH_ALLOWLIST)
    expect_true("/api/external/ensembl/structure" %in% AUTH_ALLOWLIST)
    expect_true("/api/external/alphafold/structure" %in% AUTH_ALLOWLIST)
    expect_true("/api/external/mgi/phenotypes" %in% AUTH_ALLOWLIST)
    expect_true("/api/external/rgd/phenotypes" %in% AUTH_ALLOWLIST)
  })

  it("AUTH_ALLOWLIST is a character vector", {
    expect_true(is.character(AUTH_ALLOWLIST))
    expect_true(length(AUTH_ALLOWLIST) > 0)
  })

  it("all external endpoints have consistent path structure", {
    external_paths <- AUTH_ALLOWLIST[grepl("^/api/external/", AUTH_ALLOWLIST)]

    # Should have 8 external paths
    expect_equal(length(external_paths), 8)

    # Each should start with /api/external/
    for (path in external_paths) {
      expect_true(grepl("^/api/external/", path))
    }
  })

  it("aggregation endpoint is included", {
    # The /api/external/gene endpoint should be present
    expect_true(any(grepl("/api/external/gene", AUTH_ALLOWLIST)))
  })

  it("per-source endpoints are all included", {
    sources <- c("gnomad/constraints", "gnomad/variants", "uniprot/domains",
                 "ensembl/structure", "alphafold/structure",
                 "mgi/phenotypes", "rgd/phenotypes")

    for (source in sources) {
      path <- paste0("/api/external/", source)
      expect_true(path %in% AUTH_ALLOWLIST,
                  info = paste("Missing:", path))
    }
  })
})

# ============================================================================
# Error response format validation
# ============================================================================

describe("error response formatting in aggregation", {
  it("creates RFC 9457 error for failed sources", {
    sources <- list(
      fail = function() stop("Connection timeout")
    )

    results <- list(sources = list(), errors = list())

    for (source_name in names(sources)) {
      result <- tryCatch({
        sources[[source_name]]()
      }, error = function(e) {
        list(error = TRUE, source = source_name, message = conditionMessage(e))
      })

      if (is.list(result) && isTRUE(result$error)) {
        results$errors[[source_name]] <- create_external_error(
          source_name, result$message
        )
      }
    }

    # Verify RFC 9457 structure
    err <- results$errors$fail
    expect_true(all(c("type", "title", "status", "detail", "source") %in% names(err)))
    expect_equal(err$status, 503L)
    expect_equal(err$source, "fail")
  })

  it("handles missing error messages gracefully", {
    sources <- list(
      test = function() list(error = TRUE, source = "test")
    )

    results <- list(sources = list(), errors = list())

    for (source_name in names(sources)) {
      result <- tryCatch({
        sources[[source_name]]()
      }, error = function(e) {
        list(error = TRUE, source = source_name, message = conditionMessage(e))
      })

      if (is.list(result) && isTRUE(result$error)) {
        results$errors[[source_name]] <- create_external_error(
          source_name, result$message %||% paste(source_name, "unavailable")
        )
      }
    }

    # Should handle missing message field
    err <- results$errors$test
    expect_true("detail" %in% names(err))
  })
})
