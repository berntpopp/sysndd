# Analysis Availability, MCP Snapshots, And LLM Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SysNDD public analysis, MCP analysis, external-provider, job-status, and LLM model-config paths availability-first and bounded.

**Architecture:** Add a MySQL-backed public analysis snapshot layer with scoped public-ready activation, worker-owned refresh jobs, and snapshot-only API/MCP read paths for supported parameter presets. Keep memoise/cachem as worker acceleration only, keep MCP read-only, fast-fail slow external providers, move cluster-summary generation to worker/admin policy, and centralize Gemini model configuration with an operator allowlist escape hatch.

**Tech Stack:** R/Plumber API, MySQL migrations, DBI/RMariaDB, testthat, durable async jobs, Vue 3 + TypeScript, Vite/Vitest, MCP sidecar, Gemini API configuration.

---

## Implementation Notes

- Do not implement on the current dirty workspace without checking `git status --short`.
- Do not reintroduce Redis.
- Do not make MCP write-capable.
- Do not let public API or MCP requests compute STRING networks, phenotype clustering, phenotype correlations, fCoSE layouts, or Gemini summaries on cache miss.
- Snapshot uniqueness is exactly one public-ready row per `(analysis_type, parameter_hash)`.
- Unsupported public/MCP analysis parameters return `unsupported_parameter` or `invalid_input`; they do not return `snapshot_missing`.
- `snapshot_missing` means the requested parameter preset is supported but no public-ready snapshot exists.
- Full `input_hash` mismatch detection happens in worker/admin refresh paths. Public reads use manifest status, parameter hash, `stale_after`, and a cheap stored `source_data_version` when available.
- Snapshot payloads must use approved-public data only: active rows from `ndd_entity_view` and review-derived data from primary approved reviews.

## Files And Responsibilities

Create:

- `db/migrations/024_add_public_analysis_snapshots.sql`
  - Add manifest and normalized snapshot payload tables.
  - Add scoped `public_ready_slot` generated column and unique key on `(analysis_type, parameter_hash, public_ready_slot)`.
- `api/functions/analysis-snapshot-presets.R`
  - Supported parameter matrix, canonicalization, parameter hash, and unsupported-parameter errors.
- `api/functions/analysis-snapshot-repository.R`
  - DB reads/writes, activation, public snapshot lookup, retention, and cheap source-data version helpers.
- `api/functions/analysis-snapshot-builder.R`
  - Worker-side conversion from existing analysis helper outputs into manifest and normalized rows.
- `api/functions/async-job-analysis-snapshot-handlers.R`
  - Durable worker job handler for `analysis_snapshot_refresh`.
- `api/services/analysis-snapshot-service.R`
  - Public/API shaping, problem payloads, snapshot status metadata, and read-time filtering.
- `api/functions/llm-model-config.R`
  - Central Gemini catalog/default/env/config/allowlist validation.
- `api/tests/testthat/test-unit-analysis-snapshot-presets.R`
- `api/tests/testthat/test-unit-analysis-snapshot-migration.R`
- `api/tests/testthat/test-unit-analysis-snapshot-repository.R`
- `api/tests/testthat/test-unit-analysis-snapshot-builder.R`
- `api/tests/testthat/test-endpoint-analysis-snapshot-read.R`
- `api/tests/testthat/test-unit-job-status-result-mode.R`
- `api/tests/testthat/test-mcp-search-ranking.R`
- `api/tests/testthat/test-mcp-snapshot-diagnostics.R`
- `api/tests/testthat/test-unit-external-proxy-budgets.R`
- `api/tests/testthat/test-unit-llm-model-config.R`

Modify:

- `api/bootstrap/load_modules.R`
- `api/functions/migration-manifest.R`
- `api/functions/async-job-handlers.R`
- `api/functions/job-manager.R`
- `api/endpoints/jobs_endpoints.R`
- `api/endpoints/analysis_endpoints.R`
- `api/functions/analysis-network-functions.R`
- `api/functions/mcp-repository.R`
- `api/functions/mcp-analysis-repository.R`
- `api/functions/mcp-analysis-cache-repository.R`
- `api/services/mcp-analysis-service.R`
- `api/services/mcp-query-service.R`
- `api/services/mcp-capabilities-service.R`
- `api/services/mcp-tool-analysis-registry.R`
- `api/scripts/mcp-smoke.R`
- `api/functions/external-proxy-functions.R`
- `api/functions/external-proxy-mgi.R`
- `api/functions/external-proxy-rgd.R`
- `api/endpoints/external_endpoints.R`
- `api/functions/llm-client.R`
- `api/functions/llm-service.R`
- `api/functions/llm-judge.R`
- `api/functions/llm-cache-repository.R`
- `api/endpoints/llm_admin_endpoints.R`
- `api/config.yml.example`
- `app/src/api/analysis.ts`
- `app/src/api/analysis.spec.ts`
- `app/src/composables/useNetworkData.ts`
- `app/src/composables/useNetworkData.spec.ts`
- `app/src/api/llm_admin.ts`
- `app/src/api/llm_admin.spec.ts`
- `app/src/components/llm/LlmConfigPanel.vue`
- `app/src/components/llm/LlmConfigPanel.spec.ts`
- `documentation/08-development.qmd`
- `documentation/09-deployment.qmd`
- `AGENTS.md`

## Commit Strategy

- Commit 1: Snapshot schema, manifest constants, and preset contract.
- Commit 2: Snapshot repository, builder, worker refresh, and retention.
- Commit 3: API snapshot read switch, job result modes, frontend degraded metadata.
- Commit 4: MCP snapshot reads, diagnostics, search ranking, publication type.
- Commit 5: External provider budgets.
- Commit 6: LLM model config hardening and docs.
- Commit 7: Final verification fixes and planning closeout.

---

### Task 1: Snapshot Schema, Migration Manifest, And Parameter Presets

**Files:**
- Create: `db/migrations/024_add_public_analysis_snapshots.sql`
- Create: `api/functions/analysis-snapshot-presets.R`
- Create: `api/tests/testthat/test-unit-analysis-snapshot-migration.R`
- Create: `api/tests/testthat/test-unit-analysis-snapshot-presets.R`
- Modify: `api/functions/migration-manifest.R`
- Modify: `api/bootstrap/load_modules.R`

- [x] **Step 1: Write migration manifest and DDL tests**

Create `api/tests/testthat/test-unit-analysis-snapshot-migration.R`:

```r
test_that("migration manifest expects public analysis snapshot migration", {
  source(file.path("functions", "migration-manifest.R"), local = TRUE)

  expect_equal(EXPECTED_LATEST_MIGRATION, "024_add_public_analysis_snapshots.sql")
  expect_equal(EXPECTED_MIGRATION_COUNT, 25L)
})

test_that("public analysis snapshot migration enforces scoped public-ready uniqueness", {
  migration_path <- file.path("..", "db", "migrations", "024_add_public_analysis_snapshots.sql")
  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")

  expect_match(sql, "analysis_snapshot_manifest", fixed = TRUE)
  expect_match(sql, "public_ready_slot", fixed = TRUE)
  expect_match(sql, "analysis_type", fixed = TRUE)
  expect_match(sql, "parameter_hash", fixed = TRUE)
  expect_match(sql, "UNIQUE KEY `idx_analysis_snapshot_public_ready`", fixed = TRUE)
  expect_match(sql, "`analysis_type`, `parameter_hash`, `public_ready_slot`", fixed = TRUE)
  expect_match(sql, "ON DELETE CASCADE", fixed = TRUE)
})
```

- [x] **Step 2: Write parameter preset tests**

Create `api/tests/testthat/test-unit-analysis-snapshot-presets.R`:

