# api/endpoints/phenotype_endpoints.R
#
# This file contains all Phenotype-related endpoints, extracted from
# the original sysndd_plumber.R. It follows the Google R Style Guide
# conventions where possible (e.g., two-space indentation, meaningful
# function names, etc.).

## -------------------------------------------------------------------##
## Phenotype endpoints
## -------------------------------------------------------------------##

#* Get a List of Entities Associated with a List of Phenotypes
#*
#* # `Details`
#* This endpoint retrieves a list of entities associated with specified phenotypes
#* based on the data in the database. It uses helper functions like
#* generate_phenotype_entities_list() to filter and paginate results.
#*
#* # `Return`
#* Returns a cursor pagination object containing links, meta, and data.
#*
#* @tag phenotype
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
#* @get entities/browse
function(req,
         res,
         sort = "entity_id",
         filter = "",
         fields = "",
         `page_after` = "0",
         `page_size` = "10",
         fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details", # nolint: line_length_linter
         format = "json") {
  res$serializer <- serializers[[format]]

  # Call helper function
  phenotype_entities_list <- generate_phenotype_entities_list(
    sort,
    filter,
    fields,
    `page_after`,
    `page_size`,
    fspec
  )

  if (format == "xlsx") {
    creation_date <- strftime(
      as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S"
    )
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
      str_replace_all("_api_", "")
    filename <- file.path(paste0(base_filename, "_", creation_date, ".xlsx"))

    bin <- generate_xlsx_bin(phenotype_entities_list, base_filename)
    as_attachment(bin, filename)
  } else {
    phenotype_entities_list
  }
}


#* Get Correlation between Phenotypes
#*
#* This endpoint returns the correlation matrix between phenotypes
#* based on the data in the database.
#*
#* # `Details`
#* It first gathers entity-phenotype associations via
#* generate_phenotype_entities_list(), then compiles a correlation matrix
#* (long format) with columns "x", "x_id", "y", "y_id", and "value".
#*
#* # `Note on Cluster Navigation`
#* This endpoint returns correlations between **individual phenotypes** (HPO terms),
#* not entity clusters. There is no direct mapping from a phenotype pair to a
#* cluster_id because:
#* - Phenotypes are features used for clustering
#* - Clusters are groups of entities (genes)
#* - A phenotype can appear in multiple entity clusters
#*
#* For cluster-based navigation, use the phenotype_clustering endpoint which
#* groups entities by phenotype similarity. This correlation data is best used
#* for filtering the phenotype table by co-occurring HPO terms.
#*
#* # `Return`
#* A data frame containing the correlation matrix between phenotypes with columns:
#* - x: First phenotype name (HPO_term)
#* - x_id: First phenotype ID (e.g., "HP:0001249")
#* - y: Second phenotype name (HPO_term)
#* - y_id: Second phenotype ID
#* - value: Correlation coefficient (-1 to 1)
#*
#* @tag phenotype
#* @serializer json list(na="string")
#*
#* @param filter:str A string representing a filter query to use
#*                  when selecting data from the database.
#*
#* @get correlation
function(res,
         filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)") {
  phenotype_entities_data <- generate_phenotype_entities_list(filter = filter)$data %>%
    separate_rows(modifier_phenotype_id, sep = ",") %>%
    unique()

  phenotype_list_tbl <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  sysndd_db_phenotypes <- phenotype_entities_data %>%
    filter(str_detect(modifier_phenotype_id, "1-")) %>%
    mutate(phenotype_id = str_remove(modifier_phenotype_id, "[1-4]-")) %>%
    filter(phenotype_id != "HP:0001249") %>%
    left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
    select(entity_id, phenotype_id, HPO_term)

  sysndd_db_phenotypes_matrix <- sysndd_db_phenotypes %>%
    select(-phenotype_id) %>%
    mutate(has_HPO_term = 1) %>%
    unique() %>%
    pivot_wider(names_from = HPO_term, values_from = has_HPO_term) %>%
    replace(is.na(.), 0) %>%
    select(-entity_id)

  sysndd_db_phenotypes_corr <- round(cor(sysndd_db_phenotypes_matrix), 2)
  phenotypes_corr_melted <- melt(sysndd_db_phenotypes_corr) %>%
    select(x = Var1, y = Var2, value)

  phenotype_list_join <- phenotype_list_tbl %>%
    select(phenotype_id, HPO_term)

  phenotypes_corr_melted_ids <- phenotypes_corr_melted %>%
    left_join(phenotype_list_join, by = c("x" = "HPO_term")) %>%
    select(x, y, value, x_id = phenotype_id) %>%
    left_join(phenotype_list_join, by = c("y" = "HPO_term")) %>%
    select(x, x_id, y, y_id = phenotype_id, value)

  # Note: cluster_id is not included because phenotype pairs don't map to
  # entity clusters (see documentation above). Frontend should link to
  # /Phenotypes/ filtered by phenotype pair.
  phenotypes_corr_melted_ids
}


#* Get Counts of Phenotypes in Annotated Entities
#*
#* This endpoint returns the counts of phenotypes in annotated entities
#* based on data in the database.
#*
#* # `Details`
#* Similar approach to the correlation endpoint, but instead of computing
#* correlation, it simply tallies how many times each phenotype appears.
#*
#* # `Return`
#* A data frame with columns "HPO_term", "phenotype_id", and "count".
#*
#* @tag phenotype
#* @serializer json list(na="string")
#*
#* @param filter:str Filter expression to restrict the entity set.
#*
#* @get count
function(res,
         filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)") {
  phenotype_entities_data <- generate_phenotype_entities_list(filter = filter)$data %>%
    separate_rows(modifier_phenotype_id, sep = ",") %>%
    unique()

  phenotype_list_tbl <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  sysndd_db_phenotypes <- phenotype_entities_data %>%
    mutate(phenotype_id = str_remove(modifier_phenotype_id, "[1-5]-")) %>%
    filter(phenotype_id != "HP:0001249") %>%
    left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
    select(entity_id, phenotype_id, HPO_term)

  sysndd_db_phenotypes_count <- sysndd_db_phenotypes %>%
    group_by(HPO_term, phenotype_id) %>%
    tally() %>%
    arrange(desc(n)) %>%
    ungroup() %>%
    select(HPO_term, phenotype_id, count = n)

  sysndd_db_phenotypes_count
}
