# functions/analysis-reproducibility.R
#
# Self-reproducing cluster-snapshot bundles (#512). Worker/heavy-path only —
# never invoked on a public request (the read endpoints below only decode a row
# that a worker already persisted).
#
# Per clustering snapshot, this exports the inputs needed to INDEPENDENTLY
# recompute the served separation metric:
#   - functional: the full largest-connected-component (LCC) edge list
#     (source, target, combined_score, exp_db_score?) + the COMPLETE membership
#     (every community, incl. clusters below min_size) + params + served_modularity
#   - phenotype:  the MCA coordinate matrix (entity_id, Dim.1..Dim.k) + membership
#     (entity_id, cluster) + params (ncp, kk, consol, seed, prevalence band) +
#     served_silhouette
# plus a SHA-256 `reproducibility_hash` over the CANONICAL pre-gzip JSON so the
# served validation numbers are verifiably tied to their inputs.
#
# The bundle serializer (`analysis_reproducibility_bundle`) is representation-
# agnostic: it serializes whatever payload it is given, gzips it, and hashes the
# pre-gzip JSON. The heavy payload builders (which call build_string_subgraph /
# FactoMineR::MCA) are separated out so the snapshot builder stays thin.
#
# Deps: jsonlite, digest (serializer); igraph, FactoMineR (payload builders).

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Schema version of the bundle envelope itself (independent of the snapshot
# schema version). Bump only if the bundle field layout changes.
ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION <- "1.0"

#' Canonical JSON for the reproducibility bundle.
#'
#' `digits = NA` keeps full numeric precision so a recomputation from the bundle
#' matches the served metric bit-for-bit; `dataframe = "rows"` emits row objects.
#' @noRd
analysis_reproducibility_canonical_json <- function(value) {
  as.character(jsonlite::toJSON(
    value,
    dataframe = "rows",
    auto_unbox = TRUE,
    digits = NA,
    null = "null",
    na = "null"
  ))
}

analysis_reproducibility_rows <- function(df) {
  if (is.null(df)) {
    return(data.frame())
  }
  as.data.frame(df, stringsAsFactors = FALSE)
}

analysis_reproducibility_scalar_num <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_real_)
  }
  suppressWarnings(as.numeric(x[[1]]))
}

#' Assemble, gzip and hash a reproducibility bundle.
#'
#' Representation-agnostic: the payload carries the already-built inputs.
#' - `kind = "functional"`: `payload$edges` (source/target/combined_score/
#'   exp_db_score?), `payload$membership` (node/cluster), `payload$params`,
#'   `payload$served_modularity`.
#' - `kind = "phenotype"`: `payload$coords` (entity_id/Dim.*),
#'   `payload$membership` (entity_id/cluster), `payload$params`,
#'   `payload$served_silhouette`.
#'
#' @return list(kind, bundle_gzip_json = <raw gzip>, reproducibility_hash =
#'   <64-char sha256 over the pre-gzip canonical JSON>, byte_size = <length of
#'   the gzip blob>).
#' @export
analysis_reproducibility_bundle <- function(kind, payload) {
  kind <- as.character(kind)[[1]]
  payload <- payload %||% list()

  if (identical(kind, "functional")) {
    bundle_obj <- list(
      schema_version = ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION,
      kind = kind,
      params = payload$params %||% list(),
      edges = analysis_reproducibility_rows(payload$edges),
      membership = analysis_reproducibility_rows(payload$membership),
      served_modularity = analysis_reproducibility_scalar_num(payload$served_modularity)
    )
  } else if (identical(kind, "phenotype")) {
    bundle_obj <- list(
      schema_version = ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION,
      kind = kind,
      params = payload$params %||% list(),
      coords = analysis_reproducibility_rows(payload$coords),
      membership = analysis_reproducibility_rows(payload$membership),
      served_silhouette = analysis_reproducibility_scalar_num(payload$served_silhouette)
    )
  } else {
    stop(sprintf("Unsupported reproducibility bundle kind: %s", kind), call. = FALSE)
  }

  json <- analysis_reproducibility_canonical_json(bundle_obj)
  gz <- memCompress(charToRaw(json), type = "gzip")
  list(
    kind = kind,
    bundle_gzip_json = gz,
    reproducibility_hash = digest::digest(json, algo = "sha256", serialize = FALSE),
    byte_size = length(gz)
  )
}

#' Decode a stored bundle blob back to the parsed JSON object.
#'
#' Accepts either a raw gzip vector or a DBI blob column value (list-of-raw).
#' @export
analysis_reproducibility_decode <- function(bundle_gzip_json) {
  raw_blob <- bundle_gzip_json
  if (is.list(raw_blob) && length(raw_blob) >= 1L) {
    raw_blob <- raw_blob[[1]]
  }
  if (!is.raw(raw_blob)) {
    stop("reproducibility bundle is not a raw gzip blob", call. = FALSE)
  }
  json <- memDecompress(raw_blob, type = "gzip", asChar = TRUE)
  jsonlite::fromJSON(json, simplifyVector = TRUE)
}

