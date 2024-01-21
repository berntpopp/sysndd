############################################
## load libraries
library(tidyverse)  ##n eeded for general table operations
library(jsonlite)   ## needed for OBO operations
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


## define OxO functions
## these functions calculate mappings to other ontologies

oxo_mapping_from_ontology_id <- function(ontology_id)  {

  url <- paste0("https://www.ebi.ac.uk/spot/oxo/api/mappings?fromId=", ontology_id)
  
  # try again while error
  # implemented in April 2023 because of
  # There was an unexpected error (type=Internal Server Error, status=500).
  # http://neo4j:dba@localhost:7474/db/data/transaction/commit: Connect to localhost:7474 [localhost/127.0.0.1] failed: Connection refused
  # based on https://stackoverflow.com/questions/66133261/how-to-make-a-new-request-while-there-is-an-error-fromjson
  # TODO: implement other retries
  oxo_request <- tryCatch(fromJSON(url), error = function(e) {return(NA)})

  while(all(is.na(oxo_request))) {
    Sys.sleep(0.2) #Change as per requirement. 
    oxo_request <- tryCatch(fromJSON(url), error = function(e) {return(NA)})
  }
  
  oxo_request_tibble <- as_tibble(oxo_request$`_embedded`$mappings$fromTerm$curie)

  if(length(oxo_request_tibble) == 0){
    mappings_from_omim_id <- NA
  } else {
    mappings_from_omim_id <- oxo_request_tibble%>%
      mutate(ontology =  str_remove(value, pattern = ":.+")) %>%
      unique() %>%
      group_by(ontology) %>% 
      arrange(value) %>% 
      mutate(value = paste0(value, collapse = ";")) %>% 
      unique() %>%
      ungroup() %>%
      arrange(ontology) %>%
      pivot_wider(names_from = ontology, values_from = value)
  }

  return(mappings_from_omim_id)
}
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

# TODO: replace oxo_mapping_from_ontology_id with something faster and more reliable
disease_ontology_set <- bind_rows(genemap2_hgnc, mondo_terms) %>%
  rowwise() %>%
  mutate(mappings = oxo_mapping_from_ontology_id(disease_ontology_id)) %>%
  ungroup() %>%
  mutate(DOID = mappings$DOID) %>%
  mutate(MONDO = mappings$MONDO) %>%
  mutate(Orphanet = mappings$Orphanet) %>%
  mutate(EFO = mappings$EFO) %>%
  select(-mappings) %>%
  mutate(is_active = TRUE) %>%
  mutate(update_date = omim_file_date)

############################################



############################################
## export table as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(disease_ontology_set, file = paste0("results/disease_ontology_set.",creation_date,".csv"))
############################################