# functions/response-fields-helpers.R
#### Field selection, cursor pagination, and field-spec helpers
#### (select_tibble_fields, generate_cursor_pag_inf, generate_tibble_fspec)
#### Split from response-helpers.R in WP8 (#401, part of #346).
####
#### Dependencies (loaded by start_sysndd_api.R):
####   dplyr, tidyr, tibble, stringr
####   core/errors.R (stop_for_bad_request, used by select_tibble_fields)


#' Select requested fields from a tibble
#'
#' @description
#' This function selects the requested fields from a given tibble. It ensures
#' that the unique_id column is included in the output, even if it was not
#' explicitly requested.
#'
#' @param selection_tibble A tibble containing the data to be filtered.
#' @param fields_requested A character string containing the fields to be
#'   selected, separated by commas. If an empty string is provided, all fields
#'   will be selected.
#' @param unique_id A character string specifying the unique identifier column
#'   name (default: "entity_id").
#'
#' @return
#' A tibble containing only the requested fields.
#'
#' @examples
#' data <- tibble(a = 1:5, b = letters[1:5], entity_id = 101:105)
#' select_tibble_fields(data, "a,b")
#' select_tibble_fields(data, "")
#'
#' @export
#' @seealso
#' For more information on working with tibbles in R, see the following resource:
#' \url{https://tibble.tidyverse.org/}
select_tibble_fields <- function(
  selection_tibble,
  fields_requested,
  unique_id = "entity_id"
) {
  # get column names from selection_tibble
  tibble_colnames <- colnames(selection_tibble)

  # check if fields_requested is empty string,
  # if so assign tibble_colnames to it, else
  # split the fields_requested input by comma
  if (fields_requested != "") {
    fields_requested <- str_split(str_replace_all(
      fields_requested, fixed(" "), ""
    ), ",")[[1]]
  } else {
    fields_requested <- tibble_colnames
  }

  # check if unique_id variable is in the column names,
  # if not prepend to the list for unique sorting
  if (!(unique_id %in% fields_requested)) {
    fields_requested <- append(fields_requested, unique_id, after = 0)
    fields_requested <- Filter(function(x) !identical("", x), fields_requested)
  }

  # check if requested column names exist in tibble, if error
  if (all(fields_requested %in% tibble_colnames)) {
    selection_tibble <- selection_tibble %>%
      dplyr::select(all_of(fields_requested))
  } else {
    # A request for fields the queried view/tibble does not expose is a client
    # error (400), not a server fault (500). With mount_endpoints.R now routing
    # every sub-router through errorHandler, this error_400 maps to a proper
    # 400 + problem+json. Name the offending columns so a frontend/view schema
    # mismatch is debuggable.
    missing_fields <- setdiff(fields_requested, tibble_colnames)
    stop_for_bad_request(sprintf(
      "Some requested fields are not in the column names: %s",
      paste(missing_fields, collapse = ", ")
    ))
  }
  return(selection_tibble)
}


