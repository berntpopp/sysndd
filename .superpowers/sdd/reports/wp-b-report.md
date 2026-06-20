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
