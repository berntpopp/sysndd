# api/tests/testthat/test-unit-approval-service-provenance.R
#
# #612: approval is when the served set becomes real.
#
# WHY THIS HOOK EXISTS
# --------------------
# Write reconciliation gates its REJECTION edges on
# review_write_save_determines_served_set(): a Reviewer's draft omission must not
# suppress provenance for terms the approved review is still serving. But
# review_update() unconditionally sets review_approved = 0
# (functions/review-repository.R), so on the ordinary
# edit-then-approve-separately workflow that gate never opens. The term stops
# being served, yet its assertion stays active_unconfirmed -- the safe direction,
# but the suggestion-suppression signal is lost and the curation queue keeps
# offering a term nobody serves.
#
# REJECTION-ONLY, DELIBERATELY. Approving a review is an act on the REVIEW, not a
# per-term reading of machine evidence. See the apply_confirmations tests here
# and in test-unit-variation-provenance-reconcile.R.

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/variation-provenance-reconcile.R", local = FALSE)
source_api_file("functions/variation-provenance-approval.R", local = FALSE)
source_api_file("functions/db-transaction-scope.R", local = FALSE)
source_api_file("services/approval-service.R", local = FALSE)

# Stub a binding the module under test resolves at call time.
#
# testthat's local_mocked_bindings() cannot target these: globalenv() has no
# pkgload namespace, so it aborts with "No packages loaded with pkgload"
# (test-unit-clustering-gene-universe.R:13). The suite's own idiom is a direct
# assign plus a withr::defer restore (test-unit-review-write-service.R:151).
#
# The subtlety this helper exists to encode: `source_api_file(local = FALSE)`
# sources into `parent.frame()` -- the TEST FILE's environment, not .GlobalEnv
# (helper-paths.R:52-66). So a module function sourced here resolves its
# siblings from that environment, and assigning the stub into .GlobalEnv is a
# silent no-op: the real function is found first and the test exercises
# production code with an unmocked database. Target the function's OWN enclosing
# environment instead, which is by construction where it looks.
#
# The second subtlety: `env` is REQUIRED, not defaulted to `parent.frame()`.
# Under `test_that()` the block is `eval()`ed, so `parent.frame()` seen from a
# helper called inside it is not the test's own frame, and the deferred restore
# fires at the wrong moment -- observed here as the first stub being removed
# before the function under test could see it. Each caller passes
# `environment()`, which is unambiguously the test frame.
#
# `base::get`/`base::exists` are explicit because the `config` package masks
# `base::get` with a signature that has no `envir` argument (AGENTS.md).
MODULE_ENV <- environment(variation_provenance_reconcile_on_approval)

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


# ---------------------------------------------------------------------------
# variation_provenance_served_terms_for_entity()
# ---------------------------------------------------------------------------

test_that("served terms come from primary approved reviews with active connect rows", {
  captured <- NULL
  mock_module(env = environment(), bindings = list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      captured <<- list(sql = sql, params = params)
      tibble::tibble(
        vario_id    = c("VariO:0015", "VariO:0017"),
        modifier_id = c(1L, 5L)
      )
    }
  ))

  served <- variation_provenance_served_terms_for_entity(42L)

  expect_equal(served$vario_id, c("VariO:0015", "VariO:0017"))
  expect_equal(served$modifier_id, c(1L, 5L))
  expect_equal(captured$params, list(42L))
  # The served set is defined by the PUBLIC read's own rule
  # (svc_entity_variation, services/entity-read-endpoint-service.R). A query that
  # drops any of these three clauses serves a different set than the entity page
  # does, and the whole hook then rejects the wrong terms.
  expect_match(captured$sql, "is_active = 1", fixed = TRUE)
  expect_match(captured$sql, "is_primary = 1", fixed = TRUE)
  expect_match(captured$sql, "review_approved = 1", fixed = TRUE)
  # Bound, never interpolated.
  expect_false(grepl("42", captured$sql, fixed = TRUE))
})

test_that("an empty served set yields a zero-row tibble with the right columns", {
  mock_module(env = environment(), bindings = list(db_execute_query = function(...) tibble::tibble()))

  served <- variation_provenance_served_terms_for_entity(42L)
  expect_equal(nrow(served), 0L)
  expect_setequal(names(served), c("vario_id", "modifier_id"))
})

test_that("a NULL query result is treated as an empty served set, not an error", {
  mock_module(env = environment(), bindings = list(db_execute_query = function(...) NULL))
  expect_equal(nrow(variation_provenance_served_terms_for_entity(42L)), 0L)
})


# ---------------------------------------------------------------------------
# variation_provenance_reconcile_on_approval()
# ---------------------------------------------------------------------------

