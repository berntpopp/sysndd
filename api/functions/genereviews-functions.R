# functions/genereviews-functions.R
#### This file holds genereviews functions

#' This function takes a PMID id and generates Bookshelf_IDs
#' which are used to get the GeneReview information
#'
#' @param pmid_input A list of PMIDs
#'
#' @return tibble Genereviews article information
#' @export
info_from_genereviews_pmid <- function(pmid_input) {
  pmid_input <- str_replace_all(pmid_input, "PMID:", "")

  Bookshelf_IDs <- genereviews_from_pmid(pmid_input)
  output_tibble <- info_from_genereviews(Bookshelf_IDs)

  return(output_tibble)
}


#' This function takes a PMID id and generates Bookshelf_IDs
#' or returns a boolean value representing if the article exists
#'
#' @param pmid_input A PMID id
#' @param check A boolean indicator value
#'
#' @return tibble Genereviews article information or boolean value
#' @export
genereviews_from_pmid <- function(pmid_input, check = FALSE) {
  pmid_input <- str_replace_all(pmid_input, "PMID:", "")

## TODO: find a faster implementation of the check

  url <- paste0("https://www.ncbi.nlm.nih.gov/books/NBK1116/?term=",
    pmid_input,
    "[PMID]")
  url_request <- url(url, "rb")

  webpage_request <- xml2::read_html(url_request, options = c("RECOVER"))
  close(url_request)

  Bookshelf_ID <- webpage_request %>%
    html_nodes("div.rslt") %>%
    html_nodes("p.title") %>%
    html_nodes("a") %>%
    html_attr("href") %>%
    str_replace("/books/", "") %>%
    str_replace("/", "")

  Bookshelf_ID_tibble <- as_tibble(Bookshelf_ID)
  Bookshelf_IDs <- str_c(Bookshelf_ID_tibble$value, collapse = ",")

  if (!check) {
    return(Bookshelf_IDs)
  } else {
    return(as.logical(nchar(Bookshelf_IDs)))
  }

}


#' This function takes a Bookshelf_ID and returns
#' a tibble with GeneReview information
#'
#' @param Bookshelf_ID A NCBI Bookshelf id
#'
#' @return tibble with Genereviews article information
#' @export
info_from_genereviews <- function(Bookshelf_ID) {
  url <- paste0("https://www.ncbi.nlm.nih.gov/books/", Bookshelf_ID)
  genereviews_url <- url(url, "rb")

  genereviews_request <- xml2::read_html(genereviews_url, options = "RECOVER")
  close(genereviews_url)

  pmid <- genereviews_request %>%
    html_nodes("div.small") %>%
    html_nodes("span.label") %>%
    html_nodes("a") %>%
    html_attr("href") %>%
    str_replace("/pubmed/", "") %>%
    str_replace("/", "")

  title <- genereviews_request %>%
    html_nodes("title") %>%
    html_text() %>%
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
    html_attr("content") %>%
    str_c(collapse = "; ")

## TODO: some error here with title now having multiple matches,
## seems to work in the import script check solution there

  return_tibble <- as_tibble_row(c("publication_id" = pmid,
      "Bookshelf_ID" = Bookshelf_ID,
      "Title" = title[1], "Abstract" = abstract,
      "Date" = date_revision,
      "First_author" = first_author,
      "Keywords" = keywords)) %>%
    separate(Date, c("Day", "Month", "Year"), sep = " ") %>%
    mutate(Month = match(Month, month.name)) %>%
    separate(First_author, c("Firstname", "Lastname"),
      sep = " (?=[^ ]*$)",
      extra = "merge") %>%
    mutate(Journal_abbreviation = "GeneReviews") %>%
    mutate(Journal = "GeneReviews") %>%
    mutate(other_publication_id = paste0("Bookshelf_ID:", Bookshelf_ID)) %>%
    mutate(Publication_date = paste0(Year, "-", str_pad(Month, 2, pad = "0"),
      "-",
      str_pad(Day, 2, pad = "0"))) %>%
    select(publication_id,
      other_publication_id,
      Title, Abstract,
      Publication_date,
      Journal_abbreviation,
      Journal,
      Keywords,
      Lastname,
      Firstname) %>%
    select(-publication_id) %>%
    mutate(across(everything(), ~replace_na(.x, "")))

  return(return_tibble)
}


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


#' Retrieve PMID from GeneReviews Using Bookshelf ID
#'
#' @description
#' This function fetches the PubMed ID (PMID) of a GeneReviews article by scraping
#' the GeneReviews page of the specified Bookshelf ID. The CSS selectors used for scraping
#' can be customized.
#'
#' @param bookshelf_id The Bookshelf ID of the article as represented in GeneReviews.
#' @param base_url The base URL of the GeneReviews section on the NCBI website.
#'   Defaults to "https://www.ncbi.nlm.nih.gov/books/".
#' @param selector A character vector of CSS selectors to be used in sequence for
#'   scraping the required data. Defaults to c("div.small", "span.label", "a").
#'
#' @return A string containing the PMID of the GeneReviews article. Returns NA
#'   if the PMID cannot be found or if an error occurs during the process.
#'
#' @examples
#' \dontrun{
#' pmid_from_bookshelf_id("NBK501979")
#' }
#'
#' @importFrom xml2 read_html
#' @importFrom rvest html_nodes html_attr
#' @importFrom stringr str_replace
#' @export
pmid_from_bookshelf_id <- function(bookshelf_id,
                                   base_url = "https://www.ncbi.nlm.nih.gov/books/",
                                   selector = c("div.small", "span.label", "a")) {

  bookshelf_url <- paste0(base_url, bookshelf_id)

  tryCatch({
    bookshelf_request <- xml2::read_html(bookshelf_url, options = "RECOVER")

    # Apply the CSS selectors in sequence
    for (sel in selector) {
      bookshelf_request <- html_nodes(bookshelf_request, sel)
    }

    pmid <- bookshelf_request %>%
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
