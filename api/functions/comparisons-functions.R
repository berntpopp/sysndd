# api/functions/comparisons-functions.R
#
# Core import logic for comparisons data refresh.
# Refactored from db/11_Rcommands_sysndd_db_table_database_comparisons.R
#
# This module handles:
# - Downloading data from 7+ external NDD databases
# - Parsing various formats (PDF, CSV, TSV, JSON, TXT)
# - Standardizing data to common schema
# - Resolving gene symbols to HGNC IDs via local database lookup
# - All-or-nothing database update via transaction
#
# Key functions:
#   - comparisons_update_async(params): Main async entry point for mirai daemon
#   - download_source_data(source_config, temp_dir): Download single source
#   - parse_* functions: Parse each source format
#   - standardize_comparison_data(parsed_data, source_name): Normalize schema
#   - resolve_hgnc_symbols(symbols, conn): Batch lookup HGNC IDs
#
# Usage:
#   Called from jobs_endpoints.R via create_job() executor_fn

library(DBI)
library(dplyr)
library(tidyr)
library(stringr)
library(readr)
library(jsonlite)
library(tibble)

# Conditionally load pdftools (may not be installed in all environments)
if (requireNamespace("pdftools", quietly = TRUE)) {
  library(pdftools)
}

#' Download Source Data
#'
#' Downloads data from a single source URL to a temporary file.
#' Handles different file formats appropriately.
#'
#' @param source_config A single-row tibble with source_name, source_url, file_format
#' @param temp_dir Directory to save downloaded files
#' @param timeout_seconds Download timeout in seconds (default: 300)
#'
#' @return Path to downloaded file, or NULL on failure
#'
#' @export
download_source_data <- function(source_config, temp_dir, timeout_seconds = 300) {
  source_name <- source_config$source_name
  url <- source_config$source_url
  format <- source_config$file_format

  # Determine file extension
  ext <- switch(format,
    "pdf" = ".pdf",
    "csv.gz" = ".csv.gz",
    "csv" = ".csv",
    "tsv" = ".tsv",
    "json" = ".json",
    "txt" = ".txt",
    ".dat"  # fallback

)

  output_file <- file.path(temp_dir, paste0(source_name, ext))

  tryCatch({
    # Download with timeout
    old_timeout <- getOption("timeout")
    options(timeout = timeout_seconds)
    on.exit(options(timeout = old_timeout), add = TRUE)

    download.file(url, output_file, mode = "wb", quiet = TRUE)

    if (file.exists(output_file) && file.size(output_file) > 0) {
      return(output_file)
    } else {
      warning(sprintf("[%s] Downloaded file is empty or missing", source_name))
      return(NULL)
    }
  }, error = function(e) {
    warning(sprintf("[%s] Download failed: %s", source_name, e$message))
    return(NULL)
  })
}

#' Parse Radboudumc PDF
#'
#' Parses the Radboudumc ID gene panel PDF to extract gene symbols and OMIM IDs.
#' Adapted from the original script's radboudumc parsing logic.
#'
#' @param file_path Path to downloaded PDF file
#'
#' @return Tibble with columns: gene_symbol, OMIMdiseaseID, list, version
#'
#' @export
parse_radboudumc_pdf <- function(file_path) {
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop("pdftools package required for PDF parsing")
  }

  # Read PDF text
  pdf_pages <- pdftools::pdf_text(file_path)

  # Extract version from first page (first line typically contains version)
  version <- pdf_pages[1] %>%
    str_extract(pattern = "^.+\\n") %>%
    str_remove(pattern = "\\n") %>%
    str_squish()

  # Parse all pages
  radboudumc_pdf_list <- pdf_pages %>%
    read_lines(skip = 3) %>%
    str_squish() %>%
    as_tibble() %>%
    separate(value,
             c("gene_symbol", "MedianCoverage", "pCoveredo10x", "pCoveredo20x", "OMIMdiseaseID"),
             sep = " ",
             fill = "right",
             extra = "drop") %>%
    filter(!is.na(gene_symbol)) %>%
    filter(!(gene_symbol %in% c(
      "", "%", "OMIM", "Gene", "Genes", "Median", "Ad",
      "Coverage", "Covered", "Non", "EAS.GenProductCoverage.pdf.footer.ad01"
    )))

  # Clean up OMIM IDs
  result <- radboudumc_pdf_list %>%
    dplyr::select(gene_symbol, OMIMdiseaseID) %>%
    mutate(
      OMIMdiseaseID = na_if(OMIMdiseaseID, "-"),
      list = "radboudumc_ID",
      version = version
    )

  return(result)
}

