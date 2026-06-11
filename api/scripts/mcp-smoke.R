#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

required <- c("httr2", "jsonlite")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Missing required packages for MCP smoke: ", paste(missing, collapse = ", "))
}

endpoint <- Sys.getenv("MCP_URL", "http://127.0.0.1:8787")
token <- Sys.getenv("MCP_BEARER_TOKEN", "")

rpc <- function(method, params = NULL, id = 1L) {
  body <- list(jsonrpc = "2.0", id = id, method = method)
  if (!is.null(params)) body$params <- params

  req <- httr2::request(endpoint) |>
    httr2::req_headers(
      `Content-Type` = "application/json",
      `MCP-Protocol-Version` = "2025-11-25"
    ) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_timeout(5)

  if (nzchar(token)) {
    req <- httr2::req_headers(req, Authorization = paste("Bearer", token))
  }

  resp <- httr2::req_perform(req)
  jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)
}

init <- rpc("initialize", list(
  protocolVersion = "2025-11-25",
  capabilities = list(),
  clientInfo = list(name = "sysndd-mcp-smoke", version = "0.1.0")
), 1L)
if (is.null(init$result)) stop("MCP initialize failed")
if (!grepl("SysNDD", init$result$instructions %||% "", fixed = TRUE)) {
  stop("MCP initialize did not return SysNDD-specific instructions")
}
if (!grepl("research", init$result$instructions %||% "", ignore.case = TRUE)) {
  stop("MCP initialize did not return research-use guidance")
}
if (is.null(init$result$capabilities$resources)) {
  stop("MCP initialize did not advertise resources capability")
}

listed <- rpc("tools/list", id = 2L)
tools <- listed$result$tools %||% list()
tool_names <- vapply(tools, function(x) x$name %||% "", character(1))
required_tools <- c(
  "search_sysndd",
  "get_gene_context",
  "get_genes_context",
  "get_entity_context",
  "get_entities_context",
  "get_publication_context",
  "get_publications_context",
  "get_sysndd_capabilities",
  "get_sysndd_analysis_catalog",
  "get_gene_research_context",
  "get_nddscore_context",
  "get_curation_comparison_context",
  "get_phenotype_analysis_context",
  "get_gene_network_context"
)
missing_tools <- setdiff(required_tools, tool_names)
if (length(missing_tools) > 0L) {
  stop("MCP tools/list missing required tools: ", paste(missing_tools, collapse = ", "))
}

for (tool in tools) {
  if (!isTRUE(tool$annotations$readOnlyHint)) {
    stop("MCP tool missing readOnlyHint annotation: ", tool$name %||% "<unknown>")
  }
  if (is.null(tool$outputSchema)) {
    stop("MCP tool missing outputSchema: ", tool$name %||% "<unknown>")
  }
}

tool_by_name <- function(name) {
  matches <- tools[vapply(tools, function(tool) identical(tool$name, name), logical(1))]
  if (length(matches) != 1L) stop("Could not find tool metadata for ", name)
  matches[[1]]
}

