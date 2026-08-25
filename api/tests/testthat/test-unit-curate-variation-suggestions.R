# api/tests/testthat/test-unit-curate-variation-suggestions.R
#
# #612 Phase 6: the cross-entity curation queue over UNCONFIRMED machine-derived
# variation-ontology assertions.
#
# WHY BOTH STATES
# ---------------
# The #608 design named a queue over `state = 'suggested'`. The February 2026
# backfill then wrote every one of its 8,083 rows `active_unconfirmed`, so a
# suggested-only queue would render an EMPTY PAGE while the ~1,981-item
# weak-evidence backlog it exists to make tractable sits in the other state. The
# queue therefore spans `('active_unconfirmed','suggested')`, with `state` as a
# facet.
#
# WHY THE ACTIONS ARE ASYMMETRIC
# ------------------------------
# `provenance_for_entity()` filters the public read to
# `('active_unconfirmed','confirmed')`. Writing `rejected` onto an
# `active_unconfirmed` assertion drops it out of that filter while the term is
# STILL SERVED, so the entity card would render it as CURATOR-AUTHORED -- the
# exact fabrication this feature exists to prevent. So:
#
#   active_unconfirmed (served)  -> Confirm is safe, Dismiss is not
#   suggested (not served)       -> Dismiss is safe, Confirm is not
#
# The other direction of each pair would have to add or remove a curated term,
# which is a review write and must go through review_write_mutate().

source_api_file("core/errors.R", local = FALSE)
source_api_file("services/entity-variation-provenance-service.R", local = FALSE)
source_api_file("services/curate-variation-suggestion-service.R", local = FALSE)

MODULE_ENV <- environment(svc_curate_variation_suggestions)

# See test-unit-approval-service-provenance.R for why this targets the module's
# own environment and why `env` is required rather than defaulted.
mock_module <- function(bindings, env) {
  restore <- lapply(names(bindings), function(name) {
    had <- base::exists(name, envir = MODULE_ENV, inherits = FALSE)
    previous <- if (had) base::get(name, envir = MODULE_ENV, inherits = FALSE) else NULL
    assign(name, bindings[[name]], envir = MODULE_ENV)
    function() {
      if (had) {
        assign(name, previous, envir = MODULE_ENV)
      } else if (base::exists(name, envir = MODULE_ENV, inherits = FALSE)) {
        rm(list = name, envir = MODULE_ENV)
      }
    }
  })
  withr::defer(lapply(restore, function(undo) undo()), envir = env)
  invisible(NULL)
}

default_params <- function() {
  svc_curate_variation_suggestion_params(
    state = NULL, source_key = NULL, max_strength = NULL, moved = NULL,
    q = NULL, sort = NULL, page = NULL, page_size = NULL
  )
}

queue_row <- function(...) {
  base <- list(
    assertion_id = 1L, entity_id = 42L, symbol = "CHD8",
    disease_ontology_name = "CHD8 disorder", vario_id = "VariO:0015",
    vario_name = "protein truncation", modifier_id = 1L,
    state = "active_unconfirmed", served = 1L, moved = 1L,
    source_type = "external_database", source_key = "clinvar",
    batch_id = "clinvar-2026-02", evidence_strength = 2L,
    evidence_summary = "10 ClinVar records, max 2 stars", evidence_id = 1L
  )
  utils::modifyList(base, list(...))
}

queue_rows <- function(...) do.call(rbind, lapply(list(...), as.data.frame,
                                                  stringsAsFactors = FALSE))


# ---------------------------------------------------------------------------
# Parameter validation
# ---------------------------------------------------------------------------

test_that("defaults are the strongest-evidence-first first page", {
  params <- default_params()
  expect_null(params$state)
  expect_null(params$source_key)
  expect_null(params$max_strength)
  expect_false(params$moved)
  expect_null(params$q)
  expect_equal(params$sort, "strength_desc")
  expect_equal(params$page, 1L)
  expect_equal(params$page_size, 25L)
})

