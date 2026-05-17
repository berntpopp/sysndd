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
