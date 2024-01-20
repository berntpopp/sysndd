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
##connect to online sysid database
## make ssh connection
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

## connect to the database
sysid_db <- dbConnect(RMariaDB::MariaDB(), dbname = config_vars_proj$dbname_sysid, user = config_vars_proj$user_sysid, password = config_vars_proj$password_sysid, server = config_vars_proj$server_sysid_local, port = config_vars_proj$port_sysid_local)
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
