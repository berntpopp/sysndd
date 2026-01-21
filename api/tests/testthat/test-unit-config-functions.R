# test-unit-config-functions.R
# Unit tests for api/functions/config-functions.R
#
# These tests cover the update_api_spec_examples() function which updates
# OpenAPI spec examples from a JSON file. This is a pure function that
# manipulates list structures without external dependencies.

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/config-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Source functions being tested
source(file.path(api_dir, "functions/config-functions.R"))

# ============================================================================
# update_api_spec_examples() Tests
# ============================================================================

test_that("update_api_spec_examples returns unchanged spec for empty inputs", {
  # Empty spec
  empty_spec <- list()
  empty_json <- list()

  result <- update_api_spec_examples(empty_spec, empty_json)

  expect_equal(result, empty_spec)
  expect_equal(length(result), 0)
})

test_that("update_api_spec_examples returns unchanged spec when api_spec_json is empty", {
  spec <- list(
    paths = list(
      "/api/test" = list(
        post = list(
          summary = "Test endpoint"
        )
      )
    )
  )
  empty_json <- list()

  result <- update_api_spec_examples(spec, empty_json)

  expect_equal(result, spec)
})

test_that("update_api_spec_examples skips non-matching paths", {
  spec <- list(
    paths = list(
      "/api/existing" = list(
        get = list(summary = "Get endpoint")
      )
    )
  )

  api_spec_json <- list(
    "/api/nonexistent" = list(
      post = list(
        requestBody = list(
          content = list(
            "application/json" = list(
              schema = list(
                properties = list(
                  create_json = list(
                    example = '{"key": "value"}'
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  result <- update_api_spec_examples(spec, api_spec_json)

  # Spec should remain unchanged - path doesn't exist
  expect_equal(result, spec)
})

test_that("update_api_spec_examples skips non-matching methods", {
  spec <- list(
    paths = list(
      "/api/test" = list(
        get = list(summary = "Get endpoint")
      )
    )
  )

  api_spec_json <- list(
    "/api/test" = list(
      post = list(  # Different method
        requestBody = list(
          content = list(
            "application/json" = list(
              schema = list(
                properties = list(
                  create_json = list(
                    example = '{"key": "value"}'
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  result <- update_api_spec_examples(spec, api_spec_json)

  # Spec should remain unchanged - method doesn't match
  expect_equal(result, spec)
})

test_that("update_api_spec_examples updates matching path/method examples", {
  # Set up spec with existing structure but no example
  spec <- list(
    paths = list(
      "/api/entity" = list(
        post = list(
          summary = "Create entity",
          requestBody = list(
            content = list(
              "application/json" = list(
                schema = list(
                  properties = list(
                    create_json = list(
                      example = NULL
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  # JSON with new example
  api_spec_json <- list(
    "/api/entity" = list(
      post = list(
        requestBody = list(
          content = list(
            "application/json" = list(
              schema = list(
                properties = list(
                  create_json = list(
                    example = '{"entity_id": "ENT001", "name": "Test"}'
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  result <- update_api_spec_examples(spec, api_spec_json)

  # Example should be updated
  expected_example <- '{"entity_id": "ENT001", "name": "Test"}'
  actual_example <- result$paths$`/api/entity`$post$requestBody$content$`application/json`$schema$properties$create_json$example

  expect_equal(actual_example, expected_example)
})

test_that("update_api_spec_examples preserves other spec properties", {
  spec <- list(
    info = list(title = "SysNDD API", version = "1.0"),
    servers = list(list(url = "http://localhost:7778")),
    paths = list(
      "/api/test" = list(
        post = list(
          summary = "Test endpoint",
          description = "A test endpoint",
          requestBody = list(
            content = list(
              "application/json" = list(
                schema = list(
                  properties = list(
                    create_json = list(
                      example = "old_example",
                      type = "string"
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  api_spec_json <- list(
    "/api/test" = list(
      post = list(
        requestBody = list(
          content = list(
            "application/json" = list(
              schema = list(
                properties = list(
                  create_json = list(
                    example = "new_example"
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  result <- update_api_spec_examples(spec, api_spec_json)

  # Info and servers should be preserved
  expect_equal(result$info$title, "SysNDD API")
  expect_equal(result$info$version, "1.0")
  expect_equal(result$servers[[1]]$url, "http://localhost:7778")

  # Other path properties preserved
  expect_equal(result$paths$`/api/test`$post$summary, "Test endpoint")
  expect_equal(result$paths$`/api/test`$post$description, "A test endpoint")

  # Example updated
  expect_equal(
    result$paths$`/api/test`$post$requestBody$content$`application/json`$schema$properties$create_json$example,
    "new_example"
  )
})

test_that("update_api_spec_examples handles multiple paths and methods", {
  spec <- list(
    paths = list(
      "/api/entity" = list(
        post = list(
          requestBody = list(
            content = list(
              "application/json" = list(
                schema = list(
                  properties = list(
                    create_json = list(example = "old1")
                  )
                )
              )
            )
          )
        )
      ),
      "/api/gene" = list(
        post = list(
          requestBody = list(
            content = list(
              "application/json" = list(
                schema = list(
                  properties = list(
                    create_json = list(example = "old2")
                  )
                )
              )
            )
          )
        ),
        put = list(
          requestBody = list(
            content = list(
              "application/json" = list(
                schema = list(
                  properties = list(
                    create_json = list(example = "old3")
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  api_spec_json <- list(
    "/api/entity" = list(
      post = list(
        requestBody = list(
          content = list(
            "application/json" = list(
              schema = list(
                properties = list(
                  create_json = list(example = "new1")
                )
              )
            )
          )
        )
      )
    ),
    "/api/gene" = list(
      put = list(
        requestBody = list(
          content = list(
            "application/json" = list(
              schema = list(
                properties = list(
                  create_json = list(example = "new3")
                )
              )
            )
          )
        )
      )
    )
  )

  result <- update_api_spec_examples(spec, api_spec_json)

  # /api/entity POST should be updated
  expect_equal(
    result$paths$`/api/entity`$post$requestBody$content$`application/json`$schema$properties$create_json$example,
    "new1"
  )

  # /api/gene POST should be unchanged (not in json)
  expect_equal(
    result$paths$`/api/gene`$post$requestBody$content$`application/json`$schema$properties$create_json$example,
    "old2"
  )

  # /api/gene PUT should be updated
  expect_equal(
    result$paths$`/api/gene`$put$requestBody$content$`application/json`$schema$properties$create_json$example,
    "new3"
  )
})

test_that("update_api_spec_examples skips when example not in json", {
  spec <- list(
    paths = list(
      "/api/test" = list(
        post = list(
          requestBody = list(
            content = list(
              "application/json" = list(
                schema = list(
                  properties = list(
                    create_json = list(
                      example = "original"
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  # JSON has the path/method but no example property
  api_spec_json <- list(
    "/api/test" = list(
      post = list(
        requestBody = list(
          content = list(
            "application/json" = list(
              schema = list(
                properties = list(
                  create_json = list(
                    type = "string"
                    # No example property
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  result <- update_api_spec_examples(spec, api_spec_json)

  # Example should remain unchanged
  expect_equal(
    result$paths$`/api/test`$post$requestBody$content$`application/json`$schema$properties$create_json$example,
    "original"
  )
})