```r
test_that("snapshot presets canonicalize supported parameters", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)

  network <- analysis_snapshot_normalize_params(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = "400", max_edges = "10000")
  )
  expect_equal(network$analysis_type, "gene_network_edges")
  expect_equal(network$params$cluster_type, "clusters")
  expect_equal(network$params$min_confidence, 400L)
  expect_equal(network$params$max_edges, 10000L)
  expect_match(network$parameter_hash, "^[a-f0-9]{64}$")

  functional <- analysis_snapshot_normalize_params(
    "functional_clusters",
    list(algorithm = "leiden")
  )
  expect_equal(functional$params$algorithm, "leiden")
})

test_that("snapshot presets reject unsupported analysis parameters", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)

  expect_error(
    analysis_snapshot_normalize_params("functional_clusters", list(algorithm = "walktrap")),
    class = "analysis_snapshot_unsupported_parameter_error"
  )
  expect_error(
    analysis_snapshot_normalize_params(
      "gene_network_edges",
      list(cluster_type = "clusters", min_confidence = 700, max_edges = 10000)
    ),
    class = "analysis_snapshot_unsupported_parameter_error"
  )
  expect_error(
    analysis_snapshot_normalize_params("unknown_analysis", list()),
    class = "analysis_snapshot_unsupported_parameter_error"
  )
})

test_that("snapshot presets define data_class for every public analysis type", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)

  presets <- analysis_snapshot_supported_presets()
  expect_true(all(vapply(presets, function(x) identical(x$data_class, "curated_derived_analysis"), logical(1))))
  expect_true(all(c(
    "functional_clusters",
    "phenotype_clusters",
    "phenotype_correlations",
    "phenotype_functional_correlations",
    "gene_network_edges"
  ) %in% vapply(presets, `[[`, character(1), "analysis_type")))
})
```

- [x] **Step 3: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-migration.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-presets.R')"
```

Expected:

- Migration test fails because migration `024_add_public_analysis_snapshots.sql` and manifest constants do not exist yet.
- Preset test fails because `analysis-snapshot-presets.R` does not exist yet.

- [x] **Step 4: Add migration DDL**

Create `db/migrations/024_add_public_analysis_snapshots.sql` with this table set:

```sql
-- Migration: 024_add_public_analysis_snapshots
-- Description: Durable public derived-analysis snapshots for API and MCP reads.

CREATE TABLE IF NOT EXISTS `analysis_snapshot_manifest` (
  `snapshot_id` BIGINT NOT NULL AUTO_INCREMENT,
  `analysis_type` VARCHAR(64) NOT NULL,
  `parameter_hash` CHAR(64) NOT NULL,
  `schema_version` VARCHAR(16) NOT NULL,
  `data_class` VARCHAR(64) NOT NULL,
  `status` ENUM('pending','validated','public_ready','superseded','failed') NOT NULL DEFAULT 'pending',
  `public_ready` TINYINT NOT NULL DEFAULT 0,
  `public_ready_slot` TINYINT
      GENERATED ALWAYS AS (CASE WHEN `public_ready` = 1 THEN 1 ELSE NULL END) STORED,
  `generated_by_job_id` CHAR(36) DEFAULT NULL,
  `generated_at` DATETIME(6) DEFAULT NULL,
  `activated_at` DATETIME(6) DEFAULT NULL,
  `superseded_at` DATETIME(6) DEFAULT NULL,
  `stale_after` DATETIME(6) DEFAULT NULL,
  `source_versions_json` JSON DEFAULT NULL,
  `source_data_version` VARCHAR(128) DEFAULT NULL,
  `parameters_json` JSON NOT NULL,
  `input_hash` CHAR(64) NOT NULL,
  `payload_hash` CHAR(64) NOT NULL,
  `algorithm_name` VARCHAR(64) DEFAULT NULL,
  `algorithm_version` VARCHAR(64) DEFAULT NULL,
  `package_versions_json` JSON DEFAULT NULL,
  `row_counts_json` JSON DEFAULT NULL,
  `warnings_json` JSON DEFAULT NULL,
  `last_error_message` TEXT DEFAULT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
      ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`snapshot_id`),
  UNIQUE KEY `idx_analysis_snapshot_public_ready`
      (`analysis_type`, `parameter_hash`, `public_ready_slot`),
  KEY `idx_analysis_snapshot_lookup`
      (`analysis_type`, `parameter_hash`, `public_ready`, `status`),
  KEY `idx_analysis_snapshot_generated_at` (`analysis_type`, `generated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_network_node` (
  `snapshot_id` BIGINT NOT NULL,
  `hgnc_id` VARCHAR(10) NOT NULL,
  `symbol` VARCHAR(50) DEFAULT NULL,
  `cluster_id` VARCHAR(32) DEFAULT NULL,
  `category` VARCHAR(64) DEFAULT NULL,
  `degree` INT DEFAULT NULL,
  `x` DOUBLE DEFAULT NULL,
  `y` DOUBLE DEFAULT NULL,
  `layout_x` DOUBLE DEFAULT NULL,
  `layout_y` DOUBLE DEFAULT NULL,
  `igraph_x` DOUBLE DEFAULT NULL,
  `igraph_y` DOUBLE DEFAULT NULL,
  `display_order` INT DEFAULT NULL,
  PRIMARY KEY (`snapshot_id`, `hgnc_id`),
  KEY `idx_analysis_snapshot_network_node_symbol` (`symbol`),
  CONSTRAINT `fk_analysis_snapshot_network_node_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_network_edge` (
  `snapshot_id` BIGINT NOT NULL,
  `edge_rank` INT NOT NULL,
  `source_hgnc_id` VARCHAR(10) NOT NULL,
  `target_hgnc_id` VARCHAR(10) NOT NULL,
  `confidence` DECIMAL(8,7) NOT NULL,
  PRIMARY KEY (`snapshot_id`, `edge_rank`),
  KEY `idx_analysis_snapshot_network_edge_source` (`snapshot_id`, `source_hgnc_id`),
  KEY `idx_analysis_snapshot_network_edge_target` (`snapshot_id`, `target_hgnc_id`),
  CONSTRAINT `fk_analysis_snapshot_network_edge_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_cluster` (
  `snapshot_id` BIGINT NOT NULL,
  `cluster_kind` VARCHAR(64) NOT NULL,
  `cluster_id` VARCHAR(64) NOT NULL,
  `cluster_hash` CHAR(64) DEFAULT NULL,
  `cluster_size` INT DEFAULT NULL,
  `label` VARCHAR(255) DEFAULT NULL,
  `metadata_json` JSON DEFAULT NULL,
  PRIMARY KEY (`snapshot_id`, `cluster_kind`, `cluster_id`),
  KEY `idx_analysis_snapshot_cluster_hash` (`cluster_hash`),
  CONSTRAINT `fk_analysis_snapshot_cluster_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_cluster_member` (
  `snapshot_id` BIGINT NOT NULL,
  `cluster_kind` VARCHAR(64) NOT NULL,
  `cluster_id` VARCHAR(64) NOT NULL,
  `member_rank` INT NOT NULL,
  `entity_id` INT DEFAULT NULL,
  `hgnc_id` VARCHAR(10) DEFAULT NULL,
  `symbol` VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (`snapshot_id`, `cluster_kind`, `cluster_id`, `member_rank`),
  KEY `idx_analysis_snapshot_cluster_member_gene` (`snapshot_id`, `hgnc_id`),
  KEY `idx_analysis_snapshot_cluster_member_entity` (`snapshot_id`, `entity_id`),
  CONSTRAINT `fk_analysis_snapshot_cluster_member_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_correlation` (
  `snapshot_id` BIGINT NOT NULL,
  `row_rank` INT NOT NULL,
  `correlation_kind` VARCHAR(64) NOT NULL,
  `x_key` VARCHAR(255) NOT NULL,
  `y_key` VARCHAR(255) NOT NULL,
  `value` DECIMAL(8,5) NOT NULL,
  `abs_value` DECIMAL(8,5) NOT NULL,
  `metadata_json` JSON DEFAULT NULL,
  PRIMARY KEY (`snapshot_id`, `row_rank`),
  KEY `idx_analysis_snapshot_correlation_x` (`snapshot_id`, `x_key`),
  KEY `idx_analysis_snapshot_correlation_y` (`snapshot_id`, `y_key`),
  CONSTRAINT `fk_analysis_snapshot_correlation_manifest`
      FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [x] **Step 5: Implement manifest constants and preset helpers**

Modify `api/functions/migration-manifest.R`:

```r
EXPECTED_LATEST_MIGRATION <- "024_add_public_analysis_snapshots.sql"
EXPECTED_MIGRATION_COUNT <- 25L
```

Create `api/functions/analysis-snapshot-presets.R` with these exported functions:

```r
ANALYSIS_SNAPSHOT_SCHEMA_VERSION <- "1.0"

analysis_snapshot_unsupported_parameter <- function(message, fields = list()) {
  rlang::abort(
    message = message,
    class = "analysis_snapshot_unsupported_parameter_error",
    !!!fields
  )
}

analysis_snapshot_supported_presets <- function() {
  list(
    list(analysis_type = "functional_clusters", data_class = "curated_derived_analysis", params = list(algorithm = "leiden")),
    list(analysis_type = "phenotype_clusters", data_class = "curated_derived_analysis", params = list()),
    list(analysis_type = "phenotype_correlations", data_class = "curated_derived_analysis", params = list(filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)")),
    list(analysis_type = "phenotype_functional_correlations", data_class = "curated_derived_analysis", params = list(algorithm = "leiden")),
    list(analysis_type = "gene_network_edges", data_class = "curated_derived_analysis", params = list(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L))
  )
}

analysis_snapshot_canonical_json <- function(value) {
  as.character(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", dataframe = "rows"))
}

analysis_snapshot_parameter_hash <- function(analysis_type, params) {
  digest::digest(
    paste0(analysis_type, ":", analysis_snapshot_canonical_json(params)),
    algo = "sha256",
    serialize = FALSE
  )
}
```

Then implement `analysis_snapshot_normalize_params(analysis_type, params = list())` so it:

- accepts the five analysis types listed above;
- coerces `min_confidence` and `max_edges` to integers;
- accepts only the initial public presets;
- returns `analysis_type`, `data_class`, `params`, `parameters_json`, and `parameter_hash`;
- throws `analysis_snapshot_unsupported_parameter_error` for any unsupported type or parameter combination.

Modify `api/bootstrap/load_modules.R`:

- Add `"functions/analysis-snapshot-presets.R"` after `"functions/async-job-service.R"` and before repository files that will use it.

- [x] **Step 6: Run focused tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-migration.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-presets.R')"
```

Expected:

- Both test files pass.

- [x] **Step 7: Commit Task 1**

Run:

```bash
git add db/migrations/024_add_public_analysis_snapshots.sql \
  api/functions/migration-manifest.R \
  api/bootstrap/load_modules.R \
  api/functions/analysis-snapshot-presets.R \
  api/tests/testthat/test-unit-analysis-snapshot-migration.R \
  api/tests/testthat/test-unit-analysis-snapshot-presets.R
git commit -m "feat: add public analysis snapshot schema"
```

Expected:

- Commit succeeds.

---

### Task 2: Snapshot Repository, Builder, Worker Refresh, And Retention

**Files:**
- Create: `api/functions/analysis-snapshot-repository.R`
- Create: `api/functions/analysis-snapshot-builder.R`
- Create: `api/functions/async-job-analysis-snapshot-handlers.R`
- Create: `api/tests/testthat/test-unit-analysis-snapshot-repository.R`
- Create: `api/tests/testthat/test-unit-analysis-snapshot-builder.R`
- Modify: `api/bootstrap/load_modules.R`
- Modify: `api/functions/async-job-handlers.R`

- [x] **Step 1: Write repository tests first**

Create `api/tests/testthat/test-unit-analysis-snapshot-repository.R`:

```r
test_that("snapshot repository exposes expected public API", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

  expect_true(exists("analysis_snapshot_lock_name", mode = "function"))
  expect_true(exists("analysis_snapshot_get_public", mode = "function"))
  expect_true(exists("analysis_snapshot_create_manifest", mode = "function"))
  expect_true(exists("analysis_snapshot_activate", mode = "function"))
  expect_true(exists("analysis_snapshot_prune", mode = "function"))
})

test_that("snapshot lock names are scoped by analysis type and parameter hash", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

  preset <- analysis_snapshot_normalize_params(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400, max_edges = 10000)
  )
  expect_equal(
    analysis_snapshot_lock_name(preset$analysis_type, preset$parameter_hash),
    paste0("analysis_snapshot_refresh:gene_network_edges:", preset$parameter_hash)
  )
})

test_that("snapshot status helpers classify missing and stale rows", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

  expect_equal(analysis_snapshot_status_code(NULL), "snapshot_missing")
  stale <- list(stale_after = Sys.time() - 60)
  expect_equal(analysis_snapshot_status_code(stale), "snapshot_stale")
  fresh <- list(stale_after = Sys.time() + 60)
  expect_equal(analysis_snapshot_status_code(fresh), "available")
})
```

- [x] **Step 2: Write builder tests first**

Create `api/tests/testthat/test-unit-analysis-snapshot-builder.R`:

```r
test_that("network snapshot builder normalizes nodes and edges", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-builder.R"), local = TRUE)

  network <- list(
    nodes = tibble::tibble(
      hgnc_id = c("HGNC:1", "HGNC:2"),
      symbol = c("A", "B"),
      cluster = c(1, 1),
      category = c("Definitive", "Moderate"),
      degree = c(5L, 4L),
      x = c(10, 20),
      y = c(30, 40)
    ),
    edges = tibble::tibble(source = "HGNC:1", target = "HGNC:2", confidence = 0.9),
    metadata = list(node_count = 2L, edge_count = 1L)
  )

  built <- analysis_snapshot_build_network_rows(network)

  expect_equal(nrow(built$nodes), 2L)
  expect_equal(nrow(built$edges), 1L)
  expect_equal(built$edges$edge_rank, 1L)
  expect_equal(built$row_counts$nodes, 2L)
  expect_equal(built$row_counts$edges, 1L)
})

test_that("correlation snapshot builder supports triangle and diagonal shaping later", {
  source(file.path("functions", "analysis-snapshot-builder.R"), local = TRUE)

  rows <- tibble::tibble(x = c("A", "A", "B"), y = c("A", "B", "B"), value = c(1, 0.5, 1))
  built <- analysis_snapshot_build_correlation_rows(rows, correlation_kind = "phenotype")

  expect_equal(nrow(built$correlations), 3L)
  expect_equal(built$correlations$row_rank, 1:3)
  expect_equal(built$correlations$abs_value, c(1, 0.5, 1))
})
```

- [x] **Step 3: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-repository.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-builder.R')"
```

Expected:

- Repository test fails because `analysis-snapshot-repository.R` does not exist.
- Builder test fails because `analysis-snapshot-builder.R` does not exist.

- [x] **Step 4: Implement repository functions**

Create `api/functions/analysis-snapshot-repository.R` with these functions:

- `analysis_snapshot_lock_name(analysis_type, parameter_hash)`
- `analysis_snapshot_acquire_lock(analysis_type, parameter_hash, timeout_seconds = 30L, conn = NULL)`
- `analysis_snapshot_release_lock(analysis_type, parameter_hash, conn = NULL)`
- `analysis_snapshot_create_manifest(manifest, conn = NULL)`
- `analysis_snapshot_insert_network_rows(snapshot_id, rows, conn = NULL)`
- `analysis_snapshot_insert_cluster_rows(snapshot_id, clusters, members, conn = NULL)`
- `analysis_snapshot_insert_correlation_rows(snapshot_id, correlations, conn = NULL)`
- `analysis_snapshot_activate(snapshot_id, analysis_type, parameter_hash, conn = NULL)`
- `analysis_snapshot_get_public(analysis_type, parameter_hash, conn = NULL)`
- `analysis_snapshot_status_code(row)`
- `analysis_snapshot_source_data_version(conn = NULL)`
- `analysis_snapshot_prune(analysis_type, parameter_hash, keep_public_ready = 3L, keep_superseded_days = 14L, conn = NULL)`

Implementation constraints:

- Use `db_execute_query()` and `db_execute_statement()` with unnamed parameter lists.
- `analysis_snapshot_activate()` runs in a DB transaction.
- Activation first supersedes old public-ready rows for the same `(analysis_type, parameter_hash)`, then sets the target row to `public_ready = 1`, `status = 'public_ready'`, and `activated_at = NOW(6)`.
- The unique key catches activation races.
- `analysis_snapshot_status_code(NULL)` returns `snapshot_missing`.
- A row with `stale_after < Sys.time()` returns `snapshot_stale`.
- A row whose stored `source_data_version` differs from a supplied current version returns `source_version_mismatch`.

- [x] **Step 5: Implement builder functions**

Create `api/functions/analysis-snapshot-builder.R` with these functions:

- `analysis_snapshot_payload_hash(payload)`
- `analysis_snapshot_input_hash(inputs)`
- `analysis_snapshot_build_network_rows(network)`
- `analysis_snapshot_build_cluster_rows(clusters, cluster_kind)`
- `analysis_snapshot_build_correlation_rows(rows, correlation_kind)`
- `analysis_snapshot_build_payload(analysis_type, params)`
- `analysis_snapshot_refresh(analysis_type, params, job_id = NULL, conn = NULL)`

Implementation constraints:

- `analysis_snapshot_build_payload()` calls existing deterministic helpers only inside worker/admin refresh:
  - `functional_clusters`: `gen_string_clust_obj_mem()` for Leiden and approved NDD genes.
  - `phenotype_clusters`: `generate_phenotype_clusters()`.
  - `phenotype_correlations`: `generate_phenotype_correlations_mem(filter = default, min_abs_correlation = NULL)`.
  - `phenotype_functional_correlations`: `generate_phenotype_functional_cluster_correlation()`.
  - `gene_network_edges`: `generate_network_edges_response(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L)`.
- Builders return normalized tibbles and `row_counts`.
- Builders preserve existing cluster hashes when the source payload has `hash_filter`.
- Builders include only approved-public inputs by using the existing analysis helpers that already filter primary approved reviews, or by adding that filter before snapshot insert where the helper output is incomplete.

- [x] **Step 6: Add worker handler and registry entry**

Create `api/functions/async-job-analysis-snapshot-handlers.R`:

```r
.async_job_run_analysis_snapshot_refresh <- function(job, payload, state, worker_config) {
  analysis_type <- as.character(payload$analysis_type[[1]] %||% payload$analysis_type)
  params <- payload$params %||% list()
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 2)

  progress("snapshot_start", paste("Refreshing analysis snapshot", analysis_type), current = 0, total = 3)
  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
  progress("snapshot_build", paste("Building analysis snapshot", analysis_type), current = 1, total = 3)
  result <- analysis_snapshot_refresh(
    analysis_type = normalized$analysis_type,
    params = normalized$params,
    job_id = job$job_id[[1]]
  )
  progress("snapshot_complete", paste("Analysis snapshot refreshed", analysis_type), current = 3, total = 3)

  result
}
```

Modify `api/functions/async-job-handlers.R`:

- Source `functions/async-job-analysis-snapshot-handlers.R` through `bootstrap_load_modules()`, not by ad hoc `source()` inside the registry.
- Add registry entry:

```r
analysis_snapshot_refresh = list(
  cancel_mode = "best_effort",
  run = function(...) .async_job_run_analysis_snapshot_refresh(...),
  after_success = .async_job_after_success_noop
)
```

Modify `api/bootstrap/load_modules.R`:

- Add new function files in this order after `analysis-snapshot-presets.R`:
  - `functions/analysis-snapshot-repository.R`
  - `functions/analysis-snapshot-builder.R`
  - `functions/async-job-analysis-snapshot-handlers.R`

- [x] **Step 7: Run focused tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-repository.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-builder.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-nddscore-job.R')"
```

Expected:

- Snapshot repository and builder tests pass.
- Existing NDDScore active-slot tests still pass.

- [x] **Step 8: Commit Task 2**

Run:

```bash
git add api/functions/analysis-snapshot-repository.R \
  api/functions/analysis-snapshot-builder.R \
  api/functions/async-job-analysis-snapshot-handlers.R \
  api/functions/async-job-handlers.R \
  api/bootstrap/load_modules.R \
  api/tests/testthat/test-unit-analysis-snapshot-repository.R \
  api/tests/testthat/test-unit-analysis-snapshot-builder.R
git commit -m "feat: add analysis snapshot refresh pipeline"
```

Expected:

- Commit succeeds.

---

### Task 3: API Snapshot Reads, Job Result Modes, And Frontend Degraded Metadata

**Files:**
- Create: `api/services/analysis-snapshot-service.R`
- Create: `api/tests/testthat/test-endpoint-analysis-snapshot-read.R`
- Create: `api/tests/testthat/test-unit-job-status-result-mode.R`
- Modify: `api/bootstrap/load_modules.R`
- Modify: `api/functions/job-manager.R`
- Modify: `api/endpoints/jobs_endpoints.R`
- Modify: `api/endpoints/analysis_endpoints.R`
- Modify: `app/src/api/analysis.ts`
- Modify: `app/src/api/analysis.spec.ts`
- Modify: `app/src/composables/useNetworkData.ts`
- Modify: `app/src/composables/useNetworkData.spec.ts`

- [ ] **Step 1: Write API snapshot read tests first**

Create `api/tests/testthat/test-endpoint-analysis-snapshot-read.R`:

```r
test_that("analysis snapshot service returns unsupported_parameter before compute", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  result <- analysis_snapshot_service_read(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 700, max_edges = 10000),
    repo_get_public = function(...) stop("repo should not be called")
  )

  expect_equal(result$status, 400L)
  expect_equal(result$body$code, "unsupported_parameter")
})

test_that("analysis snapshot service returns snapshot_missing for supported missing preset", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  result <- analysis_snapshot_service_read(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400, max_edges = 10000),
    repo_get_public = function(...) NULL
  )

  expect_equal(result$status, 503L)
  expect_equal(result$body$code, "snapshot_missing")
})
```

- [ ] **Step 2: Write job result mode tests first**

Create `api/tests/testthat/test-unit-job-status-result-mode.R`:

```r
test_that("get_job_status defaults to summary without result_json", {
  env <- new.env(parent = globalenv())
  sys.source(file.path("functions", "job-manager.R"), envir = env)

  captured_include_result <- NULL
  env$async_job_service_status <- function(job_id, include_result = FALSE) {
    captured_include_result <<- include_result
    tibble::tibble(
      job_id = job_id,
      job_type = "clustering",
      status = "completed",
      submitted_at = Sys.time(),
      completed_at = Sys.time(),
      progress_pct = 100,
      progress_message = "done",
      last_error_code = NA_character_,
      last_error_message = NA_character_
    )
  }

  result <- env$get_job_status("job-1")
  expect_false(captured_include_result)
  expect_equal(result$status, "completed")
  expect_null(result$result)
})