search_schema <- tool_by_name("search_sysndd")$inputSchema
if (!nzchar(search_schema$properties$types$description %||% "")) {
  stop("search_sysndd types array description is blank")
}
pub_batch_schema <- tool_by_name("get_publications_context")$inputSchema
if (!nzchar(pub_batch_schema$properties$pmids$description %||% "")) {
  stop("get_publications_context pmids array description is blank")
}
entity_batch_schema <- tool_by_name("get_entities_context")$inputSchema
if (!nzchar(entity_batch_schema$properties$entity_ids$description %||% "")) {
  stop("get_entities_context entity_ids array description is blank")
}
gene_tool <- tool_by_name("get_gene_context")
if (!grepl("Example:", gene_tool$description %||% "", fixed = TRUE)) {
  stop("get_gene_context description is missing an example")
}
if (!is.null(gene_tool$inputSchema$properties$query) || !is.null(gene_tool$inputSchema$properties$symbol)) {
  stop("get_gene_context schema exposes deprecated gene aliases")
}
if (is.null(gene_tool$inputSchema$properties$response_mode)) {
  stop("get_gene_context schema is missing response_mode")
}
if (is.null(gene_tool$inputSchema$properties$synopsis_mode)) {
  stop("get_gene_context schema is missing synopsis_mode")
}
if (is.null(gene_tool$inputSchema$properties$expand)) {
  stop("get_gene_context schema is missing expand")
}
if (!grepl("default true", gene_tool$inputSchema$properties$include_entities$description %||% "", ignore.case = TRUE)) {
  stop("get_gene_context include_entities description is missing default")
}
gene_batch_tool <- tool_by_name("get_genes_context")
if (is.null(gene_batch_tool$inputSchema$properties$genes)) {
  stop("get_genes_context schema is missing genes")
}
entity_batch_tool <- tool_by_name("get_entities_context")
if (is.null(entity_batch_tool$inputSchema$properties$dedupe_publications)) {
  stop("get_entities_context schema is missing dedupe_publications")
}
pub_tool <- tool_by_name("get_publications_context")
if (is.null(pub_tool$inputSchema$properties$abstract_mode)) {
  stop("get_publications_context schema is missing abstract_mode")
}
gene_research_tool <- tool_by_name("get_gene_research_context")
for (property in c("response_mode", "max_response_chars", "include_diagnostics", "dry_run")) {
  if (is.null(gene_research_tool$inputSchema$properties[[property]])) {
    stop("get_gene_research_context schema is missing ", property)
  }
}
nddscore_tool <- tool_by_name("get_nddscore_context")
for (property in c("response_mode", "max_response_chars", "include_diagnostics", "dry_run")) {
  if (is.null(nddscore_tool$inputSchema$properties[[property]])) {
    stop("get_nddscore_context schema is missing ", property)
  }
}
phenotype_analysis_tool <- tool_by_name("get_phenotype_analysis_context")
for (property in c("drop_diagonal", "triangle_only")) {
  if (is.null(phenotype_analysis_tool$inputSchema$properties[[property]])) {
    stop("get_phenotype_analysis_context schema is missing ", property)
  }
}

resources <- rpc("resources/list", id = 3L)
if (!is.null(resources$error)) stop("MCP resources/list failed: ", resources$error$message)
resource_uris <- vapply(resources$result$resources %||% list(), function(x) x$uri %||% "", character(1))
if (!"sysndd://schema/tool-guide" %in% resource_uris) {
  stop("MCP resources/list missing sysndd://schema/tool-guide")
}
tool_guide <- rpc("resources/read", list(uri = "sysndd://schema/tool-guide"), id = 4L)
if (!is.null(tool_guide$error)) stop("MCP resources/read failed: ", tool_guide$error$message)
if (!grepl("tool-guide", tool_guide$result$contents[[1]]$text %||% "", fixed = TRUE)) {
  stop("MCP resources/read returned unexpected tool-guide text")
}
overview <- rpc("resources/read", list(uri = "sysndd://schema/overview"), id = 41L)
if (!is.null(overview$error)) stop("MCP overview resource read failed: ", overview$error$message)
overview_text <- overview$result$contents[[1]]$text %||% ""
tool_guide_text <- tool_guide$result$contents[[1]]$text %||% ""
if (identical(overview_text, tool_guide_text) || grepl("schema/tool-guide", overview_text, fixed = TRUE)) {
  stop("MCP schema resources are not distinct")
}

