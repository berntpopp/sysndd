test_that("MCP registry exposes only approved SysNDD tools", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  tool_names <- vapply(registry$tools, function(x) x@name %||% x$name %||% "", character(1))

  expect_setequal(tool_names, c(
    "search_sysndd",
    "get_gene_context",
    "get_entity_context",
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
  expect_match(instructions, "get_publications_context", fixed = TRUE)
  expect_match(instructions, "sysndd://schema/tool-guide", fixed = TRUE)
  expect_match(instructions, "not_found", fixed = TRUE)
  expect_match(instructions, "read-only", ignore.case = TRUE)
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
