source_api_file("functions/nddscore-import.R", local = FALSE)

fixture_archive <- function(name = "nddscore_fixture_release.tar.gz") {
  fixture_dir <- file.path(
    get_api_dir(),
    "tests", "testthat", "fixtures", "nddscore"
  )
  archive <- file.path(fixture_dir, name)
  if (!file.exists(archive)) {
    generator <- file.path(fixture_dir, "make-fixture-archive.R")
    withr::with_dir(dirname(get_api_dir()), {
      source(generator, local = TRUE)
    })
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

describe("nddscore_verify_archive_checksum", {
  it("passes when md5 matches", {
    path <- fixture_archive()
    good_md5 <- digest::digest(file = path, algo = "md5")
    expect_true(nddscore_verify_archive_checksum(path, good_md5))
  })

  it("stops with a clear error on md5 mismatch", {
    expect_error(
      nddscore_verify_archive_checksum(
        fixture_archive(),
        paste(rep("0", 32), collapse = "")
      ),
      "checksum"
    )
  })
})

describe("nddscore_download_archive", {
  it("writes the archive to the destination path", {
    src <- fixture_archive()
    dest <- file.path(tempdir(), "ndd_dl_test.tar.gz")
    on.exit(unlink(dest), add = TRUE)
    stub_download <- function(url, destfile) {
      file.copy(src, destfile, overwrite = TRUE)
    }

    out <- nddscore_download_archive(
      "https://example/content",
      dest,
      http_download = stub_download
    )
    expect_equal(out, dest)
    expect_true(file.exists(dest))
    expect_gt(file.size(dest), 0)
  })
})

describe("nddscore_extract_and_verify", {
  it("extracts and verifies the inner checksums.sha256", {
    rel_dir <- nddscore_extract_and_verify(fixture_archive())
    expect_true(dir.exists(rel_dir))
    expect_true(file.exists(file.path(rel_dir, "nddscore_release.json")))
    expect_true(file.exists(file.path(rel_dir, "nddscore_gene_predictions.tsv")))
  })

  it("stops when a bundled sha256 does not match", {
    expect_error(
      nddscore_extract_and_verify(fixture_archive("nddscore_fixture_corrupt_sha256.tar.gz")),
      "sha256|checksum"
    )
  })
})

describe("nddscore_parse_release_json", {
  it("parses release metadata from the fixture", {
    rel_dir <- nddscore_extract_and_verify(fixture_archive())
    meta <- nddscore_parse_release_json(rel_dir)

    expect_equal(meta$release_id, "ndd_fixture_release")
    expect_equal(meta$score_schema_version, "1.0.0")
    expect_equal(meta$n_genes, 3L)
    expect_equal(meta$n_hpo_predictions, 4L)
    expect_equal(meta$n_hpo_terms, 2L)
    expect_equal(meta$hpo_threshold, 0.5)
    expect_type(meta$ndd_performance_json, "character")
    expect_match(meta$ndd_performance_json, "auc_roc")
  })
})

describe("nddscore_load_tsvs", {
  it("loads the three TSVs into tibbles", {
    rel_dir <- nddscore_extract_and_verify(fixture_archive())
    frames <- nddscore_load_tsvs(rel_dir)

    expect_named(frames, c("gene", "hpo", "term"), ignore.order = TRUE)
    expect_equal(nrow(frames$gene), 3L)
    expect_equal(nrow(frames$hpo), 4L)
    expect_equal(nrow(frames$term), 2L)
    expect_true("ndd_score" %in% names(frames$gene))
    expect_true("probability" %in% names(frames$hpo))
  })
})

describe("nddscore_validate", {
  load_fixture <- function() {
    rel_dir <- nddscore_extract_and_verify(fixture_archive())
    list(release = nddscore_parse_release_json(rel_dir),
         frames = nddscore_load_tsvs(rel_dir))
  }

  it("passes for the valid fixture", {
    fx <- load_fixture()
    result <- nddscore_validate(fx$release, fx$frames)
    expect_true(result$ok)
    expect_length(result$messages, 0)
  })

  it("fails when a gene row count disagrees with n_genes", {
    fx <- load_fixture()
    fx$frames$gene <- fx$frames$gene[1, ]
    result <- nddscore_validate(fx$release, fx$frames)
    expect_false(result$ok)
    expect_true(any(grepl("n_genes|gene row count", result$messages)))
  })

  it("fails when a required column is missing", {
    fx <- load_fixture()
    fx$frames$gene$ndd_score <- NULL
    result <- nddscore_validate(fx$release, fx$frames)
    expect_false(result$ok)
    expect_true(any(grepl("ndd_score", result$messages)))
  })

  it("fails on an orphan HPO prediction row", {
    fx <- load_fixture()
    fx$frames$hpo$hgnc_id[1] <- "HGNC:0000000"
    result <- nddscore_validate(fx$release, fx$frames)
    expect_false(result$ok)
    expect_true(any(grepl("orphan|HGNC:0000000", result$messages)))
  })

  it("fails on invalid JSON in a JSON column", {
    fx <- load_fixture()
    fx$frames$gene$called_inheritance_modes[1] <- "{not json"
    result <- nddscore_validate(fx$release, fx$frames)
    expect_false(result$ok)
    expect_true(any(grepl("JSON|called_inheritance_modes", result$messages)))
  })
})
