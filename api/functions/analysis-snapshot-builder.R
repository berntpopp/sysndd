# functions/analysis-snapshot-builder.R

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

analysis_snapshot_hash_json <- function(value) {
  if (exists("analysis_snapshot_canonical_json", mode = "function")) {
    return(analysis_snapshot_canonical_json(value))
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

analysis_snapshot_payload_hash <- function(payload) {
  digest::digest(analysis_snapshot_hash_json(payload), algo = "sha256", serialize = FALSE)
}

analysis_snapshot_input_hash <- function(inputs) {
  digest::digest(analysis_snapshot_hash_json(inputs), algo = "sha256", serialize = FALSE)
}

analysis_snapshot_column <- function(rows, name, default) {
  if (name %in% names(rows)) {
    return(rows[[name]])
  }

  rep(default, nrow(rows))
}

analysis_snapshot_metadata_json <- function(row, excluded_names) {
  metadata_names <- setdiff(names(row), excluded_names)
  if (length(metadata_names) == 0L) {
    return(NA_character_)
  }

  metadata <- stats::setNames(vector("list", length(metadata_names)), metadata_names)
  for (name in metadata_names) {
    value <- row[[name]][[1]]
    if (is.null(value) || length(value) == 0L) {
      metadata[[name]] <- NULL
    } else if (is.atomic(value) && length(value) == 1L && is.na(value)) {
      metadata[[name]] <- NULL
    } else {
      metadata[[name]] <- value
    }
  }
  if (length(metadata) == 0L) {
    return(NA_character_)
  }

  as.character(jsonlite::toJSON(metadata, auto_unbox = TRUE, null = "null", na = "null"))
}

analysis_snapshot_build_network_rows <- function(network) {
  nodes_in <- tibble::as_tibble(network$nodes %||% tibble::tibble())
  edges_in <- tibble::as_tibble(network$edges %||% tibble::tibble())

  nodes <- if (nrow(nodes_in) > 0L) {
    tibble::tibble(
      hgnc_id = as.character(analysis_snapshot_column(nodes_in, "hgnc_id", NA_character_)),
      symbol = as.character(analysis_snapshot_column(nodes_in, "symbol", NA_character_)),
      cluster_id = as.character(analysis_snapshot_column(
        nodes_in,
        if ("cluster_id" %in% names(nodes_in)) "cluster_id" else "cluster",
        NA_character_
      )),
      category = as.character(analysis_snapshot_column(nodes_in, "category", NA_character_)),
      degree = suppressWarnings(as.integer(analysis_snapshot_column(nodes_in, "degree", NA_integer_))),
      x = suppressWarnings(as.numeric(analysis_snapshot_column(nodes_in, "x", NA_real_))),
      y = suppressWarnings(as.numeric(analysis_snapshot_column(nodes_in, "y", NA_real_))),
      layout_x = suppressWarnings(as.numeric(analysis_snapshot_column(nodes_in, "layout_x", NA_real_))),
      layout_y = suppressWarnings(as.numeric(analysis_snapshot_column(nodes_in, "layout_y", NA_real_))),
      igraph_x = suppressWarnings(as.numeric(analysis_snapshot_column(nodes_in, "igraph_x", NA_real_))),
      igraph_y = suppressWarnings(as.numeric(analysis_snapshot_column(nodes_in, "igraph_y", NA_real_))),
      display_order = seq_len(nrow(nodes_in))
    )
  } else {
    tibble::tibble(
      hgnc_id = character(),
      symbol = character(),
      cluster_id = character(),
      category = character(),
      degree = integer(),
      x = numeric(),
      y = numeric(),
      layout_x = numeric(),
      layout_y = numeric(),
      igraph_x = numeric(),
      igraph_y = numeric(),
      display_order = integer()
    )
  }
  if (nrow(nodes) > 0L) {
    node_key <- as.character(nodes$hgnc_id)
    keep <- !is.na(node_key) & nzchar(node_key) & !duplicated(node_key)
    nodes <- nodes[keep, , drop = FALSE]
    nodes$display_order <- seq_len(nrow(nodes))
  }

  edges <- if (nrow(edges_in) > 0L) {
    source_col <- if ("source_hgnc_id" %in% names(edges_in)) "source_hgnc_id" else "source"
    target_col <- if ("target_hgnc_id" %in% names(edges_in)) "target_hgnc_id" else "target"
    tibble::tibble(
      edge_rank = seq_len(nrow(edges_in)),
      source_hgnc_id = as.character(analysis_snapshot_column(edges_in, source_col, NA_character_)),
      target_hgnc_id = as.character(analysis_snapshot_column(edges_in, target_col, NA_character_)),
      confidence = suppressWarnings(as.numeric(analysis_snapshot_column(edges_in, "confidence", NA_real_)))
    )
  } else {
    tibble::tibble(
      edge_rank = integer(),
      source_hgnc_id = character(),
      target_hgnc_id = character(),
      confidence = numeric()
    )
  }

  list(
    nodes = nodes,
    edges = edges,
    row_counts = list(nodes = nrow(nodes), edges = nrow(edges))
  )
}

#' Extract the canonical cluster hash (SHA-256) from a clustering result's
#' `hash_filter` column.
#'
#' Clustering carries `hash_filter` as a filter expression `equals(hash,XXX)`
#' (or already a bare hash). The `analysis_snapshot_cluster.cluster_hash` column
#' is CHAR(64), so we must store the inner `XXX`, not the whole expression —
#' otherwise the INSERT overflows ("Data too long for column 'cluster_hash'",
#' errno 1406), the refresh transaction rolls back, and every public analysis
#' endpoint stays on `snapshot_missing`. Mirrors the extraction in
#' `llm-batch-generator.R` so the snapshot and the LLM summary cache agree on the
#' cluster key.
#' @noRd
analysis_snapshot_extract_cluster_hash <- function(hash_filter) {
  vapply(
    as.character(hash_filter),
    function(h) {
      if (is.na(h) || !nzchar(h)) {
        return(NA_character_)
      }
      if (grepl("^equals\\(hash,", h)) {
        sub("^equals\\(hash,(.*)\\)$", "\\1", h)
      } else {
        h
      }
    },
    character(1),
    USE.NAMES = FALSE
  )
}

analysis_snapshot_build_cluster_rows <- function(clusters, cluster_kind) {
  clusters_in <- tibble::as_tibble(clusters %||% tibble::tibble())
  if (nrow(clusters_in) == 0L) {
    return(list(
      clusters = tibble::tibble(
        cluster_kind = character(),
        cluster_id = character(),
        cluster_hash = character(),
        cluster_size = integer(),
        label = character(),
        metadata_json = character()
      ),
      members = tibble::tibble(
        cluster_kind = character(),
        cluster_id = character(),
        member_rank = integer(),
        entity_id = integer(),
        hgnc_id = character(),
        symbol = character()
      ),
      row_counts = list(clusters = 0L, members = 0L)
    ))
  }

  cluster_id_col <- if ("cluster_id" %in% names(clusters_in)) "cluster_id" else "cluster"
  cluster_ids <- as.character(clusters_in[[cluster_id_col]])
  cluster_hashes <- analysis_snapshot_extract_cluster_hash(
    analysis_snapshot_column(clusters_in, "hash_filter", NA_character_)
  )
  cluster_sizes <- suppressWarnings(as.integer(analysis_snapshot_column(clusters_in, "cluster_size", NA_integer_)))
  labels <- as.character(analysis_snapshot_column(
    clusters_in,
    if ("label" %in% names(clusters_in)) "label" else "name",
    NA_character_
  ))

  cluster_rows <- tibble::tibble(
    cluster_kind = as.character(cluster_kind),
    cluster_id = cluster_ids,
    cluster_hash = cluster_hashes,
    cluster_size = cluster_sizes,
    label = labels,
    metadata_json = vapply(
      seq_len(nrow(clusters_in)),
      function(i) {
        analysis_snapshot_metadata_json(
          clusters_in[i, , drop = FALSE],
          c(cluster_id_col, "cluster_id", "cluster", "hash_filter", "cluster_size", "label", "name", "identifiers")
        )
      },
      character(1)
    )
  )

  member_rows <- lapply(seq_len(nrow(clusters_in)), function(i) {
    identifiers <- if ("identifiers" %in% names(clusters_in)) clusters_in$identifiers[[i]] else NULL
    identifiers <- tibble::as_tibble(identifiers %||% tibble::tibble())
    if (nrow(identifiers) == 0L) {
      return(tibble::tibble())
    }

    tibble::tibble(
      cluster_kind = as.character(cluster_kind),
      cluster_id = cluster_ids[[i]],
      member_rank = seq_len(nrow(identifiers)),
      entity_id = suppressWarnings(as.integer(analysis_snapshot_column(identifiers, "entity_id", NA_integer_))),
      hgnc_id = as.character(analysis_snapshot_column(identifiers, "hgnc_id", NA_character_)),
      symbol = as.character(analysis_snapshot_column(identifiers, "symbol", NA_character_))
    )
  })
  members <- dplyr::bind_rows(member_rows)

  list(
    clusters = cluster_rows,
    members = members,
    row_counts = list(clusters = nrow(cluster_rows), members = nrow(members))
  )
}

analysis_snapshot_build_correlation_rows <- function(rows, correlation_kind) {
  rows_in <- tibble::as_tibble(rows %||% tibble::tibble())
  if (nrow(rows_in) == 0L) {
    correlations <- tibble::tibble(
      row_rank = integer(),
      correlation_kind = character(),
      x_key = character(),
      y_key = character(),
      value = numeric(),
      abs_value = numeric(),
      metadata_json = character()
    )
  } else {
    correlations <- tibble::tibble(
      row_rank = seq_len(nrow(rows_in)),
      correlation_kind = as.character(correlation_kind),
      x_key = as.character(analysis_snapshot_column(rows_in, "x", NA_character_)),
      y_key = as.character(analysis_snapshot_column(rows_in, "y", NA_character_)),
      value = suppressWarnings(as.numeric(analysis_snapshot_column(rows_in, "value", NA_real_))),
      abs_value = abs(suppressWarnings(as.numeric(analysis_snapshot_column(rows_in, "value", NA_real_)))),
      metadata_json = vapply(
        seq_len(nrow(rows_in)),
        function(i) analysis_snapshot_metadata_json(rows_in[i, , drop = FALSE], c("x", "y", "value")),
        character(1)
      )
    )
    valid_rows <- !is.na(correlations$x_key) &
      nzchar(correlations$x_key) &
      !is.na(correlations$y_key) &
      nzchar(correlations$y_key) &
      is.finite(correlations$value)
    correlations <- correlations[valid_rows, , drop = FALSE]
    if (nrow(correlations) > 0L) {
      correlations$row_rank <- seq_len(nrow(correlations))
      correlations$abs_value <- abs(correlations$value)
    }
  }

  list(
    correlations = correlations,
    row_counts = list(correlations = nrow(correlations))
  )
}

analysis_snapshot_with_refresh_connection <- function(conn = NULL, code) {
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

analysis_snapshot_with_write_transaction <- function(conn, code) {
  if (exists("db_with_transaction", mode = "function")) {
    return(db_with_transaction(function(txn_conn) {
      code(txn_conn)
    }, pool_obj = conn))
  }

  DBI::dbWithTransaction(conn, code(conn))
}

analysis_snapshot_stale_after <- function(now = Sys.time()) {
  days <- suppressWarnings(as.numeric(Sys.getenv("ANALYSIS_SNAPSHOT_STALE_AFTER_DAYS", unset = "7")))
  if (is.na(days) || days <= 0) {
    days <- 7
  }
  as.POSIXct(now, tz = "UTC") + (days * 86400)
}

analysis_snapshot_cluster_llm_type <- function(analysis_type) {
  switch(as.character(analysis_type[[1]]),
    functional_clusters = "functional",
    phenotype_clusters = "phenotype",
    NULL
  )
}

analysis_snapshot_trigger_llm_generation <- function(analysis_type, payload, parent_job_id = NULL) {
  cluster_type <- analysis_snapshot_cluster_llm_type(analysis_type)
  if (is.null(cluster_type)) {
    return(NULL)
  }
  if (!exists("trigger_llm_batch_generation", mode = "function")) {
    return(list(skipped = TRUE, reason = "llm_trigger_unavailable"))
  }

  clusters <- payload$raw %||% tibble::tibble()
  if (is.null(clusters) || (is.data.frame(clusters) && nrow(clusters) == 0L)) {
    return(list(skipped = TRUE, reason = "empty_clusters"))
  }

  tryCatch(
    trigger_llm_batch_generation(
      clusters,
      cluster_type = cluster_type,
      parent_job_id = as.character(parent_job_id %||% "")
    ),
    error = function(e) {
      list(
        success = FALSE,
        error = conditionMessage(e),
        cluster_type = cluster_type
      )
    }
  )
}

analysis_snapshot_approved_gene_ids <- function(conn = NULL) {
  rows <- db_execute_query(
    "SELECT DISTINCT hgnc_id
       FROM ndd_entity_view
      WHERE hgnc_id IS NOT NULL
        AND ndd_phenotype = 1
      ORDER BY hgnc_id",
    conn = conn
  )

  as.character(rows$hgnc_id)
}

analysis_snapshot_build_payload <- function(analysis_type, params, conn = NULL) {
  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
  params <- normalized$params

  switch(normalized$analysis_type,
    functional_clusters = {
      gene_ids <- analysis_snapshot_approved_gene_ids(conn = conn)
      clusters <- gen_string_clust_obj_mem(gene_ids, algorithm = params$algorithm)
      n_res <- as.integer(Sys.getenv("ANALYSIS_CLUSTER_VALIDATION_RESAMPLES", "100"))
      val <- validate_functional_clusters(gene_ids, resolution = 1.0, n_resamples = n_res)
      clusters <- dplyr::left_join(
        dplyr::mutate(clusters, cluster_id = as.character(cluster)),   # type-align the join key
        val$per_cluster, by = "cluster_id"
      ) %>% dplyr::select(-cluster_id)
      built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "functional")
      list(kind = "clusters", raw = clusters, clusters = built$clusters,
           members = built$members, row_counts = built$row_counts,
           partition_validation = val$partition)
    },
    phenotype_clusters = {
      clusters <- generate_phenotype_clusters()
      n_res <- as.integer(Sys.getenv("ANALYSIS_CLUSTER_VALIDATION_RESAMPLES", "100"))
      val <- validate_phenotype_clusters(
        generate_phenotype_cluster_input()$matrix,
        quali_sup_var = 1:1, quanti_sup_var = 2:4, n_resamples = n_res
      )
      clusters <- dplyr::left_join(
        dplyr::mutate(clusters, cluster_id = as.character(cluster)),
        val$per_cluster, by = "cluster_id"
      ) %>% dplyr::select(-cluster_id)
      built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "phenotype")
      list(kind = "clusters", raw = clusters, clusters = built$clusters,
           members = built$members, row_counts = built$row_counts,
           partition_validation = val$partition)
    },
    phenotype_correlations = {
      rows <- generate_phenotype_correlations_mem(
        filter = params$filter,
        min_abs_correlation = NULL
      )
      built <- analysis_snapshot_build_correlation_rows(rows, correlation_kind = "phenotype")
      list(kind = "correlations", raw = rows, correlations = built$correlations, row_counts = built$row_counts)
    },
    phenotype_functional_correlations = {
      result <- generate_phenotype_functional_cluster_correlation()
      rows <- result$correlation_melted %||% result
      built <- analysis_snapshot_build_correlation_rows(rows, correlation_kind = "phenotype_functional")
      list(kind = "correlations", raw = rows, correlations = built$correlations, row_counts = built$row_counts)
    },
    gene_network_edges = {
      network <- generate_network_edges_response(
        cluster_type = params$cluster_type,
        min_confidence = params$min_confidence,
        max_edges = params$max_edges
      )
      built <- analysis_snapshot_build_network_rows(network)
      list(
        kind = "network",
        raw = network,
        nodes = built$nodes,
        edges = built$edges,
        metadata = network$metadata %||% list(),
        row_counts = built$row_counts
      )
    },
    stop(sprintf("Unsupported analysis snapshot type: %s", normalized$analysis_type), call. = FALSE)
  )
}

analysis_snapshot_refresh <- function(analysis_type, params, job_id = NULL, conn = NULL) {
  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
  analysis_snapshot_with_refresh_connection(conn, function(refresh_conn) {
    lock_acquired <- analysis_snapshot_acquire_lock(
      normalized$analysis_type,
      normalized$parameter_hash,
      conn = refresh_conn
    )
    if (!isTRUE(lock_acquired)) {
      stop("Analysis snapshot refresh is already running for this parameter set", call. = FALSE)
    }
    on.exit(
      tryCatch(
        analysis_snapshot_release_lock(normalized$analysis_type, normalized$parameter_hash, conn = refresh_conn),
        error = function(e) NULL
      ),
      add = TRUE
    )

    source_data_version <- analysis_snapshot_source_data_version(conn = refresh_conn)
    stale_after <- analysis_snapshot_stale_after()
    payload <- analysis_snapshot_build_payload(normalized$analysis_type, normalized$params, conn = refresh_conn)
    row_counts <- payload$row_counts %||% list()
    if (identical(payload$kind, "network")) {
      row_counts$network_metadata <- payload$metadata %||% list()
    }
    payload_hash <- analysis_snapshot_payload_hash(
      payload[setdiff(names(payload), c("raw", "partition_validation"))]
    )
    input_hash <- analysis_snapshot_input_hash(list(
      analysis_type = normalized$analysis_type,
      params = normalized$params,
      source_data_version = source_data_version
    ))

    # Human-facing DB release label (#22 / #459). Policy: when the db_version
    # surface is unavailable, store the literal "unknown" (never omit).
    dbv <- tryCatch(db_version_get(conn = refresh_conn),
                    error = function(e) list(version = "unknown", commit = "unknown", available = FALSE))
    db_release_version <- if (isTRUE(dbv$available)) dbv$version %||% "unknown" else "unknown"
    db_release_commit  <- if (isTRUE(dbv$available)) dbv$commit  %||% "unknown" else "unknown"

    write_result <- analysis_snapshot_with_write_transaction(refresh_conn, function(txn_conn) {
      snapshot_id <- analysis_snapshot_create_manifest(
        list(
          analysis_type = normalized$analysis_type,
          parameter_hash = normalized$parameter_hash,
          schema_version = ANALYSIS_SNAPSHOT_SCHEMA_VERSION,
          data_class = normalized$data_class,
          status = "pending",
          generated_by_job_id = job_id,
          stale_after = stale_after,
          source_versions = list(sysndd_public_data = source_data_version,
                                 db_release_version = db_release_version,
                                 db_release_commit  = db_release_commit),
          source_data_version = source_data_version,
          parameters_json = normalized$parameters_json,
          input_hash = input_hash,
          payload_hash = payload_hash,
          algorithm_name = normalized$params$algorithm %||% normalized$params$cluster_type %||% NA_character_,
          row_counts = row_counts,
          validation = payload$partition_validation,   # NULL for non-clustering presets
          db_release_version = db_release_version,
          db_release_commit  = db_release_commit
        ),
        conn = txn_conn
      )

      if (identical(payload$kind, "network")) {
        analysis_snapshot_insert_network_rows(snapshot_id, payload, conn = txn_conn)
      } else if (identical(payload$kind, "clusters")) {
        analysis_snapshot_insert_cluster_rows(snapshot_id, payload$clusters, payload$members, conn = txn_conn)
      } else if (identical(payload$kind, "correlations")) {
        analysis_snapshot_insert_correlation_rows(snapshot_id, payload$correlations, conn = txn_conn)
      } else {
        stop(sprintf("Unsupported analysis snapshot payload kind: %s", payload$kind), call. = FALSE)
      }

      analysis_snapshot_activate(
        snapshot_id,
        normalized$analysis_type,
        normalized$parameter_hash,
        conn = txn_conn,
        use_transaction = FALSE
      )
      pruned <- analysis_snapshot_prune(normalized$analysis_type, normalized$parameter_hash, conn = txn_conn)

      list(snapshot_id = snapshot_id, pruned = pruned)
    })
    llm_generation <- analysis_snapshot_trigger_llm_generation(
      normalized$analysis_type,
      payload,
      parent_job_id = job_id %||% write_result$snapshot_id
    )

    list(
      snapshot_id = write_result$snapshot_id,
      analysis_type = normalized$analysis_type,
      parameter_hash = normalized$parameter_hash,
      status = "public_ready",
      row_counts = row_counts,
      payload_hash = payload_hash,
      input_hash = input_hash,
      source_data_version = source_data_version,
      stale_after = stale_after,
      pruned = write_result$pruned,
      llm_generation = llm_generation
    )
  })
}
