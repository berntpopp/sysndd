analysis_snapshot_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())

analysis_snapshot_fake_res <- function() {
  env <- new.env(parent = emptyenv())
  env$status <- 200L
  env$headers <- list()
  env$setHeader <- function(name, value) {
    env$headers[[name]] <- value
    invisible(NULL)
  }
  env
}

analysis_snapshot_endpoint_handler <- function(decorator_regex) {
  source(file.path("endpoints", "analysis_endpoints.R"), local = TRUE)

  src <- readLines(file.path("endpoints", "analysis_endpoints.R"), warn = FALSE)
  dec_idx <- grep(decorator_regex, src)[[1L]]
  function_start <- dec_idx + which(grepl("^function\\(", src[dec_idx:length(src)]))[[1L]] - 1L
  depth <- 0L
  function_end <- function_start
  for (idx in function_start:length(src)) {
    depth <- depth +
      lengths(regmatches(src[[idx]], gregexpr("\\{", src[[idx]], fixed = FALSE))) -
      lengths(regmatches(src[[idx]], gregexpr("\\}", src[[idx]], fixed = FALSE)))
    if (idx > function_start && depth == 0L) {
      function_end <- idx
      break
    }
  }

  eval(parse(text = paste(src[function_start:function_end], collapse = "\n")))
}

analysis_snapshot_fake_manifest <- function(analysis_type = "gene_network_edges",
                                            parameters_json = "{\"cluster_type\":\"clusters\",\"min_confidence\":400,\"max_edges\":10000}",
                                            row_counts_json = NA_character_) {
  tibble::tibble(
    snapshot_id = 1,
    analysis_type = analysis_type,
    parameter_hash = "hash",
    schema_version = "1.0",
    data_class = "curated_derived_analysis",
    generated_at = as.POSIXct("2026-05-30 00:00:00", tz = "UTC"),
    stale_after = as.POSIXct(NA),
    source_data_version = "source-v1",
    parameters_json = parameters_json,
    algorithm_name = NA_character_,
    row_counts_json = row_counts_json
  )
}

analysis_snapshot_fake_network <- function(row_counts_json = NA_character_) {
  list(
    manifest = analysis_snapshot_fake_manifest(row_counts_json = row_counts_json),
    network_nodes = tibble::tibble(
      hgnc_id = c("HGNC:1", "HGNC:2"),
      symbol = c("AAA", "BBB"),
      cluster_id = c("1", "1"),
      category = c("Definitive", "Moderate"),
      degree = c(1L, 1L),
      x = c(10, 20),
      y = c(30, 40),
      layout_x = c(NA_real_, NA_real_),
      layout_y = c(NA_real_, NA_real_),
      igraph_x = c(NA_real_, NA_real_),
      igraph_y = c(NA_real_, NA_real_)
    ),
    network_edges = tibble::tibble(
      source_hgnc_id = "HGNC:1",
      target_hgnc_id = "HGNC:2",
      confidence = 0.9
    ),
    clusters = tibble::tibble(),
    cluster_members = tibble::tibble(),
    correlations = tibble::tibble()
  )
}

analysis_snapshot_fake_phenotype <- function() {
  list(
    manifest = analysis_snapshot_fake_manifest(
      analysis_type = "phenotype_clusters",
      parameters_json = "{}"
    ),
    network_nodes = tibble::tibble(),
    network_edges = tibble::tibble(),
    clusters = tibble::tibble(
      cluster_kind = "phenotype",
      cluster_id = "1",
      cluster_hash = "phenotype-hash",
      cluster_size = 1L,
      label = NA_character_,
      metadata_json = NA_character_
    ),
    cluster_members = tibble::tibble(
      cluster_kind = "phenotype",
      cluster_id = "1",
      entity_id = 1L,
      hgnc_id = "HGNC:1",
      symbol = "AAA"
    ),
    correlations = tibble::tibble()
  )
}

test_that("analysis snapshot service returns unsupported_parameter before compute", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  result <- service_analysis_snapshot_read(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 700, max_edges = 10000),
    repo_get_public = function(...) stop("repo should not be called")
  )

  expect_equal(result$status, 400L)
  expect_equal(result$body$code, "unsupported_parameter")
})

