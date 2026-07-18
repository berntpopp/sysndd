# api/functions/clustering-gene-universe.R
#
# Category-selected clustering gene-universe resolver (#574 D1).
#
# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
# universe from curated SysNDD confidence categories instead of the default
# "all NDD genes" set. This file builds ONLY the resolver + provenance
# helpers; the submit service and durable handler wiring is done later.
#
# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
# same gene also has OTHER-category entities. This mirrors
# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
# added `category %in% selector` filter -- it deliberately does NOT use
# `select_network_gene_category()`, which is a gene-level display-label
# aggregator for node coloring, not a universe filter.
#
# Category validation is live against `ndd_entity_status_categories_list
# WHERE is_active = 1` -- no hardcoded category strings, and no category
# string is interpolated into SQL (dbplyr `%in%` + an allowlist pre-check).

# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
# selector returns character(0), which the resolver rejects with 400 -- it must
# never fall through to the all-NDD default.
clustering_normalize_category_filter <- function(category_filter) {
  if (is.null(category_filter)) return(NULL)
  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
  vals <- vals[nzchar(vals)]
  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
  sort(unique(vals))
}

clustering_gene_list_sha256 <- function(hgnc_ids) {
  digest::digest(
    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
    algo = "sha256", serialize = FALSE
  )
}

clustering_resolve_category_universe <- function(category_filter, conn = pool) {
  selector <- clustering_normalize_category_filter(category_filter)

  if (is.null(selector)) {
    # Absent -> preserve the exact current default ordering for cache parity.
    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
  }
  if (length(selector) == 0L) {
    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
  }

  active <- conn %>%
    dplyr::tbl("ndd_entity_status_categories_list") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::select(category) %>%
    dplyr::collect() %>%
    dplyr::pull(category)
  unknown <- setdiff(selector, active)
  if (length(unknown) > 0L) {
    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
    stop_for_bad_request(sprintf(
      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
    ))
  }

  hgnc_ids <- conn %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::arrange(entity_id) %>%
    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
    dplyr::select(hgnc_id) %>%
    dplyr::collect() %>%
    unique() %>%
    dplyr::pull(hgnc_id)

  if (length(hgnc_ids) < 2L) {
    stop_for_bad_request(sprintf(
      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
      paste(selector, collapse = ","), length(hgnc_ids)
    ))
  }
  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
}
