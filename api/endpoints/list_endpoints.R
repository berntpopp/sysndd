# api/endpoints/list_endpoints.R
#
# This file contains all "list" endpoints, extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible.

## -------------------------------------------------------------------##
## List endpoints
## -------------------------------------------------------------------##

#* Get All Status Categories
#*
#* Retrieves a list of all status categories from the
#* ndd_entity_status_categories_list table.
#*
#* # `Return`
#* Returns a list of status categories.
#*
#* @tag list
#* @serializer json list(na="string")
#*
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of status categories.
#*
#* @get status
function(tree = FALSE) {
  tree <- as.logical(tree)

  status_list_collected <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    arrange(category_id) %>%
    collect()

  if (tree) {
    # Format for treeselect library: id and label columns
    status_list_return_helper <- status_list_collected %>%
      select(id = category_id, label = category)
  } else {
    # Return raw data structure
    status_list_return_helper <- status_list_collected
  }

  status_list_return_helper
}


#* Get All Phenotypes
#*
#* This endpoint retrieves a list of all phenotypes.
#*
#* # `Return`
#* Returns a list of phenotypes. If 'tree' is TRUE,
#* returns them in a nested structure with modifiers.
#*
#* @tag list
#* @serializer json list(na="string")
#*
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of phenotypes.
#*
#* @get phenotype
function(tree = FALSE) {
  tree <- as.logical(tree)

  if (tree) {
    modifier_list_collected <- pool %>%
      tbl("modifier_list") %>%
      filter(allowed_phenotype) %>%
      select(modifier_id, modifier_name) %>%
      arrange(modifier_id) %>%
      collect()

    phenotype_list_collected <- pool %>%
      tbl("phenotype_list") %>%
      select(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms) %>%
      arrange(HPO_term) %>%
      collect() %>%
      mutate(children = list(modifier_list_collected)) %>%
      unnest(children) %>%
      filter(modifier_id != 1) %>%
      mutate(id = paste0(modifier_id, "-", phenotype_id)) %>%
      mutate(label = paste0(modifier_name, ": ", HPO_term)) %>%
      select(-modifier_id, -modifier_name) %>%
      nest(data = c(id, label)) %>%
      mutate(phenotype_id = paste0("1-", phenotype_id)) %>%
      mutate(HPO_term = paste0("present: ", HPO_term)) %>%
      select(id = phenotype_id, label = HPO_term, children = data)
  } else {
    phenotype_list_collected <- pool %>%
      tbl("phenotype_list") %>%
      select(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms) %>%
      arrange(HPO_term) %>%
      collect()
  }

  phenotype_list_collected
}


#* Get All Inheritance Terms
#*
#* This endpoint retrieves a list of all inheritance terms.
#*
#* # `Return`
#* Returns a list of inheritance terms.
#*
#* @tag list
#* @serializer json list(na="string")
#*
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of inheritance terms.
#*
#* @get inheritance
function(tree = FALSE) {
  tree <- as.logical(tree)

  moi_list_collected <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    arrange(hpo_mode_of_inheritance_term) %>%
    collect() %>%
    filter(is_active == 1) %>%
    select(-is_active, -update_date)

  if (tree) {
    moi_list_return_helper <- moi_list_collected %>%
      select(
        id = hpo_mode_of_inheritance_term,
        label = hpo_mode_of_inheritance_term_name
      )
  } else {
    moi_list_return_helper <- moi_list_collected %>%
      tidyr::nest(.by = c(hpo_mode_of_inheritance_term), .key = "values") %>%
      ungroup() %>%
      pivot_wider(
        id_cols = everything(),
        names_from = "hpo_mode_of_inheritance_term",
        values_from = "values"
      )
  }

  moi_list_return_helper
}


#* Get All Variation Ontology Terms
#*
#* This endpoint retrieves a list of all variation ontology terms.
#*
#* # `Return`
#* Returns a list of variation ontology terms.
#*
#* @tag list
#* @serializer json list(na="string")
#*
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of variation ontology terms.
#*
#* @get variation_ontology
function(tree = FALSE) {
  tree <- as.logical(tree)

  if (tree) {
    modifier_list_collected <- pool %>%
      tbl("modifier_list") %>%
      filter(allowed_variation) %>%
      select(modifier_id, modifier_name) %>%
      arrange(modifier_id) %>%
      collect()

    variation_ontology_list_coll <- pool %>%
      tbl("variation_ontology_list") %>%
      filter(is_active) %>%
      select(vario_id, vario_name, definition, sort) %>%
      arrange(sort) %>%
      collect() %>%
      select(-sort) %>%
      mutate(children = list(modifier_list_collected)) %>%
      unnest(children) %>%
      filter(modifier_id != 1) %>%
      mutate(id = paste0(modifier_id, "-", vario_id)) %>%
      mutate(label = paste0(modifier_name, ": ", vario_name)) %>%
      select(-modifier_id, -modifier_name) %>%
      nest(data = c(id, label)) %>%
      mutate(vario_id = paste0("1-", vario_id)) %>%
      mutate(vario_name = paste0("present: ", vario_name)) %>%
      select(id = vario_id, label = vario_name, children = data)
  } else {
    variation_ontology_list_coll <- pool %>%
      tbl("variation_ontology_list") %>%
      select(vario_id, vario_name, definition, sort) %>%
      arrange(sort) %>%
      collect() %>%
      select(-sort)
  }

  variation_ontology_list_coll
}

## List endpoints
## -------------------------------------------------------------------##
