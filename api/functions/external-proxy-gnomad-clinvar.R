# api/functions/external-proxy-gnomad-clinvar.R
#
# ClinVar classification vocabulary and compact-summary helpers for the gnomAD
# proxy. Extracted from external-proxy-gnomad.R to keep both files under the
# 600-line ceiling (AGENTS.md); sourced immediately after it in
# bootstrap/load_modules.R, which is what `summarise_gnomad_clinvar_variants()`
# depends on.
#
# The vocabulary table here is mirrored by `CLINVAR_SIGNIFICANCE_TABLE` in
# app/src/types/clinvarSignificance.ts, and both are asserted against
# api/tests/testthat/fixtures/clinvar-significance-vocabulary.json in both
# directions. See GitHub issue #607.

#### ClinVar summary helpers

clinvar_primary_classes <- list(
  pathogenic = list(label = "Pathogenic", short_label = "P"),
  likely_pathogenic = list(label = "Likely pathogenic", short_label = "LP"),
  conflicting = list(label = "Conflicting classifications", short_label = "CONF"),
  vus = list(label = "VUS", short_label = "VUS"),
  likely_benign = list(label = "Likely benign", short_label = "LB"),
  benign = list(label = "Benign", short_label = "B")
)

clinvar_consequence_labels <- list(
  lof = "LoF",
  missense = "Missense",
  splice = "Splice",
  inframe_indel = "In-frame indel",
  synonymous = "Synonymous",
  intronic = "Intronic",
  utr = "UTR",
  other = "Other"
)

sanitize_summary_key <- function(value) {
  key <- gsub("[^a-z0-9]+", "_", tolower(as.character(value)))
  key <- gsub("^_+|_+$", "", key)
  if (identical(key, "")) "unknown" else key
}

#' Canonical ClinVar clinical-significance vocabulary
#'
#' Mirrors `CLINVAR_SIGNIFICANCE_TABLE` in `app/src/types/clinvarSignificance.ts`.
#' Both are asserted against
#' `api/tests/testthat/fixtures/clinvar-significance-vocabulary.json` in both
#' directions, so the two tables cannot drift; add a new term to the fixture
#' first, then to both tables.
#'
#' Keys are already normalized (underscores to spaces, lowercase, single-spaced).
#' Combined pairs resolve to the MORE SEVERE member.
#'
#' @export
clinvar_significance_table <- c(
  "pathogenic"                                   = "pathogenic",
  "pathogenic/likely pathogenic"                 = "pathogenic",
  "pathogenic, low penetrance"                   = "pathogenic",

  "likely pathogenic"                            = "likely_pathogenic",
  "likely pathogenic, low penetrance"            = "likely_pathogenic",

  "uncertain significance"                       = "vus",

  "likely benign"                                = "likely_benign",
  "benign/likely benign"                         = "likely_benign",

  "benign"                                       = "benign",

  "conflicting classifications of pathogenicity" = "conflicting",
  "conflicting interpretations of pathogenicity" = "conflicting",

  "not provided"                              = "other:not_provided",
  "no classification provided"                = "other:no_classification_provided",
  "no classifications from unflagged records" = "other:no_classifications_from_unflagged_records",
  "no classification for the single variant"  = "other:no_classification_for_the_single_variant",
  "drug response"                             = "other:drug_response",
  "risk factor"                               = "other:risk_factor",
  "association"                               = "other:association",
  "association not found"                     = "other:association_not_found",
  "protective"                                = "other:protective",
  "affects"                                   = "other:affects",
  "confers sensitivity"                       = "other:confers_sensitivity",
  "established risk allele"                   = "other:established_risk_allele",
  "likely risk allele"                        = "other:likely_risk_allele",
  "uncertain risk allele"                     = "other:uncertain_risk_allele",
  "other"                                     = "other:other"
)

