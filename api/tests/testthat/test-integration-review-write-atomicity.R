# Real-RMariaDB regression coverage for the review-save transaction boundary.
#
# The fixture DDL deliberately runs on its own connection: MySQL DDL commits
# implicitly, while each test below uses with_test_db_transaction() and passes
# its caller-owned connection to svc_review_write().

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)
source_api_file("functions/db-transaction-scope.R", local = FALSE)
source_api_file("functions/variation-provenance-approval.R", local = FALSE)
source_api_file("services/approval-service.R", local = FALSE)
source_api_file("functions/publication-write-preparation.R", local = FALSE)
if (!exists("genereviews_from_pmid", mode = "function")) {
  genereviews_from_pmid <- function(...) FALSE
}
source_api_file("functions/review-repository.R", local = FALSE)
source_api_file("functions/publication-repository.R", local = FALSE)
source_api_file("functions/phenotype-repository.R", local = FALSE)
source_api_file("functions/ontology-repository.R", local = FALSE)
source_api_file("functions/re-review-sync.R", local = FALSE)
source_api_file("functions/variation-provenance-reconcile.R", local = FALSE)

review_write_service_path <- file.path(
  get_api_dir(), "services", "review-write-service.R"
)
if (file.exists(review_write_service_path)) {
  source_api_file("services/review-write-service.R", local = FALSE)
}

