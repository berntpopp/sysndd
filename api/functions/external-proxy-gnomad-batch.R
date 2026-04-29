# api/functions/external-proxy-gnomad-batch.R
#### Batched gnomAD GraphQL fallback for HGNC-update pipeline
#### See spec: .planning/superpowers/specs/2026-04-29-gnomad-constraints-x-chr-fallback-design.md

require(httr2)
require(jsonlite)

# Sentinel value stored in cache_static when gnomAD confirmed a symbol has no constraint data.
# We need to distinguish "we asked, gnomAD said no" from "we never asked", and the
# cachem filesystem cache treats NULL and missing identically. The literal string is
# never a valid JSON-object response so it's safe as a tag.
GNOMAD_BATCH_NA_SENTINEL <- "__GNOMAD_NA__"

# Cache key namespace. Bumping the suffix is a clean way to invalidate after a JSON-shape change.
GNOMAD_BATCH_CACHE_PREFIX <- "gnomad_constraint_v1::"

# 19 fields the bulk pipeline emits. Keep this list aligned with
# GNOMAD_TSV_COLUMN_MAP in api/functions/hgnc-enrichment-gnomad.R.
GNOMAD_BATCH_FIELDS <- c(
  "pLI",
  "oe_lof", "oe_lof_lower", "oe_lof_upper",
  "oe_mis", "oe_mis_lower", "oe_mis_upper",
  "oe_syn", "oe_syn_lower", "oe_syn_upper",
  "exp_lof", "obs_lof",
  "exp_mis", "obs_mis",
  "exp_syn", "obs_syn",
  "lof_z", "mis_z", "syn_z"
)

# gnomAD's GraphQL server enforces a query-cost limit of 25 (one cost unit per gene).
# Verified empirically 2026-04-29.
GNOMAD_BATCH_MAX_PER_REQUEST <- 25L

# gnomAD GraphQL endpoint. The ?raw query bypasses the GraphiQL HTML wrapper that
# would otherwise be served when the Accept header does not survive a proxy.
GNOMAD_BATCH_ENDPOINT <- "https://gnomad.broadinstitute.org/api?raw"

#' Build an aliased GraphQL query for ≤25 gene constraint lookups
#' @noRd
.build_aliased_constraint_query <- function(symbols) {
  if (length(symbols) == 0L) return(NULL)
  if (length(symbols) > GNOMAD_BATCH_MAX_PER_REQUEST) {
    stop(sprintf(
      "[gnomad-batch] internal error: builder called with %d symbols (max %d). The caller should chunk before calling.",
      length(symbols), GNOMAD_BATCH_MAX_PER_REQUEST
    ))
  }
  valid_mask <- vapply(symbols, validate_gene_symbol, logical(1L), USE.NAMES = FALSE)
  if (any(!valid_mask)) {
    warning(sprintf(
      "[gnomad-batch] filtered %d invalid symbols from query (will be returned as NA): %s",
      sum(!valid_mask),
      paste(shQuote(symbols[!valid_mask]), collapse = ", ")
    ), call. = FALSE)
  }
  valid_syms <- symbols[valid_mask]
  if (length(valid_syms) == 0L) return(NULL)

  field_block <- paste(GNOMAD_BATCH_FIELDS, collapse = " ")
  parts <- vapply(seq_along(valid_syms), function(i) {
    sprintf(
      'g%d: gene(gene_symbol: "%s", reference_genome: GRCh38) { gnomad_constraint { %s } }',
      i - 1L, valid_syms[i], field_block
    )
  }, character(1L), USE.NAMES = FALSE)

  paste0("query Batch { ", paste(parts, collapse = " "), " }")
}