#' Atomic ClinVar classification terms, for resolving AGGREGATE values
#'
#' ClinVar aggregates across submissions: it joins classification terms with
#' `/`, then appends non-classification assertions after `;` or `|` — e.g. the
#' live record VCV000013310, `Pathogenic/Likely pathogenic/Pathogenic, low
#' penetrance/Established risk allele; risk factor`. Matching only whole strings
#' would send every such value to `other:*` and undercount real pathogenic
#' variants. Mirrors `CLINVAR_SIGNIFICANCE_TOKENS` on the client.
#'
#' @keywords internal
clinvar_significance_tokens <- c(
  "pathogenic"                                   = "pathogenic",
  "pathogenic, low penetrance"                   = "pathogenic",
  "likely pathogenic"                            = "likely_pathogenic",
  "likely pathogenic, low penetrance"            = "likely_pathogenic",
  "uncertain significance"                       = "vus",
  "likely benign"                                = "likely_benign",
  "benign"                                       = "benign",
  "conflicting classifications of pathogenicity" = "conflicting",
  "conflicting interpretations of pathogenicity" = "conflicting",
  "established risk allele"                      = "other",
  "likely risk allele"                           = "other",
  "uncertain risk allele"                        = "other",
  "drug response"                                = "other",
  "risk factor"                                  = "other",
  "association"                                  = "other",
  "protective"                                   = "other",
  "affects"                                      = "other",
  "other"                                        = "other"
)

#' Severity rank used to combine the tokens of an aggregate value
#' @keywords internal
clinvar_token_severity <- c(
  other = 0,
  benign = 1,
  likely_benign = 2,
  vus = 3,
  likely_pathogenic = 4,
  pathogenic = 5
)

#' Resolve a ClinVar aggregate value by its documented delimiter grammar
#'
#' Keeps the first `;`/`|` segment (the pathogenicity assertion; later segments
#' are secondary assertions such as `risk factor`), splits it on `/`, and
#' exact-matches every token. Any unresolvable token fails the whole value — a
#' partial match must never be allowed to promote an aggregate into a tier.
#'
#' @param key Already-normalized significance key
#' @return The combined class key, or NULL when the value is not resolvable
#' @keywords internal
.clinvar_resolve_aggregate <- function(key) {
  if (identical(key, "")) {
    return(NULL)
  }

  primary <- trimws(strsplit(key, "[;|]")[[1]][1])
  if (is.na(primary) || identical(primary, "")) {
    return(NULL)
  }

  tokens <- trimws(strsplit(primary, "/", fixed = TRUE)[[1]])
  best <- NULL

  for (token in tokens) {
    # Single-bracket lookup: `[[` on a named atomic vector ERRORS on a missing
    # key, `[` yields NA, which is what a fail-closed miss needs here.
    resolved <- unname(clinvar_significance_tokens[token])
    if (is.na(resolved)) {
      return(NULL) # one unknown token poisons the whole value
    }
    if (identical(resolved, "conflicting")) {
      return("conflicting")
    }
    if (is.null(best) ||
      clinvar_token_severity[[resolved]] > clinvar_token_severity[[best]]) {
      best <- resolved
    }
  }

  if (identical(best, "other")) "other:other" else best
}

#' Normalize ClinVar clinical significance for compact summary chips
#'
#' ClinVar `clinical_significance` is a controlled vocabulary, so it is matched
#' by EXACT string equality against `clinvar_significance_table` after one
#' normalization step, falling back to a tokenized parse of ClinVar's documented
#' aggregate grammar. Substring matching (`grepl`) silently misfiles every new or
#' unanticipated term into whichever branch its substrings happen to hit —
#' `"Conflicting classifications of pathogenicity"` contains `"pathogenic"`,
#' which is how the client counted and drew it as Pathogenic (issue #607). Do not
#' reintroduce a `grepl()` fallback here.
#'
#' @param significance ClinVar clinical significance string
#' @return One of the six primary class keys or an `other:*` key
#' @export
normalize_clinvar_classification <- function(significance) {
  if (is.null(significance) || length(significance) == 0) {
    return("other:unknown")
  }

  significance <- significance[[1]]

  if (is.na(significance)) {
    return("other:unknown")
  }

  key <- gsub("_", " ", tolower(as.character(significance)), fixed = TRUE)
  key <- trimws(gsub("\\s+", " ", key))

  if (identical(key, "")) {
    return("other:unknown")
  }

  mapped <- unname(clinvar_significance_table[key])
  if (!is.na(mapped)) {
    return(mapped)
  }

  aggregate <- .clinvar_resolve_aggregate(key)
  if (!is.null(aggregate)) {
    return(aggregate)
  }

  paste0("other:", sanitize_summary_key(key))
}

