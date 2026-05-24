if (!exists("network_layout_cache_key", mode = "function")) {
  source_api_file("functions/analysis-network-layout-functions.R", local = FALSE, envir = globalenv())
}

test_that("network layout key changes with max_edges and edge set", {
  network <- list(
    nodes = tibble::tibble(
      hgnc_id = c("HGNC:1", "HGNC:2"),
      symbol = c("AAA", "BBB"),
      cluster = c(1, 1),
      degree = c(1L, 1L),
      category = c("Definitive", "Definitive")
    ),
    edges = tibble::tibble(
      source = "HGNC:1",
      target = "HGNC:2",
      confidence = 0.99
    ),
    metadata = list(string_version = "11.5", min_confidence = 400)
  )

  key_100 <- network_layout_cache_key(
    network,
    cluster_type = "clusters",
    min_confidence = 400L,
    max_edges = 100L
  )
  key_200 <- network_layout_cache_key(
    network,
    cluster_type = "clusters",
    min_confidence = 400L,
    max_edges = 200L
  )

  network_changed <- network
  network_changed$edges$confidence <- 0.95
  key_changed <- network_layout_cache_key(
    network_changed,
    cluster_type = "clusters",
    min_confidence = 400L,
    max_edges = 100L
  )

  expect_type(key_100, "character")
  expect_equal(nchar(key_100), 64L)
  expect_false(identical(key_100, key_200))
  expect_false(identical(key_100, key_changed))
})

test_that("cytoscape layout input contains compound parents and gene node sizes", {
  network <- list(
    nodes = tibble::tibble(
      hgnc_id = c("HGNC:1", "HGNC:2"),
      symbol = c("AAA", "BBB"),
      cluster = c(1, 1),
      degree = c(4L, 1L),
      category = c("Definitive", "Moderate")
    ),
    edges = tibble::tibble(source = "HGNC:1", target = "HGNC:2", confidence = 0.8),
    metadata = list()
  )

  request <- build_network_fcose_layout_request(network, layout_key = "abc")
  ids <- vapply(request$elements, function(element) element$data$id, character(1))

  expect_true("cluster-1" %in% ids)
  expect_true("HGNC:1" %in% ids)
  gene <- request$elements[[which(ids == "HGNC:1")]]
  expect_equal(gene$data$parent, "cluster-1")
  expect_equal(gene$data$size, 15)
  expect_equal(request$layout_options$name, "fcose")
})

test_that("layout artifacts round trip through cache", {
  cache_dir <- withr::local_tempdir()
  artifact <- list(
    schema_version = 1L,
    layout_engine = "cytoscape-fcose",
    positions = list("HGNC:1" = list(x = 10, y = 20)),
    metadata = list(layout_key = "abc")
  )

  write_network_layout_artifact("abc", artifact, cache_dir = cache_dir)
  restored <- read_network_layout_artifact("abc", cache_dir = cache_dir)

  expect_equal(restored, artifact)
})

test_that("display positions attach only when complete", {
  network <- list(
    nodes = tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2"), x = c(1, 2), y = c(3, 4)),
    edges = tibble::tibble(),
    metadata = list(layout_algorithm = "drl")
  )
  artifact <- list(
    positions = list("HGNC:1" = list(x = 10, y = 20), "HGNC:2" = list(x = 30, y = 40)),
    metadata = list(layout_duration_ms = 10, node_count = 2L, edge_count = 0L)
  )

  updated <- attach_network_display_layout(network, artifact, layout_key = "abc")

  expect_equal(updated$nodes$x, c(10, 30))
  expect_equal(updated$nodes$y, c(20, 40))
  expect_equal(updated$nodes$layout_x, c(10, 30))
  expect_equal(updated$nodes$layout_y, c(20, 40))
  expect_equal(updated$nodes$igraph_x, c(1, 2))
  expect_equal(updated$nodes$igraph_y, c(3, 4))
  expect_equal(updated$metadata$display_layout_status, "available")
  expect_equal(updated$metadata$layout_engine, "cytoscape-fcose")
})

test_that("incomplete display positions are rejected", {
  artifact <- list(
    positions = list("HGNC:1" = list(x = 10, y = 20)),
    metadata = list()
  )

  expect_error(
    validate_network_layout_artifact(artifact, expected_gene_ids = c("HGNC:1", "HGNC:2")),
    "missing positions"
  )
})
