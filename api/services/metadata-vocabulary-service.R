# services/metadata-vocabulary-service.R
#
# Service layer for the Admin "Manage Metadata" CRUD surface (issue #32).
#
# Responsibilities:
#   - Validate request payloads (presence, type, length) and raise classed
#     RFC 9457 errors (stop_for_bad_request / stop_for_not_found) so the
#     endpoint sub-router maps them to problem+json.
#   - Enforce per-vocabulary editability rules:
#       * "sysndd"  vocabularies   -> create / update / soft-delete
#       * "anchored" vocabularies  -> update curated fields + activate only;
#                                     no create, no delete (terms come from an
#                                     external ontology).
#   - Guard deletes with an in-use reference check, blocking with a 400 when a
#     value is still referenced by curation data (soft-delete instead).
#
# All functions take a `pool`/`conn` for dependency injection so tests can
# pass a transaction connection (with_test_db_transaction()).
#
# `svc_metadata_*` prefix avoids shadowing repository functions in the global
# environment (AGENTS.md service-prefix invariant).

# Column length ceilings mirrored from the base schema so we fail fast with a
# 400 instead of a silent MySQL truncation / 500.
.SVC_METADATA_MAX_LEN <- list(
  modifier_name = 15L,
  category = 15L,
  hpo_mode_of_inheritance_term_name = 100L,
  hpo_mode_of_inheritance_term_definition = 1000L,
  inheritance_filter = 20L,
  inheritance_short_text = 5L,
  vario_name = 100L,
  definition = 1000L
)

#' Resolve a vocabulary descriptor or stop with a 404.
#'
#' @param slug Vocabulary slug from the route.
#' @return Descriptor list.
#' @keywords internal
svc_metadata_require_descriptor <- function(slug) {
  descriptor <- metadata_vocabulary_descriptor(slug)
  if (is.null(descriptor)) {
    stop_for_not_found(sprintf("Unknown metadata vocabulary: %s", slug))
  }
  descriptor
}

#' Coerce a tinyint-like flag (0/1) from a JSON value, or stop with 400.
#'
#' Accepts logical, 0/1 numerics, and "true"/"false" strings.
#'
#' @param value Incoming value.
#' @param field Field name (for error messages).
#' @return Integer 0 or 1.
#' @keywords internal
svc_metadata_coerce_flag <- function(value, field) {
  if (is.logical(value) && length(value) == 1 && !is.na(value)) {
    return(as.integer(value))
  }
  if (is.numeric(value) && length(value) == 1 && value %in% c(0, 1)) {
    return(as.integer(value))
  }
  if (is.character(value) && length(value) == 1) {
    lowered <- tolower(value)
    if (lowered %in% c("true", "1")) return(1L)
    if (lowered %in% c("false", "0")) return(0L)
  }
  stop_for_bad_request(sprintf("Field '%s' must be a boolean (0/1).", field))
}

#' Validate a non-empty character field against its length ceiling.
#'
#' @param value Incoming value.
#' @param field Field name.
#' @param required Whether the field is mandatory.
#' @return Trimmed character scalar, or NULL when optional + absent.
#' @keywords internal
svc_metadata_clean_text <- function(value, field, required = FALSE) {
  if (is.null(value) || (length(value) == 1 && is.na(value))) {
    if (required) {
      stop_for_bad_request(sprintf("Field '%s' is required.", field))
    }
    return(NULL)
  }
  if (!is.character(value) || length(value) != 1) {
    stop_for_bad_request(sprintf("Field '%s' must be a single string.", field))
  }
  trimmed <- trimws(value)
  if (required && nchar(trimmed) == 0) {
    stop_for_bad_request(sprintf("Field '%s' must not be empty.", field))
  }
  ceiling <- .SVC_METADATA_MAX_LEN[[field]]
  if (!is.null(ceiling) && nchar(trimmed) > ceiling) {
    stop_for_bad_request(sprintf(
      "Field '%s' exceeds the maximum length of %d characters.",
      field, ceiling
    ))
  }
  trimmed
}

