# Filter-pushdown audit — `tbl() %>% collect() %>% filter()` antipattern

Date: 2026-04-27
Branch: `feature/v11.3-genes-entities-perf-ux`
Reference fix: `api/endpoints/entity_endpoints.R` lines 90–133 (compact-mode SQL pushdown);
`api/functions/response-helpers.R` lines 247–248 (single-column `equals` → `==`).

## 1. Summary

The same antipattern that was just fixed in `entity_endpoints.R` (collect-the-whole-view,
then filter in R) is repeated in **9 other call sites**. Three are clearly worth
fixing now because they collect medium-to-large views per request and the underlying
endpoint is hot:

1. **`GET /api/gene/`** (`api/endpoints/gene_endpoints.R:60–74`) — collects the full
   `ndd_entity_view` (~4 200 rows) on every Genes-page request, even for
   `equals(symbol,X)` lookups. Same shape as the entity fix; the gene page already
   benefits from the entity fix indirectly but the gene-list path itself is
   un-fixed. Highest user-visible payoff.
2. **`GET /api/publication/`** and **`GET /api/publication/pubtator/table`**
   (`publication_endpoints.R:247–253`, `412–420`) — collect `publication`
   (~4 700 rows) and `pubtator_search_cache` (500 rows, but every query is an
   indexed-column equals or contains). PubTator search/admin is hot during curation.
3. **`GET /api/re_review/table`** (`re_review_endpoints.R:163, 245`) — collects a
   joined view that fans out across `re_review_entity_connect` (3 558),
   `re_review_assignment`, `ndd_entity_view` (4 200), `ndd_entity_review` (6 258),
   `ndd_entity_status`, `user`. The R-side filter typically narrows to one
   reviewer's rows, so pushdown saves a wide join + collect on every keystroke.

The other 6 candidates are lower priority (lower row counts, or callers depend
on global `count_filtered` facets that need the in-R two-pass form).

## 2. All candidates

| File:line | Endpoint (path under `/api`) | Underlying view | Rows | fspec needed? | Est. saving |
|---|---|---|---:|---|---|
| `api/endpoints/gene_endpoints.R:66` | `GET /gene/` | `ndd_entity_view` (+ in-R group_by) | 4 200 | **Yes** (`count_filtered`) | High — but needs the entity-style compact dual-path because TablesGenes consumes facet counts |
| `api/endpoints/publication_endpoints.R:252` | `GET /publication/` | `publication` | 4 689 | No (`tbl_fspec$fspec$count_filtered <- tbl_fspec$fspec$count`) | High — pushdown is straightforward, no facet two-pass needed |
| `api/endpoints/publication_endpoints.R:418` | `GET /publication/pubtator/table` | `pubtator_search_cache` | 500 | No | Medium — small table but cursor-paginated and called per keystroke |
| `api/endpoints/publication_endpoints.R:548` | `GET /publication/pubtator/genes` | `pubtator_human_gene_entity_view` | 757 | No | Low–Medium — filter is on **computed** fields (`is_novel`, `entities_count`); cannot push down cleanly |
| `api/endpoints/re_review_endpoints.R:243` | `GET /re_review/table` | join over 6 tables incl. `ndd_entity_view` | ~3 558 (post-join wider) | No (no fspec returned) | High — wide join collected before user filter |
| `api/endpoints/statistics_endpoints.R:113` | `GET /statistics/entities_over_time` | `ndd_entity_view` | 4 200 | No | Medium — collected once then aggregated; pushdown viable |
| `api/endpoints/statistics_endpoints.R:457` | `GET /statistics/publication_stats` | `publication` | 4 689 | No (only stats) | Medium — same shape |
| `api/endpoints/user_endpoints.R:62/82` | `GET /user/table` | `user` | 62 | No (manual fspec) | **Negligible** — leave as-is |
| `api/endpoints/ontology_endpoints.R:127` | `GET /ontology/variant/table` | `variation_ontology_list` | 495 | No (manual fspec) | Low — keep |

