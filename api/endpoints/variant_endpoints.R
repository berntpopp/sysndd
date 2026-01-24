# api/endpoints/variant_endpoints.R
#
# This file contains all Variant-related endpoints, extracted from
# the original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible (e.g., two-space indentation, meaningful
# function names, etc.).

## -------------------------------------------------------------------##
## Variant endpoints
## -------------------------------------------------------------------##

#* Browse Entities by Variant
#*
#* # `Details`
#* This endpoint retrieves a list of entities associated with specified variants,
#* using a helper function like `generate_variant_entities_list()` to handle
#* sorting, filtering, pagination, and field selection.
#*
#* # `Return`
#* Returns a cursor pagination object containing links, meta, and data.
#*
#* @tag variant
#* @serializer json list(na="string")
#*
#* @param sort:str Output column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#* @param fields:str Comma separated list of output columns.
#* @param page_after:str Cursor after which to show entries in pagination.
#* @param page_size:str Page size in pagination.
#* @param fspec:str Fields to generate field specification.
#* @param format:str Output format, either "json" or "xlsx".
#*
#* @get browse
function(req,
         res,
         sort = "entity_id",
         filter = "",
         fields = "",
         page_after = "0",
         page_size = "10",
         fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,modifier_variant_id,details", # nolint: line_length_linter
         format = "json") {
  # Set response serializer
  res$serializer <- serializers[[format]]

  # Call the helper function that returns a list with $links, $meta, $data
  variant_entities_list <- generate_variant_entities_list(
    sort,
    filter,
    fields,
    page_after,
    page_size,
    fspec
  )

  # If XLSX requested, convert the data to an attachment
  if (format == "xlsx") {
    creation_date <- strftime(
      as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S"
    )
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
      str_replace_all("_api_", "")
    filename <- file.path(paste0(base_filename, "_", creation_date, ".xlsx"))

    bin <- generate_xlsx_bin(variant_entities_list, base_filename)
    as_attachment(bin, filename)
  } else {
    variant_entities_list
  }
}


#* Get Correlation between Variants
#*
#* This endpoint returns a correlation-like matrix between variants
#* based on the data in the database.
#*
#* # `Details`
#* It first gathers entity-variant associations via
#* `generate_variant_entities_list()`, then constructs a matrix
#* of presence/absence to compute correlation (or another metric).
#*
#* # `Return`
#* A data frame (long format) containing columns like "x", "x_id",
#* "y", "y_id", and "value" for the correlation matrix.
#*
#* @tag variant
#* @serializer json list(na="string")
#*
#* @param filter:str A string representing a filter query to use
#*                  when selecting data from the database.
#*
#* @get correlation
function(res,
         filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)") {
  # 1) Use helper to get a data frame with columns (entity_id, modifier_variant_id, etc.)
  variant_entities_data <- generate_variant_entities_list(filter = filter)$data %>%
    # Convert comma-separated variant IDs to separate rows
    separate_rows(modifier_variant_id, sep = ",") %>%
    unique()

  # 2) Get the variation_ontology_list so we can match vario_id -> vario_name
  variation_ontology_list_tbl <- pool %>%
    tbl("variation_ontology_list") %>%
    collect() # columns: vario_id, vario_name, definition, etc.

  # 3) Parse out the vario_id from e.g. "1-VariO:0001" (leading digits-dash)
  db_variants <- variant_entities_data %>%
    mutate(vario_id = str_remove(modifier_variant_id, "^[0-9]+-")) %>%
    # Join on vario_id
    left_join(variation_ontology_list_tbl, by = "vario_id") %>%
    # Rename vario_name -> variant_name for pivot convenience
    rename(variant_name = vario_name) %>%
    select(entity_id, vario_id, variant_name)

  # 4) Construct a presence/absence matrix
  db_variants_matrix <- db_variants %>%
    mutate(has_variant = 1) %>%
    select(entity_id, variant_name, has_variant) %>%
    unique() %>%
    pivot_wider(names_from = variant_name, values_from = has_variant) %>%
    replace(is.na(.), 0) %>%
    select(-entity_id)

  # Edge case: If no variant columns remain, return an empty tibble
  if (ncol(db_variants_matrix) == 0) {
    return(tibble::tibble(
      x = character(),
      x_id = character(),
      y = character(),
      y_id = character(),
      value = numeric()
    ))
  }

  # 5) Compute correlation
  db_variants_corr <- round(cor(db_variants_matrix), 2)

  # 6) Melt correlation matrix to long form
  variants_corr_melted <- reshape2::melt(db_variants_corr) %>%
    select(x = Var1, y = Var2, value)

  # 7) Build a local lookup for (vario_id, variant_name) so we can rejoin
  local_vario_lookup <- db_variants %>%
    distinct(vario_id, variant_name) %>%
    rename(x_id = vario_id, x = variant_name)

  # Join 'x'
  variants_corr_melted_ids <- variants_corr_melted %>%
    left_join(local_vario_lookup, by = "x") %>%
    rename(x_vario_id = x_id) %>%
    # Join 'y' by a second rename
    left_join(local_vario_lookup %>%
                rename(y = x, y_vario_id = x_id), by = "y") %>%
    select(
      x, x_vario_id,
      y, y_vario_id,
      value
    )

  variants_corr_melted_ids
}


#* Get Counts of Variants in Annotated Entities
#*
#* This endpoint returns the counts of variants across annotated entities
#* based on data in the database.
#*
#* # `Details`
#* Similar approach to the correlation endpoint, but instead of computing
#* correlation, it simply tallies how many times each variant (vario_id) appears.
#*
#* # `Return`
#* A data frame with columns "variant_name", "vario_id", and "count".
#*
#* @tag variant
#* @serializer json list(na="string")
#*
#* @param filter:str Filter expression to restrict the entity set.
#*
#* @get count
function(res,
         filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)") {
  # 1) Use helper to get entity-variant associations
  variant_entities_data <- generate_variant_entities_list(filter = filter)$data %>%
    separate_rows(modifier_variant_id, sep = ",") %>%
    unique()

  # 2) Pull variation_ontology_list
  variation_ontology_list_tbl <- pool %>%
    tbl("variation_ontology_list") %>%
    collect()

  # 3) Parse vario_id and join
  db_variants <- variant_entities_data %>%
    mutate(vario_id = str_remove(modifier_variant_id, "^[0-9]+-")) %>%
    left_join(variation_ontology_list_tbl, by = "vario_id") %>%
    rename(variant_name = vario_name) %>%
    select(entity_id, vario_id, variant_name)

  # 4) Count occurrences
  db_variants_count <- db_variants %>%
    group_by(vario_id, variant_name) %>%
    tally() %>%
    arrange(desc(n)) %>%
    ungroup() %>%
    # rename for clarity: we store vario_id + variant_name + count
    select(vario_id, variant_name, count = n)

  db_variants_count
}
