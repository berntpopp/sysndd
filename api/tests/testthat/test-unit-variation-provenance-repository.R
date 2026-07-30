# api/tests/testthat/test-unit-variation-provenance-repository.R

source_api_file("functions/variation-provenance-repository.R", local = FALSE)

terms_fixture <- tibble::tibble(
  entity_id   = c(2097L, 2097L, 2097L, 2097L),
  vario_id    = c("VariO:0001", "VariO:0015", "VariO:0017", "VariO:0017"),
  vario_name  = c("variation", "protein truncation",
                  "nonsynonymous variation", "nonsynonymous variation"),
  modifier_id = c(1L, 1L, 1L, 5L)
)

provenance_fixture <- tibble::tibble(
  entity_id        = c(2097L, 2097L, 2097L),
  vario_id         = c("VariO:0015", "VariO:0017", "VariO:0017"),
  modifier_id      = c(1L, 1L, 1L),
  state            = c("confirmed", "active_unconfirmed", "active_unconfirmed"),
  source_type      = c("external_database", "external_database", "literature"),
  source_key       = c("clinvar", "clinvar", "synopsis"),
  evidence_strength = c(2L, 1L, 3L),
  evidence_summary = c("5 ClinVar records, max 2 stars",
                       "2 ClinVar records, max 1 star",
                       "Matched 'truncating variants' in synopsis")
)

test_that("terms without an assertion are curator-authored (NULL)", {
  out <- attach_provenance(terms_fixture, provenance_fixture)
  expect_true(is.null(out[out$vario_id == "VariO:0001", ]$provenance[[1]]))
})

test_that("present and absent are distinguished by modifier", {
  out <- attach_provenance(terms_fixture, provenance_fixture)
  present <- out[out$vario_id == "VariO:0017" & out$modifier_id == 1L, ]$provenance[[1]]
  absent  <- out[out$vario_id == "VariO:0017" & out$modifier_id == 5L, ]$provenance[[1]]

  expect_equal(present$state, "active_unconfirmed")
  expect_null(absent)   # no assertion for the 'absent' claim
})

test_that("multiple sources are returned as a deterministically ordered array", {
  out <- attach_provenance(terms_fixture, provenance_fixture)
  prov <- out[out$vario_id == "VariO:0017" & out$modifier_id == 1L, ]$provenance[[1]]

  expect_equal(length(prov$sources), 2L)
  # strongest first, then source_key ascending
  expect_equal(prov$sources[[1]]$source_key, "synopsis")
  expect_equal(prov$sources[[1]]$strength, 3L)
  expect_equal(prov$sources[[2]]$source_key, "clinvar")
  expect_equal(prov$max_strength, 3L)
})

test_that("the stored summary is returned verbatim, not regenerated", {
  out <- attach_provenance(terms_fixture, provenance_fixture)
  prov <- out[out$vario_id == "VariO:0017" & out$modifier_id == 1L, ]$provenance[[1]]
  expect_equal(prov$sources[[1]]$summary,
               "Matched 'truncating variants' in synopsis")
})

test_that("attach_provenance never drops or reorders terms", {
  out <- attach_provenance(terms_fixture, provenance_fixture)
  expect_equal(nrow(out), 4L)
  expect_equal(out$vario_id, terms_fixture$vario_id)
})

test_that("an empty provenance table leaves every term curator-authored", {
  out <- attach_provenance(terms_fixture, provenance_fixture[0, ])
  expect_true(all(vapply(out$provenance, is.null, logical(1))))
})

test_that("the full evidence payload is never inlined on the hot path", {
  out <- attach_provenance(terms_fixture, provenance_fixture)
  prov <- out[out$vario_id == "VariO:0017" & out$modifier_id == 1L, ]$provenance[[1]]
  expect_null(prov$evidence_json)
  expect_null(prov$sources[[1]]$items)
})

test_that("the repository module is registered for runtime loading", {
  bootstrap <- paste(
    readLines(file.path(get_api_dir(), "bootstrap", "load_modules.R"), warn = FALSE),
    collapse = "\n")
  expect_match(bootstrap, "functions/variation-provenance-repository.R", fixed = TRUE)
})

# --- Additional cases beyond the brief's verbatim block ---------------------

test_that("a zero-row terms tibble still has a provenance column", {
  out <- attach_provenance(terms_fixture[0, ], provenance_fixture)
  expect_true("provenance" %in% names(out))
  expect_equal(nrow(out), 0L)
})

