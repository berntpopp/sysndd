# Project Research Summary

**Project:** SysNDD v10.4 OMIM Optimization & Refactor
**Domain:** Neurodevelopmental disorder database - OMIM data integration
**Researched:** 2026-02-07
**Confidence:** HIGH

## Executive Summary

This milestone optimizes OMIM data integration by consolidating two divergent data flows (ontology and comparisons systems) onto a unified genemap2.txt foundation. The current ontology system uses mim2gene.txt + JAX API calls (~20 minutes for 8,500 disease names), while the comparisons system already efficiently parses genemap2.txt locally. By migrating the ontology system to genemap2.txt, we eliminate the slow JAX API dependency, gain mode of inheritance (MOI) information that was previously unavailable, and unify caching infrastructure with a 1-day TTL.

The recommended approach leverages existing R packages (httr2, fs, lubridate) without new dependencies. The codebase already has validated patterns from omim-functions.R and file-functions.R that can be extended. The key architectural change is creating shared genemap2-functions.R for download/parsing, then adapting ontology-functions.R to use genemap2 data instead of JAX API, while maintaining backward-compatible database schemas.

Critical risks include OMIM IP blocking from excessive downloads (mitigated by file-based 1-day TTL caching), genemap2.txt column name changes breaking parsing (mitigated by defensive column mapping), and Phenotypes column regex fragility (mitigated by robust field-based parsing). A phased migration with feature flags allows rollback to JAX API if needed, ensuring production stability during the transition.

## Key Findings

### Recommended Stack

No new packages required. The existing R stack already provides everything needed for OMIM file download caching with 1-day TTL.

**Core technologies:**
- **httr2**: HTTP downloads with exponential backoff retry (already used in omim-functions.R for mim2gene.txt)
- **fs**: Cross-platform file system operations (already used in file-functions.R)
- **lubridate**: Date arithmetic for TTL validation (already used in check_file_age())

**Key finding:** The project already uses date-stamped filenames (mim2gene.YYYY-MM-DD.txt) and check_file_age() for age-based validation. This pattern extends naturally to all OMIM downloads with consistent 1-day TTL. Do NOT add cachem or memoise (wrong abstraction for file downloads), do NOT use base download.file() (lacks retry logic).

### Expected Features

**Must have (table stakes):**
- **Download caching with 1-day TTL**: Prevents OMIM IP blocking, aligns with weekly update frequency, already validated in mim2gene download
- **Disease name extraction**: Core requirement for displaying human-readable disease labels from genemap2 Phenotypes column
- **MIM number to gene association**: Required to link OMIM diseases to genes for cross-database comparison
- **Inheritance mode extraction**: Essential for filtering/categorizing diseases by inheritance pattern (currently missing from mim2gene approach, genemap2 provides this)
- **Environment variable for download key**: Move from hardcoded value to OMIM_DOWNLOAD_KEY env var, consistent with existing project patterns

**Should have (differentiators):**
- **Unified data source**: Both ontology and comparisons systems using same genemap2 cache eliminates version drift
- **MOI data in ontology system**: genemap2 provides inheritance information that mim2gene lacks, populating previously NA fields
- **Evidence level tracking**: Preserve mapping key (1-4) for future filtering by evidence strength
- **Deprecation detection**: Track moved/removed OMIM IDs for curator re-review (may require keeping mim2gene download or diff-based approach)

