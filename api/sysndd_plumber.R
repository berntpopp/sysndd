# sysndd_plumber.R
## to do: adapt "serializer json list(na="null")"
## to do: add pool library for connection managment


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
library(easyPubMed)
library(rvest)
library(lubridate)
library(pool)
library(memoise)
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
dw <- config::get("sysndd_db_local")
##-------------------------------------------------------------------##


##-------------------------------------------------------------------##
pool <- dbPool(
  drv = RMariaDB::MariaDB(),
  dbname = dw$dbname,
  host = dw$host,
  user = dw$user,
  password = dw$password,
  server = dw$server,
  port = dw$port
  
)
##-------------------------------------------------------------------##


##-------------------------------------------------------------------##
# Define functions
nest_gene_tibble <- function(tibble) {
	nested_tibble <- tibble %>%
		nest_by(symbol, hgnc_id, category, hpo_mode_of_inheritance_term_name, hpo_mode_of_inheritance_term, .key = "entities")

	return(nested_tibble)
}

# Memoisize function ------------------------------------------------------
nest_gene_tibble_mem <- memoise(nest_gene_tibble)
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
## define global functions

## pubmed and genereviews functions
pubmed_info_from_pmid <- function(pmid_tibble, request_max = 200) {
	input_tibble <- as_tibble(pmid_tibble) %>%
		mutate(publication_id = as.character(value)) %>%
		mutate(publication_id = str_remove(publication_id, "PMID:")) %>%
		select(-value)
	
	row_number <- nrow(input_tibble)
	groups_number <- ceiling(row_number/request_max)
	
	input_tibble_request <- input_tibble %>%
		mutate(group = sample(1:groups_number, row_number, replace=T)) %>%
		group_by(group) %>%
		mutate(publication_id = paste0(publication_id, "[PMID]")) %>%
		mutate(publication_id = str_flatten(publication_id, collapse = " or ")) %>%
		unique() %>%
		ungroup() %>%
		rowwise() %>%
		mutate(response = fetch_pubmed_data(get_pubmed_ids(publication_id), encoding = "ASCII")) %>%
		ungroup() %>%
		mutate(new_PM_df = map(response, ~table_articles_byAuth(pubmed_data = .x, 
                                   included_authors = "first", 
                                   max_chars = 1000, 
                                   encoding = "ASCII"))) %>%
		unnest(cols = new_PM_df) %>%
		select(-publication_id, -group, -response) %>%
		select(publication_id = pmid, DOI = doi, Title = title, Abstract = abstract, Year = year, Month = month, Day = day, Journal_abbreviation = jabbrv, Journal = journal, Keywords= keywords, Lastname = lastname, Firstname = firstname)

	ouput_tibble <- input_tibble %>%
		left_join(input_tibble_request, by = "publication_id")
	
	return(ouput_tibble)
}


genereviews_from_pmid <- function(pmid_input)  {
	url_request <- paste0("https://www.ncbi.nlm.nih.gov/books/NBK1116/?term=", pmid_input)
	url_request = url(url_request, "rb")

	webpage_request <- xml2::read_html(url_request, options = c("RECOVER"))
	
	Bookshelf_ID <- webpage_request %>% 
		html_nodes("div.rslt") %>%
		html_nodes("p.title") %>% 
		html_nodes("a") %>% 
		html_attr('href') %>%
		str_replace("/books/", "") %>%
		str_replace("/", "")
	
	Bookshelf_ID_tibble <- as_tibble(Bookshelf_ID)
	Bookshelf_IDs <- str_c(Bookshelf_ID_tibble$value, collapse = ",")
	
	close(url_request)
	return(Bookshelf_IDs)
}


