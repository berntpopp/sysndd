# tests/testthat/test-unit-api-lane.R
# Pure test (no DB / no network) — runs on host.
# Guards the #344 enrichment-lane identity helper used to (a) gate startup
# bootstraps off the enrichment lane and (b) label request-timing logs.

test_that("api_lane defaults to core and is case-insensitive", {
  source(file.path(get_api_dir(), "functions", "external-proxy-request-state.R"), local = TRUE)
  withr::with_envvar(c(API_LANE = ""), {
    expect_identical(api_lane(), "core")
    expect_false(api_lane_is_enrichment())
  })
  withr::with_envvar(c(API_LANE = "Enrichment"), {
    expect_identical(api_lane(), "enrichment")
    expect_true(api_lane_is_enrichment())
  })
  withr::with_envvar(c(API_LANE = "core"), {
    expect_false(api_lane_is_enrichment())
  })
})
