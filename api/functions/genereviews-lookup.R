# functions/genereviews-lookup.R
#
# Reliable, batchable, cached GeneReviews availability lookup.
#
# Unlike the legacy HTML scrapers in genereviews-functions.R (which parse the
# NCBI Bookshelf web pages and silently return NA on error), this module uses
# the NCBI E-utilities `books` database directly (ESearch + ESummary), restricted
# to the GeneReviews chapter set. It returns a structured result and follows the
# external-proxy error contract: transient upstream failures yield
# `list(error = TRUE, ...)` so they are never poisoned into the success-only
# cache (see memoise_external_success_only() in external-proxy-functions.R).
#
# E-utilities usage notes:
# - ESearch on db=books with term "<GENE>[Gene Symbol] AND GeneReviews[book]"
#   returns Bookshelf UIDs of GeneReviews chapters for that gene.
# - ESummary on db=books resolves those UIDs to the public NBK accession
#   (the "NBK..." id used in https://www.ncbi.nlm.nih.gov/books/<NBK>/) and the
#   chapter title.
# - No API key/email is required for low-volume anonymous use; if one is later
#   configured it is read from env (NCBI_API_KEY / NCBI_EUTILS_EMAIL) without
#   hardcoding any secret.

# Load shared external-proxy infrastructure (cache backends, memoise wrapper,
# the error-shape contract, gene-symbol validation) if not already sourced.
if (!exists("memoise_external_success_only", mode = "function")) {
  if (file.exists("functions/external-proxy-functions.R")) {
    source("functions/external-proxy-functions.R", local = TRUE)
  }
}

GENEREVIEWS_EUTILS_BASE <- "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

#' Append configured NCBI E-utilities credentials to a query list
#'
#' Reads NCBI_API_KEY / NCBI_EUTILS_EMAIL from the environment when present.
#' Never hardcodes a key. Anonymous requests are valid for low-volume use.
#'
#' @param query Named list of query parameters.
#' @return The query list with `tool`, `email`, and `api_key` added when set.
#' @noRd
genereviews_eutils_query <- function(query) {
  query$tool <- query$tool %||% "sysndd"

  email <- Sys.getenv("NCBI_EUTILS_EMAIL", "")
  if (nzchar(email)) {
    query$email <- email
  }

  api_key <- Sys.getenv("NCBI_API_KEY", "")
  if (nzchar(api_key)) {
    query$api_key <- api_key
  }

  query
}

#' Build the public GeneReviews Bookshelf URL for an NBK accession
#'
#' @param nbk_id NCBI Bookshelf accession (e.g. "NBK1116").
#' @return Full https URL, or NA_character_ when the id is missing.
#' @noRd
genereviews_bookshelf_url <- function(nbk_id) {
  if (is.null(nbk_id) || length(nbk_id) == 0 || is.na(nbk_id) || !nzchar(nbk_id)) {
    return(NA_character_)
  }
  paste0("https://www.ncbi.nlm.nih.gov/books/", nbk_id, "/")
}

#' Perform a single E-utilities GET and return the parsed XML document
#'
#' Applies the same retry/timeout policy used by pubmed_esearch_count(): retry
#' transient 429/5xx, 30s timeout. Errors propagate to the caller's tryCatch.
#'
#' @param endpoint One of "esearch.fcgi" or "esummary.fcgi".
#' @param query Named list of query parameters.
#' @return Parsed xml2 document.
#' @noRd
genereviews_eutils_xml <- function(endpoint, query) {
  response <- httr2::request(paste0(GENEREVIEWS_EUTILS_BASE, "/", endpoint)) %>%
    httr2::req_url_query(!!!genereviews_eutils_query(query)) %>%
    httr2::req_retry(
      max_tries = 3,
      backoff = ~ 2^.x,
      is_transient = ~ httr2::resp_status(.x) %in% c(429, 500, 502, 503, 504)
    ) %>%
    httr2::req_timeout(30) %>%
    httr2::req_perform()

  xml2::read_xml(httr2::resp_body_string(response))
}

