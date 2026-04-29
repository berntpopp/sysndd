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

describe(".fetch_gnomad_constraints_chunk", {
  it("returns named char vec on a 200 response with all aliases populated", {
    body <- jsonlite::toJSON(list(
      data = setNames(
        lapply(seq_len(2), function(i) list(gnomad_constraint = list(
          pLI = 0.99, oe_lof = 0.1, oe_lof_lower = 0.05, oe_lof_upper = 0.2,
          oe_mis = 1, oe_mis_lower = 0.9, oe_mis_upper = 1.1,
          oe_syn = 1, oe_syn_lower = 0.9, oe_syn_upper = 1.1,
          exp_lof = 50, obs_lof = 5, exp_mis = 500, obs_mis = 500,
          exp_syn = 200, obs_syn = 200, lof_z = 3.5, mis_z = 0, syn_z = 0
        ))),
        c("g0", "g1")
      )
    ), auto_unbox = TRUE)

    httr2::with_mocked_responses(
      # Local httr2 requires raw body in response() and a function/list mock; plan used
      # string body and bare response. Wrap body via charToRaw and mock as function.
      mock = function(req) httr2::response(status_code = 200L, body = charToRaw(body), headers = list("content-type" = "application/json")),
      {
        out <- .fetch_gnomad_constraints_chunk(c("MECP2", "CDKL5"))
        expect_named(out, c("MECP2", "CDKL5"))
        expect_false(any(is.na(out)))
      }
    )
  })

  it("returns all-NA on a 500 response, with a warning", {
    httr2::with_mocked_responses(
      mock = function(req) httr2::response(status_code = 500L, body = charToRaw('{"error":"oops"}')),
      {
        expect_warning(
          out <- .fetch_gnomad_constraints_chunk(c("MECP2", "CDKL5")),
          # Escape brackets — bare `[gnomad-batch]` is read as a char-class with invalid range.
          "\\[gnomad-batch\\].*HTTP",
          ignore.case = TRUE
        )
        expect_named(out, c("MECP2", "CDKL5"))
        expect_true(all(is.na(out)))
      }
    )
  })

  it("returns all-NA on an unparseable body, with a warning", {
    httr2::with_mocked_responses(
      mock = function(req) httr2::response(status_code = 200L, body = charToRaw("<html>not json</html>")),
      {
        expect_warning(
          out <- .fetch_gnomad_constraints_chunk(c("MECP2", "CDKL5")),
          "\\[gnomad-batch\\].*(parse|json)",
          ignore.case = TRUE
        )
        expect_true(all(is.na(out)))
      }
    )
  })

  it("returns empty named char vec for empty input without firing a request", {
    # If a request fires under empty input, the mock's absence will cause an error.
    out <- .fetch_gnomad_constraints_chunk(character(0))
    expect_length(out, 0L)
  })
})

