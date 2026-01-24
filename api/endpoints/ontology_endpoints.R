# api/endpoints/ontology_endpoints.R
#
# This file contains all ontology-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible (e.g., two-space indentation, meaningful
# function names, etc.).

## -------------------------------------------------------------------##
## Ontology endpoints
## -------------------------------------------------------------------##

#* Fetch Ontology Entry by ID
#*
#* This endpoint fetches an ontology entry based on its disease_ontology_id_version.
#*
#* # `Details`
#* Retrieves detailed information about an ontology term, including associated
#* HGNC IDs and inheritance terms.
#*
#* # `Return`
#* Returns detailed information of the specified ontology term.
#*
#* @tag ontology
#* @serializer json list(na="null")
#*
#* @param ontology_input The disease_ontology_id_version or name to query.
#* @param input_type The type of input, usually "ontology_id".
#*
#* @response 200 OK. Returns detailed ontology info.
#*
#* @get <ontology_input>
function(ontology_input, input_type = "ontology_id") {
  ontology_input <- URLdecode(ontology_input)

  mode_of_inheritance_list_coll <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    filter(is_active == 1) %>%
    select(
      hpo_mode_of_inheritance_term,
      hpo_mode_of_inheritance_term_name,
      inheritance_filter
    ) %>%
    collect()

  disease_ontology_set <- pool %>%
    tbl("disease_ontology_set") %>%
    collect()

  disease_ontology_set_collected <- disease_ontology_set %>%
    mutate(disease_ontology_id_search = disease_ontology_id) %>%
    mutate(disease_ontology_name_search = disease_ontology_name) %>%
    pivot_longer(
      cols = disease_ontology_id_search:disease_ontology_name_search,
      names_to = "type",
      values_to = "search"
    ) %>%
    filter(search == ontology_input) %>%
    select(
      disease_ontology_id_version,
      disease_ontology_id,
      disease_ontology_name,
      disease_ontology_source,
      disease_ontology_is_specific,
      hgnc_id,
      hpo_mode_of_inheritance_term,
      DOID,
      MONDO,
      Orphanet,
      EFO
    ) %>%
    arrange(disease_ontology_id_version) %>%
    left_join(mode_of_inheritance_list_coll, by = c("hpo_mode_of_inheritance_term")) %>%
    group_by(disease_ontology_id) %>%
    summarize_all(~ paste(unique(.), collapse = ";")) %>%
    ungroup() %>%
    mutate(across(everything(), ~ replace(., . == "NA", NA))) %>%
    mutate(across(everything(), ~ str_split(., pattern = ";")))

  disease_ontology_set_collected
}


#* Retrieves a summary table of the variation ontology list.
#*
#* # `Details`
#* This endpoint fetches summary information about the variation ontology list,
#* such as IDs, labels, definitions, etc. Administrators have full access,
#* otherwise request is forbidden.
#*
#* # `Return`
#* A JSON array containing the ontology table.
#*
#* @tag ontology
#* @serializer json list(na="string")
#* @get variant/table
function(req, res) {
  require_role(req, res, "Administrator")

  user <- req$user_id

  ontology_table <- pool %>%
    tbl("variation_ontology_list") %>%
    select(
      vario_id,
      vario_name,
      definition,
      obsolete,
      is_active,
      sort,
      update_date
    ) %>%
    collect()

  ontology_table
}


#* Updates the details of an existing variation ontology.
#*
#* # `Details`
#* This endpoint allows Administrators to modify variation ontology attributes.
#* If the vario_id is found, it updates the fields. If no changes are detected,
#* it indicates no changes. On success, updates `update_date`.
#*
#* # `Input`
#* - `ontology_details`: JSON with the fields to update, including "vario_id".
#*
#* @tag ontology
#* @serializer json list(na="string")
#* @accept json
#* @put variant/update
function(req, res) {
  require_role(req, res, "Administrator")

  # Parse JSON payload
  ontology_details <- req$argsBody$ontology_details

  if (is.null(ontology_details$vario_id)) {
    res$status <- 400
    return(list(error = "The vario_id field is required."))
  }

  # Fetch current data to check if ontology exists
  current_data <- db_execute_query(
    "SELECT * FROM variation_ontology_list WHERE vario_id = ?",
    list(ontology_details$vario_id)
  )

  if (nrow(current_data) == 0) {
    res$status <- 404
    return(list(error = "Ontology with the given vario_id not found."))
  }

  fields_to_update <- names(ontology_details)[
    !names(ontology_details) %in% c("vario_id", "update_date")
  ]

  if (length(fields_to_update) == 0) {
    res$status <- 400
    return(list(error = "No valid fields to update."))
  }

  changes <- sapply(fields_to_update, function(field) {
    new_value <- as.character(ontology_details[[field]])
    current_value <- as.character(current_data[[field]])
    new_value != current_value
  })

  if (!any(changes)) {
    res$status <- 200
    return(list(message = "No changes detected, ontology details remain unchanged."))
  }

  # Build SET clause with placeholders
  set_assignments <- paste(
    sapply(fields_to_update, function(field) {
      paste0(field, " = ?")
    }, USE.NAMES = FALSE),
    collapse = ", "
  )
  set_clause <- paste0(set_assignments, ", update_date = NOW()")

  # Build parameterized UPDATE query
  query_update <- paste0(
    "UPDATE variation_ontology_list SET ", set_clause, " WHERE vario_id = ?"
  )

  # Build parameter list: field values + vario_id at end
  params <- c(
    lapply(fields_to_update, function(field) ontology_details[[field]]),
    list(ontology_details$vario_id)
  )

  result <- tryCatch(
    {
      db_execute_statement(query_update, params)
    },
    error = function(e) {
      list(error = e$message)
    }
  )

  if (is.list(result) && !is.null(result$error)) {
    res$status <- 500
    return(list(error = "Failed to update ontology details: ", result$error))
  }

  list(message = "Ontology details updated successfully.")
}
