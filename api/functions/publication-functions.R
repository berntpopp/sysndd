# functions/publication-functions.R
#### This file holds pubmed functions

# load source files if not already loaded
if (!exists("info_from_genereviews_pmid", mode = "function")) {
  source("functions/genereviews-functions.R", local = TRUE)
}

#' A function that checks whether all PMIDs in a list are valid
#' and can be found in pubmed, returns true if all are and
#' false if one is invalid
#'
#' @param pmid_input A list of PMIDs
#'
#' @return Boolean value representing if all PMIDs were found
#' @export
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


#' A function that takes a tibble of publication_ids and
#' publication_types and adds them to the database if they are new
#'
#' @param publications_received tibble with publication_id and publication_type
#'
#' @return list with http status message
#' @export
new_publication <- function(publications_received) {
  # check if all received PMIDs are valid
  if (check_pmid(publications_received$publication_id)) {

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
    pub_list_coll_gr <- publications_list_collected %>%
      filter(publication_type == "gene_review")
    pub_list_coll_other <- publications_list_collected %>%
      filter(publication_type != "gene_review")

    # check if subset list is longer then 0 then get info
    if (length(compact(pub_list_coll_gr$publication_id)) > 0) {
      pub_list_coll_gr_info <- pub_list_coll_gr %>%
        rowwise() %>%
        mutate(info = info_from_genereviews_pmid(publication_id)) %>%
        unnest(info)
    }

    # check if subset list is longer then 0 then get info
    if (length(compact(pub_list_coll_other$publication_id)) > 0) {
      pub_list_coll_other_info <- pub_list_coll_other %>%
        rowwise() %>%
        mutate(info = info_from_pmid(publication_id)) %>%
        unnest(info)
    }

    # bind the two tibbles if they exist
    publications_list_collected_info <- bind_rows(get0("pub_list_coll_gr_info"),
      get0("pub_list_coll_other_info"))

    # add new publications to database table "publication" if present and not NA
    if (nrow(publications_list_collected_info) > 0) {
      poolWithTransaction(pool, function(conn) {
        dbAppendTable(conn, "publication", publications_list_collected_info)
      })
    }

    # return OK
    return(list(status = 200, message = "OK. Entry created."))

  } else {
    # return Bad Request
    return(list(status = 400, message = "Bad Request. Invalid PMIDs detected."))
  }
}


