# functions/hpo-functions.R

require(jsonlite) # Load the jsonlite package before using the functions
require(tidyverse) # Load the tidyverse package before using the functions
require(ontologyIndex) # Load the ontologyIndex package before using the functions

#### This file holds analyses functions for HPO request
#' Retrieve the HPO children terms for a given HPO term ID.
#'
#' This function retrieves the immediate children terms of a specified term
#' from the Human Phenotype Ontology (HPO). It uses the `ontologyIndex` package
#' to interact with the ontology and the `tidyr` package to format the results.
#'
#' @param term_input_id The HPO term ID for which to retrieve the children terms.
#'   This should be a valid HPO term ID string.
#'
#' @details The function starts by querying the ontology for the children of the
#'   given term using `get_term_property()`. The result is then transformed into
#'   a tibble. Additionally, the current system date is added as an attribute
#'   to each term, representing the date of the query.
#'
#' @importFrom ontologyIndex get_term_property
#' @importFrom tidyr as_tibble
#'
#' @return A tibble with two columns:
#'   - `term`: Contains the HPO children terms corresponding to the input HPO term ID.
#'   - `query_date`: Contains the date when the query was made.
#'
#' @examples
#' \dontrun{
#'   # Load the Human Phenotype Ontology (HPO) before using the function
#'   # Example usage of the function:
#'   hpo_children_from_term("HP:0000001")
#' }
#'
#' @export
hpo_children_from_term <- function(term_input_id, hpo_input = hpo_ontology) {
  # Query the ontology for children of the given term
  children_terms <- get_term_property(ontology = hpo_input, property = "children", term = term_input_id)

  # Convert the result into a tibble and add the current query date
  children_tibble <- children_terms %>%
    tidyr::as_tibble() %>%
    mutate(query_date = Sys.Date()) %>%
    dplyr::select(term = value, query_date)

  return(children_tibble)
}


#' Retrieve all HPO descendants and the term itself from term ID.
#'
#' @param term_input_id The HPO term ID for which to retrieve all children terms.
#' @param all_children_list A list to accumulate all children terms. Initial call should be empty.
#' @return A tibble with unique HPO children terms and the query date, including nested children,
#'   corresponding to the input HPO term ID.
#' @examples
#' \dontrun{
#' # Load the Human Phenotype Ontology (HPO) before using the function
#' # Example usage of the function with an empty list as the initial call:
#' hpo_all_children_from_term("HP:0000001")
#' }
#' @export
hpo_all_children_from_term <- function(term_input_id, hpo_input = hpo_ontology, all_children_list = tibble()) {
  # Retrieve the immediate children of the current term
  children_tibble <- hpo_children_from_term(term_input_id, hpo_input)

  # Add the current term to the results
  all_children_list <- bind_rows(all_children_list, tibble(term = term_input_id, query_date = Sys.Date()))

  # If there are children, recursively get their children
  if (nrow(children_tibble) > 0) {
    for (child_id in children_tibble$term) {
      all_children_list <- hpo_all_children_from_term(child_id, hpo_input, all_children_list)
    }
  }

  # Return only unique rows
  return(distinct(all_children_list))
}


#' Retrieve HPO name from term ID
#'
#' This function retrieves the HPO name corresponding to a given HPO term ID.
#'
#' @param term_input_id The HPO term ID for which to retrieve the HPO name.
#'
#' @importFrom jsonlite fromJSON
#' @importFrom magrittr %>%
#' @importFrom dplyr select
#' @importFrom tidyr as_tibble
#'
#' @return A tibble with the HPO name corresponding to the input HPO term ID.
#'
#' @examples
#' hpo_name_from_term("HP:1234567")
#'
#' @export
hpo_name_from_term <- function(term_input_id) {
  retries <- 3 # Number of retries before giving up
  retry_delay <- 5 # Delay in seconds between retries

  for (attempt in 1:retries) {
    tryCatch(
      {
        hpo_term_response <- jsonlite::fromJSON(
          paste0(
            "https://ontology.jax.org/api/hp/terms/",
            URLencode(term_input_id, reserved = TRUE)
          )
        )

        term_name <- hpo_term_response$name
        if (is.null(term_name) || length(term_name) == 0) term_name <- NA_character_
        hpo_term_name <- tibble::tibble(
          hpo_mode_of_inheritance_term_name = as.character(term_name)[1]
        )

        return(hpo_term_name)
      },
      error = function(e) {
        if (attempt < retries) {
          message("Retrying after error:", conditionMessage(e))
          Sys.sleep(retry_delay)
        } else {
          stop("Failed after multiple retries:", conditionMessage(e))
        }
      }
    )
  }
}


#' Retrieve HPO definition from term ID
#'
#' This function retrieves the HPO definition corresponding to a given HPO term ID.
#'
#' @param term_input_id The HPO term ID for which to retrieve the HPO definition.
#'
#' @importFrom jsonlite fromJSON
#' @importFrom magrittr %>%
#' @importFrom dplyr select
#' @importFrom tidyr as_tibble
#'
#' @return A tibble with the HPO definition corresponding to the input HPO term ID.
#'
#' @examples
#' hpo_definition_from_term("HP:1234567")
#'
#' @export
hpo_definition_from_term <- function(term_input_id) {
  retries <- 3 # Number of retries before giving up
  retry_delay <- 5 # Delay in seconds between retries

  for (attempt in 1:retries) {
    tryCatch(
      {
        hpo_term_response <- jsonlite::fromJSON(
          paste0(
            "https://ontology.jax.org/api/hp/terms/",
            URLencode(term_input_id, reserved = TRUE)
          )
        )

        term_definition <- hpo_term_response$definition
        if (is.null(term_definition) || length(term_definition) == 0) term_definition <- ""
        hpo_term_definition <- tibble::tibble(
          hpo_mode_of_inheritance_term_definition = as.character(term_definition)[1]
        )

        return(hpo_term_definition)
      },
      error = function(e) {
        if (attempt < retries) {
          message("Retrying after error:", conditionMessage(e))
          Sys.sleep(retry_delay)
        } else {
          stop("Failed after multiple retries:", conditionMessage(e))
        }
      }
    )
  }
}


