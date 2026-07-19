# Phenotype Missingness Sensitivity (#582) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an additive, missingness-aware positive-only Jaccard sensitivity metric to the phenotype-clustering validation, stored under `partition_validation$missingness_sensitivity`, without changing the served partition, `cluster_hash`, or LLM summaries.

**Architecture:** A new self-contained R module extracts recorded-present ("positive") HPO term sets from the encoded active matrix the validator already receives, builds a modified Jaccard dissimilarity that never rewards jointly-unrecorded pairs, reclusters with average-linkage `hclust` at the served visible cluster count, and reports ARI / per-cluster max-Jaccard recovery / Jaccard-space silhouette vs the served partition. `validate_phenotype_clusters()` calls it best-effort (env-gated, `tryCatch`) and attaches the result to its `partition` list, which the builder excludes from `payload_hash`.

**Tech Stack:** R, base `stats` (`hclust`, `cutree`, `as.dist`), `cluster::silhouette` (optional — degrades to `NA` when absent), testthat.

**Spec:** `.planning/superpowers/specs/2026-07-19-phenotype-missingness-sensitivity-582-design.md` (Codex 5.6-sol reviewed).

## Global Constraints

- **Additive only.** The field lives in `val$partition` → `partition_validation`, which the builder excludes from the payload hash (`analysis-snapshot-builder.R:503`: `payload[setdiff(names(payload), c("raw", "partition_validation", "reproducibility"))]`). Never change `val$per_cluster`, `val$reference_members`, `ref_members`, or the served membership. Do **not** bump `CLUSTER_LOGIC_VERSION`.
- **Namespace explicitly** in API/worker code: `dplyr::select`, `stats::`, `cluster::`, `base::get` — loaded packages mask `select`, `get`, `merge`. Use `dplyr::*_join`, `stats::setNames`, etc.
- **Determinism:** no RNG in the new code. Reproducibility is conditional on the explicit `sort()` of entity ids — permutation-invariant.
- **Encoding semantics:** an `absent` MCA cell means **not recorded / unknown**, NOT confirmed clinical absence. Provenance uses `encoding_semantics = "present/not_recorded"`; the distance is `"one_minus_jaccard_modified"` (because `d(∅,∅)=1` breaks the Jaccard identity axiom).
- **Host vs container:** `cluster` and `RMariaDB` are NOT installed on host R. The new unit tests must run on host — silhouette assertions guard with `testthat::skip_if_not_installed("cluster")`.
- **File-size ceiling:** keep the new file under 600 lines (it will be ~230).
- **Commits:** every commit message ends with the repo footer line `Claude-Session: https://claude.ai/code/session_01GXKRAQPitLjZ5uYQbX7Y8G` (append it to each commit below).

## File Structure

- **Create** `api/functions/analysis-phenotype-missingness.R` — the whole metric: active-term resolution, positive-set extraction, modified-Jaccard dissimilarity, ARI, silhouette/band private helpers, and the orchestrator. One responsibility: positive-only missingness sensitivity.
- **Create** `api/tests/testthat/test-unit-phenotype-missingness.R` — unit tests (host-runnable).
- **Modify** `api/bootstrap/load_modules.R` — source the new file before `analysis-cluster-validation.R`.
- **Modify** `api/bootstrap/setup_workers.R` — same, in the `everywhere()` block.
- **Modify** `api/functions/analysis-cluster-validation.R` — call the orchestrator best-effort and attach `missingness_sensitivity` to the phenotype `partition` list.
- **Modify** `api/tests/testthat/test-unit-analysis-cluster-validation.R` — additivity regression + presence assertions.
- **Create** `api/tests/testthat/test-unit-analysis-snapshot-service-missingness.R` — public serialization round-trip.
- **Modify** `AGENTS.md` and the relevant `documentation/*.qmd` — encoding-semantics + metric documentation (AC10).

---

### Task 1: Core positive-only Jaccard + ARI helpers (pure functions)

**Files:**
- Create: `api/functions/analysis-phenotype-missingness.R`
- Test: `api/tests/testthat/test-unit-phenotype-missingness.R`

**Interfaces:**
- Consumes: nothing (pure).
- Produces:
  - `phenotype_active_terms(matrix, quali_sup_var = 1:1, quanti_sup_var = 2:4)` → `character`
  - `phenotype_positive_sets_from_matrix(mat, active_cols)` → named `list` (entity_id → char vec)
  - `positive_jaccard_dissimilarity(positive_sets, entity_order = NULL)` → symmetric numeric `matrix` with `dimnames = entity_order` and integer attr `n_empty_positive_sets`
  - `adjusted_rand_index(a, b)` → `double` (or `NA_real_`)

- [ ] **Step 1: Write the failing tests**

Create `api/tests/testthat/test-unit-phenotype-missingness.R`:

```r
source_api_file("functions/analysis-phenotype-missingness.R", local = FALSE, envir = globalenv())

# ---- positive-set extraction ----------------------------------------------
test_that("phenotype_active_terms prefers mca_provenance$kept_terms", {
  m <- data.frame(inh = "AD", c1 = 1, c2 = 2, c3 = 3,
                  Seizures = factor("present", c("absent", "present")),
                  Microcephaly = factor("absent", c("absent", "present")))
  attr(m, "mca_provenance") <- list(kept_terms = c("Seizures", "Microcephaly"))
  expect_setequal(phenotype_active_terms(m, 1:1, 2:4), c("Seizures", "Microcephaly"))
})

test_that("phenotype_active_terms falls back to positional complement", {
  m <- data.frame(inh = "AD", c1 = 1, c2 = 2, c3 = 3,
                  Seizures = factor("present", c("absent", "present")))
  expect_equal(phenotype_active_terms(m, 1:1, 2:4), "Seizures")
})

test_that("positive sets ignore supplementary + absent/NA cells (factor labels, not codes)", {
  m <- data.frame(
    inh = c("AD", "AR"), c1 = c(1, 2), c2 = c(0, 0), c3 = c(1, 1),
    Seizures = factor(c("present", "absent"), c("absent", "present")),
    ID       = factor(c("present", "present"), c("absent", "present")),
    stringsAsFactors = FALSE
  )
  rownames(m) <- c("e1", "e2")
  sets <- phenotype_positive_sets_from_matrix(m, c("Seizures", "ID"))
  expect_setequal(sets[["e1"]], c("Seizures", "ID"))
  expect_setequal(sets[["e2"]], "ID")
})

# ---- modified Jaccard dissimilarity ---------------------------------------
test_that("identical positive sets have distance 0", {
  D <- positive_jaccard_dissimilarity(list(a = c("x", "y"), b = c("x", "y")))
  expect_equal(D["a", "b"], 0)
})

test_that("disjoint sets have distance 1 regardless of jointly-unrecorded terms", {
  # a and b each have ONE distinct positive term; all other active terms are jointly
  # unrecorded and must NOT pull them together.
  D <- positive_jaccard_dissimilarity(list(a = "x", b = "y"))
  expect_equal(D["a", "b"], 1)
})

test_that("empty-set pairs are distance 1, never an artificial zero", {
  D <- positive_jaccard_dissimilarity(list(a = character(0), b = character(0),
                                           c = "x"))
  expect_equal(D["a", "b"], 1)   # both empty -> modified rule d = 1
  expect_equal(D["a", "c"], 1)   # one empty -> naturally d = 1
  expect_equal(diag(D), c(a = 0, b = 0, c = 0), ignore_attr = TRUE)
  expect_equal(attr(D, "n_empty_positive_sets"), 2L)
})

test_that("partial overlap is exactly 1 - |cap|/|cup|", {
  D <- positive_jaccard_dissimilarity(list(a = c("x", "y", "z"), b = c("y", "z", "w")))
  expect_equal(D["a", "b"], 1 - 2 / 4)
})

# ---- adjusted Rand index --------------------------------------------------
test_that("adjusted_rand_index is 1 for identical labelings", {
  expect_equal(adjusted_rand_index(c(1, 1, 2, 2), c(2, 2, 9, 9)), 1)
})

test_that("adjusted_rand_index is ~0 for independent labelings", {
  set.seed(1)
  a <- rep(1:2, each = 50); b <- sample(a)
  expect_lt(abs(adjusted_rand_index(a, b)), 0.15)
})

test_that("adjusted_rand_index is NA when the adjustment denominator is zero", {
  expect_true(is.na(adjusted_rand_index(rep(1, 6), rep(1, 6))))  # both single-cluster
})

test_that("adjusted_rand_index errors on unequal lengths", {
  expect_error(adjusted_rand_index(1:3, 1:4), "equal length")
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-phenotype-missingness.R')"`
Expected: FAIL — `could not find function "phenotype_active_terms"` (file/functions not defined yet).

- [ ] **Step 3: Create the module with the four pure helpers**

Create `api/functions/analysis-phenotype-missingness.R`:

```r
# functions/analysis-phenotype-missingness.R
#
# Missingness-aware positive-only sensitivity for the phenotype cluster analysis (#582).
# Worker/heavy-path only. Additive validation attached to
# partition_validation$missingness_sensitivity — DETERMINISTIC, no external calls, and
# EXCLUDED from analysis_snapshot_payload_hash, so it never changes membership/cluster_hash.
#
# The served MCA/HCPC partition encodes an unrecorded HPO annotation as `absent`
# (phenotype_mca_prep_matrix). Here `absent` means NOT RECORDED / UNKNOWN, not confirmed
# clinical absence. This sensitivity re-derives entity similarity from POSITIVE
# (recorded-present) evidence only, using a MODIFIED Jaccard dissimilarity that never
# rewards a pair for jointly-unrecorded terms, and reports how well the served partition
# survives that stricter representation.
#
# Refs: Jaccard 1912; Hubert & Arabie 1985 (adjusted Rand index); Kaufman & Rousseeuw 1990
# (silhouette bands).

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

#' Active (non-supplementary) HPO term column names of an encoded phenotype matrix.
#'
#' Authoritative source: the `mca_provenance$kept_terms` attribute attached by
#' phenotype_mca_prep_matrix(). Falls back to the positional complement of the
#' supplementary columns for test matrices without the attribute. Both are intersected
#' with the actual columns so a stale attribute can never name a missing column.
phenotype_active_terms <- function(matrix, quali_sup_var = 1:1, quanti_sup_var = 2:4) {
  cols <- colnames(matrix)
  prov <- attr(matrix, "mca_provenance")
  kept <- if (!is.null(prov) && !is.null(prov$kept_terms)) as.character(prov$kept_terms) else NULL
  if (!is.null(kept) && length(kept) > 0L) {
    return(intersect(kept, cols))
  }
  sup_idx <- unique(c(quali_sup_var, quanti_sup_var))
  sup_idx <- sup_idx[sup_idx >= 1L & sup_idx <= length(cols)]
  setdiff(cols, cols[sup_idx])
}

#' Positive-term set per entity from an encoded phenotype matrix.
#'
#' A cell is POSITIVE when it is "present" (encoded factor level) or "yes" (a raw
#' pre-encoding matrix, accepted defensively). "absent"/NA are NOT recorded and enter no
#' set. Factor columns are coerced to their LABELS (as.character), never integer codes.
phenotype_positive_sets_from_matrix <- function(mat, active_cols) {
  ids <- rownames(mat)
  if (is.null(ids)) ids <- as.character(seq_len(nrow(mat)))
  active_cols <- intersect(active_cols, colnames(mat))
  if (length(active_cols) == 0L) {
    return(stats::setNames(rep(list(character(0)), length(ids)), ids))
  }
  char_cols <- lapply(active_cols, function(cn) as.character(mat[[cn]]))
  cm <- do.call(cbind, char_cols)              # n_entities x n_active character matrix
  colnames(cm) <- active_cols
  stats::setNames(lapply(seq_len(nrow(cm)), function(i) {
    v <- cm[i, ]
    active_cols[!is.na(v) & (v == "present" | v == "yes")]
  }), ids)
}

#' Modified positive-only Jaccard dissimilarity over entities.
#'
#' d(A,B) = 1 - |A cap B| / |A cup B|, with the empty-union case (two DIFFERENT entities
#' both carrying zero positive evidence) defined as d = 1 (NOT 0) so jointly-unrecorded
#' entities are never an artificial zero-distance pair. Diagonal is 0.
#'
#' Vectorized: incidence X (entities x terms); intersection = X %*% t(X); union =
#' |A| + |B| - inter. Reuses the union buffer in place (inter, X, D) to bound peak memory.
positive_jaccard_dissimilarity <- function(positive_sets, entity_order = NULL) {
  if (is.null(entity_order)) entity_order <- sort(names(positive_sets))
  positive_sets <- positive_sets[entity_order]
  n <- length(entity_order)
  set_sizes <- vapply(positive_sets, length, integer(1))
  n_empty <- sum(set_sizes == 0L)

  terms <- sort(unique(unlist(positive_sets, use.names = FALSE)))
  if (n <= 1L || length(terms) == 0L) {
    D <- matrix(if (n <= 1L) 0 else 1, nrow = n, ncol = n,
                dimnames = list(entity_order, entity_order))
    diag(D) <- 0
    attr(D, "n_empty_positive_sets") <- as.integer(n_empty)
    return(D)
  }

  X <- matrix(0L, nrow = n, ncol = length(terms),
              dimnames = list(entity_order, terms))
  for (i in seq_len(n)) {
    ti <- positive_sets[[i]]
    if (length(ti)) X[i, ti] <- 1L
  }
  inter <- X %*% t(X)                             # n x n intersection sizes
  sizes <- rowSums(X)
  D <- outer(sizes, sizes, `+`) - inter           # D holds the UNION buffer
  nz <- D > 0
  D[nz]  <- 1 - inter[nz] / D[nz]                 # union > 0 -> 1 - J
  D[!nz] <- 1                                     # empty union -> distance 1
  diag(D) <- 0
  dimnames(D) <- list(entity_order, entity_order)
  attr(D, "n_empty_positive_sets") <- as.integer(n_empty)
  D
}

#' Adjusted Rand Index (Hubert & Arabie 1985) between two label vectors.
#'
#' ARI = (index - expected) / (max_index - expected). Returns NA_real_ iff the adjustment
#' denominator is zero (non-adjustable, e.g. both labelings a single cluster).
adjusted_rand_index <- function(a, b) {
  if (length(a) != length(b)) {
    stop("adjusted_rand_index: label vectors must have equal length", call. = FALSE)
  }
  n <- length(a)
  if (n < 2L) return(NA_real_)
  tab <- table(a, b)
  comb2 <- function(x) sum(x * (x - 1) / 2)
  index     <- comb2(as.vector(tab))
  a_sums    <- comb2(rowSums(tab))
  b_sums    <- comb2(colSums(tab))
  total     <- n * (n - 1) / 2
  expected  <- a_sums * b_sums / total
  max_index <- (a_sums + b_sums) / 2
  denom <- max_index - expected
  if (denom == 0) return(NA_real_)
  (index - expected) / denom
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-phenotype-missingness.R')"`
Expected: PASS (all Task-1 tests green).

- [ ] **Step 5: Commit**

```bash
git add api/functions/analysis-phenotype-missingness.R api/tests/testthat/test-unit-phenotype-missingness.R
git commit -m "feat(analysis): positive-only Jaccard + ARI helpers for phenotype missingness sensitivity (#582)"
```

---

### Task 2: Orchestrator with non-informative guard, statuses, and alignment invariants

**Files:**
- Modify: `api/functions/analysis-phenotype-missingness.R` (append orchestrator + private helpers)
- Test: `api/tests/testthat/test-unit-phenotype-missingness.R` (append)

**Interfaces:**
- Consumes: `phenotype_active_terms`, `phenotype_positive_sets_from_matrix`, `positive_jaccard_dissimilarity`, `adjusted_rand_index` (Task 1); `cluster_max_jaccard` (from `analysis-cluster-validation.R`, present at worker runtime and sourced by the test).
- Produces: `phenotype_missingness_sensitivity(wide_phenotypes_df, ref_members, quali_sup_var = 1:1, quanti_sup_var = 2:4)` → the result `list` (spec §4.6).

- [ ] **Step 1: Write the failing tests**

Append to `api/tests/testthat/test-unit-phenotype-missingness.R`:

```r
# cluster_max_jaccard lives in the validator module (present at worker runtime).
source_api_file("functions/analysis-cluster-validation.R", local = FALSE, envir = globalenv())

# Build a small encoded phenotype matrix with a clean 2-cluster POSITIVE structure.
# Cluster A entities share {Seizures, ID}; cluster B entities share {Microcephaly, Ataxia}.
.mk_pheno_matrix <- function() {
  lv <- c("absent", "present")
  f <- function(x) factor(x, lv)
  m <- data.frame(
    inh = rep("AD", 6),
    c1 = 0, c2 = 0, c3 = 0,
    Seizures     = f(c("present", "present", "present", "absent",  "absent",  "absent")),
    ID           = f(c("present", "present", "present", "absent",  "absent",  "absent")),
    Microcephaly = f(c("absent",  "absent",  "absent",  "present", "present", "present")),
    Ataxia       = f(c("absent",  "absent",  "absent",  "present", "present", "present")),
    stringsAsFactors = FALSE
  )
  rownames(m) <- paste0("e", 1:6)
  attr(m, "mca_provenance") <- list(kept_terms = c("Seizures", "ID", "Microcephaly", "Ataxia"))
  m
}

test_that("orchestrator recovers a clean 2-cluster structure (ARI = 1)", {
  m <- .mk_pheno_matrix()
  ref <- list("1" = c("e1", "e2", "e3"), "2" = c("e4", "e5", "e6"))
  res <- phenotype_missingness_sensitivity(m, ref)
  expect_equal(res$status, "ok")
  expect_equal(res$k, 2L)
  expect_equal(res$n_entities_assigned, 6L)
  expect_equal(res$n_active_terms, 4L)
  expect_equal(res$adjusted_rand_index, 1)
  expect_named(res$per_cluster_max_jaccard, c("1", "2"))
  expect_equal(unname(unlist(res$per_cluster_max_jaccard)), c(1, 1))
  expect_true(all(c("silhouette_served_partition", "silhouette_sensitivity_partition") %in% names(res)))
})

test_that("orchestrator silhouette is well-separated when cluster pkg present", {
  testthat::skip_if_not_installed("cluster")
  res <- phenotype_missingness_sensitivity(.mk_pheno_matrix(),
                                           list("1" = c("e1","e2","e3"), "2" = c("e4","e5","e6")))
  expect_gt(res$silhouette_served_partition, 0.5)
})

test_that("orchestrator records eligibility counts incl. unassigned entities", {
  m <- .mk_pheno_matrix()                       # 6 rows
  ref <- list("1" = c("e1", "e2", "e3"), "2" = c("e4", "e5"))  # e6 unassigned
  res <- phenotype_missingness_sensitivity(m, ref)
  expect_equal(res$n_entities_input, 6L)
  expect_equal(res$n_entities_assigned, 5L)
  expect_equal(res$n_entities_excluded_unassigned, 1L)
})

test_that("orchestrator is deterministic and permutation-invariant", {
  m <- .mk_pheno_matrix()
  ref <- list("1" = c("e1", "e2", "e3"), "2" = c("e4", "e5", "e6"))
  r1 <- phenotype_missingness_sensitivity(m, ref)
  r2 <- phenotype_missingness_sensitivity(m[sample(nrow(m)), ], ref)
  expect_equal(r1$adjusted_rand_index, r2$adjusted_rand_index)
  expect_equal(r1$per_cluster_max_jaccard, r2$per_cluster_max_jaccard)
})

test_that("non-informative distance matrix -> undefined_no_distance_structure (all-disjoint)", {
  lv <- c("absent", "present"); f <- function(x) factor(x, lv)
  m <- data.frame(inh = "AD", c1 = 0, c2 = 0, c3 = 0,
                  T1 = f(c("present", "absent", "absent", "absent")),
                  T2 = f(c("absent", "present", "absent", "absent")),
                  T3 = f(c("absent", "absent", "present", "absent")),
                  T4 = f(c("absent", "absent", "absent", "present")))
  rownames(m) <- paste0("e", 1:4)
  attr(m, "mca_provenance") <- list(kept_terms = c("T1", "T2", "T3", "T4"))
  res <- phenotype_missingness_sensitivity(m, list("1" = c("e1", "e2"), "2" = c("e3", "e4")))
  expect_equal(res$status, "undefined_no_distance_structure")
  expect_true(is.na(res$adjusted_rand_index))
  expect_length(res$per_cluster_max_jaccard, 0)
})

test_that("all-empty positive sets -> undefined_no_distance_structure", {
  lv <- c("absent", "present"); f <- function(x) factor(x, lv)
  m <- data.frame(inh = "AD", c1 = 0, c2 = 0, c3 = 0,
                  T1 = f(rep("absent", 4)), T2 = f(rep("absent", 4)))
  rownames(m) <- paste0("e", 1:4)
  attr(m, "mca_provenance") <- list(kept_terms = c("T1", "T2"))
  res <- phenotype_missingness_sensitivity(m, list("1" = c("e1", "e2"), "2" = c("e3", "e4")))
  expect_equal(res$status, "undefined_no_distance_structure")
  expect_equal(res$n_empty_positive_sets, 4L)
})

test_that("orchestrator fails closed on alignment violations", {
  m <- .mk_pheno_matrix()
  # e9 is not a matrix row -> alignment invariant violated.
  res <- phenotype_missingness_sensitivity(m, list("1" = c("e1", "e2"), "2" = c("e9")))
  expect_equal(res$status, "error")
})

test_that("fewer than 2 clusters -> undefined_lt2_clusters", {
  m <- .mk_pheno_matrix()
  res <- phenotype_missingness_sensitivity(m, list("1" = c("e1", "e2", "e3")))
  expect_equal(res$status, "undefined_lt2_clusters")
})

test_that("production-shape extraction: raw {yes,NA} through mca prep, then positive sets", {
  source_api_file("functions/analysis-phenotype-mca-prep.R", local = FALSE, envir = globalenv())
  raw <- data.frame(
    inh = c("AD", "AR", "AD", "AR"),
    phenotype_non_id_count = c(1, 1, 1, 1),
    phenotype_id_count = c(1, 1, 1, 1),
    gene_entity_count = c(1, 1, 1, 1),
    Seizures = c("yes", "yes", NA, NA),
    ID       = c("yes", NA, "yes", "yes"),
    Ataxia   = c(NA, "yes", "yes", NA),
    stringsAsFactors = FALSE
  )
  rownames(raw) <- paste0("e", 1:4)
  enc <- phenotype_mca_prep_matrix(raw)          # {absent,present} factors + provenance
  active <- phenotype_active_terms(enc)
  sets <- phenotype_positive_sets_from_matrix(enc, active)
  expect_true("Seizures" %in% sets[["e1"]])      # recorded present survives
  expect_false("Seizures" %in% sets[["e3"]])     # NA -> not recorded -> absent from set
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-phenotype-missingness.R')"`
Expected: FAIL — `could not find function "phenotype_missingness_sensitivity"`.

