# api/endpoints/analysis_endpoints.R
#
# This file contains all Analysis-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Be sure to source any required helper files at the top (e.g.,
# source("functions/database-functions.R", local = TRUE)) if needed.
#
# Note: For long-running operations, consider using async endpoints:
#   POST /api/jobs/clustering/submit - Async functional clustering
#   POST /api/jobs/phenotype_clustering/submit - Async phenotype clustering
#   GET /api/jobs/<job_id>/status - Poll job status

## -------------------------------------------------------------------##
## Analyses endpoints
## -------------------------------------------------------------------##

#* Retrieve Functional Clustering Data with Pagination
#*
#* This endpoint fetches functional clustering data for genes with NDD phenotype.
#* Results are paginated to reduce response size and improve performance.
#*
#* # `Details`
#* - Returns clusters sorted by cluster number for stable pagination
#* - Use `page_after` cursor to fetch subsequent pages
#* - Default page size is 10 clusters, maximum is 50
#* - Categories are returned in full (small dataset, not paginated)
#*
#* # `Pagination`
#* - First page: omit `page_after` or pass empty string
#* - Next page: use `next_cursor` from previous response as `page_after`
#* - Last page: `has_more` will be `false` and `next_cursor` will be `null`
#*
#* # `Return`
#* Returns categories, paginated clusters, and pagination metadata.
#*
#* @tag analysis
#* @serializer json list(na="string")
#* @param page_after:str Cursor for pagination (hash_filter of last item, empty for first page)
#* @param page_size:str Number of clusters per page (default "10", max "50")
#* @param algorithm:str Clustering algorithm: "leiden" (default, fast) or "walktrap" (slower, legacy)
#*
#* @response 200 OK. Returns object with:
#*   - categories: Full list of enrichment categories with links
#*   - clusters: Array of cluster objects (paginated)
#*   - pagination: {page_size, page_after, next_cursor, total_count, has_more}
#*   - meta: {algorithm, cache_hit}
#*
#* @get functional_clustering
function(page_after = "", page_size = "10", algorithm = "leiden") {
  # Define link sources
  value <- c(
    "COMPARTMENTS",
    "Component",
    "DISEASES",
    "Function",
    "HPO",
    "InterPro",
    "KEGG",
    "Keyword",
    "NetworkNeighborAL",
    "Pfam",
    "PMID",
    "Process",
    "RCTM",
    "SMART",
    "TISSUES",
    "WikiPathways"
  )

  link <- c(
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://disease-ontology.org/term/",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://hpo.jax.org/app/browse/term/",
    "http://www.ebi.ac.uk/interpro/entry/InterPro/",
    "https://www.genome.jp/dbget-bin/www_bget?",
    "https://www.uniprot.org/keywords/",
    "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
    "https://www.ebi.ac.uk/interpro/entry/pfam/",
    "https://www.ncbi.nlm.nih.gov/search/all/?term=",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://reactome.org/content/detail/R-",
    "http://www.ebi.ac.uk/interpro/entry/smart/",
    "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
    "https://www.wikipathways.org/index.php/Pathway:"
  )

  links <- tibble(value, link)

  # NOTE: Backward compatibility
  # - Clients not using pagination get first 10 clusters (was all clusters)
  # - To get all clusters, iterate using next_cursor until has_more=false
  # - Categories still returned in full (not paginated)

  # Validate and parse pagination parameters
  page_size_int <- min(max(as.integer(page_size), 1), 50)
  page_after_clean <- if (is.null(page_after) || page_after == "") "" else page_after

  # Validate algorithm parameter
  algorithm_clean <- tolower(algorithm)
  if (!algorithm_clean %in% c("leiden", "walktrap")) {
    algorithm_clean <- "leiden"  # Default to faster algorithm
  }

  # Track timing for performance monitoring
  start_time <- Sys.time()

  # Get data from database
  genes_from_entity_table <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id) %>%
    collect() %>%
    unique()

  # Generate clusters for the retrieved HGNC IDs with selected algorithm
  functional_clusters <- gen_string_clust_obj_mem(
    genes_from_entity_table$hgnc_id,
    algorithm = algorithm_clean
  )

  # Calculate elapsed time
  elapsed_seconds <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Generate categories
  categories <- functional_clusters %>%
    select(term_enrichment) %>%
    unnest(cols = c(term_enrichment)) %>%
    select(category) %>%
    unique() %>%
    arrange(category) %>%
    mutate(
      text = case_when(
        nchar(category) <= 5 ~ category,
        nchar(category) > 5 ~ str_to_sentence(category)
      )
    ) %>%
    select(value = category, text) %>%
    left_join(links, by = c("value"))

  # Sort clusters deterministically for stable pagination
  # (prevents duplicates/gaps across pages)
  clusters_sorted <- functional_clusters %>%
    arrange(cluster) %>%
    mutate(row_num = row_number())

  # Find cursor position
  if (page_after_clean == "") {
    start_idx <- 1
  } else {
    cursor_pos <- which(clusters_sorted$hash_filter == page_after_clean)
    start_idx <- if (length(cursor_pos) > 0) cursor_pos[1] + 1 else 1
  }

  # Extract page slice
  end_idx <- min(start_idx + page_size_int - 1, nrow(clusters_sorted))
  clusters_page <- clusters_sorted %>%
    slice(start_idx:end_idx) %>%
    select(-row_num)  # Remove internal field

  # Generate next cursor (hash_filter of last item in page)
  next_cursor <- if (end_idx < nrow(clusters_sorted)) {
    clusters_page %>% slice(n()) %>% pull(hash_filter)
  } else {
    NULL
  }

  # Generate the object to return with pagination metadata
  list(
    categories = categories,
    clusters = clusters_page,  # Paginated clusters (was functional_clusters)
    pagination = list(
      page_size = page_size_int,
      page_after = page_after_clean,
      next_cursor = next_cursor,
      total_count = nrow(clusters_sorted),
      has_more = !is.null(next_cursor)
    ),
    meta = list(
      algorithm = algorithm_clean,
      elapsed_seconds = round(elapsed_seconds, 2),
      gene_count = nrow(genes_from_entity_table),
      cluster_count = nrow(clusters_sorted)
    )
  )
}


