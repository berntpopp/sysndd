# tests/testthat/test-unit-helper-functions.R
# Unit tests for api/functions/helper-functions.R
#
# These tests cover pure functions that don't require database access.
# Run with: Rscript -e "testthat::test_file('tests/testthat/test-unit-helper-functions.R')"

# Load required libraries
library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(tidyr)

# Source the functions being tested using the helper
# Use local = FALSE to make functions available in test scope
source_api_file("functions/helper-functions.R", local = FALSE)
# errors.R provides stop_for_bad_request(), which select_tibble_fields() uses to
# signal a recoverable 400. Source into the global env so select_tibble_fields()
# (also global) resolves the LOCAL stop_for_bad_request() rather than the
# httpproblems package export — this mirrors the production bootstrap
# (load_modules.R sources into .GlobalEnv).
source_api_file("core/errors.R", local = FALSE, envir = globalenv())

# =============================================================================
# is_valid_email() tests
# =============================================================================

test_that("is_valid_email returns TRUE for valid email addresses", {
  expect_true(is_valid_email("test@example.com"))
  expect_true(is_valid_email("user.name@domain.org"))
  expect_true(is_valid_email("user+tag@example.co.uk"))
  expect_true(is_valid_email("USER@CAPS.COM"))
  expect_true(is_valid_email("john.doe123@university.edu"))
})

test_that("is_valid_email returns FALSE for invalid email addresses", {
  expect_false(is_valid_email("not-an-email"))
  expect_false(is_valid_email("missing@"))
  expect_false(is_valid_email("@nodomain.com"))
  expect_false(is_valid_email(""))
  expect_false(is_valid_email("no-at-sign.com"))
})

test_that("is_valid_email handles edge cases", {
  # Single character domain parts should fail (needs 2+ chars in TLD)
  expect_false(is_valid_email("test@example.c"))

  # Numbers in email are valid
  expect_true(is_valid_email("user123@domain456.com"))

  # Dots in local part are valid
  expect_true(is_valid_email("first.last@example.com"))

  # Underscores are valid
  expect_true(is_valid_email("user_name@example.com"))
})


# =============================================================================
# generate_initials() tests
# =============================================================================

test_that("generate_initials creates correct initials from names", {
  expect_equal(generate_initials("John", "Doe"), "JD")
  expect_equal(generate_initials("Ada", "Lovelace"), "AL")
  expect_equal(generate_initials("Marie", "Curie"), "MC")
})

test_that("generate_initials handles single-letter names", {
  expect_equal(generate_initials("A", "B"), "AB")
})

test_that("generate_initials handles lowercase input", {
  # Function takes first char regardless of case
  expect_equal(generate_initials("john", "doe"), "jd")
})


# =============================================================================
# generate_sort_expressions() tests
# =============================================================================

test_that("generate_sort_expressions parses ascending sort", {
  result <- generate_sort_expressions("+name", unique_id = "id")

  expect_true("name" %in% result)
  # unique_id should be appended if not present
  expect_true("id" %in% result)
})

test_that("generate_sort_expressions parses descending sort", {
  result <- generate_sort_expressions("-name", unique_id = "id")

  expect_true("desc(name)" %in% result)
  expect_true("id" %in% result)
})

test_that("generate_sort_expressions handles multiple columns", {
  result <- generate_sort_expressions("+name,-age,+date", unique_id = "id")

  expect_true("name" %in% result)
  expect_true("desc(age)" %in% result)
  expect_true("date" %in% result)
  expect_true("id" %in% result)
})

test_that("generate_sort_expressions defaults to ascending without prefix", {

  result <- generate_sort_expressions("name", unique_id = "id")

  expect_true("name" %in% result)
})

test_that("generate_sort_expressions includes unique_id only once", {
  # When unique_id is already in sort list, don't duplicate
  result <- generate_sort_expressions("+entity_id,-name", unique_id = "entity_id")

  # entity_id should appear only once
  expect_equal(sum(grepl("entity_id", result)), 1)
})


# =============================================================================
# generate_filter_expressions() tests
# =============================================================================

