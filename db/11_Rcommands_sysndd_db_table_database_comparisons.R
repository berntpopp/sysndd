############################################
## load libraries
library(tidyverse)  ## needed for general table operations
library(jsonlite)  ## needed for HGNC requests
library(pdftools)  ## for pdf parsings
library(config)     ## needed to read config file
############################################


############################################
## SysNDD data-prep bootstrap (issue #33): locate db/config, then db_bootstrap()
## sets SYSNDD_DB_DIR, anchors CWD to db/, sources db_sysid_source.R, sets db_src.
.f <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
if (is.null(.f)) .f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.cfg <- if (nzchar(Sys.getenv("SYSNDD_DB_DIR"))) {
  file.path(Sys.getenv("SYSNDD_DB_DIR"), "config")
} else {
  file.path(dirname(normalizePath(.f[1])), "config")
}
source(file.path(.cfg, "db_config.R"))
config_vars_proj <- db_bootstrap()
############################################



############################################
## define functions
## WP9 / #346 (#402): the HGNC + HPO helper functions live in a sibling file to
## keep this list-by-list import pipeline under the 600-line soft ceiling.
## Source them here, AFTER db_bootstrap(), because they rely on db_src and the
## bootstrap-provided URL helpers. Behavior is unchanged: the functions are
## defined into this (global) environment exactly as before.
source(db_path("11_Rcommands_sysndd_db_table_database_comparisons_helpers.R"))
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
  mutate(children_count = HPO_children_count_from_term(hpo_mode_of_inheritance_term)) %>%
  mutate(is_active = case_when(children_count == 0 ~ TRUE, children_count > 0 ~ FALSE)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term == "HP:0001417" ~ TRUE, hpo_mode_of_inheritance_term != "HP:0001417" ~ is_active)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term_definition == "" ~ FALSE, hpo_mode_of_inheritance_term_definition != "" ~ is_active)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term == "HP:0000007" ~ TRUE, hpo_mode_of_inheritance_term != "HP:0000007" ~ is_active)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term == "HP:0000006" ~ TRUE, hpo_mode_of_inheritance_term != "HP:0000006" ~ is_active)) %>%
  mutate(is_active = case_when(hpo_mode_of_inheritance_term == "HP:0001428" ~ TRUE, hpo_mode_of_inheritance_term != "HP:0001428" ~ is_active)) %>%
  select(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name, hpo_mode_of_inheritance_term_definition, is_active) %>%
  ungroup() %>%
  mutate(update_date = query_date)
############################################



############################################
## download all database sources
database_file_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

ndd_databases_links <- read_delim("data/ndd_databases_links/ndd_databases_links.txt", "\t", escape_double = FALSE, trim_ws = TRUE) %>%
mutate(file_saved = paste0(name, ".", database_file_date, ".", format))

for (row in 1:nrow(ndd_databases_links)) {
  download.file(ndd_databases_links$link[row], paste0("data/", ndd_databases_links$file_saved[row]), mode = "wb")
}
############################################



############################################
## 1) radboudumc ID
## to do: annotate "disease_ontology_id" with possible inheritance from OMIM, remove wrong OMIM entries
## to do: annotate OMIM disease name

radboudumc_version <- pdf_text(paste0("data/", (ndd_databases_links %>% filter(name == "radboudumc_ID"))$file_saved))[1] %>% 
  str_extract(pattern = "^.+\\n") %>% 
  str_remove(pattern = "\\n")

radboudumc_pdf_list <- pdf_text(paste0("data/", (ndd_databases_links %>% filter(name == "radboudumc_ID"))$file_saved)) %>%
  read_lines(skip=3) %>%
  str_squish() %>%
  as_tibble() %>%
  separate(value, c("gene_symbol", "MedianCoverage", "pCoveredo10x", "pCoveredo20x","OMIMdiseaseID"), sep=" ") %>%
  filter(!(gene_symbol %in% c("","%","OMIM","Gene","Genes","Median","Ad","Coverage","Covered","Non","EAS.GenProductCoverage.pdf.footer.ad01")))

