# sysndd_plumber.R

##-------------------------------------------------------------------##
# load libraries
library(plumber)
library(tidyverse)
library(DBI)
library(RMariaDB)
library(jsonlite)
library(config)
library(jose)
library(plotly)
library(RCurl)
library(stringdist)
library(xlsx)
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
dw <- config::get("sysndd_db_local")
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## enable cross origin requests
## based on https://github.com/rstudio/plumber/issues/66
#* @filter cors
cors <- function(req, res) {
  
  res$setHeader("Access-Control-Allow-Origin", "*")
  
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods","*")
    res$setHeader("Access-Control-Allow-Headers", req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS)
    res$status <- 200 
    return(list())
  } else {
    plumber::forward()
  }
  
}
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## global variables
inheritance_input_allowed <- c("X-linked", "Dominant", "Recessive", "Other", "All")
output_columns_allowed <- c("category", "inheritance", "symbol", "hgnc_id", "entrez_id", "ensembl_gene_id", "ucsc_id", "bed_hg19", "bed_hg38")
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
#* @apiTitle SysNDD API
#* @apiDescription This is the API powering the SysNDD website and allowing programmatic access to the database contents.
#* @apiVersion 0.1.0
#* @apiTOS http://www.sysndd.org/terms/
#* @apiContact list(name = "API Support", url = "http://www.sysndd.org/support", email = "support@sysndd.org")
#* @apiLicense list(name = "CC BY 4.0", url = "https://creativecommons.org/licenses/by/4.0/")

#* @apiTag entities Entities related endpoints
#* @apiTag publications Publication related endpoints
#* @apiTag genes Gene related endpoints
#* @apiTag ontology Ontology related endpoints
#* @apiTag inheritance Inheritance related endpoints
#* @apiTag phenotypes Phenoptype related endpoints
#* @apiTag authentication Authentication related endpoints
#* @apiTag panels Gene panel related endpoints
#* @apiTag search Database search related endpoints
#* @apiTag statistics Database statistics
#* @apiTag status Status related endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Entity endpoints

#* @tag entities
## get all entities
#* @serializer json list(na="string")
#' @get /api/entities
function() {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	sysndd_db_disease_table <- tbl(sysndd_db, "ndd_entity_view")


	sysndd_db_disease_collected <- sysndd_db_disease_table %>%
		arrange(entity_id) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))
		
	# disconnect from database
	dbDisconnect(sysndd_db)
	
	sysndd_db_disease_collected
}


#* @tag entities
## create a new entity
## example data: {"hgnc_id":"HGNC:21396", "hpo_mode_of_inheritance_term":"HP:0000007", "disease_ontology_id_version":"OMIM:210600", "ndd_phenotype":"1"}
#* @serializer json list(na="string")
#' @post /api/entities/create
function(entity_data) {

	entity_data <- as_tibble(fromJSON(entity_data)) %>%
		select(hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype)

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	dbAppendTable(sysndd_db, "ndd_entity", entity_data)
	dbDisconnect(sysndd_db)
	res <- "Data submitted successfully!"
}


#* @tag entities
## delete an entity
#* @serializer json list(na="string")
#' @delete /api/entities/delete
function(sysndd_id, req, res) {

  if (req$user_role == "Admin"){
    sysndd_id <- as.integer(sysndd_id)
	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	dbExecute(sysndd_db, paste0("DELETE FROM ndd_entity_phenotype_connect WHERE entity_id = ", sysndd_id, ";"))
	dbExecute(sysndd_db, paste0("DELETE FROM ndd_entity_publication_join WHERE entity_id = ", sysndd_id, ";"))
	dbExecute(sysndd_db, paste0("DELETE FROM ndd_entity_status WHERE entity_id = ", sysndd_id, ";"))
	dbExecute(sysndd_db, paste0("DELETE FROM ndd_entity_review WHERE entity_id = ", sysndd_id, ";"))
	dbExecute(sysndd_db, paste0("DELETE FROM ndd_entity WHERE entity_id = ", sysndd_id, ";"))

	dbDisconnect(sysndd_db)
	res <- "Entry deleted."
  } else {
    res$status <- 401 # Unauthorized
  }

}


