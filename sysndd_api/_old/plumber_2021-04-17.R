# plumber.R

# load libraries
library(plumber)
library(tidyverse)
library(DBI)
library(RMariaDB)



## get all entities
#* @serializer json list(na="string")
#' @get /api/entities
function() {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = "sysndd_db", user = "root", password = "bepo96kamo")
	sysndd_db_disease_table <- tbl(sysndd_db, "ndd_entity_view")


	sysndd_db_disease_collected <- sysndd_db_disease_table %>%
		arrange(entity_id) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)
	
	sysndd_db_disease_collected
}


## get a single entity
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>
function(sysndd_id) {
	# remove spaces from list
	sysndd_id <- str_replace_all(sysndd_id, " ", "")

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = "sysndd_db", user = "root", password = "bepo96kamo")
	sysndd_db_disease_table <- tbl(sysndd_db, "ndd_entity_view")


	sysndd_db_disease_collected <- sysndd_db_disease_table %>%
		filter(entity_id == sysndd_id) %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)
	
	sysndd_db_disease_collected
}



## get all phenotypes for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/phenotypes
function(sysndd_id) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = "sysndd_db", user = "root", password = "bepo96kamo")
	ndd_entity_phenotype_connect_collected <- tbl(sysndd_db, "ndd_entity_phenotype_connect") %>%
		collect()
	ndd_entity_phenotype_list_collected <- tbl(sysndd_db, "ndd_entity_phenotype_list") %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	ndd_entity_phenotype_list <- ndd_entity_phenotype_connect_collected %>%
		filter(entity_id == sysndd_id) %>%
		inner_join(ndd_entity_phenotype_list_collected, by=c("phenotype_id"="HPO_term_identifier")) %>%
		select(entity_id, phenotype_id, HPO_term, modifier) %>%
		arrange(phenotype_id)
}




## get all clinical synopsis for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/synopsis
function(sysndd_id) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = "sysndd_db", user = "root", password = "bepo96kamo")
	ndd_entity_review_collected <- tbl(sysndd_db, "ndd_entity_review") %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	ndd_entity_review_list <- ndd_entity_review_collected %>%
		filter(entity_id == sysndd_id & is_primary) %>%
		select(entity_id, synopsis, review_date) %>%
		arrange(review_date)
}


## post an new all clinical synopsis for a entity_id
## example data: {"review_id":3130, "synopsis":"Hello you sexy database"}
#* @serializer json list(na="string")
#' @post /api/entities/<sysndd_id>/synopsis
function(sysndd_id, synopsis_in) {

	# connect to database
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = "sysndd_db", user = "root", password = "bepo96kamo")

	test <- as_tibble(fromJSON(synopsis_in)) %>% 
		add_column(sysndd_id) %>% 
		select(review_id, entity_id = sysndd_id, synopsis)
	dbAppendTable(sysndd_db, "ndd_entity_review", test)
}




## get status for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/status
function(sysndd_id) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = "sysndd_db", user = "root", password = "bepo96kamo")
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


## get all publications for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/publications
function(sysndd_id) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = "sysndd_db", user = "root", password = "bepo96kamo")
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



## get all publications for a entity_id
#* @serializer json list(na="string")
#' @get /api/entities/<sysndd_id>/publications/<pmid>
function(sysndd_id, pmid) {

	pmid <- URLdecode(pmid) %>%
		str_replace_all("[^0-9]+", "")
	pmid <- paste0("PMID:",pmid)
		

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = "sysndd_db", user = "root", password = "bepo96kamo")
	ndd_entity_publication_join_collected <- tbl(sysndd_db, "ndd_entity_publication_join") %>%
		collect()
	publication_collected <- tbl(sysndd_db, "publication") %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	ndd_entity_publication_list <- ndd_entity_publication_join_collected %>%
		filter(entity_id == sysndd_id & publication_id == pmid) %>%
		inner_join(publication_collected, by=c("publication_id")) %>%
		select(entity_id, publication_id, other_publication_id, publication_status, Title, Abstract, Lastname, Firstname, Publication_date, Journal, Keywords) %>%
		arrange(publication_id)
}




## get a list of genes filtered by the association status and inheritance pattern associated with an entity
#* @serializer json list(na="string")
#' @get /api/genelist
function(category_query="", inheritance_query="", only_count=FALSE) {

	# get data from database and filter
	sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = "sysndd_db", user = "root", password = "bepo96kamo")
	ndd_entity_view_collected <- tbl(sysndd_db, "ndd_entity_view") %>%
		collect()
	ndd_entity_status_collected <- tbl(sysndd_db, "ndd_entity_status") %>%
		collect()
	ndd_entity_status_categories_list_collected <- tbl(sysndd_db, "ndd_entity_status_categories_list") %>%
		collect()
	mode_of_inheritance_list_collected <- tbl(sysndd_db, "mode_of_inheritance_list") %>%
		collect()

	# disconnect from database
	dbDisconnect(sysndd_db)

	if (only_count) {
		ndd_entity_review_list <- ndd_entity_status_collected %>%
		inner_join(ndd_entity_status_categories_list_collected, by=c("category_id")) %>%
		filter(category == category_query) %>%
		inner_join(ndd_entity_view_collected, by=c("entity_id")) %>%
		filter(hpo_mode_of_inheritance_term_name == inheritance_query & ndd_phenotype) %>%
		select(symbol) %>%
		unique() %>%
		arrange(symbol) %>%
		tally()
	} else {
		ndd_entity_review_list <- ndd_entity_status_collected %>%
		inner_join(ndd_entity_status_categories_list_collected, by=c("category_id")) %>%
		filter(category == category_query) %>%
		inner_join(ndd_entity_view_collected, by=c("entity_id")) %>%
		filter(hpo_mode_of_inheritance_term_name == inheritance_query & ndd_phenotype) %>%
		select(symbol) %>%
		unique() %>%
		arrange(symbol)
	}	
}