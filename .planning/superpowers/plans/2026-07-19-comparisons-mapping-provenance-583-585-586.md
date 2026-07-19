# Curation-comparison mapping policy + snapshot generator provenance — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In one PR (closing #583, #585, #586), correct the PanelApp evidence-tier crosswalk to a full ordinal mapping with a versioned, drift-proof policy surface; persist additive generator provenance in analysis snapshots; and add a keyboard-accessible tier-mapping help affordance on the Curation Comparisons page.

**Architecture:** #583 changes the read-time normalizer (`category-normalization.R`) and adds a declarative `comparison_category_crosswalk()` (single display source of truth, guarded consistent with the executable normalizer) exposed via a new pure `GET /api/comparisons/crosswalk` and a `mapping_version` carried on `/metadata` + the frozen browse/XLSX outputs. #585 adds a nullable `generator_json` manifest column (migration 046) written additively by the snapshot builder — outside every identity hash — surfaced in `meta.snapshot.generator` + `generator_hash`. #586 adds a reusable Vue popover component fetching the crosswalk endpoint.

**Tech Stack:** R/Plumber + `renv` (api/), MySQL migrations (db/), Vue 3 + TypeScript + Vite + BootstrapVueNext (app/), testthat + vitest.

## Global Constraints

- Additive provenance MUST NOT enter `analysis_snapshot_payload_hash` (excludes `raw`/`partition_validation`/`reproducibility`), `input_hash` (type/params/source_data_version/dependencies), or any per-cluster `cluster_hash`. Do NOT bump `CLUSTER_LOGIC_VERSION` (`"2026-07-06.510-expdb"`). No LLM regeneration.
- Release `content_digest` MUST remain unchanged: provenance goes only in blocks already excluded from it (`generator`, `source`).
- Normalized four-tier vocabulary strings EXACTLY: `Definitive`, `Moderate`, `Limited`, `Refuted` (+ non-tier fillers `not applicable`, `not listed`). No new label.
- PanelApp full ordinal: `3`→`Definitive`, `2`→`Moderate`, `1`→`Limited`. No PanelApp tier maps to `Refuted`. G2P `disputed`/`refuted`→`Refuted` unchanged.
- New migration: `046_add_analysis_snapshot_generator_provenance.sql`; `EXPECTED_LATEST_MIGRATION <- "046_add_analysis_snapshot_generator_provenance.sql"`, `EXPECTED_MIGRATION_COUNT <- 44L`.
- Mapping version literal: `COMPARISON_CATEGORY_MAPPING_VERSION <- "2026-07-19.583-panelapp-ordinal"`.
- API R code must namespace `dplyr::select` etc.; use `base::get` explicitly if dispatching by name (masked by `config`).
- Frontend API access via typed clients in `app/src/api/*` only; no raw axios in components.
- #584 (ZNF41) is OUT of scope — do not touch entity/curation data.

## File structure