test_that("approval rejects an omitted term and leaves a served one alone", {
  applied <- NULL
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = c(1L, 2L),
        vario_id     = c("VariO:0015", "VariO:0017"),
        modifier_id  = c(1L, 1L),
        state        = c("active_unconfirmed", "active_unconfirmed")
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = "VariO:0015", modifier_id = 1L)
    },
    variation_provenance_apply_reconciliation = function(plan, review_user_id, conn = NULL) {
      applied <<- plan
      nrow(plan)
    }
  ))

  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 1L)
  expect_equal(applied$assertion_id, 2L)
  expect_equal(applied$to_state, "rejected")
  expect_false(applied$needs_attribution)
})

test_that("approval never confirms a submitted suggestion -- it restores it instead", {
  # A `suggested` assertion whose term IS served must not stay invisible (the
  # public read would then show the term as curator-authored), but approving a
  # review is not a per-term reading of evidence either. It becomes
  # `active_unconfirmed`: visible as machine provenance, still awaiting a real
  # decision in the curation queue.
  applied <- NULL
  statements <- list()
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = 1L, vario_id = "VariO:0017", modifier_id = 1L, state = "suggested"
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = "VariO:0017", modifier_id = 1L)
    },
    variation_provenance_apply_reconciliation = function(plan, review_user_id, conn = NULL) {
      applied <<- plan
      nrow(plan)
    },
    db_execute_statement = function(sql, params = list(), conn = NULL) {
      statements[[length(statements) + 1L]] <<- sql
      1L
    }
  ))

  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 1L)
  # The state machine planned nothing -- no confirmation, no rejection.
  expect_null(applied)
  # The restore did the work, and it never writes attribution.
  expect_length(statements, 1L)
  expect_match(statements[[1L]], "state = 'active_unconfirmed'", fixed = TRUE)
  expect_false(grepl("confirmed_by", statements[[1L]], fixed = TRUE))
})

test_that("approval never re-stamps an already-confirmed assertion", {
  applied <- NULL
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = 1L, vario_id = "VariO:0015", modifier_id = 1L, state = "confirmed"
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = "VariO:0015", modifier_id = 1L)
    },
    variation_provenance_apply_reconciliation = function(plan, review_user_id, conn = NULL) {
      applied <<- plan
      nrow(plan)
    }
  ))

  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 0L)
  expect_null(applied)
})

test_that("an EMPTY post-approval served set rejects every open assertion", {
  # Approval itself creates the primary approved review, so an entity whose
  # approved review carries no variation terms legitimately serves none. A
  # "skip when the served set is empty" guard would strand exactly the
  # assertions this hook exists to retire.
  applied <- NULL
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = c(1L, 2L, 3L),
        vario_id     = c("VariO:0015", "VariO:0017", "VariO:0031"),
        modifier_id  = c(1L, 1L, 1L),
        state        = c("active_unconfirmed", "suggested", "confirmed")
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = character(), modifier_id = integer())
    },
    variation_provenance_apply_reconciliation = function(plan, review_user_id, conn = NULL) {
      applied <<- plan
      nrow(plan)
    }
  ))

  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 2L)
  expect_setequal(applied$assertion_id, c(1L, 2L))
  expect_true(all(applied$to_state == "rejected"))
})

test_that("identity is (vario_id, modifier_id) -- present and absent are independent", {
  applied <- NULL
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = c(1L, 2L),
        vario_id     = c("VariO:0015", "VariO:0015"),
        modifier_id  = c(1L, 5L),
        state        = c("active_unconfirmed", "active_unconfirmed")
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = "VariO:0015", modifier_id = 1L)
    },
    variation_provenance_apply_reconciliation = function(plan, review_user_id, conn = NULL) {
      applied <<- plan
      nrow(plan)
    }
  ))

  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 1L)
  # Only the `absent` assertion is retired; the served `present` one is untouched.
  expect_equal(applied$assertion_id, 2L)
})

test_that("an entity with no assertion rows short-circuits without a served-set query", {
  served_called <- FALSE
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = integer(), vario_id = character(),
        modifier_id = integer(), state = character()
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      served_called <<- TRUE
      tibble::tibble(vario_id = character(), modifier_id = integer())
    }
  ))

  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 0L)
  expect_false(served_called)
})

