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
    "get_sysndd_stats"
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
})

test_that("MCP static resource handlers list and read schema resources", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  listed <- mcp_handle_resources_list(1L)
  uris <- vapply(listed$result$resources, `[[`, character(1), "uri")
  expect_true("sysndd://schema/overview" %in% uris)
  expect_true("sysndd://schema/tool-guide" %in% uris)

  read <- mcp_handle_resources_read(2L, "sysndd://schema/tool-guide")
  expect_match(read$result$contents[[1]]$text, "tool-guide", fixed = TRUE)

  missing <- mcp_handle_resources_read(3L, "sysndd://schema/missing")
  expect_equal(missing$error$code, -32002)
})

test_that("MCP tool wrappers accept symbol alias and reject unknown parameters visibly", {
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
  tool <- registry$tool_functions$get_gene_context

  parsed <- jsonlite::fromJSON(tool(symbol = "NAA10"), simplifyVector = FALSE)
  expect_equal(parsed$gene$symbol, "NAA10")

  err <- jsonlite::fromJSON(tool(foo = "NAA10"), simplifyVector = FALSE)
  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "foo")
})
