# services/analysis-snapshot-service.R

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

service_analysis_snapshot_problem <- function(code,
                                              message,
                                              status,
                                              analysis_type,
                                              retry_after = NULL) {
  result <- list(
    status = as.integer(status),
    body = list(
      code = code,
      message = message,
      analysis_type = analysis_type
    )
  )
  if (!is.null(retry_after)) {
    result$retry_after <- as.integer(retry_after)
  }
  result
}

service_analysis_snapshot_read <- function(analysis_type,
                                           params,
                                           repo_get_public = analysis_snapshot_get_public) {
  normalized <- tryCatch(
    analysis_snapshot_normalize_params(analysis_type, params),
    analysis_snapshot_unsupported_parameter_error = function(e) e
  )

  if (inherits(normalized, "analysis_snapshot_unsupported_parameter_error")) {
    return(service_analysis_snapshot_problem(
      code = "unsupported_parameter",
      message = conditionMessage(normalized),
      status = 400L,
      analysis_type = as.character(analysis_type[[1]])
    ))
  }

  snapshot <- repo_get_public(normalized$analysis_type, normalized$parameter_hash)
  if (is.null(snapshot)) {
    return(service_analysis_snapshot_problem(
      code = "snapshot_missing",
      message = "No public analysis snapshot is currently available for this supported parameter set.",
      status = 503L,
      analysis_type = normalized$analysis_type,
      retry_after = 60L
    ))
  }

  status_code <- snapshot$status_code %||% "available"
  if (!identical(status_code, "available")) {
    return(service_analysis_snapshot_problem(
      code = status_code,
      message = service_analysis_snapshot_status_message(status_code),
      status = 503L,
      analysis_type = normalized$analysis_type,
      retry_after = 60L
    ))
  }

  body <- switch(normalized$analysis_type,
    functional_clusters = service_analysis_snapshot_shape_functional(snapshot),
    phenotype_clusters = service_analysis_snapshot_shape_phenotype_clusters(snapshot),
    phenotype_correlations = service_analysis_snapshot_shape_correlations(snapshot),
    phenotype_functional_correlations = service_analysis_snapshot_shape_correlations(snapshot, drop_diagonal = FALSE),
    gene_network_edges = service_analysis_snapshot_shape_network(snapshot, max_edges = normalized$params$max_edges),
    stop(sprintf("Unsupported analysis snapshot type: %s", normalized$analysis_type), call. = FALSE)
  )

  list(status = 200L, body = body)
}

service_analysis_snapshot_status_message <- function(status_code) {
  switch(status_code,
    snapshot_stale = "The active public analysis snapshot is stale and should be refreshed before serving.",
    source_version_mismatch = paste(
      "The active public analysis snapshot was built from a different",
      "public source-data version and should be refreshed before serving."
    ),
    snapshot_missing = "No public analysis snapshot is currently available for this supported parameter set.",
    "The active public analysis snapshot is not currently available."
  )
}

service_analysis_snapshot_shape_functional <- function(snapshot) {
  clusters <- service_analysis_snapshot_shape_clusters(snapshot, cluster_kind = "functional")
  categories <- service_analysis_snapshot_functional_categories(clusters)

  list(
    categories = categories,
    clusters = clusters,
    pagination = list(
      page_size = nrow(clusters),
      page_after = "",
      next_cursor = NULL,
      total_count = nrow(clusters),
      has_more = FALSE
    ),
    meta = c(
      list(
        algorithm = service_analysis_snapshot_manifest_algorithm(snapshot, default = "leiden"),
        elapsed_seconds = 0,
        gene_count = service_analysis_snapshot_count_cluster_members(clusters),
        cluster_count = nrow(clusters),
        cache_hit = TRUE
      ),
      service_analysis_snapshot_meta(snapshot)
    )
  )
}

service_analysis_snapshot_shape_phenotype_clusters <- function(snapshot) {
  clusters <- service_analysis_snapshot_shape_clusters(snapshot, cluster_kind = "phenotype")
  list(
    clusters = clusters,
    meta = service_analysis_snapshot_meta(snapshot)
  )
}