test_that("get_job_status includes result only for full result mode", {
  env <- new.env(parent = globalenv())
  sys.source(file.path("functions", "job-manager.R"), envir = env)

  captured_include_result <- NULL
  env$async_job_service_status <- function(job_id, include_result = FALSE) {
    captured_include_result <<- include_result
    tibble::tibble(
      job_id = job_id,
      job_type = "clustering",
      status = "completed",
      submitted_at = Sys.time(),
      completed_at = Sys.time(),
      progress_pct = 100,
      progress_message = "done",
      result_json = '{"meta":{"cluster_count":2}}',
      last_error_code = NA_character_,
      last_error_message = NA_character_
    )
  }

  result <- env$get_job_status("job-1", result_mode = "full")
  expect_true(captured_include_result)
  expect_equal(result$result$meta$cluster_count, 2)
})
```

- [ ] **Step 3: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-analysis-snapshot-read.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-status-result-mode.R')"
```

Expected:

- Snapshot service test fails because `analysis-snapshot-service.R` does not exist.
- Job result mode test fails because `get_job_status()` has no `result_mode` argument and always requests result JSON.

- [ ] **Step 4: Implement snapshot service**

Create `api/services/analysis-snapshot-service.R` with:

- `analysis_snapshot_problem(code, message, status, analysis_type, retry_after = NULL)`
- `analysis_snapshot_service_read(analysis_type, params, repo_get_public = analysis_snapshot_get_public)`
- `analysis_snapshot_shape_functional(snapshot)`
- `analysis_snapshot_shape_phenotype_clusters(snapshot)`
- `analysis_snapshot_shape_correlations(snapshot, min_abs_correlation = NULL, drop_diagonal = TRUE, triangle_only = FALSE)`
- `analysis_snapshot_shape_network(snapshot, max_edges = 10000L)`

