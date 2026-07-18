# functions/analysis-snapshot-release-repository.R
#
# DB persistence for immutable public analysis-snapshot RELEASES (#573 Slice
# A / Task A3). Reads/writes the three tables added by migration
# `045_add_analysis_snapshot_release.sql`: `analysis_snapshot_release` (head),
# `analysis_snapshot_release_member` (per-layer lineage), and
# `analysis_snapshot_release_file` (per-archive-file blob + checksum).
#
# Deliberately self-contained: uses raw `DBI::dbGetQuery()` / `DBI::dbExecute()`
# with bound `?` params (never string-interpolated identifiers) instead of the
# `db_execute_query()`/`db_execute_statement()` wrappers in `db-helpers.R`.
# Those wrappers eagerly stringify every param for a DEBUG log line — fine for
# scalar params, but for a LONGBLOB param (`list(<raw>)`) that would deparse
# the whole multi-MB blob on every call, mirroring the exact trap already
# documented in `analysis-reproducibility.R`'s
# `analysis_snapshot_insert_reproducibility()`. Blob columns (`bundle_gzip`,
# `content_gzip`) are always bound as `list(<raw vector>)`, per DBI's blob
# binding convention (verified against RMariaDB).
#
# `conn` is a REQUIRED, explicit DBI connection on every function here (no
# `conn = NULL` global-pool fallback like the sibling
# `analysis-snapshot-repository.R`). Two reasons: (1) `analysis_release_insert()`
# wraps its writes in one `DBI::dbWithTransaction(conn, {...})`, which needs a
# real `DBIConnection`, not a `Pool`; and (2) blob binding via
# `list(<raw vector>)` needs the same. Callers (services, later tasks) are
# responsible for resolving/checking out a real connection before calling in.
#
# IMPORTANT test/caller trap (verified live against RMariaDB): calling
# `analysis_release_insert()` on a connection that already has an open
# transaction raises "Nested transactions not supported" (RMariaDB's
# `dbBegin()` rejects it) — the same trap documented in
# `test-integration-additive-ontology-terms.R` /
# `test-integration-ontology-mapping-refresh.R`. Never call it from inside
# `with_test_db_transaction()`.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# --------------------------------------------------------------------------- #
# Internal helpers
# --------------------------------------------------------------------------- #

#' Unwrap a single-row blob column value to its raw vector.
#' @noRd
.analysis_release_blob <- function(x) {
  if (is.list(x)) x <- x[[1]]
  x
}

#' Coerce a possibly-NULL scalar to a bindable value, defaulting to NA.
#' @noRd
.analysis_release_chr <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  as.character(x[[1]])
}

#' Head-table column list shared by SELECTs (excludes the `bundle_gzip` blob
#' so metadata reads never pull the multi-MB bundle unless explicitly asked
#' for via `analysis_release_get_bundle()`).
#' @noRd
.analysis_release_head_columns <- paste(
  "release_id, release_version, title, status, manifest_schema_version,",
  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
  "source_data_version, db_release_version, db_release_commit, scope_statement,",
  "license, file_count, total_bytes, created_by_user_id, created_at,",
  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
  "version_doi, concept_doi, last_error_message"
)

#' Convert a single-row data.frame (as returned by dbGetQuery) into a plain
#' named list, one element per column.
#' @noRd
.analysis_release_row_to_list <- function(rows, i = 1L) {
  as.list(rows[i, , drop = FALSE])
}

# --------------------------------------------------------------------------- #
# Write
# --------------------------------------------------------------------------- #

