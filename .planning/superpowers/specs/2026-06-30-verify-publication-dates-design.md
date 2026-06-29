# Verified publication dates: persist source on refresh + durable backfill job (#460)

**Date:** 2026-06-30
**Issue:** https://github.com/berntpopp/sysndd/issues/460
**Implementation branch (proposed):** `fix/verify-publication-dates-460`

> Scope note: backend/data-pipeline reproducibility fix. Framed generically (temporal/
> provenance queryability via API/MCP); no external publication artifacts referenced here.

## Problem

Publication records expose dates flagged `publication_date_confidence: unverified`, and
`recommended_citation` drops the date when the source is untrusted. This blocks any
temporal/provenance query that needs a trustworthy literature publication date.

**Ground-truthed state (the issue is correct in spirit but the infra is further along
than it implies):**

- The schema is ready: `publication.publication_date_source VARCHAR(20)` (migration
  `021_add_publication_date_source.sql`), with observed values `'pubmed'`,
  `'pubmed_partial'`, `'medline_date'`, `'unknown'`, and `NULL` (legacy). The confidence
  flag is **derived** from it in `api/services/mcp-service.R:283-293`
  (`pubmed`→`pubmed_verified`; `pubmed_partial`/`medline_date`→`pubmed_partial`; else /
  `NA`→`unverified`).
- The literature date column already exists: `publication.Publication_date` (DATE) backs
  `publication_date_sysndd_record` (`mcp-service.R:319`). **Correction to the issue's
  claim #3:** this is the *literature* date column, not a curation column. The curation
  timeline is the separate `sysndd_curation_date` (← `curation_review_date`); the record
  stamp is `publication.update_date`. The real defect is that **legacy rows have
  `publication_date_source = NULL`** (migration 021 nulled them "until the backfill runs"),
  so their `Publication_date` is unverified and may be an ingestion-date artifact.
- `recommended_citation` (`mcp-service.R:255-272`) already **includes the date for trusted
  rows** (`pubmed_verified`/`pubmed_partial`) and appends `"(publication date unverified)"`
  otherwise. So the "include the year" acceptance criterion is met automatically once a
  row's source is populated — no citation-format change is required.
- A **complete operator backfill already exists**: `db/updates/backfill_publication_dates.R`
  (advisory lock `sysndd_backfill_publication_dates`, scope = primary-approved
  publications with `NULL`/invalid source, ≤200 PMIDs/request, NCBI rate delay,
  transactional batched UPDATE of **both** `Publication_date` and
  `publication_date_source`). It is operator-run, not wired into the app.
- A durable `publication_refresh` async job exists (`async-job-handlers.R:758-832`,
  registry `:924`) that re-fetches per PMID via `info_from_pmid` and UPDATEs
  `publication` — but its UPDATE (`:782-791`) **omits `publication_date_source`**, so
  refreshed rows silently stay `unverified`. **This is the core latent bug.**

So the two real gaps are narrow: (1) the refresh job drops the source column; (2) the
verified-date backfill is not app-triggerable/durable.

## Goals (Option 1: close gaps + durable job + run)

- `publication_refresh` persists `publication_date_source` (and thus the confidence flag).
- A durable, Administrator-triggerable verified-date **backfill job** exists, reusing the
  existing standalone script's logic, so the backfill runs without SSH/`docker exec`.
- The backfill is **run**, flipping resolvable legacy rows to `pubmed_verified` /
  `pubmed_partial`; verified dates already surface through the API/MCP and citations.
- A documented fallback for PMIDs that cannot be verified (`NULL`/`unknown` →
  `unverified`).

## Non-goals (Option 3, deferred)

- **No Crossref-by-DOI fallback.** PubMed EUtils is the single source for v1; unresolvable
  PMIDs stay `unverified`. (No Crossref helper exists in the repo today.)
- **No routing PubMed through `external_proxy_budget()`.** `pubmed_esearch_count()` /
  `pubmed_fetch_xml()` currently use raw `httr2::req_timeout(30)` + `req_retry(3)` and a
  manual `Sys.sleep(0.34)` NCBI rate-gate. The dedicated backfill job carries its own
  rate-limit and chunking, so the per-request external-time ceiling (designed for public
  paths) is not the constraint here. Noted as a follow-up (the `external-budget-guard`
  static test currently does not cover these PubMed helpers; do **not** widen its scope in
  this change).

## Design

### Fix 1 — `publication_refresh` persists the source (core latent bug)

In `.async_job_run_publication_refresh` (`api/functions/async-job-handlers.R:758-832`),
extend the per-PMID UPDATE (`:782-791`) to also set `publication_date_source` from the
`info_from_pmid` result (which already returns it). This is the minimal correctness fix and
makes every future refresh self-verifying.

### Fix 2 — extract shared backfill logic + durable job

