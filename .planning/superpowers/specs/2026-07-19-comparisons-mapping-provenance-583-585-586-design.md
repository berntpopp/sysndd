# Design: Curation-comparison mapping policy + snapshot generator provenance

- **Date:** 2026-07-19
- **Issues:** #583 (PanelApp Red/1 → low evidence), #585 (snapshot generator provenance), #586 (explain normalized tier mappings in the Curation Comparisons UI)
- **Explicitly out of scope:** #584 (ZNF41 entity 780) — a senior-curator adjudication recorded through the running SysNDD curation workflow, not a repository code change. Excluded from this PR by owner decision.
- **Deliverable:** one PR closing #583, #585, #586.

## Problem

Three coupled transparency gaps in the curation-comparison and analysis-snapshot surfaces:

1. **#583** — `normalize_comparison_categories()` maps PanelApp confidence `1`/Red → `Refuted` and `2`/Amber → `Limited`. PanelApp Red denotes *low evidence*, not affirmative refutation; downstream consumers wrongly treat low-evidence PanelApp membership as excluded. The normalized mapping also carries no version identifier, so frozen downstream comparisons cannot tell old from new policy.
2. **#585** — Analysis snapshots persist input/validation/payload hashes but not the *generator*: no deployed application revision, `CLUSTER_LOGIC_VERSION`, snapshot-builder version, or algorithm/library parameters. A consumer can verify internal hashes but cannot reproduce the code state.
3. **#586** — The public Curation Comparisons page never explains how source-specific confidence labels are harmonized, and there is no in-context, versioned crosswalk. Any explanation added risks drifting from the API's actual normalization.

## Owner decisions (locked)

- **PanelApp crosswalk = full ordinal:** Green/`3` → Definitive, Amber/`2` → **Moderate**, Red/`1` → **Limited**. **No PanelApp tier maps to Refuted.** This corrects *both* Amber (was Limited) and Red (was Refuted).
- **#584 excluded** from this PR entirely; no code, no dossier. Handled separately by a curator.

## Key invariants this design must preserve

- **Additive provenance never changes identity.** `analysis_snapshot_payload_hash()` deliberately excludes `{raw, partition_validation, reproducibility}`; `input_hash` covers only `{analysis_type, params, source_data_version, dependencies}`; per-cluster `cluster_hash` is independent. #585 provenance lives **outside** all three, so membership/`cluster_hash`/LLM summaries do not change and **`CLUSTER_LOGIC_VERSION` is NOT bumped** (`api/functions/analysis-snapshot-builder.R:499-513`).
- **Release content-addressing is unchanged.** `analysis_release_content_digest()` hashes only `{manifest_schema_version, source_data_version, layers[]}` and excludes the `generator`/`source`/`created_at`/`title`/DOI blocks, so extending the release `generator` block does not change `content_digest` or `release_id` (`api/functions/analysis-snapshot-release-manifest.R:155-172`).
- **Comparison normalization is read-time.** Categories are stored raw in `ndd_database_comparison` and normalized at read time in exactly two sites (`api/functions/comparisons-list.R:66-67`, `api/endpoints/comparisons_endpoints.R:134-136`). The #583 change therefore takes effect on an **API restart** — no `comparisons_update` refresh and no worker restart for existing rows.
- **No UI drift.** The popover's mapping text is fetched from a new API endpoint whose payload is generated from the same declarative crosswalk the normalizer is verified against by a CI guard test.

## Architecture

### Component 1 — Category normalization policy (`#583`, API)

**File:** `api/functions/category-normalization.R`