#* Retrieve Phenotype Clustering Data
#*
#* This endpoint fetches data clusters of entities based on phenotypes
#* using Multiple Correspondence Analysis (MCA) and Hierarchical Clustering.
#*
#* # `Details`
#* Retrieves phenotype-based clusters of entities.
#*
#* # `Return`
#* Returns a list of entities grouped by phenotype clusters.
#*
#* @tag analysis
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns phenotype clustering data.
#*
#* @get phenotype_clustering
function() {
  # Define constants for filtering
  id_phenotype_ids <- c(
    "HP:0001249",
    "HP:0001256",
    "HP:0002187",
    "HP:0002342",
    "HP:0006889",
    "HP:0010864"
  )

  categories <- c("Definitive")

  # Get data from database
  ndd_entity_view_tbl <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()

  ndd_entity_review_tbl <- pool %>%
    tbl("ndd_entity_review") %>%
    collect() %>%
    filter(is_primary == 1) %>%
    select(review_id)

  ndd_review_phenotype_connect_tbl <- pool %>%
    tbl("ndd_review_phenotype_connect") %>%
    collect()

  modifier_list_tbl <- pool %>%
    tbl("modifier_list") %>%
    collect()

  phenotype_list_tbl <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  # Join tables and filter
  sysndd_db_phenotypes <- ndd_entity_view_tbl %>%
    left_join(ndd_review_phenotype_connect_tbl, by = c("entity_id")) %>%
    left_join(modifier_list_tbl, by = c("modifier_id")) %>%
    left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
    mutate(
      ndd_phenotype = case_when(
        ndd_phenotype == 1 ~ "Yes",
        ndd_phenotype == 0 ~ "No"
      )
    ) %>%
    filter(ndd_phenotype == "Yes") %>%
    filter(category %in% categories) %>%
    filter(modifier_name == "present") %>%
    filter(review_id %in% ndd_entity_review_tbl$review_id) %>%
    select(
      entity_id,
      hpo_mode_of_inheritance_term_name,
      phenotype_id,
      HPO_term,
      hgnc_id
    ) %>%
    group_by(entity_id) %>%
    mutate(
      phenotype_non_id_count = sum(!(phenotype_id %in% id_phenotype_ids)),
      phenotype_id_count = sum(phenotype_id %in% id_phenotype_ids)
    ) %>%
    ungroup() %>%
    unique()

  # Convert to wide format
  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes %>%
    mutate(present = "yes") %>%
    select(-phenotype_id) %>%
    pivot_wider(names_from = HPO_term, values_from = present) %>%
    group_by(hgnc_id) %>%
    mutate(gene_entity_count = n()) %>%
    ungroup() %>%
    relocate(gene_entity_count, .after = phenotype_id_count) %>%
    select(-hgnc_id)

  # Convert to data frame
  sysndd_db_phenotypes_wider_df <- sysndd_db_phenotypes_wider %>%
    select(-entity_id) %>%
    as.data.frame()

  # Transform row names to entity_id
  row.names(sysndd_db_phenotypes_wider_df) <- sysndd_db_phenotypes_wider$entity_id

  # Perform cluster analysis using memoized function
  phenotype_clusters <- gen_mca_clust_obj_mem(sysndd_db_phenotypes_wider_df)

  # Add back gene identifiers
  ndd_entity_view_tbl_sub <- ndd_entity_view_tbl %>%
    select(entity_id, hgnc_id, symbol)

  phenotype_clusters_identifiers <- phenotype_clusters %>%
    unnest(identifiers) %>%
    mutate(entity_id = as.integer(entity_id)) %>%
    left_join(ndd_entity_view_tbl_sub, by = c("entity_id")) %>%
    nest(identifiers = c(entity_id, hgnc_id, symbol))

  # Return output
  phenotype_clusters_identifiers
}


