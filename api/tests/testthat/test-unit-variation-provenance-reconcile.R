# api/tests/testthat/test-unit-variation-provenance-reconcile.R
#
# Unit contracts for the write-reconciliation state machine (#608).
#
# The planner is PURE: every state-machine row below is driven directly with
# plain tibbles and no database at all. Only the applier and the orchestrator
# touch SQL, and the two tests at the bottom of this file drive those through
# injected `db_execute_query` / `db_execute_statement` stubs so the inertness
# guarantee is provable without a database too. The real-DB proof lives in
# test-integration-review-write-atomicity.R.

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/variation-provenance-reconcile.R", local = FALSE)

review_write_service_path <- file.path(
  get_api_dir(), "services", "review-write-service.R"
)
if (file.exists(review_write_service_path)) {
  source_api_file("services/review-write-service.R", local = FALSE)
}

# ---------------------------------------------------------------------------
# Fixture builders
# ---------------------------------------------------------------------------

vp_previous <- function(...) {
  rows <- list(...)
  tibble::tibble(
    assertion_id = vapply(rows, function(r) as.integer(r[[1L]]), integer(1)),
    vario_id     = vapply(rows, function(r) as.character(r[[2L]]), character(1)),
    modifier_id  = vapply(rows, function(r) as.integer(r[[3L]]), integer(1)),
    state        = vapply(rows, function(r) as.character(r[[4L]]), character(1))
  )
}

vp_no_previous <- function() {
  tibble::tibble(
    assertion_id = integer(), vario_id = character(),
    modifier_id = integer(), state = character()
  )
}

vp_submitted <- function(...) {
  rows <- list(...)
  if (length(rows) == 0L) {
    return(tibble::tibble(vario_id = character(), modifier_id = integer()))
  }
  tibble::tibble(
    vario_id    = vapply(rows, function(r) as.character(r[[1L]]), character(1)),
    modifier_id = vapply(rows, function(r) as.integer(r[[2L]]), integer(1))
  )
}

vp_actions <- function(...) {
  rows <- list(...)
  if (length(rows) == 0L) {
    return(tibble::tibble(
      vario_id = character(), modifier_id = integer(),
      provenance_action = character()
    ))
  }
  tibble::tibble(
    vario_id          = vapply(rows, function(r) as.character(r[[1L]]), character(1)),
    modifier_id       = vapply(rows, function(r) as.integer(r[[2L]]), integer(1)),
    provenance_action = vapply(rows, function(r) as.character(r[[3L]]), character(1))
  )
}


# ===========================================================================
# THE regression test for the original bug (#608). Read this one first.
# ===========================================================================

test_that("REGRESSION #608: saving a review with no provenance_action leaves an active_unconfirmed assertion active_unconfirmed -- a machine-derived annotation is NEVER silently promoted to curator-authored", {
  # A curator opens an entity to fix one sentence of synopsis. Every existing
  # variation-ontology term arrives pre-checked by the form's prefill, so the
  # term IS in the submitted set -- but the curator performed no act that
  # distinguishes "I read the papers and agree" from "I did not notice the
  # pre-checked box". Confirmation must therefore NOT happen.
  #
  # Two things must both hold: the assertion stays `active_unconfirmed` (not
  # promoted to `confirmed`), and no transition at all is planned (so the
  # annotation is not rejected either -- it stays live on the entity).
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(11L, "VariO:0017", 1L, "active_unconfirmed")),
    submitted = vp_submitted(list("VariO:0017", 1L)),
    actions   = vp_actions(list("VariO:0017", 1L, NA_character_))
  )

  expect_equal(nrow(plan), 0L)
  expect_false("confirmed" %in% plan$to_state)
})

test_that("REGRESSION #608: a client that sends no provenance field whatsoever still does not promote a resubmitted active_unconfirmed assertion", {
  # Two of the three prefill-and-resubmit frontend surfaces send no provenance
  # field at all. Correctness must not depend on the client sending anything.
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(11L, "VariO:0017", 1L, "active_unconfirmed")),
    submitted = vp_submitted(list("VariO:0017", 1L)),
    actions   = NULL
  )

  expect_equal(nrow(plan), 0L)
})


# ===========================================================================
# State machine -- one test per row of the table in the module header
# ===========================================================================

