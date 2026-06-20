# functions/disease-ontology-mapping-builder.R
# Disease cross-ontology mapping builder: SQL-driven derivation and DB write-path
# for the disease_ontology_mapping table and disease_ontology_set projection columns.
#
# Depends on: mondo-index-builder.R (for MONDO_TARGET_ALLOWLIST, mondo_merge_xrefs)

require(dplyr)
require(tibble)
require(DBI)

# ---------------------------------------------------------------------------
# Column map: which disease_ontology_set column each allowlist prefix writes to
# (OMIM is the disease_ontology_id anchor itself — no separate column needed)
# ---------------------------------------------------------------------------
.MAPPING_PREFIX_COLUMN <- c(
  DOID     = "DOID",
  MONDO    = "MONDO",
  Orphanet = "Orphanet",
  EFO      = "EFO",
  UMLS     = "UMLS",
  MedGen   = "MedGen",
  NCIT     = "NCIT",
  GARD     = "GARD"
)

# ---------------------------------------------------------------------------
# B6: Derive disease cross-ontology mappings
# ---------------------------------------------------------------------------

#' Derive disease cross-ontology mapping rows from the DB
#'
#' For each distinct disease_ontology_id in disease_ontology_set:
#' 1. Emits a sysndd_native mapping row (self-referencing, source = "sysndd_native").
#' 2. Resolves a MONDO hub: if the prefix is MONDO, uses it directly; otherwise
#'    looks up the strongest-predicate match in mondo_xref.
#' 3. If a MONDO hub is found, emits a MONDO mapping row and all downstream
#'    cross-ontology mappings from mondo_xref for the resolved hub.
#'
#' @param conn DBI connection.
#' @param target_allowlist Character vector of prefixes to include in output.
#'   Defaults to MONDO_TARGET_ALLOWLIST.
#' @return Tibble with columns: disease_ontology_id, mondo_id, target_prefix,
#'   target_id, target_label, predicate, source, release_version.
#' @export
disease_mapping_derive <- function(conn, target_allowlist = MONDO_TARGET_ALLOWLIST) {
  # Fetch distinct disease_ontology_id values
  disease_ids_df <- DBI::dbGetQuery(
    conn,
    "SELECT DISTINCT disease_ontology_id FROM disease_ontology_set"
  )

  if (nrow(disease_ids_df) == 0L) {
    return(tibble::tibble(
      disease_ontology_id = character(),
      mondo_id            = character(),
      target_prefix       = character(),
      target_id           = character(),
      target_label        = character(),
      predicate           = character(),
      source              = character(),
      release_version     = character()
    ))
  }

  disease_ids <- disease_ids_df$disease_ontology_id

  # Fetch all mondo_xref rows in one query (pulled into R memory)
  # This is safe for the MONDO xref table which is a fixed-size ontology index
  xref_df <- DBI::dbGetQuery(
    conn,
    paste0(
      "SELECT mondo_id, target_prefix, target_id, target_id_upper, ",
      "target_label, predicate, origin, source, release_version ",
      "FROM mondo_xref"
    )
  )

  # Derive the latest release version from xref table (or fall back to NA)
  release_version <- if (nrow(xref_df) > 0L && !is.null(xref_df$release_version)) {
    ver <- xref_df$release_version[!is.na(xref_df$release_version)]
    if (length(ver) > 0L) ver[[1L]] else NA_character_
  } else {
    NA_character_
  }

  result_rows <- list()

  for (did in disease_ids) {
    # Determine prefix of this disease id
    prefix <- if (!is.na(did) && grepl("^[A-Za-z][A-Za-z0-9_]*:.+$", did)) {
      raw_prefix <- sub(":.*$", "", did)
      raw_upper  <- toupper(raw_prefix)
      aliases    <- .MONDO_PREFIX_ALIASES_FOR_DERIVE()
      if (raw_upper %in% names(aliases)) aliases[[raw_upper]] else raw_prefix
    } else {
      NA_character_
    }

    # 1. Native mapping row (self-reference)
    result_rows[[length(result_rows) + 1L]] <- list(
      disease_ontology_id = did,
      mondo_id            = NA_character_,
      target_prefix       = prefix,
      target_id           = did,
      target_label        = NA_character_,
      predicate           = NA_character_,
      source              = "sysndd_native",
      release_version     = release_version
    )

    # 2. Resolve MONDO hub
    mondo_id <- NA_character_
    if (!is.na(prefix) && prefix == "MONDO") {
      mondo_id <- did
    } else if (!is.na(did) && nrow(xref_df) > 0L) {
      did_upper <- toupper(did)
      candidate <- xref_df[
        !is.na(xref_df$target_id_upper) & xref_df$target_id_upper == did_upper,
        ,
        drop = FALSE
      ]
      if (nrow(candidate) > 0L) {
        # Pick row with lowest predicate rank
        cand_ranks <- vapply(candidate$predicate, function(p) {
          r <- MONDO_PREDICATE_RANK[p]
          if (is.na(r)) 5L else as.integer(r)
        }, integer(1L))
        best_idx <- which.min(cand_ranks)
        mondo_id <- candidate$mondo_id[[best_idx]]
      }
    }

    if (is.na(mondo_id)) next

    # 3a. Emit MONDO mapping row (unless native IS MONDO)
    if (!is.na(prefix) && prefix != "MONDO") {
      # Determine source based on origin of the xref that gave us the hub
      did_upper  <- toupper(did)
      anchor_row <- xref_df[
        !is.na(xref_df$target_id_upper) & xref_df$target_id_upper == did_upper &
        !is.na(xref_df$mondo_id)        & xref_df$mondo_id == mondo_id,
        ,
        drop = FALSE
      ]
      hub_source <- if (nrow(anchor_row) > 0L) {
        if (isTRUE(anchor_row$origin[[1L]] == "sssom")) "mondo_sssom" else "mondo_obo_xref"
      } else {
        "mondo_obo_xref"
      }

      result_rows[[length(result_rows) + 1L]] <- list(
        disease_ontology_id = did,
        mondo_id            = mondo_id,
        target_prefix       = "MONDO",
        target_id           = mondo_id,
        target_label        = NA_character_,
        predicate           = if (nrow(anchor_row) > 0L) anchor_row$predicate[[1L]] else NA_character_,
        source              = hub_source,
        release_version     = release_version
      )
    }

    # 3b. Emit all other downstream xrefs for this mondo_id
    downstream <- xref_df[
      !is.na(xref_df$mondo_id) & xref_df$mondo_id == mondo_id &
      xref_df$target_prefix %in% target_allowlist,
      ,
      drop = FALSE
    ]
    # Exclude: the native anchor (target_id == did) and MONDO self-ref
    downstream <- downstream[
      !(!is.na(downstream$target_id) & downstream$target_id == did) &
      downstream$target_prefix != "MONDO",
      ,
      drop = FALSE
    ]

    if (nrow(downstream) == 0L) next

    # Pick best predicate per (target_prefix, target_id)
    downstream$prank <- vapply(downstream$predicate, function(p) {
      r <- MONDO_PREDICATE_RANK[p]
      if (is.na(r)) 5L else as.integer(r)
    }, integer(1L))

    downstream_deduped <- downstream |>
      dplyr::group_by(target_prefix, target_id) |>
      dplyr::slice_min(prank, n = 1, with_ties = FALSE) |>
      dplyr::ungroup()

    for (i in seq_len(nrow(downstream_deduped))) {
      row <- downstream_deduped[i, , drop = FALSE]
      xref_source <- if (isTRUE(row$origin == "sssom")) "mondo_sssom" else "mondo_obo_xref"
      result_rows[[length(result_rows) + 1L]] <- list(
        disease_ontology_id = did,
        mondo_id            = mondo_id,
        target_prefix       = row$target_prefix,
        target_id           = row$target_id,
        target_label        = if (is.na(row$target_label)) NA_character_ else row$target_label,
        predicate           = row$predicate,
        source              = xref_source,
        release_version     = release_version
      )
    }
  }

  if (length(result_rows) == 0L) {
    return(tibble::tibble(
      disease_ontology_id = character(),
      mondo_id            = character(),
      target_prefix       = character(),
      target_id           = character(),
      target_label        = character(),
      predicate           = character(),
      source              = character(),
      release_version     = character()
    ))
  }

  tibble::tibble(
    disease_ontology_id = vapply(result_rows, `[[`, character(1L), "disease_ontology_id"),
    mondo_id            = vapply(result_rows, function(x) {
      v <- x[["mondo_id"]]
      if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
    }, character(1L)),
    target_prefix       = vapply(result_rows, function(x) {
      v <- x[["target_prefix"]]
      if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
    }, character(1L)),
    target_id           = vapply(result_rows, `[[`, character(1L), "target_id"),
    target_label        = vapply(result_rows, function(x) {
      v <- x[["target_label"]]
      if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
    }, character(1L)),
    predicate           = vapply(result_rows, function(x) {
      v <- x[["predicate"]]
      if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
    }, character(1L)),
    source              = vapply(result_rows, `[[`, character(1L), "source"),
    release_version     = vapply(result_rows, function(x) {
      v <- x[["release_version"]]
      if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
    }, character(1L))
  )
}

