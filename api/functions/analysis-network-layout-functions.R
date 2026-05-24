# functions/analysis-network-layout-functions.R
#### GeneNetworks fCoSE display layout artifacts

NETWORK_LAYOUT_SCHEMA_VERSION <- 1L
NETWORK_LAYOUT_VERSION <- 1L
NETWORK_LAYOUT_PROFILE <- "gene_network_fcose_v1"
NETWORK_LAYOUT_ENGINE <- "cytoscape-fcose"

.network_layout_or <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

network_layout_options <- function() {
  list(
    name = "fcose",
    quality = "default",
    randomize = TRUE,
    animate = FALSE,
    nodeDimensionsIncludeLabels = FALSE,
    fit = FALSE,
    padding = 30,
    idealEdgeLength = 80,
    nodeRepulsion = 8000,
    edgeElasticity = 0.45,
    gravity = 0.25,
    numIter = 2500,
    boundingBox = list(x1 = 0, y1 = 0, w = 1200, h = 900)
  )
}

network_layout_cache_dir <- function(cache_dir = Sys.getenv(
  "NETWORK_LAYOUT_CACHE_DIR",
  unset = "/app/cache/network_layouts"
)) {
  cache_dir
}

network_layout_cache_path <- function(layout_key, cache_dir = network_layout_cache_dir()) {
  file.path(cache_dir, paste0(layout_key, ".rds"))
}

network_layout_helper_path <- function(helper_path = Sys.getenv(
  "NETWORK_LAYOUT_HELPER",
  unset = "/app/layout/gene-network-fcose-layout.mjs"
)) {
  if (file.exists(helper_path)) {
    return(helper_path)
  }

  candidates <- c(
    file.path("layout", "gene-network-fcose-layout.mjs"),
    file.path("api", "layout", "gene-network-fcose-layout.mjs")
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing) > 0) {
    return(existing[[1]])
  }

  helper_path
}

network_layout_package_versions <- function() {
  lock_candidates <- c(
    Sys.getenv("NETWORK_LAYOUT_PACKAGE_LOCK", unset = ""),
    file.path("layout", "package-lock.json"),
    file.path("api", "layout", "package-lock.json")
  )
  lock_candidates <- lock_candidates[nzchar(lock_candidates)]
  existing_locks <- lock_candidates[file.exists(lock_candidates)]
  lock_path <- if (length(existing_locks) > 0) existing_locks[[1]] else NULL

  versions <- list(
    cytoscape_version = "3.33.3",
    cytoscape_fcose_version = "2.2.0",
    node_major_version = Sys.getenv("NETWORK_LAYOUT_NODE_MAJOR", unset = "24")
  )

  if (!is.null(lock_path) && !is.na(lock_path)) {
    lock <- tryCatch(
      jsonlite::fromJSON(lock_path, simplifyVector = FALSE),
      error = function(e) NULL
    )
    packages <- lock$packages
    cytoscape <- packages[["node_modules/cytoscape"]]
    fcose <- packages[["node_modules/cytoscape-fcose"]]
    versions$cytoscape_version <- .network_layout_or(cytoscape$version, versions$cytoscape_version)
    versions$cytoscape_fcose_version <- .network_layout_or(fcose$version, versions$cytoscape_fcose_version)
  }

  versions
}

network_layout_main_cluster <- function(cluster) {
  if (is.null(cluster) || length(cluster) == 0 || is.na(cluster)) {
    return(NA_character_)
  }
  strsplit(as.character(cluster), ".", fixed = TRUE)[[1]][[1]]
}

network_layout_cluster_color <- function(cluster) {
  colors <- c(
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
    "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
    "#aec7e8", "#ffbb78", "#98df8a", "#ff9896", "#c5b0d5"
  )
  main_cluster <- suppressWarnings(as.integer(network_layout_main_cluster(cluster)))
  if (is.na(main_cluster) || main_cluster < 0) {
    main_cluster <- 0L
  }
  colors[(main_cluster %% length(colors)) + 1L]
}

network_layout_node_size <- function(degree) {
  degree <- suppressWarnings(as.numeric(degree))
  if (is.na(degree) || degree < 0) {
    degree <- 1
  }
  max(15, sqrt(degree) * 6)
}

network_layout_edge_width <- function(confidence) {
  confidence <- suppressWarnings(as.numeric(confidence))
  if (is.na(confidence)) {
    confidence <- 0
  }
  max(0.5, confidence * 3)
}

