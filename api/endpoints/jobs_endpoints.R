# api/endpoints/jobs_endpoints.R
#
# Async job submission and status polling endpoints.
# Uses mirai for background execution, returns HTTP 202 Accepted for long-running operations.
#
# Endpoints:
#   POST /api/jobs/clustering/submit - Submit functional clustering job
#   POST /api/jobs/phenotype_clustering/submit - Submit phenotype clustering job
#   GET /api/jobs/<job_id>/status - Poll job status and retrieve results
#
# Dependencies:
#   - pool (global database connection pool)
#   - create_job, get_job_status, check_duplicate_job (from job-manager.R)
#   - gen_string_clust_obj, gen_mca_clust_obj (analysis functions - loaded in daemons via everywhere())

## -------------------------------------------------------------------##
## Job Submission Endpoints
## -------------------------------------------------------------------##

#* Submit Functional Clustering Job
#*
#* Submits an async job to compute functional clustering via STRING-db.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @post /clustering/submit
function(req, res) {
  # CRITICAL: Extract request data BEFORE mirai call

  # Connection objects cannot cross process boundaries
  genes_list <- NULL
  if (!is.null(req$argsBody$genes)) {
    genes_list <- req$argsBody$genes
  }

  # Extract algorithm parameter (default: leiden)
  # Ensure we get a scalar value (JSON may pass arrays)
  algorithm <- "leiden"
  if (!is.null(req$argsBody$algorithm)) {
    algo_input <- req$argsBody$algorithm
    # Handle array input - always take first element if vector
    if (is.list(algo_input) || length(algo_input) >= 1) {
      algo_input <- algo_input[[1]]
    }
    algorithm <- tolower(as.character(algo_input))
    if (!algorithm %in% c("leiden", "walktrap")) {
      algorithm <- "leiden"
    }
  }

  # If no genes provided, use default (all NDD genes)
  # This matches current functional_clustering endpoint behavior
  if (is.null(genes_list) || length(genes_list) == 0) {
    genes_list <- pool %>%
      tbl("ndd_entity_view") %>%
      arrange(entity_id) %>%
      filter(ndd_phenotype == 1) %>%
      select(hgnc_id) %>%
      collect() %>%
      unique() %>%
      pull(hgnc_id)
  }

  # CRITICAL: Pre-fetch STRING ID table BEFORE mirai call
  # Database connections cannot cross process boundaries (mirai best practice)
  string_id_table <- pool %>%
    tbl("non_alt_loci_set") %>%
    filter(!is.na(STRING_id)) %>%
    select(symbol, hgnc_id, STRING_id) %>%
    collect()

  # Check for duplicate job (include algorithm in check)
  dup_check <- check_duplicate_job("clustering", list(genes = genes_list, algorithm = algorithm))
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "Identical job already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # Define category links (needed for result)
  category_links <- tibble::tibble(
    value = c(
      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
    ),
    link = c(
      "https://www.ebi.ac.uk/QuickGO/term/",
      "https://www.ebi.ac.uk/QuickGO/term/",
      "https://disease-ontology.org/term/",
      "https://www.ebi.ac.uk/QuickGO/term/",
      "https://hpo.jax.org/app/browse/term/",
      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
      "https://www.genome.jp/dbget-bin/www_bget?",
      "https://www.uniprot.org/keywords/",
      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
      "https://www.ebi.ac.uk/interpro/entry/pfam/",
      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
      "https://www.ebi.ac.uk/QuickGO/term/",
      "https://reactome.org/content/detail/R-",
      "http://www.ebi.ac.uk/interpro/entry/smart/",
      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
      "https://www.wikipathways.org/index.php/Pathway:"
    )
  )

  # Cache-first: if the memoized function already has a cached result,
  # return it immediately without spawning an async daemon job.
  # The network_edges endpoint (graph) warms this cache on first load,
  # so subsequent table requests resolve instantly.
  cache_hit <- tryCatch(
    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
    error = function(e) FALSE
  )

  if (cache_hit) {
    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)

    categories <- cached_clusters %>%
      dplyr::select(term_enrichment) %>%
      tidyr::unnest(cols = c(term_enrichment)) %>%
      dplyr::select(category) %>%
      unique() %>%
      dplyr::arrange(category) %>%
      dplyr::mutate(
        text = dplyr::case_when(
          nchar(category) <= 5 ~ category,
          nchar(category) > 5 ~ stringr::str_to_sentence(category)
        )
      ) %>%
      dplyr::select(value = category, text) %>%
      dplyr::left_join(category_links, by = c("value"))

    # Create pre-completed job for tracking consistency
    job_id <- uuid::UUIDgenerate()
    jobs_env[[job_id]] <- list(
      job_id = job_id,
      operation = "clustering",
      status = "completed",
      mirai_obj = NULL,
      submitted_at = Sys.time(),
      params_hash = digest::digest(list(genes = genes_list, algorithm = algorithm)),
      result = list(
        clusters = cached_clusters,
        categories = categories,
        meta = list(
          algorithm = algorithm,
          gene_count = length(genes_list),
          cluster_count = nrow(cached_clusters),
          cache_hit = TRUE
        )
      ),
      error = NULL,
      completed_at = Sys.time()
    )

    # Chain LLM generation for cache hits (same as job completion path)
    if (exists("trigger_llm_batch_generation", mode = "function")) {
      message("[jobs_endpoints] Triggering LLM batch generation for functional clusters (cache hit)")
      tryCatch(
        trigger_llm_batch_generation(
          clusters = cached_clusters,
          cluster_type = "functional",
          parent_job_id = job_id
        ),
        error = function(e) message("[jobs_endpoints] LLM trigger error: ", e$message)
      )
    } else {
      message("[jobs_endpoints] trigger_llm_batch_generation not found")
    }

    res$status <- 202
    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
    res$setHeader("Retry-After", "0")

    return(list(
      job_id = job_id,
      status = "accepted",
      estimated_seconds = 0,
      status_url = paste0("/api/jobs/", job_id, "/status")
    ))
  }

  # Cache miss - create async job
  result <- create_job(
    operation = "clustering",
    params = list(
      genes = genes_list,
      algorithm = algorithm,
      category_links = category_links,
      string_id_table = string_id_table
    ),
    executor_fn = function(params) {
      # This runs in mirai daemon
      # Pass pre-fetched string_id_table since daemon can't access pool
      clusters <- gen_string_clust_obj(
        params$genes,
        algorithm = params$algorithm,
        string_id_table = params$string_id_table
      )

      # Generate categories from clusters
      categories <- clusters %>%
        dplyr::select(term_enrichment) %>%
        tidyr::unnest(cols = c(term_enrichment)) %>%
        dplyr::select(category) %>%
        unique() %>%
        dplyr::arrange(category) %>%
        dplyr::mutate(
          text = dplyr::case_when(
            nchar(category) <= 5 ~ category,
            nchar(category) > 5 ~ stringr::str_to_sentence(category)
          )
        ) %>%
        dplyr::select(value = category, text) %>%
        dplyr::left_join(params$category_links, by = c("value"))

      # Return both clusters and categories
      list(
        clusters = clusters,
        categories = categories,
        meta = list(
          algorithm = params$algorithm,
          gene_count = length(params$genes),
          cluster_count = nrow(clusters)
        )
      )
    }
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "5")

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = result$estimated_seconds,
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

