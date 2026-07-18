# functions/analysis-snapshot-repository.R

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

analysis_snapshot_lock_name <- function(analysis_type, parameter_hash) {
  # MySQL GET_LOCK() names must be <= 64 characters (errno 4163 otherwise). The
  # previous "analysis_snapshot_refresh:<type>:<sha256>" form was 109-124 chars,
  # so GET_LOCK always failed and the refresh job aborted before writing a
  # snapshot -> permanent `snapshot_missing` on every public analysis endpoint.
  # parameter_hash is a 64-char SHA-256 that already encodes (analysis_type,
  # params) (see analysis_snapshot_parameter_hash), so a short prefix + a
  # truncated hash stays unique per preset while fitting the limit. analysis_type
  # is intentionally not inlined — the long preset names overflow the cap.
  paste0("asr:", substr(as.character(parameter_hash[[1]]), 1, 56))
}

analysis_snapshot_acquire_lock <- function(analysis_type,
                                           parameter_hash,
                                           timeout_seconds = 30L,
                                           conn = NULL) {
  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
  result <- db_execute_query(
    "SELECT GET_LOCK(?, ?) AS acquired",
    unname(list(lock_name, as.integer(timeout_seconds))),
    conn = conn
  )

  isTRUE(as.integer(result$acquired[[1]]) == 1L)
}

analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
  result <- db_execute_query(
    "SELECT RELEASE_LOCK(?) AS released",
    unname(list(lock_name)),
    conn = conn
  )

  invisible(isTRUE(as.integer(result$released[[1]]) == 1L))
}

analysis_snapshot_json <- function(value) {
  if (is.null(value)) {
    return(NA_character_)
  }

  as.character(jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    dataframe = "rows",
    POSIXt = "ISO8601",
    Date = "ISO8601"
  ))
}

analysis_snapshot_scalar <- function(value, default = NA) {
  if (is.null(value) || length(value) == 0L) {
    return(default)
  }

  value[[1]]
}

analysis_snapshot_with_repository_connection <- function(conn = NULL, code) {
  if (!is.null(conn) && inherits(conn, "Pool")) {
    checked_out <- pool::poolCheckout(conn)
    on.exit(pool::poolReturn(checked_out), add = TRUE)
    return(code(checked_out))
  }

  if (!is.null(conn)) {
    return(code(conn))
  }

  db_connection <- get_db_connection()
  if (inherits(db_connection, "Pool")) {
    checked_out <- pool::poolCheckout(db_connection)
    on.exit(pool::poolReturn(checked_out), add = TRUE)
    return(code(checked_out))
  }

  if (inherits(db_connection, "DBIConnection")) {
    is_daemon_conn <- base::exists("daemon_db_conn", envir = .GlobalEnv) &&
      identical(db_connection, base::get("daemon_db_conn", envir = .GlobalEnv))
    if (!is_daemon_conn) {
      on.exit(DBI::dbDisconnect(db_connection), add = TRUE)
    }
  }

  code(db_connection)
}

analysis_snapshot_append_rows <- function(table_name, rows, conn) {
  rows <- as.data.frame(rows, stringsAsFactors = FALSE)
  if (nrow(rows) == 0L) {
    return(invisible(0L))
  }
  DBI::dbAppendTable(conn, table_name, rows)
  invisible(nrow(rows))
}