test_that("row 1 (spec): submitted + active_unconfirmed + an action that is not 'confirm' stays active_unconfirmed", {
  for (action in c("reject", "CONFIRM", "confirmed", "", "unknown-verb")) {
    plan <- variation_provenance_plan_reconciliation(
      previous  = vp_previous(list(11L, "VariO:0017", 1L, "active_unconfirmed")),
      submitted = vp_submitted(list("VariO:0017", 1L)),
      actions   = vp_actions(list("VariO:0017", 1L, action))
    )
    expect_equal(nrow(plan), 0L, info = paste("action:", action))
  }
})

test_that("row 2 (spec): submitted + active_unconfirmed + 'confirm' becomes confirmed and earns attribution", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(11L, "VariO:0017", 1L, "active_unconfirmed")),
    submitted = vp_submitted(list("VariO:0017", 1L)),
    actions   = vp_actions(list("VariO:0017", 1L, "confirm"))
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$assertion_id, 11L)
  expect_equal(plan$from_state, "active_unconfirmed")
  expect_equal(plan$to_state, "confirmed")
  expect_true(plan$needs_attribution)
})

test_that("row 3: submitted + suggested becomes confirmed with attribution regardless of the action field", {
  # A `suggested` assertion is by definition not in the curated set, so no
  # prefill surface can pre-check it. Its presence in a submission is an
  # affirmative curator act, so it earns attribution even with no action field.
  for (actions in list(NULL, vp_actions(), vp_actions(list("VariO:0017", 1L, NA_character_)),
                       vp_actions(list("VariO:0017", 1L, "confirm")))) {
    plan <- variation_provenance_plan_reconciliation(
      previous  = vp_previous(list(12L, "VariO:0017", 1L, "suggested")),
      submitted = vp_submitted(list("VariO:0017", 1L)),
      actions   = actions
    )
    expect_equal(nrow(plan), 1L)
    expect_equal(plan$from_state, "suggested")
    expect_equal(plan$to_state, "confirmed")
    expect_true(plan$needs_attribution)
  }
})

test_that("row 4: submitted + confirmed stays confirmed and is never re-stamped", {
  # Re-saving an already-confirmed term must not overwrite the original
  # curator's attribution with the current saver's; the record is historical.
  # An empty plan is exactly what makes that true -- the applier issues no
  # UPDATE at all, so confirmed_by/confirmed_at cannot be touched.
  for (actions in list(NULL, vp_actions(list("VariO:0017", 1L, "confirm")))) {
    plan <- variation_provenance_plan_reconciliation(
      previous  = vp_previous(list(13L, "VariO:0017", 1L, "confirmed")),
      submitted = vp_submitted(list("VariO:0017", 1L)),
      actions   = actions
    )
    expect_equal(nrow(plan), 0L)
  }
})

test_that("row 5: submitted + rejected becomes confirmed with fresh attribution", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(14L, "VariO:0017", 1L, "rejected")),
    submitted = vp_submitted(list("VariO:0017", 1L)),
    actions   = NULL
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$from_state, "rejected")
  expect_equal(plan$to_state, "confirmed")
  expect_true(plan$needs_attribution)
})

test_that("row 6 (spec): a submitted term with no assertion row creates no row and no transition", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(11L, "VariO:0017", 1L, "active_unconfirmed")),
    submitted = vp_submitted(list("VariO:0017", 1L), list("VariO:0999", 1L)),
    actions   = vp_actions(list("VariO:0999", 1L, "confirm"))
  )

  expect_equal(nrow(plan), 0L)
  expect_false("VariO:0999" %in% names(plan))
})

test_that("row 7 (spec): omitted + active_unconfirmed becomes rejected without attribution", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(11L, "VariO:0017", 1L, "active_unconfirmed")),
    submitted = vp_submitted(list("VariO:0001", 1L)),
    actions   = NULL
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$assertion_id, 11L)
  expect_equal(plan$from_state, "active_unconfirmed")
  expect_equal(plan$to_state, "rejected")
  expect_false(plan$needs_attribution)
})

test_that("row 8 (spec): omitted + suggested becomes rejected without attribution", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(12L, "VariO:0017", 1L, "suggested")),
    submitted = vp_submitted(),
    actions   = NULL
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$to_state, "rejected")
  expect_false(plan$needs_attribution)
})

test_that("row 9: omitted + confirmed stays confirmed (a removed term keeps its confirmation history)", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(13L, "VariO:0017", 1L, "confirmed")),
    submitted = vp_submitted(),
    actions   = NULL
  )

  expect_equal(nrow(plan), 0L)
})

