# tests/testthat/test-integration-analysis-release-admin-endpoints.R
#
# Integration tests for the ADMIN routes of immutable analysis-snapshot
# releases (#573 Slice A / Task A7): the 6 routes appended to
# endpoints/admin_analysis_snapshot_endpoints.R -- POST /releases (build),
# GET /releases (admin list, incl. drafts), GET /releases/<id> (admin
# detail, incl. draft), POST /releases/<id>/publish, PATCH
# /releases/<id>/doi, DELETE /releases/<id>.
#
# Handler-extraction idiom (mirrors test-integration-analysis-release-endpoints.R,
# A6's public-route test, which itself mirrors test-endpoint-analysis-snapshot-read.R):
# each route handler is extracted from admin_analysis_snapshot_endpoints.R by
# decorator regex + brace-depth scan, then eval()'d and called directly with a
# fake `req`/`res` -- no live plumber router needed. Every free variable an
# extracted handler references at call time (require_role, svc_release_*,
# analysis_release_*, stop_for_not_found, `pool`, `%||%`) is bound straight
# into .GlobalEnv via base source(file, local = FALSE) -- see A6's file header
# for the empirically-verified reason a test_that()-local source() does not
# reach a sibling top-level closure's lexical chain, while .GlobalEnv always
# does.
#
# UNLIKE A6, this file sources core/middleware.R FOR REAL (not stubbed) so
# require_role()'s actual 403-vs-pass-through behaviour is exercised, matching
# the brief's explicit ask to "verify against how require_role signals".
# core/middleware.R only needs library(jose)/library(stringr)/library(logger),
# all available on host.
#
# POST /releases (build) is tested against a STUBBED
# analysis_snapshot_release_build() (real snapshot-backed building is
# integration-tested in A4's own test file and end-to-end in the dev-stack;
# seeding the full analysis_snapshot_* source tables here would duplicate
# that coverage for no benefit). The stub is bound into .GlobalEnv the same
# way `pool` is -- assign + withr::defer(rm(...)).
#
# analysis_snapshot_release_build()'s ultimate persistence call,
# analysis_release_insert(), wraps its writes in ONE
# DBI::dbWithTransaction() and binds blob params via list(<raw>) -- both need
# a real DBIConnection, never a bare pool::Pool (see
# functions/analysis-snapshot-release-repository.R's file header). The
# production POST /releases route therefore does
# pool::poolCheckout(pool)/pool::poolReturn(conn) around the build call, so
# `pool` must be bound to a GENUINE pool::dbPool() here (not just a raw
# connection, unlike A6's `pool <- conn` shortcut) or poolCheckout() errors.
# make_test_pool() mirrors test-integration-entity-rename.R's identically-named
# helper.

release_admin_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(release_admin_test_wd), testthat::teardown_env())

release_a7_globals_before <- ls(envir = .GlobalEnv)
source(file.path("core", "errors.R"), local = FALSE)
source(file.path("core", "middleware.R"), local = FALSE)
source(file.path("functions", "analysis-snapshot-presets.R"), local = FALSE)
source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = FALSE)
source(file.path("functions", "analysis-snapshot-release-repository.R"), local = FALSE)
source(file.path("services", "analysis-snapshot-release-service.R"), local = FALSE)
release_a7_new_globals <- setdiff(ls(envir = .GlobalEnv), release_a7_globals_before)
withr::defer(
  rm(list = intersect(release_a7_new_globals, ls(envir = .GlobalEnv)), envir = .GlobalEnv),
  testthat::teardown_env()
)

# --------------------------------------------------------------------------- #
# Fixture builders (mirrors test-integration-analysis-release-endpoints.R)
# --------------------------------------------------------------------------- #

TEST_PUBLISHED_RELEASE_ID <- "asr_test0000000701"
TEST_DRAFT_PUBLISH_RELEASE_ID <- "asr_test0000000702"
TEST_DRAFT_DELETE_RELEASE_ID <- "asr_test0000000703"
ALL_TEST_A7_RELEASE_IDS <- c(
  TEST_PUBLISHED_RELEASE_ID, TEST_DRAFT_PUBLISH_RELEASE_ID, TEST_DRAFT_DELETE_RELEASE_ID
)