#' Parse Gene2Phenotype CSV
#'
#' Parses the Gene2Phenotype DDG2P CSV (gzipped) file.
#'
#' @param file_path Path to downloaded CSV.gz file
#'
#' @return Tibble with extracted columns
#'
#' @export
parse_gene2phenotype_csv <- function(file_path) {
  data <- read_csv(file_path, show_col_types = FALSE)

  result <- data %>%
    dplyr::select(
      gene_symbol = `gene symbol`,
      disease_ontology_name = `disease name`,
      disease_ontology_id = `disease mim`,
      category = `confidence category`,
      inheritance = `allelic requirement`,
      pathogenicity_mode = `mutation consequence`,
      phenotype = phenotypes,
      publication_id = pmids
    ) %>%
    mutate(
      list = "gene2phenotype",
      version = basename(file_path) %>% str_remove(pattern = "\\.csv(\\.gz)?$")
    )

  return(result)
}

#' Parse PanelApp TSV
#'
#' Parses the PanelApp intellectual disability panel TSV file.
#'
#' @param file_path Path to downloaded TSV file
#'
#' @return Tibble with extracted columns
#'
#' @export
parse_panelapp_tsv <- function(file_path) {
  data <- read_tsv(file_path, show_col_types = FALSE)

  # Filter for genes only (not regions/STRs)
  result <- data %>%
    filter(`Entity type` == "gene") %>%
    dplyr::select(
      gene_symbol = `Gene Symbol`,
      disease_ontology = Phenotypes,
      category = GEL_Status,
      inheritance = Model_Of_Inheritance,
      pathogenicity_mode = `Mode of pathogenicity`,
      phenotype = HPO,
      publication_id = Publications,
      version
    ) %>%
    mutate(list = "panelapp")

  return(result)
}

#' Parse SFARI CSV
#'
#' Parses the SFARI autism gene database CSV file.
#'
#' @param file_path Path to downloaded CSV file
#'
#' @return Tibble with extracted columns
#'
#' @export
parse_sfari_csv <- function(file_path) {
  data <- read_csv(file_path, show_col_types = FALSE)

  result <- data %>%
    dplyr::select(
      gene_symbol = `gene-symbol`,
      disease_ontology_name = syndromic,
      disease_ontology_id = syndromic,
      category = `gene-score`
    ) %>%
    mutate(
      list = "sfari",
      version = basename(file_path) %>% str_remove(pattern = "\\.csv$"),
      category = as.character(category),
      disease_ontology_id = as.character(disease_ontology_id),
      disease_ontology_name = as.character(disease_ontology_name)
    )

  return(result)
}

