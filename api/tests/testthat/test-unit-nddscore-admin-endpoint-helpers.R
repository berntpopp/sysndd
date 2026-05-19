source_api_file("functions/nddscore-admin-endpoint-helpers.R", local = FALSE)

test_that("NDDScore admin scalar helpers normalize empty values", {
  expect_equal(.nddscore_admin_scalar(NULL, default = "fallback"), "fallback")
  expect_equal(.nddscore_admin_scalar(character(), default = "fallback"), "fallback")
  expect_equal(.nddscore_admin_scalar(NA_character_, default = "fallback"), "fallback")
  expect_equal(.nddscore_admin_scalar("  ", default = "fallback"), "fallback")
  expect_equal(.nddscore_admin_scalar(c("value", "ignored"), default = "fallback"), "value")
})

test_that("NDDScore admin bool helper accepts common serialized forms", {
  expect_true(.nddscore_admin_bool(TRUE))
  expect_true(.nddscore_admin_bool(1))
  expect_true(.nddscore_admin_bool("yes"))
  expect_false(.nddscore_admin_bool(FALSE, default = TRUE))
  expect_false(.nddscore_admin_bool(0, default = TRUE))
  expect_false(.nddscore_admin_bool("no", default = TRUE))
  expect_true(.nddscore_admin_bool("unknown", default = TRUE))
})

test_that("NDDScore admin request body falls back to parsed postBody", {
  req <- list(postBody = '{"is_active":true,"label":"release"}')

  body <- .nddscore_admin_request_body(req)

  expect_true(body$is_active)
  expect_equal(body$label, "release")
})

test_that("NDDScore admin row and URL helpers keep endpoint shape", {
  expect_false(.nddscore_admin_has_rows(data.frame()))
  expect_true(.nddscore_admin_has_rows(data.frame(id = 1L)))
  expect_equal(.nddscore_admin_tibble_rows(data.frame(id = 1:2))[[2]]$id, 2L)
  expect_equal(.nddscore_admin_job_status_url(42L), "/api/jobs/42/status")
})
