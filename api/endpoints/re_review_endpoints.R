# api/endpoints/re_review_endpoints.R
#
# This file contains all Re-review-related endpoints, extracted from
# the original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible.

# Note: db-helpers.R is sourced by start_sysndd_api.R before endpoints are loaded
# Functions like db_execute_statement are available in the global environment

## -------------------------------------------------------------------##
## Re-review endpoints
## -------------------------------------------------------------------##

#* Submit a Re-Review Entry
#*
#* Allows users with roles (Administrator, Curator, Reviewer) to submit a
#* re-review entry in the DB.
#*
#* # `Details`
#* Updates the re_review_entity_connect table accordingly.
#*
#* # `Return`
#* If successful, returns success message or updated entry. Otherwise, an error.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put submit
function(req, res) {
  require_role(req, res, "Reviewer")

  submit_user_id <- req$user_id
  submit_data <- req$argsBody$submit_json

  # Build parameterized UPDATE query dynamically
  fields_to_update <- names(submit_data)[names(submit_data) != "re_review_entity_id"]
  set_clause <- paste(paste0(fields_to_update, " = ?"), collapse = ", ")
  sql <- paste0("UPDATE re_review_entity_connect SET ", set_clause, " WHERE re_review_entity_id = ?")

  # Parameters: field values + re_review_entity_id
  # IMPORTANT: Must unname for anonymous (?) placeholders
  params <- unname(c(as.list(submit_data[fields_to_update]), list(submit_data$re_review_entity_id)))

  db_execute_statement(sql, params)
}


#* Unsubmit a Re-Review Entry
#*
#* Allows (Administrator, Curator) to revert a re-review entry to un-submitted.
#*
#* # `Details`
#* Sets re_review_submitted = 0 in the DB for that re_review_entity_id.
#*
#* # `Return`
#* If successful, a success message. Otherwise, an error.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put unsubmit/<re_review_id>
function(req, res, re_review_id) {
  require_role(req, res, "Curator")

  submit_user_id <- req$user_id
  re_review_id <- as.integer(re_review_id)

  db_execute_statement(
    "UPDATE re_review_entity_connect SET re_review_submitted = 0 WHERE re_review_entity_id = ?",
    list(re_review_id)
  )
}


#* Approve a Re-Review Entry
#*
#* Allows (Administrator, Curator) to approve a re-review entry.
#*
#* # `Details`
#* Depending on status_ok and review_ok, updates DB fields.
#*
#* # `Return`
#* Success message or error.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_id The ID of the re-review entry.
#* @param status_ok Whether the status is approved.
#* @param review_ok Whether the review is approved.
#*
#* @put approve/<re_review_id>
function(req, res, re_review_id, status_ok = FALSE, review_ok = FALSE) {
  require_role(req, res, "Curator")

  status_ok <- as.logical(status_ok)
  review_ok <- as.logical(review_ok)
  submit_user_id <- req$user_id
  re_review_id <- as.integer(re_review_id)

  re_review_entity_connect_data <- pool %>%
    tbl("re_review_entity_connect") %>%
    filter(re_review_entity_id == re_review_id) %>%
    collect()

  # If status_ok, set new status active, reset older ones.
  if (status_ok) {
    db_execute_statement(
      "UPDATE ndd_entity_status SET is_active = 0 WHERE entity_id = ?",
      list(re_review_entity_connect_data$entity_id)
    )
    db_execute_statement(
      "UPDATE ndd_entity_status SET is_active = 1 WHERE status_id = ?",
      list(re_review_entity_connect_data$status_id)
    )
    db_execute_statement(
      "UPDATE ndd_entity_status SET approving_user_id = ? WHERE status_id = ?",
      list(submit_user_id, re_review_entity_connect_data$status_id)
    )
    db_execute_statement(
      "UPDATE ndd_entity_status SET status_approved = 1 WHERE status_id = ?",
      list(re_review_entity_connect_data$status_id)
    )
  } else {
    db_execute_statement(
      "UPDATE ndd_entity_status SET approving_user_id = ? WHERE status_id = ?",
      list(submit_user_id, re_review_entity_connect_data$status_id)
    )
    db_execute_statement(
      "UPDATE ndd_entity_status SET status_approved = 0 WHERE status_id = ?",
      list(re_review_entity_connect_data$status_id)
    )
  }

  # If review_ok, reset old primary, set new primary
  if (review_ok) {
    db_execute_statement(
      "UPDATE ndd_entity_review SET is_primary = 0 WHERE entity_id = ?",
      list(re_review_entity_connect_data$entity_id)
    )
    db_execute_statement(
      "UPDATE ndd_entity_review SET is_primary = 1 WHERE review_id = ?",
      list(re_review_entity_connect_data$review_id)
    )
    db_execute_statement(
      "UPDATE ndd_entity_review SET approving_user_id = ? WHERE review_id = ?",
      list(submit_user_id, re_review_entity_connect_data$review_id)
    )
    db_execute_statement(
      "UPDATE ndd_entity_review SET review_approved = 1 WHERE review_id = ?",
      list(re_review_entity_connect_data$review_id)
    )
  } else {
    db_execute_statement(
      "UPDATE ndd_entity_review SET approving_user_id = ? WHERE review_id = ?",
      list(submit_user_id, re_review_entity_connect_data$review_id)
    )
    db_execute_statement(
      "UPDATE ndd_entity_review SET review_approved = 0 WHERE review_id = ?",
      list(re_review_entity_connect_data$review_id)
    )
  }

  # Mark re_review_approved
  db_execute_statement(
    "UPDATE re_review_entity_connect SET re_review_approved = 1 WHERE re_review_entity_id = ?",
    list(re_review_id)
  )
  db_execute_statement(
    "UPDATE re_review_entity_connect SET approving_user_id = ? WHERE re_review_entity_id = ?",
    list(submit_user_id, re_review_id)
  )
}


