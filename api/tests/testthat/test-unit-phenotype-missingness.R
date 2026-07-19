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