info_from_genereviews <- function(Bookshelf_ID)  {
	genereviews_url <- paste0("https://www.ncbi.nlm.nih.gov/books/", Bookshelf_ID)
	genereviews_url = url(genereviews_url, "rb")

	genereviews_request <- xml2::read_html(genereviews_url, options = "RECOVER")

	pmid <- genereviews_request %>% 
		html_nodes("div.small") %>%
		html_nodes("span.label") %>%
		html_nodes("a") %>%
		html_attr('href') %>%
		str_replace("/pubmed/", "") %>%
		str_replace("/", "")
		
	title <- genereviews_request %>% 
		html_nodes("title") %>%
		str_replace_all("title", "") %>%
		str_replace_all("\\/", "") %>%
		str_replace_all("<>", "") %>%
		str_replace_all(" -.+", "")

	abstract <- genereviews_request %>% 
		html_nodes(xpath = "//div[contains(h2, 'Summary')]") %>%
		str_replace_all("<.+?>", "") %>%
		str_replace_all("\n", " ") %>%
		str_squish()

	date_revision <- genereviews_request %>% 
		html_nodes(xpath = "//div[contains(h3, 'Revision History')]") %>%
		str_replace_all("<.+?>", "") %>%
		str_replace_all("\n", " ") %>%
		str_replace_all("Revision History", "") %>%
		str_replace_all("Review posted live", "") %>%
		str_replace_all("\\(.+", "") %>%
		str_squish()

	authors <- genereviews_request %>%
		html_nodes("div") %>%
		html_nodes("[itemprop='author']")

	first_author <- authors[1] %>%
		str_replace_all("<.+?>", "") %>%
		str_squish()

	keywords <- genereviews_request %>%
		html_nodes("[name='citation_keywords']") %>%
		html_attr('content') %>%
		str_c(collapse = "; ")

	return_tibble <- as_tibble_row(c("publication_id" = pmid, "Bookshelf_ID" = Bookshelf_ID, "Title" = title, "Abstract" = abstract, "Date" = date_revision, "First_author" = first_author, "Keywords" = keywords)) %>%
		separate(Date, c("Day", "Month", "Year"), sep = " ") %>%
		mutate(Month = match(Month, month.name)) %>%
		separate(First_author, c("Firstname", "Lastname") , sep = " (?=[^ ]*$)", extra = "merge") %>%
		mutate(Journal_abbreviation = "GeneReviews") %>%
		mutate(Journal = "GeneReviews") %>%
		select(publication_id, Bookshelf_ID, Title, Abstract, Year, Month, Day, Journal_abbreviation, Journal, Keywords, Lastname, Firstname)
	
	close(genereviews_url)
	return(return_tibble)
}	
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
	sysndd_db_disease_table <- pool %>% 
		tbl("ndd_entity_view")


	sysndd_db_disease_collected <- sysndd_db_disease_table %>%
		arrange(entity_id) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))
	
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

	dbExecute(sysndd_db, paste0("DELETE FROM ndd_review_phenotype_connect WHERE entity_id = ", sysndd_id, ";"))
	dbExecute(sysndd_db, paste0("DELETE FROM ndd_review_publication_join WHERE entity_id = ", sysndd_id, ";"))
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
	sysndd_db_disease_table <- pool %>% 
		tbl("ndd_entity_view")

	sysndd_db_disease_collected <- sysndd_db_disease_table %>%
		filter(entity_id %in% sysndd_id) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))

	sysndd_db_disease_collected
}


#* @tag entities
## get all phenotypes for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/phenotypes
function(sysndd_id) {

	# get data from database and filter
	ndd_review_phenotype_connect_collected <- pool %>% 
		tbl("ndd_review_phenotype_connect") %>%
		filter(is_active == 1) %>%
		collect()
	phenotype_list_collected <- pool %>% 
		tbl("phenotype_list") %>%
		collect()

	phenotype_list <- ndd_review_phenotype_connect_collected %>%
		filter(entity_id == sysndd_id) %>%
		inner_join(phenotype_list_collected, by=c("phenotype_id")) %>%
		select(entity_id, phenotype_id, HPO_term, modifier_id) %>%
		arrange(phenotype_id)
}


#* @tag entities
## get all clinical synopsis for a entity_id
#* @serializer json list(na="null")
#' @get /api/entities/<sysndd_id>/review
function(sysndd_id) {

	# get data from database and filter
	ndd_entity_review_collected <- pool %>% 
		tbl("ndd_entity_review") %>%
		collect()

	ndd_entity_review_list <- ndd_entity_review_collected %>%
		filter(entity_id == sysndd_id & is_primary) %>%
		select(entity_id, synopsis, review_date) %>%
		arrange(review_date)
		
	ndd_entity_review_list_joined <- as_tibble(sysndd_id) %>% 
		select(entity_id = value) %>%
		mutate(entity_id = as.integer(entity_id)) %>%
		left_join(ndd_entity_review_list, by = c("entity_id"))
}


