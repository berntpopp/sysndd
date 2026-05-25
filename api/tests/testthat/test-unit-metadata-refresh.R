library(testthat)
library(mockery)

source_api_file("functions/metadata-refresh.R", local = FALSE)

describe("metadata_with_foreign_key_checks_disabled", {
  it("restores foreign key checks when the callback errors", {
    mock_conn <- structure(list(), class = "MockConnection")
    statements <- character()

    local_mocked_bindings(
      dbExecute = function(conn, statement, ...) {
        statements <<- c(statements, statement)
        1L
      },
      .package = "DBI"
    )

    expect_error(
      metadata_with_foreign_key_checks_disabled(mock_conn, function() {
        stop("simulated refresh failure", call. = FALSE)
      }),
      "simulated refresh failure"
    )

    expect_equal(
      statements,
      c("SET FOREIGN_KEY_CHECKS = 0", "SET FOREIGN_KEY_CHECKS = 1")
    )
  })

  it("restores foreign key checks after a successful callback", {
    mock_conn <- structure(list(), class = "MockConnection")
    statements <- character()

    local_mocked_bindings(
      dbExecute = function(conn, statement, ...) {
        statements <<- c(statements, statement)
        1L
      },
      .package = "DBI"
    )

    result <- metadata_with_foreign_key_checks_disabled(mock_conn, function() "ok")

    expect_equal(result, "ok")
    expect_equal(
      statements,
      c("SET FOREIGN_KEY_CHECKS = 0", "SET FOREIGN_KEY_CHECKS = 1")
    )
  })

  it("surfaces success-path foreign key restoration failures", {
    mock_conn <- structure(list(), class = "MockConnection")
    call_count <- 0L

    local_mocked_bindings(
      dbExecute = function(conn, statement, ...) {
        call_count <<- call_count + 1L
        if (identical(statement, "SET FOREIGN_KEY_CHECKS = 1")) {
          stop("restore failed", call. = FALSE)
        }
        1L
      },
      .package = "DBI"
    )

    expect_error(
      suppressWarnings(metadata_with_foreign_key_checks_disabled(mock_conn, function() "ok")),
      "Failed to restore FOREIGN_KEY_CHECKS"
    )
    expect_true(call_count >= 2L)
  })
})