service_analysis_snapshot_shape_correlations <- function(snapshot,
                                                         min_abs_correlation = NULL,
                                                         drop_diagonal = TRUE,
                                                         triangle_only = FALSE) {
  rows <- tibble::as_tibble(snapshot$correlations %||% tibble::tibble())
  melted <- if (nrow(rows) == 0L) {
    tibble::tibble(x = character(), y = character(), value = numeric())
  } else {
    tibble::tibble(
      x = as.character(rows$x_key),
      y = as.character(rows$y_key),
      value = suppressWarnings(as.numeric(rows$value))
    )
  }

  if (!is.null(min_abs_correlation)) {
    min_abs_correlation <- suppressWarnings(as.numeric(min_abs_correlation))
    if (!is.na(min_abs_correlation)) {
      melted <- dplyr::filter(melted, abs(value) >= min_abs_correlation)
    }
  }
  if (isTRUE(drop_diagonal) && nrow(melted) > 0L) {
    melted <- dplyr::filter(melted, x != y)
  }
  if (isTRUE(triangle_only) && nrow(melted) > 0L) {
    melted <- dplyr::filter(melted, x < y)
  }

  matrix_value <- service_analysis_snapshot_correlation_matrix(melted)
  list(
    correlation_matrix = matrix_value,
    correlation_melted = melted,
    meta = service_analysis_snapshot_meta(snapshot)
  )
}

service_analysis_snapshot_shape_network <- function(snapshot, max_edges = 10000L) {
  nodes_in <- tibble::as_tibble(snapshot$network_nodes %||% tibble::tibble())
  edges_in <- tibble::as_tibble(snapshot$network_edges %||% tibble::tibble())

  nodes <- if (nrow(nodes_in) == 0L) {
    tibble::tibble(
      hgnc_id = character(),
      symbol = character(),
      cluster = character(),
      degree = integer(),
      category = character(),
      x = numeric(),
      y = numeric(),
      layout_x = numeric(),
      layout_y = numeric(),
      igraph_x = numeric(),
      igraph_y = numeric()
    )
  } else {
    tibble::tibble(
      hgnc_id = as.character(nodes_in$hgnc_id),
      symbol = as.character(nodes_in$symbol),
      cluster = as.character(nodes_in$cluster_id),
      degree = suppressWarnings(as.integer(nodes_in$degree)),
      category = as.character(nodes_in$category),
      x = suppressWarnings(as.numeric(nodes_in$x)),
      y = suppressWarnings(as.numeric(nodes_in$y)),
      layout_x = suppressWarnings(as.numeric(nodes_in$layout_x)),
      layout_y = suppressWarnings(as.numeric(nodes_in$layout_y)),
      igraph_x = suppressWarnings(as.numeric(nodes_in$igraph_x)),
      igraph_y = suppressWarnings(as.numeric(nodes_in$igraph_y))
    )
  }

  edges <- if (nrow(edges_in) == 0L) {
    tibble::tibble(source = character(), target = character(), confidence = numeric())
  } else {
    tibble::tibble(
      source = as.character(edges_in$source_hgnc_id),
      target = as.character(edges_in$target_hgnc_id),
      confidence = suppressWarnings(as.numeric(edges_in$confidence))
    )
  }

  total_edges <- nrow(edges)
  max_edges <- suppressWarnings(as.integer(max_edges))
  if (is.na(max_edges) || max_edges < 0L) {
    max_edges <- 10000L
  }
  edges_filtered <- FALSE
  if (max_edges > 0L && nrow(edges) > max_edges) {
    edges <- edges[order(-edges$confidence, edges$source, edges$target), ]
    edges <- utils::head(edges, max_edges)
    connected_nodes <- unique(c(edges$source, edges$target))
    nodes <- nodes[nodes$hgnc_id %in% connected_nodes, ]
    edges_filtered <- TRUE
  }

  category_counts <- if (nrow(nodes) > 0L && "category" %in% names(nodes)) {
    category_summary <- dplyr::summarise(
      dplyr::group_by(nodes, category),
      count = dplyr::n(),
      .groups = "drop"
    )
    as.list(tidyr::pivot_wider(
      category_summary,
      names_from = category,
      values_from = count,
      values_fill = 0
    ))
  } else {
    list()
  }

  generated_metadata <- service_analysis_snapshot_manifest_network_metadata(snapshot)
  metadata <- c(
    utils::modifyList(
      list(
        node_count = nrow(nodes),
        edge_count = nrow(edges),
        cluster_count = length(unique(nodes$cluster[!is.na(nodes$cluster)])),
        total_edges = total_edges,
        edges_filtered = edges_filtered,
        min_confidence = service_analysis_snapshot_manifest_min_confidence(snapshot),
        elapsed_seconds = 0,
        category_counts = category_counts,
        display_layout_status = if (all(c("x", "y") %in% names(nodes)) && nrow(nodes) > 0L) {
          "available"
        } else {
          "missing"
        }
      ),
      generated_metadata
    ),
    service_analysis_snapshot_meta(snapshot)
  )

  list(nodes = nodes, edges = edges, metadata = metadata)
}

