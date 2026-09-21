# Phenotype Multi-Start Consolidation (#679) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the released phenotype partition the lowest-inertia k-means optimum among a seeded set of starts, compute k in application code, report the optimisation landscape, and move FactoMineR to 2.17 behind a drift guard.

**Architecture:** A new pure base-R module owns Ward tree -> k rule -> multi-start Hartigan-Wong consolidation -> landscape. `gen_mca_clust_obj` keeps its signature and return shape but calls that module instead of `FactoMineR::HCPC`; FactoMineR is reduced to `MCA` + `catdes`. The validator inherits the procedure because its per-k and resampling reruns already go through `gen_mca_clust_obj`.

**Tech Stack:** R 4.6, `stats::hclust`/`stats::kmeans`, FactoMineR (MCA, catdes), testthat, renv, Docker.

**Spec:** `.planning/superpowers/specs/2026-09-21-phenotype-multistart-consolidation-679-design.md`

## Global Constraints

- Namespace `dplyr::select()` / `dplyr::filter()`; use `base::get()`, never bare `get()`.
- New `functions/` files are registered in BOTH `api/bootstrap/load_modules.R` and `api/bootstrap/setup_workers.R`, in dependency order.
- Every touched handwritten file stays under 600 lines.
- `partition_validation` and `reproducibility` are excluded from `payload_hash`: new diagnostics go there, never into cluster rows.
- Defaults: `n_starts = 100` (env `ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS`), `seed = 42L`, `iter_max = 100L`, `k_min = 3L`, `k_max = 25L`, `basin_ari = 0.90`, inertia tie tolerance `1e-10` relative.
- `PHENOTYPE_PROCEDURE_VERSION = "2.0-multistart"`; `CLUSTER_LOGIC_VERSION = "2026-09-21.679-multistart"`; `validation_schema_version = "2.1"`.
- No file in this repository may mention any manuscript, journal, figure or supplement.
- Host R has no FactoMineR/cluster/RMariaDB: FactoMineR-dependent tests run in the `sysndd-api:latest` image with the worktree `api/` bind-mounted:
  `docker run --rm -v "$PWD/api":/app -w /app --entrypoint Rscript sysndd-api:latest -e "testthat::test_file('tests/testthat/<file>')"`.
- Host single-file run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/<file>')"`.
- Commits end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

---

### Task 1: Pure consolidation module + real-data regression fixture

**Files:**
- Create: `api/functions/analysis-phenotype-consolidation.R`
- Create: `api/tests/testthat/fixtures/phenotype-snapshot196-coords.csv.gz` (columns `entity_id,Dim.1..Dim.8,served_cluster`, from the public reproducibility bundle of snapshot 196)
- Create: `api/tests/testthat/test-unit-phenotype-consolidation.R`
- Create: `api/tests/testthat/test-unit-phenotype-consolidation-snapshot196.R`
- Modify: `api/tests/testthat/fixtures/README.md` (one entry for the fixture: source endpoint, snapshot id, reproducibility hash `1f75f075…716a86`)
- Modify: `api/bootstrap/load_modules.R` (insert before `functions/analysis-phenotype-functions.R`), `api/bootstrap/setup_workers.R` (same position)

**Interfaces — Produces:**
- `PHENOTYPE_PROCEDURE_VERSION` (chr)
- `phenotype_consolidation_config()` -> `list(n_starts, seed, iter_max, k_min, k_max, basin_ari)`
- `phenotype_ward_tree(coords)` -> `list(X = <matrix ordered by col 1>, tree = <hclust>, within = <num, W(k)/n for k = 1..n-1>)`
- `phenotype_select_k(within, k_min = 3L, k_max = 25L)` -> `list(k = <int>, ratio_curve = <named num, names = k>)`
- `phenotype_consolidate_multistart(X, ward_cut, k, n_starts, seed, iter_max)` -> `list(solutions = <list of list(start, start_index, cluster, centers, tot_withinss, iter, converged)>, chosen = <int index into solutions>)`
- `phenotype_consolidation_landscape(solutions, chosen, n, config)` -> list (spec "Landscape block")
- `phenotype_cluster_coords(coords, k = NULL, config = phenotype_consolidation_config())` -> `list(cluster = <named int in INPUT row order, labels 1..k by ascending Dim.1 centroid>, k, k_selected_by = "ward_within_inertia_ratio_min"|"imposed", ratio_curve, centers, within_inertia, converged, landscape, config)`
- Consumes: `adjusted_rand_index(a, b)` from `functions/analysis-phenotype-missingness.R` (run-time lookup).