test_that("row 10: omitted + rejected stays rejected (already suppressed)", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(14L, "VariO:0017", 1L, "rejected")),
    submitted = vp_submitted(),
    actions   = NULL
  )

  expect_equal(nrow(plan), 0L)
})


# ===========================================================================
# Identity invariant, inertness, and plan-shape invariants
# ===========================================================================

test_that("identity is (vario_id, modifier_id): present and absent for one vario_id reconcile independently", {
  # A planner that keys on vario_id alone passes every other test in this file
  # and fails this one.
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(21L, "VariO:0017", 1L, "active_unconfirmed"),   # present
      list(22L, "VariO:0017", 5L, "active_unconfirmed")    # absent
    ),
    submitted = vp_submitted(list("VariO:0017", 1L)),      # only 'present'
    actions   = NULL
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$assertion_id, 22L)                     # the absent claim
  expect_equal(plan$to_state, "rejected")
})

test_that("a 'confirm' on the present claim does not confirm the absent claim for the same vario_id", {
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(21L, "VariO:0017", 1L, "active_unconfirmed"),
      list(22L, "VariO:0017", 5L, "active_unconfirmed")
    ),
    submitted = vp_submitted(list("VariO:0017", 1L), list("VariO:0017", 5L)),
    actions   = vp_actions(list("VariO:0017", 1L, "confirm"))
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$assertion_id, 21L)
  expect_equal(plan$to_state, "confirmed")
})

test_that("INERTNESS: an empty previous set with a non-empty submitted set plans nothing", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_no_previous(),
    submitted = vp_submitted(list("VariO:0017", 1L), list("VariO:0015", 5L)),
    actions   = vp_actions(list("VariO:0017", 1L, "confirm"))
  )

  expect_equal(nrow(plan), 0L)
  expect_named(plan, c("assertion_id", "from_state", "to_state", "needs_attribution"))
  expect_type(plan$assertion_id, "integer")
  expect_type(plan$from_state, "character")
  expect_type(plan$to_state, "character")
  expect_type(plan$needs_attribution, "logical")
})

test_that("an empty submitted set rejects every active_unconfirmed and suggested assertion and leaves the rest", {
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(31L, "VariO:0001", 1L, "active_unconfirmed"),
      list(32L, "VariO:0002", 1L, "suggested"),
      list(33L, "VariO:0003", 1L, "confirmed"),
      list(34L, "VariO:0004", 1L, "rejected")
    ),
    submitted = vp_submitted(),
    actions   = NULL
  )

  expect_equal(nrow(plan), 2L)
  expect_equal(sort(plan$assertion_id), c(31L, 32L))
  expect_true(all(plan$to_state == "rejected"))
  expect_true(all(!plan$needs_attribution))
})

test_that("both sets empty gives an empty, correctly typed plan", {
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_no_previous(), submitted = vp_submitted(), actions = NULL
  )
  expect_equal(nrow(plan), 0L)
  expect_named(plan, c("assertion_id", "from_state", "to_state", "needs_attribution"))
})

test_that("a plan never contains a no-op transition, so the applier issues no pointless UPDATE", {
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(41L, "VariO:0001", 1L, "active_unconfirmed"),  # resubmitted, no action -> no-op
      list(42L, "VariO:0002", 1L, "confirmed"),           # resubmitted -> no-op
      list(43L, "VariO:0003", 1L, "rejected"),            # omitted -> no-op
      list(44L, "VariO:0004", 1L, "suggested"),           # omitted -> rejected
      list(45L, "VariO:0005", 1L, "active_unconfirmed")   # submitted + confirm -> confirmed
    ),
    submitted = vp_submitted(
      list("VariO:0001", 1L), list("VariO:0002", 1L), list("VariO:0005", 1L)
    ),
    actions = vp_actions(list("VariO:0005", 1L, "confirm"))
  )

  expect_equal(nrow(plan), 2L)
  expect_true(all(plan$from_state != plan$to_state))
})

