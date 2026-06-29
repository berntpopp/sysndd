# api/functions/async-job-omim-apply.R
# OMIM-apply helpers extracted from async-job-handlers.R (#470).

.async_job_omim_db_write <- function(disease_ontology_set_update, safeguard, db_config) {
  sysndd_db <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password,
    server = db_config$server,
    host = db_config$host,
    port = db_config$port
  )
  on.exit(DBI::dbDisconnect(sysndd_db), add = TRUE)

  refresh_result <- refresh_disease_ontology_set(
    conn = sysndd_db,
    disease_ontology_set_update = disease_ontology_set_update,
    auto_fixes = safeguard$auto_fixes
  )

  # Correction #2: the disease set changed, so rebuild the cross-ontology
  # mappings (best-effort; never fails the ontology refresh).
  .async_job_chain_ontology_mapping_refresh()

  refresh_result$auto_fixes_applied
}

#' Best-effort additive apply of brand-new OMIM terms on a blocked update (#470).
#'
#' Inserts only entity-unreferenced new terms (zero-risk) even though critical
#' changes gate the full apply. Never throws — an insert failure is logged and
#' reported as `additive_applied = 0` with `additive_error` set, so a blocked
#' result is never turned into a job failure.
#' @return list(applied = <integer>, error = <character or NULL>)
apply_additive_terms_on_block <- function(payload, disease_ontology_set_update) {
  additive_applied <- 0L
  additive_error <- NULL
  tryCatch(
    {
      additive_rows <- extract_additive_ontology_terms(
        disease_ontology_set_update,
        payload$disease_ontology_set_current
      )
      if (nrow(additive_rows) > 0) {
        add_conn <- DBI::dbConnect(
          RMariaDB::MariaDB(),
          dbname = payload$db_config$dbname,
          user = payload$db_config$user,
          password = payload$db_config$password,
          server = payload$db_config$server,
          host = payload$db_config$host,
          port = payload$db_config$port
        )
        on.exit(tryCatch(DBI::dbDisconnect(add_conn), error = function(e) NULL), add = TRUE)
        additive_applied <- apply_additive_ontology_terms(add_conn, additive_rows)
        if (additive_applied > 0) {
          .async_job_chain_ontology_mapping_refresh()
        }
      }
    },
    error = function(e) {
      additive_error <<- conditionMessage(e)
      message(sprintf("[omim-additive] additive apply failed (non-fatal): %s", additive_error))
    }
  )
  list(applied = additive_applied, error = additive_error)
}