test_that("generate_filter_expressions returns empty string for empty input", {
  expect_equal(generate_filter_expressions(""), "")
})

test_that("generate_filter_expressions returns empty string for 'null' input", {
  expect_equal(generate_filter_expressions("null"), "")
})

test_that("generate_filter_expressions handles contains operation", {
  result <- generate_filter_expressions("contains(name,'John')")
  expect_true(grepl("str_detect", result))
  expect_true(grepl("name", result))
  expect_true(grepl("John", result))
})

test_that("generate_filter_expressions handles equals operation (single column)", {
  # Single-column equals emits direct equality so dbplyr can translate it to
  # SQL `WHERE column = 'value'` (indexable, ~20x faster than the legacy
  # REGEXP form). MySQL collation defaults to case-insensitive on our schema,
  # so semantics are preserved.
  result <- generate_filter_expressions("equals(status,'active')")
  expect_true(grepl("status\\s*==\\s*'active'", result))
})

test_that("generate_filter_expressions equals with any/all column keeps anchored regex", {
  # Multi-column equals must compare across many columns, so it stays as
  # str_detect with anchors (run after collect, no SQL pushdown).
  result_any <- generate_filter_expressions("equals(any,'active')")
  expect_true(grepl("str_detect", result_any))
  expect_true(grepl("\\^active\\$", result_any))
  result_all <- generate_filter_expressions("equals(all,'active')")
  expect_true(grepl("str_detect", result_all))
  expect_true(grepl("\\^active\\$", result_all))
})

test_that("generate_filter_expressions equals stays correct when value contains regex meta-chars", {
  # Single quotes are stripped at parse time (line 177 of response-helpers.R),
  # but other regex special chars survive. Direct equality is more correct than
  # the legacy anchored regex form for these — `equals(symbol,'GR.IN2B')`
  # should match the literal string, not "GR<any-char>IN2B" as the old
  # str_detect form would have done.
  for (val in c("GR.IN2B", "AB[CD]", "ABC|XYZ", "P53*", "AB+CD")) {
    expr <- generate_filter_expressions(sprintf("equals(symbol,'%s')", val))
    expect_match(expr, "symbol\\s*==\\s*'", info = paste("expr for", val))
    expect_true(grepl(val, expr, fixed = TRUE), info = paste("value preserved for", val))
    expect_false(grepl("str_detect", expr), info = paste("no regex form for", val))
  }
})

test_that("generate_filter_expressions equals composes inside and()/or() with == form", {
  # The single-column equals fragments must keep emitting `==` even when the
  # outer expression is and/or — otherwise the SQL pushdown loses its win
  # for compound filters.
  combined <- generate_filter_expressions(
    "and(equals(symbol,'GRIN2B'),equals(category,'Definitive'))"
  )
  expect_match(combined, "symbol\\s*==\\s*'GRIN2B'")
  expect_match(combined, "category\\s*==\\s*'Definitive'")
  expect_true(grepl("&", combined))

  combined_or <- generate_filter_expressions(
    "or(equals(symbol,'GRIN2B'),equals(symbol,'MECP2'))"
  )
  expect_match(combined_or, "symbol\\s*==\\s*'GRIN2B'")
  expect_match(combined_or, "symbol\\s*==\\s*'MECP2'")
  expect_true(grepl("\\|", combined_or))
})

test_that("generate_filter_expressions parses the URL-encoded equals form GeneView/EntityView use", {
  # GeneView mounts TablesEntities with filter=equals(symbol,GRIN2B). axios
  # URL-encodes the parens; the helper URLdecode()s the input.
  encoded <- generate_filter_expressions("equals(symbol%2CGRIN2B)")
  expect_match(encoded, "symbol\\s*==\\s*'GRIN2B'")

  hgnc <- generate_filter_expressions("equals(hgnc_id,'HGNC:4586')")
  expect_match(hgnc, "hgnc_id\\s*==\\s*'HGNC:4586'")
})

