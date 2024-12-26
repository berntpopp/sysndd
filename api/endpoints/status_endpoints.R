# api/endpoints/status_endpoints.R
#
# This file contains all Status-related endpoints, extracted from the 
# original sysndd_plumber.R. It follows the Google R Style Guide 
# conventions where possible.

##-------------------------------------------------------------------##
## Status endpoints
##-------------------------------------------------------------------##

#* Get the Status List
#*
#* Retrieves the status list for entities, optionally filtered by approval.
#*
#* # `Details`
#* Joins with user, gene/disease info, etc. to produce a wide table of statuses.
#*
#* # `Return`
#* Returns a list of statuses matching the filter_status_approved param.
#*
#* @tag status
#* @serializer json list(na="null")
#*
#* @param filter_status_approved Boolean for filtering by status_approved.
#*
#* @get /
function(req, res, filter_status_approved = FALSE) {
  filter_status_approved <- as.logical(filter_status_approved)

  entity_status_categories_coll <- pool %>%
    tbl("ndd_entity_status_categories_list")

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, user_role)

  non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, symbol)

  disease_ontology_set <- pool %>%
    tbl("disease_ontology_set") %>%
    select(
      disease_ontology_id,
      disease_ontology_id_version,
      disease_ontology_name
    )

  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    select(-is_active, -sort)

  ndd_entity_status_approved_view <- pool %>%
    tbl("ndd_entity_status_approved_view") %>%
    select(entity_id, status_approved, category_id)

  ndd_entity_status_categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list")

  boolean_list <- pool %>%
    tbl("boolean_list")

  ndd_entity_tbl <- pool %>%
    tbl("ndd_entity") %>%
    left_join(non_alt_loci_set, by = c("hgnc_id")) %>%
    left_join(disease_ontology_set, by = c("disease_ontology_id_version")) %>%
    left_join(mode_of_inheritance_list, by = c("hpo_mode_of_inheritance_term")) %>%
    left_join(ndd_entity_status_approved_view, by = c("entity_id")) %>%
    left_join(ndd_entity_status_categories_list, by = c("category_id")) %>%
    left_join(boolean_list, by = c("ndd_phenotype" = "logical")) %>%
    select(
      entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name,
      hpo_mode_of_inheritance_term,
      hpo_mode_of_inheritance_term_name
    )

  status_table_collected <- pool %>%
    tbl("ndd_entity_status") %>%
    inner_join(entity_status_categories_coll, by = c("category_id")) %>%
    left_join(user_table, by = c("status_user_id" = "user_id")) %>%
    left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
    left_join(ndd_entity_tbl, by = c("entity_id")) %>%
    filter(status_approved == filter_status_approved) %>%
    collect() %>%
    select(
      status_id,
      entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name,
      hpo_mode_of_inheritance_term,
      hpo_mode_of_inheritance_term_name,
      category,
      category_id,
      is_active,
      status_date,
      status_user_name = user_name.x,
      status_user_role = user_role.x,
      status_approved,
      approving_user_name = user_name.y,
      approving_user_role = user_role.y,
      approving_user_id,
      comment,
      problematic
    ) %>%
    arrange(entity_id, status_date) %>%
    group_by(entity_id) %>%
    mutate(duplicate = n()) %>%
    mutate(
      duplicate = case_when(
        duplicate == 1 ~ "no",
        TRUE ~ "yes"
      )
    ) %>%
    ungroup()

  review_table <- pool %>%
    tbl("ndd_entity_review") %>%
    collect() %>%
    filter(entity_id %in% status_table_collected$entity_id) %>%
    select(entity_id, review_id, is_primary, review_date) %>%
    arrange(entity_id) %>%
    group_by(entity_id) %>%
    mutate(active_review = case_when(
      is_primary == max(is_primary) ~ review_id
    )) %>%
    mutate(newest_review = case_when(
      review_date == max(review_date) ~ review_id
    )) %>%
    select(entity_id, active_review, newest_review) %>%
    mutate(
      active_review = max(active_review, na.rm = TRUE),
      newest_review = max(newest_review, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    unique() %>%
    mutate(review_change = as.numeric(!(active_review == newest_review)))

  status_table_collected <- status_table_collected %>%
    left_join(review_table, by = c("entity_id"))

  status_table_collected
}


#* Get Single Status by Status ID
#*
#* Retrieves detailed info for a specific status ID.
#*
#* # `Details`
#* Joins with user and status category tables.
#*
#* @tag status
#* @serializer json list(na="null")
#*
#* @param status_id_requested The ID of the status to retrieve.
#*
#* @response 200 OK. Returns the status data.
#*
#* @get /<status_id_requested>
function(status_id_requested) {
  status_id_requested <- URLdecode(status_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  sysndd_db_status_table <- pool %>%
    tbl("ndd_entity_status")

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, user_role)

  entity_status_categories_coll <- pool %>%
    tbl("ndd_entity_status_categories_list")

  status_table_collected <- sysndd_db_status_table %>%
    filter(status_id %in% status_id_requested) %>%
    inner_join(entity_status_categories_coll, by = c("category_id")) %>%
    left_join(user_table, by = c("status_user_id" = "user_id")) %>%
    left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
    collect() %>%
    select(
      status_id,
      entity_id,
      category,
      category_id,
      is_active,
      status_date,
      status_user_name = user_name.x,
      status_user_role = user_role.x,
      status_approved,
      approving_user_name = user_name.y,
      approving_user_role = user_role.y,
      comment,
      problematic
    ) %>%
    arrange(status_date)

  status_table_collected
}


#* Get List of All Status
#*
#* Retrieves all status categories from ndd_entity_status_categories_list.
#*
#* # `Return`
#* Returns the list of categories.
#*
#* @tag status
#* @serializer json list(na="string")
#*
#* @response 200 OK. 
#*
#* @get _list
function() {
  status_list_collected <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    arrange(category_id) %>%
    collect()

  status_list_collected
}


#* Create or Update Entity Status
#*
#* Allows creating a new status or updating an existing one for a given entity.
#* Accessible by Admin, Curator, Reviewer.
#*
#* @tag status
#* @serializer json list(na="string")
#*
#* @param re_review Boolean indicating a re-review scenario.
#*
#* @post /create
#* @put /update
function(req, res, re_review = FALSE) {
  if (req$user_role %in% c("Administrator", "Curator", "Reviewer")) {
    re_review <- as.logical(re_review)
    status_data <- req$argsBody$status_json
    status_data$status_user_id <- req$user_id

    response <- put_post_db_status(
      req$REQUEST_METHOD,
      status_data,
      re_review
    )

    res$status <- response$status
    return(response)
  } else {
    res$status <- 403
    return(list(error = "Write access forbidden."))
  }
}


#* Approve Entity Status
#*
#* Allows Admin/Curator to approve a given status by status_id.
#*
#* # `Details`
#* If status_ok=TRUE, sets the status to approved, else unapproves it.
#*
#* @tag status
#* @serializer json list(na="string")
#*
#* @response 200 OK. 
#* @response 401 or 403 if not authenticated or unauthorized.
#*
#* @put /approve/<status_id_requested>
function(req, res, status_id_requested, status_ok = FALSE) {
  status_ok <- as.logical(status_ok)

  if (length(req$user_id) == 0) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  } else if (req$user_role %in% c("Administrator", "Curator")) {
    submit_user_id <- req$user_id
    response_status_approve <- put_db_status_approve(
      status_id_requested,
      submit_user_id,
      status_ok
    )
    response_status_approve
  } else {
    res$status <- 403
    return(list(error = "Write access forbidden."))
  }
}