test_that("page_size is capped at 100 and page floors at 1", {
  params <- svc_curate_variation_suggestion_params(
    NULL, NULL, NULL, NULL, NULL, NULL, page = 0L, page_size = 5000L
  )
  expect_equal(params$page, 1L)
  expect_equal(params$page_size, 100L)
})

test_that("an unknown state, sort or source_key is a 400, never a silent default", {
  # A silently-ignored filter would show a curator a page they did not ask for
  # and let them act on it.
  expect_error(
    svc_curate_variation_suggestion_params("confirmed", NULL, NULL, NULL, NULL, NULL, NULL, NULL),
    class = "error_400"
  )
  expect_error(
    svc_curate_variation_suggestion_params("rejected", NULL, NULL, NULL, NULL, NULL, NULL, NULL),
    class = "error_400"
  )
  expect_error(
    svc_curate_variation_suggestion_params(NULL, NULL, NULL, NULL, NULL, "; DROP", NULL, NULL),
    class = "error_400"
  )
  expect_error(
    svc_curate_variation_suggestion_params(NULL, "clin var", NULL, NULL, NULL, NULL, NULL, NULL),
    class = "error_400"
  )
  expect_error(
    svc_curate_variation_suggestion_params(NULL, NULL, NULL, NULL, NULL, NULL, "abc", NULL),
    class = "error_400"
  )
})

test_that("both queue states are accepted", {
  for (state in c("active_unconfirmed", "suggested")) {
    params <- svc_curate_variation_suggestion_params(
      state, NULL, NULL, NULL, NULL, NULL, NULL, NULL
    )
    expect_equal(params$state, state)
  }
})

test_that("max_strength accepts only 0-4", {
  expect_equal(
    svc_curate_variation_suggestion_params(NULL, NULL, 0L, NULL, NULL, NULL, NULL, NULL)$max_strength,
    0L
  )
  expect_equal(
    svc_curate_variation_suggestion_params(NULL, NULL, "4", NULL, NULL, NULL, NULL, NULL)$max_strength,
    4L
  )
  expect_error(
    svc_curate_variation_suggestion_params(NULL, NULL, 5L, NULL, NULL, NULL, NULL, NULL),
    class = "error_400"
  )
  expect_error(
    svc_curate_variation_suggestion_params(NULL, NULL, -1L, NULL, NULL, NULL, NULL, NULL),
    class = "error_400"
  )
})

test_that("moved is TRUE only for an explicit true", {
  truthy <- svc_curate_variation_suggestion_params(
    NULL, NULL, NULL, "true", NULL, NULL, NULL, NULL
  )
  expect_true(truthy$moved)
  for (value in list(NULL, "false", "1", "yes", "")) {
    params <- svc_curate_variation_suggestion_params(
      NULL, NULL, NULL, value, NULL, NULL, NULL, NULL
    )
    expect_false(params$moved)
  }
})

test_that("q is trimmed, length-capped, and blanks become NULL", {
  expect_equal(
    svc_curate_variation_suggestion_params(NULL, NULL, NULL, NULL, "  CHD8 ", NULL, NULL, NULL)$q,
    "CHD8"
  )
  expect_null(
    svc_curate_variation_suggestion_params(NULL, NULL, NULL, NULL, "   ", NULL, NULL, NULL)$q
  )
  expect_error(
    svc_curate_variation_suggestion_params(
      NULL, NULL, NULL, NULL, strrep("x", 65L), NULL, NULL, NULL
    ),
    class = "error_400"
  )
})


# ---------------------------------------------------------------------------
# The listing query
# ---------------------------------------------------------------------------