radboudumc_list <- radboudumc_pdf_list %>%
  select(gene_symbol, OMIMdiseaseID) %>%
  mutate(OMIMdiseaseID = na_if(OMIMdiseaseID, "-")) %>%
  mutate(list = "radboudumc_ID") %>%
  mutate(category = "Definitive") %>%
  mutate(version = radboudumc_version) %>%
  mutate(hgnc_id = hgnc_id_from_symbol_grouped(gene_symbol)) %>%
  mutate(symbol = symbol_from_hgnc_id_grouped(hgnc_id)) %>%
  mutate(hgnc_id = paste0("HGNC:", hgnc_id)) %>%
  mutate(disease_ontology_name = NA) %>%
  mutate(pathogenicity_mode = NA) %>%
  mutate(inheritance = NA) %>%
  mutate(phenotype = NA) %>%
  mutate(publication_id = NA) %>%
  select(symbol, hgnc_id, disease_ontology_id = OMIMdiseaseID, disease_ontology_name, inheritance, category, pathogenicity_mode, phenotype, publication_id, list, version) %>%
  separate_rows(disease_ontology_id, sep = ";") %>%
  mutate(
    disease_ontology_id = case_when(
      is.na(disease_ontology_id) ~ disease_ontology_id,
      !is.na(disease_ontology_id) ~ paste0("OMIM:", disease_ontology_id)
    )
  ) %>%
  mutate(import_date = database_file_date) %>%
  mutate(granularity = "gene,disease,category(implied)")

############################################



############################################
## 2) gene2phenotype
## to do: map inheritance terms, map category

# G2P (EBI) moved to an API endpoint and renamed columns in 2026:
#   "confidence category" -> "confidence", "mutation consequence" ->
#   "variant consequence", "pmids" -> "publications" (see migration 013).
gene2phenotype_csv <- read_csv(paste0("data/", (ndd_databases_links %>% filter(name == "gene2phenotype_ID"))$file_saved)) %>%
  select(gene_symbol = `gene symbol`, disease_ontology_name = `disease name`, disease_ontology_id = `disease mim`, category = confidence, inheritance = `allelic requirement`, pathogenicity_mode = `variant consequence`, phenotype = phenotypes, publication_id = publications)

gene2phenotype_list <- gene2phenotype_csv %>%
  mutate(list = "gene2phenotype") %>%
  mutate(version = (ndd_databases_links %>% filter(name == "gene2phenotype_ID"))$file_saved %>% str_remove(pattern = "\\.csv")) %>%
  mutate(hgnc_id = hgnc_id_from_symbol_grouped(gene_symbol)) %>%
  mutate(symbol = symbol_from_hgnc_id_grouped(hgnc_id)) %>%
  mutate(hgnc_id = paste0("HGNC:", hgnc_id)) %>%
  mutate(disease_ontology_id = na_if(disease_ontology_id, "No disease mim")) %>%
  mutate(
    disease_ontology_id = case_when(
      is.na(disease_ontology_id) ~ disease_ontology_id,
      !is.na(disease_ontology_id) ~ paste0("OMIM:", disease_ontology_id)
    )
  ) %>%
  mutate(phenotype = str_replace_all(phenotype, ";", ",")) %>%
  mutate(publication_id = str_replace_all(publication_id, ";", ",")) %>%
  select(symbol, hgnc_id, disease_ontology_id, disease_ontology_name, inheritance, category, pathogenicity_mode, phenotype, publication_id, list, version) %>%
  mutate(import_date = database_file_date) %>%
  mutate(granularity = "gene,disease,inheritance,category,pathogenicity")

############################################



############################################
## 3) panelapp ID
## to do: map inheritance terms, map category

panelapp_ID_tsv <- read_delim(paste0("data/", (ndd_databases_links %>% filter(name == "panelapp_ID"))$file_saved), "\t", escape_double = FALSE, trim_ws = TRUE) %>%
  filter(`Entity type` == "gene") %>%
  select(gene_symbol = `Gene Symbol`, disease_ontology = `Phenotypes`, category = GEL_Status, inheritance = Model_Of_Inheritance, pathogenicity_mode = `Mode of pathogenicity`, phenotype = HPO, publication_id = Publications, version)

