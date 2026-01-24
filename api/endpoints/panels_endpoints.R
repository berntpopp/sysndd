# api/endpoints/panels_endpoints.R
#
# This file contains all panel-related endpoints extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions where
# possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Make sure to source any required helpers or libraries at the top if needed.

## -------------------------------------------------------------------##
## Panels endpoints
## -------------------------------------------------------------------##

#* Get List of All Panel Filtering Options
#*
#* This endpoint retrieves a list of all available filtering options for panels.
#* e.g., categories, inheritance, columns.
#*
#* # `Details`
#* Gathers data from the DB (e.g., categories, inheritance, columns).
#*
#* # `Return`
#* Returns lists of categories, inheritance terms, and columns.
#*
#* @tag panels
#* @serializer json list(na="string")
#* @get options
function() {
  categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    select(category) %>%
    collect() %>%
    filter(category != "not applicable") %>%
    add_row(category = "All") %>%
    arrange(category)

  inheritance_list <- tibble::as_tibble(inheritance_input_allowed) %>%
    select(inheritance = value) %>%
    arrange(inheritance)

  columns_list <- tibble::as_tibble(output_columns_allowed) %>%
    select(column = value)

  options <- tibble(
    lists = c("categories_list", "inheritance_list", "columns_list"),
    options = list(
      tibble(value = categories_list$category),
      tibble(value = inheritance_list$inheritance),
      tibble(value = columns_list$column)
    )
  )

  options
}


#* Browse Panel Data
#*
#* This endpoint retrieves panel data based on filters, sorting, etc.
#*
#* # `Details`
#* Allows specifying category, inheritance, sorting, fields, and so on.
#*
#* # `Return`
#* Returns the filtered and sorted panel data.
#*
#* @tag panels
#* @serializer json list(na="string")
#*
#* @param sort The column for sorting.
#* @param filter Filters to apply.
#* @param fields Output columns to include.
#* @param page_after Cursor for pagination.
#* @param page_size Page size in pagination.
#* @param max_category Logical indicating if only the maximum category is used.
#* @param format Output format ("json" or "xlsx").
#*
#* @get browse
function(req,
         res,
         sort = "symbol",
         filter = "equals(category,'Definitive'),any(inheritance_filter,'Autosomal dominant','Autosomal recessive','X-linked','Other')",
         fields = "category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38",
         `page_after` = 0,
         `page_size` = "all",
         max_category = TRUE,
         format = "json") {
  res$serializer <- serializers[[format]]
  max_category <- as.logical(max_category)

  panels_list <- generate_panels_list(
    sort,
    filter,
    fields,
    `page_after`,
    `page_size`,
    max_category
  )

  if (format == "xlsx") {
    creation_date <- strftime(
      as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S"
    )
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
      str_replace_all("_api_", "")
    filename <- file.path(paste0(base_filename, "_", creation_date, ".xlsx"))

    bin <- generate_xlsx_bin(panels_list, base_filename)
    as_attachment(bin, filename)
  } else {
    panels_list
  }
}
