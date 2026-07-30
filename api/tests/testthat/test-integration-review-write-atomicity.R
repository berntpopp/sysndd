# Real-RMariaDB regression coverage for the review-save transaction boundary.
#
# The fixture DDL deliberately runs on its own connection: MySQL DDL commits
# implicitly, while each test below uses with_test_db_transaction() and passes
# its caller-owned connection to svc_review_write().

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)
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
review_write_save <- function(conn, fixture, synopsis, variation_ontology,
                              method = "POST", mutation_fn = review_write_mutate) {
  svc_review_write(
    method = method,
    review_data = list(entity_id = fixture$entity_id, synopsis = synopsis),
    publications = tibble::tibble(
      publication_id = fixture$publication_id,
      publication_type = "additional_references"
    ),
    phenotypes = tibble::tibble(phenotype_id = fixture$phenotype_id, modifier_id = 1L),
    variation_ontology = variation_ontology,
    re_review = FALSE,
    direct_approval = FALSE,
    review_user_id = fixture$user_id,
    db = conn,
    mutation_fn = mutation_fn
  )
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

test_that("#608: omitting a term rejects its assertion, even when the client sends no provenance fields at all", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- review_write_seed(conn, 113L)
    review_write_seed_assertion(conn, fixture, state = "active_unconfirmed")

    result <- review_write_save(
      conn, fixture, "review-write-provenance-omitted",
      variation_ontology = tibble::tibble()
    )

    expect_identical(result$status, 200L)

    assertion <- review_write_assertion_row(conn, fixture)
    expect_equal(assertion$state, "rejected")
    expect_true(is.na(assertion$confirmed_by))
    expect_equal(
      review_write_count(
        conn, "ndd_review_variation_ontology_connect",
        "review_id = ?", list(result$entry$review_id[[1L]])
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

    result <- review_write_save(
      conn, fixture, "review-write-provenance-identity",
      variation_ontology = tibble::tibble(
        vario_id = fixture$vario_id, modifier_id = 1L, provenance_action = "confirm"
      )
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
