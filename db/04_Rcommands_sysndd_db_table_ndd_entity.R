############################################
## load libraries
## to do: change to DBI/RMariaDB, have to automate connection using yml file
library(tidyverse)  ##needed for general table operations
library(jsonlite)  ##needed for HGNC requests
library(DBI)    ##needed for MySQL data export
library(RMariaDB)  ##needed for MySQL data export
library(sqlr)    ##needed for MySQL data export
library(ssh)    ##needed for SSh connection to sysid database
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
## define functions

hgnc_id_from_prevsymbol <- function(symbol_input)  {
  symbol_request <- fromJSON(paste0("http://rest.genenames.org/search/prev_symbol/", symbol_input))

  hgnc_id_from_symbol <- as_tibble(symbol_request$response$docs)
  
  hgnc_id_from_symbol <- hgnc_id_from_symbol %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_symbol)) hgnc_id else NA) %>%
  mutate(symbol = if (exists('symbol', where = hgnc_id_from_symbol)) symbol else "") %>%
  mutate(score = if (exists('score', where = hgnc_id_from_symbol)) score else 0) %>%
  arrange(desc(score)) %>%
  mutate(hgnc_id = as.integer(str_split_fixed(hgnc_id, ":", 2)[, 2]))

  return(as.integer(hgnc_id_from_symbol$hgnc_id[1]))
}

hgnc_id_from_aliassymbol <- function(symbol_input)  {
  symbol_request <- fromJSON(paste0("http://rest.genenames.org/search/alias_symbol/", symbol_input))

  hgnc_id_from_symbol <- as_tibble(symbol_request$response$docs)
  
  hgnc_id_from_symbol <- hgnc_id_from_symbol %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_symbol)) hgnc_id else NA) %>%
  mutate(symbol = if (exists('symbol', where = hgnc_id_from_symbol)) symbol else "") %>%
  mutate(score = if (exists('score', where = hgnc_id_from_symbol)) score else 0) %>%
  arrange(desc(score)) %>%
  mutate(hgnc_id = as.integer(str_split_fixed(hgnc_id, ":", 2)[, 2]))

  return(as.integer(hgnc_id_from_symbol$hgnc_id[1]))
}

hgnc_id_from_symbol <- function(symbol_tibble) {
  symbol_list_tibble <- as_tibble(symbol_tibble) %>% select(symbol = value) %>% mutate(symbol = toupper(symbol))
  
  symbol_request <- fromJSON(paste0("http://rest.genenames.org/search/symbol/", str_c(symbol_list_tibble$symbol, collapse = "+OR+")))

  hgnc_id_from_symbol <- as_tibble(symbol_request$response$docs)
  
  hgnc_id_from_symbol <- hgnc_id_from_symbol %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_symbol)) hgnc_id else NA) %>%
  mutate(symbol = if (exists('symbol', where = hgnc_id_from_symbol)) toupper(symbol) else "") %>%
  mutate(hgnc_id = as.integer(str_split_fixed(hgnc_id, ":", 2)[, 2]))
    
  return_tibble <- symbol_list_tibble %>% 
  left_join(hgnc_id_from_symbol, by = "symbol") %>%
  select(hgnc_id)

  return(return_tibble)
}


symbol_from_hgnc_id <- function(hgnc_id_tibble) {
  hgnc_id_list_tibble <- as_tibble(hgnc_id_tibble) %>% 
    select(hgnc_id = value) %>%
    mutate(hgnc_id = as.integer(hgnc_id))
  
  hgnc_id_request <- fromJSON(paste0("http://rest.genenames.org/search/hgnc_id/", str_c(hgnc_id_list_tibble$hgnc_id, collapse = "+OR+")))

  hgnc_id_from_hgnc_id <- as_tibble(hgnc_id_request$response$docs)
  
  hgnc_id_from_hgnc_id <- hgnc_id_from_hgnc_id %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_hgnc_id)) hgnc_id else NA) %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_hgnc_id)) toupper(hgnc_id) else "") %>%
  mutate(hgnc_id = as.integer(str_split_fixed(hgnc_id, ":", 2)[, 2]))
    
  return_tibble <- hgnc_id_list_tibble %>% 
  left_join(hgnc_id_from_hgnc_id, by = "hgnc_id") %>%
  select(symbol)

  return(return_tibble)
}


