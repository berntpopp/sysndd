# tests/testthat/test-unit-user-session-epoch.R
#
# #535 P0-2: every privilege/state mutation must atomically increment
# `user.session_epoch` so an outstanding refresh token is revoked. These tests
# drive the real repository writers on the rolled-back test transaction by
# passing `conn = con` (user_update / user_update_password gained an optional
# `conn` for exactly this — they otherwise use the global app pool).
#
# Fixtures use parameterized SQL against the real `email` column; user_create()
# is intentionally NOT used (it inserts a nonexistent `user_email` column).

library(testthat)

# Source the repository writers under test + their dependencies.
source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)  # validate_query_column
source_api_file("functions/user-repository.R", local = FALSE)

.seed_user_epoch <- function(con, role = "Viewer", approved = 0L) {
  # Explicit high user_id (rolled back after each test) — the test `user` table
  # has no AUTO_INCREMENT and is referenced by FKs, so we pick an id well above
  # any real row instead of relying on LAST_INSERT_ID().
  suffix <- as.integer(runif(1, 1, 1e8))
  uid <- 900000000L + suffix
  DBI::dbExecute(
    con,
    "INSERT INTO user (user_id, user_name, email, password, user_role, approved, session_epoch)
       VALUES (?, ?, ?, ?, ?, ?, 0)",
    params = list(uid, paste0("epoch_", suffix), paste0("epoch", suffix, "@test.local"),
                  "x", role, approved)
  )
  uid
}

.epoch_of <- function(con, uid) {
  DBI::dbGetQuery(con, "SELECT session_epoch FROM user WHERE user_id = ?",
                  params = list(uid))$session_epoch[1]
}

test_that("user_update on user_role bumps session_epoch atomically", {
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    uid <- .seed_user_epoch(con, role = "Reviewer")
    before <- .epoch_of(con, uid)
    user_update(uid, list(user_role = "Viewer"), conn = con)
    expect_equal(.epoch_of(con, uid) - before, 1)
  })
})

test_that("user_update on approved bumps session_epoch", {
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    uid <- .seed_user_epoch(con, approved = 1L)
    before <- .epoch_of(con, uid)
    user_update(uid, list(approved = 0), conn = con)
    expect_equal(.epoch_of(con, uid) - before, 1)
  })
})

test_that("user_update on a non-privilege field does NOT bump session_epoch", {
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    uid <- .seed_user_epoch(con)
    before <- .epoch_of(con, uid)
    user_update(uid, list(abbreviation = "EN"), conn = con)
    expect_equal(.epoch_of(con, uid), before)
  })
})

test_that("user_update_password bumps session_epoch", {
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    uid <- .seed_user_epoch(con)
    before <- .epoch_of(con, uid)
    user_update_password(uid, "newhash", conn = con)
    expect_equal(.epoch_of(con, uid) - before, 1)
  })
})
