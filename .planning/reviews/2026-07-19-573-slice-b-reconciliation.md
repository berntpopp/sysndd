# #573 Slice B — review reconciliation

Branch: `feat/analysis-snapshot-releases-573-slice-b` (off `master` @ `d1a5a71a`).
Reviews: a Claude opus whole-branch review + Codex (`gpt-5.6-terra`, high reasoning) adversarial diff
review, run per the repo workflow. Findings printed twice by Codex; the review outputs are committed
alongside this file.

## Per-task reviews (subagent-driven-development)

Each task got a fresh implementer + a task reviewer (spec compliance + code quality). Findings
reconciled inline:

- **B2** (public view + panel + table): Spec OK, Quality Approved. 2 minor (byte-format boundary,
  loose table assertion) — non-blocking, carried to final review.
- **B3** (route + nav): clean. Deviation: "Data releases" inserted BEFORE "Phenotype–function
  correlation" because `routes.matrix-nav.spec.ts` (#89) pins that item last — correct resolution.
- **B4a** (admin client): 1 Important reconciled — `release_version`/`title` were mistyped as
  non-null (`release_version` even as `number`); the DB column is a reserved `VARCHAR` the builder
  always inserts as `NULL`. Fixed to `string | null` across the public + admin clients + manifest,
  dropped the always-empty "Version" column, title falls back to `release_id`. (commit `f83f2c96`)
- **B4b** (admin view + composable): 1 Important reconciled — row-action error and success rendered
  in different panels; co-located both in the Releases panel (mirrors `ManageNDDScore.vue`) + added a
  failure-placement test. 2 minor (dead `defineExpose` removed; blank-license now omitted so the
  server default applies). (commit `24825a1d`)

## Final whole-branch review (Claude opus)

Verdict: **READY TO MERGE**, 0 Critical / 0 Important. Flagged the `record_url` href as
defense-in-depth (see HIGH below) and confirmed the 3 pre-logged minors are non-blocking.

## Codex adversarial diff review — round 1: NO-SHIP

| Sev | Finding | Decision |
|-----|---------|----------|
| HIGH | `ReleaseManifestPanel.vue` renders admin-authored `zenodo.record_url` into a public `:href` with no scheme validation → a stored `javascript:` URL becomes clickable for unauthenticated `/DataReleases` visitors. | **FIXED** — added `app/src/utils/safe-url.ts` `safeHttpUrl()`; the record_url + DOI hrefs render as a link only for http(s), else plain text. Malicious-scheme test added. |
| MEDIUM | `ReleaseManifest.generator`/`source` typed as `string` but the backend serializes nested objects (`analysis-snapshot-release.R:414`); `scope_statement` nullable. | **FIXED** — real nested interfaces (`ReleaseManifestGenerator`/`Source`/`SourceDbRelease`/`SourceSnapshot`), `scope_statement: string \| null`, fixtures updated to the real wire shape. |
| MEDIUM | `DataReleases.vue` stale-response race: a slow `getLatestRelease()` resolving after a row selection overwrites `selectedRelease` (wrong release shown/downloaded). | **FIXED** — monotonic `detailRequestSeq` token discards superseded responses; out-of-order test added. |
| LOW | Error mocks used `{message}` instead of RFC 9457 `{detail}`. | **FIXED** — release-client error fixtures converted to problem+json `{type,title,status,detail}`. |
| LOW | No failure-path coverage for rejected DOI-save / draft-deletion. | **FIXED** — two tests added (error co-located in Releases panel; failed delete resets confirm state sanely). |

All round-1 findings reconciled in commit `401abf17`. Gates after fix: 97/97 targeted specs, full
suite 281 files / 2124 tests, `type-check` clean.

## Out-of-scope follow-ups (recorded, not fixed in this PR)

- **`NddScoreModelCard.vue:81`** has the identical pre-existing unguarded-`record_url`-href pattern.
  Not introduced by this branch; should get the same `safeHttpUrl` guard in a follow-up.
- **Backend `PATCH /releases/<id>/doi`** stores `record_url` without URL-scheme validation. The
  frontend guard is defense-in-depth; a source-of-truth fix (server-side allowlist of canonical
  `https://zenodo.org/...`) belongs with the backend and/or Slice C's Zenodo record-back path.

## Environment limitation (surfaced, not faked)

All dev/test DBs in this environment are BARE (no entity/release data; the incremental migrations
assume a prod-restored base schema absent here). So the mandated live browser/download verification
(render a published release, click download, recompute `sha256`, confirm it matches
`checksums.sha256`/`manifest.files[].sha256`) and a live admin HTTP build/publish COULD NOT be run.
Substitute evidence: green full frontend gate (type-check, 2124 unit tests, lint, file-size audit,
public-route bundle budget, SEO prerender), component specs that mount the real components against a
mocked-but-contract-faithful API client, and the two independent adversarial reviews above. The
"drive it in a real browser and recompute the hash" step needs a data-loaded environment.

## Codex adversarial diff review — round 2: SHIP

Re-ran independently on the post-fix branch. Verified every round-1 finding resolved (record_url
`safeHttpUrl` guard + regression tests, nested `generator`/`source` types, the `detailRequestSeq`
stale-response guard, problem+json mocks, DOI/delete failure tests) and found **no new** BLOCKER /
HIGH / MEDIUM / LOW — no public-data exposure, href-scheme bypass, backend-contract mismatch, request
race, accessibility, or file-size issue. **VERDICT: SHIP.** Full output in
`2026-07-19-573-slice-b-diff-codex-review-round2.md`.