ensure_review_write_atomicity_schema <- function() {
  conn <- get_test_db_connection()
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  ensure_test_user_table(conn)

  statements <- c(
    "CREATE TABLE IF NOT EXISTS ndd_entity (
      entity_id INT NOT NULL PRIMARY KEY,
      entry_user_id INT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS ndd_entity_review (
      review_id INT NOT NULL AUTO_INCREMENT,
      entity_id INT DEFAULT NULL,
      synopsis TEXT DEFAULT NULL,
      review_user_id INT NOT NULL,
      review_date TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
      comment TEXT DEFAULT NULL,
      review_approved TINYINT DEFAULT 0,
      approving_user_id INT DEFAULT NULL,
      is_primary TINYINT DEFAULT 0,
      PRIMARY KEY (review_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS publication (
      publication_id VARCHAR(15) NOT NULL PRIMARY KEY,
      publication_type VARCHAR(50) DEFAULT NULL,
      update_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS phenotype_list (
      phenotype_id VARCHAR(10) NOT NULL PRIMARY KEY
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS variation_ontology_list (
      vario_id VARCHAR(10) NOT NULL PRIMARY KEY
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS modifier_list (
      modifier_id INT NOT NULL PRIMARY KEY
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS ndd_review_publication_join (
      review_publication_id INT NOT NULL AUTO_INCREMENT,
      review_id INT DEFAULT NULL,
      entity_id INT DEFAULT NULL,
      publication_id VARCHAR(15) DEFAULT NULL,
      publication_type VARCHAR(50) DEFAULT NULL,
      is_reviewed TINYINT DEFAULT 1,
      PRIMARY KEY (review_publication_id),
      UNIQUE KEY review_triple (review_id, entity_id, publication_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS ndd_review_phenotype_connect (
      review_phenotype_id INT NOT NULL AUTO_INCREMENT,
      review_id INT DEFAULT NULL,
      phenotype_id VARCHAR(10) DEFAULT NULL,
      modifier_id DOUBLE DEFAULT 1,
      entity_id INT DEFAULT NULL,
      is_active TINYINT DEFAULT 1,
      PRIMARY KEY (review_phenotype_id),
      UNIQUE KEY phenotype_quintuple (review_id, phenotype_id, modifier_id, entity_id, is_active)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS ndd_review_variation_ontology_connect (
      review_vario_id INT NOT NULL AUTO_INCREMENT,
      review_id INT DEFAULT NULL,
      vario_id VARCHAR(10) DEFAULT NULL,
      modifier_id INT DEFAULT NULL,
      entity_id INT DEFAULT NULL,
      is_active TINYINT DEFAULT 1,
      PRIMARY KEY (review_vario_id),
      UNIQUE KEY variation_quintuple (review_id, vario_id, modifier_id, entity_id, is_active)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS re_review_entity_connect (
      re_review_entity_id INT NOT NULL AUTO_INCREMENT,
      entity_id INT DEFAULT NULL,
      re_review_review_saved TINYINT DEFAULT NULL,
      review_id INT DEFAULT NULL,
      PRIMARY KEY (re_review_entity_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
  )

  for (statement in statements) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  ensure_review_write_provenance_tables(conn)

  invisible(TRUE)
}

# The two provenance tables (#608) are created by APPLYING MIGRATION 047 rather
# than by a hand-written `CREATE TABLE IF NOT EXISTS` pair.
#
# Rationale (a deliberate deviation from the brief's "matching migration 047's
# shape"): this file and test-unit-variation-provenance-migration.R share one
# test database, and that file DROPS both tables at the end of its run so its
# own information_schema-guarded CREATEs stay idempotent. Whichever file runs
# first therefore creates the tables the other one sees. A hand-copied fixture
# shape would silently diverge from the migration (most importantly the
# chk_confirmed_attribution CHECK and the uq_assertion UNIQUE key that the
# migration test asserts on), so the only safe fixture is the migration itself.
# The migration's CREATEs are guarded on an information_schema existence count,
# which makes this exactly as idempotent as CREATE TABLE IF NOT EXISTS.
#
# FKs are kept: migration 047's four FK targets (`ndd_entity`,
# `variation_ontology_list`, `modifier_list`, `user`) are all created above /
# by ensure_test_user_table(), each with the referenced column as its primary
# key, so the FKs are creatable against this fixture and the seed below
# satisfies them. Note the FK targets must exist BEFORE this runs, which is why
# it is called after the statement loop.
ensure_review_write_provenance_tables <- function(conn) {
  if (!exists("split_sql_statements", mode = "function")) {
    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
  }

  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", "047_add_variation_ontology_provenance.sql"),
    file.path(get_api_dir(), "db", "migrations", "047_add_variation_ontology_provenance.sql")
  )
  migration_path <- candidates[file.exists(candidates)]
  if (length(migration_path) == 0L) {
    stop("variation-ontology-provenance migration file is missing: ", candidates[[1L]])
  }

  sql <- paste(readLines(migration_path[[1L]], warn = FALSE), collapse = "\n")
  for (statement in split_sql_statements(sql)) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  invisible(TRUE)
}

review_write_insert_entity <- function(conn, entity_id, user_id) {
  fields <- DBI::dbListFields(conn, "ndd_entity")
  cols <- "entity_id"
  params <- list(entity_id)
  if ("entry_user_id" %in% fields) {
    cols <- c(cols, "entry_user_id")
    params <- c(params, list(user_id))
  }

  sql <- sprintf(
    "INSERT INTO ndd_entity (%s) VALUES (%s)",
    paste(cols, collapse = ", "),
    paste(rep("?", length(cols)), collapse = ", ")
  )
  DBI::dbExecute(conn, sql, params = params)
}

review_write_seed <- function(conn, marker) {
  user_id <- 987651L
  entity_id <- as.integer(710000L + marker)
  publication_id <- sprintf("%d", 9100000L + marker)
  phenotype_id <- sprintf("HP:%07d", marker)
  vario_id <- sprintf("VariO:%04d", marker %% 10000L)

  DBI::dbExecute(
    conn,
    "INSERT IGNORE INTO `user` (user_id, user_name) VALUES (?, ?)",
    params = list(user_id, sprintf("review-write-atomicity-%d", marker))
  )
  review_write_insert_entity(conn, entity_id, user_id)
  DBI::dbExecute(
    conn,
    "INSERT INTO publication (publication_id, publication_type) VALUES (?, ?)",
    params = list(publication_id, "additional_references")
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO phenotype_list (phenotype_id) VALUES (?)",
    params = list(phenotype_id)
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_list (vario_id) VALUES (?)",
    params = list(vario_id)
  )
  DBI::dbExecute(
    conn,
    "INSERT IGNORE INTO modifier_list (modifier_id) VALUES (1)"
  )
  # modifier 5 ('absent') is the other half of the (vario_id, modifier_id)
  # assertion identity, and variation_ontology_assertion has an FK to
  # modifier_list, so the present/absent independence test needs it seeded.
  DBI::dbExecute(
    conn,
    "INSERT IGNORE INTO modifier_list (modifier_id) VALUES (5)"
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO re_review_entity_connect (entity_id, re_review_review_saved, review_id)
     VALUES (?, 0, NULL)",
    params = list(entity_id)
  )

  list(
    user_id = user_id,
    entity_id = entity_id,
    publication_id = publication_id,
    phenotype_id = phenotype_id,
    vario_id = vario_id
  )
}

review_write_call <- function(conn, fixture, method, review_data) {
  svc_review_write(
    method = method,
    review_data = review_data,
    publications = tibble::tibble(
      publication_id = fixture$publication_id,
      publication_type = "additional_references"
    ),
    phenotypes = tibble::tibble(
      phenotype_id = rep(fixture$phenotype_id, 2L),
      modifier_id = c(1L, 1L)
    ),
    variation_ontology = tibble::tibble(
      vario_id = fixture$vario_id,
      modifier_id = 1L
    ),
    re_review = TRUE,
    direct_approval = FALSE,
    review_user_id = fixture$user_id,
    db = conn
  )
}

# --- #608 provenance-assertion fixture helpers -----------------------------

#' Seed one provenance assertion for the fixture's entity.
#'
#' Rolled back with the surrounding with_test_db_transaction() block.
review_write_seed_assertion <- function(conn, fixture, state = "active_unconfirmed",
                                       modifier_id = 1L, vario_id = NULL,
                                       confirmed_by = NULL) {
  vario_id <- if (is.null(vario_id)) fixture$vario_id else vario_id

  if (identical(state, "confirmed")) {
    # chk_confirmed_attribution: a confirmed row must carry both.
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_assertion
         (entity_id, vario_id, modifier_id, state, confirmed_by, confirmed_at)
       VALUES (?, ?, ?, ?, ?, NOW())",
      params = list(
        fixture$entity_id, vario_id, modifier_id, state,
        if (is.null(confirmed_by)) fixture$user_id else confirmed_by
      )
    )
  } else {
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_assertion
         (entity_id, vario_id, modifier_id, state)
       VALUES (?, ?, ?, ?)",
      params = list(fixture$entity_id, vario_id, modifier_id, state)
    )
  }

  as.integer(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1L]])
}

review_write_assertion_row <- function(conn, fixture, modifier_id = 1L, vario_id = NULL) {
  vario_id <- if (is.null(vario_id)) fixture$vario_id else vario_id
  DBI::dbGetQuery(
    conn,
    "SELECT assertion_id, state, confirmed_by, confirmed_at
       FROM variation_ontology_assertion
      WHERE entity_id = ? AND vario_id = ? AND modifier_id = ?",
    params = list(fixture$entity_id, vario_id, modifier_id)
  )
}

#' Successful review save, with the submitted variation-ontology payload (and
#' therefore the provenance actions) supplied by the caller.
#'
#' `direct_approval = FALSE` + `method = "POST"` is the DRAFT case: the created
#' review is neither primary nor approved, so it does not determine the entity's
#' served term set and omissions must not reject any assertion.
review_write_save <- function(conn, fixture, synopsis, variation_ontology,
                              method = "POST", mutation_fn = review_write_mutate,
                              direct_approval = FALSE, review_id = NULL) {
  review_data <- list(entity_id = fixture$entity_id, synopsis = synopsis)
  if (!is.null(review_id)) {
    review_data$review_id <- review_id
  }

  svc_review_write(
    method = method,
    review_data = review_data,
    publications = tibble::tibble(
      publication_id = fixture$publication_id,
      publication_type = "additional_references"
    ),
    phenotypes = tibble::tibble(phenotype_id = fixture$phenotype_id, modifier_id = 1L),
    variation_ontology = variation_ontology,
    re_review = FALSE,
    direct_approval = direct_approval,
    review_user_id = fixture$user_id,
    db = conn,
    mutation_fn = mutation_fn
  )
}

#' Insert an existing PRIMARY + APPROVED review for the fixture's entity.
#'
#' This is the review the public is served from, so a PUT editing it DOES
#' determine the served term set and its omissions legitimately reject.
review_write_seed_primary_approved_review <- function(conn, fixture, synopsis) {
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_entity_review
       (entity_id, synopsis, review_user_id, review_approved, approving_user_id, is_primary)
     VALUES (?, ?, ?, 1, ?, 1)",
    params = list(fixture$entity_id, synopsis, fixture$user_id, fixture$user_id)
  )
  as.integer(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1L]])
}

review_write_count <- function(conn, table, where_sql, params) {
  DBI::dbGetQuery(
    conn,
    sprintf("SELECT COUNT(*) AS n FROM %s WHERE %s", table, where_sql),
    params = params
  )$n[[1L]]
}

review_write_atomicity_db_ready <- test_db_available()
if (isTRUE(review_write_atomicity_db_ready)) {
  ensure_review_write_atomicity_schema()
}

test_that("POST review write rolls back review, publication join, ontology joins, and re-review marker when phenotype insert fails", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 101L)
    marker <- "review-write-atomicity-post"

    expect_error(
      review_write_call(
        conn,
        fixture,
        "POST",
        list(entity_id = fixture$entity_id, synopsis = marker, comment = "must roll back")
      ),
      class = "db_statement_error"
    )

    expect_equal(
      review_write_count(conn, "ndd_entity_review", "synopsis = ?", list(marker)),
      0L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_publication_join", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_phenotype_connect", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )

    marker_row <- DBI::dbGetQuery(
      conn,
      "SELECT re_review_review_saved, review_id
       FROM re_review_entity_connect WHERE entity_id = ?",
      params = list(fixture$entity_id)
    )
    expect_equal(marker_row$re_review_review_saved, 0L)
    expect_true(is.na(marker_row$review_id))
  })
})

