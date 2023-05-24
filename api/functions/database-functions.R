#### This file holds database interaction functions


#' Post DB Entity
#'
#' This function adds a new entity to the database, if all required columns are
#' present in the provided entity data. The entity data is first converted to a
#' tibble, and then filtered to include only the required columns. The function
#' then connects to the database, adds the new entity, and disconnects from the
#' database. Finally, the function returns a status message with information on
#' whether the entity was successfully added or not.
#'
#' @param entity_data A data frame containing the entity data to be added to the
#' database.
#' @return A list with information on the status of the entity addition process,
#' including a status code, a message, and the entity ID if the entity was
#' successfully added.
#' @export
#' @seealso See 'as_tibble', 'dbConnect', 'dbAppendTable', 'dbGetQuery',
#' and 'dbDisconnect' for more information on the functions used.
#' @examples
#' post_db_entity(entity_data)
post_db_entity <- function(entity_data) {
    ##-------------------------------------------------------------------##
    # block to convert the entity components into tibble
    entity_received <- as_tibble(entity_data)
    ##-------------------------------------------------------------------##

  if ("hgnc_id" %in% colnames(entity_received) &&
      "hpo_mode_of_inheritance_term" %in% colnames(entity_received) &&
      "disease_ontology_id_version" %in% colnames(entity_received) &&
      "ndd_phenotype" %in% colnames(entity_received) &&
      "entry_user_id" %in% colnames(entity_received)
    ) {

    # select columns needed
    entity_received <- entity_received %>%
        select(hgnc_id,
        hpo_mode_of_inheritance_term,
        disease_ontology_id_version,
        ndd_phenotype,
        entry_user_id
        )

    ##-------------------------------------------------------------------##
    ## connect to the database and then add the new entity
    # connect to database
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    # submit the new entity and get the id of the
    # last insert for association with other tables
    db_append <- tryCatch({
      dbAppendTable(sysndd_db, "ndd_entity", entity_received)
    }, error = function(cond) {
            # Choose a return value in case of error
            return(cond$message)
    })

    if (db_append == 1) {
    submitted_entity_id <- dbGetQuery(sysndd_db, "SELECT LAST_INSERT_ID();") %>%
      tibble::as_tibble() %>%
      select(entity_id = `LAST_INSERT_ID()`)
    } else if (is.na(as.logical(db_append))) {
    submitted_entity_id <- NA
    db_error <- db_append
    }

    # disconnect from database
    dbDisconnect(sysndd_db)

    if (db_append == 1) {
    # return OK
    return(list(status = 200,
      message = "OK. Entry created.",
      entry = submitted_entity_id)
      )
    } else if (is.na(as.logical(db_append))) {
    return(list(status = 500,
      message = "Internal Server Error. Entry not created.",
      entry = submitted_entity_id,
      error = db_error)
      )
    }

    ##-------------------------------------------------------------------##

  } else {
    # return Bad Request
    return(list(status = 405,
      message = "Submitted entity components can not be empty.")
      )
  }
}


#' Post DB Entity
#'
#' This function adds a new entity to the database, if all required columns are
#' present in the provided entity data. The entity data is first converted to a
#' tibble, and then filtered to include only the required columns. The function
#' then connects to the database, adds the new entity, and disconnects from the
#' database. Finally, the function returns a status message with information on
#' whether the entity was successfully added or not.
#'
#' @param entity_data A data frame containing the entity data to be added to the
#' database.
#' @return A list with information on the status of the entity addition process,
#' including a status code, a message, and the entity ID if the entity was
#' successfully added.
#' @export
#' @seealso See 'as_tibble', 'dbConnect', 'dbAppendTable', 'dbGetQuery',
#' and 'dbDisconnect' for more information on the functions used.
#' @examples
#' post_db_entity(entity_data)
put_db_entity_deactivation <- function(entity_id,
  replacement = "NULL") {
  if (!is.null(entity_id)
    ) {
    ##-------------------------------------------------------------------##
    # connect to database
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
    dbname = dw$dbname,
    user = dw$user,
    password = dw$password,
    server = dw$server,
    host = dw$host,
    port = dw$port
    )

    # perform the entity update
    dbExecute(sysndd_db, paste0("UPDATE ndd_entity SET ",
    "is_active = 0, ",
    "replaced_by = ",
    replacement,
    " WHERE entity_id = ",
    entity_id,
    ";")
    )

    # disconnect from database
    dbDisconnect(sysndd_db)

    # return OK
    return(list(status = 200,
      message = "OK. Entity deactivated.",
      entry = entity_id))
    ##-------------------------------------------------------------------##

  } else {
    # return Bad Request
    return(list(status = 405,
      message = "Submitted entity_id can not be empty.")
      )
  }
}


