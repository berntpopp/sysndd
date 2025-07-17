# api/endpoints/external_endpoints.R
#
# This file contains all External-related endpoints extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions where
# possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Make sure to source any required helpers or libraries at the top if needed.

## -------------------------------------------------------------------##
## External endpoints
## -------------------------------------------------------------------##

#* Submit URL to Internet Archive
#*
#* This endpoint takes a SysNDD URL and submits it to the Internet Archive
#* (a.k.a. the Wayback Machine) for archiving.
#*
#* # `Details`
#* Validates the provided URL against a base URL (dw$archive_base_url).
#* If valid, it calls the helper function `post_url_archive()`.
#*
#* # `Return`
#* Returns a status of the archiving operation. If invalid or missing,
#* returns an error with HTTP status 400.
#*
#* @tag external
#* @serializer json list(na="string")
#*
#* @param parameter_url The URL to be archived.
#* @param capture_screenshot Whether to capture a screenshot (on/off).
#*
#* @response 200 OK if successful.
#* @response 400 Bad Request if the URL is invalid or missing.
#*
#* @get internet_archive
function(req, res, parameter_url, capture_screenshot = "on") {
  # Check if provided URL is valid
  url_valid <- str_detect(parameter_url, dw$archive_base_url)

  if (!url_valid) {
    res$status <- 400
    res$body <- jsonlite::toJSON(
      auto_unbox = TRUE,
      list(
        status = 400,
        message = "Required 'url' parameter not provided or not valid."
      )
    )
    return(res)
  } else {
    # Block to generate and post the external archive request
    response_archive <- post_url_archive(parameter_url, capture_screenshot)
    return(response_archive)
  }
}

## External endpoints
## -------------------------------------------------------------------##