Implementation constraints:

- Call `analysis_snapshot_normalize_params()` before repository lookup.
- On unsupported preset, return HTTP 400 body with `code = "unsupported_parameter"`.
- On missing supported preset, return HTTP 503 body with `code = "snapshot_missing"` and `Retry-After = 60`.
- Public read functions never call `gen_string_clust_obj_mem()`, `generate_phenotype_clusters()`, `generate_phenotype_correlations_mem()`, `generate_phenotype_functional_cluster_correlation()`, or `generate_network_edges_response()`.
- Response metadata includes:

```r
meta = list(
  snapshot = list(
    snapshot_id = snapshot_id,
    analysis_type = analysis_type,
    parameter_hash = parameter_hash,
    schema_version = schema_version,
    data_class = data_class,
    generated_at = generated_at,
    stale_after = stale_after,
    source_data_version = source_data_version
  )
)
```

Modify `api/bootstrap/load_modules.R`:

- Add `"services/analysis-snapshot-service.R"` before MCP services that may call it.

- [ ] **Step 5: Switch public analysis endpoints to snapshot service**

Modify `api/endpoints/analysis_endpoints.R`:

- `functional_clustering` calls `analysis_snapshot_service_read("functional_clusters", list(algorithm = algorithm_clean))`.
- `phenotype_clustering` calls `analysis_snapshot_service_read("phenotype_clusters", list())`.
- `phenotype_functional_cluster_correlation` calls `analysis_snapshot_service_read("phenotype_functional_correlations", list())`.
- `network_edges` calls `analysis_snapshot_service_read("gene_network_edges", list(cluster_type = cluster_type_clean, min_confidence = min_confidence_int, max_edges = max_edges_int))`.
- If the service result has `status >= 400`, set `res$status`, `Retry-After` when present, and return the problem body.
- Otherwise return the shaped body.

