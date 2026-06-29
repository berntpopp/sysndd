# Analysis Cluster Validation Implementation Plan (#457, #458, #459)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make functional (Leiden) and phenotype (MCA/HCPC) clustering scientifically correct, compute and persist per-cluster stability metrics + a human-facing DB release label in analysis snapshots, and expose them read-only through the API and MCP.

**Architecture:** Fix the two compute functions in place; add one membership-only validation module that the snapshot builder calls in the heavy/worker path; add one DB migration for partition-level metrics + DB label; thread the metrics through the existing normalized snapshot manifest/cluster tables and the existing `SELECT *` read path into the service meta block and the two MCP analysis tools.

**Tech Stack:** R / Plumber, `igraph` 2.3.1, `FactoMineR` 2.13, `cluster` 2.1.8.2 (no `fpc`), MySQL (normalized `analysis_snapshot_*` tables), testthat.

## Global Constraints

- **No manuscript references in any file** (specs, plans, code, comments, docs). Frame everything as analysis correctness + reproducibility + generic downstream consumers.
- **No synchronous clustering/validation on a public request path** — worker/heavy snapshot-build path only.
- **No new heavyweight dependency** — bootstrap-Jaccard is hand-rolled in base R + `igraph`/`cluster`; `cluster::silhouette` for phenotype only. `fpc` is NOT in `renv.lock`.
- **No silhouette for graph (functional) clusters** — no metric embedding exists.
- `partition_scope = "visible_top_level"` everywhere: metrics describe stored, post-`min_size` top-level clusters, never the raw partition or recursive subclusters.
- DB release label policy: store the literal `"unknown"` when `db_version_get()$available == FALSE`; never omit.
- Namespace `dplyr::select(...)` etc. explicitly (masking). `DBI::dbBind()` with `?` needs `unname(params)`.
- New source files must be registered in `api/bootstrap/load_modules.R` (loads both API and worker).
- Migration files are `NNN_description.sql`, applied once at startup; next free number is **037**.
- igraph 2.3.1 supports `n_iterations = -1` and `igraph::compare(method = "adjusted.rand")`.

---

### Task 1: Functional Leiden — weighted, converged, `resolution` argument (#457)

**Files:**
- Modify: `api/functions/analyses-functions.R` (`gen_string_clust_obj`: signature ~`:73-82`; `cluster_leiden` call `:148-154`; recursive call `:220-227`)
- Test: `api/tests/testthat/test-unit-functional-leiden-weights.R` (Create)

**Interfaces:**
- Produces: `gen_string_clust_obj(hgnc_list, min_size = 10, resolution = 1.0, subcluster = TRUE, parent = NA, enrichment = TRUE, algorithm = "leiden", string_id_table = NULL, score_threshold = 400)` — the `cluster_leiden` call now passes `weights = igraph::E(subgraph)$combined_score`, `resolution_parameter = resolution`, `n_iterations = -1`.

- [ ] **Step 1: Write the failing static-guard test** (repo convention: grep the function source; mirrors `test-unit-external-budget-guard.R`).

```r
# api/tests/testthat/test-unit-functional-leiden-weights.R
test_that("gen_string_clust_obj passes STRING weights and converges", {
  src <- readLines(file.path(get_api_dir(), "functions", "analyses-functions.R"))
  body <- paste(src, collapse = "\n")
  # weighted modularity on combined_score
  expect_match(body, "weights\\s*=\\s*igraph::E\\(subgraph\\)\\$combined_score", fixed = FALSE)
  # converge instead of n_iterations = 2
  expect_match(body, "n_iterations\\s*=\\s*-1", fixed = FALSE)
  expect_false(grepl("n_iterations\\s*=\\s*2", body))
  # resolution is an explicit argument, not a hardcoded literal
  expect_match(body, "resolution\\s*=\\s*1\\.0", fixed = FALSE)              # signature default
  expect_match(body, "resolution_parameter\\s*=\\s*resolution", fixed = FALSE)
})
```

- [ ] **Step 2: Run it; verify it FAILS**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-functional-leiden-weights.R')"`
Expected: FAIL (current source has `n_iterations = 2`, no `weights=`, `resolution_parameter = 1.0`).

- [ ] **Step 3: Add the `resolution` argument to the signature.** Edit `:73-82` to insert `resolution = 1.0` after `min_size = 10,`:

```r
gen_string_clust_obj <- function(
  hgnc_list,
  min_size = 10,
  resolution = 1.0,
  subcluster = TRUE,
  parent = NA,
  enrichment = TRUE,
  algorithm = "leiden",
  string_id_table = NULL,
  score_threshold = 400
)
```

- [ ] **Step 4: Replace the `cluster_leiden` call** (`:148-154`) with the weighted, converged form:

```r
cluster_result <- igraph::cluster_leiden(
  subgraph,
  objective_function   = "modularity",
  weights              = igraph::E(subgraph)$combined_score,
  resolution_parameter = resolution,
  beta                 = 0.01,
  n_iterations         = -1
)
```

- [ ] **Step 5: Thread `resolution` through the recursive subcluster call** (`:220-227`), adding `resolution = resolution` to the inner `gen_string_clust_obj(...)`:

```r
mutate(., subclusters = list(gen_string_clust_obj(
  identifiers$hgnc_id,
  min_size = min_size,
  resolution = resolution,
  subcluster = FALSE,
  parent = cluster,
  algorithm = algorithm,
  string_id_table = string_id_table,
  score_threshold = score_threshold
)))
```

(Also fixes the pre-existing drop of `min_size` on the recursive call.)

