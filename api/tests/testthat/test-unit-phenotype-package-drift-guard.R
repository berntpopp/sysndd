# Package-drift guard for the phenotype clustering path (#679).
#
# FactoMineR changed HCPC's automatic k rule between releases: on THIS input 2.13
# selects k = 3 and 2.17 selects k = 8 from identical MCA coordinates, so a routine
# dependency refresh would have silently changed the released partition. The
# application now owns k and the consolidation, and FactoMineR supplies only MCA
# coordinates and cluster descriptions. This test pins what those two still
# contribute: it must stay green, unchanged, across a FactoMineR (or R) update. If it
# goes red after a dependency bump, the released partition would change -- treat that
# as a membership change (CLUSTER_LOGIC_VERSION + the deploy runbook), not as a test
# to re-record.
#
# Reference values recorded under FactoMineR 2.13 and verified identical under 2.17.

test_that("MCA coordinates, k, the consolidated partition and the served shapes are pinned", {
  testthat::skip_if_not_installed("FactoMineR")
  local_phenotype_clustering_runtime()
  withr::local_envvar(ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS = "100")

  df <- phenotype_synthetic_matrix()
  set.seed(42)
  mca <- FactoMineR::MCA(df, ncp = 8, quali.sup = 1, quanti.sup = 2:4, graph = FALSE)
  # Absolute values: the sign of a singular vector is not defined, and is allowed to
  # flip between LAPACK builds or SVD back ends without changing any distance.
  expect_equal(sum(abs(mca$ind$coord)), 849.100172951949, tolerance = 1e-9)
  expect_equal(unname(abs(mca$ind$coord[1:5, 1])),
               c(0.211107853271, 0.629753580319, 0.263135083788, 0.701458755589,
                 0.226010885132), tolerance = 1e-9)

  res <- gen_mca_clust_obj(df, min_size = 10, quali_sup_var = 1:1, quanti_sup_var = 2:4)
  expect_identical(attr(res, "data_driven_k"), 3L)
  sizes <- stats::setNames(res$cluster_size, as.character(res$cluster))
  expect_identical(sizes[c("1", "2", "3")], c(`1` = 187L, `2` = 99L, `3` = 114L))
  expect_equal(attr(res, "consolidation")$within_inertia, 0.607768565435, tolerance = 1e-9)

  # Served description shapes do not depend on the package version.
  expect_identical(names(res$quanti_sup_var[[1]]),
                   c("variable", "v.test", "Mean.in.category", "Overall.mean",
                     "sd.in.category", "Overall.sd", "p.value"))
  by_cluster <- stats::setNames(res$cluster_signature, as.character(res$cluster))
  expect_identical(
    by_cluster[["1"]],
    "HP term 5_present|HP term 5_absent|HP term 2_absent|HP term 2_present|HP term 4_absent"
  )
})
