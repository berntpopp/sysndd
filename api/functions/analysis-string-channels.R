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

#' Path to the precomputed compact text-mining-free (exp+db) edge file.
#'
#' The full STRING detailed links file is ~12M rows; this compact file
#' (`protein1 protein2 exp_db_score`, exp+db recombined and thresholded once) is
#' the operational artifact the functional pipeline reads. Built by the db-prep
#' step from `9606.protein.links.detailed.v11.5.txt.gz`. Env-overridable.
#'
#' @return file path (relative to the API working dir, i.e. resolves under data/).
#' @export
string_expdb_edges_file <- function() {
  Sys.getenv("STRING_EXPDB_EDGES_FILE", "data/9606.protein.links.expdb.v11.5.min400.txt.gz")
}

#' Build the induced text-mining-free (exp+db) STRING subgraph for a set of ids.
#'
#' Reads the compact exp+db edge file, keeps edges whose BOTH endpoints are in
#' `string_ids` and whose recombined score >= `score_threshold`, and returns a
#' weighted igraph. The exp+db score is written to the edge attribute
#' `combined_score` so the existing weighted-Leiden / modularity plumbing consumes
#' it unchanged, and a graph attribute `weight_channel = "experimental_database"`
#' labels the channel. Returns NULL when the compact file is absent so the caller
#' can fall back to the STRINGdb combined graph (graceful degradation).
#'
#' @param string_ids character vector of STRING protein ids (e.g. 9606.ENSP...).
#' @param score_threshold minimum exp+db score to retain an edge (default 400).
#' @param file compact exp+db edge file (default `string_expdb_edges_file()`).
#' @return weighted igraph (all `string_ids` as vertices; isolates retained), or NULL.
#' @export
string_expdb_subgraph <- function(string_ids, score_threshold = 400,
                                  file = string_expdb_edges_file()) {
  if (!file.exists(file)) {
    return(NULL)
  }
  edges <- data.table::fread(
    cmd = paste("zcat", shQuote(file)),
    col.names = c("protein1", "protein2", "exp_db_score")
  )
  ids <- unique(as.character(string_ids))
  e <- edges[edges$protein1 %in% ids & edges$protein2 %in% ids &
               edges$exp_db_score >= score_threshold, ]
  g <- igraph::graph_from_data_frame(
    data.frame(from = as.character(e$protein1), to = as.character(e$protein2),
               stringsAsFactors = FALSE),
    directed = FALSE,
    vertices = data.frame(name = ids, stringsAsFactors = FALSE)
  )
  igraph::E(g)$combined_score <- as.numeric(e$exp_db_score) # plumbing-compatible weight
  # STRING's detailed links file lists every undirected pair in BOTH directions
  # (protein1->protein2 and protein2->protein1), so an undirected graph built from
  # it is a multigraph with each edge duplicated. Collapse to a simple graph so the
  # edge counts (giant_component$n_edges, edge_retention) and the exported
  # reproducibility edge list are the true undirected counts and match the
  # STRINGdb-combined fallback (which is already simple). Weighted modularity/Leiden
  # are invariant to the uniform 2x duplication, so the partition is unchanged; the
  # duplicate scores are identical, so "first" is exact.
  g <- igraph::simplify(
    g, remove.multiple = TRUE, remove.loops = TRUE,
    edge.attr.comb = list(combined_score = "first")
  )
  attr(g, "weight_channel") <- "experimental_database"
  g
}