describe("refresh_disease_ontology_set", {
  it("deletes and inserts ontology rows in a transaction without TRUNCATE", {
    mock_conn <- structure(list(), class = "MockConnection")
    state <- new.env(parent = emptyenv())
    state$statements <- character()
    state$params <- list()
    state$appends <- list()
    state$transaction_used <- FALSE

    local_mocked_bindings(
      dbExecute = function(conn, statement, params = NULL, ...) {
        state$statements <- c(state$statements, statement)
        if (!is.null(params)) {
          state$params <- c(state$params, list(params))
        }
        1L
      },
      dbWithTransaction = function(conn, code) {
        state$transaction_used <- TRUE
        force(code)
      },
      dbAppendTable = function(conn, name, value, ...) {
        state$appends <- c(state$appends, list(list(name = name, rows = nrow(value))))
        TRUE
      },
      .package = "DBI"
    )

    update_rows <- tibble::tibble(
      disease_ontology_id_version = "OMIM:100001",
      disease_ontology_id = "OMIM:100001",
      disease_ontology_name = "Updated disease",
      disease_ontology_source = "mim2gene",
      disease_ontology_date = as.POSIXct("2026-05-25", tz = "UTC"),
      disease_ontology_is_specific = TRUE,
      hgnc_id = "HGNC:1",
      hpo_mode_of_inheritance_term = "HP:0000006",
      is_active = TRUE
    )
    compatibility_rows <- dplyr::mutate(update_rows, disease_ontology_id_version = "OMIM:000001", is_active = FALSE)
    auto_fixes <- tibble::tibble(old_version = "OMIM:000001", new_version = "OMIM:100001")

    result <- refresh_disease_ontology_set(
      conn = mock_conn,
      disease_ontology_set_update = update_rows,
      auto_fixes = auto_fixes,
      compatibility_rows = compatibility_rows
    )

    expect_true(state$transaction_used)
    expect_true(any(grepl("^DELETE FROM disease_ontology_set$", state$statements)))
    expect_false(any(grepl("\\bTRUNCATE\\b", state$statements, ignore.case = TRUE)))
    expect_equal(vapply(state$appends, `[[`, character(1), "name"), c("disease_ontology_set", "disease_ontology_set"))
    expect_equal(vapply(state$appends, `[[`, integer(1), "rows"), c(1L, 1L))
    expect_equal(result$auto_fixes_applied, 1L)
    expect_equal(result$compatibility_rows, 1L)
    expect_equal(state$params[[1]], list("OMIM:100001", "OMIM:000001"))
  })

  it("rolls back real database rows when an auto-fix update fails", {
    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      required_tables <- c(
        "user",
        "mode_of_inheritance_list",
        "non_alt_loci_set",
        "disease_ontology_set",
        "ndd_entity"
      )
      missing_tables <- required_tables[
        !vapply(required_tables, DBI::dbExistsTable, logical(1), conn = conn)
      ]
      if (length(missing_tables) > 0) {
        skip(paste(
          "Test database schema is not initialized; missing table(s):",
          paste(missing_tables, collapse = ", ")
        ))
      }

      suffix <- as.integer(Sys.time()) %% 100000L
      user_id <- 900000L + suffix
      hgnc_id <- paste0("HGNC:", 9000L + suffix %% 500L)
      old_version <- paste0("OMIM:", 970000L + suffix %% 500L)
      keep_version <- paste0("OMIM:", 980000L + suffix %% 500L)
      new_version <- paste0("OMIM:", 990000L + suffix %% 500L)
      bad_version <- paste0("OMIM:", paste(rep("9", 40), collapse = ""))
      user_name <- paste0("metadata_refresh_", suffix)

      DBI::dbExecute(
        conn,
        "INSERT INTO user (user_id, user_name) VALUES (?, ?)",
        params = unname(list(user_id, user_name))
      )

      DBI::dbExecute(
        conn,
        "INSERT IGNORE INTO mode_of_inheritance_list (hpo_mode_of_inheritance_term) VALUES ('HP:0000006')"
      )
      DBI::dbExecute(
        conn,
        "INSERT INTO non_alt_loci_set (hgnc_id, symbol) VALUES (?, ?)",
        params = unname(list(hgnc_id, paste0("MR", suffix)))
      )
      DBI::dbAppendTable(
        conn,
        "disease_ontology_set",
        tibble::tibble(
          disease_ontology_id_version = c(old_version, keep_version),
          disease_ontology_id = c(old_version, keep_version),
          disease_ontology_name = c("Original old disease", "Original keep disease"),
          disease_ontology_source = "test",
          disease_ontology_date = as.POSIXct("2026-05-25", tz = "UTC"),
          disease_ontology_is_specific = TRUE,
          hgnc_id = hgnc_id,
          hpo_mode_of_inheritance_term = "HP:0000006",
          is_active = TRUE
        )
      )
      DBI::dbExecute(
        conn,
        paste(
          "INSERT INTO ndd_entity",
          "(hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version,",
          "ndd_phenotype, entry_user_id, is_active)",
          "VALUES (?, 'HP:0000006', ?, 1, ?, 1)"
        ),
        params = unname(list(hgnc_id, old_version, user_id))
      )

      update_rows <- tibble::tibble(
        disease_ontology_id_version = new_version,
        disease_ontology_id = new_version,
        disease_ontology_name = "Replacement disease",
        disease_ontology_source = "test",
        disease_ontology_date = as.POSIXct("2026-05-25", tz = "UTC"),
        disease_ontology_is_specific = TRUE,
        hgnc_id = hgnc_id,
        hpo_mode_of_inheritance_term = "HP:0000006",
        is_active = TRUE
      )
      auto_fixes <- tibble::tibble(old_version = old_version, new_version = bad_version)

      expect_error(
        refresh_disease_ontology_set(
          conn = conn,
          disease_ontology_set_update = update_rows,
          auto_fixes = auto_fixes
        ),
        "Data too long|too long|1406"
      )

      remaining <- DBI::dbGetQuery(
        conn,
        paste(
          "SELECT disease_ontology_id_version",
          "FROM disease_ontology_set",
          "WHERE disease_ontology_id_version IN (?, ?)",
          "ORDER BY disease_ontology_id_version"
        ),
        params = unname(list(old_version, keep_version))
      )
      expect_equal(remaining$disease_ontology_id_version, sort(c(old_version, keep_version)))

      fk_checks <- DBI::dbGetQuery(conn, "SELECT @@FOREIGN_KEY_CHECKS AS fk_checks")
      expect_equal(as.integer(fk_checks$fk_checks[[1]]), 1L)
    })
  })
})