#* @tag entities
## update an entity
#* @serializer json list(na="string")
#' @put /api/entities/update
function(sysndd_id, entity_data) {

	sysndd_id <- as.integer(sysndd_id)
	
	update_query <- as_tibble(fromJSON(entity_data)) %>%
    select(hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype) %>% 
	mutate(row = row_number()) %>% 
	pivot_longer(-row) %>% 
	mutate(query = paste0(name, "='", value, "'")) %>% 
	select(query) %>% 
	summarise(query = str_c(query, collapse = ", "))
	
	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	dbExecute(sysndd_db, paste0("UPDATE ndd_entity SET ", update_query, " WHERE entity_id = ", sysndd_id, ";"))

	dbDisconnect(sysndd_db)
}


#* @tag entities
## get a single entity
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>
function(sysndd_id) {
	# remove spaces from list
	sysndd_id <- URLdecode(sysndd_id) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all(" ", "") %>%
		unique()


	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	sysndd_db_disease_table <- tbl(sysndd_db, "ndd_entity_view")


	sysndd_db_disease_collected <- sysndd_db_disease_table %>%
		filter(entity_id %in% sysndd_id) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))

	# disconnect from database
	dbDisconnect(sysndd_db)
	
	sysndd_db_disease_collected
}


#* @tag entities
## get all phenotypes for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/phenotypes
function(sysndd_id) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	ndd_entity_phenotype_connect_collected <- tbl(sysndd_db, "ndd_entity_phenotype_connect") %>%
		collect()
	phenotype_list_collected <- tbl(sysndd_db, "phenotype_list") %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	phenotype_list <- ndd_entity_phenotype_connect_collected %>%
		filter(entity_id == sysndd_id) %>%
		inner_join(phenotype_list_collected, by=c("phenotype_id")) %>%
		select(entity_id, phenotype_id, HPO_term, modifier) %>%
		arrange(phenotype_id)
}


#* @tag entities
## get all clinical synopsis for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/review
function(sysndd_id) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	ndd_entity_review_collected <- tbl(sysndd_db, "ndd_entity_review") %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	ndd_entity_review_list <- ndd_entity_review_collected %>%
		filter(entity_id == sysndd_id & is_primary) %>%
		select(entity_id, synopsis, review_date) %>%
		arrange(review_date)
}


#* @tag entities
## post a new clinical synopsis for a entity_id
## example data: {"synopsis":"Hello you cool database", "review_user_id":"1"}
#* @serializer json list(na="string")
#' @post /api/entities/<sysndd_id>/review
function(sysndd_id, synopsis_in) {

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	new_review <- as_tibble(fromJSON(synopsis_in)) %>% 
		add_column(sysndd_id) %>% 
		select(entity_id = sysndd_id, synopsis, review_user_id)
	dbAppendTable(sysndd_db, "ndd_entity_review", new_review)
}


#* @tag entities
## get status for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/status
function(sysndd_id) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	ndd_entity_status_collected <- tbl(sysndd_db, "ndd_entity_status") %>%
		collect()
	ndd_entity_status_categories_collected <- tbl(sysndd_db, "ndd_entity_status_categories_list") %>%
		collect()
		
	# disconnect from database
	dbDisconnect(sysndd_db)

	ndd_entity_status_list <- ndd_entity_status_collected %>%
		filter(entity_id == sysndd_id & is_active) %>%
		inner_join(ndd_entity_status_categories_collected, by=c("category_id")) %>%
		select(entity_id, category, category_id, status_date) %>%
		arrange(status_date)
}


#* @tag entities
## post a new status for a entity_id
## example data: {"category_id":"1", "status_user_id":"1"}
#* @serializer json list(na="string")
#' @post /api/entities/<sysndd_id>/status
function(sysndd_id, category_in) {

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	new_status <- as_tibble(fromJSON(category_in)) %>% 
		add_column(sysndd_id) %>% 
		select(entity_id = sysndd_id, category_id, status_user_id)
	dbAppendTable(sysndd_db, "ndd_entity_status", new_status)
}


#* @tag entities
## get all publications for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/publications
function(sysndd_id) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	ndd_entity_publication_join_collected <- tbl(sysndd_db, "ndd_entity_publication_join") %>%
		collect()
	publication_collected <- tbl(sysndd_db, "publication") %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	ndd_entity_publication_list <- ndd_entity_publication_join_collected %>%
		filter(entity_id == sysndd_id) %>%
		arrange(publication_id)
}

