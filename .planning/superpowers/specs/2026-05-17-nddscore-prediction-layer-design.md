# NDDScore Prediction Layer — Design

**Date:** 2026-05-17
**Status:** Approved for planning
**Author:** brainstorming session

## 1. Purpose

Add a public, clearly-labelled machine-learning prediction layer ("NDDScore") to
SysNDD, sourced from a published Zenodo dataset. NDDScore must be visibly and
textually separated from the manually curated SysNDD evidence database:

- Curated SysNDD evidence remains the authoritative, manually curated content.
- NDDScore is a model-derived prediction layer for prioritization.
- NDDScore must **not** be presented as an evidence tier, curation status, or
  manual review.

The feature ships a public browsing UI + API and an Administrator-only,
production-safe import/update flow that ingests new Zenodo releases.

## 2. Scope

**In scope**

1. Production-safe DB migration for NDDScore release + prediction tables.
2. Public NDDScore REST API (active release only by default).
3. Administrator-only NDDScore import/update API + durable async job.
4. Public `/NDDScore` UI with strong ML-vs-curation separation.
5. Administrator `/ManageNDDScore` UI to check, validate, import, and activate
   the latest public Zenodo dataset.
6. Tests and documentation updates matching repository conventions.

**Out of scope (explicit, deferred to follow-up specs)**

- The optional compact NDDScore card on existing gene/entity detail pages.
- MCP server exposure of NDDScore data.

## 3. Public Dataset (verified)

- Zenodo record: <https://zenodo.org/records/20258027>
- Version DOI: `10.5281/zenodo.20258027` — Concept DOI: `10.5281/zenodo.20258026`
- API record: <https://zenodo.org/api/records/20258027>
- Archive: `nddscore_sysndd_prediction_release_2026-05-17.tar.gz`
  - 7,568,944 bytes, `md5:7b7d2b397ca80a4e8d437b9696bef049` (verified by download).
- Archive download is resolved at runtime from the Zenodo API
  `files[].links.self` content link by matching the archive filename — no
  hardcoded content URL.

Verified release contents (`sysndd_prediction_release/nddscore_release.json`):

- `release_id`: `nddscore_20260517_public`
- `score_schema_version`: `1.0.0`, `n_genes`: 19296, `n_hpo_predictions`: 44360,
  `n_hpo_terms`: 37, `n_features`: 48, `hpo_threshold`: 0.5
- TSV row counts confirmed: gene 19296, hpo 44360, terms 37.
- Performance metrics live at `ndd_performance_json.test.{auc_roc,auc_pr,brier,bss}`.

The archive ships its own `nddscore_schema.sql` (used as the DDL base), an inner
`checksums.sha256`, `MODEL_CARD.md`, `SCHEMA.md`, and `datapackage.json`.

The TSV files are used for import (small; normal `readr`/DBI import). Parquet
files are ignored. The private NDDScore source-code repository is never
referenced; no local/private paths, tokens, or `.env` content enter SysNDD.

## 4. Database — migration `021_add_nddscore_prediction_release.sql`

Four tables, additive migration applied at API startup by the existing migration
runner. DDL is based on the dataset's shipped `nddscore_schema.sql` with two
deliberate deviations:

- **Collation:** `utf8mb4_unicode_ci` (SysNDD repo convention, per migration 020),
  not the dataset's `utf8mb4_0900_ai_ci`.
- **`nddscore_release` is a superset:** dataset provenance columns **plus**
  SysNDD operational columns.

### 4.1 `nddscore_release`

One row per imported release. Columns:

- Dataset provenance: `release_id` (PK), `score_schema_version`, `version`,
  `release_created_at` (the upstream `created_at` from `nddscore_release.json`),
  `n_genes`, `n_hpo_predictions`, `n_hpo_terms`, `n_features`, `hpo_threshold`,
  `calibration_method`, `ndd_model_created_at`, `phenotype_model_created_at`,
  `inheritance_model_created_at`, `ndd_performance_json`,
  `phenotype_performance_json`, `inheritance_performance_json`,
  `data_versions_json`, `artifact_hashes_json`.
- Source/provenance: `zenodo_record_url`, `version_doi`, `concept_doi`,
  `source_record_id`, `source_archive_name`, `source_archive_checksum`,
  `source_archive_bytes`.
