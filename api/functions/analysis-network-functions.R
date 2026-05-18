# functions/analysis-network-functions.R
#### Network analysis response helpers

limit_network_edges_response <- function(network_data, max_edges = 10000L) {
  if (is.null(network_data$edges)) {
    network_data$edges <- tibble::tibble(source = character(), target = character(), confidence = numeric())
  }
  if (is.null(network_data$nodes)) {
    network_data$nodes <- tibble::tibble()
  }
  if (is.null(network_data$metadata)) {
    network_data$metadata <- list()
  }

  total_edges <- nrow(network_data$edges)

  if (max_edges > 0L && nrow(network_data$edges) > max_edges) {
    network_data$edges <- network_data$edges[order(-network_data$edges$confidence), ]
    network_data$edges <- utils::head(network_data$edges, max_edges)

    connected_nodes <- unique(c(network_data$edges$source, network_data$edges$target))
    if ("hgnc_id" %in% names(network_data$nodes)) {
      network_data$nodes <- network_data$nodes[network_data$nodes$hgnc_id %in% connected_nodes, ]
    }

    if ("category" %in% names(network_data$nodes)) {
      category_counts <- network_data$nodes %>%
        dplyr::group_by(category) %>%
        dplyr::summarise(count = dplyr::n(), .groups = "drop") %>%
        tidyr::pivot_wider(names_from = category, values_from = count, values_fill = 0) %>%
        as.list()
      network_data$metadata$category_counts <- category_counts
    }

    network_data$metadata$node_count <- nrow(network_data$nodes)
    network_data$metadata$edge_count <- nrow(network_data$edges)
    network_data$metadata$total_edges <- total_edges
    network_data$metadata$edges_filtered <- TRUE
  } else {
    network_data$metadata$total_edges <- total_edges
    network_data$metadata$edges_filtered <- FALSE
  }

  network_data
}


generate_network_edges_response <- function(cluster_type = "clusters",
                                            min_confidence = 400L,
                                            max_edges = 10000L) {
  start_time <- Sys.time()

  network_data <- gen_network_edges_mem(
    cluster_type = cluster_type,
    min_confidence = min_confidence
  )

  network_data <- limit_network_edges_response(network_data, max_edges = max_edges)
  elapsed_seconds <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  network_data$metadata$elapsed_seconds <- round(elapsed_seconds, 2)

  gc(verbose = FALSE)
  network_data
}


