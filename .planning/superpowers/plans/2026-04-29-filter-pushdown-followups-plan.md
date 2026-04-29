# Filter-Pushdown Audit Follow-ups — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the v11.3 SQL-filter-pushdown pattern to the three remaining hot endpoints that still collect-the-whole-view-then-filter-in-R: `GET /api/gene/` (HIGH user-visible payoff), `GET /api/statistics/entities_over_time`, and `GET /api/statistics/publication_stats`. Skip the four audit candidates the audit doc already marked as not-worth-fixing. Document the closeout.

**Architecture:** Two patterns are needed, mirroring v11.3:

1. **Dual-path pattern** (gene endpoint): same shape as the v11.3 entity-endpoint fix. A `compact=true` query parameter opts the caller into a SQL pushdown that skips the global-fspec computation. Default callers (the main `/Genes` table page) keep the in-R filter so the filter-dropdown facet counts still reflect the whole view.
2. **Unconditional-pushdown pattern** (statistics endpoints): no fspec returned, no compact-vs-default split needed. Push the user filter (and only the user filter) before `collect()`; aggregations / `group_by` / `mutate(n())` stay post-collect because they need the filtered subset, not the unfiltered view.

**Tech Stack:** R/Plumber, dbplyr (`filter(!!!rlang::parse_exprs(...))` before `collect()`), MySQL with `utf8mb3_general_ci` collation (case-insensitive `=` for the simple `equals` op), testthat 3 for both unit (helper-level) and integration (DB-roundtrip) coverage.

**Reference docs:**
- Audit: `.planning/perf/2026-04-27-filter-pushdown-audit.md` — rationale for each candidate.
- v11.3 entity precedent: `api/endpoints/entity_endpoints.R:85-133` (the dual-path implementation to mirror in Phase A).
- v11.3 publication-endpoint precedent: `api/endpoints/publication_endpoints.R:247-260` (unconditional pushdown — Phase B and C mirror this shape).
- Helper: `api/functions/response-helpers.R:247-248` (single-column `equals` emits `col == 'val'`, indexable).

---

## Scope

**In scope (this plan):**

| Phase | Endpoint | File:line | Pattern | Priority |
|---|---|---|---|---|
| A | `GET /api/gene/` | `api/endpoints/gene_endpoints.R:62-72` | Dual-path (compact + fspec) | HIGH |
| B | `GET /api/statistics/entities_over_time` | `api/endpoints/statistics_endpoints.R:111-145` | Unconditional pushdown | MEDIUM |
| C | `GET /api/statistics/publication_stats` | `api/endpoints/statistics_endpoints.R:454-475` | Unconditional pushdown | MEDIUM |

**Explicitly out-of-scope (deferred or skipped per audit):**

| Candidate | Reason | Action |
|---|---|---|
| `GET /user/table` (`user_endpoints.R:62/82`) | 62 rows; negligible runtime cost | Leave as-is |
| `GET /ontology/variant/table` (`ontology_endpoints.R:127`) | 495 rows, manual fspec | Leave as-is |
| `GET /publication/pubtator/genes` (`publication_endpoints.R:548`) | Filter is on **computed** post-collect fields (`is_novel`, `entities_count`); cannot push down without refactoring view | Document why; defer to a future plan that adds the computed columns to the DB view |
| `endpoint-functions.R::generate_comparisons_list` | 21 203 rows, blocked by post-collect pivot; needs SQL-view redesign | Separate follow-up plan |
| `endpoint-functions.R::generate_phenotype_entities_list` | Blocked by `paste0(collapse=",")` aggregate; would need `dbplyr` window-string or DB view | Separate follow-up plan |
| `endpoint-functions.R::generate_variant_entities_list` | Same shape as phenotype helper | Separate follow-up plan |
| `endpoint-functions.R::generate_panels_list` | **Already pushed down** before collect (audit confirmed) | No action |

**Total tasks: 13** (Phase A: 6, Phase B: 3, Phase C: 3, Phase D: 1).

---

## File Structure

