# tests/testthat/test-pagination-contract.R
# Contract tests for D5 pagination sweep
#
# Verifies that:
# 1. paginate_offset() helper produces correct envelope shape
# 2. All target endpoint files declare limit/offset params on GET list handlers
#
# Run with:
#   Rscript -e "testthat::test_file('tests/testthat/test-pagination-contract.R')"

library(testthat)
library(tibble)

# Source the pagination helpers
source_api_file("functions/pagination-helpers.R", local = FALSE)

# =============================================================================
# paginate_offset() unit tests
# =============================================================================

test_that("paginate_offset returns correct envelope shape", {
  data <- tibble(id = 1:100, value = letters[rep(1:26, length.out = 100)])
  result <- paginate_offset(data, limit = 10, offset = 0)

  expect_true(is.list(result))
  expect_named(result, c("data", "links", "meta"))
  expect_true(is.data.frame(result$data))
  expect_true(is.list(result$links))
  expect_true(is.list(result$meta))
})

test_that("paginate_offset meta contains total, limit, offset", {

  data <- tibble(id = 1:100)
  result <- paginate_offset(data, limit = 10, offset = 0)

  expect_equal(result$meta$total, 100)
  expect_equal(result$meta$limit, 10)
  expect_equal(result$meta$offset, 0)
})

test_that("paginate_offset slices data correctly", {
  data <- tibble(id = 1:100)

  # First page

  result <- paginate_offset(data, limit = 10, offset = 0)
  expect_equal(nrow(result$data), 10)
  expect_equal(result$data$id[1], 1)
  expect_equal(result$data$id[10], 10)

  # Second page
  result2 <- paginate_offset(data, limit = 10, offset = 10)
  expect_equal(nrow(result2$data), 10)
  expect_equal(result2$data$id[1], 11)
  expect_equal(result2$data$id[10], 20)

  # Last partial page
  result3 <- paginate_offset(data, limit = 10, offset = 95)
  expect_equal(nrow(result3$data), 5)
  expect_equal(result3$data$id[1], 96)
})

test_that("paginate_offset links.next is present when more data exists", {
  data <- tibble(id = 1:100)
  result <- paginate_offset(data, limit = 10, offset = 0)

  expect_false(is.null(result$links[["next"]]))
  expect_match(result$links[["next"]], "limit=10")
  expect_match(result$links[["next"]], "offset=10")
})

test_that("paginate_offset links.next is NULL on last page", {
  data <- tibble(id = 1:100)
  result <- paginate_offset(data, limit = 10, offset = 90)

  expect_null(result$links[["next"]])
})

test_that("paginate_offset links.next is NULL when data fits in one page", {
  data <- tibble(id = 1:5)
  result <- paginate_offset(data, limit = 50, offset = 0)

  expect_null(result$links[["next"]])
})

test_that("paginate_offset handles empty data frame", {
  data <- tibble(id = integer(0))
  result <- paginate_offset(data, limit = 10, offset = 0)

  expect_equal(nrow(result$data), 0)
  expect_equal(result$meta$total, 0)
  expect_null(result$links[["next"]])
})

test_that("paginate_offset defaults limit to 50 for invalid values", {
  data <- tibble(id = 1:100)

  result <- paginate_offset(data, limit = -1, offset = 0)
  expect_equal(result$meta$limit, 50)

  result2 <- paginate_offset(data, limit = "abc", offset = 0)
  expect_equal(result2$meta$limit, 50)
})

test_that("paginate_offset caps limit at PAGINATION_MAX_SIZE", {
  data <- tibble(id = 1:1000)
  result <- paginate_offset(data, limit = 9999, offset = 0)

  expect_equal(result$meta$limit, PAGINATION_MAX_SIZE)
  expect_equal(nrow(result$data), PAGINATION_MAX_SIZE)
})

test_that("paginate_offset defaults offset to 0 for invalid values", {
  data <- tibble(id = 1:100)

  result <- paginate_offset(data, limit = 10, offset = -5)
  expect_equal(result$meta$offset, 0)
})

