# Unit tests for the self-invalidating analysis cache fingerprints (#514).
#
# The fingerprints are folded into the memoise keys of the analysis-logic-dependent
# clustering functions so a methodology/data/channel change self-invalidates the
# relevant disk-cache entries WITHOUT a manual CACHE_VERSION bump.
source_api_file("functions/analysis-string-channels.R", local = FALSE, envir = globalenv())
source_api_file("functions/analysis-cache-fingerprint.R", local = FALSE, envir = globalenv())

test_that("CLUSTER_LOGIC_VERSION is a non-empty stable token embedded in both fingerprints", {
  expect_true(is.character(CLUSTER_LOGIC_VERSION) && nzchar(CLUSTER_LOGIC_VERSION))
  expect_match(analysis_string_cache_fingerprint(), CLUSTER_LOGIC_VERSION, fixed = TRUE)
  expect_match(analysis_phenotype_cache_fingerprint(), CLUSTER_LOGIC_VERSION, fixed = TRUE)
})

test_that("string fingerprint changes with the STRING channel selection", {
  withr::local_envvar(STRING_EXPDB_EDGES_FILE = "/nonexistent/expdb.txt.gz")
  withr::with_envvar(c(STRING_WEIGHT_CHANNELS = "experimental,database"), {
    a <- analysis_string_cache_fingerprint()
  })
  withr::with_envvar(c(STRING_WEIGHT_CHANNELS = "experimental"), {
    b <- analysis_string_cache_fingerprint()
  })
  expect_false(identical(a, b))
})

test_that("string fingerprint distinguishes present vs absent exp+db file, and file identity", {
  withr::local_envvar(STRING_WEIGHT_CHANNELS = "experimental,database")

  # absent file
  withr::with_envvar(c(STRING_EXPDB_EDGES_FILE = "/nonexistent/expdb.txt.gz"), {
    absent <- analysis_string_cache_fingerprint()
  })
  expect_match(absent, "absent", fixed = TRUE)

  # present file -> different fingerprint, encodes size
  tmp <- tempfile(fileext = ".txt.gz")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(rep("x", 3), tmp)
  withr::with_envvar(c(STRING_EXPDB_EDGES_FILE = tmp), {
    present <- analysis_string_cache_fingerprint()
  })
  expect_match(present, "present:", fixed = TRUE)
  expect_false(identical(absent, present))

  # grow the file -> size changes -> fingerprint changes (self-heals a rebuilt artifact)
  writeLines(rep("x", 50), tmp)
  withr::with_envvar(c(STRING_EXPDB_EDGES_FILE = tmp), {
    grown <- analysis_string_cache_fingerprint()
  })
  expect_false(identical(present, grown))
})

test_that("phenotype fingerprint changes with the MCA prevalence band", {
  withr::with_envvar(c(PHENOTYPE_MCA_PREVALENCE_MIN = "0.05", PHENOTYPE_MCA_PREVALENCE_MAX = "0.95"), {
    a <- analysis_phenotype_cache_fingerprint()
  })
  withr::with_envvar(c(PHENOTYPE_MCA_PREVALENCE_MIN = "0.10", PHENOTYPE_MCA_PREVALENCE_MAX = "0.90"), {
    b <- analysis_phenotype_cache_fingerprint()
  })
  expect_false(identical(a, b))
})

test_that("fingerprint dispatch survives a masked base::get (config::get has no `mode` arg) (#514)", {
  # Regression: config::get (loaded for DB config) masks base::get with a signature
  # that has no `mode` argument, so a `get(fn, mode = "function")` in the dispatcher
  # raised "unused argument (mode = ...)" and failed EVERY snapshot refresh on the
  # worker. Simulate that mask in the global scope the dispatcher resolves from.
  old <- if (base::exists("get", envir = globalenv(), inherits = FALSE)) {
    base::get("get", envir = globalenv(), inherits = FALSE)
  } else {
    NULL
  }
  assign("get", function(value, config = NULL, file = NULL, use_parent = TRUE) {
    stop("masked config::get reached")
  }, envir = globalenv())
  on.exit(
    if (is.null(old)) rm("get", envir = globalenv()) else assign("get", old, envir = globalenv()),
    add = TRUE
  )
  fp_s <- analysis_cache_fingerprint("string")
  fp_p <- analysis_cache_fingerprint("phenotype")
  expect_true(is.character(fp_s) && nzchar(fp_s))
  expect_true(is.character(fp_p) && nzchar(fp_p))
})

test_that("memoise mechanism: a .cache_fingerprint default arg forces a recompute on change (#514)", {
  # Mirrors how gen_string_clust_obj folds analysis_string_cache_fingerprint() into
  # its memoise key. A change to the fingerprint MUST produce a cache miss.
  calls <- 0
  demo <- function(x, .cache_fingerprint = analysis_string_cache_fingerprint()) {
    calls <<- calls + 1
    x * 2
  }
  cm <- cachem::cache_mem()
  demo_mem <- memoise::memoise(demo, cache = cm)

  withr::local_envvar(STRING_EXPDB_EDGES_FILE = "/nonexistent/expdb.txt.gz")
  withr::with_envvar(c(STRING_WEIGHT_CHANNELS = "experimental,database"), {
    demo_mem(21)
    demo_mem(21) # cache hit -> no recompute
  })
  expect_equal(calls, 1L)

  # methodology/channel change -> fingerprint changes -> cache MISS -> recompute
  withr::with_envvar(c(STRING_WEIGHT_CHANNELS = "experimental"), {
    demo_mem(21)
  })
  expect_equal(calls, 2L)
})