hgnc_id_from_symbol_grouped <- function(input_tibble, request_max = 150) {
  input_tibble <- as_tibble(input_tibble)
  
  row_number <- nrow(input_tibble)
  groups_number <- ceiling(row_number/request_max)
  
  input_tibble_request <- input_tibble %>%
    mutate(group = sample(1:groups_number, row_number, replace=T)) %>%
    group_by(group) %>%
    mutate(response = hgnc_id_from_symbol(value)$hgnc_id) %>%
    ungroup()
  
  input_tibble_request_repair <- input_tibble_request %>%
    filter(is.na(response)) %>%
    select(value) %>%
    unique() %>%
    rowwise() %>%
    mutate(response = hgnc_id_from_prevsymbol(value)) %>%
    mutate(response = case_when(!is.na(response) ~ response, is.na(response) ~ hgnc_id_from_aliassymbol(value)))
  
  input_tibble_request <- input_tibble_request %>%
    left_join(input_tibble_request_repair, by = "value") %>%
    mutate(response = case_when(!is.na(response.x) ~ response.x, is.na(response.x) ~ response.y))
  
  return(input_tibble_request$response)
}


## HPO functions
## to do: make this recursive and independent of global variable

HPO_name_from_term <- function(term_input_id) {
  hpo_term_response <- fromJSON(paste0("https://hpo.jax.org/api/hpo/term/", URLencode(term_input_id, reserved=T)))
  hpo_term_name <- as_tibble(hpo_term_response$details$name) %>%
  select(hpo_mode_of_inheritance_term_name = value)

  return(hpo_term_name)
}


HPO_definition_from_term <- function(term_input_id) {
  hpo_term_response <- fromJSON(paste0("https://hpo.jax.org/api/hpo/term/", URLencode(term_input_id, reserved=T)))
  hpo_term_definition <- as_tibble(hpo_term_response$details$definition) %>%
  select(hpo_mode_of_inheritance_term_definition = value)

  return(hpo_term_definition)
}


HPO_children_count_from_term <- function(term_input_id) {
  hpo_term_response <- fromJSON(paste0("https://hpo.jax.org/api/hpo/term/", URLencode(term_input_id, reserved=T)))
  hpo_term_children_count <- as_tibble(hpo_term_response$relations$children)

  return(length(hpo_term_children_count))
}


HPO_children_from_term <- function(term_input_id) {
  hpo_term_response <- fromJSON(paste0("https://hpo.jax.org/api/hpo/term/", URLencode(term_input_id, reserved=T)))
  hpo_term_children <- as_tibble(hpo_term_response$relations$children)

  return(hpo_term_children)
}

HPO_all_children_from_term <- function(term_input) {

  children_list <- HPO_children_from_term(term_input)
  all_children_list <<- append(all_children_list, term_input)

  if(length(children_list)!=0)
  {
    for (p in children_list$ontologyId) {
        all_children_list <<- append(all_children_list, p)
        Recall(p)
    }
  }
  all_children_tibble <- as_tibble(unlist(all_children_list)) %>% unique
  
  return(all_children_tibble)
}

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
## SysID: load the diseases table from the SysID database MySQL instance
sysid_db_disease <- tbl(sysid_db, "disease")
sysid_db_disease_collected <- sysid_db_disease %>%
  collect()
############################################



############################################
## SysID: load the human_gene_disease_connect table from the SysID database MySQL instance
sysid_db_human_gene_disease_connect <- tbl(sysid_db, "human_gene_disease_connect")
human_gene_disease_connect_collected <- sysid_db_human_gene_disease_connect %>%
  collect() %>%
  select(entity_id = human_gene_disease_id, entry_date = date_of_entry)
############################################



############################################
## get inheritance modes from HPO by finding all children of term HP:0000005 and annotating them with name and definition. 
## Activity state is defined by the term having no children.

all_children_list <- list()
HPO_all_children_from_term("HP:0000005")

