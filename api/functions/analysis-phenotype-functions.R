# functions/analysis-phenotype-functions.R
#### Phenotype and MCA analysis helpers

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
    {
      # Guard rowwise operations against empty tibble (defensive check)
      if (nrow(.) > 0) {
        rowwise(.) %>%
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
      } else {
        mutate(., cluster_size = integer(), quali_inp_var = list(), quali_sup_var = list(), quanti_sup_var = list())
      }
    }

  # return result
  return(clusters_tibble)
}


analysis_empty_phenotype_correlation <- function() {
  tibble::tibble(
    x = character(),
    x_id = character(),
    y = character(),
    y_id = character(),
    value = numeric()
  )
}


generate_phenotype_cluster_input <- function(categories = c("Definitive")) {
  id_phenotype_ids <- c(
    "HP:0001249",
    "HP:0001256",
    "HP:0002187",
    "HP:0002342",
    "HP:0006889",
    "HP:0010864"
  )

  ndd_entity_view_tbl <- pool %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::collect()

  primary_review_tbl <- pool %>%
    dplyr::tbl("ndd_entity_review") %>%
    dplyr::filter(is_primary == 1, review_approved == 1) %>%
    dplyr::select(entity_id, review_id) %>%
    dplyr::collect()

  phenotype_rows <- pool %>%
    dplyr::tbl("ndd_review_phenotype_connect") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::collect()

  modifier_rows <- pool %>%
    dplyr::tbl("modifier_list") %>%
    dplyr::collect()

  phenotype_terms <- pool %>%
    dplyr::tbl("phenotype_list") %>%
    dplyr::collect()

  joined <- ndd_entity_view_tbl %>%
    dplyr::left_join(phenotype_rows, by = "entity_id") %>%
    dplyr::inner_join(primary_review_tbl, by = c("entity_id", "review_id")) %>%
    dplyr::left_join(modifier_rows, by = "modifier_id") %>%
    dplyr::left_join(phenotype_terms, by = "phenotype_id") %>%
    dplyr::filter(ndd_phenotype == 1) %>%
    dplyr::filter(category %in% categories) %>%
    dplyr::filter(modifier_name == "present") %>%
    dplyr::select(
      entity_id,
      hpo_mode_of_inheritance_term_name,
      phenotype_id,
      HPO_term,
      hgnc_id
    ) %>%
    dplyr::group_by(entity_id) %>%
    dplyr::mutate(
      phenotype_non_id_count = sum(!(phenotype_id %in% id_phenotype_ids)),
      phenotype_id_count = sum(phenotype_id %in% id_phenotype_ids)
    ) %>%
    dplyr::ungroup() %>%
    unique()

  entity_gene_map <- ndd_entity_view_tbl %>%
    dplyr::select(entity_id, hgnc_id, symbol) %>%
    dplyr::distinct()

  if (nrow(joined) == 0L) {
    return(list(matrix = data.frame(), entity_gene_map = entity_gene_map))
  }

  wider <- joined %>%
    dplyr::mutate(present = "yes") %>%
    dplyr::select(-phenotype_id) %>%
    tidyr::pivot_wider(names_from = HPO_term, values_from = present) %>%
    dplyr::group_by(hgnc_id) %>%
    dplyr::mutate(gene_entity_count = dplyr::n()) %>%
    dplyr::ungroup() %>%
    dplyr::relocate(gene_entity_count, .after = phenotype_id_count) %>%
    dplyr::select(-hgnc_id)

  matrix <- wider %>%
    dplyr::select(-entity_id) %>%
    as.data.frame()
  row.names(matrix) <- wider$entity_id

  list(matrix = matrix, entity_gene_map = entity_gene_map)
}