test_that("the listing query binds every filter and never interpolates a value", {
  captured <- list()
  mock_module(env = environment(), bindings = list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      captured[[length(captured) + 1L]] <<- list(sql = sql, params = params)
      if (grepl("COUNT(", sql, fixed = TRUE)) {
        return(data.frame(total = 0L))
      }
      data.frame()
    }
  ))

  params <- svc_curate_variation_suggestion_params(
    "active_unconfirmed", "clinvar", 1L, "true", "CHD8", "strength_asc", 2L, 10L
  )
  svc_curate_variation_suggestions(params, pool = NULL)

  expect_length(captured, 2L)
  listing <- captured[[2L]]
  flat <- vapply(listing$params, function(p) as.character(p)[[1L]], character(1))
  expect_true("clinvar" %in% flat)
  expect_true("%CHD8%" %in% flat)
  expect_false(grepl("clinvar", listing$sql, fixed = TRUE))
  expect_false(grepl("CHD8", listing$sql, fixed = TRUE))

  # Entity visibility and both derived flags live IN the statement, never in a
  # post-filter in R -- a non-public entity must be unable to reach the page.
  expect_match(listing$sql, "ndd_entity_view", fixed = TRUE)
  expect_match(listing$sql, "origin_review_id", fixed = TRUE)
  expect_match(listing$sql, "is_primary = 1", fixed = TRUE)
  expect_match(listing$sql, "review_approved = 1", fixed = TRUE)
  expect_match(listing$sql, "c.is_active = 1", fixed = TRUE)

  # Paging is over ASSERTIONS, not over joined evidence rows.
  expect_match(listing$sql, "LIMIT ? OFFSET ?", fixed = TRUE)
  expect_match(listing$sql, "GROUP BY pa.assertion_id", fixed = TRUE)
  # Every ordering ends on assertion_id so paging is stable.
  expect_match(listing$sql, "pa.assertion_id ASC", fixed = TRUE)
})

test_that("the listing binds each filter exactly once, matching its placeholders", {
  # The outer query carries NO WHERE of its own: it is constrained entirely by
  # the JOIN to the paging subquery, which holds the only copy of the predicate.
  # Binding the filters twice raises "Number of params don't match" the moment a
  # real driver sees it -- which a mocked db_execute_query never does, so the
  # count is asserted here and executed for real in
  # test-integration-variation-suggestions.R.
  captured <- NULL
  mock_module(env = environment(), bindings = list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("COUNT(", sql, fixed = TRUE)) {
        return(data.frame(total = 0L))
      }
      captured <<- list(sql = sql, params = params)
      data.frame()
    }
  ))

  params <- svc_curate_variation_suggestion_params(
    "suggested", "clinvar", NULL, NULL, "CHD8", NULL, 1L, 25L
  )
  svc_curate_variation_suggestions(params, pool = NULL)

  placeholders <- lengths(regmatches(captured$sql, gregexpr("?", captured$sql, fixed = TRUE)))
  expect_equal(length(captured$params), placeholders)

  flat <- vapply(captured$params, function(p) as.character(p)[[1L]], character(1))
  expect_equal(sum(flat == "clinvar"), 1L)
  expect_equal(sum(flat == "suggested"), 1L)
  # ...and LIMIT/OFFSET are the last two.
  expect_equal(tail(flat, 2L), c("25", "0"))
})

test_that("sort options put unrecorded strength LAST in both directions", {
  # `null` strength means NOT RECORDED, and the entity-scoped surface already
  # sorts it last (.svc_vp_evidence_order). A queue that floated unrecorded rows
  # to the top of "weakest first" would put the least informative rows in front
  # of the actual weak-evidence backlog.
  seen <- character()
  mock_module(env = environment(), bindings = list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("COUNT(", sql, fixed = TRUE)) {
        return(data.frame(total = 0L))
      }
      seen <<- c(seen, sql)
      data.frame()
    }
  ))

  for (sort in c("strength_desc", "strength_asc")) {
    params <- svc_curate_variation_suggestion_params(
      NULL, NULL, NULL, NULL, NULL, sort, NULL, NULL
    )
    svc_curate_variation_suggestions(params, pool = NULL)
  }

  expect_length(seen, 2L)
  expect_true(all(grepl("IS NULL) ASC", seen, fixed = TRUE)))
  expect_match(seen[[1L]], "DESC", fixed = TRUE)
})

