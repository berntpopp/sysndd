# api/endpoints/entity_endpoints.R
#
# This file contains all Entity-related endpoints, extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions where possible
# (e.g., two-space indentation, meaningful function names, etc.).

## -------------------------------------------------------------------##
## Entity endpoints
## -------------------------------------------------------------------##

#* Get a Cursor Pagination Object of All Entities
#*
#* This endpoint returns a cursor pagination object of all entities based on the
#* data in the database.
#*
#* # `Details`
#* This is a plumber endpoint function that retrieves paginated data from a
#* database table and returns it as a JSON response. The function takes input
#* parameters for sorting, filtering, and field selection, and uses cursor
#* pagination to generate links to previous and next pages.
#* It retrieves data from two tables in the database, filters and sorts the data
#* based on input parameters, selects fields for inclusion in the response, and
#* generates pagination information and fields specifications.
#* The function adds meta and link information to the response and computes
#* execution time before returning the paginated data as a list.
#*
#* # `Return`
#* A cursor pagination object containing a list of entities.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sort:str Output column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#* @param fields:str Comma separated list of output columns.
#* @param page_after:str Cursor after which entries are shown.
#* @param page_size:str Page size in cursor pagination.
#* @param fspec:str Fields to generate field specification for.
#*
#* @response 200 OK. A cursor pagination object with links, meta and data (entity objects).
#* @response 500 Internal server error.
#*
#* @get /
function(req,
         res,
         sort = "entity_id",
         filter = "",
         fields = "",
         page_after = 0,
         page_size = "10",
         fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details", # nolint: line_length_linter
         format = "json") {
  # Set serializers
  res$serializer <- serializers[[format]]

  # Start time calculation
  start_time <- Sys.time()

  # Generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "entity_id")

  # Generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # Get review data from database
  ndd_entity_review <- pool %>%
    tbl("ndd_entity_review") %>%
    filter(is_primary) %>%
    dplyr::select(entity_id, synopsis)

  # Get entity data from database
  ndd_entity_view <- pool %>%
    tbl("ndd_entity_view") %>%
    left_join(ndd_entity_review, by = c("entity_id")) %>%
    collect()

  sysndd_db_disease_table <- ndd_entity_view %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # Select fields from table based on input
  sysndd_db_disease_table <- select_tibble_fields(
    sysndd_db_disease_table,
    fields,
    "entity_id"
  )

  # Use the helper generate_cursor_pag_inf to generate cursor pagination
  # information from a tibble
  disease_table_pagination_info <- generate_cursor_pag_inf(
    sysndd_db_disease_table,
    page_size,
    page_after,
    "entity_id"
  )

  # Use the helper generate_tibble_fspec to generate fields specs
  disease_table_fspec <- generate_tibble_fspec_mem(
    ndd_entity_view,
    fspec
  )
  sysndd_db_disease_table_fspec <- generate_tibble_fspec_mem(
    sysndd_db_disease_table,
    fspec
  )

  # Assign the filtered count safely via join
  # (handles differing row counts when filters reduce distinct fspec values)
  disease_table_fspec$fspec <- disease_table_fspec$fspec %>%
    dplyr::left_join(
      sysndd_db_disease_table_fspec$fspec %>%
        dplyr::select(key, count_filtered = count),
      by = "key"
    ) %>%
    dplyr::mutate(count_filtered = dplyr::coalesce(count_filtered, 0L))

  # Compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(
    paste0(round(end_time - start_time, 2), " secs")
  )

  # Add columns to the meta information from generate_cursor_pag_inf
  meta <- disease_table_pagination_info$meta %>%
    add_column(
      tibble::as_tibble(list(
        "sort" = sort,
        "filter" = filter,
        "fields" = fields,
        "fspec" = disease_table_fspec,
        "executionTime" = execution_time
      ))
    )

  # Add host, port, and other information to links
  links <- disease_table_pagination_info$links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(
      link = case_when(
        link != "null" ~ paste0(
          dw$api_base_url,
          "?sort=",
          sort,
          ifelse(filter != "", paste0("&filter=", filter), ""),
          ifelse(fields != "", paste0("&fields=", fields), ""),
          link
        ),
        link == "null" ~ "null"
      )
    ) %>%
    pivot_wider(
      id_cols = everything(),
      names_from = "type",
      values_from = "link"
    )

  # Generate object to return
  entities_list <- list(
    links = links,
    meta = meta,
    data = disease_table_pagination_info$data
  )

  # If xlsx requested, compute this and return
  if (format == "xlsx") {
    creation_date <- strftime(
      as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S"
    )
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
      str_replace_all("_api_", "")
    filename <- file.path(
      paste0(base_filename, "_", creation_date, ".xlsx")
    )

    bin <- generate_xlsx_bin(entities_list, base_filename)
    as_attachment(bin, filename)
  } else {
    entities_list
  }
}


