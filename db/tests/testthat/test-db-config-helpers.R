# Unit tests for the pure helpers in db/config/db_config.R and
# db/config/db_sysid_source.R.
#
# These run on host CI (no DB / no network). Run with:
#   Rscript --no-init-file -e "testthat::test_dir('db/tests/testthat')"

library(testthat)

# Resolve the db/ directory from this test file's location so the tests are
# themselves working-directory independent.
.this_file <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]),
  mustWork = FALSE
)
if (is.na(.this_file) || !nzchar(.this_file) || !file.exists(.this_file)) {
  # Fallback when sourced interactively or via test_dir(): use getwd()-anchored
  # search for the config helper.
  .db_dir_guess <- NULL
  for (cand in c("db/config", "../../config", "config")) {
    if (file.exists(file.path(cand, "db_config.R"))) {
      .db_dir_guess <- normalizePath(dirname(cand), mustWork = FALSE)
      break
    }
  }
  stopifnot(!is.null(.db_dir_guess))
  .db_config_dir <- file.path(.db_dir_guess, "config")
} else {
  # tests/testthat/<this> -> db/
  .db_config_dir <- file.path(dirname(dirname(dirname(.this_file))), "config")
}

source(file.path(.db_config_dir, "db_config.R"))
source(file.path(.db_config_dir, "db_sysid_source.R"))


test_that("db_dir and db_repo_root resolve consistently", {
  d <- db_dir()
  expect_true(dir.exists(d))
  expect_equal(basename(d), "db")
  expect_equal(db_repo_root(), normalizePath(dirname(d), mustWork = FALSE))
})

test_that("SYSNDD_DB_DIR env var overrides db_dir", {
  tmp <- normalizePath(tempfile("dbdir"), mustWork = FALSE)
  dir.create(tmp)
  on.exit({
    Sys.unsetenv("SYSNDD_DB_DIR")
    unlink(tmp, recursive = TRUE)
  })
  Sys.setenv(SYSNDD_DB_DIR = tmp)
  expect_equal(db_dir(), tmp)
})

test_that("db_path / db_data_path / db_results_path build paths under db/", {
  expect_equal(db_path("data", "x.txt"), file.path(db_dir(), "data", "x.txt"))
  expect_equal(
    db_data_path("omim_links", "omim_links.txt"),
    file.path(db_dir(), "data", "omim_links", "omim_links.txt")
  )
  expect_equal(db_results_path("foo.csv"), file.path(db_dir(), "results", "foo.csv"))
})

test_that("db_results_path creates the parent directory", {
  unique_sub <- paste0("test_results_", as.integer(Sys.time()))
  target <- db_results_path(unique_sub, "out.csv")
  on.exit(unlink(file.path(db_dir(), "results", unique_sub), recursive = TRUE))
  expect_true(dir.exists(dirname(target)))
})


test_that("default external source URLs match the legacy literals", {
  expect_equal(
    db_source_url("hgnc_non_alt_loci_set"),
    "http://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/tsv/non_alt_loci_set.txt"
  )
  expect_equal(db_source_url("genenames_rest_base"), "http://rest.genenames.org/search")
  expect_equal(db_source_url("hpo_term_api_base"), "https://hpo.jax.org/api/hpo/term")
  expect_equal(db_source_url("oxo_mappings_api"), "https://www.ebi.ac.uk/spot/oxo/api/mappings")
  expect_equal(
    db_source_url("ncbi_eutils_efetch"),
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
  )
  expect_equal(db_source_url("ncbi_books_base"), "https://www.ncbi.nlm.nih.gov/books")
  expect_equal(db_source_url("vario_obo"), "http://www.variationontology.org/vario_download/vario.obo")
})

test_that("db_source_url rejects unknown keys", {
  expect_error(db_source_url("not_a_source"), "Unknown data source key")
})

test_that("db_sources overlays YAML overrides on defaults", {
  tmp <- tempfile(fileext = ".yml")
  on.exit(unlink(tmp))
  writeLines(c("sources:", "  vario_obo: \"http://mirror.example/vario.obo\""), tmp)
  s <- db_sources(sources_file = tmp)
  expect_equal(s[["vario_obo"]], "http://mirror.example/vario.obo")
  # Untouched keys keep their defaults.
  expect_equal(s[["hpo_term_api_base"]], "https://hpo.jax.org/api/hpo/term")
})

test_that("db_sources accepts a flat (un-nested) YAML mapping", {
  tmp <- tempfile(fileext = ".yml")
  on.exit(unlink(tmp))
  writeLines("hpo_term_api_base: \"https://hpo.mirror/term\"", tmp)
  s <- db_sources(sources_file = tmp)
  expect_equal(s[["hpo_term_api_base"]], "https://hpo.mirror/term")
})


test_that("db_genenames_search_url builds the legacy REST shape", {
  expect_equal(
    db_genenames_search_url("prev_symbol", "FOO"),
    "http://rest.genenames.org/search/prev_symbol/FOO"
  )
  expect_equal(
    db_genenames_search_url("hgnc_id", "12345"),
    "http://rest.genenames.org/search/hgnc_id/12345"
  )
})

test_that("db_hpo_term_url URL-encodes the term id like the legacy calls", {
  # Legacy used URLencode(term, reserved = TRUE) -> ":" becomes "%3A".
  expect_equal(
    db_hpo_term_url("HP:0000005"),
    "https://hpo.jax.org/api/hpo/term/HP%3A0000005"
  )
})

test_that("db_oxo_mappings_url appends the fromId query parameter", {
  expect_equal(
    db_oxo_mappings_url("OMIM:123456"),
    "https://www.ebi.ac.uk/spot/oxo/api/mappings?fromId=OMIM:123456"
  )
})


test_that("db_sysid_source_mode honours env, then config, then snapshot", {
  on.exit(Sys.unsetenv("SYSID_SOURCE"))

  Sys.setenv(SYSID_SOURCE = "mysql")
  expect_equal(db_sysid_source_mode(NULL), "mysql")
  Sys.setenv(SYSID_SOURCE = "sqlite")
  expect_equal(db_sysid_source_mode(NULL), "sqlite")
  Sys.unsetenv("SYSID_SOURCE")

  expect_equal(db_sysid_source_mode(list(sysid_source = "mysql")), "mysql")

  # No env, no config, no snapshot -> mysql (legacy default).
  expect_equal(db_sysid_source_mode(list()), "mysql")
})

test_that("db_sysid_source_mode auto-selects sqlite when a snapshot exists", {
  snap <- tempfile(fileext = ".sqlite")
  file.create(snap)
  on.exit(unlink(snap))
  expect_equal(db_sysid_source_mode(list(sysid_sqlite_path = snap)), "sqlite")
})

test_that("db_sysid_sqlite_path resolves absolute, relative, and default forms", {
  expect_equal(
    db_sysid_sqlite_path(list(sysid_sqlite_path = "/abs/snap.sqlite")),
    normalizePath("/abs/snap.sqlite", mustWork = FALSE)
  )
  expect_equal(
    db_sysid_sqlite_path(list(sysid_sqlite_path = "data/custom/snap.sqlite")),
    db_path("data", "custom", "snap.sqlite")
  )
  expect_equal(
    db_sysid_sqlite_path(NULL),
    db_data_path("sysid", "sysid_snapshot.sqlite")
  )
})