#* Correlation of Phenotype & Functional Clusters
#*
#* This endpoint calculates the correlation between:
#*   - Phenotype-based clusters (MCA)
#*   - Functional clusters (STRING-db based)
#*   - Optionally, SFARI genes
#*
#* It returns a JSON object containing:
#*   - "correlation_matrix": a matrix of Pearson correlation coefficients
#*   - "correlation_melted": the melted version (x, y, value)
#*
#* @tag analysis
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns correlation data among clusters.
#*
#* @get phenotype_functional_cluster_correlation
function() {
  #-------------------------------------------------------#
  # 1) Load libraries and global objects are assumed
  #    to be available globally in your Plumber file:
  #
  #    - pool  (database connection pool)
  #    - other objects from your config
  #
  #-------------------------------------------------------#

  #-------------------------------------------------------#
  # 2) Build Functional Clusters from all ndd_phenotype=1
  #-------------------------------------------------------#
  # define link sources (not strictly needed if you only want correlation)
  value <- c(
    "COMPARTMENTS",
    "Component",
    "DISEASES",
    "Function",
    "HPO",
    "InterPro",
    "KEGG",
    "Keyword",
    "NetworkNeighborAL",
    "Pfam",
    "PMID",
    "Process",
    "RCTM",
    "SMART",
    "TISSUES",
    "WikiPathways"
  )
  link <- c(
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://disease-ontology.org/term/",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://hpo.jax.org/app/browse/term/",
    "http://www.ebi.ac.uk/interpro/entry/InterPro/",
    "https://www.genome.jp/dbget-bin/www_bget?",
    "https://www.uniprot.org/keywords/",
    "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
    "https://www.ebi.ac.uk/interpro/entry/pfam/",
    "https://www.ncbi.nlm.nih.gov/search/all/?term=",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://reactome.org/content/detail/R-",
    "http://www.ebi.ac.uk/interpro/entry/smart/",
    "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
    "https://www.wikipathways.org/index.php/Pathway:"
  )
  links <- tibble(value, link)

  # get data from DB: all genes with ndd_phenotype=1
  genes_from_entity_table <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id) %>%
    collect() %>%
    unique()

  # build functional clusters via gen_string_clust_obj
  functional_clusters <- gen_string_clust_obj(
    genes_from_entity_table$hgnc_id
  )

  # Flatten to (cluster, hgnc_id)
  functional_clusters_hgnc <- functional_clusters %>%
    select(cluster, identifiers) %>%
    unnest(identifiers) %>%
    mutate(cluster = paste0("fc_", cluster)) %>%
    select(cluster, hgnc_id)

  #-------------------------------------------------------#
  # 3) Build Phenotype Clusters
  #-------------------------------------------------------#
  id_phenotype_ids <- c(
    "HP:0001249",
    "HP:0001256",
    "HP:0002187",
    "HP:0002342",
    "HP:0006889",
    "HP:0010864"
  )
  categories <- c("Definitive")

  # gather data from DB
  ndd_entity_view_tbl <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()
  ndd_entity_review_tbl <- pool %>%
    tbl("ndd_entity_review") %>%
    collect() %>%
    filter(is_primary == 1) %>%
    select(review_id)

  ndd_review_phenotype_connect_tbl <- pool %>%
    tbl("ndd_review_phenotype_connect") %>%
    collect()
  modifier_list_tbl <- pool %>%
    tbl("modifier_list") %>%
    collect()
  phenotype_list_tbl <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  # join/filter
  sysndd_db_phenotypes <- ndd_entity_view_tbl %>%
    left_join(ndd_review_phenotype_connect_tbl, by = c("entity_id")) %>%
    left_join(modifier_list_tbl, by = c("modifier_id")) %>%
    left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
    mutate(ndd_phenotype = case_when(
      ndd_phenotype == 1 ~ "Yes",
      ndd_phenotype == 0 ~ "No"
    )) %>%
    filter(ndd_phenotype == "Yes") %>%
    filter(category %in% categories) %>%
    filter(modifier_name == "present") %>%
    filter(review_id %in% ndd_entity_review_tbl$review_id) %>%
    select(
      entity_id,
      hpo_mode_of_inheritance_term_name,
      phenotype_id,
      HPO_term,
      hgnc_id
    ) %>%
    group_by(entity_id) %>%
    mutate(
      phenotype_non_id_count = sum(!(phenotype_id %in% id_phenotype_ids)),
      phenotype_id_count = sum(phenotype_id %in% id_phenotype_ids)
    ) %>%
    ungroup() %>%
    unique()

  # pivot wide
  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes %>%
    mutate(present = "yes") %>%
    select(-phenotype_id) %>%
    pivot_wider(names_from = HPO_term, values_from = present) %>%
    group_by(hgnc_id) %>%
    mutate(gene_entity_count = n()) %>%
    ungroup() %>%
    relocate(gene_entity_count, .after = phenotype_id_count) %>%
    select(-hgnc_id)

  # convert to data frame
  sysndd_db_phenotypes_wider_df <- sysndd_db_phenotypes_wider %>%
    select(-entity_id) %>%
    as.data.frame()

  # set row names
  row.names(sysndd_db_phenotypes_wider_df) <-
    sysndd_db_phenotypes_wider$entity_id

  # run MCA-based clustering
  phenotype_clusters <- gen_mca_clust_obj(
    sysndd_db_phenotypes_wider_df
  )

  # add back gene identifiers
  ndd_entity_view_tbl_sub <- ndd_entity_view_tbl %>%
    select(entity_id, hgnc_id, symbol)

  phenotype_clusters_identifiers <- phenotype_clusters %>%
    unnest(identifiers) %>%
    mutate(entity_id = as.integer(entity_id)) %>%
    left_join(ndd_entity_view_tbl_sub, by = c("entity_id")) %>%
    nest(identifiers = c(entity_id, hgnc_id, symbol))

  # Flatten to (cluster, hgnc_id)
  phenotype_clusters_hgnc <- phenotype_clusters_identifiers %>%
    select(cluster, identifiers) %>%
    unnest(identifiers) %>%
    mutate(cluster = paste0("pc_", cluster)) %>%
    select(cluster, hgnc_id)

  #-------------------------------------------------------#
  # 4) Combine clusters and optionally add SFARI
  #-------------------------------------------------------#
  all_clusters <- bind_rows(functional_clusters_hgnc, phenotype_clusters_hgnc)

  # load sfari gene list from CSV
  sfari_csv <- "data/sfari_list.2024-01-23.csv.gz"
  if (file.exists(sfari_csv)) {
    sfari_list_2024_01_23_csv <- read_csv(sfari_csv)

    sfari_hgnc_pseudocluster <- sfari_list_2024_01_23_csv %>%
      mutate(cluster = "sfari") %>%
      select(cluster, hgnc_id)

    all_clusters <- bind_rows(all_clusters, sfari_hgnc_pseudocluster)
  }

  #-------------------------------------------------------#
  # 5) Build presence/absence matrix & compute correlation
  #-------------------------------------------------------#
  cluster_matrix <- all_clusters %>%
    mutate(has_hgnc_id = case_when(
      !is.na(hgnc_id) ~ 1
    )) %>%
    unique() %>%
    tidyr::pivot_wider(names_from = cluster, values_from = has_hgnc_id) %>%
    replace(is.na(.), 0) %>%
    select(-hgnc_id)

  # Calculate correlation
  cluster_matrix_corr <- round(cor(cluster_matrix), 2)

  # Melt correlation for optional use (heatmap, etc.)
  phenotypes_corr_melted <- reshape2::melt(cluster_matrix_corr) %>%
    select(x = Var1, y = Var2, value)

  #-------------------------------------------------------#
  # 6) Return the correlation data
  #-------------------------------------------------------#
  #  (You could return the matrix and the melted version.)
  list(
    correlation_matrix = cluster_matrix_corr,
    correlation_melted = phenotypes_corr_melted
  )
}

## Analyses endpoints
## -------------------------------------------------------------------##