| Action | Path | Responsibility |
|---|---|---|
| Modify | `api/endpoints/gene_endpoints.R` (lines 38-100) | Add `compact` query param + dual-path body |
| Modify | `api/endpoints/statistics_endpoints.R` (lines 110-115) | Filter pushdown for `entities_over_time` |
| Modify | `api/endpoints/statistics_endpoints.R` (lines 460-465) | Filter pushdown for `publication_stats` |
| Modify | `app/src/api/genes.ts` | Add `compact?: boolean` to params type if not already |
| Modify | `app/src/views/pages/GenesView.vue` (or whichever view calls `/api/gene/`) | Pass `compact: true` for the lookup-style cases |
| Modify | `api/tests/testthat/test-integration-pagination.R` (or new file) | Integration tests covering pushdown for all three sites |
| Modify | `app/src/api/genes.spec.ts` | Frontend test for compact param forwarding |
| Modify | `.planning/perf/2026-04-27-filter-pushdown-audit.md` | Mark closed items, link to this plan |

Total: 7 modified, 1 doc update.

---

## Phase A — `GET /api/gene/` (dual-path pushdown)

The gene endpoint is the highest-priority remaining target: it's hit on every Genes-page load, on every keystroke in the symbol filter, and on every `/Genes/<symbol>` resolution. It collects ~4 200 rows from `ndd_entity_view` even when the caller's filter narrows to one symbol.

The complication vs the publication endpoints (which got an unconditional pushdown in v11.3): the gene endpoint computes `entities_count` post-collect via `group_by(symbol) %>% mutate(n())`. We can't push that to SQL without rewriting the view, so we apply the same dual-path treatment as the entity endpoint: compact mode for symbol-lookup callers, default mode for the table view.

### Task A.1: Add integration test asserting current behaviour (regression baseline)

**Files:**
- Modify: `api/tests/testthat/test-integration-pagination.R`

- [ ] **Step 1: Write a baseline test that captures current behaviour for the GRIN2B lookup case**

Append to `api/tests/testthat/test-integration-pagination.R`:

```r
describe("GET /api/gene/ — pre-pushdown baseline (default mode)", {
  it("returns the GRIN2B row when filtered by symbol", {
    response <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/gene/") |>
      httr2::req_url_query(filter = "equals(symbol,GRIN2B)") |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(response), 200L)
    body <- httr2::resp_body_json(response)
    # Get one row back, with entities_count populated
    expect_gte(length(body$data), 1L)
    expect_true(any(vapply(body$data, function(r) r$symbol == "GRIN2B", logical(1L))))
  })

  it("returns the GRIN2B row when filtered by hgnc_id", {
    response <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/gene/") |>
      httr2::req_url_query(filter = "equals(hgnc_id,HGNC:4586)") |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(response), 200L)
    body <- httr2::resp_body_json(response)
    expect_true(any(vapply(body$data, function(r) r$symbol == "GRIN2B", logical(1L))))
  })

  it("default mode returns the same data as the upcoming compact mode (parity)", {
    # This test will gain meaning after Task A.3 — for now it documents intent.
    skip("Will be activated in Task A.3 once compact mode exists")
  })
})
```

- [ ] **Step 2: Run baseline tests to verify current behaviour**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-pagination.R')"`

Expected: the first two tests PASS (current implementation still returns correct data, just slowly). Third skipped.

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-pagination.R
git commit -m "test(api): baseline tests for /api/gene/ symbol/hgnc_id lookups"
```

### Task A.2: Add `compact` query param + parameter parsing

**Files:**
- Modify: `api/endpoints/gene_endpoints.R` (function signature + parameter parsing)

- [ ] **Step 1: Add the param to the docblock and signature**

Find the function signature in `api/endpoints/gene_endpoints.R` around line 38. Add:

```r
#* @param compact:bool When true, push the filter to SQL where possible and
#*   skip the global-fspec computation (only the filtered-set fspec is
#*   computed). Use for lookup-style queries (symbol-by-symbol resolution,
#*   `/Genes/<symbol>` page loads). Leave false for the main /Genes table
#*   page where the global fspec drives the filter-dropdown facet counts.
#*   Default false.
```

And add `compact = "false"` to the function signature args (after `format = "json"` or wherever the existing args end).

- [ ] **Step 2: Parse `compact` into a boolean local**

After the existing param-parsing block (e.g. after `filter_exprs <- generate_filter_expressions(filter)`), add:

```r
  is_compact <- isTRUE(tolower(as.character(compact[[1]])) %in% c("true", "1", "yes"))

  # The SQL pushdown is only safe for filters made entirely of `equals`/`and`/`or`
  # expressions on scalar columns of `ndd_entity_view`. For now, gate on the
  # presence of any text filter; rely on dbplyr to throw if it can't translate.
  has_text_filter <- length(filter_exprs) > 0L && nzchar(trimws(filter))
