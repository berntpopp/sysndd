# functions/disease-ontology-mapping-refresh.R
#
# Orchestrator for the disease cross-ontology mapping refresh (WP-C).
#
# A dumb cron sidecar (see docker-compose.yml `ontology-mapping-cron` +
# scripts/ontology_mapping_refresh_enqueue.R) enqueues one durable
# `disease_ontology_mapping_refresh` job each week. The durable worker claims it
# and runs this orchestrator, which:
#   1. single-flights via a MySQL advisory lock (GET_LOCK, non-blocking),
#   2. downloads the MONDO OBO + full SSSOM with a conditional GET (persisting
#      ETag/Last-Modified validators) — a cheap no-op when both are unchanged AND
#      the index/mapping tables are already populated,
#   3. parses OBO + SSSOM, then rebuilds the index + derived mappings inside ONE
#      DB transaction (mondo_index_write -> disease_mapping_derive ->
#      disease_mapping_write) so a partial failure rolls back,
#   4. writes a `disease_ontology_mapping_meta` provenance row (counts,
#      durations, validators, status),
#   5. returns a structured run summary (persisted in the job result_json).
#
# Every external HTTP call derives its timeout/retry window from
# external_proxy_budget("mondo", ...) — never a hardcoded literal (enforced by
# test-unit-external-budget-guard.R). This is a batch job, so the per-request
# external-time accumulator is reset before each external call so the public
# request ceiling does not cap the back half of the run.
#
# All consumed builder/index interfaces (mondo_obo_parse, mondo_sssom_parse,
# mondo_index_write, disease_mapping_derive, disease_mapping_write,
# download_mondo_sssom_full) live in functions/* and are sourced together at
# runtime (WP-B/WP-D).

# NULL-coalescing operator: defined locally so this file is self-contained for
# unit tests (the runtime already provides one from rlang / sibling files).
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

#' Advisory-lock name that serializes mapping-refresh runs.
#' @keywords internal
.DISEASE_ONTOLOGY_MAPPING_LOCK <- "disease_ontology_mapping_refresh"

#' Try to acquire the mapping-refresh single-flight lock (non-blocking)
#'
#' Mirrors the PubtatorNDD nightly lock pattern. `GET_LOCK(..., 0)` returns
#' immediately: 1 if acquired, 0 if another connection holds it. The lock auto-
#' releases when the holding connection closes, so a crashed worker cannot
#' deadlock the schedule.
#'
#' @param conn A DBI connection.
#' @return TRUE if the lock was acquired, FALSE otherwise.
#' @export
disease_ontology_mapping_try_lock <- function(conn) {
  result <- DBI::dbGetQuery(
    conn,
    "SELECT GET_LOCK(?, 0) AS acquired",
    params = unname(list(.DISEASE_ONTOLOGY_MAPPING_LOCK))
  )
  identical(as.integer(result$acquired[[1]]), 1L)
}

#' Release the mapping-refresh single-flight lock
#'
#' @param conn A DBI connection (the one that acquired the lock).
#' @return TRUE if the lock was held and released, FALSE otherwise.
#' @export
disease_ontology_mapping_release_lock <- function(conn) {
  result <- DBI::dbGetQuery(
    conn,
    "SELECT RELEASE_LOCK(?) AS released",
    params = unname(list(.DISEASE_ONTOLOGY_MAPPING_LOCK))
  )
  identical(as.integer(result$released[[1]]), 1L)
}

