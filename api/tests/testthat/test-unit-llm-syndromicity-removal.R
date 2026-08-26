# The model-generated syndromicity is gone from the LLM contract (#630).
#
# A static scan, deliberately: the field must not creep back into the type spec,
# the generator prompt, the judge schema or the judge prompt. Reintroducing it
# anywhere reinstates a label that is not reproducible on identical input.

test_that("the LLM generation contract no longer produces syndromicity", {
  root <- get_api_dir()
  # Match the FIELD, not the word: "syndromic malformation" is a legitimate
  # clinical_pattern enum value and "non-syndromic" is legitimate prose
  # guidance. What must not exist is a syndromicity field in a type spec, a
  # read of summary$syndromicity, or a {syndromicity} prompt interpolation.
  forbidden <- c(
    "syndromicity = ellmer::",       # a field in a type_object
    "summary$syndromicity",          # applying a value onto the summary
    "$syndromicity",                 # any read of the field
    "{syndromicity}",                # a prompt template slot
    "{syndromicity_text}",
    "{syndromicity_terms}"
  )
  for (f in c("functions/llm-types.R", "functions/llm-judge.R",
              "functions/llm-judge-prompts.R")) {
    txt <- paste(readLines(file.path(root, f), warn = FALSE), collapse = "\n")
    for (needle in forbidden) {
      expect_false(
        grepl(needle, txt, fixed = TRUE),
        info = paste0(f, " still contains `", needle, "`")
      )
    }
  }
})

test_that("corrected_syndromicity is gone from the judge schema", {
  txt <- paste(readLines(file.path(get_api_dir(), "functions/llm-judge.R"),
                         warn = FALSE), collapse = "\n")
  expect_false(grepl("corrected_syndromicity = ellmer", txt, fixed = TRUE))
})

test_that("clinical_pattern is an enum in the type spec", {
  txt <- paste(readLines(file.path(get_api_dir(), "functions/llm-types.R"),
                         warn = FALSE), collapse = "\n")
  expect_match(txt, "clinical_pattern = ellmer::type_enum", fixed = TRUE)
})

test_that("the retired flat non-ID count is gone from the prompts", {
  for (f in c("functions/llm-types.R", "functions/llm-judge-prompts.R")) {
    txt <- paste(readLines(file.path(get_api_dir(), f), warn = FALSE),
                 collapse = "\n")
    expect_false(
      grepl("phenotype_non_id_count", txt, fixed = TRUE),
      info = paste(f, "still names the retired supplementary variable")
    )
  }
})

test_that("MCP no longer allowlists syndromicity in the LLM summary", {
  source_api_file("functions/mcp-readonly-contract.R", local = FALSE)
  expect_false("syndromicity" %in% mcp_readonly_llm_summary_json_keys())
  expect_true("clinical_pattern" %in% mcp_readonly_llm_summary_json_keys())
})

test_that("the prompt version is deliberately NOT bumped", {
  source_api_file("functions/llm-summary-config.R", local = FALSE)
  # #630 ships without regeneration: the retired field is stripped on read.
  # Bumping would 404 every cached summary AND empty the MCP projection.
  expect_equal(LLM_SUMMARY_PROMPT_VERSION, "1.0")
})