panelappID_list <- panelapp_ID_tsv %>%
  mutate(list = "panelapp") %>%
  mutate(hgnc_id = hgnc_id_from_symbol_grouped(gene_symbol)) %>%
  mutate(symbol = symbol_from_hgnc_id_grouped(hgnc_id)) %>%
  mutate(hgnc_id = paste0("HGNC:", hgnc_id)) %>%
  mutate(publication_id = str_replace_all(publication_id, ";", ",")) %>%
  mutate(disease_ontology = str_replace_all(disease_ontology, "(?<=[1-9][0-9]{5})", ";")) %>%
  mutate(disease_ontology = str_replace_all(disease_ontology, "(?=[1-9][0-9]{5})", "OMIM:")) %>%
  mutate(disease_ontology = str_replace_all(disease_ontology, "OMIM:OMIM:", "OMIM:")) %>%
  mutate(disease_ontology = str_replace_all(disease_ontology, ";;", ";")) %>%
  mutate(disease_ontology = str_replace_all(disease_ontology, "; ", ";")) %>%
  mutate(disease_ontology = str_replace(disease_ontology, ";$", "")) %>%
  separate_rows(disease_ontology, sep = ";") %>%
  separate(disease_ontology, c("disease_ontology_name", "disease_ontology_id"), sep = "(?=OMIM:|MONDO:)") %>%
  mutate(disease_ontology_name = str_squish(disease_ontology_name)) %>%
  mutate(disease_ontology_id = str_squish(disease_ontology_id)) %>%
  mutate(disease_ontology_name = str_replace(disease_ontology_name, ",$", "")) %>%
  arrange(symbol, disease_ontology_id, disease_ontology_name) %>%
  select(symbol, hgnc_id, disease_ontology_id, disease_ontology_name, inheritance, category, pathogenicity_mode, phenotype, publication_id, list, version) %>%
  mutate(import_date = database_file_date) %>%
  mutate(granularity = "gene,disease(aggregated),inheritance(aggregated),category,pathogenicity(incomplete)") %>%
  rowwise() %>%
  mutate(category = toString(category)) %>%
  mutate(version = toString(version)) %>%
  ungroup()

############################################



############################################
## 4) sfari
## to do: assign disease ontology
## to do: get publications from website
## to do: get ASSOCIATED DISORDERS from website

sfari_csv <- read_csv(paste0("data/", (ndd_databases_links %>% filter(name == "sfari"))$file_saved)) %>%
  select(gene_symbol = `gene-symbol`, disease_ontology_name = syndromic, disease_ontology_id = syndromic, category = `gene-score`)

sfari_list <- sfari_csv %>%
  mutate(list = "sfari") %>%
  mutate(version = (ndd_databases_links %>% filter(name == "sfari"))$file_saved %>% str_remove(pattern = "\\.csv")) %>%
  mutate(hgnc_id = hgnc_id_from_symbol_grouped(gene_symbol)) %>%
  filter(!is.na(hgnc_id)) %>%
  mutate(symbol = symbol_from_hgnc_id_grouped(hgnc_id)) %>%
  mutate(hgnc_id = paste0("HGNC:", hgnc_id)) %>%
  mutate(inheritance = NA) %>%
  mutate(pathogenicity_mode = NA) %>%
  mutate(phenotype = NA) %>%
  mutate(publication_id = NA) %>%
  mutate(category = as.character(category)) %>%
  mutate(disease_ontology_id = as.character(disease_ontology_id)) %>%
  mutate(disease_ontology_name = as.character(disease_ontology_name)) %>%
  arrange(symbol, disease_ontology_id, disease_ontology_name) %>%
  select(symbol, hgnc_id, disease_ontology_id, disease_ontology_name, inheritance, category, pathogenicity_mode, phenotype, publication_id, list, version) %>%
  mutate(import_date = database_file_date) %>%
  mutate(granularity = "gene,disease,category")

############################################


############################################
## 5) geisinger DBD -> NDD GeneHub (nddgenehub.org "Full-Data.csv")
## The legacy dbd.geisingeradmi.org CSV was retired; NDD GeneHub publishes the
## canonical case-level Full-Data.csv (Gene Symbol, PubMed ID, the
## ID/ASD/EP/ADHD/SCZ/BD/CP phenotype flags, and Variant 1 Inheritance/Chr).
## We aggregate the case-level rows to one row per gene, mirroring
## api/functions/comparisons-parsers.R::parse_geisinger_csv().

geisinger_full_data <- read_csv(paste0("data/", (ndd_databases_links %>% filter(name == "ndd_genehub"))$file_saved)) %>%
  rename(gene_symbol = `Gene Symbol`) %>%
  mutate(gene_symbol = as.character(gene_symbol)) %>%
  filter(!is.na(gene_symbol) & gene_symbol != "")