prompts <- rpc("prompts/list", id = 42L)
if (!is.null(prompts$error)) stop("MCP prompts/list failed: ", prompts$error$message)
prompt_names <- vapply(prompts$result$prompts %||% list(), function(x) x$name %||% "", character(1))
prompts_enabled <- tolower(Sys.getenv("MCP_ENABLE_PROMPTS", "false")) %in% c("1", "true", "yes", "on")
if (prompts_enabled) {
  if (!"sysndd_gene_evidence_summary" %in% prompt_names) {
    stop("MCP prompts/list missing sysndd_gene_evidence_summary")
  }
  prompt <- rpc("prompts/get", list(name = "sysndd_gene_evidence_summary", arguments = list(gene = "NAA10")), id = 43L)
  if (!is.null(prompt$error)) stop("MCP prompts/get failed: ", prompt$error$message)
  if (!grepl("recommended_citation", prompt$result$messages[[1]]$content$text %||% "", fixed = TRUE)) {
    stop("MCP prompt did not include citation guidance")
  }
} else if (length(prompt_names) > 0L) {
  stop("MCP prompts are disabled by default but prompts/list returned prompts")
}

call_tool <- function(name, arguments, id) {
  rpc("tools/call", list(name = name, arguments = arguments), id = id)
}

capabilities <- call_tool("get_sysndd_capabilities", list(), id = 44L)
if (!is.null(capabilities$error)) stop("Capabilities returned JSON-RPC error: ", capabilities$error$message)
if (is.null(capabilities$result$structuredContent)) {
  stop("Capabilities response missing structuredContent despite outputSchema")
}
capabilities_payload <- jsonlite::fromJSON(capabilities$result$content[[1]]$text, simplifyVector = FALSE)
if (!"compact" %in% capabilities_payload$payload_modes$response_mode) {
  stop("Capabilities payload missing response_mode guidance")
}
if (!identical(capabilities_payload$limits$get_entities_context$max_entity_ids, 20L)) {
  stop("Capabilities payload missing get_entities_context max")
}
if (is.null(capabilities_payload$analysis_data_classes$ml_prediction) ||
  !isTRUE(capabilities_payload$safety$llm_generation_disabled)) {
  stop("Capabilities payload missing analysis data-class guardrails")
}

search_gene <- call_tool("search_sysndd", list(query = "PNKP", types = list("gene"), limit = 1L), id = 45L)
if (!is.null(search_gene$error)) stop("search_sysndd returned JSON-RPC error: ", search_gene$error$message)
search_payload <- jsonlite::fromJSON(search_gene$result$content[[1]]$text, simplifyVector = FALSE)
matches <- search_payload$matches %||% list()
if (length(matches) == 0L) {
  stop("search_sysndd did not find the approved public smoke gene PNKP")
}
gene <- matches[[1]]$id %||% matches[[1]]$label %||% "PNKP"

nmda_search <- call_tool("search_sysndd", list(query = "NMDA receptor", limit = 5L), id = 451L)
if (!is.null(nmda_search$error)) stop("NMDA receptor search returned JSON-RPC error: ", nmda_search$error$message)
nmda_payload <- jsonlite::fromJSON(nmda_search$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(nmda_payload$meta$query_tokens, list("NMDA", "RECEPTOR"))) {
  stop("NMDA receptor search did not report expected query tokens")
}
if (length(nmda_payload$matches %||% list()) > 1L) {
  scores <- vapply(nmda_payload$matches, function(x) as.numeric(x$score %||% 0), numeric(1))
  if (is.unsorted(rev(scores))) {
    stop("NMDA receptor search scores are not sorted descending")
  }
}

epilepsy_search <- call_tool("search_sysndd", list(query = "epilepsy aphasia", limit = 5L), id = 452L)
if (!is.null(epilepsy_search$error)) stop("epilepsy aphasia search returned JSON-RPC error: ", epilepsy_search$error$message)
epilepsy_payload <- jsonlite::fromJSON(epilepsy_search$result$content[[1]]$text, simplifyVector = FALSE)
if (is.null(epilepsy_payload$meta$query_tokens) || is.null(epilepsy_payload$meta$searched_types)) {
  stop("epilepsy aphasia search did not report diagnostics")
}
epilepsy_matches <- epilepsy_payload$matches %||% list()
if (length(epilepsy_matches) > 1L) {
  scores <- vapply(epilepsy_matches, function(x) as.numeric(x$score %||% 0), numeric(1))
  if (is.unsorted(rev(scores))) {
    stop("epilepsy aphasia search scores are not sorted descending")
  }
}
if (length(epilepsy_matches) == 0L && is.null(epilepsy_payload$meta$zero_result_guidance)) {
  stop("epilepsy aphasia search did not return matches or zero-result guidance")
}

