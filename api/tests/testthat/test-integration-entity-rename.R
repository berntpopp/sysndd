# tests/testthat/test-integration-entity-rename.R
# DB-backed integration tests for svc_entity_rename_full (#318).
# Requires test database (sysndd_db_test) and skips when unavailable.

library(testthat)
library(tibble)
library(dplyr)
library(DBI)
library(purrr)
library(stringr)
library(tidyr)
library(xml2)

source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/entity-repository.R", local = FALSE)
source_api_file("functions/review-repository.R", local = FALSE)
source_api_file("functions/status-repository.R", local = FALSE)
source_api_file("functions/phenotype-repository.R", local = FALSE)
source_api_file("functions/ontology-repository.R", local = FALSE)
source_api_file("functions/publication-repository.R", local = FALSE)
source_api_file("functions/publication-functions.R", local = FALSE)
source_api_file("core/errors.R", local = FALSE)
source_api_file("services/entity-service.R", local = FALSE)

TEST_HGNC <- "HGNC:99901"
TEST_MOI <- "HP:9000001"
TEST_PHENOTYPE <- "HP:9000002"
TEST_VARIO <- "VariO:9001"
TEST_PUBLICATION <- "PMID:990001"
TEST_BOGUS_PMIDS <- c("PMID:99999991", "PMID:99999992")
TEST_ONTOLOGIES <- c(
  "OMIM:990001",
  "OMIM:990002",
  "OMIM:990003",
  "OMIM:990004",
  "OMIM:990005"
)

SOURCE_ONTOLOGY <- TEST_ONTOLOGIES[[1]]
DEST_ONTOLOGY <- TEST_ONTOLOGIES[[2]]
ROLLBACK_DEST_ONTOLOGY <- TEST_ONTOLOGIES[[3]]
CONFLICT_DEST_ONTOLOGY <- TEST_ONTOLOGIES[[4]]

db_fetch_params <- function(conn, sql, params = list()) {
  result <- DBI::dbSendQuery(conn, sql)
  on.exit(DBI::dbClearResult(result), add = TRUE)
  if (length(params) > 0) {
    DBI::dbBind(result, unname(params))
  }
  tibble::as_tibble(DBI::dbFetch(result))
}

db_execute_params <- function(conn, sql, params = list()) {
  result <- DBI::dbSendStatement(conn, sql)
  on.exit(DBI::dbClearResult(result), add = TRUE)
  if (length(params) > 0) {
    DBI::dbBind(result, unname(params))
  }
  DBI::dbGetRowsAffected(result)
}

placeholders <- function(values) {
  paste(rep("?", length(values)), collapse = ", ")
}

db_delete_in <- function(conn, table, column, values) {
  if (length(values) == 0) {
    return(invisible(0L))
  }
  sql <- sprintf(
    "DELETE FROM %s WHERE %s IN (%s)",
    table,
    column,
    placeholders(values)
  )
  db_execute_params(conn, sql, as.list(values))
}

make_test_pool <- function() {
  test_config <- get_test_config()
  pool::dbPool(
    RMariaDB::MariaDB(),
    dbname = test_config$dbname,
    host = test_config$host,
    user = test_config$user,
    password = test_config$password,
    port = as.integer(test_config$port)
  )
}

skip_if_missing_entity_rename_schema <- function(conn) {
  required_tables <- c(
    "ndd_entity",
    "ndd_entity_review",
    "ndd_entity_status",
    "ndd_review_publication_join",
    "publication",
    "ndd_review_phenotype_connect",
    "phenotype_list",
    "ndd_review_variation_ontology_connect",
    "variation_ontology_list",
    "disease_ontology_set",
    "mode_of_inheritance_list",
    "non_alt_loci_set"
  )
  missing_tables <- required_tables[!vapply(
    required_tables,
    function(table) DBI::dbExistsTable(conn, table),
    logical(1)
  )]

  if (length(missing_tables) > 0) {
    skip(paste(
      "Test database schema is not initialized; missing table(s):",
      paste(missing_tables, collapse = ", ")
    ))
  }
}