#* Get Re-Review Overview Table
#*
#* Returns the re-review overview table for the authenticated user.
#*
#* # `Details`
#* The function filters the re-review data based on the provided `filter` and
#* `curate` parameters. Admin/Curators can see curated or uncurated sets.
#* Reviewers see only unsubmitted sets assigned to them.
#* Supports cursor pagination for large re-review lists.
#*
#* # `Return`
#* Returns a re-review overview table if successful, or an error message.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param filter Condition for the re-review data.
#* @param curate Boolean indicating whether to see curated or not.
#* @param page_after Cursor after which entries are shown (default: 0)
#* @param page_size Page size in cursor pagination (default: "all")
#*
#* @get table
function(req,
         res,
         filter = "equals(re_review_approved,0)",
         curate = FALSE,
         page_after = 0,
         page_size = "all") {
  curate <- as.logical(curate)

  # Curate mode requires Curator+, non-curate requires Reviewer+
  if (curate) {
    require_role(req, res, "Curator")
  } else {
    require_role(req, res, "Reviewer")
  }

  filter_exprs <- generate_filter_expressions(filter)
  user <- req$user_id

  re_review_entity_connect <- pool %>%
    tbl("re_review_entity_connect") %>%
    filter(re_review_approved == 0) %>%
    {
      if (curate) {
        filter(., re_review_submitted == 1)
      } else {
        filter(., re_review_submitted == 0)
      }
    }

  re_review_assignment <- pool %>%
    tbl("re_review_assignment") %>%
    {
      if (!curate) {
        filter(., user_id == user)
      } else {
        .
      }
    }

  ndd_entity_view <- pool %>%
    tbl("ndd_entity_view")

  ndd_entity_status_category <- pool %>%
    tbl("ndd_entity_status") %>%
    select(status_id, category_id)

  ndd_entity_status_categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list")

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, user_role)

  review_user_collected <- pool %>%
    tbl("ndd_entity_review") %>%
    left_join(user_table, by = c("review_user_id" = "user_id")) %>%
    select(
      review_id,
      review_date,
      review_user_id,
      review_user_name = user_name,
      review_user_role = user_role,
      review_approving_user_id = approving_user_id
    )

  status_user_collected <- pool %>%
    tbl("ndd_entity_status") %>%
    left_join(user_table, by = c("status_user_id" = "user_id")) %>%
    select(
      status_id,
      status_date,
      status_user_id,
      status_user_name = user_name,
      status_user_role = user_role,
      status_approving_user_id = approving_user_id
    )

  re_review_user_list <- re_review_entity_connect %>%
    inner_join(re_review_assignment, by = c("re_review_batch")) %>%
    select(
      re_review_entity_id,
      entity_id,
      re_review_review_saved,
      re_review_status_saved,
      re_review_submitted,
      re_review_approved,
      status_id,
      review_id
    ) %>%
    inner_join(ndd_entity_view, by = c("entity_id")) %>%
    select(-category_id, -category) %>%
    inner_join(ndd_entity_status_category, by = c("status_id")) %>%
    inner_join(ndd_entity_status_categories_list, by = c("category_id")) %>%
    inner_join(review_user_collected, by = c("review_id")) %>%
    inner_join(status_user_collected, by = c("status_id")) %>%
    collect() %>%
    arrange(re_review_entity_id) %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # Apply pagination
  pagination_info <- generate_cursor_pag_inf_safe(
    re_review_user_list,
    page_size,
    page_after,
    "re_review_entity_id"
  )

  list(
    links = pagination_info$links,
    meta = pagination_info$meta,
    data = pagination_info$data
  )
}


