# Pure-module tests for the application-owned phenotype clustering core (#679):
# Ward tree -> k rule -> multi-start k-means consolidation -> landscape.
# Base R only, so these run on the host without FactoMineR.

source_api_file("functions/analysis-phenotype-missingness.R", local = FALSE, envir = globalenv())
source_api_file("functions/analysis-phenotype-consolidation.R", local = FALSE, envir = globalenv())

# Pin the start count inside each test that relies on the default, so an ambient
# override cannot change what is asserted and nothing leaks into later test files.
pin_default_starts <- function(env = parent.frame()) {
  withr::local_envvar(ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS = "100", .local_envir = env)
}

three_blobs <- function(n_per = 40L, seed = 1L) {
  set.seed(seed)
  centres <- rbind(c(-6, 0), c(0, 5), c(6, 0))
  x <- do.call(rbind, lapply(1:3, function(i) {
    cbind(stats::rnorm(n_per, centres[i, 1], 0.5), stats::rnorm(n_per, centres[i, 2], 0.5))
  }))
  # Shuffle so the input row order is unrelated to the first coordinate.
  x <- x[sample.int(nrow(x)), , drop = FALSE]
  rownames(x) <- paste0("e", seq_len(nrow(x)))
  colnames(x) <- c("Dim.1", "Dim.2")
  x
}

test_that("phenotype_select_k minimises W(k)/W(k-1) over the allowed range", {
  within <- c(10, 6, 3, 2.7, 2.5, 2.4)
  sel <- phenotype_select_k(within, k_min = 3L, k_max = 5L)
  expect_identical(sel$k, 3L)
  expect_equal(unname(sel$ratio_curve), c(3 / 6, 2.7 / 3, 2.5 / 2.7))
  expect_identical(names(sel$ratio_curve), c("3", "4", "5"))
  # k_max beyond the tree is capped at length(within) (= n - 1).
  capped <- phenotype_select_k(within, k_min = 3L, k_max = 25L)
  expect_identical(names(capped$ratio_curve), as.character(3:6))
})

test_that("phenotype_ward_tree within-inertia equals the direct computation", {
  x <- three_blobs()
  wt <- phenotype_ward_tree(x)
  expect_identical(nrow(wt$X), nrow(x))
  expect_false(is.unsorted(wt$X[, 1]))
  # W(1)/n is the total inertia; W(3)/n is the within inertia of the 3-cut.
  total <- sum(sweep(x, 2, colMeans(x))^2) / nrow(x)
  expect_equal(wt$within[[1]], total, tolerance = 1e-10)
  cut3 <- stats::cutree(wt$tree, k = 3L)
  w3 <- sum(vapply(split(seq_len(nrow(wt$X)), cut3), function(idx) {
    blk <- wt$X[idx, , drop = FALSE]
    sum(sweep(blk, 2, colMeans(blk))^2)
  }, numeric(1))) / nrow(x)
  expect_equal(wt$within[[3]], w3, tolerance = 1e-10)
})

test_that("phenotype_cluster_coords recovers separated blobs deterministically", {
  pin_default_starts()
  x <- three_blobs()
  fit <- phenotype_cluster_coords(x)
  expect_identical(fit$k, 3L)
  expect_identical(fit$k_selected_by, "ward_within_inertia_ratio_min")
  expect_identical(names(fit$cluster), rownames(x)) # input row order preserved
  expect_identical(as.integer(table(fit$cluster)), c(40L, 40L, 40L))
  # labels ordered by ascending first-coordinate centroid
  expect_false(is.unsorted(fit$centers[, 1]))
  centroid_dim1 <- tapply(x[, 1], fit$cluster, mean)
  expect_false(is.unsorted(as.numeric(centroid_dim1)))
  expect_true(isTRUE(fit$converged))
  expect_identical(fit, phenotype_cluster_coords(x))
})

test_that("clustering does not depend on or disturb the caller's RNG stream", {
  pin_default_starts()
  x <- three_blobs()
  set.seed(99)
  a <- phenotype_cluster_coords(x)
  after_a <- stats::runif(1)
  set.seed(99)
  expected_after <- {
    stats::runif(0)
    stats::runif(1)
  }
  set.seed(5)
  b <- phenotype_cluster_coords(x)
  expect_identical(a$cluster, b$cluster)
  expect_identical(after_a, expected_after)
})

