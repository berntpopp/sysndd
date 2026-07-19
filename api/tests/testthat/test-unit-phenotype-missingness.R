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
