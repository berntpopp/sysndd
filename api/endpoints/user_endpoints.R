# api/endpoints/user_endpoints.R
#
# This file contains all user-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible.

# Note: All required modules (security.R, middleware.R, user-repository.R)
# are sourced by start_sysndd_api.R before endpoints are loaded.
# Functions are available in the global environment.

## -------------------------------------------------------------------##
## User endpoint section
## -------------------------------------------------------------------##

#* Retrieves a summary table of users based on role permissions.
#*
#* # `Details`
#* Admins see all users; Curators see only unapproved users; others are forbidden.
#* Supports cursor pagination for large user lists.
#*
#* @tag user
#* @serializer json list(na="null")
#* @param page_after Cursor after which entries are shown (default: 0)
#* @param page_size Page size in cursor pagination (default: "all")
#* @get table
function(req, res, page_after = 0, page_size = "all") {
  # Require Curator role or higher
  require_role(req, res, "Curator")

  if (req$user_role == "Administrator") {
    user_table <- pool %>%
      tbl("user") %>%
      select(
        user_id,
        user_name,
        email,
        orcid,
        abbreviation,
        first_name,
        family_name,
        comment,
        terms_agreed,
        created_at,
        user_role,
        approved
      ) %>%
      arrange(created_at, user_id) %>%
      collect()

    # Apply pagination
    pagination_info <- generate_cursor_pag_inf_safe(
      user_table,
      page_size,
      page_after,
      "user_id"
    )

    list(
      links = pagination_info$links,
      meta = pagination_info$meta,
      data = pagination_info$data
    )
  } else {
    # Curator sees only unapproved users
    user_table <- pool %>%
      tbl("user") %>%
      select(
        user_id,
        user_name,
        email,
        orcid,
        abbreviation,
        first_name,
        family_name,
        comment,
        terms_agreed,
        created_at,
        user_role,
        approved
      ) %>%
      filter(approved == 0) %>%
      arrange(created_at, user_id) %>%
      collect()

    # Apply pagination
    pagination_info <- generate_cursor_pag_inf_safe(
      user_table,
      page_size,
      page_after,
      "user_id"
    )

    list(
      links = pagination_info$links,
      meta = pagination_info$meta,
      data = pagination_info$data
    )
  }
}


#* Retrieves count statistics of all contributions for a specified user.
#*
#* # `Details`
#* Admin/Curator/Reviewer can see. Returns active reviews and statuses user contributed.
#*
#* @tag user
#* @serializer json list(na="string")
#* @get <user_id>/contributions
function(req, res, user_id) {
  # Require Reviewer role or higher
  require_role(req, res, "Reviewer")

  user_requested <- user_id

  active_user_reviews <- pool %>%
    tbl("ndd_entity_review") %>%
    filter(is_primary == 1) %>%
    filter(review_user_id == user_requested) %>%
    select(review_id) %>%
    collect() %>%
    tally() %>%
    select(active_reviews = n)

  active_user_status <- pool %>%
    tbl("ndd_entity_status") %>%
    filter(is_active == 1) %>%
    filter(status_user_id == user_requested) %>%
    select(status_id) %>%
    collect() %>%
    tally() %>%
    select(active_status = n)

  list(
    user_id = user_requested,
    active_status = active_user_status$active_status,
    active_reviews = active_user_reviews$active_reviews
  )
}


#* Manages the approval status of a user application.
#*
#* # `Details`
#* Only Admin/Curator. If approved, sets user as approved=1, generates a password,
#* sends mail, etc. If unapproved, removes user from DB.
#*
#* @tag user
#* @serializer json list(na="string")
#* @put approval
function(req, res, user_id = 0, status_approval = FALSE) {
  # Require Curator role or higher
  require_role(req, res, "Curator")

  user_id_approval <- as.integer(user_id)
  status_approval <- as.logical(status_approval)

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, approved, first_name, family_name, email) %>%
    filter(user_id == user_id_approval) %>%
    collect()
  user_id_approval_exists <- as.logical(length(user_table$user_id))
  user_id_approval_approved <- as.logical(user_table$approved[1])

  if (!user_id_approval_exists) {
    res$status <- 409
    return(list(error = "User account does not exist."))
  } else if (user_id_approval_exists && user_id_approval_approved) {
    res$status <- 409
    return(list(error = "User account already active."))
  } else if (user_id_approval_exists && !user_id_approval_approved) {
    if (status_approval) {
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

      send_noreply_email(
        c(
          "Your registration for sysndd.org has been approved by a curator.",
          "Your password (please change after first login):",
          user_password
        ),
        "Account approved for SysNDD.org",
        user_table$email,
        "curator@sysndd.org"
      )
    } else {
      # Rejection - delete user using db_execute_statement
      db_execute_statement(
        "DELETE FROM user WHERE user_id = ?",
        list(user_id_approval)
      )
    }
  }
}