- [ ] **Step 1: Build the fixture** from the already-downloaded bundle JSON (scratchpad `repro.json`): join `coords` with `membership` on `entity_id`, write gz CSV, confirm 2,017 rows and size < 100 KB.

- [ ] **Step 2: Write failing unit tests** (`test-unit-phenotype-consolidation.R`), sourcing the missingness file then the new module with `source_api_file(..., local = FALSE, envir = globalenv())`:
  - `phenotype_select_k(c(10, 6, 3, 2.7, 2.5, 2.4), 3, 5)` -> ratios `3/6, 2.7/3, 2.5/2.7`, `k == 3`; `k_max` beyond `length(within)` is capped.
  - three well-separated Gaussian blobs (`set.seed(1)`, 3 x 40 points, 2-D) -> `k == 3`, sizes 40/40/40, labels ordered by ascending first-coordinate centroid, `names(cluster)` identical to input rownames in input order, two calls `identical()`.
  - duplicate rows: blobs with every row repeated twice -> no error, same k.
  - selection order: stub solutions list through `.phenotype_select_solution()` — non-converged lower-inertia loses to converged; exact tie -> lowest start index (Ward start).
  - constructed two-basin landscape: solutions with label vectors A, A', B (A' differs from A in 1 of 100 points) -> `n_distinct_partitions == 3`, `n_basins == 2`.
  - `n < 4` -> error matching "at least 4".
  - `k = 2` imposed -> `k_selected_by == "imposed"`, two clusters.

- [ ] **Step 3: Write failing regression test** (`...-snapshot196.R`): read fixture; `fit <- phenotype_cluster_coords(X)`; assert `fit$k == 3`; `fit$landscape$ward_start$within_inertia` ~ 0.3603 (tol 2e-4); `fit$within_inertia` ~ 0.3530 (tol 2e-4) and `<=` every basin's `best_within_inertia`; sorted sizes within +-10 of `c(1121, 555, 341)`; `ARI(fit$cluster, served) < 0.5`; `n_basins == 2`; `ward_start$in_chosen_basin` FALSE; `chosen$share_of_starts > 0.6`. Legacy replica: `config$n_starts <- 0L` -> ARI vs served `== 1`. Perturbation: for seeds 1001:1005 drop 5 random rows -> ARI vs full-data chosen (common rows) `>= 0.95`.

- [ ] **Step 4: Run both on host, expect FAIL** (function not found).

- [ ] **Step 5: Implement the module** exactly per the Interfaces block and spec "New module" section. Key points: `X <- X[order(X[, 1]), , drop = FALSE]`; `tree <- stats::hclust(stats::dist(X)^2 / (2 * n), method = "ward.D")`; `within <- rev(cumsum(tree$height))`; random start `i`: `set.seed(seed + i); centers <- U[sample.int(nrow(U), k), , drop = FALSE]` with `U <- unique(X)`, skipped when `nrow(U) < k`; each run wrapped in `withCallingHandlers` (muffle + record warnings) and `tryCatch` (failed start -> dropped; Ward start failing -> `stop()`); `converged <- identical(as.integer(km$ifault), 0L)`; selection = converged pool, `w <= min(w) * (1 + 1e-10)`, lowest index; relabel with `order(order(centers[, 1]))`; return cluster in input row order.

- [ ] **Step 6: Run both test files on host, expect PASS.** Also run in the image to confirm identical numbers on R 4.6.1.

- [ ] **Step 7: Register the module** in `load_modules.R` and `setup_workers.R`; run `test-unit-helper-functions.R` and `test-unit-analysis-snapshot-validation-build.R` (loader guards).

- [ ] **Step 8: Commit** `feat(analysis): pure multi-start phenotype consolidation module (#679)`.

### Task 2: `gen_mca_clust_obj` uses the module; FactoMineR reduced to MCA + catdes

