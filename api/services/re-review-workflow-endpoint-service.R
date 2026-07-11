# api/services/re-review-workflow-endpoint-service.R
#
# Endpoint-orchestration layer for the MUTATING re-review endpoints:
# lifecycle (submit/unsubmit/refuse/approve) and batch/assignment/
# recalculation management. Extracted from api/endpoints/re_review_endpoints.R
# (#346) to bring the endpoint file under the 600-line ceiling.
#
# These functions wrap the existing domain services in
# re-review-service.R / re-review-refusal-service.R / status-repository.R /
# review-repository.R; the Reviewer/Curator role gates stay route-local in
# the endpoint file. A couple of handlers (svc_re_review_approve,
# svc_re_review_batch_assign, svc_re_review_batch_unassign) accept `res` and
# set `res$status` directly on their non-200 path, matching the same
# reference-semantics idiom already used by
# api/functions/llm-endpoint-helpers.R and
# api/functions/publication-endpoint-helpers.R — Plumber's response object
# is mutable, so this preserves the exact original response body shape
# (no injected "status" key) without inventing a new envelope convention.

#' `PUT submit` body: build + run the parameterized re-review submit UPDATE.
#'
#' Preserves the security-critical allowlist: only columns surviving
#' `re_review_filter_submit_fields()` (SECURITY #2) reach the SET clause,
#' and params are `unname()`d for the anonymous `?` placeholders.
svc_re_review_submit <- function(submit_data) {
  fields_to_update <- names(submit_data)[names(submit_data) != "re_review_entity_id"]
  fields_to_update <- re_review_filter_submit_fields(fields_to_update)
  set_clause <- paste(paste0(fields_to_update, " = ?"), collapse = ", ")
  sql <- paste0("UPDATE re_review_entity_connect SET ", set_clause, " WHERE re_review_entity_id = ?")

  params <- unname(c(as.list(submit_data[fields_to_update]), list(submit_data$re_review_entity_id)))

  db_execute_statement(sql, params)
}

#' `PUT unsubmit/<id>` body: reset `re_review_submitted` to 0.
svc_re_review_unsubmit <- function(re_review_id) {
  re_review_id <- as.integer(re_review_id)
  db_execute_statement(
    "UPDATE re_review_entity_connect SET re_review_submitted = 0 WHERE re_review_entity_id = ?",
    list(re_review_id)
  )
}

#' `PUT refuse/<id>` body: validate id, delegate to
#' `refuse_re_review_entity()`, and map a non-200 service result to the
#' matching classed RFC 9457 error.
svc_re_review_refuse <- function(re_review_id, user_id, reason) {
  re_review_id <- as.integer(re_review_id)
  if (is.na(re_review_id)) {
    stop_for_bad_request("re_review_id must be an integer")
  }

  result <- refuse_re_review_entity(
    re_review_entity_id = re_review_id,
    user_id = user_id,
    reason = reason,
    pool = pool
  )
  stop_for_rereview_result_error(result)

  list(message = result$message, entry = result$entry)
}

#' `PUT refuse/clear/<id>` body: validate id, delegate to
#' `clear_re_review_refusal()`.
svc_re_review_refuse_clear <- function(re_review_id) {
  re_review_id <- as.integer(re_review_id)
  if (is.na(re_review_id)) {
    stop_for_bad_request("re_review_id must be an integer")
  }

  result <- clear_re_review_refusal(re_review_entity_id = re_review_id, pool = pool)
  stop_for_rereview_result_error(result)

  list(message = result$message, entry = result$entry)
}

#' `PUT approve/<id>` body: look up the connect row, 404 if missing,
#' otherwise delegate to `status_approve()` / `review_approve()`.
svc_re_review_approve <- function(re_review_id, status_ok, review_ok, user_id, res, pool) {
  status_ok <- as.logical(status_ok)
  review_ok <- as.logical(review_ok)
  re_review_id <- as.integer(re_review_id)

  re_review_entity_connect_data <- pool %>%
    tbl("re_review_entity_connect") %>%
    filter(re_review_entity_id == re_review_id) %>%
    collect()

  if (nrow(re_review_entity_connect_data) == 0) {
    res$status <- 404L
    return(list(error = "Re-review record not found"))
  }

  status_approve(
    re_review_entity_connect_data$status_id,
    user_id,
    approved = status_ok
  )
  review_approve(
    re_review_entity_connect_data$review_id,
    user_id,
    approved = review_ok
  )

  list(message = "Re-review approved successfully")
}

#' `GET batch/apply` body: email curators a new-batch request on behalf
#' of the requesting reviewer.
svc_re_review_batch_apply <- function(user_id, pool) {
  user_table <- pool %>%
    tbl("user") %>%
    collect()

  user_info <- user_table %>%
    filter(user_id == !!user_id) %>%
    select(user_id, user_name, email, orcid)

  curator_mail <- user_table %>%
    filter(user_role == "Curator") %>%
    pull(email)

  email_html <- email_rereview_request(
    user_info = list(
      user_name = user_info$user_name,
      email = user_info$email,
      orcid = user_info$orcid %||% ""
    )
  )

  send_noreply_email(
    email_body = email_html,
    email_subject = "SysNDD Re-Review Batch Request Submitted",
    email_recipient = user_info$email,
    email_blind_copy = curator_mail,
    html_content = TRUE
  )
}