test_that("paginate_offset returns empty data for offset beyond range", {
  data <- tibble(id = 1:10)
  result <- paginate_offset(data, limit = 10, offset = 100)

  expect_equal(nrow(result$data), 0)
  expect_equal(result$meta$total, 10)
})

test_that("paginate_offset includes base_url in links.next when provided", {
  data <- tibble(id = 1:100)
  result <- paginate_offset(data, limit = 10, offset = 0,
                            base_url = "/api/example?sort=id")

  expect_match(result$links[["next"]], "^/api/example\\?sort=id&limit=10&offset=10$")
})


# =============================================================================
# Endpoint signature verification
# =============================================================================
# Parse each target endpoint file and verify that GET handlers accepting list
# data declare `limit` and `offset` parameters.

#' Extract function signatures from a plumber endpoint file
#'
#' Reads the file, finds function declarations preceded by @get annotations,
#' and returns the parameter names for each.
#'
#' @param file_path Relative path from api/ directory
#' @return Named list: route -> character vector of param names
extract_get_handler_params <- function(file_path) {
  api_dir <- get_api_dir()
  full_path <- file.path(api_dir, file_path)
  lines <- readLines(full_path, warn = FALSE)

  handlers <- list()
  i <- 1
  while (i <= length(lines)) {
    line <- trimws(lines[i])

    # Detect @get annotation
    if (grepl("^#\\*\\s*@get\\s+", line)) {
      route <- sub("^#\\*\\s*@get\\s+", "", line)

      # Scan forward for the function() declaration
      j <- i + 1
      while (j <= length(lines) && !grepl("^function\\s*\\(", trimws(lines[j]))) {
        j <- j + 1
      }

      if (j <= length(lines)) {
        # Gather the full function signature (may span multiple lines)
        sig <- ""
        k <- j
        while (k <= length(lines) && !grepl("\\{", lines[k])) {
          sig <- paste0(sig, lines[k])
          k <- k + 1
        }
        sig <- paste0(sig, lines[min(k, length(lines))])

        # Extract parameter names from function(param1, param2 = default, ...)
        params_str <- sub(".*function\\s*\\(", "", sig)
        params_str <- sub("\\)\\s*\\{.*", "", params_str)
        params <- trimws(strsplit(params_str, ",")[[1]])
        param_names <- sub("\\s*=.*", "", params)
        param_names <- sub("^`", "", param_names)
        param_names <- sub("`$", "", param_names)
        param_names <- param_names[param_names != "" & param_names != "..."]

        handlers[[route]] <- param_names
      }
      i <- j + 1
    } else {
      i <- i + 1
    }
  }
  handlers
}


# --- backup_endpoints.R: GET /list ---
test_that("backup GET /list accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/backup_endpoints.R")
  expect_true("/list" %in% names(handlers),
              info = "GET /list handler not found in backup_endpoints.R")
  params <- handlers[["/list"]]
  expect_true("limit" %in% params, info = "limit param missing from GET /list")
  expect_true("offset" %in% params, info = "offset param missing from GET /list")
})

# --- llm_admin_endpoints.R: GET /cache/summaries, GET /logs ---
test_that("llm_admin GET /cache/summaries accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/llm_admin_endpoints.R")
  expect_true("/cache/summaries" %in% names(handlers),
              info = "GET /cache/summaries handler not found")
  params <- handlers[["/cache/summaries"]]
  expect_true("limit" %in% params, info = "limit param missing from GET /cache/summaries")
  expect_true("offset" %in% params, info = "offset param missing from GET /cache/summaries")
})

test_that("llm_admin GET /logs accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/llm_admin_endpoints.R")
  expect_true("/logs" %in% names(handlers),
              info = "GET /logs handler not found")
  params <- handlers[["/logs"]]
  expect_true("limit" %in% params, info = "limit param missing from GET /logs")
  expect_true("offset" %in% params, info = "offset param missing from GET /logs")
})