## Entity endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Publication endpoints

#* @tag publications
## get a publication by pmid
#* @serializer json list(na="string")
#' @get /api/publications/<pmid>
function(pmid) {

	pmid <- URLdecode(pmid) %>%
		str_replace_all("[^0-9]+", "")
	pmid <- paste0("PMID:",pmid)
		

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	publication_collected <- tbl(sysndd_db, "publication") %>%
		filter(publication_id == pmid) %>%
		select(publication_id, other_publication_id, Title, Abstract, Lastname, Firstname, Publication_date, Journal, Keywords) %>%
		arrange(publication_id) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	publication_collected
}

## Publication endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Gene endpoints

#* @tag genes
## get all genes and associated entities
#* @serializer json list(na="string")
#' @get /api/genes
function() {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	sysndd_db_genes_table <- tbl(sysndd_db, "ndd_entity_view")

	sysndd_db_genes_collected <- sysndd_db_genes_table %>%
		arrange(entity_id) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		)) %>%
		nest_by(symbol, hgnc_id, category, hpo_mode_of_inheritance_term_name, hpo_mode_of_inheritance_term, .key = "entities")
		
	# disconnect from database
	dbDisconnect(sysndd_db)
	
	sysndd_db_genes_collected
}


#* @tag genes
## get infos for a single gene by hgnc_id
#* @serializer json list(na="string")
#' @get /api/genes/<hgnc>
function(hgnc) {

	hgnc <- URLdecode(hgnc) %>%
		str_replace_all("[^0-9]+", "")
	hgnc <- paste0("HGNC:",hgnc)
		

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	non_alt_loci_set_collected <- tbl(sysndd_db, "non_alt_loci_set") %>%
		filter(hgnc_id == hgnc) %>%
		select(hgnc_id, symbol, name, entrez_id, ensembl_gene_id, ucsc_id, ccds_id, uniprot_ids) %>%
		arrange(hgnc_id) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	non_alt_loci_set_collected
}


#* @tag genes
## get all entities for a single gene by hgnc_id
#* @serializer json list(na="string")
#' @get /api/genes/<hgnc>/entities
function(hgnc) {

	hgnc <- URLdecode(hgnc) %>%
		str_replace_all("[^0-9]+", "")
	hgnc <- paste0("HGNC:",hgnc)

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	entity_by_gene_list <- tbl(sysndd_db, "ndd_entity_view") %>%
		filter(hgnc_id == hgnc) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))

	# disconnect from database
	dbDisconnect(sysndd_db)

	entity_by_gene_list
}

## Gene endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Ontology endpoints

#* @tag ontology
## get an ontology entry by disease_ontology_id_version
#* @serializer json list(na="string")
#' @get /api/ontology/<ontology_id>
function(ontology_id) {

	ontology_id <- URLdecode(ontology_id)

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	ontology_set_collected <- tbl(sysndd_db, "ontology_set") %>%
		filter(disease_ontology_id == ontology_id) %>%
		select(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, disease_ontology_source, disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term, DOID, MONDO, Orphanet, UMLS, EFO) %>%
		arrange(disease_ontology_id_version) %>%
		collect() %>%
		group_by(disease_ontology_id) %>%
		summarise_all(~paste(unique(.), collapse = ';')) %>%
		ungroup() %>%
		mutate(across(everything(), ~replace(., . ==  "NULL" , "")))

	# disconnect from database
	dbDisconnect(sysndd_db)

	ontology_set_collected
}

## Ontology endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Inheritance endpoints

#* @tag inheritance
## get a inheritance by hpo_id
#* @serializer json list(na="string")
#' @get /api/inheritance/<hpo>
function(hpo) {

	hpo <- URLdecode(hpo) %>%
		str_replace_all("[^0-9]+", "")
	hpo <- paste0("HP:",hpo)
		

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	mode_of_inheritance_list_collected <- tbl(sysndd_db, "mode_of_inheritance_list") %>%
		filter(hpo_mode_of_inheritance_term == hpo) %>%
		select(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name) %>%
		arrange(hpo_mode_of_inheritance_term) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	mode_of_inheritance_list_collected
}

## Inheritance endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Phenotype endpoints

