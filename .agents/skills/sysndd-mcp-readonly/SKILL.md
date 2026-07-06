---
name: sysndd-mcp-readonly
description: Use when changing the SysNDD read-only MCP sidecar, its tools, repositories, resources, capabilities, schema version, or anything the MCP layer reads or exposes — especially when a product requirement would have MCP write, generate, fetch externally, or surface non-public data
---

# SysNDD MCP Read-Only Contract

Use this skill before changing the MCP sidecar (`api/start_sysndd_mcp.R`, `api/services/mcp-*.R`, `api/functions/mcp-*.R`). MCP v1 is a **separate, read-only process serving approved public data only**. The contract is safety-critical: violating it can leak curation-in-progress or misrepresent data to LLM clients.

## Hard Invariants — MCP MUST NOT

- Write the DB, call write routes, or execute raw SQL / raw R.
- Call Gemini or any LLM **generation**. Summaries are **cache-hit-only, admin-generated** reads (`require_validated = TRUE`).
- Call live external gene providers. Stored external IDs may be shown **only** as `external_reference_identifier`.
- Expose draft reviews, re-review workflows, admin/user/log/job data, curation comments, or broad export payloads.

When a product ask conflicts with these (e.g. "include the latest review even if unapproved", "generate a summary on cache miss", "present NDDScore as the authoritative classification"), **the invariant wins.** Implement the compliant framing and push the extra need to the authenticated main API (Curator+) or an admin/worker job — never into MCP.

## Approved-Public Enforcement

Repository queries must return only approved public data:

- Active records from `ndd_entity_view`.
- Review-derived synopsis / phenotype / variation / publication data **only from primary approved reviews**: `is_primary = 1 AND review_approved = 1`. Do not drop these gates to serve "fresher" content.

## Cache Access Is Read-Only

The sidecar binds the same memoised wrapper names as the API and mounts `api_cache` **read-only**. It must not initialize cache versions, clear cache files, compute STRING/phenotype clusters, or write entries. Phenotype correlations are **cache-hit-only** — never call `generate_phenotype_correlations()` on a miss. A fingerprint mismatch may only make MCP **miss**, never serve stale (that is why the exp+db artifact is mounted read-only to MCP).

## Adding or Changing a Tool

- Build it as a **thin composition** of existing read-only repo helpers (see `get_gene_research_context` for the pattern). Register in `mcp-tool-registry.R`; wrap execution in `mcp_tool_safe(...)`.
- **Label every payload's `data_class`**: `curated_sysndd_evidence`, `curated_derived_analysis`, `ml_prediction`, `llm_generated_summary`, `external_reference_identifier`, or `operational_metadata`. NDDScore is always `ml_prediction`, `not_evidence_tier`, and never alters curated classifications.
- Recoverable validation failures return a JSON tool result with `schema_version`, `error.code`, and `isError = true` — **not** a raw R error or JSON-RPC `-32603`.
- Large tools default `response_mode = "compact"` and expose `budget` metadata; keep `schema_version` at the outer envelope only.
- `MCP_SCHEMA_VERSION` (currently `1.2`) is the compatibility contract — bump additively for a new tool, and keep `get_sysndd_capabilities`, `resources/list`, and `resources/read` aligned. Prompts are **off by default** (`MCP_ENABLE_PROMPTS`); enable only for intentional slash-command prompts.

## Verify

- Healthcheck stays cheap and data-independent: `api/scripts/mcp-healthcheck.R` (initialize + tools/list). The heavier `api/scripts/mcp-smoke.R` exercises real tools for dev/CI.
- Guard tests: `api/tests/testthat/test-mcp-*.R` (repository, analysis service, publication-context-verified). A new tool needs a unit test asserting approved-only reads and correct `data_class` labels.

## Common Mistakes

| Mistake | Why it's wrong |
|---|---|
| Query drops `review_approved = 1` for freshness | Leaks draft/in-progress curation |
| Generate an LLM summary on cache miss | MCP has no egress/creds and must not write cache; generation is admin/worker-only |
| Present NDDScore as the evidence verdict | NDDScore is `ml_prediction`, not an evidence tier |
| Return raw R error on bad input | Clients expect the recoverable JSON error envelope |
| Add a tool without bumping `MCP_SCHEMA_VERSION` / updating capabilities | Breaks the discovery + compatibility contract |
