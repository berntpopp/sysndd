# Statistics Admin Endpoint Service Layer for SysNDD API
#
# Business logic extracted from the six Administrator-gated routes of
# api/endpoints/statistics_endpoints.R (#346 Wave 3 Task 8). The
# `require_role(req, res, "Administrator")` gate stays in the endpoint
# shells; this file holds the request processing that runs once a caller
# has passed that gate.
#
# These routes back the CHEAP `/statistics` surface (#344): none of the
# functions below may call an external provider fetcher. A static guard in
# tests/testthat/test-unit-statistics-endpoint-services.R scans this file
# (and the sibling public service file) for that pattern.
#
# Uses the global `pool` connection (matches the pre-extraction convention
# in statistics_endpoints.R) rather than dependency-injecting pool, since
# these functions are only ever called from the statistics endpoint shells.

#' New-entities update statistics (service layer)
#'
#' Backing logic for `GET /statistics/updates` (Administrator-only).
#'
#' @param start_date Start date for range (YYYY-MM-DD).
#' @param end_date End date for range (YYYY-MM-DD).
#' @return List with `total_new_entities`, `unique_genes`, `average_per_day`.
#' @export
svc_statistics_admin_updates <- function(start_date, end_date) {
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


#' Re-review statistics (service layer)
#'
#' Backing logic for `GET /statistics/rereview` (Administrator-only).
#'
#' @param start_date Start date (YYYY-MM-DD).
#' @param end_date End date (YYYY-MM-DD).
#' @return List with `total_rereviews`, `percentage_finished`, `average_per_day`.
#' @export
svc_statistics_admin_rereview <- function(start_date, end_date) {
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


#' Updated-reviews statistics (service layer)
#'
#' Backing logic for `GET /statistics/updated_reviews` (Administrator-only).
#' Identifies entity IDs with more than one review, picks the max date, and
#' checks whether it falls within the requested range.
#'
#' @param start_date Start date (YYYY-MM-DD).
#' @param end_date End date (YYYY-MM-DD).
#' @return List with `total_updated_reviews`.
#' @export
svc_statistics_admin_updated_reviews <- function(start_date, end_date) {
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


#' Updated-statuses statistics (service layer)
#'
#' Backing logic for `GET /statistics/updated_statuses` (Administrator-only).
#' Identifies entity IDs with more than one status record, picks the max
#' date, and checks whether it falls within the requested range.
#'
#' @param start_date Start date (YYYY-MM-DD).
#' @param end_date End date (YYYY-MM-DD).
#' @return List with `total_updated_statuses`.
#' @export
svc_statistics_admin_updated_statuses <- function(start_date, end_date) {
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


#' Contributor leaderboard (service layer)
#'
#' Backing logic for `GET /statistics/contributor_leaderboard`
#' (Administrator-only). Aggregates entity counts per initial submitter
#' (`ndd_entity_status.status_user_id`, earliest status row per entity),
#' restricted to NDD-phenotype entities, returning the top N.
#'
#' @param top Number of top contributors to return.
#' @param start_date Optional start date for filtering (YYYY-MM-DD).
#' @param end_date Optional end date for filtering (YYYY-MM-DD).
#' @param scope Either "all_time" or "range".
#' @return List with `data` (leaderboard rows) and `meta`.
#' @export
svc_statistics_admin_contributor_leaderboard <- function(top = 10,
                                                           start_date = NULL,
                                                           end_date = NULL,
                                                           scope = "all_time") {
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


#' Re-review leaderboard (service layer)
#'
#' Backing logic for `GET /statistics/rereview_leaderboard`
#' (Administrator-only). Aggregates `re_review_entity_connect` by assigned
#' user, counting submitted/approved re-reviews.
#'
#' # `Details`
#' Intentionally includes unsubmitted assignments (not just
#' `re_review_submitted == 1`) to support three-segment stacked bars
#' (approved / submitted / not-submitted) in the frontend (v10.5, Phase 81).
#'
#' @param top Number of top reviewers to return.
#' @param start_date Optional start date for filtering (YYYY-MM-DD).
#' @param end_date Optional end date for filtering (YYYY-MM-DD).
#' @param scope Either "all_time" or "range".
#' @return List with `data` (leaderboard rows) and `meta`.
#' @export
svc_statistics_admin_rereview_leaderboard <- function(top = 10,
                                                        start_date = NULL,
                                                        end_date = NULL,
                                                        scope = "all_time") {
  # Get review dates for filtering
  review_dates <- pool %>%
    tbl("ndd_entity_review") %>%
    select(review_id, review_date) %>%
    collect()

  status_dates <- pool %>%
    tbl("ndd_entity_status") %>%
    select(status_id, status_date) %>%
    collect()

  # Get ALL re-review assignments (not just submitted ones); see @details above.
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