- [ ] **Step 6: Run the guard test; verify PASS**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-functional-leiden-weights.R')"`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add api/functions/analyses-functions.R api/tests/testthat/test-unit-functional-leiden-weights.R
git commit -m "fix(analysis): functional Leiden uses STRING combined_score weights and converges (#457)"
```

---

### Task 2: Phenotype HCPC — data-driven k, enforce `min_size`, surface coords + signature (#458)

**Files:**
- Modify: `api/functions/analysis-phenotype-functions.R` (`gen_mca_clust_obj`: signature `:14-20`; `HCPC` call `:48-55`; cluster assembly `:58-74`; return `:112`)
- Test: `api/tests/testthat/test-unit-phenotype-hcpc-k.R` (Create)

**Interfaces:**
- Produces: `gen_mca_clust_obj(wide_phenotypes_df, min_size = 10, quali_sup_var = 1:1, quanti_sup_var = 2:4, cutpoint = -1)`. Returns a list `{clusters = <tibble with cols cluster, identifiers, hash_filter, cluster_size, cluster_signature, quali_inp_var, quali_sup_var, quanti_sup_var>, k = <int>, mca_ind_coord = <matrix rownamed by entity_id>}`. (Change from a bare tibble to a named list — update all callers in Task 5 hooks.)

> Caller note: `generate_phenotype_clusters()` (`analysis-phenotype-functions.R:220`) and `gen_mca_clust_obj_mem` currently consume the bare tibble. After this task the return is a list; `generate_phenotype_clusters()` must read `result$clusters` and pass `result$mca_ind_coord` / `result$k` onward. This is handled in Step 5 below and consumed in Task 3.

- [ ] **Step 1: Write the failing static-guard test**

```r
# api/tests/testthat/test-unit-phenotype-hcpc-k.R
test_that("gen_mca_clust_obj selects k from data and enforces min_size", {
  src <- readLines(file.path(get_api_dir(), "functions", "analysis-phenotype-functions.R"))
  body <- paste(src, collapse = "\n")
  expect_match(body, "nb\\.clust\\s*=\\s*-1", fixed = FALSE)            # data-driven k path reachable
  expect_match(body, "cutpoint\\s*=\\s*-1", fixed = FALSE)             # default is data-driven
  expect_match(body, "filter\\(cluster_size\\s*>=\\s*min_size\\)")     # min_size now enforced
  expect_match(body, "cluster_signature")                              # stable identity present
  expect_match(body, "mca_ind_coord")                                  # coords surfaced for silhouette
})
```

- [ ] **Step 2: Run it; verify FAIL**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-phenotype-hcpc-k.R')"`
Expected: FAIL (current default `cutpoint = 5`, no `min_size` filter, no signature/coords).

- [ ] **Step 3: Default to data-driven k.** Edit signature `:19` `cutpoint = 5` → `cutpoint = -1`. The `HCPC(..., nb.clust = cutpoint, ...)` call (`:48`) then auto-selects when `cutpoint = -1`; leave the rest of the `HCPC(...)` call unchanged.

- [ ] **Step 4: Capture the emergent k** immediately after the `HCPC(...)` call (after `:55`):

```r
emergent_k <- nlevels(mca_hcpc$data.clust$clust)
```

- [ ] **Step 5: Enforce `min_size`, add `cluster_signature`, and return coords + k.** In the cluster-assembly pipeline (the block that builds `clusters_tibble`, around `:58-112`):
  - After `mutate(cluster_size = nrow(identifiers))` (`:74`), add the filter mirroring the functional path:
    ```r
    dplyr::filter(cluster_size >= min_size) %>%
    ```
  - Add a deterministic `cluster_signature` from the already-computed enriched HPO terms in `quali_inp_var` (top-5 by ascending `p.value`, tie-break by term name; signature string + short hash):
    ```r
    dplyr::mutate(cluster_signature = vapply(quali_inp_var, function(qv) {
      if (is.null(qv) || nrow(qv) == 0) return(NA_character_)
      ord <- order(qv$p.value, qv$category)          # deterministic
      terms <- utils::head(qv$category[ord], 5L)
      paste(terms, collapse = "|")
    }, character(1))) %>%
    dplyr::mutate(cluster_signature_hash =
      vapply(cluster_signature, function(s)
        if (is.na(s)) NA_character_ else digest::digest(s, algo = "sha256"),
        character(1)))
    ```
    (`digest` is already a transitive dep via memoise/hashing in this codebase; if the load check fails, substitute `openssl::sha256`.)
  - Change the final `return(clusters_tibble)` (`:112`) to:
    ```r
    return(list(
      clusters = clusters_tibble,
      k = emergent_k,
      mca_ind_coord = mca_phenotypes$ind$coord   # rows are entity_id rownames
    ))
    ```
  - Ensure the empty-input branch (`:106-107`) returns the same list shape with an empty tibble, `k = 0L`, `mca_ind_coord = NULL`.

- [ ] **Step 6: Update `generate_phenotype_clusters()`** (`analysis-phenotype-functions.R:220` area) to consume the new list:

```r
mca_result <- gen_mca_clust_obj_mem(input$matrix)
clusters    <- mca_result$clusters
# carry coords + k for the validation helper / builder
attr(clusters, "mca_ind_coord") <- mca_result$mca_ind_coord
attr(clusters, "phenotype_k")   <- mca_result$k
# ... existing unnest/join hgnc_id+symbol/re-nest identifiers logic unchanged ...
```

(Attaching coords/k as attributes keeps the downstream nested-tibble shape identical while making them available to the builder in Task 5.)

- [ ] **Step 7: Add a behavioral unit test** with a synthetic phenotype matrix that has clear structure, asserting data-driven k ≥ 2 and that small clusters are dropped:

```r
test_that("gen_mca_clust_obj returns a data-driven k and drops tiny clusters", {
  set.seed(1)
  # 60 entities: two clear phenotype blocks + 3 singletons
  mk <- function(n, cols_on) {
    m <- matrix(NA_character_, n, 6, dimnames = list(NULL, paste0("HP_", 1:6)))
    for (c in cols_on) m[, c] <- "yes"; as.data.frame(m, stringsAsFactors = FALSE)
  }
  df <- rbind(mk(28, c(1,2,3)), mk(29, c(4,5,6)), mk(3, c(1,6)))
  df$entity_id <- seq_len(nrow(df))
  df$moi <- "AD"; df$c1 <- 1; df$c2 <- 1; df$c3 <- 1
  df <- df[, c("entity_id","moi","c1","c2","c3", paste0("HP_",1:6))]
  res <- gen_mca_clust_obj(df, min_size = 10, quali_sup_var = 1:1, quanti_sup_var = 2:4, cutpoint = -1)
  expect_true(is.list(res) && !is.null(res$clusters))
  expect_gte(res$k, 2L)
  expect_true(all(res$clusters$cluster_size >= 10))   # tiny clusters dropped
  expect_false(is.null(res$mca_ind_coord))
})
```