#' Decode a stored bundle blob back to its RAW pre-gzip canonical-JSON string.
#'
#' Identical blob-unwrap to `analysis_reproducibility_decode()`, but returns the
#' verbatim `memDecompress(..., asChar = TRUE)` string WITHOUT parsing. This is
#' the exact byte content the `reproducibility_hash` was computed over
#' (`digest::digest(json, algo = "sha256", serialize = FALSE)`), so
#' `sha256(charToRaw(<this>)) == reproducibility_hash` bit-for-bit. The immutable
#' release (#573) materializes `reproducibility.json` from THIS string, never from
#' `analysis_reproducibility_decode()` — a parse + re-serialize round-trip drops
#' the `digits = NA` precision and would break the content-address hash.
#'
#' Accepts either a raw gzip vector or a DBI blob column value (list-of-raw).
#' @return chr(1), the pre-gzip canonical JSON.
#' @export
analysis_reproducibility_decode_raw <- function(bundle_gzip_json) {
  raw_blob <- bundle_gzip_json
  if (is.list(raw_blob) && length(raw_blob) >= 1L) {
    raw_blob <- raw_blob[[1]]
  }
  if (!is.raw(raw_blob)) {
    stop("reproducibility bundle is not a raw gzip blob", call. = FALSE)
  }
  memDecompress(raw_blob, type = "gzip", asChar = TRUE)
}

# --------------------------------------------------------------------------- #
# Heavy payload builders (worker/heavy-path only).
# --------------------------------------------------------------------------- #

#' Build the functional reproducibility payload from the clustered graph.
#'
#' Reconstructs the byte-identical STRING subgraph via `build_string_subgraph`,
#' restricts to the largest connected component (the connected substrate the
#' modularity null is calibrated against), reclusters with the same seeded Leiden
#' (`.leiden_membership`), and records the LCC modularity as `served_modularity`
#' so a recomputation from the bundle reproduces it exactly.
#' @noRd
analysis_reproducibility_functional_payload <- function(hgnc_list, val = NULL, params = list(),
                                                        score_threshold = 400, resolution = 1.0,
                                                        seed = 42L) {
  subgraph <- build_string_subgraph(hgnc_list, score_threshold)
  lcc <- igraph::largest_component(subgraph)
  membership_int <- .leiden_membership(lcc, resolution, seed)
  served_modularity <- igraph::modularity(
    lcc, membership_int,
    weights = igraph::E(lcc)$combined_score
  )

  el <- igraph::as_data_frame(lcc, what = "edges")
  edges <- data.frame(
    source = as.character(el$from),
    target = as.character(el$to),
    combined_score = suppressWarnings(as.numeric(el$combined_score)),
    stringsAsFactors = FALSE
  )
  if (!is.null(el$exp_db_score)) {
    edges$exp_db_score <- suppressWarnings(as.numeric(el$exp_db_score))
  }

  membership <- data.frame(
    node = as.character(igraph::V(lcc)$name),
    cluster = as.integer(membership_int),
    stringsAsFactors = FALSE
  )

  partition <- val$partition %||% list()
  bundle_params <- utils::modifyList(
    list(
      score_threshold = score_threshold,
      resolution = resolution,
      seed = seed,
      weight_channel = partition$weight_channel %||% "combined_score",
      modularity_full_partition = analysis_reproducibility_scalar_num(partition$modularity),
      modularity_z = analysis_reproducibility_scalar_num(partition$modularity_z),
      n_clusters = partition$n_clusters %||% NA_integer_,
      giant_component = partition$giant_component %||% NULL
    ),
    params %||% list()
  )

  list(
    edges = edges,
    membership = membership,
    served_modularity = served_modularity,
    params = bundle_params
  )
}

