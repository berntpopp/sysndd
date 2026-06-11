# tests/testthat/test-integration-metadata-vocabulary.R
#
# DB-writing integration tests for the Admin metadata vocabulary CRUD service
# (issue #32). These exercise the repository + service against the real test
# database and are wrapped in with_test_db_transaction() so every change is
# rolled back. They skip automatically when no test DB is configured (host).
#
# Migration 033 adds the is_active / sort columns these tests rely on, so the
# test schema must include it.

library(testthat)
library(tibble)

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/metadata-vocabulary-repository.R", local = FALSE)
source_api_file("services/metadata-vocabulary-service.R", local = FALSE)

modifier_descriptor <- metadata_vocabulary_descriptor("modifier")
status_descriptor <- metadata_vocabulary_descriptor("status_category")

# The CI test database starts minimal — tests create only the schema they need
# rather than loading the full application schema (see helper-db.R). These
# vocabulary + reference tables come from the base migration; skip when they are
# not present so the suite stays green on a minimal DB and runs fully against a
# complete one (mirrors skip_if_missing_entity_rename_schema).
skip_if_missing_metadata_vocab_schema <- function() {
  conn <- tryCatch(get_test_db_connection(), error = function(e) NULL)
  if (is.null(conn)) {
    return(invisible(FALSE))
  }
  on.exit(DBI::dbDisconnect(conn), add = TRUE)
  required_tables <- c(
    "modifier_list",
    "ndd_entity_status_categories_list",
    "mode_of_inheritance_list",
    "variation_ontology_list",
    "ndd_review_phenotype_connect",
    "ndd_review_variation_ontology_connect",
    "ndd_entity_status"
  )
  missing_tables <- required_tables[!vapply(
    required_tables,
    function(table) DBI::dbExistsTable(conn, table),
    logical(1)
  )]
  if (length(missing_tables) > 0) {
    testthat::skip(paste0(
      "metadata vocabulary schema not present in test DB (missing: ",
      paste(missing_tables, collapse = ", "), ")"
    ))
  }
  invisible(TRUE)
}

test_that("modifier round-trip: create, update, soft-delete unused value", {
  skip_if_missing_metadata_vocab_schema()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    created <- svc_metadata_create(
      "modifier",
      list(modifier_name = "tmpmod", allowed_phenotype = 1, allowed_variation = 0),
      pool = conn
    )
    expect_equal(created$status, 201)
    new_id <- created$entry$pk

    fetched <- metadata_vocabulary_get(modifier_descriptor, new_id, conn = conn)
    expect_equal(nrow(fetched), 1)
    expect_equal(fetched$modifier_name, "tmpmod")
    expect_equal(as.integer(fetched$is_active), 1L)

    updated <- svc_metadata_update(
      "modifier", as.character(new_id),
      list(modifier_name = "tmpmod2"), pool = conn
    )
    expect_equal(updated$status, 200)
    refetched <- metadata_vocabulary_get(modifier_descriptor, new_id, conn = conn)
    expect_equal(refetched$modifier_name, "tmpmod2")

    # Unused value soft-deletes (is_active -> 0)
    deleted <- svc_metadata_delete("modifier", as.character(new_id), pool = conn)
    expect_equal(deleted$status, 200)
    after <- metadata_vocabulary_get(modifier_descriptor, new_id, conn = conn)
    expect_equal(as.integer(after$is_active), 0L)
  })
})

test_that("status category in-use delete is blocked with a 400", {
  skip_if_missing_metadata_vocab_schema()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    created <- svc_metadata_create(
      "status_category", list(category = "tmpcat"), pool = conn
    )
    new_id <- created$entry$pk

    # Reference the new category from ndd_entity_status so the guard trips.
    DBI::dbExecute(
      conn,
      sprintf(
        "INSERT INTO ndd_entity_status (entity_id, category_id, is_active, status_user_id)
         VALUES (999999, %d, 1, 1)",
        new_id
      )
    )

    usage <- metadata_vocabulary_usage_count(status_descriptor, new_id, conn = conn)
    expect_gte(usage, 1L)

    expect_error(
      svc_metadata_delete("status_category", as.character(new_id), pool = conn),
      class = "error_400"
    )
  })
})

test_that("anchored inheritance vocabulary lists and updates curated fields", {
  skip_if_missing_metadata_vocab_schema()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    listed <- svc_metadata_list("inheritance", pool = conn)
    expect_true("data" %in% names(listed))
    expect_identical(listed$meta$editable, "anchored")

    # Pick any existing inheritance term to edit its curated short text.
    rows <- metadata_vocabulary_list(
      metadata_vocabulary_descriptor("inheritance"), conn = conn
    )
    skip_if(nrow(rows) == 0, "no inheritance terms seeded in test DB")
    term <- rows$hpo_mode_of_inheritance_term[[1]]

    updated <- svc_metadata_update(
      "inheritance", term,
      list(inheritance_short_text = "ZZ"), pool = conn
    )
    expect_equal(updated$status, 200)

    # Anchored vocabularies must reject create + delete.
    expect_error(
      svc_metadata_create(
        "inheritance",
        list(hpo_mode_of_inheritance_term_name = "X"), pool = conn
      ),
      class = "error_400"
    )
    expect_error(
      svc_metadata_delete("inheritance", term, pool = conn),
      class = "error_400"
    )
  })
})
