# api/endpoints/re_review_endpoints.R
#
# This file contains all Re-review-related endpoints, extracted from
# the original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible.
#
# Route decorators/formals and the Reviewer/Curator role gates stay
# route-local here (behavior-preserving, #346). Handler bodies delegate to
# services/re-review-query-endpoint-service.R (read-only handlers) and
# services/re-review-workflow-endpoint-service.R (lifecycle/batch/
# assignment/recalculation handlers), which in turn call the pre-existing
# domain services in services/re-review-service.R and
# services/re-review-refusal-service.R.

# Note: db-helpers.R is sourced by start_sysndd_api.R before endpoints are loaded
# Functions like db_execute_statement are available in the global environment

## -------------------------------------------------------------------##
## Re-review endpoints
## -------------------------------------------------------------------##

#* Submit a Re-Review Entry
#*
#* Allows users with roles (Administrator, Curator, Reviewer) to submit a
#* re-review entry in the DB. Updates the re_review_entity_connect table.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put submit
function(req, res) {
  require_role(req, res, "Reviewer")

  svc_re_review_submit(req$argsBody$submit_json)
}

#* Unsubmit a Re-Review Entry
#*
#* Allows (Administrator, Curator) to revert a re-review entry to
#* un-submitted. Sets re_review_submitted = 0 for that re_review_entity_id.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put unsubmit/<re_review_id>
function(req, res, re_review_id) {
  require_role(req, res, "Curator")

  svc_re_review_unsubmit(re_review_id)
}

#* Refuse / decline a Re-Review Entry (needs specialist)
#*
#* Reviewer+ declines a complex / out-of-scope item (issue #54). Sets
#* re_review_refused = 1 with the optional body reason, refusing user, and
#* timestamp; the item leaves the reviewer queue and curator approve queue and
#* surfaces in the curator "refused" view. Curated status/review unchanged.
#* The optional reason is body-only: `{ "reason": "..." }`, never a query string.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put refuse/<re_review_id>
function(req, res, re_review_id) {
  require_role(req, res, "Reviewer")

  svc_re_review_refuse(re_review_id, req$user_id, req$argsBody$reason)
}

#* Clear a Re-Review refusal (curator triage)
#*
#* Curator+ reverses a refusal so the item re-enters the normal re-review flow
#* (issue #54). 200 on success, problem+json 404 when the item is not found.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put refuse/clear/<re_review_id>
function(req, res, re_review_id) {
  require_role(req, res, "Curator")

  svc_re_review_refuse_clear(re_review_id)
}

#* Approve a Re-Review Entry
#*
#* Allows (Administrator, Curator) to approve a re-review entry. Depending
#* on status_ok and review_ok, updates DB fields.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_id The ID of the re-review entry.
#* @param status_ok Whether the status is approved.
#* @param review_ok Whether the review is approved.
#*
#* @put approve/<re_review_id>
function(req, res, re_review_id, status_ok = FALSE, review_ok = FALSE) {
  require_role(req, res, "Curator")

  svc_re_review_approve(re_review_id, status_ok, review_ok, req$user_id, res, pool)
}

#* Get Re-Review Overview Table
#*
#* Returns the re-review overview table for the authenticated user, filtered
#* by `filter`/`curate`/`refused`. Admin/Curators can see curated or
#* uncurated sets. Reviewers see only unsubmitted, non-refused sets assigned
#* to them. When `refused = TRUE` (Curator+), the table lists items a
#* re-reviewer declined for specialist attention (issue #54) — these are
#* excluded from both the reviewer queue and the curator approve queue.
#* Supports cursor pagination for large re-review lists.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param filter Condition for the re-review data.
#* @param curate Boolean indicating whether to see curated or not.
#* @param refused Boolean. When TRUE (Curator+), list refused items only.
#* @param page_after Cursor after which entries are shown (default: 0)
#* @param page_size Page size in cursor pagination (default: "all")
#*
#* @get table
function(req,
         res,
         filter = "equals(re_review_approved,0)",
         curate = FALSE,
         refused = FALSE,
         page_after = 0,
         page_size = "all") {
  curate <- as.logical(curate)
  refused <- as.logical(refused)

  # Refused mode is a curator surface; otherwise curate -> Curator+,
  # plain reviewer queue -> Reviewer+.
  if (curate || refused) {
    require_role(req, res, "Curator")
  } else {
    require_role(req, res, "Reviewer")
  }

  re_review_user_list <- svc_re_review_table_query(filter, curate, refused, req$user_id, pool)
  svc_re_review_paginate(re_review_user_list, page_size, page_after)
}