#' Put Post DB Review
#'
#' This function is used to post or update reviews in the database. If the review
#' data is complete and valid, the function either adds a new review to the
#' database or updates an existing review. The function connects to the database,
#' performs the appropriate action, and then disconnects from the database. The
#' function returns a status message indicating whether the action was successful
#' or not.
#'
#' @param request_method A character vector indicating the type of request to be
#' made. Must be either "POST" or "PUT".
#' @param review_data A data frame containing the review data to be added or
#' updated in the database.
#' @param re_review A logical value indicating whether this is a re-review. If
#' TRUE, the function executes a query to update the status and status ID of the
#' re-review entity connection.
#' @return A list with information on the status of the review addition or
#' update process, including a status code, a message, and the review ID if
#' the review was successfully added or updated.
#' @export
#' @seealso See 'as_tibble', 'dbConnect', 'dbAppendTable', 'dbGetQuery',
#' and 'dbDisconnect' for more information on the functions used.
#' @examples
#' put_post_db_review(request_method, review_data, re_review = FALSE)
put_post_db_review <- function(request_method,
  review_data, re_review = FALSE) {
  ##-------------------------------------------------------------------##
  # convert review_received to tibble
  review_received <- as_tibble(review_data)
  ##-------------------------------------------------------------------##

  ##-------------------------------------------------------------------##
  # make sure re_review input is logical
  re_review <- as.logical(re_review)
  ##-------------------------------------------------------------------##

  ##-------------------------------------------------------------------##
  # escape single quotes for SQL
  # This fixes a bug where single quotes cause saving error
  # based on: https://stackoverflow.com/questions/40257230/r-escape-single-quote-in-a-string
  review_received <- review_received %>%
    mutate(synopsis = str_replace_all(synopsis, "'", "''"))
  ##-------------------------------------------------------------------##

  if (("synopsis" %in% colnames(review_received)) &&
      ("entity_id" %in% colnames(review_received)) &&
      nchar(review_received$synopsis) > 0) {

    ##-------------------------------------------------------------------##
    # check request type and perform database update accordingly
    if (request_method == "POST" &&
        !("review_id" %in% colnames(review_received))) {
      ##-------------------------------------------------------------------##
      ## for the post request we connect
      ## to the database and then add the new synopsis
      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
        )

      # submit the new synopsis and get the id of
      # the last insert for association with other tables
      dbAppendTable(sysndd_db, "ndd_entity_review", review_received)
      submitted_review_id <- dbGetQuery(sysndd_db,
          "SELECT LAST_INSERT_ID();"
          ) %>%
        tibble::as_tibble() %>%
        select(review_id = `LAST_INSERT_ID()`)

      # execute update query for re_review_entity_connect
      # saving status and status_id if re_review is TRUE
      if (re_review) {
        dbExecute(sysndd_db,
          paste0("UPDATE re_review_entity_connect SET ",
            "re_review_review_saved = 1, ",
            "review_id=",
            submitted_review_id$review_id,
            " WHERE entity_id = ",
            review_data$entity_id,
            ";"))
      }

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200,
        message = "OK. Entry created.",
        entry = submitted_review_id)
        )
      ##-------------------------------------------------------------------##
    } else if (request_method == "PUT" &&
               ("review_id" %in% colnames(review_received))) {
      ##-------------------------------------------------------------------##
      ## for the put request we update the review and set it's status to 0
      # generate update query, we remove entity_id
      # to not allow changing the review entity connection
      update_query <- review_received %>%
        select(-entity_id) %>%
        mutate(row = row_number()) %>%
        mutate(across(where(is.logical), as.integer)) %>%
        mutate(across(where(is.numeric), as.character)) %>%
        pivot_longer(-row) %>%
        mutate(query = paste0(name, "='", value, "'")) %>%
        select(query) %>%
        summarize(query = str_c(query, collapse = ", "))

      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
        )

      # perform the review update
      dbExecute(sysndd_db, paste0("UPDATE ndd_entity_review SET ",
        update_query,
        " WHERE review_id = ",
        review_received$review_id,
        ";")
        )

      # reset approval status
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review ",
        "SET review_approved=0 WHERE review_id = ",
        review_received$review_id,
        ";")
        )

      # reset approval user
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review ",
        "SET approving_user_id=NULL WHERE review_id = ",
        review_received$review_id,
        ";")
        )

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200,
        message = "OK. Entry created.",
        entry = review_received$review_id))
      ##-------------------------------------------------------------------##
    } else {
      # return Method Not Allowed
      return(list(status = 405, message = "Method Not Allowed."))
    }
    ##-------------------------------------------------------------------##

  } else {
    # return Bad Request
    return(list(status = 405,
      message = "Submitted synopsis data can not be empty.")
      )
  }
}


