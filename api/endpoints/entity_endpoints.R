# api/endpoints/entity_endpoints.R
#
# All Entity-related endpoints. Bodies delegate to
# services/entity-read-endpoint-service.R (list/detail reads) and
# services/entity-submission-endpoint-service.R (create/deactivate
# orchestration) as of #346 Wave 3. `/rename` keeps calling the pre-existing
# svc_entity_rename_full() (services/entity-service.R) unchanged. `/create`'s
# publication-preparation-before-transaction block and the legacy
# current_review = FALSE approved-review gate computations stay inline on
# purpose — see entity-submission-endpoint-service.R's header comment and
# test-unit-public-approved-review-guard.R.

## -------------------------------------------------------------------##
## Entity endpoints
## -------------------------------------------------------------------##

#* Get a Cursor Pagination Object of All Entities
#*
#* Returns a cursor-paginated list of entities with sort/filter/field
#* selection, cursor pagination links, and field specifications.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sort:str Output column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#* @param fields:str Comma separated list of output columns.
#* @param page_after:str Cursor after which entries are shown.
#* @param page_size:str Page size in cursor pagination.
#* @param fspec:str Fields to generate field specification for.
#* @param compact:bool When true, push the filter to SQL and skip the
#*   global-fspec computation (count == count_filtered). For embedded callers
#*   that don't render filter dropdowns. Default false.
#*
#* @response 200 OK. A cursor pagination object with links, meta and data (entity objects).
#* @response 500 Internal server error.
#*
#* @get /
function(req,
         res,
         sort = "entity_id",
         filter = "",
         fields = "",
         page_after = 0,
         page_size = "10",
         fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details", # nolint: line_length_linter
         format = "json",
         compact = "false") {
  res$serializer <- serializers[[format]]

  entities_list <- svc_entity_list_query(
    sort = sort, filter = filter, fields = fields,
    page_after = page_after, page_size = page_size,
    fspec = fspec, compact = compact, pool = pool
  )

  if (format == "xlsx") {
    creation_date <- strftime(
      as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S"
    )
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
      str_replace_all("_api_", "")
    filename <- file.path(paste0(base_filename, "_", creation_date, ".xlsx"))

    bin <- generate_xlsx_bin(entities_list, base_filename)
    as_attachment(bin, filename)
  } else {
    entities_list
  }
}

#* Create New Entity
#*
#* Creates a new entity with review, status, publications, phenotypes, and
#* variation ontology. Supports direct approval for Curator+ callers.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param direct_approval Boolean for direct approval. Defaults to FALSE.
#*
#* @post /create
function(req, res, direct_approval = FALSE) {
  require_role(req, res, "Curator")

  create_data <- req$argsBody$create_json

  # Prepare publications (includes external GeneReviews API call). Insert
  # publications into the reference table BEFORE the atomic transaction so a
  # publication failure writes nothing and the whole request fails fast.
  publications <- NULL
  if (length(compact(create_data$review$literature)) > 0) {
    publications <- bind_rows(
      tibble::as_tibble(compact(
        create_data$review$literature$additional_references
      )),
      tibble::as_tibble(compact(
        create_data$review$literature$gene_review
      )),
      .id = "publication_type"
    ) %>%
      dplyr::select(publication_id = value, publication_type) %>%
      mutate(
        publication_type = case_when(
          publication_type == 1 ~ "additional_references",
          publication_type == 2 ~ "gene_review"
        )
      ) %>%
      unique() %>%
      arrange(publication_id) %>%
      mutate(publication_id = str_replace_all(publication_id, "\\s", "")) %>%
      rowwise() %>%
      mutate(gr_check = genereviews_from_pmid(publication_id, check = TRUE)) %>%
      ungroup() %>%
      mutate(
        publication_type = case_when(
          publication_type == "additional_references" & gr_check ~ "gene_review",
          publication_type == "gene_review" & !gr_check ~ "additional_references",
          TRUE ~ publication_type
        )
      ) %>%
      dplyr::select(-gr_check)

    # Insert publications into reference table BEFORE transaction
    # (reference data persists even if entity creation fails)
    pub_result <- tryCatch(
      new_publication(publications),
      publication_fetch_error = function(e) {
        list(status = 400,
             message = paste("Bad Request.", e$message),
             error = e$message)
      }
    )
    if (pub_result$status != 200) {
      logger::log_error(
        "Publication insert failed, aborting entity creation",
        error = pub_result$message
      )
      res$status <- pub_result$status
      return(list(
        status = pub_result$status,
        message = paste("Publication error:", pub_result$message),
        error = pub_result$error
      ))
    }
  }

  result <- svc_entity_create_finalize(
    create_data = create_data,
    publications = publications,
    direct_approval = as.logical(direct_approval),
    user_id = req$user_id,
    pool = pool
  )

  res$status <- if (result$status == 200) 201L else result$status
  result
}

