# functions/helper-functions.R
# Compatibility shim — loads the split helper modules when sourced standalone.
# Retained because pre-existing test files source this path directly.
# The actual implementations live in:
#   account-helpers.R, data-helpers.R, entity-helpers.R, response-helpers.R

if (!exists("random_password", mode = "function")) {
  .dir <- if (file.exists("functions/account-helpers.R")) "functions" else dirname(sys.frame(1)$ofile)
  source(file.path(.dir, "account-helpers.R"), local = FALSE)
  source(file.path(.dir, "data-helpers.R"), local = FALSE)
  source(file.path(.dir, "entity-helpers.R"), local = FALSE)
  source(file.path(.dir, "response-helpers.R"), local = FALSE)
  rm(.dir)
}
