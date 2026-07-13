library(testthat)

.mcp_live_repo_root <- Sys.getenv("SYSNDD_REPO_ROOT", unset = "")
if (!nzchar(.mcp_live_repo_root)) {
  .mcp_live_repo_root <- normalizePath(file.path(get_api_dir(), ".."), mustWork = TRUE)
}

.mcp_live_read <- function(path) {
  readLines(file.path(.mcp_live_repo_root, path), warn = FALSE)
}

test_that("the disposable verifier is isolated and wired through make", {
  compose <- paste(
    .mcp_live_read("docker-compose.mcp-select-verify.yml"),
    collapse = "\n"
  )
  make_fragment <- paste(
    .mcp_live_read("make/mcp-select-principal.mk"),
    collapse = "\n"
  )
  root_make <- paste(.mcp_live_read("Makefile"), collapse = "\n")
  mysql_init <- paste(
    .mcp_live_read("api/scripts/verify-mcp-select-principal-mysql-init.sql"),
    collapse = "\n"
  )

  expect_false(grepl("container_name:|external:|^[[:space:]]+name:", compose))
  expect_match(compose, "com.sysndd.mcp-select-verify-id")
  expect_match(compose, "service_completed_successfully")
  expect_match(compose, "MCP_DB_USER: sysndd_mcp", fixed = TRUE)
  expect_match(
    compose,
    "verify-mcp-select-principal-mysql-init.sql:/docker-entrypoint-initdb.d/",
    fixed = TRUE
  )
  expect_false(grepl("MYSQL_PASSWORD:.*[^}]$", compose))
  expect_match(
    mysql_init,
    "GRANT PROXY ON ''@'' TO 'root'@'%' WITH GRANT OPTION",
    fixed = TRUE
  )
  expect_match(make_fragment, "verify-mcp-select-principal-live")
  expect_match(make_fragment, "verify_mcp_select_assert_labels")
  expect_match(make_fragment, "openssl rand")
  expect_match(root_make, "make/mcp-select-principal.mk", fixed = TRUE)
})

test_that("the live verifier freezes the complete security proof", {
  script <- paste(
    .mcp_live_read("api/scripts/verify-mcp-select-principal-live.R"),
    collapse = "\n"
  )
  fixture <- paste(
    .mcp_live_read("api/scripts/verify-mcp-select-principal-fixtures.R"),
    collapse = "\n"
  )
  make_fragment <- paste(
    .mcp_live_read("make/mcp-select-principal.mk"),
    collapse = "\n"
  )
  quarantine <- paste(
    .mcp_live_read("api/functions/mcp-readonly-provisioner-quarantine.R"),
    collapse = "\n"
  )

  exact_tools <- c(
    "search_sysndd", "get_gene_context", "get_genes_context",
    "get_entity_context", "get_entities_context", "list_gene_entities",
    "get_publication_context", "get_publications_context",
    "find_entities_by_phenotype", "find_entities_by_disease",
    "get_sysndd_stats", "get_sysndd_capabilities",
    "get_sysndd_analysis_catalog", "get_gene_research_context",
    "get_nddscore_context", "get_curation_comparison_context",
    "get_phenotype_analysis_context", "get_gene_network_context"
  )

  for (tool in exact_tools) expect_match(script, tool, fixed = TRUE)
  expect_match(script, "run_migrations")
  expect_match(script, "mcp-readonly-provisioner-quarantine.R", fixed = TRUE)
  expect_match(script, "mcp_readonly_reconcile")
  expect_match(script, "same-shape malicious")
  expect_match(script, "wrong definer")
  expect_match(script, "mandatory_roles")
  expect_match(quarantine, "REVOKE PROXY")
  expect_match(script, "RETAIN CURRENT PASSWORD", fixed = TRUE)
  expect_match(script, "obsolete primary password", fixed = TRUE)
  expect_match(script, "obsolete secondary password", fixed = TRUE)
  expect_match(script, "INSERT")
  expect_match(script, "UPDATE")
  expect_match(script, "DELETE")
  expect_match(script, "tools/list", fixed = TRUE)
  expect_match(script, "tools/call", fixed = TRUE)
  expect_match(script, "snapshot_pending")
  expect_match(script, "source_mismatch")
  expect_match(script, "old_schema")
  expect_match(script, "NULL_expiry")
  expect_match(script, "credential sentinel")
  expect_match(script, "reader_secret", fixed = TRUE)
  expect_match(make_fragment, "generated reader password leaked", fixed = TRUE)
  expect_match(script, "MCP SELECT-only live verification PASS", fixed = TRUE)

  expect_match(fixture, "draft")
  expect_match(fixture, "secondary")
  expect_match(fixture, "inactive")
  expect_match(fixture, "cross_entity")
  expect_match(fixture, "non_ndd")
  expect_match(fixture, "forbidden_nested")
  expect_false(grepl("skip\\(|SKIP|Sys.getenv\\(\"MYSQL_PASSWORD\"", script))
})