test_that("needs_attribution is TRUE exactly for transitions into confirmed from a different state", {
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(51L, "VariO:0001", 1L, "suggested"),           # -> confirmed
      list(52L, "VariO:0002", 1L, "rejected"),            # -> confirmed
      list(53L, "VariO:0003", 1L, "active_unconfirmed"),  # -> confirmed (confirm)
      list(54L, "VariO:0004", 1L, "active_unconfirmed"),  # -> rejected
      list(55L, "VariO:0005", 1L, "suggested")            # -> rejected
    ),
    submitted = vp_submitted(
      list("VariO:0001", 1L), list("VariO:0002", 1L), list("VariO:0003", 1L)
    ),
    actions = vp_actions(list("VariO:0003", 1L, "confirm"))
  )

  expect_equal(nrow(plan), 5L)
  attribution <- setNames(plan$needs_attribution, plan$assertion_id)
  expect_true(attribution[["51"]])
  expect_true(attribution[["52"]])
  expect_true(attribution[["53"]])
  expect_false(attribution[["54"]])
  expect_false(attribution[["55"]])
  expect_equal(plan$needs_attribution, plan$to_state == "confirmed")
})

test_that("duplicate submitted entries for one identity are idempotent (one transition, not two)", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(61L, "VariO:0017", 1L, "suggested")),
    submitted = vp_submitted(
      list("VariO:0017", 1L), list("VariO:0017", 1L), list("VariO:0017", 1L)
    ),
    actions = vp_actions(
      list("VariO:0017", 1L, NA_character_), list("VariO:0017", 1L, "confirm")
    )
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$to_state, "confirmed")
})

test_that("a submitted modifier_id arriving as a character string still matches the assertion identity", {
  # Plumber/jsonlite can hand modifier ids over as strings; the identity key
  # must be type-stable or a resubmitted term would look omitted and be
  # rejected -- silently deleting a live annotation.
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(71L, "VariO:0017", 1L, "active_unconfirmed")),
    submitted = tibble::tibble(vario_id = "VariO:0017", modifier_id = "1"),
    actions   = NULL
  )

  expect_equal(nrow(plan), 0L)
})


# ===========================================================================
# I1 -- the identity key must be as case-insensitive as the DB collation
# ===========================================================================

test_that("REGRESSION #608 (I1): a case-variant vario_id still matches its existing assertion and is NOT rejected", {
  # variation_ontology_list.vario_id is utf8mb4_0900_ai_ci, so
  # review_write_validate_lookup_ids() accepts a submitted "vario:0017" and the
  # connect row IS written -- the term stays served. A case-SENSITIVE R identity
  # key would then classify the stored "VariO:0017" assertion as omitted, reject
  # it, drop it out of the read path's state filter, and the still-served
  # machine-derived term would present as curator-authored.
  for (variant in c("vario:0017", "VARIO:0017", "VaRiO:0017", " vario:0017 ")) {
    plan <- variation_provenance_plan_reconciliation(
      previous  = vp_previous(list(101L, "VariO:0017", 1L, "active_unconfirmed")),
      submitted = tibble::tibble(vario_id = variant, modifier_id = 1L),
      actions   = NULL
    )
    expect_equal(nrow(plan), 0L, info = paste("variant:", variant))
  }
})

test_that("I1: a case-variant vario_id can still carry an explicit confirmation", {
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(102L, "VariO:0017", 1L, "active_unconfirmed")),
    submitted = tibble::tibble(vario_id = "vario:0017", modifier_id = 1L),
    actions   = tibble::tibble(
      vario_id = "vario:0017", modifier_id = 1L, provenance_action = "confirm"
    )
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$assertion_id, 102L)
  expect_equal(plan$to_state, "confirmed")
})

test_that("REGRESSION #608 (I1, the reachable variant): an assertion STORED with non-canonical casing still matches a canonically-cased submission", {
  # This is the reachable direction. The submission side is protected by
  # review_write_validate_lookup_ids(), whose R-side setdiff() is case-sensitive
  # and 400s a case variant before it reaches reconciliation (verified in the
  # integration test). But the ASSERTION rows are written by a backfill in a
  # different repository. If that backfill stores "vario:0017" while the curated
  # connect table holds "VariO:0017", a case-sensitive key would classify EVERY
  # such assertion as omitted and reject all of them on the next save -- the
  # whole backfilled set would silently become curator-authored.
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(105L, "vario:0017", 1L, "active_unconfirmed")),
    submitted = vp_submitted(list("VariO:0017", 1L)),
    actions   = NULL
  )
  expect_equal(nrow(plan), 0L)

  confirmed <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(106L, "vario:0017", 1L, "active_unconfirmed")),
    submitted = vp_submitted(list("VariO:0017", 1L)),
    actions   = vp_actions(list("VariO:0017", 1L, "confirm"))
  )
  expect_equal(nrow(confirmed), 1L)
  expect_equal(confirmed$to_state, "confirmed")
})

