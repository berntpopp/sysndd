---
phase: quick
plan: 001
type: execute
wave: 1
depends_on: []
files_modified:
  - api/tests/testthat/test-llm-benchmark.R
  - api/tests/testthat/fixtures/llm-benchmark-ground-truth.json
autonomous: true

must_haves:
  truths:
    - "Benchmark tests can load ground truth data for all 6 functional and 5 phenotype clusters"
    - "Tests can generate summaries using actual LLM prompts and score against ground truth"
    - "Tests report accuracy scores on 1-10 scale matching Phase 63 methodology"
  artifacts:
    - path: "api/tests/testthat/test-llm-benchmark.R"
      provides: "LLM benchmark test suite"
      min_lines: 150
    - path: "api/tests/testthat/fixtures/llm-benchmark-ground-truth.json"
      provides: "Ground truth data for all clusters"
  key_links:
    - from: "test-llm-benchmark.R"
      to: "llm-service.R"
      via: "build_cluster_prompt, build_phenotype_cluster_prompt"
      pattern: "build_.*_prompt"
---

<objective>
Create reusable LLM prompt benchmark test scripts with ground truth data for functional and phenotype cluster summaries.

Purpose: Enable repeatable testing of LLM prompt quality by comparing generated summaries against known-correct ground truth data, using the same 1-10 scoring methodology from Phase 63.

Output:
- `test-llm-benchmark.R` - Benchmark test suite with skip_if_no_gemini() guard
- `llm-benchmark-ground-truth.json` - Ground truth data for all clusters
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PHASE_63_LLM_PIPELINE_FINAL.md

# Key source files for understanding prompt structure
@api/functions/llm-service.R (build_cluster_prompt, build_phenotype_cluster_prompt)
@api/functions/llm-judge.R (build_functional_judge_prompt, build_phenotype_judge_prompt)

# Existing test patterns to follow
@api/tests/testthat/test-llm-batch.R
@api/tests/testthat/test-llm-judge.R
@api/tests/testthat/test-llm-validation.R
@api/tests/testthat/helper-db.R
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create ground truth fixture data</name>
  <files>api/tests/testthat/fixtures/llm-benchmark-ground-truth.json</files>
  <action>
Create JSON fixture file with ground truth data for benchmark testing.

Structure:
```json
{
  "functional_clusters": {
    "1": {
      "name": "Developmental/Growth Signaling",
      "ground_truth_pathways": ["PI3K-Akt signaling pathway", "Ras signaling pathway", "Pathways in cancer"],
      "ground_truth_themes": ["growth signaling", "developmental regulation", "cancer pathways"],
      "expected_confidence": "high",
      "phase_63_score": 10,
      "notes": "From Phase 63 benchmark - all pathways verbatim from KEGG"
    },
    "3": {
      "name": "Chromatin/Epigenetic",
      "ground_truth_pathways": ["Lysine degradation", "Cell cycle"],
      "ground_truth_themes": ["chromatin remodeling", "histone modification", "cell cycle"],
      "expected_confidence": "high",
      "phase_63_score": 10,
      "notes": "From Phase 63 benchmark - pathways verbatim"
    }
    // ... clusters 2, 4, 5, 6 with placeholder data to be filled from actual database
  },
  "phenotype_clusters": {
    "3": {
      "name": "Progressive/Metabolic",
      "ground_truth_phenotypes_enriched": ["Progressive", "early mortality", "mitochondrial", "metabolic", "regression"],
      "ground_truth_phenotypes_depleted": [],
      "expected_clinical_pattern": "progressive metabolic/degenerative",
      "expected_confidence": "high",
      "phase_63_score": 10,
      "notes": "From Phase 63 benchmark - strictly clinical terms only"
    },
    "4": {
      "name": "Syndromic Malformations",
      "ground_truth_phenotypes_enriched": ["genitourinary", "kidney", "skeletal", "oral cleft", "heart abnormalities"],
      "ground_truth_phenotypes_depleted": [],
      "expected_clinical_pattern": "syndromic malformation",
      "expected_confidence": "high",
      "phase_63_score": 9,
      "notes": "From Phase 63 benchmark"
    }
    // ... clusters 1, 2, 5 with placeholder data
  },
  "scoring_criteria": {
    "description": "1-10 scale rating summaries against ground truth",
    "thresholds": {
      "excellent": {"min": 9, "description": "All terms verbatim, no hallucinations"},
      "good": {"min": 7, "description": "Minor generalizations, no fabrications"},
      "acceptable": {"min": 5, "description": "Some inaccuracies but core themes correct"},
      "poor": {"min": 1, "description": "Significant hallucinations or missing themes"}
    }
  }
}
```