geisinger_pheno_labels <- c(
  ID = "Intellectual disability", ASD = "Autism", EP = "Epilepsy",
  ADHD = "Attention deficit hyperactivity disorder", SCZ = "Schizophrenia",
  BD = "Bipolar disorder", CP = "Cerebral palsy"
)
geisinger_pheno_labels <- geisinger_pheno_labels[names(geisinger_pheno_labels) %in% colnames(geisinger_full_data)]

geisinger_phenotype <- geisinger_full_data %>%
  select(gene_symbol, all_of(names(geisinger_pheno_labels))) %>%
  mutate(across(all_of(names(geisinger_pheno_labels)), as.character)) %>%
  pivot_longer(-gene_symbol, names_to = "code", values_to = "flag") %>%
  filter(!is.na(flag) & flag != "") %>%
  mutate(pheno = unname(geisinger_pheno_labels[code])) %>%
  distinct(gene_symbol, pheno) %>%
  group_by(gene_symbol) %>%
  summarise(phenotype = paste(sort(unique(pheno)), collapse = ";"), .groups = "drop")

geisinger_publications <- geisinger_full_data %>%
  transmute(gene_symbol, pmid = str_extract_all(as.character(`PubMed ID`), "[0-9]+")) %>%
  unnest(pmid) %>%
  filter(!is.na(pmid) & pmid != "") %>%
  distinct(gene_symbol, pmid) %>%
  group_by(gene_symbol) %>%
  summarise(publication_id = paste(unique(pmid), collapse = ";"), .groups = "drop")

geisinger_inheritance <- geisinger_full_data %>%
  mutate(
    .chr = as.character(`Variant 1 Chr`),
    .inh = as.character(`Variant 1 Inheritance`),
    inheritance_term = case_when(
      .chr %in% c("X", "23") ~ "X-linked inheritance",
      .inh == "De novo" ~ "Sporadic",
      .inh %in% c("Inherited", "Maternal", "Paternal", "Parental", "Unknown") ~ "Autosomal dominant inheritance",
      .inh == "Bi-parental" ~ "Autosomal recessive inheritance",
      .inh == "Mosaic" ~ "Somatic mosaicism",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(inheritance_term)) %>%
  distinct(gene_symbol, inheritance_term) %>%
  group_by(gene_symbol) %>%
  summarise(inheritance = paste(sort(unique(inheritance_term)), collapse = ";"), .groups = "drop")

geisinger_list <- geisinger_full_data %>%
  distinct(gene_symbol) %>%
  left_join(geisinger_phenotype, by = "gene_symbol") %>%
  left_join(geisinger_publications, by = "gene_symbol") %>%
  left_join(geisinger_inheritance, by = "gene_symbol") %>%
  mutate(list = "ndd_genehub") %>%
  mutate(version = (ndd_databases_links %>% filter(name == "ndd_genehub"))$file_saved %>% str_remove(pattern = "\\.csv")) %>%
  mutate(hgnc_id = hgnc_id_from_symbol_grouped(gene_symbol)) %>%
  filter(!is.na(hgnc_id)) %>%
  mutate(symbol = symbol_from_hgnc_id_grouped(hgnc_id)) %>%
  mutate(hgnc_id = paste0("HGNC:", hgnc_id)) %>%
  mutate(disease_ontology_id = NA) %>%
  mutate(disease_ontology_name = NA) %>%
  mutate(category = "Definitive") %>%
  mutate(pathogenicity_mode = NA) %>%
  arrange(symbol, disease_ontology_id, disease_ontology_name) %>%
  select(symbol, hgnc_id, disease_ontology_id, disease_ontology_name, inheritance, category, pathogenicity_mode, phenotype, publication_id, list, version) %>%
  mutate(import_date = database_file_date) %>%
  mutate(granularity = "gene,phenotype,inheritance(derived),publication,category(implied)")
############################################



############################################
## 6) OMIM (using the HPO phenotype_to_genes table and filtering)

# NDD seed term for the OMIM-NDD comparator (issue #502). Configurable via the
# OMIM_NDD_SEED_TERM env var; default HP:0012759 "Neurodevelopmental
# abnormality". All descendants of the seed are included (single /descendants
# call). Defensible alternatives for a sensitivity sweep: HP:0001249
# "Intellectual disability" (narrower) or HP:0000707 "Abnormality of the nervous
# system" (broader).
ndd_seed_term <- Sys.getenv("OMIM_NDD_SEED_TERM", unset = "HP:0012759")
all_children_list <- list()
HPO_all_children_from_term(ndd_seed_term)
ndd_phenotypes <- all_children_list %>% unique()

# load data files

# deprectaed due to file format changes by HPO
# hpo_phenotype_to_genes_txt <- read_delim(paste0("data/", (ndd_databases_links %>% filter(name == "hpo_phenotype_to_genes"))$file_saved), "\t", 
#   delim = "\t", 
#   escape_double = FALSE, 
#     col_names = c("HPO_id", "HPO_label","entrez_gene_id","entrez_gene_symbol","Additional_Info","Source","disease_ID_link"), 
#   trim_ws = TRUE, 
#   skip = 1)

# new file format
phenotype_hpoa <- read_delim(paste0("data/", (ndd_databases_links %>% filter(name == "phenotype_hpoa"))$file_saved), 
    delim = "\t",
  escape_double = FALSE, 
    trim_ws = TRUE,
  skip = 4)

omim_genemap2 <- read_delim(paste0("data/", (ndd_databases_links %>% filter(name == "omim_genemap2"))$file_saved), "\t", 
    escape_double = FALSE, 
    col_names = FALSE, 
    comment = "#", 
    trim_ws = TRUE) %>%
  select(Chromosome = X1,  Genomic_Position_Start = X2, Genomic_Position_End = X3, Cyto_Location = X4, Computed_Cyto_Location = X5, MIM_Number = X6, Gene_Symbols = X7, Gene_Name = X8, Approved_Symbol = X9, Entrez_Gene_ID = X10, Ensembl_Gene_ID = X11, Comments = X12, Phenotypes = X13, Mouse_Gene_Symbol_ID = X14) %>%
  select(Approved_Symbol, Phenotypes) %>%
  separate_rows(Phenotypes, sep = "; ") %>%
  separate(Phenotypes, c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"), "\\), (?!.+\\))") %>%
  separate(disease_ontology_name, c("disease_ontology_name", "Mapping_key"), "\\((?!.+\\()") %>%
  mutate(Mapping_key = str_replace_all(Mapping_key, "\\)", "")) %>%
  separate(disease_ontology_name, c("disease_ontology_name", "MIM_Number"), ", (?=[0-9][0-9][0-9][0-9][0-9][0-9])") %>%
  mutate(Mapping_key = str_replace_all(Mapping_key, " ", "")) %>%
  mutate(MIM_Number = str_replace_all(MIM_Number, " ", "")) %>%
  filter(!is.na(MIM_Number))  %>%
  filter(!is.na(Approved_Symbol))  %>%
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
  left_join(mode_of_inheritance_list, by=c("hpo_mode_of_inheritance_term_name"))