#' `PUT batch/assign` body: assign the next available (unassigned) batch
#' to a user and email them.
svc_re_review_batch_assign <- function(user_id_assign, res, pool) {
  user_info <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, email, approved) %>%
    filter(user_id == user_id_assign) %>%
    collect()

  user_id_assign_exists <- as.logical(length(user_info$user_id))

  if (!user_id_assign_exists) {
    res$status <- 409
    return(list(error = "User account does not exist."))
  }

  re_review_assignment <- pool %>%
    tbl("re_review_assignment") %>%
    select(re_review_batch)

  re_review_entity_connect <- pool %>%
    tbl("re_review_entity_connect") %>%
    select(re_review_batch) %>%
    anti_join(re_review_assignment, by = c("re_review_batch")) %>%
    collect() %>%
    unique() %>%
    summarize(re_review_batch = min(re_review_batch))

  re_review_batch_next <- re_review_entity_connect$re_review_batch

  if (is.na(re_review_batch_next)) {
    res$status <- 409
    return(list(error = "No available batches to assign."))
  }

  entity_count <- pool %>%
    tbl("re_review_entity_connect") %>%
    filter(re_review_batch == re_review_batch_next) %>%
    summarize(n = n()) %>%
    collect() %>%
    pull(n)

  db_execute_statement(
    "INSERT INTO re_review_assignment (user_id, re_review_batch) VALUES (?, ?)",
    list(user_id_assign, re_review_batch_next)
  )

  email_html <- email_batch_assigned(
    user_info = list(
      user_name = user_info$user_name,
      email = user_info$email
    ),
    batch_info = list(
      batch_number = re_review_batch_next,
      entity_count = entity_count
    ),
    review_url = paste0(dw$base_url, "/ReReview")
  )

  send_noreply_email(
    email_body = email_html,
    email_subject = "SysNDD Re-Review Batch Assigned",
    email_recipient = user_info$email,
    email_blind_copy = "curator@sysndd.org",
    html_content = TRUE
  )

  list(
    message = "Batch assigned successfully.",
    batch_number = re_review_batch_next,
    entity_count = entity_count
  )
}

#' `DELETE batch/unassign` body: remove an existing batch assignment.
svc_re_review_batch_unassign <- function(re_review_batch, res, pool) {
  re_review_batch_unassign <- as.integer(re_review_batch)

  re_review_assignment_table <- pool %>%
    tbl("re_review_assignment") %>%
    select(re_review_batch) %>%
    filter(re_review_batch == re_review_batch_unassign) %>%
    collect()

  re_review_batch_unassign_ex <- as.logical(
    length(re_review_assignment_table$re_review_batch)
  )

  if (!re_review_batch_unassign_ex) {
    res$status <- 409
    return(list(error = "Batch does not exist."))
  }

  db_execute_statement(
    "DELETE FROM re_review_assignment WHERE re_review_batch = ?",
    list(re_review_batch_unassign)
  )
}

#' Shared criteria mapping for `batch/create`, `batch/preview`, and
#' `batch/recalculate` request bodies. Pure (no I/O).
svc_re_review_extract_criteria <- function(body) {
  list(
    date_range = body$date_range,
    gene_list = body$gene_list,
    status_filter = body$status_filter,
    disease_id = body$disease_id,
    batch_size = body$batch_size %||% 20L
  )
}

#' `POST batch/create` body.
svc_re_review_batch_create <- function(body, pool) {
  criteria <- svc_re_review_extract_criteria(body)
  batch_create(criteria, body$assigned_user_id, body$batch_name, pool)
}

#' `POST batch/preview` body.
svc_re_review_batch_preview <- function(body, pool) {
  criteria <- svc_re_review_extract_criteria(body)
  batch_preview(criteria, criteria$batch_size, pool)
}

#' `PUT batch/reassign` body.
svc_re_review_batch_reassign <- function(re_review_batch, user_id, pool) {
  batch_reassign(as.integer(re_review_batch), as.integer(user_id), pool)
}

#' `PUT batch/archive` body.
svc_re_review_batch_archive <- function(re_review_batch, pool) {
  batch_archive(as.integer(re_review_batch), pool)
}

#' `PUT entities/assign` body: validate the required fields, then
#' delegate to `entity_assign()`.
svc_re_review_entities_assign <- function(body, pool) {
  entity_ids <- body$entity_ids
  user_id <- body$user_id
  batch_name <- body$batch_name

  if (is.null(entity_ids) || length(entity_ids) == 0) {
    return(list(status = 400L, message = "entity_ids is required and must not be empty"))
  }
  if (is.null(user_id)) {
    return(list(status = 400L, message = "user_id is required"))
  }

  entity_assign(as.integer(entity_ids), as.integer(user_id), batch_name, pool)
}

#' `PUT batch/recalculate` body.
svc_re_review_batch_recalculate <- function(body, pool) {
  batch_id <- body$re_review_batch
  criteria <- svc_re_review_extract_criteria(body)

  if (is.null(batch_id)) {
    return(list(status = 400L, message = "re_review_batch is required"))
  }

  batch_recalculate(as.integer(batch_id), criteria, pool)
}
