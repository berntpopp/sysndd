# Requirements: SysNDD v10.3 Bug Fixes & Stabilization

**Defined:** 2026-02-05
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v1 Requirements

Requirements for v10.3 milestone. Each maps to roadmap phases.

### API Bug Fixes

- [x] **API-01**: Direct approval entity creation no longer returns 500 error (#166)
- [x] **API-02**: Panels page loads successfully with all allowed columns matching query results (#161)
- [x] **API-03**: Clustering endpoints handle empty tibbles in rowwise context without crashing (#155)

### Data Infrastructure

- [x] **DATA-01**: Database migration widens ndd_database_comparison columns to prevent truncation (#158)
- [x] **DATA-02**: Database migration updates Gene2Phenotype source URL and file_format to new API (#156)
- [x] **DATA-03**: Stale memoization cache is invalidated when code changes affect cached data structures (#157)

### Frontend Fixes

- [x] **FE-01**: Documentation links point to correct numbered-prefix URLs on GitHub Pages (#162)
- [x] **FE-02**: Table column headers display statistics/metadata on hover (#164)

### Frontend UX Improvements

- [x] **UX-01**: Create Entity phenotype selection uses same multiselect component as ModifyEntity (#165)
- [x] **UX-02**: Associated Entities section appears above Constraint and ClinVar sections in Genes view (#163)

## v2 Requirements

Deferred to future milestones.

- **INFRA-01**: Playwright testing infrastructure in dev container (#140)
- **INFRA-02**: Redis job queue with separate heavy/light workers (#154)
- **INFRA-03**: Automated log cleanup cron job (#105)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-container scaling fix (#136) | Separate infrastructure concern, not a bug fix |
| Initial password login bug (#142) | Needs deeper investigation, separate milestone |
| VariO ontology replacement (#98) | Feature request, not stabilization |
| Curation matrix links (#89) | Feature request, not stabilization |
| CurationComparisons input style (#83) | Low priority cosmetic issue |
| Editable static content via UI (#58) | Feature request, deferred |
| OMIM update optimization (#139) | Performance enhancement, not a bug |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| API-01 | Phase 74 | Complete |
| API-02 | Phase 74 | Complete |
| API-03 | Phase 74 | Complete |
| DATA-01 | Phase 73 | Complete |
| DATA-02 | Phase 73 | Complete |
| DATA-03 | Phase 73 | Complete |
| FE-01 | Phase 75 | Complete |
| FE-02 | Phase 75 | Complete |
| UX-01 | Phase 75 | Complete |
| UX-02 | Phase 75 | Complete |

**Coverage:**
- v1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-02-05*
*Last updated: 2026-02-06 -- Phase 75 complete (FE-01, FE-02, UX-01, UX-02)*