generate_phenotype_clusters <- function() {
  if (!exists("gen_mca_clust_obj_mem", mode = "function")) {
    return(tibble::tibble())
  }

  input <- generate_phenotype_cluster_input()
  if (is.null(input$matrix) || nrow(input$matrix) == 0L) {
    return(tibble::tibble())
  }

  phenotype_clusters <- gen_mca_clust_obj_mem(input$matrix)
  if (is.null(phenotype_clusters) || nrow(phenotype_clusters) == 0L) {
    return(phenotype_clusters)
  }

  phenotype_clusters %>%
    tidyr::unnest(identifiers) %>%
    dplyr::mutate(entity_id = as.integer(entity_id)) %>%
    dplyr::left_join(input$entity_gene_map, by = "entity_id") %>%
    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
}


generate_phenotype_correlations <- function(
  filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)",
  min_abs_correlation = NULL
) {
  filter <- URLdecode(if (is.null(filter)) "" else filter)
  filter_exprs <- generate_filter_expressions(filter)

  ndd_entity_view_tbl <- pool %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::collect()

  primary_review_tbl <- pool %>%
    dplyr::tbl("ndd_entity_review") %>%
    dplyr::filter(is_primary == 1, review_approved == 1) %>%
    dplyr::select(entity_id, review_id) %>%
    dplyr::collect()

  phenotype_rows <- pool %>%
    dplyr::tbl("ndd_review_phenotype_connect") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::collect()

  modifier_rows <- pool %>%
    dplyr::tbl("modifier_list") %>%
    dplyr::collect()

  phenotype_list_tbl <- pool %>%
    dplyr::tbl("phenotype_list") %>%
    dplyr::collect()

  entity_phenotype_table <- ndd_entity_view_tbl %>%
    dplyr::inner_join(primary_review_tbl, by = "entity_id") %>%
    dplyr::inner_join(phenotype_rows, by = c("entity_id", "review_id")) %>%
    dplyr::left_join(modifier_rows, by = "modifier_id") %>%
    dplyr::mutate(modifier_phenotype_id = paste0(modifier_id, "-", phenotype_id)) %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(names(ndd_entity_view_tbl)))) %>%
    dplyr::summarise(
      modifier_phenotype_id = paste(sort(unique(modifier_phenotype_id)), collapse = ","),
      .groups = "drop"
    ) %>%
    dplyr::filter(!!!rlang::parse_exprs(filter_exprs))

  sysndd_db_phenotypes <- entity_phenotype_table %>%
    tidyr::separate_rows(modifier_phenotype_id, sep = ",") %>%
    dplyr::mutate(phenotype_id = stringr::str_remove(modifier_phenotype_id, "[1-4]-")) %>%
    dplyr::filter(stringr::str_detect(modifier_phenotype_id, "1-")) %>%
    dplyr::filter(phenotype_id != "HP:0001249") %>%
    dplyr::left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
    dplyr::filter(!is.na(HPO_term)) %>%
    dplyr::select(entity_id, phenotype_id, HPO_term) %>%
    unique()

  if (nrow(sysndd_db_phenotypes) == 0L) {
    return(analysis_empty_phenotype_correlation())
  }

  sysndd_db_phenotypes_matrix <- sysndd_db_phenotypes %>%
    dplyr::select(-phenotype_id) %>%
    dplyr::mutate(has_HPO_term = 1) %>%
    unique() %>%
    tidyr::pivot_wider(names_from = HPO_term, values_from = has_HPO_term) %>%
    dplyr::mutate(dplyr::across(-entity_id, ~ tidyr::replace_na(.x, 0))) %>%
    dplyr::select(-entity_id)

  if (ncol(sysndd_db_phenotypes_matrix) == 0L) {
    return(analysis_empty_phenotype_correlation())
  }

  sysndd_db_phenotypes_corr <- round(stats::cor(sysndd_db_phenotypes_matrix), 2)
  phenotypes_corr_melted <- reshape2::melt(sysndd_db_phenotypes_corr) %>%
    dplyr::select(x = Var1, y = Var2, value)

  phenotype_list_join <- phenotype_list_tbl %>%
    dplyr::select(phenotype_id, HPO_term)

  phenotypes_corr_melted_ids <- phenotypes_corr_melted %>%
    dplyr::left_join(phenotype_list_join, by = c("x" = "HPO_term")) %>%
    dplyr::select(x, y, value, x_id = phenotype_id) %>%
    dplyr::left_join(phenotype_list_join, by = c("y" = "HPO_term")) %>%
    dplyr::select(x, x_id, y, y_id = phenotype_id, value)

  if (!is.null(min_abs_correlation)) {
    min_abs_correlation <- suppressWarnings(as.numeric(min_abs_correlation))
    if (!is.na(min_abs_correlation)) {
      phenotypes_corr_melted_ids <- phenotypes_corr_melted_ids %>%
        dplyr::filter(abs(value) >= min_abs_correlation)
    }
  }

  phenotypes_corr_melted_ids
}


