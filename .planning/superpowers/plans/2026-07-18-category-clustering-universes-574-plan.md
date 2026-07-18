# Category-Selected Gene Universes for Functional Clustering (#574) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `POST /api/jobs/clustering/submit` accept a `category_filter` (e.g. `["Definitive"]`) that resolves the clustering gene universe from curated SysNDD confidence categories at the **entity** level, with an auditable provenance record, while leaving the explicit-`genes` path, the no-args default, and the fixed public snapshot GET unchanged.

**Architecture:** A new `clustering_resolve_category_universe()` helper resolves `category_filter` → distinct HGNC ids from `ndd_entity_view` (approved-public, per-entity, `ndd_phenotype == 1`, `category %in% active-vocab`), reusing `generate_ndd_hgnc_ids()` for the NULL default. The submit service validates mutual exclusion, threads the normalized selector + `gene_list_sha256` + analysis fingerprint into the durable payload (so the DB `active_request_hash` constraint distinguishes selectors) and the result `meta`.

**Tech Stack:** R/Plumber, dbplyr over MySQL, `digest`/`jsonlite`, testthat.

**Spec:** `.planning/superpowers/specs/2026-07-18-category-clustering-universes-574-design.md`

## Global Constraints

- **Entity-level resolution**: filter `ndd_entity_view` *entity rows* (`filter(ndd_phenotype == 1, category %in% cats)`) then `distinct(hgnc_id)`. A gene with ≥1 entity in a selected category qualifies even with other-category entities. **Never** use `select_network_gene_category()` (the gene-level display-label aggregator — node coloring only).
- **Validate live**: allowlist = `ndd_entity_status_categories_list WHERE is_active = 1` (values `Definitive/Moderate/Limited/Refuted/not applicable`; `is_active` added by migration 033). No hardcoded category strings; no category string interpolated into SQL (dbplyr `%in%` + allowlist pre-check).
- **Mutual exclusion**: `genes` + non-empty `category_filter` → 400. Neither → all NDD genes (byte-identical to today via `generate_ndd_hgnc_ids()`).
- **Provenance**: persist + return `selector` (normalized), `resolved_gene_count`, `gene_list_sha256 = sha256(canonical(sort(unique(hgnc_ids))))`, and an `analysis_fingerprint` (`cluster_logic_version`, `source_data_version`, `string_weight_channel`, `score_threshold=400`, `algorithm`, `seed=42`). Keep results **non-`public_ready`**.
- **Dedup**: add normalized `category_filter` to the durable `create_job` payload (the DB `UNIQUE(job_type, active_request_hash)` over the full payload is the authoritative dedup) and to the preflight `check_duplicate_job` params. Do **not** touch the pre-existing preflight/DB hash-scope inconsistency beyond that.
- Error path: category validation / mutual-exclusion / empty-universe → `stop_for_bad_request` (RFC 9457 problem+json). Pre-existing 409 (dup) / 503 (capacity) direct-status responses unchanged.
- No new deps; keep touched files < 600 lines; namespace `dplyr::` verbs; `base::get`; approved-public data only.
- Gates: `make lint-api`, `make test-api-fast`, then `make ci-local`; `make code-quality-audit`.

## File structure

- Create `api/functions/clustering-gene-universe.R` — the resolver + selector normalization + sorted sha256 helper.
- Create `api/tests/testthat/test-unit-clustering-gene-universe.R`.
- Modify `api/services/job-functional-submission-service.R` — accept `category_filter`, mutual exclusion, resolve via helper, provenance + dedup, meta on both the cache-hit and create_job paths.
- Modify `api/functions/async-job-handlers.R` — `.async_job_run_clustering` echoes the payload provenance + adds `string_weight_channel` (from the result attr) into result `meta`.
- Modify `api/bootstrap/load_modules.R` — register `clustering-gene-universe.R` (before the submission service).
- Modify `api/tests/testthat/test-unit-job-endpoint-services.R` — new branches.
- Create `api/tests/testthat/test-integration-clustering-category-submit.R`.
- Docs: `api/version_spec.json` (endpoint body), `AGENTS.md` (note), `documentation/08-development.qmd`.

---

### Task D1: Gene-universe resolver + provenance helpers

