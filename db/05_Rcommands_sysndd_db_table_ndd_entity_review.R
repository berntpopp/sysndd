############################################
## load libraries
## to do: change to DBI/RMariaDB, have to automate connection using yml file
library(tidyverse)  ##needed for general table operations
library(jsonlite)  ##needed for HGNC requests
library(DBI)    ##needed for MySQL data export
library(RMariaDB)  ##needed for MySQL data export
library(sqlr)    ##needed for MySQL data export
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
## connect to the SysID source (issue #33: reproducible import)
## db_sysid_source_mode() selects "sqlite" (a local, reproducible snapshot —
## recommended) or "mysql" (the legacy upstream SysID DB over an SSH tunnel).
## See db/config/db_sysid_source.R and db/README.md "Reproducible SysID import".
sysid_mode <- db_sysid_source_mode(config_vars_proj)

if (sysid_mode == "mysql") {
  ## legacy path: open an SSH tunnel to the upstream SysID MySQL instance.
  cmd <- paste0('ssh::ssh_tunnel(ssh::ssh_connect(host = "',
    config_vars_proj$host_sysid,
    ', passwd = "',
    config_vars_proj$passwd_sysid,
    '"), port = ',
    config_vars_proj$port_sysid_local,
    ', target = "',
    config_vars_proj$server_sysid_local,
    ':',
    config_vars_proj$port_sysid_local,
    '")')

  pid <- sys::r_background(
      std_out = FALSE,
      std_err = FALSE,
      args = c("-e", cmd)
  )
}

## open a source-agnostic connection (SQLite snapshot or tunnelled MySQL)
sysid_db <- db_sysid_connect(config_vars_proj, mode = sysid_mode)
############################################



############################################
## SysID: load the diseases table from the local SysID database MySQL instance
sysid_db_disease <- tbl(sysid_db, "disease")
sysid_db_disease_collected <- sysid_db_disease %>%
  collect()
############################################



############################################
## SysID: load the human_gene_disease_connect table from the local SysID database MySQL instance
sysid_db_human_gene_disease_connect <- tbl(sysid_db, "human_gene_disease_connect")
human_gene_disease_connect_collected <- sysid_db_human_gene_disease_connect %>%
  collect() %>%
  select(entity_id = human_gene_disease_id, entry_date = date_of_entry)
############################################



############################################
## 
table_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

ndd_entity_review <- sysid_db_disease_collected %>%
  select(entity_id = human_gene_disease_id, synopsis = clinical_synopsis) %>%
  mutate(is_primary = TRUE) %>%
  mutate(review_user_id = 3) %>%
  mutate(review_approved = TRUE) %>%
  mutate(approving_user_id = 3) %>%
  mutate(comment = "") %>%
  left_join(human_gene_disease_connect_collected, by = c("entity_id")) %>%
  arrange(entity_id) %>%
  rownames_to_column(var = "review_id") %>%
  select(review_id, entity_id, synopsis, is_primary, review_date = entry_date, review_user_id, review_approved, approving_user_id, comment)

############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(ndd_entity_review, file = paste0("results/ndd_entity_review.",creation_date,".csv"))
############################################



############################################
## close database connection
rm_con()
############################################
