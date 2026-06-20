# WP-B Implementation Report: R Parsing & DB Write-Path

Branch: `worktree-agent-a6ef7547ee39d2c37` (off master, TDD implementation)  
Date: 2026-06-20

---

## Files Created

| File | Description |
|------|-------------|
| `api/functions/mondo-index-builder.R` | B1-B5: CURIE normalization, SSSOM parser, OBO parser, xref merge, DB write |
| `api/functions/disease-ontology-mapping-builder.R` | B6: disease mapping derive + write + projection refresh |
| `api/tests/testthat/test-unit-mondo-index-builder.R` | B1-B4 unit tests (29 tests) |
| `api/tests/testthat/test-integration-mondo-index.R` | B5+B6 integration tests (4 tests, skip if no DB) |
| `api/tests/testthat/test-unit-disease-ontology-mapping-builder.R` | B6+B7 unit/mock tests (16 tests) |
| `api/tests/testthat/fixtures/mondo-mini.sssom.tsv` | B2 SSSOM fixture (3 data rows, real tabs) |
| `api/tests/testthat/fixtures/mondo-mini.obo` | B3 OBO fixture (3 terms, xrefs, obsolete) |
| `db/migrations/036_add_disease_ontology_mappings.sql` | Schema: mondo_term, mondo_xref, disease_ontology_mapping, disease_ontology_mapping_meta, ALTER disease_ontology_set |

## Files Modified

| File | Change |
|------|--------|
| `api/functions/mondo-functions.R` | Added `download_mondo_sssom_full()` (B7) |
| `api/functions/migration-manifest.R` | Included from feat branch |

---

## Commit SHAs

| Commit | SHA | Description |
|--------|-----|-------------|
| B1-B4 | `43b6cb95` | CURIE normalization, SSSOM/OBO parsers, xref merge |
| B5-B7 | `42ba5e26` | MONDO index write, disease mapping derive+write, full SSSOM download |
| lint fix | `96b616a8` | Replace semicolons with newlines (lintr) |

---

## Test Results by Task

| Task | Command | Result |
|------|---------|--------|
| B1 (CURIE norm) | `test_dir(..., filter='mondo|mapping')` | PASS 7/7 |
| B2 (SSSOM parser) | same | PASS 3/3 |
| B3 (OBO parser) | same | PASS 6/6 |
| B4 (xref merge) | same | PASS 3/3 |
| B5 (index write) | integration, needs DB | SKIP (no DB) |
| B6 (mapping derive+write) | integration: 2 DB + 3 mock | DB: SKIP; mock: PASS 3/3 |
| B7 (SSSOM download) | unit tests | PASS 4/4 |
| **Total** | `test_dir(filter='mondo|mapping')` | **FAIL 0 \| SKIP 5 \| PASS 84** |

Skips are expected: 5 skips for tests requiring live test DB (migration 036 not yet applied) or network access.

---

## Lint

`make lint-api` — **0 issues** across 134 R files after fixing semicolon compound statements in `disease-ontology-mapping-builder.R`.

---

## Key Implementation Decisions

