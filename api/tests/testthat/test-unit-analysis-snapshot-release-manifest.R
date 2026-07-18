# Unit tests for the pure, DB-free analysis-snapshot RELEASE manifest +
# content-address + canonical-archive helpers (#573 Slice A / Task A2).
#
# These functions define release IDENTITY (content_digest / release_id) and
# produce the release manifest.json, checksums.sha256 text, and tar.gz
# archive consumed by later tasks (repository persistence, build
# orchestrator). Pure unit test: no database, runs anywhere.

analysis_release_manifest_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_release_manifest_test_wd), testthat::teardown_env())

source(file.path("core", "errors.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)

# --------------------------------------------------------------------------- #
# B1: `layers` is a SELECTION, never a policy redefinition.
# --------------------------------------------------------------------------- #

test_that("resolve_layers returns the full registry when nothing is requested", {
  expect_identical(analysis_snapshot_release_resolve_layers(NULL), analysis_snapshot_release_layers())
  expect_identical(analysis_snapshot_release_resolve_layers(list()), analysis_snapshot_release_layers())
})

test_that("resolve_layers ignores caller policy fields and returns REGISTRY entries", {
  registry <- analysis_snapshot_release_layers()
  reg_functional <- Filter(function(l) identical(l$analysis_type, "functional_clusters"), registry)[[1]]

  # A hostile selector: tries to disable the reproducibility gate + path-traverse.
  resolved <- analysis_snapshot_release_resolve_layers(list(
    list(analysis_type = "functional_clusters", has_reproducibility = FALSE, files_prefix = "../evil", params = list(x = 1))
  ))
  expect_length(resolved, 1L)
  expect_identical(resolved[[1]]$files_prefix, reg_functional$files_prefix)
  expect_true(resolved[[1]]$has_reproducibility) # registry value, NOT the caller's FALSE
  expect_identical(resolved[[1]]$params, reg_functional$params)
})

test_that("resolve_layers accepts a bare-string selector and preserves request order", {
  resolved <- analysis_snapshot_release_resolve_layers(list("phenotype_clusters", "functional_clusters"))
  expect_equal(
    vapply(resolved, function(l) l$analysis_type, character(1)),
    c("phenotype_clusters", "functional_clusters")
  )
})

test_that("resolve_layers rejects an unknown or duplicate analysis_type with 400", {
  expect_error(
    analysis_snapshot_release_resolve_layers(list(list(analysis_type = "not_a_layer"))),
    class = "error_400"
  )
  expect_error(
    analysis_snapshot_release_resolve_layers(list("functional_clusters", "functional_clusters")),
    class = "error_400"
  )
})

test_that("build_tar_gz rejects a path-traversal archive path", {
  expect_error(
    analysis_release_build_tar_gz(list("../x.json" = charToRaw("{}"))),
    "unsafe release file path"
  )
  expect_error(
    analysis_release_build_tar_gz(list("/etc/passwd" = charToRaw("x"))),
    "unsafe release file path"
  )
})

test_that("release manifest module exposes the expected public API", {
  expect_true(is.character(ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION))
  expect_equal(ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION, "1.0")
  expect_true(exists("analysis_snapshot_release_layers", mode = "function"))
  expect_true(exists("analysis_release_canonical_bytes", mode = "function"))
  expect_true(exists("analysis_release_sha256", mode = "function"))
  expect_true(exists("analysis_release_content_digest", mode = "function"))
  expect_true(exists("analysis_release_id", mode = "function"))
  expect_true(exists("analysis_release_build_manifest", mode = "function"))
  expect_true(exists("analysis_release_checksums_text", mode = "function"))
  expect_true(exists("analysis_release_build_tar_gz", mode = "function"))
})

test_that("analysis_snapshot_release_layers() registers the 3 default analysis layers", {
  layers <- analysis_snapshot_release_layers()
  expect_equal(length(layers), 3)

  types <- vapply(layers, `[[`, character(1), "analysis_type")
  expect_equal(types, c("functional_clusters", "phenotype_clusters", "phenotype_functional_correlations"))

  functional <- layers[[1]]
  expect_equal(functional$params, list(algorithm = "leiden"))
  expect_equal(functional$files_prefix, "functional_clusters")
  expect_true(functional$has_reproducibility)

  phenotype <- layers[[2]]
  expect_equal(phenotype$params, list())
  expect_true(phenotype$has_reproducibility)

  correlations <- layers[[3]]
  expect_equal(correlations$params, list(algorithm = "leiden"))
  expect_false(correlations$has_reproducibility)
})

test_that("analysis_release_sha256 accepts raw and character and agrees on the same bytes", {
  from_chr <- analysis_release_sha256("hello")
  from_raw <- analysis_release_sha256(charToRaw("hello"))
  expect_identical(from_chr, from_raw)
  expect_match(from_chr, "^[0-9a-f]{64}$")
})

test_that("analysis_release_canonical_bytes reuses the shared canonical serializer", {
  obj <- list(b = 2, a = 1)
  expect_identical(
    analysis_release_canonical_bytes(obj),
    charToRaw(enc2utf8(analysis_snapshot_canonical_json(obj)))
  )
})

test_that("content_digest and release_id are pure functions of scientific content", {
  entries <- list(
    list(analysis_type = "functional_clusters", input_hash = "a", payload_hash = "b", reproducibility_hash = "c", dependencies = NULL),
    list(analysis_type = "phenotype_clusters", input_hash = "d", payload_hash = "e", reproducibility_hash = "f", dependencies = NULL)
  )
  d1 <- analysis_release_content_digest(entries, "srcv1", "1.0")
  d2 <- analysis_release_content_digest(rev(entries), "srcv1", "1.0") # order-independent (sorted internally)
  expect_identical(d1, d2)
  expect_match(analysis_release_id(d1), "^asr_[0-9a-f]{16}$")
  # created_at / title do NOT affect identity:
  expect_false(identical(d1, analysis_release_content_digest(entries, "srcv2", "1.0")))
})

test_that("analysis_release_build_manifest excludes manifest.json and checksums.sha256 from files[]", {
  files <- list(
    list(path = "manifest.json", sha256 = "111", bytes = 3L),
    list(path = "a/payload.json", sha256 = "222", bytes = 5L),
    list(path = "checksums.sha256", sha256 = "333", bytes = 9L)
  )
  manifest <- analysis_release_build_manifest(list(
    release_id = "asr_deadbeefcafebabe",
    release_version = "2026-07-18",
    title = "SysNDD Analysis Release",
    created_at = "2026-07-18T00:00:00Z",
    license = "CC-BY-4.0",
    scope_statement = "default analysis layers",
    generator = "sysndd-api",
    source = list(source_data_version = "srcv1"),
    layers = list(),
    files = files,
    content_digest = "deadbeef"
  ))

  paths <- vapply(manifest$files, `[[`, character(1), "path")
  expect_equal(paths, "a/payload.json")
  expect_equal(manifest$release_id, "asr_deadbeefcafebabe")
  expect_equal(manifest$content_digest, "deadbeef")
})

test_that("checksums text lists every file except checksums.sha256", {
  files <- list(
    list(path = "manifest.json", sha256 = "111", bytes = 3L),
    list(path = "a/payload.json", sha256 = "222", bytes = 5L),
    list(path = "checksums.sha256", sha256 = "333", bytes = 9L)
  )
  txt <- analysis_release_checksums_text(files)
  expect_match(txt, "111  manifest.json")
  expect_match(txt, "222  a/payload.json")
  expect_false(grepl("checksums.sha256", txt, fixed = TRUE))
})

test_that("tar.gz round-trips: untar yields exactly the input files/bytes", {
  payload <- list("a/x.json" = charToRaw("{\"k\":1}"), "manifest.json" = charToRaw("{}"))
  gz <- analysis_release_build_tar_gz(payload)
  d <- tempfile()
  dir.create(d)
  tarfile <- file.path(d, "b.tar")
  writeBin(memDecompress(gz, type = "gzip"), tarfile)
  utils::untar(tarfile, exdir = d)
  expect_identical(readBin(file.path(d, "a/x.json"), "raw", 64L), payload[["a/x.json"]])
  expect_identical(readBin(file.path(d, "manifest.json"), "raw", 64L), payload[["manifest.json"]])
})
