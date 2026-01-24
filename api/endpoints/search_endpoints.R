# api/endpoints/search_endpoints.R
#
# This file contains all search-related endpoints, extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible.

## -------------------------------------------------------------------##
## Search endpoints
## -------------------------------------------------------------------##

#* Search Entity View by Multiple Columns
#*
#* Allows searching the entity_view by entity_id, hgnc_id, symbol, disease_ontology,
#* etc., possibly using fuzzy matching (stringdist).
#*
#* # `Details`
#* If there's a near-perfect match, it returns that. Otherwise returns
#* the top matches, up to 10 by default.
#*
#* # `Return`
#* A set of search results with metadata about the match distance, etc.
#*
#* @tag search
#* @serializer json list(na="string")
#*
#* @param searchterm The search query.
#* @param helper Logical controlling the output format.
#*
#* @get <searchterm>
function(searchterm, helper = TRUE) {
  helper <- as.logical(helper)
  searchterm <- URLdecode(searchterm) %>%
    str_squish()

  sysndd_db_entity_search <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    collect() %>%
    select(
      entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name
    ) %>%
    mutate(entity = as.character(entity_id)) %>%
    pivot_longer(!entity_id, names_to = "search", values_to = "results") %>%
    mutate(search = str_replace(search, "entity", "entity_id")) %>%
    mutate(searchdist = stringdist(
      str_to_lower(results),
      str_to_lower(searchterm),
      method = "jw",
      p = 0.1
    )) %>%
    arrange(searchdist, results) %>%
    mutate(results_url = URLencode(results, reserved = TRUE)) %>%
    mutate(link = case_when(
      search == "hgnc_id" ~ paste0("/Genes/", results_url),
      search == "symbol" ~ paste0("/Genes/", results_url),
      search == "disease_ontology_id_version" ~ paste0("/Ontology/", results_url),
      search == "disease_ontology_name" ~ paste0("/Ontology/", results_url),
      search == "entity_id" ~ paste0("/Entities/", results_url)
    )) %>%
    select(-results_url)

  sysndd_db_entity_search_length <- sysndd_db_entity_search %>%
    filter(searchdist < 0.1) %>%
    tally()

  return_count <- if (sysndd_db_entity_search_length$n > 10) {
    sysndd_db_entity_search_length$n
  } else {
    10
  }

  if (sysndd_db_entity_search$searchdist[1] == 0 &&
        is.na(suppressWarnings(as.integer(sysndd_db_entity_search$results[1])))) {
    sysndd_db_entity_search_return <- sysndd_db_entity_search %>%
      slice_head(n = 1)
  } else {
    sysndd_db_entity_search_return <- sysndd_db_entity_search %>%
      slice_head(n = return_count)
  }

  if (helper) {
    sysndd_db_entity_search_return <- sysndd_db_entity_search_return %>%
      tidyr::nest(.by = c(results), .key = "values") %>%
      ungroup() %>%
      pivot_wider(
        id_cols = everything(),
        names_from = "results",
        values_from = "values"
      )
  } else {
    sysndd_db_entity_search_return
  }
}


#* Search Disease Ontology by ID or Name
#*
#* Fuzzy matching search within the disease_ontology_set table.
#*
#* # `Details`
#* If tree=TRUE, format output for treeselect library. Otherwise
#* pivot wide if multiple results.
#*
#* @tag search
#* @serializer json list(na="string")
#*
#* @param searchterm The query string.
#* @param tree Logical controlling output format.
#*
#* @get ontology/<searchterm>
function(searchterm, tree = FALSE) {
  tree <- as.logical(tree)
  searchterm <- URLdecode(searchterm) %>%
    str_squish()

  do_set_search <- pool %>%
    tbl("search_disease_ontology_set") %>%
    filter(result %like% paste0("%", searchterm, "%")) %>%
    collect() %>%
    mutate(searchdist = stringdist(
      str_to_lower(result),
      str_to_lower(searchterm),
      method = "jw",
      p = 0.1
    )) %>%
    arrange(searchdist, result)

  do_set_search_length <- do_set_search %>%
    filter(searchdist < 0.1) %>%
    tally()

  return_count <- if (do_set_search_length$n > 10) {
    do_set_search_length$n
  } else {
    10
  }

  do_set_search_return <- do_set_search %>%
    slice_head(n = return_count)

  if (tree) {
    do_set_search_return_helper <- do_set_search_return %>%
      select(
        id = disease_ontology_id_version,
        label = result,
        disease_ontology_id_version,
        disease_ontology_id,
        disease_ontology_name,
        search,
        searchdist
      )
  } else {
    do_set_search_return_helper <- do_set_search_return %>%
      tidyr::nest(.by = c(results), .key = "values") %>%
      ungroup() %>%
      pivot_wider(
        id_cols = everything(),
        names_from = "result",
        values_from = "values"
      )
  }

  do_set_search_return_helper
}


