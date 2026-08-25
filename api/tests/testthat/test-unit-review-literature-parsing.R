# #635 -- the literature block -> publications tibble contract.
#
# Two things depend on this being exactly right, and neither is obvious from the code:
#
#  1. ZERO ROWS MEANS "REMOVE EVERYTHING". `review_write_mutate()` routes an empty
#     result on PUT to `publication_replace_for_review()` with an empty tibble, which
#     DELETEs every join row for the review. So the empty case is not a degenerate
#     no-op; it is the destructive one, and it is exactly what the browser sends when a
#     curator clears the Publications field.
#  2. THE TYPE LABEL IS POSITIONAL. `bind_rows(.id = )` labels rows by which frame they
#     came from -- "1" additional references, "2" GeneReviews -- NOT by any value in
#     the data. If a zero-row first frame shifted the second frame's label to "1",
#     removing every additional reference would silently re-file the surviving
#     GeneReviews as additional references. It does not, but only a test says so.
source_api_file("functions/review-literature-parsing.R", local = FALSE)

# jsonlite (plumber's body parser) renders a JSON array of strings as a character
# vector and `[]` as an empty list; both shapes are exercised below.

test_that("both lists populated map to their own types", {
  result <- review_write_literature_to_publications(
    list(
      additional_references = c("PMID:1111111", "PMID:2222222"),
      gene_review = c("PMID:9999999")
    )
  )

  expect_equal(nrow(result), 3L)
  expect_equal(
    result$publication_type,
    c("additional_references", "additional_references", "gene_review")
  )
  expect_equal(
    result$publication_id,
    c("PMID:1111111", "PMID:2222222", "PMID:9999999")
  )
})

test_that("only additional references keeps the additional_references label", {
  result <- review_write_literature_to_publications(
    list(additional_references = c("PMID:1111111"), gene_review = list())
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$publication_type, "additional_references")
  expect_equal(result$publication_id, "PMID:1111111")
})

test_that("only GeneReviews stays gene_review despite an empty leading frame", {
  # THE regression this file exists for: an empty `additional_references` must not
  # shift the GeneReviews rows into position 1 and relabel them.
  result <- review_write_literature_to_publications(
    list(additional_references = list(), gene_review = c("PMID:9999999"))
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$publication_type, "gene_review")
  expect_equal(result$publication_id, "PMID:9999999")
})

test_that("both lists empty yields zero rows with the right columns", {
  result <- review_write_literature_to_publications(
    list(additional_references = list(), gene_review = list())
  )

  expect_equal(nrow(result), 0L)
  expect_equal(names(result), c("publication_id", "publication_type"))
  expect_type(result$publication_id, "character")
  expect_type(result$publication_type, "character")
})

test_that("an absent, NULL or empty literature block yields zero rows", {
  for (literature in list(NULL, list(), list(additional_references = NULL, gene_review = NULL))) {
    result <- review_write_literature_to_publications(literature)
    expect_equal(nrow(result), 0L)
    expect_equal(names(result), c("publication_id", "publication_type"))
  }
})

test_that("whitespace inside a PMID is stripped and duplicates collapse", {
  result <- review_write_literature_to_publications(
    list(
      additional_references = c("PMID: 1111111", "PMID:1111111"),
      gene_review = list()
    )
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$publication_id, "PMID:1111111")
})

test_that("the same PMID in both lists leaves the parser as two rows", {
  # This parser's `distinct()` is over the whole row, so a PMID a curator typed into
  # BOTH tag widgets survives here as two rows -- one per type. That is the parser's
  # contract and nothing more: it does NOT reach the join table's `review_triple`
  # unique key on (review_id, entity_id, publication_id), because
  # `review_write_prepare()` immediately passes this through
  # `publication_write_classify_genereviews()`, whose
  # `dplyr::distinct(publication_id, .keep_all = TRUE)` collapses it to one row (and
  # re-derives the type from `genereviews_from_pmid()` anyway). Pinned so a future
  # change to either side is visible; corrected after adversarial review, which caught
  # this comment claiming a unique-key violation that cannot happen.
  result <- review_write_literature_to_publications(
    list(
      additional_references = c("PMID:1111111"),
      gene_review = c("PMID:1111111")
    )
  )

  expect_equal(nrow(result), 2L)
  expect_equal(result$publication_type, c("additional_references", "gene_review"))
})
