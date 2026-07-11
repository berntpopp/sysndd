# api/services/user-bulk-endpoint-service.R
#
# Endpoint service for the atomic bulk-mutation routes in
# endpoints/user_endpoints.R: bulk approve, bulk delete, bulk assign-role.
# `require_role()` gates stay in the endpoint shells. The bulk_approve
# admin-target shield (`assert_not_targeting_admin()`, #5) also stays in its
# shell (bulk_delete is Administrator-only and needs no target shield;
# bulk_assign_role's shield already lives one layer down, inside
# `user_bulk_assign_role()` in services/user-service.R). Each `svc_` function
# here owns the array-shape validation (empty / >20 cap) plus the
# try/error-to-status mapping around the transactional services/user-service.R
# `user_bulk_*()` functions.

#' Bulk-approve up to 20 users in one atomic transaction.
#'
#' Behind `POST /api/user/bulk_approve`, called after the shell's
#' admin-target shield check.
#'
#' @param req Plumber request (needs `req$user_id`).
#' @param res Plumber response (mutated on the 400/409 paths).
#' @param user_ids Integer vector of target user ids.
#' @return List response body.
svc_user_bulk_approve <- function(req, res, user_ids) {
  if (is.null(user_ids) || length(user_ids) == 0) {
    res$status <- 400
    return(list(error = "user_ids array is required and cannot be empty"))
  }

  if (length(user_ids) > 20) {
    res$status <- 400
    return(list(error = "Cannot process more than 20 users at once"))
  }

  result <- tryCatch(
    {
      user_bulk_approve(user_ids, req$user_id, pool)
    },
    error = function(e) {
      list(error = e$message)
    }
  )

  if (!is.null(result$error)) {
    res$status <- 409
    return(list(error = result$error))
  }

  list(processed = result$processed, message = result$message)
}

#' Bulk-delete up to 20 users in one atomic transaction.
#'
#' Behind `POST /api/user/bulk_delete` (Administrator-only). Rejects the
#' whole batch with 403 if any target is currently an Administrator.
#'
#' @param req Plumber request (needs `req$user_id`).
#' @param res Plumber response (mutated on the 400/403/409 paths).
#' @param user_ids Integer vector of target user ids.
#' @return List response body.
svc_user_bulk_delete <- function(req, res, user_ids) {
  if (is.null(user_ids) || length(user_ids) == 0) {
    res$status <- 400
    return(list(error = "user_ids array is required and cannot be empty"))
  }

  if (length(user_ids) > 20) {
    res$status <- 400
    return(list(error = "Cannot process more than 20 users at once"))
  }

  result <- tryCatch(
    {
      user_bulk_delete(user_ids, req$user_id, pool)
    },
    error = function(e) {
      # Check if error is about admin users
      if (grepl("Cannot delete: selection contains admin users", e$message)) {
        res$status <- 403
        return(list(error = e$message))
      }
      list(error = e$message)
    }
  )

  if (!is.null(result$error)) {
    if (res$status != 403) {
      res$status <- 409
    }
    return(list(error = result$error))
  }

  list(processed = result$processed, message = result$message)
}

#' Bulk-assign a role to up to 20 users in one atomic transaction.
#'
#' Behind `POST /api/user/bulk_assign_role`. Curators may not assign the
#' Administrator role; the target-current-role admin shield is enforced one
#' layer down by `user_bulk_assign_role()` (services/user-service.R).
#'
#' @param req Plumber request (needs `req$user_role`).
#' @param res Plumber response (mutated on the 400/403/409 paths).
#' @param user_ids Integer vector of target user ids.
#' @param role Character role to assign.
#' @return List response body.
svc_user_bulk_assign_role <- function(req, res, user_ids, role) {
  if (is.null(user_ids) || length(user_ids) == 0) {
    res$status <- 400
    return(list(error = "user_ids array is required and cannot be empty"))
  }

  if (is.null(role) || role == "") {
    res$status <- 400
    return(list(error = "role field is required"))
  }

  if (length(user_ids) > 20) {
    res$status <- 400
    return(list(error = "Cannot process more than 20 users at once"))
  }

  allowed_roles <- c("Administrator", "Curator", "Reviewer", "Viewer")
  if (!role %in% allowed_roles) {
    res$status <- 400
    return(list(error = "Invalid role specified"))
  }

  if (req$user_role == "Curator" && role == "Administrator") {
    res$status <- 403
    return(list(error = "Insufficient permissions to assign Administrator role"))
  }

  result <- tryCatch(
    {
      user_bulk_assign_role(user_ids, role, req$user_role, pool)
    },
    error = function(e) {
      list(error = e$message)
    }
  )

  if (!is.null(result$error)) {
    res$status <- 409
    return(list(error = result$error))
  }

  list(processed = result$processed, message = result$message)
}
