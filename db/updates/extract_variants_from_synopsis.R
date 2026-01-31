############################################
## load libraries
library(tidyverse)  ## for dplyr, stringr etc.
library(DBI)        
library(RMariaDB)

############################################
## 1) Connect to database
sysndd_db <- dbConnect(
  RMariaDB::MariaDB(),
  dbname = config_vars_proj$dbname_sysndd,
  user   = config_vars_proj$user_sysndd,
  password = config_vars_proj$password_sysndd,
  server   = config_vars_proj$server_sysid_sysndd,
  port     = config_vars_proj$port_sysid_sysndd
)

############################################
## 2) Pull the primary reviews
ndd_reviews <- dbGetQuery(
  sysndd_db,
  "SELECT 
     review_id, 
     entity_id,
     synopsis
   FROM ndd_entity_review
   WHERE 
       is_primary = 1;"
)

## Convert synopsis to plain character
ndd_reviews <- ndd_reviews %>%
  mutate(synopsis = as.character(synopsis))

############################################
## 3) Define a dictionary of variant terms -> vario_id
variant_dictionary <- tribble(
  ~pattern,             ~vario_id,
  "missense",           "VariO:0017",
  "non-synonymous",     "VariO:0017",
  "nonsense",           "VariO:0015",
  "stop mutation",      "VariO:0015",
  "start loss",          "VariO:0015",
  "stop-gain",          "VariO:0015",
  "stop gain",          "VariO:0015",
  "frameshift",         "VariO:0031",
  "fs variant",         "VariO:0031",
  "fs mutation",        "VariO:0031",
  "truncating",         "VariO:0015",
  "in-frame variant",   "VariO:0030",
  "amino acid insertion","VariO:0030",
  "in-frame deletion",  "VariO:0030",
  "in-frame duplication","VariO:0030",
  "in-frame insertion", "VariO:0030",
  "in-frame indel",     "VariO:0030",
  "splice",             "VariO:0508",
  "splicing",           "VariO:0508",
  "deletion",           "VariO:0193",
  "duplication",        "VariO:0187",
  "CNV",                "VariO:0187",
  "copy number variation","VariO:0187",
  "insertion",          "VariO:0142",
  "gain-of-function",   "VariO:0040",
  "gain of function",   "VariO:0040",
  "gof",                "VariO:0040",
  "GOF",                "VariO:0040",
  "dominant-negative",  "VariO:0039",
  "loss-of-function",   "VariO:0043",
  "lof",                "VariO:0043",
  "LOF",                "VariO:0043",
  "translocations",     "VariO:0144",
  "trinucleotide repeat","VariO:0189",
  "CGG repeat expansion","VariO:0189",
  "point mutation",     "VariO:0002",
  "inversion",          "VariO:0132",
  "rearrangement",      "VariO:0132",
  # Extend as needed
)

############################################
## 4) Build results data frame:
##    only (review_id, vario_id, modifier_id, entity_id)
vario_hits <- tibble(
  review_id   = integer(),
  vario_id    = character(),
  modifier_id = integer(),
  entity_id   = integer()
)

for (i in seq_len(nrow(ndd_reviews))) {
  
  rev_id   <- ndd_reviews$review_id[i]
  ent_id   <- ndd_reviews$entity_id[i]
  text_syn <- ndd_reviews$synopsis[i]
  
  if (is.na(text_syn) || text_syn == "") {
    next
  }
  
  # for each pattern in variant_dictionary, see if text_syn contains it
  for (j in seq_len(nrow(variant_dictionary))) {
    pattern_j  <- variant_dictionary$pattern[j]
    vario_j    <- variant_dictionary$vario_id[j]
    
    # case-insensitive search
    if (grepl(pattern_j, text_syn, ignore.case = TRUE)) {
      new_row <- tibble(
        review_id   = rev_id,
        vario_id    = vario_j,
        modifier_id = 1,       # or some default you choose
        entity_id   = ent_id
      )
      vario_hits <- bind_rows(vario_hits, new_row)
    }
  }
}

############################################
## 5) Remove duplicates in vario_hits itself (optional step)
##    in case the same combination was found multiple times
vario_hits <- vario_hits %>%
  distinct(review_id, vario_id, modifier_id, entity_id)

############################################
## 6) Pull existing records from the DB so we can exclude duplicates
##    i.e. the same four columns
existing_records <- dbGetQuery(
  sysndd_db,
  "SELECT 
     review_id,
     vario_id,
     modifier_id,
     entity_id
   FROM ndd_review_variation_ontology_connect
   WHERE is_active = 1;"
)

## Convert columns to the same type (if needed)
## Usually the columns will match, but just in case:
existing_records <- existing_records %>%
  mutate(
    review_id   = as.integer(review_id),
    vario_id    = as.character(vario_id),
    modifier_id = as.integer(modifier_id),
    entity_id   = as.integer(entity_id)
  )

############################################
## 7) Filter out any hits already present in the DB
vario_hits_new <- vario_hits %>%
  anti_join(existing_records,
            by = c("review_id", "vario_id", "modifier_id", "entity_id"))

############################################
## 8) Inspect final data
print(vario_hits_new)

## 9) Save to CSV for later insertion
write.csv(vario_hits_new, "my_new_variant_hits.csv", row.names = FALSE)

############################################
## 10) Done, close connection
dbDisconnect(sysndd_db)