Keep the existing heavy helper functions available for worker/admin refresh; do not delete them.

- [ ] **Step 6: Implement job result modes and remove public cache-hit LLM chaining**

Modify `api/functions/job-manager.R`:

- Change signature to `get_job_status <- function(job_id, result_mode = "summary")`.
- Validate `result_mode` in `c("summary", "full")`.
- Call `async_job_service_status(job_id, include_result = identical(result_mode, "full"))`.
- For completed summary mode, return `result = NULL` and include `result_mode = "summary"`.
- For completed full mode, preserve existing full result behavior.

Modify job status endpoint in `api/endpoints/jobs_endpoints.R`:

- Parse query/body `result_mode`, default to `"summary"`.
- Pass it to `get_job_status(job_id, result_mode = result_mode)`.

Modify clustering and phenotype clustering cache-hit branches in `api/endpoints/jobs_endpoints.R`:

- Remove direct `trigger_llm_batch_generation()` calls from public cache-hit branches.
- Add response field `llm_generation = "snapshot_refresh_owned"` in the accepted response metadata if a field is needed for clients.
- Do not remove worker `after_success` chaining for actual queued clustering jobs in this task.

- [ ] **Step 7: Update frontend analysis types and degraded network handling**

Modify `app/src/api/analysis.ts`:

- Add:

```ts
export interface AnalysisSnapshotMeta {
  snapshot_id?: number;
  analysis_type?: string;
  parameter_hash?: string;
  schema_version?: string;
  data_class?: string;
  generated_at?: string;
  stale_after?: string;
  source_data_version?: string;
}
```

- Add `snapshot?: AnalysisSnapshotMeta` to `ClusteringMeta` and `NetworkMetadata`.

Modify `app/src/composables/useNetworkData.ts`:

- Keep existing error handling.
- When a snapshot problem response is thrown by `apiClient`, preserve the problem `code` in the `Error.message` if the client exposes it.
- Do not retry unsupported parameters automatically.

Modify tests in `app/src/api/analysis.spec.ts` and `app/src/composables/useNetworkData.spec.ts`:

- Assert `metadata.snapshot.analysis_type` is accepted on network responses.
- Assert a rejected snapshot problem sets `error.value` and leaves `networkData.value` null.

- [ ] **Step 8: Run focused tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-analysis-snapshot-read.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-status-result-mode.R')"
cd app && npx vitest run src/api/analysis.spec.ts src/composables/useNetworkData.spec.ts
```

Expected:

- API focused tests pass.
- Vitest specs pass.

- [ ] **Step 9: Commit Task 3**

Run:

```bash
git add api/services/analysis-snapshot-service.R \
  api/bootstrap/load_modules.R \
  api/functions/job-manager.R \
  api/endpoints/jobs_endpoints.R \
  api/endpoints/analysis_endpoints.R \
  api/tests/testthat/test-endpoint-analysis-snapshot-read.R \
  api/tests/testthat/test-unit-job-status-result-mode.R \
  app/src/api/analysis.ts \
  app/src/api/analysis.spec.ts \
  app/src/composables/useNetworkData.ts \
  app/src/composables/useNetworkData.spec.ts
git commit -m "feat: serve public analysis from snapshots"
```

Expected:

- Commit succeeds.

---

### Task 4: MCP Snapshot Reads, Search Ranking, Publication Type, And Smoke Coverage

**Files:**
- Create: `api/tests/testthat/test-mcp-search-ranking.R`
- Create: `api/tests/testthat/test-mcp-snapshot-diagnostics.R`
- Modify: `api/functions/mcp-repository.R`
- Modify: `api/functions/mcp-analysis-repository.R`
- Modify: `api/functions/mcp-analysis-cache-repository.R`
- Modify: `api/services/mcp-query-service.R`
- Modify: `api/services/mcp-analysis-service.R`
- Modify: `api/services/mcp-capabilities-service.R`
- Modify: `api/services/mcp-tool-analysis-registry.R`
- Modify: `api/scripts/mcp-smoke.R`

- [ ] **Step 1: Write MCP search tests first**

Create `api/tests/testthat/test-mcp-search-ranking.R`:

```r
test_that("MCP search token scoring ranks aliases and phrase token matches", {
  source(file.path("services", "mcp-service.R"), local = TRUE)
  source(file.path("functions", "mcp-repository.R"), local = TRUE)
  source(file.path("services", "mcp-query-service.R"), local = TRUE)

  expect_equal(mcp_search_tokens("NMDA receptor"), c("NMDA", "RECEPTOR"))

  candidates <- tibble::tibble(
    type = c("gene", "gene"),
    id = c("GRIN2A", "GENE2"),
    label = c("GRIN2A", "GENE2"),
    description = c("glutamate ionotropic receptor NMDA type subunit 2A", "unrelated"),
    matched_field = c("name", "symbol"),
    match_tier = c("token_overlap", "contains"),
    token_matches = c(2L, 0L)
  )

  ranked <- mcp_rank_search_candidates(candidates)
  expect_equal(ranked$id[[1]], "GRIN2A")
})

