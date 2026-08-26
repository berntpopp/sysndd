# The cluster-summary endpoint's #630 changes: the retired model-generated
# syndromicity is stripped on read, clinical_pattern is enumerated, and a
# disagreement between the two is surfaced rather than hidden.

source_api_file("functions/llm-endpoint-helpers.R", local = FALSE)

test_that("a stale LLM syndromicity key is stripped from a cached summary", {
  out <- llm_summary_strip_llm_syndromicity(list(
    summary = "text",
    syndromicity = "predominantly_id",
    clinical_pattern = "other"
  ))
  expect_null(out$syndromicity)
  expect_equal(out$summary, "text")
  expect_equal(out$clinical_pattern, "other")
})

test_that("stripping is a no-op on a summary that never had the key", {
  out <- llm_summary_strip_llm_syndromicity(list(summary = "text"))
  expect_equal(out, list(summary = "text"))
})

test_that("the vocabulary is exactly the five values the prompt names", {
  expect_setequal(LLM_CLINICAL_PATTERN_VOCABULARY, c(
    "syndromic malformation", "pure neurodevelopmental",
    "progressive metabolic/degenerative", "overgrowth syndrome", "other"
  ))
})

test_that("an in-vocabulary clinical_pattern passes through unchanged", {
  expect_equal(
    llm_summary_normalize_clinical_pattern("pure neurodevelopmental"),
    "pure neurodevelopmental"
  )
})

test_that("the observed production drift is aliased, not degraded to other", {
  # These exact strings are present in llm_cluster_summary_cache.
  expect_equal(
    llm_summary_normalize_clinical_pattern("progressive metabolic disorders"),
    "progressive metabolic/degenerative"
  )
  expect_equal(
    llm_summary_normalize_clinical_pattern("syndromic malformations"),
    "syndromic malformation"
  )
  expect_equal(
    llm_summary_normalize_clinical_pattern("overgrowth syndromes"),
    "overgrowth syndrome"
  )
})

test_that("an unrecognised clinical_pattern degrades to other", {
  expect_equal(llm_summary_normalize_clinical_pattern("something novel"), "other")
})

test_that("a missing clinical_pattern stays NULL rather than becoming other", {
  expect_null(llm_summary_normalize_clinical_pattern(NULL))
  expect_null(llm_summary_normalize_clinical_pattern(""))
  expect_null(llm_summary_normalize_clinical_pattern(character(0)))
})

test_that("a pattern contradicting the computed call is flagged", {
  expect_true(llm_summary_pattern_conflicts(
    "pure neurodevelopmental", list(cluster_call = "predominantly_syndromic")
  ))
  expect_true(llm_summary_pattern_conflicts(
    "syndromic malformation", list(cluster_call = "predominantly_isolated")
  ))
})

test_that("an agreeing or unrelated pattern is not flagged", {
  expect_false(llm_summary_pattern_conflicts(
    "syndromic malformation", list(cluster_call = "predominantly_syndromic")
  ))
  expect_false(llm_summary_pattern_conflicts(
    "pure neurodevelopmental", list(cluster_call = "mixed")
  ))
  expect_false(llm_summary_pattern_conflicts(
    "overgrowth syndrome", list(cluster_call = "predominantly_syndromic")
  ))
})

test_that("conflict detection is safe when either side is absent", {
  expect_false(llm_summary_pattern_conflicts(NULL, list(cluster_call = "mixed")))
  expect_false(llm_summary_pattern_conflicts("pure neurodevelopmental", NULL))
  expect_false(llm_summary_pattern_conflicts("pure neurodevelopmental", list()))
})

test_that("the validation scope names what the judge does NOT cover", {
  expect_match(LLM_VALIDATION_SCOPE, "Does NOT cover syndromicity")
})
