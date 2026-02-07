# Roadmap: SysNDD Developer Experience

## Milestones

- ✅ **v1.0 Developer Experience** - Phases 1-5 (shipped 2026-01-21)
- ✅ **v2.0 Docker Infrastructure** - Phases 6-9 (shipped 2026-01-22)
- ✅ **v3.0 Frontend Modernization** - Phases 10-17 (shipped 2026-01-23)
- ✅ **v4.0 Backend Overhaul** - Phases 18-24 (shipped 2026-01-24)
- ✅ **v5.0 Analysis Modernization** - Phases 25-27 (shipped 2026-01-25)
- ✅ **v6.0 Admin Panel** - Phases 28-33 (shipped 2026-01-26)
- ✅ **v7.0 Curation Workflows** - Phases 34-39 (shipped 2026-01-27)
- ✅ **v8.0 Gene Page** - Phases 40-46 (shipped 2026-01-29)
- ✅ **v9.0 Production Readiness** - Phases 47-54 (shipped 2026-01-31)
- ✅ **v10.0 Data Quality & AI Insights** - Phases 55-65 (shipped 2026-02-01)
- ✅ **v10.1 Production Deployment Fixes** - Phases 66-68 (shipped 2026-02-03)
- ✅ **v10.2 Performance & Memory Optimization** - Phases 69-72 (shipped 2026-02-03)
- ✅ **v10.3 Bug Fixes & Stabilization** - Phases 73-75 (shipped 2026-02-06)
- 🚧 **v10.4 OMIM Optimization & Refactor** - Phases 76-79 (in progress)

## Phases

<details>
<summary>✅ v1.0 through v10.3 (Phases 1-75) - See MILESTONES.md</summary>

Phases 1-75 delivered across milestones v1.0 through v10.3. See `.planning/MILESTONES.md` for full history.

</details>

### 🚧 v10.4 OMIM Optimization & Refactor (In Progress)

**Milestone Goal:** Replace slow JAX API sequential workflow with genemap2.txt-based processing, unify OMIM data sources between ontology and comparisons systems, add disk-based caching with 1-day TTL, and move OMIM download key to environment variable.

**Performance improvement:** Ontology update time drops from ~8 minutes to ~30 seconds (eliminates 7-minute JAX API loop).

**Key deliverables:**
- Shared genemap2 infrastructure with download caching and robust parsing
- Ontology system migration to genemap2 with mode of inheritance data
- Unified cache between ontology and comparisons systems
- Environment variable configuration for OMIM download key

#### Phase 76: Shared Infrastructure ✅

**Goal:** Create reusable genemap2 download/parse infrastructure without touching existing systems

**Depends on:** Nothing (foundation phase)

**Requirements:** INFRA-01, INFRA-02, INFRA-03, INFRA-04

**Success Criteria** (what must be TRUE):
1. ✅ Developer can set OMIM_DOWNLOAD_KEY environment variable and genemap2.txt downloads succeed
2. ✅ genemap2.txt file is cached on disk with 1-day TTL (no duplicate downloads within 24 hours)
3. ✅ parse_genemap2() extracts disease name, MIM number, mapping key, and inheritance from Phenotypes column
4. ✅ Parsing handles historical column name variations without breaking (defensive column mapping)
5. ✅ Unit tests verify download caching logic and parsing edge cases

**Plans:** 2 plans

Plans:
- [x] 76-01-PLAN.md — Download infrastructure: env var API key, 1-day TTL caching, check_file_age_days()
- [x] 76-02-PLAN.md — Parse infrastructure: shared parse_genemap2() with fixture-based unit tests

#### Phase 77: Ontology Migration ✅

**Goal:** Replace mim2gene + JAX API with genemap2 in ontology system for 50x+ speed improvement

**Depends on:** Phase 76 (shared infrastructure)

**Requirements:** ONTO-01, ONTO-02, ONTO-03, ONTO-04, ONTO-05, ONTO-06

**Success Criteria** (what must be TRUE):
1. ✅ Ontology update completes in under 60 seconds (was ~8 minutes with JAX API)
2. ✅ Disease names in disease_ontology_set match genemap2.txt Phenotypes column
3. ✅ Inheritance mode information from genemap2 is mapped to HPO terms and stored in disease_ontology_set
4. ✅ Duplicate MIM numbers retain _1, _2 versioning consistent with previous behavior
5. ✅ MONDO SSSOM mappings continue to be applied after genemap2 processing
6. ✅ mim2gene.txt continues to be downloaded for deprecation tracking of moved/removed entries

**Plans:** 2 plans

Plans:
- [x] 77-01-PLAN.md — Create build_omim_from_genemap2() with inheritance mapping, HGNC joining, and versioning
- [x] 77-02-PLAN.md — Rewire process_omim_ontology() to use genemap2 workflow, keep mim2gene for deprecation

#### Phase 78: Comparisons Integration ✅

**Goal:** Unify comparisons system to use shared genemap2 cache (single download per day across both systems)

**Depends on:** Phase 77 (ontology migration stable)

**Requirements:** COMP-01, COMP-02

**Success Criteria** (what must be TRUE):
1. ✅ Comparisons system uses shared genemap2 cache from Phase 76 (data/ directory, not temp_dir)
2. ✅ Only one genemap2.txt download occurs per day regardless of ontology or comparisons update
3. ✅ Comparisons omim_genemap2 parsing calls shared parse_genemap2() (no duplicate parsing code)
4. ✅ Comparisons data refresh job continues to work with same output schema

**Plans:** 2 plans

Plans:
- [x] 78-01-PLAN.md — Add download_hpoa() caching, replace parse_omim_genemap2() with adapt_genemap2_for_comparisons() adapter, modify async workflow, add migration
- [x] 78-02-PLAN.md — Unit tests for adapt_genemap2_for_comparisons() adapter with synthetic fixtures

#### Phase 79: Configuration & Cleanup

**Goal:** Remove deprecated JAX API code, clean up hardcoded keys, externalize OMIM download key to environment variable, unify mim2gene.txt caching

**Depends on:** Phase 78 (both systems using genemap2)

**Requirements:** CFG-01, CFG-02, CFG-03

**Success Criteria** (what must be TRUE):
1. Docker Compose and .env.example updated with OMIM_DOWNLOAD_KEY variable documentation
2. JAX API functions removed from codebase (fetch_jax_disease_name, fetch_all_disease_names)
3. Hardcoded OMIM download key removed from comparisons_config migration and omim_links.txt
4. No dead code remains from JAX API implementation
5. CLAUDE.md and deployment documentation updated with OMIM_DOWNLOAD_KEY configuration

**Plans:** 2 plans

Plans:
- [ ] 79-01-PLAN.md — Docker Compose + .env.example configuration, remove hardcoded OMIM API keys from all files
- [ ] 79-02-PLAN.md — Remove JAX API functions, unify mim2gene.txt caching to 1-day TTL, update tests

## Progress

**Execution Order:** Phases execute sequentially: 76 -> 77 -> 78 -> 79

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 76. Shared Infrastructure | v10.4 | 2/2 | ✅ Complete | 2026-02-07 |
| 77. Ontology Migration | v10.4 | 2/2 | ✅ Complete | 2026-02-07 |
| 78. Comparisons Integration | v10.4 | 2/2 | ✅ Complete | 2026-02-07 |
| 79. Configuration & Cleanup | v10.4 | 0/2 | Not started | - |

---
*Roadmap created: 2026-02-07*
*Last updated: 2026-02-07 after Phase 78 completion*
