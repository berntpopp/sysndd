test_that("get_gene_context reports entity pagination and can expand entity details in one call", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_resolve <- mcp_repo_resolve_gene
  old_entities <- mcp_repo_get_gene_entities
  old_count <- mcp_repo_count_gene_entities
  old_comparisons <- mcp_repo_get_gene_comparisons
  old_context <- mcp_repo_get_entity_context
  old_phenotypes <- mcp_repo_get_entity_phenotypes
  old_variation <- mcp_repo_get_entity_variation
  old_publications <- mcp_repo_get_entity_publications
  assign("mcp_repo_resolve_gene", function(normalized_gene) {
    tibble::tibble(hgnc_id = "HGNC:2903", symbol = "GRIN2A", name = "glutamate ionotropic receptor NMDA type subunit 2A")
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_entities", function(...) {
    tibble::tibble(
      entity_id = c(303L, 304L),
      symbol = "GRIN2A",
      hgnc_id = "HGNC:2903",
      disease_ontology_id_version = c("MONDO:1", "MONDO:2"),
      disease_ontology_name = c("Disease A", "Disease B"),
      hpo_mode_of_inheritance_term_name = "Autosomal dominant",
      category = "Definitive",
      ndd_phenotype_word = "yes",
      synopsis = "Public synopsis"
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_count_gene_entities", function(...) 7L, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_comparisons", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_context", function(entity_id) {
    tibble::tibble(
      entity_id = entity_id,
      hgnc_id = "HGNC:2903",
      symbol = "GRIN2A",
      disease_ontology_id_version = paste0("MONDO:", entity_id),
      disease_ontology_name = paste("Disease", entity_id),
      hpo_mode_of_inheritance_term_name = "Autosomal dominant",
      category = "Definitive",
      category_id = 1L,
      ndd_phenotype_word = "yes",
      synopsis = "Detailed public synopsis",
      review_date = as.Date("2025-01-01")
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_entity_phenotypes", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_variation", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_publications", function(entity_id, limit) {
    tibble::tibble(
      publication_id = "PMID:20890276",
      Title = "Shared NMDA paper",
      Abstract = "Abstract text",
      Journal = "Journal",
      Publication_date = as.Date("2010-01-01"),
      Lastname = "Smith",
      Firstname = "A",
      publication_type = "Journal Article",
      curation_review_date = as.Date("2025-01-01")
    )
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_resolve_gene", old_resolve, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_entities", old_entities, envir = .GlobalEnv)
    assign("mcp_repo_count_gene_entities", old_count, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_comparisons", old_comparisons, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_context", old_context, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_phenotypes", old_phenotypes, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_variation", old_variation, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_publications", old_publications, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_context(
    "GRIN2A",
    entity_limit = 2L,
    expand = "entities",
    abstract_mode = "metadata"
  )

  expect_equal(result$meta$entity_total, 7L)
  expect_equal(result$meta$entity_returned, 2L)
  expect_true(result$meta$entity_has_more)
  expect_equal(result$meta$next_entity_offset, 2L)
  expect_equal(result$meta$expand, "entities")
  expect_equal(result$entity_details$meta$publication_shape, "top_level_deduplicated")
  expect_equal(length(result$entity_details$publications), 1L)
  expect_null(result$entity_details$publications[[1]]$abstract_excerpt)
})

test_that("get_gene_context expand respects the batch detail cap instead of erroring", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_resolve <- mcp_repo_resolve_gene
  old_entities <- mcp_repo_get_gene_entities
  old_count <- mcp_repo_count_gene_entities
  old_comparisons <- mcp_repo_get_gene_comparisons
  old_context <- mcp_repo_get_entity_context
  old_phenotypes <- mcp_repo_get_entity_phenotypes
  old_variation <- mcp_repo_get_entity_variation
  old_publications <- mcp_repo_get_entity_publications
  assign("mcp_repo_resolve_gene", function(normalized_gene) {
    tibble::tibble(hgnc_id = "HGNC:1", symbol = "BIGGENE", name = "large entity gene")
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_entities", function(hgnc_id, limit, offset, ...) {
    tibble::tibble(
      entity_id = seq_len(limit),
      symbol = "BIGGENE",
      hgnc_id = "HGNC:1",
      disease_ontology_id_version = paste0("MONDO:", seq_len(limit)),
      disease_ontology_name = paste("Disease", seq_len(limit)),
      hpo_mode_of_inheritance_term_name = "Autosomal dominant",
      category = "Definitive",
      ndd_phenotype_word = "yes",
      synopsis = "Public synopsis"
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_count_gene_entities", function(...) 25L, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_comparisons", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_context", function(entity_id) {
    tibble::tibble(
      entity_id = entity_id,
      hgnc_id = "HGNC:1",
      symbol = "BIGGENE",
      disease_ontology_id_version = paste0("MONDO:", entity_id),
      disease_ontology_name = paste("Disease", entity_id),
      hpo_mode_of_inheritance_term_name = "Autosomal dominant",
      category = "Definitive",
      category_id = 1L,
      ndd_phenotype_word = "yes",
      synopsis = "Detailed public synopsis",
      review_date = as.Date("2025-01-01")
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_entity_phenotypes", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_variation", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_publications", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_resolve_gene", old_resolve, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_entities", old_entities, envir = .GlobalEnv)
    assign("mcp_repo_count_gene_entities", old_count, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_comparisons", old_comparisons, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_context", old_context, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_phenotypes", old_phenotypes, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_variation", old_variation, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_publications", old_publications, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_context("BIGGENE", entity_limit = 25L, expand = "entities")

  expect_equal(result$meta$entity_limit, 25L)
  expect_equal(result$meta$entity_returned, 20L)
  expect_equal(result$meta$entity_detail_limit, 20L)
  expect_true(result$meta$entity_detail_truncated_by_batch_cap)
  expect_equal(result$entity_details$meta$requested, 20L)
})
