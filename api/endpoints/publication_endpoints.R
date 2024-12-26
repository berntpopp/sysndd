# api/endpoints/publication_endpoints.R
#
# This file contains all Publication-related endpoints extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible.

##-------------------------------------------------------------------##
## Publication endpoints
##-------------------------------------------------------------------##

#* Fetch Publication by PMID
#*
#* Fetches a publication from the DB by PMID.
#*
#* # `Details`
#* Looks up the publication table for the matching PMID. 
#* Returns metadata: title, abstract, authors, etc.
#*
#* # `Return`
#* JSON object with the publication metadata.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param pmid The PubMed ID of the publication.
#*
#* @response 200 OK. Returns publication metadata.
#*
#* @get <pmid>
function(pmid) {
  pmid <- URLdecode(pmid) %>%
    str_replace_all("[^0-9]+", "")
  pmid <- paste0("PMID:", pmid)

  publication_collected <- pool %>%
    tbl("publication") %>%
    filter(publication_id == pmid) %>%
    select(
      publication_id,
      other_publication_id,
      Title,
      Abstract,
      Lastname,
      Firstname,
      Publication_date,
      Journal,
      Keywords
    ) %>%
    arrange(publication_id) %>%
    collect()

  publication_collected
}


#* Validate PMID Existence in PubMed
#*
#* Checks if a given PMID exists in PubMed.
#*
#* # `Details`
#* Uses the helper function check_pmid(pmid).
#*
#* # `Return`
#* JSON object indicating if PMID is valid or not.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param pmid The PMID to validate.
#*
#* @response 200 OK. Returns validation result.
#*
#* @get <pmid>
function(req, res, pmid) {
  pmid <- URLdecode(pmid) %>%
    str_replace_all("[^0-9]+", "")
  check_pmid(pmid)
}


#* Search Publications on PubTator
#*
#* Queries the PubTator API for publications matching a set query. Allows pagination.
#*
#* # `Details`
#* Returns a list of publication metadata (PMIDs, titles, etc.). 
#* Also returns meta (e.g., total pages).
#*
#* # `Return`
#* JSON containing 'meta' and 'data'.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param current_page Numeric: The starting page number for the API response.
#*
#* @response 200 OK. Returns the list of publications' metadata.
#*
#* @get pubtator/search
function(req, res, current_page = 1) {
  query <- '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disorder" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)'

  max_pages <- 1
  current_page <- as.numeric(current_page)

  pmids_data <- pubtator_v3_pmids_from_request(query, current_page, max_pages)
  per_page <- 10
  total_pages <- pubtator_v3_total_pages_from_query(query)

  response_data <- list(
    meta = list(
      "perPage" = per_page,
      "currentPage" = current_page,
      "totalPages" = total_pages
    ),
    data = pmids_data
  )

  res$status <- 200
  response_data
}
