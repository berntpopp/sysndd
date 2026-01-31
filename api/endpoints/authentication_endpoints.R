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
#* @param signup_data: JSON with the fields: user_name, first_name, family_name,
#*                     email, orcid, comment, terms_agreed.
#*
#* @response 200 OK. The signup was successful; user added to DB, email sent.
#* @response 404 Not Found. Invalid registration data.
#*
#* @get signup
function(signup_data) {
  user <- tibble::as_tibble(fromJSON(signup_data)) %>%
    mutate(
      terms_agreed = case_when(
        terms_agreed == "accepted" ~ "1",
        TRUE ~ "0"
      )
    ) %>%
    select(
      user_name,
      first_name,
      family_name,
      email,
      orcid,
      comment,
      terms_agreed
    )

  input_validation <- pivot_longer(user, cols = everything()) %>%
    mutate(
      valid = case_when(
        name == "user_name" ~ (nchar(value) >= 5 & nchar(value) <= 20),
        name == "first_name" ~ (nchar(value) >= 2 & nchar(value) <= 50),
        name == "family_name" ~ (nchar(value) >= 2 & nchar(value) <= 50),
        name == "email" ~ str_detect(value, regex(".+@.+\\..+", dotall = TRUE)),
        name == "orcid" ~ str_detect(value, regex("^(([0-9]{4})-){3}[0-9]{3}[0-9X]$")),
        name == "comment" ~ (nchar(value) >= 10 & nchar(value) <= 250),
        name == "terms_agreed" ~ (value == "1")
      )
    ) %>%
    mutate(all = "1") %>%
    select(all, valid) %>%
    group_by(all) %>%
    summarize(valid = as.logical(prod(valid))) %>%
    ungroup() %>%
    select(valid)

  if (input_validation$valid) {
    # Insert user into DB using parameterized query
    # Build INSERT with explicit column names matching tibble structure
    cols <- names(user)
    placeholders <- paste(rep("?", length(cols)), collapse = ", ")
    sql <- sprintf("INSERT INTO user (%s) VALUES (%s)", paste(cols, collapse = ", "), placeholders)
    db_execute_statement(sql, unname(as.list(user)))

    # Send email
    send_noreply_email(
      c(
        "Your registration request for sysndd.org has been sent to the curators",
        "who will review it soon. Information provided:",
        user
      ),
      "Your registration request to SysNDD.org",
      user$email,
      "curator@sysndd.org"
    )
  } else {
    res$status <- 404
    res$body <- "Please provide valid registration data."
    res
  }
}


#* Authenticate a User with Login
#*
#* Checks username & password against the DB for an approved user. If correct,
#* returns a JWT. Otherwise, returns an error.
#*
#* # `Details`
#* Uses auth_signin service function for authentication logic.
#* Returns JWT string for backward compatibility with existing clients.
#*
#* # `Return`
#* JWT on success, error message otherwise.
#*
#* @tag authentication
#* @serializer json list(na="string")
#*
#* @param user_name username provided by the user
#* @param password password provided by the user
#*
#* @response 200 OK. Returns the JWT.
#* @response 401 Unauthorized. If user or password is wrong or user not approved.
#*
#* @get authenticate
function(req, res, user_name, password) {
  # Validate inputs before calling service
  if (
    is.null(user_name) || nchar(user_name) < 5 || nchar(user_name) > 20 ||
      is.null(password) || nchar(password) < 5 || nchar(password) > 50
  ) {
    res$status <- 404
    res$body <- "Please provide valid username and password."
    return(res)
  }

  # Call auth service (returns structured response)
  tryCatch(
    {
      result <- auth_signin(user_name, password, pool, dw)
      # Return just the access token for backward compatibility
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
