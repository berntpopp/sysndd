# User Service Layer for SysNDD API
# Provides business logic for user management operations
#
# Functions accept pool as parameter (dependency injection)
# Handles role-based filtering, user approval workflow, and role updates

#' Get user list filtered by requesting user's role
#'
#' Returns user information based on the requesting user's permissions:
#' - Administrators see all active users with full details
#' - Curators see reviewers and viewers
#' - Reviewers and Viewers see limited user information
#'
#' @param requesting_role Role of user making request (Administrator, Curator, Reviewer, Viewer)
#' @param pool Database connection pool
#' @return Tibble of users (filtered by role visibility)
#'
#' @examples
#' \dontrun{
#' users <- user_get_list("Administrator", pool)
#' users <- user_get_list("Curator", pool)
#' }
#'
#' @export
user_get_list <- function(requesting_role, pool) {
  base_query <- pool %>%
    tbl("user") %>%
    filter(account_status == "active")

  if (requesting_role == "Administrator") {
    # Admins see all users with full details
    base_query %>%
      select(
        user_id, user_name, email, user_role, orcid, abbreviation,
        first_name, family_name, created_at
      ) %>%
      collect()
  } else if (requesting_role == "Curator") {
    # Curators see reviewers and viewers
    base_query %>%
      filter(user_role %in% c("Reviewer", "Viewer")) %>%
      select(user_id, user_name, email, user_role) %>%
      collect()
  } else {
    # Reviewers and Viewers see limited info
    base_query %>%
      select(user_id, user_name) %>%
      collect()
  }
}


#' Get single user by ID
#'
#' Retrieves detailed information for a specific user.
#' Does not include password hash (uses safe query).
#'
#' @param user_id Integer user ID
#' @param pool Database connection pool
#' @return Tibble with user record (0 rows if not found)
#'
#' @examples
#' \dontrun{
#' user <- user_get_by_id(5, pool)
#' }
#'
#' @export
user_get_by_id <- function(user_id, pool) {
  pool %>%
    tbl("user") %>%
    filter(user_id == !!user_id) %>%
    select(
      user_id, user_name, email, user_role, orcid, abbreviation,
      first_name, family_name, account_status, created_at
    ) %>%
    collect()
}


#' Approve or reject user registration
#'
#' Sets account_status to "active" or "rejected" and records approving user.
#' For approvals, also generates password and sends email notification.
#'
#' @param user_id Integer user ID to approve/reject
#' @param approving_user_id Integer user ID performing the action
#' @param approve Logical - TRUE to approve, FALSE to reject
#' @param pool Database connection pool
#' @return List with status and message
#'
#' @details
#' - Approval: Sets account_status to "active", records approving_user_id
#' - Rejection: Sets account_status to "rejected", records approving_user_id
#' - Generates random password for approved users if none exists
#' - Sends email notification with credentials
#'
#' @examples
#' \dontrun{
#' result <- user_approve(42, 1, TRUE, pool)
#' result <- user_approve(43, 1, FALSE, pool)
#' }
#'
#' @export
user_approve <- function(user_id, approving_user_id, approve, pool) {
  # Get user details
  user <- pool %>%
    tbl("user") %>%
    filter(user_id == !!user_id) %>%
    select(
      user_id, user_name, email, first_name, family_name,
      account_status, password
    ) %>%
    collect()

  if (nrow(user) == 0) {
    stop("User not found")
  }

  if (user$account_status == "active") {
    stop("User account already active")
  }

  # Set status based on approval decision
  new_status <- if (approve) "active" else "rejected"

  # Update user account status
  db_execute_statement(
    "UPDATE user SET account_status = ?, approving_user_id = ? WHERE user_id = ?",
    list(new_status, approving_user_id, user_id)
  )

  if (approve) {
    # Generate password if user doesn't have one
    if (is.null(user$password) || user$password == "") {
      user_password <- random_password()
      user_initials <- generate_initials(user$first_name, user$family_name)

      # Hash password with Argon2id before storing
      hashed_password <- hash_password(user_password)
      user_update_password(user_id, hashed_password)

      # Update abbreviation
      db_execute_statement(
        "UPDATE user SET abbreviation = ? WHERE user_id = ?",
        list(user_initials, user_id)
      )

      # Send approval email with password
      send_noreply_email(
        c(
          "Your registration for sysndd.org has been approved by a curator.",
          "Your password (please change after first login):",
          user_password
        ),
        "Account approved for SysNDD.org",
        user$email,
        "curator@sysndd.org"
      )
    }

    logger::log_info("User approved", user_id = user_id, approving_user_id = approving_user_id)
    list(status = 200, message = "User approved successfully")
  } else {
    logger::log_info("User rejected", user_id = user_id, approving_user_id = approving_user_id)
    list(status = 200, message = "User rejected")
  }
}