cleanup_entity_rename_fixture <- function(conn) {
  entity_ids <- db_fetch_params(
    conn,
    paste0(
      "SELECT entity_id FROM ndd_entity ",
      "WHERE hgnc_id = ? OR disease_ontology_id_version IN (",
      placeholders(TEST_ONTOLOGIES),
      ")"
    ),
    c(list(TEST_HGNC), as.list(TEST_ONTOLOGIES))
  )$entity_id

  review_ids <- integer()
  if (length(entity_ids) > 0) {
    review_ids <- db_fetch_params(
      conn,
      paste0(
        "SELECT review_id FROM ndd_entity_review WHERE entity_id IN (",
        placeholders(entity_ids),
        ")"
      ),
      as.list(entity_ids)
    )$review_id
  }

  db_delete_in(conn, "ndd_review_variation_ontology_connect", "review_id", review_ids)
  db_delete_in(conn, "ndd_review_variation_ontology_connect", "entity_id", entity_ids)
  db_delete_in(conn, "ndd_review_variation_ontology_connect", "vario_id", TEST_VARIO)

  db_delete_in(conn, "ndd_review_phenotype_connect", "review_id", review_ids)
  db_delete_in(conn, "ndd_review_phenotype_connect", "entity_id", entity_ids)
  db_delete_in(conn, "ndd_review_phenotype_connect", "phenotype_id", TEST_PHENOTYPE)

  db_delete_in(conn, "ndd_review_publication_join", "review_id", review_ids)
  db_delete_in(conn, "ndd_review_publication_join", "entity_id", entity_ids)
  db_delete_in(
    conn,
    "ndd_review_publication_join",
    "publication_id",
    c(TEST_PUBLICATION, TEST_BOGUS_PMIDS)
  )

  db_delete_in(conn, "ndd_entity_status", "entity_id", entity_ids)
  db_delete_in(conn, "ndd_entity_review", "entity_id", entity_ids)

  if (length(entity_ids) > 0) {
    db_execute_params(
      conn,
      paste0(
        "UPDATE ndd_entity SET replaced_by = NULL ",
        "WHERE entity_id IN (", placeholders(entity_ids), ") ",
        "OR replaced_by IN (", placeholders(entity_ids), ")"
      ),
      c(as.list(entity_ids), as.list(entity_ids))
    )
  }

  db_delete_in(conn, "ndd_entity", "entity_id", entity_ids)
  db_delete_in(conn, "publication", "publication_id", c(TEST_PUBLICATION, TEST_BOGUS_PMIDS))
  db_delete_in(conn, "phenotype_list", "phenotype_id", TEST_PHENOTYPE)
  db_delete_in(conn, "variation_ontology_list", "vario_id", TEST_VARIO)
  db_delete_in(conn, "disease_ontology_set", "disease_ontology_id_version", TEST_ONTOLOGIES)
  db_delete_in(conn, "mode_of_inheritance_list", "hpo_mode_of_inheritance_term", TEST_MOI)
  db_delete_in(conn, "non_alt_loci_set", "hgnc_id", TEST_HGNC)

  invisible(NULL)
}

