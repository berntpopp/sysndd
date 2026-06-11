# api/endpoints/metadata_endpoints.R
#
# Administrator-gated CRUD for SysNDD-managed curation controlled vocabularies
# (issue #32). Mounted at /api/metadata via mount_endpoint() so classed errors
# map to RFC 9457 problem+json.
#
# Vocabularies (slug -> table):
#   modifier            -> modifier_list                     (full CRUD)
#   status_category     -> ndd_entity_status_categories_list (full CRUD)
#   inheritance         -> mode_of_inheritance_list          (edit + activate)
#   variation_ontology  -> variation_ontology_list           (edit + activate)
#
# Reads (GET) are Administrator-only here because the admin view shows inactive
# rows and raw lifecycle columns; the public curation dropdowns keep using the
# existing /api/list/* endpoints.
#
# Writes are body-only JSON (AGENTS.md body-only invariant). The whole JSON
# object is the payload; there is no query-string write transport.

# Read the parsed JSON body as a flat named list, tolerating plumber's two
# accessors. Returns an empty list when no body was supplied.
.metadata_request_body <- function(req) {
  body <- req$body
  if (is.null(body) || length(body) == 0) {
    body <- req$argsBody
  }
  if (is.null(body)) {
    return(list())
  }
  as.list(body)
}

## -------------------------------------------------------------------##
## Vocabulary catalog
## -------------------------------------------------------------------##

#* List the managed metadata vocabularies and their editability.
#*
#* Returns the descriptor catalog so the admin UI can render one tab/table per
#* vocabulary and know which support create/delete versus activate-only edits.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag metadata
#* @serializer json list(na="string")
#* @response 200 OK. Returns the vocabulary catalog.
#* @get /
function(req, res) {
  require_role(req, res, "Administrator")
  registry <- metadata_vocabulary_registry()
  vocabularies <- lapply(registry, function(d) {
    list(
      slug = d$slug,
      label = d$label,
      table = d$table,
      pk = d$pk,
      pk_type = d$pk_type,
      editable = d$editable,
      managed = d$managed,
      fields = d$fields,
      has_is_active = d$has_is_active,
      has_sort = d$has_sort
    )
  })
  list(data = unname(vocabularies))
}

## -------------------------------------------------------------------##
## Per-vocabulary list
## -------------------------------------------------------------------##

#* List all rows of a managed vocabulary (includes inactive entries).
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag metadata
#* @serializer json list(na="string")
#* @param slug The vocabulary slug (modifier, status_category, inheritance, variation_ontology).
#* @response 200 OK. Returns the vocabulary rows and metadata.
#* @response 404 Unknown vocabulary slug.
#* @get /<slug>
function(req, res, slug) {
  require_role(req, res, "Administrator")
  svc_metadata_list(slug, pool)
}

## -------------------------------------------------------------------##
## Create
## -------------------------------------------------------------------##

#* Create a new entry in a SysNDD-managed vocabulary.
#*
#* Only the fully SysNDD-managed vocabularies (modifier, status_category)
#* accept new entries. Anchored vocabularies (inheritance, variation_ontology)
#* return 400 because their terms come from an external ontology.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag metadata
#* @serializer json list(na="string")
#* @accept json
#* @param slug The vocabulary slug.
#* @response 201 Created.
#* @response 400 Validation failed or vocabulary is not creatable.
#* @post /<slug>
function(req, res, slug) {
  require_role(req, res, "Administrator")
  body <- .metadata_request_body(req)
  result <- svc_metadata_create(slug, body, pool)
  res$status <- result$status
  result
}

## -------------------------------------------------------------------##
## Update
## -------------------------------------------------------------------##

#* Update an existing vocabulary entry.
#*
#* SysNDD-managed vocabularies allow editing all curated fields plus the
#* is_active / sort lifecycle columns. Anchored vocabularies allow editing the
#* curated display fields and the is_active flag, but not the ontology term id.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag metadata
#* @serializer json list(na="string")
#* @accept json
#* @param slug The vocabulary slug.
#* @param id The primary-key value of the entry to update.
#* @response 200 OK. Entry updated.
#* @response 400 Validation failed.
#* @response 404 Vocabulary or entry not found.
#* @put /<slug>/<id>
function(req, res, slug, id) {
  require_role(req, res, "Administrator")
  body <- .metadata_request_body(req)
  result <- svc_metadata_update(slug, id, body, pool)
  res$status <- result$status
  result
}

## -------------------------------------------------------------------##
## Delete (soft-delete with in-use guard)
## -------------------------------------------------------------------##

#* Soft-delete (deactivate) a vocabulary entry, blocking when it is in use.
#*
#* A value still referenced by curation data returns 400; the admin should
#* deactivate via update instead. An unused value is deactivated
#* (is_active = 0) rather than hard-deleted so logical references stay valid.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag metadata
#* @serializer json list(na="string")
#* @param slug The vocabulary slug.
#* @param id The primary-key value of the entry to delete.
#* @response 200 OK. Entry deactivated.
#* @response 400 Entry is in use or vocabulary is not deletable.
#* @response 404 Vocabulary or entry not found.
#* @delete /<slug>/<id>
function(req, res, slug, id) {
  require_role(req, res, "Administrator")
  result <- svc_metadata_delete(slug, id, pool)
  res$status <- result$status
  result
}