```

- [ ] **Step 3: Commit**

```bash
git add api/endpoints/gene_endpoints.R
git commit -m "feat(api): add compact query param to /api/gene/ (parsing only)"
```

### Task A.3: Implement the fast path body

**Files:**
- Modify: `api/endpoints/gene_endpoints.R` (replace lines 62-100 ish)

- [ ] **Step 1: Replace the collect-then-filter block with the dual-path body**

Find the existing block in `api/endpoints/gene_endpoints.R` around line 62-72:

```r
  # Get data from database and filter
  sysndd_db_genes_table <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    collect() %>%
    group_by(symbol) %>%
    mutate(entities_count = n()) %>%
    ungroup()

  # Apply filters and sorting
  sysndd_db_genes_table_filtered <- sysndd_db_genes_table %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))
```

Replace with:

```r
  ndd_entity_view_lazy <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id)

  # Fast path: compact + a text filter present → push the filter to SQL,
  # then compute entities_count on the (small) filtered set in R. This avoids
  # the global view collect (~4 200 rows) for lookup-style queries.
  fast_path_filtered <- NULL
  if (is_compact && has_text_filter) {
    fast_path_filtered <- tryCatch(
      ndd_entity_view_lazy %>%
        filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        collect() %>%
        group_by(symbol) %>%
        mutate(entities_count = n()) %>%
        ungroup(),
      error = function(e) {
        message(sprintf(
          "[gene-list] SQL filter pushdown failed (%s); falling back to in-R filter",
          conditionMessage(e)
        ))
        NULL
      }
    )
  }

  if (!is.null(fast_path_filtered)) {
    sysndd_db_genes_table <- fast_path_filtered
    sysndd_db_genes_table_filtered <- fast_path_filtered %>%
      arrange(!!!rlang::parse_exprs(sort_exprs))
  } else {
    # Default path: collect global view, then group/filter in R. Required for
    # the main /Genes table page where the global fspec drives the
    # filter-dropdown facet counts ("X of Y").
    sysndd_db_genes_table <- ndd_entity_view_lazy %>%
      collect() %>%
      group_by(symbol) %>%
      mutate(entities_count = n()) %>%
      ungroup()
    sysndd_db_genes_table_filtered <- sysndd_db_genes_table %>%
      filter(!!!rlang::parse_exprs(filter_exprs)) %>%
      arrange(!!!rlang::parse_exprs(sort_exprs))
  }
```

- [ ] **Step 2: Update the fspec block to reuse the filtered set in compact mode**

Find the existing block:

```r
  # Field specs
  sysndd_db_genes_table_fspec <- generate_tibble_fspec_mem(
    sysndd_db_genes_table,
    fspec
  )
  sysndd_db_genes_table_filtered_fspec <- generate_tibble_fspec_mem(
    sysndd_db_genes_table_filtered,
    fspec
  )
  sysndd_db_genes_table_fspec$fspec$count_filtered <-
    sysndd_db_genes_table_filtered_fspec$fspec$count
