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
library(fuzzyjoin)  ## needed for regex_left_join
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
## SysID: load the diseases and human_gene table from the local SysID database MySQL instance
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
## define location of excel sheet with phenotype information
AccPhen_to_HPOterms_file_location <- "data/phenotypes/AccPhen_to_HPOterms_2022-04-12.xlsx"
############################################



############################################
## load the excel sheet for accompanying phenotype letter to HPO term conversion
AccPhen_to_HPOterms_file_sheet <- read_excel(AccPhen_to_HPOterms_file_location, sheet = "additional_class", na = "NA") %>%
  mutate(additional_class_id = na_if(additional_class_id, "0")) %>%
  mutate(search_terms = na_if(search_terms, "0")) %>%
  mutate(HPO_term_definition = na_if(HPO_term_definition, "0")) %>%
  mutate(HPO_term_synonyms = na_if(HPO_term_synonyms, "0"))

## 
accompanying_phenotype_d_letter <- sysid_db_disease_collected %>%
  select(additional_class_type_d) %>%
  mutate(additional_class_type_d = str_replace_all(additional_class_type_d, "\\s*", "")) %>%
  separate_rows(additional_class_type_d, sep = ",") %>%
  unique() %>%
  arrange(additional_class_type_d) %>%
  filter(additional_class_type_d != "") %>%
  mutate(has_bracket = str_detect(additional_class_type_d, "\\(")) %>%
  mutate(additional_class_type = str_remove_all(additional_class_type_d, "\\(|\\)"))

##
AccPhen_to_HPOterms_file_sheet_searchterms <- AccPhen_to_HPOterms_file_sheet %>%
  select(additional_class_type, additional_class_type_new, search_terms) %>%
  mutate(search_terms_in_additional_class_type_group = str_replace_all(search_terms, "; ", "\\|")) %>%
  select(-search_terms)
############################################



############################################
## load the excel sheet for main_class to ID_HPO_terms conversion
AccPhen_to_main_class_ID_HPO_terms_file_sheet <- read_excel(AccPhen_to_HPOterms_file_location, sheet = "main_class_ID_HPO_terms", na = "NA")

AccPhen_to_main_class_ID_HPO_terms_file_sheet_searchterms <- AccPhen_to_main_class_ID_HPO_terms_file_sheet %>%
  select(main_class_type, search_terms, HPO_term_identifier) %>%
  mutate(search_terms_in_main_class_type_group = str_replace_all(search_terms, "; ", "\\|"))
############################################


############################################
## split the additional_class_type_d column from sysid_db_disease_collected into separate rows 
## and join with AccPhen_to_HPOterms_file_sheet_searchterms for further searches and filtering
sysid_db_disease_collected_split_and_join_AccPhen_to_HPOterms <- sysid_db_disease_collected %>%
  mutate(additional_class_type_d = str_replace_all(additional_class_type_d, "\\s*", "")) %>%
  separate_rows(additional_class_type_d, sep = ",") %>%
  mutate(has_bracket = str_detect(additional_class_type_d, "\\(")) %>%
  mutate(additional_class_type = str_remove_all(additional_class_type_d, "\\(|\\)")) %>%
  mutate(clinical_synopsis_extended = paste(clinical_synopsis, disease_subtype, disease_type, inheritance_pattern, sep = "; ")) %>%
  mutate(clinical_synopsis_extended = str_to_lower(clinical_synopsis_extended)) %>%
  select(human_gene_disease_id, gene_symbol, gene_group, additional_class_type, has_bracket, clinical_synopsis_extended) %>%
  left_join(AccPhen_to_HPOterms_file_sheet_searchterms, by = c("additional_class_type")) %>%
  mutate(search_terms_in_additional_class_type_group_found = str_detect(clinical_synopsis_extended, search_terms_in_additional_class_type_group))


## filter the joined sysid_db_disease table with separated additional_class_type_d for terms that do not need to be separated
sysid_db_disease_collected_split_and_filter_class_type_through_search <- sysid_db_disease_collected_split_and_join_AccPhen_to_HPOterms %>%
  filter(additional_class_type != "" & additional_class_type == additional_class_type_new) %>%
  arrange(human_gene_disease_id, additional_class_type_new) %>%
  select(human_gene_disease_id, additional_class_type_new, has_bracket) %>%
  unique()


