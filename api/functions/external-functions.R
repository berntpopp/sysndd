#### This file holds function for interaction with external resources

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
post_url_archive <- function(parameter_url,
    parameter_capture_screenshot = "on") {

    # check if provided URL is valid
    # TODO: implement more sanity checks
    url_valid <- str_detect(parameter_url, dw$archive_base_url)

    if (url_valid) {
    # based on https://docs.google.com/document/
    # d/1Nsv52MvSjbLb2PCpHlat0gkzw0EvtSgpKHu4mk0MnrA/edit
    response <- httr::POST("https://web.archive.org/save",
      body = list(url = parameter_url,
        capture_screenshot = parameter_capture_screenshot),
      add_headers(Accept = "application/json",
        Authorization = paste0("LOW ",
          dw$archive_access_key,
          ":",
          dw$archive_secret_key)))

    # TODO: more meaningful response
    # TODO: wait for and get success message
    return(content(response))

    } else {
    # return Bad Request
    return(list(status = 400,
      message = paste0("The submittedURL",
      "is not a valid SyNDD URL."
                )
            )
        )
    }
}
