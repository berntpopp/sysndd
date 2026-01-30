# api/functions/hgnc-enrichment-gnomad.R
#### gnomAD constraint batch enrichment and AlphaFold ID derivation
#### for the HGNC update pipeline

require(jsonlite)
require(readr)
require(dplyr)

# Bulk constraint metrics TSV from gnomAD (single-line change for version upgrades)
GNOMAD_CONSTRAINT_TSV_URL <- "https://storage.googleapis.com/gcp-public-data--gnomad/release/4.1/constraint/gnomad.v4.1.constraint_metrics.tsv"

# Minimum expected file size in bytes (~10 MB typical; reject anything < 1 MB)
GNOMAD_TSV_MIN_SIZE <- 1e6

# Minimum number of MANE Select genes expected (~19k in v4.1; warn below 15k)
GNOMAD_MIN_MANE_GENES <- 15000

# Column mapping from gnomAD v4.1 TSV (dot-separated) to our JSON field names
GNOMAD_TSV_COLUMN_MAP <- c(
  "lof.pLI"          = "pLI",
  "lof.oe"           = "oe_lof",
  "lof.oe_ci.lower"  = "oe_lof_lower",
  "lof.oe_ci.upper"  = "oe_lof_upper",
  "mis.oe"           = "oe_mis",
  "mis.oe_ci.lower"  = "oe_mis_lower",
  "mis.oe_ci.upper"  = "oe_mis_upper",
  "syn.oe"           = "oe_syn",
  "syn.oe_ci.lower"  = "oe_syn_lower",
  "syn.oe_ci.upper"  = "oe_syn_upper",
  "lof.exp"          = "exp_lof",
  "lof.obs"          = "obs_lof",
  "mis.exp"          = "exp_mis",
  "mis.obs"          = "obs_mis",
  "syn.exp"          = "exp_syn",
  "syn.obs"          = "obs_syn",
  "lof.z_score"      = "lof_z",
  "mis.z_score"      = "mis_z",
  "syn.z_score"      = "syn_z"
)


#' Enrich HGNC tibble with gnomAD constraint scores (bulk TSV approach)
#'
#' @description
#' Downloads the gnomAD v4.1 bulk constraint metrics TSV (~10 MB), filters
#' for MANE Select transcripts, maps columns to our 19-field JSON format,
#' and joins by gene symbol. Completes in seconds instead of the ~73 hours
#' required by the previous per-gene API approach.
#'
#' @param hgnc_tibble A tibble from the HGNC update pipeline with at least
#'   a `symbol` column containing gene symbols.
#' @param progress_fn Optional progress reporting function with signature
#'   `progress_fn(step_id, step_label, current, total)`.
#'
#' @return The input tibble with an added `gnomad_constraints` column
#'   containing JSON strings (or NA for genes without constraint data).
#'
#' @details
#' - Downloads bulk TSV once from Google Cloud Storage
#' - Validates file size and required columns before parsing
#' - Filters for MANE Select transcripts (one canonical transcript per gene)
#' - Deduplicates by gene symbol (first match if multiple MANE Select rows)
#' - Uses case-insensitive gene symbol matching
#' - Asserts a minimum number of enriched genes to catch silent failures
#' - Genes not in gnomAD get NA
#' - JSON format is identical to the per-gene API approach
#'
#' @export
enrich_gnomad_constraints <- function(hgnc_tibble, progress_fn = NULL) {
  total_steps <- 3
  message("[gnomAD enrichment] Starting bulk constraint enrichment")

  # --- Step 1: Download TSV ---
  message("[gnomAD enrichment] Step 1/3: Downloading constraint metrics TSV")
  if (!is.null(progress_fn)) {
    tryCatch(
      progress_fn("gnomad", "gnomAD: downloading TSV", current = 1, total = total_steps),
      error = function(e) NULL
    )
  }

  tmp_file <- tempfile(fileext = ".tsv")
  on.exit(unlink(tmp_file), add = TRUE)

  tryCatch(
    {
      download.file(GNOMAD_CONSTRAINT_TSV_URL, destfile = tmp_file, mode = "wb", quiet = TRUE)
    },
    error = function(e) {
      stop(sprintf("[gnomAD enrichment] Failed to download TSV: %s", conditionMessage(e)))
    }
  )

  # [I4] Validate downloaded file is a real TSV, not an error page or empty file
  file_size <- file.info(tmp_file)$size
  if (is.na(file_size) || file_size < GNOMAD_TSV_MIN_SIZE) {
    stop(sprintf(
      "[gnomAD enrichment] Downloaded file too small (%s bytes, expected >%s). URL may have changed or returned an error page.",
      format(file_size, big.mark = ","), format(GNOMAD_TSV_MIN_SIZE, big.mark = ",")
    ))
  }
  message(sprintf(
    "[gnomAD enrichment] Downloaded %s bytes to %s",
    format(file_size, big.mark = ","), tmp_file
  ))

  # --- Step 2: Parse and filter ---
  message("[gnomAD enrichment] Step 2/3: Parsing and filtering for MANE Select transcripts")
  if (!is.null(progress_fn)) {
    tryCatch(
      progress_fn("gnomad", "gnomAD: parsing TSV", current = 2, total = total_steps),
      error = function(e) NULL
    )
  }

  # Read with readr for proper type handling (scientific notation, NAs)
  constraint_raw <- readr::read_tsv(tmp_file, show_col_types = FALSE)

  # Check required columns exist
  required_cols <- c("gene", "mane_select", names(GNOMAD_TSV_COLUMN_MAP))
  missing_cols <- setdiff(required_cols, colnames(constraint_raw))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "[gnomAD enrichment] TSV missing expected columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }

  # [I7] Filter for MANE Select transcripts using robust coercion.
  # readr v2 infers TRUE/FALSE as logical, but future gnomAD versions could use
  # "true"/"false" strings or 1/0. Convert to character and compare lowercased.
  constraint_filtered <- constraint_raw %>%
    dplyr::filter(tolower(as.character(mane_select)) == "true") %>%
    dplyr::distinct(gene, .keep_all = TRUE)

  n_mane <- nrow(constraint_filtered)
  message(sprintf(
    "[gnomAD enrichment] Filtered to %d MANE Select genes from %d total rows",
    n_mane, nrow(constraint_raw)
  ))

  # [I8] Sanity check: if very few MANE Select genes found, the TSV format
  # may have changed silently. Fail loudly rather than writing NAs for everything.
  if (n_mane < GNOMAD_MIN_MANE_GENES) {
    stop(sprintf(
      "[gnomAD enrichment] Only %d MANE Select genes found (expected >= %d). The gnomAD TSV format may have changed.",
      n_mane, GNOMAD_MIN_MANE_GENES
    ))
  }

  # --- Step 3: Build JSON and join ---
  message("[gnomAD enrichment] Step 3/3: Building JSON and joining to HGNC tibble")
  if (!is.null(progress_fn)) {
    tryCatch(
      progress_fn("gnomad", "gnomAD: joining data", current = 3, total = total_steps),
      error = function(e) NULL
    )
  }

  # Select only the columns we need
  constraint_subset <- constraint_filtered %>%
    dplyr::select(gene, dplyr::all_of(names(GNOMAD_TSV_COLUMN_MAP)))

  # [O1] Vectorized JSON construction using sprintf instead of row-wise toJSON.
  # All 19 fields are numeric, so we can build JSON strings directly.
  # This replaces ~19,000 individual toJSON() calls with a single vectorized operation.
  json_fields <- GNOMAD_TSV_COLUMN_MAP # values are our field names
  tsv_cols <- names(GNOMAD_TSV_COLUMN_MAP) # keys are TSV column names

  # Build the sprintf format string: {"pLI":%s,"oe_lof":%s,...}
  json_template <- paste0(
    "{",
    paste(sprintf('"%s":%%s', json_fields), collapse = ","),
    "}"
  )

  # Extract the numeric columns as a list of character vectors for JSON embedding.
  # Use as.character() which preserves R's default formatting (scientific notation
  # for very small/large values like pLI = 1.5474e-34). This is valid JSON per RFC 8259.
  col_values <- lapply(tsv_cols, function(col) {
    vals <- as.numeric(constraint_subset[[col]])
    ifelse(is.na(vals), "null", as.character(vals))
  })

  # Apply sprintf vectorized across all rows
  constraint_json_vec <- do.call(sprintf, c(list(fmt = json_template), col_values))

  # [I5] Case-insensitive gene symbol lookup: normalize both sides to uppercase
  constraint_lookup <- setNames(constraint_json_vec, toupper(constraint_subset$gene))
  hgnc_tibble$gnomad_constraints <- unname(constraint_lookup[toupper(hgnc_tibble$symbol)])

  n_mapped <- sum(!is.na(hgnc_tibble$gnomad_constraints))
  message(sprintf(
    "[gnomAD enrichment] Complete. %d / %d genes had constraint data.",
    n_mapped, nrow(hgnc_tibble)
  ))

  return(hgnc_tibble)
}


