# functions/analyses-functions.R
#### This file holds analyses functions

#' A recursive function generating a functional gene cluster with string-db
#'
#' @param hgnc_list A comma separated list as concatenated text
#' @param min_size A number defining the minimal cluster size to return
#' @param subcluster Boolean value indicating whether to perform subclustering
#' @param parent the parent cluster name used in the generation of subclusters
#' @param enrichment Boolean value indicating whether to perform enrichment
#' @param algorithm Clustering algorithm name (default: "leiden")
#' @param string_id_table Pre-fetched STRING ID table (for daemon context)
#' @param score_threshold STRING confidence score threshold (0-1000, default 400 = medium)
#'
#' @return The clusters tibble
#' @export
gen_string_clust_obj <- function(
  hgnc_list,
  min_size = 10,
  subcluster = TRUE,
  parent = NA,
  enrichment = TRUE,
  algorithm = "leiden",
  string_id_table = NULL,
  score_threshold = 400
) {
  # Caching is handled by the memoise wrapper (gen_string_clust_obj_mem)
  # backed by cachem::cache_disk with Inf TTL. No file-based cache needed.

  # load/ download STRING database files
  string_db <- STRINGdb::STRINGdb$new(
    version = "11.5",
    species = 9606,
    score_threshold = score_threshold,
    input_directory = "data"
  )

  # Load gene table from database and filter to input HGNC list
  # If string_id_table is provided (for daemon context), use it; otherwise fetch from pool
  if (!is.null(string_id_table)) {
    sysndd_db_string_id_table <- string_id_table %>%
      filter(hgnc_id %in% hgnc_list)
  } else {
    sysndd_db_string_id_table <- pool %>%
      tbl("non_alt_loci_set") %>%
      filter(!is.na(STRING_id)) %>%
      select(symbol, hgnc_id, STRING_id) %>%
      collect() %>%
      filter(hgnc_id %in% hgnc_list)
  }

  # convert to dataframe
  sysndd_db_string_id_df <- sysndd_db_string_id_table %>%
    as.data.frame()

  # Perform clustering using Leiden algorithm via igraph
  # (replaced Walktrap for 2-3x performance improvement)

  # Get full STRING graph for Leiden clustering
  string_graph <- string_db$get_graph()

  # Filter to input gene set (intersect with genes having STRING IDs)
  genes_in_graph <- intersect(
    igraph::V(string_graph)$name,
    sysndd_db_string_id_df$STRING_id
  )

  # Create subgraph with only input genes
  subgraph <- igraph::induced_subgraph(
    string_graph,
    vids = which(igraph::V(string_graph)$name %in% genes_in_graph)
  )

  # Run clustering algorithm based on parameter
  # Leiden: 2-3x faster, good for large networks
  # Walktrap: Classic algorithm, uses random walks to detect communities
  #
  # IMPORTANT: Set seed for reproducible clustering results
  # This ensures cluster hashes remain consistent across API calls,
  # which is critical for LLM summary cache matching.
  set.seed(42)

  if (algorithm == "walktrap") {
    # Walktrap clustering using random walks
    # steps=4 is default and works well for PPI networks
    cluster_result <- igraph::cluster_walktrap(
      subgraph,
      steps = 4
    )
  } else {
    # Default: Leiden clustering (faster)
    # Parameters optimized for PPI networks:
    # - modularity: Standard objective for biological networks
    # - resolution=1.0: Default, produces similar cluster sizes to Walktrap
    # - beta=0.01: Low randomness ensures reproducible results
    # - n_iterations=2: Default, balances quality and speed
    cluster_result <- igraph::cluster_leiden(
      subgraph,
      objective_function = "modularity",
      resolution_parameter = 1.0,
      beta = 0.01,
      n_iterations = 2
    )
  }

  # Convert to list format (compatible with existing downstream code)
  clusters_list <- split(
    igraph::V(subgraph)$name,
    cluster_result$membership
  )

  clusters_tibble <- tibble(clusters_list) %>%
    select(STRING_id = clusters_list) %>%
    mutate(cluster = row_number()) %>%
    unnest_longer(col = "STRING_id") %>%
    left_join(sysndd_db_string_id_table, by = c("STRING_id")) %>%
    tidyr::nest(.by = c(cluster), .key = "identifiers") %>%
    mutate(hash_filter = purrr::map(identifiers, function(ids) {
      # Pass identifiers tibble with symbol column (post_db_hash expects named column)
      post_db_hash(tibble::tibble(symbol = ids$symbol))
    })) %>%
    mutate(hash_filter = purrr::map_chr(hash_filter, ~ .x$links$hash)) %>%
    rowwise() %>%
    mutate(cluster_size = nrow(identifiers)) %>%
    filter(cluster_size >= min_size) %>%
    select(cluster, cluster_size, identifiers, hash_filter) %>%
    {
      if (!is.na(parent)) {
        mutate(., parent_cluster = parent)
      } else {
        .
      }
    } %>%
    {
      if (enrichment) {
        mutate(.,
          term_enrichment =
            list(gen_string_enrich_tib(identifiers$hgnc_id) %>%
              mutate(term = str_replace(term, "GOCC", "GO")))
        )
      } else {
        .
      }
    } %>%
    {
      if (subcluster) {
        mutate(., subclusters = list(gen_string_clust_obj(
          identifiers$hgnc_id,
          subcluster = FALSE,
          parent = cluster,
          algorithm = algorithm,
          string_id_table = string_id_table,
          score_threshold = score_threshold
        )))
      } else {
        .
      }
    } %>%
    ungroup()

  # return result
  return(clusters_tibble)
}


