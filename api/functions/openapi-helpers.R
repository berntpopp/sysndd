# api/functions/openapi-helpers.R
#
# OpenAPI specification enhancement utilities.
# Follows Single Responsibility Principle - only handles OpenAPI enhancement.
# Follows Open/Closed Principle - extend via JSON files, not code changes.
#
# Created: 2026-02-02
# Purpose: Modular OpenAPI schema loading and enhancement

#' Load JSON Files from Directory
#'
#' Loads all JSON files from a directory and merges them into a single list.
#'
#' @param dir_path Path to directory containing JSON files
#' @return Named list of merged JSON contents
#' @keywords internal
load_openapi_json_files <- function(dir_path, recursive = TRUE) {
  if (!dir.exists(dir_path)) {
    return(list())
  }

  json_files <- list.files(dir_path, pattern = "\\.json$", full.names = TRUE, recursive = recursive)
  # Exclude files starting with underscore (like _all_inferred_schemas.json)
  json_files <- json_files[!grepl("^_", basename(json_files))]

  result <- list()

  for (file in json_files) {
    tryCatch({
      content <- jsonlite::fromJSON(file, simplifyVector = FALSE)
      result <- c(result, content)
    }, error = function(e) {
      warning(sprintf("Failed to load OpenAPI JSON file %s: %s", file, e$message))
    })
  }

  result
}


#' Merge Lists Recursively
#'
#' Merges two lists, with second list taking precedence for conflicts.
#'
#' @param base Base list
#' @param overlay List to merge on top
#' @return Merged list
#' @keywords internal
merge_openapi_lists <- function(base, overlay) {
  if (is.null(base)) return(overlay)
  if (is.null(overlay)) return(base)

  for (name in names(overlay)) {
    if (name %in% names(base) && is.list(base[[name]]) && is.list(overlay[[name]])) {
      base[[name]] <- merge_openapi_lists(base[[name]], overlay[[name]])
    } else {
      base[[name]] <- overlay[[name]]
    }
  }

  base
}


#' Create Standard Error Response
#'
#' Factory function for RFC 9457 compliant error responses.
#' Follows DRY - single definition used for all error codes.
#'
#' @param description Human-readable description
#' @return OpenAPI response object with $ref to ProblemDetails
#' @keywords internal
create_error_response <- function(description) {
  list(
    description = description,
    content = list(
      "application/problem+json" = list(
        schema = list(`$ref` = "#/components/schemas/ProblemDetails")
      )
    )
  )
}


#' Get Standard Error Responses
#'
#' Returns pre-defined error response definitions for common HTTP status codes.
#' These are added to components/responses for $ref usage.
#'
#' @return Named list of error response definitions
#' @export
get_standard_error_responses <- function() {
  list(
    "BadRequest" = create_error_response(
      "Bad Request - Invalid input parameters"
    ),
    "Unauthorized" = create_error_response(
      "Unauthorized - Authentication required"
    ),
    "Forbidden" = create_error_response(
      "Forbidden - Insufficient permissions"
    ),
    "NotFound" = create_error_response(
      "Not Found - Resource does not exist"
    ),
    "InternalServerError" = create_error_response(
      "Internal Server Error - Unexpected error occurred"
    )
  )
}


#' Add Error Responses to Endpoint
#'
#' Adds standard error responses to an endpoint if not already present.
#' Only adds responses that are relevant (doesn't add 401 to public endpoints).
#'
#' @param endpoint_spec The endpoint specification object
#' @param include_auth Whether to include 401/403 responses (default TRUE)
#' @return Modified endpoint specification
#' @keywords internal
add_error_responses_to_endpoint <- function(endpoint_spec, include_auth = TRUE) {
  if (is.null(endpoint_spec$responses)) {
    endpoint_spec$responses <- list()
  }

  # Always replace error responses with our $ref versions

# This ensures RFC 9457 ProblemDetails schema is used consistently
  # (Plumber may have added default responses with generic schemas)
  endpoint_spec$responses[["400"]] <- list(
    `$ref` = "#/components/responses/BadRequest"
  )
  endpoint_spec$responses[["500"]] <- list(
    `$ref` = "#/components/responses/InternalServerError"
  )

  # Auth-related responses (skip for public endpoints)
  if (include_auth) {
    endpoint_spec$responses[["401"]] <- list(
      `$ref` = "#/components/responses/Unauthorized"
    )
    endpoint_spec$responses[["403"]] <- list(
      `$ref` = "#/components/responses/Forbidden"
    )
  } else {
    # Remove auth responses if they exist on public endpoints
    endpoint_spec$responses[["401"]] <- NULL
    endpoint_spec$responses[["403"]] <- NULL
  }

  # Add 404 for all endpoints
  endpoint_spec$responses[["404"]] <- list(
    `$ref` = "#/components/responses/NotFound"
  )

  endpoint_spec
}


