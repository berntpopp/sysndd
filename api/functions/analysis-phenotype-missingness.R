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
#' @return the missingness_sensitivity result list (spec section 4.6). Best-effort:
#'   alignment/guard failures return a diagnostic `status`, never an error, so the caller's
#'   refresh survives.
phenotype_missingness_sensitivity <- function(wide_phenotypes_df, ref_members,
                                              quali_sup_var = 1:1, quanti_sup_var = 2:4) {
  # NB: `base` deliberately omits `status`. c(base, list(status = ...)) would otherwise
  # create a duplicate `status` key and `$status` returns the FIRST match, shadowing every
  # override. Each terminal return sets its own status.
  base <- list(
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
    status = "ok",
    adjusted_rand_index = ari,
    per_cluster_max_jaccard = as.list(recovery),
    silhouette_served_partition = .missingness_silhouette(served_labels, D),
    silhouette_sensitivity_partition = .missingness_silhouette(sens_labels, D),
    interpretation = .missingness_ari_band(ari)
  ))
}
