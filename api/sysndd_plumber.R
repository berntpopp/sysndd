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
library(coop)
library(reshape2)
library(blastula)
library(keyring)
library(future)
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
Sys.setenv(SMTP_PASSWORD=toString(dw$mail_noreply_password))
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## global variables
inheritance_input_allowed <- c("X-linked", "Dominant", "Recessive", "Other", "All")
output_columns_allowed <- c("category", "inheritance", "symbol", "hgnc_id", "entrez_id", "ensembl_gene_id", "ucsc_id", "bed_hg19", "bed_hg38")
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
##-------------------------------------------------------------------##
# Define global functions

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


# based on https://xiaolianglin.com/2018/12/05/Use-memoise-to-speed-up-your-R-plumber-API/

nest_gene_tibble <- function(tibble) {
    nested_tibble <- tibble %>%
        nest_by(symbol, hgnc_id, .key = "entities")
    
    return(nested_tibble)
}

make_entities_plot <- function(data_tibble) {
	plot <- ggplot(data = data_tibble , aes(x = entry_date, color = category)) +
		stat_bin(data=subset(data_tibble, category=="Definitive"), aes(y=cumsum(..count..)), geom="step", bins = 30) +
		stat_bin(data=subset(data_tibble, category=="Limited"), aes(y=cumsum(..count..)), geom="step", bins = 30) +
		theme_classic() +
		theme(axis.text.x = element_text(angle = -45, hjust = 0), axis.title.x = element_blank(), axis.title.y = element_blank(), legend.position="top", legend.title = element_blank())

	file <- "results/plot.png"
	ggsave(file, plot, width = 4.5, height = 2.5, dpi = 150, units = "in")
	return(base64Encode(readBin(file, "raw", n = file.info(file)$size), "txt"))
}

make_matrix_plot <- function(data_melt) {
	matrix_plot <- ggplot(data = data_melt, aes(x=Var1, y=Var2, fill=value)) +
		geom_tile(color = "white") +
		scale_fill_gradient2(low = "blue", high = "red", mid = "white", midpoint = 0, limit = c(-1,1), space = "Lab", name="Pearson\nCorrelation") +
		theme_classic() +
		theme(axis.text.x = element_text(angle = -90, hjust = 0), axis.title.x = element_blank(), axis.title.y = element_blank(), legend.position="top", legend.title = element_blank()) +
		coord_fixed()

	file <- "results/matrix_plot.png"
	ggsave(file, matrix_plot, width = 3.0, height = 3.5, dpi = 150, units = "in")
	return(base64Encode(readBin(file, "raw", n = file.info(file)$size), "txt"))
}

# Memoise functions
nest_gene_tibble_mem <- memoise(nest_gene_tibble)
make_entities_plot_mem <- memoise(make_entities_plot)
make_matrix_plot_mem <- memoise(make_matrix_plot)

##-------------------------------------------------------------------##
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
##-------------------------------------------------------------------##
#* @apiTitle SysNDD API

#* @apiDescription This is the API powering the SysNDD website and allowing programmatic access to the database contents.
#* @apiVersion 0.1.0
#* @apiTOS http://www.sysndd.org/terms/
#* @apiContact list(name = "API Support", url = "http://www.sysndd.org/support", email = "support@sysndd.org")
#* @apiLicense list(name = "CC BY 4.0", url = "https://creativecommons.org/licenses/by/4.0/")

#* @apiTag entities Entities related endpoints
#* @apiTag reviews Reviews related endpoints
#* @apiTag status Status related endpoints
#* @apiTag publications Publication related endpoints
#* @apiTag genes Gene related endpoints
#* @apiTag ontology Ontology related endpoints
#* @apiTag inheritance Inheritance related endpoints
#* @apiTag phenotypes Phenoptype related endpoints
#* @apiTag panels Gene panel related endpoints
#* @apiTag comparisons NDD gene list comparisons related endpoints
#* @apiTag search Database search related endpoints
#* @apiTag statistics Database statistics
#* @apiTag authentication Authentication related endpoints
##-------------------------------------------------------------------##
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## filters

