# api/endpoints/external_endpoints.R
#
# This file contains all External-related endpoints extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions where
# possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Make sure to source any required helpers or libraries at the top if needed.

## -------------------------------------------------------------------##
## External endpoints
## -------------------------------------------------------------------##

#* Submit URL to Internet Archive
#*
#* This endpoint takes a SysNDD URL and submits it to the Internet Archive
#* (a.k.a. the Wayback Machine) for archiving.
#*
#* # `Details`
#* Validates the provided URL against a base URL (dw$archive_base_url).
#* If valid, it calls the helper function `post_url_archive()`.
#*
#* # `Return`
#* Returns a status of the archiving operation. If invalid or missing,
#* returns an error with HTTP status 400.
#*
#* @tag external
#* @serializer json list(na="string")
#*
#* @param parameter_url The URL to be archived.
#* @param capture_screenshot Whether to capture a screenshot (on/off).
#*
#* @response 200 OK if successful.
#* @response 400 Bad Request if the URL is invalid or missing.
#*
#* @get internet_archive
function(req, res, parameter_url, capture_screenshot = "on") {
  # Check if provided URL is valid
  url_valid <- str_detect(parameter_url, dw$archive_base_url)

  if (!url_valid) {
    res$status <- 400
    res$body <- jsonlite::toJSON(
      auto_unbox = TRUE,
      list(
        status = 400,
        message = "Required 'url' parameter not provided or not valid."
      )
    )
    return(res)
  } else {
    # Block to generate and post the external archive request
    response_archive <- post_url_archive(parameter_url, capture_screenshot)
    return(response_archive)
  }
}

## -------------------------------------------------------------------##
## External proxy endpoints for genomic data sources
## -------------------------------------------------------------------##

#* Get gnomAD constraint scores for a gene
#*
#* Returns pLI, LOEUF, mis_z and other constraint metrics from gnomAD v4.
#* Data is cached for 30 days.
#*
#* @tag external-proxy
#* @serializer unboxedJSON
#* @param symbol Gene symbol (e.g., "BRCA1")
#* @response 200 Constraint scores for the gene
#* @response 400 Invalid gene symbol
#* @response 404 Gene not found in gnomAD
#* @response 503 gnomAD API unavailable
#* @get gnomad/constraints/<symbol>
function(symbol, res) {
  # Validate input
  if (!validate_gene_symbol(symbol)) {
    res$status <- 400L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "gnomad",
      sprintf("Invalid gene symbol: %s", symbol),
      400L,
      paste0("/api/external/gnomad/constraints/", symbol)
    ))
  }

  # Fetch data (memoised)
  result <- fetch_gnomad_constraints_mem(symbol)

  # Handle not found
  if (is.list(result) && isTRUE(result$found == FALSE)) {
    res$status <- 404L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "gnomad",
      sprintf("Gene %s not found in gnomAD", symbol),
      404L,
      paste0("/api/external/gnomad/constraints/", symbol)
    ))
  }

  # Handle error
  if (is.list(result) && isTRUE(result$error)) {
    res$status <- 503L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "gnomad",
      result$message %||% "gnomAD API unavailable",
      503L,
      paste0("/api/external/gnomad/constraints/", symbol)
    ))
  }

  # Success
  return(result)
}

#* Get gnomAD ClinVar variants for a gene
#*
#* Returns pathogenic and likely pathogenic variants from gnomAD's ClinVar integration.
#* Data is cached for 7 days.
#*
#* @tag external-proxy
#* @serializer unboxedJSON
#* @param symbol Gene symbol (e.g., "BRCA1")
#* @response 200 ClinVar variants for the gene
#* @response 400 Invalid gene symbol
#* @response 404 Gene not found in gnomAD
#* @response 503 gnomAD API unavailable
#* @get gnomad/variants/<symbol>
function(symbol, res) {
  # Validate input
  if (!validate_gene_symbol(symbol)) {
    res$status <- 400L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "gnomad",
      sprintf("Invalid gene symbol: %s", symbol),
      400L,
      paste0("/api/external/gnomad/variants/", symbol)
    ))
  }

  # Fetch data (memoised)
  result <- fetch_gnomad_clinvar_variants_mem(symbol)

  # Handle not found
  if (is.list(result) && isTRUE(result$found == FALSE)) {
    res$status <- 404L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "gnomad",
      sprintf("Gene %s not found in gnomAD", symbol),
      404L,
      paste0("/api/external/gnomad/variants/", symbol)
    ))
  }

  # Handle error
  if (is.list(result) && isTRUE(result$error)) {
    res$status <- 503L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "gnomad",
      result$message %||% "gnomAD API unavailable",
      503L,
      paste0("/api/external/gnomad/variants/", symbol)
    ))
  }

  # Success
  return(result)
}

