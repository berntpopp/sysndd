# functions/omim-download-functions.R
#
# OMIM/HPO acquisition: credentials + downloads for genemap2.txt, mim2gene.txt,
# phenotype.hpoa, and phenotype_to_genes.txt. Extracted from omim-functions.R
# (WP #346, Wave 4 Task 10) to keep both files under the 600-line soft
# ceiling; behavior, TTL caching, retry/timeout, and OMIM_DOWNLOAD_KEY
# secrecy are unchanged.
#
# Provides:
# - get_omim_download_key(): reads OMIM_DOWNLOAD_KEY from the environment
#   (never logged) for authenticated genemap2.txt downloads
# - download_mim2gene() / download_genemap2(): OMIM file acquisition with
#   1-day TTL caching (check_file_age_days() / get_newest_file())
# - download_hpoa() / download_phenotype_to_genes(): HPO file acquisition
#   with the same TTL caching pattern
#
# Sourced by omim-functions.R (guard-sourced there, before the parser module
# and before the rest of that file) so load_modules.R and setup_workers.R
# only need to reference omim-functions.R.

require(httr2)
require(fs)

#' Download mim2gene.txt from OMIM
#'
#' Downloads the mim2gene.txt file from OMIM's public data. Uses httr2 with
#' retry logic for reliability. Checks file age before downloading with 1-day
#' TTL (time-to-live) caching.
#'
#' @param output_path Character string, directory to save the file (default: "data/")
#' @param force Logical, if TRUE downloads even if recent file exists (default: FALSE)
#' @param max_age_days Integer, maximum age in days before re-downloading (default: 1)
#' @return Character string, path to the downloaded/existing file
#'
#' @details
#' Downloaded files are named mim2gene.YYYY-MM-DD.txt.
#'
#' Caching behavior:
#' - Uses check_file_age_days() for 1-day TTL checking
#' - Returns cached file if it exists and is less than max_age_days old
#' - Downloads fresh file if cache is expired or force=TRUE
#'
#' Retry logic (same as download_genemap2):
#' - max_tries: 3
#' - max_seconds: 60
#' - backoff: exponential (2^x seconds)
#' - timeout: 30 seconds per request
#'
#' @examples
#' \dontrun{
#'   # Use cached file if < 1 day old
#'   file_path <- download_mim2gene()
#'
#'   # Force fresh download
#'   file_path <- download_mim2gene(force = TRUE)
#' }
#'
#' @export
download_mim2gene <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists
  if (!force && check_file_age_days("mim2gene", output_path, max_age_days)) {
    existing_file <- get_newest_file("mim2gene", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[OMIM] Using cached mim2gene.txt: %s", existing_file))
      return(existing_file)
    }
  }

  # Download from OMIM
  url <- "https://omim.org/static/omim/data/mim2gene.txt"
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "mim2gene.", current_date, ".txt")

  # Ensure output directory exists
  if (!dir_exists(output_path)) {
    dir_create(output_path)
  }

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_perform()

  if (resp_status(response) != 200) {
    stop(sprintf("Failed to download mim2gene.txt: HTTP %d", resp_status(response)))
  }

  # Write to file
  writeBin(resp_body_raw(response), output_file)

  message(sprintf("[OMIM] Downloaded mim2gene.txt to %s", output_file))

  return(output_file)
}


#' Get OMIM download API key from environment variable
#'
#' Retrieves the OMIM download API key from the OMIM_DOWNLOAD_KEY environment
#' variable. Stops with an informative error message if the variable is not set.
#'
#' @return Character string, the OMIM download API key
#'
#' @details
#' The OMIM download key is required for authenticated downloads of genemap2.txt.
#' Set the environment variable in one of these ways:
#' - Add to .env file: OMIM_DOWNLOAD_KEY=your_key_here
#' - Docker Compose: environment: - OMIM_DOWNLOAD_KEY=${OMIM_DOWNLOAD_KEY}
#' - R session: Sys.setenv(OMIM_DOWNLOAD_KEY = "your_key_here")
#'
#' The key itself is never logged or included in error/message output; only
#' its presence/absence is reported.
#'
#' @examples
#' \dontrun{
#'   api_key <- get_omim_download_key()
#' }
#'
#' @export
get_omim_download_key <- function() {
  api_key <- Sys.getenv("OMIM_DOWNLOAD_KEY", "")
  if (api_key == "") {
    stop(
      "OMIM_DOWNLOAD_KEY environment variable not set.\n",
      "Add to .env file: OMIM_DOWNLOAD_KEY=your_key_here\n",
      "Or set in Docker Compose: environment: - OMIM_DOWNLOAD_KEY=${OMIM_DOWNLOAD_KEY}"
    )
  }
  return(api_key)
}