test_that("MCP search zero-result response includes diagnostics", {
  source(file.path("services", "mcp-service.R"), local = TRUE)
  source(file.path("services", "mcp-query-service.R"), local = TRUE)

  old_repo <- get0("mcp_repo_search", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_repo_search", function(query, types, limit) tibble::tibble(), envir = .GlobalEnv)
  on.exit({
    if (is.null(old_repo)) rm("mcp_repo_search", envir = .GlobalEnv) else assign("mcp_repo_search", old_repo, envir = .GlobalEnv)
  }, add = TRUE)

  result <- mcp_search_sysndd("epilepsy aphasia", types = c("gene", "disease"), limit = 10)
  expect_equal(result$meta$returned, 0L)
  expect_equal(result$meta$query_tokens, c("EPILEPSY", "APHASIA"))
  expect_true(length(result$meta$searched_types) > 0)
})
```

- [ ] **Step 2: Write MCP snapshot diagnostics tests first**

Create `api/tests/testthat/test-mcp-snapshot-diagnostics.R`:

```r
test_that("MCP gene network reports unsupported parameters before lookup", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "mcp-service.R"), local = TRUE)
  source(file.path("services", "mcp-analysis-shaping.R"), local = TRUE)
  source(file.path("services", "mcp-analysis-service.R"), local = TRUE)

  expect_error(
    mcp_get_gene_network_context(cluster_type = "clusters", min_confidence = 700, max_edges = 100),
    class = "mcp_tool_error"
  )
})

test_that("MCP phenotype correlations reject gene in global mode", {
  source(file.path("services", "mcp-service.R"), local = TRUE)
  source(file.path("services", "mcp-analysis-shaping.R"), local = TRUE)
  source(file.path("services", "mcp-analysis-service.R"), local = TRUE)

  expect_error(
    mcp_get_phenotype_analysis_context(mode = "correlations", gene = "GRIN2A"),
    class = "mcp_tool_error"
  )
})
```

- [ ] **Step 3: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-search-ranking.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-snapshot-diagnostics.R')"
```

Expected:

- Search ranking test fails because token/scoring helpers are missing.
- Snapshot diagnostics test fails because MCP still uses cache repository behavior and does not expose `unsupported_parameter`.

- [ ] **Step 4: Implement deterministic MCP token search**

Modify `api/functions/mcp-repository.R`:

- Add `mcp_search_tokens(query)`:
  - uppercase;
  - split on non-alphanumeric characters;
  - drop empty tokens;
  - drop one-character tokens except numeric identifiers;
  - cap at 6 tokens.
- Add `mcp_rank_search_candidates(rows)`:
  - exact identifier score 1000;
  - exact label score 900;
  - alias/previous symbol score 850;
  - phrase match score 750;
  - prefix score 650;
  - token overlap score `400 + 25 * token_matches`;
  - contains score 250.
- Replace narrow gene query with bounded candidate SQL against `non_alt_loci_set` plus `hgnc_symbol_lookup`.
- Do not modify `db/C_Rcommands_set-table-connections.R`.
- Keep phenotype and variant search branches, but include them in default MCP search through the existing `MCP_ALLOWED_SEARCH_TYPES`.
- Add phenotype synonym matching through `phenotype_list.HPO_term_synonyms` if the column exists in the current schema; guard with `dbListFields()` or a repository helper so tests can run against older fixtures.

Modify `api/services/mcp-query-service.R`:

- Include `query_tokens`, `searched_types`, and `zero_result_guidance` in `meta`.
- Use `score` from repository ranking when present.
- Preserve `limit` max 25.

- [ ] **Step 5: Switch MCP analysis to snapshot-backed reads**

Modify `api/functions/mcp-analysis-repository.R`:

- Add snapshot-backed read helpers:
  - `mcp_analysis_repo_get_public_snapshot(analysis_type, params)`
  - `mcp_analysis_repo_get_snapshot_network(gene = NULL, max_edges = 100L)`
  - `mcp_analysis_repo_get_snapshot_phenotype_correlations(phenotype = NULL, min_abs_correlation = 0.3, drop_diagonal = TRUE, triangle_only = FALSE, limit = 25L)`
  - `mcp_analysis_repo_get_snapshot_phenotype_clusters(gene = NULL, cluster_id = NULL, limit = 25L)`
  - `mcp_analysis_repo_get_snapshot_phenotype_functional_correlations(gene = NULL, limit = 25L)`
- Use `analysis_snapshot_get_public()` and normalized preset functions.
- Keep old memoise/disk-cache functions available only as tests migrate; do not call disk RDS scans from MCP service after this task.

Modify `api/functions/mcp-analysis-cache-repository.R`:

- Mark disk-scan helpers as legacy.
- Ensure MCP service no longer calls `mcp_analysis_repo_find_disk_payload()` in normal paths.

Modify `api/services/mcp-analysis-service.R`:

- In `mcp_get_gene_network_context()`, normalize only supported snapshot key `cluster_type = "clusters"`, `min_confidence = 400`, stored `max_edges = 10000`.
- Treat MCP `max_edges` as response trim cap.
- On unsupported key, throw `mcp_error("unsupported_parameter", ...)`.
- On missing snapshot, throw `mcp_error("snapshot_missing", ...)`.
- In phenotype correlations, reject non-empty `gene` with `invalid_input`.
- Add `drop_diagonal` and `triangle_only` arguments and pass them to repository shaping.

Modify `api/services/mcp-tool-analysis-registry.R`:

- Add `drop_diagonal` and `triangle_only` input schema fields.
- Update descriptions to say analysis tools read public-ready snapshots only.

Modify `api/services/mcp-capabilities-service.R`:

- Replace "cache-only analysis" text with "public-ready snapshot-only analysis".
- Preserve MCP read-only/no-LLM/no-external-provider language.

- [ ] **Step 6: Add publication type semantics**

Modify `api/functions/mcp-repository.R`:

- In `mcp_repo_get_publication_context()`, select `rpj.publication_type`.
- Keep it on each linked entity/publication row.

Modify publication shaping in `api/services/mcp-record-service.R` if needed:

- Include per-link `publication_type`.
- If adding an envelope field, call it `publication_types` and make it a deduped array.

- [ ] **Step 7: Extend MCP smoke**

Modify `api/scripts/mcp-smoke.R`:

- Add a search call for `NMDA receptor`.
- Add a search call for `epilepsy aphasia`.
- Add a diagnostics/dry-run call for gene network context that accepts snapshot missing or available but rejects unsupported parameters.
- Add publication context assertion that linked publication rows include `publication_type` when links exist.
- Add phenotype correlation call with `drop_diagonal = TRUE` and `triangle_only = TRUE`.

- [ ] **Step 8: Run focused MCP tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-search-ranking.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-snapshot-diagnostics.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-service.R')"
```

Expected:

- All focused MCP tests pass.

- [ ] **Step 9: Commit Task 4**

Run:

```bash
git add api/functions/mcp-repository.R \
  api/functions/mcp-analysis-repository.R \
  api/functions/mcp-analysis-cache-repository.R \
  api/services/mcp-query-service.R \
  api/services/mcp-analysis-service.R \
  api/services/mcp-capabilities-service.R \
  api/services/mcp-tool-analysis-registry.R \
  api/scripts/mcp-smoke.R \
  api/tests/testthat/test-mcp-search-ranking.R \
  api/tests/testthat/test-mcp-snapshot-diagnostics.R \
  api/tests/testthat/test-mcp-analysis-service.R \
  api/tests/testthat/test-mcp-service.R
git commit -m "feat: serve MCP analysis from public snapshots"
```

Expected:

- Commit succeeds.

---

### Task 5: External Provider Budgets And Timing Diagnostics

**Files:**
- Create: `api/tests/testthat/test-unit-external-proxy-budgets.R`
- Modify: `api/functions/external-proxy-functions.R`
- Modify: `api/functions/external-proxy-mgi.R`
- Modify: `api/functions/external-proxy-rgd.R`
- Modify: `api/endpoints/external_endpoints.R`

- [ ] **Step 1: Write budget tests first**

Create `api/tests/testthat/test-unit-external-proxy-budgets.R`:

```r
test_that("external proxy budgets are short and source-specific", {
  source(file.path("functions", "external-proxy-functions.R"), local = TRUE)

  mgi <- external_proxy_budget("mgi")
  gnomad <- external_proxy_budget("gnomad")

  expect_lte(mgi$timeout_seconds, 8)
  expect_lte(mgi$max_seconds, 12)
  expect_lte(gnomad$timeout_seconds, 8)
  expect_true(mgi$max_tries >= 1L)
})

