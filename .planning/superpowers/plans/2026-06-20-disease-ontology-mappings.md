# Disease Cross-Ontology Mappings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every SysNDD disease provenance-tracked cross-references to MONDO, Orphanet, OMIM, DOID, UMLS, MedGen, NCIT, GARD, EFO — ingested from upstream MONDO releases, refreshable via admin/cron/startup, and surfaced with external outlinks in the Entities list and the Entity detail page.

**Architecture:** A weekly worker job materializes a local MONDO index (`mondo_term`/`mondo_xref`) from `mondo.obo` + `mondo.sssom.tsv`, derives a normalized `disease_ontology_mapping` store anchored on each SysNDD disease (MONDO-as-hub), and refreshes denormalized projection columns on `disease_ontology_set`. A cheap public read endpoint serves grouped mappings; the frontend lazy-fetches them and renders outlink badges. Mirrors the existing `pubtatornidd_nightly` (cron+job+bootstrap) and `analysis_snapshot` (shared-submit+admin) subsystems.

**Tech Stack:** R/Plumber + `renv`, MySQL (`RMariaDB`/`pool`/`DBI`), `ontologyIndex`/`httr2`/`readr`, Vue 3 + TypeScript + Vite + bootstrap-vue-next, vitest/testthat.

**Spec:** `.planning/superpowers/specs/2026-06-20-disease-ontology-mappings-design.md`

## Global Constraints

- **Migration runner:** new migration is `db/migrations/036_add_disease_ontology_mappings.sql`. Bump `api/functions/migration-manifest.R`: `EXPECTED_LATEST_MIGRATION <- "036_add_disease_ontology_mappings.sql"`, `EXPECTED_MIGRATION_COUNT <- 34L`. Migration failure must crash startup — never weaken startup checks to work around it.
- **`ndd_entity_view` is NOT modified** (avoids the byte-for-byte mirror risk). Frontend reads mappings from the new `/api/disease/mappings` endpoint.
- **Namespace dplyr verbs** explicitly (`dplyr::select`, `dplyr::filter`, …) — several loaded packages mask them. Use `inherits(x, "Date")`, not `is.Date(x)`.
- **`DBI::dbBind()` with `?` placeholders needs `unname(params)`.**
- **Every external HTTP call** derives timeout/retry from `external_proxy_budget("mondo", ...)` or goes through `make_external_request()` — never a hardcoded `req_timeout(<n>)`/`max_seconds=<n>`. Use `memoise_external_success_only(..., source = "mondo")` for any memoised fetcher. Enforced by `api/tests/testthat/test-unit-external-budget-guard.R`.
- **Every mounted endpoint file** is wrapped with `mount_endpoint()` (attaches RFC9457 errorHandler + 404). Never `pr_mount(pr(...))` bare. Only `error_400/401/403/404/500` classes exist; raise via `stop_for_bad_request()` etc.
- **Admin routes are Administrator-gated** via `require_role(req, res, "Administrator")`. Mount `/api/admin/ontology` BEFORE `/api/admin` (more-specific prefix wins).
- **Service prefixes:** service functions keep `svc_`/`service_` prefixes so they don't shadow repository functions in the global env.
- **Frontend:** API access only through typed clients in `app/src/api/*`; no raw axios in views/components; no direct `localStorage.token`/`localStorage.user`. Plumber may array-wrap JSON scalars — unwrap before use.
- **Files stay under ~600 lines** where practical; extract cohesive helpers when approaching it.
- **Gates before handoff:** `make code-quality-audit`, then scope-appropriate `make test-api-fast` / `make lint-api` / `cd app && npm run type-check && npm run test:unit && npm run lint` / `make verify-seo-app`.

## Frozen Contract (Wave 1 freezes this; all later WPs code against it)

**Tables** — exact DDL in spec §4 (`mondo_term`, `mondo_xref`, `disease_ontology_mapping`, `disease_ontology_mapping_meta`; projection `ALTER` on `disease_ontology_set`).

**Mapping store key:** anchor on **base** `disease_ontology_id` (non-versioned, e.g. `OMIM:618524`).

**Target prefix allowlist (canonical casing):** `MONDO, Orphanet, OMIM, DOID, UMLS, MedGen, NCIT, GARD, EFO`. CURIE alias normalization: `ORPHANET|ORPHA→Orphanet`, `MIM→OMIM`, `NCIT|NCI→NCIT`, `MEDGEN→MedGen`, `GARD→GARD`, `EFO→EFO`, `DOID→DOID`, `UMLS|UMLS_CUI→UMLS`. **`OMIMPS` is NOT canonicalized to OMIM and is dropped in v1** (phenotypic-series ids would mislink to an OMIM entry page — never map them). `SCTID|SNOMEDCT` and `MESH` are not in the allowlist and are dropped.

**`target_id` is always a full CURIE**, including UMLS → `UMLS:C1234567` (never bare `C1234567`). The frontend may shorten the *displayed label* but the stored/returned id keeps the prefix.

**Collation:** `disease_ontology_set` is `utf8mb3` (default collation `utf8mb3_general_ci`). The new utf8mb4 tables keep utf8mb4 for label/definition columns, but **`disease_ontology_mapping.disease_ontology_id` (the cross-charset join key to `disease_ontology_set`) is pinned to `CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci`** so the projection `UPDATE … JOIN` and read joins never raise "Illegal mix of collations". WP-A confirms the exact collation via `SHOW FULL COLUMNS FROM disease_ontology_set` and matches it.

**Predicate rank (strongest→weakest):** `exactMatch(0) < equivalentTo(1) < closeMatch(2) < narrowMatch(3) < broadMatch(4) < xref(5)`.

**Read endpoint:** `GET /api/disease/mappings?entity_id=<int>` OR `?disease_ontology_id=<CURIE>`. Response JSON shape (spec §7):
```json
{ "disease_ontology_id":"OMIM:618524", "disease_ontology_name":"…", "mondo_id":"MONDO:0032745",
  "release_version":"2026-05-05", "status":"current|missing",
  "mappings": { "<Prefix>": [ {"id":"<CURIE>","label":"…|null","predicate":"…|null","source":"sysndd_native|mondo_sssom|mondo_obo_xref"} ] } }
```
Response carries **ids/predicates only, never URLs**. `status:"missing"` (HTTP 200) when no mapping rows exist yet (cold start).

**Async job type string:** `disease_ontology_mapping_refresh`. **Advisory lock name:** `disease_ontology_mapping_refresh`. **Env:** `DISEASE_ONTOLOGY_MONDO_OBO_URL`, `DISEASE_ONTOLOGY_MONDO_SSSOM_URL`, `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP` (default `true`), `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_STAGGER_SECONDS` (default `360`).

## Dependency Waves (each cell = one parallel agent / PR)

- **Wave 1:** WP-A (schema + freeze contract).
- **Wave 2 (parallel):** WP-B (ingestion), WP-D (read endpoint), WP-E (frontend foundation — stub client until D lands).
- **Wave 3 (parallel):** WP-C (refresh/admin/cron/bootstrap), WP-F (list expand), WP-G (detail card).
- **Wave 4:** WP-H (docs, invariants, integration, SEO gate).

Branch naming: `feat/ontology-mappings-<wp>` (e.g. `feat/ontology-mappings-schema`). Each WP is one PR onto `master`.

## Review Corrections (binding — applied into the tasks below; verified against live code 2026-06-20)

