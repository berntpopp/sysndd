#### This file holds analyses functions

#' A recursive function generating a gene clusters object
#'
#' @param hgnc_list A comma separated list as concatenated text
#' @param min_size A number defining the minimal cluster size to return
#' @param subcluster Boolean value indicateting whether to perform subclustering
#' @param parent the parent cluster name used in the generation of subclusters
#'
#' @return The clusters tibble
#' @export
generate_cluster_object <- function(hgnc_list,
  min_size = 10,
  subcluster = TRUE,
  parent = NA) {

  # compute hashes for input
  panel_hash <- generate_panel_hash(hgnc_list)
  function_hash <- generate_function_hash(generate_cluster_object)

  # generate result output filename
  filename_results <- paste0("results/",
    panel_hash, ".",
    function_hash, ".",
    min_size, ".",
    subcluster, ".json")

  if (file.exists(filename_results)) {

    clusters_tibble <- jsonlite::fromJSON(filename_results) %>%
      tibble::tibble()

  } else {

    # load/ download STRING database files
    string_db <- STRINGdb::STRINGdb$new(version = "11.5",
      species = 9606,
      score_threshold = 200,
      input_directory = "data")

    sysndd_db_string_id_table <- pool %>%
      tbl("non_alt_loci_set") %>%
      filter(!is.na(STRING_id)) %>%
      select(symbol, hgnc_id, STRING_id) %>%
      collect() %>%
      filter(hgnc_id %in% hgnc_list)

    sysndd_db_string_id_df <- sysndd_db_string_id_table %>%
      as.data.frame()

    clusters_list <- string_db$get_clusters(sysndd_db_string_id_df$STRING_id,
      algorithm = "walktrap")

    clusters_tibble <- tibble(clusters_list) %>%
      select(STRING_id = clusters_list) %>%
      mutate(cluster = row_number()) %>%
      unnest_longer(col = "STRING_id") %>%
      left_join(sysndd_db_string_id_table, by = c("STRING_id")) %>%
      nest_by(cluster, .key = "identifiers") %>%
      mutate(hash_filter = list(
        post_db_hash(identifiers %>% select(symbol)))
      ) %>%
      mutate(hash_filter = hash_filter$links$hash) %>%
      ungroup() %>%
      rowwise() %>%
      mutate(cluster_size = nrow(identifiers)) %>%
      filter(cluster_size >= min_size) %>%
      select(cluster, cluster_size, identifiers, hash_filter) %>%
      {if (!is.na(parent))
        mutate(., parent_cluster = parent)
      else .
      } %>%
      {if (subcluster)
        mutate(., subclusters = list(generate_cluster_object(
          identifiers$hgnc_id,
          subcluster = FALSE,
          parent = cluster)))
      else .
      } %>%
      ungroup()

    # save computation result
    clusters_json <- toJSON(clusters_tibble)
    write(clusters_json, filename_results)

  }

  # return result
  return(clusters_tibble)

}
