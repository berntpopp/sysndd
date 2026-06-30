test_that("gen_string_clust_obj passes STRING weights and converges", {
  src <- readLines(file.path(get_api_dir(), "functions", "analyses-functions.R"))
  body <- paste(src, collapse = "\n")
  # weighted modularity on combined_score
  expect_match(body, "weights\\s*=\\s*igraph::E\\(subgraph\\)\\$combined_score", fixed = FALSE)
  # converge instead of n_iterations = 2
  expect_match(body, "n_iterations\\s*=\\s*-1", fixed = FALSE)
  expect_false(grepl("n_iterations\\s*=\\s*2", body))
  # resolution is an explicit argument, not a hardcoded literal
  expect_match(body, "resolution\\s*=\\s*1\\.0", fixed = FALSE)              # signature default
  expect_match(body, "resolution_parameter\\s*=\\s*resolution", fixed = FALSE)
  expect_match(body, "cluster_signature")                                   # degree-based identity (Step 5)
})

test_that("igraph 2.3.1 accepts n_iterations = -1 (iterate to stable)", {
  # Codex flagged that -1 is documented in the igraph C docs but not the R help page;
  # this behavioral regression proves the installed igraph 2.3.1 accepts it.
  g <- igraph::make_graph(~ a-b, b-c, c-a, d-e, e-f, f-d)   # two triangles
  igraph::E(g)$combined_score <- 900
  expect_silent(cl <- igraph::cluster_leiden(
    g, objective_function = "modularity", weights = igraph::E(g)$combined_score,
    resolution_parameter = 1.0, beta = 0.01, n_iterations = -1))
  expect_gte(length(unique(cl$membership)), 2L)
})