Load with `source_api_file("functions/analysis-phenotype-functions.R", local = FALSE, envir = globalenv())` in a `setup` block (see existing phenotype tests for the helper preamble).

- [ ] **Step 8: Run both tests; verify PASS**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-phenotype-hcpc-k.R')"`
Expected: PASS (both static guard and behavioral).

- [ ] **Step 9: Commit**

```bash
git add api/functions/analysis-phenotype-functions.R api/tests/testthat/test-unit-phenotype-hcpc-k.R
git commit -m "fix(analysis): phenotype HCPC selects k from data, enforces min_size, adds stable signature (#458)"
```

---

### Task 3: Membership-only validation helpers (new module) (#457)

**Files:**
- Create: `api/functions/analysis-cluster-validation.R`
- Modify: `api/bootstrap/load_modules.R` (register the new module)
- Test: `api/tests/testthat/test-unit-analysis-cluster-validation.R` (Create)

**Interfaces:**
- Produces:
  - `validate_functional_clusters(hgnc_list, score_threshold = 400, resolution = 1.0, n_resamples = 100, min_size = 10, seed = 42)` → `list(per_cluster = tibble(cluster_id, jaccard_mean, jaccard_n_resamples, bootstrap_seed), partition = list(algorithm = "leiden", weighted = TRUE, n_iterations = -1, resolution_parameter = resolution, modularity = <dbl>, n_clusters = <int>, partition_scope = "visible_top_level", resampling_scheme = "bootstrap_nodes"))`.
  - `validate_phenotype_clusters(reference_clusters, mca_ind_coord, wide_phenotypes_df, quali_sup_var, quanti_sup_var, min_size = 10, n_resamples = 100, seed = 42)` → `list(per_cluster = tibble(cluster_id, jaccard_mean, jaccard_n_resamples, bootstrap_seed, silhouette_mean), partition = list(algorithm = "mca_hcpc", k = <int>, k_selection_metric = "hcpc_relative_inertia_loss", mean_silhouette = <dbl>, n_clusters = <int>, partition_scope = "visible_top_level", resampling_scheme = "bootstrap_entities"))`.
  - `cluster_max_jaccard(reference_members, bootstrap_clusters, present_ids)` — internal: for each reference cluster (intersected with `present_ids`), max Jaccard against any bootstrap cluster.

- [ ] **Step 1: Write the failing test for the Jaccard primitive**

```r
# api/tests/testthat/test-unit-analysis-cluster-validation.R
test_that("cluster_max_jaccard recovers identical partitions at 1.0", {
  ref  <- list(A = c("g1","g2","g3"), B = c("g4","g5"))
  boot <- list(X = c("g1","g2","g3"), Y = c("g4","g5"))
  present <- c("g1","g2","g3","g4","g5")
  res <- cluster_max_jaccard(ref, boot, present)
  expect_equal(unname(res[["A"]]), 1.0)
  expect_equal(unname(res[["B"]]), 1.0)
})

test_that("cluster_max_jaccard penalizes a split cluster", {
  ref  <- list(A = c("g1","g2","g3","g4"))
  boot <- list(X = c("g1","g2"), Y = c("g3","g4"))   # ref A split in two
  res <- cluster_max_jaccard(ref, boot, c("g1","g2","g3","g4"))
  expect_equal(unname(res[["A"]]), 0.5)              # max(2/4, 2/4)
})
```

- [ ] **Step 2: Run; verify FAIL**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-cluster-validation.R')"`
Expected: FAIL ("could not find function cluster_max_jaccard").

- [ ] **Step 3: Implement the Jaccard primitive + functional validator** in `api/functions/analysis-cluster-validation.R`:

```r
# Membership-only cluster validation. Worker/heavy-path only — never on a public request.

cluster_max_jaccard <- function(reference_members, bootstrap_clusters, present_ids) {
  jac <- function(a, b) {
    a <- intersect(a, present_ids)
    if (length(a) == 0) return(NA_real_)
    inter <- length(intersect(a, b))
    union <- length(union(a, b))
    if (union == 0) 0 else inter / union
  }
  vapply(reference_members, function(ref) {
    if (length(bootstrap_clusters) == 0) return(NA_real_)
    max(vapply(bootstrap_clusters, function(bc) jac(ref, bc), numeric(1)), na.rm = TRUE)
  }, numeric(1))
}

# Build the fixed STRING subgraph + weighted/converged reference partition (visible top level).
.functional_reference_partition <- function(hgnc_list, score_threshold, resolution, min_size) {
  clusters <- gen_string_clust_obj(
    hgnc_list, min_size = min_size, resolution = resolution,
    subcluster = FALSE, enrichment = FALSE, score_threshold = score_threshold
  )
  # gen_string_clust_obj returns a tibble of visible top-level clusters (post min_size).
  members <- stats::setNames(
    lapply(clusters$identifiers, function(d) d$hgnc_id),
    as.character(clusters$cluster)
  )
  members
}

validate_functional_clusters <- function(hgnc_list, score_threshold = 400, resolution = 1.0,
                                          n_resamples = 100, min_size = 10, seed = 42) {
  subgraph <- build_string_subgraph(hgnc_list, score_threshold)      # shared refactored helper (Step 4)
  ref_members <- .functional_reference_partition(subgraph, resolution, min_size)
  n_clusters <- length(ref_members)

  # Weighted modularity of the reference partition on the full induced subgraph.
  membership <- .membership_vector(subgraph, ref_members)
  modularity <- igraph::modularity(
    subgraph, membership,
    weights = igraph::E(subgraph)$combined_score
  )

  all_nodes <- igraph::V(subgraph)$name
  per_cluster_acc <- stats::setNames(
    rep(list(numeric(0)), n_clusters), names(ref_members)
  )
  for (b in seq_len(n_resamples)) {
    set.seed(seed + b)
    sampled <- unique(sample(all_nodes, length(all_nodes), replace = TRUE))
    sub_b <- igraph::induced_subgraph(subgraph, which(all_nodes %in% sampled))
    set.seed(seed + b)
    cl_b <- igraph::cluster_leiden(
      sub_b, objective_function = "modularity",
      weights = igraph::E(sub_b)$combined_score,
      resolution_parameter = resolution, beta = 0.01, n_iterations = -1
    )
    boot_clusters <- split(igraph::V(sub_b)$name, cl_b$membership)
    jac <- cluster_max_jaccard(ref_members, boot_clusters, sampled)
    for (k in names(ref_members)) per_cluster_acc[[k]] <- c(per_cluster_acc[[k]], jac[[k]])
  }

  per_cluster <- dplyr::tibble(
    cluster_id = names(ref_members),
    jaccard_mean = vapply(per_cluster_acc, function(v) mean(v, na.rm = TRUE), numeric(1)),
    jaccard_n_resamples = n_resamples,
    bootstrap_seed = seed
  )
  list(
    per_cluster = per_cluster,
    partition = list(
      algorithm = "leiden", weighted = TRUE, n_iterations = -1L,
      resolution_parameter = resolution, modularity = modularity,
      n_clusters = n_clusters, partition_scope = "visible_top_level",
      resampling_scheme = "bootstrap_nodes"
    )
  )
}
```

