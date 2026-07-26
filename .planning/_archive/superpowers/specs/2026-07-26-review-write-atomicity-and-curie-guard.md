# Review Write Atomicity and CURIE Regression Guard — Specification

- **Date:** 2026-07-26
- **Status:** Drafted for requested Codex `gpt-5.6-terra` plan review; no implementation has started.
- **Context:** Follow-up work after #600 / v0.30.11 (`372df87a`).
- **Delivery:** Two independent PRs. PR 2 may land before PR 1.

## Problem

`POST /api/review/create` and `PUT /api/review/update` currently execute the review, publication, phenotype, and variation writes sequentially. The called repositories either use the global pool or begin their own transaction, so there is no request-wide atomic boundary. A phenotype failure can therefore return 500 after the review and publication association have committed; for re-reviews, it can also mark `re_review_review_saved = 1` prematurely.

The #600 frontend defect made this observable: an ontology CURIE coerced through `Number()` became `NaN`, then JSON `null`, which failed during phenotype/variation connection. The frontend now sends CURIEs correctly. The API must still reject malformed/null ontology identifiers before any write begins, and the UI needs a durable, executable regression guard.

## Decision summary

1. **PR 1: prepare first, write once.** Resolve external publication/GeneReviews information and perform all deterministic request validation before starting a MySQL transaction. Then write the publication rows, review, join rows, re-review saved marker, and optional direct approval through one checked-out connection and one transaction.
2. **No transaction is held over upstream I/O.** External resolution succeeding and the subsequent DB transaction rolling back is acceptable: the retrieved metadata is discarded, the remote reads have no compensating side effect, and a retry may fetch it again. This is preferable to holding locks while waiting for PubMed/GeneReviews.
3. **Explicit connection participation prevents nesting.** The coordinator begins a transaction only for a `pool::Pool`. A supplied `DBIConnection` is assumed to be caller-owned and is used directly. Repository operations receive `conn` and never begin a nested transaction when it is supplied. This makes `with_test_db_transaction()` usable for DB-writing integration tests.
4. **Malformed phenotype/VariO identifiers are client errors.** A missing, `NULL`, `NA`, empty, or all-whitespace `phenotype_id` / `vario_id` is rejected before external work or DB writes with `stop_for_bad_request()`. Mounted endpoint error handling then emits RFC 9457 `application/problem+json`, status 400.
5. **The re-review marker is last.** `re_review_review_saved = 1` and the linked `review_id` are updated only after every preceding review mutation has succeeded, within the same transaction. A later failure rolls the marker back with the rest.
6. **Scalar success response is in scope.** The replacement service returns one scalar 200 status and one scalar message. The existing tibble aggregation that recycles status into a vector is removed from this path.
7. **No automatic historical repair.** An automated data repair cannot safely distinguish an intentional review with no phenotype/variation rows from a partial #600-era failure, and it would risk overwriting curation. Re-saving a known affected review executes the normal update/replace path and restores its intended joins atomically. Provide operator/support guidance only; do not run a migration or mass update.

## Approaches considered

### A. Put `dbWithTransaction()` around the current endpoint calls

Rejected. `new_publication()` performs upstream I/O and also opens its own transaction; update/replace repositories do likewise. RMariaDB rejects `dbBegin()` on an already-open connection, and global-pool reads/writes would not reliably participate in an endpoint-owned connection. This would either fail at runtime or create a misleading partial boundary.

### B. Prepare externally, then coordinate one connection-aware transaction (selected)

The endpoint remains responsible only for authorization and request extraction. A focused review-write service normalizes and validates the payload, obtains publication metadata before `BEGIN`, then owns the short all-or-nothing mutation phase. Repositories expose `conn = NULL` participation and only self-transaction for legacy standalone callers. This follows the existing entity creation design while solving the nested-transaction and external-I/O constraints explicitly.

### C. Keep sequential writes and add compensating deletes on failure

