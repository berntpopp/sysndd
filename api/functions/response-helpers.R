# functions/response-helpers.R
#### Query building, sorting, filtering, pagination, and field-spec helpers
#### (generate_sort_expressions, generate_filter_expressions,
####  select_tibble_fields, generate_cursor_pag_inf, generate_tibble_fspec)
#### Split from helper-functions.R in v11.0 phase D2.
####
#### Dependencies (loaded by start_sysndd_api.R):
####   dplyr, tidyr, tibble, stringr, rlang, jsonlite
####   pool global (used by generate_filter_expressions for hash lookups)


#' Generate sort expressions to parse
#'
#' @description
#' This function generates sort expressions based on a provided sort string.
#' The sort string should contain column names separated by commas, with an
#' optional "+" or "-" prefix indicating ascending or descending order,
#' respectively. The function returns a list of expressions for sorting.
#'
#' @param sort_string A character string containing the column names to sort by,
#'   separated by commas. Prefix column names with "+" for ascending order or
#'   "-" for descending order.
#' @param unique_id A character string representing the unique ID column name,
#'   with a default value of "entity_id".
#'
#' @return
#' A character vector containing sort expressions based on the input sort
#' string and the unique ID column.
#'
#' @examples
#' generate_sort_expressions("+name,-age")
#' generate_sort_expressions("name,-age", unique_id = "id")
#'
#' @export
#' @seealso
#' For more information on how the sort string is parsed, see the following
#' resources:
#' \url{https://dplyr.tidyverse.org/reference/desc.html} for details on how
#' the "desc()" function is used to sort in descending order.
generate_sort_expressions <- function(sort_string, unique_id = "entity_id") {
  # split the sort input by comma and compute
  # directions based on presence of + or - in front of the string
  sort_tibble <- as_tibble(str_split(
    str_replace_all(sort_string, fixed(" "), ""), ","
  )[[1]]) %>%
    dplyr::select(column = value) %>%
    mutate(direction = case_when(
      str_sub(column, 1, 1) == "+" ~ "asc",
      str_sub(column, 1, 1) == "-" ~ "desc",
      TRUE ~ "asc",
    )) %>%
    mutate(column = case_when(
      str_sub(column, 1, 1) == "+" ~ str_sub(column, 2, -1),
      str_sub(column, 1, 1) == "-" ~ str_sub(column, 2, -1),
      TRUE ~ column,
    )) %>%
    mutate(exprs = case_when(
      direction == "asc" ~ column,
      direction == "desc" ~ paste0("desc(", column, ")"),
    )) %>%
    unique() %>%
    group_by(column) %>%
    mutate(count = n())

  sort_list <- sort_tibble$exprs

  # and check if entity_id is in the resulting list,
  # if not append to the list for unique sorting
  if (!(unique_id %in% sort_list ||
          paste0("desc(", unique_id, ")") %in% sort_list)) {
    sort_list <- append(sort_list, unique_id)
  }

  return(sort_list)
}


