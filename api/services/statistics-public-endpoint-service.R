# Statistics Public Endpoint Service Layer for SysNDD API
#
# Business logic extracted from the four public routes of
# api/endpoints/statistics_endpoints.R (#346 Wave 3 Task 8). Endpoint shells
# stay thin authorization/delegation wrappers; this file holds the actual
# request processing so the endpoint file can stay under the file-size
# ceiling.
#
# These routes back the CHEAP `/statistics` surface (#344): none of the
# functions below may call an external provider fetcher. A static guard in
# tests/testthat/test-unit-statistics-endpoint-services.R scans this file
# (and the sibling admin service file) for that pattern.
#
# Uses the global `pool` connection (matches the pre-extraction convention
# in statistics_endpoints.R) rather than dependency-injecting pool, since
# these functions are only ever called from the statistics endpoint shells.

#' Category count statistics (service layer)
#'
#' Thin wrapper around the memoised `generate_stat_tibble_mem()` cache used
#' by `GET /statistics/category_count`.
#'
#' @param sort Sort spec, e.g. "category_id,-n".
#' @param type Either "gene" or another supported aggregation type.
#' @return Tibble of category count statistics.
#' @export
svc_statistics_category_count <- function(sort, type) {
  generate_stat_tibble_mem(sort, type)
}


#' Gene news statistics (service layer)
#'
#' Thin wrapper around the memoised `generate_gene_news_tibble_mem()` cache
#' used by `GET /statistics/news`.
#'
#' @param n Number of latest entries to retrieve.
#' @return Tibble of latest "Definitive" category entries.
#' @export
svc_statistics_gene_news <- function(n) {
  generate_gene_news_tibble_mem(n)
}


#' Entities-over-time statistics (service layer)
#'
#' Backing logic for `GET /statistics/entities_over_time`: validates
#' `aggregate`/`group`, pushes the caller filter to SQL when possible, then
#' aggregates and time-buckets the result. On invalid input this mutates
#' `res` to a 400 and returns the Plumber response object directly (matching
#' the pre-extraction handler contract), otherwise returns
#' `list(meta = ..., data = ...)`.
#'
#' @param res Plumber response object.
#' @param aggregate Aggregation level ("entity_id" or "symbol").
#' @param group Group by "category", "inheritance_filter", or
#'   "inheritance_multiple".
#' @param summarize Time summarization level (e.g. "month").
#' @param filter Filter string, e.g. "contains(ndd_phenotype_word,Yes)".
#' @return `res` (mutated, status 400) on invalid input, otherwise a list
#'   with `meta` and `data`.
#' @export
svc_statistics_entities_over_time <- function(res, aggregate, group, summarize, filter) {
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

  # Derive allowlist from ndd_entity_view; returns NULL on transient DB error
  # (legacy behavior: allowlist disabled, bare-identifier check still applies).
  stats_allowed_cols <- allowed_columns_for_view("ndd_entity_view")

  # Generate filter expressions
  filter_exprs <- generate_filter_expressions(filter,
    allowed_columns = stats_allowed_cols)
  has_text_filter <- length(filter_exprs) > 0L && nzchar(trimws(filter))

  # Push filter to SQL when present; aggregations stay post-collect.
  entity_view_lazy <- pool %>% tbl("ndd_entity_view")
  entity_view_coll <- if (has_text_filter) {
    tryCatch(
      entity_view_lazy %>%
        dplyr::filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        collect(),
      error = function(e) {
        message(sprintf(
          "[entities_over_time] SQL filter pushdown failed (%s); collecting full view",
          conditionMessage(e)
        ))
        entity_view_lazy %>% collect()
      }
    )
  } else {
    entity_view_lazy %>% collect()
  }

  # Log initial count for diagnostics
  initial_count <- nrow(entity_view_coll)
  log_debug("Entities over time: Initial entity_view count = {initial_count}")

  # Filter is now already applied in SQL when fast-path succeeded; the in-R
  # filter call below is a no-op fast-pass on the fast path, and the actual
  # filter on the slow path. Keeping it unconditional simplifies the code.
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


#' Publication statistics (service layer)
#'
#' Backing logic for `GET /statistics/publication_stats`: aggregates counts
#' on publication_type, Journal, Lastname, update_date, Publication_date, and
#' Keywords, applying per-column minimum-count thresholds and an optional
#' text filter. Mutates `res$status <- 200` to match the pre-extraction
#' handler, which set the status explicitly even though 200 is the default.
#'
#' @param res Plumber response object.
#' @param time_aggregate Time grouping level, e.g. "year", "month".
#' @param filter Filter string in the shared filter-expression format.
#' @param min_journal_count Minimum occurrence count to keep a Journal.
#' @param min_lastname_count Minimum occurrence count to keep a Lastname.
#' @param min_keyword_count Minimum occurrence count to keep a Keyword.
#' @return A list with per-column aggregated counts and the echoed params.
#' @export
svc_statistics_publication_stats <- function(res,
                                              time_aggregate,
                                              filter,
                                              min_journal_count,
                                              min_lastname_count,
                                              min_keyword_count) {
  # Convert min count parameters to integers (Plumber passes query params as strings)
  min_journal_count <- as.integer(min_journal_count)
  min_lastname_count <- as.integer(min_lastname_count)
  min_keyword_count <- as.integer(min_keyword_count)

  # 1) Generate filter expressions from the user-provided 'filter' string.
  #    Allowlist columns against the publication view this endpoint queries so
  #    a user token cannot reach parse_exprs as code.
  pub_allowed_cols <- allowed_columns_for_view("publication")
  filter_exprs <- generate_filter_expressions(filter, allowed_columns = pub_allowed_cols)
  has_text_filter <- length(filter_exprs) > 0L && nzchar(trimws(filter))

  # 2) Push filter to SQL where possible; fall back to in-R if dbplyr can't translate.
  publication_lazy <- pool %>% tbl("publication")
  publication_tbl <- if (has_text_filter) {
    tryCatch(
      publication_lazy %>%
        filter(!!!rlang::parse_exprs(filter_exprs)) %>%
        collect(),
      error = function(e) {
        message(sprintf(
          "[publication_stats] SQL filter pushdown failed (%s); falling back to in-R filter",
          conditionMessage(e)
        ))
        publication_lazy %>% collect() %>% filter(!!!rlang::parse_exprs(filter_exprs))
      }
    )
  } else {
    publication_lazy %>% collect()
  }

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
