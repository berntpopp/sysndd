# functions/analysis-snapshot-repository.R

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

analysis_snapshot_lock_name <- function(analysis_type, parameter_hash) {
  paste0(
    "analysis_snapshot_refresh:",
    as.character(analysis_type[[1]]),
    ":",
    as.character(parameter_hash[[1]])
  )
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

  code(db_connection)
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
         package_versions_json, row_counts_json, warnings_json, last_error_message
       ) VALUES (
         ?, ?, ?, ?, ?, 0, ?, COALESCE(?, NOW(6)), ?,
         ?, ?, ?, ?, ?, ?, ?,
         ?, ?, ?, ?
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
        analysis_snapshot_scalar(manifest$last_error_message, NA_character_)
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
    for (i in seq_len(nrow(nodes))) {
      node <- nodes[i, , drop = FALSE]
      db_execute_statement(
        "INSERT INTO analysis_snapshot_network_node (
           snapshot_id, hgnc_id, symbol, cluster_id, category, degree,
           x, y, layout_x, layout_y, igraph_x, igraph_y, display_order
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        unname(list(
          snapshot_id,
          node$hgnc_id[[1]],
          analysis_snapshot_scalar(node$symbol, NA_character_),
          analysis_snapshot_scalar(node$cluster_id, NA_character_),
          analysis_snapshot_scalar(node$category, NA_character_),
          analysis_snapshot_scalar(node$degree, NA_integer_),
          analysis_snapshot_scalar(node$x, NA_real_),
          analysis_snapshot_scalar(node$y, NA_real_),
          analysis_snapshot_scalar(node$layout_x, NA_real_),
          analysis_snapshot_scalar(node$layout_y, NA_real_),
          analysis_snapshot_scalar(node$igraph_x, NA_real_),
          analysis_snapshot_scalar(node$igraph_y, NA_real_),
          analysis_snapshot_scalar(node$display_order, NA_integer_)
        )),
        conn = conn
      )
    }
  }

  if (nrow(edges) > 0L) {
    for (i in seq_len(nrow(edges))) {
      edge <- edges[i, , drop = FALSE]
      db_execute_statement(
        "INSERT INTO analysis_snapshot_network_edge (
           snapshot_id, edge_rank, source_hgnc_id, target_hgnc_id, confidence
         ) VALUES (?, ?, ?, ?, ?)",
        unname(list(
          snapshot_id,
          edge$edge_rank[[1]],
          edge$source_hgnc_id[[1]],
          edge$target_hgnc_id[[1]],
          edge$confidence[[1]]
        )),
        conn = conn
      )
    }
  }

  invisible(list(nodes = nrow(nodes), edges = nrow(edges)))
}

analysis_snapshot_insert_cluster_rows <- function(snapshot_id, clusters, members, conn = NULL) {
  clusters <- tibble::as_tibble(clusters %||% tibble::tibble())
  members <- tibble::as_tibble(members %||% tibble::tibble())

  if (nrow(clusters) > 0L) {
    for (i in seq_len(nrow(clusters))) {
      cluster <- clusters[i, , drop = FALSE]
      db_execute_statement(
        "INSERT INTO analysis_snapshot_cluster (
           snapshot_id, cluster_kind, cluster_id, cluster_hash,
           cluster_size, label, metadata_json
         ) VALUES (?, ?, ?, ?, ?, ?, ?)",
        unname(list(
          snapshot_id,
          cluster$cluster_kind[[1]],
          cluster$cluster_id[[1]],
          analysis_snapshot_scalar(cluster$cluster_hash, NA_character_),
          analysis_snapshot_scalar(cluster$cluster_size, NA_integer_),
          analysis_snapshot_scalar(cluster$label, NA_character_),
          analysis_snapshot_scalar(cluster$metadata_json, NA_character_)
        )),
        conn = conn
      )
    }
  }

  if (nrow(members) > 0L) {
    for (i in seq_len(nrow(members))) {
      member <- members[i, , drop = FALSE]
      db_execute_statement(
        "INSERT INTO analysis_snapshot_cluster_member (
           snapshot_id, cluster_kind, cluster_id, member_rank,
           entity_id, hgnc_id, symbol
         ) VALUES (?, ?, ?, ?, ?, ?, ?)",
        unname(list(
          snapshot_id,
          member$cluster_kind[[1]],
          member$cluster_id[[1]],
          member$member_rank[[1]],
          analysis_snapshot_scalar(member$entity_id, NA_integer_),
          analysis_snapshot_scalar(member$hgnc_id, NA_character_),
          analysis_snapshot_scalar(member$symbol, NA_character_)
        )),
        conn = conn
      )
    }
  }

  invisible(list(clusters = nrow(clusters), members = nrow(members)))
}

