############################################
## load libraries
## to do: change to DBI/RMariaDB, have to automate connection using yml file
library(tidyverse)  ##needed for general table operations
library(jsonlite)  ##needed for HGNC requests
library(DBI)    ##needed for MySQL data export
library(RMariaDB)  ##needed for MySQL data export
library(sqlr)    ##needed for MySQL data export
library(httr2)  ##needed for direct PubMed E-utilities requests
library(xml2)  ##needed for PubMed XML parsing
library(rvest)    ##needed for genereviews scrape
library(lubridate)  ##needed for genereviews scrape
library(ssh)    ##needed for SSH connection to sysid database
library(readxl)    ## needed for excel import
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
## connect to the SysID source (issue #33: reproducible import)
## db_sysid_source_mode() selects "sqlite" (a local, reproducible snapshot —
## recommended) or "mysql" (the legacy upstream SysID DB over an SSH tunnel).
## See db/config/db_sysid_source.R and db/README.md "Reproducible SysID import".
sysid_mode <- db_sysid_source_mode(config_vars_proj)

if (sysid_mode == "mysql") {
  ## legacy path: open an SSH tunnel to the upstream SysID MySQL instance.
  cmd <- paste0('ssh::ssh_tunnel(ssh::ssh_connect(host = "',
    config_vars_proj$host_sysid,
    ', passwd = "',
    config_vars_proj$passwd_sysid,
    '"), port = ',
    config_vars_proj$port_sysid_local,
    ', target = "',
    config_vars_proj$server_sysid_local,
    ':',
    config_vars_proj$port_sysid_local,
    '")')

  pid <- sys::r_background(
      std_out = FALSE,
      std_err = FALSE,
      args = c("-e", cmd)
  )
}

## open a source-agnostic connection (SQLite snapshot or tunnelled MySQL)
sysid_db <- db_sysid_connect(config_vars_proj, mode = sysid_mode)
############################################



############################################
## load the diseases and human_gene table from the local SysID database MySQL instance
sysid_db_disease <- tbl(sysid_db, "disease")
sysid_db_disease_collected <- sysid_db_disease %>%
  collect()
############################################



############################################
## define functions
normalize_pubmed_ids <- function(pmid_input) {
  if (is.null(pmid_input) || length(pmid_input) == 0) {
    return(character())
  }

  pmids <- as.character(unlist(pmid_input, use.names = FALSE))
  pmids <- str_trim(pmids)
  pmids <- str_remove(pmids, regex("^PMID:", ignore_case = TRUE))
  pmids <- pmids[!is.na(pmids) & nzchar(pmids)]
  pmids
}

pubmed_fetch_xml <- function(pmids) {
  pmids <- unique(normalize_pubmed_ids(pmids))
  pmids <- pmids[str_detect(pmids, "^[0-9]+$")]
  if (length(pmids) == 0L) {
    return("<PubmedArticleSet/>")
  }

  request(db_source_url("ncbi_eutils_efetch", db_src)) %>%
    req_url_query(
      db = "pubmed",
      id = str_c(pmids, collapse = ","),
      retmode = "xml",
      rettype = "xml"
    ) %>%
    req_retry(
      max_tries = 3,
      backoff = ~ 2^.x,
      is_transient = ~ resp_status(.x) %in% c(429, 500, 502, 503, 504)
    ) %>%
    req_timeout(30) %>%
    req_perform() %>%
    resp_body_string()
}

pubmed_text_first <- function(node, xpath, default = "") {
  value <- xml2::xml_text(xml2::xml_find_first(node, xpath))
  if (length(value) == 0L || is.na(value)) {
    return(default)
  }
  value
}

pubmed_text_all <- function(node, xpath) {
  values <- xml2::xml_text(xml2::xml_find_all(node, xpath))
  values[!is.na(values)]
}

pubmed_date_part <- function(article, part) {
  xpath <- paste0(
    ".//PubMedPubDate[@PubStatus = 'pubmed' or @Pubstatus = 'pubmed']/",
    part
  )
  value <- pubmed_text_first(article, xpath, default = NA_character_)
  if (is.na(value)) {
    value <- pubmed_text_first(article, paste0(".//Article/Journal/JournalIssue/PubDate/", part),
      default = NA_character_
    )
  }
  value
}