#' Update user role with permission checks
#'
#' Changes user's role with validation based on requesting user's permissions:
#' - Administrator can set any role
#' - Curator can set Curator, Reviewer, or Viewer roles
#'
#' @param user_id Integer user ID to update
#' @param new_role Character new role name
#' @param requesting_role Character role of user making the request
#' @param pool Database connection pool
#' @return List with status and message
#'
#' @details
#' Permission matrix:
#' - Administrator → can assign any role
#' - Curator → can assign Curator, Reviewer, Viewer (not Administrator)
#' - Others → no permission
#'
#' @examples
#' \dontrun{
#' result <- user_update_role(42, "Reviewer", "Administrator", pool)
#' result <- user_update_role(43, "Curator", "Curator", pool)
#' }
#'
#' @export
user_update_role <- function(user_id, new_role, requesting_role, pool) {
  allowed_roles <- c("Administrator", "Curator", "Reviewer", "Viewer")

  # Validate new role
  if (!new_role %in% allowed_roles) {
    stop("Invalid role specified")
  }

  # Check permissions
  if (requesting_role == "Administrator") {
    # Admin can assign any role
    db_execute_statement(
      "UPDATE user SET user_role = ? WHERE user_id = ?",
      list(new_role, user_id)
    )

    logger::log_info("User role updated", user_id = user_id, new_role = new_role)
    list(status = 200, message = "Role updated successfully")
  } else if (requesting_role == "Curator" && new_role != "Administrator") {
    # Curator can assign Curator, Reviewer, or Viewer
    db_execute_statement(
      "UPDATE user SET user_role = ? WHERE user_id = ?",
      list(new_role, user_id)
    )

    logger::log_info("User role updated", user_id = user_id, new_role = new_role)
    list(status = 200, message = "Role updated successfully")
  } else if (requesting_role == "Curator" && new_role == "Administrator") {
    stop("Insufficient permissions to assign Administrator role")
  } else {
    stop("Insufficient permissions to change user roles")
  }
}


#' Change user password with validation
#'
#' Updates user password with security checks:
#' - Administrators can change any password without old password
#' - Users can change their own password with old password verification
#'
#' @param user_id Integer user ID
#' @param old_password Character current password (required for non-admins)
#' @param new_password Character new password
#' @param requesting_role Character role of user making request
#' @param requesting_user_id Integer ID of user making request
#' @param pool Database connection pool
#' @return List with status and message
#'
#' @details
#' Password requirements (validated before calling):
#' - Minimum 8 characters
#' - Contains lowercase letter
#' - Contains uppercase letter
#' - Contains digit
#' - Contains special character
#'
#' Permission rules:
#' - Admin: can change any password without old_password
#' - User: can change own password with correct old_password
#'
#' @examples
#' \dontrun{
#' # Admin changing password
#' result <- user_change_password(42, "", "NewPass123!", "Administrator", 1, pool)
#'
#' # User changing own password
#' result <- user_change_password(42, "OldPass123!", "NewPass123!", "Reviewer", 42, pool)
#' }
#'
#' @export
user_change_password <- function(user_id, old_password, new_password,
                                 requesting_role, requesting_user_id, pool) {
  # Get user info including password for verification
  user <- pool %>%
    tbl("user") %>%
    filter(user_id == !!user_id) %>%
    select(user_id, password, account_status) %>%
    collect()

  if (nrow(user) == 0) {
    stop("User not found")
  }

  if (user$account_status != "active") {
    stop("User account not active")
  }

  # Check permissions and verify old password if needed
  is_admin <- requesting_role == "Administrator"
  is_self <- requesting_user_id == user_id

  if (!is_admin && !is_self) {
    stop("Insufficient permissions to change this user's password")
  }

  # Verify old password unless admin
  if (!is_admin) {
    if (!verify_password(user$password, old_password)) {
      stop("Current password is incorrect")
    }
  }

  # Hash and update password
  hashed_new_password <- hash_password(new_password)
  user_update_password(user_id, hashed_new_password)

  logger::log_info("Password changed",
    user_id = user_id,
    changed_by = requesting_user_id
  )

  list(status = 200, message = "Password changed successfully")
}


