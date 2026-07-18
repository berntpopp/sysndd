# Immutable Public Analysis-Snapshot Releases — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a read-only, immutable, content-addressed public "analysis-snapshot release" that pins the functional, phenotype, and phenotype-functional-correlation layers together with verifiable lineage and per-file SHA-256 checksums, plus a Zenodo operator archival path, a category-selected clustering submit (#574), and the #572 production lineage runbook.

**Architecture:** A release freezes canonical-JSON copies of the currently-active, coherent, lineage-verified public snapshots into three new DB tables (`analysis_snapshot_release`, `_member`, `_file`), identified by a content-addressed `release_id`. Admin builds synchronously (DB-only, fail-closed on incoherent/stale/mismatched sources); the public reads catalog/manifest/files/bundle retrieval-only. Mirrors the in-repo `nddscore_release` pattern and the `../nddscore` Zenodo flow.

**Tech Stack:** R/Plumber API (`renv`), MySQL migrations, `digest`/`jsonlite` for canonical hashing, Vue 3 + TypeScript SPA, `httr2` for the operator Zenodo script.

**Spec:** `.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md`

## Global Constraints

- Release construction is a **pure additive provenance layer**: never alter cluster membership, validation metrics, cache keys, LLM-summary validity, or recompute any analysis to publish an archive.
- Public release routes are **retrieval-only**: no compute, snapshot refresh, LLM generation, external provider calls, or DB writes. Add them to the cheap-route / external-budget isolation guards.
- Build fails **closed**: only `public_ready`, non-stale, source/schema-matching, **hard-coherence-re-checked**, reproducibility-bearing, dependency-lineage-verified snapshots may enter a release; otherwise **HTTP 400** with the exact reason (no 409 class exists). A duplicate build is idempotent (200, existing head).
- A published release is **immutable** and retained indefinitely; a later snapshot refresh mints a **new** release. DOI columns are additive external provenance, **excluded** from `content_digest`/`manifest_sha256`.
- Canonical serializer = `analysis_snapshot_canonical_json()` (`jsonlite::toJSON(auto_unbox=TRUE, null="null", dataframe="rows")`); SHA-256 via `digest::digest(x, algo="sha256", serialize=FALSE)`. `release_id = "asr_" + content_digest[:16]` (64-bit handle; full digest stored).
- Every endpoint file is mounted via `mount_endpoint()` (RFC 9457 problem+json). `require_role(req, res, "Administrator")` on admin routes. `DBI::dbBind` params `unname()`-ed; blobs bound as `list(raw)`. Namespace `dplyr::select` etc. explicitly. Use `base::get` (not `config`-masked `get`).
- Keep every touched file **< 600 lines**; split builder/manifest/files/service helpers. Approved-public data only — release payloads contain only snapshot payload data already public via `/api/analysis/*`.
- Frontend: typed clients in `app/src/api/*` only (no raw axios); errors via `extractApiErrorMessage`; Plumber scalar-array unwrap via `unwrapScalar`; `BTable` flat field keys; reactive tooltips via directive value.
- Version bump four surfaces (`app/package.json` root+lockfile, `api/version_spec.json`, `CHANGELOG.md`) per repo convention. Docs contract: `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd`, `README.md`.
- Gates before handoff: `make code-quality-audit`, `make lint-api`, `make test-api-fast` (then `make ci-local`), `cd app && npm run type-check && npm run test:unit`, `make verify-seo-app`.

---

# SLICE 0 — #572 production lineage runbook (prerequisite, no code)

### Task 0: Deploy master + force-refresh + verify lineage

**Files:** none (operator runbook; captured in `documentation/09-deployment.qmd` under Task A9).

- [ ] Deploy current `master` to the production Compose stack; restart `api`, `worker`, `worker-maintenance`.
- [ ] As Administrator: `POST /api/admin/analysis/snapshots/refresh` body `{"analysis_type":"phenotype_functional_correlations","force":true}`; watch `GET /api/admin/analysis/snapshots/status` until it reports `available`.
- [ ] Verify: `curl -s https://<host>/api/analysis/phenotype_functional_cluster_correlation | jq '.meta.snapshot.dependencies'` shows both `functional_clusters` and `phenotype_clusters` with `snapshot_id` + `payload_hash`.
- [ ] Verify fail-closed: force-refresh one cluster axis, confirm the correlation read returns 503 `dependency_snapshot_mismatch` until the correlation is rebuilt.
- [ ] Notify manuscript maintainers. **Gate:** do not build the first release until this passes.

---

# SLICE A — #573 core backend (fully detailed; its own PR)

## File structure (Slice A)

