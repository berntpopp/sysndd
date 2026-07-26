# Review Write Atomicity and CURIE Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each review save all-or-nothing without holding a MySQL transaction over upstream I/O, and independently prevent ontology CURIE coercion from returning to either curation submit path.

**Architecture:** PR 1 adds a focused review-write coordinator that prepares external publication metadata and validates the full request before beginning one connection-owned DB write phase. Connection-aware repositories participate in that phase rather than nesting transactions, including the re-review marker and direct approval. PR 2 documents the tag invariant and adds frontend runtime tests proving both submission paths preserve CURIE strings through JSON serialization.

**Tech Stack:** R, Plumber, DBI/RMariaDB, `pool`, testthat, Vue 3, TypeScript, Vitest/MSW.

**Spec:** `.planning/superpowers/specs/2026-07-26-review-write-atomicity-and-curie-guard.md`.

---

## Global constraints

- Deliver **two separate PRs**. PR 2 is independent and may merge first.
- Do not hold a DB transaction while calling PubMed, GeneReviews, or any other upstream service.
- Preserve the transaction-owner rule: a pool API request owns one checked-out transaction; a passed DBI connection is already owned by its caller and must never receive nested `dbBegin()` / `dbWithTransaction()`.
- Use `with_test_db_transaction()` for every DB-writing test. Run any DDL fixture setup beforehand on a separate direct connection because DDL auto-commits.
- Keep handwritten source files below the 600-line soft ceiling. `api/endpoints/review_endpoints.R` is 586 lines and `api/services/review-service.R` is 500; extract rather than append.
- Use `dplyr::select()` and other masked verbs explicitly. Use `base::get()` if a lookup is needed.
- Preserve `mount_endpoint()` error handling. New request-validation failures must throw existing `error_400` via `stop_for_bad_request()` so mounted routes produce RFC 9457 `application/problem+json`; unexpected persistence failures remain the existing redacted 500 path.
- No historical data migration or automatic repair job. See the spec’s operational repair decision.

## File structure

### PR 1 — atomic review save

- **Create:** `api/services/review-write-service.R` — the only request-wide coordinator: normalization, preflight, external preparation, transaction ownership, mutation order, scalar response.
- **Create:** `api/functions/publication-write-preparation.R` — extract publication metadata resolution from persistence; no DB writes and no transaction ownership.
- **Create:** `api/tests/testthat/test-integration-review-write-atomicity.R` — real-RMariaDB transaction/rollback regressions.
- **Create:** `api/tests/testthat/test-unit-review-write-service.R` — pure/preflight, direct-connection, scalar-response and error-class tests.
- **Modify:** `api/bootstrap/load_modules.R` — source the new helper before `publication-functions.R` and the new coordinator before endpoint mounting.
- **Modify:** `api/endpoints/review_endpoints.R` — retain role/method gates and delegate write handling; remove sequential writes and vector aggregation.
- **Modify:** `api/functions/publication-functions.R` — retain `new_publication()`’s standalone contract by composing extracted preparation plus standalone persistence.
- **Modify:** `api/functions/review-repository.R` — add shared-connection participation for update, re-review saved status, and review approval.
- **Modify:** `api/functions/publication-repository.R`, `api/functions/phenotype-repository.R`, `api/functions/ontology-repository.R` — add `conn = NULL` to replace paths and execute directly on supplied connections.
- **Modify:** `api/tests/testthat/test-endpoint-review.R` and narrow repository tests — assert delegation/scalar status and connection-participation contracts.

### PR 2 — CURIE docs and guard

- **Create:** `app/src/utils/ontologyTags.spec.ts` — first-separator and CURIE-string unit coverage.
- **Modify:** `app/src/composables/review/useReviewApprovalActions.spec.ts` — exercise `submitReviewUpdate()` with CURIE tags and inspect the serialized outbound body.
- **Modify:** `app/src/composables/review/useReviewApprovalActions.ts` — correct local loaded-row ontology ID annotations to string.
- **Modify:** `app/src/views/curate/composables/__tests__/useReviewForm.spec.ts` only if needed to make the existing #600 regression test cover a hyphen-bearing suffix; do not duplicate its existing coverage needlessly.
- **Modify:** `AGENTS.md` — add the concise Stack-Specific Gotchas invariant.

## PR 1 tasks — atomic review write

### Task 1: Write the failing real-database rollback regression first

**Files:**

- Create: `api/tests/testthat/test-integration-review-write-atomicity.R`
- Read: `api/tests/testthat/helper-db.R`, `api/tests/testthat/test-integration-rereview-sync.R`

