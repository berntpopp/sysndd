# tests/testthat/test-unit-backup-credential-safety.R
#
# #535 P1-1: the backup CLI invocation must never carry the DB password in
# process argv or a shell command string; the password may only ever land in a
# mode-0600 MySQL option file. Host-runnable: no DB, no /backup mount.

library(testthat)

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a

source_api_file("functions/backup-functions.R", local = FALSE)

# Password deliberately contains every option-file metacharacter: '#', space,
# double-quote, and backslash.
cfg <- list(dbname = "sysndd_db", host = "db", user = "root",
            password = "s3cr#t \"pw\\x", port = 3306L)

test_that("mysqldump args carry --defaults-extra-file first and never the password", {
  opt <- "/tmp/opt.cnf"
  args <- .backup_mysqldump_args(cfg, opt)
  expect_equal(args[[1]], paste0("--defaults-extra-file=", opt))
  expect_false(any(grepl(cfg$password, args, fixed = TRUE)))
  expect_false(any(grepl("^-p", args)))          # no -p<password>
  expect_true("sysndd_db" %in% args)             # dbname positional retained
  expect_true(all(c("--single-transaction", "--routines", "--triggers", "--quick") %in% args))
})

test_that("restore command carries --defaults-extra-file, never the password, and shQuotes tokens", {
  opt <- "/tmp/opt.cnf"
  cmd_gz  <- .backup_restore_command(cfg, opt, "/backup/x.sql.gz", TRUE)
  cmd_sql <- .backup_restore_command(cfg, opt, "/backup/x.sql", FALSE)
  for (cmd in list(cmd_gz, cmd_sql)) {
    expect_true(grepl("--defaults-extra-file=", cmd, fixed = TRUE))
    expect_false(grepl(cfg$password, cmd, fixed = TRUE))
    expect_false(grepl("-p'", cmd, fixed = TRUE))
    expect_false(grepl("-p\"", cmd, fixed = TRUE))
  }
  expect_true(grepl("gunzip -c", cmd_gz, fixed = TRUE))
  expect_true(grepl(" < ", cmd_sql, fixed = TRUE))
})

test_that("option-file body escapes exactly per MySQL [client] quoting", {
  # Raw password  s3cr#t "pw\x   ->  escaped  s3cr#t \"pw\\x
  expected <- paste0("[client]\n", 'password="s3cr#t \\"pw\\\\x"', "\n")
  expect_identical(.backup_option_file_content(cfg), expected)
})

test_that("option file is created fail-closed at mode 0600 and holds the escaped password", {
  path <- .backup_write_option_file(cfg)
  on.exit(unlink(path), add = TRUE)
  expect_true(file.exists(path))
  # Mode 0600: no group/other bits.
  mode <- as.integer(file.info(path)$mode)
  expect_equal(bitwAnd(mode, as.integer(as.octmode("077"))), 0L)
  body <- paste(readLines(path), collapse = "\n")
  expect_true(grepl('password="', body, fixed = TRUE))
  expect_true(grepl('\\"pw', body, fixed = TRUE))   # escaped quote present
})

test_that("the real MySQL client parses the escaped option file (integration)", {
  client <- Sys.which("mysql")
  if (!nzchar(client)) client <- Sys.which("mariadb")
  skip_if(!nzchar(client), "no mysql/mariadb client on PATH")

  path <- .backup_write_option_file(cfg)
  on.exit(unlink(path), add = TRUE)
  out <- suppressWarnings(system2(
    client, c(paste0("--defaults-extra-file=", path), "--print-defaults"),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(out, "status") %||% 0
  # The client must accept our escaping (exit 0) and surface a password option.
  expect_equal(status, 0)
  expect_true(any(grepl("--password", out, fixed = TRUE)))
})
