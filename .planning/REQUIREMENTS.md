# Requirements: SysNDD v10.4 OMIM Optimization & Refactor

**Defined:** 2026-02-07
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v1 Requirements

Requirements for v10.4 milestone. Each maps to roadmap phases.

### Shared Infrastructure

- [x] **INFRA-01**: genemap2.txt downloads use OMIM_DOWNLOAD_KEY environment variable (not hardcoded) (#139)
- [x] **INFRA-02**: genemap2.txt downloads are cached on disk with 1-day TTL to prevent OMIM rate limiting/blocking
- [x] **INFRA-03**: genemap2.txt parsing handles column name variations defensively (historical field renames)
- [x] **INFRA-04**: Shared parse_genemap2() function extracts disease name, MIM number, mapping key, and inheritance from Phenotypes column

### Ontology Migration

- [x] **ONTO-01**: Ontology update uses genemap2.txt for disease names instead of JAX API sequential calls (#139)
- [x] **ONTO-02**: Ontology update completes in under 60 seconds (was ~8 minutes with JAX API)
- [x] **ONTO-03**: Inheritance mode information from genemap2.txt is mapped to HPO terms and stored in disease_ontology_set
- [x] **ONTO-04**: Duplicate MIM numbers retain versioning (OMIM:123456_1, _2) consistent with previous behavior
- [x] **ONTO-05**: MONDO SSSOM mappings continue to be applied after genemap2 processing (unchanged)
- [x] **ONTO-06**: mim2gene.txt continues to be downloaded (free, no auth) for deprecation tracking of moved/removed entries

### Comparisons Integration

- [x] **COMP-01**: Comparisons system uses shared genemap2 cache (single download per day across both systems)
- [x] **COMP-02**: Comparisons omim_genemap2 parsing calls shared parse_genemap2() to eliminate code duplication

### Configuration & Cleanup

- [ ] **CFG-01**: Docker Compose and .env.example updated with OMIM_DOWNLOAD_KEY variable
- [ ] **CFG-02**: JAX API functions removed (fetch_jax_disease_name, fetch_all_disease_names)
- [ ] **CFG-03**: Hardcoded OMIM download key removed from comparisons_config migration and omim_links.txt

## v2 Requirements

Deferred to future milestones.

- **INFRA-05**: Playwright testing infrastructure in dev container (#140)
- **INFRA-06**: Redis job queue with separate heavy/light workers (#154)
- **INFRA-07**: Automated log cleanup cron job (#105)
- **DEPR-01**: Diff-based deprecation detection (compare genemap2 versions instead of mim2gene)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-container scaling fix (#136) | Separate infrastructure concern |
| Initial password login bug (#142) | Needs deeper investigation, separate milestone |
| VariO ontology replacement (#98) | Feature request, not OMIM related |
| Dynamic HPO hierarchy fetch | Static NDD HPO term list sufficient for filtering |
| Multiple OMIM provider fallbacks | genemap2.txt is sole authoritative source |
| mimTitles.txt integration | genemap2.txt provides disease names directly |
| Real-time OMIM API integration | File-based approach with caching is safer and faster |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 76 | Complete |
| INFRA-02 | Phase 76 | Complete |
| INFRA-03 | Phase 76 | Complete |
| INFRA-04 | Phase 76 | Complete |
| ONTO-01 | Phase 77 | Complete |
| ONTO-02 | Phase 77 | Complete |
| ONTO-03 | Phase 77 | Complete |
| ONTO-04 | Phase 77 | Complete |
| ONTO-05 | Phase 77 | Complete |
| ONTO-06 | Phase 77 | Complete |
| COMP-01 | Phase 78 | Complete |
| COMP-02 | Phase 78 | Complete |
| CFG-01 | Phase 79 | Pending |
| CFG-02 | Phase 79 | Pending |
| CFG-03 | Phase 79 | Pending |

**Coverage:**
- v1 requirements: 15 total
- Mapped to phases: 15 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-02-07*
*Last updated: 2026-02-07 after Phase 78 completion*