- Create `db/migrations/045_add_analysis_snapshot_release.sql` — the three release tables.
- Create `api/functions/analysis-snapshot-release-manifest.R` — pure manifest/hash/canonical-file helpers (no DB).
- Create `api/functions/analysis-snapshot-release-repository.R` — DB reads/writes (insert release+members+files in one txn; list/get/get-file; prune guard).
- Create `api/functions/analysis-snapshot-release.R` — `analysis_snapshot_release_build()` orchestrator (load+gate+materialize+persist).
- Create `api/services/analysis-snapshot-release-service.R` — admin build/publish/doi/delete + public list/get/manifest/file/bundle service wrappers (problem+json shaping).
- Modify `api/endpoints/analysis_endpoints.R` — public read routes (same sub-router as reproducibility).
- Modify `api/endpoints/admin_analysis_snapshot_endpoints.R` — admin release routes.
- Modify `api/bootstrap/load_modules.R` — register the three new function files (API + worker + MCP loaders).
- Modify `api/functions/analysis-snapshot-repository.R` — `analysis_snapshot_prune()` skip release-referenced snapshots.
- Modify the cheap-route / external-budget guard test allow/deny lists.
- Tests under `api/tests/testthat/`.

### Task A1: Migration 045 (release tables)

**Files:**
- Create: `db/migrations/045_add_analysis_snapshot_release.sql`
- Modify: `db/migrations/README.md` (bump `EXPECTED_LATEST_MIGRATION` note) and the manifest constant if one exists (`grep -rn EXPECTED_LATEST_MIGRATION api/`).
- Test: `api/tests/testthat/test-unit-analysis-snapshot-release-repository.R` (schema smoke uses the running dev DB).

**Interfaces:**
- Produces tables `analysis_snapshot_release`, `analysis_snapshot_release_member`, `analysis_snapshot_release_file` (columns per spec §5).

- [ ] **Step 1: Write the migration** (DDL exactly per spec §5; `utf8mb4_unicode_ci`; FK `created_by_user_id`→`user`; child FKs cascade).

