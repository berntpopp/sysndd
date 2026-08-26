# api/tests/testthat/test-integration-clustering-category-submit.R
#
# Real-MySQL integration coverage for the category-selected clustering
# gene-universe resolver (`clustering_resolve_category_universe()`,
# api/functions/clustering-gene-universe.R, #574 D1/D3). Complements the
# DB-free unit tests in test-unit-clustering-gene-universe.R (which use an
# in-memory RSQLite fixture) with assertions against the REAL `sysndd_db_test`
# MySQL `ndd_entity_view` -- proving entity-level resolution with no
# client-side filter and correct MySQL translation of the dbplyr pipeline.
#
# ---------------------------------------------------------------------------
# Deviation from the D3 plan brief, and why (documented per the task's own
# instructions):
#
# The plan brief's literal Step 1 asked this file to seed D1's fixture
# entities (incl. a 2nd "Definitive" gene) directly into `ndd_entity_view`'s
# base tables on the empty test DB. `ndd_entity_view` joins ~7 tables
# (ndd_entity + ndd_entity_status + ndd_entity_status_categories_list +
# boolean_list + disease_ontology_set + mode_of_inheritance_list +
# non_alt_loci_set) with a specific column/FK contract; self-seeding that
# chain here would be fragile, easy to silently drift from the real view
# definition, and largely redundant with the mandated live-container
# end-to-end verification (submitting `category_filter` against the running
# dev stack), which the controller performs separately.
#
# So this file PREFERS a populated view: it probes the live `ndd_entity_view`
# for a real, currently-active category with >=2 distinct NDD
# (`ndd_phenotype = 1`) genes and uses that when it exists, which on a
# populated clone gives genuine resolver-vs-real-MySQL-view coverage without
# fragile fixture seeding.
#
# UPDATE (#612): it no longer SKIPs when that probe finds nothing. It did, and
# a fresh/CI database ALWAYS finds nothing -- so these three tests ran only when
# an unrelated file happened to leave data behind, and reported green by
# skipping the rest of the time. `.clustering_seed_category_universe()` now
# seeds a minimal two-gene universe inside the caller's rollback instead. The
# concern above stands and is why the seed is minimal and commented: it must
# stay in step with the view's join contract.
# ---------------------------------------------------------------------------

library(testthat)
library(DBI)

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/clustering-gene-universe.R", local = FALSE)
# The resolver's `is.null(selector)` (NULL/default) branch calls
# `generate_ndd_hgnc_ids()` directly (it does NOT take `conn` on that path --
# see clustering-gene-universe.R), so it must be sourced here too, or Test 3
# below throws "could not find function" instead of exercising the branch.
source_api_file("functions/analyses-functions.R", local = FALSE)

#' Probe the live `ndd_entity_view` for one real, currently-active category
#' with >=2 distinct NDD (`ndd_phenotype = 1`) genes.
#'
#' Joins against `ndd_entity_status_categories_list WHERE is_active = 1` so
#' the returned category is guaranteed to pass
#' `clustering_resolve_category_universe()`'s own live allowlist check --
#' never returns a category that the resolver itself would reject as
#' unknown/inactive.
#'
#' @param conn DBI connection to the test database.
#' @return character(1) category name, or NULL if no such category exists
#'   (e.g. an empty/fresh test DB, or `ndd_entity_view` is absent).
.clustering_category_probe <- function(conn) {
  if (!DBI::dbExistsTable(conn, "ndd_entity_view")) {
    return(NULL)
  }
  if (!DBI::dbExistsTable(conn, "ndd_entity_status_categories_list")) {
    return(NULL)
  }

  counts <- tryCatch(
    DBI::dbGetQuery(
      conn,
      paste(
        "SELECT v.category AS category, COUNT(DISTINCT v.hgnc_id) AS gene_count",
        "FROM ndd_entity_view v",
        "INNER JOIN ndd_entity_status_categories_list c",
        "  ON c.category = v.category AND c.is_active = 1",
        "WHERE v.ndd_phenotype = 1",
        "GROUP BY v.category",
        "ORDER BY gene_count DESC"
      )
    ),
    error = function(e) NULL
  )
  if (is.null(counts) || nrow(counts) == 0L) {
    return(NULL)
  }

  eligible <- counts[counts$gene_count >= 2, , drop = FALSE]
  if (nrow(eligible) == 0L) {
    return(NULL)
  }

  as.character(eligible$category[[1]])
}


