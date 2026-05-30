# functions/mcp-search-repository.R
#
# Read-only candidate search helpers for the SysNDD MCP sidecar.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

mcp_search_tokens <- function(query, max_tokens = 6L) {
  query <- toupper(as.character(query %||% "")[1])
  tokens <- unlist(strsplit(query, "[^A-Z0-9]+", perl = TRUE), use.names = FALSE)
  tokens <- tokens[!is.na(tokens) & nzchar(tokens)]
  tokens <- tokens[nchar(tokens) > 1L | grepl("^[0-9]+$", tokens)]
  unique(utils::head(tokens, max(1L, as.integer(max_tokens))))
}

mcp_search_token_filter <- function(columns, token_like) {
  if (length(token_like) == 0L || length(columns) == 0L) {
    return(list(sql = "", params = list()))
  }

  filters <- character()
  params <- list()
  for (column in columns) {
    filters <- c(filters, rep(sprintf("UPPER(%s) LIKE UPPER(?)", column), length(token_like)))
    params <- c(params, as.list(token_like))
  }

  list(sql = paste(filters, collapse = " OR "), params = params)
}

mcp_rank_search_candidates <- function(rows, query_tokens = NULL, query = NULL) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(tibble::as_tibble(rows %||% tibble::tibble()))
  }

  ranked <- tibble::as_tibble(rows)
  if (!"matched_field" %in% names(ranked)) ranked$matched_field <- NA_character_
  if (!"match_tier" %in% names(ranked)) ranked$match_tier <- "contains"
  tokens <- query_tokens %||% mcp_search_tokens(query %||% "")
  if (!"token_matches" %in% names(ranked) || length(tokens) > 0L) {
    haystacks <- toupper(paste(
      as.character(ranked$id %||% ""),
      as.character(ranked$label %||% ""),
      as.character(ranked$description %||% "")
    ))
    ranked$token_matches <- vapply(haystacks, function(value) {
      sum(vapply(tokens, function(token) grepl(token, value, fixed = TRUE), logical(1)))
    }, integer(1))
  }

  ranked$token_matches <- suppressWarnings(as.integer(ranked$token_matches))
  ranked$token_matches[is.na(ranked$token_matches)] <- 0L
  ranked$match_tier <- ifelse(
    ranked$match_tier %in% c("contains", NA_character_) & ranked$token_matches > 0L,
    "token_overlap",
    ranked$match_tier
  )
  ranked$score <- vapply(seq_len(nrow(ranked)), function(i) {
    tier <- as.character(ranked$match_tier[[i]] %||% "contains")
    token_matches <- ranked$token_matches[[i]]
    switch(tier,
      exact_identifier = 1000,
      exact_label = 900,
      alias = 850,
      previous = 850,
      alias_symbol = 850,
      previous_symbol = 850,
      phrase = 750,
      prefix = 650,
      token_overlap = 400 + 25 * token_matches,
      contains = 250,
      100
    )
  }, numeric(1))

  ranked <- ranked[order(-ranked$score, ranked$type, ranked$label, ranked$id), , drop = FALSE]
  rownames(ranked) <- NULL
  ranked
}

mcp_repo_table_has_column <- function(table, column) {
  result <- tryCatch(
    db_execute_query(
      "SELECT COUNT(*) AS has_column
         FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?",
      list(table, column)
    ),
    error = function(e) NULL
  )
  !is.null(result) && nrow(result) > 0L && as.integer(result$has_column[[1]] %||% 0L) > 0L
}
