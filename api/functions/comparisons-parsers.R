# api/functions/comparisons-parsers.R
#
# Per-source parsers + schema normalization for the comparisons data refresh.
# Extracted from comparisons-functions.R (WP #346 / #502) to keep both files
# under the 600-line soft ceiling; behavior is unchanged. These functions are
# pure transforms over downloaded files and depend only on the tidyverse
# (dplyr/readr/tidyr/stringr) plus jsonlite/pdftools loaded by the API/worker.
#
# Sourced by api/bootstrap/setup_workers.R (worker) before comparisons-functions.R.
#
# Functions:
#   - parse_radboudumc_pdf / parse_gene2phenotype_csv / parse_panelapp_tsv /
#     parse_sfari_csv / parse_ndd_genehub_csv / parse_orphanet_json
#   - adapt_genemap2_for_comparisons(genemap2_data, phenotype_to_genes_path)
#   - standardize_comparison_data(parsed_data, source_name, import_date)

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
    # Filter out PDF header/footer text and non-gene entries
    filter(!(gene_symbol %in% c(
      "", "%", "OMIM", "Gene", "Genes", "Median", "Ad",
      "Coverage", "Covered", "Non", "EAS.GenProductCoverage.pdf.footer.ad01",
      "PHENOTYPE", "DESCRIPTION", "ALACRIMIA", "ADDISONIANISM-"
    ))) %>%
    # Valid gene symbols are uppercase, 1-12 chars, alphanumeric with optional dash/number
    # Filter out entries that look like descriptions (contain lowercase, end with dash, etc.)
    filter(str_detect(gene_symbol, "^[A-Z0-9][A-Z0-9-]*[A-Z0-9]$|^[A-Z0-9]$")) %>%
    filter(nchar(gene_symbol) <= 15)

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

  # G2P changed their column names in 2026:
  #   "confidence category" -> "confidence"
  #   "mutation consequence" -> "variant consequence"
  #   "pmids" -> "publications"
  result <- data %>%
    dplyr::select(
      gene_symbol = `gene symbol`,
      disease_ontology_name = `disease name`,
      disease_ontology_id = `disease mim`,
      category = confidence,
      inheritance = `allelic requirement`,
      pathogenicity_mode = `variant consequence`,
      phenotype = phenotypes,
      publication_id = publications
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

#' Parse Geisinger DBD / NDD GeneHub CSV
#'
#' Parses the Developmental Brain Disorders gene database.
#'
#' The original DBD database (`dbd.geisingeradmi.org`) was retired and migrated
#' to NDD GeneHub (`nddgenehub.org`), which publishes the canonical case-level
#' "Full-Data.csv" export. It is the direct successor to the legacy
#' `DBD-Genes-Full-Data.csv` that the original importer consumed: one row per
#' curated case, keyed by `Gene Symbol`, carrying a `PubMed ID`, the seven
#' phenotype-category flags (`ID`, `ASD`, `EP`, `ADHD`, `SCZ`, `BD`, `CP` marked
#' with "X" when present), and per-variant `Variant 1 Inheritance` /
#' `Variant 1 Chr`.
#'
#' This parser aggregates the case-level rows to one row per gene, mirroring the
#' original importer: the union of flagged phenotypes, the distinct set of PubMed
#' IDs, and the distinct set of derived inheritance modes (X-linked when the
#' variant is on the X chromosome, otherwise mapped from the case inheritance
#' vocabulary). Category is "Definitive" because every gene in this export is a
#' curated NDD gene (DBD tiers 1-4 / AR live only in the derived per-mechanism
#' `Full-*-Table-Data.csv` files, which do not cover all genes and carry no
#' publications).
#'
#' The parser is schema-tolerant: it only reads columns that are present, so an
#' upstream column addition/removal does not break the refresh.
#'
#' @param file_path Path to downloaded CSV file
#'
#' @return Tibble with columns: gene_symbol, category, inheritance, phenotype,
#'   publication_id, list, version
#'
#' @export
# NDD GeneHub publishes the evidence tier in the per-mechanism table exports, not
# in the case-level Full-Data.csv: Full-LoF-Table-Data.csv carries the LoF `Tier`
# (1-4, or AR), and Full-Missense-Table-Data.csv lists the Missense-classified
# genes. A gene present in Full-Data.csv but in neither table has a single
# reported LoF variant and is "Unclassified". See https://nddgenehub.org/methodology.
NDD_GENEHUB_LOF_URL <- "https://nddgenehub.org/files/Full-LoF-Table-Data.csv"
NDD_GENEHUB_MISSENSE_URL <- "https://nddgenehub.org/files/Full-Missense-Table-Data.csv"

#' Build the NDD GeneHub gene -> evidence-tier category lookup.
#'
#' Reads the LoF + Missense tier tables (URLs by default, local paths for tests).
#' Best-effort: a table that cannot be read contributes nothing. LoF tier wins
#' over Missense when a gene is in both.
#'
#' @return Tibble(gene_symbol, category) with category in
#'   {AR, Tier 1, Tier 2, Tier 3, Tier 4, Missense}.
#' @export
ndd_genehub_category_lookup <- function(lof_path = NDD_GENEHUB_LOF_URL,
                                        missense_path = NDD_GENEHUB_MISSENSE_URL) {
  tier_labels <- c("AR" = "AR", "1" = "Tier 1", "2" = "Tier 2", "3" = "Tier 3", "4" = "Tier 4")
  lof <- tryCatch(read_csv(lof_path, show_col_types = FALSE), error = function(e) NULL)
  missense <- tryCatch(read_csv(missense_path, show_col_types = FALSE), error = function(e) NULL)

  lof_cat <- if (!is.null(lof) && all(c("Gene", "Tier") %in% colnames(lof))) {
    lof %>%
      dplyr::transmute(
        gene_symbol = as.character(Gene),
        category = unname(tier_labels[as.character(Tier)])
      ) %>%
      dplyr::filter(!is.na(category) & !is.na(gene_symbol))
  } else {
    tibble(gene_symbol = character(), category = character())
  }

  missense_cat <- if (!is.null(missense) && "Gene" %in% colnames(missense)) {
    missense %>%
      dplyr::transmute(gene_symbol = as.character(Gene), category = "Missense") %>%
      dplyr::filter(!is.na(gene_symbol)) %>%
      dplyr::anti_join(lof_cat, by = "gene_symbol")
  } else {
    tibble(gene_symbol = character(), category = character())
  }

  dplyr::bind_rows(lof_cat, missense_cat) %>% dplyr::distinct(gene_symbol, .keep_all = TRUE)
}

parse_ndd_genehub_csv <- function(file_path, category_lookup = NULL) {
  data <- read_csv(file_path, show_col_types = FALSE)

  gene_col <- intersect(c("Gene Symbol", "Gene"), colnames(data))[1]
  if (is.na(gene_col)) {
    stop("Geisinger/NDD GeneHub CSV missing expected 'Gene Symbol' column")
  }
  data <- data %>%
    rename(gene_symbol = !!gene_col) %>%
    mutate(gene_symbol = as.character(gene_symbol)) %>%
    filter(!is.na(gene_symbol) & gene_symbol != "")

  # Phenotype-category flags -> human-readable labels (present only if flagged).
  pheno_labels <- c(
    ID   = "Intellectual disability",
    ASD  = "Autism",
    EP   = "Epilepsy",
    ADHD = "Attention deficit hyperactivity disorder",
    SCZ  = "Schizophrenia",
    BD   = "Bipolar disorder",
    CP   = "Cerebral palsy"
  )
  pheno_labels <- pheno_labels[names(pheno_labels) %in% colnames(data)]

  base <- data %>% dplyr::distinct(gene_symbol)

  # Phenotypes: a gene has phenotype P if any of its cases flags column P.
  if (length(pheno_labels) > 0) {
    pheno_agg <- data %>%
      dplyr::select(gene_symbol, dplyr::all_of(names(pheno_labels))) %>%
      mutate(across(dplyr::all_of(names(pheno_labels)), as.character)) %>%
      pivot_longer(-gene_symbol, names_to = "code", values_to = "flag") %>%
      filter(!is.na(flag) & flag != "") %>%
      mutate(pheno = unname(pheno_labels[code])) %>%
      dplyr::distinct(gene_symbol, pheno) %>%
      group_by(gene_symbol) %>%
      summarise(phenotype = paste(sort(unique(pheno)), collapse = ";"), .groups = "drop")
    base <- base %>% left_join(pheno_agg, by = "gene_symbol")
  } else {
    base <- base %>% mutate(phenotype = NA_character_)
  }

  # Publications: distinct PubMed IDs per gene.
  if ("PubMed ID" %in% colnames(data)) {
    pub_agg <- data %>%
      dplyr::transmute(gene_symbol, pmid = str_extract_all(as.character(`PubMed ID`), "[0-9]+")) %>%
      tidyr::unnest(pmid) %>%
      filter(!is.na(pmid) & pmid != "") %>%
      dplyr::distinct(gene_symbol, pmid) %>%
      group_by(gene_symbol) %>%
      summarise(publication_id = paste(unique(pmid), collapse = ";"), .groups = "drop")
    base <- base %>% left_join(pub_agg, by = "gene_symbol")
  } else {
    base <- base %>% mutate(publication_id = NA_character_)
  }

  # Inheritance: X-linked when on the X chromosome, else mapped from the case
  # inheritance vocabulary (mirrors the original DBD importer's lookup).
  if ("Variant 1 Inheritance" %in% colnames(data)) {
    chr_col <- if ("Variant 1 Chr" %in% colnames(data)) as.character(data[["Variant 1 Chr"]]) else NA_character_
    inh_agg <- data %>%
      mutate(
        .chr = chr_col,
        .inh_raw = as.character(`Variant 1 Inheritance`),
        inheritance_term = dplyr::case_when(
          .chr %in% c("X", "23") ~ "X-linked inheritance",
          .inh_raw == "De novo" ~ "Sporadic",
          .inh_raw %in% c("Inherited", "Maternal", "Paternal", "Parental", "Unknown") ~
            "Autosomal dominant inheritance",
          .inh_raw == "Bi-parental" ~ "Autosomal recessive inheritance",
          .inh_raw == "Mosaic" ~ "Somatic mosaicism",
          TRUE ~ NA_character_
        )
      ) %>%
      filter(!is.na(inheritance_term)) %>%
      dplyr::distinct(gene_symbol, inheritance_term) %>%
      group_by(gene_symbol) %>%
      summarise(inheritance = paste(sort(unique(inheritance_term)), collapse = ";"), .groups = "drop")
    base <- base %>% left_join(inh_agg, by = "gene_symbol")
  } else {
    base <- base %>% mutate(inheritance = NA_character_)
  }

  # Category is the NDD GeneHub evidence tier (AR / Tier 1-4 / Missense), from the
  # tier tables; genes in neither table are "Unclassified".
  if (is.null(category_lookup)) {
    category_lookup <- tryCatch(ndd_genehub_category_lookup(), error = function(e) NULL)
  }
  if (!is.null(category_lookup) && nrow(category_lookup) > 0) {
    base <- base %>% left_join(category_lookup, by = "gene_symbol")
  } else {
    base <- base %>% mutate(category = NA_character_)
  }

  result <- base %>%
    mutate(
      list = "ndd_genehub",
      category = dplyr::coalesce(category, "Unclassified"),
      version = basename(file_path) %>% str_remove(pattern = "\\.csv$")
    )

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
    "ndd_genehub" = "gene,phenotype,inheritance(derived),publication,category(implied)",
    "omim_ndd" = "gene(aggregated),disease,inheritance(aggregated),category(implied)",
    "orphanet_id" = "gene,disease,inheritance,category(implied),pathogenicity(low-resolution)",
    "unknown"
  )

  # Handle radboudumc-specific OMIM ID formatting and set category
  # Original script sets category = "Definitive" for all radboudumc entries
  if (source_name == "radboudumc_ID" && "OMIMdiseaseID" %in% colnames(result)) {
    result <- result %>%
      dplyr::select(-any_of("disease_ontology_id")) %>%
      rename(disease_ontology_id = OMIMdiseaseID) %>%
      separate_rows(disease_ontology_id, sep = ";") %>%
      mutate(
        disease_ontology_id = case_when(
          is.na(disease_ontology_id) ~ disease_ontology_id,
          !is.na(disease_ontology_id) ~ paste0("OMIM:", disease_ontology_id)
        ),
        category = "Definitive"  # All radboudumc entries are considered Definitive
      )
  }

  # Geisinger / NDD GeneHub: the parser now carries the real DBD tier
  # (Tier 1-4 / AR) through as `category`; do not flatten it to "Definitive".

  # Handle gene2phenotype OMIM ID formatting
  if (source_name == "gene2phenotype") {
    result <- result %>%
      mutate(
        # Convert to character first (new G2P format has numeric disease_mim column)
        disease_ontology_id = as.character(disease_ontology_id),
        # Handle both old format ("No disease mim" text) and new format (NA)
        disease_ontology_id = na_if(disease_ontology_id, "No disease mim"),
        disease_ontology_id = case_when(
          is.na(disease_ontology_id) ~ NA_character_,
          TRUE ~ paste0("OMIM:", disease_ontology_id)
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
      {
        # Guard rowwise operations against empty tibble
        if (nrow(.) > 0) {
          rowwise(.) %>%
            mutate(
              category = toString(category),
              version = toString(version)
            ) %>%
            ungroup()
        } else {
          .
        }
      }
  }

  # Select only expected columns in order
  result <- result %>%
    dplyr::select(all_of(expected_cols))

  return(result)
}
