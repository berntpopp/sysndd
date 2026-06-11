# functions/pubtator-enrichment-metrics.R
#
# Pure, library-light statistical metrics that normalize PubtatorNDD gene
# co-occurrence counts for research-popularity bias (GitHub issue #175).
#
# Raw co-occurrence count with NDD terms conflates true NDD relevance with how
# heavily a gene is studied: TP53/APP/MAPT/APOE surface in the top 10 by raw
# count despite no specific NDD role. Normalizing by the gene's TOTAL PubTator
# publication count separates true NDD genes (0.1-0.6% NDD/Total) from
# popularity noise (0.001-0.01%) by ~two orders of magnitude.
#
# Three complementary, defensible metrics are computed per gene against a fixed
# 2x2 contingency built from corpus-level counts:
#
#   * Enrichment ratio (observed / expected fold-change) -- simple, intuitive
#     ranking. Equivalent to the "fold enrichment" used in over-representation
#     analysis: observed / (ndd_corpus_size * background_count / total_corpus).
#   * NPMI (Normalized Pointwise Mutual Information, Bouma 2009), bounded
#     [-1, 1] -- inherently normalizes for both gene popularity and corpus
#     size; this is the association measure recommended by CoCoScore
#     (Groth et al. 2020) and PMI-family text-mining (DISEASES,
#     Pletscher-Frankild et al. 2015).
#   * Fisher's exact test p-value (one-sided, enrichment) + Benjamini-Hochberg
#     FDR across all genes -- statistical significance of the association.
#
# References:
#   - Bouma G. (2009) Normalized (Pointwise) Mutual Information in Collocation
#     Extraction. Proc. GSCL.
#   - Pletscher-Frankild et al. (2015) DISEASES: Text mining and data
#     integration of disease-gene associations. Methods 74:83-89.
#   - Groth et al. (2020) CoCoScore: context-aware co-occurrence scoring.
#     Bioinformatics 36(1):264-271.
#   - Stoeger et al. (2018) Large-scale investigation of the reasons why
#     potentially important genes are ignored. PLOS Biology.
#
# No DB access here; no external calls. Fully unit-testable. See
# functions/pubtator-enrichment-collector.R for the count collection and DB I/O.

#' Compute the fold enrichment ratio for a single gene-NDD co-occurrence
#'
#' @param observed Number of NDD-corpus publications mentioning the gene
#'   (the curated PubtatorNDD co-occurrence count).
#' @param background_count Total PubTator publications mentioning the gene
#'   anywhere in the corpus (the popularity denominator).
#' @param ndd_corpus_size Number of publications in the NDD corpus.
#' @param total_corpus_size Number of publications in the whole PubTator corpus.
#'
#' @return Numeric fold enrichment (observed / expected). `NA_real_` when inputs
#'   are missing or any denominator is zero. A value > 1 means the gene
#'   co-occurs with NDD more than its overall publication volume predicts.
#' @export
pubtator_enrichment_ratio <- function(observed,
                                      background_count,
                                      ndd_corpus_size,
                                      total_corpus_size) {
  if (.pubtator_metric_invalid(observed, background_count,
                               ndd_corpus_size, total_corpus_size)) {
    return(NA_real_)
  }
  if (background_count <= 0 || total_corpus_size <= 0) {
    return(NA_real_)
  }

  # expected = how many of the gene's publications would land in the NDD corpus
  # if NDD-membership were independent of this gene.
  expected <- ndd_corpus_size * (background_count / total_corpus_size)
  if (expected <= 0) {
    return(NA_real_)
  }

  observed / expected
}

#' Compute Normalized Pointwise Mutual Information (NPMI) for one gene-NDD pair
#'
#' NPMI(x, y) = PMI(x, y) / -log p(x, y), bounded to [-1, 1]:
#'   +1  the gene and NDD always co-occur (p(x,y) == p(x) == p(y))
#'    0  independence (observed == expected)
#'   -1  the gene and NDD never co-occur (observed == 0)
#'
#' Here x = "publication mentions the gene", y = "publication is in the NDD
#' corpus", and the sample space is the whole PubTator corpus, so:
#'   p(x)   = background_count / total_corpus_size
#'   p(y)   = ndd_corpus_size  / total_corpus_size
#'   p(x,y) = observed         / total_corpus_size
#'
#' @inheritParams pubtator_enrichment_ratio
#'
#' @return Numeric NPMI in [-1, 1], or `NA_real_` for invalid inputs. Returns
#'   exactly -1 when `observed == 0` (the never-co-occur limit).
#' @export
pubtator_npmi <- function(observed,
                          background_count,
                          ndd_corpus_size,
                          total_corpus_size) {
  if (.pubtator_metric_invalid(observed, background_count,
                               ndd_corpus_size, total_corpus_size)) {
    return(NA_real_)
  }
  if (total_corpus_size <= 0 || background_count <= 0 || ndd_corpus_size <= 0) {
    return(NA_real_)
  }

  # Never co-occur: PMI -> -Inf, NPMI -> -1 (the defined limit).
  if (observed <= 0) {
    return(-1)
  }

  p_xy <- observed / total_corpus_size
  p_x <- background_count / total_corpus_size
  p_y <- ndd_corpus_size / total_corpus_size

  # Always co-occur: p(x,y) == p(x) == p(y); -log p(x,y) == 0 -> NPMI = +1.
  if (isTRUE(all.equal(p_xy, 1))) {
    return(1)
  }

  pmi <- log(p_xy / (p_x * p_y))
  denom <- -log(p_xy)
  if (denom <= 0) {
    # p(x,y) == 1 handled above; any residual zero denominator -> perfect assoc.
    return(1)
  }

  npmi <- pmi / denom
  # Guard against floating point spilling slightly outside the bound.
  max(-1, min(1, npmi))
}