**Defer (post-MVP):**
- **Dual-source validation**: Cross-validate genemap2 vs mim2gene for data quality (nice-to-have, but comparisons system doesn't need mim2gene)
- **Dynamic HPO hierarchy fetch**: Static NDD HPO term list is sufficient; API fetch is optimization
- **MONDO mapping for comparisons**: Already exists for ontology system; extend later if needed

### Architecture Approach

The unified genemap2.txt architecture consolidates two currently divergent OMIM data flows by creating shared infrastructure at the data layer while maintaining existing component boundaries. The ontology system currently uses mim2gene.txt + JAX API (~7 minutes for disease names), while comparisons already uses genemap2.txt with HPO filtering. By introducing genemap2-functions.R for shared download/parsing, then rewriting process_omim_ontology() to use genemap2 data, both systems benefit from common caching (1-day TTL in data/ directory), unified download key management (OMIM_DOWNLOAD_KEY env var with database fallback), and reduced external API dependencies.

**Major components:**
1. **genemap2-functions.R (NEW)**: Shared download/parsing infrastructure with get_omim_download_key(), download_genemap2_with_key(), parse_genemap2(), parse_phenotypes_column()
2. **omim-functions.R (MODIFIED)**: Replace mim2gene + JAX API logic with build_omim_ontology_set_from_genemap2(), remove fetch_all_disease_names(), adapt deprecation tracking
3. **ontology-functions.R (MODIFIED)**: Rewrite process_omim_ontology() to call genemap2 functions, remove JAX API progress tracking, keep MONDO SSSOM application
4. **comparisons-functions.R (OPTIONAL)**: Refactor to use shared parse_genemap2() or keep isolated parsing to avoid coupling (Phase 3 decision)

**Performance improvement:** Eliminates 7-minute JAX API fetching, total ontology update time drops from ~8 minutes to ~30 seconds.

### Critical Pitfalls

1. **Missing download caching leads to OMIM IP blocking** — Implement TTL-based caching (1 day) FIRST before any parsing logic. OMIM enforces rate limiting and can revoke API keys for excessive downloads. Use file-based caching with check_file_age(), not httr2 req_cache() which respects HTTP headers (OMIM returns Cache-Control: no-cache). Prevention: download_genemap2_with_key() checks cache age, returns existing file if <1 day old, only downloads on cache miss or expiry.

2. **genemap2.txt field name changes break parsing** — OMIM periodically renames column headers without versioning (e.g., "Approved Symbol" → "Approved Gene Symbol"). Implement defensive column name mapping with fallbacks for historical variations. Prevention: use colnames_mapping list with alternatives, throw clear error with available columns if none match, don't assume exact header names.

3. **Phenotypes column regex fragility** — The Phenotypes column contains complex nested structures with multiple delimiter types. Format: "Disease name, MIM_number (mapping_key), inheritance; Next disease...". Use robust field-based parsing instead of complex regex chains. Prevention: parse_phenotypes_column() extracts MIM (6 digits after comma), mapping key (digit in parentheses), disease name (before first paren), with validation for unparseable entries.

4. **No rollback plan for data source migration** — Cutover from JAX API to genemap2 happens atomically. Implement feature flag (OMIM_DATA_SOURCE env var) with "genemap2", "jax_api", or "both" modes. Prevention: keep JAX API code intact during Phase 2, use "both" mode to validate new vs old approach, only delete old code after stable operation (1-2 weeks).

5. **Environment variable migration incomplete** — Moving OMIM API key from hardcoded to env var can fail in Docker/CI if not configured in all environments. Prevention: get_omim_download_key() with clear error messages listing configuration for .Renviron, docker-compose.yml, GitHub Actions secrets. Test in local, Docker, and CI before deployment.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Shared Infrastructure (Foundation)
**Rationale:** Create reusable genemap2 download/parse without touching existing systems. Additive-only changes minimize risk.
**Delivers:** Working genemap2-functions.R with download, parse, and caching capabilities
**Addresses:** Download caching (table stakes), environment variable management (table stakes), defensive column mapping (critical pitfall 2)
**Avoids:** IP blocking (critical pitfall 1) by implementing TTL cache first, Phenotypes parsing fragility (critical pitfall 3) with robust extraction
**Stack:** httr2 with retry logic, fs for file operations, lubridate for TTL validation
**Research flag:** STANDARD PATTERN (well-documented httr2 usage, existing check_file_age pattern to extend)

### Phase 2: Ontology System Migration (Primary Goal)
**Rationale:** Replace mim2gene + JAX API with genemap2 in ontology system. This is the core performance improvement (8 min → 30 sec).
**Delivers:** Ontology system using genemap2 with MOI data populated, JAX API dependency removed
**Addresses:** Unified data source (differentiator), MOI data in ontology (should have), performance optimization (eliminates 7-minute JAX API loop)
**Avoids:** No rollback plan (critical pitfall 4) by keeping JAX code commented, not deleted
**Uses:** Shared genemap2-functions.R from Phase 1, inheritance mode mapping from comparisons system
**Implements:** build_omim_ontology_set_from_genemap2() with Phenotypes parsing, versioning logic (OMIM:123456_1 for duplicates), HGNC matching
**Research flag:** NEEDS LIGHT RESEARCH (Phenotypes column parsing patterns exist in comparisons-functions.R, but need adaptation for ontology schema)

### Phase 3: Comparisons System Integration (Optional Optimization)
**Rationale:** Unify comparisons to use shared cache, eliminate duplicate parsing. Lower priority than Phase 2.
**Delivers:** Single genemap2 download per day (shared cache), consistent data version across systems
**Addresses:** Unified data source (differentiator), reduced code duplication
**Avoids:** Cache inconsistency anti-pattern (ontology uses data/, comparisons uses temp_dir)
**Uses:** Shared download_genemap2_with_key() from Phase 1
**Decision point:** Shared parse_genemap2() vs isolated parsing (coupling vs duplication trade-off)
**Research flag:** STANDARD PATTERN (comparisons already uses genemap2, just consolidating infrastructure)

### Phase 4: Cleanup and Deprecation Tracking (Maintenance)
**Rationale:** Remove deprecated code, restore deprecation detection functionality. Safe to defer until Phases 1-3 stable.
**Delivers:** Clean codebase, updated documentation, deprecation tracking (currently lost in genemap2 migration)
**Addresses:** Deprecation detection (should have feature)
**Avoids:** Leaving dead code in production
**Options for deprecation:** Keep mim2gene download for moved/removed entries, or implement diff-based approach comparing genemap2 versions
**Research flag:** NEEDS RESEARCH (deprecation strategy unclear, mim2gene has explicit moved/removed flag, genemap2 does not)

### Phase Ordering Rationale

- **Phase 1 before 2:** Shared infrastructure must exist before ontology migration uses it. Additive-only changes minimize risk.
- **Phase 2 is primary goal:** Performance improvement (8 min → 30 sec) and MOI data addition are the milestone deliverables.
- **Phase 3 is optional optimization:** Comparisons system already works, consolidation is code quality improvement not functional requirement.
- **Phase 4 deferred to post-MVP:** Deprecation tracking is valuable but not blocking, needs research on best approach (mim2gene vs diff-based).

**Dependency chain:**
```
Phase 1 (genemap2-functions.R) → Phase 2 (ontology migration)
                                 ↓
                                 Phase 3 (comparisons consolidation) → Phase 4 (cleanup)
```

**Pitfall mitigation order:**
- Phase 1 addresses critical pitfalls 1, 2, 3 (caching, column mapping, parsing)
- Phase 2 addresses critical pitfall 4 (rollback plan with feature flag)
- Phase 2 addresses critical pitfall 5 (env var configuration)
- Phase 4 addresses deprecation tracking gap

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Ontology Migration):** Light research needed on inheritance mode mapping (comparisons-functions.R has mapping table, need to verify coverage for all genemap2 MOI terms)
- **Phase 4 (Deprecation Tracking):** Research needed on deprecation strategy (keep mim2gene download only for moved/removed detection, or implement diff-based approach)

