# Shared fixtures for focused user endpoint service tests.

make_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$body <- NULL
  res
}

make_mock_req <- function(user_id = NULL, user_role = NULL, argsBody = NULL,
                          postBody = "", authorization = NULL) {
  req <- list(postBody = postBody)
  if (!is.null(user_id)) req$user_id <- user_id
  if (!is.null(user_role)) req$user_role <- user_role
  if (!is.null(argsBody)) req$argsBody <- argsBody
  if (!is.null(authorization)) req$HTTP_AUTHORIZATION <- authorization
  req
}

make_service_sandbox <- function(tables = list(), overrides = list()) {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(a, b) if (is.null(a)) b else a
  env$pool <- structure(list(), class = "mock_pool")
  env$tbl <- function(.data, table_name, ...) {
    if (!table_name %in% names(tables)) {
      stop("No fixture registered for table: ", table_name)
    }
    tables[[table_name]]
  }
  for (nm in names(overrides)) {
    assign(nm, overrides[[nm]], envir = env)
  }
  env
}

load_service_into <- function(relative_path, envir) {
  source_api_file(relative_path, local = FALSE, envir = envir)
}

extract_plumber_handler <- function(file_path, decorator_regex, envir) {
  src_lines <- readLines(file_path, warn = FALSE)
  dec_line <- grep(decorator_regex, src_lines)
  if (length(dec_line) != 1L) {
    stop("Expected exactly one decorator match for ", decorator_regex)
  }
  parsed <- parse(file = file_path, keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  handler_expr <- NULL
  for (i in seq_along(parsed)) {
    if (srcrefs[[i]][1L] > dec_line[[1L]]) {
      handler_expr <- parsed[[i]]
      break
    }
  }
  if (is.null(handler_expr)) stop("No handler found after decorator line")
  eval(handler_expr, envir = envir)
}

user_endpoints_path <- function() {
  file.path(get_api_dir(), "endpoints", "user_endpoints.R")
}
