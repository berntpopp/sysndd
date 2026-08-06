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
  # 050 was scoped to the variation view and stays that way.
  #
  # The original reason recorded here was wrong and is corrected in admin#19:
  # svc_entity_phenotypes()/svc_entity_publications() do NOT filter on review_id
  # alone -- they end with left_join(ndd_entity_active, by = "entity_id"), which
  # re-imposes agreement. The 744 + 166 rows were therefore never "currently
  # served"; they were dropped. entity_id was subsequently established as the
  # authoritative column and the underlying rows were repaired, so the phenotype
  # view needs no predicate: after the repair there is nothing for it to hide.
  # Migration 051 enforces the invariant structurally.
  sql <- read_all(migration_050_path())

  expect_false(grepl("VIEW `ndd_review_phenotype_connect_view`", sql, fixed = TRUE))
  expect_false(grepl("ndd_review_phenotype_connect`.`entity_id` = ", sql, fixed = TRUE))
})

test_that("the SEO variation query requires entity agreement", {
  src <- read_all(file.path(get_api_dir(), "services", "seo-service.R"))

  expect_match(src, "AND er.entity_id = vc.entity_id", fixed = TRUE)
})

test_that("the SEO phenotype and publication queries are deliberately unchanged", {
  # They anchor on entity_id, the authoritative column (admin#19), so they were
  # already correct. Adding a review-agreement predicate would be redundant with
  # migration 051 rather than harmful -- but redundant, so it stays out.
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

  expect_equal(EXPECTED_LATEST_MIGRATION, "052_variation_review_agreement_constraint.sql")
  expect_equal(EXPECTED_MIGRATION_COUNT, 50L)
})
