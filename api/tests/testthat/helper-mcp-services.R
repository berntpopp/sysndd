# tests/testthat/helper-mcp-services.R
#
# Keep split MCP capability helpers available for legacy tests that source
# mcp-service.R directly.

.mcp_test_api_dir <- function() {
  candidates <- c(
    getwd(),
    file.path(getwd(), ".."),
    file.path(getwd(), "..", ".."),
    "/app"
  )
  for (dir in candidates) {
    if (file.exists(file.path(dir, "services", "mcp-service.R"))) {
      return(normalizePath(dir))
    }
  }
  stop("Cannot find api directory for MCP test helpers")
}

.mcp_test_source <- function(path) {
  source(file.path(.mcp_test_api_dir(), path), local = .GlobalEnv)
}

.mcp_test_source("services/mcp-service.R")
.mcp_test_source("services/mcp-query-service.R")
.mcp_test_source("services/mcp-record-service.R")
.mcp_test_source("services/mcp-analysis-shaping.R")
.mcp_test_source("services/mcp-capabilities-service.R")
