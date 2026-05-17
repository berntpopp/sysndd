# NDDScore Prediction Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public, clearly-labelled machine-learning prediction layer ("NDDScore") to SysNDD — sourced from a published Zenodo dataset — with a public browsing UI/API and an Administrator-only, production-safe import/update flow.

**Architecture:** An additive DB migration adds four `nddscore_*` tables plus `*_current` views. A durable MySQL-backed async job (System B) downloads, verifies, validates, and imports a Zenodo release in the worker container, switching the active release atomically only at the final step. Read-only public endpoints serve the active release; Administrator-only endpoints submit the import job. The Vue SPA gets a public `/NDDScore` browsing page and an admin `/ManageNDDScore` operations page, with copy and visual treatment that keeps NDDScore visibly separate from curated SysNDD evidence.

**Tech Stack:** R / Plumber API (`renv`), MySQL (migration runner with advisory locks), durable async-job worker, Vue 3 + TypeScript + Vite SPA, `testthat` (API) and `vitest` (frontend).

**Source spec:** `.planning/superpowers/specs/2026-05-17-nddscore-prediction-layer-design.md` — all design decisions are locked in spec §11. This plan does not re-open them.

**Verified dataset facts** (confirmed by downloading Zenodo record `20258027` during planning):
- Archive `nddscore_sysndd_prediction_release_2026-05-17.tar.gz`, 7,568,944 bytes, `md5:7b7d2b397ca80a4e8d437b9696bef049`.
- Zenodo record version string: `2026.05.17`; version DOI `10.5281/zenodo.20258027`; concept DOI `10.5281/zenodo.20258026`.
- Archive top directory: `sysndd_zenodo_dataset/`; release files in `sysndd_zenodo_dataset/sysndd_prediction_release/`.
- `nddscore_release.json` `release_id` = `nddscore_20260517_public`, `score_schema_version` = `1.0.0`, `n_genes` 19296, `n_hpo_predictions` 44360, `n_hpo_terms` 37, `n_features` 48, `hpo_threshold` 0.5. It carries `is_active: true` (the importer **ignores** this).
- TSV row counts confirmed: gene 19296, hpo prediction 44360, hpo term 37.
- The inner `sysndd_prediction_release/checksums.sha256` lists sha256 for 8 files: `README.md`, the 3 `.parquet`, the 3 `.tsv`, `nddscore_release.json`, `nddscore_schema.sql` (it does not list itself).
- Exact TSV column headers and the shipped `nddscore_schema.sql` are reproduced verbatim in Task 1 and Task 6.

---

## Conventions every task must follow

Read `AGENTS.md` before starting. Key invariants this plan depends on:

- **API source order** (`api/bootstrap/load_modules.R`): functions → core → services → endpoints. New `api/functions/nddscore-*.R` files must be registered in `load_modules.R`.
- **Repository before services**: service functions use `svc_`/`service_` prefixes to avoid shadowing repository functions. NDDScore repository functions use the bare `nddscore_` prefix and live in `api/functions/`.
- **Namespace `dplyr::select()`** etc. explicitly — loaded packages mask them.
- **`DBI::dbBind()` with `?` placeholders** needs `unname()`-ed params; never named lists.
- **Plumber may return JSON scalars as arrays.** Frontend unwraps with `unwrapScalar()` before feeding values back into axios params.
- **Migrations** are applied at API startup by the migration runner under a MySQL advisory lock; failures crash startup — never weaken startup checks to work around a failing migration.
- **Worker container**: durable async-job code is sourced once at worker start. After changing worker-executed code (`api/functions/async-job-handlers.R`, `api/functions/nddscore-*.R`), restart the worker container before assuming the change is live. The worker has outbound egress (needed for Zenodo).
- **`api/tests/` is not bind-mounted** into containers — run API tests on the host (`make test-api` / single-file `Rscript -e "testthat::test_file(...)"`), or `docker cp` into a running container.
- **No secrets in logs.** The importer never logs tokens, env vars, or DB passwords.
- **Copy rules (spec §7).** Use: `ML prediction`, `Model-derived`, `Prediction layer`, `Separate from curated SysNDD evidence`, `Not an evidence tier`. Never: `curated NDDScore`, `validated by SysNDD`, `evidence tier`, `manual review`, `curated gene status`.

**Verification gates (spec §10).** Run after the phase that touches the relevant tree; all must pass before handoff:
`make pre-commit`, `make test-api`, `make lint-api`, `make lint-app`, `cd app && npm run type-check`, `cd app && npm run test:unit`, and `make ci-local` before final handoff.

**Commits.** One atomic commit per task step that says "Commit". Do not push and do not open a PR unless the user explicitly asks. Conventional-commit messages (`feat:`, `test:`, `docs:`, `chore:`).

---

## File Structure

**Created — API:**
- `db/migrations/023_add_nddscore_prediction_release.sql` — additive schema migration.
- `api/functions/nddscore-import.R` — pure, unit-testable importer functions (fetch / download / verify / extract / parse / load / validate).
- `api/functions/nddscore-repository.R` — read-only parametrized query functions for the public API.
- `api/endpoints/nddscore_endpoints.R` — public NDDScore REST endpoints.
- `api/tests/testthat/test-nddscore-migration.R` — migration / table-shape tests.
- `api/tests/testthat/test-nddscore-import.R` — importer unit tests.
- `api/tests/testthat/test-nddscore-job.R` — async-job handler tests (advisory lock, activation, guards).
- `api/tests/testthat/test-nddscore-repository.R` — repository query tests.
- `api/tests/testthat/test-nddscore-endpoints.R` — public + admin endpoint tests.
- `api/tests/testthat/helper-nddscore.R` — fixture-archive path helper + DB seed helpers.
- `api/tests/testthat/fixtures/nddscore/` — committed trimmed fixture archive + generator script.

**Modified — API:**
- `api/bootstrap/load_modules.R` — register the two new `functions/nddscore-*.R` files.
- `api/functions/async-job-handlers.R` — add the `nddscore_import` registry entry + handler.
- `api/start_sysndd_api.R` / plumber router — mount `nddscore_endpoints.R` under `/api/nddscore`.
- `api/endpoints/admin_endpoints.R` — add three `/api/admin/nddscore/*` endpoints.
- `api/version_spec.json` — bump version.

**Created — frontend:**
- `app/src/api/nddscore.ts` — public API client.
- `app/src/api/nddscore_admin.ts` — admin API client.
- `app/src/components/nddscore/NddScorePredictionCard.vue` — reusable ML-prediction indicator card.
- `app/src/components/nddscore/NddScoreGeneTable.vue` — gene-predictions table.
- `app/src/components/nddscore/NddScoreHpoTable.vue` — phenotype-predictions table.
- `app/src/components/nddscore/NddScoreModelCard.vue` — model-card tab.
- `app/src/components/nddscore/NddScoreGeneDetail.vue` — single-gene detail.
- `app/src/views/nddscore/NDDScore.vue` — public page shell (AnalysisShell + route-driven tabs).
- `app/src/views/admin/ManageNDDScore.vue` — admin operations page.
- `*.spec.ts` siblings for the components/views above.

**Modified — frontend:**
- `app/src/assets/js/constants/main_nav_constants.ts` — new `NDDScore` dropdown + admin nav item.
- `app/src/router/routes.ts` — `/NDDScore` (with children) + `/ManageNDDScore` routes.

**Modified — docs:**
- `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd`, `db/migrations/README.md`.

---

# Phase 1 — Database schema + test fixture

### Task 1: Migration `023_add_nddscore_prediction_release.sql`

**Files:**
- Create: `db/migrations/023_add_nddscore_prediction_release.sql`

The DDL is adapted from the dataset's shipped `nddscore_schema.sql` with two deliberate deviations (spec §4): collation forced to `utf8mb4_unicode_ci`, and `nddscore_release` extended into a superset with SysNDD provenance + operational columns. `nddscore_gene_prediction`, `nddscore_hpo_prediction`, `nddscore_hpo_term` keep the dataset's columns verbatim; indexes follow spec §4.5; all three `*_current` views are added.

- [ ] **Step 1: Write the migration file**

Create `db/migrations/023_add_nddscore_prediction_release.sql` with exactly this content:

```sql
-- Migration: 023_add_nddscore_prediction_release
-- Description: Adds the NDDScore machine-learning prediction layer: release metadata,
--              per-gene predictions, per-gene-HPO predictions, and per-HPO-term metadata,
--              plus *_current views resolving the single active release.
--              NDDScore is a model-derived prediction layer and is kept separate from
--              curated SysNDD evidence. DDL adapted from the Zenodo dataset's shipped
--              nddscore_schema.sql; collation forced to utf8mb4_unicode_ci (repo
--              convention, see migration 020); nddscore_release extended with SysNDD
--              provenance + operational columns. is_active is SysNDD-controlled.

CREATE TABLE IF NOT EXISTS `nddscore_release` (
  `release_id` VARCHAR(64) NOT NULL,
  `score_schema_version` VARCHAR(16) NOT NULL,
  `version` VARCHAR(32) DEFAULT NULL,
  `release_created_at` DATETIME(6) DEFAULT NULL,
  `n_genes` INT NOT NULL,
  `n_hpo_predictions` INT NOT NULL,
  `n_hpo_terms` INT NOT NULL,
  `n_features` INT NOT NULL,
  `hpo_threshold` DECIMAL(6,5) NOT NULL,
  `calibration_method` VARCHAR(64) DEFAULT NULL,
  `ndd_model_created_at` VARCHAR(64) DEFAULT NULL,
  `phenotype_model_created_at` VARCHAR(64) DEFAULT NULL,
  `inheritance_model_created_at` VARCHAR(64) DEFAULT NULL,
  `ndd_performance_json` JSON DEFAULT NULL,
  `phenotype_performance_json` JSON DEFAULT NULL,
  `inheritance_performance_json` JSON DEFAULT NULL,
  `data_versions_json` JSON DEFAULT NULL,
  `artifact_hashes_json` JSON DEFAULT NULL,
  `zenodo_record_url` VARCHAR(255) DEFAULT NULL,
  `version_doi` VARCHAR(128) DEFAULT NULL,
  `concept_doi` VARCHAR(128) DEFAULT NULL,
  `source_record_id` VARCHAR(32) DEFAULT NULL,
  `source_archive_name` VARCHAR(255) DEFAULT NULL,
  `source_archive_checksum` VARCHAR(64) DEFAULT NULL,
  `source_archive_bytes` BIGINT DEFAULT NULL,
  `is_active` TINYINT NOT NULL DEFAULT 0,
  `import_status` ENUM('pending','importing','validated','active','superseded','failed')
      NOT NULL DEFAULT 'pending',
  `imported_by` INT DEFAULT NULL,
  `import_job_id` CHAR(36) DEFAULT NULL,
  `import_started_at` DATETIME(6) DEFAULT NULL,
  `import_completed_at` DATETIME(6) DEFAULT NULL,
  `activated_at` DATETIME(6) DEFAULT NULL,
  `last_error_message` TEXT DEFAULT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
      ON UPDATE CURRENT_TIMESTAMP(6),
  `active_release_slot` TINYINT
      GENERATED ALWAYS AS (CASE WHEN `is_active` = 1 THEN 1 ELSE NULL END) STORED,
  PRIMARY KEY (`release_id`),
  UNIQUE KEY `idx_nddscore_release_active_slot` (`active_release_slot`),
  KEY `idx_nddscore_release_status` (`import_status`),
  CONSTRAINT `fk_nddscore_release_imported_by`
      FOREIGN KEY (`imported_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nddscore_gene_prediction` (
  `release_id` VARCHAR(64) NOT NULL,
  `hgnc_id` VARCHAR(10) NOT NULL,
  `gene_symbol` VARCHAR(50) NOT NULL,
  `ensembl_gene_id` VARCHAR(20) DEFAULT NULL,
  `ndd_score` DECIMAL(8,7) NOT NULL,
  `ndd_score_std` DECIMAL(8,7) DEFAULT NULL,
  `ndd_score_iqr` DECIMAL(8,7) DEFAULT NULL,
  `bag_agreement` DECIMAL(8,7) DEFAULT NULL,
  `rank` INT NOT NULL,
  `percentile` DECIMAL(8,5) NOT NULL,
  `risk_tier` VARCHAR(20) NOT NULL,
  `confidence_tier` VARCHAR(20) NOT NULL,
  `known_sysndd_gene` TINYINT DEFAULT NULL,
  `model_split` VARCHAR(20) DEFAULT NULL,
  `inheritance_ad_probability` DECIMAL(8,7) DEFAULT NULL,
  `inheritance_ar_probability` DECIMAL(8,7) DEFAULT NULL,
  `inheritance_xld_probability` DECIMAL(8,7) DEFAULT NULL,
  `inheritance_xlr_probability` DECIMAL(8,7) DEFAULT NULL,
  `top_inheritance_mode` VARCHAR(8) DEFAULT NULL,
  `called_inheritance_modes` JSON DEFAULT NULL,
  `n_predicted_hpo` INT NOT NULL DEFAULT 0,
  `top_hpo_predictions_json` JSON DEFAULT NULL,
  `shap_clinical` DOUBLE DEFAULT NULL,
  `shap_constraint` DOUBLE DEFAULT NULL,
  `shap_expression` DOUBLE DEFAULT NULL,
  `shap_network` DOUBLE DEFAULT NULL,
  `shap_conservation` DOUBLE DEFAULT NULL,
  `shap_other` DOUBLE DEFAULT NULL,
  `dominant_shap_group` VARCHAR(32) DEFAULT NULL,
  `top_features_json` JSON DEFAULT NULL,
  `prediction_note` TEXT DEFAULT NULL,
  PRIMARY KEY (`release_id`, `hgnc_id`),
  KEY `idx_nddscore_gene_symbol` (`release_id`, `gene_symbol`),
  KEY `idx_nddscore_gene_rank` (`release_id`, `rank`),
  KEY `idx_nddscore_gene_risk` (`release_id`, `risk_tier`),
  KEY `idx_nddscore_gene_confidence` (`release_id`, `confidence_tier`),
  CONSTRAINT `fk_nddscore_gene_release`
      FOREIGN KEY (`release_id`) REFERENCES `nddscore_release` (`release_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nddscore_hpo_prediction` (
  `release_id` VARCHAR(64) NOT NULL,
  `hgnc_id` VARCHAR(10) NOT NULL,
  `gene_symbol` VARCHAR(50) NOT NULL,
  `phenotype_id` VARCHAR(10) NOT NULL,
  `phenotype_name` VARCHAR(255) NOT NULL,
  `probability` DECIMAL(8,7) NOT NULL,
  `rank_for_gene` INT NOT NULL,
  `passes_default_threshold` TINYINT NOT NULL DEFAULT 1,
  `term_auc_roc` DECIMAL(8,7) DEFAULT NULL,
  `term_auc_pr` DECIMAL(8,7) DEFAULT NULL,
  `term_training_support` INT DEFAULT NULL,
  PRIMARY KEY (`release_id`, `hgnc_id`, `phenotype_id`),
  KEY `idx_nddscore_hpo_phenotype` (`release_id`, `phenotype_id`),
  KEY `idx_nddscore_hpo_probability` (`release_id`, `probability`),
  CONSTRAINT `fk_nddscore_hpo_gene`
      FOREIGN KEY (`release_id`, `hgnc_id`)
      REFERENCES `nddscore_gene_prediction` (`release_id`, `hgnc_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nddscore_hpo_term` (
  `release_id` VARCHAR(64) NOT NULL,
  `phenotype_id` VARCHAR(10) NOT NULL,
  `phenotype_name` VARCHAR(255) NOT NULL,
  `term_auc_roc` DECIMAL(8,7) DEFAULT NULL,
  `term_auc_pr` DECIMAL(8,7) DEFAULT NULL,
  `term_training_support` INT DEFAULT NULL,
  `is_in_ndd_subtree` TINYINT DEFAULT NULL,
  PRIMARY KEY (`release_id`, `phenotype_id`),
  CONSTRAINT `fk_nddscore_hpo_term_release`
      FOREIGN KEY (`release_id`) REFERENCES `nddscore_release` (`release_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE OR REPLACE VIEW `nddscore_gene_prediction_current` AS
SELECT gp.*
FROM `nddscore_gene_prediction` gp
JOIN `nddscore_release` r ON r.`release_id` = gp.`release_id`
WHERE r.`is_active` = 1;

CREATE OR REPLACE VIEW `nddscore_hpo_prediction_current` AS
SELECT hp.*
FROM `nddscore_hpo_prediction` hp
JOIN `nddscore_release` r ON r.`release_id` = hp.`release_id`
WHERE r.`is_active` = 1;

CREATE OR REPLACE VIEW `nddscore_hpo_term_current` AS
SELECT ht.*
FROM `nddscore_hpo_term` ht
JOIN `nddscore_release` r ON r.`release_id` = ht.`release_id`
WHERE r.`is_active` = 1;
```

- [ ] **Step 2: Verify migration prefix uniqueness**

Run: `bash scripts/check-migration-prefixes.sh`
Expected: exit 0, no duplicate-prefix error (023 is new).

- [ ] **Step 3: Apply the migration against a dev DB and confirm it runs**

Run: `make docker-dev-db` (or `make dev`), then check the API/worker startup log for the migration runner applying `023_add_nddscore_prediction_release`.
Expected: startup completes; `schema_version` table has a row for `023_add_nddscore_prediction_release.sql` with `success = TRUE`. If startup crashes, the migration is malformed — fix the SQL, do not weaken the runner.

Verify the four tables and three views exist:
Run: `docker exec sysndd-db-1 mysql -uroot -p"$MYSQL_ROOT_PASSWORD" sysndd_db_dev -e "SHOW TABLES LIKE 'nddscore%'; SHOW FULL TABLES LIKE 'nddscore%current';"`
Expected: `nddscore_release`, `nddscore_gene_prediction`, `nddscore_hpo_prediction`, `nddscore_hpo_term` (BASE TABLE) and three `*_current` (VIEW).

- [ ] **Step 4: Commit**

```bash
git add db/migrations/023_add_nddscore_prediction_release.sql
git commit -m "feat(db): add NDDScore prediction-layer migration 023"
```

---

### Task 2: Test fixture archive + generator

**Files:**
- Create: `api/tests/testthat/fixtures/nddscore/make-fixture-archive.R` (generator script)
- Create: `api/tests/testthat/fixtures/nddscore/nddscore_fixture_release.tar.gz` (committed fixture)
- Create: `api/tests/testthat/fixtures/nddscore/nddscore_fixture_bad_md5.tar.gz` (committed; identical bytes are fine — only the *expected* md5 passed in tests differs)
- Create: `api/tests/testthat/fixtures/nddscore/README.md`

The fixture is a trimmed `.tar.gz` with the same internal layout as the real Zenodo archive but only 3 genes / a handful of HPO rows, so importer tests run with no network. It ships its own valid inner `checksums.sha256`. A second archive (`*_corrupt_sha256.tar.gz`) has a deliberately wrong inner sha256 line to test extract-verification failure.

- [ ] **Step 1: Write the generator script**

Create `api/tests/testthat/fixtures/nddscore/make-fixture-archive.R`:

```r
# Regenerates the committed NDDScore test fixture archives.
# Run from repo root: Rscript api/tests/testthat/fixtures/nddscore/make-fixture-archive.R
# Produces, in this directory:
#   nddscore_fixture_release.tar.gz  - valid trimmed release (3 genes, 4 HPO predictions, 2 terms)
#   nddscore_fixture_corrupt_sha256.tar.gz - same files but inner checksums.sha256 is wrong
# The fixture mirrors the real archive layout:
#   sysndd_zenodo_dataset/sysndd_prediction_release/{*.tsv, nddscore_release.json,
#     nddscore_schema.sql, checksums.sha256}

fixture_dir <- "api/tests/testthat/fixtures/nddscore"
rel <- "sysndd_zenodo_dataset/sysndd_prediction_release"

