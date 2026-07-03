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

  # FULL optimized Leiden partition = the quantity the objective maximizes; report ITS modularity.
  full_membership <- .leiden_membership(subgraph, resolution, seed)
  modularity <- igraph::modularity(subgraph, full_membership,
                                   weights = igraph::E(subgraph)$combined_score)

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
    jaccard_mean = vapply(per_cluster_acc, function(v) if (length(v)) mean(v, na.rm = TRUE) else NA_real_, numeric(1)),
    jaccard_n_resamples = vapply(per_cluster_acc, length, integer(1)),
    bootstrap_seed = seed
  )
  list(
    per_cluster = per_cluster,
    partition = list(
      validation_schema_version = "1.0",
      algorithm = "leiden", weighted = TRUE, n_iterations = -1L,
      resolution_parameter = resolution,
      modularity = modularity, modularity_scope = "full_partition",
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

  ent_to_cluster <- stats::setNames(rep(names(ref_members), lengths(ref_members)), unlist(ref_members))
  keep       <- rownames(coords) %in% names(ent_to_cluster)                 # retained (assigned) entities only
  n_assigned <- sum(keep)
  n_dropped  <- nrow(coords) - n_assigned                                   # dropped = unassigned (sub-min_size)
  memb_int   <- as.integer(factor(ent_to_cluster[rownames(coords)[keep]]))

  sil_mean   <- NA_real_
  sil_status <- "ok"
  k_curve    <- NULL
  per_sil  <- stats::setNames(rep(NA_real_, n_clusters), names(ref_members))
  if (n_clusters < 2 || length(unique(memb_int)) < 2) {
    sil_status <- "undefined_lt2_clusters"                                  # silhouette undefined; NA with reason
  } else {
    d <- stats::dist(coords[keep, , drop = FALSE])                          # assigned entities only
    sil <- cluster::silhouette(memb_int, d)
    sil_mean <- mean(sil[, "sil_width"])
    agg <- tapply(sil[, "sil_width"], sil[, "cluster"], mean)
    per_sil <- stats::setNames(as.numeric(agg)[order(as.integer(names(agg)))], names(ref_members))
    # supporting k-selection curve on the SAME Ward linkage HCPC uses (assigned entities only).
    hc <- stats::hclust(d, method = "ward.D2")
    ks <- 2:min(10L, n_assigned - 1L)
    k_curve <- stats::setNames(
      lapply(ks, function(k) mean(cluster::silhouette(stats::cutree(hc, k = k), d)[, "sil_width"])),
      as.character(ks)
    )
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
    jaccard_mean = vapply(per_cluster_acc, function(v) if (length(v)) mean(v, na.rm = TRUE) else NA_real_, numeric(1)),
    jaccard_n_resamples = vapply(per_cluster_acc, length, integer(1)),
    bootstrap_seed = seed,
    silhouette_mean = per_sil
  )
  list(
    per_cluster = per_cluster,
    partition = list(
      validation_schema_version = "1.0",
      algorithm = "mca_hcpc", k = n_clusters,
      k_selection_metric = "hcpc_relative_inertia_loss", k_selection_curve = k_curve,
      mean_silhouette = sil_mean, silhouette_status = sil_status,
      n_clusters = n_clusters, n_entities_assigned = n_assigned, n_entities_dropped = n_dropped,
      partition_scope = "visible_top_level",
      resampling_scheme = "subsample", subsample_fraction = subsample_fraction,
      n_resamples = n_resamples, n_resamples_effective = n_eff
    )
  )
}