.delete_test_a7_releases <- function(conn) {
  placeholders <- paste(rep("?", length(ALL_TEST_A7_RELEASE_IDS)), collapse = ",")
  DBI::dbExecute(
    conn,
    sprintf("DELETE FROM analysis_snapshot_release WHERE release_id IN (%s)", placeholders),
    params = unname(as.list(ALL_TEST_A7_RELEASE_IDS))
  )
}

make_gzip_file <- function(file_path, text, media_type = "application/json") {
  raw_bytes <- charToRaw(text)
  list(
    file_path = file_path,
    content_sha256 = analysis_release_sha256(raw_bytes),
    byte_size = length(raw_bytes),
    media_type = media_type,
    content_gzip = memCompress(raw_bytes, type = "gzip")
  )
}

make_manifest_file <- function(release_id, payload_file) {
  manifest_json <- analysis_snapshot_canonical_json(list(
    release_id = release_id,
    release_version = "v1",
    files = list(list(
      path = payload_file$file_path,
      sha256 = payload_file$content_sha256,
      bytes = payload_file$byte_size
    ))
  ))
  make_gzip_file("manifest.json", manifest_json)
}

make_release_head <- function(release_id, manifest_file) {
  bundle_gzip <- memCompress(charToRaw(paste0("bundle contents for ", release_id)), type = "gzip")
  list(
    release_id = release_id,
    release_version = "v1",
    title = "Test admin release",
    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
    content_digest = analysis_release_sha256(paste0("digest-", release_id)),
    # manifest_sha256 MUST equal the manifest.json FILE's own content_sha256.
    manifest_sha256 = manifest_file$content_sha256,
    bundle_sha256 = analysis_release_sha256(bundle_gzip),
    bundle_gzip = bundle_gzip,
    source_data_version = "srcv1",
    license = "CC-BY-4.0"
  )
}

make_member <- function() {
  list(
    analysis_type = "functional_clusters",
    parameter_hash = analysis_release_sha256("functional_clusters-params"),
    snapshot_id = 701L,
    input_hash = analysis_release_sha256("functional_clusters-input"),
    payload_hash = analysis_release_sha256("functional_clusters-payload"),
    schema_version = "1.2",
    reproducibility_hash = analysis_release_sha256("functional_clusters-repro"),
    role = "layer"
  )
}

#' Seed one release directly via the A3 repository (not the A4 build
#' orchestrator -- mirrors A6's fixture style).
seed_release <- function(conn, release_id, publish) {
  payload_file <- make_gzip_file("functional_clusters/payload.json", paste0("{\"id\":\"", release_id, "\"}"))
  manifest_file <- make_manifest_file(release_id, payload_file)
  head <- make_release_head(release_id, manifest_file)
  analysis_release_insert(head, list(make_member()), list(manifest_file, payload_file), conn)
  if (isTRUE(publish)) {
    analysis_release_publish(release_id, conn = conn)
  }
  head
}

#' A GENUINE pool::dbPool(), required by the build route's
#' pool::poolCheckout(pool) -- mirrors test-integration-entity-rename.R's
#' identically-named helper.
make_test_pool <- function() {
  test_config <- get_test_config()
  pool::dbPool(
    RMariaDB::MariaDB(),
    dbname = test_config$dbname,
    host = test_config$host,
    user = test_config$user,
    password = test_config$password,
    port = as.integer(test_config$port)
  )
}

# --------------------------------------------------------------------------- #
# Handler extraction idiom
# --------------------------------------------------------------------------- #

release_endpoint_fake_res <- function() {
  env <- new.env(parent = emptyenv())
  env$status <- 200L
  env$headers <- list()
  env$setHeader <- function(name, value) {
    env$headers[[name]] <- value
    invisible(NULL)
  }
  env
}

release_admin_fake_req <- function(role = "Administrator", user_id = 42L, post_body = NULL) {
  req <- new.env(parent = emptyenv())
  req$user_role <- role
  req$user_id <- user_id
  req$postBody <- post_body
  req$PATH_INFO <- "/api/admin/analysis/releases"
  req
}

