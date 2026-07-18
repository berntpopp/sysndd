mcp_fixture_dir <- Sys.getenv("MCP_TEST_FIXTURE_DIR", "")
mcp_fixture_path <- if (nzchar(mcp_fixture_dir)) {
  file.path(mcp_fixture_dir, "helper-mcp-select-principal.R")
} else {
  testthat::test_path("helper-mcp-select-principal.R")
}
source(mcp_fixture_path, local = TRUE)

source(
  Sys.getenv(
    "MCP_MANIFEST_PATH",
    file.path(get_api_dir(), "functions", "migration-manifest.R")
  ),
  local = FALSE
)

migration_path <- Sys.getenv(
  "MCP_MIGRATION_PATH",
  file.path(get_api_dir(), "..", "db", "migrations", "044_mcp_public_read_projections.sql")
)
contract_path <- Sys.getenv(
  "MCP_CONTRACT_PATH",
  file.path(get_api_dir(), "functions", "mcp-readonly-contract.R")
)

test_that("migration 044 and contract freeze exactly 23 projections", {
  expect_true(file.exists(migration_path))
  expect_true(file.exists(contract_path))

  source(contract_path, local = FALSE)
  expected <- mcp_select_expected_columns()

  expect_identical(mcp_readonly_projection_names(), names(expected))
  expect_identical(mcp_readonly_projection_columns(), expected)
  expect_length(mcp_readonly_projection_names(), 23L)
})

test_that("all projections are explicit CURRENT_USER security-definer views", {
  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
  executable_sql <- gsub("(?m)^\\s*--.*$", "", sql, perl = TRUE)
  expected <- mcp_select_expected_columns()

  expect_length(gregexpr("CREATE OR REPLACE", sql, fixed = TRUE)[[1]], 23L)
  expect_length(gregexpr("DEFINER = CURRENT_USER", sql, fixed = TRUE)[[1]], 23L)
  expect_length(gregexpr("SQL SECURITY DEFINER", sql, fixed = TRUE)[[1]], 23L)
  expect_false(grepl("SELECT\\s+\\*", executable_sql, perl = TRUE, ignore.case = TRUE))
  expect_false(grepl("CREATE\\s+(USER|ROLE)|GRANT\\s|REVOKE\\s|PASSWORD", executable_sql,
    perl = TRUE, ignore.case = TRUE
  ))

  for (view in names(expected)) {
    expect_match(sql, paste0("VIEW `", view, "`"), fixed = TRUE)
  }
})

test_that("projection contract freezes the bounded dependency DAG", {
  source(contract_path, local = FALSE)
  deps <- mcp_readonly_projection_dependencies()

  expect_identical(deps[names(mcp_select_expected_dependencies())], mcp_select_expected_dependencies())
  child_views <- grep("^mcp_public_analysis_(network|cluster|correlation)", names(deps), value = TRUE)
  expect_true(all(vapply(
    child_views,
    function(name) "mcp_public_analysis_manifest" %in% deps[[name]],
    logical(1)
  )))
})

test_that("contract derives normalized trusted definitions from migration 044", {
  source(contract_path, local = FALSE)
  definitions <- mcp_readonly_trusted_view_definitions(migration_path)

  expect_identical(names(definitions), mcp_readonly_projection_names())
  expect_true(all(nzchar(unname(definitions))))
  expect_true(all(!grepl("create or replace|definer|sql security", definitions)))
  expect_match(
    definitions[["mcp_public_analysis_manifest"]],
    "m.source_data_version=sv.source_data_version",
    fixed = TRUE
  )
})

test_that("trusted normalization matches MySQL canonical VIEW_DEFINITION", {
  source(contract_path, local = FALSE)
  trusted <- mcp_readonly_trusted_view_definitions(migration_path)
  stored <- paste0(
    "select `m`.`snapshot_id` AS `snapshot_id`,`m`.`analysis_type` AS `analysis_type`,",
    "`m`.`parameter_hash` AS `parameter_hash`,`m`.`schema_version` AS `schema_version`,",
    "`m`.`data_class` AS `data_class`,`m`.`generated_at` AS `generated_at`,",
    "`m`.`activated_at` AS `activated_at`,`m`.`stale_after` AS `stale_after`,",
    "`m`.`source_data_version` AS `source_data_version`,`m`.`parameters_json` AS `parameters_json`,",
    "`m`.`payload_hash` AS `payload_hash`,`m`.`algorithm_name` AS `algorithm_name`,",
    "`m`.`algorithm_version` AS `algorithm_version`,`m`.`row_counts_json` AS `row_counts_json` ",
    "from (`verify_a`.`analysis_snapshot_manifest` `m` join ",
    "`verify_a`.`mcp_public_analysis_source_version` `sv` on((`m`.`source_data_version` = ",
    "`verify_a`.`sv`.`source_data_version`))) where ((`m`.`public_ready` = 1) and ",
    "(`m`.`status` = 'public_ready') and (`m`.`stale_after` is not null) and ",
    "(`m`.`stale_after` > utc_timestamp()) and (`m`.`source_data_version` = ",
    "`verify_a`.`sv`.`source_data_version`) and (`m`.`schema_version` = '1.2'))"
  )

  expect_identical(
    mcp_readonly_normalize_view_sql(stored, schema = "verify_a"),
    trusted[["mcp_public_analysis_manifest"]]
  )

  malicious <- sub("'public_ready'", "'pending'", stored, fixed = TRUE)
  expect_false(identical(
    mcp_readonly_normalize_view_sql(malicious, schema = "verify_a"),
    trusted[["mcp_public_analysis_manifest"]]
  ))
})

