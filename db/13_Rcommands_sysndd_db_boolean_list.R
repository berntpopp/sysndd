############################################
## load libraries
library(tidyverse)  ##needed for general table operations
library(config)     ## needed to read config file
############################################


############################################
## SysNDD data-prep bootstrap (issue #33): locate db/config, then db_bootstrap()
## sets SYSNDD_DB_DIR, anchors CWD to db/, sources db_sysid_source.R, sets db_src.
.f <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
if (is.null(.f)) .f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.cfg <- if (nzchar(Sys.getenv("SYSNDD_DB_DIR"))) {
  file.path(Sys.getenv("SYSNDD_DB_DIR"), "config")
} else {
  file.path(dirname(normalizePath(.f[1])), "config")
}
source(file.path(.cfg, "db_config.R"))
config_vars_proj <- db_bootstrap()
############################################



############################################
##
table_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

boolean_list <- tibble(
    boolean_id = numeric(),
    boolean_number = numeric(),
    boolean_word = character(),
    word_english = character(),
    logical = logical(),
  ) %>%
  add_row(boolean_id = 1, boolean_number = 0, boolean_word = "false", word_english = "No", logical=FALSE) %>%
  add_row(boolean_id = 2, boolean_number = 1, boolean_word = "true", word_english = "Yes", logical=TRUE)

############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(boolean_list, file = paste0("results/boolean_list.",creation_date,".csv"),na = "")
############################################
