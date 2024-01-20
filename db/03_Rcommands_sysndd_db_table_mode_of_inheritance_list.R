############################################
## load libraries
library(tidyverse)  ## needed for general table operations
library(jsonlite)   ## needed for HGNC requests
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
## get inheritance modes from HPO by finding all children of term HP:0000005 and annotating them with name and definition. 
## Activity state is defined by the term having no children.

query_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

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
  mutate(children_count = HPO_children_count_from_term(hpo_mode_of_inheritance_term))


mode_of_inheritance_select_sort <- mode_of_inheritance_list %>%
    mutate(is_active = case_when(hpo_mode_of_inheritance_term %in% c("HP:0000006", "HP:0000007", "HP:0001417", "HP:0001419", "HP:0001423", "HP:0001427", "HP:0001428") ~ TRUE, TRUE ~ FALSE)) %>%
    mutate(sort = case_when(
        hpo_mode_of_inheritance_term %in% c("HP:0000006") ~ 1,
        hpo_mode_of_inheritance_term %in% c("HP:0000007") ~ 2,
        hpo_mode_of_inheritance_term %in% c("HP:0001417") ~ 3,
        hpo_mode_of_inheritance_term %in% c("HP:0001419") ~ 4,
        hpo_mode_of_inheritance_term %in% c("HP:0001423") ~ 5,
        hpo_mode_of_inheritance_term %in% c("HP:0001427") ~ 6,
        hpo_mode_of_inheritance_term %in% c("HP:0001428") ~ 7,
        TRUE ~ 0
      )
    ) %>%
    mutate(inheritance_filter = case_when(
      str_detect(hpo_mode_of_inheritance_term_name, "X-linked") ~ "X-linked",
      str_detect(hpo_mode_of_inheritance_term_name, "Autosomal dominant inheritance") ~ "Autosomal dominant",
      str_detect(hpo_mode_of_inheritance_term_name, "Autosomal recessive inheritance") ~ "Autosomal recessive",
      TRUE ~ "Other"
    )) %>%
    mutate(inheritance_short_text = case_when(
      str_detect(hpo_mode_of_inheritance_term_name, "X-linked dominant inheritance") ~ "XD",
      str_detect(hpo_mode_of_inheritance_term_name, "X-linked recessive inheritance") ~ "XR",
      str_detect(hpo_mode_of_inheritance_term_name, "X-linked inheritance") ~ "Xo",
      str_detect(hpo_mode_of_inheritance_term_name, "Autosomal dominant inheritance") ~ "AD",
      str_detect(hpo_mode_of_inheritance_term_name, "Autosomal recessive inheritance") ~ "AR",
      str_detect(hpo_mode_of_inheritance_term_name, "Mitochondrial inheritance") ~ "Mit",
      str_detect(hpo_mode_of_inheritance_term_name, "Somatic mutation") ~ "Som",
      TRUE ~ "Oth"
    )) %>%
    mutate(hpo_mode_of_inheritance_term_name = case_when(
      str_detect(hpo_mode_of_inheritance_term_name, "X-linked inheritance") ~ "X-linked other inheritance",
      TRUE ~ hpo_mode_of_inheritance_term_name
    )) %>%
  select(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name, hpo_mode_of_inheritance_term_definition, inheritance_filter, inheritance_short_text, is_active, sort) %>%
  ungroup() %>%
  mutate(update_date = query_date)


############################################



############################################
## export table as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(mode_of_inheritance_select_sort, file = paste0("results/mode_of_inheritance_list.",creation_date,".csv"))
############################################