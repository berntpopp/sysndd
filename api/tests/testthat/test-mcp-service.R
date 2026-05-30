test_that("get_gene_context shapes compact public gene payloads", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_resolve <- mcp_repo_resolve_gene
  old_entities <- mcp_repo_get_gene_entities
  old_count <- mcp_repo_count_gene_entities
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
  assign("mcp_repo_count_gene_entities", function(...) 1L, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_comparisons", function(...) tibble::tibble(list = "OMIM", category = "Definitive"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_resolve_gene", old_resolve, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_entities", old_entities, envir = .GlobalEnv)
    assign("mcp_repo_count_gene_entities", old_count, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_comparisons", old_comparisons, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_context("MECP2")

  expect_equal(result$schema_version, MCP_SCHEMA_VERSION)
  expect_equal(result$gene$symbol, "MECP2")
  expect_true(result$entities[[1]]$synopsis_truncated)
  expect_lte(nchar(result$entities[[1]]$synopsis_excerpt), 1500)
  expect_equal(result$comparison_sources, list())
  expect_equal(result$resource_links[[1]]$uri, "sysndd://gene/MECP2")
})

test_that("MCP payload mode helpers shape abstracts and synopses predictably", {
  source("../../services/mcp-service.R")

  expect_equal(mcp_validate_mode(NULL, c("compact", "standard"), "response_mode", "compact"), "compact")
  expect_equal(mcp_validate_mode("standard", c("compact", "standard"), "response_mode", "compact"), "standard")
  err <- tryCatch(
    mcp_validate_mode("verbose", c("compact", "standard"), "response_mode", "compact"),
    mcp_tool_error = function(e) unclass(e)
  )
  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "response_mode")

  pub <- list(
    publication_id = "PMID:1",
    Title = "A title",
    Abstract = paste(rep("Abstract", 300), collapse = " "),
    Journal = "Journal",
    Publication_date = as.Date("2020-01-01"),
    Lastname = "Smith",
    publication_type = "Journal Article",
    curation_review_date = as.Date("2021-01-01")
  )

  no_abstract <- mcp_publication_record(pub, abstract_mode = "none")
  expect_null(no_abstract$abstract_available)
  expect_null(no_abstract$abstract_excerpt)

  metadata <- mcp_publication_record(pub, abstract_mode = "metadata")
  expect_true(metadata$abstract_available)
  expect_null(metadata$abstract_excerpt)
  expect_null(metadata$abstract_truncated)

  excerpt <- mcp_publication_record(pub, abstract_mode = "excerpt", abstract_max_chars = 40L)
  expect_true(excerpt$abstract_available)
  expect_lte(nchar(excerpt$abstract_excerpt), 40L)
  expect_true(excerpt$abstract_truncated)

  entity <- list(entity_id = 10L, synopsis = paste(rep("Long public synopsis", 20), collapse = " "), review_date = as.Date("2025-01-01"))
  none <- mcp_apply_synopsis_mode(entity, "none", 10L)
  expect_null(none$entity$synopsis)
  expect_equal(none$review$review_date, "2025-01-01")

  excerpt_synopsis <- mcp_apply_synopsis_mode(entity, "excerpt", 40L)
  expect_lte(nchar(excerpt_synopsis$review$synopsis), 40L)
  expect_true(excerpt_synopsis$review$synopsis_truncated)

  full <- mcp_apply_synopsis_mode(entity, "full", 40L)
  expect_equal(full$review$synopsis, entity$synopsis)
  expect_false(full$review$synopsis_truncated)
})

test_that("gene identifier normalization keeps the stored HGNC prefix", {
  source("../../services/mcp-service.R")

  prefixed <- mcp_normalize_gene_input("HGNC:18704")
  bare <- mcp_normalize_gene_input("18704")
  symbol <- mcp_normalize_gene_input("NAA10")

  expect_equal(prefixed, list(kind = "hgnc_id", value = "HGNC:18704"))
  expect_equal(bare, list(kind = "hgnc_id", value = "HGNC:18704"))
  expect_equal(symbol, list(kind = "symbol", value = "NAA10"))
})

test_that("MCP error payloads are JSON-serializable without condition internals", {
  source("../../services/mcp-service.R")

  err <- mcp_error(
    "temporarily_unavailable",
    "Wrapped failure",
    fields = list(cause = simpleError("database unavailable"))
  )

  payload <- mcp_error_payload(err)

  expect_equal(payload$schema_version, MCP_SCHEMA_VERSION)
  expect_equal(payload$error$code, "temporarily_unavailable")
  expect_false(inherits(payload$error$cause, "condition"))
  expect_no_error(jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", na = "null"))
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
  expect_equal(result$meta$publication_limit, 25L)
  expect_equal(result$meta$phenotype_cap, 100L)
  expect_equal(result$meta$variation_cap, 100L)
  expect_true(result$meta$include_publications)
  expect_false(result$meta$include_phenotypes)
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
      publication_date_source = "pubmed",
      Lastname = "Gogoll",
      Firstname = "L",
      Keywords = "NAA10",
      entity_id = c(451L, 452L),
      symbol = c("NAA10", "NAA15"),
      hgnc_id = c("18704", "30782"),
      disease_ontology_name = c("NAA10-related syndrome", "NAA15-related syndrome"),
      category = c("Definitive", "Moderate"),
      publication_type = c("Original", "Review"),
      curation_review_date = as.Date(c("2023-04-12", "2024-02-01"))
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_repo_get_publication_context", old_publication, envir = .GlobalEnv))

  result <- mcp_get_publication_context("37130971")

  expect_equal(result$publication_date_sysndd_record, "2021-08-01")
  expect_null(result$publication_date)
  expect_false(result$abstract_available)
  expect_null(result$abstract_excerpt)
  expect_match(result$recommended_citation, "Gogoll")
  expect_match(result$recommended_citation, "Am J Med Genet A")
  expect_match(result$recommended_citation, "PMID:37130971")
  expect_equal(result$linked_entities[[1]]$sysndd_curation_date, "2023-04-12")
  expect_equal(result$linked_entities[[1]]$publication_type, "Original")
  expect_equal(result$publication_types, list("Original", "Review"))
  expect_equal(result$publication_date_confidence, "pubmed_verified")

  metadata <- mcp_get_publication_context("37130971", abstract_mode = "metadata")
  expect_false(metadata$abstract_available)
  expect_null(metadata$abstract_excerpt)
  expect_null(metadata$abstract_truncated)

  no_abstract <- mcp_get_publication_context("37130971", abstract_mode = "none")
  expect_null(no_abstract$abstract_available)
  expect_null(no_abstract$abstract_excerpt)
})