test_that("generate_filter_expressions equals with empty value emits valid SQL-ready form", {
  # `equals(symbol,)` should produce `symbol == ''` — the in-R str_remove_all
  # at line 177 of response-helpers.R strips quotes/parens; an empty value
  # survives as empty string. The expression must still parse and dbplyr
  # must accept it (edge case audit recommendation #2).
  empty <- generate_filter_expressions("equals(symbol,)")
  expect_match(empty, "symbol\\s*==\\s*''")
  # And the parsed form must be a valid R expression (parse_exprs would error
  # on a malformed string).
  parsed <- rlang::parse_exprs(empty)
  expect_length(parsed, 1)
})

test_that("generate_filter_expressions equals strips single quotes from value (documented behaviour)", {
  # Line 177 of response-helpers.R strips both `'` and `)` from filter values
  # to defang injection. `equals(symbol,O'Reilly)` therefore becomes
  # `symbol == 'OReilly'`. Pin the contract — no live caller passes single
  # quotes (no SysNDD symbol/HGNC/ontology term contains one), but if a
  # future caller does, the test makes the silent normalisation explicit.
  result <- generate_filter_expressions("equals(name,'O'Reilly')")
  expect_match(result, "name\\s*==\\s*'OReilly'")
  expect_false(grepl("'O'Reilly'", result, fixed = TRUE))
})

test_that("generate_filter_expressions equals composes case-insensitively under MySQL collation", {
  # Audit recommendation #5: pre-fix, `str_detect('^X$')` was case-sensitive
  # in R. Post-fix, the SQL pushdown path uses MySQL `=` which inherits the
  # column collation. Our schema columns default to `utf8mb3_general_ci` /
  # `utf8mb4_general_ci` (case-insensitive). The test confirms that the helper
  # itself emits the value verbatim — case is decided by the DB collation,
  # not by the R expression. Live integration test in
  # test-integration-pagination.R covers the SQL-side observation.
  upper <- generate_filter_expressions("equals(symbol,GRIN2B)")
  lower <- generate_filter_expressions("equals(symbol,grin2b)")
  expect_match(upper, "symbol\\s*==\\s*'GRIN2B'")
  expect_match(lower, "symbol\\s*==\\s*'grin2b'")
  # Helper preserves the literal — no normalisation applied here.
  expect_false(identical(upper, lower))
})

test_that("generate_filter_expressions handles any operation with multiple values", {
  result <- generate_filter_expressions("any(category,'A,B,C')")
  expect_true(grepl("str_detect", result))
  expect_true(grepl("category", result))
  expect_true(grepl("A|B|C", result))  # any uses | for alternatives
})

test_that("generate_filter_expressions handles 'and' logical operator", {
  result <- generate_filter_expressions("and(contains(name,'John'),equals(status,'active'))")
  expect_true(grepl("&", result))  # and uses &
})

test_that("generate_filter_expressions handles 'or' logical operator", {
  result <- generate_filter_expressions("or(contains(name,'John'),equals(status,'active'))")
  expect_true(grepl("\\|", result))  # or uses |
})

test_that("generate_filter_expressions throws error for unsupported operations", {
  expect_error(
    generate_filter_expressions("contains(name,'John')", operations_allowed = "fakeop"),
    "not supported"
  )
})

test_that("generate_filter_expressions handles greaterThan with numeric values", {
  result <- generate_filter_expressions("greaterThan(score,'0.5')")

  # Should produce comparison expression with numeric value (no quotes around 0.5)
  expect_true(grepl("score", result))
  expect_true(grepl(">", result))
  expect_true(grepl("0\\.5", result))
  # Numeric values should not be wrapped in quotes in the output
  expect_false(grepl("'0\\.5'", result))
})

test_that("generate_filter_expressions handles lessThan with numeric values", {
  result <- generate_filter_expressions("lessThan(count,'100')")

  expect_true(grepl("count", result))
  expect_true(grepl("<", result))
  expect_true(grepl("100", result))
})

test_that("generate_filter_expressions handles greaterThanOrEqual with numeric values", {
  # Note: Operation name is "greaterThanOrEqual" not "greaterThanOrEquals"
  result <- generate_filter_expressions("greaterThanOrEqual(value,'10')")

  expect_true(grepl("value", result))
  expect_true(grepl(">=", result))
  expect_true(grepl("10", result))
})

