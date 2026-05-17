test_that("MCP identifier helpers normalize supported gene and PMID inputs", {
  source("../../services/mcp-service.R")

  expect_equal(mcp_normalize_gene_input("HGNC:1234"), list(kind = "hgnc_id", value = "1234"))
  expect_equal(mcp_normalize_gene_input("1234"), list(kind = "hgnc_id", value = "1234"))
  expect_equal(mcp_normalize_gene_input("MECP2"), list(kind = "symbol", value = "MECP2"))
  expect_equal(mcp_normalize_pmid("https://pubmed.ncbi.nlm.nih.gov/12345678/"), "PMID:12345678")
  expect_error(mcp_validate_limit(51, max = 50), class = "mcp_tool_error")
})

test_that("MCP envelopes include schema version and truncation metadata", {
  source("../../services/mcp-service.R")

  truncated <- mcp_truncate_text(paste(rep("x", 20), collapse = ""), 10)

  expect_true(truncated$truncated)
  expect_equal(nchar(truncated$text), 10)

  err <- mcp_error("invalid_input", "Bad input", fields = list(argument = "query"))

  expect_equal(err$schema_version, "1.0")
  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "query")
})

test_that("MCP input validators reject raw SQL-like and overbroad input", {
  source("../../services/mcp-service.R")

  expect_error(mcp_validate_query("x"), class = "mcp_tool_error")
  expect_error(mcp_validate_query("MECP2; DROP TABLE ndd_entity"), class = "mcp_tool_error")
  expect_error(mcp_validate_enum("maybe", c("yes", "no", "any"), "ndd_phenotype"), class = "mcp_tool_error")
})
