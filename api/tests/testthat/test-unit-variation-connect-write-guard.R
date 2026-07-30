# tests/testthat/test-unit-variation-connect-write-guard.R
#
# Static guard (#608). The provenance model's load-bearing invariant is:
#
#   "Absence of an assertion row means the annotation is curator-authored."
#
# That invariant only holds if nothing writes curated rows into
# `ndd_review_variation_ontology_connect` without also going through
# provenance reconciliation. The sanctioned write path is
# `functions/ontology-repository.R` (`variation_ontology_connect_to_review()` /
# `variation_ontology_replace_for_review()`), reached through
# `review_write_mutate()` in `services/review-write-service.R`, where
# `variation_provenance_reconcile_for_review()` runs on the SAME transaction
# connection right after the connect-table write (see the comment block above
# that call in review-write-service.R). Any OTHER file that writes the connect
# table bypasses reconciliation and silently reintroduces the #608 laundering
# bug: automated/imported rows would look curator-authored because no
# assertion row was ever recorded for them.
#
# This file has two guards:
#   1. No file outside an explicit allowlist may contain a write
#      (INSERT/UPDATE/DELETE/REPLACE/TRUNCATE) targeting
#      `ndd_review_variation_ontology_connect`, scanned across functions/,
#      services/, endpoints/ (the request/job-execution source tree per
#      AGENTS.md's "API bootstrap and source order" -- the same three
#      directories test-unit-job-payload-credential-guard.R scans).
#   2. The reconciliation wiring itself is locked: review-write-service.R
#      must still call variation_provenance_reconcile_for_review() with
#      conn = txn_conn (the SAME transaction as the curated write). The
#      companion assertion that functions/variation-provenance-reconcile.R
#      is registered in bootstrap/load_modules.R already exists in
#      test-unit-variation-provenance-reconcile.R ("the reconciliation module
#      is registered for runtime loading") -- deliberately NOT duplicated
#      here.
#
# Scan scope deliberately excludes tests/, scripts/, and db/: this guard
# freezes the REQUEST-PATH write surface, not test fixtures or db-repo
# migrations (which have their own, separate #608 enforcement). One
# scripts/ file was investigated and found out of scope -- see the
# allowlist comment below.
#
# Pure test (no DB / no network) -- runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-variation-connect-write-guard.R')"

library(testthat)

CONNECT_TABLE <- "ndd_review_variation_ontology_connect"
WRITE_KEYWORDS <- c("INSERT", "UPDATE", "DELETE", "REPLACE", "TRUNCATE")

# Allowlist by FILE (relative to api/), kept minimal and explicit.
#
#   functions/ontology-repository.R
#     The sanctioned path. variation_ontology_connect_to_review() INSERTs and
#     variation_ontology_replace_for_review() DELETEs-then-INSERTs. Both are
#     called from review_write_mutate() (services/review-write-service.R),
#     which runs variation_provenance_reconcile_for_review() on the same
#     transaction connection immediately afterward -- see guard 2 below.
#
# Investigated and NOT allowlisted (do not need to be -- see report):
#   services/review-service.R defines svc_review_add_variation_ontology() and
#   put_post_db_var_ont_con(). A repo-wide grep for both call sites (excluding
#   their own definitions/roxygen \dontrun examples) found ZERO callers --
#   they are dead code. Both delegate to the SAME sanctioned repository
#   functions (variation_ontology_connect_to_review() /
#   variation_ontology_replace_for_review()) by name rather than embedding
#   raw SQL, so review-service.R contains no literal write statement against
#   the connect table and this text-based guard does not need to allowlist
#   it. They are flagged here as a correctness hazard for a follow-up: if
#   ever re-wired to a live endpoint, they would write the connect table
#   WITHOUT running reconciliation (reconciliation is orchestrated one layer
#   up, in review_write_mutate(), not inside the repository functions they
#   call) -- silently reintroducing the #608 laundering bug. They must not be
#   resurrected without also routing through review_write_mutate(), and the
#   right long-term outcome is deleting them (out of scope for this guard).
#
#   scripts/verify-mcp-select-principal-fixtures.R INSERTs directly into the
#   connect table, but it is a disposable synthetic-fixture seeder for a
#   throwaway MCP principal-verification rig ("No production data or
#   credential is read by this file"), not request/job-execution code. It is
#   out of this guard's scan scope (scripts/ is not scanned) rather than
#   allowlisted.
variation_connect_write_allowlist <- c(
  "functions/ontology-repository.R"
)

variation_connect_scan_dirs <- c("functions", "services", "endpoints")

