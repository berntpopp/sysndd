analysis_snapshot_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())

test_that("snapshot presets canonicalize supported parameters", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)

  network <- analysis_snapshot_normalize_params(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = "400", max_edges = "10000")
  )
  expect_equal(network$analysis_type, "gene_network_edges")
  expect_equal(network$params$cluster_type, "clusters")
  expect_equal(network$params$min_confidence, 400L)
  expect_equal(network$params$max_edges, 10000L)
  expect_match(network$parameter_hash, "^[a-f0-9]{64}$")

  functional <- analysis_snapshot_normalize_params(
    "functional_clusters",
    list(algorithm = "leiden")
  )
  expect_equal(functional$params$algorithm, "leiden")
})

test_that("snapshot presets reject unsupported analysis parameters", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)

  expect_error(
    analysis_snapshot_normalize_params("functional_clusters", list(algorithm = "walktrap")),
    regexp = "supported public preset values",
    class = "analysis_snapshot_unsupported_parameter_error"
  )
  expect_error(
    analysis_snapshot_normalize_params(
      "gene_network_edges",
      list(cluster_type = "clusters", min_confidence = 700, max_edges = 10000)
    ),
    class = "analysis_snapshot_unsupported_parameter_error"
  )
  expect_error(
    analysis_snapshot_normalize_params("unknown_analysis", list()),
    class = "analysis_snapshot_unsupported_parameter_error"
  )
  expect_error(
    analysis_snapshot_normalize_params("phenotype_clusters", list("unexpected")),
    class = "analysis_snapshot_unsupported_parameter_error"
  )
})

test_that("snapshot presets define data_class for every public analysis type", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)

  presets <- analysis_snapshot_supported_presets()
  expect_true(all(vapply(presets, function(x) identical(x$data_class, "curated_derived_analysis"), logical(1))))
  expect_true(all(c(
    "functional_clusters",
    "phenotype_clusters",
    "phenotype_correlations",
    "phenotype_functional_correlations",
    "gene_network_edges"
  ) %in% vapply(presets, `[[`, character(1), "analysis_type")))
})