#' Bulk approve multiple users atomically
#'
#' Approves multiple users in a single atomic transaction. All users
#' are approved or none are (all-or-nothing guarantee).
#'
#' @param user_ids Integer vector of user IDs to approve
#' @param approving_user_id Integer user ID performing the approval
#' @param pool Database connection pool
#' @return List with processed count and message
#'
#' @details
#' - Validates array length <= 20 users
#' - Wraps all operations in database transaction
#' - For each user: sets account_status to "active", generates password, sends email
#' - If ANY user fails (not found, already approved), rolls back ALL changes
#' - Uses db_with_transaction for atomic semantics
#'
#' @examples
#' \dontrun{
#' result <- user_bulk_approve(c(42, 43, 44), 1, pool)
#' }
#'
#' @export
user_bulk_approve <- function(user_ids, approving_user_id, pool) {
  # Validate array length
  if (length(user_ids) == 0) {
    stop("user_ids cannot be empty")
  }
  if (length(user_ids) > 20) {
    stop("Cannot process more than 20 users at once")
  }

  # Execute all operations in a transaction
  db_with_transaction({
    processed <- 0

    for (user_id in user_ids) {
      # Get user details
      user <- pool %>%
        tbl("user") %>%
        filter(user_id == !!user_id) %>%
        select(
          user_id, user_name, email, first_name, family_name,
          account_status, password
        ) %>%
        collect()

      if (nrow(user) == 0) {
        stop(paste("User not found:", user_id))
      }

      if (user$account_status == "active") {
        stop(paste("User account already active:", user_id))
      }

      # Update user account status
      db_execute_statement(
        "UPDATE user SET account_status = ?, approving_user_id = ? WHERE user_id = ?",
        list("active", approving_user_id, user_id)
      )

      # Generate password if user doesn't have one
      if (is.null(user$password) || user$password == "") {
        user_password <- random_password()
        user_initials <- generate_initials(user$first_name, user$family_name)

        # Hash password with Argon2id before storing
        hashed_password <- hash_password(user_password)
        user_update_password(user_id, hashed_password)

        # Update abbreviation
        db_execute_statement(
          "UPDATE user SET abbreviation = ? WHERE user_id = ?",
          list(user_initials, user_id)
        )

        # Send approval email with password
        send_noreply_email(
          c(
            "Your registration for sysndd.org has been approved by a curator.",
            "Your password (please change after first login):",
            user_password
          ),
          "Account approved for SysNDD.org",
          user$email,
          "curator@sysndd.org"
        )
      }

      processed <- processed + 1
    }

    logger::log_info("Bulk approved users",
                     count = processed,
                     approving_user_id = approving_user_id)

    list(processed = processed, message = paste(processed, "users approved successfully"))
  }, pool_obj = pool)
}


