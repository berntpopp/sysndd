# sysndd_plumber.R

##-------------------------------------------------------------------##
# load libraries
library(plumber)
library(tidyverse)
library(DBI)
library(RMariaDB)
library(jsonlite)
library(config)
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
dw <- config::get("sysndd_db")
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## enable cross origin requests
#* @filter cors
cors <- function(res) {
    res$setHeader("Access-Control-Allow-Origin", "*")
    plumber::forward()
}
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Entity endpoints

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



## delete an entity
#* @serializer json list(na="string")
#' @delete /api/entities/delete
function(sysndd_id) {

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
}



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



## post a new all clinical synopsis for a entity_id
## example data: {"synopsis":"Hello you cool database"}
#* @serializer json list(na="string")
#' @post /api/entities/<sysndd_id>/review
function(sysndd_id, synopsis_in) {

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	new_review <- as_tibble(fromJSON(synopsis_in)) %>% 
		add_column(sysndd_id) %>% 
		select(entity_id = sysndd_id, synopsis)
	dbAppendTable(sysndd_db, "ndd_entity_review", new_review)
}



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
		select(entity_id, category, status_date) %>%
		arrange(status_date)
}



## post a new status for a entity_id
## example data: {"category_id":"1", "status_user_id":"1"}
#* @serializer json list(na="string")
#' @post /api/entities/<sysndd_id>/status
function(sysndd_id, category_in) {

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	new_status <- as_tibble(fromJSON(category_in)) %>% 
		add_column(sysndd_id) %>% 
		select(entity_id = sysndd_id, category_id, status_user_id, approving_user_id)
	dbAppendTable(sysndd_db, "ndd_entity_status", new_status)
}



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

## Gene endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Ontology endpoints

## get an ontology entry by disease_ontology_id_version
#* @serializer json list(na="string")
#' @get /api/ontology/<o_id_v>
function(o_id_v) {

	o_id_v <- URLdecode(o_id_v)

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	ontology_set_collected <- tbl(sysndd_db, "ontology_set") %>%
		filter(disease_ontology_id_version == o_id_v) %>%
		select(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, disease_ontology_source, disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term) %>%
		arrange(disease_ontology_id_version) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	ontology_set_collected
}

## Ontology endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Inheritance endpoints

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

## get list of all phenotypes
#* @serializer json list(na="string")
#' @get /api/phenotypes
function() {
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	phenotype_list_collected <- tbl(sysndd_db, "phenotype_list") %>%
		select(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms) %>%
		arrange(phenotype_id) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	phenotype_list_collected
}


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
##Authentication section

## athentication create user
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



## athentication login user
## example data: {"user_name":"Bernt", "password":"password"}
## based on https://github.com/jandix/sealr/blob/master/examples/jwt_simple_example.R
#* @serializer json list(na="string")
#' @post /api/auth/signin
function(req, res, signin_data) {
	signin_data <- as_tibble(fromJSON(signin_data)) %>%
		select(user_name, password)
	check_user <- signin_data$user_name
	check_pass <- signin_data$password
	
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
		collect()
		
		  if (nrow(user_filtered) != 1){
			res$status <- 401
			res$body <- "User or password wrong."
			dbDisconnect(sysndd_db)
			res
			}
	
	
		  if (nrow(user_filtered) == 1){
			return(user_filtered)
			dbDisconnect(sysndd_db)
			}
}

##Authentication section
##-------------------------------------------------------------------##