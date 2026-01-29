# tests/testthat/helper-mailpit.R
# Mailpit API helpers for email integration tests
#
# These functions provide access to the Mailpit test email server.
# Uses httr2 for HTTP requests to Mailpit REST API.

#' Check if Mailpit is available
#'
#' Attempts to connect to Mailpit API and returns TRUE/FALSE.
#' Used internally by skip_if_no_mailpit().
#'
#' @param mailpit_url Base URL for Mailpit (default: http://localhost:8025)
#' @return Logical indicating if Mailpit is available
mailpit_available <- function(mailpit_url = "http://localhost:8025") {
  tryCatch({
    resp <- httr2::request(paste0(mailpit_url, "/api/v1/messages")) |>
      httr2::req_timeout(2) |>
      httr2::req_perform()
    httr2::resp_status(resp) == 200
  }, error = function(e) FALSE)
}


#' Skip test if Mailpit not available
#'
#' Call at the start of integration tests that require Mailpit.
#' Provides informative skip message.
#'
#' @examples
#' test_that("email sends correctly", {
#'   skip_if_no_mailpit()
#'   # ... test code ...
#' })
skip_if_no_mailpit <- function() {
  if (!mailpit_available()) {
    testthat::skip(
      "Mailpit not available (start with: docker compose -f docker-compose.dev.yml up -d mailpit)"
    )
  }
}


#' Get all messages from Mailpit
#'
#' Returns the message list from Mailpit inbox.
#'
#' @param mailpit_url Base URL for Mailpit
#' @return List with messages array and total count
mailpit_get_messages <- function(mailpit_url = "http://localhost:8025") {
  resp <- httr2::request(paste0(mailpit_url, "/api/v1/messages")) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}


#' Search messages in Mailpit
#'
#' Searches Mailpit inbox using query string.
#'
#' @param query Search query (email address, subject text, etc.)
#' @param mailpit_url Base URL for Mailpit
#' @return List with matching messages
mailpit_search <- function(query, mailpit_url = "http://localhost:8025") {
  resp <- httr2::request(paste0(mailpit_url, "/api/v1/search")) |>
    httr2::req_url_query(query = query) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}


#' Delete all messages in Mailpit
#'
#' Clears Mailpit inbox. Call before tests for isolation.
#'
#' @param mailpit_url Base URL for Mailpit
#' @return Invisible TRUE on success
mailpit_delete_all <- function(mailpit_url = "http://localhost:8025") {
  httr2::request(paste0(mailpit_url, "/api/v1/messages")) |>
    httr2::req_method("DELETE") |>
    httr2::req_perform()
  invisible(TRUE)
}


#' Get message count in Mailpit
#'
#' Returns total number of messages in inbox.
#'
#' @param mailpit_url Base URL for Mailpit
#' @return Integer message count
mailpit_message_count <- function(mailpit_url = "http://localhost:8025") {
  messages <- mailpit_get_messages(mailpit_url)
  messages$total %||% 0
}


#' Wait for message to appear in Mailpit
#'
#' Polls Mailpit until a message matching the query appears or timeout.
#' Useful when email sending is asynchronous.
#'
#' @param query Search query (typically recipient email)
#' @param timeout_seconds Maximum time to wait (default: 10)
#' @param mailpit_url Base URL for Mailpit
#' @return First matching message, or error on timeout
mailpit_wait_for_message <- function(
    query,
    timeout_seconds = 10,
    mailpit_url = "http://localhost:8025") {
  start_time <- Sys.time()
  while (difftime(Sys.time(), start_time, units = "secs") < timeout_seconds) {
    result <- mailpit_search(query, mailpit_url)
    if (!is.null(result$total) && result$total > 0) {
      return(result$messages[[1]])
    }
    Sys.sleep(0.5)
  }
  stop(paste("Timeout waiting for email matching:", query))
}


#' Get full message by ID
#'
#' Retrieves complete message content including body.
#'
#' @param message_id Mailpit message ID
#' @param mailpit_url Base URL for Mailpit
#' @return Full message object with Text and HTML body
mailpit_get_message <- function(message_id, mailpit_url = "http://localhost:8025") {
  resp <- httr2::request(paste0(mailpit_url, "/api/v1/message/", message_id)) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}