#' Map Inferred Schema to Endpoint Path and Method
#'
#' Converts an inferred schema name (e.g., "api_health_GET") to
#' the corresponding OpenAPI path and method by matching against
#' existing paths in the spec.
#'
#' @param inferred_from The x-inferred-from value (e.g., "api_health_GET")
#' @param available_paths Vector of available paths in the OpenAPI spec
#' @return List with path and method, or NULL if cannot parse
#' @keywords internal
parse_inferred_schema_path <- function(inferred_from, available_paths = NULL) {
  if (is.null(inferred_from) || !nzchar(inferred_from)) {
    return(NULL)
  }

  # Pattern: api_segment1_segment2_..._METHOD
  # Split by underscore and extract method (last part)
  parts <- strsplit(inferred_from, "_")[[1]]
  if (length(parts) < 2) {
    return(NULL)
  }

  method <- tolower(parts[length(parts)])
  if (!method %in% c("get", "post", "put", "delete", "patch")) {
    return(NULL)
  }

  # Get path portion (without method)
  path_portion <- paste(parts[-length(parts)], collapse = "_")

  # If we have available paths, find the best match by normalizing both
  if (!is.null(available_paths) && length(available_paths) > 0) {
    # Normalize the schema path portion: replace _ with /
    normalized_schema <- tolower(gsub("_", "/", path_portion))

    for (avail_path in available_paths) {
      # Skip parameterized paths
      if (grepl("\\{", avail_path)) {
        next
      }
      # Normalize the available path: remove leading /, replace _ with /, remove trailing /
      normalized_avail <- tolower(gsub("_", "/", avail_path))
      normalized_avail <- gsub("^/|/$", "", normalized_avail)
      normalized_schema_clean <- gsub("^/|/$", "", normalized_schema)

      if (normalized_avail == normalized_schema_clean) {
        return(list(path = avail_path, method = method))
      }
    }
  }

  # Fallback: simple underscore to slash conversion
  path_parts <- parts[-length(parts)]
  path <- paste0("/", paste(path_parts, collapse = "/"), "/")
  list(path = path, method = method)
}


#' Apply Inferred Schemas to 200 Responses
#'
#' Maps inferred schemas to their corresponding endpoints' 200 responses.
#' Uses the x-inferred-from field to determine which endpoint to update.
#'
#' @param spec The OpenAPI specification object
#' @return Modified specification with 200 responses referencing schemas
#' @keywords internal
apply_inferred_schemas_to_responses <- function(spec) {
  if (is.null(spec$components$schemas)) {
    return(spec)
  }

  # Get all available paths for matching
  available_paths <- names(spec$paths)

  applied_count <- 0

  for (schema_name in names(spec$components$schemas)) {
    schema <- spec$components$schemas[[schema_name]]
    inferred_from <- schema[["x-inferred-from"]]

    if (is.null(inferred_from)) {
      next
    }

    # Parse with available paths for fuzzy matching
    parsed <- parse_inferred_schema_path(inferred_from, available_paths)
    if (is.null(parsed)) {
      next
    }

    matched_path <- parsed$path
    method <- parsed$method

    # Verify path and method exist
    if (!is.null(spec$paths[[matched_path]]) && !is.null(spec$paths[[matched_path]][[method]])) {
      # Update the 200 response to reference this schema
      if (!is.null(spec$paths[[matched_path]][[method]]$responses[["200"]])) {
        spec$paths[[matched_path]][[method]]$responses[["200"]]$content[["application/json"]]$schema <- list(
          `$ref` = paste0("#/components/schemas/", schema_name)
        )
        applied_count <- applied_count + 1
      }
    }
  }

  message("[apply_inferred_schemas] Applied ", applied_count, " schema references to 200 responses")
  spec
}


