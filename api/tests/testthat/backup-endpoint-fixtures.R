# Shared fixtures for test-endpoint-backup.R.
# Explicitly sourced so single-file testthat runs load the same helpers.

`%||%` <- function(a, b) if (is.null(a)) b else a

extract_plumber_handler <- function(file_path, decorator_regex, envir) {
  src_lines <- readLines(file_path, warn = FALSE)
  dec_line <- grep(decorator_regex, src_lines)
  if (length(dec_line) == 0L) {
    stop("Decorator not found: ", decorator_regex)
  }
  dec_line <- dec_line[[1L]]

  parsed <- parse(file = file_path, keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  if (is.null(srcrefs)) {
    stop("Unable to read source refs for ", file_path)
  }

  handler_expr <- NULL
  for (i in seq_along(parsed)) {
    start_line <- srcrefs[[i]][1L]
    if (start_line > dec_line) {
      handler_expr <- parsed[[i]]
      break
    }
  }
  if (is.null(handler_expr)) {
    stop("No top-level expression found after decorator line ", dec_line)
  }

  eval(handler_expr, envir = envir)
}

make_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$body <- NULL
  res$headers <- list()
  res$setHeader <- function(name, value) {
    res$headers[[name]] <- value
    invisible(NULL)
  }
  res$serializer <- NULL
  res
}

backup_file_path <- function() {
  file.path(get_api_dir(), "endpoints", "backup_endpoints.R")
}

.backup_functions_env <- new.env()
source_api_file(
  "functions/backup-functions.R",
  local = FALSE,
  envir = .backup_functions_env
)

make_backup_sandbox <- function(role = "Administrator") {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(a, b) if (is.null(a)) b else a

  env$require_role <- function(req, res, min_role) {
    actual_role <- req$user_role %||% "none"
    if (actual_role != "Administrator" && min_role == "Administrator") {
      res$status <- 403
      stop("Forbidden: requires Administrator role")
    }
    invisible(TRUE)
  }

  env$log_error <- function(...) invisible(NULL)
  env$log_info <- function(...) invisible(NULL)
  env$logger <- list(
    log_error = function(...) invisible(NULL),
    log_info = function(...) invisible(NULL)
  )
  env$serializer_json <- function(...) identity

  env$dw <- list(
    dbname = "sysndd_test",
    host = "127.0.0.1",
    user = "test",
    password = "test",
    port = 3306L
  )

  env$check_duplicate_job <- function(operation, params) {
    list(duplicate = FALSE, existing_job_id = NULL)
  }
  env$create_job <- function(operation, params) {
    list(job_id = "job-fixture-1234", error = NULL)
  }
  env$list_backup_files <- function(dir) {
    data.frame(
      filename = character(0),
      size_bytes = integer(0),
      created_at = as.POSIXct(character(0)),
      table_count = integer(0),
      stringsAsFactors = FALSE
    )
  }
  env$get_backup_metadata <- function(dir) {
    list(total_count = 0L, total_size_bytes = 0L)
  }
  env$is_valid_backup_filename <- .backup_functions_env$is_valid_backup_filename

  source_api_file("services/backup-endpoint-service.R", local = FALSE, envir = env)
  env
}

admin_req <- function(body = NULL, path_args = list()) {
  list(
    user_id = 42L,
    user_role = "Administrator",
    user_name = "admin_test",
    PATH_INFO = "/api/backup/list",
    argsBody = body %||% list()
  )
}

viewer_req <- function(body = NULL) {
  req <- admin_req(body = body)
  req$user_role <- "Viewer"
  req
}

install_download_fixture <- function(env, tmpdir, filename, content_bytes) {
  fake_path <- file.path(tmpdir, filename)
  writeBin(content_bytes, fake_path)
  fake_size <- file.info(fake_path)$size

  env$file.exists <- function(path) {
    endsWith(path, paste0("/", filename))
  }
  env$file.info <- function(path) {
    if (endsWith(path, paste0("/", filename))) {
      data.frame(size = fake_size)
    } else {
      data.frame(size = NA_real_)
    }
  }
  env$file <- function(description, open = "") {
    base::file(fake_path, open = open)
  }
  env$readBin <- function(con, what, n, ...) {
    base::readBin(con, what = what, n = n, ...)
  }
  invisible(fake_path)
}
