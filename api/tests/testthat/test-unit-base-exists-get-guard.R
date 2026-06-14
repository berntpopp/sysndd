# tests/testthat/test-unit-base-exists-get-guard.R
#
# Static guard: any call to exists()/get() that passes `inherits =` MUST be
# namespaced as base::exists / base::get.
#
# Why: the live API runtime attaches packages (e.g. biomaRt -> AnnotationDbi)
# that mask base `exists`/`get` with S4 generics which reject the base R
# `inherits =` argument. A bare `exists("dw", envir = .GlobalEnv, inherits =
# FALSE)` then throws `unused arguments (envir, inherits)`, which 500'd
# GET /api/llm/config (the masked-verb failure mode documented in AGENTS.md,
# same class as biomaRt::select masking dplyr::select).
#
# Pure test (no DB / no network) -- runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-base-exists-get-guard.R')"

guarded_source_files <- function() {
  root <- get_api_dir()
  dirs <- file.path(root, c("endpoints", "functions", "services", "core"))
  dirs <- dirs[dir.exists(dirs)]
  unlist(lapply(dirs, list.files, pattern = "\\.R$", full.names = TRUE))
}

# An offending line passes `inherits` to a *bare* exists()/get() call --
# i.e. one not already namespaced as `base::exists` / `base::get` (and not part
# of some other `pkg::exists` call).
bare_inherits_offenders <- function(verb, files) {
  offenders <- character()
  bare <- paste0("(^|[^:[:alnum:]_.])", verb, "\\(")
  namespaced <- paste0("base::", verb, "\\(")
  for (f in files) {
    src <- readLines(f, warn = FALSE)
    for (i in seq_along(src)) {
      line <- src[i]
      if (!grepl("\\binherits\\b", line)) next
      if (!grepl(bare, line)) next
      if (grepl(namespaced, line)) next
      offenders <- c(offenders, paste0(basename(f), ":", i, ": ", trimws(line)))
    }
  }
  offenders
}

test_that("exists() with inherits= is base:: namespaced", {
  offenders <- bare_inherits_offenders("exists", guarded_source_files())
  expect_identical(
    offenders, character(),
    info = paste(
      "Use base::exists() when passing inherits= (masked-verb guard):",
      paste(offenders, collapse = " | ")
    )
  )
})

test_that("get() with inherits= is base:: namespaced", {
  offenders <- bare_inherits_offenders("get", guarded_source_files())
  expect_identical(
    offenders, character(),
    info = paste(
      "Use base::get() when passing inherits= (masked-verb guard):",
      paste(offenders, collapse = " | ")
    )
  )
})