network_layout_strip_display_fields <- function(network_data) {
  stripped <- network_data
  node_display_fields <- c("x", "y", "layout_x", "layout_y", "igraph_x", "igraph_y")
  metadata_display_fields <- c(
    "display_layout_status",
    "display_layout_key",
    "display_layout_version",
    "display_layout_duration_ms",
    "display_layout_node_count",
    "display_layout_edge_count",
    "layout_engine"
  )

  if (!is.null(stripped$nodes)) {
    stripped$nodes <- stripped$nodes[, setdiff(names(stripped$nodes), node_display_fields), drop = FALSE]
  }
  if (!is.null(stripped$metadata)) {
    stripped$metadata[metadata_display_fields] <- NULL
  }

  stripped
}

network_layout_elements_style <- function() {
  list(
    list(
      selector = "node[?isClusterParent]",
      style = list(
        "background-color" = "data(color)",
        "background-opacity" = 0.15,
        "border-width" = 3,
        "border-color" = "data(color)",
        "border-opacity" = 0.6,
        shape = "round-rectangle",
        label = "",
        padding = "30px"
      )
    ),
    list(
      selector = "node[!isClusterParent]",
      style = list(
        width = "data(size)",
        height = "data(size)",
        "background-color" = "data(color)",
        "border-width" = 2,
        "border-color" = "#333",
        label = "data(symbol)",
        "font-size" = "8px",
        "text-valign" = "bottom",
        "text-halign" = "center",
        "text-margin-y" = 3,
        color = "#333",
        "min-zoomed-font-size" = 8
      )
    ),
    list(
      selector = "edge",
      style = list(
        "curve-style" = "haystack",
        "haystack-radius" = 0,
        width = "data(width)",
        "line-color" = "#ccc",
        opacity = 0.6
      )
    )
  )
}

build_network_fcose_layout_request <- function(network_data, layout_key) {
  nodes <- as.data.frame(.network_layout_or(network_data$nodes, data.frame()), stringsAsFactors = FALSE)
  edges <- as.data.frame(.network_layout_or(network_data$edges, data.frame()), stringsAsFactors = FALSE)

  if (!"hgnc_id" %in% names(nodes)) {
    stop("network nodes must include hgnc_id", call. = FALSE)
  }

  main_clusters <- if ("cluster" %in% names(nodes)) {
    vapply(nodes$cluster, network_layout_main_cluster, character(1))
  } else {
    rep(NA_character_, nrow(nodes))
  }
  cluster_ids <- unique(main_clusters[!is.na(main_clusters)])

  cluster_parent_nodes <- lapply(cluster_ids, function(cluster_id) {
    list(data = list(
      id = paste0("cluster-", cluster_id),
      label = paste0("Cluster ", cluster_id),
      isClusterParent = TRUE,
      color = network_layout_cluster_color(cluster_id)
    ))
  })

  gene_nodes <- lapply(seq_len(nrow(nodes)), function(i) {
    node <- nodes[i, , drop = FALSE]
    cluster <- if ("cluster" %in% names(node)) node$cluster[[1]] else NA
    main_cluster <- network_layout_main_cluster(cluster)
    data <- list(
      id = as.character(node$hgnc_id[[1]]),
      symbol = as.character(.network_layout_or(node$symbol[[1]], node$hgnc_id[[1]])),
      cluster = cluster,
      degree = suppressWarnings(as.integer(.network_layout_or(node$degree[[1]], 1L))),
      category = as.character(.network_layout_or(node$category[[1]], "Definitive")),
      size = network_layout_node_size(.network_layout_or(node$degree[[1]], 1L)),
      color = network_layout_cluster_color(cluster)
    )

    if (!is.na(main_cluster)) {
      data$parent <- paste0("cluster-", main_cluster)
    }

    list(data = data)
  })

  edge_elements <- lapply(seq_len(nrow(edges)), function(i) {
    edge <- edges[i, , drop = FALSE]
    confidence <- if ("confidence" %in% names(edge)) edge$confidence[[1]] else NA_real_
    list(data = list(
      id = paste0("e", i - 1L),
      source = as.character(edge$source[[1]]),
      target = as.character(edge$target[[1]]),
      confidence = suppressWarnings(as.numeric(confidence)),
      width = network_layout_edge_width(confidence)
    ))
  })

  list(
    schema_version = NETWORK_LAYOUT_SCHEMA_VERSION,
    elements = c(cluster_parent_nodes, gene_nodes, edge_elements),
    style = network_layout_elements_style(),
    layout_options = network_layout_options(),
    metadata = list(
      layout_key = layout_key,
      layout_profile = NETWORK_LAYOUT_PROFILE,
      layout_version = NETWORK_LAYOUT_VERSION,
      layout_engine = NETWORK_LAYOUT_ENGINE,
      node_count = nrow(nodes),
      edge_count = nrow(edges)
    )
  )
}