#' Parse Geisinger DBD CSV
#'
#' Parses the Geisinger Developmental Brain Disorders database CSV.
#'
#' @param file_path Path to downloaded CSV file
#'
#' @return Tibble with extracted columns
#'
#' @export
parse_geisinger_csv <- function(file_path) {
  data <- read_csv(file_path, show_col_types = FALSE)

  # Create inheritance lookup table
  geisinger_inheritance_lookup <- data %>%
    dplyr::select(Inheritance, Chr) %>%
    mutate(
      Chr = case_when(
        Chr > 22 ~ "X",
        Chr <= 22 ~ "A",
        is.na(Chr) ~ "A"
      )
    ) %>%
    unique() %>%
    mutate(
      inheritance_term_name = case_when(
        Chr == "X" ~ "X-linked inheritance",
        Inheritance == "De novo" ~ "Sporadic",
        Inheritance == "Inherited" ~ "Autosomal dominant inheritance",
        Inheritance == "Maternal" ~ "Autosomal dominant inheritance",
        Inheritance == "Paternal" ~ "Autosomal dominant inheritance",
        Inheritance == "Parental" ~ "Autosomal dominant inheritance",
        Inheritance == "Unknown" ~ "Autosomal dominant inheritance",
        Inheritance == "Bi-parental" ~ "Autosomal recessive inheritance",
        Inheritance == "Mosaic" ~ "Somatic mosaicism",
        TRUE ~ NA_character_
      )
    ) %>%
    mutate(Inheritance = paste0(Inheritance, "_", Chr)) %>%
    dplyr::select(-Chr) %>%
    unique()

  # Process main data
  geisinger_csv <- data %>%
    dplyr::select(
      gene_symbol = Gene,
      ID = `ID?DD`,
      Autism,
      ADHD,
      Schizophrenia,
      Bipolar = `Bipolar Disorder`,
      Inheritance,
      PMID,
      additional_information = `Additional Information`,
      Chr
    ) %>%
    mutate(
      Chr = case_when(
        Chr > 22 ~ "X",
        Chr <= 22 ~ "A",
        is.na(Chr) ~ "A"
      )
    ) %>%
    mutate(Inheritance = paste0(Inheritance, "_", Chr)) %>%
    mutate(additional_information = str_extract(additional_information, pattern = "PMID [0-9]+")) %>%
    mutate(additional_information = str_remove(additional_information, pattern = "PMID ")) %>%
    mutate(PMID = as.character(PMID)) %>%
    pivot_longer(c(PMID, additional_information), values_to = "PMID") %>%
    filter(!is.na(PMID)) %>%
    dplyr::select(-name) %>%
    pivot_longer(c(ID, Autism, ADHD, Schizophrenia, Bipolar), names_to = "phenotype") %>%
    filter(!is.na(value)) %>%
    dplyr::select(-value) %>%
    left_join(geisinger_inheritance_lookup, by = c("Inheritance")) %>%
    dplyr::select(-Inheritance, -Chr) %>%
    unique() %>%
    group_by(gene_symbol) %>%
    arrange(gene_symbol, PMID) %>%
    mutate(PMID = paste0(PMID, collapse = ";")) %>%
    unique() %>%
    arrange(gene_symbol, phenotype) %>%
    mutate(phenotype = paste0(phenotype, collapse = ";")) %>%
    unique() %>%
    arrange(gene_symbol, inheritance_term_name) %>%
    mutate(inheritance_term_name = paste0(inheritance_term_name, collapse = ";")) %>%
    unique() %>%
    ungroup()

  result <- geisinger_csv %>%
    mutate(
      list = "geisinger_DBD",
      version = basename(file_path) %>% str_remove(pattern = "\\.csv$")
    ) %>%
    rename(inheritance = inheritance_term_name, publication_id = PMID)

  return(result)
}

#' Parse Orphanet ID JSON
#'
#' Parses the Orphanet ID genes JSON from their API endpoint.
#'
#' @param file_path Path to downloaded JSON file
#'
#' @return Tibble with extracted columns
#'
#' @export
parse_orphanet_json <- function(file_path) {
  json_content <- paste(readLines(file_path, warn = FALSE), collapse = "")
  json_data <- fromJSON(json_content)

  result <- as_tibble(json_data$data) %>%
    filter(GeneType != "Disorder-associated locus") %>%
    mutate(
      list = "orphanet_id",
      version = basename(file_path) %>% str_remove(pattern = "\\.json$"),
      category = "Definitive",
      SourceOfValidation = str_replace_all(SourceOfValidation, " ", ""),
      DisorderOMIM = str_replace_all(DisorderOMIM, "(?=[1-9][0-9]{5})", "OMIM:"),
      DisorderOMIM = str_replace_all(DisorderOMIM, ", ", ";"),
      OrphaCode = str_replace_all(OrphaCode, " ", ""),
      DisorderGeneAssociationType = str_replace_all(DisorderGeneAssociationType, "<br>", ""),
      SourceOfValidation = na_if(SourceOfValidation, "NULL")
    ) %>%
    separate_rows(Inheritance, sep = ", ") %>%
    dplyr::select(
      gene_symbol = GeneSymbol,
      disease_ontology_id = OrphaCode,
      disease_ontology_name = DisorderName,
      inheritance = Inheritance,
      pathogenicity_mode = DisorderGeneAssociationType,
      publication_id = SourceOfValidation,
      list,
      version,
      category
    )

  return(result)
}

