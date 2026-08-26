# dplyr verbs that other loaded packages mask must stay namespaced.
#
# `biomaRt` exports an S4 `select` and `stats` exports `filter`, and both are on
# the API/worker search path. Whether a bare call resolves to the dplyr verb
# therefore depends on package ATTACH ORDER, which differs between the running
# API, the durable worker, the mirai pool and a standalone Rscript. A bare call
# fails with "unable to find an inherited method for function 'select' for
# signature 'x = \"tbl_df\"'" -- which is how gen_mca_clust_obj() broke the
# moment it was exercised outside the API's own load order.
#
# AGENTS.md already mandates namespacing these; this test enforces it, so the
# hazard cannot creep back one pipe at a time.

MASKED_DPLYR_VERBS <- c("select", "filter")

test_that("no API source file calls a masked dplyr verb unqualified", {
  root <- get_api_dir()
  files <- list.files(
    file.path(root, c("functions", "services", "endpoints", "core")),
    pattern = "[.]R$", full.names = TRUE, recursive = TRUE
  )

  offenders <- list()
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    for (i in seq_along(lines)) {
      line <- lines[[i]]
      # Comment and roxygen lines are prose, not calls.
      if (grepl("^\\s*#", line)) next
      for (verb in MASKED_DPLYR_VERBS) {
        # Not preceded by ':' (already namespaced), a word character
        # (`post_db_filter(`), or '.' (`x.select(`).
        pattern <- paste0("(?<![:\\w.])", verb, "\\(")
        if (grepl(pattern, line, perl = TRUE)) {
          offenders[[length(offenders) + 1L]] <- sprintf(
            "%s:%d: %s", basename(f), i, trimws(line)
          )
        }
      }
    }
  }

  expect_equal(
    length(offenders), 0L,
    info = paste0(
      "Unqualified masked dplyr verb(s). Use dplyr::select() / dplyr::filter():\n",
      paste(utils::head(unlist(offenders), 20), collapse = "\n")
    )
  )
})

test_that("the guard actually detects a bare call", {
  # A guard that cannot fail is not a guard. Drive the same detection over a
  # synthetic line to prove the pattern matches what it claims to.
  detect <- function(line, verb) {
    grepl(paste0("(?<![:\\w.])", verb, "\\("), line, perl = TRUE)
  }
  expect_true(detect("  x %>% select(a, b) %>%", "select"))
  expect_true(detect("    filter(category == 'Definitive')", "filter"))
  expect_false(detect("  x %>% dplyr::select(a)", "select"))
  expect_false(detect("  x %>% dplyr::filter(a)", "filter"))
  # Must not fire on unrelated identifiers that merely end in the verb name.
  expect_false(detect("  post_db_filter(x)", "filter"))
  expect_false(detect("  generate_filter_expressions(x)", "filter"))
  expect_false(detect("  Filter(f, x)", "filter"))
})
