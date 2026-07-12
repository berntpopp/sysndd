# Focused profile and password-reset-change service coverage.

test_that("svc_user_profile_update requires authentication", {
  env <- make_service_sandbox()
  load_service_into("services/user-password-profile-endpoint-service.R", env)
  res <- make_mock_res()
  env$svc_user_profile_update(list(postBody = "{}"), res)
  expect_equal(res$status, 401L)
})

test_that("svc_user_profile_update validates unique email and ORCID fields", {
  invalid_email <- make_service_sandbox(overrides = list(is_valid_email = function(x) FALSE))
  load_service_into("services/user-password-profile-endpoint-service.R", invalid_email)
  res <- make_mock_res()
  result <- invalid_email$svc_user_profile_update(
    list(user_id = 1, postBody = '{"email":"not-an-email"}'), res
  )
  expect_equal(res$status, 400L)
  expect_match(result$error, "Invalid email")

  existing <- tibble::tibble(user_id = 2, email = "taken@example.com")
  duplicate <- make_service_sandbox(
    tables = list(user = existing),
    overrides = list(is_valid_email = function(x) TRUE)
  )
  load_service_into("services/user-password-profile-endpoint-service.R", duplicate)
  res <- make_mock_res()
  result <- duplicate$svc_user_profile_update(
    list(user_id = 1, postBody = '{"email":"taken@example.com"}'), res
  )
  expect_equal(res$status, 400L)
  expect_match(result$error, "already in use")

  invalid_orcid <- make_service_sandbox()
  load_service_into("services/user-password-profile-endpoint-service.R", invalid_orcid)
  res <- make_mock_res()
  result <- invalid_orcid$svc_user_profile_update(
    list(user_id = 1, postBody = '{"orcid":"not-an-orcid"}'), res
  )
  expect_equal(res$status, 400L)
  expect_match(result$error, "Invalid ORCID")
})

test_that("svc_user_profile_update persists normalized fields and rejects empty updates", {
  updated <- NULL
  env <- make_service_sandbox(overrides = list(
    user_update = function(user_id, updates) updated <<- list(user_id = user_id, updates = updates)
  ))
  load_service_into("services/user-password-profile-endpoint-service.R", env)
  res <- make_mock_res()
  result <- env$svc_user_profile_update(
    list(user_id = 1, postBody = '{"orcid":"0000-0001-2345-678x"}'), res
  )
  expect_equal(res$status, 200L)
  expect_equal(updated$updates$orcid, "0000-0001-2345-678X")
  expect_true("orcid" %in% result$updated_fields)

  empty_res <- make_mock_res()
  env$svc_user_profile_update(list(user_id = 1, postBody = "{}"), empty_res)
  expect_equal(empty_res$status, 400L)
})

test_that("svc_user_password_reset_change rejects expired or missing users", {
  expired <- make_service_sandbox(overrides = list(
    jwt_decode_hmac = function(jwt, secret) list(
      user_id = 1, user_name = "alice", email = "a@x.com", hash = "h",
      iat = as.integer(Sys.time()) - 3600, exp = as.integer(Sys.time()) - 1
    ),
    dw = list(secret = "sekrit")
  ))
  load_service_into("services/user-password-profile-endpoint-service.R", expired)
  res <- make_mock_res()
  result <- expired$svc_user_password_reset_change(
    list(postBody = "{}", HTTP_AUTHORIZATION = "Bearer faketoken"), res
  )
  expect_equal(res$status, 401L)
  expect_match(result$error, "expired")

  missing <- make_service_sandbox(
    tables = list(user = tibble::tibble(
      user_id = integer(0), user_name = character(0), password = character(0),
      email = character(0), password_reset_date = character(0)
    )),
    overrides = list(
      jwt_decode_hmac = function(jwt, secret) list(
        user_id = 999, user_name = "ghost", email = "g@x.com", hash = "h",
        iat = as.integer(Sys.time()), exp = as.integer(Sys.time()) + 900
      ),
      dw = list(secret = "sekrit", salt = "salty")
    )
  )
  load_service_into("services/user-password-profile-endpoint-service.R", missing)
  res <- make_mock_res()
  missing$svc_user_password_reset_change(
    list(postBody = "{}", HTTP_AUTHORIZATION = "Bearer faketoken"), res
  )
  expect_equal(res$status, 404L)
})

test_that("svc_user_password_reset_change rejects a hash mismatch", {
  now_ts <- Sys.time()
  env <- make_service_sandbox(
    tables = list(user = tibble::tibble(
      user_id = 1, user_name = "alice", password = "currentpw",
      email = "a@x.com", password_reset_date = format(now_ts, "%Y-%m-%d %H:%M:%S")
    )),
    overrides = list(
      jwt_decode_hmac = function(jwt, secret) list(
        user_id = 1, user_name = "alice", email = "a@x.com", hash = "WRONG-HASH",
        iat = as.integer(now_ts), exp = as.integer(now_ts) + 900
      ),
      dw = list(secret = "sekrit", salt = "salty"),
      new_password_valid = function(...) TRUE
    )
  )
  load_service_into("services/user-password-profile-endpoint-service.R", env)
  res <- make_mock_res()
  result <- env$svc_user_password_reset_change(list(
    postBody = '{"password":"NewPass1!","password_confirm":"NewPass1!"}',
    HTTP_AUTHORIZATION = "Bearer faketoken"
  ), res)
  expect_equal(res$status, 409L)
  expect_match(result$error, "Password or JWT input problem")
})

test_that("svc_user_password_reset_change succeeds for valid claims and password", {
  reset_date_str <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  expected_iat <- as.integer(as.POSIXct(reset_date_str, tz = "UTC"))
  real_hash <- toString(openssl::md5(paste0("salty", "currentpw")))
  cleared_params <- NULL
  env <- make_service_sandbox(
    tables = list(user = tibble::tibble(
      user_id = 1, user_name = "alice", password = "currentpw",
      email = "a@x.com", password_reset_date = reset_date_str
    )),
    overrides = list(
      jwt_decode_hmac = function(jwt, secret) list(
        user_id = 1, user_name = "alice", email = "a@x.com", hash = real_hash,
        iat = expected_iat, exp = as.integer(Sys.time()) + 900
      ),
      dw = list(secret = "sekrit", salt = "salty"),
      new_password_valid = function(...) TRUE,
      hash_password = function(pw) paste0("hashed:", pw),
      user_update_password = function(...) invisible(TRUE),
      db_execute_statement = function(sql, params) {
        cleared_params <<- params
        1L
      }
    )
  )
  load_service_into("services/user-password-profile-endpoint-service.R", env)
  res <- make_mock_res()
  result <- env$svc_user_password_reset_change(list(
    postBody = '{"password":"NewPass1!","password_confirm":"NewPass1!"}',
    HTTP_AUTHORIZATION = "Bearer faketoken"
  ), res)
  expect_equal(res$status, 201L)
  expect_equal(result$message, "Password successfully changed.")
  expect_equal(cleared_params[[1]], 1)
})
