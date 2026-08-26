# The LLM prompt version is pinned in TWO places, and they must agree (#630).
#
# `LLM_SUMMARY_PROMPT_VERSION` (R) is bound into every cache lookup, and the
# `mcp_public_llm_cluster_summary` view pins a version literal in SQL while
# mcp-analysis-repository.R independently filters that view by the R constant.
# Bumping one without the other makes the intersection EMPTY: the MCP sidecar
# returns zero summaries, silently. This test turns the next legitimate bump
# into a loud failure instead of an outage.

source_api_file("functions/llm-summary-config.R", local = FALSE)

test_that("the R prompt version matches the version pinned in the MCP view", {
  migrations <- list.files(
    file.path(dirname(get_api_dir()), "db", "migrations"),
    pattern = "[.]sql$", full.names = TRUE
  )
  # The latest migration that (re)defines the view is the authority.
  defining <- Filter(function(f) {
    grepl("VIEW `mcp_public_llm_cluster_summary`",
          paste(readLines(f, warn = FALSE), collapse = "\n"), fixed = TRUE)
  }, migrations)
  expect_gt(length(defining), 0)

  latest <- sort(defining)[length(defining)]
  txt <- paste(readLines(latest, warn = FALSE), collapse = "\n")
  pinned <- regmatches(
    txt, regexpr("`prompt_version`\\s*=\\s*'([^']+)'", txt, perl = TRUE)
  )
  version <- sub(".*'([^']+)'.*", "\\1", pinned)

  expect_equal(
    version, LLM_SUMMARY_PROMPT_VERSION,
    info = paste0(
      "LLM_SUMMARY_PROMPT_VERSION is '", LLM_SUMMARY_PROMPT_VERSION,
      "' but ", basename(latest), " pins '", version, "'. Bumping the R ",
      "constant requires a migration that recreates the view with the new ",
      "version, or MCP serves nothing."
    )
  )
})

test_that("the MCP view no longer projects the retired syndromicity key", {
  migrations <- sort(list.files(
    file.path(dirname(get_api_dir()), "db", "migrations"),
    pattern = "[.]sql$", full.names = TRUE
  ))
  defining <- Filter(function(f) {
    grepl("VIEW `mcp_public_llm_cluster_summary`",
          paste(readLines(f, warn = FALSE), collapse = "\n"), fixed = TRUE)
  }, migrations)
  latest <- defining[length(defining)]
  txt <- paste(readLines(latest, warn = FALSE), collapse = "\n")
  # Only the JSON_OBJECT projection matters; the explanatory header may mention
  # the word.
  projection <- sub(".*JSON_OBJECT\\((.*?)\\) AS `summary_json`.*", "\\1", txt)
  expect_false(grepl("'syndromicity'", projection, fixed = TRUE))
})
