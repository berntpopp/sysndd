# api/endpoints/disease_mapping_endpoints.R
#
# Public, DB-only read endpoint: GET /api/disease/mappings
# Returns cross-ontology mappings for a SysNDD disease.
# No external provider calls (cheap-route; guarded by test-unit-cheap-route-isolation.R).

#* Get disease cross-ontology mappings
#*
#* Returns grouped cross-ontology mappings for a SysNDD disease,
#* looked up either by entity_id or disease_ontology_id.
#* Exactly one of the two params is required.
#*
#* @tag disease
#* @serializer json list(na="null")
#*
#* @param entity_id Integer entity ID (from ndd_entity_view public surface).
#* @param disease_ontology_id CURIE of the disease (e.g., "OMIM:618524").
#*
#* @response 200 OK. Returns mapping object with status "current" or "missing".
#* @response 400 Bad Request. Exactly one param required.
#*
#* @get /mappings
function(req, res, entity_id = NULL, disease_ontology_id = NULL) {
  # Unwrap Plumber array-scalars
  entity_id <- if (is.null(entity_id)) NULL else entity_id[[1]]
  disease_ontology_id <- if (is.null(disease_ontology_id)) NULL else disease_ontology_id[[1]]

  has_entity <- !is.null(entity_id) && !is.na(entity_id) && nchar(as.character(entity_id)) > 0
  has_disease <- !is.null(disease_ontology_id) &&
    !is.na(disease_ontology_id) &&
    nchar(as.character(disease_ontology_id)) > 0

  if (has_entity == has_disease) {
    stop_for_bad_request("Exactly one of entity_id or disease_ontology_id is required.")
  }

  if (has_entity) {
    entity_id_int <- suppressWarnings(as.integer(entity_id))
    if (is.na(entity_id_int)) stop_for_bad_request("entity_id must be an integer.")
    disease_mapping_for_entity(entity_id_int)
  } else {
    disease_mapping_for_disease(as.character(disease_ontology_id))
  }
}
