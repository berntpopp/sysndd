# api/tests/testthat/test-unit-curate-variation-apply.R
#
# #612 Phase 6: the queue's two write actions.
#
# THE ASYMMETRY IS THE WHOLE DESIGN
# ---------------------------------
# `provenance_for_entity()` filters the public read to
# ('active_unconfirmed','confirmed'). Writing `rejected` onto an
# `active_unconfirmed` assertion drops it out of that filter while the term is
# STILL SERVED, so the entity card renders it as CURATOR-AUTHORED -- the exact
# fabrication this feature exists to prevent. Therefore:
#
#   Confirm  requires state == 'active_unconfirmed' AND served
#   Dismiss  requires state == 'suggested'          AND NOT served
#
# The other direction of each pair would have to ADD or REMOVE a curated term,
# which is a review write and must go through review_write_mutate(). The queue
# never writes ndd_review_variation_ontology_connect.
#
# CONCURRENCY
# -----------
# Server-side re-derivation is not enough on its own: a dismiss could read
# `suggested + not served` while a concurrent review write adds and approves the
# term, then commit `rejected` onto a now-served assertion. So the batch takes a
# `SELECT ... FOR UPDATE` on its assertion rows, re-reads served membership while
# holding those locks, and writes CONDITIONALLY on the state it observed.

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/variation-provenance-reconcile.R", local = FALSE)
source_api_file("functions/variation-provenance-approval.R", local = FALSE)
source_api_file("services/curate-variation-apply-service.R", local = FALSE)

MODULE_ENV <- environment(svc_curate_variation_apply)

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

item <- function(vario_id = "VariO:0015", modifier_id = 1L, entity_id = 42L) {
  list(entity_id = entity_id, vario_id = vario_id, modifier_id = modifier_id)
}

locked <- function(state, vario_id = "VariO:0015", modifier_id = 1L,
                   assertion_id = 9L, entity_id = 42L) {
  data.frame(
    assertion_id = assertion_id, entity_id = entity_id, vario_id = vario_id,
    modifier_id = modifier_id, state = state, stringsAsFactors = FALSE
  )
}

served <- function(vario_id = "VariO:0015", modifier_id = 1L) {
  tibble::tibble(vario_id = vario_id, modifier_id = as.integer(modifier_id))
}

no_terms <- tibble::tibble(vario_id = character(), modifier_id = integer())

#' Wire up the module's four collaborators for one scenario.
stub_apply <- function(env, lock_rows, served_terms, affected = 1L, capture = NULL) {
  mock_module(env = env, bindings = list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (!is.null(capture)) capture$lock_sql <- sql
      lock_rows
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      served_terms
    },
    db_execute_statement = function(sql, params = list(), conn = NULL) {
      if (!is.null(capture)) {
        capture$statements <- c(capture$statements, list(list(sql = sql, params = params)))
      }
      affected
    }
  ))
}


# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------

test_that("an unknown action is a 400", {
  expect_error(
    svc_curate_variation_apply(list(item()), "retire", 7L, db = NULL),
    class = "error_400"
  )
})

test_that("an empty item list is a 400, not a no-op success", {
  # A silent 200 with applied = 0 would read as "nothing needed doing".
  expect_error(svc_curate_variation_apply(list(), "confirm", 7L, db = NULL), class = "error_400")
  expect_error(svc_curate_variation_apply(NULL, "confirm", 7L, db = NULL), class = "error_400")
})

test_that("more than 100 items is a 400", {
  items <- replicate(101L, item(), simplify = FALSE)
  expect_error(svc_curate_variation_apply(items, "confirm", 7L, db = NULL), class = "error_400")
})

test_that("a malformed identity is a 400 rather than a silently dropped item", {
  expect_error(
    svc_curate_variation_apply(list(list(entity_id = "x", vario_id = "VariO:0015",
                                         modifier_id = 1L)), "confirm", 7L, db = NULL),
    class = "error_400"
  )
  expect_error(
    svc_curate_variation_apply(list(list(entity_id = 42L, vario_id = "",
                                         modifier_id = 1L)), "confirm", 7L, db = NULL),
    class = "error_400"
  )
  expect_error(
    svc_curate_variation_apply(list(list(entity_id = 42L, vario_id = "VariO:0015",
                                         modifier_id = "abc")), "confirm", 7L, db = NULL),
    class = "error_400"
  )
})

