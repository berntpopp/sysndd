# Cluster-Analysis Soundness & Reproducibility (#508–#512) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the two-axis cluster analysis mathematically sound and self-reproducing: one unit-free null-calibrated separation z-score on both axes, feature-clean MCA, a consistent HCPC k-curve with true consolidation, text-mining-free null-benchmarked modularity, and a reproducibility bundle.

**Architecture:** Additive validation fields (excluded from `payload_hash`) land first with zero cluster-hash / LLM-cache churn (Wave 1); membership-changing method upgrades follow with a coordinated snapshot refresh + LLM regeneration (Wave 2). New statistics live in small, cohesive, worker-only modules; existing functions get minimal, surgical edits.

**Tech Stack:** R/Plumber (`FactoMineR`, `igraph`, `cluster`, `diptest`, `STRINGdb`), MySQL migrations, Vue 3 + TS frontend, MCP sidecar, `renv`.

## Global Constraints

- No manuscript references in any repository artifact; frame around the pipeline + served cross-axis interpretation. (repo rule)
- Every touched file stays < 600 lines; extract cohesive helpers rather than growing a file. `analysis-snapshot-builder.R` is already 577 lines — put new logic in new files.
- Cluster-validation / null-model / dip / repro-bundle code is **worker/heavy-path only**; never invoked on a public request. Public reads stay DB-only.
- Register every new `functions/*.R` in `api/bootstrap/load_modules.R` (single loader for API + worker). **Restart the worker container** after changing worker-executed code before a refresh reflects it.
- Determinism: every null/resample is `set.seed`-controlled (base seed 42 + offset). Cluster hashes must stay reproducible.
- `analysis_snapshot_payload_hash` excludes `partition_validation` (`analysis-snapshot-builder.R:493-494`) — Wave-1 additions must stay inside the validation block / new child rows, never the hashed payload.
- New migration is `041_add_analysis_reproducibility.sql`; update `EXPECTED_LATEST_MIGRATION` (`api/functions/migration-manifest.R:5`) + the 3 asserting tests (`test-unit-analysis-snapshot-migration.R:8`, `test-unit-core-views-manifest.R:13`, `test-unit-migration-runner.R:250`) + the runner min-count.
- `validation_schema_version` "1.0"→"2.0"; `ANALYSIS_SNAPSHOT_SCHEMA_VERSION` "1.1"→"1.2".
- Verify in the running container (`sysndd-api-1`, `sysndd-worker-1`); host R lacks `FactoMineR`/`igraph`/`RMariaDB`. Tests dir is not bind-mounted — `docker cp` or rebuild to run tests in-container.
- STRING channel default `experimental,database` (text-mining excluded, per decision).

---

## WAVE 1 — additive rigor (no `cluster_hash` change, no LLM regen)

### Task 1: `analysis-null-models.R` — shared null-calibrated statistics

**Files:**
- Create: `api/functions/analysis-null-models.R`
- Modify: `api/bootstrap/load_modules.R` (register after `analysis-cluster-validation.R`, line ~110)
- Modify: `api/renv.lock` (add `diptest`) via `renv::install("diptest"); renv::snapshot()`
- Test: `api/tests/testthat/test-unit-analysis-null-models.R`

**Interfaces — Produces:**
- `modularity_null_zscore(graph, membership, weights, n_null = 200L, seed = 42L, resolution = 1.0)` → `list(q_obs, q_null_mean, q_null_sd, z, p_empirical, n_null, null_model = "degree_preserving_configuration")`
- `silhouette_null_zscore(coords, membership, n_null = 1000L, seed = 42L)` → `list(sil_obs, sil_null_mean, sil_null_sd, z, p_empirical, n_null, null_model = "label_permutation")`
- `dip_unimodality(dist_vector)` → `list(dip_statistic, p_value, interpretation)` (`interpretation ∈ {"unimodal_continuum","multimodal_discrete","borderline"}`)
- `knn_similarity_graph(coords, k = 15L, mutual = TRUE)` → weighted `igraph` (Gaussian local-bandwidth weights on a mutual-kNN graph)

- [ ] **Step 1: Write the failing tests**