```

Replace with:

```r
  # In compact mode the filtered set IS the working set, so global fspec ==
  # filtered fspec. In default mode keep the two-pass split.
  sysndd_db_genes_table_fspec <- generate_tibble_fspec_mem(
    sysndd_db_genes_table,
    fspec
  )
  if (is_compact) {
    sysndd_db_genes_table_fspec$fspec$count_filtered <-
      sysndd_db_genes_table_fspec$fspec$count
  } else {
    sysndd_db_genes_table_filtered_fspec <- generate_tibble_fspec_mem(
      sysndd_db_genes_table_filtered,
      fspec
    )
    sysndd_db_genes_table_fspec$fspec$count_filtered <-
      sysndd_db_genes_table_filtered_fspec$fspec$count
  }
```

- [ ] **Step 3: Run baseline tests, expect still-pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-pagination.R')"`

Expected: A.1 baseline tests still PASS (default mode unchanged).

- [ ] **Step 4: Activate the parity test**

In `test-integration-pagination.R`, replace the skip:

```r
  it("default mode returns the same data as the upcoming compact mode (parity)", {
    default_resp <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/gene/") |>
      httr2::req_url_query(filter = "equals(symbol,GRIN2B)") |>
      httr2::req_perform() |> httr2::resp_body_json()
    compact_resp <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/gene/") |>
      httr2::req_url_query(filter = "equals(symbol,GRIN2B)", compact = "true") |>
      httr2::req_perform() |> httr2::resp_body_json()
    # Same gene, same entities_count, same row payload
    expect_equal(length(default_resp$data), length(compact_resp$data))
    default_grin <- Filter(function(r) r$symbol == "GRIN2B", default_resp$data)[[1L]]
    compact_grin <- Filter(function(r) r$symbol == "GRIN2B", compact_resp$data)[[1L]]
    expect_equal(default_grin$entities_count, compact_grin$entities_count)
  })
```

- [ ] **Step 5: Run, expect pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-pagination.R')"`

Expected: 3 PASSes for `/api/gene/`.

- [ ] **Step 6: Commit**

```bash
git add api/endpoints/gene_endpoints.R api/tests/testthat/test-integration-pagination.R
git commit -m "perf(api): SQL filter pushdown for /api/gene/ in compact mode"
```

### Task A.4: Add edge-case integration tests

**Files:**
- Modify: `api/tests/testthat/test-integration-pagination.R`

- [ ] **Step 1: Add tests for case-insensitivity, hgnc_id form, unknown symbol, vario-coexistence-not-applicable**

Append:

```r
describe("GET /api/gene/?compact=true — edge cases", {
  it("is case-insensitive (utf8mb3_general_ci collation)", {
    upper <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/gene/") |>
      httr2::req_url_query(filter = "equals(symbol,GRIN2B)", compact = "true") |>
      httr2::req_perform() |> httr2::resp_body_json()
    lower <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/gene/") |>
      httr2::req_url_query(filter = "equals(symbol,grin2b)", compact = "true") |>
      httr2::req_perform() |> httr2::resp_body_json()
    expect_equal(length(upper$data), length(lower$data))
  })

  it("returns empty data array for unknown symbol", {
    resp <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/gene/") |>
      httr2::req_url_query(filter = "equals(symbol,DEFINITELY_NOT_REAL)", compact = "true") |>
      httr2::req_perform()
    body <- httr2::resp_body_json(resp)
    expect_equal(length(body$data), 0L)
  })

  it("composed and(equals(...),equals(...)) translates to SQL", {
    resp <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/gene/") |>
      httr2::req_url_query(filter = "and(equals(symbol,GRIN2B),equals(category,Definitive))",
        compact = "true") |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 200L)
  })

  it("falls back to in-R when filter cannot be SQL-translated", {
    # Trigger fallback by passing a contains() with regex meta — at the time of
    # writing dbplyr can't translate every shape. The fallback should still
    # return the right data.
    resp <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/gene/") |>
      httr2::req_url_query(filter = "contains(symbol,GRIN)", compact = "true") |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 200L)
    body <- httr2::resp_body_json(resp)
    expect_gte(length(body$data), 1L)
  })
})
```

- [ ] **Step 2: Run, expect pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-pagination.R')"`