**Files:**
- Modify: `api/functions/analysis-phenotype-functions.R:36-167`
- Modify: `api/tests/testthat/test-unit-phenotype-hcpc-k.R`
- Create: `api/tests/testthat/test-unit-phenotype-hcpc-parity.R`

**Interfaces:**
- Consumes: `phenotype_cluster_coords()`, `phenotype_consolidation_config()`.
- Produces: `phenotype_catdes(data_clust, row_w)` -> `list(category = <named list of matrices>, quanti = <named list of matrices|NULL with exactly the columns "v.test","Mean in category","Overall mean","sd in category","Overall sd","p.value">)`; `gen_mca_clust_obj(...)` unchanged signature, tibble unchanged, attributes `data_driven_k` (int) and `consolidation` (landscape list + `k_ward_ratio_curve`).

- [ ] **Step 1: Parity test (container, `skip_if_not_installed("FactoMineR")`).** On the 400-row three-block synthetic matrix from the spec investigation (`set.seed(11)`), with `ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS=0`: membership from `gen_mca_clust_obj(df, cutpoint = 3)` equals `FactoMineR::HCPC(mca, nb.clust = 3, kk = Inf, consol = TRUE, graph = FALSE)$data.clust$clust` (ARI 1, identical sizes per label), and `phenotype_catdes()` `category`/`quanti` numerically equal HCPC's `desc.var` (compare values, not row names; quanti restricted to the six columns). On FactoMineR < 2.14 additionally assert auto-k equals `HCPC(nb.clust = -1)`.
- [ ] **Step 2: Update `test-unit-phenotype-hcpc-k.R`** source-text assertions: replace the `nb\.clust\s*=\s*-1` expectation with `phenotype_cluster_coords\(` and assert the body no longer contains `FactoMineR::HCPC(`. Add to the behavioural test: `attr(res, "consolidation")$n_starts_total == 101`.
- [ ] **Step 3: Run in image, expect FAIL.**
- [ ] **Step 4: Implement.** Replace the `FactoMineR::HCPC` block with:

```r
  fit <- phenotype_cluster_coords(
    mca_phenotypes$ind$coord,
    k = if (is.numeric(cutpoint) && cutpoint > 0) as.integer(cutpoint) else NULL
  )
  data_clust <- cbind.data.frame(
    mca_phenotypes$call$X,
    clust = factor(fit$cluster[rownames(mca_phenotypes$call$X)], levels = seq_len(fit$k))
  )
  desc <- phenotype_catdes(data_clust, row_w = mca_phenotypes$call$row.w.init)
```
  then substitute `data_clust` for `mca_hcpc$data.clust` and `desc$category` / `desc$quanti` for `mca_hcpc$desc.var$...`; set `attr(., "data_driven_k") <- fit$k` and `attr(., "consolidation") <- c(fit$landscape, list(k_ward_ratio_curve = fit$ratio_curve, within_inertia = fit$within_inertia, converged = fit$converged))`. Add `phenotype_catdes()` above `gen_mca_clust_obj` (passes `html.table = FALSE` only when `"html.table" %in% names(formals(FactoMineR::catdes))`; subsets quanti columns with `intersect`). Replace the long `kk = Inf` comment with a short one pointing at the consolidation module and #679.
- [ ] **Step 5: Run `test-unit-phenotype-hcpc-k.R`, `...-parity.R`, `test-unit-phenotype-validation-crossaxis.R`, `test-unit-phenotype-missingness.R` in the image, expect PASS.**
- [ ] **Step 6: Commit** `fix(analysis): multi-start consolidation + app-owned k in phenotype clustering (#679)`.

### Task 3: Validator reports procedure, selector curve and landscape; version-proof ncp diagnostic

**Files:**
- Modify: `api/functions/analysis-cluster-validation.R` (`validate_phenotype_clusters`)
- Modify: `api/tests/testthat/test-unit-phenotype-validation-crossaxis.R`

