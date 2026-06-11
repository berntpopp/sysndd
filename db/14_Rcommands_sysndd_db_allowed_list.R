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
## create a new allowed list table
table_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

inheritance_list <- tibble(value = c("X-linked", "Dominant", "Recessive", "Other", "All")) %>%
  mutate(type = "input") %>%
  mutate(analysis = "inheritance")

panels_list <- tibble(value = c("category", "inheritance", "symbol", "hgnc_id", "entrez_id", "ensembl_gene_id", "ucsc_id", "bed_hg19", "bed_hg38")) %>%
  mutate(type = "output") %>%
  mutate(analysis = "panels")

status_list <- tibble(value = c("Administrator", "Curator", "Reviewer", "Viewer")) %>%
  mutate(type = "input") %>%
  mutate(analysis = "user")

allowed_list <- inheritance_list %>%
  bind_rows(panels_list) %>%
  bind_rows(status_list) %>%
  rowid_to_column(var = "allowed_id") %>%
  select(allowed_id, type, analysis, value)

############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(allowed_list, file = paste0("results/allowed_list.",creation_date,".csv"),na = "")
############################################