mode_of_inheritance_list <- all_children_list %>%
  unlist() %>%
  as_tibble() %>%
  unique() %>%
  select(hpo_mode_of_inheritance_term = value) %>%
  mutate(hpo_mode_of_inheritance_id = row_number()) %>%
  rowwise() %>%
  mutate(hpo_mode_of_inheritance_term_name = HPO_name_from_term(hpo_mode_of_inheritance_term)$hpo_mode_of_inheritance_term_name) %>%
  mutate(hpo_mode_of_inheritance_term_definition = HPO_definition_from_term(hpo_mode_of_inheritance_term)$hpo_mode_of_inheritance_term_definition) %>%
  mutate(children_count = HPO_children_count_from_term(hpo_mode_of_inheritance_term)) %>%
  mutate(is_active = case_when(children_count == 0 ~ TRUE, children_count > 0 ~ FALSE)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term == "HP:0001417" ~ TRUE, hpo_mode_of_inheritance_term != "HP:0001417" ~ is_active)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term_definition == "" ~ FALSE, hpo_mode_of_inheritance_term_definition != "" ~ is_active)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term == "HP:0000007" ~ TRUE, hpo_mode_of_inheritance_term != "HP:0000007" ~ is_active)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term == "HP:0000006" ~ TRUE, hpo_mode_of_inheritance_term != "HP:0000006" ~ is_active)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term == "HP:0001428" ~ TRUE, hpo_mode_of_inheritance_term != "HP:0001428" ~ is_active)) %>%
  select(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name, hpo_mode_of_inheritance_term_definition, is_active) %>%
  ungroup()
############################################



############################################
## download all OMIM files
omim_file_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

omim_links <- as_tibble(read_lines("data/omim_links/omim_links.txt")) %>%
  mutate(file_name = str_remove(value, "https.+\\/")) %>%
  mutate(file_name = str_remove(file_name, "\\.txt")) %>%
  mutate(file_name = paste0("data/", file_name, ".", omim_file_date, ".txt"))

for (row in 1:nrow(omim_links)) {
  download.file(omim_links$value[row], omim_links$file_name[row], mode = "wb")
}
############################################



############################################
## load and reformat the OMIM tables
mim2gene <- read_delim(omim_links$file_name[1], "\t", escape_double = FALSE, col_names = FALSE, comment = "#", trim_ws = TRUE) %>%
  select(MIM_Number = X1,  MIM_Entry_Type = X2, Entrez_Gene_ID = X3, Approved_Gene_Symbol_HGNC = X4, Ensembl_Gene_ID = X5) %>%
  mutate(omim_id = paste0("OMIM:",MIM_Number)) %>%
  select(-MIM_Number, -Entrez_Gene_ID, -Ensembl_Gene_ID)

mim2gene_hgnc <- mim2gene %>%
  filter(!is.na(Approved_Gene_Symbol_HGNC)) %>%
  unique() %>%
  mutate(hgnc_id = paste0("HGNC:",hgnc_id_from_symbol_grouped(Approved_Gene_Symbol_HGNC)))
  
mimTitles <- read_delim(omim_links$file_name[2], "\t", escape_double = FALSE, col_names = FALSE, comment = "#", trim_ws = TRUE) %>%
  select(Prefix = X1,  MIM_Number = X2, Preferred_Title_symbol = X3, Alternative_Titles_symbols = X4, Included_Titles_symbols = X5) %>%
  mutate(omim_id = paste0("OMIM:",MIM_Number)) %>%
  select(-MIM_Number)

genemap2 <- read_delim(omim_links$file_name[3], "\t", escape_double = FALSE, col_names = FALSE, comment = "#", trim_ws = TRUE) %>%
  select(Chromosome = X1,  Genomic_Position_Start = X2, Genomic_Position_End = X3, Cyto_Location = X4, Computed_Cyto_Location = X5, MIM_Number = X6, Gene_Symbols = X7, Gene_Name = X8, Approved_Symbol = X9, Entrez_Gene_ID = X10, Ensembl_Gene_ID = X11, Comments = X12, Phenotypes = X13, Mouse_Gene_Symbol_ID = X14)