## -------------------------------------------------------------------##
## Phenotype Clustering Submission
## -------------------------------------------------------------------##

#* Submit Phenotype Clustering Job
#*
#* Submits an async job to compute phenotype clustering via MCA.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @post /phenotype_clustering/submit
function(req, res) {
  # Prepare data BEFORE mirai (database connections can't cross process boundary)
  # This replicates the data gathering from phenotype_clustering endpoint

  id_phenotype_ids <- c(
    "HP:0001249", "HP:0001256", "HP:0002187",
    "HP:0002342", "HP:0006889", "HP:0010864"
  )
  categories <- c("Definitive")

  # Gather all data from database
  ndd_entity_view_tbl <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()
  ndd_entity_review_tbl <- pool %>%
    tbl("ndd_entity_review") %>%
    collect() %>%
    filter(is_primary == 1) %>%
    select(review_id)
  ndd_review_phenotype_connect_tbl <- pool %>%
    tbl("ndd_review_phenotype_connect") %>%
    collect()
  modifier_list_tbl <- pool %>%
    tbl("modifier_list") %>%
    collect()
  phenotype_list_tbl <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  # Create params hash based on entity count (stable identifier)
  params_hash_input <- list(
    entity_count = nrow(ndd_entity_view_tbl),
    operation = "phenotype_clustering"
  )

  # Check for duplicate
  dup_check <- check_duplicate_job("phenotype_clustering", params_hash_input)
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "Identical job already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # Build the data frame for clustering (same as regular API endpoint)
  sysndd_db_phenotypes <- ndd_entity_view_tbl %>%
    left_join(ndd_review_phenotype_connect_tbl, by = "entity_id") %>%
    left_join(modifier_list_tbl, by = "modifier_id") %>%
    left_join(phenotype_list_tbl, by = "phenotype_id") %>%
    mutate(ndd_phenotype = case_when(
      ndd_phenotype == 1 ~ "Yes",
      ndd_phenotype == 0 ~ "No"
    )) %>%
    filter(ndd_phenotype == "Yes") %>%
    filter(category %in% categories) %>%
    filter(modifier_name == "present") %>%
    filter(review_id %in% ndd_entity_review_tbl$review_id) %>%
    select(entity_id, hpo_mode_of_inheritance_term_name, phenotype_id, HPO_term, hgnc_id) %>%
    group_by(entity_id) %>%
    mutate(
      phenotype_non_id_count = sum(!(phenotype_id %in% id_phenotype_ids)),
      phenotype_id_count = sum(phenotype_id %in% id_phenotype_ids)
    ) %>%
    ungroup() %>%
    unique()

  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes %>%
    mutate(present = "yes") %>%
    select(-phenotype_id) %>%
    pivot_wider(names_from = HPO_term, values_from = present) %>%
    group_by(hgnc_id) %>%
    mutate(gene_entity_count = n()) %>%
    ungroup() %>%
    relocate(gene_entity_count, .after = phenotype_id_count) %>%
    select(-hgnc_id)

  sysndd_db_phenotypes_wider_df <- sysndd_db_phenotypes_wider %>%
    select(-entity_id) %>%
    as.data.frame()
  row.names(sysndd_db_phenotypes_wider_df) <- sysndd_db_phenotypes_wider$entity_id

  # Cache-first: if the memoized function already has a cached result,
  # return it immediately without spawning an async daemon job.
  # This ensures the LLM batch uses the same hashes as the API endpoint.
  cache_hit <- tryCatch(
    memoise::has_cache(gen_mca_clust_obj_mem)(sysndd_db_phenotypes_wider_df),
    error = function(e) FALSE
  )

  if (cache_hit) {
    cached_clusters <- gen_mca_clust_obj_mem(sysndd_db_phenotypes_wider_df)

    # Add back gene identifiers
    ndd_entity_view_tbl_sub <- ndd_entity_view_tbl %>%
      select(entity_id, hgnc_id, symbol)

    cached_clusters_with_ids <- cached_clusters %>%
      unnest(identifiers) %>%
      mutate(entity_id = as.integer(entity_id)) %>%
      left_join(ndd_entity_view_tbl_sub, by = "entity_id") %>%
      nest(identifiers = c(entity_id, hgnc_id, symbol))

    # Create pre-completed job for tracking consistency
    job_id <- uuid::UUIDgenerate()
    jobs_env[[job_id]] <- list(
      job_id = job_id,
      operation = "phenotype_clustering",
      status = "completed",
      mirai_obj = NULL,
      submitted_at = Sys.time(),
      params_hash = digest::digest(params_hash_input),
      result = cached_clusters_with_ids,
      error = NULL,
      completed_at = Sys.time()
    )

    # Chain LLM generation for cache hits (same as job completion path)
    if (exists("trigger_llm_batch_generation", mode = "function")) {
      message("[jobs_endpoints] Triggering LLM batch generation for phenotype clusters (cache hit)")
      tryCatch(
        trigger_llm_batch_generation(
          clusters = cached_clusters_with_ids,
          cluster_type = "phenotype",
          parent_job_id = job_id
        ),
        error = function(e) message("[jobs_endpoints] LLM trigger error: ", e$message)
      )
    } else {
      message("[jobs_endpoints] trigger_llm_batch_generation not found")
    }

    res$status <- 202
    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
    res$setHeader("Retry-After", "0")

    return(list(
      job_id = job_id,
      status = "accepted",
      estimated_seconds = 0,
      status_url = paste0("/api/jobs/", job_id, "/status")
    ))
  }

  # Cache miss - create async job with pre-built data frame
  result <- create_job(
    operation = "phenotype_clustering",
    params = list(
      ndd_entity_view_tbl = ndd_entity_view_tbl,
      ndd_entity_review_tbl = ndd_entity_review_tbl,
      ndd_review_phenotype_connect_tbl = ndd_review_phenotype_connect_tbl,
      modifier_list_tbl = modifier_list_tbl,
      phenotype_list_tbl = phenotype_list_tbl,
      id_phenotype_ids = id_phenotype_ids,
      categories = categories
    ),
    executor_fn = function(params) {
      # This runs in mirai daemon
      # Replicate phenotype_clustering logic
      sysndd_db_phenotypes <- params$ndd_entity_view_tbl %>%
        left_join(params$ndd_review_phenotype_connect_tbl, by = "entity_id") %>%
        left_join(params$modifier_list_tbl, by = "modifier_id") %>%
        left_join(params$phenotype_list_tbl, by = "phenotype_id") %>%
        mutate(ndd_phenotype = case_when(
          ndd_phenotype == 1 ~ "Yes",
          ndd_phenotype == 0 ~ "No"
        )) %>%
        filter(ndd_phenotype == "Yes") %>%
        filter(category %in% params$categories) %>%
        filter(modifier_name == "present") %>%
        filter(review_id %in% params$ndd_entity_review_tbl$review_id) %>%
        select(
          entity_id, hpo_mode_of_inheritance_term_name, phenotype_id,
          HPO_term, hgnc_id
        ) %>%
        group_by(entity_id) %>%
        mutate(
          phenotype_non_id_count = sum(!(phenotype_id %in% params$id_phenotype_ids)),
          phenotype_id_count = sum(phenotype_id %in% params$id_phenotype_ids)
        ) %>%
        ungroup() %>%
        unique()

      sysndd_db_phenotypes_wider <- sysndd_db_phenotypes %>%
        mutate(present = "yes") %>%
        select(-phenotype_id) %>%
        pivot_wider(names_from = HPO_term, values_from = present) %>%
        group_by(hgnc_id) %>%
        mutate(gene_entity_count = n()) %>%
        ungroup() %>%
        relocate(gene_entity_count, .after = phenotype_id_count) %>%
        select(-hgnc_id)

      sysndd_db_phenotypes_wider_df <- sysndd_db_phenotypes_wider %>%
        select(-entity_id) %>%
        as.data.frame()

      row.names(sysndd_db_phenotypes_wider_df) <- sysndd_db_phenotypes_wider$entity_id

      # Use non-memoized version (memoized not available in daemon)
      phenotype_clusters <- gen_mca_clust_obj(sysndd_db_phenotypes_wider_df)

      # Add back identifiers
      ndd_entity_view_tbl_sub <- params$ndd_entity_view_tbl %>%
        select(entity_id, hgnc_id, symbol)

      phenotype_clusters %>%
        unnest(identifiers) %>%
        mutate(entity_id = as.integer(entity_id)) %>%
        left_join(ndd_entity_view_tbl_sub, by = "entity_id") %>%
        nest(identifiers = c(entity_id, hgnc_id, symbol))
    }
  )

  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "5")

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 60,
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