- [ ] **Step 4: Refactor the real subgraph construction into a shared helper** (so the validator reuses the byte-identical fixed graph, not a reconstruction). **Codebase-verified:** `gen_string_clust_obj` (`analyses-functions.R:87-123`) builds the subgraph from a module-local `sysndd_db_string_id_df` (the `non_alt_loci_set` STRING ids filtered by `hgnc_id %in% hgnc_list`, or the passed `string_id_table`), then `induced_subgraph` over `string_db$get_graph()`. Extract lines ~87-123 verbatim into `build_string_subgraph(hgnc_list, score_threshold = 400, string_id_table = NULL)` in `analyses-functions.R`, have `gen_string_clust_obj` call it (no behavior change), and have the validator call it too:

```r
build_string_subgraph <- function(hgnc_list, score_threshold = 400, string_id_table = NULL) {
  string_db <- get_string_db(score_threshold)
  if (!is.null(string_id_table)) {
    id_tbl <- dplyr::filter(string_id_table, hgnc_id %in% hgnc_list)
  } else {
    id_tbl <- pool %>% dplyr::tbl("non_alt_loci_set") %>%
      dplyr::filter(!is.na(STRING_id)) %>%
      dplyr::select(symbol, hgnc_id, STRING_id) %>%
      dplyr::collect() %>% dplyr::filter(hgnc_id %in% hgnc_list)
  }
  id_df <- as.data.frame(id_tbl)
  string_graph <- string_db$get_graph()
  genes_in_graph <- intersect(igraph::V(string_graph)$name, id_df$STRING_id)
  igraph::induced_subgraph(string_graph, vids = which(igraph::V(string_graph)$name %in% genes_in_graph))
}

# Visible top-level reference partition computed directly on the shared subgraph
# (weighted, converged, post-min_size) — guarantees the SAME graph object production uses.
.functional_reference_partition <- function(subgraph, resolution = 1.0, min_size = 10) {
  set.seed(42)
  cl <- igraph::cluster_leiden(
    subgraph, objective_function = "modularity",
    weights = igraph::E(subgraph)$combined_score,
    resolution_parameter = resolution, beta = 0.01, n_iterations = -1
  )
  parts <- split(igraph::V(subgraph)$name, cl$membership)
  parts <- parts[vapply(parts, length, integer(1)) >= min_size]   # visible_top_level
  stats::setNames(parts, as.character(seq_along(parts)))
}

.membership_vector <- function(subgraph, members) {
  node_names <- igraph::V(subgraph)$name
  m <- rep(NA_integer_, length(node_names)); names(m) <- node_names
  for (i in seq_along(members)) m[names(m) %in% members[[i]]] <- i
  # nodes not in any visible cluster get their own singleton ids (so modularity is defined)
  na_idx <- which(is.na(m)); if (length(na_idx)) m[na_idx] <- length(members) + seq_along(na_idx)
  m
}
```

> Contract: the validator's reference graph MUST be the same object production clusters. Refactoring (not reconstructing) the construction is what guarantees that. Add a guard test asserting `gen_string_clust_obj` calls `build_string_subgraph`.

- [ ] **Step 5: Implement `validate_phenotype_clusters`** (silhouette + entity-bootstrap Jaccard):

