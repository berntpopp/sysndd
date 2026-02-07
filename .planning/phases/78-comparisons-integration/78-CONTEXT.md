# Phase 78: Comparisons Integration - Context

**Gathered:** 2026-02-07 (revised after research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Unify the comparisons system to use the shared genemap2 cache and parser from Phase 76. After this phase, only one genemap2.txt download occurs per day regardless of whether ontology or comparisons update runs. The comparisons system's duplicate `parse_omim_genemap2()` is deleted and replaced by the shared `parse_genemap2()` with a new adapter function. phenotype.hpoa also gets persistent caching. No new comparison sources are added; no changes to non-OMIM comparison sources.

</domain>

<decisions>
## Implementation Decisions

### NDD filtering strategy
- NDD filtering is a **separate post-parse step**, not part of the shared `parse_genemap2()` function
- Shared parser returns all OMIM entries; the comparisons adapter function applies NDD HPO term filtering after parsing
- NDD HPO terms **stay hardcoded as a named constant** (`NDD_HPO_TERMS`) in R code — these are stable domain constants defining what "NDD" means in SysNDD, not environment-specific configuration (YAGNI: never changed, no admin UI exists, database storage adds migration/query/parsing complexity for zero current benefit)
- Well-documented constant with comment explaining when to review (if HPO restructures the neurodevelopmental branch)

### Cache sharing approach
- Comparisons calls `download_genemap2()` from shared omim-functions.R directly — gets cached file from `data/` directory with 1-day TTL
- If genemap2.txt was already downloaded today (by ontology or a previous comparisons run), no re-download occurs
- **Remove genemap2 entry from comparisons_config entirely** via database migration — the URL contains a plaintext OMIM API key (security risk), per-source `last_updated` has no UI consumer, and `comparisons_metadata` already tracks global refresh status
- How to integrate genemap2 into the comparisons download loop (special-case vs separate handling before the generic loop): **Claude's discretion**

### Parser transition plan
- **Delete `parse_omim_genemap2()` entirely** and create a new `adapt_genemap2_for_comparisons()` function — the old name is misleading since the function no longer parses anything (Adapter pattern; rename signals semantic change)
- Adapter takes pre-parsed genemap2 data (output of `parse_genemap2()`) + phenotype.hpoa path, applies NDD filtering, and returns comparisons-ready schema
- Adapter function produces: `gene_symbol`, `disease_ontology_id`, `disease_ontology_name`, `inheritance`, `list`, `version`, `category`
- OMIM category (`"Definitive"`) and granularity string remain **hardcoded in the adapter** — fixed OMIM characteristics, not configurable
- Shared parser's inheritance mappings (15 entries) are **canonical** — any differences from the old 14-entry mapping are accepted as improvements

### phenotype.hpoa handling
- phenotype.hpoa gets **persistent caching** in `data/` directory, same pattern as genemap2 (avoids redundant 5-15 MB downloads on retry/re-run)
- Download/cache function (`download_hpoa()` or similar) goes into **shared omim-functions.R** alongside `download_genemap2()`
- phenotype.hpoa URL stays in **comparisons_config table** — passed to the download function as a parameter
- **1-day TTL** for hpoa caching, consistent with genemap2 strategy (HPO updates quarterly, but consistency across sources matters more than per-source optimization)

### Claude's Discretion
- How to integrate genemap2 into the comparisons download loop (special-case in `download_source_data()` vs handle separately before loop)
- Exact placement of `adapt_genemap2_for_comparisons()` (in comparisons-functions.R or a separate file)
- Migration number for removing genemap2 from comparisons_config
- Test fixture strategy for the adapter function
- Whether `download_hpoa()` accepts URL parameter or reads from comparisons_config directly

</decisions>

<specifics>
## Specific Ideas

- Consistent 1-day TTL across all cached OMIM/HPO files for simplicity
- NDD_HPO_TERMS constant should include a comment referencing HP:0012759 as the root term and linking to HPO for future review
- Security improvement: removing genemap2 row from comparisons_config eliminates plaintext API key from database (shared `download_genemap2()` uses OMIM_DOWNLOAD_KEY env var instead)

</specifics>

<deferred>
## Deferred Ideas

- Database-driven NDD HPO term management — if future need arises to define custom phenotype filters for different disease domains, build the database infrastructure then (may need HPO tree traversal, not a flat list)
- Persistent caching for other comparisons sources (ClinGen, PanelApp, SFARI, etc.) — monitor for frequent same-day reruns before adding complexity
- Admin UI for comparisons_config management (toggling is_active, viewing per-source last_updated)

</deferred>

---

*Phase: 78-comparisons-integration*
*Context gathered: 2026-02-07*