#' Extract Network Edges from STRINGdb for Cytoscape.js Visualization
#'
#' Returns protein-protein interaction network data in a format suitable for
#' Cytoscape.js visualization. Includes nodes with gene identifiers and cluster
#' membership, plus edges with STRING confidence scores.
#'
#' @param cluster_type Type of clusters to use: "clusters" or "subclusters"
#' @param min_confidence Minimum STRING confidence score (0-1000, default 400)
#' @param string_id_table Pre-fetched STRING ID table (for daemon context)
#'
#' @return List with nodes, edges, and metadata:
#'   - nodes: tibble with hgnc_id, symbol, cluster, degree
#'   - edges: tibble with source, target, confidence
#'   - metadata: list with node_count, edge_count, cluster_count, string_version, min_confidence
#' @export
gen_network_edges <- function(
  cluster_type = "clusters",
  min_confidence = 400,
  string_id_table = NULL
) {
  # Version constants for cache invalidation
  string_version <- "11.5" # Must match STRINGdb$new version below
  cache_version <- Sys.getenv("CACHE_VERSION", "1")

  # Get all NDD genes for clustering
  # If string_id_table is provided (for daemon context), use it; otherwise fetch from pool
  if (!is.null(string_id_table)) {
    sysndd_db_string_id_table <- string_id_table
  } else {
    sysndd_db_string_id_table <- pool %>%
      tbl("non_alt_loci_set") %>%
      filter(!is.na(STRING_id)) %>%
      select(symbol, hgnc_id, STRING_id) %>%
      collect()
  }

  # Get NDD genes from entity view
  genes_from_entity_table <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id) %>%
    collect() %>%
    unique()

  # Get category for each gene (use highest confidence category per gene)
  # Order: Definitive > Moderate > Limited > Refuted
  gene_categories <- pool %>%
    tbl("ndd_entity_view") %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id, category) %>%
    distinct() %>%
    collect() %>%
    group_by(hgnc_id) %>%
    summarise(
      category = select_network_gene_category(category),
      .groups = "drop"
    ) %>%
    ungroup()

  # Get clusters using existing function
  functional_clusters <- gen_string_clust_obj_mem(
    genes_from_entity_table$hgnc_id,
    algorithm = "leiden",
    string_id_table = sysndd_db_string_id_table
  )

  # Build cluster map (hgnc_id -> cluster number)
  # Use clusters or subclusters based on parameter
  if (cluster_type == "subclusters") {
    # Flatten subclusters
    cluster_map <- functional_clusters %>%
      select(cluster, subclusters) %>%
      unnest(cols = c(subclusters)) %>%
      rename(parent_cluster = cluster, cluster = cluster.1) %>%
      select(parent_cluster, cluster, identifiers) %>%
      unnest(cols = c(identifiers)) %>%
      select(hgnc_id, cluster = parent_cluster, subcluster = cluster) %>%
      # Create combined cluster ID for subclusters
      mutate(cluster_id = paste0(cluster, ".", subcluster)) %>%
      select(hgnc_id, cluster = cluster_id)
  } else {
    # Use main clusters
    cluster_map <- functional_clusters %>%
      select(cluster, identifiers) %>%
      unnest(cols = c(identifiers)) %>%
      select(hgnc_id, cluster)
  }

  # Get unique HGNC IDs with their STRING IDs
  gene_table <- sysndd_db_string_id_table %>%
    filter(hgnc_id %in% cluster_map$hgnc_id)

  # Get cached STRINGdb instance (singleton avoids repeated version API calls)
  string_db <- get_string_db(min_confidence)

  # Get STRING graph
  string_graph <- string_db$get_graph()

  # Filter to input gene set
  genes_in_graph <- intersect(
    igraph::V(string_graph)$name,
    gene_table$STRING_id
  )

  # Create subgraph with only input genes
  subgraph <- igraph::induced_subgraph(
    string_graph,
    vids = which(igraph::V(string_graph)$name %in% genes_in_graph)
  )

  # Build STRING ID to HGNC ID mapping
  # Use distinct() and group_by to handle cases where multiple HGNC IDs map to same STRING ID
  # Pick the first (alphabetically) HGNC ID for each STRING ID to ensure 1:1 mapping
  string_to_hgnc <- gene_table %>%
    select(STRING_id, hgnc_id, symbol) %>%
    distinct() %>%
    group_by(STRING_id) %>%
    arrange(hgnc_id) %>%
    slice_head(n = 1) %>%
    ungroup()

  # Calculate node degrees
  node_degrees <- igraph::degree(subgraph)

  # Build nodes tibble
  nodes <- tibble(
    STRING_id = names(node_degrees),
    degree = as.integer(node_degrees)
  ) %>%
    left_join(string_to_hgnc, by = "STRING_id") %>%
    left_join(cluster_map, by = "hgnc_id") %>%
    select(hgnc_id, symbol, cluster, degree) %>%
    filter(!is.na(hgnc_id)) %>%
    distinct()

  # Get edge list from subgraph
  edge_list <- igraph::as_edgelist(subgraph)

  # Get edge attributes (combined_score)
  edge_scores <- igraph::E(subgraph)$combined_score

  # Build edges tibble
  if (nrow(edge_list) > 0) {
    # Create lookup table for STRING to HGNC mapping
    string_hgnc_lookup <- string_to_hgnc %>%
      select(STRING_id, hgnc_id)

    edges <- tibble(
      source_string = edge_list[, 1],
      target_string = edge_list[, 2],
      combined_score = edge_scores
    ) %>%
      # Map STRING IDs to HGNC IDs using the deduplicated lookup
      left_join(
        string_hgnc_lookup,
        by = c("source_string" = "STRING_id")
      ) %>%
      rename(source = hgnc_id) %>%
      left_join(
        string_hgnc_lookup,
        by = c("target_string" = "STRING_id")
      ) %>%
      rename(target = hgnc_id) %>%
      # Normalize confidence to 0-1 range
      mutate(confidence = combined_score / 1000) %>%
      select(source, target, confidence) %>%
      filter(!is.na(source) & !is.na(target)) %>%
      distinct() # Remove any duplicate edges
  } else {
    edges <- tibble(
      source = character(),
      target = character(),
      confidence = numeric()
    )
  }

  # Count unique clusters
  cluster_count <- length(unique(nodes$cluster[!is.na(nodes$cluster)]))

  # PRE-COMPUTE LAYOUT POSITIONS SERVER-SIDE
  # Using igraph's layout algorithms (fast, good quality)
  # This is cached via gen_network_edges_mem, so only computed once
  message(paste0("[gen_network_edges] Computing layout for ", nrow(nodes), " nodes..."))
  layout_start <- Sys.time()

  # Adaptive layout algorithm selection based on graph size
  # - DrL for large graphs (>1000 nodes): Designed for large-scale networks
  # - FR with grid for medium graphs (500-1000): Faster but less accurate
  # - Standard FR for small graphs (<500): Best quality, current behavior
  # See: https://r.igraph.org/reference/layout_nicely.html
  node_count <- nrow(nodes)

  if (node_count > 1000) {
    # DrL for large graphs - designed for large-scale networks
    # Does not use edge weights (DrL implementation limitation)
    message(sprintf("[gen_network_edges] Using DrL layout for %d nodes (large graph)", node_count))
    layout_matrix <- igraph::layout_with_drl(subgraph)
    layout_algo <- "drl"
  } else if (node_count > 500) {
    # FR with grid optimization for medium graphs
    # Grid-based version is faster but less accurate
    message(sprintf("[gen_network_edges] Using FR-grid layout for %d nodes (medium graph)", node_count))
    layout_matrix <- igraph::layout_with_fr(
      subgraph,
      niter = 300,  # Reduced iterations for speed
      grid = "grid",
      weights = igraph::E(subgraph)$combined_score / 1000
    )
    layout_algo <- "fruchterman_reingold_grid"
  } else {
    # Standard FR for small graphs - best quality, current behavior preserved
    message(sprintf("[gen_network_edges] Using FR layout for %d nodes (small graph)", node_count))
    layout_matrix <- igraph::layout_with_fr(
      subgraph,
      niter = 500,
      weights = igraph::E(subgraph)$combined_score / 1000
    )
    layout_algo <- "fruchterman_reingold"
  }

  layout_time <- as.numeric(difftime(Sys.time(), layout_start, units = "secs"))
  message(paste0("[gen_network_edges] Layout computed in ", round(layout_time, 2), "s"))

  # Normalize layout to 0-1000 range for consistent client rendering
  x_range <- range(layout_matrix[, 1])
  y_range <- range(layout_matrix[, 2])
  layout_normalized <- data.frame(
    STRING_id = names(node_degrees),
    x = round((layout_matrix[, 1] - x_range[1]) / (x_range[2] - x_range[1]) * 1000),
    y = round((layout_matrix[, 2] - y_range[1]) / (y_range[2] - y_range[1]) * 1000)
  )

  # Add positions and category to nodes
  nodes <- nodes %>%
    left_join(
      string_to_hgnc %>% select(STRING_id, hgnc_id),
      by = "hgnc_id"
    ) %>%
    left_join(layout_normalized, by = "STRING_id") %>%
    left_join(gene_categories, by = "hgnc_id") %>%
    select(hgnc_id, symbol, cluster, degree, category, x, y) %>%
    distinct()

  # Count genes by category for metadata
  category_counts <- nodes %>%
    group_by(category) %>%
    summarise(count = n()) %>%
    tidyr::pivot_wider(names_from = category, values_from = count, values_fill = 0) %>%
    as.list()

  # Build metadata
  metadata <- list(
    node_count = nrow(nodes),
    edge_count = nrow(edges),
    cluster_count = cluster_count,
    string_version = string_version,
    min_confidence = min_confidence,
    layout_algorithm = layout_algo,
    layout_time_seconds = round(layout_time, 2),
    # Add total NDD genes and genes with STRING data for UI display
    total_ndd_genes = nrow(genes_from_entity_table),
    genes_with_string = nrow(gene_table),
    genes_in_clusters = nrow(cluster_map),
    # Category breakdown
    category_counts = category_counts
  )

  message(paste0("[gen_network_edges] Returning ", nrow(nodes), " nodes, ", nrow(edges), " edges"))

  # Build result before cleanup
  result <- list(
    nodes = nodes,
    edges = edges,
    metadata = metadata
  )

  # Memory cleanup: remove large intermediate objects
  # STRING graph and igraph objects consume significant memory during computation
  rm(string_graph, subgraph, edge_list, layout_matrix, layout_normalized)
  rm(string_to_hgnc, gene_table, cluster_map, node_degrees)
  gc(verbose = FALSE)

  # Return structured result
  result
}


# Note: gen_network_edges_mem is defined in start_sysndd_api.R
# using in-memory cache (cachem::cache_mem) for consistency with other memoized functions