#' Insert a release head + its members + its files in ONE transaction.
#'
#' `release_head` is a named list with (at least) `release_id`,
#' `manifest_schema_version`, `content_digest`, `manifest_sha256`,
#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
#' `scope_statement`, `license` (defaults `"CC-BY-4.0"`),
#' `created_by_user_id`. Always inserted with `status = 'draft'` —
#' `analysis_release_publish()` is the only way to flip it.
#'
#' `bundle_bytes`, `file_count`, `total_bytes` are derived here (not trusted
#' from the caller) from `bundle_gzip`/`files` directly, so they can never
#' drift from the actual stored bytes.
#'
#' `members` is a list of `list(analysis_type, parameter_hash, snapshot_id,
#' input_hash, payload_hash, schema_version, reproducibility_hash = NULL,
#' role = "layer")`.
#'
#' `files` is a list of `list(file_path, content_sha256, byte_size,
#' media_type = "application/json", content_gzip)` (`content_gzip` a raw
#' vector).
#'
#' @return chr, the inserted `release_id`.
#' @export
analysis_release_insert <- function(release_head, members = list(), files = list(), conn) {
  release_id <- .analysis_release_chr(release_head$release_id)
  if (is.na(release_id) || !nzchar(release_id)) {
    stop("release_head$release_id is required", call. = FALSE)
  }
  bundle_gzip <- release_head$bundle_gzip
  if (!is.raw(bundle_gzip)) {
    stop("release_head$bundle_gzip must be a raw vector", call. = FALSE)
  }

  file_count <- length(files)
  total_bytes <- sum(vapply(files, function(f) as.numeric(f$byte_size %||% 0), numeric(1)))

  DBI::dbWithTransaction(conn, {
    DBI::dbExecute(
      conn,
      "INSERT INTO analysis_snapshot_release (
         release_id, release_version, title, status, manifest_schema_version,
         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
         source_data_version, db_release_version, db_release_commit, scope_statement,
         license, file_count, total_bytes, created_by_user_id
       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      params = unname(list(
        release_id,
        .analysis_release_chr(release_head$release_version),
        .analysis_release_chr(release_head$title),
        .analysis_release_chr(release_head$manifest_schema_version),
        .analysis_release_chr(release_head$content_digest),
        .analysis_release_chr(release_head$manifest_sha256),
        .analysis_release_chr(release_head$bundle_sha256),
        list(bundle_gzip),
        length(bundle_gzip),
        .analysis_release_chr(release_head$source_data_version),
        .analysis_release_chr(release_head$db_release_version),
        .analysis_release_chr(release_head$db_release_commit),
        .analysis_release_chr(release_head$scope_statement),
        release_head$license %||% "CC-BY-4.0",
        as.integer(file_count),
        as.numeric(total_bytes),
        if (is.null(release_head$created_by_user_id)) NA_integer_ else as.integer(release_head$created_by_user_id)
      ))
    )

    for (m in members) {
      DBI::dbExecute(
        conn,
        "INSERT INTO analysis_snapshot_release_member (
           release_id, analysis_type, parameter_hash, snapshot_id, input_hash,
           payload_hash, schema_version, reproducibility_hash, role
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        params = unname(list(
          release_id,
          .analysis_release_chr(m$analysis_type),
          .analysis_release_chr(m$parameter_hash),
          as.numeric(m$snapshot_id),
          .analysis_release_chr(m$input_hash),
          .analysis_release_chr(m$payload_hash),
          .analysis_release_chr(m$schema_version),
          .analysis_release_chr(m$reproducibility_hash),
          m$role %||% "layer"
        ))
      )
    }

    for (f in files) {
      DBI::dbExecute(
        conn,
        "INSERT INTO analysis_snapshot_release_file (
           release_id, file_path, content_sha256, byte_size, media_type, content_gzip
         ) VALUES (?, ?, ?, ?, ?, ?)",
        params = unname(list(
          release_id,
          .analysis_release_chr(f$file_path),
          .analysis_release_chr(f$content_sha256),
          as.integer(f$byte_size),
          f$media_type %||% "application/json",
          list(f$content_gzip)
        ))
      )
    }
  })

  release_id
}

# --------------------------------------------------------------------------- #
# Read
# --------------------------------------------------------------------------- #

#' Fetch a release head (+ parsed manifest.json, if stored) by id.
#'
#' Draft rows are hidden unless `include_draft = TRUE` — the visibility
#' filter is applied in SQL (`AND status = 'published'`), not by fetching and
#' discarding in R.
#'
#' @return A named list (head columns + `$manifest`, the parsed manifest.json
#'   as a plain R list via `jsonlite::fromJSON(simplifyVector = FALSE)`), or
#'   `NULL` if no matching (visible) row exists.
#' @export
analysis_release_get <- function(release_id, include_draft = FALSE, conn) {
  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
  sql <- paste0(
    "SELECT ", .analysis_release_head_columns, "
       FROM analysis_snapshot_release
      WHERE release_id = ?", status_clause, "
      LIMIT 1"
  )
  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
  if (nrow(rows) == 0L) {
    return(NULL)
  }

  head <- .analysis_release_row_to_list(rows)

  manifest_file <- analysis_release_get_file(
    release_id, "manifest.json",
    include_draft = include_draft, conn = conn
  )
  head$manifest <- if (is.null(manifest_file)) {
    NULL
  } else {
    tryCatch(
      jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE),
      error = function(e) NULL
    )
  }

  head
}