```r
# api/tests/testthat/test-unit-analysis-null-models.R
source_api_file("functions/analysis-null-models.R", local = FALSE)

test_that("modularity_null_zscore is deterministic, sign-correct, p in (0,1]", {
  set.seed(1)
  g <- igraph::make_full_graph(8) %du% igraph::make_full_graph(8)  # 2 clear communities
  g <- igraph::add_edges(g, c(1, 9))                               # one bridge
  igraph::E(g)$w <- 1
  memb <- c(rep(1L, 8), rep(2L, 8))
  r1 <- modularity_null_zscore(g, memb, weights = igraph::E(g)$w, n_null = 50L, seed = 42L)
  r2 <- modularity_null_zscore(g, memb, weights = igraph::E(g)$w, n_null = 50L, seed = 42L)
  expect_equal(r1$z, r2$z)                       # deterministic
  expect_gt(r1$z, 2)                             # planted structure >> null
  expect_true(r1$p_empirical > 0 && r1$p_empirical <= 1)
  expect_identical(r1$null_model, "degree_preserving_configuration")
})

test_that("silhouette_null_zscore standardizes vs label permutation", {
  set.seed(2)
  coords <- rbind(matrix(rnorm(100, 0), ncol = 2), matrix(rnorm(100, 6), ncol = 2))
  memb <- c(rep(1L, 50), rep(2L, 50))
  r <- silhouette_null_zscore(coords, memb, n_null = 200L, seed = 42L)
  expect_gt(r$z, 3)
  expect_identical(r$null_model, "label_permutation")
})

test_that("dip_unimodality flags bimodal vs unimodal", {
  uni <- dip_unimodality(as.vector(dist(rnorm(200))))
  bi  <- dip_unimodality(as.vector(dist(c(rnorm(100, 0), rnorm(100, 10)))))
  expect_gt(uni$p_value, 0.1)
  expect_lt(bi$p_value, 0.05)
})

test_that("knn_similarity_graph returns a weighted mutual-kNN igraph", {
  coords <- matrix(rnorm(60), ncol = 3)
  g <- knn_similarity_graph(coords, k = 5L, mutual = TRUE)
  expect_s3_class(g, "igraph")
  expect_true(!is.null(igraph::E(g)$weight))
  expect_equal(igraph::vcount(g), nrow(coords))
})
```

- [ ] **Step 2: Run to verify it fails** — `docker cp` test in, then
`docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-analysis-null-models.R')"` → FAIL (functions not found).

- [ ] **Step 3: Implement `api/functions/analysis-null-models.R`**

