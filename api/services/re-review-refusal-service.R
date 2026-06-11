# Re-Review Refusal Service for SysNDD API
#
# Issue #54: a re-reviewer can DECLINE/REFUSE a re-review item that is too
# complex or out of scope, flagging it for specialist/curator attention
# instead of forcing a review.
#
# Refusal is a distinct state (re_review_refused = 1), NOT "approved" and NOT
# "rejected". A refused item:
#   - leaves the refusing reviewer's active queue,
#   - leaves the curator approve queue,
#   - surfaces in the curator "refused / needs specialist" view.
#
# It never alters the curated SysNDD status or review classification.
#
# Extracted into its own file (rather than growing the ~930-line
# re-review-service.R) per the AGENTS.md file-size guidance.

#' Map a refusal-service result status to a classed RFC 9457 error
#'
#' Endpoints call this to translate a non-200 service result into the
#' appropriate `stop_for_*` classed error so the mounted error handler emits
#' problem+json. Only `error_400/401/403/404/500` classes exist, so the 409
#' "already refused" case maps to a 400 with a clear message. No-op on 200.
#'
#' @param result List returned by the refusal service (`status`, `message`).
#' @keywords internal
stop_for_rereview_result_error <- function(result) {
  if (result$status == 200) {
    return(invisible(NULL))
  }
  if (result$status == 404) {
    stop_for_not_found(result$message)
  }
  # 400 and 409 (already refused) both surface as a 400 bad request.
  stop_for_bad_request(result$message)
}

#' Record a re-review refusal for a single re-review item
#'
#' Marks the `re_review_entity_connect` row as refused, recording the
#' optional reason, the refusing user, and the timestamp. Refusing clears
#' `re_review_submitted` so the item cannot also sit in the approve queue.
#'
#' @param re_review_entity_id Integer id of the re_review_entity_connect row.
#' @param user_id Integer id of the refusing re-reviewer (req$user_id).
#' @param reason Optional free-text reason (trimmed; capped at 1000 chars).
#' @param pool Database connection pool (or transaction connection).
#' @return List with status, message, and entry (re_review_entity_id).
#'   status 404 when the row does not exist, 409 when already refused.
#'
#' @examples
#' \dontrun{
#' refuse_re_review_entity(42L, user_id = 7L, reason = "Needs specialist", pool)
#' }
#'
#' @export
refuse_re_review_entity <- function(re_review_entity_id, user_id, reason = NULL, pool) {
  re_review_entity_id <- as.integer(re_review_entity_id)
  user_id <- as.integer(user_id)

  if (is.na(re_review_entity_id)) {
    return(list(status = 400, message = "re_review_entity_id must be an integer"))
  }
  if (is.na(user_id)) {
    return(list(status = 400, message = "A valid user_id is required to record a refusal"))
  }

  # Normalize the optional reason: trim, NULL out empties, cap to column width.
  reason <- if (is.null(reason)) NA_character_ else trimws(as.character(reason)[1])
  if (!is.na(reason) && !nzchar(reason)) {
    reason <- NA_character_
  }
  if (!is.na(reason) && nchar(reason) > 1000L) {
    reason <- substr(reason, 1L, 1000L)
  }

  existing <- db_execute_query(
    "SELECT re_review_entity_id, re_review_refused, re_review_approved
     FROM re_review_entity_connect
     WHERE re_review_entity_id = ?",
    list(re_review_entity_id),
    conn = pool
  )

  if (nrow(existing) == 0) {
    logger::log_warn("Re-review refusal failed: item not found",
      re_review_entity_id = re_review_entity_id
    )
    return(list(status = 404, message = "Re-review item not found"))
  }

  if (isTRUE(as.integer(existing$re_review_refused[1]) == 1L)) {
    logger::log_warn("Re-review refusal skipped: already refused",
      re_review_entity_id = re_review_entity_id
    )
    return(list(status = 409, message = "Re-review item is already marked as refused"))
  }

  # IMPORTANT: unname() the params for the anonymous ? placeholders.
  db_execute_statement(
    "UPDATE re_review_entity_connect
        SET re_review_refused = 1,
            re_review_refusal_comment = ?,
            re_review_refused_user_id = ?,
            re_review_refused_date = UTC_TIMESTAMP(),
            re_review_submitted = 0
      WHERE re_review_entity_id = ?",
    unname(list(
      if (is.na(reason)) NA else reason,
      user_id,
      re_review_entity_id
    )),
    conn = pool
  )

  logger::log_info("Re-review item refused",
    re_review_entity_id = re_review_entity_id,
    refused_by = user_id,
    has_reason = !is.na(reason)
  )

  list(
    status = 200,
    message = "Re-review item refused and flagged for specialist attention",
    entry = list(re_review_entity_id = re_review_entity_id)
  )
}


#' Clear a re-review refusal (curator/admin action)
#'
#' Reverses a refusal so the item can re-enter the normal re-review flow.
#' Intended for curators triaging the "refused / needs specialist" surface.
#'
#' @param re_review_entity_id Integer id of the re_review_entity_connect row.
#' @param pool Database connection pool (or transaction connection).
#' @return List with status, message, and entry (re_review_entity_id).
#'   status 404 when the row does not exist.
#'
#' @export
clear_re_review_refusal <- function(re_review_entity_id, pool) {
  re_review_entity_id <- as.integer(re_review_entity_id)

  if (is.na(re_review_entity_id)) {
    return(list(status = 400, message = "re_review_entity_id must be an integer"))
  }

  existing <- db_execute_query(
    "SELECT re_review_entity_id FROM re_review_entity_connect WHERE re_review_entity_id = ?",
    list(re_review_entity_id),
    conn = pool
  )

  if (nrow(existing) == 0) {
    return(list(status = 404, message = "Re-review item not found"))
  }

  db_execute_statement(
    "UPDATE re_review_entity_connect
        SET re_review_refused = 0,
            re_review_refusal_comment = NULL,
            re_review_refused_user_id = NULL,
            re_review_refused_date = NULL
      WHERE re_review_entity_id = ?",
    list(re_review_entity_id),
    conn = pool
  )

  logger::log_info("Re-review refusal cleared", re_review_entity_id = re_review_entity_id)

  list(
    status = 200,
    message = "Re-review refusal cleared",
    entry = list(re_review_entity_id = re_review_entity_id)
  )
}
