# SysNDD MCP LLM Ergonomics Design

## Problem

The read-only SysNDD MCP sidecar has a strong data contract for approved public
gene-disease evidence, but LLM consumer testing found several remaining
front-door and edge-case problems that keep the server below a 9/10 consumer
experience:

- A malformed or guessed tool argument can fail at the JSON-RPC layer with a raw
  R error instead of returning a model-visible correction.
- The server advertises the `resources` capability but does not implement
  `resources/list` or `resources/read`.
- Tool metadata does not yet advertise read-only annotations or output schemas,
  even though the payload shapes are stable and versioned.
- Some list/search tools omit `resource_uri`, `suggested_tools`, or consistent
  `meta` fields, which weakens cross-tool navigation.
- `find_entities_by_phenotype(category = "BogusCategory")` silently returns an
  empty result, creating a false negative for a valid phenotype.
- `get_publication_context(pmid = "notapmid")` escapes as JSON-RPC `-32603`
  because the R condition object cannot be serialized.

This design focuses on protocol correctness and LLM self-correction before new
feature breadth. The goal is to make the MCP server predictable enough that an
LLM can discover the right path, call tools with fewer round trips, recover from
input mistakes, and cite evidence without guessing.

## Evidence Reviewed

Two consumer passes were considered:

- Gene-to-entity-to-publication walkthrough:
  `get_gene_context` -> multiple `get_entity_context` calls ->
  `get_publication_context`.
- Full tool evaluation:
  8 happy-path calls on a fresh gene plus 17 edge calls, including cross-tool
  identifier flow for entity IDs, HGNC IDs, OMIM IDs, HPO IDs, and PMIDs.

The strongest existing pieces should be preserved:

- `schema_version` on every tool payload.
- Explicit `*_truncated` booleans.
- `recommended_citation`, `pubmed_publication_date`, and
  `sysndd_curation_date`.
- `resolved_diseases` / `resolved_phenotypes` echoes.
- Stable application error envelopes for known validation failures.
- Public-data scoping through `ndd_entity_view` and primary approved reviews.

The live sidecar confirmed the remaining defects:

- `resources/list` and `resources/read` return `-32601 Method not found`.
- `get_gene_context(symbol = "NAA10")` returns `-32603 unused argument`.
- `find_entities_by_phenotype(phenotype = "HP:0001250", category =
  "BogusCategory")` returns an empty success payload.
- `get_publication_context(pmid = "notapmid")` returns `-32603 No method asJSON
  S3 class: condition`.
- `search_sysndd` reports `meta.total` as the returned page length, not a true
  total, and has no `has_more`.
- `tools/list` has no `outputSchema`, no read-only annotations, and blank
  descriptions for array parameters.

## Design Goals

1. Preserve the original MCP security scope: private/internal or static-bearer
   protected, separate sidecar, read-only, no raw SQL/R, no Gemini, no external
   providers, no draft/review/admin/user/log/job data.
2. Make wrong calls recoverable by the model: validation and domain errors must
   return stable `schema_version` + `error` payloads visible in tool results.
3. Align advertised MCP capabilities with implemented methods.
4. Advertise schemas and read-only hints to clients where the current R MCP
   stack allows it, without replacing the transport for this iteration.
5. Improve cross-tool navigation by making entity rows consistently carry
   `resource_uri` and `suggested_tools`.
6. Add batching only where it removes obvious fan-out without changing the
   public-data gate.

## Non-Goals

- Do not expose parameterized record resources in v1.
- Do not add prompts in this pass.
- Do not make MCP public unauthenticated by default.
- Do not add write tools, curation tools, review data, admin data, raw DB access,
  R execution, Gemini calls, PubMed/PubTator calls, or broad exports.
- Do not replace `mcptools` unless a verified blocker prevents the compatibility
  shim from meeting these requirements.
- Do not change the meaning of existing public SysNDD fields.

## Recommended Approach

Use a SysNDD MCP compatibility shim around `mcptools`.