Include documented ground truth from Phase 63:
- Functional Cluster 1: PI3K-Akt, Ras, Pathways in cancer (scored 10/10)
- Functional Cluster 3: Lysine degradation, Cell cycle (scored 10/10)
- Phenotype Cluster 3: Progressive, early mortality, mitochondrial, metabolic, regression (scored 10/10)
- Phenotype Cluster 4: Genitourinary, kidney, skeletal, oral cleft, heart abnormalities (scored 9/10)

For remaining clusters (2, 4, 5, 6 functional; 1, 2, 5 phenotype), add placeholder entries with `"ground_truth_pending": true` flag.
  </action>
  <verify>
```bash
cat api/tests/testthat/fixtures/llm-benchmark-ground-truth.json | jq '.functional_clusters | keys'
cat api/tests/testthat/fixtures/llm-benchmark-ground-truth.json | jq '.phenotype_clusters | keys'
```
Should show cluster IDs for both types.
  </verify>
  <done>Ground truth JSON file exists with Phase 63 documented clusters and placeholders for remaining clusters.</done>
</task>

<task type="auto">
  <name>Task 2: Create LLM benchmark test suite</name>
  <files>api/tests/testthat/test-llm-benchmark.R</files>
  <action>
Create comprehensive benchmark test file following existing test patterns.

Key components:

1. **Skip helpers:**
```r
skip_if_no_gemini <- function() {
  skip_if(!exists("is_gemini_configured", mode = "function") || !is_gemini_configured(),
          "GEMINI_API_KEY not configured")
}
```

2. **Ground truth loading:**
```r
load_benchmark_ground_truth <- function() {
  fixture_path <- testthat::test_path("fixtures", "llm-benchmark-ground-truth.json")
  if (!file.exists(fixture_path)) {
    stop("Ground truth fixture not found: ", fixture_path)
  }
  jsonlite::fromJSON(fixture_path, simplifyVector = FALSE)
}
```

3. **Scoring function:**
```r
score_functional_summary <- function(summary, ground_truth) {
  # Score 1-10 based on:
  # - Pathway accuracy (verbatim matches from ground_truth_pathways)
  # - Theme coverage (overlap with ground_truth_themes)
  # - No hallucinated pathways (not in ground truth)
  # Returns list(score, reasoning, details)
}

score_phenotype_summary <- function(summary, ground_truth) {
  # Score 1-10 based on:
  # - Phenotype accuracy (terms from ground_truth_phenotypes_enriched)
  # - No molecular/gene terms present
  # - Clinical pattern matches expected
  # Returns list(score, reasoning, details)
}
```

4. **Test structure:**
- `test_that("ground truth fixture loads correctly", {...})` - Unit test
- `test_that("functional cluster 1 benchmark", {...})` - Integration test with skip_if_no_gemini
- `test_that("functional cluster 3 benchmark", {...})` - Integration test
- `test_that("phenotype cluster 3 benchmark", {...})` - Integration test
- `test_that("phenotype cluster 4 benchmark", {...})` - Integration test
- `test_that("batch benchmark summary", {...})` - Optional aggregated results

5. **Mock cluster data creation:**
```r
create_mock_functional_cluster <- function(cluster_number) {
  # Create minimal cluster_data structure for prompt building
  # Must include: identifiers (tibble), term_enrichment (tibble with KEGG/GO terms)
}

create_mock_phenotype_cluster <- function(cluster_number) {
  # Create minimal cluster_data structure for phenotype prompts
  # Must include: identifiers (tibble), quali_inp_var (tibble with v.test, p.value)
}
```