#* @filter cors
## enable cross origin requests
## based on https://github.com/rstudio/plumber/issues/66
function(req, res) {
  
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


#* @filter check_signin
## check signin from header token and set user variable to request
function(req, res) {
	# load secret and convert to raw
	key <- charToRaw(dw$secret)

	if (req$REQUEST_METHOD == "GET" & is.null(req$HTTP_AUTHORIZATION)) {
		plumber::forward()
	} else if (req$REQUEST_METHOD == "GET" & !is.null(req$HTTP_AUTHORIZATION)) {
		# load jwt from header
		jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
		# decode jwt
		user <- jwt_decode_hmac(str_remove(req$HTTP_AUTHORIZATION, "Bearer "), secret = key)
		# add user_id and user_role as value to request
		req$user_id <- as.integer(user$user_id)
		req$user_role <- user$user_role
		# and forward request
		plumber::forward()
	} else {
		if (is.null(req$HTTP_AUTHORIZATION)) {
			res$status <- 401 # Unauthorized
			return(list(error="Authorization http header missing."))
		} else if (jwt_decode_hmac(str_remove(req$HTTP_AUTHORIZATION, "Bearer "), secret = key)$exp  < as.numeric(Sys.time())) {
			res$status <- 401 # Unauthorized
			return(list(error="Token expired."))
		} else {
			# load jwt from header
			jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
			# decode jwt
			user <- jwt_decode_hmac(str_remove(req$HTTP_AUTHORIZATION, "Bearer "), secret = key)
			# add user_id and user_role as value to request
			req$user_id <- as.integer(user$user_id)
			req$user_role <- user$user_role
			# and forward request
			plumber::forward()
		}
	}
}
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Entity endpoints

#* @tag entities
## get all entities
#* @serializer json list(na="string")
#' @get /api/entities
function(res, sort = "entity_id", `page[after]` = 0, `page[size]` = "all") {

	# get number of rows in ndd_entity_view
	sysndd_db_disease_rows <- (pool %>% 
		tbl("ndd_entity_view") %>%
		summarise(n = n()) %>%
		collect()
		)$n

	# split the sort input by comma and check if entity_idis in the resulting list, if not append to the list for unique sorting
	sort_list <- str_split(str_squish(sort), ",")[[1]]
	
	if ( !("entity_id" %in% sort) ){
		sort_list <- append(sort, "entity_id")
	}

	# check if `page[size]` is either "all" or a valid integer and convert or assign values accordingly
	if ( `page[size]` == "all" ){
		page_after <- 0
		page_size <- sysndd_db_disease_rows
		page_count <- ceiling(sysndd_db_disease_rows/page_size)
	} else if ( is.numeric(as.integer(`page[size]`)) )
	{
		page_after <- as.integer(`page[after]`)
		page_size <- as.integer(`page[size]`)
		page_count <- ceiling(sysndd_db_disease_rows/page_size)
	} else
	{
		res$status <- 400 #Bad Request
		return(list(error="Invalid Parameter Value Error."))
	}

	# get data from database
	ndd_entity_review <- pool %>% 
		tbl("ndd_entity_review") %>%
		filter(is_primary) %>%
		select(entity_id, synopsis)
		
	sysndd_db_disease_table <- pool %>% 
		tbl("ndd_entity_view") %>%
		left_join(ndd_entity_review, by = c("entity_id")) %>%
		arrange(!!!syms(sort_list)) %>%
		collect()

	# find the current row of the requested page_after entry
	page_after_row <- (sysndd_db_disease_table %>%
		mutate(row = row_number()) %>%
		filter(entity_id == page_after)
		)$row

	if ( length(page_after_row) == 0 ){
		page_after_row <- 0
		page_after_row_next <- ( sysndd_db_disease_table %>%
			filter(row_number() == page_after_row + page_size + 1) )$entity_id
	} else {
		page_after_row_next <- ( sysndd_db_disease_table %>%
			filter(row_number() == page_after_row + page_size) )$entity_id
	}

	# find next and prev item row
	page_after_row_prev <- ( sysndd_db_disease_table %>%
		filter(row_number() == page_after_row - page_size) )$entity_id
	page_after_row_last <- ( sysndd_db_disease_table %>%
		filter(row_number() ==  page_size * (page_count - 1) ) )$entity_id
		
	# filter by row
	sysndd_db_disease_table <- sysndd_db_disease_table %>%
		filter(row_number() > page_after_row & row_number() <= page_after_row + page_size)

	sysndd_db_disease_collected <- sysndd_db_disease_table  %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))

	# generate links for self, next and prev pages
	self <- paste0("http://", dw$host, ":", dw$port_self, "/api/entities/?sort=", sort, "&page[after]=", `page[after]`, "&page[size]=", `page[size]`)
	if ( length(page_after_row_prev) == 0 ){
		prev <- "null"
	} else
	{
		prev <- paste0("http://", dw$host, ":", dw$port_self, "/api/entities?sort=", sort, "&page[after]=", page_after_row_prev, "&page[size]=", `page[size]`)
	}
	
	if ( length(page_after_row_next) == 0 ){
		`next` <- "null"
	} else
	{
		`next` <- paste0("http://", dw$host, ":", dw$port_self, "/api/entities?sort=", sort, "&page[after]=", page_after_row_next, "&page[size]=", `page[size]`)
	}
	
	if ( length(page_after_row_last) == 0 ){
		last <- "null"
	} else
	{
		last <- paste0("http://", dw$host, ":", dw$port_self, "/api/entities?sort=", sort, "&page[after]=", page_after_row_last, "&page[size]=", `page[size]`)
	}

	links <- as_tibble(list("prev" = prev, "self" = self, "next" = `next`, "last" = last))

	# 
	list(links = links, data = sysndd_db_disease_collected)
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
		arrange(phenotype_id) %>%
		unique()
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
		select(entity_id, publication_id, publication_type, is_reviewed) %>%
		arrange(publication_id) %>%
		unique()
}

## Entity endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Review endpoints
#* @tag reviews
## get a single review by review_id
#* @serializer json list(na="null")
#' @get /api/reviews/<review_requested>
function(review_requested) {
	# remove spaces from list
	review_requested <- URLdecode(review_requested) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all(" ", "") %>%
		unique()

	# get data from database and filter
	sysndd_db_review_table <- pool %>% 
		tbl("ndd_entity_review")
	user_table <- pool %>% 
		tbl("user") %>% 
		select(user_id, user_name, user_role)
		
	sysndd_db_review_table_collected <- sysndd_db_review_table %>%
		filter(review_id == review_requested) %>%
		left_join(user_table, by = c("review_user_id" = "user_id")) %>%
		left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
		collect() %>%
		select(review_id, entity_id, synopsis, is_primary, review_date, review_user_name = user_name.x, review_user_role = user_role.x, review_approved, approving_user_name = user_name.y, approving_user_role = user_role.y, comment)

	sysndd_db_review_table_collected
}


#* @tag reviews
## get all phenotypes for a review
#* @serializer json list(na="string")
#' @get /api/reviews/<review_requested>/phenotypes
function(review_requested) {
	# remove spaces from list
	review_requested <- URLdecode(review_requested) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all(" ", "") %>%
		unique()

	# get data from database and filter
	ndd_review_phenotype_connect_collected <- pool %>% 
		tbl("ndd_review_phenotype_connect") %>%
		collect()

	phenotype_list_collected <- pool %>% 
		tbl("phenotype_list") %>%
		collect()

	phenotype_list <- ndd_review_phenotype_connect_collected %>%
		filter(review_id == review_requested) %>%
		inner_join(phenotype_list_collected, by=c("phenotype_id")) %>%
		select(review_id, entity_id, phenotype_id, HPO_term, modifier_id) %>%
		arrange(phenotype_id)
}


#* @tag reviews
## get all publications for a reviews_id
#* @serializer json list(na="string")
#' @get /api/reviews/<review_requested>/publications
function(review_requested) {
	# remove spaces from list
	review_requested <- URLdecode(review_requested) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all(" ", "") %>%
		unique()
		
	# get data from database and filter
	ndd_review_publication_join_collected <- pool %>% 
		tbl("ndd_review_publication_join") %>%
		collect()

	publication_collected <- pool %>% 
		tbl("publication") %>%
		collect()

	ndd_entity_publication_list <- ndd_review_publication_join_collected %>%
		filter(review_id == review_requested) %>%
		arrange(publication_id)
}


