source_api_file("functions/user-endpoint-helpers.R", local = FALSE)

test_that("password_meets_complexity enforces length and character classes", {
  expect_true(password_meets_complexity("Abcdef1!"))   # 8 chars, all classes
  expect_false(password_meets_complexity("Abc1!"))      # too short
  expect_false(password_meets_complexity("abcdef1!"))   # no uppercase
  expect_false(password_meets_complexity("ABCDEF1!"))   # no lowercase
  expect_false(password_meets_complexity("Abcdefg!"))   # no digit
  expect_false(password_meets_complexity("Abcdefg1"))   # no special character
})

test_that("new_password_valid requires the confirmation to match", {
  expect_true(new_password_valid("Abcdef1!", "Abcdef1!"))
  expect_false(new_password_valid("Abcdef1!", "Different1!"))
})

test_that("new_password_valid (change flow) rejects reuse of the old password", {
  expect_false(
    new_password_valid("Abcdef1!", "Abcdef1!", old_pass = "Abcdef1!")
  )
  expect_true(
    new_password_valid("Abcdef1!", "Abcdef1!", old_pass = "OldPass1!")
  )
})

test_that("new_password_valid (reset flow) ignores the old password", {
  # old_pass = NULL means the reuse check is skipped (no current password)
  expect_true(new_password_valid("Abcdef1!", "Abcdef1!"))
  expect_false(new_password_valid("weak", "weak"))
})
