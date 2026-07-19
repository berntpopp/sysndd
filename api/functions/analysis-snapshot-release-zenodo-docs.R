# api/functions/analysis-snapshot-release-zenodo-docs.R
#
# Doc-string builders for the analysis-snapshot RELEASE Zenodo packager
# (#573 Slice C / Task C1). Extracted from
# `analysis-snapshot-release-zenodo-package.R` (which guard-sources this
# file) to keep both files under the repo's 600-line soft ceiling -- mirrors
# the `comparisons-functions.R` / `comparisons-parsers.R` split.
#
# Every function here is pure (`str` in, `str` out) and mirrors one of the
# sibling `../nddscore/src/models/sysndd_export.py` doc builders
# (`_build_readme` / `_build_ingestion_notes` / `_build_schema_doc` /
# `_build_changelog` / `_build_citation_cff`), adapted to analysis-release
# content (no model performance metrics, no morbidscore/mantis scrubbing --
# analysis releases carry no private git-sha/model fields to begin with).
#
# Depends on `%||%` and `.analysis_release_zenodo_created_at_date()`, both
# defined in the sibling `analysis-snapshot-release-zenodo-package.R` (which
# always sources this file, never the other way around) -- resolved lazily
# at CALL time via the shared global sourcing environment, not at source
# time, so definition order across the two files does not matter.

.analysis_release_zenodo_docs_loaded <- TRUE

#' `README.md`: version/id/DOI header + a 4-step "Use" walkthrough.
analysis_release_zenodo_build_readme <- function(head, doi = NULL) {
  release_id <- as.character(head$release_id %||% "")[[1]]
  version <- as.character((head$source_data_version %||% head$release_version %||% release_id))[[1]]
  doi_text <- doi %||% "reserved Zenodo DOI to be added before publication"

  paste0(
    "# SysNDD analysis-snapshot release\n\n",
    sprintf("- Release ID: `%s`\n", release_id),
    sprintf("- Source data version: `%s`\n", version),
    sprintf("- DOI: %s\n\n", doi_text),
    "This dataset is an immutable, content-addressed export of a SysNDD public ",
    "analysis-snapshot release. It is a derived analysis product, not a copy of ",
    "the primary curated SysNDD evidence.\n\n",
    "## Use\n\n",
    "1. Extract the archive.\n",
    "2. Verify `checksums.sha256` at the archive root (and the nested ",
    "`analysis_snapshot_release/checksums.sha256`).\n",
    "3. Read `DATA_CARD.md` and `SCHEMA.md`.\n",
    "4. Import files from `analysis_snapshot_release/` using its own ",
    "`manifest.json` as the file index.\n"
  )
}

#' `DATA_CARD.md`: what each bundled file is, the layer set, how to verify.
#' Folds the intent of nddscore's `_build_ingestion_notes` since there is no
#' model to card here.
analysis_release_zenodo_build_data_card <- function(head) {
  release_id <- as.character(head$release_id %||% "")[[1]]
  layers <- head$manifest$layers %||% head$layers %||% list()

  layer_block <- if (length(layers) > 0) {
    layer_names <- vapply(layers, function(layer) {
      as.character(layer$analysis_type %||% "unknown")[[1]]
    }, character(1))
    paste(sprintf("- `%s`", layer_names), collapse = "\n")
  } else {
    paste(
      "- `functional_clusters`", "- `phenotype_clusters`",
      "- `phenotype_functional_correlations`",
      sep = "\n"
    )
  }

  paste0(
    "# Data Card\n\n",
    sprintf(
      "Release `%s` bundles the following analysis layers under ",
      release_id
    ),
    "`analysis_snapshot_release/`:\n\n",
    layer_block, "\n\n",
    "Each cluster layer directory contains `payload.json` (the served cluster ",
    "membership + validation) and, where applicable, `reproducibility.json` (the ",
    "raw artifact needed to independently recompute modularity/silhouette). The ",
    "phenotype-functional correlation layer has a `payload.json` only.\n\n",
    "`analysis_snapshot_release/manifest.json` lists every bundled file with its ",
    "size and sha256; `checksums.sha256` (both at the archive root and inside ",
    "`analysis_snapshot_release/`) lets any consumer verify byte-for-byte ",
    "integrity with `sha256sum -c`.\n\n",
    "Scope: derived cluster analysis over approved public SysNDD curation data. ",
    "This is not raw curated evidence and not a clinical diagnostic product.\n"
  )
}