analysis_snapshot_create_manifest <- function(manifest, conn = NULL) {
  generated_at <- analysis_snapshot_scalar(manifest$generated_at, NA)
  stale_after <- analysis_snapshot_scalar(manifest$stale_after, NA)

  analysis_snapshot_with_repository_connection(conn, function(manifest_conn) {
    db_execute_statement(
      "INSERT INTO analysis_snapshot_manifest (
         analysis_type, parameter_hash, schema_version, data_class, status,
         public_ready, generated_by_job_id, generated_at, stale_after,
         source_versions_json, source_data_version, parameters_json,
         input_hash, payload_hash, algorithm_name, algorithm_version,
         package_versions_json, row_counts_json, warnings_json, last_error_message,
         validation_json, db_release_version, db_release_commit
       ) VALUES (
         ?, ?, ?, ?, ?, 0, ?, COALESCE(?, NOW(6)), ?,
         ?, ?, ?, ?, ?, ?, ?,
         ?, ?, ?, ?,
         ?, ?, ?
       )",
      unname(list(
        manifest$analysis_type,
        manifest$parameter_hash,
        manifest$schema_version,
        manifest$data_class,
        manifest$status %||% "pending",
        analysis_snapshot_scalar(manifest$generated_by_job_id, NA_character_),
        generated_at,
        stale_after,
        analysis_snapshot_json(manifest$source_versions),
        analysis_snapshot_scalar(manifest$source_data_version, NA_character_),
        manifest$parameters_json,
        manifest$input_hash,
        manifest$payload_hash,
        analysis_snapshot_scalar(manifest$algorithm_name, NA_character_),
        analysis_snapshot_scalar(manifest$algorithm_version, NA_character_),
        analysis_snapshot_json(manifest$package_versions),
        analysis_snapshot_json(manifest$row_counts),
        analysis_snapshot_json(manifest$warnings),
        analysis_snapshot_scalar(manifest$last_error_message, NA_character_),
        analysis_snapshot_json(manifest$validation),                       # JSON column
        analysis_snapshot_scalar(manifest$db_release_version, NA_character_),
        analysis_snapshot_scalar(manifest$db_release_commit,  NA_character_)
      )),
      conn = manifest_conn
    )

    id <- db_execute_query("SELECT LAST_INSERT_ID() AS snapshot_id", conn = manifest_conn)
    as.numeric(id$snapshot_id[[1]])
  })
}

analysis_snapshot_insert_network_rows <- function(snapshot_id, rows, conn = NULL) {
  nodes <- tibble::as_tibble(rows$nodes %||% tibble::tibble())
  edges <- tibble::as_tibble(rows$edges %||% tibble::tibble())

  if (nrow(nodes) > 0L) {
    node_rows <- data.frame(
      snapshot_id = rep(snapshot_id, nrow(nodes)),
      hgnc_id = as.character(nodes$hgnc_id),
      symbol = as.character(nodes$symbol),
      cluster_id = as.character(nodes$cluster_id),
      category = as.character(nodes$category),
      degree = suppressWarnings(as.integer(nodes$degree)),
      x = suppressWarnings(as.numeric(nodes$x)),
      y = suppressWarnings(as.numeric(nodes$y)),
      layout_x = suppressWarnings(as.numeric(nodes$layout_x)),
      layout_y = suppressWarnings(as.numeric(nodes$layout_y)),
      igraph_x = suppressWarnings(as.numeric(nodes$igraph_x)),
      igraph_y = suppressWarnings(as.numeric(nodes$igraph_y)),
      display_order = suppressWarnings(as.integer(nodes$display_order)),
      stringsAsFactors = FALSE
    )
    analysis_snapshot_append_rows("analysis_snapshot_network_node", node_rows, conn)
  }

  if (nrow(edges) > 0L) {
    edge_rows <- data.frame(
      snapshot_id = rep(snapshot_id, nrow(edges)),
      edge_rank = suppressWarnings(as.integer(edges$edge_rank)),
      source_hgnc_id = as.character(edges$source_hgnc_id),
      target_hgnc_id = as.character(edges$target_hgnc_id),
      confidence = suppressWarnings(as.numeric(edges$confidence)),
      stringsAsFactors = FALSE
    )
    analysis_snapshot_append_rows("analysis_snapshot_network_edge", edge_rows, conn)
  }

  invisible(list(nodes = nrow(nodes), edges = nrow(edges)))
}

analysis_snapshot_insert_cluster_rows <- function(snapshot_id, clusters, members, conn = NULL) {
  clusters <- tibble::as_tibble(clusters %||% tibble::tibble())
  members <- tibble::as_tibble(members %||% tibble::tibble())

  if (nrow(clusters) > 0L) {
    cluster_rows <- data.frame(
      snapshot_id = rep(snapshot_id, nrow(clusters)),
      cluster_kind = as.character(clusters$cluster_kind),
      cluster_id = as.character(clusters$cluster_id),
      cluster_hash = as.character(clusters$cluster_hash),
      cluster_size = suppressWarnings(as.integer(clusters$cluster_size)),
      label = as.character(clusters$label),
      metadata_json = as.character(clusters$metadata_json),
      stringsAsFactors = FALSE
    )
    analysis_snapshot_append_rows("analysis_snapshot_cluster", cluster_rows, conn)
  }

  if (nrow(members) > 0L) {
    member_rows <- data.frame(
      snapshot_id = rep(snapshot_id, nrow(members)),
      cluster_kind = as.character(members$cluster_kind),
      cluster_id = as.character(members$cluster_id),
      member_rank = suppressWarnings(as.integer(members$member_rank)),
      entity_id = suppressWarnings(as.integer(members$entity_id)),
      hgnc_id = as.character(members$hgnc_id),
      symbol = as.character(members$symbol),
      stringsAsFactors = FALSE
    )
    analysis_snapshot_append_rows("analysis_snapshot_cluster_member", member_rows, conn)
  }

  invisible(list(clusters = nrow(clusters), members = nrow(members)))
}

