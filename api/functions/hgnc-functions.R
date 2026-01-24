# funcctions/hgnc-functions.R
#### This file holds analyses functions for the hgnc standardization

#' Retrieve HGNC ID from previous symbol
#'
#' This function retrieves the HGNC ID corresponding to a given previous symbol.
#'
#' @param symbol_input The previous symbol for which to retrieve the HGNC ID.
#'
#' @return An integer representing the HGNC ID corresponding to the input previous symbol.
#'
#' @examples
#' hgnc_id_from_prevsymbol("lysine (K)-specific methyltransferase 2B")
#'
#' @export
hgnc_id_from_prevsymbol <- function(symbol_input) {
  symbol_request <- fromJSON(paste0("http://rest.genenames.org/search/prev_symbol/", symbol_input))

  hgnc_id_from_symbol <- as_tibble(symbol_request$response$docs)

  hgnc_id_from_symbol <- hgnc_id_from_symbol %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_symbol)) hgnc_id else NA) %>%
  mutate(symbol = if (exists('symbol', where = hgnc_id_from_symbol)) symbol else "") %>%
  mutate(score = if (exists('score', where = hgnc_id_from_symbol)) score else 0) %>%
  arrange(desc(score)) %>%
  mutate(hgnc_id = as.integer(str_split_fixed(hgnc_id, ":", 2)[, 2]))

  return(as.integer(hgnc_id_from_symbol$hgnc_id[1]))
}


#' Retrieve HGNC ID from alias symbol
#'
#' This function retrieves the HGNC ID corresponding to a given alias symbol.
#'
#' @param symbol_input The alias symbol for which to retrieve the HGNC ID.
#'
#' @return An integer representing the HGNC ID corresponding to the input alias symbol.
#'
#' @examples
#' hgnc_id_from_aliassymbol("MLL2")
#'
#' @export
hgnc_id_from_aliassymbol <- function(symbol_input) {
  symbol_request <- fromJSON(paste0("http://rest.genenames.org/search/alias_symbol/", symbol_input))

  hgnc_id_from_symbol <- as_tibble(symbol_request$response$docs)

  hgnc_id_from_symbol <- hgnc_id_from_symbol %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_symbol)) hgnc_id else NA) %>%
  mutate(symbol = if (exists('symbol', where = hgnc_id_from_symbol)) symbol else "") %>%
  mutate(score = if (exists('score', where = hgnc_id_from_symbol)) score else 0) %>%
  arrange(desc(score)) %>%
  mutate(hgnc_id = as.integer(str_split_fixed(hgnc_id, ":", 2)[, 2]))

  return(as.integer(hgnc_id_from_symbol$hgnc_id[1]))
}


#' Retrieve HGNC ID from symbol
#'
#' This function retrieves the HGNC ID corresponding to a given symbol or symbols.
#'
#' @param symbol_tibble A tibble containing the symbol(s) for which to retrieve the HGNC ID.
#'
#' @return A tibble with the HGNC ID(s) corresponding to the input symbol(s).
#'
#' @examples
#' symbol_tibble <- tibble(value = c("symbol1", "symbol2", "symbol3"))
#' hgnc_id_from_symbol(symbol_tibble)
#'
#' @export
hgnc_id_from_symbol <- function(symbol_tibble) {
  symbol_list_tibble <- as_tibble(symbol_tibble) %>% dplyr::select(symbol = value) %>% mutate(symbol = toupper(symbol))

  symbol_request <- fromJSON(paste0("http://rest.genenames.org/search/symbol/", str_c(symbol_list_tibble$symbol, collapse = "+OR+")))

  hgnc_id_from_symbol <- as_tibble(symbol_request$response$docs)

  hgnc_id_from_symbol <- hgnc_id_from_symbol %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_symbol)) hgnc_id else NA) %>%
  mutate(symbol = if (exists('symbol', where = hgnc_id_from_symbol)) toupper(symbol) else "") %>%
  mutate(hgnc_id = as.integer(str_split_fixed(hgnc_id, ":", 2)[, 2]))

  return_tibble <- symbol_list_tibble %>%
  left_join(hgnc_id_from_symbol, by = "symbol") %>%
  dplyr::select(hgnc_id)

  return(return_tibble)
}


