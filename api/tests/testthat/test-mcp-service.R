test_that("get_gene_context shapes compact public gene payloads", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_resolve <- mcp_repo_resolve_gene
  old_entities <- mcp_repo_get_gene_entities
  old_comparisons <- mcp_repo_get_gene_comparisons
  assign("mcp_repo_resolve_gene", function(normalized_gene) {
    tibble::tibble(hgnc_id = "1", symbol = "MECP2", name = "methyl-CpG binding protein 2")
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_entities", function(...) {
    tibble::tibble(
      entity_id = 10L,
      symbol = "MECP2",
      hgnc_id = "1",
      disease_ontology_id_version = "MONDO:1",
      disease_ontology_name = "Rett syndrome",
      hpo_mode_of_inheritance_term_name = "X-linked dominant",
      category = "Definitive",
      ndd_phenotype_word = "yes",
      synopsis = paste(rep("A", 2000), collapse = "")
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_comparisons", function(...) tibble::tibble(list = "OMIM", category = "Definitive"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_resolve_gene", old_resolve, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_entities", old_entities, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_comparisons", old_comparisons, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_context("MECP2")

  expect_equal(result$schema_version, "1.0")
  expect_equal(result$gene$symbol, "MECP2")
  expect_true(result$entities[[1]]$synopsis_truncated)
  expect_lte(nchar(result$entities[[1]]$synopsis_excerpt), 1500)
  expect_equal(result$resource_links[[1]]$uri, "sysndd://gene/MECP2")
})

test_that("entity context respects include flags and caps publication limits", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_context <- mcp_repo_get_entity_context
  old_phenotypes <- mcp_repo_get_entity_phenotypes
  old_variation <- mcp_repo_get_entity_variation
  old_publications <- mcp_repo_get_entity_publications
  assign("mcp_repo_get_entity_context", function(entity_id) {
    tibble::tibble(
      entity_id = entity_id,
      symbol = "MECP2",
      hgnc_id = "1",
      category = "Definitive",
      synopsis = "Public synopsis",
      review_date = as.Date("2025-01-01")
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_entity_phenotypes", function(...) stop("phenotypes should not be called"), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_variation", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_publications", function(entity_id, limit) tibble::tibble(publication_id = "PMID:1", Title = "Paper"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_get_entity_context", old_context, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_phenotypes", old_phenotypes, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_variation", old_variation, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_publications", old_publications, envir = .GlobalEnv)
  })

  result <- mcp_get_entity_context(10L, include_phenotypes = FALSE, publication_limit = 25L)

  expect_equal(result$entity$entity_id, 10L)
  expect_equal(result$phenotypes, list())
  expect_equal(result$publications[[1]]$publication_id, "PMID:1")
})

test_that("search and list tools return capped metadata envelopes", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_search <- mcp_repo_search
  old_resolve <- mcp_repo_resolve_gene
  old_entities <- mcp_repo_get_gene_entities
  old_count <- mcp_repo_count_gene_entities
  assign("mcp_repo_search", function(query, types, limit) {
    tibble::tibble(type = "gene", id = "MECP2", label = "MECP2", description = "methyl-CpG binding protein 2", match_tier = "exact_identifier")
  }, envir = .GlobalEnv)
  assign("mcp_repo_resolve_gene", function(normalized_gene) tibble::tibble(hgnc_id = "1", symbol = "MECP2", name = "methyl-CpG binding protein 2"), envir = .GlobalEnv)
  assign("mcp_repo_get_gene_entities", function(...) tibble::tibble(entity_id = 10L, symbol = "MECP2", hgnc_id = "1", disease_ontology_name = "Rett syndrome", category = "Definitive", ndd_phenotype_word = "yes"), envir = .GlobalEnv)
  assign("mcp_repo_count_gene_entities", function(...) 1L, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_search", old_search, envir = .GlobalEnv)
    assign("mcp_repo_resolve_gene", old_resolve, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_entities", old_entities, envir = .GlobalEnv)
    assign("mcp_repo_count_gene_entities", old_count, envir = .GlobalEnv)
  })

  search <- mcp_search_sysndd("MECP2", limit = 5L)
  listed <- mcp_list_gene_entities("MECP2", limit = 5L)

  expect_equal(search$matches[[1]]$resource_uri, "sysndd://gene/MECP2")
  expect_equal(listed$meta$total, 1L)
  expect_false(listed$meta$has_more)
})

test_that("publication context includes citation, availability, and date semantics", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_publication <- mcp_repo_get_publication_context
  assign("mcp_repo_get_publication_context", function(publication_id) {
    tibble::tibble(
      publication_id = publication_id,
      Title = "NAA10-related neurodevelopmental syndrome",
      Abstract = NA_character_,
      Journal = "Am J Med Genet A",
      Publication_date = as.Date("2021-08-01"),
      Lastname = "Gogoll",
      Firstname = "L",
      Keywords = "NAA10",
      entity_id = c(451L, 452L),
      symbol = c("NAA10", "NAA15"),
      hgnc_id = c("18704", "30782"),
      disease_ontology_name = c("NAA10-related syndrome", "NAA15-related syndrome"),
      category = c("Definitive", "Moderate"),
      curation_review_date = as.Date(c("2023-04-12", "2024-02-01"))
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_repo_get_publication_context", old_publication, envir = .GlobalEnv))

  result <- mcp_get_publication_context("37130971")

  expect_equal(result$pubmed_publication_date, "2021-08-01")
  expect_null(result$publication_date)
  expect_false(result$abstract_available)
  expect_equal(result$abstract_excerpt, "")
  expect_match(result$recommended_citation, "Gogoll")
  expect_match(result$recommended_citation, "Am J Med Genet A")
  expect_match(result$recommended_citation, "PMID:37130971")
  expect_equal(result$linked_entities[[1]]$sysndd_curation_date, "2023-04-12")
})

test_that("batch publication context preserves request order and returns per-PMID errors", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_publication <- mcp_repo_get_publication_context
  assign("mcp_repo_get_publication_context", function(publication_id) {
    if (identical(publication_id, "PMID:999")) return(tibble::tibble())
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

  expect_equal(result$schema_version, "1.0")
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
})

test_that("batch entity context preserves order and returns per-entity errors", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_context <- mcp_repo_get_entity_context
  old_phenotypes <- mcp_repo_get_entity_phenotypes
  old_variation <- mcp_repo_get_entity_variation
  old_publications <- mcp_repo_get_entity_publications
  assign("mcp_repo_get_entity_context", function(entity_id) {
    if (identical(entity_id, 999L)) return(tibble::tibble())
    tibble::tibble(
      entity_id = entity_id,
      symbol = "SCN1A",
      hgnc_id = "HGNC:10585",
      category = "Definitive",
      synopsis = "Public synopsis",
      review_date = as.Date("2025-01-01")
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_entity_phenotypes", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_variation", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_publications", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_get_entity_context", old_context, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_phenotypes", old_phenotypes, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_variation", old_variation, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_publications", old_publications, envir = .GlobalEnv)
  })

  result <- mcp_get_entities_context(c(10L, 999L, 11L), include_publications = FALSE)

  expect_equal(result$meta$requested, 3L)
  expect_equal(result$meta$returned, 2L)
  expect_equal(result$meta$errors, 1L)
  expect_equal(result$entities[[1]]$entity$entity_id, 10L)
  expect_equal(result$entities[[2]]$entity_id, 999L)
  expect_equal(result$entities[[2]]$error$code, "not_found")
  expect_equal(result$entities[[3]]$entity$entity_id, 11L)
})
