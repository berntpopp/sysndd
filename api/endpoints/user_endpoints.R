# api/endpoints/user_endpoints.R
#
# User-related endpoints, extracted from the original sysndd_plumber.R.
# Functions (security.R, middleware.R, user-repository.R, services/*) are
# sourced by start_sysndd_api.R before endpoints are loaded and are available
# in the global environment.
#
# Thin authorization/delegation shell (#346): every `require_role()` gate and
# the admin-target shield (`assert_not_targeting_admin()`, #5) live here;
# request processing has moved to the `svc_`-prefixed functions in
# services/user-read-endpoint-service.R, services/user-account-endpoint-service.R,
# services/user-password-profile-endpoint-service.R, and
# services/user-bulk-endpoint-service.R.

## -------------------------------------------------------------------##
## User endpoint section
## -------------------------------------------------------------------##

#* Retrieves a summary table of users based on role permissions.
#* Admins see all users; Curators see only unapproved users; others are forbidden.
#* Supports server-side filtering, sorting, and cursor pagination.
#* @tag user
#* @serializer json list(na="null")
#* @param filter Filter string (e.g., "user_name:contains:john")
#* @param sort Sort string (e.g., "+user_name" or "-email")
#* @param page_after Cursor after which entries are shown (default: 0)
#* @param page_size Page size in cursor pagination (default: "all")
#* @param fspec Field specification for table columns
#* @get table
function(req, res, filter = "", sort = "+user_id", page_after = 0,
         page_size = "all",
         fspec = "user_id,user_name,email,user_role,approved,abbreviation,first_name,family_name,comment,created_at") {
  require_role(req, res, "Curator")

  svc_user_table_list(req, filter, sort, page_after, page_size, fspec)
}

#* Retrieves count statistics of all contributions for a specified user.
#* Users can view their own contributions. Reviewer/Curator/Admin can view any user.
#* @tag user
#* @serializer json list(na="string")
#* @get <user_id>/contributions
function(req, res, user_id) {
  if (as.integer(user_id) != req$user_id) {
    require_role(req, res, "Reviewer")
  }

  svc_user_contributions(user_id)
}

#* Manages the approval status of a user application.
#* Only Admin/Curator. If approved, sets user as approved=1, generates a password,
#* sends mail, etc. If unapproved, removes user from DB.
#* @tag user
#* @serializer json list(na="string")
#* @put approval
function(req, res, user_id = 0, status_approval = FALSE) {
  require_role(req, res, "Curator")

  user_id_approval <- as.integer(user_id)
  status_approval <- as.logical(status_approval)

  user_table <- svc_user_fetch_for_approval(user_id_approval)

  if (nrow(user_table) == 0) {
    res$status <- 409
    return(list(error = "User account does not exist."))
  }

  # SECURITY (#5): non-Administrator may not approve/reject a currently-Administrator target.
  if (req$user_role != "Administrator") {
    assert_not_targeting_admin(req$user_role, user_table$user_role)
  }

  svc_user_approval_apply(req, res, user_table, user_id_approval, status_approval)
}

#* Allows administrators to change the roles of users.
#* If admin, can set any role. If curator, can only set certain roles.
#* @tag user
#* @put change_role
function(req, res, user_id, role_assigned = "Viewer") {
  require_role(req, res, "Curator")

  user_id_role <- as.integer(user_id)
  role_assigned <- as.character(role_assigned)

  # SECURITY (#5): non-Administrator may not modify a currently-Administrator target.
  if (req$user_role != "Administrator") {
    assert_not_targeting_admin(req$user_role, user_current_roles(user_id_role, pool))
  }

  svc_user_change_role(req, res, user_id_role, role_assigned)
}

#* Retrieves a list of all available user roles.
#* Admin can see all roles, Curator sees all except "Administrator".
#* @tag user
#* @get role_list
function(req, res) {
  require_role(req, res, "Curator")

  svc_user_role_list(req)
}

#* Retrieves a list of users based on their roles.
#* Admin/Curator can filter users by roles.
#* @tag user
#* @get list
function(req, res, roles = "Viewer") {
  require_role(req, res, "Curator")

  svc_user_list_by_roles(res, roles)
}

