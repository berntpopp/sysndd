# WP-A Implementation Report: Disease Cross-Ontology Mapping Schema & Migration

## Files Created / Modified

| File | Action |
|---|---|
| `db/migrations/036_add_disease_ontology_mappings.sql` | Created — new migration |
| `api/functions/migration-manifest.R` | Modified — bumped to `036…`/`34L` |
| `api/tests/testthat/test-unit-core-views-manifest.R` | Modified — updated assertions, added 036 test |
| `db/migrations/README.md` | Modified — added one-line note for 036 |

## Step 1: Live Collation Confirmed

Confirmed via `SHOW FULL COLUMNS FROM disease_ontology_set LIKE 'disease_ontology_id'` run against `sysndd_mysql` (production MySQL container, accessed through the API container via `RMariaDB`):

```
Field: disease_ontology_id
Type:  varchar(15)
Collation: utf8mb3_general_ci
```

This matches the base schema migration (`000_initialize_base_schema.sql`) which declares `DEFAULT CHARSET=utf8mb3`.

The `disease_ontology_mapping.disease_ontology_id` join key was pinned to `CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci` in the DDL, matching the source column exactly.

## Step 2: Migration File

Created `db/migrations/036_add_disease_ontology_mappings.sql` verbatim per the brief:
- 4 new tables: `mondo_term`, `mondo_xref`, `disease_ontology_mapping`, `disease_ontology_mapping_meta` (all `DEFAULT CHARSET=utf8mb4`)
- 1 `ALTER TABLE disease_ontology_set` adding 5 new columns: `UMLS`, `MedGen`, `NCIT`, `GARD`, `ontology_mapping_release`
- No `USE` statement; no `IF NOT EXISTS` on ADD COLUMNs (runner applies once)

## Step 3: Manifest Bumped

`api/functions/migration-manifest.R`:
- `EXPECTED_LATEST_MIGRATION <- "036_add_disease_ontology_mappings.sql"`
- `EXPECTED_MIGRATION_COUNT <- 34L`

## Step 4: C_Rcommands_set-table-connections.R

Grepped for `disease_ontology_set` in `db/C_Rcommands_set-table-connections.R`. The script:
- Does NOT `CREATE` the `disease_ontology_set` table
- Only runs `ALTER TABLE` on it and references it inside `CREATE OR REPLACE VIEW` statements
- No `ndd_entity_view` involvement

Per the brief: **no changes needed to this file**.

## Step 5: Tests

Test file: `api/tests/testthat/test-unit-core-views-manifest.R`

Updated assertions:
- `test_that("manifest expects migration 036 as latest")` — checks both `EXPECTED_LATEST_MIGRATION` and `EXPECTED_MIGRATION_COUNT == 34L`
- `test_that("migration manifest validates against db/migrations")` — validates latest is `036…`
- `test_that("migration 036 file exists and contains disease_ontology_mapping table")` — new test: checks file exists, verifies `CREATE TABLE IF NOT EXISTS \`disease_ontology_mapping\``, `CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci`, all 4 new tables, `ALTER TABLE \`disease_ontology_set\``, `\`UMLS\``, `\`ontology_mapping_release\``

### Test command and output:
```
cd /home/bernt-popp/development/sysndd/api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-core-views-manifest.R')"
```

Result: **[ FAIL 0 | WARN 1 | SKIP 0 | PASS 22 ]**

(The single warning is an irrelevant R version note about the `fs` package being built under R 4.5.3, not a test failure.)

## Step 6: Applied Against Live Dev DB and Verified

The migration was applied by restarting `sysndd-api-1`. Log confirmation:
```
[2026-06-20 14:22:58.255844] Migrations complete (1 applied in 0.24s): 036_add_disease_ontology_mappings.sql
```

Container health after restart: **running healthy**

### Table verification (via API container → sysndd_mysql):

```
SHOW TABLES LIKE 'mondo_%':
  mondo_term
  mondo_xref

SHOW TABLES LIKE 'disease_ontology_mapping%':
  disease_ontology_mapping
  disease_ontology_mapping_meta
```

### Column verification (disease_ontology_set):
New columns present: `UMLS`, `MedGen`, `NCIT`, `GARD`, `ontology_mapping_release` (positions 15–19)

### Trial join:
```sql
SELECT s.disease_ontology_id
FROM disease_ontology_set s
LEFT JOIN disease_ontology_mapping m ON s.disease_ontology_id = m.disease_ontology_id
LIMIT 1;
```
Result: `MONDO:0001071` — **no collation error**.

## Notes / Concerns

- The `sysndd_mysql_dev` container (used for development) is on the `sysndd_default` network, isolated from the `sysndd_backend` network where the API and production MySQL containers live. Direct external access to `sysndd_mysql_dev` was not possible (all connection attempts returned Access Denied). The live collation was confirmed from the production MySQL container (`sysndd_mysql`) instead — which is the container the API actually connects to. The `disease_ontology_set` table definition in `000_initialize_base_schema.sql` was cross-checked as a secondary source: it explicitly declares `DEFAULT CHARSET=utf8mb3`, confirming `utf8mb3_general_ci` would be the column collation in both MySQL containers.
- No changes were made to `ndd_entity_view` or any view definitions.
- Startup manifest validation was not weakened.

## Commits

Two commits to be created:
1. `feat(db): add disease cross-ontology mapping tables (migration 036)` — migration SQL, manifest bump, test update
2. `docs(db): note migration 036 in README` — README one-liner
