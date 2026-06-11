# services/genereviews-service.R
#
# Curator-facing GeneReviews coverage + attach service (issues #14, #46).
#
# Responsibilities:
# - svc_genereviews_existing_links(): which entities already have a GeneReviews
#   reference linked (publication_type = "gene_review"), read from approved data.
# - svc_genereviews_coverage(): merge the SysNDD gene/entity set with already
#   linked GeneReviews and (optionally) live NCBI availability into a flat
#   coverage table that flags genes lacking a GeneReviews entry (#46).
# - svc_genereviews_coverage_csv(): render that coverage table as a CSV string
#   for the "Excel-style export" requested in #46.
# - svc_genereviews_attach_to_entity(): attach a GeneReviews chapter (by PMID)
#   to an entity's primary review, reusing the existing publication model (#14).
#
# This service reads from `ndd_entity_view` (active entities with gene symbols)
# and `ndd_review_publication_join` (existing gene_review links). Live NCBI
# lookups are delegated to fetch_genereviews_availability_batch(), which is
# cached and designed for worker/admin use; coverage requests that include the
# live lookup must be gated by the caller (Curator+ endpoint).

# Load dependencies if not already in scope (test isolation).
if (!exists("fetch_genereviews_availability_batch", mode = "function")) {
  if (file.exists("functions/genereviews-lookup.R")) {
    source("functions/genereviews-lookup.R", local = TRUE)
  }
}

#' Distinct gene/entity set from the active entity view
#'
#' @return Tibble with entity_id, hgnc_id, symbol, disease_ontology_name.
#' @noRd
genereviews_entity_gene_set <- function() {
  pool %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::select(
      entity_id,
      hgnc_id,
      symbol,
      disease_ontology_name
    ) %>%
    dplyr::collect()
}

#' Existing GeneReviews references linked to entities
#'
#' Reads `gene_review`-typed rows from `ndd_review_publication_join` joined to
#' the `publication` table for the NBK accession (stored in
#' `other_publication_id` as "Bookshelf_ID:NBK...").
#'
#' @return Tibble: entity_id, publication_id (PMID), nbk_id, title.
#' @export
svc_genereviews_existing_links <- function() {
  links <- pool %>%
    dplyr::tbl("ndd_review_publication_join") %>%
    dplyr::filter(publication_type == "gene_review") %>%
    dplyr::select(entity_id, publication_id) %>%
    dplyr::distinct() %>%
    dplyr::collect()

  if (nrow(links) == 0L) {
    return(tibble::tibble(
      entity_id = integer(),
      publication_id = character(),
      nbk_id = character(),
      title = character()
    ))
  }

  pubs <- pool %>%
    dplyr::tbl("publication") %>%
    dplyr::select(publication_id, other_publication_id, Title) %>%
    dplyr::collect()

  links %>%
    dplyr::left_join(pubs, by = "publication_id") %>%
    dplyr::mutate(
      nbk_id = stringr::str_replace(
        dplyr::coalesce(other_publication_id, ""),
        "^Bookshelf_ID:",
        ""
      ),
      nbk_id = dplyr::if_else(nzchar(nbk_id), nbk_id, NA_character_),
      title = Title
    ) %>%
    dplyr::select(entity_id, publication_id, nbk_id, title)
}

#' Build the gene -> GeneReviews coverage table
#'
#' Combines the SysNDD entity/gene set, existing linked GeneReviews, and
#' (optionally) live NCBI availability into one row per entity.
#'
#' @param include_live When TRUE, performs the (cached) NCBI availability lookup
#'   over the distinct gene symbols. When FALSE, coverage reflects only what is
#'   already linked in SysNDD (cheap, no external calls).
#' @return Tibble with columns: entity_id, hgnc_id, symbol,
#'   disease_ontology_name, already_linked (logical), linked_pmid, linked_nbk_id,
#'   genereview_available (logical|NA), available_nbk_id, available_url,
#'   available_title, lookup_error (logical), needs_attention (logical).
#'   `needs_attention` is TRUE when a GeneReviews chapter is available upstream
#'   but not yet linked to the entity (the #46 "flag genes lacking an entry"
#'   signal), and is NA when live availability was not requested.
#' @export
svc_genereviews_coverage <- function(include_live = FALSE) {
  entities <- genereviews_entity_gene_set()

  empty <- tibble::tibble(
    entity_id = integer(),
    hgnc_id = character(),
    symbol = character(),
    disease_ontology_name = character(),
    already_linked = logical(),
    linked_pmid = character(),
    linked_nbk_id = character(),
    genereview_available = logical(),
    available_nbk_id = character(),
    available_url = character(),
    available_title = character(),
    lookup_error = logical(),
    needs_attention = logical()
  )

  if (nrow(entities) == 0L) {
    return(empty)
  }

  existing <- svc_genereviews_existing_links() %>%
    dplyr::group_by(entity_id) %>%
    dplyr::summarise(
      already_linked = TRUE,
      linked_pmid = paste(unique(stats::na.omit(publication_id)), collapse = ", "),
      linked_nbk_id = paste(unique(stats::na.omit(nbk_id)), collapse = ", "),
      .groups = "drop"
    )

  coverage <- entities %>%
    dplyr::left_join(existing, by = "entity_id") %>%
    dplyr::mutate(
      already_linked = dplyr::coalesce(already_linked, FALSE),
      linked_pmid = dplyr::coalesce(linked_pmid, NA_character_),
      linked_nbk_id = dplyr::coalesce(linked_nbk_id, NA_character_)
    )

  if (!isTRUE(include_live)) {
    return(coverage %>%
      dplyr::mutate(
        genereview_available = NA,
        available_nbk_id = NA_character_,
        available_url = NA_character_,
        available_title = NA_character_,
        lookup_error = FALSE,
        needs_attention = NA
      ))
  }

  availability <- fetch_genereviews_availability_batch(unique(coverage$symbol)) %>%
    dplyr::rename(
      genereview_available = has_genereview,
      available_nbk_id = nbk_id,
      available_url = url,
      available_title = title
    ) %>%
    dplyr::select(
      symbol = gene_symbol,
      genereview_available,
      available_nbk_id,
      available_url,
      available_title,
      lookup_error
    )

  coverage %>%
    dplyr::left_join(availability, by = "symbol") %>%
    dplyr::mutate(
      lookup_error = dplyr::coalesce(lookup_error, FALSE),
      needs_attention = isTRUE_vec(genereview_available) & !already_linked
    )
}