```r
validate_phenotype_clusters <- function(reference_clusters, mca_ind_coord, wide_phenotypes_df,
                                         quali_sup_var, quanti_sup_var, min_size = 10,
                                         n_resamples = 100, seed = 42) {
  ref_members <- stats::setNames(
    lapply(reference_clusters$identifiers, function(d) as.character(d$entity_id)),
    as.character(reference_clusters$cluster)
  )
  n_clusters <- length(ref_members)

  # Silhouette on MCA Euclidean coordinates (valid embedding).
  ent_to_cluster <- stats::setNames(
    rep(names(ref_members), lengths(ref_members)), unlist(ref_members)
  )
  coord_ids <- rownames(mca_ind_coord)
  keep <- coord_ids %in% names(ent_to_cluster)
  memb_int <- as.integer(factor(ent_to_cluster[coord_ids[keep]]))
  sil_mean <- NA_real_; per_sil <- stats::setNames(rep(NA_real_, n_clusters), names(ref_members))
  k_curve <- NULL
  if (length(unique(memb_int)) >= 2) {
    d <- stats::dist(mca_ind_coord[keep, , drop = FALSE])
    sil <- cluster::silhouette(memb_int, d)
    sil_mean <- mean(sil[, "sil_width"])
    agg <- tapply(sil[, "sil_width"], sil[, "cluster"], mean)
    per_sil <- stats::setNames(as.numeric(agg)[order(as.integer(names(agg)))], names(ref_members))
    # k-selection curve: mean silhouette over k in 2..10 on the SAME Ward linkage HCPC uses,
    # so the data-driven k can be shown to sit at/near a silhouette optimum (supporting diagnostic).
    d_full <- stats::dist(mca_ind_coord)
    hc <- stats::hclust(d_full, method = "ward.D2")
    ks <- 2:min(10L, nrow(mca_ind_coord) - 1L)
    k_curve <- stats::setNames(
      lapply(ks, function(k) mean(cluster::silhouette(stats::cutree(hc, k = k), d_full)[, "sil_width"])),
      as.character(ks)
    )
  }

  # Entity-bootstrap Jaccard: resample entities, recompute MCA+HCPC, max-Jaccard per cluster.
  per_cluster_acc <- stats::setNames(rep(list(numeric(0)), n_clusters), names(ref_members))
  all_entities <- as.character(wide_phenotypes_df$entity_id)
  for (b in seq_len(n_resamples)) {
    set.seed(seed + b)
    sampled <- unique(sample(all_entities, length(all_entities), replace = TRUE))
    df_b <- wide_phenotypes_df[match(sampled, all_entities), , drop = FALSE]
    cl_b <- tryCatch(
      gen_mca_clust_obj(df_b, min_size = min_size,
                        quali_sup_var = quali_sup_var, quanti_sup_var = quanti_sup_var,
                        cutpoint = -1)$clusters,
      error = function(e) NULL
    )
    if (is.null(cl_b) || nrow(cl_b) == 0) next
    boot_members <- lapply(cl_b$identifiers, function(d) as.character(d$entity_id))
    jac <- cluster_max_jaccard(ref_members, boot_members, sampled)
    for (k in names(ref_members)) per_cluster_acc[[k]] <- c(per_cluster_acc[[k]], jac[[k]])
  }

  per_cluster <- dplyr::tibble(
    cluster_id = names(ref_members),
    jaccard_mean = vapply(per_cluster_acc, function(v) if (length(v)) mean(v, na.rm = TRUE) else NA_real_, numeric(1)),
    jaccard_n_resamples = vapply(per_cluster_acc, length, integer(1)),
    bootstrap_seed = seed,
    silhouette_mean = per_sil
  )
  list(
    per_cluster = per_cluster,
    partition = list(
      algorithm = "mca_hcpc", k = n_clusters,
      k_selection_metric = "hcpc_relative_inertia_loss",
      k_selection_curve = k_curve,             # mean silhouette per k in 2..10 (Ward), or NULL
      mean_silhouette = sil_mean, n_clusters = n_clusters,
      partition_scope = "visible_top_level", resampling_scheme = "bootstrap_entities"
    )
  )
}
```

- [ ] **Step 6: Register the module.** Add `"functions/analysis-cluster-validation.R"` to the source list in `api/bootstrap/load_modules.R` (after `analyses-functions.R` and `analysis-phenotype-functions.R`, since it depends on them).

- [ ] **Step 7: Run the validation tests; verify PASS**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-cluster-validation.R')"`
Expected: PASS (Jaccard primitive). The graph/MCA-dependent functions are integration-exercised in Task 5; here only `cluster_max_jaccard` is unit-tested (it has no external deps).

- [ ] **Step 8: Commit**

```bash
git add api/functions/analysis-cluster-validation.R api/bootstrap/load_modules.R api/tests/testthat/test-unit-analysis-cluster-validation.R
git commit -m "feat(analysis): membership-only cluster-validation helpers (bootstrap-Jaccard, modularity, silhouette) (#457)"
```

---

### Task 4: Migration 037 + manifest constants + guard tests (#459)

**Files:**
- Create: `db/migrations/037_add_analysis_snapshot_validation.sql`
- Modify: `api/functions/migration-manifest.R` (`EXPECTED_LATEST_MIGRATION` `:5`, `EXPECTED_MIGRATION_COUNT` `:6`)
- Modify: `api/tests/testthat/test-unit-core-views-manifest.R:13`, `api/tests/testthat/test-unit-analysis-snapshot-migration.R:8`

**Interfaces:**
- Produces: three new nullable columns on `analysis_snapshot_manifest`: `validation_json JSON`, `db_release_version VARCHAR(64)`, `db_release_commit VARCHAR(64)`.

- [ ] **Step 1: Update the failing manifest guard test first** (it currently asserts the old latest/count):

```r
# test-unit-analysis-snapshot-migration.R:8  (and test-unit-core-views-manifest.R:13)
EXPECTED_LATEST_MIGRATION <- "037_add_analysis_snapshot_validation.sql"   # was 036_...
EXPECTED_MIGRATION_COUNT  <- 35L                                          # was 34L
```

- [ ] **Step 2: Run the guard tests; verify FAIL** (manifest constant mismatch)

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-migration.R')"`
Expected: FAIL until the manifest + file exist.

- [ ] **Step 3: Write the migration**

```sql
-- db/migrations/037_add_analysis_snapshot_validation.sql
-- Partition-level cluster-validation metrics + human-facing DB release label on snapshots.
ALTER TABLE analysis_snapshot_manifest
  ADD COLUMN validation_json    JSON         DEFAULT NULL,
  ADD COLUMN db_release_version VARCHAR(64)  DEFAULT NULL,
  ADD COLUMN db_release_commit  VARCHAR(64)  DEFAULT NULL;
```

- [ ] **Step 4: Bump the manifest constants** in `api/functions/migration-manifest.R`:

```r
EXPECTED_LATEST_MIGRATION <- "037_add_analysis_snapshot_validation.sql"
EXPECTED_MIGRATION_COUNT  <- 35L
```

