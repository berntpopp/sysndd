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