`mcptools` already provides a working HTTP sidecar and `ellmer::tool()` registry,
but it currently omits several MCP features that matter for LLM ergonomics. A
small shim should patch or wrap the exact boundary points that serialize
capabilities, tool metadata, tool results, and static resources.

This is preferable to replacing the transport because the existing Phase 0 spike
and smoke tests already prove the initialize -> tools/list -> tools/call flow.
The data and service layers can remain focused on approved public SysNDD
retrieval while the shim adapts the server surface to the MCP contract.

## Alternatives Considered

### A. Minimal Bug Fix Only

Fix the phenotype category validator and malformed PMID serializer crash, then
leave resources, schemas, and metadata unchanged.

Pros:

- Fastest path.
- Lowest risk to transport behavior.

Cons:

- Leaves advertised-but-missing resources.
- Leaves unknown argument failures as JSON-RPC internals.
- Does not improve client validation or discoverability enough to reach >9/10.

### B. SysNDD `mcptools` Compatibility Shim

Patch or wrap `mcptools` to expose SysNDD instructions, static resources,
read-only tool annotations, output schemas, structured content when enabled, and
tool-visible validation errors.

Pros:

- Fixes the verified consumer pain points while preserving the existing sidecar.
- Keeps the implementation small and testable.
- Retains backward-compatible JSON text for clients that do not consume
  `structuredContent`.

Cons:

- Depends on internal `mcptools` functions until upstream support improves.
- Requires wire-level smoke tests to guard patches across package updates.

### C. Replace the MCP Transport Adapter

Keep the SysNDD service/repository code, but replace `mcptools` HTTP handling
with a custom MCP HTTP adapter.

Pros:

- Full control over protocol behavior.
- Easier to implement resources, schemas, and error semantics directly.

Cons:

- Much larger implementation surface.
- Higher chance of introducing transport bugs.
- Not justified while a small compatibility shim can address the current gaps.

Recommendation: implement Alternative B.

## Detailed Design

### Server Instructions

Keep SysNDD-specific `initialize.result.instructions`, but expand them slightly
to include:

- Canonical pipeline:
  `search_sysndd` -> `get_gene_context` -> `get_entity_context` ->
  `get_publication_context` / `get_publications_context`.
- Batch pipeline:
  `get_gene_context` -> `get_entities_context` for multiple entity IDs when
  available.
- Entity model:
  an entity is a gene-disease-inheritance curation record; one gene can have
  many entities.
- Citation contract:
  paste `recommended_citation` verbatim; do not treat
  `sysndd_curation_date` as a publication date.
- Resource contract:
  `sysndd://schema/overview` and `sysndd://schema/tool-guide` are static
  documentation resources. Record-like `sysndd://gene`, `sysndd://entity`, and
  `sysndd://publication` URIs are stable identifiers in v1; tools remain the
  retrieval path.
- Research-use disclaimer:
  SysNDD MCP supports research and evidence review, not clinical decision
  support.
- Error contract:
  application errors use `schema_version` and `error.code` such as
  `invalid_input`, `not_found`, `ambiguous_query`, and
  `temporarily_unavailable`.

### Tool Metadata

Every tool advertised in `tools/list` should include:

- `annotations.readOnlyHint = true`
- `annotations.destructiveHint = false`
- `annotations.idempotentHint = true`
- `annotations.openWorldHint = false`
- `outputSchema` with at least:
  - root `type: object`
  - required `schema_version`
  - documented top-level fields for each tool
  - an `error` shape for tool-level error payloads where applicable

`search_sysndd.types` and `get_publications_context.pmids` must provide
array-level descriptions, not only item descriptions.

Tool descriptions should name the expected next step when useful. Example:

- `find_entities_by_phenotype`: "Find approved public entities by HPO ID or
  phenotype text; pass returned entity_id values to get_entity_context or
  get_entities_context."

### Tool Result Shape

Default mode should remain stable JSON text until native structured output is
proven safe for the deployed client mix.

