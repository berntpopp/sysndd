# api/functions/disease-ontology-mapping-repository.R
#
# Read-only repository for disease cross-ontology mappings (WP-D).
# Public DB-only read path — no external provider calls.
#
# Depends on: pool global (runtime); no other API files required for the
# pure function disease_mapping_group_rows().

# ---------------------------------------------------------------------------
# Inline allowlist order (mirrors MONDO_TARGET_ALLOWLIST in mondo-index-builder.R).
# Defined here so the pure function is testable without sourcing that file.
# ---------------------------------------------------------------------------
.DISEASE_MAPPING_PREFIX_ORDER <- c(
  "MONDO", "Orphanet", "OMIM", "DOID", "UMLS", "MedGen", "NCIT", "GARD", "EFO"
)

# ---------------------------------------------------------------------------
# Pure helper: group mapping rows by prefix in canonical allowlist order
# ---------------------------------------------------------------------------

#' Group disease mapping rows by target prefix
#'
#' Pure function (no DB access). Converts a flat tibble of mapping rows into
#' the grouped list structure used by the API response, ordered by the
#' canonical allowlist.
#'
#' @param rows A tibble/data.frame with columns:
#'   target_prefix, target_id, target_label, predicate, source.
#' @param prefix_order Character vector defining the group order.
#'   Defaults to the canonical MONDO_TARGET_ALLOWLIST order.
#' @return A list with two elements:
#'   - `mappings`: named list, one entry per prefix group (in order),
#'     each a list of items with fields id, label, predicate, source.
#'   - `mondo_id`: the first target_id from the MONDO group, or NULL.
#' @export
disease_mapping_group_rows <- function(
  rows,
  prefix_order = .DISEASE_MAPPING_PREFIX_ORDER
) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(list(mappings = list(), mondo_id = NULL))
  }

  # Determine which prefixes are present, ordered by allowlist.
  # Drop any prefix not in the allowlist — the public response must only
  # contain allowlisted ontologies.
  present_prefixes <- prefix_order[prefix_order %in% rows$target_prefix]
  ordered_prefixes <- present_prefixes

  if (length(ordered_prefixes) == 0L) {
    return(list(mappings = list(), mondo_id = NULL))
  }

  mappings <- vector("list", length(ordered_prefixes))
  names(mappings) <- ordered_prefixes

  for (pfx in ordered_prefixes) {
    group <- rows[rows$target_prefix == pfx, , drop = FALSE]
    mappings[[pfx]] <- lapply(seq_len(nrow(group)), function(i) {
      list(
        id        = group$target_id[[i]],
        label     = group$target_label[[i]],
        predicate = group$predicate[[i]],
        source    = group$source[[i]]
      )
    })
  }

  # Extract mondo_id: first target_id from the MONDO group
  mondo_id <- if ("MONDO" %in% ordered_prefixes && length(mappings$MONDO) > 0L) {
    mappings$MONDO[[1L]]$id
  } else {
    NULL
  }

  list(mappings = mappings, mondo_id = mondo_id)
}

# ---------------------------------------------------------------------------
# DB read: mappings for a disease_ontology_id
# ---------------------------------------------------------------------------