## use defined search terms to assign new additional_class_type_d for clinical terms which need to be separated
sysid_db_disease_collected_assign_new_additional_class_type_through_search <- sysid_db_disease_collected_split_and_join_AccPhen_to_HPOterms %>%
  filter(additional_class_type != "" & additional_class_type != additional_class_type_new & search_terms_in_additional_class_type_group_found) %>%
  arrange(human_gene_disease_id, additional_class_type_new) %>%
  select(human_gene_disease_id, additional_class_type_new, has_bracket) %>%
  unique()


## find all entries with "hearing loss", or other new phenotype classes using the search terms in clinical synopsis
sysid_db_entries_search_new_clinical_class <- sysid_db_disease_collected %>%
  mutate(additional_class_type_d = str_replace_all(additional_class_type_d, "\\s*", "")) %>%
  separate_rows(additional_class_type_d, sep = ",") %>%
  mutate(has_bracket = str_detect(additional_class_type_d, "\\(")) %>%
  mutate(additional_class_type = str_remove_all(additional_class_type_d, "\\(|\\)")) %>%
  mutate(clinical_synopsis = str_to_lower(clinical_synopsis)) %>%
  select(human_gene_disease_id, gene_group, additional_class_type, has_bracket, clinical_synopsis) %>%
  regex_left_join(AccPhen_to_HPOterms_file_sheet_searchterms, by = c("clinical_synopsis" = "search_terms_in_additional_class_type_group")) %>%
  mutate(search_terms_in_additional_class_type_group_found = str_detect(clinical_synopsis, search_terms_in_additional_class_type_group)) %>%
  filter(is.na(additional_class_type.y) & search_terms_in_additional_class_type_group_found) %>%
  select(human_gene_disease_id, additional_class_type_new, has_bracket) %>%
  unique()


## join into one table
ndd_review_phenotype_connect_additional_class_type_d <- sysid_db_disease_collected_split_and_filter_class_type_through_search %>%
  bind_rows(sysid_db_disease_collected_assign_new_additional_class_type_through_search) %>%
  bind_rows(sysid_db_entries_search_new_clinical_class) %>%
  mutate(HPO_term_modifier = case_when(
    has_bracket ~ "uncertain", 
    !has_bracket ~ "present")) %>%
  left_join(AccPhen_to_HPOterms_file_sheet, by = c("additional_class_type_new")) %>%
  select(human_gene_disease_id, HPO_term_identifier, HPO_term_modifier) %>%
  unique()
############################################



############################################
## 
sysid_db_disease_collected_split_and_join_AccPhen_to_main_class_ID_HPO_terms <- sysid_db_disease_collected %>%
  mutate(main_class_type = str_replace_all(main_class_type, "\\s*", "")) %>%
  separate_rows(main_class_type, sep = ",") %>%
  mutate(clinical_synopsis_extended = paste(clinical_synopsis, disease_subtype, disease_type, inheritance_pattern, sep = "; ")) %>%
  mutate(clinical_synopsis_extended = str_to_lower(clinical_synopsis_extended)) %>%
  select(human_gene_disease_id, gene_symbol, gene_group, main_class_type, clinical_synopsis_extended) %>%
  filter(!is.na(main_class_type)) %>%
  left_join(AccPhen_to_main_class_ID_HPO_terms_file_sheet_searchterms, by = c("main_class_type")) %>%
  mutate(search_terms_in_main_class_type_found = str_detect(clinical_synopsis_extended, search_terms_in_main_class_type_group))

