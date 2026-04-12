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
#' This function generates a random password of length 12
#' by selecting characters from a vector of possible characters
#' that includes digits, lowercase letters, uppercase letters,
#' exclamation mark, and dollar sign. The steps are as follows:
#' 1. Create a vector named 'possible_characters' containing digits, lowercase
#'    letters, uppercase letters, exclamation mark, and dollar sign.
#' 2. Use the 'sample()' function to randomly select 12 characters from the
#'    'possible_characters' vector and 'paste()' to combine them into a string.
#' 3. Use 'collapse = ""' argument in the 'paste()' function to prevent any
#'    separators between the selected characters.
#' 4. Return the generated password.
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

  # use paste and sample to generate a random password of length 12
  password <- paste(sample(possible_characters, 12), collapse = "")

  # return password
  return(password)
}


#' Validate email address
#'
#' @description
#' This function checks whether a given email address is valid by using regular
#' expressions and the 'grepl()' function. The email address is considered valid
#' if it matches the following pattern:
#' 1. Starts with a word boundary (\<).
#' 2. Followed by one or more uppercase letters, digits, dots, underscores,
#'    percent signs, plus signs, or hyphens ([A-Z0-9._%+-]+).
#' 3. Followed by the at symbol (@).
#' 4. Followed by one or more uppercase letters, digits, dots, or hyphens
#'    ([A-Z0-9.-]+).
#' 5. Followed by a dot (.).
#' 6. Followed by two or more uppercase letters ([A-Z]{2,}).
#' 7. Ends with a word boundary (\>).
#' The 'ignore.case = TRUE' argument in 'grepl()' makes the function
#' case-insensitive, allowing it to match email addresses regardless of the
#' letter case.
#'
#' @param email_address A character string representing an email address.
#'
#' @return A boolean value indicating whether the email address is valid.
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
  grepl("\\<[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}\\>",
    as.character(email_address),
    ignore.case = TRUE
  )
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
#' @param email_blind_copy A character string representing the blind copy
#'   recipient's email address, with a default value of "noreply@sysndd.org".
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
  email_blind_copy = "noreply@sysndd.org",
  html_content = FALSE
) {
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
