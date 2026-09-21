# functions/analysis-phenotype-consolidation.R
#
# Application-owned clustering core of the phenotype axis (#679):
#   Ward tree on the MCA coordinates -> data-driven k -> MULTI-START k-means
#   consolidation -> optimisation landscape.
#
# Why this is not delegated to FactoMineR::HCPC:
#   * HCPC consolidates with ONE k-means run started from the Ward-cut centroids.
#     k-means only finds a local optimum, and on real data that start can sit in the
#     basin of the worse one; a one-entity change can flip the released partition.
#   * HCPC's automatic k rule changed between package releases, so delegating k made
#     the released partition depend on a version pin.
# The Ward tree and the k rule below reproduce HCPC (FactoMineR 2.13) exactly; with
# `n_starts = 0` the whole procedure is a drop-in replica of
# `HCPC(nb.clust = -1, kk = Inf, consol = TRUE)`.
#
# Pure functions over a numeric coordinate matrix: base R only, no DB, no FactoMineR.
# `adjusted_rand_index()` (functions/analysis-phenotype-missingness.R) is resolved at
# call time.

# Recorded in the snapshot parameters so a partition can be tied to its procedure.
PHENOTYPE_PROCEDURE_VERSION <- "2.0-multistart"

#' Frozen consolidation configuration.
#'
#' `n_starts` (seeded random starts in addition to the Ward-cut start) is the only
#' env-tunable value: `ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS`, default 100, 0 =
#' legacy single-start. It changes membership, so it is part of the phenotype cache
#' fingerprint.
#' @export
phenotype_consolidation_config <- function() {
  n_starts <- suppressWarnings(as.integer(
    Sys.getenv("ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS", "100")
  ))
  if (is.na(n_starts) || n_starts < 0L) n_starts <- 100L
  list(
    n_starts = n_starts, seed = 42L, iter_max = 100L,
    k_min = 3L, k_max = 25L,
    # Two converged solutions belong to the same basin when ARI >= this. Hartigan-Wong
    # micro-variants of one optimum agree at ~0.94-0.99; distinct basins at ~0.35.
    basin_ari = 0.90
  )
}

#' Everything needed to re-run the clustering procedure, for snapshot provenance.
#'
#' Single source for the applied-params block and the reproducibility bundle, so the
#' two can never describe different procedures.
#' @export
phenotype_procedure_params <- function(config = phenotype_consolidation_config()) {
  list(
    procedure_version = PHENOTYPE_PROCEDURE_VERSION,
    k_rule = "ward_within_inertia_ratio_min", k_min = config$k_min, k_max = config$k_max,
    consolidation_method = "multistart_kmeans",
    consolidation_n_starts = config$n_starts, consolidation_seed = config$seed,
    consolidation_iter_max = config$iter_max, kmeans_algorithm = "Hartigan-Wong",
    factominer_version = tryCatch(as.character(utils::packageVersion("FactoMineR")),
                                  error = function(e) NA_character_),
    r_version = R.version.string
  )
}

# Run `code` without disturbing the caller's RNG stream.
.phenotype_with_preserved_rng <- function(code) {
  genv <- globalenv()
  # base:: on purpose: the live runtime attaches packages that mask exists()/get() with
  # S4 generics rejecting `inherits =` (test-unit-base-exists-get-guard.R).
  had <- base::exists(".Random.seed", envir = genv, inherits = FALSE)
  old <- if (had) base::get(".Random.seed", envir = genv, inherits = FALSE) else NULL
  on.exit({
    if (had) {
      assign(".Random.seed", old, envir = genv)
    } else if (base::exists(".Random.seed", envir = genv, inherits = FALSE)) {
      rm(".Random.seed", envir = genv)
    }
  }, add = TRUE)
  force(code)
}

# Rows that are distinct up to float noise. Identical phenotype profiles share an MCA
# coordinate, but the SVD leaves noise at ~1e-33 on null dimensions; comparing on a
# scale-relative 10-decimal grid keeps such rows from counting as different points.
.phenotype_distinct_rows <- function(x) {
  scale <- max(abs(x))
  if (!is.finite(scale) || scale == 0) scale <- 1
  !duplicated(round(x / scale, 10))
}