- **Mapping change:** PanelApp branch becomes `3 → Definitive`, `2 → Moderate`, `1 → Limited`. G2P `refuted`/`disputed → Refuted` unchanged (this is the only comparison source carrying explicit disputed/refuted assertions).
- **Roxygen update (required, not optional):** the function's `@details` block (`category-normalization.R:28-31`) currently states PanelApp `2 → Limited`, `1 → Refuted`; it is corrected to the new ordinal in the same change so the in-code documentation never contradicts the behavior.
- **Version constant:** add `COMPARISON_CATEGORY_MAPPING_VERSION <- "2026-07-19.583-panelapp-ordinal"` (date-tagged policy id). This is the single identifier surfaced to consumers.
- **Declarative crosswalk (single display source of truth):** add `comparison_category_crosswalk()` returning a structured object:
  - `mapping_version`
  - `tiers`: the ordered normalized four-tier vocabulary with short definitions (`Definitive`, `Moderate`, `Limited`, `Refuted`) plus the non-tier fillers (`not applicable`, `not listed`) documented separately.
  - `sources[]`: per source, the native scale → normalized-tier rows. **Each row is tagged with a `rule_kind`** so the guard test can exercise the *executable* behavior, not just declared rows: `exact` (PanelApp `3/2/1`, SFARI `1/2/3`, NDD GeneHub `Tier 1`/`AR`/`Tier 2`/`Tier 3`/`Tier 4`/`Missense`), `case_insensitive` (G2P `strong`/`definitive`/`limited`/`moderate`/`disputed`/`refuted`/`both rd and if`), `missing` (SFARI `NA → Definitive`, serialized as JSON `null` native value), `fallback` (NDD GeneHub any-other-tier → Limited; a named "Unclassified/other" rule), `all_values` (radboudumc → Definitive for any input), `passthrough` (SysNDD/OMIM/Orphanet identity). PanelApp rows carry native labels Green/Amber/Red alongside `3/2/1` (the color↔number equivalence is external PanelApp semantics, surfaced only for human display).
  - `notes`: the "Red/1 is Limited, not Refuted" highlight and the "ungraded inclusion lists → implied Definitive for comparability, not a native category" caveat (radboudumc/OMIM/Orphanet).
- **Rationale for a declarative structure + guard test rather than a full data-driven rewrite of the `case_when`:** the executable `case_when` is proven by an existing test suite and has legitimate special cases (case-insensitive G2P, SFARI `NA`, NDD GeneHub and radboudumc catch-alls, identity passthrough for SysNDD/OMIM/Orphanet). Rewriting it to a join is higher-risk for zero product benefit. Instead the declarative crosswalk is the *display/serialization* source, and a **consistency guard test** drives `normalize_comparison_categories()` on a fixture derived from every crosswalk row **and its `rule_kind` semantics** (including `Unclassified`/arbitrary NDD GeneHub input, an arbitrary radboudumc value, mixed-case G2P, and SFARI `NA`) and asserts the stated normalized tier — so the display crosswalk can never drift from the executable normalizer, and an undocumented new normalizer branch is caught.