test_that("confirm without a usable user id is a 400, not a constraint violation", {
  # Confirm stamps confirmed_by, and migration 047's chk_confirmed_attribution
  # forbids a confirmed row with a NULL confirmed_by -- so a malformed caller
  # would otherwise surface as an opaque 500 mid-transaction.
  for (bad in list(NULL, NA_integer_, "abc")) {
    expect_error(
      svc_curate_variation_apply(list(item()), "confirm", bad, db = NULL),
      class = "error_400"
    )
  }
})

test_that("dismiss does not require a user id -- it stamps no attribution", {
  capture <- new.env()
  stub_apply(environment(), locked("suggested"), no_terms, capture = capture)
  result <- svc_curate_variation_apply(list(item()), "dismiss", NULL, db = NULL)
  expect_equal(result$applied, 1L)
})


# ---------------------------------------------------------------------------
# The two refusals
# ---------------------------------------------------------------------------

test_that("confirm refuses an assertion that is not served", {
  # A `suggested` assertion is by definition NOT in the curated set; confirming
  # it would have to ADD the term, which is a review write.
  stub_apply(environment(), locked("suggested"), no_terms)
  result <- svc_curate_variation_apply(list(item()), "confirm", 7L, db = NULL)
  expect_equal(result$requested, 1L)
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "wrong_state")
})

test_that("confirm refuses a served assertion in the wrong state", {
  stub_apply(environment(), locked("confirmed"), served())
  result <- svc_curate_variation_apply(list(item()), "confirm", 7L, db = NULL)
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "wrong_state")
})

test_that("confirm refuses an active_unconfirmed assertion the entity does not serve", {
  stub_apply(environment(), locked("active_unconfirmed"), no_terms)
  result <- svc_curate_variation_apply(list(item()), "confirm", 7L, db = NULL)
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "not_served")
})

test_that("dismiss refuses an assertion that IS served", {
  # THE load-bearing refusal: rejecting a served term makes the entity card
  # render it as curator-authored.
  stub_apply(environment(), locked("suggested"), served())
  result <- svc_curate_variation_apply(list(item()), "dismiss", 7L, db = NULL)
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "served")
})

test_that("dismiss refuses an active_unconfirmed assertion", {
  stub_apply(environment(), locked("active_unconfirmed"), no_terms)
  result <- svc_curate_variation_apply(list(item()), "dismiss", 7L, db = NULL)
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "wrong_state")
})

test_that("an unknown assertion is skipped, never created", {
  stub_apply(environment(), data.frame(), no_terms)
  result <- svc_curate_variation_apply(list(item()), "confirm", 7L, db = NULL)
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "not_found")
})


# ---------------------------------------------------------------------------
# The writes
# ---------------------------------------------------------------------------

test_that("confirm stamps state and attribution, conditioned on the observed state", {
  capture <- new.env(); capture$statements <- list()
  stub_apply(environment(), locked("active_unconfirmed"), served(), capture = capture)

  result <- svc_curate_variation_apply(list(item()), "confirm", 7L, db = NULL)

  expect_equal(result$applied, 1L)
  expect_length(result$skipped, 0L)
  expect_length(capture$statements, 1L)
  statement <- capture$statements[[1L]]
  expect_match(statement$sql, "state = 'confirmed'", fixed = TRUE)
  expect_match(statement$sql, "confirmed_by = ?", fixed = TRUE)
  # Conditional on the state observed under the row lock, so a transaction that
  # lost the race writes 0 rows instead of clobbering the winner.
  expect_match(statement$sql, "AND state = ?", fixed = TRUE)
  values <- vapply(statement$params, function(p) as.character(p)[[1L]], character(1))
  expect_equal(values, c("7", "9", "active_unconfirmed"))
})

