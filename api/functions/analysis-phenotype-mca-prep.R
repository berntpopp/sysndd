# functions/analysis-phenotype-mca-prep.R
#
# MCA feature hygiene for the phenotype cluster analysis (#508).
# Worker/heavy-path only — never invoked on a public request. Deterministic.
#
# The phenotype MCA operates on an entities x HPO-organ-system presence matrix
# (see generate_phenotype_cluster_input): each HPO term is a character column
# coded "yes" where present and NA where absent, preceded by a small set of
# supplementary columns (the inheritance name, then the phenotype_non_id_count,
# phenotype_id_count and gene_entity_count integer columns) that MCA carries as
# quali.sup / quanti.sup and must therefore be preserved untouched.
#
# Using the HPO subtree root ("Phenotypic abnormality", HP:0000118) and
# near-universal / near-rare terms as *active* MCA variables dilutes inertia and
# mechanically depresses the silhouette. These helpers:
#   1. phenotype_mca_active_filter  -> drop the root + terms outside a prevalence
#      band, keeping the supplementary columns as leading columns;
#   2. phenotype_mca_encode_presence -> recode {"yes", NA} to an explicit
#      {absent, present} 2-level factor so absence is a real MCA category
#      (Le Roux & Rouanet; Greenacre);
#   3. phenotype_mca_ncp -> Greenacre 1/Q dimension-retention rule plus
#      Greenacre-adjusted inertia percentages for the retained axes.
#
# Refs: Greenacre 2007 (adjusted inertia, 1/Q rule); Le Roux & Rouanet 2004
# (absence as an MCA category); Kaufman & Rousseeuw 1990 (silhouette bands).

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Detect an HPO presence column: a character/factor column whose non-NA values
# are all the sentinel "yes". The supplementary columns are excluded by this
# test because the inheritance column holds inheritance names (not "yes") and the
# three count columns are numeric.
.phenotype_mca_is_presence_column <- function(col) {
  if (!(is.character(col) || is.factor(col))) {
    return(FALSE)
  }
  vals <- unique(as.character(col))
  vals <- vals[!is.na(vals)]
  # Require at least one non-NA "yes": an all-NA character column (e.g. a fully
  # missing supplementary inheritance column) would otherwise satisfy
  # `all(character(0) %in% "yes") == TRUE` and be misclassified as a presence
  # column, then dropped as near_rare and shift the quali.sup/quanti.sup indices.
  length(vals) > 0L && all(vals %in% "yes")
}

# Prevalence of a presence column = fraction of rows coded "yes" (absent = NA).
.phenotype_mca_prevalence <- function(col, n_rows) {
  if (n_rows <= 0L) {
    return(NA_real_)
  }
  sum(as.character(col) == "yes", na.rm = TRUE) / n_rows
}

# Is this presence column the HPO ontology root (HP:0000118)?
# Either the column NAME is in drop_terms, or an optional name->id lookup maps it
# to HP:0000118.
.phenotype_mca_is_root <- function(term, drop_terms, hpo_lookup) {
  if (term %in% drop_terms) {
    return(TRUE)
  }
  if (!is.null(hpo_lookup) &&
    all(c("HPO_term", "phenotype_id") %in% colnames(hpo_lookup))) {
    ids <- hpo_lookup$phenotype_id[hpo_lookup$HPO_term == term]
    ids <- ids[!is.na(ids)]
    if (any(ids == "HP:0000118")) {
      return(TRUE)
    }
  }
  FALSE
}

