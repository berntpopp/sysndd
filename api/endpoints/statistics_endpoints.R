# api/endpoints/statistics_endpoints.R
#
# This file contains all Statistics-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Be sure to source any required helper files at the top (e.g.,
# source("functions/database-functions.R", local = TRUE)) if needed.

##-------------------------------------------------------------------##
## Statistics section
##-------------------------------------------------------------------##

#* Get Category Count Statistics
#*
#* This endpoint retrieves statistics for genes with an NDD phenotype.
#*
#* # `Details`
#* Retrieves statistics on entities by category and inheritance type.
#*
#* # `Return`
#* Returns the category count statistics in a tabular form.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* @get /category_count
function(sort = "category_id,-n",
         type = "gene") {
  disease_genes_statistics <- generate_stat_tibble_mem(sort, type)
  disease_genes_statistics
}


#* Get News Entries
#*
#* This endpoint retrieves the most recent entries in the "Definitive" category.
#*
#* # `Details`
#* Returns a small list of newly added definitive genes or entries for
#* display as "news."
#*
#* # `Return`
#* Returns the latest news entries as a data frame.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* @param n Number of latest entries to retrieve.
#* @get /news
function(n = 5) {
  sysndd_db_disease_genes_news <- generate_gene_news_tibble_mem(n)
  sysndd_db_disease_genes_news
}


#* Get Entities Over Time
#*
#* This endpoint retrieves database entry development over time.
#*
#* # `Details`
#* Computes the cumulative number of entities over time, optionally grouped by
#* inheritance or category, to show how many were added in monthly increments.
#*
#* # `Return`
#* Returns a list with a 'meta' part and a 'data' part. 'meta' contains
#* summary info (e.g., max counts), and 'data' contains nested time-series.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* @param aggregate Aggregation level (either 'entity_id' or 'symbol').
#* @param group     Group by 'category', 'inheritance_filter', or 'inheritance_multiple'.
#* @param summarize Time summarization level (e.g. 'month').
#* @param filter    Filters to apply, e.g. "contains(ndd_phenotype_word,Yes),any(inheritance_filter,Autosomal dominant,Autosomal recessive,X-linked)".
#* @get /entities_over_time
function(res,
         aggregate = "entity_id",
         group = "category",
         summarize = "month",
         filter = "contains(ndd_phenotype_word,Yes),any(inheritance_filter,Autosomal dominant,Autosomal recessive,X-linked)") {
  start_time <- Sys.time()

  # Validate input for 'aggregate' and 'group'
  if (!(aggregate %in% c("entity_id", "symbol")) ||
      !(group %in% c("category", "inheritance_filter", "inheritance_multiple"))) {
    res$status <- 400
    res$body <- jsonlite::toJSON(
      auto_unbox = TRUE,
      list(
        status = 400,
        message = "Required 'aggregate' or 'group' parameter not in allowed list."
      )
    )
    return(res)
  }

  if (aggregate == "entity_id" && group == "inheritance_multiple") {
    res$status <- 400
    res$body <- jsonlite::toJSON(
      auto_unbox = TRUE,
      list(
        status = 400,
        message = "Multiple inheritance only sensible when grouping by gene symbol."
      )
    )
    return(res)
  }

  # Generate filter expressions
  filter_exprs <- generate_filter_expressions(filter)

  # Collect and filter data
  entity_view_coll <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()

  entity_view_filtered <- entity_view_coll %>%
    dplyr::filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    arrange(entry_date, entity_id) %>%
    {
      if (aggregate == "symbol") {
        group_by(., symbol) %>%
          mutate(entities_count = n()) %>%
          mutate(inheritance_filter_count = n_distinct(inheritance_filter)) %>%
          mutate(
            inheritance_multiple = str_c(
              unique(inheritance_filter), collapse = " | "
            )
          ) %>%
          ungroup()
      } else {
        .
      }
    } %>%
    {
      if (group == "inheritance_multiple") {
        dplyr::filter(., inheritance_filter_count > 1)
      } else {
        .
      }
    } %>%
    dplyr::arrange(!!rlang::sym(aggregate)) %>%
    dplyr::select(
      !!rlang::sym(aggregate),
      !!rlang::sym(group),
      entry_date
    ) %>%
    {
      if (aggregate == "symbol") {
        group_by(., symbol) %>%
          mutate(entry_date = min(entry_date)) %>%
          ungroup() %>%
          unique()
      } else {
        .
      }
    }

  # Summarize by time
  entity_view_summarized <- entity_view_filtered %>%
    mutate(count = 1) %>%
    arrange(entry_date) %>%
    group_by(!!rlang::sym(group)) %>%
    summarize_by_time(
      .date_var = entry_date,
      .by       = rlang::sym(summarize),
      .type     = "ceiling", 
      count     = sum(count)
    ) %>%
    mutate(cumulative_count = cumsum(count)) %>%
    ungroup() %>%
    mutate(entry_date = strftime(entry_date, "%Y-%m-%d"))

  # Nest the output
  entity_view_nested <- entity_view_summarized %>%
    tidyr::nest(.by = !!rlang::sym(group), .key = "values") %>%
    ungroup() %>%
    dplyr::select("group" = !!rlang::sym(group), values)

  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2), " secs"))

  # Meta info
  meta <- tibble::as_tibble(
    list(
      aggregate            = aggregate,
      group                = group,
      summarize            = summarize,
      filter               = filter,
      max_count            = max(entity_view_summarized$count),
      max_cumulative_count = max(entity_view_summarized$cumulative_count),
      executionTime        = execution_time
    )
  )

  list(meta = meta, data = entity_view_nested)
}