test_that("dismiss sets rejected and stamps no attribution", {
  capture <- new.env(); capture$statements <- list()
  stub_apply(environment(), locked("suggested"), no_terms, capture = capture)

  result <- svc_curate_variation_apply(list(item()), "dismiss", 7L, db = NULL)

  expect_equal(result$applied, 1L)
  statement <- capture$statements[[1L]]
  expect_match(statement$sql, "state = 'rejected'", fixed = TRUE)
  expect_false(grepl("confirmed_by", statement$sql, fixed = TRUE))
  expect_match(statement$sql, "AND state = ?", fixed = TRUE)
})

test_that("a state that changed under the lock is reported skipped, not applied", {
  stub_apply(environment(), locked("active_unconfirmed"), served(), affected = 0L)
  result <- svc_curate_variation_apply(list(item()), "confirm", 7L, db = NULL)
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "state_changed")
})

test_that("the locking read orders by assertion_id and takes row locks", {
  # Ordering by assertion_id means two concurrent batches acquire their locks in
  # the same order and cannot deadlock on each other.
  capture <- new.env(); capture$statements <- list()
  stub_apply(environment(), locked("active_unconfirmed"), served(), capture = capture)
  svc_curate_variation_apply(list(item()), "confirm", 7L, db = NULL)
  expect_match(capture$lock_sql, "ORDER BY a.assertion_id", fixed = TRUE)
  expect_match(capture$lock_sql, "FOR UPDATE", fixed = TRUE)
})

test_that("identity is (entity, vario, modifier) -- present and absent decide separately", {
  stub_apply(
    environment(),
    rbind(locked("active_unconfirmed", modifier_id = 1L, assertion_id = 9L),
          locked("active_unconfirmed", modifier_id = 5L, assertion_id = 10L)),
    served(modifier_id = 1L)
  )
  result <- svc_curate_variation_apply(
    list(item(modifier_id = 1L), item(modifier_id = 5L)), "confirm", 7L, db = NULL
  )
  expect_equal(result$requested, 2L)
  expect_equal(result$applied, 1L)
  expect_equal(result$skipped[[1L]]$modifier_id, 5L)
  expect_equal(result$skipped[[1L]]$reason, "not_served")
})

test_that("identity comparison is case-insensitive on vario_id", {
  # vario_id collates case-insensitively in MySQL, so a case variant names the
  # same assertion. A case-SENSITIVE comparison here would report `not_served`
  # for a term the entity does serve.
  stub_apply(environment(), locked("active_unconfirmed", vario_id = "vario:0015"), served())
  result <- svc_curate_variation_apply(
    list(item(vario_id = "VariO:0015")), "confirm", 7L, db = NULL
  )
  expect_equal(result$applied, 1L)
})

test_that("a mixed batch reports every skip with its own reason", {
  # A silent partial success on a provenance surface is the failure mode this
  # whole feature exists to avoid.
  stub_apply(
    environment(),
    rbind(locked("active_unconfirmed", modifier_id = 1L, assertion_id = 9L),
          locked("confirmed", modifier_id = 5L, assertion_id = 10L)),
    served(modifier_id = 1L)
  )
  result <- svc_curate_variation_apply(
    list(item(modifier_id = 1L), item(modifier_id = 5L),
         item(vario_id = "VariO:0099")),
    "confirm", 7L, db = NULL
  )
  expect_equal(result$requested, 3L)
  expect_equal(result$applied, 1L)
  expect_setequal(
    vapply(result$skipped, function(s) s$reason, character(1)),
    c("wrong_state", "not_found")
  )
})

test_that("the whole batch runs in one transaction scope", {
  scoped <- character()
  mock_module(env = environment(), bindings = list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) {
      scoped <<- c(scoped, savepoint)
      fn(db)
    },
    db_execute_query = function(...) locked("active_unconfirmed"),
    variation_provenance_served_terms_for_entity = function(...) served(),
    db_execute_statement = function(...) 1L
  ))
  svc_curate_variation_apply(list(item(), item(modifier_id = 5L)), "confirm", 7L, db = NULL)
  expect_length(scoped, 1L)
})

test_that("the service never co-locates a write with the connect table", {
  source_text <- paste(
    readLines(
      file.path(get_api_dir(), "services", "curate-variation-apply-service.R"),
      warn = FALSE
    ),
    collapse = "\n"
  )
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
  expect_match(bootstrap, "services/curate-variation-apply-service.R", fixed = TRUE)
})
