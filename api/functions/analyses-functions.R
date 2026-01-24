# functions/analyses-functions.R
#### This file holds analyses functions

#' A recursive function generating a functional gene cluster with string-db
#'
#' @param hgnc_list A comma separated list as concatenated text
#' @param min_size A number defining the minimal cluster size to return
#' @param subcluster Boolean value indicating whether to perform subclustering
#' @param parent the parent cluster name used in the generation of subclusters
#'
#' @return The clusters tibble
#' @export
gen_string_clust_obj <- function(
  hgnc_list,
  min_size = 10,
  subcluster = TRUE,
  parent = NA,
  enrichment = TRUE
) {
  # compute hashes for input
  panel_hash <- generate_panel_hash(hgnc_list)
  function_hash <- generate_function_hash(gen_string_clust_obj)

  # generate result output filename
  filename_results <- paste0(
    "results/",
    panel_hash, ".",
    function_hash, ".",
    min_size, ".",
    subcluster, ".json"
  )

  if (file.exists(filename_results)) {
    clusters_tibble <- jsonlite::fromJSON(filename_results) %>%
      tibble::tibble()
  } else {
    # load/ download STRING database files
    string_db <- STRINGdb::STRINGdb$new(
      version = "11.5",
      species = 9606,
      score_threshold = 200,
      input_directory = "data"
    )

    # load gene table from database and filter to input HGNC list
    sysndd_db_string_id_table <- pool %>%
      tbl("non_alt_loci_set") %>%
      filter(!is.na(STRING_id)) %>%
      select(symbol, hgnc_id, STRING_id) %>%
      collect() %>%
      filter(hgnc_id %in% hgnc_list)

    # convert to dataframe
    sysndd_db_string_id_df <- sysndd_db_string_id_table %>%
      as.data.frame()

    # perform clustering using the get_clusters function
    # and walktrap algorithm from the stringdb package
    clusters_list <- string_db$get_clusters(sysndd_db_string_id_df$STRING_id,
      algorithm = "walktrap"
    )

    clusters_tibble <- tibble(clusters_list) %>%
      select(STRING_id = clusters_list) %>%
      mutate(cluster = row_number()) %>%
      unnest_longer(col = "STRING_id") %>%
      left_join(sysndd_db_string_id_table, by = c("STRING_id")) %>%
      tidyr::nest(.by = c(cluster), .key = "identifiers") %>%
      mutate(hash_filter = list(
        post_db_hash(identifiers %>% purrr::pluck("symbol"))
      )) %>%
      mutate(hash_filter = purrr::pluck(hash_filter, 1, 1, "hash")) %>%
      ungroup() %>%
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
            parent = cluster
          )))
        } else {
          .
        }
      } %>%
      ungroup()

    # save computation result
    clusters_json <- toJSON(clusters_tibble)
    write(clusters_json, filename_results)
  }

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
    score_threshold = 200,
    input_directory = "data/"
  )

  # compute enrichment and convert to tibble
  enrichment_tibble <- string_db$get_enrichment(hgnc_list) %>%
    tibble() %>%
    select(-ncbiTaxonId, -inputGenes, -preferredNames)

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
  # compute hashes for input
  panel_hash <- generate_panel_hash(row.names(wide_phenotypes_df))
  function_hash <- generate_function_hash(gen_mca_clust_obj)

  # generate result output filename
  filename_results <- paste0(
    "results/",
    panel_hash, ".",
    function_hash, ".", ".json"
  )

  if (file.exists(filename_results)) {
    clusters_tibble <- jsonlite::fromJSON(filename_results) %>%
      tibble::tibble()
  } else {
    # Compute Multiple Correspondence Analysis (MCA)
    # TODO(future-ML): Optimize ncp (number of components) selection
    # Current: Fixed ncp=15, may not capture >70% information variance
    # Enhancement ideas from STHDA:
    # - http://www.sthda.com/english/articles/31-principal-component-methods-in-r-practical-guide/
    # - http://www.sthda.com/english/articles/31-principal-component-methods-in-r-practical-guide/117-hcpc-hierarchical-clustering-on-principal-components-essentials/
    # - Specifically: #case-3-clustering-on-mixed-data
    # Implementation: Calculate cumulative variance explained, set ncp to reach 70% threshold
    mca_phenotypes <- MCA(wide_phenotypes_df,
      ncp = 15,
      quali.sup = quali_sup_var,
      quanti.sup = quanti_sup_var,
      graph = FALSE
    )

    # compute hierarchical clustering
    mca_hcpc <- HCPC(mca_phenotypes,
      nb.clust = cutpoint,
      kk = Inf,
      mi = 3,
      max = 25,
      consol = TRUE,
      graph = FALSE
    )

    # add entity_id back as column
    mca_hcpc$data.clust$entity_id <- row.names(mca_hcpc$data.clust)

    # generate cluster tibble
    clusters_tibble <- tibble(mca_hcpc$data.clust) %>%
      select(entity_id, cluster = clust) %>%
      tidyr::nest(.by = c(cluster), .key = "identifiers") %>%
      mutate(hash_filter = list(
        post_db_hash(identifiers %>%
          purrr::pluck("entity_id"), "entity_id", "/api/entity")
      )) %>%
      mutate(hash_filter = hash_filter$links$hash) %>%
      ungroup() %>%
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
        mutate(variable = str_remove_all(variable, "^.+=|_yes")))) %>%
      mutate(quali_sup_var = list(tibble::as_tibble(
        mca_hcpc$desc.var$category[[cluster]],
        rownames = "variable",
        .name_repair = ~ vctrs::vec_as_names(...,
          repair = "universal", quiet = TRUE
        )
      ) %>%
        filter(!str_detect(variable, "NA")) %>%
        filter(str_detect(variable, "hpo")) %>%
        mutate(variable = str_remove_all(variable, "^.+=|_yes")))) %>%
      mutate(quanti_sup_var = list(tibble::as_tibble(
        mca_hcpc$desc.var$quanti[[cluster]],
        rownames = "variable",
        .name_repair = ~ vctrs::vec_as_names(...,
          repair = "universal", quiet = TRUE
        )
      ))) %>%
      ungroup()

    # save computation result
    clusters_json <- toJSON(clusters_tibble)
    write(clusters_json, filename_results)
  }

  # return result
  return(clusters_tibble)
}