test_that("PUT review write preserves existing review and joins when phenotype replacement fails", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 102L)
    old_synopsis <- "review-write-atomicity-put-original"
    old_comment <- "original comment"

    DBI::dbExecute(
      conn,
      "INSERT INTO ndd_entity_review (entity_id, synopsis, review_user_id, comment)
       VALUES (?, ?, ?, ?)",
      params = list(fixture$entity_id, old_synopsis, fixture$user_id, old_comment)
    )
    review_id <- DBI::dbGetQuery(
      conn, "SELECT LAST_INSERT_ID() AS review_id"
    )$review_id[[1L]]
    DBI::dbExecute(
      conn,
      "INSERT INTO ndd_review_publication_join
       (review_id, entity_id, publication_id, publication_type)
       VALUES (?, ?, ?, ?)",
      params = list(review_id, fixture$entity_id, fixture$publication_id, "additional_references")
    )
    DBI::dbExecute(
      conn,
      "INSERT INTO ndd_review_phenotype_connect
       (review_id, entity_id, phenotype_id, modifier_id)
       VALUES (?, ?, ?, 1)",
      params = list(review_id, fixture$entity_id, fixture$phenotype_id)
    )
    DBI::dbExecute(
      conn,
      "INSERT INTO ndd_review_variation_ontology_connect
       (review_id, entity_id, vario_id, modifier_id)
       VALUES (?, ?, ?, 1)",
      params = list(review_id, fixture$entity_id, fixture$vario_id)
    )
    DBI::dbExecute(
      conn,
      "UPDATE re_review_entity_connect
       SET re_review_review_saved = 1, review_id = ? WHERE entity_id = ?",
      params = list(review_id, fixture$entity_id)
    )

    expect_error(
      review_write_call(
        conn,
        fixture,
        "PUT",
        list(
          entity_id = fixture$entity_id,
          review_id = review_id,
          synopsis = "review-write-atomicity-put-updated",
          comment = "updated comment"
        )
      ),
      class = "db_statement_error"
    )

    review_row <- DBI::dbGetQuery(
      conn,
      "SELECT synopsis, comment FROM ndd_entity_review WHERE review_id = ?",
      params = list(review_id)
    )
    expect_equal(review_row$synopsis, old_synopsis)
    expect_equal(review_row$comment, old_comment)
    expect_equal(
      review_write_count(conn, "ndd_review_publication_join", "review_id = ?", list(review_id)),
      1L
    )
    expect_equal(
      review_write_count(conn, "ndd_review_phenotype_connect", "review_id = ?", list(review_id)),
      1L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "review_id = ?", list(review_id)
      ),
      1L
    )
    marker_row <- DBI::dbGetQuery(
      conn,
      "SELECT re_review_review_saved, review_id
       FROM re_review_entity_connect WHERE entity_id = ?",
      params = list(fixture$entity_id)
    )
    expect_equal(marker_row$re_review_review_saved, 1L)
    expect_equal(as.integer(marker_row$review_id), as.integer(review_id))
  })
})

test_that("unknown modifier is rejected before a review write mutates any dependent row", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 104L)
    marker <- "review-write-atomicity-unknown-modifier"

    expect_error(
      svc_review_write(
        method = "POST",
        review_data = list(entity_id = fixture$entity_id, synopsis = marker),
        publications = tibble::tibble(
          publication_id = fixture$publication_id,
          publication_type = "additional_references"
        ),
        phenotypes = tibble::tibble(
          phenotype_id = fixture$phenotype_id,
          modifier_id = 999L
        ),
        variation_ontology = tibble::tibble(
          vario_id = fixture$vario_id,
          modifier_id = 1L
        ),
        review_user_id = fixture$user_id,
        db = conn
      ),
      class = "error_400",
      regexp = "modifier_id"
    )

    expect_equal(
      review_write_count(conn, "ndd_entity_review", "synopsis = ?", list(marker)),
      0L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_publication_join", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_phenotype_connect", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
  })
})

test_that("review write commits all dependent rows and returns a scalar 200 status", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 103L)
    result <- svc_review_write(
      method = "POST",
      review_data = list(
        entity_id = fixture$entity_id,
        synopsis = "review-write-atomicity-success",
        comment = "complete"
      ),
      publications = tibble::tibble(
        publication_id = fixture$publication_id,
        publication_type = "additional_references"
      ),
      phenotypes = tibble::tibble(
        phenotype_id = fixture$phenotype_id,
        modifier_id = 1L
      ),
      variation_ontology = tibble::tibble(
        vario_id = fixture$vario_id,
        modifier_id = 1L
      ),
      re_review = TRUE,
      direct_approval = FALSE,
      review_user_id = fixture$user_id,
      db = conn
    )

    expect_type(result$status, "integer")
    expect_length(result$status, 1L)
    expect_identical(result$status, 200L)
    review_id <- result$entry$review_id[[1L]]
    expect_equal(
      review_write_count(conn, "ndd_review_publication_join", "review_id = ?", list(review_id)),
      1L
    )
    expect_equal(
      review_write_count(conn, "ndd_review_phenotype_connect", "review_id = ?", list(review_id)),
      1L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "review_id = ?", list(review_id)
      ),
      1L
    )
    marker_row <- DBI::dbGetQuery(
      conn,
      "SELECT re_review_review_saved, review_id
       FROM re_review_entity_connect WHERE entity_id = ?",
      params = list(fixture$entity_id)
    )
    expect_equal(marker_row$re_review_review_saved, 1L)
    expect_equal(marker_row$review_id, review_id)
  })
})


# ===========================================================================
# #608 -- variation-ontology provenance reconciliation, end to end
#
# Real RMariaDB, real migration-047 tables, real svc_review_write() through the
# caller-owned-connection SAVEPOINT branch.
# ===========================================================================