catalog <- call_tool("get_sysndd_analysis_catalog", list(), id = 46L)
if (!is.null(catalog$error)) stop("Analysis catalog returned JSON-RPC error: ", catalog$error$message)
catalog_payload <- jsonlite::fromJSON(catalog$result$content[[1]]$text, simplifyVector = FALSE)
analysis_ids <- vapply(catalog_payload$analyses %||% list(), function(x) x$analysis_id %||% "", character(1))
if (!"gene_research_context" %in% analysis_ids || !"nddscore" %in% analysis_ids) {
  stop("Analysis catalog missing required analysis IDs")
}

gene_research_dry <- call_tool(
  "get_gene_research_context",
  list(gene = gene, dry_run = TRUE, include_diagnostics = TRUE),
  id = 47L
)
if (!is.null(gene_research_dry$error)) stop("Gene research dry-run returned JSON-RPC error: ", gene_research_dry$error$message)
dry_payload <- jsonlite::fromJSON(gene_research_dry$result$content[[1]]$text, simplifyVector = FALSE)
if (is.null(dry_payload$section_status) || is.null(dry_payload$budget)) {
  stop("Gene research dry-run missing section_status or budget")
}

gene_research <- call_tool(
  "get_gene_research_context",
  list(gene = gene, sections = list("curated", "nddscore"), response_mode = "compact"),
  id = 48L
)
if (!is.null(gene_research$error)) stop("Gene research context returned JSON-RPC error: ", gene_research$error$message)
research_payload <- jsonlite::fromJSON(gene_research$result$content[[1]]$text, simplifyVector = FALSE)
if (is.null(research_payload$sections$curated) || is.null(research_payload$section_status$nddscore)) {
  stop("Gene research context missing curated section or nddscore status")
}

nddscore <- call_tool("get_nddscore_context", list(gene = gene), id = 49L)
if (!is.null(nddscore$error)) stop("NDDScore returned JSON-RPC error: ", nddscore$error$message)
if (!isTRUE(is.null(nddscore$result$isError) || nddscore$result$isError %in% c(TRUE, FALSE))) {
  stop("NDDScore did not return a valid tool-result error flag")
}
if (!isTRUE(nddscore$result$isError)) {
  nddscore_payload <- jsonlite::fromJSON(nddscore$result$content[[1]]$text, simplifyVector = FALSE)
  if (!identical(nddscore_payload$data_class, "ml_prediction") || !isTRUE(nddscore_payload$not_evidence_tier)) {
    stop("NDDScore payload missing ML prediction evidence-boundary labels")
  }
}

bad_mode <- call_tool("get_phenotype_analysis_context", list(mode = "raw_matrix"), id = 50L)
if (!is.null(bad_mode$error)) stop("Invalid phenotype mode returned JSON-RPC error: ", bad_mode$error$message)
if (!isTRUE(bad_mode$result$isError)) stop("Invalid phenotype mode did not return a tool error result")
bad_mode_payload <- jsonlite::fromJSON(bad_mode$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(bad_mode_payload$error$code, "invalid_input")) {
  stop("Invalid phenotype mode did not return invalid_input")
}

