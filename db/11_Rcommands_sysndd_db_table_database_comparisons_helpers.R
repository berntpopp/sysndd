############################################
## Helper functions for 11_Rcommands_sysndd_db_table_database_comparisons.R
##
## WP9 / #346 (#402): extracted verbatim from the comparisons data-prep script
## to keep that script under the 600-line soft ceiling without splitting its
## sequential, list-by-list import pipeline (which would reduce clarity).
##
## This file defines functions only. It must be `source()`d by the parent
## script AFTER `db_bootstrap()` has run, because these helpers rely on the
## bootstrap-provided `db_src` and the `db_genenames_search_url()` /
## `db_hpo_term_url()` helpers, plus the `tidyverse` / `jsonlite` packages the
## parent loads at its top. `HPO_all_children_from_term()` intentionally mutates
## the global `all_children_list` via `<<-`; the parent resets that list before
## each traversal. Do not add library() calls or a bootstrap block here.
############################################


############################################
## define functions

## HGNC functions
hgnc_id_from_prevsymbol <- function(symbol_input)  {
  symbol_request <- fromJSON(db_genenames_search_url("prev_symbol", symbol_input, db_src))

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
  symbol_request <- fromJSON(db_genenames_search_url("alias_symbol", symbol_input, db_src))

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

  symbol_request <- fromJSON(db_genenames_search_url("symbol", str_c(symbol_list_tibble$symbol, collapse = "+OR+"), db_src))

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


symbol_from_hgnc_id <- function(hgnc_id_tibble) {
  hgnc_id_list_tibble <- as_tibble(hgnc_id_tibble) %>%
    select(hgnc_id = value) %>%
    mutate(hgnc_id = as.integer(hgnc_id))

  hgnc_id_request <- fromJSON(db_genenames_search_url("hgnc_id", str_c(hgnc_id_list_tibble$hgnc_id, collapse = "+OR+"), db_src))

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

symbol_from_hgnc_id_grouped <- function(input_tibble, request_max = 150) {
  input_tibble <- as_tibble(input_tibble)

  row_number <- nrow(input_tibble)
  groups_number <- ceiling(row_number/request_max)

  input_tibble_request <- input_tibble %>%
    mutate(group = sample(1:groups_number, row_number, replace=T)) %>%
    group_by(group) %>%
    mutate(response = symbol_from_hgnc_id(value)$symbol) %>%
    ungroup()

  return(input_tibble_request$response)
}

## HPO functions
## to do: make this recursive and independent of global variable

HPO_name_from_term <- function(term_input_id) {
  hpo_term_response <- fromJSON(db_hpo_term_url(term_input_id, db_src))
  hpo_term_name <- as_tibble(hpo_term_response$details$name) %>%
  select(hpo_mode_of_inheritance_term_name = value)

  return(hpo_term_name)
}


HPO_definition_from_term <- function(term_input_id) {
  hpo_term_response <- fromJSON(db_hpo_term_url(term_input_id, db_src))
  hpo_term_definition <- as_tibble(hpo_term_response$details$definition) %>%
  select(hpo_mode_of_inheritance_term_definition = value)

  return(hpo_term_definition)
}


HPO_children_count_from_term <- function(term_input_id) {
  hpo_term_response <- fromJSON(db_hpo_term_url(term_input_id, db_src))
  hpo_term_children_count <- as_tibble(hpo_term_response$relations$children)

  return(length(hpo_term_children_count))
}


HPO_children_from_term <- function(term_input_id) {
  hpo_term_response <- fromJSON(db_hpo_term_url(term_input_id, db_src))
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
