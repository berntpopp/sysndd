# api/services/re-review-query-endpoint-service.R
#
# Endpoint-orchestration layer for the READ-ONLY re-review endpoints
# (`GET table`, `GET assignment_table`, `GET entities/available`).
#
# Extracted from api/endpoints/re_review_endpoints.R (#346) to bring the
# endpoint file under the 600-line ceiling. This file holds the DB
# query/shaping logic that used to live inline in the endpoint bodies;
# the Reviewer/Curator role gates stay route-local in the endpoint file.
#
# Functions here take `pool` (and any already-parsed request values) as
# explicit arguments rather than reading `req`/globals directly, so they
# can be unit tested with a mocked pool or synthetic data frames.

#' Which re_review_entity_connect filter mode applies to a `GET table`
#' request, given the (already role-gated) curate/refused flags.
#'
#' `refused` takes priority over `curate` — mirrors the original inline
#' `if (refused) ... else if (curate) ... else ...` branch exactly.
#'
#' @return One of "refused", "curate", "reviewer_queue".
svc_re_review_table_filter_mode <- function(curate, refused) {
  if (isTRUE(refused)) {
    "refused"
  } else if (isTRUE(curate)) {
    "curate"
  } else {
    "reviewer_queue"
  }
}

#' Whether the `re_review_assignment` lazy query should be scoped to the
#' requesting user (the plain Reviewer queue) or left unfiltered (the
#' Curator curate/refused surfaces, which see all assignments).
svc_re_review_table_scope_to_user <- function(curate, refused) {
  !isTRUE(curate) && !isTRUE(refused)
}

#' Build the collected, filtered, sorted re-review overview rows for
#' `GET table`.
#'
#' Mirrors the original endpoint body: six-table lazy join, optional SQL
#' filter pushdown via `filter`, with a collect-then-filter fallback on
#' translation errors. `requesting_user_id` is intentionally NOT named
#' `user_id` — that name collides with the `re_review_assignment.user_id`
#' column under dbplyr's data-masking NSE and would silently compare the
#' column to itself.
#'
#' @param filter Filter expression string (see generate_filter_expressions).
#' @param curate Logical: curator "curated" surface.
#' @param refused Logical: curator "refused / needs specialist" surface.
#' @param requesting_user_id Integer id of the authenticated user.
#' @param pool Database connection pool.
#' @return Data frame of re-review overview rows, arranged by
#'   `re_review_entity_id`.
svc_re_review_table_query <- function(filter, curate, refused, requesting_user_id, pool) {
  filter_exprs <- generate_filter_expressions(filter)
  filter_mode <- svc_re_review_table_filter_mode(curate, refused)
  scope_to_user <- svc_re_review_table_scope_to_user(curate, refused)

  re_review_entity_connect <- pool %>%
    tbl("re_review_entity_connect") %>%
    filter(re_review_approved == 0) %>%
    {
      switch(filter_mode,
        refused = filter(., re_review_refused == 1),
        curate  = filter(., re_review_submitted == 1, re_review_refused == 0),
        filter(., re_review_submitted == 0, re_review_refused == 0)
      )
    }

  re_review_assignment <- pool %>%
    tbl("re_review_assignment") %>%
    {
      if (scope_to_user) filter(., user_id == requesting_user_id) else .
    }

  ndd_entity_view <- pool %>%
    tbl("ndd_entity_view")

  ndd_entity_status_category <- pool %>%
    tbl("ndd_entity_status") %>%
    select(status_id, category_id)

  ndd_entity_status_categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list")

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, user_role)

  review_user_collected <- pool %>%
    tbl("ndd_entity_review") %>%
    left_join(user_table, by = c("review_user_id" = "user_id")) %>%
    select(
      review_id,
      review_date,
      review_user_id,
      review_user_name = user_name,
      review_user_role = user_role,
      review_approving_user_id = approving_user_id
    )

  status_user_collected <- pool %>%
    tbl("ndd_entity_status") %>%
    left_join(user_table, by = c("status_user_id" = "user_id")) %>%
    select(
      status_id,
      status_date,
      status_user_id,
      status_user_name = user_name,
      status_user_role = user_role,
      status_approving_user_id = approving_user_id
    )

  # Build the lazy joined query, then push the user filter to SQL when one is
  # provided so we don't collect the full 6-table join just to drop most rows
  # in R. Falls back to the legacy collect-then-filter path on translation
  # errors. No fspec contract on this endpoint, so unconditional pushdown is safe.
  refused_user_collected <- pool %>%
    tbl("user") %>%
    select(
      re_review_refused_user_id = user_id,
      re_review_refused_user_name = user_name
    )

  re_review_user_list_lazy <- re_review_entity_connect %>%
    inner_join(re_review_assignment, by = c("re_review_batch")) %>%
    select(
      re_review_entity_id,
      entity_id,
      re_review_review_saved,
      re_review_status_saved,
      re_review_submitted,
      re_review_approved,
      re_review_refused,
      re_review_refusal_comment,
      re_review_refused_user_id,
      re_review_refused_date,
      status_id,
      review_id
    ) %>%
    left_join(refused_user_collected, by = c("re_review_refused_user_id")) %>%
    inner_join(ndd_entity_view, by = c("entity_id")) %>%
    select(-category_id, -category) %>%
    inner_join(ndd_entity_status_category, by = c("status_id")) %>%
    inner_join(ndd_entity_status_categories_list, by = c("category_id")) %>%
    inner_join(review_user_collected, by = c("review_id")) %>%
    inner_join(status_user_collected, by = c("status_id"))

  has_filter <- length(filter_exprs) > 0 && nzchar(filter_exprs[[1]])
  if (has_filter) {
    tryCatch(
      re_review_user_list_lazy %>%
        filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        collect() %>%
        arrange(re_review_entity_id),
      error = function(e) {
        message(sprintf(
          "[re-review-table] SQL filter pushdown failed (%s); falling back",
          conditionMessage(e)
        ))
        re_review_user_list_lazy %>%
          collect() %>%
          arrange(re_review_entity_id) %>%
          filter(!!!rlang::parse_exprs(filter_exprs))
      }
    )
  } else {
    re_review_user_list_lazy %>%
      collect() %>%
      arrange(re_review_entity_id)
  }
}

