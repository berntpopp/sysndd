# tests/testthat/test-unit-variant-view-entity-agreement.R
#
# Guard for migration 050 + seo-service.R (berntpopp/sysndd-administration#18).
#
# ndd_review_variation_ontology_connect records which entity a row belongs to
# TWICE -- in its own `entity_id`, and via the entity owning its `review_id`.
# Production has 256 active rows where those disagree (206 on a primary, approved
# review), from a 2022 seed that read a stale snapshot CSV.
#
# svc_entity_variation() drops those rows by requiring BOTH predicates. The
# variant view and the SEO query joined on review_id alone, so the same rows
# surfaced in the public variant browse and in SEO structured data -- the entity
# page and the browse disagreeing about the same entity.
#
# These assertions are about SOURCE TEXT, so they hold with no database.
#
# Pure test (no DB / no network) -- runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-variant-view-entity-agreement.R')"

library(testthat)

migration_050_path <- function() {
  file.path(get_api_dir(), "..", "db", "migrations",
            "050_variant_view_entity_agreement.sql")
}

read_all <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

test_that("migration 050 joins the variant view on BOTH review_id and entity_id", {
  path <- migration_050_path()
  expect_true(file.exists(path))
  sql <- read_all(path)

  expect_match(sql, "VIEW `ndd_review_variant_connect_view`", fixed = TRUE)
  expect_match(
    sql,
    "`ndd_review_variation_ontology_connect`.`entity_id` = `ndd_entity_review`.`entity_id`",
    fixed = TRUE
  )
})

test_that("migration 050 keeps all three approval gates from migration 042", {
  # The entity-agreement predicate is ADDITIONAL. Dropping any of these would
  # leak unapproved in-place review edits publicly, which is what 042 exists for.
  sql <- read_all(migration_050_path())

  expect_match(sql, "`is_active` = 1", fixed = TRUE)
  expect_match(sql, "`is_primary` = 1", fixed = TRUE)
  expect_match(sql, "`review_approved` = 1", fixed = TRUE)
})

test_that("migration 050 does NOT touch the phenotype view", {
  # svc_entity_phenotypes() and svc_entity_publications() filter on review_id
  # alone, so their view already agrees with their endpoint. Adding the predicate
  # there would HIDE 744 phenotype and 166 publication rows that are currently
  # served -- a user-visible removal resting on an unproven assumption about which
  # column is authoritative. This test exists so a future "make it consistent"
  # change has to argue with it first.
  sql <- read_all(migration_050_path())

  expect_false(grepl("VIEW `ndd_review_phenotype_connect_view`", sql, fixed = TRUE))
  expect_false(grepl("ndd_review_phenotype_connect`.`entity_id` = ", sql, fixed = TRUE))
})

test_that("the SEO variation query requires entity agreement", {
  src <- read_all(file.path(get_api_dir(), "services", "seo-service.R"))

  expect_match(src, "AND er.entity_id = vc.entity_id", fixed = TRUE)
})

test_that("the SEO phenotype and publication queries are deliberately unchanged", {
  # Same reasoning as the migration: they match their endpoints already.
  src <- read_all(file.path(get_api_dir(), "services", "seo-service.R"))

  expect_false(grepl("AND er.entity_id = pc.entity_id", src, fixed = TRUE))
  expect_false(grepl("AND er.entity_id = rpj.entity_id", src, fixed = TRUE))
})

test_that("the SEO variation query still matches svc_entity_variation's gates", {
  src <- read_all(file.path(get_api_dir(), "services", "seo-service.R"))

  expect_match(src, "er.is_primary = 1 AND er.review_approved = 1", fixed = TRUE)
  expect_match(src, "vc.is_active = 1", fixed = TRUE)
})

test_that("the migration manifest tracks 050 as the latest migration", {
  origin_dir <- Sys.getenv("MCP_API_TEST_ROOT", get_api_dir())
  source(file.path(origin_dir, "functions", "migration-manifest.R"), local = FALSE)

  expect_equal(EXPECTED_LATEST_MIGRATION, "050_variant_view_entity_agreement.sql")
  expect_equal(EXPECTED_MIGRATION_COUNT, 48L)
})
