# api/tests/testthat/test-integration-gnomad-batch.R
# Live integration tests against the gnomAD GraphQL API.
# Skipped unless RUN_GNOMAD_INTEGRATION=1.

source_api_file("functions/external-proxy-functions.R", local = FALSE)
source_api_file("functions/external-proxy-gnomad-batch.R", local = FALSE)

describe("fetch_gnomad_constraints_batch — live", {
  testthat::skip_if_not(
    Sys.getenv("RUN_GNOMAD_INTEGRATION") == "1",
    "Set RUN_GNOMAD_INTEGRATION=1 to run live gnomAD tests"
  )
  testthat::skip_if_offline("gnomad.broadinstitute.org")

  it("fetches MECP2, CDKL5, FMR1 (all chrX, all known to gnomAD)", {
    out <- fetch_gnomad_constraints_batch(
      c("MECP2", "CDKL5", "FMR1"),
      cache = cachem::cache_mem()
    )
    expect_named(out, c("MECP2", "CDKL5", "FMR1"))
    for (s in c("MECP2", "CDKL5", "FMR1")) {
      expect_false(
        is.na(out[[s]]),
        info = sprintf("expected non-NA for %s but got NA", s)
      )
      parsed <- jsonlite::fromJSON(out[[s]])
      expect_named(parsed, GNOMAD_BATCH_FIELDS, ignore.order = TRUE)
      expect_true(is.numeric(parsed$pLI))
    }
  })

  it("returns NA for an obviously fake symbol", {
    out <- fetch_gnomad_constraints_batch(
      c("DEFINITELY_NOT_A_REAL_GENE_XYZ"),
      cache = cachem::cache_mem()
    )
    expect_true(is.na(out[["DEFINITELY_NOT_A_REAL_GENE_XYZ"]]))
  })

  it("completes 150-symbol fallback simulation in under 30 seconds", {
    # Sample of known X-linked genes; not all will be valid in gnomAD.
    chrx <- c(
      "MECP2", "CDKL5", "FMR1", "ATRX", "KDM5C", "HUWE1", "OFD1", "PHF6",
      "SMC1A", "IL1RAPL1", "RPS6KA3", "DMD", "HPRT1", "ARX", "MED12", "UBE2A",
      "ZNF711", "GRIA3", "WDR45", "WAS", "UPF3B", "UBA1", "TRMT1", "TIMM8A",
      "TFE3", "TBL1X", "SYP", "SYN1", "SOX3", "SLC9A6", "SLC6A8"
    )
    syms <- rep(chrx, 5L)[1:150L]
    elapsed <- system.time(
      out <- fetch_gnomad_constraints_batch(syms, cache = cachem::cache_mem())
    )["elapsed"]
    cat(sprintf("\n[bench] %d symbols in %.2fs\n", length(syms), elapsed))
    expect_lt(elapsed, 30.0)
  })
})
