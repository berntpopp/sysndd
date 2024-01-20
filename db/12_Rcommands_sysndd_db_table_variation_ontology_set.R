############################################
## load libraries
library(tidyverse)    ##needed for general table operations
library(ontologyIndex)  ##needed for OBO operations
library(readxl)      ##needed for excel list with sorting
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
## load the excel file for sorting
sort_variation <- read_excel("data/lists/lists_2022-05-03.xlsx", 
    sheet = "variation_ontology_list") %>%
  arrange(sort, vario_id) %>%
  mutate(id = as.integer(row_number())) %>% 
  mutate(sort = as.integer(sort)) %>% 
  mutate(sort = case_when(
      is.na(sort) ~ id,
      !is.na(sort) ~ sort,
    )
  ) %>%
  mutate(use = case_when(
      use == 1 ~ TRUE,
      use == 0 ~ FALSE,
    )
  ) %>%
  select(vario_id, is_active = use, sort)
############################################



############################################
## download vario.obo file
file_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
vario_link <- "http://www.variationontology.org/vario_download/vario.obo"
vario_file <- "data/vario.obo"
download.file(vario_link, vario_file, mode = "wb")
############################################



############################################
## load and convert to tibble
vario <- get_ontology(vario_file, propagate_relationships = "is_a", extract_tags = "everything")

variation_ontology_list <- tibble(vario$id, vario$name, vario$def, vario$obsolete) %>%
  select(vario_id = `vario$id`, vario_name = `vario$name`, definition = `vario$def`, obsolete = `vario$obsolete`) %>%
  mutate(definition = str_remove(definition, " \\[VariO\\:mv\\]")) %>%
  mutate(definition = str_remove_all(definition, "\"")) %>%
  mutate(obsolete = as.logical(obsolete)) %>%
  left_join(sort_variation, by=c("vario_id")) %>%
  mutate(update_date = file_date) %>%
  filter(str_detect(vario_id, "VariO")) %>%
  select(vario_id, vario_name, definition, obsolete, is_active, sort, update_date)
############################################



############################################
## load precomputed ndd_entity_review csv table to merge review_id
ndd_entity_review_files <- list.files(path = "results/") %>%
  as_tibble() %>%
  filter(str_detect(value, "ndd_entity_review")) %>%
  mutate(date = str_split(value, "\\.", simplify = TRUE)[, 2]) %>%
  arrange(date)

ndd_entity_review_ids <- read_csv(paste0("results/", ndd_entity_review_files$value[1])) %>%
  select(review_id, entity_id)
############################################



############################################
## assign variation id VariO:0001 "variation" to all reviews
ndd_review_variation_ontology_connect <- ndd_entity_review_ids %>%
  mutate(vario_id = "VariO:0001") %>%
  mutate(is_active = TRUE) %>%
  mutate(modifier_id = 1) %>%
  mutate(variation_ontology_date = file_date) %>%
  rownames_to_column(var = "review_vario_id") %>%
  select(review_vario_id, review_id, vario_id, modifier_id, entity_id, variation_ontology_date, is_active)
############################################



############################################
## export table as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(variation_ontology_list, file = paste0("results/variation_ontology_list.",creation_date,".csv"))
write_csv(ndd_review_variation_ontology_connect, file = paste0("results/ndd_review_variation_ontology_connect.",creation_date,".csv"))
############################################