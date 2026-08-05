# Static guard for migration 049_add_evidence_origin_review.sql (#608).
#
# origin_review_id is what separates an imported variation-ontology term still
# sitting on the review the February 2026 import wrote to ("unchanged") from one
# carried into a later curator review ("moved" -- the term now wears a curator's
# name and a recent review date while resting on unchanged machine evidence).
# Detecting that laundering is the reason the provenance system exists, so the
# properties below are not schema niceties:
#
#   * It must be a COLUMN, not a key inside evidence_json. The hot read path
#     deliberately does not select evidence_json, so a JSON key is reachable only
#     one assertion at a time from the detail endpoint -- useless for "which
#     imported terms have moved".
#   * It must stay NULLABLE. Only import-derived evidence has an origin review;
#     NOT NULL would force a sentinel, which is a fabricated provenance record.
#   * It must NOT gain a foreign key to ndd_entity_review. The value is a
#     historical audit fact that outlives the review row, and an FK would take a
#     shared parent lock on ndd_entity_review for each of the ~8,083 backfill
#     inserts -- direct contention against live curation.
#
# These assertions are deliberately about the migration's TEXT, not a live
# database: they are the things a future "simplification" would quietly remove,
# and they must hold in any environment (no DB required).
#
# Pure test (no DB / no network) -- runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-evidence-origin-review.R')"

library(testthat)

# Sourced explicitly (mirroring test-unit-core-views-manifest.R) so the manifest
# assertion at the bottom of this file works when the file is run in isolation.
origin_review_test_api_dir <- Sys.getenv("MCP_API_TEST_ROOT", get_api_dir())
source(file.path(origin_review_test_api_dir, "functions", "migration-manifest.R"), local = FALSE)

MIGRATION_049 <- "049_add_evidence_origin_review.sql"

.evidence_origin_review_migration_sql <- function() {
  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", MIGRATION_049),
    file.path(get_api_dir(), "db", "migrations", MIGRATION_049)
  )
  path <- candidates[file.exists(candidates)][1]
  if (is.na(path)) {
    skip(paste("Migration not found:", MIGRATION_049))
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

# The negative assertions below must read the EXECUTABLE DDL, not the file's
# prose. This migration's header explains at length why it does NOT create a
# foreign key -- so a naive grep over the whole file finds "FOREIGN KEY" in the
# comment that exists to justify its absence, and fails on the very text that
# documents the correct behaviour.
.evidence_origin_review_migration_ddl <- function() {
  lines <- strsplit(.evidence_origin_review_migration_sql(), "\n", fixed = TRUE)[[1]]
  paste(lines[!grepl("^\\s*--", lines)], collapse = "\n")
}

test_that("migration 049 adds origin_review_id as a nullable INT column", {
  sql <- .evidence_origin_review_migration_sql()

  expect_match(sql, "ADD COLUMN `origin_review_id` INT NULL", fixed = TRUE)
  # NOT NULL would force a sentinel value for every non-import source.
  expect_false(grepl("`origin_review_id` INT NOT NULL", sql, fixed = TRUE))
})

test_that("migration 049 indexes the column so the moved/unchanged split is a join", {
  # Without the index the one query this column exists to serve is a full scan of
  # every evidence row.
  sql <- .evidence_origin_review_migration_sql()

  expect_match(sql, "ADD KEY `idx_origin_review` (`origin_review_id`)", fixed = TRUE)
})

test_that("migration 049 does NOT create a foreign key to ndd_entity_review", {
  ddl <- .evidence_origin_review_migration_ddl()

  expect_false(grepl("FOREIGN KEY", ddl, fixed = TRUE))
  expect_false(grepl("REFERENCES", ddl, fixed = TRUE))
  expect_false(grepl("ndd_entity_review", ddl, fixed = TRUE))
})

test_that("migration 049 never touches the curated connect table", {
  # The curated table is rewritten wholesale on every review save; provenance must
  # never live there, and this migration must never write to it.
  ddl <- .evidence_origin_review_migration_ddl()

  expect_false(grepl("ndd_review_variation_ontology_connect", ddl, fixed = TRUE))
  # Whole-file check too: not even a comment should suggest writing there.
  expect_false(grepl(
    "INSERT INTO `?ndd_review_variation_ontology_connect",
    .evidence_origin_review_migration_sql()
  ))
})

test_that("migration 049 is idempotent and skips a missing table instead of erroring", {
  # MySQL 8 has no ADD COLUMN IF NOT EXISTS, so re-application safety has to come
  # from information_schema guards. Both the column and the index are guarded, and
  # an absent variation_ontology_evidence table (047 never applied) no-ops.
  sql <- .evidence_origin_review_migration_sql()

  expect_match(sql, "information_schema.COLUMNS", fixed = TRUE)
  expect_match(sql, "information_schema.STATISTICS", fixed = TRUE)
  expect_match(sql, "@vope_table_exists = 1 AND @origin_col_exists = 0", fixed = TRUE)
  expect_match(sql, "@vope_table_exists = 1 AND @origin_idx_exists = 0", fixed = TRUE)
  expect_match(sql, "'SELECT 1'", fixed = TRUE)
})

test_that("migration 049 is present and counted in the manifest", {
  # Asserts 049 EXISTS, not that it is the newest. A per-migration guard that
  # pins the global latest breaks every time an unrelated migration is added —
  # which is exactly what happened when 050 landed. The latest-migration
  # assertion belongs in test-unit-core-views-manifest.R, and lives there.
  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", MIGRATION_049),
    file.path(get_api_dir(), "db", "migrations", MIGRATION_049)
  )
  expect_true(any(file.exists(candidates)))
  expect_gte(EXPECTED_MIGRATION_COUNT, 47L)
})