#' Drop near-constant / root HPO presence columns from the MCA active set.
#'
#' The supplementary columns (inheritance + the three count columns) are
#' preserved untouched and returned as the leading columns of `active_matrix` in
#' their original positions/order, so downstream `MCA(quali.sup = 1,
#' quanti.sup = 2:4)` still refers to them by the same indices.
#'
#' @param matrix data.frame; entities in rownames, presence columns + leading
#'   supplementary columns (see generate_phenotype_cluster_input).
#' @param prevalence_min,prevalence_max numeric prevalence band; a presence
#'   column with prevalence < min is `near_rare`, > max is `near_universal`.
#' @param drop_terms character; presence-column NAMES to always drop (the HPO
#'   root is named "Phenotypic abnormality").
#' @param hpo_lookup optional data.frame/tibble with `HPO_term`/`phenotype_id`
#'   columns to map a column name to its HPO id for the root check.
#' @return list(active_matrix, kept_terms, excluded) where `excluded` is a
#'   tibble (term, prevalence, reason) with reason in
#'   {"root", "near_universal", "near_rare"} (root takes precedence).
phenotype_mca_active_filter <- function(matrix,
                                        prevalence_min = 0.05,
                                        prevalence_max = 0.95,
                                        drop_terms = c("Phenotypic abnormality"),
                                        hpo_lookup = NULL) {
  mat <- as.data.frame(matrix, stringsAsFactors = FALSE)
  n_rows <- nrow(mat)
  all_cols <- colnames(mat)

  is_presence <- vapply(
    mat,
    .phenotype_mca_is_presence_column,
    logical(1)
  )
  presence_cols <- all_cols[is_presence]

  kept_terms <- character(0)
  ex_term <- character(0)
  ex_prev <- numeric(0)
  ex_reason <- character(0)

  for (term in presence_cols) {
    prev <- .phenotype_mca_prevalence(mat[[term]], n_rows)
    if (.phenotype_mca_is_root(term, drop_terms, hpo_lookup)) {
      reason <- "root"
    } else if (is.finite(prev) && prev > prevalence_max) {
      reason <- "near_universal"
    } else if (is.finite(prev) && prev < prevalence_min) {
      reason <- "near_rare"
    } else {
      kept_terms <- c(kept_terms, term)
      next
    }
    ex_term <- c(ex_term, term)
    ex_prev <- c(ex_prev, prev)
    ex_reason <- c(ex_reason, reason)
  }

  # Preserve original column order: supplementary columns are never presence
  # columns, so keeping every non-excluded column leaves them as leading columns.
  keep_cols <- all_cols[!(all_cols %in% ex_term)]
  active_matrix <- mat[, keep_cols, drop = FALSE]

  excluded <- tibble::tibble(
    term = ex_term,
    prevalence = ex_prev,
    reason = ex_reason
  )

  # Defensive: MCA needs >= 2 active variables. With realistic NDD data dozens of
  # organ-system terms survive the band; an empty/degenerate active set would only
  # arise from an unexpected input (e.g. a mis-shaped matrix) and would otherwise
  # crash downstream FactoMineR::MCA() with an opaque error. Surface it early.
  if (length(kept_terms) < 2L) {
    warning(sprintf(
      "phenotype_mca_active_filter: only %d active term(s) survived the prevalence band [%.3f, %.3f]; MCA needs >= 2.",
      length(kept_terms), prevalence_min, prevalence_max
    ), call. = FALSE)
  }

  list(
    active_matrix = active_matrix,
    kept_terms = kept_terms,
    excluded = excluded
  )
}

#' Recode HPO presence columns to explicit {absent, present} 2-level factors.
#'
#' MCA treats NA as a missing category; encoding absence as a real level lets it
#' contribute inertia (Le Roux & Rouanet; Greenacre). Supplementary columns are
#' left unchanged.
#'
#' @param matrix data.frame with the presence columns coded {"yes", NA}.
#' @param presence_cols character; the presence column names to recode.
#' @return the data.frame with each presence column a factor with levels
#'   c("absent", "present") (NA -> "absent", "yes" -> "present").
phenotype_mca_encode_presence <- function(matrix, presence_cols) {
  mat <- as.data.frame(matrix, stringsAsFactors = FALSE)
  for (term in presence_cols) {
    if (!term %in% colnames(mat)) {
      next
    }
    vals <- as.character(mat[[term]])
    coded <- ifelse(!is.na(vals) & vals == "yes", "present", "absent")
    mat[[term]] <- factor(coded, levels = c("absent", "present"))
  }
  mat
}