genemap2_hgnc <- genemap2 %>%
  filter(!is.na(Phenotypes) & !is.na(Approved_Symbol)) %>%
  select(Approved_Symbol, Phenotypes) %>%
  mutate(hgnc_id = paste0("HGNC:", hgnc_id_from_symbol_grouped(Approved_Symbol))) %>%
  separate_rows(Phenotypes, sep = "; ") %>%
  separate(Phenotypes, c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"), "\\), (?!.+\\))") %>%
  separate(disease_ontology_name, c("disease_ontology_name", "Mapping_key"), "\\((?!.+\\()") %>%
  mutate(Mapping_key = str_replace_all(Mapping_key, "\\)", "")) %>%
  separate(disease_ontology_name, c("disease_ontology_name", "MIM_Number"), ", (?=[0-9][0-9][0-9][0-9][0-9][0-9])") %>%
  mutate(Mapping_key = str_replace_all(Mapping_key, " ", "")) %>%
  mutate(MIM_Number = str_replace_all(MIM_Number, " ", "")) %>%
  filter(!is.na(MIM_Number))  %>%
  mutate(disease_ontology_id = paste0("OMIM:",MIM_Number)) %>%
  separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%
  mutate(hpo_mode_of_inheritance_term_name = str_replace_all(hpo_mode_of_inheritance_term_name, "\\?", "")) %>%
  select(-MIM_Number) %>%
  unique() %>%
  mutate(hpo_mode_of_inheritance_term_name = case_when(hpo_mode_of_inheritance_term_name == "Autosomal dominant" ~ "Autosomal dominant inheritance", 
    hpo_mode_of_inheritance_term_name == "Autosomal recessive" ~ "Autosomal recessive inheritance", 
    hpo_mode_of_inheritance_term_name == "Digenic dominant" ~ "Digenic inheritance", 
    hpo_mode_of_inheritance_term_name == "Digenic recessive" ~ "Digenic inheritance", 
    hpo_mode_of_inheritance_term_name == "Isolated cases" ~ "Sporadic", 
    hpo_mode_of_inheritance_term_name == "Mitochondrial" ~ "Mitochondrial inheritance", 
    hpo_mode_of_inheritance_term_name == "Multifactorial" ~ "Multifactorial inheritance", 
    hpo_mode_of_inheritance_term_name == "Pseudoautosomal dominant" ~ "X-linked dominant inheritance", 
    hpo_mode_of_inheritance_term_name == "Pseudoautosomal recessive" ~ "X-linked recessive inheritance", 
    hpo_mode_of_inheritance_term_name == "Somatic mosaicism" ~ "Somatic mosaicism", 
    hpo_mode_of_inheritance_term_name == "Somatic mutation" ~ "Somatic mutation", 
    hpo_mode_of_inheritance_term_name == "X-linked" ~ "X-linked inheritance", 
    hpo_mode_of_inheritance_term_name == "X-linked dominant" ~ "X-linked dominant inheritance", 
    hpo_mode_of_inheritance_term_name == "X-linked recessive" ~ "X-linked recessive inheritance", 
    hpo_mode_of_inheritance_term_name == "Y-linked" ~ "Y-linked inheritance")) %>%
  left_join(mode_of_inheritance_list, by=c("hpo_mode_of_inheritance_term_name")) %>%
  select(disease_ontology_id, hgnc_id, disease_ontology_name, hpo_mode_of_inheritance_term) %>%
  arrange(disease_ontology_id, hgnc_id, disease_ontology_name, hpo_mode_of_inheritance_term) %>%
  group_by(disease_ontology_id) %>%
  mutate(n = 1) %>%
  mutate(count = n()) %>%
  mutate(version = cumsum(n)) %>%
  ungroup() %>%
  mutate(disease_ontology_id_version = case_when(count == 1 ~ disease_ontology_id, count >= 1 ~ paste0(disease_ontology_id, "_", version))) %>%
  mutate(disease_ontology_source = "morbidmap") %>%
  mutate(disease_ontology_date = omim_file_date) %>%
  mutate(disease_ontology_is_specific = TRUE) %>%
  select(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, disease_ontology_source, disease_ontology_date, disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term)

############################################



############################################
## load the MONDO term file
mondo_file <- "data/mondo_terms/mondo_terms.txt"
mondo_terms <- read_delim(mondo_file, "\t", col_names = TRUE) %>%
  mutate(disease_ontology_source = "mondo") %>%
  mutate(disease_ontology_date = omim_file_date) %>%
  mutate(disease_ontology_is_specific = FALSE) %>%
  mutate(hgnc_id = NA) %>%
  mutate(hpo_mode_of_inheritance_term = NA) %>%
  mutate(disease_ontology_id_version = disease_ontology_id) %>%
  select(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, disease_ontology_source, disease_ontology_date, disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term)
############################################



############################################
## bind the OMIM and MONDO tables
ontology_set <- bind_rows(genemap2_hgnc, mondo_terms) %>%
  mutate(is_active = TRUE) 
