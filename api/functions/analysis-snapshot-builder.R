# functions/analysis-snapshot-builder.R
if (!exists("%||%", mode = "function")) `%||%` <- function(x, y) if (is.null(x)) y else x
analysis_snapshot_hash_json <- function(value) {
  if (exists("analysis_snapshot_canonical_json", mode = "function")) return(analysis_snapshot_canonical_json(value))
  as.character(jsonlite::toJSON(
    value, auto_unbox = TRUE, null = "null", na = "null", dataframe = "rows",
    POSIXt = "ISO8601", Date = "ISO8601"
  ))
}

analysis_snapshot_payload_hash <- function(payload) {
  digest::digest(analysis_snapshot_hash_json(payload), algo = "sha256", serialize = FALSE)
}

analysis_snapshot_input_hash <- function(inputs) {
  digest::digest(analysis_snapshot_hash_json(inputs), algo = "sha256", serialize = FALSE)
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

analysis_snapshot_trigger_llm_generation <- function(analysis_type, payload, parent_job_id = NULL, conn = NULL) {
  cluster_type <- analysis_snapshot_cluster_llm_type(analysis_type)
  if (is.null(cluster_type)) {
    return(NULL)
  }

  # Retire orphaned is_current summary rows whose hash is not in the
  # just-published snapshot (#485). Runs regardless of whether generation is
  # triggered so a re-clustering that drops cluster numbers cannot leave stale
  # is_current rows behind. Best-effort: a cleanup failure must not fail the
  # refresh. Guarded by exists() so the builder can be sourced standalone.
  if (exists("retire_orphan_cluster_summaries", mode = "function")) {
    current_hashes <- if (is.data.frame(payload$clusters) &&
                            "cluster_hash" %in% names(payload$clusters)) {
      payload$clusters$cluster_hash
    } else {
      character()
    }
    tryCatch(
      retire_orphan_cluster_summaries(cluster_type, current_hashes, conn = conn),
      error = function(e) {
        message("[snapshot] retire_orphan_cluster_summaries failed: ", conditionMessage(e))
      }
    )
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
      # #514: refuse to publish an incoherent snapshot (stale membership vs fresh
      # validation, or a channel disagreement) BEFORE joining. Also carries the served
      # membership channel forward as a `membership_weight_channel` attribute.
      clusters <- analysis_snapshot_join_validated_clusters(clusters, val, kind = "functional")
      # Additive provenance (#514 channel + #573 H4 reference member sets) into
      # validation_json; excluded from payload_hash, so no cluster_hash churn.
      val$partition <- analysis_snapshot_attach_partition_provenance(val$partition, clusters)
      built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "functional")
      # #512: additive self-reproducing bundle (LCC edge list + full membership +
      # served modularity). Best-effort; a NULL bundle never blocks the refresh.
      reproducibility <- analysis_snapshot_functional_reproducibility(
        gene_ids, val = val, params = list(algorithm = params$algorithm)
      )
      payload <- list(kind = "clusters", raw = clusters, clusters = built$clusters,
           members = built$members, row_counts = built$row_counts,
           partition_validation = val$partition, reproducibility = reproducibility)
      # #585: applied params as an R ATTRIBUTE (never a payload list element, so it
      # can never enter payload_hash).
      attr(payload, "applied_params") <- analysis_snapshot_functional_applied_params(
        params, payload$partition_validation$membership_weight_channel
      )
      payload
    },
    phenotype_clusters = {
      clusters <- generate_phenotype_clusters()
      n_res <- as.integer(Sys.getenv("ANALYSIS_CLUSTER_VALIDATION_RESAMPLES", "100"))
      input_matrix <- generate_phenotype_cluster_input()$matrix
      val <- validate_phenotype_clusters(
        input_matrix,
        quali_sup_var = 1:1, quanti_sup_var = 2:4, n_resamples = n_res
      )
      # #514: same coherence gate as the functional axis (phenotype has no channel).
      clusters <- analysis_snapshot_join_validated_clusters(clusters, val, kind = "phenotype")
      val$partition <- analysis_snapshot_attach_partition_provenance(val$partition, clusters)

      # #630: computed, registry-backed syndromicity per cluster. Loads the
      # annotation evidence once for the whole snapshot; see
      # functions/syndromicity-snapshot.R for why that matters and why
      # cluster_hash is unaffected. Deliberately NOT exists()-guarded: a missing
      # module must fail loudly rather than silently publish a snapshot whose
      # syndromicity is absent.
      clusters <- syndromicity_attach_to_clusters(clusters)

      built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "phenotype")
      # #512: additive bundle (MCA coords + membership + served silhouette).
      reproducibility <- analysis_snapshot_phenotype_reproducibility(
        input_matrix, clusters, val = val
      )
      payload <- list(kind = "clusters", raw = clusters, clusters = built$clusters,
           members = built$members, row_counts = built$row_counts,
           partition_validation = val$partition, reproducibility = reproducibility)
      # #585: applied MCA/HCPC params as an R ATTRIBUTE (excluded from payload_hash).
      attr(payload, "applied_params") <- analysis_snapshot_phenotype_applied_params(
        nrow(built$clusters)
      )
      payload
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
      result <- analysis_snapshot_build_dependency_bound_pc_fc_correlation(conn = conn)
      rows <- result$rows
      built <- analysis_snapshot_build_correlation_rows(rows, correlation_kind = "phenotype_functional")
      list(
        kind = "correlations",
        raw = rows,
        correlations = built$correlations,
        row_counts = built$row_counts,
        dependencies = result$dependencies
      )
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
    # Derived manifest provenance (#585 B3): payload/input hashing, source-version
    # resolution (#22/#459), and additive generator provenance (#585) + gate; in the
    # provenance module, exists()-guarded (builder idiom) so isolated units degrade.
    prov <- if (exists("analysis_snapshot_compute_manifest_provenance", mode = "function")) {
      analysis_snapshot_compute_manifest_provenance(normalized, payload, source_data_version, refresh_conn)
    } else {
      list(source_versions = list(sysndd_public_data = source_data_version))
    }
    payload_hash <- prov$payload_hash %||% analysis_snapshot_payload_hash(
      payload[setdiff(names(payload), c("raw", "partition_validation", "reproducibility"))])
    input_hash <- prov$input_hash %||% analysis_snapshot_input_hash(
      list(analysis_type = normalized$analysis_type, params = normalized$params,
           source_data_version = source_data_version))
    source_versions <- prov$source_versions
    db_release_version <- prov$db_release_version %||% "unknown"
    db_release_commit  <- prov$db_release_commit %||% "unknown"
    generator_block <- prov$generator

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
          source_versions = source_versions,
          source_data_version = source_data_version,
          parameters_json = normalized$parameters_json,
          input_hash = input_hash,
          payload_hash = payload_hash,
          algorithm_name = normalized$params$algorithm %||% normalized$params$cluster_type %||% NA_character_,
          row_counts = row_counts,
          validation = payload$partition_validation,   # NULL for non-clustering presets
          generator = generator_block,                 # #585 additive provenance (JSON column)
          db_release_version = db_release_version,
          db_release_commit  = db_release_commit
        ),
        conn = txn_conn
      )

      if (identical(payload$kind, "network")) {
        analysis_snapshot_insert_network_rows(snapshot_id, payload, conn = txn_conn)
      } else if (identical(payload$kind, "clusters")) {
        analysis_snapshot_insert_cluster_rows(snapshot_id, payload$clusters, payload$members, conn = txn_conn)
        if (!is.null(payload$reproducibility)) {
          analysis_snapshot_insert_reproducibility(snapshot_id, payload$reproducibility, conn = txn_conn)
        }
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
      parent_job_id = job_id %||% write_result$snapshot_id,
      conn = refresh_conn
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
      dependencies = payload$dependencies,
      stale_after = stale_after,
      pruned = write_result$pruned,
      llm_generation = llm_generation
    )
  })
}
