# api/endpoints/analysis_endpoints.R
#
# This file contains all Analysis-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Be sure to source any required helper files at the top (e.g.,
# source("functions/database-functions.R", local = TRUE)) if needed.

## -------------------------------------------------------------------##
## Analyses endpoints
## -------------------------------------------------------------------##

#* Retrieve Available Functional Clustering Categories
#*
#* This endpoint fetches the available functional clustering categories
#* for genes, linking them to their respective sources.
#*
#* # `Details`
#* Retrieves functional clustering categories with source links.
#*
#* # `Return`
#* Returns a list of functional clustering categories and their source links.
#*
#* @tag analysis
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns functional clustering categories and source links.
#*
#* @get functional_clustering
function() {
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

  # Get data from database
  genes_from_entity_table <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id) %>%
    collect() %>%
    unique()

  # Generate clusters for the retrieved HGNC IDs
  functional_clusters <- gen_string_clust_obj_mem(genes_from_entity_table$hgnc_id)

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

  # Generate the object to return
  list(
    categories = categories,
    clusters = functional_clusters
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
