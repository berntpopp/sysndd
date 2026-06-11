# SysNDD MCP — Search & Derived-Analysis Benchmark Fixes — Implementation Plan

**Date:** 2026-06-11
**Owner:** api / mcp
**Status:** safe subset implemented in this change; remainder = ordered backlog
**Design:** `.planning/superpowers/specs/2026-06-11-mcp-search-analysis-benchmark-fixes-design.md`
**Tracks:** GitHub issue #353

This plan orders the issue-#353 backlog by risk/value and records exactly what shipped in
this change vs what is deferred (and why). Effort is rough relative sizing, not hours.

## A. Shipped in this change (low-risk, well-defined, invariant-safe)

All four respect every MCP invariant (read-only, approved-public-data, `schema_version`
1.2, cache-hit-only). All are additive field additions or bugfixes to existing-field
serialization — no removals, no type changes, no new DB access patterns.

| # | Item (issue tag) | Change | Files | Risk | Effort | Test |
|---|------------------|--------|-------|------|--------|------|
| A1 | Null-as-`{}` (P1) | `structuredContent` is built from the null-safe JSON text (`mcp_structured_content()` round-trip) so nulls render as JSON `null`, mirroring `content[].text`. | `api/services/mcp-tools.R` | Low | S | unit + smoke |
| A2 | `publication_type` dropped (P1) | Top-level scalar promoted to first non-empty link value via `mcp_first_nonempty_value()`; per-link + aggregate fields unchanged. | `api/services/mcp-record-service.R`, `api/services/mcp-service.R` | Low | S | unit + smoke |
| A3 | Zero-result echo (P2) | `find_entities_by_*` always echo `meta$query_echo` + `meta$query_resolved`; `find_entities_by_disease` also echoes top-level `disease`. | `api/services/mcp-record-service.R` | Low | S | unit + smoke |
| A4 | Section-status consistency (P0 gap A) | `mcp_section_call()` collapses `{temporarily_unavailable, snapshot_missing, snapshot_stale, source_version_mismatch}` to `temporarily_unavailable`; specific code preserved in the section value. New `MCP_SECTION_UNAVAILABLE_CODES`. | `api/services/mcp-research-context-service.R` | Low | S | unit |

### Tests added/extended
- `api/tests/testthat/test-mcp-search-analysis-fixes.R` (new): null-serialization
  round-trip, `mcp_first_nonempty_value`, publication_type promotion, both zero-result
  echoes, section-status code mapping. (Host-runnable; mocks all DB access.)
- `api/scripts/mcp-smoke.R` (extended): zero-result `find_entities_by_disease` /
  `find_entities_by_phenotype` echo + `query_resolved`; `get_publication_context`
  top-level `publication_type` is never `{}` and `structuredContent` is present.

### Verification (host)
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-search-analysis-fixes.R')"` — pass.
- Regression: `test-mcp-service.R`, `test-mcp-search-ranking.R`,
  `test-mcp-snapshot-diagnostics.R`, `test-mcp-service-publication-discovery.R` — pass.
- `make lint-api`, `make code-quality-audit`.
- `mcp-smoke.R` runs against the stack in CI (do not start the stack locally).

## B. Deferred follow-ups (ordered by value / readiness)

### B1 — Search recall: disease synonyms (P0-quality, issue 3.1)
- **Why deferred:** the zero-hit defect is already fixed; this is recall *quality* and
  needs an approved-public disease-synonym source column + a defined ranking weight. No
  ambiguity-free safe edit exists today.
- **Plan:** confirm a synonym source on an approved-public view; extend the `disease`
  branch of `mcp_repo_search()` with a `synonym` tier (mirroring the existing HPO-synonym
  conditional pattern); add a smoke assertion for a known synonym query.
- **Risk:** medium (data-source choice + ranking). **Effort:** M.

### B2 — `find_entities_by_*` ranking + count-only mode (P2, issue 3.6)
- **Why deferred:** needs a ranking contract (category-strength ordering, optional
  modifier weighting) and a new `response_mode`/`aggregate` schema surface + smoke
  coverage.
- **Plan:** order by category strength then symbol; add `aggregate`/`count_only` returning
  per-category counts + totals without row payloads; update tool descriptions and
  capabilities; add tests.
- **Risk:** medium. **Effort:** M.

### B3 — Snapshot prewarm runbook + operator guidance (P0 gap B, issue 3.2)
- **Why deferred:** MCP must not initialize/compute caches (invariant). This is a
  deployment/ops decision about which snapshots ship prewarmed.
- **Plan:** document the snapshot-refresh job + which presets to prewarm in
  `documentation/09-deployment.qmd`; decide whether `snapshot_missing` + `retry_with` is
  sufficient operator guidance or a `needs_admin_initialization` synonym adds value
  (current recommendation: keep `snapshot_missing`, avoid error-code sprawl).
- **Risk:** low (docs/ops). **Effort:** S–M.

### B4 — Search fuzzy / typo tolerance (P0-quality, issue 3.1)
- **Why deferred:** needs a ranking design and a perf budget for fuzzy scans on the
  candidate set.
- **Plan:** evaluate trigram / edit-distance ranking on the already-bounded candidate set;
  gate behind a flag; benchmark latency.
- **Risk:** medium/high. **Effort:** M–L.

### B5 — `drop_diagonal`/`triangle_only` in `phenotype_functional_correlations` (P1-minor, 3.3)
- **Why deferred:** functional-correlations mode reads a fixed snapshot preset; threading
  the flags requires preset support.
- **Risk:** low. **Effort:** S.

### B6 — GRIN2A entity #303 phenotype gap (P3, issue 3.8)
- **Disposition:** curation-data issue, **not MCP code**. Flag for curator review via the
  curation backlog / issue comment. No MCP change.

## C. Risks & mitigations (shipped subset)

- **A1 re-serialization cost:** one `fromJSON(toJSON(...))` round-trip per tool call.
  Payloads are compact by default and bounded by `max_response_chars`; negligible.
  Fallback to raw payload on parse error keeps behavior safe.
- **A2 semantics:** top-level `publication_type` represents "a type present on the
  publication's links," not "the type for a specific entity." Per-link truth stays in
  `linked_entities[].publication_type` and `publication_types`. This matches how callers
  already consume the aggregate.
- **A3/A4 additive fields:** consumers using strict schemas are unaffected because the
  output schema is `additionalProperties = true` and `schema_version` is unchanged.