#' This custom function replaces "table_articles_byAuth" from
#' easypubmed because that function is buggy
#'
#' @param pubmed_xml_data A XML string from Pubmed API
#'
#' @return tibble with article information columns
#' @export
table_articles_from_xml <- function(pubmed_xml_data) {
# convert to xml
pmid_xml <- read_xml(pubmed_xml_data)

# extract values
pmid <- pmid_xml %>%
  xml_find_all("//PMID") %>%
  xml_text()

doi <- (pmid_xml %>%
  xml_find_all("//ELocationID[@EIdType='doi']") %>%
  xml_text())

doi2 <- pmid_xml %>%
  xml_find_all("//ArticleId[@EIdType='doi']") %>%
  xml_text()

doi3 <- pmid_xml %>%
  xml_find_all("//ArticleId[@IdType='doi' and
    not(ancestor::ReferenceList)]") %>%
    # this removes possible citations from the DOI list
  xml_text()

if (length(doi) == 0 && length(doi2) != 0) {
    doi <- doi2
} else if (length(doi) == 0 &&
  length(doi2) == 0 &&
  length(doi3) != 0) {
    doi <- doi3
} else if (length(doi) == 0 &&
  length(doi2) == 0 &&
  length(doi3) == 0) {
    doi <- ""
}

title <- pmid_xml %>%
  xml_find_all("//ArticleTitle") %>%
  xml_text()

abstract <- pmid_xml %>%
  xml_find_all("//AbstractText") %>%
  xml_text()

jabbrv <- pmid_xml %>%
  xml_find_all("//ISOAbbreviation") %>%
  xml_text()

journal <- pmid_xml %>%
  xml_find_all("//Title") %>%
  xml_text()

# get both keyword and mesh terms, later merge
mesh <- pmid_xml %>%
  xml_find_all("//DescriptorName") %>%
  xml_text()

keyword <- pmid_xml %>%
  xml_find_all("//Keyword") %>%
  xml_text()

year <- pmid_xml %>%
  xml_find_all("//PubMedPubDate[@Pubstatus = 'pubmed']/Year") %>%
  xml_text()

month <- pmid_xml %>%
  xml_find_all("//PubMedPubDate[@Pubstatus = 'pubmed']/Month") %>%
  xml_text()

day <- pmid_xml %>%
  xml_find_all("//PubMedPubDate[@Pubstatus = 'pubmed']/Day") %>%
  xml_text()

lastname <- pmid_xml %>%
  xml_find_all("//AuthorList/Author[1]/LastName") %>%
  xml_text()

firstname <- pmid_xml %>%
  xml_find_all("//AuthorList/Author[1]/ForeName") %>%
  xml_text()

collective <- pmid_xml %>%
  xml_find_all("//AuthorList/Author[1]/CollectiveName") %>%
  xml_text()

if ((length(firstname) == 0 ||
  length(firstname) == 0) &&
  length(collective) != 0) {
    lastname <- collective
    firstname <- collective
}

if (length(year) == 0 ||
  length(month) == 0 ||
  length(day) == 0)  {
    year <- format(Sys.time(), "%Y")
    month <- format(Sys.time(), "%m")
    day <- format(Sys.time(), "%d")
}

address <- pmid_xml %>%
  xml_find_all("//AuthorList/Author[1]/AffiliationInfo") %>%
  xml_text()

# return list of results
return_tibble <- as_tibble(
    list(pmid = pmid[1],
        doi = doi,
        title = str_c(title, collapse = " "),
        abstract = str_c(abstract, collapse = " "),
        jabbrv = jabbrv,
        journal = journal[1],
        keywords = str_c(unique(str_squish(c(mesh, keyword))), collapse = "; "),
        year = year,
        month = str_pad(month, 2, "left", pad = "0"),
        day = str_pad(day, 2, "left", pad = "0"),
        lastname = lastname,
        firstname = firstname,
        address = str_c(address, collapse = "; ")
    )
  )

return(return_tibble)
}


#' Splits requests for PMID information in chunks for the API
#'
#' @param pmid_value A list of PMIDs
#' @param request_max a number used to partition the requests in chunks
#'
#' @return tibble with article information columns
#' @export
info_from_pmid <- function(pmid_value, request_max = 200) {
  pmid_value <- str_replace_all(pmid_value, "PMID:", "")

  input_tibble <- as_tibble(pmid_value) %>%
    mutate(publication_id = as.character(value)) %>%
    mutate(publication_id = str_remove(publication_id, "PMID:")) %>%
    select(-value)

  row_number <- nrow(input_tibble)
  groups_number <- ceiling(row_number / request_max)

  input_tibble_request <- input_tibble %>%
    mutate(group = sample(1:groups_number, row_number, replace = TRUE)) %>%
    group_by(group) %>%
    mutate(publication_id = paste0(publication_id, "[PMID]")) %>%
    mutate(publication_id = str_flatten(publication_id, collapse = " or ")) %>%
    unique() %>%
    ungroup() %>%
    rowwise() %>%
    mutate(response = fetch_pubmed_data(get_pubmed_ids(publication_id),
      encoding = "ASCII")) %>%
    ungroup() %>%
    mutate(new_PM_df = map(response, ~table_articles_from_xml(.x))) %>%
    unnest(cols = new_PM_df) %>%
    mutate(other_publication_id = paste0("DOI:", doi)) %>%
    mutate(Publication_date = paste0(year, "-", month, "-", day)) %>%
    select(-publication_id, -group, -response) %>%
    select(publication_id = pmid,
      other_publication_id,
      Title = title,
      Abstract = abstract,
      Publication_date,
      Journal_abbreviation = jabbrv,
      Journal = journal,
      Keywords = keywords,
      Lastname = lastname,
      Firstname = firstname)

  output_tibble <- input_tibble %>%
    left_join(input_tibble_request, by = "publication_id") %>%
    select(-publication_id) %>%
    mutate(across(everything(), ~replace_na(.x, "")))

  return(output_tibble)
}