# tests/testthat/mcp-analysis-service-fixtures.R
#
# Shared source setup for the MCP analysis-service and research-context tests.
# Both test files explicitly source this fixture so standalone test_file() runs
# do not depend on suite order or helper auto-loading.

mcp_analysis_source_file <- function(relative_path) {
  source(file.path(get_api_dir(), relative_path), local = FALSE)
}

mcp_analysis_source_services <- function() {
  mcp_analysis_source_file("services/mcp-service.R")
  mcp_analysis_source_file("functions/analysis-snapshot-presets.R")
  mcp_analysis_source_file("services/mcp-analysis-shaping.R")
  mcp_analysis_source_file("services/mcp-query-service.R")
  mcp_analysis_source_file("services/mcp-record-service.R")
  mcp_analysis_source_file("services/mcp-analysis-service.R")
  mcp_analysis_source_file("services/mcp-analysis-llm-cache-service.R")
  mcp_analysis_source_file("services/mcp-research-context-service.R")
}

source_mcp_analysis_repository <- function() {
  mcp_analysis_source_file("functions/mcp-analysis-cache-repository.R")
  mcp_analysis_source_file("functions/mcp-analysis-repository.R")
}

mcp_analysis_source_services()
