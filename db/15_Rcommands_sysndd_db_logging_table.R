############################################
## load libraries
library(tidyverse)  ## needed for general table operations
library(DBI)    ## needed for MySQL data export
library(RMariaDB)  ## needed for MySQL data export
library(config)     ## needed to read config file
############################################


############################################
## define relative script path
project_topic <- "sysndd"
project_name <- "R"

## read configs
config_vars_proj <- config::get(file = Sys.getenv("CONFIG_FILE"),
    config = project_topic)

## set working directory
setwd(paste0(config_vars_proj$projectsdir, project_name))

## set global options
options(scipen = 999)
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
## create logging table
rs <- dbSendQuery(sysndd_db, "
  CREATE TABLE IF NOT EXISTS `logging` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `timestamp` DATETIME NOT NULL,
    `address` VARCHAR(255) NOT NULL,
    `agent` TEXT,
    `host` VARCHAR(255),
    `request_method` VARCHAR(10),
    `path` TEXT,
    `query` TEXT,
    `post` TEXT,
    `status` INT,
    `duration` FLOAT,
    `file` VARCHAR(255),
    `modified` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  );")

dbClearResult(rs)
############################################


############################################
## close database connection
dbDisconnect(sysndd_db)
############################################
