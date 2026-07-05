source_api_file("functions/analysis-null-models.R", local = FALSE, envir = globalenv())
source_api_file("functions/analysis-cluster-validation.R", local = FALSE, envir = globalenv())

# Synthetic two-community weighted graph with a `combined_score` edge attribute,
# plus a couple of isolates and a disconnected pair, so giant-component reporting
# has something to count. Stubs build_string_subgraph so no STRING/DB is needed.
make_two_community_string_graph <- function() {
  g <- igraph::disjoint_union(igraph::make_full_graph(12), igraph::make_full_graph(12))
  g <- igraph::add_edges(g, c(1, 13)) # single bridge -> one connected component of 24
  g <- igraph::add_vertices(g, 4) # v25, v26 stay isolates; v27-v28 become a fragment
  g <- igraph::add_edges(g, c(27, 28)) # a disconnected 2-node fragment
  igraph::V(g)$name <- paste0("HGNC:", seq_len(igraph::vcount(g)))
  igraph::E(g)$combined_score <- 800
  g
}

test_that("validate_functional_clusters reports modularity-z + giant component (#510)", {
  g <- make_two_community_string_graph()
  build_string_subgraph <<- function(hgnc_list, score_threshold = 400, string_id_table = NULL) g
  on.exit(rm(build_string_subgraph, envir = globalenv()), add = TRUE)

  v <- validate_functional_clusters(igraph::V(g)$name, n_resamples = 3L, min_size = 3L)
  p <- v$partition

  expect_identical(p$validation_schema_version, "2.0")
  expect_true(all(c("modularity_z", "modularity_p_empirical", "giant_component",
                    "dip_statistic", "dip_p", "separation_z", "null_model") %in% names(p)))
  expect_identical(p$separation_z, p$modularity_z)
  expect_identical(p$null_model, "degree_preserving_configuration")

  gc <- p$giant_component
  expect_true(all(c("n_nodes", "n_edges", "n_isolates", "n_components",
                    "node_retention", "edge_retention") %in% names(gc)))
  expect_equal(gc$n_isolates, 2L) # the two added isolates
  expect_gte(gc$n_components, 3L) # main + fragment + isolates
  expect_equal(gc$n_nodes, 24L) # largest component = the two bridged cliques

  # planted two-clique structure should separate strongly vs the degree-matched null
  expect_gt(p$modularity_z, 2)
  expect_true(p$modularity_p_empirical > 0 && p$modularity_p_empirical <= 1)
})
