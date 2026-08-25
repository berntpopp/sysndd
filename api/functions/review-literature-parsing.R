# functions/review-literature-parsing.R
#
# Turns a review request body's `literature` block into the two-column publications
# tibble that `svc_review_write()` consumes.
#
# Extracted verbatim from the inline block in `endpoints/review_endpoints.R` (#635) so
# it can be tested directly. The shape it produces decides whether a curator's edit is
# honoured: `review_write_mutate()` routes a zero-row result on PUT to
# `publication_replace_for_review()` with an empty tibble, i.e. "delete them all", and
# a mislabelled row would move a publication between the two lists.

#' Parse a review body's `literature` block into a publications tibble
#'
#' @param literature The `literature` object from `review_json` — a list with
#'   `additional_references` and/or `gene_review` entries, either of which may be
#'   absent, `NULL`, or an empty array. `jsonlite` (via plumber's body parser)
#'   renders a JSON array of strings as a character vector and `[]` as `list()`.
#'
#' @return A tibble with `publication_id` (whitespace stripped) and `publication_type`
#'   (`"additional_references"` | `"gene_review"`), distinct, possibly zero rows.
#'
#' @details
#' The `publication_type` comes from `dplyr::bind_rows(.id = )`, which labels rows by
#' the POSITION of the frame they came from — `"1"` for additional references, `"2"`
#' for GeneReviews. That positional contract is the fragile part and the reason this
#' function is unit-tested across all four populated/empty combinations: a zero-row
#' first frame must NOT shift the second frame's label to `"1"`, or removing every
#' additional reference would silently re-file the surviving GeneReviews as additional
#' references. `bind_rows()` retains the zero-row frame's position, so it does not —
#' but nothing except a test says so.
#'
#' @keywords internal
review_write_literature_to_publications <- function(literature) {
  empty <- tibble::tibble(
    publication_id = character(),
    publication_type = character()
  )

  if (length(purrr::compact(literature)) == 0L) {
    return(empty)
  }

  dplyr::bind_rows(
    tibble::as_tibble(purrr::compact(literature$additional_references)),
    tibble::as_tibble(purrr::compact(literature$gene_review)),
    .id = "publication_type"
  ) |>
    dplyr::transmute(
      publication_id = gsub("\\s+", "", value),
      publication_type = dplyr::case_when(
        publication_type == "1" ~ "additional_references",
        publication_type == "2" ~ "gene_review"
      )
    ) |>
    dplyr::distinct()
}
