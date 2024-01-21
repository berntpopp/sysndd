
############################################
## load libraries
library(tidyverse)  ## needed for general table operations
library(DBI)        ## needed for MySQL data export
library(RMariaDB)   ## needed for MySQL data export
library(sqlr)       ## needed for MySQL data export
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
## connect to the database
sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = config_vars_proj$dbname_sysndd, user = config_vars_proj$user_sysndd, password = config_vars_proj$password_sysndd, server = config_vars_proj$server_sysndd_local, port = config_vars_proj$port_sysndd_local)
############################################


############################################
## set column types in user table
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY user_id int;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY user_name varchar(50);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY password varchar(50);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY email varchar(50);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY orcid varchar(50);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY abbreviation varchar(50);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY first_name varchar(100);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY family_name varchar(100);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY user_role varchar(20);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY comment varchar(250);")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY terms_agreed tinyint;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY approved tinyint;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY rereview_request tinyint;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY created_at TIMESTAMP;")
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, "ALTER TABLE sysndd_db.user MODIFY password_reset_date TIMESTAMP;")
dbClearResult(rs)
############################################



############################################
## set column types in non_alt_loci_set table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY hgnc_id varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY symbol varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY name varchar(200);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY locus_group varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY locus_type varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY status varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY location varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY location_sortable varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY alias_symbol varchar(200);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY alias_name varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY prev_symbol varchar(200);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY prev_name varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY gene_group varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY gene_group_id varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY date_approved_reserved TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY date_symbol_changed TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY date_name_changed TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY date_modified TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY entrez_id varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY ensembl_gene_id varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY vega_id varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY ucsc_id varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY ena varchar(100);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY refseq_accession varchar(100);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY ccds_id varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY uniprot_ids varchar(100);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY pubmed_id varchar(100);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY mgd_id varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY rgd_id varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY lsdb varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY cosmic varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY omim_id varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY mirbase varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY homeodb varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY snornabase varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY bioparadigms_slc varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY orphanet varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY `pseudogene.org` varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY horde_id varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY merops varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY imgt varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY iuphar varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY kznf_gene_catalog varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY `mamit-trnadb` varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY cd varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY lncrnadb varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY enzyme_id varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY intermediate_filament_db varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY rna_central_ids varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY lncipedia varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY gtrnadb varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY agr varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY mane_select varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY gencc varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY update_date TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY STRING_id varchar(200);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY bed_hg19 varchar(100);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.non_alt_loci_set MODIFY bed_hg38 varchar(100);')
dbClearResult(rs)
############################################


############################################
## set column types in mode_of_inheritance_list table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.mode_of_inheritance_list MODIFY hpo_mode_of_inheritance_term varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.mode_of_inheritance_list MODIFY hpo_mode_of_inheritance_term_name varchar(100);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.mode_of_inheritance_list MODIFY hpo_mode_of_inheritance_term_definition varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.mode_of_inheritance_list MODIFY inheritance_filter varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.mode_of_inheritance_list MODIFY inheritance_short_text varchar(5);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.mode_of_inheritance_list MODIFY is_active tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.mode_of_inheritance_list MODIFY sort int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.mode_of_inheritance_list MODIFY update_date TIMESTAMP;')
dbClearResult(rs)
############################################


############################################
## set column types in disease_ontology_set table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY disease_ontology_id_version varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY disease_ontology_id varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY disease_ontology_name varchar(500);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY disease_ontology_source varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY disease_ontology_date TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY disease_ontology_is_specific tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY hgnc_id varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY hpo_mode_of_inheritance_term varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY DOID varchar(200);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY MONDO varchar(200);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY Orphanet varchar(200);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY EFO varchar(200);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY is_active tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.disease_ontology_set MODIFY update_date TIMESTAMP;')
dbClearResult(rs)
############################################


############################################
## set column types in ndd_entity table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY entity_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY hgnc_id varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY hpo_mode_of_inheritance_term varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY disease_ontology_id_version varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY ndd_phenotype tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY entry_date TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY entry_source varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY entry_user_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY is_active tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity MODIFY replaced_by int;')
dbClearResult(rs)
############################################


############################################
## set column types in ndd_entity_status table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY status_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY entity_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY category_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY is_active tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY status_date TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY status_user_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY status_approved tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY approving_user_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY comment varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status MODIFY problematic tinyint;')
dbClearResult(rs)
############################################