pubmed_articles_from_xml <- function(pubmed_xml_data) {
  pmid_xml <- xml2::read_xml(pubmed_xml_data)
  articles <- xml2::xml_find_all(pmid_xml, "//PubmedArticle")

  purrr::map_dfr(articles, function(article) {
    doi <- pubmed_text_first(article, ".//Article/ELocationID[@EIdType = 'doi']",
      default = NA_character_
    )
    if (is.na(doi)) {
      doi <- pubmed_text_first(article, ".//ArticleId[@EIdType = 'doi']",
        default = NA_character_
      )
    }
    if (is.na(doi)) {
      doi <- pubmed_text_first(article, ".//ArticleId[@IdType = 'doi' and not(ancestor::ReferenceList)]")
    }

    lastname <- pubmed_text_first(article, ".//AuthorList/Author[1]/LastName")
    firstname <- pubmed_text_first(article, ".//AuthorList/Author[1]/ForeName")
    collective <- pubmed_text_first(article, ".//AuthorList/Author[1]/CollectiveName",
      default = NA_character_
    )
    if ((lastname == "" || firstname == "") && !is.na(collective)) {
      lastname <- collective
      firstname <- collective
    }

    year <- pubmed_date_part(article, "Year")
    month <- pubmed_date_part(article, "Month")
    day <- pubmed_date_part(article, "Day")
    if (is.na(year) || is.na(month) || is.na(day)) {
      year <- format(Sys.time(), "%Y")
      month <- format(Sys.time(), "%m")
      day <- format(Sys.time(), "%d")
    }

    mesh <- pubmed_text_all(article, ".//DescriptorName")
    keyword <- pubmed_text_all(article, ".//Keyword")

    tibble::tibble(
      publication_id = pubmed_text_first(article, ".//MedlineCitation/PMID"),
      DOI = doi,
      Title = str_c(pubmed_text_all(article, ".//Article/ArticleTitle"), collapse = " "),
      Abstract = str_c(pubmed_text_all(article, ".//AbstractText"), collapse = " "),
      Year = year,
      Month = str_pad(month, 2, "left", pad = "0"),
      Day = str_pad(day, 2, "left", pad = "0"),
      Journal_abbreviation = pubmed_text_first(article, ".//Article/Journal/ISOAbbreviation"),
      Journal = pubmed_text_first(article, ".//Article/Journal/Title"),
      Keywords = str_c(unique(str_squish(c(mesh, keyword))), collapse = "; "),
      Lastname = lastname,
      Firstname = firstname
    )
  })
}

pubmed_info_from_pmid <- function(pmid_tibble, request_max = 200) {
  request_max <- as.integer(request_max)
  if (is.na(request_max) || request_max < 1L) {
    stop("request_max must be a positive integer")
  }

  input_tibble <- tibble::tibble(publication_id = normalize_pubmed_ids(pmid_tibble))
  requested_publication_ids <- unique(input_tibble$publication_id)
  chunks <- split(
    requested_publication_ids,
    ceiling(seq_along(requested_publication_ids) / request_max)
  )

  input_tibble_request <- purrr::map_dfr(chunks, function(chunk) {
    pubmed_fetch_xml(chunk) %>%
      pubmed_articles_from_xml()
  })

  ouput_tibble <- input_tibble %>%
    left_join(input_tibble_request, by = "publication_id")
  
  return(ouput_tibble)
}


genereviews_from_pmid <- function(pmid_input)  {
  url_request <- paste0(db_source_url("ncbi_books_base", db_src), "/NBK1116/?term=", pmid_input)
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
  genereviews_url <- paste0(db_source_url("ncbi_books_base", db_src), "/", Bookshelf_ID)
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

  return_tibble <- as_tibble_row(c("publication_id" = pmid, "Bookshelf_ID" = Bookshelf_ID, "Title" = title[1], "Abstract" = abstract, "Date" = date_revision, "First_author" = first_author, "Keywords" = keywords)) %>%
    separate(Date, c("Day", "Month", "Year"), sep = " ") %>%
    mutate(Month = match(Month, month.name)) %>%
    separate(First_author, c("Firstname", "Lastname") , sep = " (?=[^ ]*$)", extra = "merge") %>%
    mutate(Journal_abbreviation = "GeneReviews") %>%
    mutate(Journal = "GeneReviews") %>%
    select(publication_id, Bookshelf_ID, Title, Abstract, Year, Month, Day, Journal_abbreviation, Journal, Keywords, Lastname, Firstname)
  
  close(genereviews_url)
  return(return_tibble)
}  
############################################



############################################
## load precomputed ndd_entity_review csv table to merge review_id
ndd_entity_review_files <- list.files(path = "results/") %>%
  as_tibble() %>%
  filter(str_detect(value, "ndd_entity_review")) %>%
  mutate(date = str_split(value, "\\.", simplify = TRUE)[, 2]) %>%
  arrange(date)

ndd_entity_review_ids <- read_csv(paste0("results/", ndd_entity_review_files$value[1])) %>%
  select(review_id, entity_id)
############################################



############################################
##
query_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")

ndd_entity_publications <- sysid_db_disease_collected %>%
  select(human_gene_disease_id, additional_references, gene_review) %>%
  pivot_longer(-human_gene_disease_id, names_to = "publication_type", values_to = "publication_id") %>%
  filter(publication_id != "" & !is.na(publication_id)) %>%
  separate_rows(publication_id, sep = ",") %>%
  mutate(publication_id = str_remove(publication_id, "PMID: ")) %>%
  mutate(publication_id = as.numeric(publication_id))