#' Ward tree on the coordinates, with the within-cluster inertia of every cut.
#'
#' Rows are ordered by the first coordinate (as HCPC does) so tie handling and the
#' random-start row index space do not depend on the input row order.
#' @return list(X = ordered matrix, tree = hclust, within = W(k)/n for k = 1..n-1)
#' @export
phenotype_ward_tree <- function(coords) {
  x <- as.matrix(coords)
  storage.mode(x) <- "double"
  n <- nrow(x)
  if (is.null(n) || n < 4L) {
    stop("phenotype clustering needs at least 4 rows", call. = FALSE)
  }
  if (anyNA(x)) stop("phenotype clustering coordinates contain NA", call. = FALSE)
  if (sum(.phenotype_distinct_rows(x)) < 2L) {
    stop("phenotype clustering needs at least 2 distinct rows", call. = FALSE)
  }
  if (is.null(rownames(x))) rownames(x) <- as.character(seq_len(n))
  x <- x[order(x[, 1], decreasing = FALSE), , drop = FALSE]
  # Ward on squared distances scaled by 1/(2n): merge heights are inertia gains, so
  # the sum of the (n - k) smallest heights is the within-cluster inertia of the k-cut.
  tree <- stats::hclust(stats::dist(x)^2 / (2 * n), method = "ward.D")
  list(X = x, tree = tree, within = rev(cumsum(tree$height)),
       n_distinct = sum(.phenotype_distinct_rows(x)))
}

#' Data-driven k: the k in k_min..k_max minimising W(k) / W(k-1).
#'
#' Within-inertia below 1e-12 of the total is treated as exactly zero, so float noise
#' on heavily duplicated data (W(k) ~ 1e-33 once every distinct profile is its own
#' cluster) can never produce a spurious minimum; 0/0 ratios are NA and ignored. k is
#' also capped at the number of distinct rows, beyond which k-means has empty clusters.
#' @return list(k, ratio_curve = named numeric keyed by k)
#' @export
phenotype_select_k <- function(within, k_min = 3L, k_max = 25L, n_distinct = Inf) {
  k_max <- as.integer(min(k_max, length(within), n_distinct))
  k_min <- min(as.integer(k_min), k_max)
  if (k_min < 2L) {
    stop("phenotype clustering: no admissible k in the requested range", call. = FALSE)
  }
  within[within < within[[1]] * 1e-12] <- 0
  ks <- k_min:k_max
  ratio <- within[ks] / within[ks - 1L]
  ratio[is.nan(ratio)] <- NA_real_
  best <- which.min(ratio)
  if (length(best) == 0L) {
    stop("phenotype clustering: k rule is undefined on this tree", call. = FALSE)
  }
  list(k = ks[[best]], ratio_curve = stats::setNames(ratio, as.character(ks)))
}

# One Hartigan-Wong run; a list with only `error` when k-means itself errors (e.g. an
# empty cluster from an unlucky random start).
.phenotype_kmeans_run <- function(x, centers, iter_max) {
  km <- tryCatch(
    withCallingHandlers(
      stats::kmeans(x, centers = centers, iter.max = iter_max, algorithm = "Hartigan-Wong"),
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) list(error = conditionMessage(e))
  )
  if (!is.null(km$error)) return(km)
  list(
    cluster = as.integer(km$cluster), centers = km$centers,
    tot_withinss = km$tot.withinss, iter = as.integer(km$iter),
    # ifault 0 = converged; 2 = iter.max reached; 4 = Quick-TRANSfer limit.
    converged = identical(as.integer(km$ifault), 0L)
  )
}

