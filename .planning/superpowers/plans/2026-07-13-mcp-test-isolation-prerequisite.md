# MCP Test Isolation Prerequisite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the MCP research-context dry-run test deterministic regardless of earlier global database stubs or live public snapshot rows, without changing production behavior.

**Architecture:** Split the coherent gene research-context tests out of the oversized MCP analysis service test into a standalone test file. Put shared source/setup functions in an explicitly sourced fixture so both test files remain independently runnable, then isolate the failing test by stubbing every repository availability probe it asserts.

**Tech Stack:** R, testthat, withr, SysNDD MCP read-only services and repositories.

---

### Task 1: Capture the test-order regression

**Files:**
- Create: `api/tests/testthat/test-mcp-analysis-research-context.R`
- Create: `api/tests/testthat/mcp-analysis-service-fixtures.R`
- Modify: `api/tests/testthat/test-mcp-analysis-service.R`

- [ ] **Step 1: Add the explicit fixture and split the coherent research-context block**

Create `mcp-analysis-service-fixtures.R` with source helpers shared by the analysis-service and research-context files. Explicitly source it from both tests using `get_api_dir()` and move the tests from `gene research context aggregates requested sections...` through `gene research marks budget-dropped sections...` unchanged into `test-mcp-analysis-research-context.R`.

- [ ] **Step 2: Run both split files standalone**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R'); testthat::test_file('tests/testthat/test-mcp-analysis-research-context.R')"
```

Expected: both files load their fixture explicitly and preserve the existing standalone test behavior.

- [ ] **Step 3: Capture RED with the known preload order**

Run the research-context file after preloading `db_execute_query` so `mcp_analysis_repo_public_snapshot_available()` observes an available functional-correlation snapshot:

```bash
cd api
Rscript --no-init-file -e "assign('db_execute_query', function(query, params = list(), conn = NULL) tibble::tibble(snapshot_id = 1L, source_data_version = 'source-v1', stale_after = Sys.time() + 3600), envir = .GlobalEnv); assign('analysis_snapshot_source_data_version', function(...) NULL, envir = .GlobalEnv); testthat::test_file('tests/testthat/test-mcp-analysis-research-context.R')"
```

Expected: FAIL at `phenotype_functional_correlations`, actual `available` instead of `temporarily_unavailable`.

### Task 2: Isolate every asserted availability dependency

**Files:**
- Modify: `api/tests/testthat/test-mcp-analysis-research-context.R`

- [ ] **Step 1: Add the minimal missing stub**

In `gene research dry-run reports phenotype cache unavailability explicitly`, save, replace, and defer restoration of `mcp_analysis_repo_public_snapshot_available` alongside `mcp_analysis_repo_phenotype_cluster_cache_hit`. The test stub must return `FALSE` so all three asserted unavailable statuses are controlled locally.

- [ ] **Step 2: Verify GREEN under the preload reproduction**

Re-run the exact preload command from Task 1. Expected: all research-context tests PASS with zero failures and zero skips.

- [ ] **Step 3: Re-run both split files standalone**

Run the two-file command from Task 1. Expected: both files PASS with zero failures and zero skips.

### Task 3: Verify repository gates and review the diff

**Files:**
- Create: `.planning/reviews/2026-07-13-security-535-mcp-test-isolation-prereq-diff-codex-review.md`

- [ ] **Step 1: Check file size and diff hygiene**

Run:

```bash
wc -l api/tests/testthat/test-mcp-analysis-service.R api/tests/testthat/test-mcp-analysis-research-context.R api/tests/testthat/mcp-analysis-service-fixtures.R
git diff --check
make code-quality-audit
```

Expected: every touched handwritten test/fixture file is below 600 lines and all commands exit 0.

- [ ] **Step 2: Run API gates**

Run:

```bash
make lint-api
make test-api-fast
```

Expected: both commands exit 0; the API lane reports zero failures and does not mistake skips for passes.

- [ ] **Step 3: Run deep adversarial Codex DIFF review**

Execute Codex detached against the branch diff from `dfb6d8fc`, poll to completion, record the exact prompt, findings, verdict, and rounds in `.planning/reviews/2026-07-13-security-535-mcp-test-isolation-prereq-diff-codex-review.md`. Fix every BLOCKER/HIGH and cheap MEDIUM/LOW, rerunning verification after edits, until no BLOCKER/HIGH remains.

- [ ] **Step 4: Commit and publish only after fresh evidence**

Run `git status -sb`, commit the test-only prerequisite, push `fix/535-mcp-test-isolation-prereq`, and open a PR whose body explains the prerequisite scope but contains no closing keyword for #550, #551, or #535.
