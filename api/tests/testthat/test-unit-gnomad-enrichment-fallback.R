# api/tests/testthat/test-unit-gnomad-enrichment-fallback.R

source_api_file("functions/external-proxy-functions.R", local = FALSE)
source_api_file("functions/external-proxy-gnomad-batch.R", local = FALSE)
source_api_file("functions/hgnc-enrichment-gnomad.R", local = FALSE)

describe("enrich_gnomad_constraints with chrX fallback", {
  it("fills NA rows with values returned by fetch_gnomad_constraints_batch", {
    hgnc <- tibble::tibble(
      hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
      symbol = c("BRCA1", "MECP2", "CDKL5")
    )

    fake_fallback <- '{"pLI":0.999,"oe_lof":0.05,"oe_lof_lower":0.01,"oe_lof_upper":0.15,"oe_mis":1,"oe_mis_lower":0.9,"oe_mis_upper":1.1,"oe_syn":1,"oe_syn_lower":0.9,"oe_syn_upper":1.1,"exp_lof":40,"obs_lof":2,"exp_mis":400,"obs_mis":400,"exp_syn":150,"obs_syn":150,"lof_z":4.5,"mis_z":0,"syn_z":0}'

    bulk_mock <- tibble::tibble(
      gene = "BRCA1", mane_select = "true",
      `lof.pLI` = 0.99, `lof.oe` = 0.1, `lof.oe_ci.lower` = 0.05, `lof.oe_ci.upper` = 0.2,
      `mis.oe` = 1, `mis.oe_ci.lower` = 0.9, `mis.oe_ci.upper` = 1.1,
      `syn.oe` = 1, `syn.oe_ci.lower` = 0.9, `syn.oe_ci.upper` = 1.1,
      `lof.exp` = 50, `lof.obs` = 5, `mis.exp` = 500, `mis.obs` = 500,
      `syn.exp` = 200, `syn.obs` = 200, `lof.z_score` = 3.5, `mis.z_score` = 0, `syn.z_score` = 0
    )

    mockery::stub(enrich_gnomad_constraints, "download.file", function(...) invisible(NULL))
    mockery::stub(enrich_gnomad_constraints, "file.info", function(...) data.frame(size = 2e6))
    mockery::stub(enrich_gnomad_constraints, "readr::read_tsv", function(...) bulk_mock)
    mockery::stub(enrich_gnomad_constraints, "fetch_gnomad_constraints_batch",
      function(symbols, ...) {
        setNames(rep(fake_fallback, length(symbols)), symbols)
      }
    )

    # Temporarily lower the MANE-genes minimum so the 1-row mock TSV passes the
    # sanity check. mockery::stub cannot replace top-level constants (it
    # substitutes a thunk function), so swap the binding in the same
    # environment the function looks the constant up from, and restore it on
    # exit. enrich_gnomad_constraints was sourced via source_api_file into the
    # test-file environment, so its closure env is environment(fn), not the
    # global env.
    fn_env <- environment(enrich_gnomad_constraints)
    orig_min <- get("GNOMAD_MIN_MANE_GENES", envir = fn_env)
    assign("GNOMAD_MIN_MANE_GENES", 1L, envir = fn_env)
    on.exit(assign("GNOMAD_MIN_MANE_GENES", orig_min, envir = fn_env), add = TRUE)

    out <- enrich_gnomad_constraints(hgnc)
    expect_equal(nrow(out), 3L)
    expect_false(is.na(out$gnomad_constraints[out$symbol == "BRCA1"]))
    expect_false(is.na(out$gnomad_constraints[out$symbol == "MECP2"]))
    expect_false(is.na(out$gnomad_constraints[out$symbol == "CDKL5"]))
    parsed_bulk <- jsonlite::fromJSON(out$gnomad_constraints[out$symbol == "BRCA1"])
    expect_equal(parsed_bulk$lof_z, 3.5)
    parsed_fallback <- jsonlite::fromJSON(out$gnomad_constraints[out$symbol == "MECP2"])
    expect_equal(parsed_fallback$lof_z, 4.5)
  })
})
