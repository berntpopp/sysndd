# api/functions/external-proxy-gnomad.R
#### gnomAD GraphQL proxy functions for constraint scores and ClinVar variants

require(httr2) # HTTP client for GraphQL queries
require(jsonlite) # JSON parsing


#' Fetch gnomAD constraint scores for a gene
#'
#' @description
#' Queries gnomAD v4 GraphQL API for gene-level constraint metrics including
#' pLI (probability of loss-of-function intolerance), LOEUF (loss-of-function
#' observed/expected upper bound fraction), and missense/synonymous Z-scores.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1", "TP53")
#'
#' @return List with constraint data or error information:
#' \describe{
#'   \item{Success}{list(source = "gnomad", gene_symbol, gene_id, constraints = list(...))}
#'   \item{Gene not found}{list(found = FALSE, source = "gnomad")}
#'   \item{Invalid symbol}{list(error = TRUE, source = "gnomad", message = "Invalid gene symbol")}
#'   \item{Error}{list(error = TRUE, source = "gnomad", message = <details>)}
#' }
#'
#' @details
#' Constraint fields returned (when available):
#' - pLI: Probability of loss-of-function intolerance (0-1, higher = more constrained)
#' - oe_lof, oe_lof_lower, oe_lof_upper: Observed/expected LoF ratio with confidence interval
#' - oe_mis, oe_mis_lower, oe_mis_upper: Observed/expected missense ratio with CI
#' - oe_syn, oe_syn_lower, oe_syn_upper: Observed/expected synonymous ratio with CI
#' - exp_lof, obs_lof: Expected and observed LoF variant counts
#' - exp_mis, obs_mis: Expected and observed missense variant counts
#' - exp_syn, obs_syn: Expected and observed synonymous variant counts
#' - lof_z, mis_z, syn_z: Z-scores for LoF, missense, and synonymous variants
#'
#' Uses rate limiting (10 req/min), retry with exponential backoff, and 30s timeout.
#' Cached with 30-day TTL via memoised wrapper (fetch_gnomad_constraints_mem).
#'
#' @examples
#' \dontrun{
#'   result <- fetch_gnomad_constraints("BRCA1")
#'   if (!result$error && result$found) {
#'     print(result$constraints$pLI)
#'   }
#' }
#'
#' @export
fetch_gnomad_constraints <- function(gene_symbol) {
  # Validate gene symbol format (prevents GraphQL injection)
  if (!validate_gene_symbol(gene_symbol)) {
    return(list(
      error = TRUE,
      source = "gnomad",
      message = "Invalid gene symbol"
    ))
  }

  tryCatch(
    {
      budget <- external_proxy_budget("gnomad")

      # GraphQL query for gene-level constraint metrics
      query_string <- "
        query GeneConstraint($symbol: String!) {
          gene(gene_symbol: $symbol, reference_genome: GRCh38) {
            gene_id
            symbol
            gnomad_constraint {
              pLI
              oe_lof
              oe_lof_lower
              oe_lof_upper
              oe_mis
              oe_mis_lower
              oe_mis_upper
              oe_syn
              oe_syn_lower
              oe_syn_upper
              exp_lof
              obs_lof
              exp_mis
              obs_mis
              exp_syn
              obs_syn
              lof_z
              mis_z
              syn_z
            }
          }
        }
      "

      # Build GraphQL POST request with httr2
      req <- request("https://gnomad.broadinstitute.org/api") %>%
        req_method("POST") %>%
        req_body_json(list(
          query = query_string,
          variables = list(symbol = gene_symbol)
        )) %>%
        req_throttle(
          rate = EXTERNAL_API_THROTTLE$gnomad$capacity / EXTERNAL_API_THROTTLE$gnomad$fill_time_s
        ) %>%
        req_retry(
          max_tries = budget$max_tries,
          max_seconds = budget$max_seconds,
          backoff = ~ 2^.x,
          is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
        ) %>%
        req_timeout(budget$timeout_seconds) %>%
        req_error(is_error = ~FALSE) # Handle errors manually

      # Perform request
      response <- req_perform(req)

      # Handle non-200 responses
      if (resp_status(response) != 200) {
        return(list(
          error = TRUE,
          status = resp_status(response),
          source = "gnomad",
          message = paste("gnomAD API returned HTTP", resp_status(response))
        ))
      }

      # Parse JSON response
      response_data <- resp_body_json(response)

      # Check if gene was found (data$gene is NULL if not found)
      if (is.null(response_data$data$gene)) {
        return(list(found = FALSE, source = "gnomad"))
      }

      # Extract constraint data
      gene_data <- response_data$data$gene
      constraints <- gene_data$gnomad_constraint

      # Return structured result
      return(list(
        source = "gnomad",
        gene_symbol = gene_data$symbol,
        gene_id = gene_data$gene_id,
        constraints = constraints
      ))
    },
    error = function(e) {
      # Catch network errors, timeouts, JSON parsing failures
      return(list(
        error = TRUE,
        source = "gnomad",
        message = conditionMessage(e)
      ))
    }
  )
}