#' Retrieve count of HPO children from term ID
#'
#' This function retrieves the count of HPO children terms for a given HPO term ID.
#'
#' @param term_input_id The HPO term ID for which to retrieve the count of children.
#'
#' @importFrom jsonlite fromJSON
#' @importFrom magrittr %>%
#' @importFrom dplyr select
#' @importFrom tidyr as_tibble
#'
#' @return An integer representing the count of HPO children terms.
#'
#' @examples
#' hpo_children_count_from_term("HP:1234567")
#'
#' @export
hpo_children_count_from_term <- function(term_input_id) {
  retries <- 3 # Number of retries before giving up
  retry_delay <- 5 # Delay in seconds between retries

  for (attempt in 1:retries) {
    tryCatch(
      {
        hpo_term_children <- jsonlite::fromJSON(
          paste0(
            "https://ontology.jax.org/api/hp/terms/",
            URLencode(term_input_id, reserved = TRUE),
            "/children"
          )
        )

        hpo_term_children_count <- if (is.data.frame(hpo_term_children)) {
          nrow(hpo_term_children)
        } else {
          length(hpo_term_children)
        }

        return(hpo_term_children_count)
      },
      error = function(e) {
        if (attempt < retries) {
          message("Retrying after error:", conditionMessage(e))
          Sys.sleep(retry_delay)
        } else {
          stop("Failed after multiple retries:", conditionMessage(e))
        }
      }
    )
  }
}


#' This function retrieves the HPO children terms for a given HPO term ID.
#'
#' @param term_input_id The HPO term ID for which to retrieve the children terms.
#'
#' @importFrom jsonlite fromJSON
#' @importFrom magrittr %>%
#' @importFrom dplyr select
#' @importFrom tidyr as_tibble
#'
#' @return A tibble with the HPO children terms corresponding to the input HPO term ID.
#'
#' @examples
#' hpo_children_from_term_api("HP:1234567")
#'
#' @export
hpo_children_from_term_api <- function(term_input_id) {
  retries <- 3 # Number of retries before giving up
  retry_delay <- 5 # Delay in seconds between retries

  for (attempt in 1:retries) {
    tryCatch(
      {
        hpo_term_children_response <- jsonlite::fromJSON(
          paste0(
            "https://ontology.jax.org/api/hp/terms/",
            URLencode(term_input_id, reserved = TRUE),
            "/children"
          )
        )

        hpo_term_children <- tidyr::as_tibble(hpo_term_children_response)

        return(hpo_term_children)
      },
      error = function(e) {
        if (attempt < retries) {
          message("Retrying after error:", conditionMessage(e))
          Sys.sleep(retry_delay)
        } else {
          stop("Failed after multiple retries:", conditionMessage(e))
        }
      }
    )
  }
}


#' Retrieve all HPO descendants and the term itself from term ID
#'
#' This function retrieves all the HPO children terms, including nested children,
#' for a given HPO term ID.
#'
#' @param term_input The HPO term ID for which to retrieve all children terms.
#' @param all_children_list A list to accumulate all children terms. Should be empty at the initial call.
#'
#' @return A tibble with all the HPO children terms, including nested children,
#'   corresponding to the input HPO term ID.
#'
#' @examples
#' hpo_all_children_from_term_api("HP:1234567", list())
#'
#' @export
hpo_all_children_from_term_api <- function(term_input, all_children_list = list(),
                                           timeout_seconds = 30) {
  # The current JAX ontology API exposes a /descendants endpoint that returns
  # the full transitive descendant set in a single request, so this no longer
  # recursively walks one HTTP call per term (against the retired hpo.jax.org
  # API). The request is bounded (req_timeout + one retry) so a stalled ontology
  # API cannot hang a worker job. On any failure OR an empty/malformed response
  # we emit a warning() — a silent fall-back to seed-only would re-introduce the
  # exact under-capture bug the OMIM-NDD descendant expansion fixes, so it must
  # be observable in worker logs. Returns the seed term plus all descendants.
  desc_url <- paste0(
    "https://ontology.jax.org/api/hp/terms/",
    URLencode(term_input, reserved = TRUE),
    "/descendants"
  )
  desc_ids <- tryCatch({
    req <- httr2::request(desc_url)
    req <- httr2::req_timeout(req, timeout_seconds)
    req <- httr2::req_retry(req, max_tries = 2)
    parsed <- httr2::resp_body_json(httr2::req_perform(req), simplifyVector = TRUE)
    raw_ids <- if (is.data.frame(parsed)) parsed[["id"]] else if (is.list(parsed)) parsed[["id"]] else parsed
    clean <- trimws(as.character(raw_ids))
    clean <- clean[!is.na(clean) & nzchar(clean)]
    if (length(clean) == 0) {
      warning(sprintf(
        "hpo_all_children_from_term_api: no descendants parsed for %s (unexpected response shape?); using seed-only",
        term_input
      ), call. = FALSE)
    }
    clean
  }, error = function(e) {
    warning(sprintf(
      "hpo_all_children_from_term_api: /descendants fetch failed for %s (%s); using seed-only",
      term_input, conditionMessage(e)
    ), call. = FALSE)
    character(0)
  })

  tidyr::as_tibble(unique(c(unlist(all_children_list), term_input, desc_ids)))
}
