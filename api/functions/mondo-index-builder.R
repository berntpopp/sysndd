# functions/mondo-index-builder.R
# MONDO cross-ontology index builder: CURIE normalization, SSSOM/OBO parsing,
# xref merge, and DB write-path for mondo_term + mondo_xref tables.

require(dplyr)
require(readr)
require(tibble)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MONDO_TARGET_ALLOWLIST <- c(
  "MONDO", "Orphanet", "OMIM", "DOID", "UMLS", "MedGen", "NCIT", "GARD", "EFO"
)

MONDO_PREDICATE_RANK <- c(
  exactMatch   = 0L,
  equivalentTo = 1L,
  closeMatch   = 2L,
  narrowMatch  = 3L,
  broadMatch   = 4L,
  xref         = 5L
)

# NOTE (correction #7): OMIMPS is deliberately absent — phenotypic-series ids
# must NOT canonicalize to OMIM (they would mislink to an OMIM entry page).
# An unmapped prefix stays as-is and is dropped downstream (not in allowlist).
.MONDO_PREFIX_ALIASES <- c(
  ORPHANET = "Orphanet",
  ORPHA    = "Orphanet",
  MIM      = "OMIM",
  OMIM     = "OMIM",
  MEDGEN   = "MedGen",
  NCIT     = "NCIT",
  NCI      = "NCIT",
  GARD     = "GARD",
  EFO      = "EFO",
  DOID     = "DOID",
  UMLS     = "UMLS",
  UMLS_CUI = "UMLS",
  MONDO    = "MONDO"
)

# ---------------------------------------------------------------------------
# B1: CURIE normalization helpers
# ---------------------------------------------------------------------------

#' Extract and canonicalize the prefix of a CURIE
#'
#' @param curie Character. A CURIE such as "OMIM:618524" or "ORPHANET:530983".
#' @return Canonical prefix string or NA_character_ if not parseable.
#' @export
mondo_curie_prefix <- function(curie) {
  curie <- trimws(as.character(curie))
  m <- regmatches(curie, regexec("^([A-Za-z][A-Za-z0-9_]*):", curie))[[1]]
  if (length(m) < 2) return(NA_character_)
  raw <- toupper(m[[2]])
  unname(
    ifelse(
      raw %in% names(.MONDO_PREFIX_ALIASES),
      .MONDO_PREFIX_ALIASES[raw],
      m[[2]]  # return original casing when no alias found
    )
  )
}

#' Normalize a CURIE to canonical prefix casing
#'
#' @param curie Character. A CURIE such as "ORPHANET:530983".
#' @return Normalized CURIE (e.g., "Orphanet:530983") or NA_character_.
#' @export
mondo_normalize_curie <- function(curie) {
  curie <- trimws(as.character(curie))
  m <- regmatches(curie, regexec("^([A-Za-z][A-Za-z0-9_]*):(.+)$", curie))[[1]]
  if (length(m) < 3) return(NA_character_)
  prefix <- mondo_curie_prefix(curie)
  if (is.na(prefix)) return(NA_character_)
  paste0(prefix, ":", trimws(m[[3]]))
}

# ---------------------------------------------------------------------------
# B2: SSSOM parser
# ---------------------------------------------------------------------------

