if (!exists(".async_job_run_network_layout_prewarm", mode = "function")) {
  source_api_file("functions/async-job-network-layout-handlers.R", local = FALSE, envir = globalenv())
}

network_layout_job_runner_with_stubs <- function(...) {
  runner <- .async_job_run_network_layout_prewarm
  stub_env <- list2env(list(...), parent = environment(runner))
  environment(runner) <- stub_env
  runner
}

test_that("network layout prewarm job uses defaults and reports artifact metadata", {
  calls <- new.env(parent = emptyenv())
  calls$network <- list()
  calls$artifact <- list()

  runner <- network_layout_job_runner_with_stubs(
    generate_network_edges_response = function(cluster_type, min_confidence, max_edges) {
      calls$network <- list(
        cluster_type = cluster_type,
        min_confidence = min_confidence,
        max_edges = max_edges
      )
      list(nodes = tibble::tibble(hgnc_id = "HGNC:1"), edges = tibble::tibble(), metadata = list())
    },
    generate_network_display_layout_artifact = function(network_data,
                                                        cluster_type,
                                                        min_confidence,
                                                        max_edges,
                                                        force) {
      calls$artifact <- list(
        cluster_type = cluster_type,
        min_confidence = min_confidence,
        max_edges = max_edges,
        force = force,
        network_data = network_data
      )
      list(
        metadata = list(
          layout_key = "layout-key",
          cache_hit = TRUE,
          node_count = 1L,
          edge_count = 0L,
          layout_duration_ms = 25L
        )
      )
    }
  )

  result <- runner(
    job = list(job_id = "job-1"),
    payload = list(),
    state = list(),
    worker_config = list()
  )

  expect_equal(calls$network$cluster_type, "clusters")
  expect_equal(calls$network$min_confidence, 400L)
  expect_equal(calls$network$max_edges, 10000L)
  expect_false(calls$artifact$force)
  expect_equal(result$status, "completed")
  expect_equal(result$layout_key, "layout-key")
  expect_true(result$cache_hit)
})

test_that("network layout prewarm job forwards force and payload values", {
  observed <- new.env(parent = emptyenv())

  runner <- network_layout_job_runner_with_stubs(
    generate_network_edges_response = function(cluster_type, min_confidence, max_edges) {
      list(nodes = tibble::tibble(hgnc_id = "HGNC:1"), edges = tibble::tibble(), metadata = list())
    },
    generate_network_display_layout_artifact = function(network_data,
                                                        cluster_type,
                                                        min_confidence,
                                                        max_edges,
                                                        force) {
      observed$force <- force
      observed$cluster_type <- cluster_type
      observed$min_confidence <- min_confidence
      observed$max_edges <- max_edges
      list(metadata = list(layout_key = "forced", cache_hit = FALSE, node_count = 1L, edge_count = 0L))
    }
  )

  result <- runner(
    job = list(job_id = "job-1"),
    payload = list(cluster_type = "subclusters", min_confidence = 700, max_edges = 3000, force = TRUE),
    state = list(),
    worker_config = list()
  )

  expect_equal(observed$cluster_type, "subclusters")
  expect_equal(observed$min_confidence, 700L)
  expect_equal(observed$max_edges, 3000L)
  expect_true(observed$force)
  expect_false(result$cache_hit)
})

test_that("async worker binds shared memoise cache before starting", {
  script <- readLines(file.path(get_api_dir(), "start_async_worker.R"), warn = FALSE)

  expect_true(any(grepl('source\\("bootstrap/init_cache.R"', script, fixed = FALSE)))
  expect_true(any(grepl("bootstrap_init_cache_version()", script, fixed = TRUE)))
  expect_true(any(grepl("bootstrap_bind_memoised(envir = .GlobalEnv)", script, fixed = TRUE)))
})

test_that("network layout submit endpoint is mounted under jobs", {
  mount_script <- readLines(file.path(get_api_dir(), "bootstrap", "mount_endpoints.R"), warn = FALSE)

  expect_true(any(grepl(
    'pr_mount\\("/api/jobs/network_layout", plumber::pr\\("endpoints/jobs_network_layout_endpoints.R"\\)\\)',
    mount_script
  )))
})

test_that("network layout submit endpoint uses top-level authenticated user id", {
  endpoint_script <- paste(
    readLines(file.path(get_api_dir(), "endpoints", "jobs_network_layout_endpoints.R"), warn = FALSE),
    collapse = "\n"
  )

  expect_true(grepl("submitted_by = req\\$user_id %\\|\\|% NULL", endpoint_script))
  expect_false(grepl("submitted_by = req\\$user\\$user_id", endpoint_script))
})