test_that("REGRESSION #608 END TO END: a review save with no provenance action leaves an active_unconfirmed assertion active_unconfirmed AND keeps the annotation live in the connect table", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 111L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    # Exactly what the prefill-and-resubmit surfaces send: the existing term,
    # pre-checked, with no provenance field of any kind.
    result <- review_write_save(
      conn, fixture, "review-write-provenance-no-action",
      variation_ontology = tibble::tibble(vario_id = fixture$vario_id, modifier_id = 1L)
    )

    expect_identical(result$status, 200L)
    review_id <- result$entry$review_id[[1L]]

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(nrow(assertion), 1L)
    # NOT promoted to curator-authored...
    expect_equal(assertion$state, "active_unconfirmed")
    expect_true(is.na(assertion$confirmed_by))
    expect_true(is.na(assertion$confirmed_at))
    # ...and NOT removed either: the annotation is still served on the entity.
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect",
        "review_id = ? AND vario_id = ? AND modifier_id = 1", list(review_id, fixture$vario_id)
      ),
      1L
    )
  })
})

test_that("#608: confirmation is an act -- provenance_action = 'confirm' confirms and attributes to the saving user", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 112L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    result <- review_write_save(
      conn, fixture, "review-write-provenance-confirm",
      variation_ontology = tibble::tibble(
        vario_id = fixture$vario_id, modifier_id = 1L, provenance_action = "confirm"
      )
    )

    expect_identical(result$status, 200L)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "confirmed")
    expect_equal(as.integer(assertion$confirmed_by), as.integer(fixture$user_id))
    expect_false(is.na(assertion$confirmed_at))

    # The extra payload column must NOT leak into the curated connect write.
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect",
        "review_id = ?", list(result$entry$review_id[[1L]])
      ),
      1L
    )
  })
})

test_that("REGRESSION #608 END TO END (I2): a REVIEWER DRAFT save that omits a term leaves its assertion active_unconfirmed -- a draft must never suppress provenance for a term the approved review is still serving", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 113L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    # A plain Reviewer POST: the created review is neither primary nor approved,
    # so it does not determine the entity's served term set. Rejecting here would
    # drop the assertion out of the read path's state filter while the approved
    # review keeps serving the term, i.e. it would render as curator-authored.
    result <- review_write_save(
      conn, fixture, "review-write-provenance-draft-omitted",
      variation_ontology = tibble::tibble()
    )

    expect_identical(result$status, 200L)
    review_id <- result$entry$review_id[[1L]]
    served <- DBI::dbGetQuery(
      conn,
      "SELECT is_primary, review_approved FROM ndd_entity_review WHERE review_id = ?",
      params = list(review_id)
    )
    expect_equal(as.integer(served$is_primary), 0L)
    expect_equal(as.integer(served$review_approved), 0L)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "active_unconfirmed")
    expect_true(is.na(assertion$confirmed_by))
    # The draft's own connect rows are empty, as submitted -- the curated write is
    # unaffected by the provenance rule.
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "review_id = ?", list(review_id)
      ),
      0L
    )
  })
})

test_that("#608 (I2): a DIRECT-APPROVAL save that omits a term DOES reject its assertion", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 117L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    # direct_approval makes this review the served set in the same transaction,
    # and the omission already wipes the connect rows, so rejecting is correct.
    result <- review_write_save(
      conn, fixture, "review-write-provenance-approved-omitted",
      variation_ontology = tibble::tibble(),
      direct_approval = TRUE
    )

    expect_identical(result$status, 200L)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "rejected")
    expect_true(is.na(assertion$confirmed_by))
  })
})

test_that("#608 (I2): review_write_save_determines_served_set() is TRUE for a primary+approved review and FALSE for a draft", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 118L)

    approved_id <- review_write_seed_primary_approved_review(
      conn, fixture, "review-write-provenance-served-review"
    )
    DBI::dbExecute(
      conn,
      "INSERT INTO ndd_entity_review (entity_id, synopsis, review_user_id)
       VALUES (?, ?, ?)",
      params = list(fixture$entity_id, "review-write-provenance-draft-review", fixture$user_id)
    )
    draft_id <- as.integer(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1L]])

    # The is_primary + review_approved branch, exercised directly against real
    # rows. The PUT-path test below explains why this branch cannot be reached
    # through a plain review save.
    expect_true(review_write_save_determines_served_set(approved_id, FALSE, conn))
    expect_false(review_write_save_determines_served_set(draft_id, FALSE, conn))
    # direct_approval short-circuits before the query, so it holds even for a draft.
    expect_true(review_write_save_determines_served_set(draft_id, TRUE, conn))
    # An unknown review_id is not an approval.
    expect_false(review_write_save_determines_served_set(-1L, FALSE, conn))
  })
})

test_that("#608 (I2): a plain PUT editing the live review does NOT reject, because review_update() un-approves the review it just edited", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 122L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")
    review_id <- review_write_seed_primary_approved_review(
      conn, fixture, "review-write-provenance-live-review"
    )
    DBI::dbExecute(
      conn,
      "INSERT INTO ndd_review_variation_ontology_connect
         (review_id, entity_id, vario_id, modifier_id) VALUES (?, ?, ?, 1)",
      params = list(review_id, fixture$entity_id, fixture$vario_id)
    )

    result <- review_write_save(
      conn, fixture, "review-write-provenance-live-review-updated",
      variation_ontology = tibble::tibble(),
      method = "PUT", review_id = review_id
    )

    expect_identical(result$status, 200L)

    # Verified empirically: review_update() unconditionally runs
    # `UPDATE ndd_entity_review SET review_approved = 0` (and clears
    # approving_user_id) after the edit -- an edited review needs re-approval.
    # So by the time the predicate runs, this save is NO LONGER the served set,
    # and the omission must not reject. Nothing is being served for this entity
    # either, so no term can read as curator-authored in the meantime.
    served <- DBI::dbGetQuery(
      conn,
      "SELECT is_primary, review_approved FROM ndd_entity_review WHERE review_id = ?",
      params = list(review_id)
    )
    expect_equal(as.integer(served$review_approved), 0L)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "active_unconfirmed")
    expect_true(is.na(assertion$confirmed_by))
  })
})

test_that("#608 (I2): a PUT with direct approval that omits a term DOES reject its assertion", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 123L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")
    review_id <- review_write_seed_primary_approved_review(
      conn, fixture, "review-write-provenance-put-approve-original"
    )

    result <- review_write_save(
      conn, fixture, "review-write-provenance-put-approve-updated",
      variation_ontology = tibble::tibble(),
      method = "PUT", review_id = review_id, direct_approval = TRUE
    )

    expect_identical(result$status, 200L)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "rejected")
    # The curated replace emptied the connect rows too, so the served set and the
    # provenance state agree.
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "review_id = ?", list(review_id)
      ),
      0L
    )
  })
})