seed_reference_rows <- function(conn) {
  db_execute_params(
    conn,
    "INSERT INTO non_alt_loci_set (hgnc_id, symbol, name) VALUES (?, ?, ?)",
    list(TEST_HGNC, "SYSNDDTEST", "SysNDD test gene")
  )
  db_execute_params(
    conn,
    paste0(
      "INSERT INTO mode_of_inheritance_list ",
      "(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name, ",
      "inheritance_filter, inheritance_short_text, is_active, sort) ",
      "VALUES (?, ?, ?, ?, ?, ?)"
    ),
    list(TEST_MOI, "SysNDD test inheritance", "test", "TST", 1L, 9000001L)
  )

  for (ontology in TEST_ONTOLOGIES) {
    db_execute_params(
      conn,
      paste0(
        "INSERT INTO disease_ontology_set ",
        "(disease_ontology_id_version, disease_ontology_id, ",
        "disease_ontology_name, disease_ontology_source, ",
        "disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term, ",
        "is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
      ),
      list(
        ontology,
        str_remove(ontology, "^OMIM:"),
        paste("SysNDD test ontology", ontology),
        "OMIM",
        1L,
        TEST_HGNC,
        TEST_MOI,
        1L
      )
    )
  }

  db_execute_params(
    conn,
    paste0(
      "INSERT INTO phenotype_list ",
      "(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms, comment) ",
      "VALUES (?, ?, ?, ?, ?)"
    ),
    list(
      TEST_PHENOTYPE,
      "SysNDD test phenotype",
      "Phenotype used by entity rename integration tests.",
      "",
      "test fixture"
    )
  )
  db_execute_params(
    conn,
    paste0(
      "INSERT INTO variation_ontology_list ",
      "(vario_id, vario_name, definition, obsolete, is_active, sort) ",
      "VALUES (?, ?, ?, ?, ?, ?)"
    ),
    list(
      TEST_VARIO,
      "SysNDD test variation",
      "Variation term used by entity rename integration tests.",
      0L,
      1L,
      9001L
    )
  )
  db_execute_params(
    conn,
    paste0(
      "INSERT INTO publication ",
      "(publication_id, publication_type, other_publication_id, Title, Abstract, ",
      "Publication_date, Journal_abbreviation, Journal, Keywords, Lastname, Firstname) ",
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ),
    list(
      TEST_PUBLICATION,
      "additional_references",
      "DOI:10.9999/sysndd-test",
      "SysNDD test publication",
      "Publication used by entity rename integration tests.",
      "2026-01-01",
      "SysNDD Test J",
      "SysNDD Test Journal",
      "test",
      "Curator",
      "Test"
    )
  )

  invisible(NULL)
}

insert_and_get_id <- function(conn, sql, params, id_column) {
  db_execute_params(conn, sql, params)
  id <- db_fetch_params(conn, sprintf("SELECT LAST_INSERT_ID() AS %s", id_column))[[id_column]][[1]]
  as.integer(id)
}