test_that("analysis snapshot service returns snapshot_missing for supported missing preset", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  result <- service_analysis_snapshot_read(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400, max_edges = 10000),
    repo_get_public = function(...) NULL
  )

  expect_equal(result$status, 503L)
  expect_equal(result$body$code, "snapshot_missing")
})

test_that("analysis snapshot service reports stale and mismatched public snapshots", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  stale <- analysis_snapshot_fake_phenotype()
  stale$status_code <- "snapshot_stale"
  stale_result <- service_analysis_snapshot_read(
    "phenotype_clusters",
    list(),
    repo_get_public = function(...) stale
  )
  expect_equal(stale_result$status, 503L)
  expect_equal(stale_result$body$code, "snapshot_stale")

  mismatched <- analysis_snapshot_fake_phenotype()
  mismatched$status_code <- "source_version_mismatch"
  mismatch_result <- service_analysis_snapshot_read(
    "phenotype_clusters",
    list(),
    repo_get_public = function(...) mismatched
  )
  expect_equal(mismatch_result$status, 503L)
  expect_equal(mismatch_result$body$code, "source_version_mismatch")
})

test_that("serve-time self-heal fires for missing/stale/mismatched snapshots only", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$args <- character(0)
  spy <- function(at) calls$args <- c(calls$args, as.character(at))

  # snapshot_missing -> self-heal fires
  missing <- service_analysis_snapshot_read(
    "phenotype_clusters", list(),
    repo_get_public = function(...) NULL,
    on_stale_refresh = spy
  )
  expect_equal(missing$status, 503L)
  expect_equal(missing$body$code, "snapshot_missing")

  # source_version_mismatch -> self-heal fires
  mismatched <- analysis_snapshot_fake_phenotype()
  mismatched$status_code <- "source_version_mismatch"
  mm <- service_analysis_snapshot_read(
    "phenotype_clusters", list(),
    repo_get_public = function(...) mismatched,
    on_stale_refresh = spy
  )
  expect_equal(mm$status, 503L)

  # stale -> self-heal fires
  stale <- analysis_snapshot_fake_phenotype()
  stale$status_code <- "snapshot_stale"
  st <- service_analysis_snapshot_read(
    "phenotype_clusters", list(),
    repo_get_public = function(...) stale,
    on_stale_refresh = spy
  )
  expect_equal(st$status, 503L)

  expect_equal(calls$args, c("phenotype_clusters", "phenotype_clusters", "phenotype_clusters"))

  # available (200) -> self-heal must NOT fire
  ok <- analysis_snapshot_fake_phenotype()
  ok$status_code <- "available"
  ok_result <- service_analysis_snapshot_read(
    "phenotype_clusters", list(),
    repo_get_public = function(...) ok,
    on_stale_refresh = spy
  )
  expect_equal(ok_result$status, 200L)

  # unsupported_parameter (400) -> self-heal must NOT fire (no compute, no refresh)
  bad <- service_analysis_snapshot_read(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 700, max_edges = 10000),
    repo_get_public = function(...) stop("repo should not be called"),
    on_stale_refresh = spy
  )
  expect_equal(bad$status, 400L)

  # still exactly the three 503-path calls
  expect_equal(length(calls$args), 3L)
})

test_that("serve-time self-heal never turns a 503 into a 500 when the trigger errors", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  result <- service_analysis_snapshot_read(
    "phenotype_clusters", list(),
    repo_get_public = function(...) NULL,
    on_stale_refresh = function(at) stop("boom")
  )
  expect_equal(result$status, 503L)
  expect_equal(result$body$code, "snapshot_missing")
})