#' Generate filter expressions to parse
#'
#' @description
#' This function generates filter expressions based on a provided filter string.
#' The filter string should follow the semantics defined by
#' https://www.jsonapi.net/usage/reading/filtering.html. Currently, only the
#' "Equality" and "Contains text" operations are implemented.
#'
#' @param filter_string A character string containing the filter conditions.
#' @param operations_allowed A character string containing the allowed
#'   operations, separated by commas (default:
#'   "equals,contains,any,all,lessThan,greaterThan,lessOrEqual,greaterOrEqual").
#'
#' @return
#' A character string containing the filter expression based on the input
#' filter string and the allowed operations.
#'
#' @examples
#' generate_filter_expressions("and(name, contains, 'John')")
#' generate_filter_expressions("or(age, equals, '30')")
#'
#' @export
#' @seealso
#' For more information on the filtering semantics, see the following resource:
#' \url{https://www.jsonapi.net/usage/reading/filtering.html}
#'
#' @note
#' Error handling and validation implemented for malformed expressions and missing columns.
#' Column type handling uses string comparison for all operations (sufficient for current use cases).
generate_filter_expressions <- function(
  filter_string,
  operations_allowed =
    "equals,contains,any,all,lessThan,greaterThan,lessOrEqual,greaterOrEqual,lessThanOrEqual,greaterThanOrEqual"
) {
  # define supported operations
  operations_supported <- paste0(
    "equals,contains,any,all,",
    "lessThan,greaterThan,lessOrEqual,greaterOrEqual,",
    "lessThanOrEqual,greaterThanOrEqual,and,or,not"
  ) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  # define supported logic
  logic_supported <- "and,or,not" %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  # transform submitted operations to list
  operations_allowed <- URLdecode(operations_allowed) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  filter_string <- URLdecode(filter_string) %>%
    str_trim()

  # If the filter_string is empty or "null" (as a string), return an empty
  # string immediately, indicating no filtering should be applied. This
  # handles cases where users input "null" as a literal string, which is
  # not valid for generating filter expressions.
  if (filter_string == "" || filter_string == "null") {
    return("")
  }

  # Validate filter expression structure (basic parentheses check)
  open_parens <- str_count(filter_string, "\\(")
  close_parens <- str_count(filter_string, "\\)")
  if (open_parens != close_parens) {
    stop("Malformed filter expression: mismatched parentheses")
  }

  logical_operator <- stringr::str_extract(
    string = filter_string,
    pattern = ".+?\\("
  ) %>%
    stringr::str_remove_all("\\(")

  if (logical_operator %in% logic_supported) {
    filter_string <- filter_string %>%
      stringr::str_extract(pattern = "(?<=\\().*(?=\\))")
  } else {
    logical_operator <- "and"
  }

  # check if requested operations are supported, if not through error
  if (all(operations_allowed %in% operations_supported)) {
    if (filter_string != "") {
      # generate tibble from expressions with error handling
      filter_string_tibble <- tryCatch(
        {
          as_tibble(str_split(str_squish(filter_string), "\\),")[[1]]) %>%
            tidyr::separate(value, c("logic", "column_value"), sep = "\\(") %>%
            tidyr::separate(column_value, c("column", "filter_value"),
              sep = "\\,",
              extra = "merge"
            ) %>%
            mutate(filter_value = str_remove_all(filter_value, "'|\\)"))
        },
        error = function(e) {
          stop(paste("Failed to parse filter expression:", e$message))
        }
      )

      # check if hash is in filter expression
      filter_string_hash <- filter_string_tibble %>%
        filter(str_detect(column, "hash"))

      filter_string_has_hash <- (nrow(filter_string_hash) >= 1)

      if (filter_string_has_hash) {
        # check if hash is present in database
        table_hash_filter <- pool %>%
          tbl("table_hash") %>%
          collect() %>%
          filter(hash_256 == filter_string_hash$filter_value[1])

        hash_found <- (nrow(table_hash_filter) == 1)
      }

      # compute filter expressions if hash keyword IS found
      if (filter_string_has_hash && hash_found) {
        table_hash_filter_value <- fromJSON(table_hash_filter$json_text)

        filter_list <- paste0(
          colnames(table_hash_filter_value),
          " %in% c('",
          str_c(as.list(table_hash_filter_value)[[1]], collapse = "','"),
          "')"
        )
      } else if (filter_string_has_hash && !hash_found) {
        stop("Hash not found.")
      } else {
        # compute filter expressions if hash keyword NOT found
        filter_tibble <- filter_string_tibble %>%
          filter(!str_detect(column, "hash")) %>%
          mutate(exprs = case_when(
            ## logic for contains based on regex
            column == "any" & logic == "contains" ~
              paste0(
                "if_any(everything(), ~str_detect(.x, '",
                filter_value, "'))"
              ),
            column == "all" & logic == "contains" ~
              paste0(
                "if_all(everything(), ~str_detect(.x, '",
                filter_value, "'))"
              ),
            !(column %in% c("all", "any")) & logic == "contains" ~
              paste0("str_detect(", column, ", '", filter_value, "')"),
            ## logic for equals based on regex
            column == "any" & logic == "equals" ~
              paste0(
                "if_any(everything(), ~str_detect(.x, '^",
                filter_value, "$'))"
              ),
            column == "all" & logic == "equals" ~
              paste0(
                "if_all(everything(), ~str_detect(.x, '^",
                filter_value, "$'))"
              ),
            !(column %in% c("all", "any")) & logic == "equals" ~
              paste0("str_detect(", column, ", '^", filter_value, "$')"),
            ## logic for any based on regex
            column == "any" & logic == "any" ~
              paste0(
                "if_any(everything(), ~str_detect(.x, ",
                str_replace_all(paste0("'", filter_value, "')"),
                  pattern = "\\,",
                  replacement = "|"
                ), ")"
              ),
            column == "all" & logic == "any" ~
              paste0(
                "if_all(everything(), ~str_detect(.x, ",
                str_replace_all(paste0("'", filter_value, "')"),
                  pattern = "\\,",
                  replacement = "|"
                ), ")"
              ),
            !(column %in% c("all", "any")) & logic == "any" ~
              paste0(
                "str_detect(", column, ", ",
                str_replace_all(
                  paste0(
                    "'",
                    filter_value, "')"
                  ),
                  pattern = "\\,",
                  replacement = "|"
                )
              ),
            ## logic for all based on regex
            column == "any" & logic == "all" ~
              paste0(
                "if_any(everything(), ~str_detect(.x, ",
                str_replace_all(paste0("'(?=.*", filter_value, ")')"),
                  pattern = "\\,",
                  replacement = ")(?=.*"
                ), ")"
              ),
            column == "all" & logic == "all" ~
              paste0(
                "if_all(everything(), ~str_detect(.x, ",
                str_replace_all(paste0("'(?=.*", filter_value, ")')"),
                  pattern = "\\,",
                  replacement = ")(?=.*"
                ), ")"
              ),
            !(column %in% c("all", "any")) & logic == "all" ~
              paste0(
                "str_detect(", column, ", ",
                str_replace_all(
                  paste0(
                    "'(?=.*",
                    filter_value, ")')"
                  ),
                  pattern = "\\,",
                  replacement = ")(?=.*"
                )
              ),
            ## logic for Less than (numeric-aware)
            column == "any" & logic == "lessThan" ~
              paste0(
                "if_any(everything(), .x < ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            column == "all" & logic == "lessThan" ~
              paste0(
                "if_any(everything(), .x < ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            !(column %in% c("all", "any")) & logic == "lessThan" ~
              paste0(
                column, " < ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'"))
              ),
            ## logic for Greater than (numeric-aware)
            column == "any" & logic == "greaterThan" ~
              paste0(
                "if_any(everything(), .x > ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            column == "all" & logic == "greaterThan" ~
              paste0(
                "if_any(everything(), .x > ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            !(column %in% c("all", "any")) & logic == "greaterThan" ~
              paste0(
                column, " > ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'"))
              ),
            ## logic for Less than or equal to (numeric-aware)
            column == "any" & logic == "lessOrEqual" ~
              paste0(
                "if_any(everything(), .x <= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            column == "all" & logic == "lessOrEqual" ~
              paste0(
                "if_any(everything(), .x <= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            !(column %in% c("all", "any")) & logic == "lessOrEqual" ~
              paste0(
                column, " <= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'"))
              ),
            ## alias: lessThanOrEqual -> lessOrEqual (numeric-aware)
            column == "any" & logic == "lessThanOrEqual" ~
              paste0(
                "if_any(everything(), .x <= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            column == "all" & logic == "lessThanOrEqual" ~
              paste0(
                "if_any(everything(), .x <= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            !(column %in% c("all", "any")) & logic == "lessThanOrEqual" ~
              paste0(
                column, " <= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'"))
              ),
            ## logic for Greater than or equal to (numeric-aware)
            column == "any" & logic == "greaterOrEqual" ~
              paste0(
                "if_any(everything(), .x >= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            column == "all" & logic == "greaterOrEqual" ~
              paste0(
                "if_any(everything(), .x >= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            !(column %in% c("all", "any")) & logic == "greaterOrEqual" ~
              paste0(
                column, " >= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'"))
              ),
            ## alias: greaterThanOrEqual -> greaterOrEqual (numeric-aware)
            column == "any" & logic == "greaterThanOrEqual" ~
              paste0(
                "if_any(everything(), .x >= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            column == "all" & logic == "greaterThanOrEqual" ~
              paste0(
                "if_any(everything(), .x >= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'")), ")"
              ),
            !(column %in% c("all", "any")) & logic == "greaterThanOrEqual" ~
              paste0(
                column, " >= ",
                ifelse(grepl("^-?[0-9.]+$", filter_value), filter_value,
                       paste0("'", filter_value, "'"))
              ),
          )) %>%
          ## remove non fitting values
          filter(logic %in% operations_allowed) %>%
          filter(!is.na(exprs))

        ## generate a list of filters
        filter_list <- filter_tibble$exprs
      }

      # compute filter string based on input logic
      if (logical_operator == "and") {
        filter_expression <- stringr::str_c(filter_list, collapse = " & ")
      } else if (logical_operator == "or") {
        filter_expression <- stringr::str_c(filter_list, collapse = " | ")
      } else if (logical_operator == "not") {
        filter_expression <- paste0(
          "!( ",
          stringr::str_c(filter_list, collapse = " | "),
          " )"
        )
      }

      return(filter_expression)
    } else {
      return(filter_string)
    }
  } else {
    stop("Some requested operations are not supported.")
  }
}


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
    stop("Some requested fields are not in the column names.")
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

  if (length(page_after_row) == 0) {
    page_after_row <- 0
    page_after_row_next <- (pagination_tibble %>%
                              filter(row_number() == page_after_row + page_size + 1) %>%
                              dplyr::select(!!sym(pagination_identifier)))[[1]]
  } else {
    page_after_row_next <- (pagination_tibble %>%
                              filter(row_number() == page_after_row + page_size) %>%
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