test_that("the module is registered with the single loader", {
  # Files are not autodiscovered, and the same loader serves the API and the
  # durable worker.
  bootstrap <- paste(
    readLines(file.path(get_api_dir(), "bootstrap", "load_modules.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(bootstrap, "functions/variation-provenance-approval.R", fixed = TRUE)
})


test_that("the stub helper restores what it replaced", {
  # Self-check: if teardown did not work, a stub would leak into the next test
  # and this file's other assertions would be exercising each other's mocks
  # rather than the module.
  original <- variation_provenance_served_terms_for_entity
  local({
    mock_module(env = environment(), bindings = list(
      variation_provenance_served_terms_for_entity = function(...) "stubbed"
    ))
    expect_identical(variation_provenance_served_terms_for_entity(1L), "stubbed")
  })
  expect_identical(variation_provenance_served_terms_for_entity, original)

  expect_false(base::exists("db_execute_query", envir = MODULE_ENV, inherits = FALSE))
  local({
    mock_module(env = environment(), bindings = list(db_execute_query = function(...) NULL))
    expect_true(base::exists("db_execute_query", envir = MODULE_ENV, inherits = FALSE))
  })
  expect_false(base::exists("db_execute_query", envir = MODULE_ENV, inherits = FALSE))
})


# ---------------------------------------------------------------------------
# svc_approval_review_approve() -- the hook's call site
# ---------------------------------------------------------------------------

test_that("approving a review reconciles each affected entity exactly once", {
  reconciled <- integer()
  approved <- NULL
  entity_sql <- NULL
  mock_module(env = environment(), bindings = list(
    review_approve = function(review_ids, approving_user_id, approved = TRUE, conn = NULL) {
      approved <<- review_ids
      review_ids
    },
    db_execute_query = function(sql, params = list(), conn = NULL) {
      entity_sql <<- sql
      # One review can only belong to one entity, but "all" spans many, and a
      # single entity can own several of them -- hence DISTINCT plus unique().
      data.frame(entity_id = c(11L, 11L, 12L))
    },
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    variation_provenance_reconcile_on_approval = function(entity_id, review_user_id,
                                                          conn = NULL) {
      reconciled <<- c(reconciled, as.integer(entity_id))
      0L
    }
  ))

  result <- svc_approval_review_approve(42L, user_id = 7L, approve = TRUE, pool = NULL)

  expect_equal(result$status, 200)
  expect_equal(sort(reconciled), c(11L, 12L))
  expect_equal(approved, 42L)
  expect_match(entity_sql, "DISTINCT", fixed = TRUE)
  # Bound, never interpolated.
  expect_false(grepl("42", entity_sql, fixed = TRUE))
})

test_that("unapproving a review reconciles nothing", {
  # Unapproving does not establish a served set, so it must not retire anything.
  called <- FALSE
  mock_module(env = environment(), bindings = list(
    review_approve = function(review_ids, ...) review_ids,
    db_execute_query = function(...) data.frame(entity_id = 11L),
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    variation_provenance_reconcile_on_approval = function(...) {
      called <<- TRUE
      0L
    }
  ))

  svc_approval_review_approve(42L, user_id = 7L, approve = FALSE, pool = NULL)
  expect_false(called)
})

test_that("approval and reconciliation run inside ONE transaction scope", {
  # A reconciliation failure must roll the approval back, or the entity is left
  # serving terms whose provenance disagrees with what it serves.
  scoped <- character()
  inner_conn <- structure(list(), class = "FakeConn")
  seen_conns <- list()
  mock_module(env = environment(), bindings = list(
    review_approve = function(review_ids, approving_user_id, approved = TRUE, conn = NULL) {
      seen_conns$approve <<- conn
      review_ids
    },
    db_execute_query = function(sql, params = list(), conn = NULL) {
      seen_conns$query <<- conn
      data.frame(entity_id = 11L)
    },
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) {
      scoped <<- c(scoped, savepoint)
      fn(inner_conn)
    },
    variation_provenance_reconcile_on_approval = function(entity_id, review_user_id,
                                                          conn = NULL) {
      seen_conns$reconcile <<- conn
      0L
    }
  ))

  svc_approval_review_approve(42L, user_id = 7L, approve = TRUE, pool = NULL)

  expect_length(scoped, 1L)
  expect_identical(seen_conns$approve, inner_conn)
  expect_identical(seen_conns$query, inner_conn)
  expect_identical(seen_conns$reconcile, inner_conn)
})

test_that("a reconciliation failure propagates so the scope can roll back", {
  mock_module(env = environment(), bindings = list(
    review_approve = function(review_ids, ...) review_ids,
    db_execute_query = function(...) data.frame(entity_id = 11L),
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    variation_provenance_reconcile_on_approval = function(...) stop("reconcile boom")
  ))

  expect_error(
    svc_approval_review_approve(42L, user_id = 7L, approve = TRUE, pool = NULL),
    "reconcile boom"
  )
})

test_that("a vector of review ids no longer trips the length-1 'all' check", {
  # `if (as.character(c(42, 43)) == "all")` raises "the condition has length > 1",
  # so this function's DOCUMENTED multi-id support has never worked. The
  # per-entity reconciliation loop depends on it.
  approved <- NULL
  mock_module(env = environment(), bindings = list(
    review_approve = function(review_ids, approving_user_id, approved = TRUE, conn = NULL) {
      approved <<- review_ids
      review_ids
    },
    db_execute_query = function(...) data.frame(entity_id = 11L),
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    variation_provenance_reconcile_on_approval = function(...) 0L
  ))

  result <- svc_approval_review_approve(c(42L, 43L), user_id = 7L, approve = TRUE, pool = NULL)

  expect_equal(result$status, 200)
  expect_equal(approved, c(42L, 43L))
  expect_equal(result$entry, c(42L, 43L))
})

test_that("null inputs still short-circuit with a 400 before any transaction", {
  scoped <- FALSE
  mock_module(env = environment(), bindings = list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) {
      scoped <<- TRUE
      fn(db)
    }
  ))

  result <- svc_approval_review_approve(NULL, user_id = 7L, approve = TRUE, pool = NULL)
  expect_equal(result$status, 400)
  expect_false(scoped)
})