```r
# functions/analysis-null-models.R
#
# Shared null-calibrated separation statistics for cluster validation.
# Worker/heavy-path only — never on a public request. Deterministic (seeded).
#
# The two axes report a common, unit-free footing:
#   - graph  -> modularity z-score vs a degree-preserving configuration-model null
#   - points -> silhouette  z-score vs a label-permutation null
# plus a representation-agnostic dip test of unimodality (continuum vs discrete),
# and a kNN-graph builder so the SAME index (modularity z) is available on the
# phenotype embedding as well.
#
# Refs: Guimera/Sales-Pardo/Amaral 2004 (Q on random graphs); Miyauchi & Kawase
# 2016 (Z-modularity); Traag et al. 2019 (Leiden); Rousseeuw 1987 (silhouette);
# Hartigan & Hartigan 1985 (dip test); von Luxburg 2007 (mutual-kNN graphs).

#' Degree-preserving configuration-model modularity z-score.
#' Rewire keeps the (unweighted) degree sequence; the observed weight multiset is
#' permuted onto the null topology and each replicate is re-restricted to its
#' largest component so Q_obs and Q_null share a connected substrate.
modularity_null_zscore <- function(graph, membership, weights,
                                   n_null = 200L, seed = 42L, resolution = 1.0) {
  q_obs <- igraph::modularity(graph, membership, weights = weights, resolution = resolution)
  ecount <- igraph::ecount(graph)
  niter <- max(100L, 10L * ecount)
  memb_by_name <- stats::setNames(membership, igraph::V(graph)$name)
  q_null <- vapply(seq_len(n_null), function(i) {
    set.seed(seed + i)
    h <- igraph::rewire(graph, with = igraph::keeping_degseq(loops = FALSE, niter = niter))
    igraph::E(h)$weight <- sample(weights)                 # permute weight multiset
    h <- igraph::largest_component(h)
    mm <- memb_by_name[igraph::V(h)$name]                  # carry labels to kept nodes
    igraph::modularity(h, as.integer(factor(mm)),
                       weights = igraph::E(h)$weight, resolution = resolution)
  }, numeric(1))
  sdv <- stats::sd(q_null)
  list(
    q_obs = q_obs, q_null_mean = mean(q_null), q_null_sd = sdv,
    z = if (is.finite(sdv) && sdv > 0) (q_obs - mean(q_null)) / sdv else NA_real_,
    p_empirical = (1 + sum(q_null >= q_obs)) / (n_null + 1),
    n_null = n_null, null_model = "degree_preserving_configuration"
  )
}

#' Label-permutation silhouette z-score (preserves cluster sizes).
silhouette_null_zscore <- function(coords, membership, n_null = 1000L, seed = 42L) {
  d <- stats::dist(coords)
  sil_obs <- mean(cluster::silhouette(as.integer(membership), d)[, "sil_width"])
  sil_null <- vapply(seq_len(n_null), function(i) {
    set.seed(seed + i)
    mean(cluster::silhouette(sample(as.integer(membership)), d)[, "sil_width"])
  }, numeric(1))
  sdv <- stats::sd(sil_null)
  list(
    sil_obs = sil_obs, sil_null_mean = mean(sil_null), sil_null_sd = sdv,
    z = if (is.finite(sdv) && sdv > 0) (sil_obs - mean(sil_null)) / sdv else NA_real_,
    p_empirical = (1 + sum(sil_null >= sil_obs)) / (n_null + 1),
    n_null = n_null, null_model = "label_permutation"
  )
}

#' Dip test of unimodality on a pairwise-distance vector.
dip_unimodality <- function(dist_vector) {
  x <- as.numeric(dist_vector)
  x <- x[is.finite(x)]
  if (length(x) < 4L) {
    return(list(dip_statistic = NA_real_, p_value = NA_real_, interpretation = "undefined"))
  }
  dt <- diptest::dip.test(x)
  interp <- if (is.na(dt$p.value)) "undefined"
            else if (dt$p.value < 0.05) "multimodal_discrete"
            else if (dt$p.value > 0.10) "unimodal_continuum"
            else "borderline"
  list(dip_statistic = unname(dt$statistic), p_value = dt$p.value, interpretation = interp)
}

#' Mutual-kNN similarity graph with local-bandwidth Gaussian weights.
knn_similarity_graph <- function(coords, k = 15L, mutual = TRUE) {
  n <- nrow(coords)
  k <- min(as.integer(k), n - 1L)
  dm <- as.matrix(stats::dist(coords))
  sigma <- apply(dm, 1, function(r) sort(r)[k + 1L])       # local bandwidth = dist to k-th nn
  sigma[sigma == 0] <- .Machine$double.eps
  adj <- matrix(0, n, n)
  for (i in seq_len(n)) {
    nn <- order(dm[i, ])[2:(k + 1L)]
    adj[i, nn] <- 1
  }
  keep <- if (isTRUE(mutual)) (adj * t(adj)) else pmax(adj, t(adj))
  w <- exp(-(dm^2) / (sigma %o% sigma))
  w[keep == 0] <- 0
  diag(w) <- 0
  g <- igraph::graph_from_adjacency_matrix(w, mode = "undirected", weighted = TRUE, diag = FALSE)
  igraph::V(g)$name <- rownames(coords) %||% as.character(seq_len(n))
  g
}
```

- [ ] **Step 4: Register + add dependency**
Add `"functions/analysis-null-models.R",` to `api/bootstrap/load_modules.R` right after the `analysis-cluster-validation.R` line. On the host: `cd api && Rscript --no-init-file -e 'renv::install("diptest"); renv::snapshot()'` (or add to the container image). Guard-source `diptest` in the module header comment.

- [ ] **Step 5: Run tests to verify pass** — same `docker exec` command → PASS.

- [ ] **Step 6: Commit**
```bash
git add api/functions/analysis-null-models.R api/bootstrap/load_modules.R api/renv.lock api/tests/testthat/test-unit-analysis-null-models.R
git commit -m "feat(analysis): null-calibrated separation statistics (modularity-z, silhouette-z, dip, kNN graph) (#511)"
```

---

### Task 2: Functional modularity null + giant-component (Wave-1 reporting, on current graph)

**Files:**
- Modify: `api/functions/analysis-cluster-validation.R` (`validate_functional_clusters`, L61-121)
- Test: `api/tests/testthat/test-unit-analysis-cluster-validation.R` (extend)

**Interfaces — Consumes:** `modularity_null_zscore`, `dip_unimodality` (Task 1). **Produces:** extended `$partition` list with `modularity_z`, `modularity_p_empirical`, `null_model`, `n_null`, `giant_component`, `dip_statistic`, `dip_p`, `separation_z`.