Notes on the entity-fix replacement strategy:

- The gene endpoint is special because `entities_count` is computed via
  `group_by(symbol) %>% mutate(n())` AFTER collect. Pushdown needs to either
  (a) move that to a SQL window/aggregate, or (b) replicate the entity-style
  dual-path: SQL pushdown in compact mode + in-R fallback otherwise.
- The publication endpoints already initialise
  `tbl_fspec$fspec$count_filtered <- tbl_fspec$fspec$count`, i.e. they don't
  expose a global vs filtered split → safe to push the filter to SQL
  unconditionally (no `compact` flag needed).
- `re_review/table` builds a chain of lazy joins and only `collect()`s right
  before applying the user filter (line 243). Moving `filter(!!!parse_exprs(...))`
  before `collect()` should translate cleanly for `equals` / `contains` over
  scalar columns; vario-style joins are already absent here.

## 3. Other layers

### `api/functions/endpoint-functions.R` — 4 occurrences

These are shared helpers behind public endpoints:

| Line | Helper | Called from | Underlying view | Notes |
|---:|---|---|---|---|
| 42 / 108 | `generate_comparisons_list()` | `GET /comparisons/browse` | `ndd_database_comparison_view` (21 203 rows) | Filter applied in R after collect+pivot. The pivot step depends on the full set, so pushdown is **not** straightforward — would need a SQL view or two-stage query. **Worth a follow-up plan, not a quick fix.** |
| 211 / 235 | `generate_phenotype_entities_list()` | `GET /phenotype/entities/browse`, `correlation`, `count` | `ndd_review_phenotype_connect_view` (22 305) joined with `ndd_entity_view` (4 200) | Currently double-collects. Pushdown blocked by the `paste0(collapse=",")` aggregate on `modifier_phenotype_id` that runs in R. Could be moved to a DB view or `dbplyr` window-string. |
| 409 / 460 | `generate_panels_list()` | `GET /panels/browse` | `ndd_entity_view` filtered to `ndd_phenotype == 1` | The `filter(ndd_phenotype == 1) %>% select(...)` is **already pushed down** before collect; the user filter (line 460) runs in R. Mid-priority candidate. |
| 777 / 801 | `generate_variant_entities_list()` | `GET /variant/browse`, `correlation`, `count` | `ndd_review_variant_connect_view` (9 571) joined with `ndd_entity_view` (4 200) | Same shape as phenotype helper — double-collect, R-side aggregate `paste0(collapse=",")` blocks naive pushdown. |

Also `generate_gene_news_tibble()` at line 742: filter is hard-coded
(`ndd_phenotype == 1 & category == "Definitive"`) and **already pushed down**
before `collect()`. OK as-is.

### `api/services/*.R`

Reviewed `auth-service.R`, `search-service.R`, `approval-service.R`,
`user-service.R`, `review-service.R`, `entity-service.R`. All `tbl()` chains
either:

- push their predicates to SQL before `collect()` (e.g. `search-service.R`
  uses `filter(result %like% !!search_pattern)` *before* collect on every
  `search_*` view), or
- collect a single keyed row by primary key (e.g. `tbl("user") %>% filter(user_id == !!uid) %>% collect()`).

No additional candidates in services.

## 4. Behavior-change risks (regex-special chars in `equals`)

The old form was `str_detect(col, '^value$')`; the new form is `col == 'value'`.
Semantics differ when `value` contains any of `. * + ? | \ ( ) [ ] { } ^ $`.

Survey of every `equals(...)` call in the repo:

| Source | Value(s) passed to `equals(...)` | Regex-meta? | Behavior change? |
|---|---|---|---|
| `app/src/views/pages/GeneView.vue:191–198` | `${routeParam}` for `symbol` or `hgnc_id` | symbols are uppercase ASCII; HGNC IDs `HGNC:N` (`:` is not regex-meta) | No |
| `app/src/composables/useEntityRecord.ts:36` | `entity_id` (numeric) | No | No |
| `app/src/views/curate/composables/useEntityInfo.ts:67`, `composables/review/useReviewApprovalActions.ts:188`, `views/curate/ApproveStatus.vue:98`, `views/review/composables/useReviewData.ts:244` | `entity_id` (numeric) | No | No |
| `app/src/api/panels.spec.ts`, `app/src/api/re_review.spec.ts` | `'Definitive'`, `0` | No | No |
| `app/src/composables/useUrlParsing.spec.ts` | `BRCA1`, numeric `1` | No | No |
| `app/tests/perf/fixtures.ts` | `GRIN2B`, `MECP2`, `HGNC:4586` | No | No |
| `api/tests/testthat/test-integration-llm-endpoints.R` | `equals(hash,...)` — routed through hash short-circuit (line 192–198) before regex | No (and bypasses the new `==` path) | No |
| Default param values in endpoints (`re_review_endpoints.R:150`, `panels_endpoints.R:87`) | `0`, `'Definitive'` | No | No |

**Net: no caller in the current repo passes regex-meta characters to a
single-column `equals`.** The new test in `test-unit-helper-functions.R:156`
already covers the synthetic cases (`GR.IN2B`, `AB[CD]`, `ABC|XYZ`, `P53*`,
`AB+CD`) and asserts they switch to literal-equality semantics.

The two intentional exceptions (`equals(any,...)` / `equals(all,...)`) keep the
anchored-regex form (response-helpers.R:237–246) — multi-column whole-row
matches still need `str_detect`. Confirmed in the test at line 145.

## 5. Edge cases the new tests should cover

Recommend adding these to `test-unit-helper-functions.R` and (where they hit
the DB) to a new `test-integration-pagination.R` block:

1. **Composed `equals` via `and()` / `or()`** — `and(equals(symbol,X),equals(category,Y))`
   currently composes two `==` fragments via `&` / `|` (helper test at
   line 170–187 covers the helper output, but no integration test verifies
   that dbplyr translates the **composed** expression to SQL without falling
   back). Needed for the `compact` fast path on entity/gene endpoints.
2. **Empty `equals` value** — `equals(symbol,)` → `symbol == ''`. Verify it
   doesn't blow up parsing (the `str_remove_all("'|\\)")` step at line 177
   should leave an empty string) and that the SQL pushdown doesn't trip on
   empty literals.
3. **Single-quote-in-value** — `equals(symbol,O'Reilly)`. Today line 177
   strips `'` characters, so the value silently becomes `OReilly`. Worth a
   regression test asserting the documented behaviour (or a deliberate fix
   — neither symbol nor HGNC IDs contain `'` so this is a latent bug, not
   live).
4. **Unicode / non-ASCII** — e.g. `equals(symbol,ÅSE1)`. Verify URLdecode
   handles it and the SQL `=` comparison uses the connection's collation
   (utf8mb4 on our schema).
5. **Case sensitivity** — pre-fix, `str_detect('^value$')` was case-sensitive
   in R; post-fix, MySQL `=` uses the column collation (default
   `utf8mb4_general_ci`, case-insensitive). Add a test that
   `equals(symbol,grin2b)` and `equals(symbol,GRIN2B)` return the same rows
   under `compact=true` (this is a **behavioral change** vs the old in-R
   regex path that's worth pinning).
6. **Vario-filter coexistence** — entity endpoint disables the fast path when
   `has_vario_filter`. Add a guard test that
   `and(equals(symbol,X),equals(vario_id,N))` still returns correct rows
   (i.e. falls back through the in-R path without losing the vario filter).
7. **Translation-failure fallback** — synthesise an expression dbplyr cannot
   translate (e.g. injection of `if_any(...)` via crafted column name) and
   assert the warning is logged and the legacy in-R path produces the same
   answer it always did.
