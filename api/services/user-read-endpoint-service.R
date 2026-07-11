# api/services/user-read-endpoint-service.R
#
# Endpoint service for the read-only user routes in
# endpoints/user_endpoints.R: the summary table, per-user contributions,
# the allowed-role list, and the role-filtered user list. All `require_role()`
# gates (and the contributions self/other check) stay in the endpoint shells;
# these `svc_` functions hold only the request-processing logic behind them.

#' Build the paginated/filterable/sortable user summary table.
#'
#' Behind `GET /api/user/table`. `req` is only used to branch visibility on
#' the caller's role (Administrator sees every column; everyone else who
#' clears the Curator gate sees only unapproved users).
#'
#' @param req Plumber request (needs `req$user_role`).
#' @param filter Filter string (e.g., "user_name:contains:john").
#' @param sort Sort string (e.g., "+user_name" or "-email").
#' @param page_after Cursor after which entries are shown.
#' @param page_size Page size in cursor pagination (or "all").
#' @param fspec Comma-separated field specification for table columns.
#' @return List with `links`, `meta`, and `data`.
svc_user_table_list <- function(req, filter, sort, page_after, page_size, fspec) {
  start_time <- Sys.time()

  sort_exprs <- generate_sort_expressions(sort, unique_id = "user_id")
  filter_exprs <- generate_filter_expressions(filter)

  user_columns <- c(
    "user_id", "user_name", "email", "orcid", "abbreviation", "first_name",
    "family_name", "comment", "terms_agreed", "created_at", "user_role", "approved"
  )

  if (req$user_role == "Administrator") {
    user_table <- pool %>%
      tbl("user") %>%
      select(dplyr::all_of(user_columns)) %>%
      collect()
  } else {
    # Curator sees only unapproved users
    user_table <- pool %>%
      tbl("user") %>%
      select(dplyr::all_of(user_columns)) %>%
      filter(approved == 0) %>%
      collect()
  }

  if (filter_exprs != "") {
    user_table <- user_table %>%
      filter(!!!rlang::parse_exprs(filter_exprs))
  }

  user_table <- user_table %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  pagination_info <- generate_cursor_pag_inf_safe(
    user_table,
    page_size,
    page_after,
    "user_id"
  )

  end_time <- Sys.time()
  execution_time <- as.character(
    paste0(round(end_time - start_time, 2), " secs")
  )

  fspec_fields <- strsplit(fspec, ",")[[1]]
  fspec_parsed <- lapply(fspec_fields, function(field) {
    field <- trimws(field)
    label <- switch(field,
      user_id = "ID",
      user_name = "Username",
      email = "E-mail",
      user_role = "Role",
      approved = "Approved",
      abbreviation = "Abbreviation",
      first_name = "First Name",
      family_name = "Family Name",
      comment = "Comment",
      created_at = "Created",
      orcid = "ORCID",
      terms_agreed = "Terms Agreed",
      field # default: use field name as label
    )
    list(
      key = field,
      label = label,
      sortable = TRUE,
      filterable = TRUE,
      class = "text-start"
    )
  })

  meta <- pagination_info$meta %>%
    add_column(tibble::as_tibble(list(
      fspec = list(fspec_parsed),
      executionTime = execution_time
    )))

  list(
    links = pagination_info$links,
    meta = meta,
    data = pagination_info$data
  )
}

#' Count a user's active reviews and active statuses.
#'
#' Behind `GET /api/user/<user_id>/contributions`. The caller's own-vs-other
#' authorization check lives in the endpoint shell.
#'
#' @param user_id Target user id (character/integer, as received from Plumber).
#' @return List with `user_id`, `active_status`, and `active_reviews`.
svc_user_contributions <- function(user_id) {
  user_requested <- user_id

  active_user_reviews <- pool %>%
    tbl("ndd_entity_review") %>%
    filter(is_primary == 1) %>%
    filter(review_user_id == user_requested) %>%
    select(review_id) %>%
    collect() %>%
    tally() %>%
    select(active_reviews = n)

  active_user_status <- pool %>%
    tbl("ndd_entity_status") %>%
    filter(is_active == 1) %>%
    filter(status_user_id == user_requested) %>%
    select(status_id) %>%
    collect() %>%
    tally() %>%
    select(active_status = n)

  list(
    user_id = user_requested,
    active_status = active_user_status$active_status,
    active_reviews = active_user_reviews$active_reviews
  )
}

#' List the allowed roles, hiding Administrator from non-Administrators.
#'
#' Behind `GET /api/user/role_list`.
#'
#' @param req Plumber request (needs `req$user_role`).
#' @return Tibble with a single `role` column.
svc_user_role_list <- function(req) {
  if (req$user_role == "Administrator") {
    role_list <- tibble::as_tibble(user_status_allowed) %>%
      select(role = value)
    role_list
  } else {
    # Curator sees all except Administrator
    role_list <- tibble::as_tibble(user_status_allowed) %>%
      select(role = value) %>%
      filter(role != "Administrator")
    role_list
  }
}

#' List approved users filtered by a comma-separated set of roles.
#'
#' Behind `GET /api/user/list`. Sets a 400 problem body directly on `res` and
#' returns it when any submitted role is outside the allow-list, matching the
#' pre-extraction handler's response shape.
#'
#' @param res Plumber response (mutated on the 400 path).
#' @param roles Comma-separated roles string.
#' @return Tibble of matching approved users, or `res` on validation failure.
svc_user_list_by_roles <- function(res, roles) {
  roles_list <- str_trim(str_split(str_squish(roles), ",")[[1]])
  roles_allowed_check <- all(roles_list %in% user_status_allowed)

  if (!roles_allowed_check) {
    res$status <- 400
    res$body <- jsonlite::toJSON(
      auto_unbox = TRUE,
      list(
        status = 400,
        message = "Some submitted roles are not in the allowed roles list."
      )
    )
    return(res)
  }

  user_table_roles <- pool %>%
    tbl("user") %>%
    filter(approved == 1) %>%
    filter(user_role %in% roles_list) %>%
    select(user_id, user_name, user_role) %>%
    collect()
  user_table_roles
}
