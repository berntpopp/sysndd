
############################################
## load libraries
library(tidyverse)  ##needed for general table operations
library(DBI)    ##needed for MySQL data export
library(RMariaDB)  ##needed for MySQL data export
library(sqlr)    ##needed for MySQL data export
library(tools)    ##needed for md5sum calculation
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
## load results data from external files
import_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

results_csv_table <- list.files(path = "results/", pattern = ".csv") %>%
  as_tibble() %>%
  separate(value, c("table_name", "table_date", "extension"), sep = "\\.") %>%
  mutate(file_name = paste0(table_name, ".", table_date, ".", extension)) %>%
  mutate(import_date = import_date) %>%
  mutate(results_file_id = row_number()) %>%
  mutate(md5sum_file = md5sum(paste0("results/", file_name))) %>%
  dplyr::select(results_file_id, file_name, table_name, table_date, extension, import_date, md5sum_file)
############################################



############################################
## drop all tables if they exist
drop_db_tbl("results_csv_table", force = TRUE)
drop_db_tbl(results_csv_table$table_name, force = TRUE)
############################################



############################################
##
write_db_tbl(name = "results_csv_table", data = results_csv_table, keys = pk_spec(names(results_csv_table)[1]), char_set = "utf8")

for (row in 1:nrow(results_csv_table)) {
  table_to_import <- read_delim(paste0("results/",slice(results_csv_table, row)$file_name), ",", col_names = TRUE)
  write_db_tbl(name = slice(results_csv_table, row)$table_name, data = table_to_import, keys = pk_spec(names(table_to_import)[1]), char_set = "utf8")
}
############################################



############################################
## close database connection
rm_con()
############################################