Expected: 4 new PASSes.

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-pagination.R
git commit -m "test(api): edge cases for /api/gene/ compact-mode SQL pushdown"
```

### Task A.5: Frontend — pass `compact: true` for symbol-lookup paths

**Files:**
- Modify: `app/src/api/genes.ts`
- Modify: `app/src/api/genes.spec.ts`
- Modify: any composable / view that calls `/api/gene/` for a single-symbol lookup (likely `app/src/composables/useGeneRecord.ts` or similar — `grep -rn "api/gene/" app/src/`)

- [ ] **Step 1: Add `compact?: boolean` to the params type**

Find the `ListGenesParams` type (or equivalent) in `app/src/api/genes.ts`. Add:

```ts
export interface ListGenesParams {
  // ... existing fields ...
  compact?: boolean;
}
```

And in the function that builds the request, conditionally append:

```ts
  if (params.compact) {
    searchParams.set('compact', 'true');
  }
```

- [ ] **Step 2: Update the test to assert compact param forwarding**

In `app/src/api/genes.spec.ts`:

```ts
  it('forwards compact=true when params.compact is set', async () => {
    const captured = vi.fn();
    server.use(
      http.get('/api/gene/', ({ request }) => {
        captured(request.url);
        return HttpResponse.json({ data: [], pagination: {}, fspec: {} });
      })
    );
    await listGenes({ filter: 'equals(symbol,GRIN2B)', compact: true });
    expect(captured).toHaveBeenCalled();
    const url = new URL(captured.mock.calls[0][0]);
    expect(url.searchParams.get('compact')).toBe('true');
  });
```

- [ ] **Step 3: Wire `compact: true` into the symbol-lookup composable**

Run: `grep -rn "listGenes\|api/gene/\?" app/src/composables/ app/src/views/`

Identify each call site. For paths that fetch a single gene by symbol or hgnc_id (e.g. `useGeneRecord.ts`, `GeneView.vue` triggers), pass `compact: true`. For the main `/Genes` table page (which shows the dropdown facet counts), leave it default.

- [ ] **Step 4: Run frontend tests**

Run: `cd app && npm run test:unit`

Expected: existing tests pass + new compact-forwarding test passes.

- [ ] **Step 5: Commit**

```bash
git add app/src/api/genes.ts app/src/api/genes.spec.ts app/src/composables/ app/src/views/
git commit -m "feat(app): use compact mode for /api/gene/ symbol-lookup callers"
```

### Task A.6: Manual smoke + benchmark

- [ ] **Step 1: Run the dev stack, exercise /Genes/GRIN2B**

```bash
make dev
# wait, then in browser: open http://localhost/Genes/GRIN2B
# check Network tab: the /api/gene/?filter=...&compact=true request
# should be < 200ms (was ~600ms before pushdown)
```

- [ ] **Step 2: Re-run the local Playwright bench (optional)**

If the v11.3 perf bench at `app/tests/perf/genes-entities.bench.spec.ts` is still wired up:

```bash
make playwright-stack
cd app && npx playwright test tests/perf/genes-entities.bench.spec.ts
```

Compare cold/warm numbers vs the v11.3 baseline in `.planning/perf/2026-04-26-deep-load-analysis.md`.

- [ ] **Step 3: Commit results notes if any**

If the bench reveals a regression or a notable improvement, append a brief note to `.planning/perf/2026-04-26-deep-load-analysis.md`.

---

## Phase B — `GET /api/statistics/entities_over_time`

This endpoint collects all of `ndd_entity_view` (~4 200 rows) on every request, then filters in R, then aggregates. The filter is applied AFTER the collect even though it doesn't depend on any post-collect computation. Push the filter before the collect.

### Task B.1: Baseline test (regression guard)

**Files:**
- Modify: `api/tests/testthat/test-integration-pagination.R` (or new file `test-integration-statistics.R`)

- [ ] **Step 1: Write baseline tests**

Append:

```r
describe("GET /api/statistics/entities_over_time — pre-pushdown baseline", {
  it("returns aggregated counts for the default unfiltered query", {
    resp <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/statistics/entities_over_time") |>
      httr2::req_url_query(aggregate = "entity_id", group = "category", summarize = "year") |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 200L)
    body <- httr2::resp_body_json(resp)
    expect_gte(length(body$data %||% body), 1L)
  })

  it("respects a category filter", {
    resp <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/statistics/entities_over_time") |>
      httr2::req_url_query(
        aggregate = "entity_id", group = "category", summarize = "year",
        filter = "equals(category,Definitive)"
      ) |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 200L)
  })
})
```

- [ ] **Step 2: Run, expect PASS**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-pagination.R')"`

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-pagination.R
git commit -m "test(api): baseline for /api/statistics/entities_over_time"
```

### Task B.2: Push the filter to SQL

**Files:**
- Modify: `api/endpoints/statistics_endpoints.R` (around line 110-145)

- [ ] **Step 1: Replace the collect-then-filter block**

Find around line 110-120:

```r
  # Generate filter expressions
  filter_exprs <- generate_filter_expressions(filter)

  # Collect and filter data
  entity_view_coll <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()

  # Log initial count for diagnostics
  initial_count <- nrow(entity_view_coll)
  log_debug("Entities over time: Initial entity_view count = {initial_count}")

  entity_view_filtered <- entity_view_coll %>%
    dplyr::filter(!!!rlang::parse_exprs(filter_exprs)) %>%
