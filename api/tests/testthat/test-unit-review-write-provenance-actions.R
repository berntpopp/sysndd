# api/tests/testthat/test-unit-review-write-provenance-actions.R
#
# Unit contracts for review_write_extract_provenance_actions() (#608).
#
# Split out of test-unit-variation-provenance-reconcile.R to keep both files
# well under the repo's 600-line soft ceiling. This file covers the RAW payload
# shapes only; the state machine that consumes the extracted table lives in
# test-unit-variation-provenance-reconcile.R, which also keeps the one
# cross-module test that joins the extractor's output to the planner.
#
# review_write_normalize_ontology() deliberately reduces each submitted term to
# exactly (vario_id, modifier_id) -- that two-column output is the connect-table
# write payload and is shared with the phenotype path. The extractor is the
# separate reader of the RAW submission that recovers provenance_action without
# widening it.

source_api_file("core/errors.R", local = FALSE)

review_write_service_path <- file.path(
  get_api_dir(), "services", "review-write-service.R"
)
if (file.exists(review_write_service_path)) {
  source_api_file("services/review-write-service.R", local = FALSE)
}

# ===========================================================================
# Every raw payload shape the three prefill-and-resubmit surfaces produce
# ===========================================================================

vp_expect_empty_actions <- function(out) {
  expect_true(is.data.frame(out))
  expect_named(out, c("vario_id", "modifier_id", "provenance_action"))
  expect_equal(nrow(out), 0L)
  expect_type(out$vario_id, "character")
  expect_type(out$modifier_id, "integer")
  expect_type(out$provenance_action, "character")
}

test_that("NULL, list() and a zero-row tibble all yield a correctly typed zero-row action table", {
  vp_expect_empty_actions(review_write_extract_provenance_actions(NULL))
  vp_expect_empty_actions(review_write_extract_provenance_actions(list()))
  vp_expect_empty_actions(review_write_extract_provenance_actions(
    tibble::tibble(vario_id = character(), modifier_id = integer())
  ))
})

test_that("records carrying vario_id + modifier_id parse with a missing action as NA, never 'confirm'", {
  out <- review_write_extract_provenance_actions(list(
    list(vario_id = "VariO:0017", modifier_id = 1L),
    list(vario_id = "VariO:0015", modifier_id = 5L)
  ))

  expect_equal(out$vario_id, c("VariO:0017", "VariO:0015"))
  expect_equal(out$modifier_id, c(1L, 5L))
  expect_true(all(is.na(out$provenance_action)))
})

test_that("records carrying vario_id + modifier_id + provenance_action parse the action through", {
  out <- review_write_extract_provenance_actions(list(
    list(vario_id = "VariO:0017", modifier_id = 1L, provenance_action = "confirm"),
    list(vario_id = "VariO:0015", modifier_id = 5L, provenance_action = "reject")
  ))

  expect_equal(out$provenance_action, c("confirm", "reject"))
})

test_that("a single un-nested record (one term submitted) yields exactly one row", {
  out <- review_write_extract_provenance_actions(
    list(vario_id = "VariO:0017", modifier_id = 1L, provenance_action = "confirm")
  )

  expect_equal(nrow(out), 1L)
  expect_equal(out$vario_id, "VariO:0017")
  expect_equal(out$provenance_action, "confirm")
})

test_that("a data.frame payload (jsonlite simplifyVector = TRUE) parses without walking columns", {
  # AGENTS.md, async-job-force-apply-payload.R: `vapply(table, \(x) x$field)`
  # over a data.frame walks COLUMNS (atomic vectors) and dies with
  # "$ operator is invalid for atomic vectors". Plumber's body parser
  # simplifies a uniform array of objects into exactly this shape.
  payload <- jsonlite::fromJSON(
    '[{"vario_id":"VariO:0017","modifier_id":1,"provenance_action":"confirm"},
      {"vario_id":"VariO:0015","modifier_id":5,"provenance_action":null}]',
    simplifyVector = TRUE
  )
  expect_true(is.data.frame(payload))

  out <- review_write_extract_provenance_actions(payload)

  expect_equal(nrow(out), 2L)
  expect_equal(out$vario_id, c("VariO:0017", "VariO:0015"))
  expect_equal(out$modifier_id, c(1L, 5L))
  expect_equal(out$provenance_action, c("confirm", NA_character_))
})