#' Build the column set for an editable field list from a request body.
#'
#' Applies text-length validation and flag coercion based on the descriptor.
#'
#' @param descriptor Vocabulary descriptor.
#' @param body Parsed request body (named list).
#' @param require_all When TRUE (create), required text fields must be present.
#' @return Named list of column -> value to write (subset of editable fields).
#' @keywords internal
svc_metadata_collect_fields <- function(descriptor, body, require_all = FALSE) {
  columns <- list()
  for (field in descriptor$fields) {
    present <- field %in% names(body)
    if (!present && !require_all) {
      next
    }
    raw <- body[[field]]
    if (field %in% c("allowed_phenotype", "allowed_variation")) {
      # modifier flags default to 0 on create when omitted
      if (!present) {
        columns[[field]] <- 0L
      } else {
        columns[[field]] <- svc_metadata_coerce_flag(raw, field)
      }
    } else {
      # The vocabulary's first declared field is its required display name on
      # create; remaining text fields are optional.
      required <- require_all && identical(field, descriptor$fields[[1]])
      cleaned <- svc_metadata_clean_text(raw, field, required = required)
      if (!is.null(cleaned)) {
        columns[[field]] <- cleaned
      }
    }
  }
  columns
}

#' Apply the optional is_active / sort lifecycle columns from the body.
#'
#' @param descriptor Vocabulary descriptor.
#' @param body Parsed request body.
#' @param columns Accumulated column list.
#' @param default_active When TRUE (create), default is_active to 1.
#' @return Updated column list.
#' @keywords internal
svc_metadata_apply_lifecycle <- function(descriptor, body, columns, default_active = FALSE) {
  if (isTRUE(descriptor$has_is_active)) {
    if ("is_active" %in% names(body)) {
      columns[["is_active"]] <- svc_metadata_coerce_flag(body[["is_active"]], "is_active")
    } else if (default_active) {
      columns[["is_active"]] <- 1L
    }
  }
  if (isTRUE(descriptor$has_sort) && "sort" %in% names(body)) {
    sort_val <- body[["sort"]]
    if (!is.null(sort_val) && !(length(sort_val) == 1 && is.na(sort_val))) {
      if (!is.numeric(sort_val) || length(sort_val) != 1) {
        stop_for_bad_request("Field 'sort' must be an integer.")
      }
      columns[["sort"]] <- as.integer(sort_val)
    }
  }
  columns
}

# ---------------------------------------------------------------------------
# Public service operations
# ---------------------------------------------------------------------------

#' List a managed vocabulary's rows (admin view; includes inactive).
#'
#' @param slug Vocabulary slug.
#' @param pool Connection/pool.
#' @return List with `data` (rows) and `meta` (descriptor summary).
#' @export
svc_metadata_list <- function(slug, pool) {
  descriptor <- svc_metadata_require_descriptor(slug)
  rows <- metadata_vocabulary_list(descriptor, conn = pool)
  list(
    meta = list(
      slug = descriptor$slug,
      label = descriptor$label,
      table = descriptor$table,
      pk = descriptor$pk,
      editable = descriptor$editable,
      managed = descriptor$managed,
      fields = descriptor$fields
    ),
    data = rows
  )
}

#' Create a new vocabulary row (sysndd-managed vocabularies only).
#'
#' @param slug Vocabulary slug.
#' @param body Parsed request body.
#' @param pool Connection/pool.
#' @return List(status, message, entry).
#' @export
svc_metadata_create <- function(slug, body, pool) {
  descriptor <- svc_metadata_require_descriptor(slug)
  if (!isTRUE(descriptor$editable)) {
    stop_for_bad_request(sprintf(
      "The '%s' vocabulary is anchored to an external ontology; new terms cannot be created here.",
      descriptor$label
    ))
  }
  if (!identical(descriptor$pk_type, "integer")) {
    stop_for_bad_request("Creation is only supported for integer-keyed vocabularies.")
  }

  columns <- svc_metadata_collect_fields(descriptor, body, require_all = TRUE)
  columns <- svc_metadata_apply_lifecycle(descriptor, body, columns, default_active = TRUE)

  next_id <- metadata_vocabulary_next_id(descriptor, conn = pool)
  if (isTRUE(descriptor$has_sort) && is.null(columns[["sort"]])) {
    columns[["sort"]] <- next_id
  }
  insert_columns <- c(stats::setNames(list(next_id), descriptor$pk), columns)

  metadata_vocabulary_insert(descriptor, insert_columns, conn = pool)
  list(
    status = 201,
    message = "OK. Vocabulary entry created.",
    entry = list(pk = next_id)
  )
}