#* Allows a user or an administrator to change the user's password.
#* Validates old password, checks new password complexity, updates DB.
#* Password input is accepted only via a JSON request body so secrets never
#* appear in URLs or access logs.
#* @tag user
#* @put password/update
function(req, res) {
  content_type <- req$HTTP_CONTENT_TYPE %||% req$CONTENT_TYPE %||% ""
  media_type <- strsplit(tolower(content_type), ";", fixed = TRUE)[[1]][1]
  if (media_type != "application/json") {
    res$status <- 415
    return(list(error = "Content-Type must be application/json."))
  }

  body <- tryCatch(
    jsonlite::fromJSON(req$postBody),
    error = function(e) NULL
  )
  required_fields <- c("user_id_pass_change", "old_pass", "new_pass_1", "new_pass_2")
  if (
    is.null(body) ||
      length(body) == 0 ||
      !all(required_fields %in% names(body))
  ) {
    res$status <- 400
    return(list(error = "Malformed or empty JSON body."))
  }

  is_scalar_string <- function(x) {
    is.character(x) && length(x) == 1 && !is.na(x)
  }

  is_scalar_integerish <- function(x) {
    if ((is.integer(x) || is.numeric(x)) && length(x) == 1 && !is.na(x) && is.finite(x)) {
      return(x == floor(x))
    }

    if (is.character(x) && length(x) == 1 && !is.na(x)) {
      return(grepl("^-?\\d+$", x))
    }

    FALSE
  }

  if (!is_scalar_integerish(body$user_id_pass_change)) {
    res$status <- 400
    return(list(error = "`user_id_pass_change` must be a scalar integer value."))
  }

  if (
    !is_scalar_string(body$old_pass) ||
      !is_scalar_string(body$new_pass_1) ||
      !is_scalar_string(body$new_pass_2)
  ) {
    res$status <- 400
    return(list(error = "`old_pass`, `new_pass_1`, and `new_pass_2` must each be scalar strings."))
  }

  svc_user_password_update(req, res, body)
}

#* Update User Profile (Self-Service)
#* Allows authenticated users to update their own email and ORCID (self-service
#* only). Validates email format and ORCID format (0000-0000-0000-000X).
#* @tag user
#* @serializer json list(na="string")
#* @response 200 OK. Profile updated successfully.
#* @response 400 Bad Request. Invalid email or ORCID format.
#* @response 401 Unauthorized. Not authenticated.
#* @put profile
function(req, res) {
  svc_user_profile_update(req, res)
}

#* Allows a user to request a password reset by email.
#* If the email is valid and exists in the DB, generates a reset token
#* and sends email with reset URL. Uses POST with JSON body per OWASP guidelines
#* to avoid exposing email in URL/logs.
#* @tag user
#* @post password/reset/request
function(req, res) {
  svc_user_password_reset_request(req, res)
}

#* Does password reset
#* This endpoint is called with a Bearer token that includes a
#* password_reset_date-based JWT. If valid and not expired, updates the password.
#* Uses POST with JSON body per OWASP guidelines - passwords must NEVER be in URLs.
#* @tag user
#* @post password/reset/change
function(req, res) {
  svc_user_password_reset_change(req, res)
}

#* Deletes a user from the system.
#* Admin only. Checks if user exists, deletes them, logs operation.
#* @tag user
#* @serializer json list(na="string")
#* @delete delete
function(req, res, user_id) {
  require_role(req, res, "Administrator")

  svc_user_delete(res, user_id)
}

#* Updates the details of an existing user and handles approval process.
#* Admin can modify user attributes. If approved, checks for existing password
#* else generates one and sends email.
#* @tag user
#* @serializer json list(na="string")
#* @accept json
#* @put update
function(req, res) {
  require_role(req, res, "Administrator")

  svc_user_update_details(req, res)
}

#* Bulk approve multiple users
#* Approves multiple users in a single atomic transaction.
#* Requires Curator role or higher. Max 20 users per request.
#* @tag user
#* @serializer json list(na="null")
#* @accept json
#* @post bulk_approve
function(req, res) {
  require_role(req, res, "Curator")

  user_ids <- as.integer(req$argsBody$user_ids)

  # SECURITY (#5): non-Administrator may not bulk-approve currently-Administrator targets.
  if (req$user_role != "Administrator") {
    assert_not_targeting_admin(req$user_role, user_current_roles(user_ids, pool))
  }

  svc_user_bulk_approve(req, res, user_ids)
}

#* Bulk delete multiple users
#* Deletes multiple users in a single atomic transaction.
#* Requires Administrator role. Max 20 users per request.
#* Rejects requests containing admin users.
#* @tag user
#* @serializer json list(na="null")
#* @accept json
#* @post bulk_delete
function(req, res) {
  require_role(req, res, "Administrator")

  user_ids <- as.integer(req$argsBody$user_ids)

  svc_user_bulk_delete(req, res, user_ids)
}

#* Bulk assign role to multiple users
#* Assigns a role to multiple users in a single atomic transaction.
#* Requires Curator role or higher. Max 20 users per request.
#* Curators cannot assign Administrator role.
#* @tag user
#* @serializer json list(na="null")
#* @accept json
#* @post bulk_assign_role
function(req, res) {
  require_role(req, res, "Curator")

  user_ids <- as.integer(req$argsBody$user_ids)
  role <- req$argsBody$role

  svc_user_bulk_assign_role(req, res, user_ids, role)
}