network_layout_key_material <- function(network_data, cluster_type, min_confidence, max_edges) {
  clean_network <- network_layout_strip_display_fields(network_data)
  nodes <- as.data.frame(.network_layout_or(clean_network$nodes, data.frame()), stringsAsFactors = FALSE)
  edges <- as.data.frame(.network_layout_or(clean_network$edges, data.frame()), stringsAsFactors = FALSE)
  metadata <- .network_layout_or(clean_network$metadata, list())
  versions <- network_layout_package_versions()

  node_ids <- if ("hgnc_id" %in% names(nodes)) sort(unique(as.character(nodes$hgnc_id))) else character()
  node_material <- if (nrow(nodes) > 0) {
    tibble::tibble(
      hgnc_id = as.character(nodes$hgnc_id),
      symbol = as.character(.network_layout_or(nodes$symbol, "")),
      cluster = as.character(.network_layout_or(nodes$cluster, "")),
      degree = suppressWarnings(as.integer(.network_layout_or(nodes$degree, 0L))),
      category = as.character(.network_layout_or(nodes$category, "")),
      size = vapply(.network_layout_or(nodes$degree, 0L), network_layout_node_size, numeric(1))
    ) |>
      dplyr::arrange(hgnc_id)
  } else {
    tibble::tibble(
      hgnc_id = character(),
      symbol = character(),
      cluster = character(),
      degree = integer(),
      category = character(),
      size = numeric()
    )
  }

  edge_material <- if (nrow(edges) > 0) {
    tibble::tibble(
      source = as.character(edges$source),
      target = as.character(edges$target),
      confidence = round(suppressWarnings(as.numeric(edges$confidence)), 8)
    ) |>
      dplyr::arrange(dplyr::desc(confidence), source, target)
  } else {
    tibble::tibble(source = character(), target = character(), confidence = numeric())
  }

  list(
    artifact_type = "gene_network_cytoscape_layout",
    schema_version = NETWORK_LAYOUT_SCHEMA_VERSION,
    layout_version = NETWORK_LAYOUT_VERSION,
    layout_profile = NETWORK_LAYOUT_PROFILE,
    layout_engine = NETWORK_LAYOUT_ENGINE,
    cytoscape_version = versions$cytoscape_version,
    cytoscape_fcose_version = versions$cytoscape_fcose_version,
    node_major_version = versions$node_major_version,
    cluster_type = cluster_type,
    min_confidence = as.integer(min_confidence),
    max_edges = as.integer(max_edges),
    edge_filtering_policy = "confidence_desc_top_n",
    deterministic_edge_tie_breakers = c("confidence_desc", "source_asc", "target_asc"),
    string_version = .network_layout_or(metadata$string_version, "unknown"),
    displayed_node_ids = node_ids,
    displayed_edges = edge_material,
    cluster_membership = node_material[, c("hgnc_id", "cluster"), drop = FALSE],
    node_material = node_material,
    node_size_policy = "max(15, sqrt(degree) * 6)",
    compound_parent_policy = "cluster-<mainCluster>",
    layout_options = network_layout_options()
  )
}