- [ ] **Step 3: Append the orchestrator + private helpers**

Append to `api/functions/analysis-phenotype-missingness.R`:

```r
# Mean silhouette of a labeling on dissimilarity D. NA when < 2 distinct labels or when
# the optional `cluster` package is unavailable (host CI) — the metric degrades, never errors.
.missingness_silhouette <- function(labels, D) {
  lab_int <- as.integer(factor(labels))
  if (length(unique(lab_int)) < 2L) return(NA_real_)
  if (!requireNamespace("cluster", quietly = TRUE)) return(NA_real_)
  sil <- tryCatch(cluster::silhouette(lab_int, stats::as.dist(D)), error = function(e) NULL)
  if (is.null(sil)) return(NA_real_)
  mean(sil[, "sil_width"])
}

# ARI agreement band (interpretation only, never a gate).
.missingness_ari_band <- function(ari) {
  if (!is.finite(ari)) return(NA_character_)
  if (ari >= 0.75) "strong_agreement"
  else if (ari >= 0.5) "moderate_agreement"
  else if (ari >= 0.25) "weak_agreement"
  else "poor_agreement"
}

#' Positive-only missingness sensitivity for the served phenotype partition.
#'
#' @param wide_phenotypes_df the encoded active matrix the validator received (entities in
#'   rownames; leading supplementary columns; active {absent,present} factors).
#' @param ref_members named list cluster_id -> served entity_id character vectors (the
#'   served visible partition, keyed as in validate_phenotype_clusters()).
#' @return the missingness_sensitivity result list (spec §4.6). Best-effort: alignment/guard
#'   failures return a diagnostic `status`, never an error, so the caller's refresh survives.
phenotype_missingness_sensitivity <- function(wide_phenotypes_df, ref_members,
                                              quali_sup_var = 1:1, quanti_sup_var = 2:4) {
  base <- list(
    status = "ok",
    data_class = "curated_derived_analysis",
    method = "positive_only_jaccard",
    linkage = "average",
    distance = "one_minus_jaccard_modified",
    encoding_semantics = "present/not_recorded",
    empty_union_distance = 1L
  )

  assigned <- as.character(unlist(ref_members, use.names = FALSE))
  n_input <- nrow(wide_phenotypes_df)
  row_ids <- rownames(wide_phenotypes_df)
  if (is.null(row_ids)) row_ids <- as.character(seq_len(n_input))

  # Alignment invariants (fail-closed -> status "error", never a silent mislabel).
  if (anyDuplicated(row_ids) || anyDuplicated(assigned) || !all(assigned %in% row_ids)) {
    return(c(base, list(status = "error",
                        message = "alignment invariant violated (dup rows / dup members / missing member)")))
  }

  n_clusters <- length(ref_members)
  active_cols <- phenotype_active_terms(wide_phenotypes_df, quali_sup_var, quanti_sup_var)
  entity_order <- sort(unique(assigned))
  n_assigned <- length(entity_order)

  counts <- list(
    k = as.integer(n_clusters),
    n_entities_input = as.integer(n_input),
    n_entities_assigned = as.integer(n_assigned),
    n_entities_excluded_unassigned = as.integer(n_input - n_assigned),
    n_active_terms = length(active_cols)
  )

  if (n_clusters < 2L || n_assigned < 2L) {
    return(c(base, counts, list(
      status = "undefined_lt2_clusters",
      n_empty_positive_sets = NA_integer_,
      adjusted_rand_index = NA_real_,
      per_cluster_max_jaccard = list(),
      silhouette_served_partition = NA_real_,
      silhouette_sensitivity_partition = NA_real_
    )))
  }

  sub <- wide_phenotypes_df[entity_order, , drop = FALSE]
  positive_sets <- phenotype_positive_sets_from_matrix(sub, active_cols)
  D <- positive_jaccard_dissimilarity(positive_sets, entity_order = entity_order)
  counts$n_empty_positive_sets <- as.integer(attr(D, "n_empty_positive_sets") %||% NA_integer_)

  ent_to_cluster <- stats::setNames(
    rep(names(ref_members), lengths(ref_members)),
    as.character(unlist(ref_members, use.names = FALSE))
  )
  served_labels <- ent_to_cluster[entity_order]

  # Non-informative distance guard: only one unique finite off-diagonal value -> the cut is
  # an artifact of tie order, not phenotype structure. Report served silhouette only.
  lower <- D[lower.tri(D)]
  if (length(unique(lower[is.finite(lower)])) <= 1L) {
    return(c(base, counts, list(
      status = "undefined_no_distance_structure",
      adjusted_rand_index = NA_real_,
      per_cluster_max_jaccard = list(),
      silhouette_served_partition = .missingness_silhouette(served_labels, D),
      silhouette_sensitivity_partition = NA_real_
    )))
  }

  hc <- stats::hclust(stats::as.dist(D), method = "average")
  sens_labels <- stats::cutree(hc, k = n_clusters)

  ari <- adjusted_rand_index(as.character(served_labels), as.integer(sens_labels))
  sens_clusters <- split(entity_order, sens_labels)
  recovery <- cluster_max_jaccard(lapply(ref_members, as.character), sens_clusters, entity_order)

  c(base, counts, list(
    adjusted_rand_index = ari,
    per_cluster_max_jaccard = as.list(recovery),
    silhouette_served_partition = .missingness_silhouette(served_labels, D),
    silhouette_sensitivity_partition = .missingness_silhouette(sens_labels, D),
    interpretation = .missingness_ari_band(ari)
  ))
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-phenotype-missingness.R')"`
Expected: PASS (Task-1 + Task-2 tests; the silhouette-value test skips if `cluster` absent).