test_that("I1: case-folding the ontology half does not collapse distinct vario_ids", {
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(103L, "VariO:0017", 1L, "active_unconfirmed"),
      list(104L, "VariO:0015", 1L, "active_unconfirmed")
    ),
    submitted = tibble::tibble(vario_id = "vario:0017", modifier_id = 1L),
    actions   = NULL
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$assertion_id, 104L)   # only the genuinely omitted one
  expect_equal(plan$to_state, "rejected")
})


# ===========================================================================
# I2 -- rejection applies only when the save determines the served term set
# ===========================================================================

test_that("REGRESSION #608 (I2): a draft save that omits a term leaves its assertion active_unconfirmed -- a draft never rejects a term the approved review is still serving", {
  # Assertions are entity-scoped, but the publicly served terms come from the
  # primary APPROVED review. A Reviewer's draft omission is not a statement about
  # the served set; rejecting on it would drop the assertion out of the read
  # path's state filter while the approved review keeps serving the term, so the
  # term would render as curator-authored. Removal becomes real on approval.
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(111L, "VariO:0017", 1L, "active_unconfirmed"),
      list(112L, "VariO:0015", 1L, "suggested")
    ),
    submitted        = vp_submitted(),
    actions          = NULL,
    apply_rejections = FALSE
  )

  expect_equal(nrow(plan), 0L)
})

test_that("I2: a save that DOES determine the served term set still rejects omitted terms", {
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(111L, "VariO:0017", 1L, "active_unconfirmed"),
      list(112L, "VariO:0015", 1L, "suggested")
    ),
    submitted        = vp_submitted(),
    actions          = NULL,
    apply_rejections = TRUE
  )

  expect_equal(nrow(plan), 2L)
  expect_true(all(plan$to_state == "rejected"))
})

test_that("I2: confirmations are NEVER gated -- an affirmative act on a draft still confirms", {
  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(121L, "VariO:0017", 1L, "active_unconfirmed"),  # confirm -> confirmed
      list(122L, "VariO:0015", 1L, "suggested"),           # submitted -> confirmed
      list(123L, "VariO:0013", 1L, "rejected"),            # submitted -> confirmed
      list(124L, "VariO:0011", 1L, "active_unconfirmed")   # omitted -> NOT rejected
    ),
    submitted = vp_submitted(
      list("VariO:0017", 1L), list("VariO:0015", 1L), list("VariO:0013", 1L)
    ),
    actions          = vp_actions(list("VariO:0017", 1L, "confirm")),
    apply_rejections = FALSE
  )

  expect_equal(nrow(plan), 3L)
  expect_true(all(plan$to_state == "confirmed"))
  expect_true(all(plan$needs_attribution))
  expect_false(124L %in% plan$assertion_id)
})

test_that("I2: apply_rejections defaults to TRUE so every pre-existing state-machine caller is unchanged", {
  formals_default <- formals(variation_provenance_plan_reconciliation)$apply_rejections
  expect_true(isTRUE(eval(formals_default)))

  expect_equal(
    nrow(variation_provenance_plan_reconciliation(
      previous  = vp_previous(list(131L, "VariO:0017", 1L, "active_unconfirmed")),
      submitted = vp_submitted()
    )),
    1L
  )
})

test_that("I2: a non-logical or NA apply_rejections is treated as FALSE (the non-destructive direction)", {
  for (flag in list(NA, NULL, "yes", 1L)) {
    plan <- variation_provenance_plan_reconciliation(
      previous         = vp_previous(list(141L, "VariO:0017", 1L, "active_unconfirmed")),
      submitted        = vp_submitted(),
      actions          = NULL,
      apply_rejections = flag
    )
    expect_equal(nrow(plan), 0L, info = paste("flag:", paste(format(flag), collapse = ",")))
  }
})

# (the orchestrator-level apply_rejections passthrough is exercised in the
#  applier/orchestrator section below, where the DB stub helper is defined)


# ===========================================================================
# M2 -- an unparseable submitted set must fail loudly, never look empty
# ===========================================================================