test_that("generate_filter_expressions handles lessThanOrEqual with numeric values", {
  # Note: Operation name is "lessThanOrEqual" not "lessThanOrEquals"
  result <- generate_filter_expressions("lessThanOrEqual(rank,'50')")

  expect_true(grepl("rank", result))
  expect_true(grepl("<=", result))
  expect_true(grepl("50", result))
})

test_that("generate_filter_expressions handles combined numeric filters", {
  # Test that multiple numeric filters work together (vectorized context)
  result <- generate_filter_expressions("and(greaterThan(score,'0.3'),lessThan(score,'0.9'))")

  expect_true(grepl("score", result))
  expect_true(grepl("&", result))  # and uses &
  expect_true(grepl(">", result))
  expect_true(grepl("<", result))
  expect_true(grepl("0\\.3", result))
  expect_true(grepl("0\\.9", result))
})


# =============================================================================
# select_tibble_fields() tests
# =============================================================================

test_that("select_tibble_fields selects specific columns", {
  test_data <- tibble(
    entity_id = 1:5,
    name = letters[1:5],
    age = 20:24,
    city = c("NYC", "LA", "SF", "CHI", "BOS")
  )

  result <- select_tibble_fields(test_data, "name,age", unique_id = "entity_id")

  expect_equal(ncol(result), 3)  # entity_id + name + age
  expect_true("entity_id" %in% colnames(result))
  expect_true("name" %in% colnames(result))
  expect_true("age" %in% colnames(result))
  expect_false("city" %in% colnames(result))
})

test_that("select_tibble_fields returns all columns when fields_requested is empty", {
  test_data <- tibble(
    entity_id = 1:3,
    name = letters[1:3],
    value = 10:12
  )

  result <- select_tibble_fields(test_data, "", unique_id = "entity_id")

  expect_equal(ncol(result), 3)
  expect_equal(colnames(result), colnames(test_data))
})

test_that("select_tibble_fields always includes unique_id even if not requested", {
  test_data <- tibble(
    entity_id = 1:3,
    name = letters[1:3],
    value = 10:12
  )

  result <- select_tibble_fields(test_data, "name", unique_id = "entity_id")

  expect_true("entity_id" %in% colnames(result))
  expect_true("name" %in% colnames(result))
})

test_that("select_tibble_fields throws error for non-existent columns", {
  test_data <- tibble(
    entity_id = 1:3,
    name = letters[1:3]
  )

  expect_error(
    select_tibble_fields(test_data, "nonexistent_column", unique_id = "entity_id"),
    "not in the column names"
  )
})

test_that("select_tibble_fields signals a 400 (not a 500) for unknown fields", {
  # Regression guard for the Modify Entity 500: a request for fields absent from
  # the queried view is a client error. The error must carry the error_400 class
  # so errorHandler maps it to HTTP 400 (mount_endpoints.R now routes every
  # endpoint sub-router through errorHandler), and must name the offending field.
  test_data <- tibble(entity_id = 1:3, name = letters[1:3])

  err <- tryCatch(
    select_tibble_fields(test_data, "is_active,replaced_by", unique_id = "entity_id"),
    error = function(e) e
  )

  expect_s3_class(err, "error_400")
  expect_equal(err$status, 400)
  expect_match(conditionMessage(err), "is_active")
  expect_match(conditionMessage(err), "replaced_by")
})


# =============================================================================
# generate_cursor_pag_inf() tests
# =============================================================================

test_that("generate_cursor_pag_inf returns all rows with page_size='all'", {
  test_data <- tibble(
    entity_id = 1:20,
    value = letters[1:20]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = "all", pagination_identifier = "entity_id")

  expect_equal(nrow(result$data), 20)
  expect_equal(result$meta$perPage, 20)
  expect_equal(result$meta$totalItems, 20)
})

test_that("generate_cursor_pag_inf returns correct slice with numeric page_size", {
  test_data <- tibble(
    entity_id = 1:20,
    value = letters[1:20]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = 5, page_after = 0, pagination_identifier = "entity_id")

  expect_equal(nrow(result$data), 5)
  expect_equal(result$meta$perPage, 5)
  expect_equal(result$meta$totalPages, 4)  # 20 / 5 = 4
})