build_one <- function(out_name, corrupt_sha = FALSE) {
  stage <- file.path(tempdir(), paste0("ndd_fix_", as.integer(runif(1, 1, 1e9))))
  rel_dir <- file.path(stage, rel)
  dir.create(rel_dir, recursive = TRUE, showWarnings = FALSE)

  gene_tsv <- paste(
    "release_id\thgnc_id\tgene_symbol\tensembl_gene_id\tndd_score\tndd_score_std\tndd_score_iqr\tbag_agreement\trank\tpercentile\trisk_tier\tconfidence_tier\tknown_sysndd_gene\tmodel_split\tinheritance_ad_probability\tinheritance_ar_probability\tinheritance_xld_probability\tinheritance_xlr_probability\ttop_inheritance_mode\tcalled_inheritance_modes\tn_predicted_hpo\ttop_hpo_predictions_json\tshap_clinical\tshap_constraint\tshap_expression\tshap_network\tshap_conservation\tshap_other\tdominant_shap_group\ttop_features_json\tprediction_note",
    "ndd_fixture_release\tHGNC:2022\tCLCN4\tENSG00000073464\t0.9938804\t0.0035516\t0.0040947\t1.0\t1\t100.0\tVery High\tHigh\t1\ttrain\t0.0244\t0.0\t0.7373\t0.0233\tXLD\t\"[\"\"XLD\"\"]\"\t2\t\"[]\"\t1.06\t1.90\t2.18\t0.36\t0.07\t0.04\texpression\t\"[]\"\tFixture gene CLCN4.",
    "ndd_fixture_release\tHGNC:11110\tSTXBP1\tENSG00000136854\t0.9512000\t0.0100000\t0.0120000\t0.9\t2\t99.5\tHigh\tHigh\t1\ttest\t0.8100\t0.0200\t0.0100\t0.0050\tAD\t\"[\"\"AD\"\"]\"\t2\t\"[]\"\t0.50\t0.40\t0.30\t0.20\t0.10\t0.05\tclinical\t\"[]\"\tFixture gene STXBP1.",
    "ndd_fixture_release\tHGNC:99999\tFIXNOVEL\tENSG00000000001\t0.4200000\t0.0500000\t0.0600000\t0.5\t3\t42.0\tLow\tLow\t0\ttrain\t0.3000\t0.3000\t0.0100\t0.0100\tAR\t\"[]\"\t0\t\"[]\"\t0.10\t0.10\t0.10\t0.10\t0.10\t0.10\tother\t\"[]\"\tFixture novel gene.",
    sep = "\n"
  )
  hpo_pred_tsv <- paste(
    "release_id\thgnc_id\tgene_symbol\tphenotype_id\tphenotype_name\tprobability\trank_for_gene\tpasses_default_threshold\tterm_auc_roc\tterm_auc_pr\tterm_training_support",
    "ndd_fixture_release\tHGNC:2022\tCLCN4\tHP:0001249\tIntellectual disability\t0.9981000\t1\t1\t0.8200000\t0.7100000\t450",
    "ndd_fixture_release\tHGNC:2022\tCLCN4\tHP:0001250\tSeizure\t0.8317000\t2\t1\t0.7900000\t0.6800000\t300",
    "ndd_fixture_release\tHGNC:11110\tSTXBP1\tHP:0001249\tIntellectual disability\t0.9700000\t1\t1\t0.8200000\t0.7100000\t450",
    "ndd_fixture_release\tHGNC:11110\tSTXBP1\tHP:0001250\tSeizure\t0.9100000\t2\t1\t0.7900000\t0.6800000\t300",
    sep = "\n"
  )
  hpo_term_tsv <- paste(
    "release_id\tphenotype_id\tphenotype_name\tterm_auc_roc\tterm_auc_pr\tterm_training_support",
    "ndd_fixture_release\tHP:0001249\tIntellectual disability\t0.8200000\t0.7100000\t450",
    "ndd_fixture_release\tHP:0001250\tSeizure\t0.7900000\t0.6800000\t300",
    sep = "\n"
  )
  release_json <- paste0(
    '{\n',
    '  "release_id": "ndd_fixture_release",\n',
    '  "score_schema_version": "1.0.0",\n',
    '  "created_at": "2026-05-17T13:53:16",\n',
    '  "n_genes": 3,\n',
    '  "n_hpo_predictions": 4,\n',
    '  "n_hpo_terms": 2,\n',
    '  "n_features": 48,\n',
    '  "hpo_threshold": 0.5,\n',
    '  "calibration_method": "platt_oob",\n',
    '  "ndd_model_created_at": "2026-05-17T13:49:24",\n',
    '  "phenotype_model_created_at": "2026-05-17T13:51:16",\n',
    '  "inheritance_model_created_at": "2026-05-17T13:51:20",\n',
    '  "is_active": true,\n',
    '  "ndd_performance_json": {"test": {"auc_roc": 0.8877, "auc_pr": 0.8965, ',
    '"brier": 0.1388, "bss": 0.4438}},\n',
    '  "phenotype_performance_json": {"pre_tpr": {"macro_auc_roc": 0.749}},\n',
    '  "inheritance_performance_json": {"macro_f1": 0.728},\n',
    '  "data_versions_json": {"hgnc": {"version": "2026-04"}},\n',
    '  "artifact_hashes_json": {"nddscore_schema.sql": "fixture"}\n',
    '}\n'
  )
  schema_sql <- "-- fixture schema placeholder; real DDL ships in db/migrations/023\n"

  writeLines(gene_tsv, file.path(rel_dir, "nddscore_gene_predictions.tsv"))
  writeLines(hpo_pred_tsv, file.path(rel_dir, "nddscore_hpo_predictions.tsv"))
  writeLines(hpo_term_tsv, file.path(rel_dir, "nddscore_hpo_terms.tsv"))
  writeLines(release_json, file.path(rel_dir, "nddscore_release.json"))
  writeLines(schema_sql, file.path(rel_dir, "nddscore_schema.sql"))

  checksum_files <- c(
    "nddscore_gene_predictions.tsv", "nddscore_hpo_predictions.tsv",
    "nddscore_hpo_terms.tsv", "nddscore_release.json", "nddscore_schema.sql"
  )
  sha_lines <- vapply(checksum_files, function(f) {
    digest_val <- if (corrupt_sha && f == "nddscore_release.json") {
      paste(rep("0", 64), collapse = "")
    } else {
      digest::digest(file = file.path(rel_dir, f), algo = "sha256")
    }
    paste0(digest_val, "  ", f)
  }, character(1))
  writeLines(sha_lines, file.path(rel_dir, "checksums.sha256"))

  old_wd <- getwd()
  setwd(stage)
  on.exit(setwd(old_wd), add = TRUE)
  utils::tar(
    file.path(old_wd, fixture_dir, out_name),
    files = "sysndd_zenodo_dataset",
    compression = "gzip"
  )
  setwd(old_wd)
  archive <- file.path(fixture_dir, out_name)
  message(sprintf(
    "%s: %d bytes, md5=%s", out_name,
    file.size(archive), digest::digest(file = archive, algo = "md5")
  ))
}

build_one("nddscore_fixture_release.tar.gz", corrupt_sha = FALSE)
build_one("nddscore_fixture_corrupt_sha256.tar.gz", corrupt_sha = TRUE)
```

- [ ] **Step 2: Generate the fixtures**

Run: `cd /home/bernt-popp/development/sysndd && Rscript --no-init-file api/tests/testthat/fixtures/nddscore/make-fixture-archive.R`
Expected: prints two lines like `nddscore_fixture_release.tar.gz: NNNN bytes, md5=<hash>`. **Record the md5 of `nddscore_fixture_release.tar.gz`** — it is needed verbatim in Task 8's `helper-nddscore.R` and Task 9's tests as the "expected good md5".

- [ ] **Step 3: Write the fixture README**

Create `api/tests/testthat/fixtures/nddscore/README.md`:

```markdown
# NDDScore test fixtures

Trimmed Zenodo-style release archives for offline importer/job tests. No network.

- `nddscore_fixture_release.tar.gz` — valid 3-gene / 4-HPO-prediction / 2-term release
  with a correct inner `checksums.sha256`. Internal layout matches the real archive:
  `sysndd_zenodo_dataset/sysndd_prediction_release/`.
- `nddscore_fixture_corrupt_sha256.tar.gz` — same files, but the inner `checksums.sha256`
  line for `nddscore_release.json` is wrong (extract-verification failure case).

Regenerate with `Rscript api/tests/testthat/fixtures/nddscore/make-fixture-archive.R`.
The valid archive's md5 is recorded in `helper-nddscore.R` as the expected good checksum.
```

- [ ] **Step 4: Commit**

```bash
git add api/tests/testthat/fixtures/nddscore/
git commit -m "test(api): add trimmed NDDScore fixture archives + generator"
```

---

# Phase 2 — Backend importer (`nddscore-import.R`, TDD)

All Phase 2 functions are pure and unit-testable (spec §5.2). They never touch the DB and never log secrets. Tests mock Zenodo HTTP — no network. Each task is strict red-green: write the failing test, run it red, implement, run it green, commit.

The importer file accumulates one function per task. Create the file in Task 3 with a header comment; later tasks append.

### Task 3: `nddscore_fetch_zenodo_metadata()`

**Files:**
- Create: `api/functions/nddscore-import.R`
- Create: `api/tests/testthat/test-nddscore-import.R`

`nddscore_fetch_zenodo_metadata(record_id, http_get = ...)` fetches the Zenodo API record JSON and locates the release archive file entry by filename (`*.tar.gz`), returning a normalized list. The HTTP call is injected as a parameter (`http_get`) so tests pass a stub — no `httptest2` needed here.

- [ ] **Step 1: Write the failing test**

Create `api/tests/testthat/test-nddscore-import.R`:

```r
# Tests for the pure NDDScore importer functions (api/functions/nddscore-import.R).
# Zenodo HTTP is always stubbed; archive operations use the committed fixture.

source_api_file("functions/nddscore-import.R", local = FALSE)

fixture_archive <- function(name = "nddscore_fixture_release.tar.gz") {
  testthat::test_path("fixtures", "nddscore", name)
}

# A minimal Zenodo API record shaped like the real /api/records/<id> response.
fake_zenodo_record <- function() {
  list(
    id = 20258027L,
    doi = "10.5281/zenodo.20258027",
    conceptdoi = "10.5281/zenodo.20258026",
    metadata = list(version = "2026.05.17"),
    links = list(self_html = "https://zenodo.org/records/20258027"),
    files = list(
      list(
        key = "nddscore_sysndd_prediction_release_2026-05-17.tar.gz",
        size = 7568944L,
        checksum = "md5:7b7d2b397ca80a4e8d437b9696bef049",
        links = list(self = "https://zenodo.org/api/records/20258027/files/nddscore_sysndd_prediction_release_2026-05-17.tar.gz/content")
      )
    )
  )
}

describe("nddscore_fetch_zenodo_metadata", {
  it("locates the archive entry and normalizes metadata", {
    stub_get <- function(url) {
      expect_match(url, "/api/records/20258027$")
      fake_zenodo_record()
    }
    meta <- nddscore_fetch_zenodo_metadata("20258027", http_get = stub_get)

    expect_equal(meta$record_id, "20258027")
    expect_equal(meta$archive_name,
                 "nddscore_sysndd_prediction_release_2026-05-17.tar.gz")
    expect_equal(meta$archive_bytes, 7568944L)
    expect_equal(meta$archive_md5, "7b7d2b397ca80a4e8d437b9696bef049")
    expect_match(meta$content_url, "/content$")
    expect_equal(meta$version, "2026.05.17")
    expect_equal(meta$version_doi, "10.5281/zenodo.20258027")
    expect_equal(meta$concept_doi, "10.5281/zenodo.20258026")
    expect_equal(meta$record_url, "https://zenodo.org/records/20258027")
  })

  it("errors clearly when no .tar.gz file entry exists", {
    stub_get <- function(url) {
      rec <- fake_zenodo_record()
      rec$files <- list(list(key = "readme.txt", size = 1L,
                             checksum = "md5:abc", links = list(self = "x")))
      rec
    }
    expect_error(
      nddscore_fetch_zenodo_metadata("20258027", http_get = stub_get),
      "archive"
    )
  })
})
```

- [ ] **Step 2: Run the test — verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-import.R')"`
Expected: FAIL — `could not find function "nddscore_fetch_zenodo_metadata"`.

- [ ] **Step 3: Implement**

Create `api/functions/nddscore-import.R`:

```r
# NDDScore importer — pure, unit-testable functions.
# Fetch / download / verify / extract / parse / load / validate a Zenodo release.
# No DB writes here; no secrets are logged. See db/migrations/023 for the target schema.

#' Default HTTP JSON GET used by nddscore_fetch_zenodo_metadata.
#' Separated out so tests inject a stub instead.
.nddscore_http_get_json <- function(url) {
  resp <- httr2::request(url) |>
    httr2::req_retry(max_tries = 4, is_transient = ~ httr2::resp_status(.x) %in% c(429, 503, 504)) |>
    httr2::req_timeout(30) |>
    httr2::req_perform()
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

#' Fetch Zenodo record metadata and locate the release archive file entry.
#'
#' @param record_id Zenodo numeric record id (string or numeric).
#' @param http_get Function(url) returning the parsed record JSON as a list.
#' @return Named list: record_id, record_url, version, version_doi, concept_doi,
#'   archive_name, archive_bytes, archive_md5, content_url.
nddscore_fetch_zenodo_metadata <- function(record_id, http_get = .nddscore_http_get_json) {
  record_id <- as.character(record_id)[[1]]
  url <- paste0("https://zenodo.org/api/records/", record_id)
  record <- http_get(url)

  files <- record$files
  if (is.null(files) || length(files) == 0) {
    stop("Zenodo record has no files; cannot locate NDDScore archive", call. = FALSE)
  }
  is_archive <- vapply(files, function(f) {
    grepl("\\.tar\\.gz$", f$key %||% "", ignore.case = TRUE)
  }, logical(1))
  if (!any(is_archive)) {
    stop("Zenodo record contains no .tar.gz archive file entry", call. = FALSE)
  }
  entry <- files[is_archive][[1]]

  checksum <- entry$checksum %||% ""
  archive_md5 <- sub("^md5:", "", checksum)

  list(
    record_id = record_id,
    record_url = record$links$self_html %||%
      paste0("https://zenodo.org/records/", record_id),
    version = record$metadata$version %||% NA_character_,
    version_doi = record$doi %||% NA_character_,
    concept_doi = record$conceptdoi %||% NA_character_,
    archive_name = entry$key,
    archive_bytes = as.numeric(entry$size %||% NA),
    archive_md5 = archive_md5,
    content_url = entry$links$self
  )
}
```

If `%||%` is not already a global helper, confirm with `grep -rn '"%||%"' api/functions/` — it is widely used in the codebase (e.g. `middleware.R`). If sourced order makes it unavailable in this file at test time, add at the top of `nddscore-import.R`: `` `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a `` — but only if the grep shows no global definition.

- [ ] **Step 4: Run the test — verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-import.R')"`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add api/functions/nddscore-import.R api/tests/testthat/test-nddscore-import.R
git commit -m "feat(api): NDDScore Zenodo metadata fetch (TDD)"
```

---

### Task 4: `nddscore_download_archive()` + `nddscore_verify_archive_checksum()`

**Files:**
- Modify: `api/functions/nddscore-import.R` (append)
- Modify: `api/tests/testthat/test-nddscore-import.R` (append)

`nddscore_verify_archive_checksum(path, expected_md5)` returns `TRUE` on match and `stop()`s on mismatch. `nddscore_download_archive(url, dest, http_download = ...)` writes the archive to `dest` (download injected for tests).

- [ ] **Step 1: Write the failing tests** — append to `test-nddscore-import.R`:

```r
describe("nddscore_verify_archive_checksum", {
  it("passes when md5 matches", {
    path <- fixture_archive()
    good_md5 <- digest::digest(file = path, algo = "md5")
    expect_true(nddscore_verify_archive_checksum(path, good_md5))
  })

  it("stops with a clear error on md5 mismatch", {
    expect_error(
      nddscore_verify_archive_checksum(fixture_archive(),
                                       paste(rep("0", 32), collapse = "")),
      "checksum"
    )
  })
})

describe("nddscore_download_archive", {
  it("writes the archive to the destination path", {
    src <- fixture_archive()
    dest <- file.path(tempdir(), "ndd_dl_test.tar.gz")
    on.exit(unlink(dest), add = TRUE)
    stub_download <- function(url, destfile) file.copy(src, destfile, overwrite = TRUE)

    out <- nddscore_download_archive("https://example/content", dest,
                                     http_download = stub_download)
    expect_equal(out, dest)
    expect_true(file.exists(dest))
    expect_gt(file.size(dest), 0)
  })
})
```

- [ ] **Step 2: Run — verify fail**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-import.R')"`
Expected: FAIL — functions not found.

- [ ] **Step 3: Implement** — append to `nddscore-import.R`:

```r
#' Verify a downloaded archive against the Zenodo-published MD5.
#' @return TRUE on match; stops with a clear error on mismatch.
nddscore_verify_archive_checksum <- function(path, expected_md5) {
  if (!file.exists(path)) {
    stop("NDDScore archive not found for checksum verification", call. = FALSE)
  }
  actual <- digest::digest(file = path, algo = "md5")
  expected <- tolower(sub("^md5:", "", expected_md5 %||% ""))
  if (!identical(tolower(actual), expected)) {
    stop(sprintf(
      "NDDScore archive checksum mismatch (expected %s, got %s)",
      expected, actual
    ), call. = FALSE)
  }
  TRUE
}

#' Default binary downloader; tests inject a stub.
.nddscore_http_download <- function(url, destfile) {
  resp <- httr2::request(url) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_timeout(300) |>
    httr2::req_perform(path = destfile)
  invisible(destfile)
}

#' Download the release archive to a destination path.
#' @return The destination path.
nddscore_download_archive <- function(url, dest, http_download = .nddscore_http_download) {
  if (is.null(url) || !nzchar(url)) {
    stop("NDDScore archive download URL is missing", call. = FALSE)
  }
  http_download(url, dest)
  if (!file.exists(dest) || file.size(dest) == 0) {
    stop("NDDScore archive download produced an empty file", call. = FALSE)
  }
  dest
}
```

- [ ] **Step 4: Run — verify pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-import.R')"`
Expected: PASS (all tests so far).

- [ ] **Step 5: Commit**

```bash
git add api/functions/nddscore-import.R api/tests/testthat/test-nddscore-import.R
git commit -m "feat(api): NDDScore archive download + md5 verification (TDD)"
```

---

### Task 5: `nddscore_extract_and_verify()`

**Files:**
- Modify: `api/functions/nddscore-import.R` (append)
- Modify: `api/tests/testthat/test-nddscore-import.R` (append)

Extracts the `.tar.gz` to a temp dir, finds the `sysndd_prediction_release` directory, and verifies every file listed in the bundled inner `checksums.sha256` against its sha256. Returns the path to the release directory.

- [ ] **Step 1: Write the failing tests** — append to `test-nddscore-import.R`:

```r
describe("nddscore_extract_and_verify", {
  it("extracts and verifies the inner checksums.sha256", {
    rel_dir <- nddscore_extract_and_verify(fixture_archive())
    expect_true(dir.exists(rel_dir))
    expect_true(file.exists(file.path(rel_dir, "nddscore_release.json")))
    expect_true(file.exists(file.path(rel_dir, "nddscore_gene_predictions.tsv")))
  })

  it("stops when a bundled sha256 does not match", {
    expect_error(
      nddscore_extract_and_verify(fixture_archive("nddscore_fixture_corrupt_sha256.tar.gz")),
      "sha256|checksum"
    )
  })
})
```

- [ ] **Step 2: Run — verify fail.** Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-import.R')"` → FAIL, function not found.

- [ ] **Step 3: Implement** — append to `nddscore-import.R`:

```r
#' Extract the release archive and verify the bundled inner checksums.sha256.
#'
#' @param archive_path Path to the .tar.gz.
#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
#' @return Path to the `sysndd_prediction_release` directory inside the extraction.
nddscore_extract_and_verify <- function(archive_path, exdir = NULL) {
  if (is.null(exdir)) {
    exdir <- file.path(tempdir(), paste0("ndd_extract_", as.integer(runif(1, 1, 1e9))))
  }
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  utils::untar(archive_path, exdir = exdir)

  rel_candidates <- list.files(exdir, pattern = "^sysndd_prediction_release$",
                               recursive = TRUE, include.dirs = TRUE,
                               full.names = TRUE)
  if (length(rel_candidates) == 0) {
    stop("Archive does not contain a sysndd_prediction_release directory", call. = FALSE)
  }
  rel_dir <- rel_candidates[[1]]

  sha_file <- file.path(rel_dir, "checksums.sha256")
  if (!file.exists(sha_file)) {
    stop("Archive release directory has no bundled checksums.sha256", call. = FALSE)
  }
  sha_lines <- readLines(sha_file, warn = FALSE)
  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
  for (line in sha_lines) {
    parts <- strsplit(trimws(line), "\\s+")[[1]]
    expected_sha <- parts[[1]]
    rel_name <- parts[[length(parts)]]
    target <- file.path(rel_dir, rel_name)
    if (!file.exists(target)) {
      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name),
           call. = FALSE)
    }
    actual_sha <- digest::digest(file = target, algo = "sha256")
    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name),
           call. = FALSE)
    }
  }
  rel_dir
}
```