#' Enhance OpenAPI Specification
#'
#' Main function to enhance Plumber-generated OpenAPI spec with:
#' - Component schemas from JSON files
#' - Standard error response definitions
#' - Endpoint-specific enhancements
#'
#' Follows Open/Closed Principle: extend via config files, not code changes.
#'
#' @param spec The OpenAPI specification object from Plumber
#' @param config_dir Base directory for OpenAPI config files
#'   (default: "config/openapi")
#' @param add_error_responses Whether to add standard error responses
#'   to all endpoints (default: TRUE)
#' @param public_paths Vector of path prefixes that don't require auth
#'   (e.g., "/api/health")
#' @return Enhanced specification object
#' @export
enhance_openapi_spec <- function(
  spec,
  config_dir = "config/openapi",
  add_error_responses = TRUE,
  public_paths = c("/api/health", "/api/version", "/api/about")
) {
  # Check if this spec has already been enhanced (avoid redundant processing)
  if (!is.null(spec$components$schemas$ProblemDetails)) {
    message("[enhance_openapi_spec] Spec already enhanced, skipping")
    return(spec)
  }

  message("[enhance_openapi_spec] Starting enhancement...")

  # 1. Load and merge component schemas
  schemas_dir <- file.path(config_dir, "schemas")
  message("[enhance_openapi_spec] Loading schemas from: ", schemas_dir)
  schemas <- load_openapi_json_files(schemas_dir)
  message("[enhance_openapi_spec] Loaded ", length(schemas), " schemas: ", paste(names(schemas), collapse=", "))
  if (length(schemas) > 0) {
    if (is.null(spec$components$schemas)) {
      spec$components$schemas <- list()
    }
    spec$components$schemas <- merge_openapi_lists(
      spec$components$schemas,
      schemas
    )
    message("[enhance_openapi_spec] Merged schemas into spec")
  }

  # 1b. Apply inferred schemas to 200 responses
  spec <- apply_inferred_schemas_to_responses(spec)

  message("[enhance_openapi_spec] add_error_responses = ", add_error_responses)

  # 2. Add standard error response definitions to components
  if (add_error_responses) {
    if (is.null(spec$components$responses)) {
      spec$components$responses <- list()
    }
    std_responses <- get_standard_error_responses()
    message("[enhance_openapi_spec] Adding ", length(std_responses), " standard error responses")
    spec$components$responses <- merge_openapi_lists(
      spec$components$responses,
      std_responses
    )
    message("[enhance_openapi_spec] components$responses now has: ", paste(names(spec$components$responses), collapse=", "))
  }

  # 3. Load and merge custom response definitions
  responses_dir <- file.path(config_dir, "responses")
  responses <- load_openapi_json_files(responses_dir)
  if (length(responses) > 0) {
    spec$components$responses <- merge_openapi_lists(
      spec$components$responses,
      responses
    )
  }

  # 4. Load and apply endpoint-specific enhancements
  endpoints_dir <- file.path(config_dir, "endpoints")
  endpoints <- load_openapi_json_files(endpoints_dir)
  for (path in names(endpoints)) {
    if (!is.null(spec$paths[[path]])) {
      spec$paths[[path]] <- merge_openapi_lists(
        spec$paths[[path]],
        endpoints[[path]]
      )
    }
  }

  # 5. Add error responses to all endpoints
  # Auth responses (401/403) only added to write methods (POST, PUT, DELETE, PATCH)
  # unless the path is in public_paths (then no auth for any method)
  if (add_error_responses) {
    path_count <- 0
    write_methods <- c("post", "put", "delete", "patch")
    for (path in names(spec$paths)) {
      for (method in names(spec$paths[[path]])) {
        # Skip non-operation keys
        if (method %in% c("parameters", "servers", "summary", "description")) {
          next
        }
        # Determine if auth responses should be included:
        # - Excluded for paths in public_paths (all methods)
        # - Excluded for GET/HEAD/OPTIONS (read-only methods)
        # - Included for write methods (POST, PUT, DELETE, PATCH)
        is_public_path <- any(sapply(public_paths, function(p) startsWith(path, p)))
        is_write_method <- tolower(method) %in% write_methods
        include_auth <- !is_public_path && is_write_method

        spec$paths[[path]][[method]] <- add_error_responses_to_endpoint(
          spec$paths[[path]][[method]],
          include_auth = include_auth
        )
        path_count <- path_count + 1
      }
    }
    message("[enhance_openapi_spec] Added error responses to ", path_count, " operations")
  }

  message("[enhance_openapi_spec] Final spec components: ", paste(names(spec$components), collapse=", "))
  spec
}