phenotype_corr <- call_tool(
  "get_phenotype_analysis_context",
  list(mode = "correlations", drop_diagonal = TRUE, triangle_only = TRUE, dry_run = TRUE),
  id = 501L
)
if (!is.null(phenotype_corr$error)) stop("Phenotype correlation dry-run returned JSON-RPC error: ", phenotype_corr$error$message)
phenotype_corr_payload <- jsonlite::fromJSON(phenotype_corr$result$content[[1]]$text, simplifyVector = FALSE)
if (isTRUE(phenotype_corr$result$isError)) {
  if (!identical(phenotype_corr_payload$error$code, "snapshot_missing")) {
    stop("Phenotype correlation dry-run returned unexpected error code")
  }
} else if (!isTRUE(phenotype_corr_payload$meta$drop_diagonal) || !isTRUE(phenotype_corr_payload$meta$triangle_only)) {
  stop("Phenotype correlation dry-run did not echo drop_diagonal/triangle_only")
}

network_dry <- call_tool(
  "get_gene_network_context",
  list(gene = gene, dry_run = TRUE, response_mode = "diagnostics"),
  id = 502L
)
if (!is.null(network_dry$error)) stop("Gene network diagnostics returned JSON-RPC error: ", network_dry$error$message)
network_dry_payload <- jsonlite::fromJSON(network_dry$result$content[[1]]$text, simplifyVector = FALSE)
if (isTRUE(network_dry$result$isError)) {
  if (!identical(network_dry_payload$error$code, "snapshot_missing")) {
    stop("Gene network diagnostics returned unexpected tool error")
  }
} else if (!network_dry_payload$section_status %in% c("available", "snapshot_missing")) {
  stop("Gene network diagnostics did not report available or snapshot_missing")
}

unsupported_network <- call_tool(
  "get_gene_network_context",
  list(cluster_type = "clusters", min_confidence = 700L, max_edges = 100L),
  id = 503L
)
if (!is.null(unsupported_network$error)) stop("Unsupported network parameter returned JSON-RPC error: ", unsupported_network$error$message)
if (!isTRUE(unsupported_network$result$isError)) stop("Unsupported network parameter did not return a tool error result")
unsupported_network_payload <- jsonlite::fromJSON(unsupported_network$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(unsupported_network_payload$error$code, "unsupported_parameter")) {
  stop("Unsupported network parameter did not return unsupported_parameter")
}

malformed_pmid <- call_tool("get_publication_context", list(pmid = "notapmid"), id = 5L)
if (!is.null(malformed_pmid$error)) stop("Malformed PMID returned JSON-RPC error: ", malformed_pmid$error$message)
if (!isTRUE(malformed_pmid$result$isError)) stop("Malformed PMID did not return a tool error result")
pmid_payload <- jsonlite::fromJSON(malformed_pmid$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(pmid_payload$error$code, "invalid_input") || !identical(pmid_payload$error$argument, "pmid")) {
  stop("Malformed PMID did not return invalid_input for pmid")
}

bad_category <- call_tool(
  "find_entities_by_phenotype",
  list(phenotype = "HP:0001250", category = "BogusCategory"),
  id = 6L
)
if (!is.null(bad_category$error)) stop("Invalid phenotype category returned JSON-RPC error: ", bad_category$error$message)
if (!isTRUE(bad_category$result$isError)) stop("Invalid phenotype category did not return a tool error result")
category_payload <- jsonlite::fromJSON(bad_category$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(category_payload$error$code, "invalid_input") || !identical(category_payload$error$argument, "category")) {
  stop("Invalid phenotype category did not return invalid_input for category")
}

# issue #353: find_entities_by_* must echo the requested term + resolution flag even
# on zero results so callers distinguish an unmatched term from a valid empty result.
zero_disease <- call_tool(
  "find_entities_by_disease",
  list(disease = "zzzz nonexistent disorder zzzz", limit = 1L),
  id = 61L
)
if (!is.null(zero_disease$error)) stop("zero-result disease search returned JSON-RPC error: ", zero_disease$error$message)
if (isTRUE(zero_disease$result$isError)) stop("zero-result disease search returned an unexpected tool error")
zero_disease_payload <- jsonlite::fromJSON(zero_disease$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(zero_disease_payload$disease, "zzzz nonexistent disorder zzzz") ||
  !identical(zero_disease_payload$meta$query_echo, "zzzz nonexistent disorder zzzz")) {
  stop("zero-result disease search did not echo the requested term")
}
if (!identical(zero_disease_payload$meta$query_resolved, FALSE)) {
  stop("zero-result disease search did not report query_resolved = false")
}

