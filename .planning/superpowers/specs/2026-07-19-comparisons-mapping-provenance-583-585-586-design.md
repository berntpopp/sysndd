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
- **Version constant:** add `COMPARISON_CATEGORY_MAPPING_VERSION <- "2026-07-19.583-panelapp-ordinal"` (date-tagged policy id). This is the single identifier surfaced to consumers.
- **Declarative crosswalk (single display source of truth):** add `comparison_category_crosswalk()` returning a structured object:
  - `mapping_version`
  - `tiers`: the ordered normalized four-tier vocabulary with short definitions (`Definitive`, `Moderate`, `Limited`, `Refuted`) plus the non-tier fillers (`not applicable`, `not listed`) documented separately.
  - `sources[]`: per source, the native scale → normalized-tier rows (e.g. PanelApp `Green/3→Definitive`, `Amber/2→Moderate`, `Red/1→Limited`; G2P strong/definitive→Definitive, moderate→Moderate, limited→Limited, disputed/refuted→Refuted; SFARI 1/2/3; NDD GeneHub tiers; radboudumc/OMIM/Orphanet as *implied Definitive for ungraded inclusion lists*), each with a one-line note.
  - `notes`: the "Red is not Refuted" highlight and the "ungraded inclusion lists → implied Definitive for comparability, not a native category" caveat.
- **Rationale for a declarative structure + guard test rather than a full data-driven rewrite of the `case_when`:** the executable `case_when` is proven by an existing test suite and has legitimate special cases (case-insensitive G2P, SFARI `NA`, NDD GeneHub and radboudumc catch-alls, identity passthrough for SysNDD/OMIM/Orphanet). Rewriting it to a join is higher-risk for zero product benefit. Instead the declarative crosswalk is the *display/serialization* source, and a **consistency guard test** asserts that for every crosswalk row `(list, native_value)`, `normalize_comparison_categories()` yields the stated normalized tier — so the two can never drift.

**Endpoints (`api/endpoints/comparisons_endpoints.R`):**
- `GET /api/comparisons/metadata` — add `mapping_version = COMPARISON_CATEGORY_MAPPING_VERSION` to the returned list (both the populated and the empty-table fallback branches).
- New `GET /api/comparisons/crosswalk` — cheap, DB-free, unauthenticated; returns `comparison_category_crosswalk()` verbatim. Mounted through the existing `mount_endpoint()` helper so it inherits the RFC 9457 error handler.

**Non-goals (documented):**
- MCP `mcp_public_comparison` view (`db/migrations/044`) exposes the *raw* native category and is a pre-existing separate surface; it is **not** changed here. Documented as a known follow-up, not a regression this PR introduces.
- `db/11_Rcommands_sysndd_db_table_database_comparisons.R` (out-of-band db-prep) is inspected; if it embeds a PanelApp category map it is updated to track the API, otherwise left unchanged with a note.

### Component 2 — Snapshot generator provenance (`#585`, API + DB)

**Migration:** `db/migrations/046_add_analysis_snapshot_generator_provenance.sql` — additively adds `generator_json JSON NULL` to `analysis_snapshot_manifest`. Idempotent guard (information_schema check) consistent with existing migrations. Bump `api/functions/migration-manifest.R`: `EXPECTED_LATEST_MIGRATION <- "046_add_analysis_snapshot_generator_provenance.sql"`, `EXPECTED_MIGRATION_COUNT <- 44L`.

**Constants:**
- `ANALYSIS_SNAPSHOT_BUILDER_VERSION <- "1.0"` and `GENERATOR_SCHEMA_VERSION <- "1.0"` (co-located with the builder/presets).
- Reuse the runtime commit resolver from `api/endpoints/version_endpoints.R:22-41` by extracting a shared helper `resolve_app_git_commit()` (env `GIT_COMMIT` → `git rev-parse --short HEAD` → `"unknown"`), used by both the version endpoint and the snapshot builder (DRY).

