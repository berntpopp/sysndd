source_mcp_tools <- function() {
  source("../../services/mcp-service.R")
  source("../../services/mcp-analysis-shaping.R")
  source("../../services/mcp-capabilities-service.R")
  source("../../services/mcp-tool-core.R")
  source("../../services/mcp-tool-resources.R")
  source("../../services/mcp-tools.R")
  source("../../services/mcp-tool-analysis-registry.R")
  source("../../services/mcp-tool-registry.R")
}

analysis_tool_names <- c(
  "get_sysndd_analysis_catalog",
  "get_gene_research_context",
  "get_nddscore_context",
  "get_curation_comparison_context",
  "get_phenotype_analysis_context",
  "get_gene_network_context"
)

test_that("MCP registry exposes only approved SysNDD tools", {
  skip_if_not_installed("ellmer")

  source_mcp_tools()

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  tool_names <- vapply(registry$tools, function(x) x@name %||% x$name %||% "", character(1))

  expect_setequal(tool_names, c(
    "search_sysndd",
    "get_gene_context",
    "get_genes_context",
    "get_entity_context",
    "get_entities_context",
    "list_gene_entities",
    "get_publication_context",
    "get_publications_context",
    "find_entities_by_phenotype",
    "find_entities_by_disease",
    "get_sysndd_stats",
    "get_sysndd_capabilities",
    analysis_tool_names
  ))
  tool_tokens <- unique(unlist(strsplit(tool_names, "_", fixed = TRUE)))
  expect_false(any(tolower(tool_tokens) %in% c("session", "code", "sql", "admin", "review", "job", "log", "user")))
  expect_true(any(vapply(registry$resources, function(x) identical(x$uri, "sysndd://schema/overview"), logical(1))))
  expect_true(any(vapply(registry$resources, function(x) identical(x$uri, "sysndd://schema/tool-guide"), logical(1))))
})

test_that("get_genes_context is registered in the tool registry", {
  skip_if_not_installed("ellmer")

  source_mcp_tools()

  registry <- mcp_build_tool_registry()
  tool_names <- vapply(registry$tools, function(t) t@name, character(1))
  expect_true("get_genes_context" %in% tool_names)
  expect_true("get_genes_context" %in% names(registry$tool_functions))
})

test_that("MCP server instructions describe workflow, resources, errors, and constraints", {
  source_mcp_tools()

  instructions <- mcp_server_instructions()

  expect_match(instructions, "gene.*entity.*publication", ignore.case = TRUE)
  expect_match(instructions, "entities are gene-disease-inheritance", ignore.case = TRUE)
  expect_match(instructions, "get_entities_context", fixed = TRUE)
  expect_match(instructions, "get_publications_context", fixed = TRUE)
  expect_match(instructions, "get_sysndd_capabilities", fixed = TRUE)
  expect_match(instructions, "sysndd://schema/tool-guide", fixed = TRUE)
  expect_match(instructions, "not_found", fixed = TRUE)
  expect_match(instructions, "read-only", ignore.case = TRUE)
  expect_match(instructions, "research", ignore.case = TRUE)
})

test_that("MCP initialize capabilities use SysNDD-specific instructions", {
  skip_if_not_installed("mcptools")

  source_mcp_tools()

  expect_true(mcp_patch_mcptools_instructions("SysNDD custom instructions"))
  capabilities <- get("capabilities", envir = asNamespace("mcptools"))()

  expect_equal(capabilities$serverInfo$name, "SysNDD read-only MCP")
  expect_equal(capabilities$instructions, "SysNDD custom instructions")
  expect_true(is.null(capabilities$capabilities$prompts))
  expect_false(is.null(capabilities$capabilities$resources))

  old_prompts <- Sys.getenv("MCP_ENABLE_PROMPTS", unset = NA_character_)
  on.exit(
    {
      if (is.na(old_prompts)) {
        Sys.unsetenv("MCP_ENABLE_PROMPTS")
      } else {
        Sys.setenv(MCP_ENABLE_PROMPTS = old_prompts)
      }
    },
    add = TRUE
  )
  Sys.setenv(MCP_ENABLE_PROMPTS = "true")
  capabilities <- get("capabilities", envir = asNamespace("mcptools"))()
  expect_false(is.null(capabilities$capabilities$prompts))
})

