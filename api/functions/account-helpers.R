# functions/account-helpers.R
#### User/account helper functions (random_password, is_valid_email,
#### generate_initials, send_noreply_email)
#### Split from helper-functions.R in v11.0 phase D2.
####
#### Dependencies (loaded by start_sysndd_api.R):
####   blastula (compose_email, md, smtp_send, creds_envvar)
####   htmltools (HTML)
####   dw config object (mail settings)


#' Generate a random password
#'
#' @description
#' Generates a 12-character temporary password from a 64-symbol alphabet
#' (digits, lowercase, uppercase, "!", "$"). Randomness comes from a CSPRNG
#' (\code{openssl::rand_bytes}), NOT the seedable Mersenne-Twister behind
#' \code{sample()}, because credentials must not be reproducible from a known
#' seed. The alphabet is exactly 64 characters and \code{256 \%\% 64 == 0}, so
#' mapping each uniform random byte with \code{\%\% 64} is bias-free (every symbol
#' has exactly four byte preimages, no modulo bias, no rejection sampling needed).
#' Entropy is 12 * log2(64) = 72 bits.
#'
#' @return A randomly generated password.
#'
#' @examples
#' # Generate a random password
#' random_password()
#'
#' @seealso
#' Based on: \url{https://stackoverflow.com/questions/22219035/function-to-generate-a-random-password}
#'
#' @export
random_password <- function() {
  # create a vector of possible characters
  possible_characters <- c(0:9, letters, LETTERS, "!", "$")

  # Draw from a CSPRNG (openssl::rand_bytes), NOT sample()/Mersenne-Twister, which
  # is seedable and predictable and must never generate credentials. The alphabet
  # is exactly 64 characters and 256 %% 64 == 0, so mapping a uniform random byte
  # with `%% 64` is bias-free (no rejection sampling needed). Keep the alphabet at
  # 64 entries or this invariant no longer holds.
  n_chars <- 12L
  idx <- as.integer(openssl::rand_bytes(n_chars)) %% length(possible_characters) + 1L
  password <- paste(possible_characters[idx], collapse = "")

  # return password
  return(password)
}


#' Validate email address
#'
#' @description
#' Checks whether a value is a single, syntactically valid email address that is
#' safe to hand to \code{smtp_send()} as a \code{to}/\code{bcc} header. The value
#' must be a NON-NA scalar string, contain NO control characters (CR/LF/tab/etc.,
#' which enable SMTP header injection), and match the whole-string (anchored)
#' pattern local-part@domain.tld. The old pattern used \code{\\<}/\code{\\>} word
#' boundaries, which are NOT anchors: a valid address embedded in surrounding junk
#' (including a newline-delimited injected header) matched. This function is now
#' anchored and control-char-free so it is a trustworthy gate for the mail path.
#'
#' @param email_address A character string representing an email address.
#'
#' @return A single boolean; TRUE only for a safe, valid, scalar email address.
#'
#' @examples
#' # Validate an email address
#' is_valid_email("test@example.com")
#'
#' @seealso
#' Based on: \url{https://www.r-bloggers.com/2012/07/validating-email-adresses-in-r/}
#'
#' @export
is_valid_email <- function(email_address) {
  # Reject non-scalar / NA up front: a vector could smuggle multiple addresses,
  # and NA would coerce to the string "NA".
  if (is.null(email_address) || length(email_address) != 1L ||
    is.na(email_address)) {
    return(FALSE)
  }
  email_address <- as.character(email_address)
  # Any control character (CR/LF/tab) is disqualifying — it enables SMTP header
  # injection once the value reaches the `to`/`bcc` header.
  if (grepl("[[:cntrl:]]", email_address)) {
    return(FALSE)
  }
  # Anchored whole-string match (^...$), so surrounding text cannot slip through.
  grepl("^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$",
    email_address,
    ignore.case = TRUE
  )
}


#' Detect control characters in a user-supplied account field
#'
#' @description
#' Returns TRUE if any element of \code{x} contains a control character
#' (CR, LF, tab, etc.). Signup/profile free-text fields (user_name, first_name,
#' family_name, email, orcid, comment) must reject these: a CR/LF survives into
#' log lines (\code{message()}/logger, enabling log forging) and into email
#' headers when the value is later emailed. Printable non-ASCII (accents,
#' apostrophes) is intentionally allowed.
#'
#' @param x A character vector (or coercible) to inspect.
#'
#' @return A single logical: TRUE if a control character is present.
#'
#' @export
account_field_has_control_char <- function(x) {
  any(grepl("[[:cntrl:]]", as.character(x)))
}


#' Neutralize control characters before a value is logged
#'
#' @description
#' Replaces any control character (CR, LF, tab, etc.) in \code{x} with a space so
#' that a stored user-controlled value (e.g. a legacy \code{user_name} that
#' predates the signup control-char guard) cannot forge log lines when it is
#' interpolated into a log message.
#'
#' @param x A value (coerced to character) about to be logged.
#'
#' @return A character vector with control characters replaced by spaces.
#'
#' @export
sanitize_log_value <- function(x) {
  gsub("[[:cntrl:]]", " ", as.character(x))
}