############################################




############################################
## create a subtable for all inheritance modes in sysid and map them to the respective HPO terms
sysid_db_disease_inheritance <- sysid_db_disease_collected %>%
  select(inheritance_pattern, inheritance_type) %>%
  mutate(mode_of_inheritance = paste0(inheritance_pattern, " ", inheritance_type)) %>%
  select(-inheritance_pattern, -inheritance_type) %>%
  group_by(mode_of_inheritance) %>%
  tally() %>%
  mutate(hpo_mode_of_inheritance_term = case_when(mode_of_inheritance == "Mendelian autosomal dominant" ~ "HP:0000006", 
    mode_of_inheritance == "Mendelian autosomal recessive" ~ "HP:0000007", 
    mode_of_inheritance == "Mendelian X-linked dominant" ~ "HP:0001423", 
    mode_of_inheritance == "Mendelian X-linked recessive" ~ "HP:0001419", 
    mode_of_inheritance == "Mitochondrial N/A" ~ "HP:0001427", 
    mode_of_inheritance == "Somatic N/A" ~ "HP:0001428", 
    mode_of_inheritance == "Mendelian X-linked not sure" ~ "HP:0001417", 
    mode_of_inheritance == "Mendelian autosomal not sure" ~ "HP:0032113", 
    mode_of_inheritance == "Unknown N/A" ~ "HP:0001423" )) %>%
  mutate(inheritance_has_problem = case_when(!is.na(hpo_mode_of_inheritance_term) ~ FALSE, is.na(hpo_mode_of_inheritance_term) ~ TRUE)) %>%
  select(-n, -inheritance_has_problem)
############################################