1. **Public surface only.** `disease_mapping_for_entity()` resolves the entity through **`ndd_entity_view`** (the public list source, `entity_endpoints.R:92`), NOT raw `ndd_entity`. An entity absent from `ndd_entity_view` (inactive/non-public) returns `status:"missing"` — never leaks mappings. Test required. (WP-D T-D1)
2. **Operator ontology refresh wipes projection columns.** `refresh_disease_ontology_set()` does `DELETE FROM disease_ontology_set` + re-append (`metadata-refresh.R:99`) and the combine logic doesn't build the new columns. So a successful `ontology_update`/`force_apply_ontology` MUST enqueue a `disease_ontology_mapping_refresh` afterward, or projection columns + normalized mappings drift. (WP-C T-C7)
3. **`/api/ontology` + frontend type must carry the new columns.** Endpoint selects only `DOID,MONDO,Orphanet,EFO` (`ontology_endpoints.R:66`); `app/src/api/ontology.ts:40` mirrors only those. Add `UMLS,MedGen,NCIT,GARD,ontology_mapping_release` to both. (WP-D T-D3, WP-E T-E5)
4. **Source files via `bootstrap_load_modules()`**, not `start_sysndd_api.R`. New function files → `api/bootstrap/load_modules.R` `function_files`; the service → its `service_files` list. The durable async worker (`start_async_worker.R:6`) calls `bootstrap_load_modules()`, so this one list covers both API and worker. Only the **bootstrap hook call** goes in `start_sysndd_api.R`. No `setup_workers.R` (mirai) change needed — the refresh is not a daemon job. Restart the worker container after changes. (WP-C T-C5)
5. **Reuse the existing table expansion.** `GenericTable` already has a `details` toggle column + `#row-expansion` slot (`GenericTable.vue:489,496`) and `TablesEntities` already ships `details` + `fields_details` (`TablesEntities.vue:459,464`). WP-F **extends** that expansion (override the `#row-expansion` slot / append to the detail card) — it does NOT add a second desktop expansion system. (WP-F T-F1)
6. **UMLS id is a full CURIE** `UMLS:C1234567` everywhere (schema, derive, endpoint, tests). (Frozen Contract; WP-E T-E1)
7. **Never canonicalize `OMIMPS`→OMIM**; drop OMIMPS in v1. (Frozen Contract; WP-B T-B1)
8. **Pin the cross-charset join key collation** in WP-A (`disease_ontology_mapping.disease_ontology_id` → utf8mb3). (Frozen Contract; WP-A T-A1)

---

# WP-A — Schema & migration (Wave 1)

**Files:**
- Create: `db/migrations/036_add_disease_ontology_mappings.sql`
- Modify: `api/functions/migration-manifest.R:5-6`
- Modify (if it recreates `disease_ontology_set`): `db/C_Rcommands_set-table-connections.R`
- Test: `api/tests/testthat/test-unit-migration-manifest.R` (extend) and a manifest/DDL sanity check.

**Interfaces:**
- Produces: the four tables + projection columns from the Frozen Contract. No R symbols.

### Task A1: Write the migration

