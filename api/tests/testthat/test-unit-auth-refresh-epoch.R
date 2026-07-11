# tests/testthat/test-unit-auth-refresh-epoch.R
#
# #535 P0-2: auth_refresh() is DB-backed, role-current, and epoch-revocable.
# These integration tests drive the real auth_refresh against the rolled-back
# test transaction by passing the transaction connection as the `pool` argument
# (auth_refresh already takes `pool`). Fixtures use parameterized SQL against the
# real `user` schema (user_create() is broken).

library(testthat)
library(jose)

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)
source_api_file("functions/user-repository.R", local = FALSE)
source_api_file("services/auth-service.R", local = FALSE)

.cfg <- function() list(secret = get_test_config("secret"), token_expiry = 3600L)

.seed <- function(con, role = "Curator", approved = 1L) {
  suffix <- as.integer(runif(1, 1, 1e8))
  uid <- 900000000L + suffix
  DBI::dbExecute(
    con,
    "INSERT INTO user (user_id, user_name, email, password, user_role, approved, session_epoch)
       VALUES (?, ?, ?, ?, ?, ?, 0)",
    params = list(uid, paste0("ar_", suffix), paste0("ar", suffix, "@test.local"),
                  "x", role, approved)
  )
  uid
}

.epoch_of <- function(con, uid) {
  DBI::dbGetQuery(con, "SELECT session_epoch FROM user WHERE user_id = ?",
                  params = list(uid))$session_epoch[1]
}

.mint <- function(con, uid, cfg) {
  u <- con %>%
    dplyr::tbl("user") %>%
    dplyr::filter(.data$user_id == !!uid) %>%
    dplyr::rename(user_created = created_at) %>%
    dplyr::collect()
  auth_generate_token(u[1, ], cfg)$access_token
}

# Mint a legacy token WITHOUT a sepoch claim (simulates a pre-#535 token).
.mint_legacy <- function(uid, cfg, role = "Curator") {
  claim <- jose::jwt_claim(
    user_id = uid, user_name = "legacy", email = "l@t.local", user_role = role,
    iat = as.numeric(Sys.time()), exp = as.numeric(Sys.time()) + 3600
  )
  jose::jwt_encode_hmac(claim, secret = charToRaw(cfg$secret))
}

test_that("token carries sepoch and a normal refresh succeeds with DB-derived claims", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Curator")
    tok <- .mint(con, uid, cfg)
    expect_equal(as.numeric(auth_validate_token(tok, cfg)$sepoch), 0)
    newtok <- auth_refresh(tok, con, cfg)
    claims <- auth_validate_token(newtok, cfg)
    expect_equal(claims$user_role, "Curator")
    expect_equal(as.numeric(claims$sepoch), as.numeric(.epoch_of(con, uid)))
  })
})

test_that("refresh mints the CURRENT DB role (role-current), isolated from any epoch bump", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Administrator")
    tok <- .mint(con, uid, cfg)                 # token role = Administrator, sepoch = 0
    # raw update: change role WITHOUT bumping epoch, so the token still validates
    DBI::dbExecute(con, "UPDATE user SET user_role = 'Viewer' WHERE user_id = ?",
                   params = list(uid))
    newtok <- auth_refresh(tok, con, cfg)
    expect_equal(auth_validate_token(newtok, cfg)$user_role, "Viewer")  # from DB, not token
  })
})

test_that("refresh is REJECTED after a real demotion (epoch bump via user_update)", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Curator")
    tok <- .mint(con, uid, cfg)
    user_update(uid, list(user_role = "Viewer"), conn = con)  # bumps epoch atomically
    expect_error(auth_refresh(tok, con, cfg), regexp = "revoked|unauthor", ignore.case = TRUE)
  })
})

test_that("refresh is REJECTED for a deactivated user", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Reviewer", approved = 1L)
    tok <- .mint(con, uid, cfg)
    user_update(uid, list(approved = 0), conn = con)
    expect_error(auth_refresh(tok, con, cfg), regexp = "not active|revoked|unauthor",
                 ignore.case = TRUE)
  })
})

test_that("refresh is REJECTED after a password change (epoch bump)", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con); tok <- .mint(con, uid, cfg)
    user_update_password(uid, "newhash", conn = con)
    expect_error(auth_refresh(tok, con, cfg), regexp = "revoked|unauthor", ignore.case = TRUE)
  })
})

test_that("refresh is REJECTED for a deleted user", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con); tok <- .mint(con, uid, cfg)
    DBI::dbExecute(con, "DELETE FROM user WHERE user_id = ?", params = list(uid))
    expect_error(auth_refresh(tok, con, cfg), regexp = "no longer exists|unauthor",
                 ignore.case = TRUE)
  })
})

test_that("refresh is REJECTED for a legacy token with no sepoch claim (no indefinite renewal)", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Curator")
    legacy <- .mint_legacy(uid, cfg)
    expect_null(auth_validate_token(legacy, cfg)$sepoch)  # confirm it has no sepoch
    expect_error(auth_refresh(legacy, con, cfg),
                 regexp = "predates|revocation|unauthor", ignore.case = TRUE)
  })
})

test_that("refresh is REJECTED for a token whose epoch no longer matches (stale)", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Curator")
    tok <- .mint(con, uid, cfg)                         # sepoch = 0
    # bump epoch out from under the token WITHOUT other changes
    DBI::dbExecute(con, "UPDATE user SET session_epoch = session_epoch + 5 WHERE user_id = ?",
                   params = list(uid))
    expect_error(auth_refresh(tok, con, cfg), regexp = "revoked|unauthor", ignore.case = TRUE)
  })
})