#' List candidate R source files under the scanned tree.
.variation_connect_scan_files <- function() {
  base <- get_api_dir()
  files <- unlist(lapply(variation_connect_scan_dirs, function(d) {
    list.files(file.path(base, d), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  }))
  files[file.exists(files)]
}

#' Path relative to api/, e.g. "functions/ontology-repository.R".
.variation_connect_relpath <- function(full_path, base) {
  rel <- sub(base, "", full_path, fixed = TRUE)
  sub("^[/\\\\]+", "", rel)
}

#' Find write-keyword-then-table-name matches in a file's normalized text.
#'
#' Strips full-line comments/roxygen (so a doc mention can't trip the guard),
#' then collapses all remaining whitespace (including newlines) into single
#' spaces so a keyword and the table name separated across physical lines
#' (the common multi-line SQL-string-literal style in this codebase) are
#' still adjacent in the scanned text. The keyword-to-table-name gap
#' deliberately EXCLUDES quote characters (`"`/`'`): in standard SQL grammar
#' the table name always immediately follows the keyword (INSERT INTO
#' <table>, DELETE FROM <table>, UPDATE <table>, REPLACE INTO <table>,
#' TRUNCATE TABLE <table>) with no quoted literal in between, so requiring an
#' unbroken, quote-free run between them confines a match to a single R
#' string literal / SQL statement -- a write for a DIFFERENT table earlier
#' in the same file cannot "reach across" its own closing quote to pair with
#' an unrelated later mention of this table (e.g. a read, or a comment).
#' Matching is case-insensitive (SQL keywords/table names are not reliably
#' one case in this codebase).
.variation_connect_write_hits <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[!grepl("^\\s*#", lines)]
  blob <- paste(lines, collapse = " ")
  blob <- gsub("[[:space:]]+", " ", blob)

  pattern <- sprintf(
    "(?i)\\b(%s)\\b[^\"']{0,200}?\\b%s\\b",
    paste(WRITE_KEYWORDS, collapse = "|"),
    CONNECT_TABLE
  )
  m <- gregexpr(pattern, blob, perl = TRUE)
  hits <- regmatches(blob, m)[[1]]
  hits[hits != -1]
}

# ===========================================================================
# Guard 1: no un-allowlisted file writes the connect table
# ===========================================================================

test_that("no file outside the allowlist writes ndd_review_variation_ontology_connect", {
  base <- get_api_dir()
  offenders <- character(0)

  for (f in .variation_connect_scan_files()) {
    rel <- .variation_connect_relpath(f, base)
    if (rel %in% variation_connect_write_allowlist) next

    hits <- .variation_connect_write_hits(f)
    if (length(hits)) {
      offenders <- c(offenders, paste0(rel, ": ", trimws(hits)))
    }
  }

  expect_identical(
    offenders, character(0),
    info = paste(
      "A file outside the allowlist writes ndd_review_variation_ontology_connect",
      "directly. The sanctioned write path is functions/ontology-repository.R",
      "(variation_ontology_connect_to_review() / variation_ontology_replace_for_review()),",
      "reached through review_write_mutate() in services/review-write-service.R, where",
      "provenance reconciliation (variation_provenance_reconcile_for_review()) runs on",
      "the SAME transaction right after the write. Route the new write through that",
      "path instead of writing the table directly, or -- if it is genuinely a new",
      "legitimate write site -- add it to variation_connect_write_allowlist above WITH",
      "a written justification comment explaining why reconciliation does not need to",
      "run for it. Offending matches:", paste(offenders, collapse = " | ")
    )
  )
})

test_that("the allowlist is not vacuous: the sanctioned file really does write the table", {
  path <- file.path(get_api_dir(), "functions", "ontology-repository.R")
  hits <- .variation_connect_write_hits(path)

  expect_true(
    any(grepl("^INSERT", hits, ignore.case = TRUE)),
    info = "Expected an INSERT match in functions/ontology-repository.R"
  )
  expect_true(
    any(grepl("^DELETE", hits, ignore.case = TRUE)),
    info = "Expected a DELETE match in functions/ontology-repository.R"
  )
})

test_that("the write-detector actually flags an offending pattern (the guard can fail)", {
  # Proves the regex logic itself can detect a violation, independent of the
  # real scanned tree above. Uses a throwaway temp file so it never touches
  # functions/services/endpoints.
  tmp <- tempfile(fileext = ".R")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(
    c(
      "some_fn <- function(conn) {",
      "  db_execute_statement(",
      "    \"INSERT INTO ndd_review_variation_ontology_connect",
      "     (review_id, vario_id, modifier_id, entity_id)",
      "     VALUES (?, ?, ?, ?)\",",
      "    list(1, 'VariO:0001', 1, 2),",
      "    conn = conn",
      "  )",
      "}"
    ),
    tmp
  )

  hits <- .variation_connect_write_hits(tmp)
  expect_true(length(hits) >= 1L)
  expect_true(any(grepl("^INSERT", hits, ignore.case = TRUE)))

  # A pure read must NOT trip the detector.
  tmp_read <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_read), add = TRUE)
  writeLines(
    c(
      "some_read_fn <- function() {",
      "  db_execute_query(",
      "    \"SELECT review_id, vario_id FROM ndd_review_variation_ontology_connect",
      "     WHERE review_id = ?\",",
      "    list(1)",
      "  )",
      "}"
    ),
    tmp_read
  )
  expect_identical(.variation_connect_write_hits(tmp_read), character(0))
})