# Index of the released solution: converged before non-converged, then the lowest
# inertia (relative tolerance 1e-10 counts as a tie), then the lowest start index --
# so the Ward-cut start wins exact ties, then seed order.
.phenotype_select_solution <- function(solutions) {
  w <- vapply(solutions, function(s) s$tot_withinss, numeric(1))
  conv <- vapply(solutions, function(s) isTRUE(s$converged), logical(1))
  pool <- if (any(conv)) which(conv) else seq_along(solutions)
  tied <- pool[w[pool] <= min(w[pool]) * (1 + 1e-10)]
  min(tied)
}

#' Consolidate a Ward cut with k-means from the Ward centroids AND seeded random starts.
#'
#' Random start i draws k distinct rows (up to float noise) under `set.seed(seed + i)`.
#' Duplicate phenotype profiles are common, and duplicate centres make kmeans error.
#' @return list(solutions = list of runs, chosen = index into solutions)
#' @export
phenotype_consolidate_multistart <- function(x, ward_cut, k, n_starts = 100L,
                                             seed = 42L, iter_max = 100L) {
  ward_centers <- rowsum(x, ward_cut) / as.vector(table(ward_cut))
  ward_run <- .phenotype_kmeans_run(x, ward_centers, iter_max)
  if (!is.null(ward_run$error)) {
    stop("phenotype clustering: k-means failed from the Ward-cut start: ", ward_run$error,
         call. = FALSE)
  }
  solutions <- list(c(list(start = "ward_cut", start_index = 0L), ward_run))

  distinct_rows <- x[.phenotype_distinct_rows(x), , drop = FALSE]
  if (n_starts > 0L && nrow(distinct_rows) >= k) {
    .phenotype_with_preserved_rng({
      for (i in seq_len(n_starts)) {
        set.seed(seed + i)
        centers <- distinct_rows[sample.int(nrow(distinct_rows), k), , drop = FALSE]
        run <- .phenotype_kmeans_run(x, centers, iter_max)
        if (is.null(run$error)) {
          solutions[[length(solutions) + 1L]] <- c(list(start = "random", start_index = i), run)
        }
      }
    })
  }
  list(solutions = solutions, chosen = .phenotype_select_solution(solutions))
}

#' How contested is the released solution?
#'
#' Groups every start into basins (ARI >= config$basin_ari against a basin's best
#' solution) and reports inertias as W/n. Additive diagnostics only.
#' @export
phenotype_consolidation_landscape <- function(solutions, chosen, n, config) {
  w <- vapply(solutions, function(s) s$tot_withinss, numeric(1))
  conv <- vapply(solutions, function(s) isTRUE(s$converged), logical(1))
  # Rank: the chosen solution first, then the selection order.
  rank_order <- order(seq_along(solutions) != chosen, !conv, w, seq_along(solutions))

  # Collapse exact duplicates first (label-invariant key), then group into basins.
  keys <- vapply(solutions, function(s) {
    paste(match(s$cluster, unique(s$cluster)), collapse = ",")
  }, character(1))
  basin_of <- integer(length(solutions))
  reps <- integer(0)
  key_basin <- list()
  ari_to <- function(i, j) {
    a <- adjusted_rand_index(solutions[[i]]$cluster, solutions[[j]]$cluster)
    if (is.na(a)) 0 else a
  }
  for (i in rank_order) {
    known <- key_basin[[keys[[i]]]]
    if (!is.null(known)) {
      basin_of[[i]] <- known
      next
    }
    hit <- 0L
    for (b in seq_along(reps)) {
      if (ari_to(i, reps[[b]]) >= config$basin_ari) {
        hit <- b
        break
      }
    }
    if (hit == 0L) {
      reps <- c(reps, i)
      hit <- length(reps)
    }
    basin_of[[i]] <- hit
    key_basin[[keys[[i]]]] <- hit
  }

  n_total <- length(solutions)
  basins <- lapply(seq_along(reps), function(b) {
    members <- which(basin_of == b)
    rep_sol <- solutions[[reps[[b]]]]
    list(
      rank = b, best_within_inertia = min(w[members]) / n,
      n_starts = length(members), share_of_starts = length(members) / n_total,
      ari_vs_chosen = if (b == 1L) 1 else ari_to(reps[[b]], chosen),
      sizes = as.integer(sort(table(rep_sol$cluster), decreasing = TRUE))
    )
  })
  runner_up <- if (length(basins) >= 2L) {
    list(within_inertia = basins[[2]]$best_within_inertia,
         share_of_starts = basins[[2]]$share_of_starts,
         ari_vs_chosen = basins[[2]]$ari_vs_chosen)
  } else {
    NULL
  }
  chosen_sol <- solutions[[chosen]]
  list(
    n_starts_total = n_total, n_random_starts = n_total - 1L,
    seed = config$seed, iter_max = config$iter_max, algorithm = "Hartigan-Wong",
    n_converged = sum(conv), basin_ari_threshold = config$basin_ari,
    chosen = list(
      start = chosen_sol$start, start_index = chosen_sol$start_index,
      within_inertia = w[[chosen]] / n,
      n_starts_in_basin = basins[[1]]$n_starts, share_of_starts = basins[[1]]$share_of_starts
    ),
    ward_start = list(
      within_inertia = w[[1]] / n, ari_vs_chosen = if (chosen == 1L) 1 else ari_to(1L, chosen),
      in_chosen_basin = basin_of[[1]] == 1L
    ),
    n_distinct_partitions = length(unique(keys)), n_basins = length(basins),
    basins = utils::head(basins, 5L), runner_up = runner_up,
    inertia_gap_relative = if (is.null(runner_up)) {
      NULL
    } else {
      (runner_up$within_inertia - w[[chosen]] / n) / (w[[chosen]] / n)
    }
  )
}