#' Post or Put DB Publication Connection
#'
#' This function is used to add or update variant publication connections in the
#' database. The function checks if the submitted publications are allowed by
#' comparing them to a list of available publications. If the publications are
#' allowed, the function checks if it is a POST or PUT request and either
#' creates new connections or updates existing connections accordingly.
#'
#' @param request_method A string indicating the request method, which can be
#' either "POST" or "PUT".
#' @param publication_data A data frame containing the publication data to be
#' added or updated.
#' @param entity_id The ID of the entity to which the publications are being
#' connected.
#' @param review_id The ID of the review to which the publications are being
#' connected.
#' @return A list with information on the status of the connection addition or
#' update process, including a status code and message.
#' @export
#' @seealso See dbConnect, dbAppendTable, dbExecute, and dbDisconnect
#' for more information on the functions used.
#' @examples
#' put_post_db_pub_con("POST", publication_data, entity_id, review_id)
put_post_db_pub_con <- function(request_method,
  publication_data,
  entity_id,
  review_id) {
  ##-------------------------------------------------------------------##
  # get publication_ids present in table
  publication_list_collected <- pool %>%
    tbl("publication") %>%
    select(publication_id) %>%
    arrange(publication_id) %>%
    collect()

  # check if received publications are in allowed publications
  publications_allowed <- all(publication_data$publication_id %in%
    publication_list_collected$publication_id)

  # prepare publications tibble for submission
  publications_submission <- publication_data %>%
    add_column(review_id) %>%
    add_column(entity_id) %>%
    select(review_id, entity_id, publication_id, publication_type)

  # for the PUT request we check whether the submitted entity ID
  # matches the current one associated with the review id to
  # not allow changing this connection
  review_publication_for_match <- (pool %>%
    tbl("ndd_entity_review") %>%
    select(review_id, entity_id) %>%
    filter(review_id == {{review_id}}) %>%
    collect() %>%
    unique()
    )$entity_id[1]

  entity_id_match <- (review_publication_for_match == entity_id)

  if (publications_allowed) {
    if (request_method == "POST") {
      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
        )

      # submit publications from new review to database
      dbAppendTable(sysndd_db,
        "ndd_review_publication_join",
        publications_submission
        )

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200,
        message = "OK. Entry created.")
        )
    } else if (request_method == "PUT" &&
        (entity_id_match || is.na(entity_id_match))) {
      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
        )

      # delete old publication connections for review_id
      dbExecute(sysndd_db,
        paste0("DELETE FROM ndd_review_publication_join WHERE review_id = ",
        review_id,
        ";")
        )

      # submit publications from new review to database
      dbAppendTable(sysndd_db,
        "ndd_review_publication_join",
        publications_submission
        )

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200, message = "OK. Entry created."))
    } else {
      # return Method Not Allowed
      return(list(status = 405, message = "Method not Allowed."))
    }
  } else {
    # return Bad Request
    return(list(status = 400,
      message = paste0("Some of the submitted publications are not in",
        " the allowed in the publications list. Add them there first."
        )
      )
    )
  }
  ##-------------------------------------------------------------------##
}


