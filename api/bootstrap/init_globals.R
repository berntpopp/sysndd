## -------------------------------------------------------------------##
# api/bootstrap/init_globals.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Produces the small set of top-level values that endpoints and
# filters still look up by bare name in .GlobalEnv:
#   - serializers (json + xlsx response serializers)
#   - inheritance_input_allowed (allow-list used by /entity routes)
#   - output_columns_allowed (allow-list used by list/search routes)
#   - user_status_allowed (allow-list used by admin/user routes)
#   - version_json / sysndd_api_version (from version_spec.json)
#
# These were super-assignments in pre-D6 start_sysndd_api.R. The
# composer binds the return value at top level with `<-`.
## -------------------------------------------------------------------##

#' Resolve the small set of top-level constants the API exposes.
#'
#' @param version_spec_path Path to `version_spec.json`.
#' @return A named list the composer unpacks at top level.
#' @export
bootstrap_init_globals <- function(version_spec_path = "version_spec.json") {
  serializers <- list(
    "json" = plumber::serializer_json(),
    "xlsx" = plumber::serializer_content_type(
      type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
  )

  inheritance_input_allowed <- c(
    "X-linked",
    "Autosomal dominant",
    "Autosomal recessive",
    "Other",
    "All"
  )

  output_columns_allowed <- c(
    "category",
    "inheritance",
    "symbol",
    "hgnc_id",
    "entrez_id",
    "ensembl_gene_id",
    "ucsc_id",
    "bed_hg19",
    "bed_hg38"
  )

  user_status_allowed <- c("Administrator", "Curator", "Reviewer", "Viewer")

  version_json <- jsonlite::fromJSON(version_spec_path)

  list(
    serializers = serializers,
    inheritance_input_allowed = inheritance_input_allowed,
    output_columns_allowed = output_columns_allowed,
    user_status_allowed = user_status_allowed,
    version_json = version_json,
    sysndd_api_version = version_json$version
  )
}