#* Get Updates Statistics
#*
#* This endpoint retrieves statistics for new updates in a given date range.
#*
#* # `Details`
#* Checks how many new entities (and genes) were added and calculates an
#* average-per-day rate.
#*
#* # `Authorization`
#* Only Administrators can access this endpoint.
#*
#* # `Return`
#* Returns a list with counts and averages.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* @param start_date Start date for range (YYYY-MM-DD).
#* @param end_date   End date for range (YYYY-MM-DD).
#* @get /updates
function(req, res, start_date, end_date) {
  # Must be Administrator
  if (is.null(req$user_role) || req$user_role != "Administrator") {
    res$status <- 403
    return(list(error = "Access forbidden. Only administrators can access this endpoint."))
  }

  sysndd_ndd_entity <- pool %>%
    tbl("ndd_entity") %>%
    collect() %>%
    mutate(ndd_phenotype = case_when(
      ndd_phenotype == 1 ~ "Yes",
      ndd_phenotype == 0 ~ "No"
    )) %>%
    dplyr::filter(ndd_phenotype == "Yes") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::filter(entry_date >= as.Date(start_date) & entry_date <= as.Date(end_date))

  total_new  <- nrow(sysndd_ndd_entity)
  unique_gns <- n_distinct(sysndd_ndd_entity$hgnc_id)
  day_diff   <- as.numeric(difftime(as.Date(end_date), as.Date(start_date), units = "days"))
  avg_day    <- ifelse(day_diff > 0, total_new / day_diff, NA)

  list(
    total_new_entities = total_new,
    unique_genes       = unique_gns,
    average_per_day    = avg_day
  )
}