6. **Integration tests pattern:**
```r
test_that("functional cluster 1 achieves benchmark score >= 8", {
  skip_if_no_gemini()

  ground_truth <- load_benchmark_ground_truth()
  cluster_gt <- ground_truth$functional_clusters[["1"]]

  # Skip if ground truth not yet defined
  skip_if(isTRUE(cluster_gt$ground_truth_pending), "Ground truth pending for cluster 1")

  # Create mock cluster data with known enrichment terms
  cluster_data <- create_mock_functional_cluster_from_ground_truth(cluster_gt)

  # Generate summary using actual prompts
  result <- generate_cluster_summary(cluster_data, cluster_type = "functional")

  expect_true(result$success)

  # Score against ground truth
  score_result <- score_functional_summary(result$summary, cluster_gt)

  # Log score for reporting
  message(sprintf("Cluster 1 score: %d/10 - %s", score_result$score, score_result$reasoning))

  # Assert minimum benchmark score
  expect_gte(score_result$score, 8,
             info = paste("Benchmark failed:", score_result$reasoning))
})
```

Follow patterns from existing test-llm-*.R files:
- Use testthat::test_that()
- Use skip_if_no_gemini() guard for API-dependent tests
- Keep mock data creation separate from test logic
- Log results with message() for visibility in test output
  </action>
  <verify>
```bash
# Syntax check
Rscript -e "parse('api/tests/testthat/test-llm-benchmark.R')"

# Run only the unit tests (no Gemini required)
cd api && Rscript -e "testthat::test_file('tests/testthat/test-llm-benchmark.R', filter='ground truth')"
```
  </verify>
  <done>
- test-llm-benchmark.R exists with scoring functions and test structure
- Unit tests for ground truth loading pass without API key
- Integration tests properly skip when GEMINI_API_KEY not set
  </done>
</task>

<task type="auto">
  <name>Task 3: Validate benchmark tests work end-to-end</name>
  <files>api/tests/testthat/test-llm-benchmark.R</files>
  <action>
Verify the complete benchmark test flow:

1. **Run unit tests (no API needed):**
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-llm-benchmark.R', filter='fixture|ground truth')"
```
Expect: Tests pass, ground truth loads correctly.

2. **Check skip behavior when no API key:**
```bash
cd api && GEMINI_API_KEY="" Rscript -e "testthat::test_file('tests/testthat/test-llm-benchmark.R')"
```
Expect: Integration tests skip with "GEMINI_API_KEY not configured" message.

3. **Add documentation header to test file:**
```r
# Test file: test-llm-benchmark.R
# LLM prompt benchmark tests with ground truth comparison
#
# Purpose: Validate LLM prompt quality by comparing generated summaries
# against known-correct ground truth data from Phase 63 validation.
#
# Usage:
#   # Run all benchmark tests (requires GEMINI_API_KEY)
#   testthat::test_file('tests/testthat/test-llm-benchmark.R')
#
#   # Run only unit tests (no API key needed)
#   testthat::test_file('tests/testthat/test-llm-benchmark.R', filter='fixture')
#
# Ground truth source: .planning/PHASE_63_LLM_PIPELINE_FINAL.md
```

4. **Verify fixture directory exists:**
```bash
ls -la api/tests/testthat/fixtures/
```
Create if missing: `mkdir -p api/tests/testthat/fixtures`
  </action>
  <verify>
```bash
# Full validation
cd /home/bernt-popp/development/sysndd/api && \
  Rscript -e "testthat::test_file('tests/testthat/test-llm-benchmark.R')" 2>&1 | head -50
```
Should show:
- Unit tests passing
- Integration tests skipping (if no API key) or passing with scores
  </verify>
  <done>
- All unit tests pass without API key
- Integration tests properly skip or pass based on GEMINI_API_KEY
- Test output shows scores for completed benchmarks
  </done>
</task>

</tasks>

<verification>
1. Ground truth fixture exists and is valid JSON: `jq '.' api/tests/testthat/fixtures/llm-benchmark-ground-truth.json`
2. Test file parses without errors: `Rscript -e "parse('api/tests/testthat/test-llm-benchmark.R')"`
3. Unit tests pass: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-llm-benchmark.R', filter='fixture')"`
4. Integration tests skip gracefully without API key
</verification>

<success_criteria>
- test-llm-benchmark.R exists with scoring functions matching Phase 63 methodology
- llm-benchmark-ground-truth.json contains documented ground truth from Phase 63
- Unit tests pass without GEMINI_API_KEY
- Integration tests properly skip when GEMINI_API_KEY not set
- When run with API key, benchmarks report scores on 1-10 scale
</success_criteria>

<output>
After completion, create `.planning/quick/001-llm-benchmark-test-scripts/001-SUMMARY.md`
</output>