test_that("generate_cursor_pag_inf meta contains expected fields", {
  test_data <- tibble(
    entity_id = 1:10,
    value = letters[1:10]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = 3, pagination_identifier = "entity_id")

  expect_true("perPage" %in% names(result$meta))
  expect_true("currentPage" %in% names(result$meta))
  expect_true("totalPages" %in% names(result$meta))
  expect_true("totalItems" %in% names(result$meta))
})

test_that("generate_cursor_pag_inf links contain expected navigation links", {
  test_data <- tibble(
    entity_id = 1:10,
    value = letters[1:10]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = 3, pagination_identifier = "entity_id")

  expect_true("prev" %in% names(result$links))
  expect_true("self" %in% names(result$links))
  expect_true("next" %in% names(result$links))
  expect_true("last" %in% names(result$links))
})

test_that("generate_cursor_pag_inf returns correct structure", {
  test_data <- tibble(
    entity_id = 1:5,
    value = letters[1:5]
  )

  result <- generate_cursor_pag_inf(test_data, page_size = 2, pagination_identifier = "entity_id")

  expect_true("links" %in% names(result))
  expect_true("meta" %in% names(result))
  expect_true("data" %in% names(result))
})


# =============================================================================
# generate_tibble_fspec() tests
# =============================================================================

test_that("generate_tibble_fspec generates field specs from tibble", {
  test_data <- tibble(
    entity_id = 1:10,
    category = rep(c("A", "B"), 5),
    status = rep(c("active", "inactive"), 5)
  )

  result <- generate_tibble_fspec(test_data, "entity_id,category,status")

  expect_true("fspec" %in% names(result))
  expect_true("key" %in% names(result$fspec))
  expect_true("filterable" %in% names(result$fspec))
  expect_true("sortable" %in% names(result$fspec))
})

test_that("generate_tibble_fspec determines filterable/selectable based on unique values", {
  # Few unique values should be selectable
  # Threshold: >10 unique values -> filterable, <=2 -> selectable, 3-10 -> multi_selectable
  test_data <- tibble(
    entity_id = 1:15,
    binary = rep(c("yes", "no"), length.out = 15),
    multi = rep(c("A", "B", "C", "D"), length.out = 15),
    many = paste0("value", 1:15)  # 15 unique values -> >10 -> filterable
  )

  result <- generate_tibble_fspec(test_data, "binary,multi,many")

  binary_spec <- result$fspec %>% filter(key == "binary")
  multi_spec <- result$fspec %>% filter(key == "multi")
  many_spec <- result$fspec %>% filter(key == "many")

  # 2 unique values -> selectable
  expect_true(binary_spec$selectable)
  # 4 unique values -> multi_selectable
  expect_true(multi_spec$multi_selectable)
  # 15 unique values (>10) -> filterable
  expect_true(many_spec$filterable)
})

test_that("generate_tibble_fspec handles fspecInput filtering", {
  test_data <- tibble(
    entity_id = 1:5,
    col_a = letters[1:5],
    col_b = LETTERS[1:5],
    col_c = 1:5
  )

  result <- generate_tibble_fspec(test_data, "entity_id,col_a")

  # Only requested columns should be in output
  expect_equal(nrow(result$fspec), 2)
  expect_true("entity_id" %in% result$fspec$key)
  expect_true("col_a" %in% result$fspec$key)
  expect_false("col_b" %in% result$fspec$key)
})


# =============================================================================
# fspec_merge_filtered_counts() tests
# =============================================================================

test_that("fspec_merge_filtered_counts keeps global count and adds filtered count", {
  global <- generate_tibble_fspec(
    tibble(category = c("a", "b", "c"), symbol = c("X", "Y", "Z")),
    "category,symbol"
  )
  filtered <- generate_tibble_fspec(
    tibble(category = c("a", "b"), symbol = c("X", "Y")),
    "category,symbol"
  )

  merged <- fspec_merge_filtered_counts(global, filtered)

  # Total `count` is preserved from the global fspec...
  expect_equal(merged$fspec$count[merged$fspec$key == "category"], 3L)
  # ...while `count_filtered` reflects the filtered set.
  expect_equal(merged$fspec$count_filtered[merged$fspec$key == "category"], 2L)
  expect_true("count_filtered" %in% colnames(merged$fspec))
})