#' This function generates initials for an avatar based on the provided
#' first name and family name. The initials are created by taking the first
#' character of each name.
#'
#' @param first_name A character string representing the first name.
#' @param family_name A character string representing the family name.
#'
#' @return
#' A character string containing the initials, created by taking the first
#' character of the first name and the first character of the family name.
#'
#' @examples
#' generate_initials("John", "Doe")
#' generate_initials("Ada", "Lovelace")
#'
#' @seealso
#' \url{https://stackoverflow.com/questions/24833566/get-initials-from-string-of-words}
#' for the Stack Overflow question that inspired this function.
#' @export
generate_initials <- function(first_name, family_name) {
  initials <- paste(
    substr(
      strsplit(
        paste0(
          first_name,
          " ",
          family_name
        ),
        " "
      )[[1]],
      1, 1
    ),
    collapse = ""
  )

  return(initials)
}


#' Send a no-reply email
#'
#' @description
#' This function sends a no-reply email with a specified email body, subject,
#' and recipient. It allows for an optional blind copy recipient.
#' Supports both plain text (legacy) and full HTML content.
#'
#' @param email_body A character string representing the body of the email.
#'   Can be plain text (will be converted to markdown) or full HTML
#'   (when html_content=TRUE).
#' @param email_subject A character string representing the subject of the email.
#' @param email_recipient A character string representing the recipient's email
#'   address.
#' @param email_blind_copy Optional blind-copy recipient address(es). Defaults to
#'   NULL (NO blind copy). Credential/token emails (account approval, password
#'   reset) must NOT be blind-copied to a shared mailbox, so callers that need a
#'   curator notification pass an explicit non-secret address; everything else
#'   goes only to the recipient.
#' @param html_content Logical. If TRUE, email_body is treated as complete HTML.
#'   If FALSE (default), email_body is treated as markdown/plain text.
#'
#' @return
#' A character string indicating that the email has been sent.
#'
#' @examples
#' send_noreply_email(
#'   email_body = "Hello, this is a test email.",
#'   email_subject = "Test Email",
#'   email_recipient = "example@example.com"
#' )
#' @export
send_noreply_email <- function(
  email_body,
  email_subject,
  email_recipient,
  email_blind_copy = NULL,
  html_content = FALSE
) {
  # Defense-in-depth: this is the single choke point every outbound account email
  # passes through, so validate the transport headers here before smtp_send().
  # is_valid_email() is scalar-only, NA-safe, control-char-free and anchored, so
  # it rejects both SMTP header injection (CR/LF) AND SMTP recipient grammar such
  # as `<a@b.com> NOTIFY=SUCCESS` that a legacy/admin-edited row (predating the
  # anchored signup validator) could otherwise smuggle to the transport. The
  # subject is not an address, so it is only checked for control characters.
  if (!is_valid_email(email_recipient)) {
    stop("send_noreply_email: recipient is not a valid email address",
      call. = FALSE)
  }
  if (length(as.character(email_subject)) != 1L || is.na(email_subject) ||
    grepl("[[:cntrl:]]", as.character(email_subject))) {
    stop("send_noreply_email: subject contains disallowed control characters",
      call. = FALSE)
  }
  # BCC is optional and may be a character vector (the curator notification list).
  # Drop empty entries (an empty string means "no blind copy"); validate the rest.
  if (!is.null(email_blind_copy)) {
    bcc <- as.character(email_blind_copy)
    bcc <- bcc[nzchar(trimws(bcc))]
    if (length(bcc) > 0L) {
      if (!all(vapply(bcc, is_valid_email, logical(1)))) {
        stop("send_noreply_email: bcc contains an invalid email address",
          call. = FALSE)
      }
      email_blind_copy <- bcc
    } else {
      email_blind_copy <- NULL
    }
  }

  if (html_content) {
    # Use full HTML content directly (from email-templates.R)
    # Wrap with htmltools::HTML() for proper raw HTML handling
    email <- compose_email(
      body = htmltools::HTML(email_body)
    )
  } else {
    # Legacy: treat as markdown with standard footer
    email <- compose_email(
      body = md(email_body),
      footer = md(paste0(
        "Visit [SysNDD.org](https://www.sysndd.org) for ",
        "the latest information on Neurodevelopmental Disorders."
      ))
    )
  }

  suppressMessages(email %>%
    smtp_send(
      from = "noreply@sysndd.org",
      subject = email_subject,
      to = email_recipient,
      bcc = email_blind_copy,
      credentials = creds_envvar(
        pass_envvar = "SMTP_PASSWORD",
        user = dw$mail_noreply_user,
        host = dw$mail_noreply_host,
        port = dw$mail_noreply_port,
        use_ssl = dw$mail_noreply_use_ssl
      )
    ))
  return("Request mail send!")
}