- Operational: `is_active` (TINYINT, SysNDD-controlled — see below),
  `import_status`
  ENUM(`pending`,`importing`,`validated`,`active`,`superseded`,`failed`),
  `imported_by` (FK → `user.user_id`), `import_job_id`,
  `import_started_at`, `import_completed_at`, `activated_at`,
  `last_error_message`, `created_at` (row), `updated_at` (row).

`is_active` is **SysNDD operational state, not dataset provenance**. The
upstream `nddscore_release.json` carries its own `is_active` field; the importer
**ignores it** and always inserts new releases with `is_active = 0`. Activation
is performed only by SysNDD's atomic activation step (§5.3).

`import_status` is a **lifecycle** field, distinct from `is_active`:
`pending → importing → validated → active` on success, `→ failed` on error.
When a newer release is activated, the previously active release transitions
`active → superseded` inside the same atomic transaction. "Is this release
currently served" is answered solely by `is_active`.

- Keys: PK `release_id`. A STORED generated column
  `active_release_slot = CASE WHEN is_active = 1 THEN 1 ELSE NULL END` with a
  `UNIQUE KEY` on it enforces **at most one active release at the schema level**
  (same pattern as `async_jobs.active_request_hash` in migration 020), so the
  `*_current` views can never return duplicate rows. KEY on `import_status`.

JSON metric columns store the upstream JSON verbatim. `version` is the Zenodo
record version string (e.g. `2026.05.17`).

### 4.2 `nddscore_gene_prediction`

One row per HGNC gene per release. PK `(release_id, hgnc_id)`, FK
`release_id` → `nddscore_release` ON DELETE CASCADE. Columns exactly as the brief
/ dataset schema (`gene_symbol`, `ensembl_gene_id`, `ndd_score`, `ndd_score_std`,
`ndd_score_iqr`, `bag_agreement`, `rank`, `percentile`, `risk_tier`,
`confidence_tier`, `known_sysndd_gene`, `model_split`, four
`inheritance_*_probability`, `top_inheritance_mode`, `called_inheritance_modes`
JSON, `n_predicted_hpo`, `top_hpo_predictions_json` JSON, six `shap_*`,
`dominant_shap_group`, `top_features_json` JSON, `prediction_note`).

### 4.3 `nddscore_hpo_prediction`

One row per predicted gene-HPO association. PK
`(release_id, hgnc_id, phenotype_id)`, FK `(release_id, hgnc_id)` →
`nddscore_gene_prediction` ON DELETE CASCADE. Columns: `gene_symbol`,
`phenotype_id`, `phenotype_name`, `probability`, `rank_for_gene`,
`passes_default_threshold`, `term_auc_roc`, `term_auc_pr`,
`term_training_support`.

### 4.4 `nddscore_hpo_term`

One row per HPO term per release. PK `(release_id, phenotype_id)`, FK
`release_id` → `nddscore_release` ON DELETE CASCADE. Columns: `phenotype_name`,
`term_auc_roc`, `term_auc_pr`, `term_training_support`, `is_in_ndd_subtree`.

### 4.5 Indexes and views

Indexes: `nddscore_gene_prediction(release_id, hgnc_id)` [PK],
`(release_id, gene_symbol)`, `(release_id, rank)`, `(release_id, risk_tier)`,
`(release_id, confidence_tier)`; `nddscore_hpo_prediction(release_id, hgnc_id)`
[PK prefix], `(release_id, phenotype_id)`, `(release_id, probability)`.

Views: `nddscore_gene_prediction_current`, `nddscore_hpo_prediction_current`,
`nddscore_hpo_term_current` — each `JOIN nddscore_release ON is_active = 1`.

### 4.6 Retention

All imported releases are **retained** (history). Only `is_active` flips between
releases. No auto-pruning; a pruning action can be added in a later spec.

## 5. Backend — R API

### 5.1 Repository — `api/functions/nddscore-repository.R`

Read-only, parametrized queries. Serves the active release by default (resolve
active `release_id` once, or query the `*_current` views). All sort and filter
inputs validated against a **whitelist** of column names; no string
interpolation of untrusted values into SQL. `DBI::dbBind()` with `?`
placeholders and `unname()`-ed params.

### 5.2 Importer — `api/functions/nddscore-import.R`

Pure, unit-testable functions:

- `nddscore_fetch_zenodo_metadata(record_id)` — fetch Zenodo API JSON, locate
  the archive file entry by filename, return name/size/checksum/`links.self`.
