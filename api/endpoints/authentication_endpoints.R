# api/endpoints/authentication_endpoints.R
#
# This file contains all authentication-related endpoints extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Make sure to source any required helpers or libraries at the top if needed,
# for example:
# source("functions/database-functions.R", local = TRUE)

# Note: All required modules (security.R, db-helpers.R, auth-service.R)
# are sourced by start_sysndd_api.R before endpoints are loaded.
# Functions are available in the global environment.

## -------------------------------------------------------------------##
## Authentication section
## -------------------------------------------------------------------##

#* User Signup
#*
#* This endpoint handles user signups. It validates the user's provided info
#* (e.g., username, names, email, ORCID, terms agreement), and if valid, inserts
#* a new user record. Then it sends a confirmation email to notify them of the
#* pending request.
#*
#* # `Details`
#* Checks if user input passes basic validations like name length, email format,
#* etc. On success, the user is added to the database with `approved=0`, and a
#* mail is sent to them. If any validation fails, returns an error.
#*
#* # `Return`
#* Returns an error if data is invalid. Otherwise, sends a confirmation email
#* and a success message.
#*
#* @tag authentication
#* @serializer json list(na="string")
#*
#* @response 200 OK. The signup was successful; user added to DB, email sent.
#* @response 400 Bad Request. If the JSON body is missing, malformed, or empty.
#* @response 404 Not Found. Invalid registration data.
#* @response 415 Unsupported Media Type. If the request is not JSON.
#*
#* @post signup
function(req, res) {
  admission <- auth_endpoint_admission_guard(req, res)
  if (!admission$admitted) return(admission$response)

  content_type <- req$HTTP_CONTENT_TYPE %||% req$CONTENT_TYPE %||% ""
  media_type <- strsplit(tolower(content_type), ";", fixed = TRUE)[[1]][1]
  if (media_type != "application/json") {
    res$status <- 415
    res$body <- "Content-Type must be application/json."
    return(res)
  }

  signup_body <- tryCatch(
    jsonlite::fromJSON(req$postBody),
    error = function(e) NULL
  )
  required_fields <- c(
    "user_name",
    "first_name",
    "family_name",
    "email",
    "orcid",
    "comment",
    "terms_agreed"
  )
  if (
    is.null(signup_body) ||
      length(signup_body) == 0 ||
      !all(required_fields %in% names(signup_body))
  ) {
    res$status <- 400
    res$body <- "Malformed or empty JSON body."
    return(res)
  }

  required_fields_are_scalar_strings <- vapply(
    required_fields,
    function(field) {
      value <- signup_body[[field]]
      is.character(value) && length(value) == 1 && !is.na(value)
    },
    logical(1)
  )
  if (!all(required_fields_are_scalar_strings)) {
    res$status <- 400
    res$body <- "Malformed JSON body: each required field must be a single string value."
    return(res)
  }

  # Reject control characters (CR/LF/tab) in any account field. Left unchecked,
  # a CR/LF-bearing field is forged into log lines (the best-effort SMTP-failure
  # logger below prints user_name verbatim) and into email headers once the value
  # is emailed to the user/curators. Printable non-ASCII (accents) is allowed.
  fields_have_control_chars <- vapply(
    required_fields,
    function(field) account_field_has_control_char(signup_body[[field]]),
    logical(1)
  )
  if (any(fields_have_control_chars)) {
    res$status <- 400
    res$body <- "Malformed JSON body: fields must not contain control characters."
    return(res)
  }

  # Gate the email through the hardened, anchored validator (not the permissive
  # `.+@.+\\..+` shape used below): SMTP recipient grammar such as
  # `<a@example.com> NOTIFY=SUCCESS` must not create an account whose approval
  # credentials are then handed to smtp_send() as a malformed/injectable address.
  if (!is_valid_email(signup_body[["email"]])) {
    res$status <- 400
    res$body <- "Malformed JSON body: invalid email address."
    return(res)
  }

  user <- tibble::as_tibble(signup_body) %>%
    dplyr::mutate(
      terms_agreed = dplyr::case_when(
        terms_agreed == "accepted" ~ "1",
        TRUE ~ "0"
      )
    ) %>%
    dplyr::select(
      user_name,
      first_name,
      family_name,
      email,
      orcid,
      comment,
      terms_agreed
    )

  input_validation <- tidyr::pivot_longer(user, cols = dplyr::everything()) %>%
    dplyr::mutate(
      valid = dplyr::case_when(
        name == "user_name" ~ (nchar(value) >= 5 & nchar(value) <= 20),
        name == "first_name" ~ (nchar(value) >= 2 & nchar(value) <= 50),
        name == "family_name" ~ (nchar(value) >= 2 & nchar(value) <= 50),
        name == "email" ~ stringr::str_detect(
          value,
          stringr::regex(".+@.+\\..+", dotall = TRUE)
        ),
        name == "orcid" ~ stringr::str_detect(
          value,
          stringr::regex("^(([0-9]{4})-){3}[0-9]{3}[0-9X]$")
        ),
        name == "comment" ~ (nchar(value) >= 10 & nchar(value) <= 250),
        name == "terms_agreed" ~ (value == "1")
      )
    ) %>%
    dplyr::mutate(all = "1") %>%
    dplyr::select(all, valid) %>%
    dplyr::group_by(all) %>%
    dplyr::summarize(valid = as.logical(prod(valid)), .groups = "drop") %>%
    dplyr::select(valid)

  if (input_validation$valid) {
    # Insert user into DB using parameterized query
    # Build INSERT with explicit column names matching tibble structure
    cols <- names(user)
    placeholders <- paste(rep("?", length(cols)), collapse = ", ")
    sql <- sprintf("INSERT INTO user (%s) VALUES (%s)", paste(cols, collapse = ", "), placeholders)
    db_execute_statement(sql, unname(as.list(user)))

    # Generate professional HTML email using template
    email_html <- email_registration_request(
      user_info = list(
        user_name = user$user_name,
        email = user$email,
        first_name = user$first_name,
        family_name = user$family_name
      )
    )

    # The registration request is recorded once the user row is inserted above.
    # The notification email is best-effort: a transient SMTP failure must not
    # fail (or half-complete) the registration — the account already exists and
    # is visible to admins for approval. Log loudly and continue with a 200.
    tryCatch(
      send_noreply_email(
        email_body = email_html,
        email_subject = "SysNDD Registration Request Received",
        email_recipient = user$email,
        email_blind_copy = "curator@sysndd.org",
        html_content = TRUE
      ),
      error = function(e) {
        message(sprintf(
          "[signup] registration recorded for '%s' but notification email failed (non-fatal): %s",
          user$user_name, conditionMessage(e)
        ))
      }
    )
  } else {
    res$status <- 404
    res$body <- "Please provide valid registration data."
    return(res)
  }
}


