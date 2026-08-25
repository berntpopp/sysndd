# api/tests/testthat/test-integration-variation-suggestions.R
#
# #612 Phase 6: the curation queue, against a REAL schema.
#
# The unit tests in test-unit-curate-variation-suggestions.R mock
# db_execute_query, so they assert the SQL's TEXT and never execute it. That is
# not enough for this surface: the query joins a view, derives two EXISTS flags,
# and pages over a grouped derived table, and its first draft bound every filter
# twice -- valid-looking text that a real driver rejects with "Number of params
# don't match" the moment it runs. This file executes it.
#
# Requires a schema-loaded database. CI applies the migrations
# (api/scripts/ci-load-test-schema.R); locally, see AGENTS.md.

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/variation-provenance-repository.R", local = FALSE)
source_api_file("services/entity-variation-provenance-service.R", local = FALSE)
source_api_file("services/curate-variation-suggestion-service.R", local = FALSE)

cvs_required_tables <- c(
  "variation_ontology_assertion", "variation_ontology_evidence",
  "ndd_review_variation_ontology_connect", "ndd_entity_review",
  "ndd_entity", "ndd_entity_view", "variation_ontology_list", "modifier_list"
)

skip_if_missing_cvs_schema <- function(conn) {
  missing <- cvs_required_tables[
    !vapply(cvs_required_tables, function(x) DBI::dbExistsTable(conn, x), logical(1))
  ]
  if (length(missing) > 0L) {
    skip(paste("curation-queue schema missing:", paste(missing, collapse = ", ")))
  }
}

#' Seed one entity that `ndd_entity_view` will actually resolve.
#'
#' The view inner-joins non_alt_loci_set, disease_ontology_set,
#' mode_of_inheritance_list, boolean_list and the approved-status view, so an
#' entity is INVISIBLE to the queue unless every one of those rows exists. That
#' is the point: the queue must be unable to show a non-public entity.
cvs_seed <- function(conn, marker, symbol = NULL) {
  user_id <- as.integer(986000L + marker)
  entity_id <- as.integer(736000L + marker)
  # hgnc_id is varchar(10), so the id has to fit in ten characters.
  hgnc_id <- sprintf("HGNC:%05d", 90000L + marker)
  symbol <- symbol %||% sprintf("CVSGENE%d", marker)
  disease_version <- sprintf("OMIM:%06d_1", 800000L + marker)
  vario_id <- sprintf("VariO:%04d", 6000L + (marker %% 1000L))
  inheritance <- sprintf("HP:%07d", 100000L + marker)

  DBI::dbExecute(conn, "INSERT IGNORE INTO `user` (user_id, user_name) VALUES (?, ?)",
                 params = list(user_id, sprintf("cvs-user-%d", marker)))
  # boolean_list is seeded by the base schema and its PRIMARY KEY is boolean_id,
  # not `logical` -- inserting here adds a SECOND row with logical = 1, which
  # makes ndd_entity_view emit two rows per entity and silently doubles every
  # evidence list this file asserts on.
  DBI::dbExecute(conn, "INSERT IGNORE INTO non_alt_loci_set (hgnc_id, symbol) VALUES (?, ?)",
                 params = list(hgnc_id, symbol))
  DBI::dbExecute(
    conn,
    "INSERT IGNORE INTO disease_ontology_set
       (disease_ontology_id_version, disease_ontology_id, disease_ontology_name, is_active)
     VALUES (?, ?, ?, 1)",
    params = list(disease_version, sprintf("OMIM:%06d", 800000L + marker),
                  sprintf("CVS disorder %d", marker))
  )
  DBI::dbExecute(
    conn,
    "INSERT IGNORE INTO mode_of_inheritance_list
       (hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name, inheritance_filter)
     VALUES (?, ?, ?)",
    params = list(inheritance, "Autosomal dominant inheritance", "Dominant")
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_entity
       (entity_id, hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version,
        ndd_phenotype, entry_user_id, is_active)
     VALUES (?, ?, ?, ?, 1, ?, 1)",
    params = list(entity_id, hgnc_id, inheritance, disease_version, user_id)
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_entity_status
       (entity_id, category_id, is_active, status_user_id, status_approved)
     VALUES (?, 1, 1, ?, 1)",
    params = list(entity_id, user_id)
  )
  DBI::dbExecute(conn, "INSERT IGNORE INTO variation_ontology_list (vario_id, vario_name)
                        VALUES (?, ?)",
                 params = list(vario_id, sprintf("cvs term %d", marker)))
  DBI::dbExecute(conn, "INSERT IGNORE INTO modifier_list (modifier_id) VALUES (1)")
  DBI::dbExecute(conn, "INSERT IGNORE INTO modifier_list (modifier_id) VALUES (5)")

  list(user_id = user_id, entity_id = entity_id, symbol = symbol, vario_id = vario_id)
}

