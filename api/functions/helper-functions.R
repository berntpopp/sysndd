# functions/helper-functions.R
# Compatibility shim — loads the split helper modules when sourced standalone.
# Retained because pre-existing test files source this path directly. Some do so
# via a raw source(..., local = FALSE) that runs this file in globalenv, where
# the test helper get_api_dir() (defined in the child test environment) is NOT in
# scope. To work regardless of caller environment or working directory, resolve
# the sibling modules relative to THIS file's own directory.
# The actual implementations live in:
#   account-helpers.R, data-helpers.R, entity-helpers.R, response-helpers.R,
#   response-fields-helpers.R

if (!exists("random_password", mode = "function") ||
    !exists("generate_filter_expressions", mode = "function") ||
    !exists("select_tibble_fields", mode = "function") ||
    !exists("nest_gene_tibble", mode = "function") ||
    !exists("generate_panel_hash", mode = "function")) {
  # Derive this file's own directory from the active source() frame so the
  # sibling modules load no matter how (or from where) the shim was sourced.
  # Fall back to the get_api_dir() test helper, then to a CWD-relative path.
  .funcs_dir <- local({
    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
    if (length(ofiles) > 0) {
      dirname(normalizePath(ofiles[[length(ofiles)]]))
    } else {
      tryCatch(file.path(get_api_dir(), "functions"), error = function(e) "functions")
    }
  })
  for (.f in c("account-helpers.R", "data-helpers.R", "entity-helpers.R",
               "response-helpers.R", "response-fields-helpers.R")) {
    .p <- file.path(.funcs_dir, .f)
    if (file.exists(.p)) source(.p, local = FALSE)
  }
  rm(.funcs_dir, .f, .p)
}