service_analysis_snapshot_shape_clusters <- function(snapshot, cluster_kind) {
  clusters <- tibble::as_tibble(snapshot$clusters %||% tibble::tibble())
  members <- tibble::as_tibble(snapshot$cluster_members %||% tibble::tibble())
  if (!"cluster_kind" %in% names(clusters)) {
    return(tibble::tibble(cluster = character(), hash_filter = character(), identifiers = list()))
  }
  if (!"cluster_kind" %in% names(members)) {
    members <- tibble::tibble(
      cluster_kind = character(),
      cluster_id = character(),
      entity_id = integer(),
      hgnc_id = character(),
      symbol = character()
    )
  }
  clusters <- clusters[clusters$cluster_kind == cluster_kind, , drop = FALSE]
  members <- members[members$cluster_kind == cluster_kind, , drop = FALSE]

  if (nrow(clusters) == 0L) {
    return(tibble::tibble(cluster = character(), hash_filter = character(), identifiers = list()))
  }

  rows <- lapply(seq_len(nrow(clusters)), function(i) {
    cluster <- clusters[i, , drop = FALSE]
    metadata <- service_analysis_snapshot_parse_json_object(cluster$metadata_json[[1]])
    cluster_members <- members[members$cluster_id == cluster$cluster_id[[1]], , drop = FALSE]
    identifiers <- if (nrow(cluster_members) == 0L) {
      tibble::tibble(entity_id = integer(), hgnc_id = character(), symbol = character())
    } else {
      tibble::tibble(
        entity_id = suppressWarnings(as.integer(cluster_members$entity_id)),
        hgnc_id = as.character(cluster_members$hgnc_id),
        symbol = as.character(cluster_members$symbol)
      )
    }

    cluster_id <- cluster$cluster_id[[1]]
    cluster_hash <- cluster$cluster_hash[[1]]
    cluster_size <- suppressWarnings(as.integer(cluster$cluster_size[[1]]))
    cluster_label <- cluster$label[[1]]
    row <- tibble::tibble(
      cluster = cluster_id,
      hash_filter = cluster_hash,
      cluster_size = cluster_size,
      label = cluster_label,
      identifiers = list(identifiers)
    )
    for (name in names(metadata)) {
      row[[name]] <- list(metadata[[name]])
    }
    row
  })

  dplyr::bind_rows(rows)
}

