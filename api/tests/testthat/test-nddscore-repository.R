library(testthat)
library(DBI)

source_api_file("functions/db-helpers.R", local = FALSE, envir = .GlobalEnv)
source_api_file("functions/nddscore-import.R", local = FALSE, envir = .GlobalEnv)
source_api_file("functions/nddscore-repository.R", local = FALSE, envir = .GlobalEnv)

with_nddscore_active_fixture <- function(code) {
  skip_if_no_test_db()
  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn), envir = parent.frame())
  nddscore_clean_tables(conn)
  withr::defer(nddscore_clean_tables(conn), envir = parent.frame())

  old_daemon_conn_exists <- exists("daemon_db_conn", envir = .GlobalEnv)
  old_daemon_conn <- if (old_daemon_conn_exists) {
    get("daemon_db_conn", envir = .GlobalEnv)
  } else {
    NULL
  }
  assign("daemon_db_conn", conn, envir = .GlobalEnv)
  withr::defer({
    if (old_daemon_conn_exists) {
      assign("daemon_db_conn", old_daemon_conn, envir = .GlobalEnv)
    } else if (exists("daemon_db_conn", envir = .GlobalEnv)) {
      rm("daemon_db_conn", envir = .GlobalEnv)
    }
  }, envir = parent.frame())

  nddscore_run_import(
    conn = conn,
    record_id = "20258027",
    validate_only = FALSE,
    imported_by = NULL,
    job_id = "job-repository-fixture",
    deps = nddscore_stub_deps(),
    progress = function(...) NULL
  )

  force(code)
}

test_that("nddscore_repo_current_release returns active release metadata", {
  with_nddscore_active_fixture({
    release <- nddscore_repo_current_release()

    expect_equal(release$release_id[[1]], "ndd_fixture_release")
    expect_equal(release$score_schema_version[[1]], "1.0.0")
    expect_equal(as.integer(release$n_genes[[1]]), 3L)
    expect_equal(as.integer(release$n_hpo_predictions[[1]]), 4L)
    expect_equal(as.integer(release$n_hpo_terms[[1]]), 2L)
    expect_equal(release$import_status[[1]], "active")
    expect_equal(as.integer(release$is_active[[1]]), 1L)
  })
})

test_that("nddscore_repo_genes paginates, filters, searches, and validates sort", {
  with_nddscore_active_fixture({
    page_one <- nddscore_repo_genes(sort = "rank", page = 1L, page_size = 2L)
    expect_equal(page_one$total, 3L)
    expect_equal(page_one$page, 1L)
    expect_equal(page_one$page_size, 2L)
    expect_equal(nrow(page_one$data), 2L)
    expect_equal(page_one$data$gene_symbol, c("CLCN4", "STXBP1"))

    high <- nddscore_repo_genes(filters = list(risk_tier = "High"))
    expect_equal(high$total, 1L)
    expect_equal(high$data$gene_symbol, "STXBP1")

    known <- nddscore_repo_genes(filters = list(known_sysndd_gene = "true"))
    expect_equal(known$total, 2L)
    expect_equal(known$data$gene_symbol, c("CLCN4", "STXBP1"))

    novel <- nddscore_repo_genes(filters = list(known_sysndd_gene = "false"))
    expect_equal(novel$total, 1L)
    expect_equal(novel$data$gene_symbol, "FIXNOVEL")

    clcn <- nddscore_repo_genes(filters = list(search = "clc"))
    expect_equal(clcn$total, 1L)
    expect_equal(clcn$data$hgnc_id, "HGNC:2022")

    high_rank <- nddscore_repo_genes(filters = list(rank_max = 2L))
    expect_equal(high_rank$total, 2L)
    expect_equal(high_rank$data$gene_symbol, c("CLCN4", "STXBP1"))

    high_percentile <- nddscore_repo_genes(filters = list(percentile_min = 98))
    expect_true(high_percentile$total >= 1L)
    expect_true(all(high_percentile$data$percentile >= 98))

    top_ad <- nddscore_repo_genes(filters = list(top_inheritance_mode = "AD"))
    expect_true(top_ad$total >= 1L)
    expect_true(all(top_ad$data$top_inheritance_mode == "AD"))

    hpo_filtered <- nddscore_repo_genes(filters = list(hpo_terms = c("HP:0001249", "HP:0001250")))
    expect_true(hpo_filtered$total >= 1L)
    expect_true(any(hpo_filtered$data$gene_symbol == "CLCN4"))

    expect_error(
      nddscore_repo_genes(sort = "release_id; DROP TABLE nddscore_release"),
      "Invalid sort column"
    )
  })
})

test_that("nddscore_repo_gene_detail resolves by HGNC id or symbol and includes HPO predictions", {
  with_nddscore_active_fixture({
    by_hgnc <- nddscore_repo_gene_detail("HGNC:2022")
    expect_equal(by_hgnc$gene$gene_symbol[[1]], "CLCN4")
    expect_equal(nrow(by_hgnc$hpo_predictions), 2L)
    expect_equal(by_hgnc$hpo_predictions$phenotype_id, c("HP:0001249", "HP:0001250"))

    by_symbol <- nddscore_repo_gene_detail("stxbp1")
    expect_equal(by_symbol$gene$hgnc_id[[1]], "HGNC:11110")
    expect_equal(nrow(by_symbol$hpo_predictions), 2L)

    unknown <- nddscore_repo_gene_detail("NOT_A_GENE")
    expect_null(unknown$gene)
    expect_equal(nrow(unknown$hpo_predictions), 0L)
  })
})

test_that("nddscore_repo_hpo, nddscore_repo_terms, and nddscore_repo_download_info return fixture totals", {
  with_nddscore_active_fixture({
    hpo <- nddscore_repo_hpo(sort = "-probability", page = 1L, page_size = 10L)
    expect_equal(hpo$total, 4L)
    expect_equal(nrow(hpo$data), 4L)
    expect_equal(hpo$data$probability[[1]], 0.9981)

    seizure <- nddscore_repo_hpo(filters = list(phenotype_id = "HP:0001250"))
    expect_equal(seizure$total, 2L)
    expect_true(all(seizure$data$phenotype_name == "Seizure"))

    passing <- nddscore_repo_hpo(filters = list(passes_default_threshold = "true"))
    expect_equal(passing$total, 4L)
    expect_true(all(passing$data$passes_default_threshold == 1L))

    terms <- nddscore_repo_terms()
    expect_equal(nrow(terms), 2L)
    expect_equal(terms$phenotype_id, c("HP:0001249", "HP:0001250"))

    info <- nddscore_repo_download_info()
    expect_equal(info$release_id, "ndd_fixture_release")
    expect_equal(info$version_doi, "10.5281/zenodo.20258027")
    expect_equal(info$record_url, "https://zenodo.org/records/20258027")
    expect_equal(info$archive_name, "nddscore_fixture_release.tar.gz")
    expect_equal(info$counts$genes, 3L)
    expect_equal(info$counts$hpo_predictions, 4L)
    expect_equal(info$counts$hpo_terms, 2L)
  })
})
