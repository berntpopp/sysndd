# SysNDD MCP Payload Efficiency And Discoverability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve SysNDD MCP token efficiency and discoverability with payload modes, batch publication dedupe, a capabilities tool, and user-controlled prompts.

**Architecture:** Keep the existing R MCP sidecar and public-data repository gate. Add service helpers for payload modes and publication shaping, extend tool metadata/protocol patches for prompts and capabilities, and keep JSON text as the compatibility result with optional structured output.

**Tech Stack:** R, `testthat`, `ellmer`, `mcptools`, `jsonlite`, `httr2`, Docker Compose, MySQL-backed SysNDD public views.

---

## File Map

- Modify `api/services/mcp-service.R`: mode validation, abstract/synopsis shaping, publication summaries, entity batch dedupe, capabilities payload, search rank metadata.
- Modify `api/services/mcp-tools.R`: new tool arguments, `get_sysndd_capabilities`, prompts protocol handlers, shorter instructions.
- Modify `api/scripts/mcp-smoke.R`: smoke capabilities, prompts, cheap defaults, and batch dedupe.
- Modify `api/config/mcp/resources/sysndd-schema.md`: payload modes, prompts, capabilities, and publication tier guidance.
- Modify `api/tests/testthat/test-mcp-service.R`: service-level payload-mode and dedupe tests.
- Modify `api/tests/testthat/test-mcp-tools.R`: registry/protocol tests for capabilities and prompts.
- Modify `documentation/03-api.qmd`, `documentation/09-deployment.qmd`, and `AGENTS.md`: durable MCP contract updates.

## Task 1: Payload Mode Service Tests And Helpers

- [ ] Add failing tests in `api/tests/testthat/test-mcp-service.R` for `mcp_validate_mode()`, `mcp_publication_record()` abstract modes, and `mcp_apply_synopsis_mode()` synopsis modes.
- [ ] Run the focused service test file and confirm failures are for missing helpers or unchanged behavior.
- [ ] Add helpers to `api/services/mcp-service.R`: `mcp_validate_mode()`, `mcp_abstract_policy()`, `mcp_publication_record()`, and `mcp_apply_synopsis_mode()`.
- [ ] Wire `abstract_mode`, `synopsis_mode`, and `response_mode` through `mcp_get_entity_context()`, `mcp_get_publication_context()`, and `mcp_get_publications_context()`.
- [ ] Re-run the focused service tests and confirm they pass.

## Task 2: Gene Defaults And Entity Batch Dedupe

- [ ] Add failing tests for `get_gene_context` defaulting `include_comparisons = false`, and for `get_entities_context(dedupe_publications = TRUE)` returning top-level unique publications with per-entity publication references.
- [ ] Run the focused service tests and confirm the failures match the intended behavior.
- [ ] Change `mcp_get_gene_context()` and its tool wrapper default to `include_comparisons = false`.
- [ ] Add `dedupe_publications` to `mcp_get_entities_context()`. When true, replace each entity result's full `publications` list with `publication_refs` and emit top-level `publications`.
- [ ] Re-run the focused service tests and confirm they pass.

## Task 3: Capabilities Tool And Tool Metadata

- [ ] Add failing tests in `api/tests/testthat/test-mcp-tools.R` asserting the registry includes `get_sysndd_capabilities`, all tools still advertise read-only annotations/output schemas, and the capabilities result documents workflows, limits, payload modes, errors, resources, and safety scope.
- [ ] Run the focused tools tests and confirm failures.
- [ ] Implement `mcp_get_sysndd_capabilities()` in `api/services/mcp-service.R`.
- [ ] Register `get_sysndd_capabilities` in `api/services/mcp-tools.R` with a no-argument schema-safe tool definition.
- [ ] Shorten `mcp_server_instructions()` and point clients at `get_sysndd_capabilities` plus `sysndd://schema/tool-guide`.
- [ ] Re-run the focused tools tests and confirm they pass.

## Task 4: MCP Prompts

- [ ] Add failing tests for `mcp_handle_prompts_list()` and `mcp_handle_prompts_get()` returning four SysNDD prompts with argument metadata and research/citation instructions.
- [ ] Run the focused tools tests and confirm failures.
- [ ] Add prompt metadata and prompt rendering helpers in `api/services/mcp-tools.R`.
- [ ] Patch `mcp_patch_mcptools_protocol()` to handle `prompts/list` and `prompts/get`, and patch initialize capabilities to advertise `prompts = list(listChanged = FALSE)`.
- [ ] Re-run the focused tools tests and confirm they pass.

## Task 5: Smoke And Documentation

- [ ] Extend `api/scripts/mcp-smoke.R` to call `get_sysndd_capabilities`, verify prompt listing/retrieval, verify cheap `get_gene_context` output, and verify deduped entity batch metadata.
- [ ] Update `api/config/mcp/resources/sysndd-schema.md`, `documentation/03-api.qmd`, `documentation/09-deployment.qmd`, and `AGENTS.md` with payload modes, prompts, and capabilities guidance.
- [ ] Run focused tests, `make lint-api`, `make test-api-fast`, rebuild/restart Docker MCP, and run `MCP_URL=http://127.0.0.1:8787 make test-mcp-smoke`.
- [ ] Commit and push the focused changes to `feature/read-only-mcp-api`.
