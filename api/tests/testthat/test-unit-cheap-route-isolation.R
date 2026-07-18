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

# Immutable analysis-snapshot RELEASES (#573 Slice A / Task A8). Both the
# public read routes (`releases*` in analysis_endpoints.R) and the
# Administrator build/publish/DOI/delete routes (admin_analysis_snapshot_
# endpoints.R) only ever read/write the DB-only release tables added by
# migration 045 -- they never call an external provider. Unlike the
# whole-file checks above, `analysis_endpoints.R` and
# admin_analysis_snapshot_endpoints.R also carry PRE-EXISTING non-release
# routes, so this scans just the dedicated release function/service files
# (which contain nothing but release logic) rather than the whole endpoint
# files.
release_source_files <- c(
  "functions/analysis-snapshot-release-manifest.R",
  "functions/analysis-snapshot-release-repository.R",
  "functions/analysis-snapshot-release-materialize.R",
  "functions/analysis-snapshot-release.R",
  "services/analysis-snapshot-release-service.R"
)

test_that("analysis-snapshot release build/read files never reference an external provider fetcher", {
  offenders <- character()
  for (rel in release_source_files) {
    path <- file.path(get_api_dir(), rel)
    if (!file.exists(path)) next
    src <- readLines(path, warn = FALSE)
    src <- src[!grepl("^\\s*#", src)]
    pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)|httr2::|make_external_request"
    hits <- grep(pattern, src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(rel, ": ", trimws(hits)))
  }
  expect_identical(
    offenders, character(),
    info = paste(
      "Analysis-snapshot release file calls an external fetcher (releases must stay DB-only):",
      paste(offenders, collapse = " | ")
    )
  )
})

test_that("the public releases* routes in analysis_endpoints.R never reference an external provider fetcher", {
  path <- file.path(get_api_dir(), "endpoints", "analysis_endpoints.R")
  if (!file.exists(path)) skip("analysis_endpoints.R not found")
  src <- readLines(path, warn = FALSE)
  # Isolate the "RELEASES" section (bounded by its own header comment through
  # end-of-file, since it is the last block in the file) so a pre-existing,
  # non-release route elsewhere in this shared endpoint file cannot mask a
  # release regression under an unrelated diff.
  start <- grep("Analysis-snapshot RELEASES: public read routes", src)
  if (length(start) == 0L) skip("releases section marker not found in analysis_endpoints.R")
  section <- src[start[[1]]:length(src)]
  section <- section[!grepl("^\\s*#", section)]
  pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)|httr2::|make_external_request"
  hits <- grep(pattern, section, value = TRUE)
  expect_identical(
    hits, character(),
    info = paste("public releases* routes call an external fetcher:", paste(hits, collapse = " | "))
  )
})

test_that("admin release routes in admin_analysis_snapshot_endpoints.R never reference an external provider fetcher", {
  path <- file.path(get_api_dir(), "endpoints", "admin_analysis_snapshot_endpoints.R")
  if (!file.exists(path)) skip("admin_analysis_snapshot_endpoints.R not found")
  src <- readLines(path, warn = FALSE)
  src <- src[!grepl("^\\s*#", src)]
  pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)|httr2::|make_external_request"
  hits <- grep(pattern, src, value = TRUE)
  expect_identical(
    hits, character(),
    info = paste(
      "admin_analysis_snapshot_endpoints.R (incl. release routes) calls an external fetcher:",
      paste(hits, collapse = " | ")
    )
  )
})