**Files:**
- Create: `api/functions/clustering-gene-universe.R`
- Test: `api/tests/testthat/test-unit-clustering-gene-universe.R`
- Modify: `api/bootstrap/load_modules.R` (source it before `services/job-functional-submission-service.R`)

**Interfaces:**
- Produces:
  - `clustering_normalize_category_filter(category_filter)` → `NULL` (absent/empty) or sorted-unique-trimmed `character`.
  - `clustering_gene_list_sha256(hgnc_ids)` → chr; `digest::digest(jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE), algo = "sha256", serialize = FALSE)`.
  - `clustering_resolve_category_universe(category_filter, conn = pool)` → `list(hgnc_ids, selector, resolved_gene_count)`. Throws `stop_for_bad_request` on empty/unknown/inactive token or empty-universe.
- Consumes: `generate_ndd_hgnc_ids()` (`analyses-functions.R`), `stop_for_bad_request` (`core/errors.R`).

- [ ] **Step 1: Write failing tests** (use a fake `conn` via a small in-memory tibble seam, or `with_test_db_transaction()` if the resolver takes `conn`). Cover the entity-level semantics with a seam that returns controlled `ndd_entity_view` rows:

```r
# fixture: entity rows (one row per entity)
ev <- tibble::tribble(
  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
  2L,        "HGNC:1",   1L,             "Limited",
  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
  5L,        "HGNC:4",   1L,             "Moderate"      # gene 4: Moderate NDD
)
cats <- tibble::tibble(category = c("Definitive","Moderate","Limited","Refuted","not applicable"), is_active = 1L)

test_that("Definitive selects a gene with any Definitive NDD entity (multi-entity gene included)", {
  r <- clustering_resolve_category_universe("Definitive", conn = fake_conn(ev, cats))
  expect_setequal(r$hgnc_ids, "HGNC:1")          # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
  expect_identical(r$selector, "Definitive")
  expect_identical(r$resolved_gene_count, 1L)
})

test_that("multi-value selector is a union across categories", {
  r <- clustering_resolve_category_universe(c("Definitive","Moderate"), conn = fake_conn(ev, cats))
  expect_setequal(r$hgnc_ids, c("HGNC:1","HGNC:4"))
})

test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
  # stub generate_ndd_hgnc_ids() to return the entity-view NDD distinct set
  r <- clustering_resolve_category_universe(NULL, conn = fake_conn(ev, cats))
  expect_identical(r$hgnc_ids, c("HGNC:1","HGNC:2","HGNC:4"))  # arrange(entity_id)+distinct, ndd_phenotype==1
  expect_null(r$selector)
})

test_that("unknown / inactive / empty tokens are rejected 400", {
  expect_error(clustering_resolve_category_universe("Definative", conn = fake_conn(ev, cats)), class = "error_400")
  expect_error(clustering_resolve_category_universe(character(0), conn = fake_conn(ev, cats)), class = "error_400")
})

test_that("a valid category resolving to zero genes is rejected 400 (no empty-graph job)", {
  expect_error(clustering_resolve_category_universe("Refuted", conn = fake_conn(ev, cats)), class = "error_400")
})

test_that("gene_list_sha256 is sort-order independent", {
  expect_identical(clustering_gene_list_sha256(c("HGNC:3","HGNC:1")), clustering_gene_list_sha256(c("HGNC:1","HGNC:3")))
})
```

- [ ] **Step 2: Run, expect FAIL** (`docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-clustering-gene-universe.R')"` after `docker cp`, or host `Rscript` if the shim resolves the seam).
- [ ] **Step 3: Implement** `clustering-gene-universe.R`:

```r
# api/functions/clustering-gene-universe.R
clustering_normalize_category_filter <- function(category_filter) {
  if (is.null(category_filter)) return(NULL)
  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
  vals <- vals[nzchar(vals)]
  if (length(vals) == 0L) return(NULL)
  sort(unique(vals))
}

clustering_gene_list_sha256 <- function(hgnc_ids) {
  digest::digest(
    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
    algo = "sha256", serialize = FALSE
  )
}

clustering_resolve_category_universe <- function(category_filter, conn = pool) {
  selector <- clustering_normalize_category_filter(category_filter)

  if (is.null(selector)) {
    # Preserve the exact current default ordering for cache parity.
    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
  }

  active <- conn %>%
    dplyr::tbl("ndd_entity_status_categories_list") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::select(category) %>%
    dplyr::collect() %>%
    dplyr::pull(category)
  unknown <- setdiff(selector, active)
  if (length(unknown) > 0L) {
    stop_for_bad_request(
      sprintf("Unknown or inactive category_filter value(s): %s", paste(unknown, collapse = ", ")),
      detail = sprintf("Allowed active categories: %s", paste(sort(active), collapse = ", "))
    )
  }

  hgnc_ids <- conn %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::arrange(entity_id) %>%
    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
    dplyr::select(hgnc_id) %>%
    dplyr::collect() %>%
    unique() %>%
    dplyr::pull(hgnc_id)

  if (length(hgnc_ids) < 2L) {
    stop_for_bad_request(
      "Resolved gene universe is empty or too small for clustering",
      detail = sprintf("category_filter=[%s] resolved %d gene(s)", paste(selector, collapse = ","), length(hgnc_ids))
    )
  }
  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
}
```

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Register + commit** — add the `source()` in `bootstrap/load_modules.R` before the submission service; `git commit -m "feat(api): category-selected clustering gene-universe resolver (#574)"`.

---

### Task D2: Submit-endpoint wiring (category_filter, mutual exclusion, provenance, dedup)

**Files:**
- Modify: `api/services/job-functional-submission-service.R`
- Test: `api/tests/testthat/test-unit-job-endpoint-services.R` (extend)

**Interfaces:**
- Consumes: `clustering_resolve_category_universe`, `clustering_gene_list_sha256` (D1); `CLUSTER_LOGIC_VERSION`, `analysis_snapshot_source_data_version` (fingerprint).
- Produces: the submit handler now reads `req$argsBody$category_filter`; builds `provenance = list(selector, resolved_gene_count, gene_list_sha256, analysis_fingerprint)`; threads it into the durable payload and both result-`meta` paths; adds `category_filter = selector` to the dedup params + payload.

- [ ] **Step 1: Write failing tests** (extend the existing mock-env pattern in `test-unit-job-endpoint-services.R`):