test_that("#608 (I2): a confirmation on a REVIEWER DRAFT save still confirms -- an affirmative act is never gated", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 119L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    result <- review_write_save(
      conn, fixture, "review-write-provenance-draft-confirm",
      variation_ontology = tibble::tibble(
        vario_id = fixture$vario_id, modifier_id = 1L, provenance_action = "confirm"
      )
    )

    expect_identical(result$status, 200L)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "confirmed")
    expect_equal(as.integer(assertion$confirmed_by), as.integer(fixture$user_id))
    expect_false(is.na(assertion$confirmed_at))
  })
})

test_that("REGRESSION #608 END TO END (PUT path): resubmitting a term with no provenance action leaves an active_unconfirmed assertion active_unconfirmed", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 120L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")
    review_id <- review_write_seed_primary_approved_review(
      conn, fixture, "review-write-provenance-put-original"
    )
    DBI::dbExecute(
      conn,
      "INSERT INTO ndd_review_variation_ontology_connect
         (review_id, entity_id, vario_id, modifier_id) VALUES (?, ?, ?, 1)",
      params = list(review_id, fixture$entity_id, fixture$vario_id)
    )

    # The PUT branch additionally runs the review_id-ownership check and
    # variation_ontology_replace_for_review(); the reconciliation must behave
    # identically to POST. This save DOES determine the served set, so the
    # resubmitted term is the interesting case: still not promoted.
    result <- review_write_save(
      conn, fixture, "review-write-provenance-put-no-action",
      variation_ontology = tibble::tibble(vario_id = fixture$vario_id, modifier_id = 1L),
      method = "PUT", review_id = review_id
    )

    expect_identical(result$status, 200L)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "active_unconfirmed")
    expect_true(is.na(assertion$confirmed_by))
    expect_true(is.na(assertion$confirmed_at))
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect",
        "review_id = ? AND vario_id = ? AND modifier_id = 1", list(review_id, fixture$vario_id)
      ),
      1L
    )
  })
})

test_that("#608 (I1): a case-variant vario_id never reaches reconciliation -- lookup validation rejects it with a 400 and nothing is written", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 121L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")
    lowered <- tolower(fixture$vario_id)
    expect_false(identical(lowered, fixture$vario_id))

    # Empirically verified on this MySQL 8.4.11 test DB (see the fix report):
    # the SQL `IN` match IS case-insensitive (utf8mb4_0900_ai_ci) and returns the
    # STORED casing, but review_write_validate_lookup_ids() then compares with
    # R's case-SENSITIVE setdiff(), so the submitted id looks unknown and the
    # request 400s. The reviewer's premise for I1 -- "validation accepts it, the
    # connect row is written" -- therefore does not hold through this service.
    # The identity-key case-normalization is kept as defense in depth for the
    # reachable variant (a backfill writing non-canonical casing into
    # variation_ontology_assertion), which is unit-tested.
    expect_error(
      review_write_save(
        conn, fixture, "review-write-provenance-case-variant",
        variation_ontology = tibble::tibble(vario_id = lowered, modifier_id = 1L),
        direct_approval = TRUE
      ),
      class = "error_400",
      regexp = "vario_id"
    )

    # Nothing laundered and nothing written: the assertion is untouched.
    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(nrow(assertion), 1L)
    expect_equal(assertion$state, "active_unconfirmed")
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
  })
})

test_that("#608: 'present' and 'absent' for one vario_id reconcile independently within a single save", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 116L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed", modifier_id = 1L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed", modifier_id = 5L)

    # direct_approval so this save determines the served term set and the
    # omitted 'absent' claim is legitimately rejectable (see the I2 rule); the
    # point of the test is that the two modifiers are handled INDEPENDENTLY.
    result <- review_write_save(
      conn, fixture, "review-write-provenance-identity",
      variation_ontology = tibble::tibble(
        vario_id = fixture$vario_id, modifier_id = 1L, provenance_action = "confirm"
      ),
      direct_approval = TRUE
    )

    expect_identical(result$status, 200L)

    present <- review_write_assertion_row(conn, fixture, modifier_id = 1L)
    absent <- review_write_assertion_row(conn, fixture, modifier_id = 5L)
    expect_equal(present$state, "confirmed")
    expect_equal(as.integer(present$confirmed_by), as.integer(fixture$user_id))
    expect_equal(absent$state, "rejected")
    expect_true(is.na(absent$confirmed_by))
  })
})

test_that("#608: a failure downstream of the reconciliation rolls the assertion state back with the review", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 114L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    # The file's existing failure injection (duplicate phenotype rows tripping
    # the phenotype_quintuple UNIQUE key) fires UPSTREAM of the reconciliation,
    # so it cannot prove the reconciliation rolls back. Same failure MODE
    # (duplicate-key -> db_statement_error), positioned downstream: run the real
    # mutation, then re-insert the phenotype connect row it just wrote.
    state_before_failure <- NULL
    failing_mutation <- function(prepared, txn_conn, ...) {
      result <- review_write_mutate(prepared, txn_conn, ...)
      # Observe the reconciliation's write from INSIDE the transaction, so this
      # test cannot pass vacuously by never having written anything to roll back.
      state_before_failure <<- DBI::dbGetQuery(
        txn_conn,
        "SELECT state, confirmed_by FROM variation_ontology_assertion
          WHERE entity_id = ? AND vario_id = ? AND modifier_id = 1",
        params = list(fixture$entity_id, fixture$vario_id)
      )
      db_execute_statement(
        "INSERT INTO ndd_review_phenotype_connect
           (review_id, entity_id, phenotype_id, modifier_id)
         VALUES (?, ?, ?, 1)",
        list(result$review_id, prepared$review_data$entity_id, fixture$phenotype_id),
        conn = txn_conn
      )
      result
    }

    expect_error(
      review_write_save(
        conn, fixture, "review-write-provenance-rollback",
        variation_ontology = tibble::tibble(
          vario_id = fixture$vario_id, modifier_id = 1L, provenance_action = "confirm"
        ),
        mutation_fn = failing_mutation
      ),
      class = "db_statement_error"
    )

    # The reconciliation really did confirm inside the transaction...
    expect_equal(state_before_failure$state, "confirmed")
    expect_equal(as.integer(state_before_failure$confirmed_by), as.integer(fixture$user_id))

    # ...and that confirmation must now be gone.
    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(nrow(assertion), 1L)
    expect_equal(assertion$state, "active_unconfirmed")
    expect_true(is.na(assertion$confirmed_by))
    expect_true(is.na(assertion$confirmed_at))
    # ...together with the review and its joins.
    expect_equal(
      review_write_count(
        conn, "ndd_entity_review", "synopsis = ?", list("review-write-provenance-rollback")
      ),
      0L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
  })
})