cvs_seed_review <- function(conn, fixture, is_primary = 1L, approved = 1L) {
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_entity_review
       (entity_id, synopsis, review_user_id, review_approved, approving_user_id, is_primary)
     VALUES (?, 'cvs', ?, ?, ?, ?)",
    params = list(fixture$entity_id, fixture$user_id, approved, fixture$user_id, is_primary)
  )
  as.integer(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1L]])
}

cvs_seed_connect <- function(conn, fixture, review_id, modifier_id = 1L) {
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_review_variation_ontology_connect
       (review_id, entity_id, vario_id, modifier_id, is_active)
     VALUES (?, ?, ?, ?, 1)",
    params = list(review_id, fixture$entity_id, fixture$vario_id, as.integer(modifier_id))
  )
}

cvs_seed_assertion <- function(conn, fixture, state = "active_unconfirmed", modifier_id = 1L) {
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_assertion (entity_id, vario_id, modifier_id, state)
     VALUES (?, ?, ?, ?)",
    params = list(fixture$entity_id, fixture$vario_id, as.integer(modifier_id), state)
  )
  as.integer(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1L]])
}

cvs_seed_evidence <- function(conn, assertion_id, source_key = "clinvar",
                              source_type = "external_database", strength = 2L,
                              origin_review_id = NA_integer_,
                              summary = "10 ClinVar records, max 2 stars") {
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_evidence
       (assertion_id, source_type, source_key, batch_id, evidence_summary,
        evidence_strength, evidence_json, origin_review_id)
     VALUES (?, ?, ?, ?, ?, ?, '{\"records\":[]}', ?)",
    params = list(as.integer(assertion_id), source_type, source_key,
                  paste0(source_key, "-2026-02"), summary,
                  as.integer(strength), origin_review_id)
  )
}

cvs_query <- function(conn, ...) {
  svc_curate_variation_suggestions(
    svc_curate_variation_suggestion_params(...), pool = conn
  )
}

cvs_rows_for <- function(result, entity_id) {
  Filter(function(row) identical(row$entity_id, as.integer(entity_id)), result$data)
}


test_that("every filter combination is valid SQL against the real schema", {
  # The first draft of this query bound each filter twice and read perfectly.
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    combos <- list(
      list(),
      list(state = "active_unconfirmed"),
      list(state = "suggested", sort = "strength_asc"),
      list(source_key = "clinvar"),
      list(max_strength = 1L),
      list(moved = "true"),
      list(q = "CHD8"),
      list(q = "42"),
      list(sort = "entity_asc", page = 2L, page_size = 10L),
      list(state = "active_unconfirmed", source_key = "clinvar", max_strength = 1L,
           moved = "true", q = "CHD8", sort = "strength_desc", page = 1L, page_size = 100L)
    )
    for (combo in combos) {
      result <- do.call(cvs_query, c(list(conn = conn), combo))
      expect_type(result$meta$total, "integer")
      expect_type(result$data, "list")
    }
  })
})

test_that("a served, unconfirmed assertion is listed with its evidence", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 11L)
    review_id <- cvs_seed_review(conn, fixture)
    cvs_seed_connect(conn, fixture, review_id)
    assertion_id <- cvs_seed_assertion(conn, fixture, "active_unconfirmed")
    cvs_seed_evidence(conn, assertion_id, origin_review_id = review_id)

    rows <- cvs_rows_for(cvs_query(conn, q = fixture$symbol), fixture$entity_id)
    expect_length(rows, 1L)
    row <- rows[[1L]]
    expect_equal(row$vario_id, fixture$vario_id)
    expect_equal(row$modifier_id, 1L)
    expect_equal(row$state, "active_unconfirmed")
    expect_true(row$served)
    # origin_review_id IS the current primary approved review, so nothing moved.
    expect_false(row$moved)
    expect_equal(row$max_strength, 2L)
    expect_length(row$evidence, 1L)
    expect_equal(row$evidence[[1L]]$source_key, "clinvar")
    expect_equal(row$symbol, fixture$symbol)
  })
})