#' Fetch ClinVar variants for a gene from gnomAD
#'
#' @description
#' Queries gnomAD v4 GraphQL API for ClinVar variants associated with a gene.
#' Returns clinical significance, HGVS notation, review status, and whether
#' the variant is present in gnomAD population data.
#'
#' @param gene_symbol Character string, HGNC gene symbol (e.g., "BRCA1", "TP53")
#'
#' @return List with ClinVar variant data or error information:
#' \describe{
#'   \item{Success}{list(source = "gnomad_clinvar", gene_symbol, gene_id, variants = [...], variant_count)}
#'   \item{Gene not found}{list(found = FALSE, source = "gnomad")}
#'   \item{Invalid symbol}{list(error = TRUE, source = "gnomad", message = "Invalid gene symbol")}
#'   \item{Error}{list(error = TRUE, source = "gnomad", message = <details>)}
#' }
#'
#' @details
#' Each variant includes:
#' - clinical_significance: ClinVar classification (Pathogenic, Benign, VUS, etc.)
#' - clinvar_variation_id: ClinVar variant ID
#' - gold_stars: Review status confidence (0-4 stars)
#' - hgvsc: HGVS coding sequence notation (c. notation)
#' - hgvsp: HGVS protein sequence notation (p. notation)
#' - in_gnomad: Boolean, whether variant is observed in gnomAD population data
#' - major_consequence: Most severe consequence (missense, frameshift, etc.)
#' - pos: Genomic position (GRCh38)
#' - review_status: ClinVar review status text
#' - variant_id: gnomAD variant identifier (chrom-pos-ref-alt)
#'
#' Uses rate limiting (10 req/min), retry with exponential backoff, and 30s timeout.
#' Cached with 7-day TTL via memoised wrapper (fetch_gnomad_clinvar_variants_mem).
#'
#' @examples
#' \dontrun{
#'   result <- fetch_gnomad_clinvar_variants("BRCA1")
#'   if (!result$error && result$found) {
#'     print(paste("Found", result$variant_count, "ClinVar variants"))
#'   }
#' }
#'
#' @export
fetch_gnomad_clinvar_variants <- function(gene_symbol) {
  # Validate gene symbol format
  if (!validate_gene_symbol(gene_symbol)) {
    return(list(
      error = TRUE,
      source = "gnomad",
      message = "Invalid gene symbol"
    ))
  }

  tryCatch(
    {
      budget <- external_proxy_budget("gnomad")

      # GraphQL query for ClinVar variants associated with gene
      query_string <- "
        query GeneClinvar($symbol: String!) {
          gene(gene_symbol: $symbol, reference_genome: GRCh38) {
            gene_id
            symbol
            clinvar_variants {
              clinical_significance
              clinvar_variation_id
              gold_stars
              hgvsc
              hgvsp
              in_gnomad
              major_consequence
              pos
              review_status
              variant_id
            }
          }
        }
      "

      # Build GraphQL POST request with httr2
      req <- request("https://gnomad.broadinstitute.org/api") %>%
        req_method("POST") %>%
        req_body_json(list(
          query = query_string,
          variables = list(symbol = gene_symbol)
        )) %>%
        req_throttle(
          rate = EXTERNAL_API_THROTTLE$gnomad$capacity / EXTERNAL_API_THROTTLE$gnomad$fill_time_s
        ) %>%
        req_retry(
          max_tries = budget$max_tries,
          max_seconds = budget$max_seconds,
          backoff = ~ 2^.x,
          is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
        ) %>%
        req_timeout(budget$timeout_seconds) %>%
        req_error(is_error = ~FALSE) # Handle errors manually

      # Perform request
      response <- req_perform(req)

      # Handle non-200 responses
      if (resp_status(response) != 200) {
        return(list(
          error = TRUE,
          status = resp_status(response),
          source = "gnomad",
          message = paste("gnomAD API returned HTTP", resp_status(response))
        ))
      }

      # Parse JSON response
      response_data <- resp_body_json(response)

      # Check if gene was found
      if (is.null(response_data$data$gene)) {
        return(list(found = FALSE, source = "gnomad"))
      }

      # Extract ClinVar variant data
      gene_data <- response_data$data$gene
      variants <- gene_data$clinvar_variants

      # Return structured result
      return(list(
        source = "gnomad_clinvar",
        gene_symbol = gene_data$symbol,
        gene_id = gene_data$gene_id,
        variants = variants,
        variant_count = length(variants)
      ))
    },
    error = function(e) {
      # Catch network errors, timeouts, JSON parsing failures
      return(list(
        error = TRUE,
        source = "gnomad",
        message = conditionMessage(e)
      ))
    }
  )
}