#* @tag entities
## post a new clinical synopsis for a entity_id
## example data: {"synopsis":"Hello you cool database", "review_user_id":"1"}
#* @serializer json list(na="string")
#' @post /api/entities/review
function(review_json, res) {

	review_data <- fromJSON(review_json)
	review_user_id <- 1

	# convert phenotypes and publications to tibble
	phenotypes_received <- as_tibble(review_data$phenotypes)
	if ( length(compact(review_data$literature)) > 0 ) {
		publications_received <- as_tibble(compact(review_data$literature)) %>% 
			pivot_longer(everything(), names_to = "publication_type", values_to = "publication_id") %>%
			unique() %>%
			select(publication_id, publication_type) %>%
			arrange(publication_id)
	} else {
		publications_received <- as_tibble_row(c(publication_id = NA, publication_type = NA))
	}
	sysnopsis_received <- as_tibble(review_data$synopsis) %>% 
		add_column(review_data$entity) %>% 
		add_column(review_user_id) %>% 
		select(entity_id = `review_data$entity`, synopsis = value, review_user_id)

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

	# get allowed HPO terms
	phenotype_list_collected <- tbl(sysndd_db, "phenotype_list") %>%
		select(phenotype_id) %>%
		arrange(HPO_term) %>%
		collect()

	# check if received phenoytpes are in allowed phenotypes
	phenoytpes_allowed <- all(phenotypes_received$phenotype_id %in% phenotype_list_collected$phenotype_id)
	
	if ( !phenoytpes_allowed ) {
		res$status <- 400
		res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
		status = 400,
		message = paste0("Some of the submitted phenotypes are not in the allowed phenotype_id list.")
		))
		return(res)
	}

	# get existing PMIDs
	publications_list_collected <- tbl(sysndd_db, "publication") %>%
		select(publication_id) %>%
		arrange(publication_id) %>%
		collect()

	# check if publication_ids are already present in the database
	publications_new <- publications_received %>%
		mutate(present = publication_id %in% publications_list_collected$publication_id) %>%
		filter(!present) %>%
		select(-present)

	# add new publications to database table "publication"
	if (nrow(publications_new) > 0) {
		dbAppendTable(sysndd_db, "publication", publications_new)
	}

	# submit the new synopsis and get the id of the last insert for association with other tables
	dbAppendTable(sysndd_db, "ndd_entity_review", sysnopsis_received)
	submitted_review_id <- dbGetQuery(sysndd_db, "SELECT LAST_INSERT_ID();") %>% 
		as_tibble() %>% 
		select(review_id = `LAST_INSERT_ID()`)

	# prepare phenotype tibble for submission
	phenotypes_submission <- phenotypes_received %>% 
		add_column(submitted_review_id$review_id) %>% 
		add_column(review_data$entity) %>% 
		select(review_id = `submitted_review_id$review_id`, phenotype_id, entity_id = `review_data$entity`, modifier_id)

	# submit phenotypes from new review to database
	dbAppendTable(sysndd_db, "ndd_review_phenotype_connect", phenotypes_submission)

	# prepare publications tibble for submission
	publications_submission <- publications_received %>% 
		add_column(submitted_review_id$review_id) %>% 
		add_column(review_data$entity) %>% 
		select(review_id = `submitted_review_id$review_id`, entity_id = `review_data$entity`, publication_id, publication_type)

	# submit publications from new review to database	
	dbAppendTable(sysndd_db, "ndd_review_publication_join", publications_submission)

	# disconnect from database
	dbDisconnect(sysndd_db)
}


#* @tag entities
## get status for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/status
function(sysndd_id) {

	# get data from database and filter
	ndd_entity_status_collected <- pool %>% 
		tbl("ndd_entity_status") %>%
		collect()
	ndd_entity_status_categories_collected <- pool %>% 
		tbl("ndd_entity_status_categories_list") %>%
		collect()

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
	ndd_review_publication_join_collected <- pool %>% 
		tbl("ndd_review_publication_join") %>%
		filter(is_reviewed == 1) %>%
		collect()
	publication_collected <- pool %>% 
		tbl("publication") %>%
		collect()

	ndd_entity_publication_list <- ndd_review_publication_join_collected %>%
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
	publication_collected <- pool %>% 
		tbl("publication") %>%
		filter(publication_id == pmid) %>%
		select(publication_id, other_publication_id, Title, Abstract, Lastname, Firstname, Publication_date, Journal, Keywords) %>%
		arrange(publication_id) %>%
		collect()
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
	sysndd_db_genes_table <- pool %>% 
		tbl("ndd_entity_view") %>%
		arrange(entity_id) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))

	sysndd_db_genes_collected <- nest_gene_tibble(sysndd_db_genes_table)

	sysndd_db_genes_collected
}


