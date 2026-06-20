# Disease Cross-Ontology Mappings — Design Spec

- **Date:** 2026-06-20
- **Status:** Draft for review
- **Author:** brainstorming session (Bernt Popp + agent)
- **Topic:** Map SysNDD disease names/ids to external disease ontologies (MONDO, Orphanet, OMIM, DOID, UMLS, MedGen, NCIT, GARD, EFO) with a refreshable ingestion pipeline, admin controls, and frontend outlinks.

---

## 1. Goal

Every SysNDD entity is a `(gene, inheritance, disease, ndd_phenotype)` curation record whose disease is anchored on a single `disease_ontology_set` row (today almost always an OMIM id, occasionally a curated MONDO term). We want each disease to also carry **rich, provenance-tracked cross-references to other disease ontologies**, kept fresh from upstream releases, surfaced in the UI with **external outlinks** in two places:

1. The **Entities list** (`/Entities`) — progressive-disclosure "show details" per row.
2. The **Entity detail page** (`/Entities/:id`) — a dedicated "Linked disease ontologies" card.

Plus **operator controls** to refresh the mapping source regularly (admin endpoints + nightly/weekly cron + startup bootstrap), mirroring existing SysNDD refresh subsystems.

This is an **enhance-and-formalize** effort, not greenfield: the columns, a partial MONDO SSSOM importer, and an OBO xref extractor already exist but are sparse, unexposed, and not independently refreshable.

## 2. Current state (what already exists)

- **`disease_ontology_set`** (`db/migrations/000_initialize_base_schema.sql:34`) — PK `disease_ontology_id_version` (e.g. `OMIM:618524`, sometimes `OMIM:618524_1`); base `disease_ontology_id`; `disease_ontology_name`; and **already-present** denormalized xref columns `DOID`, `MONDO`, `Orphanet`, `EFO` (each `varchar(200)`, semicolon-joined). Charset `utf8mb3`.
- **Entity → disease link**: `ndd_entity.disease_ontology_id_version` → FK `disease_ontology_set.disease_ontology_id_version`.
- **`ndd_entity_view`** exposes only `disease_ontology_id_version` and `disease_ontology_name` (NOT the xref columns). It is fragile: its body must stay mirrored byte-for-byte between the latest `CREATE OR REPLACE VIEW` migration and `db/C_Rcommands_set-table-connections.R`.
- **`mondo-functions.R`** — downloads the **OMIM-only** SSSOM subset (`mondo_exactmatch_omim.sssom.tsv`), parses it, fills the `MONDO` column for `mim2gene` rows. Partial.
- **`ontology-functions.R` `get_mondo_mappings()`** — downloads MONDO OBO via `ontologyIndex`, extracts xrefs (OMIM/DOID/Orphanet/EFO/UMLS), caches a CSV. Runs only inside the big ontology-refresh job.
- **`/api/ontology/<input>`** (`ontology_endpoints.R`) — returns a `disease_ontology_set` row including the four xref columns.
- **Frontend**: `DiseaseBadge` (no outlinks), `ResourceLink` (card + compact badge with outlink, ideal), `OntologyView.vue` already contains hardcoded OMIM/MONDO/Orphanet/DOID URL templates. `EntityView.vue` has a half-wired `mondoEquivalent` shown as plain text. Cross-ref fields exist in the typed `OntologyTerm` but are unused on the entity page.

### Reference repo: `../mondo-link` (Python)

Materializes a **local MONDO index** from `mondo.obo` + `mondo.sssom.tsv` into SQLite: tables `term`, `xref` (merged OBO+SSSOM with `predicate`, `origin`, `source`, `object_label`), closure, FTS, and a single-row `meta` (release version, counts, validators). Key ideas we reuse:
- **MONDO is the hub**: resolve a disease's OMIM id → MONDO via SSSOM `exactMatch`/`equivalentTo`, then read MONDO's xrefs for Orphanet/DOID/UMLS/MedGen/NCIT/GARD/EFO.
- **Predicate ranking** (`exactMatch` < `equivalentTo` < `closeMatch` < `narrowMatch` < `broadMatch` < `xref`); strongest wins on collapse.
- **CURIE prefix normalization / aliases** (`ORPHANET`→`Orphanet`, `MIM`→`OMIM`, `SNOMEDCT`→`SCTID`, …).
- **Conditional-GET refresh** (ETag/Last-Modified): a no-change refresh is ~free. **Atomic rebuild**. **Provenance** (release version + counts) stored every build.
- `../orphanet-link` does **not** exist locally; Orphanet is obtained **through MONDO xrefs**, the standard approach (no separate Orphanet product download needed in v1).