#' Fetch disease cross-ontology mappings for a disease_ontology_id
#'
#' Queries disease_ontology_mapping (is_active = 1) and disease_ontology_set
#' for metadata. Returns a structured list ready for the API response.
#'
#' @param disease_ontology_id Character. CURIE of the disease
#'   (e.g., "OMIM:618524").
#' @param conn DBI connection. If NULL, uses the global `pool`.
#' @return A list with elements: disease_ontology_id, disease_ontology_name,
#'   mondo_id, release_version, status ("current" or "missing"),
#'   mappings (named list).
#' @export
disease_mapping_for_disease <- function(disease_ontology_id, conn = NULL) {
  conn_used <- if (is.null(conn)) pool else conn

  # 1. Fetch disease metadata from disease_ontology_set
  meta_rows <- DBI::dbGetQuery(
    conn_used,
    paste0(
      "SELECT disease_ontology_name ",
      "FROM disease_ontology_set ",
      "WHERE disease_ontology_id = ? ",
      "LIMIT 1"
    ),
    params = unname(list(disease_ontology_id))
  )

  disease_ontology_name <- if (nrow(meta_rows) > 0L) {
    meta_rows$disease_ontology_name[[1L]]
  } else {
    NA_character_
  }

  # 2. Fetch active mapping rows
  mapping_rows <- DBI::dbGetQuery(
    conn_used,
    paste0(
      "SELECT target_prefix, target_id, target_label, predicate, source, release_version ",
      "FROM disease_ontology_mapping ",
      "WHERE disease_ontology_id = ? AND is_active = 1 ",
      "LIMIT 1000"
    ),
    params = unname(list(disease_ontology_id))
  )

  if (nrow(mapping_rows) == 0L) {
    return(list(
      disease_ontology_id   = disease_ontology_id,
      disease_ontology_name = disease_ontology_name,
      mondo_id              = NULL,
      release_version       = NULL,
      status                = "missing",
      mappings              = list()
    ))
  }

  # 3. Group rows
  grouped <- disease_mapping_group_rows(mapping_rows)

  # 4. Extract release_version from rows (single contract field)
  release_version <- if (!is.null(mapping_rows$release_version)) {
    ver <- mapping_rows$release_version[!is.na(mapping_rows$release_version)]
    if (length(ver) > 0L) ver[[1L]] else NULL
  } else {
    NULL
  }

  list(
    disease_ontology_id   = disease_ontology_id,
    disease_ontology_name = disease_ontology_name,
    mondo_id              = grouped$mondo_id,
    release_version       = release_version,
    status                = "current",
    mappings              = grouped$mappings
  )
}

# ---------------------------------------------------------------------------
# DB read: mappings for an entity (resolves via ndd_entity_view)
# ---------------------------------------------------------------------------

#' Fetch disease cross-ontology mappings for a SysNDD entity
#'
#' Resolves entity_id -> disease_ontology_id_version via the public
#' ndd_entity_view surface, then looks up the base disease_ontology_id and
#' delegates to disease_mapping_for_disease().
#'
#' Only entities present in ndd_entity_view (active, public) are resolved.
#' Inactive or non-public entities return a "missing" response without leaking
#' mapping data.
#'
#' @param entity_id Integer entity ID.
#' @param conn DBI connection. If NULL, uses the global `pool`.
#' @return A list in the same shape as disease_mapping_for_disease().
#' @export
disease_mapping_for_entity <- function(entity_id, conn = NULL) {
  conn_used <- if (is.null(conn)) pool else conn

  # Resolve entity to disease_ontology_id_version via public view
  entity_rows <- DBI::dbGetQuery(
    conn_used,
    paste0(
      "SELECT disease_ontology_id_version ",
      "FROM ndd_entity_view ",
      "WHERE entity_id = ? ",
      "LIMIT 1"
    ),
    params = unname(list(entity_id))
  )

  if (nrow(entity_rows) == 0L) {
    # Entity not found in public view — return missing without leaking data
    return(list(
      disease_ontology_id   = NA,
      disease_ontology_name = NA,
      mondo_id              = NULL,
      release_version       = NULL,
      status                = "missing",
      mappings              = list()
    ))
  }

  disease_ontology_id_version <- entity_rows$disease_ontology_id_version[[1L]]

  # Resolve disease_ontology_id_version to base disease_ontology_id
  dos_rows <- DBI::dbGetQuery(
    conn_used,
    paste0(
      "SELECT disease_ontology_id ",
      "FROM disease_ontology_set ",
      "WHERE disease_ontology_id_version = ? ",
      "LIMIT 1"
    ),
    params = unname(list(disease_ontology_id_version))
  )

  if (nrow(dos_rows) == 0L) {
    return(list(
      disease_ontology_id   = NA,
      disease_ontology_name = NA,
      mondo_id              = NULL,
      release_version       = NULL,
      status                = "missing",
      mappings              = list()
    ))
  }

  base_disease_ontology_id <- dos_rows$disease_ontology_id[[1L]]

  # Delegate to the disease-level lookup
  disease_mapping_for_disease(base_disease_ontology_id, conn = conn_used)
}