#' Parse OMIM Genemap2 with HPO Phenotype Annotations
#'
#' Parses OMIM genemap2.txt along with HPO phenotype.hpoa to identify
#' NDD-related genes based on HPO term filtering.
#'
#' @param genemap2_path Path to omim_genemap2.txt file
#' @param phenotype_hpoa_path Path to phenotype.hpoa file
#'
#' @return Tibble with extracted NDD-related genes
#'
#' @export
parse_omim_genemap2 <- function(genemap2_path, phenotype_hpoa_path) {
  # Define NDD-related HPO terms (Neurodevelopmental abnormality HP:0012759 and children)
  # Note: In the async job, we fetch these from HPO API or use a static list
  ndd_phenotypes <- c(
    "HP:0012759", "HP:0001249", "HP:0001256", "HP:0002187",
    "HP:0002342", "HP:0006889", "HP:0010864"
  )

  # Read phenotype.hpoa (skip header lines)
  phenotype_hpoa <- read_tsv(
    phenotype_hpoa_path,
    skip = 4,
    show_col_types = FALSE
  )

  # Read genemap2.txt (skip comment lines)
  omim_genemap2 <- read_tsv(
    genemap2_path,
    col_names = FALSE,
    comment = "#",
    show_col_types = FALSE
  ) %>%
    dplyr::select(
      Chromosome = X1,
      Genomic_Position_Start = X2,
      Genomic_Position_End = X3,
      Cyto_Location = X4,
      Computed_Cyto_Location = X5,
      MIM_Number = X6,
      Gene_Symbols = X7,
      Gene_Name = X8,
      Approved_Symbol = X9,
      Entrez_Gene_ID = X10,
      Ensembl_Gene_ID = X11,
      Comments = X12,
      Phenotypes = X13,
      Mouse_Gene_Symbol_ID = X14
    ) %>%
    dplyr::select(Approved_Symbol, Phenotypes) %>%
    separate_rows(Phenotypes, sep = "; ") %>%
    separate(Phenotypes, c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"),
             "\\), (?!.+\\))", fill = "right") %>%
    separate(disease_ontology_name, c("disease_ontology_name", "Mapping_key"),
             "\\((?!.+\\()", fill = "right") %>%
    mutate(Mapping_key = str_replace_all(Mapping_key, "\\)", "")) %>%
    separate(disease_ontology_name, c("disease_ontology_name", "MIM_Number"),
             ", (?=[0-9][0-9][0-9][0-9][0-9][0-9])", fill = "right") %>%
    mutate(
      Mapping_key = str_replace_all(Mapping_key, " ", ""),
      MIM_Number = str_replace_all(MIM_Number, " ", "")
    ) %>%
    filter(!is.na(MIM_Number)) %>%
    filter(!is.na(Approved_Symbol)) %>%
    mutate(disease_ontology_id = paste0("OMIM:", MIM_Number)) %>%
    separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%
    mutate(hpo_mode_of_inheritance_term_name = str_replace_all(hpo_mode_of_inheritance_term_name, "\\?", "")) %>%
    dplyr::select(-MIM_Number) %>%
    unique() %>%
    # Map inheritance terms to standardized names
    mutate(hpo_mode_of_inheritance_term_name = case_when(
      hpo_mode_of_inheritance_term_name == "Autosomal dominant" ~ "Autosomal dominant inheritance",
      hpo_mode_of_inheritance_term_name == "Autosomal recessive" ~ "Autosomal recessive inheritance",
      hpo_mode_of_inheritance_term_name == "Digenic dominant" ~ "Digenic inheritance",
      hpo_mode_of_inheritance_term_name == "Digenic recessive" ~ "Digenic inheritance",
      hpo_mode_of_inheritance_term_name == "Isolated cases" ~ "Sporadic",
      hpo_mode_of_inheritance_term_name == "Mitochondrial" ~ "Mitochondrial inheritance",
      hpo_mode_of_inheritance_term_name == "Multifactorial" ~ "Multifactorial inheritance",
      hpo_mode_of_inheritance_term_name == "Pseudoautosomal dominant" ~ "X-linked dominant inheritance",
      hpo_mode_of_inheritance_term_name == "Pseudoautosomal recessive" ~ "X-linked recessive inheritance",
      hpo_mode_of_inheritance_term_name == "Somatic mosaicism" ~ "Somatic mosaicism",
      hpo_mode_of_inheritance_term_name == "Somatic mutation" ~ "Somatic mutation",
      hpo_mode_of_inheritance_term_name == "X-linked" ~ "X-linked inheritance",
      hpo_mode_of_inheritance_term_name == "X-linked dominant" ~ "X-linked dominant inheritance",
      hpo_mode_of_inheritance_term_name == "X-linked recessive" ~ "X-linked recessive inheritance",
      hpo_mode_of_inheritance_term_name == "Y-linked" ~ "Y-linked inheritance",
      TRUE ~ hpo_mode_of_inheritance_term_name
    ))

  # Filter for NDD-related OMIM entries via HPO phenotypes
  phenotype_hpoa_omim_ndd <- phenotype_hpoa %>%
    filter(str_detect(database_id, "OMIM")) %>%
    filter(hpo_id %in% ndd_phenotypes) %>%
    dplyr::select(database_id) %>%
    unique()

  # Join to get NDD genes
  result <- phenotype_hpoa_omim_ndd %>%
    left_join(omim_genemap2, by = c("database_id" = "disease_ontology_id")) %>%
    filter(!is.na(Approved_Symbol)) %>%
    mutate(
      list = "omim_ndd",
      version = basename(genemap2_path) %>% str_remove(pattern = "\\.txt$"),
      category = "Definitive"
    ) %>%
    dplyr::select(
      gene_symbol = Approved_Symbol,
      disease_ontology_id = database_id,
      disease_ontology_name,
      inheritance = hpo_mode_of_inheritance_term_name,
      list,
      version,
      category
    )

  return(result)
}

