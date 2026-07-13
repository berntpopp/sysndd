## -------------------------------------------------------------------##
# api/services/mcp-analysis-llm-cache-service.R
#
# MCP analysis LLM-summary reads (extracted from mcp-analysis-service.R to keep
# that file under the 600-line ceiling; #459). MCP exposes only validated,
# eligible, admin-generated cluster summaries from the dedicated projection and
# never triggers Gemini/LLM generation. All payloads are labelled
# `llm_generated_summary`.
## -------------------------------------------------------------------##

mcp_parse_json_field <- function(value, default = list()) {
  if (is.null(value) || length(value) == 0L || is.na(value[[1]]) || !nzchar(as.character(value[[1]]))) {
    return(default)
  }
  tryCatch(
    jsonlite::fromJSON(as.character(value[[1]]), simplifyVector = FALSE),
    error = function(e) default
  )
}

mcp_llm_summary_allowlist <- function(summary) {
  allowed <- if (base::exists("mcp_readonly_llm_summary_json_keys", mode = "function")) {
    mcp_readonly_llm_summary_json_keys()
  } else {
    c(
      "summary", "key_themes", "pathways", "tags", "clinical_relevance", "confidence",
      "key_phenotype_themes", "notably_absent", "clinical_pattern", "syndrome_hints",
      "inheritance_patterns", "syndromicity", "data_quality_note"
    )
  }
  if (!is.list(summary) || is.null(names(summary))) return(list())
  summary[intersect(allowed, names(summary))]
}

mcp_llm_cache_miss <- function(cluster_type, cluster_hash = NULL, cluster_number = NULL) {
  c(
    mcp_analysis_provenance(
      "llm_generated_summary", "SysNDD validated LLM summary",
      "mcp_public_llm_cluster_summary", "admin_llm_workflow"
    ),
    list(
      summary_available = FALSE,
      stored_summary_only = TRUE,
      cluster_type = cluster_type,
      cluster_hash = cluster_hash,
      cluster_number = cluster_number
    )
  )
}

mcp_get_cached_llm_summaries <- function(cluster_type,
                                         cluster_hashes = NULL,
                                         cluster_numbers = NULL,
                                         require_validated = TRUE,
                                         limit = 10L) {
  cluster_type <- mcp_validate_enum(cluster_type, c("functional", "phenotype"), "cluster_type")
  limit <- mcp_validate_limit(limit, default = 10L, max = 20L)
  rows <- mcp_analysis_repo_get_cached_llm_summaries(
    cluster_type = cluster_type,
    cluster_hashes = cluster_hashes,
    cluster_numbers = cluster_numbers,
    require_validated = require_validated,
    limit = limit
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(list(mcp_llm_cache_miss(
      cluster_type,
      cluster_hash = (cluster_hashes %||% list(NULL))[[1]],
      cluster_number = (cluster_numbers %||% list(NULL))[[1]]
    )))
  }

  lapply(seq_len(nrow(rows)), function(i) {
    row <- mcp_row_to_list(rows[i, , drop = FALSE])
    c(
      mcp_analysis_provenance(
        "llm_generated_summary", "SysNDD validated LLM summary",
        "mcp_public_llm_cluster_summary", "admin_llm_workflow"
      ),
      list(
        summary_available = TRUE,
        stored_summary_only = TRUE,
        summary_id = row$cache_id,
        cluster_type = row$cluster_type,
        cluster_number = row$cluster_number,
        cluster_hash = row$cluster_hash,
        model_name = row$model_name,
        prompt_version = row$prompt_version,
        validation_status = row$validation_status,
        created_at = row$created_at,
        validated_at = row$validated_at,
        tags = mcp_parse_json_field(row$tags, list()),
        summary = mcp_llm_summary_allowlist(mcp_parse_json_field(row$summary_json, list()))
      )
    )
  })
}