- [ ] **Step 1: Extend the cross-axis test**: `p$validation_schema_version == "2.1"`; names include `procedure_version`, `k_rule`, `k_ward_ratio_curve`, `consolidation_landscape`, `factominer_version`; `p$k_rule == "ward_within_inertia_ratio_min"`; `p$consolidation_landscape$chosen$within_inertia <= p$consolidation_landscape$ward_start$within_inertia + 1e-12`; anchor invariant unchanged; `p$ncp_recommended_1overq` is a finite integer.
- [ ] **Step 2: Run in image, expect FAIL.**
- [ ] **Step 3: Implement**: read `cons <- attr(ref, "consolidation")`; add the five fields (curve as a named list rounded to 4 dp, matching `k_decision_curve` style); compute the ncp diagnostic from `FactoMineR::MCA(wide_phenotypes_df, ncp = Inf, quali.sup, quanti.sup, graph = FALSE)$eig[, "eigenvalue"]` inside the existing `tryCatch`; bump schema to `"2.1"`; update the stale `kk = 50` comment.
- [ ] **Step 4: Run cross-axis + `test-unit-analysis-cluster-validation.R` in image, expect PASS.**
- [ ] **Step 5: Commit** `feat(analysis): serve k selector curve and consolidation landscape in phenotype validation (#679)`.

### Task 4: Provenance, reproducibility params, cache key

**Files:**
- Modify: `api/functions/analysis-snapshot-provenance-generator.R` (`analysis_snapshot_phenotype_applied_params`)
- Modify: `api/functions/analysis-reproducibility.R` (`analysis_reproducibility_phenotype_payload` bundle params)
- Modify: `api/functions/analysis-cache-fingerprint.R` (`CLUSTER_LOGIC_VERSION`, phenotype fingerprint folds in the starts env)
- Modify tests: `test-unit-analysis-snapshot-provenance.R`, `test-unit-analysis-reproducibility.R`, the cache-fingerprint test file (find with `grep -ln analysis_phenotype_cache_fingerprint api/tests/testthat`)

- [ ] **Step 1: Failing tests**: applied params contain `procedure_version`, `k_rule`, `k_min = 3L`, `k_max = 25L`, `consolidation_method = "multistart_kmeans"`, `consolidation_n_starts`, `consolidation_seed = 42L`, `consolidation_iter_max = 100L`, `kmeans_algorithm = "Hartigan-Wong"`, `factominer_version`, `r_version`; bundle params contain `procedure_version`, `consolidation_n_starts`, `consolidation_seed`, `within_inertia`; fingerprint changes when `ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS` changes.
- [ ] **Step 2: Run, expect FAIL. Step 3: Implement** (config values read from `phenotype_consolidation_config()` guarded by `exists(..., mode = "function")` so minimal test envs degrade to `NA`). **Step 4: PASS. Step 5: Commit** `feat(analysis): record phenotype procedure provenance and key the cache on it (#679)`.

### Task 5: Continuity against the previous public snapshot

**Files:**
- Modify: `api/functions/analysis-snapshot-coherence.R` (add `analysis_snapshot_phenotype_continuity()`)
- Modify: `api/functions/analysis-snapshot-builder.R` (phenotype branch: `val$partition$continuity <- ...` before the payload is assembled)
- Create: `api/tests/testthat/test-unit-analysis-snapshot-continuity.R`
- Create: `api/tests/testthat/test-integration-analysis-snapshot-continuity.R`

**Interfaces — Produces:** `analysis_snapshot_phenotype_continuity(clusters, conn = NULL, query_fn = db_execute_query)` -> `list(status = "ok"|"no_previous_snapshot"|"unavailable", previous_snapshot_id, n_common_entities, ari, per_cluster_best_jaccard = <named list>, message)`.

- [ ] **Step 1: Unit tests with an injected `query_fn`**: identical membership -> `ari == 1`; permuted labels -> `ari == 1` (label-invariant); no manifest row -> `no_previous_snapshot`; `query_fn` throwing -> `unavailable` and no error.
- [ ] **Step 2: Integration test** (guarded by the existing `skip_if_missing_*_schema()` helper, inside `with_test_db_transaction()`): insert a public-ready `phenotype_clusters` manifest + member rows, call with the real `db_execute_query`, expect `status == "ok"` and the right `previous_snapshot_id`. Required because a stub cannot see SQL.
- [ ] **Step 3: Implement** — two parameterised queries (latest public-ready manifest id for `analysis_type = 'phenotype_clusters'`; members for that id and the phenotype `cluster_kind` value used by `analysis_snapshot_build_cluster_rows`), `adjusted_rand_index` over common entity ids, per-cluster max Jaccard; whole body in `tryCatch`.
- [ ] **Step 4: Run unit on host + integration via `make test-db-schema` DB or a scratch MySQL; PASS. Step 5: Commit** `feat(analysis): report partition continuity against the previous snapshot (#679)`.

