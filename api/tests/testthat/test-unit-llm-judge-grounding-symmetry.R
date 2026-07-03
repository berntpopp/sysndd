# tests/testthat/test-unit-llm-judge-grounding-symmetry.R
#
# Regression guard (#495): the phenotype LLM-judge must ground against the SAME
# enriched/depleted phenotype set the generator saw. The old judge prompt
# truncated to the top-15 by |v.test|; for the largest cluster (the "pure ID +
# seizures" cluster, 1043 entities) the top-15 are dominated by strong
# DEPLETIONS (heart/genitourinary/skeletal/... all absent), so genuinely
# ENRICHED, cluster-defining phenotypes — Seizures (+8.18), Behavioral (+7.71),
# ID-profound (+8.20), Microcephaly (+4.11) — fall to rank #17+ and disappear
# from the judge's "authoritative source". The judge then flags them as
# "fabricated specific phenotypes" and HARD-REJECTS a correctly-grounded
# summary. The fix: show ENRICHED and DEPLETED separately (mirroring the
# generator) so enriched terms are never crowded out by larger-|v.test|
# depletions.
#
# Pure glue builder (no ellmer / DB / network) — runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-llm-judge-grounding-symmetry.R')"

library(testthat)

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

suppressWarnings(suppressMessages({
  source_api_file("functions/llm-judge-prompts.R", local = FALSE)
}))

# Faithful subset of the real production cluster-2 (1043 entities) quali_inp_var.
# 14 depletions with |v.test| > 8.18 push the enriched Seizures (+8.18),
# ID-profound (+8.20), Behavioral (+7.71) and Microcephaly (+4.11) out of a
# top-15-by-|v.test| window.
cluster2_quali_inp_var <- data.frame(
  variable = c(
    # enriched (positive v.test) — the cluster's true defining phenotypes
    "Intellectual disability, severe", "Intellectual disability, moderate",
    "Intellectual disability, profound", "Seizures", "Behavioral abnormality",
    "Intellectual disability, mild", "Microcephaly",
    # depleted (negative v.test) — dominate the |v.test| ranking
    "Abnormal heart morphology", "Abnormality of the genitourinary system",
    "Abnormality of the skeletal system", "Age of death", "Hearing impairment",
    "Progressive", "Abnormality of the kidney",
    "Abnormality of metabolism/homeostasis", "Abnormality of the eye",
    "Abnormality of the integument", "Abnormality of the mitochondrion",
    "Short stature", "Oral cleft"
  ),
  `v.test` = c(
    12.53, 10.24, 8.20, 8.18, 7.71, 5.82, 4.11,
    -13.78, -13.35, -12.38, -12.16, -11.81, -11.79, -11.32,
    -10.70, -9.95, -9.71, -9.41, -9.25, -8.84
  ),
  `p.value` = 1e-10,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

cluster2_summary <- list(
  summary = paste(
    "A large, predominantly non-syndromic (isolated) intellectual disability",
    "cluster, enriched for seizures and microcephaly, with a striking depletion",
    "of extra-CNS malformations."
  ),
  key_phenotype_themes = c("Intellectual disability", "Seizures", "Microcephaly"),
  tags = c("intellectual disability", "seizures", "behavioral", "microcephaly"),
  confidence = "medium"
)

judge_prompt <- build_phenotype_judge_prompt(
  summary = cluster2_summary,
  cluster_data = list(
    identifiers = data.frame(entity_id = seq_len(1043)),
    quali_inp_var = cluster2_quali_inp_var
  )
)

# Match the DATA-DERIVED phenotype line ("- {variable}: v.test=... [DIRECTION]"),
# not the judge prompt's static instructional examples (which also say "Seizures").
prompt_lines <- strsplit(judge_prompt, "\n", fixed = TRUE)[[1]]
data_line_for <- function(term) {
  hit <- prompt_lines[grepl(paste0(term, ": v.test="), prompt_lines, fixed = TRUE)]
  if (length(hit) == 0L) NA_character_ else hit[1]
}

test_that("enriched phenotypes outside the top-15 |v.test| are still shown to the judge as data", {
  # Seizures (+8.18, rank ~#18), Behavioral (+7.71), Microcephaly (+4.11) are
  # genuinely ENRICHED and must appear as grounding data so the judge does not
  # falsely flag them as fabricated.
  expect_false(is.na(data_line_for("Seizures")))
  expect_false(is.na(data_line_for("Behavioral abnormality")))
  expect_false(is.na(data_line_for("Microcephaly")))
})

test_that("Seizures is presented to the judge as ENRICHED, not depleted", {
  seizure_line <- data_line_for("Seizures")
  expect_false(is.na(seizure_line))
  expect_match(seizure_line, "ENRICHED", fixed = TRUE)
})

test_that("strong depletions remain visible to the judge as data", {
  heart_line <- data_line_for("Abnormal heart morphology")
  gu_line <- data_line_for("Abnormality of the genitourinary system")
  expect_false(is.na(heart_line))
  expect_false(is.na(gu_line))
  expect_match(heart_line, "DEPLETED", fixed = TRUE)
})
