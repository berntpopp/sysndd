# api/endpoints/authentication_endpoints.R
#
# This file contains all authentication-related endpoints extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Make sure to source any required helpers or libraries at the top if needed,
# for example:
# source("functions/database-functions.R", local = TRUE)

# Load security utilities for password verification and progressive migration
source("core/security.R", local = TRUE)

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
    # Insert user into DB
    sysndd_db <- dbConnect(
      RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port
    )

    dbAppendTable(sysndd_db, "user", user)
    dbDisconnect(sysndd_db)

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
#* Loads secret from environment (dw$secret), verifies user, role, and other
#* details, and if successful, encodes a JWT with expiry time.
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
  check_user <- user_name
  check_pass <- password

  # Load secret
  key <- charToRaw(dw$secret)

  if (
    is.null(check_user) || nchar(check_user) < 5 || nchar(check_user) > 20 ||
      is.null(check_pass) || nchar(check_pass) < 5 || nchar(check_pass) > 50
  ) {
    res$status <- 404
    res$body <- "Please provide valid username and password."
    return(res)
  }

  # Fetch user by username only (don't filter by password in SQL)
  user_filtered <- pool %>%
    tbl("user") %>%
    filter(user_name == check_user & approved == 1) %>%
    collect()

  if (nrow(user_filtered) != 1) {
    res$status <- 401
    res$body <- "User or password wrong."
    return(res)
  }

  # Verify password using dual-hash support (Argon2id or plaintext)
  authenticated <- verify_password(user_filtered$password[1], check_pass)

  if (!authenticated) {
    res$status <- 401
    res$body <- "User or password wrong."
    return(res)
  }

  # Progressive password upgrade: migrate plaintext to Argon2id on successful login
  if (needs_upgrade(user_filtered$password[1])) {
    upgrade_password(pool, user_filtered$user_id[1], check_pass)
  }

  # Remove password and add JWT timestamps
  user_filtered <- user_filtered %>%
    select(-password) %>%
    mutate(
      iat = as.numeric(Sys.time()),
      exp = as.numeric(Sys.time()) + dw$refresh
    )

  # If match found, create JWT
  claim <- jwt_claim(
    user_id = user_filtered$user_id,
    user_name = user_filtered$user_name,
    email = user_filtered$email,
    user_role = user_filtered$user_role,
    user_created = user_filtered$created_at,
    abbreviation = user_filtered$abbreviation,
    orcid = user_filtered$orcid,
    iat = user_filtered$iat,
    exp = user_filtered$exp
  )

  jwt <- jwt_encode_hmac(claim, secret = key)
  jwt
}


#* Authenticate a User (token check)
#*
#* This endpoint verifies the Authorization header for a valid JWT. If valid and
#* not expired, returns the user data. Otherwise, returns an error.
#*
#* # `Details`
#* Loads JWT from header, decodes it, checks expiration.
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
  # Load secret
  key <- charToRaw(dw$secret)

  if (is.null(req$HTTP_AUTHORIZATION)) {
    res$status <- 401
    return(list(error = "Authorization http header missing."))
  }

  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

  user <- NULL
  tryCatch(
    {
      user <- jwt_decode_hmac(jwt, secret = key)
      user$token_expired <- (user$exp < as.numeric(Sys.time()))
    },
    error = function(e) {
      res$status <- 401
      return(list(error = "Authentication not successful."))
    }
  )

  if (is.null(jwt) || user$token_expired) {
    res$status <- 401
    return(list(error = "Authentication not successful."))
  } else {
    list(
      user_id = user$user_id,
      user_name = user$user_name,
      email = user$email,
      user_role = user$user_role,
      user_created = user$user_created,
      abbreviation = user$abbreviation,
      orcid = user$orcid,
      exp = user$exp
    )
  }
}


#* Refresh the Authentication Token
#*
#* If the user’s current token is valid and not expired, this endpoint returns a
#* new, refreshed token with updated expiry. Otherwise, returns an error.
#*
#* # `Details`
#* Similar to sign-in. Decodes the JWT, checks if it’s expired. If valid,
#* regenerates the token with a fresh expiration time.
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
  key <- charToRaw(dw$secret)

  if (is.null(req$HTTP_AUTHORIZATION)) {
    res$status <- 401
    return(list(error = "Authorization http header missing."))
  }

  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
  user <- NULL

  tryCatch(
    {
      user <- jwt_decode_hmac(jwt, secret = key)
      user$token_expired <- (user$exp < as.numeric(Sys.time()))
    },
    error = function(e) {
      res$status <- 401
      return(list(error = "Authentication not successful."))
    }
  )

  if (is.null(jwt) || user$token_expired) {
    res$status <- 401
    return(list(error = "Authentication not successful."))
  } else {
    claim <- jwt_claim(
      user_id = user$user_id,
      user_name = user$user_name,
      email = user$email,
      user_role = user$user_role,
      user_created = user$user_created,
      abbreviation = user$abbreviation,
      orcid = user$orcid,
      iat = as.numeric(Sys.time()),
      exp = as.numeric(Sys.time()) + dw$refresh
    )
    jwt <- jwt_encode_hmac(claim, secret = key)
    jwt
  }
}

## Authentication section
## -------------------------------------------------------------------##
