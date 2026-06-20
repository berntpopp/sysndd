# WP-D Implementation Report

## Status: DONE

## Commits

| Task | SHA | Message |
|------|-----|---------|
| D1 | `9ef28539` | feat(api): disease mapping read repository |
| D2 | `6c36ebe6` | feat(api): public GET /api/disease/mappings endpoint |
| D3 | `23652da0` | feat(api): expose UMLS/MedGen/NCIT/GARD on /api/ontology |

## Test Summary

All tests green on host:
- `test-unit-disease-mapping-endpoint.R`: PASS 19 / FAIL 0 / SKIP 0 (D1 pure-function grouping tests + D3 projection-column presence checks)
- `test-unit-cheap-route-isolation.R`: PASS 3 / FAIL 0 / SKIP 0 (existing 1 + 2 new DB-only isolation checks for disease endpoint and repository)

## Implementation Notes

- `disease_mapping_group_rows()` defines its own inline `DISEASE_MAPPING_PREFIX_ORDER` constant (mirrors `MONDO_TARGET_ALLOWLIST`) so the pure function is testable without sourcing `mondo-index-builder.R`.
- `disease_mapping_for_entity()` resolves ONLY via `ndd_entity_view` — inactive/non-public entities return `status:"missing"`, never leaking mapping data (correction #1 honored).
- All DB params use `unname(list(...))` per AGENTS.md gotcha.
- `mount_endpoint()` wrapper used for the new disease endpoint (RFC 9457 error/404 inheritance).
- `mondo-index-builder.R` and `disease-ontology-mapping-repository.R` added to `load_modules.R` function_files list.
- `api/endpoints/ontology_endpoints.R` select() extended with UMLS, MedGen, NCIT, GARD, ontology_mapping_release (D3/correction #3).

## Concerns

None. All binding corrections (#1, #3) implemented. Endpoint is DB-only (no external fetchers). `status:"missing"` returns HTTP 200 as specified.

---

## Fix pass

### Fixes applied

**C1 (Critical) — inactive-entity no-leak security test**

Added two tests using `local_mocked_bindings(dbGetQuery = ...)` on the `DBI` package:
- Negative case: mocked `ndd_entity_view` query returns 0 rows → `disease_mapping_for_entity()` returns `status="missing"`, `length(mappings)==0`, `mondo_id=NULL`. Test asserts the SQL targets `ndd_entity_view` and not bare `ndd_entity` (the guard that would break if someone swapped the table name).
- Positive case: mocked view returns a row → all three queries (entity view, dos lookup, disease mapping) are chained, result is `status="current"` with OMIM mapping, `release_version="2024-01"`.

**I1 (Important) — endpoint parameter validation tests**

The endpoint file uses a plumber anonymous function, not a named symbol, so we defined `make_disease_mapping_handler()` — a factory that mirrors the endpoint handler body verbatim with injectable stubs — plus a guard test asserting the endpoint source text still contains the exact phrases the mirror reproduces. Six tests cover: both-absent → `error_400`, both-present → `error_400`, entity_id only → delegates to entity fn, disease_ontology_id only → delegates to disease fn, unknown disease → `status:"missing"` (no throw), non-integer entity_id → `error_400`.

**I2 (Important) — single `release_version` field**

Removed `ontology_mapping_release` key from both `disease_mapping_for_disease` and `disease_mapping_for_entity` (all four return sites). Kept only `release_version` (the frozen-contract field). Also removed the `SELECT ontology_mapping_release` from the `disease_ontology_set` metadata query since it is no longer needed. Tests updated to assert `ontology_mapping_release` is absent from the response.

**m1 (Minor) — drop non-allowlisted prefixes**

In `disease_mapping_group_rows`, removed the `extra_prefixes` / `setdiff` block entirely. `ordered_prefixes` is now strictly `present_prefixes` (only allowlisted prefixes in `rows$target_prefix`). Two new tests: (a) rows with `PROPRIETARY` and `INTERNAL_DB` mixed with `MONDO`/`OMIM` — stray keys absent from output; (b) rows with only non-allowlisted prefixes — returns `list()` and `NULL` mondo_id.

### Test command and output

```
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-disease-mapping-endpoint.R')"
```

Result: **[ FAIL 0 | WARN 0 | SKIP 0 | PASS 59 ]**

```
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-cheap-route-isolation.R')"
```

Result: **[ FAIL 0 | WARN 0 | SKIP 0 | PASS 3 ]**

### Dev-DB no-leak probe result

Ran inside `sysndd-api-1` (queries live dev DB via `disease_mapping_for_entity()`):

```sql
SELECT e.entity_id
FROM ndd_entity e
LEFT JOIN ndd_entity_view v ON e.entity_id = v.entity_id
WHERE v.entity_id IS NULL
LIMIT 1
-- Result: entity_id = 3656
```

`disease_mapping_for_entity(3656)` returned `status = "missing"`, `length(mappings) = 0`.

**Dev-DB no-leak probe: PASS** — entity 3656 is present in `ndd_entity` but absent from `ndd_entity_view`; calling the entity lookup returns missing with no mapping data.

### Commit

`bd05bcfb` — `fix(api): test inactive-entity no-leak + param validation; single release_version field; drop non-allowlisted prefixes`