#' Resolve the MONDO OBO URL (env -> config -> built-in default)
#'
#' Precedence mirrors `.resolve_sssom_url()`: explicit arg ->
#' `DISEASE_ONTOLOGY_MONDO_OBO_URL` env -> `config$mondo_obo_url` -> default.
#'
#' @param obo_url Character or NULL. Explicit override (NULL = auto-resolve).
#' @return Resolved URL string.
#' @export
disease_ontology_mapping_resolve_obo_url <- function(obo_url = NULL) {
  default_url <- "http://purl.obolibrary.org/obo/mondo.obo"

  if (is.null(obo_url) || !nzchar(obo_url)) {
    obo_url <- Sys.getenv("DISEASE_ONTOLOGY_MONDO_OBO_URL", "")
  }
  if (!nzchar(obo_url)) {
    obo_url <- tryCatch(
      {
        cfg <- config::get()
        if (!is.null(cfg$mondo_obo_url) && nzchar(cfg$mondo_obo_url)) {
          cfg$mondo_obo_url
        } else {
          default_url
        }
      },
      error = function(e) default_url
    )
  }
  obo_url
}

#' Download the MONDO OBO file with a budgeted, conditional GET
#'
#' Uses external_proxy_budget("mondo", ...) for timeout/retry/tries — never a
#' hardcoded literal. Sends conditional `If-None-Match` / `If-Modified-Since`
#' headers when prior validators are supplied; a 304 short-circuits to the cached
#' file. Resets the per-request external-time accumulator first so the public
#' request ceiling does not cap this batch download.
#'
#' @param output_path Directory for the cached file.
#' @param obo_url Override URL (NULL resolves from env/config/default).
#' @param prior_validators Optional list(etag=, last_modified=) from a prior run.
#' @return list(path=, etag=, last_modified=, not_modified=, status=).
#' @export
disease_ontology_mapping_download_obo <- function(output_path = "data/mondo_mappings/",
                                                  obo_url = NULL,
                                                  prior_validators = NULL) {
  obo_url <- disease_ontology_mapping_resolve_obo_url(obo_url)

  if (!dir.exists(output_path)) {
    fs::dir_create(output_path, recurse = TRUE)
  }

  file_basename <- "mondo-obo"
  current_date  <- format(Sys.Date(), "%Y-%m-%d")
  output_file   <- file.path(output_path, paste0(file_basename, ".", current_date, ".obo"))

  # Reset the per-request accumulator before each external call (batch job).
  if (exists("external_proxy_request_reset", mode = "function")) {
    external_proxy_request_reset()
  }

  budget <- external_proxy_budget("mondo")

  req <- httr2::request(obo_url) |>
    httr2::req_retry(
      max_tries    = budget$max_tries,
      max_seconds  = budget$max_seconds,
      is_transient = ~ httr2::resp_status(.x) %in% c(429L, 500L, 502L, 503L, 504L)
    ) |>
    httr2::req_timeout(budget$timeout_seconds) |>
    httr2::req_error(is_error = ~FALSE)

  if (!is.null(prior_validators)) {
    if (!is.null(prior_validators$etag) && nzchar(prior_validators$etag)) {
      req <- httr2::req_headers(req, `If-None-Match` = prior_validators$etag)
    }
    if (!is.null(prior_validators$last_modified) && nzchar(prior_validators$last_modified)) {
      req <- httr2::req_headers(req, `If-Modified-Since` = prior_validators$last_modified)
    }
  }

  response <- httr2::req_perform(req)
  status   <- httr2::resp_status(response)

  if (identical(status, 304L)) {
    return(list(
      path          = NULL,
      etag          = prior_validators$etag %||% NA_character_,
      last_modified = prior_validators$last_modified %||% NA_character_,
      not_modified  = TRUE,
      status        = status
    ))
  }

  if (!identical(status, 200L)) {
    stop(sprintf("Failed to download MONDO OBO file. HTTP status: %s", status), call. = FALSE)
  }

  content <- httr2::resp_body_string(response)
  writeLines(content, output_file)

  list(
    path          = output_file,
    etag          = httr2::resp_header(response, "ETag") %||% NA_character_,
    last_modified = httr2::resp_header(response, "Last-Modified") %||% NA_character_,
    not_modified  = FALSE,
    status        = status
  )
}

