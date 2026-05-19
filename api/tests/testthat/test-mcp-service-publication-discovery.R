test_that("publication context treats missing PubMed provenance as unverified", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_publication <- mcp_repo_get_publication_context
  assign("mcp_repo_get_publication_context", function(publication_id) {
    tibble::tibble(
      publication_id = publication_id,
      Title = "Shared paper",
      Abstract = "Abstract",
      Journal = "Journal",
      Publication_date = as.Date("2024-02-01"),
      publication_date_source = NA_character_,
      Lastname = "Smith",
      Firstname = "A",
      Keywords = "",
      entity_id = c(451L, 452L),
      symbol = c("NAA10", "NAA15"),
      hgnc_id = c("18704", "30782"),
      disease_ontology_name = c("NAA10-related syndrome", "NAA15-related syndrome"),
      category = c("Definitive", "Moderate"),
      curation_review_date = as.Date(c("2023-04-12", "2024-02-01"))
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_repo_get_publication_context", old_publication, envir = .GlobalEnv))

  result <- mcp_get_publication_context("PMID:1")

  expect_equal(result$publication_date_confidence, "unverified")
  expect_match(result$date_notes$publication_date_sysndd_record, "provenance not yet verified", fixed = TRUE)
})

test_that("batch publication context preserves request order and returns per-PMID errors", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_publication <- mcp_repo_get_publication_context
  assign("mcp_repo_get_publication_context", function(publication_id) {
    if (identical(publication_id, "PMID:999")) {
      return(tibble::tibble())
    }
    tibble::tibble(
      publication_id = publication_id,
      Title = paste("Title", publication_id),
      Abstract = "Abstract text",
      Journal = "Journal",
      Publication_date = as.Date("2020-01-01"),
      Lastname = "Smith",
      Firstname = "A",
      Keywords = "",
      entity_id = NA_integer_,
      symbol = NA_character_,
      hgnc_id = NA_character_,
      disease_ontology_name = NA_character_,
      category = NA_character_,
      curation_review_date = as.Date(NA)
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_repo_get_publication_context", old_publication, envir = .GlobalEnv))

  result <- mcp_get_publications_context(c("PMID:123", "999", "PMID:123"))

  expect_equal(result$schema_version, MCP_SCHEMA_VERSION)
  expect_equal(result$meta$requested, 3L)
  expect_equal(result$meta$returned, 2L)
  expect_equal(result$publications[[1]]$publication_id, "PMID:123")
  expect_equal(result$publications[[2]]$publication_id, "PMID:999")
  expect_equal(result$publications[[2]]$error$code, "not_found")
  expect_equal(result$publications[[3]]$publication_id, "PMID:123")
})

test_that("find_entities_by_phenotype rejects invalid category instead of returning a false negative", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  err <- tryCatch(
    mcp_find_entities_by_phenotype("HP:0001250", category = "BogusCategory"),
    mcp_tool_error = function(e) unclass(e)
  )

  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "category")
})

test_that("find_entities_by_phenotype reports true pagination totals", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_find <- mcp_repo_find_entities_by_phenotype
  old_count <- mcp_repo_count_entities_by_phenotype
  assign("mcp_repo_find_entities_by_phenotype", function(...) {
    tibble::tibble(
      entity_id = c(10L, 11L),
      symbol = c("A", "B"),
      hgnc_id = c("1", "2"),
      disease_ontology_id_version = c("MONDO:1", "MONDO:2"),
      disease_ontology_name = c("Disease A", "Disease B"),
      hpo_mode_of_inheritance_term_name = c("Autosomal dominant", "Autosomal recessive"),
      category = c("Definitive", "Definitive"),
      ndd_phenotype_word = c("yes", "yes"),
      phenotype_id = c("HP:0000252", "HP:0000252"),
      HPO_term = c("Microcephaly", "Microcephaly"),
      modifier_name = c("present", "present")
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_count_entities_by_phenotype", function(...) 42L, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_find_entities_by_phenotype", old_find, envir = .GlobalEnv)
    assign("mcp_repo_count_entities_by_phenotype", old_count, envir = .GlobalEnv)
  })

  result <- mcp_find_entities_by_phenotype("HP:0000252", limit = 2L)

  expect_equal(result$meta$total, 42L)
  expect_equal(result$meta$returned, 2L)
  expect_true(result$meta$has_more)
})

test_that("find_entities_by_disease reports true pagination totals", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_find <- mcp_repo_find_entities_by_disease
  old_count <- mcp_repo_count_entities_by_disease
  assign("mcp_repo_find_entities_by_disease", function(...) {
    tibble::tibble(
      entity_id = c(10L, 11L),
      symbol = c("MECP2", "MECP2"),
      hgnc_id = c("HGNC:6990", "HGNC:6990"),
      disease_ontology_id_version = c("MONDO:1", "MONDO:2"),
      disease_ontology_name = c("Rett syndrome", "Congenital Rett syndrome"),
      hpo_mode_of_inheritance_term_name = c("X-linked dominant", "X-linked dominant"),
      category = c("Definitive", "Definitive"),
      ndd_phenotype_word = c("yes", "yes")
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_count_entities_by_disease", function(...) 5L, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_find_entities_by_disease", old_find, envir = .GlobalEnv)
    assign("mcp_repo_count_entities_by_disease", old_count, envir = .GlobalEnv)
  })

  result <- mcp_find_entities_by_disease("Rett syndrome", limit = 2L)

  expect_equal(result$meta$total, 5L)
  expect_equal(result$meta$returned, 2L)
  expect_true(result$meta$has_more)
})

