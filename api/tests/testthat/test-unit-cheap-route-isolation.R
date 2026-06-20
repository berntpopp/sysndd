# tests/testthat/test-unit-cheap-route-isolation.R
#
# Static guard (#344): cheap routes (health, auth, statistics) must never call an
# external provider fetcher, so a slow upstream cannot leak into their latency.
# This locks in the categorical isolation the issue's acceptance criteria require.
#
# Pure test (no DB / no network) — runs on host.

cheap_route_files <- c(
  "health_endpoints.R",
  "authentication_endpoints.R",
  "statistics_endpoints.R"
)

test_that("cheap-route handlers never reference an external provider fetcher", {
  edir <- file.path(get_api_dir(), "endpoints")
  offenders <- character()
  for (f in cheap_route_files) {
    path <- file.path(edir, f)
    if (!file.exists(path)) next
    src <- readLines(path, warn = FALSE)
    # Strip comment lines so a doc mention can't trip the guard.
    src <- src[!grepl("^\\s*#", src)]
    pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)"
    hits <- grep(pattern, src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(f, ": ", trimws(hits)))
  }
  expect_identical(
    offenders, character(),
    info = paste(
      "Cheap route calls an external fetcher (would couple its latency to a slow upstream):",
      paste(offenders, collapse = " | ")
    )
  )
})

test_that("disease endpoint never references an external provider fetcher", {
  path <- file.path(get_api_dir(), "endpoints", "disease_mapping_endpoints.R")
  if (!file.exists(path)) skip("disease_mapping_endpoints.R not found")
  src <- readLines(path, warn = FALSE)
  src <- src[!grepl("^\\s*#", src)]
  pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)"
  hits <- grep(pattern, src, value = TRUE)
  expect_identical(
    hits, character(),
    info = paste("disease endpoint calls an external fetcher:", paste(hits, collapse = " | "))
  )
})

test_that("disease mapping repository never references an external provider fetcher", {
  path <- file.path(get_api_dir(), "functions", "disease-ontology-mapping-repository.R")
  if (!file.exists(path)) skip("disease-ontology-mapping-repository.R not found")
  src <- readLines(path, warn = FALSE)
  src <- src[!grepl("^\\s*#", src)]
  pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)"
  hits <- grep(pattern, src, value = TRUE)
  expect_identical(
    hits, character(),
    info = paste("disease mapping repository calls an external fetcher:", paste(hits, collapse = " | "))
  )
})