#* Authenticate a User with Login
#*
#* Credentials are submitted as a JSON body (POST) instead of query parameters
#* so they never land in access logs, Traefik logs, or browser history.
#*
#* # `Details`
#* Parses `user_name` and `password` from the JSON request body and delegates
#* to `auth_signin`. Returns the JWT access token as a JSON string so the
#* wire format is identical to the legacy `@get` handler — clients only need
#* to switch HTTP method and payload location, not response parsing.
#*
#* # `Return`
#* JWT string on success, error message otherwise.
#*
#* @tag authentication
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns the JWT.
#* @response 400 Bad Request. If JSON body is missing or malformed.
#* @response 401 Unauthorized. If user or password is wrong or user not approved.
#*
#* @post authenticate
function(req, res) {
  admission <- auth_endpoint_admission_guard(req, res)
  if (!admission$admitted) return(admission$response)

  content_type <- req$HTTP_CONTENT_TYPE %||% req$CONTENT_TYPE %||% ""
  media_type <- strsplit(tolower(content_type), ";", fixed = TRUE)[[1]][1]
  if (media_type != "application/json") {
    res$status <- 415L
    return(list(error = "Content-Type must be application/json."))
  }

  # Parse credentials from JSON body (OWASP: secrets MUST NOT be in URLs)
  body <- tryCatch(
    jsonlite::fromJSON(req$postBody, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (!is.list(body) || is.null(names(body))) {
    res$status <- 400L
    return(list(error = "Request body must be a JSON object."))
  }
  user_name <- body$user_name %||% ""
  password <- body$password %||% ""

  # Validate inputs before calling service
  if (
    !is.character(user_name) || length(user_name) != 1L || is.na(user_name) ||
      !is.character(password) || length(password) != 1L || is.na(password) ||
      nchar(user_name) < 5 || nchar(user_name) > 20 ||
      nchar(password) < 5 || nchar(password) > 50
  ) {
    res$status <- 400
    res$body <- "Please provide valid username and password."
    return(res)
  }

  # Call auth service (returns structured response)
  tryCatch(
    {
      result <- auth_signin(user_name, password, pool, dw)
      # Return just the access token for backward compatibility with @get shape
      result$access_token
    },
    error = function(e) {
      res$status <- 401
      res$body <- "User or password wrong."
      return(res)
    }
  )
}


#* Authenticate a User (token check)
#*
#* This endpoint verifies the Authorization header for a valid JWT. If valid and
#* not expired, returns the user data. Otherwise, returns an error.
#*
#* # `Details`
#* Uses auth_verify service function to validate JWT token.
#*
#* # `Return`
#* User info if token is valid; 401 otherwise.
#*
#* @tag authentication
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns user_id, user_name, email, etc.
#* @response 401 Unauthorized. If token is missing or invalid/expired.
#*
#* @get signin
function(req, res) {
  if (is.null(req$HTTP_AUTHORIZATION)) {
    res$status <- 401
    return(list(error = "Authorization http header missing."))
  }

  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

  tryCatch(
    {
      # Call auth_verify service function
      auth_verify(jwt, dw)
    },
    error = function(e) {
      res$status <- 401
      return(list(error = "Authentication not successful."))
    }
  )
}


#* Refresh the Authentication Token
#*
#* If the user's current token is valid and not expired, this endpoint returns a
#* new, refreshed token with updated expiry. Otherwise, returns an error.
#*
#* # `Details`
#* Uses auth_refresh service function to generate new token.
#*
#* # `Return`
#* Refreshed JWT or error message.
#*
#* @tag authentication
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns the refreshed JWT.
#* @response 401 Unauthorized. If token invalid or missing.
#*
#* @get refresh
function(req, res) {
  if (is.null(req$HTTP_AUTHORIZATION)) {
    res$status <- 401
    return(list(error = "Authorization http header missing."))
  }

  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

  tryCatch(
    {
      # Call auth_refresh service function (returns new JWT string)
      auth_refresh(jwt, pool, dw)
    },
    error = function(e) {
      res$status <- 401
      return(list(error = "Authentication not successful."))
    }
  )
}

## Authentication section
## -------------------------------------------------------------------##