1. **Factor the standalone script** `db/updates/backfill_publication_dates.R` core into a
   shared function, e.g. `backfill_publication_dates_run(conn, limit = NULL, dry_run =
   FALSE, progress = NULL)` in `api/functions/publication-date-backfill.R` (registered in
   `api/bootstrap/load_modules.R` so both the API and the worker load it). It encapsulates:
   target selection (primary-approved publications with `NULL`/invalid source), chunked
   fetch (`info_from_pmid`, ≤200/req), NCBI rate-limit, and transactional batched UPDATE of
   `Publication_date` + `publication_date_source`. The advisory lock
   `GET_LOCK('sysndd_backfill_publication_dates', 0)` stays (single-flight). The standalone
   script becomes a thin CLI wrapper over this function (operator path preserved).
2. **Register a durable async handler** `publication_date_backfill` in
   `async_job_handler_registry` (System B; worker-executed, needs NCBI egress — the worker
   already has the `proxy` network). The handler calls the shared function with a
   `progress` callback for job-history visibility and returns a structured run summary
   (counts: targeted / verified / partial / unresolved) into `result_json`. A benign skip
   (lock held / nothing to backfill) completes successfully; a hard fetch/DB failure marks
   the job failed (observable in job history) — mirroring the pubtatornidd/ontology-mapping
   job conventions.
3. **Administrator trigger endpoint** `POST /api/admin/publications/verify-dates` (optional
   `limit`, optional `dry_run`) that enqueues the durable job, plus
   `GET /api/admin/publications/verify-dates/status` reporting last-run summary from job
   history. Mount the `/api/admin/publications` sub-router **before** `/api/admin` (more
   specific prefix wins) and wrap with `mount_endpoint()` (RFC 9457 error handler). Guard
   with `require_role(req, res, "Administrator")`.

### Fix 3 — run it + confirm exposure

- Run the backfill (operator triggers the new admin endpoint, or runs the CLI wrapper).
- Verified dates already flow through `mcp_publication_record` (`mcp-service.R:306-340`) and
  `recommended_citation`; no read-path change is required. Confirm via MCP
  `get_publication_context` on a backfilled PMID that `publication_date_confidence` is
  `pubmed_verified`/`pubmed_partial` and `recommended_citation` carries the year.

## Testing

- **Unit**: `publication_refresh` UPDATE includes `publication_date_source` (static guard
  on the handler source + a behavioral test with a mocked `info_from_pmid` asserting the
  bound UPDATE params include the source); the shared `backfill_publication_dates_run`
  selects the correct target set and, with a mocked PubMed fetch, writes both columns
  (`with_test_db_transaction`).
- **Unit**: the durable handler is registered and the admin endpoint requires Administrator
  + is mounted via `mount_endpoint()` (mirror `test-unit-admin-snapshot-endpoint-guard.R`).
- **MCP**: a verified row yields `publication_date_confidence = pubmed_verified` and a
  year-bearing `recommended_citation` (extend the MCP publication service test).
- PubMed network helpers are mocked (stub `pubmed_fetch_xml` / `info_from_pmid`), per repo
  convention — no live NCBI calls in tests.

## Acceptance criteria

- [ ] `publication_refresh` persists `publication_date_source` (resolvable PMIDs become
      `pubmed_verified`/`pubmed_partial`, not `unverified`).
- [ ] A durable Administrator-triggerable backfill job exists, reusing the shared logic;
      the standalone script remains a thin wrapper.
- [ ] After running the backfill, resolvable legacy publication rows carry a
      `publication_date` with `publication_date_confidence` ∈
      {`pubmed_verified`,`pubmed_partial`}; `recommended_citation` includes the year.
- [ ] A documented fallback exists for unverifiable PMIDs (`NULL`/`unknown` →
      `unverified`).
- [ ] The verified date is queryable via API/MCP (already is; confirmed by test).

## Files touched (anticipated)

- `api/functions/async-job-handlers.R` (refresh UPDATE + new handler registration)
- `api/functions/publication-date-backfill.R` (**new**, shared logic)
- `db/updates/backfill_publication_dates.R` (thin wrapper over shared fn)
- `api/endpoints/admin_publications_endpoints.R` (**new**, admin trigger + status)
- `api/bootstrap/mount_endpoints.R` (mount before `/api/admin`)
- `api/bootstrap/load_modules.R` (register new module)
- tests: `publication_refresh` source guard + behavior, backfill unit, admin-endpoint
  guard, MCP verified-citation test

## Operational notes

- The backfill is bounded to primary-approved publications (not the whole `publication`
  table), so the NCBI call volume is moderate; chunked ≤200/req with the existing rate
  delay. Worker egress to NCBI is required (already present on the `proxy` network).
- Independent of the clustering program (#457–459); can ship in parallel.