#* @tag genes
## get infos for a single gene by hgnc_id
#* @serializer json list(na="string")
#' @get /api/genes/<hgnc>
function(hgnc) {

	hgnc <- URLdecode(hgnc) %>%
		str_replace_all("HGNC:", "")
	hgnc <- paste0("HGNC:",hgnc)

	# get data from database and filter
	non_alt_loci_set_collected <- pool %>% 
		tbl("non_alt_loci_set") %>%
		filter(hgnc_id == hgnc) %>%
		select(hgnc_id, symbol, name, entrez_id, ensembl_gene_id, ucsc_id, ccds_id, uniprot_ids) %>%
		arrange(hgnc_id) %>%
		collect()
}


#* @tag genes
## get infos for a single gene by symbol
#* @serializer json list(na="string")
#' @get /api/genes/symbol/<symbol>
function(symbol) {

	symbol_input <- URLdecode(symbol) %>%
		str_to_lower()
		
	# get data from database and filter
	non_alt_loci_set_collected <- pool %>% 
		tbl("non_alt_loci_set") %>%
		filter(str_to_lower(symbol) == symbol_input) %>%
		select(hgnc_id, symbol, name, entrez_id, ensembl_gene_id, ucsc_id, ccds_id, uniprot_ids) %>%
		arrange(hgnc_id) %>%
		collect()
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
	entity_by_gene_list <- pool %>% 
		tbl("ndd_entity_view") %>%
		filter(hgnc_id == hgnc) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))

	entity_by_gene_list
}


#* @tag genes
## get all entities for a single gene by symbol
#* @serializer json list(na="string")
#' @get /api/genes/symbol/<symbol>/entities
function(symbol) {

	symbol_input <- URLdecode(symbol) %>%
		str_to_lower()

	# get data from database and filter
	entity_by_gene_list <- pool %>% 
		tbl("ndd_entity_view") %>%
		filter(str_to_lower(symbol) == symbol_input) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))

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
	ontology_set_collected <- pool %>% 
		tbl("ontology_set") %>%
		filter(disease_ontology_id == ontology_id) %>%
		select(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, disease_ontology_source, disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term, DOID, MONDO, Orphanet, UMLS, EFO) %>%
		arrange(disease_ontology_id_version) %>%
		collect() %>%
		group_by(disease_ontology_id) %>%
		summarise_all(~paste(unique(.), collapse = ';')) %>%
		ungroup() %>%
		mutate(across(everything(), ~replace(., . ==  "NULL" , "")))
}


#* @tag ontology
## get an ontology entry by disease_ontology_name
#* @serializer json list(na="string")
#' @get /api/ontology/name/<ontology_name>
function(ontology_name) {
	ontology_name <- URLdecode(ontology_name)

	# get data from database and filter
	ontology_set_collected <- pool %>% 
		tbl("ontology_set") %>%
		filter(disease_ontology_name == ontology_name) %>%
		select(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, disease_ontology_source, disease_ontology_is_specific, hgnc_id, hpo_mode_of_inheritance_term, DOID, MONDO, Orphanet, UMLS, EFO) %>%
		arrange(disease_ontology_id_version) %>%
		collect() %>%
		group_by(disease_ontology_id) %>%
		summarise_all(~paste(unique(.), collapse = ';')) %>%
		ungroup() %>%
		mutate(across(everything(), ~replace(., . ==  "NULL" , "")))
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
	mode_of_inheritance_list_collected <- pool %>% 
		tbl("mode_of_inheritance_list") %>%
		filter(hpo_mode_of_inheritance_term == hpo) %>%
		select(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name) %>%
		arrange(hpo_mode_of_inheritance_term) %>%
		collect()
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
	phenotype_list_collected <- pool %>% 
		tbl("phenotype_list") %>%
		select(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms) %>%
		arrange(HPO_term) %>%
		collect()
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
	phenotype_list_collected <- pool %>% 
		tbl("phenotype_list") %>%
		filter(phenotype_id == hpo) %>%
		select(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms) %>%
		arrange(phenotype_id) %>%
		collect()
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
	entity_list_from_phenotype_list_collected <- pool %>% 
		tbl("ndd_review_phenotype_connect") %>%
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
	status_list_collected <- pool %>% 
		tbl("ndd_entity_status_categories_list") %>%
		arrange(category_id) %>%
		collect()
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
	# connect to database and get category list
	categories_list <- pool %>% 
		tbl("ndd_entity_status_categories_list") %>%
		select(category) %>%
		collect() %>%
		add_row(category = "All") %>%
		arrange(category)
	
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

	# validate inputs
	ndd_entity_status_categories_list <- pool %>% 
		tbl("ndd_entity_status_categories_list") %>%
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
	sysndd_db_ndd_entity_view  <- pool %>% 
		tbl("ndd_entity_view") %>%
		filter(ndd_phenotype == 1) %>%
		select(hgnc_id, symbol, inheritance = hpo_mode_of_inheritance_term_name, category)
	sysndd_db_non_alt_loci_set <- pool %>% 
		tbl("non_alt_loci_set") %>%
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

	# connect to database and validate inputs
	ndd_entity_status_categories_list <- pool %>% 
		tbl("ndd_entity_status_categories_list") %>%
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
	sysndd_db_ndd_entity_view <- pool %>% 
		tbl("ndd_entity_view") %>%
		filter(ndd_phenotype == 1) %>%
		select(hgnc_id, symbol, inheritance = hpo_mode_of_inheritance_term_name, category)
	sysndd_db_non_alt_loci_set <- pool %>% 
		tbl("non_alt_loci_set") %>%
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

	sysndd_db_disease_genes <- pool %>% 
		tbl("ndd_entity_view") %>%
		arrange(entity_id) %>%
		filter(ndd_phenotype == 1) %>%
		select(symbol, inheritance = hpo_mode_of_inheritance_term_name, category) %>%
		collect()
	
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
		mutate(category_group = category) %>%
		group_by(category_group) %>% 
		nest() %>% 
		ungroup() %>%
		select(category = category_group, groups = data)

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
	sysndd_db_disease_genes_news <- pool %>% 
		tbl("ndd_entity_view") %>%
		arrange(entity_id) %>%
		filter(ndd_phenotype == 1 & category == "Definitive") %>%
		collect() %>%
		arrange(desc(entry_date)) %>%
		slice(1:n)

	sysndd_db_disease_genes_news
}


