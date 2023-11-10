#### This file holds genereviews functions

#' Retrieve PMID from GeneReviews Using Gene Name
#'
#' @description
#' This function fetches the PubMed ID (PMID) of a GeneReviews article by scraping
#' the GeneReviews page of the specified gene. The CSS selectors used for scraping
#' can be customized.
#'
#' @param genereviews_name The name of the gene as represented in GeneReviews.
#' @param base_url The base URL of the GeneReviews section on the NCBI website.
#'   Defaults to "https://www.ncbi.nlm.nih.gov/books/n/gene/".
#' @param selector A character vector of CSS selectors to be used in sequence for
#'   scraping the required data. Defaults to c("div.small", "span.label", "a").
#'
#' @return A string containing the PMID of the GeneReviews article. Returns NA
#'   if the PMID cannot be found or if an error occurs during the process.
#'
#' @examples
#' \dontrun{
#' pmid_from_genereviews_name("GRIN2B")
#' }
#'
#' @importFrom xml2 read_html
#' @importFrom rvest html_nodes html_attr
#' @importFrom stringr str_replace
#' @export
pmid_from_genereviews_name <- function(genereviews_name, 
                                       base_url = "https://www.ncbi.nlm.nih.gov/books/n/gene/",
                                       selector = c("div.small", "span.label", "a")) {

  genereviews_url <- paste0(base_url, genereviews_name)

  tryCatch({
    genereviews_request <- xml2::read_html(genereviews_url, options = "RECOVER")

    # Apply the CSS selectors in sequence
    for (sel in selector) {
      genereviews_request <- html_nodes(genereviews_request, sel)
    }

    pmid <- genereviews_request %>%
      html_attr("href") %>%
      str_replace("/pubmed/", "") %>%
      str_replace("/", "")

    if (length(pmid) == 0) {
      return(NA) # Return NA if PMID not found
    }
    
    return(pmid)
  }, error = function(e) {
    message("Error in reading URL: ", e$message)
    return(NA)
  })
}

