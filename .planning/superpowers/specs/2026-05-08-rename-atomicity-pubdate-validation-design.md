# /rename atomicity + Publication_date / PubMed-miss handling (design)

Date: 2026-05-08
Status: Approved
Related: issue [#318](https://github.com/berntpopp/sysndd/issues/318); follow-ups noted as out-of-scope below.

## 1. Problem

Two bugs surfaced in production on 2026-05-08 when curator C. tried to upgrade BAIAP2 from *Limited* → *Definitive* (which involved a disease-ontology change) and submit FRMD3. Both block entity submissions, both leave inconsistent records that hold unique-constraint slots while being invisible to curators, and both have been verified present on `master` (`cc5f7c6c`).

### Bug 1 — `/rename` is non-transactional and drops approval state

`POST /api/entity/rename` (`api/endpoints/entity_endpoints.R`, the rename branch in the `@post /rename` handler) performs six sequential writes — `post_db_entity` → `put_db_entity_deactivation` → `put_post_db_review` → publication-join → phenotype-connect → `put_post_db_status` — without a wrapping transaction. The endpoint already carries an explicit `TODO BUG-07` admitting the design gap, but the user-visible failure today is sharper than the documented TODO suggests:

The status step at `put_post_db_status("POST", ndd_entity_status_replaced)` does not preserve `is_active`, `status_approved`, or `approving_user_id` from the source row — those fall back to column defaults (`is_active DEFAULT 0`, `status_approved DEFAULT 0`). The new review row, however, *does* end up `review_approved=1`. Result: the rows are mutually inconsistent. For BAIAP2, the rename produced entity 4641 (active) with review 6322 (approved) but status 5562 (`is_active=0, status_approved=0`). Most curator views filter on `status.is_active=1 AND status_approved=1`, so the entity disappeared while still occupying the unique-quadruple slot — re-submission is blocked by `entity_quadruple` and the curator has no clear error.

### Bug 2 — Empty `Publication_date` rejected by MySQL 8.4 strict mode

After the MySQL 8.0.29 → 8.4.8 migration in January 2026, the default `sql_mode` includes `STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE`. Empty strings are no longer accepted for `TIMESTAMP`/`DATETIME` columns.

In `api/functions/publication-functions.R`, `info_from_pmid` builds the publication tibble with:
1. `mutate(Publication_date = paste0(year, "-", month, "-", day))` (line 322)
2. `left_join(input_tibble_request, by = "publication_id")` to align with the requested PMID list (line 338)
3. `mutate(across(everything(), ~ replace_na(.x, "")))` (line 340)

When PubMed returns no article for a requested PMID, the left-join produces all-NA rows, and the blanket `replace_na` then writes `Publication_date = ""`. The downstream loop in `new_publication` (`publication-functions.R:134-137`) executes one `db_execute_statement` per row without a transaction or `tryCatch`, so the failing INSERT crashes the call after partial inserts may have committed. In `entity_endpoints.R` (`POST /api/entity` and `POST /api/entity/rename`) the publication step runs before the entity transaction, so on failure the user sees a 500 and no entity is created at all — matching the FRMD3 symptom of "can't be submitted, old one not visible" (it was never created).

## 2. Goal

A single PR fixes both bugs with the smallest behavior-preserving change, and adds tests that would have caught each bug in isolation.

Success criteria:
- A disease rename with a curator user produces an `ndd_entity_status` row with `is_active=1, status_approved=1, approving_user_id` matching the source — verified by integration test against a real DB.
- A forced mid-rename failure (e.g. a malformed phenotype id) leaves the database byte-identical to its pre-call state — no orphaned entity, review, or status — verified by integration test that snapshots row counts before and after.
- Submitting an entity with a PMID PubMed cannot resolve produces HTTP 400 with a message naming the offending PMID, and no rows are written to `publication`, `ndd_entity`, `ndd_entity_review`, `ndd_entity_status`, or any join table — verified by integration test using a stubbed PubMed response.
- A PubMed lookup that succeeds but yields no `<PubMedPubDate>` components for a PMID continues to populate `Publication_date` from the existing fallback (today's date) — behavior unchanged for the non-bug path.
- `make ci-local` passes; manual smoke against the dev stack confirms a successful rename and a rejected bogus-PMID submission.

Non-goals (out of scope, captured for follow-up):
- Full BUG-07 redesign (renames go through approval workflow with curator UI for pending renames). Separate PR with UI consideration.
- Replacing the `table_articles_from_xml` "fallback to today's date when PubMed has incomplete `<PubDate>`" hack at `publication-functions.R:247-253`. Wrong but not crashing; deserves its own issue.
- Production data cleanup for `status_id=5562` (BAIAP2) and the two legacy 2013/2014 orphans (TBC1D23, COG6). Manual ad-hoc SQL after deploy, already documented in #318.
- Schema changes — `publication.Publication_date` is already `TIMESTAMP NULL DEFAULT NULL`; no migration needed.

## 3. Approach

Refactor the rename branch behind a new service function and tighten `info_from_pmid` to fail fast on unresolvable PMIDs.

### 3.1 New service function `svc_entity_rename_full`

File: `api/services/entity-service.R`. Mirror the existing `svc_entity_create_full` pattern (validation outside transaction, all writes inside `db_with_transaction`, structured error classes, RFC 9457 problem details on failure). The signature:

```r
svc_entity_rename_full <- function(rename_data, user_id, pool) -> list(status, message, entry)
```

- `rename_data`: parsed body, identical to today's `req$argsBody$rename_json`.
- `user_id`: integer, the new entry user.
- `pool`: DB connection pool (DI for testability).
- Returns the same shape as `svc_entity_create_full`: `list(status = 200|400|409|500, message = ..., entry = tibble(entity_id = ..., review_id = ..., status_id = ...))`.

Pre-transaction (uses `pool` directly, fast-fail before any write):
- Confirm the source entity exists and is active.
- Confirm the new disease ontology id differs from the old (matches today's guard at `entity_endpoints.R` rename branch).
- Confirm hgnc / MOI / ndd_phenotype are unchanged (today's guard).
- Confirm the destination quadruple is not already taken (avoid mid-transaction `Duplicate entry` on `entity_quadruple`).
- Load the original review, status, and join-table rows that will be carried forward.

Inside `db_with_transaction(function(txn_conn) { ... }, pool_obj = pool)`:
1. `entity_create(replaced_entity_data, conn = txn_conn)` → returns `new_entity_id`.
2. `db_execute_statement("UPDATE ndd_entity SET is_active=0, replaced_by=? WHERE entity_id=?", list(new_entity_id, old_entity_id), conn = txn_conn)`.
3. `review_create(review_replaced, conn = txn_conn)` — must propagate `is_primary`, `review_approved`, `approving_user_id`, `comment` from the source row. See §3.3.
4. `publication_connect_to_review(new_review_id, new_entity_id, pubs, conn = txn_conn)` — same helper used by `svc_entity_create_full`.
5. `phenotype_connect_to_review(new_review_id, new_entity_id, phens, conn = txn_conn)`.
6. `variation_ontology_connect_to_review(new_review_id, new_entity_id, vario, conn = txn_conn)`.
7. `status_create(status_replaced, conn = txn_conn)` — must propagate `is_active`, `status_approved`, `approving_user_id`, `category_id`, `problematic`, `comment` from the source row. See §3.3.

All writes use `txn_conn`. On any inner exception, `db_with_transaction` issues `ROLLBACK` and re-throws as `db_transaction_error`; the outer `tryCatch` in the service maps it to `list(status = 500, ...)`.

`logger::log_warn` keeps emitting "Disease rename for entity {id} bypassing approval workflow" — behavior is unchanged for curators, the warning is still factually correct, and the BUG-07 follow-up will replace it.

### 3.2 Endpoint shim `POST /api/entity/rename`

File: `api/endpoints/entity_endpoints.R`. The rename handler shrinks to a thin wrapper matching the create-entity pattern:

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

The ~190-line non-atomic body is removed entirely. The service is the single source of truth.

### 3.3 Repository functions: explicit approval-state propagation

`review_create` (likely in `api/functions/review-repository.R`) and `status_create` (likely `api/functions/status-repository.R`) — exact files confirmed during implementation — must accept and INSERT the approval-state columns explicitly. Today they may rely on database defaults for these. The contract change:

- `review_create(review_data, conn)`: INSERT now includes `is_primary`, `review_approved`, `approving_user_id`, `comment` whenever those keys are present in `review_data`. When absent (the create-entity path that doesn't pre-approve), behavior is unchanged — the columns fall back to defaults.
- `status_create(status_data, conn)`: same shape — INSERT includes `is_active`, `status_approved`, `approving_user_id`, `category_id`, `problematic`, `comment` when present.

This is a *purely additive* repository change. The create-entity path keeps working unmodified because `svc_entity_create_full` already passes a status_data list that doesn't include those keys (status is approved by a separate UPDATE in step 7 of the existing function). Verified by reading `entity-service.R` lines 629-657.

### 3.4 `info_from_pmid` fail-fast on unresolvable PMIDs

File: `api/functions/publication-functions.R`. Two changes inside `info_from_pmid` (starting at the existing line 289):

1. After the `left_join` at line 338 — but before the `replace_na` — detect rows where the PubMed fetch returned nothing. The detection rule: a row whose `pmid` (or `Title`, equivalently — both come from the fetched data) is NA after the join means the requested PMID was not retrievable. Collect the offending PMIDs and, if non-empty, abort:
   ```r
   if (length(unresolvable) > 0) {
     rlang::abort(
       message = paste0("PMIDs not retrievable from PubMed: ",
                        paste(unresolvable, collapse = ", ")),
       class = "publication_fetch_error",
       pmids = unresolvable
     )
   }
   ```
2. Replace the blanket `mutate(across(everything(), ~ replace_na(.x, "")))` with one that excludes timestamp columns:
   ```r
   mutate(across(-any_of("Publication_date"), ~ replace_na(.x, "")))
   ```
   The `any_of` keeps the call safe if the column is renamed or absent. NAs in `Publication_date` survive into the INSERT and DBI passes NULL — the column is already `TIMESTAMP NULL DEFAULT NULL`. With change #1 in place this branch is technically unreachable (every row has resolved data or we abort), but it's a cheap guard against future edits and any partial-fetch code path we may not have walked.

### 3.5 `new_publication` transactional INSERT loop

File: `api/functions/publication-functions.R` lines 127-138. Wrap the per-row INSERT loop in `db_with_transaction` and a `tryCatch` that re-throws as a structured error. Belt-and-braces: today's primary failure mode is gone after §3.4, but a future bug should never half-commit a publication batch.

### 3.6 Endpoint-level error mapping

In `entity_endpoints.R` (the `POST /api/entity` and `POST /api/entity/rename` handlers) and `review_endpoints.R` (the two existing `new_publication` call sites at lines ~282 and ~338), extend the surrounding `tryCatch` (or wrap if absent) to catch `publication_fetch_error` and return:

```r
list(status = 400,
     message = paste("Bad Request.", e$message),
     error = e$message)
```

The existing 500-response path stays for genuinely unexpected errors.

## 4. Tests

`api/tests/` is not bind-mounted in dev/prod containers; tests run on the host (`make test-api-fast` for the PR gate, `make test-api` full) or are copied into the container. New and extended files:

### 4.1 New unit file `test-unit-entity-rename.R`

- Mock `db_with_transaction` to capture the inner function's write count; assert that on inner exception the captured commit count is zero (transaction-level rollback semantics — the helper itself is already tested elsewhere, this asserts the service uses it).
- Service-level validation: rename to an unchanged ontology returns 400 without touching the DB pool.
- Service-level conflict detection: when destination quadruple already exists, returns 409.

### 4.2 Extend `test-unit-publication-functions.R` (or create if absent)

- `info_from_pmid` with a stubbed `fetch_pubmed_data` that omits one PMID → expect `publication_fetch_error` with the omitted PMID listed.
- `info_from_pmid` with all PMIDs resolved → expect a tibble with no `""` in `Publication_date` (assertion targets the post-replace shape, regression guard for §3.4 #2).

### 4.3 Extend `test-integration-entity.R`

Three new tests, each using the existing helper-db harness against a real MySQL:

- **Rename happy path**: seed an active+approved entity with one publication, one phenotype; call `svc_entity_rename_full` with a new `disease_ontology_id_version`; assert (a) old entity has `is_active=0, replaced_by=new_id`, (b) new entity has `is_active=1, replaced_by=NULL`, (c) new review has `review_approved=1, approving_user_id=<curator>`, (d) new status has `is_active=1, status_approved=1, approving_user_id=<curator>`, (e) join tables for the new review are populated.
- **Rename rollback**: seed the same entity; call `svc_entity_rename_full` with a phenotype payload containing an invalid `phenotype_id` (FK violation). Snapshot row counts in `ndd_entity`, `ndd_entity_review`, `ndd_entity_status`, `ndd_review_phenotype_connect`, `ndd_review_publication_join` before and after; assert all five counts are unchanged. Assert the original entity is still `is_active=1, replaced_by=NULL`.
- **Bogus PMID rejection**: seed nothing; stub `fetch_pubmed_data` (or its caller) to return an empty XML for the PMID; POST to `/api/entity` with that PMID; assert HTTP 400 with the PMID in the response body and zero new rows across all relevant tables.

### 4.4 Quality gates

- `make pre-commit` (fast PR gate) green.
- `make ci-local` green before push.
- `make lint-api` clean (no new lintr warnings introduced).
- Manual smoke on dev stack: rename a seeded entity via the running API, verify status row in DB; submit a known-bogus PMID, verify the 400 response.

## 5. Risk and mitigation

| Risk | Likelihood | Mitigation |
|---|---|---|
| `review_create` / `status_create` are also called from non-rename paths and our additive INSERT changes break those callers | medium | Only insert new columns when the corresponding key is present in the input list. All existing callers keep working unchanged because they don't pass the keys. Verified by reading every call site during implementation; also covered by the existing `test-integration-entity.R` happy paths. |
| `db_with_transaction`'s rollback semantics differ from what we assume | low | The helper is already used in production by `svc_entity_create_full`. Integration test 4.3 (rename rollback) asserts byte-equivalence of row counts, which is the contract we depend on. |
| `publication_fetch_error` propagates up before pre-existing `tryCatch` handlers and 500s instead of 400-ing | medium | Test 4.3 (bogus PMID rejection) asserts HTTP 400 specifically. If it fails we know exactly where to wrap. |
| The blanket `replace_na("")` exclusion of `Publication_date` breaks downstream assumptions about the column type | low | Downstream code reads `Publication_date` from the DB, not from the in-memory tibble. The DB stores `NULL` either way (today, after MySQL 8.4 strict mode rejects `""`, the row never gets written). No regression possible. |
| New status row carries `approving_user_id` of the original approver — that user may no longer have curator privileges | low | Matches the existing rename behavior (today the rename also bypasses approval). BUG-07 follow-up addresses the bigger question of whether disease renames should re-approve. |

## 6. Branch and PR

- Branch: `fix/rename-atomicity-pubdate-validation` off `master`.
- PR title: `fix(api): atomic /rename with approval carry-over + reject unresolvable PMIDs (closes #318)`.
- PR description: links #318, summarises the two fixes, lists the §2 non-goals as follow-ups, includes the post-deploy DB cleanup SQL for `status_id=5562` from #318 with a note that production cleanup is operator-driven (not in this PR).
- CI: standard official lane (lint, type-check, vitest, R API, smoke).