### B1 — CURIE normalization
- `OMIMPS` deliberately absent from `.MONDO_PREFIX_ALIASES` (correction #7) — phenotypic series IDs stay as-is and are dropped by allowlist downstream
- `mondo_curie_prefix()` and `mondo_normalize_curie()` handle NA, bare strings, and unknown prefixes gracefully

### B2 — SSSOM parser
- `readr::read_tsv` (backed by vroom) requires binary connection; `textConnection()` fails silently with "can only read from binary connection". Fixed by stripping `#` comment lines manually then passing filtered text via `I()` — the only vroom-compatible approach for in-memory text

### B3 — OBO parser
- Line-by-line state machine, not regex over whole file — handles arbitrary stanza ordering
- `{source="MONDO:equivalentTo"}` annotation → predicate = "equivalentTo"; absent annotation → "xref"
- Only `MONDO:\d{7}` ids are kept; HP:, CHEBI:, etc. are silently skipped

### B4 — Merge
- `MONDO_PREDICATE_RANK`: `exactMatch=0` beats `equivalentTo=1` beats `closeMatch=2` beats `narrowMatch=3` beats `broadMatch=4` beats `xref=5`
- `target_label` coalesced from any row in the group (not just the best-rank row)

### B5 — DB write
- `DELETE FROM` (never `TRUNCATE`) — TRUNCATE is DDL, auto-commits, breaks rollback
- Batch insert at 5000 rows via `.mondo_batch_append()`
- `target_id_upper = toupper(target_id)` added for case-insensitive lookup index

### B6 — Disease mapping derive
- SQL-driven: pulls `disease_ontology_id` from `disease_ontology_set` and all `mondo_xref` rows into R memory once — avoids N+1 queries
- Three row types per disease: `sysndd_native` (always), MONDO hub (if resolved), downstream cross-ontology (for each allowlisted prefix from hub's xrefs)
- Projection columns (UMLS, MedGen, NCIT, GARD) updated via SQL JOIN; missing columns silently skipped

### B7 — Full SSSOM download
- URL resolution: `sssom_url` arg → `DISEASE_ONTOLOGY_MONDO_SSSOM_URL` env → `config$mondo_sssom_url` → built-in default
- `external_proxy_budget("mondo")` for `timeout_seconds`, `max_seconds`, `max_tries` — no hardcoded literals

---

## Concerns / Follow-Up

1. **Integration tests need migration 036 applied to test DB** — the B5 and B6 integration tests skip on CI until the test DB is migrated. This is correct behavior; they will activate automatically once migration 036 is part of the test setup.
2. **`disease_mapping_derive` loads all `mondo_xref` rows into R memory** — appropriate for the MONDO xref table (tens of thousands of rows). If the table grows to millions, a cursor-based approach would be needed.
3. **`disease_mapping_write` projection UPDATE** uses a simplified `GROUP BY disease_ontology_id` without explicit predicate ordering — picks first target_id per prefix. For production, a ranked subquery would be more deterministic; this is acceptable for now given the allowlist filtering.
4. **`mondo-functions.R` has `require(tidyverse)`** at file top (pre-existing). The warnings in test output are expected and not caused by WP-B changes.

---

## Fix pass

Commit: `ca0e4045`  
Date: 2026-06-20

### Fixes applied

| ID | Fix | File(s) |
|----|-----|---------|
| C1 | Added `DOID/MONDO/Orphanet/EFO` to `.MAPPING_PREFIX_COLUMN` (was only 4, now all 8); removed wrong comment | `disease-ontology-mapping-builder.R` |
| C2 | Reset all 8 columns to NULL before write; populate via `GROUP_CONCAT(DISTINCT … ORDER BY … SEPARATOR ';')` per-prefix grouped by disease_ontology_id | `disease-ontology-mapping-builder.R` |
| I3 | Replaced `paste0("… '", release_version, "' …")` interpolation with `DBI::dbExecute(conn, "… = ? …", params = unname(list(…)))` for both per-prefix UPDATE and ontology_mapping_release UPDATE | `disease-ontology-mapping-builder.R` |
| I2 | Removed verbatim `.MONDO_PREFIX_ALIASES_FOR_DERIVE()` copy; now delegates to `.MONDO_PREFIX_ALIASES` from `mondo-index-builder.R` | `disease-ontology-mapping-builder.R` |
| I1 | `.map_predicate` inside `mondo_sssom_parse` now maps `equivalentClass` / `owl:equivalentClass` / bare `equivalentTo` short-forms to `"equivalentTo"` | `mondo-index-builder.R` |
| M1 | Extracted `.resolve_sssom_url()` helper from `download_mondo_sssom_full`; replaced tautological env-read test with 3 targeted resolution tests (arg → env → default) | `mondo-functions.R`, `test-unit-disease-ontology-mapping-builder.R` |
| I4 | Added projection-column assertions after `disease_mapping_write` in integration test: checks `MONDO` and `Orphanet` are non-NULL and contain the expected CURIEs | `test-integration-mondo-index.R` |

### Unit test results (host)

```
# test-unit-mondo-index-builder.R
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-mondo-index-builder.R')"
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 31 ]
# (was 19 before I1 test added; +12 from duplicated run, net unique: 31)

# test-unit-disease-ontology-mapping-builder.R
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-disease-ontology-mapping-builder.R')"
[ FAIL 0 | WARN 8 | SKIP 0 | PASS 19 ]
# 8 WARNings are pre-existing host-R missing tidyverse/fs (container-only); not failures
```

### Dev-DB rollback probe output (C1/C2/I4 verification)

Ran `/tmp/sysndd_probe_c1c2.R` inside `sysndd-api-1` against `sysndd_db` via `START TRANSACTION … ROLLBACK`. Seeded 1 mondo_term + 8 mondo_xref rows (one per target prefix: OMIM=anchor, plus Orphanet, DOID, EFO, UMLS, MedGen, NCIT, GARD). Matched to real `disease_ontology_id = OMIM:100100`.

```
=== Derived rows: 6774
=== Unique target prefixes: MONDO, OMIM, DOID, EFO, GARD, MedGen, NCIT, Orphanet, UMLS
=== Rows for OMIM:100100 : 9
  disease_ontology_id target_prefix target_id       source         predicate
1 OMIM:100100         OMIM          OMIM:100100     sysndd_native  NA
2 OMIM:100100         MONDO         MONDO:0032745   mondo_obo_xref equivalentTo
3 OMIM:100100         DOID          DOID:0081234    mondo_sssom    exactMatch
4 OMIM:100100         EFO           EFO:0004190     mondo_sssom    exactMatch
5 OMIM:100100         GARD          GARD:0009849    mondo_sssom    exactMatch
6 OMIM:100100         MedGen        MedGen:C3714756 mondo_sssom    exactMatch
7 OMIM:100100         NCIT          NCIT:C92168     mondo_sssom    exactMatch
8 OMIM:100100         Orphanet      Orphanet:530983 mondo_sssom    exactMatch
9 OMIM:100100         UMLS          UMLS:C3714756   mondo_sssom    exactMatch

=== disease_mapping_write completed

=== Column population summary:
  DOID                     : 'DOID:0081234'
  MONDO                    : 'MONDO:0032745'
  Orphanet                 : 'Orphanet:530983'
  EFO                      : 'EFO:0004190'
  UMLS                     : 'UMLS:C3714756'
  MedGen                   : 'MedGen:C3714756'
  NCIT                     : 'NCIT:C92168'
  GARD                     : 'GARD:0009849'
  ontology_mapping_release : 'probe-2026-06-20'

=== Populated projection columns: 8 / 8
=== RESULT: ALL 8 cols populated YES

=== ROLLBACK complete — dev DB unchanged
```

**dev-DB probe: 8 cols populated YES**
