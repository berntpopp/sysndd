# Project State: SysNDD

**Last updated:** 2026-01-31
**Current milestone:** v10.0 Data Quality & AI Insights

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-31)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v10.0 — Bug fixes, Publications/Pubtator improvements, LLM cluster summaries

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 55 (Bug Fixes)
**Plan:** Not started
**Status:** Ready to plan
**Progress:** v10.0 [                    ] 0/8 phases

**Last completed:** v9.0 Production Readiness milestone shipped
**Last activity:** 2026-01-31 — v10.0 roadmap created

---

## Milestone v10.0 Roadmap

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 55 | Bug Fixes | BUG-01 to BUG-08 | Not started |
| 56 | Variant Correlations & Publications | VCOR-01, VCOR-02, PUB-01 to PUB-04 | Not started |
| 57 | Pubtator Improvements | PUBT-01 to PUBT-06 | Not started |
| 58 | LLM Foundation | LLM-01 to LLM-04 | Not started |
| 59 | LLM Batch & Caching | LLM-05, LLM-06 | Not started |
| 60 | LLM Display | LLM-07, LLM-08, LLM-12 | Not started |
| 61 | LLM Validation | LLM-09, LLM-10, LLM-11 | Not started |
| 62 | Admin & Infrastructure | ADMIN-01, INFRA-01 | Not started |

**Phases:** 8 (55-62)
**Requirements:** 34 mapped (100% coverage)

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 256
- Milestones shipped: 9 (v1-v9)
- Phases completed: 54

**By Milestone:**

| Milestone | Phases | Plans | Shipped |
|-----------|--------|-------|---------|
| v1 Developer Experience | 1-5 | 19 | 2026-01-21 |
| v2 Docker Infrastructure | 6-9 | 8 | 2026-01-22 |
| v3 Frontend Modernization | 10-17 | 53 | 2026-01-23 |
| v4 Backend Overhaul | 18-24 | 42 | 2026-01-24 |
| v5 Analysis Modernization | 25-27 | 16 | 2026-01-25 |
| v6 Admin Panel Modernization | 28-33 | 20 | 2026-01-26 |
| v7 Curation Workflow Modernization | 34-39 | 21 | 2026-01-27 |
| v8 Gene Page & Genomic Data | 40-46 | 25 | 2026-01-29 |
| v9 Production Readiness | 47-54 | 16 | 2026-01-31 |
| v10 Data Quality & AI Insights | 55-62 | TBD | In progress |

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 687 + 11 E2E | 20.3% coverage, 24 integration + 53 migration + 11 E2E tests |
| **Frontend Tests** | 144 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 28 | 7 original + 6 admin + 10 curation + 5 gene page |
| **Migrations** | 3 files + runner | api/functions/migration-runner.R ready |
| **Lintr Issues** | 0 | From 1,240 in v4 |
| **ESLint Issues** | 0 | 240 errors fixed in v7 |
| **Bundle Size** | ~600 KB gzipped | Vite 7.3.1, 164ms dev startup |

---

## Accumulated Context

### Phase Dependencies (v10.0)

```
Phase 55 (Bug Fixes)
    |
    +---------------------------+
    |                           |
    v                           v
Phase 56 (Variant & Pubs)  Phase 58 (LLM Foundation)
    |                           |
    v                           v
Phase 57 (Pubtator)        Phase 59 (LLM Batch & Caching)
                                |
                                v
                           Phase 60 (LLM Display)
                                |
                                v
                           Phase 61 (LLM Validation)

Phase 62 (Admin & Infra) can run parallel after Phase 55
```

### Research Findings (from research/SUMMARY.md)

- **Use ellmer >= 0.4.0** for Gemini API (not gemini.R)
- **Entity validation mandatory** — LLMs invent plausible gene names
- **LLM-as-judge has 64-68% agreement** — use rule-based validators as primary
- **easyPubMed deprecated functions** retiring 2026 — update to epm_* API
- **Existing patterns cover 80%** — external-proxy, mirai jobs, pubtator caching

### Key Technical Notes

1. **LLM integration point:** New `api/functions/llm-service.R` following external-proxy pattern
2. **Summary storage:** New `llm_cluster_summary_cache` table following pubtator cache pattern
3. **Batch generation:** Follow HGNC update job pattern via mirai
4. **Summary display:** Extend AnalyseGeneClusters.vue and AnalysesPhenotypeClusters.vue
5. **Admin panel:** Follow ManageAnnotations.vue pattern

---

## Session Continuity

**Last session:** 2026-01-31
**Stopped at:** v10.0 roadmap created
**Next action:** `/gsd:plan-phase 55` to create Phase 55 plans

**Handoff notes:**

1. **v10.0 Roadmap Created (2026-01-31):**
   - 8 phases (55-62), 34 requirements
   - Bug fixes first (Phase 55), then features
   - LLM phases (58-61) form sequential chain
   - Phase 62 can run parallel after Phase 55

2. **Phase 55 Priority Bugs:**
   - #122: EIF2AK2 publication update incomplete
   - #115: GAP43 entity not visible
   - #114: MEF2C entity updating issues
   - Viewer profile / auto-logout
   - PMID deletion during re-review
   - #44: Entities over time counts incorrect
   - #41: Disease renaming / re-reviewer identity

3. **LLM Implementation Notes:**
   - Add ellmer >= 0.4.0 to renv
   - GEMINI_API_KEY in environment variable
   - Structured JSON output with entity validation
   - Batch pre-generation via mirai (no real-time generation)

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-31 — v10.0 roadmap created*
