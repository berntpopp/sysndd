# Adversarial diff review — #573 Slice B (analysis-snapshot release UI)

You are a staff-level adversarial reviewer. Review the frontend changes on this branch that add the
public + Administrator UI for immutable analysis-snapshot releases. Be skeptical and thorough — hunt
for real correctness bugs, contract mismatches against the R/Plumber backend, security issues, and
weak tests. Expand scope to adjacent same-class issues you find.

## The diff to review
Run and review exactly:
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
(24 files, all under `app/src/`, plus `documentation/09-deployment.qmd`, `AGENTS.md`, `CHANGELOG.md`,
and version files.) This is a Vue 3 + TypeScript SPA (`app/`) talking to an R/Plumber REST API
(`api/`). You may read any file in the repo for context — the backend routes live in
`api/endpoints/analysis_endpoints.R` and `api/endpoints/admin_analysis_snapshot_endpoints.R`, the
services in `api/services/analysis-snapshot-release-service.R`, and the repository/manifest helpers
in `api/functions/analysis-snapshot-release*.R`. Repo conventions are in `AGENTS.md`.

## What this change does
- `app/src/api/analysis_releases.ts` — PUBLIC typed client (re-exported from `analysis.ts`):
  `listReleases`, `getLatestRelease`, `getRelease`, `downloadReleaseBundle`,
  `downloadReleaseManifest`, `downloadReleaseFile`.
- `app/src/api/admin_analysis_release.ts` — ADMIN typed client: `buildRelease`, `listAdminReleases`,
  `getAdminRelease`, `publishRelease`, `recordReleaseDoi`, `deleteDraftRelease`,
  `fetchSnapshotStatus`, `RELEASE_LAYER_TYPES`.
- `app/src/views/analyses/DataReleases.vue` (+ `ReleaseManifestPanel.vue`, `dataReleaseTable.ts`) —
  public page: releases table + manifest provenance card + downloads + "how to verify" disclosure.
- `app/src/views/admin/ManageAnalysisReleases.vue` (+ `useAnalysisReleaseAdmin.ts`) — admin page:
  build / publish / record-DOI / delete-draft.
- routing + nav registration + a decorative `meta.sitemap`.

## LOCKED decisions (do NOT flag these as defects; DO flag any code that violates them)
1. **Public head is a fixed 14-field allowlist** + `zenodo{record_url,version_doi,concept_doi}` +
   conditional `layers`/`manifest`. It NEVER includes `created_by_user_id` or `last_error_message`.
   The public `ReleaseHead` type must not carry those; the ADMIN `AdminReleaseHead` intentionally does
   (flat DOI columns, not nested `zenodo`). The two types are deliberately different.
2. **`release_version` is a reserved `VARCHAR(32) DEFAULT NULL`** the builder always inserts as `NULL`
   (`api/functions/analysis-snapshot-release.R:409,467`); `title` is nullable too. Both are typed
   `string | null`; the UI must not render an always-empty Version column and must fall back to
   `release_id` when `title` is null.
3. **`reproducibility.json` hashes EXACTLY to `reproducibility_hash`**; each file has its own
   `content_sha256`; `payload_hash`/`input_hash`/`snapshot_id` are LINEAGE ANCHORS cross-checkable
   against the live `/api/analysis/*` `meta.snapshot`, NOT a hash of the release's own `payload.json`.
   The "How to verify" copy must state this correctly and must NOT claim `sha256(payload.json) ==
   payload_hash`.
4. **`GET .../releases/<id>/file?path=<file_path>` uses a query param**, not a URL path segment.
5. **`manifest` + `files[]` appear ONLY on the detail/`latest` routes**; the LIST route carries a
   light per-head `layers` (`{analysis_type, snapshot_id, payload_hash}`). The manifest panel must
   fetch the DETAIL route.
6. **Admin build**: 201 = created, 200 = idempotent duplicate, 503 `release_lock_unavailable`
   (Retry-After) = sources mid-refresh (surface DISTINCTLY), 400 = one of 5 gate classes
   (`release_snapshot_not_available`, `release_source_incoherent`, `release_reproducibility_missing`,
   `release_source_version_mismatch`, `release_dependency_lineage_mismatch`). The build is synchronous
   and DB-only (no async job).
7. **Build must be disabled unless all three release layers are `available`**: exactly
   `functional_clusters`, `phenotype_clusters`, `phenotype_functional_correlations` (the status
   endpoint also returns `phenotype_correlations` + `gene_network_edges` — those must be IGNORED for
   the gate).
8. **"Publish immediately" defaults to UNCHECKED** (build a draft; publish is a deliberate second step).
9. Repo footguns (flag violations): typed clients only (no raw axios in views/components, no
   `localStorage.token`/`localStorage.user`); BootstrapVueNext `BTable` cannot render a dotted field
   key (flatten `zenodo.*` → `zenodo_*`); `v-b-tooltip` is reactive to the binding VALUE not `:title`;
   Plumber JSON scalars may come back array-wrapped on default-serialized endpoints (the release
   admin routes use `unboxedJSON`, so scalars are plain there); problem+json errors are read via
   `extractApiErrorMessage`.

## Focus your adversarial energy on
- **Contract fidelity**: does each client call the exact route/verb/param the R endpoint expects?
  Does `recordReleaseDoi` send ONLY the supplied DOI fields (an empty/omitted field must be left
  unchanged server-side, never nulled)? Does `buildRelease`'s `validateStatus` correctly let
  200/201/503 resolve while 400/404 throw?
- **Rendering correctness & XSS**: release data (title, hashes, DOI values, file paths, `record_url`)
  is server-controlled but admin-authored — are DOI/`record_url` links safe (no `javascript:` scheme
  injection into `href`), and is any `v-html`/dynamic-attribute usage safe? Is the dotted-key BTable
  trap actually avoided in BOTH tables (public + admin)?
- **Resource leaks**: every blob download must create AND revoke its object URL and clean up the
  transient anchor.
- **State/edge cases**: empty state (no published release → `getLatestRelease` 404), a release with a
  `null` title or `null` reproducibility_hash (correlation layer), the `canBuild` gate when a release
  layer is `stale`/`missing`/absent, concurrent build clicks (double-submit), and the 503-vs-400
  branch not being conflated.
- **Test quality**: are the vitest specs asserting real behavior, or shallow truthiness? Is the
  failure path (a rejected publish/DOI/delete) covered and shown near the control? Do MSW mocks model
  the real wire shapes (problem+json uses `detail`, not `message`)?
- **Accessibility**: copy buttons, download buttons, and form inputs have accessible labels; no
  blocking `window.confirm`.
- **File size**: any handwritten source file > 600 lines (soft ceiling).

## Output
List findings grouped by severity: **BLOCKER**, **HIGH**, **MEDIUM**, **LOW**. For each: the file:line,
the concrete failure scenario (inputs → wrong behavior), and a fix direction. Then end with an explicit
verdict line: `VERDICT: SHIP` or `VERDICT: NO-SHIP` (with the blocking items). If you find nothing
ship-blocking, say so plainly — do not manufacture issues.
