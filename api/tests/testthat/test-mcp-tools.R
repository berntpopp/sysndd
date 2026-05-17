test_that("MCP registry exposes only approved SysNDD tools", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  tool_names <- vapply(registry$tools, function(x) x@name %||% x$name %||% "", character(1))

  expect_setequal(tool_names, c(
    "search_sysndd",
    "get_gene_context",
    "get_entity_context",
    "get_entities_context",
    "list_gene_entities",
    "get_publication_context",
    "get_publications_context",
    "find_entities_by_phenotype",
    "find_entities_by_disease",
    "get_sysndd_stats",
    "get_sysndd_capabilities"
  ))
  expect_false(any(grepl("session|code|sql|admin|review|job|log|user", tool_names, ignore.case = TRUE)))
  expect_true(any(vapply(registry$resources, function(x) identical(x$uri, "sysndd://schema/overview"), logical(1))))
  expect_true(any(vapply(registry$resources, function(x) identical(x$uri, "sysndd://schema/tool-guide"), logical(1))))
})

test_that("MCP server instructions describe workflow, resources, errors, and constraints", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

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
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  expect_true(mcp_patch_mcptools_instructions("SysNDD custom instructions"))
  capabilities <- get("capabilities", envir = asNamespace("mcptools"))()

  expect_equal(capabilities$serverInfo$name, "SysNDD read-only MCP")
  expect_equal(capabilities$instructions, "SysNDD custom instructions")
  expect_false(is.null(capabilities$capabilities$prompts))
  expect_false(is.null(capabilities$capabilities$resources))
})

test_that("MCP tool wrapper serializes tool errors as stable JSON text", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  wrapped <- mcp_tool_safe(function() stop(mcp_error("invalid_input", "Bad input")), output_mode = "json_text")
  parsed <- jsonlite::fromJSON(wrapped(), simplifyVector = FALSE)

  expect_equal(parsed$schema_version, "1.0")
  expect_equal(parsed$error$code, "invalid_input")
})

test_that("MCP registry exposes rich tool metadata for LLM clients", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

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

  search <- metadata[[which(tool_names == "search_sysndd")]]
  expect_match(search$inputSchema$properties$types$description, "default all", ignore.case = TRUE)

  phenotype <- metadata[[which(tool_names == "find_entities_by_phenotype")]]
  expect_match(phenotype$inputSchema$properties$modifier$description, "default present", ignore.case = TRUE)
  expect_match(phenotype$inputSchema$properties$category$description, "default Definitive", fixed = TRUE)

  capabilities <- metadata[[which(tool_names == "get_sysndd_capabilities")]]
  expect_match(capabilities$description, "capabilities", ignore.case = TRUE)
})

test_that("MCP tool responses include structuredContent when output schemas are advertised", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  payload <- list(schema_version = "1.0", value = "ok")
  response <- mcp_tool_result_response(1L, payload, output_mode = "json_text")

  expect_equal(response$result$structuredContent, payload)
  expect_match(response$result$content[[1]]$text, "\"schema_version\"", fixed = TRUE)
})

test_that("MCP static resource handlers list and read distinct schema resources", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

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

test_that("MCP tool wrappers accept common gene aliases and reject unknown parameters visibly", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  old_resolve <- mcp_repo_resolve_gene
  old_entities <- mcp_repo_get_gene_entities
  old_comparisons <- mcp_repo_get_gene_comparisons
  assign("mcp_repo_resolve_gene", function(normalized_gene) {
    tibble::tibble(hgnc_id = "HGNC:18704", symbol = "NAA10", name = "NAA10")
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_entities", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_gene_comparisons", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_resolve_gene", old_resolve, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_entities", old_entities, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_comparisons", old_comparisons, envir = .GlobalEnv)
  })

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  tool <- registry$tools[[which(vapply(registry$tools, function(x) x@name, character(1)) == "get_gene_context")]]

  parsed <- jsonlite::fromJSON(tool(symbol = "NAA10"), simplifyVector = FALSE)
  expect_equal(parsed$gene$symbol, "NAA10")

  parsed_query <- jsonlite::fromJSON(tool(query = "NAA10"), simplifyVector = FALSE)
  expect_equal(parsed_query$gene$symbol, "NAA10")

  hidden_alias_ok <- mcp_tool_call_arg_error(
    list(method = "tools/call", params = list(name = "get_gene_context", arguments = list(query = "NAA10"))),
    registry$tools
  )
  expect_null(hidden_alias_ok)

  err <- mcp_tool_call_arg_error(
    list(method = "tools/call", params = list(name = "get_gene_context", arguments = list(foo = "NAA10"))),
    registry$tools
  )
  err_payload <- unclass(err)
  expect_equal(err_payload$error$code, "invalid_input")
  expect_equal(err_payload$error$argument, "foo")
  expect_false("symbol" %in% err_payload$error$expected_arguments)
  expect_false("query" %in% err_payload$error$expected_arguments)
  expect_equal(err_payload$error$hint, "Use 'gene' for gene symbols, HGNC IDs, or HGNC:1234 identifiers.")
})

test_that("MCP prompt handlers list and render SysNDD workflow prompts", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

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
