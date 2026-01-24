# api/endpoints/user_endpoints.R
#
# This file contains all user-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible.

# Load security utilities for password hashing and verification
source("../core/security.R", local = TRUE)

##-------------------------------------------------------------------##
## User endpoint section
##-------------------------------------------------------------------##

#* Retrieves a summary table of users based on role permissions.
#*
#* # `Details`
#* Admins see all users; Curators see only unapproved users; others are forbidden.
#*
#* @tag user
#* @serializer json list(na="null")
#* @get table
function(req, res) {
  user <- req$user_id

  if (length(user) == 0) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  } else if (req$user_role %in% c("Administrator")) {
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
      collect()

    user_table
  } else if (req$user_role %in% c("Curator")) {
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
      collect()

    user_table
  } else {
    res$status <- 403
    return(list(error = "Read access forbidden."))
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
  user_requested <- user_id
  user <- req$user_id

  if (length(user) == 0) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  } else if (req$user_role %in% c("Administrator", "Curator", "Reviewer")) {
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
  } else {
    res$status <- 403
    return(list(error = "Read access forbidden."))
  }
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
  user <- req$user_id
  user_id_approval <- as.integer(user_id)
  status_approval <- as.logical(status_approval)

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, approved, first_name, family_name, email) %>%
    filter(user_id == user_id_approval) %>%
    collect()
  user_id_approval_exists <- as.logical(length(user_table$user_id))
  user_id_approval_approved <- as.logical(user_table$approved[1])

  if (length(user) == 0) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  } else if (
    req$user_role %in% c("Administrator", "Curator") &&
    !user_id_approval_exists
  ) {
    res$status <- 409
    return(list(error = "User account does not exist."))
  } else if (
    req$user_role %in% c("Administrator", "Curator") &&
    user_id_approval_exists &&
    user_id_approval_approved
  ) {
    res$status <- 409
    return(list(error = "User account already active."))
  } else if (
    req$user_role %in% c("Administrator", "Curator") &&
    user_id_approval_exists &&
    !user_id_approval_approved
  ) {
    if (status_approval) {
      user_password <- random_password()
      user_initials <- generate_initials(
        user_table$first_name,
        user_table$family_name
      )

      sysndd_db <- dbConnect(
        RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
      )

      # Hash password with Argon2id before storing
      hashed_password <- hash_password(user_password)
      dbExecute(
        sysndd_db,
        "UPDATE user SET approved = 1, password = ?, abbreviation = ? WHERE user_id = ?",
        params = list(hashed_password, user_initials, user_id_approval)
      )

      dbDisconnect(sysndd_db)

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
      sysndd_db <- dbConnect(
        RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
      )

      dbExecute(
        sysndd_db,
        "DELETE FROM user WHERE user_id = ?",
        params = list(user_id_approval)
      )

      dbDisconnect(sysndd_db)
    }
  } else {
    res$status <- 403
    return(list(error = "Read access forbidden."))
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
  user <- req$user_id
  user_id_role <- as.integer(user_id)
  role_assigned <- as.character(role_assigned)

  if (length(user) == 0) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  } else if (req$user_role %in% c("Administrator")) {
    sysndd_db <- dbConnect(
      RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port
    )

    dbExecute(
      sysndd_db,
      "UPDATE user SET user_role = ? WHERE user_id = ?",
      params = list(role_assigned, user_id_role)
    )

    dbDisconnect(sysndd_db)

  } else if (
    req$user_role %in% c("Curator") &&
    role_assigned %in% c("Curator", "Reviewer", "Viewer")
  ) {
    sysndd_db <- dbConnect(
      RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port
    )

    dbExecute(
      sysndd_db,
      "UPDATE user SET user_role = ? WHERE user_id = ?",
      params = list(role_assigned, user_id_role)
    )

    dbDisconnect(sysndd_db)
  } else if (
    req$user_role %in% c("Curator") && 
    role_assigned %in% c("Administrator")
  ) {
    res$status <- 403
    return(list(error = "Insufficient rights."))
  } else {
    res$status <- 403
    return(list(error = "Write access forbidden."))
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
  user <- req$user_id

  if (length(user) == 0) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  } else if (req$user_role %in% c("Administrator")) {
    role_list <- tibble::as_tibble(user_status_allowed) %>%
      select(role = value)
    role_list
  } else if (req$user_role %in% c("Curator")) {
    role_list <- tibble::as_tibble(user_status_allowed) %>%
      select(role = value) %>%
      filter(role != "Administrator")
    role_list
  } else {
    res$status <- 403
    return(list(error = "Read access forbidden."))
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
  user <- req$user_id
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

  if (length(user) == 0) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  } else if (req$user_role %in% c("Administrator", "Curator")) {
    user_table_roles <- pool %>%
      tbl("user") %>%
      filter(approved == 1) %>%
      filter(user_role %in% roles_list) %>%
      select(user_id, user_name, user_role) %>%
      collect()
    user_table_roles
  } else {
    res$status <- 403
    return(list(error = "Read access forbidden."))
  }
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
    sysndd_db <- dbConnect(
      RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port
    )

    # Hash new password with Argon2id before storing
    hashed_new_password <- hash_password(new_pass_1)
    dbExecute(
      sysndd_db,
      "UPDATE user SET password = ? WHERE user_id = ?",
      params = list(hashed_new_password, user_id_pass_change)
    )

    dbDisconnect(sysndd_db)

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

    sysndd_db <- dbConnect(
      RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port
    )

    dbExecute(
      sysndd_db,
      "UPDATE user SET password_reset_date = ? WHERE user_id = ?",
      params = list(as.character(timestamp_request), user_id_from_email[1])
    )

    dbDisconnect(sysndd_db)

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
      sysndd_db <- dbConnect(
        RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
      )

      # Hash new password with Argon2id before storing
      hashed_new_password <- hash_password(new_pass_1)
      dbExecute(
        sysndd_db,
        "UPDATE user SET password = ? WHERE user_id = ?",
        params = list(hashed_new_password, user_jwt$user_id)
      )
      dbExecute(
        sysndd_db,
        "UPDATE user SET password_reset_date = NULL WHERE user_id = ?",
        params = list(user_jwt$user_id)
      )

      dbDisconnect(sysndd_db)

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
  user_id <- as.integer(user_id)

  if (req$user_role != "Administrator") {
    res$status <- 403
    return(list(error = "Administrative privileges required for this action."))
  }

  if (!is.numeric(user_id) || user_id <= 0) {
    res$status <- 400
    return(list(error = "Invalid user_id provided."))
  }

  sysndd_db <- dbConnect(
    RMariaDB::MariaDB(),
    dbname = dw$dbname,
    user = dw$user,
    password = dw$password,
    server = dw$server,
    host = dw$host,
    port = dw$port
  )

  exist_result <- dbGetQuery(
    sysndd_db,
    "SELECT COUNT(*) as count FROM user WHERE user_id = ?",
    params = list(user_id)
  )

  if (exist_result$count == 0) {
    dbDisconnect(sysndd_db)
    res$status <- 404
    return(list(error = "User not found."))
  }

  delete_result <- tryCatch({
    dbExecute(
      sysndd_db,
      "DELETE FROM user WHERE user_id = ?",
      params = list(user_id)
    )
  }, error = function(e) {
    NULL
  })

  dbDisconnect(sysndd_db)

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
  if (req$user_role != "Administrator") {
    res$status <- 403
    return(list(error = "Administrative privileges required for this action."))
  }

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

  sysndd_db <- dbConnect(
    RMariaDB::MariaDB(),
    dbname = dw$dbname,
    user = dw$user,
    password = dw$password,
    server = dw$server,
    host = dw$host,
    port = dw$port
  )

  # Build parameterized query to prevent SQL injection
  fields_to_update <- names(user_details)[names(user_details) != "user_id"]
  placeholders <- paste0(fields_to_update, " = ?", collapse = ", ")
  query <- paste0("UPDATE user SET ", placeholders, " WHERE user_id = ?")
  params <- c(as.list(user_details[fields_to_update]), list(user_details[["user_id"]]))

  result <- tryCatch({
    dbExecute(sysndd_db, query, params = params)
  }, error = function(e) {
    list(error = e$message)
  })

  dbDisconnect(sysndd_db)

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

        sysndd_db <- dbConnect(
          RMariaDB::MariaDB(),
          dbname = dw$dbname,
          user = dw$user,
          password = dw$password,
          server = dw$server,
          host = dw$host,
          port = dw$port
        )

        # Hash password with Argon2id before storing
        hashed_password <- hash_password(user_password)
        dbExecute(
          sysndd_db,
          "UPDATE user SET password = ?, abbreviation = ? WHERE user_id = ?",
          params = list(hashed_password, user_initials, user_details$user_id)
        )

        dbDisconnect(sysndd_db)

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
