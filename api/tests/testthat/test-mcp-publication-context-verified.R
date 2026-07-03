# Confirms that once publication_date_source is verified (`pubmed`), the MCP
# publication record surfaces it as trusted: publication_date_confidence becomes
# `pubmed_verified` and recommended_citation carries the year (#460). The
# derivation (mcp-service.R) and citation already support this; this test locks it
# so the backfill's effect is queryable through the MCP read path.
#
# mcp_get_publication_context(pmid, abstract_max_chars, abstract_mode) takes a
# SINGLE prefixed pmid and NO conn (it opens its own approved-public read; batch
# variant is mcp_get_publications_context(pmids, ...)). The MCP services are loaded
# into .GlobalEnv by helper-mcp-services.R, and mcp_repo_get_publication_context's
# INNER JOIN to ndd_entity_view makes a DB-seed approach infeasible for a unit test,
# so the repository read is mocked the same way as
# test-mcp-service-publication-discovery.R.
test_that("verified publication yields pubmed_verified confidence and a dated citation", {
  source(file.path(get_api_dir(), "functions", "mcp-repository.R"), local = FALSE)
  source(file.path(get_api_dir(), "services", "mcp-service.R"), local = FALSE)

  old_publication <- mcp_repo_get_publication_context
  assign("mcp_repo_get_publication_context", function(publication_id) {
    tibble::tibble(
      publication_id = publication_id,
      Title = "Verified paper",
      Abstract = "Abstract",
      Journal = "Journal",
      Publication_date = as.Date("2018-07-15"),
      publication_date_source = "pubmed",
      Lastname = "Smith",
      Firstname = "A",
      Keywords = "",
      entity_id = 451L,
      symbol = "ARID1B",
      hgnc_id = "18040",
      disease_ontology_name = "ARID1B-related disorder",
      category = "Definitive",
      publication_type = NA_character_,
      curation_review_date = as.Date("2023-04-12")
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_repo_get_publication_context", old_publication, envir = .GlobalEnv))

  rec <- mcp_get_publication_context("PMID:999200")

  expect_equal(rec$publication_date_confidence, "pubmed_verified")
  expect_match(rec$recommended_citation, "2018")
})