release_admin_handler <- function(decorator_regex) {
  source(file.path("endpoints", "admin_analysis_snapshot_endpoints.R"), local = TRUE)

  src <- readLines(file.path("endpoints", "admin_analysis_snapshot_endpoints.R"), warn = FALSE)
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

#' Build a classed condition matching A4's `c(<name>, "error", "condition")`
#' shape (functions/analysis-snapshot-release.R `.analysis_release_condition`).
release_condition <- function(class_name, message) {
  structure(class = c(class_name, "error", "condition"), list(message = message, call = NULL))
}

ADMIN_A7_DECORATORS <- list(
  build = "^#\\*\\s+@post\\s+/releases\\s*$",
  list = "^#\\*\\s+@get\\s+/releases\\s*$",
  detail = "^#\\*\\s+@get\\s+/releases/<release_id>\\s*$",
  publish = "^#\\*\\s+@post\\s+/releases/<release_id>/publish\\s*$",
  doi = "^#\\*\\s+@patch\\s+/releases/<release_id>/doi\\s*$",
  delete = "^#\\*\\s+@delete\\s+/releases/<release_id>\\s*$"
)

# =============================================================================
# Role gate
# =============================================================================

test_that("all 6 admin release routes reject a non-Administrator request with error_403", {
  for (dec in ADMIN_A7_DECORATORS) {
    handler <- release_admin_handler(dec)
    err <- tryCatch(
      handler(req = release_admin_fake_req(role = "Viewer"), res = release_endpoint_fake_res()),
      error = function(e) e
    )
    expect_s3_class(err, "error_403")
  }
})

test_that("require_role lets an Administrator-role request through", {
  passed <- tryCatch(
    {
      require_role(release_admin_fake_req(role = "Administrator"), release_endpoint_fake_res(), "Administrator")
      TRUE
    },
    error = function(e) FALSE
  )
  expect_true(passed)
})

# =============================================================================
# POST /releases (stubbed orchestrator)
# =============================================================================

test_that("POST /releases: 201 on a new build, 200 on an idempotent duplicate, 400 naming the failing layer on a gate error", {
  skip_if_no_test_db()

  admin_pool <- make_test_pool()
  withr::defer(pool::poolClose(admin_pool))
  assign("pool", admin_pool, envir = .GlobalEnv)
  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))

  build_handler <- release_admin_handler(ADMIN_A7_DECORATORS$build)
  withr::defer(if (exists("analysis_snapshot_release_build", envir = .GlobalEnv, inherits = FALSE)) {
    rm("analysis_snapshot_release_build", envir = .GlobalEnv)
  })

  # --- 201: newly created ---------------------------------------------------
  head_new <- list(release_id = "asr_admin_new", status = "draft")
  assign("analysis_snapshot_release_build", function(...) list(release = head_new, created = TRUE), envir = .GlobalEnv)
  res_new <- release_endpoint_fake_res()
  out_new <- build_handler(req = release_admin_fake_req(post_body = "{}"), res = res_new)
  expect_equal(res_new$status, 201L)
  expect_identical(out_new, head_new)

  # --- 200: idempotent duplicate ---------------------------------------------
  head_dup <- list(release_id = "asr_admin_dup", status = "published")
  assign("analysis_snapshot_release_build", function(...) list(release = head_dup, created = FALSE), envir = .GlobalEnv)
  res_dup <- release_endpoint_fake_res()
  out_dup <- build_handler(req = release_admin_fake_req(post_body = "{}"), res = res_dup)
  expect_equal(res_dup$status, 200L)
  expect_identical(out_dup, head_dup)

  # --- 400: gate failure, message names the failing layer --------------------
  assign(
    "analysis_snapshot_release_build",
    function(...) {
      stop(release_condition(
        "release_snapshot_not_available",
        "layer functional_clusters is not available for release: snapshot_stale"
      ))
    },
    envir = .GlobalEnv
  )
  gate_err <- tryCatch(
    build_handler(req = release_admin_fake_req(post_body = "{}"), res = release_endpoint_fake_res()),
    error = function(e) e
  )
  expect_s3_class(gate_err, "error_400")
  expect_match(conditionMessage(gate_err), "functional_clusters", fixed = TRUE)
  expect_match(conditionMessage(gate_err), "snapshot_stale", fixed = TRUE)
})