test_that("canonical hashes preserve predicate grouping on MySQL 8.4", {
  source(contract_path, local = FALSE)
  hashes <- mcp_readonly_canonical_view_hashes()
  runtime <- mcp_readonly_canonical_hash_runtime()

  expect_identical(names(hashes), mcp_readonly_projection_names())
  expect_true(all(grepl("^[0-9a-f]{64}$", unname(hashes))))
  expect_identical(runtime, list(database_family = "MySQL", major_minor = "8.4"))

  trusted_grouping <- "select x from t where ((a=1) and ((b=1) or (c=1)))"
  hostile_grouping <- "select x from t where (((a=1) and (b=1)) or (c=1))"
  expect_false(identical(
    mcp_readonly_canonical_view_hash(trusted_grouping, schema = "verify_a"),
    mcp_readonly_canonical_view_hash(hostile_grouping, schema = "verify_a")
  ))
})

test_that("migration enforces public lifecycle and confidentiality gates", {
  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")

  required <- c(
    "nal.`status` = 'Approved'", "e.`is_active` = 1",
    "r.`is_primary` = 1", "r.`review_approved` = 1",
    "c.`is_active` = 1", "rpj.`is_reviewed` = 1",
    "m.`public_ready` = 1", "m.`status` = 'public_ready'",
    "m.`stale_after` IS NOT NULL", "m.`stale_after` > UTC_TIMESTAMP()",
    "m.`source_data_version` = sv.`source_data_version`",
    "m.`schema_version` = '1.2'", "r.`import_status` = 'active'",
    "r.`is_active` = 1", "c.`validation_status` = 'validated'",
    "c.`is_current` = 1", "c.`prompt_version` = '1.0'"
  )
  for (predicate in required) expect_match(sql, predicate, fixed = TRUE)

  forbidden <- c(
    "review_user_id", "approving_user_id", "comment", "last_error_message",
    "generated_by_job_id", "warnings_json", "package_versions_json",
    "source_archive_name", "source_archive_checksum", "source_archive_bytes"
  )
  for (column in forbidden) {
    expect_false(any(vapply(mcp_select_expected_columns(), function(cols) column %in% cols, logical(1))))
  }
})

test_that("source version formula and derived-content allowlists are frozen", {
  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
  source(file.path(get_api_dir(), "functions", "llm-summary-config.R"), local = FALSE)

  source_formula <- c(
    "(SELECT COUNT(*) FROM `ndd_entity_view`)",
    "r.`is_primary` = 1 AND r.`review_approved` = 1",
    "rpc.`is_active` = 1",
    "s.`is_active` = 1 AND s.`status_approved` = 1"
  )
  for (fragment in source_formula) expect_match(sql, fragment, fixed = TRUE)
  expect_match(sql, paste0("c.`prompt_version` = '", LLM_SUMMARY_PROMPT_VERSION, "'"), fixed = TRUE)

  allowed_json_keys <- c(
    "summary", "key_themes", "pathways", "tags", "clinical_relevance", "confidence",
    "key_phenotype_themes", "notably_absent", "clinical_pattern", "syndrome_hints",
    "inheritance_patterns", "syndromicity", "data_quality_note"
  )
  expect_identical(mcp_readonly_llm_summary_json_keys(), allowed_json_keys)
  expect_false(grepl("judge|reasoning|validation_status", paste(allowed_json_keys, collapse = "|")))
})

test_that("manifest advances contiguously to migration 045", {
  expect_identical(EXPECTED_LATEST_MIGRATION, "045_add_analysis_snapshot_release.sql")
  expect_identical(EXPECTED_MIGRATION_COUNT, 43L)
})
