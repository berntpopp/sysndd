# Status Service Layer for SysNDD API
# Provides business logic for entity status operations
#
# Functions accept pool as parameter (dependency injection)
# Handles status creation, updates, and re-review workflow

#' Create new entity status
#'
#' Creates a new status record for an entity with optional re-review integration.
#' Validates required fields and integrates with re-review workflow if requested.
#'
#' @param status_data List or tibble with entity_id, category_id, and optional fields
#' @param pool Database connection pool
#' @param re_review Logical - whether this is a re-review status (default: FALSE)
#' @return List with status code, message, and newly created status_id
#'
#' @details
#' Required fields in status_data:
#' - entity_id: Integer entity ID
#' - category_id: Integer category ID
#'
#' Optional fields:
#' - problematic: Logical/Integer flag (defaults to 0)
#' - status_user_id: Integer user ID who created status
#'
#' If re_review is TRUE:
#' - Updates re_review_entity_connect table
#' - Sets re_review_status_saved = 1
#' - Links status_id to re-review record
#'
#' @examples
#' \dontrun{
#' result <- service_status_create(
#'   list(entity_id = 5, category_id = 2, problematic = 0),
#'   pool,
#'   re_review = FALSE
#' )
#' # Returns: list(status = 200, message = "OK. Entry created.", entry = 42)
#' }
#'
#' @export
service_status_create <- function(status_data, pool, re_review = FALSE) {
  # Validate input
  if (!("category_id" %in% names(status_data))) {
    stop("category_id is required")
  }

  if (!("entity_id" %in% names(status_data))) {
    stop("entity_id is required for status creation")
  }

  # Convert to tibble and remove null values
  status_tibble <- purrr::compact(status_data) %>%
    tibble::as_tibble() %>%
    select(-any_of("status_id"))

  # Get connection for transaction
  conn <- pool::poolCheckout(pool)
  on.exit(pool::poolReturn(conn), add = TRUE)

  tryCatch(
    {
      # Insert status record
      DBI::dbAppendTable(conn, "ndd_entity_status", status_tibble)

      # Get newly created status_id
      status_id <- DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() as status_id")$status_id

      # Update re-review if requested
      if (re_review) {
        DBI::dbExecute(
          conn,
          "UPDATE re_review_entity_connect
         SET re_review_status_saved = 1, status_id = ?
         WHERE entity_id = ?",
          params = list(status_id, status_data$entity_id)
        )

        logger::log_info("Status created with re-review",
          status_id = status_id,
          entity_id = status_data$entity_id
        )
      } else {
        logger::log_info("Status created",
          status_id = status_id,
          entity_id = status_data$entity_id
        )
      }

      list(
        status = 200,
        message = "OK. Entry created.",
        entry = status_id
      )
    },
    error = function(e) {
      logger::log_error("Failed to create status",
        error = e$message,
        entity_id = status_data$entity_id
      )
      stop(paste("Failed to create status:", e$message))
    }
  )
}


#' Update existing entity status
#'
#' Updates an existing status record with new field values.
#' Prevents changing entity_id to maintain referential integrity.
#'
#' @param status_data List or tibble with status_id and fields to update
#' @param pool Database connection pool
#' @return List with status code, message, and updated status_id
#'
#' @details
#' Required fields in status_data:
#' - status_id: Integer status ID to update
#'
#' Updatable fields:
#' - category_id: Integer category ID
#' - problematic: Logical/Integer flag
#' - status_approved: Logical/Integer approval flag
#' - approving_user_id: Integer user ID who approved
#' - is_active: Logical/Integer active flag
#'
#' Protected fields (ignored if provided):
#' - entity_id: Cannot change entity association
#' - status_id: Cannot change primary key
#'
#' @examples
#' \dontrun{
#' result <- service_status_update(
#'   list(status_id = 42, category_id = 3, problematic = 1),
#'   pool
#' )
#' # Returns: list(status = 200, message = "OK. Entry updated.", entry = 42)
#' }
#'
#' @export
service_status_update <- function(status_data, pool) {
  # Validate input
  if (!("status_id" %in% names(status_data))) {
    stop("status_id is required for status update")
  }

  # Convert to tibble and remove protected fields
  status_tibble <- purrr::compact(status_data) %>%
    tibble::as_tibble()

  # Extract status_id for WHERE clause
  status_id_for_update <- status_tibble$status_id[1]

  # Remove entity_id and status_id from update data
  status_received_data <- status_tibble %>%
    select(-any_of(c("entity_id", "status_id")))

  if (ncol(status_received_data) == 0) {
    stop("No valid fields to update")
  }

  # Convert logical to integer for database compatibility
  status_received_data <- status_received_data %>%
    mutate(across(where(is.logical), as.integer))

  # Build parameterized UPDATE query
  col_names <- colnames(status_received_data)
  set_clause <- paste0(col_names, " = ?", collapse = ", ")
  update_query <- paste0("UPDATE ndd_entity_status SET ", set_clause, " WHERE status_id = ?")

  # Prepare params: all column values + status_id for WHERE
  params_list <- as.list(status_received_data[1, ])
  params_list <- c(params_list, list(status_id_for_update))

  # Get connection for update
  conn <- pool::poolCheckout(pool)
  on.exit(pool::poolReturn(conn), add = TRUE)

  tryCatch(
    {
      # Execute update
      affected_rows <- DBI::dbExecute(conn, update_query, params = params_list)

      logger::log_info("Status updated",
        status_id = status_id_for_update,
        affected_rows = affected_rows
      )

      list(
        status = 200,
        message = "OK. Entry updated.",
        entry = status_id_for_update
      )
    },
    error = function(e) {
      logger::log_error("Failed to update status",
        error = e$message,
        status_id = status_id_for_update
      )
      stop(paste("Failed to update status:", e$message))
    }
  )
}