#* @tag reviews
## post a new clinical synopsis for a entity_id in re-review mode
## example data: {"re_review_entity_id":1, "entity_id": 1, "synopsis": "activating, gain-of-function mutations: congenital hypertrichosis, neonatal macrosomia, distinct osteochondrodysplasia, cardiomegaly; activating mutations", "literature": {"additional_references": ["PMID:22608503", "PMID:22610116"], "gene_review": ["PMID:25275207"]}, "phenotypes": {"phenotype_id": ["HP:0000256", "HP:0000924", "HP:0001256", "HP:0001574", "HP:0001627", "HP:0002342"], "modifier_id": [1,1,1,1,1,1]}, "comment": ""}
#* @serializer json list(na="string")
#' @post /api/re_review/review
#' @put /api/re_review/review
function(req, res, review_json) {
	# first check rights
	if ( req$user_role %in% c("Admin", "Curator", "Reviewer") ) {
				
		review_user_id <- req$user_id
		review_data <- fromJSON(review_json)

		if ( !is.null(review_data$synopsis) & !is.null(review_data$entity_id) & nchar(review_data$synopsis) > 0 ) {

			# convert phenotypes to tibble
			phenotypes_received <- as_tibble(review_data$phenotypes)

			# convert publications to tibble
			if ( length(compact(review_data$literature)) > 0 ) {
				publications_received <- bind_rows(as_tibble(compact(review_data$literature$additional_references)), as_tibble(compact(review_data$literature$gene_review)), .id = "publication_type") %>% 
					select(publication_id = value, publication_type) %>%
					mutate(publication_type = case_when(
					  publication_type == 1 ~ "additional_references",
					  publication_type == 2 ~ "gene_review"
					)) %>%
					unique() %>%
					select(publication_id, publication_type) %>%
					arrange(publication_id)

			} else {
				publications_received <- as_tibble_row(c(publication_id = NA, publication_type = NA))
			}

			# convert sysnopsis to tibble, check if comment is null and handle
			if ( !is.null(review_data$comment) ) {
				sysnopsis_received <- as_tibble(review_data$synopsis) %>% 
					add_column(review_data$entity_id) %>% 
					add_column(review_data$comment) %>% 
					add_column(review_user_id) %>% 
					select(entity_id = `review_data$entity_id`, synopsis = value, review_user_id, comment = `review_data$comment`)
			} else {
				sysnopsis_received <- as_tibble(review_data$synopsis) %>% 
					add_column(review_data$entity_id) %>%
					add_column(review_user_id) %>% 
					select(entity_id = `review_data$entity_id`, synopsis = value, review_user_id, comment = NULL)
			}

			##-------------------------------------------------------------------##
			# get allowed HPO terms
			phenotype_list_collected <- pool %>%
				tbl("phenotype_list") %>%
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

			##-------------------------------------------------------------------##

			##-------------------------------------------------------------------##
			# check which request type was requested and perform database update accordingly
			if ( req$REQUEST_METHOD == "POST") {
				##-------------------------------------------------------------------##
				## for the post request we connect to the database and then add new publications, the new synopis and the associate the synopis with phenotypesa nd publications
				# connect to database
				sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

				# get existing PMIDs
				publications_list_collected <- pool %>%
					tbl("publication") %>%
					select(publication_id) %>%
					arrange(publication_id) %>%
					collect()
				
				# check if publication_ids are already present in the database
				publications_new <- publications_received %>%
					mutate(present = publication_id %in% publications_list_collected$publication_id) %>%
					filter(!present & !is.na(publication_id)) %>%
					select(-present)
				
				# add new publications to database table "publication" if present and not NA
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
					add_column(review_data$entity_id) %>% 
					select(review_id = `submitted_review_id$review_id`, phenotype_id, entity_id = `review_data$entity_id`, modifier_id)

				# submit phenotypes from new review to database
				dbAppendTable(sysndd_db, "ndd_review_phenotype_connect", phenotypes_submission)

				# prepare publications tibble for submission
				publications_submission <- publications_received %>% 
					add_column(submitted_review_id$review_id) %>% 
					add_column(review_data$entity_id) %>% 
					select(review_id = `submitted_review_id$review_id`, entity_id = `review_data$entity_id`, publication_id, publication_type)

				# submit publications from new review to database	
				dbAppendTable(sysndd_db, "ndd_review_publication_join", publications_submission)

				# execute update query for re_review_entity_connect saving status and review_id
				dbExecute(sysndd_db, paste0("UPDATE re_review_entity_connect SET ", "re_review_review_saved = 1, ", "review_id=", submitted_review_id$review_id, " WHERE re_review_entity_id = ", review_data$re_review_entity_id, ";"))

				# disconnect from database
				dbDisconnect(sysndd_db)
				##-------------------------------------------------------------------##
				
			} else if ( req$REQUEST_METHOD == "PUT") {
				##-------------------------------------------------------------------##
				## for the put request we first find the review_id saved in the re_review, delete associated phenotype and publication connections and publications associated only in that review then proceed to update the review and make new connections
				
				# get the review_id using the re_review_entity_id
				review_id_from_re_review_entity_id <- (pool %>% 
					tbl("re_review_entity_connect") %>%
					collect() %>%
					filter(re_review_entity_id %in% review_data$re_review_entity_id))$review_id

				# compute publications only present in the former review which are to be deleted before adding the new publications to the review
				ndd_review_publication_join <- pool %>% 
					tbl("ndd_review_publication_join") %>%
					collect() 
				ndd_review_publication_join_count <-ndd_review_publication_join %>%
					select(publication_id) %>%
					group_by(publication_id) %>%
					mutate(count = n()) %>%
					ungroup() %>%
					unique()
				publication_id_to_purge <- (ndd_review_publication_join %>%
					left_join(ndd_review_publication_join_count, by = c("publication_id")) %>%
					filter(review_id %in% review_id_from_re_review_entity_id) %>%
					filter(count == 1) %>%
					mutate(publication_id = paste0("'", publication_id, "'")))$publication_id

				# connect to database
				sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
				
				# delete old phenotype connections for review_id first
				dbExecute(sysndd_db, paste0("DELETE FROM ndd_review_phenotype_connect WHERE review_id = ", review_id_from_re_review_entity_id, ";"))
				
				# delete old publication connections for review_id second
				dbExecute(sysndd_db, paste0("DELETE FROM ndd_review_publication_join WHERE review_id = ", review_id_from_re_review_entity_id, ";"))
				
				# delete old publication connections if only present in previous version of this review
				if (length(publication_id_to_purge) > 0) {
					dbExecute(sysndd_db, paste0("DELETE FROM publication WHERE publication_id IN (", str_c(publication_id_to_purge, collapse=", "), ");"))
				}

				# get existing PMIDs
				publications_list_collected <- pool %>%
					tbl("publication") %>%
					select(publication_id) %>%
					arrange(publication_id) %>%
					collect()
				
				# check if publication_ids are already present in the database
				publications_new <- publications_received %>%
					mutate(present = publication_id %in% publications_list_collected$publication_id) %>%
					filter(!present & !is.na(publication_id)) %>%
					select(-present)
				
				# add new publications to database table "publication" if present and not NA
				if (nrow(publications_new) > 0) {
					dbAppendTable(sysndd_db, "publication", publications_new)
				}

				# prepare phenotype tibble for submission
				phenotypes_submission <- phenotypes_received %>% 
					add_column(review_id_from_re_review_entity_id) %>% 
					add_column(review_data$entity_id) %>% 
					select(review_id = review_id_from_re_review_entity_id, phenotype_id, entity_id = `review_data$entity_id`, modifier_id)

				# submit phenotypes from new review to database
				dbAppendTable(sysndd_db, "ndd_review_phenotype_connect", phenotypes_submission)

				# prepare publications tibble for submission
				publications_submission <- publications_received %>% 
					add_column(review_id_from_re_review_entity_id) %>% 
					add_column(review_data$entity_id) %>% 
					select(review_id = review_id_from_re_review_entity_id, entity_id = `review_data$entity_id`, publication_id, publication_type)

				# submit publications from new review to database	
				dbAppendTable(sysndd_db, "ndd_review_publication_join", publications_submission)

				# generate update query
				update_query <- as_tibble(sysnopsis_received) %>%
					mutate(row = row_number()) %>%  
					mutate(across(where(is.logical), as.integer)) %>%
					mutate(across(where(is.numeric), as.character)) %>%
					pivot_longer(-row) %>% 
					mutate(query = paste0(name, "='", value, "'")) %>% 
					select(query) %>% 
					summarise(query = str_c(query, collapse = ", "))

				# submit the new review
				dbExecute(sysndd_db, paste0("UPDATE ndd_entity_review SET ", update_query, " WHERE review_id = ", review_id_from_re_review_entity_id, ";"))
				
				# disconnect from database
				dbDisconnect(sysndd_db)
				##-------------------------------------------------------------------##
			}
			##-------------------------------------------------------------------##
		} else {
			res$status <- 400 # Bad Request
			return(list(error="Submitted synopsis data can not be empty."))
		}

	} else {
		res$status <- 403 # Forbidden
		return(list(error="Write access forbidden."))
	}
}