#' Download genemap2.txt from OMIM
#'
#' Downloads the genemap2.txt file from OMIM using an authenticated download URL.
#' Uses httr2 with retry logic for reliability. Checks file age before downloading
#' with 1-day TTL (time-to-live) caching.
#'
#' @param output_path Character string, directory to save the file (default: "data/")
#' @param force Logical, if TRUE downloads even if recent file exists (default: FALSE)
#' @param max_age_days Integer, maximum age in days before re-downloading (default: 1)
#' @return Character string, path to the downloaded/existing file
#'
#' @details
#' Uses OMIM_DOWNLOAD_KEY environment variable for authentication (see get_omim_download_key()).
#' Downloaded files are named genemap2.YYYY-MM-DD.txt.
#'
#' Caching behavior:
#' - Uses check_file_age_days() for 1-day TTL checking
#' - Returns cached file if it exists and is less than max_age_days old
#' - Downloads fresh file if cache is expired or force=TRUE
#'
#' Retry logic (same as download_mim2gene):
#' - max_tries: 3
#' - max_seconds: 60
#' - backoff: exponential (2^x seconds)
#' - timeout: 30 seconds per request
#'
#' The API key is only used to build the authenticated download URL and is
#' never written to a log/message; only generic HTTP status is reported on
#' failure.
#'
#' @examples
#' \dontrun{
#'   # Use cached file if < 1 day old
#'   file_path <- download_genemap2()
#'
#'   # Force fresh download
#'   file_path <- download_genemap2(force = TRUE)
#' }
#'
#' @export
download_genemap2 <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists
  if (!force && check_file_age_days("genemap2", output_path, max_age_days)) {
    existing_file <- get_newest_file("genemap2", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[OMIM] Using cached genemap2.txt: %s", existing_file))
      return(existing_file)
    }
  }

  # Get API key
  api_key <- get_omim_download_key()

  # Download from OMIM with authenticated URL
  url <- sprintf("https://data.omim.org/downloads/%s/genemap2.txt", api_key)
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "genemap2.", current_date, ".txt")

  # Ensure output directory exists
  if (!dir_exists(output_path)) {
    dir_create(output_path)
  }

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_perform()

  if (resp_status(response) != 200) {
    stop(sprintf("Failed to download genemap2.txt: HTTP %d", resp_status(response)))
  }

  # Write to file
  writeBin(resp_body_raw(response), output_file)

  message(sprintf("[OMIM] Downloaded genemap2.txt to %s", output_file))

  return(output_file)
}


