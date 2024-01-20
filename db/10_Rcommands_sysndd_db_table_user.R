############################################
## load libraries
library(tidyverse)  ## needed for general table operations
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
## load user data from an external file
user <- read_csv("config/path_to_your_file.csv")
############################################


############################################
## create a new user table
table_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

user <- user %>%
  arrange(user_id) %>%
  mutate(created_at = strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")) %>%
  mutate(password_reset_date = NA)
############################################


############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(user, file = paste0("results/user.",creation_date,".csv"),na = "")
############################################