############################################
## set column types in ndd_entity_review table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_review MODIFY review_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_review MODIFY entity_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_review MODIFY synopsis text;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_review MODIFY is_primary tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_review MODIFY review_date TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_review MODIFY review_user_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_review MODIFY review_approved tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_review MODIFY approving_user_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_review MODIFY comment varchar(1000);')
dbClearResult(rs)
############################################


############################################
## set column types in ndd_review_phenotype_connect table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY review_phenotype_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY review_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY phenotype_id varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY modifier_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY entity_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY phenotype_date TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_phenotype_connect MODIFY is_active tinyint;')
dbClearResult(rs)
############################################


############################################
## set column types in phenotype_list table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.phenotype_list MODIFY phenotype_id varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.phenotype_list MODIFY HPO_term varchar(100);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.phenotype_list MODIFY HPO_term_definition varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.phenotype_list MODIFY HPO_term_synonyms varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.phenotype_list MODIFY comment varchar(1000);')
dbClearResult(rs)
############################################


############################################
## set column types in modifier_list table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.modifier_list MODIFY modifier_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.modifier_list MODIFY modifier_name varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.modifier_list MODIFY allowed_phenotype tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.modifier_list MODIFY allowed_variation tinyint;')
dbClearResult(rs)
############################################


############################################
## set column types in ndd_entity_status_categories_list table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status_categories_list MODIFY category_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_entity_status_categories_list MODIFY category varchar(15);')
dbClearResult(rs)
############################################


############################################
## set column types in ndd_review_variation_ontology_connect table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY review_vario_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY review_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY vario_id varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY modifier_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY entity_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY variation_ontology_date TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_variation_ontology_connect MODIFY is_active tinyint;')
dbClearResult(rs)
############################################


############################################
## set column types in variation_ontology_list table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.variation_ontology_list MODIFY vario_id varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.variation_ontology_list MODIFY vario_name varchar(100);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.variation_ontology_list MODIFY definition varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.variation_ontology_list MODIFY obsolete tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.variation_ontology_list MODIFY is_active tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.variation_ontology_list MODIFY sort int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.variation_ontology_list MODIFY update_date TIMESTAMP;')
dbClearResult(rs)
############################################


############################################
## set column types in publication table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY publication_id varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY publication_type varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY other_publication_id varchar(250);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY Title varchar(1000);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY Abstract text;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY `Fulltext` text;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY Publication_date TIMESTAMP;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY Journal_abbreviation varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY Journal varchar(200);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY Keywords text;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY Lastname varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY Firstname varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.publication MODIFY update_date TIMESTAMP;')
dbClearResult(rs)
############################################


############################################
## set column types in ndd_review_publication_join table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_publication_join MODIFY review_publication_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_publication_join MODIFY review_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_publication_join MODIFY entity_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_publication_join MODIFY publication_id varchar(15);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_publication_join MODIFY publication_type varchar(50);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.ndd_review_publication_join MODIFY is_reviewed tinyint;')
dbClearResult(rs)
############################################


############################################
## set column types in boolean_list table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.boolean_list MODIFY boolean_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.boolean_list MODIFY boolean_number int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.boolean_list MODIFY boolean_word varchar(5);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.boolean_list MODIFY word_english varchar(5);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.boolean_list MODIFY logical tinyint;')
dbClearResult(rs)
############################################


############################################
## set column types in allowed_list table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.allowed_list MODIFY allowed_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.allowed_list MODIFY type varchar(10);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.allowed_list MODIFY analysis varchar(20);')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.allowed_list MODIFY value varchar(50);')
dbClearResult(rs)
############################################


############################################
## set column types in re_review_entity_connect table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY re_review_entity_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY entity_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY re_review_batch int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY re_review_review_saved tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY re_review_status_saved tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY re_review_submitted tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY re_review_approved tinyint;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY approving_user_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY status_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_entity_connect MODIFY review_id int;')
dbClearResult(rs)
############################################


############################################
## set column types in re_review_assignment table
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_assignment MODIFY assignment_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_assignment MODIFY user_id int;')
dbClearResult(rs)
rs <- dbSendQuery(sysndd_db, 'ALTER TABLE sysndd_db.re_review_assignment MODIFY re_review_batch int;')
dbClearResult(rs)
############################################



############################################
## create empty hash link table
rs <- dbSendQuery(sysndd_db, 'CREATE TABLE `sysndd_db`.`table_hash` (
  `hash_id` INT NOT NULL AUTO_INCREMENT,
  `hash_256` VARCHAR(64) NULL,
  `json_text` TEXT NULL,
  `target_endpoint` VARCHAR(100) NULL,
  `entry_date` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`hash_id`),
  UNIQUE INDEX `hash_256_UNIQUE` (`hash_256` ASC) VISIBLE);;')
dbClearResult(rs)
############################################



############################################
## close database connection
rm_con()
############################################