#### ClinVar summary helpers

clinvar_primary_classes <- list(
  pathogenic = list(label = "Pathogenic", short_label = "P"),
  likely_pathogenic = list(label = "Likely pathogenic", short_label = "LP"),
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

#' Normalize ClinVar clinical significance for compact summary chips
#'
#' @param significance ClinVar clinical significance string
#' @return One of the five primary class keys or an `other:*` key
#' @export
normalize_clinvar_classification <- function(significance) {
  if (is.null(significance) || is.na(significance) || significance == "") {
    return("other:unknown")
  }

  key <- gsub("_", " ", tolower(as.character(significance)), fixed = TRUE)
  key <- gsub("\\s+", " ", trimws(key))

  if (key %in% c("pathogenic/likely pathogenic", "pathogenic likely pathogenic")) {
    return("pathogenic")
  }
  if (key %in% c("benign/likely benign", "benign likely benign")) {
    return("likely_benign")
  }
  if (grepl("conflicting", key, fixed = TRUE)) {
    return("other:conflicting_classifications_of_pathogenicity")
  }
  if (grepl("not provided", key, fixed = TRUE)) {
    return("other:not_provided")
  }
  if (grepl("likely", key, fixed = TRUE) && grepl("pathogenic", key, fixed = TRUE)) {
    return("likely_pathogenic")
  }
  if (grepl("pathogenic", key, fixed = TRUE)) {
    return("pathogenic")
  }
  if (grepl("uncertain", key, fixed = TRUE) || grepl("vus", key, fixed = TRUE)) {
    return("vus")
  }
  if (grepl("likely", key, fixed = TRUE) && grepl("benign", key, fixed = TRUE)) {
    return("likely_benign")
  }
  if (grepl("benign", key, fixed = TRUE)) {
    return("benign")
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


#### Memoised wrappers with per-source caching

#' Memoised version of fetch_gnomad_constraints with 30-day cache
#'
#' @description
#' Cached version of fetch_gnomad_constraints using cache_static backend.
#' Constraint scores are static data that rarely changes, so 30-day TTL is appropriate.
#'
#' @inheritParams fetch_gnomad_constraints
#' @return Same as fetch_gnomad_constraints
#'
#' @export
fetch_gnomad_constraints_mem <- memoise_external_success_only(
  fetch_gnomad_constraints,
  cache = cache_static,
  source = "gnomad"
)


#' Memoised version of fetch_gnomad_clinvar_variants with 7-day cache
#'
#' @description
#' Cached version of fetch_gnomad_clinvar_variants using cache_dynamic backend.
#' ClinVar data is updated regularly, so 7-day TTL balances freshness with performance.
#'
#' @inheritParams fetch_gnomad_clinvar_variants
#' @return Same as fetch_gnomad_clinvar_variants
#'
#' @export
fetch_gnomad_clinvar_variants_mem <- memoise_external_success_only(
  fetch_gnomad_clinvar_variants,
  cache = cache_dynamic,
  source = "gnomad"
)