When `MCP_OUTPUT_MODE=structuredContent` is enabled, tool calls should return:

- `structuredContent`: the R list payload as JSON object.
- `content[0].text`: the same payload serialized as JSON text for backward
  compatibility.
- `isError = true` for application-level error payloads.

When default JSON text mode is used, the `content[0].text` payload remains the
contract. The smoke test should verify this mode and, where practical, a
structured-output mode in a focused unit test.

### Error Handling

Known validation and domain failures should be tool execution errors, not raw
JSON-RPC internal errors. This lets the LLM see the error and self-correct.

Use this envelope:

```json
{
  "schema_version": "1.0",
  "error": {
    "code": "invalid_input",
    "message": "category must be one of: Definitive, Moderate, Limited, Refuted",
    "argument": "category",
    "allowed_values": ["Definitive", "Moderate", "Limited", "Refuted"]
  }
}
```

Requirements:

- Unknown tool names may remain JSON-RPC protocol errors.
- Unknown arguments should return a tool-visible `invalid_input` payload naming
  the unknown argument and expected arguments.
- `get_gene_context(symbol = "...")` should not error. Accept `symbol` as a
  deprecated alias for `gene`, normalize internally, and include no extra output
  field unless needed for debug tests.
- Malformed PMIDs must validate before repository access and return
  `invalid_input` with `argument = "pmid"`.
- Invalid phenotype category filters must return `invalid_input` and never
  silently convert a valid phenotype into an empty successful result.
- Empty valid searches remain successful empty arrays with honest metadata.

### Category Validation

Add a shared MCP category validator for public entity categories. The allowed
set should be read from an existing authoritative list if a safe read-only
helper already exists; otherwise define the current public enum in the MCP
service layer and test it:

- `Definitive`
- `Moderate`
- `Limited`
- `Refuted`

Apply this validator to:

- `list_gene_entities(category = ...)`
- `find_entities_by_phenotype(category = ...)`

`find_entities_by_disease` has no category argument today; no category behavior
is needed there unless a future filter is added.

### PMID Validation

Strengthen `mcp_normalize_pmid()`:

- Accept `123`, `PMID:123`, and PubMed URLs with a numeric PMID path.
- Reject strings that contain no numeric PubMed identifier.
- Avoid `regmatches()` returning a condition-like object or empty result that
  later breaks JSON serialization.
- Return normalized `PMID:<digits>` consistently.

### Resource Capability

Because the server advertises resources, implement static resource methods:

- `resources/list`
  - returns `sysndd://schema/overview`
  - returns `sysndd://schema/tool-guide`
  - includes `name`, `title`, `description`, `mimeType`, and assistant-oriented
    annotations.
- `resources/read`
  - accepts only the two static schema URIs.
  - returns text contents from `api/config/mcp/resources/sysndd-schema.md`.
  - returns JSON-RPC resource-not-found `-32002` for unknown resource URIs.

Do not add `resources/templates/list` or parameterized record resources in v1.
If a client calls `resources/templates/list`, returning `-32601 Method not
found` is acceptable because templates are not advertised.

### Search Metadata

`search_sysndd` should expose a list-style `meta` shape:

```json
{
  "limit": 10,
  "offset": 0,
  "returned": 10,
  "total": 42,
  "has_more": true
}
```

If a true total would require expensive cross-type counts, use a bounded
`has_more` implementation by querying `limit + 1` per type and documenting
`total` as `returned` until a true total is available. The preferred
implementation is a true total for each enabled type plus aggregate total, but
not at the cost of broad unbounded scans.

### Cross-Tool Navigation

Every entity row returned by list/find tools should include:

- `resource_uri = "sysndd://entity/<entity_id>"`
- `suggested_tools = ["get_entity_context", "get_entities_context"]`

Apply this to:

- `list_gene_entities`
- `find_entities_by_disease`
- `find_entities_by_phenotype`

Continue returning `resolved_diseases` and `resolved_phenotypes`; they are a
useful echo for LLM verification.

