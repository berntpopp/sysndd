# Parity of the application-owned phenotype procedure with FactoMineR::HCPC (#679).
#
# With the random starts switched off (n_starts = 0) the application procedure must
# be a drop-in replica of HCPC(nb.clust = k, kk = Inf, consol = TRUE): same labels for
# every entity and the same cluster descriptions. That is what licenses replacing the
# HCPC call, and it must hold on whichever FactoMineR is installed.

test_that("n_starts = 0 reproduces HCPC labels and descriptions at a fixed k", {
  testthat::skip_if_not_installed("FactoMineR")
  local_phenotype_clustering_runtime()
  withr::local_envvar(ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS = "0")

  df <- phenotype_synthetic_matrix()
  set.seed(42)
  mca <- FactoMineR::MCA(df, ncp = 8, quali.sup = 1, quanti.sup = 2:4, graph = FALSE)
  hc <- FactoMineR::HCPC(mca, nb.clust = 3, kk = Inf, min = 3, max = 25,
                         consol = TRUE, graph = FALSE)
  hcpc_labels <- stats::setNames(as.integer(as.character(hc$data.clust$clust)),
                                 rownames(hc$data.clust))

  res <- gen_mca_clust_obj(df, min_size = 1, quali_sup_var = 1:1, quanti_sup_var = 2:4,
                           cutpoint = 3)
  ours <- phenotype_membership_from_clusters(res)
  expect_setequal(names(ours), names(hcpc_labels))
  # identical LABELS, not merely the same partition: both number clusters by
  # ascending first-coordinate centroid.
  expect_identical(unname(ours[names(hcpc_labels)]), unname(hcpc_labels))

  # Descriptions: direct catdes on the same clusters equals HCPC's desc.var.
  data_clust <- cbind.data.frame(mca$call$X, clust = hc$data.clust$clust)
  desc <- phenotype_catdes(data_clust, row_w = mca$call$row.w.init)
  quanti_cols <- c("v.test", "Mean in category", "Overall mean", "sd in category",
                   "Overall sd", "p.value")
  for (cl in names(hc$desc.var$category)) {
    expect_equal(unname(desc$category[[cl]]), unname(hc$desc.var$category[[cl]]))
    expect_identical(colnames(desc$quanti[[cl]]), quanti_cols)
    expect_equal(unname(desc$quanti[[cl]]),
                 unname(hc$desc.var$quanti[[cl]][, quanti_cols, drop = FALSE]))
  }
})

test_that("the application k rule equals the HCPC 2.13 automatic cut", {
  testthat::skip_if_not_installed("FactoMineR")
  # Later FactoMineR releases changed HCPC's automatic cut; the application rule is
  # pinned to the documented one, so only compare where HCPC still implements it.
  testthat::skip_if(utils::packageVersion("FactoMineR") >= "2.14",
                    "HCPC auto-cut differs from the documented rule in this FactoMineR")
  local_phenotype_clustering_runtime()
  withr::local_envvar(ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS = "0")

  df <- phenotype_synthetic_matrix()
  set.seed(42)
  mca <- FactoMineR::MCA(df, ncp = 8, quali.sup = 1, quanti.sup = 2:4, graph = FALSE)
  hc <- FactoMineR::HCPC(mca, nb.clust = -1, kk = Inf, min = 3, max = 25,
                         consol = TRUE, graph = FALSE)
  res <- gen_mca_clust_obj(df, min_size = 1, quali_sup_var = 1:1, quanti_sup_var = 2:4,
                           cutpoint = -1)
  expect_identical(attr(res, "data_driven_k"), nlevels(hc$data.clust$clust))
  ours <- phenotype_membership_from_clusters(res)
  expect_identical(unname(ours[rownames(hc$data.clust)]),
                   as.integer(as.character(hc$data.clust$clust)))
})
