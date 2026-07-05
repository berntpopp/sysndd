# functions/analysis-cluster-validation.R
#
# Membership-only cluster validation. Worker/heavy-path only — never on a public
# request. Deterministic, hand-rolled (no `fpc`).
#
# Resampling scheme: SUBSAMPLING WITHOUT REPLACEMENT (Hennig clusterboot
# "subset" method), not a with-replacement bootstrap. A with-replacement
# bootstrap is ill-defined for a graph (igraph has no duplicate nodes) and for
# the MCA row matrix (duplicate rows distort inertia). Each resample draws a
# fraction `subsample_fraction` (default 0.8) of nodes/entities without
# replacement, reclusters, and takes the per-reference-cluster max-Jaccard
# recovery. `n_resamples_effective` records resamples that yielded >=1 cluster.
#
# Modularity scope: reported on the FULL optimized Leiden partition (the
# quantity the objective maximizes), labeled modularity_scope =
# "full_partition". The per-cluster bootstrap-Jaccard is separately scoped to the
# stored visible top-level clusters (partition_scope = "visible_top_level").
#
# Hennig interpretation bands (metric documentation, not gates): mean Jaccard
# <=0.5 "dissolved"; 0.6-0.75 "pattern but membership doubtful"; >=0.75
# "valid/stable"; >=0.85 "highly stable".

# Mean over the non-NA recoveries; NA_real_ when a cluster was never testable in
# any resample (avoids NaN from mean(<all-NA>, na.rm = TRUE)).
jaccard_mean_non_na <- function(v) {
  v <- v[!is.na(v)]
  if (length(v)) mean(v) else NA_real_
}

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
    vals <- vapply(bootstrap_clusters, function(bc) jac(ref, bc), numeric(1))
    vals <- vals[!is.na(vals)]
    # A reference cluster with no members present in this subsample yields an
    # all-NA recovery vector; report NA_real_ (not max(numeric(0)) == -Inf, which
    # would poison the per-cluster mean) so this resample is simply not counted
    # for that cluster.
    if (length(vals) == 0) return(NA_real_)
    max(vals)
  }, numeric(1))
}

# One weighted+converged Leiden membership (shared by reference + each resample).
.leiden_membership <- function(g, resolution, seed) {
  set.seed(seed)
  igraph::cluster_leiden(
    g, objective_function = "modularity",
    weights = igraph::E(g)$combined_score,
    resolution_parameter = resolution, beta = 0.01, n_iterations = -1
  )$membership
}

