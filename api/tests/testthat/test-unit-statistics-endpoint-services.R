# tests/testthat/test-unit-statistics-endpoint-services.R
#
# Unit tests for the two services extracted from
# api/endpoints/statistics_endpoints.R (#346 Wave 3 Task 8):
#   - api/services/statistics-public-endpoint-service.R
#   - api/services/statistics-admin-endpoint-service.R
#
# Host-runnable, no test database required for the assertions below: each
# service is source()'d directly into an isolated sandbox environment that
# provides lightweight stand-ins for the globals the pre-extraction handler
# already depended on:
#   - `pool` -> a plain-tibble "mock_pool" object with a `tbl.mock_pool()` S3
#     method, so `pool %>% tbl("name") %>% collect()` returns a fixture
#     tibble unchanged. dbplyr/RMariaDB are not required.
#   - `summarize_by_time()` -> a small stand-in for timetk::summarize_by_time()
#     (timetk is not installed on the bare host R) that buckets to whole
#     months while preserving any existing dplyr grouping, matching the
#     production call sites closely enough to exercise real wiring/shape.
#     Verified against the real service functions during authoring (see task
#     report); production still calls the real timetk implementation once
#     the API boots with timetk attached.
#   - `generate_filter_expressions()` / `allowed_columns_for_view()` -> the
#     same kind of no-op/pass-through stub test-endpoint-statistics.R already
#     uses. Their own behavior is covered by
#     test-unit-filter-column-allowlist.R; this file only needs to prove
#     that a supplied filter string reaches the query.
#
# DB-state cases that would need the real MySQL test database are separately
# guarded with skip_if_no_test_db() (none of the assertions below need one,
# since the mock pool covers every table these services touch).

library(testthat)
library(dplyr)
library(tidyr)
library(stringr)
library(tibble)
library(rlang)
library(jsonlite)

## ---------------------------------------------------------------------##
## Shared fixtures
## ---------------------------------------------------------------------##

#' Stand-in for `dplyr::tbl()` bound directly into each sandbox environment
#' (see build_statistics_sandbox() below) rather than registered as an S3
#' method: testthat does not source test files into the literal
#' `.GlobalEnv`, so a `tbl.mock_pool` S3 method defined at file scope is not
#' reliably visible to `UseMethod()` dispatch from inside a service function
#' whose closure environment is the sandbox. Binding `tbl` directly in the
#' sandbox is resolved by ordinary lexical scoping instead, which is
#' unaffected by where the test file itself happens to be sourced.
mock_pool_tbl <- function(src, name, ...) {
  if (!name %in% names(src)) {
    stop("mock_pool: unknown table '", name, "'")
  }
  src[[name]]
}

make_mock_pool <- function(tables) {
  structure(tables, class = "mock_pool")
}

#' Fake Plumber response object. A plain list would not observe mutations
#' made inside a called service function (R list assignment copies), so this
#' uses an environment to match Plumber's real (R6, reference-semantics)
#' response object.
make_fake_res <- function(status = 200L) {
  e <- new.env(parent = emptyenv())
  e$status <- status
  e$body <- NULL
  e
}

#' Minimal stand-in for timetk::summarize_by_time(), sufficient to exercise
#' the wiring/shape of svc_statistics_entities_over_time() and
#' svc_statistics_publication_stats() without the timetk package. Always
#' buckets to whole months and preserves any existing dplyr grouping (timetk
#' keeps the caller's group_by() as the outer group; dplyr::summarise()
#' drops only the innermost/most-recently-added group by default, which is
#' `.bucket` here since it is added after the caller's group via `.add =
#' TRUE`) so downstream `cumsum()`-per-group semantics match production.
stub_summarize_by_time <- function(.data, .date_var, .by, .type = "floor", ...) {
  date_sym <- rlang::ensym(.date_var)
  date_name <- rlang::as_string(date_sym)
  agg <- rlang::enquos(...)

  .data %>%
    dplyr::mutate(.bucket = as.Date(format(as.Date(!!date_sym), "%Y-%m-01"))) %>%
    dplyr::group_by(.bucket, .add = TRUE) %>%
    dplyr::arrange(.bucket, .by_group = TRUE) %>%
    dplyr::summarise(!!!agg, .groups = "drop_last") %>%
    dplyr::rename(!!date_name := .bucket)
}

