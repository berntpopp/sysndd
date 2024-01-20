############################################
## load libraries
library(tidyverse)  ##needed for general table operations
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
