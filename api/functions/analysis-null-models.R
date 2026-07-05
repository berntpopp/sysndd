# functions/analysis-null-models.R
#
# Shared null-calibrated separation statistics for cluster validation.
# Worker/heavy-path only — never invoked on a public request. Deterministic
# (every null is seeded).
#
# The two analysis axes report a common, unit-free footing so the served
# "function modular / phenotype continuum" contrast is like-for-like instead of
# silhouette-vs-modularity apples-to-oranges (#511):
#   - graph  -> modularity z-score vs a degree-preserving configuration-model null
#   - points -> silhouette  z-score vs a label-permutation null
# plus a representation-agnostic dip test of unimodality (continuum vs discrete),
# and a kNN-graph builder so the SAME index (modularity z) is available on the
# phenotype MCA embedding as well as on the functional graph.
#
# Refs: Guimera, Sales-Pardo & Amaral 2004 (modularity of random graphs);
# Miyauchi & Kawase 2016 (Z-modularity); Newman & Girvan 2004 (modularity);
# Traag et al. 2019 (Leiden); Rousseeuw 1987 (silhouette); Hartigan & Hartigan
# 1985 (dip test); von Luxburg 2007 (mutual-kNN similarity graphs).

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

#' Degree-preserving configuration-model modularity z-score.
#'
#' Rewire keeps the (unweighted) degree sequence; the observed weight multiset is
#' permuted onto the null topology and each replicate is re-restricted to its
#' largest connected component so Q_obs and Q_null share a connected substrate
#' (a disconnected fragment is a trivial "perfect community" that inflates Q). The
#' OBSERVED graph is likewise restricted to its largest component here, so the
#' caller may pass a graph with disconnected fragments (e.g. a mutual-kNN graph)
#' and still get a like-for-like q_obs; passing an already-connected component is
#' a no-op.
#'
#' Two null flavours, selected by `recluster`:
#'   - `recluster = <fn(graph, weights) -> membership>` (functional axis): each
#'     null replicate RE-DETECTS communities with the same algorithm and its
#'     re-optimized Q is the null statistic. This is the Guimera/Sales-Pardo/
#'     Amaral (2004) configuration-model benchmark — even degree-matched random
#'     graphs reach Q ~ 0.3-0.5 under re-optimization, so this is what makes the
#'     z a real significance statement rather than "is Q distinguishable from 0".
#'   - `recluster = NULL` (default; phenotype shared-modularity axis): the given
#'     membership is an EXTERNAL node attribute (the MCA/HCPC partition) that the
#'     graph cannot re-derive, so the null holds those labels fixed and asks
#'     whether that labelling is more assortative than a degree-preserving
#'     rewiring — an attribute-assortativity significance test.
#'
#' @param graph igraph object; restricted to its largest component internally.
#' @param membership integer/factor membership aligned to V(graph).
#' @param weights numeric edge weights aligned to E(graph).
#' @param n_null number of degree-preserving rewirings (default 200; 1000 ideal).
#' @param seed base RNG seed (replicate i uses seed + i).
#' @param resolution modularity resolution parameter (must match observed).
#' @param recluster optional `function(graph, weights)` returning a membership
#'   vector; when supplied, each null replicate re-detects communities (Guimera
#'   re-optimized null). When NULL the observed labels are held fixed.
#' @return list(q_obs, q_null_mean, q_null_sd, z, p_empirical, n_null, null_model)
#' @export
modularity_null_zscore <- function(graph, membership, weights,
                                   n_null = 200L, seed = 42L, resolution = 1.0,
                                   recluster = NULL) {
  n_null <- as.integer(n_null)
  null_model <- if (is.function(recluster)) {
    "degree_preserving_configuration_reoptimized"
  } else {
    "degree_preserving_configuration_fixed_labels"
  }
  # Name-key the observed membership and carry the weights on the graph so both
  # survive the largest-component restriction (and the per-replicate rewiring).
  memb_by_name <- stats::setNames(as.integer(factor(membership)), igraph::V(graph)$name)
  igraph::E(graph)$.null_weight <- weights
  g  <- igraph::largest_component(graph)                     # shared substrate; no-op if connected
  gw <- igraph::E(g)$.null_weight
  obs_memb <- as.integer(factor(memb_by_name[igraph::V(g)$name]))
  q_obs <- igraph::modularity(g, obs_memb, weights = gw, resolution = resolution)
  ecount <- igraph::ecount(g)
  if (ecount < 2L || n_null < 2L) {
    return(list(q_obs = q_obs, q_null_mean = NA_real_, q_null_sd = NA_real_,
                z = NA_real_, p_empirical = NA_real_, n_null = n_null,
                null_model = null_model))
  }
  niter <- max(100L, 10L * ecount)
  q_null <- vapply(seq_len(n_null), function(i) {
    set.seed(seed + i)
    h <- igraph::rewire(g, with = igraph::keeping_degseq(loops = FALSE, niter = niter))
    igraph::E(h)$.null_weight <- sample(gw)                 # permute weight multiset onto null topology
    h <- igraph::largest_component(h)
    if (igraph::ecount(h) < 1L) return(NA_real_)
    hw <- igraph::E(h)$.null_weight
    null_memb <- if (is.function(recluster)) {
      as.integer(factor(recluster(h, hw)))                 # re-optimize communities on the null (Guimera)
    } else {
      as.integer(factor(memb_by_name[igraph::V(h)$name]))  # external attribute held fixed on kept nodes
    }
    igraph::modularity(h, null_memb, weights = hw, resolution = resolution)
  }, numeric(1))
  q_null <- q_null[is.finite(q_null)]
  sdv <- if (length(q_null) > 1L) stats::sd(q_null) else NA_real_
  list(
    q_obs = q_obs,
    q_null_mean = if (length(q_null)) mean(q_null) else NA_real_,
    q_null_sd = sdv,
    z = if (isTRUE(is.finite(sdv) && sdv > 0)) (q_obs - mean(q_null)) / sdv else NA_real_,
    p_empirical = (1 + sum(q_null >= q_obs)) / (length(q_null) + 1),
    n_null = length(q_null),
    null_model = null_model
  )
}