describe("fetch_gnomad_constraints_batch", {
  # Helper: in-memory cachem that mimics cache_static for these tests.
  make_mem_cache <- function() cachem::cache_mem()

  it("returns aligned named char vec on full success", {
    cache <- make_mem_cache()
    body <- jsonlite::toJSON(list(
      data = list(
        g0 = list(gnomad_constraint = list(
          pLI = 0.99, oe_lof = 0.1, oe_lof_lower = 0.05, oe_lof_upper = 0.2,
          oe_mis = 1, oe_mis_lower = 0.9, oe_mis_upper = 1.1,
          oe_syn = 1, oe_syn_lower = 0.9, oe_syn_upper = 1.1,
          exp_lof = 50, obs_lof = 5, exp_mis = 500, obs_mis = 500,
          exp_syn = 200, obs_syn = 200, lof_z = 3.5, mis_z = 0, syn_z = 0
        )),
        g1 = NULL # unknown gene
      )
    ), auto_unbox = TRUE)

    httr2::with_mocked_responses(
      mock = function(req) httr2::response(status_code = 200L, body = charToRaw(body), headers = list("content-type" = "application/json")),
      {
        out <- fetch_gnomad_constraints_batch(c("MECP2", "FAKE_GENE"), cache = cache)
        expect_named(out, c("MECP2", "FAKE_GENE"))
        expect_false(is.na(out[["MECP2"]]))
        expect_true(is.na(out[["FAKE_GENE"]]))
      }
    )
  })

  it("does not fire any request when every symbol is in cache", {
    cache <- make_mem_cache()
    # cachem requires lowercase-alphanumeric keys; module exposes .gnomad_batch_cache_key
    # to construct them. Plan used the prior `gnomad_constraint_v1::SYMBOL` form.
    cache$set(.gnomad_batch_cache_key("MECP2"), '{"pLI":0.99}')
    cache$set(.gnomad_batch_cache_key("CDKL5"), "__GNOMAD_NA__")

    # If a request fires, with_mocked_responses errors with no mock provided
    out <- fetch_gnomad_constraints_batch(c("MECP2", "CDKL5"), cache = cache)
    expect_equal(out[["MECP2"]], '{"pLI":0.99}')
    expect_true(is.na(out[["CDKL5"]]))
  })

  it("fires exactly one request when 5 symbols are uncached and 5 are cached", {
    cache <- make_mem_cache()
    cached <- paste0("CACHED", 1:5)
    uncached <- paste0("MISS", 1:5)
    for (s in cached) cache$set(.gnomad_batch_cache_key(s), sprintf('{"sym":"%s"}', s))

    body <- jsonlite::toJSON(list(
      data = setNames(
        lapply(seq_along(uncached), function(i) list(gnomad_constraint = list(
          pLI = 0.5, oe_lof = 1, oe_lof_lower = 0.5, oe_lof_upper = 1.5,
          oe_mis = 1, oe_mis_lower = 0.9, oe_mis_upper = 1.1,
          oe_syn = 1, oe_syn_lower = 0.9, oe_syn_upper = 1.1,
          exp_lof = 50, obs_lof = 5, exp_mis = 500, obs_mis = 500,
          exp_syn = 200, obs_syn = 200, lof_z = 0, mis_z = 0, syn_z = 0
        ))),
        paste0("g", seq_along(uncached) - 1L)
      )
    ), auto_unbox = TRUE)

    call_count <- 0L
    httr2::with_mocked_responses(
      mock = function(req) {
        call_count <<- call_count + 1L
        httr2::response(status_code = 200L, body = charToRaw(body), headers = list("content-type" = "application/json"))
      },
      {
        out <- fetch_gnomad_constraints_batch(c(cached, uncached), cache = cache)
      }
    )
    expect_equal(call_count, 1L)
    expect_length(out, 10L)
  })

  it("fires three requests when 60 symbols are uncached (chunks 25/25/10)", {
    cache <- make_mem_cache()
    syms <- paste0("GENE", sprintf("%03d", 1:60))
    chunk_count <- 0L
    # Plan used httr2::req_body_get(req) which is not a real accessor. Per task5 instructions,
    # we replace body parsing with a call counter and return all-NA per chunk (max 25 aliases).
    canned_body <- jsonlite::toJSON(list(
      data = setNames(
        replicate(GNOMAD_BATCH_MAX_PER_REQUEST, NULL, simplify = FALSE),
        paste0("g", seq_len(GNOMAD_BATCH_MAX_PER_REQUEST) - 1L)
      )
    ), auto_unbox = TRUE, null = "null")
    httr2::with_mocked_responses(
      mock = function(req) {
        chunk_count <<- chunk_count + 1L
        httr2::response(status_code = 200L, body = charToRaw(canned_body), headers = list("content-type" = "application/json"))
      },
      {
        out <- fetch_gnomad_constraints_batch(syms, cache = cache, max_concurrency = 1L)
      }
    )
    expect_equal(chunk_count, 3L)
    expect_length(out, 60L)
    expect_true(all(is.na(out)))
  })

  it("caches every recovered value AND every gene-not-found result", {
    cache <- make_mem_cache()
    body <- jsonlite::toJSON(list(
      data = list(
        g0 = list(gnomad_constraint = list(
          pLI = 0.5, oe_lof = 1, oe_lof_lower = 0.5, oe_lof_upper = 1.5,
          oe_mis = 1, oe_mis_lower = 0.9, oe_mis_upper = 1.1,
          oe_syn = 1, oe_syn_lower = 0.9, oe_syn_upper = 1.1,
          exp_lof = 50, obs_lof = 5, exp_mis = 500, obs_mis = 500,
          exp_syn = 200, obs_syn = 200, lof_z = 0, mis_z = 0, syn_z = 0
        )),
        g1 = NULL
      )
    ), auto_unbox = TRUE)
    httr2::with_mocked_responses(
      mock = function(req) httr2::response(status_code = 200L, body = charToRaw(body), headers = list("content-type" = "application/json")),
      {
        fetch_gnomad_constraints_batch(c("HIT", "MISS"), cache = cache)
      }
    )
    expect_true(cache$exists(.gnomad_batch_cache_key("HIT")))
    expect_true(cache$exists(.gnomad_batch_cache_key("MISS")))
    expect_equal(cache$get(.gnomad_batch_cache_key("MISS")), "__GNOMAD_NA__")
  })

  it("does not collide HLA-B and HLAB cache keys", {
    expect_false(.gnomad_batch_cache_key("HLA-B") == .gnomad_batch_cache_key("HLAB"))
  })

  it("does NOT cache results from a transport-failed batch", {
    cache <- make_mem_cache()
    httr2::with_mocked_responses(
      mock = function(req) httr2::response(status_code = 500L, body = charToRaw('{"err":"x"}')),
      {
        suppressWarnings(
          fetch_gnomad_constraints_batch(c("MECP2"), cache = cache)
        )
      }
    )
    expect_false(cache$exists(.gnomad_batch_cache_key("MECP2")))
  })
})