#' Apply the full #508 MCA feature hygiene to a raw phenotype presence matrix.
#'
#' Single entry point so EVERY path that feeds a phenotype matrix into MCA/HCPC —
#' the served snapshot input (`generate_phenotype_cluster_input`) AND the
#' interactive/durable async clustering job (`.async_job_phenotype_matrix`) —
#' consumes the identical cleaned active set and cannot silently diverge. Reads the
#' prevalence band from `PHENOTYPE_MCA_PREVALENCE_MIN`/`MAX`, drops the HPO subtree
#' root + near-constant terms, recodes `{"yes", NA}` to `{present, absent}`, and
#' attaches the `mca_provenance` attribute.
#'
#' @param matrix data.frame; entities in rownames, leading supplementary columns +
#'   `{"yes", NA}` presence columns.
#' @param hpo_lookup optional data.frame with `HPO_term`/`phenotype_id` for the
#'   root check (name -> HP:0000118).
#' @return the cleaned/encoded data.frame carrying an `mca_provenance` attribute.
#' @export
phenotype_mca_prep_matrix <- function(matrix, hpo_lookup = NULL) {
  prev_min <- as.numeric(Sys.getenv("PHENOTYPE_MCA_PREVALENCE_MIN", "0.05"))
  prev_max <- as.numeric(Sys.getenv("PHENOTYPE_MCA_PREVALENCE_MAX", "0.95"))
  prep <- phenotype_mca_active_filter(
    matrix,
    prevalence_min = prev_min,
    prevalence_max = prev_max,
    hpo_lookup = hpo_lookup
  )
  active <- phenotype_mca_encode_presence(prep$active_matrix, prep$kept_terms)
  provenance <- list(
    kept_terms = prep$kept_terms,
    excluded_terms = prep$excluded,
    prevalence_band = c(min = prev_min, max = prev_max),
    n_active_terms = length(prep$kept_terms),
    encoding = "absent_present_factor"
  )
  attr(active, "mca_provenance") <- provenance
  active
}

#' Greenacre 1/Q dimension-retention rule + adjusted inertia.
#'
#' Retain axes whose eigenvalue exceeds the average inertia 1/Q (Q = number of
#' active variables); floor the count so HCPC always has >= `floor` dimensions.
#' Adjusted-inertia percentages rescale the retained eigenvalues onto Greenacre's
#' adjusted total inertia, which discounts the off-diagonal Burt-table inflation.
#'
#' @param eigenvalues numeric vector of MCA eigenvalues (e.g. `mca$eig[, 1]`).
#' @param q_active integer number of active variables (Q).
#' @param floor integer minimum ncp (default 2).
#' @param n_categories optional total number of categories J across the active
#'   variables; defaults to `2 * q_active` (binary absent/present factors).
#' @return list(ncp, adjusted_inertia) where `adjusted_inertia` is the vector of
#'   Greenacre-adjusted percentages for the retained (lambda > 1/Q) axes.
phenotype_mca_ncp <- function(eigenvalues, q_active, floor = 2L,
                              n_categories = NULL) {
  lambda <- as.numeric(eigenvalues)
  lambda <- lambda[is.finite(lambda)]
  q <- as.numeric(q_active)
  threshold <- 1 / q

  retained <- lambda[lambda > threshold]
  ncp <- max(as.integer(floor), length(retained))

  jj <- n_categories %||% (2 * q)
  greenacre_denom <- (q / (q - 1)) *
    (sum(lambda^2) - (jj - q) / q^2)

  lam_adj <- (q / (q - 1))^2 * (retained - threshold)^2
  adjusted_inertia <- 100 * lam_adj / greenacre_denom

  list(
    ncp = ncp,
    adjusted_inertia = adjusted_inertia
  )
}