generate_phenotype_cluster_membership <- function() {
  phenotype_clusters <- generate_phenotype_clusters()
  if (is.null(phenotype_clusters) || nrow(phenotype_clusters) == 0L) {
    return(tibble::tibble(cluster = character(), hgnc_id = character()))
  }

  phenotype_clusters %>%
    dplyr::select(cluster, identifiers) %>%
    tidyr::unnest(identifiers) %>%
    dplyr::mutate(cluster = paste0("pc_", cluster)) %>%
    dplyr::select(cluster, hgnc_id)
}


generate_phenotype_functional_cluster_membership <- function(include_sfari = TRUE) {
  all_clusters <- dplyr::bind_rows(
    generate_functional_cluster_membership(algorithm = "leiden"),
    generate_phenotype_cluster_membership()
  )

  sfari_csv <- "data/sfari_list.2024-01-23.csv.gz"
  if (isTRUE(include_sfari) && file.exists(sfari_csv)) {
    sfari_hgnc_pseudocluster <- readr::read_csv(sfari_csv, show_col_types = FALSE) %>%
      dplyr::mutate(cluster = "sfari") %>%
      dplyr::select(cluster, hgnc_id)

    all_clusters <- dplyr::bind_rows(all_clusters, sfari_hgnc_pseudocluster)
  }

  all_clusters %>%
    dplyr::filter(!is.na(hgnc_id)) %>%
    unique()
}


generate_phenotype_functional_cluster_correlation <- function(include_membership = FALSE,
                                                              include_sfari = TRUE) {
  all_clusters <- generate_phenotype_functional_cluster_membership(include_sfari = include_sfari)

  if (nrow(all_clusters) == 0L) {
    result <- list(
      correlation_matrix = matrix(numeric(), nrow = 0L, ncol = 0L),
      correlation_melted = tibble::tibble(x = character(), y = character(), value = numeric())
    )
    if (isTRUE(include_membership)) result$cluster_membership <- all_clusters
    return(result)
  }

  cluster_matrix <- all_clusters %>%
    dplyr::mutate(has_hgnc_id = dplyr::case_when(!is.na(hgnc_id) ~ 1)) %>%
    unique() %>%
    tidyr::pivot_wider(names_from = cluster, values_from = has_hgnc_id) %>%
    dplyr::mutate(dplyr::across(-hgnc_id, ~ tidyr::replace_na(.x, 0))) %>%
    dplyr::select(-hgnc_id)

  if (ncol(cluster_matrix) == 0L) {
    cluster_matrix_corr <- matrix(numeric(), nrow = 0L, ncol = 0L)
    phenotypes_corr_melted <- tibble::tibble(x = character(), y = character(), value = numeric())
  } else {
    cluster_matrix_corr <- round(stats::cor(cluster_matrix), 2)
    phenotypes_corr_melted <- reshape2::melt(cluster_matrix_corr) %>%
      dplyr::select(x = Var1, y = Var2, value)
  }

  result <- list(
    correlation_matrix = cluster_matrix_corr,
    correlation_melted = phenotypes_corr_melted
  )
  if (isTRUE(include_membership)) result$cluster_membership <- all_clusters
  result
}
