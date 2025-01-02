# functions/helper-functions.R
#### This file holds helper functions

#' Nest the gene tibble
#'
#' @description
#' This function organizes data in a tibble by nesting it into groups, making it
#' easier to analyze or manipulate the data.
#' It performs the following operations:
#' 1. Remembers the initial sorting of the tibble by selecting columns 'symbol',
#'    'hgnc_id', and 'entities_count', retaining only unique rows.
#' 2. Nests the tibble by columns 'symbol', 'hgnc_id', and 'entities_count',
#'    assigning the key "entities" to the nested data frame.
#' 3. Removes grouping and arranges the nested tibble by the 'symbol' column,
#'    using the initial sorting as the level order.
#' 4. Returns the nested tibble.
#'
#' @param tibble A tibble to be nested.
#'
#' @return A nested tibble.
#'
#' @examples
#' # Prepare example tibble
#' example_tibble <- tibble(
#'   symbol = c("A", "B", "C"),
#'   hgnc_id = c(1, 2, 3),
#'   entities_count = c(5, 3, 2)
#' )
#'
#' # Nest the example tibble
#' nest_gene_tibble(example_tibble)
#'
#' @seealso
#' Based on: \url{https://xiaolianglin.com/}
#'
#' @export
nest_gene_tibble <- function(tibble) {

  # remember the initial sorting
  initial_sort <- tibble %>%
    select(symbol, hgnc_id, entities_count) %>%
    unique()

  # nest then re-apply the sorting
    nested_tibble <- tibble %>%
        tidyr::nest(.by = c(symbol, hgnc_id, entities_count), .key = "entities") %>%
        arrange(factor(symbol, levels = initial_sort$symbol))

    return(nested_tibble)
}


#' Generate a random password
#'
#' @description
#' This function generates a random password of length 12
#' by selecting characters from a vector of possible characters
#' that includes digits, lowercase letters, #' uppercase letters,
#' exclamation mark, and dollar sign. The steps are as follows:
#' 1. Create a vector named 'possible_characters' containing digits, lowercase
#'    letters, uppercase letters, exclamation mark, and dollar sign.
#' 2. Use the 'sample()' function to randomly select 12 characters from the
#'    'possible_characters' vector and 'paste()' to combine them into a string.
#' 3. Use 'collapse = ""' argument in the 'paste()' function to prevent any
#'    separators between the selected characters.
#' 4. Return the generated password.
#'
#' @return A randomly generated password.
#'
#' @examples
#' # Generate a random password
#' random_password()
#'
#' @seealso
#' Based on: \url{https://stackoverflow.com/questions/22219035/function-to-generate-a-random-password}
#'
#' @export
random_password <- function() {
  # create a vector of possible characters
  possible_characters <- c(0:9, letters, LETTERS, "!", "$")

  # use paste and sample to generate a random password of length 12
  password <- paste(sample(possible_characters, 12), collapse = "")

  # return password
  return(password)
}


#' Validate email address
#'
#' @description
#' This function checks whether a given email address is valid by using regular
#' expressions and the 'grepl()' function. The email address is considered valid
#' if it matches the following pattern:
#' 1. Starts with a word boundary (\<).
#' 2. Followed by one or more uppercase letters, digits, dots, underscores,
#'    percent signs, plus signs, or hyphens ([A-Z0-9._%+-]+).
#' 3. Followed by the at symbol (@).
#' 4. Followed by one or more uppercase letters, digits, dots, or hyphens
#'    ([A-Z0-9.-]+).
#' 5. Followed by a dot (.).
#' 6. Followed by two or more uppercase letters ([A-Z]{2,}).
#' 7. Ends with a word boundary (\>).
#' The 'ignore.case = TRUE' argument in 'grepl()' makes the function
#' case-insensitive, allowing it to match email addresses regardless of the
#' letter case.
#'
#' @param email_address A character string representing an email address.
#'
#' @return A boolean value indicating whether the email address is valid.
#'
#' @examples
#' # Validate an email address
#' is_valid_email("test@example.com")
#'
#' @seealso
#' Based on: \url{https://www.r-bloggers.com/2012/07/validating-email-adresses-in-r/}
#'
#' @export
is_valid_email <- function(email_address) {
    grepl("\\<[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}\\>",
      as.character(email_address),
      ignore.case = TRUE
      )
}


