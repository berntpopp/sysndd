# tests/testthat/test-unit-entity-review-agreement-constraint.R
#
# Guard for migration 051 (berntpopp/sysndd-administration#19).
#
# The three review join tables record which entity a row belongs to TWICE: in
# their own `entity_id`, and via the entity owning their `review_id`. Nothing
# enforced agreement, so ~1,377 rows drifted apart unnoticed between 2022 and
# 2026 -- a seeding script resolved review_id from a stale snapshot after one
# entity was deleted and another added, shifting every review_id in a 256-entity
# block by one.
#
# Migration 051 makes the disagreement unrepresentable: a COMPOSITE foreign key
# on (review_id, entity_id) referencing ndd_entity_review(review_id, entity_id).
# Because review_id is that table's primary key, the pair can only resolve when
# entity_id equals the review's own entity. The engine now rejects what the
# application previously had to remember to check.
#
# These assertions are about SOURCE TEXT, so they hold with no database.
#
# Pure test (no DB / no network) -- runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-entity-review-agreement-constraint.R')"

library(testthat)

migration_051_path <- function() {
  file.path(get_api_dir(), "..", "db", "migrations",
            "051_entity_review_agreement_constraint.sql")
}

read_all <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

# Executable DDL only: the rationale prose above each statement names the very
# tables and keywords these tests assert on, so matching raw file text would let
# a comment satisfy a test that no statement satisfies.
migration_051_ddl <- function() {
  lines <- readLines(migration_051_path(), warn = FALSE)
  paste(lines[!grepl("^\\s*--", lines)], collapse = "\n")
}

test_that("migration 051 exists", {
  expect_true(file.exists(migration_051_path()))
})

test_that("051 adds the unique parent key the composite FK needs", {
  # A composite FK requires an index on the referenced columns. review_id is
  # already the PK, so (review_id, entity_id) is unique by construction -- but
  # MySQL still needs the index to exist before it will accept the reference.
  ddl <- migration_051_ddl()

  expect_match(ddl, "ndd_entity_review", fixed = TRUE)
  expect_match(ddl, "uq_entity_review_review_entity", fixed = TRUE)
  expect_match(ddl, "UNIQUE", fixed = TRUE)
})

test_that("051 constrains the phenotype join table on BOTH columns", {
  ddl <- migration_051_ddl()

  expect_match(ddl, "fk_phenotype_connect_review_entity", fixed = TRUE)
  expect_match(
    ddl,
    "FOREIGN KEY (`review_id`, `entity_id`)",
    fixed = TRUE
  )
})

test_that("051 constrains the publication join table on BOTH columns", {
  ddl <- migration_051_ddl()

  expect_match(ddl, "fk_publication_join_review_entity", fixed = TRUE)
})

test_that("051 does NOT constrain the variation table", {
  # ndd_review_variation_ontology_connect still holds 256 rows that violate the
  # invariant (admin#18). Adding the FK there would abort the migration and take
  # the API down on startup, since migrations run before the server binds.
  # It gets the same constraint once those rows are repaired.
  ddl <- migration_051_ddl()

  expect_false(grepl("ndd_review_variation_ontology_connect", ddl, fixed = TRUE))
})

test_that("051 is guarded so a rerun and a restored older dump both no-op", {
  # Same PREPARE/EXECUTE information_schema guard style as 043/046/049: MySQL 8
  # has no ADD CONSTRAINT IF NOT EXISTS.
  ddl <- migration_051_ddl()

  expect_match(ddl, "information_schema", fixed = TRUE)
  expect_match(ddl, "PREPARE", fixed = TRUE)
})

test_that("051 refuses to apply while the data still violates the invariant", {
  # An unguarded ADD FOREIGN KEY against violating rows fails the migration,
  # which fails API startup. The guard checks for violations first and skips,
  # so a database that was never repaired starts and reports rather than
  # crash-looping.
  ddl <- migration_051_ddl()

  # counts disagreeing rows ...
  expect_match(ddl, "WHERE c.`entity_id` <> r.`entity_id`", fixed = TRUE)
  # ... and only adds each constraint when that count is zero.
  expect_match(ddl, "IF(@pheno_violations = 0 AND @pheno_fk_exists = 0",
               fixed = TRUE)
  expect_match(ddl, "IF(@pub_violations = 0 AND @pub_fk_exists = 0",
               fixed = TRUE)
})

test_that("the review curation reads require entity agreement", {
  # Defense in depth, and NOT redundant with the FK. The FK holds in MySQL;
  # the testthat fixtures and any SQLite-backed environment have no such
  # enforcement, and a restored pre-repair dump skips the constraint by design
  # (see the violation guard above). These are the surfaces where a mismatched
  # row would be shown to a curator inside someone else's review -- and the
  # save path is DELETE ... WHERE review_id + re-insert from the submitted
  # form, so a row displayed under the wrong review gets re-attributed to the
  # wrong entity on the next save.
  src <- read_all(file.path(get_api_dir(), "endpoints", "review_endpoints.R"))

  expect_match(src, "entity_id == review_entity_id", fixed = TRUE)
})

test_that("the migration manifest tracks 051 as the latest migration", {
  origin_dir <- Sys.getenv("MCP_API_TEST_ROOT", get_api_dir())
  source(file.path(origin_dir, "functions", "migration-manifest.R"), local = FALSE)

  expect_equal(EXPECTED_LATEST_MIGRATION,
               "051_entity_review_agreement_constraint.sql")
  expect_equal(EXPECTED_MIGRATION_COUNT, 49L)
})
