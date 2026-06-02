# functions/exernal-functions.R
#### This file holds function for interaction with external resources

#' Validate a URL is an https URL whose host exactly matches the archive base.
#'
#' Parses both URLs and compares scheme+host exactly (no substring/regex
#' matching) to prevent host-spoofing of the archive credential.
#'
#' @param parameter_url Candidate URL string.
#' @param archive_base_url Trusted base URL (dw$archive_base_url).
#' @return Logical TRUE only for an https URL on the exact archive host.
#' @export
is_valid_archive_url <- function(parameter_url, archive_base_url) {
  if (is.null(parameter_url) || length(parameter_url) != 1L ||
        is.na(parameter_url) || parameter_url == "") {
    return(FALSE)
  }
  parsed <- tryCatch(httr2::url_parse(parameter_url), error = function(e) NULL)
  base <- tryCatch(httr2::url_parse(archive_base_url), error = function(e) NULL)
  if (is.null(parsed) || is.null(base)) {
    return(FALSE)
  }
  # Hostnames are case-insensitive; compare lower-cased to avoid false negatives
  # on legitimate mixed-case URLs while keeping an exact (non-substring) match.
  identical(parsed$scheme, "https") &&
    !is.null(parsed$hostname) && !is.null(base$hostname) &&
    identical(tolower(parsed$hostname), tolower(base$hostname))
}

#' Post URL to the Internet Archive using their SPN2 API
#'
#' @description
#' This function posts a URL to the Internet Archive using their SPN2 API. It
#' takes a URL and an optional parameter to capture a screenshot. The function
#' checks if the provided URL is valid and returns the response from the API.
#'
#' @param parameter_url A character string representing the URL to be posted to
#'   the Internet Archive.
#' @param parameter_capture_screenshot An optional character string with the
#'   default value "on". If set to "on", a screenshot will be captured.
#'   Otherwise, no screenshot will be taken.
#'
#' @return
#' If the provided URL is valid, the function returns the response from the API
#' as a list. If the URL is not valid, it returns a list with a status code of
#' 400 and an error message.
#'
#' @examples
#' post_url_archive("https://example.com")
#' post_url_archive("https://example.com", parameter_capture_screenshot = "off")
#'
#' @export
post_url_archive <- function(
  parameter_url,
  parameter_capture_screenshot = "on"
) {
  # Validate URL is from SysNDD domain using exact-host check.
  # Delegates to is_valid_archive_url() for consistent validation.
  url_valid <- is_valid_archive_url(parameter_url, dw$archive_base_url) &&
    nchar(parameter_url) < 2048 # URL length sanity check

  if (url_valid) {
    # based on https://docs.google.com/document/
    # d/1Nsv52MvSjbLb2PCpHlat0gkzw0EvtSgpKHu4mk0MnrA/edit
    response <- httr::POST("https://web.archive.org/save",
      body = list(
        url = parameter_url,
        capture_screenshot = parameter_capture_screenshot
      ),
      add_headers(
        Accept = "application/json",
        Authorization = paste0(
          "LOW ",
          dw$archive_access_key,
          ":",
          dw$archive_secret_key
        )
      )
    )

    # Internet Archive SPN2 API is asynchronous
    # Returns job_id immediately, actual archiving completes later
    # Current implementation returns raw response with job_id
    # Clients can poll job_id status endpoint if needed
    response_content <- content(response)

    # Basic response validation
    if (response$status_code >= 400) {
      return(list(
        status = response$status_code,
        message = "Internet Archive request failed",
        details = response_content
      ))
    }

    return(response_content)
  } else {
    # return Bad Request
    return(list(
      status = 400,
      message = paste0(
        "The submittedURL",
        "is not a valid SyNDD URL."
      )
    ))
  }
}
