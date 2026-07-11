# tests/testthat/test-unit-entity-endpoint-services.R
# Unit tests for the #346 Wave 3 entity endpoint service extraction:
#   - services/entity-read-endpoint-service.R
#   - services/entity-submission-endpoint-service.R
#
# Pure-logic pieces (no pool/DB) are exercised directly. DB-touching
# orchestrators are gated with skip_if_no_test_db().
#
# Note on scope: the `POST /entity/create` publication-preparation-before-
# transaction / no-write-on-failure logic intentionally stays INLINE in
# entity_endpoints.R (see entity-submission-endpoint-service.R's header
# comment) so it is not duplicated here — it remains covered by the existing
# test-integration-entity-rename.R handler-extraction test, which this
# refactor must not break.

library(testthat)
library(dplyr)
library(tibble)
library(tidyr)
library(stringr)
library(purrr)

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/response-fields-helpers.R", local = FALSE)
source_api_file("functions/entity-helpers.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)
source_api_file("functions/entity-repository.R", local = FALSE)
source_api_file("functions/review-repository.R", local = FALSE)
source_api_file("services/entity-service.R", local = FALSE)
source_api_file("services/entity-read-endpoint-service.R", local = FALSE)
source_api_file("services/entity-submission-endpoint-service.R", local = FALSE)

# generate_tibble_fspec_mem is normally bound at API startup from
# bootstrap/init_cache.R (memoise::memoise(generate_tibble_fspec, cache = cm)).
# For unit tests, alias it to the unmemoised implementation directly —
# memoisation is a caching optimization, not a behavior difference.
if (!exists("generate_tibble_fspec_mem")) {
  generate_tibble_fspec_mem <- generate_tibble_fspec
}

function_with_cloned_env <- function(fn) {
  environment(fn) <- rlang::env_clone(environment(fn))
  fn
}

# =============================================================================
# svc_entity_compact_flag()
# =============================================================================

test_that("svc_entity_compact_flag coerces plumber-style truthy strings", {
  expect_true(svc_entity_compact_flag("true"))
  expect_true(svc_entity_compact_flag("TRUE"))
  expect_true(svc_entity_compact_flag("1"))
  expect_true(svc_entity_compact_flag("yes"))
  expect_true(svc_entity_compact_flag(list("true")))
})

test_that("svc_entity_compact_flag rejects falsy/unknown strings", {
  expect_false(svc_entity_compact_flag("false"))
  expect_false(svc_entity_compact_flag("FALSE"))
  expect_false(svc_entity_compact_flag("0"))
  expect_false(svc_entity_compact_flag("no"))
  expect_false(svc_entity_compact_flag(""))
  expect_false(svc_entity_compact_flag("banana"))
})

# =============================================================================
# svc_entity_shape_entity_page() — compact vs. global query behavior, detail
# columns, cursor pagination, links
# =============================================================================

make_entity_view_fixture <- function(n = 5) {
  tibble::tibble(
    entity_id = 1:n,
    symbol = paste0("GENE", 1:n),
    category = rep(c("Definitive", "Moderate"), length.out = n),
    disease_ontology_name = paste0("Disease ", 1:n)
  )
}

test_that("svc_entity_shape_entity_page compact mode: count_filtered == count", {
  filtered_set <- make_entity_view_fixture(2)

  result <- svc_entity_shape_entity_page(
    sysndd_db_disease_table = filtered_set,
    ndd_entity_view = filtered_set,
    sort = "entity_id", filter = "", fields = "",
    page_after = 0, page_size = "all",
    fspec = "entity_id,symbol,category",
    is_compact = TRUE,
    api_base_url = "http://test.local"
  )

  fspec_tbl <- result$meta$fspec[[1]]
  expect_true(all(fspec_tbl$count == fspec_tbl$count_filtered))
})

test_that("svc_entity_shape_entity_page default mode: global vs filtered counts differ", {
  full_view <- make_entity_view_fixture(5)
  working_set <- full_view %>% dplyr::filter(category == "Definitive")
  expect_lt(nrow(working_set), nrow(full_view))

  result <- svc_entity_shape_entity_page(
    sysndd_db_disease_table = working_set,
    ndd_entity_view = full_view,
    sort = "entity_id", filter = "any(category,Definitive)", fields = "",
    page_after = 0, page_size = "all",
    fspec = "entity_id,category",
    is_compact = FALSE,
    api_base_url = "http://test.local"
  )

  # fspec `count` is the number of DISTINCT values for the column (drives the
  # filter-dropdown option count), not a row count — generate_tibble_fspec()
  # computes it via `lengths(selectOptions)` over the deduplicated values.
  fspec_tbl <- result$meta$fspec[[1]]
  category_row <- fspec_tbl %>% dplyr::filter(key == "category")
  expect_equal(category_row$count, dplyr::n_distinct(full_view$category))
  expect_equal(category_row$count_filtered, dplyr::n_distinct(working_set$category))
  expect_lt(category_row$count_filtered, category_row$count)
})

test_that("svc_entity_shape_entity_page restricts data to requested fields plus entity_id", {
  view <- make_entity_view_fixture(3)

  result <- svc_entity_shape_entity_page(
    sysndd_db_disease_table = view,
    ndd_entity_view = view,
    sort = "entity_id", filter = "", fields = "symbol",
    page_after = 0, page_size = "all",
    fspec = "entity_id,symbol",
    is_compact = TRUE,
    api_base_url = "http://test.local"
  )

  expect_setequal(colnames(result$data), c("entity_id", "symbol"))
})

test_that("svc_entity_shape_entity_page builds links with the api_base_url and query params", {
  view <- make_entity_view_fixture(3)

  result <- svc_entity_shape_entity_page(
    sysndd_db_disease_table = view,
    ndd_entity_view = view,
    sort = "symbol", filter = "any(category,Definitive)", fields = "symbol",
    page_after = 0, page_size = "1",
    fspec = "entity_id,symbol",
    is_compact = TRUE,
    api_base_url = "http://test.local/api/entity"
  )

  self_link <- result$links$self[[1]]
  expect_true(grepl("^http://test\\.local/api/entity", self_link))
  expect_true(grepl("sort=symbol", self_link, fixed = TRUE))
  expect_true(grepl("filter=any%28category%2CDefinitive%29|filter=any\\(category,Definitive\\)", self_link))
})

# =============================================================================
# entity-read-endpoint-service.R approved-review gate (#3) — analog of
# test-unit-public-approved-review-guard.R, adjusted for the service split
# =============================================================================

test_that("entity-read-endpoint-service.R never filters ndd_entity_review by is_primary alone", {
  src <- paste(readLines("../../services/entity-read-endpoint-service.R", warn = FALSE), collapse = "\n")
  bad <- gregexpr("filter\\([^)]*is_primary[^)]*\\)", src)[[1]]
  if (bad[1] != -1) {
    for (i in seq_along(bad)) {
      frag <- substr(src, bad[i], bad[i] + attr(bad, "match.length")[i] - 1)
      expect_true(grepl("review_approved", frag),
                  info = paste("is_primary filter without review_approved:", frag))
    }
  }
  succeed()
})

test_that("entity-read-endpoint-service.R legacy connect-table reads stay gated by approved_review_ids", {
  src <- paste(readLines("../../services/entity-read-endpoint-service.R", warn = FALSE), collapse = "\n")

  # The 3 legacy (current_review = FALSE) connect-table reads filter on the
  # caller-supplied approved_review_ids (itself sourced from
  # primary_approved_reviews() at the endpoint layer), not an ungated set.
  expect_true(grepl(
    "filter(is_active == 1 & review_id %in% approved_review_ids)", src, fixed = TRUE
  ))
  expect_true(grepl(
    "filter(is_active == 1 & entity_id == sysndd_id & review_id %in% approved_review_ids)",
    src, fixed = TRUE
  ))
  expect_true(grepl(
    "filter(is_reviewed == 1 & review_id %in% approved_review_ids)", src, fixed = TRUE
  ))

  # No connect-table read filters is_active/is_reviewed with no review_id gate.
  expect_false(grepl("filter(is_active == 1)", src, fixed = TRUE))
  expect_false(grepl("filter(is_reviewed == 1)", src, fixed = TRUE))
})

test_that("entity_endpoints.R still computes the approved_review_ids gate for the 3 legacy branches", {
  src <- paste(readLines("../../endpoints/entity_endpoints.R", warn = FALSE), collapse = "\n")
  n_gate <- length(gregexpr("approved_review_ids <- primary_approved_reviews", src)[[1]])
  expect_gte(n_gate, 3)
})

# =============================================================================
# svc_entity_deactivate_decision() — pure mutation-only-deactivate logic
# =============================================================================

base_deactivate_original <- tibble::tibble(
  entity_id = 42L,
  hgnc_id = "HGNC:1234",
  hpo_mode_of_inheritance_term = "HP:0000006",
  ndd_phenotype = 1L,
  is_active = 1L,
  replaced_by = NA_integer_
)

test_that("svc_entity_deactivate_decision approves a pure is_active flip", {
  deactivate_data <- list(entity = list(
    entity_id = 42L,
    hgnc_id = "HGNC:1234",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = 1L,
    is_active = 0L,
    replaced_by = 99L
  ))

  decision <- svc_entity_deactivate_decision(deactivate_data, base_deactivate_original)

  expect_equal(decision$action, "deactivate")
  expect_equal(decision$entity_id, 42L)
  expect_equal(decision$replaced_by, 99L)
})

test_that("svc_entity_deactivate_decision rejects a non-mutation field change", {
  deactivate_data <- list(entity = list(
    entity_id = 42L,
    hgnc_id = "HGNC:9999", # changed — not allowed
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = 1L,
    is_active = 0L,
    replaced_by = NA
  ))

  decision <- svc_entity_deactivate_decision(deactivate_data, base_deactivate_original)

  expect_equal(decision$action, "reject")
  expect_equal(decision$error, "This endpoint only allows deactivating an entity.")
})

test_that("svc_entity_deactivate_decision rejects a no-op (is_active unchanged)", {
  deactivate_data <- list(entity = list(
    entity_id = 42L,
    hgnc_id = "HGNC:1234",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = 1L,
    is_active = 1L, # unchanged
    replaced_by = NA
  ))

  decision <- svc_entity_deactivate_decision(deactivate_data, base_deactivate_original)

  expect_equal(decision$action, "reject")
})

test_that("svc_entity_deactivate_decision normalizes a string 'NULL' replaced_by to NA", {
  deactivate_data <- list(entity = list(
    entity_id = 42L,
    hgnc_id = "HGNC:1234",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = 1L,
    is_active = 0L,
    replaced_by = "NULL"
  ))

  decision <- svc_entity_deactivate_decision(deactivate_data, base_deactivate_original)

  expect_equal(decision$action, "deactivate")
  expect_true(is.na(decision$replaced_by))
})

# =============================================================================
# svc_entity_create_finalize() — normalization, server attribution, direct
# approval, 201/cache invalidation (svc_entity_create_full is mocked)
# =============================================================================

make_create_data <- function(phenotypes = NULL, variation_ontology = NULL) {
  list(
    entity = list(
      hgnc_id = "HGNC:1234",
      hpo_mode_of_inheritance_term = "HP:0000006",
      disease_ontology_id_version = "OMIM:123456_1",
      ndd_phenotype = 1L
    ),
    review = list(
      synopsis = list("A synopsis."),
      comment = "a comment",
      phenotypes = phenotypes,
      variation_ontology = variation_ontology
    ),
    status = list(category_id = 1L, problematic = 0L)
  )
}

test_that("svc_entity_create_finalize normalizes modifier-phenotype value pairs", {
  create_data <- make_create_data(
    phenotypes = list(value = c("1-HP:0001249", "0-HP:0000252"))
  )

  captured <- NULL
  fn <- function_with_cloned_env(svc_entity_create_finalize)
  mockery::stub(fn, "svc_entity_create_full", function(...) {
    captured <<- list(...)
    list(status = 200, message = "OK. Entry created.",
         entry = tibble::tibble(entity_id = 1L, review_id = 2L, status_id = 3L))
  })

  fn(create_data = create_data, publications = NULL, direct_approval = FALSE,
     user_id = 7L, pool = NULL)

  expect_s3_class(captured$phenotypes, "tbl_df")
  expect_setequal(colnames(captured$phenotypes), c("phenotype_id", "modifier_id"))
  expect_setequal(captured$phenotypes$phenotype_id, c("HP:0001249", "HP:0000252"))
  expect_setequal(captured$phenotypes$modifier_id, c("1", "0"))
})

test_that("svc_entity_create_finalize normalizes modifier-vario value pairs", {
  create_data <- make_create_data(
    variation_ontology = list(value = c("2-VariO:0002"))
  )

  captured <- NULL
  fn <- function_with_cloned_env(svc_entity_create_finalize)
  mockery::stub(fn, "svc_entity_create_full", function(...) {
    captured <<- list(...)
    list(status = 200, message = "OK. Entry created.",
         entry = tibble::tibble(entity_id = 1L, review_id = 2L, status_id = 3L))
  })

  fn(create_data = create_data, publications = NULL, direct_approval = FALSE,
     user_id = 7L, pool = NULL)

  expect_s3_class(captured$variation_ontology, "tbl_df")
  # sapply() over a length-1 character vector names its result by the input
  # value itself (pre-existing behavior, unchanged by this refactor) — strip
  # names before comparing.
  expect_equal(unname(captured$variation_ontology$vario_id), "VariO:0002")
  expect_equal(unname(captured$variation_ontology$modifier_id), "2")
})

test_that("svc_entity_create_finalize server-attributes approving_user_id only when direct_approval is TRUE", {
  create_data <- make_create_data()
  captured <- NULL
  capture_stub <- function(...) {
    captured <<- list(...)
    list(status = 200, message = "OK. Entry created.",
         entry = tibble::tibble(entity_id = 1L, review_id = 2L, status_id = 3L))
  }

  fn_direct <- function_with_cloned_env(svc_entity_create_finalize)
  mockery::stub(fn_direct, "svc_entity_create_full", capture_stub)
  fn_direct(create_data = create_data, publications = NULL, direct_approval = TRUE,
             user_id = 11L, pool = NULL)
  expect_equal(captured$approving_user_id, 11L)
  expect_true(captured$direct_approval)

  captured <- NULL
  fn_indirect <- function_with_cloned_env(svc_entity_create_finalize)
  mockery::stub(fn_indirect, "svc_entity_create_full", capture_stub)
  fn_indirect(create_data = create_data, publications = NULL, direct_approval = FALSE,
               user_id = 11L, pool = NULL)
  expect_null(captured$approving_user_id)
  expect_false(captured$direct_approval)
})

test_that("svc_entity_create_finalize invalidates caches on success but not on failure", {
  create_data <- make_create_data()

  news_calls <- 0L
  stat_calls <- 0L
  make_counters <- function() {
    news_calls <<- 0L
    stat_calls <<- 0L
    list(
      news = memoise::memoise(function() {
        news_calls <<- news_calls + 1L
        news_calls
      }),
      stat = memoise::memoise(function() {
        stat_calls <<- stat_calls + 1L
        stat_calls
      })
    )
  }

  # Success: both caches are forgotten (next call recomputes).
  counters <- make_counters()
  fn_ok <- function_with_cloned_env(svc_entity_create_finalize)
  assign("generate_gene_news_tibble_mem", counters$news, envir = environment(fn_ok))
  assign("generate_stat_tibble_mem", counters$stat, envir = environment(fn_ok))
  mockery::stub(fn_ok, "svc_entity_create_full", function(...) {
    list(status = 200, message = "OK. Entry created.",
         entry = tibble::tibble(entity_id = 1L, review_id = 2L, status_id = 3L))
  })
  counters$news()
  counters$stat()
  fn_ok(create_data = create_data, publications = NULL, direct_approval = FALSE,
        user_id = 7L, pool = NULL)
  expect_equal(counters$news(), 2L) # forgotten -> recomputed
  expect_equal(counters$stat(), 2L)

  # Failure: caches are left untouched (still cached at 1).
  counters2 <- make_counters()
  fn_fail <- function_with_cloned_env(svc_entity_create_finalize)
  assign("generate_gene_news_tibble_mem", counters2$news, envir = environment(fn_fail))
  assign("generate_stat_tibble_mem", counters2$stat, envir = environment(fn_fail))
  mockery::stub(fn_fail, "svc_entity_create_full", function(...) {
    list(status = 409, message = "Conflict.", entry = NULL)
  })
  counters2$news()
  counters2$stat()
  fn_fail(create_data = create_data, publications = NULL, direct_approval = FALSE,
          user_id = 7L, pool = NULL)
  expect_equal(counters2$news(), 1L) # still cached
  expect_equal(counters2$stat(), 1L)
})

# =============================================================================
# DB-touching orchestrators (skip on host, no RMariaDB)
# =============================================================================
#
# Scope note: put_db_entity_deactivation() -> entity_deactivate() ->
# db_execute_statement() resolves its connection via get_db_connection() when
# no `conn` is passed (pre-existing behavior, unchanged by this refactor —
# the original inline handler also called put_db_entity_deactivation()
# without threading `pool` through). That means a DB test of
# svc_entity_deactivate_request()'s *approval* path would open a connection
# outside this test's own transaction/rollback, so it is deliberately not
# exercised here; svc_entity_deactivate_decision() (pure, tested above)
# covers the mutation-only decision logic that path depends on. The reject
# path never reaches put_db_entity_deactivation(), so it is safe to exercise
# end-to-end below alongside the simplest read-only orchestrators.

test_that("svc_entity_deactivate_request rejects a non-mutation change against a real ndd_entity row", {
  skip_if_no_test_db()

  with_test_db_transaction({
    con <- getOption(".test_db_con")

    # The default local/PR test DB (sysndd_db_test) starts empty; mirrors the
    # repo convention (test-integration-entity-rename.R, test-unit-metadata-refresh.R,
    # helper-publication-dates.R::skip_if_missing_publication_backfill_schema())
    # of skipping gracefully rather than erroring when the schema isn't loaded.
    required_tables <- c(
      "user", "non_alt_loci_set", "mode_of_inheritance_list",
      "disease_ontology_set", "ndd_entity"
    )
    missing_tables <- required_tables[!vapply(
      required_tables, DBI::dbExistsTable, logical(1), conn = con
    )]
    if (length(missing_tables) > 0) {
      skip(paste(
        "Test database schema is not initialized; missing table(s):",
        paste(missing_tables, collapse = ", ")
      ))
    }

    DBI::dbExecute(con, "INSERT IGNORE INTO `user` (user_id, user_name) VALUES (1, 'svc-entity-endpoint-test')") # nolint: line_length_linter
    hgnc_id <- paste0("HGNC:", sample(9000000:9999999, 1))
    moi_term <- paste0("HP:", sample(9000000:9999999, 1))
    ontology_id <- paste0("OMIM:", sample(9000000:9999999, 1), "_1")
    DBI::dbExecute(
      con,
      "INSERT INTO non_alt_loci_set (hgnc_id, symbol, name) VALUES (?, ?, ?)",
      params = list(hgnc_id, "SVCENTITYTEST", "svc entity endpoint test gene")
    )
    DBI::dbExecute(
      con,
      paste0(
        "INSERT INTO mode_of_inheritance_list ",
        "(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name, ",
        "inheritance_filter, inheritance_short_text, is_active, sort) ",
        "VALUES (?, 'svc entity endpoint test inheritance', 'test', 'TST', 1, 9100001)"
      ),
      params = list(moi_term)
    )
    DBI::dbExecute(
      con,
      paste0(
        "INSERT INTO disease_ontology_set ",
        "(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, ",
        "disease_ontology_source, disease_ontology_is_specific, hgnc_id, ",
        "hpo_mode_of_inheritance_term, is_active) VALUES (?, ?, ?, 'OMIM', 1, ?, ?, 1)"
      ),
      params = list(
        ontology_id, str_remove(ontology_id, "_1$"), "svc entity endpoint test disease", hgnc_id, moi_term
      )
    )
    DBI::dbExecute(
      con,
      paste0(
        "INSERT INTO ndd_entity ",
        "(hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ",
        "ndd_phenotype, entry_user_id, is_active) VALUES (?, ?, ?, 1, 1, 1)"
      ),
      params = list(hgnc_id, moi_term, ontology_id)
    )
    entity_id <- as.integer(
      DBI::dbGetQuery(con, "SELECT LAST_INSERT_ID() AS id")$id[[1]]
    )

    # hgnc_id changed relative to the stored row -> mutation-only guard rejects.
    deactivate_data <- list(entity = list(
      entity_id = entity_id,
      hgnc_id = "HGNC:0",
      hpo_mode_of_inheritance_term = moi_term,
      ndd_phenotype = 1L,
      is_active = 0L,
      replaced_by = NA
    ))

    result <- svc_entity_deactivate_request(deactivate_data, deactivate_user_id = 1L, pool = con)

    expect_equal(result$http_status, 400)
    expect_equal(result$body$error, "This endpoint only allows deactivating an entity.")

    row <- DBI::dbGetQuery(con, "SELECT is_active FROM ndd_entity WHERE entity_id = ?", params = list(entity_id))
    expect_equal(as.integer(row$is_active[[1]]), 1L) # untouched
  })
})

test_that("svc_entity_review and svc_entity_status run against the real pool for a non-existent entity", {
  skip_if_no_test_db()
  # svc_entity_review() -> primary_approved_reviews() calls dplyr::tbl() against
  # a real DBI connection, which needs the {dbplyr} backend package; it is a
  # declared renv dependency (present in the container) but not always
  # installed on a host test runner, so skip gracefully rather than erroring.
  skip_if_not_installed("dbplyr")

  with_test_db_transaction({
    con <- getOption(".test_db_con")
    if (!DBI::dbExistsTable(con, "ndd_entity_review") ||
        !DBI::dbExistsTable(con, "ndd_entity_status_categories_list")) {
      testthat::skip("entity review/status tables not present in this test DB")
    }

    review_row <- svc_entity_review(-999999L, con)
    expect_equal(nrow(review_row), 1L)
    expect_equal(review_row$entity_id, -999999L)
    expect_true(is.na(review_row$review_id))

    status_rows <- svc_entity_status(-999999L, con)
    expect_equal(nrow(status_rows), 0L)
  })
})
