#!/usr/bin/env Rscript
# api/scripts/endpoint-inventory.R
#
# Extracts all routes from the SysNDD API endpoint files and generates a verification checklist.
#
# Usage:
#   Rscript scripts/endpoint-inventory.R
#
# Output:
#   api/results/endpoint-checklist.csv - CSV with all endpoints for verification
#
# This script must be run from the api/ directory.

## -------------------------------------------------------------------##
# Setup and validation
## -------------------------------------------------------------------##

# Ensure we're in the api/ directory
if (!file.exists("start_sysndd_api.R")) {
  stop("Error: This script must be run from the api/ directory.\n",
       "Current directory: ", getwd())
}

cat("Extracting endpoint routes from endpoint files...\n")

## -------------------------------------------------------------------##
# Define mount points from start_sysndd_api.R
## -------------------------------------------------------------------##

# Mount points in order from start_sysndd_api.R (lines 330-350)
mount_map <- list(
  "/api/entity" = "endpoints/entity_endpoints.R",
  "/api/review" = "endpoints/review_endpoints.R",
  "/api/re_review" = "endpoints/re_review_endpoints.R",
  "/api/publication" = "endpoints/publication_endpoints.R",
  "/api/gene" = "endpoints/gene_endpoints.R",
  "/api/ontology" = "endpoints/ontology_endpoints.R",
  "/api/phenotype" = "endpoints/phenotype_endpoints.R",
  "/api/status" = "endpoints/status_endpoints.R",
  "/api/panels" = "endpoints/panels_endpoints.R",
  "/api/comparisons" = "endpoints/comparisons_endpoints.R",
  "/api/analysis" = "endpoints/analysis_endpoints.R",
  "/api/hash" = "endpoints/hash_endpoints.R",
  "/api/search" = "endpoints/search_endpoints.R",
  "/api/list" = "endpoints/list_endpoints.R",
  "/api/logs" = "endpoints/logging_endpoints.R",
  "/api/user" = "endpoints/user_endpoints.R",
  "/api/auth" = "endpoints/authentication_endpoints.R",
  "/api/admin" = "endpoints/admin_endpoints.R",
  "/api/external" = "endpoints/external_endpoints.R",
  "/api/statistics" = "endpoints/statistics_endpoints.R",
  "/api/variant" = "endpoints/variant_endpoints.R"
)

## -------------------------------------------------------------------##
# Extract routes from each endpoint file
## -------------------------------------------------------------------##

all_endpoints <- list()

for (mount_point in names(mount_map)) {
  endpoint_file <- mount_map[[mount_point]]

  if (!file.exists(endpoint_file)) {
    warning(sprintf("Endpoint file not found: %s", endpoint_file))
    next
  }

  # Read the file
  file_content <- readLines(endpoint_file, warn = FALSE)

  # Find lines with plumber annotations: #* @get, #* @post, etc.
  method_lines <- grep("^#\\*\\s*@(get|post|put|delete|patch)\\s+", file_content, value = TRUE)

  # Extract method and path
  for (line in method_lines) {
    # Parse: #* @METHOD PATH
    match <- regexec("^#\\*\\s*@(get|post|put|delete|patch)\\s+(.*)$", line)
    if (match[[1]][1] != -1) {
      captures <- regmatches(line, match)[[1]]
      method <- toupper(captures[2])
      path <- trimws(captures[3])

      # Build full path: mount_point + path
      # Handle special cases: "/" stays as mount_point, others append
      full_path <- if (path == "/" || path == "") {
        paste0(mount_point, "/")
      } else {
        paste0(mount_point, path)
      }

      # Determine if auth is required (heuristic)
      # GET endpoints typically public unless /admin, /user, /auth
      # POST/PUT/DELETE/PATCH typically require auth
      auth_required <- if (method == "GET") {
        grepl("/admin|/user|/auth", full_path)
      } else {
        TRUE
      }

      all_endpoints[[length(all_endpoints) + 1]] <- list(
        path = full_path,
        method = method,
        auth_required = auth_required,
        verified = FALSE,
        notes = ""
      )
    }
  }
}

# Convert to dataframe
endpoint_data <- do.call(rbind, lapply(all_endpoints, function(x) {
  data.frame(
    path = x$path,
    methods = x$method,
    auth_required = x$auth_required,
    verified = x$verified,
    notes = x$notes,
    stringsAsFactors = FALSE
  )
}))

# Aggregate multiple methods for same path
if (nrow(endpoint_data) > 0) {
  endpoint_data <- aggregate(
    methods ~ path + auth_required + verified + notes,
    data = endpoint_data,
    FUN = function(x) paste(unique(x), collapse = ", ")
  )
}

## -------------------------------------------------------------------##
# Generate summary statistics
## -------------------------------------------------------------------##

cat("\n=== Endpoint Inventory Summary ===\n")
cat(sprintf("Total endpoints: %d\n", nrow(endpoint_data)))
cat(sprintf("Public endpoints (no auth): %d\n", sum(!endpoint_data$auth_required)))
cat(sprintf("Protected endpoints (auth required): %d\n\n", sum(endpoint_data$auth_required)))

# Count endpoints by mount point
mount_points <- unique(sub("^(/api/[^/]+).*", "\\1", endpoint_data$path))
cat("Mount points found:\n")
for (mp in sort(mount_points)) {
  count <- sum(grepl(paste0("^", mp), endpoint_data$path))
  cat(sprintf("  %s: %d endpoints\n", mp, count))
}

## -------------------------------------------------------------------##
# Write CSV output
## -------------------------------------------------------------------##

# Create results directory if it doesn't exist
results_dir <- "results"
if (!dir.exists(results_dir)) {
  cat(sprintf("\nCreating %s/ directory...\n", results_dir))
  dir.create(results_dir, recursive = TRUE)
}

output_file <- file.path(results_dir, "endpoint-checklist.csv")
cat(sprintf("\nWriting checklist to %s...\n", output_file))

write.csv(endpoint_data, output_file, row.names = FALSE)

cat(sprintf("\n✓ Successfully created endpoint checklist with %d entries\n", nrow(endpoint_data)))
cat(sprintf("✓ File: %s\n", output_file))