#* Allows administrators to change the roles of users.
#*
#* # `Details`
#* If admin, can set any role. If curator, can only set certain roles.
#*
#* @tag user
#* @put change_role
function(req, res, user_id, role_assigned = "Viewer") {
  # Require Curator role or higher
  require_role(req, res, "Curator")

  user_id_role <- as.integer(user_id)
  role_assigned <- as.character(role_assigned)

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


#* Retrieves a list of all available user roles.
#*
#* # `Details`
#* Admin can see all roles, Curator sees all except "Administrator".
#*
#* @tag user
#* @get role_list
function(req, res) {
  # Require Curator role or higher
  require_role(req, res, "Curator")

  if (req$user_role == "Administrator") {
    role_list <- tibble::as_tibble(user_status_allowed) %>%
      select(role = value)
    role_list
  } else {
    # Curator sees all except Administrator
    role_list <- tibble::as_tibble(user_status_allowed) %>%
      select(role = value) %>%
      filter(role != "Administrator")
    role_list
  }
}


#* Retrieves a list of users based on their roles.
#*
#* # `Details`
#* Admin/Curator can filter users by roles.
#*
#* @tag user
#* @get list
function(req, res, roles = "Viewer") {
  # Require Curator role or higher
  require_role(req, res, "Curator")

  roles_list <- str_trim(str_split(str_squish(roles), ",")[[1]])
  roles_allowed_check <- all(roles_list %in% user_status_allowed)

  if (!roles_allowed_check) {
    res$status <- 400
    res$body <- jsonlite::toJSON(
      auto_unbox = TRUE,
      list(
        status = 400,
        message = "Some submitted roles are not in the allowed roles list."
      )
    )
    return(res)
  }

  user_table_roles <- pool %>%
    tbl("user") %>%
    filter(approved == 1) %>%
    filter(user_role %in% roles_list) %>%
    select(user_id, user_name, user_role) %>%
    collect()
  user_table_roles
}


#* Allows a user or an administrator to change the user's password.
#*
#* # `Details`
#* Validates old password, checks new password complexity, updates DB.
#*
#* @tag user
#* @put password/update
function(
  req,
  res,
  user_id_pass_change = 0,
  old_pass = "",
  new_pass_1 = "",
  new_pass_2 = ""
) {
  user <- req$user_id
  user_id_pass_change <- as.integer(user_id_pass_change)

  # Get user info including password for verification
  user_table <- pool %>%
    tbl("user") %>%
    select(
      user_id,
      user_name,
      password,
      approved,
      first_name,
      family_name,
      email
    ) %>%
    filter(user_id == user_id_pass_change) %>%
    collect()

  user_id_pass_change_exists <- as.logical(length(user_table$user_id))
  user_id_pass_change_approved <- as.logical(user_table$approved[1])
  # Use verify_password to support both plaintext and hashed passwords
  old_pass_match <- verify_password(user_table$password[1], old_pass)
  new_pass_match_and_valid <- (new_pass_1 == new_pass_2) &&
    (new_pass_1 != old_pass) &&
    nchar(new_pass_1) > 7 &&
    grepl("[a-z]", new_pass_1) &&
    grepl("[A-Z]", new_pass_1) &&
    grepl("\\d", new_pass_1) &&
    grepl("[!@#$%^&*]", new_pass_1)

  if (length(user) == 0) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  } else if (
    (req$user_role %in% c("Administrator") || user == user_id_pass_change) &&
      !user_id_pass_change_exists &&
      (old_pass_match || req$user_role %in% c("Administrator")) &&
      new_pass_match_and_valid
  ) {
    res$status <- 409
    return(list(error = "User account does not exist."))
  } else if (
    (req$user_role %in% c("Administrator") || user == user_id_pass_change) &&
      user_id_pass_change_exists && !user_id_pass_change_approved &&
      (old_pass_match || req$user_role %in% c("Administrator")) &&
      new_pass_match_and_valid
  ) {
    res$status <- 409
    return(list(error = "User account not approved."))
  } else if (
    (req$user_role %in% c("Administrator") || user == user_id_pass_change) &&
      (!(old_pass_match || req$user_role %in% c("Administrator")) ||
         !new_pass_match_and_valid)
  ) {
    res$status <- 409
    return(list(error = "Password input problem."))
  } else if (
    (req$user_role %in% c("Administrator") || user == user_id_pass_change) &&
      user_id_pass_change_exists &&
      user_id_pass_change_approved &&
      (old_pass_match || req$user_role %in% c("Administrator")) &&
      new_pass_match_and_valid
  ) {
    # Hash new password with Argon2id before storing
    hashed_new_password <- hash_password(new_pass_1)
    user_update_password(user_id_pass_change, hashed_new_password)

    res$status <- 201
    return(list(message = "Password successfully changed."))
  } else {
    res$status <- 403
    return(list(error = "Read access forbidden."))
  }
}


