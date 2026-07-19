# Adversarial diff review ROUND 2 — #573 Slice B (analysis-snapshot release UI)

You reviewed this branch in round 1 and returned NO-SHIP with one HIGH, two MEDIUM, two LOW. Those
findings have now been addressed in commit `401abf17`. This is a fresh, independent re-review of the
CURRENT full branch diff. Do two things:

1. **Verify each round-1 finding is genuinely resolved** (not papered over):
   - HIGH: `zenodo.record_url` rendered into a public `:href` with no scheme validation. Fix: a new
     `app/src/utils/safe-url.ts` `safeHttpUrl()` helper gates the record_url (and the DOI-constructed
     hrefs) so a `javascript:`/`data:` scheme renders as PLAIN TEXT, not a clickable link. Confirm a
     `javascript:` record_url can no longer become a clickable `<a href="javascript:...">` on
     `/DataReleases`, and the test proves it.
   - MEDIUM: `ReleaseManifest.generator`/`source` were typed as `string` but the backend serializes
     nested objects. Fix: real nested interfaces matching `api/functions/analysis-snapshot-release.R`,
     `scope_statement` made nullable, fixtures updated. Confirm the exported type now matches the wire
     shape.
   - MEDIUM: stale-response race in `DataReleases.vue`. Fix: a monotonic `detailRequestSeq` token
     discards a superseded detail response. Confirm a late `getLatestRelease` can no longer overwrite
     a newer `getRelease(id)` selection.
   - LOW: error mocks used `{message}` instead of RFC 9457 `{detail}` — converted.
   - LOW: added failure-path coverage for rejected DOI-save and draft-deletion.

2. **Hunt for any NEW or adjacent issues** the fixes may have introduced or that remain — same
   adversarial rigor as round 1 (contract fidelity vs the R/Plumber backend, security, resource
   leaks, race conditions, weak tests, accessibility, file size).

## The diff to review
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
Backend routes: `api/endpoints/analysis_endpoints.R`, `api/endpoints/admin_analysis_snapshot_endpoints.R`.
Backend helpers: `api/functions/analysis-snapshot-release*.R`, service in
`api/services/analysis-snapshot-release-service.R`. Conventions: `AGENTS.md`.

## Locked decisions (do NOT flag as defects; flag violations)
Public head = fixed 14-field allowlist + `zenodo{record_url,version_doi,concept_doi}` + conditional
`layers`/`manifest`, NEVER `created_by_user_id`/`last_error_message`. `release_version` is a reserved
always-NULL string. `reproducibility.json` hashes exactly to `reproducibility_hash`;
`payload_hash`/`input_hash`/`snapshot_id` are lineage anchors, NOT a hash of `payload.json`. `/file`
uses a `path` query param. Build: 201 created / 200 dup / 503 lock (distinct) / 400 five gate classes;
synchronous DB-only. Build disabled unless the 3 release layers are `available` (ignore
`phenotype_correlations`/`gene_network_edges`). "Publish immediately" defaults to draft. Typed clients
only; BTable can't render dotted field keys; problem+json via `extractApiErrorMessage`; no blocking
`window.confirm`.

Note: `NddScoreModelCard.vue` has a pre-existing identical unguarded-href pattern that is explicitly
OUT OF SCOPE for this PR (a separate follow-up) — do not count it against this branch.

## Output
Findings grouped by **BLOCKER / HIGH / MEDIUM / LOW**, each with file:line + concrete failure scenario
+ fix direction. Then a final `VERDICT: SHIP` or `VERDICT: NO-SHIP` line. If the round-1 findings are
resolved and nothing new is ship-blocking, say `VERDICT: SHIP` plainly.
