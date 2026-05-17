source_api_file("functions/nddscore-import.R", local = FALSE)

fixture_archive <- function(name = "nddscore_fixture_release.tar.gz") {
  fixture_dir <- file.path(
    get_api_dir(),
    "tests", "testthat", "fixtures", "nddscore"
  )
  archive <- file.path(fixture_dir, name)
  if (!file.exists(archive)) {
    generator <- file.path(fixture_dir, "make-fixture-archive.R")
    source(generator, local = TRUE)
  }
  archive
}

fake_zenodo_record <- function(files = NULL) {
  archive <- fixture_archive()
  if (is.null(files)) {
    files <- list(list(
      key = "nddscore_sysndd_prediction_release_2026-05-17.tar.gz",
      size = 7568944L,
      checksum = "md5:7b7d2b397ca80a4e8d437b9696bef049",
      links = list(
        self = paste0(
          "https://zenodo.org/api/records/20258027/files/",
          basename(archive),
          "/content"
        )
      )
    ))
  }

  list(
    id = 20258027L,
    doi = "10.5281/zenodo.20258027",
    conceptdoi = "10.5281/zenodo.20258026",
    metadata = list(version = "2026.05.17"),
    links = list(self_html = "https://zenodo.org/records/20258027"),
    files = files
  )
}

test_that("nddscore_fetch_zenodo_metadata locates archive and normalizes metadata", {
  requested_url <- NULL
  metadata <- nddscore_fetch_zenodo_metadata(
    20258027,
    http_get = function(url) {
      requested_url <<- url
      fake_zenodo_record()
    }
  )

  expect_equal(requested_url, "https://zenodo.org/api/records/20258027")
  expect_equal(metadata$record_id, "20258027")
  expect_equal(metadata$record_url, "https://zenodo.org/records/20258027")
  expect_equal(metadata$version, "2026.05.17")
  expect_equal(metadata$version_doi, "10.5281/zenodo.20258027")
  expect_equal(metadata$concept_doi, "10.5281/zenodo.20258026")
  expect_equal(
    metadata$archive_name,
    "nddscore_sysndd_prediction_release_2026-05-17.tar.gz"
  )
  expect_equal(metadata$archive_bytes, 7568944)
  expect_equal(metadata$archive_md5, "7b7d2b397ca80a4e8d437b9696bef049")
  expect_match(metadata$content_url, "/content$")
})

test_that("nddscore_fetch_zenodo_metadata errors clearly without archive entry", {
  expect_error(
    nddscore_fetch_zenodo_metadata(
      "20258027",
      http_get = function(url) {
        fake_zenodo_record(files = list(list(
          key = "nddscore_release.json",
          size = 1024L,
          checksum = "md5:abc",
          links = list(self = paste0(url, "/files/nddscore_release.json/content"))
        )))
      }
    ),
    "no \\.tar\\.gz archive file entry"
  )
})
