test_that("validate_phenotype_clusters: consistent k-curve + cross-axis footing (#509,#511)", {
  testthat::skip_if_not_installed("FactoMineR")
  local_phenotype_clustering_runtime(validation = TRUE)
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

  expect_identical(p$validation_schema_version, "2.1")
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
  # #679: the procedure, the ACTUAL k selector curve and the optimisation landscape
  # are served, and the released solution is never worse than the Ward-cut start.
  expect_true(all(c("procedure_version", "k_rule", "k_ward_ratio_curve",
                    "consolidation_landscape", "factominer_version") %in% names(p)))
  expect_identical(p$procedure_version, PHENOTYPE_PROCEDURE_VERSION)
  expect_identical(p$k_rule, "ward_within_inertia_ratio_min")
  expect_true(is.list(p$k_ward_ratio_curve) && length(p$k_ward_ratio_curve) >= 1L)
  # how contested k itself was travels with the partition
  expect_true(all(c("k", "ratio", "runner_up_k", "runner_up_ratio", "margin") %in%
                    names(p$k_selection)))
  expect_false("k_selection" %in% names(p$consolidation_landscape))
  ls <- p$consolidation_landscape
  expect_gte(ls$n_starts_total, 1L)
  expect_lte(ls$chosen$within_inertia, ls$ward_start$within_inertia + 1e-12)
  expect_identical(p$factominer_version, as.character(utils::packageVersion("FactoMineR")))
  # The 1/Q ncp diagnostic comes from a full-spectrum MCA, so it does not depend on
  # how many eigenvalues the clustering MCA happens to return.
  expect_true(is.finite(p$ncp_recommended_1overq))
  expect_true(is.finite(p$adjusted_inertia))
  # kk = Inf -> real consolidation runs and is honestly reported.
  expect_true(isTRUE(p$consolidation))
  expect_identical(p$hcpc_kk, "Inf")
})