test_that("POST /releases: a caller-supplied `layers` JSON body array parses as list-of-lists, never a data.frame", {
  skip_if_no_test_db()

  admin_pool <- make_test_pool()
  withr::defer(pool::poolClose(admin_pool))
  assign("pool", admin_pool, envir = .GlobalEnv)
  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))

  build_handler <- release_admin_handler(ADMIN_A7_DECORATORS$build)
  withr::defer(if (exists("analysis_snapshot_release_build", envir = .GlobalEnv, inherits = FALSE)) {
    rm("analysis_snapshot_release_build", envir = .GlobalEnv)
  })

  captured <- NULL
  assign(
    "analysis_snapshot_release_build",
    function(...) {
      captured <<- list(...)
      list(release = list(release_id = "asr_admin_layers"), created = TRUE)
    },
    envir = .GlobalEnv
  )

  post_body <- paste0(
    '{"title":"Manual build","publish":false,"layers":[',
    '{"analysis_type":"functional_clusters","params":{"algorithm":"leiden"},',
    '"files_prefix":"functional_clusters","has_reproducibility":true},',
    '{"analysis_type":"phenotype_clusters","params":{},',
    '"files_prefix":"phenotype_clusters","has_reproducibility":true}',
    "]}"
  )
  build_handler(req = release_admin_fake_req(post_body = post_body), res = release_endpoint_fake_res())

  expect_false(is.null(captured$layers))
  expect_false(is.data.frame(captured$layers))
  expect_type(captured$layers, "list")
  expect_length(captured$layers, 2L)
  expect_equal(captured$layers[[1]]$analysis_type, "functional_clusters")
  expect_equal(captured$layers[[1]]$params$algorithm, "leiden")
  expect_true(isTRUE(captured$layers[[1]]$has_reproducibility))
  expect_equal(captured$layers[[2]]$analysis_type, "phenotype_clusters")
  expect_length(captured$layers[[2]]$params, 0L) # jsonlite parses {} as a named empty list
  expect_equal(captured$title, "Manual build")
  expect_false(isTRUE(captured$publish))
})

test_that("POST /releases: an empty body omits `layers` (lets the orchestrator default apply) and defaults publish=TRUE/license", {
  skip_if_no_test_db()

  admin_pool <- make_test_pool()
  withr::defer(pool::poolClose(admin_pool))
  assign("pool", admin_pool, envir = .GlobalEnv)
  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))

  build_handler <- release_admin_handler(ADMIN_A7_DECORATORS$build)
  withr::defer(if (exists("analysis_snapshot_release_build", envir = .GlobalEnv, inherits = FALSE)) {
    rm("analysis_snapshot_release_build", envir = .GlobalEnv)
  })

  captured <- NULL
  assign(
    "analysis_snapshot_release_build",
    function(...) {
      captured <<- list(...)
      list(release = list(release_id = "asr_admin_default"), created = TRUE)
    },
    envir = .GlobalEnv
  )

  build_handler(req = release_admin_fake_req(post_body = NULL), res = release_endpoint_fake_res())

  expect_null(captured$layers)
  expect_true(isTRUE(captured$publish))
  expect_equal(captured$license, "CC-BY-4.0")
  expect_equal(captured$created_by, 42L)
})

# =============================================================================
# Admin lifecycle: list (incl. drafts), detail (incl. draft), publish,
# DOI patch, delete
# =============================================================================