zero_phenotype <- call_tool(
  "find_entities_by_phenotype",
  list(phenotype = "HP:0000000", limit = 1L),
  id = 62L
)
if (!is.null(zero_phenotype$error)) stop("zero-result phenotype search returned JSON-RPC error: ", zero_phenotype$error$message)
if (!isTRUE(zero_phenotype$result$isError)) {
  zero_phenotype_payload <- jsonlite::fromJSON(zero_phenotype$result$content[[1]]$text, simplifyVector = FALSE)
  if (!identical(zero_phenotype_payload$meta$query_echo, "HP:0000000")) {
    stop("zero-result phenotype search did not echo the requested term")
  }
}

symbol_alias <- call_tool("get_gene_context", list(symbol = "NAA10", entity_limit = 1L), id = 7L)
if (!is.null(symbol_alias$error)) stop("symbol alias returned JSON-RPC error: ", symbol_alias$error$message)
if (!isTRUE(symbol_alias$result$isError)) stop("symbol alias did not return a tool error result")
symbol_payload <- jsonlite::fromJSON(symbol_alias$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(symbol_payload$error$code, "invalid_input") || !identical(symbol_payload$error$argument, "symbol")) {
  stop("symbol alias did not return invalid_input for symbol")
}

query_alias <- call_tool("get_gene_context", list(query = "NAA10", entity_limit = 1L), id = 8L)
if (!is.null(query_alias$error)) stop("query alias returned JSON-RPC error: ", query_alias$error$message)
if (!isTRUE(query_alias$result$isError)) stop("query alias did not return a tool error result")
query_payload <- jsonlite::fromJSON(query_alias$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(query_payload$error$code, "invalid_input") || !identical(query_payload$error$argument, "query")) {
  stop("query alias did not return invalid_input for query")
}

gene_batch <- call_tool("get_genes_context", list(genes = list("PNKP")), id = 80L)
if (!is.null(gene_batch$error)) stop("get_genes_context returned JSON-RPC error: ", gene_batch$error$message)
gene_batch_payload <- jsonlite::fromJSON(gene_batch$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(gene_batch_payload$meta$requested, 1L)) {
  stop("get_genes_context did not report the requested gene count")
}