Rejected. Compensation cannot faithfully restore a PUT's replaced join rows, can race with concurrent edits, would leave re-review state difficult to reconstruct, and is less reliable than database rollback.

## PR 1 — atomic review write

### Boundary and data flow

```
request
  -> role gate and method check (endpoint)
  -> normalize tag payloads; validate synopsis, ids, modifiers, requested review/entity relationship
  -> classify/fetch external publication metadata (no transaction)
  -> validate local lookup identifiers (no transaction)
  -> BEGIN on one checked-out connection
       -> insert prepared, missing publication records
       -> create or update review
       -> insert/replace publication associations
       -> insert/replace phenotype associations
       -> insert/replace variation associations
       -> set re_review_review_saved + review_id, if requested
       -> direct approval, if requested
     COMMIT
  -> scalar 200 response
```

An error at any mutation step escapes the coordinator transaction and rolls back every mutation in the list. The mounted endpoint handler maps unexpected transaction/database errors to the existing redacted RFC 9457 500 response. No new 500 condition class is needed.

### Publication preparation

`new_publication()` is not currently external-only: it fetches metadata and writes the `publication` table in its own transaction. The implementation must split those responsibilities:

- a preparation helper resolves and returns the as-yet-missing publication rows without persisting them;
- a connection-aware persistence helper inserts those prepared rows inside the review transaction;
- the legacy `new_publication()` API keeps its existing standalone behaviour by composing preparation and standalone persistence, preserving callers outside review write (entity creation and GeneReviews tooling).

The transaction must tolerate a concurrent request making a prepared publication available between preparation and persistence. The persistence operation must use a duplicate-safe, constrained insertion strategy rather than treating that benign race as a failed review save; genuinely invalid database values still fail and roll back the review transaction.

### Transaction participation contract

The coordinator accepts a pool or direct DBI connection.

- With `pool::Pool` (the API path), it checks out one connection and wraps its write callback with `db_with_transaction(..., pool_obj = pool)` / `DBI::dbWithTransaction` exactly once.
- With a direct DBI connection (the integration-test path), it performs the callback directly and never calls `dbBegin()`, `dbWithTransaction()`, or `db_with_transaction()`. The caller owns the transaction.
- Repository functions that can write as part of the review save accept `conn = NULL`. With `conn`, they execute only their SQL on that connection. Without it, existing public standalone behaviour remains transactionally safe by opening their own transaction where necessary.

This is deliberately local to review-related operations. The generic transaction helper will not attempt to detect or silently join arbitrary pre-existing transactions; doing so would mask incorrect ownership elsewhere.

### Validation and error behaviour

The new request-normalization/validation stage accepts the two established wire formats (tag `value` and explicit `phenotype_id`/`vario_id` plus modifier), preserving ontology values as strings. It rejects these before any external resolution or write:

- absent or blank synopsis/entity/review id required for the selected method;
- malformed tag shape or non-numeric/missing modifier;
- `phenotype_id` / `vario_id` that is `NULL`, `NA`, empty, or whitespace-only;
- identifiers absent from the corresponding local lookup table;
- PUT whose review does not belong to the supplied entity.

Bad request validation uses the existing `stop_for_bad_request()` / `error_400` mechanism, not an ad-hoc returned list. Because `/api/review` is mounted with `mount_endpoint()`, clients receive a scalar RFC 9457 problem document with status 400 and `application/problem+json`.

Existing external publication resolution errors remain 400s and happen before the write phase. A successful remote fetch followed by DB rollback does not create a partially saved review or partially saved publication record.

### Re-review and direct approval

The re-review saved flag belongs to the write unit, not review creation alone. It is updated after joins have been written and before commit, so its value never claims an incomplete save.

`direct_approval=TRUE` is also part of the request's mutation unit. Refactor the repository approval operation to participate in the supplied connection, so approval and its sibling/re-review synchronization are rolled back if any preceding or approval step fails. This prevents a direct-approval request from retaining the same misleading “500 but review saved” outcome through a different final write.