test_that("M2: an unparseable submitted set raises instead of degrading to 'everything omitted'", {
  # Degrading would look like "the curator removed every term" and reject the
  # entity's assertions -- silent degradation in the destructive direction.
  for (bad in list("not-a-table", 42L, as.name("x"))) {
    expect_error(
      variation_provenance_plan_reconciliation(
        previous  = vp_previous(list(161L, "VariO:0017", 1L, "active_unconfirmed")),
        submitted = bad,
        actions   = NULL
      ),
      class = "variation_provenance_unparseable_input"
    )
  }
})

test_that("M2: a genuinely empty submitted set is still accepted, not confused with an unparseable one", {
  for (empty in list(NULL, list(), tibble::tibble(vario_id = character(), modifier_id = integer()))) {
    plan <- variation_provenance_plan_reconciliation(
      previous  = vp_previous(list(171L, "VariO:0017", 1L, "active_unconfirmed")),
      submitted = empty,
      actions   = NULL
    )
    expect_equal(nrow(plan), 1L)
    expect_equal(plan$to_state, "rejected")
  }
})

test_that("M2: an unparseable actions set still degrades quietly (the safe direction)", {
  # actions only ever ADDS confirmations, so losing it cannot fabricate
  # provenance -- it just means no confirmation happens.
  plan <- variation_provenance_plan_reconciliation(
    previous  = vp_previous(list(181L, "VariO:0017", 1L, "active_unconfirmed")),
    submitted = vp_submitted(list("VariO:0017", 1L)),
    actions   = "not-a-table"
  )

  expect_equal(nrow(plan), 0L)
})


# ===========================================================================
# The extractor -> planner join
#
# The raw-payload shape coverage for review_write_extract_provenance_actions()
# lives in test-unit-review-write-provenance-actions.R. This one test stays
# here because it is the CROSS-MODULE contract: the extractor's output and the
# normalizer's output must agree on identity, or the planner joins nothing.
# ===========================================================================

test_that("the extracted action table feeds the planner directly, on the same raw payload the normalizer consumes", {
  # The production shape: Plumber parses the JSON body with jsonlite
  # simplifyVector = TRUE, so a uniform array of objects arrives as a
  # data.frame. review_write_normalize_ontology() and the extractor must agree
  # on it, because the planner joins their two outputs by identity.
  raw <- jsonlite::fromJSON(
    '[{"vario_id":"VariO:0017","modifier_id":1,"provenance_action":"confirm"},
      {"vario_id":"VariO:0015","modifier_id":1,"provenance_action":null}]',
    simplifyVector = TRUE
  )
  actions <- review_write_extract_provenance_actions(raw)
  submitted <- review_write_normalize_ontology(raw, "vario_id")

  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(91L, "VariO:0017", 1L, "active_unconfirmed"),
      list(92L, "VariO:0015", 1L, "active_unconfirmed"),
      list(93L, "VariO:0099", 1L, "active_unconfirmed")
    ),
    submitted = submitted,
    actions   = actions
  )

  expect_equal(nrow(plan), 2L)
  states <- setNames(plan$to_state, plan$assertion_id)
  expect_equal(states[["91"]], "confirmed")   # explicit confirm
  expect_equal(states[["93"]], "rejected")    # omitted from the submission
  expect_false("92" %in% names(states))       # resubmitted, no action -> untouched
})

test_that("the extractor and the normalizer agree on identity for the combined 'value' tag shape too", {
  # The other live wire shape. If the two split the tag differently the planner
  # would see an action for an identity that is not in the submitted set, and
  # would reject a term the curator just confirmed.
  raw <- tibble::tibble(
    value = c("1-VariO:0017", "5-VariO:0017"),
    provenance_action = c("confirm", NA_character_)
  )
  actions <- review_write_extract_provenance_actions(raw)
  submitted <- review_write_normalize_ontology(raw, "vario_id")

  expect_equal(actions$vario_id, submitted$vario_id)
  expect_equal(actions$modifier_id, submitted$modifier_id)

  plan <- variation_provenance_plan_reconciliation(
    previous = vp_previous(
      list(95L, "VariO:0017", 1L, "active_unconfirmed"),
      list(96L, "VariO:0017", 5L, "active_unconfirmed")
    ),
    submitted = submitted,
    actions   = actions
  )

  expect_equal(nrow(plan), 1L)
  expect_equal(plan$assertion_id, 95L)
  expect_equal(plan$to_state, "confirmed")
})


# ===========================================================================
# Applier and orchestrator -- SQL boundary, driven through stubs (no DB)
# ===========================================================================

