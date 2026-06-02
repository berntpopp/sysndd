library(testthat)

source_api_file("functions/external-functions.R", local = FALSE)

base <- "https://sysndd.dbmr.unibe.ch/"

test_that("only exact-host https URLs are valid", {
  expect_true(is_valid_archive_url("https://sysndd.dbmr.unibe.ch/Genes", base))
  expect_true(is_valid_archive_url("https://sysndd.dbmr.unibe.ch/", base))
  # Hostnames are case-insensitive — a mixed-case host is still the same host.
  expect_true(is_valid_archive_url("HTTPS://SYSNDD.DBMR.UNIBE.CH/Genes", base))
})

test_that("host-spoofing and non-https are rejected", {
  expect_false(is_valid_archive_url(
    "https://attacker.example/?x=https://sysndd.dbmr.unibe.ch/", base))
  expect_false(is_valid_archive_url(
    "https://sysndd.dbmr.unibe.ch.attacker.example/x", base))
  # userinfo trick: real host is attacker.example
  expect_false(is_valid_archive_url(
    "https://sysndd.dbmr.unibe.ch@attacker.example/x", base))
  # trailing-dot host is a distinct hostname and must not match
  expect_false(is_valid_archive_url("https://sysndd.dbmr.unibe.ch./x", base))
  expect_false(is_valid_archive_url("http://sysndd.dbmr.unibe.ch/x", base))
  expect_false(is_valid_archive_url("", base))
  expect_false(is_valid_archive_url(NA_character_, base))
  expect_false(is_valid_archive_url(NULL, base))
})
