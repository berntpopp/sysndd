# services/mcp-gts.R
#
# GTS v1 (Genetics Tool Server) wire frame for the read-only SysNDD sidecar:
# server identity, the response envelope v1.2 (success/result/_meta), the closed
# error vocabulary, input-schema examples, GET /health and the
# MCP-Protocol-Version check. Tool payloads stay unchanged; they travel under
# `result` of the envelope.

MCP_SERVER_NAME <- "sysndd-mcp"
MCP_GTS_SOURCE <- "sysndd"
MCP_GTS_ERROR_CODES <- c(
  "invalid_input", "not_found", "ambiguous_query",
  "upstream_unavailable", "rate_limited", "internal"
)

# The server version is the SysNDD release version: one source for API, app and MCP.
mcp_server_version <- function(path = "version_spec.json") {
  cached <- getOption("sysndd.mcp_server_version")
  if (!is.null(cached)) {
    return(cached)
  }
  version <- as.character(jsonlite::fromJSON(path)$version)
  options(sysndd.mcp_server_version = version)
  version
}

# Legacy SysNDD codes mapped onto the closed GTS vocabulary (GTS-CORE-ERR-02).
mcp_gts_error_code <- function(code) {
  code <- as.character(code %||% "")[1]
  if (code %in% MCP_GTS_ERROR_CODES) {
    return(code)
  }
  switch(code,
    unsupported_parameter = "invalid_input",
    snapshot_missing = "upstream_unavailable",
    temporarily_unavailable = "upstream_unavailable",
    "internal"
  )
}

mcp_gts_request_id <- function() {
  paste(sprintf("%02x", sample.int(256L, 16L, replace = TRUE) - 1L), collapse = "")
}

mcp_gts_utc_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

mcp_gts_drop_null <- function(x) x[!vapply(x, is.null, logical(1))]

# Wrap one legacy SysNDD payload in the GeneFoundry response envelope v1.2.
mcp_gts_envelope <- function(payload, is_error = FALSE, version = mcp_server_version()) {
  if (!is.list(payload)) payload <- list(value = payload)
  meta <- list(
    source = MCP_GTS_SOURCE,
    request_id = mcp_gts_request_id(),
    elapsed_ms = as.numeric(payload$meta$elapsed_ms %||% 0)
  )
  if (isTRUE(is_error)) {
    err <- payload$error %||% list()
    code <- mcp_gts_error_code(err$code)
    env <- list(
      success = FALSE,
      error_code = code,
      message = as.character(err$message %||% "MCP tool failed")[1],
      retryable = code %in% c("upstream_unavailable", "rate_limited")
    )
    if (identical(code, "invalid_input")) {
      # Only a well-formed parameter name is echoed (GTS-CORE-TXT-04).
      field <- as.character(err$argument %||% "")[1]
      if (grepl("^[A-Za-z_][A-Za-z0-9_]{0,63}$", field)) env$field <- field
      allowed <- err$allowed_values %||% err$expected_arguments
      if (length(allowed) > 0L) env$allowed_values <- as.list(allowed)
    }
    return(mcp_gts_drop_null(c(env, list(
      `_meta` = meta,
      schema_version = payload$schema_version,
      error = err
    ))))
  }
  meta$data_version <- version
  meta$retrieved_at <- mcp_gts_utc_now()
  mcp_gts_drop_null(list(
    success = TRUE,
    result = payload,
    `_meta` = meta,
    unsafe_for_clinical_use = TRUE,
    schema_version = payload$schema_version
  ))
}

# outputSchema of every tool: the envelope, with the legacy payload under `result`.
mcp_gts_output_schema <- function(result_schema, description) {
  result_schema$required <- NULL
  # Kept terse: every tool repeats it, and the tool surface has a token budget.
  list(
    type = "object",
    description = description,
    properties = list(
      success = list(type = "boolean"),
      result = result_schema,
      `_meta` = list(type = "object"),
      unsafe_for_clinical_use = list(type = "boolean"),
      error_code = list(type = "string")
    ),
    required = list("success", "_meta")
  )
}

# `examples` for every required and array parameter (GTS-CORE-SCH-02); the
# first example of each required parameter is a valid call.
MCP_GTS_INPUT_EXAMPLES <- list(
  search_sysndd = list(query = list("PNKP"), types = list(list("gene"))),
  get_gene_context = list(gene = list("PNKP", "HGNC:9154")),
  get_genes_context = list(genes = list(list("PNKP", "MECP2"))),
  get_entity_context = list(entity_id = list(451L)),
  get_entities_context = list(entity_ids = list(list(451L, 1317L))),
  list_gene_entities = list(gene = list("PNKP")),
  get_publication_context = list(pmid = list("PMID:37130971")),
  get_publications_context = list(pmids = list(list("PMID:37130971", "30842225"))),
  find_entities_by_phenotype = list(phenotype = list("HP:0000252")),
  find_entities_by_disease = list(disease = list("Rett syndrome")),
  get_gene_research_context = list(gene = list("PNKP"), sections = list(list("curated", "nddscore"))),
  get_nddscore_context = list(hpo_terms = list(list("HP:0000252"))),
  get_curation_comparison_context = list(sources = list(list("gene2phenotype"))),
  get_phenotype_analysis_context = list(mode = list("clusters"))
)

mcp_gts_add_examples <- function(item) {
  examples <- MCP_GTS_INPUT_EXAMPLES[[item$name %||% ""]] %||% list()
  for (prop in intersect(names(examples), names(item$inputSchema$properties))) {
    item$inputSchema$properties[[prop]]$examples <- examples[[prop]]
  }
  item
}

mcp_gts_health_response <- function(version) {
  list(
    status = 200L,
    headers = list("Content-Type" = "application/json"),
    body = jsonlite::toJSON(
      list(status = "ok", name = MCP_SERVER_NAME, version = version, transport = "streamable-http"),
      auto_unbox = TRUE
    )
  )
}

# GET /health, and 400 for an unsupported MCP-Protocol-Version header (GTS-CORE-TRN-03).
mcp_patch_mcptools_http <- function(version = mcp_server_version()) {
  if (!requireNamespace("mcptools", quietly = TRUE)) {
    return(FALSE)
  }
  ns <- asNamespace("mcptools")
  original <- getOption("sysndd.mcptools.handle_http_request_original")
  if (is.null(original)) {
    original <- base::get("handle_http_request", envir = ns)
    options(sysndd.mcptools.handle_http_request_original = list(original))
  } else {
    original <- original[[1]]
  }
  supported <- base::get("supported_protocol_versions", envir = ns)
  patched <- function(req) {
    if (identical(req$REQUEST_METHOD, "GET") && identical(req$PATH_INFO, "/health")) {
      return(mcp_gts_health_response(version))
    }
    header <- req$HTTP_MCP_PROTOCOL_VERSION
    if (!is.null(header) && !header %in% supported) {
      return(list(
        status = 400L,
        headers = list("Content-Type" = "application/json"),
        body = jsonlite::toJSON(list(error = "Unsupported MCP-Protocol-Version"), auto_unbox = TRUE)
      ))
    }
    original(req)
  }
  environment(patched) <- environment()
  assignInNamespace("handle_http_request", patched, ns = "mcptools")
  # The transport serializes structuredContent; keep JSON null as null so it
  # equals the content[] text mirror (GTS-CORE-ENV-01).
  null_safe_to_json <- function(x, ...) jsonlite::toJSON(x, ..., auto_unbox = TRUE, null = "null", na = "null")
  assignInNamespace("to_json", null_safe_to_json, ns = "mcptools")
  TRUE
}