test_that("rows group evidence per assertion and expose the derived flags", {
  mock_module(env = environment(), bindings = list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("COUNT(", sql, fixed = TRUE)) {
        return(data.frame(total = 1L))
      }
      queue_rows(
        queue_row(source_type = "external_database", source_key = "clinvar",
                  batch_id = "clinvar-2026-02", evidence_strength = 2L, evidence_id = 1L,
                  evidence_summary = "10 ClinVar records, max 2 stars"),
        queue_row(source_type = "literature", source_key = "synopsis",
                  batch_id = "synopsis-2026-02", evidence_strength = 3L, evidence_id = 2L,
                  evidence_summary = "1 synopsis match")
      )
    }
  ))

  result <- svc_curate_variation_suggestions(default_params(), pool = NULL)

  expect_equal(result$meta$total, 1L)
  expect_equal(result$meta$page, 1L)
  expect_length(result$data, 1L)

  row <- result$data[[1L]]
  expect_equal(row$entity_id, 42L)
  expect_equal(row$vario_id, "VariO:0015")
  expect_equal(row$modifier_id, 1L)
  expect_true(row$served)
  expect_true(row$moved)
  expect_equal(row$max_strength, 3L)
  # Strongest evidence first, mirroring the entity-scoped surface's ordering.
  expect_equal(vapply(row$evidence, function(e) e$source_key, character(1)),
               c("synopsis", "clinvar"))
  # evidence_json is deliberately NOT on the list payload.
  expect_null(row$evidence[[1L]]$evidence_json)
})

test_that("an assertion with no evidence row yields an empty array, not a phantom", {
  # The LEFT JOIN produces one all-NA evidence row for an assertion with none;
  # source_key is NOT NULL in the table, so NA there can only mean "no match".
  mock_module(env = environment(), bindings = list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("COUNT(", sql, fixed = TRUE)) {
        return(data.frame(total = 1L))
      }
      queue_rows(queue_row(
        state = "suggested", served = 0L, moved = 0L,
        source_type = NA_character_, source_key = NA_character_,
        batch_id = NA_character_, evidence_strength = NA_integer_,
        evidence_summary = NA_character_, evidence_id = NA_integer_
      ))
    }
  ))

  row <- svc_curate_variation_suggestions(default_params(), pool = NULL)$data[[1L]]
  expect_length(row$evidence, 0L)
  expect_null(row$max_strength)
  expect_false(row$served)
  expect_false(row$moved)
  expect_equal(row$state, "suggested")
})

test_that("an empty result set returns an empty array with honest meta", {
  mock_module(env = environment(), bindings = list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("COUNT(", sql, fixed = TRUE)) {
        return(data.frame(total = 0L))
      }
      data.frame()
    }
  ))

  result <- svc_curate_variation_suggestions(default_params(), pool = NULL)
  expect_equal(result$meta$total, 0L)
  expect_length(result$data, 0L)
})

test_that("the service never co-locates a write with the connect table", {
  # It reads ndd_review_variation_ontology_connect to derive `served`. The
  # curated write path in functions/ontology-repository.R stays the sole writer;
  # test-unit-variation-connect-write-guard.R enforces that repo-wide.
  source_text <- paste(
    readLines(
      file.path(get_api_dir(), "services", "curate-variation-suggestion-service.R"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(source_text, "ndd_review_variation_ontology_connect", fixed = TRUE)
  for (verb in c("INSERT INTO ndd_review_variation_ontology_connect",
                 "UPDATE ndd_review_variation_ontology_connect",
                 "DELETE FROM ndd_review_variation_ontology_connect")) {
    expect_false(grepl(verb, source_text, fixed = TRUE))
  }
})

test_that("the service is registered with the single loader", {
  bootstrap <- paste(
    readLines(file.path(get_api_dir(), "bootstrap", "load_modules.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(bootstrap, "services/curate-variation-suggestion-service.R", fixed = TRUE)
})
