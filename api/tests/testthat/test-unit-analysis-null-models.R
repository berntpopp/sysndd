source_api_file("functions/analysis-null-models.R", local = FALSE, envir = globalenv())

test_that("modularity_null_zscore is deterministic, sign-correct, p in (0,1]", {
  set.seed(1)
  g <- igraph::disjoint_union(igraph::make_full_graph(8), igraph::make_full_graph(8))
  g <- igraph::add_edges(g, c(1, 9)) # one bridge between the two cliques
  igraph::V(g)$name <- as.character(seq_len(igraph::vcount(g)))
  igraph::E(g)$w <- 1
  memb <- c(rep(1L, 8), rep(2L, 8))
  r1 <- modularity_null_zscore(g, memb, weights = igraph::E(g)$w, n_null = 50L, seed = 42L)
  r2 <- modularity_null_zscore(g, memb, weights = igraph::E(g)$w, n_null = 50L, seed = 42L)
  expect_equal(r1$z, r2$z) # deterministic
  expect_gt(r1$z, 2) # planted two-clique structure >> degree-matched null
  expect_true(r1$p_empirical > 0 && r1$p_empirical <= 1)
  expect_identical(r1$null_model, "degree_preserving_configuration_fixed_labels")
})

test_that("modularity_null_zscore re-optimizes communities per replicate when given recluster", {
  set.seed(11)
  g <- igraph::disjoint_union(igraph::make_full_graph(10), igraph::make_full_graph(10))
  g <- igraph::add_edges(g, c(1, 11)) # bridge the two cliques into one component
  igraph::V(g)$name <- as.character(seq_len(igraph::vcount(g)))
  igraph::E(g)$w <- 1
  memb <- c(rep(1L, 10), rep(2L, 10))
  recluster <- function(gg, ww) {
    igraph::cluster_leiden(gg, objective_function = "modularity", weights = ww,
                           resolution_parameter = 1, beta = 0.01, n_iterations = -1)$membership
  }
  fixed <- modularity_null_zscore(g, memb, weights = igraph::E(g)$w, n_null = 50L, seed = 7L)
  reopt <- modularity_null_zscore(g, memb, weights = igraph::E(g)$w, n_null = 50L, seed = 7L,
                                  recluster = recluster)
  expect_identical(fixed$null_model, "degree_preserving_configuration_fixed_labels")
  expect_identical(reopt$null_model, "degree_preserving_configuration_reoptimized")
  # The universal, graph-independent property of the Guimera re-optimized null: by
  # re-detecting communities on each rewired graph it recovers the modularity a
  # degree-matched random graph genuinely reaches, so its null mean is strictly
  # HIGHER than the fixed-label null (which strands the observed labels on random
  # edges, giving Q ~ 0). On real sparse graphs this makes the re-optimized z far
  # smaller/less inflated; the z *magnitude* relationship is not universal (on a
  # tiny dense synthetic graph the re-optimized null has lower variance), so we
  # assert the null-mean property, not the z ordering.
  expect_gt(reopt$q_null_mean, fixed$q_null_mean)
  expect_true(is.finite(reopt$z))
  expect_true(is.finite(fixed$z))
})

test_that("silhouette_null_zscore standardizes vs a label-permutation null", {
  set.seed(2)
  coords <- rbind(matrix(rnorm(100, 0), ncol = 2), matrix(rnorm(100, 6), ncol = 2))
  memb <- c(rep(1L, 50), rep(2L, 50))
  r <- silhouette_null_zscore(coords, memb, n_null = 200L, seed = 42L)
  expect_gt(r$z, 3)
  expect_identical(r$null_model, "label_permutation")
  expect_true(r$p_empirical > 0 && r$p_empirical <= 1)
})

test_that("dip_unimodality flags bimodal vs unimodal distance distributions", {
  set.seed(3)
  uni <- dip_unimodality(as.vector(dist(rnorm(200))))
  bi <- dip_unimodality(as.vector(dist(c(rnorm(120, 0), rnorm(120, 12)))))
  # diptest is optional; only assert when it is installed
  if (requireNamespace("diptest", quietly = TRUE)) {
    expect_gt(uni$p_value, 0.1)
    expect_lt(bi$p_value, 0.05)
    expect_identical(bi$interpretation, "multimodal_discrete")
  } else {
    expect_identical(uni$interpretation, "unavailable_diptest_not_installed")
  }
})

test_that("knn_similarity_graph returns a weighted mutual-kNN igraph", {
  set.seed(4)
  coords <- matrix(rnorm(60), ncol = 3)
  rownames(coords) <- paste0("n", seq_len(nrow(coords)))
  g <- knn_similarity_graph(coords, k = 5L, mutual = TRUE)
  expect_s3_class(g, "igraph")
  expect_true(!is.null(igraph::E(g)$weight))
  expect_equal(igraph::vcount(g), nrow(coords))
  expect_true(all(igraph::V(g)$name == rownames(coords)))
})

test_that("modularity_null_zscore degrades gracefully on a trivial graph", {
  g <- igraph::make_empty_graph(n = 3, directed = FALSE)
  igraph::V(g)$name <- as.character(1:3)
  r <- modularity_null_zscore(g, c(1L, 1L, 2L), weights = numeric(0), n_null = 10L)
  expect_true(is.na(r$z))
})
