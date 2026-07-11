# api/endpoints/statistics_endpoints.R
#
# This file contains all Statistics-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Be sure to source any required helper files at the top (e.g.,
# source("functions/database-functions.R", local = TRUE)) if needed.
#
# Request processing lives in api/services/statistics-public-endpoint-service.R
# (public routes) and api/services/statistics-admin-endpoint-service.R
# (Administrator-gated routes, #346 Wave 3 Task 8). This file stays a thin
# authorization/delegation shell: role gates stay here, everything else
# delegates to the named `svc_statistics_*` functions.

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
  svc_statistics_category_count(sort, type)
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
  svc_statistics_gene_news(n)
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
  svc_statistics_entities_over_time(res, aggregate, group, summarize, filter)
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

  svc_statistics_admin_updates(start_date, end_date)
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

  svc_statistics_admin_rereview(start_date, end_date)
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

  svc_statistics_admin_updated_reviews(start_date, end_date)
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

  svc_statistics_admin_updated_statuses(start_date, end_date)
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
  svc_statistics_publication_stats(
    res,
    time_aggregate,
    filter,
    min_journal_count,
    min_lastname_count,
    min_keyword_count
  )
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

  svc_statistics_admin_contributor_leaderboard(top, start_date, end_date, scope)
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

  svc_statistics_admin_rereview_leaderboard(top, start_date, end_date, scope)
}