############################################
## find disease_subtype without omim identifier and count them for reclassification to MONDO
sysid_db_disease_disease_subtype_no_omim <- sysid_db_disease_collected %>%
  filter(is.na(omim_disease) | omim_disease == 0) %>%
  select(disease_subtype, omim_disease) %>%
  group_by(disease_subtype) %>%
  tally() %>%
  mutate(group = case_when(disease_subtype == "Developmental Disorder" ~ "intellectual disability", 
    disease_subtype == "intellectual disability" ~ "intellectual disability", 
    disease_subtype == "non-syndromic ID" ~ "intellectual disability", 
    disease_subtype == "ID" ~ "intellectual disability", 
    disease_subtype == "syndromic ID" ~ "intellectual disability", 
    disease_subtype == "ID and microcephaly" ~ "intellectual disability", 
    disease_subtype == "ID and epilepsy" ~ "intellectual disability", 
    disease_subtype == "ID/DD, ASD" ~ "intellectual disability", 
    disease_subtype == "ASD, ID" ~ "intellectual disability", 
    disease_subtype == "ID, cataract" ~ "intellectual disability", 
    disease_subtype == "ID, microcephaly" ~ "intellectual disability", 
    disease_subtype == "infantile neurodegeneration" ~ "intellectual disability", 
    disease_subtype == "intellectual disability and schizophrenia" ~ "intellectual disability", 
    disease_subtype == "non syndromic ID" ~ "intellectual disability", 
    disease_subtype == "ID with ataxia" ~ "intellectual disability", 
    disease_subtype == "ID with microcephaly and spasticity" ~ "intellectual disability", 
    disease_subtype == "ID, epilepsy, muscular weakness" ~ "intellectual disability", 
    disease_subtype == "severe ID" ~ "intellectual disability",
    disease_subtype == "UNSPECIFIC ID AND AUTISM" ~ "intellectual disability", 
    disease_subtype == "ID/Epilepsy" ~ "intellectual disability", 
    disease_subtype == "learning problems" ~ "intellectual disability",     
    disease_subtype == "autism" ~ "autism spectrum disorder", 
    disease_subtype == "autism spectrum disorder" ~ "autism spectrum disorder", 
    disease_subtype == "ASD" ~ "autism spectrum disorder", 
    disease_subtype == "ASD/AUTISM" ~ "autism spectrum disorder", 
    disease_subtype == "epileptic encephalopathy" ~ "developmental and epileptic encephalopathy", 
    disease_subtype == "developmental and epileptic encephalopathy" ~ "developmental and epileptic encephalopathy",
    disease_subtype == "encephalopathy" ~ "developmental and epileptic encephalopathy", 
    disease_subtype == "epileptic encephalpathy" ~ "developmental and epileptic encephalopathy", 
    disease_subtype == "ENCEPHALOPATHY, PROGRESSIVE MITOCHONDRIAL, WITH PROXIMAL RENAL TUBULOPATHY DUE TO CYTOCHROME C OXIDASE DEFICIENCY" ~ "developmental and epileptic encephalopathy", 
    disease_subtype == "infantile myoclonic epilepsy and neurodegeneration" ~ "developmental and epileptic encephalopathy",
    disease_subtype == "mitochondrial disorder" ~ "mitochondrial disease", 
    disease_subtype == "MITOCHONDRIAL COMPLEX IV DEFICIENCY" ~ "mitochondrial disease", 
    disease_subtype == "MELAS SYNDROME" ~ "mitochondrial disease", 
    disease_subtype == "CYTOCHROME C OXIDASE DEFICIENCY" ~ "mitochondrial disease", 
    disease_subtype == "CYTOCHROME C OXIDASE I DEFICIENCY" ~ "mitochondrial disease", 
    disease_subtype == "LEBER HEREDITARY OPTICUS NEUROPATHY, LHON" ~ "mitochondrial disease", 
    disease_subtype == "LEIGH SYNDROME DUE TO MITOCHONDRIAL COMPLEX I DEFICIENCY" ~ "mitochondrial disease", 
    disease_subtype == "LEUKODYSTROPHY AND ISOLATED MITOCHONDRIAL COMPLEX II DEFICIENCY" ~ "mitochondrial disease", 
    disease_subtype == "MELAS" ~ "mitochondrial disease", 
    disease_subtype == "MERFF SYNDROME" ~ "mitochondrial disease", 
    disease_subtype == "MITOCHONDRIAL COMPLEX IV DEFICIENCY, COX DEFICIENCY" ~ "mitochondrial disease",
    disease_subtype == "complex IV deficiency" ~ "mitochondrial disease",
    disease_subtype == "Leukodystrophy" ~ "leukodystrophy",
    disease_subtype == "neurodegeneration" ~ "leukodystrophy",
    disease_subtype == "neurodegeneration with brain iron accumulation" ~ "leukodystrophy",
    disease_subtype == "INCLUSION BODY MYOPATHY WITH EARLY-ONSET PAGET DISEASE WITH OR WITHOUT FRONTOTEMPORAL DEMENTIA 1; IBMPFD1" ~ "leukodystrophy",
    disease_subtype == "brain malformation" ~ "central nervous system malformation",
    disease_subtype == "primary microcephaly" ~ "central nervous system malformation",
    disease_subtype == "holoprosencephaly" ~ "central nervous system malformation",
    disease_subtype == "Lissencephaly" ~ "central nervous system malformation",
    disease_subtype == "microlissencephaly" ~ "central nervous system malformation",
    disease_subtype == "periventricular heterotopia" ~ "central nervous system malformation",
    disease_subtype == "malformation of cortical development" ~ "central nervous system malformation",
    disease_subtype == "pontocerebellar hypoplasia" ~ "central nervous system malformation",
    disease_subtype == "POROKERATOSIS 3, DISSEMINATED SUPERFICIAL ACTINIC TYPE; POROK3" ~ "central nervous system malformation",
    disease_subtype == "multiple malformations and anomalies" ~ "syndromic disease",
    disease_subtype == "anomalies" ~ "syndromic disease",
    disease_subtype == "Noonan syndrome" ~ "syndromic disease",
    disease_subtype == "orofaciodigital syndrome" ~ "syndromic disease",
    disease_subtype == "Ramon syndrome" ~ "syndromic disease",
    disease_subtype == "Shwachman-Diamond-like syndrome" ~ "syndromic disease",
    disease_subtype == "Blepharophimosis-intellectual disability syndrome" ~ "syndromic disease",
    disease_subtype == "Braddock-Carey syndrome" ~ "syndromic disease",
    disease_subtype == "Lowry-Wood syndrome" ~ "syndromic disease",
    disease_subtype == "MENTAL RETARDATION, DEAFNESS, ANKYLOSIS, AND MILD HYPOPHOSPHATEMIA" ~ "syndromic disease",
    disease_subtype == "NAA10 deficiency" ~ "syndromic disease",
    disease_subtype == "Baratela-Scott syndrome" ~ "syndromic disease",
    disease_subtype == "ciliopathy" ~ "syndromic disease",
    disease_subtype == "Joubert syndrome" ~ "syndromic disease",
    disease_subtype == "KFA, myopathy, mild short stature, microcephaly, and distinctive facies" ~ "syndromic disease",
    disease_subtype == "spondylometaphyseal dypslasia" ~ "syndromic disease",
    disease_subtype == "skeletal dysplasia" ~ "syndromic disease",
    disease_subtype == "osteosclerotic metaphyseal dysplasia" ~ "syndromic disease",
    disease_subtype == "Encephalocraniocutaneous Lipomatosis" ~ "syndromic disease",
    disease_subtype == "cerebellar ataxia" ~ "nervous system disorder",
    disease_subtype == "ocular motor apraxia" ~ "nervous system disorder",
    disease_subtype == "optic nerve atrophy" ~ "nervous system disorder",
    disease_subtype == "optic atrophy" ~ "nervous system disorder",
    disease_subtype == "NONSYNDROMIC HEARING LOSS" ~ "nervous system disorder",
    disease_subtype == "Nocturnal frontal lobe epilepsy (NFLE)" ~ "nervous system disorder",
    disease_subtype == "HEREDITARY HYPEREKPLEXIA" ~ "nervous system disorder",
    disease_subtype == "neuromuscular disorder" ~ "neuromuscular disease",
    disease_subtype == "muscle disorder" ~ "neuromuscular disease",
    disease_subtype == "spastic paraplegia" ~ "neuromuscular disease",
    disease_subtype == "myopathy" ~ "neuromuscular disease",
    disease_subtype == "dystonia" ~ "neuromuscular disease",
    disease_subtype == "congenital disorder of glycosylation" ~ "metabolic disease",
    disease_subtype == "hyperinsulinemic hypoglycemia" ~ "metabolic disease",
    disease_subtype == "lipodystrophy" ~ "metabolic disease",
    disease_subtype == "Cobalamin disorder" ~ "metabolic disease",
    disease_subtype == "ACOX2-deficiency" ~ "metabolic disease",
    disease_subtype == "TPI DEFICIENCY" ~ "metabolic disease",
    disease_subtype == "PSEUDOHYPOALDOSTERONISM" ~ "metabolic disease",
    disease_subtype == "DIABETES-DEAFNESS SYNDROME" ~ "metabolic disease",
    disease_subtype == "DIABETES MELLITUS, NONINSULIN-DEPENDENT, 1; NIDDM1" ~ "metabolic disease",
    disease_subtype == "dicarboxylic aminoaciduria" ~ "metabolic disease",
    disease_subtype == "central nervous system malformation" ~ "central nervous system malformation",
    disease_subtype == "leukodystrophy" ~ "leukodystrophy",
    disease_subtype == "metabolic disease" ~ "metabolic disease",
    disease_subtype == "mitochondrial disease" ~ "mitochondrial disease",
    disease_subtype == "nervous system disorder" ~ "nervous system disorder",
    disease_subtype == "neuromuscular disease" ~ "neuromuscular disease",
    disease_subtype == "syndromic disease" ~ "syndromic disease")) %>%  
  mutate(disease_ontology_id = case_when(group == "intellectual disability" ~ "MONDO:0001071", 
    group == "autism spectrum disorder" ~ "MONDO:0005258", 
    group == "developmental and epileptic encephalopathy" ~ "MONDO:0100062",
    group == "leukodystrophy" ~ "MONDO:0019046",
    group == "mitochondrial disease" ~ "MONDO:0044970",
    group == "central nervous system malformation" ~ "MONDO:0020022",
    group == "syndromic disease" ~ "MONDO:0002254",
    group == "metabolic disease" ~ "MONDO:0005066",
    group == "nervous system disorder" ~ "MONDO:0005071",
    group == "neuromuscular disease" ~ "MONDO:0019056")) %>%
  mutate(disease_subtype_has_problem = case_when(!is.na(group) ~ FALSE, is.na(group) ~ TRUE)) %>%
  select(-n, -group, -disease_subtype_has_problem)
