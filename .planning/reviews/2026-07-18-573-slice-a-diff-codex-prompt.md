# Codex adversarial DIFF review — #573 Slice A (immutable public analysis-snapshot releases, backend)

You are an adversarial staff-level reviewer. Review the implemented backend for issue #573 on the current branch against `master`. Be skeptical and thorough: find correctness bugs, security holes, and any regression of the LOCKED design decisions below. Prefer concrete, reproducible findings with `file:line` and a failure scenario.

## What to review
The Slice A commits are `git log --oneline 67cf6003..HEAD` (branch tip). Inspect the full diff: `git diff 67cf6003..HEAD`. Key new/changed files:
- `db/migrations/045_add_analysis_snapshot_release.sql` (+ `api/functions/migration-manifest.R` constant bump)
- `api/functions/analysis-snapshot-release-manifest.R` (pure content-address/manifest/tar helpers)
- `api/functions/analysis-snapshot-release-repository.R` (DB reads/writes, blobs)
- `api/functions/analysis-snapshot-release.R` + `api/functions/analysis-snapshot-release-materialize.R` (build orchestrator + gates + materialization)
- `api/functions/analysis-reproducibility.R` (new `analysis_reproducibility_decode_raw`)
- `api/services/analysis-snapshot-release-service.R` (problem+json shaping)
- `api/endpoints/analysis_endpoints.R` (public read routes) + `api/endpoints/admin_analysis_snapshot_endpoints.R` (admin routes)
- `api/functions/analysis-snapshot-repository.R` (`analysis_snapshot_prune` release guard)
- `api/bootstrap/load_modules.R` (registration); tests under `api/tests/testthat/`
Spec (source of truth, already reconciled with a prior Codex review — do NOT re-litigate settled design): `.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md` and plan `…-573-plan.md`.

## LOCKED decisions (intentional — flag a REGRESSION of these, not the decision itself)
- Release identity = `content_digest` = sha256 over invariant scientific content, EXCLUDING `created_at`/`title`/DOI. `release_id = "asr_" + content_digest[:16]`; full 64-char digest stored; collision-checked on insert.
- Each release file has its OWN `content_sha256`. `sha256(payload.json) != payload_hash` by design (DECIMAL round-trip) — `payload_hash`/`input_hash`/`snapshot_id` are cross-checkable LINEAGE ANCHORS vs the live `meta.snapshot`, not the file hash.
- `reproducibility.json` = the RAW `memDecompress(bundle_gzip_json, type="gzip", asChar=TRUE)` bytes (NOT the parsing `analysis_reproducibility_decode()`), so `sha256(reproducibility.json) == reproducibility_hash` EXACTLY.
- File retrieval route = `GET /releases/<id>/file?path=<file_path>` (query param; Plumber 1.3.2 has NO `<path:.*>`); exact `(release_id,file_path)` PK lookup, no traversal surface.
- Build fails 400 (there is NO 409 class): not-available / hard-coherence-recheck (require_coherence=TRUE, ignoring the env downgrade; incl. the reconstructable channel-match check; member-set equality is genuinely NOT reconstructable because `reference_members` is not persisted — the non-NA-stability check is the accepted substitute) / missing-reproducibility / source-version-mismatch / dependency-lineage-mismatch. Duplicate build = idempotent 200. TOCTOU: per-preset advisory locks + a FRESH pre-insert loader re-read re-asserting {snapshot_id,payload_hash}+deps. DOI additive, outside the hash. Bundle built once + stored + served verbatim (rebuild determinism NOT required).
- Migration 045 bumps BOTH `EXPECTED_LATEST_MIGRATION` and `EXPECTED_MIGRATION_COUNT` (42→43).
- Public release routes are DB-only (no external fetcher). Admin routes require Administrator. Drafts never public.

## Focus your adversarial attention on
1. **Authorization / data exposure:** can any public route reach a draft release or non-approved-public data? Is every admin route Administrator-gated (first line)? Any way to bypass?
2. **SQL / injection:** every `release_id`/`file_path`/param goes through bound `?` params with `unname()`; no string interpolation; the prune `NOT IN`/helper is NULL-safe. Any interpolation site?
3. **Build gate soundness:** can an incoherent / stale / mismatched / reproducibility-less / superseded snapshot be frozen into a published release? Is the TOCTOU re-read genuinely fresh (not the cached in-memory object)? Do the per-preset locks actually collide with the axis-refresh locks?
4. **Hashing invariants:** verify the reproducibility.json exact-equality and the content_digest exclusions hold in code; look for any place `created_at`/`title`/DOI could leak into the digest, or where the served bytes could differ from the hashed bytes.
5. **Byte-serving correctness:** the manifest/file/bundle routes — single Content-Type, correct bytes, no traversal, blobs not stringified/logged.
6. **Resource safety:** the build route's `pool::poolCheckout` returns the connection on ALL paths (incl. every 400 error path); advisory locks released on all exits; no connection/lock leak.
7. **Adjacent same-class issues:** if you find one instance of a class of bug (a missing bound param, a leak path, an authz gap, a hash-input inconsistency), GREP FOR AND REPORT ALL SIBLINGS in the release code — do not stop at the first.
8. **Migration/bootstrap:** 045 DDL correctness for MySQL 8.4; the manifest count/latest bump; module source order in load_modules.R.

## Output format
Group findings by severity: BLOCKER / HIGH / MEDIUM / LOW. For each: `file:line`, the defect, a concrete failure scenario (inputs → wrong outcome), and a minimal fix. If a concern turns out to be handled correctly, say so briefly (a short "checked X — OK"). End with a one-line SHIP / DO-NOT-SHIP recommendation. Do not modify any files (read-only review).