## 3. Decisions

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| D1 | Data model | **Hybrid** (user-selected): normalized provenance-rich store + denormalized projection | Normalized store as app source of truth; projection columns for cheap reads/export. Mirrors the `pubtator_gene_summary` precompute+fallback pattern. |
| D2 | Ingestion | **Full local MONDO index, refreshed on a schedule** (recommended) | Hybrid needs `predicate`/`source`/`release_version` per mapping — only derivable from real OBO+SSSOM. Unlocks reverse lookup + hierarchy + future MCP. Reuses existing OBO/SSSOM download code. |
| D3 | Hub anchoring | **MONDO-as-hub** (settled best practice) | MONDO already curates xrefs to all targets; mapping each ontology independently would duplicate Monarch's curation. |
| D4 | Outlink scope | **MONDO, Orphanet, OMIM, DOID** first-class clickable; **MedGen, NCIT, GARD, EFO** clickable where stable; **UMLS** stored + shown as plain id (no clean public deep-link) | Covers the explicit ask (MONDO, Orphanet) plus the natural neighbors; one central URL-template module. |
| D5 | Entities list UX | **Expandable row detail** with lazy-fetched outlink strip | Keeps the dense list clean; mirrors the existing `EntitiesMobileRows` "Details" pattern and the `/pubtator/table` lazy-fetch-on-expand precedent. |
| D6 | `ndd_entity_view` | **Do NOT modify it**; frontend lazy-fetches mappings from a dedicated endpoint | Avoids the byte-for-byte view-mirror risk; decouples frontend from the fragile view. Exposing projection columns in the view is a deferred follow-up. |
| D7 | Refresh cadence | **Weekly** cron (MONDO releases ~monthly) + startup bootstrap heal | Cheap no-op weeks via conditional GET; weekly is ample. Configurable. |
| D8 | Mapping anchor key | Anchor on **base `disease_ontology_id`** (non-versioned) | All `_version` rows of a disease share the same external mappings; avoids per-version duplication. |

**These reflect the recommended calls presented to the user; any can be overridden before plans are written.**

## 4. Data model (migration `036_add_disease_ontology_mappings.sql`)

New tables use `utf8mb4`. All read-only at request time; written only by the refresh job.