### Batch Entity Tool

Add `get_entities_context` as a bounded fan-out reducer:

- Input:
  - `entity_ids`: array of 1-20 positive integers.
  - passthrough booleans matching `get_entity_context`.
  - `publication_limit` with the same range as `get_entity_context`.
- Output:
  - `schema_version`
  - `entities`: array preserving request order.
  - per-entity error entries for not found or invalid IDs.
  - `meta.requested`, `meta.returned`, `meta.errors`, `meta.max_entity_ids`.
- Behavior:
  - no writes, no external calls, same public-data gate as `get_entity_context`.
  - reuse `mcp_get_entity_context()` internally after validation.

Do not inline all entity detail into `get_gene_context` in this pass. The batch
tool solves the four-call fan-out without making the gene overview unexpectedly
large.

## Testing Plan

Use TDD for each behavior change.

### Unit Tests

Add or update service tests for:

- `mcp_normalize_pmid("notapmid")` returns `invalid_input`.
- valid PMID forms normalize to `PMID:<digits>`.
- invalid phenotype category returns `invalid_input`.
- valid phenotype with invalid category does not return an empty success.
- `symbol` alias calls the same path as `gene`.
- unknown argument validation returns `invalid_input` with expected arguments.
- entity row decoration adds `resource_uri` and `suggested_tools`.
- `get_entities_context` preserves order and returns per-ID errors.
- `search_sysndd` returns the unified `meta` fields.

### Tool Registry Tests

Verify `tools/list` metadata includes:

- no blank array descriptions.
- read-only annotations on every tool.
- output schemas on every tool.
- `get_entities_context` is registered.

### Wire/Smoke Tests

Extend `api/scripts/mcp-smoke.R` to verify:

- `initialize` returns SysNDD instructions with the pipeline and research-use
  disclaimer.
- `resources/list` returns the two static schema resources.
- `resources/read` can read `sysndd://schema/tool-guide`.
- `tools/list` includes `outputSchema` and read-only annotations.
- malformed PMID returns a tool-visible `invalid_input` payload, not JSON-RPC
  `-32603`.
- `get_gene_context(symbol = "NAA10")` succeeds or returns a tool-visible
  alias guidance payload if alias support is disabled by configuration.
- `find_entities_by_phenotype(category = "BogusCategory")` returns
  `invalid_input`.

### Repo Verification

Run:

- focused MCP unit tests while iterating.
- `make test-mcp-smoke`.
- `make test-api-fast`.
- `make lint-api`.
- `git diff --check`.

## Documentation Updates

Update:

- `AGENTS.md` with MCP maintenance notes for resources, output schemas, and
  error envelopes.
- `documentation/03-api.qmd` with the MCP tool catalog, canonical workflow,
  batch entity tool, resource behavior, and error contract.
- `documentation/09-deployment.qmd` if sidecar environment variables or
  structured-output mode change.
- `api/config/mcp/resources/sysndd-schema.md` to match the live resource
  contract.

## Acceptance Criteria

- Live `initialize` no longer exposes generic R-session instructions.
- Live `resources/list` and `resources/read` work for static schema resources,
  or the `resources` capability is not advertised. Preferred outcome: resources
  work.
- Live `tools/list` has read-only annotations and output schemas.
- Live `tools/list` has no blank parameter descriptions.
- Malformed PMIDs produce a stable `invalid_input` tool error.
- Invalid phenotype categories produce a stable `invalid_input` tool error.
- `symbol` can be used as an alias for `gene` on `get_gene_context`.
- `search_sysndd` reports consistent list metadata.
- List/find entity rows include `resource_uri` and `suggested_tools`.
- `get_entities_context` batches 1-20 entity context lookups with per-ID errors.
- No MCP tool writes to the DB, calls Gemini, calls external providers, executes
  raw SQL/R, or exposes draft/review/admin/user/log/job data.
- `make test-mcp-smoke`, `make test-api-fast`, and `make lint-api` pass before
  handoff.
