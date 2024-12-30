############################################
## load libraries
library(tidyverse)  ## for read_csv and dplyr
library(DBI)
library(RMariaDB)

############################################
## 1) Connect to database
sysndd_db <- dbConnect(
  RMariaDB::MariaDB(),
  dbname   = config_vars_proj$dbname_sysndd,
  user     = config_vars_proj$user_sysndd,
  password = config_vars_proj$password_sysndd,
  server   = config_vars_proj$server_sysid_sysndd,
  port     = config_vars_proj$port_sysid_sysndd
)

############################################
## 2) Load the CSV containing the new variant hits
##    e.g. "my_new_variant_hits.csv"
vario_data <- read_csv("my_new_variant_hits.csv")

## vario_data should have columns:
##   review_id, vario_id, modifier_id, entity_id

############################################
## 3) Insert into ndd_review_variation_ontology_connect
##    We assume columns: (review_id, vario_id, modifier_id, entity_id, is_active)
##    The 'review_vario_id' primary key is auto-increment
##    The 'variation_ontology_date' can have a default value (e.g. current_timestamp)

## Approach A: Use a simple loop with parameter binding
for (i in seq_len(nrow(vario_data))) {
  row_i <- vario_data[i, ]   # a one-row tibble

  dbExecute(
    sysndd_db,
    "
      INSERT INTO ndd_review_variation_ontology_connect 
        (review_id, vario_id, modifier_id, entity_id, is_active)
      VALUES (?, ?, ?, ?, 1);
    ",
    params = list(
      row_i$review_id,
      row_i$vario_id,
      row_i$modifier_id,
      row_i$entity_id
    )
  )
}

############################################
## 4) Clean up / close connection
dbDisconnect(sysndd_db)
