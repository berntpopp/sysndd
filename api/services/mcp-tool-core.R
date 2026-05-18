# services/mcp-tool-core.R
#
# MCP tool serialization, metadata, and JSON-RPC helpers for the read-only SysNDD sidecar.

library(jsonlite)

mcp_serialize_result <- function(value, output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  text <- jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", na = "null")
  structure(
    text,
    sysndd_mcp_payload = value,
    sysndd_mcp_output_mode = output_mode,
    class = c("sysndd_mcp_text_result", "character")
  )
}

mcp_add_elapsed_ms <- function(value, started_at) {
  if (!is.list(value)) {
    return(value)
  }
  elapsed_ms <- as.integer(round((as.numeric(Sys.time()) - started_at) * 1000))
  value$meta <- value$meta %||% list()
  value$meta$elapsed_ms <- elapsed_ms
  value
}

mcp_tool_safe <- function(fn, output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  force(fn)
  force(output_mode)
  function(...) {
    started_at <- as.numeric(Sys.time())
    tryCatch(
      mcp_serialize_result(mcp_add_elapsed_ms(fn(...), started_at), output_mode = output_mode),
      mcp_tool_error = function(e) {
        res <- mcp_serialize_result(mcp_add_elapsed_ms(mcp_error_payload(e), started_at), output_mode = output_mode)
        attr(res, "sysndd_mcp_is_error") <- TRUE
        res
      },
      error = function(e) {
        res <- mcp_serialize_result(
          mcp_add_elapsed_ms(mcp_error("temporarily_unavailable", "MCP tool failed"), started_at),
          output_mode = output_mode
        )
        attr(res, "sysndd_mcp_is_error") <- TRUE
        res
      }
    )
  }
}

mcp_unknown_arg_error <- function(provided, expected, hint = NULL) {
  unknown <- setdiff(provided[nzchar(provided)], expected)
  if (length(unknown) > 0L) {
    fields <- list(argument = unknown[[1]], expected_arguments = expected)
    if (!is.null(hint) && nzchar(hint)) fields$hint <- hint
    stop(mcp_error(
      "invalid_input",
      sprintf("Unknown parameter '%s'. Expected: %s", unknown[[1]], paste(expected, collapse = ", ")),
      fields
    ))
  }
}

mcp_tool_args <- function(args, expected, required = character(), aliases = list(), unknown_hint = NULL) {
  if (is.null(names(args))) names(args) <- rep("", length(args))
  for (alias in names(aliases)) {
    if (alias %in% names(args)) {
      canonical <- aliases[[alias]]
      if (!canonical %in% names(args)) args[[canonical]] <- args[[alias]]
      args[[alias]] <- NULL
    }
  }
  mcp_unknown_arg_error(names(args), expected, hint = unknown_hint)
  missing <- setdiff(required, names(args))
  if (length(missing) > 0L) {
    stop(mcp_error(
      "invalid_input",
      sprintf("Missing required parameter '%s'", missing[[1]]),
      list(argument = missing[[1]], expected_arguments = expected)
    ))
  }
  args
}
mcp_tool_annotations <- function(title = NULL) {
  compact <- function(x) x[!vapply(x, is.null, logical(1))]
  compact(list(
    title = title,
    readOnlyHint = TRUE,
    destructiveHint = FALSE,
    idempotentHint = TRUE,
    openWorldHint = FALSE
  ))
}

MCP_ANALYSIS_TOOL_NAMES <- c(
  "get_sysndd_analysis_catalog",
  "get_gene_research_context",
  "get_nddscore_context",
  "get_curation_comparison_context",
  "get_phenotype_analysis_context",
  "get_gene_network_context"
)

mcp_output_schema <- function(name) {
  base <- list(
    type = "object",
    properties = list(
      schema_version = list(type = "string", description = "SysNDD MCP payload schema version."),
      error = list(
        type = "object",
        description = "Present when the tool returns a recoverable application-level error.",
        properties = list(
          code = list(type = "string"),
          message = list(type = "string"),
          argument = list(type = "string")
        )
      )
    ),
    required = list("schema_version"),
    additionalProperties = TRUE,
    description = sprintf("Stable SysNDD MCP %s result envelope.", name)
  )
  if (!name %in% MCP_ANALYSIS_TOOL_NAMES) {
    return(base)
  }

  base$properties <- c(base$properties, list(
    data_class = list(type = "string", description = "Data class label, for example curated_derived_analysis, ml_prediction, or llm_generated_summary."),
    budget = list(type = "object", description = "Response budget metadata including requested, estimated, returned, and dropped_summary fields when applicable."),
    meta = list(type = "object", description = "Mode, paging, diagnostics, cache, dry_run, and timing metadata."),
    recovery = list(type = "object", description = "Optional recovery hints such as retry_with values for smaller or diagnostic calls.")
  ))
  if (identical(name, "get_nddscore_context")) {
    base$properties <- c(base$properties, list(
      curation_effect = list(type = "string", description = "Always none; NDDScore never changes curated SysNDD classifications."),
      not_evidence_tier = list(type = "boolean", description = "Always true; NDDScore is not a curated evidence tier."),
      notice = list(type = "string", description = "ML prediction boundary notice.")
    ))
  }
  base$description <- sprintf("Stable SysNDD MCP %s analysis envelope with budget, metadata, and recoverable errors.", name)
  base
}

mcp_fill_array_descriptions <- function(input_schema) {
  props <- input_schema$properties
  if (is.null(props)) {
    return(input_schema)
  }
  for (name in names(props)) {
    prop <- props[[name]]
    if (identical(prop$type, "array") && !nzchar(prop$description %||% "")) {
      item_desc <- prop$items$description %||% ""
      prop$description <- if (nzchar(item_desc)) paste("Array of", item_desc) else sprintf("Array parameter '%s'.", name)
      props[[name]] <- prop
    }
  }
  input_schema$properties <- props
  input_schema
}

mcp_hidden_aliases <- function(tool_name) {
  character()
}

mcp_visible_expected_arguments <- function(tool_name, expected) {
  setdiff(expected, mcp_hidden_aliases(tool_name))
}

mcp_hide_deprecated_aliases <- function(item) {
  hidden <- mcp_hidden_aliases(item$name %||% "")
  if (length(hidden) == 0L || is.null(item$inputSchema$properties)) {
    return(item)
  }
  item$inputSchema$properties[hidden] <- NULL
  if (!is.null(item$inputSchema$required)) {
    item$inputSchema$required <- setdiff(item$inputSchema$required, hidden)
  }
  item
}

mcp_tool_metadata <- function(tools) {
  tool_as_json <- base::get("tool_as_json", envir = asNamespace("mcptools"))
  lapply(tools, function(tool) {
    item <- tool_as_json(tool)
    item$inputSchema <- mcp_fill_array_descriptions(item$inputSchema)
    item <- mcp_hide_deprecated_aliases(item)
    item$annotations <- mcp_tool_annotations(title = item$name)
    item$outputSchema <- mcp_output_schema(item$name)
    item
  })
}

mcp_jsonrpc_response <- function(id, result = NULL, error = NULL) {
  if (!is.null(error)) {
    return(list(jsonrpc = "2.0", id = id, error = error))
  }
  list(jsonrpc = "2.0", id = id, result = result)
}