- [ ] **Step 4: Run — verify pass.** Run the test file → PASS.

- [ ] **Step 5: Commit**

```bash
git add api/functions/nddscore-import.R api/tests/testthat/test-nddscore-import.R
git commit -m "feat(api): NDDScore archive extraction + sha256 verification (TDD)"
```

---

### Task 6: `nddscore_parse_release_json()` + `nddscore_load_tsvs()`

**Files:**
- Modify: `api/functions/nddscore-import.R` (append)
- Modify: `api/tests/testthat/test-nddscore-import.R` (append)

`nddscore_parse_release_json(dir)` parses `nddscore_release.json` into a one-row metadata list. `nddscore_load_tsvs(dir)` loads the three TSVs via `readr` into a list of three tibbles (`gene`, `hpo`, `term`).

The real release-file TSV headers (verbatim, used as the schema contract in Task 7):
- gene: `release_id, hgnc_id, gene_symbol, ensembl_gene_id, ndd_score, ndd_score_std, ndd_score_iqr, bag_agreement, rank, percentile, risk_tier, confidence_tier, known_sysndd_gene, model_split, inheritance_ad_probability, inheritance_ar_probability, inheritance_xld_probability, inheritance_xlr_probability, top_inheritance_mode, called_inheritance_modes, n_predicted_hpo, top_hpo_predictions_json, shap_clinical, shap_constraint, shap_expression, shap_network, shap_conservation, shap_other, dominant_shap_group, top_features_json, prediction_note`
- hpo: `release_id, hgnc_id, gene_symbol, phenotype_id, phenotype_name, probability, rank_for_gene, passes_default_threshold, term_auc_roc, term_auc_pr, term_training_support`
- term: `release_id, phenotype_id, phenotype_name, term_auc_roc, term_auc_pr, term_training_support`

- [ ] **Step 1: Write the failing tests** — append:

```r
describe("nddscore_parse_release_json", {
  it("parses release metadata from the fixture", {
    rel_dir <- nddscore_extract_and_verify(fixture_archive())
    meta <- nddscore_parse_release_json(rel_dir)

    expect_equal(meta$release_id, "ndd_fixture_release")
    expect_equal(meta$score_schema_version, "1.0.0")
    expect_equal(meta$n_genes, 3L)
    expect_equal(meta$n_hpo_predictions, 4L)
    expect_equal(meta$n_hpo_terms, 2L)
    expect_equal(meta$hpo_threshold, 0.5)
    # JSON metric blocks are kept as compact JSON strings for verbatim DB storage.
    expect_type(meta$ndd_performance_json, "character")
    expect_match(meta$ndd_performance_json, "auc_roc")
  })
})

describe("nddscore_load_tsvs", {
  it("loads the three TSVs into tibbles", {
    rel_dir <- nddscore_extract_and_verify(fixture_archive())
    frames <- nddscore_load_tsvs(rel_dir)

    expect_named(frames, c("gene", "hpo", "term"), ignore.order = TRUE)
    expect_equal(nrow(frames$gene), 3L)
    expect_equal(nrow(frames$hpo), 4L)
    expect_equal(nrow(frames$term), 2L)
    expect_true("ndd_score" %in% names(frames$gene))
    expect_true("probability" %in% names(frames$hpo))
  })
})
```

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement** — append to `nddscore-import.R`:

```r
#' Parse nddscore_release.json into a one-row metadata list.
#' JSON metric sub-objects are re-serialized to compact JSON strings so they can
#' be stored verbatim in the JSON columns of nddscore_release.
nddscore_parse_release_json <- function(dir) {
  path <- file.path(dir, "nddscore_release.json")
  if (!file.exists(path)) {
    stop("nddscore_release.json not found in release directory", call. = FALSE)
  }
  raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)

  as_json_string <- function(x) {
    if (is.null(x)) return(NA_character_)
    jsonlite::toJSON(x, auto_unbox = TRUE, null = "null")
  }
  num <- function(x) if (is.null(x)) NA_real_ else as.numeric(x)
  int <- function(x) if (is.null(x)) NA_integer_ else as.integer(x)
  chr <- function(x) if (is.null(x)) NA_character_ else as.character(x)

  list(
    release_id = chr(raw$release_id),
    score_schema_version = chr(raw$score_schema_version),
    release_created_at = chr(raw$created_at),
    n_genes = int(raw$n_genes),
    n_hpo_predictions = int(raw$n_hpo_predictions),
    n_hpo_terms = int(raw$n_hpo_terms),
    n_features = int(raw$n_features),
    hpo_threshold = num(raw$hpo_threshold),
    calibration_method = chr(raw$calibration_method),
    ndd_model_created_at = chr(raw$ndd_model_created_at),
    phenotype_model_created_at = chr(raw$phenotype_model_created_at),
    inheritance_model_created_at = chr(raw$inheritance_model_created_at),
    ndd_performance_json = as_json_string(raw$ndd_performance_json),
    phenotype_performance_json = as_json_string(raw$phenotype_performance_json),
    inheritance_performance_json = as_json_string(raw$inheritance_performance_json),
    data_versions_json = as_json_string(raw$data_versions_json),
    artifact_hashes_json = as_json_string(raw$artifact_hashes_json)
  )
}

#' Load the three release TSVs into a named list of tibbles.
nddscore_load_tsvs <- function(dir) {
  read_one <- function(name) {
    path <- file.path(dir, name)
    if (!file.exists(path)) {
      stop(sprintf("Release TSV '%s' not found", name), call. = FALSE)
    }
    readr::read_tsv(path, show_col_types = FALSE, progress = FALSE)
  }
  list(
    gene = read_one("nddscore_gene_predictions.tsv"),
    hpo = read_one("nddscore_hpo_predictions.tsv"),
    term = read_one("nddscore_hpo_terms.tsv")
  )
}
```

- [ ] **Step 4: Run — verify pass.**

- [ ] **Step 5: Commit**

```bash
git add api/functions/nddscore-import.R api/tests/testthat/test-nddscore-import.R
git commit -m "feat(api): NDDScore release JSON + TSV loading (TDD)"
```

---

### Task 7: `nddscore_validate()`

**Files:**
- Modify: `api/functions/nddscore-import.R` (append)
- Modify: `api/tests/testthat/test-nddscore-import.R` (append)

`nddscore_validate(release, frames)` runs every check from spec §5.2: required columns present on each frame; row counts match `n_genes`/`n_hpo_predictions`/`n_hpo_terms`; JSON columns parse; orphan-row checks (every `hpo$hgnc_id` exists in `gene`; every `hpo$phenotype_id` exists in `term`). Returns `list(ok = TRUE, messages = character(0))` on success; on failure `list(ok = FALSE, messages = <one per problem>)`. It never `stop()`s — the caller decides.

- [ ] **Step 1: Write the failing tests** — append:

```r
describe("nddscore_validate", {
  load_fixture <- function() {
    rel_dir <- nddscore_extract_and_verify(fixture_archive())
    list(release = nddscore_parse_release_json(rel_dir),
         frames = nddscore_load_tsvs(rel_dir))
  }

  it("passes for the valid fixture", {
    fx <- load_fixture()
    result <- nddscore_validate(fx$release, fx$frames)
    expect_true(result$ok)
    expect_length(result$messages, 0)
  })

  it("fails when a gene row count disagrees with n_genes", {
    fx <- load_fixture()
    fx$frames$gene <- fx$frames$gene[1, ]
    result <- nddscore_validate(fx$release, fx$frames)
    expect_false(result$ok)
    expect_true(any(grepl("n_genes|gene row count", result$messages)))
  })

  it("fails when a required column is missing", {
    fx <- load_fixture()
    fx$frames$gene$ndd_score <- NULL
    result <- nddscore_validate(fx$release, fx$frames)
    expect_false(result$ok)
    expect_true(any(grepl("ndd_score", result$messages)))
  })

  it("fails on an orphan HPO prediction row", {
    fx <- load_fixture()
    fx$frames$hpo$hgnc_id[1] <- "HGNC:0000000"
    result <- nddscore_validate(fx$release, fx$frames)
    expect_false(result$ok)
    expect_true(any(grepl("orphan|HGNC:0000000", result$messages)))
  })

  it("fails on invalid JSON in a JSON column", {
    fx <- load_fixture()
    fx$frames$gene$called_inheritance_modes[1] <- "{not json"
    result <- nddscore_validate(fx$release, fx$frames)
    expect_false(result$ok)
    expect_true(any(grepl("JSON|called_inheritance_modes", result$messages)))
  })
})
```

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement** — append to `nddscore-import.R`:

```r
# Required columns per frame — the schema contract (matches db/migrations/023).
.nddscore_required_columns <- list(
  gene = c("release_id", "hgnc_id", "gene_symbol", "ndd_score", "rank",
           "percentile", "risk_tier", "confidence_tier", "n_predicted_hpo"),
  hpo = c("release_id", "hgnc_id", "phenotype_id", "phenotype_name",
          "probability", "rank_for_gene", "passes_default_threshold"),
  term = c("release_id", "phenotype_id", "phenotype_name")
)
# JSON-typed columns that must contain parseable JSON when non-NA.
.nddscore_json_columns <- list(
  gene = c("called_inheritance_modes", "top_hpo_predictions_json", "top_features_json")
)

#' Validate a parsed release + loaded frames against the schema contract.
#' @return list(ok = logical, messages = character()).
nddscore_validate <- function(release, frames) {
  msgs <- character(0)

  for (frame_name in names(.nddscore_required_columns)) {
    required <- .nddscore_required_columns[[frame_name]]
    present <- names(frames[[frame_name]])
    missing <- setdiff(required, present)
    if (length(missing) > 0) {
      msgs <- c(msgs, sprintf("Frame '%s' missing required column(s): %s",
                              frame_name, paste(missing, collapse = ", ")))
    }
  }

  count_check <- function(frame_name, expected, label) {
    actual <- nrow(frames[[frame_name]])
    if (!is.na(expected) && actual != expected) {
      msgs <<- c(msgs, sprintf("%s row count %d disagrees with %s (%d)",
                               frame_name, actual, label, expected))
    }
  }
  count_check("gene", release$n_genes, "n_genes")
  count_check("hpo", release$n_hpo_predictions, "n_hpo_predictions")
  count_check("term", release$n_hpo_terms, "n_hpo_terms")

  for (col in .nddscore_json_columns$gene) {
    if (col %in% names(frames$gene)) {
      vals <- frames$gene[[col]]
      bad <- vapply(vals, function(v) {
        if (is.na(v) || !nzchar(v)) return(FALSE)
        !isTRUE(jsonlite::validate(v))
      }, logical(1))
      if (any(bad)) {
        msgs <- c(msgs, sprintf("Column '%s' has %d invalid JSON value(s)",
                                col, sum(bad)))
      }
    }
  }

  if (all(c("hgnc_id") %in% names(frames$hpo)) &&
      "hgnc_id" %in% names(frames$gene)) {
    orphan_genes <- setdiff(unique(frames$hpo$hgnc_id),
                            unique(frames$gene$hgnc_id))
    if (length(orphan_genes) > 0) {
      msgs <- c(msgs, sprintf(
        "Orphan HPO prediction rows: hgnc_id not in gene predictions: %s",
        paste(utils::head(orphan_genes, 5), collapse = ", ")))
    }
  }
  if ("phenotype_id" %in% names(frames$hpo) &&
      "phenotype_id" %in% names(frames$term)) {
    orphan_terms <- setdiff(unique(frames$hpo$phenotype_id),
                            unique(frames$term$phenotype_id))
    if (length(orphan_terms) > 0) {
      msgs <- c(msgs, sprintf(
        "Orphan HPO prediction rows: phenotype_id not in term metadata: %s",
        paste(utils::head(orphan_terms, 5), collapse = ", ")))
    }
  }

  list(ok = length(msgs) == 0, messages = msgs)
}
```

- [ ] **Step 4: Run — verify pass** (all `test-nddscore-import.R` tests green).

- [ ] **Step 5: Commit**

```bash
git add api/functions/nddscore-import.R api/tests/testthat/test-nddscore-import.R
git commit -m "feat(api): NDDScore release validation (TDD)"
```

---

# Phase 3 — Backend DB write layer, async job, repository, endpoints

Phase 3 tasks that touch the DB use a real test database. Tests start with `skip_if_no_test_db()` and assume migration 023 has been applied to the test DB (the migration runner does this on startup; `make test-api` provisions it). DB-write tests clean the `nddscore_*` tables themselves (FK `ON DELETE CASCADE` from `nddscore_release` clears children) rather than relying on transaction rollback, because the activation step uses its own explicit transaction.

### Task 8: NDDScore DB write helpers + test helper

**Files:**
- Modify: `api/functions/nddscore-import.R` (append the DB-write section)
- Create: `api/tests/testthat/helper-nddscore.R`
- Create: `api/tests/testthat/test-nddscore-job.R`

DB-write helpers (advisory lock, release-row upsert, prediction inserts, DB row-count re-check, atomic activation, failure marking). These take an explicit `conn` so they are testable against the test DB.

- [ ] **Step 1: Write the test helper**

Create `api/tests/testthat/helper-nddscore.R`:

```r
# Shared helpers for NDDScore DB-write, job, repository, and endpoint tests.

# Path to a committed fixture archive.
nddscore_fixture_path <- function(name = "nddscore_fixture_release.tar.gz") {
  testthat::test_path("fixtures", "nddscore", name)
}

# The valid fixture archive's md5 — recomputed each call so it never goes stale
# if the fixture is regenerated. Used as the "expected good md5" in job tests.
nddscore_fixture_good_md5 <- function() {
  digest::digest(file = nddscore_fixture_path(), algo = "md5")
}

# Remove all NDDScore rows (release cascade clears gene/hpo/term children).
nddscore_clean_tables <- function(conn) {
  DBI::dbExecute(conn, "DELETE FROM nddscore_release")
  invisible(TRUE)
}

# Build an importer dependency list whose Zenodo calls are fully stubbed and
# whose download copies the committed fixture archive. record_id is cosmetic.
nddscore_stub_deps <- function(fixture = "nddscore_fixture_release.tar.gz",
                               archive_md5 = NULL) {
  src <- nddscore_fixture_path(fixture)
  md5 <- archive_md5 %||% digest::digest(file = src, algo = "md5")
  list(
    fetch_metadata = function(record_id) list(
      record_id = as.character(record_id),
      record_url = "https://zenodo.org/records/20258027",
      version = "2026.05.17",
      version_doi = "10.5281/zenodo.20258027",
      concept_doi = "10.5281/zenodo.20258026",
      archive_name = "nddscore_sysndd_prediction_release_2026-05-17.tar.gz",
      archive_bytes = file.size(src),
      archive_md5 = md5,
      content_url = "https://zenodo.org/api/records/20258027/files/x/content"
    ),
    download = function(url, dest) file.copy(src, dest, overwrite = TRUE)
  )
}
```

- [ ] **Step 2: Write failing tests** for the DB-write helpers in `test-nddscore-job.R`:

```r
# Tests for NDDScore DB-write helpers and the async-job orchestration.
source_api_file("functions/nddscore-import.R", local = FALSE)

describe("nddscore_release_exists", {
  it("reports existence and active state", {
    skip_if_no_test_db()
    conn <- get_test_db_connection()
    withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)

    expect_false(nddscore_release_exists(conn, "ndd_fixture_release")$exists)

    nddscore_upsert_release_row(conn, list(release_id = "ndd_fixture_release",
      score_schema_version = "1.0.0", n_genes = 3L, n_hpo_predictions = 4L,
      n_hpo_terms = 2L, n_features = 48L, hpo_threshold = 0.5),
      import_job_id = "job-1", imported_by = NULL)

    state <- nddscore_release_exists(conn, "ndd_fixture_release")
    expect_true(state$exists)
    expect_false(state$is_active)
    nddscore_clean_tables(conn)
  })
})

describe("nddscore_insert_predictions + nddscore_count_release_rows", {
  it("inserts gene/hpo/term rows and counts them", {
    skip_if_no_test_db()
    conn <- get_test_db_connection()
    withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)

    rel_dir <- nddscore_extract_and_verify(nddscore_fixture_path())
    release <- nddscore_parse_release_json(rel_dir)
    frames <- nddscore_load_tsvs(rel_dir)

    nddscore_upsert_release_row(conn, release, import_job_id = "job-1",
                                imported_by = NULL)
    nddscore_insert_predictions(conn, release$release_id, frames)

    counts <- nddscore_count_release_rows(conn, release$release_id)
    expect_equal(counts$gene, 3L)
    expect_equal(counts$hpo, 4L)
    expect_equal(counts$term, 2L)
    nddscore_clean_tables(conn)
  })
})

describe("nddscore_activate_release", {
  it("atomically switches the active release and supersedes the prior one", {
    skip_if_no_test_db()
    conn <- get_test_db_connection()
    withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)

    base <- list(score_schema_version = "1.0.0", n_genes = 0L,
                 n_hpo_predictions = 0L, n_hpo_terms = 0L, n_features = 48L,
                 hpo_threshold = 0.5)
    nddscore_upsert_release_row(conn, c(base, list(release_id = "rel_old")),
                                import_job_id = "j0", imported_by = NULL)
    nddscore_activate_release(conn, "rel_old")
    nddscore_upsert_release_row(conn, c(base, list(release_id = "rel_new")),
                                import_job_id = "j1", imported_by = NULL)
    nddscore_activate_release(conn, "rel_new")

    rows <- DBI::dbGetQuery(conn,
      "SELECT release_id, is_active, import_status FROM nddscore_release ORDER BY release_id")
    expect_equal(rows$is_active[rows$release_id == "rel_new"], 1L)
    expect_equal(rows$is_active[rows$release_id == "rel_old"], 0L)
    expect_equal(rows$import_status[rows$release_id == "rel_old"], "superseded")
    expect_equal(rows$import_status[rows$release_id == "rel_new"], "active")
    nddscore_clean_tables(conn)
  })

  it("the active_release_slot unique key rejects two active releases", {
    skip_if_no_test_db()
    conn <- get_test_db_connection()
    withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)

    base <- list(score_schema_version = "1.0.0", n_genes = 0L,
                 n_hpo_predictions = 0L, n_hpo_terms = 0L, n_features = 48L,
                 hpo_threshold = 0.5)
    nddscore_upsert_release_row(conn, c(base, list(release_id = "rel_a")),
                                import_job_id = "ja", imported_by = NULL)
    nddscore_upsert_release_row(conn, c(base, list(release_id = "rel_b")),
                                import_job_id = "jb", imported_by = NULL)
    DBI::dbExecute(conn, "UPDATE nddscore_release SET is_active = 1 WHERE release_id = 'rel_a'")
    expect_error(
      DBI::dbExecute(conn, "UPDATE nddscore_release SET is_active = 1 WHERE release_id = 'rel_b'"),
      "Duplicate|active_release_slot"
    )
    nddscore_clean_tables(conn)
  })
})

describe("nddscore import advisory lock", {
  it("a second connection cannot acquire the held lock", {
    skip_if_no_test_db()
    conn1 <- get_test_db_connection()
    conn2 <- get_test_db_connection()
    withr::defer(DBI::dbDisconnect(conn1))
    withr::defer(DBI::dbDisconnect(conn2))

    expect_true(nddscore_acquire_import_lock(conn1))
    expect_false(nddscore_try_acquire_import_lock(conn2))
    nddscore_release_import_lock(conn1)
    expect_true(nddscore_acquire_import_lock(conn2))
    nddscore_release_import_lock(conn2)
  })
})
```

- [ ] **Step 3: Run — verify fail.** Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-job.R')"` → FAIL, helpers not found (or skipped if no test DB — provision one).

- [ ] **Step 4: Implement the DB-write section** — append to `api/functions/nddscore-import.R`:

```r
# ---------------------------------------------------------------------------
# NDDScore DB-write helpers. These take an explicit DBI connection so the
# async-job handler can hold one connection for the advisory lock + all writes,
# and so they are testable against the test database.
# ---------------------------------------------------------------------------

.NDDSCORE_IMPORT_LOCK <- "nddscore_import"

#' Try to acquire the NDDScore import advisory lock without waiting.
#' @return TRUE if acquired, FALSE if held elsewhere.
nddscore_try_acquire_import_lock <- function(conn) {
  res <- DBI::dbGetQuery(conn,
    "SELECT GET_LOCK(?, 0) AS acquired", params = list(.NDDSCORE_IMPORT_LOCK))
  isTRUE(!is.na(res$acquired[[1]]) && res$acquired[[1]] == 1)
}

#' Acquire the NDDScore import advisory lock or stop with a clear error.
nddscore_acquire_import_lock <- function(conn) {
  if (!nddscore_try_acquire_import_lock(conn)) {
    stop("Another NDDScore import is already running", call. = FALSE)
  }
  TRUE
}

#' Release the NDDScore import advisory lock (no-op if not held).
nddscore_release_import_lock <- function(conn) {
  invisible(DBI::dbGetQuery(conn,
    "SELECT RELEASE_LOCK(?) AS released", params = list(.NDDSCORE_IMPORT_LOCK)))
}

#' Existence + active state of a release row.
nddscore_release_exists <- function(conn, release_id) {
  row <- DBI::dbGetQuery(conn,
    "SELECT is_active FROM nddscore_release WHERE release_id = ?",
    params = list(release_id))
  if (nrow(row) == 0) return(list(exists = FALSE, is_active = FALSE))
  list(exists = TRUE, is_active = isTRUE(row$is_active[[1]] == 1))
}

#' Insert or replace the (always inactive) release row for an import.
#' is_active is forced to 0; activation happens only via nddscore_activate_release.
nddscore_upsert_release_row <- function(conn, release, import_job_id,
                                        imported_by = NULL, source = list(),
                                        import_status = "importing") {
  DBI::dbExecute(conn, "DELETE FROM nddscore_release WHERE release_id = ?",
                 params = list(release$release_id))
  sql <- paste(
    "INSERT INTO nddscore_release",
    "(release_id, score_schema_version, version, release_created_at,",
    " n_genes, n_hpo_predictions, n_hpo_terms, n_features, hpo_threshold,",
    " calibration_method, ndd_model_created_at, phenotype_model_created_at,",
    " inheritance_model_created_at, ndd_performance_json,",
    " phenotype_performance_json, inheritance_performance_json,",
    " data_versions_json, artifact_hashes_json, zenodo_record_url,",
    " version_doi, concept_doi, source_record_id, source_archive_name,",
    " source_archive_checksum, source_archive_bytes, is_active,",
    " import_status, imported_by, import_job_id, import_started_at)",
    "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,0,?,?,?,NOW(6))"
  )
  params <- list(
    release$release_id, release$score_schema_version, source$version %||% NA,
    release$release_created_at %||% NA,
    release$n_genes, release$n_hpo_predictions, release$n_hpo_terms,
    release$n_features, release$hpo_threshold,
    release$calibration_method %||% NA, release$ndd_model_created_at %||% NA,
    release$phenotype_model_created_at %||% NA,
    release$inheritance_model_created_at %||% NA,
    release$ndd_performance_json %||% NA,
    release$phenotype_performance_json %||% NA,
    release$inheritance_performance_json %||% NA,
    release$data_versions_json %||% NA, release$artifact_hashes_json %||% NA,
    source$record_url %||% NA, source$version_doi %||% NA,
    source$concept_doi %||% NA, source$record_id %||% NA,
    source$archive_name %||% NA, source$archive_md5 %||% NA,
    source$archive_bytes %||% NA, import_status,
    if (is.null(imported_by)) NA else as.integer(imported_by), import_job_id
  )
  DBI::dbExecute(conn, sql, params = unname(params))
  invisible(TRUE)
}

#' Insert gene, term, and HPO-prediction rows for a release. Caller has already
#' inserted the release row. Done in one transaction; partial inserts roll back.
nddscore_insert_predictions <- function(conn, release_id, frames) {
  align <- function(df, table) {
    cols <- DBI::dbListFields(conn, table)
    df <- df[, intersect(cols, names(df)), drop = FALSE]
    df$release_id <- release_id
    df
  }
  DBI::dbWithTransaction(conn, {
    DBI::dbAppendTable(conn, "nddscore_gene_prediction",
                       align(frames$gene, "nddscore_gene_prediction"))
    DBI::dbAppendTable(conn, "nddscore_hpo_term",
                       align(frames$term, "nddscore_hpo_term"))
    DBI::dbAppendTable(conn, "nddscore_hpo_prediction",
                       align(frames$hpo, "nddscore_hpo_prediction"))
  })
  invisible(TRUE)
}

#' Count gene/hpo/term rows actually stored for a release (DB-side re-validation).
nddscore_count_release_rows <- function(conn, release_id) {
  one <- function(table) {
    DBI::dbGetQuery(conn,
      sprintf("SELECT COUNT(*) AS n FROM %s WHERE release_id = ?", table),
      params = list(release_id))$n[[1]]
  }
  list(gene = as.integer(one("nddscore_gene_prediction")),
       hpo = as.integer(one("nddscore_hpo_prediction")),
       term = as.integer(one("nddscore_hpo_term")))
}

#' Mark a release validated (still inactive) once DB counts re-check.
nddscore_mark_release_validated <- function(conn, release_id) {
  DBI::dbExecute(conn,
    "UPDATE nddscore_release SET import_status = 'validated' WHERE release_id = ?",
    params = list(release_id))
  invisible(TRUE)
}

#' Atomically activate a release: supersede the prior active one and promote this
#' one, in a single transaction. The active_release_slot unique key guarantees
#' the switch can never leave two active releases.
nddscore_activate_release <- function(conn, release_id) {
  DBI::dbWithTransaction(conn, {
    DBI::dbExecute(conn, paste(
      "UPDATE nddscore_release",
      "SET is_active = 0, import_status = 'superseded'",
      "WHERE is_active = 1 AND release_id <> ?"), params = list(release_id))
    DBI::dbExecute(conn, paste(
      "UPDATE nddscore_release",
      "SET is_active = 1, import_status = 'active', activated_at = NOW(6),",
      "    import_completed_at = NOW(6), last_error_message = NULL",
      "WHERE release_id = ?"), params = list(release_id))
  })
  invisible(TRUE)
}

#' Mark a release failed, recording the error message. Never raises.
nddscore_mark_release_failed <- function(conn, release_id, message) {
  tryCatch(
    DBI::dbExecute(conn, paste(
      "UPDATE nddscore_release",
      "SET import_status = 'failed', is_active = 0,",
      "    last_error_message = ?, import_completed_at = NOW(6)",
      "WHERE release_id = ?"),
      params = list(substr(message, 1, 2000), release_id)),
    error = function(e) NULL
  )
  invisible(TRUE)
}

#' Delete an existing inactive release's rows so a prior failed attempt at the
#' same release_id can be retried. Refuses to touch an active release.
nddscore_delete_inactive_release <- function(conn, release_id) {
  state <- nddscore_release_exists(conn, release_id)
  if (state$exists && state$is_active) {
    stop("Refusing to delete an active NDDScore release", call. = FALSE)
  }
  DBI::dbExecute(conn, "DELETE FROM nddscore_release WHERE release_id = ?",
                 params = list(release_id))
  invisible(TRUE)
}
```

- [ ] **Step 5: Run — verify pass.** Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-job.R')"` → PASS (all describe blocks).

- [ ] **Step 6: Commit**

```bash
git add api/functions/nddscore-import.R api/tests/testthat/helper-nddscore.R api/tests/testthat/test-nddscore-job.R
git commit -m "feat(api): NDDScore DB-write helpers + advisory lock (TDD)"
```

---

### Task 9: `nddscore_run_import()` orchestration + async-job handler

**Files:**
- Modify: `api/functions/nddscore-import.R` (append the orchestration function)
- Modify: `api/functions/async-job-handlers.R` (add handler + registry entry)
- Modify: `api/tests/testthat/test-nddscore-job.R` (append)

`nddscore_run_import(conn, record_id, validate_only, imported_by, job_id, deps, progress)` is the testable core implementing spec §5.3 steps 1-12. The handler `.async_job_run_nddscore_import` is a thin adapter: checks out a pool connection, holds the advisory lock, builds real Zenodo deps, calls `nddscore_run_import`.

- [ ] **Step 1: Write failing tests** — append to `test-nddscore-job.R`:

```r
describe("nddscore_run_import", {
  run <- function(conn, validate_only = FALSE, deps = nddscore_stub_deps(),
                  job_id = "job-test", record_id = "20258027") {
    nddscore_run_import(conn, record_id = record_id, validate_only = validate_only,
                        imported_by = NULL, job_id = job_id, deps = deps,
                        progress = function(...) invisible(NULL))
  }

  it("validate_only writes nothing to prediction tables", {
    skip_if_no_test_db()
    conn <- get_test_db_connection(); withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)
    result <- run(conn, validate_only = TRUE)
    expect_true(result$validated)
    expect_false(result$activated)
    counts <- nddscore_count_release_rows(conn, "ndd_fixture_release")
    expect_equal(counts$gene, 0L)
    expect_false(nddscore_release_exists(conn, "ndd_fixture_release")$exists)
    nddscore_clean_tables(conn)
  })

  it("a full import activates the release at the final step", {
    skip_if_no_test_db()
    conn <- get_test_db_connection(); withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)
    result <- run(conn, validate_only = FALSE)
    expect_true(result$activated)
    expect_equal(result$gene_rows, 3L)
    expect_equal(result$hpo_rows, 4L)
    expect_equal(result$term_rows, 2L)
    state <- nddscore_release_exists(conn, "ndd_fixture_release")
    expect_true(state$is_active)
    nddscore_clean_tables(conn)
  })

  it("a checksum failure leaves the previous active release active", {
    skip_if_no_test_db()
    conn <- get_test_db_connection(); withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)
    run(conn, validate_only = FALSE)  # rel ndd_fixture_release now active

    bad_deps <- nddscore_stub_deps(archive_md5 = paste(rep("0", 32), collapse = ""))
    expect_error(
      nddscore_run_import(conn, record_id = "20258027", validate_only = FALSE,
        imported_by = NULL, job_id = "job-bad", deps = bad_deps,
        progress = function(...) invisible(NULL)),
      "checksum"
    )
    state <- nddscore_release_exists(conn, "ndd_fixture_release")
    expect_true(state$is_active)  # still serving
    nddscore_clean_tables(conn)
  })

  it("refuses to re-import the currently active release_id", {
    skip_if_no_test_db()
    conn <- get_test_db_connection(); withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)
    run(conn, validate_only = FALSE)
    expect_error(run(conn, validate_only = FALSE, job_id = "job-2"),
                 "active")
    nddscore_clean_tables(conn)
  })

  it("re-importing a previously failed inactive release_id succeeds", {
    skip_if_no_test_db()
    conn <- get_test_db_connection(); withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)
    # Seed an inactive failed release row with the same id.
    nddscore_upsert_release_row(conn, list(release_id = "ndd_fixture_release",
      score_schema_version = "1.0.0", n_genes = 3L, n_hpo_predictions = 4L,
      n_hpo_terms = 2L, n_features = 48L, hpo_threshold = 0.5),
      import_job_id = "old", imported_by = NULL, import_status = "failed")
    result <- run(conn, validate_only = FALSE, job_id = "job-retry")
    expect_true(result$activated)
    nddscore_clean_tables(conn)
  })
})

describe("nddscore_import handler registration", {
  it("is registered in the durable async job registry", {
    source_api_file("functions/async-job-handlers.R", local = FALSE)
    entry <- async_job_get_handler("nddscore_import")
    expect_true(is.function(entry$run))
  })
})
```

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement `nddscore_run_import`** — append to `api/functions/nddscore-import.R`:

```r
# ---------------------------------------------------------------------------
# Orchestration: production-safe import per spec section 5.3 (steps 1-12).
# The caller (async-job handler or test) supplies the connection and already
# holds the advisory lock. `deps` lets tests stub Zenodo; `progress` is a
# reporter callback (step, message, current, total).
# ---------------------------------------------------------------------------

nddscore_run_import <- function(conn, record_id, validate_only = FALSE,
                                imported_by = NULL, job_id = NULL,
                                deps = list(), progress = function(...) {}) {
  fetch_metadata <- deps$fetch_metadata %||%
    function(rid) nddscore_fetch_zenodo_metadata(rid)
  download <- deps$download %||% nddscore_download_archive

  progress("fetch", "Fetching Zenodo metadata", current = 0, total = 6)
  meta <- fetch_metadata(record_id)

  tmp <- file.path(tempdir(), paste0("ndd_import_", as.integer(runif(1, 1, 1e9))))
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)
  archive_path <- file.path(tmp, meta$archive_name %||% "release.tar.gz")

  progress("download", "Downloading release archive", current = 1, total = 6)
  download(meta$content_url, archive_path)
  nddscore_verify_archive_checksum(archive_path, meta$archive_md5)

  progress("extract", "Extracting and verifying archive", current = 2, total = 6)
  rel_dir <- nddscore_extract_and_verify(archive_path)

  progress("parse", "Parsing release and loading TSVs", current = 3, total = 6)
  release <- nddscore_parse_release_json(rel_dir)
  frames <- nddscore_load_tsvs(rel_dir)

  progress("validate", "Validating release", current = 4, total = 6)
  validation <- nddscore_validate(release, frames)
  if (!validation$ok) {
    stop(paste0("NDDScore release validation failed: ",
                paste(validation$messages, collapse = "; ")), call. = FALSE)
  }

  source <- list(
    version = meta$version, version_doi = meta$version_doi,
    concept_doi = meta$concept_doi, record_id = meta$record_id,
    record_url = meta$record_url, archive_name = meta$archive_name,
    archive_md5 = meta$archive_md5, archive_bytes = meta$archive_bytes
  )
  result_base <- list(
    release_id = release$release_id, version_doi = meta$version_doi,
    concept_doi = meta$concept_doi, record_url = meta$record_url,
    archive_name = meta$archive_name, archive_checksum = meta$archive_md5,
    gene_rows = nrow(frames$gene), hpo_rows = nrow(frames$hpo),
    term_rows = nrow(frames$term)
  )

  if (isTRUE(validate_only)) {
    return(c(result_base, list(validated = TRUE, activated = FALSE)))
  }

  # Active-release guard (step 7).
  state <- nddscore_release_exists(conn, release$release_id)
  if (state$exists && state$is_active) {
    stop(sprintf(paste(
      "NDDScore release '%s' is already the active release;",
      "re-importing the active release is refused"), release$release_id),
      call. = FALSE)
  }
  if (state$exists) {
    nddscore_delete_inactive_release(conn, release$release_id)
  }

  progress("import", "Writing prediction rows", current = 5, total = 6)
  nddscore_upsert_release_row(conn, release, import_job_id = job_id,
                              imported_by = imported_by, source = source,
                              import_status = "importing")
  nddscore_insert_predictions(conn, release$release_id, frames)

  counts <- nddscore_count_release_rows(conn, release$release_id)
  if (counts$gene != nrow(frames$gene) || counts$hpo != nrow(frames$hpo) ||
      counts$term != nrow(frames$term)) {
    stop("NDDScore DB row counts disagree with loaded frames after insert",
         call. = FALSE)
  }
  nddscore_mark_release_validated(conn, release$release_id)

  progress("activate", "Activating release", current = 6, total = 6)
  nddscore_activate_release(conn, release$release_id)

  c(result_base, list(validated = TRUE, activated = TRUE,
                      gene_rows = counts$gene, hpo_rows = counts$hpo,
                      term_rows = counts$term))
}
```

- [ ] **Step 4: Implement the handler** — in `api/functions/async-job-handlers.R`, add this handler function near the other `.async_job_run_*` functions:

```r
.async_job_run_nddscore_import <- function(job, payload, state, worker_config) {
  record_id <- .async_job_payload_scalar(payload, "record_id")
  validate_only <- isTRUE(.async_job_payload_scalar(payload, "validate_only",
                                                    required = FALSE,
                                                    default = FALSE))
  job_id <- job$job_id[[1]]
  submitted_by <- if (!is.null(job$submitted_by) &&
                      !is.na(job$submitted_by[[1]])) job$submitted_by[[1]] else NULL
  progress <- .async_job_progress_reporter(job_id)

  # One connection from the worker pool held for the lock + all writes.
  conn <- pool::poolCheckout(pool)
  on.exit(pool::poolReturn(conn), add = TRUE)

  nddscore_acquire_import_lock(conn)
  on.exit(nddscore_release_import_lock(conn), add = TRUE)

  tryCatch(
    nddscore_run_import(conn, record_id = record_id,
                        validate_only = validate_only,
                        imported_by = submitted_by, job_id = job_id,
                        progress = progress),
    error = function(e) {
      # Best-effort: mark the new release failed if it was created; never mask
      # the original error. The previously active release is untouched.
      tryCatch({
        rid <- tryCatch(
          nddscore_parse_release_json(
            nddscore_extract_and_verify(file.path(tempdir(), "x")))$release_id,
          error = function(.) NULL)
        if (!is.null(rid)) nddscore_mark_release_failed(conn, rid, conditionMessage(e))
      }, error = function(.) NULL)
      stop(e)
    }
  )
}
```

Note: the failure-marking inside the handler is best-effort. The robust failure marking already happens inside `nddscore_run_import` for the release row it created — refine: instead of re-deriving the release id in the handler `error` branch, have `nddscore_run_import` wrap its post-`upsert` body so that on error it calls `nddscore_mark_release_failed(conn, release$release_id, ...)` then re-raises. Apply this refinement: in `nddscore_run_import`, wrap steps from `nddscore_upsert_release_row` onward in `tryCatch(..., error = function(e) { nddscore_mark_release_failed(conn, release$release_id, conditionMessage(e)); stop(e) })`. Then the handler's `error` branch only needs to `stop(e)`. Update the handler accordingly (drop the re-derive block).

Then register it — in `async-job-handlers.R`, add to the `async_job_handler_registry` list:

```r
  nddscore_import = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_nddscore_import,
    after_success = .async_job_after_success_noop
  ),
```

- [ ] **Step 5: Run — verify pass.** Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-job.R')"` → PASS.

- [ ] **Step 6: Commit**

```bash
git add api/functions/nddscore-import.R api/functions/async-job-handlers.R api/tests/testthat/test-nddscore-job.R
git commit -m "feat(api): NDDScore durable import job orchestration + handler (TDD)"
```

---

### Task 10: Read-only repository `nddscore-repository.R`

**Files:**
- Create: `api/functions/nddscore-repository.R`
- Create: `api/tests/testthat/test-nddscore-repository.R`

Read-only parametrized queries serving the active release via the `*_current` views. Sort and filter inputs are validated against column whitelists; no untrusted string is interpolated into SQL. All queries use `DBI::dbBind`-style `?` placeholders through `db_execute_query` with `unname()`-ed params.

- [ ] **Step 1: Write failing tests**

Create `api/tests/testthat/test-nddscore-repository.R`:

```r
# Tests for the read-only NDDScore repository (api/functions/nddscore-repository.R).
source_api_file("functions/nddscore-import.R", local = FALSE)
source_api_file("functions/nddscore-repository.R", local = FALSE)

# Seed the test DB with the active fixture release, run code, then clean up.
with_nddscore_active_fixture <- function(code) {
  skip_if_no_test_db()
  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))
  nddscore_clean_tables(conn)
  nddscore_run_import(conn, record_id = "20258027", validate_only = FALSE,
                      imported_by = NULL, job_id = "repo-seed",
                      deps = nddscore_stub_deps(),
                      progress = function(...) invisible(NULL))
  withr::defer(nddscore_clean_tables(conn))
  force(code)
}

describe("nddscore_repo_current_release", {
  it("returns the active release metadata", {
    with_nddscore_active_fixture({
      rel <- nddscore_repo_current_release()
      expect_equal(rel$release_id, "ndd_fixture_release")
      expect_equal(as.integer(rel$n_genes), 3L)
    })
  })
})

describe("nddscore_repo_genes", {
  it("returns paginated gene predictions for the active release", {
    with_nddscore_active_fixture({
      page <- nddscore_repo_genes(page = 1L, page_size = 2L)
      expect_lte(nrow(page$data), 2L)
      expect_equal(page$total, 3L)
      expect_true(all(c("gene_symbol", "ndd_score", "risk_tier") %in%
                        names(page$data)))
    })
  })

  it("filters by risk_tier and searches by symbol", {
    with_nddscore_active_fixture({
      low <- nddscore_repo_genes(filters = list(risk_tier = "Low"))
      expect_true(all(low$data$risk_tier == "Low"))
      hit <- nddscore_repo_genes(filters = list(search = "CLCN4"))
      expect_true("CLCN4" %in% hit$data$gene_symbol)
    })
  })

  it("rejects a non-whitelisted sort column", {
    with_nddscore_active_fixture({
      expect_error(nddscore_repo_genes(sort = "ndd_score; DROP TABLE x"),
                   "sort")
    })
  })
})

describe("nddscore_repo_gene_detail", {
  it("resolves by HGNC id and by symbol and includes HPO predictions", {
    with_nddscore_active_fixture({
      by_id <- nddscore_repo_gene_detail("HGNC:2022")
      by_sym <- nddscore_repo_gene_detail("CLCN4")
      expect_equal(by_id$gene$gene_symbol, "CLCN4")
      expect_equal(by_sym$gene$hgnc_id, "HGNC:2022")
      expect_equal(nrow(by_sym$hpo_predictions), 2L)
    })
  })

  it("returns NULL gene for an unknown identifier", {
    with_nddscore_active_fixture({
      expect_null(nddscore_repo_gene_detail("HGNC:0000000")$gene)
    })
  })
})

describe("nddscore_repo_hpo / nddscore_repo_terms / nddscore_repo_download_info", {
  it("returns phenotype predictions, terms, and download info", {
    with_nddscore_active_fixture({
      hpo <- nddscore_repo_hpo(page = 1L, page_size = 10L)
      expect_equal(hpo$total, 4L)
      terms <- nddscore_repo_terms()
      expect_equal(nrow(terms), 2L)
      info <- nddscore_repo_download_info()
      expect_equal(info$version_doi, "10.5281/zenodo.20258027")
    })
  })
})
```

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement**

Create `api/functions/nddscore-repository.R`:

```r
# NDDScore read-only repository. Serves the active release via the *_current
# views. Sort/filter inputs are whitelisted; no untrusted string is interpolated
# into SQL. Parametrized queries go through db_execute_query (unnamed params).

# Whitelisted sortable columns per resource.
.nddscore_gene_sort_cols <- c("rank", "ndd_score", "gene_symbol", "percentile",
                              "risk_tier", "confidence_tier", "n_predicted_hpo")
.nddscore_hpo_sort_cols <- c("probability", "rank_for_gene", "gene_symbol",
                             "phenotype_id")

.nddscore_clamp_page <- function(page, page_size) {
  page <- suppressWarnings(as.integer(page %||% 1L))
  page_size <- suppressWarnings(as.integer(page_size %||% 25L))
  if (is.na(page) || page < 1L) page <- 1L
  if (is.na(page_size) || page_size < 1L) page_size <- 25L
  if (page_size > 200L) page_size <- 200L
  list(page = page, page_size = page_size, offset = (page - 1L) * page_size)
}

.nddscore_check_sort <- function(sort, allowed) {
  sort <- sort %||% allowed[[1]]
  col <- sub("^[-+]?", "", sort)
  desc <- startsWith(sort, "-")
  if (!col %in% allowed) {
    stop(sprintf("Invalid sort column '%s'", col), call. = FALSE)
  }
  list(col = col, dir = if (desc) "DESC" else "ASC")
}

#' Active release metadata (one row) or NULL if no active release.
nddscore_repo_current_release <- function() {
  rows <- db_execute_query(
    "SELECT * FROM nddscore_release WHERE is_active = 1 LIMIT 1", list())
  if (nrow(rows) == 0) return(NULL)
  rows[1, ]
}

#' Paginated/sorted/filtered gene predictions for the active release.
#' filters: list(search=, risk_tier=, confidence_tier=, known_sysndd_gene=).
nddscore_repo_genes <- function(filters = list(), sort = "rank",
                                page = 1L, page_size = 25L) {
  s <- .nddscore_check_sort(sort, .nddscore_gene_sort_cols)
  pg <- .nddscore_clamp_page(page, page_size)

  where <- character(0); params <- list()
  if (!is.null(filters$search) && nzchar(filters$search)) {
    where <- c(where, "(gene_symbol LIKE ? OR hgnc_id LIKE ?)")
    like <- paste0("%", filters$search, "%")
    params <- c(params, list(like, like))
  }
  for (f in c("risk_tier", "confidence_tier")) {
    if (!is.null(filters[[f]]) && nzchar(filters[[f]])) {
      where <- c(where, sprintf("%s = ?", f))
      params <- c(params, list(filters[[f]]))
    }
  }
  if (!is.null(filters$known_sysndd_gene) && nzchar(filters$known_sysndd_gene)) {
    where <- c(where, "known_sysndd_gene = ?")
    params <- c(params, list(as.integer(filters$known_sysndd_gene %in%
                                          c("1", "true", "TRUE"))))
  }
  where_sql <- if (length(where)) paste("WHERE", paste(where, collapse = " AND ")) else ""

  total <- db_execute_query(sprintf(
    "SELECT COUNT(*) AS n FROM nddscore_gene_prediction_current %s", where_sql),
    params)$n[[1]]
  data <- db_execute_query(sprintf(paste(
    "SELECT * FROM nddscore_gene_prediction_current %s",
    "ORDER BY %s %s LIMIT ? OFFSET ?"),
    where_sql, s$col, s$dir),
    c(params, list(pg$page_size, pg$offset)))

  list(data = data, total = as.integer(total),
       page = pg$page, page_size = pg$page_size)
}

#' Single-gene detail: gene row + its HPO predictions. Accepts HGNC id or symbol.
nddscore_repo_gene_detail <- function(hgnc_id_or_symbol) {
  key <- as.character(hgnc_id_or_symbol)[[1]]
  gene <- db_execute_query(paste(
    "SELECT * FROM nddscore_gene_prediction_current",
    "WHERE hgnc_id = ? OR gene_symbol = ? LIMIT 1"),
    list(key, key))
  if (nrow(gene) == 0) return(list(gene = NULL, hpo_predictions = NULL))
  hpo <- db_execute_query(paste(
    "SELECT * FROM nddscore_hpo_prediction_current",
    "WHERE hgnc_id = ? ORDER BY rank_for_gene ASC"),
    list(gene$hgnc_id[[1]]))
  list(gene = gene[1, ], hpo_predictions = hpo)
}

#' Paginated phenotype (gene-HPO) predictions for the active release.
#' filters: list(search=, phenotype_id=, passes_threshold=).
nddscore_repo_hpo <- function(filters = list(), sort = "-probability",
                              page = 1L, page_size = 25L) {
  s <- .nddscore_check_sort(sort, .nddscore_hpo_sort_cols)
  pg <- .nddscore_clamp_page(page, page_size)

  where <- character(0); params <- list()
  if (!is.null(filters$search) && nzchar(filters$search)) {
    where <- c(where, "(gene_symbol LIKE ? OR phenotype_name LIKE ?)")
    like <- paste0("%", filters$search, "%")
    params <- c(params, list(like, like))
  }
  if (!is.null(filters$phenotype_id) && nzchar(filters$phenotype_id)) {
    where <- c(where, "phenotype_id = ?")
    params <- c(params, list(filters$phenotype_id))
  }
  if (!is.null(filters$passes_threshold) && nzchar(filters$passes_threshold)) {
    where <- c(where, "passes_default_threshold = ?")
    params <- c(params, list(as.integer(filters$passes_threshold %in%
                                          c("1", "true", "TRUE"))))
  }
  where_sql <- if (length(where)) paste("WHERE", paste(where, collapse = " AND ")) else ""

  total <- db_execute_query(sprintf(
    "SELECT COUNT(*) AS n FROM nddscore_hpo_prediction_current %s", where_sql),
    params)$n[[1]]
  data <- db_execute_query(sprintf(paste(
    "SELECT * FROM nddscore_hpo_prediction_current %s",
    "ORDER BY %s %s LIMIT ? OFFSET ?"),
    where_sql, s$col, s$dir),
    c(params, list(pg$page_size, pg$offset)))

  list(data = data, total = as.integer(total),
       page = pg$page, page_size = pg$page_size)
}

#' All HPO term metadata for the active release.
nddscore_repo_terms <- function() {
  db_execute_query(paste(
    "SELECT * FROM nddscore_hpo_term_current ORDER BY phenotype_id ASC"), list())
}

#' DOIs / record URL / archive identity from the active release.
nddscore_repo_download_info <- function() {
  rel <- nddscore_repo_current_release()
  if (is.null(rel)) return(NULL)
  list(
    release_id = rel$release_id, version = rel$version,
    zenodo_record_url = rel$zenodo_record_url, version_doi = rel$version_doi,
    concept_doi = rel$concept_doi, source_record_id = rel$source_record_id,
    source_archive_name = rel$source_archive_name,
    source_archive_checksum = rel$source_archive_checksum,
    source_archive_bytes = rel$source_archive_bytes
  )
}
```

- [ ] **Step 4: Run — verify pass.**

- [ ] **Step 5: Commit**

```bash
git add api/functions/nddscore-repository.R api/tests/testthat/test-nddscore-repository.R
git commit -m "feat(api): NDDScore read-only repository (TDD)"
```

---

### Task 11: Public endpoints `nddscore_endpoints.R`

**Files:**
- Create: `api/endpoints/nddscore_endpoints.R`
- Modify: `api/tests/testthat/test-nddscore-endpoints.R` (created here)

Six public GET endpoints (spec §5.4). Each is a thin wrapper over the repository. Endpoint handlers unwrap Plumber array-scalar params and map a `NULL` active release to a clear `404`. Read the existing `api/endpoints/gene_endpoints.R` first to match the Plumber annotation style (`#* @tag`, `#* @serializer json list(na="string")`, `#* @get`) and the `core/errors.R` helpers (`stop_for_not_found`).

- [ ] **Step 1: Write the failing tests**

Create `api/tests/testthat/test-nddscore-endpoints.R`:

```r
# Tests for NDDScore public + admin endpoint handler functions. The endpoint
# files define plumber-annotated functions; we exercise the handler logic via
# the repository seed used in the repository tests.
source_api_file("functions/nddscore-import.R", local = FALSE)
source_api_file("functions/nddscore-repository.R", local = FALSE)

describe("NDDScore public endpoint behavior", {
  it("current-release endpoint returns 404 when no release is active", {
    skip_if_no_test_db()
    conn <- get_test_db_connection(); withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)
    expect_null(nddscore_repo_current_release())
  })

  it("gene list endpoint paginates the active release", {
    skip_if_no_test_db()
    conn <- get_test_db_connection(); withr::defer(DBI::dbDisconnect(conn))
    nddscore_clean_tables(conn)
    nddscore_run_import(conn, record_id = "20258027", validate_only = FALSE,
                        imported_by = NULL, job_id = "ep-seed",
                        deps = nddscore_stub_deps(),
                        progress = function(...) invisible(NULL))
    withr::defer(nddscore_clean_tables(conn))
    page <- nddscore_repo_genes(page = 1L, page_size = 2L)
    expect_equal(page$total, 3L)
    expect_lte(nrow(page$data), 2L)
  })
})
```

(The endpoint files are mounted and exercised end-to-end by the API smoke test; these unit tests assert the repository-backed behavior the handlers expose. A full HTTP round-trip test is added in Task 12 for the admin submission path.)

- [ ] **Step 2: Run — verify fail / skip** (no `nddscore_endpoints.R` yet — this step mainly fails once Task 12 adds the HTTP test; here it will pass on the repo functions. Proceed to implement the endpoint file regardless.)

- [ ] **Step 3: Implement the endpoint file**

Create `api/endpoints/nddscore_endpoints.R`:

```r
# Public NDDScore endpoints. NDDScore is a model-derived prediction layer,
# served read-only from the active release. Curated SysNDD evidence is never
# reclassified by NDDScore.

#* @apiTitle NDDScore public API
#* @apiTag nddscore Model-derived NDD prediction layer (read-only)

#* Active NDDScore release metadata and performance summary.
#* @tag nddscore
#* @serializer json list(na="string")
#* @get /release/current
function(req, res) {
  release <- nddscore_repo_current_release()
  if (is.null(release)) {
    res$status <- 404L
    return(list(error = "No active NDDScore release"))
  }
  release
}

#* Paginated, sortable, filterable gene predictions for the active release.
#* @tag nddscore
#* @serializer json list(na="string")
#* @param sort:str Whitelisted sort column, optional leading '-' for descending.
#* @param search:str Free-text search over gene symbol / HGNC id.
#* @param risk_tier:str Filter by risk tier.
#* @param confidence_tier:str Filter by confidence tier.
#* @param known_sysndd_gene:str "true"/"false" filter.
#* @param page:int Page number (1-based).
#* @param page_size:int Rows per page (max 200).
#* @get /genes
function(req, res, sort = "rank", search = "", risk_tier = "",
         confidence_tier = "", known_sysndd_gene = "",
         page = "1", page_size = "25") {
  uw <- function(x) as.character(x)[[1]]
  tryCatch(
    nddscore_repo_genes(
      filters = list(search = uw(search), risk_tier = uw(risk_tier),
                     confidence_tier = uw(confidence_tier),
                     known_sysndd_gene = uw(known_sysndd_gene)),
      sort = uw(sort), page = uw(page), page_size = uw(page_size)),
    error = function(e) { res$status <- 400L; list(error = conditionMessage(e)) }
  )
}

#* Single-gene NDDScore detail (by HGNC id or symbol), with HPO predictions.
#* @tag nddscore
#* @serializer json list(na="string")
#* @get /genes/<hgnc_id_or_symbol>
function(req, res, hgnc_id_or_symbol) {
  detail <- nddscore_repo_gene_detail(as.character(hgnc_id_or_symbol)[[1]])
  if (is.null(detail$gene)) {
    res$status <- 404L
    return(list(error = "Gene not found in the active NDDScore release"))
  }
  detail
}

#* Paginated phenotype (gene-HPO) predictions for the active release.
#* @tag nddscore
#* @serializer json list(na="string")
#* @get /hpo
function(req, res, sort = "-probability", search = "", phenotype_id = "",
         passes_threshold = "", page = "1", page_size = "25") {
  uw <- function(x) as.character(x)[[1]]
  tryCatch(
    nddscore_repo_hpo(
      filters = list(search = uw(search), phenotype_id = uw(phenotype_id),
                     passes_threshold = uw(passes_threshold)),
      sort = uw(sort), page = uw(page), page_size = uw(page_size)),
    error = function(e) { res$status <- 400L; list(error = conditionMessage(e)) }
  )
}

#* HPO term metadata for the active release.
#* @tag nddscore
#* @serializer json list(na="string")
#* @get /terms
function(req, res) {
  nddscore_repo_terms()
}

#* NDDScore dataset download info: DOIs, record URL, archive name + checksum.
#* @tag nddscore
#* @serializer json list(na="string")
#* @get /download/info
function(req, res) {
  info <- nddscore_repo_download_info()
  if (is.null(info)) {
    res$status <- 404L
    return(list(error = "No active NDDScore release"))
  }
  info
}
```

- [ ] **Step 4: Mount the endpoint file.** In `api/start_sysndd_api.R`, find where other endpoint files are mounted (e.g. `pr_mount` / `mount` calls for `gene_endpoints.R`) and add a mount for `nddscore_endpoints.R` under `/api/nddscore`. Match the exact mounting idiom used for the neighbouring public endpoint files. Run `grep -n "endpoints/" api/start_sysndd_api.R` to find the block.

- [ ] **Step 5: Run — verify pass.** Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-endpoints.R')"` → PASS.

- [ ] **Step 6: Commit**

```bash
git add api/endpoints/nddscore_endpoints.R api/start_sysndd_api.R api/tests/testthat/test-nddscore-endpoints.R
git commit -m "feat(api): public NDDScore endpoints"
```

---

### Task 12: Admin endpoints + module wiring + version bump

**Files:**
- Modify: `api/endpoints/admin_endpoints.R` (add three endpoints)
- Modify: `api/bootstrap/load_modules.R` (register the two new function files)
- Modify: `api/version_spec.json` (version bump)
- Modify: `api/tests/testthat/test-nddscore-endpoints.R` (append admin test)

Three Administrator-only endpoints (spec §5.5). The role is enforced in the handler via `require_role(req, res, "Administrator")` (the existing route filter also enforces it — both layers, never frontend-only). The import endpoint submits the durable `nddscore_import` job via `async_job_service_submit` (System B; spec §11: "not job-manager.R"). Status is polled by the existing `GET /api/jobs/<job_id>/status`, which is durable-backed (`get_job_status` → `async_job_service_status`).

- [ ] **Step 1: Register the new function files** in `api/bootstrap/load_modules.R` — add to the functions source list (alongside `async-job-repository.R` etc.), in this order (repository-style files, before services):

```r
  "functions/nddscore-import.R",
  "functions/nddscore-repository.R",
```

- [ ] **Step 2: Write the failing admin test** — append to `test-nddscore-endpoints.R`:

```r
describe("NDDScore admin import submission", {
  it("submits a durable nddscore_import job and returns its job id", {
    skip_if_no_test_db()
    source_api_file("functions/async-job-service.R", local = FALSE)
    submitted <- async_job_service_submit(
      job_type = "nddscore_import",
      request_payload = list(record_id = "20258027", validate_only = TRUE),
      submitted_by = NULL)
    expect_true(submitted$created || submitted$duplicate)
    expect_equal(submitted$job$job_type[[1]], "nddscore_import")
  })
})
```

- [ ] **Step 3: Run — verify fail/behaviour.** Run the test file. The submit test should pass once `async-job-service.R` is sourced (the job type is a free-form string). If it fails, inspect the error — `async_job_service_submit` requires a valid DB.