service_analysis_snapshot_meta <- function(snapshot) {
  manifest <- tibble::as_tibble(snapshot$manifest)
  row <- manifest[1, , drop = FALSE]
  list(
    snapshot = list(
      snapshot_id = service_analysis_snapshot_json_scalar(service_analysis_snapshot_scalar_value(row$snapshot_id)),
      analysis_type = service_analysis_snapshot_json_scalar(service_analysis_snapshot_scalar_value(row$analysis_type)),
      parameter_hash = service_analysis_snapshot_json_scalar(service_analysis_snapshot_scalar_value(row$parameter_hash)),
      schema_version = service_analysis_snapshot_json_scalar(service_analysis_snapshot_scalar_value(row$schema_version)),
      data_class = service_analysis_snapshot_json_scalar(service_analysis_snapshot_scalar_value(row$data_class)),
      generated_at = service_analysis_snapshot_json_scalar(
        service_analysis_snapshot_time_string(service_analysis_snapshot_scalar_value(row$generated_at))
      ),
      stale_after = service_analysis_snapshot_json_scalar(
        service_analysis_snapshot_time_string(service_analysis_snapshot_scalar_value(row$stale_after))
      ),
      source_data_version = service_analysis_snapshot_json_scalar(
        service_analysis_snapshot_scalar_value(row$source_data_version)
      ),
      # Lineage hashes (W3C-PROV / FAIR provenance per issue #347 output
      # contract): input_hash binds the snapshot to its supported parameter set
      # plus the public source-data version; payload_hash binds it to the
      # materialized result. record_counts exposes the stored row counts so
      # callers can audit completeness without a second query. All come from the
      # public-ready manifest row already selected by analysis_snapshot_get_public().
      input_hash = service_analysis_snapshot_json_scalar(
        service_analysis_snapshot_column_value(row, "input_hash")
      ),
      payload_hash = service_analysis_snapshot_json_scalar(
        service_analysis_snapshot_column_value(row, "payload_hash")
      ),
      record_counts = service_analysis_snapshot_record_counts(row)
    )
  )
}

# Safe single-row column accessor that tolerates manifests missing optional
# columns without emitting tibble "unknown column" warnings.
service_analysis_snapshot_column_value <- function(row, name, default = NULL) {
  if (!name %in% names(row)) {
    return(default)
  }
  service_analysis_snapshot_scalar_value(row[[name]], default)
}

service_analysis_snapshot_record_counts <- function(row) {
  if (!"row_counts_json" %in% names(row)) {
    return(NULL)
  }
  counts <- service_analysis_snapshot_parse_json_object(row$row_counts_json[[1]])
  # network_metadata is generated metadata, not a row count; keep the
  # record_counts block scoped to the materialized payload tables.
  counts$network_metadata <- NULL
  if (length(counts) == 0L) {
    return(NULL)
  }
  counts
}

service_analysis_snapshot_parse_json_object <- function(value) {
  if (is.null(value) || length(value) == 0L || is.na(value[[1]]) || !nzchar(value[[1]])) {
    return(list())
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(value[[1]], simplifyVector = TRUE),
    error = function(e) list()
  )
  if (is.list(parsed)) parsed else list()
}

service_analysis_snapshot_json_scalar <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }
  jsonlite::unbox(value)
}

service_analysis_snapshot_scalar_value <- function(value, default = NULL) {
  if (is.null(value) || length(value) == 0L) {
    return(default)
  }
  first <- value[[1]]
  if (length(first) == 0L || (is.atomic(first) && length(first) == 1L && is.na(first))) {
    return(default)
  }
  first
}

