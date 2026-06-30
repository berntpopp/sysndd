# functions/analyses-functions.R
#### This file holds analyses functions

## -------------------------------------------------------------------##
# STRINGdb singleton cache
## -------------------------------------------------------------------##
# Cache STRINGdb objects by score_threshold to avoid repeated version API calls.
# STRINGdb$new() checks string-db.org/api/version on every call - expensive!
# This singleton ensures we only initialize once per threshold value per R process.
# Works in both main API process and mirai daemon workers.
string_db_cache <- new.env(parent = emptyenv())

#' Get cached STRINGdb instance
#'
#' Returns a cached STRINGdb object for the given score_threshold.
#' Creates and caches a new instance if not already cached.
#' Avoids repeated version API calls to string-db.org.
#'
#' @param score_threshold INTEGER. STRING confidence threshold (0-1000, default 400)
#' @return STRINGdb object
#' @export
get_string_db <- function(score_threshold = 400L) {
  cache_key <- as.character(score_threshold)

  # base:: namespacing guards against loaded packages masking base exists/get.
  if (!base::exists(cache_key, envir = string_db_cache)) {
    message(sprintf("[STRING] Initializing STRINGdb singleton (threshold=%d)...", score_threshold))
    string_db_cache[[cache_key]] <- STRINGdb::STRINGdb$new(
      version = "11.5",
      species = 9606,
      score_threshold = score_threshold,
      input_directory = "data"
    )
    message(sprintf("[STRING] STRINGdb singleton ready (threshold=%d)", score_threshold))
  }

  string_db_cache[[cache_key]]
}

## -------------------------------------------------------------------##
# Analysis Functions
## -------------------------------------------------------------------##