# deprecated due to file format changes by HPO
# hpo_phenotype_to_genes_omim_ndd <- hpo_phenotype_to_genes_txt %>%
#   filter(Source == "mim2gene") %>%
#   filter(HPO_id %in% ndd_phenotypes) %>%
#   select(disease_ID_link) %>%
#   unique()

phenotype_hpoa_omim_ndd <- phenotype_hpoa %>%
   filter(str_detect(database_id, "OMIM")) %>%
   filter(hpo_id %in% ndd_phenotypes) %>%
   select(database_id) %>%
   unique()

omim_ndd_list <- phenotype_hpoa_omim_ndd %>%
  left_join(omim_genemap2, by = c("database_id" = "disease_ontology_id")) %>%
  filter(!is.na(Approved_Symbol)) %>%
  mutate(list = "omim_ndd") %>%
  mutate(version = (ndd_databases_links %>% filter(name == "hpo_phenotype_to_genes"))$file_saved %>% str_remove(pattern = "\\.txt")) %>%
  mutate(category = "Definitive") %>%
  mutate(hgnc_id = hgnc_id_from_symbol_grouped(Approved_Symbol)) %>%
  mutate(symbol = symbol_from_hgnc_id_grouped(hgnc_id)) %>%
  mutate(hgnc_id = paste0("HGNC:", hgnc_id)) %>%
    mutate(phenotype = NA) %>%
  mutate(pathogenicity_mode = NA) %>%
  mutate(publication_id = NA) %>%
  select(symbol, hgnc_id, disease_ontology_id = database_id, disease_ontology_name, inheritance = hpo_mode_of_inheritance_term_name, category, pathogenicity_mode, phenotype, publication_id, list, version) %>%
  mutate(import_date = database_file_date) %>%
  mutate(granularity = "gene(aggregated),disease,inheritance(aggregated),category(implied)")
  