test_that("`served` is FALSE when the connect row hangs off an unapproved review", {
  # The whole Confirm/Dismiss asymmetry rests on this flag being the same rule
  # the public entity card uses.
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 12L)
    draft_id <- cvs_seed_review(conn, fixture, is_primary = 0L, approved = 0L)
    cvs_seed_connect(conn, fixture, draft_id)
    assertion_id <- cvs_seed_assertion(conn, fixture, "suggested")
    cvs_seed_evidence(conn, assertion_id, source_key = "synopsis",
                      source_type = "literature", strength = 1L)

    row <- cvs_rows_for(cvs_query(conn, q = fixture$symbol), fixture$entity_id)[[1L]]
    expect_false(row$served)
    expect_equal(row$state, "suggested")
  })
})

test_that("`moved` is TRUE when the import's review no longer serves the term", {
  # The 95-row laundered set in production. origin_review_id (migration 049) has
  # no foreign key, so a superseded OR vanished origin review both read as moved.
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 13L)
    import_review <- cvs_seed_review(conn, fixture, is_primary = 0L, approved = 1L)
    current_review <- cvs_seed_review(conn, fixture, is_primary = 1L, approved = 1L)
    cvs_seed_connect(conn, fixture, current_review)
    assertion_id <- cvs_seed_assertion(conn, fixture, "active_unconfirmed")
    cvs_seed_evidence(conn, assertion_id, origin_review_id = import_review)

    row <- cvs_rows_for(cvs_query(conn, q = fixture$symbol), fixture$entity_id)[[1L]]
    expect_true(row$moved)
    expect_true(row$served)

    # ...and the facet actually narrows to it.
    moved_only <- cvs_rows_for(
      cvs_query(conn, q = fixture$symbol, moved = "true"), fixture$entity_id
    )
    expect_length(moved_only, 1L)
  })
})

test_that("a confirmed or rejected assertion never appears in the queue", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 14L)
    review_id <- cvs_seed_review(conn, fixture)
    cvs_seed_connect(conn, fixture, review_id)
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_assertion
         (entity_id, vario_id, modifier_id, state, confirmed_by, confirmed_at)
       VALUES (?, ?, 1, 'confirmed', ?, NOW())",
      params = list(fixture$entity_id, fixture$vario_id, fixture$user_id)
    )
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_assertion (entity_id, vario_id, modifier_id, state)
       VALUES (?, ?, 5, 'rejected')",
      params = list(fixture$entity_id, fixture$vario_id)
    )

    expect_length(cvs_rows_for(cvs_query(conn, q = fixture$symbol), fixture$entity_id), 0L)
  })
})

test_that("present and absent are independent rows in the queue", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 15L)
    review_id <- cvs_seed_review(conn, fixture)
    cvs_seed_connect(conn, fixture, review_id, modifier_id = 1L)
    present <- cvs_seed_assertion(conn, fixture, "active_unconfirmed", modifier_id = 1L)
    absent <- cvs_seed_assertion(conn, fixture, "active_unconfirmed", modifier_id = 5L)
    cvs_seed_evidence(conn, present)
    cvs_seed_evidence(conn, absent, strength = 4L)

    rows <- cvs_rows_for(cvs_query(conn, q = fixture$symbol), fixture$entity_id)
    expect_length(rows, 2L)
    by_modifier <- setNames(rows, vapply(rows, function(r) as.character(r$modifier_id),
                                         character(1)))
    # Only the `present` half has a connect row, so only it is served.
    expect_true(by_modifier[["1"]]$served)
    expect_false(by_modifier[["5"]]$served)
  })
})