- `nddscore_download_archive(url, dest)` — download to a temp dir.
- `nddscore_verify_archive_checksum(path, expected_md5)` — verify Zenodo MD5.
- `nddscore_extract_and_verify(path)` — extract to temp dir, verify the bundled
  `checksums.sha256` for every release file.
- `nddscore_parse_release_json(dir)` — parse `nddscore_release.json`.
- `nddscore_load_tsvs(dir)` — load the three TSVs via `readr` into data frames.
- `nddscore_validate(release, frames)` — schema/required-column checks,
  row-count checks against `n_genes` / `n_hpo_predictions` / `n_hpo_terms`,
  JSON-validity checks for JSON columns, orphan-row checks (every HPO prediction
  `hgnc_id` exists in gene predictions; every term referenced exists).

No secrets, env vars, DB passwords, or tokens are ever logged.

### 5.3 Async job — durable, System B

New durable job type `nddscore_import` registered in the
`async_job_handler_registry` in `api/functions/async-job-handlers.R`, alongside
the existing gene-clustering handler. Runs in the **worker container** (which has
outbound network egress). Job payload: `record_id`, `validate_only` (boolean).

**Concurrency protection.** The `async_jobs` active-request-hash unique
constraint is *not sufficient* on its own: that hash is `job_type +
payload_json`, so a `validate_only = true` job, a `validate_only = false` job,
or two different `record_id`s produce different hashes and would not collide. A
dedicated lock is therefore required. The handler acquires a **named MySQL
advisory lock** (`GET_LOCK('nddscore_import', ...)`, the same lock mechanism the
migration runner already uses) at the start of execution and releases it at the
end. A second `nddscore_import` job that cannot acquire the lock fails fast with
a clear "another NDDScore import is already running" error. The advisory lock
covers `validate_only` jobs too — they are short, and serializing them keeps the
behavior simple and predictable.

Handler steps (production-safe ordering):

1. Fetch Zenodo metadata; locate archive by filename.
2. Download archive to a temp dir; verify Zenodo MD5.
3. Extract; verify bundled `checksums.sha256`.
4. Parse `nddscore_release.json`; load TSVs.
5. Validate schema, row counts, JSON validity, orphan rows.
6. If `validate_only = true`: stop here, return a validation-only result, write
   **nothing** to prediction tables.
7. **Active-release guard:** if a row with this `release_id` already exists and
   `is_active = 1`, refuse the import with a clear error — re-importing the
   currently active release would require deleting its live prediction rows and
   would break the "current release keeps serving" guarantee. (A future forced
   replace would stage into temp tables or a fresh release ID; out of scope
   here.) If the `release_id` exists but is **inactive** (a prior `failed`
   attempt), delete only that inactive release's prediction rows and continue.
8. Upsert an **inactive** `nddscore_release` row (`is_active = 0`,
   `import_status = importing`).
9. Insert gene, HPO term, and HPO prediction rows for this `release_id` while it
   is still inactive — the current active release keeps serving throughout.
10. Re-validate row counts from the DB; mark the release `validated`.
11. **Atomic activation** (single transaction): transition the previously active
    release to `is_active = 0` / `import_status = superseded`, and the new
    release to `is_active = 1` / `import_status = active` / `activated_at = now`;
    commit together. The `active_release_slot` unique key guarantees the switch
    cannot leave two active releases.
12. On any failure: mark the new release `failed` with `last_error_message`,
    leave the previous active release active and serving.

Job result JSON: release ID, version DOI, concept DOI, record URL, archive
filename, archive checksum, gene rows loaded, HPO prediction rows loaded, HPO
term rows loaded, whether the release was activated.

### 5.4 Public endpoints — `api/endpoints/nddscore_endpoints.R`

- `GET /api/nddscore/release/current` — active release metadata + performance.
- `GET /api/nddscore/genes` — paginated/sortable/filterable gene predictions.
- `GET /api/nddscore/genes/<hgnc_id_or_symbol>` — single-gene detail (joins
  curated SysNDD gene/entity data for display context only).
- `GET /api/nddscore/hpo` — paginated phenotype predictions.
- `GET /api/nddscore/terms` — HPO term metadata.
- `GET /api/nddscore/download/info` — DOIs, record URL, archive name/checksum.

All read the active release by default. Pagination + whitelisted sort/filter.
Joins to curated SysNDD tables are display-only; curated data is never
reclassified by NDDScore.

### 5.5 Admin endpoints — added to `api/endpoints/admin_endpoints.R`