- [ ] **Step 1: Build the fixture outside the test transaction.**

  Add an idempotent `ensure_review_write_atomicity_schema()` fixture helper that opens its own `get_test_db_connection()`, ensures the minimal parent/reference tables and the review/publication/phenotype/variation/re-review tables required by the test, then disconnects. Do not put `CREATE TABLE`, `TRUNCATE`, or `DROP` inside `with_test_db_transaction()`.

- [ ] **Step 2: Add the POST failure test (expected to fail on current code).**

  Name it exactly: `POST review write rolls back review, publication join, ontology joins, and re-review marker when phenotype insert fails`.

  Inside `with_test_db_transaction()`:

  - use `conn <- getOption(".test_db_con")` and insert a marker entity/user, one existing publication, one valid HPO term, one valid VariO term, and an unmarked `re_review_entity_connect` row;
  - pass `conn` to the review-write entry point (the initial test may target the proposed service name and therefore fail before implementation);
  - provide one valid existing publication association and the same valid phenotype twice. The first insert succeeds and the second hits the real unique `phenotype_quintuple` constraint, making this a deterministic failure *after* the review and publication association writes;
  - assert the call errors; query the same connection and assert zero marker review rows, zero marker review-publication joins, zero phenotype joins, zero variation joins, and `re_review_review_saved`/`review_id` unchanged.

  Expected current result: FAIL because no coordinator exists; after a naïve wiring to the current path it would expose the documented partial persistence.

- [ ] **Step 3: Add the PUT preservation regression (also failing initially).**

  Name it exactly: `PUT review write preserves existing review and joins when phenotype replacement fails`.

  Seed an existing review with distinguishable synopsis/comment plus one publication, phenotype, variation, and re-review marker values. Submit a changed synopsis and duplicate valid phenotype rows to trigger the same late unique constraint. Assert that all pre-existing review fields and every original association remain exactly unchanged, and the marker still references its original review. This guards the DELETE-then-INSERT replace paths as well as POST creation.

- [ ] **Step 4: Add a successful control test.**

  Use non-duplicated valid CURIE inputs and a pre-existing publication. Assert all expected rows and the re-review marker commit together, and assert the returned `status` is an integer scalar `200L`, not a vector.

- [ ] **Step 5: Run the single file and record the actual result.**

  Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-review-write-atomicity.R')"`

  Expected initially: the two regression tests fail because `svc_review_write()` is not defined. After implementation, require a real `PASS` count and `SKIP 0`; do not treat a skipped database test as green.

### Task 2: Specify and test preflight validation and direct-connection ownership

**Files:**

- Create: `api/tests/testthat/test-unit-review-write-service.R`
- Test target: planned `api/services/review-write-service.R`

- [ ] **Step 1: Write failing unit tests for invalid ontology data.**

  Add table-driven cases for `phenotype_id` and `vario_id` as `NULL`, `NA`, `""`, and whitespace. For both tag-value and explicit-object inputs, expect the preparation function to throw class `error_400` with a field-specific message. Instrument the external preparation and transaction callback dependencies; assert neither is called.

- [ ] **Step 2: Write the nested-transaction regression test.**

  Inside `with_test_db_transaction()`, pass `getOption(".test_db_con")` to the coordinator and stub/spy only the transaction starter. Assert no transaction starter is called, the SQL callback receives that exact connection, and no RMariaDB “Nested transactions not supported” error is raised. This is the executable contract for `with_test_db_transaction()` participation.

- [ ] **Step 3: Write failing tests for the production pool path and response shape.**

  Inject a fake checkout/transaction boundary and a successful mutation result. Assert exactly one transaction begins for a pool-owned request, every operation receives the same connection object, and the assembled success response contains exactly one `status = 200L` and one scalar message.

- [ ] **Step 4: Run the new unit file.**

  Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-review-write-service.R')"`

  Expected initially: FAIL because the coordinator and preflight functions do not exist.

### Task 3: Extract publication resolution from publication persistence

**Files:**

- Create: `api/functions/publication-write-preparation.R`
- Modify: `api/functions/publication-functions.R`
- Test: `api/tests/testthat/test-unit-review-write-service.R` (add focused cases)

- [ ] **Step 1: Add failing preparation tests.**

  Test that the new helper returns publication rows to insert but does not execute an INSERT or start a transaction; mock PubMed/GeneReviews functions and assert they run before any supplied persistence callback. Test that an unresolved PMID is converted to an `error_400` before the review-write callback is entered.

- [ ] **Step 2: Implement the extraction.**

  Move the existing missing-publication detection and metadata fetching from `new_publication()` into the new helper. Preserve the existing PMID normalization and GeneReviews classification. Add a small connection-aware persistence function that inserts prepared rows using the caller’s connection; make duplicate publication primary-key races benign while allowing other database errors to escape.