**Endpoints (`api/endpoints/comparisons_endpoints.R`):**
- `GET /api/comparisons/metadata` — add `mapping_version = COMPARISON_CATEGORY_MAPPING_VERSION` to **all three** return paths (missing-table fallback ~`:293`, empty-row fallback ~`:309`, populated row ~`:319`).
- **Frozen-export self-identification (satisfies #583 "API comparison output identifies the mapping version"):** add `mapping_version` to the **browse** response — the `generate_comparisons_list()` payload gains a `meta`/provenance field carrying `COMPARISON_CATEGORY_MAPPING_VERSION` — and to the **XLSX export** provenance (header row or metadata sheet) via `browseComparisonsXlsx`. A saved browse JSON or downloaded XLSX must prove which policy produced it, not just the live `/metadata`.
- New `GET /api/comparisons/crosswalk` — cheap, pure in-memory (no DB, no external), unauthenticated; returns `comparison_category_crosswalk()` verbatim. It lives in `comparisons_endpoints.R`, whose whole router is already mounted through `mount_endpoint()` (`api/bootstrap/mount_endpoints.R:131`), so it inherits the RFC 9457 error handler with no extra mount. Special native inputs are serialized explicitly (SFARI missing → JSON `null`; NDD GeneHub other → a named `fallback` rule) rather than ambiguous display strings.

**Stale duplicate normalizer (required cleanup):** `api/tests/testthat/test-unit-endpoint-functions.R:277-296` reimplements the `case_when` inline and only tests PanelApp `3`. It is a second, partial mapping description that will silently perpetuate the old policy; replace it with a call to the real `normalize_comparison_categories()` (or delete it), rather than leaving it as "no change needed".

**Non-goals (documented):**
- MCP `mcp_public_comparison` view (`db/migrations/044`) exposes the *raw* native category and is a pre-existing separate surface; it is **not** changed here. Documented as a known follow-up, not a regression this PR introduces.
- `db/11_Rcommands_sysndd_db_table_database_comparisons.R` (out-of-band db-prep) only copies the raw `GEL_Status` value and contains **no** PanelApp category mapping (confirmed) — nothing to synchronize; left unchanged.

### Component 2 — Snapshot generator provenance (`#585`, API + DB)

**Migration:** `db/migrations/046_add_analysis_snapshot_generator_provenance.sql` — additively adds `generator_json JSON NULL` to `analysis_snapshot_manifest`. Idempotent guard (information_schema check) consistent with existing migrations. Bump `api/functions/migration-manifest.R`: `EXPECTED_LATEST_MIGRATION <- "046_add_analysis_snapshot_generator_provenance.sql"`, `EXPECTED_MIGRATION_COUNT <- 44L`. **Also update the tests that assert the manifest baseline:** `test-unit-analysis-snapshot-migration.R:9`, `test-mcp-select-principal-projections.R:179`, `test-unit-core-views-manifest.R:13` (any that pin the latest migration / count).

**Constants:**
- `ANALYSIS_SNAPSHOT_BUILDER_VERSION <- "1.0"` and `ANALYSIS_GENERATOR_SCHEMA_VERSION <- "1.0"` (co-located with the builder/presets).
- Reuse the runtime commit resolver from `api/endpoints/version_endpoints.R:22-41` by extracting a shared helper `resolve_app_git_commit()` (env `GIT_COMMIT` → `git rev-parse --short HEAD` → `"unknown"`), used by both the version endpoint and the snapshot builder (DRY).

**Reproducible generator contract (concrete, not a placeholder):** the `generator` block is:
```
{
  generator_schema_version,          # ANALYSIS_GENERATOR_SCHEMA_VERSION
  application_version,               # version_json$version, e.g. "0.30.6"
  application_commit,                # resolve_app_git_commit(); may be "unknown" in dev
  snapshot_builder_version,          # ANALYSIS_SNAPSHOT_BUILDER_VERSION
  cluster_logic_version,             # CLUSTER_LOGIC_VERSION (clustering types only; NULL/omitted otherwise)
  generated_at,                      # ONE UTC ISO-8601 timestamp captured once (see below)
  algorithm: { name, params: {...} },# per-analysis-type (below)
  library_versions: { ... }          # fixed allowlist, resolved from installed packages
}
```
- **Per-analysis-type `algorithm.params`** (recorded from the actual clustering call, not re-derived):
  - `functional_clusters`: `{ weight_channel, min_confidence/score_threshold, leiden { resolution, beta, n_iterations, seed }, min_size, max_edges }` (source: `analyses-functions.R` around the Leiden call).
  - `phenotype_clusters`: `{ ncp, prevalence_min, prevalence_max, kk (= "Inf"), consol (TRUE), hcpc_nb_clust, supplementary_vars }` (source: `analysis-phenotype-functions.R`).
  - `phenotype_functional_correlations` / `network_edges`: the relevant preset params + the pinned functional/phenotype `snapshot_id`s already in `dependencies`.
- **`library_versions`**: a **fixed allowlist** resolver `analysis_generator_library_versions()` returning `packageVersion()` for the clustering-relevant packages (`igraph`, `leidenAlg`/`leiden`, `FactoMineR`, `factoextra`, `STRINGdb`, `data.table`, plus `R.version.string`). A missing/unavailable package degrades to `NA` for that key rather than erroring (mirrors `network_layout_package_versions()`).
- **Single-timestamp rule:** `generated_at` is captured **once** in UTC in the builder and the *same* value is written into `generator_json`; the manifest row's own `generated_at`/`NOW(6)` column is separate DB metadata — the provenance timestamp must not be re-derived from `NOW()` so the JSON and any comparison stay stable.

**Builder (`api/functions/analysis-snapshot-builder.R`):**
- Assemble the `generator` block above, persist it into `generator_json` on the manifest write. It is **not** added to any hashed payload key (not in the `payload` list hashed by `analysis_snapshot_payload_hash`, not in `input_hash`).
- **Validation gate:** `analysis_snapshot_assert_generator_complete(generator, analysis_type)` fails closed (`stop`) when a required key is missing/empty for a newly generated snapshot (`generator_schema_version`, `application_version`, `snapshot_builder_version`, `generated_at` required for all; `cluster_logic_version` required for clustering types; `application_commit` present but may equal `"unknown"`). Called before persist.

**Read/meta surface (`api/services/analysis-snapshot-service.R`):**
- `service_analysis_snapshot_meta()` adds `snapshot$generator` and `snapshot$generator_hash`.
- **Pre-046 tolerance (precise):** the existing `service_analysis_snapshot_parse_json_object()` returns an **empty list** (not `NULL`) for an absent/empty column (`service.R:401`). The meta code must therefore treat an empty/absent `generator_json` as **omitted** `generator` and `generator_hash = NULL` (do not emit `generator: {}`). `generator_hash` = SHA-256 over the stored `generator_json` string, mirroring `service_analysis_snapshot_validation_hash()` (returns `NULL` when the column is empty/absent). A direct pre-column fixture test covers this.

**Release layer (`api/functions/analysis-snapshot-release.R`) — per-layer, not singleton:**
- The release keeps its existing `generator` block (`release.R:~414-422`) describing the **release-packaging program** unchanged.
- Each pinned snapshot's own `generator` is recorded **per layer** under `source.snapshots[]` (alongside the existing `{analysis_type, snapshot_id, parameter_hash}`, `release.R:~423-432`), because the three layers can come from different snapshot builds — a singleton copy would be semantically wrong. Both `generator` and `source` are already excluded from `content_digest` (`release-manifest.R:155-172`) → `release_id` unchanged.
- **Immutability note:** a published release is immutable and the build early-returns idempotently on identical content (`release.R:377`), so a provenance-only snapshot refresh does **not** retrofit an existing release; new releases capture the current per-layer provenance. This is consistent with the #573 immutability contract and is stated, not worked around. A release test asserts distinct per-layer generator values survive into `source.snapshots[]`.

**Docs deliverable (acceptance):** the manifest/provenance docs (AGENTS.md + `documentation/09-deployment.qmd`) distinguish: the **complete partition** (all clusters incl. sub-`min_size`, from the reproducibility bundle), the **display-filtered communities** (visible clusters ≥ `min_size` in the payload), and the **associated graph/node universe** (functional LCC vs full node set; phenotype MCA entity set).

### Component 3 — Curation Comparisons tier-mapping help (`#586`, frontend)

**New typed client (`app/src/api/comparisons.ts`):** `getComparisonsCrosswalk(): Promise<ComparisonsCrosswalk>` + `ComparisonsCrosswalk` type mirroring the endpoint (`mapping_version`, `tiers[]`, `sources[]`, `notes`). Add `mapping_version` to `ComparisonsMetadata`.

**New reusable component `app/src/components/analyses/EvidenceTierMappingHelp.vue`** (mirrors `CurationSourcesPopover.vue`):
- Renders an `InlineHelpBadge` (a real `<button>`, keyboard-focusable, `aria-label="Explain normalized evidence-tier mapping"`) with a distinct id, plus a sibling `BPopover target=<id> variant="info"`.
- **Keyboard-accessible popover pattern (not focus-only):** because the popover contains an interactive link, a `triggers="focus"`/`"focus hover"` popover would dismiss when focus moves from the badge toward the link, so the link is unreachable by keyboard (a latent gap in the sibling `CurationSourcesPopover.vue`). Use a **click/keyboard toggle** — badge activation (Enter/Space/click) opens the popover, focus can move into it, the "complete crosswalk" link is reachable by Tab, and **Escape** dismisses it (`triggers="click"` with `:hover` for mouse convenience only). This is verified by an **interaction test**, not just a static attribute check.
- On mount, fetches `getComparisonsCrosswalk()`; the popover is **concise** — the four-tier scale one-liner, the "PanelApp Red/1 = Limited, not Refuted" highlight, the "ungraded inclusion lists → implied Definitive for comparability" caveat, and the `mapping_version` label — all API-sourced.
- **Fetch-failure fallback shows a neutral "Mapping information is unavailable" message and NO tier/PanelApp text.** Restating the mapping locally would contradict the no-drift guarantee; on failure the component must not assert any mapping facts of its own.

**Placement (`app/src/components/analyses/AnalysesCurationUpset.vue`):** insert `<EvidenceTierMappingHelp />` immediately after the existing `Overlap` `<h2>` help badge (the default `/CurationComparisons` view), so the affordance is "immediately after the Overlap control/label."

**Link to the complete versioned mapping table:** the concise popover includes a link to the **complete versioned crosswalk**. The authoritative, self-contained, drift-proof target is the `GET /api/comparisons/crosswalk` endpoint itself (a complete mapping table carrying `mapping_version`). The link's `href` is built from the app's configured Axios base URL (`app/src/plugins/axios.ts`), handling a relative base, and opens in a new tab with a safe `rel` (`noopener noreferrer`). This keeps the "complete versioned mapping table" inside this repo/PR — no dependency on editing the external bookdown docs. Tests assert the link's `href` resolves to the `/comparisons/crosswalk` path.

**Tests (`app/src/components/analyses/EvidenceTierMappingHelp.spec.ts`):** badge renders with the accessible name and no navigational `href` on the badge itself; popover content renders the tiers from a mocked crosswalk; the "Full mapping crosswalk" link has the expected target. Mirror `InlineHelpBadge.spec.ts` + `AnalysesCurationUpset.spec.ts` + a link-target assertion pattern.

## Data flow

- **#583:** raw `ndd_database_comparison` → `normalize_comparison_categories()` (read-time) → `/comparisons/browse|upset`. The declarative `comparison_category_crosswalk()` → `/comparisons/crosswalk` → frontend popover. `COMPARISON_CATEGORY_MAPPING_VERSION` → `/comparisons/metadata` + `/crosswalk`.
- **#585:** builder computes `generator` → `generator_json` (manifest) → `service_analysis_snapshot_meta()` → `meta.snapshot.generator` + `generator_hash` on `/api/analysis/*`. Release build copies it into manifest.json `generator`.
- **#586:** `/comparisons/crosswalk` → `EvidenceTierMappingHelp.vue` → popover on `/CurationComparisons`.

## Error handling

- `/comparisons/crosswalk` is pure/in-memory (no DB, no external), cannot fail on data. It inherits the RFC 9457 problem+json error handler because the whole `comparisons_endpoints.R` router is already mounted via `mount_endpoint()` (`api/bootstrap/mount_endpoints.R:131`) — no extra mount. It makes no external calls, so no `external_proxy_budget()` wrapper is needed. **The existing cheap-route isolation guard (`test-unit-cheap-route-isolation.R`) is scoped to `/health`, `/auth`, `/statistics` only** — this design does NOT claim that guard covers `/comparisons/*`; it simply keeps the route external-call-free by construction.
- Snapshot read tolerates pre-046 manifests: an empty/absent `generator_json` (the parser returns an empty list) → `generator` omitted and `generator_hash = NULL`, via the existing safe accessors.
- Provenance completeness gate fails the *build* (new snapshot) loudly rather than persisting an incomplete generator block; existing public-ready snapshots are untouched.
- Frontend popover fetch failure → a neutral "Mapping information is unavailable" message (no local tier restatement); badge and accessibility unaffected.

## Testing strategy

- **API #583:** update `test-unit-category-normalization.R` (PanelApp `2→Moderate`, `1→Limited`; add an explicit lock that G2P `disputed`/`refuted → Refuted` so the asymmetry is pinned); replace/remove the stale inline duplicate in `test-unit-endpoint-functions.R:277-296`; new `test-unit-comparisons-crosswalk.R` asserting (a) crosswalk↔normalizer consistency driven by every row's `rule_kind` (incl. `Unclassified`/arbitrary NDD GeneHub, arbitrary radboudumc, mixed-case G2P, SFARI `NA`), (b) `mapping_version` presence and match to the constant, (c) endpoint/`comparison_category_crosswalk()` shape, (d) `mapping_version` present on the browse `meta`.
- **API #585:** extend `test-unit-analysis-snapshot-provenance.R` for the `generator` block + `generator_hash` + the pre-046 empty-`generator_json` → omitted-generator/`NULL`-hash fixture; a builder test that the completeness gate rejects an incomplete generator and that adding provenance does not change `payload_hash`/`input_hash`; a `generator_json` serialization round-trip test; a release test asserting distinct per-layer generators survive into `source.snapshots[]`; update the migration-baseline assertions (`test-unit-analysis-snapshot-migration.R`, `test-mcp-select-principal-projections.R`, `test-unit-core-views-manifest.R`). `test-unit-analysis-cache-fingerprint.R` stays green (`CLUSTER_LOGIC_VERSION` unchanged).
- **Frontend #586:** `EvidenceTierMappingHelp.spec.ts` — badge accessible name + no navigational `href` on the badge; popover renders tiers from a mocked crosswalk; **keyboard interaction** (activate badge → Tab reaches the "complete crosswalk" link → link has the crosswalk `href`; Escape dismisses); fetch-failure renders the neutral message with no tier text. An `AnalysesCurationUpset.spec.ts` assertion that the component mounts after the Overlap label. Optionally an MSW/typed-client test for `getComparisonsCrosswalk()`.
- **Gates:** `make code-quality-audit`, `make test-api-fast` (or targeted `test_file`), `make lint-api`, `cd app && npm run lint && npm run type-check && npm run test:unit`.

## Deployment / release notes

- **#583:** read-time mapping → **API restart** applies it; no comparisons refresh, no worker restart. Downstream frozen comparisons distinguish policy by `mapping_version` (carried on the browse `meta` and the XLSX export, not only the live `/metadata`). CHANGELOG `[Unreleased]` entry + AGENTS.md "Curation-comparison sources & refresh" note the PanelApp ordinal correction (both Amber and Red changed) and the new `mapping_version`/`/crosswalk`.
- **#585:** additive; existing snapshots serve unchanged (no `generator` until refreshed). Migration `046` runs at startup; manifest constants bumped. No `CLUSTER_LOGIC_VERSION` bump, no LLM regeneration. **A provenance backfill is optional, not required; if performed it must restart the worker AND `worker-maintenance` first** (the builder is worker-executed code) before `POST /api/admin/analysis/snapshots/refresh?...&force=true`. Because a forced cluster refresh mints a new `snapshot_id`, the `phenotype_functional_correlations` snapshot must then be force-refreshed too (its #571/#572 dependency gate pins the phenotype `snapshot_id`+`payload_hash`, else public correlation reads return `dependency_snapshot_mismatch`).
- **#586:** ships with #583 so UI/API/downstream share one mapping policy.

## Out of scope / non-goals

- #584 ZNF41 adjudication (owner-handled, curation workflow).
- Normalizing the MCP comparison projection (`mcp_public_comparison`) — documented follow-up.
- Any change to clustering membership, `cluster_hash`, LLM summaries, or `CLUSTER_LOGIC_VERSION`.
- A full data-driven rewrite of the `normalize_comparison_categories()` `case_when`.