#' Posts or puts the variant phenotype connections
#'
#' This function posts or puts the variant phenotype connections.
#' It takes a request method, phenotype data, entity id, and review id as inputs.
#'
#' @param request_method A character string indicating the type of HTTP request
#' to be made ("POST" or "PUT").
#' @param phenotypes_data A data frame containing the phenotype information
#' for submission.
#' @param entity_id An integer value indicating the entity ID.
#' @param review_id An integer value indicating the review ID.
#'
#' @return A list containing status and message indicating the success or
#' failure of the operation.
#' @export
#'
#' @examples
#' put_post_db_phen_con("POST", phenotypes_data, entity_id, review_id)
put_post_db_phen_con <- function(request_method,
  phenotypes_data,
  entity_id,
  review_id) {
  ##-------------------------------------------------------------------##
  # get allowed HPO terms
  phenotype_list_collected <- pool %>%
    tbl("phenotype_list") %>%
    select(phenotype_id) %>%
    arrange(HPO_term) %>%
    collect()

  # check if received phenotypes are in allowed phenotypes
  phenotypes_allowed <- all(phenotypes_data$phenotype_id %in%
    phenotype_list_collected$phenotype_id)

  # prepare phenotype tibble for submission
  phenotypes_submission <- phenotypes_data %>%
    add_column(review_id) %>%
    add_column(entity_id) %>%
    select(review_id, phenotype_id, entity_id, modifier_id)

  # for the PUT request we check whether the submitted entity ID
  # matches the current one associated with the review id
  # to not allow changing this connection
  ndd_review_phenotype_for_match <- (pool %>%
    tbl("ndd_review_phenotype_connect") %>%
    select(review_id, entity_id) %>%
    filter(review_id == {{review_id}}) %>%
    collect() %>%
    unique()
    )$entity_id[1]

  entity_id_match <- (ndd_review_phenotype_for_match == entity_id)

  if (phenotypes_allowed) {
    if (request_method == "POST") {
      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
        )

      # submit phenotypes from new review to database
      dbAppendTable(sysndd_db,
        "ndd_review_phenotype_connect",
        phenotypes_submission
        )

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200, message = "OK. Entry created."))
    } else if (request_method == "PUT" &&
        (entity_id_match || is.na(entity_id_match))) {
      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
        )

      # used to delete the old phenotype
      # connections for review_id here (until 2022-06-10)
      # changed to inactivation
      dbExecute(sysndd_db,
        paste0("DELETE FROM ndd_review_phenotype_connect ",
        "WHERE review_id = ",
        review_id,
        ";")
        )

      # submit phenotypes from new review to database
      dbAppendTable(sysndd_db,
        "ndd_review_phenotype_connect",
        phenotypes_submission
        )

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200,
      message = "OK. Entry created."))
    } else {
      # return Method Not Allowed
      return(list(status = 405, message = "Method not Allowed."))
    }

  } else {
    # return Bad Request
    return(list(status = 400,
      message = paste0("Some of the submitted phenotypes are",
      "not in the allowed phenotype_id list."
      )
      )
    )
  }
  ##-------------------------------------------------------------------##
}


