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

**Phase:** 57 (Pubtator Improvements) - In progress
**Plan:** 1/2 complete
**Status:** Plan 01 complete, ready for Plan 02
**Progress:** v10.0 [█████               ] 2.5/8 phases (31%)

**Last completed:** 57-01 - Stats Fix and API Enhancement (PUBT-01 partial, PUBT-02/03 foundation)
**Last activity:** 2026-01-31 — Completed 57-01-PLAN.md

---

## Milestone v10.0 Roadmap

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 55 | Bug Fixes | BUG-01 to BUG-08 | ✓ Complete |
| 56 | Variant Correlations & Publications | VCOR-01, VCOR-02, PUB-01 to PUB-04 | ✓ Complete |
| 57 | Pubtator Improvements | PUBT-01 to PUBT-06 | In progress (1/2) |
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
- Total plans completed: 261
- Milestones shipped: 9 (v1-v9)
- Phases completed: 56

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

### Decisions from Phase 55

**Plan 01 (Entity Bugs):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Created atomic function but kept legacy endpoint | Refactoring /create endpoint would be high-risk; provide function for future use | entity_create_with_review_status() available for future migration |
| 2026-01-31 | Focus on observability over enforcement | Logging provides immediate debugging value without breaking existing flow | PARTIAL CREATION warnings detect orphaned entities in production |
| 2026-01-31 | Used db_with_transaction pattern | Reuse existing battle-tested transaction infrastructure | Consistent error handling and rollback across all atomic operations |

**Plan 02 (Curation Bugs):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Self-service authorization for contributions endpoint | Users should view own data regardless of role | Viewer users can access /user/{id}/contributions for their own ID |
| 2026-01-31 | Warning logging vs hard validation for PMID deletion | Root cause in frontend; blocking would break workflows | Operations continue but losses are detected via logs |
| 2026-01-31 | Floor vs ceiling for time aggregation | Ceiling shifts dates to next period incorrectly | Entities-over-time chart now aligns with database dates |
| 2026-01-31 | Explicit field protection in repository updates | Preserve attribution (review_user_id should never change) | review_update explicitly removes review_user_id from updates |
| 2026-01-31 | Close disease rename approval as wontfix | Current behavior is functional; approval workflow adds complexity without proportional benefit | Issue #41 closed, infrastructure reverted |

### Decisions from Phase 56

**Plan 02 (Publications Enhancements):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | Combined Tasks 1 and 2 | Initialization guards are integral to the caching implementation pattern | Cleaner implementation, single coherent commit |
| 2026-01-31 | Used D3 rollups for time aggregation | Built-in D3 function, cleaner than manual grouping | Consistent with D3 patterns elsewhere in codebase |
| 2026-01-31 | Added YTD label to current year metric | "Publications [year] (YTD)" clarifies it's year-to-date | Clearer user understanding of metric scope |

### Decisions from Phase 57

**Plan 01 (Stats Fix and API Enhancement):**

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2026-01-31 | pmids as comma-separated string | Excel export compatibility - arrays don't export well to XLSX format | pmids field is a string, not JSON array |
| 2026-01-31 | Default sort: -is_novel,oldest_pub_date | Surface coverage gaps (novel genes) first, then prioritize long-overlooked genes | Novel genes appear first in API response |
| 2026-01-31 | Fetch novel count via API filter | Consistent with other stats, avoids downloading all data to client | Admin panel uses filter=is_novel==1 |

---

## Session Continuity

**Last session:** 2026-01-31
**Stopped at:** Completed 57-01-PLAN.md (Stats Fix and API Enhancement)
**Next action:** Execute 57-02-PLAN.md (Genes Table Enhancements)
**Resume file:** None

**Handoff notes:**

1. **v10.0 Roadmap Created (2026-01-31):**
   - 8 phases (55-62), 34 requirements
   - Bug fixes first (Phase 55), then features
   - LLM phases (58-61) form sequential chain
   - Phase 62 can run parallel after Phase 55

2. **Phase 55 Bug Status:**
   - ✅ #122: EIF2AK2 publication update incomplete (BUG-01) - Logging added in 55-01
   - ✅ #115: GAP43 entity not visible (BUG-02) - Atomic function prevents orphaning in 55-01
   - ✅ #114: MEF2C entity updating issues (BUG-03) - Logging detects partial updates in 55-01
   - ✅ Viewer profile / auto-logout (BUG-04) - Fixed in 55-02
   - ✅ PMID deletion during re-review (BUG-05) - Fixed: Frontend now merges original publications with additions in useReviewForm.ts
   - ✅ #44: Entities over time counts incorrect (BUG-06) - Fixed: (1) floor aggregation, (2) removed inheritance filter to match homepage, (3) lessThan with next month for full month inclusion, (4) same NDD filter across all views
   - ✅ #41: Disease renaming bypasses approval (BUG-07) - Closed as wontfix, current behavior is intentional
   - ✅ Re-reviewer identity lost (BUG-08) - Fixed in 55-02

3. **LLM Implementation Notes:**
   - Add ellmer >= 0.4.0 to renv
   - GEMINI_API_KEY in environment variable
   - Structured JSON output with entity validation
   - Batch pre-generation via mirai (no real-time generation)

4. **Phase 57 Progress (Pubtator):**
   - ✅ 57-01: Stats page fixed, API enhanced with prioritization fields
   - API returns: is_novel, oldest_pub_date, pmids (CSV string)
   - Admin panel shows Pubtator cache stats
   - Ready for 57-02: Genes table with prioritization display

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-31 — Completed 57-01-PLAN.md (Pubtator Stats Fix and API Enhancement)*
