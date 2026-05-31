# Unit tests for backup filename validation (path-traversal guard).
source_api_file("functions/backup-functions.R", local = FALSE)

test_that("valid backup filenames pass", {
  expect_true(is_valid_backup_filename("backup-2024-01-15.sql"))
  expect_true(is_valid_backup_filename("backup-2024-01-15.sql.gz"))
})

test_that("path separators are rejected", {
  expect_false(is_valid_backup_filename("../etc/passwd"))
  expect_false(is_valid_backup_filename("sub/dir.sql"))
  expect_false(is_valid_backup_filename("a\\b.sql"))
})

test_that("non-backup extensions are rejected", {
  expect_false(is_valid_backup_filename("evil.sh"))
  expect_false(is_valid_backup_filename("backup.sql.gz.exe"))
  expect_false(is_valid_backup_filename(""))
  expect_false(is_valid_backup_filename(NULL))
})

test_that("defensive input branches are guarded", {
  expect_false(is_valid_backup_filename(NA_character_))
  expect_false(is_valid_backup_filename(c("a.sql", "b.sql")))
  expect_true(is_valid_backup_filename(".sql")) # documents accepted edge case
})