validate_functional_clusters <- function(hgnc_list, score_threshold = 400, resolution = 1.0,
                                          n_resamples = 100, min_size = 10,
                                          subsample_fraction = 0.8, seed = 42) {
  subgraph  <- build_string_subgraph(hgnc_list, score_threshold)     # shared refactored helper
  all_nodes <- igraph::V(subgraph)$name
  weight_channel <- attr(subgraph, "weight_channel")
  if (is.null(weight_channel)) weight_channel <- "combined_score"

  # FULL optimized Leiden partition = the quantity the objective maximizes; report ITS modularity.
  full_membership <- .leiden_membership(subgraph, resolution, seed)
  modularity <- igraph::modularity(subgraph, full_membership,
                                   weights = igraph::E(subgraph)$combined_score)

  # #510 channel sensitivity: how much does Q change if text-mining is included?
  # Off by default (an extra full STRINGdb combined build); flip the env to report it.
  modularity_combined <- NA_real_
  if (identical(weight_channel, "experimental_database") &&
      identical(tolower(Sys.getenv("ANALYSIS_REPORT_COMBINED_SENSITIVITY", "false")), "true")) {
    modularity_combined <- tryCatch({
      cs <- build_string_subgraph(hgnc_list, score_threshold, channel = "combined")
      cs_lcc <- igraph::largest_component(cs)
      igraph::modularity(cs_lcc, .leiden_membership(cs_lcc, resolution, seed),
                         weights = igraph::E(cs_lcc)$combined_score)
    }, error = function(e) NA_real_)
  }

  # --- #510: giant-component structure + degree-preserving modularity null ---
  # A raw Q is not a significance statement (Leiden maximizes exactly Q, and even
  # degree-matched random graphs reach Q ~ 0.3-0.5; Guimera et al. 2004). Report a
  # modularity z-score vs a degree-preserving configuration-model null, computed on
  # the largest connected component so disconnected fragments (each a trivial
  # "perfect community") do not inflate the benchmark. Disconnected-component counts
  # are recorded so a "modular only because it shattered" signature is visible.
  n_null <- as.integer(Sys.getenv("ANALYSIS_MODULARITY_NULL_N", "200"))
  comp <- igraph::components(subgraph)
  lcc  <- igraph::largest_component(subgraph)
  giant_component <- list(
    n_nodes = igraph::vcount(lcc), n_edges = igraph::ecount(lcc),
    n_isolates = sum(igraph::degree(subgraph) == 0L),
    n_components = comp$no,
    node_retention = igraph::vcount(lcc) / max(1L, igraph::vcount(subgraph)),
    edge_retention = igraph::ecount(lcc) / max(1L, igraph::ecount(subgraph))
  )
  lcc_membership <- .leiden_membership(lcc, resolution, seed)
  mod_null <- modularity_null_zscore(
    lcc, lcc_membership, weights = igraph::E(lcc)$combined_score,
    n_null = n_null, seed = seed, resolution = resolution
  )
  # Representation-agnostic continuum-vs-modular signal: dip test of unimodality on
  # the distribution of pairwise shortest-path (hop) distances over an LCC sample.
  set.seed(seed)
  lcc_nodes <- igraph::V(lcc)$name
  dip_sample <- if (length(lcc_nodes) > 500L) sample(lcc_nodes, 500L) else lcc_nodes
  spd <- igraph::distances(lcc, v = dip_sample, to = dip_sample, weights = NA)
  spd <- spd[upper.tri(spd)]
  dip <- dip_unimodality(spd[is.finite(spd)])

  # VISIBLE top-level reference = full partition restricted to clusters >= min_size (for Jaccard).
  # Key each reference cluster by its ORIGINAL split position (1..N), matching
  # gen_string_clust_obj's row_number()-derived `cluster`, so per-cluster metrics
  # join onto the correct stored clusters even when min_size drops earlier
  # clusters (which leaves gaps in the numbering — seq_along() would desync them).
  parts       <- split(all_nodes, full_membership)
  visible_idx <- which(vapply(parts, length, integer(1)) >= min_size)
  ref_members <- stats::setNames(parts[visible_idx], as.character(visible_idx))
  n_clusters  <- length(ref_members)
  n_dropped   <- length(parts) - n_clusters

  # Subsample WITHOUT replacement (Hennig clusterboot "subset" method) — well-defined estimand,
  # no graph-duplicate-node problem. f = subsample_fraction of the node set per resample.
  m <- max(2L, floor(subsample_fraction * length(all_nodes)))
  per_cluster_acc <- stats::setNames(rep(list(numeric(0)), n_clusters), names(ref_members))
  n_eff <- 0L
  for (b in seq_len(n_resamples)) {
    set.seed(seed + b)
    sampled <- sample(all_nodes, m, replace = FALSE)
    sub_b   <- igraph::induced_subgraph(subgraph, which(all_nodes %in% sampled))
    boot_clusters <- split(igraph::V(sub_b)$name, .leiden_membership(sub_b, resolution, seed + b))
    if (!length(boot_clusters)) next
    n_eff <- n_eff + 1L
    jac <- cluster_max_jaccard(ref_members, boot_clusters, sampled)
    for (k in names(ref_members)) per_cluster_acc[[k]] <- c(per_cluster_acc[[k]], jac[[k]])
  }

  per_cluster <- dplyr::tibble(
    cluster_id = names(ref_members),
    # Mean/count over resamples where the cluster was actually testable (had >=1
    # reference member present in the subsample). NA recoveries are excluded so
    # jaccard_n_resamples reflects effective coverage, not the raw resample count.
    jaccard_mean = vapply(per_cluster_acc, jaccard_mean_non_na, numeric(1)),
    jaccard_n_resamples = vapply(per_cluster_acc, function(v) sum(!is.na(v)), integer(1)),
    bootstrap_seed = seed
  )
  list(
    per_cluster = per_cluster,
    partition = list(
      validation_schema_version = "2.0",
      algorithm = "leiden", weighted = TRUE, n_iterations = -1L,
      resolution_parameter = resolution,
      modularity = modularity, modularity_scope = "full_partition",
      weight_channel = weight_channel,
      modularity_combined_score = modularity_combined,
      modularity_z = mod_null$z, modularity_p_empirical = mod_null$p_empirical,
      modularity_null_mean = mod_null$q_null_mean, modularity_null_sd = mod_null$q_null_sd,
      null_model = mod_null$null_model, n_null = mod_null$n_null,
      giant_component = giant_component,
      dip_statistic = dip$dip_statistic, dip_p = dip$p_value,
      dip_interpretation = dip$interpretation, dip_scope = "shortest_path_sample",
      separation_z = mod_null$z,
      n_clusters = n_clusters, n_dropped_below_min_size = n_dropped,
      partition_scope = "visible_top_level",
      resampling_scheme = "subsample", subsample_fraction = subsample_fraction,
      n_resamples = n_resamples, n_resamples_effective = n_eff
    )
  )
}

