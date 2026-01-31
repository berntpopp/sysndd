# test-external-proxy-functions.R
# Tests for shared external proxy infrastructure (external-proxy-functions.R)
#
# These tests validate the core building blocks used by all external API proxy
# endpoints: input validation, error formatting, cache backends, and rate limits.
# No real external API calls - all unit tests.

# Load required packages
library(dplyr)
library(httr2)

# Source required files using helper-paths.R (loaded automatically by setup.R)
# Use local = FALSE to make functions available in test scope
source_api_file("functions/external-proxy-functions.R", local = FALSE)

# ============================================================================
# validate_gene_symbol() Tests
# ============================================================================

describe("validate_gene_symbol", {
  it("accepts valid HGNC gene symbols", {
    expect_true(validate_gene_symbol("BRCA1"))
    expect_true(validate_gene_symbol("TP53"))
    expect_true(validate_gene_symbol("HLA-A"))
    expect_true(validate_gene_symbol("C9orf72"))
  })

  it("rejects NULL and empty strings", {
    expect_false(validate_gene_symbol(NULL))
    expect_false(validate_gene_symbol(""))
    expect_false(validate_gene_symbol(NA))
  })

  it("rejects lowercase and special characters", {
    expect_false(validate_gene_symbol("brca1"))
    expect_false(validate_gene_symbol("BRCA1; DROP TABLE"))
    expect_false(validate_gene_symbol('BRCA1"'))
    expect_false(validate_gene_symbol("BRCA1\ngene"))
  })

  it("rejects GraphQL injection attempts", {
    expect_false(validate_gene_symbol('BRCA1" } evil { "'))
    expect_false(validate_gene_symbol("BRCA1{}"))
  })

  it("rejects symbols starting with numbers", {
    expect_false(validate_gene_symbol("1INVALID"))
    expect_false(validate_gene_symbol("123GENE"))
  })

  it("accepts symbols with hyphens in valid positions", {
    expect_true(validate_gene_symbol("HLA-DRB1"))
    expect_true(validate_gene_symbol("IL-6"))
  })
})

# ============================================================================
# create_external_error() Tests
# ============================================================================

describe("create_external_error", {
  it("returns RFC 9457 formatted error with source", {
    err <- create_external_error("gnomad", "API unavailable")
    expect_equal(err$type, "https://sysndd.org/problems/external-api-failure")
    expect_equal(err$source, "gnomad")
    expect_equal(err$status, 503L)
    expect_true(grepl("gnomad", err$title))
    expect_equal(err$detail, "API unavailable")
  })

  it("accepts custom status code", {
    err <- create_external_error("uniprot", "Bad request", 400L)
    expect_equal(err$status, 400L)
  })

  it("includes instance when provided", {
    err <- create_external_error("ensembl", "Timeout", instance = "/api/external/ensembl/structure/BRCA1")
    expect_equal(err$instance, "/api/external/ensembl/structure/BRCA1")
  })

  it("has all required RFC 9457 fields", {
    err <- create_external_error("uniprot", "Connection failed")
    expect_true(all(c("type", "title", "status", "detail", "source") %in% names(err)))
  })

  it("formats title consistently", {
    err <- create_external_error("mgi", "Network error")
    expect_true(grepl("Failed to fetch mgi data", err$title))
  })
})

# ============================================================================
# Cache backend tests
# ============================================================================

describe("cache backends", {
  it("cache_static exists and is a cachem cache object", {
    expect_true(!is.null(cache_static))
    expect_true(inherits(cache_static, "cache_disk") || is.environment(cache_static))
  })

  it("cache_stable exists and is a cachem cache object", {
    expect_true(!is.null(cache_stable))
    expect_true(inherits(cache_stable, "cache_disk") || is.environment(cache_stable))
  })

  it("cache_dynamic exists and is a cachem cache object", {
    expect_true(!is.null(cache_dynamic))
    expect_true(inherits(cache_dynamic, "cache_disk") || is.environment(cache_dynamic))
  })

  it("all three cache backends are distinct objects", {
    # Use object.size or similar to verify they're different instances
    expect_false(identical(cache_static, cache_stable))
    expect_false(identical(cache_static, cache_dynamic))
    expect_false(identical(cache_stable, cache_dynamic))
  })
})

# ============================================================================
# EXTERNAL_API_THROTTLE config tests
# ============================================================================

describe("EXTERNAL_API_THROTTLE", {
  it("contains all 6 API configurations", {
    expect_true(all(c("gnomad", "ensembl", "uniprot", "alphafold", "mgi", "rgd") %in%
      names(EXTERNAL_API_THROTTLE)))
  })

  it("each config has capacity and fill_time_s", {
    for (api_name in names(EXTERNAL_API_THROTTLE)) {
      config <- EXTERNAL_API_THROTTLE[[api_name]]
      expect_true("capacity" %in% names(config), info = paste(api_name, "missing capacity"))
      expect_true("fill_time_s" %in% names(config), info = paste(api_name, "missing fill_time_s"))
    }
  })

  it("gnomAD has conservative rate limit (10/min)", {
    expect_equal(EXTERNAL_API_THROTTLE$gnomad$capacity, 10)
    expect_equal(EXTERNAL_API_THROTTLE$gnomad$fill_time_s, 60)
  })

  it("Ensembl has documented rate limit (900/min)", {
    expect_equal(EXTERNAL_API_THROTTLE$ensembl$capacity, 900)
    expect_equal(EXTERNAL_API_THROTTLE$ensembl$fill_time_s, 60)
  })

  it("all capacity values are positive integers", {
    for (api_name in names(EXTERNAL_API_THROTTLE)) {
      capacity <- EXTERNAL_API_THROTTLE[[api_name]]$capacity
      expect_true(is.numeric(capacity), info = paste(api_name, "capacity not numeric"))
      expect_true(capacity > 0, info = paste(api_name, "capacity not positive"))
    }
  })

  it("all fill_time_s values are positive integers", {
    for (api_name in names(EXTERNAL_API_THROTTLE)) {
      fill_time <- EXTERNAL_API_THROTTLE[[api_name]]$fill_time_s
      expect_true(is.numeric(fill_time), info = paste(api_name, "fill_time_s not numeric"))
      expect_true(fill_time > 0, info = paste(api_name, "fill_time_s not positive"))
    }
  })
})