#* Request New Re-Review Batch
#*
#* Allows the authenticated user to request a new batch of entities for re-review
#* by emailing curators.
#*
#* # `Details`
#* Sends an email to curators with the user info.
#*
#* # `Return`
#* 200 OK if email successfully sent, else error.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @get batch/apply
function(req, res) {
  require_role(req, res, "Reviewer")

  user <- req$user_id

  user_table <- pool %>%
    tbl("user") %>%
    collect()

  user_info <- user_table %>%
    filter(user_id == user) %>%
    select(user_id, user_name, email, orcid)

  curator_mail <- user_table %>%
    filter(user_role == "Curator") %>%
    pull(email)

  # Generate professional HTML email using template
  email_html <- email_rereview_request(
    user_info = list(
      user_name = user_info$user_name,
      email = user_info$email,
      orcid = user_info$orcid %||% ""
    )
  )

  res_mail <- send_noreply_email(
    email_body = email_html,
    email_subject = "SysNDD Re-Review Batch Request Submitted",
    email_recipient = user_info$email,
    email_blind_copy = curator_mail,
    html_content = TRUE
  )
  res_mail
}


#* Assign New Re-Review Batch
#*
#* Allows Admin/Curator to assign a new batch of entities for re-review
#* to a specified user.
#*
#* # `Details`
#* Computes the next batch, inserts into re_review_assignment table.
#*
#* # `Return`
#* Success if assigned, or error if user doesn’t exist.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param user_id The ID of the user to assign the batch to.
#*
#* @put batch/assign
function(req, res, user_id) {
  require_role(req, res, "Curator")

  user_id_assign <- as.integer(user_id)

  # Get assignee user info for email

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

  # Find next available batch
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

  # Get entity count for the batch
  entity_count <- pool %>%
    tbl("re_review_entity_connect") %>%
    filter(re_review_batch == re_review_batch_next) %>%
    summarize(n = n()) %>%
    collect() %>%
    pull(n)

  # Insert assignment
  db_execute_statement(
    "INSERT INTO re_review_assignment (user_id, re_review_batch) VALUES (?, ?)",
    list(user_id_assign, re_review_batch_next)
  )

  # Send notification email to assignee
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


#* Unassign Re-Review Batch
#*
#* Allows Admin/Curator to unassign a re-review batch based on the provided
#* re_review_batch.
#*
#* # `Details`
#* Removes the assignment from re_review_assignment table.
#*
#* # `Return`
#* If successful, unassigns the batch. Otherwise, error.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_batch The ID of the re-review batch to unassign.
#*
#* @delete batch/unassign
function(req, res, re_review_batch) {
  require_role(req, res, "Curator")

  user <- req$user_id
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


#* Get Re-Review Assignment Table
#*
#* Returns summary statistics of all re-review batch assignments - entities
#* reviewed, etc.
#*
#* # `Return`
#* Summary table of re-review batch assignments, or an error if not admin/curator.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @get assignment_table
function(req, res) {
  require_role(req, res, "Curator")

  user <- req$user_id

  re_review_entity_connect_table <- pool %>%
    tbl("re_review_entity_connect") %>%
    select(
      re_review_batch,
      re_review_review_saved,
      re_review_status_saved,
      re_review_submitted,
      re_review_approved
    ) %>%
    group_by(re_review_batch) %>%
    collect() %>%
    mutate(entity_count = 1) %>%
    summarize_at(vars(re_review_review_saved:entity_count), sum)

  re_review_assignment_table <- pool %>%
    tbl("re_review_assignment")

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name)

  re_review_assign_table_user <- re_review_assignment_table %>%
    left_join(user_table, by = c("user_id")) %>%
    collect() %>%
    left_join(re_review_entity_connect_table, by = c("re_review_batch")) %>%
    select(
      assignment_id,
      user_id,
      user_name,
      re_review_batch,
      re_review_review_saved,
      re_review_status_saved,
      re_review_submitted,
      re_review_approved,
      entity_count
    ) %>%
    arrange(user_id)

  re_review_assign_table_user
}


## -------------------------------------------------------------------##
## Re-review Batch Management Endpoints (Dynamic)
## -------------------------------------------------------------------##

#* Create a new Re-Review Batch dynamically
#*
#* Creates a batch based on provided criteria (date range, gene list, status, disease).
#* Optionally assigns to a user during creation.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @post batch/create
function(req, res) {
  require_role(req, res, "Curator")

  # Parse request body
  body <- req$argsBody

  # Extract criteria
  criteria <- list(
    date_range = body$date_range, # list(start="YYYY-MM-DD", end="YYYY-MM-DD")
    gene_list = body$gene_list, # array of hgnc_id integers
    status_filter = body$status_filter, # category_id integer
    disease_id = body$disease_id, # disease ontology id string
    batch_size = body$batch_size %||% 20L
  )

  assigned_user_id <- body$assigned_user_id # optional
  batch_name <- body$batch_name # optional

  result <- batch_create(criteria, assigned_user_id, batch_name, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}


#* Preview matching entities for batch criteria
#*
#* Returns entities that would be included in a batch without creating it.
#* Useful for reviewing criteria before committing.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @post batch/preview
function(req, res) {
  require_role(req, res, "Curator")

  body <- req$argsBody

  criteria <- list(
    date_range = body$date_range,
    gene_list = body$gene_list,
    status_filter = body$status_filter,
    disease_id = body$disease_id,
    batch_size = body$batch_size %||% 20L
  )

  result <- batch_preview(criteria, criteria$batch_size, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}


#* Reassign Re-Review Batch to different user
#*
#* Changes the assigned user for an existing batch.
#* Can reassign at any time (per CONTEXT decision).
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_batch The batch ID to reassign
#* @param user_id The new user ID to assign to
#*
#* @put batch/reassign
function(req, res, re_review_batch, user_id) {
  require_role(req, res, "Curator")

  batch_id <- as.integer(re_review_batch)
  new_user_id <- as.integer(user_id)

  result <- batch_reassign(batch_id, new_user_id, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}


#* Archive (soft delete) a Re-Review Batch
#*
#* Removes batch assignment, preserving entity connect records for audit.
#* Only allowed for batches not yet completed (per CONTEXT decision).
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_batch The batch ID to archive
#*
#* @put batch/archive
function(req, res, re_review_batch) {
  require_role(req, res, "Curator")

  batch_id <- as.integer(re_review_batch)

  result <- batch_archive(batch_id, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}


#* Assign specific entities/genes to a user for re-review
#*
#* Creates a new batch containing only the specified entities and assigns to user.
#* Enables gene-specific assignment where admin selects specific genes for specific user.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put entities/assign
function(req, res) {
  require_role(req, res, "Curator")

  body <- req$argsBody

  entity_ids <- body$entity_ids # array of entity_id integers (required)
  user_id <- body$user_id # user to assign to (required)
  batch_name <- body$batch_name # optional custom batch name

  if (is.null(entity_ids) || length(entity_ids) == 0) {
    res$status <- 400L
    return(list(status = 400L, message = "entity_ids is required and must not be empty"))
  }

  if (is.null(user_id)) {
    res$status <- 400L
    return(list(status = 400L, message = "user_id is required"))
  }

  result <- entity_assign(as.integer(entity_ids), as.integer(user_id), batch_name, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}


#* Recalculate batch entity membership based on updated criteria
#*
#* Re-assigns entities to a batch based on new criteria.
#* Only allowed for batches not yet assigned (unassigned batches only).
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put batch/recalculate
function(req, res) {
  require_role(req, res, "Curator")

  body <- req$argsBody

  batch_id <- body$re_review_batch
  criteria <- list(
    date_range = body$date_range,
    gene_list = body$gene_list,
    status_filter = body$status_filter,
    disease_id = body$disease_id,
    batch_size = body$batch_size %||% 20L
  )

  if (is.null(batch_id)) {
    res$status <- 400L
    return(list(status = 400L, message = "re_review_batch is required"))
  }

  result <- batch_recalculate(as.integer(batch_id), criteria, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}
