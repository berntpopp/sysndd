# functions/analysis-string-channels.R
#
# Text-mining-free STRING edge weights for functional clustering (#510).
# Worker/heavy-path only — never invoked on a public request. Deterministic.
#
# STRING's per-channel scores are integer confidences in [0, 1000] (probability
# x 1000). The published `combined_score` folds in the text-mining channel, so a
# gene pair can look "functionally linked" purely because they are co-mentioned
# in the literature — which contaminates the functional-modularity axis with the
# very literature signal it is meant to be independent of. To keep the functional
# axis clean we DROP text-mining (and any other unwanted channel) and re-combine
# ONLY the selected channels (default: experimental + database) with STRING's own
# probabilistic-OR "naive Bayesian" combine formula.
#
# STRING combine formula (Szklarczyk et al., STRING DB papers; von Mering 2005):
# given per-channel probabilities s_i in [0, 1] and a random-expectation prior p,
#   strip(s)   = max(0, (s - p) / (1 - p))          # remove the prior from each channel
#   combined'  = 1 - prod_i (1 - strip(s_i))        # probabilistic OR of the channels
#   final      = combined' + p * (1 - combined')     # add the prior back once
# Channel scores are passed/returned on the 0..1000 integer scale; the prior is
# STRING's default p = 0.041.
#
# Env `STRING_WEIGHT_CHANNELS` (default "experimental,database") selects which
# detailed-file channel columns are OR-combined; listing other channel names that
# are present as columns generalizes the OR over those columns instead.

# STRING's default random-expectation prior (p) used to strip/re-add the prior.
STRING_COMBINE_PRIOR <- 0.041

#' Channels to OR-combine, from `STRING_WEIGHT_CHANNELS` (default exp + database).
#'
#' Text-mining is deliberately excluded by default so functional modularity is
#' not contaminated by literature co-mention (#510).
#'
#' @return character vector of channel column names.
#' @export
string_weight_channels <- function() {
  raw <- Sys.getenv("STRING_WEIGHT_CHANNELS", "experimental,database")
  channels <- trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
  channels <- channels[nzchar(channels)]
  if (!length(channels)) channels <- c("experimental", "database")
  channels
}

#' Probabilistic-OR combine of a list of channel score vectors.
#'
#' Internal helper implementing STRING's combine formula over an arbitrary set of
#' channels (each a numeric vector of 0..1000 integer scores of equal length).
#'
#' @param channel_list list of numeric vectors (0..1000 channel scores).
#' @param prior STRING random-expectation prior.
#' @return numeric vector of recombined 0..1000 scores.
#' @keywords internal
.string_or_combine <- function(channel_list, prior = STRING_COMBINE_PRIOR) {
  if (!length(channel_list)) {
    stop("string channel combine requires at least one channel", call. = FALSE)
  }
  n <- length(channel_list[[1L]])
  prod_term <- rep(1, n) # accumulates prod_i (1 - strip(s_i))
  for (ch in channel_list) {
    s <- as.numeric(ch) / 1000
    stripped <- pmax(0, (s - prior) / (1 - prior)) # remove prior from this channel
    prod_term <- prod_term * (1 - stripped)
  }
  combined <- 1 - prod_term # probabilistic OR
  final <- combined + prior * (1 - combined) # add the prior back once
  final * 1000
}

#' Recombine the experimental + database channels via STRING's OR combine.
#'
#' Vectorized. Inputs are 0..1000 integer channel scores (experimental, database);
#' returns the recombined 0..1000 score (numeric). An edge with only text-mining
#' evidence (experimental = 0, database = 0) collapses to the prior (~41), well
#' below any useful threshold.
#'
#' @param escore experimental-channel score(s), 0..1000.
#' @param dscore database-channel score(s), 0..1000.
#' @param prior STRING random-expectation prior (default 0.041).
#' @return numeric vector of recombined 0..1000 scores.
#' @export
string_recompute_score <- function(escore, dscore, prior = STRING_COMBINE_PRIOR) {
  .string_or_combine(list(escore, dscore), prior = prior)
}

#' Text-mining-free STRING edges from the detailed links file.
#'
#' Takes the STRING `9606.protein.links.detailed.v11.5.txt` columns (at least
#' `protein1, protein2` plus the channel columns named in `STRING_WEIGHT_CHANNELS`;
#' other channel columns present in the frame are ignored), recombines only the
#' selected channels into `exp_db_score`, and keeps only edges scoring at least
#' `score_threshold`. This is the primary functional-clustering weight (#510).
#'
#' @param detailed_df data.frame/tibble with `protein1`, `protein2`, and the
#'   selected channel columns (default `experimental`, `database`).
#' @param score_threshold minimum recombined score to retain an edge (default 400).
#' @return tibble `(protein1, protein2, exp_db_score)` of retained edges.
#' @export
string_textmining_free_edges <- function(detailed_df, score_threshold = 400) {
  channels <- string_weight_channels()
  required <- c("protein1", "protein2", channels)
  missing <- setdiff(required, names(detailed_df))
  if (length(missing)) {
    stop(
      "string_textmining_free_edges: missing required column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  channel_list <- lapply(channels, function(cn) detailed_df[[cn]])
  exp_db_score <- .string_or_combine(channel_list, prior = STRING_COMBINE_PRIOR)
  out <- tibble::tibble(
    protein1 = detailed_df[["protein1"]],
    protein2 = detailed_df[["protein2"]],
    exp_db_score = exp_db_score
  )
  dplyr::filter(out, is.finite(.data$exp_db_score) & .data$exp_db_score >= score_threshold)
}