Phases with standard patterns (skip research-phase):
- **Phase 1 (Shared Infrastructure):** httr2 download with retry is well-documented, file-based caching pattern already exists in codebase (check_file_age, get_newest_file)
- **Phase 3 (Comparisons Integration):** Comparisons system already parses genemap2, just moving to shared cache (no new patterns)

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All required packages already in renv.lock, patterns validated in existing code (omim-functions.R, file-functions.R) |
| Features | MEDIUM | genemap2 parsing well-understood from comparisons system, but inheritance mode coverage needs validation (OMIM uses free text, mapping may be incomplete) |
| Architecture | HIGH | Based on direct code analysis of existing OMIM flows (ontology vs comparisons), clear integration points identified |
| Pitfalls | HIGH | OMIM rate limiting documented in terms of service, column name changes observed in community parsers (Scout CHANGELOG), Phenotypes parsing validated from existing comparisons code |

**Overall confidence:** HIGH (85% - stack and architecture very clear, some uncertainty on MOI mapping coverage)

### Gaps to Address

- **Inheritance mode mapping completeness:** The comparisons-functions.R mapping table covers 14 inheritance terms, but genemap2 uses free text. Validate during Phase 2 implementation that all genemap2 inheritance values map correctly, log unmapped terms for manual review.

- **Deprecation detection strategy:** genemap2.txt lacks explicit moved/removed flags that mim2gene.txt provides. Options: (1) keep mim2gene download for deprecation checking only, (2) implement diff-based approach comparing genemap2 versions, (3) defer deprecation tracking. Decide during Phase 4 planning based on curator workflow importance.

- **Gene symbol ambiguity handling:** genemap2 contains historical gene symbols that may no longer be current HGNC symbols. Implement fallback matching using Entrez ID and Ensembl ID from genemap2 (columns available) if symbol lookup fails. Monitor match rate during Phase 2 testing.

- **Phenotypes column edge cases:** Known variations include disease names with commas, semicolons in unexpected places, missing mapping keys. Build comprehensive test suite from real genemap2.txt samples before Phase 2 implementation, not just synthetic test data.

## Sources

### Primary (HIGH confidence)
- **Existing codebase patterns:** api/functions/omim-functions.R (mim2gene + JAX API, lines 36-72), api/functions/file-functions.R (check_file_age, get_newest_file), api/functions/comparisons-functions.R (genemap2 parsing, lines 390-503)
- **OMIM official documentation:** https://omim.org/downloads (download URLs, file descriptions), https://www.omim.org/help/faq (mapping key definitions)
- **httr2 documentation:** https://httr2.r-lib.org/ (retry logic, timeout control)
- **R package verification:** httr2, fs, lubridate all in renv.lock

### Secondary (MEDIUM confidence)
- **HPO phenotype.hpoa format:** https://obophenotype.github.io/human-phenotype-ontology/annotations/phenotype_hpoa/ (12-column format with OMIM cross-reference)
- **OMIM file comparison:** Biostars discussion on morbidmap vs genemap2 differences (community consensus)
- **Gene symbol updates:** HGNChelper package documentation for symbol correction (PMC7856679)
- **Column name variations:** Scout CHANGELOG (Clinical-Genomics/scout) documents field renaming in production

### Tertiary (LOW confidence, needs validation)
- **Third-party OMIM parsers:** GitHub topics/omim shows historical column name variations (multiple parsers independently handle "Approved Symbol" vs "Approved Gene Symbol")
- **Inheritance mode mapping:** Comparisons-functions.R mapping table appears comprehensive but may not cover all genemap2 free text values (validation needed during implementation)

---
*Research completed: 2026-02-07*
*Ready for roadmap: yes*
