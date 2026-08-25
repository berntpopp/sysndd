# api/endpoints/review_endpoints.R
#
# This file contains all Review-related endpoints, extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions where
# possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Make sure to source any required helpers if needed (e.g.,
# source("functions/database-functions.R", local = TRUE)).

## -------------------------------------------------------------------##
## Review endpoints
## -------------------------------------------------------------------##

#* Get Review List
#*
#* This endpoint retrieves the list of reviews. It can optionally filter
#* by approval status (review_approved).
#*
#* # `Details`
#* Fetches data from multiple tables, including user, gene, disease, inheritance,
#* approval status, etc., and returns the combined dataset.
#*
#* # `Return`
#* A list of reviews that match the applied filter.
#*
#* @tag review
#* @serializer json list(na="null")
#*
#* @param filter_review_approved Boolean: whether to filter by approved status.
#*
#* @response 200 OK. Returns a list of matching reviews.
#*
#* @get /
function(req, res, filter_review_approved = FALSE) {
  require_role(req, res, "Reviewer")

  # Ensure logical
  filter_review_approved <- as.logical(filter_review_approved)

  # user
  user_table <- pool %>%
    tbl("user") %>%
    dplyr::select(user_id, user_name, user_role)

  # gene
  non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    dplyr::select(hgnc_id, symbol)

  # disease
  disease_ontology_set <- pool %>%
    tbl("disease_ontology_set") %>%
    dplyr::select(
      disease_ontology_id,
      disease_ontology_id_version,
      disease_ontology_name
    )

  # moi
  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    dplyr::select(-is_active, -sort)

  # approved status
  ndd_entity_status_approved_view <- pool %>%
    tbl("ndd_entity_status_approved_view") %>%
    dplyr::select(entity_id, status_approved, category_id)

  # categories
  ndd_entity_status_categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list")

  # boolean
  boolean_list <- pool %>%
    tbl("boolean_list")

  # Entity table
  ndd_entity_tbl <- pool %>%
    tbl("ndd_entity") %>%
    left_join(non_alt_loci_set, by = c("hgnc_id")) %>%
    left_join(disease_ontology_set, by = c("disease_ontology_id_version")) %>%
    left_join(mode_of_inheritance_list, by = c("hpo_mode_of_inheritance_term")) %>%
    left_join(ndd_entity_status_approved_view, by = c("entity_id")) %>%
    left_join(ndd_entity_status_categories_list, by = c("category_id")) %>%
    left_join(boolean_list, by = c("ndd_phenotype" = "logical")) %>%
    dplyr::select(
      entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name,
      hpo_mode_of_inheritance_term,
      hpo_mode_of_inheritance_term_name
    )

  # join and filter
  review_table_collected <- pool %>%
    tbl("ndd_entity_review") %>%
    left_join(user_table, by = c("review_user_id" = "user_id")) %>%
    left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
    left_join(ndd_entity_tbl, by = c("entity_id")) %>%
    filter(review_approved == filter_review_approved) %>%
    {
      if (!filter_review_approved) filter(., is.na(approving_user_id)) else .
    } %>%
    collect() %>%
    dplyr::select(
      review_id,
      entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name,
      hpo_mode_of_inheritance_term,
      hpo_mode_of_inheritance_term_name,
      synopsis,
      is_primary,
      review_date,
      review_user_name = user_name.x,
      review_user_role = user_role.x,
      review_approved,
      approving_user_name = user_name.y,
      approving_user_role = user_role.y,
      approving_user_id,
      comment
    ) %>%
    arrange(entity_id, review_date) %>%
    group_by(entity_id) %>%
    mutate(duplicate = n()) %>%
    mutate(
      duplicate = case_when(
        duplicate == 1 ~ "no",
        TRUE ~ "yes"
      )
    ) %>%
    ungroup()

  # status table
  status_table <- pool %>%
    tbl("ndd_entity_status") %>%
    collect() %>%
    filter(entity_id %in% review_table_collected$entity_id) %>%
    dplyr::select(entity_id, status_id, category_id, is_active, status_date) %>%
    arrange(entity_id) %>%
    group_by(entity_id) %>%
    mutate(
      active_status = case_when(is_active == max(is_active) ~ status_id),
      active_category = case_when(is_active == max(is_active) ~ category_id)
    ) %>%
    mutate(
      newest_status = case_when(status_date == max(status_date) ~ status_id),
      newest_category = case_when(status_date == max(status_date) ~ category_id)
    ) %>%
    dplyr::select(
      entity_id,
      active_status,
      active_category,
      newest_status,
      newest_category
    ) %>%
    mutate(
      active_status = max(active_status, na.rm = TRUE),
      active_category = max(active_category, na.rm = TRUE),
      newest_status = max(newest_status, na.rm = TRUE),
      newest_category = max(newest_category, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    unique() %>%
    mutate(status_change = as.numeric(!(active_status == newest_status)))

  review_table_collected <- review_table_collected %>%
    left_join(status_table, by = c("entity_id"))

  review_table_collected
}


#* Create or Update a Clinical Synopsis for an Entity
#*
#* Handles creating or updating a clinical synopsis for a specified entity ID.
#*
#* # `Details`
#* POST to create a new review, PUT to update an existing one.
#* Also handles publications, phenotypes, variation ontology.
#* When `direct_approval=TRUE` the freshly written review is approved in the
#* same request (mirrors the entity-create direct-approval flow). Direct
#* approval is a Curator+ action, so the handler escalates the role gate to
#* Curator before approving; Reviewer callers that request direct approval are
#* rejected with 403.
#*
#* # `Return`
#* Returns a status and message summarizing the operations performed.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param re_review Boolean: indicates if it's a re-review scenario.
#* @param direct_approval Boolean for Curator+ direct approval. Defaults to FALSE.
#*
#* @response 200 OK.
#* @response 400 Bad Request if synopsis data is empty.
#* @response 403 Forbidden if no write access.
#* @response 405 Method Not Allowed for invalid HTTP method.
#*
#* @post /create
#* @put /update
function(req, res, re_review = FALSE, direct_approval = FALSE) {
  require_role(req, res, "Reviewer")

  re_review <- as.logical(re_review)
  direct_approval <- as.logical(direct_approval)
  if (is.na(direct_approval)) direct_approval <- FALSE

  # Direct approval is a Curator+ action; never trust the client's flag alone.
  if (isTRUE(direct_approval)) {
    require_role(req, res, "Curator")
  }

  review_user_id <- req$user_id
  review_data <- req$argsBody$review_json
  if (!(req$REQUEST_METHOD %in% c("POST", "PUT"))) {
    return(list(status = 405L, message = "Method Not Allowed."))
  }

  # #635: extracted to functions/review-literature-parsing.R so the positional
  # `bind_rows(.id = )` contract that maps frame 1 -> additional_references and
  # frame 2 -> gene_review is unit-tested across all four populated/empty
  # combinations. An empty block yields zero rows, which review_write_mutate()
  # reads on PUT as "remove every publication from this review".
  publications <- review_write_literature_to_publications(review_data$literature)

  response <- svc_review_write(
    method = req$REQUEST_METHOD,
    review_data = review_data,
    publications = publications,
    phenotypes = review_data$phenotypes,
    variation_ontology = review_data$variation_ontology,
    re_review = re_review,
    direct_approval = direct_approval,
    review_user_id = review_user_id,
    db = pool
  )
  res$status <- response$status
  response
}


#* Get a Single Review by review_id
#*
#* Retrieves a single review given its review_id.
#*
#* # `Details`
#* Decodes the review_id, queries the DB, returns the record.
#*
#* # `Return`
#* Returns the review table row matching the specified ID.
#*
#* @tag review
#* @serializer json list(na="null")
#*
#* @param review_id_requested The review_id to retrieve.
#*
#* @response 200 OK. Returns the review data.
#*
#* @get /<review_id_requested>
function(req, res, review_id_requested) {
  require_role(req, res, "Reviewer")

  review_id_requested <- URLdecode(review_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  sysndd_db_review_table <- pool %>%
    tbl("ndd_entity_review")

  user_table <- pool %>%
    tbl("user") %>%
    dplyr::select(user_id, user_name, user_role)

  review_table_collected <- sysndd_db_review_table %>%
    filter(review_id %in% review_id_requested) %>%
    left_join(user_table, by = c("review_user_id" = "user_id")) %>%
    left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
    collect() %>%
    dplyr::select(
      review_id,
      entity_id,
      synopsis,
      is_primary,
      review_date,
      review_user_name = user_name.x,
      review_user_role = user_role.x,
      review_approved,
      approving_user_name = user_name.y,
      approving_user_role = user_role.y,
      comment
    )

  review_table_collected
}


#* Get All Phenotypes for a Review
#*
#* Retrieves all phenotypes associated with a specific review_id.
#*
#* # `Details`
#* Queries ndd_review_phenotype_connect and phenotype_list.
#*
#* # `Return`
#* A list of phenotypes for the given review_id.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param review_id_requested The review_id to retrieve phenotypes for.
#*
#* @response 200 OK. Returns a list of phenotypes.
#*
#* @get /<review_id_requested>/phenotypes
function(req, res, review_id_requested) {
  require_role(req, res, "Reviewer")

  review_id_requested <- URLdecode(review_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  ndd_review_phenotype_conn_coll <- pool %>%
    tbl("ndd_review_phenotype_connect") %>%
    collect()

  phenotype_list_collected <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  # A connect row names its entity twice: in `entity_id`, and via the entity
  # owning `review_id`. Migration 051 makes disagreement impossible in MySQL,
  # but this read must not depend on that -- fixtures and SQLite-backed
  # environments have no such constraint, and the guard in 051 deliberately
  # skips a database restored from a pre-repair dump. Showing a foreign row
  # here is not merely cosmetic: saving a review DELETEs by review_id and
  # re-inserts the submitted form, so anything displayed under the wrong review
  # is re-attributed to the wrong entity on the next save (admin#19).
  review_entity <- pool %>%
    tbl("ndd_entity_review") %>%
    dplyr::select(review_id, review_entity_id = entity_id) %>%
    collect()

  phenotype_list <- ndd_review_phenotype_conn_coll %>%
    filter(review_id %in% review_id_requested & is_active) %>%
    inner_join(review_entity, by = c("review_id")) %>%
    filter(entity_id == review_entity_id) %>%
    inner_join(phenotype_list_collected, by = c("phenotype_id")) %>%
    dplyr::select(review_id, entity_id, phenotype_id, HPO_term, modifier_id) %>%
    arrange(phenotype_id)

  phenotype_list
}


#* Get All Variant Ontology Terms for a Review
#*
#* Retrieves all variant ontology terms for a specific review.
#*
#* # `Details`
#* Similar approach as phenotypes; joins variation_ontology_list.
#*
#* # `Return`
#* A list of variant ontology terms.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param review_id_requested The review_id for which to retrieve variant ontology.
#*
#* @response 200 OK. Returns the list of variant ontology terms.
#*
#* @get /<review_id_requested>/variation
function(req, res, review_id_requested) {
  require_role(req, res, "Reviewer")

  review_id_requested <- URLdecode(review_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  review_variation_ontology_con <- pool %>%
    tbl("ndd_review_variation_ontology_connect") %>%
    collect()

  variation_ontology_list_col <- pool %>%
    tbl("variation_ontology_list") %>%
    collect()

  variation_list <- review_variation_ontology_con %>%
    filter(review_id %in% review_id_requested & is_active) %>%
    inner_join(variation_ontology_list_col, by = c("vario_id")) %>%
    dplyr::select(review_id, entity_id, vario_id, vario_name, modifier_id) %>%
    arrange(vario_id)

  variation_list
}


#* Get All Publications for a Review
#*
#* Retrieves all publications associated with a specific review.
#*
#* # `Details`
#* Queries ndd_review_publication_join, returning relevant publication info.
#*
#* # `Return`
#* A list of publications for the given review_id.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param review_id_requested The review_id for which to retrieve publications.
#*
#* @response 200 OK. Returns the publications.
#*
#* @get /<review_id_requested>/publications
function(req, res, review_id_requested) {
  require_role(req, res, "Reviewer")

  review_id_requested <- URLdecode(review_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  review_publication_join_coll <- pool %>%
    tbl("ndd_review_publication_join") %>%
    collect()

  publication_collected <- pool %>%
    tbl("publication") %>%
    collect()

  # Same entity-agreement guard as the phenotype read above (admin#19).
  review_entity <- pool %>%
    tbl("ndd_entity_review") %>%
    dplyr::select(review_id, review_entity_id = entity_id) %>%
    collect()

  ndd_entity_publication_list <- review_publication_join_coll %>%
    filter(review_id %in% review_id_requested) %>%
    inner_join(review_entity, by = c("review_id")) %>%
    filter(entity_id == review_entity_id) %>%
    dplyr::select(-review_entity_id) %>%
    arrange(publication_id)

  ndd_entity_publication_list
}


#* Put the Review Approval
#*
#* Updates the approval status of a review. Only Admin/Curator.
#*
#* # `Details`
#* Calls put_db_review_approve(review_id_requested, submit_user_id, review_ok).
#*
#* # `Return`
#* Status of the operation.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param review_id_requested The review_id to be approved.
#* @param review_ok Boolean indicating approval status.
#*
#* @put /approve/<review_id_requested>
function(req, res, review_id_requested, review_ok = FALSE) {
  require_role(req, res, "Curator")

  review_ok <- as.logical(review_ok)
  submit_user_id <- req$user_id

  response_review_approve <- svc_approval_review_approve(
    review_id_requested,
    submit_user_id,
    review_ok,
    pool
  )
  response_review_approve
}