- `GET  /api/admin/nddscore/status` — active release, last import status/error,
  imported counts, recent `nddscore_import` jobs.
- `GET  /api/admin/nddscore/zenodo` — current Zenodo metadata, compared to the
  active release.
- `POST /api/admin/nddscore/import` — submit the `nddscore_import` async job
  (accepts `validate_only`).

Administrator role enforced on **both** the route filter and the handler — not
frontend-only.

## 6. Frontend — Vue 3

### 6.1 Navigation

- New **top-level dropdown** `NDDScore` in
  `app/src/assets/js/constants/main_nav_constants.ts` `DROPDOWN_ITEMS_LEFT`,
  positioned **between `Analyses` and `Help`**,
  `required: ['']` (public). Items: `Gene predictions` → `/NDDScore`,
  `Phenotype predictions` → `/NDDScore/PhenotypePredictions`, `Model card` →
  `/NDDScore/ModelCard`. A distinctive icon (`cpu`) marks it as the ML layer.
  Rationale: the navbar has no standalone links — every top entry is a dropdown;
  a peer dropdown gives NDDScore prominence and visual separation from curated
  content.
- `Manage NDDScore` → `/ManageNDDScore` added to the `Administration` dropdown,
  icons `['gear', 'graph-up-arrow']`.

### 6.2 Routes — `app/src/router/routes.ts`

- `/NDDScore` — public, `component: views/nddscore/NDDScore.vue`, with explicit
  child routes, mirroring the `/PhenotypeCorrelations` children pattern:
  - index (empty path) → `Gene predictions` tab
  - `PhenotypePredictions` → `/NDDScore/PhenotypePredictions`
  - `ModelCard` → `/NDDScore/ModelCard`
  - `Gene/:hgncIdOrSymbol` → `/NDDScore/Gene/<id>` for the gene-detail view.
    Defining gene detail as its own parametrized segment avoids any path
    collision with the static `PhenotypePredictions` / `ModelCard` segments. It
    is reached by clicking a gene row, not from the nav dropdown.
- `/ManageNDDScore` — `component: views/admin/ManageNDDScore.vue`,
  `beforeEnter: createAuthGuard(['Administrator'])`.

### 6.3 Public page — `views/nddscore/NDDScore.vue`

Uses `AnalysisShell` (title `NDDScore`, subtitle: *"Machine-learning predictions
for NDD gene association and phenotype annotations. These predictions are
separate from curated SysNDD evidence."*). Route-driven tabs. The `meta` slot
carries the ML indicator badge on every tab.

A prominent **`NddScorePredictionCard`** (new component, modeled on
`LlmSummaryCard` but visually distinct) sits at the top of the page:

- Header indicator: `bi-cpu` icon + label **"ML prediction"** (deliberately not
  `bi-stars`/"AI", so it reads as a separate layer).
- Body: the mandated disclaimer — *"NDDScore is a model-derived prediction
  layer. It is not curated SysNDD evidence, not a manual review, and not an
  evidence-tier assignment."* — plus an inline performance strip (Test AUC-ROC,
  Brier Skill Score) and the release ID + version DOI link.
- This component is the reusable unit for the later gene/entity-page card.

Tabs:

1. **Gene predictions** — table built from the **same components as `/Entities`**
   (`TableShell` + `TableSearchInput` + `TableDownloadLinkCopyButtons` + filter
   row + sortable headers + numbered pagination). Columns: gene, HGNC ID, NDD
   score, rank, percentile, risk tier, confidence tier, known SysNDD gene, top
   inheritance mode, predicted HPO count. Risk/confidence tiers render as colored
   pill badges; `known_sysndd_gene` is a badge linking to the curated gene page.
   Filters: search, risk tier, confidence tier, known SysNDD gene.
2. **Gene detail** — NDD score + rank, risk/confidence tier, inheritance
   probabilities, top predicted HPO terms, SHAP group contributions, link to the
   curated SysNDD gene/entity pages. Curated evidence kept in a visually distinct
   block from predictions.
3. **Phenotype predictions** — `/Entities`-style table of gene-HPO associations.
   Filters: gene, phenotype, threshold/pass flag, probability. Shows term-level
   AUC/support.
4. **Model card** — a `BCard` styled like the cluster summary card: header = ML
   indicator + release-ID badge; body = a performance metrics grid (AUC-ROC,
   AUC-PR, Brier, BSS from `ndd_performance_json.test`), counts (genes / HPO
   predictions / HPO terms / features), version + concept DOI + Zenodo link, and
   intended-use / limitations summarized from the public `MODEL_CARD.md`.

