# tests/testthat/test-unit-role-admin-target-guard.R
#
# Guard (#5): role-mutation paths blocked ASSIGNING the Administrator role but
# never checked the TARGET's current role, so a Curator could demote any
# Administrator to Viewer. assert_not_targeting_admin() is the shield (mirrors
# the user_bulk_delete admin protection) and every role-mutation path uses it.
#
# Pure (helper needs no DB) — runs on host.

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)
if (!requireNamespace("logger", quietly = TRUE)) {
  stop("logger package not available — cannot run user-service tests")
}
source_api_file("services/user-service.R", local = FALSE)

test_that("assert_not_targeting_admin blocks a non-admin caller on admin targets", {
  skip_if_not(exists("assert_not_targeting_admin"))
  # Curator targeting an Administrator -> 403.
  expect_error(assert_not_targeting_admin("Curator", c("Administrator")))
  expect_error(assert_not_targeting_admin("Reviewer", c("Viewer", "Administrator")))
  # Curator targeting non-admins -> allowed.
  expect_true(assert_not_targeting_admin("Curator", c("Viewer", "Reviewer")))
  # A non-existent target (empty role set) does not falsely trip the guard.
  expect_true(assert_not_targeting_admin("Curator", character(0)))
  # An Administrator may do anything.
  expect_true(assert_not_targeting_admin("Administrator", c("Administrator")))
})

test_that("all three role-mutation paths use the admin-target guard", {
  us <- paste(readLines(file.path(get_api_dir(), "services", "user-service.R"),
                        warn = FALSE), collapse = "\n")
  ue <- paste(readLines(file.path(get_api_dir(), "endpoints", "user_endpoints.R"),
                        warn = FALSE), collapse = "\n")
  # user-service.R: helper definition + calls in user_update_role and
  # user_bulk_assign_role => >= 3 references.
  expect_gte(length(gregexpr("assert_not_targeting_admin", us)[[1]]), 3)
  # Every account-mutating endpoint that a Curator can reach guards admin
  # targets: change_role, /user/approval, and bulk_approve (Codex PR-2 LOW-2).
  expect_gte(length(gregexpr("assert_not_targeting_admin", ue)[[1]]), 3)
})