#' Build a sandbox environment with the globals a statistics service expects
#' (mirrors the pre-extraction endpoint's dependency set), then source the
#' target service file into it.
#'
#' @param service_file Path relative to api/, e.g.
#'   "services/statistics-public-endpoint-service.R".
#' @param pool_tables Named list of tibbles backing the mock `pool`.
build_statistics_sandbox <- function(service_file, pool_tables = list()) {
  env <- new.env(parent = globalenv())
  env$pool <- make_mock_pool(pool_tables)
  env$tbl <- function(src, name, ...) mock_pool_tbl(src, name, ...)
  env$summarize_by_time <- stub_summarize_by_time
  env$allowed_columns_for_view <- function(view_name) NULL
  env$generate_filter_expressions <- function(filter_string, ..., allowed_columns = NULL) {
    if (is.null(filter_string) || !nzchar(trimws(filter_string)) || identical(filter_string, "null")) {
      return("")
    }
    # Test stub: tests pass an already-valid dplyr boolean expression string
    # directly (production's JSON-API-style grammar is exercised in
    # test-unit-filter-column-allowlist.R, not re-tested here).
    filter_string
  }
  env$log_debug <- function(...) invisible(NULL)
  env$generate_stat_tibble_mem <- function(sort, type) {
    tibble::tibble(sort_used = sort, type_used = type)
  }
  env$generate_gene_news_tibble_mem <- function(n) {
    tibble::tibble(n_used = n)
  }
  source_api_file(service_file, local = FALSE, envir = env)
  env
}

public_env <- function(pool_tables = list()) {
  build_statistics_sandbox("services/statistics-public-endpoint-service.R", pool_tables)
}

admin_env <- function(pool_tables = list()) {
  build_statistics_sandbox("services/statistics-admin-endpoint-service.R", pool_tables)
}

## ---------------------------------------------------------------------##
## Cheap-route guard (#344): expand the external-fetcher scan to both new
## service files, mirroring test-unit-cheap-route-isolation.R's pattern.
## `/statistics` is a cheap route; extraction must not hide an external call
## inside either service.
## ---------------------------------------------------------------------##

test_that("statistics endpoint services never reference an external provider fetcher", {
  service_files <- c(
    "statistics-public-endpoint-service.R",
    "statistics-admin-endpoint-service.R"
  )
  sdir <- file.path(get_api_dir(), "services")
  offenders <- character()
  for (f in service_files) {
    path <- file.path(sdir, f)
    expect_true(file.exists(path), info = paste("missing service file:", f))
    src <- readLines(path, warn = FALSE)
    src <- src[!grepl("^\\s*#", src)]
    pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)"
    hits <- grep(pattern, src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(f, ": ", trimws(hits)))
  }
  expect_identical(
    offenders, character(),
    info = paste(
      "Statistics service calls an external fetcher (would break the cheap-route contract):",
      paste(offenders, collapse = " | ")
    )
  )
})

## ---------------------------------------------------------------------##
## Public service: trivial delegates
## ---------------------------------------------------------------------##

test_that("svc_statistics_category_count delegates to generate_stat_tibble_mem", {
  env <- public_env()
  result <- env$svc_statistics_category_count("category_id,-n", "gene")
  expect_equal(result$sort_used, "category_id,-n")
  expect_equal(result$type_used, "gene")
})

test_that("svc_statistics_gene_news delegates to generate_gene_news_tibble_mem", {
  env <- public_env()
  result <- env$svc_statistics_gene_news(5)
  expect_equal(result$n_used, 5)
})

## ---------------------------------------------------------------------##
## Public service: svc_statistics_entities_over_time — 400 validation
## ---------------------------------------------------------------------##

