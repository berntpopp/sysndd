# tests/testthat/test-unit-entity-vario-filter.R
# all(vario_id,A,B) must list only entities carrying both terms (#709); it
# used to behave like any(), so the variant correlogram drill-down showed a union.

library(testthat)
library(dplyr)
library(stringr)

source_api_file("functions/entity-helpers.R", local = FALSE)

test_that("extract_vario_filter keeps each clause's operator", {
  res <- extract_vario_filter(
    "any(category,Definitive),all(vario_id,VariO:0015,VariO:0017)"
  )
  expect_equal(res$filter_without_vario, "any(category,Definitive)")
  expect_equal(res$vario_clauses, list(
    list(operator = "all", vario_ids = c("VariO:0015", "VariO:0017"))
  ))
  expect_length(extract_vario_filter("any(category,Definitive)")$vario_clauses, 0)
  expect_equal(extract_vario_filter("all(vario_id,VariO:0015,)")$vario_clauses[[1]]$vario_ids, "VariO:0015")
})

test_that("get_entity_ids_by_vario: any() is a union, all() an intersection", {
  skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "ndd_review_variant_connect_view", data.frame(
    entity_id = c(1L, 1L, 2L, 3L, 3L),
    vario_id = c("VariO:0015", "VariO:0017", "VariO:0015", "VariO:0017", "VariO:0017")
  ))
  ids <- c("VariO:0015", "VariO:0017")

  expect_setequal(get_entity_ids_by_vario(ids, con), c(1L, 2L, 3L))
  expect_equal(get_entity_ids_by_vario(ids, con, match_all = TRUE), 1L)
  expect_setequal(get_entity_ids_by_vario("VariO:0017", con, match_all = TRUE), c(1L, 3L))
})

test_that("svc_entity_list_query ANDs variant clauses and honours all()", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("mockery")
  source_api_file("functions/response-helpers.R", local = FALSE)
  source_api_file("functions/review-repository.R", local = FALSE)
  source_api_file("services/entity-read-endpoint-service.R", local = FALSE)
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "ndd_entity_view", data.frame(entity_id = 1:3, category = "Definitive"))
  DBI::dbWriteTable(con, "ndd_entity_review", data.frame(
    entity_id = 1:3, synopsis = "", is_primary = 1L, review_approved = 1L
  ))
  DBI::dbWriteTable(con, "ndd_review_variant_connect_view", data.frame(
    entity_id = c(1L, 1L, 1L, 2L, 3L, 3L),
    vario_id = c("VariO:0015", "VariO:0017", "VariO:0001", "VariO:0015", "VariO:0017", "VariO:0001")
  ))
  list_ids <- function(filter) {
    fn <- svc_entity_list_query
    mockery::stub(fn, "allowed_columns_for_view", NULL)
    mockery::stub(fn, "svc_entity_shape_entity_page", function(sysndd_db_disease_table,
                                                               ndd_entity_view, ...) {
      # the global view feeds the column specs, so a variant filter must not shrink it
      expect_equal(nrow(ndd_entity_view), 3L)
      list(meta = list(), data = sort(sysndd_db_disease_table$entity_id))
    })
    fn(filter = filter, pool = con, api_base_url = "")$data
  }

  expect_equal(list_ids("any(category,Definitive),all(vario_id,VariO:0015,VariO:0017)"), 1L)
  expect_equal(list_ids("any(vario_id,VariO:0015,VariO:0017)"), 1:3)
  expect_equal(list_ids("any(vario_id,VariO:0015),all(vario_id,VariO:0001)"), 1L)
  expect_equal(list_ids("all(vario_id,VariO:0015,VariO:0001,VariO:0017),any(vario_id,VariO:0099)"), integer(0))
})