- [ ] **Step 3: Preserve legacy standalone behaviour.**

  Rewrite `new_publication()` as the compatibility composition: prepare outside its own transaction, then persist its prepared rows in its existing standalone atomic boundary. Do not change entity creation or GeneReviews callers in this PR.

- [ ] **Step 4: Run focused tests.**

  Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-review-write-service.R')"`

  Expected: PASS, with no real network calls.

### Task 4: Make review-related repositories participate in a caller-owned transaction

**Files:**

- Modify: `api/functions/review-repository.R`
- Modify: `api/functions/publication-repository.R`
- Modify: `api/functions/phenotype-repository.R`
- Modify: `api/functions/ontology-repository.R`
- Test: `api/tests/testthat/test-unit-review-repository.R` and focused new/nearby repository tests

- [ ] **Step 1: Write failing repository participation tests.**

  For each update/replace operation used by the coordinator, call it with a sentinel direct `conn` and assert it sends every statement to that connection without invoking `db_with_transaction()`. Separately retain a standalone-call test for one replace path proving it still owns a transaction when `conn` is absent.

- [ ] **Step 2: Refactor review repository methods.**

  Give `review_update()`, `review_update_re_review_status()`, and `review_approve()` an optional `conn = NULL`. Separate each method’s SQL body from transaction ownership: supplied connection runs the body directly; absent connection retains its current all-or-nothing standalone transaction. Keep approval’s sibling reset and `sync_rereview_approval(..., conn = ...)` semantics unchanged.

- [ ] **Step 3: Refactor publication/phenotype/variation replace methods.**

  Give all replace methods an optional `conn = NULL`; run their DELETE plus INSERT statements on the supplied connection without opening another transaction. Keep the no-connection behaviour atomic for legacy callers. Make the coordinator perform validation/ownership checks before it enters its transaction and use the transaction connection for its final review/entity relationship check.

- [ ] **Step 4: Run repository tests.**

  Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-review-repository.R')"`

  Run any new repository-specific test files added in this task.

  Expected: PASS. If an existing test exposes an unintended standalone behaviour change, stop and resolve it before proceeding; do not make `db_with_transaction()` silently accept nested ownership.

### Task 5: Implement the focused coordinator and connect it to the endpoint

**Files:**

- Create: `api/services/review-write-service.R`
- Modify: `api/bootstrap/load_modules.R`
- Modify: `api/endpoints/review_endpoints.R`
- Modify: `api/tests/testthat/test-endpoint-review.R`

- [ ] **Step 1: Implement the coordinator’s two explicit phases.**

  Phase A normalizes the two accepted ontology payload shapes without numeric CURIE coercion; validates synopsis/method/review/entity/ontology ids and modifiers; classifies GeneReviews and resolves publication rows with no write transaction. Convert client-visible validation and fetch failures to `stop_for_bad_request()`.

  Phase B receives the prepared immutable data and owns one short connection-scoped mutation: persist newly prepared publications, create or update the review, connect/replace publications, phenotypes, variations, then update the re-review marker. If `direct_approval=TRUE`, perform connection-participating review approval last. Any error must escape the transaction callback.

- [ ] **Step 2: Implement explicit transaction ownership.**

  For a pool, check out/return exactly one connection and start exactly one transaction through the existing helper. For a direct DBI connection, run the Phase B callback directly. Do not use a global pool inside Phase B and do not add generic active-transaction probing.

- [ ] **Step 3: Simplify the endpoint.**

  Keep authorization, `POST`/`PUT` validation, and Curator escalation for direct approval in `review_endpoints.R`. Replace the sequential `put_post_db_*` calls, returned-error lists, and tibble `unique()/max(status)` aggregate with one coordinator call. Return its scalar response; do not manually turn errors into opaque 500 lists. Ensure the file no longer grows beyond its present size.

- [ ] **Step 4: Update endpoint tests.**

  Update the sandbox to inject the coordinator rather than each sequential writer. Assert direct approval reaches the coordinator, a success status is scalar, and an `error_400` propagates for `mount_endpoint()` to serialize. Keep role-gate tests unchanged.

- [ ] **Step 5: Run targeted API tests.**

  Run:

  `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-review-write-atomicity.R')"`

  `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-review-write-service.R')"`

  `cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-review.R')"`

  Expected: all PASS with no skips for the integration test.

- [ ] **Step 6: Commit PR 1’s implementation slice.**

  Stage only the API coordinator, repository, endpoint, and API test files listed above. Use a focused commit message such as `fix(review): make review save atomic across dependent writes`.