test_that("duplicate rows do not break the random starts", {
  pin_default_starts()
  x <- three_blobs(n_per = 15L)
  dup <- rbind(x, x)
  rownames(dup) <- paste0("d", seq_len(nrow(dup)))
  fit <- phenotype_cluster_coords(dup)
  expect_identical(fit$k, 3L)
  expect_identical(as.integer(table(fit$cluster)), c(30L, 30L, 30L))
  expect_gt(fit$landscape$n_random_starts, 0L)
})

test_that("numerically-zero within-inertia cannot drive the k rule", {
  # Float noise below the tolerance is zero: W(3) = 0 wins, and the 0/0 ratios after it
  # are undefined rather than a spurious minimum.
  sel <- phenotype_select_k(c(1, 0.4, 3e-33, 1e-33, 0), k_min = 3L, k_max = 5L)
  expect_identical(sel$k, 3L)
  expect_equal(unname(sel$ratio_curve[["3"]]), 0)
  expect_true(all(is.na(sel$ratio_curve[c("4", "5")])))
  # k can never exceed the number of distinct rows
  capped <- phenotype_select_k(c(10, 6, 3, 2.7, 2.5, 2.4), k_min = 3L, k_max = 6L, n_distinct = 4L)
  expect_identical(names(capped$ratio_curve), c("3", "4"))
})

test_that("three distinct profiles, heavily duplicated, cluster into exactly three", {
  set.seed(3)
  p <- rbind(c(-1, 0.2), c(1, 0.1), c(0.1, -2))
  x <- p[c(rep(1, 28), rep(2, 29), rep(3, 5)), ] + stats::rnorm(124, 0, 1e-16)
  rownames(x) <- as.character(seq_len(nrow(x)))
  fit <- phenotype_cluster_coords(x)
  expect_identical(fit$k, 3L)
  expect_identical(sort(as.integer(table(fit$cluster))), c(5L, 28L, 29L))
})

test_that("two profiles plus SVD noise on null dimensions give two clusters, not seven", {
  # The shape MCA returns for two crisp phenotype blocks: +/-1 on the first dimension
  # and ~1e-33 noise elsewhere. The legacy procedure split this noise into 7 clusters.
  set.seed(4)
  x <- cbind(rep(c(1, -1), each = 60L), stats::rnorm(120, 0, 1e-33), stats::rnorm(120, 0, 1e-64))
  rownames(x) <- as.character(seq_len(nrow(x)))
  fit <- phenotype_cluster_coords(x)
  expect_identical(fit$k, 2L)
  expect_identical(as.integer(table(fit$cluster)), c(60L, 60L))
})

test_that("an imposed k overrides the rule and is reported as imposed", {
  x <- three_blobs()
  fit <- phenotype_cluster_coords(x, k = 2L)
  expect_identical(fit$k, 2L)
  expect_identical(fit$k_selected_by, "imposed")
  expect_identical(length(unique(fit$cluster)), 2L)
  # the rule's own curve is still reported
  expect_true("3" %in% names(fit$ratio_curve))
})

test_that("n_starts = 0 runs the Ward-cut start only", {
  x <- three_blobs()
  cfg <- phenotype_consolidation_config()
  cfg$n_starts <- 0L
  fit <- phenotype_cluster_coords(x, config = cfg)
  expect_identical(fit$landscape$n_starts_total, 1L)
  expect_identical(fit$landscape$chosen$start, "ward_cut")
  expect_null(fit$landscape$runner_up)
})

test_that("too-small or degenerate input fails with a clear message", {
  expect_error(phenotype_cluster_coords(matrix(1:6, 3, 2)), "at least 4")
  expect_error(phenotype_cluster_coords(matrix(1, 10, 2)), "distinct")
})

test_that("selection prefers converged, then lowest inertia, then lowest start index", {
  sol <- function(w, conv) list(tot_withinss = w, converged = conv)
  # a non-converged lower-inertia run loses to a converged one
  expect_identical(.phenotype_select_solution(list(sol(5, TRUE), sol(4, FALSE), sol(6, TRUE))), 1L)
  # exact and within-tolerance ties go to the lowest index (the Ward-cut start)
  expect_identical(.phenotype_select_solution(list(sol(5, TRUE), sol(5, TRUE))), 1L)
  expect_identical(.phenotype_select_solution(list(sol(5, TRUE), sol(5 * (1 - 1e-12), TRUE))), 1L)
  # a real improvement wins regardless of index
  expect_identical(.phenotype_select_solution(list(sol(5, TRUE), sol(4.9, TRUE))), 2L)
  # nothing converged -> still pick the lowest inertia
  expect_identical(.phenotype_select_solution(list(sol(5, FALSE), sol(4, FALSE))), 2L)
})