test_that("functional endpoint returns unsupported_parameter for walktrap without repo or heavy compute", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  old_service <- service_analysis_snapshot_read
  old_heavy <- get0("gen_string_clust_obj_mem", envir = .GlobalEnv, ifnotfound = NULL)
  assign("gen_string_clust_obj_mem", function(...) stop("heavy helper should not be called"), envir = .GlobalEnv)
  on.exit(
    {
      assign("service_analysis_snapshot_read", old_service, envir = .GlobalEnv)
      if (is.null(old_heavy)) {
        rm("gen_string_clust_obj_mem", envir = .GlobalEnv)
      } else {
        assign("gen_string_clust_obj_mem", old_heavy, envir = .GlobalEnv)
      }
    },
    add = TRUE
  )

  assign("service_analysis_snapshot_read", function(analysis_type, params, repo_get_public = NULL) {
    old_service(analysis_type, params, repo_get_public = function(...) stop("repo should not be called"))
  }, envir = .GlobalEnv)

  endpoint <- analysis_snapshot_endpoint_handler("^#\\*\\s+@get\\s+functional_clustering\\s*$")
  res <- analysis_snapshot_fake_res()
  result <- endpoint(algorithm = "walktrap", res = res)

  expect_equal(res$status, 400L)
  expect_equal(result$code, "unsupported_parameter")
})

test_that("network endpoint returns unsupported_parameter for unsupported raw params without repo or heavy compute", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  old_service <- service_analysis_snapshot_read
  old_heavy <- get0("generate_network_edges_response", envir = .GlobalEnv, ifnotfound = NULL)
  assign("generate_network_edges_response", function(...) stop("heavy helper should not be called"), envir = .GlobalEnv)
  on.exit(
    {
      assign("service_analysis_snapshot_read", old_service, envir = .GlobalEnv)
      if (is.null(old_heavy)) {
        rm("generate_network_edges_response", envir = .GlobalEnv)
      } else {
        assign("generate_network_edges_response", old_heavy, envir = .GlobalEnv)
      }
    },
    add = TRUE
  )

  assign("service_analysis_snapshot_read", function(analysis_type, params, repo_get_public = NULL) {
    old_service(analysis_type, params, repo_get_public = function(...) stop("repo should not be called"))
  }, envir = .GlobalEnv)

  endpoint <- analysis_snapshot_endpoint_handler("^#\\*\\s+@get\\s+network_edges\\s*$")

  min_confidence_res <- analysis_snapshot_fake_res()
  min_confidence_result <- endpoint(min_confidence = "700", res = min_confidence_res)
  expect_equal(min_confidence_res$status, 400L)
  expect_equal(min_confidence_result$code, "unsupported_parameter")

  cluster_type_res <- analysis_snapshot_fake_res()
  cluster_type_result <- endpoint(cluster_type = "invalid", res = cluster_type_res)
  expect_equal(cluster_type_res$status, 400L)
  expect_equal(cluster_type_result$code, "unsupported_parameter")
})

test_that("phenotype snapshot shaping preserves meta snapshot envelope", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  result <- service_analysis_snapshot_shape_phenotype_clusters(analysis_snapshot_fake_phenotype())

  expect_equal(as.character(result$meta$snapshot$analysis_type), "phenotype_clusters")
  expect_equal(result$clusters$cluster[[1]], "1")
})

test_that("phenotype cluster metadata round-trips scalar table values for JSON export", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  snapshot <- analysis_snapshot_fake_phenotype()
  snapshot$clusters$metadata_json[[1]] <- jsonlite::toJSON(
    list(
      quali_inp_var = tibble::tibble(variable = "Seizures", `p.value` = 0.001, `v.test` = 3.2),
      quali_sup_var = tibble::tibble(variable = "AD", `p.value` = 0.02, `v.test` = 2.4),
      quanti_sup_var = tibble::tibble(variable = "count", `p.value` = 0.03, `v.test` = 2.1)
    ),
    auto_unbox = TRUE,
    dataframe = "rows"
  )

  result <- service_analysis_snapshot_shape_phenotype_clusters(snapshot)
  json <- jsonlite::toJSON(result, dataframe = "rows", auto_unbox = FALSE)

  expect_s3_class(result$clusters$quali_inp_var[[1]], "data.frame")
  expect_equal(result$clusters$quali_inp_var[[1]]$variable[[1]], "Seizures")
  expect_false(grepl('"variable":\\["Seizures"\\]', json))
  expect_false(grepl('"p.value":\\[0.001\\]', json))
  expect_false(grepl('"v.test":\\[3.2\\]', json))
})

