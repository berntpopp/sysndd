# tests/testthat/test-unit-external-proxy-request-bound.R
# Pure test (no DB / no network) — runs on host.
# #344: a multi-call fetcher must be able to see, BEFORE a subsequent upstream
# call, that this request has already spent (or, counting the just-elapsed but
# not-yet-accumulated time, is about to spend) its external-time ceiling.

test_that("external_proxy_request_would_exceed accounts for pending, not-yet-added time", {
  source(file.path(get_api_dir(), "functions", "external-proxy-request-state.R"), local = TRUE)
  withr::with_envvar(c(EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "15"), {
    external_proxy_request_reset()
    expect_false(external_proxy_request_would_exceed(0))
    expect_false(external_proxy_request_would_exceed(14000)) # 14s < 15s ceiling

    # Simulate 10s already accumulated from a prior fetcher this request.
    external_proxy_request_add(10000)
    expect_false(external_proxy_request_would_exceed(0))     # 10s < 15s
    expect_true(external_proxy_request_would_exceed(6000))   # 10s + 6s pending >= 15s
    external_proxy_request_reset()
  })
})

test_that("MGI fetcher gates its second upstream call on the request ceiling", {
  path <- file.path(get_api_dir(), "functions", "external-proxy-mgi.R")
  src <- readLines(path, warn = FALSE)
  src <- src[!grepl("^\\s*#", src)]
  expect_true(
    any(grepl("external_proxy_request_would_exceed", src)),
    info = "external-proxy-mgi.R must gate its zygosity call on the per-request ceiling (#344)"
  )
})