test_that("an empty pending set returns OK without opening a transaction", {
  scoped <- FALSE
  mock_module(env = environment(), bindings = list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) {
      scoped <<- TRUE
      fn(db)
    }
  ))

  result <- svc_approval_review_approve(integer(0), user_id = 7L, approve = TRUE, pool = NULL)
  expect_equal(result$status, 200)
  expect_equal(result$entry, integer(0))
  expect_false(scoped)
})


# ---------------------------------------------------------------------------
# The restore edge (#612 review follow-up)
# ---------------------------------------------------------------------------
#
# The public read filters provenance to ('active_unconfirmed','confirmed'), so
# an assertion left `suggested` or `rejected` while its term IS served renders
# as CURATOR-AUTHORED. That is reachable: a curator dismisses an unserved
# suggestion in the queue (legitimate), a draft containing that term is approved
# later, and the term becomes served with a `rejected` assertion behind it.

test_that("approval restores a now-served suggested assertion to active_unconfirmed", {
  statements <- list()
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = 9L, vario_id = "VariO:0015", modifier_id = 1L, state = "suggested"
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = "VariO:0015", modifier_id = 1L)
    },
    db_execute_statement = function(sql, params = list(), conn = NULL) {
      statements[[length(statements) + 1L]] <<- list(sql = sql, params = params)
      1L
    }
  ))

  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 1L)
  expect_length(statements, 1L)
  expect_match(statements[[1L]]$sql, "state = 'active_unconfirmed'", fixed = TRUE)
  # NEVER confirmed: approving a review is not a per-term reading of evidence.
  expect_false(grepl("confirmed_by", statements[[1L]]$sql, fixed = TRUE))
  # Conditional, so a concurrent transition wins rather than being clobbered.
  expect_match(statements[[1L]]$sql, "AND state IN ('suggested', 'rejected')", fixed = TRUE)
})

test_that("approval restores a now-served rejected assertion too", {
  statements <- list()
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = 9L, vario_id = "VariO:0015", modifier_id = 1L, state = "rejected"
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = "VariO:0015", modifier_id = 1L)
    },
    db_execute_statement = function(sql, params = list(), conn = NULL) {
      statements[[length(statements) + 1L]] <<- list(sql = sql, params = params)
      1L
    }
  ))

  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 1L)
  expect_equal(statements[[1L]]$params, list(9L))
})

test_that("a served assertion that is already visible is left alone", {
  called <- FALSE
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = c(9L, 10L),
        vario_id = c("VariO:0015", "VariO:0017"),
        modifier_id = c(1L, 1L),
        state = c("active_unconfirmed", "confirmed")
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = c("VariO:0015", "VariO:0017"), modifier_id = c(1L, 1L))
    },
    db_execute_statement = function(...) {
      called <<- TRUE
      1L
    }
  ))

  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 0L)
  expect_false(called)
})

test_that("an UNSERVED suggested assertion is not restored -- it is not visible anyway", {
  statements <- list()
  mock_module(env = environment(), bindings = list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = 9L, vario_id = "VariO:0017", modifier_id = 1L, state = "suggested"
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = "VariO:0015", modifier_id = 1L)
    },
    db_execute_statement = function(sql, params = list(), conn = NULL) {
      statements[[length(statements) + 1L]] <<- list(sql = sql, params = params)
      1L
    }
  ))

  # It IS rejected by the omitted-term edge, but never "restored".
  variation_provenance_reconcile_on_approval(42L, review_user_id = 7L)
  expect_false(any(vapply(
    statements,
    function(s) grepl("state = 'active_unconfirmed'", s$sql, fixed = TRUE),
    logical(1)
  )))
})

test_that("re-review approval routes through the approval service, not the repository", {
  # Approving a re-review publishes a term set exactly like any other approval,
  # so it must run the same reconciliation in the same transaction.
  service <- paste(
    readLines(
      file.path(get_api_dir(), "services", "re-review-workflow-endpoint-service.R"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(service, "svc_approval_review_approve(", fixed = TRUE)
  expect_false(grepl("\n  review_approve(", service, fixed = TRUE))
})