# --- re_review_endpoints.R: GET assignment_table ---
test_that("re_review GET assignment_table accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/re_review_endpoints.R")
  expect_true("assignment_table" %in% names(handlers),
              info = "GET assignment_table handler not found")
  params <- handlers[["assignment_table"]]
  expect_true("limit" %in% params, info = "limit param missing from GET assignment_table")
  expect_true("offset" %in% params, info = "offset param missing from GET assignment_table")
})

# --- search_endpoints.R: 4 search GET endpoints ---
test_that("search GET <searchterm> accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/search_endpoints.R")
  expect_true("<searchterm>" %in% names(handlers),
              info = "GET <searchterm> handler not found")
  params <- handlers[["<searchterm>"]]
  expect_true("limit" %in% params, info = "limit param missing from GET <searchterm>")
  expect_true("offset" %in% params, info = "offset param missing from GET <searchterm>")
})

test_that("search GET ontology/<searchterm> accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/search_endpoints.R")
  expect_true("ontology/<searchterm>" %in% names(handlers),
              info = "GET ontology/<searchterm> handler not found")
  params <- handlers[["ontology/<searchterm>"]]
  expect_true("limit" %in% params)
  expect_true("offset" %in% params)
})

test_that("search GET gene/<searchterm> accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/search_endpoints.R")
  expect_true("gene/<searchterm>" %in% names(handlers),
              info = "GET gene/<searchterm> handler not found")
  params <- handlers[["gene/<searchterm>"]]
  expect_true("limit" %in% params)
  expect_true("offset" %in% params)
})

test_that("search GET inheritance/<searchterm> accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/search_endpoints.R")
  expect_true("inheritance/<searchterm>" %in% names(handlers),
              info = "GET inheritance/<searchterm> handler not found")
  params <- handlers[["inheritance/<searchterm>"]]
  expect_true("limit" %in% params)
  expect_true("offset" %in% params)
})

# --- variant_endpoints.R: GET correlation, GET count ---
test_that("variant GET correlation accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/variant_endpoints.R")
  expect_true("correlation" %in% names(handlers),
              info = "GET correlation handler not found")
  params <- handlers[["correlation"]]
  expect_true("limit" %in% params, info = "limit param missing from GET correlation")
  expect_true("offset" %in% params, info = "offset param missing from GET correlation")
})

test_that("variant GET count accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/variant_endpoints.R")
  expect_true("count" %in% names(handlers),
              info = "GET count handler not found")
  params <- handlers[["count"]]
  expect_true("limit" %in% params, info = "limit param missing from GET count")
  expect_true("offset" %in% params, info = "offset param missing from GET count")
})

# --- panels_endpoints.R: GET options ---
test_that("panels GET options accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/panels_endpoints.R")
  expect_true("options" %in% names(handlers),
              info = "GET options handler not found")
  params <- handlers[["options"]]
  expect_true("limit" %in% params, info = "limit param missing from GET options")
  expect_true("offset" %in% params, info = "offset param missing from GET options")
})

# --- comparisons_endpoints.R: GET options, GET upset, GET similarity ---
test_that("comparisons GET options accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/comparisons_endpoints.R")
  expect_true("options" %in% names(handlers),
              info = "GET options handler not found in comparisons")
  params <- handlers[["options"]]
  expect_true("limit" %in% params, info = "limit param missing from comparisons GET options")
  expect_true("offset" %in% params, info = "offset param missing from comparisons GET options")
})

test_that("comparisons GET upset accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/comparisons_endpoints.R")
  expect_true("upset" %in% names(handlers),
              info = "GET upset handler not found")
  params <- handlers[["upset"]]
  expect_true("limit" %in% params)
  expect_true("offset" %in% params)
})

test_that("comparisons GET similarity accepts limit and offset", {
  handlers <- extract_get_handler_params("endpoints/comparisons_endpoints.R")
  expect_true("similarity" %in% names(handlers),
              info = "GET similarity handler not found")
  params <- handlers[["similarity"]]
  expect_true("limit" %in% params)
  expect_true("offset" %in% params)
})
