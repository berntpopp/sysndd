# Static guard for migration 048_widen_publication_author_columns.sql (#614).
#
# The defect this migration fixes is not a schema nicety: publication ingestion
# runs inside the review-save transaction, so an author name that overflows
# publication.Lastname rolls back the curator's ENTIRE save with an opaque 500.
# PubMed puts a consortium byline in <CollectiveName>, which the parser assigns to
# BOTH Lastname and Firstname, so both columns must be widened -- widening only
# the one named in the bug report would leave the identical failure on the other.
#
# These assertions are deliberately about the migration's TEXT, not a live
# database: they are the things a future "simplification" would quietly remove,
# and they must hold in any environment (no DB required).
#
# Pure test (no DB / no network) -- runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-publication-author-columns.R')"

library(testthat)

MIGRATION_048 <- "048_widen_publication_author_columns.sql"

.publication_author_migration_sql <- function() {
  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", MIGRATION_048),
    file.path(get_api_dir(), "db", "migrations", MIGRATION_048)
  )
  path <- candidates[file.exists(candidates)][1]
  if (is.na(path)) {
    skip(paste("Migration not found:", MIGRATION_048))
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

test_that("migration 048 widens BOTH author columns, not just Lastname", {
  sql <- .publication_author_migration_sql()

  expect_match(sql, "MODIFY COLUMN `Lastname` VARCHAR\\(255\\)", fixed = FALSE)
  expect_match(sql, "MODIFY COLUMN `Firstname` VARCHAR\\(255\\)", fixed = FALSE)
})

test_that("migration 048 restates each column's own charset instead of hardcoding one", {
  # ALTER TABLE ... MODIFY COLUMN does NOT preserve a column's character set when
  # the statement omits one -- it falls back to the TABLE default (utf8mb3 here).
  # A static charset would therefore silently downconvert a column that has
  # drifted to utf8mb4, which is the same trap already documented for
  # disease_ontology_mapping and variation_ontology_list. The charset and
  # collation must be read back from information_schema and re-stated.
  sql <- .publication_author_migration_sql()

  expect_match(sql, "CHARACTER_SET_NAME FROM information_schema\\.COLUMNS")
  expect_match(sql, "COLLATION_NAME FROM information_schema\\.COLUMNS")
  expect_match(sql, "CHARACTER SET ', @pub_lastname_charset", fixed = TRUE)
  expect_match(sql, "CHARACTER SET ', @pub_firstname_charset", fixed = TRUE)
})

test_that("migration 048 is idempotent and restore-drift safe", {
  # Guarded on the live width, so a rerun (or an already-wide column) no-ops and
  # a missing column is skipped rather than erroring.
  sql <- .publication_author_migration_sql()

  expect_match(sql, "@pub_lastname_len IS NOT NULL AND @pub_lastname_len < 255", fixed = TRUE)
  expect_match(sql, "@pub_firstname_len IS NOT NULL AND @pub_firstname_len < 255", fixed = TRUE)
  expect_match(sql, "'SELECT 1'", fixed = TRUE)
})

test_that("the parser's clamp is bound to the widened column width", {
  # The clamp is a backstop for an upstream string longer than the column, so it
  # is only correct while its constant equals the width migration 048 sets. If
  # one moves without the other, the clamp either truncates data the column could
  # have held or stops preventing the overflow it exists to prevent.
  # Sourced explicitly rather than skipped-if-absent: a SKIP here would silently
  # stop guarding the very coupling this test exists for. The parser file has no
  # DB or network dependency, so it loads on the host.
  source_api_file("functions/pubmed-xml-parser.R", local = FALSE)

  expect_equal(PUBLICATION_AUTHOR_NAME_MAX_CHARS, 255L)
  expect_match(.publication_author_migration_sql(), "VARCHAR\\(255\\)")
})