- [ ] **Step 1 — Create `db/migrations/036_add_disease_ontology_mappings.sql`** with the DDL from spec §4.1–4.5 (the four `CREATE TABLE IF NOT EXISTS` and the `ALTER TABLE disease_ontology_set ADD COLUMN …`). Prefix every statement file-scoped; no `USE`. End each `CREATE` with `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`. **Collation pin (binding correction #8):** declare `disease_ontology_mapping.disease_ontology_id varchar(15) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL` so it joins to `disease_ontology_set.disease_ontology_id` without an "Illegal mix of collations" error. Leave `mondo_id`/`target_id`/`target_id_upper` as utf8mb4 (they only join within the new tables).

- [ ] **Step 2 — Guard the `ALTER` for idempotency.** MySQL lacks `ADD COLUMN IF NOT EXISTS` portably across the deployed version; the runner applies each file once via the migrations ledger, so a plain `ALTER TABLE disease_ontology_set ADD COLUMN …` is correct (the file runs exactly once). Do **not** add `IF NOT EXISTS` to columns. Verify the runner records `036` in its ledger table (read `api/bootstrap/run_migrations.R` to confirm ledger semantics).

- [ ] **Step 3 — Bump the manifest.** In `api/functions/migration-manifest.R` set line 5 `EXPECTED_LATEST_MIGRATION <- "036_add_disease_ontology_mappings.sql"` and line 6 `EXPECTED_MIGRATION_COUNT <- 34L`.

- [ ] **Step 4 — Check `C_Rcommands_set-table-connections.R`.** Grep for `disease_ontology_set`. If that script `CREATE`s or `CREATE OR REPLACE`s the table (vs. only referencing it in views), add the four new projection columns there to keep the bootstrap script in sync. It must **not** touch `ndd_entity_view`’s column list for this change.

- [ ] **Step 5 — Extend the manifest test.** In `api/tests/testthat/test-unit-migration-manifest.R` (read it first), confirm the existing assertions now expect `036…`/`34L`. Add an assertion that `db/migrations/036_add_disease_ontology_mappings.sql` exists and contains `CREATE TABLE IF NOT EXISTS \`disease_ontology_mapping\``.

- [ ] **Step 6 — Run the test.** `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-migration-manifest.R')"`. Expected: PASS.

- [ ] **Step 7 — Confirm collation + apply locally.** First run `SHOW FULL COLUMNS FROM disease_ontology_set LIKE 'disease_ontology_id';` and confirm the join key really is `utf8mb3_general_ci`; if the deployed DB shows a different utf8mb3 collation, match it exactly in the migration. Then bring up `make docker-dev-db`, restart the API, confirm boot succeeds and the four tables + columns exist (`SHOW COLUMNS FROM disease_ontology_set;`). A trial `SELECT … FROM disease_ontology_mapping m JOIN disease_ontology_set s ON m.disease_ontology_id = s.disease_ontology_id LIMIT 1;` must not raise collation errors.

- [ ] **Step 8 — Commit.**
```bash
git add db/migrations/036_add_disease_ontology_mappings.sql api/functions/migration-manifest.R api/tests/testthat/test-unit-migration-manifest.R db/C_Rcommands_set-table-connections.R
git commit -m "feat(db): add disease cross-ontology mapping tables (migration 036)"
```

### Task A2: Commit the frozen contract reference

- [ ] **Step 1 — Add a short `db/migrations/README.md` note** (append) describing `036` and pointing to the spec, so other WPs can confirm column names without re-reading the migration.

- [ ] **Step 2 — Commit.** `git commit -am "docs(db): note migration 036 in README"`.

---

# WP-B — Ingestion R functions (Wave 2; depends on A contract)

Pure parse/build/derive logic + write-path repository. No network in unit tests (fixtures). This is the algorithmic heart.

**Files:**
- Create: `api/functions/mondo-index-builder.R` (OBO + SSSOM parse → `mondo_term`/`mondo_xref` build)
- Modify: `api/functions/mondo-functions.R` (point SSSOM download at full `mondo.sssom.tsv`; keep OMIM-subset fn for back-compat)
- Create: `api/functions/disease-ontology-mapping-builder.R` (derive `disease_ontology_mapping` + projection write)
- Create: `api/tests/testthat/fixtures/mondo-mini.obo`, `api/tests/testthat/fixtures/mondo-mini.sssom.tsv`
- Test: `api/tests/testthat/test-unit-mondo-index-builder.R`, `api/tests/testthat/test-unit-disease-ontology-mapping-builder.R`

**Interfaces:**
- Produces (consumed by WP-C):
  - `mondo_obo_parse(text) -> list(version=chr, terms=tibble[mondo_id,label,definition,is_obsolete,replaced_by], xrefs=tibble[mondo_id,target_prefix,target_id,predicate,origin,source,target_label])`
  - `mondo_sssom_parse(text) -> tibble[mondo_id,target_prefix,target_id,predicate,source,target_label]`
  - `mondo_normalize_curie(curie) -> chr` (alias-mapped, canonical casing) and `mondo_curie_prefix(curie) -> chr`
  - `mondo_merge_xrefs(obo_xrefs, sssom_xrefs) -> tibble` (deduped, strongest predicate per (mondo_id,target_prefix,target_id))
  - `mondo_index_write(conn, parsed_obo, sssom_tbl, release_version)` — truncates+loads `mondo_term`,`mondo_xref` transactionally
  - `disease_mapping_derive(conn, target_allowlist) -> tibble[disease_ontology_id,mondo_id,target_prefix,target_id,target_label,predicate,source,release_version]`
  - `disease_mapping_write(conn, mapping_tbl, release_version)` — replaces `disease_ontology_mapping` + refreshes `disease_ontology_set` projection columns, transactionally
  - Constants: `MONDO_TARGET_ALLOWLIST`, `MONDO_PREDICATE_RANK`

### Task B1: CURIE normalization (TDD)

- [ ] **Step 1 — Write failing test** `api/tests/testthat/test-unit-mondo-index-builder.R`:
```r
source_api_file("functions/mondo-index-builder.R", local = FALSE)

test_that("mondo_normalize_curie maps aliases to canonical casing", {
  expect_equal(mondo_normalize_curie("ORPHANET:530983"), "Orphanet:530983")
  expect_equal(mondo_normalize_curie("ORPHA:530983"),    "Orphanet:530983")
  expect_equal(mondo_normalize_curie("MIM:618524"),      "OMIM:618524")
  expect_equal(mondo_normalize_curie("UMLS:C1234567"),   "UMLS:C1234567")  # full CURIE, not bare
  expect_equal(mondo_curie_prefix("DOID:0081234"),       "DOID")
  # correction #7: OMIMPS must NOT become OMIM (stays OMIMPS, dropped by allowlist later)
  expect_equal(mondo_normalize_curie("OMIMPS:618524"),   "OMIMPS:618524")
  expect_false("OMIMPS" %in% MONDO_TARGET_ALLOWLIST)
  expect_true(is.na(mondo_normalize_curie("not-a-curie")))
})
```
- [ ] **Step 2 — Run, verify FAIL** (`could not find function "mondo_normalize_curie"`): `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-mondo-index-builder.R')"`.
- [ ] **Step 3 — Implement** in `api/functions/mondo-index-builder.R`:
```r
MONDO_TARGET_ALLOWLIST <- c("MONDO","Orphanet","OMIM","DOID","UMLS","MedGen","NCIT","GARD","EFO")
MONDO_PREDICATE_RANK <- c(exactMatch = 0L, equivalentTo = 1L, closeMatch = 2L,
                          narrowMatch = 3L, broadMatch = 4L, xref = 5L)
# NOTE (correction #7): OMIMPS is deliberately absent — phenotypic-series ids
# must NOT canonicalize to OMIM (they would mislink to an OMIM entry page).
# An unmapped prefix stays as-is and is dropped downstream (not in allowlist).
.MONDO_PREFIX_ALIASES <- c(ORPHANET = "Orphanet", ORPHA = "Orphanet", MIM = "OMIM",
                           OMIM = "OMIM", MEDGEN = "MedGen",
                           NCIT = "NCIT", NCI = "NCIT", GARD = "GARD", EFO = "EFO",
                           DOID = "DOID", UMLS = "UMLS", UMLS_CUI = "UMLS", MONDO = "MONDO")

mondo_curie_prefix <- function(curie) {
  curie <- trimws(as.character(curie))
  m <- regmatches(curie, regexec("^([A-Za-z][A-Za-z0-9_]*):", curie))[[1]]
  if (length(m) < 2) return(NA_character_)
  raw <- toupper(m[[2]])
  unname(ifelse(raw %in% names(.MONDO_PREFIX_ALIASES), .MONDO_PREFIX_ALIASES[raw], m[[2]]))
}

mondo_normalize_curie <- function(curie) {
  curie <- trimws(as.character(curie))
  m <- regmatches(curie, regexec("^([A-Za-z][A-Za-z0-9_]*):(.+)$", curie))[[1]]
  if (length(m) < 3) return(NA_character_)
  prefix <- mondo_curie_prefix(curie)
  if (is.na(prefix)) return(NA_character_)
  paste0(prefix, ":", trimws(m[[3]]))
}
```
- [ ] **Step 4 — Run, verify PASS.**
- [ ] **Step 5 — Commit.** `git add -A && git commit -m "feat(api): CURIE normalization for MONDO xref ingestion"`.

### Task B2: SSSOM parser (TDD)

- [ ] **Step 1 — Add fixture** `api/tests/testthat/fixtures/mondo-mini.sssom.tsv` (tab-separated; first lines are `#`-comments, then a header row `subject_id\tpredicate_id\tobject_id\tobject_label\tmapping_justification\tconfidence`, then 3 rows: one `MONDO:0032745 skos:exactMatch OMIM:618524`, one `MONDO:0032745 skos:exactMatch Orphanet:530983`, one `MONDO:0008426 skos:closeMatch DOID:0081234`).
- [ ] **Step 2 — Write failing test** (append to the builder test file):
```r
test_that("mondo_sssom_parse maps predicates and normalizes targets", {
  txt <- readChar("fixtures/mondo-mini.sssom.tsv", file.info("fixtures/mondo-mini.sssom.tsv")$size)
  out <- mondo_sssom_parse(txt)
  expect_true(all(c("mondo_id","target_prefix","target_id","predicate") %in% names(out)))
  row <- out[out$target_id == "Orphanet:530983", ]
  expect_equal(row$mondo_id, "MONDO:0032745")
  expect_equal(row$predicate, "exactMatch")
  expect_equal(row$target_prefix, "Orphanet")
})
```
- [ ] **Step 3 — Run, verify FAIL.**
- [ ] **Step 4 — Implement** `mondo_sssom_parse()` in `mondo-index-builder.R`. Read with `readr::read_tsv(comment = "#", show_col_types = FALSE)`. Map `predicate_id`: strip the `skos:`/`semapv:` prefix, map `exactMatch/closeMatch/narrowMatch/broadMatch` verbatim; anything else → `xref`. Normalize `object_id` via `mondo_normalize_curie`; derive `target_prefix` via `mondo_curie_prefix`; carry `object_label`→`target_label` and `mapping_justification`→`source`. Drop rows whose `subject_id` isn't `MONDO:` or whose `target_prefix` is `NA`. Return a tibble with the contract columns; `origin` is set by the caller (sssom).
- [ ] **Step 5 — Run, verify PASS. Commit.** `git commit -am "feat(api): MONDO SSSOM parser"`.

### Task B3: OBO parser (TDD)

- [ ] **Step 1 — Add fixture** `api/tests/testthat/fixtures/mondo-mini.obo`: an OBO header with `data-version: releases/2026-05-05`, then two `[Term]` stanzas: `MONDO:0032745` (name, def, `xref: OMIM:618524 {source="MONDO:equivalentTo"}`, `xref: Orphanet:530983`) and an obsolete `MONDO:0000003` (`is_obsolete: true`, `replaced_by: MONDO:0032745`).
- [ ] **Step 2 — Write failing test:**
```r
test_that("mondo_obo_parse extracts version, terms, and xrefs", {
  txt <- readChar("fixtures/mondo-mini.obo", file.info("fixtures/mondo-mini.obo")$size)
  res <- mondo_obo_parse(txt)
  expect_equal(res$version, "2026-05-05")
  expect_true("MONDO:0032745" %in% res$terms$mondo_id)
  obs <- res$terms[res$terms$mondo_id == "MONDO:0000003", ]
  expect_equal(obs$is_obsolete, 1L); expect_equal(obs$replaced_by, "MONDO:0032745")
  xr <- res$xrefs[res$xrefs$target_id == "OMIM:618524", ]
  expect_equal(xr$mondo_id, "MONDO:0032745")
  expect_equal(xr$predicate, "equivalentTo")  # from {source="MONDO:equivalentTo"}
})
```
- [ ] **Step 3 — Run, verify FAIL.**
- [ ] **Step 4 — Implement** `mondo_obo_parse(text)` as a line-by-line stanza state machine. Only keep `[Term]` stanzas whose `id:` matches `^MONDO:\d{7}$`. Per stanza collect `name`, `def` (strip surrounding quotes and trailing `[refs]`), `is_obsolete` (`true`→1L), `replaced_by` (normalized MONDO id), and `xref:` lines. For each xref: `mondo_normalize_curie` the object; `target_prefix` via `mondo_curie_prefix`; predicate = `equivalentTo` when the trailing `{…}` contains `MONDO:equivalentTo`, else `xref`; `origin="obo_xref"`; `source=NA`; `target_label=NA`. Drop xrefs with `NA` prefix or prefix outside `MONDO_TARGET_ALLOWLIST`. Extract `version` from the `data-version: releases/<v>` header (strip `releases/`). Return `list(version, terms=tibble, xrefs=tibble)`. Keep this function under ~120 lines; if larger, extract `.mondo_obo_apply_tag()`.
- [ ] **Step 5 — Run, verify PASS. Commit.** `git commit -am "feat(api): MONDO OBO parser"`.

### Task B4: Merge xrefs with predicate ranking (TDD)

- [ ] **Step 1 — Write failing test:** build two small tibbles (obo: `MONDO:0032745 OMIM:618524 equivalentTo obo_xref`; sssom: same target `exactMatch sssom`) and assert `mondo_merge_xrefs` collapses to ONE row per `(mondo_id,target_prefix,target_id)` keeping `exactMatch` (rank 0 wins), and preserves the SSSOM `target_label`/`source` when the winner is the SSSOM row.
- [ ] **Step 2 — Run, verify FAIL.**
- [ ] **Step 3 — Implement** `mondo_merge_xrefs(obo_xrefs, sssom_xrefs)`: `dplyr::bind_rows`, add `prank = MONDO_PREDICATE_RANK[predicate]` (default 5L), `dplyr::group_by(mondo_id, target_prefix, target_id)`, `dplyr::slice_min(prank, n = 1, with_ties = FALSE)`, `dplyr::ungroup()`, drop `prank`. Coalesce `target_label` across the group (`dplyr::first(na.omit(...))`) so an OBO winner still gets the SSSOM label when available.
- [ ] **Step 4 — Run, verify PASS. Commit.**

### Task B5: Index write (DB; integration-style with test transaction)

- [ ] **Step 1 — Write test** in a new `api/tests/testthat/test-integration-mondo-index.R` guarded by DB availability (mirror an existing integration test's DB-skip helper). Use `with_test_db_transaction()`. Insert a tiny parsed OBO + SSSOM, call `mondo_index_write(conn, parsed, sssom_tbl, "2026-05-05")`, assert `mondo_term`/`mondo_xref` row counts and that the OMIM xref resolves.
- [ ] **Step 2 — Run, verify FAIL.**
- [ ] **Step 3 — Implement** `mondo_index_write(conn, parsed_obo, sssom_tbl, release_version)`: inside the caller's transaction, `DELETE FROM mondo_xref; DELETE FROM mondo_term;` (NOT `TRUNCATE` — it auto-commits and breaks rollback), then `DBI::dbAppendTable` term rows (add `release_version`) and merged xref rows (add `target_id_upper = toupper(target_id)`, `release_version`). Batch appends ≤5000 rows.
- [ ] **Step 4 — Run, verify PASS (or SKIP if no DB). Commit.**

### Task B6: Derive disease mappings + projection write (DB)

- [ ] **Step 1 — Write test** (in the same integration file): seed `disease_ontology_set` with `OMIM:618524` (base id) and the `mondo_xref` rows for `MONDO:0032745`. Call `disease_mapping_derive(conn, MONDO_TARGET_ALLOWLIST)` then `disease_mapping_write(conn, derived, "2026-05-05")`. Assert: a `sysndd_native` OMIM row exists; `mondo_id` resolved to `MONDO:0032745`; an `Orphanet:530983` row exists with `source="mondo_obo_xref"`/`predicate`; and `disease_ontology_set.MONDO`/`.Orphanet` projection columns are populated for that disease.
- [ ] **Step 2 — Run, verify FAIL.**
- [ ] **Step 3 — Implement** `disease_mapping_derive()` (SQL-driven; read `disease_ontology_set` distinct base `disease_ontology_id`):
  - native row per disease: `{target_prefix = prefix(disease_ontology_id), target_id = disease_ontology_id, source="sysndd_native", predicate=NA}`.
  - resolve hub: if `prefix(disease_ontology_id)=="MONDO"`, `mondo_id = disease_ontology_id`; else reverse-lookup `mondo_xref` by `target_id_upper = upper(disease_ontology_id)`, pick strongest predicate (`slice_min(prank)`), take its `mondo_id`. Emit a `MONDO` mapping row (`source="mondo_sssom"` when the resolving row’s origin is sssom else `mondo_obo_xref`).
  - target rows: for the resolved `mondo_id`, pull all `mondo_xref` whose `target_prefix %in% allowlist`, collapse strongest predicate per `(prefix,target_id)`, emit rows with `source = if(origin=="sssom") "mondo_sssom" else "mondo_obo_xref"`. Exclude a target row that duplicates the native anchor.
  - Return the contract tibble.
  `disease_mapping_write()`: in a transaction, `DELETE FROM disease_ontology_mapping;` then append derived rows (`is_active=1`, `target_id`, `release_version`). Then refresh projection columns: for each allowlist prefix, `UPDATE disease_ontology_set s JOIN (SELECT disease_ontology_id, GROUP_CONCAT(target_id SEPARATOR ';') g FROM disease_ontology_mapping WHERE target_prefix=? GROUP BY disease_ontology_id) m ON s.disease_ontology_id = m.disease_ontology_id SET s.<Col> = m.g, s.ontology_mapping_release = ?`. Only the four added columns (`UMLS,MedGen,NCIT,GARD`) plus existing `DOID,MONDO,Orphanet,EFO`.
- [ ] **Step 4 — Run, verify PASS (or SKIP). Commit** `git commit -am "feat(api): derive disease cross-ontology mappings + projection refresh"`.

### Task B7: Point SSSOM download at the full release

- [ ] **Step 1 — In `api/functions/mondo-functions.R`** add a new `download_mondo_sssom_full(output_path, force, sssom_url = NULL)` that resolves the URL from `DISEASE_ONTOLOGY_MONDO_SSSOM_URL` env → config → default `https://raw.githubusercontent.com/monarch-initiative/mondo/master/src/ontology/mappings/mondo.sssom.tsv`. Use `external_proxy_budget("mondo", ...)` for the request (no hardcoded timeout). Leave the existing OMIM-subset function intact for back-compat.
- [ ] **Step 2 — Test** the URL-resolution precedence with `withr::with_envvar` (no network): assert env beats default. Run, verify PASS.
- [ ] **Step 3 — Commit.** `git commit -am "feat(api): full MONDO SSSOM download with budgeted fetch"`.
- [ ] **Step 4 — Gate:** `make lint-api` (host) and `cd api && Rscript -e "testthat::test_dir('tests/testthat', filter='mondo|mapping')"`.

---

# WP-C — Refresh orchestration + admin + cron + bootstrap (Wave 3; depends on B)

Mirror `pubtatornidd_nightly` (orchestrator+lock+cron+bootstrap) and `analysis_snapshot` (shared-submit+admin). Read those files first and copy structure.

**Files:**
- Create: `api/functions/disease-ontology-mapping-refresh.R` (orchestrator)
- Create: `api/services/disease-ontology-mapping-service.R` (shared submit + status)
- Create: `api/endpoints/admin_ontology_mapping_endpoints.R`
- Create: `api/scripts/ontology_mapping_refresh_enqueue.R`
- Modify: `api/functions/async-job-handlers.R` (registry + handler)
- Modify: `api/bootstrap/load_modules.R` (add new function/service files to the source lists — covers API + durable worker)
- Modify: `api/bootstrap/mount_endpoints.R` (mount `/api/admin/ontology` before `/api/admin`)
- Modify: `api/start_sysndd_api.R` (bootstrap hook **only** — not the source list)
- Modify: `api/functions/async-job-handlers.R` + the `force_apply_ontology` endpoint (T-C7 re-trigger)
- Modify: `api/config.yml` (mondo urls), `docker-compose.yml` (+ `*.prod.yml`) (cron sidecar; worker egress already present)
- Test: `api/tests/testthat/test-unit-ontology-mapping-service.R`, `test-unit-ontology-mapping-refresh.R`, `test-unit-admin-ontology-mapping-endpoints.R`, `test-unit-ontology-refresh-chains-mapping.R`

**Interfaces:**
- Consumes from B: `mondo_obo_parse`, `mondo_sssom_parse`, `mondo_merge_xrefs`, `mondo_index_write`, `disease_mapping_derive`, `disease_mapping_write`, `download_mondo_sssom_full`, `MONDO_TARGET_ALLOWLIST`.
- Produces (consumed by H/tests): `disease_ontology_mapping_refresh_run(job, payload, progress)`, `service_disease_ontology_mapping_submit_refresh(force, stagger, submit_fn, exists_fn, conn, now, stagger_seconds)`, `service_disease_ontology_mapping_status()`, `disease_ontology_mapping_bootstrap_on_startup()`.

### Task C1: Orchestrator with single-flight lock (TDD where possible)

- [ ] **Step 1 — Read** `api/functions/pubtatornidd-nightly.R` end-to-end as the template.
- [ ] **Step 2 — Implement** `disease-ontology-mapping-refresh.R`:
  - `disease_ontology_mapping_try_lock(conn)` / `_release_lock(conn)` via `GET_LOCK('disease_ontology_mapping_refresh', 0)` / `RELEASE_LOCK`.
  - `disease_ontology_mapping_refresh_run(job, payload, progress = NULL)`:
    1. acquire lock non-blocking; if held → return `list(status="skipped", reason="lock_held")` (job completes successfully).
    2. resolve URLs (env→config→default), download OBO + SSSOM with conditional GET (persist validators); reset external accumulator per call (`external_proxy_request_reset()` if present).
    3. parse → merge → `mondo_index_write` → `disease_mapping_derive` → `disease_mapping_write`, **all inside one DB transaction** so a partial failure rolls back.
    4. write a `disease_ontology_mapping_meta` row (counts, durations, validators, `status="success"`).
    5. release lock; return structured summary. On any step error: write a `status="failed"` meta row, release lock, re-raise so the job is marked failed.
  - `progress()` calls mirror nddscore's reporter (steps/total).
- [ ] **Step 3 — Unit test** the lock-held skip path and the meta-row-on-failure path with injected fakes (no network/DB): pass a fake `conn` whose `GET_LOCK` returns 0 → assert `status=="skipped"`. Run, verify PASS.
- [ ] **Step 4 — Commit.** `git commit -m "feat(api): disease ontology mapping refresh orchestrator"`.

### Task C2: Register the async job handler

- [ ] **Step 1 — In `api/functions/async-job-handlers.R`** add `.async_job_run_disease_ontology_mapping_refresh <- function(job, payload, state, worker_config) disease_ontology_mapping_refresh_run(job, payload, .async_job_progress_reporter)` near the other handlers, and a registry entry `disease_ontology_mapping_refresh = list(cancel_mode = "non_interruptible", run = .async_job_run_disease_ontology_mapping_refresh, after_success = .async_job_after_success_noop)`.
- [ ] **Step 2 — Test** `async_job_get_handler("disease_ontology_mapping_refresh")` returns a list with a callable `run`. Run, verify PASS.
- [ ] **Step 3 — Commit.**

### Task C3: Shared submit + status service

- [ ] **Step 1 — Read** `api/services/analysis-snapshot-refresh-service.R` (`service_analysis_snapshot_submit_refresh`, `…_status`, `…_bootstrap_enabled`, stagger logic) as the template.
- [ ] **Step 2 — Implement** `disease-ontology-mapping-service.R`:
  - `service_disease_ontology_mapping_submit_refresh(force = FALSE, stagger = FALSE, submit_fn = async_job_service_submit, exists_fn = disease_ontology_mapping_build_exists, conn = NULL, now = Sys.time(), stagger_seconds = NULL)` — if `!force && exists_fn()` and not stagger-bootstrap, skip; else `submit_fn(job_type="disease_ontology_mapping_refresh", request_payload=list(force=force), queue_name="default", priority=50L, max_attempts=3L, scheduled_at = if (stagger) now + stagger_seconds else now, conn=conn)`. Return `list(submitted=…, duplicate=…, job_id=…)`.
  - `disease_ontology_mapping_build_exists()` — `SELECT 1 FROM disease_ontology_mapping_meta WHERE status='success' LIMIT 1`.
  - `service_disease_ontology_mapping_status()` — latest meta row(s) as a structured list.
  - `disease_ontology_mapping_bootstrap_enabled()` — env `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP` (default true).
  - `disease_ontology_mapping_bootstrap_on_startup()` — if enabled and `!build_exists()`, call submit with `stagger=TRUE`, `stagger_seconds = as.integer(Sys.getenv("DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_STAGGER_SECONDS","360"))`; never throw.
- [ ] **Step 3 — Unit test** with injected `submit_fn`/`exists_fn` fakes: (a) `force=FALSE` + exists → no submit; (b) `force=TRUE` → submit at `now`; (c) bootstrap + not-exists → submit at `now + stagger`. Run, verify PASS.
- [ ] **Step 4 — Commit.** `git commit -m "feat(api): shared submit/status/bootstrap for ontology mapping refresh"`.

### Task C4: Admin endpoints

- [ ] **Step 1 — Read** `api/endpoints/admin_analysis_snapshot_endpoints.R` as the template.
- [ ] **Step 2 — Implement** `admin_ontology_mapping_endpoints.R`:
  - `POST /api/admin/ontology/mappings/refresh` — `require_role(req,res,"Administrator")`; parse optional `force`; call `service_disease_ontology_mapping_submit_refresh(force = isTRUE(force))`; `res$status <- 202L`; return the submit outcome.
  - `GET /api/admin/ontology/mappings/status` — Administrator-gated; return `service_disease_ontology_mapping_status()`.
- [ ] **Step 3 — Mount** in `api/bootstrap/mount_endpoints.R`: add `pr_mount("/api/admin/ontology", mount_endpoint("endpoints/admin_ontology_mapping_endpoints.R"))` **before** the `/api/admin` mount. Add the public read mount note here only if WP-D hasn't (coordinate; D owns `/api/disease`).
- [ ] **Step 4 — Test** the role gate: a non-admin request → 403; mounted via `mount_endpoint` so a thrown `stop_for_bad_request` maps to problem+json (reuse the pattern from `test-unit-endpoint-error-handler.R`). Run, verify PASS.
- [ ] **Step 5 — Commit.** `git commit -m "feat(api): admin endpoints to refresh/inspect ontology mappings"`.

### Task C5: Bootstrap hook + source order + config

- [ ] **Step 1 — Source the new files via `api/bootstrap/load_modules.R`** (correction #4 — NOT `start_sysndd_api.R`). In `bootstrap_load_modules()` add `functions/mondo-index-builder.R`, `functions/disease-ontology-mapping-builder.R`, `functions/disease-ontology-mapping-repository.R`, `functions/disease-ontology-mapping-refresh.R` to the `function_files` vector (before `services`), and `services/disease-ontology-mapping-service.R` to the `service_files` vector. This one list is loaded by the API (`start_sysndd_api.R:76`) **and** the durable async worker (`start_async_worker.R:6`), so the worker that runs the job gets the code. No `setup_workers.R` (mirai) change — this isn't a daemon job. Restart the worker container after deploy.
- [ ] **Step 1b — Add only the bootstrap hook to `api/start_sysndd_api.R`** after migrations and after the existing snapshot/pubtatornidd bootstraps:
```r
tryCatch(
  disease_ontology_mapping_bootstrap_on_startup(),
  error = function(e) message(sprintf("[ontology-mapping-bootstrap] skipped: %s", conditionMessage(e)))
)
```
- [ ] **Step 2 — In `api/config.yml`** add under the appropriate block: `mondo_obo_url`, `mondo_sssom_url` defaults (mirror nddscore’s config pattern). Do not bake secrets.
- [ ] **Step 3 — Smoke** locally: restart API, confirm boot logs show the bootstrap line and the API stays up. Commit `git commit -m "feat(api): wire ontology mapping bootstrap + config"`.

### Task C6: Cron sidecar + enqueue script

- [ ] **Step 1 — Read** `api/scripts/pubtatornidd_nightly_enqueue.R` and the `pubtatornidd-cron` Compose service.
- [ ] **Step 2 — Implement** `api/scripts/ontology_mapping_refresh_enqueue.R`: bootstrap config/pool like the pubtatornidd script, then `service_disease_ontology_mapping_submit_refresh(force = FALSE)` (or `async_job_service_submit` directly), exit 0 on success/duplicate, non-zero on failure.
- [ ] **Step 3 — Add `ontology-mapping-cron` service** to `docker-compose.yml` (and prod compose) modeled on `pubtatornidd-cron`: same image, `backend` network only (no egress), a weekly scheduler loop (`ONTOLOGY_MAPPING_REFRESH_AT` weekday/time env) running the enqueue script. Confirm the **worker** is on the `proxy` network (egress) — it already must be for Gemini/PubMed; no change expected, but verify.
- [ ] **Step 4 — Commit.** `git commit -m "feat(ops): weekly cron sidecar for ontology mapping refresh"`.
- [ ] **Step 5 — Gate:** `make test-api-fast` and `make lint-api`.

### Task C7: Re-trigger mapping refresh after an operator ontology refresh (correction #2)

**Why:** `refresh_disease_ontology_set()` does `DELETE FROM disease_ontology_set` + re-append (`metadata-refresh.R:99`), and the combine logic doesn't rebuild the projection columns — so any operator ontology refresh leaves the new columns blank and the normalized `disease_ontology_mapping` rows pointing at base ids that may have changed. A successful ontology refresh must enqueue a `disease_ontology_mapping_refresh`.

**Files:** Modify the two ontology-refresh completion sites — the async ontology refresh handler (grep `async-job-handlers.R` for the ontology/`process_combine_ontology` job) and the force-apply path (`PUT /api/admin/force_apply_ontology`, grep `force_apply` across `api/endpoints/`).

- [ ] **Step 1 — Locate** both sites where `refresh_disease_ontology_set()` completes successfully (the normal ontology async job `after_success`/run tail, and the `force_apply_ontology` handler tail).
- [ ] **Step 2 — After each successful `refresh_disease_ontology_set()`**, call `service_disease_ontology_mapping_submit_refresh(force = TRUE)` (force because the disease set changed; dedup-safe). Wrap in `tryCatch` so a submission hiccup does not fail the ontology refresh itself — log and continue.
- [ ] **Step 3 — Test:** unit-test the chaining with an injected `submit_fn` spy — assert that a simulated successful ontology refresh calls the mapping-refresh submit exactly once with `force = TRUE`. Run, verify PASS.
- [ ] **Step 4 — Commit.** `git commit -m "feat(api): refresh ontology mappings after an ontology-set refresh"`.

---

# WP-D — Read API: mappings endpoint (Wave 2; depends on A contract)

**Files:**
- Create: `api/endpoints/disease_mapping_endpoints.R`
- Create: `api/functions/disease-ontology-mapping-repository.R` (read-only)
- Modify: `api/bootstrap/mount_endpoints.R` (mount `/api/disease`)
- Test: `api/tests/testthat/test-unit-disease-mapping-endpoint.R`, `test-unit-cheap-route-isolation.R` (extend allow-list)

**Interfaces:**
- Produces: `GET /api/disease/mappings` (contract §7); repository `disease_mapping_for_disease(disease_ontology_id) -> grouped list`, `disease_mapping_for_entity(entity_id) -> grouped list` (resolves entity→base disease id via `ndd_entity`/`disease_ontology_set`).

### Task D1: Repository read function (TDD via DB or pure-shape test)

- [ ] **Step 1 — Write test** in `test-unit-disease-mapping-endpoint.R` for the **grouping shape**: feed `disease_mapping_group_rows(rows_tbl)` a small tibble of mapping rows and assert it returns `list(mappings = list(MONDO=..., Orphanet=...), mondo_id=...)` with each entry `list(id,label,predicate,source)` and prefixes ordered per `MONDO_TARGET_ALLOWLIST`. (Pure function, no DB.)
- [ ] **Step 2 — Run, verify FAIL.**
- [ ] **Step 3 — Implement** `disease-ontology-mapping-repository.R`:
  - `disease_mapping_group_rows(rows)` — pure: split by `target_prefix`, order groups by allowlist, build the per-row lists; derive `mondo_id` from the `MONDO` group’s first id.
  - `disease_mapping_for_disease(disease_ontology_id, conn = NULL)` — `SELECT … FROM disease_ontology_mapping WHERE disease_ontology_id = ? AND is_active = 1`; join `disease_ontology_set` for `disease_ontology_name` + `ontology_mapping_release`; `status = if (nrow==0) "missing" else "current"`; return the grouped object.
  - `disease_mapping_for_entity(entity_id, conn = NULL)` — **resolve through `ndd_entity_view`, NOT raw `ndd_entity`** (binding correction #1): `SELECT disease_ontology_id_version FROM ndd_entity_view WHERE entity_id = ?`. This matches the public entity-list surface (`entity_endpoints.R:92`); an entity absent from the view (inactive / not public) yields **zero rows → return `status:"missing"`** and never leaks mappings. Then map `disease_ontology_id_version → base disease_ontology_id` (join `disease_ontology_set` for the base `disease_ontology_id`) and delegate to `disease_mapping_for_disease`. Use `DBI::dbBind` with `unname(params)`.
- [ ] **Step 4 — Run, verify PASS. Commit.** `git commit -m "feat(api): disease mapping read repository"`.

### Task D2: Endpoint + mount + cheap-route isolation

- [ ] **Step 1 — Write endpoint test** asserting: `?entity_id=` and `?disease_ontology_id=` both resolve; missing/both-absent → `stop_for_bad_request` (problem+json 400); unknown disease → `status:"missing"` 200; **an `entity_id` that exists but is absent from `ndd_entity_view` (inactive/non-public) → `status:"missing"` 200, no mapping rows leaked** (correction #1; DB-or-mocked integration check). (Mock the repository for the shape cases.)
- [ ] **Step 2 — Run, verify FAIL.**
- [ ] **Step 3 — Implement** `disease_mapping_endpoints.R`: a single `GET /mappings` handler. Validate exactly one of `entity_id`/`disease_ontology_id` is present (unwrap Plumber array-scalars). Call the repository. Return the grouped JSON. No external calls.
- [ ] **Step 4 — Mount** at `/api/disease` via `mount_endpoint()` in `mount_endpoints.R`.
- [ ] **Step 5 — Extend `test-unit-cheap-route-isolation.R`** to assert `/api/disease` does not reference any external fetcher (it’s DB-only). Run, verify PASS.
- [ ] **Step 6 — Commit.** `git commit -m "feat(api): public GET /api/disease/mappings endpoint"`.
- [ ] **Step 7 — Gate:** `make test-api-fast`, `make lint-api`.

### Task D3: Surface the new projection columns on `/api/ontology` (correction #3)

**Files:** Modify `api/endpoints/ontology_endpoints.R:58-69` (the `select(...)` list in the `@get <ontology_input>` handler).

- [ ] **Step 1 — Read** `ontology_endpoints.R:32-80`. The `select()` currently lists `DOID, MONDO, Orphanet, EFO`.
- [ ] **Step 2 — Add** `UMLS, MedGen, NCIT, GARD, ontology_mapping_release` to that `select()` so the existing ontology lookup returns the full projection set (the columns added in migration 036). Keep the existing `group_by(disease_ontology_id) %>% summarize_all(paste(unique(.), collapse=";"))` aggregation — the new columns flow through unchanged.
- [ ] **Step 3 — Test:** extend the ontology endpoint's test (or add one) asserting the response includes the five new keys for a disease that has them. If no test file exists for this endpoint, add a minimal one. Run, verify PASS.
- [ ] **Step 4 — Commit.** `git commit -m "feat(api): expose UMLS/MedGen/NCIT/GARD on /api/ontology"`.

> **Coordination:** the frontend `OntologyTerm` type (`app/src/api/ontology.ts:40`) must mirror these new keys — done in WP-E Task E5.

---

# WP-E — Frontend foundation (Wave 2; depends on D contract)

**Files:**
- Modify: `app/src/assets/js/constants/ontology_links.ts` (add prefix→URL helpers + dispatcher)
- Create: `app/src/api/disease-mappings.ts` (typed client + types)
- Create: `app/src/composables/useEntityMappings.ts` (SWR hook)
- Create: `app/src/components/disease/LinkedOntologies.vue` (grouped outlink badges)
- Test: `app/src/assets/js/constants/ontology_links.spec.ts`, `app/src/components/disease/LinkedOntologies.spec.ts`

**Interfaces:**
- Produces (consumed by F, G): `ontologyOutlink(prefix, id) -> { url: string | null; label: string }`; `getEntityMappings(entityId)`, `getDiseaseMappings(diseaseId)`; `DiseaseMappingResponse` type; `useEntityMappings(entityIdRef)` returning a `ResourceState<DiseaseMappingResponse|null>`; `<LinkedOntologies :data layout="strip|card" />`.

### Task E1: URL templates (TDD)

- [ ] **Step 1 — Write** `ontology_links.spec.ts`:
```ts
import { describe, it, expect } from 'vitest';
import { ontologyOutlink } from '@/assets/js/constants/ontology_links';
describe('ontologyOutlink', () => {
  it('builds OMIM/MONDO/Orphanet/DOID urls', () => {
    expect(ontologyOutlink('OMIM','OMIM:618524').url).toBe('https://www.omim.org/entry/618524');
    expect(ontologyOutlink('MONDO','MONDO:0032745').url).toBe('http://purl.obolibrary.org/obo/MONDO_0032745');
    expect(ontologyOutlink('Orphanet','Orphanet:530983').url).toContain('orpha.net');
    expect(ontologyOutlink('DOID','DOID:0081234').url).toBe('https://disease-ontology.org/term/DOID:0081234');
  });
  it('returns null url for UMLS (no clean deep-link) and keeps the full CURIE label', () => {
    const out = ontologyOutlink('UMLS','UMLS:C1234567'); // full CURIE per correction #6
    expect(out.url).toBeNull();
    expect(out.label).toBe('UMLS:C1234567');
  });
});
```
- [ ] **Step 2 — Run, verify FAIL:** `cd app && npx vitest run src/assets/js/constants/ontology_links.spec.ts`.
- [ ] **Step 3 — Implement** the helpers in `ontology_links.ts` (reuse the templates already hardcoded in `OntologyView.vue`): OMIM `https://www.omim.org/entry/<digits>`, MONDO `http://purl.obolibrary.org/obo/MONDO_<digits>`, Orphanet `https://www.orpha.net/en/disease/detail/<digits>` (or the existing OC_Exp template — match `OntologyView.vue`), DOID `https://disease-ontology.org/term/<DOID:id>`, MedGen `https://www.ncbi.nlm.nih.gov/medgen/<id>`, NCIT EVS browser, GARD `https://rarediseases.info.nih.gov/diseases/<id>`, EFO EBI OLS, UMLS → `null`. `ontologyOutlink(prefix,id)` dispatches and returns `{ url, label: id }`.
- [ ] **Step 4 — Run, verify PASS. Commit.** `git commit -m "feat(app): centralize ontology outlink URL templates"`.

### Task E2: Typed client + types

- [ ] **Step 1 — Implement** `app/src/api/disease-mappings.ts`: `DiseaseMappingEntry { id: string; label: string|null; predicate: string|null; source: string }`, `DiseaseMappingResponse { disease_ontology_id: string; disease_ontology_name: string; mondo_id: string|null; release_version: string|null; status: 'current'|'missing'; mappings: Record<string, DiseaseMappingEntry[]> }`, and `getEntityMappings(entityId, config?)`/`getDiseaseMappings(diseaseId, config?)` using the shared `apiClient`. Unwrap any array-scalars from Plumber.
- [ ] **Step 2 — Type-check:** `cd app && npm run type-check`. Commit.

### Task E3: SWR composable

- [ ] **Step 1 — Implement** `useEntityMappings.ts` mirroring an existing per-source hook (e.g. `useEntityPublications.ts`): `useResource` keyed by `entity_id`, fetcher = `getEntityMappings`. Lazy (caller controls when the key becomes non-null).
- [ ] **Step 2 — Type-check. Commit.**

### Task E4: `LinkedOntologies.vue` (component test)

- [ ] **Step 1 — Write** `LinkedOntologies.spec.ts`: mount with a `DiseaseMappingResponse` containing MONDO+Orphanet+UMLS; assert MONDO/Orphanet render as `<a target="_blank">` with the right hrefs, UMLS renders as a non-link badge, and an empty `mappings` object renders nothing (group hidden). Assert `status:"missing"` shows a subtle “mappings being prepared” note.
- [ ] **Step 2 — Run, verify FAIL.**
- [ ] **Step 3 — Implement** `LinkedOntologies.vue`: props `{ data: DiseaseMappingResponse | null; loading?: boolean; layout?: 'strip'|'card' }`. Iterate prefixes in allowlist order; per group render `ResourceLink` (compact) when `ontologyOutlink().url` is non-null, else a plain badge. `layout="strip"` = inline flex-wrap; `layout="card"` = labeled rows. Respect `prefers-reduced-motion`; add `rel="noopener"`.
- [ ] **Step 4 — Run, verify PASS. Commit.** `git commit -m "feat(app): LinkedOntologies outlink component"`.
- [ ] **Step 5 — Gate:** `cd app && npm run lint && npm run type-check && npx vitest run src/components/disease src/assets/js/constants`.

### Task E5: Mirror the new projection keys in the `OntologyTerm` type (correction #3)

**Files:** Modify `app/src/api/ontology.ts:32-46` (the `OntologyTerm` interface).

- [ ] **Step 1 — Add** `UMLS: string[]`, `MedGen: string[]`, `NCIT: string[]`, `GARD: string[]`, `ontology_mapping_release: string[]` to `OntologyTerm`, matching the new keys WP-D Task D3 returns from `/api/ontology` (Plumber array-wraps; keep `string[]` like the existing `DOID/MONDO/Orphanet/EFO`).
- [ ] **Step 2 — Type-check:** `cd app && npm run type-check`. Expected PASS.
- [ ] **Step 3 — Commit.** `git commit -m "feat(app): extend OntologyTerm with new cross-ontology keys"`.

---

# WP-F — Entities list: expandable row (Wave 3; depends on E)

**Correction #5:** `GenericTable` already has the `details` toggle column (`GenericTable.vue:489`) and a `#row-expansion` slot (`GenericTable.vue:496`); `TablesEntities` already renders `details` + `fields_details` (`TablesEntities.vue:459,464`). **Extend that existing expansion — do NOT add a second expansion system, prop, or toggle.**

**Files:**
- Modify: `app/src/components/tables/TablesEntities.vue` (override the `#row-expansion` slot to append a mappings strip; add the lazy hook)
- Modify: `app/src/components/tables/EntitiesMobileRows.vue` (add the mappings strip inside the existing Details collapse)
- Test: `app/src/components/tables/TablesEntities.spec.ts` (extend)

### Task F1: Append ontology outlinks to the existing row expansion

- [ ] **Step 1 — Read** `GenericTable.vue:488-520` (the `#row-expansion` slot + `fieldDetails`) and `TablesEntities.vue:440-480` (the existing `details` column + `fields_details`) and `EntitiesMobileRows.vue` to see exactly how the current detail card renders.
- [ ] **Step 2 — In `TablesEntities.vue`, override the `<template #row-expansion="{ row, toggle }">` slot** so the existing detail card still renders AND, below it, a "Linked ontologies" strip. On first expansion of a row, set the `useEntityMappings` key to `row.entity_id` (lazy — keyed reactive so the fetch only fires for expanded rows) and render `<LinkedOntologies layout="strip" :data="mappings.data.value" :loading="mappings.loading.value" />`. Do not introduce a new toggle — reuse `GenericTable`'s `toggleExpansion`/`details` column. (If a single shared `useEntityMappings` key can't serve multiple simultaneously-expanded rows, key a small per-row map of resources, or fetch on expand into a `Map<entityId, resource>`.)
- [ ] **Step 3 — Mirror** in `EntitiesMobileRows.vue`: add the same `LinkedOntologies` strip inside the existing Details collapse block (the mobile rows already have the Details button pattern).
- [ ] **Step 4 — Test:** extend `TablesEntities.spec.ts` to assert that expanding a row (via the existing `details` toggle) renders `LinkedOntologies` and triggers the mappings fetch (mock the composable/client). Run, verify PASS.
- [ ] **Step 5 — Commit.** `git commit -m "feat(app): ontology outlinks in the existing Entities row expansion"`.
- [ ] **Step 6 — Gate:** `npm run lint && npm run type-check && npx vitest run src/components/tables`.

---

# WP-G — Entity detail: disease card (Wave 3; depends on E)

**Files:**
- Modify: `app/src/views/pages/EntityView.vue` (add SectionCard; remove half-wired `mondoEquivalent` plain text)
- Test: `app/src/views/pages/EntityView.spec.ts` (extend if present, else add a focused spec)

### Task G1: "Linked disease ontologies" SectionCard

- [ ] **Step 1 — Add** `const mappings = useEntityMappings(entityIdStr)` alongside the existing per-source hooks (fires in parallel on mount).
- [ ] **Step 2 — Add** a `<SectionCard title="Linked disease ontologies">` after the hero, before Clinical Synopsis, rendering `<LinkedOntologies layout="card" :data="mappings.data.value" :loading="mappings.loading.value" />`. Wire `empty`/`error` states from the resource. Remove the old plain-text `mondoEquivalent` pill.
- [ ] **Step 3 — Test:** with a mocked `useEntityMappings`, assert the card renders the MONDO/Orphanet outlinks and that the old plain-text MONDO pill is gone. Run, verify PASS.
- [ ] **Step 4 — Commit.** `git commit -m "feat(app): linked disease ontologies card on the entity page"`.
- [ ] **Step 5 — Gate:** `npm run lint && npm run type-check && npx vitest run src/views/pages`.

---

# WP-H — Docs, invariants, integration, SEO (Wave 4; depends on C, D, F, G)

**Files:**
- Modify: `AGENTS.md` (new architecture-invariant section)
- Modify: `documentation/08-development.qmd`, `documentation/09-deployment.qmd`
- Modify: `db/migrations/README.md` (if used for notes)
- Create: `api/tests/testthat/test-integration-ontology-mapping-refresh.R` (end-to-end on fixtures)

### Task H1: Architecture invariant in AGENTS.md

- [ ] **Step 1 — Add** a "Disease cross-ontology mappings" subsection under Architecture Invariants: sources (`mondo.obo`+`mondo.sssom.tsv`), MONDO-as-hub, the four tables + projection columns, `ndd_entity_view` intentionally untouched (frontend reads `/api/disease/mappings`), the `disease_ontology_mapping_refresh` job + advisory lock + cron sidecar + staggered bootstrap, the public `/api/disease/mappings` read endpoint (cheap/DB-only) **resolving entities through `ndd_entity_view` (public surface only)**, the admin `/api/admin/ontology/mappings/*` endpoints (mount-before-`/api/admin`), and the frontend lazy-fetch + central `ontology_links.ts`. Record the binding rules: **an operator ontology refresh (`refresh_disease_ontology_set`) MUST chain `disease_ontology_mapping_refresh(force=TRUE)`** (else projection columns drift); **`OMIMPS` is never canonicalized to OMIM**; **`target_id` is a full CURIE (incl. `UMLS:`)**; new files are sourced via `bootstrap_load_modules()` (covers API + durable worker); and the `disease_ontology_id` join key is pinned to utf8mb3 collation.
- [ ] **Step 2 — Commit.** `git commit -m "docs: AGENTS.md invariant for disease ontology mappings"`.

### Task H2: Dev + deployment docs

- [ ] **Step 1 — `08-development.qmd`:** how to trigger a refresh locally (admin endpoint / enqueue script), where the fixtures live, how to run the mapping tests.
- [ ] **Step 2 — `09-deployment.qmd`:** the `ontology-mapping-cron` sidecar, env vars (`DISEASE_ONTOLOGY_MONDO_OBO_URL/_SSSOM_URL`, bootstrap gate + stagger), worker egress requirement, weekly cadence.
- [ ] **Step 3 — Commit.**

### Task H3: End-to-end integration test

- [ ] **Step 1 — Write** `test-integration-ontology-mapping-refresh.R`: with `with_test_db_transaction()`, stub the two downloads to return the `mondo-mini` fixtures, run `disease_ontology_mapping_refresh_run(...)`, assert `mondo_term`/`mondo_xref`/`disease_ontology_mapping` populated, projection columns set, and a `success` meta row written. Assert a second run with both downloads 304 → `status="skipped"` and no row churn.
- [ ] **Step 2 — Run, verify PASS (or SKIP without DB).**
- [ ] **Step 3 — SEO gate:** `make verify-seo-app` (the detail card is client-fetched; confirm no prerender regression).
- [ ] **Step 4 — Full gates:** `make code-quality-audit`, `make ci-local` (or `make test-api` + frontend gates). Commit `git commit -m "test: end-to-end disease ontology mapping refresh"`.

---

## Self-Review (completed by author)

**Spec coverage:** §4 schema → WP-A; §5 ingestion → WP-B; §6 refresh/admin/cron/bootstrap → WP-C; §7 read API → WP-D; §8 frontend → WP-E/F/G; §12 testing → folded per task + WP-H; §13 docs → WP-H. Non-goals (§9) intentionally excluded. No gaps.

**Placeholder scan:** No "TBD/handle edge cases/write tests for the above". Mirror-tasks (C1–C6) name the exact template file + the concrete deltas, which is the real implementation instruction, not a placeholder.

**Type/name consistency:** `disease_ontology_mapping_refresh` (job type = lock name) used consistently; `disease_mapping_for_entity/_for_disease`, `disease_mapping_derive/_write`, `mondo_index_write`, `service_disease_ontology_mapping_submit_refresh`, `useEntityMappings`, `ontologyOutlink`, `LinkedOntologies` referenced identically across producing and consuming tasks. Endpoint `/api/disease/mappings` and admin `/api/admin/ontology/mappings/*` consistent between WP-C/D and WP-H. Migration `036`/`34L` consistent between Global Constraints and WP-A.

**Review corrections (Codex, 2026-06-20):** all 8 findings folded in and verified against live code — #1 `ndd_entity_view` resolution (T-D1), #2 ontology-refresh chaining (T-C7), #3 `/api/ontology` + `OntologyTerm` columns (T-D3/T-E5), #4 `load_modules.R` sourcing (T-C5), #5 reuse existing `#row-expansion` (T-F1), #6 full-CURIE UMLS (Frozen Contract/T-E1), #7 no OMIMPS→OMIM (T-B1), #8 utf8mb3 join-key collation (T-A1). See "Review Corrections (binding)" near the top.
