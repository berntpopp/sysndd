############################################
## 16_Rcommands_sysndd_db_pubtator_cache_table.R
##
## This script connects to the sysndd_db MariaDB database and creates
## three tables:
##   (1) pubtator_query_cache
##   (2) pubtator_search_cache
##   (3) pubtator_annotation_cache
## Additionally, it DROPs the old table `pubtator_cache` if it exists.
############################################

## load libraries
library(tidyverse)   ## needed for general table operations
library(DBI)         ## needed for MySQL data export
library(RMariaDB)    ## needed for MySQL data export
library(config)      ## needed to read config file

############################################
## define relative script path
project_topic <- "sysndd"
project_name <- "R"

## read configs
config_vars_proj <- config::get(file = Sys.getenv("CONFIG_FILE"), config = project_topic)

## set working directory
setwd(paste0(config_vars_proj$projectsdir, project_name))

## set global options
options(scipen = 999)

############################################
## connect to the database
sysndd_db <- dbConnect(
  RMariaDB::MariaDB(),
  dbname   = config_vars_proj$dbname_sysndd,
  user     = config_vars_proj$user_sysndd,
  password = config_vars_proj$password_sysndd,
  host     = config_vars_proj$server_sysid_sysndd, 
  port     = config_vars_proj$port_sysid_sysndd
)
############################################

############################################
## Drop old table 'pubtator_cache' if it exists
############################################
rs <- dbSendQuery(sysndd_db, "DROP TABLE IF EXISTS `pubtator_cache`;")
dbClearResult(rs)

############################################
## 1) Create pubtator_query_cache
##
## Holds the input query parameters and metadata:
##  - query_id (PK)
##  - query_text
##  - query_hash
##  - query_date
##  - page_number
##  - page_size
############################################
rs <- dbSendQuery(sysndd_db, "
  CREATE TABLE IF NOT EXISTS `pubtator_query_cache` (
    `query_id` INT AUTO_INCREMENT PRIMARY KEY,
    `query_text` TEXT NOT NULL,
    `query_hash` VARCHAR(64) NOT NULL,
    `query_date` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `total_page_number` INT NOT NULL,
    `queried_page_number` INT NOT NULL,
    `page_size` INT NOT NULL
  );
")
dbClearResult(rs)


############################################
## 2) Create pubtator_search_cache
##
## Holds data returned by pubtator_v3_pmids_from_request (columns:
##   id, pmid, doi, title, journal, date, score, text_hl).
## We store them in MySQL with typical column types (adjust as needed).
## Also references pubtator_query_cache.query_id
############################################
rs <- dbSendQuery(sysndd_db, "
  CREATE TABLE IF NOT EXISTS `pubtator_search_cache` (
    `search_id` INT AUTO_INCREMENT PRIMARY KEY,
    `query_id` INT NOT NULL,
    `id` VARCHAR(255),
    `pmid` INT,
    `doi` VARCHAR(255),
    `title` TEXT,
    `journal` VARCHAR(255),
    `date` DATE,
    `score` FLOAT,
    `text_hl` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX (pmid)
  );
")
dbClearResult(rs)


############################################
## 3) Create pubtator_annotation_cache
##
## Holds data returned by flatten_pubtator_passages. Example columns:
##   - annotation_id (PK)
##   - search_id (FK referencing pubtator_search_cache)
##   - pmid
##   - id (annotation 'id' from PubTator)
##   - text, identifier, type, ncbi_homologene, etc.
##   - created_at
############################################
rs <- dbSendQuery(sysndd_db, "
  CREATE TABLE IF NOT EXISTS `pubtator_annotation_cache` (
    `annotation_id` INT AUTO_INCREMENT PRIMARY KEY,

    -- Link back to pubtator_search_cache
    `search_id` INT NULL,

    `pmid` INT NOT NULL,
    `id` VARCHAR(255) NULL,
    `text` TEXT NULL,
    `identifier` VARCHAR(255) NULL,
    `type` VARCHAR(100) NULL,
    `ncbi_homologene` VARCHAR(50) NULL,
    `valid` TINYINT(1) NULL,
    `normalized` TEXT NULL,
    `database` VARCHAR(100) NULL,
    `normalized_id` VARCHAR(255) NULL,
    `biotype` VARCHAR(100) NULL,
    `name` TEXT NULL,
    `accession` VARCHAR(255) NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
")
dbClearResult(rs)

############################################
## close database connection
dbDisconnect(sysndd_db)
############################################

cat("All tables created/updated successfully.\n")
