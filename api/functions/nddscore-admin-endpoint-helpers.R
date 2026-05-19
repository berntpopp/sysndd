# api/functions/nddscore-admin-endpoint-helpers.R

.nddscore_admin_has_rows <- function(value) {
  !is.null(value) && is.data.frame(value) && nrow(value) > 0L
}

.nddscore_admin_scalar <- function(value, default = NULL) {
  if (is.null(value) || length(value) == 0L) {
    return(default)
  }
  value <- value[[1]]
  if (is.null(value) || (length(value) == 1L && is.na(value))) {
    return(default)
  }
  if (is.character(value) && !nzchar(trimws(value))) {
    return(default)
  }
  value
}

.nddscore_admin_bool <- function(value, default = FALSE) {
  value <- .nddscore_admin_scalar(value, default)
  if (is.logical(value)) {
    return(isTRUE(value))
  }
  if (is.numeric(value)) {
    return(!is.na(value) && value != 0)
  }
  value <- tolower(trimws(as.character(value)))
  if (value %in% c("true", "t", "1", "yes", "y")) {
    return(TRUE)
  }
  if (value %in% c("false", "f", "0", "no", "n")) {
    return(FALSE)
  }
  isTRUE(default)
}

.nddscore_admin_request_body <- function(req) {
  body <- req$body
  if (is.null(body) && !is.null(req$postBody) && nzchar(req$postBody)) {
    body <- jsonlite::fromJSON(req$postBody, simplifyVector = FALSE)
  }
  if (is.null(body)) {
    body <- list()
  }
  body
}

.nddscore_admin_tibble_rows <- function(data) {
  if (!.nddscore_admin_has_rows(data)) {
    return(list())
  }
  lapply(seq_len(nrow(data)), function(i) {
    as.list(data[i, , drop = FALSE])
  })
}

.nddscore_admin_job_status_url <- function(job_id) {
  paste0("/api/jobs/", job_id, "/status")
}
