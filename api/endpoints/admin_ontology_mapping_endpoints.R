## -------------------------------------------------------------------##
# api/endpoints/admin_ontology_mapping_endpoints.R
#
# Administrator-only HTTP triggers for the durable disease cross-ontology mapping
# refresh (WP-C). Mounted at /api/admin/ontology, so:
#   POST /api/admin/ontology/mappings/refresh  (submit a refresh job)
#   GET  /api/admin/ontology/mappings/status   (latest provenance state)
#
# Both submit paths (this endpoint, the startup bootstrap, the cron enqueue
# script, and the C7 re-trigger) share one function,
# service_disease_ontology_mapping_submit_refresh(), so submission logic is not
# duplicated. Mounted via mount_endpoint() (RFC 9457 error handling) and BEFORE
# /api/admin so the more-specific prefix wins.
## -------------------------------------------------------------------##

#* Submit a disease ontology mapping refresh job (Administrator only)
#*
#* Idempotently submits a `disease_ontology_mapping_refresh` job so the worker
#* re-downloads MONDO OBO + SSSOM and rebuilds the cross-ontology index and the
#* derived `disease_ontology_mapping` rows. By default a successful prior build
#* short-circuits; pass `force=true` to force a rebuild. Re-submitting a
#* queued/running refresh returns the existing job (dedup).
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @param force:bool Optional; rebuild even when a successful build exists. Default false.
#*
#* @post /mappings/refresh
function(req, res, force = FALSE) {
  require_role(req, res, "Administrator")

  force_flag <- isTRUE(force) ||
    identical(tolower(as.character(force)[[1]]), "true") ||
    identical(as.character(force)[[1]], "1")

  outcome <- service_disease_ontology_mapping_submit_refresh(force = force_flag)

  res$status <- 202L
  outcome
}

#* Disease ontology mapping refresh status (Administrator only)
#*
#* Returns the latest `disease_ontology_mapping_meta` rows (status, counts,
#* timings) so an operator can watch a rebuild progress without DB access.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @get /mappings/status
function(req, res) {
  require_role(req, res, "Administrator")
  service_disease_ontology_mapping_status()
}