#* Renames an entity by updating its disease ontology ID version.
#*
#* Renames the disease ontology of an entity (Curator+): deactivates the old
#* entity_id (replaced_by the new one) and copies review/status forward onto
#* a newly created entity_id via svc_entity_rename_full(). rename_json is
#* `list(entity = list(entity_id, hgnc_id, hpo_mode_of_inheritance_term,
#* ndd_phenotype, disease_ontology_id_version))`.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param rename_json A JSON object with the above detailed properties.
#*
#* @post /rename
function(req, res) {
  require_role(req, res, "Curator")

  result <- svc_entity_rename_full(
    rename_data = req$argsBody$rename_json,
    user_id     = req$user_id,
    pool        = pool
  )

  res$status <- if (result$status == 200) 201L else result$status
  result
}

#* Deactivate Entity
#*
#* Deactivates an existing entity (Curator+). Only mutation of is_active/
#* replaced_by is allowed; any other field change is rejected as Bad Request.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @response 200 OK. A list with status, message and entity_id.
#* @response 400 Bad Request. Submitted JSON data does not match the criteria for deactivating or is malformed.
#* @response 403 Forbidden. User does not have the required role.
#* @response 500 Internal server error.
#*
#* @post /deactivate
function(req, res) {
  require_role(req, res, "Curator")

  result <- svc_entity_deactivate_request(
    deactivate_data = req$argsBody$deactivate_json,
    deactivate_user_id = req$user_id,
    pool = pool
  )

  res$status <- result$http_status
  result$body
}


#* Get Phenotypes for Entity
#*
#* Retrieves phenotypes for entity_id. Defaults to the currently active
#* (primary + approved) review only.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id A numeric, representing the entity_id to be retrieved.
#* @param current_review A logical, if TRUE (default) returns phenotypes from
#* the currently active review only. If FALSE, returns all active phenotypes.
#*
#* @response 200 OK. A data frame with phenotype information and review metadata.
#* @response 500 Internal server error.
#*
#* @get /<sysndd_id>/phenotypes
function(sysndd_id, current_review = TRUE) {
  # Legacy "all reviews" mode is still a PUBLIC read, so it must stay
  # approved-only: gate to primary + approved review_ids so it cannot leak
  # unapproved curation (#3, Codex re-review).
  if (current_review) {
    approved_review_ids <- NULL
  } else {
    approved_review_ids <- primary_approved_reviews(pool) %>% dplyr::pull(review_id)
  }

  svc_entity_phenotypes(sysndd_id, current_review, approved_review_ids, pool)
}


#* Get Variation Ontology for Entity
#*
#* Retrieves variation ontology terms for entity_id. Defaults to the
#* currently active (primary + approved) review only.
#*
#* Each term carries a `provenance` object (#608) recording where the
#* annotation came from, or `null` when the term is curator-authored (no
#* assertion row). The `null="null"` serializer argument is load-bearing:
#* without it jsonlite renders a NULL list element as `{}` instead of `null`
#* and the curator-authored contract breaks. `na="string"` would otherwise
#* render an unrecorded numeric strength as the string "NA", so the service
#* normalizes unrecorded scalars to NULL — see
#* services/entity-variation-provenance-service.R.
#*
#* @tag entity
#* @serializer json list(na="string", null="null")
#*
#* @param sysndd_id The entity_id for which ontology should be retrieved.
#* @param current_review A logical, if TRUE (default) returns variations from
#* the currently active review only. If FALSE, returns all active variations.
#*
#* @response 200 OK. A data frame with variation ontology information, provenance and review metadata.
#* @response 500 Internal server error.
#*
#* @get /<sysndd_id>/variation
function(sysndd_id, current_review = TRUE) {
  # Legacy "all reviews" mode is still a PUBLIC read, so it must stay
  # approved-only (#3, Codex re-review).
  if (current_review) {
    approved_review_ids <- NULL
  } else {
    approved_review_ids <- primary_approved_reviews(pool) %>% dplyr::pull(review_id)
  }

  svc_entity_variation(sysndd_id, current_review, approved_review_ids, pool)
}


