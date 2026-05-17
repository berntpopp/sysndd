# SysNDD MCP Payload Efficiency And Discoverability Design

## Problem

LLM consumer reviews now rate the SysNDD MCP data contract highly for
correctness, citation safety, structured errors, and batch tools. The remaining
gap to a >9.5/10 experience is mostly operational: broad payloads spend too many
tokens, some cheap-path controls are not obvious from the tool list, and common
workflows depend on the model assembling the right sequence manually.

The next pass must improve speed, token efficiency, and discoverability without
expanding the security surface. MCP remains a read-only sidecar. V1 still uses
approved public entities from `ndd_entity_view` and primary approved reviews
only. It must not expose draft/review/admin/user/log/job data, raw SQL, raw R,
Gemini, external providers, or writes.

## Evidence And MCP Baseline

The MCP specification frames tools as model-controlled, resources as
application-controlled, and prompts as user-controlled workflow templates.
Therefore SysNDD should keep record retrieval in tools, use resources for static
schema/help context, and add prompts only as opt-in workflow guidance. Tools that
return structured data should keep JSON text compatibility while exposing
`structuredContent` when available. Tool validation errors should remain
recoverable tool results with `isError = true` so models can self-correct.

Security guidance reinforces the current private/internal read-only design:
validate all inputs, enforce access control outside the sidecar or through a
static bearer token, minimize scope, and avoid relying on annotations as hard
security guarantees.

## Goals

1. Make the default path cheaper: no unrequested comparison-source payloads and
   no abstracts when a caller asks for metadata only.
2. Give callers explicit payload controls on context tools.
3. Remove repeated shared publication objects from batch entity responses.
4. Add an in-band capabilities tool for model-visible onboarding without forcing
   resource reads.
5. Add MCP prompts for common SysNDD evidence workflows.
6. Preserve stable JSON text output, optional structured output, output schemas,
   read-only annotations, static schema resources, and existing error envelopes.
7. Keep changes covered by TDD and the existing MCP smoke checks.

## Non-Goals

- Do not add parameterized record resource templates in this pass.
- Do not add clinical decision support, diagnosis, treatment recommendations, or
  personalized medical advice prompts.
- Do not add external PubMed/PubTator/Gemini calls or data backfill jobs.
- Do not expose public unauthenticated MCP by default.
- Do not merge this sidecar into Plumber.

## Design

### Payload Controls

Add three model-facing controls:

- `response_mode`: `compact`, `standard`, or `full`.
- `abstract_mode`: `none`, `metadata`, or `excerpt`.
- `synopsis_mode`: `none`, `excerpt`, or `full`.

`compact` is the default for broad and batch contexts. It suppresses expensive
optional sections unless explicitly requested. `standard` keeps current useful
summary behavior. `full` maximizes detail within existing caps. These are modes,
not unlimited exports.

Abstract modes use a stable shape:

- `none`: no abstract text, `abstract_available` omitted.
- `metadata`: `abstract_available` is present, while `abstract_excerpt` and
  `abstract_truncated` are omitted.
- `excerpt`: includes `abstract_available`, `abstract_excerpt`, and
  `abstract_truncated`.

Synopsis modes use a stable shape:

- `none`: synopsis fields are omitted.
- `excerpt`: include capped synopsis text and truncation flag.
- `full`: include the review synopsis up to the existing full-context cap.

For compatibility, existing include flags remain supported. The default for
`get_gene_context` changes to `include_comparisons = false`.

`get_gene_context` also exposes `expand = "none" | "entities"`. The default
`none` keeps the cheap first-page gene summary. `entities` reuses
`get_entities_context` internally to return an `entity_details` block with the
same publication dedupe behavior as the batch tool, so common "tell me about gene
X" tasks can complete in one round trip when the caller opts into the extra
payload. Because the batch detail path accepts 20 IDs per call, expanded gene
detail clamps the detail fetch to 20 entities and reports that cap in `meta`.

### Batch Publication Deduplication

`get_entities_context` gains `dedupe_publications = true` by default. When true,
entity results keep lightweight publication references while a top-level
`publications` list contains one publication object per PMID. The response keeps
request order for entities and preserves per-entity errors.

### Capabilities Tool

Add `get_sysndd_capabilities`. It returns a compact orientation object with:

- canonical workflows;
- tool index and when-to-use guidance;
- cheap-path examples;
- limits and pagination contract;
- payload mode definitions;
- citation/date contract;
- resource contract;
- error code taxonomy;
- safety scope and v1 exclusions.

This is a read-only tool so model clients can discover help through `tools/list`
and `tools/call`, even when resources/prompts are hidden or skipped by a client.

### MCP Prompts

Patch `mcptools` protocol handling for:

- `prompts/list`
- `prompts/get`

Expose four user-controlled prompts:

- `sysndd_gene_evidence_summary`
- `sysndd_entity_evidence_brief`
- `sysndd_publication_citation_pack`
- `sysndd_phenotype_entity_discovery`

Prompts return instructions and workflow steps only. They do not call tools or
include hidden generated claims. They must state research-use-only scope and
tell the model to paste `recommended_citation` verbatim.

### Search And Metadata Polish

Improve `search_sysndd` output so score is actionable:

- include `rank_reason`;
- include `matched_field` when derivable;
- document that broad searches are capped and type-filterable.

If a true corpus total is not available for a search type, keep the existing
bounded total semantics but call it `total_returned_by_search` in capability
docs rather than implying a corpus count.

### Documentation And Tests

Update static schema resources, MCP smoke, and API/deployment docs. Tests must
cover:

- default `get_gene_context` excluding comparisons;
- abstract/synopsis modes;
- entity-batch publication dedupe;
- capabilities tool metadata;
- prompt listing and prompt retrieval;
- JSON text and structured output behavior remaining valid.

## Success Criteria

- `make lint-api` passes.
- Focused MCP service/tool tests pass.
- `MCP_URL=http://127.0.0.1:8787 make test-mcp-smoke` passes after Docker MCP is
  rebuilt and restarted.
- Manual MCP consumers can answer a common gene summary with fewer repeated
  tokens, see the cheap path in tool metadata, discover capabilities by tool,
  and invoke prompt templates if their client supports MCP prompts.