test_that("svc_statistics_entities_over_time 400s on an invalid aggregate", {
  env <- public_env()
  res <- env$svc_statistics_entities_over_time(make_fake_res(), "bogus", "category", "month", "")
  expect_equal(res$status, 400)
  body <- jsonlite::fromJSON(as.character(res$body))
  expect_equal(body$status, 400)
  expect_match(body$message, "not in allowed list")
})

test_that("svc_statistics_entities_over_time 400s on an invalid group", {
  env <- public_env()
  res <- env$svc_statistics_entities_over_time(make_fake_res(), "entity_id", "bogus", "month", "")
  expect_equal(res$status, 400)
  body <- jsonlite::fromJSON(as.character(res$body))
  expect_match(body$message, "not in allowed list")
})

test_that("svc_statistics_entities_over_time 400s on entity_id + inheritance_multiple", {
  env <- public_env()
  res <- env$svc_statistics_entities_over_time(
    make_fake_res(), "entity_id", "inheritance_multiple", "month", ""
  )
  expect_equal(res$status, 400)
  body <- jsonlite::fromJSON(as.character(res$body))
  expect_match(body$message, "Multiple inheritance only sensible")
})

## ---------------------------------------------------------------------##
## Public service: svc_statistics_entities_over_time — shapes/counts
## ---------------------------------------------------------------------##

entities_over_time_fixture <- function() {
  tibble::tibble(
    entity_id = 1:6,
    symbol = c("GENEA", "GENEA", "GENEB", "GENEB", "GENEC", "GENEA"),
    category = c(
      "Definitive", "Definitive", "Limited", "Limited", "Definitive", "Definitive"
    ),
    inheritance_filter = c("AD", "AD", "AR", "AR", "AD", "AD"),
    entry_date = as.Date(c(
      "2024-01-05", "2024-01-20", "2024-02-10", "2024-02-15", "2024-01-25", "2024-03-05"
    ))
  )
}

test_that("svc_statistics_entities_over_time returns nested meta/data time-series shape", {
  env <- public_env(list(ndd_entity_view = entities_over_time_fixture()))
  result <- env$svc_statistics_entities_over_time(
    make_fake_res(), "entity_id", "category", "month", ""
  )

  expect_named(result, c("meta", "data"))
  expect_equal(result$meta$aggregate, "entity_id")
  expect_equal(result$meta$group, "category")
  expect_equal(result$meta$max_count, 3)
  expect_equal(result$meta$max_cumulative_count, 4)

  expect_named(result$data, c("group", "values"))
  expect_setequal(result$data$group, c("Definitive", "Limited"))

  definitive_values <- result$data$values[[which(result$data$group == "Definitive")]]
  expect_named(definitive_values, c("entry_date", "count", "cumulative_count"))
  # Two buckets for Definitive (2024-01 with 3 entities, 2024-03 with 1);
  # cumulative_count accumulates within the group.
  expect_equal(nrow(definitive_values), 2)
  expect_equal(definitive_values$count, c(3, 1))
  expect_equal(definitive_values$cumulative_count, c(3, 4))

  limited_values <- result$data$values[[which(result$data$group == "Limited")]]
  expect_equal(nrow(limited_values), 1)
  expect_equal(limited_values$count, 2)
})

test_that("svc_statistics_entities_over_time handles a zero-row view without erroring", {
  env <- public_env(list(
    ndd_entity_view = entities_over_time_fixture()[0, ]
  ))
  result <- suppressWarnings(
    env$svc_statistics_entities_over_time(make_fake_res(), "entity_id", "category", "month", "")
  )
  expect_named(result, c("meta", "data"))
  expect_equal(nrow(result$data), 0)
  expect_named(result$data, c("group", "values"))
})

## ---------------------------------------------------------------------##
## Public service: svc_statistics_publication_stats
## ---------------------------------------------------------------------##