```

Replace with:

```r
  # Generate filter expressions
  filter_exprs <- generate_filter_expressions(filter)
  has_text_filter <- length(filter_exprs) > 0L && nzchar(trimws(filter))

  # Push filter to SQL when present; aggregations stay post-collect.
  entity_view_lazy <- pool %>% tbl("ndd_entity_view")
  entity_view_coll <- if (has_text_filter) {
    tryCatch(
      entity_view_lazy %>%
        dplyr::filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        collect(),
      error = function(e) {
        message(sprintf(
          "[entities_over_time] SQL filter pushdown failed (%s); collecting full view",
          conditionMessage(e)
        ))
        entity_view_lazy %>% collect()
      }
    )
  } else {
    entity_view_lazy %>% collect()
  }

  # Log initial count for diagnostics
  initial_count <- nrow(entity_view_coll)
  log_debug("Entities over time: Initial entity_view count = {initial_count}")

  # Filter is now already applied in SQL when fast-path succeeded; the in-R
  # filter call is the no-op fallback for the slow path. Apply unconditionally
  # to handle both: it's a cheap pass when the row set is already filtered.
  entity_view_filtered <- entity_view_coll %>%
    dplyr::filter(!!!rlang::parse_exprs(filter_exprs)) %>%
```

(Leave the rest of the pipeline — the `arrange / group_by / mutate / select` — exactly as it is. The double-apply of the filter is harmless: in the fast path the filter matches everything (already filtered in SQL); in the slow path it does the actual filtering.)

- [ ] **Step 2: Run baseline tests**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-pagination.R')"`

Expected: B.1 baseline tests still PASS.

- [ ] **Step 3: Commit**

```bash
git add api/endpoints/statistics_endpoints.R
git commit -m "perf(api): SQL filter pushdown for /api/statistics/entities_over_time"
```

### Task B.3: Edge case test — pushdown vs unfiltered parity

**Files:**
- Modify: `api/tests/testthat/test-integration-pagination.R`

- [ ] **Step 1: Add parity test**

Append:

```r
describe("entities_over_time — pushdown parity", {
  it("filtered count equals unfiltered subset of same category", {
    unfiltered <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/statistics/entities_over_time") |>
      httr2::req_url_query(aggregate = "entity_id", group = "category", summarize = "year") |>
      httr2::req_perform() |> httr2::resp_body_json()
    filtered <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/statistics/entities_over_time") |>
      httr2::req_url_query(
        aggregate = "entity_id", group = "category", summarize = "year",
        filter = "equals(category,Definitive)"
      ) |>
      httr2::req_perform() |> httr2::resp_body_json()
    # Definitive count in filtered should match the Definitive subset in unfiltered.
    # Exact comparison structure depends on the response shape — assert size invariant.
    expect_lte(length(filtered$data %||% filtered),
               length(unfiltered$data %||% unfiltered))
  })
})
```