#' Wrap a collected re-review overview data frame into the cursor
#' pagination envelope `GET table` returns.
#'
#' Pure (no I/O): operates on an already-collected data frame, so it is
#' unit-testable without a database.
svc_re_review_paginate <- function(re_review_user_list, page_size, page_after) {
  pagination_info <- generate_cursor_pag_inf_safe(
    re_review_user_list,
    page_size,
    page_after,
    "re_review_entity_id"
  )

  list(
    links = pagination_info$links,
    meta = pagination_info$meta,
    data = pagination_info$data
  )
}

#' Per-batch totals for `GET assignment_table` (re_review_entity_connect
#' side): sums the save/submit/approve counters and an entity_count of 1
#' per row, grouped by batch.
svc_re_review_assignment_entity_summary <- function(pool) {
  pool %>%
    tbl("re_review_entity_connect") %>%
    select(
      re_review_batch,
      re_review_review_saved,
      re_review_status_saved,
      re_review_submitted,
      re_review_approved
    ) %>%
    group_by(re_review_batch) %>%
    collect() %>%
    mutate(entity_count = 1) %>%
    summarize_at(vars(re_review_review_saved:entity_count), sum)
}

#' `re_review_assignment` left-joined to `user`, collected (the assignee
#' side of `GET assignment_table`).
svc_re_review_assignment_user_table <- function(pool) {
  re_review_assignment_table <- pool %>%
    tbl("re_review_assignment")

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name)

  re_review_assignment_table %>%
    left_join(user_table, by = c("user_id")) %>%
    collect()
}

#' Combine the two already-collected `GET assignment_table` halves into
#' the final response shape.
#'
#' Pure (no I/O): both inputs are plain data frames, so this is
#' unit-testable without a database. Returns a bare data frame — plumber
#' serializes it as a JSON array (ManageReReview.vue reads
#' `response.data` directly via `Array.isArray(data)`), not a
#' list-wrapped envelope. Do not wrap this in `list(...)`.
svc_re_review_assignment_table_combine <- function(assignment_user_df, entity_connect_summary_df) {
  assignment_user_df %>%
    left_join(entity_connect_summary_df, by = c("re_review_batch")) %>%
    select(
      assignment_id,
      user_id,
      user_name,
      re_review_batch,
      re_review_review_saved,
      re_review_status_saved,
      re_review_submitted,
      re_review_approved,
      entity_count
    ) %>%
    arrange(user_id)
}

#' Full `GET assignment_table` body: fetch both halves and combine.
svc_re_review_assignment_table_endpoint <- function(pool) {
  entity_connect_summary <- svc_re_review_assignment_entity_summary(pool)
  assignment_user <- svc_re_review_assignment_user_table(pool)
  svc_re_review_assignment_table_combine(assignment_user, entity_connect_summary)
}

#' `GET entities/available` body. Thin pass-through to the existing
#' `available_entities()` domain service (re-review-service.R), which
#' already owns search/pagination/validation.
svc_re_review_entities_available <- function(q, page, page_size, pool) {
  available_entities(q, page, page_size, pool)
}
