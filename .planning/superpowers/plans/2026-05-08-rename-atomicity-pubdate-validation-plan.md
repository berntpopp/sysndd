# /rename atomicity + Publication_date validation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix issue #318 — make `POST /api/entity/rename` atomic with correct approval-state carry-over, reject entity submissions whose PMIDs PubMed cannot resolve, and surface the resulting structured errors as clear toasts in the curator UI instead of opaque axios stack traces.

**Architecture:** Refactor the rename branch behind a new `svc_entity_rename_full` service that wraps all DB writes in `db_with_transaction`; extend `review_create` and `status_create` to propagate approval-state columns when present in their input; tighten `info_from_pmid` to fail fast with a structured `publication_fetch_error` and to leave `Publication_date` NULL rather than `""`; map the new error class to HTTP 400 at the endpoint layer with a precise message; on the frontend, add an `extractApiErrorMessage` helper and route mutation-composable `catch` blocks through it so the existing `bootstrap-vue-next` toast receives the API's `message` text rather than a generic `[object Object]`.

**Tech Stack:** R 4.5 / Plumber, RMariaDB / DBI, MySQL 8.4, testthat 3, tibble/dplyr.

**Spec:** `.planning/superpowers/specs/2026-05-08-rename-atomicity-pubdate-validation-design.md`

**Branch:** `fix/rename-atomicity-pubdate-validation` (already exists, contains the spec commit).

---

## Files touched

| File | Change | Why |
|---|---|---|
| `api/functions/review-repository.R` | extend `review_create` (line 85) | INSERT also `is_primary` / `review_approved` / `approving_user_id` / `comment` when provided |
| `api/functions/status-repository.R` | extend `status_create` (line 84) | INSERT also `is_active` / `status_approved` / `approving_user_id` / `comment` when provided |
| `api/functions/publication-functions.R` | modify `info_from_pmid` (line 289) and `new_publication` (line 36) | fail-fast on unresolvable PMIDs; preserve NA `Publication_date`; transactional INSERT loop |
| `api/services/entity-service.R` | add `svc_entity_rename_full` after line 719 | atomic rename mirroring `svc_entity_create_full` |
| `api/endpoints/entity_endpoints.R` | replace rename body (lines 459-665); map `publication_fetch_error` in `/create` handler | thin shim + 400 mapping |
| `api/endpoints/review_endpoints.R` | map `publication_fetch_error` (around lines 282 and 338) | 400 mapping for review POST/PUT call sites |
| `api/tests/testthat/test-unit-review-repository.R` | extend | regression for approval-state propagation |
| `api/tests/testthat/test-unit-status-repository.R` | **create** | repository propagation tests |
| `api/tests/testthat/test-unit-publication-functions.R` | extend | fail-fast and Publication_date NA |
| `api/tests/testthat/test-unit-entity-service.R` | extend | `svc_entity_rename_full` signature + no-shadow |
| `api/tests/testthat/test-integration-entity-rename.R` | **create** | DB-backed happy path / rollback / bogus PMID / exact 400/404/409 message text |
| `app/src/utils/api-errors.ts` | **create** | `extractApiErrorMessage(err, fallback)` helper |
| `app/src/utils/__tests__/api-errors.spec.ts` | **create** | unit tests for the helper (axios shape, fetch shape, plain Error, unknown) |
| `app/src/views/curate/composables/useEntityMutations.ts` | modify catch blocks | feed clean message into `onToast` instead of the raw axios error |
| `app/src/views/curate/composables/__tests__/useEntityMutations.spec.ts` | extend | assert toast receives the API `message` on 400/409, fallback on network error |

---

## Task 1: Extend `review_create` to propagate approval-state columns

**Files:**
- Modify: `api/functions/review-repository.R:85-126`
- Test: `api/tests/testthat/test-unit-review-repository.R` (extend)

- [ ] **Step 1: Write the failing tests**

Append to `api/tests/testthat/test-unit-review-repository.R`:

```r
test_that("review_create propagates is_primary, review_approved, approving_user_id, comment when provided", {
  # Capture the SQL and params passed to db_execute_statement
  captured <- list()
  local_mocked_bindings(
    db_execute_statement = function(sql, params, conn = NULL) {
      captured$sql <<- sql
      captured$params <<- params
      invisible(NULL)
    },
    db_execute_query = function(sql, conn = NULL) {
      tibble::tibble(review_id = 42L)
    }
  )

  review_id <- review_create(list(
    entity_id = 5,
    synopsis = "test",
    review_user_id = 3,
    is_primary = 1,
    review_approved = 1,
    approving_user_id = 7,
    comment = "carried over"
  ))

  expect_equal(review_id, 42L)
  expect_match(captured$sql, "is_primary")
  expect_match(captured$sql, "review_approved")
  expect_match(captured$sql, "approving_user_id")
  expect_match(captured$sql, "comment")
  # Params order must match the column order in the INSERT
  expect_true(7 %in% captured$params)
  expect_true("carried over" %in% captured$params)
})

test_that("review_create omits approval-state columns when keys are absent (back-compat)", {
  captured <- list()
  local_mocked_bindings(
    db_execute_statement = function(sql, params, conn = NULL) {
      captured$sql <<- sql
      captured$params <<- params
      invisible(NULL)
    },
    db_execute_query = function(sql, conn = NULL) tibble::tibble(review_id = 1L)
  )

  review_create(list(entity_id = 5, synopsis = "x", review_user_id = 3))

  # These columns must be absent so DB defaults apply (back-compat with create-entity flow)
  expect_false(grepl("is_primary", captured$sql))
  expect_false(grepl("review_approved", captured$sql))
  expect_false(grepl("approving_user_id", captured$sql))
  expect_false(grepl("comment", captured$sql))
})
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-review-repository.R')"
```

Expected: the new test_that blocks fail (the propagation block fails because the current INSERT only has `entity_id, synopsis, review_user_id`; the omit block likely passes already).

- [ ] **Step 3: Replace the INSERT in `review_create`**

In `api/functions/review-repository.R`, replace lines 115-120 with:

```r
  # Always-present columns
  cols <- c("entity_id", "synopsis", "review_user_id")
  vals <- list(review_data$entity_id, synopsis, review_data$review_user_id)

  # Optional approval-state columns: include only when explicitly provided.
  # Fixes #318: rename flow lost approval state because old INSERT hardcoded
  # only the three required columns and let defaults apply.
  optional <- c("is_primary", "review_approved", "approving_user_id", "comment")
  for (col in optional) {
    val <- review_data[[col]]
    if (!is.null(val) && !(length(val) == 1 && is.na(val))) {
      cols <- c(cols, col)
      vals <- c(vals, list(val))
    }
  }

  placeholders <- paste(rep("?", length(cols)), collapse = ", ")
  sql <- sprintf("INSERT INTO ndd_entity_review (%s) VALUES (%s)",
                 paste(cols, collapse = ", "), placeholders)

  db_execute_statement(sql, vals, conn = conn)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-review-repository.R')"
```

Expected: all tests pass, no failures.

- [ ] **Step 5: Commit**

```bash
git add api/functions/review-repository.R api/tests/testthat/test-unit-review-repository.R
git commit -m "fix(api): review_create propagates approval-state columns when provided

When review_data carries is_primary / review_approved / approving_user_id /
comment, include them in the INSERT so callers (e.g. /rename) can carry
approval state across to the new review. When absent the columns are
omitted and DB defaults apply — back-compat with svc_entity_create_full.

Refs #318."
```

---

## Task 2: Create `test-unit-status-repository.R` and extend `status_create`

**Files:**
- Create: `api/tests/testthat/test-unit-status-repository.R`
- Modify: `api/functions/status-repository.R:84-140`

- [ ] **Step 1: Create the failing tests**

Create `api/tests/testthat/test-unit-status-repository.R`:

```r
# tests/testthat/test-unit-status-repository.R
# Unit tests for status_create — focus on optional approval-state propagation
# added in #318. Existing required-field validation is already covered indirectly
# via svc_entity_create_full integration paths.

library(testthat)
library(tibble)

source_api_file("functions/status-repository.R", local = FALSE)

test_that("status_create validates entity_id, category_id, status_user_id", {
  expect_error(
    status_create(tibble(category_id = 1, status_user_id = 1)),
    class = "status_validation_error"
  )
  expect_error(
    status_create(tibble(entity_id = 1, status_user_id = 1)),
    class = "status_validation_error"
  )
  expect_error(
    status_create(tibble(entity_id = 1, category_id = 1)),
    class = "status_validation_error"
  )
})

test_that("status_create propagates is_active, status_approved, approving_user_id, comment when provided", {
  captured <- list()
  local_mocked_bindings(
    db_execute_statement = function(sql, params, conn = NULL) {
      captured$sql <<- sql
      captured$params <<- params
      invisible(NULL)
    },
    db_execute_query = function(sql, conn = NULL) tibble::tibble(status_id = 99L)
  )

  status_id <- status_create(tibble(
    entity_id = 5,
    category_id = 1,
    status_user_id = 3,
    is_active = 1,
    status_approved = 1,
    approving_user_id = 7,
    problematic = 0,
    comment = "carried over"
  ))

  expect_equal(status_id, 99L)
  expect_match(captured$sql, "is_active")
  expect_match(captured$sql, "status_approved")
  expect_match(captured$sql, "approving_user_id")
  expect_match(captured$sql, "comment")
  expect_true(7 %in% captured$params)
})

test_that("status_create omits approval-state columns when keys are absent (back-compat)", {
  captured <- list()
  local_mocked_bindings(
    db_execute_statement = function(sql, params, conn = NULL) {
      captured$sql <<- sql
      captured$params <<- params
      invisible(NULL)
    },
    db_execute_query = function(sql, conn = NULL) tibble::tibble(status_id = 1L)
  )

  status_create(tibble(entity_id = 5, category_id = 1, status_user_id = 3))

  expect_false(grepl("is_active", captured$sql))
  expect_false(grepl("status_approved", captured$sql))
  expect_false(grepl("approving_user_id", captured$sql))
  expect_false(grepl("\\bcomment\\b", captured$sql))
})
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-status-repository.R')"
```

