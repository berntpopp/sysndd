# Publication metadata preparation for short caller-owned write transactions.
#
# This module resolves missing PubMed/GeneReviews rows before a review save
# starts its database transaction. Persistence stays separate so a slow upstream
# can never hold review-row locks.

publication_write_classify_genereviews <- function(publications) {
  if (is.null(publications)) {
    return(tibble::tibble(
      publication_id = character(),
      publication_type = character()
    ))
  }

  publications <- tibble::as_tibble(publications)
  if (nrow(publications) == 0L) {
    return(tibble::tibble(
      publication_id = character(),
      publication_type = character()
    ))
  }

  required <- c("publication_id", "publication_type")
  missing <- base::setdiff(required, names(publications))
  if (length(missing) > 0L) {
    stop_for_bad_request(
      paste("Missing publication field(s):", paste(missing, collapse = ", "))
    )
  }

  publications <- publications |>
    dplyr::mutate(publication_id = gsub("\\s+", "", as.character(publication_id))) |>
    dplyr::filter(!is.na(publication_id), nzchar(publication_id)) |>
    dplyr::distinct(publication_id, .keep_all = TRUE)
  if (nrow(publications) == 0L) {
    return(publications)
  }

  classifier <- base::get("genereviews_from_pmid", mode = "function", inherits = TRUE)
  is_gene_review <- vapply(
    publications$publication_id,
    function(publication_id) isTRUE(classifier(publication_id, check = TRUE)),
    logical(1)
  )

  dplyr::mutate(
    publications,
    publication_type = dplyr::case_when(
      publication_type == "additional_references" & is_gene_review ~ "gene_review",
      publication_type == "gene_review" & !is_gene_review ~ "additional_references",
      TRUE ~ publication_type
    )
  )
}

publication_write_prepare <- function(publications, db) {
  if (is.null(publications) || nrow(publications) == 0L) {
    return(tibble::tibble())
  }

  required <- c("publication_id", "publication_type")
  missing <- base::setdiff(required, names(publications))
  if (length(missing) > 0L) {
    stop_for_bad_request(
      paste("Missing publication field(s):", paste(missing, collapse = ", "))
    )
  }

  publications <- tibble::as_tibble(publications) |>
    dplyr::mutate(publication_id = gsub("\\s+", "", as.character(publication_id))) |>
    dplyr::filter(!is.na(publication_id), nzchar(publication_id)) |>
    dplyr::distinct(publication_id, .keep_all = TRUE)

  if (nrow(publications) == 0L) {
    return(tibble::tibble())
  }

  placeholders <- paste(rep("?", nrow(publications)), collapse = ", ")
  existing <- db_execute_query(
    paste0("SELECT publication_id FROM publication WHERE publication_id IN (", placeholders, ")"),
    as.list(publications$publication_id),
    conn = db
  )
  missing_rows <- publications[!publications$publication_id %in% existing$publication_id, , drop = FALSE]

  if (nrow(missing_rows) == 0L) {
    return(tibble::tibble())
  }

  if (!check_pmid(missing_rows$publication_id)) {
    rlang::abort(
      message = "Invalid PMIDs detected.",
      class = "publication_fetch_error"
    )
  }

  # Publications are fetched ONE PMID AT A TIME (each row is bound to its own
  # fetched metadata), but the curator submitted them as a SET. Letting the
  # first unresolvable PMID abort the run reports only that one, so a curator
  # with two bad references fixes one, resubmits, and is told about the next --
  # a message per round trip. Failures are therefore collected across every
  # fetch and raised once, naming all of them (#318's "fail fast with a clear
  # message" is about not half-committing, not about reporting one at a time).
  fetch_failures <- list()
  fetch_rows <- function(rows, fetcher) {
    dplyr::bind_rows(lapply(seq_len(nrow(rows)), function(index) {
      tryCatch(
        dplyr::bind_cols(
          rows[index, , drop = FALSE],
          tibble::as_tibble(fetcher(rows$publication_id[[index]]))
        ),
        publication_fetch_error = function(condition) {
          fetch_failures[[length(fetch_failures) + 1L]] <<- condition
          NULL
        }
      )
    }))
  }

  gene_reviews <- missing_rows |>
    dplyr::filter(publication_type == "gene_review")
  other_publications <- missing_rows |>
    dplyr::filter(publication_type != "gene_review")

  fetched <- dplyr::bind_rows(
    if (nrow(gene_reviews) > 0L) {
      fetch_rows(gene_reviews, info_from_genereviews_pmid)
    },
    if (nrow(other_publications) > 0L) {
      fetch_rows(other_publications, info_from_pmid)
    }
  )

  publication_write_abort_on_fetch_failures(fetch_failures)

  fetched
}

#' Raise the collected per-PMID fetch failures as a single condition.
#'
#' Every unresolvable-PMID abort carries a `pmids` field, so those can be merged
#' into one list naming each of them. Anything else -- a transport failure, a
#' malformed response, any future `publication_fetch_error` without `pmids` --
#' is re-raised UNCHANGED: folding it into a "not retrievable from PubMed" list
#' would misreport its cause, and this function exists to make the message more
#' accurate, not less.
#'
#' @param failures List of captured `publication_fetch_error` conditions.
#' @return Invisibly `NULL` when there is nothing to raise; otherwise aborts.
#' @noRd
publication_write_abort_on_fetch_failures <- function(failures) {
  if (length(failures) == 0L) {
    return(invisible(NULL))
  }

  has_pmids <- vapply(failures, function(cnd) length(cnd$pmids) > 0L, logical(1))
  if (!all(has_pmids)) {
    stop(failures[[which(!has_pmids)[[1]]]])
  }

  unresolved <- unique(unlist(
    lapply(failures, function(cnd) cnd$pmids),
    use.names = FALSE
  ))

  rlang::abort(
    message = paste0(
      "PMIDs not retrievable from PubMed: ",
      paste(unresolved, collapse = ", ")
    ),
    class = "publication_fetch_error",
    pmids = unresolved
  )
}

publication_write_persist <- function(prepared_publications, conn) {
  if (is.null(prepared_publications) || nrow(prepared_publications) == 0L) {
    return(invisible(0L))
  }

  cols <- names(prepared_publications)
  placeholders <- paste(rep("?", length(cols)), collapse = ", ")
  sql <- sprintf(
    "INSERT INTO publication (%s) VALUES (%s)",
    paste(cols, collapse = ", "),
    placeholders
  )

  inserted <- 0L
  for (index in seq_len(nrow(prepared_publications))) {
    tryCatch(
      {
        inserted <- inserted + db_execute_statement(
          sql,
          as.list(prepared_publications[index, , drop = FALSE]),
          conn = conn
        )
      },
      db_statement_error = function(error) {
        if (!grepl("Duplicate entry", error$message, fixed = TRUE)) {
          stop(error)
        }
      }
    )
  }

  invisible(as.integer(inserted))
}
