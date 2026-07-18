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
- **Provenance**: persist + return the **selector object** `{kind: category|explicit|all_ndd, category_filter}`, `resolved_gene_count`, `gene_list_sha256 = sha256(canonical(sort(unique(hgnc_ids))))`, an **intended** fingerprint (`analysis_string_cache_fingerprint()` + `score_threshold=400`, `algorithm`, `seed=42`) in the identity/payload, an **effective** fingerprint (`weight_channel = attr(clusters,"weight_channel")`) in the result meta, and `source_data_version`. `source_data_version` is a **cached, fail-closed** read (`clustering_cached_source_data_version()`), fetched **only when building a payload** — never before admission (its backing view runs global counts/joins). Keep results **non-`public_ready`**.
- **Dedup**: add normalized `category_filter` to the durable `create_job` payload **and** the preflight params **only for category selectors** (explicit/no-arg payloads unchanged → byte-identical `request_hash` to today). The DB `UNIQUE(job_type, active_request_hash)` over the full payload is the authoritative (active-only, best-effort) dedup; #574 makes the identity **selector-aware** but does **not** add an HTTP 409 or change the active-only semantics. The preflight/DB hash-scope inconsistency is pre-existing and out of scope.
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
  - `clustering_normalize_category_filter(category_filter)` → **`NULL` only when the argument is `NULL` (absent)**; **`character(0)` when supplied-but-empty** (`[]`/`[""]`/`["  "]`); otherwise sorted-unique-trimmed `character`. (The absent-vs-empty distinction is load-bearing — empty must 400, absent must default.)
  - `clustering_gene_list_sha256(hgnc_ids)` → chr; `digest::digest(jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE), algo = "sha256", serialize = FALSE)`.
  - `clustering_resolve_category_universe(category_filter, conn = pool)` → `list(hgnc_ids, selector, resolved_gene_count)`. `selector` is `NULL` for the default branch, else the normalized character vector. Throws `stop_for_bad_request` (allowed set **in the message**, not `detail`) on supplied-empty / unknown / inactive token, or on a resolved universe with **< 2** genes.
- Consumes: `generate_ndd_hgnc_ids()` (`analyses-functions.R`), `stop_for_bad_request` (`core/errors.R`).

- [ ] **Step 1: Write failing tests** (use a fake `conn` via a small in-memory tibble seam, or `with_test_db_transaction()` if the resolver takes `conn`). Cover the entity-level semantics with a seam that returns controlled `ndd_entity_view` rows:

```r
# fixture: entity rows (one row per entity). TWO Definitive NDD genes so the
# ["Definitive"] universe passes the >=2 guard (Codex BLOCKER on the earlier
# single-gene fixture).
ev <- tibble::tribble(
  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
  2L,        "HGNC:1",   1L,             "Limited",
  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
  5L,        "HGNC:4",   1L,             "Moderate",     # gene 4: Moderate NDD (single -> too-small alone)
  6L,        "HGNC:5",   1L,             "Definitive"    # gene 5: second Definitive NDD gene
)
cats <- tibble::tibble(category = c("Definitive","Moderate","Limited","Refuted","not applicable"), is_active = 1L)

test_that("Definitive selects genes with any Definitive NDD entity (multi-entity gene included)", {
  r <- clustering_resolve_category_universe("Definitive", conn = fake_conn(ev, cats))
  expect_setequal(r$hgnc_ids, c("HGNC:1","HGNC:5"))   # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
  expect_identical(r$selector, "Definitive")
  expect_identical(r$resolved_gene_count, 2L)
})

test_that("multi-value selector is a union across categories", {
  r <- clustering_resolve_category_universe(c("Definitive","Moderate"), conn = fake_conn(ev, cats))
  expect_setequal(r$hgnc_ids, c("HGNC:1","HGNC:5","HGNC:4"))
})

test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
  r <- clustering_resolve_category_universe(NULL, conn = fake_conn(ev, cats))
  expect_identical(r$hgnc_ids, c("HGNC:1","HGNC:2","HGNC:4","HGNC:5"))  # arrange(entity_id)+distinct, ndd_phenotype==1
  expect_null(r$selector)
})

test_that("unknown token is rejected 400 with the allowed set in the MESSAGE (not detail)", {
  err <- tryCatch(clustering_resolve_category_universe("Definative", conn = fake_conn(ev, cats)), error = function(e) e)
  expect_s3_class(err, "error_400")
  expect_match(conditionMessage(err), "Definitive")   # allowed set is in the message so it reaches clients
})

test_that("supplied-but-empty selector is 400 (NOT the all-NDD default)", {
  expect_error(clustering_resolve_category_universe(list(), conn = fake_conn(ev, cats)), class = "error_400")
  expect_error(clustering_resolve_category_universe(list("   "), conn = fake_conn(ev, cats)), class = "error_400")
})

test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job)", {
  expect_error(clustering_resolve_category_universe("Refuted", conn = fake_conn(ev, cats)), class = "error_400")  # 0 genes
  expect_error(clustering_resolve_category_universe("Moderate", conn = fake_conn(ev, cats)), class = "error_400")  # 1 gene
})

test_that("gene_list_sha256 is sort-order independent", {
  expect_identical(clustering_gene_list_sha256(c("HGNC:3","HGNC:1")), clustering_gene_list_sha256(c("HGNC:1","HGNC:3")))
})
```