publication_stats_fixture <- function() {
  tibble::tibble(
    publication_id = 1:6,
    publication_type = c(
      "gene_review", "gene_review", "case_report", "case_report", "case_report", "gene_review"
    ),
    Journal = c("J1", "J1", "J2", "J2", "J3", "J1"),
    Lastname = c("Smith", "Smith", "Jones", "Jones", "Doe", "Smith"),
    update_date = as.Date(NA),
    Publication_date = as.Date(NA),
    Keywords = c(
      "epilepsy;autism", "epilepsy", "autism", "autism", "rare", "epilepsy;autism"
    )
  )
}

test_that("svc_statistics_publication_stats aggregates every column and sets res$status 200", {
  env <- public_env(list(publication = publication_stats_fixture()))
  res <- make_fake_res(status = 200L)

  result <- env$svc_statistics_publication_stats(res, "year", "", 1, 1, 1)

  expect_equal(res$status, 200)
  expect_setequal(result$publication_type_counts$publication_type, c("gene_review", "case_report"))
  expect_equal(
    result$publication_type_counts$count[result$publication_type_counts$publication_type == "gene_review"],
    3
  )
  expect_setequal(result$journal_counts$Journal, c("J1", "J2", "J3"))
  expect_setequal(result$keyword_counts$Keywords, c("autism", "epilepsy", "rare"))
  expect_equal(result$time_aggregate_used, "year")
  expect_equal(result$min_journal_count_used, 1L)
})

test_that("svc_statistics_publication_stats honours min-count thresholds (empty-state per column)", {
  env <- public_env(list(publication = publication_stats_fixture()))
  result <- env$svc_statistics_publication_stats(
    make_fake_res(), "year", "",
    min_journal_count = 2, min_lastname_count = 2, min_keyword_count = 3
  )

  # J3 (count 1) drops below min_journal_count = 2.
  expect_setequal(result$journal_counts$Journal, c("J1", "J2"))
  expect_false("J3" %in% result$journal_counts$Journal)
  # Doe (count 1) drops below min_lastname_count = 2.
  expect_setequal(result$last_name_counts$Lastname, c("Smith", "Jones"))
  # "rare" (count 1) drops below min_keyword_count = 3.
  expect_setequal(result$keyword_counts$Keywords, c("autism", "epilepsy"))
})

test_that("svc_statistics_publication_stats applies the supplied filter before aggregating", {
  env <- public_env(list(publication = publication_stats_fixture()))
  result <- env$svc_statistics_publication_stats(
    make_fake_res(), "year", "publication_type == 'gene_review'", 1, 1, 1
  )

  expect_equal(nrow(result$publication_type_counts), 1)
  expect_equal(result$publication_type_counts$publication_type, "gene_review")
  expect_equal(result$filter_used, "publication_type == 'gene_review'")
})

test_that("svc_statistics_publication_stats handles an empty publication table", {
  env <- public_env(list(publication = publication_stats_fixture()[0, ]))
  result <- env$svc_statistics_publication_stats(make_fake_res(), "year", "", 1, 1, 1)

  expect_equal(nrow(result$publication_type_counts), 0)
  expect_named(result$publication_type_counts, c("publication_type", "count"))
  expect_equal(nrow(result$journal_counts), 0)
  expect_equal(nrow(result$keyword_counts), 0)
})

## ---------------------------------------------------------------------##
## Admin service: date-range statistics
## ---------------------------------------------------------------------##

test_that("svc_statistics_admin_updates counts new NDD entities in range", {
  env <- admin_env(list(
    ndd_entity = tibble::tibble(
      entity_id = 1:5,
      hgnc_id = c(101, 101, 102, 103, 104),
      ndd_phenotype = c(1, 1, 1, 0, 1),
      is_active = c(1, 1, 1, 1, 0),
      entry_date = as.Date(c(
        "2024-01-05", "2024-01-10", "2024-02-01", "2024-01-15", "2024-01-20"
      ))
    )
  ))
  result <- env$svc_statistics_admin_updates("2024-01-01", "2024-01-31")
  expect_equal(result$total_new_entities, 2)
  expect_equal(result$unique_genes, 1)
})

