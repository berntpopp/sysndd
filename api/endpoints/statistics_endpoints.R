# api/endpoints/statistics_endpoints.R
#
# This file contains all Statistics-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Be sure to source any required helper files at the top (e.g.,
# source("functions/database-functions.R", local = TRUE)) if needed.

## -------------------------------------------------------------------##
## Statistics section
## -------------------------------------------------------------------##

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
#* @param filter    Filters to apply, e.g. "contains(ndd_phenotype_word,Yes)" for NDD entities.
#* @get /entities_over_time
function(res,
         aggregate = "entity_id",
         group = "category",
         summarize = "month",
         filter = "contains(ndd_phenotype_word,Yes)") {
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

  # Log initial count for diagnostics
  initial_count <- nrow(entity_view_coll)
  log_debug("Entities over time: Initial entity_view count = {initial_count}")

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
              unique(inheritance_filter),
              collapse = " | "
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

  # Log filtered count for diagnostics
  filtered_count <- nrow(entity_view_filtered)
  log_debug("Entities over time: After filtering count = {filtered_count}")

  # Summarize by time
  # Note: Using .type = "floor" instead of "ceiling" to avoid shifting dates forward
  entity_view_summarized <- entity_view_filtered %>%
    mutate(count = 1) %>%
    arrange(entry_date) %>%
    group_by(!!rlang::sym(group)) %>%
    summarize_by_time(
      .date_var = entry_date,
      .by       = rlang::sym(summarize),
      .type     = "floor",
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

  # Log final cumulative count for diagnostics
  max_cumulative <- max(entity_view_summarized$cumulative_count)
  log_debug(
    "Entities over time: Final max cumulative count = {max_cumulative}, ",
    "filtered count = {filtered_count}"
  )

  # Meta info
  meta <- tibble::as_tibble(
    list(
      aggregate            = aggregate,
      group                = group,
      summarize            = summarize,
      filter               = filter,
      max_count            = max(entity_view_summarized$count),
      max_cumulative_count = max_cumulative,
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
  require_role(req, res, "Administrator")

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

  total_new <- nrow(sysndd_ndd_entity)
  unique_gns <- n_distinct(sysndd_ndd_entity$hgnc_id)
  day_diff <- as.numeric(difftime(as.Date(end_date), as.Date(start_date), units = "days"))
  avg_day <- ifelse(day_diff > 0, total_new / day_diff, NA)

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
  require_role(req, res, "Administrator")

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
    {
      # Guard rowwise operations against empty tibble
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(date = max(review_date, status_date, na.rm = TRUE)) %>%
          ungroup()
      } else {
        mutate(., date = as.Date(NA))
      }
    } %>%
    dplyr::filter(date >= as.Date(start_date) & date <= as.Date(end_date))

  total_rr <- nrow(sysndd_re_review_entity_connect)
  total_in_pipeline <- pool %>%
    tbl("re_review_entity_connect") %>%
    summarise(n = n()) %>%
    collect() %>%
    pull(n)
  percent_finished <- if (total_in_pipeline > 0) (total_rr / total_in_pipeline) * 100 else 0
  day_diff <- as.numeric(difftime(as.Date(end_date), as.Date(start_date), units = "days"))
  avg_day <- ifelse(day_diff > 0, total_rr / day_diff, NA)

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
  require_role(req, res, "Administrator")

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
  require_role(req, res, "Administrator")

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


## -------------------------------------------------------------------##
## Additional Endpoint: Publication Statistics
## -------------------------------------------------------------------##

#* Get Publication Statistics
#*
#* Aggregates counts on several columns of the publication table:
#* - publication_type
#* - Journal (filter out those with count < min_journal_count)
#* - Lastname (filter out those with count < min_lastname_count)
#* - update_date (aggregated by year/month/etc. using summarize_by_time)
#* - Publication_date (aggregated similarly)
#* - Keywords (split by semicolons, filter out those with count < min_keyword_count)
#*
#* # `Details`
#* This endpoint fetches all rows from the publication table, applies a filter
#* if provided (`filter` parameter), groups by each column, and returns counts
#* for each unique value. For 'update_date' and 'Publication_date', it aggregates
#* via `summarize_by_time`. For 'Journal', 'Lastname', and 'Keywords', it removes
#* entries that do not meet the respective min_count threshold.
#*
#* @tag statistics
#* @serializer json list(na="string")
#*
#* @param time_aggregate A character indicating the time grouping level,
#*   e.g. "year", "month", "week", "day", etc. Defaults to "year".
#* @param filter A filter string in your custom format, e.g. "contains(publication_type,gene_review)".
#* @param min_journal_count Integer: omit journals that occur fewer than this number of times. Defaults to 1.
#* @param min_lastname_count Integer: omit last names that occur fewer than this number of times. Defaults to 1.
#* @param min_keyword_count Integer: omit keywords that occur fewer than this number of times. Defaults to 1.
#*
#* @response 200 OK. A JSON list with aggregated counts
#* @response 500 Internal server error
#*
#* @get /publication_stats
function(req,
         res,
         time_aggregate = "year",
         filter = "",
         min_journal_count = 1,
         min_lastname_count = 1,
         min_keyword_count = 1) {
  # Convert min count parameters to integers (Plumber passes query params as strings)
  min_journal_count <- as.integer(min_journal_count)
  min_lastname_count <- as.integer(min_lastname_count)
  min_keyword_count <- as.integer(min_keyword_count)

  # 1) Generate filter expressions from the user-provided 'filter' string
  filter_exprs <- generate_filter_expressions(filter)

  # 2) Collect from the publication table, then apply filter
  publication_tbl <- pool %>%
    tbl("publication") %>%
    collect() %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # 3) Aggregate counts for publication_type (no min count threshold)
  publication_type_counts <- publication_tbl %>%
    group_by(publication_type) %>%
    summarise(count = n()) %>%
    arrange(desc(count))

  # 4) Aggregate counts for Journal, then filter out below min_journal_count
  journal_counts <- publication_tbl %>%
    filter(!is.na(Journal) & Journal != "") %>%
    group_by(Journal) %>%
    summarise(count = n()) %>%
    filter(count >= min_journal_count) %>%
    arrange(desc(count))

  # 5) Aggregate counts for Lastname, then filter out below min_lastname_count
  last_name_counts <- publication_tbl %>%
    filter(!is.na(Lastname) & Lastname != "") %>%
    group_by(Lastname) %>%
    summarise(count = n()) %>%
    filter(count >= min_lastname_count) %>%
    arrange(desc(count))

  # 6) Summarize update_date by time_aggregate (using summarize_by_time)
  update_date_by_time <- publication_tbl %>%
    filter(!is.na(update_date)) %>%
    mutate(update_date = as.Date(update_date)) %>%
    summarize_by_time(
      .date_var = update_date,
      .by       = time_aggregate,
      count     = n()
    ) %>%
    ungroup() %>%
    rename(update_date = 1) %>%
    mutate(update_date = as.character(update_date)) %>%
    arrange(update_date)

  # 7) Summarize Publication_date by time_aggregate
  publication_date_by_time <- publication_tbl %>%
    filter(!is.na(Publication_date)) %>%
    mutate(Publication_date = as.Date(Publication_date)) %>%
    summarize_by_time(
      .date_var = Publication_date,
      .by       = time_aggregate,
      count     = n()
    ) %>%
    ungroup() %>%
    rename(Publication_date = 1) %>%
    mutate(Publication_date = as.character(Publication_date)) %>%
    arrange(Publication_date)

  # 8) Aggregate counts for Keywords (split by semicolon),
  #    then filter out those below min_keyword_count.
  keyword_counts <- publication_tbl %>%
    filter(!is.na(Keywords) & Keywords != "") %>%
    mutate(Keywords = str_squish(Keywords)) %>%
    tidyr::separate_rows(Keywords, sep = ";") %>%
    mutate(Keywords = str_trim(Keywords)) %>%
    filter(Keywords != "") %>%
    group_by(Keywords) %>%
    summarise(count = n()) %>%
    filter(count >= min_keyword_count) %>%
    arrange(desc(count))

  # 9) Build a result list
  stats_list <- list(
    publication_type_counts      = publication_type_counts,
    journal_counts               = journal_counts,
    last_name_counts             = last_name_counts,
    update_date_aggregated       = update_date_by_time,
    publication_date_aggregated  = publication_date_by_time,
    keyword_counts               = keyword_counts,
    time_aggregate_used          = time_aggregate,
    filter_used                  = filter,
    min_journal_count_used       = min_journal_count,
    min_lastname_count_used      = min_lastname_count,
    min_keyword_count_used       = min_keyword_count
  )

  # 10) Return as JSON
  res$status <- 200
  stats_list
}


#* Get Contributor Leaderboard
#*
#* This endpoint retrieves the top contributors ranked by entity count.
#*
#* # `Details`
#* Aggregates entity counts per user, returning the top N contributors.
#* Supports optional date range filtering.
#*
#* # `Authorization`
#* Only Administrators can access this endpoint.
#*
#* # `Return`
#* Returns a list with 'data' containing user_name and entity_count for each contributor.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* @param top Number of top contributors to return (default: 10)
#* @param start_date Optional start date for filtering (YYYY-MM-DD)
#* @param end_date Optional end date for filtering (YYYY-MM-DD)
#* @param scope Either "all_time" or "range" - determines whether to use date filtering
#* @get /contributor_leaderboard
function(req, res, top = 10, start_date = NULL, end_date = NULL, scope = "all_time") {
  require_role(req, res, "Administrator")

  # Get entity data via status table (entities are linked to users via status_user_id)
  # Use ndd_entity_status to find the initial submitter for each entity
  entity_status <- pool %>%
    tbl("ndd_entity_status") %>%
    select(entity_id, status_user_id, status_date) %>%
    collect() %>%
    group_by(entity_id) %>%
    arrange(status_date) %>%
    slice(1) %>%
    ungroup()

  # Get entity info for filtering
  # ndd_phenotype is stored as 1/0 in the database, not "Yes"/"No"
  entity_info <- pool %>%
    tbl("ndd_entity_view") %>%
    select(entity_id, entry_date, ndd_phenotype) %>%
    collect() %>%
    filter(ndd_phenotype == 1)

  # Join to get entities with their creators
  entity_data <- entity_info %>%
    inner_join(entity_status, by = "entity_id")

  # Apply date range filter if scope is "range" and dates provided
  if (scope == "range" && !is.null(start_date) && !is.null(end_date)) {
    entity_data <- entity_data %>%
      filter(entry_date >= as.Date(start_date) & entry_date <= as.Date(end_date))
  }

  # Get user table for names
  user_data <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, first_name, family_name) %>%
    collect()

  # Aggregate by creator (status_user_id) and join with user names
  leaderboard <- entity_data %>%
    group_by(status_user_id) %>%
    summarise(entity_count = n()) %>%
    arrange(desc(entity_count)) %>%
    head(as.integer(top)) %>%
    left_join(user_data, by = c("status_user_id" = "user_id")) %>%
    mutate(display_name = ifelse(
      !is.na(first_name) & !is.na(family_name),
      paste(first_name, family_name),
      user_name
    )) %>%
    select(user_id = status_user_id, user_name, display_name, entity_count)

  list(
    data = leaderboard,
    meta = list(
      top = as.integer(top),
      scope = scope,
      start_date = start_date,
      end_date = end_date,
      total_contributors = n_distinct(entity_data$status_user_id)
    )
  )
}


#* Get Re-Review Leaderboard
#*
#* Returns the top reviewers by number of submitted re-reviews.
#*
#* # `Details`
#* Aggregates re_review_entity_connect data by user, counting submitted
#* re-reviews per reviewer. Optionally filters by date range.
#*
#* # `Authorization`
#* Only Administrators can access this endpoint.
#*
#* # `Return`
#* Returns a list with 'data' containing user_name and re-review counts.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* @param top Number of top reviewers to return (default: 10)
#* @param start_date Optional start date for filtering (YYYY-MM-DD)
#* @param end_date Optional end date for filtering (YYYY-MM-DD)
#* @param scope Either "all_time" or "range" - determines whether to use date filtering
#* @get /rereview_leaderboard
function(req, res, top = 10, start_date = NULL, end_date = NULL, scope = "all_time") {
  require_role(req, res, "Administrator")

  # Get review dates for filtering
  review_dates <- pool %>%
    tbl("ndd_entity_review") %>%
    select(review_id, review_date) %>%
    collect()

  status_dates <- pool %>%
    tbl("ndd_entity_status") %>%
    select(status_id, status_date) %>%
    collect()

  # Get re-review data with assignments to determine which user did each re-review
  re_review_data <- pool %>%
    tbl("re_review_entity_connect") %>%
    collect() %>%
    left_join(review_dates, by = "review_id") %>%
    left_join(status_dates, by = "status_id") %>%
    {
      # Guard rowwise operations against empty tibble
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(date = max(review_date, status_date, na.rm = TRUE)) %>%
          ungroup()
      } else {
        mutate(., date = as.Date(NA))
      }
    }

  # Get assignments to link batches to users
  assignments <- pool %>%
    tbl("re_review_assignment") %>%
    select(re_review_batch, user_id) %>%
    collect()

  # Join to get user for each re-review
  re_review_with_users <- re_review_data %>%
    inner_join(assignments, by = "re_review_batch")

  # Apply date range filter if scope is "range" and dates provided
  if (scope == "range" && !is.null(start_date) && !is.null(end_date)) {
    re_review_with_users <- re_review_with_users %>%
      filter(date >= as.Date(start_date) & date <= as.Date(end_date))
  }

  # Get user table for names
  user_data <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, first_name, family_name) %>%
    collect()

  # Aggregate by user
  leaderboard <- re_review_with_users %>%
    group_by(user_id) %>%
    summarise(
      total_assigned = n(),
      submitted_count = sum(re_review_submitted == 1, na.rm = TRUE),
      approved_count = sum(re_review_approved == 1, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(submitted_count)) %>%
    head(as.integer(top)) %>%
    left_join(user_data, by = "user_id") %>%
    mutate(display_name = ifelse(
      !is.na(first_name) & !is.na(family_name),
      paste(first_name, family_name),
      user_name
    )) %>%
    dplyr::select(user_id, user_name, display_name, total_assigned, submitted_count, approved_count)

  list(
    data = leaderboard,
    meta = list(
      top = as.integer(top),
      scope = scope,
      start_date = start_date,
      end_date = end_date,
      total_reviewers = n_distinct(re_review_with_users$user_id),
      total_submitted = nrow(re_review_with_users),
      total_approved = sum(re_review_with_users$re_review_approved == 1, na.rm = TRUE)
    )
  )
}