#' This function generates initials for an avatar based on the provided
#' first name and family name. The initials are created by taking the first
#' character of each name.
#'
#' @param first_name A character string representing the first name.
#' @param family_name A character string representing the family name.
#'
#' @return
#' A character string containing the initials, created by taking the first
#' character of the first name and the first character of the family name.
#'
#' @examples
#' generate_initials("John", "Doe")
#' generate_initials("Ada", "Lovelace")
#'
#' @seealso
#' \url{https://stackoverflow.com/questions/24833566/get-initials-from-string-of-words}
#' for the Stack Overflow question that inspired this function.
#' @export
generate_initials <- function(first_name, family_name) {
    initials <- paste(substr(strsplit(paste0(first_name,
          " ",
          family_name),
          " ")[[1]],
        1, 1),
      collapse = "")

    return(initials)
}


#' Send a no-reply email
#'
#' @description
#' This function sends a no-reply email with a specified email body, subject,
#' and recipient. It allows for an optional blind copy recipient.
#'
#' @param email_body A character string representing the body of the email.
#' @param email_subject A character string representing the subject of the email.
#' @param email_recipient A character string representing the recipient's email
#'   address.
#' @param email_blind_copy A character string representing the blind copy
#'   recipient's email address, with a default value of "noreply@sysndd.org".
#'
#' @return
#' A character string indicating that the email has been sent.
#'
#' @examples
#' send_noreply_email(
#'   email_body = "Hello, this is a test email.",
#'   email_subject = "Test Email",
#'   email_recipient = "example@example.com"
#' )
#' @export
send_noreply_email <- function(email_body,
  email_subject,
  email_recipient,
  email_blind_copy = "noreply@sysndd.org") {
    email <- compose_email(
      body = md(email_body),
      footer = md(paste0("Visit [SysNDD.org](https://www.sysndd.org) for ",
        "the latest information on Neurodevelopmental Disorders."))
      )

    suppressMessages(email %>%
      smtp_send(
      from = "noreply@sysndd.org",
      subject = email_subject,
      to = email_recipient,
      bcc = email_blind_copy,
      credentials = creds_envvar(
        pass_envvar = "SMTP_PASSWORD",
        user = dw$mail_noreply_user,
        host = dw$mail_noreply_host,
        port = dw$mail_noreply_port,
        use_ssl = dw$mail_noreply_use_ssl
      )
      ))
    return("Request mail send!")
}


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
          str_replace_all(sort_string, fixed(" "), ""), ",")[[1]]) %>%
        select(column = value) %>%
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
    unique %>%
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
#' TODO: Implement error handling.
#' TODO: Implement checking if the respective columns exist.
#' TODO: Implement allowed operations as input argument.
#' TODO: Implement column type handling.
generate_filter_expressions <- function(filter_string,
    operations_allowed =
    "equals,contains,any,all,lessThan,greaterThan,lessOrEqual,greaterOrEqual") {

  # define supported operations
  operations_supported <- paste0("equals,contains,any,all,",
      "lessThan,greaterThan,lessOrEqual,greaterOrEqual,and,or,not") %>%
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
  if (filter_string == "" | filter_string == "null") {
      return("")
  }

  logical_operator <- stringr::str_extract(string = filter_string,
      pattern = ".+?\\(") %>%
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

      # generate tibble from expressions
      filter_string_tibble <- as_tibble(str_split(str_squish(filter_string),
          "\\),")[[1]]) %>%
        separate(value, c("logic", "column_value"), sep = "\\(") %>%
        separate(column_value, c("column", "filter_value"),
          sep = "\\,",
          extra = "merge") %>%
        mutate(filter_value = str_remove_all(filter_value, "'|\\)"))

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
          "')")

      } else if (filter_string_has_hash && !hash_found) {
        stop("Hash not found.")
      }  else {
      # compute filter expressions if hash keyword NOT found
      filter_tibble <- filter_string_tibble %>%
        filter(!str_detect(column, "hash"))  %>%
        mutate(exprs = case_when(
      ## logic for contains based on regex
          column == "any" & logic == "contains" ~
            paste0("if_any(everything(), ~str_detect(.x, '",
              filter_value, "'))"),
          column == "all" & logic == "contains" ~
            paste0("if_all(everything(), ~str_detect(.x, '",
              filter_value, "'))"),
          !(column %in% c("all", "any")) & logic == "contains" ~
            paste0("str_detect(", column, ", '", filter_value, "')"),
      ## logic for equals based on regex
          column == "any" & logic == "equals" ~
            paste0("if_any(everything(), ~str_detect(.x, '^",
              filter_value, "$'))"),
          column == "all" & logic == "equals" ~
            paste0("if_all(everything(), ~str_detect(.x, '^",
              filter_value, "$'))"),
          !(column %in% c("all", "any")) & logic == "equals" ~
            paste0("str_detect(", column, ", '^", filter_value, "$')"),
      ## logic for any based on regex
          column == "any" & logic == "any" ~
            paste0("if_any(everything(), ~str_detect(.x, ",
              str_replace_all(paste0("'", filter_value, "')"),
                pattern = "\\,",
                replacement = "|"), ")"),
          column == "all" & logic == "any" ~
            paste0("if_all(everything(), ~str_detect(.x, ",
              str_replace_all(paste0("'", filter_value, "')"),
                pattern = "\\,",
                replacement = "|"), ")"),
          !(column %in% c("all", "any")) & logic == "any" ~
            paste0("str_detect(", column, ", ",
              str_replace_all(paste0("'",
                filter_value, "')"),
                pattern = "\\,",
                replacement = "|")),
      ## logic for all based on regex
          column == "any" & logic == "all" ~
            paste0("if_any(everything(), ~str_detect(.x, ",
              str_replace_all(paste0("'(?=.*", filter_value, ")')"),
                pattern = "\\,",
                replacement = ")(?=.*"), ")"),
          column == "all" & logic == "all" ~
            paste0("if_all(everything(), ~str_detect(.x, ",
              str_replace_all(paste0("'(?=.*", filter_value, ")')"),
                pattern = "\\,",
                replacement = ")(?=.*"), ")"),
          !(column %in% c("all", "any")) & logic == "all" ~
            paste0("str_detect(", column, ", ",
              str_replace_all(paste0("'(?=.*",
                filter_value, ")')"),
                pattern = "\\,",
                replacement = ")(?=.*")),
      ## logic for Less than
          column == "any" & logic == "lessThan" ~
            paste0("if_any(everything(), .x < '", filter_value, "'"),
          column == "all" & logic == "lessThan" ~
            paste0("if_any(everything(), .x < '", filter_value, "'"),
          !(column %in% c("all", "any")) & logic == "lessThan" ~
            paste0(column, " < '", filter_value, "'"),
      ## logic for Greater than
          column == "any" & logic == "greaterThan" ~
            paste0("if_any(everything(), .x > '", filter_value, "'"),
          column == "all" & logic == "greaterThan" ~
            paste0("if_any(everything(), .x > '", filter_value, "'"),
          !(column %in% c("all", "any")) & logic == "greaterThan" ~
            paste0(column, " > '", filter_value, "'"),
      ## logic for Less than or equal to
          column == "any" & logic == "lessOrEqual" ~
            paste0("if_any(everything(), .x <= '", filter_value, "'"),
          column == "all" & logic == "lessOrEqual" ~
            paste0("if_any(everything(), .x <= '", filter_value, "'"),
          !(column %in% c("all", "any")) & logic == "lessOrEqual" ~
            paste0(column, " <= '", filter_value, "'"),
      ## logic for Greater than or equal to
          column == "any" & logic == "greaterOrEqual" ~
            paste0("if_any(everything(), .x >= '", filter_value, "'"),
          column == "all" & logic == "greaterOrEqual" ~
            paste0("if_any(everything(), .x >= '", filter_value, "'"),
          !(column %in% c("all", "any")) & logic == "greaterOrEqual" ~
            paste0(column, " >= '", filter_value, "'"),
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
        filter_expression <- paste0("!( ",
          stringr::str_c(filter_list, collapse = " | "),
          " )")
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
select_tibble_fields <- function(selection_tibble,
  fields_requested,
  unique_id = "entity_id") {

  # get column names from selection_tibble
  tibble_colnames <- colnames(selection_tibble)

  # check if fields_requested is empty string,
  # if so assign tibble_colnames to it, else
  # split the fields_requested input by comma
  if (fields_requested != "") {
    fields_requested <- str_split(str_replace_all(
      fields_requested, fixed(" "), ""), ",")[[1]]
  } else {
    fields_requested <- tibble_colnames
  }

  # check if unique_id variable is in the column names,
  # if not prepend to the list for unique sorting
  if (!(unique_id %in% fields_requested)) {
    fields_requested <- purrr::prepend(fields_requested, unique_id)
    fields_requested <- Filter(function(x) !identical("", x), fields_requested)
  }

  # check if requested column names exist in tibble, if error
  if (all(fields_requested %in% tibble_colnames)) {
    selection_tibble <- selection_tibble %>%
    select(all_of(fields_requested))
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
generate_cursor_pag_inf <- function(pagination_tibble,
  page_size = "all",
  page_after = 0,
  pagination_identifier = "entity_id") {

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
      select(!!sym(pagination_identifier)))[[1]]
  } else {
    page_after_row_next <- (pagination_tibble %>%
      filter(row_number() == page_after_row + page_size) %>%
      select(!!sym(pagination_identifier)))[[1]]
  }

  # find next and prev item row
  page_after_row_prev <- (pagination_tibble %>%
    filter(row_number() == page_after_row - page_size) %>%
      select(!!sym(pagination_identifier)))[[1]]
  page_after_row_last <- (pagination_tibble %>%
    filter(row_number() == page_size * (page_count - 1)) %>%
      select(!!sym(pagination_identifier)))[[1]]

  # filter by row
  pagination_tibble <- pagination_tibble %>%
    filter((row_number() > page_after_row) &
      (row_number() <= page_after_row + page_size))

  # generate links for self, next and prev pages
  self <- paste0("&page_after=", page_after, "&page_size=", page_size)
  if (length(page_after_row_prev) == 0) {
    prev <- "null"
  } else {
    prev <- paste0("&page_after=",
      page_after_row_prev,
      "&page_size=",
      page_size)
  }

  if (length(page_after_row_next) == 0) {
    `next` <- "null"
  } else {
    `next` <- paste0("&page_after=",
      page_after_row_next,
      "&page_size=",
      page_size)
  }

  if (length(page_after_row_last) == 0) {
    last <- "null"
  } else {
    last <- paste0("&page_after=",
      page_after_row_last,
      "&page_size=",
      page_size)
  }

  # generate links object
  links <- as_tibble(list("prev" = prev,
    "self" = self,
    "next" = `next`,
    "last" = last))

  # generate meta object
  meta <- as_tibble(list("perPage" = page_size,
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
    "totalItems" = pagination_tibble_rows)
  )

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
        fspecInput, fixed(" "), ""), ",")[[1]]
    } else {
      fspecInput <- tibble_colnames
    }

    # generate fields object
    fields_values <- field_tibble %>%
      mutate(across(everything(), as.character)) %>%
      pivot_longer(everything(),
        names_to = "key",
        values_to = "values",
        values_ptypes = list(values = character())) %>%
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
      {if ("details" %in% fspecInput)
        add_row(., key = "details",
          selectOptions = NULL,
          filterable = FALSE,
          selectable = FALSE,
          multi_selectable = FALSE,
          sortable = FALSE,
          sortDirection = "asc",
          class = "text-center",
          label = "Details")
      else .
      }

  # generate return list
  return_data <- list(fspec = fields_values)

  return(return_data)
}