test_that("MCP tool wrapper serializes tool errors as stable JSON text", {
  source_mcp_tools()

  wrapped <- mcp_tool_safe(function() stop(mcp_error("invalid_input", "Bad input")), output_mode = "json_text")
  parsed <- jsonlite::fromJSON(wrapped(), simplifyVector = FALSE)

  expect_equal(parsed$schema_version, MCP_SCHEMA_VERSION)
  expect_equal(parsed$error$code, "invalid_input")

  wrapped_condition <- mcp_tool_safe(function() {
    stop(mcp_error("temporarily_unavailable", "Bad input", list(cause = simpleError("raw R error"))))
  }, output_mode = "json_text")
  parsed_condition <- jsonlite::fromJSON(wrapped_condition(), simplifyVector = FALSE)

  expect_equal(parsed_condition$error$code, "temporarily_unavailable")
  expect_false(inherits(parsed_condition$error$cause, "condition"))
})

test_that("MCP registry exposes rich tool metadata for LLM clients", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("mcptools")

  source_mcp_tools()

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  metadata <- mcp_tool_metadata(registry$tools)

  expect_true(all(vapply(metadata, function(x) isTRUE(x$annotations$readOnlyHint), logical(1))))
  expect_true(all(vapply(metadata, function(x) identical(x$annotations$destructiveHint, FALSE), logical(1))))
  expect_true(all(vapply(metadata, function(x) !is.null(x$outputSchema), logical(1))))

  tool_names <- vapply(metadata, `[[`, character(1), "name")
  search <- metadata[[which(tool_names == "search_sysndd")]]
  expect_true(nzchar(search$inputSchema$properties$types$description))

  batch_pubs <- metadata[[which(tool_names == "get_publications_context")]]
  expect_true(nzchar(batch_pubs$inputSchema$properties$pmids$description))

  batch_entities <- metadata[[which(tool_names == "get_entities_context")]]
  expect_true(nzchar(batch_entities$inputSchema$properties$entity_ids$description))

  gene <- metadata[[which(tool_names == "get_gene_context")]]
  expect_match(gene$description, "Example:", fixed = TRUE)
  expect_match(gene$description, "include_comparisons", fixed = TRUE)
  expect_no_match(gene$description, "symbol", ignore.case = TRUE)
  expect_no_match(gene$description, "query", ignore.case = TRUE)
  expect_null(gene$inputSchema$properties$symbol)
  expect_null(gene$inputSchema$properties$query)
  expect_no_match(gene$inputSchema$properties$gene$description, "symbol/query", fixed = TRUE)
  expect_true("gene" %in% gene$inputSchema$required)
  expect_false(is.null(gene$inputSchema$properties$response_mode))
  expect_match(gene$inputSchema$properties$include_entities$description, "default true", ignore.case = TRUE)
  expect_match(gene$inputSchema$properties$include_comparisons$description, "default false", ignore.case = TRUE)
  expect_match(gene$inputSchema$properties$expand$description, "none", fixed = TRUE)
  expect_match(gene$inputSchema$properties$expand$description, "entities", fixed = TRUE)
  expect_match(gene$inputSchema$properties$entity_limit$description, "detail fetches at most 20", ignore.case = TRUE)

  entity <- metadata[[which(tool_names == "get_entity_context")]]
  expect_match(entity$inputSchema$properties$include_publications$description, "default true", ignore.case = TRUE)
  expect_match(entity$inputSchema$properties$include_phenotypes$description, "default true", ignore.case = TRUE)

  list_gene <- metadata[[which(tool_names == "list_gene_entities")]]
  expect_null(list_gene$inputSchema$properties$symbol)
  expect_null(list_gene$inputSchema$properties$query)
  expect_no_match(list_gene$inputSchema$properties$gene$description, "symbol", ignore.case = TRUE)
  expect_true("gene" %in% list_gene$inputSchema$required)

  search <- metadata[[which(tool_names == "search_sysndd")]]
  expect_match(search$inputSchema$properties$types$description, "default all", ignore.case = TRUE)

  phenotype <- metadata[[which(tool_names == "find_entities_by_phenotype")]]
  expect_match(phenotype$inputSchema$properties$modifier$description, "default present", ignore.case = TRUE)
  expect_match(phenotype$inputSchema$properties$category$description, "default Definitive", fixed = TRUE)

  capabilities <- metadata[[which(tool_names == "get_sysndd_capabilities")]]
  expect_match(capabilities$description, "capabilities", ignore.case = TRUE)
})