test_that("INERTNESS #608: with no assertion rows for the entity a review save writes nothing to either provenance table", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 115L)
    # Deliberately NO assertion seeded: this is production today, because the
    # backfill that populates these tables lives in another repository and has
    # not run.

    result <- review_write_save(
      conn, fixture, "review-write-provenance-inert",
      variation_ontology = tibble::tibble(
        vario_id = fixture$vario_id, modifier_id = 1L, provenance_action = "confirm"
      )
    )

    expect_identical(result$status, 200L)
    expect_equal(
      review_write_count(
        conn, "variation_ontology_assertion", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
    expect_equal(
      review_write_count(
        conn,
        "variation_ontology_evidence e
           JOIN variation_ontology_assertion a ON a.assertion_id = e.assertion_id",
        "a.entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
    # The ordinary curated write still happened.
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect",
        "review_id = ?", list(result$entry$review_id[[1L]])
      ),
      1L
    )
  })
})


# ===========================================================================
# #613 -- the endpoint's REAL payload shape must reach review_update()
#
# `review_data <- req$argsBody$review_json` (endpoints/review_endpoints.R:220)
# ALWAYS carries `literature`, `phenotypes` and `variation_ontology`: the handler
# reads those three keys off the very object it then forwards as `review_data`.
# Every test above constructs `review_data` from allowlisted columns only, which
# is exactly why `review_update()`'s mass-assignment allowlist firing on the
# ontology keys (an opaque 500 on every save the frontend actually sends) stayed
# hidden.
# ===========================================================================

#' `review_data` in the shape `req$argsBody$review_json` really arrives in.
#'
#' The three extra keys are not test decoration -- the frontend sends them on
#' every save (`useReviewForm.submitForm()` -> `new Review(synopsis, literature,
#' phenotypes, variations, comment)`), and Plumber's jsonlite body parser
#' (`simplifyVector = TRUE`) turns each uniform JSON array of objects into a
#' data.frame, hence the data.frame columns below.
#'
#' `...` appends further keys, which is how the escalation cases smuggle
#' `review_approved` / `is_primary` / `approving_user_id`.
review_write_endpoint_review_data <- function(fixture, synopsis, comment = NULL,
                                             review_id = NULL, ...) {
  review_data <- list(entity_id = fixture$entity_id, synopsis = synopsis)
  if (!is.null(review_id)) {
    review_data$review_id <- review_id
  }
  if (!is.null(comment)) {
    review_data$comment <- comment
  }

  review_data$literature <- list(
    additional_references = data.frame(
      value = fixture$publication_id, stringsAsFactors = FALSE
    ),
    gene_review = data.frame(value = character(), stringsAsFactors = FALSE)
  )
  review_data$phenotypes <- data.frame(
    phenotype_id = fixture$phenotype_id, modifier_id = 1L, stringsAsFactors = FALSE
  )
  review_data$variation_ontology <- data.frame(
    vario_id = fixture$vario_id, modifier_id = 1L, stringsAsFactors = FALSE
  )

  extra <- list(...)
  for (key in names(extra)) {
    review_data[[key]] <- extra[[key]]
  }
  review_data
}

#' Call svc_review_write() the way the endpoint does: the ontology arguments are
#' read OFF `review_data`, and `review_data` itself is still passed whole.
review_write_endpoint_save <- function(conn, fixture, method, review_data,
                                       direct_approval = FALSE) {
  svc_review_write(
    method = method,
    review_data = review_data,
    publications = tibble::tibble(
      publication_id = fixture$publication_id,
      publication_type = "additional_references"
    ),
    phenotypes = review_data$phenotypes,
    variation_ontology = review_data$variation_ontology,
    re_review = FALSE,
    direct_approval = direct_approval,
    review_user_id = fixture$user_id,
    db = conn
  )
}

review_write_review_row <- function(conn, review_id) {
  DBI::dbGetQuery(
    conn,
    "SELECT synopsis, comment, is_primary, review_approved, approving_user_id
       FROM ndd_entity_review WHERE review_id = ?",
    params = list(review_id)
  )
}

review_write_seed_plain_review <- function(conn, fixture, synopsis, comment) {
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_entity_review (entity_id, synopsis, review_user_id, comment)
     VALUES (?, ?, ?, ?)",
    params = list(fixture$entity_id, synopsis, fixture$user_id, comment)
  )
  as.integer(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1L]])
}

test_that("REGRESSION #613: a PUT save whose review_data carries the endpoint's literature/phenotypes/variation_ontology keys succeeds and updates synopsis and comment", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 131L)
    review_id <- review_write_seed_plain_review(
      conn, fixture, "review-write-613-original", "original comment"
    )

    result <- review_write_endpoint_save(
      conn, fixture, "PUT",
      review_write_endpoint_review_data(
        fixture, "review-write-613-updated",
        comment = "updated comment", review_id = review_id
      )
    )

    expect_identical(result$status, 200L)
    expect_equal(result$message, "OK. Review updated.")

    row <- review_write_review_row(conn, review_id)
    expect_equal(row$synopsis, "review-write-613-updated")
    expect_equal(row$comment, "updated comment")
    # The curated joins were replaced, i.e. the whole PUT mutation committed
    # rather than rolling back on the allowlist abort.
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "review_id = ?", list(review_id)
      ),
      1L
    )
    expect_equal(
      review_write_count(
        conn, "ndd_review_phenotype_connect", "review_id = ?", list(review_id)
      ),
      1L
    )
  })
})

test_that("SECURITY #613: a PUT save cannot smuggle is_primary / review_approved / approving_user_id into ndd_entity_review", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 132L)
    review_id <- review_write_seed_plain_review(
      conn, fixture, "review-write-613-escalation-original", "original comment"
    )

    # `review_update()`'s own allowlist permits all three columns, because
    # svc_review_update() and the approval path need them. Forwarding the client
    # body into it would therefore let a Reviewer approve their own review and
    # make it primary, bypassing the Curator gate on /api/review/approve.
    result <- review_write_endpoint_save(
      conn, fixture, "PUT",
      review_write_endpoint_review_data(
        fixture, "review-write-613-escalation-updated",
        comment = "escalation attempt", review_id = review_id,
        is_primary = 1L, review_approved = 1L, approving_user_id = fixture$user_id
      )
    )

    expect_identical(result$status, 200L)

    row <- review_write_review_row(conn, review_id)
    # is_primary is the load-bearing assertion: review_update() unconditionally
    # runs `SET review_approved = 0` and `SET approving_user_id = NULL` after the
    # edit, so those two would be reset even if smuggled -- is_primary would
    # genuinely persist as 1.
    expect_equal(as.integer(row$is_primary), 0L)
    expect_equal(as.integer(row$review_approved), 0L)
    expect_true(is.na(row$approving_user_id))
    # ...while the two legitimately writable columns still saved.
    expect_equal(row$synopsis, "review-write-613-escalation-updated")
    expect_equal(row$comment, "escalation attempt")
  })
})