analysis_snapshot_insert_correlation_rows <- function(snapshot_id, correlations, conn = NULL) {
  correlations <- tibble::as_tibble(correlations %||% tibble::tibble())
  if (nrow(correlations) == 0L) {
    return(invisible(0L))
  }

  correlation_rows <- data.frame(
    snapshot_id = rep(snapshot_id, nrow(correlations)),
    row_rank = suppressWarnings(as.integer(correlations$row_rank)),
    correlation_kind = as.character(correlations$correlation_kind),
    x_key = as.character(correlations$x_key),
    y_key = as.character(correlations$y_key),
    value = suppressWarnings(as.numeric(correlations$value)),
    abs_value = suppressWarnings(as.numeric(correlations$abs_value)),
    metadata_json = as.character(correlations$metadata_json),
    stringsAsFactors = FALSE
  )
  analysis_snapshot_append_rows("analysis_snapshot_correlation", correlation_rows, conn)

  invisible(nrow(correlations))
}

analysis_snapshot_activate <- function(snapshot_id,
                                       analysis_type,
                                       parameter_hash,
                                       conn = NULL,
                                       use_transaction = TRUE) {
  tx <- function(txn_conn) {
    db_execute_statement(
      "UPDATE analysis_snapshot_manifest
          SET public_ready = 0,
              status = 'superseded',
              superseded_at = NOW(6)
        WHERE analysis_type = ?
          AND parameter_hash = ?
          AND public_ready = 1
          AND snapshot_id <> ?",
      unname(list(analysis_type, parameter_hash, snapshot_id)),
      conn = txn_conn
    )

    affected <- db_execute_statement(
      "UPDATE analysis_snapshot_manifest
          SET public_ready = 1,
              status = 'public_ready',
              activated_at = NOW(6),
              last_error_message = NULL
        WHERE snapshot_id = ?
          AND analysis_type = ?
          AND parameter_hash = ?",
      unname(list(snapshot_id, analysis_type, parameter_hash)),
      conn = txn_conn
    )

    if (affected != 1L) {
      stop("Analysis snapshot activation target was not found", call. = FALSE)
    }

    invisible(snapshot_id)
  }

  if (!isTRUE(use_transaction)) {
    return(tx(conn))
  }

  if (exists("db_with_transaction", mode = "function")) {
    return(db_with_transaction(function(txn_conn) {
      tx(txn_conn)
    }, pool_obj = conn))
  }

  DBI::dbWithTransaction(conn, tx(conn))
}

analysis_snapshot_get_public <- function(analysis_type,
                                         parameter_hash,
                                         conn = NULL,
                                         current_source_data_version = NULL) {
  manifest <- db_execute_query(
    "SELECT *
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND public_ready = 1
        AND status = 'public_ready'
      ORDER BY activated_at DESC, snapshot_id DESC
      LIMIT 1",
    unname(list(analysis_type, parameter_hash)),
    conn = conn
  )

  if (nrow(manifest) == 0L) {
    return(NULL)
  }

  if (is.null(current_source_data_version) &&
    exists("analysis_snapshot_source_data_version", mode = "function")) {
    current_source_data_version <- tryCatch(
      analysis_snapshot_source_data_version(conn = conn),
      error = function(e) NULL
    )
  }
  if (!is.null(current_source_data_version)) {
    manifest$current_source_data_version <- as.character(current_source_data_version)[1]
  }

  manifest <- manifest[1, , drop = FALSE]
  status_code <- analysis_snapshot_status_code(manifest)
  if (identical(status_code, "available") &&
      identical(as.character(analysis_type[[1]]), "phenotype_functional_correlations")) {
    if (!exists("analysis_snapshot_dependency_status_code", mode = "function")) {
      status_code <- "dependency_snapshot_mismatch"
    } else {
      status_code <- analysis_snapshot_dependency_status_code(manifest, conn = conn)
    }
  }
  if (!identical(status_code, "available")) {
    return(list(
      manifest = manifest,
      status_code = status_code
    ))
  }

  snapshot_id <- manifest$snapshot_id[[1]]
  list(
    manifest = manifest,
    status_code = status_code,
    network_nodes = db_execute_query(
      "SELECT * FROM analysis_snapshot_network_node WHERE snapshot_id = ? ORDER BY display_order, hgnc_id",
      unname(list(snapshot_id)),
      conn = conn
    ),
    network_edges = db_execute_query(
      "SELECT * FROM analysis_snapshot_network_edge WHERE snapshot_id = ? ORDER BY edge_rank",
      unname(list(snapshot_id)),
      conn = conn
    ),
    clusters = db_execute_query(
      "SELECT * FROM analysis_snapshot_cluster WHERE snapshot_id = ? ORDER BY cluster_kind, cluster_id",
      unname(list(snapshot_id)),
      conn = conn
    ),
    cluster_members = db_execute_query(
      paste(
        "SELECT * FROM analysis_snapshot_cluster_member",
        "WHERE snapshot_id = ?",
        "ORDER BY cluster_kind, cluster_id, member_rank"
      ),
      unname(list(snapshot_id)),
      conn = conn
    ),
    correlations = db_execute_query(
      "SELECT * FROM analysis_snapshot_correlation WHERE snapshot_id = ? ORDER BY row_rank",
      unname(list(snapshot_id)),
      conn = conn
    )
  )
}