#' Bulk delete multiple users atomically
#'
#' Deletes multiple users in a single atomic transaction. All users
#' are deleted or none are (all-or-nothing guarantee).
#'
#' @param user_ids Integer vector of user IDs to delete
#' @param requesting_user_id Integer user ID performing the deletion
#' @param pool Database connection pool
#' @return List with processed count and message
#'
#' @details
#' - Validates array length <= 20 users
#' - Checks if ANY user has role="Administrator" and rejects entire request if so
#' - Wraps all deletions in database transaction
#' - Protection against accidental admin deletion
#'
#' @examples
#' \dontrun{
#' result <- user_bulk_delete(c(42, 43), 1, pool)
#' }
#'
#' @export
user_bulk_delete <- function(user_ids, requesting_user_id, pool) {
  # Validate array length
  if (length(user_ids) == 0) {
    stop("user_ids cannot be empty")
  }
  if (length(user_ids) > 20) {
    stop("Cannot process more than 20 users at once")
  }

  # First, query all user_ids to get their roles (outside transaction)
  users <- pool %>%
    tbl("user") %>%
    filter(user_id %in% !!user_ids) %>%
    select(user_id, user_role) %>%
    collect()

  # Check if ANY user has Administrator role
  admin_users <- users %>% filter(user_role == "Administrator")
  if (nrow(admin_users) > 0) {
    admin_ids <- paste(admin_users$user_id, collapse = ", ")
    stop(paste("Cannot delete: selection contains admin users (IDs:", admin_ids, ")"))
  }

  # Execute all deletions in a transaction
  db_with_transaction({
    processed <- 0

    for (user_id in user_ids) {
      # Delete user
      rows_affected <- db_execute_statement(
        "DELETE FROM user WHERE user_id = ?",
        list(user_id)
      )

      if (rows_affected == 0) {
        stop(paste("User not found:", user_id))
      }

      processed <- processed + 1
    }

    logger::log_info("Bulk deleted users",
                     count = processed,
                     requesting_user_id = requesting_user_id)

    list(processed = processed, message = paste(processed, "users deleted successfully"))
  }, pool_obj = pool)
}


#' Bulk assign role to multiple users atomically
#'
#' Assigns a role to multiple users in a single atomic transaction.
#' All users are updated or none are (all-or-nothing guarantee).
#'
#' @param user_ids Integer vector of user IDs to update
#' @param new_role Character new role name
#' @param requesting_role Character role of user making the request
#' @param pool Database connection pool
#' @return List with processed count and message
#'
#' @details
#' - Validates array length <= 20 users
#' - Validates new_role is valid (Administrator, Curator, Reviewer, Viewer)
#' - Permission check: Curator cannot assign Administrator role
#' - Wraps all role updates in database transaction
#'
#' @examples
#' \dontrun{
#' result <- user_bulk_assign_role(c(42, 43), "Curator", "Administrator", pool)
#' }
#'
#' @export
user_bulk_assign_role <- function(user_ids, new_role, requesting_role, pool) {
  # Validate array length
  if (length(user_ids) == 0) {
    stop("user_ids cannot be empty")
  }
  if (length(user_ids) > 20) {
    stop("Cannot process more than 20 users at once")
  }

  # Validate new role
  allowed_roles <- c("Administrator", "Curator", "Reviewer", "Viewer")
  if (!new_role %in% allowed_roles) {
    stop("Invalid role specified")
  }

  # Check permissions
  if (requesting_role == "Curator" && new_role == "Administrator") {
    stop("Insufficient permissions to assign Administrator role")
  }

  # Execute all role updates in a transaction
  db_with_transaction({
    processed <- 0

    for (user_id in user_ids) {
      # Update user role
      rows_affected <- db_execute_statement(
        "UPDATE user SET user_role = ? WHERE user_id = ?",
        list(new_role, user_id)
      )

      if (rows_affected == 0) {
        stop(paste("User not found:", user_id))
      }

      processed <- processed + 1
    }

    logger::log_info("Bulk assigned role",
                     count = processed,
                     new_role = new_role)

    list(processed = processed, message = paste(processed, "users assigned to", new_role, "role successfully"))
  }, pool_obj = pool)
}