### Task 6: Run PR 1 verification gates and perform a code-quality pass

**Files:** all PR 1 changes

- [ ] **Step 1: Run fast iteration gate.**

  Run: `make test-api-fast`

  Expected: PASS. Inspect the summary; database skips do not satisfy the integration-test acceptance criterion.

- [ ] **Step 2: Run deterministic quality checks.**

  Run: `git diff --check && make code-quality-audit`

  Expected: no whitespace errors and no 600-line ratchet failure. Specifically inspect `review_endpoints.R`, `review-service.R`, and the new coordinator for one-responsibility boundaries.

- [ ] **Step 3: Run full local CI before handoff.**

  Run: `make ci-local`

  Expected: PASS. Report the actual summary and any legitimately environment-gated checks.

## PR 2 tasks — CURIE docs and executable guard

### Task 7: Add the first-separator helper regression test

**Files:**

- Create: `app/src/utils/ontologyTags.spec.ts`
- Test target: `app/src/utils/ontologyTags.ts`

- [ ] **Step 1: Write failing expectations.**

  Assert `splitOntologyTag('1-HP:0001249')` returns numeric modifier `1` and string ontology id `HP:0001249`; assert `splitOntologyTag('5-VariO:0015')` returns `5` and `VariO:0015`; assert `splitOntologyTag('1-CURIE:part-with-hyphen')` preserves the entire suffix after the first separator. Assert the ontology result is a string, not a number.

- [ ] **Step 2: Run the test.**

  Run: `cd app && npx vitest run src/utils/ontologyTags.spec.ts`

  Expected initially: FAIL because the spec file does not exist; after adding it, PASS against the already-correct helper.

### Task 8: Guard the curator approval submit path at the wire boundary

**Files:**

- Modify: `app/src/composables/review/useReviewApprovalActions.spec.ts`
- Modify: `app/src/composables/review/useReviewApprovalActions.ts`

- [ ] **Step 1: Write the failing MSW test for `submitReviewUpdate()`.**

  Mock `PUT /api/review/update`, call `submitReviewUpdate()` with `selectPhenotype` and `selectVariation` tags using real CURIEs, parse the request JSON in the MSW resolver, and assert `phenotype_id` / `vario_id` are exactly the input CURIE strings. Serialize the submitted body and assert neither identifier is `null`. Include a hyphen-bearing ontology suffix to enforce first-separator behaviour through the consumer.

- [ ] **Step 2: Correct the stale local response annotations.**

  Change only the local loaded-row type annotations in `useReviewApprovalActions.ts` from numeric ontology IDs to strings, matching `app/src/api/review.ts`. Do not alter the submission model or add raw axios/localStorage access.

- [ ] **Step 3: Run the focused frontend tests.**

  Run:

  `cd app && npx vitest run src/utils/ontologyTags.spec.ts`

  `cd app && npx vitest run src/composables/review/useReviewApprovalActions.spec.ts`

  `cd app && npx vitest run src/views/curate/composables/__tests__/useReviewForm.spec.ts`

  Expected: PASS. The existing #600 form test and this new approval-path test together cover both curation submit flows.

### Task 9: Document the invariant and verify PR 2

**Files:**

- Modify: `AGENTS.md`
- Test: frontend tests from Tasks 7–8

- [ ] **Step 1: Add one Stack-Specific Gotchas bullet.**

  State the full tag encoding, real `HP:`/`VariO:` examples, the API/list endpoint provenance, the fact that CURIE ids are never numeric, and the exclusive use of `splitOntologyTag()` with first-separator semantics. Keep it adjacent to the existing masking/Plumber gotchas.

- [ ] **Step 2: Run static/type and quality checks.**

  Run: `git diff --check && make code-quality-audit && cd app && npm run type-check`

  Expected: PASS.

- [ ] **Step 3: Run full local CI before handoff.**

  Run: `make ci-local`

  Expected: PASS. This PR must not wait for PR 1; it changes docs, frontend type annotations, and Vitest guards only.

- [ ] **Step 4: Commit PR 2 separately.**

  Stage only `AGENTS.md` and the frontend helper/type/test changes. Use a focused commit message such as `test(review): guard CURIE ontology tags from numeric coercion`.

## Final handoff checklist

- [ ] Confirm the two PRs have no overlapping required commits and can be reviewed/merged independently.
- [ ] State plainly that there is no automatic repair migration and link support guidance to re-save known affected reviews.
- [ ] Report the targeted integration test’s real PASS/SKIP summary, `make test-api-fast`, `make code-quality-audit`, frontend type-check, and `make ci-local` outputs.
- [ ] Request the planned independent Codex `gpt-5.6-terra` review before any implementation work begins.
