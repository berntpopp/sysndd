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