# Self-contained: recomputes the reference partition AND the MCA coords from wide_phenotypes_df
# (deterministic, set.seed(42)) — so gen_mca_clust_obj's return shape is never touched.
validate_phenotype_clusters <- function(wide_phenotypes_df, quali_sup_var = 1:1,
                                         quanti_sup_var = 2:4, min_size = 10,
                                         n_resamples = 100, subsample_fraction = 0.8, seed = 42) {
  ref <- gen_mca_clust_obj(wide_phenotypes_df, min_size = min_size,
                           quali_sup_var = quali_sup_var, quanti_sup_var = quanti_sup_var,
                           cutpoint = -1)                                   # tibble (Task 2)
  ref_members <- stats::setNames(
    lapply(ref$identifiers, function(d) as.character(d$entity_id)),
    as.character(ref$cluster)
  )
  n_clusters <- length(ref_members)
  # The actual HCPC nb.clust (data-driven k, before min_size dropping). Equals
  # n_clusters when nothing is dropped (the production case). The curve anchors here.
  data_driven_k <- attr(ref, "data_driven_k")
  if (is.null(data_driven_k)) data_driven_k <- n_clusters

  # Entity IDs may live in an `entity_id` column or (the production matrix from
  # generate_phenotype_cluster_input()) in the rownames — support both so the
  # validator keys entities the same way gen_mca_clust_obj does.
  entity_ids <- if (!is.null(wide_phenotypes_df$entity_id)) {
    as.character(wide_phenotypes_df$entity_id)
  } else {
    as.character(rownames(wide_phenotypes_df))
  }

  set.seed(42)
  mca <- FactoMineR::MCA(wide_phenotypes_df, ncp = 8, quali.sup = quali_sup_var,
                         quanti.sup = quanti_sup_var, graph = FALSE)
  coords <- mca$ind$coord
  rownames(coords) <- entity_ids

  # #508 provenance: the active/excluded HPO term set (attached by
  # generate_phenotype_cluster_input) + the Greenacre 1/Q ncp diagnostic. ncp stays
  # at the empirically-stable denoising value of 8 for the actual clustering; the
  # 1/Q recommendation and adjusted inertia are reported for transparency.
  mca_prov <- attr(wide_phenotypes_df, "mca_provenance")
  q_active <- ncol(wide_phenotypes_df) - length(quali_sup_var) - length(quanti_sup_var)
  ncp_diag <- if (exists("phenotype_mca_ncp", mode = "function")) {
    tryCatch(phenotype_mca_ncp(mca$eig[, "eigenvalue"], q_active),
             error = function(e) NULL)
  } else {
    NULL
  }

  ent_to_cluster <- stats::setNames(rep(names(ref_members), lengths(ref_members)), unlist(ref_members))
  keep       <- rownames(coords) %in% names(ent_to_cluster)                 # retained (assigned) entities only
  n_assigned <- sum(keep)
  n_dropped  <- nrow(coords) - n_assigned                                   # dropped = unassigned (sub-min_size)
  memb_int   <- as.integer(factor(ent_to_cluster[rownames(coords)[keep]]))

  sil_mean   <- NA_real_
  sil_status <- "ok"
  k_curve    <- NULL
  k_decision <- NULL
  sil_band   <- NA_character_
  sil_z <- NA_real_
  sil_p <- NA_real_
  dip_stat <- NA_real_
  dip_p <- NA_real_
  dip_interp <- NA_character_
  shared_mod_z <- NA_real_
  per_sil  <- stats::setNames(rep(NA_real_, n_clusters), names(ref_members))
  if (n_clusters < 2 || length(unique(memb_int)) < 2) {
    sil_status <- "undefined_lt2_clusters"                                  # silhouette undefined; NA with reason
  } else {
    coords_keep <- coords[keep, , drop = FALSE]
    d <- stats::dist(coords_keep)                                           # assigned entities only
    sil <- cluster::silhouette(memb_int, d)
    sil_mean <- mean(sil[, "sil_width"])
    agg <- tapply(sil[, "sil_width"], sil[, "cluster"], mean)
    per_sil <- stats::setNames(as.numeric(agg)[order(as.integer(names(agg)))], names(ref_members))

    # #509: k-selection curves computed on the SAME HCPC procedure that produced
    # the reported labels (not a plain Ward cut). Re-run HCPC(nb.clust = k) on the
    # same MCA object with the production kk/consol config, restrict each partition
    # to the assigned entities, and score silhouette on the MCA-coord distance -> by
    # construction k_selection_curve[k] at the reported k equals mean_silhouette.
    # A separate k_decision_curve reports the relative within-cluster inertia loss
    # (the criterion HCPC actually uses to pick k) so it is explicit that k was NOT
    # chosen by silhouette. (Wave 1 uses kk = 50; Task 10 flips kk to Inf in both
    # gen_mca_clust_obj and here so the curve keeps matching the served partition.)
    within_inertia <- function(cm, lab) {
      sum(vapply(split(seq_len(nrow(cm)), lab), function(idx) {
        if (length(idx) < 2L) return(0)
        blk <- cm[idx, , drop = FALSE]
        ctr <- colMeans(blk)
        sum((blk - matrix(ctr, nrow(blk), ncol(blk), byrow = TRUE))^2)
      }, numeric(1)))
    }
    # Candidate k grid = 2..10 plus the actual data-driven k (so the curve always
    # contains an anchor point that reproduces the reported partition), capped by N.
    ks <- sort(unique(c(2:min(10L, n_assigned - 1L),
                        as.integer(data_driven_k))))
    ks <- ks[ks >= 2L & ks <= (n_assigned - 1L)]
    keep_names <- rownames(coords)[keep]
    # Re-run the EXACT served procedure (gen_mca_clust_obj, which re-seeds
    # internally and owns the kk/consol config) forcing each k, so the curve
    # describes the reported partition. At the auto-selected k this reproduces the
    # served labels -> k_selection_curve[k_selected] == mean_silhouette exactly.
    per_k <- lapply(ks, function(k) {
      cl_k <- tryCatch(
        gen_mca_clust_obj(wide_phenotypes_df, min_size = min_size,
                          quali_sup_var = quali_sup_var, quanti_sup_var = quanti_sup_var,
                          cutpoint = k),
        error = function(e) NULL
      )
      if (is.null(cl_k) || nrow(cl_k) == 0) return(list(sil = NA_real_, w = NA_real_))
      members_k <- stats::setNames(
        lapply(cl_k$identifiers, function(dd) as.character(dd$entity_id)),
        as.character(cl_k$cluster)
      )
      e2c   <- stats::setNames(rep(names(members_k), lengths(members_k)), unlist(members_k))
      ids_k <- intersect(keep_names, names(e2c))
      if (length(ids_k) < 3L || length(unique(e2c[ids_k])) < 2L) {
        return(list(sil = NA_real_, w = NA_real_))
      }
      lab <- as.integer(factor(e2c[ids_k]))
      ck  <- coords[ids_k, , drop = FALSE]
      list(sil = mean(cluster::silhouette(lab, stats::dist(ck))[, "sil_width"]),
           w = within_inertia(ck, lab))
    })
    k_curve <- stats::setNames(lapply(per_k, function(x) x$sil), as.character(ks))
    w_vals  <- vapply(per_k, function(x) x$w, numeric(1))
    # relative within-cluster inertia loss (the criterion HCPC uses to pick k), so
    # it is explicit that k was chosen by inertia loss, not by the silhouette curve.
    rel_loss <- c(NA_real_, utils::head(w_vals, -1) / utils::tail(w_vals, -1) - 1)
    k_decision <- stats::setNames(as.list(round(rel_loss, 4)), as.character(ks))

    sil_band <- if (sil_mean <= 0.25) "no_substantial_structure_continuum"
                else if (sil_mean <= 0.5) "weak_structure"
                else if (sil_mean <= 0.7) "reasonable_structure" else "strong_structure"

    # #511: unit-free, null-calibrated separation on the phenotype axis + the SAME
    # modularity-z index via a mutual-kNN graph of the MCA coords, so both axes are
    # comparable. Plus a representation-agnostic dip test on the distance vector.
    sil_null_n <- as.integer(Sys.getenv("ANALYSIS_SILHOUETTE_NULL_N", "1000"))
    mod_null_n <- as.integer(Sys.getenv("ANALYSIS_MODULARITY_NULL_N", "200"))
    knn_k      <- as.integer(Sys.getenv("ANALYSIS_PHENOTYPE_KNN_K", "15"))
    sz <- silhouette_null_zscore(coords_keep, memb_int, n_null = sil_null_n, seed = seed)
    sil_z <- sz$z
    sil_p <- sz$p_empirical
    dp <- dip_unimodality(as.vector(d))
    dip_stat <- dp$dip_statistic
    dip_p <- dp$p_value
    dip_interp <- dp$interpretation
    rownames(coords_keep) <- keep_names
    kg <- tryCatch(knn_similarity_graph(coords_keep, k = knn_k), error = function(e) NULL)
    if (!is.null(kg) && igraph::ecount(kg) > 0L) {
      smz <- tryCatch(
        modularity_null_zscore(kg, memb_int, weights = igraph::E(kg)$weight,
                               n_null = mod_null_n, seed = seed),
        error = function(e) list(z = NA_real_)
      )
      shared_mod_z <- smz$z
    }
  }

  # Subsample entities WITHOUT replacement; recompute MCA+HCPC; max-Jaccard per visible cluster.
  per_cluster_acc <- stats::setNames(rep(list(numeric(0)), n_clusters), names(ref_members))
  all_entities <- entity_ids
  m <- max(2L, floor(subsample_fraction * length(all_entities)))
  n_eff <- 0L
  for (b in seq_len(n_resamples)) {
    set.seed(seed + b)
    sampled <- sample(all_entities, m, replace = FALSE)
    df_b <- wide_phenotypes_df[match(sampled, all_entities), , drop = FALSE]
    cl_b <- tryCatch(
      gen_mca_clust_obj(df_b, min_size = min_size, quali_sup_var = quali_sup_var,
                        quanti_sup_var = quanti_sup_var, cutpoint = -1),     # tibble
      error = function(e) NULL
    )
    if (is.null(cl_b) || nrow(cl_b) == 0) next
    n_eff <- n_eff + 1L
    boot_members <- lapply(cl_b$identifiers, function(d) as.character(d$entity_id))
    jac <- cluster_max_jaccard(ref_members, boot_members, sampled)
    for (k in names(ref_members)) per_cluster_acc[[k]] <- c(per_cluster_acc[[k]], jac[[k]])
  }

  per_cluster <- dplyr::tibble(
    cluster_id = names(ref_members),
    # Mean/count over resamples where the cluster was actually testable (had >=1
    # reference member present in the subsample); NA recoveries are excluded.
    jaccard_mean = vapply(per_cluster_acc, jaccard_mean_non_na, numeric(1)),
    jaccard_n_resamples = vapply(per_cluster_acc, function(v) sum(!is.na(v)), integer(1)),
    bootstrap_seed = seed,
    silhouette_mean = per_sil
  )
  list(
    per_cluster = per_cluster,
    partition = list(
      validation_schema_version = "2.0",
      algorithm = "mca_hcpc", k = n_clusters, k_selected = as.integer(data_driven_k),
      hcpc_nb_clust = as.integer(data_driven_k),
      # kk = Inf -> full Ward tree + real k-means consolidation actually runs (#509).
      hcpc_kk = "Inf", consolidation = TRUE,
      active_feature_set = mca_prov,
      ncp_used = 8L,
      ncp_recommended_1overq = if (!is.null(ncp_diag)) ncp_diag$ncp else NA_integer_,
      adjusted_inertia = if (!is.null(ncp_diag)) ncp_diag$adjusted_inertia else NA_real_,
      k_selection_metric = "hcpc_relative_inertia_loss",
      k_selection_curve = k_curve, k_decision_curve = k_decision,
      mean_silhouette = sil_mean, silhouette_status = sil_status,
      silhouette_interpretation = sil_band,
      silhouette_z = sil_z, silhouette_p_empirical = sil_p, null_model = "label_permutation",
      shared_modularity_z = shared_mod_z, separation_z = sil_z,
      dip_statistic = dip_stat, dip_p = dip_p, dip_interpretation = dip_interp,
      dip_scope = "mca_coord_distance",
      n_clusters = n_clusters, n_entities_assigned = n_assigned, n_entities_dropped = n_dropped,
      partition_scope = "visible_top_level",
      resampling_scheme = "subsample", subsample_fraction = subsample_fraction,
      n_resamples = n_resamples, n_resamples_effective = n_eff
    )
  )
}