#' Read a scalar from a parsed job payload list (NULL-safe)
#' @keywords internal
.disease_ontology_mapping_payload_scalar <- function(payload, key, default = NULL) {
  if (is.null(payload) || is.null(payload[[key]])) {
    return(default)
  }
  value <- payload[[key]]
  if (length(value) == 0) {
    return(default)
  }
  value[[1]]
}

#' Whether the index + mapping tables are already populated.
#' @keywords internal
.disease_ontology_mapping_tables_populated <- function(conn) {
  rows <- tryCatch(
    DBI::dbGetQuery(
      conn,
      paste0(
        "SELECT ",
        "(SELECT COUNT(*) FROM mondo_term) AS term_n, ",
        "(SELECT COUNT(*) FROM disease_ontology_mapping WHERE is_active = 1) AS map_n"
      )
    ),
    error = function(e) NULL
  )
  if (is.null(rows) || nrow(rows) == 0) {
    return(FALSE)
  }
  isTRUE(as.integer(rows$term_n[[1]]) > 0L) && isTRUE(as.integer(rows$map_n[[1]]) > 0L)
}

#' Write a provenance row to disease_ontology_mapping_meta.
#' @keywords internal
.disease_ontology_mapping_write_meta <- function(conn, fields) {
  validators_json <- tryCatch(
    jsonlite::toJSON(fields$source_validators %||% list(), auto_unbox = TRUE),
    error = function(e) "{}"
  )
  tryCatch(
    DBI::dbExecute(
      conn,
      paste0(
        "INSERT INTO disease_ontology_mapping_meta ",
        "(mondo_release_version, mondo_obo_url, mondo_sssom_url, source_validators, ",
        " mondo_term_count, mondo_xref_count, mapping_count, disease_covered_count, ",
        " status, build_started_at, build_finished_at, build_duration_s) ",
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      ),
      params = unname(list(
        fields$mondo_release_version %||% NA_character_,
        fields$mondo_obo_url %||% NA_character_,
        fields$mondo_sssom_url %||% NA_character_,
        as.character(validators_json),
        fields$mondo_term_count %||% NA_integer_,
        fields$mondo_xref_count %||% NA_integer_,
        fields$mapping_count %||% NA_integer_,
        fields$disease_covered_count %||% NA_integer_,
        fields$status %||% NA_character_,
        format(fields$build_started_at, "%Y-%m-%d %H:%M:%S"),
        format(fields$build_finished_at %||% Sys.time(), "%Y-%m-%d %H:%M:%S"),
        fields$build_duration_s %||% NA_real_
      ))
    ),
    error = function(e) {
      message(sprintf("[ontology-mapping-refresh] could not write meta row: %s",
                      conditionMessage(e)))
      NULL
    }
  )
}