#' Standardize Comparison Data
#'
#' Normalizes parsed data from any source to the common schema used in
#' ndd_database_comparison table.
#'
#' @param parsed_data Tibble from a parse_* function
#' @param source_name Name of the source (e.g., "radboudumc_ID")
#' @param import_date Date string for import_date column
#'
#' @return Tibble with standardized columns
#'
#' @export
standardize_comparison_data <- function(parsed_data, source_name, import_date) {
  # Define expected columns
  expected_cols <- c(
    "symbol", "hgnc_id", "disease_ontology_id", "disease_ontology_name",
    "inheritance", "category", "pathogenicity_mode", "phenotype",
    "publication_id", "list", "version", "import_date", "granularity"
  )

  # Start with the parsed data
  result <- parsed_data

  # Rename gene_symbol to symbol if present
  if ("gene_symbol" %in% colnames(result)) {
    result <- result %>% rename(symbol = gene_symbol)
  }

  # Ensure all expected columns exist
  for (col in expected_cols) {
    if (!col %in% colnames(result)) {
      result[[col]] <- NA_character_
    }
  }

  # Set import_date
  result$import_date <- import_date

  # Set source-specific granularity
  result$granularity <- switch(source_name,
    "radboudumc_ID" = "gene,disease,category(implied)",
    "gene2phenotype" = "gene,disease,inheritance,category,pathogenicity",
    "panelapp" = "gene,disease(aggregated),inheritance(aggregated),category,pathogenicity(incomplete)",
    "sfari" = "gene,disease,category",
    "geisinger_DBD" = "gene,disease,category",
    "omim_ndd" = "gene(aggregated),disease,inheritance(aggregated),category(implied)",
    "orphanet_id" = "gene,disease,inheritance,category(implied),pathogenicity(low-resolution)",
    "unknown"
  )

  # Handle radboudumc-specific OMIM ID formatting
  if (source_name == "radboudumc_ID" && "OMIMdiseaseID" %in% colnames(result)) {
    result <- result %>%
      dplyr::select(-any_of("disease_ontology_id")) %>%
      rename(disease_ontology_id = OMIMdiseaseID) %>%
      separate_rows(disease_ontology_id, sep = ";") %>%
      mutate(
        disease_ontology_id = case_when(
          is.na(disease_ontology_id) ~ disease_ontology_id,
          !is.na(disease_ontology_id) ~ paste0("OMIM:", disease_ontology_id)
        )
      )
  }

  # Handle gene2phenotype OMIM ID formatting
  if (source_name == "gene2phenotype") {
    result <- result %>%
      mutate(
        disease_ontology_id = na_if(disease_ontology_id, "No disease mim"),
        disease_ontology_id = case_when(
          is.na(disease_ontology_id) ~ disease_ontology_id,
          !is.na(disease_ontology_id) ~ paste0("OMIM:", disease_ontology_id)
        ),
        phenotype = str_replace_all(phenotype, ";", ","),
        publication_id = str_replace_all(publication_id, ";", ",")
      )
  }

  # Handle panelapp OMIM/MONDO ID extraction
  if (source_name == "panelapp" && "disease_ontology" %in% colnames(result)) {
    result <- result %>%
      mutate(
        disease_ontology = str_replace_all(disease_ontology, "(?<=[1-9][0-9]{5})", ";"),
        disease_ontology = str_replace_all(disease_ontology, "(?=[1-9][0-9]{5})", "OMIM:"),
        disease_ontology = str_replace_all(disease_ontology, "OMIM:OMIM:", "OMIM:"),
        disease_ontology = str_replace_all(disease_ontology, ";;", ";"),
        disease_ontology = str_replace_all(disease_ontology, "; ", ";"),
        disease_ontology = str_replace(disease_ontology, ";$", ""),
        publication_id = str_replace_all(publication_id, ";", ",")
      ) %>%
      separate_rows(disease_ontology, sep = ";") %>%
      separate(disease_ontology, c("disease_ontology_name", "disease_ontology_id"),
               sep = "(?=OMIM:|MONDO:)", fill = "right") %>%
      mutate(
        disease_ontology_name = str_squish(disease_ontology_name),
        disease_ontology_id = str_squish(disease_ontology_id),
        disease_ontology_name = str_replace(disease_ontology_name, ",$", "")
      ) %>%
      rowwise() %>%
      mutate(
        category = toString(category),
        version = toString(version)
      ) %>%
      ungroup()
  }

  # Select only expected columns in order
  result <- result %>%
    dplyr::select(all_of(expected_cols))

  return(result)
}