test_that("admin release lifecycle: list shows drafts, detail returns a draft, publish flips a draft, DOI patch is additive, delete refuses published/removes a draft", {
  skip_if_no_test_db()

  schema_conn <- get_test_db_connection()
  ensure_test_release_schema(schema_conn)
  DBI::dbDisconnect(schema_conn)

  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))
  .delete_test_a7_releases(conn) # pre-clean any leftovers from a crashed run
  withr::defer(.delete_test_a7_releases(conn)) # post-clean

  admin_pool <- make_test_pool()
  withr::defer(pool::poolClose(admin_pool))
  assign("pool", admin_pool, envir = .GlobalEnv)
  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))

  seed_release(conn, TEST_PUBLISHED_RELEASE_ID, publish = TRUE)
  seed_release(conn, TEST_DRAFT_PUBLISH_RELEASE_ID, publish = FALSE)
  seed_release(conn, TEST_DRAFT_DELETE_RELEASE_ID, publish = FALSE)

  admin_req <- release_admin_fake_req()

  # =========================================================================
  # GET /releases (admin): published AND both drafts appear
  # =========================================================================
  list_handler <- release_admin_handler(ADMIN_A7_DECORATORS$list)
  list_result <- list_handler(req = admin_req, res = release_endpoint_fake_res())
  listed_ids <- vapply(list_result$releases, function(r) as.character(r$release_id), character(1))
  expect_true(TEST_PUBLISHED_RELEASE_ID %in% listed_ids)
  expect_true(TEST_DRAFT_PUBLISH_RELEASE_ID %in% listed_ids)
  expect_true(TEST_DRAFT_DELETE_RELEASE_ID %in% listed_ids)

  # =========================================================================
  # GET /releases/<release_id> (admin): a draft id returns the draft; unknown -> 404
  # =========================================================================
  detail_handler <- release_admin_handler(ADMIN_A7_DECORATORS$detail)
  draft_detail <- detail_handler(
    req = admin_req, res = release_endpoint_fake_res(), release_id = TEST_DRAFT_PUBLISH_RELEASE_ID
  )
  expect_equal(as.character(draft_detail$release_id), TEST_DRAFT_PUBLISH_RELEASE_ID)
  expect_equal(as.character(draft_detail$status), "draft")

  unknown_err <- tryCatch(
    detail_handler(req = admin_req, res = release_endpoint_fake_res(), release_id = "asr_does_not_exist"),
    error = function(e) e
  )
  expect_s3_class(unknown_err, "error_404")

  # =========================================================================
  # POST /releases/<release_id>/publish: flips a seeded draft
  # =========================================================================
  publish_handler <- release_admin_handler(ADMIN_A7_DECORATORS$publish)
  published_result <- publish_handler(
    req = admin_req, res = release_endpoint_fake_res(), release_id = TEST_DRAFT_PUBLISH_RELEASE_ID
  )
  expect_equal(as.character(published_result$status), "published")

  reread_after_publish <- analysis_release_get(TEST_DRAFT_PUBLISH_RELEASE_ID, include_draft = TRUE, conn = conn)
  expect_equal(as.character(reread_after_publish$status), "published")

  # =========================================================================
  # PATCH /releases/<release_id>/doi: additive, content_digest/manifest_sha256 unchanged
  # =========================================================================
  doi_handler <- release_admin_handler(ADMIN_A7_DECORATORS$doi)
  before_doi <- analysis_release_get(TEST_PUBLISHED_RELEASE_ID, include_draft = TRUE, conn = conn)

  doi_result <- doi_handler(
    req = admin_req, res = release_endpoint_fake_res(),
    release_id = TEST_PUBLISHED_RELEASE_ID,
    version_doi = "10.5281/zenodo.999999"
  )
  expect_equal(as.character(doi_result$version_doi), "10.5281/zenodo.999999")
  expect_equal(as.character(doi_result$content_digest), as.character(before_doi$content_digest))
  expect_equal(as.character(doi_result$manifest_sha256), as.character(before_doi$manifest_sha256))
  # only the supplied field was touched -- an omitted field stays unset, it
  # is never nulled out by the partial update.
  expect_true(is.na(doi_result$zenodo_record_id))

  # =========================================================================
  # DELETE /releases/<release_id>: refuses published, removes a draft
  # =========================================================================
  delete_handler <- release_admin_handler(ADMIN_A7_DECORATORS$delete)
  published_delete_err <- tryCatch(
    delete_handler(req = admin_req, res = release_endpoint_fake_res(), release_id = TEST_PUBLISHED_RELEASE_ID),
    error = function(e) e
  )
  expect_s3_class(published_delete_err, "error_400")
  expect_true(analysis_release_exists(TEST_PUBLISHED_RELEASE_ID, conn = conn))

  draft_delete_result <- delete_handler(
    req = admin_req, res = release_endpoint_fake_res(), release_id = TEST_DRAFT_DELETE_RELEASE_ID
  )
  expect_true(isTRUE(draft_delete_result$deleted))
  expect_false(analysis_release_exists(TEST_DRAFT_DELETE_RELEASE_ID, conn = conn))

  delete_unknown_err <- tryCatch(
    delete_handler(req = admin_req, res = release_endpoint_fake_res(), release_id = "asr_does_not_exist"),
    error = function(e) e
  )
  expect_s3_class(delete_unknown_err, "error_404")
})