#' Parallelized function to retrieve HGNC ID from symbol
#'
#' This function retrieves the HGNC ID corresponding to symbols in parallel using
#' grouped requests. It supports parallel processing by dividing the input into
#' smaller groups and processing them concurrently.
#'
#' @param input_tibble A tibble containing the symbols for which to retrieve the HGNC ID.
#' @param request_max Maximum number of symbols to include in each grouped request (default: 150).
#'
#' @return A vector of HGNC ID(s) corresponding to the input symbols.
#'
#' @examples
#' input_tibble <- tibble(value = c("ARID1B", "GRIN2B", "NAA10"))
#' hgnc_id_from_symbol_grouped(input_tibble)
#'
#' @export
hgnc_id_from_symbol_grouped <- function(input_tibble, request_max = 150) {
  input_tibble <- as_tibble(input_tibble)

  row_number <- nrow(input_tibble)
  groups_number <- ceiling(row_number/request_max)

  input_tibble_request <- input_tibble %>%
  mutate(group = sample(1:groups_number, row_number, replace = TRUE)) %>%
  group_by(group) %>%
  mutate(response = hgnc_id_from_symbol(value)$hgnc_id) %>%
  ungroup()

  input_tibble_request_repair <- input_tibble_request %>%
  filter(is.na(response)) %>%
  dplyr::select(value) %>%
  unique() %>%
  rowwise() %>%
  mutate(response = hgnc_id_from_prevsymbol(value)) %>%
  mutate(response = case_when(!is.na(response) ~ response, is.na(response) ~ hgnc_id_from_aliassymbol(value)))

  input_tibble_request <- input_tibble_request %>%
  left_join(input_tibble_request_repair, by = "value") %>%
  mutate(response = case_when(!is.na(response.x) ~ response.x, is.na(response.x) ~ response.y))

  return(input_tibble_request$response)
}


#' Retrieve symbol from HGNC ID
#'
#' This function retrieves the symbol corresponding to a given HGNC ID or IDs.
#'
#' @param hgnc_id_tibble A tibble containing the HGNC ID(s) for which to retrieve the symbol.
#'
#' @return A tibble with the symbol(s) corresponding to the input HGNC ID(s).
#'
#' @examples
#' hgnc_id_tibble <- tibble(value = c(123, 456, 789))
#' symbol_from_hgnc_id(hgnc_id_tibble)
#'
#' @export
symbol_from_hgnc_id <- function(hgnc_id_tibble) {
  hgnc_id_list_tibble <- as_tibble(hgnc_id_tibble) %>%
    dplyr::select(hgnc_id = value) %>%
    mutate(hgnc_id = as.integer(hgnc_id))

  hgnc_id_request <- fromJSON(paste0("http://rest.genenames.org/search/hgnc_id/", str_c(hgnc_id_list_tibble$hgnc_id, collapse = "+OR+")))

  hgnc_id_from_hgnc_id <- as_tibble(hgnc_id_request$response$docs)

  hgnc_id_from_hgnc_id <- hgnc_id_from_hgnc_id %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_hgnc_id)) hgnc_id else NA) %>%
  mutate(hgnc_id = if (exists('hgnc_id', where = hgnc_id_from_hgnc_id)) toupper(hgnc_id) else "") %>%
  mutate(hgnc_id = as.integer(str_split_fixed(hgnc_id, ":", 2)[, 2]))

  return_tibble <- hgnc_id_list_tibble %>%
  left_join(hgnc_id_from_hgnc_id, by = "hgnc_id") %>%
  dplyr::select(symbol)

  return(return_tibble)
}


#' Parallelized function to retrieve symbol from HGNC ID
#'
#' This function retrieves the symbol corresponding to HGNC IDs in parallel using
#' grouped requests. It supports parallel processing by dividing the input into
#' smaller groups and processing them concurrently.
#'
#' @param input_tibble A tibble containing the HGNC ID(s) for which to retrieve the symbol.
#' @param request_max Maximum number of HGNC IDs to include in each grouped request (default: 150).
#'
#' @return A vector of symbol(s) corresponding to the input HGNC ID(s).e
#'
#' @examples
#' input_tibble <- tibble(value = c(123, 456, 789))
#' symbol_from_hgnc_id_grouped(input_tibble)
#'
#' @export
symbol_from_hgnc_id_grouped <- function(input_tibble, request_max = 150) {
  input_tibble <- as_tibble(input_tibble)

  row_number <- nrow(input_tibble)
  groups_number <- ceiling(row_number/request_max)

  input_tibble_request <- input_tibble %>%
    mutate(group = sample(1:groups_number, row_number, replace = TRUE)) %>%
    group_by(group) %>%
    mutate(response = symbol_from_hgnc_id(value)$symbol) %>%
    ungroup()

  return(input_tibble_request$response)
}