#* Request New Re-Review Batch
#*
#* Allows the authenticated user to request a new batch of entities for
#* re-review by emailing curators with the user info. 200 OK if the email
#* was sent, else error.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @get batch/apply
function(req, res) {
  require_role(req, res, "Reviewer")

  svc_re_review_batch_apply(req$user_id, pool)
}

#* Assign New Re-Review Batch
#*
#* Allows Admin/Curator to assign a new batch of entities for re-review to a
#* specified user. Computes the next batch, inserts into
#* re_review_assignment table. Success if assigned, or error if user
#* doesn’t exist.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param user_id The ID of the user to assign the batch to.
#*
#* @put batch/assign
function(req, res, user_id) {
  require_role(req, res, "Curator")

  svc_re_review_batch_assign(as.integer(user_id), res, pool)
}

#* Unassign Re-Review Batch
#*
#* Allows Admin/Curator to unassign a re-review batch based on the provided
#* re_review_batch. Removes the assignment from re_review_assignment table.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_batch The ID of the re-review batch to unassign.
#*
#* @delete batch/unassign
function(req, res, re_review_batch) {
  require_role(req, res, "Curator")

  svc_re_review_batch_unassign(re_review_batch, res, pool)
}

#* Get Re-Review Assignment Table
#*
#* Returns summary statistics of all re-review batch assignments - entities
#* reviewed, etc.
#*
#* # `Return`
#* Summary table of re-review batch assignments, or an error if not admin/curator.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param limit:int Maximum number of items per page (default: 50, max: 500)
#* @param offset:int Number of items to skip (default: 0)
#*
#* @get assignment_table
function(req, res, limit = 50, offset = 0) {
  require_role(req, res, "Curator")

  # Preserve legacy response shape (ManageReReview.vue reads response.data
  # directly as an array via Array.isArray(data)). limit/offset remain in
  # the signature for the pagination contract.
  svc_re_review_assignment_table_endpoint(pool)
}

## -------------------------------------------------------------------##
## Re-review Batch Management Endpoints (Dynamic)
## -------------------------------------------------------------------##

#* Create a new Re-Review Batch dynamically
#*
#* Creates a batch based on provided criteria (date range, gene list, status, disease).
#* Optionally assigns to a user during creation.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @post batch/create
function(req, res) {
  require_role(req, res, "Curator")

  result <- svc_re_review_batch_create(req$argsBody, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}

#* Preview matching entities for batch criteria
#*
#* Returns entities that would be included in a batch without creating it.
#* Useful for reviewing criteria before committing.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @post batch/preview
function(req, res) {
  require_role(req, res, "Curator")

  result <- svc_re_review_batch_preview(req$argsBody, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}

#* List entities available for manual re-review assignment
#*
#* Returns a searchable, paginated list of entities not currently connected to
#* an active re-review batch. Use this for manual pick UI; batch/preview remains
#* gene-atomic and batch-size limited for dynamic batch creation.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param q Optional search string.
#* @param page One-based page number.
#* @param page_size Number of entities per page, capped at 100.
#*
#* @get entities/available
function(req, res, q = "", page = 1L, page_size = 25L) {
  require_role(req, res, "Curator")

  result <- svc_re_review_entities_available(q, page, page_size, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}

#* Reassign Re-Review Batch to different user
#*
#* Changes the assigned user for an existing batch.
#* Can reassign at any time (per CONTEXT decision).
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_batch The batch ID to reassign
#* @param user_id The new user ID to assign to
#*
#* @put batch/reassign
function(req, res, re_review_batch, user_id) {
  require_role(req, res, "Curator")

  result <- svc_re_review_batch_reassign(re_review_batch, user_id, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}

#* Archive (soft delete) a Re-Review Batch
#*
#* Removes batch assignment, preserving entity connect records for audit.
#* Only allowed for batches not yet completed (per CONTEXT decision).
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_batch The batch ID to archive
#*
#* @put batch/archive
function(req, res, re_review_batch) {
  require_role(req, res, "Curator")

  result <- svc_re_review_batch_archive(re_review_batch, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}

#* Assign specific entities/genes to a user for re-review
#*
#* Creates a new batch containing only the specified entities and assigns to user.
#* Enables gene-specific assignment where admin selects specific genes for specific user.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put entities/assign
function(req, res) {
  require_role(req, res, "Curator")

  result <- svc_re_review_entities_assign(req$argsBody, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}

#* Recalculate batch entity membership based on updated criteria
#*
#* Re-assigns entities to a batch based on new criteria.
#* Only allowed for batches not yet assigned (unassigned batches only).
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @put batch/recalculate
function(req, res) {
  require_role(req, res, "Curator")

  result <- svc_re_review_batch_recalculate(req$argsBody, pool)

  if (result$status != 200) {
    res$status <- result$status
  }

  result
}