```r
test_that("category_filter and genes are mutually exclusive -> 400", {
  # env stubs: clustering_resolve_category_universe not reached
  res <- new_res()
  out <- with_submit_env(function() svc_job_submit_functional_clustering(
    req = list(argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive"))), res = res))
  expect_identical(res$status, 400L)
})

test_that("category_filter resolves the universe and records provenance in the durable payload", {
  captured <- NULL
  env$clustering_resolve_category_universe <- function(cf, conn = NULL) list(hgnc_ids = c("HGNC:1","HGNC:4"), selector = "Definitive", resolved_gene_count = 2L)
  env$create_job <- function(operation, params) { captured <<- params; list(job_id = "j1", status = "accepted", estimated_seconds = 5) }
  env$check_duplicate_job <- function(operation, params) { expect_true("category_filter" %in% names(params)); list(duplicate = FALSE) }
  # ... run submit with argsBody$category_filter = list("Definitive"), cache miss ...
  expect_identical(captured$category_filter, "Definitive")
  expect_identical(captured$genes, c("HGNC:1","HGNC:4"))
  expect_true(all(c("selector","resolved_gene_count","gene_list_sha256","analysis_fingerprint") %in% names(captured$provenance)))
})

test_that("no genes and no category_filter -> all NDD genes (backward compatible)", {
  # resolver stub for NULL returns the all-NDD set; assert create_job genes == that set and category_filter is NULL
})
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** the submit changes:
  - After the admission guard, read `category_filter <- req$argsBody$category_filter` and `genes_in <- req$argsBody$genes`.
  - **Mutual exclusion**: if `!is.null(genes_in) && length(genes_in) > 0` **and** `length(clustering_normalize_category_filter(category_filter)) > 0` → `stop_for_bad_request("Provide either genes or category_filter, not both")`.
  - **Resolve** the universe: if an explicit `genes_in` is given, `genes_list <- genes_in; selector <- NULL`; else `u <- clustering_resolve_category_universe(category_filter); genes_list <- u$hgnc_ids; selector <- u$selector` (this covers the NULL default too).
  - Compute `provenance <- list(selector = selector, resolved_gene_count = length(genes_list), gene_list_sha256 = clustering_gene_list_sha256(genes_list), analysis_fingerprint = list(cluster_logic_version = CLUSTER_LOGIC_VERSION, source_data_version = tryCatch(analysis_snapshot_source_data_version(), error = function(e) NA_character_), score_threshold = 400L, algorithm = algorithm, seed = 42L))`.
  - **Dedup**: `check_duplicate_job("clustering", list(genes = genes_list, algorithm = algorithm, category_filter = selector))`.
  - **Payload** (both cache-hit `store_completed` and `create_job`): add `category_filter = selector` and `provenance = provenance` to the `request_payload`/`params` list (alongside the existing `genes, algorithm, category_links, string_id_table`).
  - **Result meta** (cache-hit path): extend `meta` with `selector`, `resolved_gene_count = length(genes_list)`, `gene_list_sha256 = provenance$gene_list_sha256`, `analysis_fingerprint = provenance$analysis_fingerprint`, and `string_weight_channel = attr(cached_clusters, "weight_channel")`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** — `feat(api): category_filter on clustering submit with provenance + selector-aware dedup (#574)`.

---

### Task D3: Durable-handler result meta + integration + docs

**Files:**
- Modify: `api/functions/async-job-handlers.R` (`.async_job_run_clustering`)
- Test: `api/tests/testthat/test-integration-clustering-category-submit.R`
- Docs: `api/version_spec.json`, `AGENTS.md`, `documentation/08-development.qmd`

- [ ] **Step 1: Failing integration test** (`with_test_db_transaction()`, seed the D1 fixture entities into `ndd_entity_view`'s base tables or a view stub): submit `category_filter=["Definitive"]` (cache miss) → the durable job's `request_payload_json` contains `genes == resolved Definitive set` + `category_filter == "Definitive"` + `provenance.gene_list_sha256`; the job result `meta` carries `selector/resolved_gene_count/gene_list_sha256/analysis_fingerprint/string_weight_channel`. Also: explicit-`genes` submit and no-arg submit retain today's payload shape (backward compat); two identical `["Definitive"]` concurrent submits → one active job; `["Definitive"]` vs a same-gene `["Definitive","Moderate"]` → two jobs.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** `.async_job_run_clustering` to merge the payload `provenance` and `attr(clusters, "weight_channel")` into the returned `meta` (echo `payload$provenance` fields + `string_weight_channel`), so a worker-run (cache-miss) job records the same provenance as the cache-hit path.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Docs + commit** — document the `category_filter` body param + provenance in `api/version_spec.json`, add an AGENTS invariant (entity-level resolution; not `public_ready`; dedup on selector), note the workflow in `08-development.qmd`. **Gate:** `make ci-local`. Commit `feat(api): record clustering provenance in job meta + docs (#574)`.

---

## Self-review (against the spec)

- **Spec coverage:** §4 semantics → D1 resolver + D2 mutual exclusion; §5 resolver → D1; §6 provenance → D2/D3; §7 dedup → D2 (payload+preflight `category_filter`); §8 edge cases → D1/D3 tests (all 15 enumerated map to a test); §9 error contract → D1/D2 (`stop_for_bad_request`); §10 non-goals honored (phenotype submit + category GET untouched); §11 tests → D1/D3; §12 facts → Global Constraints.
- **Placeholder scan:** resolver + normalization + sha256 are shown in full; the submit-service edits reference exact existing lines (67–76, 87, 130–189, 212–220) and list every field to add; the integration test enumerates concrete assertions.
- **Type consistency:** `clustering_resolve_category_universe` returns `list(hgnc_ids, selector, resolved_gene_count)` consumed identically in D2/D3; `provenance` fields (`selector`, `resolved_gene_count`, `gene_list_sha256`, `analysis_fingerprint`) match across payload, cache-hit meta, and handler meta; `category_filter` in dedup params == payload == provenance selector.
- **Locked decision:** dedup correctness rides the DB `active_request_hash` unique constraint (full payload now includes `category_filter`); the preflight/DB hash-scope mismatch is a flagged pre-existing issue, explicitly out of #574 scope.

## Execution handoff

Independent of the #573 slices — can land in parallel. One PR: branch → plan-review → TDD (D1→D2→D3) → Codex diff-review → PR.