# ===========================================================================
# Guard 2: the reconciliation wiring itself
# ===========================================================================
#
# NOTE: the companion assertion that functions/variation-provenance-reconcile.R
# is registered in bootstrap/load_modules.R already exists as
# test-unit-variation-provenance-reconcile.R's
# "the reconciliation module is registered for runtime loading" test. It is
# deliberately NOT duplicated here.

test_that("review-write-service.R reconciles provenance on the SAME transaction connection", {
  path <- file.path(get_api_dir(), "services", "review-write-service.R")
  lines <- readLines(path, warn = FALSE)
  blob <- paste(gsub("[[:space:]]+", " ", lines), collapse = " ")

  call_pos <- regexpr("variation_provenance_reconcile_for_review\\s*\\(", blob, perl = TRUE)
  expect_true(
    as.integer(call_pos) > 0,
    info = paste(
      "review_write_mutate() must call variation_provenance_reconcile_for_review().",
      "Without it, curated connect-table writes stop being reconciled against",
      "provenance assertions and #608's laundering bug returns."
    )
  )

  call_len <- attr(call_pos, "match.length")
  window <- substr(blob, call_pos, call_pos + call_len + 300L)

  expect_match(
    window, "conn\\s*=\\s*txn_conn",
    perl = TRUE,
    info = paste(
      "variation_provenance_reconcile_for_review() must be called with",
      "conn = txn_conn -- the SAME transaction connection review_write_mutate() uses",
      "for the curated connect-table write. If this were refactored onto its own",
      "connection (e.g. a fresh pool checkout), provenance reconciliation and the",
      "curated write would no longer commit/rollback atomically, which is exactly the",
      "regression this assertion freezes."
    )
  )
})

# ===========================================================================
# Guard 3: the entity-rename carry-forward wiring
# ===========================================================================
#
# The rename path is the OTHER place a curated variation-ontology term set is
# written for a NEW entity_id. svc_entity_rename_full() creates new_entity_id,
# copies the review's connect rows onto it, and must also carry the entity's
# provenance assertions across -- assertions are keyed on entity_id, so a
# rename that skips this leaves the new entity with ZERO assertions, which the
# read contract (functions/variation-provenance-repository.R) defines as
# CURATOR-AUTHORED. A machine-derived, unconfirmed annotation would silently
# become an apparently curator-authored one just by being renamed.
#
# This is a STATIC assertion because an executed end-to-end test is not
# available here: svc_entity_rename_full() calls db_with_transaction()
# unconditionally, with no caller-owned SAVEPOINT branch, so it cannot nest
# inside with_test_db_transaction() the way the review-write path can. The
# carry-forward function itself IS executed against a real database by
# test-integration-variation-provenance-carry-forward.R; what is unverified at
# runtime, and therefore frozen here, is the CALL SITE -- a typo in the
# function name or a dropped `conn =` argument would otherwise reach production
# with only parse-level checking, and the failure mode is silent.

test_that("entity-rename-service.R carries provenance forward on the rename transaction", {
  path <- file.path(get_api_dir(), "services", "entity-rename-service.R")
  lines <- readLines(path, warn = FALSE)
  # Whitespace-normalize before matching: the call may be wrapped across
  # physical lines, and this guard is about the call's presence and its
  # connection argument, not its formatting.
  blob <- paste(gsub("[[:space:]]+", " ", lines), collapse = " ")

  call_pos <- regexpr("variation_provenance_carry_forward_entity\\s*\\(", blob, perl = TRUE)
  expect_true(
    as.integer(call_pos) > 0,
    info = paste(
      "svc_entity_rename_full() must call variation_provenance_carry_forward_entity().",
      "Provenance assertions are keyed on entity_id, so a rename that creates a new",
      "entity_id without copying them leaves the renamed entity with zero assertions --",
      "and zero assertions is exactly what the read path reports as 'curator-authored'.",
      "Dropping this call therefore does not lose a nice-to-have annotation; it",
      "relabels machine-derived, unconfirmed terms as curator-authored on the public",
      "entity card, silently, for every renamed entity. That is #608's laundering bug",
      "reappearing through the rename door."
    )
  )

  call_len <- attr(call_pos, "match.length")
  window <- substr(blob, call_pos, call_pos + call_len + 300L)

  expect_match(
    window, "conn\\s*=\\s*txn_conn",
    perl = TRUE,
    info = paste(
      "variation_provenance_carry_forward_entity() must be called with conn = txn_conn",
      "-- the SAME transaction connection svc_entity_rename_full() uses to create the",
      "new entity and copy its review rows. On a separate connection the carry-forward",
      "would not see the new entity inside the uncommitted rename transaction, and it",
      "would not roll back with it: a rename that failed after this point would leave",
      "orphaned assertion rows, and a carry-forward that failed would leave the renamed",
      "entity's terms reading as curator-authored while the rename itself committed."
    )
  )
})