#* Get UniProt protein domains for a gene
#*
#* Returns protein domain architecture from UniProt including Pfam, SMART, and InterPro domains.
#* Data is cached for 14 days.
#*
#* @tag external-proxy
#* @serializer unboxedJSON
#* @param symbol Gene symbol (e.g., "BRCA1")
#* @response 200 Protein domains for the gene
#* @response 400 Invalid gene symbol
#* @response 404 Gene not found in UniProt
#* @response 503 UniProt API unavailable
#* @get uniprot/domains/<symbol>
function(symbol, res) {
  # Validate input
  if (!validate_gene_symbol(symbol)) {
    res$status <- 400L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "uniprot",
      sprintf("Invalid gene symbol: %s", symbol),
      400L,
      paste0("/api/external/uniprot/domains/", symbol)
    ))
  }

  # Fetch data (memoised)
  result <- fetch_uniprot_domains_mem(symbol)

  # Handle not found
  if (is.list(result) && isTRUE(result$found == FALSE)) {
    res$status <- 404L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "uniprot",
      sprintf("Gene %s not found in UniProt", symbol),
      404L,
      paste0("/api/external/uniprot/domains/", symbol)
    ))
  }

  # Handle error
  if (is.list(result) && isTRUE(result$error)) {
    res$status <- 503L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "uniprot",
      result$message %||% "UniProt API unavailable",
      503L,
      paste0("/api/external/uniprot/domains/", symbol)
    ))
  }

  # Success
  return(result)
}

#* Get Ensembl gene structure for a gene
#*
#* Returns gene coordinates, transcripts, exons, and UTR regions from Ensembl REST API.
#* Data is cached for 14 days.
#*
#* @tag external-proxy
#* @serializer unboxedJSON
#* @param symbol Gene symbol (e.g., "BRCA1")
#* @response 200 Gene structure information
#* @response 400 Invalid gene symbol
#* @response 404 Gene not found in Ensembl
#* @response 503 Ensembl API unavailable
#* @get ensembl/structure/<symbol>
function(symbol, res) {
  # Validate input
  if (!validate_gene_symbol(symbol)) {
    res$status <- 400L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "ensembl",
      sprintf("Invalid gene symbol: %s", symbol),
      400L,
      paste0("/api/external/ensembl/structure/", symbol)
    ))
  }

  # Fetch data (memoised)
  result <- fetch_ensembl_gene_structure_mem(symbol)

  # Handle not found
  if (is.list(result) && isTRUE(result$found == FALSE)) {
    res$status <- 404L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "ensembl",
      sprintf("Gene %s not found in Ensembl", symbol),
      404L,
      paste0("/api/external/ensembl/structure/", symbol)
    ))
  }

  # Handle error
  if (is.list(result) && isTRUE(result$error)) {
    res$status <- 503L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "ensembl",
      result$message %||% "Ensembl API unavailable",
      503L,
      paste0("/api/external/ensembl/structure/", symbol)
    ))
  }

  # Success
  return(result)
}

