# tests/testthat/test-unit-llm-judge-prompt.R
#
# Unit tests for the #448 phenotype-judge robustness changes:
# - verdict type advertises corrected_summary
# - apply_judge_corrections() applies (or skips) corrected_summary + other fields
# - the phenotype judge prompt allows grounded clinical synthesis and prefers
#   accept_with_corrections over a hard reject for isolated molecular phrasing,
#   while keeping the severe-error hard rejects
# - the phenotype generation prompt permits grounded gestalt synthesis
#
# Requires ellmer (the verdict type is built at source time) -> run in the API
# container: docker exec sysndd-api-1 Rscript -e \
#   "testthat::test_file('/app/tests/testthat/test-unit-llm-judge-prompt.R')"

source_api_file("functions/llm-judge.R", local = FALSE)
source_api_file("functions/llm-judge-prompts.R", local = FALSE)
source_api_file("functions/llm-types.R", local = FALSE)

# --- Task 1: verdict type gains corrected_summary ---------------------------

test_that("verdict type advertises corrected_summary", {
  props <- names(llm_judge_verdict_type@properties)
  expect_true("corrected_summary" %in% props)
  # existing fields preserved
  expect_true(all(c("verdict", "reasoning", "corrected_tags") %in% props))
})

# --- Task 2: apply_judge_corrections ----------------------------------------

test_that("apply_judge_corrections rewrites main summary when corrected_summary given", {
  base <- list(
    summary = "Genes involved in synaptic signaling drive mild ID.",
    tags = c("a")
  )
  verdict <- list(
    corrections_needed = TRUE,
    corrected_summary = "Mild intellectual disability with macrocephaly and behavioral abnormality.",
    corrections_made = c("Removed molecular phrasing from summary")
  )
  out <- apply_judge_corrections(base, verdict)
  expect_equal(out$summary, "Mild intellectual disability with macrocephaly and behavioral abnormality.")
  expect_true(isTRUE(out$corrections_applied))
  expect_equal(out$corrections_made, c("Removed molecular phrasing from summary"))
})

test_that("apply_judge_corrections leaves summary intact when no corrected_summary", {
  base <- list(summary = "Original summary", tags = c("a"))
  verdict <- list(corrections_needed = TRUE, corrected_tags = c("b", "c"))
  out <- apply_judge_corrections(base, verdict)
  expect_equal(out$summary, "Original summary")
  expect_equal(out$tags, c("b", "c"))
})

test_that("apply_judge_corrections is a no-op when corrections_needed is FALSE", {
  base <- list(summary = "Original", tags = c("a"))
  verdict <- list(corrections_needed = FALSE, corrected_summary = "should be ignored")
  out <- apply_judge_corrections(base, verdict)
  expect_equal(out$summary, "Original")
  expect_null(out$corrections_applied)
})

test_that("apply_judge_corrections ignores blank corrected_summary", {
  base <- list(summary = "Original", tags = c("a"))
  verdict <- list(corrections_needed = TRUE, corrected_summary = "   ")
  out <- apply_judge_corrections(base, verdict)
  expect_equal(out$summary, "Original")
})

# --- Task 3: phenotype judge prompt is less brittle but keeps hard rejects ---

test_that("phenotype judge prompt allows grounded synthesis + correction path", {
  p <- build_phenotype_judge_prompt(
    summary = list(summary = "x", confidence = "low"),
    cluster_data = list(identifiers = data.frame(entity_id = 1:3))
  )
  # new, softer behavior
  expect_match(p, "grounded clinical synthesis", fixed = TRUE)
  expect_match(p, "corrected_summary", fixed = TRUE)
  expect_match(p, "accept_with_corrections", fixed = TRUE)
  # hard rejects still present
  expect_match(p, "Direction inversion", ignore.case = TRUE)
  expect_match(p, "Grounding score < 50%", fixed = TRUE)
})

# --- #490: large-cluster judge relaxation -----------------------------------

test_that("phenotype judge prompt adds a relaxed-bar instruction for LARGE clusters", {
  big <- build_phenotype_judge_prompt(
    summary = list(summary = "x", confidence = "low"),
    cluster_data = list(identifiers = data.frame(entity_id = seq_len(1043)))
  )
  small <- build_phenotype_judge_prompt(
    summary = list(summary = "x", confidence = "low"),
    cluster_data = list(identifiers = data.frame(entity_id = 1:5))
  )
  # Large, heterogeneous cluster -> relaxed, high-level GESTALT bar is present.
  expect_match(big, "RELAXED BAR", fixed = TRUE)
  expect_match(big, "HIGH-LEVEL GESTALT", fixed = TRUE)
  # Normal-sized clusters keep the strict bar (no relaxation note).
  expect_false(grepl("RELAXED BAR", small, fixed = TRUE))
})

# --- Task 4: generation prompt permits grounded gestalt synthesis -----------

test_that("phenotype generation prompt permits grounded gestalt synthesis", {
  cd <- list(
    quali_inp_var = data.frame(
      variable = c("Macrocephaly", "Intellectual disability, mild", "Behavioral abnormality"),
      `v.test` = c(3.6, 6.4, 4.15),
      `p.value` = c(0.01, 0.001, 0.005),
      check.names = FALSE
    ),
    identifiers = data.frame(entity_id = 1:5)
  )
  p <- build_phenotype_cluster_prompt(cd)
  expect_match(p, "synthesize", ignore.case = TRUE)
  # the molecular guardrails must remain intact
  expect_match(p, "MUST NOT", fixed = TRUE)
})