### 6.4 Admin page — `views/admin/ManageNDDScore.vue`

Reuses `AdminOperationPanel`, `useAsyncJob`, and `GET /api/jobs/<job_id>/status`
polling (same pattern as `ManageLLM` / `ManagePubtator`).

Displays: current active release ID; version DOI + Zenodo record URL; concept
DOI; archive filename + checksum; import/activation timestamp; imported row
counts; model performance summary from `ndd_performance_json.test`; last import
status + last error; recent NDDScore update jobs.

Actions:

- **Check Zenodo** — fetch current Zenodo metadata, show file name/checksum/size,
  DOIs, record URL, compared to the active release.
- **Download & validate** — start the `nddscore_import` job with
  `validate_only = true` (downloads + verifies + validates, activates nothing).
- **Import & activate latest release** — start the `nddscore_import` job; behind
  an explicit confirmation modal that states the previous active release remains
  active until activation succeeds.

### 6.5 API clients

- `app/src/api/nddscore.ts` — public endpoints.
- `app/src/api/nddscore_admin.ts` — admin endpoints.

Plumber JSON scalars may arrive as arrays; values are unwrapped before being fed
back into axios params.

## 7. Copy Rules

Use: `ML prediction`, `Model-derived`, `Prediction layer`, `Separate from
curated SysNDD evidence`, `Not an evidence tier`. Never: `curated NDDScore`,
`validated by SysNDD`, `evidence tier`, `manual review`, `curated gene status`.
A high score is described as a prioritization signal, never as proof of disease
causality.

## 8. Testing (TDD for importer + API)

A small **fixture archive** (a trimmed `.tar.gz` with a handful of genes and a
matching `nddscore_release.json` / `checksums.sha256`) is committed under the API
test fixtures. Tests cover:

- migration / table creation
- active-release selection
- importer schema validation against the fixture
- checksum-failure behavior (bad MD5 / bad `checksums.sha256`)
- failed import leaves the previous active release active
- successful import switches the active release only at the final step
- re-importing the currently active `release_id` is refused (active-release
  guard); re-importing a previously *failed* inactive `release_id` succeeds
- the schema enforces at most one active release (`active_release_slot` unique
  key rejects a second `is_active = 1` row)
- after activation the previously active release is `is_active = 0` /
  `import_status = superseded` (unambiguous lifecycle state)
- concurrent NDDScore imports are blocked even with non-identical payloads
  (advisory lock), including a `validate_only` job vs. an import job
- `validate_only` writes nothing to prediction tables
- public current-release endpoint
- gene list / search / filter endpoint
- gene detail endpoint
- admin status endpoint
- admin import job submission endpoint
- frontend public route + nav item present
- admin route / nav item requires Administrator role
- public page disclaimer text distinguishes ML prediction from curated evidence
- admin page confirmation before import / activation

Zenodo is mocked in all normal tests — no network-dependent tests. Existing test
utilities and fixtures are reused.

## 9. Documentation

Per the repo Documentation Contract, update in the same change:

- `AGENTS.md` — NDDScore tables, import job, and the ML-vs-curated invariant.
- `documentation/08-development.qmd` — local workflow for the import job.
- `documentation/09-deployment.qmd` — operator guidance for running NDDScore
  updates in production (admin UI flow, worker egress requirement).
- `db/migrations/README.md` — note migration 021 if conventions require it.

## 10. Verification

`make pre-commit`, `make test-api`, `make lint-api`, `make lint-app`,
`cd app && npm run type-check`, `cd app && npm run test:unit`; `make ci-local`
before final handoff.

## 11. Open Questions

None. All design decisions resolved during brainstorming and peer review:

- Old releases retained (history); no auto-pruning.
- `validate_only` dry-run stage included on the single job handler.
- MCP exposure out of scope.
- Top-level `NDDScore` dropdown (not an item inside `Analyses`).
- Durable MySQL-backed async job (System B), not `job-manager.R`.
- `is_active` is SysNDD-controlled; upstream `is_active` is ignored.
- `import_status` is lifecycle-only with a `superseded` terminal state.
- Single-active-release enforced at the schema level via a generated column +
  unique key.
- Concurrent imports serialized by a named MySQL advisory lock, not by the
  async-job request hash.
- Re-importing the active `release_id` is refused; gene detail is a
  parametrized child route.
