############################################
## load libraries
library(tidyverse)  ## needed for general table operations
library(DBI)    ## needed for MySQL data export
library(RMariaDB)  ## needed for MySQL data export
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
## connect to the database
sysndd_db <- dbConnect(RMariaDB::MariaDB(),
  dbname = config_vars_proj$dbname_sysndd,
  user = config_vars_proj$user_sysndd,
  password = config_vars_proj$password_sysndd,
  server = config_vars_proj$server_sysid_sysndd,
  port = config_vars_proj$port_sysid_sysndd)
############################################


############################################
## create json_storage table
rs <- dbSendQuery(sysndd_db, "
  CREATE TABLE IF NOT EXISTS `json_storage` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL,
    `json_data` JSON NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  );")

dbClearResult(rs)
############################################


############################################
## close database connection
dbDisconnect(sysndd_db)
############################################
