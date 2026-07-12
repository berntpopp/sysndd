# tests/testthat/test-unit-llm-regenerate.R
#
# Unit tests for snapshot-driven LLM regeneration (#488) and the force/cache
# skip decision. Pure tests (no DB, no ellmer): dependencies are stubbed /
# injected.
#
# Host-runnable:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-llm-regenerate.R')"

library(testthat)
library(tibble)

# --- llm_should_skip_cached truth table -------------------------------------

source_batch_generator_env <- function() {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(a, b) if (is.null(a)) b else a
  # Pre-define the conditionally-sourced dependencies so llm-batch-generator.R
  # does NOT source llm-service.R / llm-judge.R (which require ellmer at source).
  env$generate_cluster_summary <- function(...) NULL
  env$get_cached_summary <- function(...) NULL
  env$create_progress_reporter <- function(...) function(...) NULL
  env$generate_and_validate_with_judge <- function(...) NULL
  env$is_gemini_configured <- function() TRUE
  env$create_job <- function(...) list(job_id = "x")
  source_api_file("functions/llm-batch-generator.R", local = FALSE, envir = env)
  env
}

test_that("llm_should_skip_cached truth table", {
  env <- source_batch_generator_env()
  skip <- env$llm_should_skip_cached
  hit <- tibble::tibble(cache_id = 1L)
  miss_null <- NULL
  miss_empty <- tibble::tibble(cache_id = integer())

  # Cache hit, not forced -> skip (use cache)
  expect_true(skip(hit, force = FALSE))
  # Cache hit, forced -> regenerate (do not skip)
  expect_false(skip(hit, force = TRUE))
  # Cache miss (NULL / 0 rows) -> regenerate regardless of force
  expect_false(skip(miss_null, force = FALSE))
  expect_false(skip(miss_empty, force = FALSE))
  expect_false(skip(miss_null, force = TRUE))
})

test_that("trigger_llm_batch_generation threads force into the job params", {
  env <- source_batch_generator_env()
  captured <- new.env()
  env$is_gemini_configured <- function() TRUE
  env$create_job <- function(operation, params) {
    captured$params <- params
    list(job_id = "job-1")
  }
  # Force reading config.yml to succeed by stubbing config::get through the env.
  # Simpler: point db_config resolution at a minimal config via a stub of the
  # helper path is not exposed, so instead stub the whole config read by giving
  # a config.yml-independent path: provide a fake `config` list via options is
  # not possible here. We rely on the real config.yml presence in api/ for the
  # db_config block; if it is unavailable, skip.
  clusters <- tibble::tibble(cluster = 1L, hash_filter = "h1", identifiers = list(tibble::tibble()))
  res <- env$trigger_llm_batch_generation(clusters, "phenotype", "parent", force = TRUE)
  skip_if(is.null(captured$params), "config.yml db_config unavailable on host")
  expect_true(isTRUE(captured$params$force))
})

# --- llm_regenerate_from_snapshot -------------------------------------------

source_regenerate_env <- function() {
  env <- new.env(parent = globalenv())
  source_api_file("functions/llm-regenerate-helpers.R", local = FALSE, envir = env)
  env
}

test_that("llm_regenerate_cluster_type_map maps functional + phenotype", {
  env <- source_regenerate_env()
  f <- env$llm_regenerate_cluster_type_map("functional")
  expect_equal(f$analysis_type, "functional_clusters")
  expect_equal(f$cluster_kind, "functional")
  expect_equal(f$params$algorithm, "leiden")

  p <- env$llm_regenerate_cluster_type_map("phenotype")
  expect_equal(p$analysis_type, "phenotype_clusters")
  expect_equal(p$cluster_kind, "phenotype")

  expect_null(env$llm_regenerate_cluster_type_map("nonsense"))
})

test_that("llm_regenerate_from_snapshot forwards snapshot-shaped clusters whose hash_filter == snapshot cluster_hash", {
  env <- source_regenerate_env()
  captured <- new.env()

  # Snapshot's stored per-cluster hashes (what serving looks up).
  snapshot_hashes <- c("f556d8b467", "175f540336", "e336100201")

  get_snapshot <- function(analysis_type, params) {
    captured$analysis_type <- analysis_type
    captured$params <- params
    list(snapshot = list(id = 17L))
  }
  # Mirror service_analysis_snapshot_shape_clusters: hash_filter == cluster_hash.
  shape_clusters <- function(snapshot, cluster_kind) {
    captured$cluster_kind <- cluster_kind
    tibble::tibble(
      cluster = c(1L, 2L, 3L),
      hash_filter = snapshot_hashes,
      identifiers = list(tibble::tibble(entity_id = 1L))
    )
  }
  trigger <- function(clusters, cluster_type, parent_job_id, force = FALSE) {
    captured$clusters <- clusters
    captured$cluster_type <- cluster_type
    captured$parent_job_id <- parent_job_id
    captured$force <- force
    list(job_id = "llm-job")
  }

  out <- env$llm_regenerate_from_snapshot(
    "phenotype",
    parent_job_id = "p1",
    force = TRUE,
    get_snapshot = get_snapshot,
    shape_clusters = shape_clusters,
    trigger = trigger
  )

  expect_true(out$ready)
  expect_equal(out$analysis_type, "phenotype_clusters")
  expect_equal(out$cluster_count, 3L)
  # Read the published snapshot for phenotype (params list()).
  expect_equal(captured$analysis_type, "phenotype_clusters")
  expect_equal(captured$cluster_kind, "phenotype")
  # The forwarded clusters carry the SNAPSHOT hashes so serving can find them.
  expect_equal(captured$clusters$hash_filter, snapshot_hashes)
  expect_equal(captured$cluster_type, "phenotype")
  expect_equal(captured$parent_job_id, "p1")
  expect_true(captured$force)
})

test_that("llm_regenerate_from_snapshot reports not-ready when no public snapshot", {
  env <- source_regenerate_env()
  trigger_called <- FALSE
  out <- env$llm_regenerate_from_snapshot(
    "phenotype",
    parent_job_id = "p1",
    get_snapshot = function(...) NULL,
    shape_clusters = function(...) stop("must not shape"),
    trigger = function(...) {
      trigger_called <<- TRUE
      NULL
    }
  )
  expect_false(out$ready)
  expect_equal(out$reason, "snapshot_not_ready")
  expect_false(trigger_called)
})

test_that("llm_regenerate_from_snapshot reports empty when snapshot has no clusters", {
  env <- source_regenerate_env()
  out <- env$llm_regenerate_from_snapshot(
    "functional",
    parent_job_id = "p1",
    get_snapshot = function(...) list(snapshot = list(id = 1L)),
    shape_clusters = function(...) tibble::tibble(),
    trigger = function(...) stop("must not trigger on empty")
  )
  expect_false(out$ready)
  expect_equal(out$reason, "snapshot_empty")
})

# --- static guard: /regenerate must not recompute clustering (#488) ----------

test_that("the /regenerate handler no longer recomputes clustering inline", {
  src <- readLines(
    file.path(get_api_dir(), "endpoints", "llm_admin_endpoints.R"),
    warn = FALSE
  )
  joined <- paste(src, collapse = "\n")
  expect_false(grepl("gen_mca_clust_obj_mem", joined, fixed = TRUE))
  expect_false(grepl("gen_string_clust_obj_mem", joined, fixed = TRUE))
  expect_false(grepl("Build data exactly like analysis_endpoints.R", joined, fixed = TRUE))
  # It DOES drive from the snapshot helper.
  expect_true(grepl("llm_regenerate_from_snapshot", joined, fixed = TRUE))
})