#' Posts or puts the variant ontology connections
#'
#' This function posts or puts the variant ontology connections.
#' It takes a request method, variation ontology data, entity id, and review id as inputs.
#'
#' @param request_method A character string indicating the type of HTTP request
#' to be made ("POST" or "PUT").
#' @param variation_ontology_data A data frame containing the variation ontology
#' information for submission.
#' @param entity_id An integer value indicating the entity ID.
#' @param review_id An integer value indicating the review ID.
#'
#' @return A list containing status and message indicating the success or
#' failure of the operation.
#' @export
#'
#' @examples
#' put_post_db_var_ont_con("POST", variation_ontology_data, entity_id, review_id)
put_post_db_var_ont_con <- function(request_method,
  variation_ontology_data,
  entity_id,
  review_id) {
  ##-------------------------------------------------------------------##
  # get allowed variation ontology terms
  variation_ontology_list <- pool %>%
    tbl("variation_ontology_list") %>%
    select(vario_id) %>%
    arrange(vario_id) %>%
    collect()

  # check if received variation ontology terms are
  # in allowed variation ontology terms
  variation_ontology_allowed <- all(variation_ontology_data$vario_id %in%
    variation_ontology_list$vario_id)

  # prepare variation ontology tibble for submission
  variation_ontology_submission <- variation_ontology_data %>%
    add_column(review_id) %>%
    add_column(entity_id) %>%
    select(review_id, vario_id, modifier_id, entity_id)

  # for the PUT request we check whether the submitted entity ID
  # matches the current one associated with the review id to not
  # allow changing this connection
  variation_ontology_match <- (pool %>%
    tbl("ndd_review_variation_ontology_connect") %>%
    select(review_id, entity_id) %>%
    filter(review_id == {{review_id}}) %>%
    collect() %>%
    unique()
    )$entity_id[1]

  entity_id_match <- (variation_ontology_match == entity_id)

  if (variation_ontology_allowed) {
    if (request_method == "POST") {
      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
        )

      # submit variation ontology terms from new review to database
      dbAppendTable(sysndd_db,
        "ndd_review_variation_ontology_connect",
        variation_ontology_submission
        )

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200, message = "OK. Entry created."))
    } else if (request_method == "PUT" &&
        (entity_id_match || is.na(entity_id_match))) {
      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
        )

      # delete old variation ontology connections for review_id first
      dbExecute(sysndd_db,
        paste0("DELETE FROM ndd_review_variation_ontology_connect ",
        "WHERE review_id = ",
        review_id,
        ";")
        )

      # submit variation ontology terms from new review to database
      dbAppendTable(sysndd_db,
        "ndd_review_variation_ontology_connect",
        variation_ontology_submission
        )

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200,
        message = "OK. Entry created."))
    } else {
      # return Method Not Allowed
      return(list(status = 405,
        message = "Method not Allowed."))
    }

  } else {
    # return Bad Request
    return(list(status = 400,
      message = paste0("Some of the submitted variation ontology ",
        "terms are not in the allowed vario_id list."
        )
      )
    )
  }
  ##-------------------------------------------------------------------##
}