#* Get AlphaFold protein structure prediction for a gene
#*
#* Returns AlphaFold 3D structure prediction URLs and confidence scores.
#* Data is cached for 30 days.
#*
#* @tag external-proxy
#* @serializer unboxedJSON
#* @param symbol Gene symbol (e.g., "BRCA1")
#* @response 200 AlphaFold structure information
#* @response 400 Invalid gene symbol
#* @response 404 Gene not found in AlphaFold database
#* @response 503 AlphaFold API unavailable
#* @get alphafold/structure/<symbol>
function(symbol, res) {
  # Validate input
  if (!validate_gene_symbol(symbol)) {
    res$status <- 400L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "alphafold",
      sprintf("Invalid gene symbol: %s", symbol),
      400L,
      paste0("/api/external/alphafold/structure/", symbol)
    ))
  }

  # Fetch data (memoised)
  result <- fetch_alphafold_structure_mem(symbol)

  # Handle not found
  if (is.list(result) && isTRUE(result$found == FALSE)) {
    res$status <- 404L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "alphafold",
      sprintf("Gene %s not found in AlphaFold database", symbol),
      404L,
      paste0("/api/external/alphafold/structure/", symbol)
    ))
  }

  # Handle error
  if (is.list(result) && isTRUE(result$error)) {
    res$status <- 503L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "alphafold",
      result$message %||% "AlphaFold API unavailable",
      503L,
      paste0("/api/external/alphafold/structure/", symbol)
    ))
  }

  # Success
  return(result)
}

#* Get MGI mouse phenotypes for a gene
#*
#* Returns mouse model phenotypes from Mouse Genome Informatics database.
#* Data is cached for 14 days.
#*
#* @tag external-proxy
#* @serializer unboxedJSON
#* @param symbol Gene symbol (e.g., "BRCA1")
#* @response 200 Mouse phenotype information
#* @response 400 Invalid gene symbol
#* @response 404 Gene not found in MGI
#* @response 503 MGI API unavailable
#* @get mgi/phenotypes/<symbol>
function(symbol, res) {
  # Validate input
  if (!validate_gene_symbol(symbol)) {
    res$status <- 400L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "mgi",
      sprintf("Invalid gene symbol: %s", symbol),
      400L,
      paste0("/api/external/mgi/phenotypes/", symbol)
    ))
  }

  # Fetch data (memoised)
  result <- fetch_mgi_phenotypes_mem(symbol)

  # Handle not found
  if (is.list(result) && isTRUE(result$found == FALSE)) {
    res$status <- 404L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "mgi",
      sprintf("Gene %s not found in MGI", symbol),
      404L,
      paste0("/api/external/mgi/phenotypes/", symbol)
    ))
  }

  # Handle error
  if (is.list(result) && isTRUE(result$error)) {
    res$status <- 503L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "mgi",
      result$message %||% "MGI API unavailable",
      503L,
      paste0("/api/external/mgi/phenotypes/", symbol)
    ))
  }

  # Success
  return(result)
}

#* Get RGD rat phenotypes for a gene
#*
#* Returns rat model phenotypes from Rat Genome Database.
#* Data is cached for 14 days.
#*
#* @tag external-proxy
#* @serializer unboxedJSON
#* @param symbol Gene symbol (e.g., "BRCA1")
#* @response 200 Rat phenotype information
#* @response 400 Invalid gene symbol
#* @response 404 Gene not found in RGD
#* @response 503 RGD API unavailable
#* @get rgd/phenotypes/<symbol>
function(symbol, res) {
  # Validate input
  if (!validate_gene_symbol(symbol)) {
    res$status <- 400L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "rgd",
      sprintf("Invalid gene symbol: %s", symbol),
      400L,
      paste0("/api/external/rgd/phenotypes/", symbol)
    ))
  }

  # Fetch data (memoised)
  result <- fetch_rgd_phenotypes_mem(symbol)

  # Handle not found
  if (is.list(result) && isTRUE(result$found == FALSE)) {
    res$status <- 404L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "rgd",
      sprintf("Gene %s not found in RGD", symbol),
      404L,
      paste0("/api/external/rgd/phenotypes/", symbol)
    ))
  }

  # Handle error
  if (is.list(result) && isTRUE(result$error)) {
    res$status <- 503L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error(
      "rgd",
      result$message %||% "RGD API unavailable",
      503L,
      paste0("/api/external/rgd/phenotypes/", symbol)
    ))
  }

  # Success
  return(result)
}

## External endpoints
## -------------------------------------------------------------------##