test_that("a data.frame payload without a provenance_action column parses with all-NA actions", {
  payload <- jsonlite::fromJSON(
    '[{"vario_id":"VariO:0017","modifier_id":1},{"vario_id":"VariO:0015","modifier_id":5}]',
    simplifyVector = TRUE
  )
  expect_true(is.data.frame(payload))

  out <- review_write_extract_provenance_actions(payload)

  expect_equal(nrow(out), 2L)
  expect_true(all(is.na(out$provenance_action)))
})

test_that("a combined 'value' tag splits on the FIRST hyphen only", {
  out <- review_write_extract_provenance_actions(list(
    list(value = "1-VariO:0017"),
    list(value = "5-VariO:0015", provenance_action = "confirm")
  ))

  expect_equal(out$vario_id, c("VariO:0017", "VariO:0015"))
  expect_equal(out$modifier_id, c(1L, 5L))
  expect_equal(out$provenance_action, c(NA_character_, "confirm"))
})

test_that("a 'value' tag whose ontology half contains a hyphen is never truncated (#600 family)", {
  out <- review_write_extract_provenance_actions(list(
    list(value = "1-VariO:0015-alpha")
  ))

  expect_equal(out$vario_id, "VariO:0015-alpha")
  expect_equal(out$modifier_id, 1L)
})

test_that("a 'value' tag data.frame shape parses identically to the record-list shape", {
  out <- review_write_extract_provenance_actions(
    tibble::tibble(value = c("1-VariO:0017", "5-VariO:0015"))
  )

  expect_equal(out$vario_id, c("VariO:0017", "VariO:0015"))
  expect_equal(out$modifier_id, c(1L, 5L))
})

test_that("missing, NULL, NA and empty-string provenance_action all become NA_character_, never 'confirm'", {
  out <- review_write_extract_provenance_actions(list(
    list(vario_id = "VariO:0001", modifier_id = 1L),
    list(vario_id = "VariO:0002", modifier_id = 1L, provenance_action = NULL),
    list(vario_id = "VariO:0003", modifier_id = 1L, provenance_action = NA),
    list(vario_id = "VariO:0004", modifier_id = 1L, provenance_action = NA_character_),
    list(vario_id = "VariO:0005", modifier_id = 1L, provenance_action = ""),
    list(vario_id = "VariO:0006", modifier_id = 1L, provenance_action = "   ")
  ))

  expect_equal(nrow(out), 6L)
  expect_true(all(is.na(out$provenance_action)))
})

test_that("an unrecognized provenance_action is carried through verbatim, not coerced towards 'confirm'", {
  # The extractor is a faithful projection; deciding that "Confirm" and
  # "definitely-yes" are NOT confirmations is the planner's job, and
  # test-unit-variation-provenance-reconcile.R's "row 1" test drives exactly
  # these values through it.
  out <- review_write_extract_provenance_actions(list(
    list(vario_id = "VariO:0017", modifier_id = 1L, provenance_action = "Confirm"),
    list(vario_id = "VariO:0015", modifier_id = 1L, provenance_action = "definitely-yes")
  ))

  expect_equal(out$provenance_action, c("Confirm", "definitely-yes"))
})

test_that("a padded 'confirm' is accepted, matching the file's existing trimws normalization", {
  out <- review_write_extract_provenance_actions(list(
    list(vario_id = "VariO:0017", modifier_id = 1L, provenance_action = " confirm ")
  ))
  expect_equal(out$provenance_action, "confirm")
})

test_that("rows with an unusable identity are dropped rather than raising", {
  out <- review_write_extract_provenance_actions(list(
    list(vario_id = "VariO:0017", modifier_id = 1L, provenance_action = "confirm"),
    list(vario_id = "VariO:0018", modifier_id = "not-a-number"),
    list(vario_id = "", modifier_id = 1L),
    list(value = "VariO:0019"),
    list(unrelated = "noise")
  ))

  expect_equal(nrow(out), 1L)
  expect_equal(out$vario_id, "VariO:0017")
})