vp_with_stubbed_db <- function(query_result, code) {
  statements <- list()
  had_query <- exists("db_execute_query", envir = .GlobalEnv, inherits = FALSE)
  had_stmt <- exists("db_execute_statement", envir = .GlobalEnv, inherits = FALSE)
  if (had_query) {
    previous_query <- base::get("db_execute_query", envir = .GlobalEnv, inherits = FALSE)
  }
  if (had_stmt) {
    previous_stmt <- base::get("db_execute_statement", envir = .GlobalEnv, inherits = FALSE)
  }

  assign("db_execute_query", function(sql, params = list(), conn = NULL) query_result,
         envir = .GlobalEnv)
  assign("db_execute_statement", function(sql, params = list(), conn = NULL) {
    statements[[length(statements) + 1L]] <<- list(sql = sql, params = params)
    1L
  }, envir = .GlobalEnv)
  withr::defer({
    if (had_query) {
      assign("db_execute_query", previous_query, envir = .GlobalEnv)
    } else {
      rm("db_execute_query", envir = .GlobalEnv)
    }
    if (had_stmt) {
      assign("db_execute_statement", previous_stmt, envir = .GlobalEnv)
    } else {
      rm("db_execute_statement", envir = .GlobalEnv)
    }
  }, envir = parent.frame())

  result <- code()
  list(result = result, statements = statements)
}

test_that("INERTNESS: with zero assertion rows the orchestrator issues no write statement at all", {
  # The backfill that populates these tables lives in another repository and
  # has not run. Until it does, this code path must be provably inert on
  # production traffic.
  run <- vp_with_stubbed_db(
    query_result = tibble::tibble(
      assertion_id = integer(), vario_id = character(),
      modifier_id = integer(), state = character()
    ),
    code = function() {
      variation_provenance_reconcile_for_review(
        entity_id = 2097L,
        submitted = vp_submitted(list("VariO:0017", 1L)),
        actions   = vp_actions(list("VariO:0017", 1L, "confirm")),
        review_user_id = 7L,
        conn = "stub-conn"
      )
    }
  )

  expect_equal(run$result, 0L)
  expect_length(run$statements, 0L)
})

test_that("I2: the orchestrator threads apply_rejections through, so a draft save issues no UPDATE", {
  run <- vp_with_stubbed_db(
    query_result = tibble::tibble(
      assertion_id = 151L, vario_id = "VariO:0017",
      modifier_id = 1L, state = "active_unconfirmed"
    ),
    code = function() {
      list(
        draft = variation_provenance_reconcile_for_review(
          entity_id = 2097L, submitted = vp_submitted(), actions = NULL,
          review_user_id = 7L, conn = "stub-conn", apply_rejections = FALSE
        ),
        served = variation_provenance_reconcile_for_review(
          entity_id = 2097L, submitted = vp_submitted(), actions = NULL,
          review_user_id = 7L, conn = "stub-conn", apply_rejections = TRUE
        )
      )
    }
  )

  expect_equal(run$result$draft, 0L)
  expect_equal(run$result$served, 1L)
  # Exactly one UPDATE across both calls: the draft call must issue none.
  expect_length(run$statements, 1L)
  expect_equal(run$statements[[1L]]$params, list("rejected", 151L))
})

test_that("the applier issues one UPDATE per planned transition and stamps attribution only when required", {
  plan <- tibble::tibble(
    assertion_id      = c(11L, 12L),
    from_state        = c("active_unconfirmed", "active_unconfirmed"),
    to_state          = c("confirmed", "rejected"),
    needs_attribution = c(TRUE, FALSE)
  )

  run <- vp_with_stubbed_db(
    query_result = tibble::tibble(),
    code = function() {
      variation_provenance_apply_reconciliation(plan, review_user_id = 7L, conn = "stub-conn")
    }
  )

  expect_equal(run$result, 2L)
  expect_length(run$statements, 2L)

  confirm_stmt <- run$statements[[1L]]
  expect_match(confirm_stmt$sql, "confirmed_by", fixed = TRUE)
  expect_match(confirm_stmt$sql, "confirmed_at", fixed = TRUE)
  expect_equal(confirm_stmt$params, list("confirmed", 7L, 11L))

  reject_stmt <- run$statements[[2L]]
  expect_false(grepl("confirmed_by", reject_stmt$sql, fixed = TRUE))
  expect_equal(reject_stmt$params, list("rejected", 12L))
})

