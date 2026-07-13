# functions/mcp-readonly-provisioner-secret.R
#
# MySQL 8.4 generated-password result validation and owner-only secret output.

.mcp_secret_abort <- function(message) {
  stop(message, call. = FALSE)
}

.mcp_auth_factor_is_one <- function(value) {
  if (length(value) != 1L) return(FALSE)
  if (identical(typeof(value), "integer") && is.null(attributes(value))) {
    return(identical(value, 1L))
  }
  if (!identical(typeof(value), "double") ||
      !identical(class(value), "integer64") || is.na(value)) {
    return(FALSE)
  }
  identical(tryCatch(as.character(value), error = function(e) NA_character_), "1")
}

mcp_readonly_generated_password <- function(rows) {
  required <- c("user", "host", "generated password", "auth_factor")
  if (!is.data.frame(rows) || nrow(rows) != 1L ||
      !identical(names(rows), required)) {
    .mcp_secret_abort("generated password result has an unexpected shape")
  }
  if (!identical(as.character(rows$user[[1L]]), "sysndd_mcp") ||
      !identical(as.character(rows$host[[1L]]), "%")) {
    .mcp_secret_abort("generated password result is not for the fixed reader")
  }
  if (!.mcp_auth_factor_is_one(rows$auth_factor[[1L]])) {
    .mcp_secret_abort("generated password result has an unexpected factor")
  }
  password <- as.character(rows[["generated password"]][[1L]])
  if (length(password) != 1L || is.na(password) ||
      nchar(password, type = "bytes") < 5L ||
      nchar(password, type = "bytes") > 255L ||
      grepl("[\r\n]", password, perl = TRUE)) {
    .mcp_secret_abort("generated password value is invalid")
  }
  password
}

mcp_readonly_write_secret <- function(path, password) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !nzchar(path) || grepl("[\r\n]", path, perl = TRUE)) {
    .mcp_secret_abort("MCP_DB_PASSWORD_OUTPUT_FILE is invalid")
  }
  if (!startsWith(path, "/")) {
    .mcp_secret_abort("MCP_DB_PASSWORD_OUTPUT_FILE must be an absolute path")
  }
  if (!is.character(password) || length(password) != 1L || is.na(password) ||
      !nzchar(password) || grepl("[\r\n]", password, perl = TRUE)) {
    .mcp_secret_abort("generated password value is invalid")
  }
  link_target <- Sys.readlink(path)
  if (!is.na(link_target) && nzchar(link_target)) {
    .mcp_secret_abort("MCP_DB_PASSWORD_OUTPUT_FILE must not be a symbolic link")
  }

  parent <- tryCatch(
    normalizePath(dirname(path), mustWork = TRUE),
    error = function(e) {
      .mcp_secret_abort("MCP_DB_PASSWORD_OUTPUT_FILE parent is unavailable")
    }
  )
  if (!dir.exists(parent)) {
    .mcp_secret_abort("MCP_DB_PASSWORD_OUTPUT_FILE parent is not a directory")
  }
  parent_info <- file.info(parent)
  parent_mode <- as.integer(parent_info$mode[[1L]])
  current_user <- unname(Sys.info()[["user"]])
  owner_bits <- as.integer(as.octmode("700"))
  other_bits <- as.integer(as.octmode("077"))
  if (!is.character(current_user) || length(current_user) != 1L ||
      is.na(parent_info$uname[[1L]]) || parent_info$uname[[1L]] != current_user ||
      bitwAnd(parent_mode, owner_bits) != owner_bits ||
      bitwAnd(parent_mode, other_bits) != 0L) {
    .mcp_secret_abort("MCP_DB_PASSWORD_OUTPUT_FILE parent must be owner-only")
  }
  target <- file.path(parent, basename(path))
  if (file.exists(target) && dir.exists(target)) {
    .mcp_secret_abort("MCP_DB_PASSWORD_OUTPUT_FILE must be a regular file")
  }

  temporary <- tempfile(".mcp-reader-secret-", tmpdir = parent)
  on.exit(unlink(temporary), add = TRUE)
  if (file.exists(temporary) || !file.create(temporary)) {
    .mcp_secret_abort("could not create MCP reader secret")
  }
  if (!isTRUE(Sys.chmod(temporary, mode = "0600", use_umask = FALSE))) {
    .mcp_secret_abort("could not restrict MCP reader secret")
  }
  connection <- file(temporary, open = "wb")
  on.exit(try(close(connection), silent = TRUE), add = TRUE)
  writeBin(charToRaw(password), connection)
  close(connection)
  if (!file.rename(temporary, target)) {
    .mcp_secret_abort("could not atomically install MCP reader secret")
  }
  if (!isTRUE(Sys.chmod(target, mode = "0600", use_umask = FALSE))) {
    .mcp_secret_abort("could not restrict installed MCP reader secret")
  }
  installed <- file.info(target)
  installed_mode <- as.integer(installed$mode[[1L]])
  expected_bytes <- charToRaw(password)
  connection <- file(target, open = "rb")
  on.exit(try(close(connection), silent = TRUE), add = TRUE)
  installed_bytes <- readBin(connection, what = "raw", n = length(expected_bytes) + 1L)
  close(connection)
  expected_mode <- as.integer(as.octmode("600"))
  if (!isTRUE(file_test("-f", target)) ||
      is.na(installed$isdir[[1L]]) || installed$isdir[[1L]] ||
      is.na(installed$uname[[1L]]) || installed$uname[[1L]] != current_user ||
      installed_mode != expected_mode ||
      !identical(installed_bytes, expected_bytes)) {
    .mcp_secret_abort("installed MCP reader secret failed verification")
  }
  normalizePath(target, mustWork = TRUE)
}
