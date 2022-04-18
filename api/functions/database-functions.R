PostDatabaseEntity <- function(hgnc_id,
  hpo_mode_of_inheritance_term,
  disease_ontology_id_version,
  ndd_phenotype, entry_user_id) {
  if (!is.null(hgnc_id) &
    !is.null(hpo_mode_of_inheritance_term) &
    !is.null(disease_ontology_id_version) &
    !is.null(ndd_phenotype)
    ) {
    ##-------------------------------------------------------------------##
    # block to convert the entity components into tibble
    entity_received <- as_tibble(hgnc_id) %>%
      add_column(hpo_mode_of_inheritance_term) %>%
      add_column(disease_ontology_id_version) %>%
      add_column(ndd_phenotype) %>%
      add_column(entry_user_id) %>%
      select(hgnc_id = value,
        hpo_mode_of_inheritance_term,
        disease_ontology_id_version,
        ndd_phenotype, entry_user_id
        )
    ##-------------------------------------------------------------------##

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
      as_tibble() %>%
      select(entity_id = `LAST_INSERT_ID()`)
    } else if (is.na(as.logical(db_append))) {
    submitted_entity_id <- NA
    db_error <- db_append
    }

    # disconnect from database
    dbDisconnect(sysndd_db)

    if (db_append == 1) {
    # return OK
    return(list(status=200,
      message="OK. Entry created.",
      entry=submitted_entity_id)
      )
    } else if (is.na(as.logical(db_append))) {
    return(list(status=500,
      message="Internal Server Error. Entry not created.",
      entry=submitted_entity_id,
      error=db_error)
      )
    }

    ##-------------------------------------------------------------------##

  } else {
    # return Bad Request
    return(list(status=405,
      message="Submitted entity components can not be empty.")
      )
  }
}


PutPostDatabaseReview <- function(request_method,
  synopsis,
  comment,
  review_user_id,
  entity_id,
  review_id = NULL
  ) {
  if (!is.null(synopsis) & !is.null(entity_id) & nchar(synopsis) > 0) {
    ##-------------------------------------------------------------------##
    # block to convert the review components
    # into independent tibbles and validate
    # convert sysnopsis to tibble, check if comment is null and handle
    if (!is.null(comment)) {
      sysnopsis_received <- as_tibble(synopsis) %>%
        add_column(entity_id) %>%
        add_column(comment) %>%
        add_column(review_user_id) %>%
        select(entity_id, synopsis = value, review_user_id, comment)
    } else {
      sysnopsis_received <- as_tibble(synopsis) %>%
        add_column(entity_id) %>%
        add_column(review_user_id) %>%
        select(entity_id, synopsis = value, review_user_id, comment = NULL)
    }
    ##-------------------------------------------------------------------##

    ##-------------------------------------------------------------------##
    # check request type and perform database update accordingly
    if (request_method == "POST" & is.null(review_id)) {
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
      dbAppendTable(sysndd_db, "ndd_entity_review", sysnopsis_received)
      submitted_review_id <- dbGetQuery(sysndd_db,
          "SELECT LAST_INSERT_ID();"
          ) %>%
        as_tibble() %>%
        select(review_id = `LAST_INSERT_ID()`)

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status=200,
        message="OK. Entry created.",
        entry=submitted_review_id)
        )
      ##-------------------------------------------------------------------##
    } else if (request_method == "PUT" & !is.null(review_id)) {
      ##-------------------------------------------------------------------##
      ## for the put request we update the review and set it's status to 0
      # generate update query, we remove entity_id
      # to not allow canging the review entity connection
      update_query <- sysnopsis_received %>%
        select(-entity_id) %>%
        mutate(row = row_number()) %>%
        mutate(across(where(is.logical), as.integer)) %>%
        mutate(across(where(is.numeric), as.character)) %>%
        pivot_longer(-row) %>%
        mutate(query = paste0(name, "='", value, "'")) %>%
        select(query) %>%
        summarise(query = str_c(query, collapse = ", "))

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
        review_id,
        ";")
        )

      # reset approval status
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review ",
        "SET review_approved=0 WHERE review_id = ",
        review_id,
        ";")
        )

      # reset approval user
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review ",
        "SET approving_user_id=NULL WHERE review_id = ",
        review_id,
        ";")
        )

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status=200, message="OK. Entry created.", entry=review_id))
      ##-------------------------------------------------------------------##
    } else {
      # return Method Not Allowed
      return(list(status=405, message="Method Not Allowed."))
    }
    ##-------------------------------------------------------------------##

  } else {
    # return Bad Request
    return(list(status=405,
      message="Submitted synopsis data can not be empty.")
      )
  }
}