seed_approved_entity_bundle <- function(conn, ontology, with_joins = TRUE, user_id = 1L) {
  entity_id <- insert_and_get_id(
    conn,
    paste0(
      "INSERT INTO ndd_entity ",
      "(hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ",
      "ndd_phenotype, entry_user_id, is_active) VALUES (?, ?, ?, ?, ?, ?)"
    ),
    list(TEST_HGNC, TEST_MOI, ontology, 1L, user_id, 1L),
    "entity_id"
  )
  review_id <- insert_and_get_id(
    conn,
    paste0(
      "INSERT INTO ndd_entity_review ",
      "(entity_id, synopsis, is_primary, review_user_id, review_approved, ",
      "approving_user_id, comment) VALUES (?, ?, ?, ?, ?, ?, ?)"
    ),
    list(
      entity_id,
      paste("Approved source synopsis for", ontology),
      1L,
      user_id,
      1L,
      user_id,
      "approved test review"
    ),
    "review_id"
  )
  status_id <- insert_and_get_id(
    conn,
    paste0(
      "INSERT INTO ndd_entity_status ",
      "(entity_id, category_id, is_active, status_user_id, status_approved, ",
      "approving_user_id, problematic, comment) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    ),
    list(entity_id, 1L, 1L, user_id, 1L, user_id, 0L, "approved test status"),
    "status_id"
  )

  if (isTRUE(with_joins)) {
    db_execute_params(
      conn,
      paste0(
        "INSERT INTO ndd_review_publication_join ",
        "(review_id, entity_id, publication_id, publication_type) ",
        "VALUES (?, ?, ?, ?)"
      ),
      list(review_id, entity_id, TEST_PUBLICATION, "additional_references")
    )
    db_execute_params(
      conn,
      paste0(
        "INSERT INTO ndd_review_phenotype_connect ",
        "(review_id, entity_id, phenotype_id, modifier_id) VALUES (?, ?, ?, ?)"
      ),
      list(review_id, entity_id, TEST_PHENOTYPE, 1L)
    )
    db_execute_params(
      conn,
      paste0(
        "INSERT INTO ndd_review_variation_ontology_connect ",
        "(review_id, vario_id, modifier_id, entity_id) VALUES (?, ?, ?, ?)"
      ),
      list(review_id, TEST_VARIO, 1L, entity_id)
    )
  }

  list(entity_id = entity_id, review_id = review_id, status_id = status_id)
}

rename_payload <- function(entity_id, ontology) {
  list(entity = list(
    entity_id = entity_id,
    hgnc_id = TEST_HGNC,
    hpo_mode_of_inheritance_term = TEST_MOI,
    ndd_phenotype = 1L,
    disease_ontology_id_version = ontology
  ))
}

fetch_one <- function(conn, sql, params = list()) {
  rows <- db_fetch_params(conn, sql, params)
  expect_equal(nrow(rows), 1L)
  rows[1, ]
}

fetch_entity_row <- function(conn, entity_id) {
  fetch_one(
    conn,
    paste0(
      "SELECT entity_id, hgnc_id, hpo_mode_of_inheritance_term, ",
      "disease_ontology_id_version, ndd_phenotype, is_active, replaced_by ",
      "FROM ndd_entity WHERE entity_id = ?"
    ),
    list(entity_id)
  )
}

fetch_review_row <- function(conn, review_id) {
  fetch_one(
    conn,
    paste0(
      "SELECT review_id, entity_id, synopsis, is_primary, review_approved, ",
      "approving_user_id, comment FROM ndd_entity_review WHERE review_id = ?"
    ),
    list(review_id)
  )
}

fetch_status_row <- function(conn, status_id) {
  fetch_one(
    conn,
    paste0(
      "SELECT status_id, entity_id, category_id, is_active, status_approved, ",
      "approving_user_id, problematic, comment FROM ndd_entity_status ",
      "WHERE status_id = ?"
    ),
    list(status_id)
  )
}

count_query <- function(conn, sql, params = list()) {
  as.integer(db_fetch_params(conn, sql, params)$n[[1]])
}

function_with_cloned_env <- function(fn) {
  environment(fn) <- rlang::env_clone(environment(fn))
  fn
}

entity_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "entity_endpoints.R")
}

entity_source <- function() {
  readLines(entity_endpoint_path(), warn = FALSE)
}

extract_entity_handler <- function(decorator_regex, envir) {
  src_lines <- entity_source()
  dec_hits <- grep(decorator_regex, src_lines)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in entity_endpoints.R: ", decorator_regex)
  }
  dec_line <- dec_hits[[1L]]

  parsed <- parse(file = entity_endpoint_path(), keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  if (is.null(srcrefs)) {
    stop("Unable to read source refs for entity_endpoints.R")
  }

  handler_expr <- NULL
  for (i in seq_along(parsed)) {
    start_line <- srcrefs[[i]][1L]
    if (start_line > dec_line) {
      handler_expr <- parsed[[i]]
      break
    }
  }
  if (is.null(handler_expr)) {
    stop("No top-level expression found after decorator line ", dec_line)
  }

  eval(handler_expr, envir = envir)
}

make_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$body <- NULL
  res
}

count_join_table <- function(conn, table, review_ids, entity_ids, extra_column, extra_values) {
  clauses <- character()
  params <- list()

  if (length(review_ids) > 0) {
    clauses <- c(clauses, paste0("review_id IN (", placeholders(review_ids), ")"))
    params <- c(params, as.list(review_ids))
  }
  if (length(entity_ids) > 0) {
    clauses <- c(clauses, paste0("entity_id IN (", placeholders(entity_ids), ")"))
    params <- c(params, as.list(entity_ids))
  }
  if (length(extra_values) > 0) {
    clauses <- c(clauses, paste0(extra_column, " IN (", placeholders(extra_values), ")"))
    params <- c(params, as.list(extra_values))
  }

  if (length(clauses) == 0) {
    return(0L)
  }

  count_query(
    conn,
    sprintf(
      "SELECT COUNT(*) AS n FROM %s WHERE %s",
      table,
      paste(clauses, collapse = " OR ")
    ),
    params
  )
}

