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
##
table_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

boolean_list <- tibble(
    boolean_id = numeric(),
    boolean_number = numeric(),
    boolean_word = character(),
    word_english = character(),
    logical = logical(),
  ) %>%
  add_row(boolean_id = 1, boolean_number = 0, boolean_word = "false", word_english = "No", logical=FALSE) %>%
  add_row(boolean_id = 2, boolean_number = 1, boolean_word = "true", word_english = "Yes", logical=TRUE)

############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(boolean_list, file = paste0("results/boolean_list.",creation_date,".csv"),na = "")
############################################