#' Parse a MONDO SSSOM mapping text (multi-prefix)
#'
#' Reads tab-separated SSSOM text with comment lines starting with "#", then
#' normalizes CURIEs, maps predicates, and filters rows. Does NOT filter by
#' allowlist at this stage — the caller (merge or write) decides which prefixes
#' to keep.
#'
#' @param text Character. Full text of an SSSOM TSV file.
#' @return Tibble with columns: mondo_id, target_prefix, target_id, predicate,
#'   source, target_label.
#' @export
mondo_sssom_parse <- function(text) {
  # readr::read_tsv (backed by vroom) requires a binary or file connection;
  # textConnection() is text-mode and causes "can only read from a binary
  # connection". Strip comment lines first, then pass the filtered text as a
  # character vector via I() which vroom accepts.
  lines_all     <- strsplit(text, "\n", fixed = TRUE)[[1]]
  lines_data    <- lines_all[!grepl("^#", lines_all)]
  filtered_text <- paste(lines_data, collapse = "\n")

  tbl <- readr::read_tsv(
    I(filtered_text),
    col_types      = readr::cols(.default = "c"),
    show_col_types = FALSE
  )

  # Guard: ensure expected columns exist
  required <- c("subject_id", "predicate_id", "object_id")
  missing  <- setdiff(required, names(tbl))
  if (length(missing) > 0L) {
    stop("SSSOM text missing required columns: ", paste(missing, collapse = ", "))
  }

  # Map predicate_id to short name
  .map_predicate <- function(pred) {
    # Strip namespace prefix (e.g. "skos:", "semapv:")
    short <- sub("^[a-zA-Z]+:", "", pred)
    if (short %in% c("exactMatch", "closeMatch", "narrowMatch", "broadMatch")) {
      return(short)
    }
    "xref"
  }

  # Normalize object_id
  norm_id   <- vapply(tbl$object_id,      mondo_normalize_curie, character(1L))
  prefix    <- vapply(norm_id,            mondo_curie_prefix,    character(1L))
  predicate <- vapply(tbl$predicate_id,   .map_predicate,        character(1L))

  target_label <- if ("object_label"         %in% names(tbl)) tbl$object_label         else NA_character_
  source       <- if ("mapping_justification" %in% names(tbl)) tbl$mapping_justification else NA_character_

  result <- tibble::tibble(
    mondo_id     = tbl$subject_id,
    target_prefix = prefix,
    target_id    = norm_id,
    predicate    = predicate,
    source       = source,
    target_label = target_label
  )

  # Drop rows where subject is not MONDO or prefix is NA / not resolvable
  result <- dplyr::filter(
    result,
    grepl("^MONDO:", mondo_id),
    !is.na(target_prefix)
  )

  result
}

# ---------------------------------------------------------------------------
# B3: OBO parser
# ---------------------------------------------------------------------------

