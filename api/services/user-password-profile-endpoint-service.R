# api/services/user-password-profile-endpoint-service.R
#
# Endpoint service for the self-service password/profile routes in
# endpoints/user_endpoints.R: password change, profile update, and the
# password-reset request/change pair. Password/profile inputs stay
# JSON-body-only end to end (#OWASP): the `password/update` shell keeps its
# Content-Type/JSON-parse/scalar-shape validation inline (it is extracted and
# unit-tested directly out of the endpoint file by test-endpoint-auth.R) and
# only delegates the post-validation business logic here.

#' Apply a validated password change for self or (Administrator) another user.
#'
#' Behind `PUT /api/user/password/update`, called by the endpoint shell only
#' after Content-Type, JSON-parse, and scalar-shape validation has passed.
#'
#' @param req Plumber request (needs `req$user_id`, `req$user_role`).
#' @param res Plumber response (mutated on every path).
#' @param body Parsed JSON body with `user_id_pass_change`, `old_pass`,
#'   `new_pass_1`, `new_pass_2` (already scalar-validated by the shell).
#' @return List response body.
svc_user_password_update <- function(req, res, body) {
  user_id_pass_change <- body$user_id_pass_change
  old_pass <- body$old_pass
  new_pass_1 <- body$new_pass_1
  new_pass_2 <- body$new_pass_2

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
  new_pass_match_and_valid <- new_password_valid(new_pass_1, new_pass_2, old_pass)

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

#' Self-service update of the caller's own email and/or ORCID.
#'
#' Behind `PUT /api/user/profile`. Not gated by `require_role()` (any
#' authenticated user may edit their own profile); the shell only forwards.
#'
#' @param req Plumber request (needs `req$user_id`, `req$postBody`).
#' @param res Plumber response (mutated on every path).
#' @return List response body.
svc_user_profile_update <- function(req, res) {
  user_id <- req$user_id

  if (length(user_id) == 0 || is.null(user_id)) {
    res$status <- 401
    return(list(error = "Please authenticate."))
  }

  # Parse JSON body
  body <- tryCatch(
    jsonlite::fromJSON(req$postBody),
    error = function(e) list()
  )

  new_email <- body$email
  new_orcid <- body$orcid

  # Track what will be updated

  updates <- list()
  updated_fields <- c()


  # Validate and prepare email update
  if (!is.null(new_email) && nchar(trimws(new_email)) > 0) {
    new_email <- trimws(new_email)
    if (!is_valid_email(new_email)) {
      res$status <- 400
      return(list(error = "Invalid email format."))
    }

    # Check if email is already taken by another user
    existing_email <- pool %>%
      tbl("user") %>%
      filter(email == new_email, user_id != !!user_id) %>%
      collect()

    if (nrow(existing_email) > 0) {
      res$status <- 400
      return(list(error = "Email address is already in use by another account."))
    }

    updates$email <- new_email
    updated_fields <- c(updated_fields, "email")
  }

  # Validate and prepare ORCID update
  if (!is.null(new_orcid)) {
    new_orcid <- trimws(new_orcid)

    # Allow empty string to clear ORCID
    if (nchar(new_orcid) == 0) {
      updates$orcid <- ""
      updated_fields <- c(updated_fields, "orcid")
    } else {
      # ORCID format: 0000-0000-0000-000X (last char can be digit or X)
      # Using [0-9] instead of \d for R compatibility
      orcid_pattern <- "^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$"
      if (!grepl(orcid_pattern, new_orcid, ignore.case = TRUE)) {
        res$status <- 400
        return(list(
          error = "Invalid ORCID format. Expected: 0000-0000-0000-000X"
        ))
      }
      # Normalize: uppercase X
      updates$orcid <- toupper(new_orcid)
      updated_fields <- c(updated_fields, "orcid")
    }
  }

  # Check if there's anything to update
  if (length(updates) == 0) {
    res$status <- 400
    return(list(error = "No valid fields provided for update."))
  }

  # Perform update using existing repository function
  user_update(user_id, updates)

  res$status <- 200
  return(list(
    message = "Profile updated successfully.",
    updated_fields = updated_fields
  ))
}

#' Best-effort, anti-enumeration password-reset request.
#'
#' Behind `POST /api/user/password/reset/request`. Delegates the actual
#' anti-enumeration/SMTP-hardening logic to
#' `process_password_reset_request()` (functions/user-endpoint-helpers.R).
#'
#' @param req Plumber request (needs `req$postBody`).
#' @param res Plumber response (mutated with the shared response status).
#' @return List response body.
svc_user_password_reset_request <- function(req, res) {
  # Parse email from JSON body (OWASP: sensitive data should not be in URLs)
  body <- tryCatch(
    jsonlite::fromJSON(req$postBody),
    error = function(e) list()
  )
  email_request <- body$email %||% ""

  user_table <- pool %>%
    tbl("user") %>%
    collect()

  result <- process_password_reset_request(email_request, user_table, dw)
  res$status <- result$status
  result$body
}

#' Complete a password reset given a signed, unexpired reset JWT.
#'
#' Behind `POST /api/user/password/reset/change`. Validates the bearer JWT's
#' claims against the current DB row (rather than comparing JWT strings) so
#' `jti`/`nbf` fields never cause a false mismatch.
#'
#' @param req Plumber request (needs `req$postBody`, `req$HTTP_AUTHORIZATION`).
#' @param res Plumber response (mutated on every path).
#' @return List response body.
svc_user_password_reset_change <- function(req, res) {
  # Parse passwords from JSON body (OWASP: passwords MUST NOT be in URLs)
  body <- tryCatch(
    jsonlite::fromJSON(req$postBody),
    error = function(e) list()
  )
  new_pass_1 <- body$password %||% ""
  new_pass_2 <- body$password_confirm %||% ""
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
      mutate(reset_posix = as.POSIXct(password_reset_date, tz = "UTC")) %>%
      mutate(timestamp_iat = as.integer(reset_posix)) %>%
      select(user_id, user_name, hash, email, timestamp_iat)

    # Check user was found
    if (nrow(user_table) == 0) {
      res$status <- 404
      return(list(error = "User not found."))
    }

    # Validate JWT claims against database values (instead of comparing JWT strings)
    # This properly handles jti/nbf fields that are auto-generated
    # Use first() to extract scalar values from tibble columns
    # Allow 2-second tolerance on iat to handle datetime rounding when storing/retrieving
    iat_tolerance <- abs(user_jwt$iat - user_table$timestamp_iat[[1]]) <= 2

    jwt_claims_valid <- (user_jwt$user_id == user_table$user_id[[1]]) &&
      (user_jwt$user_name == user_table$user_name[[1]]) &&
      (user_jwt$email == user_table$email[[1]]) &&
      (user_jwt$hash == user_table$hash[[1]]) &&
      iat_tolerance

    new_pass_match_and_valid <- new_password_valid(new_pass_1, new_pass_2)

    if (jwt_claims_valid && new_pass_match_and_valid) {
      # Hash new password with Argon2id before storing
      hashed_new_password <- hash_password(new_pass_1)
      user_update_password(user_jwt$user_id, hashed_new_password)
      # Clear password_reset_date using direct SQL (NULL params don't work well with DBI)
      db_execute_statement(
        "UPDATE user SET password_reset_date = NULL WHERE user_id = ?",
        list(user_jwt$user_id)
      )

      res$status <- 201
      return(list(message = "Password successfully changed."))
    } else {
      res$status <- 409
      return(list(error = "Password or JWT input problem."))
    }
  }
}
