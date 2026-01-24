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
#   - gen_string_clust_obj_mem, gen_mca_clust_obj_mem (memoized analysis functions)

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

  # Check for duplicate job
  dup_check <- check_duplicate_job("clustering", list(genes = genes_list))
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

  # Create async job
  result <- create_job(
    operation = "clustering",
    params = list(genes = genes_list),
    executor_fn = function(params) {
      # This runs in mirai daemon - use memoized version
      gen_string_clust_obj_mem(params$genes)
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
  ndd_entity_view_tbl <- pool %>% tbl("ndd_entity_view") %>% collect()
  ndd_entity_review_tbl <- pool %>% tbl("ndd_entity_review") %>% collect() %>%
    filter(is_primary == 1) %>% select(review_id)
  ndd_review_phenotype_connect_tbl <- pool %>%
    tbl("ndd_review_phenotype_connect") %>% collect()
  modifier_list_tbl <- pool %>% tbl("modifier_list") %>% collect()
  phenotype_list_tbl <- pool %>% tbl("phenotype_list") %>% collect()

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

  # Create job with pre-fetched data
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
        select(entity_id, hpo_mode_of_inheritance_term_name, phenotype_id,
               HPO_term, hgnc_id) %>%
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

      phenotype_clusters <- gen_mca_clust_obj_mem(sysndd_db_phenotypes_wider_df)

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
  # Check authentication - require Administrator
  if (is.null(req$user_id)) {
    res$status <- 401
    return(list(error = "UNAUTHORIZED", message = "Authentication required"))
  }

  if (req$user_role != "Administrator") {
    res$status <- 403
    return(list(error = "FORBIDDEN", message = "Administrator role required"))
  }

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
        max_file_age = 0,  # Force regeneration
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
  res$setHeader("Retry-After", "30")  # Longer polling interval for ontology update

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 300,  # Ontology update is slow (5+ minutes)
    status_url = paste0("/api/jobs/", result$job_id, "/status")
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
#* @serializer json list(na="string")
#* @get /<job_id>/status
function(job_id, res) {
  status <- get_job_status(job_id)

  if (!is.null(status$error) && status$error == "JOB_NOT_FOUND") {
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