- [ ] **Step 1: Write failing test** — assert the new keys exist, `giant_component` records `n_isolates`/`n_components`/`node_retention`, `separation_z == modularity_z`, and `n_null` honors `ANALYSIS_MODULARITY_NULL_N`.

```r
test_that("validate_functional_clusters reports modularity z + giant component", {
  # small synthetic graph via a stubbed build_string_subgraph (see helper)
  with_stub_string_subgraph(two_community_graph(), {
    v <- validate_functional_clusters(letters[1:16], n_resamples = 5L)
  })
  p <- v$partition
  expect_true(all(c("modularity_z","modularity_p_empirical","giant_component",
                    "dip_statistic","dip_p","separation_z") %in% names(p)))
  expect_equal(p$separation_z, p$modularity_z)
  expect_true(all(c("n_isolates","n_components","node_retention") %in% names(p$giant_component)))
})
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** — in `validate_functional_clusters`, after `full_membership` / `modularity`:
```r
  n_null <- as.integer(Sys.getenv("ANALYSIS_MODULARITY_NULL_N", "200"))
  comp <- igraph::components(subgraph)
  lcc  <- igraph::largest_component(subgraph)
  gc <- list(
    n_nodes = igraph::vcount(lcc), n_edges = igraph::ecount(lcc),
    n_isolates = sum(igraph::degree(subgraph) == 0L),
    n_components = comp$no,
    node_retention = igraph::vcount(lcc) / max(1L, igraph::vcount(subgraph)),
    edge_retention = igraph::ecount(lcc) / max(1L, igraph::ecount(subgraph))
  )
  # modularity z computed on the LCC (Q_obs recomputed on LCC for a connected substrate)
  lcc_memb <- .leiden_membership(lcc, resolution, seed)
  mz <- modularity_null_zscore(lcc, lcc_memb, weights = igraph::E(lcc)$combined_score,
                               n_null = n_null, seed = seed, resolution = resolution)
  # dip on graph distance (1 - normalized weight) over the LCC
  w <- igraph::E(lcc)$combined_score
  dip <- dip_unimodality(1 - (w - min(w)) / (max(w) - min(w) + 1e-9))
