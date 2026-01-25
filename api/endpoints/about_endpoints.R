# api/endpoints/about_endpoints.R
#
# This file contains all about/CMS-related endpoints for managing
# About page content with draft/publish workflow.
#
# Follows the Google R Style Guide conventions.

## -------------------------------------------------------------------##
## About CMS endpoints
## -------------------------------------------------------------------##

#* Get current user's draft or latest published content
#*
#* This endpoint retrieves the current user's draft content if it exists,
#* otherwise falls back to the latest published version. Used by the
#* CMS editor to load content for editing.
#*
#* # `Details`
#* - Requires Administrator role
#* - Returns user's active draft if available
#* - Falls back to latest published content if no draft
#* - Returns empty array if no content exists
#*
#* # `Return`
#* Returns JSON array of section objects
#*
#* @tag about
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns sections array.
#* @response 401 Unauthorized. User not authenticated.
#* @response 403 Forbidden. User lacks Administrator role.
#*
#* @get /draft
function(req, res) {
  require_role(req, res, "Administrator")

  # Try to get user's draft first
  draft_result <- db_execute_query(
    "SELECT sections_json FROM about_content WHERE user_id = ? AND status = 'draft' LIMIT 1",
    list(req$user_id)
  )

  if (nrow(draft_result) > 0) {
    # Parse JSON and return
    sections <- jsonlite::fromJSON(draft_result$sections_json[1])
    return(sections)
  }

  # No draft found, fall back to latest published
  published_result <- db_execute_query(
    "SELECT sections_json FROM about_content WHERE status = 'published' ORDER BY version DESC LIMIT 1"
  )

  if (nrow(published_result) > 0) {
    sections <- jsonlite::fromJSON(published_result$sections_json[1])
    return(sections)
  }

  # No content exists at all
  return(list())
}


#* Save draft content for current user
#*
#* This endpoint saves the provided sections as a draft for the current user.
#* Uses upsert pattern: deletes any existing draft for the user, then inserts new draft.
#*
#* # `Details`
#* - Requires Administrator role
#* - Validates sections array is not empty
#* - Replaces any existing draft for the user
#* - Uses transaction for atomicity
#*
#* # `Input`
#* - `sections`: JSON array of section objects
#*
#* # `Return`
#* Returns success message
#*
#* @tag about
#* @serializer json list(na="string")
#* @accept json
#*
#* @response 200 OK. Draft saved successfully.
#* @response 400 Bad Request. Invalid input (empty sections).
#* @response 401 Unauthorized. User not authenticated.
#* @response 403 Forbidden. User lacks Administrator role.
#* @response 500 Internal Server Error. Database operation failed.
#*
#* @put /draft
function(req, res) {
  require_role(req, res, "Administrator")

  # Parse request body
  sections <- req$argsBody$sections

  # Validate input
  if (is.null(sections) || length(sections) == 0) {
    res$status <- 400
    return(list(error = "Sections array cannot be empty"))
  }

  # Convert sections to JSON string
  sections_json <- jsonlite::toJSON(sections, auto_unbox = TRUE)

  # Use transaction for atomic upsert
  result <- tryCatch({
    db_with_transaction({
      # Delete existing draft for this user
      db_execute_statement(
        "DELETE FROM about_content WHERE user_id = ? AND status = 'draft'",
        list(req$user_id)
      )

      # Insert new draft
      db_execute_statement(
        "INSERT INTO about_content (user_id, sections_json, status) VALUES (?, ?, 'draft')",
        list(req$user_id, sections_json)
      )
    })

    list(message = "Draft saved successfully")
  }, error = function(e) {
    res$status <- 500
    return(list(error = paste("Failed to save draft:", e$message)))
  })

  result
}


#* Publish content (creates new version)
#*
#* This endpoint publishes the provided sections as a new version.
#* Calculates next version number, inserts published content,
#* and deletes user's draft.
#*
#* # `Details`
#* - Requires Administrator role
#* - Validates sections array is not empty
#* - Increments version number automatically
#* - Deletes user's draft after successful publish
#* - Uses transaction for atomicity
#*
#* # `Input`
#* - `sections`: JSON array of section objects
#*
#* # `Return`
#* Returns success message with version number
#*
#* @tag about
#* @serializer json list(na="string")
#* @accept json
#*
#* @response 200 OK. Content published successfully.
#* @response 400 Bad Request. Invalid input (empty sections).
#* @response 401 Unauthorized. User not authenticated.
#* @response 403 Forbidden. User lacks Administrator role.
#* @response 500 Internal Server Error. Database operation failed.
#*
#* @post /publish
function(req, res) {
  require_role(req, res, "Administrator")

  # Parse request body
  sections <- req$argsBody$sections

  # Validate input
  if (is.null(sections) || length(sections) == 0) {
    res$status <- 400
    return(list(error = "Sections array cannot be empty"))
  }

  # Convert sections to JSON string
  sections_json <- jsonlite::toJSON(sections, auto_unbox = TRUE)

  # Use transaction for atomic publish
  result <- tryCatch({
    db_with_transaction({
      # Get next version number
      version_result <- db_execute_query(
        "SELECT COALESCE(MAX(version), 0) + 1 AS next_version FROM about_content WHERE status = 'published'"
      )
      next_version <- version_result$next_version[1]

      # Insert new published version
      db_execute_statement(
        "INSERT INTO about_content (user_id, sections_json, status, version, published_at) VALUES (?, ?, 'published', ?, NOW())",
        list(req$user_id, sections_json, next_version)
      )

      # Delete user's draft
      db_execute_statement(
        "DELETE FROM about_content WHERE user_id = ? AND status = 'draft'",
        list(req$user_id)
      )

      # Return version number
      next_version
    })
  }, error = function(e) {
    res$status <- 500
    return(list(error = paste("Failed to publish content:", e$message)))
  })

  list(
    message = "Content published successfully",
    version = result
  )
}


#* Get latest published content (public)
#*
#* This endpoint retrieves the latest published About page content.
#* No authentication required - used by public About page.
#*
#* # `Details`
#* - No authentication required
#* - Returns latest published version
#* - Returns empty array if no published content
#*
#* # `Return`
#* Returns JSON array of section objects
#*
#* @tag about
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns sections array.
#*
#* @get /published
function() {
  # Query latest published version
  published_result <- db_execute_query(
    "SELECT sections_json FROM about_content WHERE status = 'published' ORDER BY version DESC LIMIT 1"
  )

  if (nrow(published_result) > 0) {
    sections <- jsonlite::fromJSON(published_result$sections_json[1])
    return(sections)
  }

  # No published content exists
  return(list())
}