test_that("list and find entity rows include resource URIs and suggested tools", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  rows <- tibble::tibble(
    entity_id = 10L,
    symbol = "MECP2",
    hgnc_id = "HGNC:6990",
    disease_ontology_id_version = "MONDO:1",
    disease_ontology_name = "Rett syndrome",
    hpo_mode_of_inheritance_term_name = "X-linked dominant",
    category = "Definitive",
    ndd_phenotype_word = "Yes"
  )

  decorated <- mcp_decorate_entity_records(rows)

  expect_equal(decorated[[1]]$resource_uri, "sysndd://entity/10")
  expect_equal(decorated[[1]]$suggested_tools, list("get_entity_context", "get_entities_context"))
})

test_that("search_sysndd reports returned count and has_more metadata", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_search <- mcp_repo_search
  assign("mcp_repo_search", function(query, types, limit) {
    tibble::tibble(
      type = rep("gene", 3),
      id = c("SCN1A", "SCN1B", "SCN2A"),
      label = c("SCN1A", "SCN1B", "SCN2A"),
      description = c("one", "two", "three"),
      match_tier = c("exact_identifier", "contains", "contains")
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_repo_search", old_search, envir = .GlobalEnv))

  result <- mcp_search_sysndd("SCN", types = c("gene"), limit = 2L)

  expect_equal(length(result$matches), 2L)
  expect_equal(result$meta$limit, 2L)
  expect_equal(result$meta$offset, 0L)
  expect_equal(result$meta$returned, 2L)
  expect_equal(result$meta$total, 3L)
  expect_true(result$meta$has_more)
  expect_equal(result$matches[[1]]$rank_reason, "exact_identifier")
  expect_true(nzchar(result$matches[[1]]$matched_field))
})

test_that("mcp_publication_date_quality uses the stored provenance column", {
  verified <- mcp_publication_date_quality("2013-06-08", curation_dates = NULL,
                                           date_source = "pubmed")
  expect_equal(verified$confidence, "pubmed_verified")

  partial <- mcp_publication_date_quality("2017-01-01", curation_dates = NULL,
                                          date_source = "pubmed_partial")
  expect_equal(partial$confidence, "pubmed_partial")

  no_source <- mcp_publication_date_quality("2024-12-08",
                                            curation_dates = "2024-12-08",
                                            date_source = NULL)
  expect_equal(no_source$confidence, "unverified")

  fallback <- mcp_publication_date_quality("2019-05-01", curation_dates = NULL,
                                           date_source = NULL)
  expect_equal(fallback$confidence, "unverified")
})

test_that("mcp_publication_record renames the date field and guards the citation", {
  pub <- list(
    publication_id = "PMID:1", Title = "T", Journal = "J",
    Publication_date = "2024-12-08", curation_review_date = "2024-12-08",
    Lastname = "Doe", publication_type = "original",
    publication_date_source = NA, Abstract = "A"
  )
  rec <- mcp_publication_record(pub, abstract_mode = "metadata")
  expect_true("publication_date_sysndd_record" %in% names(rec))
  expect_false("pubmed_publication_date" %in% names(rec))
  expect_equal(rec$publication_date_confidence, "unverified")
  expect_match(rec$recommended_citation, "publication date unverified")
})
