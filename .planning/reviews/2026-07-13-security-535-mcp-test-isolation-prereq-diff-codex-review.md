# #535 MCP test-isolation prerequisite — Codex adversarial diff review

**Reviewer:** Codex `gpt-5.6-sol`, `model_reasoning_effort=xhigh`, read-only  
**Base:** `dfb6d8fc945a61ef82f4d4b144bc87154d8317e7`  
**Round:** 1  
**Verdict:** `SHIP`  
**BLOCKER/HIGH remaining:** no

## Prompt

> Perform a deep adversarial DIFF review of all current changes versus dfb6d8fc in this repository. Do not edit files. This is a narrowly scoped #535 prerequisite: test-only MCP test-order isolation repair; no production behavior changes. Inspect git diff and untracked files. Verify that the split from test-mcp-analysis-service.R to test-mcp-analysis-research-context.R preserves every moved test, both files explicitly source a safe fixture and run standalone, all modified global bindings are restored, and the regression test controls both phenotype cluster-cache availability and phenotype-functional-correlation public snapshot availability. Check hidden suite-order coupling, fixture auto-execution, path resolution, test count loss, and MCP read-only/security regressions. Classify every concrete finding BLOCKER/HIGH/MEDIUM/LOW with file and line. Treat planning documents as non-production. End exactly with Verdict: SHIP or Verdict: FIX-FIRST, followed by BLOCKER/HIGH remaining: yes or no.

## Findings

No concrete finding at any severity.

The reviewer independently established:

- The diff changes tests and planning records only; no production file changed.
- Test parity is exact: 29 tests and 123 expectations before and after; all nine moved research-context tests and all 36 expectations remain.
- Both test files explicitly source the fixture through `get_api_dir()`.
- The fixture preserves the original service source order and matches neither the `test-*` nor `helper-*` auto-discovery patterns.
- Every moved global stub is deferred back to its prior binding.
- The regression controls and restores both `mcp_analysis_repo_phenotype_cluster_cache_hit` and `mcp_analysis_repo_public_snapshot_available`.
- The new test file participates in fast and full CI discovery.
- No MCP read-only, approved-public, generation, external-call, or data-exposure behavior changed.
- Static diff whitespace checks passed.

The read-only reviewer could not run R or Docker inside its sandbox. Runtime evidence was produced independently before review: the contaminated preload reproduction passed 36/36 after the fix, both standalone test files passed 87/87 and 36/36, and `make test-api-fast` completed with 6,224 passes and zero failures.

## Final reviewer text

> Verdict: SHIP  
> BLOCKER/HIGH remaining: no
