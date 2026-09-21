# Real-data regression for #679. The fixture is the public reproducibility bundle
# of phenotype snapshot 196 (MCA coordinates at 4 decimals + the membership that was
# served). On this input the legacy single-start consolidation lands in the
# HIGHER-inertia of two k-means optima; the multi-start procedure must not.
# Base R only, so it runs on the host.

source_api_file("functions/analysis-phenotype-missingness.R", local = FALSE, envir = globalenv())
source_api_file("functions/analysis-phenotype-consolidation.R", local = FALSE, envir = globalenv())

read_snapshot196 <- function() {
  path <- file.path(get_api_dir(), "tests", "testthat", "fixtures",
                    "phenotype-snapshot196-coords.csv.gz")
  df <- utils::read.csv(gzfile(path), check.names = FALSE, stringsAsFactors = FALSE)
  x <- as.matrix(df[, grep("^Dim\\.", names(df)), drop = FALSE])
  rownames(x) <- as.character(df$entity_id)
  list(x = x, served = stats::setNames(as.integer(df$served_cluster), as.character(df$entity_id)))
}

# Pin the start count so an ambient ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS cannot
# change what these tests assert.
multistart_config <- function(n_starts = 100L) {
  cfg <- phenotype_consolidation_config()
  cfg$n_starts <- n_starts
  cfg
}

test_that("the fixture is the snapshot-196 bundle", {
  fx <- read_snapshot196()
  expect_identical(dim(fx$x), c(2017L, 8L))
  expect_identical(as.integer(sort(table(fx$served), decreasing = TRUE)), c(992L, 695L, 330L))
})

test_that("the documented k rule still selects k = 3", {
  fx <- read_snapshot196()
  wt <- phenotype_ward_tree(fx$x)
  sel <- phenotype_select_k(wt$within, 3L, 25L)
  expect_identical(sel$k, 3L)
  expect_equal(unname(sel$ratio_curve[["3"]]), 0.9012, tolerance = 1e-3)
})

test_that("n_starts = 0 replicates the served (legacy single-start) partition exactly", {
  fx <- read_snapshot196()
  legacy <- phenotype_cluster_coords(fx$x, config = multistart_config(0L))
  expect_equal(adjusted_rand_index(legacy$cluster, fx$served[names(legacy$cluster)]), 1)
  expect_equal(legacy$within_inertia, 0.3603, tolerance = 5e-4)
})

test_that("multi-start returns the lower-inertia optimum and reports the landscape", {
  fx <- read_snapshot196()
  fit <- phenotype_cluster_coords(fx$x, config = multistart_config())
  ls <- fit$landscape

  expect_identical(fit$k, 3L)
  expect_true(isTRUE(fit$converged))
  expect_equal(fit$within_inertia, 0.3530, tolerance = 5e-4)
  sizes <- as.integer(sort(table(fit$cluster), decreasing = TRUE))
  expect_true(all(abs(sizes - c(1121L, 555L, 341L)) <= 10L))

  # The chosen solution is the best of everything tried.
  expect_identical(ls$n_starts_total, 101L)
  basin_w <- vapply(ls$basins, function(b) b$best_within_inertia, numeric(1))
  expect_true(all(fit$within_inertia <= basin_w + 1e-12))
  expect_equal(ls$chosen$within_inertia, fit$within_inertia)

  # Two basins; the Ward-cut start sits in the worse one.
  expect_identical(ls$n_basins, 2L)
  expect_gt(ls$n_distinct_partitions, ls$n_basins) # micro-variants exist
  expect_false(ls$ward_start$in_chosen_basin)
  expect_equal(ls$ward_start$within_inertia, 0.3603, tolerance = 5e-4)
  expect_lt(ls$ward_start$ari_vs_chosen, 0.5)
  expect_gt(ls$chosen$share_of_starts, 0.6)
  expect_equal(ls$runner_up$within_inertia, 0.3603, tolerance = 5e-4)
  expect_gt(ls$inertia_gap_relative, 0.015)

  # It is a different partition from the one that was served.
  expect_lt(adjusted_rand_index(fit$cluster, fx$served[names(fit$cluster)]), 0.5)
})

test_that("the multi-start partition is stable under entity deletions while k holds", {
  fx <- read_snapshot196()
  full <- phenotype_cluster_coords(fx$x, config = multistart_config())
  aris <- numeric(0)
  ks <- integer(0)
  for (s in 1:40) {
    set.seed(s)
    drop <- sample.int(nrow(fx$x), 20L) # ~1% of the entities
    part <- phenotype_cluster_coords(fx$x[-drop, , drop = FALSE], config = multistart_config())
    ks <- c(ks, part$k)
    aris <- c(aris, adjusted_rand_index(part$cluster, full$cluster[names(part$cluster)]))
  }
  # Given the same k the consolidation no longer flips basin: the legacy single-start
  # procedure fell to ARI ~0.35 in most such trials.
  expect_true(all(aris[ks == 3L] >= 0.9))
  expect_gte(mean(aris[ks == 3L] >= 0.95), 0.9)
  # What multi-start does NOT fix: the k rule itself is nearly tied on this input
  # (W(3)/W(2) = 0.901 vs W(4)/W(3) = 0.914), so a 1% perturbation can occasionally tip
  # it to k = 4. That is rare, and it is why the margin is served.
  expect_gte(mean(ks == 3L), 0.9)
})

test_that("the k margin exposes the near-tie between k = 3 and k = 4", {
  fx <- read_snapshot196()
  fit <- phenotype_cluster_coords(fx$x, config = multistart_config())
  expect_identical(fit$k_selection$k, 3L)
  expect_identical(fit$k_selection$runner_up_k, 4L)
  expect_equal(fit$k_selection$ratio, 0.9012, tolerance = 1e-3)
  expect_equal(fit$k_selection$runner_up_ratio, 0.9140, tolerance = 1e-3)
  expect_equal(fit$k_selection$margin, 0.0128, tolerance = 5e-2)
})

test_that("the k rule equals the FactoMineR 2.13 automatic cut, reimplemented independently", {
  # FactoMineR >= 2.14 changed HCPC's automatic cut, so it cannot serve as the oracle
  # under the locked version. This is the 2.13 `auto.cut.tree` verbatim, on the tree
  # implementation HCPC itself uses.
  testthat::skip_if_not_installed("flashClust")
  fx <- read_snapshot196()
  x <- fx$x[order(fx$x[, 1]), , drop = FALSE]
  n <- nrow(x)
  weight <- rep(1, n)
  eff <- outer(weight, weight, FUN = function(a, b, m) a * b / m / (a + b), m = sum(weight))
  hc <- flashClust::hclust(stats::dist(x)^2 * eff[lower.tri(eff)], method = "ward",
                           members = weight)
  inert_gain <- rev(hc$height)
  intra <- rev(cumsum(rev(inert_gain)))
  quot <- intra[3:25] / intra[2:24]
  wt <- phenotype_ward_tree(fx$x)
  ours <- phenotype_select_k(wt$within, 3L, 25L)
  expect_identical(ours$k, as.integer(which.min(quot) + 2L))
  expect_equal(unname(ours$ratio_curve), quot, tolerance = 1e-10)
})