- [ ] **Step 4: Implement the admin endpoints** — append to `api/endpoints/admin_endpoints.R` (match the file's existing annotation + `require_role` idiom):

```r
#* NDDScore admin: active release, last import status, recent import jobs.
#* @tag admin
#* @serializer json list(na="string")
#* @get /nddscore/status
function(req, res) {
  require_role(req, res, "Administrator")
  release <- nddscore_repo_current_release()
  recent <- tryCatch(get_job_history(20), error = function(e) NULL)
  nddscore_jobs <- if (!is.null(recent) && nrow(recent) > 0) {
    recent[recent$operation == "nddscore_import", , drop = FALSE]
  } else {
    recent
  }
  list(active_release = release, recent_jobs = nddscore_jobs)
}

#* NDDScore admin: current Zenodo metadata vs the active release.
#* @tag admin
#* @serializer json list(na="string")
#* @param record_id:str Zenodo record id (default 20258027).
#* @get /nddscore/zenodo
function(req, res, record_id = "20258027") {
  require_role(req, res, "Administrator")
  rid <- as.character(record_id)[[1]]
  meta <- tryCatch(nddscore_fetch_zenodo_metadata(rid),
                   error = function(e) {
                     res$status <- 502L
                     list(error = conditionMessage(e))
                   })
  if (!is.null(meta$error)) return(meta)
  active <- nddscore_repo_current_release()
  list(
    zenodo = meta,
    active_release = active,
    matches_active = !is.null(active) &&
      identical(active$source_record_id, meta$record_id)
  )
}

#* NDDScore admin: submit the durable nddscore_import job.
#* @tag admin
#* @serializer json list(na="string")
#* @post /nddscore/import
function(req, res) {
  require_role(req, res, "Administrator")
  body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
  record_id <- as.character(body$record_id %||% "20258027")[[1]]
  validate_only <- isTRUE(body$validate_only)

  submitted <- async_job_service_submit(
    job_type = "nddscore_import",
    request_payload = list(record_id = record_id, validate_only = validate_only),
    submitted_by = req$user_id %||% NULL)

  job_id <- submitted$job$job_id[[1]]
  res$status <- if (submitted$duplicate) 409L else 202L
  res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
  list(
    job_id = job_id,
    status = if (submitted$duplicate) "duplicate" else "accepted",
    validate_only = validate_only,
    status_url = paste0("/api/jobs/", job_id, "/status")
  )
}
```

- [ ] **Step 5: Bump the API version.** In `api/version_spec.json`, change `"version"` from `0.19.0` to `0.20.0`.

- [ ] **Step 6: Run — verify pass.** Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-endpoints.R')"` → PASS.

- [ ] **Step 7: Restart the worker container** (durable handler + new function files are sourced at worker start): `docker compose restart worker` (or rebuild per `make dev`). Required before any live job test.

- [ ] **Step 8: Phase 3 verification gate.**

Run: `make lint-api` → expected: clean.
Run: `make test-api-fast` → expected: pass (NDDScore suites green; pre-existing unrelated failures noted in project memory are acceptable).

- [ ] **Step 9: Commit**

```bash
git add api/endpoints/admin_endpoints.R api/bootstrap/load_modules.R api/version_spec.json api/tests/testthat/test-nddscore-endpoints.R
git commit -m "feat(api): NDDScore admin endpoints + module wiring + v0.20.0"
```

---

# Phase 4 — Public frontend (`/NDDScore`)

Before starting, open these files — they are the templates each task mirrors: `app/src/views/analyses/PhenotypeCorrelations.vue` (AnalysisShell + route-driven tabs), `app/src/components/tables/TablesEntities.vue` (TableShell composition), `app/src/components/llm/LlmSummaryCard.vue` (card layout), `app/src/api/client.ts` (`apiClient`, `unwrapScalar`). All NDDScore copy must follow spec §7 copy rules.

### Task 13: Navigation + routes

**Files:**
- Modify: `app/src/assets/js/constants/main_nav_constants.ts`
- Modify: `app/src/router/routes.ts`
- Create: `app/src/router/routes.nddscore.spec.ts`

- [ ] **Step 1: Write the failing test**

Create `app/src/router/routes.nddscore.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { routes } from './routes';
import { DROPDOWN_ITEMS_LEFT } from '@/assets/js/constants/main_nav_constants';

describe('NDDScore navigation + routes', () => {
  it('adds a public NDDScore dropdown between Analyses and Help', () => {
    const ids = DROPDOWN_ITEMS_LEFT.map((d) => d.id);
    const idxScore = ids.indexOf('ndd_score_dropdown');
    expect(idxScore).toBeGreaterThan(ids.indexOf('analyses_dropdown'));
    expect(idxScore).toBeLessThan(ids.indexOf('help_dropdown'));
    const dd = DROPDOWN_ITEMS_LEFT[idxScore];
    expect(dd.required).toEqual(['']); // public
    expect(dd.items.some((i) => i.path === '/NDDScore')).toBe(true);
  });

  it('registers a public /NDDScore route with child routes', () => {
    const score = routes.find((r) => r.path === '/NDDScore');
    expect(score).toBeDefined();
    expect(score?.beforeEnter).toBeUndefined(); // public
    const childPaths = (score?.children ?? []).map((c) => c.path);
    expect(childPaths).toContain('');
    expect(childPaths).toContain('PhenotypePredictions');
    expect(childPaths).toContain('ModelCard');
    expect(childPaths).toContain('Gene/:hgncIdOrSymbol');
  });

  it('registers an Administrator-guarded /ManageNDDScore route', () => {
    const manage = routes.find((r) => r.path === '/ManageNDDScore');
    expect(manage).toBeDefined();
    expect(typeof manage?.beforeEnter).toBe('function');
  });
});
```

- [ ] **Step 2: Run — verify fail.** Run: `cd app && npx vitest run src/router/routes.nddscore.spec.ts` → FAIL.

- [ ] **Step 3: Add the NDDScore dropdown.** In `app/src/assets/js/constants/main_nav_constants.ts`, insert a new object into `DROPDOWN_ITEMS_LEFT` immediately before the `help_dropdown` object:

```ts
    {
      id: 'ndd_score_dropdown',
      title: 'NDDScore',
      required: [''],
      align: 'left',
      items: [
        { text: 'Gene predictions', path: '/NDDScore', icons: ['cpu', 'list-ol'] },
        {
          text: 'Phenotype predictions',
          path: '/NDDScore/PhenotypePredictions',
          icons: ['cpu', 'diagram-3'],
        },
        { text: 'Model card', path: '/NDDScore/ModelCard', icons: ['cpu', 'card-text'] },
      ],
    },
```

Add the admin nav item — in `DROPDOWN_ITEMS_RIGHT` `administration_dropdown` `items` array, after the `LLM Management` entry:

```ts
        { text: 'Manage NDDScore', path: '/ManageNDDScore', icons: ['gear', 'graph-up-arrow'] },
```

- [ ] **Step 4: Add the routes.** In `app/src/router/routes.ts`, add a public `/NDDScore` route mirroring the `/PhenotypeCorrelations` children pattern, plus the admin route:

```ts
  {
    path: '/NDDScore',
    component: () => import('@/views/nddscore/NDDScore.vue'),
    children: [
      {
        path: '',
        name: 'NDDScore',
        component: () => import('@/components/nddscore/NddScoreGeneTable.vue'),
      },
      {
        path: 'PhenotypePredictions',
        name: 'NDDScorePhenotypePredictions',
        component: () => import('@/components/nddscore/NddScoreHpoTable.vue'),
      },
      {
        path: 'ModelCard',
        name: 'NDDScoreModelCard',
        component: () => import('@/components/nddscore/NddScoreModelCard.vue'),
      },
      {
        path: 'Gene/:hgncIdOrSymbol',
        name: 'NDDScoreGeneDetail',
        component: () => import('@/components/nddscore/NddScoreGeneDetail.vue'),
        props: true,
      },
    ],
    meta: { sitemap: { priority: 0.7, changefreq: 'monthly' } },
  },
  {
    path: '/ManageNDDScore',
    name: 'ManageNDDScore',
    component: () => import('@/views/admin/ManageNDDScore.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator']),
  },
```

- [ ] **Step 5: Run — verify pass.** Run: `cd app && npx vitest run src/router/routes.nddscore.spec.ts` → PASS.

- [ ] **Step 6: Commit**

```bash
git add app/src/assets/js/constants/main_nav_constants.ts app/src/router/routes.ts app/src/router/routes.nddscore.spec.ts
git commit -m "feat(app): NDDScore navigation + routes"
```

---

### Task 14: Public API client `nddscore.ts`

**Files:**
- Create: `app/src/api/nddscore.ts`
- Create: `app/src/api/nddscore.spec.ts`

- [ ] **Step 1: Write the failing test**

Create `app/src/api/nddscore.spec.ts`:

```ts
import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { fetchCurrentRelease, fetchGenePredictions } from './nddscore';

describe('nddscore api client', () => {
  afterEach(() => server.resetHandlers());

  it('fetches the current release', async () => {
    server.use(
      http.get('/api/nddscore/release/current', () =>
        HttpResponse.json({ release_id: ['ndd_fixture_release'], n_genes: [3] })
      )
    );
    const release = await fetchCurrentRelease();
    // R/Plumber array-scalars are unwrapped by the client.
    expect(release.release_id).toBe('ndd_fixture_release');
    expect(release.n_genes).toBe(3);
  });

  it('passes pagination + filter params to the genes endpoint', async () => {
    let seen: URL | null = null;
    server.use(
      http.get('/api/nddscore/genes', ({ request }) => {
        seen = new URL(request.url);
        return HttpResponse.json({ data: [], total: 0, page: 2, page_size: 10 });
      })
    );
    await fetchGenePredictions({ page: 2, pageSize: 10, riskTier: 'Low' });
    expect(seen!.searchParams.get('page')).toBe('2');
    expect(seen!.searchParams.get('page_size')).toBe('10');
    expect(seen!.searchParams.get('risk_tier')).toBe('Low');
  });
});
```

- [ ] **Step 2: Run — verify fail.** Run: `cd app && npx vitest run src/api/nddscore.spec.ts` → FAIL.

- [ ] **Step 3: Implement**

Create `app/src/api/nddscore.ts`:

```ts
// Public NDDScore API client. NDDScore is a model-derived prediction layer,
// served read-only. R/Plumber may return JSON scalars as 1-element arrays;
// callers unwrap with unwrapScalar where a scalar is expected.
import { apiClient, unwrapScalar } from './client';

export interface NddScoreReleaseRaw {
  [key: string]: unknown;
}

export interface NddScoreGeneQuery {
  sort?: string;
  search?: string;
  riskTier?: string;
  confidenceTier?: string;
  knownSysnddGene?: string;
  page?: number;
  pageSize?: number;
}

export interface NddScorePage<T> {
  data: T[];
  total: number;
  page: number;
  page_size: number;
}

function unwrapRecord<T extends Record<string, unknown>>(row: T): T {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(row)) out[k] = unwrapScalar(v as never);
  return out as T;
}

export async function fetchCurrentRelease(): Promise<NddScoreReleaseRaw> {
  const release = await apiClient.get<NddScoreReleaseRaw>('/api/nddscore/release/current');
  return unwrapRecord(release);
}

export async function fetchGenePredictions(
  query: NddScoreGeneQuery = {}
): Promise<NddScorePage<Record<string, unknown>>> {
  const params: Record<string, string | number> = {};
  if (query.sort) params.sort = query.sort;
  if (query.search) params.search = query.search;
  if (query.riskTier) params.risk_tier = query.riskTier;
  if (query.confidenceTier) params.confidence_tier = query.confidenceTier;
  if (query.knownSysnddGene) params.known_sysndd_gene = query.knownSysnddGene;
  if (query.page) params.page = query.page;
  if (query.pageSize) params.page_size = query.pageSize;
  return apiClient.get('/api/nddscore/genes', { params });
}

export async function fetchGeneDetail(hgncIdOrSymbol: string): Promise<{
  gene: Record<string, unknown> | null;
  hpo_predictions: Record<string, unknown>[] | null;
}> {
  return apiClient.get(`/api/nddscore/genes/${encodeURIComponent(hgncIdOrSymbol)}`);
}

export interface NddScoreHpoQuery {
  sort?: string;
  search?: string;
  phenotypeId?: string;
  passesThreshold?: string;
  page?: number;
  pageSize?: number;
}

export async function fetchHpoPredictions(
  query: NddScoreHpoQuery = {}
): Promise<NddScorePage<Record<string, unknown>>> {
  const params: Record<string, string | number> = {};
  if (query.sort) params.sort = query.sort;
  if (query.search) params.search = query.search;
  if (query.phenotypeId) params.phenotype_id = query.phenotypeId;
  if (query.passesThreshold) params.passes_threshold = query.passesThreshold;
  if (query.page) params.page = query.page;
  if (query.pageSize) params.page_size = query.pageSize;
  return apiClient.get('/api/nddscore/hpo', { params });
}

export async function fetchHpoTerms(): Promise<Record<string, unknown>[]> {
  return apiClient.get('/api/nddscore/terms');
}

export async function fetchDownloadInfo(): Promise<Record<string, unknown>> {
  const info = await apiClient.get<Record<string, unknown>>('/api/nddscore/download/info');
  return unwrapRecord(info);
}
```

If `unwrapScalar` is not exported from `app/src/api/client.ts` under that exact name, run `grep -rn "unwrap" app/src/api/` and use the actual exported helper; do not invent one.

- [ ] **Step 4: Run — verify pass.** Run: `cd app && npx vitest run src/api/nddscore.spec.ts` → PASS.

- [ ] **Step 5: Commit**

```bash
git add app/src/api/nddscore.ts app/src/api/nddscore.spec.ts
git commit -m "feat(app): NDDScore public API client"
```

---

### Task 15: `NddScorePredictionCard` component

**Files:**
- Create: `app/src/components/nddscore/NddScorePredictionCard.vue`
- Create: `app/src/components/nddscore/NddScorePredictionCard.spec.ts`

The reusable ML-prediction indicator card (spec §6.3) — modeled on `LlmSummaryCard` but visually distinct: header uses `bi-cpu` + label **"ML prediction"** (deliberately not `bi-stars`/"AI"). Body carries the mandated disclaimer, a performance strip (Test AUC-ROC, Brier Skill Score), and the release ID + version DOI link.

- [ ] **Step 1: Write the failing test**

Create `app/src/components/nddscore/NddScorePredictionCard.spec.ts`:

```ts
import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import NddScorePredictionCard from './NddScorePredictionCard.vue';

describe('NddScorePredictionCard', () => {
  const props = {
    releaseId: 'nddscore_20260517_public',
    versionDoi: '10.5281/zenodo.20258027',
    testAucRoc: 0.8877,
    brierSkillScore: 0.4438,
  };

  it('renders the ML prediction indicator, not an AI label', () => {
    const wrapper = mount(NddScorePredictionCard, { props });
    expect(wrapper.text()).toContain('ML prediction');
    expect(wrapper.find('.bi-cpu').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('AI');
  });

  it('shows the mandated separation disclaimer', () => {
    const wrapper = mount(NddScorePredictionCard, { props });
    const text = wrapper.text();
    expect(text).toContain('model-derived prediction layer');
    expect(text).toContain('not curated SysNDD evidence');
    expect(text).toContain('not an evidence-tier assignment');
  });

  it('renders the performance strip and release identity', () => {
    const wrapper = mount(NddScorePredictionCard, { props });
    expect(wrapper.text()).toContain('nddscore_20260517_public');
    expect(wrapper.get('a').attributes('href')).toContain('10.5281/zenodo.20258027');
  });
});
```

- [ ] **Step 2: Run — verify fail.** Run: `cd app && npx vitest run src/components/nddscore/NddScorePredictionCard.spec.ts` → FAIL.

- [ ] **Step 3: Implement**

Create `app/src/components/nddscore/NddScorePredictionCard.vue`:

```vue
<template>
  <BCard class="ndd-score-card" no-body>
    <div class="ndd-score-card__header">
      <i class="bi bi-cpu ndd-score-card__icon" aria-hidden="true" />
      <span class="ndd-score-card__label">ML prediction</span>
      <BBadge v-if="releaseId" variant="secondary" class="ms-auto">
        {{ releaseId }}
      </BBadge>
    </div>
    <div class="ndd-score-card__body">
      <p class="ndd-score-card__disclaimer">
        NDDScore is a model-derived prediction layer. It is not curated SysNDD
        evidence, not a manual review, and not an evidence-tier assignment.
      </p>
      <div class="ndd-score-card__metrics">
        <div v-if="testAucRoc != null" class="ndd-score-card__metric">
          <span class="ndd-score-card__metric-value">{{ formatMetric(testAucRoc) }}</span>
          <span class="ndd-score-card__metric-label">Test AUC-ROC</span>
        </div>
        <div v-if="brierSkillScore != null" class="ndd-score-card__metric">
          <span class="ndd-score-card__metric-value">{{ formatMetric(brierSkillScore) }}</span>
          <span class="ndd-score-card__metric-label">Brier Skill Score</span>
        </div>
      </div>
      <p v-if="versionDoi" class="ndd-score-card__doi">
        Version DOI:
        <a :href="`https://doi.org/${versionDoi}`" target="_blank" rel="noopener">
          {{ versionDoi }}
        </a>
      </p>
    </div>
  </BCard>
</template>

<script setup lang="ts">
defineProps<{
  releaseId?: string;
  versionDoi?: string;
  testAucRoc?: number | null;
  brierSkillScore?: number | null;
}>();

function formatMetric(value: number): string {
  return value.toFixed(3);
}
</script>

<style scoped>
.ndd-score-card {
  border-left: 4px solid var(--bs-info, #0dcaf0);
}
.ndd-score-card__header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--bs-border-color, #dee2e6);
  font-weight: 600;
}
.ndd-score-card__icon {
  color: var(--bs-info, #0dcaf0);
  font-size: 1.25rem;
}
.ndd-score-card__body {
  padding: 1rem;
}
.ndd-score-card__disclaimer {
  font-size: 0.9rem;
  margin-bottom: 0.75rem;
}
.ndd-score-card__metrics {
  display: flex;
  gap: 1.5rem;
  margin-bottom: 0.5rem;
}
.ndd-score-card__metric {
  display: flex;
  flex-direction: column;
}
.ndd-score-card__metric-value {
  font-size: 1.25rem;
  font-weight: 700;
}
.ndd-score-card__metric-label {
  font-size: 0.75rem;
  color: var(--bs-secondary-color, #6c757d);
}
.ndd-score-card__doi {
  font-size: 0.8rem;
  margin-bottom: 0;
}
</style>
```

Verify `BCard`/`BBadge` are globally registered (they are used across the app — e.g. `LlmSummaryCard.vue`). If the project imports them explicitly per-component, follow that local convention instead.

- [ ] **Step 4: Run — verify pass.** Run the spec → PASS.

- [ ] **Step 5: Commit**

```bash
git add app/src/components/nddscore/NddScorePredictionCard.vue app/src/components/nddscore/NddScorePredictionCard.spec.ts
git commit -m "feat(app): NddScorePredictionCard ML-prediction indicator"
```

---

### Task 16: `NDDScore.vue` page shell + `NddScoreGeneTable`

**Files:**
- Create: `app/src/views/nddscore/NDDScore.vue`
- Create: `app/src/components/nddscore/NddScoreGeneTable.vue`
- Create: `app/src/views/nddscore/NDDScore.spec.ts`

`NDDScore.vue` is the page shell: `AnalysisShell` (title `NDDScore`, the spec §6.3 subtitle), route-driven tabs, the `meta` slot carrying an ML indicator badge, and `NddScorePredictionCard` pinned at the top. Child components render in the default slot via `<RouterView>`. `NddScoreGeneTable` is the gene-predictions table built on `TableShell` + `TableSearchInput` (mirror `TablesEntities.vue`).

- [ ] **Step 1: Write the failing test**

Create `app/src/views/nddscore/NDDScore.spec.ts`:

```ts
import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import NDDScore from './NDDScore.vue';

vi.mock('@/api/nddscore', () => ({
  fetchCurrentRelease: vi.fn().mockResolvedValue({
    release_id: 'nddscore_20260517_public',
    version_doi: '10.5281/zenodo.20258027',
    ndd_performance_json: JSON.stringify({ test: { auc_roc: 0.8877, bss: 0.4438 } }),
  }),
}));

describe('NDDScore.vue', () => {
  it('renders the ML-vs-curated separation subtitle and prediction card', async () => {
    const wrapper = mount(NDDScore, {
      global: {
        stubs: { RouterView: true, AnalysisShell: false, RouterLink: true },
      },
    });
    await new Promise((r) => setTimeout(r, 0));
    const text = wrapper.text();
    expect(text).toContain('separate from curated SysNDD evidence');
    expect(wrapper.findComponent({ name: 'NddScorePredictionCard' }).exists()).toBe(true);
  });
});
```

If `AnalysisShell` cannot mount un-stubbed in unit tests, stub it (`AnalysisShell: true`) and instead assert the subtitle is passed as a prop: `wrapper.findComponent({ name: 'AnalysisShell' }).props('subtitle')`.

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement `NDDScore.vue`**

Create `app/src/views/nddscore/NDDScore.vue`:

```vue
<template>
  <AnalysisShell
    title="NDDScore"
    :subtitle="subtitle"
    nav-label="NDDScore views"
    :tabs="tabs"
  >
    <template #meta>
      <BBadge variant="info">
        <i class="bi bi-cpu me-1" aria-hidden="true" />ML prediction layer
      </BBadge>
    </template>

    <NddScorePredictionCard
      class="mb-3"
      :release-id="releaseId"
      :version-doi="versionDoi"
      :test-auc-roc="testAucRoc"
      :brier-skill-score="brierSkillScore"
    />
    <RouterView />
  </AnalysisShell>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';
import NddScorePredictionCard from '@/components/nddscore/NddScorePredictionCard.vue';
import { fetchCurrentRelease } from '@/api/nddscore';

const subtitle =
  'Machine-learning predictions for NDD gene association and phenotype ' +
  'annotations. These predictions are separate from curated SysNDD evidence.';

const tabs = [
  { label: 'Gene predictions', to: { name: 'NDDScore' } },
  { label: 'Phenotype predictions', to: { name: 'NDDScorePhenotypePredictions' } },
  { label: 'Model card', to: { name: 'NDDScoreModelCard' } },
];

const releaseId = ref<string>('');
const versionDoi = ref<string>('');
const testAucRoc = ref<number | null>(null);
const brierSkillScore = ref<number | null>(null);

onMounted(async () => {
  try {
    const release = await fetchCurrentRelease();
    releaseId.value = String(release.release_id ?? '');
    versionDoi.value = String(release.version_doi ?? '');
    const perfRaw = release.ndd_performance_json;
    const perf = typeof perfRaw === 'string' ? JSON.parse(perfRaw) : perfRaw;
    testAucRoc.value = perf?.test?.auc_roc ?? null;
    brierSkillScore.value = perf?.test?.bss ?? null;
  } catch {
    // No active release yet — the prediction card still renders the disclaimer.
  }
});
</script>
```

- [ ] **Step 4: Implement `NddScoreGeneTable.vue`**

Create `app/src/components/nddscore/NddScoreGeneTable.vue`. Mirror `app/src/components/tables/TablesEntities.vue` for the `TableShell` + `TableSearchInput` + pagination composition. Required behavior: columns gene symbol, HGNC id, NDD score, rank, percentile, risk tier (colored pill `BBadge`), confidence tier (colored pill `BBadge`), known SysNDD gene (`BBadge` linking to `/Genes/<hgnc_id>` when true), top inheritance mode, predicted HPO count; filters search + risk tier + confidence tier + known SysNDD gene; numbered pagination; row click routes to `{ name: 'NDDScoreGeneDetail', params: { hgncIdOrSymbol } }`.

```vue
<template>
  <TableShell
    title="Gene predictions"
    :meta="`${total} genes`"
    :loading="loading"
  >
    <template #toolbar>
      <div class="ndd-gene-toolbar">
        <TableSearchInput
          v-model="search"
          placeholder="Search gene symbol or HGNC id"
          :debounce-time="500"
          @update:model-value="reload"
        />
        <select v-model="riskTier" aria-label="Risk tier" @change="reload">
          <option value="">All risk tiers</option>
          <option v-for="t in riskTiers" :key="t" :value="t">{{ t }}</option>
        </select>
        <select v-model="confidenceTier" aria-label="Confidence tier" @change="reload">
          <option value="">All confidence tiers</option>
          <option v-for="t in confidenceTiers" :key="t" :value="t">{{ t }}</option>
        </select>
        <select v-model="knownSysnddGene" aria-label="Known SysNDD gene" @change="reload">
          <option value="">All genes</option>
          <option value="true">Known SysNDD gene</option>
          <option value="false">Not in SysNDD</option>
        </select>
      </div>
    </template>

    <table class="table table-hover">
      <thead>
        <tr>
          <th>Gene</th><th>HGNC ID</th><th>NDD score</th><th>Rank</th>
          <th>Percentile</th><th>Risk tier</th><th>Confidence</th>
          <th>SysNDD</th><th>Top inheritance</th><th>Predicted HPO</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in rows"
          :key="String(row.hgnc_id)"
          class="ndd-gene-row"
          @click="openGene(row)"
        >
          <td>{{ row.gene_symbol }}</td>
          <td>{{ row.hgnc_id }}</td>
          <td>{{ formatScore(row.ndd_score) }}</td>
          <td>{{ row.rank }}</td>
          <td>{{ formatScore(row.percentile) }}</td>
          <td><BBadge :variant="riskVariant(String(row.risk_tier))">{{ row.risk_tier }}</BBadge></td>
          <td><BBadge :variant="confidenceVariant(String(row.confidence_tier))">{{ row.confidence_tier }}</BBadge></td>
          <td>
            <RouterLink
              v-if="isTrue(row.known_sysndd_gene)"
              :to="`/Genes/${row.hgnc_id}`"
              @click.stop
            >
              <BBadge variant="success">Curated</BBadge>
            </RouterLink>
            <span v-else class="text-muted">—</span>
          </td>
          <td>{{ row.top_inheritance_mode || '—' }}</td>
          <td>{{ row.n_predicted_hpo }}</td>
        </tr>
      </tbody>
    </table>

    <BPagination
      v-model="page"
      :total-rows="total"
      :per-page="pageSize"
      @update:model-value="reload"
    />
  </TableShell>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import TableShell from '@/components/table/TableShell.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import { fetchGenePredictions } from '@/api/nddscore';

const router = useRouter();
const rows = ref<Record<string, unknown>[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(25);
const loading = ref(false);
const search = ref<string | null>(null);
const riskTier = ref('');
const confidenceTier = ref('');
const knownSysnddGene = ref('');
const riskTiers = ['Very High', 'High', 'Moderate', 'Low'];
const confidenceTiers = ['High', 'Moderate', 'Low'];

function isTrue(v: unknown): boolean {
  return v === 1 || v === true || v === '1' || v === 'true';
}
function formatScore(v: unknown): string {
  const n = Number(v);
  return Number.isFinite(n) ? n.toFixed(3) : '—';
}
function riskVariant(tier: string): string {
  return { 'Very High': 'danger', High: 'warning', Moderate: 'info', Low: 'secondary' }[tier] ?? 'secondary';
}
function confidenceVariant(tier: string): string {
  return { High: 'success', Moderate: 'info', Low: 'secondary' }[tier] ?? 'secondary';
}
function openGene(row: Record<string, unknown>): void {
  router.push({ name: 'NDDScoreGeneDetail', params: { hgncIdOrSymbol: String(row.hgnc_id) } });
}

async function reload(): Promise<void> {
  loading.value = true;
  try {
    const result = await fetchGenePredictions({
      search: search.value ?? '',
      riskTier: riskTier.value,
      confidenceTier: confidenceTier.value,
      knownSysnddGene: knownSysnddGene.value,
      page: page.value,
      pageSize: pageSize.value,
    });
    rows.value = result.data;
    total.value = result.total;
  } finally {
    loading.value = false;
  }
}

onMounted(reload);
</script>

<style scoped>
.ndd-gene-toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
}
.ndd-gene-row {
  cursor: pointer;
}
</style>
```

Confirm `BPagination`/`BBadge` are globally registered (used widely). If `TablesEntities.vue` uses a project-specific pagination component (`TablePaginationControls`), use that instead for visual consistency — read `TablesEntities.vue` first and match.

- [ ] **Step 5: Run — verify pass.** Run: `cd app && npx vitest run src/views/nddscore/NDDScore.spec.ts` → PASS. Then `cd app && npm run type-check` → expected clean for the new files.

- [ ] **Step 6: Commit**

```bash
git add app/src/views/nddscore/NDDScore.vue app/src/components/nddscore/NddScoreGeneTable.vue app/src/views/nddscore/NDDScore.spec.ts
git commit -m "feat(app): NDDScore page shell + gene predictions table"
```

---

### Task 17: `NddScoreHpoTable` + `NddScoreModelCard`

**Files:**
- Create: `app/src/components/nddscore/NddScoreHpoTable.vue`
- Create: `app/src/components/nddscore/NddScoreModelCard.vue`
- Create: `app/src/components/nddscore/NddScoreModelCard.spec.ts`

- [ ] **Step 1: Write the failing test**

Create `app/src/components/nddscore/NddScoreModelCard.spec.ts`:

```ts
import { mount, flushPromises } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import NddScoreModelCard from './NddScoreModelCard.vue';

vi.mock('@/api/nddscore', () => ({
  fetchCurrentRelease: vi.fn().mockResolvedValue({
    release_id: 'nddscore_20260517_public',
    version: '2026.05.17',
    version_doi: '10.5281/zenodo.20258027',
    concept_doi: '10.5281/zenodo.20258026',
    zenodo_record_url: 'https://zenodo.org/records/20258027',
    n_genes: 19296,
    n_hpo_predictions: 44360,
    n_hpo_terms: 37,
    n_features: 48,
    ndd_performance_json: JSON.stringify({
      test: { auc_roc: 0.8877, auc_pr: 0.8965, brier: 0.1388, bss: 0.4438 },
    }),
  }),
}));

describe('NddScoreModelCard', () => {
  it('renders the performance grid, counts, and DOIs', async () => {
    const wrapper = mount(NddScoreModelCard);
    await flushPromises();
    const text = wrapper.text();
    expect(text).toContain('0.888'); // AUC-ROC
    expect(text).toContain('19296'); // gene count
    expect(text).toContain('10.5281/zenodo.20258026'); // concept DOI
    expect(text).toContain('ML prediction');
  });
});
```

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement `NddScoreModelCard.vue`**

Create `app/src/components/nddscore/NddScoreModelCard.vue`:

```vue
<template>
  <BCard no-body class="ndd-model-card">
    <div class="ndd-model-card__header">
      <i class="bi bi-cpu me-2" aria-hidden="true" />
      <span>ML prediction — model card</span>
      <BBadge v-if="release" variant="secondary" class="ms-auto">
        {{ release.release_id }}
      </BBadge>
    </div>
    <div v-if="release" class="ndd-model-card__body">
      <h3 class="h6">Test-set performance</h3>
      <div class="ndd-model-card__metrics">
        <div v-for="m in metrics" :key="m.label" class="ndd-model-card__metric">
          <span class="ndd-model-card__value">{{ m.value }}</span>
          <span class="ndd-model-card__label">{{ m.label }}</span>
        </div>
      </div>
      <h3 class="h6 mt-3">Release contents</h3>
      <ul class="ndd-model-card__counts">
        <li>{{ release.n_genes }} genes scored</li>
        <li>{{ release.n_hpo_predictions }} phenotype predictions</li>
        <li>{{ release.n_hpo_terms }} HPO terms</li>
        <li>{{ release.n_features }} model features</li>
      </ul>
      <h3 class="h6 mt-3">Provenance</h3>
      <p class="mb-1">Version: {{ release.version }}</p>
      <p class="mb-1">
        Version DOI:
        <a :href="`https://doi.org/${release.version_doi}`" target="_blank" rel="noopener">
          {{ release.version_doi }}
        </a>
      </p>
      <p class="mb-1">
        Concept DOI:
        <a :href="`https://doi.org/${release.concept_doi}`" target="_blank" rel="noopener">
          {{ release.concept_doi }}
        </a>
      </p>
      <p class="mb-1">
        <a :href="String(release.zenodo_record_url)" target="_blank" rel="noopener">
          Zenodo record
        </a>
      </p>
      <p class="ndd-model-card__intended-use">
        Intended use: NDDScore is a prioritization signal for candidate NDD genes
        and phenotype annotations. A high score is a prioritization signal, not
        proof of disease causality. NDDScore is separate from curated SysNDD
        evidence and is not an evidence tier.
      </p>
    </div>
    <div v-else class="ndd-model-card__body text-muted">
      No active NDDScore release.
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { fetchCurrentRelease } from '@/api/nddscore';

const release = ref<Record<string, unknown> | null>(null);

const metrics = computed(() => {
  if (!release.value) return [];
  const raw = release.value.ndd_performance_json;
  const perf = typeof raw === 'string' ? JSON.parse(raw) : raw;
  const t = perf?.test ?? {};
  const fmt = (v: unknown) => (Number.isFinite(Number(v)) ? Number(v).toFixed(3) : '—');
  return [
    { label: 'AUC-ROC', value: fmt(t.auc_roc) },
    { label: 'AUC-PR', value: fmt(t.auc_pr) },
    { label: 'Brier', value: fmt(t.brier) },
    { label: 'Brier Skill Score', value: fmt(t.bss) },
  ];
});

onMounted(async () => {
  try {
    release.value = await fetchCurrentRelease();
  } catch {
    release.value = null;
  }
});
</script>

<style scoped>
.ndd-model-card { border-left: 4px solid var(--bs-info, #0dcaf0); }
.ndd-model-card__header {
  display: flex; align-items: center; font-weight: 600;
  padding: 0.75rem 1rem; border-bottom: 1px solid var(--bs-border-color, #dee2e6);
}
.ndd-model-card__body { padding: 1rem; }
.ndd-model-card__metrics { display: flex; flex-wrap: wrap; gap: 1.5rem; }
.ndd-model-card__metric { display: flex; flex-direction: column; }
.ndd-model-card__value { font-size: 1.25rem; font-weight: 700; }
.ndd-model-card__label { font-size: 0.75rem; color: var(--bs-secondary-color, #6c757d); }
.ndd-model-card__intended-use { font-size: 0.85rem; margin-top: 0.75rem; }
</style>
```

- [ ] **Step 4: Implement `NddScoreHpoTable.vue`** — the phenotype-predictions table, same `TableShell` composition as `NddScoreGeneTable` (Task 16). Columns: gene, HGNC id, phenotype id, phenotype name, probability, rank for gene, passes threshold (`BBadge`), term AUC-ROC, term training support. Filters: search (gene/phenotype), phenotype id, passes-threshold. Numbered pagination. Calls `fetchHpoPredictions` from `@/api/nddscore`. Use the exact structure of `NddScoreGeneTable.vue` from Task 16 as the template — same `loading`/`rows`/`total`/`page`/`reload` pattern — only the columns, filters, and the `fetchHpoPredictions` call differ. No row click-through. Full code follows that template; key differences:

```vue
<!-- script setup excerpt — replaces the gene-specific parts -->
import { fetchHpoPredictions } from '@/api/nddscore';
// state: search, phenotypeId, passesThreshold (replacing risk/confidence/known filters)
async function reload(): Promise<void> {
  loading.value = true;
  try {
    const result = await fetchHpoPredictions({
      search: search.value ?? '',
      phenotypeId: phenotypeId.value,
      passesThreshold: passesThreshold.value,
      page: page.value,
      pageSize: pageSize.value,
    });
    rows.value = result.data;
    total.value = result.total;
  } finally {
    loading.value = false;
  }
}
```

- [ ] **Step 5: Run — verify pass.** Run: `cd app && npx vitest run src/components/nddscore/NddScoreModelCard.spec.ts` → PASS. Run `cd app && npm run type-check`.

- [ ] **Step 6: Commit**

```bash
git add app/src/components/nddscore/NddScoreHpoTable.vue app/src/components/nddscore/NddScoreModelCard.vue app/src/components/nddscore/NddScoreModelCard.spec.ts
git commit -m "feat(app): NDDScore phenotype table + model card"
```

---

### Task 18: `NddScoreGeneDetail` component

**Files:**
- Create: `app/src/components/nddscore/NddScoreGeneDetail.vue`
- Create: `app/src/components/nddscore/NddScoreGeneDetail.spec.ts`

Single-gene detail (spec §6.3 tab 2): NDD score + rank, risk/confidence tier, inheritance probabilities, top predicted HPO terms, SHAP group contributions, and links to the curated SysNDD gene/entity pages. Curated-evidence links sit in a visually distinct block from the prediction content. Receives `hgncIdOrSymbol` as a route prop.

- [ ] **Step 1: Write the failing test**

Create `app/src/components/nddscore/NddScoreGeneDetail.spec.ts`:

```ts
import { mount, flushPromises } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import NddScoreGeneDetail from './NddScoreGeneDetail.vue';

vi.mock('@/api/nddscore', () => ({
  fetchGeneDetail: vi.fn().mockResolvedValue({
    gene: {
      hgnc_id: 'HGNC:2022', gene_symbol: 'CLCN4', ndd_score: 0.9939, rank: 1,
      risk_tier: 'Very High', confidence_tier: 'High', known_sysndd_gene: 1,
      inheritance_ad_probability: 0.02, inheritance_ar_probability: 0.0,
      inheritance_xld_probability: 0.74, inheritance_xlr_probability: 0.02,
      shap_clinical: 1.06, shap_constraint: 1.9, shap_expression: 2.19,
      shap_network: 0.36, shap_conservation: 0.07, shap_other: 0.04,
    },
    hpo_predictions: [
      { phenotype_id: 'HP:0001249', phenotype_name: 'Intellectual disability', probability: 0.998 },
    ],
  }),
}));

describe('NddScoreGeneDetail', () => {
  it('renders prediction detail and a distinct curated-evidence link block', async () => {
    const wrapper = mount(NddScoreGeneDetail, {
      props: { hgncIdOrSymbol: 'CLCN4' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    });
    await flushPromises();
    const text = wrapper.text();
    expect(text).toContain('CLCN4');
    expect(text).toContain('Very High');
    expect(text).toContain('Intellectual disability');
    expect(wrapper.find('.ndd-gene-detail__curated').exists()).toBe(true);
  });
});
```

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement**

Create `app/src/components/nddscore/NddScoreGeneDetail.vue`:

```vue
<template>
  <div v-if="gene" class="ndd-gene-detail">
    <header class="ndd-gene-detail__header">
      <h2 class="h4">{{ gene.gene_symbol }}</h2>
      <BBadge variant="info"><i class="bi bi-cpu me-1" aria-hidden="true" />ML prediction</BBadge>
    </header>

    <section class="ndd-gene-detail__predictions">
      <p>
        NDD score <strong>{{ formatScore(gene.ndd_score) }}</strong> ·
        rank <strong>{{ gene.rank }}</strong> ·
        <BBadge :variant="riskVariant(String(gene.risk_tier))">{{ gene.risk_tier }}</BBadge>
        <BBadge :variant="confidenceVariant(String(gene.confidence_tier))" class="ms-1">
          {{ gene.confidence_tier }} confidence
        </BBadge>
      </p>

      <h3 class="h6">Predicted inheritance probabilities</h3>
      <ul>
        <li>AD: {{ formatScore(gene.inheritance_ad_probability) }}</li>
        <li>AR: {{ formatScore(gene.inheritance_ar_probability) }}</li>
        <li>XLD: {{ formatScore(gene.inheritance_xld_probability) }}</li>
        <li>XLR: {{ formatScore(gene.inheritance_xlr_probability) }}</li>
      </ul>

      <h3 class="h6">Top predicted HPO terms</h3>
      <ul>
        <li v-for="hpo in hpoPredictions" :key="String(hpo.phenotype_id)">
          {{ hpo.phenotype_name }} ({{ hpo.phenotype_id }}) —
          {{ formatScore(hpo.probability) }}
        </li>
      </ul>

      <h3 class="h6">SHAP group contributions</h3>
      <ul>
        <li v-for="g in shapGroups" :key="g.label">{{ g.label }}: {{ g.value }}</li>
      </ul>
    </section>

    <section class="ndd-gene-detail__curated">
      <h3 class="h6">
        <i class="bi bi-journal-check me-1" aria-hidden="true" />Curated SysNDD evidence
      </h3>
      <p class="small text-muted">
        The curated SysNDD record is the authoritative, manually reviewed evidence
        — separate from this NDDScore prediction.
      </p>
      <RouterLink :to="`/Genes/${gene.hgnc_id}`">Curated gene page</RouterLink>
    </section>
  </div>
  <div v-else-if="loaded" class="text-muted">
    No NDDScore prediction for this gene in the active release.
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { fetchGeneDetail } from '@/api/nddscore';

const props = defineProps<{ hgncIdOrSymbol: string }>();

const gene = ref<Record<string, unknown> | null>(null);
const hpoPredictions = ref<Record<string, unknown>[]>([]);
const loaded = ref(false);

function formatScore(v: unknown): string {
  const n = Number(v);
  return Number.isFinite(n) ? n.toFixed(3) : '—';
}
function riskVariant(tier: string): string {
  return { 'Very High': 'danger', High: 'warning', Moderate: 'info', Low: 'secondary' }[tier] ?? 'secondary';
}
function confidenceVariant(tier: string): string {
  return { High: 'success', Moderate: 'info', Low: 'secondary' }[tier] ?? 'secondary';
}
const shapGroups = computed(() => {
  if (!gene.value) return [];
  const g = gene.value;
  return [
    { label: 'Clinical', value: formatScore(g.shap_clinical) },
    { label: 'Constraint', value: formatScore(g.shap_constraint) },
    { label: 'Expression', value: formatScore(g.shap_expression) },
    { label: 'Network', value: formatScore(g.shap_network) },
    { label: 'Conservation', value: formatScore(g.shap_conservation) },
    { label: 'Other', value: formatScore(g.shap_other) },
  ];
});

async function load(): Promise<void> {
  loaded.value = false;
  const detail = await fetchGeneDetail(props.hgncIdOrSymbol);
  gene.value = detail.gene;
  hpoPredictions.value = detail.hpo_predictions ?? [];
  loaded.value = true;
}

onMounted(load);
watch(() => props.hgncIdOrSymbol, load);
</script>

<style scoped>
.ndd-gene-detail__header { display: flex; align-items: center; gap: 0.5rem; }
.ndd-gene-detail__curated {
  margin-top: 1.5rem;
  padding: 1rem;
  border: 1px dashed var(--bs-border-color, #dee2e6);
  border-radius: 0.375rem;
  background: var(--bs-tertiary-bg, #f8f9fa);
}
</style>
```

- [ ] **Step 4: Run — verify pass.** Run the spec → PASS. Run `cd app && npm run type-check`.

- [ ] **Step 5: Phase 4 verification gate.**

Run: `cd app && npm run lint` (or `make lint-app`) → clean.
Run: `cd app && npm run test:unit` → all NDDScore specs pass.
Run: `cd app && npm run type-check` → clean.

- [ ] **Step 6: Commit**

```bash
git add app/src/components/nddscore/NddScoreGeneDetail.vue app/src/components/nddscore/NddScoreGeneDetail.spec.ts
git commit -m "feat(app): NDDScore gene-detail view"
```

---

# Phase 5 — Admin frontend (`/ManageNDDScore`)

Read `app/src/views/admin/ManagePubtator.vue` and `ManageLLM.vue` first — `ManageNDDScore.vue` mirrors them (`AdminOperationPanel`, `useAsyncJob`, `GET /api/jobs/<job_id>/status` polling).

### Task 19: Admin API client `nddscore_admin.ts`

**Files:**
- Create: `app/src/api/nddscore_admin.ts`
- Create: `app/src/api/nddscore_admin.spec.ts`

- [ ] **Step 1: Write the failing test**

Create `app/src/api/nddscore_admin.spec.ts`:

```ts
import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { fetchNddScoreStatus, submitNddScoreImport } from './nddscore_admin';

describe('nddscore_admin api client', () => {
  afterEach(() => server.resetHandlers());

  it('fetches admin status', async () => {
    primeAuth();
    server.use(
      http.get('/api/admin/nddscore/status', () =>
        HttpResponse.json({ active_release: { release_id: 'r1' }, recent_jobs: [] })
      )
    );
    const status = await fetchNddScoreStatus();
    expect(status.active_release?.release_id).toBe('r1');
  });

  it('submits an import job and returns the unwrapped job id', async () => {
    primeAuth();
    server.use(
      http.post('/api/admin/nddscore/import', () =>
        HttpResponse.json({ job_id: ['job-xyz'], status: ['accepted'] })
      )
    );
    const result = await submitNddScoreImport({ recordId: '20258027', validateOnly: true });
    expect(result.jobId).toBe('job-xyz');
  });
});
```

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement**

Create `app/src/api/nddscore_admin.ts`:

```ts
// Administrator-only NDDScore API client. R/Plumber scalars are unwrapped
// before use (notably job_id, which axios would otherwise encode as job_id[]).
import { apiClient, unwrapScalar } from './client';

export interface NddScoreAdminStatus {
  active_release: Record<string, unknown> | null;
  recent_jobs: Record<string, unknown>[] | null;
}

export interface NddScoreZenodoComparison {
  zenodo: Record<string, unknown>;
  active_release: Record<string, unknown> | null;
  matches_active: boolean;
}

export async function fetchNddScoreStatus(): Promise<NddScoreAdminStatus> {
  return apiClient.get('/api/admin/nddscore/status');
}

export async function fetchNddScoreZenodo(
  recordId = '20258027'
): Promise<NddScoreZenodoComparison> {
  return apiClient.get('/api/admin/nddscore/zenodo', { params: { record_id: recordId } });
}

export async function submitNddScoreImport(opts: {
  recordId?: string;
  validateOnly: boolean;
}): Promise<{ jobId: string; status: string }> {
  const raw = await apiClient.post<{ job_id: unknown; status: unknown }>(
    '/api/admin/nddscore/import',
    { record_id: opts.recordId ?? '20258027', validate_only: opts.validateOnly }
  );
  return {
    jobId: String(unwrapScalar(raw.job_id as never)),
    status: String(unwrapScalar(raw.status as never)),
  };
}
```

- [ ] **Step 4: Run — verify pass.**

- [ ] **Step 5: Commit**

```bash
git add app/src/api/nddscore_admin.ts app/src/api/nddscore_admin.spec.ts
git commit -m "feat(app): NDDScore admin API client"
```

---

### Task 20: `ManageNDDScore.vue` admin page

**Files:**
- Create: `app/src/views/admin/ManageNDDScore.vue`
- Create: `app/src/views/admin/ManageNDDScore.spec.ts`

Admin operations page (spec §6.4). Reuses `AdminOperationPanel` + `useAsyncJob`. Displays current active release, DOIs, archive identity, timestamps, imported counts, performance summary, last import status/error, recent jobs. Three actions: **Check Zenodo**, **Download & validate** (`validate_only = true`), **Import & activate latest release** — the last behind an explicit confirmation modal (`BModal`) stating the previous active release stays active until activation succeeds.

- [ ] **Step 1: Write the failing test**

Create `app/src/views/admin/ManageNDDScore.spec.ts`:

```ts
import { mount, flushPromises } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import ManageNDDScore from './ManageNDDScore.vue';

vi.mock('@/api/nddscore_admin', () => ({
  fetchNddScoreStatus: vi.fn().mockResolvedValue({
    active_release: { release_id: 'nddscore_20260517_public', import_status: 'active' },
    recent_jobs: [],
  }),
  fetchNddScoreZenodo: vi.fn(),
  submitNddScoreImport: vi.fn().mockResolvedValue({ jobId: 'job-1', status: 'accepted' }),
}));

describe('ManageNDDScore.vue', () => {
  it('renders the active release and an import confirmation gate', async () => {
    const wrapper = mount(ManageNDDScore, {
      global: { stubs: { AdminOperationPanel: false, BModal: true } },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('nddscore_20260517_public');
    // The import action must require explicit confirmation, not fire directly.
    const importBtn = wrapper.find('[data-testid="ndd-import-btn"]');
    expect(importBtn.exists()).toBe(true);
    const { submitNddScoreImport } = await import('@/api/nddscore_admin');
    expect(submitNddScoreImport).not.toHaveBeenCalled();
  });

  it('submits the import job only after confirmation', async () => {
    const wrapper = mount(ManageNDDScore, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    await wrapper.find('[data-testid="ndd-import-btn"]').trigger('click');
    await (wrapper.vm as unknown as { confirmImport: () => Promise<void> }).confirmImport();
    await flushPromises();
    const { submitNddScoreImport } = await import('@/api/nddscore_admin');
    expect(submitNddScoreImport).toHaveBeenCalledWith({ validateOnly: false });
  });
});
```

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement**

Create `app/src/views/admin/ManageNDDScore.vue`:

```vue
<template>
  <div class="manage-nddscore container py-3">
    <h1 class="h3">Manage NDDScore</h1>
    <p class="text-muted">
      NDDScore is a model-derived prediction layer, separate from curated SysNDD
      evidence. Importing a release never changes curated SysNDD records.
    </p>

    <AdminOperationPanel
      title="Active NDDScore release"
      icon="graph-up-arrow"
      :meta="activeReleaseMeta"
    >
      <dl v-if="status?.active_release" class="manage-nddscore__facts">
        <div><dt>Release ID</dt><dd>{{ status.active_release.release_id }}</dd></div>
        <div><dt>Import status</dt><dd>{{ status.active_release.import_status }}</dd></div>
        <div><dt>Version DOI</dt><dd>{{ status.active_release.version_doi }}</dd></div>
        <div><dt>Concept DOI</dt><dd>{{ status.active_release.concept_doi }}</dd></div>
        <div><dt>Archive</dt><dd>{{ status.active_release.source_archive_name }}</dd></div>
        <div><dt>Checksum</dt><dd>{{ status.active_release.source_archive_checksum }}</dd></div>
        <div><dt>Activated</dt><dd>{{ status.active_release.activated_at }}</dd></div>
        <div><dt>Genes / HPO preds / terms</dt>
          <dd>{{ status.active_release.n_genes }} /
            {{ status.active_release.n_hpo_predictions }} /
            {{ status.active_release.n_hpo_terms }}</dd></div>
        <div v-if="status.active_release.last_error_message">
          <dt>Last error</dt><dd>{{ status.active_release.last_error_message }}</dd>
        </div>
      </dl>
      <p v-else class="text-muted">No active NDDScore release.</p>
    </AdminOperationPanel>

    <AdminOperationPanel title="Update from Zenodo" icon="cloud-download" class="mt-3">
      <template #actions>
        <BButton variant="outline-secondary" @click="onCheckZenodo">Check Zenodo</BButton>
        <BButton variant="outline-primary" @click="onValidateOnly">Download &amp; validate</BButton>
        <BButton
          variant="primary"
          data-testid="ndd-import-btn"
          @click="showConfirm = true"
        >
          Import &amp; activate latest release
        </BButton>
      </template>

      <div v-if="zenodo" class="manage-nddscore__zenodo">
        <p>Zenodo archive: {{ zenodo.zenodo.archive_name }}
          ({{ zenodo.zenodo.archive_bytes }} bytes)</p>
        <p>Checksum: {{ zenodo.zenodo.archive_md5 }}</p>
        <p>Matches active release: {{ zenodo.matches_active ? 'yes' : 'no' }}</p>
      </div>

      <div v-if="job.jobId.value" class="manage-nddscore__job mt-2">
        <BBadge :class="job.statusBadgeClass.value">{{ job.status.value }}</BBadge>
        <span class="ms-2">{{ job.step.value }}</span>
        <BProgress :max="100" class="mt-1">
          <BProgressBar
            :value="job.hasRealProgress.value ? (job.progressPercent.value ?? 0) : 100"
            :variant="job.progressVariant.value"
            :striped="!job.hasRealProgress.value"
          />
        </BProgress>
        <BAlert v-if="job.error.value" variant="danger" show class="mt-2">
          {{ job.error.value }}
        </BAlert>
      </div>
    </AdminOperationPanel>

    <BModal
      v-model="showConfirm"
      title="Import and activate NDDScore release"
      ok-title="Import & activate"
      ok-variant="primary"
      @ok="confirmImport"
    >
      <p>
        This downloads, verifies, validates, and imports the latest Zenodo
        release. The current active release keeps serving until the new release
        is fully validated; activation is the final atomic step. Continue?
      </p>
    </BModal>

    <BAlert v-if="feedback" :variant="feedbackVariant" show class="mt-3">
      {{ feedback }}
    </BAlert>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import { useAsyncJob } from '@/composables/useAsyncJob';
import {
  fetchNddScoreStatus,
  fetchNddScoreZenodo,
  submitNddScoreImport,
  type NddScoreAdminStatus,
  type NddScoreZenodoComparison,
} from '@/api/nddscore_admin';

const status = ref<NddScoreAdminStatus | null>(null);
const zenodo = ref<NddScoreZenodoComparison | null>(null);
const showConfirm = ref(false);
const feedback = ref('');
const feedbackVariant = ref<'info' | 'danger' | 'success'>('info');

const job = useAsyncJob((jobId: string) => `/api/jobs/${jobId}/status`);

const activeReleaseMeta = computed(() =>
  status.value?.active_release
    ? String(status.value.active_release.import_status ?? '')
    : 'none'
);

async function refreshStatus(): Promise<void> {
  status.value = await fetchNddScoreStatus();
}

async function onCheckZenodo(): Promise<void> {
  try {
    zenodo.value = await fetchNddScoreZenodo();
    feedback.value = '';
  } catch (err) {
    feedbackVariant.value = 'danger';
    feedback.value = `Zenodo check failed: ${err instanceof Error ? err.message : 'error'}`;
  }
}

async function startImport(validateOnly: boolean): Promise<void> {
  try {
    const result = await submitNddScoreImport({ validateOnly });
    job.startJob(result.jobId);
    feedbackVariant.value = 'info';
    feedback.value = validateOnly
      ? 'Download & validate job submitted.'
      : 'Import & activate job submitted.';
  } catch (err) {
    feedbackVariant.value = 'danger';
    feedback.value = `Job submission failed: ${err instanceof Error ? err.message : 'error'}`;
  }
}

async function onValidateOnly(): Promise<void> {
  await startImport(true);
}

async function confirmImport(): Promise<void> {
  showConfirm.value = false;
  await startImport(false);
}

defineExpose({ confirmImport });

onMounted(refreshStatus);
</script>

<style scoped>
.manage-nddscore__facts { display: grid; gap: 0.25rem; }
.manage-nddscore__facts div { display: flex; gap: 0.5rem; }
.manage-nddscore__facts dt { font-weight: 600; min-width: 14rem; }
.manage-nddscore__facts dd { margin: 0; }
</style>
```

Reconcile against the real `useAsyncJob` return shape (Task exploration: it returns refs, not a nested object). If `useAsyncJob` returns destructured refs (`{ jobId, status, step, ... }`), destructure them and drop the `job.` / `.value` template prefixes — match exactly how `ManagePubtator.vue` consumes it. The test's `confirmImport` expose stays regardless.

- [ ] **Step 4: Run — verify pass.** Run: `cd app && npx vitest run src/views/admin/ManageNDDScore.spec.ts` → PASS.

- [ ] **Step 5: Phase 5 verification gate.**

Run: `make lint-app` → clean. `cd app && npm run type-check` → clean. `cd app && npm run test:unit` → all NDDScore specs pass.

- [ ] **Step 6: Commit**

```bash
git add app/src/views/admin/ManageNDDScore.vue app/src/views/admin/ManageNDDScore.spec.ts
git commit -m "feat(app): ManageNDDScore admin page"
```

---

# Phase 6 — Documentation + full verification

### Task 21: Documentation updates

**Files:**
- Modify: `AGENTS.md`
- Modify: `documentation/08-development.qmd`
- Modify: `documentation/09-deployment.qmd`
- Modify: `db/migrations/README.md`

- [ ] **Step 1: Update `AGENTS.md`.** Add an "NDDScore prediction layer" subsection under the architecture invariants. Content to include:
  - The four `nddscore_*` tables and three `*_current` views (migration 023).
  - The **ML-vs-curated invariant**: NDDScore is a model-derived prediction layer, never an evidence tier / curation status / manual review; copy rules per spec §7; curated SysNDD evidence is never reclassified by NDDScore.
  - The durable `nddscore_import` async job (System B, registered in `async_job_handler_registry`), runs in the worker (needs egress for Zenodo), serialized by the `nddscore_import` MySQL advisory lock, atomic active-release switch via the `active_release_slot` generated-column unique key, active-release re-import guard.
  - `is_active` is SysNDD-controlled; the upstream `nddscore_release.json` `is_active` is ignored.

- [ ] **Step 2: Update `documentation/08-development.qmd`.** Add a "Running an NDDScore import locally" subsection: the admin `/ManageNDDScore` flow, `validate_only` dry-run vs full import, that the worker container must be restarted after changing `nddscore-*.R` or `async-job-handlers.R`, the offline test fixtures under `api/tests/testthat/fixtures/nddscore/` and the `make-fixture-archive.R` regenerator.

- [ ] **Step 3: Update `documentation/09-deployment.qmd`.** Add operator guidance: running NDDScore updates in production via the admin UI (Check Zenodo → Download & validate → Import & activate), the worker egress requirement (Zenodo), that the previous active release keeps serving until activation succeeds, all releases retained (history; no auto-pruning), and reading `import_status` / `last_error_message` on failure.

- [ ] **Step 4: Update `db/migrations/README.md`.** Add migration 023 to any migration list/table the README maintains, following the convention used for migration 020.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md documentation/08-development.qmd documentation/09-deployment.qmd db/migrations/README.md
git commit -m "docs: document NDDScore prediction layer, import job, and ML-vs-curated invariant"
```

---

### Task 22: Full verification gate

No code changes — this task runs the spec §10 gates and fixes any fallout (a regression fix is its own atomic commit).

- [ ] **Step 1: API lint.** Run: `make lint-api` → expected: clean.

- [ ] **Step 2: Full API test suite.** Run: `make test-api` → expected: all NDDScore suites pass; only the pre-existing unrelated failures recorded in project memory (`test-llm-benchmark.R`, `test-llm-judge.R`, the 4 `test-unit-entity-creation.R` status-aggregation failures) remain. Any new failure must be fixed before proceeding.

- [ ] **Step 3: Frontend gates.** Run: `make lint-app` → clean. `cd app && npm run type-check` → clean. `cd app && npm run type-check:strict` → clean for new files. `cd app && npm run test:unit` → all green.

- [ ] **Step 4: SEO prerender gate** (new public route `/NDDScore`). Run: `make verify-seo-app` → expected: pass; the new public route is handled by the prerender pipeline.

- [ ] **Step 5: Pre-commit gate.** Run: `make pre-commit` → expected: pass.

- [ ] **Step 6: Full CI parity.** Run: `make ci-local` → expected: pass. This is the handoff gate.

- [ ] **Step 7: Live smoke (manual, optional but recommended).** With `make dev` running and the worker restarted: log in as Administrator, open `/ManageNDDScore`, run **Check Zenodo**, then **Download & validate** against record `20258027`, confirm the job reaches `completed`. Then open `/NDDScore` and confirm the gene table, phenotype table, model card, and a gene-detail page render with the ML-prediction disclaimer visible.

- [ ] **Step 8: Commit any verification fixes** (only if Steps 1-6 required code changes; otherwise nothing to commit).

```bash
git add -A
git commit -m "fix: resolve NDDScore verification-gate findings"
```

---

## Self-Review (completed during planning)

**Spec coverage** — every spec section maps to tasks:
- §2 deliverable 1 (DB migration) → Task 1. §2.2 (public API) → Tasks 10-11. §2.3 (admin API + durable async job) → Tasks 8-9, 12. §2.4 (public `/NDDScore` UI) → Tasks 13-18. §2.5 (admin `/ManageNDDScore` UI) → Tasks 19-20. §2.6 (tests + docs) → distributed TDD + Task 21.
- §3 (verified dataset) → Task 1 DDL + Task 2 fixture reflect the real schema/JSON/TSV headers downloaded during planning.
- §4 (migration: 4 tables, generated-column unique key, 3 views, retention) → Task 1.
- §5.1 repository → Task 10. §5.2 importer pure functions → Tasks 3-7. §5.3 durable job (12 steps, advisory lock, guards, atomic activation) → Tasks 8-9. §5.4 public endpoints → Task 11. §5.5 admin endpoints (role on filter + handler) → Task 12.
- §6.1 nav, §6.2 routes → Task 13. §6.3 public page (shell, prediction card, 4 tabs, gene detail) → Tasks 15-18. §6.4 admin page → Task 20. §6.5 API clients → Tasks 14, 19.
- §7 copy rules → enforced in component code + asserted in `NddScorePredictionCard.spec.ts` / `NDDScore.spec.ts`.
- §8 test list → mapped: migration (Task 1 Step 3 + repo tests rely on it), active-release selection (Task 10), importer schema validation (Task 7), checksum-failure (Tasks 4-5), failed import keeps prior active (Task 9), successful import switches at final step (Task 9), active-release re-import refused / failed-id retry (Task 9), single-active-release schema enforcement (Task 8), superseded lifecycle (Task 8), concurrent-import advisory lock incl. validate_only-vs-import (Task 8 lock test — abstracted to the lock, which is payload-agnostic), `validate_only` writes nothing (Task 9), public current-release/list/detail endpoints (Tasks 10-11), admin status/submit (Task 12), frontend route+nav (Task 13), admin route requires Administrator (Task 13), disclaimer copy (Task 15), import confirmation gate (Task 20). Zenodo mocked everywhere (stubbed deps / injected `http_get`).
- §9 docs → Task 21. §10 verification → Task 22.
- §11 open questions: none — plan does not re-open decisions.

**Placeholder scan:** no `TBD`/`implement later`; every code step ships complete code. Two deliberate "mirror the template" references (NddScoreHpoTable mirrors NddScoreGeneTable; AGENTS.md/qmd doc content) give explicit, enumerated content rather than "similar to Task N" — acceptable because the template is named and the deltas are spelled out.

**Type/name consistency:** importer function names (`nddscore_fetch_zenodo_metadata`, `nddscore_extract_and_verify`, `nddscore_run_import`, etc.) are consistent across Tasks 3-12. Repository names (`nddscore_repo_*`) consistent across Tasks 10-12. API client exports (`fetchCurrentRelease`, `fetchGenePredictions`, `fetchGeneDetail`, `fetchHpoPredictions`, `fetchHpoTerms`, `fetchDownloadInfo`, `fetchNddScoreStatus`, `fetchNddScoreZenodo`, `submitNddScoreImport`) consistent across Tasks 14, 16-20. Route names (`NDDScore`, `NDDScorePhenotypePredictions`, `NDDScoreModelCard`, `NDDScoreGeneDetail`) consistent across Tasks 13, 16, 18.

**Two integration points the executor must reconcile against live code** (flagged inline, not gaps): the exact `pr_mount` idiom in `start_sysndd_api.R` (Task 11 Step 4) and the exact `useAsyncJob` return shape (Task 20 Step 3). Both are "read the neighbouring file and match" — the spec and patterns are unambiguous; only the local call syntax must be copied verbatim.