#* Search Gene by HGNC ID or Symbol
#*
#* Fuzzy search in the gene set (hgnc_id, symbol).
#*
#* # `Details`
#* If tree=TRUE, format as arrays for treeselect. Otherwise pivot wide.
#*
#* @tag search
#* @serializer json list(na="string")
#*
#* @param searchterm The query string.
#* @param tree Logical controlling output format.
#*
#* @get gene/<searchterm>
function(searchterm, tree = FALSE) {
  tree <- as.logical(tree)
  searchterm <- URLdecode(searchterm) %>%
    str_squish()

  non_alt_loci_set_search <- pool %>%
    tbl("search_non_alt_loci_view") %>%
    filter(result %like% paste0("%", searchterm, "%")) %>%
    collect() %>%
    mutate(searchdist = stringdist(
      str_to_lower(result),
      str_to_lower(searchterm),
      method = "jw",
      p = 0.1
    )) %>%
    arrange(searchdist, result)

  non_alt_loci_set_search_length <- non_alt_loci_set_search %>%
    filter(searchdist < 0.1) %>%
    tally()

  return_count <- if (non_alt_loci_set_search_length$n > 10) {
    non_alt_loci_set_search_length$n
  } else {
    10
  }

  non_alt_loci_set_search_return <- non_alt_loci_set_search %>%
    slice_head(n = return_count)

  if (tree) {
    nal_set_search_return_helper <- non_alt_loci_set_search_return %>%
      select(
        id = hgnc_id,
        label = result,
        symbol,
        name,
        search,
        searchdist
      )
  } else {
    nal_set_search_return_helper <- non_alt_loci_set_search_return %>%
      tidyr::nest(.by = c(results), .key = "values") %>%
      ungroup() %>%
      pivot_wider(
        id_cols = everything(),
        names_from = "result",
        values_from = "values"
      )
  }

  nal_set_search_return_helper
}


#* Search Mode of Inheritance by Term Name or Term
#*
#* Fuzzy matching in mode_of_inheritance_list.
#*
#* # `Details`
#* If tree=TRUE, arrays for treeselect. Otherwise pivot wide.
#*
#* @tag search
#* @serializer json list(na="string")
#*
#* @param searchterm The query string.
#* @param tree Logical controlling output format.
#*
#* @get inheritance/<searchterm>
function(searchterm, tree = FALSE) {
  tree <- as.logical(tree)
  searchterm <- URLdecode(searchterm) %>%
    str_squish()

  moi_list <- pool %>%
    tbl("search_mode_of_inheritance_list_view") %>%
    collect() %>%
    mutate(searchdist = 1)

  moi_list_search <- pool %>%
    tbl("search_mode_of_inheritance_list_view") %>%
    filter(result %like% paste0("%", searchterm, "%")) %>%
    collect() %>%
    mutate(searchdist = stringdist(
      str_to_lower(result),
      str_to_lower(searchterm),
      method = "jw",
      p = 0.1
    )) %>%
    arrange(searchdist, sort)

  moi_list_search_length <- moi_list_search %>%
    filter(searchdist < 0.1) %>%
    tally()

  return_count <- if (moi_list_search_length$n > 10) {
    moi_list_search_length$n
  } else {
    10
  }

  moi_list_search_return <- moi_list_search %>%
    slice_head(n = return_count)

  if (tree) {
    moi_list_search_return_helper <- moi_list_search_return %>%
      select(
        id = hpo_mode_of_inheritance_term,
        label = result,
        search,
        searchdist
      )
  } else {
    moi_list_search_return_helper <- moi_list_search_return %>%
      tidyr::nest(.by = c(results), .key = "values") %>%
      ungroup() %>%
      pivot_wider(
        id_cols = everything(),
        names_from = "result",
        values_from = "values"
      )
  }

  moi_list_search_return_helper
}