- **Workstream A (#583, R + api tests):** `api/functions/category-normalization.R`, `api/endpoints/comparisons_endpoints.R`, `api/functions/comparisons-list.R`, `api/tests/testthat/test-unit-category-normalization.R`, `api/tests/testthat/test-unit-comparisons-crosswalk.R` (new), `api/tests/testthat/test-unit-endpoint-functions.R`.
- **Workstream B (#585, R + SQL + docs):** `db/migrations/046_add_analysis_snapshot_generator_provenance.sql` (new), `api/functions/migration-manifest.R`, `api/functions/analysis-snapshot-provenance-generator.R` (new), `api/endpoints/version_endpoints.R`, `api/functions/analysis-snapshot-builder.R`, `api/functions/analysis-snapshot-repository.R`, `api/services/analysis-snapshot-service.R`, `api/functions/analysis-snapshot-release.R`, `api/bootstrap/load_modules.R`, `api/bootstrap/setup_workers.R`, api tests, `documentation/09-deployment.qmd`.
- **Workstream C (#586, frontend):** `app/src/api/comparisons.ts`, `app/src/components/analyses/EvidenceTierMappingHelp.vue` (new), `app/src/components/analyses/AnalysesCurationUpset.vue`, `app/src/components/analyses/EvidenceTierMappingHelp.spec.ts` (new), `app/src/components/analyses/AnalysesCurationUpset.spec.ts`.
- **Workstream D (cross-cutting docs):** `CHANGELOG.md`, `AGENTS.md`.

**Parallelization:** A, B, C are file-disjoint and can run concurrently. C's typed client is written against the crosswalk shape defined in Task A2 (fully specified below), integration-verified at the end. D runs last (touches shared CHANGELOG/AGENTS). Within B, do B1→B2→B3→B4 in order (shared files), B5/B6 after B4.

---

## Workstream A — #583 PanelApp crosswalk + mapping version

### Task A1: PanelApp full-ordinal mapping change

**Files:**
- Modify: `api/functions/category-normalization.R:67-69` (mapping), `:28-31` (roxygen)
- Test: `api/tests/testthat/test-unit-category-normalization.R:66-78`

**Interfaces:**
- Produces: `normalize_comparison_categories(data)` unchanged signature; PanelApp `2→Moderate`, `1→Limited`.

- [ ] **Step 1: Update the failing test first.** In `test-unit-category-normalization.R`, change the panelapp test (lines 66-78) to:

```r
test_that("normalize_comparison_categories maps panelapp confidence to full ordinal", {
  fixture <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3"),
    list = rep("panelapp", 3),
    category = c("3", "2", "1")
  )

  result <- normalize_comparison_categories(fixture)

  expect_equal(result$category[1], "Definitive")  # Green/3
  expect_equal(result$category[2], "Moderate")     # Amber/2 (was Limited)
  expect_equal(result$category[3], "Limited")      # Red/1  = low evidence, NOT Refuted
})

test_that("gene2phenotype disputed/refuted still map to Refuted (asymmetry lock)", {
  fixture <- tibble(
    symbol = c("A", "B"),
    list = rep("gene2phenotype", 2),
    category = c("disputed", "refuted")
  )
  result <- normalize_comparison_categories(fixture)
  expect_equal(result$category, c("Refuted", "Refuted"))
})
```

Also update the per-source regression test at `test-unit-category-normalization.R:163`: `panelapp "2"` now expects `"Moderate"` (was `"Limited"`).

- [ ] **Step 2: Run to confirm it fails.**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-category-normalization.R')"`
Expected: FAIL (current code returns Limited/Refuted for 2/1).

- [ ] **Step 3: Change the mapping.** In `api/functions/category-normalization.R`, lines 67-69 become:

```r
      # panelapp mappings (Genomics England confidence: 3=Green, 2=Amber, 1=Red)
      # Full ordinal: Green->Definitive, Amber->Moderate, Red->Limited. Red is LOW
      # evidence, NOT affirmative refutation (issue #583). No panelapp tier maps to Refuted.
      list == "panelapp" & category == "3" ~ "Definitive",
      list == "panelapp" & category == "2" ~ "Moderate",
      list == "panelapp" & category == "1" ~ "Limited",
```

And update the roxygen `@details` (lines 28-31) to:

```r
#' - **panelapp** (Genomics England confidence 1-3; Red/Amber/Green):
#'   - "3" (Green) → "Definitive"
#'   - "2" (Amber) → "Moderate"
#'   - "1" (Red)   → "Limited"   (low evidence, NOT Refuted — issue #583)
```

- [ ] **Step 4: Run to confirm pass.**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-category-normalization.R')"`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add api/functions/category-normalization.R api/tests/testthat/test-unit-category-normalization.R
git commit -m "fix(comparisons): map PanelApp full ordinal (Amber->Moderate, Red->Limited) (#583)"
```

### Task A2: Mapping version + declarative crosswalk + consistency guard

**Files:**
- Modify: `api/functions/category-normalization.R` (append constant + `comparison_category_crosswalk()`)
- Test: `api/tests/testthat/test-unit-comparisons-crosswalk.R` (new)

**Interfaces:**
- Produces: `COMPARISON_CATEGORY_MAPPING_VERSION` (character scalar); `comparison_category_crosswalk()` returning a list `{mapping_version, tiers[], sources[], notes[]}` where each `sources[].rules[]` element is `{native_value, native_label, normalized_tier, rule_kind, note}`.

- [ ] **Step 1: Write the failing consistency + shape test** in `api/tests/testthat/test-unit-comparisons-crosswalk.R`:

```r
# test-unit-comparisons-crosswalk.R
library(testthat); library(tibble); library(dplyr)
api_dir <- if (basename(getwd()) == "testthat") normalizePath(file.path(getwd(), "..", "..")) else getwd()
source(file.path(api_dir, "functions/category-normalization.R"))

test_that("mapping_version is a non-empty scalar and matches the crosswalk", {
  expect_true(nzchar(COMPARISON_CATEGORY_MAPPING_VERSION))
  cw <- comparison_category_crosswalk()
  expect_identical(cw$mapping_version, COMPARISON_CATEGORY_MAPPING_VERSION)
  expect_true(all(c("mapping_version", "tiers", "sources", "notes") %in% names(cw)))
})

test_that("every crosswalk rule agrees with the executable normalizer (no drift)", {
  cw <- comparison_category_crosswalk()
  for (src in cw$sources) {
    for (rule in src$rules) {
      # Build a probe native value per rule_kind
      probe <- switch(rule$rule_kind,
        missing = NA_character_,
        case_insensitive = toupper(rule$native_value),  # exercise casing
        fallback = "Totally Unknown Tier XYZ",            # arbitrary -> fallback tier
        all_values = "any arbitrary value",               # arbitrary -> single tier
        rule$native_value                                  # exact / passthrough
      )
      got <- normalize_comparison_categories(
        tibble(symbol = "G", list = src$list, category = probe)
      )$category[[1]]
      expect_identical(got, rule$normalized_tier,
        info = sprintf("%s / %s (%s)", src$list, rule$native_value, rule$rule_kind))
    }
  }
})

test_that("PanelApp crosswalk encodes the full ordinal and never Refuted", {
  cw <- comparison_category_crosswalk()
  pa <- Filter(function(s) s$list == "panelapp", cw$sources)[[1]]
  tiers <- vapply(pa$rules, function(r) r$normalized_tier, character(1))
  expect_setequal(tiers, c("Definitive", "Moderate", "Limited"))
  expect_false("Refuted" %in% tiers)
})
```

- [ ] **Step 2: Run to confirm it fails** (function undefined).

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-comparisons-crosswalk.R')"`
Expected: FAIL — `could not find function "comparison_category_crosswalk"`.

- [ ] **Step 3: Append the constant + crosswalk to `api/functions/category-normalization.R`:**

```r
#### Mapping policy version + declarative crosswalk (issue #583/#586) ####

# Single policy identifier surfaced to consumers so frozen downstream
# comparisons can distinguish old from new normalization policy. Bump the date
# and suffix whenever a mapping rule changes.
COMPARISON_CATEGORY_MAPPING_VERSION <- "2026-07-19.583-panelapp-ordinal"

#' Declarative evidence-tier crosswalk (single display source of truth).
#'
#' Serialized by GET /api/comparisons/crosswalk and rendered by the frontend
#' tier-mapping help. A guard test (test-unit-comparisons-crosswalk.R) drives
#' `normalize_comparison_categories()` from these rows so the display can never
#' drift from the executable normalizer. `rule_kind` tells the guard how to
#' probe each rule: exact | case_insensitive | missing | fallback | all_values
#' | passthrough.
#' @export
comparison_category_crosswalk <- function() {
  rule <- function(native_value, native_label, normalized_tier, rule_kind, note = NA_character_) {
    list(native_value = native_value, native_label = native_label,
         normalized_tier = normalized_tier, rule_kind = rule_kind, note = note)
  }
  list(
    mapping_version = COMPARISON_CATEGORY_MAPPING_VERSION,
    tiers = list(
      list(tier = "Definitive", definition = "Strong, established gene-disease evidence."),
      list(tier = "Moderate",   definition = "Moderate evidence."),
      list(tier = "Limited",    definition = "Limited / low evidence."),
      list(tier = "Refuted",    definition = "Evidence disputes the association.")
    ),
    sources = list(
      list(list = "panelapp", label = "PanelApp", rules = list(
        rule("3", "Green (3)", "Definitive", "exact"),
        rule("2", "Amber (2)", "Moderate",   "exact"),
        rule("1", "Red (1)",   "Limited",    "exact", "Red = low evidence, not Refuted.")
      )),
      list(list = "gene2phenotype", label = "Gene2Phenotype", rules = list(
        rule("strong",         "strong",         "Definitive", "case_insensitive"),
        rule("definitive",     "definitive",     "Definitive", "case_insensitive"),
        rule("moderate",       "moderate",       "Moderate",   "case_insensitive"),
        rule("limited",        "limited",        "Limited",    "case_insensitive"),
        rule("disputed",       "disputed",       "Refuted",    "case_insensitive"),
        rule("refuted",        "refuted",        "Refuted",    "case_insensitive"),
        rule("both rd and if", "both RD and IF", "Definitive", "case_insensitive")
      )),
      list(list = "sfari", label = "SFARI Gene", rules = list(
        rule("1", "score 1", "Definitive", "exact"),
        rule("2", "score 2", "Moderate",   "exact"),
        rule("3", "score 3", "Limited",    "exact"),
        rule(NA_character_, "ungraded (NA)", "Definitive", "missing")
      )),
      list(list = "ndd_genehub", label = "NDD GeneHub", rules = list(
        rule("Tier 1",  "Tier 1", "Definitive", "exact"),
        rule("AR",      "AR",     "Definitive", "exact"),
        rule("Tier 2",  "Tier 2", "Moderate",   "exact"),
        rule("Tier 3",  "Tier 3", "Limited",    "exact"),
        rule("Tier 4",  "Tier 4", "Limited",    "exact"),
        rule("Missense","Missense","Limited",   "exact"),
        rule("*",       "other / Unclassified", "Limited", "fallback")
      )),
      list(list = "radboudumc_ID", label = "Radboudumc ID", rules = list(
        rule("*", "any (ungraded inclusion list)", "Definitive", "all_values",
             "Ungraded inclusion list -> implied Definitive for comparability.")
      )),
      list(list = "SysNDD", label = "SysNDD", rules = list(
        rule("*", "native SysNDD category", NA_character_, "passthrough",
             "SysNDD categories pass through unchanged.")
      ))
    ),
    notes = list(
      "PanelApp Red/1 normalizes to Limited (low evidence), never Refuted.",
      "Ungraded inclusion lists (Radboudumc, OMIM NDD, Orphanet) receive an implied Definitive for comparability, not a native equivalent tier.",
      "Only explicit source-native disputed/refuted assertions (e.g. Gene2Phenotype) map to Refuted."
    )
  )
}
```

Note: the `passthrough` (`SysNDD`) rule has `normalized_tier = NA` — the guard test skips tier assertion for passthrough by construction (probe equals native `"*"`, normalizer returns `"*"` unchanged, which the guard compares against `NA`). To keep the guard clean, the guard test filters out `rule_kind == "passthrough"` rows before asserting. **Add this filter to the Step-1 test** (`if (rule$rule_kind == "passthrough") next`).

- [ ] **Step 4: Update the guard test to skip passthrough**, then run.

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-comparisons-crosswalk.R')"`
Expected: PASS (all rules agree with the normalizer; PanelApp never Refuted).

- [ ] **Step 5: Commit.**

```bash
git add api/functions/category-normalization.R api/tests/testthat/test-unit-comparisons-crosswalk.R
git commit -m "feat(comparisons): declarative tier crosswalk + mapping_version with drift guard (#583)"
```

### Task A3: Expose crosswalk endpoint + mapping_version on metadata + frozen browse/XLSX

**Files:**
- Modify: `api/endpoints/comparisons_endpoints.R` (add `/crosswalk`; `mapping_version` in all 3 `/metadata` paths)
- Modify: `api/functions/comparisons-list.R` (add `mapping_version` to `meta`)
- Test: append to `api/tests/testthat/test-unit-comparisons-crosswalk.R`

**Interfaces:**
- Consumes: `comparison_category_crosswalk()`, `COMPARISON_CATEGORY_MAPPING_VERSION` (Task A2).
- Produces: `GET /api/comparisons/crosswalk` → the crosswalk object; `/metadata` gains `mapping_version`; browse `meta` gains `mapping_version`.

- [ ] **Step 1: Write the failing endpoint-shape test** (append to `test-unit-comparisons-crosswalk.R`): source `comparisons_endpoints.R`'s crosswalk handler is a plumber file, so test the underlying function instead — assert the browse `meta` carries `mapping_version` by unit-testing the meta assembly is out of easy reach; instead assert the CONSTANT is referenced. Add:

```r
test_that("crosswalk object is JSON-serializable and stable", {
  cw <- comparison_category_crosswalk()
  j <- jsonlite::toJSON(cw, auto_unbox = TRUE, null = "null")
  expect_true(nchar(j) > 100)
  back <- jsonlite::fromJSON(j, simplifyVector = FALSE)
  expect_identical(back$mapping_version, COMPARISON_CATEGORY_MAPPING_VERSION)
})
```

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-comparisons-crosswalk.R')"` → PASS (this already works after A2; it locks serialization).

- [ ] **Step 2: Add the `/crosswalk` endpoint** in `api/endpoints/comparisons_endpoints.R` (near `/metadata`/`/sources`):

```r
#* Get the normalized evidence-tier crosswalk
#*
#* Pure, in-memory (no DB, no external). Returns the declarative mapping of
#* source-native confidence labels to the normalized four-tier scale plus the
#* mapping policy version. This is the authoritative complete versioned mapping
#* table the Curation Comparisons help affordance links to (issue #586).
#*
#* @tag comparisons
#* @serializer json list(na="string")
#*
#* @get /crosswalk
function() {
  comparison_category_crosswalk()
}
```

- [ ] **Step 3: Add `mapping_version` to all three `/metadata` return paths** in `api/endpoints/comparisons_endpoints.R` — add `mapping_version = COMPARISON_CATEGORY_MAPPING_VERSION,` as the first field of each of the three returned `list(...)` (missing-table fallback, empty-row fallback, populated row).

- [ ] **Step 4: Add `mapping_version` to the browse `meta`** in `api/functions/comparisons-list.R` — in the `add_column(as_tibble(list(...)))` meta block (~lines 148-154), add `"mapping_version" = COMPARISON_CATEGORY_MAPPING_VERSION,`. This makes a saved browse JSON and the XLSX export (which serializes `comparisons_list`) self-identifying.

- [ ] **Step 5: Restart the dev API and smoke-test the routes** (read-time change, API restart applies it):

Run:
```bash
curl -s http://localhost:7777/api/comparisons/crosswalk | head -c 400
curl -s "http://localhost:7777/api/comparisons/metadata" | grep -o '"mapping_version":"[^"]*"'
```
Expected: crosswalk JSON with `mapping_version`; metadata carries the same version. (If the dev stack is not running, this is verified at the integration gate instead.)

- [ ] **Step 6: Commit.**

```bash
git add api/endpoints/comparisons_endpoints.R api/functions/comparisons-list.R api/tests/testthat/test-unit-comparisons-crosswalk.R
git commit -m "feat(comparisons): /crosswalk endpoint + mapping_version on metadata & browse/xlsx (#583)"
```

### Task A4: Retire the stale duplicate normalizer test

**Files:**
- Modify: `api/tests/testthat/test-unit-endpoint-functions.R:277-296`

- [ ] **Step 1:** Replace the inline `case_when` reimplementation (lines 277-296) with a call to the real function so there is one mapping source. Change the fixture assertions to use `normalize_comparison_categories()` and drop the local `mutate(case_when(...))`. If the surrounding test only exercised PanelApp `"3"→Definitive`, replace with:

```r
test_that("normalize_comparison_categories is the single mapping authority", {
  res <- normalize_comparison_categories(
    tibble::tibble(symbol = "G", list = "panelapp", category = "3")
  )
  expect_equal(res$category[[1]], "Definitive")
})
```

(Ensure `category-normalization.R` is sourced by this test file; add `source(...)` if not already present.)

- [ ] **Step 2: Run.** `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-endpoint-functions.R')"` → PASS.

- [ ] **Step 3: Commit.**

```bash
git add api/tests/testthat/test-unit-endpoint-functions.R
git commit -m "test(comparisons): drop stale duplicate normalizer, defer to single authority (#583)"
```

---

## Workstream B — #585 snapshot generator provenance

### Task B1: Migration 046 + manifest bump + baseline test updates

**Files:**
- Create: `db/migrations/046_add_analysis_snapshot_generator_provenance.sql`
- Modify: `api/functions/migration-manifest.R:5-6`
- Modify: `api/tests/testthat/test-unit-analysis-snapshot-migration.R`, `test-mcp-select-principal-projections.R`, `test-unit-core-views-manifest.R`

- [ ] **Step 1: Write the migration** (idempotent, mirroring existing additive migrations):

```sql
-- 046_add_analysis_snapshot_generator_provenance.sql
-- Additive: immutable generator provenance for analysis snapshots (issue #585).
-- Stored OUTSIDE every identity hash (payload_hash/input_hash/cluster_hash), so
-- it changes no membership, cluster_hash, or LLM summary. Nullable; pre-046
-- snapshots read NULL and omit the generator block.
SET @col_exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'analysis_snapshot_manifest'
    AND COLUMN_NAME = 'generator_json'
);
SET @ddl := IF(@col_exists = 0,
  'ALTER TABLE analysis_snapshot_manifest ADD COLUMN generator_json JSON NULL AFTER package_versions_json',
  'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
```

- [ ] **Step 2: Bump the manifest** in `api/functions/migration-manifest.R`:

```r
EXPECTED_LATEST_MIGRATION <- "046_add_analysis_snapshot_generator_provenance.sql"
EXPECTED_MIGRATION_COUNT <- 44L
```

- [ ] **Step 3: Update baseline assertions.** In each of `test-unit-analysis-snapshot-migration.R`, `test-mcp-select-principal-projections.R`, `test-unit-core-views-manifest.R`, find any assertion pinning the latest migration filename or migration count and update to `046_...` / `44`. (Grep each file for `045_add_analysis_snapshot_release` or `43L`/`EXPECTED_MIGRATION_COUNT`.)

- [ ] **Step 4: Run the affected tests.**

Run: `cd api && Rscript -e "for (f in c('test-unit-analysis-snapshot-migration.R','test-unit-core-views-manifest.R')) testthat::test_file(file.path('tests/testthat', f))"`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add db/migrations/046_add_analysis_snapshot_generator_provenance.sql api/functions/migration-manifest.R api/tests/testthat/test-unit-analysis-snapshot-migration.R api/tests/testthat/test-mcp-select-principal-projections.R api/tests/testthat/test-unit-core-views-manifest.R
git commit -m "feat(db): migration 046 add analysis_snapshot_manifest.generator_json (#585)"
```

### Task B2: Provenance helpers (commit resolver, library versions, generator assembly, gate)

**Files:**
- Create: `api/functions/analysis-snapshot-provenance-generator.R`
- Modify: `api/endpoints/version_endpoints.R` (use the shared resolver)
- Modify: `api/bootstrap/load_modules.R`, `api/bootstrap/setup_workers.R` (register the new file)
- Test: `api/tests/testthat/test-unit-analysis-snapshot-provenance.R` (extend)

**Interfaces:**
- Produces:
  - `resolve_app_git_commit()` → character (env `GIT_COMMIT` → `git rev-parse --short HEAD` → `"unknown"`).
  - `resolve_app_version()` → character (`version_json$version` if the global exists, else read `version_spec.json`, else `"unknown"`).
  - `analysis_generator_library_versions()` → named list of package versions (`NA` per-package on failure).
  - `analysis_snapshot_build_generator(analysis_type, params, generated_at_utc)` → the generator list.
  - `analysis_snapshot_assert_generator_complete(generator, analysis_type)` → invisibly TRUE or `stop()`.
  - Constants `ANALYSIS_SNAPSHOT_BUILDER_VERSION <- "1.0"`, `ANALYSIS_GENERATOR_SCHEMA_VERSION <- "1.0"`.

- [ ] **Step 1: Write failing tests** (extend `test-unit-analysis-snapshot-provenance.R`):

```r
test_that("generator block is complete and reproducible for clustering types", {
  g <- analysis_snapshot_build_generator(
    "functional_clusters",
    params = list(algorithm = "leiden", resolution = 1.0, score_threshold = 400),
    generated_at_utc = "2026-07-19T00:00:00Z"
  )
  expect_identical(g$generator_schema_version, ANALYSIS_GENERATOR_SCHEMA_VERSION)
  expect_true(nzchar(g$application_version))
  expect_true(nzchar(g$snapshot_builder_version))
  expect_identical(g$cluster_logic_version, CLUSTER_LOGIC_VERSION)
  expect_identical(g$generated_at, "2026-07-19T00:00:00Z")
  expect_true("leiden" == g$algorithm$name || "functional_clusters" == g$algorithm$name)
  expect_true(is.list(g$library_versions))
  expect_silent(analysis_snapshot_assert_generator_complete(g, "functional_clusters"))
})

test_that("completeness gate rejects a missing required field", {
  g <- analysis_snapshot_build_generator("functional_clusters",
        list(algorithm = "leiden"), "2026-07-19T00:00:00Z")
  g$cluster_logic_version <- NULL
  expect_error(analysis_snapshot_assert_generator_complete(g, "functional_clusters"))
})

test_that("non-clustering types do not require cluster_logic_version", {
  g <- analysis_snapshot_build_generator("network_edges", list(), "2026-07-19T00:00:00Z")
  expect_silent(analysis_snapshot_assert_generator_complete(g, "network_edges"))
})
```

- [ ] **Step 2: Run to confirm failure** (functions undefined).

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-provenance.R')"`
Expected: FAIL.

- [ ] **Step 3: Write `api/functions/analysis-snapshot-provenance-generator.R`:**

```r
# functions/analysis-snapshot-provenance-generator.R
# Immutable generator provenance for analysis snapshots (issue #585).
# Additive-only: written to the manifest generator_json column, OUTSIDE every
# identity hash. Never bump CLUSTER_LOGIC_VERSION for provenance changes.

ANALYSIS_SNAPSHOT_BUILDER_VERSION <- "1.0"
ANALYSIS_GENERATOR_SCHEMA_VERSION <- "1.0"

# Clustering analysis types whose provenance must record CLUSTER_LOGIC_VERSION.
.analysis_generator_clustering_types <- c("functional_clusters", "phenotype_clusters")

#' Resolve the deployed application git commit (shared with the version endpoint).
#' Priority: GIT_COMMIT env (Docker build injection) > `git rev-parse --short HEAD` > "unknown".
resolve_app_git_commit <- function() {
  commit <- Sys.getenv("GIT_COMMIT", unset = "")
  if (nzchar(commit)) return(commit)
  tryCatch({
    out <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)
    if (length(out) == 0 || !nzchar(out[[1]])) "unknown" else out[[1]]
  }, error = function(e) "unknown")
}

#' Resolve the application semantic version robustly in API and worker contexts.
resolve_app_version <- function() {
  v <- tryCatch(base::get("version_json", envir = .GlobalEnv)$version, error = function(e) NULL)
  if (!is.null(v) && nzchar(v)) return(v)
  vj <- tryCatch(jsonlite::fromJSON(file.path(get_api_dir(), "version_spec.json")), error = function(e) NULL)
  if (!is.null(vj$version) && nzchar(vj$version)) vj$version else "unknown"
}

#' Pinned library versions relevant to clustering reproducibility.
analysis_generator_library_versions <- function() {
  pkgs <- c("igraph", "leidenAlg", "FactoMineR", "factoextra", "STRINGdb", "data.table")
  vers <- lapply(pkgs, function(p) {
    tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
  })
  names(vers) <- pkgs
  vers$r_version <- R.version.string
  vers
}

#' Assemble the immutable generator provenance block.
#' @param generated_at_utc a single UTC ISO-8601 timestamp captured once by the caller.
analysis_snapshot_build_generator <- function(analysis_type, params, generated_at_utc) {
  is_clustering <- analysis_type %in% .analysis_generator_clustering_types
  list(
    generator_schema_version = ANALYSIS_GENERATOR_SCHEMA_VERSION,
    application_version = resolve_app_version(),
    application_commit = resolve_app_git_commit(),
    snapshot_builder_version = ANALYSIS_SNAPSHOT_BUILDER_VERSION,
    cluster_logic_version = if (is_clustering) CLUSTER_LOGIC_VERSION else NULL,
    generated_at = generated_at_utc,
    algorithm = list(
      name = params$algorithm %||% params$cluster_type %||% analysis_type,
      params = params %||% list()
    ),
    library_versions = analysis_generator_library_versions()
  )
}

#' Fail-closed completeness gate for a NEW snapshot's generator provenance.
analysis_snapshot_assert_generator_complete <- function(generator, analysis_type) {
  required <- c("generator_schema_version", "application_version",
                "snapshot_builder_version", "generated_at")
  if (analysis_type %in% .analysis_generator_clustering_types) {
    required <- c(required, "cluster_logic_version")
  }
  for (k in required) {
    v <- generator[[k]]
    if (is.null(v) || length(v) == 0L || is.na(v[[1]]) || !nzchar(as.character(v[[1]]))) {
      stop(sprintf("incomplete snapshot generator provenance: missing '%s' for %s",
                   k, analysis_type), call. = FALSE)
    }
  }
  # application_commit must be present but may legitimately be "unknown" in dev.
  if (is.null(generator$application_commit)) {
    stop("incomplete snapshot generator provenance: missing 'application_commit'", call. = FALSE)
  }
  invisible(TRUE)
}
```

- [ ] **Step 4: Register the new file.** In `api/bootstrap/load_modules.R`, add `"functions/analysis-snapshot-provenance-generator.R"` to the sourced list BEFORE `analysis-snapshot-builder.R`. Mirror in `api/bootstrap/setup_workers.R`'s `everywhere()` source list.

- [ ] **Step 5: Refactor `version_endpoints.R`** to reuse the resolver — replace the inline commit block (lines 22-41) with `commit <- resolve_app_git_commit()`.

- [ ] **Step 6: Run tests.**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-provenance.R')"`
Expected: PASS.

- [ ] **Step 7: Commit.**

```bash
git add api/functions/analysis-snapshot-provenance-generator.R api/endpoints/version_endpoints.R api/bootstrap/load_modules.R api/bootstrap/setup_workers.R api/tests/testthat/test-unit-analysis-snapshot-provenance.R
git commit -m "feat(analysis): generator-provenance helpers + shared commit resolver (#585)"
```

### Task B3: Builder writes generator_json (single UTC timestamp) + gate; repository persists it

**Files:**
- Modify: `api/functions/analysis-snapshot-builder.R` (~495-552)
- Modify: `api/functions/analysis-snapshot-repository.R` (`analysis_snapshot_create_manifest` INSERT)

**Interfaces:**
- Consumes: `analysis_snapshot_build_generator`, `analysis_snapshot_assert_generator_complete` (B2).
- Produces: `analysis_snapshot_create_manifest(list(..., generator = <list>))` writes `generator_json`.

- [ ] **Step 1: Teach the repository INSERT about `generator_json`.** In `analysis_snapshot_create_manifest()` (`analysis-snapshot-repository.R`), add `generator_json` to the column list and one `?` placeholder (after `package_versions_json`), and add `analysis_snapshot_json(manifest$generator)` to the `unname(list(...))` params in the matching position. (The migration placed `generator_json` after `package_versions_json`; keep column order consistent.)

- [ ] **Step 2: In the builder**, capture the timestamp once and build+gate the generator, then pass it into the manifest list. Just before the `write_result <- analysis_snapshot_with_write_transaction(...)` block (`builder.R:~535`), add:

```r
    generated_at_utc <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
    generator_block <- analysis_snapshot_build_generator(
      normalized$analysis_type, normalized$params, generated_at_utc
    )
    analysis_snapshot_assert_generator_complete(generator_block, normalized$analysis_type)
```

Then add `generator = generator_block,` to the `list(...)` passed to `analysis_snapshot_create_manifest()`.

- [ ] **Step 3: Add a builder-level test** that provenance does not change the hashes. In `test-unit-analysis-snapshot-provenance.R` add a pure assertion using the payload-hash helper directly:

```r
test_that("adding a generator key does not change payload_hash or input_hash", {
  payload <- list(kind = "clusters", clusters = list(a = 1), members = list(),
                  raw = list(x = 1), partition_validation = list(v = 1))
  base_hash <- analysis_snapshot_payload_hash(
    payload[setdiff(names(payload), c("raw", "partition_validation", "reproducibility"))])
  payload$generator <- list(application_version = "9.9.9")  # not a hashed key path
  same_hash <- analysis_snapshot_payload_hash(
    payload[setdiff(names(payload), c("raw", "partition_validation", "reproducibility", "generator"))])
  expect_identical(base_hash, same_hash)
})
```

- [ ] **Step 4: Run.**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-provenance.R')"`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add api/functions/analysis-snapshot-builder.R api/functions/analysis-snapshot-repository.R api/tests/testthat/test-unit-analysis-snapshot-provenance.R
git commit -m "feat(analysis): builder persists generator_json outside identity hashes (#585)"
```

### Task B4: Surface generator + generator_hash in meta (pre-046 tolerant)

**Files:**
- Modify: `api/services/analysis-snapshot-service.R` (`service_analysis_snapshot_meta`, add a `generator_hash` helper mirroring `validation_hash`)
- Test: `api/tests/testthat/test-unit-analysis-snapshot-provenance.R` (extend)

**Interfaces:**
- Produces: `meta.snapshot.generator` (object or omitted), `meta.snapshot.generator_hash` (string or `NULL`).

- [ ] **Step 1: Write failing tests** using a fake manifest row (mirror the existing provenance test's fixture):

```r
test_that("meta exposes generator + generator_hash when generator_json present", {
  row <- tibble::tibble(snapshot_id = 1, analysis_type = "functional_clusters",
    parameter_hash = "p", schema_version = "1.2", data_class = "curated_derived_analysis",
    generated_at = "2026-07-19 00:00:00", stale_after = NA, source_data_version = "v1",
    source_versions_json = "{}", input_hash = "i", payload_hash = "h",
    generator_json = '{"application_version":"0.30.6","cluster_logic_version":"x"}')
  meta <- service_analysis_snapshot_meta(list(manifest = row))$snapshot
  expect_equal(meta$generator$application_version, "0.30.6")
  expect_true(nzchar(meta$generator_hash))
})

test_that("pre-046 snapshot (no/empty generator_json) omits generator + null hash", {
  row <- tibble::tibble(snapshot_id = 1, analysis_type = "functional_clusters",
    parameter_hash = "p", schema_version = "1.2", data_class = "x",
    generated_at = "2026-07-19 00:00:00", stale_after = NA, source_data_version = "v1",
    source_versions_json = "{}", input_hash = "i", payload_hash = "h")
  meta <- service_analysis_snapshot_meta(list(manifest = row))$snapshot
  expect_null(meta$generator)
  expect_null(meta$generator_hash)
})
```

- [ ] **Step 2: Run to confirm failure.**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-provenance.R')"`
Expected: FAIL.

- [ ] **Step 3: Add a `generator_hash` helper** in `analysis-snapshot-service.R` (next to `service_analysis_snapshot_validation_hash`):

```r
service_analysis_snapshot_generator_hash <- function(row) {
  raw <- service_analysis_snapshot_column_value(row, "generator_json")
  if (is.null(raw) || length(raw) == 0L || is.na(raw[[1]]) || !nzchar(raw[[1]])) return(NULL)
  service_analysis_snapshot_json_scalar(
    digest::digest(raw[[1]], algo = "sha256", serialize = FALSE))
}
```

- [ ] **Step 4: Add generator to the meta block.** In `service_analysis_snapshot_meta()`'s `snapshot = list(...)`, after `db_release = list(...)`, add:

```r
      generator = {
        g <- service_analysis_snapshot_parse_json_object(
          service_analysis_snapshot_column_value(row, "generator_json"))
        if (length(g) == 0L) NULL else g
      },
      generator_hash = service_analysis_snapshot_generator_hash(row)
```

(`service_analysis_snapshot_parse_json_object` returns an empty list for absent/empty → mapped to `NULL` so the key is omitted, matching pre-046 tolerance.)

- [ ] **Step 5: Run.**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-provenance.R')"`
Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add api/services/analysis-snapshot-service.R api/tests/testthat/test-unit-analysis-snapshot-provenance.R
git commit -m "feat(analysis): surface generator + generator_hash in snapshot meta (#585)"
```

### Task B5: Per-layer generator provenance in the release manifest

**Files:**
- Modify: `api/functions/analysis-snapshot-release.R` (`source.snapshots[]` per-layer)
- Test: `api/tests/testthat/test-integration-analysis-snapshot-release-build.R` or a unit test on the manifest assembly

**Interfaces:**
- Consumes: each pinned snapshot's `meta.snapshot.generator` (B4).
- Produces: `manifest.source.snapshots[i].generator` per layer; packager `generator` unchanged; `content_digest` unchanged.

- [ ] **Step 1: Write a failing test** asserting distinct per-layer generators survive into `source.snapshots[]` and that `content_digest` is unchanged by their presence. Use the existing release-manifest test harness fixture; if only an integration test exists, add a focused unit test on the function that assembles the `source` block, feeding two layers with different `generator.application_commit` values and asserting both appear and `analysis_release_content_digest()` output is identical with/without the generator sub-keys.

- [ ] **Step 2: Run to confirm failure.**

- [ ] **Step 3: Implement.** Where the release builds `source.snapshots[]` (`release.R:~423-432`), include each snapshot's `generator` (read from its `meta.snapshot.generator`, already available where per-snapshot lineage is collected at `release.R:~365-374`). Keep the packager `generator` block (`release.R:~414-422`) untouched. Confirm `analysis_release_content_digest()` (`release-manifest.R:155-172`) still hashes only `{manifest_schema_version, source_data_version, layers[]{analysis_type,input_hash,payload_hash,reproducibility_hash,dependencies}}` — do NOT add generator to the hashed layer projection.

- [ ] **Step 4: Run.**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-release-manifest.R')"`
Expected: PASS (and `content_digest` stable).

- [ ] **Step 5: Commit.**

```bash
git add api/functions/analysis-snapshot-release.R api/tests/testthat/
git commit -m "feat(analysis): record per-layer snapshot generator in release manifest (#585)"
```

### Task B6: Provenance docs (partition / display-filtered / graph-node universe)

**Files:**
- Modify: `documentation/09-deployment.qmd` (provenance + backfill runbook), `AGENTS.md` (Analysis-snapshot section)

- [ ] **Step 1:** Add a subsection documenting the three levels a consumer must distinguish, and the additive-provenance/backfill runbook (worker + worker-maintenance restart before a forced refresh; then force-refresh `phenotype_functional_correlations`). Content:

```
- **Complete partition** — every cluster incl. sub-`min_size`, available from the
  reproducibility bundle (`/api/analysis/*/reproducibility`).
- **Display-filtered communities** — visible clusters (>= `min_size`) materialized
  in the snapshot payload and served by `/api/analysis/*`.
- **Associated graph/node universe** — functional: the STRING largest connected
  component (isolates/fragments excluded from modularity); phenotype: the MCA
  entity set after prevalence-band hygiene.
- **Generator provenance** (`meta.snapshot.generator`, additive): application
  version+commit, `CLUSTER_LOGIC_VERSION`, snapshot-builder version, generated_at,
  algorithm params, library versions. Additive-only; no hash/membership change.
  Optional backfill: restart `worker` AND `worker-maintenance` (builder is
  worker-executed), then force-refresh both cluster presets, then force-refresh
  `phenotype_functional_correlations` (dependency gate).
```

- [ ] **Step 2: Verify docs build gate** if applicable (`make verify-seo-app` is unrelated; docs are qmd — just confirm no broken syntax by eye).

- [ ] **Step 3: Commit.**

```bash
git add documentation/09-deployment.qmd AGENTS.md
git commit -m "docs(analysis): document snapshot provenance + partition/universe levels (#585)"
```

---

## Workstream C — #586 tier-mapping help UI

### Task C1: Typed crosswalk client + mapping_version type

**Files:**
- Modify: `app/src/api/comparisons.ts`
- Test: `app/src/api/comparisons.spec.ts` (extend, optional MSW)

**Interfaces:**
- Produces: `ComparisonsCrosswalk`, `CrosswalkSource`, `CrosswalkRule` types; `getComparisonsCrosswalk(): Promise<ComparisonsCrosswalk>`; `ComparisonsMetadata.mapping_version?: string`.

- [ ] **Step 1: Add the types + client function** in `app/src/api/comparisons.ts` (mirror `getComparisonsSources`):

```ts
export interface CrosswalkRule {
  native_value: string | null;
  native_label: string;
  normalized_tier: 'Definitive' | 'Moderate' | 'Limited' | 'Refuted' | null;
  rule_kind: string;
  note: string | null;
}
export interface CrosswalkSource { list: string; label: string; rules: CrosswalkRule[]; }
export interface CrosswalkTier { tier: string; definition: string; }
export interface ComparisonsCrosswalk {
  mapping_version: string;
  tiers: CrosswalkTier[];
  sources: CrosswalkSource[];
  notes: string[];
}

export async function getComparisonsCrosswalk(): Promise<ComparisonsCrosswalk> {
  const { data } = await api.get<ComparisonsCrosswalk>('/api/comparisons/crosswalk');
  return data;
}
```

Add `mapping_version?: string;` to the `ComparisonsMetadata` interface.

- [ ] **Step 2: Type-check.**

Run: `cd app && npm run type-check`
Expected: PASS.

- [ ] **Step 3: Commit.**

```bash
git add app/src/api/comparisons.ts
git commit -m "feat(app): typed getComparisonsCrosswalk client + mapping_version (#586)"
```

### Task C2: EvidenceTierMappingHelp component (keyboard-accessible, neutral fallback)

**Files:**
- Create: `app/src/components/analyses/EvidenceTierMappingHelp.vue`
- Test: `app/src/components/analyses/EvidenceTierMappingHelp.spec.ts` (new)

**Interfaces:**
- Consumes: `getComparisonsCrosswalk` (C1), `InlineHelpBadge`, `BPopover`.
- Produces: `<EvidenceTierMappingHelp />` (no props).

- [ ] **Step 1: Write the failing spec** mirroring `InlineHelpBadge.spec.ts` + `AnalysesCurationUpset.spec.ts`:

```ts
import { mount, flushPromises } from '@vue/test-utils';
import { describe, it, expect, vi } from 'vitest';
import EvidenceTierMappingHelp from './EvidenceTierMappingHelp.vue';

vi.mock('@/api/comparisons', () => ({
  getComparisonsCrosswalk: vi.fn(() => Promise.resolve({
    mapping_version: '2026-07-19.583-panelapp-ordinal',
    tiers: [{ tier: 'Limited', definition: 'Low evidence.' }],
    sources: [{ list: 'panelapp', label: 'PanelApp', rules: [
      { native_value: '1', native_label: 'Red (1)', normalized_tier: 'Limited', rule_kind: 'exact', note: null }] }],
    notes: ['PanelApp Red/1 normalizes to Limited, never Refuted.'],
  })),
}));

const stubs = { InlineHelpBadge: { template: '<button :aria-label="ariaLabel"><slot/></button>', props: ['ariaLabel','id'] },
  BPopover: { template: '<div class="popover"><slot name="title"/><slot/></div>' } };

describe('EvidenceTierMappingHelp', () => {
  it('exposes an accessible help affordance with no navigational href on the badge', () => {
    const w = mount(EvidenceTierMappingHelp, { global: { stubs } });
    const badge = w.get('button');
    expect(badge.attributes('aria-label')).toMatch(/evidence-tier/i);
    expect(badge.attributes('href')).toBeUndefined();
  });
  it('renders the API-sourced mapping version and a link to the crosswalk', async () => {
    const w = mount(EvidenceTierMappingHelp, { global: { stubs } });
    await flushPromises();
    expect(w.text()).toContain('2026-07-19.583-panelapp-ordinal');
    const link = w.get('a.crosswalk-link');
    expect(link.attributes('href')).toContain('/comparisons/crosswalk');
    expect(link.attributes('rel')).toContain('noopener');
  });
  it('shows a neutral unavailable message and NO tier text on fetch failure', async () => {
    const mod = await import('@/api/comparisons');
    (mod.getComparisonsCrosswalk as any).mockRejectedValueOnce(new Error('down'));
    const w = mount(EvidenceTierMappingHelp, { global: { stubs } });
    await flushPromises();
    expect(w.text()).toMatch(/unavailable/i);
    expect(w.text()).not.toMatch(/Refuted|Limited|Moderate|Definitive/);
  });
});
```

- [ ] **Step 2: Run to confirm failure.**

Run: `cd app && npx vitest run src/components/analyses/EvidenceTierMappingHelp.spec.ts`
Expected: FAIL (component missing).

- [ ] **Step 3: Implement `EvidenceTierMappingHelp.vue`** (Options API, mirrors `CurationSourcesPopover.vue`; click-triggered popover so the internal link is keyboard-reachable; `apiBaseUrl` from the axios plugin):

```vue
<!-- src/components/analyses/EvidenceTierMappingHelp.vue -->
<template>
  <span class="tier-mapping-help">
    <InlineHelpBadge
      id="popover-badge-tier-mapping"
      aria-label="Explain normalized evidence-tier mapping"
    />
    <BPopover
      target="popover-badge-tier-mapping"
      variant="info"
      triggers="click"
    >
      <template #title>Normalized evidence tiers</template>
      <div v-if="crosswalk">
        <p class="mb-1 small">
          Comparisons use a normalized four-tier scale: Definitive, Moderate,
          Limited, Refuted. Each source keeps its native label; analyses use the
          documented mapping.
        </p>
        <p class="mb-1 small"><strong>PanelApp Red/1 &rarr; Limited</strong> (low evidence, not Refuted).</p>
        <p class="mb-1 small text-muted">Ungraded inclusion lists &rarr; implied Definitive for comparability.</p>
        <p class="mb-1 small">Mapping version: <code>{{ crosswalk.mapping_version }}</code></p>
        <a class="crosswalk-link" :href="crosswalkUrl" target="_blank" rel="noopener noreferrer">
          View the complete mapping crosswalk
        </a>
      </div>
      <div v-else-if="failed" class="small text-muted">Mapping information is unavailable.</div>
      <div v-else class="small text-muted">Loading&hellip;</div>
    </BPopover>
  </span>
</template>

<script>
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import { getComparisonsCrosswalk } from '@/api/comparisons';
import { API_URL } from '@/plugins/axios';

export default {
  name: 'EvidenceTierMappingHelp',
  components: { InlineHelpBadge },
  data() { return { crosswalk: null, failed: false }; },
  computed: {
    crosswalkUrl() {
      const base = (API_URL || '').replace(/\/$/, '');
      return `${base}/api/comparisons/crosswalk`;
    },
  },
  async mounted() {
    try { this.crosswalk = await getComparisonsCrosswalk(); }
    catch { this.failed = true; }
  },
};
</script>
```

Note: confirm the exported base-URL symbol in `app/src/plugins/axios.ts` (it may be named `API_URL`, `apiBaseUrl`, or the axios instance's `defaults.baseURL`). If no symbol is exported, use `api.defaults.baseURL` from the shared client. Adjust the import accordingly and keep the test's `href` assertion (`/comparisons/crosswalk`).

- [ ] **Step 4: Run the spec.**

Run: `cd app && npx vitest run src/components/analyses/EvidenceTierMappingHelp.spec.ts`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add app/src/components/analyses/EvidenceTierMappingHelp.vue app/src/components/analyses/EvidenceTierMappingHelp.spec.ts
git commit -m "feat(app): EvidenceTierMappingHelp popover (API-sourced, keyboard-accessible) (#586)"
```

### Task C3: Mount the help after the Overlap label

**Files:**
- Modify: `app/src/components/analyses/AnalysesCurationUpset.vue` (template + component registration)
- Test: `app/src/components/analyses/AnalysesCurationUpset.spec.ts` (extend)

- [ ] **Step 1: Add a failing assertion** to `AnalysesCurationUpset.spec.ts` that the component is present (stub it):

```ts
it('renders the evidence-tier mapping help after the Overlap title', () => {
  const wrapper = mount(AnalysesCurationUpset, { global: { stubs: {
    InlineHelpBadge: true, BPopover: true, EvidenceTierMappingHelp: true,
    DownloadImageButtons: true } } });
  expect(wrapper.findComponent({ name: 'EvidenceTierMappingHelp' }).exists()).toBe(true);
});
```

- [ ] **Step 2: Run to confirm failure.**

Run: `cd app && npx vitest run src/components/analyses/AnalysesCurationUpset.spec.ts`
Expected: FAIL.

- [ ] **Step 3: Wire it in.** In `AnalysesCurationUpset.vue`: import `EvidenceTierMappingHelp`, register it in `components`, and insert `<EvidenceTierMappingHelp />` inside the `<h2 class="panel-title">` immediately after the existing `<InlineHelpBadge ... id="popover-badge-help-upset" />` (after line 13).

- [ ] **Step 4: Run + lint + type-check.**

Run: `cd app && npx vitest run src/components/analyses/AnalysesCurationUpset.spec.ts && npm run lint && npm run type-check`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add app/src/components/analyses/AnalysesCurationUpset.vue app/src/components/analyses/AnalysesCurationUpset.spec.ts
git commit -m "feat(app): mount tier-mapping help after Overlap label on CurationComparisons (#586)"
```

---

## Workstream D — cross-cutting docs

### Task D1: CHANGELOG + AGENTS.md

**Files:**
- Modify: `CHANGELOG.md` (`## [Unreleased]`), `AGENTS.md`

- [ ] **Step 1:** Add an `## [Unreleased]` block (Keep-a-Changelog `### Added`/`### Changed`) describing: PanelApp full-ordinal correction (Amber 2 Limited→Moderate, Red 1 Refuted→Limited), the `mapping_version` on `/metadata`+browse+XLSX and the new `/api/comparisons/crosswalk`, the tier-mapping help affordance, and the additive snapshot `generator` provenance (no hash/`CLUSTER_LOGIC_VERSION` change; migration 046). Explicitly state #583 needs only an **API restart**.

- [ ] **Step 2:** In `AGENTS.md`, under "Curation-comparison sources & refresh", note the PanelApp ordinal + `mapping_version`/`/crosswalk`; under the Analysis-snapshot section, note the additive `generator_json` (migration 046) surfaced at `meta.snapshot.generator` + `generator_hash`, and that it is excluded from `payload_hash` so no `CLUSTER_LOGIC_VERSION` bump / LLM regen.

- [ ] **Step 3: Commit.**

```bash
git add CHANGELOG.md AGENTS.md
git commit -m "docs: changelog + AGENTS notes for mapping policy & snapshot provenance (#583, #585, #586)"
```

---

## Final verification gate (before PR)

- [ ] `make code-quality-audit` — file-size ratchet + audits pass (all new/changed files < 600 lines).
- [ ] `make lint-api` and `make test-api-fast` (or targeted `test_file` for the changed suites): normalization, crosswalk, snapshot-provenance, migration, endpoint-functions.
- [ ] `cd app && npm run lint && npm run type-check && npm run test:unit`.
- [ ] Integration smoke (if dev stack up): `curl /api/comparisons/crosswalk`, `/metadata` (mapping_version present), `/comparisons/browse` meta carries mapping_version; a snapshot read shows `meta.snapshot.generator` after a refresh (optional — provenance is additive).
- [ ] Confirm no `CLUSTER_LOGIC_VERSION` change and no `payload_hash`/`cluster_hash` churn (grep diff).
- [ ] Open ONE PR closing #583, #585, #586 (each on its own `Closes #` line). Do NOT reference #584.

## Spec coverage self-check

- #583 acceptance: mapping distinguishes Red/1 from Refuted (A1) ✓; ClinGen/GenCC disputed/refuted unchanged — G2P asymmetry lock (A1) ✓; API output identifies mapping version — `/metadata` + browse `meta` + XLSX (A3) ✓; release note (D1) ✓.
- #585 acceptance: payload carries immutable revision + CLUSTER_LOGIC_VERSION (B2/B3) ✓; validation rejects incomplete provenance (B2/B3 gate) ✓; docs distinguish partition/communities/universe (B6) ✓; additive-only, no membership/hash change (Global Constraints, B3 test) ✓; serialization + coherence tests (B3/B4) ✓.
- #586 acceptance: affordance after Overlap (C3) ✓; keyboard + SR (C2 InlineHelpBadge button + click popover + interaction test) ✓; concise + links to complete versioned table (C2, crosswalk endpoint) ✓; sourced from same config, no drift (A2 guard + C2 API-sourced) ✓; frontend tests visibility/name/link (C2) ✓; depends on #583 (same PR) ✓.