- [ ] **Step 5: Run the guard tests; verify PASS**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-migration.R'); testthat::test_file('tests/testthat/test-unit-core-views-manifest.R')"`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add db/migrations/037_add_analysis_snapshot_validation.sql api/functions/migration-manifest.R api/tests/testthat/test-unit-core-views-manifest.R api/tests/testthat/test-unit-analysis-snapshot-migration.R
git commit -m "feat(db): migration 037 adds validation_json + db_release label to snapshot manifest (#459)"
```

---

### Task 5: Builder wires validation + DB label; repository persists; service exposes (#459)

**Files:**
- Modify: `api/functions/analysis-snapshot-builder.R` (`analysis_snapshot_build_payload` switch `:381-438`; `analysis_snapshot_refresh` manifest assembly `:460-491`; `payload_hash` exclusion `:467`)
- Modify: `api/functions/analysis-snapshot-repository.R` (`analysis_snapshot_create_manifest` `:106`, INSERT `:112-143`)
- Modify: `api/services/analysis-snapshot-service.R` (`service_analysis_snapshot_meta` `:316-350`)
- Test: `api/tests/testthat/test-unit-analysis-snapshot-validation-build.R` (Create)

**Codebase-verified wiring (read before editing):** the build+persist entry point is
`analysis_snapshot_refresh(analysis_type, params, job_id = NULL, conn = NULL)` (`:441`),
which calls `analysis_snapshot_build_payload(...)` (`:462`) then
`analysis_snapshot_create_manifest(list(...), conn = txn_conn)` (`:475-493`) passing a
**single named list** (not positional args). `analysis_snapshot_payload_hash` (`:467`)
hashes `payload[setdiff(names(payload), c("raw"))]`. The functional branch calls
`gen_string_clust_obj_mem(analysis_snapshot_approved_gene_ids(conn), algorithm)` (`:383`);
the phenotype branch calls `generate_phenotype_clusters()` (`:397`).

**Interfaces:**
- Consumes: `validate_functional_clusters`, `validate_phenotype_clusters` (Task 3), `db_version_get(conn)` (`api/functions/db-version.R`).
- Produces: the manifest `list(...)` at `:475` gains `validation`, `db_release_version`, `db_release_commit`; `analysis_snapshot_create_manifest` reads them from the list; per-cluster `metadata_json` gains `jaccard_mean`/`jaccard_n_resamples`/`bootstrap_seed`/`silhouette_mean`/`cluster_signature`; the meta block gains `validation` + `db_release`.

- [ ] **Step 1: Write the failing builder test.** Drive the **real** entry point `analysis_snapshot_refresh`, stubbing the heavy STRING compute AND the validators AND `db_version_get` so it is deterministic and offline:

```r
# api/tests/testthat/test-unit-analysis-snapshot-validation-build.R
test_that("functional snapshot persists validation + db release label", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    local_mocked_bindings(
      # avoid the live STRING API: return a minimal visible-cluster tibble shaped like
      # gen_string_clust_obj's output (cluster, identifiers[hgnc_id], hash_filter, cluster_size)
      gen_string_clust_obj_mem = function(...) dplyr::tibble(
        cluster = 1L,
        identifiers = list(dplyr::tibble(hgnc_id = c("HGNC:1","HGNC:2"))),
        hash_filter = "deadbeef", cluster_size = 2L
      ),
      validate_functional_clusters = function(...) list(
        per_cluster = dplyr::tibble(cluster_id = "1", jaccard_mean = 0.82,
                                    jaccard_n_resamples = 100L, bootstrap_seed = 42L),
        partition = list(algorithm = "leiden", weighted = TRUE, n_iterations = -1L,
                         resolution_parameter = 1.0, modularity = 0.41, n_clusters = 1L,
                         partition_scope = "visible_top_level", resampling_scheme = "bootstrap_nodes")
      ),
      db_version_get = function(...) list(version = "v3.2.0", commit = "abc1234", available = TRUE),
      .package = NULL
    )
    res <- analysis_snapshot_refresh("functional_clusters",
             params = list(algorithm = "leiden"), conn = conn)
    man <- DBI::dbGetQuery(conn,
      "SELECT validation_json, db_release_version, db_release_commit
         FROM analysis_snapshot_manifest
        WHERE analysis_type = 'functional_clusters' ORDER BY snapshot_id DESC LIMIT 1")
    expect_false(is.na(man$validation_json))
    expect_match(man$validation_json, "visible_top_level")
    expect_equal(man$db_release_version, "v3.2.0")
  })
})
```

(Confirm the cluster-tibble fixture columns against `analysis_snapshot_build_cluster_rows` (`:164-241`) so `left_join(... by = c("cluster" = "cluster_id"))` type-aligns — coerce `cluster` to character if needed.)

- [ ] **Step 2: Run; verify FAIL**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-validation-build.R')"`
Expected: FAIL (manifest columns unpopulated / function args absent).

- [ ] **Step 3: Wire validation into the two clustering branches of `analysis_snapshot_build_payload`.** Insert the validation call **between** `clusters <- ...` and `built <- analysis_snapshot_build_cluster_rows(...)` so per-cluster fields are joined onto `clusters` before row-building (they then auto-flow into `metadata_json`), and add `partition_validation` to the returned list. Full functional branch (`:382-395`):

```r
functional_clusters = {
  gene_ids <- analysis_snapshot_approved_gene_ids(conn = conn)
  clusters <- gen_string_clust_obj_mem(gene_ids, algorithm = params$algorithm)
  n_res <- as.integer(Sys.getenv("ANALYSIS_CLUSTER_VALIDATION_RESAMPLES", "100"))
  val <- validate_functional_clusters(gene_ids, resolution = 1.0, n_resamples = n_res)
  clusters <- dplyr::left_join(
    dplyr::mutate(clusters, cluster_id = as.character(cluster)),   # type-align the join key
    val$per_cluster, by = "cluster_id"
  ) %>% dplyr::select(-cluster_id)
  built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "functional")
  list(kind = "clusters", raw = clusters, clusters = built$clusters,
       members = built$members, row_counts = built$row_counts,
       partition_validation = val$partition)
}
```