#' Run the disease cross-ontology mapping refresh orchestrator
#'
#' @param job The claimed job row (`job_id` used for progress).
#' @param payload Parsed job payload (may carry `force`).
#' @param progress Optional progress reporter `progress(step, message, ...)`.
#' @param pool_obj Optional DB pool (default: global `pool`). Injectable for tests.
#' @param try_lock_fn Injectable single-flight lock acquirer (default the canonical
#'   advisory-lock helper). A fake returning FALSE drives the lock-held skip path.
#' @param release_lock_fn Injectable lock releaser.
#' @param download_obo_fn Injectable OBO downloader (default the budgeted fetcher).
#' @param write_meta_fn Injectable provenance writer.
#' @param checkout_fn / @param return_fn Injectable pool checkout/return (default
#'   `pool::poolCheckout` / `pool::poolReturn`).
#' @return Structured run-summary list. `status == "skipped"` for the benign
#'   locked / unchanged cases (still a job success); on a real refresh-step
#'   failure a `status="failed"` meta row is written and the error re-raised so
#'   the durable handler marks the job failed.
#' @export
disease_ontology_mapping_refresh_run <- function(job, payload = list(), progress = NULL,
                                                 pool_obj = NULL,
                                                 try_lock_fn = disease_ontology_mapping_try_lock,
                                                 release_lock_fn = disease_ontology_mapping_release_lock,
                                                 download_obo_fn = disease_ontology_mapping_download_obo,
                                                 write_meta_fn = .disease_ontology_mapping_write_meta,
                                                 checkout_fn = pool::poolCheckout,
                                                 return_fn = pool::poolReturn) {
  report <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress) && is.function(progress)) {
      tryCatch(progress(step, message, current = current, total = total),
               error = function(e) NULL)
    }
  }

  force <- isTRUE(.disease_ontology_mapping_payload_scalar(payload, "force", default = FALSE))

  if (is.null(pool_obj)) {
    if (!base::exists("pool", envir = .GlobalEnv, inherits = FALSE)) {
      stop("Disease ontology mapping refresh requires the global database pool", call. = FALSE)
    }
    pool_obj <- base::get("pool", envir = .GlobalEnv, inherits = FALSE)
  }
  conn <- checkout_fn(pool_obj)
  lock_acquired <- FALSE
  on.exit({
    if (isTRUE(lock_acquired)) {
      tryCatch(release_lock_fn(conn), error = function(e) NULL)
    }
    return_fn(conn)
  }, add = TRUE)

  report("lock", "Acquiring mapping-refresh single-flight lock...", current = 0, total = 6)
  lock_acquired <- try_lock_fn(conn)
  if (!isTRUE(lock_acquired)) {
    # Benign skip: another refresh holds the lock. The job completes successfully.
    return(list(
      status  = "skipped",
      success = TRUE,
      reason  = "lock_held",
      message = "Another disease ontology mapping refresh is active; skipped this cycle"
    ))
  }

  build_started_at <- Sys.time()
  obo_url   <- disease_ontology_mapping_resolve_obo_url()
  sssom_url <- if (exists(".resolve_sssom_url", mode = "function")) .resolve_sssom_url() else NA_character_

  result <- tryCatch(
    {
      # Step 1: download OBO (conditional GET, budgeted).
      report("download_obo", "Downloading MONDO OBO...", current = 1, total = 6)
      obo_dl <- download_obo_fn(obo_url = obo_url)

      # Step 2: download full SSSOM (reset accumulator first — batch job).
      report("download_sssom", "Downloading MONDO SSSOM...", current = 2, total = 6)
      if (exists("external_proxy_request_reset", mode = "function")) {
        external_proxy_request_reset()
      }
      sssom_path <- download_mondo_sssom_full(force = force, sssom_url = if (is.na(sssom_url)) NULL else sssom_url)

      tables_populated <- .disease_ontology_mapping_tables_populated(conn)

      # Conditional-GET no-op: OBO unchanged AND tables already populated.
      if (!force && isTRUE(obo_dl$not_modified) && isTRUE(tables_populated)) {
        finished_at <- Sys.time()
        write_meta_fn(conn, list(
          mondo_release_version = NA_character_,
          mondo_obo_url         = obo_url,
          mondo_sssom_url       = sssom_url,
          source_validators     = list(
            obo_etag = obo_dl$etag, obo_last_modified = obo_dl$last_modified
          ),
          mondo_term_count      = NA_integer_,
          mondo_xref_count      = NA_integer_,
          mapping_count         = NA_integer_,
          disease_covered_count = NA_integer_,
          status                = "skipped",
          build_started_at      = build_started_at,
          build_finished_at     = finished_at,
          build_duration_s      = as.numeric(difftime(finished_at, build_started_at, units = "secs"))
        ))
        return(list(
          status  = "skipped",
          success = TRUE,
          reason  = "not_modified",
          message = "MONDO OBO unchanged and tables populated; skipped rebuild",
          validators = list(obo_etag = obo_dl$etag, obo_last_modified = obo_dl$last_modified)
        ))
      }

      # Step 3: parse OBO + SSSOM.
      report("parse", "Parsing MONDO OBO + SSSOM...", current = 3, total = 6)
      obo_text   <- paste(readLines(obo_dl$path, warn = FALSE), collapse = "\n")
      parsed_obo <- mondo_obo_parse(obo_text)
      sssom_text <- paste(readLines(sssom_path, warn = FALSE), collapse = "\n")
      sssom_tbl  <- mondo_sssom_parse(sssom_text)

      release_version <- parsed_obo$version %||% NA_character_

      # Step 4: transactional rebuild — index write + derive + mapping write.
      report("rebuild", "Rebuilding index + derived mappings (transaction)...",
             current = 4, total = 6)
      mapping_tbl <- NULL
      DBI::dbWithTransaction(conn, {
        mondo_index_write(conn, parsed_obo, sssom_tbl, release_version)
        mapping_tbl <<- disease_mapping_derive(conn, MONDO_TARGET_ALLOWLIST)
        disease_mapping_write(conn, mapping_tbl, release_version)
      })

      # Step 5: collect counts for provenance.
      report("provenance", "Writing provenance meta row...", current = 5, total = 6)
      term_count  <- nrow(parsed_obo$terms)
      xref_count  <- tryCatch(
        as.integer(DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM mondo_xref")$n[[1]]),
        error = function(e) NA_integer_
      )
      mapping_count <- if (is.null(mapping_tbl)) 0L else nrow(mapping_tbl)
      disease_covered <- if (is.null(mapping_tbl) || nrow(mapping_tbl) == 0L) {
        0L
      } else {
        length(unique(mapping_tbl$disease_ontology_id))
      }

      finished_at <- Sys.time()
      write_meta_fn(conn, list(
        mondo_release_version = release_version,
        mondo_obo_url         = obo_url,
        mondo_sssom_url       = sssom_url,
        source_validators     = list(
          obo_etag = obo_dl$etag, obo_last_modified = obo_dl$last_modified
        ),
        mondo_term_count      = term_count,
        mondo_xref_count      = xref_count,
        mapping_count         = mapping_count,
        disease_covered_count = disease_covered,
        status                = "success",
        build_started_at      = build_started_at,
        build_finished_at     = finished_at,
        build_duration_s      = as.numeric(difftime(finished_at, build_started_at, units = "secs"))
      ))

      report("complete", "Disease ontology mapping refresh complete", current = 6, total = 6)

      list(
        status                = "success",
        success               = TRUE,
        reason                = "rebuilt",
        release_version       = release_version,
        mondo_term_count      = term_count,
        mondo_xref_count      = xref_count,
        mapping_count         = mapping_count,
        disease_covered_count = disease_covered,
        message = sprintf(
          "Disease ontology mapping refresh: release=%s terms=%s xrefs=%s mappings=%s diseases=%s",
          release_version, term_count, xref_count, mapping_count, disease_covered
        )
      )
    },
    error = function(e) {
      # A real refresh-step failure: record a failed provenance row and re-raise.
      finished_at <- Sys.time()
      tryCatch(
        write_meta_fn(conn, list(
          mondo_release_version = NA_character_,
          mondo_obo_url         = obo_url,
          mondo_sssom_url       = sssom_url,
          source_validators     = list(),
          mondo_term_count      = NA_integer_,
          mondo_xref_count      = NA_integer_,
          mapping_count         = NA_integer_,
          disease_covered_count = NA_integer_,
          status                = "failed",
          build_started_at      = build_started_at,
          build_finished_at     = finished_at,
          build_duration_s      = as.numeric(difftime(finished_at, build_started_at, units = "secs"))
        )),
        error = function(e2) NULL
      )
      stop(sprintf("Disease ontology mapping refresh failed: %s", conditionMessage(e)),
           call. = FALSE)
    }
  )

  result
}
