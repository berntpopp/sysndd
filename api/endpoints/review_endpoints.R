# api/endpoints/review_endpoints.R
#
# This file contains all Review-related endpoints, extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions where
# possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Make sure to source any required helpers if needed (e.g., 
# source("functions/database-functions.R", local = TRUE)).

##-------------------------------------------------------------------##
## Review endpoints
##-------------------------------------------------------------------##

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
#*
#* # `Return`
#* Returns a status and message summarizing the operations performed.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param re_review Boolean: indicates if it's a re-review scenario.
#*
#* @response 200 OK. 
#* @response 400 Bad Request if synopsis data is empty.
#* @response 403 Forbidden if no write access.
#* @response 405 Method Not Allowed for invalid HTTP method.
#*
#* @post /create
#* @put /update
function(req, res, re_review = FALSE) {
  if (req$user_role %in% c("Administrator", "Curator", "Reviewer")) {
    re_review <- as.logical(re_review)
    review_user_id <- req$user_id
    review_data <- req$argsBody$review_json

    if (!is.null(review_data$synopsis) &&
        !is.null(review_data$entity_id) &&
        nchar(review_data$synopsis) > 0) {
      # Publications
      if (length(compact(review_data$literature)) > 0) {
        publications_received <- bind_rows(
          tibble::as_tibble(compact(review_data$literature$additional_references)),
          tibble::as_tibble(compact(review_data$literature$gene_review)),
          .id = "publication_type"
        ) %>%
          dplyr::select(publication_id = value, publication_type) %>%
          mutate(
            publication_type = case_when(
              publication_type == 1 ~ "additional_references",
              publication_type == 2 ~ "gene_review"
            )
          ) %>%
          unique() %>%
          arrange(publication_id) %>%
          mutate(publication_id = str_replace_all(publication_id, "\\s", "")) %>%
          rowwise() %>%
          mutate(gr_check = genereviews_from_pmid(publication_id, check = TRUE)) %>%
          ungroup() %>%
          mutate(
            publication_type = case_when(
              publication_type == "additional_references" & gr_check ~ "gene_review",
              publication_type == "gene_review" & !gr_check ~ "additional_references",
              TRUE ~ publication_type
            )
          ) %>%
          dplyr::select(-gr_check)
      } else {
        publications_received <- tibble::as_tibble_row(
          c(publication_id = NA, publication_type = NA)
        )
      }

      # Synopsis
      if (!is.null(review_data$comment)) {
        sysnopsis_received <- tibble::as_tibble(review_data$synopsis) %>%
          add_column(review_data$entity_id) %>%
          add_column(review_data$comment) %>%
          add_column(review_user_id) %>%
          dplyr::select(
            entity_id = `review_data$entity_id`,
            synopsis = value,
            review_user_id,
            comment = `review_data$comment`
          )
      } else {
        sysnopsis_received <- tibble::as_tibble(review_data$synopsis) %>%
          add_column(review_data$entity_id) %>%
          add_column(review_user_id) %>%
          dplyr::select(
            entity_id = `review_data$entity_id`,
            synopsis = value,
            review_user_id,
            comment = NULL
          )
      }

      # phenotypes
      phenotypes_received <- tibble::as_tibble(review_data$phenotypes)
      # variation ontology
      variation_received <- tibble::as_tibble(review_data$variation_ontology)

      # Check request method (POST -> new review, PUT -> update existing)
      if (req$REQUEST_METHOD == "POST") {
        response_review <- put_post_db_review(
          req$REQUEST_METHOD,
          sysnopsis_received,
          re_review
        )

        # Publications
        if (length(compact(review_data$literature)) > 0) {
          response_publication <- new_publication(publications_received)
          response_publication_conn <- put_post_db_pub_con(
            req$REQUEST_METHOD,
            publications_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(response_review$entry$review_id)
          )
        } else {
          response_publication <- list(status = 200, message = "OK. Skipped.")
          response_publication_conn <- list(status = 200, message = "OK. Skipped.")
        }

        # Phenotypes
        if (length(compact(phenotypes_received)) > 0) {
          response_phenotype_connections <- put_post_db_phen_con(
            req$REQUEST_METHOD,
            phenotypes_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(response_review$entry$review_id)
          )
        } else {
          response_phenotype_connections <- list(status = 200, message = "OK. Skipped.")
        }

        # Variation
        if (length(compact(variation_received)) > 0) {
          resp_variation_ontology_conn <- put_post_db_var_ont_con(
            req$REQUEST_METHOD,
            variation_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(response_review$entry$review_id)
          )
        } else {
          resp_variation_ontology_conn <- list(status = 200, message = "OK. Skipped.")
        }

        # Summarize response
        response <- tibble::as_tibble(response_publication) %>%
          bind_rows(tibble::as_tibble(response_review)) %>%
          bind_rows(tibble::as_tibble(response_publication_conn)) %>%
          bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
          bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
          dplyr::select(status, message) %>%
          unique() %>%
          mutate(status = max(status)) %>%
          mutate(message = str_c(message, collapse = "; "))
        return(list(status = response$status, message = response$message))

      } else if (req$REQUEST_METHOD == "PUT") {
        sysnopsis_received$review_id <- review_data$review_id
        response_review <- put_post_db_review(
          req$REQUEST_METHOD,
          sysnopsis_received,
          re_review
        )

        if (length(compact(review_data$literature)) > 0) {
          response_publication <- new_publication(publications_received)
          response_publication_conn <- put_post_db_pub_con(
            req$REQUEST_METHOD,
            publications_received,
            sysnopsis_received$entity_id,
            review_data$review_id
          )
        } else {
          response_publication <- list(status = 200, message = "OK. Skipped.")
          response_publication_conn <- list(status = 200, message = "OK. Skipped.")
        }

        if (length(compact(phenotypes_received)) > 0) {
          response_phenotype_connections <- put_post_db_phen_con(
            req$REQUEST_METHOD,
            phenotypes_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(review_data$review_id)
          )
        } else {
          response_phenotype_connections <- list(status = 200, message = "OK. Skipped.")
        }

        if (length(compact(variation_received)) > 0) {
          resp_variation_ontology_conn <- put_post_db_var_ont_con(
            req$REQUEST_METHOD,
            variation_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(review_data$review_id)
          )
        } else {
          resp_variation_ontology_conn <- list(status = 200, message = "OK. Skipped.")
        }

        response <- tibble::as_tibble(response_publication) %>%
          bind_rows(tibble::as_tibble(response_review)) %>%
          bind_rows(tibble::as_tibble(response_publication_conn)) %>%
          bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
          bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
          dplyr::select(status, message) %>%
          unique() %>%
          mutate(status = max(status)) %>%
          mutate(message = str_c(message, collapse = "; "))
        return(list(status = response$status, message = response$message))

      } else {
        return(list(status = 405, message = "Method Not Allowed."))
      }
    } else {
      res$status <- 400
      return(list(error = "Submitted synopsis data can not be empty."))
    }
  } else {
    res$status <- 403
    return(list(error = "Write access forbidden."))
  }
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
function(review_id_requested) {
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
function(review_id_requested) {
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

  phenotype_list <- ndd_review_phenotype_conn_coll %>%
    filter(review_id %in% review_id_requested & is_active) %>%
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
function(review_id_requested) {
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
function(review_id_requested) {
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

  ndd_entity_publication_list <- review_publication_join_coll %>%
    filter(review_id %in% review_id_requested) %>%
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
  review_ok <- as.logical(review_ok)

  if (length(req$user_id) == 0) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  } else if (req$user_role %in% c("Administrator", "Curator")) {
    submit_user_id <- req$user_id
    response_review_approve <- put_db_review_approve(
      review_id_requested,
      submit_user_id,
      review_ok
    )
    response_review_approve
  } else {
    res$status <- 403
    return(list(error = "Write access forbidden."))
  }
}