# I2: Use the canonical .MONDO_PREFIX_ALIASES from mondo-index-builder.R directly.
# Both files are sourced together at runtime; no duplication needed.
.MONDO_PREFIX_ALIASES_FOR_DERIVE <- function() .MONDO_PREFIX_ALIASES

# ---------------------------------------------------------------------------
# B6: Write mappings to DB + refresh projection columns
# ---------------------------------------------------------------------------

#' Write derived disease_ontology_mapping rows to the DB and refresh projections
#'
#' Must be called inside the caller's transaction. Deletes existing rows first
#' (DELETE, never TRUNCATE — TRUNCATE auto-commits and breaks rollback).
#'
#' Also refreshes denormalized columns in disease_ontology_set:
#' UMLS, MedGen, NCIT, GARD, ontology_mapping_release — for each allowlist
#' prefix that has a corresponding column, joins disease_ontology_mapping and
#' updates disease_ontology_set using the best (highest-rank) mapping value.
#'
#' @param conn DBI connection (already in a transaction).
#' @param mapping_tbl Tibble from disease_mapping_derive().
#' @param release_version Character release version string.
#' @return Invisibly NULL.
#' @export
disease_mapping_write <- function(conn, mapping_tbl, release_version) {
  # Delete existing rows (NOT TRUNCATE — must be rollback-safe)
  DBI::dbExecute(conn, "DELETE FROM disease_ontology_mapping")

  if (nrow(mapping_tbl) == 0L) return(invisible(NULL))

  # Ensure is_active column is set
  mapping_tbl$is_active <- 1L

  # Batch insert
  batch_size <- 5000L
  starts     <- seq(1L, nrow(mapping_tbl), by = batch_size)
  for (s in starts) {
    e    <- min(s + batch_size - 1L, nrow(mapping_tbl))
    rows <- mapping_tbl[s:e, ]
    DBI::dbAppendTable(conn, "disease_ontology_mapping", rows)
  }

  # Refresh projection columns in disease_ontology_set where columns exist
  dos_cols <- tryCatch(
    names(DBI::dbGetQuery(conn, "SELECT * FROM disease_ontology_set LIMIT 0")),
    error = function(e) character(0L)
  )

  # C2: Reset all 8 projection columns to NULL first so stale values don't persist
  # for diseases that lost a prefix's mappings in this refresh.
  reset_parts <- vapply(names(.MAPPING_PREFIX_COLUMN), function(prefix) {
    col <- .MAPPING_PREFIX_COLUMN[[prefix]]
    if (col %in% dos_cols) paste0("`", col, "` = NULL") else ""
  }, character(1L))
  reset_parts <- reset_parts[nzchar(reset_parts)]
  if (length(reset_parts) > 0L) {
    tryCatch(
      DBI::dbExecute(
        conn,
        paste0("UPDATE disease_ontology_set SET ", paste(reset_parts, collapse = ", "))
      ),
      error = function(e) {
        warning("disease_mapping_write: could not reset projection columns: ", e$message)
      }
    )
  }

  # C2: Populate each column using GROUP_CONCAT(DISTINCT ... ORDER BY ... SEPARATOR ';')
  # so values are semicolon-joined and deterministic, matching the varchar(200) convention.
  for (prefix in names(.MAPPING_PREFIX_COLUMN)) {
    col <- .MAPPING_PREFIX_COLUMN[[prefix]]
    if (!(col %in% dos_cols)) next

    # I3: Use parameterized query for the prefix value to avoid SQL injection.
    # The column name is from our own trusted constant map so backtick-quoting is safe.
    sql <- paste0(
      "UPDATE disease_ontology_set dos ",
      "JOIN (",
      "  SELECT d.disease_ontology_id, ",
      "    LEFT(GROUP_CONCAT(DISTINCT d.target_id ORDER BY d.target_id SEPARATOR ';'), 200) AS joined_ids ",
      "  FROM disease_ontology_mapping d ",
      "  WHERE d.target_prefix = ? ",
      "    AND d.source != 'sysndd_native' ",
      "    AND d.is_active = 1 ",
      "    AND d.target_id IS NOT NULL ",
      "  GROUP BY d.disease_ontology_id ",
      ") best ON dos.disease_ontology_id = best.disease_ontology_id ",
      "SET dos.`", col, "` = best.joined_ids"
    )
    tryCatch(
      DBI::dbExecute(conn, sql, params = unname(list(prefix))),
      error = function(e) {
        warning("disease_mapping_write: could not update column '", col, "': ", e$message)
      }
    )
  }

  # I3: Update ontology_mapping_release using a parameterized query.
  if ("ontology_mapping_release" %in% dos_cols && !is.na(release_version)) {
    DBI::dbExecute(
      conn,
      paste0(
        "UPDATE disease_ontology_set ",
        "SET ontology_mapping_release = ? ",
        "WHERE disease_ontology_id IN (",
        "  SELECT DISTINCT disease_ontology_id FROM disease_ontology_mapping",
        ")"
      ),
      params = unname(list(release_version))
    )
  }

  invisible(NULL)
}