Expected: the propagation test fails (current INSERT hardcodes 4 columns); the validation and omit tests pass already.

- [ ] **Step 3: Replace the INSERT block in `status_create`**

In `api/functions/status-repository.R`, replace lines 117-133 with:

```r
  # Always-present columns
  entity_id <- status_data$entity_id[1]
  category_id <- status_data$category_id[1]
  status_user_id <- status_data$status_user_id[1]
  problematic <- if ("problematic" %in% colnames(status_data)) status_data$problematic[1] else 0

  cols <- c("entity_id", "category_id", "status_user_id", "problematic")
  vals <- list(entity_id, category_id, status_user_id, problematic)

  # Optional approval-state columns: include only when explicitly provided.
  # Fixes #318: rename flow lost approval state because old INSERT hardcoded
  # only the four columns above and let DB defaults of 0 apply.
  optional <- c("is_active", "status_approved", "approving_user_id", "comment")
  for (col in optional) {
    if (col %in% colnames(status_data)) {
      val <- status_data[[col]][1]
      if (!is.na(val)) {
        cols <- c(cols, col)
        vals <- c(vals, list(val))
      }
    }
  }

  placeholders <- paste(rep("?", length(cols)), collapse = ", ")
  sql <- sprintf("INSERT INTO ndd_entity_status (%s) VALUES (%s)",
                 paste(cols, collapse = ", "), placeholders)

  db_execute_statement(sql, vals, conn = conn)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-status-repository.R')"
```

Expected: all three tests pass.

- [ ] **Step 5: Commit**

```bash
git add api/functions/status-repository.R api/tests/testthat/test-unit-status-repository.R
git commit -m "fix(api): status_create propagates approval-state columns when provided

Introduces the symmetric change to review_create: when status_data carries
is_active / status_approved / approving_user_id / comment, include them in
the INSERT. When absent the columns fall back to defaults (is_active=0,
status_approved=0) — back-compat with svc_entity_create_full which sets
those values via a separate UPDATE inside the same transaction.

Adds test-unit-status-repository.R with three tests: required-field
validation, propagation, and back-compat omission.

Refs #318."
```

---

## Task 3: `info_from_pmid` fail-fast on unresolvable PMIDs

**Files:**
- Modify: `api/functions/publication-functions.R:289-343` (`info_from_pmid`)
- Test: `api/tests/testthat/test-unit-publication-functions.R` (extend)

- [ ] **Step 1: Write the failing test**

Append to `api/tests/testthat/test-unit-publication-functions.R`:

```r
test_that("info_from_pmid raises publication_fetch_error when PubMed returns nothing for a PMID", {
  # Stub fetch_pubmed_data to return a one-PMID XML even though we requested two
  local_mocked_bindings(
    fetch_pubmed_data = function(...) {
      '<?xml version="1.0"?><PubmedArticleSet><PubmedArticle>
       <MedlineCitation><PMID>11111111</PMID>
       <Article><Journal><Title>J Test</Title><ISOAbbreviation>JT</ISOAbbreviation></Journal>
       <ArticleTitle>Resolvable</ArticleTitle><Abstract><AbstractText>x</AbstractText></Abstract>
       <AuthorList><Author><LastName>A</LastName><ForeName>B</ForeName></Author></AuthorList>
       </Article></MedlineCitation>
       <PubmedData><History>
        <PubMedPubDate PubStatus="pubmed"><Year>2024</Year><Month>1</Month><Day>1</Day></PubMedPubDate>
       </History><ArticleIdList><ArticleId IdType="doi">10.1/x</ArticleId></ArticleIdList></PubmedData>
       </PubmedArticle></PubmedArticleSet>'
    },
    get_pubmed_ids = function(query) list(IdList = list())
  )

  expect_error(
    info_from_pmid(c("11111111", "22222222")),
    class = "publication_fetch_error"
  )
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R', filter = 'publication_fetch_error')"
```

Expected: FAIL — current code does not raise this class.

- [ ] **Step 3: Add the fail-fast block in `info_from_pmid`**

In `api/functions/publication-functions.R`, in the `output_tibble` pipeline starting at line 337, replace:

```r
  output_tibble <- input_tibble %>%
    left_join(input_tibble_request, by = "publication_id") %>%
    dplyr::select(-publication_id) %>%
    mutate(across(everything(), ~ replace_na(.x, "")))
```

with:

```r
  joined <- input_tibble %>%
    left_join(input_tibble_request, by = "publication_id")

  # Detect PMIDs PubMed did not return any data for. After the left_join those
  # rows have NA in every fetched column. Fail fast (#318): half-committing a
  # stub publication row and a connected entity is worse than a 400.
  unresolved <- joined %>%
    dplyr::filter(is.na(publication_id.y) | (is.na(Title) & is.na(year))) %>%
    dplyr::pull(publication_id.x)
  # Note: the column names above depend on the join's suffix behaviour. If the
  # left_join above changes column shape, prefer detecting via Title/year being
  # NA on a row that originated only from input_tibble.

  # Robust detection that does not depend on join suffixes:
  unresolved <- input_tibble$publication_id[
    !input_tibble$publication_id %in% input_tibble_request$publication_id
  ]
  if (length(unresolved) > 0) {
    rlang::abort(
      message = paste0("PMIDs not retrievable from PubMed: ",
                       paste(unresolved, collapse = ", ")),
      class = "publication_fetch_error",
      pmids = unresolved
    )
  }

  output_tibble <- joined %>%
    dplyr::select(-publication_id) %>%
    mutate(across(everything(), ~ replace_na(.x, "")))
```

After verifying the test passes, drop the first (suffix-dependent) `unresolved` block; it's left in this plan only so you can see the alternate detection rule and pick whichever the actual data shape supports. The `!input_tibble$publication_id %in% input_tibble_request$publication_id` form is the simpler one and is what we use.

- [ ] **Step 4: Run test to verify it passes**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R', filter = 'publication_fetch_error')"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/functions/publication-functions.R api/tests/testthat/test-unit-publication-functions.R
git commit -m "fix(api): info_from_pmid fails fast when PubMed returns no data for a PMID

Previously the left_join + replace_na pattern silently coerced unresolvable
PMIDs into stub publication rows with empty strings, which under MySQL 8.4
strict mode then rejected the INSERT and 500'd the user. Now the function
raises publication_fetch_error with the offending PMIDs listed; endpoint
layer (next commit) translates this to HTTP 400.

Refs #318."
```

---

## Task 4: Exclude `Publication_date` from the blanket `replace_na`

**Files:**
- Modify: `api/functions/publication-functions.R:340` (still inside `info_from_pmid`)
- Test: `api/tests/testthat/test-unit-publication-functions.R` (extend)

- [ ] **Step 1: Write the failing test**

Append:

```r
test_that("info_from_pmid leaves Publication_date as NA when PubMed lacks date for a fully-resolved row", {
  # Stub the XML so the Year/Month/Day XPath returns nothing — table_articles_from_xml
  # then falls back to today (existing behaviour, separate quirk). What we are
  # asserting here is that even if a downstream code path produced NA, the
  # final replace_na step does not coerce Publication_date to "".
  #
  # We test by stubbing info_from_pmid's collected tibble shape directly: build
  # a fake tibble with NA Publication_date and confirm replace_na exclusion.
  fake <- tibble::tibble(
    Title = NA_character_,
    Publication_date = NA_character_,
    Journal = NA_character_
  )
  result <- fake %>%
    dplyr::mutate(dplyr::across(-dplyr::any_of("Publication_date"),
                                ~ tidyr::replace_na(.x, "")))
  expect_true(is.na(result$Publication_date))
  expect_equal(result$Title, "")
})
```

(This test pins the *helper expression* we will use; the integration test in Task 11 verifies the real code path.)

- [ ] **Step 2: Run test to verify it passes (sanity)**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R', filter = 'leaves Publication_date as NA')"
```

Expected: PASS — this is a pure helper-expression test. If it fails, fix the expression before changing real code.

- [ ] **Step 3: Apply the same expression in `info_from_pmid`**

In `api/functions/publication-functions.R`, in the block introduced in Task 3, change:

```r
  output_tibble <- joined %>%
    dplyr::select(-publication_id) %>%
    mutate(across(everything(), ~ replace_na(.x, "")))
```