test_that("svc_statistics_admin_updates is an empty state outside the range", {
  env <- admin_env(list(
    ndd_entity = tibble::tibble(
      entity_id = 1L, hgnc_id = 101, ndd_phenotype = 1, is_active = 1,
      entry_date = as.Date("2024-01-05")
    )
  ))
  result <- env$svc_statistics_admin_updates("2025-01-01", "2025-01-31")
  expect_equal(result$total_new_entities, 0)
  expect_equal(result$unique_genes, 0)
  expect_equal(result$average_per_day, 0)
})

test_that("svc_statistics_admin_rereview computes totals and percentage finished", {
  env <- admin_env(list(
    ndd_entity_review = tibble::tibble(
      review_id = 1:3, review_date = as.Date(c("2024-01-05", "2024-01-10", "2024-02-01"))
    ),
    ndd_entity_status = tibble::tibble(
      status_id = 1:3, status_date = as.Date(c("2024-01-06", "2024-01-11", "2024-02-02"))
    ),
    re_review_entity_connect = tibble::tibble(
      entity_id = 1:3, review_id = 1:3, status_id = 1:3, re_review_submitted = c(1, 1, 0)
    )
  ))
  result <- env$svc_statistics_admin_rereview("2024-01-01", "2024-01-31")
  expect_equal(result$total_rereviews, 2)
  expect_equal(result$percentage_finished, (2 / 3) * 100)
})

test_that("svc_statistics_admin_rereview is an empty state with no submitted rows", {
  env <- admin_env(list(
    ndd_entity_review = tibble::tibble(review_id = integer(0), review_date = as.Date(character(0))),
    ndd_entity_status = tibble::tibble(status_id = integer(0), status_date = as.Date(character(0))),
    re_review_entity_connect = tibble::tibble(
      entity_id = integer(0), review_id = integer(0), status_id = integer(0),
      re_review_submitted = integer(0)
    )
  ))
  result <- env$svc_statistics_admin_rereview("2024-01-01", "2024-01-31")
  expect_equal(result$total_rereviews, 0)
  expect_equal(result$percentage_finished, 0)
})

test_that("svc_statistics_admin_updated_reviews counts entities with >1 review in range", {
  env <- admin_env(list(
    ndd_entity_review = tibble::tibble(
      entity_id = c(1, 1, 2),
      review_date = as.Date(c("2024-01-01", "2024-01-15", "2024-01-01"))
    )
  ))
  result <- env$svc_statistics_admin_updated_reviews("2024-01-01", "2024-01-31")
  expect_equal(result$total_updated_reviews, 1)
})

test_that("svc_statistics_admin_updated_reviews is an empty state without duplicate entities", {
  env <- admin_env(list(
    ndd_entity_review = tibble::tibble(entity_id = c(1, 2), review_date = as.Date(c("2024-01-01", "2024-01-02")))
  ))
  # Pre-existing (unchanged) quirk: group_by(entity_id) %>% filter(n() > 1) with
  # a constant-per-group predicate leaves every original group present with 0
  # rows rather than dropping the group entirely, so the subsequent
  # max(review_date, na.rm = TRUE) warns per empty group. total_updated_reviews
  # is still correctly 0; suppressWarnings() only silences that benign warning.
  result <- suppressWarnings(
    env$svc_statistics_admin_updated_reviews("2024-01-01", "2024-01-31")
  )
  expect_equal(result$total_updated_reviews, 0)
})

test_that("svc_statistics_admin_updated_statuses counts entities with >1 status in range", {
  env <- admin_env(list(
    ndd_entity_status = tibble::tibble(
      entity_id = c(1, 1, 2),
      status_date = as.Date(c("2024-01-01", "2024-01-20", "2024-01-01"))
    )
  ))
  result <- env$svc_statistics_admin_updated_statuses("2024-01-01", "2024-01-31")
  expect_equal(result$total_updated_statuses, 1)
})

## ---------------------------------------------------------------------##
## Admin service: leaderboards — fields, meta, empty states
## ---------------------------------------------------------------------##

