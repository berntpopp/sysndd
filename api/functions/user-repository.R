# functions/user-repository.R
#
# User domain repository - handles database operations for user management and authentication.
# Uses db-helpers for parameterized queries and automatic connection cleanup.
#
# Key features:
# - All queries use parameterized SQL via db_execute_query/db_execute_statement
# - Password operations isolated with clear security warnings
# - user_find_for_auth includes password hash (auth only, never logged)
# - All public user queries use users_view (excludes password)

library(tibble)
library(logger)

#' Find user by ID
#'
#' Retrieves user information by user_id. Uses users_view to avoid
#' exposing password hash.
#'
#' @param user_id Integer user ID
#' @return Tibble with user_id, user_name, user_email, user_role.
#'   Returns empty tibble if user not found.
#'
#' @examples
#' \dontrun{
#' user <- user_find_by_id(5)
#' }
#'
#' @export
user_find_by_id <- function(user_id) {
  sql <- "SELECT user_id, user_name, user_email, user_role FROM users_view WHERE user_id = ?"
  db_execute_query(sql, list(user_id))
}

#' Find user by email
#'
#' Retrieves user information by email address. Uses users_view to avoid
#' exposing password hash.
#'
#' @param email Character email address
#' @return Tibble with user_id, user_name, user_email, user_role.
#'   Returns empty tibble if user not found.
#'
#' @examples
#' \dontrun{
#' user <- user_find_by_email("curator@sysndd.org")
#' }
#'
#' @export
user_find_by_email <- function(email) {
  sql <- "SELECT user_id, user_name, user_email, user_role FROM users_view WHERE user_email = ?"
  db_execute_query(sql, list(email))
}

#' Find multiple users by IDs
#'
#' Retrieves multiple users in a single query using IN clause.
#' Uses users_view to avoid exposing password hash.
#'
#' @param user_ids Integer vector of user IDs
#' @return Tibble with user_id, user_name, user_email, user_role.
#'   Returns empty tibble if no users found or empty input.
#'
#' @examples
#' \dontrun{
#' users <- user_find_by_ids(c(5, 10, 15))
#' }
#'
#' @export
user_find_by_ids <- function(user_ids) {
  # Handle empty input
  if (length(user_ids) == 0) {
    return(tibble::tibble(
      user_id = integer(),
      user_name = character(),
      user_email = character(),
      user_role = character()
    ))
  }

  # Generate placeholders for IN clause
  placeholders <- paste(rep("?", length(user_ids)), collapse = ", ")
  sql <- paste0("SELECT user_id, user_name, user_email, user_role FROM users_view WHERE user_id IN (", placeholders, ")")

  # Convert user_ids to list for parameterized query
  db_execute_query(sql, as.list(user_ids))
}

#' Find user with password hash for authentication
#'
#' SECURITY WARNING: This function returns the password hash.
#' Only use for authentication purposes. Never log the result.
#'
#' Queries the users table directly (not users_view) to access password_hash.
#' Column name is user_password_hash to match existing schema.
#'
#' @param email Character email address
#' @return Tibble with user_id, user_name, user_email, user_role, user_password_hash.
#'   Returns empty tibble if user not found.
#'
#' @examples
#' \dontrun{
#' # AUTHENTICATION ONLY - Never log this result
#' user_auth <- user_find_for_auth("curator@sysndd.org")
#' is_valid <- verify_password(user_auth$user_password_hash[1], password_attempt)
#' }
#'
#' @export
user_find_for_auth <- function(email) {
  sql <- "SELECT user_id, user_name, user_email, user_role, password as user_password_hash FROM user WHERE user_email = ?"

  # Execute query - result will NOT be logged by db_execute_query (parameters only)
  # The password hash is in the result set but never appears in logs
  db_execute_query(sql, list(email))
}

