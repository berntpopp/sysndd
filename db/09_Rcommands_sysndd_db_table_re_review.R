############################################
## load libraries
## to do: change to DBI/RMariaDB, have to automate connection using yml file
library(tidyverse)  ## needed for general table operations
library(jsonlite)   ## needed for HGNC requests
library(DBI)        ## needed for MySQL data export
library(RMariaDB)   ## needed for MySQL data export
library(sqlr)       ## needed for MySQL data export
library(readxl)     ## needed for excel import
library(ssh)        ## needed for SSH connection to sysid database

library(fuzzyjoin)  ## needed for fuzzy joins
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
## load precomputed ndd_entity and corresponding status and review csv table
ndd_entity_files <- list.files(path = "results/") %>%
  as_tibble() %>%
  filter(str_detect(value, "ndd_entity")) %>%
  mutate(date = str_split(value, "\\.", simplify = TRUE)[, 2]) %>%
  arrange(date)

ndd_entity <- read_csv(paste0("results/", ndd_entity_files$value[1]))
ndd_entity_review <- read_csv(paste0("results/", ndd_entity_files$value[2]))
ndd_entity_status <- read_csv(paste0("results/", ndd_entity_files$value[3]))
############################################


############################################
## for Zeynep Tümer
z_batch <- c("HGNC:2903", "HGNC:24713", "HGNC:25461", "HGNC:494", "ZFP142") %>%
  as_tibble() %>%
  mutate(z_batch = TRUE) %>%
  select(hgnc_id = value, z_batch)
############################################


############################################
## compute batches of genes for re-review into groups of 20
group_size <- 20

ndd_entity_hgnc_id_batch <- ndd_entity %>%
  arrange(entity_id) %>%
  select(hgnc_id) %>%
  unique() %>%
  mutate(re_review_batch = (row_number()-1) %/% group_size + 1) %>%
  left_join(z_batch, by = c("hgnc_id")) %>%
  mutate(re_review_batch = case_when(
      z_batch ~ 0,
      is.na(z_batch) ~ re_review_batch
    )) %>%
  select(-z_batch)
############################################



############################################
## make a tibble of user_ids and batches
re_review_assignment <- tibble(
    re_review_batch = numeric(),
    user_id = numeric()
  ) %>%
  add_row(user_id = 2, re_review_batch = 1) %>%
  add_row(user_id = 3, re_review_batch = 2) %>%
  add_row(user_id = 4, re_review_batch = 3) %>%
  add_row(user_id = 5, re_review_batch = 4) %>%
  add_row(user_id = 6, re_review_batch = 5) %>%
  add_row(user_id = 7, re_review_batch = 6) %>%
  add_row(user_id = 8, re_review_batch = 7) %>%
  add_row(user_id = 9, re_review_batch = 8) %>%
  add_row(user_id = 10, re_review_batch = 0) %>%
  add_row(user_id = 10, re_review_batch = 10) %>%
  arrange(user_id) %>%
  mutate(assignment_id = row_number()) %>%
  select(assignment_id, user_id, re_review_batch)
############################################



############################################
## join the batch list back to ndd_entity and add boolean flags for re_revied status
## plus new: add the initial status and review ids
re_review_entity_connect <- ndd_entity %>%
  left_join(ndd_entity_review, by = c("entity_id")) %>%
  left_join(ndd_entity_status, by = c("entity_id")) %>%
  left_join(ndd_entity_hgnc_id_batch, by = c("hgnc_id")) %>%
  select(entity_id, re_review_batch, status_id, review_id) %>%
  mutate(re_review_review_saved = FALSE) %>%
  mutate(re_review_status_saved = FALSE) %>%
  mutate(re_review_submitted = FALSE) %>%
  mutate(re_review_approved = FALSE) %>%
  mutate(approving_user_id = NA) %>%
  arrange(re_review_batch, entity_id) %>%
  mutate(re_review_entity_id = row_number()) %>%
  select(re_review_entity_id, entity_id, re_review_batch, re_review_review_saved, re_review_status_saved, re_review_submitted, re_review_approved, approving_user_id, status_id, review_id)
############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

write_csv(re_review_entity_connect, file = paste0("results/", "re_review_entity_connect.",creation_date,".csv"))
write_csv(re_review_assignment, file = paste0("results/", "re_review_assignment.",creation_date,".csv"))
############################################