#* @tag phenotypes
## get list of all phenotypes
#* @serializer json list(na="string")
#' @get /api/phenotypes_list
function() {
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	phenotype_list_collected <- tbl(sysndd_db, "phenotype_list") %>%
		select(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms) %>%
		arrange(HPO_term) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	phenotype_list_collected
}


#* @tag phenotypes
## get a phenotype by hpo_id
#* @serializer json list(na="string")
#' @get /api/phenotypes/<hpo>
function(hpo) {

	hpo <- URLdecode(hpo) %>%
		str_replace_all("[^0-9]+", "")
	hpo <- paste0("HP:",hpo)
		

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	phenotype_list_collected <- tbl(sysndd_db, "phenotype_list") %>%
		filter(phenotype_id == hpo) %>%
		select(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms) %>%
		arrange(phenotype_id) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	phenotype_list_collected
}


#* @tag phenotypes
## get a list of entities associated with a list of phenotypes
#* @serializer json list(na="string")
#' @get /api/phenotypes/<hpo_list>/entities
function(hpo_list) {

	hpo_list <- URLdecode(hpo_list) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all("[^0-9]+", "") %>%
		str_replace("^", "HP:") %>%
		unique()
		

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	entity_list_from_phenotype_list_collected <- tbl(sysndd_db, "ndd_entity_phenotype_connect") %>%
		filter(phenotype_id %in% hpo_list) %>%
		arrange(phenotype_id) %>%
		select(entity_id, phenotype_id) %>%
		collect() %>%
		unique() %>%
		arrange(entity_id) %>%
		mutate(found=TRUE) %>%
		pivot_wider(names_from = phenotype_id, values_from = found) %>%
		replace(., is.na(.), FALSE) %>%
		pivot_longer(-entity_id, names_to =c("phenotype_id")) %>%
		select(-phenotype_id) %>%
		group_by(entity_id) %>%
		summarise(value = all(value)) %>%
		filter(value) %>%
		select(entity_id) %>%
		ungroup()

	# disconnect from database
	dbDisconnect(sysndd_db)

	entity_list_from_phenotype_list_collected
}

## Phenotype endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Status endpoints

#* @tag status
## get list of all status
#* @serializer json list(na="string")
#' @get /api/status_list
function() {
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	status_list_collected <- tbl(sysndd_db, "ndd_entity_status_categories_list") %>%
		select(category_id, category) %>%
		arrange(category_id) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	status_list_collected
}
## status endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Panels endpoints

#* @tag panels
## get list of all panel api options
#* @serializer json list(na="string")
#' @get /api/panels/options
function() {
	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	# get category list
	categories_list <- tbl(sysndd_db, "ndd_entity_status_categories_list") %>%
		select(category) %>%
		collect() %>%
		add_row(category = "All") %>%
		arrange(category)

	# disconnect from database
	dbDisconnect(sysndd_db)
	
	inheritance_list <- as_tibble(inheritance_input_allowed) %>%
		select(inheritance = value) %>%
		arrange(inheritance)

	columns_list <- as_tibble(output_columns_allowed) %>%
		select(column = value)

	options <- tibble(
	  lists = c("categories_list", "inheritance_list", "columns_list"),
	  options = list(
		tibble(value = categories_list$category),
		tibble(value = inheritance_list$inheritance),
		tibble(value = columns_list$column)
	  )
	)
	
	options
}


