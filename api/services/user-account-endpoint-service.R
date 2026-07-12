# api/services/user-account-endpoint-service.R
#
# Endpoint service for the account-mutation routes in
# endpoints/user_endpoints.R: approval, role change, delete, and the
# Administrator bulk-field update. `require_role()` gates and the
# admin-target shield (`assert_not_targeting_admin()`, #5) stay in the
# endpoint shells; these `svc_` functions hold the request-processing logic
# behind them.

#' Fetch the approval-relevant columns for a single target user.
#'
#' Used by the `PUT /api/user/approval` shell before the existence check and
#' admin-target shield.
#'
#' @param user_id_approval Integer target user id.
#' @return Zero- or one-row tibble.
svc_user_fetch_for_approval <- function(user_id_approval) {
  pool %>%
    tbl("user") %>%
    select(user_id, user_name, approved, first_name, family_name, email, user_role) %>%
    filter(user_id == user_id_approval) %>%
    collect()
}

#' Approve or reject a pending user application.
#'
#' Behind `PUT /api/user/approval`, called after the shell has already
#' fetched `user_table` (existence-checked) and cleared the admin-target
#' shield.
#'
#' @param req Plumber request (needs `req$user_id` for the audit log line).
#' @param res Plumber response (mutated on already-active/email-failure paths).
#' @param user_table Single-row tibble for the target user.
#' @param user_id_approval Integer target user id.
#' @param status_approval Logical: `TRUE` approves, `FALSE` rejects.
#' @return List response body.
svc_user_approval_apply <- function(req, res, user_table, user_id_approval, status_approval) {
  # Early return: already approved
  if (as.logical(user_table$approved[1])) {
    res$status <- 409
    return(list(error = "User account already active."))
  }

  # Handle rejection (simpler path first)
  if (!status_approval) {
    db_execute_statement(
      "DELETE FROM user WHERE user_id = ?",
      list(user_id_approval)
    )
    log_info("User rejected and deleted: user_id={user_id_approval}, by={req$user_id}")
    return(list(message = "User application rejected.", user_id = user_id_approval))
  }

  # Handle approval
  user_password <- random_password()
  user_initials <- generate_initials(
    user_table$first_name,
    user_table$family_name
  )

  # Hash password with Argon2id before storing
  hashed_password <- hash_password(user_password)

  # Update user approval status, password, and abbreviation
  user_update(user_id_approval, list(approved = 1, abbreviation = user_initials))
  user_update_password(user_id_approval, hashed_password)

  # Sanitize the stored user_name before logging: a legacy row predating the
  # signup control-char guard could otherwise forge log lines (#535 S8).
  log_info("User approved: user_id={user_id_approval}, user_name={sanitize_log_value(user_table$user_name)}, by={req$user_id}")

  # Generate and send email with error handling
  email_result <- tryCatch({
    email_html <- email_account_approved(
      user_name = user_table$user_name,
      temp_password = user_password,
      login_url = paste0(dw$base_url, "/Login")
    )

    # The approval email carries the temporary password; deliver it to the USER
    # ONLY. BCCing it to the shared curator mailbox would let any reader there
    # sign in as the newly approved user (#535 S8).
    send_noreply_email(
      email_body = email_html,
      email_subject = "Welcome to SysNDD - Your Account Has Been Approved!",
      email_recipient = user_table$email,
      html_content = TRUE
    )

    list(success = TRUE)
  }, error = function(e) {
    log_error("Email send failed for user_id={user_id_approval}: {e$message}")
    list(success = FALSE, error = e$message)
  })

  # Return response with email status
  if (email_result$success) {
    return(list(
      message = "User approved successfully.",
      user_id = user_id_approval,
      user_name = user_table$user_name,
      email_sent = TRUE
    ))
  } else {
    # User is approved but email failed - alert curator
    res$status <- 200
    return(list(
      message = "User approved but email delivery failed. Please contact user manually.",
      user_id = user_id_approval,
      user_name = user_table$user_name,
      email = user_table$email,
      email_sent = FALSE,
      email_error = email_result$error
    ))
  }
}

#' Apply a role assignment once permission tiering has been decided.
#'
#' Behind `PUT /api/user/change_role`, called after the shell's admin-target
#' shield check.
#'
#' @param req Plumber request (needs `req$user_role`).
#' @param res Plumber response (mutated on the 403 path).
#' @param user_id_role Integer target user id.
#' @param role_assigned Character role to assign.
#' @return List response body, or nothing (Plumber default) on success.
svc_user_change_role <- function(req, res, user_id_role, role_assigned) {
  if (req$user_role == "Administrator") {
    # Admin can assign any role
    user_update(user_id_role, list(user_role = role_assigned))
  } else if (role_assigned %in% c("Curator", "Reviewer", "Viewer")) {
    # Curator can assign non-Administrator roles
    user_update(user_id_role, list(user_role = role_assigned))
  } else {
    res$status <- 403
    return(list(error = "Insufficient rights. Curators cannot assign Administrator role."))
  }
}