test_that("an assertion with no evidence rows gets an empty sources list, not a phantom entry", {
  # This mimics the left-join NA row provenance_for_entity() genuinely produces
  # for a suggested/active_unconfirmed assertion whose evidence has not been
  # written yet: source_type/source_key/evidence_strength/evidence_summary are
  # all NA because there is literally no evidence row to join, not because a
  # real evidence row has an unrecorded strength.
  #
  # Deliberate choice (documented per the brief): an empty sources list is
  # preferred over a list containing a single all-NA phantom source, because
  # `sources` is rendered directly to the client and an all-NA entry would be
  # a meaningless element for a consumer to iterate over.
  terms_no_evidence <- tibble::tibble(
    entity_id = 3001L, vario_id = "VariO:0020",
    vario_name = "no evidence yet", modifier_id = 1L
  )
  provenance_no_evidence <- tibble::tibble(
    entity_id = 3001L, vario_id = "VariO:0020", modifier_id = 1L,
    state = "active_unconfirmed",
    source_type = NA_character_, source_key = NA_character_,
    evidence_strength = NA_integer_, evidence_summary = NA_character_
  )

  out <- attach_provenance(terms_no_evidence, provenance_no_evidence)
  prov <- out$provenance[[1]]

  expect_false(is.null(prov))
  expect_equal(prov$state, "active_unconfirmed")
  expect_true(is.na(prov$max_strength))
  expect_equal(length(prov$sources), 0L)
})

test_that("all-NA strengths across two real sources give NA max_strength, not -Inf", {
  terms_x <- tibble::tibble(
    entity_id = 4001L, vario_id = "VariO:0030",
    vario_name = "all na strength", modifier_id = 1L
  )
  provenance_x <- tibble::tibble(
    entity_id         = c(4001L, 4001L),
    vario_id          = c("VariO:0030", "VariO:0030"),
    modifier_id       = c(1L, 1L),
    state             = c("confirmed", "confirmed"),
    source_type       = c("literature", "literature"),
    source_key        = c("zeta", "alpha"),
    evidence_strength = c(NA_integer_, NA_integer_),
    evidence_summary  = c("z summary", "a summary")
  )

  out <- attach_provenance(terms_x, provenance_x)
  prov <- out$provenance[[1]]

  expect_true(is.na(prov$max_strength))
  expect_equal(length(prov$sources), 2L)
  # no strength to sort by anywhere -> falls back to source_key ascending
  expect_equal(prov$sources[[1]]$source_key, "alpha")
  expect_equal(prov$sources[[2]]$source_key, "zeta")
})

test_that("a mixed NA/present strength source sorts last and max_strength ignores the NA", {
  terms_x <- tibble::tibble(
    entity_id = 4002L, vario_id = "VariO:0031",
    vario_name = "mixed na strength", modifier_id = 1L
  )
  provenance_x <- tibble::tibble(
    entity_id         = c(4002L, 4002L),
    vario_id          = c("VariO:0031", "VariO:0031"),
    modifier_id       = c(1L, 1L),
    state             = c("confirmed", "confirmed"),
    source_type       = c("literature", "external_database"),
    # "aaa_no_strength" sorts first alphabetically, which would win a
    # source_key-only sort; it must still lose to "clinvar" because strength
    # ordering takes priority and only ties fall back to source_key.
    source_key        = c("aaa_no_strength", "clinvar"),
    evidence_strength = c(NA_integer_, 2L),
    evidence_summary  = c("no strength recorded", "2 stars")
  )

  out <- attach_provenance(terms_x, provenance_x)
  prov <- out$provenance[[1]]

  expect_equal(prov$max_strength, 2L)
  expect_equal(prov$sources[[1]]$source_key, "clinvar")
  expect_equal(prov$sources[[2]]$source_key, "aaa_no_strength")
})

test_that("duplicate identity rows in terms each get the same provenance, row count unchanged", {
  terms_dup <- tibble::tibble(
    entity_id   = c(2097L, 2097L),
    vario_id    = c("VariO:0017", "VariO:0017"),
    vario_name  = c("nonsynonymous variation", "nonsynonymous variation"),
    modifier_id = c(1L, 1L)
  )

  out <- attach_provenance(terms_dup, provenance_fixture)

  expect_equal(nrow(out), 2L)
  expect_equal(out$provenance[[1]]$state, out$provenance[[2]]$state)
  expect_equal(length(out$provenance[[1]]$sources), length(out$provenance[[2]]$sources))
  expect_equal(out$provenance[[1]]$sources[[1]]$source_key,
               out$provenance[[2]]$sources[[1]]$source_key)
})

