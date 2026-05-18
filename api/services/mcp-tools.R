# services/mcp-tools.R
#
# MCP protocol patches for resources, prompts, tool schemas, and structured results.

mcp_tool_result_response <- function(id, payload, is_error = FALSE, output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  body <- list(
    content = list(list(type = "text", text = jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", na = "null"))),
    isError = isTRUE(is_error),
    structuredContent = payload
  )
  mcp_jsonrpc_response(id, body)
}

mcp_tool_property_names <- function(tool) {
  names(tool@arguments@properties %||% list())
}

mcp_tool_required_properties <- function(tool) {
  props <- tool@arguments@properties %||% list()
  names(props)[vapply(props, function(prop) isTRUE(prop@required), logical(1))]
}

mcp_tool_call_arg_error <- function(data, tools) {
  if (!identical(data$method, "tools/call")) {
    return(NULL)
  }
  tool_name <- data$params$name %||% ""
  matches <- Filter(function(tool) identical(tool@name, tool_name), tools)
  if (length(matches) != 1L) {
    return(NULL)
  }

  tool <- matches[[1]]
  args <- data$params$arguments %||% list()
  if (is.null(args)) args <- list()
  if (is.null(names(args))) names(args) <- rep("", length(args))

  expected <- mcp_tool_property_names(tool)
  hidden_aliases <- mcp_hidden_aliases(tool_name)
  allowed <- union(expected, hidden_aliases)
  visible_expected <- mcp_visible_expected_arguments(tool_name, expected)
  provided <- names(args)[nzchar(names(args))]
  unknown <- setdiff(provided, allowed)
  gene_hint <- "Use 'gene' for gene symbols, HGNC IDs, or HGNC:1234 identifiers."
  if (length(unknown) > 0L) {
    fields <- list(argument = unknown[[1]], expected_arguments = visible_expected)
    if (tool_name %in% c("get_gene_context", "list_gene_entities")) fields$hint <- gene_hint
    return(mcp_error("invalid_input", sprintf("Unknown parameter '%s'. Expected: %s", unknown[[1]], paste(visible_expected, collapse = ", ")), fields))
  }

  missing <- setdiff(mcp_tool_required_properties(tool), provided)
  if (length(missing) > 0L) {
    return(mcp_error("invalid_input", sprintf("Missing required parameter '%s'", missing[[1]]), list(argument = missing[[1]], expected_arguments = expected)))
  }
  NULL
}

mcp_patch_mcptools_result_formatter <- function(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  if (!requireNamespace("mcptools", quietly = TRUE)) {
    return(FALSE)
  }
  ns <- asNamespace("mcptools")
  original <- getOption("sysndd.mcptools.as_tool_call_result_original")
  if (is.null(original)) {
    original <- base::get("as_tool_call_result", envir = ns)
    options(sysndd.mcptools.as_tool_call_result_original = list(original))
  } else {
    original <- original[[1]]
  }
  patched <- function(data, result) {
    if (inherits(result, "sysndd_mcp_text_result")) {
      payload <- attr(result, "sysndd_mcp_payload")
      return(mcp_tool_result_response(
        data$id,
        payload,
        is_error = isTRUE(attr(result, "sysndd_mcp_is_error")),
        output_mode = attr(result, "sysndd_mcp_output_mode")
      ))
    }
    original(data, result)
  }
  environment(patched) <- environment()
  assignInNamespace("as_tool_call_result", patched, ns = "mcptools")
  TRUE
}

mcp_patch_mcptools_protocol <- function(registry, instructions = mcp_server_instructions()) {
  if (!requireNamespace("mcptools", quietly = TRUE)) {
    return(FALSE)
  }
  ns <- asNamespace("mcptools")
  mcp_patch_mcptools_instructions(instructions)

  patched_tools <- function() mcp_tool_metadata(registry$tools)
  environment(patched_tools) <- environment()
  assignInNamespace("get_mcptools_tools_as_json", patched_tools, ns = "mcptools")

  original_handle <- getOption("sysndd.mcptools.handle_http_request_message_original")
  if (is.null(original_handle)) {
    original_handle <- base::get("handle_http_request_message", envir = ns)
    options(sysndd.mcptools.handle_http_request_message_original = list(original_handle))
  } else {
    original_handle <- original_handle[[1]]
  }
  patched_handle <- function(data) {
    if (identical(data$method, "resources/list")) {
      return(mcp_handle_resources_list(data$id))
    }
    if (identical(data$method, "resources/read")) {
      return(mcp_handle_resources_read(data$id, data$params$uri))
    }
    if (identical(data$method, "prompts/list")) {
      return(mcp_handle_prompts_list(data$id))
    }
    if (identical(data$method, "prompts/get")) {
      if (!mcp_prompts_enabled()) {
        return(mcp_jsonrpc_response(
          data$id,
          error = list(code = -32601L, message = "MCP prompts are disabled")
        ))
      }
      return(mcp_handle_prompts_get(data$id, data$params$name, data$params$arguments %||% list()))
    }
    tool_arg_error <- mcp_tool_call_arg_error(data, registry$tools)
    if (!is.null(tool_arg_error)) {
      return(mcp_tool_result_response(data$id, unclass(tool_arg_error), is_error = TRUE))
    }
    original_handle(data)
  }
  environment(patched_handle) <- environment()
  assignInNamespace("handle_http_request_message", patched_handle, ns = "mcptools")

  mcp_patch_mcptools_result_formatter(Sys.getenv("MCP_OUTPUT_MODE", "json_text"))
  TRUE
}