test_that("external proxy timing wrapper preserves result and records elapsed metadata", {
  source(file.path("functions", "external-proxy-functions.R"), local = TRUE)

  result <- external_proxy_with_timing("mgi", function() list(source = "mgi", found = FALSE))

  expect_false(isTRUE(result$error))
  expect_equal(result$source, "mgi")
  expect_true(is.numeric(result$elapsed_ms))
})
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-proxy-budgets.R')"
```

Expected:

- Test fails because `external_proxy_budget()` and `external_proxy_with_timing()` do not exist.

- [ ] **Step 3: Implement budget helpers**

Modify `api/functions/external-proxy-functions.R`:

- Add `external_proxy_budget(api_name)` returning:

```r
list(
  timeout_seconds = as.numeric(Sys.getenv(paste0("EXTERNAL_PROXY_", toupper(api_name), "_TIMEOUT_SECONDS"), Sys.getenv("EXTERNAL_PROXY_TIMEOUT_SECONDS", "6"))),
  max_seconds = as.numeric(Sys.getenv(paste0("EXTERNAL_PROXY_", toupper(api_name), "_MAX_SECONDS"), Sys.getenv("EXTERNAL_PROXY_MAX_SECONDS", "10"))),
  max_tries = as.integer(Sys.getenv(paste0("EXTERNAL_PROXY_", toupper(api_name), "_MAX_TRIES"), Sys.getenv("EXTERNAL_PROXY_MAX_TRIES", "2")))
)
```

- Add `external_proxy_with_timing(source, expr_fn)`:
  - records elapsed milliseconds;
  - adds `elapsed_ms` to list results;
  - logs `[external-proxy] source=<source> event=complete status=<status> elapsed_ms=<ms> cache=<unknown>`;
  - catches errors into `list(error = TRUE, status = 503L, source = source, message = conditionMessage(e), elapsed_ms = elapsed)`.
- Change `make_external_request()` to use `external_proxy_budget(api_name)` by default.
- Replace hardcoded `max_tries = 5`, `max_seconds = 120`, and `req_timeout(30)`.

- [ ] **Step 4: Move MGI/RGD direct calls onto budgets**

Modify `api/functions/external-proxy-mgi.R`:

- Use `budget <- external_proxy_budget("mgi")`.
- Apply `req_retry(max_tries = budget$max_tries, max_seconds = budget$max_seconds, ...)`.
- Apply `req_timeout(budget$timeout_seconds)`.
- Wrap top-level fetch in `external_proxy_with_timing("mgi", function() { ... })`.

Modify `api/functions/external-proxy-rgd.R` the same way with `"rgd"`.

- [ ] **Step 5: Scope aggregate endpoint**

Modify `api/endpoints/external_endpoints.R`:

- Keep the aggregate route for compatibility.
- Add a short aggregate budget using `Sys.getenv("EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS", "12")`.
- Stop iterating once elapsed time exceeds the aggregate budget.
- Return `partial = TRUE` and `skipped_sources` when the budget stops later sources.
- Do not introduce parallel fanout.

- [ ] **Step 6: Run focused tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-proxy-budgets.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-external-proxy-endpoints.R')"
```

Expected:

- Budget tests pass.
- Existing external endpoint tests pass.

- [ ] **Step 7: Commit Task 5**

Run:

```bash
git add api/functions/external-proxy-functions.R \
  api/functions/external-proxy-mgi.R \
  api/functions/external-proxy-rgd.R \
  api/endpoints/external_endpoints.R \
  api/tests/testthat/test-unit-external-proxy-budgets.R \
  api/tests/testthat/test-external-proxy-endpoints.R
git commit -m "fix: bound external provider request budgets"
```

Expected:

- Commit succeeds.

---

### Task 6: LLM Model Config Hardening

**Files:**
- Create: `api/functions/llm-model-config.R`
- Create: `api/tests/testthat/test-unit-llm-model-config.R`
- Modify: `api/bootstrap/load_modules.R`
- Modify: `api/functions/llm-client.R`
- Modify: `api/functions/llm-service.R`
- Modify: `api/functions/llm-judge.R`
- Modify: `api/functions/llm-cache-repository.R`
- Modify: `api/endpoints/llm_admin_endpoints.R`
- Modify: `api/tests/testthat/test-unit-llm-client-config.R`
- Modify: `api/tests/testthat/test-unit-llm-endpoint-helpers.R`
- Modify: `api/config.yml.example`
- Modify: `app/src/api/llm_admin.ts`
- Modify: `app/src/api/llm_admin.spec.ts`
- Modify: `app/src/components/llm/LlmConfigPanel.vue`
- Modify: `app/src/components/llm/LlmConfigPanel.spec.ts`
- Modify: `documentation/08-development.qmd`
- Modify: `documentation/09-deployment.qmd`

- [ ] **Step 1: Write model config tests first**

Create `api/tests/testthat/test-unit-llm-model-config.R`:

```r
test_that("Gemini model config resolves stable default", {
  source(file.path("functions", "llm-model-config.R"), local = TRUE)

  withr::local_envvar(GEMINI_MODEL = NA, GEMINI_ALLOWED_MODELS_EXTRA = NA)
  resolved <- llm_model_config_resolve(config = list())

  expect_equal(resolved$model, "gemini-3.5-flash")
  expect_equal(resolved$source, "default")
  expect_true(resolved$valid)
})

test_that("Gemini model config rejects unknown models unless operator allowlisted", {
  source(file.path("functions", "llm-model-config.R"), local = TRUE)

  withr::local_envvar(GEMINI_MODEL = "gemini-new-release", GEMINI_ALLOWED_MODELS_EXTRA = NA)
  rejected <- llm_model_config_resolve(config = list())
  expect_false(rejected$valid)
  expect_equal(rejected$error_code, "llm_model_invalid")

  withr::local_envvar(GEMINI_MODEL = "gemini-new-release", GEMINI_ALLOWED_MODELS_EXTRA = "gemini-new-release")
  allowed <- llm_model_config_resolve(config = list())
  expect_true(allowed$valid)
  expect_true(allowed$operator_allowed)
  expect_match(allowed$warning, "operator", ignore.case = TRUE)
})

test_that("Gemini model catalog marks shut-down preview model invalid", {
  source(file.path("functions", "llm-model-config.R"), local = TRUE)

  meta <- llm_model_metadata("gemini-3-pro-preview")
  expect_false(meta$allowed)
  expect_equal(meta$status, "shutdown")
})
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-llm-model-config.R')"
```

Expected:

- Test fails because `llm-model-config.R` does not exist.

- [ ] **Step 3: Implement central model config helper**

Create `api/functions/llm-model-config.R` with:

- `LLM_DEFAULT_GEMINI_MODEL <- "gemini-3.5-flash"`
- `llm_model_catalog()`
- `llm_model_metadata(model)`
- `llm_model_extra_allowlist()`
- `llm_model_config_resolve(config = NULL)`
- `llm_model_config_validate(model, config = NULL)`
- `get_default_gemini_model(config = NULL)`
- `list_gemini_models(include_preview = TRUE, include_operator_allowed = TRUE)`
- `get_gemini_model_metadata(model)`

Catalog entries:

- `gemini-3.5-flash`: `status = "stable"`, `allowed = TRUE`, `default = TRUE`.
- `gemini-3.1-pro-preview`: `status = "preview"`, `allowed = TRUE`, `default = FALSE`.
- `gemini-3.1-flash-lite`: `status = "stable"`, `allowed = TRUE`, `default = FALSE`.
- `gemini-2.5-flash`: `status = "stable"`, `allowed = TRUE`, `default = FALSE`.
- `gemini-2.5-pro`: `status = "stable"`, `allowed = TRUE`, `default = FALSE`.
- `gemini-2.5-flash-lite`: `status = "stable"`, `allowed = TRUE`, `default = FALSE`.
- `gemini-3-pro-preview`: `status = "shutdown"`, `allowed = FALSE`, `shutdown_date = "2026-03-09"`.

Resolution order:

1. `GEMINI_MODEL`
2. config key `gemini_model`
3. `LLM_DEFAULT_GEMINI_MODEL`

Operator allowlist:

- Read comma-separated `GEMINI_ALLOWED_MODELS_EXTRA`.
- Unknown model is valid only if included in the allowlist.
- Return `operator_allowed = TRUE` and a warning.

- [ ] **Step 4: Wire runtime paths to central config**

Modify `api/bootstrap/load_modules.R`:

- Source `functions/llm-model-config.R` before `functions/llm-client.R`.

Modify `api/functions/llm-client.R`:

- Remove local `get_default_gemini_model()`, `list_gemini_models()`, and `get_gemini_model_metadata()` definitions.
- Use functions from `llm-model-config.R`.
- Before calling Gemini, call `llm_model_config_validate(model)`.
- Return a structured `llm_model_invalid` error result when invalid.

Modify `api/functions/llm-service.R` and `api/functions/llm-judge.R`:

- Replace stale roxygen defaults mentioning `gemini-3-pro-preview`.
- Keep `model = NULL` defaults and resolve through `get_default_gemini_model()`.

Modify `api/functions/llm-cache-repository.R`:

- Change examples that imply `gemini-3-pro-preview` is current. Historical rows may still contain old names.

Modify `api/endpoints/llm_admin_endpoints.R`:

- Config response includes `current_model`, `source`, `default_model`, `valid`, `operator_allowed`, `warning`, and `available_models`.
- Update model mutation endpoint to reject invalid models unless operator allowlisted.

- [ ] **Step 5: Update frontend LLM admin types and tests**

Modify `app/src/api/llm_admin.ts`:

- Add fields to config response type:
  - `source`
  - `default_model`
  - `valid`
  - `operator_allowed`
  - `warning`

Modify `app/src/components/llm/LlmConfigPanel.vue`:

- Display invalid current model warning using existing admin-panel styling.
- Display operator-allowed warning when present.
- Do not add marketing copy or a new landing-style section.

Update `app/src/api/llm_admin.spec.ts` and `app/src/components/llm/LlmConfigPanel.spec.ts` to use current valid model names and invalid/operator-allowed response fields.

- [ ] **Step 6: Update config docs**

Modify `api/config.yml.example`:

- Add `gemini_model: "gemini-3.5-flash"` under each config environment.

Modify `documentation/08-development.qmd`:

- Document `GEMINI_MODEL`, `GEMINI_ALLOWED_MODELS_EXTRA`, and local default.

Modify `documentation/09-deployment.qmd`:

- Document production config source order, invalid model behavior, and operator allowlist warning.

- [ ] **Step 7: Run focused tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-llm-model-config.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-llm-client-config.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-llm-endpoint-helpers.R')"
cd app && npx vitest run src/api/llm_admin.spec.ts src/components/llm/LlmConfigPanel.spec.ts
```

Expected:

- All focused LLM tests pass.

- [ ] **Step 8: Commit Task 6**

Run:

```bash
git add api/functions/llm-model-config.R \
  api/bootstrap/load_modules.R \
  api/functions/llm-client.R \
  api/functions/llm-service.R \
  api/functions/llm-judge.R \
  api/functions/llm-cache-repository.R \
  api/endpoints/llm_admin_endpoints.R \
  api/tests/testthat/test-unit-llm-model-config.R \
  api/tests/testthat/test-unit-llm-client-config.R \
  api/tests/testthat/test-unit-llm-endpoint-helpers.R \
  api/config.yml.example \
  app/src/api/llm_admin.ts \
  app/src/api/llm_admin.spec.ts \
  app/src/components/llm/LlmConfigPanel.vue \
  app/src/components/llm/LlmConfigPanel.spec.ts \
  documentation/08-development.qmd \
  documentation/09-deployment.qmd
git commit -m "fix: centralize Gemini model configuration"
```

Expected:

- Commit succeeds.

---

### Task 7: Documentation, Agent Guidance, And Final Verification

**Files:**
- Modify: `AGENTS.md`
- Modify: `documentation/08-development.qmd`
- Modify: `documentation/09-deployment.qmd`
- Modify: `.planning/superpowers/plans/2026-05-30-analysis-availability-mcp-snapshots-llm-config-plan.md` if execution notes are discovered during implementation

- [ ] **Step 1: Update persistent agent guidance**

Modify `AGENTS.md`:

- Add a short section under derived analysis/MCP guidance:
  - public analysis endpoints read public-ready snapshots;
  - supported parameter presets are fixed until worker precomputes more;
  - unsupported parameters fail fast;
  - MCP reads public-ready snapshots only;
  - snapshot refresh jobs must use approved-public input gates;
  - snapshot activation is scoped by `(analysis_type, parameter_hash)`.

- [ ] **Step 2: Update development docs**

Modify `documentation/08-development.qmd`:

- Add developer workflow for:
  - creating a snapshot migration;
  - running `analysis_snapshot_refresh`;
  - running focused snapshot tests;
  - using `make test-mcp-smoke`;
  - LLM model env vars.

- [ ] **Step 3: Update deployment docs**

Modify `documentation/09-deployment.qmd`:

- Add operator workflow for:
  - refreshing public analysis snapshots after data changes;
  - interpreting `snapshot_missing`, `snapshot_stale`, and `unsupported_parameter`;
  - configuring external provider budgets;
  - configuring Gemini model defaults and operator allowlist.

- [ ] **Step 4: Run file-size and static code-quality gate**

Run:

```bash
make code-quality-audit
```

Expected:

- Command exits 0.
- If a touched handwritten file exceeds the ratchet, split cohesive helpers before continuing.

- [ ] **Step 5: Run fast API gate**

Run:

```bash
make test-api-fast
```

Expected:

- Command exits 0.

- [ ] **Step 6: Run frontend checks**

Run:

```bash
make lint-app
cd app && npm run type-check
cd app && npm run test:unit
```

Expected:

- All commands exit 0.

- [ ] **Step 7: Run MCP smoke against a running MCP sidecar**

Start the local MCP stack using the repository's documented dev stack if it is not already running.

Run:

```bash
make test-mcp-smoke
```

Expected:

- Command exits 0 and reports MCP smoke complete.

- [ ] **Step 8: Run final pre-commit gate**

Run:

```bash
make pre-commit
```

Expected:

- Command exits 0.

- [ ] **Step 9: Run full local CI if the implementation touched every planned area**

Run this because the sprint touches DB, API, worker, MCP, frontend, and docs:

```bash
make ci-local
```

Expected:

- Command exits 0.
- If any unrelated pre-existing failure appears, capture the exact failing test names and confirm they are pre-existing before handoff.

- [ ] **Step 10: Commit Task 7**

Run:

```bash
git add AGENTS.md documentation/08-development.qmd documentation/09-deployment.qmd
git commit -m "docs: document public analysis snapshot operations"
```

Expected:

- Commit succeeds, or reports nothing to commit if documentation was already committed with earlier tasks.

---

## Final Handoff Checklist

- [ ] `git status --short` shows only intentional changes or a clean tree.
- [ ] `git log --oneline -n 7` shows the planned phase commits.
- [ ] `make code-quality-audit` passed.
- [ ] `make test-api-fast` passed.
- [ ] `make test-mcp-smoke` passed against a running MCP sidecar.
- [ ] `cd app && npm run type-check` passed.
- [ ] `cd app && npm run test:unit` passed.
- [ ] `make pre-commit` passed.
- [ ] `make ci-local` passed or exact environment blocker is documented.
- [ ] Public analysis endpoints do not call heavy analysis helpers on missing snapshots.
- [ ] MCP analysis tools do not call disk RDS scans, live external providers, Gemini, or heavy analysis helpers.
- [ ] Unsupported analysis parameters return `unsupported_parameter`.
- [ ] Snapshot activation guarantees one public-ready row per `(analysis_type, parameter_hash)`.
- [ ] LLM generation no longer happens from public cache-hit job submission.
- [ ] LLM generation is handled by worker/admin snapshot refresh policy or reports `summary_available = false`.