PutPostDatabasePubCon <- function(request_method,
  publication_data,
  entity_id,
  review_id
  ) {
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

  # for the PUT requst we check whether the submitted entity ID
  # matches the curent one associated with the review id to
  # not allow changing this connection
  ndd_review_publication_for_match <- (pool %>%
    tbl("ndd_review_publication_join") %>%
    select(review_id, entity_id) %>%
    filter(review_id == {{review_id}}) %>%
    collect() %>%
    unique()
    )$entity_id[1]

  entity_id_match <- (ndd_review_publication_for_match == entity_id)

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
      return(list(status=200,
        message="OK. Entry created.")
        )
    } else if (request_method == "PUT" & entity_id_match) {
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
      return(list(status=200, message="OK. Entry created."))
    } else {
      # return Method Not Allowed
      return(list(status=405, message="Method not Allowed."))
    }
  } else {
    # return Bad Request
    return(list(status=400,
      message=paste0("Some of the submitted publications are not in",
        "the allowed in the publications list. Add them there first."
        )
      )
    )
  }
  ##-------------------------------------------------------------------##
}


PutPostDatabasePhenCon <- function(request_method,
  phenotypes_data,
  entity_id,
  review_id
  ) {
  ##-------------------------------------------------------------------##
  # get allowed HPO terms
  phenotype_list_collected <- pool %>%
    tbl("phenotype_list") %>%
    select(phenotype_id) %>%
    arrange(HPO_term) %>%
    collect()

  # check if received phenoytpes are in allowed phenotypes
  phenoytpes_allowed <- all(phenotypes_data$phenotype_id %in%
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

  if (phenoytpes_allowed) {
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
      return(list(status=200, message="OK. Entry created."))
    } else if (request_method == "PUT" & entity_id_match) {
      # connect to database
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
        )

      # delete old phenotype connections for review_id first
      dbExecute(sysndd_db,
        paste0("DELETE FROM ndd_review_phenotype_connect WHERE review_id = ",
        review_id,
        ";")
        )

      # submit phenotypes from new review to database
      dbAppendTable(sysndd_db,
        "ndd_review_phenotype_connect",
        phenotypes_submissio
        )

      # disconnect from database
      dbDisconnect(sysndd_db)

      # return OK
      return(list(status=200, message="OK. Entry created."))
    } else {
      # return Method Not Allowed
      return(list(status=405, message="Method not Allowed."))
    }

  } else {
    # return Bad Request
    return(list(status=400,
      message=paste0("Some of the submitted phenotypes are",
      "not in the allowed phenotype_id list."
      )
      )
    )
  }
  ##-------------------------------------------------------------------##
}


PutPostDatabaseVarOntCon <- function(request_method,
  variation_ontology_data,
  entity_id,
  review_id
  ) {
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
    select(review_id, vario_id, entity_id)

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
      return(list(status=200, message="OK. Entry created."))
    } else if (request_method == "PUT" & entity_id_match) {
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
      return(list(status=200, message="OK. Entry created."))
    } else {
      # return Method Not Allowed
      return(list(status=405, message="Method not Allowed."))
    }

  } else {
    # return Bad Request
    return(list(status=400,
      message=paste0("Some of the submitted variation ontology ",
        "terms are not in the allowed vario_id list."
        )
      )
    )
  }
  ##-------------------------------------------------------------------##
}


PutPostDatabaseStatus <- function(request_method, status_data, status_user_id) {

    if (!is.null(status_data$category) | !is.null(status_data$problematic)) {

      # convert status data to tibble, check if comment is null and handle
      if (!is.null(status_data$comment)) {
        status_received <- as_tibble(status_data) %>%
          add_column(status_user_id)
      } else {
        status_data$comment <- ""
        status_received <- as_tibble(status_data) %>%
          add_column(status_user_id) %>%
          select(-comment)
      }

      # check request type and perform database update accoringly
      if (request_method == "POST" & !is.null(status_data$entity_id)) {
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
        # disconnect from database
        dbDisconnect(sysndd_db)

        # return OK
        return(list(status=200, message="OK. Entry created."))

      } else if (request_method == "PUT" & !is.null(status_data$status_id)) {
        # remove entity_id if provided from status_received and
        # remove status_id to prepare update query
        status_received <- tryCatch({
          status_received %>%
          select(-entity_id, -status_id)
        }, error = function(e) {
          status_received
        })

        # generate update query
        update_query <- as_tibble(status_received) %>%
          mutate(row = row_number()) %>%
          mutate(across(where(is.logical), as.integer)) %>%
          mutate(across(where(is.numeric), as.character)) %>%
          pivot_longer(-row) %>%
          mutate(query = paste0(name, "='", value, "'")) %>%
          select(query) %>%
          summarise(query = str_c(query, collapse = ", "))

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
          status_data$status_id, ";")
          )

        # disconnect from database
        dbDisconnect(sysndd_db)

        # return OK
        return(list(status=200, message="OK. Entry updated."))
      } else {
      # return Method Not Allowed
      return(list(status=405, message="Method not Allowed."))
      }

    } else {
      # return error
      return(list(status=400, error="Submitted data can not be null."))
    }
}