Phenotype branch (`:396-405`) — coords + k were attached as attributes in Task 2 Step 6:

```r
phenotype_clusters = {
  clusters <- generate_phenotype_clusters()
  mca_coord <- attr(clusters, "mca_ind_coord")
  n_res <- as.integer(Sys.getenv("ANALYSIS_CLUSTER_VALIDATION_RESAMPLES", "100"))
  val <- validate_phenotype_clusters(
    clusters, mca_coord,
    wide_phenotypes_df = generate_phenotype_cluster_input()$matrix,
    quali_sup_var = 1:1, quanti_sup_var = 2:4, n_resamples = n_res
  )
  clusters <- dplyr::left_join(
    dplyr::mutate(clusters, cluster_id = as.character(cluster)),
    val$per_cluster, by = "cluster_id"
  ) %>% dplyr::select(-cluster_id)
  built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "phenotype")
  list(kind = "clusters", raw = clusters, clusters = built$clusters,
       members = built$members, row_counts = built$row_counts,
       partition_validation = val$partition)
}
```

(Non-clustering branches are unchanged; they simply omit `partition_validation`, which reads as `NULL` downstream.)

- [ ] **Step 4: In `analysis_snapshot_refresh`, exclude `partition_validation` from the payload hash, compute the DB label, and extend the manifest list.**
  - At `:467` change the hash exclusion so the (derived, non-input) validation does not perturb `payload_hash`:
    ```r
    payload_hash <- analysis_snapshot_payload_hash(
      payload[setdiff(names(payload), c("raw", "partition_validation"))]
    )
    ```
  - Just before the `analysis_snapshot_create_manifest(list(...))` call (`:475`):
    ```r
    dbv <- tryCatch(db_version_get(conn = refresh_conn),
                    error = function(e) list(version = "unknown", commit = "unknown", available = FALSE))
    db_release_version <- if (isTRUE(dbv$available)) dbv$version %||% "unknown" else "unknown"
    db_release_commit  <- if (isTRUE(dbv$available)) dbv$commit  %||% "unknown" else "unknown"
    ```
  - Extend the existing manifest `list(...)` (`:476-491`) with three new keys and the enriched `source_versions`:
    ```r
    source_versions = list(sysndd_public_data = source_data_version,
                           db_release_version = db_release_version,
                           db_release_commit  = db_release_commit),
    validation = payload$partition_validation,   # NULL for non-clustering presets
    db_release_version = db_release_version,
    db_release_commit  = db_release_commit,
    ```

- [ ] **Step 5: Extend `analysis_snapshot_create_manifest`** (`repository.R:106`, single named-list arg). Read `manifest$validation`, `manifest$db_release_version`, `manifest$db_release_commit` from the list; serialize `validation` with `jsonlite::toJSON(validation, auto_unbox = TRUE, null = "null")` when non-NULL (else bind `NA`); add the three columns to the INSERT column list (`:112-117`) + three `?` placeholders + the binding (the call already builds a positional params vector — append in the same order and keep the existing `unname()` wrapping for `DBI::dbBind`).

- [ ] **Step 6: Expose in the meta block.** In `service_analysis_snapshot_meta()` (`:316-350`) add:

```r
validation = service_analysis_snapshot_parse_json_object(manifest$validation_json[[1]]),
db_release = list(version = manifest$db_release_version[[1]] %||% "unknown",
                  commit  = manifest$db_release_commit[[1]]  %||% "unknown")
```

(The read path is `SELECT *`, so the new columns are already present on `manifest`.)

- [ ] **Step 7: Run the build test; verify PASS**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-validation-build.R')"`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add api/functions/analysis-snapshot-builder.R api/functions/analysis-snapshot-repository.R api/services/analysis-snapshot-service.R api/tests/testthat/test-unit-analysis-snapshot-validation-build.R
git commit -m "feat(analysis): persist cluster-validation metrics + DB release label in snapshots (#459)"
```

---

### Task 6: MCP exposure + capabilities (#459)

**Files:**
- Modify: `api/services/mcp-analysis-service.R` (`mcp_get_phenotype_analysis_context` `:390`, `mcp_get_gene_network_context` `:500`)
- Modify: the capabilities doc source for `get_sysndd_capabilities` (grep `mcp-capabilities-service.R` for the analysis section)
- Test: `api/tests/testthat/test-mcp-analysis-service.R` (extend)

**Interfaces:**
- Consumes: the `meta.validation` + `meta.db_release` produced in Task 5.
- Produces: MCP analysis payloads carry `validation` (data-class `curated_derived_analysis`) and `db_release` + `partition_scope` (data-class `operational_metadata`), read-only.

- [ ] **Step 1: Write the failing MCP test**

```r
test_that("phenotype analysis context surfaces validation + db release", {
  out <- mcp_get_phenotype_analysis_context(/* minimal args per existing tests */)
  expect_true(!is.null(out$validation))
  expect_true(!is.null(out$db_release$version))
  expect_equal(out$validation$partition_scope, "visible_top_level")
})
```

(Model the call + fixtures on the existing `test-mcp-analysis-service.R` cases.)

- [ ] **Step 2: Run; verify FAIL** — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"`

- [ ] **Step 3: Surface the fields** in both MCP analysis tools by copying `meta$validation` and `meta$db_release` from the snapshot read result into the tool output, attaching the data-class labels the MCP envelope uses (`curated_derived_analysis` for metrics, `operational_metadata` for the label/scope). Follow the existing data-class attachment pattern in `mcp-analysis-service.R`.

- [ ] **Step 4: Document** the new fields in the `get_sysndd_capabilities` analysis section (one short paragraph: validation metrics, `partition_scope` semantics, DB release label, read-only).

- [ ] **Step 5: Run; verify PASS** — same command as Step 2.

- [ ] **Step 6: Commit**

```bash
git add api/services/mcp-analysis-service.R api/services/mcp-capabilities-service.R api/tests/testthat/test-mcp-analysis-service.R
git commit -m "feat(mcp): expose cluster-validation metrics + DB release label read-only (#459)"
```

