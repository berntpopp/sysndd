library(testthat)

source_api_file("services/seo-service.R", local = FALSE, envir = test_env())

make_seo_env <- function() {
  env <- new.env(parent = globalenv())
  env$queries <- list()
  env$db_execute_query <- function(sql, params = list(), conn = NULL) {
    env$queries[[length(env$queries) + 1]] <- list(sql = sql, params = params, conn = conn)

    if (grepl("FROM ndd_entity_view", sql) && grepl("GROUP BY hgnc_id", sql)) {
      return(tibble::tibble(
        symbol = "CHD8",
        hgnc_id = "HGNC:20153",
        last_modified = "2026-05-09"
      ))
    }

    if (grepl("FROM ndd_entity_view", sql) && grepl("GROUP BY entity_id", sql)) {
      return(tibble::tibble(
        entity_id = 123,
        last_modified = "2026-05-09"
      ))
    }

    if (grepl("FROM non_alt_loci_set", sql)) {
      return(tibble::tibble(
        symbol = "CHD8",
        name = "chromodomain helicase DNA binding protein 8",
        hgnc_id = "HGNC:20153",
        ensembl_gene_id = "ENSG00000100888",
        entrez_id = "57680",
        omim_id = "610528"
      ))
    }

    if (grepl("disease_ontology_name", sql) && grepl("DISTINCT", sql)) {
      return(tibble::tibble(disease = "autism"))
    }

    if (grepl("hpo_mode_of_inheritance_term_name", sql) && grepl("DISTINCT", sql)) {
      return(tibble::tibble(inheritance = "Autosomal dominant"))
    }

    if (grepl("category AS label", sql)) {
      return(tibble::tibble(label = "Definitive", count = 1))
    }

    if (grepl("ndd_phenotype_word AS label", sql)) {
      return(tibble::tibble(label = "NDD", count = 2))
    }

    if (grepl("COUNT\\(\\*\\)", sql)) {
      return(tibble::tibble(entity_count = 2))
    }

    if (grepl("ndd_review_publication_join", sql)) {
      return(tibble::tibble(pmid = "22495309"))
    }

    if (grepl("DATE_FORMAT\\(MAX\\(entry_date\\)", sql)) {
      return(tibble::tibble(last_modified = "2026-05-09"))
    }

    if (grepl("FROM ndd_entity_view", sql) && grepl("WHERE entity_id", sql) && grepl("LIMIT 1", sql)) {
      return(tibble::tibble(
        entity_id = 123,
        symbol = "CHD8",
        hgnc_id = "HGNC:20153",
        disease_ontology_name = "autism",
        disease_ontology_id_version = "OMIM:209850",
        hpo_mode_of_inheritance_term_name = "Autosomal dominant",
        category = "Definitive",
        ndd_phenotype_word = "NDD"
      ))
    }

    if (grepl("ndd_entity_review", sql)) {
      return(tibble::tibble(synopsis = "Curated CHD8 association.", last_modified = "2026-05-09"))
    }

    if (grepl("HPO_term", sql, ignore.case = TRUE)) {
      return(tibble::tibble(id = "HP:0000729", label = "Autistic behavior"))
    }

    if (grepl("variation_ontology_list", sql)) {
      return(tibble::tibble(id = "VariO:0133", label = "loss of function variant"))
    }

    tibble::tibble()
  }
  source_api_file("services/seo-service.R", local = FALSE, envir = env)
  env
}

test_that("svc_seo_routes returns only public routes", {
  env <- make_seo_env()

  routes <- env$svc_seo_routes(conn = "POOL")

  expect_equal(routes$genes[[1]]$symbol, "CHD8")
  expect_equal(routes$entities[[1]]$entityId, "123")
  expect_equal(routes$static[[1]]$path, "/")
  expect_false(any(grepl("Login|Admin|Register", unlist(routes))))
})

test_that("svc_seo_gene returns compact gene facts", {
  env <- make_seo_env()

  payload <- env$svc_seo_gene("CHD8", conn = "POOL")

  expect_equal(payload$symbol, "CHD8")
  expect_equal(payload$entityCount, 2)
  expect_equal(payload$diseases[[1]], "autism")
  expect_equal(payload$classifications[[1]]$label, "Definitive")
  expect_equal(payload$pmids[[1]], "22495309")
})

test_that("svc_seo_entity returns compact entity facts", {
  env <- make_seo_env()

  payload <- env$svc_seo_entity("123", conn = "POOL")

  expect_equal(payload$entityId, "123")
  expect_equal(payload$symbol, "CHD8")
  expect_equal(payload$diseaseName, "autism")
  expect_equal(payload$hpoTerms[[1]]$id, "HP:0000729")
  expect_equal(payload$variationTerms[[1]]$label, "loss of function variant")
})

test_that("missing SEO records return not-found payloads", {
  env <- make_seo_env()
  env$db_execute_query <- function(...) tibble::tibble()

  expect_equal(env$svc_seo_gene("MISSING", conn = "POOL")$status, 404)
  expect_equal(env$svc_seo_entity("999", conn = "POOL")$status, 404)
})

test_that("SEO endpoints expose public handlers that delegate to services", {
  endpoint_file <- file.path(get_api_dir(), "endpoints", "seo_endpoints.R")
  src <- readLines(endpoint_file, warn = FALSE)

  expect_true(any(grepl("^#\\*\\s+@get\\s+/routes\\s*$", src)))
  expect_true(any(grepl("^#\\*\\s+@get\\s+/gene/<symbol>\\s*$", src)))
  expect_true(any(grepl("^#\\*\\s+@get\\s+/entity/<entity_id>\\s*$", src)))
  expect_true(any(grepl("^#\\*\\s+@get\\s+/static\\s*$", src)))
})