```
Add to the returned `$partition`: `modularity_z = mz$z, modularity_p_empirical = mz$p_empirical, null_model = mz$null_model, n_null = mz$n_null, giant_component = gc, dip_statistic = dip$dip_statistic, dip_p = dip$p_value, separation_z = mz$z, validation_schema_version = "2.0"`.

- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** `feat(analysis): degree-preserving modularity null + giant-component reporting (#510)`.

---

### Task 3: HCPC k-selection curve consistency + honest reporting + comment fix

**Files:**
- Modify: `api/functions/analysis-phenotype-functions.R` (L52-62 comment; expose ncp/procedure)
- Modify: `api/functions/analysis-cluster-validation.R` (`validate_phenotype_clusters`, L170-177 curve)
- Test: `api/tests/testthat/test-unit-phenotype-hcpc-k.R` (extend)

**Interfaces — Produces:** `$partition` gains `k_decision_curve` (relative inertia loss per k), `k_selected`, `silhouette_interpretation`; `k_selection_curve[k_selected]` equals `mean_silhouette` to tolerance because it re-runs the exact HCPC procedure.

- [ ] **Step 1: Write failing test**
```r
test_that("k_selection_curve matches the reported partition at k_selected", {
  v <- validate_phenotype_clusters(demo_phenotype_matrix(), n_resamples = 3L)
  p <- v$partition
  expect_true(!is.null(p$k_decision_curve))
  expect_equal(as.numeric(p$k_selection_curve[[as.character(p$k)]]),
               p$mean_silhouette, tolerance = 1e-6)
  expect_match(p$silhouette_interpretation, "continuum|weak|structure")
})
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** — replace the Ward-cut curve (L170-177) with a curve that re-runs the actual HCPC procedure at each k on the same MCA object, scoring silhouette on `res$data.clust$clust` in MCA-coord space, and read HCPC's relative-inertia-loss for the decision curve:
```r
  mca_obj <- FactoMineR::MCA(wide_phenotypes_df, ncp = ncp, quali.sup = quali_sup_var,
                             quanti.sup = quanti_sup_var, graph = FALSE)
  coords <- mca_obj$ind$coord; rownames(coords) <- entity_ids
  d <- stats::dist(coords[keep, , drop = FALSE])
  ks <- 2:min(10L, n_assigned - 1L)
  k_curve <- stats::setNames(lapply(ks, function(k) {
    hc <- FactoMineR::HCPC(mca_obj, nb.clust = k, kk = Inf, consol = TRUE, graph = FALSE)
    lab <- as.integer(hc$data.clust$clust)[keep]
    mean(cluster::silhouette(lab, d)[, "sil_width"])
  }), as.character(ks))
  # decision curve: HCPC relative inertia loss (Krzanowski-Lai style) from the Ward tree heights
  hc_full <- FactoMineR::HCPC(mca_obj, nb.clust = -1, kk = Inf, consol = TRUE, graph = FALSE)
  ig <- rev(hc_full$call$t$tree$height)
  intra <- rev(cumsum(rev(ig)))
  decision <- stats::setNames(as.list(round(abs(diff(intra) / intra[-length(intra)])[seq_along(ks)], 4)), as.character(ks))
  band <- if (sil_mean <= 0.25) "no_substantial_structure_continuum"
          else if (sil_mean <= 0.5) "weak_structure" else "reasonable_structure"
```
Add `k_decision_curve = decision, k_selected = n_clusters, silhouette_interpretation = band, consolidation = TRUE`. Fix `analysis-phenotype-functions.R:60` comment to state consolidation runs only when `kk = Inf` (Wave 2 flips `kk`; in Wave 1 keep the curve re-running the same config the production call uses). **Wave-1 note:** if production still uses `kk=50` (no consol) until Task 10, re-run the curve with the *production* config so it stays consistent; parameterize the HCPC call from a single `hcpc_config` list shared with `gen_mca_clust_obj`.

- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** `fix(analysis): consistent HCPC k-selection curve + inertia-loss decision curve + honest silhouette band (#509)`.

---

### Task 4: Phenotype silhouette-z + dip + shared modularity-z (cross-axis footing)

**Files:**
- Modify: `api/functions/analysis-cluster-validation.R` (`validate_phenotype_clusters`)
- Test: `api/tests/testthat/test-unit-phenotype-hcpc-k.R` (extend)

**Interfaces — Consumes:** `silhouette_null_zscore`, `dip_unimodality`, `knn_similarity_graph`, `modularity_null_zscore` (Task 1). **Produces:** `$partition` gains `silhouette_z`, `silhouette_p_empirical`, `dip_statistic`, `dip_p`, `shared_modularity_z`, `separation_z = silhouette_z`.

- [ ] **Step 1: Write failing test** — assert keys present, `separation_z == silhouette_z`, `shared_modularity_z` finite for ≥2 clusters.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — inside the `n_clusters >= 2` branch:
```r
  sz <- silhouette_null_zscore(coords[keep, , drop = FALSE], memb_int,
                               n_null = as.integer(Sys.getenv("ANALYSIS_SILHOUETTE_NULL_N", "1000")), seed = seed)
  dip <- dip_unimodality(as.vector(d))
  kg <- knn_similarity_graph(coords[keep, , drop = FALSE],
                             k = as.integer(Sys.getenv("ANALYSIS_PHENOTYPE_KNN_K", "15")))
  smz <- tryCatch(modularity_null_zscore(kg, memb_int, weights = igraph::E(kg)$weight,
                                         n_null = as.integer(Sys.getenv("ANALYSIS_MODULARITY_NULL_N", "200")), seed = seed),
                  error = function(e) list(z = NA_real_))
```
Add `silhouette_z = sz$z, silhouette_p_empirical = sz$p_empirical, dip_statistic = dip$dip_statistic, dip_p = dip$p_value, shared_modularity_z = smz$z, separation_z = sz$z, validation_schema_version = "2.0"`.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** `feat(analysis): phenotype silhouette-z, dip, and shared modularity-z on MCA kNN graph (#511)`.

---

### Task 5: Reproducibility bundle — migration, storage, builder, endpoints

**Files:**
- Create: `db/migrations/041_add_analysis_reproducibility.sql`
- Create: `api/functions/analysis-reproducibility.R` (bundle build + hash; keep builder < 600)
- Create: `api/endpoints/analysis_reproducibility_endpoints.R`
- Modify: `api/functions/migration-manifest.R:5`; `api/functions/analysis-snapshot-repository.R` (write repro row); `api/functions/analysis-snapshot-builder.R` (call bundle build); `api/bootstrap/mount_endpoints.R` (mount via `mount_endpoint`); `api/bootstrap/load_modules.R`
- Modify tests: `test-unit-analysis-snapshot-migration.R:8`, `test-unit-core-views-manifest.R:13`, `test-unit-migration-runner.R:250`
- Test: `api/tests/testthat/test-unit-analysis-reproducibility.R`

**Interfaces — Produces:**
- `analysis_reproducibility_bundle(kind, payload)` → `list(bundle_json, reproducibility_hash)` where `payload` is the builder's `raw`/graph/coords.
- Endpoints `GET /api/analysis/functional_clustering/reproducibility`, `GET /api/analysis/phenotype_clustering/reproducibility`.

- [ ] **Step 1: Write failing round-trip test** (the #512 guarantee):
```r
test_that("modularity recomputed from the functional bundle equals the served metric", {
  b <- analysis_reproducibility_bundle("functional", stub_functional_payload())
  parsed <- jsonlite::fromJSON(memDecompress(b$bundle_json, "gzip", asChar = TRUE))
  g <- igraph::graph_from_data_frame(parsed$edges[c("source","target")], directed = FALSE)
  igraph::E(g)$weight <- parsed$edges$exp_db_score
  memb <- parsed$membership$cluster[match(igraph::V(g)$name, parsed$membership$node)]
  q <- igraph::modularity(igraph::largest_component(g), as.integer(factor(memb)), weights = NULL)
  expect_equal(round(q, 3), round(parsed$served_modularity, 3))
})
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Migration**
```sql
-- db/migrations/041_add_analysis_reproducibility.sql
CREATE TABLE IF NOT EXISTS analysis_snapshot_reproducibility (
  reproducibility_id   INT AUTO_INCREMENT PRIMARY KEY,
  snapshot_id          INT NOT NULL,
  kind                 VARCHAR(32) NOT NULL,
  bundle_gzip_json     LONGBLOB NOT NULL,
  reproducibility_hash CHAR(64) NOT NULL,
  byte_size            INT NOT NULL,
  created_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_repro_snapshot FOREIGN KEY (snapshot_id)
    REFERENCES analysis_snapshot (snapshot_id) ON DELETE CASCADE,
  UNIQUE KEY uq_repro_snapshot (snapshot_id)
);
```
Update `EXPECTED_LATEST_MIGRATION <- "041_add_analysis_reproducibility.sql"` and the 3 asserting tests + runner min-count.

- [ ] **Step 4: Implement `analysis-reproducibility.R`** — build gzipped JSON `{ kind, params, edges|coords, membership, served_modularity|served_silhouette, reproducibility_hash }`; `reproducibility_hash = digest::digest(canonical_json, "sha256")`. Wire `analysis_snapshot_build_payload` (functional + phenotype branches) to attach the bundle to the payload and `analysis_snapshot_refresh` to persist it via a new `analysis_snapshot_insert_reproducibility(snapshot_id, bundle)` repo fn. Add the two endpoints (DB-only read; resolve entities/genes through the public surface; `mount_endpoint()`).

- [ ] **Step 5: Run → PASS** (round-trip + endpoint tests).
- [ ] **Step 6: Commit** `feat(analysis): self-reproducing snapshot bundle (full edges, membership, MCA coords) + endpoints (#512)`.

---

### Task 6: Frontend + MCP surfacing of new validation fields

**Files:**
- Modify: `app/src/api/analysis.ts` (`ClusterValidation` interface)
- Modify: `app/src/components/analyses/clusterValidation.ts` (`summarizeValidation`)
- Modify: `app/src/components/analyses/ClusterValidationCard.vue`
- Modify: `api/functions/mcp-analysis-service.R` (expose new fields as `operational_metadata`)
- Test: `app/src/components/analyses/clusterValidation.spec.ts`, `ClusterValidationCard.spec.ts`, `analysis.spec.ts`; `api/tests/testthat/test-mcp-analysis-service.R`

- [ ] **Step 1: Write failing FE test** — `summarizeValidation` returns a "Separation z" metric (with p-value hint) as the headline for both axes; component counts + interpretation band shown; absent fields hidden.
- [ ] **Step 2: Run → FAIL** (`cd app && npx vitest run src/components/analyses/clusterValidation.spec.ts`).
- [ ] **Step 3: Implement** — add fields to the TS interface; in `summarizeValidation` prepend `{ label: 'Separation z', value: fmtDecimal(z), hint: 'vs matched null, p=' + p }` for both branches; render giant-component + interpretation in the card. Add MCP `operational_metadata` fields.
- [ ] **Step 4: Run → PASS**; `cd app && npm run type-check`.
- [ ] **Step 5: Commit** `feat(analysis-ui): surface null-calibrated separation z + dip + component counts (#510,#511)`.

---

### Task 7: Schema-version bumps, snapshot-build test, Wave-1 docs

**Files:**
- Modify: `api/functions/analysis-snapshot-presets.R` (`ANALYSIS_SNAPSHOT_SCHEMA_VERSION` → "1.2")
- Modify: `api/tests/testthat/test-unit-analysis-snapshot-validation-build.R` (assert 2.0 + new fields persisted)
- Modify: `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd`, `db/migrations/README.md`

- [ ] **Step 1** Update schema constant + validation-build test (new fields present in `validation_json`).
- [ ] **Step 2** Run `docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-analysis-snapshot-validation-build.R')"` → PASS.
- [ ] **Step 3** Extend the AGENTS.md analysis-snapshot/cluster-validation invariant: null-calibrated z framework, dip test, giant-component, reproducibility bundle + endpoints, schema 2.0/1.2. Add Wave-2 runbook stub to `09-deployment.qmd`.
- [ ] **Step 4** Commit `docs(analysis): Wave-1 schema bump + cluster-soundness docs (#508-#512)`.

**Wave-1 gate:** `make code-quality-audit && make lint-api && make test-api-fast` green; restart worker; `POST /api/admin/analysis/snapshots/refresh?force=true` for both cluster types (validation-only change — hashes unchanged); confirm endpoints return bundles + new validation fields render.

---

## WAVE 2 — method changes (`cluster_hash` regen + coordinated LLM regen)

### Task 8: `analysis-string-channels.R` — text-mining-free STRING weights

**Files:**
- Create: `api/functions/analysis-string-channels.R`
- Create/modify: db-prep download for `9606.protein.links.detailed.v11.5.txt.gz` (documented; not baked into image)
- Modify: `api/bootstrap/load_modules.R`
- Test: `api/tests/testthat/test-unit-analysis-string-channels.R`

**Interfaces — Produces:** `string_recompute_score(escore, dscore, prior = 0.041)` (vectorized, scores in 0..1000 → returns 0..1000); `string_textmining_free_edges(string_ids, score_threshold = 400)` → tibble `(protein1, protein2, exp_db_score)`.

- [ ] **Step 1: Failing test** — OR formula against a hand-computed value:
```r
test_that("string_recompute_score matches STRING OR combine (exp+db)", {
  # escore=0.5, dscore=0.4, prior=0.041 -> strip, OR, add prior
  p <- 0.041; s <- function(x) pmax(0,(x-p)/(1-p))
  expect_equal(string_recompute_score(500, 400) / 1000,
               { c <- 1-(1-s(.5))*(1-s(.4)); c + p*(1-c) }, tolerance = 1e-6)
})
```
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the OR formula + a reader that loads the detailed file, keeps `experimental`+`database`, recombines, thresholds. Document the download + checksum; env `STRING_WEIGHT_CHANNELS`.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** `feat(analysis): text-mining-free STRING channel recompute (experimental+database) (#510)`.

---

### Task 9: `analysis-phenotype-mca-prep.R` — near-constant filtering, encoding, ncp rule

**Files:**
- Create: `api/functions/analysis-phenotype-mca-prep.R`
- Modify: `api/bootstrap/load_modules.R`
- Test: `api/tests/testthat/test-unit-phenotype-mca-prep.R`

**Interfaces — Produces:** `phenotype_mca_active_filter(matrix, prevalence_min=0.05, prevalence_max=0.95, drop_terms=c("HP:0000118"), hpo_lookup=NULL)` → `list(active_matrix, kept_terms, excluded)`; `phenotype_mca_encode_presence(matrix, presence_cols)` → recoded df with `{absent,present}` factors; `phenotype_mca_ncp(eig, q_active)` → `list(ncp, adjusted_inertia)`.

- [ ] **Step 1: Failing tests** — filter drops `HP:0000118` + a 100%-prevalence and a 0.5%-prevalence column, keeps a 50% column; encoding yields 2-level factors; `phenotype_mca_ncp` returns `sum(λ>1/Q)` and Greenacre-adjusted percentages.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the three helpers (prevalence over non-NA/"yes"; map term→hpo_id via `phenotype_list`; Greenacre `1/Q` + adjusted inertia formula from spec §5.C1).
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** `feat(analysis): MCA near-constant filtering, absent/present encoding, Greenacre ncp (#508)`.

---

### Task 10: Wire MCA prep + true consolidation into the phenotype pipeline

**Files:**
- Modify: `api/functions/analysis-phenotype-functions.R` (`gen_mca_clust_obj`, `generate_phenotype_cluster_input`)
- Test: `api/tests/testthat/test-unit-phenotype-hcpc-k.R` (extend)

**Interfaces — Consumes:** Task 9 helpers. **Produces:** provenance list `active_feature_set` (kept), `excluded_terms`, `prevalence_band`, `ncp_selected`, `adjusted_inertia`, `consolidation=TRUE`, `kk="Inf"` — attached so the builder writes them into the validation block.

- [ ] **Step 1: Failing test** — after wiring, `HP:0000118` absent from active vars; HCPC runs `kk=Inf, consol=TRUE` (no consolidation warning); provenance present; cluster count still sensible.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — apply filter+encoding in the input build; two-pass ncp; `HCPC(..., kk = Inf, consol = TRUE)`; return provenance without changing the tibble's unnest columns. Share the `hcpc_config` used by Task 3's curve.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** `feat(analysis): filtered MCA active set + true consolidation in phenotype clustering (#508,#509)`.

---

### Task 11: Wire text-mining-free graph + LCC into the functional pipeline

**Files:**
- Modify: `api/functions/analyses-functions.R` (`build_string_subgraph`, `gen_string_clust_obj`)
- Modify: `api/functions/analysis-cluster-validation.R` (`validate_functional_clusters`: primary weights = exp_db; keep `modularity_combined_score` sensitivity)
- Modify: `api/functions/analysis-network-functions.R` (display graph uses same weights)
- Test: `api/tests/testthat/test-unit-functional-leiden-weights.R` (extend)

**Interfaces — Consumes:** Task 8. **Produces:** functional partition + modularity computed on the LCC of the text-mining-free graph; validation `weight_channel="experimental_database"`, `modularity_combined_score` (sensitivity).

- [ ] **Step 1: Failing test** — subgraph weights come from `exp_db_score`; text-mining-only edges dropped; validation carries both `modularity` (primary) and `modularity_combined_score`.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — `build_string_subgraph` builds the text-mining-free weighted graph, restricts to `largest_component()`; Leiden + modularity use `exp_db_score`; compute a combined-score sensitivity modularity on the same partition. Display graph follows.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** `feat(analysis): text-mining-free, giant-component functional clustering as primary (#510)`.

---

### Task 12: Coordinated refresh + LLM regen + end-to-end verification

- [ ] **Step 1** `make code-quality-audit && make lint-api && make test-api-fast`; `cd app && npm run type-check && npm run test:unit`.
- [ ] **Step 2** Rebuild/restart worker (worker-executed code changed): `docker compose restart worker worker-maintenance` (dev: `worker`).
- [ ] **Step 3** Force refresh both cluster types: `POST /api/admin/analysis/snapshots/refresh?analysis_type=functional_clusters&force=true` and `...phenotype_clusters&force=true`.
- [ ] **Step 4** Regenerate LLM summaries (hashes changed): `POST /api/llm/regenerate?cluster_type=phenotype&force=true` and `...functional&force=true`.
- [ ] **Step 5** Verify live: fetch both `/api/analysis/*_clustering` — confirm `separation_z`, `dip_p`, `giant_component`, filtered `active_feature_set` (no `HP:0000118`), `weight_channel=experimental_database`, `consolidation=true`, and `k_selection_curve[k]==mean_silhouette`. Fetch both `/reproducibility` endpoints and recompute modularity + silhouette from the bundle == served (the #512 guarantee).
- [ ] **Step 6** Commit `chore(analysis): Wave-2 coordinated refresh runbook + e2e verification (#508-#512)` and update `documentation/09-deployment.qmd` runbook.

---

## Self-Review

**Spec coverage:** C1→Tasks 9,10; C2→Tasks 3,10; C3→Tasks 2,8,11; C4→Tasks 1,4; C5→Task 5; C6→Task 6; schema/versioning→Task 7; rollout→Wave gates + Task 12; docs→Tasks 7,12. All covered.
**Placeholder scan:** core novel code (null models, OR formula, kNN, filter) given in full; integration steps show exact edits; no TBD.
**Type consistency:** `separation_z` = modularity_z (function) / silhouette_z (phenotype); `modularity_null_zscore`/`silhouette_null_zscore`/`dip_unimodality`/`knn_similarity_graph` names stable across Tasks 1,2,4; `analysis_reproducibility_bundle` stable across Task 5.
**Parallelism:** Wave 1 — Task 1 first (blocks 2,4); Tasks 3 & 5 independent; Task 6 after 2/4/5; Task 7 last. Wave 2 — Tasks 8 & 9 parallel; 10 needs 9; 11 needs 8; 12 last.
