# functions/analysis-snapshot-rows.R
#
# Row shaping for analysis snapshots: turns the in-memory payload objects
# (clusters, members, network nodes/edges, correlations) into the flat tibbles
# that the snapshot tables store, and packs any column outside the known set
# into `metadata_json`.
#
# Extracted from analysis-snapshot-builder.R (#630), which had reached the
# 600-line ceiling. The split is by responsibility, not by convenience: this
# file is pure shaping with no DB access and no orchestration, while the builder
# owns the build/validate/persist sequence.
#
# The metadata_json packing here is what lets an additive per-cluster block
# (e.g. the computed syndromicity) reach the API with no schema change: any
# clusters-tibble column outside the excluded set is serialized into
# metadata_json, and service_analysis_snapshot_shape_clusters() merges those
# keys back onto the served row.

if (!exists("%||%", mode = "function")) `%||%` <- function(x, y) if (is.null(x)) y else x

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