#' Parse a MONDO OBO file text
#'
#' Line-by-line stanza state machine. Extracts [Term] stanzas, their xrefs,
#' and the release version from the header.
#'
#' @param text Character. Full text of a MONDO OBO file.
#' @return Named list with:
#'   \describe{
#'     \item{version}{Character release version string (e.g., "2026-05-05").}
#'     \item{terms}{Tibble: mondo_id, label, definition, is_obsolete, replaced_by.}
#'     \item{xrefs}{Tibble: mondo_id, target_prefix, target_id, predicate,
#'       origin, source, target_label.}
#'   }
#' @export
mondo_obo_parse <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]

  # --- Extract header version ---
  version <- NA_character_
  for (ln in lines) {
    m <- regmatches(ln, regexec("^data-version:\\s*releases/(.+)$", ln))[[1]]
    if (length(m) >= 2L) {
      version <- trimws(m[[2]])
      break
    }
  }

  # --- State machine over stanzas ---
  .MONDO_ID_RE <- "^MONDO:\\d{7}$"

  terms_list <- list()
  xrefs_list <- list()

  in_term   <- FALSE
  cur_id    <- NULL
  cur_name  <- NA_character_
  cur_def   <- NA_character_
  cur_obs   <- 0L
  cur_rep   <- NA_character_
  cur_xrefs <- list()

  .flush_stanza <- function() {
    if (!in_term || is.null(cur_id) || !grepl(.MONDO_ID_RE, cur_id)) return()
    terms_list[[length(terms_list) + 1L]] <<- list(
      mondo_id    = cur_id,
      label       = cur_name,
      definition  = cur_def,
      is_obsolete = cur_obs,
      replaced_by = cur_rep
    )
    xrefs_list <<- c(xrefs_list, cur_xrefs)
  }

  .parse_xref_line <- function(xref_raw) {
    # Strip "xref: " prefix
    xref_val <- trimws(sub("^xref:\\s*", "", xref_raw))
    # Extract trailing annotation {source="MONDO:equivalentTo"} if present
    ann_match <- regmatches(xref_val, regexec("\\{([^}]*)\\}", xref_val))[[1]]
    annotation <- if (length(ann_match) >= 2L) ann_match[[2]] else ""
    # Remove annotation from the CURIE part
    curie_part <- trimws(sub("\\s*\\{[^}]*\\}", "", xref_val))

    norm_id <- mondo_normalize_curie(curie_part)
    if (is.na(norm_id)) return(NULL)
    pfx <- mondo_curie_prefix(norm_id)
    if (is.na(pfx) || !(pfx %in% MONDO_TARGET_ALLOWLIST)) return(NULL)

    # Predicate: equivalentTo if annotation says so, else xref
    predicate <- if (grepl("MONDO:equivalentTo", annotation, fixed = TRUE)) {
      "equivalentTo"
    } else {
      "xref"
    }

    list(
      mondo_id     = cur_id,
      target_prefix = pfx,
      target_id    = norm_id,
      predicate    = predicate,
      origin       = "obo_xref",
      source       = NA_character_,
      target_label = NA_character_
    )
  }

  for (ln in lines) {
    ln <- trimws(ln)

    if (ln == "[Term]") {
      .flush_stanza()
      in_term   <- TRUE
      cur_id    <- NULL
      cur_name  <- NA_character_
      cur_def   <- NA_character_
      cur_obs   <- 0L
      cur_rep   <- NA_character_
      cur_xrefs <- list()
      next
    }

    if (!in_term) next

    if (grepl("^\\[", ln) && ln != "[Term]") {
      # New non-Term stanza
      .flush_stanza()
      in_term <- FALSE
      next
    }

    if (grepl("^id:\\s*", ln)) {
      cur_id <- trimws(sub("^id:\\s*", "", ln))
      next
    }
    if (grepl("^name:\\s*", ln)) {
      cur_name <- trimws(sub("^name:\\s*", "", ln))
      next
    }
    if (grepl("^def:\\s*", ln)) {
      # def: "text..." [refs]
      def_raw <- trimws(sub("^def:\\s*", "", ln))
      # Strip surrounding quotes and trailing [refs]
      def_raw <- sub('^"', "", def_raw)
      def_raw <- sub('"\\s*\\[[^]]*\\]\\s*$', "", def_raw)
      cur_def <- trimws(def_raw)
      next
    }
    if (grepl("^is_obsolete:\\s*true", ln)) {
      cur_obs <- 1L
      next
    }
    if (grepl("^replaced_by:\\s*", ln)) {
      rep_raw <- trimws(sub("^replaced_by:\\s*", "", ln))
      cur_rep <- mondo_normalize_curie(rep_raw)
      next
    }
    if (grepl("^xref:\\s*", ln)) {
      xr <- .parse_xref_line(ln)
      if (!is.null(xr)) {
        cur_xrefs[[length(cur_xrefs) + 1L]] <- xr
      }
      next
    }
  }
  # Flush last stanza
  .flush_stanza()

  # Build tibbles
  if (length(terms_list) == 0L) {
    terms_tbl <- tibble::tibble(
      mondo_id    = character(),
      label       = character(),
      definition  = character(),
      is_obsolete = integer(),
      replaced_by = character()
    )
  } else {
    terms_tbl <- tibble::tibble(
      mondo_id    = vapply(terms_list, `[[`, character(1L), "mondo_id"),
      label       = vapply(terms_list, `[[`, character(1L), "label"),
      definition  = vapply(terms_list, function(x) {
        v <- x[["definition"]]
        if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
      }, character(1L)),
      is_obsolete = vapply(terms_list, `[[`, integer(1L), "is_obsolete"),
      replaced_by = vapply(terms_list, function(x) {
        v <- x[["replaced_by"]]
        if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
      }, character(1L))
    )
  }

  if (length(xrefs_list) == 0L) {
    xrefs_tbl <- tibble::tibble(
      mondo_id     = character(),
      target_prefix = character(),
      target_id    = character(),
      predicate    = character(),
      origin       = character(),
      source       = character(),
      target_label = character()
    )
  } else {
    xrefs_tbl <- tibble::tibble(
      mondo_id     = vapply(xrefs_list, `[[`, character(1L), "mondo_id"),
      target_prefix = vapply(xrefs_list, `[[`, character(1L), "target_prefix"),
      target_id    = vapply(xrefs_list, `[[`, character(1L), "target_id"),
      predicate    = vapply(xrefs_list, `[[`, character(1L), "predicate"),
      origin       = vapply(xrefs_list, `[[`, character(1L), "origin"),
      source       = vapply(xrefs_list, function(x) {
        v <- x[["source"]]
        if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
      }, character(1L)),
      target_label = vapply(xrefs_list, function(x) {
        v <- x[["target_label"]]
        if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
      }, character(1L))
    )
  }

  list(version = version, terms = terms_tbl, xrefs = xrefs_tbl)
}

# ---------------------------------------------------------------------------
# B4: Merge xrefs with predicate ranking
# ---------------------------------------------------------------------------