## -------------------------------------------------------------------##
## Ontology Update Submission
## -------------------------------------------------------------------##

#* Submit Ontology Update Job
#*
#* Submits an async job to update disease ontology data from MONDO and OMIM sources.
#* Requires Administrator role.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @post /ontology_update/submit
function(req, res) {
  require_role(req, res, "Administrator")

  # CRITICAL: Extract all database data BEFORE mirai
  # Database connections cannot cross process boundaries

  # Get HGNC list
  hgnc_list <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(symbol, hgnc_id) %>%
    collect()

  # Get mode of inheritance list
  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    filter(is_active == 1) %>%
    select(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name) %>%
    collect()

  # Check for duplicate job (ontology update has no params variation)
  dup_check <- check_duplicate_job("ontology_update", list(operation = "ontology_update"))
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "Ontology update job already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # Create async job
  result <- create_job(
    operation = "ontology_update",
    params = list(
      hgnc_list = hgnc_list,
      mode_of_inheritance_list = mode_of_inheritance_list
    ),
    executor_fn = function(params) {
      # This runs in mirai daemon
      # The process_combine_ontology function handles:
      # - Downloading MONDO ontology
      # - Downloading OMIM genemap2
      # - Processing and combining data
      # - Saving results to CSV

      # Call the ontology processing function
      disease_ontology_set <- process_combine_ontology(
        hgnc_list = params$hgnc_list,
        mode_of_inheritance_list = params$mode_of_inheritance_list,
        max_file_age = 0, # Force regeneration
        output_path = "data/"
      )

      # Return summary
      list(
        status = "completed",
        rows_processed = nrow(disease_ontology_set),
        sources = c("MONDO", "OMIM"),
        output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
      )
    }
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "30") # Longer polling interval for ontology update

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 300, # Ontology update is slow (5+ minutes)
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

## -------------------------------------------------------------------##
## HGNC Data Update Submission
## -------------------------------------------------------------------##

#* Submit HGNC Data Update Job
#*
#* Submits an async job to download and update HGNC gene data.
#* Requires Administrator role.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @post /hgnc_update/submit
function(req, res) {
  require_role(req, res, "Administrator")

  # CRITICAL: Extract database config BEFORE mirai
  # Database connections cannot cross process boundaries, so the daemon
  # must create its own connection using the config values.
  db_config <- list(
    dbname   = dw$dbname,
    host     = dw$host,
    user     = dw$user,
    password = dw$password,
    port     = dw$port
  )

  # Check for duplicate running job
  # Use a stable identifier (operation name only) — db_config contains credentials
  # and should NOT be included in the hash or stored longer than necessary.
  dup_check <- check_duplicate_job("hgnc_update", list(operation = "hgnc_update"))
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "HGNC update job already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # Create async job for HGNC update pipeline
  # gnomAD enrichment now uses bulk TSV download (~10s), Ensembl/STRINGdb are the bottleneck
  result <- create_job(
    operation = "hgnc_update",
    params = list(db_config = db_config),
    timeout_ms = 1800000, # 30 minutes (bulk TSV approach makes gnomAD fast)
    executor_fn = function(params) {
      # This runs in mirai daemon
      # Create file-based progress reporter so main process can read progress
      progress <- create_progress_reporter(params$.__job_id__)
      job_id <- params$.__job_id__

      # --- Phase 1: Download and process HGNC data ---
      message(sprintf(
        "[%s] [job:%s] HGNC update: starting data download and processing...",
        Sys.time(), job_id
      ))

      hgnc_data <- tryCatch(
        {
          update_process_hgnc_data(progress_fn = progress)
        },
        error = function(e) {
          msg <- sprintf("HGNC pipeline failed during data processing: %s", conditionMessage(e))
          message(sprintf("[%s] [job:%s] %s", Sys.time(), job_id, msg))
          stop(msg)
        }
      )

      message(sprintf(
        "[%s] [job:%s] HGNC update: processed %d rows (%d columns), writing to database...",
        Sys.time(), job_id, nrow(hgnc_data), ncol(hgnc_data)
      ))

      # --- Phase 2: Write to database ---
      progress("db_write", "Writing to database...", current = 9, total = 9)

      conn <- tryCatch(
        {
          DBI::dbConnect(
            RMariaDB::MariaDB(),
            dbname   = params$db_config$dbname,
            host     = params$db_config$host,
            user     = params$db_config$user,
            password = params$db_config$password,
            port     = params$db_config$port
          )
        },
        error = function(e) {
          msg <- sprintf("Failed to connect to database: %s", conditionMessage(e))
          message(sprintf("[%s] [job:%s] %s", Sys.time(), job_id, msg))
          stop(msg)
        }
      )
      on.exit(DBI::dbDisconnect(conn), add = TRUE)

      # Reconcile tibble columns against DB schema to prevent mismatches
      # (e.g. HGNC upstream renames like rna_central_ids -> rna_central_id)
      db_cols <- DBI::dbListFields(conn, "non_alt_loci_set")
      tibble_cols <- colnames(hgnc_data)

      # Drop tibble columns that don't exist in the DB table
      extra_cols <- setdiff(tibble_cols, db_cols)
      if (length(extra_cols) > 0) {
        message(sprintf(
          "[%s] [job:%s] Dropping %d tibble columns not in DB: %s",
          Sys.time(), job_id, length(extra_cols),
          paste(extra_cols, collapse = ", ")
        ))
        hgnc_data <- hgnc_data[, setdiff(tibble_cols, extra_cols), drop = FALSE]
      }

      # Warn about DB columns missing from the tibble (will be NULL in DB)
      missing_cols <- setdiff(db_cols, colnames(hgnc_data))
      if (length(missing_cols) > 0) {
        message(sprintf(
          "[%s] [job:%s] DB columns not in tibble (will be NULL): %s",
          Sys.time(), job_id, paste(missing_cols, collapse = ", ")
        ))
      }

      # Atomic table replacement: DELETE + INSERT in a real transaction
      # NOTE: TRUNCATE is DDL and auto-commits in MySQL — it cannot be rolled back.
      # DELETE FROM is DML and participates in the transaction, so on failure the
      # entire operation rolls back and the table retains its previous data.
      tryCatch(
        {
          # Disable FK checks for this session; ensure they are re-enabled even on error
          DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")
          on.exit(tryCatch(DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1"),
            error = function(e) NULL
          ), add = TRUE)

          DBI::dbWithTransaction(conn, {
            DBI::dbExecute(conn, "DELETE FROM non_alt_loci_set")

            if (nrow(hgnc_data) > 0) {
              DBI::dbAppendTable(conn, "non_alt_loci_set", hgnc_data)
            }
          })

          DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1")
        },
        error = function(e) {
          msg <- sprintf(
            "Database write failed: %s. Tibble cols: [%s]. DB cols: [%s].",
            conditionMessage(e),
            paste(colnames(hgnc_data), collapse = ", "),
            paste(db_cols, collapse = ", ")
          )
          message(sprintf("[%s] [job:%s] %s", Sys.time(), job_id, msg))
          stop(msg)
        }
      )

      message(sprintf(
        "[%s] [job:%s] HGNC update: database write complete (%d rows)",
        Sys.time(), job_id, nrow(hgnc_data)
      ))

      # Return summary (not the full tibble — avoid memory overhead in job state)
      list(
        status = "completed",
        rows_processed = nrow(hgnc_data),
        columns_written = ncol(hgnc_data),
        columns_dropped = length(extra_cols),
        message = "HGNC data updated and written to database successfully"
      )
    }
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "60") # Long-running job: poll every minute

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 300, # ~5 min typical (Ensembl BioMart is the bottleneck)
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

## -------------------------------------------------------------------##
## Comparisons Data Update Submission
## -------------------------------------------------------------------##

#* Submit Comparisons Data Update Job
#*
#* Submits an async job to refresh the comparisons data from all external
#* NDD databases (Radboud, Gene2Phenotype, PanelApp, SFARI, Geisinger,
#* OMIM NDD, Orphanet).
#*
#* Requires Administrator role.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @post /comparisons_update/submit
function(req, res) {
  require_role(req, res, "Administrator")

  # CRITICAL: Extract database config BEFORE mirai
  # Database connections cannot cross process boundaries, so the daemon
  # must create its own connection using the config values.
  db_config <- list(
    dbname   = dw$dbname,
    host     = dw$host,
    user     = dw$user,
    password = dw$password,
    port     = dw$port
  )

  # Check for duplicate running job
  # Use a stable identifier (operation name only) — db_config contains credentials
  # and should NOT be included in the hash or stored longer than necessary.
  dup_check <- check_duplicate_job("comparisons_update", list(operation = "comparisons_update"))
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "Comparisons update job already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # Create async job for comparisons update
  # Downloads from 7+ sources can take 5-30 minutes depending on network
  result <- create_job(
    operation = "comparisons_update",
    params = list(db_config = db_config),
    timeout_ms = 1800000, # 30 minutes
    executor_fn = function(params) {
      # This runs in mirai daemon
      comparisons_update_async(params)
    }
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "30") # Long-running job: poll every 30 seconds

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 300, # ~5 min typical
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

## -------------------------------------------------------------------##
## Job History
## -------------------------------------------------------------------##

#* Get Job History
#*
#* Returns a list of recent jobs for admin review.
#* Requires Administrator role.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @get /history
function(req, res, limit = 20) {
  require_role(req, res, "Administrator")

  # Validate and constrain limit parameter
  limit <- as.integer(limit)
  if (is.na(limit) || limit < 1) {
    limit <- 20
  }
  if (limit > 100) {
    limit <- 100
  }

  # Get job history from job-manager
  jobs <- get_job_history(limit)

  # Return with metadata
  list(
    data = if (nrow(jobs) > 0) {
      # Convert data frame to list of lists for JSON serialization
      lapply(seq_len(nrow(jobs)), function(i) {
        list(
          job_id = jobs$job_id[i],
          operation = jobs$operation[i],
          status = jobs$status[i],
          submitted_at = jobs$submitted_at[i],
          completed_at = jobs$completed_at[i],
          duration_seconds = jobs$duration_seconds[i],
          error_message = jobs$error_message[i]
        )
      })
    } else {
      list()
    },
    meta = list(
      count = nrow(jobs),
      limit = limit
    )
  )
}

## -------------------------------------------------------------------##
## Job Status Polling
## -------------------------------------------------------------------##

#* Get Job Status
#*
#* Poll job status and retrieve results when complete.
#* Returns Retry-After header for running jobs.
#*
#* @tag jobs
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @get /<job_id>/status
function(job_id, res) {
  status <- get_job_status(job_id)

  if (identical(status$error, "JOB_NOT_FOUND")) {
    res$status <- 404
    return(list(
      error = "JOB_NOT_FOUND",
      message = paste0("Job '", job_id, "' not found or expired")
    ))
  }

  # Set Retry-After for running jobs
  if (status$status %in% c("pending", "running")) {
    res$setHeader("Retry-After", as.character(status$retry_after %||% 5))
  }

  res$status <- 200
  return(status)
}