#' List release heads (newest first), each with a `layers` member summary.
#'
#' `status = NULL` returns releases of every status; otherwise filters to the
#' given status (e.g. `"published"`, `"draft"`) in SQL.
#'
#' @return A list of named lists (head columns + `$layers`, a list of
#'   `list(analysis_type, snapshot_id, payload_hash)` for `role = 'layer'`
#'   members). Empty list if no rows match.
#' @export
analysis_release_list <- function(status = "published", limit = 50L, offset = 0L, conn) {
  where_clause <- ""
  params <- list()
  if (!is.null(status)) {
    where_clause <- " WHERE status = ?"
    params <- list(as.character(status))
  }
  sql <- paste0(
    "SELECT ", .analysis_release_head_columns, "
       FROM analysis_snapshot_release",
    where_clause,
    " ORDER BY created_at DESC LIMIT ? OFFSET ?"
  )
  params <- c(params, list(as.integer(limit), as.integer(offset)))
  rows <- DBI::dbGetQuery(conn, sql, params = unname(params))
  if (nrow(rows) == 0L) {
    return(list())
  }

  release_ids <- as.character(rows$release_id)
  placeholders <- paste(rep("?", length(release_ids)), collapse = ",")
  members <- DBI::dbGetQuery(
    conn,
    paste0(
      "SELECT release_id, analysis_type, snapshot_id, payload_hash
         FROM analysis_snapshot_release_member
        WHERE role = 'layer' AND release_id IN (", placeholders, ")
        ORDER BY release_id, analysis_type"
    ),
    params = unname(as.list(release_ids))
  )

  lapply(seq_len(nrow(rows)), function(i) {
    head <- .analysis_release_row_to_list(rows, i)
    rid <- as.character(head$release_id)
    layer_rows <- members[members$release_id == rid, , drop = FALSE]
    head$layers <- lapply(seq_len(nrow(layer_rows)), function(j) {
      list(
        analysis_type = as.character(layer_rows$analysis_type[[j]]),
        snapshot_id = layer_rows$snapshot_id[[j]],
        payload_hash = as.character(layer_rows$payload_hash[[j]])
      )
    })
    head
  })
}

#' Fetch one archive file's bytes by its exact (release_id, file_path) key.
#'
#' PK lookup only — no path building/concatenation. Draft-release files are
#' hidden unless `include_draft = TRUE` (a SQL join against the head table's
#' `status`, applied before any blob is fetched).
#'
#' @return `list(bytes = <raw, decompressed>, media_type = chr,
#'   content_sha256 = chr)`, or `NULL` if no matching (visible) row exists.
#' @export
analysis_release_get_file <- function(release_id, file_path, include_draft = FALSE, conn) {
  status_clause <- if (isTRUE(include_draft)) "" else " AND r.status = 'published'"
  sql <- paste0(
    "SELECT f.content_gzip, f.media_type, f.content_sha256
       FROM analysis_snapshot_release_file f
       JOIN analysis_snapshot_release r ON r.release_id = f.release_id
      WHERE f.release_id = ? AND f.file_path = ?", status_clause, "
      LIMIT 1"
  )
  rows <- DBI::dbGetQuery(
    conn, sql,
    params = unname(list(as.character(release_id), as.character(file_path)))
  )
  if (nrow(rows) == 0L) {
    return(NULL)
  }

  gz <- .analysis_release_blob(rows$content_gzip[[1]])
  list(
    bytes = memDecompress(gz, type = "gzip"),
    media_type = as.character(rows$media_type[[1]]),
    content_sha256 = as.character(rows$content_sha256[[1]])
  )
}