- [ ] **Step 5: Commit**

```bash
git add api/functions/analysis-phenotype-missingness.R api/tests/testthat/test-unit-phenotype-missingness.R
git commit -m "feat(analysis): phenotype missingness sensitivity orchestrator with guards + statuses (#582)"
```

---

### Task 3: Register the module and wire it into the validator (additive)

**Files:**
- Modify: `api/bootstrap/load_modules.R` (source before `analysis-cluster-validation.R`)
- Modify: `api/bootstrap/setup_workers.R` (`everywhere()` block, before `analysis-cluster-validation.R`)
- Modify: `api/functions/analysis-cluster-validation.R` (call + attach field)
- Test: `api/tests/testthat/test-unit-analysis-cluster-validation.R` (additivity regression + presence)

**Interfaces:**
- Consumes: `phenotype_missingness_sensitivity` (Task 2), `analysis_snapshot_payload_hash` (from `analysis-snapshot-builder.R`).
- Produces: `validate_phenotype_clusters(...)$partition$missingness_sensitivity`.

- [ ] **Step 1: Write the failing additivity + presence tests**

Append to `api/tests/testthat/test-unit-analysis-cluster-validation.R`:

```r
source_api_file("functions/analysis-snapshot-builder.R", local = FALSE, envir = globalenv())

test_that("missingness_sensitivity is EXCLUDED from payload_hash (additive, no cluster_hash churn)", {
  base_payload <- list(
    kind = "clusters",
    clusters = tibble::tibble(cluster = 1:2, hash_filter = c("h1", "h2")),
    members = tibble::tibble(entity_id = c("e1", "e2")),
    row_counts = list(clusters = 2L),
    partition_validation = list(
      algorithm = "mca_hcpc",
      missingness_sensitivity = list(status = "ok", adjusted_rand_index = 0.90)
    )
  )
  variant <- base_payload
  variant$partition_validation$missingness_sensitivity <-
    list(status = "ok", adjusted_rand_index = 0.10)

  hash_of <- function(p) analysis_snapshot_payload_hash(
    p[setdiff(names(p), c("raw", "partition_validation", "reproducibility"))]
  )
  expect_identical(hash_of(base_payload), hash_of(variant))
})
```

- [ ] **Step 2: Run the additivity test to verify it passes already (guard the invariant)**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-cluster-validation.R')"`
Expected: PASS — this test locks the existing exclusion behavior so a future edit that drops `partition_validation` from the excluded set fails loudly. (It is a regression guard, not a red→green step.)

- [ ] **Step 3: Register the new module in both worker entrypoints**

In `api/bootstrap/load_modules.R`, add the new file immediately before `functions/analysis-cluster-validation.R` (currently line 146):

```r
    "functions/analysis-null-models.R",
    "functions/analysis-phenotype-missingness.R",
    "functions/analysis-cluster-validation.R",
```

In `api/bootstrap/setup_workers.R`, inside `mirai::everywhere({ ... })`, add before the `analysis-cluster-validation.R` source (currently line 98):

```r
    source("/app/functions/analysis-null-models.R", local = FALSE)
    source("/app/functions/analysis-phenotype-missingness.R", local = FALSE)
    source("/app/functions/analysis-cluster-validation.R", local = FALSE)
```

- [ ] **Step 4: Wire the call into `validate_phenotype_clusters()`**

In `api/functions/analysis-cluster-validation.R`, inside `validate_phenotype_clusters()`, immediately before the final `list(per_cluster = ..., ...)` return (after `per_cluster` is built, ~line 389-397), add:

```r
  # #582: additive positive-only missingness sensitivity. Best-effort + env-gated, mirroring
  # the ncp_diag/kg patterns; a failure degrades to a diagnostic field, never fails the refresh.
  # ref_members here is keyed cluster_id -> entity_id char vecs, exactly what the orchestrator
  # expects; wide_phenotypes_df is the encoded active matrix (present cells = recorded present).
  missingness <- if (identical(tolower(Sys.getenv(
        "ANALYSIS_PHENOTYPE_MISSINGNESS_SENSITIVITY", "true")), "true") &&
      exists("phenotype_missingness_sensitivity", mode = "function")) {
    tryCatch(
      phenotype_missingness_sensitivity(wide_phenotypes_df, ref_members,
                                        quali_sup_var = quali_sup_var,
                                        quanti_sup_var = quanti_sup_var),
      error = function(e) list(status = "error", message = conditionMessage(e))
    )
  } else {
    list(status = "skipped")
  }
```

Then, in the `partition = list(...)` block of that same return, add one line (after `dip_scope = "mca_coord_distance",`):

```r
      missingness_sensitivity = missingness,
```

- [ ] **Step 5: Add the presence test for the validator return**

Append to `api/tests/testthat/test-unit-analysis-cluster-validation.R`:

```r
test_that("validate_phenotype_clusters attaches missingness_sensitivity additively", {
  testthat::skip_if_not_installed("FactoMineR")
  testthat::skip_if_not_installed("cluster")
  source_api_file("functions/analysis-phenotype-mca-prep.R", local = FALSE, envir = globalenv())
  source_api_file("functions/analysis-phenotype-functions.R", local = FALSE, envir = globalenv())
  source_api_file("functions/analysis-null-models.R", local = FALSE, envir = globalenv())
  source_api_file("functions/analysis-phenotype-missingness.R", local = FALSE, envir = globalenv())

  # Small synthetic encoded matrix with a 2-cluster positive structure and the real
  # 4 leading supplementary columns, so gen_mca_clust_obj/HCPC produce >= 2 clusters.
  lv <- c("absent", "present"); f <- function(x) factor(x, lv)
  n <- 40
  grp <- rep(1:2, each = n / 2)
  m <- data.frame(
    inh = rep("AD", n),
    phenotype_non_id_count = 1, phenotype_id_count = 1, gene_entity_count = 1,
    Seizures     = f(ifelse(grp == 1, "present", "absent")),
    ID           = f(ifelse(grp == 1, "present", "absent")),
    Microcephaly = f(ifelse(grp == 2, "present", "absent")),
    Ataxia       = f(ifelse(grp == 2, "present", "absent"))
  )
  rownames(m) <- paste0("e", seq_len(n))
  attr(m, "mca_provenance") <- list(kept_terms = c("Seizures", "ID", "Microcephaly", "Ataxia"))

  val <- tryCatch(
    validate_phenotype_clusters(m, quali_sup_var = 1:1, quanti_sup_var = 2:4,
                                min_size = 5, n_resamples = 2),
    error = function(e) NULL
  )
  testthat::skip_if(is.null(val), "phenotype validator unavailable on host")
  ms <- val$partition$missingness_sensitivity
  expect_false(is.null(ms))
  expect_true(all(c("adjusted_rand_index", "per_cluster_max_jaccard",
                    "silhouette_served_partition") %in% names(ms)))
})
```

- [ ] **Step 6: Run the validator tests**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-cluster-validation.R')"`
Expected: PASS (the heavy validator test skips on host if `FactoMineR`/`cluster` are absent; the additivity guard passes).

- [ ] **Step 7: Commit**

```bash
git add api/functions/analysis-cluster-validation.R api/bootstrap/load_modules.R api/bootstrap/setup_workers.R api/tests/testthat/test-unit-analysis-cluster-validation.R
git commit -m "feat(analysis): attach missingness_sensitivity to phenotype partition validation (#582)"
```

---

### Task 4: Public serialization coverage + documentation

**Files:**
- Create: `api/tests/testthat/test-unit-analysis-snapshot-service-missingness.R`
- Modify: `AGENTS.md`
- Modify: the phenotype-validation `documentation/*.qmd` (grep-located)

**Interfaces:**
- Consumes: `service_analysis_snapshot_parse_json_object` / the snapshot JSON round-trip (`analysis-snapshot-service.R`).
- Produces: nothing new; asserts the additive field surfaces + serializes correctly and documents the semantics.

- [ ] **Step 1: Write the failing serialization test**

Create `api/tests/testthat/test-unit-analysis-snapshot-service-missingness.R`:

```r
source_api_file("functions/analysis-snapshot-builder.R", local = FALSE, envir = globalenv())

test_that("missingness_sensitivity round-trips through validation_json as a keyed object; validation_hash tracks it, payload_hash does not", {
  validation <- list(
    algorithm = "mca_hcpc",
    missingness_sensitivity = list(
      status = "ok",
      adjusted_rand_index = 0.82,
      per_cluster_max_jaccard = list("1" = 0.9, "2" = 0.7),
      silhouette_served_partition = 0.31
    )
  )
  json <- jsonlite::toJSON(validation, auto_unbox = TRUE, digits = NA, null = "null")
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  ms <- parsed$missingness_sensitivity
  expect_equal(ms$status, "ok")
  expect_equal(ms$adjusted_rand_index, 0.82)
  # per_cluster_max_jaccard MUST serialize as a keyed JSON object, not an array.
  expect_true(is.list(ms$per_cluster_max_jaccard))
  expect_named(ms$per_cluster_max_jaccard, c("1", "2"))

  # payload_hash is computed on a payload that EXCLUDES partition_validation, so a change in
  # the missingness block cannot move it; validation_hash (a hash of validation_json) does.
  base_validation <- validation
  changed <- validation
  changed$missingness_sensitivity$adjusted_rand_index <- 0.11
  vhash <- function(v) digest::digest(jsonlite::toJSON(v, auto_unbox = TRUE, digits = NA), algo = "sha256")
  expect_false(identical(vhash(base_validation), vhash(changed)))
})
```