#' Merge OBO and SSSOM xrefs, picking the strongest predicate per triple
#'
#' @param obo_xrefs Tibble from mondo_obo_parse()$xrefs (with origin column).
#' @param sssom_xrefs Tibble from mondo_sssom_parse() (origin column optional).
#' @return Merged tibble with one row per (mondo_id, target_prefix, target_id),
#'   carrying the strongest predicate and coalesced target_label.
#' @export
mondo_merge_xrefs <- function(obo_xrefs, sssom_xrefs) {
  # Ensure sssom_xrefs has origin column
  if (!"origin" %in% names(sssom_xrefs)) {
    sssom_xrefs$origin <- "sssom"
  }

  all_xrefs <- dplyr::bind_rows(obo_xrefs, sssom_xrefs)
  if (nrow(all_xrefs) == 0L) return(all_xrefs)

  # Assign numeric predicate rank for ordering
  all_xrefs$prank <- vapply(all_xrefs$predicate, function(p) {
    r <- MONDO_PREDICATE_RANK[p]
    if (is.na(r)) 5L else as.integer(r)
  }, integer(1L))

  # Best predicate per (mondo_id, target_prefix, target_id)
  best <- all_xrefs |>
    dplyr::group_by(mondo_id, target_prefix, target_id) |>
    dplyr::slice_min(prank, n = 1, with_ties = FALSE) |>
    dplyr::ungroup()

  # Coalesce target_label from any row in the group
  labels <- all_xrefs |>
    dplyr::filter(!is.na(target_label)) |>
    dplyr::group_by(mondo_id, target_prefix, target_id) |>
    dplyr::summarise(target_label_best = dplyr::first(target_label), .groups = "drop")

  result <- dplyr::left_join(best, labels, by = c("mondo_id", "target_prefix", "target_id"))
  result$target_label <- ifelse(
    !is.na(result$target_label_best),
    result$target_label_best,
    result$target_label
  )
  result$target_label_best <- NULL
  result$prank             <- NULL
  result
}

# ---------------------------------------------------------------------------
# B5: Index write (DB write-path)
# ---------------------------------------------------------------------------

#' Batch-append a tibble to a DB table in chunks
#'
#' @param conn DBI connection.
#' @param table_name Character table name.
#' @param tbl Tibble to append.
#' @param max_rows Integer batch size (default 5000).
#' @return Invisibly NULL.
.mondo_batch_append <- function(conn, table_name, tbl, max_rows = 5000L) {
  if (nrow(tbl) == 0L) return(invisible(NULL))
  starts <- seq(1L, nrow(tbl), by = max_rows)
  for (s in starts) {
    e <- min(s + max_rows - 1L, nrow(tbl))
    DBI::dbAppendTable(conn, table_name, tbl[s:e, ])
  }
  invisible(NULL)
}

#' Write parsed MONDO terms and xrefs to the DB
#'
#' Must be called inside the caller's transaction. Deletes existing rows first
#' (DELETE, never TRUNCATE — TRUNCATE auto-commits and breaks rollback).
#'
#' @param conn DBI connection (already in a transaction).
#' @param parsed_obo List from mondo_obo_parse().
#' @param sssom_tbl Tibble from mondo_sssom_parse() (origin column added if missing).
#' @param release_version Character release version string.
#' @return Invisibly NULL.
#' @export
mondo_index_write <- function(conn, parsed_obo, sssom_tbl, release_version) {
  # Delete existing rows (NOT TRUNCATE — must be rollback-safe)
  DBI::dbExecute(conn, "DELETE FROM mondo_xref")
  DBI::dbExecute(conn, "DELETE FROM mondo_term")

  # Ensure sssom_tbl has origin column
  if (!"origin" %in% names(sssom_tbl)) {
    sssom_tbl$origin <- "sssom"
  }

  # Merge xrefs
  merged_xrefs <- mondo_merge_xrefs(parsed_obo$xrefs, sssom_tbl)

  # Prepare and write terms
  terms <- parsed_obo$terms
  terms$release_version <- release_version
  .mondo_batch_append(conn, "mondo_term", terms)

  # Prepare and write xrefs
  if (nrow(merged_xrefs) > 0L) {
    merged_xrefs$target_id_upper <- toupper(merged_xrefs$target_id)
    merged_xrefs$release_version <- release_version
    .mondo_batch_append(conn, "mondo_xref", merged_xrefs)
  }

  invisible(NULL)
}