### Task 6: Frontend type + MCP/schema surfaces

**Files:**
- Modify: `app/src/api/analysis.ts` (`ClusterValidation`: optional `procedure_version`, `k_rule`, `k_ward_ratio_curve`, `consolidation_landscape`, `continuity`, `factominer_version`)
- Check (modify only if they enumerate validation fields): `grep -rn "k_decision_curve" api/ mcp/ app/src`

- [ ] **Step 1:** add the optional fields with a `ConsolidationLandscape` interface mirroring the spec block. **Step 2:** `cd app && npm run type-check`. **Step 3: Commit** `feat(app): type the phenotype consolidation landscape (#679)`.

### Task 7: FactoMineR 2.13 -> 2.17 behind a drift guard

**Files:**
- Create: `api/tests/testthat/test-unit-phenotype-package-drift-guard.R`
- Modify: `api/renv.lock` (FactoMineR 2.17; add `irlba`, `showtext`, `sysfonts`, `showtextdb`)
- Modify: `api/Dockerfile` only if system libraries are missing for `sysfonts`/`showtext`

- [ ] **Step 1: Drift guard first, on 2.13**: fixed synthetic input (400 rows, `set.seed(11)`) -> assert `data_driven_k == 3`, cluster sizes, `round(sum(abs(mca$ind$coord)), 6)` and `round(abs(mca$ind$coord[1:5, 1]), 8)` (absolute values: SVD sign is not guaranteed across LAPACK/irlba), six quanti columns. Record values under 2.13 in the image; commit the test green.
- [ ] **Step 2:** run the same test with the scratch 2.17 library on `.libPaths()` -> must be green unchanged. This is the go/no-go for the bump.
- [ ] **Step 3:** generate lock records for the five packages with `renv::record()`/`renv::snapshot(packages = ...)` inside the image; FactoMineR as a URL remote to `https://packagemanager.posit.co/cran/2026-09-15/src/contrib/FactoMineR_2.17.tar.gz` (verify 200 with `curl -I`), the four imports resolved from the pinned 2026-05-08 repository.
- [ ] **Step 4:** `docker build -t sysndd-api:679 api/` (BuildKit cache makes the restore incremental); in the new image assert `packageVersion("FactoMineR") == "2.17"` and run all phenotype test files.
- [ ] **Step 5: Gate.** Green -> commit `build(api): FactoMineR 2.17 with package-drift guard (#679)`. Not green after reasonable effort -> revert the lock change, keep the guard + a call-site comment that the pin is now a convenience rather than a correctness requirement, and record the follow-up in the PR body.

### Task 8: Docs, changelog, full verification, draft PR

**Files:** `.agents/skills/sysndd-analysis-snapshots/SKILL.md`, `.agents/skills/sysndd-analysis-snapshots/references/cluster-soundness-508-512.md`, `documentation/02-web-tool.qmd` (phenotype method paragraph), `documentation/09-deployment.qmd` (env var + runbook note), `CHANGELOG.md` (`[Unreleased]`), `scripts/code-quality-file-size-baseline.tsv` only if needed.

- [ ] **Step 1:** grep `api/tests/` for any heading/phrase guard on the docs being edited before moving text.
- [ ] **Step 2:** write docs (procedure, env var `ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS`, landscape/continuity fields, deploy = membership-change runbook, labels may renumber).
- [ ] **Step 3: End-to-end** in the image: production-shaped synthetic matrix through `gen_mca_clust_obj` + `validate_phenotype_clusters` (small `n_resamples`), assert anchor invariant and coherent `reference_members`; repeat under 2.17.
- [ ] **Step 4:** `make code-quality-audit`, `make lint-api`, `make test-api-fast`, `cd app && npm run type-check && npm run test:unit` (TMPDIR on disk), then `make ci-local` if time allows.
- [ ] **Step 5:** push branch, `gh pr create --draft` with summary, evidence table, test results, deploy notes, `Closes #679`.
