test_that("validate_phenotype_clusters: consistent k-curve + cross-axis footing (#509,#511)", {
  testthat::skip_if_not_installed("FactoMineR")
  suppressWarnings(suppressMessages({
    library(dplyr); library(tibble); library(tidyr); library(purrr); library(stringr)
  }))
  source_api_file("functions/analysis-null-models.R", local = FALSE, envir = globalenv())
  source_api_file("functions/analysis-phenotype-functions.R", local = FALSE, envir = globalenv())
  source_api_file("functions/analysis-cluster-validation.R", local = FALSE, envir = globalenv())

  # Stub the identifier-hash helper (unrelated to validation metrics).
  had_hash <- exists("post_db_hash", envir = globalenv())
  old_hash <- if (had_hash) get("post_db_hash", envir = globalenv())
  assign("post_db_hash", function(...) list(links = list(hash = "test-stub")), envir = globalenv())
  withr::defer({
    if (had_hash) assign("post_db_hash", old_hash, envir = globalenv())
    else if (exists("post_db_hash", envir = globalenv())) rm("post_db_hash", envir = globalenv())
  })
  # keep the null loops small + fast for the test
  withr::local_envvar(ANALYSIS_SILHOUETTE_NULL_N = "60", ANALYSIS_MODULARITY_NULL_N = "40",
                      ANALYSIS_PHENOTYPE_KNN_K = "8")

  set.seed(1)
  mk <- function(n, cols_on) {
    m <- matrix(NA_character_, n, 6, dimnames = list(NULL, paste0("HP_", 1:6)))
    for (col in cols_on) m[, col] <- "yes"
    as.data.frame(m, stringsAsFactors = FALSE)
  }
  hpo <- rbind(mk(28, c(1, 2, 3)), mk(29, c(4, 5, 6)), mk(5, c(1, 6)))
  n <- nrow(hpo)
  grp <- c(rep("A", 28), rep("B", 29), rep("C", 5))
  df <- data.frame(
    moi    = ifelse(grp == "A", "AD", ifelse(grp == "B", "AR", "XL")),
    count1 = as.numeric(ifelse(grp == "A", 8, ifelse(grp == "B", 2, 5)) + rpois(n, 1)),
    count2 = as.numeric(ifelse(grp == "A", 3, ifelse(grp == "B", 9, 6)) + rpois(n, 1)),
    count3 = as.numeric(ifelse(grp == "A", 6, ifelse(grp == "B", 6, 1)) + rpois(n, 1)),
    hpo, stringsAsFactors = FALSE, check.names = FALSE
  )
  rownames(df) <- as.character(seq_len(n))

  v <- validate_phenotype_clusters(df, quali_sup_var = 1:1, quanti_sup_var = 2:4,
                                   min_size = 10, n_resamples = 3L)
  p <- v$partition

  expect_identical(p$validation_schema_version, "2.0")
  expect_true(all(c("k_decision_curve", "silhouette_z", "silhouette_p_empirical",
                    "shared_modularity_z", "separation_z", "dip_statistic", "dip_p",
                    "silhouette_interpretation", "consolidation") %in% names(p)))
  # #509 anchor: the curve at the reported k equals the reported mean silhouette,
  # because it re-runs the exact served procedure (gen_mca_clust_obj) at that k.
  expect_equal(as.numeric(p$k_selection_curve[[as.character(p$k)]]),
               p$mean_silhouette, tolerance = 1e-6)
  # #511: separation footing on the phenotype axis = silhouette-z (not raw silhouette)
  expect_identical(p$separation_z, p$silhouette_z)
  expect_identical(p$null_model, "label_permutation")
  # Wave 1 keeps kk = 50 -> consolidation is honestly reported as disabled.
  expect_false(isTRUE(p$consolidation))
})