#' Seed two NDD entities sharing one approved category, so the probe above finds
#' something on a FRESH test database.
#'
#' Before this, all three tests below `skip()`ed whenever `ndd_entity_view` was
#' empty -- which is every CI run, because CI's database is migrated but not
#' populated. A test that only runs when someone else happened to leave data
#' behind is not a test (same lesson as the `OMIM:618524` residue dependency in
#' test-integration-mondo-index.R). Everything here is written inside the
#' caller's `with_test_db_transaction()`, so it rolls back.
#'
#' `ndd_entity_view` joins ndd_entity -> non_alt_loci_set, disease_ontology_set,
#' mode_of_inheritance_list, ndd_entity_status_approved_view (status_approved = 1
#' AND is_active = 1), ndd_entity_status_categories_list and boolean_list. Note
#' boolean_list and the category list are BASE-SCHEMA seeds and are deliberately
#' NOT inserted here: adding a second `logical = 1` row makes the view emit two
#' rows per entity and silently doubles every count.
#'
#' @param conn Connection inside the caller's open transaction.
#' @return The category name the seeded entities share.
.clustering_seed_category_universe <- function(conn) {
  # RMariaDB raises "Query has no parameters" when `params` is supplied for a
  # statement with no placeholders, so omit the argument entirely in that case.
  exec <- function(sql, params = list()) {
    if (length(params) == 0L) {
      return(DBI::dbExecute(conn, sql))
    }
    DBI::dbExecute(conn, sql, params = unname(params))
  }
  suffix <- as.integer(Sys.time()) %% 10000L
  # Pick an ACTIVE category rather than assuming category_id 1 is active: the
  # category list is admin-editable (soft-deactivatable via is_active), so
  # hardcoding an id could seed entities under a category
  # clustering_resolve_category_universe() then rejects. Activate one if the
  # whole list happens to be inactive -- still inside the caller's rollback.
  active <- DBI::dbGetQuery(
    conn,
    "SELECT category_id, category FROM ndd_entity_status_categories_list WHERE is_active = 1 LIMIT 1"
  )
  if (nrow(active) == 0L) {
    DBI::dbExecute(
      conn,
      "UPDATE ndd_entity_status_categories_list SET is_active = 1 WHERE category_id = 1"
    )
    active <- DBI::dbGetQuery(
      conn,
      "SELECT category_id, category FROM ndd_entity_status_categories_list WHERE category_id = 1"
    )
  }
  category_id <- as.integer(active$category_id[[1]])
  user_id <- 880000L + suffix
  moi <- DBI::dbGetQuery(
    conn, "SELECT hpo_mode_of_inheritance_term AS t FROM mode_of_inheritance_list LIMIT 1"
  )$t
  if (length(moi) == 0L) {
    exec("INSERT INTO mode_of_inheritance_list (hpo_mode_of_inheritance_term) VALUES ('HP:0000006')")
    moi <- "HP:0000006"
  }

  exec("INSERT INTO user (user_id, user_name) VALUES (?, ?)",
       list(user_id, paste0("clustering_seed_", suffix)))

  ontology <- sprintf("OMIM:%06d_1", 880000L + suffix %% 500L)
  exec(
    paste(
      "INSERT INTO disease_ontology_set",
      "(disease_ontology_id_version, disease_ontology_id, disease_ontology_name,",
      "disease_ontology_source, is_active) VALUES (?, ?, ?, 'test', 1)"
    ),
    list(ontology, sub("_1$", "", ontology), "Clustering seed disease")
  )

  # Two DISTINCT genes, so COUNT(DISTINCT hgnc_id) >= 2 for this category.
  for (index in seq_len(2L)) {
    hgnc <- sprintf("HGNC:%05d", 88000L + (suffix %% 400L) * 2L + index)
    exec("INSERT INTO non_alt_loci_set (hgnc_id, symbol) VALUES (?, ?)",
         list(hgnc, sprintf("CLSEED%d%d", suffix %% 1000L, index)))
    exec(
      paste(
        "INSERT INTO ndd_entity",
        "(hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version,",
        "ndd_phenotype, entry_user_id, is_active) VALUES (?, ?, ?, 1, ?, 1)"
      ),
      list(hgnc, moi, ontology, user_id)
    )
    entity_id <- test_db_last_insert_id(conn, "entity_id")
    exec(
      paste(
        "INSERT INTO ndd_entity_status",
        "(entity_id, category_id, is_active, status_user_id, status_approved,",
        "approving_user_id, problematic, comment)",
        "VALUES (?, ?, 1, ?, 1, ?, 0, 'clustering seed')"
      ),
      list(entity_id, category_id, user_id, user_id)
    )
  }

  as.character(active$category[[1]])
}

