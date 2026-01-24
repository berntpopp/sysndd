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
    select(term = value, query_date)

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
            "https://hpo.jax.org/api/hpo/term/",
            URLencode(term_input_id, reserved = TRUE)
          )
        )

        hpo_term_name <- tidyr::as_tibble(hpo_term_response$details$name) %>%
          dplyr::select(hpo_mode_of_inheritance_term_name = value)

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
            "https://hpo.jax.org/api/hpo/term/",
            URLencode(term_input_id, reserved = TRUE)
          )
        )

        hpo_term_definition <- tidyr::as_tibble(hpo_term_response$details$definition) %>%
          dplyr::select(hpo_mode_of_inheritance_term_definition = value)

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
        hpo_term_response <- jsonlite::fromJSON(
          paste0(
            "https://hpo.jax.org/api/hpo/term/",
            URLencode(term_input_id, reserved = TRUE)
          )
        )

        hpo_term_children_count <- length(hpo_term_response$relations$children)

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
        hpo_term_response <- jsonlite::fromJSON(
          paste0(
            "https://hpo.jax.org/api/hpo/term/",
            URLencode(term_input_id, reserved = TRUE)
          )
        )

        hpo_term_children <- tidyr::as_tibble(hpo_term_response$relations$children)

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
hpo_all_children_from_term_api <- function(term_input, all_children_list = list()) {
  children_list <- hpo_children_from_term_api(term_input)

  # Combine all_children_list and term_input
  all_children_list <- c(all_children_list, term_input)

  if (length(children_list) != 0) {
    for (p in children_list$ontologyId) {
      # Update all_children_list with each recursive call
      all_children_list <- hpo_all_children_from_term_api(p, all_children_list)
    }
  }

  # If no more children are found, convert the list to a tibble and remove duplicates
  if (length(children_list) == 0) {
    all_children_tibble <- tidyr::as_tibble(unlist(all_children_list)) %>%
      unique()
    return(all_children_tibble)
  } else {
    return(all_children_list)
  }
}