service_analysis_snapshot_time_string <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }
  if (inherits(value, "POSIXt")) {
    return(format(value, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"))
  }
  as.character(value)
}

service_analysis_snapshot_manifest_algorithm <- function(snapshot, default = NULL) {
  manifest <- tibble::as_tibble(snapshot$manifest)
  value <- service_analysis_snapshot_scalar_value(manifest$algorithm_name, default)
  value %||% default
}

service_analysis_snapshot_manifest_min_confidence <- function(snapshot) {
  manifest <- tibble::as_tibble(snapshot$manifest)
  params <- service_analysis_snapshot_parse_json_object(manifest$parameters_json[[1]])
  suppressWarnings(as.integer(params$min_confidence %||% NA_integer_))
}

service_analysis_snapshot_manifest_network_metadata <- function(snapshot) {
  manifest <- tibble::as_tibble(snapshot$manifest)
  if (!"row_counts_json" %in% names(manifest)) {
    return(list())
  }
  row_counts <- service_analysis_snapshot_parse_json_object(manifest$row_counts_json[[1]])
  metadata <- row_counts$network_metadata %||% list()
  if (is.list(metadata)) metadata else list()
}

service_analysis_snapshot_count_cluster_members <- function(clusters) {
  if (nrow(clusters) == 0L || !"identifiers" %in% names(clusters)) {
    return(0L)
  }
  length(unique(unlist(lapply(clusters$identifiers, function(x) x$hgnc_id), use.names = FALSE)))
}

service_analysis_snapshot_functional_categories <- function(clusters) {
  if (nrow(clusters) == 0L || !"term_enrichment" %in% names(clusters)) {
    return(tibble::tibble(value = character(), text = character(), link = character()))
  }

  values <- unique(unlist(lapply(clusters$term_enrichment, function(term_rows) {
    service_analysis_snapshot_extract_categories(term_rows)
  }), use.names = FALSE))
  values <- sort(values[!is.na(values) & nzchar(values)])

  links <- list(
    COMPARTMENTS = "https://www.ebi.ac.uk/QuickGO/term/",
    Component = "https://www.ebi.ac.uk/QuickGO/term/",
    DISEASES = "https://disease-ontology.org/term/",
    Function = "https://www.ebi.ac.uk/QuickGO/term/",
    HPO = "https://hpo.jax.org/app/browse/term/",
    InterPro = "http://www.ebi.ac.uk/interpro/entry/InterPro/",
    KEGG = "https://www.genome.jp/dbget-bin/www_bget?",
    Keyword = "https://www.uniprot.org/keywords/",
    NetworkNeighborAL = "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
    Pfam = "https://www.ebi.ac.uk/interpro/entry/pfam/",
    PMID = "https://www.ncbi.nlm.nih.gov/search/all/?term=",
    Process = "https://www.ebi.ac.uk/QuickGO/term/",
    RCTM = "https://reactome.org/content/detail/R-",
    SMART = "http://www.ebi.ac.uk/interpro/entry/smart/",
    TISSUES = "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
    WikiPathways = "https://www.wikipathways.org/index.php/Pathway:"
  )

  tibble::tibble(
    value = values,
    text = ifelse(nchar(values) <= 5, values, stringr::str_to_sentence(values)),
    link = unname(vapply(values, function(value) links[[value]] %||% NA_character_, character(1)))
  )
}

service_analysis_snapshot_extract_categories <- function(value) {
  if (is.null(value) || length(value) == 0L) {
    return(character())
  }
  if (is.data.frame(value) && "category" %in% names(value)) {
    return(as.character(value$category))
  }
  if (is.list(value)) {
    if ("category" %in% names(value)) {
      return(as.character(value$category))
    }
    return(unlist(lapply(value, service_analysis_snapshot_extract_categories), use.names = FALSE))
  }
  character()
}

service_analysis_snapshot_correlation_matrix <- function(melted) {
  if (nrow(melted) == 0L) {
    return(matrix(numeric(), nrow = 0L, ncol = 0L))
  }
  keys <- sort(unique(c(melted$x, melted$y)))
  result <- matrix(NA_real_, nrow = length(keys), ncol = length(keys), dimnames = list(keys, keys))
  for (i in seq_len(nrow(melted))) {
    result[melted$x[[i]], melted$y[[i]]] <- melted$value[[i]]
  }
  result
}

# --- Shared snapshot refresh submission (#420) ---------------------------------
# One submit path shared by the startup bootstrap, the admin endpoint, and the
# operator script (scripts/refresh-analysis-snapshots.R). Keep this the single
# source of submission logic.

#' Whether the startup snapshot bootstrap is enabled.
#'
#' Config gate (issue #420), implemented as an env var to match the repo's
#' sidecar/env conventions. Default enabled; set
#' `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP=false` to disable.
#' @export
analysis_snapshot_bootstrap_enabled <- function() {
  raw <- trimws(Sys.getenv("ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP", "true"))
  if (!nzchar(raw)) {
    return(TRUE)
  }
  tolower(raw) %in% c("true", "1", "yes", "on")
}

#' Submit analysis_snapshot_refresh jobs for supported presets.
#'
#' For each target preset: normalize params (canonical parameter_hash), and
#' unless `force` skip presets that already have an active public-ready snapshot,
#' then submit a durable `analysis_snapshot_refresh` job (dedup-safe). Per-preset
#' failures are isolated and reported, never thrown.
#'
#' @param analysis_type Optional single preset; NULL = all supported presets.
#' @param force When TRUE, submit even when a current snapshot exists.
#' @param presets Optional preset list (defaults to the supported presets).
#' @param submit_fn Injectable job-submit fn (default `async_job_service_submit`).
#' @param exists_fn Injectable existence probe (default `analysis_snapshot_public_exists`).
#' @param conn Optional DB connection/pool.
#' @return Structured summary list.
#' @export
service_analysis_snapshot_submit_refresh <- function(analysis_type = NULL,
                                                     force = FALSE,
                                                     presets = NULL,
                                                     submit_fn = async_job_service_submit,
                                                     exists_fn = analysis_snapshot_public_exists,
                                                     conn = NULL) {
  if (is.null(presets)) {
    presets <- analysis_snapshot_supported_presets()
  }
  if (!is.null(analysis_type)) {
    analysis_type <- as.character(analysis_type[[1]])
    presets <- Filter(function(p) identical(p$analysis_type, analysis_type), presets)
    if (length(presets) == 0L) {
      analysis_snapshot_unsupported_parameter(
        sprintf("Unsupported analysis snapshot type: %s", analysis_type),
        fields = list(analysis_type = analysis_type)
      )
    }
  }

  force <- isTRUE(force)
  results <- list()
  submitted <- 0L
  reused <- 0L
  skipped <- 0L
  failed <- 0L

  for (preset in presets) {
    normalized <- analysis_snapshot_normalize_params(preset$analysis_type, preset$params)
    at <- normalized$analysis_type
    ph <- normalized$parameter_hash

    if (!force) {
      already <- tryCatch(exists_fn(at, ph, conn = conn), error = function(e) FALSE)
      if (isTRUE(already)) {
        skipped <- skipped + 1L
        results[[length(results) + 1L]] <- list(
          analysis_type = at, parameter_hash = ph,
          action = "skipped_existing", job_id = NA_character_,
          message = "public-ready snapshot already present"
        )
        next
      }
    }

    outcome <- tryCatch(
      submit_fn(
        job_type = "analysis_snapshot_refresh",
        request_payload = list(analysis_type = at, params = normalized$params),
        queue_name = "default",
        priority = 50L,
        conn = conn
      ),
      error = function(e) list(.error = conditionMessage(e))
    )

    if (!is.null(outcome$.error)) {
      failed <- failed + 1L
      results[[length(results) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph,
        action = "error", job_id = NA_character_, message = outcome$.error
      )
      next
    }

    job_id <- tryCatch(as.character(outcome$job$job_id[[1]]), error = function(e) NA_character_)
    if (isTRUE(outcome$duplicate)) {
      reused <- reused + 1L
      results[[length(results) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph,
        action = "reused", job_id = job_id,
        message = "existing queued/running job reused"
      )
    } else {
      submitted <- submitted + 1L
      results[[length(results) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph,
        action = "submitted", job_id = job_id, message = "refresh job submitted"
      )
    }
  }

  list(
    requested = length(presets),
    submitted = submitted,
    reused = reused,
    skipped = skipped,
    failed = failed,
    force = force,
    results = results
  )
}

#' Per-preset public snapshot status overview.
#'
#' @param presets Optional preset list (defaults to the supported presets).
#' @param manifest_fn Injectable manifest read (default `analysis_snapshot_public_manifest`).
#' @param conn Optional DB connection/pool.
#' @return list(presets = list(per-preset state), summary = counts).
#' @export
service_analysis_snapshot_status <- function(presets = NULL,
                                             manifest_fn = analysis_snapshot_public_manifest,
                                             conn = NULL) {
  if (is.null(presets)) {
    presets <- analysis_snapshot_supported_presets()
  }
  preset_states <- list()
  total <- 0L
  available <- 0L
  missing <- 0L
  stale <- 0L
  mismatch <- 0L

  for (preset in presets) {
    normalized <- analysis_snapshot_normalize_params(preset$analysis_type, preset$params)
    at <- normalized$analysis_type
    ph <- normalized$parameter_hash
    manifest <- tryCatch(manifest_fn(at, ph, conn = conn), error = function(e) NULL)
    total <- total + 1L

    if (is.null(manifest)) {
      missing <- missing + 1L
      preset_states[[length(preset_states) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph, state = "missing",
        generated_at = NA_character_, activated_at = NA_character_,
        stale_after = NA_character_, source_data_version = NA_character_,
        row_counts = NULL
      )
      next
    }

    status_code <- service_analysis_snapshot_scalar_value(manifest$status_code, "available")
    state <- switch(status_code,
      available = "available",
      snapshot_stale = "stale",
      source_version_mismatch = "source_version_mismatch",
      snapshot_missing = "missing",
      status_code
    )
    if (identical(state, "available")) {
      available <- available + 1L
    } else if (identical(state, "stale")) {
      stale <- stale + 1L
    } else if (identical(state, "source_version_mismatch")) {
      mismatch <- mismatch + 1L
    } else if (identical(state, "missing")) {
      missing <- missing + 1L
    }

    preset_states[[length(preset_states) + 1L]] <- list(
      analysis_type = at,
      parameter_hash = ph,
      state = state,
      generated_at = service_analysis_snapshot_time_string(
        service_analysis_snapshot_scalar_value(manifest$generated_at)
      ),
      activated_at = service_analysis_snapshot_time_string(
        service_analysis_snapshot_scalar_value(manifest$activated_at)
      ),
      stale_after = service_analysis_snapshot_time_string(
        service_analysis_snapshot_scalar_value(manifest$stale_after)
      ),
      source_data_version = service_analysis_snapshot_scalar_value(
        manifest$source_data_version, NA_character_
      ),
      row_counts = service_analysis_snapshot_record_counts(manifest)
    )
  }

  list(
    presets = preset_states,
    summary = list(
      total = total, available = available, missing = missing,
      stale = stale, mismatch = mismatch
    )
  )
}

#' Startup bootstrap: enqueue refresh jobs for missing presets (idempotent).
#'
#' Mirrors `pubtatornidd_bootstrap_enrichment()`. No-op when disabled; never
#' throws (callable directly in API startup).
#'
#' @param submit_refresh_fn Injectable submit fn (default the shared submit).
#' @param enabled_fn Injectable gate (default `analysis_snapshot_bootstrap_enabled`).
#' @return Invisibly TRUE when at least one preset was missing, FALSE otherwise.
#' @export
analysis_snapshot_bootstrap_on_startup <- function(
    submit_refresh_fn = service_analysis_snapshot_submit_refresh,
    enabled_fn = analysis_snapshot_bootstrap_enabled) {
  if (!isTRUE(enabled_fn())) {
    message("[snapshot-bootstrap] disabled via ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP; skipping")
    return(invisible(FALSE))
  }

  summary <- tryCatch(
    submit_refresh_fn(force = FALSE),
    error = function(e) {
      message(sprintf("[snapshot-bootstrap] skipped: %s", conditionMessage(e)))
      NULL
    }
  )
  if (is.null(summary)) {
    return(invisible(FALSE))
  }

  missing <- summary$requested - summary$skipped
  if (missing > 0L) {
    message(sprintf(
      "[snapshot-bootstrap] %d/%d presets missing -> submitted %d refresh jobs (reused %d, failed %d)",
      missing, summary$requested, summary$submitted, summary$reused, summary$failed
    ))
  } else {
    message("[snapshot-bootstrap] all presets present, nothing to do")
  }
  invisible(missing > 0L)
}
