.async_job_not_implemented_handler <- function(job_type) {
  force(job_type)

  function(job, payload, state, worker_config) {
    stop(
      sprintf("Async job handler '%s' is not implemented in the durable worker runtime yet", job_type),
      call. = FALSE
    )
  }
}

.async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
  invisible(result)
}

async_job_handler_registry <- list(
  clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_not_implemented_handler("clustering"),
    after_success = .async_job_after_success_noop
  ),
  phenotype_clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_not_implemented_handler("phenotype_clustering"),
    after_success = .async_job_after_success_noop
  ),
  ontology_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_not_implemented_handler("ontology_update")
  ),
  hgnc_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_not_implemented_handler("hgnc_update")
  ),
  comparisons_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_not_implemented_handler("comparisons_update")
  ),
  pubtator_update = list(
    cancel_mode = "best_effort",
    run = .async_job_not_implemented_handler("pubtator_update")
  ),
  llm_generation = list(
    cancel_mode = "best_effort",
    run = .async_job_not_implemented_handler("llm_generation")
  ),
  backup_create = list(
    cancel_mode = "non_interruptible",
    run = .async_job_not_implemented_handler("backup_create")
  ),
  backup_restore = list(
    cancel_mode = "non_interruptible",
    run = .async_job_not_implemented_handler("backup_restore")
  ),
  omim_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_not_implemented_handler("omim_update")
  ),
  force_apply_ontology = list(
    cancel_mode = "non_interruptible",
    run = .async_job_not_implemented_handler("force_apply_ontology")
  ),
  publication_refresh = list(
    cancel_mode = "best_effort",
    run = .async_job_not_implemented_handler("publication_refresh")
  )
)

#' Resolve a durable async job handler definition
#'
#' @param job_type Character async job type.
#' @param registry Named handler registry.
#'
#' @return Registry entry with run/cancel metadata.
#' @export
async_job_get_handler <- function(job_type, registry = async_job_handler_registry) {
  entry <- registry[[job_type]]

  if (is.null(entry)) {
    stop(sprintf("No durable async job handler registered for '%s'", job_type), call. = FALSE)
  }

  if (!is.function(entry$run)) {
    stop(sprintf("Handler registry entry for '%s' is missing a callable run function", job_type), call. = FALSE)
  }

  entry
}