## 
sysid_db_disease_collected_ID_assigned_through_search <- sysid_db_disease_collected_split_and_join_AccPhen_to_main_class_ID_HPO_terms %>%
  filter(search_terms_in_main_class_type_found) %>%
  arrange(human_gene_disease_id, main_class_type) %>%
  mutate(HPO_term_modifier_found = str_detect(clinical_synopsis_extended, "variable")) %>%
  unique() %>%
  mutate(HPO_term_modifier = case_when(
    main_class_type == "1" ~ "present", 
    main_class_type == "2" ~ "present", 
    main_class_type == "3" ~ "present", 
    main_class_type == "4" & !HPO_term_modifier_found ~ "present",
    main_class_type == "4" & HPO_term_modifier_found ~ "variable", 
    main_class_type == "5" & !HPO_term_modifier_found ~ "present",
    main_class_type == "5" & HPO_term_modifier_found ~ "variable", 
    main_class_type == "6" & !HPO_term_modifier_found ~ "present",
    main_class_type == "6" & HPO_term_modifier_found ~ "variable", 
    main_class_type == "7" ~ "rare", 
    main_class_type == "8a" ~ "rare", 
    main_class_type == "8b" ~ "variable", 
    main_class_type == "9" ~ "rare")) %>%
  select(human_gene_disease_id, HPO_term_identifier, HPO_term_modifier) %>%
  unique()

## 
sysid_db_disease_collected_ID_assigned_through_rules <- sysid_db_disease_collected_split_and_join_AccPhen_to_main_class_ID_HPO_terms %>%
  group_by(human_gene_disease_id, main_class_type) %>%
  select(human_gene_disease_id, main_class_type, search_terms_in_main_class_type_found) %>%
  mutate(search_terms_in_main_class_type_found = any(search_terms_in_main_class_type_found)) %>%
  ungroup() %>%
  unique() %>%
  filter(!search_terms_in_main_class_type_found) %>%
  arrange(main_class_type) %>%
  mutate(HPO_term_identifier = case_when(
    main_class_type == "1" ~ "HP:0010864; HP:0002342", 
    main_class_type == "2" ~ "HP:0010864; HP:0002342", 
    main_class_type == "3" ~ "HP:0010864; HP:0002342", 
    main_class_type == "4" ~ "HP:0002342; HP:0001256", 
    main_class_type == "5" ~ "HP:0002342; HP:0001256", 
    main_class_type == "6" ~ "HP:0002342; HP:0001256", 
    main_class_type == "7" ~ "HP:0001249", 
    main_class_type == "8a" ~ "HP:0001249", 
    main_class_type == "8b" ~ "HP:0001249", 
    main_class_type == "9" ~ "HP:0001249")) %>%
  mutate(HPO_term_modifier = case_when(
    main_class_type == "1" ~ "present", 
    main_class_type == "2" ~ "present", 
    main_class_type == "3" ~ "present", 
    main_class_type == "4" ~ "present", 
    main_class_type == "5" ~ "present", 
    main_class_type == "6" ~ "present", 
    main_class_type == "7" ~ "rare", 
    main_class_type == "8a" ~ "rare", 
    main_class_type == "8b" ~ "variable", 
    main_class_type == "9" ~ "rare")) %>%
  select(-search_terms_in_main_class_type_found) %>%
  separate_rows(HPO_term_identifier, sep = "; ") %>%
  select(human_gene_disease_id, HPO_term_identifier, HPO_term_modifier) %>%
  unique()

## assign general ID HPO term to sysid yes for candidates
## changed this to include all sysid yes on 2022-06-01 (removed "is.na(main_class_type) & " from filter)
sysid_db_disease_collected_ID_for_candidates_with_sysid_yes <- sysid_db_disease_collected %>%
  mutate(main_class_type = str_replace_all(main_class_type, "\\s*", "")) %>%
  separate_rows(main_class_type, sep = ",") %>%
  mutate(clinical_synopsis_extended = paste(clinical_synopsis, disease_subtype, disease_type, inheritance_pattern, sep = "; ")) %>%
  mutate(clinical_synopsis_extended = str_to_lower(clinical_synopsis_extended)) %>%
  select(human_gene_disease_id, gene_symbol, gene_group, main_class_type, clinical_synopsis_extended, sysid_yes_no) %>%
  filter(sysid_yes_no == 1) %>%
  mutate(HPO_term_identifier = "HP:0001249") %>%
  mutate(HPO_term_modifier = "present") %>%
  unique() %>%
  group_by(human_gene_disease_id, HPO_term_identifier) %>%
  mutate(HPO_term_modifier = max(HPO_term_modifier)) %>%
  ungroup() %>%
  unique() %>%
  select(human_gene_disease_id, HPO_term_identifier, HPO_term_modifier)