#* Get Re-review Statistics
#*
#* This endpoint retrieves statistics for re-reviews in a given date range.
#*
#* # `Details`
#* Fetches how many re-reviews occurred and some basic metrics.
#*
#* # `Authorization`
#* Only Administrators can access this endpoint.
#*
#* # `Return`
#* Returns a list with total re-reviews, a percentage, etc.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* @param start_date Start date (YYYY-MM-DD).
#* @param end_date   End date (YYYY-MM-DD).
#* @get /rereview
function(req, res, start_date, end_date) {
  if (is.null(req$user_role) || req$user_role != "Administrator") {
    res$status <- 403
    return(list(error = "Access forbidden. Only administrators can access this endpoint."))
  }

  sysndd_review_connect <- pool %>%
    tbl("ndd_entity_review") %>%
    collect() %>%
    dplyr::select(review_id, review_date)

  sysndd_status_connect <- pool %>%
    tbl("ndd_entity_status") %>%
    collect() %>%
    dplyr::select(status_id, status_date)

  sysndd_re_review_entity_connect <- pool %>%
    tbl("re_review_entity_connect") %>%
    collect() %>%
    dplyr::filter(re_review_submitted == 1) %>%
    left_join(sysndd_review_connect, by = c("review_id")) %>%
    left_join(sysndd_status_connect, by = c("status_id")) %>%
    rowwise() %>%
    mutate(date = max(review_date, status_date, na.rm = TRUE)) %>%
    ungroup() %>%
    dplyr::filter(date >= as.Date(start_date) & date <= as.Date(end_date))

  total_rr <- nrow(sysndd_re_review_entity_connect)
  # Example placeholder: dividing total by 3650 for demonstration
  percent_finished <- (total_rr / 3650) * 100
  day_diff         <- as.numeric(difftime(as.Date(end_date), as.Date(start_date), units = "days"))
  avg_day          <- ifelse(day_diff > 0, total_rr / day_diff, NA)

  list(
    total_rereviews       = total_rr,
    percentage_finished   = percent_finished,
    average_per_day       = avg_day
  )
}


#* Get Updated Reviews Statistics
#*
#* This endpoint retrieves the number of reviews that have been updated
#* in a given date range.
#*
#* # `Details`
#* Identifies entity IDs that have >1 reviews, picks the max date, and sees
#* if it falls in the desired date range.
#*
#* # `Authorization`
#* Only Administrators can access this endpoint.
#*
#* # `Return`
#* Returns how many reviews got updated in the time range.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* @param start_date Start date (YYYY-MM-DD).
#* @param end_date   End date (YYYY-MM-DD).
#* @get /updated_reviews
function(req, res, start_date, end_date) {
  if (is.null(req$user_role) || req$user_role != "Administrator") {
    res$status <- 403
    return(list(error = "Access forbidden. Only administrators can access this endpoint."))
  }

  updated_reviews <- pool %>%
    tbl("ndd_entity_review") %>%
    collect() %>%
    group_by(entity_id) %>%
    dplyr::filter(n() > 1) %>%
    summarise(latest_review_date = max(review_date, na.rm = TRUE)) %>%
    dplyr::filter(latest_review_date >= as.Date(start_date) &
                  latest_review_date <= as.Date(end_date))

  list(
    total_updated_reviews = nrow(updated_reviews)
  )
}


#* Get Updated Statuses Statistics
#*
#* This endpoint retrieves the number of statuses that have been updated
#* in a given date range.
#*
#* # `Details`
#* Finds entity IDs with more than one status record, picks the max date,
#* and checks if it falls within the time range.
#*
#* # `Authorization`
#* Only Administrators can access this endpoint.
#*
#* # `Return`
#* Returns how many statuses got updated in the time range.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* @param start_date Start date (YYYY-MM-DD).
#* @param end_date   End date (YYYY-MM-DD).
#* @get /updated_statuses
function(req, res, start_date, end_date) {
  if (is.null(req$user_role) || req$user_role != "Administrator") {
    res$status <- 403
    return(list(error = "Access forbidden. Only administrators can access this endpoint."))
  }

  updated_statuses <- pool %>%
    tbl("ndd_entity_status") %>%
    collect() %>%
    group_by(entity_id) %>%
    dplyr::filter(n() > 1) %>%
    summarise(latest_status_date = max(status_date, na.rm = TRUE)) %>%
    dplyr::filter(latest_status_date >= as.Date(start_date) &
                  latest_status_date <= as.Date(end_date))

  list(
    total_updated_statuses = nrow(updated_statuses)
  )
}

## Statistics section
##-------------------------------------------------------------------##