#* @tag statistics
## get date of last update
#* @serializer json list(na="string")
#' @get /api/statistics/last_update
function() {
	# get data from database and filter
	sysndd_db_disease_entry_date_last <- pool %>% 
		tbl("ndd_entity_view") %>%
		select(entry_date) %>%
		arrange(desc(entry_date)) %>%
		head(1) %>%
		collect() %>%
		select(last_update = entry_date)

	sysndd_db_disease_entry_date_last
}


#* @tag statistics
## Return interactive plot showing the database entry development over time using plotly
#* @serializer text
#' @get /api/statistics/entities_plot
function() {
	# get data from database and filter
	sysndd_db_disease_collected  <- pool %>% 
		tbl("ndd_entity_view") %>%
		arrange(entity_id) %>%
		select(entity_id, ndd_phenotype, category, entry_date) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		)) %>%
		filter(ndd_phenotype == "Yes")

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

	sysndd_db_entity_search <- pool %>% 
		tbl("ndd_entity_view") %>%
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
		arrange(searchdist, results) %>%
		mutate(link = case_when(
			search == "hgnc_id" ~ paste0("/Genes/", results),
			search == "symbol" ~ paste0("/Genes/", results),
			search == "disease_ontology_id_version" ~ paste0("/Ontology/", results),
			search == "disease_ontology_name" ~ paste0("/Ontology/", results),
			search == "entity_id" ~ paste0("/Entities/", results)
		))

	# change output by helper input to unique values (helper = TRUE) or entities (helper = FALSE)
	if (helper) {
		sysndd_db_entity_search_helper <- sysndd_db_entity_search %>% 
			select(-entity_id, -link) %>%
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
			res$body <- "Please provide username and password."
			res
		  }

	# connect to database, find user in database and password is correct
	user_filtered <- pool %>% 
		tbl("user") %>%
		filter(user_name == check_user & password == check_pass) %>%
		select(-password, -created_at) %>%
		collect() %>%
		mutate(iat = as.numeric(Sys.time())) %>%
		mutate(exp = as.numeric(Sys.time()) + dw$refresh)
	
	# return answer depending on user credentials status
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
	
	# load jwt from header
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


#* @tag authentication
#* @get /api/auth/refresh
#* @serializer json list(na="string")
function(req, res) {

	# load secret and convert to raw
	key <- charToRaw(dw$secret)
	
	# load jwt from header
	jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
	
	user <- jwt_decode_hmac(jwt, secret = key)
	user$token_expired = (user$exp < as.numeric(Sys.time()))
	
	if (is.null(jwt) || user$token_expired){
		res$status <- 401 # Unauthorized
		return(list(error="Authentication not successful."))
	} else {
		claim <- jwt_claim(user_id = user$user_id, user_name = user$user_name, email = user$email, user_role = user$user_role, iat = as.numeric(Sys.time()), exp = as.numeric(Sys.time()) + dw$refresh)

		jwt <- jwt_encode_hmac(claim, secret = key)
		jwt
	}
	
}
##Authentication section
##-------------------------------------------------------------------##