#* @tag panels
## get last n entries in definitive category as news
#* @serializer json list(na="string")
#* @param category_input The entity association category to filter.
#* @param inheritance_input The entity inheritance type to filter.
#* @param output_columns Comma separated list of output columns (choose from: category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38).
#* @param output_sort Output column to arrange output on (choose from: category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38).
#' @get /api/panels
function(category_input = "Definitive", inheritance_input = "All", output_columns = "category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38", output_sort = "symbol", res) {
	
	output_columns_list <- URLdecode(output_columns) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all(" ", "") %>%
		unique()

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	# validate inputs
	ndd_entity_status_categories_list <- tbl(sysndd_db, "ndd_entity_status_categories_list") %>%
		select(category) %>%
		collect() %>%
		add_row(category = "All")

	if ( !(Reduce("&", output_columns_list %in% output_columns_allowed)) | !(Reduce("&", output_sort %in% output_columns_allowed)) ) {
		res$status <- 400
		res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
		status = 400,
		message = paste0("Input for 'output_columns' or 'output_sort' parameter not in list of allowed columns (allowed values=", paste0(output_columns_allowed, collapse=","), ").")
		))
		return(res)
	}

	if ( !(category_input %in% ndd_entity_status_categories_list$category) ) {
		res$status <- 400
		res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
		status = 400,
		message = paste0("Required 'category_input' parameter not in categories list (allowed values=", paste0(ndd_entity_status_categories_list$category, collapse=","), ").")
		))
		return(res)
	}
	
	if ( !(inheritance_input %in% inheritance_input_allowed) ) {
		res$status <- 400
		res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
		status = 400,
		message = paste0("Required 'inheritance_input' parameter not in categories list (allowed values=", paste0(inheritance_input_allowed, collapse=","), ").")
		))
		return(res)
	}
	
	# join entity_view and non_alt_loci_set tables
	sysndd_db_ndd_entity_view <- tbl(sysndd_db, "ndd_entity_view") %>%
		filter(ndd_phenotype == 1) %>%
		select(hgnc_id, symbol, inheritance = hpo_mode_of_inheritance_term_name, category)
	sysndd_db_non_alt_loci_set <- tbl(sysndd_db, "non_alt_loci_set") %>%
		select(hgnc_id, entrez_id, ensembl_gene_id, ucsc_id, bed_hg19, bed_hg38)
	
	sysndd_db_disease_genes <- sysndd_db_ndd_entity_view %>%
		left_join(sysndd_db_non_alt_loci_set, by =c("hgnc_id")) %>%
		collect() %>%
		unique() %>%
		mutate(inheritance = case_when(
		  str_detect(inheritance, "X-linked") ~ "X-linked",
		  str_detect(inheritance, "Autosomal dominant inheritance") ~ "Dominant",
		  str_detect(inheritance, "Autosomal recessive inheritance") ~ "Recessive",
		  TRUE ~ "Other"
		)) %>%
		select(category, inheritance, symbol, hgnc_id, entrez_id, ensembl_gene_id, ucsc_id, bed_hg19, bed_hg38) %>%
		arrange(desc(category), inheritance)

	# disconnect from database
	dbDisconnect(sysndd_db)
	
	# compute output based on input parameters
	
	if ( (category_input == "All") & (inheritance_input == "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(category = "All") %>%
			mutate(inheritance = "All") %>%
			unique() %>%
			filter(category == category_input, inheritance == inheritance_input) %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else if ( (category_input == "All") & (inheritance_input != "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(category = "All") %>%
			unique() %>%
			filter(category == category_input, inheritance == inheritance_input) %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else if ( (category_input != "All") & (inheritance_input == "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(inheritance = "All") %>%
			unique() %>%
			filter(category == category_input, inheritance == inheritance_input) %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			unique() %>%
			filter(category == category_input, inheritance == inheritance_input) %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	}

	sysndd_db_disease_genes_panel
}



#* @tag panels
## get last n entries in definitive category as news
#* @serializer contentType list(type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
#* @param category_input The entity association category to filter.
#* @param inheritance_input The entity inheritance type to filter.
#* @param output_columns Comma separated list of output columns (choose from: category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38).
#* @param output_sort Output column to arrange output on (choose from: category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38).
#' @get /api/panels/excel
function(category_input = "Definitive", inheritance_input = "All", output_columns = "category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38", output_sort = "symbol", res) {
	
	output_columns_list <- URLdecode(output_columns) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all(" ", "") %>%
		unique()

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	# validate inputs
	ndd_entity_status_categories_list <- tbl(sysndd_db, "ndd_entity_status_categories_list") %>%
		select(category) %>%
		collect() %>%
		add_row(category = "All")

	if ( !(Reduce("&", output_columns_list %in% output_columns_allowed)) | !(Reduce("&", output_sort %in% output_columns_allowed)) ) {
		res$status <- 400
		res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
		status = 400,
		message = paste0("Input for 'output_columns' or 'output_sort' parameter not in list of allowed columns (allowed values=", paste0(output_columns_allowed, collapse=","), ").")
		))
		return(res)
	}

	if ( !(category_input %in% ndd_entity_status_categories_list$category) ) {
		res$status <- 400
		res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
		status = 400,
		message = paste0("Required 'category_input' parameter not in categories list (allowed values=", paste0(ndd_entity_status_categories_list$category, collapse=","), ").")
		))
		return(res)
	}
	
	if ( !(inheritance_input %in% inheritance_input_allowed) ) {
		res$status <- 400
		res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
		status = 400,
		message = paste0("Required 'inheritance_input' parameter not in categories list (allowed values=", paste0(inheritance_input_allowed, collapse=","), ").")
		))
		return(res)
	}
	
	# join entity_view and non_alt_loci_set tables
	sysndd_db_ndd_entity_view <- tbl(sysndd_db, "ndd_entity_view") %>%
		filter(ndd_phenotype == 1) %>%
		select(hgnc_id, symbol, inheritance = hpo_mode_of_inheritance_term_name, category)
	sysndd_db_non_alt_loci_set <- tbl(sysndd_db, "non_alt_loci_set") %>%
		select(hgnc_id, entrez_id, ensembl_gene_id, ucsc_id, bed_hg19, bed_hg38)
	
	sysndd_db_disease_genes <- sysndd_db_ndd_entity_view %>%
		left_join(sysndd_db_non_alt_loci_set, by =c("hgnc_id")) %>%
		collect() %>%
		unique() %>%
		mutate(inheritance = case_when(
		  str_detect(inheritance, "X-linked") ~ "X-linked",
		  str_detect(inheritance, "Autosomal dominant inheritance") ~ "Dominant",
		  str_detect(inheritance, "Autosomal recessive inheritance") ~ "Recessive",
		  TRUE ~ "Other"
		)) %>%
		select(category, inheritance, symbol, hgnc_id, entrez_id, ensembl_gene_id, ucsc_id, bed_hg19, bed_hg38) %>%
		arrange(desc(category), inheritance)

	# disconnect from database
	dbDisconnect(sysndd_db)
	
	# compute output based on input parameters
	
	if ( (category_input == "All") & (inheritance_input == "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(category = "All") %>%
			mutate(inheritance = "All") %>%
			unique() %>%
			filter(category == category_input, inheritance == inheritance_input) %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else if ( (category_input == "All") & (inheritance_input != "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(category = "All") %>%
			unique() %>%
			filter(category == category_input, inheritance == inheritance_input) %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else if ( (category_input != "All") & (inheritance_input == "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(inheritance = "All") %>%
			unique() %>%
			filter(category == category_input, inheritance == inheritance_input) %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			unique() %>%
			filter(category == category_input, inheritance == inheritance_input) %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	}

	# generate request statistic for output
	creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%dT %H:%M:%S")
	
	request_stats <- tibble(
	  creation_date = creation_date, 
	  category_input = category_input, 
	  inheritance_input = inheritance_input,
	  output_columns = output_columns,
	  output_sort = output_sort,
	) %>%
    pivot_longer(everything(), names_to = "request", values_to = "value")

	# generate excel file output
	filename <- file.path(tempdir(), "panel.xlsx")
	write.xlsx(sysndd_db_disease_genes_panel, filename, sheetName="sysndd", append=FALSE)
	write.xlsx(request_stats, filename, sheetName="request", append=TRUE)
	attachmentString = paste0("attachment; filename=panel.xlsx", filename)
		  
	res$setHeader("Content-Disposition", attachmentString)
		  
	# Read in the raw contents of the binary file
	bin <- readBin(filename, "raw", n=file.info(filename)$size)

	#Check file existence and delete
	if (file.exists(filename)) {
	  file.remove(filename)
	}

	#Return the binary contents
	bin
}
## Panels endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Statistics endpoints

#* @tag statistics
## get statistics for all genes assoicated with a NDD phenotype by inheritance and assocation category
#* @serializer json list(na="string")
#' @get /api/statistics/genes
function() {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	
	sysndd_db_disease_genes <- tbl(sysndd_db, "ndd_entity_view") %>%
		arrange(entity_id) %>%
		filter(ndd_phenotype == 1) %>%
		select(symbol, inheritance = hpo_mode_of_inheritance_term_name, category) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)
	
	sysndd_db_disease_genes_grouped_by_category_and_inheritance <- sysndd_db_disease_genes %>%
		unique() %>% 
		mutate(inheritance = case_when(
		  str_detect(inheritance, "X-linked") ~ "X-linked",
		  str_detect(inheritance, "Autosomal dominant inheritance") ~ "Dominant",
		  str_detect(inheritance, "Autosomal recessive inheritance") ~ "Recessive",
		  TRUE ~ "Other"
		)) %>% 
		group_by(category, inheritance) %>%
		tally() %>%
		ungroup() %>%
		arrange(desc(category), desc(n)) %>% 
		group_by(category) %>% 
		nest() %>% 
		ungroup() %>%
		select(category, groups = data)

	sysndd_db_disease_genes_grouped_by_category <- sysndd_db_disease_genes %>% 
		select(-inheritance) %>%
		unique() %>%
		group_by(category) %>%
		tally() %>%
		ungroup() %>%
		arrange(desc(category), desc(n)) %>%
		group_by(category) %>%
		mutate(inheritance = "All")
		
	sysndd_db_disease_genes_statistics <- sysndd_db_disease_genes_grouped_by_category %>%
		left_join(sysndd_db_disease_genes_grouped_by_category_and_inheritance, by = c("category"))

	sysndd_db_disease_genes_statistics
}


#* @tag statistics
## get last n entries in definitive category as news
#* @serializer json list(na="string")
#' @get /api/statistics/news
function(n = 5) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	
	sysndd_db_disease_genes_news <- tbl(sysndd_db, "ndd_entity_view") %>%
		arrange(entity_id) %>%
		filter(ndd_phenotype == 1 & category == "Definitive") %>%
		collect() %>%
		arrange(desc(entry_date)) %>%
		slice(1:n)
		
	# disconnect from database
	dbDisconnect(sysndd_db)

	sysndd_db_disease_genes_news
}


#* @tag statistics
## get date of last update
#* @serializer json list(na="string")
#' @get /api/statistics/last_update
function() {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	
	sysndd_db_disease_entry_date_last <- tbl(sysndd_db, "ndd_entity_view") %>%
		select(entry_date) %>%
		arrange(desc(entry_date)) %>%
		head(1) %>%
		collect() %>%
		select(last_update = entry_date)
		
	# disconnect from database
	dbDisconnect(sysndd_db)

	sysndd_db_disease_entry_date_last
}


#* @tag statistics
## Return interactive plot showing the database entry development over time using plotly
#* @serializer text
#' @get /api/statistics/entities_plot
function() {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	
	sysndd_db_disease_collected <- tbl(sysndd_db, "ndd_entity_view") %>%
		arrange(entity_id) %>%
		select(entity_id, ndd_phenotype, category, entry_date) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		)) %>%
		filter(ndd_phenotype == "Yes")
  
	# disconnect from database
	dbDisconnect(sysndd_db)

	plot <- ggplot(data = sysndd_db_disease_collected , aes(x = entry_date, color = category)) +
		stat_bin(data=subset(sysndd_db_disease_collected, category=="Definitive"), aes(y=cumsum(..count..)), geom="step", bins = 30) +
		stat_bin(data=subset(sysndd_db_disease_collected, category=="Candidate"), aes(y=cumsum(..count..)), geom="step", bins = 30) +
		theme_classic() +
		theme(axis.text.x = element_text(angle = -45, hjust = 0), axis.title.x = element_blank(), axis.title.y = element_blank(), legend.position="top", legend.title = element_blank())

	file <- "results/plot.png"
	ggsave(file, plot, width = 4.5, height = 2.5, dpi = 150, units = "in")
	base64Encode(readBin(file, "raw", n = file.info(file)$size), "txt")

}

