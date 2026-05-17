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
      curation_review_date = as.Date(c("2023-04-12", "2024-02-01"))
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_repo_get_publication_context", old_publication, envir = .GlobalEnv))

  result <- mcp_get_publication_context("37130971")

  expect_equal(result$publication_date_sysndd_record, "2021-08-01")
  expect_null(result$publication_date)
  expect_false(result$abstract_available)
  expect_equal(result$abstract_excerpt, "")
  expect_match(result$recommended_citation, "Gogoll")
  expect_match(result$recommended_citation, "Am J Med Genet A")
  expect_match(result$recommended_citation, "PMID:37130971")
  expect_equal(result$linked_entities[[1]]$sysndd_curation_date, "2023-04-12")
  expect_false(result$publication_date_matches_curation_date)
  expect_equal(result$publication_date_confidence, "pubmed_verified")

  metadata <- mcp_get_publication_context("37130971", abstract_mode = "metadata")
  expect_false(metadata$abstract_available)
  expect_null(metadata$abstract_excerpt)
  expect_null(metadata$abstract_truncated)

  no_abstract <- mcp_get_publication_context("37130971", abstract_mode = "none")
  expect_null(no_abstract$abstract_available)
  expect_null(no_abstract$abstract_excerpt)
})

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

test_that("publication context flags dates that mirror curation dates", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_publication <- mcp_repo_get_publication_context
  assign("mcp_repo_get_publication_context", function(publication_id) {
    tibble::tibble(
      publication_id = publication_id,
      Title = "Paper",
      Abstract = "Abstract",
      Journal = "Journal",
      Publication_date = as.Date("2023-04-12"),
      publication_date_source = NA_character_,
      Lastname = "Smith",
      Firstname = "A",
      Keywords = "",
      entity_id = 451L,
      symbol = "NAA10",
      hgnc_id = "18704",
      disease_ontology_name = "NAA10-related syndrome",
      category = "Definitive",
      curation_review_date = as.Date("2023-04-12")
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_repo_get_publication_context", old_publication, envir = .GlobalEnv))

  result <- mcp_get_publication_context("PMID:1")

  expect_true(result$publication_date_matches_curation_date)
  expect_equal(result$publication_date_confidence, "matches_curation_date")
  expect_match(result$date_notes$publication_date_sysndd_record, "equals", fixed = TRUE)
})

test_that("publication context date confidence considers all linked curation dates", {
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

  expect_true(result$publication_date_matches_curation_date)
  expect_equal(result$publication_date_confidence, "matches_curation_date")
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
  expect_equal(no_source$confidence, "matches_curation_date")
  expect_true(no_source$matches_curation_date)

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
  expect_equal(rec$publication_date_confidence, "matches_curation_date")
  expect_match(rec$recommended_citation, "publication date unverified")
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