#' Posts or puts a status to the database
#'
#' @param request_method A string specifying the HTTP request method
#' @param status_data A tibble containing status data to be submitted
#' @param re_review A logical indicating whether the status is associated with
#' an entity in a re-review process
#'
#' @return A list with the status, message, and the ID of the submitted/updated status
#' @export
#'
#' @examples
#' put_post_db_status("POST", tibble::tibble(entity_id = 1, category_id = 2))
#' put_post_db_status("PUT", tibble::tibble(status_id = 1, problematic = TRUE))
#'
#' @seealso https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol_status_code
#' @seealso https://cran.r-project.org/web/packages/RMariaDB/vignettes/RMariaDB-intro.html
put_post_db_status <- function(request_method,
  status_data, re_review = FALSE) {
    ##-------------------------------------------------------------------##
    # block to convert the entity components into tibble
    # TODO: comment why compact is used here
    status_received <- purrr::compact(status_data) %>%
      tibble::as_tibble()
    ##-------------------------------------------------------------------##

    ##-------------------------------------------------------------------##
    # make sure re_review input is logical
    re_review <- as.logical(re_review)
    ##-------------------------------------------------------------------##

    if ("category_id" %in% colnames(status_received) ||
        "problematic" %in% colnames(status_received)) {

      # check request type and perform database update accordingly
      if (request_method == "POST" &&
          "entity_id" %in% colnames(status_received)) {
        # remove status_id if provided as input
        status_received <- tryCatch({
          status_received %>%
          select(-status_id)
        }, error = function(e) {
          status_received
        })

        # connect to database
        sysndd_db <- dbConnect(RMariaDB::MariaDB(),
          dbname = dw$dbname,
          user = dw$user,
          password = dw$password,
          server = dw$server,
          host = dw$host,
          port = dw$port
          )

        # submit the new status and disconnect from database
        # and get the id of the last insert for association
        # with other tables
        dbAppendTable(sysndd_db, "ndd_entity_status", status_received)

        # get the id of the last insert
        submitted_status_id <- dbGetQuery(sysndd_db,
            "SELECT LAST_INSERT_ID();") %>%
          tibble::as_tibble() %>%
          select(status_id = `LAST_INSERT_ID()`)

        # execute update query for re_review_entity_connect
        # saving status and status_id if re_review is TRUE
        if (re_review) {
          dbExecute(sysndd_db,
            paste0("UPDATE re_review_entity_connect SET ",
              "re_review_status_saved = 1, ",
              "status_id=",
              submitted_status_id$status_id,
              " WHERE entity_id = ",
              status_data$entity_id,
              ";"))
        }

        # disconnect from database
        dbDisconnect(sysndd_db)

        # return OK
        return(list(status = 200,
          message = "OK. Entry created.",
          entry = submitted_status_id$status_id)
        )

      } else if (request_method == "PUT" &&
                "status_id" %in% colnames(status_received)) {
        # remove entity_id if provided from status_received and
        # remove status_id to prepare update query
        status_received_data <- tryCatch({
          status_received %>%
          select(-entity_id, -status_id)
        }, error = function(e) {
          status_received
        })

        # generate update query
        update_query <- as_tibble(status_received_data) %>%
          mutate(row = row_number()) %>%
          mutate(across(where(is.logical), as.integer)) %>%
          mutate(across(where(is.numeric), as.character)) %>%
          pivot_longer(-row) %>%
          mutate(query = paste0(name, "='", value, "'")) %>%
          select(query) %>%
          summarize(query = str_c(query, collapse = ", "))

        # connect to database
        sysndd_db <- dbConnect(RMariaDB::MariaDB(),
          dbname = dw$dbname,
          user = dw$user,
          password = dw$password,
          server = dw$server,
          host = dw$host,
          port = dw$port
          )

        # submit the new status
        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_status SET ",
          update_query,
          " WHERE status_id = ",
          status_received$status_id, ";")
          )

        # disconnect from database
        dbDisconnect(sysndd_db)

        # return OK
        return(list(status = 200,
          message = "OK. Entry updated.",
          entry = status_received$status_id)
        )
      } else {
      # return Method Not Allowed
      return(list(status = 405,
        message = "Method not Allowed."))
      }

    } else {
      # return error
      return(list(status = 400,
        error = "Submitted data can not be null."))
    }
}