#' Delete a user account by id.
#'
#' Behind `DELETE /api/user/delete` (Administrator-only; no admin-target
#' shield needed since only Administrators can reach this route).
#'
#' @param res Plumber response (mutated on every non-200 path).
#' @param user_id Target user id (character/integer, as received from Plumber).
#' @return List response body.
svc_user_delete <- function(res, user_id) {
  user_id <- as.integer(user_id)

  if (!is.numeric(user_id) || user_id <= 0) {
    res$status <- 400
    return(list(error = "Invalid user_id provided."))
  }

  # Check if user exists
  exist_result <- db_execute_query(
    "SELECT COUNT(*) as count FROM user WHERE user_id = ?",
    list(user_id)
  )

  if (exist_result$count == 0) {
    res$status <- 404
    return(list(error = "User not found."))
  }

  # Delete user
  delete_result <- tryCatch(
    {
      db_execute_statement(
        "DELETE FROM user WHERE user_id = ?",
        list(user_id)
      )
    },
    error = function(e) {
      NULL
    }
  )

  if (is.null(delete_result)) {
    res$status <- 500
    return(list(error = "Failed to delete user."))
  }

  list(message = "User successfully deleted.")
}

#' Update arbitrary user detail fields, including the approval side effects.
#'
#' Behind `PUT /api/user/update` (Administrator-only).
#'
#' @param req Plumber request (needs `req$argsBody$user_details`).
#' @param res Plumber response (mutated on every validation/error path).
#' @return List response body, or `res` on the two `jsonlite`-serialized
#'   validation-error paths (matching the pre-extraction handler).
svc_user_update_details <- function(req, res) {
  user_details <- req$argsBody$user_details

  if (is.null(user_details$user_id)) {
    res$status <- 400
    res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
      status = 400,
      message = "The user_id field is required."
    ))
    return(res)
  }

  if (!is.null(user_details$approved)) {
    approved <- user_details$approved
    if (approved %in% c(TRUE, "TRUE", "1", 1)) {
      user_details$approved <- 1
    } else if (approved %in% c(FALSE, "FALSE", "0", 0)) {
      user_details$approved <- 0
    } else {
      res$status <- 400
      res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
        status = 400,
        message = "Invalid value for approved field."
      ))
      return(res)
    }

    if (user_details$approved == 1) {
      if (is.null(user_details$abbreviation) || user_details$abbreviation == "") {
        res$status <- 400
        res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
          status = 400,
          message = "Abbreviation must be set for approval."
        ))
        return(res)
      }
    }
  }

  # Build updates list for user_update
  fields_to_update <- names(user_details)[names(user_details) != "user_id"]
  updates <- user_details[fields_to_update]

  result <- tryCatch(
    {
      user_update(user_details$user_id, updates)
      TRUE
    },
    error = function(e) {
      list(error = e$message)
    }
  )

  if (is.list(result) && !is.null(result$error)) {
    res$status <- 500
    return(list(error = paste("Failed to update user details:", result$error)))
  }

  if (!is.null(user_details$approved) && user_details$approved == 1) {
    user_table <- pool %>%
      tbl("user") %>%
      collect() %>%
      filter(user_id == user_details$user_id) %>%
      select(first_name, family_name, email, password)

    if (nrow(user_table) > 0) {
      if (is.null(user_table$password) || user_table$password == "") {
        user_password <- random_password()
        user_initials <- generate_initials(user_table$first_name, user_table$family_name)

        # Hash password with Argon2id before storing
        hashed_password <- hash_password(user_password)
        user_update_password(user_details$user_id, hashed_password)
        user_update(user_details$user_id, list(abbreviation = user_initials))

        # Generate professional HTML email using template
        email_html <- email_account_approved(
          user_name = paste(user_table$first_name, user_table$family_name),
          temp_password = user_password,
          login_url = paste0(dw$base_url, "/Login")
        )

        # Temporary-password email goes to the USER ONLY (never BCC the shared
        # curator mailbox with a credential — see #535 S8).
        send_noreply_email(
          email_body = email_html,
          email_subject = "Welcome to SysNDD - Your Account Has Been Approved!",
          email_recipient = user_table$email,
          html_content = TRUE
        )
      }
    }
  }

  list(message = "User details updated successfully.")
}