#' Label-permutation silhouette z-score (preserves cluster sizes).
#'
#' @param coords numeric matrix (rows = objects).
#' @param membership integer/factor membership aligned to rows of coords.
#' @param n_null number of label permutations (default 1000; cheap).
#' @param seed base RNG seed (replicate i uses seed + i).
#' @return list(sil_obs, sil_null_mean, sil_null_sd, z, p_empirical, n_null, null_model)
#' @export
silhouette_null_zscore <- function(coords, membership, n_null = 1000L, seed = 42L) {
  n_null <- as.integer(n_null)
  memb <- as.integer(factor(membership))
  if (length(unique(memb)) < 2L || nrow(coords) < 3L) {
    return(list(sil_obs = NA_real_, sil_null_mean = NA_real_, sil_null_sd = NA_real_,
                z = NA_real_, p_empirical = NA_real_, n_null = n_null,
                null_model = "label_permutation"))
  }
  d <- stats::dist(coords)
  sil_obs <- mean(cluster::silhouette(memb, d)[, "sil_width"])
  sil_null <- vapply(seq_len(n_null), function(i) {
    set.seed(seed + i)
    mean(cluster::silhouette(sample(memb), d)[, "sil_width"])
  }, numeric(1))
  sdv <- stats::sd(sil_null)
  list(
    sil_obs = sil_obs, sil_null_mean = mean(sil_null), sil_null_sd = sdv,
    z = if (isTRUE(is.finite(sdv) && sdv > 0)) (sil_obs - mean(sil_null)) / sdv else NA_real_,
    p_empirical = (1 + sum(sil_null >= sil_obs)) / (n_null + 1),
    n_null = n_null, null_model = "label_permutation"
  )
}

#' Dip test of unimodality on a pairwise-distance vector.
#'
#' Gracefully degrades when the optional `diptest` package is not installed so a
#' missing dependency never breaks a refresh — the primary z-score footing does
#' not depend on it.
#'
#' @param dist_vector numeric vector of pairwise distances (or a dist object).
#' @return list(dip_statistic, p_value, interpretation)
#' @export
dip_unimodality <- function(dist_vector) {
  x <- as.numeric(dist_vector)
  x <- x[is.finite(x)]
  if (!requireNamespace("diptest", quietly = TRUE)) {
    return(list(dip_statistic = NA_real_, p_value = NA_real_,
                interpretation = "unavailable_diptest_not_installed"))
  }
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
#'
#' Used to put the phenotype MCA embedding onto a graph so the same modularity-z
#' index can be reported on both axes (#511, Strategy 1). Local bandwidth = the
#' distance to each node's k-th neighbour (self-tuning; von Luxburg 2007).
#'
#' @param coords numeric matrix (rows = objects; rownames become node names).
#' @param k neighbours per node (default 15).
#' @param mutual keep an edge only when both endpoints list each other (default TRUE).
#' @return weighted undirected igraph.
#' @export
knn_similarity_graph <- function(coords, k = 15L, mutual = TRUE) {
  n <- nrow(coords)
  k <- min(as.integer(k), n - 1L)
  if (n < 3L || k < 1L) {
    g <- igraph::make_empty_graph(n = n, directed = FALSE)
    igraph::V(g)$name <- rownames(coords) %||% as.character(seq_len(n))
    return(g)
  }
  dm <- as.matrix(stats::dist(coords))
  sigma <- apply(dm, 1, function(r) sort(r)[k + 1L])       # local bandwidth = dist to k-th nn
  sigma[!is.finite(sigma) | sigma == 0] <- .Machine$double.eps
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
