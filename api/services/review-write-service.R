# Focused review-save coordinator.
#
# Phase A prepares and validates without a write transaction. Phase B performs
# every review-related mutation on one connection, so a late join failure rolls
# back the review, all joins, the re-review marker, and optional approval.

review_write_assert_raw_ontology_fields <- function(terms, id_field) {
  if (is.null(terms) || length(terms) == 0L) {
    return(invisible(TRUE))
  }

  assert_row <- function(row) {
    row_names <- names(row)
    uses_tag <- "value" %in% row_names
    id_value <- if (uses_tag) row$value else row[[id_field]]
    if (is.null(id_value) ||
        (is.list(id_value) && any(vapply(id_value, is.null, logical(1))))) {
      stop_for_bad_request(paste0(id_field, " must be a non-blank ontology identifier."))
    }

    if (!uses_tag && "modifier_id" %in% row_names) {
      modifier_value <- row$modifier_id
      if (is.null(modifier_value) ||
          (is.list(modifier_value) && any(vapply(modifier_value, is.null, logical(1))))) {
        stop_for_bad_request(paste0("modifier_id for ", id_field, " must be an integer."))
      }
    }

    invisible(TRUE)
  }

  if (is.data.frame(terms)) {
    assert_row(terms)
  } else if (is.list(terms)) {
    term_names <- names(terms)
    is_row <- !is.null(term_names) &&
      any(c("value", id_field, "modifier_id") %in% term_names)
    if (is_row) {
      assert_row(terms)
    } else {
      lapply(terms, function(term) {
        if (is.list(term) || is.data.frame(term)) {
          assert_row(term)
        }
        invisible(TRUE)
      })
    }
  }

  invisible(TRUE)
}

review_write_empty_terms <- function(id_field) {
  out <- tibble::tibble(modifier_id = integer())
  out[[id_field]] <- character()
  dplyr::select(out, dplyr::all_of(c(id_field, "modifier_id")))
}

review_write_normalize_ontology <- function(terms, id_field) {
  if (is.null(terms) || length(terms) == 0L) {
    return(review_write_empty_terms(id_field))
  }

  review_write_assert_raw_ontology_fields(terms, id_field)
  terms <- tibble::as_tibble(terms)
  if (nrow(terms) == 0L) {
    return(review_write_empty_terms(id_field))
  }

  if ("value" %in% names(terms)) {
    value <- as.character(terms$value)
    separator <- regexpr("-", value, fixed = TRUE)
    modifier <- ifelse(separator > 0L, substr(value, 1L, separator - 1L), NA_character_)
    ontology_id <- ifelse(separator > 0L, substr(value, separator + 1L, nchar(value)), NA_character_)
  } else {
    if (!id_field %in% names(terms) || !"modifier_id" %in% names(terms)) {
      stop_for_bad_request(
        paste0("Each ontology row requires ", id_field, " and modifier_id.")
      )
    }
    ontology_id <- as.character(terms[[id_field]])
    modifier <- terms$modifier_id
  }

  ontology_id <- trimws(ontology_id)
  if (any(is.na(ontology_id) | !nzchar(ontology_id))) {
    stop_for_bad_request(paste0(id_field, " must be a non-blank ontology identifier."))
  }

  modifier_id <- suppressWarnings(as.integer(trimws(as.character(modifier))))
  if (any(is.na(modifier_id))) {
    stop_for_bad_request(paste0("modifier_id for ", id_field, " must be an integer."))
  }

  out <- tibble::tibble(modifier_id = modifier_id)
  out[[id_field]] <- ontology_id
  dplyr::select(out, dplyr::all_of(c(id_field, "modifier_id")))
}

review_write_validate_required <- function(value, field) {
  if (is.null(value) || length(value) != 1L || is.na(value) ||
      (is.character(value) && !nzchar(trimws(value)))) {
    stop_for_bad_request(paste0(field, " is required."))
  }
  invisible(TRUE)
}

review_write_validate_lookup_ids <- function(ids, table, column, db) {
  if (length(ids) == 0L) {
    return(invisible(TRUE))
  }

  ids <- unique(as.character(ids))
  placeholders <- paste(rep("?", length(ids)), collapse = ", ")
  found <- db_execute_query(
    paste0("SELECT ", column, " FROM ", table, " WHERE ", column, " IN (", placeholders, ")"),
    as.list(ids),
    conn = db
  )[[column]]
  invalid <- setdiff(ids, as.character(found))
  if (length(invalid) > 0L) {
    stop_for_bad_request(
      paste0(column, " contains unknown ontology identifier(s): ", paste(invalid, collapse = ", "))
    )
  }

  invisible(TRUE)
}