#' Generate cursor pagination information from a tibble
#'
#' @description
#' This function generates cursor-based pagination information from a tibble,
#' providing the requested page and pagination links. It also includes metadata
#' about the pagination state.
#'
#' @param pagination_tibble A tibble containing the data to be paginated.
#' @param page_size A character or numeric value specifying the number of rows
#'   per page. Use "all" for all rows in a single page (default: "all").
#' @param page_after A numeric value indicating the item to start the page
#'   after (default: 0).
#' @param pagination_identifier A character string specifying the unique
#'   identifier column name (default: "entity_id").
#'
#' @return
#' A list containing three elements:
#' - links: a tibble with URLs for the previous, self, next, and last pages.
#' - meta: a tibble with pagination metadata, including the page size, current
#'   page number, total pages, previous, current, and next item IDs, and total
#'   items.
#' - data: a tibble containing the requested page data.
#'
#' @examples
#' data <- tibble(a = 1:10, b = letters[1:10], entity_id = 101:110)
#' generate_cursor_pag_inf(data, 5)
#' generate_cursor_pag_inf(data, 3, 104)
#'
#' @export
#' @seealso
#' For more information on cursor-based pagination, see the following resource:
#' \url{https://www.sitepoint.com/paginating-real-time-data-cursor-based-pagination/}
generate_cursor_pag_inf <- function(
  pagination_tibble,
  page_size = "all",
  page_after = 0,
  pagination_identifier = "entity_id"
) {
  # get number of rows in filtered ndd_entity_view
  pagination_tibble_rows <- (pagination_tibble %>%
                               summarize(n = n()))$n

  # check if page_size is either "all" or
  # a valid integer and convert or assign values accordingly
  if (page_size == "all") {
    page_after <- 0
    page_size <- pagination_tibble_rows
    page_count <- ceiling(pagination_tibble_rows / page_size)
  } else if (is.numeric(as.integer(page_size))) {
    page_size <- as.integer(page_size)
    page_count <- ceiling(pagination_tibble_rows / page_size)
  } else {
    stop("Page size provided is not numeric or all.")
  }

  # find the current row of the requested page_after entry
  page_after_row <- (pagination_tibble %>%
      mutate(row = row_number()) %>%
      filter(!!sym(pagination_identifier) == page_after)
  )$row

  # Page 1 sends a sentinel page_after (0) that matches no row; anchor it at
  # row 0 so the row-window and cursor math below are the same on every page.
  if (length(page_after_row) == 0) {
    page_after_row <- 0
  }

  # nextItemID is the id of the LAST row shown on this page (row
  # page_after_row + page_size), so the client's subsequent `page_after=<id>`
  # request — filtered strictly greater-than that id below — resumes exactly
  # after it. It is a null (empty) cursor on the final page, i.e. when the last
  # shown row is the overall last row (page_after_row + page_size >= total).
  #
  # This single rule is applied identically to the first and every subsequent
  # page. It removes the historical first-page off-by-one (which used
  # + page_size + 1 and pointed one row PAST the last shown row, so row
  # page_size + 1 was skipped on the page 1 -> page 2 transition) WITHOUT
  # introducing a phantom trailing empty page when the total is an exact
  # multiple of page_size (the >= total guard yields a null next on the last
  # page). `filter(row_number() == 0)` deterministically returns an empty,
  # correctly-typed vector (row numbers start at 1), which the link/meta
  # builders below already treat as "no next page".
  page_after_row_end <- page_after_row + page_size
  if (page_after_row_end < pagination_tibble_rows) {
    page_after_row_next <- (pagination_tibble %>%
                              filter(row_number() == page_after_row_end) %>%
                              dplyr::select(!!sym(pagination_identifier)))[[1]]
  } else {
    page_after_row_next <- (pagination_tibble %>%
                              filter(row_number() == 0) %>%
                              dplyr::select(!!sym(pagination_identifier)))[[1]]
  }

  # find next and prev item row
  page_after_row_prev <- (pagination_tibble %>%
                            filter(row_number() == page_after_row - page_size) %>%
                            dplyr::select(!!sym(pagination_identifier)))[[1]]
  page_after_row_last <- (pagination_tibble %>%
                            filter(row_number() == page_size * (page_count - 1)) %>%
                            dplyr::select(!!sym(pagination_identifier)))[[1]]

  # filter by row
  pagination_tibble <- pagination_tibble %>%
    filter((row_number() > page_after_row) &
             (row_number() <= page_after_row + page_size))

  # generate links for self, next and prev pages
  self <- paste0("&page_after=", page_after, "&page_size=", page_size)
  if (length(page_after_row_prev) == 0) {
    prev <- "null"
  } else {
    prev <- paste0(
      "&page_after=",
      page_after_row_prev,
      "&page_size=",
      page_size
    )
  }

  if (length(page_after_row_next) == 0) {
    `next` <- "null"
  } else {
    `next` <- paste0(
      "&page_after=",
      page_after_row_next,
      "&page_size=",
      page_size
    )
  }

  if (length(page_after_row_last) == 0) {
    last <- "null"
  } else {
    last <- paste0(
      "&page_after=",
      page_after_row_last,
      "&page_size=",
      page_size
    )
  }

  # generate links object
  links <- as_tibble(list(
    "prev" = prev,
    "self" = self,
    "next" = `next`,
    "last" = last
  ))

  # generate meta object
  meta <- as_tibble(list(
    "perPage" = page_size,
    "currentPage" = ceiling((page_after_row + 1) / page_size),
    "totalPages" = page_count,
    "prevItemID" = (if (length(page_after_row_prev) == 0) {
      "null"
    } else {
      page_after_row_prev
    }),
    "currentItemID" = page_after,
    "nextItemID" = (if (length(page_after_row_next) == 0) {
      "null"
    } else {
      page_after_row_next
    }),
    "lastItemID" = (if (length(page_after_row_last) == 0) {
      "null"
    } else {
      page_after_row_last
    }),
    "totalItems" = pagination_tibble_rows
  ))

  # generate return list
  return_data <- list(links = links, meta = meta, data = pagination_tibble)

  return(return_data)
}