#' Generate a hash for a HGNC gene or entity list
#'
#' @description
#' This function generates a hash for a list of HGNC gene or entity identifiers.
#' It removes the "HGNC:" prefix if present, sorts the identifiers, concatenates
#' them, and computes the SHA-256 hash.
#'
#' @param identifier_list A character vector containing the HGNC gene or entity
#'   identifiers for which to generate the hash.
#'
#' @return
#' A character string containing the computed SHA-256 hash.
#'
#' @examples
#' genes <- c("HGNC:12345", "HGNC:67890")
#' generate_panel_hash(genes)
#'
#' @export
generate_panel_hash <- function(identifier_list) {
  # remove hgnc pre-attachment if present,
  # sort, concatenate and compute sha256 hash
  list_hash <- identifier_list %>%
    str_remove("HGNC:") %>%
    sort() %>%
    str_c(collapse = ",") %>%
    sha256()

  # return result
  return(list_hash)
}


#' Generate a hash for a JSON object
#'
#' @description
#' This function generates a hash for a JSON object. It computes the SHA-256
#' hash for the given JSON input.
#'
#' @param json_input A character string containing the JSON object for which
#'   to generate the hash.
#'
#' @return
#' A character string containing the computed SHA-256 hash.
#'
#' @examples
#' json_string <- '{"key": "value"}'
#' generate_json_hash(json_string)
#'
#' @export
generate_json_hash <- function(json_input) {
  # compute sha256 hash
  json_hash <- json_input %>%
    sha256()

  # return result
  return(json_hash)
}