count_relevant_rows <- function(conn) {
  entity_ids <- db_fetch_params(
    conn,
    paste0(
      "SELECT entity_id FROM ndd_entity ",
      "WHERE hgnc_id = ? OR disease_ontology_id_version IN (",
      placeholders(TEST_ONTOLOGIES),
      ")"
    ),
    c(list(TEST_HGNC), as.list(TEST_ONTOLOGIES))
  )$entity_id

  review_ids <- if (length(entity_ids) > 0) {
    db_fetch_params(
      conn,
      paste0(
        "SELECT review_id FROM ndd_entity_review WHERE entity_id IN (",
        placeholders(entity_ids),
        ")"
      ),
      as.list(entity_ids)
    )$review_id
  } else {
    integer()
  }

  c(
    ndd_entity = count_query(
      conn,
      paste0(
        "SELECT COUNT(*) AS n FROM ndd_entity ",
        "WHERE hgnc_id = ? OR disease_ontology_id_version IN (",
        placeholders(TEST_ONTOLOGIES),
        ")"
      ),
      c(list(TEST_HGNC), as.list(TEST_ONTOLOGIES))
    ),
    ndd_entity_review = if (length(entity_ids) > 0) {
      count_query(
        conn,
        paste0(
          "SELECT COUNT(*) AS n FROM ndd_entity_review WHERE entity_id IN (",
          placeholders(entity_ids),
          ")"
        ),
        as.list(entity_ids)
      )
    } else {
      0L
    },
    ndd_entity_status = if (length(entity_ids) > 0) {
      count_query(
        conn,
        paste0(
          "SELECT COUNT(*) AS n FROM ndd_entity_status WHERE entity_id IN (",
          placeholders(entity_ids),
          ")"
        ),
        as.list(entity_ids)
      )
    } else {
      0L
    },
    ndd_review_phenotype_connect = count_join_table(
      conn,
      "ndd_review_phenotype_connect",
      review_ids,
      entity_ids,
      "phenotype_id",
      TEST_PHENOTYPE
    ),
    ndd_review_publication_join = count_join_table(
      conn,
      "ndd_review_publication_join",
      review_ids,
      entity_ids,
      "publication_id",
      c(TEST_PUBLICATION, TEST_BOGUS_PMIDS)
    ),
    ndd_review_variation_ontology_connect = count_join_table(
      conn,
      "ndd_review_variation_ontology_connect",
      review_ids,
      entity_ids,
      "vario_id",
      TEST_VARIO
    )
  )
}

count_publication_rejection_rows <- function(conn) {
  c(
    publication = count_query(
      conn,
      paste0(
        "SELECT COUNT(*) AS n FROM publication WHERE publication_id IN (",
        placeholders(TEST_BOGUS_PMIDS),
        ")"
      ),
      as.list(TEST_BOGUS_PMIDS)
    ),
    ndd_entity = count_query(
      conn,
      "SELECT COUNT(*) AS n FROM ndd_entity WHERE hgnc_id = ?",
      list(TEST_HGNC)
    ),
    ndd_entity_review = count_query(
      conn,
      paste0(
        "SELECT COUNT(*) AS n FROM ndd_entity_review r ",
        "JOIN ndd_entity e ON e.entity_id = r.entity_id WHERE e.hgnc_id = ?"
      ),
      list(TEST_HGNC)
    ),
    ndd_entity_status = count_query(
      conn,
      paste0(
        "SELECT COUNT(*) AS n FROM ndd_entity_status s ",
        "JOIN ndd_entity e ON e.entity_id = s.entity_id WHERE e.hgnc_id = ?"
      ),
      list(TEST_HGNC)
    ),
    ndd_review_publication_join = count_query(
      conn,
      paste0(
        "SELECT COUNT(*) AS n FROM ndd_review_publication_join ",
        "WHERE publication_id IN (",
        placeholders(TEST_BOGUS_PMIDS),
        ")"
      ),
      as.list(TEST_BOGUS_PMIDS)
    )
  )
}