#' Generate field specifications from a tibble
#'
#' @description
#' This function generates field specifications from a tibble,
#' based on the given input. It includes information about the fields,
#' such as whether they are filterable, selectable, multi-selectable,
#' sortable, and their display labels.
#'
#' @param field_tibble A tibble containing the data for generating field specs.
#' @param fspecInput A character string specifying the fields to include in the
#'   output. If empty, all fields in the tibble are included (default: "").
#'
#' @return
#' A list containing one element:
#' - fspec: a tibble containing the generated field specifications.
#'
#' @examples
#' data <- tibble(a = 1:10, b = letters[1:10], entity_id = 101:110)
#' generate_tibble_fspec(data, "a,entity_id")
#'
#' @export
generate_tibble_fspec <- function(field_tibble, fspecInput) {
  # get column names from field_tibble
  tibble_colnames <- colnames(field_tibble)

  # check if fspecInput is empty string,
  # if so assign tibble_colnames to it, else
  # split the fields_requested input by comma
  if (fspecInput != "") {
    fspecInput <- str_split(str_replace_all(
      fspecInput, fixed(" "), ""
    ), ",")[[1]]
  } else {
    fspecInput <- tibble_colnames
  }

  # generate fields object
  fields_values <- field_tibble %>%
    mutate(across(everything(), as.character)) %>%
    pivot_longer(everything(),
      names_to = "key",
      values_to = "values",
      values_ptypes = list(values = character())
    ) %>%
    arrange(key, values) %>%
    unique() %>%
    group_by(key) %>%
    summarize(selectOptions = list(values)) %>%
    mutate(count = lengths(selectOptions)) %>%
    mutate(filterable = case_when(
      count > 10 ~ TRUE,
      count <= 10 ~ FALSE,
    )) %>%
    mutate(multi_selectable = case_when(
      count <= 10 & count > 2 ~ TRUE,
      TRUE ~ FALSE,
    )) %>%
    mutate(selectable = case_when(
      count <= 2 ~ TRUE,
      TRUE ~ FALSE,
    )) %>%
    mutate(selectOptions = case_when(
      count > 10 ~ list("null"),
      count <= 10 ~ selectOptions,
    )) %>%
    mutate(sortDirection = "asc") %>%
    mutate(sortable = TRUE) %>%
    mutate(class = "text-left") %>%
    mutate(label = str_to_sentence(str_replace_all(key, "_", " "))) %>%
    filter(key %in% fspecInput) %>%
    arrange(factor(key, levels = fspecInput)) %>%
    {
      if ("details" %in% fspecInput) {
        add_row(.,
          key = "details",
          selectOptions = NULL,
          filterable = FALSE,
          selectable = FALSE,
          multi_selectable = FALSE,
          sortable = FALSE,
          sortDirection = "asc",
          class = "text-center",
          label = "Details"
        )
      } else {
        .
      }
    }

  # generate return list
  return_data <- list(fspec = fields_values)

  return(return_data)
}


#' Merge filtered-set distinct counts into a global fspec as `count_filtered`
#'
#' @description
#' Faceted table column tooltips display "<count_filtered>/<count>": the number
#' of distinct values surviving the active filter over the total number of
#' distinct values. `count` is taken from the fspec computed on the global
#' (unfiltered) tibble; `count_filtered` is taken from the fspec computed on the
#' post-filter tibble and joined back **by key** (never positionally), so a
#' column whose rows are entirely removed by the filter coalesces to 0 instead
#' of misaligning the columns. This is the single source of truth for the
#' global-vs-filtered fspec merge shared by the entity, gene, phenotype,
#' variant, and comparisons table endpoints.
#'
#' @param global_fspec An fspec object (`list(fspec = <tibble>)`) from
#'   [generate_tibble_fspec()] / `generate_tibble_fspec_mem()` computed on the
#'   global (unfiltered) tibble; its `count` column is preserved as the total.
#' @param filtered_fspec An fspec object from the same helpers computed on the
#'   filtered tibble; its `count` column becomes `count_filtered`.
#'
#' @return `global_fspec` with an integer `count_filtered` column added to
#'   `global_fspec$fspec`.
#'
#' @examples
#' g <- generate_tibble_fspec(tibble::tibble(a = c(1, 2, 3)), "a")
#' f <- generate_tibble_fspec(tibble::tibble(a = c(1, 2)), "a")
#' fspec_merge_filtered_counts(g, f)$fspec
#'
#' @export
fspec_merge_filtered_counts <- function(global_fspec, filtered_fspec) {
  global_fspec$fspec <- global_fspec$fspec %>%
    dplyr::left_join(
      filtered_fspec$fspec %>% dplyr::select(key, count_filtered = count),
      by = "key"
    ) %>%
    dplyr::mutate(count_filtered = dplyr::coalesce(count_filtered, 0L))

  global_fspec
}