#' Create new user
#'
#' Inserts a new user into the database. Password must be hashed
#' before calling this function (use hash_password from core/security.R).
#'
#' @param user_data Named list with required fields:
#'   - user_name: Character user name
#'   - user_email: Character email address
#'   - user_password_hash: Character hashed password (never plaintext)
#'   - user_role: Character role (Administrator, Curator, Reviewer, Viewer)
#'
#' @return Integer user_id of the newly created user
#'
#' @examples
#' \dontrun{
#' user_id <- user_create(list(
#'   user_name = "Test User",
#'   user_email = "test@sysndd.org",
#'   user_password_hash = hash_password("secure_password"),
#'   user_role = "Viewer"
#' ))
#' }
#'
#' @export
user_create <- function(user_data) {
  # Validate required fields
  required <- c("user_name", "user_email", "user_password_hash", "user_role")
  missing <- setdiff(required, names(user_data))
  if (length(missing) > 0) {
    rlang::abort(
      message = paste("Missing required fields:", paste(missing, collapse = ", ")),
      class = "user_validation_error",
      missing_fields = missing
    )
  }

  # Map user_password_hash to password column name in database
  sql <- "INSERT INTO user (user_name, user_email, password, user_role) VALUES (?, ?, ?, ?)"

  db_execute_statement(sql, list(
    user_data$user_name,
    user_data$user_email,
    user_data$user_password_hash,
    user_data$user_role
  ))

  # Get the newly created user_id
  result <- db_execute_query("SELECT LAST_INSERT_ID() as id")
  result$id[1]
}

#' Update user (non-password fields)
#'
#' Updates user fields dynamically based on provided updates.
#' Password updates are NOT allowed here - use user_update_password instead.
#'
#' @param user_id Integer user ID
#' @param updates Named list of fields to update (e.g., list(user_name = "New Name", user_role = "Curator"))
#'   Valid fields: user_name, user_email, user_role, approved, abbreviation
#'   NOTE: user_password_hash is ignored if present (use user_update_password)
#'
#' @return Integer count of affected rows (1 if updated, 0 if user not found)
#'
#' @examples
#' \dontrun{
#' # Update role
#' rows <- user_update(5, list(user_role = "Curator"))
#'
#' # Update multiple fields
#' rows <- user_update(5, list(user_name = "New Name", approved = 1))
#' }
#'
#' @export
user_update <- function(user_id, updates) {
  # Remove password fields if present (force use of user_update_password)
  updates$user_password_hash <- NULL
  updates$password <- NULL

  # Handle empty updates
  if (length(updates) == 0) {
    log_warn("user_update called with no valid fields to update for user_id: {user_id}")
    return(0L)
  }

  # Build SET clause dynamically
  field_names <- names(updates)
  set_clause <- paste(paste0(field_names, " = ?"), collapse = ", ")

  sql <- paste0("UPDATE user SET ", set_clause, " WHERE user_id = ?")

  # Parameters: field values + user_id
  params <- c(unname(updates), user_id)

  db_execute_statement(sql, as.list(params))
}

#' Update user password
#'
#' SECURITY WARNING: Never log the password_hash parameter.
#'
#' Dedicated function for password updates. Password must be hashed
#' before calling this function (use hash_password from core/security.R).
#'
#' @param user_id Integer user ID
#' @param password_hash Character hashed password (never plaintext)
#'
#' @return Integer count of affected rows (1 if updated, 0 if user not found)
#'
#' @examples
#' \dontrun{
#' # Hash password first, then update
#' new_hash <- hash_password("new_secure_password")
#' rows <- user_update_password(5, new_hash)
#' }
#'
#' @export
user_update_password <- function(user_id, password_hash) {
  # Parameter sanitization in db_execute_statement will redact the hash (>50 chars)
  sql <- "UPDATE user SET password = ? WHERE user_id = ?"

  db_execute_statement(sql, list(password_hash, user_id))
}

#' Check if user email exists
#'
#' Efficient existence check without retrieving full user data.
#'
#' @param email Character email address
#' @return Logical TRUE if email exists, FALSE otherwise
#'
#' @examples
#' \dontrun{
#' if (user_exists("test@sysndd.org")) {
#'   # Email already registered
#' }
#' }
#'
#' @export
user_exists <- function(email) {
  sql <- "SELECT 1 FROM user WHERE user_email = ? LIMIT 1"
  result <- db_execute_query(sql, list(email))
  nrow(result) > 0
}

#' Deactivate user (soft delete)
#'
#' Sets is_active = 0 for the user. This is a soft delete that preserves
#' user data but prevents login and access.
#'
#' @param user_id Integer user ID
#' @return Integer count of affected rows (1 if deactivated, 0 if user not found)
#'
#' @examples
#' \dontrun{
#' rows <- user_deactivate(5)
#' }
#'
#' @export
user_deactivate <- function(user_id) {
  sql <- "UPDATE user SET is_active = 0 WHERE user_id = ?"
  db_execute_statement(sql, list(user_id))
}