review_write_prepare <- function(method, review_data, publications,
                                 phenotypes, variation_ontology,
                                 review_user_id, db) {
  method <- toupper(as.character(method))
  if (!method %in% c("POST", "PUT")) {
    stop_for_bad_request("Review write method must be POST or PUT.")
  }

  review_write_validate_required(review_data$entity_id, "entity_id")
  review_write_validate_required(review_data$synopsis, "synopsis")
  review_write_validate_required(review_user_id, "review_user_id")
  if (identical(method, "PUT")) {
    review_write_validate_required(review_data$review_id, "review_id")
  }

  phenotypes <- review_write_normalize_ontology(phenotypes, "phenotype_id")
  variation_ontology <- review_write_normalize_ontology(variation_ontology, "vario_id")
  review_write_validate_lookup_ids(
    phenotypes$phenotype_id, "phenotype_list", "phenotype_id", db
  )
  review_write_validate_lookup_ids(
    variation_ontology$vario_id, "variation_ontology_list", "vario_id", db
  )
  review_write_validate_lookup_ids(
    phenotypes$modifier_id, "modifier_list", "modifier_id", db
  )
  review_write_validate_lookup_ids(
    variation_ontology$modifier_id, "modifier_list", "modifier_id", db
  )

  if (identical(method, "PUT")) {
    owner <- db_execute_query(
      "SELECT entity_id FROM ndd_entity_review WHERE review_id = ?",
      list(as.integer(review_data$review_id)),
      conn = db
    )
    if (nrow(owner) != 1L || owner$entity_id[[1L]] != as.integer(review_data$entity_id)) {
      stop_for_bad_request("review_id does not belong to entity_id.")
    }
  }

  publications <- publication_write_classify_genereviews(publications)
  prepared_publications <- tryCatch(
    publication_write_prepare(publications, db = db),
    publication_fetch_error = function(error) {
      stop_for_bad_request(error$message)
    }
  )

  review_data$entity_id <- as.integer(review_data$entity_id)
  review_data$review_user_id <- as.integer(review_user_id)
  if (!is.null(review_data$review_id)) {
    review_data$review_id <- as.integer(review_data$review_id)
  }

  list(
    method = method,
    review_data = review_data,
    publications = tibble::as_tibble(publications),
    prepared_publications = prepared_publications,
    phenotypes = phenotypes,
    variation_ontology = variation_ontology
  )
}

review_write_mutate <- function(prepared, txn_conn, re_review,
                                direct_approval, review_user_id) {
  publication_write_persist(prepared$prepared_publications, conn = txn_conn)

  if (identical(prepared$method, "POST")) {
    review_id <- review_create(prepared$review_data, conn = txn_conn)
    message <- "OK. Review created."
  } else {
    review_id <- as.integer(prepared$review_data$review_id)
    review_update(review_id, prepared$review_data, conn = txn_conn)
    message <- "OK. Review updated."
  }

  entity_id <- prepared$review_data$entity_id
  if (nrow(prepared$publications) > 0L) {
    if (identical(prepared$method, "POST")) {
      publication_connect_to_review(review_id, entity_id, prepared$publications, conn = txn_conn)
    } else {
      publication_replace_for_review(review_id, entity_id, prepared$publications, conn = txn_conn)
    }
  } else if (identical(prepared$method, "PUT")) {
    publication_replace_for_review(
      review_id, entity_id,
      tibble::tibble(publication_id = character(), publication_type = character()),
      conn = txn_conn
    )
  }

  if (identical(prepared$method, "POST")) {
    phenotype_connect_to_review(review_id, entity_id, prepared$phenotypes, conn = txn_conn)
    variation_ontology_connect_to_review(
      review_id, entity_id, prepared$variation_ontology, conn = txn_conn
    )
  } else {
    phenotype_replace_for_review(review_id, entity_id, prepared$phenotypes, conn = txn_conn)
    variation_ontology_replace_for_review(
      review_id, entity_id, prepared$variation_ontology, conn = txn_conn
    )
  }

  if (isTRUE(re_review)) {
    review_update_re_review_status(entity_id, review_id, conn = txn_conn)
  }
  if (isTRUE(direct_approval)) {
    review_approve(review_id, review_user_id, approved = TRUE, conn = txn_conn)
  }

  list(review_id = as.integer(review_id), message = message)
}

review_write_run_mutation <- function(prepared, db, mutation_fn,
                                      transaction_runner = db_with_transaction) {
  run <- function(txn_conn) mutation_fn(prepared, txn_conn)
  if (inherits(db, "DBIConnection")) {
    # Direct connections are caller-owned (notably with_test_db_transaction()).
    # A savepoint gives this write unit rollback semantics without asking
    # RMariaDB to start an unsupported nested transaction.
    DBI::dbExecute(db, "SAVEPOINT review_write_mutation")
    return(tryCatch(
      {
        result <- run(db)
        DBI::dbExecute(db, "RELEASE SAVEPOINT review_write_mutation")
        result
      },
      error = function(error) {
        DBI::dbExecute(db, "ROLLBACK TO SAVEPOINT review_write_mutation")
        stop(error)
      }
    ))
  }
  transaction_runner(run, pool_obj = db)
}

svc_review_write <- function(method, review_data, publications = tibble::tibble(),
                             phenotypes = tibble::tibble(),
                             variation_ontology = tibble::tibble(),
                             re_review = FALSE, direct_approval = FALSE,
                             review_user_id, db,
                             prepare_fn = review_write_prepare,
                             mutation_fn = review_write_mutate,
                             transaction_runner = db_with_transaction) {
  # Keep client-visible ontology-shape failures ahead of every injectable
  # preparation step, external lookup, and transaction boundary.
  review_write_normalize_ontology(phenotypes, "phenotype_id")
  review_write_normalize_ontology(variation_ontology, "vario_id")

  prepared <- prepare_fn(
    method = method,
    review_data = review_data,
    publications = publications,
    phenotypes = phenotypes,
    variation_ontology = variation_ontology,
    review_user_id = review_user_id,
    db = db
  )
  result <- review_write_run_mutation(
    prepared = prepared,
    db = db,
    mutation_fn = function(prepared_data, txn_conn) {
      mutation_fn(
        prepared_data,
        txn_conn,
        re_review = re_review,
        direct_approval = direct_approval,
        review_user_id = review_user_id
      )
    },
    transaction_runner = transaction_runner
  )

  list(
    status = 200L,
    message = as.character(if (is.null(result$message)) "OK. Review stored." else result$message),
    entry = tibble::tibble(review_id = as.integer(result$review_id))
  )
}