unrelated_pubmed_xml <- function() {
  '<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation>
      <PMID>11111111</PMID>
      <Article>
        <ArticleTitle>Resolvable unrelated article</ArticleTitle>
        <Abstract><AbstractText>Unrelated article for PubMed miss tests.</AbstractText></Abstract>
        <ELocationID EIdType="doi">10.9999/unrelated</ELocationID>
        <Journal>
          <Title>SysNDD Test Journal</Title>
          <ISOAbbreviation>SysNDD Test J</ISOAbbreviation>
        </Journal>
        <AuthorList>
          <Author>
            <LastName>Curator</LastName>
            <ForeName>Test</ForeName>
            <AffiliationInfo>SysNDD test fixture</AffiliationInfo>
          </Author>
        </AuthorList>
      </Article>
    </MedlineCitation>
    <PubmedData>
      <History>
        <PubMedPubDate Pubstatus="pubmed">
          <Year>2026</Year><Month>1</Month><Day>1</Day>
        </PubMedPubDate>
      </History>
      <ArticleIdList>
        <ArticleId IdType="pubmed">11111111</ArticleId>
        <ArticleId IdType="doi">10.9999/unrelated</ArticleId>
      </ArticleIdList>
    </PubmedData>
  </PubmedArticle>
</PubmedArticleSet>'
}

with_entity_rename_fixture <- function(code) {
  skip_if_no_test_db()

  conn <- get_test_db_connection()
  pool <- NULL
  schema_ready <- FALSE
  on.exit({
    if (!is.null(pool)) {
      pool::poolClose(pool)
    }
    if (schema_ready) {
      cleanup_entity_rename_fixture(conn)
    }
    DBI::dbDisconnect(conn)
  }, add = TRUE)

  skip_if_missing_entity_rename_schema(conn)
  schema_ready <- TRUE

  cleanup_entity_rename_fixture(conn)
  seed_reference_rows(conn)
  pool <- make_test_pool()

  eval(substitute(code), envir = environment(), enclos = parent.frame())
}

test_that("svc_entity_rename_full preserves approval state on the new entity", {
  with_entity_rename_fixture({
    user_id <- 1L
    seed <- seed_approved_entity_bundle(conn, SOURCE_ONTOLOGY, user_id = user_id)

    result <- svc_entity_rename_full(
      rename_payload(seed$entity_id, DEST_ONTOLOGY),
      user_id = user_id,
      pool = pool
    )

    expect_equal(result$status, 200)
    expect_equal(result$message, "OK. Entity renamed.")
    expect_s3_class(result$entry, "tbl_df")
    expect_true(all(c("entity_id", "review_id", "status_id") %in% names(result$entry)))

    new_entity_id <- as.integer(result$entry$entity_id[[1]])
    new_review_id <- as.integer(result$entry$review_id[[1]])
    new_status_id <- as.integer(result$entry$status_id[[1]])

    old_entity <- fetch_entity_row(conn, seed$entity_id)
    new_entity <- fetch_entity_row(conn, new_entity_id)
    new_review <- fetch_review_row(conn, new_review_id)
    new_status <- fetch_status_row(conn, new_status_id)

    expect_equal(as.integer(old_entity$is_active[[1]]), 0L)
    expect_equal(as.integer(old_entity$replaced_by[[1]]), new_entity_id)

    expect_equal(as.integer(new_entity$is_active[[1]]), 1L)
    expect_true(is.na(new_entity$replaced_by[[1]]))
    expect_equal(new_entity$disease_ontology_id_version[[1]], DEST_ONTOLOGY)

    expect_equal(as.integer(new_review$entity_id[[1]]), new_entity_id)
    expect_equal(as.integer(new_review$is_primary[[1]]), 1L)
    expect_equal(as.integer(new_review$review_approved[[1]]), 1L)
    expect_equal(as.integer(new_review$approving_user_id[[1]]), user_id)

    expect_equal(as.integer(new_status$entity_id[[1]]), new_entity_id)
    expect_equal(as.integer(new_status$is_active[[1]]), 1L)
    expect_equal(as.integer(new_status$status_approved[[1]]), 1L)
    expect_equal(as.integer(new_status$approving_user_id[[1]]), user_id)

    expect_equal(
      count_query(
        conn,
        paste0(
          "SELECT COUNT(*) AS n FROM ndd_review_publication_join ",
          "WHERE review_id = ? AND entity_id = ? AND publication_id = ? ",
          "AND publication_type = ?"
        ),
        list(new_review_id, new_entity_id, TEST_PUBLICATION, "additional_references")
      ),
      1L
    )
    expect_equal(
      count_query(
        conn,
        paste0(
          "SELECT COUNT(*) AS n FROM ndd_review_phenotype_connect ",
          "WHERE review_id = ? AND entity_id = ? AND phenotype_id = ? ",
          "AND modifier_id = ?"
        ),
        list(new_review_id, new_entity_id, TEST_PHENOTYPE, 1L)
      ),
      1L
    )
    expect_equal(
      count_query(
        conn,
        paste0(
          "SELECT COUNT(*) AS n FROM ndd_review_variation_ontology_connect ",
          "WHERE review_id = ? AND entity_id = ? AND vario_id = ? ",
          "AND modifier_id = ?"
        ),
        list(new_review_id, new_entity_id, TEST_VARIO, 1L)
      ),
      1L
    )
  })
})

