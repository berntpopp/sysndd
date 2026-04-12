# functions/helper-functions.R
# Compatibility shim — loads the split helper modules when sourced standalone.
# Retained because pre-existing test files source this path directly.
# The actual implementations live in:
#   account-helpers.R, data-helpers.R, entity-helpers.R, response-helpers.R

if (!exists("random_password", mode = "function") ||
    !exists("generate_filter_expressions", mode = "function") ||
    !exists("nest_gene_tibble", mode = "function") ||
    !exists("generate_panel_hash", mode = "function")) {
  # Use get_api_dir() (test helper) if available; fall back to relative path.
  .funcs_dir <- tryCatch(file.path(get_api_dir(), "functions"), error = function(e) "functions")
  for (.f in c("account-helpers.R", "data-helpers.R", "entity-helpers.R", "response-helpers.R")) {
    .p <- file.path(.funcs_dir, .f)
    if (file.exists(.p)) source(.p, local = FALSE)
  }
  rm(.funcs_dir, .f, .p)
}