test_that("the state, source and strength facets each narrow the page", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 16L)
    strong <- cvs_seed_assertion(conn, fixture, "active_unconfirmed", modifier_id = 1L)
    weak <- cvs_seed_assertion(conn, fixture, "suggested", modifier_id = 5L)
    cvs_seed_evidence(conn, strong, source_key = "clinvar", strength = 4L)
    cvs_seed_evidence(conn, weak, source_key = "synopsis",
                      source_type = "literature", strength = 1L)

    all_rows <- cvs_rows_for(cvs_query(conn, q = fixture$symbol), fixture$entity_id)
    expect_length(all_rows, 2L)

    expect_length(
      cvs_rows_for(cvs_query(conn, q = fixture$symbol, state = "suggested"),
                   fixture$entity_id),
      1L
    )
    expect_length(
      cvs_rows_for(cvs_query(conn, q = fixture$symbol, source_key = "clinvar"),
                   fixture$entity_id),
      1L
    )
    expect_length(
      cvs_rows_for(cvs_query(conn, q = fixture$symbol, max_strength = 1L),
                   fixture$entity_id),
      1L
    )
  })
})

test_that("strength sorting puts the strongest first and the weakest first, on request", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 17L)
    strong <- cvs_seed_assertion(conn, fixture, "active_unconfirmed", modifier_id = 1L)
    weak <- cvs_seed_assertion(conn, fixture, "active_unconfirmed", modifier_id = 5L)
    cvs_seed_evidence(conn, strong, strength = 4L)
    cvs_seed_evidence(conn, weak, strength = 1L)

    desc <- cvs_rows_for(cvs_query(conn, q = fixture$symbol, sort = "strength_desc"),
                         fixture$entity_id)
    expect_equal(vapply(desc, function(r) r$max_strength, integer(1)), c(4L, 1L))

    asc <- cvs_rows_for(cvs_query(conn, q = fixture$symbol, sort = "strength_asc"),
                        fixture$entity_id)
    expect_equal(vapply(asc, function(r) r$max_strength, integer(1)), c(1L, 4L))
  })
})

test_that("an assertion with no evidence sorts LAST, never first, in weakest-first order", {
  # `null` strength means NOT RECORDED. Floating those to the top of "weakest
  # first" would put the least informative rows in front of the weak-evidence
  # backlog the queue exists to work through.
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 18L)
    scored <- cvs_seed_assertion(conn, fixture, "active_unconfirmed", modifier_id = 1L)
    cvs_seed_evidence(conn, scored, strength = 2L)
    cvs_seed_assertion(conn, fixture, "active_unconfirmed", modifier_id = 5L)

    asc <- cvs_rows_for(cvs_query(conn, q = fixture$symbol, sort = "strength_asc"),
                        fixture$entity_id)
    expect_length(asc, 2L)
    expect_equal(asc[[1L]]$max_strength, 2L)
    expect_null(asc[[2L]]$max_strength)
    expect_length(asc[[2L]]$evidence, 0L)
  })
})

test_that("paging is over assertions and the total counts assertions, not evidence rows", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 19L)
    assertion_id <- cvs_seed_assertion(conn, fixture, "active_unconfirmed")
    # Two evidence rows on ONE assertion: the count must still be 1.
    cvs_seed_evidence(conn, assertion_id, source_key = "clinvar", strength = 2L)
    cvs_seed_evidence(conn, assertion_id, source_key = "synopsis",
                      source_type = "literature", strength = 3L)

    result <- cvs_query(conn, q = fixture$symbol)
    expect_equal(result$meta$total, 1L)
    expect_length(result$data, 1L)
    expect_length(result$data[[1L]]$evidence, 2L)
    # Strongest evidence first within the row.
    expect_equal(result$data[[1L]]$evidence[[1L]]$source_key, "synopsis")
    expect_equal(result$data[[1L]]$max_strength, 3L)
  })
})

test_that("an entity that ndd_entity_view does not resolve can never reach the queue", {
  # Entity visibility is enforced INSIDE the statement, so a deactivated or
  # otherwise non-public entity is invisible rather than filtered afterwards.
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_cvs_schema(conn)

    fixture <- cvs_seed(conn, 20L)
    cvs_seed_assertion(conn, fixture, "active_unconfirmed")
    expect_length(cvs_rows_for(cvs_query(conn, q = fixture$symbol), fixture$entity_id), 1L)

    # Remove the approved status the view inner-joins on.
    DBI::dbExecute(conn, "UPDATE ndd_entity_status SET status_approved = 0 WHERE entity_id = ?",
                   params = list(fixture$entity_id))
    expect_length(cvs_rows_for(cvs_query(conn, q = fixture$symbol), fixture$entity_id), 0L)
  })
})