############################################



############################################
## 7) Orphanet (using the ID app https://id-genes.orphanet.app/ithaca/; JSON response from here: https://id-genes.orphanet.app/es/index/sysid_index_1)

id_genes_orphanet_json_file <- paste(readLines(paste0("data/", (ndd_databases_links %>% filter(name == "orphanet_id"))$file_saved)), collapse="")

id_genes_orphanet_json <- fromJSON(id_genes_orphanet_json_file)

orphanet_id_list <- as_tibble(id_genes_orphanet_json$data) %>%
  mutate(list = "orphanet_id") %>%
  mutate(version = (ndd_databases_links %>% filter(name == "orphanet_id"))$file_saved %>% str_remove(pattern = "\\.json")) %>%
  mutate(category = "Definitive") %>%
  mutate(hgnc_id = hgnc_id_from_symbol_grouped(GeneSymbol)) %>%
  mutate(symbol = symbol_from_hgnc_id_grouped(hgnc_id)) %>%
  mutate(hgnc_id = paste0("HGNC:", hgnc_id)) %>%
  mutate(SourceOfValidation = str_replace_all(SourceOfValidation, " ", "")) %>%
  mutate(DisorderOMIM = str_replace_all(DisorderOMIM, "(?=[1-9][0-9]{5})", "OMIM:")) %>%
  mutate(DisorderOMIM = str_replace_all(DisorderOMIM, ", ", ";")) %>%
  mutate(OrphaCode = str_replace_all(OrphaCode, " ", "")) %>%
  mutate(DisorderGeneAssociationType = str_replace_all(DisorderGeneAssociationType, "<br>", "")) %>%
  mutate(SourceOfValidation = na_if(SourceOfValidation, "NULL")) %>%
  separate_rows(Inheritance, sep = ", ") %>%
  filter(GeneType != "Disorder-associated locus") %>%
  arrange(symbol, OrphaCode, DisorderName) %>%
    mutate(phenotype = NA) %>%
  select(symbol, hgnc_id, disease_ontology_id = OrphaCode, disease_ontology_name = DisorderName, inheritance = Inheritance, category, pathogenicity_mode = DisorderGeneAssociationType, phenotype, publication_id = SourceOfValidation, list, version) %>%
  mutate(import_date = database_file_date) %>%
  mutate(granularity = "gene,disease,inheritance,category(implied),pathogenicity(low-resolution)")

############################################



############################################
## merge all lists
ndd_database_comparison <- radboudumc_list %>%
  bind_rows(gene2phenotype_list) %>%
  bind_rows(panelappID_list) %>%
  bind_rows(sfari_list) %>%
  bind_rows(geisinger_list) %>%
  bind_rows(omim_ndd_list) %>%
  bind_rows(orphanet_id_list) %>%
  mutate(comparison_id = row_number()) %>%
  select(comparison_id, symbol, hgnc_id, disease_ontology_id, disease_ontology_name, inheritance, category, pathogenicity_mode, phenotype, publication_id, list, version, import_date)
############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(ndd_database_comparison, file = paste0("results/ndd_database_comparison.",creation_date,".csv"))
write_csv(ndd_databases_links, file = paste0("results/ndd_databases_links.",creation_date,".csv"))

# save list snapshots as gziped csv
write_csv(radboudumc_list, file = gzfile(paste0("results/downloads/radboudumc_list.",creation_date,".csv.gz")))
write_csv(gene2phenotype_list, file = gzfile(paste0("results/downloads/gene2phenotype_list.",creation_date,".csv.gz")))
write_csv(panelappID_list, file = gzfile(paste0("results/downloads/panelappID_list.",creation_date,".csv.gz")))
write_csv(sfari_list, file = gzfile(paste0("results/downloads/sfari_list.",creation_date,".csv.gz")))
write_csv(geisinger_list, file = gzfile(paste0("results/downloads/geisinger_list.",creation_date,".csv.gz")))
write_csv(omim_ndd_list, file = gzfile(paste0("results/downloads/omim_ndd_list.",creation_date,".csv.gz")))
write_csv(orphanet_id_list, file = gzfile(paste0("results/downloads/orphanet_id_list.",creation_date,".csv.gz")))

############################################