#* @tag reviews
## post a new status for a entity_id in re-review mode
## example data: '{"re_review_entity_id":3,"entity_id":3,"comment":"fsa","problematic": true}'
#* @serializer json list(na="string")
#' @post /api/re_review/status
#' @put /api/re_review/status
function(req, res, status_json) {
	# first check rights
	if ( req$user_role %in% c("Admin", "Curator", "Reviewer") ) {
				
		status_user_id <- req$user_id
		status_data <- fromJSON(status_json)

		if ( !is.null(status_data$category) | !is.null(status_data$problematic)) {

			# convert status data to tibble, check if comment is null and handle
			if ( !is.null(status_data$comment) ) {
				status_received <- as_tibble(status_data) %>% 
					add_column(status_user_id) %>% 
					select(-re_review_entity_id)
			} else {
				status_data$comment <- ""
				status_received <- as_tibble(status_data) %>% 
					add_column(status_user_id) %>% 
					select(-re_review_entity_id, -comment)
			}

			# check which request type was requested and perform database update accoringly
			if ( req$REQUEST_METHOD == "POST") {
				# connect to database
				sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

				# submit the new status and disconnect from database and get the id of the last insert for association with other tables
				dbAppendTable(sysndd_db, "ndd_entity_status", status_received)
				submitted_status_id <- dbGetQuery(sysndd_db, "SELECT LAST_INSERT_ID();") %>% 
					as_tibble() %>% 
					select(status_id = `LAST_INSERT_ID()`)		

				# execute update query for re_review_entity_connect saving status and status_id
				dbExecute(sysndd_db, paste0("UPDATE re_review_entity_connect SET ", "re_review_status_saved = 1, ", "status_id=", submitted_status_id$status_id, " WHERE re_review_entity_id = ", status_data$re_review_entity_id, ";"))
		
				# disconnect from database
				dbDisconnect(sysndd_db)
			} else if ( req$REQUEST_METHOD == "PUT") {
				# get the status_id using the re_review_entity_id
				status_id <- (pool %>% 
					tbl("re_review_entity_connect") %>%
					collect() %>%
					filter(re_review_entity_id %in% status_data$re_review_entity_id))$status_id

				# generate update query
				update_query <- as_tibble(status_received) %>%
					mutate(row = row_number()) %>%  
					mutate(across(where(is.logical), as.integer)) %>%
					mutate(across(where(is.numeric), as.character)) %>%
					pivot_longer(-row) %>% 
					mutate(query = paste0(name, "='", value, "'")) %>% 
					select(query) %>% 
					summarise(query = str_c(query, collapse = ", "))	
					
				# connect to database
				sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

				# submit the new status
				dbExecute(sysndd_db, paste0("UPDATE ndd_entity_status SET ", update_query, " WHERE status_id = ", status_id, ";"))
		
				# disconnect from database
				dbDisconnect(sysndd_db)
			}

		} else {
			res$status <- 400 # Bad Request
			return(list(error="Submitted data can not be null."))
		}

	} else {
		res$status <- 403 # Forbidden
		return(list(error="Write access forbidden."))
	}
}


#* @tag reviews
## put the re-review submission
## example data: {"re_review_entity_id":1, "re_review_submitted":1, "status_id":1, "review_id":1}
#* @serializer json list(na="string")
#' @put /api/re_review/submit
function(req, res, submit_json) {
	# first check rights
	if ( req$user_role %in% c("Admin", "Curator", "Reviewer") ) {
				
		submit_user_id <- req$user_id
		submit_data <- fromJSON(submit_json)

		update_query <- as_tibble(submit_data) %>%
			select(-re_review_entity_id) %>%
			mutate(row = row_number()) %>% 
			pivot_longer(-row) %>% 
			mutate(query = paste0(name, "='", value, "'")) %>% 
			select(query) %>% 
			summarise(query = str_c(query, collapse = ", "))
		
		# connect to database
		sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

		# execute update query
		dbExecute(sysndd_db, paste0("UPDATE re_review_entity_connect SET ", update_query, " WHERE re_review_entity_id = ", submit_data$re_review_entity_id, ";"))

		# disconnect from database
		dbDisconnect(sysndd_db)
		
	} else {
		res$status <- 403 # Forbidden
		return(list(error="Write access forbidden."))
	}
}