#' Calculate and post a hash for a series of column values
#'
#' This function calculates and posts a hash for a series of column values
#' given as a JSON input. The column names in the JSON input can be
#' controlled with the 'allowed_columns' parameter. The resulting hash is
#' stored in the 'table_hash' table in the database.
#'
#' @param json_data JSON input containing the data to hash
#' @param allowed_columns comma-separated list of column names to allow
#' in the JSON input, defaults to "symbol,hgnc_id,entity_id"
#' @param endpoint endpoint to hash, defaults to "/api/gene"
#'
#' @return A list object with the following components:
#' \item{links}{a tibble with a link to the stored hash in the format
#' "equals(hash, hash_value)"}
#' \item{status}{HTTP status code}
#' \item{message}{message related to the request status}
#' \item{data}{the resulting hash value}
#'
#' @export
#' @seealso generate_json_hash()
post_db_hash <- function(json_data,
    allowed_columns = "symbol,hgnc_id,entity_id",
    endpoint = "/api/gene") {

    # generate list of allowed term from input
    allowed_col_list <- (allowed_columns %>%
        str_split(pattern = ","))[[1]]

    ##-------------------------------------------------------------------##
    # block to convert the json list into tibble
    # then sort it
    # check if the column name is in the allowed identifier list
    # then convert back to JSON and hash it
    # '!!!' in arrange needed to evaluate the external variable as column name
    json_tibble <- as_tibble(json_data)
    json_tibble <- json_tibble %>%
        arrange(!!!rlang::parse_exprs((json_tibble %>% colnames())[1]))

    colnames_allowed <- all((json_tibble %>% colnames()) %in%
        allowed_col_list)

    json_sort <- toJSON(json_tibble)
    ##-------------------------------------------------------------------##


    ##-------------------------------------------------------------------##
    # block to generate hash and check if present in data
    json_sort_hash <- as.character(generate_json_hash(json_sort))

    # get data from database and filter
    table_hash <- pool %>%
      tbl("table_hash") %>%
      filter(hash_256 == json_sort_hash) %>%
      collect()
    ##-------------------------------------------------------------------##


    if (colnames_allowed) {

      if (nrow(table_hash) == 0) {

        hash_tibble <- tibble::tibble(hash_256 = json_sort_hash,
          json_text = as.character(json_sort),
          target_endpoint = endpoint)

        # connect to database
        sysndd_db <- dbConnect(RMariaDB::MariaDB(),
          dbname = dw$dbname,
          user = dw$user,
          password = dw$password,
          server = dw$server,
          host = dw$host,
          port = dw$port
          )

        # submit json string and hash to database
        db_response <- dbAppendTable(sysndd_db,
          "table_hash",
          hash_tibble
          )

        # disconnect from database
        dbDisconnect(sysndd_db)

        # generate links object
        links <- as_tibble(list("hash" =
          paste0("equals(hash,", json_sort_hash, ")")))

        # generate object to return
        return(list(links = links,
          status = 200,
          message = "OK. Hash created.",
          data = json_sort_hash))

      } else {

        # generate links object
        links <- as_tibble(list("hash" =
          paste0("equals(hash,", json_sort_hash, ")")))

        # generate object to return
        return(list(links = links,
          status = 200,
          message = "OK. Hash already present.",
          data = json_sort_hash))

      }

    } else {
    # return Bad Request
    return(list(status = 400,
      message = paste0("The submitted column names are",
      "not in the allowed allowed_columns list."
                )
            )
        )
    }
}


#' Put a review approval to the database
#'
#' This function updates the review approval status in the database
#'
#' @param review_id_requested (integer|character) The id of the review to be updated.
#' If "all", all non-approved reviews will be updated.
#' @param submit_user_id (integer) The user ID of the user who approves the review.
#' @param review_ok (logical) Whether the review is approved or not.
#'
#' @return (list) A list containing the status code, message, and the entry's review id
#' @export
#' @examples
#' put_db_review_approve(1, 2, TRUE)
#' put_db_review_approve("all", 2, FALSE)
put_db_review_approve <- function(review_id_requested,
  submit_user_id,
  review_ok = FALSE) {

    ##-------------------------------------------------------------------##
    # make sure review_ok input is logical
    review_ok <- as.logical(review_ok)
    ##-------------------------------------------------------------------##

    if (!is.null(review_id_requested) &&
        !is.null(submit_user_id)) {

      # set review_id depending on request is all or one
      if (as.character(review_id_requested) == "all") {
        # get data from database and filter
        review_id_requested_tibble <- pool %>%
          tbl("ndd_entity_review") %>%
          filter(review_approved == 0) %>%
          collect() %>%
          select(review_id)

        review_id_requested <- review_id_requested_tibble$review_id
      } else {
        review_id_requested <- as.integer(review_id_requested)
      }

      # get table data from database
      ndd_entity_review_data <- pool %>%
        tbl("ndd_entity_review") %>%
        filter(review_id %in% review_id_requested) %>%
        collect()

      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port)

      # set review if confirmed
      if (review_ok) {
        # reset all reviews in ndd_entity_review to not primary
        dbExecute(sysndd_db, paste0("UPDATE ndd_entity_review ",
          "SET is_primary = 0 ",
          "WHERE entity_id IN (",
          str_c(ndd_entity_review_data$entity_id, collapse = ", "),
          ");"))

        # set the review from ndd_entity_review_data to primary,
        # add approving_user_id and set review_approved status to approved
        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_review SET is_primary = 1 ",
            "WHERE review_id IN (",
            str_c(ndd_entity_review_data$review_id, collapse = ", "),
            ");"))
        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_review SET approving_user_id = ",
            submit_user_id,
            " WHERE review_id IN (",
            str_c(ndd_entity_review_data$review_id, collapse = ", "),
            ");"))
        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_review ",
          "SET review_approved = 1 ",
          "WHERE review_id IN (",
          str_c(ndd_entity_review_data$review_id, collapse = ", "),
          ");"))
      } else {
        # add approving_user_id and set review_approved status to unapproved
        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_review ",
            "SET approving_user_id = ",
            submit_user_id,
            " WHERE review_id IN (",
            str_c(ndd_entity_review_data$review_id, collapse = ", "),
            ");"))
        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_review ",
            "SET review_approved = 0 ",
            "WHERE review_id IN (",
            str_c(ndd_entity_review_data$review_id, collapse = ", "),
            ");"))
      }

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200,
        message = "OK. Review approved.",
        entry = review_id_requested))

    } else {
      # return error
      return(list(status = 400,
        error = "Submitted data can not be null."))
    }
}