test_that("svc_entity_rename_full rolls back when a downstream insert fails", {
  with_entity_rename_fixture({
    user_id <- 1L
    seed <- seed_approved_entity_bundle(conn, SOURCE_ONTOLOGY, user_id = user_id)
    before_counts <- count_relevant_rows(conn)

    fn <- function_with_cloned_env(svc_entity_rename_full)
    mockery::stub(
      fn,
      "phenotype_connect_to_review",
      function(...) stop("forced phenotype copy failure")
    )

    result <- fn(
      rename_payload(seed$entity_id, ROLLBACK_DEST_ONTOLOGY),
      user_id = user_id,
      pool = pool
    )

    expect_equal(result$status, 500)
    expect_equal(count_relevant_rows(conn), before_counts)

    source_entity <- fetch_entity_row(conn, seed$entity_id)
    expect_equal(as.integer(source_entity$is_active[[1]]), 1L)
    expect_true(is.na(source_entity$replaced_by[[1]]))
  })
})

test_that("entity submission with unresolvable PMID returns 400 and writes nothing", {
  with_entity_rename_fixture({
    before_counts <- count_publication_rejection_rows(conn)

    info_fn <- function_with_cloned_env(info_from_pmid)
    mockery::stub(
      info_fn,
      "pubmed_fetch_xml",
      function(...) unrelated_pubmed_xml()
    )

    fn <- function_with_cloned_env(new_publication)
    mockery::stub(fn, "check_pmid", function(...) TRUE)
    assign("info_from_pmid", info_fn, envir = environment(fn))
    assign("pool", pool, envir = environment(fn))

    result <- tryCatch(
      fn(tibble::tibble(
        publication_id = TEST_BOGUS_PMIDS,
        publication_type = rep("additional_references", length(TEST_BOGUS_PMIDS))
      )),
      publication_fetch_error = function(e) {
        list(status = 400, message = e$message)
      }
    )

    expect_equal(result$status, 400)
    expect_match(result$message, "PMIDs not retrievable", fixed = TRUE)
    expect_match(result$message, "PMID:99999991", fixed = TRUE)
    expect_match(result$message, "PMID:99999992", fixed = TRUE)
    expect_equal(count_publication_rejection_rows(conn), before_counts)
  })
})

