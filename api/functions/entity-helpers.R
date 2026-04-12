# functions/entity-helpers.R
#### Entity/gene data transformation helpers (nest_gene_tibble,
#### nest_pubtator_gene_tibble, extract_vario_filter, get_entity_ids_by_vario)
#### Split from helper-functions.R in v11.0 phase D2.
####
#### Dependencies (loaded by start_sysndd_api.R):
####   dplyr, tidyr, stringr


#' Nest the gene tibble
#'
#' @description
#' This function organizes data in a tibble by nesting it into groups, making it
#' easier to analyze or manipulate the data.
#' It performs the following operations:
#' 1. Remembers the initial sorting of the tibble by selecting columns 'symbol',
#'    'hgnc_id', and 'entities_count', retaining only unique rows.
#' 2. Nests the tibble by columns 'symbol', 'hgnc_id', and 'entities_count',
#'    assigning the key "entities" to the nested data frame.
#' 3. Removes grouping and arranges the nested tibble by the 'symbol' column,
#'    using the initial sorting as the level order.
#' 4. Returns the nested tibble.
#'
#' @param tibble A tibble to be nested.
#'
#' @return A nested tibble.
#'
#' @examples
#' # Prepare example tibble
#' example_tibble <- tibble(
#'   symbol = c("A", "B", "C"),
#'   hgnc_id = c(1, 2, 3),
#'   entities_count = c(5, 3, 2)
#' )
#'
#' # Nest the example tibble
#' nest_gene_tibble(example_tibble)
#'
#' @seealso
#' Based on: \url{https://xiaolianglin.com/}
#'
#' @export
nest_gene_tibble <- function(tibble) {
  # remember the initial sorting
  initial_sort <- tibble %>%
    dplyr::select(symbol, hgnc_id, entities_count) %>%
    unique()

  # nest then re-apply the sorting
  nested_tibble <- tibble %>%
    tidyr::nest(.by = c(symbol, hgnc_id, entities_count), .key = "entities") %>%
    arrange(factor(symbol, levels = initial_sort$symbol))

  return(nested_tibble)
}


#' Nest PubTator Gene Tibble
#'
#' @description
#' Groups a PubTator data frame by gene-related columns (e.g. `gene_name`,
#' `gene_symbol`, `hgnc_id`, `gene_normalized_id`). Then creates two
#' nested list-columns:
#' \itemize{
#'   \item \strong{publications:} pmid, doi, title, journal, date, score, text_hl
#'   \item \strong{entities:} entity_id, disease_ontology_id_version, disease_ontology_name,
#'       hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name,
#'       inheritance_filter, ndd_phenotype, ndd_phenotype_word, entry_date, category, category_id
#' }
#'
#' @param df A data frame (tibble) containing:
#' \itemize{
#'   \item \code{gene_name}, \code{gene_symbol}, \code{hgnc_id}, \code{gene_normalized_id}
#'   \item \code{pmid}, \code{doi}, \code{title}, \code{journal}, \code{date}, \code{score}, \code{text_hl}
#'   \item \code{entity_id}, \code{disease_ontology_id_version}, \code{disease_ontology_name},
#'         \code{hpo_mode_of_inheritance_term}, etc.
#' }
#'
#' @return A \strong{nested tibble} with one row per gene, plus two new list-columns:
#'   \code{publications} and \code{entities}.
#'
#' @examples
#' # Suppose `df_pubtator` has all required columns:
#' # nest_pubtator_gene_tibble(df_pubtator)
#'
#' @export
nest_pubtator_gene_tibble <- function(df) {
  df %>%
    dplyr::group_by(
      gene_name,
      gene_symbol,
      hgnc_id,
      gene_normalized_id
    ) %>%
    tidyr::nest(
      publications = c(
        pmid, doi, title, journal, date, score, text_hl
      ),
      entities = c(
        entity_id, disease_ontology_id_version, disease_ontology_name,
        hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name,
        inheritance_filter, ndd_phenotype, ndd_phenotype_word,
        entry_date, category, category_id
      )
    ) %>%
    dplyr::ungroup()
}