#' This function puts a status approval to the database
#'
#' This function updates the status of a database entry to active or inactive depending on the status approval confirmation
#'
#' @param status_id_requested An integer or "all" to indicate the status(es) to update
#' @param submit_user_id An integer identifying the user that submits the request
#' @param status_ok A logical value indicating if the status should be set to active (TRUE) or inactive (FALSE)
#'
#' @return A list with the status, message, and entry
#'
#' @export
#'
#' @examples
#' put_db_status_approve(1, 10, TRUE)
#' put_db_status_approve("all", 10, TRUE)
#' put_db_status_approve(5, 15, FALSE)
#'
#' @seealso
#' \code{\link{put_db_review_approve}}
put_db_status_approve <- function(status_id_requested,
  submit_user_id,
  status_ok = FALSE) {

    ##-------------------------------------------------------------------##
    # make sure status_ok input is logical
    status_ok <- as.logical(status_ok)
    ##-------------------------------------------------------------------##

    if (!is.null(status_id_requested) &&
        !is.null(submit_user_id)) {

      # set status_id depending on request is all or one
      if (as.character(status_id_requested) == "all") {
        # get data from database and filter
        sysndd_db_status_table <- pool %>%
          tbl("ndd_entity_status") %>%
          filter(status_approved == 0) %>%
          collect() %>%
          select(status_id)

        status_id_requested <- sysndd_db_status_table$status_id
      } else {
        status_id_requested <- as.integer(status_id_requested)
      }

      # get table data from database
      ndd_entity_status_data <- pool %>%
        tbl("ndd_entity_status") %>%
        filter(status_id %in% status_id_requested) %>%
        collect()

      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port)

      # set status if confirmed
      if (status_ok) {
        # reset all status in ndd_entity_status to inactive
        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_status SET is_active = 0 ",
            "WHERE entity_id IN (",
            str_c(ndd_entity_status_data$entity_id, collapse = ", "),
            ");"))

        # set status of the new status from ndd_entity_status_data to active,
        # add approving_user_id and set approved status to approved
        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_status SET is_active = 1 ",
          "WHERE status_id IN (",
            str_c(ndd_entity_status_data$status_id, collapse = ", "),
            ");"))

        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_status SET approving_user_id = ",
            submit_user_id,
            " WHERE status_id IN (",
            str_c(ndd_entity_status_data$status_id, collapse = ", "),
            ");"))

        dbExecute(sysndd_db, paste0("UPDATE ndd_entity_status ",
          "SET status_approved = 1 ",
          "WHERE status_id IN (",
            str_c(ndd_entity_status_data$status_id, collapse = ", "),
            ");"))

      } else {
        # add approving_user_id and set approved status to unapproved
        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_status SET approving_user_id = ",
            submit_user_id,
            " WHERE status_id IN (",
            str_c(ndd_entity_status_data$status_id, collapse = ", "),
            ");"))

        dbExecute(sysndd_db,
          paste0("UPDATE ndd_entity_status ",
            "SET status_approved = 0 ",
            "WHERE status_id IN (",
            str_c(ndd_entity_status_data$status_id, collapse = ", "),
            ");"))
      }

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status = 200,
        message = "OK. Status approved.",
        entry = status_id_requested))

    } else {
      # return error
      return(list(status = 400,
        error = "Submitted data can not be null."))
    }
}