test_that("svc_statistics_admin_contributor_leaderboard returns expected fields and meta", {
  env <- admin_env(list(
    ndd_entity_status = tibble::tibble(
      entity_id = 1:4, status_user_id = c(10, 10, 11, 12),
      status_date = as.Date(c("2024-01-01", "2024-01-02", "2024-01-03", "2024-01-04"))
    ),
    ndd_entity_view = tibble::tibble(
      entity_id = 1:4,
      entry_date = as.Date(c("2024-01-01", "2024-01-02", "2024-01-03", "2024-01-04")),
      ndd_phenotype = c(1, 1, 1, 0)
    ),
    user = tibble::tibble(
      user_id = c(10, 11, 12), user_name = c("u10", "u11", "u12"),
      first_name = c("Alice", NA, "Carl"), family_name = c("A", NA, "C")
    )
  ))
  result <- env$svc_statistics_admin_contributor_leaderboard(
    top = 10, start_date = NULL, end_date = NULL, scope = "all_time"
  )

  expect_named(result, c("data", "meta"))
  expect_named(result$data, c("user_id", "user_name", "display_name", "entity_count"))
  # entity 4 is excluded (ndd_phenotype == 0), leaving contributors 10 and 11.
  expect_setequal(result$data$user_id, c(10, 11))
  expect_equal(result$data$entity_count[result$data$user_id == 10], 2)
  # display_name falls back to user_name when first/family name are NA.
  expect_equal(result$data$display_name[result$data$user_id == 11], "u11")
  expect_equal(result$data$display_name[result$data$user_id == 10], "Alice A")
  expect_equal(result$meta$top, 10)
  expect_equal(result$meta$scope, "all_time")
  expect_equal(result$meta$total_contributors, 2)
})

test_that("svc_statistics_admin_contributor_leaderboard truncates to top N and filters by scope", {
  env <- admin_env(list(
    ndd_entity_status = tibble::tibble(
      entity_id = 1:3, status_user_id = c(10, 11, 12),
      status_date = as.Date(c("2024-01-01", "2024-06-01", "2024-12-01"))
    ),
    ndd_entity_view = tibble::tibble(
      entity_id = 1:3,
      entry_date = as.Date(c("2024-01-01", "2024-06-01", "2024-12-01")),
      ndd_phenotype = c(1, 1, 1)
    ),
    user = tibble::tibble(
      user_id = 10:12, user_name = c("u10", "u11", "u12"),
      first_name = NA_character_, family_name = NA_character_
    )
  ))
  result <- env$svc_statistics_admin_contributor_leaderboard(
    top = 1, start_date = "2024-05-01", end_date = "2024-12-31", scope = "range"
  )
  expect_equal(nrow(result$data), 1)
  expect_equal(result$meta$scope, "range")
})

test_that("svc_statistics_admin_contributor_leaderboard is an empty state with no NDD entities", {
  env <- admin_env(list(
    ndd_entity_status = tibble::tibble(
      entity_id = 1L, status_user_id = 10, status_date = as.Date("2024-01-01")
    ),
    ndd_entity_view = tibble::tibble(
      entity_id = 1L, entry_date = as.Date("2024-01-01"), ndd_phenotype = 0
    ),
    user = tibble::tibble(
      user_id = 10, user_name = "u10", first_name = NA_character_, family_name = NA_character_
    )
  ))
  result <- env$svc_statistics_admin_contributor_leaderboard()
  expect_equal(nrow(result$data), 0)
  expect_equal(result$meta$total_contributors, 0)
})