#' Look up GeneReviews availability for a single gene symbol (uncached)
#'
#' @param gene_symbol HGNC gene symbol (validated; e.g. "GRIN2B").
#' @return Named list. On success:
#'   `list(source="genereviews", gene_symbol=..., has_genereview=TRUE/FALSE,
#'         nbk_id=<chr|NA>, url=<chr|NA>, title=<chr|NA>, chapter_count=<int>)`.
#'   On invalid input: `has_genereview = FALSE` with `not_found = TRUE`.
#'   On transient upstream failure: `list(error = TRUE, source="genereviews", ...)`
#'   so the success-only cache wrapper refuses to retain it.
#' @export
fetch_genereviews_availability <- function(gene_symbol) {
  not_found_result <- function() {
    list(
      source = "genereviews",
      gene_symbol = gene_symbol,
      has_genereview = FALSE,
      nbk_id = NA_character_,
      url = NA_character_,
      title = NA_character_,
      chapter_count = 0L
    )
  }

  if (!validate_gene_symbol(gene_symbol)) {
    result <- not_found_result()
    result$not_found <- TRUE
    return(result)
  }

  tryCatch(
    {
      # ESearch: find GeneReviews chapter UIDs for this gene symbol.
      term <- paste0(gene_symbol, "[Gene Symbol] AND GeneReviews[book]")
      search_doc <- genereviews_eutils_xml(
        "esearch.fcgi",
        list(db = "books", term = term, retmode = "xml", retmax = "20")
      )

      uids <- search_doc %>%
        xml2::xml_find_all("//IdList/Id") %>%
        xml2::xml_text()
      uids <- uids[!is.na(uids) & nzchar(uids)]

      if (length(uids) == 0L) {
        return(not_found_result())
      }

      # ESummary: resolve the first UID to its NBK accession + title.
      summary_doc <- genereviews_eutils_xml(
        "esummary.fcgi",
        list(db = "books", id = paste(uids, collapse = ","), retmode = "xml")
      )

      first_summary <- summary_doc %>%
        xml2::xml_find_first("//DocSum")

      nbk_id <- first_summary %>%
        xml2::xml_find_first(".//Item[@Name='AccessionID']") %>%
        xml2::xml_text()

      title <- first_summary %>%
        xml2::xml_find_first(".//Item[@Name='Title']") %>%
        xml2::xml_text()

      nbk_id <- if (is.na(nbk_id) || !nzchar(nbk_id)) NA_character_ else nbk_id
      title <- if (is.na(title) || !nzchar(title)) NA_character_ else title

      list(
        source = "genereviews",
        gene_symbol = gene_symbol,
        has_genereview = TRUE,
        nbk_id = nbk_id,
        url = genereviews_bookshelf_url(nbk_id),
        title = title,
        chapter_count = length(uids)
      )
    },
    error = function(e) {
      list(
        error = TRUE,
        status = 503L,
        source = "genereviews",
        gene_symbol = gene_symbol,
        message = conditionMessage(e)
      )
    }
  )
}

#### Memoised wrapper with static (30-day) cache

#' Memoised GeneReviews availability lookup
#'
#' GeneReviews chapter membership for a gene changes very rarely, so the static
#' 30-day cache is appropriate. `memoise_external_success_only` retains
#' successes and true not-founds but immediately forgets any `error = TRUE`
#' transient failure, preventing cache poisoning on an NCBI hiccup.
#'
#' @inheritParams fetch_genereviews_availability
#' @return Same shape as fetch_genereviews_availability.
#' @export
fetch_genereviews_availability_mem <- memoise_external_success_only(
  fetch_genereviews_availability,
  cache = cache_static
)

#' Batch GeneReviews availability lookup over a set of gene symbols
#'
#' Uses the memoised single-gene lookup so repeated symbols and warm-cache
#' entries are cheap. Designed for use by a worker/admin coverage refresh rather
#' than a synchronous public request: the caller is responsible for any
#' queue/throttle gating (see AGENTS.md on public expensive/external ops).
#'
#' @param gene_symbols Character vector of HGNC gene symbols.
#' @return A tibble with one row per unique gene symbol and columns:
#'   `gene_symbol`, `has_genereview` (logical), `nbk_id`, `url`, `title`,
#'   `chapter_count`, `lookup_error` (logical, TRUE when the upstream call
#'   failed for that gene).
#' @export
fetch_genereviews_availability_batch <- function(gene_symbols) {
  symbols <- unique(as.character(gene_symbols))
  symbols <- symbols[!is.na(symbols) & nzchar(symbols)]

  empty <- tibble::tibble(
    gene_symbol = character(),
    has_genereview = logical(),
    nbk_id = character(),
    url = character(),
    title = character(),
    chapter_count = integer(),
    lookup_error = logical()
  )

  if (length(symbols) == 0L) {
    return(empty)
  }

  rows <- lapply(symbols, function(symbol) {
    result <- fetch_genereviews_availability_mem(symbol)

    if (is.list(result) && isTRUE(result$error)) {
      return(tibble::tibble(
        gene_symbol = symbol,
        has_genereview = NA,
        nbk_id = NA_character_,
        url = NA_character_,
        title = NA_character_,
        chapter_count = NA_integer_,
        lookup_error = TRUE
      ))
    }

    tibble::tibble(
      gene_symbol = symbol,
      has_genereview = isTRUE(result$has_genereview),
      nbk_id = result$nbk_id %||% NA_character_,
      url = result$url %||% NA_character_,
      title = result$title %||% NA_character_,
      chapter_count = as.integer(result$chapter_count %||% 0L),
      lookup_error = FALSE
    )
  })

  dplyr::bind_rows(rows)
}