#' Cluster MCA coordinates: Ward tree -> k -> multi-start consolidation.
#'
#' @param coords numeric matrix (rows = entities; rownames = ids, else 1..n).
#' @param k NULL (or <= 0) selects k by the rule; a positive k imposes it.
#' @return list(cluster = named integer in INPUT row order, labelled 1..k by ascending
#'   first-coordinate centroid; k; k_selected_by; ratio_curve; centers;
#'   within_inertia (W/n); converged; landscape; config)
#' @export
phenotype_cluster_coords <- function(coords, k = NULL, config = phenotype_consolidation_config()) {
  wt <- phenotype_ward_tree(coords)
  n <- nrow(wt$X)
  input_ids <- rownames(as.matrix(coords))
  if (is.null(input_ids)) input_ids <- as.character(seq_len(n))

  rule <- phenotype_select_k(wt$within, config$k_min, config$k_max, wt$n_distinct)
  imposed <- !is.null(k) && is.finite(k) && k > 0
  k_use <- if (imposed) as.integer(k) else rule$k
  if (k_use < 2L || k_use > min(n - 1L, wt$n_distinct)) {
    stop("phenotype clustering: k must be between 2 and the number of distinct rows",
         call. = FALSE)
  }

  ward_cut <- stats::cutree(wt$tree, k = k_use)
  ms <- phenotype_consolidate_multistart(
    wt$X, ward_cut, k_use,
    n_starts = config$n_starts, seed = config$seed, iter_max = config$iter_max
  )
  best <- ms$solutions[[ms$chosen]]

  # Stable labels: number clusters by ascending first-coordinate centroid.
  centroid_order <- order(best$centers[, 1], decreasing = FALSE)
  relabel <- order(centroid_order)
  cluster <- stats::setNames(relabel[best$cluster], rownames(wt$X))[input_ids]
  centers <- best$centers[centroid_order, , drop = FALSE]
  rownames(centers) <- as.character(seq_len(k_use))

  list(
    cluster = cluster, k = k_use,
    k_selected_by = if (imposed) "imposed" else "ward_within_inertia_ratio_min",
    ratio_curve = rule$ratio_curve, centers = centers,
    within_inertia = best$tot_withinss / n, converged = isTRUE(best$converged),
    landscape = phenotype_consolidation_landscape(ms$solutions, ms$chosen, n, config),
    config = config
  )
}
