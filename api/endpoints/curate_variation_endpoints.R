# api/endpoints/curate_variation_endpoints.R
#
# The cross-entity variation-ontology curation queue (#612 Phase 6).
#
# Mounted at /api/curate/variation. A new prefix rather than an extension of
# /api/review, because this is entity-scoped curation triage rather than review
# CRUD, and because the #608 design named the page /curate/variation-suggestions.
#
# Thin by design: role gate, parameter forwarding, nothing else. Validation and
# every statement live in services/curate-variation-suggestion-service.R (read)
# and services/curate-variation-apply-service.R (write).
#
# DECLARATION ORDER IS LOAD-BEARING. `/suggestions/confirm` and
# `/suggestions/dismiss` are declared BEFORE `/suggestions`, and any future
# dynamic sibling must come after all three. Plumber matches in declaration
# order, so a single-segment dynamic route declared first would capture
# "suggestions" as its parameter -- the same trap `GET /api/status/_list` hit,
# and the reason the entity-scoped suggestions route carries the same note.
#
# Curation workflow data, not public content: every route is gated at Curator.
# Anonymous requests are forwarded by require_auth, so each handler self-gates.

library(plumber)


#* Confirm Machine-Derived Variation-Ontology Assertions
#*
#* Records a curator's explicit confirmation for a batch of queued assertions.
#*
#* Server-side, each item must be `active_unconfirmed` AND currently SERVED by
#* the entity's primary approved review. Confirming a term the entity does not
#* serve would assert a curator reading of evidence for something nobody
#* publishes; adding it instead would be a review write, which belongs to
#* `review_write_mutate()` and never to this surface. Skipped items are
#* returned with their reason rather than silently dropped.
#*
#* @tag curate
#* @serializer json list(na="string", null="null")
#*
#* @param req The request object; `items` is read from the JSON body.
#*
#* @response 200 OK. `{requested, applied, skipped}`.
#* @response 400 Bad Request. Malformed items, an empty batch, over 100 entries, or no acting user.
#* @response 403 Forbidden. Caller is not a Curator or above.
#* @response 500 Internal server error.
#*
#* @post /suggestions/confirm
function(req, res) {
  require_role(req, res, "Curator")

  svc_curate_variation_apply(
    items = req$argsBody$items,
    action = "confirm",
    review_user_id = req$user_id,
    db = pool
  )
}


#* Dismiss Suggested Variation-Ontology Assertions
#*
#* Records a curator's rejection of a batch of candidate terms.
#*
#* Server-side, each item must be `suggested` AND NOT currently served. A
#* `rejected` assertion drops out of the public read's state filter, so
#* rejecting a SERVED term would make the entity card render it as
#* curator-authored -- the exact inversion this feature exists to prevent.
#* Removing a served term is a review write and belongs to the curation form.
#*
#* @tag curate
#* @serializer json list(na="string", null="null")
#*
#* @param req The request object; `items` is read from the JSON body.
#*
#* @response 200 OK. `{requested, applied, skipped}`.
#* @response 400 Bad Request. Malformed items, an empty batch, or over 100 entries.
#* @response 403 Forbidden. Caller is not a Curator or above.
#* @response 500 Internal server error.
#*
#* @post /suggestions/dismiss
function(req, res) {
  require_role(req, res, "Curator")

  svc_curate_variation_apply(
    items = req$argsBody$items,
    action = "dismiss",
    review_user_id = req$user_id,
    db = pool
  )
}


#* List Unconfirmed Machine-Derived Variation-Ontology Assertions
#*
#* One page of the curation queue: assertions in `active_unconfirmed` or
#* `suggested`, with the evidence behind each, whether the entity currently
#* SERVES the term, and whether a curator review has since displaced the import
#* that wrote it (`moved`).
#*
#* DB-only and cheap: two statements per request (a count and a page), never one
#* per row. Entities resolve through `ndd_entity_view` inside the statement, so a
#* non-public entity can never appear. Every filter value is bound.
#*
#* `evidence_json` is deliberately absent from this listing -- the full records
#* stay one click away on the entity, which is where the decision needing them is
#* made.
#*
#* @tag curate
#* @serializer json list(na="string", null="null")
#*
#* @param state Optional: `active_unconfirmed` or `suggested`.
#* @param source_key Optional evidence source key, e.g. `clinvar`.
#* @param max_strength Optional exact 0-4 evidence strength.
#* @param moved Optional `true` to show only assertions whose import review no longer serves.
#* @param q Optional gene symbol or entity id.
#* @param sort Optional: `strength_desc` (default), `strength_asc`, `entity_asc`.
#* @param page Optional 1-based page number (default 1).
#* @param page_size Optional rows per page (default 25, capped at 100).
#*
#* @response 200 OK. `{meta: {page, page_size, total}, data: [...]}`.
#* @response 400 Bad Request. An unrecognised filter or sort value.
#* @response 403 Forbidden. Caller is not a Curator or above.
#* @response 500 Internal server error.
#*
#* @get /suggestions
function(req, res, state = NULL, source_key = NULL, max_strength = NULL,
         moved = NULL, q = NULL, sort = NULL, page = NULL, page_size = NULL) {
  require_role(req, res, "Curator")

  params <- svc_curate_variation_suggestion_params(
    state = state, source_key = source_key, max_strength = max_strength,
    moved = moved, q = q, sort = sort, page = page, page_size = page_size
  )

  svc_curate_variation_suggestions(params, pool)
}