test_that("a provenance row whose identity matches no term is ignored, not injected as a row", {
  provenance_extra <- dplyr::bind_rows(
    provenance_fixture,
    tibble::tibble(
      entity_id = 9999L, vario_id = "VariO:9999", modifier_id = 1L,
      state = "confirmed", source_type = "literature", source_key = "ghost",
      evidence_strength = 1L, evidence_summary = "matches no term"
    )
  )

  out <- attach_provenance(terms_fixture, provenance_extra)

  expect_equal(nrow(out), nrow(terms_fixture))
  expect_equal(out$vario_id, terms_fixture$vario_id)
  expect_equal(out$modifier_id, terms_fixture$modifier_id)
})

test_that("state is a single scalar from the assertion, not a per-source vector", {
  out <- attach_provenance(terms_fixture, provenance_fixture)
  prov <- out[out$vario_id == "VariO:0017" & out$modifier_id == 1L, ]$provenance[[1]]

  expect_length(prov$state, 1L)
  expect_equal(prov$state, "active_unconfirmed")
})

test_that("type stability: modifier_id as double in terms matches integer in provenance", {
  # Empirically verified (see task-3-report.md): paste(1, ...) and
  # paste(1L, ...) both render "1", so small identity values such as
  # modifier_id (1-10ish) and the fixture entity_id (2097) are unaffected.
  # This test locks that specific claim from the brief.
  terms_double <- tibble::tibble(
    entity_id = 5001L, vario_id = "VariO:0040",
    vario_name = "type stability", modifier_id = 1
  )
  provenance_int <- tibble::tibble(
    entity_id = 5001L, vario_id = "VariO:0040", modifier_id = 1L,
    state = "confirmed", source_type = "literature", source_key = "s",
    evidence_strength = 2L, evidence_summary = "ok"
  )

  expect_true(is.double(terms_double$modifier_id))
  expect_true(is.integer(provenance_int$modifier_id))

  out <- attach_provenance(terms_double, provenance_int)
  expect_false(is.null(out$provenance[[1]]))
  expect_equal(out$provenance[[1]]$state, "confirmed")
})

# --- Fix round 1 (review-foundation.md I3 / M5) ------------------------------

test_that("a terms tibble missing an identity column fails loudly, naming the column", {
  # I3: before this guard, paste() silently renders the missing column as
  # "" for every row, so every term would match nothing and render as
  # NULL / curator-authored -- a silent fabrication, not an error. Assert
  # the actual failure mode (a classed stop() naming the column), not just
  # "some error happened".
  terms_missing_modifier <- dplyr::select(terms_fixture, -modifier_id)
  expect_error(
    attach_provenance(terms_missing_modifier, provenance_fixture),
    "modifier_id"
  )

  terms_missing_entity <- dplyr::select(terms_fixture, -entity_id)
  expect_error(
    attach_provenance(terms_missing_entity, provenance_fixture),
    "entity_id"
  )

  terms_missing_vario <- dplyr::select(terms_fixture, -vario_id)
  expect_error(
    attach_provenance(terms_missing_vario, provenance_fixture),
    "vario_id"
  )
})

test_that("a non-NULL provenance tibble missing a required column fails loudly, naming the column", {
  provenance_missing_state <- dplyr::select(provenance_fixture, -state)
  expect_error(
    attach_provenance(terms_fixture, provenance_missing_state),
    "state"
  )

  provenance_missing_source_key <- dplyr::select(provenance_fixture, -source_key)
  expect_error(
    attach_provenance(terms_fixture, provenance_missing_source_key),
    "source_key"
  )

  provenance_missing_summary <- dplyr::select(provenance_fixture, -evidence_summary)
  expect_error(
    attach_provenance(terms_fixture, provenance_missing_summary),
    "evidence_summary"
  )
})

test_that("a zero-row provenance table (all columns intact) still passes validation and works", {
  # Regression guard distinguishing "0 rows" from "0/missing columns": the
  # I3 guard must be a column-presence check, not a row-count check.
  out <- attach_provenance(terms_fixture, provenance_fixture[0, ])
  expect_true(all(vapply(out$provenance, is.null, logical(1))))
})

test_that("a zero-row terms table (all columns intact) still passes validation and works", {
  out <- attach_provenance(terms_fixture[0, ], provenance_fixture)
  expect_true("provenance" %in% names(out))
  expect_equal(nrow(out), 0L)
})

test_that("provenance = NULL is exempt from the column-presence guard and keeps prior behaviour", {
  # NULL is a supported degenerate input ("no provenance available"),
  # distinct from a malformed non-NULL provenance object. It must not be
  # rejected by the I3 guard; every term should resolve to NULL as before.
  out <- attach_provenance(terms_fixture, NULL)
  expect_true(all(vapply(out$provenance, is.null, logical(1))))
})

