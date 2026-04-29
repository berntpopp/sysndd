# api/functions/external-proxy-gnomad-batch.R
#### Batched gnomAD GraphQL fallback for HGNC-update pipeline
#### See spec: .planning/superpowers/specs/2026-04-29-gnomad-constraints-x-chr-fallback-design.md
#
# Per AGENTS.md, every package call uses explicit `httr2::` / `jsonlite::` /
# `cachem::` namespacing — no bare require() at top of file.

# Sentinel value stored in cache_static when gnomAD confirmed a symbol has no constraint data.
# We need to distinguish "we asked, gnomAD said no" from "we never asked", and the
# cachem filesystem cache treats NULL and missing identically. The literal string is
# never a valid JSON-object response so it's safe as a tag.
GNOMAD_BATCH_NA_SENTINEL <- "__GNOMAD_NA__"

# Cache key namespace. Bumping the trailing version (e.g. v1 -> v2) is a clean way
# to invalidate after a JSON-shape change. cachem (cache_disk / cache_mem) accepts
# keys matching ^[a-z0-9_-]+$ — lowercase letters, digits, underscore, and hyphen
# are all valid (despite the misleading "Only lowercase letters and numbers are
# allowed" error message). The trailing underscore makes the per-symbol tail visually
# separable in cache filenames (e.g. `gnomad_constraint_v1_hla-b`).
GNOMAD_BATCH_CACHE_PREFIX <- "gnomad_constraint_v1_"

#' Build a cachem-compatible key for a single gene symbol.
#'
#' cachem keys must match `^[a-z0-9_-]+$`. HGNC symbols are alphanumeric or contain
#' hyphens (HLA-B, HLA-DRB1); both lowercase letters and hyphens are cachem-valid,
#' so we only need to lowercase to preserve `HLA-B` ≠ `HLAB`. Any other punctuation
#' (apostrophes, slashes, etc — not present in real HGNC symbols but defensive
#' against bad input) is replaced with `_` to keep the key unique and avoid silent
#' collisions across distinct sanitised symbols.
#' @noRd
.gnomad_batch_cache_key <- function(symbol) {
  normalised <- tolower(symbol)
  normalised <- gsub("[^a-z0-9_-]", "_", normalised)
  paste0(GNOMAD_BATCH_CACHE_PREFIX, normalised)
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

#' Build a prepared httr2 request for a chunk's GraphQL body.
#'
#' Shared by the single-chunk path (`.fetch_gnomad_constraints_chunk`) and the
#' parallel path (`fetch_gnomad_constraints_batch`). Centralising request
#' construction keeps headers, retries, and the "non-2xx is not an error"
#' policy identical between the two dispatch modes.
#' @noRd
.build_chunk_request <- function(query_body) {
  httr2::request(GNOMAD_BATCH_ENDPOINT) |>
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
}

#' Post-perform handling: turn a response (or an error condition) into either a
#' named character vector (JSON-or-NA per symbol) for a successful HTTP+parse,
#' or NULL for a transport-fail. Used by both dispatch paths.
#'
#' @param resp_or_err Either an httr2_response or an error condition.
#' @param symbols Character vector of HGNC symbols passed to the corresponding query, in alias order.
#' @return Named character vector on a 200-OK + parseable body (length = length(symbols),
#'   names = symbols, values JSON-or-NA), or NULL on transport failure / non-200 / parse error.
#'   Distinguishing NULL (transport-fail) from a vec-of-NAs (gene-not-found) is what lets
#'   the chunk-stitch loop decide whether to write sentinels to cache.
#' @noRd
.parse_chunk_response <- function(resp_or_err, symbols) {
  if (inherits(resp_or_err, "error") || inherits(resp_or_err, "condition")) {
    if (!inherits(resp_or_err, "httr2_response")) {
      warning(sprintf(
        "[gnomad-batch] transport error for batch of %d symbols (%s..): %s",
        length(symbols), symbols[1L], conditionMessage(resp_or_err)
      ), call. = FALSE)
      return(NULL)
    }
  }
  if (!inherits(resp_or_err, "httr2_response")) {
    return(NULL)
  }
  status <- httr2::resp_status(resp_or_err)
  if (status != 200L) {
    warning(sprintf(
      "[gnomad-batch] HTTP %d for batch of %d symbols (%s..)",
      status, length(symbols), symbols[1L]
    ), call. = FALSE)
    return(NULL)
  }
  parsed <- tryCatch(
    httr2::resp_body_json(resp_or_err),
    error = function(e) {
      warning(sprintf(
        "[gnomad-batch] could not parse json response for batch of %d symbols (%s..): %s",
        length(symbols), symbols[1L], conditionMessage(e)
      ), call. = FALSE)
      return(NULL)
    }
  )
  if (is.null(parsed)) {
    return(NULL)
  }
  .parse_batched_constraint_response(parsed, symbols)
}

#' Fire one POST to the gnomAD GraphQL endpoint for ≤25 symbols
#'
#' @param symbols Character vector, length ≤ GNOMAD_BATCH_MAX_PER_REQUEST.
#' @return On HTTP 200 + parseable JSON: named character vector of length
#'   `length(symbols)`, names equal to `symbols`, each element a JSON string or
#'   `NA_character_` (NA = gene-not-found, with a successful transport).
#'   On transport failure (timeout, non-200, or parse error): `NULL`.
#'   This NULL-vs-vec distinction is load-bearing for the cache-write decision
#'   in `fetch_gnomad_constraints_batch`: gene-not-found gets a sentinel, but a
#'   transport-failed chunk must not poison the cache for those symbols.
#' @noRd
.fetch_gnomad_constraints_chunk <- function(symbols) {
  if (length(symbols) == 0L) {
    return(setNames(character(0), character(0)))
  }
  query_body <- .build_aliased_constraint_query(symbols)
  if (is.null(query_body)) {
    # Every symbol was invalid; .build_aliased_constraint_query already warned.
    # All-invalid is not a transport failure — return all-NA so the caller
    # treats them as known-bad inputs (no point retrying invalid symbols).
    return(setNames(rep(NA_character_, length(symbols)), symbols))
  }

  req <- .build_chunk_request(query_body)
  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) e
  )
  .parse_chunk_response(resp, symbols)
}