test_that("the applier never touches ndd_review_variation_ontology_connect", {
  plan <- tibble::tibble(
    assertion_id = 11L, from_state = "active_unconfirmed",
    to_state = "rejected", needs_attribution = FALSE
  )

  run <- vp_with_stubbed_db(
    query_result = tibble::tibble(),
    code = function() {
      variation_provenance_apply_reconciliation(plan, review_user_id = 7L, conn = "stub-conn")
    }
  )

  expect_false(any(grepl(
    "ndd_review_variation_ontology_connect",
    vapply(run$statements, function(s) s$sql, character(1)),
    fixed = TRUE
  )))
})

test_that("an empty plan is applied as a no-op returning 0L", {
  run <- vp_with_stubbed_db(
    query_result = tibble::tibble(),
    code = function() {
      list(
        empty = variation_provenance_apply_reconciliation(
          variation_provenance_empty_plan(), review_user_id = 7L, conn = "stub-conn"
        ),
        null = variation_provenance_apply_reconciliation(
          NULL, review_user_id = 7L, conn = "stub-conn"
        )
      )
    }
  )

  expect_equal(run$result$empty, 0L)
  expect_equal(run$result$null, 0L)
  expect_length(run$statements, 0L)
})

test_that("a confirmation without a usable review_user_id fails loudly instead of writing an unattributed confirmation", {
  # The DB CHECK constraint (chk_confirmed_attribution) forbids a confirmed row
  # with a NULL confirmed_by, so silently proceeding would surface as an opaque
  # constraint violation mid-transaction.
  plan <- tibble::tibble(
    assertion_id = 11L, from_state = "suggested",
    to_state = "confirmed", needs_attribution = TRUE
  )

  had_stmt <- exists("db_execute_statement", envir = .GlobalEnv, inherits = FALSE)
  if (had_stmt) {
    previous_stmt <- base::get("db_execute_statement", envir = .GlobalEnv, inherits = FALSE)
  }
  assign("db_execute_statement", function(...) stop("must not write"), envir = .GlobalEnv)
  withr::defer({
    if (had_stmt) {
      assign("db_execute_statement", previous_stmt, envir = .GlobalEnv)
    } else {
      rm("db_execute_statement", envir = .GlobalEnv)
    }
  })

  expect_error(
    variation_provenance_apply_reconciliation(plan, review_user_id = NULL, conn = "stub-conn"),
    class = "variation_provenance_attribution_error"
  )
  expect_error(
    variation_provenance_apply_reconciliation(plan, review_user_id = NA, conn = "stub-conn"),
    class = "variation_provenance_attribution_error"
  )
})

test_that("the orchestrator reads all four assertion states, not just the served ones", {
  # The state machine needs `rejected` and `suggested` rows too: a submitted
  # rejected term must be liftable back to confirmed. A read filtered to
  # ('active_unconfirmed','confirmed') -- which is correct for the public READ
  # path -- would silently break that.
  captured_sql <- NULL
  had_query <- exists("db_execute_query", envir = .GlobalEnv, inherits = FALSE)
  if (had_query) {
    previous_query <- base::get("db_execute_query", envir = .GlobalEnv, inherits = FALSE)
  }
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    captured_sql <<- sql
    tibble::tibble(
      assertion_id = integer(), vario_id = character(),
      modifier_id = integer(), state = character()
    )
  }, envir = .GlobalEnv)
  withr::defer({
    if (had_query) {
      assign("db_execute_query", previous_query, envir = .GlobalEnv)
    } else {
      rm("db_execute_query", envir = .GlobalEnv)
    }
  })

  variation_provenance_assertions_for_entity(2097L, conn = "stub-conn")

  expect_match(captured_sql, "variation_ontology_assertion", fixed = TRUE)
  expect_match(captured_sql, "WHERE entity_id = ?", fixed = TRUE)
  expect_false(grepl("active_unconfirmed", captured_sql, fixed = TRUE))
})


# ===========================================================================
# Runtime registration
# ===========================================================================

test_that("the reconciliation module is registered for runtime loading", {
  # Without this line review_write_mutate() cannot resolve
  # variation_provenance_reconcile_for_review() and every review save fails.
  # The call is deliberately NOT exists()-guarded: silently skipping
  # reconciliation would silently restore the #608 laundering bug.
  bootstrap <- paste(
    readLines(file.path(get_api_dir(), "bootstrap", "load_modules.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(bootstrap, "functions/variation-provenance-reconcile.R", fixed = TRUE)
})