cheap_gene <- call_tool(
  "get_gene_context",
  list(gene = "NAA10", include_comparisons = FALSE, entity_limit = 2L, response_mode = "compact"),
  id = 81L
)
if (!is.null(cheap_gene$error)) stop("cheap get_gene_context returned JSON-RPC error: ", cheap_gene$error$message)
cheap_gene_payload <- jsonlite::fromJSON(cheap_gene$result$content[[1]]$text, simplifyVector = FALSE)
if (length(cheap_gene_payload$comparison_sources %||% list()) != 0L) {
  stop("cheap get_gene_context returned comparison_sources")
}
if (is.null(cheap_gene_payload$meta$entity_total) || is.null(cheap_gene_payload$meta$entity_has_more)) {
  stop("get_gene_context did not report entity pagination metadata")
}
if (is.null(cheap_gene$result$structuredContent)) {
  stop("get_gene_context response missing structuredContent despite outputSchema")
}
entity_ids <- vapply(cheap_gene_payload$entities %||% list(), function(x) as.integer(x$entity_id), integer(1))
if (length(entity_ids) > 0L) {
  batch <- call_tool(
    "get_entities_context",
    list(entity_ids = as.list(entity_ids), publication_limit = 2L, abstract_mode = "metadata", dedupe_publications = TRUE),
    id = 82L
  )
  if (!is.null(batch$error)) stop("deduped get_entities_context returned JSON-RPC error: ", batch$error$message)
  batch_payload <- jsonlite::fromJSON(batch$result$content[[1]]$text, simplifyVector = FALSE)
  if (!isTRUE(batch_payload$meta$dedupe_publications)) {
    stop("get_entities_context did not report dedupe_publications")
  }
  if (length(batch_payload$entities) > 0L && !is.null(batch_payload$entities[[1]]$publications)) {
    stop("deduped get_entities_context kept nested publications")
  }
  if (length(batch_payload$publications) > 0L && !is.null(batch_payload$publications[[1]]$abstract_excerpt)) {
    stop("abstract_mode=metadata returned abstract_excerpt in batch payload")
  }
  if (length(batch_payload$publications) > 0L) {
    publication_id <- batch_payload$publications[[1]]$publication_id
    publication_detail <- call_tool(
      "get_publication_context",
      list(pmid = publication_id, abstract_mode = "metadata"),
      id = 821L
    )
    if (!is.null(publication_detail$error)) stop("get_publication_context returned JSON-RPC error: ", publication_detail$error$message)
    publication_payload <- jsonlite::fromJSON(publication_detail$result$content[[1]]$text, simplifyVector = FALSE)
    linked_entities <- publication_payload$linked_entities %||% list()
    if (length(linked_entities) > 0L &&
      any(!vapply(linked_entities, function(x) !is.null(x$publication_type), logical(1)))) {
      stop("publication linked entity rows did not include publication_type")
    }
    # issue #353: structuredContent must mirror content[].text (no `{}` for nulls),
    # and the top-level publication_type must never serialize as an empty object.
    structured_text <- publication_detail$result$structuredContent
    if (is.null(structured_text)) {
      stop("get_publication_context response missing structuredContent despite outputSchema")
    }
    if (is.list(structured_text$publication_type) &&
      length(structured_text$publication_type) == 0L) {
      stop("get_publication_context publication_type serialized as an empty object instead of null/string")
    }
  }
  expanded_gene <- call_tool(
    "get_gene_context",
    list(
      gene = "NAA10",
      entity_limit = 2L,
      response_mode = "compact",
      expand = "entities",
      abstract_mode = "metadata",
      publication_limit = 2L
    ),
    id = 83L
  )
  if (!is.null(expanded_gene$error)) stop("expanded get_gene_context returned JSON-RPC error: ", expanded_gene$error$message)
  expanded_payload <- jsonlite::fromJSON(expanded_gene$result$content[[1]]$text, simplifyVector = FALSE)
  if (!identical(expanded_payload$meta$expand, "entities") || is.null(expanded_payload$entity_details)) {
    stop("get_gene_context expand=entities did not return entity_details")
  }
  if (length(expanded_payload$entity_details$publications) > 0L &&
    !is.null(expanded_payload$entity_details$publications[[1]]$abstract_excerpt)) {
    stop("expanded get_gene_context metadata mode returned abstract_excerpt")
  }
}

bad_gene_arg <- call_tool("get_gene_context", list(foo = "NAA10"), id = 9L)
if (!is.null(bad_gene_arg$error)) stop("Unknown gene arg returned JSON-RPC error: ", bad_gene_arg$error$message)
if (!isTRUE(bad_gene_arg$result$isError)) stop("Unknown gene arg did not return a tool error result")
bad_gene_payload <- jsonlite::fromJSON(bad_gene_arg$result$content[[1]]$text, simplifyVector = FALSE)
if (!identical(bad_gene_payload$error$code, "invalid_input") || !identical(bad_gene_payload$error$argument, "foo")) {
  stop("Unknown gene arg did not return invalid_input for foo")
}

cat("MCP smoke OK: ", paste(sort(tool_names), collapse = ", "), "\n", sep = "")
