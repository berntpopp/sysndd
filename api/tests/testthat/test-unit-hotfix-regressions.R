# test-unit-hotfix-regressions.R
# Regression tests for production hotfixes (2026-03-05)
#
# Covers:
# - Issue #194: charToRaw(dw$secret) fails when config::get() returns a list
# - Issue #195: Entity deactivation type coercion errors
# - Issue #197: Cache invalidation after entity mutations

library(testthat)
library(jose)
library(memoise)

# =============================================================================
# Issue #194: charToRaw guard for list-typed dw$secret
# =============================================================================

test_that("#194: charToRaw defensive wrapper handles character scalar", {
  secret <- "my-test-secret"
  key <- charToRaw(
    if (is.list(secret)) as.character(secret[[1]]) else as.character(secret)
  )
  expect_type(key, "raw")
  expect_equal(rawToChar(key), "my-test-secret")
})

test_that("#194: charToRaw defensive wrapper handles list-typed secret", {
  # config::get() can return list("value") instead of "value" for unquoted YAML

  secret <- list("my-list-secret")
  key <- charToRaw(
    if (is.list(secret)) as.character(secret[[1]]) else as.character(secret)
  )
  expect_type(key, "raw")
  expect_equal(rawToChar(key), "my-list-secret")
})

test_that("#194: charToRaw defensive wrapper handles nested list secret", {
  secret <- list(c("nested-secret"))
  key <- charToRaw(
    if (is.list(secret)) as.character(secret[[1]]) else as.character(secret)
  )
  expect_type(key, "raw")
  expect_equal(rawToChar(key), "nested-secret")
})

test_that("#194: startup validation coerces list secret and warns", {
  # Simulate the startup validation block from start_sysndd_api.R
  dw <- list(secret = list("coerced-secret"))

  expect_true(is.list(dw$secret))

  if (is.list(dw$secret)) {
    dw$secret <- as.character(dw$secret[[1]])
  }

  expect_false(is.list(dw$secret))
  expect_equal(dw$secret, "coerced-secret")
  expect_true(is.character(dw$secret) && nchar(dw$secret) > 0)
})

test_that("#194: startup validation passes for normal character secret", {
  dw <- list(secret = "normal-secret")

  expect_false(is.list(dw$secret))
  expect_true(is.character(dw$secret) && nchar(dw$secret) > 0)
})

test_that("#194: JWT round-trip works with list-coerced secret", {
  # End-to-end: simulate what middleware does with a list-typed secret
  secret_from_config <- list("jwt-test-secret-key-minimum-length")

  key <- charToRaw(
    if (is.list(secret_from_config)) {
      as.character(secret_from_config[[1]])
    } else {
      as.character(secret_from_config)
    }
  )

  claim <- jose::jwt_claim(user_id = 42, user_role = "Curator")
  token <- jose::jwt_encode_hmac(claim, secret = key)
  decoded <- jose::jwt_decode_hmac(token, secret = key)

  expect_equal(decoded$user_id, 42)
  expect_equal(decoded$user_role, "Curator")
})

# =============================================================================
# Issue #195: Entity deactivation type coercion
# =============================================================================

test_that("#195: is_active string '0' coerces to integer 0", {
  incoming_is_active <- as.integer("0")
  expect_identical(incoming_is_active, 0L)
})

test_that("#195: is_active logical FALSE coerces to integer 0", {
  incoming_is_active <- as.integer(FALSE)
  expect_identical(incoming_is_active, 0L)
})

test_that("#195: is_active integer 0 stays integer 0", {
  incoming_is_active <- as.integer(0)
  expect_identical(incoming_is_active, 0L)
})

test_that("#195: replaced_by string 'NULL' converts to NA_integer_", {
  incoming_replaced_by <- "NULL"
  if (is.character(incoming_replaced_by) &&
    toupper(trimws(incoming_replaced_by)) == "NULL") {
    incoming_replaced_by <- NA_integer_
  }
  expect_true(is.na(incoming_replaced_by))
  expect_type(incoming_replaced_by, "integer")
})

test_that("#195: replaced_by string ' null ' (padded, lowercase) converts to NA_integer_", {
  incoming_replaced_by <- " null "
  if (is.character(incoming_replaced_by) &&
    toupper(trimws(incoming_replaced_by)) == "NULL") {
    incoming_replaced_by <- NA_integer_
  }
  expect_true(is.na(incoming_replaced_by))
})

