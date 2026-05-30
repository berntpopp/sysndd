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
  cluster_hashes <- as.character(analysis_snapshot_column(clusters_in, "hash_filter", NA_character_))
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

  switch(
    normalized$analysis_type,
    functional_clusters = {
      clusters <- gen_string_clust_obj_mem(
        analysis_snapshot_approved_gene_ids(conn = conn),
        algorithm = params$algorithm
      )
      built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "functional")
      list(kind = "clusters", raw = clusters, clusters = built$clusters, members = built$members, row_counts = built$row_counts)
    },
    phenotype_clusters = {
      clusters <- generate_phenotype_clusters()
      built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "phenotype")
      list(kind = "clusters", raw = clusters, clusters = built$clusters, members = built$members, row_counts = built$row_counts)
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
    payload <- analysis_snapshot_build_payload(normalized$analysis_type, normalized$params, conn = refresh_conn)
    row_counts <- payload$row_counts %||% list()
    if (identical(payload$kind, "network")) {
      row_counts$network_metadata <- payload$metadata %||% list()
    }
    payload_hash <- analysis_snapshot_payload_hash(payload[setdiff(names(payload), c("raw"))])
    input_hash <- analysis_snapshot_input_hash(list(
      analysis_type = normalized$analysis_type,
      params = normalized$params,
      source_data_version = source_data_version
    ))

    write_result <- analysis_snapshot_with_write_transaction(refresh_conn, function(txn_conn) {
      snapshot_id <- analysis_snapshot_create_manifest(
        list(
          analysis_type = normalized$analysis_type,
          parameter_hash = normalized$parameter_hash,
          schema_version = ANALYSIS_SNAPSHOT_SCHEMA_VERSION,
          data_class = normalized$data_class,
          status = "pending",
          generated_by_job_id = job_id,
          source_versions = list(sysndd_public_data = source_data_version),
          source_data_version = source_data_version,
          parameters_json = normalized$parameters_json,
          input_hash = input_hash,
          payload_hash = payload_hash,
          algorithm_name = normalized$params$algorithm %||% normalized$params$cluster_type %||% NA_character_,
          row_counts = row_counts
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

    list(
      snapshot_id = write_result$snapshot_id,
      analysis_type = normalized$analysis_type,
      parameter_hash = normalized$parameter_hash,
      status = "public_ready",
      row_counts = row_counts,
      payload_hash = payload_hash,
      input_hash = input_hash,
      source_data_version = source_data_version,
      pruned = write_result$pruned
    )
  })
}