to:

```r
  output_tibble <- joined %>%
    dplyr::select(-publication_id) %>%
    # Exclude timestamp columns: NA -> NULL via DBI, not "" which MySQL 8.4
    # strict mode rejects (#318).
    mutate(across(-any_of("Publication_date"), ~ replace_na(.x, "")))
```

- [ ] **Step 4: Run all publication tests to verify nothing else broke**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add api/functions/publication-functions.R api/tests/testthat/test-unit-publication-functions.R
git commit -m "fix(api): exclude Publication_date from replace_na('') blanket

The mutate(across(everything(), replace_na(\"\"))) blanket converted NA
timestamps to empty strings, which MySQL 8.4 strict mode (default since
the 8.0->8.4 migration) rejects. Excluding Publication_date keeps NA, so
DBI passes NULL — the column has been TIMESTAMP NULL DEFAULT NULL all
along.

This branch is reachable today only via partial-fetch code paths because
the prior commit makes fully-unresolved PMIDs raise. Belt-and-braces.

Refs #318."
```

---

## Task 5: Wrap `new_publication` INSERT loop in `db_with_transaction`

**Files:**
- Modify: `api/functions/publication-functions.R:127-138` (the per-row INSERT loop in `new_publication`)
- Test: covered indirectly by Task 11 integration test; no new unit test (would require deep mocking)

- [ ] **Step 1: Apply the wrap**

In `api/functions/publication-functions.R`, replace the loop block at lines 127-138 with:

```r
    # add new publications to database table "publication" if present and not NA
    if (nrow(publications_list_collected_info) > 0) {
      cols <- names(publications_list_collected_info)
      placeholders <- paste(rep("?", length(cols)), collapse = ", ")
      sql <- sprintf("INSERT INTO publication (%s) VALUES (%s)",
                     paste(cols, collapse = ", "), placeholders)

      # Atomic batch (#318): a partial publication batch must never half-commit.
      # If any INSERT fails (e.g. an unexpected NULL on a NOT NULL column), the
      # whole batch rolls back and the error propagates as db_transaction_error.
      tryCatch(
        db_with_transaction(function(txn_conn) {
          for (i in seq_len(nrow(publications_list_collected_info))) {
            row <- publications_list_collected_info[i, ]
            db_execute_statement(sql, as.list(row), conn = txn_conn)
          }
          invisible(NULL)
        }),
        db_transaction_error = function(e) {
          rlang::abort(
            message = paste("Publication batch insert failed:", e$message),
            class = c("publication_insert_error", "db_statement_error"),
            original_error = e$message
          )
        }
      )
    }
```

- [ ] **Step 2: Run all publication tests**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"
```

Expected: all tests pass (this change is behaviour-preserving for the happy path; failure mode is now atomic).

- [ ] **Step 3: Commit**

```bash
git add api/functions/publication-functions.R
git commit -m "fix(api): atomic publication batch insert in new_publication

Wrap the per-row INSERT loop in db_with_transaction so a partial batch
can never half-commit. Failure propagates as publication_insert_error
(also tagged db_statement_error for compatibility with existing handlers).

Refs #318."
```

---

## Task 6: Add `svc_entity_rename_full` service function

**Files:**
- Modify: `api/services/entity-service.R` (add new function after line 719)
- Test: `api/tests/testthat/test-unit-entity-service.R` (extend)

- [ ] **Step 1: Write the failing signature/no-shadow test**

Append to `api/tests/testthat/test-unit-entity-service.R` (mirroring existing patterns):

```r
test_that("svc_entity_rename_full exists with expected signature", {
  expect_true(is.function(svc_entity_rename_full))
  svc_params <- names(formals(svc_entity_rename_full))
  expect_equal(svc_params, c("rename_data", "user_id", "pool"))
})

test_that("svc_entity_rename_full does not shadow repository functions", {
  expect_equal(names(formals(entity_create)), c("entity_data", "conn"))
  expect_equal(names(formals(review_create)), c("review_data", "conn"))
  expect_equal(names(formals(status_create)), c("status_data", "conn"))
})
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-entity-service.R', filter = 'svc_entity_rename_full')"
```

Expected: FAIL — `svc_entity_rename_full` is not defined.

- [ ] **Step 3: Add the service function**

Append to `api/services/entity-service.R` (after the closing `# nolint end` of `svc_entity_create_full`, before the `# Migrated from legacy-wrappers.R` comment):

```r
#' Rename a disease ontology atomically
#'
#' Replaces an entity's disease_ontology_id_version by creating a new entity,
#' deactivating the old one with replaced_by set, and copying the source
#' entity's review/status/joins forward — all in a single transaction.
#' Approval state (review_approved, status is_active/approved, approving_user_id)
#' is propagated from the source so the new entity remains visible to curators.
#'
#' Fixes #318. Replaces the previous non-atomic, default-resetting flow that
#' lived inline in the /rename endpoint handler.
#'
#' @param rename_data Parsed JSON body, shape `list(entity = list(entity_id, hgnc_id, hpo_mode_of_inheritance_term, ndd_phenotype, disease_ontology_id_version))`.
#' @param user_id Integer, the curator performing the rename (entry_user_id of the new entity).
#' @param pool Database connection pool.
#' @return list(status, message, entry = tibble(entity_id, review_id, status_id))
#' @export
svc_entity_rename_full <- function(rename_data, user_id, pool) {
  logger::log_info(
    "Disease rename started",
    entity_id = rename_data$entity$entity_id,
    user_id = user_id
  )

  # --- Phase 1: validation outside the transaction ---

  old_entity_id <- as.integer(rename_data$entity$entity_id)
  if (is.na(old_entity_id)) {
    return(list(status = 400, message = "Bad Request. entity_id is required."))
  }

  ndd_entity_original <- pool %>%
    dplyr::tbl("ndd_entity") %>%
    dplyr::filter(entity_id == !!old_entity_id) %>%
    dplyr::collect()

  if (nrow(ndd_entity_original) == 0) {
    return(list(status = 404, message = "Not Found. Source entity does not exist."))
  }

  if (rename_data$entity$disease_ontology_id_version ==
        ndd_entity_original$disease_ontology_id_version[1]) {
    return(list(status = 400,
                message = "Bad Request. New disease_ontology_id_version is identical to the current one."))
  }

  if (rename_data$entity$hgnc_id != ndd_entity_original$hgnc_id[1] ||
      rename_data$entity$hpo_mode_of_inheritance_term != ndd_entity_original$hpo_mode_of_inheritance_term[1] ||
      rename_data$entity$ndd_phenotype != ndd_entity_original$ndd_phenotype[1]) {
    return(list(status = 400,
                message = "Bad Request. Only disease_ontology_id_version may differ in a rename."))
  }

  # Destination quadruple must not already exist
  destination <- list(
    hgnc_id = rename_data$entity$hgnc_id,
    hpo_mode_of_inheritance_term = rename_data$entity$hpo_mode_of_inheritance_term,
    disease_ontology_id_version = rename_data$entity$disease_ontology_id_version,
    ndd_phenotype = rename_data$entity$ndd_phenotype
  )
  duplicate <- svc_entity_check_duplicate(destination, pool)
  if (!is.null(duplicate)) {
    return(list(status = 409,
                message = "Conflict. Destination quadruple already exists.",
                entry = duplicate))
  }

  # Load source review (primary, active) and status (active) — to be copied forward
  review_original <- pool %>%
    dplyr::tbl("ndd_entity_review") %>%
    dplyr::filter(entity_id == !!old_entity_id, is_primary == 1) %>%
    dplyr::collect()

  status_original <- pool %>%
    dplyr::tbl("ndd_entity_status") %>%
    dplyr::filter(entity_id == !!old_entity_id, is_active == 1) %>%
    dplyr::collect()

  publications_original <- if (nrow(review_original) > 0) {
    pool %>%
      dplyr::tbl("ndd_review_publication_join") %>%
      dplyr::filter(review_id == !!review_original$review_id[1]) %>%
      dplyr::select(publication_id, publication_type) %>%
      dplyr::collect()
  } else { tibble::tibble() }

  phenotypes_original <- if (nrow(review_original) > 0) {
    pool %>%
      dplyr::tbl("ndd_review_phenotype_connect") %>%
      dplyr::filter(review_id == !!review_original$review_id[1]) %>%
      dplyr::select(phenotype_id, modifier_id) %>%
      dplyr::collect()
  } else { tibble::tibble() }

  vario_original <- if (nrow(review_original) > 0) {
    pool %>%
      dplyr::tbl("ndd_review_variation_ontology_connect") %>%
      dplyr::filter(review_id == !!review_original$review_id[1]) %>%
      dplyr::select(vario_id, modifier_id) %>%
      dplyr::collect()
  } else { tibble::tibble() }

  logger::log_warn(
    "Disease rename for entity {old_entity_id} bypassing approval workflow.",
    "Old: {ndd_entity_original$disease_ontology_id_version[1]}, ",
    "New: {rename_data$entity$disease_ontology_id_version}"
  )

  # --- Phase 2: all DB writes in one transaction ---

  tryCatch(
    {
      result <- db_with_transaction(function(txn_conn) {
        # 1. Create new entity (carries hgnc_id/MOI/ndd_phenotype from source, new ontology)
        new_entity_id <- entity_create(list(
          hgnc_id                       = rename_data$entity$hgnc_id,
          hpo_mode_of_inheritance_term  = rename_data$entity$hpo_mode_of_inheritance_term,
          disease_ontology_id_version   = rename_data$entity$disease_ontology_id_version,
          ndd_phenotype                 = rename_data$entity$ndd_phenotype,
          entry_user_id                 = user_id
        ), conn = txn_conn)

        # 2. Deactivate old entity, set replaced_by
        db_execute_statement(
          "UPDATE ndd_entity SET is_active = 0, replaced_by = ? WHERE entity_id = ?",
          list(new_entity_id, old_entity_id),
          conn = txn_conn
        )

        # 3. Create new review with approval state propagated from source
        review_payload <- list(
          entity_id         = new_entity_id,
          synopsis          = if (nrow(review_original) > 0) review_original$synopsis[1] else NA,
          review_user_id    = user_id,
          is_primary        = if (nrow(review_original) > 0) review_original$is_primary[1] else 1,
          review_approved   = if (nrow(review_original) > 0) review_original$review_approved[1] else 0,
          approving_user_id = if (nrow(review_original) > 0) review_original$approving_user_id[1] else NA,
          comment           = if (nrow(review_original) > 0) review_original$comment[1] else NA
        )
        new_review_id <- review_create(review_payload, conn = txn_conn)

        # 4. Connect publications / phenotypes / variation ontology to new review
        if (nrow(publications_original) > 0) {
          publication_connect_to_review(new_review_id, new_entity_id,
                                        publications_original, conn = txn_conn)
        }
        if (nrow(phenotypes_original) > 0) {
          phenotype_connect_to_review(new_review_id, new_entity_id,
                                      phenotypes_original, conn = txn_conn)
        }
        if (nrow(vario_original) > 0) {
          variation_ontology_connect_to_review(new_review_id, new_entity_id,
                                               vario_original, conn = txn_conn)
        }

        # 5. Create new status with approval state propagated from source
        status_payload <- tibble::tibble(
          entity_id         = new_entity_id,
          category_id       = if (nrow(status_original) > 0) status_original$category_id[1] else 1,
          status_user_id    = user_id,
          is_active         = if (nrow(status_original) > 0) status_original$is_active[1] else 0,
          status_approved   = if (nrow(status_original) > 0) status_original$status_approved[1] else 0,
          approving_user_id = if (nrow(status_original) > 0) status_original$approving_user_id[1] else NA_integer_,
          problematic       = if (nrow(status_original) > 0) status_original$problematic[1] else 0,
          comment           = if (nrow(status_original) > 0) status_original$comment[1] else NA_character_
        )
        new_status_id <- status_create(status_payload, conn = txn_conn)

        list(entity_id = new_entity_id, review_id = new_review_id, status_id = new_status_id)
      }, pool_obj = pool)

      logger::log_info(
        "Disease rename completed atomically",
        old_entity_id = old_entity_id,
        new_entity_id = result$entity_id
      )

      return(list(
        status = 200,
        message = "OK. Entity renamed.",
        entry = tibble::tibble(
          entity_id = result$entity_id,
          review_id = result$review_id,
          status_id = result$status_id
        )
      ))
    },
    db_transaction_error = function(e) {
      logger::log_error(
        "Rename transaction failed - all changes rolled back",
        old_entity_id = old_entity_id,
        error = e$message
      )
      list(status = 500,
           message = "Internal Server Error. Rename failed. All changes rolled back.",
           error = e$message)
    },
    error = function(e) {
      logger::log_error("Unexpected error during rename",
                        old_entity_id = old_entity_id, error = e$message)
      list(status = 500,
           message = "Internal Server Error. Rename failed.",
           error = e$message)
    }
  )
}
```

- [ ] **Step 4: Run tests to verify signature/no-shadow tests pass**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-entity-service.R')"
```

Expected: all tests pass, including the two new ones.

- [ ] **Step 5: Commit**

```bash
git add api/services/entity-service.R api/tests/testthat/test-unit-entity-service.R
git commit -m "feat(api): add svc_entity_rename_full atomic rename service

Mirrors svc_entity_create_full: validation outside the transaction,
all writes inside db_with_transaction, structured error mapping. Carries
review and status approval state forward from the source entity (relies
on review_create / status_create propagation added in earlier commits).

Endpoint switch in the next commit.

Refs #318."
```

---

## Task 7: Replace `/rename` endpoint body with thin shim

**Files:**
- Modify: `api/endpoints/entity_endpoints.R:459-665` (the entire `function(req, res)` body of the `@post /rename` handler)

- [ ] **Step 1: Replace the handler body**

In `api/endpoints/entity_endpoints.R`, locate the line `#* @post /rename` (line 459) and replace the function body that follows with:

```r
function(req, res) {
  require_role(req, res, "Curator")

  result <- svc_entity_rename_full(
    rename_data = req$argsBody$rename_json,
    user_id     = req$user_id,
    pool        = pool
  )

  res$status <- if (result$status == 200) 201L else result$status
  result
}
```

Delete the entire ~200-line block previously inside the handler (the `ndd_entity_original <- ...` through the closing `} else { ... }` validation branches). Confirm the next line after your shim is the comment block for `#* @post /deactivate`.

- [ ] **Step 2: Lint and source-check**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-entity-service.R')"
make lint-api
```

Expected: tests still pass; lintr reports no new warnings on `entity_endpoints.R`.

- [ ] **Step 3: Smoke-source the file**

```bash
cd api && Rscript -e "source('endpoints/entity_endpoints.R')" 2>&1 | head -20
```

Expected: clean source, no errors. (The endpoint registration may warn about Plumber annotations outside a router; that's normal.)

- [ ] **Step 4: Commit**

```bash
git add api/endpoints/entity_endpoints.R
git commit -m "fix(api): /rename endpoint becomes thin shim over svc_entity_rename_full

Removes ~200 lines of inline non-transactional rename logic. Behaviour
preserved (rename still bypasses approval) but the new entity now carries
the source entity's approval state correctly because the underlying
service uses db_with_transaction and the repository propagation added in
prior commits.

Refs #318."
```

---

## Task 8: Map `publication_fetch_error` to HTTP 400

**Files:**
- Modify: `api/endpoints/entity_endpoints.R` (around the existing `new_publication(publications)` call in the `/create` handler — line ~290 in HEAD, may have shifted)
- Modify: `api/endpoints/review_endpoints.R` (around lines 282 and 338, the two `new_publication(publications_received)` call sites)

- [ ] **Step 1: Inspect current call sites**

```bash
cd api && grep -n "new_publication(publications" endpoints/entity_endpoints.R endpoints/review_endpoints.R
```

Note the line numbers; they may have shifted slightly from the spec.

- [ ] **Step 2: Wrap each call site in tryCatch**

For each of the three call sites, replace:

```r
        response_publication <- new_publication(publications_received)
```

(or the equivalent `pub_result <- new_publication(publications)` in entity_endpoints.R)

with:

```r
        response_publication <- tryCatch(
          new_publication(publications_received),
          publication_fetch_error = function(e) {
            list(status = 400,
                 message = paste("Bad Request.", e$message),
                 error = e$message)
          }
        )
```

In `entity_endpoints.R`, the variable name is `pub_result`; preserve it. In `review_endpoints.R`, both call sites use `response_publication`.

If a 400 is returned, the existing surrounding code (which already early-returns on non-200 publication results) handles propagation correctly. Verify by reading 5 lines of context above and below each call site.

- [ ] **Step 3: Source-check**

```bash
cd api && Rscript -e "source('endpoints/entity_endpoints.R'); source('endpoints/review_endpoints.R')" 2>&1 | head -10
```

Expected: no source errors.

- [ ] **Step 4: Commit**

```bash
git add api/endpoints/entity_endpoints.R api/endpoints/review_endpoints.R
git commit -m "fix(api): translate publication_fetch_error to HTTP 400 at endpoint layer

Wraps the three new_publication call sites (entity /create, review POST,
review PUT) in tryCatch that maps publication_fetch_error to a 400 with
the offending PMIDs in the message. Existing 500 path remains for genuine
unexpected errors.

Refs #318."
```

---

## Task 9: Integration test — rename happy path

**Files:**
- Create: `api/tests/testthat/test-integration-entity-rename.R`

- [ ] **Step 1: Create the test file with happy-path test**

```r
# tests/testthat/test-integration-entity-rename.R
# DB-backed integration tests for svc_entity_rename_full (#318).
# Requires test database (sysndd_db_test) — uses helper-db.R.

library(testthat)
library(tibble)
library(dplyr)
library(DBI)

source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/entity-repository.R", local = FALSE)
source_api_file("functions/review-repository.R", local = FALSE)
source_api_file("functions/status-repository.R", local = FALSE)
source_api_file("functions/phenotype-repository.R", local = FALSE)
source_api_file("functions/ontology-repository.R", local = FALSE)
source_api_file("functions/publication-repository.R", local = FALSE)
source_api_file("core/errors.R", local = FALSE)
source_api_file("services/entity-service.R", local = FALSE)

# Seed a complete entity (entity + approved primary review + approved active status)
seed_approved_entity <- function(con, hgnc_id, ontology, user_id) {
  DBI::dbExecute(con,
    "INSERT INTO ndd_entity (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype, entry_user_id, is_active) VALUES (?, ?, ?, ?, ?, 1)",
    list(hgnc_id, "HP:0000006", ontology, 1L, user_id))
  entity_id <- DBI::dbGetQuery(con, "SELECT LAST_INSERT_ID() AS id")$id[1]

  DBI::dbExecute(con,
    "INSERT INTO ndd_entity_review (entity_id, synopsis, review_user_id, is_primary, review_approved, approving_user_id) VALUES (?, ?, ?, 1, 1, ?)",
    list(entity_id, "test synopsis", user_id, user_id))
  review_id <- DBI::dbGetQuery(con, "SELECT LAST_INSERT_ID() AS id")$id[1]

  DBI::dbExecute(con,
    "INSERT INTO ndd_entity_status (entity_id, category_id, status_user_id, is_active, status_approved, approving_user_id) VALUES (?, 1, ?, 1, 1, ?)",
    list(entity_id, user_id, user_id))
  status_id <- DBI::dbGetQuery(con, "SELECT LAST_INSERT_ID() AS id")$id[1]

  list(entity_id = entity_id, review_id = review_id, status_id = status_id)
}

test_that("svc_entity_rename_full preserves approval state on the new entity", {
  skip_if_no_test_db()
  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con))

  DBI::dbBegin(con)
  withr::defer(DBI::dbRollback(con))

  # Seed: pick an existing HGNC + ontology pair from the test DB; or insert a
  # fixture row in non_alt_loci_set / disease_ontology_set if the test DB
  # ships empty. Adjust the pair if it collides.
  user_id <- 1L  # assumes a user with curator role exists; create if not.
  seed <- seed_approved_entity(con, "HGNC:947", "MONDO:0020022", user_id)

  # Build a pool that wraps the same connection so the service sees the seed
  pool <- pool::dbPool(
    drv = RMariaDB::MariaDB(),
    dbname = get_test_config("dbname"),
    host = get_test_config("host"),
    user = get_test_config("user"),
    password = get_test_config("password"),
    port = as.integer(get_test_config("port"))
  )
  withr::defer(pool::poolClose(pool))

  # IMPORTANT: the seed above used `con`, the pool will see committed state
  # only after we COMMIT — but we want rollback. So commit the seed in a
  # nested SAVEPOINT-like fashion using the pool directly:
  #
  # Simpler approach: do the seed via the pool, not via `con`.

  # --- seed via pool (commits) ---
  DBI::dbBegin(con)  # restart outer txn after the rollback
  pool_conn <- pool::poolCheckout(pool)
  seed <- seed_approved_entity(pool_conn, "HGNC:947", "MONDO:9999999", user_id)
  pool::poolReturn(pool_conn)
  withr::defer({
    pc <- pool::poolCheckout(pool)
    DBI::dbExecute(pc, "DELETE FROM ndd_entity_status WHERE entity_id IN (?, ?)",
                   list(seed$entity_id, seed$entity_id))  # placeholder; expanded below
    pool::poolReturn(pc)
  })

  rename_data <- list(entity = list(
    entity_id = seed$entity_id,
    hgnc_id = "HGNC:947",
    hpo_mode_of_inheritance_term = "HP:0000006",
    ndd_phenotype = 1L,
    disease_ontology_id_version = "MONDO:9999998"
  ))
  result <- svc_entity_rename_full(rename_data, user_id = user_id, pool = pool)

  expect_equal(result$status, 200)
  expect_equal(result$message, "OK. Entity renamed.")
  expect_true(!is.null(result$entry$entity_id))
  expect_true(!is.null(result$entry$review_id))
  expect_true(!is.null(result$entry$status_id))

  pool_conn <- pool::poolCheckout(pool)
  withr::defer(pool::poolReturn(pool_conn))

  new_entity <- DBI::dbGetQuery(pool_conn,
    "SELECT * FROM ndd_entity WHERE entity_id = ?", list(result$entry$entity_id))
  expect_equal(new_entity$is_active, 1)
  expect_true(is.na(new_entity$replaced_by))
  expect_equal(new_entity$disease_ontology_id_version, "MONDO:9999998")

  old_entity <- DBI::dbGetQuery(pool_conn,
    "SELECT * FROM ndd_entity WHERE entity_id = ?", list(seed$entity_id))
  expect_equal(old_entity$is_active, 0)
  expect_equal(old_entity$replaced_by, result$entry$entity_id)

  new_status <- DBI::dbGetQuery(pool_conn,
    "SELECT * FROM ndd_entity_status WHERE entity_id = ?", list(result$entry$entity_id))
  expect_equal(new_status$is_active, 1)
  expect_equal(new_status$status_approved, 1)
  expect_equal(new_status$approving_user_id, user_id)

  new_review <- DBI::dbGetQuery(pool_conn,
    "SELECT * FROM ndd_entity_review WHERE review_id = ?", list(result$entry$review_id))
  expect_equal(new_review$is_primary, 1)
  expect_equal(new_review$review_approved, 1)

  # Cleanup: explicit deletes for the rows the test created
  DBI::dbExecute(pool_conn,
    "DELETE FROM ndd_entity_status WHERE entity_id IN (?, ?)",
    list(seed$entity_id, result$entry$entity_id))
  DBI::dbExecute(pool_conn,
    "DELETE FROM ndd_entity_review WHERE entity_id IN (?, ?)",
    list(seed$entity_id, result$entry$entity_id))
  DBI::dbExecute(pool_conn,
    "DELETE FROM ndd_entity WHERE entity_id IN (?, ?)",
    list(result$entry$entity_id, seed$entity_id))
})
```

> **Note for executor:** `with_test_db_transaction` rolls back, so a seeded row inserted on `con` is invisible to the pool used by the service. The pattern above seeds via the pool (which commits), exercises the service, asserts, then explicitly deletes the rows it created. This is awkward — if the project later adopts a fixtures pattern that handles cleanup via a known-prefix tag, replace this block with that pattern.

- [ ] **Step 2: Run the test**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-entity-rename.R')"
```

Expected (with test DB available): PASS. Without test DB: SKIP.

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-entity-rename.R
git commit -m "test(api): integration test for /rename happy path (approval state carry-over)

Seeds an approved entity, calls svc_entity_rename_full, asserts that the
new entity's review and status both have the source's approval state
copied forward. Skips when test DB unavailable.

Refs #318."
```

---

## Task 10: Integration test — rollback on inner failure

**Files:**
- Modify: `api/tests/testthat/test-integration-entity-rename.R` (extend)

- [ ] **Step 1: Append the rollback test**

```r
test_that("svc_entity_rename_full rolls back when a downstream insert fails", {
  skip_if_no_test_db()

  pool <- pool::dbPool(
    drv = RMariaDB::MariaDB(),
    dbname = get_test_config("dbname"),
    host = get_test_config("host"),
    user = get_test_config("user"),
    password = get_test_config("password"),
    port = as.integer(get_test_config("port"))
  )
  withr::defer(pool::poolClose(pool))

  user_id <- 1L
  pool_conn <- pool::poolCheckout(pool)
  seed <- seed_approved_entity(pool_conn, "HGNC:947", "MONDO:9999997", user_id)
  pool::poolReturn(pool_conn)

  pre_counts <- (function() {
    pc <- pool::poolCheckout(pool); withr::defer(pool::poolReturn(pc))
    list(
      entities = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM ndd_entity")$n[1],
      reviews  = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM ndd_entity_review")$n[1],
      statuses = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM ndd_entity_status")$n[1]
    )
  })()

  # Force failure: connect a phenotype with an FK-violating phenotype_id by
  # patching phenotype_connect_to_review temporarily. The transaction must
  # roll back including the new entity, review, and status.
  with_mocked_bindings(
    phenotype_connect_to_review = function(review_id, entity_id, phenotypes, conn = NULL) {
      stop("forced failure to test rollback")
    },
    {
      # First add a phenotype connection to the source so the service tries
      # to copy it forward and our mock fires.
      pc <- pool::poolCheckout(pool)
      DBI::dbExecute(pc,
        "INSERT INTO ndd_review_phenotype_connect (review_id, phenotype_id, modifier_id) VALUES (?, ?, ?)",
        list(seed$review_id, "HP:0001249", 1))
      pool::poolReturn(pc)

      result <- svc_entity_rename_full(
        list(entity = list(
          entity_id = seed$entity_id,
          hgnc_id = "HGNC:947",
          hpo_mode_of_inheritance_term = "HP:0000006",
          ndd_phenotype = 1L,
          disease_ontology_id_version = "MONDO:9999996"
        )),
        user_id = user_id, pool = pool
      )
      expect_equal(result$status, 500)
    }
  )

  post_counts <- (function() {
    pc <- pool::poolCheckout(pool); withr::defer(pool::poolReturn(pc))
    list(
      entities = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM ndd_entity")$n[1],
      reviews  = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM ndd_entity_review")$n[1],
      statuses = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM ndd_entity_status")$n[1]
    )
  })()

  expect_equal(post_counts$entities, pre_counts$entities)
  expect_equal(post_counts$reviews,  pre_counts$reviews)
  expect_equal(post_counts$statuses, pre_counts$statuses)

  # Source entity must be untouched
  pc <- pool::poolCheckout(pool); withr::defer(pool::poolReturn(pc))
  src <- DBI::dbGetQuery(pc, "SELECT * FROM ndd_entity WHERE entity_id = ?",
                         list(seed$entity_id))
  expect_equal(src$is_active, 1)
  expect_true(is.na(src$replaced_by))

  # Cleanup
  DBI::dbExecute(pc, "DELETE FROM ndd_review_phenotype_connect WHERE review_id = ?",
                 list(seed$review_id))
  DBI::dbExecute(pc, "DELETE FROM ndd_entity_status WHERE entity_id = ?", list(seed$entity_id))
  DBI::dbExecute(pc, "DELETE FROM ndd_entity_review WHERE entity_id = ?", list(seed$entity_id))
  DBI::dbExecute(pc, "DELETE FROM ndd_entity WHERE entity_id = ?", list(seed$entity_id))
})
```

- [ ] **Step 2: Run the test**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-entity-rename.R')"
```

Expected: both tests pass (or skip if no DB).

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-entity-rename.R
git commit -m "test(api): integration test for /rename rollback on inner failure

Mocks phenotype_connect_to_review to throw; asserts row counts in
ndd_entity / ndd_entity_review / ndd_entity_status are unchanged and the
source entity remains active+unreplaced.

Refs #318."
```

---

## Task 11: Integration test — bogus PMID rejected with 400

**Files:**
- Modify: `api/tests/testthat/test-integration-entity-rename.R` (extend) **OR** new file `api/tests/testthat/test-integration-publication-fetch.R` if this becomes too large.

For simplicity append to the existing rename file; split if it grows over 400 lines.

- [ ] **Step 1: Append the test**

```r
test_that("entity submission with unresolvable PMID returns 400 and writes nothing", {
  skip_if_no_test_db()

  pool <- pool::dbPool(
    drv = RMariaDB::MariaDB(),
    dbname = get_test_config("dbname"),
    host = get_test_config("host"),
    user = get_test_config("user"),
    password = get_test_config("password"),
    port = as.integer(get_test_config("port"))
  )
  withr::defer(pool::poolClose(pool))

  pre_counts <- (function() {
    pc <- pool::poolCheckout(pool); withr::defer(pool::poolReturn(pc))
    list(
      pubs   = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM publication")$n[1],
      ents   = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM ndd_entity")$n[1]
    )
  })()

  # Force info_from_pmid to abort by stubbing fetch_pubmed_data to return empty
  with_mocked_bindings(
    fetch_pubmed_data = function(...) {
      '<?xml version="1.0"?><PubmedArticleSet></PubmedArticleSet>'
    },
    {
      result <- tryCatch(
        new_publication(tibble::tibble(
          publication_id = c("PMID:99999991", "PMID:99999992"),
          publication_type = c("additional_references", "additional_references")
        )),
        publication_fetch_error = function(e) list(status = 400, message = e$message),
        publication_insert_error = function(e) list(status = 500, message = e$message),
        error = function(e) list(status = 500, message = e$message)
      )
      expect_equal(result$status, 400)
      expect_match(result$message, "PMIDs not retrievable")
      # Message must list each unresolvable PMID so the curator knows what to fix
      expect_match(result$message, "PMID:99999991")
      expect_match(result$message, "PMID:99999992")
    }
  )

  post_counts <- (function() {
    pc <- pool::poolCheckout(pool); withr::defer(pool::poolReturn(pc))
    list(
      pubs   = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM publication")$n[1],
      ents   = DBI::dbGetQuery(pc, "SELECT COUNT(*) AS n FROM ndd_entity")$n[1]
    )
  })()
  expect_equal(post_counts$pubs, pre_counts$pubs)
  expect_equal(post_counts$ents, pre_counts$ents)
})
```

- [ ] **Step 2: Run the test**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-entity-rename.R')"
```

Expected: all three integration tests pass or all skip cleanly.

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-entity-rename.R
git commit -m "test(api): integration test rejects unresolvable PMIDs with 400

Stubs fetch_pubmed_data to return empty; asserts new_publication aborts
with publication_fetch_error and the publication / ndd_entity row counts
are unchanged.

Refs #318."
```

---

## Task 12: Integration tests for validation error paths (404 / 409 / 400)

**Files:**
- Modify: `api/tests/testthat/test-integration-entity-rename.R` (extend with validation-path tests)

These tests exercise `svc_entity_rename_full`'s validation phase (no DB writes, just lookups). They guarantee curators get the *exact* messages the frontend will surface in the toast.

- [ ] **Step 1: Append the three validation tests**

```r
test_that("svc_entity_rename_full returns 404 with clear message when source entity missing", {
  skip_if_no_test_db()

  pool <- pool::dbPool(
    drv = RMariaDB::MariaDB(),
    dbname = get_test_config("dbname"),
    host = get_test_config("host"),
    user = get_test_config("user"),
    password = get_test_config("password"),
    port = as.integer(get_test_config("port"))
  )
  withr::defer(pool::poolClose(pool))

  result <- svc_entity_rename_full(
    list(entity = list(
      entity_id = 999999999L,
      hgnc_id = "HGNC:947",
      hpo_mode_of_inheritance_term = "HP:0000006",
      ndd_phenotype = 1L,
      disease_ontology_id_version = "MONDO:0000001"
    )),
    user_id = 1L, pool = pool
  )

  expect_equal(result$status, 404)
  expect_equal(result$message, "Not Found. Source entity does not exist.")
})

test_that("svc_entity_rename_full returns 400 with clear message when ontology unchanged", {
  skip_if_no_test_db()

  pool <- pool::dbPool(
    drv = RMariaDB::MariaDB(),
    dbname = get_test_config("dbname"),
    host = get_test_config("host"),
    user = get_test_config("user"),
    password = get_test_config("password"),
    port = as.integer(get_test_config("port"))
  )
  withr::defer(pool::poolClose(pool))

  pc <- pool::poolCheckout(pool)
  seed <- seed_approved_entity(pc, "HGNC:947", "MONDO:9999985", 1L)
  pool::poolReturn(pc)
  withr::defer({
    pc <- pool::poolCheckout(pool); withr::defer(pool::poolReturn(pc))
    DBI::dbExecute(pc, "DELETE FROM ndd_entity_status WHERE entity_id = ?", list(seed$entity_id))
    DBI::dbExecute(pc, "DELETE FROM ndd_entity_review WHERE entity_id = ?", list(seed$entity_id))
    DBI::dbExecute(pc, "DELETE FROM ndd_entity WHERE entity_id = ?", list(seed$entity_id))
  })

  result <- svc_entity_rename_full(
    list(entity = list(
      entity_id = seed$entity_id,
      hgnc_id = "HGNC:947",
      hpo_mode_of_inheritance_term = "HP:0000006",
      ndd_phenotype = 1L,
      disease_ontology_id_version = "MONDO:9999985"  # same as seeded
    )),
    user_id = 1L, pool = pool
  )

  expect_equal(result$status, 400)
  expect_equal(result$message,
               "Bad Request. New disease_ontology_id_version is identical to the current one.")
})

test_that("svc_entity_rename_full returns 409 with clear message when destination quadruple exists", {
  skip_if_no_test_db()

  pool <- pool::dbPool(
    drv = RMariaDB::MariaDB(),
    dbname = get_test_config("dbname"),
    host = get_test_config("host"),
    user = get_test_config("user"),
    password = get_test_config("password"),
    port = as.integer(get_test_config("port"))
  )
  withr::defer(pool::poolClose(pool))

  pc <- pool::poolCheckout(pool)
  seed_a <- seed_approved_entity(pc, "HGNC:947", "MONDO:9999984", 1L)
  seed_b <- seed_approved_entity(pc, "HGNC:947", "MONDO:9999983", 1L)
  pool::poolReturn(pc)
  withr::defer({
    pc <- pool::poolCheckout(pool); withr::defer(pool::poolReturn(pc))
    for (id in c(seed_a$entity_id, seed_b$entity_id)) {
      DBI::dbExecute(pc, "DELETE FROM ndd_entity_status WHERE entity_id = ?", list(id))
      DBI::dbExecute(pc, "DELETE FROM ndd_entity_review WHERE entity_id = ?", list(id))
      DBI::dbExecute(pc, "DELETE FROM ndd_entity WHERE entity_id = ?", list(id))
    }
  })

  # Try to rename A onto B's quadruple
  result <- svc_entity_rename_full(
    list(entity = list(
      entity_id = seed_a$entity_id,
      hgnc_id = "HGNC:947",
      hpo_mode_of_inheritance_term = "HP:0000006",
      ndd_phenotype = 1L,
      disease_ontology_id_version = "MONDO:9999983"
    )),
    user_id = 1L, pool = pool
  )

  expect_equal(result$status, 409)
  expect_equal(result$message, "Conflict. Destination quadruple already exists.")
  expect_true(!is.null(result$entry))  # surfaces the existing entity for the UI
})
```

- [ ] **Step 2: Run all integration tests**

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-entity-rename.R')"
```

Expected: all six integration tests pass (or skip cleanly if no test DB).

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-entity-rename.R
git commit -m "test(api): integration tests for /rename validation error paths

Asserts exact response.status and response.message for 404 (source missing),
400 (ontology unchanged), and 409 (destination quadruple exists). These are
the strings the frontend surfaces in the curator toast — pinning them here
prevents accidental regressions in user-facing wording.

Refs #318."
```

---

## Task 13: Frontend `extractApiErrorMessage` helper

**Files:**
- Create: `app/src/utils/api-errors.ts`
- Create: `app/src/utils/__tests__/api-errors.spec.ts`

The current `useEntityMutations.ts` calls `onToast?.(e, 'Error', 'danger')` with the raw axios error, which `bootstrap-vue-next`'s toast renders as `[object Object]` or a stack-trace fragment. This task adds a small helper that pulls the API's `message` / `error` field out of the various error shapes and falls back to a sensible string.

- [ ] **Step 1: Write the failing tests**

Create `app/src/utils/__tests__/api-errors.spec.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { extractApiErrorMessage } from '../api-errors';

describe('extractApiErrorMessage', () => {
  it('prefers response.data.message when present (axios shape)', () => {
    const err = {
      isAxiosError: true,
      response: { status: 400, data: { message: 'Bad Request. PMIDs not retrievable from PubMed: PMID:9999.' } },
      message: 'Request failed with status code 400',
    };
    expect(extractApiErrorMessage(err, 'fallback')).toBe(
      'Bad Request. PMIDs not retrievable from PubMed: PMID:9999.',
    );
  });

  it('falls back to response.data.error when message absent', () => {
    const err = {
      isAxiosError: true,
      response: { status: 500, data: { error: 'transaction failed: deadlock' } },
      message: 'Request failed with status code 500',
    };
    expect(extractApiErrorMessage(err, 'fallback')).toBe('transaction failed: deadlock');
  });

  it('uses error.message for plain Error instances (network failures)', () => {
    const err = new Error('Network Error');
    expect(extractApiErrorMessage(err, 'fallback')).toBe('Network Error');
  });

  it('returns the fallback when the input is unrecognised', () => {
    expect(extractApiErrorMessage(undefined, 'Failed to update disease name'))
      .toBe('Failed to update disease name');
    expect(extractApiErrorMessage(null, 'Failed to update disease name'))
      .toBe('Failed to update disease name');
    expect(extractApiErrorMessage({ weird: true }, 'Failed to update disease name'))
      .toBe('Failed to update disease name');
  });

  it('handles non-string message/error values defensively', () => {
    const err = {
      isAxiosError: true,
      response: { status: 400, data: { message: ['array', 'value'] } }, // Plumber sometimes wraps scalars
      message: 'Request failed',
    };
    // Should unwrap the first element when the field is a single-element array
    expect(extractApiErrorMessage(err, 'fallback')).toBe('array');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd app && npx vitest run src/utils/__tests__/api-errors.spec.ts
```

Expected: FAIL — module does not exist.

- [ ] **Step 3: Create the helper**

Create `app/src/utils/api-errors.ts`:

```ts
// app/src/utils/api-errors.ts
//
// Extract a user-facing message from any error thrown by an API call.
//
// Background: Plumber returns structured error bodies of shape
//   { status: number, message: string, error?: string }
// Axios surfaces these via `error.response.data`. The toast (bootstrap-vue-next)
// expects a plain string — feeding it the raw axios error object renders as
// "[object Object]" or a stack-trace fragment, which is what curators see today.
//
// This helper unwraps the API message in priority order:
//   1. err.response.data.message
//   2. err.response.data.error
//   3. err.message (network errors, plain Error)
//   4. fallback
//
// Plumber occasionally wraps scalars as single-element arrays; we unwrap.

type Maybe<T> = T | undefined | null;

function unwrapScalar(value: unknown): string | undefined {
  if (typeof value === 'string') return value;
  if (Array.isArray(value) && value.length === 1 && typeof value[0] === 'string') {
    return value[0];
  }
  return undefined;
}

interface AxiosLikeError {
  response?: { data?: { message?: unknown; error?: unknown } };
  message?: unknown;
}

export function extractApiErrorMessage(err: unknown, fallback: string): string {
  if (err == null) return fallback;

  if (typeof err === 'object') {
    const axiosLike = err as AxiosLikeError;
    const fromMessage = unwrapScalar(axiosLike.response?.data?.message);
    if (fromMessage) return fromMessage;
    const fromError = unwrapScalar(axiosLike.response?.data?.error);
    if (fromError) return fromError;
    const fromTopMessage = unwrapScalar(axiosLike.message);
    if (fromTopMessage) return fromTopMessage;
  }

  if (err instanceof Error && err.message) return err.message;

  return fallback;
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app && npx vitest run src/utils/__tests__/api-errors.spec.ts
```

Expected: all five tests pass.

- [ ] **Step 5: Type-check**

```bash
cd app && npm run type-check
```

Expected: no new errors.

- [ ] **Step 6: Commit**

```bash
git add app/src/utils/api-errors.ts app/src/utils/__tests__/api-errors.spec.ts
git commit -m "feat(app): add extractApiErrorMessage helper for toast error display

Pulls Plumber-shaped { message, error } fields out of axios errors so the
curator toast shows a useful sentence instead of [object Object]. Handles
network errors (Error.message), unknown shapes (fallback), and Plumber's
single-element-array scalar quirk.

Refs #318."
```

---

## Task 14: Wire `useEntityMutations` catch blocks through the helper

**Files:**
- Modify: `app/src/views/curate/composables/useEntityMutations.ts:60-66`, `:95-101`, `:131-137`
- Modify: `app/src/views/curate/composables/__tests__/useEntityMutations.spec.ts` (extend)

- [ ] **Step 1: Write the failing tests**

Append to `app/src/views/curate/composables/__tests__/useEntityMutations.spec.ts` (skim the file first to match its existing setup imports and helpers):

```ts
import { extractApiErrorMessage } from '@/utils/api-errors';

describe('useEntityMutations toast wording on errors', () => {
  it('rename: forwards API message to onToast on 400', async () => {
    // Arrange: mock apiClient.raw.post to throw an axios-shaped 400
    const onToast = vi.fn();
    const post = vi.spyOn(apiClient.raw, 'post').mockRejectedValue({
      isAxiosError: true,
      response: {
        status: 400,
        data: { message: 'Bad Request. New disease_ontology_id_version is identical to the current one.' },
      },
      message: 'Request failed with status code 400',
    });

    const { rename } = useEntityMutations({ onToast });
    await expect(rename({ entity_info: { hgnc_id: 'HGNC:1' }, ontology_input: 'X' }))
      .rejects.toBeDefined();

    expect(onToast).toHaveBeenCalledWith(
      'Bad Request. New disease_ontology_id_version is identical to the current one.',
      'Error',
      'danger',
    );
    post.mockRestore();
  });

  it('rename: falls back to a default message on a bare network error', async () => {
    const onToast = vi.fn();
    const post = vi.spyOn(apiClient.raw, 'post').mockRejectedValue(new Error('Network Error'));

    const { rename } = useEntityMutations({ onToast });
    await expect(rename({ entity_info: { hgnc_id: 'HGNC:1' }, ontology_input: 'X' }))
      .rejects.toBeDefined();

    // The helper returns the Error.message when present, so the toast shows it
    expect(onToast).toHaveBeenCalledWith('Network Error', 'Error', 'danger');
    post.mockRestore();
  });

  it('submitReview: forwards API message on 409', async () => {
    const onToast = vi.fn();
    const post = vi.spyOn(apiClient.raw, 'post').mockRejectedValue({
      isAxiosError: true,
      response: {
        status: 409,
        data: { message: 'Conflict. Destination quadruple already exists.' },
      },
      message: 'Request failed with status code 409',
    });

    const { submitReview } = useEntityMutations({ onToast });
    await expect(submitReview({
      review_info: { entity_id: 1 },
      select_phenotype: [],
      select_variation: [],
      select_additional_references: [],
      select_gene_reviews: [],
    })).rejects.toBeDefined();

    expect(onToast).toHaveBeenCalledWith(
      'Conflict. Destination quadruple already exists.',
      'Error',
      'danger',
    );
    post.mockRestore();
  });
});
```

If the existing spec file uses a different harness for mocking `apiClient.raw.post` (e.g. a top-level `beforeEach` that resets `vi.fn()` on `post`), match that pattern instead — read the first 80 lines of the spec before adding to it.

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd app && npx vitest run src/views/curate/composables/__tests__/useEntityMutations.spec.ts -t "toast wording"
```

Expected: FAIL — current `catch` blocks pass the raw error object.

- [ ] **Step 3: Update `useEntityMutations.ts` catch blocks**

In `app/src/views/curate/composables/useEntityMutations.ts`:

1. Add the import at the top of the file (after the existing imports):

```ts
import { extractApiErrorMessage } from '@/utils/api-errors';
```

2. Replace the `rename` catch block (lines 60-66 in current HEAD):

```ts
    } catch (e) {
      const msg = extractApiErrorMessage(e, 'Failed to update disease name');
      onToast?.(msg, 'Error', 'danger');
      onAnnounce?.('Failed to update disease name', 'assertive');
      throw e;
    } finally {
      submitting.value = null;
    }
```

3. Replace the `deactivate` catch block (lines 95-101) similarly:

```ts
    } catch (e) {
      const msg = extractApiErrorMessage(e, 'Failed to deactivate entity');
      onToast?.(msg, 'Error', 'danger');
      onAnnounce?.('Failed to deactivate entity', 'assertive');
      throw e;
    } finally {
      submitting.value = null;
    }
```

4. Replace the `submitReview` catch block (lines 131-137) similarly:

```ts
    } catch (e) {
      const msg = extractApiErrorMessage(e, 'Failed to submit review');
      onToast?.(msg, 'Error', 'danger');
      onAnnounce?.('Failed to submit review', 'assertive');
      throw e;
    } finally {
      submitting.value = null;
    }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app && npx vitest run src/views/curate/composables/__tests__/useEntityMutations.spec.ts
```

Expected: all tests pass (existing + the three new ones).

- [ ] **Step 5: Type-check and lint**

```bash
cd app && npm run type-check && npm run lint
```

Expected: no new errors or warnings.

- [ ] **Step 6: Commit**

```bash
git add app/src/views/curate/composables/useEntityMutations.ts app/src/views/curate/composables/__tests__/useEntityMutations.spec.ts
git commit -m "fix(app): surface API error messages in curator toast for entity mutations

rename / deactivate / submitReview now route the catch'd error through
extractApiErrorMessage so the toast shows the API's structured message
(e.g. 'Conflict. Destination quadruple already exists.', 'PMIDs not
retrievable from PubMed: PMID:99999991, PMID:99999992') instead of a
stringified axios error.

Refs #318."
```

---

## Task 15: Final verification, push, open PR

**Files:** none (verification + git ops)

- [ ] **Step 1: Run the fast PR gate**

```bash
make pre-commit
```

Expected: green.

- [ ] **Step 2: Frontend unit tests + type-check + lint (explicit pass)**

```bash
cd app && npm run test:unit -- --run && npm run type-check && npm run lint && cd ..
```

Expected: all green. The new `extractApiErrorMessage` and `useEntityMutations` tests run as part of the unit suite.

- [ ] **Step 3: Run the full host-side check**

```bash
make ci-local
```

Expected: green. If a flake-y test fails on first run, retry once before treating it as a regression.

- [ ] **Step 4: Manual smoke against the dev stack**

```bash
make dev
# In another shell, when stack is healthy:
cd api && Rscript -e "
  source('start_sysndd_api.R')  # or curl the running container
  # Hit /api/entity/rename and inspect ndd_entity_status row
"
```

Or simpler: `curl` against the running dev API as a Curator user, perform a rename on a seeded entity, and verify the new status row in the DB:

```bash
docker exec sysndd-mysql-1 mysql -uroot -p$(grep MYSQL_ROOT_PASSWORD api/config.yml | head -1 | awk '{print $NF}') sysndd_db -e "
  SELECT s.status_id, s.is_active, s.status_approved, s.approving_user_id
  FROM ndd_entity_status s
  JOIN ndd_entity e ON e.entity_id = s.entity_id
  WHERE e.entity_id = <new_entity_id>;"
```

Expected: `is_active=1, status_approved=1, approving_user_id=<curator>`.

Also run a deliberately-bogus PMID submission (`PMID:99999999`) through the running curator UI and confirm:
1. The HTTP response is `400` with `message` mentioning the PMID.
2. The toast in the browser shows that message verbatim — not a generic "Failed to submit review".

- [ ] **Step 5: Push the branch**

```bash
git push -u origin fix/rename-atomicity-pubdate-validation
```

- [ ] **Step 6: Open the PR**

```bash
gh pr create --repo berntpopp/sysndd \
  --base master \
  --head fix/rename-atomicity-pubdate-validation \
  --title "fix(api): atomic /rename with approval carry-over + reject unresolvable PMIDs (closes #318)" \
  --body-file - <<'EOF'
## Summary

Fixes #318 — two bugs surfaced by the MySQL 8.0.29 → 8.4.8 migration in January.

- **Bug 1**: `POST /api/entity/rename` was non-transactional and silently dropped approval state on the new status row, leaving renamed entities invisible to curators while still occupying their unique-quadruple slot. Now wrapped in `db_with_transaction` via a new `svc_entity_rename_full` service; `review_create` and `status_create` propagate `is_active` / `status_approved` / `approving_user_id` / etc. when present in their input.
- **Bug 2**: `info_from_pmid` silently coerced unresolvable PMIDs into stub publication rows with empty strings, which MySQL 8.4 strict mode rejects, half-committing the publication batch. Now `info_from_pmid` aborts with `publication_fetch_error`; the endpoint layer maps that to HTTP 400 with the offending PMIDs in the message; `new_publication`'s INSERT loop is also wrapped in a transaction (belt-and-braces).
- **UX**: the curator UI's `useEntityMutations` composable now routes errors through a new `extractApiErrorMessage` helper, so the existing `bootstrap-vue-next` toast shows the API's structured message (e.g. *"Conflict. Destination quadruple already exists."*, *"PMIDs not retrievable from PubMed: PMID:99999991, PMID:99999992"*) instead of `[object Object]` or a stack-trace fragment.

Behaviour for curators is unchanged: renames still bypass approval (full BUG-07 follow-up tracked separately). The only user-visible difference is that bogus-PMID submissions now 400 cleanly instead of 500-ing, and the toast on every entity mutation actually tells the curator what went wrong.

## Tests

**Backend (R / testthat):**
- Unit tests for `review_create` / `status_create` propagation and back-compat omission (`test-unit-review-repository.R`, new `test-unit-status-repository.R`).
- Unit tests for `info_from_pmid` fail-fast and `Publication_date` NA preservation (`test-unit-publication-functions.R`).
- Unit/signature/no-shadow test for `svc_entity_rename_full` (`test-unit-entity-service.R`).
- DB-backed integration tests in `test-integration-entity-rename.R`:
  - happy path with approval-state carry-over,
  - rollback on inner failure (row counts unchanged, source untouched),
  - bogus PMID rejection (400 with each PMID listed in the message),
  - validation error paths: 404 (source missing), 400 (ontology unchanged), 409 (destination exists) — each pinned to its exact response message string.

**Frontend (TypeScript / vitest):**
- Unit tests for `extractApiErrorMessage` covering axios shape, fallback to `error`, plain `Error`, unknown shapes, and Plumber's single-element-array scalar quirk (`api-errors.spec.ts`).
- `useEntityMutations` spec extended to assert the toast receives the API's `message` for 400/409 and falls back to a sensible default on bare network errors.

`make ci-local` and `cd app && npm run test:unit && npm run type-check` green.

## Out of scope (follow-ups)

- Full BUG-07 redesign (renames go through approval workflow; needs UI). Separate PR.
- The `table_articles_from_xml` "fallback to today's date when PubMed has incomplete `<PubDate>`" hack at `publication-functions.R:247-253`. Wrong but doesn't crash; deserves its own issue.
- Production data cleanup for `status_id=5562` (BAIAP2 4641 orphan from 2026-05-08) and the 2 legacy 2013/2014 orphans. Operator-driven SQL after merge + deploy:
  ```sql
  UPDATE ndd_entity_status SET is_active=1, status_approved=1, approving_user_id=3
  WHERE status_id=5562;
  ```

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
```

Expected: PR URL printed; CI starts.

- [ ] **Step 7: Confirm CI is green**

Watch `gh pr checks <PR-number> --watch` or the GitHub Actions UI. If a check fails, fix and push amend before requesting review.

---

## Self-review checklist

- [x] Every task has the actual code, not "implement appropriate logic".
- [x] Each task ends in a single commit.
- [x] Repository function signatures (`review_create`, `status_create`, `entity_create`, `db_with_transaction`) match the actual code at HEAD `cc5f7c6c` — verified by reading the files during plan-writing.
- [x] Integration test seed/cleanup is honest about the awkwardness: pool seeds commit because the service uses the pool, so we use explicit DELETE on cleanup rather than relying on rollback.
- [x] Validation error paths (404 / 409 / 400 ontology-unchanged) have their exact response-message string pinned in tests — these strings are what curators will see in the toast, so a wording change must be intentional.
- [x] Toast helper handles axios shape, plain Error, network failures, and Plumber's single-element-array scalar quirk.
- [x] All three `useEntityMutations` mutations (`rename`, `deactivate`, `submitReview`) are routed through the helper and their fallback strings (`"Failed to update disease name"`, `"Failed to deactivate entity"`, `"Failed to submit review"`) preserve the existing user-facing wording.
- [x] Final verification runs both `make ci-local` and the frontend unit/type-check/lint suite.
- [x] Out-of-scope items match the spec (BUG-07, today's-date hack, prod data cleanup).
- [x] PR title and branch name match the spec.

## Execution handoff

Plan complete and saved to `.planning/superpowers/plans/2026-05-08-rename-atomicity-pubdate-validation-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
