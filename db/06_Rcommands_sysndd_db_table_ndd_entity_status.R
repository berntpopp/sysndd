############################################
## load libraries
## to do: change to DBI/RMariaDB, have to automate connection using yml file
library(tidyverse)  ##needed for general table operations
library(jsonlite)  ##needed for HGNC requests
library(DBI)    ##needed for MySQL data export
library(RMariaDB)  ##needed for MySQL data export
library(sqlr)    ##needed for MySQL data export
library(ssh)    ##needed for SSH connection to sysid database
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

ndd_entity_status_helper <- sysid_db_disease_collected %>%
  select(entity_id = human_gene_disease_id, category_id = gene_group_id, category = gene_group, sysid_yes_no) %>%
  mutate(is_active = TRUE) %>%
  mutate(status_user_id = 3) %>%
  left_join(human_gene_disease_connect_collected, by = c("entity_id")) %>%
  mutate(status_approved = TRUE) %>%
  mutate(approving_user_id = 3)

ndd_entity_status <- ndd_entity_status_helper %>%
  select(-category) %>%
  mutate(category_id = case_when(
    sysid_yes_no == 0 ~ 5, 
    category_id == 10 ~ 1, 
    category_id == 9 ~ 1, 
    category_id == 8 ~ 1, 
    category_id == 7 ~ 1, 
    category_id == 6 ~ 3)) %>%
  rownames_to_column(var = "status_id") %>%
  mutate(comment = "") %>%
  mutate(problematic = FALSE) %>%
  select(status_id, entity_id, category_id, is_active, status_date = entry_date, status_user_id, status_approved, approving_user_id, comment, problematic)

ndd_entity_status_categories_list <- ndd_entity_status_helper %>%
  select(category_id, category) %>%
  unique() %>%
  mutate(category = case_when(category == "Current primary ID genes" ~ "Definitive", 
    category == "ID data freeze 650" ~ "Definitive", 
    category == "ID data freeze 650" ~ "Definitive", 
    category == "ID data freeze 388" ~ "Definitive", 
    category == "ID candidate genes" ~ "Limited")) %>%
  mutate(category_id = case_when(category_id == 10 ~ 1, 
    category_id == 9 ~ 1, 
    category_id == 8 ~ 1, 
    category_id == 7 ~ 1, 
    category_id == 6 ~ 3)) %>%
  unique() %>%
  add_row(category_id = 2, category = "Moderate") %>%
  add_row(category_id = 4, category = "Refuted") %>%
  add_row(category_id = 5, category = "not applicable") %>%
  arrange(category_id)
############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(ndd_entity_status, file = paste0("results/ndd_entity_status.",creation_date,".csv"))
write_csv(ndd_entity_status_categories_list, file = paste0("results/ndd_entity_status_categories_list.",creation_date,".csv"))
############################################



############################################
## close database connection
rm_con()
############################################