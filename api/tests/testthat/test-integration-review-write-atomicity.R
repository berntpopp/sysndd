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