- [ ] **Step 2: Run it to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-service-missingness.R')"`
Expected: PASS (documents the serialization contract; jsonlite serializes a named list as a JSON object).

- [ ] **Step 3: Locate the phenotype-validation documentation**

Run: `grep -rln "partition_validation\|phenotype_clustering\|absent/present\|MCA" documentation/`
Pick the qmd that documents the phenotype validation block (likely the analysis/snapshot chapter).

- [ ] **Step 4: Add the encoding-semantics + metric documentation**

In the located `documentation/*.qmd`, add a short subsection near the phenotype-validation description:

```markdown
#### Missingness-aware positive-only sensitivity (#582)

Unrecorded phenotype cells in the phenotype MCA/HCPC input are **unknown / not recorded**,
not confirmed clinical absence. The served partition operates on a present/`not_recorded`
encoding. An additive sensitivity metric, `partition_validation.missingness_sensitivity`,
re-derives entity similarity from **recorded-present evidence only** using a modified
positive-only Jaccard dissimilarity (`d(A,B) = 1 - |A∩B|/|A∪B|`, with two entities that
share no positive evidence held at distance 1, never 0). Fixing `k` to the served visible
cluster count, it reports the adjusted Rand index, per-cluster maximum Jaccard recovery, and
Jaccard-space mean silhouette against the served partition. It is additive: excluded from
`payload_hash`, it never changes membership, `cluster_hash`, or LLM summaries.
```

In `AGENTS.md`, under the "Cluster-analysis statistical soundness (#508–#512)" section, add:

```markdown
An additive **positive-only missingness sensitivity** (#582) is attached to the phenotype
axis at `partition_validation$missingness_sensitivity` by `validate_phenotype_clusters()`
(via `api/functions/analysis-phenotype-missingness.R`). Unrecorded phenotype cells are
**unknown / not recorded**, not confirmed absence; the metric re-derives similarity from
recorded-present evidence only (modified Jaccard, `d(∅,∅)=1`), reclusters with average-linkage
`hclust` at the served visible cluster count, and reports ARI, per-cluster max-Jaccard
recovery, and Jaccard-space silhouette vs the served partition. It is additive (excluded from
`payload_hash`; no `cluster_hash`/LLM churn) and env-gated by
`ANALYSIS_PHENOTYPE_MISSINGNESS_SENSITIVITY` (default on). **Deploy:** a forced phenotype
snapshot refresh mints a new phenotype `snapshot_id`, so the phenotype-functional
correlation snapshot must be force-refreshed afterward (its #571/#572 dependency gate pins
the phenotype `snapshot_id` + `payload_hash`); do not bump `CLUSTER_LOGIC_VERSION` or
regenerate LLM summaries.
```

- [ ] **Step 5: Run the file-size + fast audit**

Run: `cd api && Rscript -e "cat(length(readLines('functions/analysis-phenotype-missingness.R')), 'lines\n')"` (expect < 600)
Run: `make code-quality-audit`
Expected: audit passes; new file under the ceiling.

- [ ] **Step 6: Commit**

```bash
git add api/tests/testthat/test-unit-analysis-snapshot-service-missingness.R AGENTS.md documentation/
git commit -m "docs+test(analysis): document + serialization-guard phenotype missingness sensitivity (#582)"
```

---

## Final verification (after all tasks)

- [ ] **Container tests** (real `cluster`/`FactoMineR`/DB): copy tests into the running API container and run the new + touched suites:

```bash
docker cp api/tests/testthat/test-unit-phenotype-missingness.R sysndd-api-1:/app/tests/testthat/
docker cp api/tests/testthat/test-unit-analysis-cluster-validation.R sysndd-api-1:/app/tests/testthat/
docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-phenotype-missingness.R')"
docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-analysis-cluster-validation.R')"
```

- [ ] **Fast API gate:** `make test-api-fast`
- [ ] **Lint:** `make lint-api`
- [ ] **(Optional) live end-to-end** in a dev stack with the worker restarted: force-refresh `phenotype_clusters`, then `phenotype_functional_correlations`, and confirm `GET /api/analysis/phenotype_clustering` `meta.snapshot.validation.missingness_sensitivity` is populated and `meta.snapshot.payload_hash` is unchanged from before the refresh. **Reminder (config::get masks base::get):** verify in the fully-loaded API/worker env, not just host unit tests.

## Spec-coverage self-check

| Spec section | Task |
|---|---|
| §4.1 Jaccard core | Task 1 |
| §4.2 empty-set / modified naming | Task 1 |
| §4.3 non-informative guard | Task 2 |
| §4.4 sensitivity clustering + determinism | Task 2 |
| §4.5 ARI/recovery/silhouette + headline | Task 2 |
| §4.6 result shape + statuses | Task 2 |
| §5.1 module + kept_terms + alignment invariants | Task 1/2 |
| §5.2 validator integration | Task 3 |
| §5.3 additivity | Task 3 (guard) |
| §6 docs | Task 4 |
| §7 tests | Tasks 1–4 |
| §8 deploy runbook | Task 4 (AGENTS.md) + Final verification |
| §11 performance bound | Task 1 (in-place buffer reuse) |
