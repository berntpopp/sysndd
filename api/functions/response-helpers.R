# functions/response-helpers.R
#### Query building, sorting, and filtering helpers
#### (validate_query_column, generate_sort_expressions,
####  generate_filter_expressions)
#### Split from helper-functions.R in v11.0 phase D2.
#### Field selection, cursor pagination, and field-spec helpers were extracted
#### into response-fields-helpers.R in WP8 (#401, part of #346).
####
#### Dependencies (loaded by start_sysndd_api.R):
####   dplyr, tidyr, tibble, stringr, rlang, jsonlite
####   pool global (used by generate_filter_expressions for hash lookups)


#' Assert a column identifier is a bare identifier and (optionally) allowlisted.
#'
#' Rejects anything that is not a simple column token (letters/digits/underscore)
#' or, when `allowed_columns` is non-NULL, is absent from it. Special cross-column
#' tokens "any"/"all" are always permitted. When `allowed_columns` is NULL the
#' allowlist check is skipped (legacy callers) but the bare-identifier check still
#' applies, so syntax like `system(`, backticks, `)`, `~`, `::` can never reach
#' parse_exprs().
#'
#' @param column A character string with the column token to validate.
#' @param allowed_columns A character vector of permitted column names, or NULL
#'   to skip the allowlist check (bare-identifier check still applies).
#'
#' @return Invisibly TRUE on success; stops with an informative message on failure.
#'
#' @export
validate_query_column <- function(column, allowed_columns = NULL) {
  if (column %in% c("any", "all")) {
    return(invisible(TRUE))
  }
  if (!grepl("^[A-Za-z][A-Za-z0-9_]*$", column)) {
    stop_for_bad_request(sprintf("Invalid filter/sort column token: '%s'", column))
  }
  if (!is.null(allowed_columns) && !(column %in% allowed_columns)) {
    stop_for_bad_request(sprintf("Column not allowed for this resource: '%s'", column))
  }
  invisible(TRUE)
}


#' Escape a value for safe interpolation into a single-quoted R string literal
#' that is subsequently parsed by `rlang::parse_exprs()`.
#'
#' Filter/hash values reach `parse_exprs()` as pasted R source; an unescaped
#' quote or backslash lets attacker-controlled data break out of the string
#' literal into executable R / injected SQL (RCE). Backslash is escaped first so
#' an escaped quote is not itself re-doubled. (#security filter-value injection)
#'
#' @param x A value (coerced to character) to embed inside single quotes.
#' @return The value with backslashes and single quotes escaped.
escape_r_string_literal <- function(x) {
  x <- as.character(x)
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  gsub("'", "\\'", x, fixed = TRUE)
}


#' Columns a public list endpoint may sort/filter on, derived from the view.
#'
#' Queries the view via the global `pool` connection and returns its column
#' names, extended with the always-permitted cross-column tokens "any" and
#' "all". The result is memoised per view name for the process lifetime.
#'
#' Returns NULL on any pool/DB error so that call sites can pass the result
#' directly to `generate_filter_expressions(allowed_columns = ...)` or
#' `generate_sort_expressions(allowed_columns = ...)` without additional
#' checking — NULL disables the allowlist check (legacy behavior) while the
#' bare-identifier guard still applies.
#'
#' @param view_name A character string naming the database view or table.
#'
#' @return A character vector of permitted column names (always includes "any"
#'   and "all"), or NULL on error (disables allowlist, bare-identifier check
#'   still applies).
#'
#' @export
allowed_columns_for_view <- memoise::memoise(function(view_name) {
  cols <- tryCatch(
    colnames(pool %>% dplyr::tbl(view_name) %>% utils::head(0) %>% dplyr::collect()),
    error = function(e) NULL
  )
  if (is.null(cols) || length(cols) == 0L) {
    return(NULL)
  }
  unique(c(cols, "any", "all"))
})


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
#' @param allowed_columns A character vector of permitted column names, or NULL
#'   to skip the allowlist check while still enforcing the bare-identifier rule.
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
generate_sort_expressions <- function(sort_string, unique_id = "entity_id", allowed_columns = NULL) {
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
    ))

  # Validate every parsed column BEFORE building paste0 expressions that reach
  # parse_exprs(). This rejects injected tokens regardless of allowlist state.
  for (col in sort_tibble$column) {
    validate_query_column(col, allowed_columns)
  }

  sort_tibble <- sort_tibble %>%
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
    "equals,contains,any,all,lessThan,greaterThan,lessOrEqual,greaterOrEqual,lessThanOrEqual,greaterThanOrEqual",
  allowed_columns = NULL
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
            # SECURITY: strip quote / close-paren / backslash so a direct-path
            # filter value cannot break out of the single-quoted string literal
            # (or escape its closing quote) once pasted into parse_exprs().
            mutate(filter_value = str_remove_all(filter_value, "'|\\)|\\\\"))
        },
        error = function(e) {
          stop(paste("Failed to parse filter expression:", e$message))
        }
      )

      # Validate every non-hash column BEFORE building paste0 expressions that
      # reach parse_exprs(). Hash columns use a separate DB-lookup path and
      # their expression columns come from colnames(fromJSON(...)), not from
      # the user-supplied column token, so they are excluded from this check.
      non_hash_columns <- filter_string_tibble %>%
        dplyr::filter(!stringr::str_detect(column, "hash")) %>%
        dplyr::pull(column)
      for (col in non_hash_columns) {
        validate_query_column(col, allowed_columns)
      }

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

        # SECURITY (#CRITICAL): the stored hash column names AND values are
        # attacker-controlled (POST /api/hash/create body) and are interpolated
        # into R source that reaches parse_exprs() at the caller. Validate the
        # column tokens as bare identifiers (a bare word cannot be a call) and
        # escape the values for the single-quoted literal, so a stored value
        # cannot break out into executable R / injected SQL (RCE).
        hash_cols <- colnames(table_hash_filter_value)
        for (hash_col in hash_cols) {
          validate_query_column(hash_col, allowed_columns)
        }
        hash_values <- vapply(
          as.list(table_hash_filter_value)[[1]],
          escape_r_string_literal,
          character(1)
        )

        filter_list <- paste0(
          hash_cols,
          " %in% c('",
          str_c(hash_values, collapse = "','"),
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
            ## logic for equals
            ##   - any/all variants stay as anchored regex (must compare across many columns)
            ##   - single-column variant emits direct equality so dbplyr translates it to
            ##     SQL `WHERE column = 'value'` (indexable, ~20x faster than REGEXP on
            ##     the entity view; semantics unchanged since the existing pattern is
            ##     a fully-anchored literal regex). MySQL collation defaults to
            ##     case-insensitive for both REGEXP and `=` on our schema.
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
              paste0(column, " == '", filter_value, "'"),
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
