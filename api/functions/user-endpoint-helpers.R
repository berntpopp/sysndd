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

#' Process a password-reset REQUEST (email a one-time reset link, best-effort)
#'
#' Pure, side-effect-injectable core of `POST /api/user/password/reset/request`.
#' The handler collects the `user` table and delegates here so the flow can be
#' unit-tested without a live SMTP relay or database.
#'
#' Behaviour (see `test-unit-password-reset-request.R`):
#' - Syntactically invalid email -> `400` (a client input error, not enumeration).
#' - Any other outcome -> a SINGLE generic `200` response, whether or not the
#'   email matches an account and whether or not the mail is delivered. This
#'   makes the endpoint impossible to use for account enumeration.
#' - Email delivery is BEST-EFFORT: a send failure (most commonly an SMTP
#'   outage) is logged loudly and swallowed, so the endpoint never returns a
#'   `500`. This mirrors the signup (#470) and admin-approval email hardening;
#'   the reset flow was previously the only email path that let an SMTP error
#'   propagate as an opaque error to a locked-out user.
#'
#' The reset-token semantics (JWT claim, `md5(salt+password)` fingerprint,
#' `password_reset_date` stamp, `iat`/`exp`) are byte-identical to the historic
#' inline handler so the sibling `POST .../password/reset/change` still
#' validates tokens minted here.
#'
#' @param email_request Raw email string from the request body.
#' @param user_table Collected `user` table tibble (needs `user_id`,
#'   `user_name`, `email`, `password`).
#' @param dw Config object (`secret`, `salt`, `refresh`, `base_url`).
#' @param send_email Mailer, injectable for tests. Defaults to
#'   `send_noreply_email`.
#' @param update_reset_date Reset-date writer, injectable for tests. Defaults to
#'   stamping `password_reset_date` via `user_update`.
#' @return `list(status = <int>, body = <list>)` for the handler to emit.
#' @export
process_password_reset_request <- function(
  email_request,
  user_table,
  dw,
  send_email = send_noreply_email,
  update_reset_date = function(user_id, ts) {
    user_update(user_id, list(password_reset_date = as.character(ts)))
  }
) {
  generic_ok <- list(
    status = 200L,
    body = list(
      message = paste0(
        "If an account exists for that email address, ",
        "a password reset link has been sent."
      )
    )
  )

  if (!is_valid_email(email_request)) {
    return(list(status = 400L, body = list(error = "Invalid Parameter Value Error.")))
  }

  # Case-insensitive lookup, first match only. Emails are unique in practice,
  # but a case-only collision must not produce a vector-valued JWT claim.
  matched <- user_table %>%
    dplyr::mutate(email_lower = stringr::str_to_lower(.data$email)) %>%
    dplyr::filter(.data$email_lower == stringr::str_to_lower(email_request)) %>%
    dplyr::slice(1L)

  if (nrow(matched) == 0L) {
    return(generic_ok) # unknown email: identical generic response
  }

  # Known account: mint the reset token, stamp the reset date, and email the
  # link. The whole block is best-effort — any failure (SMTP outage, transient
  # DB error) is logged and swallowed so the caller always receives `generic_ok`
  # and the endpoint never 500s.
  tryCatch(
    {
      ts <- Sys.time()
      key <- charToRaw(
        if (is.list(dw$secret)) as.character(dw$secret[[1]]) else as.character(dw$secret)
      )

      update_reset_date(matched$user_id, ts)

      claim <- jose::jwt_claim(
        user_id = matched$user_id,
        user_name = matched$user_name,
        email = matched$email,
        hash = toString(md5(paste0(dw$salt, matched$password))),
        iat = as.integer(ts),
        exp = as.integer(ts) + dw$refresh
      )
      jwt <- jose::jwt_encode_hmac(claim, secret = key)
      reset_url <- paste0(dw$base_url, "/PasswordReset/", jwt)

      email_html <- email_password_reset(
        reset_url = reset_url,
        user_name = matched$user_name,
        expiry_minutes = round(dw$refresh / 60)
      )

      send_email(
        email_body = email_html,
        email_subject = "Reset Your SysNDD Password",
        email_recipient = matched$email,
        html_content = TRUE
      )
    },
    error = function(e) {
      msg <- sprintf(
        "[password-reset] token processed but delivery FAILED for user_id=%s: %s",
        matched$user_id, conditionMessage(e)
      )
      if (requireNamespace("logger", quietly = TRUE)) {
        logger::log_error(msg)
      } else {
        message(msg)
      }
    }
  )

  generic_ok
}