#' Normalize gnomAD ClinVar major consequence for compact summaries
#'
#' @param consequence gnomAD major_consequence string
#' @return Normalized consequence key
#' @export
normalize_clinvar_consequence <- function(consequence) {
  if (is.null(consequence) || is.na(consequence) || consequence == "") {
    return("other")
  }

  key <- tolower(as.character(consequence))
  if (key %in% c("missense_variant")) {
    return("missense")
  }
  if (key %in% c("synonymous_variant")) {
    return("synonymous")
  }
  if (key %in% c("frameshift_variant", "stop_gained", "start_lost", "stop_lost")) {
    return("lof")
  }
  if (key %in% c("splice_donor_variant", "splice_acceptor_variant", "splice_region_variant")) {
    return("splice")
  }
  if (key %in% c("inframe_insertion", "inframe_deletion")) {
    return("inframe_indel")
  }
  if (key %in% c("intron_variant")) {
    return("intronic")
  }
  if (grepl("utr_variant$", key)) {
    return("utr")
  }
  "other"
}

make_named_count_list <- function(keys, default = 0) {
  stats::setNames(as.list(rep(default, length(keys))), keys)
}

ordered_count_rows <- function(counts, labels) {
  keys <- names(counts)[vapply(counts, function(count) count > 0, logical(1))]
  keys <- keys[order(vapply(counts[keys], identity, numeric(1)), decreasing = TRUE)]

  lapply(keys, function(key) {
    list(
      key = key,
      label = labels[[key]] %||% key,
      count = counts[[key]]
    )
  })
}

#' Build a compact ClinVar summary from gnomAD ClinVar variants
#'
#' @param variants List of ClinVar variant records returned by gnomAD
#' @return List with legacy counts plus consequence breakdowns
#' @export
summarise_gnomad_clinvar_variants <- function(variants) {
  variants <- variants %||% list()
  class_keys <- names(clinvar_primary_classes)
  consequence_keys <- names(clinvar_consequence_labels)

  counts <- make_named_count_list(class_keys)
  consequence_counts <- make_named_count_list(consequence_keys)
  other_classifications <- list()
  quality_counts <- list(
    in_gnomad = 0,
    review_stars = make_named_count_list(as.character(0:4))
  )
  class_consequence_counts <- stats::setNames(
    lapply(class_keys, function(...) make_named_count_list(consequence_keys)),
    class_keys
  )

  for (variant in variants) {
    class_key <- normalize_clinvar_classification(variant$clinical_significance)
    consequence_key <- normalize_clinvar_consequence(variant$major_consequence)

    consequence_counts[[consequence_key]] <- consequence_counts[[consequence_key]] + 1

    if (startsWith(class_key, "other:")) {
      other_key <- sub("^other:", "", class_key)
      other_classifications[[other_key]] <- (other_classifications[[other_key]] %||% 0) + 1
    } else {
      counts[[class_key]] <- counts[[class_key]] + 1
      class_consequence_counts[[class_key]][[consequence_key]] <-
        class_consequence_counts[[class_key]][[consequence_key]] + 1
    }

    if (isTRUE(variant$in_gnomad)) {
      quality_counts$in_gnomad <- quality_counts$in_gnomad + 1
    }

    stars <- suppressWarnings(as.integer(variant$gold_stars %||% 0))
    if (is.na(stars) || stars < 0) stars <- 0
    if (stars > 4) stars <- 4
    star_key <- as.character(stars)
    quality_counts$review_stars[[star_key]] <- quality_counts$review_stars[[star_key]] + 1
  }

  class_breakdowns <- stats::setNames(lapply(class_keys, function(class_key) {
    class_meta <- clinvar_primary_classes[[class_key]]
    list(
      label = class_meta$label,
      short_label = class_meta$short_label,
      count = counts[[class_key]],
      consequences = ordered_count_rows(
        class_consequence_counts[[class_key]],
        clinvar_consequence_labels
      )
    )
  }), class_keys)

  list(
    counts = counts,
    consequence_counts = ordered_count_rows(consequence_counts, clinvar_consequence_labels),
    class_breakdowns = class_breakdowns,
    quality_counts = quality_counts,
    other_classifications = other_classifications,
    variant_count = length(variants)
  )
}
