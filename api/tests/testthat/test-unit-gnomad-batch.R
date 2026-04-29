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

describe(".parse_batched_constraint_response", {
  make_constraint_obj <- function(pLI = 0.99) {
    list(
      pLI = pLI,
      oe_lof = 0.1, oe_lof_lower = 0.05, oe_lof_upper = 0.2,
      oe_mis = 1.0, oe_mis_lower = 0.9, oe_mis_upper = 1.1,
      oe_syn = 1.0, oe_syn_lower = 0.9, oe_syn_upper = 1.1,
      exp_lof = 50, obs_lof = 5,
      exp_mis = 500, obs_mis = 500,
      exp_syn = 200, obs_syn = 200,
      lof_z = 3.5, mis_z = 0.0, syn_z = 0.0
    )
  }

  it("returns named character vector with JSON for every successful alias", {
    response <- list(
      data = list(
        g0 = list(gnomad_constraint = make_constraint_obj(0.99)),
        g1 = list(gnomad_constraint = make_constraint_obj(0.50))
      )
    )
    out <- .parse_batched_constraint_response(response, c("MECP2", "CDKL5"))
    expect_named(out, c("MECP2", "CDKL5"))
    expect_false(any(is.na(out)))
    parsed_mecp2 <- jsonlite::fromJSON(out[["MECP2"]])
    expect_equal(parsed_mecp2$pLI, 0.99)
  })

  it("returns NA for an alias whose gene is null", {
    response <- list(
      data = list(
        g0 = NULL, # gene not found
        g1 = list(gnomad_constraint = make_constraint_obj())
      )
    )
    out <- .parse_batched_constraint_response(response, c("FAKE_GENE", "CDKL5"))
    expect_true(is.na(out[["FAKE_GENE"]]))
    expect_false(is.na(out[["CDKL5"]]))
  })

  it("returns NA when gene exists but gnomad_constraint is null", {
    response <- list(
      data = list(
        g0 = list(gnomad_constraint = NULL),
        g1 = list(gnomad_constraint = make_constraint_obj())
      )
    )
    out <- .parse_batched_constraint_response(response, c("LINC00001", "CDKL5"))
    expect_true(is.na(out[["LINC00001"]]))
  })

  it("returns NA for aliases referenced in errors block", {
    response <- list(
      data = list(
        g0 = NULL,
        g1 = list(gnomad_constraint = make_constraint_obj())
      ),
      errors = list(
        list(
          message = "Gene not found",
          path = list("g0")
        )
      )
    )
    out <- .parse_batched_constraint_response(response, c("FAKE_GENE", "CDKL5"))
    expect_true(is.na(out[["FAKE_GENE"]]))
    expect_false(is.na(out[["CDKL5"]]))
  })

  it("returns empty named character vector for empty input", {
    out <- .parse_batched_constraint_response(list(data = list()), character(0))
    expect_length(out, 0L)
    expect_named(out, character(0))
  })

  it("emits the same numeric formatting as the bulk pipeline for round-trip parity", {
    # Bulk pipeline emits scientific notation for very small numbers and `null` for NA.
    # This regression check ensures the JSON we emit can be parsed back identically.
    response <- list(data = list(g0 = list(gnomad_constraint = list(
      pLI = 1.5474e-34, oe_lof = NA, oe_lof_lower = NA, oe_lof_upper = NA,
      oe_mis = NA, oe_mis_lower = NA, oe_mis_upper = NA,
      oe_syn = NA, oe_syn_lower = NA, oe_syn_upper = NA,
      exp_lof = NA, obs_lof = NA, exp_mis = NA, obs_mis = NA,
      exp_syn = NA, obs_syn = NA, lof_z = NA, mis_z = NA, syn_z = NA
    ))))
    out <- .parse_batched_constraint_response(response, "WEIRD")
    parsed <- jsonlite::fromJSON(out[["WEIRD"]])
    expect_equal(parsed$pLI, 1.5474e-34)
    expect_true(is.null(parsed$oe_lof) || is.na(parsed$oe_lof))
  })
})
