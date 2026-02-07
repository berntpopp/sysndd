# Phase 78: Comparisons Integration - Context

**Gathered:** 2026-02-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Unify the comparisons system to use the shared genemap2 cache from Phase 76, eliminating duplicate downloads and duplicate parsing code between the ontology and comparisons systems. Only one genemap2.txt download occurs per day regardless of which system triggers it. phenotype.hpoa remains comparisons-only and is NOT shared.

</domain>

<decisions>
## Implementation Decisions

### Cache sharing strategy
- Comparisons calls Phase 76's `download_genemap2()` directly to get the cached file path
- Comparisons reads genemap2.txt directly from the shared cache location (no copy to tempdir)
- Only genemap2.txt moves to shared cache; phenotype.hpoa and all other comparisons sources (ClinGen, PanelApp, SFARI, etc.) stay in tempdir
- phenotype.hpoa is comparisons-only (not used by ontology system) — no sharing benefit

### Migration cutover
- Direct replacement: swap comparisons' genemap2 download with a call to Phase 76's `download_genemap2()` — no feature flag, no dual path
- Remove genemap2 entry from comparisons_config in the database entirely (clean break)
- phenotype_hpoa config entry stays as-is (comparisons-only, downloads from HPO)

### Parsing unification
- Replace comparisons' genemap2 parsing with Phase 76's `parse_genemap2()` for raw data extraction
- Comparisons applies its own NDD filtering (via phenotype.hpoa HPO terms) and schema formatting on top of the shared parsed data
- Reuse Phase 76/77's inheritance mapping (single source of truth for OMIM-to-HPO normalization) — remove duplicate case_when from comparisons
- Reduced `parse_omim_genemap2()` function stays in `comparisons-functions.R` (comparisons-specific NDD filtering logic)
- Old standalone parsing code removed entirely after migration — no dead code, no fallback

### Versioning
- Comparisons OMIM version field switches from filename-based to date-based (e.g., '2026-02-07') since genemap2 is cached daily

### Claude's Discretion
- Exact migration of the database config (SQL migration or runtime change)
- How to structure the reduced parse_omim_genemap2() function internally
- Test fixture design for regression tests

</decisions>

<specifics>
## Specific Ideas

- The comparisons `parse_omim_genemap2()` should become a thin wrapper: call shared `parse_genemap2()` → filter NDD via HPO → format to comparisons schema
- Schema must match exactly (gene_symbol, disease_ontology_id, disease_ontology_name, inheritance, list, version, category) but data quality improvements from the better parser are accepted
- Unit tests only for this phase (no database integration tests) — verify schema output using fixture data

</specifics>

<deferred>
## Deferred Ideas

- Persistent caching for phenotype.hpoa — could benefit from same caching pattern but no cross-system sharing justification currently
- Persistent caching for other comparisons sources (ClinGen, PanelApp, SFARI, etc.) — monitor for frequent same-day reruns before adding complexity

</deferred>

---

*Phase: 78-comparisons-integration*
*Context gathered: 2026-02-07*
