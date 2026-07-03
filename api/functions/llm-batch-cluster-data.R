# functions/llm-batch-cluster-data.R
#
# Pure helper that turns one clustering/snapshot cluster ROW into the
# `cluster_data` structure the LLM generation pipeline consumes, and resolves
# the authoritative `cluster_hash` from the row's `hash_filter`. Extracted from
# the (large) llm_batch_executor loop in llm-batch-generator.R to keep that file
# under the code-quality file-size ratchet, and so the row-shaping logic is
# unit-testable without a database. Sourced in both bootstrap/load_modules.R and
# bootstrap/setup_workers.R (the executor runs in the worker daemon).

require(logger)

#' Resolve a cluster's SHA-256 hash from its row.
#'
#' Prefers the pre-computed `hash_filter` (either `equals(hash,XXX)` or a bare
#' hash), mirroring the snapshot builder so the cache key agrees with the
#' published snapshot. Falls back to hashing the identifiers.
#'
#' @return Character hash, or NULL on error.
#' @keywords internal
llm_batch_extract_cluster_hash <- function(cluster_row, cluster_data, cluster_type) {
  tryCatch(
    {
      if ("hash_filter" %in% names(cluster_row)) {
        hash_str <- as.character(cluster_row$hash_filter)
        if (grepl("^equals\\(hash,", hash_str)) {
          sub("^equals\\(hash,(.*)\\)$", "\\1", hash_str)
        } else {
          hash_str
        }
      } else {
        # Backwards compatibility: derive from identifiers when no hash_filter.
        generate_cluster_hash(cluster_data$identifiers, cluster_type)
      }
    },
    error = function(e) {
      log_warn("Failed to extract/generate cluster hash: {conditionMessage(e)}")
      NULL
    }
  )
}

#' Build the cluster_data structure + hash from one cluster row.
#'
#' @param cluster_row One row (tibble slice) from the clustering/snapshot result.
#' @param cluster_type "functional" or "phenotype".
#' @param cluster_num The cluster's number/id.
#' @return list(ok = TRUE, cluster_data, cluster_hash) on success, or
#'   list(ok = FALSE, reason) when the row is unusable.
#' @export
llm_batch_build_cluster_data <- function(cluster_row, cluster_type, cluster_num) {
  cluster_data <- list(cluster_number = cluster_num)

  # Identifiers (nested list-column, or legacy comma-separated strings).
  if ("identifiers" %in% names(cluster_row)) {
    identifiers_tbl <- cluster_row$identifiers[[1]]
    if (cluster_type == "functional") {
      if (all(c("symbol", "hgnc_id") %in% names(identifiers_tbl))) {
        cluster_data$identifiers <- identifiers_tbl
      } else {
        return(list(ok = FALSE, reason = "missing symbol/hgnc_id columns"))
      }
    } else {
      if ("entity_id" %in% names(identifiers_tbl)) {
        cluster_data$identifiers <- identifiers_tbl
      } else {
        return(list(ok = FALSE, reason = "missing entity_id column"))
      }
    }
  } else if ("symbols" %in% names(cluster_row)) {
    symbols <- trimws(strsplit(as.character(cluster_row$symbols), ",")[[1]])
    cluster_data$identifiers <- tibble::tibble(symbol = symbols, hgnc_id = seq_along(symbols))
  } else if ("entity_ids" %in% names(cluster_row)) {
    entity_ids <- trimws(strsplit(as.character(cluster_row$entity_ids), ",")[[1]])
    cluster_data$identifiers <- tibble::tibble(entity_id = as.integer(entity_ids))
  } else {
    return(list(ok = FALSE, reason = "no identifiers data"))
  }

  # Term enrichment (functional). Missing => empty tibble (lower-quality gen).
  if ("term_enrichment" %in% names(cluster_row)) {
    enrichment_data <- cluster_row$term_enrichment[[1]]
    cluster_data$term_enrichment <- if (is.character(enrichment_data)) {
      jsonlite::fromJSON(enrichment_data)
    } else {
      enrichment_data
    }
  } else {
    cluster_data$term_enrichment <- tibble::tibble(
      category = character(0), term = character(0), fdr = numeric(0)
    )
  }

  # Phenotype supplementary MCA variables (kept only when non-empty).
  if (cluster_type == "phenotype") {
    for (col in c("quali_inp_var", "quali_sup_var", "quanti_sup_var")) {
      if (col %in% names(cluster_row)) {
        value <- cluster_row[[col]][[1]]
        if (is.data.frame(value) && nrow(value) > 0) {
          cluster_data[[col]] <- value
        }
      }
    }
  }

  cluster_hash <- llm_batch_extract_cluster_hash(cluster_row, cluster_data, cluster_type)
  if (is.null(cluster_hash)) {
    return(list(ok = FALSE, reason = "hash generation returned NULL"))
  }

  list(ok = TRUE, cluster_data = cluster_data, cluster_hash = cluster_hash)
}