#' Resolve HGNC Symbols to HGNC IDs
#'
#' Batch lookup of gene symbols to HGNC IDs using the local non_alt_loci_set table.
#' Handles current symbols, previous symbols, and alias symbols.
#'
#' @param symbols Character vector of gene symbols to resolve
#' @param conn Database connection
#'
#' @return Tibble with columns: symbol, hgnc_id
#'
#' @export
resolve_hgnc_symbols <- function(symbols, conn) {
  if (length(symbols) == 0) {
    return(tibble(symbol = character(), hgnc_id = character()))
  }

  # Ensure unique symbols
  unique_symbols <- unique(toupper(symbols))

  # Step 1: Direct symbol lookup
  # Use parameterized query with IN clause
  placeholders <- paste(rep("?", length(unique_symbols)), collapse = ",")
  query <- sprintf("
    SELECT symbol, hgnc_id
    FROM non_alt_loci_set
    WHERE UPPER(symbol) IN (%s)
  ", placeholders)

  stmt <- DBI::dbSendQuery(conn, query)
  DBI::dbBind(stmt, as.list(unique_symbols))
  direct_matches <- DBI::dbFetch(stmt)
  DBI::dbClearResult(stmt)

  direct_matches <- as_tibble(direct_matches) %>%
    mutate(symbol = toupper(symbol))

  # Find symbols not yet matched
  matched_symbols <- toupper(direct_matches$symbol)
  unmatched <- setdiff(unique_symbols, matched_symbols)

  # Step 2: Previous symbol lookup
  prev_matches <- tibble(symbol = character(), hgnc_id = character())
  if (length(unmatched) > 0) {
    # Search in prev_symbol column (comma-separated list)
    # This is less efficient but necessary for fallback
    prev_query <- "
      SELECT symbol, hgnc_id, prev_symbol
      FROM non_alt_loci_set
      WHERE prev_symbol IS NOT NULL AND prev_symbol != ''
    "
    prev_data <- DBI::dbGetQuery(conn, prev_query)

    if (nrow(prev_data) > 0) {
      for (i in seq_along(unmatched)) {
        sym <- unmatched[i]
        # Check if sym appears in any prev_symbol field
        match_idx <- which(sapply(prev_data$prev_symbol, function(ps) {
          sym %in% toupper(str_split(ps, "\\|")[[1]])
        }))
        if (length(match_idx) > 0) {
          prev_matches <- bind_rows(prev_matches, tibble(
            symbol = sym,
            hgnc_id = prev_data$hgnc_id[match_idx[1]]
          ))
        }
      }
    }
  }

  # Update unmatched list
  unmatched <- setdiff(unmatched, prev_matches$symbol)

  # Step 3: Alias symbol lookup
  alias_matches <- tibble(symbol = character(), hgnc_id = character())
  if (length(unmatched) > 0) {
    alias_query <- "
      SELECT symbol, hgnc_id, alias_symbol
      FROM non_alt_loci_set
      WHERE alias_symbol IS NOT NULL AND alias_symbol != ''
    "
    alias_data <- DBI::dbGetQuery(conn, alias_query)

    if (nrow(alias_data) > 0) {
      for (i in seq_along(unmatched)) {
        sym <- unmatched[i]
        match_idx <- which(sapply(alias_data$alias_symbol, function(as) {
          sym %in% toupper(str_split(as, "\\|")[[1]])
        }))
        if (length(match_idx) > 0) {
          alias_matches <- bind_rows(alias_matches, tibble(
            symbol = sym,
            hgnc_id = alias_data$hgnc_id[match_idx[1]]
          ))
        }
      }
    }
  }

  # Combine all matches
  all_matches <- bind_rows(direct_matches, prev_matches, alias_matches) %>%
    dplyr::select(symbol, hgnc_id) %>%
    distinct()

  # Join back to original symbols (preserving order and including unmatched)
  result <- tibble(symbol = toupper(symbols)) %>%
    left_join(all_matches, by = "symbol")

  return(result)
}

#' Comparisons Update Async
#'
#' Main async entry point for the comparisons data refresh job.
#' Called from mirai daemon via create_job().
#'
#' Downloads all active sources, parses, standardizes, resolves HGNC IDs,
#' merges, and atomically updates the database.
#'
#' All-or-nothing: any source failure aborts entire refresh.
#'
#' @param params List containing:
#'   - db_config: Database connection config (host, port, user, password, dbname)
#'   - .__job_id__: Job ID for progress reporting (injected by create_job)
#'
#' @return List with status, sources_updated, rows_written
#'
#' @export
comparisons_update_async <- function(params) {
  job_id <- params$.__job_id__
  db_config <- params$db_config

  # Create progress reporter
  progress <- create_progress_reporter(job_id)

  # Initialize tracking variables
  temp_dir <- NULL
  conn <- NULL

  tryCatch({
    progress("init", "Initializing comparisons update...", current = 0, total = 10)

    # Create temp directory for downloads
    temp_dir <- tempfile(pattern = "comparisons_")
    dir.create(temp_dir, recursive = TRUE)

    # Create database connection
    progress("connect", "Connecting to database...", current = 1, total = 10)
    conn <- DBI::dbConnect(
      RMariaDB::MariaDB(),
      dbname = db_config$dbname,
      host = db_config$host,
      user = db_config$user,
      password = db_config$password,
      port = db_config$port
    )

    # Get active sources
    progress("config", "Loading source configuration...", current = 2, total = 10)
    sources <- get_active_sources(conn)

    if (nrow(sources) == 0) {
      stop("No active sources configured in comparisons_config table")
    }

    message(sprintf("[%s] [job:%s] Found %d active sources", Sys.time(), job_id, nrow(sources)))

    # Track downloaded files for OMIM+HPO pairing
    downloaded_files <- list()
    all_parsed_data <- list()
    import_date <- format(Sys.Date(), "%Y-%m-%d")

    # Download all sources
    for (i in seq_len(nrow(sources))) {
      source <- sources[i, ]
      source_name <- source$source_name
      progress_current <- 2 + i
      progress_total <- 2 + nrow(sources) + 3

      progress("download", sprintf("Downloading %s...", source_name),
               current = progress_current, total = progress_total)

      file_path <- download_source_data(source, temp_dir)

      if (is.null(file_path)) {
        update_comparisons_metadata(conn, "failed", nrow(sources), 0,
                                    sprintf("Failed to download %s", source_name))
        stop(sprintf("Failed to download source: %s", source_name))
      }

      downloaded_files[[source_name]] <- file_path
      message(sprintf("[%s] [job:%s] Downloaded %s to %s", Sys.time(), job_id, source_name, file_path))
    }

    # Parse and standardize each source
    progress("parse", "Parsing downloaded files...",
             current = 2 + nrow(sources) + 1, total = 2 + nrow(sources) + 3)

    for (i in seq_len(nrow(sources))) {
      source <- sources[i, ]
      source_name <- source$source_name
      file_path <- downloaded_files[[source_name]]

      message(sprintf("[%s] [job:%s] Parsing %s...", Sys.time(), job_id, source_name))

      parsed_data <- tryCatch({
        switch(source_name,
          "radboudumc_ID" = parse_radboudumc_pdf(file_path),
          "gene2phenotype" = parse_gene2phenotype_csv(file_path),
          "panelapp" = parse_panelapp_tsv(file_path),
          "sfari" = parse_sfari_csv(file_path),
          "geisinger_DBD" = parse_geisinger_csv(file_path),
          "orphanet_id" = parse_orphanet_json(file_path),
          "omim_genemap2" = {
            # OMIM requires HPO phenotype file
            hpoa_path <- downloaded_files[["phenotype_hpoa"]]
            if (is.null(hpoa_path)) {
              stop("phenotype_hpoa file required for omim_genemap2 parsing")
            }
            parse_omim_genemap2(file_path, hpoa_path)
          },
          "phenotype_hpoa" = NULL,  # Used by omim_genemap2, not parsed separately
          stop(sprintf("Unknown source: %s", source_name))
        )
      }, error = function(e) {
        update_comparisons_metadata(conn, "failed", nrow(sources), 0,
                                    sprintf("Failed to parse %s: %s", source_name, e$message))
        stop(sprintf("Failed to parse %s: %s", source_name, e$message))
      })

      if (!is.null(parsed_data) && nrow(parsed_data) > 0) {
        # Standardize the data
        standardized <- standardize_comparison_data(parsed_data, source_name, import_date)
        all_parsed_data[[source_name]] <- standardized
        message(sprintf("[%s] [job:%s] Parsed %d rows from %s", Sys.time(), job_id, nrow(standardized), source_name))
      }
    }

    # Merge all data
    progress("merge", "Merging and resolving HGNC IDs...",
             current = 2 + nrow(sources) + 2, total = 2 + nrow(sources) + 3)

    merged_data <- bind_rows(all_parsed_data)

    if (nrow(merged_data) == 0) {
      stop("No data parsed from any source")
    }

    message(sprintf("[%s] [job:%s] Merged %d total rows", Sys.time(), job_id, nrow(merged_data)))

    # Resolve HGNC symbols
    symbols_to_resolve <- merged_data$symbol[!is.na(merged_data$symbol)]
    resolved <- resolve_hgnc_symbols(symbols_to_resolve, conn)

    # Join resolved HGNC IDs back to data
    merged_data <- merged_data %>%
      mutate(symbol = toupper(symbol)) %>%
      left_join(resolved %>% dplyr::select(symbol, resolved_hgnc = hgnc_id), by = "symbol") %>%
      mutate(
        hgnc_id = case_when(
          !is.na(resolved_hgnc) ~ paste0("HGNC:", resolved_hgnc),
          TRUE ~ hgnc_id
        )
      ) %>%
      dplyr::select(-resolved_hgnc) %>%
      # Get symbol from HGNC table for resolved genes
      left_join(
        DBI::dbGetQuery(conn, "SELECT hgnc_id, symbol AS resolved_symbol FROM non_alt_loci_set") %>%
          mutate(hgnc_id = paste0("HGNC:", hgnc_id)),
        by = "hgnc_id"
      ) %>%
      mutate(symbol = coalesce(resolved_symbol, symbol)) %>%
      dplyr::select(-resolved_symbol) %>%
      # Filter out rows without HGNC ID
      filter(!is.na(hgnc_id) & hgnc_id != "HGNC:NA") %>%
      # Add comparison_id
      mutate(comparison_id = row_number())

    message(sprintf("[%s] [job:%s] Final dataset: %d rows with HGNC IDs", Sys.time(), job_id, nrow(merged_data)))

    # Write to database atomically
    progress("write", "Writing to database...",
             current = 2 + nrow(sources) + 3, total = 2 + nrow(sources) + 3)

    # Atomic table replacement: DELETE + INSERT in transaction
    tryCatch({
      DBI::dbBegin(conn)

      # Delete existing data
      DBI::dbExecute(conn, "DELETE FROM ndd_database_comparison")

      # Insert new data
      if (nrow(merged_data) > 0) {
        # Select only columns that exist in the table
        table_cols <- DBI::dbListFields(conn, "ndd_database_comparison")
        insert_data <- merged_data %>%
          dplyr::select(any_of(table_cols))

        DBI::dbAppendTable(conn, "ndd_database_comparison", insert_data)
      }

      # Update metadata
      update_comparisons_metadata(conn, "success", length(all_parsed_data), nrow(merged_data))

      # Update source timestamps
      for (source_name in names(all_parsed_data)) {
        update_source_last_updated(conn, source_name)
      }

      DBI::dbCommit(conn)

    }, error = function(e) {
      DBI::dbRollback(conn)
      update_comparisons_metadata(conn, "failed", length(all_parsed_data), 0,
                                  sprintf("Database write failed: %s", e$message))
      stop(sprintf("Database write failed: %s", e$message))
    })

    message(sprintf("[%s] [job:%s] Comparisons update completed: %d rows from %d sources",
                    Sys.time(), job_id, nrow(merged_data), length(all_parsed_data)))

    # Return success result
    list(
      status = "completed",
      sources_updated = length(all_parsed_data),
      rows_written = nrow(merged_data),
      message = sprintf("Successfully updated %d rows from %d sources",
                        nrow(merged_data), length(all_parsed_data))
    )

  }, error = function(e) {
    message(sprintf("[%s] [job:%s] Comparisons update failed: %s", Sys.time(), job_id, e$message))
    stop(e)

  }, finally = {
    # Cleanup temp directory
    if (!is.null(temp_dir) && dir.exists(temp_dir)) {
      unlink(temp_dir, recursive = TRUE)
    }

    # Close database connection
    if (!is.null(conn) && DBI::dbIsValid(conn)) {
      DBI::dbDisconnect(conn)
    }
  })
}
