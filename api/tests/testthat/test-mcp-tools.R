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
    "find_entities_by_phenotype",
    "find_entities_by_disease",
    "get_sysndd_stats"
  ))
  expect_false(any(grepl("session|code|sql|admin|review|job|log|user", tool_names, ignore.case = TRUE)))
  expect_true(any(vapply(registry$resources, function(x) identical(x$uri, "sysndd://schema/overview"), logical(1))))
  expect_true(any(vapply(registry$resources, function(x) identical(x$uri, "sysndd://schema/tool-guide"), logical(1))))
})

test_that("MCP tool wrapper serializes tool errors as stable JSON text", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  wrapped <- mcp_tool_safe(function() stop(mcp_error("invalid_input", "Bad input")), output_mode = "json_text")
  parsed <- jsonlite::fromJSON(wrapped(), simplifyVector = FALSE)

  expect_equal(parsed$schema_version, "1.0")
  expect_equal(parsed$error$code, "invalid_input")
})