ndd_review_publication_join <- ndd_entity_publications %>%
  select(entity_id = human_gene_disease_id, publication_id, publication_type) %>%
  mutate(publication_id = paste0("PMID:", publication_id)) %>%
  arrange(entity_id) %>%
  rownames_to_column(var = "review_publication_id") %>%
  select(review_publication_id, entity_id, publication_id, publication_type) %>%
  mutate(is_reviewed = TRUE) %>%
  left_join(ndd_entity_review_ids, by = c("entity_id")) %>%
  select(review_publication_id, review_id, entity_id, publication_id, publication_type, is_reviewed)

ndd_entity_publication_not_gene_review <- ndd_entity_publications %>%
  select(publication_id, publication_type) %>%
  filter(publication_type != "gene_review") %>%
  arrange(publication_id) %>%
  unique() %>%
  mutate(pubmed_info = pubmed_info_from_pmid(publication_id))

ndd_entity_publication_is_gene_review <- ndd_entity_publications %>%
  select(publication_id, publication_type) %>%
  filter(publication_type == "gene_review") %>%
  arrange(publication_id) %>%
  unique() %>%
  rowwise() %>%
  mutate(Bookshelf_ID_pmid = genereviews_from_pmid(publication_id)) %>%
  ungroup()

ndd_entity_publication_is_gene_review_info <- ndd_entity_publication_is_gene_review %>%
  filter(Bookshelf_ID_pmid != "") %>%
  rowwise() %>%
  mutate(genereviews_info = info_from_genereviews(Bookshelf_ID_pmid)) %>%
  ungroup()

ndd_entity_publication_not_gene_review_formated <- ndd_entity_publication_not_gene_review %>%
  mutate(publication_id = paste0("PMID:", publication_id)) %>%
  mutate(other_publication_id = case_when(
    pubmed_info$DOI == "" ~ "", 
    pubmed_info$DOI != "" ~ paste0("DOI:", pubmed_info$DOI))) %>%
  mutate(other_publication_id = na_if(other_publication_id, "")) %>%
  mutate(Title = pubmed_info$Title) %>%
  mutate(Abstract = pubmed_info$Abstract) %>%
  mutate(Year = pubmed_info$Year) %>%
  mutate(Month = pubmed_info$Month) %>%
  mutate(Day = pubmed_info$Day) %>%
  mutate(Publication_date = as.Date(paste0(Year,"-",Month,"-",Day))) %>%
  mutate(Journal_abbreviation = pubmed_info$Journal_abbreviation) %>%
  mutate(Journal = pubmed_info$Journal) %>%
  mutate(Keywords = pubmed_info$Keywords) %>%
  mutate(Lastname = pubmed_info$Lastname) %>%
  mutate(Firstname = pubmed_info$Firstname) %>%
  select(-pubmed_info, -Year, -Month, -Day)

ndd_entity_publication_is_gene_review_formated <- ndd_entity_publication_is_gene_review_info %>%
  mutate(publication_id = paste0("PMID:", publication_id)) %>%
  mutate(other_publication_id = paste0("BookshelfID:", genereviews_info$Bookshelf_ID)) %>%
  mutate(Title = genereviews_info$Title) %>%
  mutate(Abstract = genereviews_info$Abstract) %>%
  mutate(Year = genereviews_info$Year) %>%
  mutate(Month = genereviews_info$Month) %>%
  mutate(Day = genereviews_info$Day) %>%
  mutate(Publication_date = as.Date(paste0(Year,"-",Month,"-",Day))) %>%
  mutate(Journal_abbreviation = genereviews_info$Journal_abbreviation) %>%
  mutate(Journal = genereviews_info$Journal) %>%
  mutate(Keywords = genereviews_info$Keywords) %>%
  mutate(Lastname = genereviews_info$Lastname) %>%
  mutate(Firstname = genereviews_info$Firstname) %>%
  select(-genereviews_info, -Bookshelf_ID_pmid, -Year, -Month, -Day)

publication <- ndd_entity_publication_not_gene_review_formated %>%
  bind_rows(ndd_entity_publication_is_gene_review_formated) %>%
  mutate(update_date = query_date)

############################################



############################################
## define location of excel sheet with phenotype information
publication_missing_info <- "data/publication_missing_info.xlsx"
############################################



############################################
## load the excel sheet for accompanying phenotype letter to HPO term conversion
publication_missing_info_table <- read_excel(publication_missing_info, sheet = "missing", na = "NA") %>%
  mutate(update_date = query_date) %>%
  mutate(Publication_date = as.Date(Publication_date))
############################################



############################################
## 
publication_fixed <- publication %>% 
  filter(!is.na(Title)) %>%
  bind_rows(publication_missing_info_table) %>%
  mutate(update_date = as.Date(update_date)) %>%
  mutate(Fulltext = "missing") %>%
  select(publication_id, publication_type, other_publication_id, Title, Abstract, Fulltext, Publication_date, Journal_abbreviation, Journal, Keywords, Lastname, Firstname, update_date)
############################################



############################################
## export as csv with date of creation
creation_date <- strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%d")
write_csv(publication_fixed, file = paste0("results/publication.",creation_date,".csv"))
write_csv(ndd_review_publication_join, file = paste0("results/ndd_review_publication_join.",creation_date,".csv"))
############################################



############################################
## close database connection
rm_con()
############################################
