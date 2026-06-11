# SysNDD MCP — Search & Derived-Analysis Benchmark Fixes

**Date:** 2026-06-11
**Owner:** api / mcp
**Status:** spec — implemented safe subset; remainder planned as follow-ups
**Tracks:** GitHub issue #353
**Source review:** `.planning/reviews/2026-05-19-mcp-tool-benchmark.md` (branch `docs/mcp-tool-benchmark`; the issue body reproduces the backlog and is the authoritative defect list used here)

## 1. Problem

An expert benchmark of all 18 SysNDD MCP tools (NDD-researcher perspective) rated the
read-only sidecar 7.5/10. The retrieval layer is production-grade; the **search** and
**derived-analysis cache** layers carry concrete defects (issue #353). This document
specifies each defect against the *current* code, proposes a concrete fix, and records
risk/effort so the safe subset can ship now and the rest is planned.

Important context: the benchmark snapshot is dated **2026-05-19**. Several P0/P1 items
have already been substantially addressed in `master` since then (see §4 "Already
addressed"). This spec re-grounds every backlog item in the code as it exists on
2026-06-11 so we neither re-implement done work nor silently drop genuinely-open gaps.

## 2. Scope and invariants

Scope: the read-only MCP sidecar (`api/start_sysndd_mcp.R`) and its tool / repository
layer under `api/services/mcp-*.R` and `api/functions/mcp-*.R`, plus
`api/scripts/mcp-smoke.R`.

All changes preserve the MCP invariants in `AGENTS.md`:

- Read-only, approved-public-data only: active `ndd_entity_view` records; review-derived
  data only from primary approved reviews (`is_primary = 1 AND review_approved = 1`).
- No writes, no raw SQL/R, no Gemini/LLM generation, no live external providers, no
  draft-review / admin / user / job / log exposure.
- `MCP_SCHEMA_VERSION` stays `1.2`. Stable JSON text with `schema_version` is the
  compatibility contract. All changes here are **additive** (new optional fields,
  corrected serialization of existing fields) — no field removals, no type changes.
- Analysis tools remain cache-hit-only: public-ready snapshots or warmed cache only;
  never compute heavy analysis, fCoSE, external calls, or Gemini on miss.
- Recoverable failures keep the JSON tool-result error envelope
  (`schema_version` + `error.code` + `isError = true`).

## 3. Defect-by-defect specification

Each item lists: benchmark claim → current code reality → fix → schema/compat impact →
risk/effort → disposition (this change vs follow-up).

### 3.1 P0 — `search_sysndd` exact-match only

- **Claim:** `"NMDA receptor"` and `"epilepsy aphasia"` return 0 hits; gene `name` and
  disease synonyms are not searched.
- **Reality (current code):** `mcp_repo_search()` (`api/functions/mcp-repository.R:31`)
  already: searches gene `nal.name` (LIKE + `name` tier), HGNC alias/previous symbols via
  `hgnc_symbol_lookup`, disease names, HPO terms and (conditionally) `HPO_term_synonyms`,
  and variant names; and runs token-overlap matching via
  `mcp_search_token_filter()` / `mcp_search_tokens()`
  (`api/functions/mcp-search-repository.R`). `mcp_rank_search_candidates()` scores tiers
  on a 100–1000 scale and orders descending. The smoke test already asserts the
  `"NMDA receptor"` and `"epilepsy aphasia"` token + ranking behavior
  (`api/scripts/mcp-smoke.R:219-247`).
- **Fix:** None required for the core defect — it is already addressed. Remaining genuine
  gaps are *quality*, not *zero-hit*: (a) disease **synonym** columns beyond
  `HPO_term_synonyms` are not searched (disease search uses `result` /
  `disease_ontology_name` only); (b) there is no fuzzy / trigram matching for
  misspellings; (c) ranking weights are heuristic and unbenchmarked.
- **Compat:** N/A.
- **Risk/effort:** Synonym expansion — medium (needs to confirm an approved-public
  disease-synonym source column and a defined ranking). Fuzzy — medium/high (needs a
  ranking design and perf budget on `LIKE '%term%'` scans).
- **Disposition:** **Follow-up** (P1-quality). Document as "search recall improvements:
  disease synonyms + optional fuzzy" rather than "search is broken." Add a smoke
  assertion only once a synonym source is chosen.

### 3.2 P0 — Uninitialized analysis caches

- **Claim:** `get_gene_network_context` and `get_phenotype_analysis_context` modes
  `clusters` / `phenotype_functional_correlations` return bare `temporarily_unavailable`.
- **Reality (current code):** Focused tools no longer return bare
  `temporarily_unavailable`. They compute a snapshot status and raise the *specific*
  recoverable code `snapshot_missing` | `snapshot_stale` | `source_version_mismatch`
  via `mcp_stop_analysis_snapshot_unavailable()`
  (`api/services/mcp-analysis-service.R:382`), and the `dry_run` / `diagnostics` path
  short-circuits to a 200 payload exposing `section_status` + `meta$snapshot_status`
  (`mcp-analysis-service.R:432-451`, `538-555`). `unsupported_parameter` is raised for
  non-preset parameters. Capabilities/error docs include the snapshot codes (asserted in
  `test-mcp-search-ranking.R`).
- **Open gap A (consistency bug):** When these tools are reached *through*
  `get_gene_research_context`, `mcp_section_call()`
  (`api/services/mcp-research-context-service.R`) collapsed only
  `temporarily_unavailable` and `snapshot_missing` to a `temporarily_unavailable` section
  status; `snapshot_stale` and `source_version_mismatch` fell through to a generic
  `"error"` status — an inconsistency for the same logical "not serviceable yet" state.
- **Open gap B (operational):** Whether the network / cluster / functional-correlation
  snapshots are *prewarmed in the deployed sidecar* is a deployment decision, not MCP
  code. Per invariants, MCP must not initialize/compute caches. The actionable
  distinction the benchmark asks for ("`needs_admin_initialization` with operator
  guidance") is partly served by the existing `retry_with` recovery hint and the
  `snapshot_*` codes.
- **Fix (this change):** Gap A only — make `mcp_section_call()` collapse the full set
  `{temporarily_unavailable, snapshot_missing, snapshot_stale, source_version_mismatch}`
  to `temporarily_unavailable` for the section status, while preserving the specific
  `error.code` in the section value payload. New constant
  `MCP_SECTION_UNAVAILABLE_CODES`.
- **Compat:** Additive/behavioral-bugfix; section status values are unchanged in vocab
  (still `available` | `temporarily_unavailable` | `error`), just mapped consistently.
- **Risk/effort:** Low / small.
- **Disposition:** **This change** (Gap A). **Follow-up / ops doc** for Gap B: document
  the snapshot prewarm runbook in `documentation/09-deployment.qmd`; consider an
  operator-facing capabilities note that a code of `snapshot_missing` means "ask an admin
  to run the snapshot-refresh job," and evaluate whether a dedicated
  `needs_admin_initialization` synonym adds value over `snapshot_missing` + `retry_with`
  (leaning no, to avoid error-code sprawl).

### 3.3 P1 — Phenotype `correlations` is global-only but accepts an ignored `gene`

- **Claim:** correlations silently accepts an ignored `gene`; no `drop_diagonal` /
  `triangle_only`.
- **Reality (current code):** Already fixed. `mcp_get_phenotype_analysis_context()`
  **rejects** a `gene` in `correlations` mode with `invalid_input`
  (`mcp-analysis-service.R:410`), and `drop_diagonal` (default TRUE) / `triangle_only`
  (default FALSE) exist and are echoed in `meta` (`mcp-analysis-service.R:390-402`,
  `489-491`); the smoke test asserts both (`mcp-smoke.R:299-312`). The
  research-context path calls correlations without `gene`
  (`mcp-research-context-service.R`), so no silent-ignore occurs.
- **Open gap:** `drop_diagonal` / `triangle_only` are plumbed into `correlations` mode
  only, not into `phenotype_functional_correlations` mode (which hardcodes no
  triangle/diagonal). Minor.
- **Fix:** None required for the core defect. Optional follow-up: thread
  `drop_diagonal`/`triangle_only` into the functional-correlations snapshot reader if a
  preset supports it.
- **Disposition:** **Closed / follow-up (minor).**

### 3.4 P1 — `publication_type` dropped in publication context tools

- **Claim:** `publication_type` returns `{}` in `get_publication_context` /
  `get_publications_context` but is populated in `get_entity_context`.
- **Reality (current code):** The column is selected in both repository queries
  (`rpj.publication_type`). The defect is **record-shaping**: in
  `mcp_get_publication_context()` the top-level scalar is taken from
  `mcp_publication_record(mcp_row_to_list(rows[1, ]))`, i.e. the **first join row**.
  `publication_type` is a *per-link* attribute (it differs per linked entity, e.g.
  `Original` vs `Review`), so the first row can be SQL `NULL`, which `mcp_row_to_list()`
  maps to R `NULL`, which then renders as `{}` via the `structuredContent` path (§3.6).
  The per-link `linked_entities[].publication_type` and the `publication_types`
  aggregate are already correct.
- **Fix (this change):** Promote the top-level scalar to the **first non-empty** value
  across all link rows via a new helper `mcp_first_nonempty_value()`. Keep per-link and
  aggregate fields unchanged.
- **Compat:** Additive bugfix — same field, now reliably populated when any link carries
  a type.
- **Risk/effort:** Low / small.
- **Disposition:** **This change.**

### 3.5 P1 — Null-as-`{}` serialization

- **Claim:** null scalars serialize as `{}` (R/Plumber artifact) instead of JSON `null`.
- **Reality (current code):** The `content[].text` path already uses
  `jsonlite::toJSON(..., null = "null", na = "null")` and is correct. The `{}` artifact
  comes from `structuredContent = payload` (`api/services/mcp-tools.R:9`): the *raw R
  list* is serialized later by the `mcptools` HTTP transport, whose `toJSON` does **not**
  pass `null = "null"`, so an R `NULL` element renders as `{}`.
- **Fix (this change):** Build `structuredContent` from the already null-safe text by
  round-tripping `jsonlite::fromJSON(text, simplifyVector = FALSE)` (new helper
  `mcp_structured_content()`), so `structuredContent` mirrors `content[].text` exactly.
  Falls back to the raw payload on parse error.
- **Compat:** Bugfix only — corrects rendering of existing fields (`{}` → `null`); no
  schema change. `schema_version` stays `1.2`.
- **Risk/effort:** Low / small. One re-serialization per tool call (payloads are already
  bounded/compact by default).
- **Disposition:** **This change.**

### 3.6 P2 — `find_entities_by_*` ranking + count-only mode

- **Claim:** results are alphabetical (924 genes for "Seizures"); add relevance /
  category-strength ranking and an aggregate / count-only mode.
- **Reality (current code):** Confirmed — `mcp_repo_find_entities_by_phenotype` /
  `..._by_disease` order by `ev.symbol, ev.entity_id` with `LIMIT/OFFSET`, and there is
  no count-only / aggregate mode (only `meta$total`).
- **Fix (deferred):** (a) Add a category-strength ordering (Definitive > Moderate >
  Limited > …) before symbol, optionally weighted by phenotype-match modifier; (b) add an
  `aggregate` / `count_only` response mode returning per-category counts and gene/entity
  totals without row payloads. Both need a defined ranking contract + new schema fields
  and smoke coverage.
- **Compat:** Additive (new optional `response_mode`/`aggregate` param + new meta).
- **Risk/effort:** Medium / medium (ranking design + new param + tests).
- **Disposition:** **Follow-up.**

### 3.7 P2 — Zero-result echo

- **Claim:** `resolved_phenotypes` / `resolved_diseases` collapse to `[]` on zero matches;
  always echo the resolved term so callers distinguish invalid input from empty results.
- **Reality (current code):** Confirmed — both fields are derived from result rows, so
  they are `[]` on a miss, and `find_entities_by_disease` did not even echo the input
  `disease` at top level.
- **Fix (this change):** Always echo the requested term and a resolution flag:
  `meta$query_echo` (the requested term) and `meta$query_resolved` (boolean) on both
  tools, plus a top-level `disease` echo on `find_entities_by_disease` (parity with the
  existing top-level `phenotype` echo).
- **Compat:** Additive (new optional fields).
- **Risk/effort:** Low / small.
- **Disposition:** **This change.**

### 3.8 P3 — GRIN2A entity #303 phenotype gap

- **Claim:** entity #303 lacks a speech/language HPO term despite its synopsis/name.
- **Reality:** This is a **curation data** issue, not MCP code. MCP must not write or fix
  curated data.
- **Disposition:** **Out of scope for MCP code** — flag for curator review (issue
  comment / curation backlog).

## 4. Already addressed (verified on 2026-06-11, no code change)

- Search recall: gene `name`, HGNC alias/previous, disease names, HPO terms +
  (conditional) synonyms, token-overlap matching, descending tier ranking, zero-result
  guidance (`meta$zero_result_guidance`, `query_tokens`, `searched_types`).
- Phenotype `correlations`: rejects `gene`; has `drop_diagonal` / `triangle_only`.
- Analysis snapshot diagnostics: specific `snapshot_missing` / `snapshot_stale` /
  `source_version_mismatch` codes; `dry_run` / `diagnostics` preflight; `retry_with`
  recovery; `unsupported_parameter` for non-preset params.

## 5. Acceptance criteria mapping (issue #353)

- P0/P1 each have a concrete spec with behavior + schema/compat note → §3.
- MCP read-only / approved-public-data invariants preserved → §2; no repository query
  gate changed.
- `mcp-smoke.R` extended for search + analysis-availability regressions → zero-result
  echo + publication_type/structuredContent-null assertions added; existing NMDA /
  epilepsy / snapshot-diagnostics assertions retained.
- Tool descriptions / `get_sysndd_capabilities` updated where behavior changes → no tool
  *contract* changed; new fields are additive under `additionalProperties = true`, so no
  schema-doc churn is required. (Capabilities already document the snapshot error codes.)

## 6. Out of scope

- Snapshot prewarming / cache initialization in the deployed sidecar (deployment/ops).
- Search fuzzy matching and disease-synonym source selection (needs ranking design).
- `find_entities_by_*` relevance ranking + count-only mode (needs ranking contract).
- GRIN2A #303 curation fix (curation workflow, not MCP).