test_that("#613: review_write_updatable_review_fields() projects a raw request body to synopsis + comment only, keeping absent keys absent", {
  full_body <- list(
    review_id = 5L, entity_id = 7L, synopsis = "s", comment = "c",
    review_user_id = 9L, is_primary = 1L, review_approved = 1L,
    approving_user_id = 9L, review_date = "2026-07-30",
    literature = list(), phenotypes = list(), variation_ontology = list()
  )
  expect_identical(
    review_write_updatable_review_fields(full_body),
    list(synopsis = "s", comment = "c")
  )
  # A payload without `comment` must not invent one, so the stored comment is
  # left untouched rather than nulled.
  expect_identical(
    review_write_updatable_review_fields(list(entity_id = 7L, synopsis = "s")),
    list(synopsis = "s")
  )
})

test_that("#613: a PUT save that omits comment updates the synopsis and leaves the stored comment untouched", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 133L)
    review_id <- review_write_seed_plain_review(
      conn, fixture, "review-write-613-nocomment-original", "keep me"
    )

    result <- review_write_endpoint_save(
      conn, fixture, "PUT",
      review_write_endpoint_review_data(
        fixture, "review-write-613-nocomment-updated", review_id = review_id
      )
    )

    expect_identical(result$status, 200L)
    row <- review_write_review_row(conn, review_id)
    expect_equal(row$synopsis, "review-write-613-nocomment-updated")
    expect_equal(row$comment, "keep me")
  })
})

test_that("#613: the POST create path is unaffected by the same endpoint-shaped review_data", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 134L)

    # review_create() picks its columns explicitly instead of sharing
    # review_update()'s allowlist, which is why entity creation kept working
    # while every re-review save 500'd.
    result <- review_write_endpoint_save(
      conn, fixture, "POST",
      review_write_endpoint_review_data(
        fixture, "review-write-613-post", comment = "post comment"
      )
    )

    expect_identical(result$status, 200L)
    expect_equal(result$message, "OK. Review created.")

    review_id <- result$entry$review_id[[1L]]
    row <- review_write_review_row(conn, review_id)
    expect_equal(row$synopsis, "review-write-613-post")
    expect_equal(row$comment, "post comment")
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect", "review_id = ?", list(review_id)
      ),
      1L
    )
  })
})

test_that("#613: review_write_creatable_review_fields() projects a raw request body to the four columns a SUBMISSION may set, never approval state", {
  full_body <- list(
    review_id = 5L, entity_id = 7L, synopsis = "s", comment = "c",
    review_user_id = 9L, is_primary = 1L, review_approved = 1L,
    approving_user_id = 9L, review_date = "2026-07-30",
    literature = list(), phenotypes = list(), variation_ontology = list()
  )
  expect_identical(
    review_write_creatable_review_fields(full_body),
    list(entity_id = 7L, review_user_id = 9L, synopsis = "s", comment = "c")
  )
  # A payload without `comment` must not invent one; the column default applies.
  expect_identical(
    review_write_creatable_review_fields(
      list(entity_id = 7L, review_user_id = 9L, synopsis = "s")
    ),
    list(entity_id = 7L, review_user_id = 9L, synopsis = "s")
  )
})

test_that("SECURITY #613: a POST create cannot mass-assign is_primary / review_approved / approving_user_id -- the review is stored unapproved and non-primary", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 135L)

    # review_create() INSERTs is_primary / review_approved / approving_user_id
    # whenever the record it is handed carries them (#318, for entity creation and
    # the rename flow), so forwarding the raw client body would let a Reviewer
    # publish an approved PRIMARY review without ever passing the Curator gate on
    # /api/review/approve. Post-#608 it is worse: a forged approved primary review
    # also satisfies review_write_save_determines_served_set(), which unlocks the
    # provenance rejection edges.
    result <- review_write_endpoint_save(
      conn, fixture, "POST",
      review_write_endpoint_review_data(
        fixture, "review-write-613-post-escalation",
        comment = "post escalation attempt",
        is_primary = 1L, review_approved = 1L, approving_user_id = fixture$user_id
      )
    )

    expect_identical(result$status, 200L)
    expect_equal(result$message, "OK. Review created.")

    review_id <- result$entry$review_id[[1L]]
    row <- review_write_review_row(conn, review_id)
    # Assert the STORED row, not merely the absence of an error. Unlike the PUT
    # path, nothing downstream resets these columns, so all three would genuinely
    # persist if the body were forwarded.
    expect_equal(as.integer(row$is_primary), 0L)
    expect_equal(as.integer(row$review_approved), 0L)
    expect_true(is.na(row$approving_user_id))
    # ...while the columns a submission legitimately sets still saved.
    expect_equal(row$synopsis, "review-write-613-post-escalation")
    expect_equal(row$comment, "post escalation attempt")
  })
})

test_that("REGRESSION #608 END TO END: a Confirm on one term while another assertion stays UNCHANGED writes state = 'confirmed' WITH attribution instead of failing migration 047's chk_confirmed_attribution", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 136L)
    # modifier 1: already confirmed and resubmitted -> UNCHANGED, so the planned
    # rows are a strict subset of the entity's assertions. That is precisely the
    # regime in which the tibble() data-masking bug turned needs_attribution into
    # NA, the applier then wrote a confirmed row with a NULL confirmed_by, and the
    # CHECK constraint rolled the whole save back as an opaque 500.
    review_write_seed_assertion(conn, fixture, state = "confirmed", modifier_id = 1L)
    review_write_seed_assertion(
      conn, fixture, state = "active_unconfirmed", modifier_id = 5L
    )

    result <- review_write_save(
      conn, fixture, "review-write-provenance-mixed-confirm",
      variation_ontology = tibble::tibble(
        vario_id = rep(fixture$vario_id, 2L),
        modifier_id = c(1L, 5L),
        provenance_action = c(NA_character_, "confirm")
      )
    )

    expect_identical(result$status, 200L)

    confirmed <- review_write_assertion_row(conn, fixture, modifier_id = 5L)
    expect_equal(confirmed$state, "confirmed")
    expect_equal(as.integer(confirmed$confirmed_by), as.integer(fixture$user_id))
    expect_false(is.na(confirmed$confirmed_at))

    # The pre-existing confirmation was not re-stamped and not disturbed.
    untouched <- review_write_assertion_row(conn, fixture, modifier_id = 1L)
    expect_equal(untouched$state, "confirmed")
    expect_equal(as.integer(untouched$confirmed_by), as.integer(fixture$user_id))
  })
})


