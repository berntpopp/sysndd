
## pubmed and genereviews functions

# this function checks whether all PMIDs in a list are valid and can be found in pubmed, returns true if all are and false if one is invalid
check_pmid <- function(pmid_input) {
	input_tibble <- as_tibble(pmid_input) %>%
		mutate(publication_id = as.character(value)) %>%
		mutate(publication_id = str_remove(publication_id, "PMID:")) %>%
		select(-value)

	input_tibble_request <- input_tibble %>%
		mutate(publication_id = paste0(publication_id, "[PMID]")) %>%
		unique() %>%
		rowwise() %>%
		mutate(count = get_pubmed_ids(publication_id)$Count) %>%
		ungroup()

	return(as.logical(prod(as.logical(as.integer(input_tibble_request$count)))))
}


# this function takes a tibble of publication_ids and publication_types and adds them to the database if they are new
new_publication <- function(publications_received) {
	# check if all received PMIDs are valid
	if ( check_pmid(publications_received$publication_id) ) {

		# check if publication_ids are already present in the database
		publications_list_collected <- pool %>%
			tbl("publication") %>%
			select(publication_id, update_date) %>%
			arrange(publication_id) %>%
			collect() %>%
			right_join(publications_received, by = c("publication_id")) %>%
			filter(is.na(update_date)) %>%
			select(-update_date)

		# subset by publication_type
		publications_list_collected_generevies <- publications_list_collected %>%
			filter(publication_type == "gene_review")
		publications_list_collected_other <- publications_list_collected %>%
			filter(publication_type != "gene_review")

		# check if subset list is longer then 0 then get info
		if ( length(compact(publications_list_collected_generevies$publication_id)) > 0 ) {
			publications_list_collected_generevies_info <- publications_list_collected_generevies %>%
				rowwise() %>%
				mutate(info = info_from_genereviews_pmid(publication_id) ) %>%
				unnest(info)
		}
		
		# check if subset list is longer then 0 then get info
		if ( length(compact(publications_list_collected_other$publication_id)) > 0 ) {
			publications_list_collected_other_info <- publications_list_collected_other %>%
				rowwise() %>%
				mutate(info = info_from_pmid(publication_id) ) %>%
				unnest(info)
		}

		# bin tghe two tibbles if they exist
		publications_list_collected_info <- bind_rows(get0("publications_list_collected_generevies_info"), get0("publications_list_collected_other_info"))

		# connect to database
		sysndd_db <- dbConnect(RMariaDB::MariaDB(), dbname = dw$dbname, user = dw$user, password = dw$password, server = dw$server, host = dw$host, port = dw$port)
		# add new publications to database table "publication" if present and not NA
		if (nrow(publications_list_collected_info) > 0) {
			dbAppendTable(sysndd_db, "publication", publications_list_collected_info)
		}
		# disconnect from database
		dbDisconnect(sysndd_db)
				
		# return OK
		return(list(status=200,message="OK. Entry created."))
		
	} else {
		# return Bad Request
		return(list(status=400,message="Bad Request. Invalid PMIDs detected."))
	}
}


info_from_pmid <- function(pmid_tibble, request_max = 200) {
	pmid_tibble <- str_replace_all(pmid_tibble, "PMID:", "")
	
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
		mutate(other_publication_id = paste0("DOI:", doi)) %>%
		mutate(Publication_date = paste0(year, "-", month, "-", day)) %>%
		select(-publication_id, -group, -response) %>%
		select(publication_id = pmid, other_publication_id, Title = title, Abstract = abstract, Publication_date, Journal_abbreviation = jabbrv, Journal = journal, Keywords= keywords, Lastname = lastname, Firstname = firstname)

	ouput_tibble <- input_tibble %>%
		left_join(input_tibble_request, by = "publication_id") %>%
		select(-publication_id) %>% 
		mutate(across(everything(), ~replace_na(.x, "")))
	
	return(ouput_tibble)
}


info_from_genereviews_pmid <- function(pmid_input) {
	pmid_input <- str_replace_all(pmid_input, "PMID:", "")

	Bookshelf_IDs <- genereviews_from_pmid(pmid_input)
	ouput_tibble <- info_from_genereviews(Bookshelf_IDs)
	
	return(ouput_tibble)
}


genereviews_from_pmid <- function(pmid_input) {
	url_request <- paste0("https://www.ncbi.nlm.nih.gov/books/NBK1116/?term=", pmid_input)
	url_request = url(url_request, "rb")
	
	webpage_request <- xml2::read_html(url_request, options = c("RECOVER"))
	close(url_request)
	
	Bookshelf_ID <- webpage_request %>% 
		html_nodes("div.rslt") %>%
		html_nodes("p.title") %>% 
		html_nodes("a") %>% 
		html_attr('href') %>%
		str_replace("/books/", "") %>%
		str_replace("/", "")
	
	Bookshelf_ID_tibble <- as_tibble(Bookshelf_ID)
	Bookshelf_IDs <- str_c(Bookshelf_ID_tibble$value, collapse = ",")

	return(Bookshelf_IDs)
}


info_from_genereviews <- function(Bookshelf_ID) {
	genereviews_url <- paste0("https://www.ncbi.nlm.nih.gov/books/", Bookshelf_ID)
	genereviews_url = url(genereviews_url, "rb")

	genereviews_request <- xml2::read_html(genereviews_url, options = "RECOVER")
	close(genereviews_url)
	
	pmid <- genereviews_request %>% 
		html_nodes("div.small") %>%
		html_nodes("span.label") %>%
		html_nodes("a") %>%
		html_attr('href') %>%
		str_replace("/pubmed/", "") %>%
		str_replace("/", "")
		
	title <- genereviews_request %>% 
		html_nodes("title") %>%  
		html_text()%>%
		str_replace_all("title", "") %>%
		str_replace_all("\\/", "") %>%
		str_replace_all("<>", "") %>%
		str_replace_all(" -.+", "")

	abstract <- genereviews_request %>% 
		html_nodes(xpath = "//div[contains(h2, 'Summary')]") %>%
		html_text() %>%
		str_replace_all("<.+?>", "") %>%
		str_replace_all("\n", " ") %>%
		str_squish()

	date_revision <- genereviews_request %>% 
		html_nodes(xpath = "//div[contains(h3, 'Revision History')]") %>%  
		html_text() %>%
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
		html_text() %>%
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
		mutate(other_publication_id = paste0("Bookshelf_ID:", Bookshelf_ID)) %>%
		mutate(Publication_date = paste0(Year, "-", str_pad(Month, 2, pad = "0"), "-", str_pad(Day, 2, pad = "0"))) %>%
		select(publication_id, other_publication_id, Title, Abstract, Publication_date, Journal_abbreviation, Journal, Keywords, Lastname, Firstname) %>%
		select(-publication_id) %>% 
		mutate(across(everything(), ~replace_na(.x, "")))

	return(return_tibble)
}