############################################



############################################
## SysID table ndd_entity
ndd_entity_merged_with_ontology_set <- sysid_db_disease_collected %>%
  select(human_gene_disease_id, sysid_yes_no, gene_symbol, inheritance_pattern, inheritance_type, omim_disease, disease_subtype) %>%
  mutate(mode_of_inheritance = paste0(inheritance_pattern, " ", inheritance_type)) %>%
  left_join(sysid_db_disease_disease_subtype_no_omim, by = "disease_subtype") %>%
  left_join(sysid_db_disease_inheritance, by = "mode_of_inheritance") %>%
  mutate(omim_id = na_if(omim_disease, 0)) %>%
  mutate(omim_id = case_when(!is.na(omim_id) ~ paste0("OMIM:",omim_id), is.na(omim_id) ~ "")) %>%
  mutate(omim_id = na_if(omim_id, "")) %>%
  mutate(disease_ontology_id = case_when(is.na(omim_id) ~ disease_ontology_id, !is.na(omim_id) ~ omim_id)) %>%
  select(-omim_disease, -omim_id, -inheritance_pattern, -inheritance_type, -mode_of_inheritance) %>%
  mutate(entry_date = "") %>%
  mutate(entry_source = "SysID") %>%
  mutate(hgnc_id = paste0("HGNC:", hgnc_id_from_symbol_grouped(gene_symbol))) %>%
  select(entity_id = human_gene_disease_id, hgnc_id, gene_symbol, hpo_mode_of_inheritance_id = hpo_mode_of_inheritance_term, disease_ontology_id, ndd_phenotype = sysid_yes_no, entry_date, entry_source, disease_subtype) %>%
  left_join(ontology_set, by=c("disease_ontology_id" = "disease_ontology_id_version")) %>%
  select(entity_id, hgnc_id = hgnc_id.x, hpo_mode_of_inheritance_term = hpo_mode_of_inheritance_id, disease_ontology_id,  disease_ontology_id.y, ndd_phenotype, disease_ontology_name = disease_subtype)