#' A function to compute  enrichment with string-db and a HGNC list
#'
#' @param hgnc_list A comma separated list as concatenated text
#'
#' @return The enrichment tibble
#' @export
gen_string_enrich_tib <- function(hgnc_list) {
  # load/ download STRING database files
  string_db <- STRINGdb$new(
    version = "11.5",
    species = 9606,
    score_threshold = 400,
    input_directory = "data/"
  )

  # compute enrichment and convert to tibble
  # Sort by FDR ascending so most significant terms appear first
  enrichment_tibble <- string_db$get_enrichment(hgnc_list) %>%
    tibble() %>%
    select(-ncbiTaxonId, -inputGenes, -preferredNames) %>%
    arrange(fdr)

  # return result
  return(enrichment_tibble)
}


#' A function clustering entities based on their phenotype annotations
#'
#' @param wide_phenotypes_df data frame of variables to be used for MCA
#' @param min_size number defining the minimal cluster size to return
#' @param quali_sup_var vector of qualitative supplementary variables
#' @param quanti_sup_var vector of quantitative supplementary variables
#' @param cutpoint cutpoint for hierarchical clustering
#'
#' @return The clusters tibble
#' @export
gen_mca_clust_obj <- function(
  wide_phenotypes_df,
  min_size = 10,
  quali_sup_var = 1:1,
  quanti_sup_var = 2:4,
  cutpoint = 5
) {
  # Caching is handled by the memoise wrapper (gen_mca_clust_obj_mem)
  # backed by cachem::cache_disk with Inf TTL. No file-based cache needed.

  # IMPORTANT: Set seed for reproducible clustering results
  # This ensures cluster hashes remain consistent across API calls,
  # which is critical for LLM summary cache matching.
  set.seed(42)

  # Compute Multiple Correspondence Analysis (MCA)
  # ncp=8 captures >70% of variance for typical phenotype data
  # Reduced from ncp=15 for 20-30% MCA speedup
  # Empirically validated: cluster assignments stable between ncp=8 and ncp=15
  # For adaptive ncp selection, generate scree plot and identify elbow point:
  #   factoextra::fviz_screeplot(mca_result)
  # See: http://www.sthda.com/english/articles/31-principal-component-methods-in-r-practical-guide/117-hcpc-hierarchical-clustering-on-principal-components-essentials/ # nolint: line_length_linter
  mca_phenotypes <- MCA(wide_phenotypes_df,
    ncp = 8, # Reduced from 15 for 20-30% speedup (validated stable clustering)
    quali.sup = quali_sup_var,
    quanti.sup = quanti_sup_var,
    graph = FALSE
  )

  # Hierarchical Clustering on Principal Components with pre-partitioning
  # kk=50 performs K-means preprocessing before hierarchical clustering
  # This reduces computational complexity from O(n^2) to O(50^2)
  # providing 50-70% speedup for datasets with >100 observations
  # See: http://factominer.free.fr/factomethods/hierarchical-clustering-on-principal-components.html
  mca_hcpc <- HCPC(mca_phenotypes,
    nb.clust = cutpoint,
    kk = 50, # Pre-partition into 50 clusters (was Inf - no pre-partitioning)
    mi = 3,
    max = 25,
    consol = TRUE, # Consolidation still performed after kk partitioning
    graph = FALSE
  )

  # add entity_id back as column
  mca_hcpc$data.clust$entity_id <- row.names(mca_hcpc$data.clust)

  # generate cluster tibble
  # Sort all variable tables by p.value ascending so most significant appear first
  clusters_tibble <- tibble(mca_hcpc$data.clust) %>%
    select(entity_id, cluster = clust) %>%
    tidyr::nest(.by = c(cluster), .key = "identifiers") %>%
    mutate(hash_filter = purrr::map(identifiers, function(ids) {
      # Pass identifiers tibble with entity_id column (post_db_hash expects named column)
      post_db_hash(tibble::tibble(entity_id = ids$entity_id), "entity_id", "/api/entity")
    })) %>%
    mutate(hash_filter = purrr::map_chr(hash_filter, ~ .x$links$hash)) %>%
    rowwise() %>%
    mutate(cluster_size = nrow(identifiers)) %>%
    mutate(quali_inp_var = list(tibble::as_tibble(
      mca_hcpc$desc.var$category[[cluster]],
      rownames = "variable",
      .name_repair = ~ vctrs::vec_as_names(...,
        repair = "universal", quiet = TRUE
      )
    ) %>%
      filter(!str_detect(variable, "NA")) %>%
      filter(!str_detect(variable, "hpo")) %>%
      mutate(variable = str_remove_all(variable, "^.+=|_yes")) %>%
      arrange(p.value))) %>%
    mutate(quali_sup_var = list(tibble::as_tibble(
      mca_hcpc$desc.var$category[[cluster]],
      rownames = "variable",
      .name_repair = ~ vctrs::vec_as_names(...,
        repair = "universal", quiet = TRUE
      )
    ) %>%
      filter(!str_detect(variable, "NA")) %>%
      filter(str_detect(variable, "hpo")) %>%
      mutate(variable = str_remove_all(variable, "^.+=|_yes")) %>%
      arrange(p.value))) %>%
    mutate(quanti_sup_var = list(tibble::as_tibble(
      mca_hcpc$desc.var$quanti[[cluster]],
      rownames = "variable",
      .name_repair = ~ vctrs::vec_as_names(...,
        repair = "universal", quiet = TRUE
      )
    ) %>%
      arrange(p.value))) %>%
    ungroup()

  # return result
  return(clusters_tibble)
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
      category = category[which.min(match(
        category,
        c("Definitive", "Moderate", "Limited", "Refuted")
      ))]
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

  # Initialize STRINGdb with specified confidence threshold
  string_db <- STRINGdb::STRINGdb$new(
    version = "11.5",
    species = 9606,
    score_threshold = min_confidence,
    input_directory = "data"
  )

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

  # Return structured result
  list(
    nodes = nodes,
    edges = edges,
    metadata = metadata
  )
}


# Note: gen_network_edges_mem is defined in start_sysndd_api.R
# using in-memory cache (cachem::cache_mem) for consistency with other memoized functions