#' Vectorised isTRUE helper (treats NA as FALSE)
#' @noRd
isTRUE_vec <- function(x) {
  !is.na(x) & x
}

#' Render a coverage table to a CSV string
#'
#' @param coverage Tibble from svc_genereviews_coverage().
#' @return Single CSV string (RFC 4180 quoting via readr).
#' @export
svc_genereviews_coverage_csv <- function(coverage) {
  if (is.null(coverage) || nrow(coverage) == 0L) {
    coverage <- svc_genereviews_coverage(include_live = FALSE)[0, ]
  }
  readr::format_csv(coverage)
}

#' Attach a GeneReviews chapter (by PMID) to an entity's primary review
#'
#' Reuses the existing publication model: ensures the GeneReviews PMID exists in
#' the `publication` table (inserting GeneReviews metadata via new_publication()
#' when missing), then links it to the entity's primary review in
#' `ndd_review_publication_join` with publication_type = "gene_review".
#'
#' Validation:
#' - PMID must be numeric (with or without the "PMID:" prefix).
#' - The PMID must correspond to a GeneReviews chapter (verified via
#'   genereviews_from_pmid(check = TRUE)); non-GeneReviews PMIDs are rejected.
#' - The entity must have a primary review to attach to.
#' - Re-attaching an already-linked PMID is a no-op success (idempotent).
#'
#' @param entity_id Integer entity ID.
#' @param pmid GeneReviews chapter PMID (string, with or without "PMID:").
#' @return List(status, message). status 200 on success/idempotent no-op,
#'   400 on invalid input, 404 when no primary review exists.
#' @export
svc_genereviews_attach_to_entity <- function(entity_id, pmid) {
  entity_id <- suppressWarnings(as.integer(entity_id))
  if (is.na(entity_id)) {
    return(list(status = 400, message = "Invalid entity_id."))
  }

  pmid_num <- normalize_pubmed_ids(pmid)
  if (length(pmid_num) != 1L || !grepl("^[0-9]+$", pmid_num)) {
    return(list(status = 400, message = "Invalid PMID."))
  }
  publication_id <- paste0("PMID:", pmid_num)

  # Confirm this PMID is genuinely a GeneReviews chapter before touching the DB.
  is_genereview <- tryCatch(
    isTRUE(genereviews_from_pmid(pmid_num, check = TRUE)),
    error = function(e) FALSE
  )
  if (!is_genereview) {
    return(list(
      status = 400,
      message = "PMID does not correspond to a GeneReviews chapter."
    ))
  }

  # Find the entity's primary review (attach point for curated references).
  reviews <- review_find_by_entity(entity_id)
  if (nrow(reviews) == 0L) {
    return(list(status = 404, message = "No review found for this entity."))
  }
  primary <- reviews[reviews$is_primary == 1, , drop = FALSE]
  review_row <- if (nrow(primary) > 0L) primary[1, ] else reviews[1, ]
  review_id <- review_row$review_id

  # Idempotency: already linked?
  already <- pool %>%
    dplyr::tbl("ndd_review_publication_join") %>%
    dplyr::filter(
      entity_id == !!entity_id,
      publication_id == !!publication_id,
      publication_type == "gene_review"
    ) %>%
    dplyr::count() %>%
    dplyr::collect() %>%
    dplyr::pull(n)

  if (length(already) > 0L && already[1] > 0L) {
    return(list(
      status = 200,
      message = "GeneReviews reference already linked to this entity.",
      review_id = review_id,
      publication_id = publication_id
    ))
  }

  publications <- tibble::tibble(
    publication_id = publication_id,
    publication_type = "gene_review"
  )

  # Ensure the publication row exists (inserts GeneReviews metadata if new).
  new_pub_result <- new_publication(publications)
  if (!is.null(new_pub_result$status) && new_pub_result$status != 200) {
    return(list(
      status = new_pub_result$status,
      message = new_pub_result$message %||% "Failed to register GeneReviews publication."
    ))
  }

  # Link the publication to the entity's primary review.
  link_result <- put_post_db_pub_con(
    method = "POST",
    publications = publications,
    entity_id = entity_id,
    review_id = review_id
  )

  list(
    status = link_result$status,
    message = if (link_result$status == 200) {
      "OK. GeneReviews reference attached to entity."
    } else {
      link_result$message %||% "Failed to attach GeneReviews reference."
    },
    review_id = review_id,
    publication_id = publication_id
  )
}