## Statistics endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Search endpoints

#* @tag search
## searchthe entity view by by columns entity_id, hgnc_id, symbol, disease_ontology_id_version, disease_ontology_name
#* @serializer json list(na="string")
#' @get /api/search/<searchterm>
function(searchterm, helper = TRUE) {

	searchterm <- URLdecode(searchterm) %>%
		str_squish()
	
	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	sysndd_db_entity_search <- tbl(sysndd_db, "ndd_entity_view") %>%
		arrange(entity_id) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		)) %>%
		select(entity_id, hgnc_id, symbol, disease_ontology_id_version, disease_ontology_name) %>%
		mutate(entity = as.character(entity_id)) %>%
		pivot_longer(!entity_id, names_to = "search", values_to = "results") %>%
		mutate(search = str_replace(search, "entity", "entity_id")) %>%
		mutate(searchdist = stringdist(str_to_lower(results), str_to_lower(searchterm), method='jw', p=0.1)) %>%
		arrange(searchdist, results)
		
	# disconnect from database
	dbDisconnect(sysndd_db)

	# change output by helper input to unique values (helper = TRUE) or entities (helper = FALSE)
	if (helper) {
		sysndd_db_entity_search_helper <- sysndd_db_entity_search %>% 
			select(-entity_id) %>%
			unique()
	} else {
		sysndd_db_entity_search_helper <- sysndd_db_entity_search
	}

	# compute filtered length with match < 0.1
	sysndd_db_entity_search_length <- sysndd_db_entity_search_helper %>%
		filter(searchdist < 0.1) %>%
		tally()
	
	if (sysndd_db_entity_search_length$n > 10) {
		return_count <- sysndd_db_entity_search_length$n
	} else {
		return_count <- 10
	}
	
	# check if perfect match exists
	if (sysndd_db_entity_search$searchdist[1] == 0) {
		sysndd_db_entity_search_return <- sysndd_db_entity_search_helper %>%
			slice_head(n=1)
	} else {
		sysndd_db_entity_search_return <- sysndd_db_entity_search_helper %>% 
			slice_head(n=return_count)
	}

	# change output by helper input to unique values (helper = TRUE) or entities (helper = FALSE)
	if (helper) {
		(sysndd_db_entity_search_return %>% 
				select(results) %>% 
				as.list())$results
	} else {
		sysndd_db_entity_search_return
	}

}

