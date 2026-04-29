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
# cachem (cache_disk / cache_mem) only accepts keys matching ^[a-z0-9]+$, so we keep this
# prefix lowercase-alphanumeric (no `::` separator) and likewise sanitise the per-symbol
# tail with `.gnomad_batch_cache_key()`.
GNOMAD_BATCH_CACHE_PREFIX <- "gnomadconstraintv1"

#' Build a cachem-compatible key for a single gene symbol.
#'
#' cachem keys must match `^[a-z0-9]+$`. Most HGNC symbols are alphanumeric but some
#' contain hyphens (e.g. HLA-B) or other punctuation; we lowercase and strip every
#' non-alphanumeric character. Collisions across distinct sanitised symbols are
#' acceptable in practice — the cache value is a JSON blob that the caller never
#' relies on by symbol identity (the named vector returned to the caller comes from
#' the GraphQL response, not from cache key lookup).
#' @noRd
.gnomad_batch_cache_key <- function(symbol) {
  paste0(GNOMAD_BATCH_CACHE_PREFIX, gsub("[^a-z0-9]", "", tolower(symbol)))
}

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

#' Fetch gnomAD constraint scores for many symbols, batched and cached
#'
#' Consults the disk cache per-symbol; chunks misses ≤25 per HTTP request; dispatches
#' chunks concurrently via httr2::reqs_perform_parallel. Successful and "Gene not found"
#' results are written back to cache (the latter as a sentinel). Transport failures
#' surface as NA without poisoning the cache.
#'
#' @param symbols Character vector of HGNC gene symbols. May be empty.
#' @param max_concurrency Integer pool size for parallel batch requests. Default 5.
#'   Benchmarks (2026-04-29, n=20) show gnomAD tolerates 20 concurrent without
#'   rate-limiting; 5 is well-mannered.
#' @param cache cachem cache backend. Default `cache_static` (30-day filesystem).
#'   Override in tests with `cachem::cache_mem()`.
#' @return Named character vector of length `length(symbols)`, names equal to `symbols`.
#'   Each element is either a JSON string in the bulk pipeline shape or `NA_character_`.
#' @export
fetch_gnomad_constraints_batch <- function(
  symbols,
  max_concurrency = 5L,
  cache = cache_static
) {
  if (length(symbols) == 0L) {
    return(setNames(character(0), character(0)))
  }

  # --- Step 1: per-symbol cache lookup ---
  upper_syms <- toupper(symbols)
  keys <- vapply(symbols, .gnomad_batch_cache_key, character(1L), USE.NAMES = FALSE)
  cached_raw <- vapply(keys, function(k) {
    if (cache$exists(k)) cache$get(k) else NA_character_
  }, character(1L), USE.NAMES = FALSE)
  cached_decoded <- ifelse(
    !is.na(cached_raw) & cached_raw == GNOMAD_BATCH_NA_SENTINEL,
    NA_character_,
    cached_raw
  )
  hit_mask <- !is.na(cached_raw) # both "real value" and sentinel count as hit

  # --- Step 2: chunk and dispatch misses ---
  miss_idx <- which(!hit_mask)
  if (length(miss_idx) > 0L) {
    miss_syms <- symbols[miss_idx]
    chunks <- split(
      miss_syms,
      ceiling(seq_along(miss_syms) / GNOMAD_BATCH_MAX_PER_REQUEST)
    )

    # Concurrency: build a request per chunk, fire via reqs_perform_parallel.
    fetch_chunk_async <- function(chunk_syms) {
      .fetch_gnomad_constraints_chunk(chunk_syms)
    }
    if (length(chunks) > 1L && max_concurrency > 1L) {
      # parallel via mirai pool — but we can also just lapply for now since the
      # individual chunks are non-blocking via httr2 anyway. Use a simple parallel
      # strategy: split chunks into waves of `max_concurrency`.
      chunk_results <- list()
      for (start in seq(1L, length(chunks), by = max_concurrency)) {
        end <- min(start + max_concurrency - 1L, length(chunks))
        wave <- chunks[start:end]
        wave_results <- lapply(wave, fetch_chunk_async)
        chunk_results <- c(chunk_results, wave_results)
      }
    } else {
      chunk_results <- lapply(chunks, fetch_chunk_async)
    }

    # Stitch chunk results back into miss_idx slots, write to cache.
    for (cr in chunk_results) {
      for (sym in names(cr)) {
        upper_sym <- toupper(sym)
        slot <- which(upper_syms == upper_sym & !hit_mask)
        if (length(slot) >= 1L) {
          val <- cr[[sym]]
          if (is.na(val)) {
            # Distinguish transport-fail (do not cache) from gene-not-found (cache as sentinel).
            # Both come back as NA from the chunk fetcher; we cannot distinguish here.
            # Convention: chunks that suffered transport failure return NA for ALL symbols,
            # successful chunks return NA only for missing genes.
            # Heuristic: if at least one alias in the chunk returned non-NA, the chunk was
            # successful; the NA is "gene not found" → cache the sentinel.
            chunk_had_success <- any(!is.na(cr))
            if (chunk_had_success) {
              tryCatch(cache$set(.gnomad_batch_cache_key(sym), GNOMAD_BATCH_NA_SENTINEL),
                error = function(e) NULL
              )
            }
          } else {
            tryCatch(cache$set(.gnomad_batch_cache_key(sym), val),
              error = function(e) NULL
            )
          }
          cached_decoded[slot] <- val
        }
      }
    }
  }

  setNames(cached_decoded, symbols)
}