#* @tag reviews
## put a re-review submission back into unsubmitted mode (only Admin and Curator status users)
#* @serializer json list(na="string")
#' @put /api/re_review/unsubmit/<re_review_id>
function(req, res, re_review_id) {
	# first check rights
	if ( length(req$user_id) == 0) {
	
		res$status <- 401 # Unauthorized
		return(list(error="Please authenticate."))

	} else if ( req$user_role %in% c("Admin", "Curator") ) {
				
		submit_user_id <- req$user_id
		re_review_id <- as.integer(re_review_id)

		# connect to database
		sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

		# execute update query
		dbExecute(sysndd_db, paste0("UPDATE re_review_entity_connect SET re_review_submitted = 0 WHERE re_review_entity_id = ", re_review_id, ";"))

		# disconnect from database
		dbDisconnect(sysndd_db)
		
	} else {
		res$status <- 403 # Forbidden
		return(list(error="Write access forbidden."))
	}
}


#* @tag reviews
## put the re-review status and review approvement (only Admin and Curator status users)
#* @serializer json list(na="string")
#' @put /api/re_review/approve/<re_review_id>
function(req, res, re_review_id, status_ok = FALSE, review_ok = FALSE) {
	status_ok <- as.logical(status_ok)
	review_ok <- as.logical(review_ok)
	
	# first check rights
	if ( length(req$user_id) == 0) {
	
		res$status <- 401 # Unauthorized
		return(list(error="Please authenticate."))

	} else if ( req$user_role %in% c("Admin", "Curator") ) {
				
		submit_user_id <- req$user_id
		re_review_id <- as.integer(re_review_id)
		
		# get table data from database
		re_review_entity_connect_data <- pool %>% 
			tbl("re_review_entity_connect") %>%
			filter(re_review_entity_id == re_review_id) %>%
			collect()
		
		# connect to database
		sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

		# set status if confirmed
		if ( status_ok ) {
			# reset all stati in ndd_entity_status to inactive
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_status SET is_active = 0 WHERE entity_id = ", re_review_entity_connect_data$entity_id, ";"))

			# set status of the new status from re_review_entity_connect to active, add approving_user_id and set approved status to approved
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_status SET is_active = 1 WHERE status_id = ", re_review_entity_connect_data$status_id, ";"))
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_status SET approving_user_id = ", submit_user_id, " WHERE status_id = ", re_review_entity_connect_data$status_id, ";"))
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_status SET status_approved = 1 WHERE status_id = ", re_review_entity_connect_data$status_id, ";"))
		} else {
			# add approving_user_id and set approved status to unapproved
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_status SET approving_user_id = ", submit_user_id, " WHERE status_id = ", re_review_entity_connect_data$status_id, ";"))
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_status SET status_approved = 0 WHERE status_id = ", re_review_entity_connect_data$status_id, ";"))
		}

		# set review if confirmed
		if ( review_ok ) {
			# reset all reviews in ndd_entity_review to not primary
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_review SET is_primary = 0 WHERE entity_id = ", re_review_entity_connect_data$entity_id, ";"))

			# set the new review from re_review_entity_connect to primary, add approving_user_id and set approved status to approved
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_review SET is_primary = 1 WHERE review_id = ", re_review_entity_connect_data$review_id, ";"))
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_review SET approving_user_id = ", submit_user_id, " WHERE review_id = ", re_review_entity_connect_data$review_id, ";"))
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_review SET review_approved = 1 WHERE review_id = ", re_review_entity_connect_data$review_id, ";"))
		} else {
			# add approving_user_id and set approved status to unapproved
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_review SET approving_user_id = ", submit_user_id, " WHERE review_id = ", re_review_entity_connect_data$review_id, ";"))
			dbExecute(sysndd_db, paste0("UPDATE ndd_entity_review SET review_approved = 0 WHERE review_id = ", re_review_entity_connect_data$review_id, ";"))
		}

		# set re_review_approved status to yes and add approving_user_id
		dbExecute(sysndd_db, paste0("UPDATE re_review_entity_connect SET re_review_approved = 1 WHERE re_review_entity_id = ", re_review_id, ";"))
		dbExecute(sysndd_db, paste0("UPDATE re_review_entity_connect SET approving_user_id = ", submit_user_id, " WHERE re_review_entity_id = ", re_review_id, ";"))	

		# disconnect from database
		dbDisconnect(sysndd_db)
		
	} else {
		res$status <- 403 # Forbidden
		return(list(error="Write access forbidden."))
	}
}

#* @tag reviews
## get the re-review overview table for the user logged in
#* @serializer json list(na="string")
#' @get /api/re_review_table
function(req, res, curate=FALSE) {
	curate <- as.logical(curate)

	# first check rights
	if ( length(req$user_id) == 0) {
	
		res$status <- 401 # Unauthorized
		return(list(error="Please authenticate."))

	} else if ( (req$user_role %in% c("Admin", "Curator", "Reviewer") & !curate ) | (req$user_role %in% c("Admin", "Curator") & curate ) ) {
						
		user <- req$user_id

		# get table data from database and filter
		re_review_entity_connect <- pool %>% 
			tbl("re_review_entity_connect") %>%
			filter(re_review_approved == 0) %>%
			{if(curate) filter(., re_review_submitted == 1) else filter(., re_review_submitted == 0)}
		re_review_assignment <- pool %>% 
			tbl("re_review_assignment") %>% 
			{if(!curate) filter(., user_id == user) else .}
		ndd_entity_view <- pool %>% 
			tbl("ndd_entity_view")
		ndd_entity_status_category <- pool %>% 
			tbl("ndd_entity_status") %>%
			select(status_id, category_id)
		ndd_entity_status_categories_list <- pool %>% 
			tbl("ndd_entity_status_categories_list")
			
		# join and collect
		re_review_user_list <- re_review_entity_connect %>%
			inner_join(re_review_assignment, by = c("re_review_batch")) %>%
			select(re_review_entity_id, entity_id, re_review_review_saved, re_review_status_saved, re_review_submitted, status_id, review_id) %>%
			inner_join(ndd_entity_view, by = c("entity_id")) %>%
			select(-category_id, -category) %>%
			inner_join(ndd_entity_status_category, by = c("status_id")) %>%
			inner_join(ndd_entity_status_categories_list, by = c("category_id")) %>%
			collect()
		
		re_review_user_list

	} else {
		res$status <- 403 # Forbidden
		return(list(error="Read access forbidden."))
	}
}

