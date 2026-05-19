test_that("batch entity context preserves order and returns per-entity errors", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_context <- mcp_repo_get_entity_context
  old_phenotypes <- mcp_repo_get_entity_phenotypes
  old_variation <- mcp_repo_get_entity_variation
  old_publications <- mcp_repo_get_entity_publications
  assign("mcp_repo_get_entity_context", function(entity_id) {
    if (identical(entity_id, 999L)) {
      return(tibble::tibble())
    }
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

test_that("batch entity context deduplicates shared publications by default", {
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
      hgnc_id = "HGNC:6990",
      category = "Definitive",
      synopsis = paste("Public synopsis", entity_id),
      review_date = as.Date("2025-01-01")
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_entity_phenotypes", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_variation", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_publications", function(entity_id, limit) {
    tibble::tibble(
      publication_id = c("PMID:20301670", paste0("PMID:", entity_id)),
      Title = c("Shared GeneReviews", paste("Entity paper", entity_id)),
      Abstract = c("Shared abstract", paste("Entity abstract", entity_id)),
      Journal = "Journal",
      Publication_date = as.Date("2020-01-01"),
      Lastname = "Smith",
      Firstname = "A",
      publication_type = "Journal Article",
      curation_review_date = as.Date("2025-01-01")
    )
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_get_entity_context", old_context, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_phenotypes", old_phenotypes, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_variation", old_variation, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_publications", old_publications, envir = .GlobalEnv)
  })

  result <- mcp_get_entities_context(c(10L, 11L), publication_limit = 2L)

  expect_equal(result$meta$dedupe_publications, TRUE)
  expect_equal(result$meta$publication_shape, "top_level_deduplicated")
  expect_equal(length(result$publications), 3L)
  expect_equal(result$meta$publication_limit, 2L)
  expect_equal(result$meta$abstract_mode, "metadata")
  expect_equal(result$meta$synopsis_mode, "excerpt")
  expect_equal(
    sort(vapply(result$publications, `[[`, character(1), "publication_id")),
    sort(c("PMID:20301670", "PMID:10", "PMID:11"))
  )
  expect_null(result$entities[[1]]$publications)
  expect_equal(result$entities[[1]]$publication_refs[[1]]$publication_id, "PMID:20301670")
  expect_equal(result$entities[[2]]$publication_refs[[1]]$publication_id, "PMID:20301670")
})

test_that("SysNDD MCP capabilities summarize workflows, modes, limits, errors, resources, and safety", {
  source("../../services/mcp-service.R")

  result <- mcp_get_sysndd_capabilities()

  expect_equal(result$schema_version, MCP_SCHEMA_VERSION)
  expect_true("search_sysndd" %in% result$canonical_workflows$gene_summary)
  expect_true("compact" %in% result$payload_modes$response_mode)
  expect_true("none" %in% result$payload_modes$abstract_mode)
  expect_equal(result$payload_modes$gene_expand_example$expand, "entities")
  expect_equal(result$payload_modes$metadata_mode_abstract_fields$includes, "abstract_available")
  expect_true("abstract_excerpt" %in% result$payload_modes$metadata_mode_abstract_fields$omits)
  expect_equal(result$limits$get_gene_context$max_entity_detail_expand_ids, 20L)
  expect_equal(result$limits$get_entities_context$max_entity_ids, 20L)
  expect_true("invalid_input" %in% result$error_codes)
  expect_match(result$resources$static[[1]], "sysndd://schema", fixed = TRUE)
  expect_match(result$safety$scope, "read-only", ignore.case = TRUE)
})

test_that("mcp_get_genes_context batches genes with per-gene errors", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_resolve <- mcp_repo_resolve_gene
  old_entities <- mcp_repo_get_gene_entities
  old_count <- mcp_repo_count_gene_entities
  old_comparisons <- mcp_repo_get_gene_comparisons
  assign("mcp_repo_resolve_gene", function(normalized_gene) {
    if (identical(normalized_gene$value, "DEFINITELY-NOT-A-GENE")) {
      return(tibble::tibble())
    }
    tibble::tibble(hgnc_id = "HGNC:9154", symbol = "PNKP", name = "PNKP")
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_entities", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_count_gene_entities", function(...) 0L, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_comparisons", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_resolve_gene", old_resolve, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_entities", old_entities, envir = .GlobalEnv)
    assign("mcp_repo_count_gene_entities", old_count, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_comparisons", old_comparisons, envir = .GlobalEnv)
  })

  res <- mcp_get_genes_context(genes = list("PNKP", "definitely-not-a-gene"))
  expect_equal(res$schema_version, MCP_SCHEMA_VERSION)
  expect_length(res$genes, 2L)
  expect_equal(res$meta$requested, 2L)
  expect_equal(res$meta$returned, 1L)
  expect_equal(res$meta$errors, 1L)
  expect_null(res$genes[[1]]$error)
  expect_false(is.null(res$genes[[2]]$error))
})

test_that("mcp_get_genes_context rejects an over-cap batch", {
  source("../../services/mcp-service.R")

  too_many <- as.list(sprintf("GENE%d", seq_len(11)))
  expect_error(mcp_get_genes_context(genes = too_many), class = "mcp_tool_error")
})