#' `SCHEMA.md`: the manifest/layers structure and the lineage-anchor vs
#' reproducibility-hash distinction, stated correctly (payload_hash/
#' input_hash/snapshot_id are lineage anchors, NOT a hash of payload.json).
analysis_release_zenodo_build_schema_doc <- function(head) {
  paste0(
    "# Schema\n\n",
    "`analysis_snapshot_release/manifest.json` is the authoritative file index. ",
    "For each layer it records `analysis_type`, `input_hash`, `payload_hash`, ",
    "`reproducibility_hash` (when the layer has a reproducibility bundle), and ",
    "`dependencies`. For each bundled file it records `path`, `bytes`, and ",
    "`sha256`.\n\n",
    "## Lineage anchors vs the reproducibility hash\n\n",
    "`payload_hash`, `input_hash`, and `snapshot_id` are cross-checkable lineage ",
    "anchors against the live `meta.snapshot.{payload_hash,input_hash,snapshot_id}` ",
    "on the corresponding `/api/analysis/*` endpoint. They are NOT a hash of this ",
    "release's own `payload.json` file -- the served payload round-trips through ",
    "fixed-precision database columns before the release freezes it, so a ",
    "byte-for-byte reconstruction is neither guaranteed nor attempted.\n\n",
    "By contrast, for each cluster layer with a reproducibility bundle, ",
    "`sha256(reproducibility.json) == reproducibility_hash` exactly.\n"
  )
}

#' `CHANGELOG.md`: one `## {version} - {date}` section (no accumulation --
#' each package rebuild overwrites the file with a single-entry changelog,
#' mirroring nddscore's `_build_changelog`).
analysis_release_zenodo_build_changelog <- function(head, version) {
  release_id <- as.character(head$release_id %||% "")[[1]]
  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
  date_suffix <- if (nzchar(release_date)) sprintf(" - %s", release_date) else ""

  paste0(
    "# Changelog\n\n",
    sprintf("## %s%s\n\n", resolved_version, date_suffix),
    sprintf("- Initial Zenodo dataset package for analysis-snapshot release `%s`.\n", release_id),
    "- Bundles the functional clusters, phenotype clusters, and ",
    "phenotype-functional correlation layers, plus their manifest and ",
    "checksums.\n"
  )
}

#' `CITATION.cff`: CFF 1.2.0, `type: dataset`, optional `doi:`, single author
#' block with ORCID, `license: CC-BY-4.0`.
analysis_release_zenodo_build_citation_cff <- function(head, version, doi = NULL) {
  release_id <- as.character(head$release_id %||% "")[[1]]
  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
  date_line <- if (nzchar(release_date)) release_date else format(Sys.Date())
  doi_block <- if (!is.null(doi) && nzchar(as.character(doi)[[1]])) {
    sprintf("doi: \"%s\"\n", as.character(doi)[[1]])
  } else {
    ""
  }

  paste0(
    "cff-version: 1.2.0\n",
    "message: \"If you use this SysNDD analysis-snapshot release, please cite it ",
    "as below.\"\n",
    "type: dataset\n",
    sprintf("title: \"SysNDD analysis-snapshot release %s\"\n", release_id),
    sprintf("version: \"%s\"\n", resolved_version),
    sprintf("date-released: \"%s\"\n", date_line),
    doi_block,
    "authors:\n",
    "  - family-names: Popp\n",
    "    given-names: Bernt\n",
    "    orcid: \"https://orcid.org/0000-0002-3679-1081\"\n",
    "keywords:\n",
    "  - SysNDD\n",
    "  - neurodevelopmental disorders\n",
    "  - clustering\n",
    "license: CC-BY-4.0\n"
  )
}