#' Download phenotype.hpoa from HPO
#'
#' Downloads the phenotype.hpoa file from the Human Phenotype Ontology using an
#' authenticated or public URL. Uses httr2 with retry logic for reliability.
#' Checks file age before downloading with 1-day TTL (time-to-live) caching.
#'
#' @param url Character string, the phenotype.hpoa download URL (from comparisons_config)
#' @param output_path Character string, directory to save the file (default: "data/")
#' @param force Logical, if TRUE downloads even if recent file exists (default: FALSE)
#' @param max_age_days Integer, maximum age in days before re-downloading (default: 1)
#' @return Character string, path to the downloaded/existing file
#'
#' @details
#' The phenotype.hpoa file contains disease-phenotype associations from HPO.
#' Downloaded files are named phenotype_hpoa.YYYY-MM-DD.txt.
#'
#' Caching behavior:
#' - Uses check_file_age_days() for 1-day TTL checking
#' - Returns cached file if it exists and is less than max_age_days old
#' - Downloads fresh file if cache is expired or force=TRUE
#'
#' Retry logic (same as download_genemap2):
#' - max_tries: 3
#' - max_seconds: 60
#' - backoff: exponential (2^x seconds)
#' - timeout: 30 seconds per request
#'
#' @examples
#' \dontrun{
#'   # Use cached file if < 1 day old
#'   url <- "http://purl.obolibrary.org/obo/hp/hpoa/phenotype.hpoa"
#'   file_path <- download_hpoa(url)
#'
#'   # Force fresh download
#'   file_path <- download_hpoa(url, force = TRUE)
#' }
#'
#' @export
download_hpoa <- function(url, output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists
  if (!force && check_file_age_days("phenotype_hpoa", output_path, max_age_days)) {
    existing_file <- get_newest_file("phenotype_hpoa", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[HPO] Using cached phenotype.hpoa: %s", existing_file))
      return(existing_file)
    }
  }

  # Download from HPO
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "phenotype_hpoa.", current_date, ".txt")

  # Ensure output directory exists
  if (!dir_exists(output_path)) {
    dir_create(output_path)
  }

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_perform()

  if (resp_status(response) != 200) {
    stop(sprintf("Failed to download phenotype.hpoa: HTTP %d", resp_status(response)))
  }

  # Write to file
  writeBin(resp_body_raw(response), output_file)

  message(sprintf("[HPO] Downloaded phenotype.hpoa to %s", output_file))

  return(output_file)
}


#' Download phenotype_to_genes.txt from HPO
#'
#' Downloads the phenotype_to_genes.txt file from the Human Phenotype Ontology.
#' This file contains pre-propagated HPO annotations (HPO hierarchy built in),
#' making it ideal for filtering by a single HPO term like HP:0012759
#' (Neurodevelopmental abnormality) without needing hierarchy traversal.
#'
#' @param url Character string, the phenotype_to_genes.txt download URL
#' @param output_path Character string, directory to save the file (default: "data/")
#' @param force Logical, if TRUE downloads even if recent file exists (default: FALSE)
#' @param max_age_days Integer, maximum age in days before re-downloading (default: 1)
#' @return Character string, path to the downloaded/existing file
#'
#' @details
#' Downloaded files are named phenotype_to_genes.YYYY-MM-DD.txt.
#'
#' Caching behavior:
#' - Uses check_file_age_days() for 1-day TTL checking
#' - Returns cached file if it exists and is less than max_age_days old
#' - Downloads fresh file if cache is expired or force=TRUE
#'
#' Retry logic (same as download_hpoa):
#' - max_tries: 3
#' - max_seconds: 60
#' - backoff: exponential (2^x seconds)
#' - timeout: 30 seconds per request
#'
#' @examples
#' \dontrun{
#'   # Use cached file if < 1 day old
#'   file_path <- download_phenotype_to_genes()
#'
#'   # Force fresh download
#'   file_path <- download_phenotype_to_genes(force = TRUE)
#' }
#'
#' @export
download_phenotype_to_genes <- function(
    url = "http://purl.obolibrary.org/obo/hp/hpoa/phenotype_to_genes.txt",
    output_path = "data/",
    force = FALSE,
    max_age_days = 1) {
  # Check if recent file exists
  if (!force && check_file_age_days("phenotype_to_genes", output_path, max_age_days)) {
    existing_file <- get_newest_file("phenotype_to_genes", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[HPO] Using cached phenotype_to_genes.txt: %s", existing_file))
      return(existing_file)
    }
  }

  # Download from HPO
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "phenotype_to_genes.", current_date, ".txt")

  # Ensure output directory exists
  if (!dir_exists(output_path)) {
    dir_create(output_path)
  }

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_perform()

  if (resp_status(response) != 200) {
    stop(sprintf(
      "Failed to download phenotype_to_genes.txt: HTTP %d",
      resp_status(response)
    ))
  }

  # Write to file
  writeBin(resp_body_raw(response), output_file)

  message(sprintf("[HPO] Downloaded phenotype_to_genes.txt to %s", output_file))

  return(output_file)
}
