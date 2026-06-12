# api/functions/user-endpoint-helpers.R

#' Shared password complexity rule for the change and reset flows
#'
#' A candidate password must be longer than 7 characters and contain at least
#' one lowercase letter, one uppercase letter, one digit, and one of the
#' permitted special characters (`!@#$%^&*`).
#'
#' @param password Candidate password string.
#' @return `TRUE` when the password satisfies every rule, otherwise `FALSE`.
#' @export
password_meets_complexity <- function(password) {
  nchar(password) > 7 &&
    grepl("[a-z]", password) &&
    grepl("[A-Z]", password) &&
    grepl("\\d", password) &&
    grepl("[!@#$%^&*]", password)
}

#' Validate a new-password pair for the change/reset flows
#'
#' Confirms the new password and its confirmation match, optionally differ from
#' the current password (password-change flow only), and satisfy the shared
#' complexity rule. The reset flow has no current password and omits `old_pass`.
#'
#' @param new_pass_1 The proposed new password.
#' @param new_pass_2 The confirmation of the new password.
#' @param old_pass Optional current password. When supplied, the new password
#'   must differ from it; the reset flow passes `NULL`.
#' @return `TRUE` when the pair is valid, otherwise `FALSE`.
#' @export
new_password_valid <- function(new_pass_1, new_pass_2, old_pass = NULL) {
  (new_pass_1 == new_pass_2) &&
    (is.null(old_pass) || new_pass_1 != old_pass) &&
    password_meets_complexity(new_pass_1)
}