---

### Task 7: Preset weight + snapshot schema version (#459)

**Files:**
- Modify: `api/functions/analysis-snapshot-presets.R` (`analysis_snapshot_preset_weight`, `ANALYSIS_SNAPSHOT_SCHEMA_VERSION`)
- Test: `api/tests/testthat/test-unit-snapshot-bootstrap-stagger.R` (update expectation)

- [ ] **Step 1: Update the failing weight test** — `phenotype_clusters` is now `"heavy"`:

```r
expect_equal(analysis_snapshot_preset_weight("phenotype_clusters"), "heavy")
```

- [ ] **Step 2: Run; verify FAIL** — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-snapshot-bootstrap-stagger.R')"`

- [ ] **Step 3: Reclassify the preset** in `analysis_snapshot_preset_weight()` so `phenotype_clusters` returns `"heavy"` (it now runs bootstrap validation), and bump `ANALYSIS_SNAPSHOT_SCHEMA_VERSION <- "1.1"`.

- [ ] **Step 4: Run; verify PASS** — same command.

- [ ] **Step 5: Commit**

```bash
git add api/functions/analysis-snapshot-presets.R api/tests/testthat/test-unit-snapshot-bootstrap-stagger.R
git commit -m "chore(analysis): phenotype_clusters is heavy (bootstrap validation); schema version 1.1 (#459)"
```

---

### Task 8: Reproducible diagnostics scripts (#457, #458)

**Files:**
- Create: `api/scripts/analysis-validation/functional-resolution-sweep.R`
- Create: `api/scripts/analysis-validation/phenotype-approximation-ari.R`

**Interfaces:**
- Operator-run only (no production wiring, no endpoint). Each writes a committed JSON + markdown report under `api/scripts/analysis-validation/reports/`.

- [ ] **Step 1: Write the resolution sweep + attribution script.** Given an approved-gene input, run γ ∈ {0.5,0.7,1.0,1.4,2.0}; for each report `{n_clusters, weighted_modularity, ari_vs_gamma1}` (ARI via `igraph::compare(m1, m2, method = "adjusted.rand")`); then the factorial {unweighted,weighted} × {n_iterations 2, converged} × γ-grid with pairwise ARI. Write `reports/functional-resolution-sweep-<date>.json` + a markdown summary table.

```r
#!/usr/bin/env Rscript
# Operator diagnostic: functional Leiden resolution sweep + algorithm-factor attribution.
# Usage: Rscript api/scripts/analysis-validation/functional-resolution-sweep.R
# (sources the API runtime, reads approved genes, writes reports/.)
source(file.path("api", "start_sysndd_api_min.R"))   # or the minimal bootstrap used by other scripts
genes <- analysis_snapshot_approved_gene_ids(pool)
gammas <- c(0.5, 0.7, 1.0, 1.4, 2.0)
ref <- NULL; rows <- list()
for (g in gammas) {
  sub <- build_string_subgraph(genes, 400)
  set.seed(42)
  cl <- igraph::cluster_leiden(sub, objective_function = "modularity",
          weights = igraph::E(sub)$combined_score,
          resolution_parameter = g, beta = 0.01, n_iterations = -1)
  if (is.null(ref)) ref <- cl$membership
  rows[[as.character(g)]] <- list(
    gamma = g, n_clusters = length(unique(cl$membership)),
    modularity = igraph::modularity(sub, cl$membership, weights = igraph::E(sub)$combined_score),
    ari_vs_gamma1 = igraph::compare(cl$membership, ref, method = "adjusted.rand")
  )
}
jsonlite::write_json(rows, "api/scripts/analysis-validation/reports/functional-resolution-sweep.json",
                     auto_unbox = TRUE, pretty = TRUE)
```

(Add the factorial attribution block: rerun with `weights = NULL` and `n_iterations = 2` to decompose unweighted/non-converged effects, reporting pairwise ARI.)

- [ ] **Step 2: Write the ncp/kk ARI script** — `ari(partition(ncp=8) vs partition(ncp=15))` and ARI across ≥5 `kk` k-means seeds; keep fast settings only if ARI ≳ 0.9, else print a FLAG. Write `reports/phenotype-approximation-ari-<date>.json`.

- [ ] **Step 3: Run both once and commit the reports** (host R with DB access per `documentation/08-development.qmd`; `HOST_R_LD_LIBRARY_PATH` override may be needed).

```bash
git add api/scripts/analysis-validation/
git commit -m "chore(analysis): archived resolution-sweep + ncp/kk ARI diagnostics (#457, #458)"
```

---

## Self-Review

- **Spec coverage:** #457 weighted+converged (T1), `resolution` (T1), validation helper + `partition_scope` (T3), resolution sweep + attribution (T8). #458 data-driven k (T2), `min_size` (T2), coords for silhouette (T2/T3), `cluster_signature` (T2), ncp/kk ARI (T8). #459 migration (T4), persist per-cluster + partition-level + DB label (T5), expose service + MCP (T5/T6), preset weight + schema (T7). ✅ all spec sections mapped.
- **Placeholder scan:** the only "align to actual source" notes (builder entry-point name in T5, MCP fixtures in T6) are explicit read-the-file instructions with the exact target identified, not deferred work. No TODO/TBD.
- **Type consistency:** `validate_functional_clusters`/`validate_phenotype_clusters` return shapes in T3 match the consumption in T5 (`val$per_cluster`, `val$partition`); `gen_mca_clust_obj` list return in T2 matches the attribute consumption in T5; `cluster_max_jaccard(reference_members, bootstrap_clusters, present_ids)` signature consistent T3↔helpers.

## Execution sequencing

T1 ∥ T2 (independent) → T3 (needs T1, T2) → T4 (independent, can run any time) → T5 (needs T3, T4) → T6 ∥ T7 (need T5) → T8 (needs T1, T2). Post-merge operational step: bump derived-analysis cache version + refresh snapshots + regenerate affected LLM summaries (see spec Operational notes).