ndd_entity_merged_with_ontology_set_select <- ndd_entity_merged_with_ontology_set %>%
  filter(!is.na(disease_ontology_id.y)) %>%
  select(entity_id, hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version = disease_ontology_id, ndd_phenotype)

ndd_entity_merged_with_ontology_set_join_id_version_four_categories <- ndd_entity_merged_with_ontology_set %>%
  filter(is.na(disease_ontology_id.y)) %>%
  left_join(ontology_set, by = c("disease_ontology_id", "disease_ontology_name", "hgnc_id", "hpo_mode_of_inheritance_term")) %>%
  select(entity_id, hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id, disease_ontology_id_version, ndd_phenotype, disease_ontology_name)

ndd_entity_merged_with_ontology_set_join_id_version_four_categories_select <- ndd_entity_merged_with_ontology_set_join_id_version_four_categories %>%
  filter(!is.na(disease_ontology_id_version)) %>%
  select(entity_id, hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype)

ndd_entity_merged_with_ontology_set_join_id_version_three_categories <- ndd_entity_merged_with_ontology_set_join_id_version_four_categories %>%
  filter(is.na(disease_ontology_id_version)) %>%
  select(entity_id, disease_ontology_id, disease_ontology_name, hgnc_id, hpo_mode_of_inheritance_term, ndd_phenotype) %>%
  mutate(hpo_mode_of_inheritance_term2 = NA) %>%
  left_join(ontology_set, by = c("disease_ontology_id", "disease_ontology_name", "hgnc_id", "hpo_mode_of_inheritance_term2" = "hpo_mode_of_inheritance_term")) %>%
  select(entity_id, hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype)

ndd_entity <- bind_rows(ndd_entity_merged_with_ontology_set_select, ndd_entity_merged_with_ontology_set_join_id_version_four_categories_select, ndd_entity_merged_with_ontology_set_join_id_version_three_categories) %>%
  mutate(is_active = TRUE) %>%
  mutate(replaced_by = 0) %>%
  mutate(replaced_by = na_if(replaced_by, 0)) %>%
  left_join(human_gene_disease_connect_collected, by = c("entity_id")) %>%
  mutate(entry_source = "SysID") %>%
  mutate(entry_user_id = 3) %>%
  select(entity_id, hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype, entry_date, entry_source, entry_user_id, is_active, replaced_by)
View(ndd_entity)

############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(ndd_entity, file = paste0("results/ndd_entity.",creation_date,".csv"))
############################################



############################################
## close database connection
rm_con()
############################################