test_that("clustering_resolve_category_universe matches a direct MySQL query on the real ndd_entity_view", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    probe_category <- .clustering_category_probe(conn)
    if (is.null(probe_category)) {
      # Fresh/CI database: seed our own universe rather than skip.
      probe_category <- .clustering_seed_category_universe(conn)
    }

    resolved <- clustering_resolve_category_universe(probe_category, conn = conn)

    direct <- DBI::dbGetQuery(
      conn,
      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1 AND category = ?",
      params = list(probe_category)
    )$hgnc_id

    # Entity-level resolution, no client-side filter: the resolver's
    # dbplyr-generated SQL must select exactly the same gene set as a direct
    # equivalent query against the same live view.
    expect_setequal(resolved$hgnc_ids, direct)
    expect_identical(resolved$selector, probe_category)
    expect_identical(resolved$resolved_gene_count, length(direct))
  })
})

test_that("clustering_resolve_category_universe rejects an unknown category, naming the allowed set in the message", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    probe_category <- .clustering_category_probe(conn)
    if (is.null(probe_category)) {
      # Fresh/CI database: seed our own universe rather than skip.
      probe_category <- .clustering_seed_category_universe(conn)
    }

    err <- tryCatch(
      clustering_resolve_category_universe("Definative", conn = conn),
      error = function(e) e
    )

    expect_s3_class(err, "error_400")
    # The allowed active-category set is named in the MESSAGE (core/filters.R
    # serializes conditionMessage(err), not a separate `detail` field), and a
    # real currently-active category (the probe result) must appear in it.
    expect_match(conditionMessage(err), "Unknown or inactive")
    expect_match(conditionMessage(err), probe_category, fixed = TRUE)
  })
})

test_that("clustering_resolve_category_universe(NULL) matches the default all-NDD-genes SELECT", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    probe_category <- .clustering_category_probe(conn)
    if (is.null(probe_category)) {
      # Fresh/CI database: seed our own universe rather than skip.
      probe_category <- .clustering_seed_category_universe(conn)
    }

    # `generate_ndd_hgnc_ids()` (analyses-functions.R) reads the package-global
    # `pool` directly -- the resolver's `is.null(selector)` branch does NOT
    # forward `conn` to it (see clustering-gene-universe.R). Bind the global
    # `pool` to this transaction's connection for the duration of the call so
    # the NULL/default branch is exercised for real against the live view,
    # then restore whatever `pool` held before (mirrors the
    # test-unit-panels-endpoint.R / test-unit-endpoint-functions.R idiom).
    # base::get(), not bare get(): a fully-loaded API/worker R session has
    # `config::get` masking `get` (no `envir` argument there), which would
    # error "unused argument (envir = .GlobalEnv)" (Codex review fix; see
    # AGENTS.md "config::get masks base::get").
    old_pool <- if (exists("pool", envir = .GlobalEnv)) base::get("pool", envir = .GlobalEnv) else NULL
    assign("pool", conn, envir = .GlobalEnv)
    withr::defer({
      if (is.null(old_pool)) {
        if (exists("pool", envir = .GlobalEnv)) rm(pool, envir = .GlobalEnv)
      } else {
        assign("pool", old_pool, envir = .GlobalEnv)
      }
    })

    resolved <- clustering_resolve_category_universe(NULL, conn = conn)

    # Meaningful, not tautological: compares against a DIRECT query against
    # the real view, not against calling generate_ndd_hgnc_ids() a second
    # time -- proves the NULL/default branch resolves the all-NDD universe
    # correctly, independent of the resolver's own implementation.
    direct <- DBI::dbGetQuery(
      conn,
      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1"
    )$hgnc_id

    expect_setequal(resolved$hgnc_ids, direct)
    expect_null(resolved$selector)
    expect_identical(resolved$resolved_gene_count, length(direct))
  })
})

test_that("pool lookup uses base::get() so config::get masking (loaded API/worker env) cannot break it", {
  # Static source guard, not a runtime probe -- reproducing the mask requires
  # `library(config)` attached ahead of base on the search path (only true
  # inside a fully-booted API/worker R session, not host `testthat`; see
  # AGENTS.md "config::get masks base::get"). This file's own NULL-branch
  # `pool` swap (three tests above) must always use the masking-safe form
  # (Codex review fix: previously a bare `get("pool", envir = .GlobalEnv)`).
  # Targets the specific `old_pool <-` assignment line only -- not the whole
  # file body -- so this guard cannot accidentally match its own literals.
  src <- readLines(
    file.path(get_api_dir(), "tests", "testthat", "test-integration-clustering-category-submit.R"),
    warn = FALSE
  )
  pool_swap_line <- src[grepl("old_pool <-.*envir = \\.GlobalEnv", src)]

  expect_length(pool_swap_line, 1L)
  expect_match(pool_swap_line, "base::get\\(", fixed = FALSE)
})