test_that("the landscape separates basins from micro-variants", {
  a <- rep(1:2, each = 50L)
  a_micro <- a
  a_micro[50] <- 2L # one boundary point moved: same basin
  b <- rep(1:2, times = 50L) # unrelated partition: a different basin
  mk <- function(cl, w, start, idx) {
    list(start = start, start_index = idx, cluster = cl, tot_withinss = w, converged = TRUE)
  }
  solutions <- list(mk(b, 12, "ward_cut", 0L), mk(a, 10, "random", 1L),
                    mk(a_micro, 10.01, "random", 2L), mk(a, 10, "random", 3L))
  cfg <- phenotype_consolidation_config()
  ls <- phenotype_consolidation_landscape(solutions, chosen = 2L, n = 100L, config = cfg)
  expect_identical(ls$n_starts_total, 4L)
  expect_identical(ls$n_distinct_partitions, 3L)
  expect_identical(ls$n_basins, 2L)
  expect_identical(ls$chosen$n_starts_in_basin, 3L)
  expect_equal(ls$chosen$share_of_starts, 0.75)
  expect_false(ls$ward_start$in_chosen_basin)
  expect_equal(ls$runner_up$within_inertia, 12 / 100)
  expect_equal(ls$inertia_gap_relative, (12 - 10) / 10)
  expect_identical(ls$basins[[1]]$rank, 1L)
  expect_equal(ls$basins[[1]]$ari_vs_chosen, 1)
})

test_that("a basin is summarised by its representative, never by a non-converged member", {
  a <- rep(1:2, each = 50L)
  a_micro <- a
  a_micro[50] <- 2L
  b <- rep(1:2, times = 50L)
  mk <- function(cl, w, conv, idx) {
    list(start = "random", start_index = idx, cluster = cl, tot_withinss = w, converged = conv)
  }
  # a_micro has LOWER inertia but did not converge: it may not undercut the chosen one,
  # and a non-converged runner-up may not produce a negative gap.
  solutions <- list(mk(a, 10, TRUE, 0L), mk(a_micro, 9, FALSE, 1L), mk(b, 9.5, FALSE, 2L))
  ls <- phenotype_consolidation_landscape(solutions, chosen = 1L, n = 100L,
                                          config = phenotype_consolidation_config())
  expect_equal(ls$basins[[1]]$best_within_inertia, ls$chosen$within_inertia)
  expect_identical(ls$basins[[1]]$n_starts, 2L)
  expect_false(ls$runner_up$converged)
  expect_null(ls$inertia_gap_relative) # no gap is claimed against a non-converged run
})

test_that("the k decision reports how contested it was", {
  sel <- phenotype_select_k(c(10, 6, 3, 2.7, 2.5, 2.4), k_min = 3L, k_max = 5L)
  expect_identical(sel$runner_up_k, 4L)
  expect_equal(sel$margin, 2.7 / 3 - 3 / 6)
  # a single admissible k has no runner-up
  one <- phenotype_select_k(c(10, 6, 3), k_min = 3L, k_max = 3L)
  expect_true(is.na(one$runner_up_k))
  expect_true(is.na(one$margin))
})

test_that("duplicated row names are rejected instead of silently mislabelled", {
  x <- three_blobs()
  rownames(x)[5] <- rownames(x)[1]
  expect_error(phenotype_cluster_coords(x), "unique")
})

test_that("phenotype_procedure_params records everything needed to re-run the procedure", {
  pin_default_starts()
  pp <- phenotype_procedure_params()
  expect_identical(pp$procedure_version, PHENOTYPE_PROCEDURE_VERSION)
  expect_identical(pp$k_rule, "ward_within_inertia_ratio_min")
  expect_identical(pp$k_min, 3L)
  expect_identical(pp$k_max, 25L)
  expect_identical(pp$consolidation_method, "multistart_kmeans")
  expect_identical(pp$consolidation_n_starts, 100L)
  expect_identical(pp$consolidation_seed, 42L)
  expect_identical(pp$consolidation_iter_max, 100L)
  expect_identical(pp$kmeans_algorithm, "Hartigan-Wong")
  expect_identical(pp$r_version, R.version.string)
  expect_true("factominer_version" %in% names(pp)) # NA on a host without FactoMineR
  withr::with_envvar(c(ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS = "0"), {
    expect_identical(phenotype_procedure_params()$consolidation_n_starts, 0L)
  })
})