#' Fetch the whole release archive (`bundle_gzip`) verbatim.
#'
#' `bundle_gzip` is stored already-gzipped and served as-is — this does NOT
#' decompress it (unlike `analysis_release_get_file()`, which stores each
#' file's gzip as a transport-only encoding of JSON content). Draft releases
#' are hidden unless `include_draft = TRUE`, filtered in SQL.
#'
#' @return `list(bytes = <raw, verbatim gzip tar>, sha256 = chr, filename =
#'   "<release_id>.tar.gz")`, or `NULL` if no matching (visible) row exists.
#' @export
analysis_release_get_bundle <- function(release_id, include_draft = FALSE, conn) {
  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
  sql <- paste0(
    "SELECT bundle_gzip, bundle_sha256
       FROM analysis_snapshot_release
      WHERE release_id = ?", status_clause, "
      LIMIT 1"
  )
  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
  if (nrow(rows) == 0L) {
    return(NULL)
  }

  list(
    bytes = .analysis_release_blob(rows$bundle_gzip[[1]]),
    sha256 = as.character(rows$bundle_sha256[[1]]),
    filename = paste0(as.character(release_id), ".tar.gz")
  )
}

#' Check whether a release id exists (any status) — for idempotent creation.
#' @return logical(1).
#' @export
analysis_release_exists <- function(release_id, conn) {
  rows <- DBI::dbGetQuery(
    conn,
    "SELECT 1 AS found FROM analysis_snapshot_release WHERE release_id = ? LIMIT 1",
    params = unname(list(as.character(release_id)))
  )
  nrow(rows) > 0L
}

#' Distinct snapshot ids referenced by any release member (the later prune
#' guard uses this to never delete a snapshot a release still points to).
#' @return integer vector (possibly empty).
#' @export
analysis_release_referenced_snapshot_ids <- function(conn) {
  rows <- DBI::dbGetQuery(
    conn,
    "SELECT DISTINCT snapshot_id FROM analysis_snapshot_release_member"
  )
  as.integer(rows$snapshot_id)
}

# --------------------------------------------------------------------------- #
# Update / delete
# --------------------------------------------------------------------------- #

#' Publish a draft release (no-op if it is not currently a draft).
#' @return logical(1), TRUE iff the row flipped to published.
#' @export
analysis_release_publish <- function(release_id, conn) {
  affected <- DBI::dbExecute(
    conn,
    "UPDATE analysis_snapshot_release
        SET status = 'published', published_at = NOW(6)
      WHERE release_id = ? AND status = 'draft'",
    params = unname(list(as.character(release_id)))
  )
  affected > 0L
}

#' Record external Zenodo/DOI provenance on an existing release.
#'
#' Additive metadata only — updates whichever of `zenodo_record_id`,
#' `zenodo_record_url`, `version_doi`, `concept_doi` are present in
#' `doi_fields`; never touches `content_digest`/`manifest_sha256` (release
#' scientific identity is immutable once minted).
#'
#' @param doi_fields Named list, any subset of `zenodo_record_id`,
#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
#' @return logical(1), TRUE iff a row was updated.
#' @export
analysis_release_set_doi <- function(release_id, doi_fields = list(), conn) {
  allowed <- c("zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi")
  present <- intersect(names(doi_fields), allowed)
  if (length(present) == 0L) {
    return(FALSE)
  }

  set_clause <- paste(paste0(present, " = ?"), collapse = ", ")
  value_params <- lapply(present, function(k) .analysis_release_chr(doi_fields[[k]]))
  affected <- DBI::dbExecute(
    conn,
    paste0("UPDATE analysis_snapshot_release SET ", set_clause, " WHERE release_id = ?"),
    params = unname(c(value_params, list(as.character(release_id))))
  )
  affected > 0L
}

#' Delete a release ONLY while it is still a draft (children cascade via FK).
#'
#' Refuses (returns FALSE, no-op) once a release is published — releases are
#' immutable/retained-indefinitely once published; only an unpublished draft
#' can be discarded (e.g. a failed/aborted build).
#'
#' @return logical(1), TRUE iff a draft row was deleted.
#' @export
analysis_release_delete_draft <- function(release_id, conn) {
  affected <- DBI::dbExecute(
    conn,
    "DELETE FROM analysis_snapshot_release WHERE release_id = ? AND status = 'draft'",
    params = unname(list(as.character(release_id)))
  )
  affected > 0L
}