#' Enrich HGNC tibble with AlphaFold model identifiers
#'
#' @description
#' Derives AlphaFold model identifiers from the `uniprot_ids` column in the
#' HGNC tibble. Uses the pattern `AF-{uniprot_id}-F1` with the first UniProt
#' ID when multiple are pipe-separated.
#'
#' @param hgnc_tibble A tibble from the HGNC update pipeline with at least
#'   a `uniprot_ids` column containing UniProt accessions (pipe-separated).
#'
#' @return The input tibble with an added `alphafold_id` column containing
#'   AlphaFold model identifiers (or NA for genes without UniProt IDs).
#'
#' @details
#' - No external API calls needed (pure string derivation)
#' - Handles missing/NA uniprot_ids -> NA
#' - Handles pipe-separated multiple IDs -> takes first
#' - Pattern: AF-{id}-F1 (e.g., AF-P41227-F1)
#'
#' @export
enrich_alphafold_ids <- function(hgnc_tibble) {
  message("[AlphaFold ID enrichment] Deriving AlphaFold IDs from UniProt accessions")

  # [M1] Use vapply (type-safe) instead of sapply
  hgnc_tibble$alphafold_id <- vapply(hgnc_tibble$uniprot_ids, function(uid) {
    if (is.na(uid) || is.null(uid) || nchar(trimws(uid)) == 0) {
      return(NA_character_)
    }

    # Take first UniProt ID if pipe-separated
    first_id <- trimws(strsplit(uid, "\\|")[[1]][1])

    if (is.na(first_id) || nchar(first_id) == 0) {
      return(NA_character_)
    }

    # Construct AlphaFold model identifier
    paste0("AF-", first_id, "-F1")
  }, character(1), USE.NAMES = FALSE)

  n_mapped <- sum(!is.na(hgnc_tibble$alphafold_id))
  message(sprintf(
    "[AlphaFold ID enrichment] Mapped %d / %d genes",
    n_mapped, nrow(hgnc_tibble)
  ))

  return(hgnc_tibble)
}