test_that("max_strength is always integer, never double, when strengths are present", {
  out <- attach_provenance(terms_fixture, provenance_fixture)
  prov <- out[out$vario_id == "VariO:0017" & out$modifier_id == 1L, ]$provenance[[1]]

  expect_identical(prov$max_strength, 3L)
  expect_true(is.integer(prov$max_strength))
})

# --- Fix round 2: case-insensitive vario_id identity -------------------------
#
# `variation_ontology_list.vario_id` is `utf8mb4_0900_ai_ci`, so the DATABASE
# treats `vario:0017` and `VariO:0017` as the same term and the FK accepts an
# assertion stored under either. The write path
# (.variation_provenance_identity_key(), functions/variation-provenance-reconcile.R)
# was already hardened for this; the read path's join key was left
# case-SENSITIVE, so a non-canonically-cased assertion produced
# `provenance: null` -- which the API contract defines as CURATOR-AUTHORED.
# The public entity card then showed a machine-derived annotation as curated
# while the SQL-resolved `.../evidence` route still returned its
# machine-derived evidence: the exact fabrication this feature prevents.

test_that("an assertion whose vario_id casing differs from the served term still matches", {
  # The reachable production shape: the companion backfill (a different
  # repository) stores `vario:0017`; the view serves `VariO:0017`.
  terms_served <- tibble::tibble(
    entity_id = 6001L, vario_id = "VariO:0017",
    vario_name = "nonsynonymous variation", modifier_id = 1L
  )
  provenance_miscased <- tibble::tibble(
    entity_id = 6001L, vario_id = "vario:0017", modifier_id = 1L,
    state = "active_unconfirmed", source_type = "external_database",
    source_key = "clinvar", evidence_strength = 2L,
    evidence_summary = "5 ClinVar records, max 2 stars"
  )

  out <- attach_provenance(terms_served, provenance_miscased)
  prov <- out$provenance[[1]]

  expect_false(is.null(prov))   # NULL here == fabricated curator attribution
  expect_equal(prov$state, "active_unconfirmed")
  expect_equal(prov$max_strength, 2L)
  expect_equal(prov$sources[[1]]$source_key, "clinvar")
})

test_that("case normalization is symmetric: a lower-cased served term matches an upper-cased assertion", {
  terms_served <- tibble::tibble(
    entity_id = 6002L, vario_id = "vario:0015",
    vario_name = "protein truncation", modifier_id = 1L
  )
  provenance_upper <- tibble::tibble(
    entity_id = 6002L, vario_id = "VARIO:0015", modifier_id = 1L,
    state = "confirmed", source_type = "literature",
    source_key = "synopsis", evidence_strength = 3L,
    evidence_summary = "Matched 'truncating variants' in synopsis"
  )

  out <- attach_provenance(terms_served, provenance_upper)
  expect_false(is.null(out$provenance[[1]]))
  expect_equal(out$provenance[[1]]$state, "confirmed")
})

test_that("present and absent stay independent under mixed vario_id casing", {
  # The load-bearing pairing: relaxing the vario_id comparison must NOT relax
  # the modifier_id one. 'present' (1) and 'absent' (5) are different claims,
  # so an assertion for one must never attach to the other.
  terms_both <- tibble::tibble(
    entity_id   = c(6003L, 6003L),
    vario_id    = c("VariO:0017", "VariO:0017"),
    vario_name  = c("nonsynonymous variation", "nonsynonymous variation"),
    modifier_id = c(1L, 5L)
  )
  provenance_present_only <- tibble::tibble(
    entity_id = 6003L, vario_id = "vario:0017", modifier_id = 1L,
    state = "confirmed", source_type = "external_database",
    source_key = "clinvar", evidence_strength = 2L,
    evidence_summary = "present only"
  )

  out <- attach_provenance(terms_both, provenance_present_only)
  present <- out[out$modifier_id == 1L, ]$provenance[[1]]
  absent  <- out[out$modifier_id == 5L, ]$provenance[[1]]

  expect_false(is.null(present))
  expect_equal(present$state, "confirmed")
  expect_null(absent)

  # And the mirror image: an 'absent' assertion must not leak onto 'present'.
  provenance_absent_only <- tibble::tibble(
    entity_id = 6003L, vario_id = "VARIO:0017", modifier_id = 5L,
    state = "active_unconfirmed", source_type = "external_database",
    source_key = "clinvar", evidence_strength = 1L,
    evidence_summary = "absent only"
  )

  out2 <- attach_provenance(terms_both, provenance_absent_only)
  expect_null(out2[out2$modifier_id == 1L, ]$provenance[[1]])
  expect_equal(out2[out2$modifier_id == 5L, ]$provenance[[1]]$state,
               "active_unconfirmed")
})