**Builder (`api/functions/analysis-snapshot-builder.R`):**
- Compute a `generator` provenance list: `{application_version (version_json$version), application_commit (resolve_app_git_commit()), cluster_logic_version (CLUSTER_LOGIC_VERSION), snapshot_builder_version, generator_schema_version, generated_at, algorithm{name, params}, library_versions{...}}`.
- Persist it into `generator_json` on the manifest write. It is **not** added to any hashed payload key.
- **Validation gate:** `analysis_snapshot_assert_generator_complete(generator)` fails closed (`stop`) when a required key is missing/empty for a newly generated snapshot (`application_version`, `cluster_logic_version`, `snapshot_builder_version`, `generator_schema_version`, `generated_at` required; `application_commit` present but may equal `"unknown"` in dev). Called before persist.

**Read/meta surface (`api/services/analysis-snapshot-service.R`):**
- `service_analysis_snapshot_meta()` adds `snapshot$generator` (parsed from `generator_json` via the existing safe accessor, `NULL` for pre-046 snapshots) and `snapshot$generator_hash` (SHA-256 over the stored `generator_json`, mirroring `service_analysis_snapshot_validation_hash()`), so clients can cache on and detect provenance changes without it entering `payload_hash`.

**Release layer (`api/functions/analysis-snapshot-release.R`):**
- Extend the manifest.json `generator` block (release.R ~414-422) with `application_version`, `application_commit`, `cluster_logic_version`, `snapshot_builder_version`. Excluded from `content_digest` → `release_id` unchanged.

**Docs deliverable (acceptance):** the manifest/provenance docs (AGENTS.md + `documentation/09-deployment.qmd`) distinguish: the **complete partition** (all clusters incl. sub-`min_size`, from the reproducibility bundle), the **display-filtered communities** (visible clusters ≥ `min_size` in the payload), and the **associated graph/node universe** (functional LCC vs full node set; phenotype MCA entity set).

### Component 3 — Curation Comparisons tier-mapping help (`#586`, frontend)

**New typed client (`app/src/api/comparisons.ts`):** `getComparisonsCrosswalk(): Promise<ComparisonsCrosswalk>` + `ComparisonsCrosswalk` type mirroring the endpoint (`mapping_version`, `tiers[]`, `sources[]`, `notes`). Add `mapping_version` to `ComparisonsMetadata`.

**New reusable component `app/src/components/analyses/EvidenceTierMappingHelp.vue`** (mirrors `CurationSourcesPopover.vue`):
- Renders an `InlineHelpBadge` (a real `<button>`, keyboard-focusable, `aria-label="Explain normalized evidence-tier mapping"`) with a distinct id, plus a sibling `BPopover target=<id> triggers="focus hover" variant="info"`.
- On mount, fetches `getComparisonsCrosswalk()`; the popover is **concise** — the four-tier scale one-liner, the "PanelApp Red/1 = Limited, not Refuted" highlight, the "ungraded inclusion lists → implied Definitive for comparability" caveat, and the `mapping_version` label — all API-sourced. Degrades gracefully to a concise static fallback if the fetch fails, but the visible tier text on success is API-sourced (no drift).

**Placement (`app/src/components/analyses/AnalysesCurationUpset.vue`):** insert `<EvidenceTierMappingHelp />` immediately after the existing `Overlap` `<h2>` help badge (the default `/CurationComparisons` view), so the affordance is "immediately after the Overlap control/label."