analysis_snapshot_status_code <- function(row) {
  if (is.null(row) || length(row) == 0L || (is.data.frame(row) && nrow(row) == 0L)) {
    return("snapshot_missing")
  }

  # Source-data version is the primary freshness signal (more informative when
  # both differ), so it is checked before the schema-version bump below.
  source_version <- analysis_snapshot_scalar(row$source_data_version, NA_character_)
  current_version <- if ("current_source_data_version" %in% names(row)) {
    analysis_snapshot_scalar(row$current_source_data_version, NA_character_)
  } else {
    NA_character_
  }
  if (is.na(current_version)) {
    current_version <- attr(row, "current_source_data_version", exact = TRUE)
  }
  if (!is.null(current_version) &&
    !is.na(current_version) &&
    !is.na(source_version) &&
    !identical(as.character(source_version), as.character(current_version))) {
    return("source_version_mismatch")
  }

  # Rebuild on a snapshot-schema bump even when source data is unchanged (#483):
  # a stored schema_version != the code's ANALYSIS_SNAPSHOT_SCHEMA_VERSION is
  # treated as not-current (like source_version_mismatch) so it self-heals.
  expected_schema <- tryCatch(as.character(ANALYSIS_SNAPSHOT_SCHEMA_VERSION)[1], error = function(e) NA_character_)
  stored_schema <- analysis_snapshot_scalar(row$schema_version, NA_character_)
  if (!is.na(expected_schema) && !is.na(stored_schema) && nzchar(stored_schema) &&
    !identical(stored_schema, expected_schema)) {
    return("schema_version_mismatch")
  }

  stale_after <- analysis_snapshot_scalar(row$stale_after, NA)
  if (!is.null(stale_after) && length(stale_after) > 0L && !is.na(stale_after)) {
    stale_at <- as.POSIXct(stale_after, tz = "UTC")
    if (!is.na(stale_at) && stale_at < Sys.time()) {
      return("snapshot_stale")
    }
  }

  "available"
}

#' Cheap existence probe for an active public-ready snapshot.
#'
#' Mirrors the public-ready predicate of `analysis_snapshot_get_public()` but
#' fetches no child-table rows — used by the startup bootstrap and admin refresh
#' to decide whether a preset still needs a refresh job.
#'
#' @return TRUE when a `public_ready = 1, status = 'public_ready'` manifest row
#'   exists for the (analysis_type, parameter_hash); FALSE otherwise.
#' @export
analysis_snapshot_public_exists <- function(analysis_type, parameter_hash, conn = NULL) {
  row <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND public_ready = 1
        AND status = 'public_ready'
      LIMIT 1",
    unname(list(analysis_type, parameter_hash)),
    conn = conn
  )
  nrow(row) > 0L
}