# ---------------------------------------------------------------------------
# #612: the approval path retires assertions the entity no longer serves
# ---------------------------------------------------------------------------
#
# review_update() unconditionally sets review_approved = 0, so on the ordinary
# edit-then-approve-separately workflow the WRITE path's rejection edge never
# fires -- the term stops being served but its assertion stays
# active_unconfirmed and the curation queue keeps offering it. These tests drive
# the real svc_approval_review_approve() against a real database, because the
# unit tests stub the transaction scope and therefore cannot prove atomicity.

test_that("#612: approving a review that omits a term retires that term's assertion", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 612L)
    assertion_id <- review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    # A draft that drops the term. The draft is not primary+approved, so the
    # write path deliberately leaves the assertion alone (#608 I2).
    result <- review_write_save(
      conn, fixture, "612-approval-drops-term",
      variation_ontology = tibble::tibble(vario_id = character(), modifier_id = integer())
    )
    expect_identical(result$status, 200L)
    review_id <- result$entry$review_id[[1L]]
    expect_equal(review_write_assertion_row(conn, fixture)$state, "active_unconfirmed")

    # Approving it is what makes the omission public -- and what retires the
    # assertion.
    approval <- svc_approval_review_approve(review_id, fixture$user_id, TRUE, pool = conn)
    expect_equal(approval$status, 200)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "rejected")
    expect_equal(assertion$assertion_id, assertion_id)
    # Rejection is not attribution: nobody confirmed anything.
    expect_true(is.na(assertion$confirmed_by))
  })
})

test_that("#612: approving a review that KEEPS a term leaves its assertion unconfirmed", {
  # The load-bearing direction. If approval retired a served term's assertion,
  # the public read's state filter would drop it and the still-served term would
  # render as CURATOR-AUTHORED -- the exact fabrication this feature prevents.
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 613L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    result <- review_write_save(
      conn, fixture, "612-approval-keeps-term",
      variation_ontology = tibble::tibble(vario_id = fixture$vario_id, modifier_id = 1L)
    )
    review_id <- result$entry$review_id[[1L]]

    svc_approval_review_approve(review_id, fixture$user_id, TRUE, pool = conn)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "active_unconfirmed")
    expect_true(is.na(assertion$confirmed_by))
  })
})

test_that("#612: approval RESTORES a now-served suggestion, and never confirms it", {
  # Two rules meet here.
  #
  # Approving a review is an act on the review, not a per-term reading of
  # machine evidence, so it must never promote to `confirmed` -- that is the
  # silent promotion #608 exists to stop.
  #
  # But an assertion left `suggested` while its term IS served falls outside the
  # public read's state filter, so the served term would render as
  # CURATOR-AUTHORED. It is therefore restored to `active_unconfirmed`: visible
  # as machine provenance, unattributed, and back in the curation queue for a
  # real decision.
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 614L)
    # modifier 5 ('absent') -- the other half of the identity, so this exercises
    # the same vario_id under a different modifier.
    review_write_seed_assertion(conn, fixture, state = "suggested", modifier_id = 5L)
    result <- review_write_save(
      conn, fixture, "612-approval-no-promote",
      variation_ontology = tibble::tibble(vario_id = fixture$vario_id, modifier_id = 5L)
    )
    review_id <- result$entry$review_id[[1L]]

    # The WRITE path confirms it (submitted + suggested is an affirmative act),
    # so re-seed the state to prove the APPROVAL path itself does not promote.
    DBI::dbExecute(
      conn,
      "UPDATE variation_ontology_assertion SET state = 'suggested',
              confirmed_by = NULL, confirmed_at = NULL
        WHERE entity_id = ? AND vario_id = ? AND modifier_id = 5",
      params = list(fixture$entity_id, fixture$vario_id)
    )

    svc_approval_review_approve(review_id, fixture$user_id, TRUE, pool = conn)

    assertion <- review_write_assertion_row(conn, fixture, modifier_id = 5L)
    expect_equal(assertion$state, "active_unconfirmed")
    # Restored, NOT confirmed: no attribution was written.
    expect_true(is.na(assertion$confirmed_by))
    expect_true(is.na(assertion$confirmed_at))
  })
})

test_that("#612: a reconciliation failure rolls the APPROVAL back with it", {
  # The atomicity claim. Without one shared transaction scope the review would
  # be left primary+approved while its assertions still described the old
  # served set.
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 615L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    result <- review_write_save(
      conn, fixture, "612-approval-rollback",
      variation_ontology = tibble::tibble(vario_id = character(), modifier_id = integer())
    )
    review_id <- result$entry$review_id[[1L]]

    before <- DBI::dbGetQuery(
      conn,
      "SELECT is_primary, review_approved, approving_user_id
         FROM ndd_entity_review WHERE review_id = ?",
      params = list(review_id)
    )
    expect_equal(as.integer(before$review_approved[[1L]]), 0L)

    target <- environment(variation_provenance_reconcile_on_approval)
    original <- base::get("variation_provenance_reconcile_on_approval", envir = target)
    assign("variation_provenance_reconcile_on_approval",
           function(...) stop("reconcile boom"), envir = target)
    withr::defer(
      assign("variation_provenance_reconcile_on_approval", original, envir = target)
    )

    expect_error(
      svc_approval_review_approve(review_id, fixture$user_id, TRUE, pool = conn),
      "reconcile boom"
    )

    after <- DBI::dbGetQuery(
      conn,
      "SELECT is_primary, review_approved, approving_user_id
         FROM ndd_entity_review WHERE review_id = ?",
      params = list(review_id)
    )
    expect_equal(as.integer(after$review_approved[[1L]]), 0L)
    expect_equal(as.integer(after$is_primary[[1L]]), as.integer(before$is_primary[[1L]]))
    expect_true(is.na(after$approving_user_id[[1L]]))
    # ...and the assertion is untouched too.
    expect_equal(review_write_assertion_row(conn, fixture)$state, "active_unconfirmed")
  })
})

test_that("#612 INERTNESS: approving an entity with no assertion rows writes nothing", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 616L)

    result <- review_write_save(
      conn, fixture, "612-approval-inert",
      variation_ontology = tibble::tibble(vario_id = fixture$vario_id, modifier_id = 1L)
    )
    review_id <- result$entry$review_id[[1L]]

    approval <- svc_approval_review_approve(review_id, fixture$user_id, TRUE, pool = conn)
    expect_equal(approval$status, 200)
    expect_equal(
      review_write_count(
        conn, "variation_ontology_assertion", "entity_id = ?", list(fixture$entity_id)
      ),
      0L
    )
    # The approval itself still happened.
    approved <- DBI::dbGetQuery(
      conn, "SELECT review_approved, is_primary FROM ndd_entity_review WHERE review_id = ?",
      params = list(review_id)
    )
    expect_equal(as.integer(approved$review_approved[[1L]]), 1L)
    expect_equal(as.integer(approved$is_primary[[1L]]), 1L)
  })
})