#* Allows a user to request a password reset by email.
#*
#* # `Details`
#* If the email is valid and exists in the DB, generates a reset token
#* and sends email with reset URL.
#*
#* @tag user
#* @put password/reset/request
function(req, res, email_request = "") {
  user_table <- pool %>%
    tbl("user") %>%
    collect()

  if (!is_valid_email(email_request)) {
    res$status <- 400
    return(list(error = "Invalid Parameter Value Error."))
  } else if (!(email_request %in% user_table$email)) {
    res$status <- 200
    res <- "Request mail send!"
  } else if ((email_request %in% user_table$email)) {
    email_user <- str_to_lower(toString(email_request))
    user_table <- user_table %>%
      mutate(email_lower = str_to_lower(email)) %>%
      filter(email_lower == email_user) %>%
      mutate(hash = toString(md5(paste0(dw$salt, password)))) %>%
      select(user_id, user_name, hash, email)

    user_id_from_email <- user_table$user_id
    timestamp_request <- Sys.time()
    timestamp_iat <- as.integer(timestamp_request)
    timestamp_exp <- as.integer(timestamp_request) + dw$refresh
    key <- charToRaw(dw$secret)

    # Update password reset timestamp
    user_update(user_id_from_email[1], list(password_reset_date = as.character(timestamp_request)))

    claim <- jwt_claim(
      user_id = user_table$user_id,
      user_name = user_table$user_name,
      email = user_table$email,
      hash = user_table$hash,
      iat = timestamp_iat,
      exp = timestamp_exp
    )

    jwt <- jwt_encode_hmac(claim, secret = key)
    reset_url <- paste0(dw$base_url, "/PasswordReset/", jwt)

    res$status <- 200
    res <- send_noreply_email(
      c(
        "We received a password reset for your account",
        "at sysndd.org. Use this link to reset:",
        reset_url
      ),
      "Your password reset request for SysNDD.org",
      user_table$email
    )
  } else {
    res$status <- 401
    return(list(error = "Error or unauthorized."))
  }
}


#* Does password reset
#*
#* # `Details`
#* This endpoint is called with a Bearer token that includes a
#* password_reset_date-based JWT. If valid and not expired, updates the password.
#*
#* @tag user
#* @get password/reset/change
function(req, res, new_pass_1 = "", new_pass_2 = "") {
  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
  key <- charToRaw(dw$secret)

  user_jwt <- jwt_decode_hmac(jwt, secret = key)
  user_jwt$token_expired <- (user_jwt$exp < as.numeric(Sys.time()))

  if (is.null(jwt) || user_jwt$token_expired) {
    res$status <- 401
    return(list(error = "Reset token expired."))
  } else {
    user_table <- pool %>%
      tbl("user") %>%
      collect() %>%
      filter(user_id == user_jwt$user_id) %>%
      mutate(hash = toString(md5(paste0(dw$salt, password)))) %>%
      mutate(timestamp_iat = as.integer(password_reset_date)) %>%
      mutate(timestamp_exp = as.integer(password_reset_date) + dw$refresh) %>%
      select(user_id, user_name, hash, email, timestamp_iat, timestamp_exp)

    claim_check <- jwt_claim(
      user_id = user_table$user_id,
      user_name = user_table$user_name,
      email = user_table$email,
      hash = user_table$hash,
      iat = user_table$timestamp_iat,
      exp = user_table$timestamp_exp
    )

    jwt_check <- jwt_encode_hmac(claim_check, secret = key)
    jwt_match <- (jwt == jwt_check)

    new_pass_match_and_valid <- (new_pass_1 == new_pass_2) &&
      nchar(new_pass_1) > 7 &&
      grepl("[a-z]", new_pass_1) &&
      grepl("[A-Z]", new_pass_1) &&
      grepl("\\d", new_pass_1) &&
      grepl("[!@#$%^&*]", new_pass_1)

    if (jwt_match && new_pass_match_and_valid) {
      # Hash new password with Argon2id before storing
      hashed_new_password <- hash_password(new_pass_1)
      user_update_password(user_jwt$user_id, hashed_new_password)
      user_update(user_jwt$user_id, list(password_reset_date = NULL))

      res$status <- 201
      return(list(message = "Password successfully changed."))
    } else {
      res$status <- 409
      return(list(error = "Password or JWT input problem."))
    }
  }
}


#* Deletes a user from the system.
#*
#* # `Details`
#* Admin only. Checks if user exists, deletes them, logs operation.
#*
#* @tag user
#* @serializer json list(na="string")
#* @delete delete
function(req, res, user_id) {
  # Require Administrator role
  require_role(req, res, "Administrator")

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


#* Updates the details of an existing user and handles approval process.
#*
#* # `Details`
#* Admin can modify user attributes. If approved, checks for existing password
#* else generates one and sends email.
#*
#* @tag user
#* @serializer json list(na="string")
#* @accept json
#* @put update
function(req, res) {
  # Require Administrator role
  require_role(req, res, "Administrator")

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

        send_noreply_email(
          email_body = paste0(
            "Your registration for sysndd.org has been approved by a curator.\n",
            "Your password (please change after first login): ", user_password
          ),
          email_subject = "Account approved for SysNDD.org",
          email_recipient = user_table$email,
          email_blind_copy = "curator@sysndd.org"
        )
      }
    }
  }

  list(message = "User details updated successfully.")
}