#' Generate a hash for a function
#'
#' @description
#' This function generates a hash for a given function. It deparses the function
#' input and computes the SHA-256 hash.
#'
#' @param function_input A function object for which to generate the hash.
#'
#' @return
#' A character string containing the computed SHA-256 hash.
#'
#' @examples
#' sample_function <- function(x) { x + 1 }
#' generate_function_hash(sample_function)
#'
#' @export
generate_function_hash <- function(function_input) {
  # deparse function, compute sha256 hash
  function_hash <- function_input %>%
    deparse1 %>%
    sha256()

  # return result
  return(function_hash)
}


#' Generate an xlsx file and return its binary info
#'
#' @description
#'
#' generate_xlsx_bin is an R function that creates a temporary
#' Excel (xlsx) file with three sheets:'data', 'meta', and 'links',
#' populated with the corresponding data from a given data object.
#' The function then reads the binary content of the generated
#' xlsx file and returns it. The temporary file is deleted
#' once the binary content is read.
#' The function performs the following steps:
#'
#' 1. Generate a temporary xlsx file path.
#' 2. Write the 'data' element of the data object to the 'data' sheet.
#' 3. Write the 'meta' element of the data object to the 'meta' sheet,
#' excluding the 'fspec' column if present.
#' 4. Write the 'links' element of the data object to the 'links' sheet.
#' 5. Read the binary content of the generated xlsx file.
#' 6. Delete the temporary xlsx file.
#' 7. Return the binary content of the file.
#'
#' @param data_object A list containing three elements: 'data', 'meta', and 'links', each containing a data frame to be written to the respective sheets in the output Excel file.
#' @param file_base_name A string representing the base name to be used for the temporary Excel file.
#'
#' @return The binary content of the generated xlsx file as a raw vector
#' @export
generate_xlsx_bin <- function(data_object, file_base_name) {

  # generate excel file output
  xlsx_file <- file.path(tempdir(),
    paste0(file_base_name, ".xlsx"))

  write.xlsx(data_object$data,
    xlsx_file,
    sheetName = "data",
    append = FALSE)

  # here we unselect the nested column fspec
  # based on https://stackoverflow.com/questions/43786883/how-do-i-select-columns-that-may-or-may-not-exist
  # TODO: instead of unselecting
  # TODO: we could transform to string for all nested
  write.xlsx(data_object$meta %>%
      select(-any_of(c("fspec"))),
    xlsx_file,
    sheetName = "meta",
    append = TRUE)

  write.xlsx(data_object$links,
    xlsx_file,
    sheetName = "links",
    append = TRUE)

  # Read in the raw contents of the binary file
  bin <- readBin(xlsx_file, "raw", n = file.info(xlsx_file)$size)

  # Check file existence and delete
  if (file.exists(xlsx_file)) {
    file.remove(xlsx_file)
  }

  # return the binary contents
  return(bin)
}