### File boundaries

Create a focused `api/services/review-write-service.R`; it owns only review-save preparation, transaction ownership, and response assembly. Keep endpoint authorization/parsing thin and keep lower repositories responsible for individual SQL operations. Do not add the coordinator to the already 500-line `review-service.R`, and reduce `review_endpoints.R` rather than pushing it above its current 586 lines.

## PR 2 — CURIE docs and executable regression guard

This PR is independent of PR 1 and changes no server transaction behaviour.

- Add a Stack-Specific Gotchas entry in `AGENTS.md`: curation tag values are `"<modifier_id>-<ontology_id>"`; the ontology half is a CURIE string; `splitOntologyTag()` is the only splitter; it splits at the first separator; only the modifier is numeric.
- Add focused frontend tests for `splitOntologyTag()` and both review-submit flows. Use real CURIE fixtures (`HP:0001249`, `VariO:0015`, including a hyphen-bearing ontology suffix) and assert the outbound JSON contains string ids and never `null`.
- Correct stale local TypeScript annotations in `useReviewApprovalActions.ts` so loaded API ontology identifiers are represented as strings, consistent with `app/src/api/review.ts`.

The runtime tests, not prose alone, are the regression guard: reintroducing `Number(ontologyId)` in either curation submission path produces `NaN`, which the JSON assertion turns into a failing `null` expectation.

## Testing strategy

| Layer | Test | Required proof |
|---|---|---|
| API integration | New `test-integration-review-write-atomicity.R`, inside `with_test_db_transaction()` | A deliberate late phenotype-write constraint failure leaves no new review, no review-publication join, no phenotype/variation join, and no re-review saved mutation. A PUT variant preserves the original review and all prior joins. |
| API unit | New review-write service tests | Invalid/null/blank CURIE ids fail as `error_400` before the transaction callback; direct connection path never opens a nested transaction; success response status is a scalar. |
| API repository | Targeted participation tests | `conn` paths do not self-wrap, while standalone callers retain atomic replace behaviour. |
| Endpoint | Existing `test-endpoint-review.R` updated | The thin endpoint delegates to the coordinator and returns scalar status; direct approval is passed into the atomic request. |
| Frontend unit | `ontologyTags` and review submit tests | First-separator splitting; CURIE preservation and no JSON `null` in both submit paths. |
| Gates | `make test-api-fast` during work; `make ci-local` before handoff | No regression of API, frontend, lint, or code-quality gates. |

DDL for API integration fixtures happens outside `with_test_db_transaction()` on a separate connection. The test creates test data inside the helper-owned transaction and passes that direct connection into the new coordinator, explicitly exercising the RMariaDB non-nesting constraint.

## Scope boundaries

Included:

- atomicity for review create/update, publication persistence/associations, phenotype/variation associations, re-review saved state, and direct approval within one review-save request;
- safe pre-write validation and RFC 9457 400 handling for malformed ontology identifiers;
- scalar status response correction on this endpoint path;
- independent CURIE documentation/types/tests.

Not included:

- a database migration, mass repair script, or mutation of historic review rows;
- generic nested-transaction auto-detection in `db_with_transaction()`;
- changing unrelated entity/status write flows or their existing publication semantics;
- frontend UX redesign, retry/idempotency tokens, or new external-provider policy;
- changing ontology formats or coercing CURIEs to numeric values.

## Operational repair decision

There is no safe automatic repair query: missing ontology joins are valid for many reviews, and historical database state contains no durable copy of the failed request payload from which to reconstruct intent. For a known affected review, support/curation should open it, verify the desired values, and save it once after PR 1. The atomic update path replaces associations and correctly commits the re-review marker together with the completed review. Log/DB investigation may identify candidates for human review, but it must not be automated into a bulk write.