#' Update and Process HGNC Data
#'
#' This function checks for the latest HGNC file and downloads it if necessary, 
#' then processes the gene information, updates STRINGdb identifiers, computes gene 
#' coordinates, and returns a tibble with the updated data. If the data is updated 
#' successfully, it saves it as a CSV file.
#'
#' @param hgnc_link The URL to download the latest HGNC file.
#' @param output_path String, the path where the output CSV file will be stored.
#' @param max_file_age Integer, the number of days to consider the file recent enough not to require re-downloading.
#' @return A tibble containing the updated non_alt_loci_set data.
#'
#' @examples
#' \dontrun{
#'   updated_hgnc_data <- update_process_hgnc_data()
#' }
#'
#' @export
update_process_hgnc_data <- function(hgnc_link = "http://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/tsv/non_alt_loci_set.txt",
                                      output_path = "data/",
                                      max_file_age = 1) {
  # Get current date in YYYY-MM-DD format
  current_date <- format(Sys.Date(), "%Y-%m-%d")

  # define the file base name
  hgnc_file_basename <- "non_alt_loci_set"

  if (check_file_age(hgnc_file_basename, output_path, max_file_age)) {
    hgnc_file <- get_newest_file(hgnc_file_basename, output_path)
  } else {
    hgnc_file <- paste0(output_path,
      hgnc_file_basename,
      ".",
      current_date,
      ".txt")

    download.file(hgnc_link, hgnc_file, mode = "wb", quiet = TRUE)
  }

  # Load the downloaded HGNC file
  non_alt_loci_set <- suppressWarnings(read_delim(hgnc_file, "\t", col_names = TRUE, show_col_types = FALSE) %>%
    mutate(update_date = current_date))

  # get symbols for string db mapping
  non_alt_loci_set_table <- non_alt_loci_set %>% 
    dplyr::select(symbol) %>%
    unique()

  # convert to data frame
  non_alt_loci_set_df <- non_alt_loci_set_table %>% 
      as.data.frame()

  # Load STRINGdb database
  string_db <- STRINGdb$new(version = "11.5", species = 9606, score_threshold = 200, input_directory = output_path)

  # Map the gene symbols to STRING identifiers
  non_alt_loci_set_mapped <- string_db$map(non_alt_loci_set_df, "symbol")

  # Convert the mapped data to a tibble
  non_alt_loci_set_mapped_tibble <- as_tibble(non_alt_loci_set_mapped) %>%
    filter(!is.na(STRING_id)) %>%
    group_by(symbol) %>%
    summarise(STRING_id = str_c(STRING_id, collapse=";")) %>%
    ungroup %>%
    unique()

  ## join with String identifiers
  non_alt_loci_set_string <- non_alt_loci_set %>% 
    left_join(non_alt_loci_set_mapped_tibble, by="symbol")

  # Compute gene coordinates from symbol and Ensembl ID
  non_alt_loci_set_coordinates <- non_alt_loci_set_string %>%
    mutate(hg19_coordinates_from_ensembl =
      gene_coordinates_from_ensembl(ensembl_gene_id)) %>%
    mutate(hg19_coordinates_from_symbol =
      gene_coordinates_from_symbol(symbol)) %>%
    mutate(hg38_coordinates_from_ensembl =
      gene_coordinates_from_ensembl(ensembl_gene_id, reference = "hg38")) %>%
    mutate(hg38_coordinates_from_symbol =
      gene_coordinates_from_symbol(symbol, reference = "hg38")) %>%
    mutate(bed_hg19 =
      case_when(
        !is.na(hg19_coordinates_from_ensembl$bed_format) ~
          hg19_coordinates_from_ensembl$bed_format,
        is.na(hg19_coordinates_from_ensembl$bed_format) ~
          hg19_coordinates_from_symbol$bed_format,
      )
    ) %>%
    mutate(bed_hg38 =
      case_when(
        !is.na(hg38_coordinates_from_ensembl$bed_format) ~
          hg38_coordinates_from_ensembl$bed_format,
        is.na(hg38_coordinates_from_ensembl$bed_format) ~
          hg38_coordinates_from_symbol$bed_format,
      )
    ) %>%
    dplyr::select(-hg19_coordinates_from_ensembl,
      -hg19_coordinates_from_symbol,
      -hg38_coordinates_from_ensembl,
      -hg38_coordinates_from_symbol)

  # Return the tibble
  return(non_alt_loci_set_coordinates)
}