network_layout_cache_key <- function(network_data, cluster_type, min_confidence, max_edges) {
  digest::digest(
    network_layout_key_material(
      network_data,
      cluster_type = cluster_type,
      min_confidence = min_confidence,
      max_edges = max_edges
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

read_network_layout_artifact <- function(layout_key, cache_dir = network_layout_cache_dir()) {
  path <- network_layout_cache_path(layout_key, cache_dir = cache_dir)
  if (!file.exists(path)) {
    return(NULL)
  }
  tryCatch(readRDS(path), error = function(e) NULL)
}

write_network_layout_artifact <- function(layout_key, artifact, cache_dir = network_layout_cache_dir()) {
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  path <- network_layout_cache_path(layout_key, cache_dir = cache_dir)
  tmp <- tempfile(pattern = paste0(layout_key, "-"), tmpdir = cache_dir, fileext = ".tmp")
  on.exit(unlink(tmp, force = TRUE), add = TRUE)

  saveRDS(artifact, tmp)
  if (!file.rename(tmp, path)) {
    file.copy(tmp, path, overwrite = TRUE)
    unlink(tmp, force = TRUE)
  }

  invisible(artifact)
}

validate_network_layout_artifact <- function(artifact, expected_gene_ids) {
  if (!is.list(artifact)) {
    stop("network layout artifact must be a list", call. = FALSE)
  }
  if (!is.null(artifact$schema_version) && artifact$schema_version != NETWORK_LAYOUT_SCHEMA_VERSION) {
    stop("network layout artifact schema_version is invalid", call. = FALSE)
  }
  if (!is.null(artifact$layout_engine) && artifact$layout_engine != NETWORK_LAYOUT_ENGINE) {
    stop("network layout artifact layout_engine is invalid", call. = FALSE)
  }
  if (!is.list(artifact$positions)) {
    stop("network layout artifact positions must be a named list", call. = FALSE)
  }

  expected_gene_ids <- sort(unique(as.character(expected_gene_ids[!is.na(expected_gene_ids)])))
  position_ids <- names(artifact$positions)
  missing_ids <- setdiff(expected_gene_ids, position_ids)
  if (length(missing_ids) > 0) {
    stop(
      sprintf("network layout artifact missing positions for %d displayed gene nodes", length(missing_ids)),
      call. = FALSE
    )
  }

  for (gene_id in expected_gene_ids) {
    position <- artifact$positions[[gene_id]]
    x <- suppressWarnings(as.numeric(position$x))
    y <- suppressWarnings(as.numeric(position$y))
    if (!is.finite(x) || !is.finite(y)) {
      stop(sprintf("network layout artifact has non-finite position for %s", gene_id), call. = FALSE)
    }
  }

  TRUE
}

attach_network_display_layout <- function(network_data, artifact, layout_key) {
  nodes <- network_data$nodes
  expected_gene_ids <- as.character(nodes$hgnc_id)
  validate_network_layout_artifact(artifact, expected_gene_ids)

  if ("x" %in% names(nodes) && !"igraph_x" %in% names(nodes)) {
    nodes$igraph_x <- nodes$x
  }
  if ("y" %in% names(nodes) && !"igraph_y" %in% names(nodes)) {
    nodes$igraph_y <- nodes$y
  }

  positions <- artifact$positions[expected_gene_ids]
  position_df <- tibble::tibble(
    hgnc_id = expected_gene_ids,
    layout_x = unname(vapply(positions, function(position) as.numeric(position$x), numeric(1))),
    layout_y = unname(vapply(positions, function(position) as.numeric(position$y), numeric(1)))
  )

  nodes <- nodes[, setdiff(names(nodes), c("layout_x", "layout_y")), drop = FALSE]
  nodes <- dplyr::left_join(nodes, position_df, by = "hgnc_id")
  nodes$x <- nodes$layout_x
  nodes$y <- nodes$layout_y

  metadata <- .network_layout_or(network_data$metadata, list())
  artifact_metadata <- .network_layout_or(artifact$metadata, list())
  metadata$layout_engine <- .network_layout_or(artifact$layout_engine, NETWORK_LAYOUT_ENGINE)
  metadata$display_layout_status <- "available"
  metadata$display_layout_key <- layout_key
  metadata$display_layout_version <- NETWORK_LAYOUT_VERSION
  metadata$display_layout_duration_ms <- .network_layout_or(artifact_metadata$layout_duration_ms, NA_integer_)
  metadata$display_layout_node_count <- .network_layout_or(artifact_metadata$node_count, length(expected_gene_ids))
  metadata$display_layout_edge_count <- .network_layout_or(
    artifact_metadata$edge_count,
    nrow(.network_layout_or(network_data$edges, data.frame()))
  )

  network_data$nodes <- nodes
  network_data$metadata <- metadata
  network_data
}

run_network_fcose_layout_helper <- function(
  request,
  helper_path = network_layout_helper_path()
) {
  payload <- jsonlite::toJSON(request, auto_unbox = TRUE, null = "null", digits = NA)
  timeout <- as.numeric(Sys.getenv("NETWORK_LAYOUT_HELPER_TIMEOUT_SECONDS", unset = "120"))
  input_path <- tempfile("network-layout-request-", fileext = ".json")
  stdout_path <- tempfile("network-layout-stdout-", fileext = ".json")
  stderr_path <- tempfile("network-layout-stderr-", fileext = ".log")
  on.exit(unlink(c(input_path, stdout_path, stderr_path), force = TRUE), add = TRUE)

  writeChar(payload, input_path, eos = NULL, useBytes = TRUE)
  status <- suppressWarnings(
    system2(
      command = "node",
      args = helper_path,
      stdin = input_path,
      stdout = stdout_path,
      stderr = stderr_path,
      timeout = timeout
    )
  )
  if (is.null(status)) {
    status <- 0L
  }
  result <- list(
    status = as.integer(status),
    stdout = paste(readLines(stdout_path, warn = FALSE), collapse = "\n"),
    stderr = paste(readLines(stderr_path, warn = FALSE), collapse = "\n")
  )

  if (result$status != 0L) {
    stderr <- substr(.network_layout_or(result$stderr, ""), 1L, 2000L)
    stop(sprintf("network fCoSE layout helper failed: %s", stderr), call. = FALSE)
  }

  tryCatch(
    jsonlite::fromJSON(result$stdout, simplifyVector = FALSE),
    error = function(e) {
      stop(sprintf("network fCoSE layout helper returned invalid JSON: %s", conditionMessage(e)), call. = FALSE)
    }
  )
}

generate_network_display_layout_artifact <- function(network_data,
                                                     cluster_type,
                                                     min_confidence,
                                                     max_edges,
                                                     force = FALSE,
                                                     cache_dir = network_layout_cache_dir(),
                                                     helper_path = network_layout_helper_path()) {
  layout_network <- network_layout_strip_display_fields(network_data)
  layout_key <- network_layout_cache_key(
    layout_network,
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges
  )
  expected_gene_ids <- as.character(layout_network$nodes$hgnc_id)

  if (!isTRUE(force)) {
    cached <- read_network_layout_artifact(layout_key, cache_dir = cache_dir)
    if (!is.null(cached)) {
      validate_network_layout_artifact(cached, expected_gene_ids)
      cached$metadata <- .network_layout_or(cached$metadata, list())
      cached$metadata$layout_key <- layout_key
      cached$metadata$cache_hit <- TRUE
      return(cached)
    }
  }

  request <- build_network_fcose_layout_request(layout_network, layout_key = layout_key)
  artifact <- run_network_fcose_layout_helper(request, helper_path = helper_path)
  validate_network_layout_artifact(artifact, expected_gene_ids)
  artifact$schema_version <- .network_layout_or(artifact$schema_version, NETWORK_LAYOUT_SCHEMA_VERSION)
  artifact$layout_engine <- .network_layout_or(artifact$layout_engine, NETWORK_LAYOUT_ENGINE)
  artifact$metadata <- .network_layout_or(artifact$metadata, list())
  artifact$metadata$layout_key <- layout_key
  artifact$metadata$layout_version <- NETWORK_LAYOUT_VERSION
  artifact$metadata$layout_profile <- NETWORK_LAYOUT_PROFILE
  artifact$metadata$cache_hit <- FALSE

  write_network_layout_artifact(layout_key, artifact, cache_dir = cache_dir)
  artifact
}

apply_cached_network_display_layout <- function(network_data,
                                                cluster_type,
                                                min_confidence,
                                                max_edges,
                                                cache_dir = network_layout_cache_dir()) {
  layout_key <- network_layout_cache_key(
    network_data,
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges
  )
  artifact <- read_network_layout_artifact(layout_key, cache_dir = cache_dir)

  if (is.null(artifact)) {
    network_data$metadata <- .network_layout_or(network_data$metadata, list())
    network_data$metadata$layout_engine <- .network_layout_or(
      network_data$metadata$layout_algorithm,
      "unknown"
    )
    network_data$metadata$display_layout_status <- "missing"
    network_data$metadata$display_layout_key <- layout_key
    network_data$metadata$display_layout_version <- NETWORK_LAYOUT_VERSION
    return(network_data)
  }

  tryCatch(
    attach_network_display_layout(network_data, artifact, layout_key = layout_key),
    error = function(e) {
      network_data$metadata <- .network_layout_or(network_data$metadata, list())
      network_data$metadata$layout_engine <- .network_layout_or(
        network_data$metadata$layout_algorithm,
        "unknown"
      )
      network_data$metadata$display_layout_status <- "invalid"
      network_data$metadata$display_layout_key <- layout_key
      network_data$metadata$display_layout_version <- NETWORK_LAYOUT_VERSION
      network_data$metadata$display_layout_error <- conditionMessage(e)
      network_data
    }
  )
}
