# api/functions/external-proxy-clinvar-traits.R
#
# Helper function to enrich gnomAD ClinVar variant records with disease condition
# and ontology associations (MONDO, OMIM) retrieved in bulk from NCBI ClinVar
# E-utilities (esummary).
#
# Extracted into a dedicated module to adhere to AGENTS.md (< 600 lines) and
# ensure fail-open resilience: if NCBI E-utilities is unavailable, variants are
# returned without condition enrichment rather than failing the API request.

require(httr2)
require(jsonlite)

#' Enrich a list of ClinVar variants with condition traits from NCBI E-utilities
#'
#' @param variants List of variant objects returned by gnomAD ClinVar proxy
#' @return The variants list with conditions, mondo_ids, and omim_ids injected
#' @export
enrich_variants_with_clinvar_traits <- function(variants) {
  if (is.null(variants) || length(variants) == 0) {
    return(variants %||% list())
  }

  tryCatch(
    {
      vids <- vapply(variants, function(v) {
        as.character(v$clinvar_variation_id %||% "")
      }, character(1))

      valid_mask <- nzchar(vids) & vids != "NA" & vids != "0"
      unique_vids <- unique(vids[valid_mask])

      if (length(unique_vids) == 0) {
        return(lapply(variants, function(v) {
          v$conditions <- v$conditions %||% list()
          v$mondo_ids <- v$mondo_ids %||% list()
          v$omim_ids <- v$omim_ids %||% list()
          v
        }))
      }

      # Cap at 1000 IDs to avoid excessive latency on extreme outlier genes
      if (length(unique_vids) > 1000) {
        unique_vids <- unique_vids[seq_len(1000)]
      }

      # Chunk into batches of up to 400 IDs
      chunk_size <- 400L
      chunks <- split(unique_vids, ceiling(seq_along(unique_vids) / chunk_size))

      trait_map <- list()
      budget <- external_proxy_budget("ncbi_clinvar", default_timeout = 6, default_max = 10, default_tries = 2L)

      for (chunk in chunks) {
        chunk_str <- paste(chunk, collapse = ",")
        url <- paste0(
          "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=clinvar&id=",
          chunk_str,
          "&retmode=json&tool=sysndd"
        )

        api_key <- Sys.getenv("NCBI_API_KEY", "")
        if (nzchar(api_key)) {
          url <- paste0(url, "&api_key=", api_key)
        }

        req <- request(url) %>%
          req_timeout(budget$timeout_seconds) %>%
          req_retry(
            max_tries = budget$max_tries,
            max_seconds = budget$max_seconds,
            backoff = ~ 2^.x,
            is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
          ) %>%
          req_user_agent("SysNDD/1.0 (https://sysndd.dbmr.unibe.ch)") %>%
          req_error(is_error = ~FALSE)

        resp <- req_perform(req)
        if (resp_status(resp) != 200) {
          next
        }

        doc <- resp_body_json(resp)
        uids <- doc$result$uids %||% list()

        for (uid in uids) {
          uid_str <- as.character(uid)
          entry <- doc$result[[uid_str]]
          if (is.null(entry)) {
            next
          }

          trait_sets <- list(
            entry$germline_classification$trait_set,
            entry$clinical_impact_classification$trait_set,
            entry$oncogenicity_classification$trait_set
          )

          cond_names <- character(0)
          mondo_set <- character(0)
          omim_set <- character(0)

          for (t_set in trait_sets) {
            if (is.null(t_set) || length(t_set) == 0) next
            for (trait in t_set) {
              name <- trimws(as.character(trait$trait_name %||% ""))
              if (nzchar(name)) {
                cond_names <- c(cond_names, name)
              }
              xrefs <- trait$trait_xrefs %||% list()
              for (xref in xrefs) {
                db_src <- toupper(as.character(xref$db_source %||% ""))
                db_id <- as.character(xref$db_id %||% "")
                if (identical(db_src, "MONDO") && nzchar(db_id)) {
                  mondo_set <- c(mondo_set, db_id)
                } else if (identical(db_src, "OMIM") && nzchar(db_id)) {
                  omim_set <- c(omim_set, db_id)
                }
              }
            }
          }

          trait_map[[uid_str]] <- list(
            conditions = as.list(unique(cond_names)),
            mondo_ids = as.list(unique(mondo_set)),
            omim_ids = as.list(unique(omim_set))
          )
        }
      }

      # Inject traits back into variant objects
      lapply(variants, function(v) {
        vid <- as.character(v$clinvar_variation_id %||% "")
        info <- trait_map[[vid]]
        v$conditions <- if (!is.null(info$conditions)) info$conditions else list()
        v$mondo_ids <- if (!is.null(info$mondo_ids)) info$mondo_ids else list()
        v$omim_ids <- if (!is.null(info$omim_ids)) info$omim_ids else list()
        v
      })
    },
    error = function(e) {
      message(paste0("[external-proxy] ClinVar traits enrichment fallback: ", conditionMessage(e)))
      lapply(variants, function(v) {
        v$conditions <- v$conditions %||% list()
        v$mondo_ids <- v$mondo_ids %||% list()
        v$omim_ids <- v$omim_ids %||% list()
        v
      })
    }
  )
}
