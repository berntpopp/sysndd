# api/tests/testthat/test-unit-gnomad-batch.R
# Unit tests for external-proxy-gnomad-batch.R

source_api_file("functions/external-proxy-functions.R", local = FALSE)
source_api_file("functions/external-proxy-gnomad-batch.R", local = FALSE)

describe(".build_aliased_constraint_query", {
  it("returns NULL for empty input", {
    expect_null(.build_aliased_constraint_query(character(0)))
  })

  it("emits one alias for one valid symbol", {
    out <- .build_aliased_constraint_query("MECP2")
    expect_type(out, "character")
    expect_length(out, 1L)
    expect_match(out, 'g0: gene\\(gene_symbol: "MECP2"', fixed = FALSE)
    expect_match(out, "pLI", fixed = TRUE)
    expect_match(out, "lof_z", fixed = TRUE)
  })

  it("emits one alias per valid symbol in input order", {
    out <- .build_aliased_constraint_query(c("FMR1", "CDKL5", "MECP2"))
    expect_match(out, 'g0: gene\\(gene_symbol: "FMR1"', fixed = FALSE)
    expect_match(out, 'g1: gene\\(gene_symbol: "CDKL5"', fixed = FALSE)
    expect_match(out, 'g2: gene\\(gene_symbol: "MECP2"', fixed = FALSE)
  })

  it("filters invalid symbols silently and warns once with the list", {
    expect_warning(
      out <- .build_aliased_constraint_query(c("FMR1", "O'Reilly", "", "CDKL5")),
      # Plan-prompt regex expected FMR1 but FMR1 is the *valid* symbol. Warning
      # lists invalid symbols only; match an invalid one (Reilly) instead.
      "filtered.*invalid.*Reilly",
      ignore.case = TRUE
    )
    expect_match(out, 'g0: gene\\(gene_symbol: "FMR1"', fixed = FALSE)
    expect_match(out, 'g1: gene\\(gene_symbol: "CDKL5"', fixed = FALSE)
    expect_false(grepl("Reilly", out, fixed = TRUE))
  })

  it("returns NULL when every symbol is invalid", {
    expect_warning(
      out <- .build_aliased_constraint_query(c("'", "")),
      "filtered.*invalid",
      ignore.case = TRUE
    )
    expect_null(out)
  })

  it("never embeds more than the cost-limit aliases", {
    syms <- paste0("GENE", seq_len(50))
    expect_error(
      .build_aliased_constraint_query(syms),
      "max .*25",
      ignore.case = TRUE
    )
  })
})
