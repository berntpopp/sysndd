######################################################################
# start_sysndd_mcp.R
#
# Dedicated read-only MCP sidecar for approved public SysNDD data.
# This process does not mount Plumber endpoints, run migrations, start
# workers, call Gemini, or call external providers.
######################################################################

source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/load_modules.R", local = FALSE)
source("functions/mcp-readonly-config.R", local = FALSE)
source("bootstrap/create_mcp_pool.R", local = FALSE)
source("functions/mcp-readonly-attestation.R", local = FALSE)
source("functions/mcp-readonly-contract.R", local = FALSE)
source("bootstrap/init_globals.R", local = FALSE)

bootstrap_init_libraries()
Sys.setenv(SYSNDD_RUNTIME = "mcp")

config_fn <- base::get("mcp_readonly_config", envir = .GlobalEnv, mode = "function")
dw <- config_fn()

bootstrap_load_modules()
pool_fn <- base::get("bootstrap_create_mcp_pool", envir = .GlobalEnv, mode = "function")
pool <- pool_fn(dw)
if (!base::exists(
  "mcp_readonly_projection_names",
  envir = .GlobalEnv,
  mode = "function",
  inherits = FALSE
)) {
  stop("MCP projection contract is unavailable")
}
projection_names_fn <- base::get(
  "mcp_readonly_projection_names",
  envir = .GlobalEnv,
  mode = "function"
)
attest_fn <- base::get("mcp_readonly_attest", envir = .GlobalEnv, mode = "function")
tryCatch(
  attest_fn(
    conn = pool,
    dbname = dw$dbname,
    projection_names = projection_names_fn()
  ),
  error = function(e) {
    try(pool::poolClose(pool), silent = TRUE)
    stop(e)
  }
)
globals <- bootstrap_init_globals()

registry <- mcp_build_tool_registry(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text"))
mcp_patch_mcptools_protocol(registry = registry, instructions = mcp_server_instructions())

mcptools::mcp_server(
  tools = registry$tools,
  type = "http",
  host = Sys.getenv("MCP_HOST", "0.0.0.0"),
  port = as.integer(Sys.getenv("MCP_PORT", "8787")),
  session_tools = FALSE
)