test_that("snapshot metadata serializes scalar fields for non-auto-unbox endpoints", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  result <- service_analysis_snapshot_shape_phenotype_clusters(analysis_snapshot_fake_phenotype())
  json <- jsonlite::toJSON(result$meta, auto_unbox = FALSE)

  expect_false(grepl('"analysis_type":\\["phenotype_clusters"\\]', json))
  expect_false(grepl('"source_data_version":\\["source-v1"\\]', json))
})

test_that("phenotype-functional snapshot shaping preserves diagonal correlations for REST", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  snapshot <- analysis_snapshot_fake_phenotype()
  snapshot$correlations <- tibble::tibble(
    x_key = c("pc_1", "pc_1"),
    y_key = c("pc_1", "fc_1"),
    value = c(1, 0.3)
  )

  result <- service_analysis_snapshot_read(
    "phenotype_functional_correlations",
    list(),
    repo_get_public = function(...) snapshot
  )

  expect_equal(result$status, 200L)
  expect_true(any(result$body$correlation_melted$x == "pc_1" & result$body$correlation_melted$y == "pc_1"))
})

test_that("network snapshot shaping replays original generated metadata", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  snapshot <- analysis_snapshot_fake_network(
    row_counts_json = '{"nodes":2,"edges":1,"network_metadata":{"total_edges":42,"edges_filtered":true,"string_version":"11.5"}}'
  )

  result <- service_analysis_snapshot_shape_network(snapshot)

  expect_equal(result$metadata$total_edges, 42)
  expect_true(result$metadata$edges_filtered)
  expect_equal(result$metadata$string_version, "11.5")
})

test_that("snapshot pagination returns empty page after final cursor", {
  source(file.path("endpoints", "analysis_endpoints.R"), local = TRUE)

  body <- list(
    clusters = tibble::tibble(
      cluster = c(1L, 2L),
      hash_filter = c("hash-1", "hash-2")
    )
  )

  result <- analysis_paginate_snapshot_clusters(body, "hash-2", 10L)

  expect_equal(nrow(result$clusters), 0L)
  expect_null(result$pagination$next_cursor)
  expect_false(result$pagination$has_more)
})

test_that("snapshot pagination rejects malformed cluster payloads instead of restarting pages", {
  source(file.path("endpoints", "analysis_endpoints.R"), local = TRUE)

  res <- analysis_snapshot_fake_res()
  body <- list(clusters = tibble::tibble(cluster = c(1L, 2L)))

  result <- analysis_paginate_snapshot_clusters(body, "hash-2", 10L, res = res)

  expect_equal(res$status, 500L)
  expect_equal(result$code, "snapshot_payload_invalid")
  expect_equal(result$details$missing_columns, "hash_filter")
})

test_that("network endpoint success preserves snapshot metadata and missing snapshots set Retry-After", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  old_service <- service_analysis_snapshot_read
  on.exit(assign("service_analysis_snapshot_read", old_service, envir = .GlobalEnv), add = TRUE)

  assign("service_analysis_snapshot_read", function(analysis_type, params, repo_get_public = NULL) {
    old_service(
      analysis_type,
      params,
      repo_get_public = function(...) {
        analysis_snapshot_fake_network(
          row_counts_json = '{"nodes":2,"edges":1,"network_metadata":{"total_edges":42,"edges_filtered":true}}'
        )
      }
    )
  }, envir = .GlobalEnv)

  endpoint <- analysis_snapshot_endpoint_handler("^#\\*\\s+@get\\s+network_edges\\s*$")
  res <- analysis_snapshot_fake_res()
  success <- endpoint(res = res)
  expect_equal(as.character(success$metadata$snapshot$analysis_type), "gene_network_edges")
  expect_equal(success$metadata$total_edges, 42)

  assign("service_analysis_snapshot_read", function(analysis_type, params, repo_get_public = NULL) {
    old_service(analysis_type, params, repo_get_public = function(...) NULL)
  }, envir = .GlobalEnv)
  missing_res <- analysis_snapshot_fake_res()
  missing <- endpoint(res = missing_res)
  expect_equal(missing_res$status, 503L)
  expect_equal(missing_res$headers[["Retry-After"]], "60")
  expect_equal(missing$code, "snapshot_missing")
})
