# functions/omim-parser-functions.R
#
# Pure parsing transforms for the OMIM/HPO acquisition files: genemap2.txt and
# mim2gene.txt. Extracted from omim-functions.R (WP #346, Wave 4 Task 10) to
# keep both files under the 600-line soft ceiling; parsing semantics (column
# positions, header handling, multi-stage Phenotypes-column regex, inheritance
# normalization) are unchanged.
#
# Provides:
# - parse_genemap2(): disease names, MIM numbers, mapping keys, and
#   inheritance modes from genemap2.txt's headerless Phenotypes column
# - parse_mim2gene(): phenotype + moved/removed entries from mim2gene.txt for
#   deprecation tracking
#
# Sourced by omim-functions.R (guard-sourced there, after the download module
# and before the rest of that file) so load_modules.R and setup_workers.R
# only need to reference omim-functions.R.

require(dplyr)
require(readr)

#' Parse genemap2.txt file from OMIM
#'
#' Reads and parses the genemap2.txt file, extracting disease names, MIM numbers,
#' mapping keys, and inheritance modes from the Phenotypes column. Uses position-based
#' column mapping for defensive handling of column name variations.
#'
#' @param genemap2_path Character string, path to the genemap2.txt file
#' @return Tibble with columns: Approved_Symbol, disease_ontology_name,
#'   disease_ontology_id, Mapping_key, hpo_mode_of_inheritance_term_name
#'
#' @details
#' The genemap2.txt file has no header row (uses # comment lines). Columns are
#' mapped by position (14 columns expected). The Phenotypes column (X13) uses
#' multi-stage parsing with negative lookaheads to extract:
#' - Disease name (may contain nested parentheses)
#' - Disease MIM number (6-digit code)
#' - Mapping key (1-4, indicates evidence level)
#' - Mode of inheritance (normalized to HPO terms)
#'
#' Multiple phenotypes per gene are separated by "; " (semicolon-space).
#' Multiple inheritance modes per phenotype are separated by ", " (comma-space).
#' Question marks ("?") in inheritance modes indicate uncertain inheritance and are removed.
#'
#' Inheritance term normalization maps 14 OMIM terms to standardized HPO vocabulary:
#' - "Autosomal dominant" -> "Autosomal dominant inheritance"
#' - "Autosomal recessive" -> "Autosomal recessive inheritance"
#' - "Digenic dominant" -> "Digenic inheritance"
#' - "Digenic recessive" -> "Digenic inheritance"
#' - "Isolated cases" -> "Sporadic"
#' - "Mitochondrial" -> "Mitochondrial inheritance"
#' - "Multifactorial" -> "Multifactorial inheritance"
#' - "Pseudoautosomal dominant" -> "X-linked dominant inheritance"
#' - "Pseudoautosomal recessive" -> "X-linked recessive inheritance"
#' - "Somatic mosaicism" -> "Somatic mosaicism"
#' - "Somatic mutation" -> "Somatic mutation"
#' - "X-linked" -> "X-linked inheritance"
#' - "X-linked dominant" -> "X-linked dominant inheritance"
#' - "X-linked recessive" -> "X-linked recessive inheritance"
#' - "Y-linked" -> "Y-linked inheritance"
#'
#' @examples
#' \dontrun{
#'   genemap_data <- parse_genemap2("data/genemap2.2026-02-07.txt")
#' }
#'
#' @export
parse_genemap2 <- function(genemap2_path) {
  # Read genemap2.txt (skip comment lines)
  raw_data <- readr::read_tsv(
    genemap2_path,
    col_names = FALSE,
    comment = "#",
    show_col_types = FALSE
  )

  # Defensive column count check
  if (ncol(raw_data) != 14) {
    stop(sprintf(
      "genemap2.txt column count mismatch. Expected 14, got %d. OMIM may have changed file format.",
      ncol(raw_data)
    ))
  }

  # Position-based column mapping
  genemap_data <- raw_data %>%
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
    # Select relevant columns for Phenotypes parsing
    dplyr::select(Approved_Symbol, Phenotypes) %>%
    # Split multiple phenotypes (semicolon-separated)
    tidyr::separate_rows(Phenotypes, sep = "; ") %>%
    # Extract inheritance mode (after last closing paren)
    tidyr::separate(
      Phenotypes,
      c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"),
      "\\), (?!.+\\))",
      fill = "right"
    ) %>%
    # Extract mapping key (last opening paren before inheritance)
    tidyr::separate(
      disease_ontology_name,
      c("disease_ontology_name", "Mapping_key"),
      "\\((?!.+\\()",
      fill = "right"
    ) %>%
    # Clean closing paren from mapping key
    dplyr::mutate(Mapping_key = stringr::str_replace_all(Mapping_key, "\\)", "")) %>%
    # Extract disease MIM number (6-digit code before mapping key)
    tidyr::separate(
      disease_ontology_name,
      c("disease_ontology_name", "MIM_Number"),
      ", (?=[0-9]{6})",
      fill = "right"
    ) %>%
    # Clean whitespace
    dplyr::mutate(
      Mapping_key = stringr::str_replace_all(Mapping_key, " ", ""),
      MIM_Number = stringr::str_replace_all(MIM_Number, " ", "")
    ) %>%
    # Filter entries without disease MIM number
    dplyr::filter(!is.na(MIM_Number)) %>%
    # Filter entries without gene symbol
    dplyr::filter(!is.na(Approved_Symbol)) %>%
    # Create OMIM ID with prefix
    dplyr::mutate(disease_ontology_id = paste0("OMIM:", MIM_Number)) %>%
    # Split multiple inheritance modes (comma-separated)
    tidyr::separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%
    # Remove question marks (uncertain inheritance)
    dplyr::mutate(
      hpo_mode_of_inheritance_term_name = stringr::str_replace_all(
        hpo_mode_of_inheritance_term_name,
        "\\?",
        ""
      )
    ) %>%
    # Remove MIM_Number column (now in disease_ontology_id)
    dplyr::select(-MIM_Number) %>%
    # Deduplicate
    unique() %>%
    # Normalize inheritance terms to HPO vocabulary
    dplyr::mutate(hpo_mode_of_inheritance_term_name = dplyr::case_when(
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

  return(genemap_data)
}


#' Parse mim2gene.txt file
#'
#' Reads and parses the mim2gene.txt file from OMIM. Filters for phenotype entries
#' and optionally includes moved/removed entries for deprecation workflow.
#'
#' @param file_path Character string, path to the mim2gene.txt file
#' @param include_moved_removed Logical, if TRUE includes moved/removed entries
#'   for deprecation detection (default: TRUE)
#' @return Tibble with columns: mim_number, mim_entry_type, gene_symbol, is_deprecated
#'
#' @details
#' The mim2gene.txt file has these columns:
#' - MIM_Number: OMIM identifier
#' - MIM_Entry_Type: gene, phenotype, predominantly phenotypes, moved/removed
#' - Entrez_Gene_ID: NCBI Gene ID (may be empty)
#' - Approved_Gene_Symbol_HGNC: HGNC symbol (may be empty for phenotypes)
#' - Ensembl_Gene_ID: Ensembl ID (may be empty)
#'
#' Phenotype entries typically have NA gene_symbol - this is expected.
#' Moved/removed entries are flagged for curator re-review workflow.
#'
#' @examples
#' \dontrun{
#'   mim_data <- parse_mim2gene("data/mim2gene.2026-01-24.txt")
#'   phenotypes_only <- parse_mim2gene("data/mim2gene.2026-01-24.txt", include_moved_removed = FALSE)
#' }
#'
#' @export
parse_mim2gene <- function(file_path, include_moved_removed = TRUE) {
  # Read tab-delimited file, skipping comment lines
  mim_data <- readr::read_delim(
    file_path,
    delim = "\t",
    comment = "#",
    col_names = c(
      "mim_number", "mim_entry_type", "entrez_gene_id",
      "gene_symbol", "ensembl_gene_id"
    ),
    col_types = readr::cols(
      mim_number = readr::col_character(),
      mim_entry_type = readr::col_character(),
      entrez_gene_id = readr::col_character(),
      gene_symbol = readr::col_character(),
      ensembl_gene_id = readr::col_character()
    ),
    na = c("", "NA"),
    show_col_types = FALSE
  )

  # Filter for phenotype entries (and optionally moved/removed)
  entry_types_to_include <- c("phenotype")
  if (include_moved_removed) {
    entry_types_to_include <- c(entry_types_to_include, "moved/removed")
  }

  result <- mim_data %>%
    dplyr::filter(mim_entry_type %in% entry_types_to_include) %>%
    dplyr::mutate(is_deprecated = mim_entry_type == "moved/removed") %>%
    dplyr::select(mim_number, mim_entry_type, gene_symbol, is_deprecated)

  return(result)
}
