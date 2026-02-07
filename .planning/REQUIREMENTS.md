# Requirements: SysNDD v10.4 OMIM Optimization & Refactor

**Defined:** 2026-02-07
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v1 Requirements

Requirements for v10.4 milestone. Each maps to roadmap phases.

### Shared Infrastructure

- [ ] **INFRA-01**: genemap2.txt downloads use OMIM_DOWNLOAD_KEY environment variable (not hardcoded) (#139)
- [ ] **INFRA-02**: genemap2.txt downloads are cached on disk with 1-day TTL to prevent OMIM rate limiting/blocking
- [ ] **INFRA-03**: genemap2.txt parsing handles column name variations defensively (historical field renames)
- [ ] **INFRA-04**: Shared parse_genemap2() function extracts disease name, MIM number, mapping key, and inheritance from Phenotypes column

### Ontology Migration

- [ ] **ONTO-01**: Ontology update uses genemap2.txt for disease names instead of JAX API sequential calls (#139)
- [ ] **ONTO-02**: Ontology update completes in under 60 seconds (was ~8 minutes with JAX API)
- [ ] **ONTO-03**: Inheritance mode information from genemap2.txt is mapped to HPO terms and stored in disease_ontology_set
- [ ] **ONTO-04**: Duplicate MIM numbers retain versioning (OMIM:123456_1, _2) consistent with previous behavior
- [ ] **ONTO-05**: MONDO SSSOM mappings continue to be applied after genemap2 processing (unchanged)
- [ ] **ONTO-06**: mim2gene.txt continues to be downloaded (free, no auth) for deprecation tracking of moved/removed entries

### Comparisons Integration

- [ ] **COMP-01**: Comparisons system uses shared genemap2 cache (single download per day across both systems)
- [ ] **COMP-02**: Comparisons omim_genemap2 parsing calls shared parse_genemap2() to eliminate code duplication

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
| INFRA-01 | TBD | Pending |
| INFRA-02 | TBD | Pending |
| INFRA-03 | TBD | Pending |
| INFRA-04 | TBD | Pending |
| ONTO-01 | TBD | Pending |
| ONTO-02 | TBD | Pending |
| ONTO-03 | TBD | Pending |
| ONTO-04 | TBD | Pending |
| ONTO-05 | TBD | Pending |
| ONTO-06 | TBD | Pending |
| COMP-01 | TBD | Pending |
| COMP-02 | TBD | Pending |
| CFG-01 | TBD | Pending |
| CFG-02 | TBD | Pending |
| CFG-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 15 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 15

---
*Requirements defined: 2026-02-07*
*Last updated: 2026-02-07 after research synthesis*