test_that("MCP analysis tools advertise labels and do not expose LLM generation", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("mcptools")

  source_mcp_tools()

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  metadata <- mcp_tool_metadata(registry$tools)
  names <- vapply(metadata, `[[`, character(1), "name")

  for (tool_name in c("get_nddscore_context", "get_gene_research_context")) {
    item <- metadata[[which(names == tool_name)]]
    expect_true(isTRUE(item$annotations$readOnlyHint))
    expect_false(isTRUE(item$annotations$openWorldHint))
    expect_false(any(grepl("prompt|gemini|generate", names(item$inputSchema$properties), ignore.case = TRUE)))
    expect_true("response_mode" %in% names(item$inputSchema$properties))
    expect_true("max_response_chars" %in% names(item$inputSchema$properties))
    expect_true("include_diagnostics" %in% names(item$inputSchema$properties))
    expect_true("dry_run" %in% names(item$inputSchema$properties))
    expect_match(item$description, "compact", ignore.case = TRUE)
    expect_match(item$description, "snapshot|cache", ignore.case = TRUE)
    expect_false(is.null(item$outputSchema))
  }

  network <- metadata[[which(names == "get_gene_network_context")]]
  expect_match(network$inputSchema$properties$cluster_type$description, "Fixed stored snapshot key", fixed = TRUE)
  expect_match(network$inputSchema$properties$min_confidence$description, "unsupported_parameter", fixed = TRUE)
})

test_that("MCP analysis output schemas expose budget and data-class fields", {
  source_mcp_tools()

  for (tool_name in analysis_tool_names) {
    schema <- mcp_output_schema(tool_name)
    expect_true("schema_version" %in% names(schema$properties))
    expect_true("error" %in% names(schema$properties))
    expect_true("budget" %in% names(schema$properties))
    expect_true("meta" %in% names(schema$properties))
  }

  nddscore <- mcp_output_schema("get_nddscore_context")
  expect_true("data_class" %in% names(nddscore$properties))
  expect_true("curation_effect" %in% names(nddscore$properties))
  expect_true("not_evidence_tier" %in% names(nddscore$properties))
  expect_true("notice" %in% names(nddscore$properties))
})

test_that("MCP tool responses include structuredContent when output schemas are advertised", {
  source_mcp_tools()

  payload <- list(schema_version = "1.0", value = "ok")
  response <- mcp_tool_result_response(1L, payload, output_mode = "json_text")

  expect_equal(response$result$structuredContent, payload)
  expect_match(response$result$content[[1]]$text, "\"schema_version\"", fixed = TRUE)
})