#' Extract vario_id filter from filter string
#'
#' @description
#' Parses a filter string and extracts any vario_id or modifier_variant_id filter
#' values. Both field names are supported for backward compatibility.
#' The filter is handled separately because variant data is stored in a join table
#' (ndd_review_variation_ontology_connect) rather than directly in the entity view.
#'
#' @param filter_string A character string containing the filter conditions.
#'
#' @return A list with:
#'   - vario_ids: Character vector of extracted vario_id values (empty if none)
#'   - filter_without_vario: The filter string with variant filters removed
#'   - has_vario_filter: Logical indicating if variant filter was found
#'
#' @examples
#' extract_vario_filter("any(category,Definitive),any(vario_id,VariO:0001,VariO:0002)")
#' # Returns: list(vario_ids = c("VariO:0001", "VariO:0002"),
#' #               filter_without_vario = "any(category,Definitive)",
#' #               has_vario_filter = TRUE)
#'
#' @export
extract_vario_filter <- function(filter_string) {
  # Default return for empty or null filter
  if (is.null(filter_string) || filter_string == "" || filter_string == "null") {
    return(list(
      vario_ids = character(0),
      filter_without_vario = filter_string,
      has_vario_filter = FALSE
    ))
  }

  # URL decode
  filter_string <- URLdecode(filter_string) %>%
    str_trim()

  # Pattern to match variant filters: vario_id or modifier_variant_id (legacy alias)
  # Supports: any(vario_id,...), all(vario_id,...), any(modifier_variant_id,...), etc.
  vario_pattern <- "(any|all)\\((vario_id|modifier_variant_id),([^)]+)\\)"

  # Extract variant filter matches
  vario_matches <- str_match_all(filter_string, vario_pattern)[[1]]

  if (nrow(vario_matches) == 0) {
    return(list(
      vario_ids = character(0),
      filter_without_vario = filter_string,
      has_vario_filter = FALSE
    ))
  }

  # Extract all vario_id values from all matches (column 4 contains the values)
  all_vario_ids <- character(0)
  for (i in seq_len(nrow(vario_matches))) {
    values <- str_split(vario_matches[i, 4], ",")[[1]] %>%
      str_trim() %>%
      str_remove_all("'")
    all_vario_ids <- c(all_vario_ids, values)
  }
  all_vario_ids <- unique(all_vario_ids)

  # Remove variant filters from the filter string
  filter_without_vario <- str_remove_all(filter_string, vario_pattern) %>%
    # Clean up consecutive commas and leading/trailing commas
    str_replace_all(",{2,}", ",") %>%
    str_remove("^,") %>%
    str_remove(",$") %>%
    str_trim()

  return(list(
    vario_ids = all_vario_ids,
    filter_without_vario = filter_without_vario,
    has_vario_filter = TRUE
  ))
}


#' Get entity IDs that have specified variation ontology terms
#'
#' @description
#' Queries the database to find all entity_ids that have at least one of the
#' specified vario_ids in their primary review's variation ontology connections.
#' Uses the ndd_review_variant_connect_view which already filters for is_primary=1
#' and is_active=1, matching the variant count endpoint behavior.
#'
#' @param vario_ids Character vector of vario_id values to filter by.
#' @param pool Database pool connection.
#'
#' @return Integer vector of entity_ids that match the variant filter.
#'
#' @examples
#' \dontrun{
#' entity_ids <- get_entity_ids_by_vario(c("VariO:0001", "VariO:0002"), pool)
#' }
#'
#' @export
get_entity_ids_by_vario <- function(vario_ids, pool) {
  if (length(vario_ids) == 0) {
    return(integer(0))
  }

  # Use the same view as variant count endpoint for consistency
  # The view already filters for is_primary=1 and is_active=1
  matching_entities <- pool %>%
    tbl("ndd_review_variant_connect_view") %>%
    filter(vario_id %in% !!vario_ids) %>%
    dplyr::select(entity_id) %>%
    distinct() %>%
    collect() %>%
    pull(entity_id)

  return(matching_entities)
}