## join into one table
ndd_review_phenotype_connect_main_class_type <- sysid_db_disease_collected_ID_assigned_through_search %>%
  bind_rows(sysid_db_disease_collected_ID_assigned_through_rules) %>%
  bind_rows(sysid_db_disease_collected_ID_for_candidates_with_sysid_yes) %>%
  unique()
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
## join both phenotype tables into one
import_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

ndd_review_phenotype_connect <- ndd_review_phenotype_connect_additional_class_type_d %>%
  bind_rows(ndd_review_phenotype_connect_main_class_type) %>%
  unique() %>%
  arrange(human_gene_disease_id, HPO_term_identifier, HPO_term_modifier) %>%
  group_by(human_gene_disease_id, HPO_term_identifier) %>%
  mutate(HPO_term_modifier = first(HPO_term_modifier)) %>%
  ungroup() %>%
## this removes "Abnormality of the axial skeleton"
  mutate(HPO_term_identifier = str_replace(HPO_term_identifier, "HP:0009121", "HP:0000924")) %>%
  unique() %>%
  rownames_to_column(var = "review_phenotype_id") %>%
  left_join(human_gene_disease_connect_collected, by = c("human_gene_disease_id" = "entity_id")) %>%
  mutate(is_active = TRUE) %>%
  select(review_phenotype_id, phenotype_id = HPO_term_identifier, entity_id = human_gene_disease_id, modifier_name = HPO_term_modifier, phenotype_date = entry_date, is_active) %>%
  left_join(ndd_entity_review_ids, by = c("entity_id")) %>%
  select(review_phenotype_id, review_id, phenotype_id, entity_id, modifier_name, phenotype_date, is_active)

modifier_list <- ndd_review_phenotype_connect %>% 
  select(modifier_name) %>% 
  unique() %>%
  rownames_to_column(var = "modifier_id") %>%
  mutate(modifier_id = as.integer(modifier_id)) %>%
  add_row(modifier_id = 5, modifier_name = "absent") %>%
  mutate(allowed_phenotype = 1) %>%
  mutate(allowed_variation =   case_when(
    modifier_id == 1 ~ 1,
    modifier_id == 5 ~ 1, 
    TRUE ~ 0)
  ) %>%
  select(modifier_id, modifier_name, allowed_phenotype, allowed_variation)

ndd_review_phenotype_connect_modifier_id <- ndd_review_phenotype_connect %>%
  left_join(modifier_list, by = c("modifier_name")) %>%
  select(review_phenotype_id, review_id, phenotype_id, modifier_id, entity_id, phenotype_date, is_active)

############################################



############################################
## generate the phenotype_list table from the two excel sheets with this info used for the ndd_review_phenotype_connect previously
AccPhen_HPOterms <- AccPhen_to_HPOterms_file_sheet %>%
select(phenotype_id = HPO_term_identifier, HPO_term, HPO_term_definition, HPO_term_synonyms, comment)

ID_HPO_terms <- AccPhen_to_main_class_ID_HPO_terms_file_sheet %>%
select(phenotype_id = HPO_term_identifier, HPO_term, HPO_term_definition, HPO_term_synonyms, comment = IQ)

phenotype_list <- AccPhen_HPOterms %>%
  bind_rows(ID_HPO_terms) %>%
  unique() %>% 
  arrange(HPO_term) %>% 
## this removes "Abnormality of the axial skeleton"
  filter(!str_detect(phenotype_id, "HP:0009121"))
############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

write_csv(ndd_review_phenotype_connect_modifier_id, file = paste0("results/", "ndd_review_phenotype_connect.",creation_date,".csv"))
write_csv(phenotype_list, file = paste0("results/", "phenotype_list.",creation_date,".csv"))
write_csv(modifier_list, file = paste0("results/", "modifier_list.",creation_date,".csv"))
############################################



############################################
## close database connection
rm_con()
############################################