test_that("POST /api/entity/create returns endpoint 400 for unresolvable PMID and writes nothing", {
  with_entity_rename_fixture({
    before_counts <- count_publication_rejection_rows(conn)

    info_fn <- function_with_cloned_env(info_from_pmid)
    mockery::stub(
      info_fn,
      "pubmed_fetch_xml",
      function(...) unrelated_pubmed_xml()
    )

    new_publication_fn <- function_with_cloned_env(new_publication)
    mockery::stub(new_publication_fn, "check_pmid", function(...) TRUE)
    assign("info_from_pmid", info_fn, envir = environment(new_publication_fn))
    assign("pool", pool, envir = environment(new_publication_fn))

    env <- new.env(parent = globalenv())
    env$require_role <- function(req, res, min_role) invisible(TRUE)
    env$pool <- pool
    env$new_publication <- new_publication_fn
    env$genereviews_from_pmid <- function(...) FALSE

    handler <- extract_entity_handler("^#\\*\\s+@post\\s+/create\\s*$", env)
    req <- list(
      user_id = 1L,
      argsBody = list(
        create_json = list(
          entity = list(
            hgnc_id = TEST_HGNC,
            hpo_mode_of_inheritance_term = TEST_MOI,
            disease_ontology_id_version = DEST_ONTOLOGY,
            ndd_phenotype = 1L
          ),
          review = list(
            synopsis = list("Entity create publication preflight regression."),
            comment = "unresolvable PMID test",
            literature = list(
              additional_references = list(value = TEST_BOGUS_PMIDS),
              gene_review = list()
            ),
            phenotypes = list(),
            variation_ontology = list()
          ),
          status = list(
            category_id = 1L,
            problematic = 0L
          )
        )
      )
    )
    res <- make_mock_res()

    result <- handler(req = req, res = res, direct_approval = FALSE)

    expected_message <- paste(
      "Publication error: Bad Request. PMIDs not retrievable from PubMed:",
      paste(TEST_BOGUS_PMIDS, collapse = ", ")
    )
    expect_equal(result$status, 400)
    expect_equal(res$status, 400)
    expect_equal(result$message, expected_message)
    expect_equal(result$error, paste(
      "PMIDs not retrievable from PubMed:",
      paste(TEST_BOGUS_PMIDS, collapse = ", ")
    ))
    expect_equal(count_publication_rejection_rows(conn), before_counts)
  })
})

test_that("svc_entity_rename_full returns 404 when source entity is missing", {
  with_entity_rename_fixture({
    missing_id <- as.integer(db_fetch_params(
      conn,
      "SELECT COALESCE(MAX(entity_id), 0) + 1000000 AS entity_id FROM ndd_entity"
    )$entity_id[[1]])

    result <- svc_entity_rename_full(
      rename_payload(missing_id, DEST_ONTOLOGY),
      user_id = 1L,
      pool = pool
    )

    expect_equal(result$status, 404)
    expect_equal(result$message, "Not Found. Source entity does not exist.")
  })
})

test_that("svc_entity_rename_full returns 400 when ontology is unchanged", {
  with_entity_rename_fixture({
    seed <- seed_approved_entity_bundle(
      conn,
      SOURCE_ONTOLOGY,
      with_joins = FALSE
    )

    result <- svc_entity_rename_full(
      rename_payload(seed$entity_id, SOURCE_ONTOLOGY),
      user_id = 1L,
      pool = pool
    )

    expect_equal(result$status, 400)
    expect_equal(
      result$message,
      "Bad Request. New disease_ontology_id_version is identical to the current one."
    )
  })
})

test_that("svc_entity_rename_full returns 409 when destination quadruple exists", {
  with_entity_rename_fixture({
    seed <- seed_approved_entity_bundle(
      conn,
      SOURCE_ONTOLOGY,
      with_joins = FALSE
    )
    conflict <- seed_approved_entity_bundle(
      conn,
      CONFLICT_DEST_ONTOLOGY,
      with_joins = FALSE
    )

    result <- svc_entity_rename_full(
      rename_payload(seed$entity_id, CONFLICT_DEST_ONTOLOGY),
      user_id = 1L,
      pool = pool
    )

    expect_equal(result$status, 409)
    expect_equal(result$message, "Conflict. Destination quadruple already exists.")
    expect_true(!is.null(result$entry))
    expect_equal(as.integer(result$entry$entity_id[[1]]), conflict$entity_id)
  })
})