test_that("svc_statistics_admin_rereview_leaderboard returns expected fields and meta", {
  env <- admin_env(list(
    ndd_entity_review = tibble::tibble(review_id = 1:2, review_date = as.Date(c("2024-01-01", "2024-01-02"))),
    ndd_entity_status = tibble::tibble(status_id = 1:2, status_date = as.Date(c("2024-01-01", "2024-01-02"))),
    re_review_entity_connect = tibble::tibble(
      entity_id = 1:2, review_id = 1:2, status_id = 1:2, re_review_batch = c("b1", "b1"),
      re_review_submitted = c(1, 0), re_review_approved = c(1, 0)
    ),
    re_review_assignment = tibble::tibble(re_review_batch = "b1", user_id = 20),
    user = tibble::tibble(user_id = 20, user_name = "u20", first_name = NA_character_, family_name = NA_character_)
  ))
  result <- env$svc_statistics_admin_rereview_leaderboard()

  expect_named(result, c("data", "meta"))
  expect_named(
    result$data,
    c("user_id", "user_name", "display_name", "total_assigned", "submitted_count", "approved_count")
  )
  expect_equal(result$data$total_assigned, 2)
  expect_equal(result$data$submitted_count, 1)
  expect_equal(result$data$approved_count, 1)
  expect_equal(result$meta$total_reviewers, 1)
  expect_equal(result$meta$total_submitted, 2)
  expect_equal(result$meta$total_approved, 1)
})

test_that("svc_statistics_admin_rereview_leaderboard is an empty state with no assignments", {
  env <- admin_env(list(
    ndd_entity_review = tibble::tibble(review_id = integer(0), review_date = as.Date(character(0))),
    ndd_entity_status = tibble::tibble(status_id = integer(0), status_date = as.Date(character(0))),
    re_review_entity_connect = tibble::tibble(
      entity_id = integer(0), review_id = integer(0), status_id = integer(0),
      re_review_batch = character(0), re_review_submitted = integer(0), re_review_approved = integer(0)
    ),
    re_review_assignment = tibble::tibble(re_review_batch = character(0), user_id = integer(0)),
    user = tibble::tibble(
      user_id = integer(0), user_name = character(0),
      first_name = character(0), family_name = character(0)
    )
  ))
  result <- env$svc_statistics_admin_rereview_leaderboard()
  expect_equal(nrow(result$data), 0)
  expect_equal(result$meta$total_reviewers, 0)
  expect_equal(result$meta$total_submitted, 0)
})

## ---------------------------------------------------------------------##
## DB-state guard: none of the assertions above need the real test database
## (the mock pool covers every table these services touch), but a schema
## drift on one of the columns the services rely on would not be caught by
## mock-based tests. This checks the real test database (when available)
## for the tables/columns both services reference, mirroring the
## with_test_db_transaction() + skip-with-reason pattern already used by
## test-unit-metadata-refresh.R.
## ---------------------------------------------------------------------##

test_that("statistics service tables and key columns exist in the schema", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    required <- list(
      ndd_entity = c("entity_id", "hgnc_id", "ndd_phenotype", "is_active", "entry_date"),
      ndd_entity_view = c(
        "entity_id", "symbol", "category", "inheritance_filter", "entry_date", "ndd_phenotype"
      ),
      ndd_entity_review = c("review_id", "entity_id", "review_date"),
      ndd_entity_status = c("status_id", "entity_id", "status_date"),
      re_review_entity_connect = c(
        "entity_id", "review_id", "status_id",
        "re_review_batch", "re_review_submitted", "re_review_approved"
      ),
      re_review_assignment = c("re_review_batch", "user_id"),
      user = c("user_id", "user_name", "first_name", "family_name"),
      publication = c(
        "publication_type", "Journal", "Lastname", "update_date", "Publication_date", "Keywords"
      )
    )

    missing_tables <- names(required)[
      !vapply(names(required), DBI::dbExistsTable, logical(1), conn = conn)
    ]
    if (length(missing_tables) > 0) {
      skip(paste(
        "Test database schema is not initialized; missing table(s):",
        paste(missing_tables, collapse = ", ")
      ))
    }

    for (tbl_name in names(required)) {
      cols <- DBI::dbListFields(conn, tbl_name)
      missing_cols <- setdiff(required[[tbl_name]], cols)
      expect_identical(
        missing_cols, character(0),
        info = paste0(
          tbl_name, " is missing expected column(s): ", paste(missing_cols, collapse = ", ")
        )
      )
    }
  })
})