test_that("fspec_merge_filtered_counts joins by key, not by row position", {
  # Reverse the filtered fspec row order to prove the merge is key-based.
  global <- generate_tibble_fspec(
    tibble(alpha = c("a", "b", "c", "d"), zeta = c("p", "q", "r", "s")),
    "alpha,zeta"
  )
  filtered <- generate_tibble_fspec(
    tibble(alpha = "a", zeta = c("p", "q")),
    "zeta,alpha"
  )

  merged <- fspec_merge_filtered_counts(global, filtered)

  expect_equal(merged$fspec$count_filtered[merged$fspec$key == "alpha"], 1L)
  expect_equal(merged$fspec$count_filtered[merged$fspec$key == "zeta"], 2L)
})

test_that("fspec_merge_filtered_counts coalesces missing filtered keys to zero", {
  global <- generate_tibble_fspec(tibble(category = c("a", "b", "c")), "category")
  # Empty filtered set => no rows for any key.
  filtered <- generate_tibble_fspec(tibble(category = character(0)), "category")

  merged <- fspec_merge_filtered_counts(global, filtered)

  expect_equal(merged$fspec$count_filtered[merged$fspec$key == "category"], 0L)
})


# =============================================================================
# generate_panel_hash() and generate_json_hash() tests
# =============================================================================

test_that("generate_panel_hash produces consistent hash for same input", {
  genes <- c("HGNC:12345", "HGNC:67890")

  hash1 <- generate_panel_hash(genes)
  hash2 <- generate_panel_hash(genes)

  expect_equal(hash1, hash2)
})

test_that("generate_panel_hash produces different hash for different inputs", {
  genes1 <- c("HGNC:12345", "HGNC:67890")
  genes2 <- c("HGNC:12345", "HGNC:99999")

  hash1 <- generate_panel_hash(genes1)
  hash2 <- generate_panel_hash(genes2)

  expect_false(hash1 == hash2)
})

test_that("generate_panel_hash removes HGNC prefix before hashing", {
  # Same identifiers with and without HGNC prefix should produce same hash
  genes_with_prefix <- c("HGNC:12345", "HGNC:67890")
  genes_without_prefix <- c("12345", "67890")

  hash_with <- generate_panel_hash(genes_with_prefix)
  hash_without <- generate_panel_hash(genes_without_prefix)

  expect_equal(hash_with, hash_without)
})

test_that("generate_json_hash produces consistent hash for same input", {
  json_string <- '{"key": "value", "number": 123}'

  hash1 <- generate_json_hash(json_string)
  hash2 <- generate_json_hash(json_string)

  expect_equal(hash1, hash2)
})

test_that("generate_json_hash produces different hash for different inputs", {
  json1 <- '{"key": "value1"}'
  json2 <- '{"key": "value2"}'

  hash1 <- generate_json_hash(json1)
  hash2 <- generate_json_hash(json2)

  expect_false(hash1 == hash2)
})


# =============================================================================
# nest_gene_tibble() tests
# =============================================================================

test_that("nest_gene_tibble groups by symbol/hgnc_id/entities_count", {
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    hgnc_id = c(100, 100, 200),
    entities_count = c(2, 2, 1),
    extra_col = c("a", "b", "c")
  )

  result <- nest_gene_tibble(test_data)

  # Should have 2 rows (one per unique symbol/hgnc_id/entities_count combo)
  expect_equal(nrow(result), 2)
  expect_true("entities" %in% colnames(result))
})

test_that("nest_gene_tibble result has entities as list-column", {
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    hgnc_id = c(100, 100, 200),
    entities_count = c(2, 2, 1),
    extra_col = c("a", "b", "c")
  )

  result <- nest_gene_tibble(test_data)

  expect_true(is.list(result$entities))
  # First group (GENE1) should have 2 rows in its nested tibble
  expect_equal(nrow(result$entities[[1]]), 2)
})