#* Create New Entity
#*
#* This endpoint allows for the creation of a new entity,
#* including entity details, review, and status.
#* It also provides options for direct approval,
#* review of literature, synopsis, phenotypes, and variation ontology.
#*
#* # `Details`
#* The function checks for user rights, and if valid,
#* proceeds to create a new entity. Subsequent checks are performed
#* to review the entity and create status. The function also handles
#* different scenarios like empty publications, phenotypes, and
#* variation ontology.
#*
#* # `Return`
#* A list with status and message of the operation or an
#* error message if user has no write access.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param direct_approval Boolean for direct approval. Defaults to FALSE.
#*
#* @post /create
function(req, res, direct_approval = FALSE) {
  require_role(req, res, "Curator")

  direct_approval <- as.logical(direct_approval)
  create_data <- req$argsBody$create_json

  entry_user_id <- req$user_id
  review_user_id <- req$user_id
  status_user_id <- req$user_id

  create_data$entity$entry_user_id <- entry_user_id

  logger::log_info(
    "Entity creation started",
    hgnc_id = create_data$entity$hgnc_id,
    user_id = entry_user_id
  )

  # Block to post new entity
  response_entity <- post_db_entity(create_data$entity)

  logger::log_debug(
    "Entity creation response",
    status = response_entity$status,
    entity_id = if (!is.null(response_entity$entry) && !is.null(response_entity$entry$entity_id)) {
      response_entity$entry$entity_id
    } else {
      NA
    }
  )

  if (response_entity$status == 200) {
    # Prepare data for review
    if (length(compact(create_data$review$literature)) > 0) {
      publications_received <- bind_rows(
        tibble::as_tibble(compact(
          create_data$review$literature$additional_references
        )),
        tibble::as_tibble(compact(
          create_data$review$literature$gene_review
        )),
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
      publications_received <- tibble::as_tibble_row(c(
        publication_id = NA, publication_type = NA
      ))
    }

    if (!is.null(create_data$review$comment)) {
      sysnopsis_received <- tibble::as_tibble(create_data$review$synopsis) %>%
        add_column(response_entity$entry$entity_id) %>%
        add_column(create_data$review$comment) %>%
        add_column(review_user_id) %>%
        dplyr::select(
          entity_id = `response_entity$entry$entity_id`,
          synopsis = value,
          review_user_id,
          comment = `create_data$review$comment`
        )
    } else {
      sysnopsis_received <- tibble::as_tibble(create_data$review$synopsis) %>%
        add_column(response_entity$entry$entity_id) %>%
        add_column(review_user_id) %>%
        dplyr::select(
          entity_id = `response_entity$entry$entity_id`,
          synopsis = value,
          review_user_id,
          comment = NULL
        )
    }

    phenotypes_received <- tibble::as_tibble(create_data$review$phenotypes)
    variation_ontology_received <- tibble::as_tibble(
      create_data$review$variation_ontology
    )

    # Use put_post_db_review to add the review
    response_review <- put_post_db_review("POST", sysnopsis_received)

    logger::log_debug(
      "Review creation response",
      status = response_review$status,
      review_id = if (!is.null(response_review$entry) && !is.null(response_review$entry$review_id)) {
        response_review$entry$review_id
      } else {
        NA
      }
    )

    # Submit publications if not empty
    if (length(compact(create_data$review$literature)) > 0) {
      response_publication <- new_publication(publications_received)
      response_publication_conn <- put_post_db_pub_con(
        "POST",
        publications_received,
        as.integer(sysnopsis_received$entity_id),
        as.integer(response_review$entry$review_id)
      )
    } else {
      response_publication <- list(status = 200, message = "OK. Skipped.")
      response_publication_conn <- list(status = 200, message = "OK. Skipped.")
    }

    # Submit phenotype connections if not empty
    if (length(compact(create_data$review$phenotypes)) > 0) {
      response_phenotype_connections <- put_post_db_phen_con(
        "POST",
        phenotypes_received,
        as.integer(sysnopsis_received$entity_id),
        as.integer(response_review$entry$review_id)
      )
    } else {
      response_phenotype_connections <- list(status = 200, message = "OK. Skipped.")
    }

    # Submit variation ontology if not empty
    if (length(compact(create_data$review$variation_ontology)) > 0) {
      resp_variation_ontology_conn <- put_post_db_var_ont_con(
        "POST",
        variation_ontology_received,
        as.integer(sysnopsis_received$entity_id),
        as.integer(response_review$entry$review_id)
      )
    } else {
      resp_variation_ontology_conn <- list(status = 200, message = "OK. Skipped.")
    }

    if (direct_approval) {
      response_review_approve <- put_db_review_approve(
        response_review$entry$review_id,
        review_user_id,
        TRUE
      )
    }

    response_review_post <- tibble::as_tibble(response_publication) %>%
      bind_rows(tibble::as_tibble(response_review)) %>%
      bind_rows(tibble::as_tibble(response_publication_conn)) %>%
      bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
      bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
      dplyr::select(status, message) %>%
      mutate(status = max(status)) %>%
      mutate(message = str_c(message, collapse = "; ")) %>%
      unique()
  } else {
    logger::log_error(
      "Entity creation failed",
      status = response_entity$status,
      error = response_entity$error
    )
    res$status <- response_entity$status
    return(list(
      status = response_entity$status,
      message = response_entity$message,
      error = response_entity$error
    ))
  }

  if (response_entity$status == 200 && response_review_post$status == 200) {
    create_data$status <- tibble::as_tibble(create_data$status) %>%
      add_column(response_entity$entry$entity_id) %>%
      add_column(status_user_id) %>%
      dplyr::select(
        entity_id = `response_entity$entry$entity_id`,
        category_id,
        status_user_id,
        comment,
        problematic
      )

    create_data$status$status_user_id <- status_user_id
    response_status_post <- put_post_db_status("POST", create_data$status)

    logger::log_debug(
      "Status creation response",
      status = response_status_post$status,
      status_id = if (!is.null(response_status_post$entry)) {
        response_status_post$entry
      } else {
        NA
      }
    )

    if (direct_approval) {
      response_status_approve <- put_db_status_approve(
        response_status_post$entry,
        status_user_id,
        TRUE
      )
    }
  } else {
    logger::log_error(
      "Entity created but review creation failed - PARTIAL CREATION",
      entity_id = response_entity$entry$entity_id,
      review_status = response_review_post$status
    )
    response_entity_review_post <- tibble::as_tibble(response_entity) %>%
      bind_rows(tibble::as_tibble(response_review_post)) %>%
      dplyr::select(status, message) %>%
      unique() %>%
      mutate(status = max(status)) %>%
      mutate(message = str_c(message, collapse = "; "))

    res$status <- response_entity_review_post$status
    return(list(
      status = response_entity_review_post$status,
      message = response_entity_review_post$message
    ))
  }

  if (response_entity$status == 200 &&
    response_review_post$status == 200 &&
    response_status_post$status == 200) {
    logger::log_info(
      "Entity creation completed successfully",
      entity_id = response_entity$entry$entity_id,
      user_id = entry_user_id
    )
    res$status <- response_entity$status
    return(response_entity)
  } else {
    logger::log_error(
      "Entity+review created but status creation failed - PARTIAL CREATION",
      entity_id = response_entity$entry$entity_id,
      review_status = response_review_post$status,
      status_status = response_status_post$status
    )
    response <- tibble::as_tibble(response_entity) %>%
      bind_rows(tibble::as_tibble(response_review_post)) %>%
      bind_rows(tibble::as_tibble(response_status_post)) %>%
      dplyr::select(status, message) %>%
      unique() %>%
      mutate(status = max(status)) %>%
      mutate(message = str_c(message, collapse = "; "))

    res$status <- response$status
    return(list(
      status = response$status,
      message = response$message
    ))
  }
}


#* Renames an entity by updating its disease ontology ID version.
#*
#* # `Details`
#* This endpoint function renames the disease ontology of a entity.
#* It checks user role and replaces the disease_ontology_id_version
#* in the ndd_entity table. It deactivates the old entity_id and sets
#* the replacement using put_db_entity_deactivation. It copies all review
#* information from the old entity to the new one, posts new status for
#* the posted entity, and computes a response based on the status of the requests.
#* If successful, the function returns the new entity_id, otherwise,
#* it returns an error message.
#*
#* # `Input`
#* A JSON object with the following properties:
#* - entity_id: (integer) The ID of the entity to be renamed.
#* - hgnc_id: (string) The HGNC ID of the entity.
#* - hpo_mode_of_inheritance_term: (string) The HPO term for mode of inheritance of the entity.
#* - ndd_phenotype: (string) The non-disease phenotype of the entity.
#* - disease_ontology_id_version: (string) The new version of the disease ontology ID of the entity.
#*
#* # `Return`
#* A JSON object with the following properties:
#* - status: (integer) The HTTP status code of the response.
#* - message: (string) A message describing the outcome of the operation.
#* - entry: (list) A list containing the updated entity ID and other metadata.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param rename_json A JSON object with the above detailed properties.
#*
#* @post /rename
function(req, res) {
  require_role(req, res, "Curator")

  new_entry_user_id <- req$user_id
  rename_data <- req$argsBody$rename_json

  ndd_entity_original <- pool %>%
    tbl("ndd_entity") %>%
    collect() %>%
    filter(entity_id == rename_data$entity$entity_id)

  ndd_entity_replaced <- ndd_entity_original %>%
    mutate(
      disease_ontology_id_version = rename_data$entity$disease_ontology_id_version,
      entry_user_id = new_entry_user_id
    ) %>%
    dplyr::select(-entity_id)

  if (
    rename_data$entity$hgnc_id == ndd_entity_replaced$hgnc_id &&
      rename_data$entity$hpo_mode_of_inheritance_term == ndd_entity_replaced$hpo_mode_of_inheritance_term &&
      rename_data$entity$ndd_phenotype == ndd_entity_replaced$ndd_phenotype &&
      rename_data$entity$disease_ontology_id_version !=
        ndd_entity_original$disease_ontology_id_version
  ) {
    # TODO: Implement approval workflow for disease renaming (BUG-07)
    # Currently disease renaming bypasses approval:
    # - New entity is immediately active
    # - Old entity is immediately deactivated
    # - Review/status are copied without re-approval
    # Should follow pattern: create inactive entity, mark review/status unapproved,
    # keep old active until approval, then swap on approval
    log_warn(
      "Disease rename for entity {rename_data$entity$entity_id} bypassing approval workflow. ",
      "Old disease: {ndd_entity_original$disease_ontology_id_version}, ",
      "New disease: {rename_data$entity$disease_ontology_id_version}"
    )

    response_new_entity <- post_db_entity(ndd_entity_replaced)
    response_deactivate <- put_db_entity_deactivation(
      ndd_entity_original$entity_id,
      response_new_entity$entry$entity_id
    )

    ndd_entity_review_original <- pool %>%
      tbl("ndd_entity_review") %>%
      collect() %>%
      filter(entity_id == rename_data$entity$entity_id, is_primary == 1)

    ndd_entity_review_replaced <- ndd_entity_review_original %>%
      mutate(entity_id = response_new_entity$entry$entity_id) %>%
      dplyr::select(-review_id)

    review_publication_join_ori <- pool %>%
      tbl("ndd_review_publication_join") %>%
      collect() %>%
      filter(review_id == ndd_entity_review_original$review_id) %>%
      dplyr::select(publication_id, publication_type)

    review_phenotype_connect_ori <- pool %>%
      tbl("ndd_review_phenotype_connect") %>%
      collect() %>%
      filter(review_id == ndd_entity_review_original$review_id) %>%
      dplyr::select(phenotype_id, modifier_id)

    review_variation_ontology_conn_ori <- pool %>%
      tbl("ndd_review_variation_ontology_connect") %>%
      collect() %>%
      filter(review_id == ndd_entity_review_original$review_id) %>%
      dplyr::select(vario_id, modifier_id)

    response_review <- put_post_db_review(
      "POST",
      ndd_entity_review_replaced
    )

    if (length(compact(review_publication_join_ori)) > 0) {
      response_publication_conn <- put_post_db_pub_con(
        "POST",
        review_publication_join_ori,
        as.integer(response_new_entity$entry$entity_id),
        as.integer(response_review$entry$review_id)
      )
    } else {
      response_publication_conn <- list(status = 200, message = "OK. Skipped.")
    }

    if (length(compact(review_phenotype_connect_ori)) > 0) {
      response_phenotype_connections <- put_post_db_phen_con(
        "POST",
        review_phenotype_connect_ori,
        as.integer(response_new_entity$entry$entity_id),
        as.integer(response_review$entry$review_id)
      )
    } else {
      response_phenotype_connections <- list(status = 200, message = "OK. Skipped.")
    }

    if (length(compact(review_variation_ontology_conn_ori)) > 0) {
      resp_variation_ontology_conn <- put_post_db_var_ont_con(
        "POST",
        review_variation_ontology_conn_ori,
        as.integer(response_new_entity$entry$entity_id),
        as.integer(response_review$entry$review_id)
      )
    } else {
      resp_variation_ontology_conn <- list(status = 200, message = "OK. Skipped.")
    }

    response_review_post <- tibble::as_tibble(response_review) %>%
      bind_rows(tibble::as_tibble(response_publication_conn)) %>%
      bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
      bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
      dplyr::select(status, message) %>%
      unique() %>%
      mutate(status = max(status)) %>%
      mutate(message = str_c(message, collapse = "; ")) %>%
      unique()

    ndd_entity_status_original <- pool %>%
      tbl("ndd_entity_status") %>%
      collect() %>%
      filter(entity_id == rename_data$entity$entity_id, is_active == 1)

    ndd_entity_status_replaced <- ndd_entity_status_original %>%
      mutate(entity_id = response_new_entity$entry$entity_id) %>%
      dplyr::select(-status_id)

    response_status_post <- put_post_db_status(
      "POST",
      ndd_entity_status_replaced
    )

    if (
      response_new_entity$status == 200 &&
        response_review_post$status == 200 &&
        response_status_post$status == 200
    ) {
      res$status <- response_new_entity$status
      return(response_new_entity)
    } else {
      response <- tibble::as_tibble(response_new_entity) %>%
        bind_rows(tibble::as_tibble(response_review_post)) %>%
        bind_rows(tibble::as_tibble(response_status_post)) %>%
        dplyr::select(status, message) %>%
        unique() %>%
        mutate(status = max(status)) %>%
        mutate(message = str_c(message, collapse = "; "))

      res$status <- response$status
      return(list(status = response$status, message = response$message))
    }
  } else {
    res$status <- 400
    return(list(
      error = paste0(
        "This endpoint only allows renaming the disease ontology of an entity."
      )
    ))
  }
}


#* Deactivate Entity
#*
#* This endpoint allows for the deactivation of an existing entity.
#* The function checks user rights and proceeds with the deactivation
#* only if the user role is either Administrator or Curator.
#* The deactivation process includes updating the 'is_active' and 'replaced_by'
#* fields in the database.
#*
#* # `Details`
#* The function only allows deactivation of an entity, any other
#* changes to the entity will result in a 'Bad Request' response.
#*
#* # `Return`
#* A list with status and message of the operation or an error
#* message if user has no write access or if the request is invalid.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @response 200 OK. A list with status, message and entity_id.
#* @response 400 Bad Request. Submitted JSON data does not match the criteria for deactivating or is malformed.
#* @response 403 Forbidden. User does not have the required role.
#* @response 500 Internal server error.
#*
#* @post /deactivate
function(req, res) {
  require_role(req, res, "Curator")

  deactivate_user_id <- req$user_id
  deactivate_data <- req$argsBody$deactivate_json

  ndd_entity_original <- pool %>%
    tbl("ndd_entity") %>%
    collect() %>%
    filter(entity_id == deactivate_data$entity$entity_id)

  ndd_entity_replaced <- ndd_entity_original %>%
    mutate(is_active = deactivate_data$entity$is_active) %>%
    mutate(replaced_by = deactivate_data$entity$replaced_by)

  if (
    deactivate_data$entity$hgnc_id == ndd_entity_replaced$hgnc_id &&
      deactivate_data$entity$hpo_mode_of_inheritance_term ==
        ndd_entity_replaced$hpo_mode_of_inheritance_term &&
      deactivate_data$entity$ndd_phenotype ==
        ndd_entity_replaced$ndd_phenotype &&
      deactivate_data$entity$is_active != ndd_entity_original$is_active
  ) {
    response_new_entity <- put_db_entity_deactivation(
      deactivate_data$entity$entity_id,
      ndd_entity_replaced$replaced_by
    )

    res$status <- response_new_entity$status
    return(list(
      status = response_new_entity$status,
      message = response_new_entity$message
    ))
  } else {
    res$status <- 400
    return(list(
      error = "This endpoint only allows deactivating an entity."
    ))
  }
}


#* Get Phenotypes for Entity
#*
#* This endpoint retrieves phenotypes associated with a given entity_id.
#* By default, it returns phenotypes from the currently active review only.
#*
#* # `Details`
#* The function joins active entities with phenotype connections from the
#* currently active review (is_primary = 1) and matches with the phenotype
#* list to get complete phenotype information.
#*
#* # `Return`
#* A dataframe containing entity_id, phenotype_id, HPO_term, modifier_id,
#* review_id, review_date, and is_primary for each phenotype.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id A numeric, representing the entity_id to be retrieved.
#* @param current_review A logical, if TRUE (default) returns phenotypes from
#* the currently active review only. If FALSE, returns all active phenotypes.
#*
#* @response 200 OK. A data frame with phenotype information and review metadata.
#* @response 500 Internal server error.
#*
#* @get /<sysndd_id>/phenotypes
function(sysndd_id, current_review = TRUE) {
  if (current_review) {
    # Get primary review for this entity
    ndd_entity_review_collected <- pool %>%
      tbl("ndd_entity_review") %>%
      collect()

    ndd_entity_review_list <- ndd_entity_review_collected %>%
      filter(entity_id == sysndd_id & is_primary) %>%
      dplyr::select(entity_id, review_id, synopsis, review_date, comment) %>%
      arrange(review_date)

    # Get phenotype connections for the primary review
    ndd_review_phenotype_conn_coll <- pool %>%
      tbl("ndd_review_phenotype_connect") %>%
      filter(review_id %in% ndd_entity_review_list$review_id) %>%
      collect()
  } else {
    # Legacy behavior: filter by is_active
    ndd_review_phenotype_conn_coll <- pool %>%
      tbl("ndd_review_phenotype_connect") %>%
      filter(is_active == 1) %>%
      collect()
  }

  phenotype_list_collected <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  ndd_entity_active <- pool %>%
    tbl("ndd_entity_view") %>%
    dplyr::select(entity_id) %>%
    collect()

  phenotype_list <- ndd_entity_active %>%
    left_join(ndd_review_phenotype_conn_coll, by = c("entity_id")) %>%
    filter(entity_id == sysndd_id) %>%
    inner_join(phenotype_list_collected, by = c("phenotype_id")) %>%
    dplyr::select(entity_id, phenotype_id, HPO_term, modifier_id) %>%
    arrange(phenotype_id) %>%
    unique()
}


#* Get Variation Ontology for Entity
#*
#* This endpoint retrieves variation ontology terms associated with a given
#* entity_id. By default, it returns variations from the currently active review only.
#*
#* # `Details`
#* The function collects variation ontology connections from the currently
#* active review (is_primary = 1), filters for the given entity_id, and joins
#* with the variation ontology list to get complete information.
#*
#* # `Return`
#* A dataframe containing entity_id, vario_id, vario_name, modifier_id,
#* review_id, review_date, and is_primary for each variation ontology term.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which ontology should be retrieved.
#* @param current_review A logical, if TRUE (default) returns variations from
#* the currently active review only. If FALSE, returns all active variations.
#*
#* @response 200 OK. A data frame with variation ontology information and review metadata.
#* @response 500 Internal server error.
#*
#* @get /<sysndd_id>/variation
function(sysndd_id, current_review = TRUE) {
  if (current_review) {
    # Get primary review for this entity
    ndd_entity_review_collected <- pool %>%
      tbl("ndd_entity_review") %>%
      collect()

    ndd_entity_review_list <- ndd_entity_review_collected %>%
      filter(entity_id == sysndd_id & is_primary) %>%
      dplyr::select(entity_id, review_id, synopsis, review_date, comment) %>%
      arrange(review_date)

    # Get variation connections for the primary review AND this specific entity
    ndd_review_variation_conn_coll <- pool %>%
      tbl("ndd_review_variation_ontology_connect") %>%
      filter(review_id %in% ndd_entity_review_list$review_id & entity_id == sysndd_id) %>%
      collect()
  } else {
    # Legacy behavior: filter by is_active
    ndd_review_variation_conn_coll <- pool %>%
      tbl("ndd_review_variation_ontology_connect") %>%
      filter(is_active == 1 & entity_id == sysndd_id) %>%
      collect()
  }

  variation_list_collected <- pool %>%
    tbl("variation_ontology_list") %>%
    collect()

  variation_list <- ndd_review_variation_conn_coll %>%
    inner_join(variation_list_collected, by = c("vario_id")) %>%
    dplyr::select(entity_id, vario_id, vario_name, modifier_id) %>%
    arrange(vario_id) %>%
    unique()
}


#* Get Clinical Synopsis for Entity
#*
#* This endpoint retrieves all clinical synopsis associated with a
#* given entity_id. The function fetches data from the database, performs
#* necessary filtering to produce the list of clinical synopsis.
#*
#* # `Details`
#* The function collects the review data from the database, filters for
#* the given entity_id and primary reviews, and selects necessary columns. The
#* result is then joined with the provided entity_id to provide a complete list.
#*
#* # `Return`
#* A dataframe containing entity_id, review_id, synopsis,
#* review_date, and comment for each clinical synopsis associated
#* with the entity_id.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which the clinical synopsis is to be retrieved.
#*
#* @get /<sysndd_id>/review
function(sysndd_id) {
  ndd_entity_review_collected <- pool %>%
    tbl("ndd_entity_review") %>%
    collect()

  ndd_entity_review_list <- ndd_entity_review_collected %>%
    filter(entity_id == sysndd_id & is_primary) %>%
    dplyr::select(entity_id, review_id, synopsis, review_date, comment) %>%
    arrange(review_date)

  ndd_entity_review_list_joined <- tibble::as_tibble(sysndd_id) %>%
    dplyr::select(entity_id = value) %>%
    mutate(entity_id = as.integer(entity_id)) %>%
    left_join(ndd_entity_review_list, by = c("entity_id"))
}


#* Get Entity Status
#*
#* This endpoint retrieves the status for a given entity_id. The
#* function collects the status data from the database, performs necessary
#* filtering, and joins with the status categories list.
#*
#* # `Details`
#* The function fetches status data and status categories from the
#* database, filters for the given entity_id and active status, joins with the
#* categories list, and selects relevant columns. The result is then ordered
#* by status date.
#*
#* # `Return`
#* A dataframe containing status_id, entity_id, category, category_id,
#* status_date, comment, and problematic fields for the status associated with
#* the entity_id.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which the status is to be retrieved.
#*
#* @get /<sysndd_id>/status
function(sysndd_id) {
  ndd_entity_status_collected <- pool %>%
    tbl("ndd_entity_status") %>%
    collect()

  entity_status_categories_coll <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    collect()

  ndd_entity_status_list <- ndd_entity_status_collected %>%
    filter(entity_id == sysndd_id & is_active) %>%
    inner_join(entity_status_categories_coll, by = c("category_id")) %>%
    dplyr::select(
      status_id,
      entity_id,
      category,
      category_id,
      status_date,
      comment,
      problematic
    ) %>%
    arrange(status_date)
}


#* Get Entity Publications
#*
#* This endpoint retrieves publications associated with a given entity_id.
#* By default, it returns publications from the currently active review only.
#*
#* # `Details`
#* The function fetches publication data from the currently active review
#* (is_primary = 1), filters for the given entity_id, and selects relevant
#* columns with review metadata.
#*
#* # `Return`
#* A dataframe containing entity_id, publication_id, publication_type,
#* is_reviewed, review_id, review_date, and is_primary for each publication.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which publications are to be retrieved.
#* @param current_review A logical, if TRUE (default) returns publications from
#* the currently active review only. If FALSE, returns all reviewed publications.
#*
#* @response 200 OK. A data frame with publication information and review metadata.
#* @response 500 Internal server error.
#*
#* @get /<sysndd_id>/publications
function(sysndd_id, current_review = TRUE) {
  if (current_review) {
    # Get primary review for this entity
    ndd_entity_review_collected <- pool %>%
      tbl("ndd_entity_review") %>%
      collect()

    ndd_entity_review_list <- ndd_entity_review_collected %>%
      filter(entity_id == sysndd_id & is_primary) %>%
      dplyr::select(entity_id, review_id, synopsis, review_date, comment) %>%
      arrange(review_date)

    # Get publication connections for the primary review
    review_publication_join_coll <- pool %>%
      tbl("ndd_review_publication_join") %>%
      filter(review_id %in% ndd_entity_review_list$review_id) %>%
      collect()
  } else {
    # Legacy behavior: filter by is_reviewed
    review_publication_join_coll <- pool %>%
      tbl("ndd_review_publication_join") %>%
      filter(is_reviewed == 1) %>%
      collect()
  }

  ndd_entity_active <- pool %>%
    tbl("ndd_entity_view") %>%
    dplyr::select(entity_id) %>%
    collect()

  ndd_entity_publication_list <- ndd_entity_active %>%
    left_join(review_publication_join_coll, by = c("entity_id")) %>%
    filter(entity_id == sysndd_id) %>%
    dplyr::select(entity_id, publication_id, publication_type, is_reviewed) %>%
    arrange(publication_id) %>%
    unique()
}

## Entity endpoints
## -------------------------------------------------------------------##
