# api/tests/testthat/test-unit-variation-provenance-evidence.R

source_api_file("functions/variation-provenance-evidence.R", local = FALSE)

test_that("external database strength maps from review stars", {
  expect_equal(normalize_evidence_strength("external_database", 0), 0L)
  expect_equal(normalize_evidence_strength("external_database", 1), 1L)
  expect_equal(normalize_evidence_strength("external_database", 4), 4L)
})

test_that("out-of-range, fractional and missing input yields NA, never a guess", {
  expect_true(is.na(normalize_evidence_strength("external_database", NULL)))
  expect_true(is.na(normalize_evidence_strength("external_database", 9)))
  expect_true(is.na(normalize_evidence_strength("external_database", -1)))
  expect_true(is.na(normalize_evidence_strength("external_database", 1.9)))
  expect_true(is.na(normalize_evidence_strength("external_database", "1.9")))
  expect_true(is.na(normalize_evidence_strength("external_database", "one")))
  expect_true(is.na(normalize_evidence_strength("unknown_source", 2)))
  expect_true(is.na(normalize_evidence_strength("curator", 2)))
})

test_that("integer-valued doubles and exact digit strings are accepted", {
  expect_equal(normalize_evidence_strength("external_database", 2.0), 2L)
  expect_equal(normalize_evidence_strength("external_database", "3"), 3L)
})

test_that("literature strength maps from match confidence", {
  expect_equal(normalize_evidence_strength("literature", "explicit"), 3L)
  expect_equal(normalize_evidence_strength("literature", "inferred"), 1L)
  expect_true(is.na(normalize_evidence_strength("literature", "banana")))
})

test_that("the evidence module is registered for runtime loading", {
  bootstrap <- paste(
    readLines(file.path(get_api_dir(), "bootstrap", "load_modules.R"), warn = FALSE),
    collapse = "\n")
  expect_match(bootstrap, "functions/variation-provenance-evidence.R", fixed = TRUE)
})

test_that("NA of each flavour returns NA_integer_ for both source types", {
  expect_true(is.na(normalize_evidence_strength("external_database", NA)))
  expect_true(is.na(normalize_evidence_strength("external_database", NA_integer_)))
  expect_true(is.na(normalize_evidence_strength("external_database", NA_character_)))
  expect_true(is.na(normalize_evidence_strength("literature", NA)))
  expect_true(is.na(normalize_evidence_strength("literature", NA_integer_)))
  expect_true(is.na(normalize_evidence_strength("literature", NA_character_)))
})

test_that("a length-2 raw vector returns NA_integer_ instead of recycling", {
  expect_true(is.na(normalize_evidence_strength("external_database", c(1, 2))))
  expect_true(is.na(normalize_evidence_strength("external_database", c("1", "2"))))
  expect_true(is.na(normalize_evidence_strength("literature", c("explicit", "inferred"))))
})

test_that("zero-length raw input returns NA_integer_", {
  expect_true(is.na(normalize_evidence_strength("external_database", character(0))))
  expect_true(is.na(normalize_evidence_strength("external_database", integer(0))))
  expect_true(is.na(normalize_evidence_strength("literature", character(0))))
})

test_that("source_type itself being NULL, NA, or length-2 returns NA_integer_", {
  expect_true(is.na(normalize_evidence_strength(NULL, 1)))
  expect_true(is.na(normalize_evidence_strength(NA, 1)))
  expect_true(is.na(normalize_evidence_strength(NA_character_, 1)))
  expect_true(is.na(normalize_evidence_strength(c("literature", "external_database"), 1)))
})

test_that("a logical raw input returns NA_integer_ rather than coercing TRUE to 1", {
  expect_true(is.na(normalize_evidence_strength("external_database", TRUE)))
  expect_true(is.na(normalize_evidence_strength("external_database", FALSE)))
})

test_that("the return value is always integer type, never double", {
  expect_identical(normalize_evidence_strength("external_database", 0), 0L)
  expect_identical(normalize_evidence_strength("external_database", 0L), 0L)
  expect_identical(normalize_evidence_strength("external_database", 9), NA_integer_)
})