analysis_snapshot_insert_correlation_rows <- function(snapshot_id, correlations, conn = NULL) {
  correlations <- tibble::as_tibble(correlations %||% tibble::tibble())
  if (nrow(correlations) == 0L) {
    return(invisible(0L))
  }

  for (i in seq_len(nrow(correlations))) {
    row <- correlations[i, , drop = FALSE]
    db_execute_statement(
      "INSERT INTO analysis_snapshot_correlation (
         snapshot_id, row_rank, correlation_kind, x_key, y_key,
         value, abs_value, metadata_json
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      unname(list(
        snapshot_id,
        row$row_rank[[1]],
        row$correlation_kind[[1]],
        row$x_key[[1]],
        row$y_key[[1]],
        row$value[[1]],
        row$abs_value[[1]],
        analysis_snapshot_scalar(row$metadata_json, NA_character_)
      )),
      conn = conn
    )
  }

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

analysis_snapshot_get_public <- function(analysis_type, parameter_hash, conn = NULL) {
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

  snapshot_id <- manifest$snapshot_id[[1]]
  list(
    manifest = manifest[1, , drop = FALSE],
    status_code = analysis_snapshot_status_code(manifest[1, , drop = FALSE]),
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
      "SELECT * FROM analysis_snapshot_cluster_member WHERE snapshot_id = ? ORDER BY cluster_kind, cluster_id, member_rank",
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

  source_version <- analysis_snapshot_scalar(row$source_data_version, NA_character_)
  current_version <- analysis_snapshot_scalar(row$current_source_data_version, NA_character_)
  if (is.na(current_version)) {
    current_version <- attr(row, "current_source_data_version", exact = TRUE)
  }
  if (!is.null(current_version) &&
      !is.na(current_version) &&
      !is.na(source_version) &&
      !identical(as.character(source_version), as.character(current_version))) {
    return("source_version_mismatch")
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

analysis_snapshot_source_data_version <- function(conn = NULL) {
  result <- db_execute_query(
    "SELECT SHA2(CONCAT_WS('|',
       (SELECT COUNT(*) FROM ndd_entity_view),
       (SELECT COUNT(*) FROM ndd_entity_review WHERE is_primary = 1 AND review_approved = 1),
       COALESCE((SELECT DATE_FORMAT(MAX(review_date), '%Y-%m-%dT%H:%i:%s.%f')
                   FROM ndd_entity_review
                  WHERE is_primary = 1 AND review_approved = 1), 'none'),
       (SELECT COUNT(*)
          FROM ndd_review_phenotype_connect rpc
          JOIN ndd_entity_review r ON r.review_id = rpc.review_id
         WHERE rpc.is_active = 1 AND r.is_primary = 1 AND r.review_approved = 1),
       COALESCE((SELECT DATE_FORMAT(MAX(rpc.phenotype_date), '%Y-%m-%dT%H:%i:%s.%f')
                   FROM ndd_review_phenotype_connect rpc
                   JOIN ndd_entity_review r ON r.review_id = rpc.review_id
                  WHERE rpc.is_active = 1 AND r.is_primary = 1 AND r.review_approved = 1), 'none'),
       (SELECT COUNT(*) FROM ndd_entity_status WHERE is_active = 1 AND status_approved = 1),
       COALESCE((SELECT DATE_FORMAT(MAX(status_date), '%Y-%m-%dT%H:%i:%s.%f')
                   FROM ndd_entity_status
                  WHERE is_active = 1 AND status_approved = 1), 'none')
     ), 256) AS source_data_version",
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

  cutoff <- Sys.time() - (keep_superseded_days * 86400)
  candidates <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND status = 'superseded'
        AND COALESCE(superseded_at, updated_at, created_at) < ?",
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