## Search endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
##Authentication section

#* @tag authentication
## authentication create user
## example data: {"user_name":"nextuser", "password":"pass", "email":"me@aol.com"}
#* @serializer json list(na="string")
#' @post /api/auth/signup
function(signup_data) {
	user <- as_tibble(fromJSON(signup_data)) %>%
		select(user_name, password, email)

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	dbAppendTable(sysndd_db, "user", user)
	dbDisconnect(sysndd_db)
	res <- "Registered successfully!"
}


#* @tag authentication
## authentication login user
## example data: {"user_name":"Bernt", "password":"password"}
## based on https://github.com/jandix/sealr/blob/master/examples/jwt_simple_example.R
#* @serializer json list(na="string")
#' @get /api/auth/authenticate
function(req, res, user_name, password) {
	
	check_user <- user_name
	check_pass <- password
	
	# load secret and convert to raw
	key <- charToRaw(dw$secret)
	
	# check if user provided credentials
		  if (is.null(check_user) || is.null(check_pass)) {
			res$status <- 404
			res$body <- "Please return username and password."
			res
		  }

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
	
	# find user in database and password is correct
	user_filtered <- tbl(sysndd_db, "user") %>%
		filter(user_name == check_user & password == check_pass) %>%
		select(-password, -created_at) %>%
		collect() %>%
		mutate(iat = as.numeric(Sys.time())) %>%
		mutate(exp = as.numeric(Sys.time()) + 120)
		
	dbDisconnect(sysndd_db)
	
		  if (nrow(user_filtered) != 1){
			res$status <- 401
			res$body <- "User or password wrong."
			res
			}
	
	
		  if (nrow(user_filtered) == 1){
			claim <- jwt_claim(user_id = user_filtered$user_id, user_name = user_filtered$user_name, email = user_filtered$email, user_role = user_filtered$user_role, iat = user_filtered$iat, exp = user_filtered$exp)
			
			jwt <- jwt_encode_hmac(claim, secret = key)
			jwt
			}
}


#* @tag authentication
#* @get /api/auth/signin
#* @serializer json list(na="string")
function(req, res) {

	# load secret and convert to raw
	key <- charToRaw(dw$secret)
	
	# load jwt from cookie
	jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
	
	user <- jwt_decode_hmac(jwt, secret = key)
	user$token_expired = (user$exp < as.numeric(Sys.time()))
	
	if (is.null(jwt) || user$token_expired){
		res$status <- 401 # Unauthorized
		return(list(error="Authentication not successful."))
	} else {
		return(list(user_name = user$user_name, user_role = user$user_role, user_id = user$user_id, exp = user$exp))
	}
	
}

##Authentication section
##-------------------------------------------------------------------##

