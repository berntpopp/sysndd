# api/functions/variation-provenance-evidence.R
#
# Pure helper for variation ontology provenance. No DB access.
#
# Strength is normalized to 0-4 so sources stay comparable in the suggestion
# queue's sort order without unpacking evidence_json. The literature mapping is
# a placeholder ranking, not a claim of equivalence with review stars -- see
# open question 4 in the design spec.

LITERATURE_CONFIDENCE_STRENGTH <- list(
  explicit = 3L,
  inferred = 1L
)

#' Normalize source-specific evidence into a comparable 0-4 strength
#'
#' Returns NA rather than guessing. An unrecognized source, a fractional value,
#' or an out-of-range value must never silently become a plausible strength.
#'
#' @param source_type "literature" or "external_database".
#' @param raw Review stars for external databases; a confidence key for literature.
#' @return Integer 0-4, or NA_integer_.
#' @export
normalize_evidence_strength <- function(source_type, raw) {
  if (identical(source_type, "external_database")) {
    if (is.null(raw) || length(raw) != 1 || is.na(raw)) return(NA_integer_)

    if (is.character(raw)) {
      if (!grepl("^[0-9]+$", raw)) return(NA_integer_)
      # Range-check as a double BEFORE coercing to integer. as.double() never
      # warns on an out-of-range digit string (it saturates to Inf instead),
      # whereas as.integer() on the same string emits "NAs introduced by
      # coercion to integer range" -- a validator should reject cleanly, not
      # warn, so out-of-range values must never reach as.integer().
      stars_dbl <- as.double(raw)
      if (is.na(stars_dbl) || stars_dbl < 0 || stars_dbl > 4) return(NA_integer_)
      stars <- as.integer(stars_dbl)
    } else if (is.numeric(raw)) {
      if (raw != trunc(raw)) return(NA_integer_)
      # Same reasoning as above: range-check before as.integer() so a huge
      # integer-valued double (e.g. 1e20) never reaches the coercion warning.
      if (raw < 0 || raw > 4) return(NA_integer_)
      stars <- as.integer(raw)
    } else {
      return(NA_integer_)
    }

    if (is.na(stars) || stars < 0L || stars > 4L) return(NA_integer_)
    return(stars)
  }

  if (identical(source_type, "literature")) {
    if (is.null(raw) || length(raw) != 1 || is.na(raw)) return(NA_integer_)
    mapped <- LITERATURE_CONFIDENCE_STRENGTH[[as.character(raw)]]
    if (is.null(mapped)) return(NA_integer_)
    return(mapped)
  }

  NA_integer_
}