#' Select the highest-priority category for a network gene
#'
#' @param categories Character vector of category values for one HGNC ID
#' @return One category value, or NA_character_ if no known category is present
#' @export
select_network_gene_category <- function(categories) {
  category_priority <- c("Definitive", "Moderate", "Limited", "Refuted")
  category_ranks <- match(categories, category_priority)

  if (all(is.na(category_ranks))) {
    return(NA_character_)
  }

  categories[which.min(category_ranks)]
}

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
  resolution = 1.0,
  subcluster = TRUE,
  parent = NA,
  enrichment = TRUE,
  algorithm = "leiden",
  string_id_table = NULL,
  score_threshold = 400
) {
  # Caching is handled by the memoise wrapper (gen_string_clust_obj_mem)
  # backed by cachem::cache_disk with Inf TTL. No file-based cache needed.

  # Get cached STRINGdb instance (singleton avoids repeated version API calls)
  string_db <- get_string_db(score_threshold)

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
    # - weights=combined_score: STRING confidence drives the weighted-modularity
    #   objective; without it the >=400 filter's signal is discarded and the
    #   partition is driven by degree topology only.
    # - resolution: explicit argument (default 1.0)
    # - beta=0.01: Low randomness ensures reproducible results
    # - n_iterations=-1: iterate until the partition is stable (Leiden's
    #   convergence guarantees are asymptotic in iteration count)
    cluster_result <- igraph::cluster_leiden(
      subgraph,
      objective_function   = "modularity",
      weights              = igraph::E(subgraph)$combined_score,
      resolution_parameter = resolution,
      beta                 = 0.01,
      n_iterations         = -1
    )
  }

  # Convert to list format (compatible with existing downstream code)
  clusters_list <- split(
    igraph::V(subgraph)$name,
    cluster_result$membership
  )

  # Early return if no clusters were formed (no STRING interactions for input genes)
  if (length(clusters_list) == 0) {
    # Clean up and return empty tibble with expected column structure
    rm(string_db, subgraph, cluster_result, clusters_list)
    gc(verbose = FALSE)
    return(tibble(
      cluster = integer(),
      cluster_size = integer(),
      identifiers = list(),
      hash_filter = character()
    ))
  }

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
    {
      # Guard rowwise operations against empty tibble (fixes subscript out of bounds error)
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(cluster_size = nrow(identifiers)) %>%
          filter(cluster_size >= min_size) %>%
          select(cluster, cluster_size, identifiers, hash_filter)
      } else {
        select(., cluster, cluster_size = integer(), identifiers, hash_filter)
      }
    } %>%
    {
      if (!is.na(parent)) {
        mutate(., parent_cluster = parent)
      } else {
        .
      }
    } %>%
    {
      # Only add enrichment if there are rows (fixes rowwise $ operator error on empty tibble)
      if (enrichment && nrow(.) > 0) {
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
      # Only add subclusters if there are rows (fixes rowwise $ operator error on empty tibble)
      if (subcluster && nrow(.) > 0) {
        mutate(., subclusters = list(gen_string_clust_obj(
          identifiers$hgnc_id,
          min_size = min_size,
          resolution = resolution,
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

  # Deterministic content signature for stable cluster identity.
  # Downstream consumers key cluster identity on `cluster_signature` (the top-5
  # highest-degree member genes from the fixed STRING subgraph, tie-broken by
  # hgnc_id) rather than the positional integer index, so a partition change does
  # not silently relabel clusters. Computed before subgraph cleanup below.
  if (nrow(clusters_tibble) > 0) {
    deg <- igraph::degree(subgraph) # named by STRING_id
    id_map <- stats::setNames(sysndd_db_string_id_df$hgnc_id, sysndd_db_string_id_df$STRING_id)
    clusters_tibble <- clusters_tibble %>%
      dplyr::mutate(cluster_signature = vapply(identifiers, function(d) {
        hg <- d$hgnc_id
        sid <- names(id_map)[match(hg, id_map)] # hgnc_id -> STRING_id
        ord <- order(-deg[sid], hg) # highest degree first, tie-break by id
        paste(utils::head(hg[ord], 5L), collapse = "|")
      }, character(1)),
      cluster_signature_hash = vapply(cluster_signature,
        function(s) digest::digest(s, algo = "sha256"), character(1)))
  }

  # Memory cleanup before returning
  # Remove large intermediate objects to help gc()
  rm(string_db, subgraph, cluster_result, clusters_list)
  gc(verbose = FALSE)

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
  # Get cached STRINGdb instance (singleton avoids repeated version API calls)
  string_db <- get_string_db(400L)

  # compute enrichment and convert to tibble
  # Sort by FDR ascending so most significant terms appear first
  enrichment_tibble <- string_db$get_enrichment(hgnc_list) %>%
    tibble() %>%
    select(-ncbiTaxonId, -inputGenes, -preferredNames) %>%
    arrange(fdr)

  # return result
  return(enrichment_tibble)
}


generate_ndd_hgnc_ids <- function() {
  pool %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::arrange(entity_id) %>%
    dplyr::filter(ndd_phenotype == 1) %>%
    dplyr::select(hgnc_id) %>%
    dplyr::collect() %>%
    unique()
}


generate_functional_clusters <- function(algorithm = "leiden") {
  genes_from_entity_table <- generate_ndd_hgnc_ids()
  gen_string_clust_obj_mem(
    genes_from_entity_table$hgnc_id,
    algorithm = algorithm
  )
}


generate_functional_cluster_membership <- function(algorithm = "leiden") {
  functional_clusters <- generate_functional_clusters(algorithm = algorithm)
  if (is.null(functional_clusters) || nrow(functional_clusters) == 0L) {
    return(tibble::tibble(cluster = character(), hgnc_id = character()))
  }

  functional_clusters %>%
    dplyr::select(cluster, identifiers) %>%
    tidyr::unnest(identifiers) %>%
    dplyr::mutate(cluster = paste0("fc_", cluster)) %>%
    dplyr::select(cluster, hgnc_id)
}