### 4.1 `mondo_term` — local MONDO term index
```sql
CREATE TABLE IF NOT EXISTS `mondo_term` (
  `mondo_id`        varchar(20)  NOT NULL,           -- MONDO:0008426
  `label`           varchar(1000) DEFAULT NULL,
  `definition`      text         DEFAULT NULL,
  `is_obsolete`     tinyint(1)   NOT NULL DEFAULT 0,
  `replaced_by`     varchar(20)  DEFAULT NULL,
  `release_version` varchar(32)  DEFAULT NULL,        -- mondo data-version, e.g. 2026-05-05
  `update_date`     timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mondo_id`),
  KEY `idx_mondo_term_label` (`label`(100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 4.2 `mondo_xref` — MONDO term cross-references (merged OBO + SSSOM)
```sql
CREATE TABLE IF NOT EXISTS `mondo_xref` (
  `id`              bigint       NOT NULL AUTO_INCREMENT,
  `mondo_id`        varchar(20)  NOT NULL,
  `target_prefix`   varchar(20)  NOT NULL,            -- OMIM, Orphanet, DOID, UMLS, MedGen, NCIT, GARD, EFO, ...
  `target_id`       varchar(64)  NOT NULL,            -- full CURIE, e.g. Orphanet:530983
  `target_id_upper` varchar(64)  NOT NULL,            -- reverse lookup
  `target_label`    varchar(1000) DEFAULT NULL,       -- SSSOM object_label when present
  `predicate`       varchar(20)  NOT NULL,            -- exactMatch|equivalentTo|closeMatch|narrowMatch|broadMatch|xref
  `origin`          varchar(12)  NOT NULL,            -- obo_xref|sssom
  `source`          varchar(200) DEFAULT NULL,        -- mapping_justification / source annotation
  `release_version` varchar(32)  DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_mondo_xref_mondo` (`mondo_id`),
  KEY `idx_mondo_xref_target` (`target_prefix`,`target_id_upper`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 4.3 `disease_ontology_mapping` — SysNDD-disease-anchored derived mappings (**app source of truth**)
```sql
CREATE TABLE IF NOT EXISTS `disease_ontology_mapping` (
  `id`                  bigint       NOT NULL AUTO_INCREMENT,
  `disease_ontology_id` varchar(15)  NOT NULL,        -- base SysNDD id (non-versioned), e.g. OMIM:618524
  `mondo_id`            varchar(20)  DEFAULT NULL,     -- resolved hub MONDO id (NULL if no equiv)
  `target_prefix`       varchar(20)  NOT NULL,
  `target_id`           varchar(64)  NOT NULL,
  `target_label`        varchar(1000) DEFAULT NULL,
  `predicate`           varchar(20)  DEFAULT NULL,
  `source`              varchar(40)  NOT NULL,         -- sysndd_native|mondo_sssom|mondo_obo_xref
  `release_version`     varchar(32)  DEFAULT NULL,
  `is_active`           tinyint(1)   NOT NULL DEFAULT 1,
  `update_date`         timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_disease_target` (`disease_ontology_id`,`target_prefix`,`target_id`),
  KEY `idx_dom_disease` (`disease_ontology_id`),
  KEY `idx_dom_target` (`target_prefix`,`target_id`)  -- reverse lookup
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
The disease's own anchor id is written as a `sysndd_native` row (e.g. `OMIM:618524` → `{target_prefix:OMIM, target_id:OMIM:618524, source:sysndd_native, predicate:NULL}`) so the endpoint returns a complete picture including the anchor. The hub `mondo_id` row is `mondo_sssom`; all other targets are `mondo_obo_xref`/`mondo_sssom`.

### 4.4 `disease_ontology_mapping_meta` — build provenance (append-only history)
```sql
CREATE TABLE IF NOT EXISTS `disease_ontology_mapping_meta` (
  `id`                    int          NOT NULL AUTO_INCREMENT,
  `mondo_release_version` varchar(32)  DEFAULT NULL,
  `mondo_obo_url`         varchar(500) DEFAULT NULL,
  `mondo_sssom_url`       varchar(500) DEFAULT NULL,
  `source_validators`     json         DEFAULT NULL,   -- {obo:{etag,last_modified}, sssom:{...}}
  `mondo_term_count`      int          DEFAULT NULL,
  `mondo_xref_count`      int          DEFAULT NULL,
  `mapping_count`         int          DEFAULT NULL,
  `disease_covered_count` int          DEFAULT NULL,
  `status`                varchar(20)  DEFAULT NULL,    -- success|skipped|failed
  `build_started_at`      timestamp    NULL DEFAULT NULL,
  `build_finished_at`     timestamp    NULL DEFAULT NULL,
  `build_duration_s`      float        DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 4.5 Projection columns on `disease_ontology_set`
`ALTER TABLE` to add the missing semicolon-joined convenience columns (existing: `DOID`, `MONDO`, `Orphanet`, `EFO`):
```sql
ALTER TABLE `disease_ontology_set`
  ADD COLUMN `UMLS`   varchar(200) DEFAULT NULL,
  ADD COLUMN `MedGen` varchar(200) DEFAULT NULL,
  ADD COLUMN `NCIT`   varchar(200) DEFAULT NULL,
  ADD COLUMN `GARD`   varchar(200) DEFAULT NULL,
  ADD COLUMN `ontology_mapping_release` varchar(32) DEFAULT NULL;
```
These are refreshed by the job from `disease_ontology_mapping`. They serve export and the existing `/api/ontology` endpoint; they are **not** added to `ndd_entity_view` in v1 (D6). The migration's `ALTER` must be mirrored in `db/C_Rcommands_set-table-connections.R` only if that script recreates `disease_ontology_set` (it does not redefine `ndd_entity_view` columns for these — confirm during WP-A).

### 4.6 Migration manifest
`api/functions/migration-manifest.R`: `EXPECTED_LATEST_MIGRATION <- "036_add_disease_ontology_mappings.sql"`, `EXPECTED_MIGRATION_COUNT <- 34L`.

## 5. Ingestion pipeline

**Sources (env-overridable, config.yml defaults):**
- MONDO OBO: `http://purl.obolibrary.org/obo/mondo.obo` (`DISEASE_ONTOLOGY_MONDO_OBO_URL`)
- MONDO SSSOM (full, all targets): `https://raw.githubusercontent.com/monarch-initiative/mondo/master/src/ontology/mappings/mondo.sssom.tsv` (`DISEASE_ONTOLOGY_MONDO_SSSOM_URL`) — **note**: replaces the existing OMIM-only subset usage.

**Steps (all off the request path, inside the refresh job):**
1. **Download** OBO + SSSOM with conditional GET (ETag/Last-Modified persisted in `_meta.source_validators`). Every external HTTP call derives timeout/retry from `external_proxy_budget("mondo", ...)` or `make_external_request()` — never a hardcoded timeout (enforced by `test-unit-external-budget-guard.R`). 304 on both + populated tables ⇒ skip rebuild, write a `skipped` meta row.
2. **Parse OBO** (`ontologyIndex` is already a dependency; reuse where possible) → `mondo_term` rows (id, label, definition, is_obsolete, replaced_by) + per-term xref list. Extract `data-version` for `release_version`.
3. **Parse SSSOM TSV** → mapping rows (subject MONDO, object CURIE, predicate, justification, object_label).
4. **Normalize CURIE prefixes** (alias map) and **merge** OBO xrefs + SSSOM into `mondo_xref` with `origin` + `predicate` + `target_id_upper`.
5. **Derive `disease_ontology_mapping`**: for each distinct base `disease_ontology_id` present in `disease_ontology_set`:
   - emit the `sysndd_native` anchor row;
   - resolve hub `mondo_id` (if the anchor is an OMIM/etc CURIE, reverse-lookup `mondo_xref` by `target_id_upper`, strongest predicate wins; if the anchor is already a MONDO id, use it directly);
   - from the hub MONDO id, emit one row per target xref (collapse to strongest predicate per `(prefix, target_id)`), restricted to the configured target prefix allowlist.
6. **Refresh projection columns** on `disease_ontology_set` (semicolon-join per prefix) + `ontology_mapping_release`.
7. **Write `disease_ontology_mapping_meta`** (`success`, counts, durations, validators).

**Atomicity:** stage the rebuild in a transaction (or build into shadow rows then swap) so a partial failure never leaves the app reading a half-built mapping set. Follow the `refresh_disease_ontology_set()` / `metadata_with_foreign_key_checks_disabled()` pattern; do **not** use `TRUNCATE` inside transactional code (it auto-commits — see metadata-refresh static guard).

## 6. Refresh orchestration, admin, cron, bootstrap

Mirror the **pubtatornidd nightly** + **analysis-snapshot bootstrap** patterns exactly.

- **Async job type** `disease_ontology_mapping_refresh` registered in `async_job_handler_registry` (`api/functions/async-job-handlers.R`) with `{cancel_mode:"non_interruptible", run, after_success:noop}`. Handler `.async_job_run_disease_ontology_mapping_refresh(job, payload, state, worker_config)` calls the orchestrator. Worker needs **outbound egress** (attach to `proxy` network, not only internal `backend`).
- **Orchestrator** `api/functions/disease-ontology-mapping-refresh.R`: single-flight via non-blocking `GET_LOCK('disease_ontology_mapping_refresh', 0)`; benign skip (lock held / no change) completes **successfully**; a failed refresh step marks the job **failed** (observable in history). Resets the per-request external-time accumulator per external call for this batch (`external_proxy_request_reset()` pattern) so the per-request ceiling doesn't cap the back half.
- **Shared submit function** `service_disease_ontology_mapping_submit_refresh(analysis-style args: force, stagger, submit_fn, exists_fn, conn, now, stagger_seconds)` in `api/services/disease-ontology-mapping-service.R` — the single submission path for startup bootstrap, admin endpoint, and operator script. Plus `service_disease_ontology_mapping_status()`.
- **Admin endpoints** `api/endpoints/admin_ontology_mapping_endpoints.R`, role-gated **Administrator**, wrapped with `mount_endpoint()`:
  - `POST /api/admin/ontology/mappings/refresh` (optional `force`) → 202.
  - `GET  /api/admin/ontology/mappings/status` → per-build state from `_meta`.
  - Mounted at `/api/admin/ontology` **before** `/api/admin` in `api/bootstrap/mount_endpoints.R` (more-specific prefix wins).
- **Cron sidecar** `ontology-mapping-cron` in Compose (model on `pubtatornidd-cron`/`log-cleanup`): DB-only network, no egress, runs `api/scripts/ontology_mapping_refresh_enqueue.R` weekly to enqueue one durable job; the worker (with egress) runs it.
- **Startup bootstrap** `disease_ontology_mapping_bootstrap_on_startup()` in `api/start_sysndd_api.R` after migrations: gated by `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP` (default on), idempotent (enqueue only when no successful build exists), never crashes boot, **staggered** (`DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_STAGGER_SECONDS`, default e.g. 360s) so it doesn't co-launch with the snapshot (120s) / pubtatornidd (240s) bootstraps.
- **Config** `api/config.yml`: `mondo_obo_url`, `mondo_sssom_url`, target-prefix allowlist; env overrides take precedence.

## 7. Read API (public, cheap)

New file `api/endpoints/disease_mapping_endpoints.R` mounted at `/api/disease` via `mount_endpoint()`; repository read functions in `api/functions/disease-ontology-mapping-repository.R`.

- `GET /api/disease/mappings?entity_id=<int>` **or** `?disease_ontology_id=<CURIE>` (query-param keyed to avoid encoding the CURIE colon in the path). Returns:
```json
{
  "disease_ontology_id": "OMIM:618524",
  "disease_ontology_name": "…",
  "mondo_id": "MONDO:0032745",
  "release_version": "2026-05-05",
  "status": "current",
  "mappings": {
    "MONDO":    [{"id":"MONDO:0032745","label":"…","predicate":"exactMatch","source":"mondo_sssom"}],
    "Orphanet": [{"id":"Orphanet:530983","label":"…","predicate":"exactMatch","source":"mondo_obo_xref"}],
    "DOID":     [{"id":"DOID:0081234","label":"…","predicate":"exactMatch","source":"mondo_obo_xref"}],
    "OMIM":     [{"id":"OMIM:618524","label":null,"predicate":null,"source":"sysndd_native"}],
    "UMLS":     [{"id":"UMLS:C1234567","label":null,"predicate":"closeMatch","source":"mondo_obo_xref"}]
  }
}
```
- The response carries **ids and predicates only — never URLs** (frontend owns URL templates; Plumber may array-wrap scalars, so the frontend unwraps).
- Cheap-route isolation: this endpoint must read DB only (no external fetch).
- **Reverse lookup** (`?target_id=Orphanet:530983` → entities) and **MCP exposure** are deferred follow-ups (Section 9).

## 8. Frontend

All API access via typed clients (no raw axios); outlinks via a central URL module.

- **`app/src/assets/js/constants/ontology_links.ts`** (extend): add `ontologyOutlink(prefix, id) -> { url: string|null, label: string }` plus per-prefix helpers (`omimUrl`, `mondoUrl`, `orphanetUrl`, `doidUrl`, `medgenUrl`, `ncitUrl`, `gardUrl`, `efoUrl`; `umlsUrl` returns `null`). Reuse the URL templates already hardcoded in `OntologyView.vue`, centralizing them.
- **`app/src/api/disease-mappings.ts`** (new typed client): `getEntityMappings(entityId)` / `getDiseaseMappings(diseaseId)` → typed `DiseaseMappingResponse`.
- **`app/src/composables/useEntityMappings.ts`** (new): SWR hook over `useResource`, lazy (fires on row-expand / card mount), keyed by entity id.
- **`app/src/components/disease/LinkedOntologies.vue`** (new): renders grouped outlink badges via `ResourceLink` (compact mode). Two layouts via prop: `strip` (table expansion) and `card` (detail page). Hides empty groups; non-linkable ids (UMLS) render as plain badges. Accessible (`aria-expanded`, reduced-motion).
- **Entities list (`TablesEntities.vue` + `GenericTable`)**: add a per-row expand toggle (mirroring `EntitiesMobileRows` "Details") that lazy-loads `useEntityMappings(entity_id)` and renders `LinkedOntologies` in `strip` layout. Requires a small expandable-row capability in the desktop table.
- **Entity detail (`EntityView.vue`)**: add a "Linked disease ontologies" `SectionCard` (after the hero, before Clinical Synopsis) using `useEntityMappings` + `LinkedOntologies` in `card` layout. Remove the half-wired plain-text `mondoEquivalent` in favor of this card.
- **SEO prerender**: the detail card is data-driven and client-fetched; run `make verify-seo-app` and confirm no prerender regression. If mappings should appear in prerendered HTML, that's a deferred follow-up.

## 9. Non-goals / deferred (v2+)

- Exposing projection columns in `ndd_entity_view` (keeps the fragile mirror untouched in v1).
- MCP tool exposure of mappings (read-only, approved-public — natural follow-up; would reuse the normalized store).
- Reverse-lookup endpoint / "entities for this Orphanet id" browse.
- MONDO hierarchy/closure tables and FTS (the reference repo has them; not needed for v1 outlinks).
- A standalone Orphanet product import (Orphanet comes through MONDO xrefs in v1).
- Enriching the public `/Ontology/<id>` page and the sitemap with the new targets.
- Fuzzy disease-name → MONDO resolution (we anchor on existing ids, not free text).

## 10. Risks & mitigations

- **Mapping correctness / over-broad links** → only emit `exactMatch`/`equivalentTo` for first-class clickable targets by default; carry weaker predicates but visually de-emphasize them; show `predicate` in tooltips.
- **`ndd_entity_view` mirror breakage** → avoided entirely (D6); frontend reads a separate endpoint.
- **External-time budget exhaustion in the batch job** → per-call accumulator reset + `external_proxy_budget`.
- **OBO parse cost (~50 MB)** → off the request path, in the worker; conditional GET makes no-change refreshes ~free; atomic rebuild.
- **utf8mb3 vs utf8mb4 join** → new tables are utf8mb4; joins to `disease_ontology_set` (utf8mb3) are on ASCII CURIEs/ids, collation-safe; verify no collation-mismatch errors in WP-A.
- **Worker egress** → ensure the worker is on the `proxy` network (already required for Gemini/PubMed); the cron sidecar stays DB-only.

## 11. Parallel-PR work-package decomposition

Designed to minimize shared-file conflicts. A short **schema-contract doc** (committed in WP-A) freezes table/column/endpoint shapes so later WPs code against it before earlier WPs merge.

| WP / PR | Title | Primary files (mostly disjoint) | Depends on |
|---|---|---|---|
| **A** | Schema & migration | `db/migrations/036_*.sql`, `api/functions/migration-manifest.R`, `db/C_Rcommands_set-table-connections.R` (only if it recreates `disease_ontology_set`), contract doc | — |
| **B** | Ingestion R functions | `api/functions/mondo-index-builder.R` (new: OBO/SSSOM parse + index build), `api/functions/mondo-functions.R` (extend to full SSSOM), `api/functions/disease-ontology-mapping-builder.R` (new: derive `disease_ontology_mapping` + projection write) | A (contract) |
| **C** | Refresh orchestration + admin + cron + bootstrap | `api/functions/disease-ontology-mapping-refresh.R`, `api/services/disease-ontology-mapping-service.R`, `api/endpoints/admin_ontology_mapping_endpoints.R`, `api/bootstrap/mount_endpoints.R` (admin mount), `api/functions/async-job-handlers.R` (registry), `api/scripts/ontology_mapping_refresh_enqueue.R`, `docker-compose*.yml`, `api/start_sysndd_api.R`, `api/config.yml` | B |
| **D** | Read API (mappings endpoint) | `api/endpoints/disease_mapping_endpoints.R`, `api/functions/disease-ontology-mapping-repository.R` (new: read-only queries), `api/bootstrap/mount_endpoints.R` (`/api/disease` mount) | A (contract) |
| **E** | Frontend foundation | `app/src/assets/js/constants/ontology_links.ts`, `app/src/api/disease-mappings.ts`, `app/src/composables/useEntityMappings.ts`, `app/src/components/disease/LinkedOntologies.vue` | D (contract) |
| **F** | Frontend — Entities list expandable row | `app/src/components/tables/TablesEntities.vue`, `GenericTable` expand capability, `EntitiesMobileRows.vue` | E |
| **G** | Frontend — Entity detail card | `app/src/views/pages/EntityView.vue` | E |
| **H** | Docs + integration tests + invariants | `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd`, `api/tests/testthat/*`, `app/tests/*` | C, D, F, G |

**Shared-file coordination:** `mount_endpoints.R` is touched by C (admin mount) and D (`/api/disease` mount) on different lines — sequence D before C or expect a trivial merge. Repository code is split by responsibility to avoid contention: **B owns the write/derive path** (`disease-ontology-mapping-builder.R`), **D owns the read path** (`disease-ontology-mapping-repository.R`) — no shared repository file. `mondo-functions.R` is extended only by B.

**Execution waves (each cell = one parallel agent/PR):**
- **Wave 1:** A (schema + frozen contract).
- **Wave 2 (parallel):** B (ingestion), D (read endpoint), E (frontend foundation, against the D contract; stub until D lands).
- **Wave 3 (parallel):** C (refresh/admin/cron/bootstrap), F (list expand), G (detail card).
- **Wave 4:** H (docs, invariants, integration tests, `AGENTS.md` architecture-invariant entry, `make verify-seo-app`).

## 12. Testing

- **R unit**: OBO parser, SSSOM parser, CURIE normalization, predicate collapse, mapping derivation (fixtures, no network). External-budget guard compliance. Single-flight lock behavior. Service submit dedup/idempotency. Admin endpoint role gate. Cheap-route isolation for the read endpoint.
- **R integration**: refresh job end-to-end on a small fixture OBO/SSSOM with `with_test_db_transaction()`; projection-column refresh; meta provenance written.
- **Frontend unit (vitest)**: `ontology_links` URL builders (incl. UMLS→null), `LinkedOntologies` rendering (empty groups hidden, non-linkable plain), `useEntityMappings` SWR states.
- **Frontend E2E (local-only, optional)**: row-expand reveals outlinks; detail card renders.
- **Gates**: `make code-quality-audit`, `make test-api-fast` (then `make test-api`), `make lint-api`, `make lint-app`, `cd app && npm run type-check`, `npm run test:unit`, `make verify-seo-app`.

## 13. Documentation contract

Update in the same change set: `AGENTS.md` (new "Disease cross-ontology mappings" architecture-invariant section — sources, MONDO-as-hub, refresh/cron/bootstrap, read-endpoint, frontend), `documentation/08-development.qmd` (dev workflow, how to trigger a refresh), `documentation/09-deployment.qmd` (cron sidecar, env vars, worker egress, bootstrap gating), and `db/migrations/README.md` if it tracks per-migration notes.

## 13a. Review corrections (Codex expert review, 2026-06-20 — binding, verified against live code)

1. **Public surface only.** The read endpoint resolves an entity through **`ndd_entity_view`** (the public list source, `entity_endpoints.R:92`), never raw `ndd_entity`; a non-public/inactive entity returns `status:"missing"`.
2. **Operator ontology refresh chains a mapping refresh.** `refresh_disease_ontology_set()` deletes+re-appends `disease_ontology_set` (`metadata-refresh.R:99`), wiping projection columns; a successful `ontology_update`/`force_apply_ontology` enqueues `disease_ontology_mapping_refresh(force=TRUE)`.
3. **`/api/ontology` + `OntologyTerm` carry the new columns.** Both currently expose only `DOID/MONDO/Orphanet/EFO`; add `UMLS/MedGen/NCIT/GARD/ontology_mapping_release`.
4. **Source new files via `bootstrap_load_modules()`** (`load_modules.R`), not `start_sysndd_api.R`. One list covers the API and the durable worker (`start_async_worker.R`). Only the bootstrap hook lives in `start_sysndd_api.R`. No `setup_workers.R` (mirai) change.
5. **Reuse the existing table expansion.** `GenericTable` already has the `details` toggle + `#row-expansion` slot and `TablesEntities` already ships `fields_details`; the list UX **extends** that, not a second system.
6. **`target_id` is always a full CURIE**, incl. `UMLS:C1234567` (the UI may shorten the display label only).
7. **Never canonicalize `OMIMPS`→OMIM** (would mislink to an OMIM entry page); drop OMIMPS in v1.
8. **Pin the cross-charset join key** `disease_ontology_mapping.disease_ontology_id` to `utf8mb3 / utf8mb3_general_ci` to match `disease_ontology_set` (avoids "Illegal mix of collations").

## 14. Open questions still overridable by the user

- **D2 ingestion** — full local MONDO index (recommended/assumed) vs. lightweight targeted enrichment.
- **D4 outlink scope** — confirm the target set and that UMLS shows as plain text.
- **D5 list UX** — expandable row (assumed) vs. inline badges vs. hover popover.
- **D7 cadence** — weekly (assumed) vs. nightly.
- **Scope of v2 deferrals** — whether MCP/SEO/`/Ontology` enrichment should be pulled into v1.