#' Update an existing vocabulary row.
#'
#' For anchored vocabularies only the curated display fields and lifecycle
#' columns are editable (the pk term itself is not). For sysndd vocabularies
#' the editable fields plus lifecycle columns are writable.
#'
#' @param slug Vocabulary slug.
#' @param pk_value Primary-key value (route param).
#' @param body Parsed request body.
#' @param pool Connection/pool.
#' @return List(status, message, entry).
#' @export
svc_metadata_update <- function(slug, pk_value, body, pool) {
  descriptor <- svc_metadata_require_descriptor(slug)
  pk_value <- svc_metadata_coerce_pk(descriptor, pk_value)

  existing <- metadata_vocabulary_get(descriptor, pk_value, conn = pool)
  if (nrow(existing) == 0) {
    stop_for_not_found(sprintf(
      "No %s entry with %s = %s.", descriptor$label, descriptor$pk, pk_value
    ))
  }

  columns <- svc_metadata_collect_fields(descriptor, body, require_all = FALSE)
  columns <- svc_metadata_apply_lifecycle(descriptor, body, columns, default_active = FALSE)

  if (length(columns) == 0) {
    stop_for_bad_request("No editable fields supplied in the update body.")
  }

  metadata_vocabulary_update(descriptor, pk_value, columns, conn = pool)
  list(
    status = 200,
    message = "OK. Vocabulary entry updated.",
    entry = list(pk = pk_value)
  )
}

#' Delete (soft-delete) a vocabulary row, guarding against in-use values.
#'
#' Hard deletes are never performed: a value in use returns a 400 telling the
#' admin to keep it; an unused value is soft-deleted (is_active = 0) so curation
#' history and any logical FK stay intact.
#'
#' @param slug Vocabulary slug.
#' @param pk_value Primary-key value (route param).
#' @param pool Connection/pool.
#' @return List(status, message).
#' @export
svc_metadata_delete <- function(slug, pk_value, pool) {
  descriptor <- svc_metadata_require_descriptor(slug)
  if (!isTRUE(descriptor$editable)) {
    stop_for_bad_request(sprintf(
      "The '%s' vocabulary is anchored to an external ontology; entries are deactivated via update, not deleted.",
      descriptor$label
    ))
  }
  pk_value <- svc_metadata_coerce_pk(descriptor, pk_value)

  existing <- metadata_vocabulary_get(descriptor, pk_value, conn = pool)
  if (nrow(existing) == 0) {
    stop_for_not_found(sprintf(
      "No %s entry with %s = %s.", descriptor$label, descriptor$pk, pk_value
    ))
  }

  usage <- metadata_vocabulary_usage_count(descriptor, pk_value, conn = pool)
  if (usage > 0) {
    stop_for_bad_request(sprintf(
      "Cannot delete this %s entry: it is referenced by %d curation record(s). Deactivate it instead.",
      descriptor$label, usage
    ))
  }

  metadata_vocabulary_soft_delete(descriptor, pk_value, conn = pool)
  list(
    status = 200,
    message = "OK. Vocabulary entry deactivated."
  )
}

#' Coerce a route primary-key string to the descriptor's pk type.
#'
#' @param descriptor Vocabulary descriptor.
#' @param pk_value Raw pk value (often a 1-element character from plumber).
#' @return Coerced pk value.
#' @keywords internal
svc_metadata_coerce_pk <- function(descriptor, pk_value) {
  if (length(pk_value) > 1) {
    pk_value <- pk_value[[1]]
  }
  if (is.null(pk_value) || (length(pk_value) == 1 && is.na(pk_value)) ||
      (is.character(pk_value) && nchar(trimws(pk_value)) == 0)) {
    stop_for_bad_request("Missing vocabulary entry identifier.")
  }
  if (identical(descriptor$pk_type, "integer")) {
    coerced <- suppressWarnings(as.integer(pk_value))
    if (is.na(coerced)) {
      stop_for_bad_request("Vocabulary entry identifier must be an integer.")
    }
    return(coerced)
  }
  as.character(pk_value)
}
