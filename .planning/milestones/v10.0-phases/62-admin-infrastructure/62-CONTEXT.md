# Phase 62: Admin & Infrastructure - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Update the admin comparisons data import system and modernize GitHub Pages documentation deployment. Comparisons data refresh becomes admin-triggered via API job. Documentation migrates from bookdown to Quarto with GitHub Pages environment deployment.

</domain>

<decisions>
## Implementation Decisions

### Comparisons data sources
- Keep current 7 external databases (Radboud, gene2phenotype, PanelApp, SFARI, Geisinger DBD, OMIM NDD, Orphanet)
- Verify and update all source URLs (some may have changed since 2023-04-13)
- Store source URLs and metadata in database config table (editable by admin)
- Database timestamp for "last updated" date (display dynamically, not hardcoded)

### Comparisons data refresh
- Refactor standalone R script into API job pattern (like pubtator_update)
- Admin-triggered refresh via endpoint, runs as async mirai job
- All-or-nothing error handling — any source failure aborts entire refresh
- Full restructure following modern R/full-stack best practices
- Researcher will investigate: modern R patterns, API designs, error handling approaches

### Comparisons UI
- Dynamic popover content from API — fetch database metadata and last-updated dates
- Full Composition API + script setup modernization (match LLM and newer components)
- Keep current 3 tabs (Overlap, Similarity, Table)
- Dedicated admin panel section for Comparisons data refresh (like Publications Refresh section)

### GitHub Pages workflow
- Switch from gh-pages branch to GitHub Pages environment (actions/deploy-pages)
- Push to master only (no PR builds, no manual dispatch)
- Delete gh-pages branch after successful migration

### Documentation migration
- Migrate from bookdown to Quarto
- Rewrite documentation in Quarto format — keep content close to original, correct errors only
- Modern documentation design following best practices
- Theme should align with SysNDD main page styling, include logo
- Researcher will investigate: Quarto best practices for scientific documentation sites

### Claude's Discretion
- Exact job API endpoint design
- Database schema for comparisons metadata config table
- Quarto theme and layout choices within styling guidelines
- Error message formatting and admin UI progress indicators

</decisions>

<specifics>
## Specific Ideas

- "Research best practices for modern R and full-stack development" — major refactoring of the 639-line import script
- Documentation should "follow similar design to main page" with SysNDD logo
- Admin section should match existing patterns (like Publications Refresh in ManageAnnotations)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 62-admin-infrastructure*
*Context gathered: 2026-02-01*