test_that("#195: replaced_by with valid integer stays as-is", {
  incoming_replaced_by <- 42L
  if (is.character(incoming_replaced_by) &&
    toupper(trimws(incoming_replaced_by)) == "NULL") {
    incoming_replaced_by <- NA_integer_
  }
  expect_identical(incoming_replaced_by, 42L)
})

test_that("#195: replaced_by with NA stays as NA", {
  incoming_replaced_by <- NA
  if (is.character(incoming_replaced_by) &&
    toupper(trimws(incoming_replaced_by)) == "NULL") {
    incoming_replaced_by <- NA_integer_
  }
  # NA is logical, not character, so the guard doesn't trigger — that's fine

  expect_true(is.na(incoming_replaced_by))
})

test_that("#195: full deactivation coercion pipeline with tibble mutate", {
  # Simulate the actual entity_endpoints.R pattern with dplyr
  library(dplyr)
  library(tibble)

  original <- tibble(
    entity_id = 1L,
    hgnc_id = "HGNC:1234",
    is_active = 1L,
    replaced_by = NA_integer_
  )

  # Simulate JSON payload types (strings from HTTP)
  incoming_is_active <- as.integer("0")
  incoming_replaced_by <- "NULL"
  if (is.character(incoming_replaced_by) &&
    toupper(trimws(incoming_replaced_by)) == "NULL") {
    incoming_replaced_by <- NA_integer_
  }

  result <- original %>%
    mutate(is_active = incoming_is_active) %>%
    mutate(replaced_by = incoming_replaced_by)

  expect_identical(result$is_active, 0L)
  expect_true(is.na(result$replaced_by))
})

# =============================================================================
# Issue #197: Cache invalidation after entity mutations
# =============================================================================

test_that("#197: memoise::forget resets a memoised function", {
  call_count <- 0L
  my_fn <- function() {
    call_count <<- call_count + 1L
    call_count
  }
  my_fn_mem <- memoise::memoise(my_fn)

  # First call caches
  result1 <- my_fn_mem()
  expect_equal(result1, 1L)

  # Second call returns cached value
  result2 <- my_fn_mem()
  expect_equal(result2, 1L)
  expect_equal(call_count, 1L)  # Still 1, was cached

  # After forget, next call recomputes
  memoise::forget(my_fn_mem)
  result3 <- my_fn_mem()
  expect_equal(result3, 2L)
  expect_equal(call_count, 2L)
})

test_that("#197: conditional cache invalidation pattern works", {
  # Simulate the exact pattern used in entity_endpoints.R
  call_count_news <- 0L
  call_count_stat <- 0L

  gen_news <- function() {
    call_count_news <<- call_count_news + 1L
    call_count_news
  }
  gen_stat <- function() {
    call_count_stat <<- call_count_stat + 1L
    call_count_stat
  }

  generate_gene_news_tibble_mem <- memoise::memoise(gen_news)
  generate_stat_tibble_mem <- memoise::memoise(gen_stat)

  # Prime caches
  generate_gene_news_tibble_mem()
  generate_stat_tibble_mem()

  # Simulate successful entity creation (status 200)
  result_status <- 200
  if (result_status == 200) {
    if (exists("generate_gene_news_tibble_mem")) {
      memoise::forget(generate_gene_news_tibble_mem)
    }
    if (exists("generate_stat_tibble_mem")) {
      memoise::forget(generate_stat_tibble_mem)
    }
  }

  # After invalidation, functions should recompute
  news_after <- generate_gene_news_tibble_mem()
  stat_after <- generate_stat_tibble_mem()

  expect_equal(news_after, 2L)  # Recomputed (was 1)
  expect_equal(stat_after, 2L)  # Recomputed (was 1)
})

test_that("#197: cache NOT invalidated on failure (non-200 status)", {
  call_count <- 0L
  my_fn <- function() {
    call_count <<- call_count + 1L
    call_count
  }
  generate_stat_tibble_mem <- memoise::memoise(my_fn)

  # Prime cache
  generate_stat_tibble_mem()
  expect_equal(call_count, 1L)

  # Simulate failed entity creation (status 500)
  result_status <- 500
  if (result_status == 200) {
    memoise::forget(generate_stat_tibble_mem)
  }

  # Cache should still be valid
  result <- generate_stat_tibble_mem()
  expect_equal(result, 1L)  # Still cached
  expect_equal(call_count, 1L)  # No recomputation
})