#* Get Suggested Variation Ontology Terms for Entity
#*
#* Retrieves the `suggested` variation-ontology assertions for entity_id, with
#* their full evidence records, so the curation form can offer them as
#* candidate terms (#608). Suggestions are NOT part of the curated set and are
#* deliberately absent from `GET /<sysndd_id>/variation`.
#*
#* DECLARATION ORDER IS LOAD-BEARING: this literal route MUST stay declared
#* before any dynamic `/<sysndd_id>/variation/<...>` route. Plumber matches in
#* declaration order, so a single-segment dynamic sibling declared first would
#* capture "suggestions" as a `vario_id` (verified empirically, and the same
#* trap that `GET /api/status/_list` hit). Locked by
#* tests/testthat/test-unit-variation-provenance-endpoints.R.
#*
#* Curation workflow data, not public content: gated at Curator. Anonymous
#* requests are forwarded by require_auth, so the handler self-gates.
#*
#* @tag entity
#* @serializer json list(na="string", null="null")
#*
#* @param sysndd_id The entity_id for which suggestions should be retrieved.
#*
#* @response 200 OK. An array of suggested assertions with their evidence (empty when there are none).
#* @response 400 Bad Request. entity id is not an integer.
#* @response 403 Forbidden. Caller is not a Curator or above.
#* @response 500 Internal server error.
#*
#* @get /<sysndd_id>/variation/suggestions
function(req, res, sysndd_id) {
  require_role(req, res, "Curator")

  svc_entity_variation_suggestions(sysndd_id, pool)
}


#* Get Variation Ontology Provenance Evidence for One Term
#*
#* Retrieves the full evidence payloads (including `evidence_json`) behind one
#* `(entity_id, vario_id, modifier_id)` assertion (#608). The compact
#* `provenance.sources` block on `GET /<sysndd_id>/variation` deliberately
#* omits these payloads to keep that hot path small.
#*
#* Public and DB-only. The entity is resolved through `ndd_entity_view` inside
#* the same statement and the assertion state is gated to the served states, so
#* a non-public entity or a suggested/rejected assertion can never surface
#* here. A missing entity and a missing assertion return the SAME 404 with the
#* same message, so the route cannot be used to probe for either.
#*
#* `vario_id` is a CURIE containing a colon (`VariO:0017`). Verified against
#* plumber 1.3.x: a raw colon routes correctly inside a single path segment,
#* but plumber does NOT percent-decode path parameters, so the service
#* URL-decodes the value and both encodings resolve identically.
#*
#* @tag entity
#* @serializer json list(na="string", null="null")
#*
#* @param sysndd_id The entity_id the assertion belongs to.
#* @param vario_id The variation-ontology CURIE, e.g. VariO:0017.
#* @param modifier_id The modifier id, e.g. 1 (present) or 5 (absent).
#*
#* @response 200 OK. The assertion identity, state and its evidence array.
#* @response 400 Bad Request. Malformed entity id, vario_id or modifier_id.
#* @response 404 Not Found. No publicly visible assertion matches.
#* @response 500 Internal server error.
#*
#* @get /<sysndd_id>/variation/<vario_id>/<modifier_id>/evidence
function(sysndd_id, vario_id, modifier_id) {
  svc_entity_variation_evidence(sysndd_id, vario_id, modifier_id, pool)
}


#* Get Clinical Synopsis for Entity
#*
#* Retrieves the clinical synopsis (primary + approved review) for entity_id.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which the clinical synopsis is to be retrieved.
#*
#* @get /<sysndd_id>/review
function(sysndd_id) {
  svc_entity_review(sysndd_id, pool)
}


#* Get Entity Status
#*
#* Retrieves the active + approved status for entity_id.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which the status is to be retrieved.
#*
#* @get /<sysndd_id>/status
function(sysndd_id) {
  svc_entity_status(sysndd_id, pool)
}


#* Get Entity Publications
#*
#* Retrieves publications for entity_id. Defaults to the currently active
#* (primary + approved) review only.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which publications are to be retrieved.
#* @param current_review A logical, if TRUE (default) returns publications from
#* the currently active review only. If FALSE, returns all reviewed publications.
#*
#* @response 200 OK. A data frame with publication information and review metadata.
#* @response 500 Internal server error.
#*
#* @get /<sysndd_id>/publications
function(sysndd_id, current_review = TRUE) {
  # Legacy "all reviews" mode is still a PUBLIC read, so it must stay
  # approved-only (#3, Codex re-review).
  if (current_review) {
    approved_review_ids <- NULL
  } else {
    approved_review_ids <- primary_approved_reviews(pool) %>% dplyr::pull(review_id)
  }

  svc_entity_publications(sysndd_id, current_review, approved_review_ids, pool)
}

## Entity endpoints
## -------------------------------------------------------------------##
