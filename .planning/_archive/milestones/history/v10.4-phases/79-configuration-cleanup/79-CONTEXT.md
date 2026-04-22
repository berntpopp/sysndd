# Phase 79: Configuration & Cleanup - Context

**Gathered:** 2026-02-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove deprecated JAX API code, externalize the hardcoded OMIM download key to an environment variable, unify mim2gene.txt caching with the shared infrastructure from Phase 76, and update documentation. This is the final cleanup phase of the v10.4 milestone.

</domain>

<decisions>
## Implementation Decisions

### Key migration strategy
- Clean break — no fallback to hardcoded key; all deployments must set OMIM_DOWNLOAD_KEY env var
- Read OMIM_DOWNLOAD_KEY once at startup, cache in API config/environment
- No health check indicator for key presence — validated when OMIM features run
- **Research needed:** Best practices for env var validation in R/Plumber APIs (required vs lazy validation pattern)
- **Research needed:** Current Docker Compose pattern for env var passing (environment section vs env_file) — match existing project conventions

### Dead code removal scope
- Aggressive cleanup — trace ALL references to JAX functions, remove every orphaned helper, test, config entry, and import
- Remove JAX-specific tests entirely (don't convert) — genemap2 already has its own tests from Phase 76-77
- Remove omim_links.txt file entirely — URL construction moves to code using env var
- Code-only cleanup for comparisons_config migration — don't add a database migration to remove the row

### Documentation updates
- .env.example: Add OMIM_DOWNLOAD_KEY with guidance comment (OMIM registration URL and brief instructions)
- CLAUDE.md: No update needed — .env.example is sufficient for developer discovery
- No separate migration docs — clean break is self-explanatory from docker-compose and .env.example changes

### Deprecation tracking
- Keep mim2gene.txt download for deprecation tracking (authoritative source for moved/removed MIM entries)
- Unify mim2gene.txt caching with the shared cache_omim_file() infrastructure from Phase 76
- **Research needed:** Verify whether mim2gene.txt requires OMIM authentication or is publicly accessible (belief: no key needed)
- Add test verifying mim2gene.txt caching works through the unified cache infrastructure

### Claude's Discretion
- Exact startup validation approach (after research completes)
- Docker Compose env var passing pattern (after research confirms existing conventions)
- Order of cleanup operations
- How to handle any edge cases in dead code tracing

</decisions>

<specifics>
## Specific Ideas

- Research best practices and existing docs fitting our R/Plumber stack for env var validation patterns
- Research existing Docker Compose configuration in the project to match patterns for env var passing
- Web search to confirm mim2gene.txt public accessibility (no OMIM download key required)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 79-configuration-cleanup*
*Context gathered: 2026-02-07*