- [ ] **Step 2: Run, expect FAIL** (`docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-clustering-gene-universe.R')"` after `docker cp`, or host `Rscript` if the shim resolves the seam).
- [ ] **Step 3: Implement** `clustering-gene-universe.R`:

```r
# api/functions/clustering-gene-universe.R

# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
# selector returns character(0), which the resolver rejects with 400 -- it must
# never fall through to the all-NDD default.
clustering_normalize_category_filter <- function(category_filter) {
  if (is.null(category_filter)) return(NULL)
  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
  vals <- vals[nzchar(vals)]
  if (length(vals) == 0L) return(character(0))   # supplied but empty -> 400 downstream
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
    # Absent -> preserve the exact current default ordering for cache parity.
    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
  }
  if (length(selector) == 0L) {
    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
  }

  active <- conn %>%
    dplyr::tbl("ndd_entity_status_categories_list") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::select(category) %>%
    dplyr::collect() %>%
    dplyr::pull(category)
  unknown <- setdiff(selector, active)
  if (length(unknown) > 0L) {
    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
    stop_for_bad_request(sprintf(
      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
    ))
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
    stop_for_bad_request(sprintf(
      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
      paste(selector, collapse = ","), length(hgnc_ids)
    ))
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
- Consumes: `clustering_resolve_category_universe`, `clustering_gene_list_sha256`, `clustering_normalize_category_filter` (D1); `analysis_string_cache_fingerprint()` (intended fingerprint), a **cached** `analysis_snapshot_source_data_version()` read.
- Produces: the submit handler reads `req$argsBody$category_filter`; decides presence via **`!is.null(req$argsBody$category_filter)`**; builds `selector_obj = list(kind, category_filter)` + `provenance = list(selector = selector_obj, resolved_gene_count, gene_list_sha256, intended_fingerprint, source_data_version)`; threads it into the durable payload + both result-`meta` paths; adds `category_filter = selector_chr` to the dedup params **and** payload **only when a category selector was used** (explicit/no-arg payloads stay byte-identical to today).

- [ ] **Step 1: Write failing tests** (extend the existing mock-env pattern in `test-unit-job-endpoint-services.R`):

```r
test_that("category_filter and genes are mutually exclusive -> 400", {
  # env stubs: clustering_resolve_category_universe not reached
  res <- new_res()
  out <- with_submit_env(function() svc_job_submit_functional_clustering(
    req = list(argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive"))), res = res))
  expect_identical(res$status, 400L)
})

test_that("category_filter resolves the universe and records the selector object + provenance in the durable payload", {
  captured <- NULL
  env$clustering_resolve_category_universe <- function(cf, conn = NULL) list(hgnc_ids = c("HGNC:1","HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
  env$create_job <- function(operation, params) { captured <<- params; list(job_id = "j1", status = "accepted", estimated_seconds = 5) }
  env$check_duplicate_job <- function(operation, params) { expect_true("category_filter" %in% names(params)); list(duplicate = FALSE) }
  # ... run submit with argsBody$category_filter = list("Definitive"), cache miss ...
  expect_identical(captured$category_filter, "Definitive")
  expect_identical(captured$genes, c("HGNC:1","HGNC:5"))
  expect_identical(captured$provenance$selector$kind, "category")
  expect_identical(captured$provenance$selector$category_filter, "Definitive")
  expect_true(all(c("resolved_gene_count","gene_list_sha256","intended_fingerprint","source_data_version") %in% names(captured$provenance)))
})

test_that("explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
  captured <- NULL
  env$create_job <- function(operation, params) { captured <<- params; list(job_id = "j2", status = "accepted", estimated_seconds = 5) }
  # run with argsBody$genes = list("HGNC:1","HGNC:5"), no category_filter, cache miss:
  expect_false("category_filter" %in% names(captured))          # no key added
  expect_identical(captured$provenance$selector$kind, "explicit")
})

test_that("request_hash is selector-aware: two same-gene selectors differ, identical selectors match", {
  h <- function(genes, algo, cf) async_job_service_request_hash("clustering",
        async_job_service_payload_json(c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))))
  g <- c("HGNC:1","HGNC:5")
  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive","Moderate"))))
  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL))   # explicit/no-arg unchanged
})
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** the submit changes:
  - After the admission guard, read `genes_in <- req$argsBody$genes`. **Presence by raw field**: `category_supplied <- !is.null(req$argsBody$category_filter)`; `has_genes <- !is.null(genes_in) && length(genes_in) > 0`.
  - **Mutual exclusion**: `if (has_genes && category_supplied) stop_for_bad_request("Provide either genes or category_filter, not both")`.
  - **Resolve** the universe + `kind`/`selector_chr`:
    - `has_genes` → `genes_list <- as.character(unlist(genes_in)); kind <- "explicit"; selector_chr <- NULL`.
    - else `category_supplied` → `u <- clustering_resolve_category_universe(req$argsBody$category_filter); genes_list <- u$hgnc_ids; selector_chr <- u$selector; kind <- "category"` (the resolver 400s a supplied-empty/unknown/too-small selector).
    - else → `u <- clustering_resolve_category_universe(NULL); genes_list <- u$hgnc_ids; selector_chr <- NULL; kind <- "all_ndd"`.
  - **Dedup params** (selector-aware only for category runs): `dup_params <- list(genes = genes_list, algorithm = algorithm); if (!is.null(selector_chr)) dup_params$category_filter <- selector_chr; check_duplicate_job("clustering", dup_params)`.
  - **Cheap-path provenance** (no expensive query yet): `selector_obj <- list(kind = kind, category_filter = selector_chr)`; `intended_fingerprint <- list(string_cache_fingerprint = analysis_string_cache_fingerprint(), score_threshold = 400L, algorithm = algorithm, seed = 42L)`; `gene_sha <- clustering_gene_list_sha256(genes_list)`.
  - **Source-data version — CACHED + fail-closed, fetched only when a payload is actually built** (Codex HIGH: its backing view runs global counts/joins, so never before admission; cache it since it changes rarely): a new `clustering_cached_source_data_version()` (short-TTL/process cache over `analysis_snapshot_source_data_version()`); on error → `res$status <- 503; return(list(error="PROVENANCE_UNAVAILABLE", ...))` (never record `NA`).
  - **Assemble `provenance`** just before submit: `list(selector = selector_obj, resolved_gene_count = length(genes_list), gene_list_sha256 = gene_sha, intended_fingerprint = intended_fingerprint, source_data_version = <cached>)`.
  - **Payload** (both cache-hit `store_completed` and `create_job`): start from `list(genes = genes_list, algorithm = algorithm, category_links = category_links, string_id_table = string_id_table, provenance = provenance)`; **add `category_filter = selector_chr` only when `!is.null(selector_chr)`** (explicit/no-arg payloads stay byte-identical to today).
  - **Result meta** (cache-hit path): extend `meta` with `selector = selector_obj`, `resolved_gene_count`, `gene_list_sha256 = gene_sha`, `intended_fingerprint`, `source_data_version`, and the **effective** fingerprint `effective_fingerprint = list(weight_channel = attr(cached_clusters, "weight_channel"))`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** — `feat(api): category_filter on clustering submit with provenance + selector-aware dedup (#574)`.

