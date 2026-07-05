test_that("validate_phenotype_clusters: consistent k-curve + cross-axis footing (#509,#511)", {
  testthat::skip_if_not_installed("FactoMineR")
  suppressWarnings(suppressMessages({
    library(dplyr); library(tibble); library(tidyr); library(purrr); library(stringr)
  }))
  source_api_file("functions/analysis-null-models.R", local = FALSE, envir = globalenv())
  source_api_file("functions/analysis-phenotype-mca-prep.R", local = FALSE, envir = globalenv())
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

  set.seed(7)
  # crisp two-block phenotype signature with separated supplementary counts, big
  # enough that both clusters clear min_size under the deterministic kk=Inf HCPC.
  mk <- function(n, cols_on) {
    m <- matrix(NA_character_, n, 6, dimnames = list(NULL, paste0("HP_", 1:6)))
    for (col in cols_on) m[, col] <- "yes"
    as.data.frame(m, stringsAsFactors = FALSE)
  }
  hpo <- rbind(mk(60, c(1, 2, 3)), mk(60, c(4, 5, 6)))
  n <- nrow(hpo)
  grp <- rep(c("A", "B"), each = 60)
  df <- data.frame(
    moi    = ifelse(grp == "A", "AD", "AR"),
    count1 = as.numeric(ifelse(grp == "A", 10, 1) + rpois(n, 1)),
    count2 = as.numeric(ifelse(grp == "B", 10, 1) + rpois(n, 1)),
    count3 = as.numeric(rpois(n, 2)),
    hpo, stringsAsFactors = FALSE, check.names = FALSE
  )
  rownames(df) <- as.character(seq_len(n))

  v <- validate_phenotype_clusters(df, quali_sup_var = 1:1, quanti_sup_var = 2:4,
                                   min_size = 10, n_resamples = 3L)
  p <- v$partition

  expect_identical(p$validation_schema_version, "2.0")
  expect_true(all(c("k_decision_curve", "silhouette_z", "silhouette_p_empirical",
                    "shared_modularity_z", "separation_z", "dip_statistic", "dip_p",
                    "silhouette_interpretation", "consolidation", "hcpc_nb_clust") %in% names(p)))
  # #509 anchor: the curve at the ACTUAL HCPC k (data-driven, pre-drop) equals the
  # reported mean silhouette, because it re-runs the exact served procedure there.
  # The fixture is engineered to yield exactly two clusters, so assert it hard — a
  # skip here would silently convert a clustering regression into a passing test.
  expect_gte(p$n_clusters, 2)
  expect_equal(as.numeric(p$k_selection_curve[[as.character(p$hcpc_nb_clust)]]),
               p$mean_silhouette, tolerance = 1e-6)
  # #511: separation footing on the phenotype axis = silhouette-z (not raw silhouette)
  expect_identical(p$separation_z, p$silhouette_z)
  expect_identical(p$null_model, "label_permutation")
  # kk = Inf -> real consolidation runs and is honestly reported.
  expect_true(isTRUE(p$consolidation))
  expect_identical(p$hcpc_kk, "Inf")
})