#' Build the 2x2 contingency table for a gene-NDD Fisher test
#'
#' Cells follow the standard over-representation layout:
#'   a = gene & NDD            = observed
#'   b = gene & not-NDD        = background_count - observed
#'   c = not-gene & NDD        = ndd_corpus_size - observed
#'   d = not-gene & not-NDD    = total - background_count - ndd_corpus_size + observed
#'
#' @inheritParams pubtator_enrichment_ratio
#'
#' @return A 2x2 integer matrix, or `NULL` if inputs are invalid / inconsistent
#'   (e.g. observed exceeds a marginal, negative cells).
#' @export
pubtator_contingency_table <- function(observed,
                                       background_count,
                                       ndd_corpus_size,
                                       total_corpus_size) {
  if (.pubtator_metric_invalid(observed, background_count,
                               ndd_corpus_size, total_corpus_size)) {
    return(NULL)
  }

  a <- observed
  b <- background_count - observed
  c <- ndd_corpus_size - observed
  d <- total_corpus_size - background_count - ndd_corpus_size + observed

  if (a < 0 || b < 0 || c < 0 || d < 0) {
    return(NULL)
  }

  matrix(
    c(a, c, b, d),
    nrow = 2,
    byrow = FALSE,
    dimnames = list(
      c("ndd", "not_ndd"),
      c("gene", "not_gene")
    )
  )
}

#' One-sided (enrichment) Fisher's exact test p-value for a gene-NDD pair
#'
#' @inheritParams pubtator_enrichment_ratio
#'
#' @return Numeric p-value in (0, 1], or `NA_real_` if the contingency table
#'   cannot be built. Uses `stats::fisher.test(alternative = "greater")` so the
#'   test asks specifically whether the gene is *enriched* in the NDD corpus.
#' @export
pubtator_fisher_pvalue <- function(observed,
                                   background_count,
                                   ndd_corpus_size,
                                   total_corpus_size) {
  tbl <- pubtator_contingency_table(
    observed, background_count, ndd_corpus_size, total_corpus_size
  )
  if (is.null(tbl)) {
    return(NA_real_)
  }

  result <- tryCatch(
    stats::fisher.test(tbl, alternative = "greater"),
    error = function(e) NULL
  )
  if (is.null(result)) {
    return(NA_real_)
  }
  result$p.value
}

#' Benjamini-Hochberg FDR correction across a vector of p-values
#'
#' Thin wrapper over `stats::p.adjust(method = "BH")` that tolerates `NA`
#' p-values (genes whose contingency table could not be built) by leaving them
#' `NA` in the output while correcting only the finite p-values.
#'
#' @param p_values Numeric vector of raw p-values (may contain `NA`).
#'
#' @return Numeric vector of BH-adjusted q-values, same length/order as input.
#' @export
pubtator_bh_fdr <- function(p_values) {
  out <- rep(NA_real_, length(p_values))
  finite_idx <- which(!is.na(p_values))
  if (length(finite_idx) == 0) {
    return(out)
  }
  out[finite_idx] <- stats::p.adjust(p_values[finite_idx], method = "BH")
  out
}

#' Compute all enrichment metrics for a data frame of gene counts
#'
#' Vectorized convenience used by the collector/worker. Adds `enrichment_ratio`,
#' `npmi`, `fisher_p`, and `fdr_bh` columns. BH-FDR is computed across the whole
#' input set, so pass *all* genes from one corpus snapshot together.
#'
#' @param gene_counts A data frame with `observed` and `background_count`
#'   columns (one row per gene).
#' @param ndd_corpus_size Scalar NDD corpus size.
#' @param total_corpus_size Scalar total corpus size.
#'
#' @return The input data frame with the four metric columns appended.
#' @export
pubtator_compute_gene_metrics <- function(gene_counts,
                                          ndd_corpus_size,
                                          total_corpus_size) {
  stopifnot(is.data.frame(gene_counts))
  if (!all(c("observed", "background_count") %in% names(gene_counts))) {
    stop("gene_counts must contain 'observed' and 'background_count' columns")
  }

  n <- nrow(gene_counts)
  enrichment_ratio <- numeric(n)
  npmi <- numeric(n)
  fisher_p <- numeric(n)

  for (i in seq_len(n)) {
    obs <- gene_counts$observed[[i]]
    bg <- gene_counts$background_count[[i]]
    enrichment_ratio[[i]] <- pubtator_enrichment_ratio(
      obs, bg, ndd_corpus_size, total_corpus_size
    )
    npmi[[i]] <- pubtator_npmi(
      obs, bg, ndd_corpus_size, total_corpus_size
    )
    fisher_p[[i]] <- pubtator_fisher_pvalue(
      obs, bg, ndd_corpus_size, total_corpus_size
    )
  }

  gene_counts$enrichment_ratio <- enrichment_ratio
  gene_counts$npmi <- npmi
  gene_counts$fisher_p <- fisher_p
  gene_counts$fdr_bh <- pubtator_bh_fdr(fisher_p)
  gene_counts
}

#' Internal: validate the four scalar metric inputs
#' @noRd
.pubtator_metric_invalid <- function(observed,
                                     background_count,
                                     ndd_corpus_size,
                                     total_corpus_size) {
  vals <- list(observed, background_count, ndd_corpus_size, total_corpus_size)
  for (v in vals) {
    if (is.null(v) || length(v) != 1L || is.na(v) || !is.finite(v)) {
      return(TRUE)
    }
  }
  FALSE
}