#' Nest PubTator Gene Tibble
#'
#' @description
#' Groups a PubTator data frame by gene-related columns (e.g. `gene_name`,
#' `gene_symbol`, `hgnc_id`, `gene_normalized_id`). Then creates two
#' nested list-columns:
#' \itemize{
#'   \item \strong{publications:} pmid, doi, title, journal, date, score, text_hl
#'   \item \strong{entities:} entity_id, disease_ontology_id_version, disease_ontology_name,
#'       hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name,
#'       inheritance_filter, ndd_phenotype, ndd_phenotype_word, entry_date, category, category_id
#' }
#'
#' @param df A data frame (tibble) containing:
#' \itemize{
#'   \item \code{gene_name}, \code{gene_symbol}, \code{hgnc_id}, \code{gene_normalized_id}
#'   \item \code{pmid}, \code{doi}, \code{title}, \code{journal}, \code{date}, \code{score}, \code{text_hl}
#'   \item \code{entity_id}, \code{disease_ontology_id_version}, \code{disease_ontology_name},
#'         \code{hpo_mode_of_inheritance_term}, etc.
#' }
#'
#' @return A \strong{nested tibble} with one row per gene, plus two new list-columns:
#'   \code{publications} and \code{entities}.
#'
#' @examples
#' # Suppose `df_pubtator` has all required columns:
#' # nest_pubtator_gene_tibble(df_pubtator)
#'
#' @export
nest_pubtator_gene_tibble <- function(df) {
  df %>%
    dplyr::group_by(
      gene_name,
      gene_symbol,
      hgnc_id,
      gene_normalized_id
    ) %>%
    tidyr::nest(
      publications = c(
        pmid, doi, title, journal, date, score, text_hl
      ),
      entities = c(
        entity_id, disease_ontology_id_version, disease_ontology_name,
        hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name,
        inheritance_filter, ndd_phenotype, ndd_phenotype_word,
        entry_date, category, category_id
      )
    ) %>%
    dplyr::ungroup()
}