---

### Task D3: Durable-handler result meta + integration + docs

**Files:**
- Modify: `api/functions/async-job-handlers.R` (`.async_job_run_clustering`)
- Test: `api/tests/testthat/test-integration-clustering-category-submit.R`
- Docs: `api/version_spec.json`, `AGENTS.md`, `documentation/08-development.qmd`

- [ ] **Step 1: Failing integration test** (`with_test_db_transaction()`, seed the D1 fixture entities incl. the 2nd Definitive gene into `ndd_entity_view`'s base tables): submit `category_filter=["Definitive"]` (cache miss) → the durable job's `request_payload_json` contains `genes == resolved Definitive set` (the AC: correct universe, **no client-side filter**) + `category_filter == "Definitive"` + `provenance$gene_list_sha256`; the job result `meta` carries `selector` (`kind="category"`), `resolved_gene_count`, `gene_list_sha256`, `intended_fingerprint`, `source_data_version`, and `effective_fingerprint$weight_channel`. Backward compat: an explicit-`genes` submit and a no-arg submit produce a payload with **no** `category_filter` key and `selector$kind` `"explicit"`/`"all_ndd"`. (Selector-aware `request_hash` distinctness is covered by the D2 unit test; do **not** assert HTTP 409 here — dedup is active-only/best-effort and `create_job` returns 202, §7.)
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** `.async_job_run_clustering` to merge `payload$provenance` and the **effective** `effective_fingerprint = list(weight_channel = attr(clusters, "weight_channel"))` into the returned `meta`, so a worker-run (cache-miss) job records the same provenance as the cache-hit path (a silent exp+db→combined fallback is then visible in the stored result).
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Docs + commit** — document the `category_filter` body param + provenance in `api/version_spec.json`, add an AGENTS invariant (entity-level resolution; not `public_ready`; dedup on selector), note the workflow in `08-development.qmd`. **Gate:** `make ci-local`. Commit `feat(api): record clustering provenance in job meta + docs (#574)`.

---

## Self-review (against the spec)

- **Spec coverage:** §4 semantics → D1 resolver + D2 mutual exclusion; §5 resolver → D1; §6 provenance → D2/D3; §7 dedup → D2 (payload+preflight `category_filter`); §8 edge cases → D1/D3 tests (all 15 enumerated map to a test); §9 error contract → D1/D2 (`stop_for_bad_request`); §10 non-goals honored (phenotype submit + category GET untouched); §11 tests → D1/D3; §12 facts → Global Constraints.
- **Placeholder scan:** resolver + normalization + sha256 are shown in full; the submit-service edits reference exact existing lines (67–76, 87, 130–189, 212–220) and list every field to add; the integration test enumerates concrete assertions.
- **Type consistency:** `clustering_resolve_category_universe` returns `list(hgnc_ids, selector, resolved_gene_count)` consumed identically in D2/D3; `provenance` = `{selector: {kind, category_filter}, resolved_gene_count, gene_list_sha256, intended_fingerprint, source_data_version}` (identity/payload) + `effective_fingerprint` (result meta) — matched across payload, cache-hit meta, and handler meta; `category_filter` payload key present iff `selector$kind == "category"`.
- **Codex-reconciled (gpt-5.6-terra):** fixture seeds 2 Definitive genes (min-2 guard); supplied-empty selector → 400 (not default); allowed set in the error **message** (handler serializes `conditionMessage`); `source_data_version` cached + fail-closed + post-admission; intended vs effective STRING channel split; **no HTTP-409 claim** (dedup is active-only/best-effort, identity is merely selector-aware); explicit/no-arg payloads byte-identical to today. Review + reconciliation in `.planning/reviews/2026-07-18-category-clustering-universes-574-codex-*.md`.

## Execution handoff

Independent of the #573 slices — can land in parallel. One PR: branch → plan-review → TDD (D1→D2→D3) → Codex diff-review → PR.
