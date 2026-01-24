# Phase 23: OMIM Migration - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace genemap2.txt as the OMIM data source with mim2gene.txt, while preserving OMIM disease names through the JAX ontology API. Add MONDO disease equivalence as suggested matches for curators. ManageAnnotations admin view must work with the new data sources.

</domain>

<decisions>
## Implementation Decisions

### Data source transition
- Clean replacement: remove genemap2 code entirely, mim2gene.txt is the only source going forward
- Preserve existing output schema: map mim2gene fields to match current structure, fill gaps from other sources
- JAX API as single source of truth for OMIM disease names
- Store mim2gene.txt with timestamp: keep local copy, check if newer version available before re-downloading

### JAX API integration
- Fetch fresh disease names each update run (no caching between runs)
- Abort entire update if JAX API is unavailable during run
- Test API limits first, implement exponential backoff with retry on rate limiting
- Log failures only (silent on success)
- Progress reporting with step + count (e.g., "Fetching disease names: 45/100")
- 3-4 major steps for progress: Download mim2gene → Fetch disease names → Validate → Write to database

### Validation & error handling
- All fields required: every entry must have MIM number, gene symbol, AND disease name
- Abort entire update if any entry fails validation (database unchanged until 100% valid)
- List all failures in job status (show all invalid MIM numbers and what's missing)
- Single transaction: all inserts/updates in one database transaction, rollback on any failure
- Pre-implementation research: standalone script to test JAX API limits/format and verify data completeness

### MONDO equivalence
- Display MONDO equivalence in both curation interface AND public entity pages
- Suggested match workflow: system suggests MONDO match, curator can accept/reject/modify
- Fetch MONDO mappings as part of the OMIM annotation update job (not separate)
- Show empty if no MONDO equivalent (no special flagging)

### Claude's Discretion
- Specific retry count and backoff timing for JAX API
- How to detect if mim2gene.txt has been updated (ETag, Last-Modified header, etc.)
- MONDO API endpoint selection and query strategy
- Step naming for progress display

</decisions>

<specifics>
## Specific Ideas

- "Test API limits in independent script before implementing in codebase" — research should produce a validation script
- Progress should show step details like "Step 2: JAX calls 45/100" in the async job status
- If research reveals data gaps (MIMs without disease names in JAX), document the gaps and decide during planning based on severity

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 23-omim-migration*
*Context gathered: 2026-01-24*