#' Fetch gnomAD constraint scores for many symbols, batched and cached
#'
#' Consults the disk cache per-symbol; chunks misses ≤25 per HTTP request; dispatches
#' chunks concurrently via `httr2::req_perform_parallel` (single-chunk fast path uses
#' the synchronous `.fetch_gnomad_constraints_chunk`). Successful and "Gene not found"
#' results are written back to cache (the latter as the `GNOMAD_BATCH_NA_SENTINEL`).
#' Transport failures surface as NA without poisoning the cache — the chunk fetcher
#' returns `NULL` for transport-failed chunks so the stitch loop can skip cache writes
#' unambiguously (no fragile "all-NA chunk" heuristic).
#'
#' @param symbols Character vector of HGNC gene symbols. May be empty.
#' @param max_concurrency Integer pool size for parallel batch requests. Default 5.
#'   Benchmarks (2026-04-29, n=20) show gnomAD tolerates 20 concurrent without
#'   rate-limiting; 5 is well-mannered. Passed as `max_active` to
#'   `httr2::req_perform_parallel`.
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
    # `chunks` is a list; coerce to a plain unnamed list so Map() pairs cleanly.
    chunks <- unname(as.list(chunks))

    if (length(chunks) == 1L) {
      # Single-chunk fast path: skip the parallel-pool spin-up.
      chunk_results <- list(.fetch_gnomad_constraints_chunk(chunks[[1L]]))
    } else {
      # Real parallel dispatch via httr2::req_perform_parallel. Build a request per
      # chunk; a chunk whose symbols are all invalid yields NULL from
      # .build_aliased_constraint_query — for those we synthesise an all-NA result
      # without firing a request. Note: req_perform_parallel honors
      # `getOption("httr2_mock")`, so `httr2::with_mocked_responses` works in tests.
      built <- lapply(chunks, function(chunk_syms) {
        qb <- .build_aliased_constraint_query(chunk_syms)
        if (is.null(qb)) NULL else .build_chunk_request(qb)
      })
      non_null_idx <- which(!vapply(built, is.null, logical(1L)))
      chunk_results <- vector("list", length(chunks))
      # All-invalid chunks: known-bad input, treat as gene-not-found (all-NA vec, NOT NULL)
      # so the stitch loop writes sentinels for any future cache reuse-by-key... but
      # because invalid symbols never produce a cachem-valid key collision with a
      # real symbol, we still emit the all-NA vec consistent with single-chunk behaviour.
      for (i in setdiff(seq_along(chunks), non_null_idx)) {
        chunk_results[[i]] <- setNames(rep(NA_character_, length(chunks[[i]])), chunks[[i]])
      }
      if (length(non_null_idx) > 0L) {
        resps <- httr2::req_perform_parallel(
          built[non_null_idx],
          max_active = max_concurrency,
          on_error = "continue",
          progress = FALSE
        )
        for (j in seq_along(non_null_idx)) {
          i <- non_null_idx[[j]]
          chunk_results[[i]] <- .parse_chunk_response(resps[[j]], chunks[[i]])
        }
      }
    }

    # Stitch chunk results back into miss_idx slots, write to cache.
    # Each chunk_result is either:
    #   - NULL              → transport-failed chunk: skip cache writes for those symbols
    #   - named char vec    → write per slot: real value as-is, NA → sentinel
    # Pairing chunks[[i]] with chunk_results[[i]] via Map keeps the input-symbol list
    # available even when cr is NULL (no names to read off).
    Map(function(chunk_syms, cr) {
      if (is.null(cr)) {
        # Transport-failed chunk: leave cached_decoded slots as NA (already
        # initialised that way) and DO NOT write sentinels. Next pipeline run
        # will retry these symbols.
        return(invisible(NULL))
      }
      for (sym in names(cr)) {
        upper_sym <- toupper(sym)
        slot <- which(upper_syms == upper_sym & !hit_mask)
        if (length(slot) >= 1L) {
          val <- cr[[sym]]
          if (is.na(val)) {
            # Successful chunk + this alias = NA → gene-not-found per gnomAD.
            # Cache as sentinel so we don't re-query (chrX/Y/M long tail.)
            tryCatch(cache$set(.gnomad_batch_cache_key(sym), GNOMAD_BATCH_NA_SENTINEL),
              error = function(e) NULL
            )
          } else {
            tryCatch(cache$set(.gnomad_batch_cache_key(sym), val),
              error = function(e) NULL
            )
          }
          cached_decoded[slot] <<- val
        }
      }
      invisible(NULL)
    }, chunks, chunk_results)
  }

  setNames(cached_decoded, symbols)
}