test_that("MCP static resource handlers list and read distinct schema resources", {
  source_mcp_tools()

  listed <- mcp_handle_resources_list(1L)
  uris <- vapply(listed$result$resources, `[[`, character(1), "uri")
  expect_true("sysndd://schema/overview" %in% uris)
  expect_true("sysndd://schema/tool-guide" %in% uris)

  read <- mcp_handle_resources_read(2L, "sysndd://schema/tool-guide")
  expect_match(read$result$contents[[1]]$text, "tool-guide", fixed = TRUE)

  overview <- mcp_handle_resources_read(4L, "sysndd://schema/overview")
  overview_text <- overview$result$contents[[1]]$text
  tool_guide_text <- read$result$contents[[1]]$text
  expect_match(overview_text, "schema/overview", fixed = TRUE)
  expect_no_match(overview_text, "schema/tool-guide", fixed = TRUE)
  expect_no_match(tool_guide_text, "schema/overview", fixed = TRUE)
  expect_false(identical(overview_text, tool_guide_text))

  missing <- mcp_handle_resources_read(3L, "sysndd://schema/missing")
  expect_equal(missing$error$code, -32002)
})

test_that("MCP tool wrappers reject unknown gene aliases visibly", {
  skip_if_not_installed("ellmer")

  source("../../functions/mcp-repository.R")
  source_mcp_tools()

  old_resolve <- mcp_repo_resolve_gene
  old_entities <- mcp_repo_get_gene_entities
  old_count <- mcp_repo_count_gene_entities
  old_comparisons <- mcp_repo_get_gene_comparisons
  assign("mcp_repo_resolve_gene", function(normalized_gene) {
    tibble::tibble(hgnc_id = "HGNC:18704", symbol = "NAA10", name = "NAA10")
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_entities", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_count_gene_entities", function(...) 0L, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_comparisons", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_resolve_gene", old_resolve, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_entities", old_entities, envir = .GlobalEnv)
    assign("mcp_repo_count_gene_entities", old_count, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_comparisons", old_comparisons, envir = .GlobalEnv)
  })

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  tool <- registry$tools[[which(vapply(registry$tools, function(x) x@name, character(1)) == "get_gene_context")]]

  parsed <- jsonlite::fromJSON(tool(gene = "NAA10"), simplifyVector = FALSE)
  expect_equal(parsed$gene$symbol, "NAA10")
  expect_false(is.null(parsed$meta$elapsed_ms))

  alias_err <- mcp_tool_call_arg_error(
    list(method = "tools/call", params = list(name = "get_gene_context", arguments = list(query = "NAA10"))),
    registry$tools
  )
  alias_payload <- unclass(alias_err)
  expect_equal(alias_payload$error$code, "invalid_input")
  expect_equal(alias_payload$error$argument, "query")

  err <- mcp_tool_call_arg_error(
    list(method = "tools/call", params = list(name = "get_gene_context", arguments = list(foo = "NAA10"))),
    registry$tools
  )
  err_payload <- unclass(err)
  expect_equal(err_payload$error$code, "invalid_input")
  expect_equal(err_payload$error$argument, "foo")
  expect_false("symbol" %in% err_payload$error$expected_arguments)
  expect_false("query" %in% err_payload$error$expected_arguments)
})

test_that("MCP prompt handlers list and render SysNDD workflow prompts", {
  source_mcp_tools()

  old_prompts <- Sys.getenv("MCP_ENABLE_PROMPTS", unset = NA_character_)
  on.exit(
    {
      if (is.na(old_prompts)) {
        Sys.unsetenv("MCP_ENABLE_PROMPTS")
      } else {
        Sys.setenv(MCP_ENABLE_PROMPTS = old_prompts)
      }
    },
    add = TRUE
  )

  Sys.unsetenv("MCP_ENABLE_PROMPTS")
  disabled <- mcp_handle_prompts_list(0L)
  expect_length(disabled$result$prompts, 0L)

  Sys.setenv(MCP_ENABLE_PROMPTS = "true")
  listed <- mcp_handle_prompts_list(1L)
  prompt_names <- vapply(listed$result$prompts, `[[`, character(1), "name")

  expect_setequal(prompt_names, c(
    "sysndd_gene_evidence_summary",
    "sysndd_entity_evidence_brief",
    "sysndd_publication_citation_pack",
    "sysndd_phenotype_entity_discovery"
  ))
  expect_true(any(vapply(listed$result$prompts, function(x) length(x$arguments) > 0L, logical(1))))

  rendered <- mcp_handle_prompts_get(
    2L,
    "sysndd_gene_evidence_summary",
    list(gene = "PNKP", depth = "compact")
  )

  expect_equal(rendered$result$description, "Summarize approved public SysNDD gene evidence.")
  text <- rendered$result$messages[[1]]$content$text
  expect_match(text, "PNKP", fixed = TRUE)
  expect_match(text, "get_gene_context", fixed = TRUE)
  expect_match(text, "recommended_citation", fixed = TRUE)
  expect_match(text, "not clinical decision support", ignore.case = TRUE)

  missing <- mcp_handle_prompts_get(3L, "missing_prompt", list())
  expect_equal(missing$error$code, -32602)

  missing_arg <- mcp_handle_prompts_get(4L, "sysndd_gene_evidence_summary", list())
  expect_equal(missing_arg$error$code, -32602)
  expect_equal(missing_arg$error$data$argument, "gene")
})

test_that("capabilities expose error examples, performance, prompts, categories", {
  source_mcp_tools()

  caps <- mcp_get_sysndd_capabilities()
  expect_true(!is.null(caps$error_examples$ambiguous_query$error$choices))
  expect_null(caps$performance$get_publication_context$cache_ttl_seconds)
  expect_match(caps$performance$note, "projections", fixed = TRUE)
  expect_true(!is.null(caps$performance$get_publication_context$cost_tier))
  expect_true(!is.null(caps$mode_resolution))
  expect_true("not applicable" %in% caps$entity_categories$returned_values)
  expect_match(caps$canonical_workflows$deferred_tool_hint, "deferred", ignore.case = TRUE)
  expect_true(!is.null(caps$prompts$note))
  expect_false(caps$prompts$enabled_by_default)
  expect_equal(caps$prompts$enable_with, "MCP_ENABLE_PROMPTS=true")
  expect_true(!is.null(caps$prompts$available_when_enabled[[1]]$arguments))
  expect_equal(caps$payload_modes$gene_expand_example$response_mode, "minimal")
})

test_that("capabilities reference get_genes_context", {
  source_mcp_tools()

  caps <- mcp_get_sysndd_capabilities()
  expect_false(is.null(caps$canonical_workflows$gene_comparison))
  expect_false(is.null(caps$limits$get_genes_context))
})

test_that("capabilities document analysis workflows and guardrails", {
  source_mcp_tools()

  caps <- mcp_get_sysndd_capabilities()
  expect_false(is.null(caps$canonical_workflows$analysis_catalog))
  expect_false(is.null(caps$canonical_workflows$gene_research))
  expect_false(is.null(caps$analysis_data_classes$ml_prediction))
  expect_true(caps$analysis_data_classes$ml_prediction$not_evidence_tier)
  expect_match(caps$analysis_data_classes$llm_generated_summary$note, "validated stored", ignore.case = TRUE)
  expect_match(caps$analysis_tools$phenotype_correlations, "global snapshot context", ignore.case = TRUE)
  expect_null(caps$analysis_tools$db_release)
  expect_true(caps$safety$live_external_calls_disabled)
  expect_true(caps$safety$llm_generation_disabled)
  expect_match(caps$analysis_tools$guardrails, "No Gemini", fixed = TRUE)
})

test_that("MCP analysis tool descriptions make no result-cache claims", {
  text <- paste(
    c(
      readLines("../../services/mcp-tool-analysis-registry.R", warn = FALSE),
      readLines("../../services/mcp-tool-resources.R", warn = FALSE)
    ),
    collapse = "\n"
  )

  expect_false(grepl("cache-only|cached LLM|local cache|cache-safe", text, ignore.case = TRUE))
  expect_match(text, "validated stored", ignore.case = TRUE)
})
