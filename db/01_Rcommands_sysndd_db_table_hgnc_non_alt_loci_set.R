############################################
## load libraries
library(tidyverse)  ## needed for general table operations
library(biomaRt)  ## needed to get gene coordinates
library(STRINGdb)  ## needed to compute StringDB identifiers
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


##-------------------------------------------------------------------------------##
## functions to get gene coordinates from symbol name using biomart

# define mart
mart_hg19 <- useMart("ensembl", host="grch37.ensembl.org")
mart_hg19 <- useDataset("hsapiens_gene_ensembl", mart_hg19)

mart_hg38 <- useMart("ensembl", host="ensembl.org")
mart_hg38 <- useDataset("hsapiens_gene_ensembl", mart_hg38)

# function to retrive bed format style gene coordinates
gene_coordinates_from_symbol <- function(gene_symbols, reference = "hg19") {
  gene_symbol_list <- as_tibble(gene_symbols) %>%
    dplyr::select(hgnc_symbol = value)

  if (reference == "hg19") {
    mart <- mart_hg19
  } else {
    mart <- mart_hg38
  }

  attributes <- c("hgnc_symbol", "chromosome_name", "start_position", "end_position")
  filters <- c("hgnc_symbol")

  values <- list(hgnc_symbol = gene_symbol_list$hgnc_symbol)

  gene_coordinates_hg19 <- getBM(attributes=attributes, filters=filters, values=values, mart=mart) %>%
    group_by(hgnc_symbol) %>%
    summarise(hgnc_symbol = max(hgnc_symbol), chromosome_name = max(chromosome_name), start_position = max(start_position), end_position = max(end_position)) %>%
    mutate(bed_format = paste0("chr", chromosome_name, ":", start_position, "-", end_position)) %>%
    dplyr::select(hgnc_symbol, bed_format)
  
  gene_symbol_list_return <- gene_symbol_list %>%
  left_join(gene_coordinates_hg19, by = ("hgnc_symbol"))
  
  return(gene_symbol_list_return)
}

# 
gene_coordinates_from_ensembl <- function(ensembl_id, reference = "hg19") {
  ensembl_id_list <- as_tibble(ensembl_id) %>%
    dplyr::select(ensembl_gene_id = value)

  if (reference == "hg19") {
    mart <- mart_hg19
  } else {
    mart <- mart_hg38
  }

  attributes <- c("ensembl_gene_id", "chromosome_name", "start_position", "end_position")
  filters <- c("ensembl_gene_id")

  values <- list(ensembl_gene_id = ensembl_id_list$ensembl_gene_id)

  gene_coordinates_hg19 <- getBM(attributes=attributes, filters=filters, values=values, mart=mart) %>%
    group_by(ensembl_gene_id) %>%
    summarise(ensembl_gene_id = max(ensembl_gene_id), chromosome_name = max(chromosome_name), start_position = max(start_position), end_position = max(end_position)) %>%
    mutate(bed_format = paste0("chr", chromosome_name, ":", start_position, "-", end_position)) %>%
    dplyr::select(ensembl_gene_id, bed_format)

  ensembl_id_list_return <- ensembl_id_list %>%
  left_join(gene_coordinates_hg19, by = ("ensembl_gene_id"))

  return(ensembl_id_list_return)
}
##-------------------------------------------------------------------------------##


############################################
## download HGNC file
file_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
hgnc_link <- "http://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/tsv/non_alt_loci_set.txt"
hgnc_file <- "data/non_alt_loci_set.txt"
download.file(hgnc_link, hgnc_file, mode = "wb")
############################################



############################################
## load STRINGdb database
string_db <- STRINGdb$new( version="11.5", species=9606, score_threshold=200, input_directory="data/")
############################################



############################################
## load the downloaded HGNC file
non_alt_loci_set <- read_delim(hgnc_file, "\t", col_names = TRUE) %>%
  mutate(update_date = file_date) 

##
non_alt_loci_set_table <- non_alt_loci_set %>% 
  dplyr::select(symbol) %>%
  unique()

non_alt_loci_set_df <- non_alt_loci_set_table %>% 
    as.data.frame()

non_alt_loci_set_mapped <- string_db$map(non_alt_loci_set_df, "symbol")
non_alt_loci_set_mapped_tibble <- as_tibble(non_alt_loci_set_mapped) %>%
  filter(!is.na(STRING_id)) %>%
  group_by(symbol) %>%
  summarise(STRING_id = str_c(STRING_id, collapse=";")) %>%
  ungroup %>%
  unique()
  
## join with Strind identifiers
non_alt_loci_set_string <- non_alt_loci_set %>% 
  left_join(non_alt_loci_set_mapped_tibble, by="symbol")

##
non_alt_loci_set_coordinates <- non_alt_loci_set_string %>%
  mutate(hg19_coordinates_from_ensembl = gene_coordinates_from_ensembl(ensembl_gene_id)) %>%
  mutate(hg19_coordinates_from_symbol = gene_coordinates_from_symbol(symbol)) %>%
  mutate(hg38_coordinates_from_ensembl = gene_coordinates_from_ensembl(ensembl_gene_id, reference = "hg38")) %>%
  mutate(hg38_coordinates_from_symbol = gene_coordinates_from_symbol(symbol, reference = "hg38")) %>% 
  mutate(bed_hg19 =
    case_when(
      !is.na(hg19_coordinates_from_ensembl$bed_format) ~ hg19_coordinates_from_ensembl$bed_format,
      is.na(hg19_coordinates_from_ensembl$bed_format) ~ hg19_coordinates_from_symbol$bed_format,
    )
  ) %>% 
  mutate(bed_hg38 =
    case_when(
      !is.na(hg38_coordinates_from_ensembl$bed_format) ~ hg38_coordinates_from_ensembl$bed_format,
      is.na(hg38_coordinates_from_ensembl$bed_format) ~ hg38_coordinates_from_symbol$bed_format,
    )
  ) %>% 
  dplyr::select(-hg19_coordinates_from_ensembl, -hg19_coordinates_from_symbol, -hg38_coordinates_from_ensembl, -hg38_coordinates_from_symbol)

############################################



############################################
## export table as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(non_alt_loci_set_coordinates, file = paste0("results/non_alt_loci_set.",creation_date,".csv"))
############################################