#' Metadata-only read of the active public-ready manifest row.
#'
#' Like `analysis_snapshot_get_public()` but returns just the single manifest row
#' annotated with the computed `status_code` (no network/cluster/correlation
#' child queries). Used by the admin status endpoint to report per-preset state.
#'
#' @return A 1-row data frame with an added `status_code` column, or NULL when no
#'   public-ready row exists.
#' @export
analysis_snapshot_public_manifest <- function(analysis_type,
                                              parameter_hash,
                                              conn = NULL,
                                              current_source_data_version = NULL) {
  manifest <- db_execute_query(
    "SELECT *
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND public_ready = 1
        AND status = 'public_ready'
      ORDER BY activated_at DESC, snapshot_id DESC
      LIMIT 1",
    unname(list(analysis_type, parameter_hash)),
    conn = conn
  )

  if (nrow(manifest) == 0L) {
    return(NULL)
  }

  if (is.null(current_source_data_version) &&
    exists("analysis_snapshot_source_data_version", mode = "function")) {
    current_source_data_version <- tryCatch(
      analysis_snapshot_source_data_version(conn = conn),
      error = function(e) NULL
    )
  }

  manifest <- manifest[1, , drop = FALSE]
  if (!is.null(current_source_data_version)) {
    manifest$current_source_data_version <- as.character(current_source_data_version)[1]
  }
  manifest$status_code <- analysis_snapshot_status_code(manifest)
  manifest
}

#' Cheap "is the active public snapshot CURRENT?" probe.
#'
#' Unlike `analysis_snapshot_public_exists()` (which only checks that a
#' public-ready row exists), this returns TRUE only when that row is also
#' *current* — its computed `status_code` is `"available"`, not `snapshot_stale`
#' or `source_version_mismatch`. Used as the skip predicate by the startup
#' bootstrap and the non-force admin refresh so a STALE or VERSION-MISMATCHED
#' snapshot is re-enqueued (self-heals on restart) instead of being treated as
#' "already present" and left serving a permanent 503. The #420/#440 self-heal
#' only covered `snapshot_missing`; a snapshot that aged past `stale_after`
#' (default 7 days) never refreshed on its own. See AGENTS.md "Public analysis
#' endpoints".
#'
#' @param manifest_fn Injectable manifest read (default
#'   `analysis_snapshot_public_manifest`) so this is unit-testable without a DB.
#' @return TRUE only when a public-ready snapshot exists and is current.
#' @export
analysis_snapshot_public_current <- function(analysis_type,
                                             parameter_hash,
                                             conn = NULL,
                                             manifest_fn = analysis_snapshot_public_manifest) {
  manifest <- tryCatch(
    manifest_fn(analysis_type, parameter_hash, conn = conn),
    error = function(e) NULL
  )
  if (is.null(manifest) ||
    (is.data.frame(manifest) && nrow(manifest) == 0L)) {
    return(FALSE)
  }
  identical(as.character(manifest$status_code)[1], "available")
}

analysis_snapshot_source_data_version <- function(conn = NULL) {
  result <- db_execute_query(
    "SELECT source_data_version
       FROM mcp_public_analysis_source_version
      LIMIT 1",
    conn = conn
  )

  as.character(result$source_data_version[[1]])
}

analysis_snapshot_prune <- function(analysis_type,
                                    parameter_hash,
                                    keep_public_ready = 3L,
                                    keep_superseded_days = 14L,
                                    conn = NULL) {
  keep_public_ready <- max(1L, as.integer(keep_public_ready))
  keep_superseded_days <- max(0L, as.integer(keep_superseded_days))

  keep_rows <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND status IN ('public_ready', 'superseded')
      ORDER BY COALESCE(activated_at, generated_at, created_at) DESC, snapshot_id DESC
      LIMIT ?",
    unname(list(analysis_type, parameter_hash, keep_public_ready)),
    conn = conn
  )
  keep_ids <- as.numeric(keep_rows$snapshot_id %||% numeric())

  cutoff_time <- as.POSIXct(Sys.time() - (keep_superseded_days * 86400), tz = "UTC")
  cutoff <- format(cutoff_time, "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
  # Exclude anything a release (#573 Slice A) still references: the release's
  # own frozen files don't need the source row, but its LIVE reproducibility
  # endpoint would 503 if the still-cited manifest row vanished.
  candidates <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND status = 'superseded'
        AND COALESCE(superseded_at, updated_at, created_at) < ?
        AND snapshot_id NOT IN (SELECT snapshot_id FROM analysis_snapshot_release_member)",
    unname(list(analysis_type, parameter_hash, cutoff)),
    conn = conn
  )

  delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), keep_ids)
  if (length(delete_ids) == 0L) {
    return(invisible(0L))
  }

  placeholders <- paste(rep("?", length(delete_ids)), collapse = ", ")
  db_execute_statement(
    paste0("DELETE FROM analysis_snapshot_manifest WHERE snapshot_id IN (", placeholders, ")"),
    unname(as.list(delete_ids)),
    conn = conn
  )
}