## Review endpoints
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


#* @tag ontology
## get all entities for a single disease by ontology_id
#* @serializer json list(na="string")
#' @get /api/ontology/<ontology_id>/entities
function(ontology_id) {

	ontology_id <- URLdecode(ontology_id)

	# get data from database and filter
	entity_by_ontology_id_list <- pool %>% 
		tbl("ndd_entity_view") %>%
		filter(disease_ontology_id_version == ontology_id) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))

	entity_by_ontology_id_list
}


#* @tag ontology
## get all entities for a single disease by ontology_id
#* @serializer json list(na="string")
#' @get /api/ontology/name/<ontology_name>/entities
function(ontology_name) {

	ontology_name <- URLdecode(ontology_name)

	# get data from database and filter
	entity_by_ontology_name_list <- pool %>% 
		tbl("ndd_entity_view") %>%
		filter(disease_ontology_name == ontology_name) %>%
		collect() %>%
		mutate(ndd_phenotype = case_when(
		  ndd_phenotype == 1 ~ "Yes",
		  ndd_phenotype == 0 ~ "No"
		))

	entity_by_ontology_name_list
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
## get a list of entities associated with a list of phenotypes for browsing
#* @serializer json list(na="string")
#' @get /api/phenotypes/entities/browse
function(hpo_list = "", logical_operator = "and") {

	hpo_list <- URLdecode(hpo_list) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all("[^0-9]+", "") %>%
		str_replace("^", "HP:") %>%
		unique()

	# get data from database and filter
	if ( logical_operator == "and" ) {
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
			pivot_longer(-entity_id, names_to = c("phenotype_id")) %>%
			select(-phenotype_id) %>%
			group_by(entity_id) %>%
			summarise(value = all(value)) %>%
			filter(value) %>%
			select(entity_id) %>%
			ungroup()
	} else if ( logical_operator == "or" ) {
		entity_list_from_phenotype_list_collected <- pool %>% 
			tbl("ndd_review_phenotype_connect") %>%
			filter(phenotype_id %in% hpo_list) %>%
			arrange(entity_id) %>%
			select(entity_id,) %>%
			collect() %>%
			unique()
	}
	
	entity_list_from_phenotype_list_collected
}


#* @tag phenotypes
## get a list of entities associated with a list of phenotypes for download as Excel file
#* @serializer contentType list(type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
#' @get /api/phenotypes/entities/excel
function(hpo_list = "", logical_operator = "and", res) {

	hpo_list <- URLdecode(hpo_list) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all("[^0-9]+", "") %>%
		str_replace("^", "HP:") %>%
		unique()

	# get data from database and filter
	if ( logical_operator == "and" ) {
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
			pivot_longer(-entity_id, names_to = c("phenotype_id")) %>%
			select(-phenotype_id) %>%
			group_by(entity_id) %>%
			summarise(value = all(value)) %>%
			filter(value) %>%
			select(entity_id) %>%
			ungroup()

	# get entity data for the excel sheet
		sysndd_db_entity_table <- pool %>% 
			tbl("ndd_entity_view") %>%
			collect() %>%
			filter(entity_id %in% entity_list_from_phenotype_list_collected$entity_id) %>%
			arrange(entity_id)
	} else if ( logical_operator == "or" ) {
		entity_list_from_phenotype_list_collected <- pool %>% 
			tbl("ndd_review_phenotype_connect") %>%
			filter(phenotype_id %in% hpo_list) %>%
			arrange(entity_id) %>%
			select(entity_id,) %>%
			collect() %>%
			unique()

	# get entity data for the excel sheet
		sysndd_db_entity_table <- pool %>% 
			tbl("ndd_entity_view") %>%
			collect() %>%
			filter(entity_id %in% entity_list_from_phenotype_list_collected$entity_id) %>%
			arrange(entity_id)
	}

	# generate request statistic for output
	creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%dT %H:%M:%S")
	
	request_stats <- tibble(
	  creation_date = creation_date, 
	  hpo_input = hpo_list, 
	  operator_input = logical_operator
	) %>%
    pivot_longer(everything(), names_to = "request", values_to = "value")

	# generate excel file output
	filename <- file.path(tempdir(), "phenotype_panel.xlsx")
	write.xlsx(sysndd_db_entity_table, filename, sheetName="sysndd_phenotype_panel", append=FALSE)
	write.xlsx(request_stats, filename, sheetName="request", append=TRUE)
	attachmentString = paste0("attachment; filename=phenotype_panel.", creation_date, ".xlsx")

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

## Phenotype endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Status endpoints

#* @tag status
## get a single status by status_id
#* @serializer json list(na="null")
#' @get /api/status/<status_requested>
function(status_requested) {
	# remove spaces from list
	status_requested <- URLdecode(status_requested) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all(" ", "") %>%
		unique()

	# get data from database and filter
	sysndd_db_status_table <- pool %>% 
		tbl("ndd_entity_status")
	user_table <- pool %>% 
		tbl("user") %>% 
		select(user_id, user_name, user_role)
	ndd_entity_status_categories_collected <- pool %>% 
		tbl("ndd_entity_status_categories_list")

	sysndd_db_status_table_collected <- sysndd_db_status_table %>%
		filter(status_id == status_requested) %>%
		inner_join(ndd_entity_status_categories_collected, by=c("category_id")) %>%
		left_join(user_table, by = c("status_user_id" = "user_id")) %>%
		left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
		collect() %>%
		select(status_id, entity_id, category, category_id, is_active, status_date, status_user_name = user_name.x, status_user_role = user_role.x, status_approved, approving_user_name = user_name.y, approving_user_role = user_role.y, comment, problematic) %>%
		arrange(status_date)

	sysndd_db_status_table_collected
}

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


#* @tag status
## post a new status for a entity_id
#* @serializer json list(na="string")
#' @post /api/status
function(req, res, status_json) {
	# first check rights
	if ( req$user_role %in% c("Admin", "Curator", "Reviewer") ) {
				
		status_user_id <- req$user_id
		status_data <- fromJSON(status_json)

		if ( !is.null(status_data$category) ) {

			status_received <- as_tibble(status_data) %>% 
				add_column(status_user_id) %>% 
				select(entity_id = entity, category_id = category, status_user_id, comment)

			# connect to database
			sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

			# submit the new status and disconnect from database
			dbAppendTable(sysndd_db, "ndd_entity_status", status_received)
			dbDisconnect(sysndd_db)
				
		} else {
			res$status <- 400 # Bad Request
			return(list(error="Submitted data can not be null."))
		}

	} else {
		res$status <- 403 # Forbidden
		return(list(error="Write access forbidden."))
	}
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
## get panel data by cetgory and inheritance terms for browsing
#* @serializer json list(na="string")
#* @param category_input The entity association category to filter.
#* @param inheritance_input The entity inheritance type to filter.
#* @param output_columns Comma separated list of output columns (choose from: category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38).
#* @param output_sort Output column to arrange output on (choose from: category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38).
#' @get /api/panels/browse
function(category_input = "Definitive", inheritance_input = "All", output_columns = "category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38", output_sort = "symbol", res) {
	
	output_columns_list <- URLdecode(output_columns) %>%
		str_split(pattern=",", simplify=TRUE) %>%
		str_replace_all(" ", "") %>%
		unique()

	# generate table with field information for display
	fields_tibble <- as_tibble(output_columns_list) %>%
		select(key = value) %>%
		mutate(label = str_to_sentence(str_replace_all(key, "_", " "))) %>%
		mutate(sortable = "true") %>%
		mutate(class = "text-left") %>%
		mutate(sortByFormatted = "true") %>%
		mutate(filterByFormatted = "true")        

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
		mutate(inheritance_filter = case_when(
		  str_detect(inheritance, "X-linked") ~ "X-linked",
		  str_detect(inheritance, "Autosomal dominant inheritance") ~ "Dominant",
		  str_detect(inheritance, "Autosomal recessive inheritance") ~ "Recessive",
		  TRUE ~ "Other"
		)) %>%
		mutate(category_filter = category) %>%
		select(category, inheritance, symbol, hgnc_id, entrez_id, ensembl_gene_id, ucsc_id, bed_hg19, bed_hg38, category_filter, inheritance_filter) %>%
		arrange(desc(category), inheritance)
	
	# compute output based on input parameters
	if ( (category_input == "All") & (inheritance_input == "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(category_filter = "All") %>%
			mutate(inheritance_filter = "All") %>%
			unique() %>%
			filter(category_filter == category_input, inheritance_filter == inheritance_input) %>%
			arrange(symbol, inheritance) %>%
			group_by(symbol) %>%
			mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
			ungroup() %>%
			unique() %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else if ( (category_input == "All") & (inheritance_input != "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(category_filter = "All") %>%
			unique() %>%
			filter(category_filter == category_input, inheritance_filter == inheritance_input) %>%
			arrange(symbol, inheritance) %>%
			group_by(symbol) %>%
			mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
			ungroup() %>%
			unique() %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else if ( (category_input != "All") & (inheritance_input == "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(inheritance_filter = "All") %>%
			unique() %>%
			filter(category_filter == category_input, inheritance_filter == inheritance_input) %>%
			arrange(symbol, inheritance) %>%
			group_by(symbol) %>%
			mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
			ungroup() %>%
			unique() %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			unique() %>%
			filter(category_filter == category_input, inheritance_filter == inheritance_input) %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	}

	# return list of format and data
	list(fields = fields_tibble, data = sysndd_db_disease_genes_panel)

}



#* @tag panels
## get panel data by cetgory and inheritance terms for download as Excel file
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
		mutate(inheritance_filter = case_when(
		  str_detect(inheritance, "X-linked") ~ "X-linked",
		  str_detect(inheritance, "Autosomal dominant inheritance") ~ "Dominant",
		  str_detect(inheritance, "Autosomal recessive inheritance") ~ "Recessive",
		  TRUE ~ "Other"
		)) %>%
		mutate(category_filter = category) %>%
		select(category, inheritance, symbol, hgnc_id, entrez_id, ensembl_gene_id, ucsc_id, bed_hg19, bed_hg38, category_filter, inheritance_filter) %>%
		arrange(desc(category), inheritance)
	
	# compute output based on input parameters
	if ( (category_input == "All") & (inheritance_input == "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(category_filter = "All") %>%
			mutate(inheritance_filter = "All") %>%
			unique() %>%
			filter(category_filter == category_input, inheritance_filter == inheritance_input) %>%
			arrange(symbol, inheritance) %>%
			group_by(symbol) %>%
			mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
			ungroup() %>%
			unique() %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else if ( (category_input == "All") & (inheritance_input != "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(category_filter = "All") %>%
			unique() %>%
			filter(category_filter == category_input, inheritance_filter == inheritance_input) %>%
			arrange(symbol, inheritance) %>%
			group_by(symbol) %>%
			mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
			ungroup() %>%
			unique() %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else if ( (category_input != "All") & (inheritance_input == "All") ) {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			mutate(inheritance_filter = "All") %>%
			unique() %>%
			filter(category_filter == category_input, inheritance_filter == inheritance_input) %>%
			arrange(symbol, inheritance) %>%
			group_by(symbol) %>%
			mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
			ungroup() %>%
			unique() %>%
			arrange(!!sym(output_sort)) %>%
			select(all_of(output_columns_list))
	} else {
		sysndd_db_disease_genes_panel <- sysndd_db_disease_genes %>%
			unique() %>%
			filter(category_filter == category_input, inheritance_filter == inheritance_input) %>%
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
	attachmentString = paste0("attachment; filename=panel.", category_input, "_", inheritance_input, ".", creation_date, ".xlsx")
		  
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
		left_join(sysndd_db_disease_genes_grouped_by_category_and_inheritance, by = c("category")) %>%
		arrange(category)

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

	make_entities_plot(sysndd_db_disease_collected)
}

## Statistics endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Comparisons endpoints

#* @tag comparisons
## Return interactive plot showing intersection between different databases
#* @serializer json list(na="string")
#' @get /api/comparisons/upset
function() {
	# get data from database and filter
	ndd_database_comparison_gene_list  <- pool %>% 
		tbl("ndd_database_comparison_view") %>%
		collect() %>%
		select(name = hgnc_id, sets = list) %>%
		unique() %>%
		group_by(name) %>%
		arrange(name) %>%
		mutate(sets = str_c(sets, collapse = ",")) %>%
		unique() %>%
		ungroup() %>%
		mutate(sets = strsplit(sets,","))
}

#* @tag comparisons
## Return interactive plot data showing intersection between different databases
#* @serializer text
#' @get /api/comparisons/correlation_plot
function() {
	# get data from database, filter and restructure
	ndd_database_comparison_matrix  <- pool %>% 
		tbl("ndd_database_comparison_view") %>%
		collect() %>%
		select(hgnc_id, list) %>%
		unique() %>%
		mutate(in_list = list) %>%
		pivot_wider(names_from = list, values_from = in_list) %>%
		select(-hgnc_id) %>%
		mutate_all(~ case_when(
			  is.na(.) ~ 0,
			  !is.na(.) ~ 1,
			)
		)

	# compute correlation matrix
	ndd_database_comparison_correlation <- cosine(ndd_database_comparison_matrix)
	ndd_database_comparison_correlation_melted <- melt(ndd_database_comparison_correlation)

	# generate plot
	make_matrix_plot(ndd_database_comparison_correlation_melted)

}


#* @tag comparisons
## Return table swhoing the presence of NDD assoicated genes in different databases
#* @serializer json list(na="string")
#' @get /api/comparisons/table
function() {
	# get data from database, filter and restructure
	
	ndd_database_comparison_view <- pool %>% 
		tbl("ndd_database_comparison_view")
	
	sysndd_db_non_alt_loci_set <- pool %>% 
		tbl("non_alt_loci_set") %>%
		select(hgnc_id, symbol)
	
	ndd_database_comparison_table  <- ndd_database_comparison_view %>% 
		left_join(sysndd_db_non_alt_loci_set, by =c("hgnc_id")) %>%
		collect() %>%
		select(symbol, hgnc_id, list) %>%
		unique() %>%
		mutate(in_list = "yes") %>%
		pivot_wider(names_from = list, values_from = in_list) %>%
		mutate_at(vars(-hgnc_id, -symbol), ~ case_when(
			  is.na(.) ~ "no",
			  !is.na(.) ~ "yes"
			)
		)

	# return table
	ndd_database_comparison_table

}
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
## example data: {"user_name":"nextuser21", "first_name":"Mark", "family_name":"Sugar", "email":"bernt.popp.md2@gmail.com", "orcid":"0001-0002-3679-1081", "comment":"I love research", "terms_agreed":"accepted"}
#* @serializer json list(na="string")
#' @get /api/auth/signup
function(signup_data) {
	user <- as_tibble(fromJSON(signup_data)) %>%
			mutate(terms_agreed = case_when(
			  terms_agreed == "accepted" ~ "1",
			  terms_agreed != "accepted" ~ "0"
			)) %>%
		select(user_name, first_name, family_name, email, orcid, comment, terms_agreed)

	input_validation <- pivot_longer(user, cols = everything()) %>%
			mutate(valid = case_when(
			  name == "user_name" ~ (nchar(value) >= 5 & nchar(value) <= 20),
			  name == "first_name" ~ (nchar(value) >= 2 & nchar(value) <= 50),
			  name == "family_name" ~ (nchar(value) >= 2 & nchar(value) <= 50),
			  name == "email" ~ str_detect(value, regex(".+@.+\\..+", dotall = TRUE)),
			  name == "orcid" ~ str_detect(value, regex("^(([0-9]{4})-){3}[0-9]{3}[0-9X]$", dotall = TRUE)),
			  name == "comment" ~ (nchar(value) >= 10 & nchar(value) <= 250),
			  name == "terms_agreed" ~ (value == "1")
			)) %>%
			mutate(all = "1") %>%
			select(all, valid) %>%
			group_by(all) %>%
			summarise(valid = as.logical(prod(valid))) %>%
			ungroup() %>%
			select(valid)

	if (input_validation$valid){

		# connect to database
		sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)

		dbAppendTable(sysndd_db, "user", user)
		
		dbDisconnect(sysndd_db)
		
		email <- compose_email(
		  body = md(c(
			 "Your registration request for sysndd.org has been send to the curators who will review it soon. Information provided:",
			 user
		  ))
		)

		email %>%
		  smtp_send(
			from = "noreply@sysndd.org",
			to = user$email,
			subject = "Your registration request to SysNDD.org",
			credentials = creds_envvar(
				pass_envvar = "SMTP_PASSWORD",
				user = dw$mail_noreply_user,
				host = dw$mail_noreply_host,
				port = dw$mail_noreply_port,
			use_ssl = dw$mail_noreply_use_ssl
			)
		  )
		res <- "Registered successfully!"
	
  } else {
		res$status <- 404
		res$body <- "Please provide valid registration data."
		res
  }
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
		  if (is.null(check_user) || nchar(check_user) < 5 || nchar(check_user) > 20 || is.null(check_pass) || nchar(check_pass) < 5 || nchar(check_pass) > 50) {
			res$status <- 404
			res$body <- "Please provide valid username and password."
			res
		  }

	# connect to database, find user in database and password is correct
	user_filtered <- pool %>% 
		tbl("user") %>%
		filter(user_name == check_user & password == check_pass & approved == 1) %>%
		select(-password) %>%
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
		claim <- jwt_claim(user_id = user_filtered$user_id, user_name = user_filtered$user_name, email = user_filtered$email, user_role = user_filtered$user_role, user_created = user_filtered$created_at, abbreviation = user_filtered$abbreviation, orcid = user_filtered$orcid, iat = user_filtered$iat, exp = user_filtered$exp)
		
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
		return(list(user_id = user$user_id, user_name = user$user_name, email = user$email, user_role = user$user_role, user_created = user$user_created, abbreviation = user$abbreviation, orcid = user$orcid, exp = user$exp))
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
		claim <- jwt_claim(user_id = user$user_id, user_name = user$user_name, email = user$email, user_role = user$user_role, user_created = user$user_created, abbreviation = user$abbreviation, orcid = user$orcid, iat = as.numeric(Sys.time()), exp = as.numeric(Sys.time()) + dw$refresh)

		jwt <- jwt_encode_hmac(claim, secret = key)
		jwt
	}
}

##Authentication section
##-------------------------------------------------------------------##
