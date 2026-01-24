# functions/logging-functions.R

#' Update Examples in API Specification
#'
#' @description
#' This function iterates through the API specification and updates the `example`
#' properties for each endpoint based on a JSON file. The function is designed
#' to work with Plumber API specifications and aims to update only the example
#' data while retaining other metadata for each endpoint.
#'
#' @param spec A list representing the current API specification in the Plumber API.
#' @param api_spec_json A list representing the API specification read from a JSON file.
#'
#' @return The updated API specification with examples modified as per the JSON file.
#'
#' @examples
#' # Assuming spec is your current API spec and api_spec is the spec read from a JSON file
#' updated_spec <- update_api_spec_examples(spec, api_spec)
#'
#' @seealso
#' \url{https://www.rplumber.io/} for more information on Plumber API.
#'
#' @export
update_api_spec_examples <- function(spec, api_spec_json) {
  for (path in names(api_spec_json)) {
    if (is.null(spec$paths[[path]])) next
    for (method in names(api_spec_json[[path]])) {
      if (is.null(spec$paths[[path]][[method]])) next
      if (is.null(api_spec_json[[path]][[method]]$requestBody$content$`application/json`$schema$properties$create_json$example)) next
      spec$paths[[path]][[method]]$requestBody$content$`application/json`$schema$properties$create_json$example <- api_spec_json[[path]][[method]]$requestBody$content$`application/json`$schema$properties$create_json$example
    }
  }
  return(spec)
}