test_that("case normalization does not collapse two genuinely different vario ids", {
  # Guards the other direction: toupper() must widen the match only across
  # casing, never across distinct terms.
  terms_two <- tibble::tibble(
    entity_id   = c(6004L, 6004L),
    vario_id    = c("VariO:0015", "VariO:0017"),
    vario_name  = c("protein truncation", "nonsynonymous variation"),
    modifier_id = c(1L, 1L)
  )
  provenance_one <- tibble::tibble(
    entity_id = 6004L, vario_id = "vario:0015", modifier_id = 1L,
    state = "confirmed", source_type = "literature", source_key = "synopsis",
    evidence_strength = 3L, evidence_summary = "only 0015"
  )

  out <- attach_provenance(terms_two, provenance_one)
  expect_false(is.null(out[out$vario_id == "VariO:0015", ]$provenance[[1]]))
  expect_null(out[out$vario_id == "VariO:0017", ]$provenance[[1]])
})

test_that("the served vario_id keeps its original casing; only the join key is normalized", {
  # Normalization is a comparison concern. Rewriting the payload's casing
  # would change what the API returns to clients, which is not the fix.
  terms_served <- tibble::tibble(
    entity_id = 6005L, vario_id = "VariO:0017",
    vario_name = "nonsynonymous variation", modifier_id = 1L
  )
  provenance_miscased <- tibble::tibble(
    entity_id = 6005L, vario_id = "vario:0017", modifier_id = 1L,
    state = "confirmed", source_type = "literature", source_key = "synopsis",
    evidence_strength = 1L, evidence_summary = "s"
  )

  out <- attach_provenance(terms_served, provenance_miscased)
  expect_identical(out$vario_id, "VariO:0017")
})

test_that(".variation_provenance_read_key normalizes casing and space but not identity", {
  # Direct unit coverage of the helper both halves of the join share, so a
  # future edit that de-normalizes one side is caught here as well as through
  # attach_provenance().
  expect_identical(
    .variation_provenance_read_key(1L, "vario:0017", 1L),
    .variation_provenance_read_key(1L, "VariO:0017", 1L)
  )
  expect_identical(
    .variation_provenance_read_key(1L, "  VariO:0017 ", 1L),
    .variation_provenance_read_key(1L, "VariO:0017", 1L)
  )
  # Distinct entity / term / modifier must stay distinct.
  expect_false(identical(
    .variation_provenance_read_key(1L, "VariO:0017", 1L),
    .variation_provenance_read_key(2L, "VariO:0017", 1L)
  ))
  expect_false(identical(
    .variation_provenance_read_key(1L, "VariO:0017", 1L),
    .variation_provenance_read_key(1L, "VariO:0015", 1L)
  ))
  expect_false(identical(
    .variation_provenance_read_key(1L, "VariO:0017", 1L),
    .variation_provenance_read_key(1L, "VariO:0017", 5L)
  ))
  # Large round entity_id must not go through as.character() (would give
  # "1e+05" for a double and silently split the join).
  expect_identical(
    .variation_provenance_read_key(100000, "VariO:0017", 1L),
    .variation_provenance_read_key(100000L, "VariO:0017", 1L)
  )
  # Zero-length in, zero-length out -- what keeps provenance = NULL working.
  expect_identical(
    .variation_provenance_read_key(NULL, NULL, NULL),
    character(0)
  )
})

test_that("large round entity_id values still match across double/integer (defensive normalization)", {
  # A broader footgun found while empirically checking the claim above:
  # paste(100000, "x") renders "1e+05" for a *double* but paste(100000L, "x")
  # renders "100000" for an *integer* -- a real risk if terms$entity_id ever
  # arrives as a double (e.g. after a JSON round-trip) while
  # provenance$entity_id is an integer straight from DBI. The implementation
  # explicitly coerces entity_id/modifier_id to integer before building the
  # join key to close this off; this test locks that decision.
  terms_round <- tibble::tibble(
    entity_id = 100000, vario_id = "VariO:0050",
    vario_name = "round number", modifier_id = 1
  )
  provenance_round <- tibble::tibble(
    entity_id = 100000L, vario_id = "VariO:0050", modifier_id = 1L,
    state = "confirmed", source_type = "literature", source_key = "s",
    evidence_strength = 2L, evidence_summary = "ok"
  )

  expect_false(identical(paste(100000, "x"), paste(100000L, "x"))) # the footgun, confirmed
  out <- attach_provenance(terms_round, provenance_round)
  expect_false(is.null(out$provenance[[1]]))
})