#' Flatten the served phenotype cluster tibble to an (entity_id, cluster) frame.
#' @noRd
analysis_reproducibility_phenotype_membership <- function(clusters) {
  clusters <- tibble::as_tibble(clusters %||% tibble::tibble())
  empty <- data.frame(entity_id = character(), cluster = character(), stringsAsFactors = FALSE)
  if (nrow(clusters) == 0L || !("identifiers" %in% names(clusters))) {
    return(empty)
  }
  cluster_col <- if ("cluster" %in% names(clusters)) "cluster" else names(clusters)[[1]]
  parts <- lapply(seq_len(nrow(clusters)), function(i) {
    ids <- tibble::as_tibble(clusters$identifiers[[i]] %||% tibble::tibble())
    if (nrow(ids) == 0L || !("entity_id" %in% names(ids))) {
      return(NULL)
    }
    data.frame(
      entity_id = as.character(ids$entity_id),
      cluster = as.character(clusters[[cluster_col]][[i]]),
      stringsAsFactors = FALSE
    )
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (length(parts) == 0L) {
    return(empty)
  }
  do.call(rbind, parts)
}

#' Build the phenotype reproducibility payload from the input matrix + clusters.
#'
#' Recomputes the MCA coordinates with the SAME seeded configuration
#' `validate_phenotype_clusters` uses (set.seed(seed); MCA(ncp = 8, quali.sup,
#' quanti.sup)), takes membership from the served cluster tibble, and records the
#' served mean silhouette so a recomputation on the bundle's coords reproduces it.
#' @noRd
analysis_reproducibility_phenotype_payload <- function(input_matrix, clusters, val = NULL,
                                                       quali_sup_var = 1:1, quanti_sup_var = 2:4,
                                                       ncp = 8L, seed = 42L, params = list()) {
  membership <- analysis_reproducibility_phenotype_membership(clusters)

  entity_ids <- as.character(rownames(input_matrix))
  set.seed(seed)
  mca <- FactoMineR::MCA(
    input_matrix,
    ncp = ncp,
    quali.sup = quali_sup_var,
    quanti.sup = quanti_sup_var,
    graph = FALSE
  )
  coord <- mca$ind$coord
  rownames(coord) <- entity_ids
  colnames(coord) <- paste0("Dim.", seq_len(ncol(coord)))

  keep_ids <- intersect(entity_ids, as.character(membership$entity_id))
  coord_keep <- coord[match(keep_ids, entity_ids), , drop = FALSE]
  coords <- cbind(
    data.frame(entity_id = keep_ids, stringsAsFactors = FALSE),
    as.data.frame(coord_keep, stringsAsFactors = FALSE)
  )

  partition <- val$partition %||% list()
  provenance <- attr(input_matrix, "mca_provenance") %||% list()
  bundle_params <- utils::modifyList(
    list(
      ncp = ncp,
      kk = as.character(partition$hcpc_kk %||% NA_character_),
      consolidation = partition$consolidation %||% NA,
      seed = seed,
      prevalence_band = provenance$prevalence_band %||% NULL,
      silhouette_z = analysis_reproducibility_scalar_num(partition$silhouette_z),
      n_clusters = partition$n_clusters %||% NA_integer_
    ),
    params %||% list()
  )

  list(
    coords = coords,
    membership = membership,
    served_silhouette = analysis_reproducibility_scalar_num(partition$mean_silhouette),
    params = bundle_params
  )
}

# --------------------------------------------------------------------------- #
# Snapshot-builder wrappers (never crash a refresh; best-effort additive bundle).
# --------------------------------------------------------------------------- #

#' @noRd
analysis_snapshot_functional_reproducibility <- function(hgnc_list, val = NULL, params = list()) {
  tryCatch(
    analysis_reproducibility_bundle(
      "functional",
      analysis_reproducibility_functional_payload(hgnc_list, val = val, params = params)
    ),
    error = function(e) {
      message("[reproducibility] functional bundle build failed: ", conditionMessage(e))
      NULL
    }
  )
}

#' @noRd
analysis_snapshot_phenotype_reproducibility <- function(input_matrix, clusters, val = NULL, params = list()) {
  tryCatch(
    analysis_reproducibility_bundle(
      "phenotype",
      analysis_reproducibility_phenotype_payload(input_matrix, clusters, val = val, params = params)
    ),
    error = function(e) {
      message("[reproducibility] phenotype bundle build failed: ", conditionMessage(e))
      NULL
    }
  )
}

# --------------------------------------------------------------------------- #
# Read-endpoint response (DB-only; decodes an already-persisted bundle).
# --------------------------------------------------------------------------- #

#' Build the read-only reproducibility endpoint response for an analysis type.
#'
#' Resolves the current public snapshot for the (approved-public) clustering
#' preset, fetches its reproducibility row, and returns the decoded bundle. Sets
#' `res$status` on the miss paths. DB-only — never computes clusters/nulls.
#'
#' @param analysis_type "functional_clusters" or "phenotype_clusters".
#' @return A list with reproducibility_hash, kind, byte_size, snapshot_id, bundle.
#' @export
analysis_reproducibility_endpoint <- function(analysis_type, res = NULL, conn = NULL) {
  normalized <- analysis_snapshot_normalize_params(analysis_type, list())
  manifest <- analysis_snapshot_public_manifest(
    normalized$analysis_type,
    normalized$parameter_hash,
    conn = conn
  )
  if (is.null(manifest) || (is.data.frame(manifest) && nrow(manifest) == 0L)) {
    if (!is.null(res)) res$status <- 404L
    return(list(
      error = "reproducibility_unavailable",
      message = "No public snapshot is available for this analysis type yet.",
      analysis_type = normalized$analysis_type
    ))
  }

  # Staleness gate: mirror the main analysis endpoints (which 503 on a snapshot
  # whose computed status is not "available") so a stale / source-version-mismatched
  # snapshot's bundle is never served as if it were current (`status_code` is
  # computed onto the manifest by analysis_snapshot_public_manifest()).
  status_code <- tryCatch(as.character(manifest$status_code)[1], error = function(e) NA_character_)
  if (!is.na(status_code) && !identical(status_code, "available")) {
    if (!is.null(res)) res$status <- 503L
    return(list(
      error = status_code,
      message = paste(
        "The current snapshot is not available (stale, missing, or source-version",
        "mismatch); its reproducibility bundle is not served as current."
      ),
      analysis_type = normalized$analysis_type
    ))
  }

  snapshot_id <- manifest$snapshot_id[[1]]
  row <- analysis_snapshot_get_reproducibility(snapshot_id, conn = conn)
  if (is.null(row) || (is.data.frame(row) && nrow(row) == 0L)) {
    if (!is.null(res)) res$status <- 404L
    return(list(
      error = "reproducibility_unavailable",
      message = "The current snapshot has no reproducibility bundle.",
      analysis_type = normalized$analysis_type,
      snapshot_id = snapshot_id
    ))
  }

  bundle <- tryCatch(
    analysis_reproducibility_decode(row$bundle_gzip_json),
    error = function(e) NULL
  )
  if (is.null(bundle)) {
    if (!is.null(res)) res$status <- 500L
    return(list(
      error = "reproducibility_decode_failed",
      message = "The stored reproducibility bundle could not be decoded.",
      analysis_type = normalized$analysis_type,
      snapshot_id = snapshot_id
    ))
  }

  list(
    reproducibility_hash = as.character(row$reproducibility_hash[[1]]),
    kind = as.character(row$kind[[1]]),
    byte_size = as.integer(row$byte_size[[1]]),
    snapshot_id = snapshot_id,
    bundle = bundle
  )
}

# --- persistence (kept here, not in analysis-snapshot-repository.R, so that file
# stays under the 600-line ceiling; these use repository/db helpers defined
# elsewhere in the global environment). ------------------------------------------

#' Persist a clustering snapshot's reproducibility bundle (#512).
#'
#' Stores the gzipped canonical-JSON bundle (a raw vector) into the LONGBLOB
#' column via a dedicated `dbSendStatement`/`dbBind` so the multi-MB blob is bound
#' as a single BLOB value (`list(raw_vector)`) and is NOT passed through
#' `db_execute_statement`, whose eager parameter stringification would deparse the
#' whole blob for its debug log. `bundle` is the value returned by
#' `analysis_reproducibility_bundle()`. A NULL/empty bundle is a no-op so a
#' snapshot whose additive bundle build failed still commits.
#' @export
analysis_snapshot_insert_reproducibility <- function(snapshot_id, bundle, conn = NULL) {
  if (is.null(bundle) || is.null(bundle$bundle_gzip_json)) {
    return(invisible(0L))
  }
  gz <- bundle$bundle_gzip_json
  if (!is.raw(gz)) {
    return(invisible(0L))
  }

  analysis_snapshot_with_repository_connection(conn, function(repro_conn) {
    stmt <- DBI::dbSendStatement(
      repro_conn,
      "INSERT INTO analysis_snapshot_reproducibility
         (snapshot_id, kind, bundle_gzip_json, reproducibility_hash, byte_size)
       VALUES (?, ?, ?, ?, ?)"
    )
    on.exit(DBI::dbClearResult(stmt), add = TRUE)
    DBI::dbBind(stmt, unname(list(
      as.numeric(snapshot_id),
      as.character(bundle$kind %||% NA_character_),
      list(gz), # bind the raw gzip vector as a single BLOB value
      as.character(bundle$reproducibility_hash %||% NA_character_),
      as.integer(bundle$byte_size %||% length(gz))
    )))
    DBI::dbGetRowsAffected(stmt)
  })

  invisible(1L)
}

#' Fetch the reproducibility row for a snapshot (raw blob + metadata).
#'
#' @return A 1-row data frame (kind, bundle_gzip_json blob, reproducibility_hash,
#'   byte_size, created_at) or NULL when the snapshot has no bundle.
#' @export
analysis_snapshot_get_reproducibility <- function(snapshot_id, conn = NULL) {
  rows <- db_execute_query(
    "SELECT kind, bundle_gzip_json, reproducibility_hash, byte_size, created_at
       FROM analysis_snapshot_reproducibility
      WHERE snapshot_id = ?
      LIMIT 1",
    unname(list(as.numeric(snapshot_id))),
    conn = conn
  )
  if (is.null(rows) || nrow(rows) == 0L) {
    return(NULL)
  }
  rows
}