#' Map a parsed GraphQL response back to a named char vector of JSON-or-NA
#'
#' @param parsed_json Already-parsed GraphQL response (`list(data = list(...), errors = ...)`).
#' @param symbols Character vector of HGNC symbols passed to the corresponding query, in alias order.
#' @return Named character vector of length `length(symbols)`, names equal to `symbols`,
#'   each value either a JSON string in the bulk pipeline shape or `NA_character_`.
#' @noRd
.parse_batched_constraint_response <- function(parsed_json, symbols) {
  if (length(symbols) == 0L) {
    return(setNames(character(0), character(0)))
  }
  # Determine which alias indices were called out in the top-level errors block.
  errored_aliases <- character(0)
  errs <- parsed_json$errors
  if (!is.null(errs) && length(errs) > 0L) {
    for (err in errs) {
      path <- err$path
      if (!is.null(path) && length(path) >= 1L) {
        # path[[1]] is the alias name like "g0"
        first <- as.character(path[[1L]])
        if (grepl("^g[0-9]+$", first)) {
          errored_aliases <- c(errored_aliases, first)
        }
      }
    }
  }

  out <- vapply(seq_along(symbols), function(i) {
    alias <- paste0("g", i - 1L)
    if (alias %in% errored_aliases) {
      return(NA_character_)
    }
    gene_obj <- parsed_json$data[[alias]]
    if (is.null(gene_obj)) {
      return(NA_character_)
    }
    constraint <- gene_obj$gnomad_constraint
    if (is.null(constraint)) {
      return(NA_character_)
    }
    # Build JSON in the same shape the bulk pipeline emits (19 fields, sprintf scientific,
    # `null` for NA). Use jsonlite::toJSON for safety, with auto_unbox = TRUE to emit scalars.
    # Reorder keys to match GNOMAD_BATCH_FIELDS for deterministic output.
    ordered <- constraint[GNOMAD_BATCH_FIELDS]
    names(ordered) <- GNOMAD_BATCH_FIELDS
    # Coerce numeric NAs to JSON null rather than R NA → "NA"
    ordered <- lapply(ordered, function(v) {
      if (is.null(v) || (length(v) == 1L && is.na(v))) NULL else v
    })
    jsonlite::toJSON(ordered, auto_unbox = TRUE, na = "null", null = "null")
  }, character(1L), USE.NAMES = FALSE)

  setNames(out, symbols)
}

#' Fire one POST to the gnomAD GraphQL endpoint for ≤25 symbols
#'
#' @param symbols Character vector, length ≤ GNOMAD_BATCH_MAX_PER_REQUEST.
#' @return Named character vector of length `length(symbols)`, names equal to `symbols`.
#'   Every element is either a JSON string or `NA_character_`. Network/parse failures
#'   surface as all-NA with a warning (no error thrown — the caller treats batch failures
#'   as non-fatal per spec §5).
#' @noRd
.fetch_gnomad_constraints_chunk <- function(symbols) {
  if (length(symbols) == 0L) {
    return(setNames(character(0), character(0)))
  }
  query_body <- .build_aliased_constraint_query(symbols)
  if (is.null(query_body)) {
    # Every symbol was invalid; .build_aliased_constraint_query already warned.
    return(setNames(rep(NA_character_, length(symbols)), symbols))
  }

  req <- httr2::request(GNOMAD_BATCH_ENDPOINT) |>
    httr2::req_method("POST") |>
    httr2::req_headers("Content-Type" = "application/json", "Accept" = "application/json") |>
    httr2::req_body_json(list(query = query_body)) |>
    httr2::req_timeout(30) |>
    httr2::req_retry(
      max_tries = 3L,
      max_seconds = 30L,
      is_transient = function(resp) httr2::resp_status(resp) %in% c(429L, 503L, 504L)
    ) |>
    httr2::req_error(is_error = function(resp) FALSE) # handle errors manually

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      warning(sprintf(
        "[gnomad-batch] transport error for batch of %d symbols (%s..): %s",
        length(symbols), symbols[1L], conditionMessage(e)
      ), call. = FALSE)
      return(NULL)
    }
  )
  if (is.null(resp)) {
    return(setNames(rep(NA_character_, length(symbols)), symbols))
  }

  status <- httr2::resp_status(resp)
  if (status != 200L) {
    warning(sprintf(
      "[gnomad-batch] HTTP %d for batch of %d symbols (%s..)",
      status, length(symbols), symbols[1L]
    ), call. = FALSE)
    return(setNames(rep(NA_character_, length(symbols)), symbols))
  }

  parsed <- tryCatch(
    httr2::resp_body_json(resp),
    error = function(e) {
      warning(sprintf(
        "[gnomad-batch] could not parse json response for batch of %d symbols (%s..): %s",
        length(symbols), symbols[1L], conditionMessage(e)
      ), call. = FALSE)
      return(NULL)
    }
  )
  if (is.null(parsed)) {
    return(setNames(rep(NA_character_, length(symbols)), symbols))
  }

  .parse_batched_constraint_response(parsed, symbols)
}
