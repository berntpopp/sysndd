#### This file holds function for interaction with external resources

# this function posts a url to the internet archive using their SPN2 API
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