- [ ] **Step 2: Run, expect PASS**

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-pagination.R
git commit -m "test(api): parity check for entities_over_time pushdown"
```

---

## Phase C — `GET /api/statistics/publication_stats`

Same shape as Phase B but on the `publication` table. The audit notes this is straightforward unconditional pushdown: no fspec exposed, only stats returned, the in-R filter doesn't depend on any post-collect computation.

### Task C.1: Baseline test

**Files:**
- Modify: `api/tests/testthat/test-integration-pagination.R`

- [ ] **Step 1: Add baseline test**

Append:

```r
describe("GET /api/statistics/publication_stats — pre-pushdown baseline", {
  it("returns aggregated stats for the default query", {
    resp <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/statistics/publication_stats") |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 200L)
    body <- httr2::resp_body_json(resp)
    expect_true(!is.null(body$publication_type_counts %||% body))
  })
})
```

- [ ] **Step 2: Run, expect PASS**

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-pagination.R
git commit -m "test(api): baseline for /api/statistics/publication_stats"
```

### Task C.2: Push the filter to SQL

**Files:**
- Modify: `api/endpoints/statistics_endpoints.R` (around line 460)

- [ ] **Step 1: Replace the collect-then-filter block**

Find around line 460:

```r
  # 1) Generate filter expressions from the user-provided 'filter' string
  filter_exprs <- generate_filter_expressions(filter)

  # 2) Collect from the publication table, then apply filter
  publication_tbl <- pool %>%
    tbl("publication") %>%
    collect() %>%
    filter(!!!rlang::parse_exprs(filter_exprs))
```

Replace with:

```r
  # 1) Generate filter expressions from the user-provided 'filter' string
  filter_exprs <- generate_filter_expressions(filter)
  has_text_filter <- length(filter_exprs) > 0L && nzchar(trimws(filter))

  # 2) Push filter to SQL where possible; fall back to in-R if dbplyr can't translate.
  publication_lazy <- pool %>% tbl("publication")
  publication_tbl <- if (has_text_filter) {
    tryCatch(
      publication_lazy %>%
        filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        collect(),
      error = function(e) {
        message(sprintf(
          "[publication_stats] SQL filter pushdown failed (%s); falling back to in-R filter",
          conditionMessage(e)
        ))
        publication_lazy %>% collect() %>% filter(!!!rlang::parse_exprs(filter_exprs))
      }
    )
  } else {
    publication_lazy %>% collect()
  }
```

- [ ] **Step 2: Run baseline + new tests**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-pagination.R')"`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add api/endpoints/statistics_endpoints.R
git commit -m "perf(api): SQL filter pushdown for /api/statistics/publication_stats"
```

### Task C.3: Filter test

**Files:**
- Modify: `api/tests/testthat/test-integration-pagination.R`

- [ ] **Step 1: Add a filter-pushdown round-trip test**

Append:

```r
describe("publication_stats — filtered round-trip", {
  it("returns a non-empty publication_type_counts when filtered to a known type", {
    resp <- httr2::request(API_URL) |>
      httr2::req_url_path("/api/statistics/publication_stats") |>
      httr2::req_url_query(filter = 'equals(publication_type,"Journal Article")') |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 200L)
  })
})
```

- [ ] **Step 2: Run, expect PASS**

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-integration-pagination.R
git commit -m "test(api): filter pushdown round-trip for publication_stats"
```

---

## Phase D — Documentation closeout

### Task D.1: Update audit doc to reflect closed items

**Files:**
- Modify: `.planning/perf/2026-04-27-filter-pushdown-audit.md`

- [ ] **Step 1: Update the audit's Section 2 table to reflect closed items**

Open `.planning/perf/2026-04-27-filter-pushdown-audit.md`. After the existing Section 2 table, append a "Status (post-2026-04-29 plan)" section:

```markdown
## Status snapshot (after 2026-04-29 follow-up plan)

| Site | v11.3 status | Follow-up status | Notes |
|---|---|---|---|
| `entity_endpoints.R` | ✅ fixed (compact dual-path) | — | |
| `publication_endpoints.R:252` (`/publication/`) | ✅ fixed (unconditional) | — | |
| `publication_endpoints.R:418` (`/publication/pubtator/table`) | ✅ fixed (unconditional) | — | |
| `re_review_endpoints.R:243` | ✅ fixed (unconditional) | — | |
| `gene_endpoints.R:66` (`/gene/`) | — | ✅ fixed (compact dual-path) | Plan 2026-04-29 Phase A |
| `statistics_endpoints.R:113` (`entities_over_time`) | — | ✅ fixed (unconditional, with try/catch fallback) | Plan 2026-04-29 Phase B |
| `statistics_endpoints.R:457` (`publication_stats`) | — | ✅ fixed (unconditional) | Plan 2026-04-29 Phase C |
| `publication_endpoints.R:548` (`/publication/pubtator/genes`) | — | ⏸ deferred | Filter on computed fields; needs view refactor |
| `user_endpoints.R:62/82` (`/user/table`) | — | ⏸ skipped | 62 rows, negligible |
| `ontology_endpoints.R:127` (`/ontology/variant/table`) | — | ⏸ skipped | 495 rows, manual fspec, low cost |

| Helper (Section 3) | Status | Notes |
|---|---|---|
| `endpoint-functions.R::generate_panels_list` | ✅ already pushed down | No action |
| `endpoint-functions.R::generate_gene_news_tibble` | ✅ already pushed down | No action |
| `endpoint-functions.R::generate_comparisons_list` | ⏸ deferred | Needs SQL view; separate plan |
| `endpoint-functions.R::generate_phenotype_entities_list` | ⏸ deferred | `paste0` aggregate blocks naive pushdown |
| `endpoint-functions.R::generate_variant_entities_list` | ⏸ deferred | Same shape as phenotype helper |

Reference plans:
- v11.3 work: `.planning/superpowers/plans/2026-04-26-v11.3-genes-entities-perf-ux-plan.md`
- This work: `.planning/superpowers/plans/2026-04-29-filter-pushdown-followups-plan.md`
```

- [ ] **Step 2: Commit**

```bash
git add .planning/perf/2026-04-27-filter-pushdown-audit.md
git commit -m "docs(perf): close out audit follow-ups, mark deferred items"
```

### Task D.2: Final verification

- [ ] **Step 1: Run the full local CI**

Run: `make ci-local`

Expected: all green.

- [ ] **Step 2: Manual smoke test**

```bash
make dev
# In browser, exercise:
# - /Genes (the table page) → fspec dropdowns still show correct counts
# - /Genes/GRIN2B → page loads quickly, single API call
# - /Statistics → entities-over-time chart renders
```

- [ ] **Step 3: Bring stack down**

Run: `make docker-down`

- [ ] **Step 4: Push and open PR**

```bash
git push origin <feature-branch>
gh pr create --title "perf: filter-pushdown follow-ups (gene + statistics endpoints)" --body "..."
```

---

## Notes for the executor

- AGENTS.md gotcha: integration tests in `test-integration-pagination.R` need the API up. Ensure `make dev` is running, or the test file should `skip_if(!api_reachable())` (the existing test file does this — copy the pattern).
- AGENTS.md gotcha: `dbplyr` translation is silently best-effort. The `tryCatch` around the SQL pushdown is the safety net — if dbplyr can't translate the user's filter, we fall back to in-R. Don't remove the tryCatch under DRY pressure.
- AGENTS.md gotcha: the MySQL collation is `utf8mb3_general_ci` — `=` is case-insensitive at the SQL level. The case-insensitivity test in A.4 pins this.
- Performance expectations (from v11.3 measurements):
  - Cold-cache `/api/gene/?compact=true&filter=equals(symbol,GRIN2B)`: target < 200 ms (was ~600 ms)
  - Warm-cache: target < 100 ms
  - The statistics endpoints are called from the admin/stats pages and are not on a hot user path; the main improvement is server-side load, not user-perceived latency.
- Audit doc: `.planning/perf/2026-04-27-filter-pushdown-audit.md` — refer to its Section 2 table when in doubt about which sites to touch.
