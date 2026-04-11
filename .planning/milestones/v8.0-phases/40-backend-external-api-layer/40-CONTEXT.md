# Phase 40: Backend External API Layer - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Build R/Plumber infrastructure to integrate external genomic data (gnomAD, UniProt, Ensembl, AlphaFold, MGI/RGD) into the gene page. Two data pathways: (1) scores and URLs stored in MySQL via admin batch update, (2) detailed data (variant positions, domain coordinates) fetched live through backend proxy endpoints with disk caching.

</domain>

<decisions>
## Implementation Decisions

### Response format & data shape
- **Hybrid architecture:** Compact data (scores, URLs, IDs) stored in MySQL gene table via admin batch update; detailed data (variant positions, domain coordinates) fetched live through proxy endpoints
- **DB-stored data:** pLI, LOEUF, mis_z scores, AlphaFold structure URL, MGI/RGD IDs, phenotype counts — columns on the gene annotation table
- **Live proxy data:** ClinVar variant positions, UniProt protein domain coordinates, detailed structure data — fetched on demand through `/api/external/` endpoints
- **Batch update:** Admin triggers batch update for all ~700 genes at once, no per-gene update needed

### Caching behavior & freshness
- **Live proxy cache TTL:** Long (7-30 days) — genomic data changes infrequently
- **DB annotations:** Manual admin trigger only, no automatic schedule
- **Cache persistence:** Disk-based cache (memoise + cachem) persists across R/Plumber restarts — avoids cold-start thundering herd
- **No cache bypass:** Cache expires naturally, no force-refresh mechanism needed

### Error handling & degradation
- **Live proxy errors:** Research best practices for API error handling in proxy/BFF patterns (decision deferred to researcher)
- **Batch update strategy:** Proper batching with retry + exponential backoff per gene; if a gene still fails after retries, skip it and continue with remaining genes
- **Batch result:** Final summary only — "695/700 updated, 5 failed (list)". No real-time progress (Plumber architecture limitation)
- **Missing data display:** Show "Not available" empty state cards when gene has no annotation data, don't hide sections entirely

### Endpoint structure & auth
- **Live proxy routes:** Separate `/api/external/` route group (e.g., `/api/external/gnomad/variants/<symbol>`, `/api/external/uniprot/domains/<symbol>`)
- **Auth:** Live proxy endpoints are public (added to AUTH_ALLOWLIST) — underlying data is public anyway
- **Admin endpoint:** New dedicated admin route `/api/admin/external-annotations/update` for batch updates
- **Source selection:** All sources updated at once, no per-source option

### Claude's Discretion
- Exact TTL values per source within the 7-30 day range
- Live proxy response format and error structure (pending research)
- Database schema for annotation columns vs separate table
- Batching strategy (chunk size, parallelism) for ~700 genes across 5 APIs
- Rate limiting implementation details (req_throttle configuration)

</decisions>

<specifics>
## Specific Ideas

- External data should be "annotated to the HGNC table" — treat scores/URLs as gene-level annotations managed through the admin annotation workflow
- The admin "manage annotations" view is the conceptual home for this, though the endpoint itself is a new admin route
- Existing patterns to reuse: httr2 retry logic from `omim-functions.R`, memoise caching from `analyses-functions.R`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 40-backend-external-api-layer*
*Context gathered: 2026-01-27*
