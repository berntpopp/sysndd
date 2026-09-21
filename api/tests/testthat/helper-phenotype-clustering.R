# Shared setup for tests that execute the real phenotype clustering path
# (gen_mca_clust_obj / validate_phenotype_clusters). Auto-loaded by testthat.

#' Production-shaped synthetic MCA input: entity ids in the ROWNAMES, one
#' categorical supplementary column, three numeric supplementary counts, then
#' {absent,present} factor columns for ten HPO-like terms drawn from three latent
#' phenotype profiles. Deterministic for a given seed.
phenotype_synthetic_matrix <- function(n = 400L, seed = 11L) {
  set.seed(seed)
  z <- sample(1:3, n, replace = TRUE, prob = c(0.5, 0.3, 0.2))
  p <- rbind(
    c(0.8, 0.7, 0.6, 0.1, 0.1, 0.1, 0.2, 0.3, 0.1, 0.4),
    c(0.1, 0.2, 0.1, 0.8, 0.7, 0.6, 0.3, 0.2, 0.5, 0.4),
    c(0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.9, 0.8, 0.1, 0.4)
  )
  hpo <- as.data.frame(lapply(seq_len(ncol(p)), function(j) {
    factor(ifelse(stats::runif(n) < p[z, j], "present", "absent"), levels = c("absent", "present"))
  }))
  names(hpo) <- paste0("HP term ", seq_len(ncol(p)))
  df <- data.frame(
    moi = factor(sample(c("AD", "AR", "XL"), n, replace = TRUE)),
    count1 = as.numeric(stats::rpois(n, 2 + z)),
    count2 = as.numeric(stats::rpois(n, 5)),
    count3 = as.numeric(stats::rpois(n, 1 + 2 * (z == 3))),
    hpo, check.names = FALSE
  )
  rownames(df) <- as.character(1000L + seq_len(n))
  df
}

#' Source the phenotype clustering modules into the global env and stub the
#' unrelated identifier-hash helper, restoring everything when `env` exits.
local_phenotype_clustering_runtime <- function(validation = FALSE, env = parent.frame()) {
  suppressWarnings(suppressMessages({
    library(dplyr)
    library(tibble)
    library(tidyr)
    library(purrr)
    library(stringr)
  }))
  files <- c(
    "functions/analysis-phenotype-mca-prep.R",
    "functions/analysis-phenotype-missingness.R",
    "functions/analysis-phenotype-consolidation.R",
    "functions/analysis-phenotype-functions.R"
  )
  if (isTRUE(validation)) {
    files <- c(files, "functions/analysis-null-models.R", "functions/analysis-cluster-validation.R")
  }
  for (f in files) source_api_file(f, local = FALSE, envir = globalenv())

  had_hash <- exists("post_db_hash", envir = globalenv(), inherits = FALSE)
  old_hash <- if (had_hash) base::get("post_db_hash", envir = globalenv()) else NULL
  assign("post_db_hash", function(...) list(links = list(hash = "test-stub")), envir = globalenv())
  withr::defer({
    if (had_hash) {
      assign("post_db_hash", old_hash, envir = globalenv())
    } else if (exists("post_db_hash", envir = globalenv(), inherits = FALSE)) {
      rm("post_db_hash", envir = globalenv())
    }
  }, envir = env)
  invisible(TRUE)
}

#' Entity -> cluster label map from a gen_mca_clust_obj() tibble.
phenotype_membership_from_clusters <- function(clusters) {
  ids <- lapply(clusters$identifiers, function(d) as.character(d$entity_id))
  stats::setNames(rep(as.integer(as.character(clusters$cluster)), lengths(ids)), unlist(ids))
}