```sql
-- Migration: 045_add_analysis_snapshot_release
-- Description: Immutable, content-addressed public analysis-snapshot releases (#573).
--   A release freezes canonical-JSON copies of the active coherent public snapshots
--   (functional/phenotype clusters + phenotype-functional correlation) with per-file
--   SHA-256 checksums and dependency lineage. Retained indefinitely; a later refresh
--   mints a NEW release. DOI columns are additive external provenance.

CREATE TABLE IF NOT EXISTS `analysis_snapshot_release` (
  `release_id` VARCHAR(64) NOT NULL,
  `release_version` VARCHAR(32) DEFAULT NULL,
  `title` VARCHAR(255) DEFAULT NULL,
  `status` ENUM('draft','published') NOT NULL DEFAULT 'draft',
  `manifest_schema_version` VARCHAR(16) NOT NULL,
  `content_digest` CHAR(64) NOT NULL,
  `manifest_sha256` CHAR(64) NOT NULL,
  `bundle_sha256` CHAR(64) NOT NULL,
  `bundle_gzip` LONGBLOB NOT NULL,
  `bundle_bytes` BIGINT NOT NULL,
  `source_data_version` VARCHAR(128) DEFAULT NULL,
  `db_release_version` VARCHAR(64) DEFAULT NULL,
  `db_release_commit` VARCHAR(64) DEFAULT NULL,
  `scope_statement` TEXT DEFAULT NULL,
  `license` VARCHAR(64) NOT NULL DEFAULT 'CC-BY-4.0',
  `file_count` INT NOT NULL DEFAULT 0,
  `total_bytes` BIGINT NOT NULL DEFAULT 0,
  `created_by_user_id` INT DEFAULT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `published_at` DATETIME(6) DEFAULT NULL,
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `zenodo_record_id` VARCHAR(32) DEFAULT NULL,
  `zenodo_record_url` VARCHAR(255) DEFAULT NULL,
  `version_doi` VARCHAR(128) DEFAULT NULL,
  `concept_doi` VARCHAR(128) DEFAULT NULL,
  `last_error_message` TEXT DEFAULT NULL,
  PRIMARY KEY (`release_id`),
  KEY `idx_asr_status_created` (`status`, `created_at`),
  KEY `idx_asr_content_digest` (`content_digest`),
  CONSTRAINT `fk_asr_created_by`
    FOREIGN KEY (`created_by_user_id`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_member` (
  `release_id` VARCHAR(64) NOT NULL,
  `analysis_type` VARCHAR(64) NOT NULL,
  `parameter_hash` CHAR(64) NOT NULL,
  `snapshot_id` BIGINT NOT NULL,
  `input_hash` CHAR(64) NOT NULL,
  `payload_hash` CHAR(64) NOT NULL,
  `schema_version` VARCHAR(16) NOT NULL,
  `reproducibility_hash` CHAR(64) DEFAULT NULL,
  `role` ENUM('layer','dependency') NOT NULL DEFAULT 'layer',
  PRIMARY KEY (`release_id`, `analysis_type`, `parameter_hash`),
  KEY `idx_asrm_snapshot` (`snapshot_id`),
  CONSTRAINT `fk_asrm_release`
    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_file` (
  `release_id` VARCHAR(64) NOT NULL,
  `file_path` VARCHAR(255) NOT NULL,
  `content_sha256` CHAR(64) NOT NULL,
  `byte_size` INT NOT NULL,
  `media_type` VARCHAR(64) NOT NULL DEFAULT 'application/json',
  `content_gzip` LONGBLOB NOT NULL,
  PRIMARY KEY (`release_id`, `file_path`),
  KEY `idx_asrf_sha256` (`content_sha256`),
  CONSTRAINT `fk_asrf_release`
    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 2: Update BOTH migration-manifest constants** in `api/functions/migration-manifest.R`: `EXPECTED_LATEST_MIGRATION` → `045_add_analysis_snapshot_release` **and** `EXPECTED_MIGRATION_COUNT` `42L → 43L` (startup validates both; bumping only the latter/former makes the API crash before serving). Update any manifest test that pins these (`grep -rn "EXPECTED_LATEST_MIGRATION\|EXPECTED_MIGRATION_COUNT" api/`).
- [ ] **Step 3: Apply on the dev DB** — `make docker-dev-db` running, restart `api` so the startup migration runner applies 045; confirm via `docker exec sysndd-api-1 Rscript -e 'DBI::dbGetQuery(...SHOW TABLES LIKE "analysis_snapshot_release%")'` (or the dev DB directly). Expected: three tables.
- [ ] **Step 4: Commit** — `git add db/migrations/045_* && git commit -m "feat(db): analysis-snapshot release tables (#573)"`.

### Task A2: Manifest + canonical-file helpers (pure, no DB)

**Files:**
- Create: `api/functions/analysis-snapshot-release-manifest.R`
- Test: `api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R`

**Interfaces:**
- Produces:
  - `ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION` (chr `"1.0"`)
  - `analysis_snapshot_release_layers()` → list of `list(analysis_type, params, files_prefix, has_reproducibility)` (default 3 manuscript layers).
  - `analysis_release_canonical_bytes(obj)` → raw (UTF-8 of `analysis_snapshot_canonical_json(obj)`).
  - `analysis_release_sha256(raw_or_chr)` → chr sha256 hex.
  - `analysis_release_content_digest(layer_entries, source_data_version, manifest_schema_version)` → chr (identity basis; layers sorted internally by `analysis_type`).
  - `analysis_release_id(content_digest)` → `paste0("asr_", substr(content_digest, 1, 16))` (64-bit readable handle; full digest stored separately).
  - `analysis_release_build_manifest(list(release_id, release_version, title, created_at, license, scope_statement, generator, source, layers, files, content_digest))` → the manifest R list (files[] excludes manifest.json + checksums.sha256).
  - `analysis_release_checksums_text(files)` → chr (`"<sha256>  <path>\n"` per file, excludes `checksums.sha256`).
  - `analysis_release_build_tar_gz(named_raw_list)` → raw. Built **once** and stored; byte-level rebuild-determinism is not required (per-file checksums + manifest are the verification anchors). Use `utils::tar` on a temp dir with sorted paths + `memCompress(type="gzip")`, or a small ustar writer; keep it simple.

- [ ] **Step 1: Write failing tests** for determinism + identity:

```r
test_that("content_digest and release_id are pure functions of scientific content", {
  entries <- list(
    list(analysis_type = "functional_clusters", input_hash = "a", payload_hash = "b", reproducibility_hash = "c", dependencies = NULL),
    list(analysis_type = "phenotype_clusters",  input_hash = "d", payload_hash = "e", reproducibility_hash = "f", dependencies = NULL)
  )
  d1 <- analysis_release_content_digest(entries, "srcv1", "1.0")
  d2 <- analysis_release_content_digest(rev(entries), "srcv1", "1.0")  # order-independent (sorted internally)
  expect_identical(d1, d2)
  expect_match(analysis_release_id(d1), "^asr_[0-9a-f]{16}$")
  # created_at / title do NOT affect identity:
  expect_false(identical(d1, analysis_release_content_digest(entries, "srcv2", "1.0")))
})

test_that("checksums text lists every file except checksums.sha256", {
  files <- list(
    list(path = "manifest.json", sha256 = "111", bytes = 3L),
    list(path = "a/payload.json", sha256 = "222", bytes = 5L),
    list(path = "checksums.sha256", sha256 = "333", bytes = 9L)
  )
  txt <- analysis_release_checksums_text(files)
  expect_match(txt, "111  manifest.json")
  expect_match(txt, "222  a/payload.json")
  expect_false(grepl("checksums.sha256", txt, fixed = TRUE))
})

test_that("tar.gz round-trips: untar yields exactly the input files/bytes", {
  payload <- list("a/x.json" = charToRaw("{\"k\":1}"), "manifest.json" = charToRaw("{}"))
  gz <- analysis_release_build_tar_gz(payload)
  d <- tempfile(); dir.create(d)
  tarfile <- file.path(d, "b.tar")
  writeBin(memDecompress(gz, type = "gzip"), tarfile)
  utils::untar(tarfile, exdir = d)
  expect_identical(readBin(file.path(d, "a/x.json"), "raw", 64L), payload[["a/x.json"]])
})
```

- [ ] **Step 2: Run tests, expect FAIL** (`docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-analysis-snapshot-release-manifest.R')"` after `docker cp`, or host `Rscript` if the shim resolves).
- [ ] **Step 3: Implement** `analysis-snapshot-release-manifest.R`. Key logic:
  - `analysis_release_content_digest`: sort `layer_entries` by `analysis_type`; build `list(manifest_schema_version, source_data_version, layers = lapply(sorted, \(e) e[c("analysis_type","input_hash","payload_hash","reproducibility_hash","dependencies")]))`; `analysis_release_sha256(analysis_release_canonical_bytes(that))`.
  - `analysis_release_build_tar_gz`: write each named raw to a temp dir (sorted paths), `utils::tar(tarfile, files, compression="none")`, then `memCompress(readBin(tarfile,"raw",...), type="gzip")`. Byte-stable rebuilds are NOT required (bundle is stored once and served verbatim); the round-trip test above is the only contract.
- [ ] **Step 4: Run tests, expect PASS.**
- [ ] **Step 5: Commit** — `feat(api): release manifest + deterministic archive helpers (#573)`.

### Task A3: Release repository (DB reads/writes)

**Files:**
- Create: `api/functions/analysis-snapshot-release-repository.R`
- Test: `api/tests/testthat/test-integration-analysis-snapshot-release-repository.R` (uses `with_test_db_transaction()`).

**Interfaces:**
- Consumes: manifest helpers (A2).
- Produces:
  - `analysis_release_insert(release_head, members, files, conn)` — one transaction; blobs `list(raw)`; returns `release_id`.
  - `analysis_release_get(release_id, include_draft = FALSE, conn)` — head row (+ parsed manifest via the stored `manifest.json` file) or NULL.
  - `analysis_release_list(status = "published", limit, offset, conn)` — head rows + member summary.
  - `analysis_release_get_file(release_id, file_path, include_draft = FALSE, conn)` — `list(bytes=raw, media_type, content_sha256)` or NULL (exact `(release_id, file_path)` match only).
  - `analysis_release_get_bundle(release_id, include_draft = FALSE, conn)` — `list(bytes=raw, sha256, filename)` or NULL.
  - `analysis_release_publish(release_id, conn)`, `analysis_release_set_doi(release_id, doi_fields, conn)`, `analysis_release_delete_draft(release_id, conn)`.
  - `analysis_release_exists(release_id, conn)` (idempotency).
  - `analysis_release_referenced_snapshot_ids(conn)` — for the prune guard.

- [ ] **Step 1: Write failing integration tests** (insert → get → list → get_file → publish → set_doi; unknown file → NULL; draft hidden unless `include_draft`).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Reads decompress `content_gzip` via `memDecompress(x, type="gzip")`. `analysis_release_get_file` selects by exact PK; no path building. All params `unname()`-ed. Insert wraps `DBI::dbWithTransaction`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** — `feat(api): analysis-release repository (#573)`.

### Task A4: Build orchestrator (load + gate + materialize + persist)

**Files:**
- Create: `api/functions/analysis-snapshot-release.R`
- Test: `api/tests/testthat/test-integration-analysis-snapshot-release-build.R`

**Interfaces:**
- Consumes: `analysis_snapshot_get_public` + `analysis_snapshot_assert_partition_coherent` (hard coherence re-check) + `analysis_snapshot_get_reproducibility`, a **new** `analysis_reproducibility_decode_raw()` (raw pre-gzip bytes, added to `analysis-reproducibility.R`), manifest helpers (A2), release repository (A3).
- Produces: `analysis_snapshot_release_build(layers = analysis_snapshot_release_layers(), title, scope_statement, license = "CC-BY-4.0", publish = TRUE, created_by = NULL, conn = NULL)` → `list(release = head, created = TRUE|FALSE)` (`created=FALSE` when an identical release already existed → idempotent).
- Error contract: `stop()` with classed conditions the service maps to **HTTP 400** (`stop_for_bad_request`, since the contract has no 409 class): `release_snapshot_not_available` (carries the failing `analysis_type` + `status_code`), `release_source_incoherent`, `release_reproducibility_missing`, `release_source_version_mismatch`, `release_dependency_lineage_mismatch`. A duplicate build is **not** an error: it returns the existing head with `created=FALSE` (service → 200).

- [ ] **Step 1: Write failing tests** (build order + gates):

```r
test_that("build refuses when any layer snapshot is not available", {
  fake_loader <- function(at, ph, conn = NULL) list(status_code = if (at == "phenotype_clusters") "snapshot_stale" else "available", manifest = ..., ...)
  expect_error(
    analysis_snapshot_release_build(loader = fake_loader, publish = TRUE),
    class = "release_snapshot_not_available"
  )
})

test_that("build refuses an available-but-incoherent snapshot and a missing reproducibility bundle", {
  with_test_db_transaction(function(conn) {
    # seed an 'available' functional snapshot whose validation set != membership set
    expect_error(analysis_snapshot_release_build(conn = conn), class = "release_source_incoherent")
  })
  with_test_db_transaction(function(conn) {
    # seed coherent snapshots but delete the functional reproducibility row
    expect_error(analysis_snapshot_release_build(conn = conn), class = "release_reproducibility_missing")
  })
})

test_that("build is idempotent by content (same snapshots -> same release_id, no duplicate row)", {
  with_test_db_transaction(function(conn) {
    # seed coherent public snapshots for the three layers ...
    r1 <- analysis_snapshot_release_build(conn = conn, publish = TRUE)
    expect_match(r1$release$release_id, "^asr_[0-9a-f]{16}$")
    expect_true(r1$created)
    r2 <- analysis_snapshot_release_build(conn = conn, publish = TRUE)
    expect_false(r2$created)
    expect_identical(r1$release$release_id, r2$release$release_id)
    expect_identical(1L, nrow(analysis_release_list(status = "published", conn = conn)))
  })
})

test_that("reproducibility.json hashes exactly to reproducibility_hash; payload_hash is a cross-checkable lineage anchor", {
  with_test_db_transaction(function(conn) {
    r <- analysis_snapshot_release_build(conn = conn)$release
    rf <- analysis_release_get_file(r$release_id, "functional_clusters/reproducibility.json", include_draft = TRUE, conn = conn)
    manifest <- jsonlite::fromJSON(rawToChar(analysis_release_get_file(r$release_id, "manifest.json", include_draft = TRUE, conn = conn)$bytes), simplifyVector = FALSE)
    fc <- Filter(function(l) l$analysis_type == "functional_clusters", manifest$layers)[[1]]
    # exact equality holds for the reproducibility bundle (stored canonical bytes):
    expect_identical(rf$content_sha256, fc$reproducibility_hash)
    # payload_hash is recorded as the lineage anchor (matches the live meta.snapshot), NOT the payload.json file hash:
    live <- analysis_snapshot_get_public("functional_clusters", analysis_snapshot_parameter_hash("functional_clusters", list(algorithm = "leiden")), conn = conn)
    expect_identical(fc$payload_hash, as.character(live$manifest$payload_hash[[1]]))
  })
})
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** with this exact **build order** (prevents hash cycles and TOCTOU drift):
  0. Open/settle one read connection; acquire the analysis-snapshot advisory lock for the correlation preset (or run steps 1–2 inside one `REPEATABLE READ` transaction) so a concurrent axis refresh can't swap a snapshot between reads. Release on exit.
  1. For each layer: `snap <- analysis_snapshot_get_public(at, ph, conn)`; if `is.null(snap)` or `snap$status_code != "available"` → `stop(structure(class = c("release_snapshot_not_available","error","condition"), message = sprintf("layer %s not available: %s", at, snap$status_code %||% "snapshot_missing")))`.
  1b. **Hard coherence re-check** per cluster layer: `available` does NOT prove coherence (the #514 gate can be `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false`). Re-run `analysis_snapshot_assert_partition_coherent(<snap membership>, <snap validation>, ..., require_coherence = TRUE)` — hard, ignoring the env — else `stop(class = "release_source_incoherent")`.
  1c. **Reproducibility presence** per cluster layer: `repro <- analysis_snapshot_get_reproducibility(snapshot_id, conn)`; if empty or no `reproducibility_hash` → `stop(class = "release_reproducibility_missing")` (the builder is best-effort: a NULL bundle still activates the snapshot, but the release requires it).
  2. Assert one shared `source_data_version` across layers (else `release_source_version_mismatch`); assert the correlation manifest's `dependencies` (`analysis_snapshot_manifest_dependencies`) equal the pinned functional+phenotype `{snapshot_id, payload_hash}` (else `release_dependency_lineage_mismatch`). Re-assert dependencies immediately before insert.
  3. Materialize per-layer files:
     - `payload.json` bytes = `analysis_release_canonical_bytes(<stored payload rows>)`, where the rows are the layer-appropriate tibbles from `snap` (`clusters` + `cluster_members`; or `correlations`; or `network_nodes` + `network_edges`). This is the file's **own** content; `content_sha256` is its own hash (NOT `payload_hash`). Record the snapshot `payload_hash`/`input_hash`/`snapshot_id` in `layer_entries` as the **lineage anchor**.
     - `reproducibility.json` bytes = the **exact pre-gzip string** `memDecompress(bundle_gzip_json, type = "gzip", asChar = TRUE)` (add helper `analysis_reproducibility_decode_raw()` to `analysis-reproducibility.R`). **Do NOT** use `analysis_reproducibility_decode()` — it runs `jsonlite::fromJSON()` and re-serialization drops the `digits = NA` precision, breaking the hash. Store/hash the raw bytes verbatim; assert `sha256(bytes) == reproducibility_hash` (test A4). Only for cluster layers.
  4. Generate `README.md` bytes (scope + verify recipe).
  5. Compute each file's `content_sha256` + `byte_size`; build `layer_entries` (`analysis_type`, `snapshot_id`, `parameter_hash`, `input_hash`, `payload_hash`, `reproducibility_hash`, `dependencies`).
  6. `content_digest` → `release_id`; if `analysis_release_exists(release_id, conn)`: read the existing head; if its stored `content_digest` matches → **return `list(release = existing, created = FALSE)`** (idempotent); if it differs → `stop()` (500-level anomaly).
  7. Build `manifest.json` (files[] excludes manifest + checksums), compute `manifest_sha256`.
  8. Build `checksums.sha256` (all files incl. manifest, excl. checksums), add as a file.
  9. Build `bundle.tar.gz` from all files, `bundle_sha256`.
  10. `analysis_release_insert(...)` in one txn (status = if publish "published" else "draft"; `published_at` when publishing). Return `list(release = head, created = TRUE)`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** — `feat(api): analysis-snapshot release build orchestrator (#573)`.

### Task A5: Service layer (problem+json shaping)

**Files:**
- Create: `api/services/analysis-snapshot-release-service.R`
- Test: `api/tests/testthat/test-unit-analysis-snapshot-release-service.R`

**Interfaces:**
- Produces: `svc_release_build`, `svc_release_publish`, `svc_release_set_doi`, `svc_release_delete_draft` (admin); `svc_release_list`, `svc_release_get`, `svc_release_manifest`, `svc_release_file`, `svc_release_bundle` (public). Uses **only the existing error classes** (`stop_for_bad_request`=400, `stop_for_not_found`=404, `stop_for_forbidden`=403 via `require_role`) — **no new 409 class** (the contract has only 400/401/403/404/500). Build-not-ready (`release_*` conditions from A4) → `stop_for_bad_request` with the condition message as `detail`; `svc_release_build` sets `res$status <- if (created) 201L else 200L` and returns the head.
- Public getters accept only `status="published"`; unknown/draft → `stop_for_not_found` (404).

- [ ] **Step 1..5**: TDD each mapping (400 detail carries the failing-layer reason; duplicate build → 200 same head; draft never returned publicly; `svc_release_file` returns `{bytes, media_type, content_sha256}`; unknown path → 404). Commit `feat(api): analysis-release service (#573)`.

### Task A6: Public read routes

**Files:**
- Modify: `api/endpoints/analysis_endpoints.R` (append routes in the existing `/api/analysis` sub-router, after the reproducibility routes).
- Test: `api/tests/testthat/test-integration-analysis-release-endpoints.R`

**Interfaces:** routes per spec §8. `latest` **before** `/<release_id>`.

- [ ] **Step 1: Write failing router tests** — build+publish a release in a test DB, then hit each route; assert: `/releases` lists it; `/releases/latest` returns it; `/releases/<id>/manifest.json` bytes hash to `manifest_sha256`; `/releases/<id>/file?path=functional_clusters/reproducibility.json` hashes to that layer's `reproducibility_hash` and `?path=functional_clusters/payload.json` hashes to its **own** `content_sha256` (matches the manifest `files[]` entry, NOT `payload_hash`); `/releases/<id>/bundle` returns `application/gzip` + `Content-Disposition attachment` and hashes to `bundle_sha256`; unknown/draft id → 404; `?path=<garbage>` → 404.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** `manifest.json` route serves the **stored** file bytes verbatim (`res$body <- bytes; res$setHeader("Content-Type","application/json")`); `/bundle` uses `@serializer octet` + Content-Disposition + `readBin`-style raw body (backup-endpoint template `services/backup-endpoint-service.R:220-269`). **File retrieval is `GET /releases/<release_id>/file` with a `path` QUERY parameter** resolved by exact `(release_id, file_path)` DB lookup — Plumber 1.3.2 has no `<path:.*>` multi-segment param, so a nested path segment would 404; the query param avoids that and has no traversal surface (exact PK match only).
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** — `feat(api): public analysis-release read routes (#573)`.

### Task A7: Admin routes

**Files:**
- Modify: `api/endpoints/admin_analysis_snapshot_endpoints.R`
- Test: `api/tests/testthat/test-integration-analysis-release-admin-endpoints.R`

**Interfaces:** routes per spec §10, all `require_role(req, res, "Administrator")`; serializer `unboxedJSON`.

- [ ] **Step 1: Failing tests** — non-admin → 403; `POST /releases` builds+publishes → 201 head; `POST /releases` again (identical content) → **200** same `release_id`, no duplicate row; a build when a layer is stale/incoherent → **400** with the failing-layer reason; `GET /releases` shows drafts; `POST /releases/<id>/publish` flips a draft; `PATCH /releases/<id>/doi` records DOI and leaves `content_digest`/`manifest_sha256` unchanged; `DELETE /releases/<id>` refuses a published release.
- [ ] **Step 2..5**: implement, pass, commit `feat(api): admin analysis-release endpoints (#573)`.

### Task A8: Loader registration, prune guard, static guards

**Files:**
- Modify: `api/bootstrap/load_modules.R` (source the 3 new function files — order: manifest → repository → release, after `analysis-snapshot-*`).
- Modify: `api/functions/analysis-snapshot-repository.R` (`analysis_snapshot_prune` excludes `snapshot_id IN (SELECT snapshot_id FROM analysis_snapshot_release_member)`).
- Modify: `api/tests/testthat/test-unit-cheap-route-isolation.R` and the external-budget guard allow-list (release routes are DB-only; assert they call no external fetcher).
- Modify: `api/tests/testthat/test-unit-endpoint-error-handler.R` if it enumerates mounted routers.
- Test: `api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R`

- [ ] **Step 1: Failing test** — a superseded snapshot referenced by a release is NOT pruned; an unreferenced one is.
- [ ] **Step 2..4**: implement + pass.
- [ ] **Step 5: Commit** — `feat(api): register release modules + prune guard + route isolation (#573)`.

### Task A9: OpenAPI + backend docs + AGENTS invariant

**Files:** `api/version_spec.json` (routes), `documentation/09-deployment.qmd` (build/publish/retention/reproducibility-boundary + Slice 0 runbook), `documentation/08-development.qmd`, `AGENTS.md` (new invariant block), `CHANGELOG.md`, version bump 4 surfaces.

- [ ] Document routes, retention, reproducibility boundary, the #572 prerequisite; add the AGENTS invariant; bump version; **Gate:** `make ci-local`. Commit `docs: analysis-snapshot releases (#573)`.

---

# SLICE B — #573 frontend (task outline; its own PR after Slice A)

**File structure:** `app/src/api/releases.ts` (+ `releases.spec.ts`), `app/src/views/analyses/DataReleases.vue` (+ spec), a `ReleaseManifestPanel.vue` component, admin `ManageAnalysisReleases.vue` (+ typed admin client), `routes.ts`, `main_nav_constants.ts`, `routes.spec.ts`, backend `/api/seo/routes` static + `generate-seo-pages.mjs` branch + fixture.

- [ ] **B1**: `releases.ts` client (`listReleases`, `getLatestRelease`, `getReleaseManifest(id)`, `getReleaseFileUrl(id,path)`, `downloadReleaseBundle(id)` via `apiClient.raw.get<Blob>(..., {responseType:'blob'})`) + `releases.spec.ts` (MSW), mirroring `about.ts`/`nddscore.ts`; unwrap via `unwrapScalar`, errors via `extractApiErrorMessage`.
- [ ] **B2**: `DataReleases.vue` (`AnalysisShell` + `useHead`) with a releases `GenericTable` (flat keys) → `SectionCard`-wrapped `ReleaseManifestPanel.vue` (`<dl>` grid styled like `NddScoreModelCard.vue`: release_id, version, source_data_version, mono hashes + copy, per-layer snapshot_id+payload_hash, dependency lineage, DOI links) + download buttons + "How to verify" disclosure. View spec asserts render + download call.
- [ ] **B3**: `routes.ts` public route `/DataReleases` (`meta.sitemap {priority:0.7, changefreq:'monthly'}`) + `main_nav_constants.ts` `analyses_dropdown` item + `routes.spec.ts` assertion.
- [ ] **B4**: admin `ManageAnalysisReleases.vue` (build/publish/record-DOI + current-coherence status; disable build unless all layers `available`) using `AuthenticatedPageShell`.
- [ ] **B5**: SEO — add `/DataReleases` to backend `/api/seo/routes` `static`; optional `buildReleaseSeo()` + `sitemap-releases.xml` + fixture; `make verify-seo-app`.
- [ ] **B6**: gates `npm run type-check`, `npm run test:unit`, `make lint-app`; commit per task.

---

# SLICE C — #573 Zenodo operator archival (task outline; its own PR after Slice A)

**File structure:** `api/scripts/package-analysis-release-zenodo.R`, `api/scripts/upload-analysis-release-zenodo.R` (or one script with subcommands), `Makefile` targets, docs in `09-deployment.qmd`. Reuse `nddscore-release-source.R` checksum helpers; mirror `../nddscore` `upload_sysndd_zenodo_dataset.py`.

- [ ] **C1**: `package-…` — read a published release (DB in-container or public API) → staging dir (`README.md`, `DATA_CARD.md`, `SCHEMA.md`, `CHANGELOG.md`, `CITATION.cff`, `datapackage.json`, `zenodo_metadata.json`, `checksums.sha256`, release files) + deterministic tarball + `.sha256`. Unit test the `datapackage.json`/`zenodo_metadata.json` builders + a safety validator (no `.env`/token/internal-path/prompt/draft/private files; verify checksums; verify extract layout).
- [ ] **C2**: `upload-…` — `ZENODO_TOKEN`, `--sandbox`, create/reuse **draft**, PUT to bucket, set metadata, print reserved DOI + draft URL; publish only with `--publish --confirm-publish`. Mirror the sibling script's functions.
- [ ] **C3**: `Makefile` targets `analysis-release-zenodo-package` / `analysis-release-zenodo-upload-draft`; operator runbook in `09-deployment.qmd`; wire the DOI record-back to `PATCH /api/admin/analysis/releases/<id>/doi`.

---

# SLICE D — #574 category-selected clustering universes (task outline; independent PR)

**File structure:** the clustering submit service (`grep -rn "jobs/clustering/submit" api/endpoints`), the gene-universe resolver (new helper `api/functions/clustering-gene-universe.R`), the async clustering job payload/dedup key, tests.

- [ ] **D1**: `clustering_resolve_category_universe(category_filter, conn)` — resolve genes with ≥1 NDD entity whose active status category ∈ `category_filter`, from `ndd_entity_view` (approved-public), dedupe HGNC; validate against `ndd_entity_status_categories_list`; unknown/empty/contradictory → `stop_for_bad_request`. Unit tests incl. a mixed-confidence gene staying included.
- [ ] **D2**: submit endpoint accepts `category_filter` (⊕ `genes`, both → 400); neither → all NDD genes. Persist+return selector, resolved distinct-gene count, sorted-HGNC SHA-256, `CLUSTER_LOGIC_VERSION` + `source_data_version`, STRING channel + threshold; include the resolved list / immutable job-input record. **Dedup key** (`job-functional-submission-service.R:86` currently keys only `{genes, algorithm}`): extend BOTH the preflight dedupe and the durable request payload to include the **normalized selector**, the sorted resolved HGNC IDs (+ their SHA-256), `algorithm`, `CLUSTER_LOGIC_VERSION`, `source_data_version`, STRING channel, and threshold — so `["Definitive"]` and `["Definitive","Moderate"]` that happen to resolve to the same current genes are **not** collapsed into one job with mismatched provenance. Keep results non-`public_ready`; category GET stays `unsupported_parameter`.
- [ ] **D3**: integration test — a `["Definitive"]` submit yields a job whose universe equals the resolved Definitive set with no client-side filter; explicit-list and no-list submissions unchanged. Docs + OpenAPI. Commit per task.

---

## Self-review (against the spec)

- **Spec coverage:** §5 tables → A1; §6 manifest/identity → A2; §7 build gates → A4; §8 public routes → A6; §9 immutability/prune guard → A4/A8; §10 admin routes → A7; §11 UI → Slice B; §12 Zenodo → Slice C; Part 2 (#574) → Slice D; Part 3 (#572) → Slice 0; §14 tests → each task's tests + A8 guards; §15 docs → A9/B5/C3. All acceptance-criteria rows (§18) map to A4/A6/A9/Slice C.
- **Placeholder scan:** Slice A is fully-stepped with code; B/C/D are explicitly task **outlines** to be expanded into their own plans at execution (each is an independent subsystem per the writing-plans scope rule) — not placeholders inside an executing task.
- **Type consistency:** `analysis_release_*` helper names, `content_digest`/`release_id`/`manifest_sha256`/`bundle_sha256`, and the `release_snapshot_not_available` / `release_source_version_mismatch` / `release_dependency_lineage_mismatch` conditions (all mapped to HTTP 400) are used consistently across A2–A7. Duplicate build is idempotent (`created=FALSE` → 200), not an error class.
- **Hashing model (locked):** each release file carries its **own** `content_sha256`; `sha256(reproducibility.json) == reproducibility_hash` exactly (stored canonical bytes); `payload.json` is the complete stored payload rows with its own hash, and the snapshot `payload_hash`/`input_hash`/`snapshot_id` are the manifest **lineage anchors** cross-checkable against the live `meta.snapshot` — the design does **not** claim `sha256(payload.json)==payload_hash` (DECIMAL round-trip makes that false; confirmed against `analysis-snapshot-builder.R:502`).

## Execution handoff

Recommended order: **Slice 0** (deploy/verify) → **Slice A** (core, its own PR) → **Slice B** + **Slice D** (parallel) → **Slice C**. Each slice = branch + plan-review → TDD → Codex diff-review → PR, per the repo workflow.