**Link to the complete versioned mapping table:** the concise popover includes a link to the **complete versioned crosswalk**. The authoritative, self-contained, drift-proof target is the `GET /api/comparisons/crosswalk` endpoint itself (a complete mapping table carrying `mapping_version`); the link opens it (absolute API URL built from the app's API base). This keeps the "complete versioned mapping table" inside this repo/PR — no dependency on editing the external bookdown docs. Tests assert the link's `href` resolves to the crosswalk endpoint path. (The endpoint is also referenced from AGENTS.md / `documentation/*` as the human-readable crosswalk authority.)

**Tests (`app/src/components/analyses/EvidenceTierMappingHelp.spec.ts`):** badge renders with the accessible name and no navigational `href` on the badge itself; popover content renders the tiers from a mocked crosswalk; the "Full mapping crosswalk" link has the expected target. Mirror `InlineHelpBadge.spec.ts` + `AnalysesCurationUpset.spec.ts` + a link-target assertion pattern.

## Data flow

- **#583:** raw `ndd_database_comparison` → `normalize_comparison_categories()` (read-time) → `/comparisons/browse|upset`. The declarative `comparison_category_crosswalk()` → `/comparisons/crosswalk` → frontend popover. `COMPARISON_CATEGORY_MAPPING_VERSION` → `/comparisons/metadata` + `/crosswalk`.
- **#585:** builder computes `generator` → `generator_json` (manifest) → `service_analysis_snapshot_meta()` → `meta.snapshot.generator` + `generator_hash` on `/api/analysis/*`. Release build copies it into manifest.json `generator`.
- **#586:** `/comparisons/crosswalk` → `EvidenceTierMappingHelp.vue` → popover on `/CurationComparisons`.

## Error handling

- `/comparisons/crosswalk` is pure/in-memory (no DB, no external), cannot fail on data; routed through `mount_endpoint()` for problem+json parity and covered by the cheap-route isolation guard (no external fetchers).
- Snapshot read tolerates pre-046 manifests (`generator_json` NULL → `generator` omitted, `generator_hash` NULL) via the existing safe column accessor.
- Provenance completeness gate fails the *build* (new snapshot) loudly rather than persisting an incomplete generator block; existing public-ready snapshots are untouched.
- Frontend popover fetch failure → concise static fallback text; badge and accessibility unaffected.

## Testing strategy

- **API #583:** update `test-unit-category-normalization.R` (PanelApp `2→Moderate`, `1→Limited`); add an explicit lock that G2P `disputed`/`refuted → Refuted`; new `test-unit-comparisons-crosswalk.R` asserting (a) crosswalk↔normalizer consistency for every row, (b) `mapping_version` presence, (c) endpoint shape. Note the stale inline duplicate in `test-unit-endpoint-functions.R:285-292` (only tests PanelApp `3`, no change needed).
- **API #585:** extend `test-unit-analysis-snapshot-provenance.R` for the `generator` block + `generator_hash`; a builder test that the completeness gate rejects an incomplete generator and that provenance does not enter `payload_hash`/`input_hash`; `test-unit-analysis-cache-fingerprint.R` unaffected (`CLUSTER_LOGIC_VERSION` unchanged); a serialization test for `generator_json` round-trip.
- **Frontend #586:** `EvidenceTierMappingHelp.spec.ts` (visibility, accessible name, mapping-link target); an `AnalysesCurationUpset.spec.ts` assertion that the component mounts after the Overlap label.
- **Gates:** `make code-quality-audit`, `make test-api-fast` (or targeted `test_file`), `make lint-api`, `cd app && npm run lint && npm run type-check && npm run test:unit`.

## Deployment / release notes

- **#583:** read-time mapping → **API restart** applies it; no comparisons refresh, no worker restart. Downstream frozen comparisons distinguish policy by `mapping_version`. CHANGELOG `[Unreleased]` entry + AGENTS.md "Curation-comparison sources & refresh" note the PanelApp ordinal correction (both Amber and Red changed) and the new `mapping_version`/`/crosswalk`.
- **#585:** additive; existing snapshots serve unchanged (no generator until refreshed). Optional (not required) forced snapshot refresh backfills provenance on the active rows. Migration `046` runs at startup; manifest constants bumped. No `CLUSTER_LOGIC_VERSION` bump, no LLM regeneration.
- **#586:** ships with #583 so UI/API/downstream share one mapping policy.

## Out of scope / non-goals

- #584 ZNF41 adjudication (owner-handled, curation workflow).
- Normalizing the MCP comparison projection (`mcp_public_comparison`) — documented follow-up.
- Any change to clustering membership, `cluster_hash`, LLM summaries, or `CLUSTER_LOGIC_VERSION`.
- A full data-driven rewrite of the `normalize_comparison_categories()` `case_when`.
