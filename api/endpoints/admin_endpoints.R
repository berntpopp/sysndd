# api/endpoints/admin_endpoints.R
#
# This file contains all Administrator-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Be sure to source any required helper files at the top (e.g.,
# source("functions/database-functions.R", local = TRUE)) if needed.

## -------------------------------------------------------------------##
## Administration section
## -------------------------------------------------------------------##

#* Get OpenAPI specification
#*
#* Returns the OpenAPI JSON specification for this API.
#* This endpoint is used by the frontend Swagger UI.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @get /openapi.json
function(req, res) {
  spec <- req$pr$getApiSpec()
  spec
}

#* Updates ontology sets and identifies critical changes
#*
#* This endpoint performs an ontology update process by aggregating and updating
#* various ontology data sets. It is restricted to Administrator users and
#* handles the complex process of updating the ontology data, identifying
#* critical changes, and updating relevant database tables.
#*
#* # `Details`
#* The function starts by collecting data from multiple tables like
#* mode_of_inheritance_list, non_alt_loci_set, and ndd_entity_view. It then
#* computes a new disease ontology set and identifies critical changes. Finally,
#* it updates the ndd_entity table with these changes and updates the database.
#*
#* # `Authorization`
#* Access to this endpoint is restricted to users with the 'Administrator' role.
#*
#* # `Return`
#* If successful, the function returns a success message. If the user is
#* unauthorized, it returns an error message indicating that access is forbidden.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put update_ontology
function(req, res) {
  # Check user role for Administrator access
  if (req$user_role != "Administrator") {
    res$status <- 403 # Forbidden
    return(list(
      error = "Access forbidden. Only administrators can perform this operation."
    ))
  }

  # Collect data from multiple tables
  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    select(-is_active, -sort) %>%
    collect()

  non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, symbol) %>%
    collect()

  ndd_entity_view <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()

  ndd_entity_view_ontology_set <- ndd_entity_view %>%
    select(entity_id, disease_ontology_id_version, disease_ontology_name) %>%
    collect()

  disease_ontology_set <- pool %>%
    tbl("disease_ontology_set") %>%
    select(
      disease_ontology_id_version,
      disease_ontology_id,
      hgnc_id,
      hpo_mode_of_inheritance_term,
      disease_ontology_name
    ) %>%
    collect()

  ndd_entity <- pool %>%
    tbl("ndd_entity") %>%
    collect()

  # Compute the new disease_ontology_set
  disease_ontology_set_update <- process_combine_ontology(
    non_alt_loci_set,
    mode_of_inheritance_list,
    3, # e.g., some parameter controlling the process
    "data/"
  )

  # Identify critical changes
  critical_changes <- identify_critical_ontology_changes(
    disease_ontology_set_update,
    disease_ontology_set,
    ndd_entity_view_ontology_set
  )

  # Mutate ndd_entity with critical changes
  ndd_entity_mutated <- ndd_entity %>%
    mutate(
      disease_ontology_id_version = case_when(
        (disease_ontology_id_version %in% critical_changes$disease_ontology_id_version) ~
          "MONDO:0700096_1",
        TRUE ~ disease_ontology_id_version
      )
    ) %>%
    mutate(entity_quadruple = paste0(
      hgnc_id, "-", disease_ontology_id_version, "-",
      hpo_mode_of_inheritance_term, "-", ndd_phenotype
    )) %>%
    mutate(number = 1) %>%
    group_by(entity_quadruple) %>%
    mutate(
      entity_quadruple_unique = n(),
      sum_number = cumsum(number)
    ) %>%
    ungroup() %>%
    mutate(disease_ontology_id_version = case_when(
      entity_quadruple_unique > 1 & sum_number == 1 ~ "MONDO:0700096_1",
      entity_quadruple_unique > 1 & sum_number == 2 ~ "MONDO:0700096_2",
      entity_quadruple_unique > 1 & sum_number == 3 ~ "MONDO:0700096_3",
      entity_quadruple_unique > 1 & sum_number == 4 ~ "MONDO:0700096_4",
      entity_quadruple_unique > 1 & sum_number == 5 ~ "MONDO:0700096_5",
      TRUE ~ disease_ontology_id_version
    )) %>%
    select(-entity_quadruple, -number, -entity_quadruple_unique, -sum_number)

  # Use transaction for atomic ontology update
  tryCatch({
    db_with_transaction({
      # Get connection from transaction context
      conn <- poolCheckout(pool)
      on.exit(poolReturn(conn), add = TRUE)

      dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0;")
      dbExecute(conn, "TRUNCATE TABLE disease_ontology_set;")
      dbAppendTable(conn, "disease_ontology_set", disease_ontology_set_update)

      dbExecute(conn, "TRUNCATE TABLE ndd_entity;")
      dbAppendTable(conn, "ndd_entity", ndd_entity_mutated)
      dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1;")
    })

    # Return success
    list(
      status = "Success",
      message = "Ontology update process completed."
    )
  }, error = function(e) {
    res$status <- 500
    list(
      error = "An error occurred during the update process. Transaction rolled back.",
      details = e$message
    )
  })
}


#* Updates HGNC data and refreshes the non_alt_loci_set table
#*
#* This endpoint performs an update process by downloading the latest HGNC data,
#* processing it, and updating the non_alt_loci_set table. It is restricted to
#* Administrator users.
#*
#* # `Details`
#* The function downloads the latest HGNC file, processes the gene information,
#* updates STRINGdb identifiers, computes gene coordinates, and then updates
#* the non_alt_loci_set table in the MySQL database with these new values.
#*
#* # `Authorization`
#* Access to this endpoint is restricted to users with the 'Administrator' role.
#*
#* # `Return`
#* If successful, returns a success message. Otherwise, returns an error message.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put update_hgnc_data
function(req, res) {
  if (req$user_role != "Administrator") {
    res$status <- 403
    return(list(error = "Access forbidden. Only administrators can perform this operation."))
  }

  # Call the function to update the HGNC data
  hgnc_data <- update_process_hgnc_data()

  # Use transaction for atomic HGNC update
  tryCatch(
    {
      db_with_transaction({
        # Get connection from transaction context
        conn <- poolCheckout(pool)
        on.exit(poolReturn(conn), add = TRUE)

        dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0;")
        dbExecute(conn, "TRUNCATE TABLE non_alt_loci_set;")
        dbWriteTable(conn, "non_alt_loci_set", hgnc_data, append = TRUE)
        dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1;")
      })

      list(status = "Success", message = "HGNC data update process completed.")
    },
    error = function(e) {
      res$status <- 500
      list(
        error = "An error occurred during the HGNC update process. Transaction rolled back.",
        details = e$message
      )
    }
  )
}


#* Retrieves the current API version
#*
#* This endpoint provides the current version of the API. It's a simple utility
#* function that can be useful for clients to check the API version they are
#* interacting with. This can help in ensuring compatibility when multiple
#* versions exist.
#*
#* # `Details`
#* The function no longer calls `apiV()`, but instead references a global
#* variable `sysndd_api_version`. It's primarily for informational purposes.
#*
#* # `Authorization`
#* This endpoint does not require any specific role. It's open for any client
#* or user who needs to know the API version.
#*
#* # `Return`
#* Returns a JSON object with the API version, e.g. {"api_version": "x.y.z"}.
#*
#* @tag admin
#* @serializer unboxedJSON list(na="string")
#* @get api_version
function() {
  list(api_version = sysndd_api_version)
}


## Administration section
## -------------------------------------------------------------------##
