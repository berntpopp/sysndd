######################################################################
# start_sysndd_mcp.R
#
# Dedicated read-only MCP sidecar for approved public SysNDD data.
# This process does not mount Plumber endpoints, run migrations, start
# workers, call Gemini, or call external providers.
######################################################################

source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/load_modules.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)
source("bootstrap/init_globals.R", local = FALSE)

bootstrap_init_libraries()

env_mode <- Sys.getenv("ENVIRONMENT", "local")
message(paste("ENVIRONMENT set to:", env_mode))

if (tolower(env_mode) == "production") {
  Sys.setenv(API_CONFIG = "sysndd_db")
} else if (tolower(env_mode) == "development") {
  Sys.setenv(API_CONFIG = "sysndd_db_dev")
} else {
  Sys.setenv(API_CONFIG = "sysndd_db_local")
}

dw <- config::get(Sys.getenv("API_CONFIG"))
if (is.list(dw$secret)) {
  dw$secret <- as.character(dw$secret[[1]])
}

if (!is.null(dw$workdir)) {
  message(paste("Setting working directory to:", dw$workdir))
  setwd(dw$workdir)
}

bootstrap_load_modules()

Sys.setenv(SYSNDD_RUNTIME = "mcp")
Sys.setenv(DB_POOL_SIZE = Sys.getenv("MCP_DB_POOL_SIZE", "2"))
pool <- bootstrap_create_pool(dw)
globals <- bootstrap_init_globals()

registry <- mcp_build_tool_registry(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text"))

mcptools::mcp_server(
  tools = registry$tools,
  type = "http",
  host = Sys.getenv("MCP_HOST", "0.0.0.0"),
  port = as.integer(Sys.getenv("MCP_PORT", "8787")),
  session_tools = FALSE
)
