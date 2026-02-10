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
- ✅ **v10.4 OMIM Optimization & Refactor** - Phases 76-79 (shipped 2026-02-07)
- ✅ **v10.5 Bug Fixes & Data Integrity** - Phases 80-82 (shipped 2026-02-09)
- 🔄 **v10.6 Curation UX Fixes & Security** - Phases 83-85

## Phases

<details>
<summary>✅ v1.0 through v10.5 (Phases 1-82) - See MILESTONES.md</summary>

Phases 1-82 delivered across milestones v1.0 through v10.5. See `.planning/MILESTONES.md` for full history.

</details>

### v10.6 Curation UX Fixes & Security

**Goal:** Fix critical curation workflow regressions blocking Christiane's daily work, clean up ghost entities, and patch axios security vulnerability.

| Phase | Title | Goal | Status |
|-------|-------|------|--------|
| 83 | Status Creation Fix & Security | Fix HTTP 500 on status change, verify approve-both restores, update axios | ✅ Complete |
| 84 | Status Change Detection | Add frontend change detection to skip status creation when unchanged | ✅ Complete |
| 85 | Ghost Entity Cleanup & Prevention | Deactivate orphaned entities, prevent future ghosts via atomic creation | ⬚ Not started |

**Phase 83 — Status Creation Fix & Security**
- Fix: Move `resetStatusForm()` before `loadStatusByEntity()` in `showStatusModify()` (ModifyEntity.vue)
- Verify: "Approve both" checkbox appears when status_change exists (ApproveReview.vue)
- Security: Update axios 1.13.4 → 1.13.5 (CVE-2026-25639)
- Requirements: R1, R2, R5
- **Plans:** 1 plan
Plans:
- [x] 83-01-PLAN.md — Fix status form reset ordering, update axios, verify approve-both

**Phase 84 — Status Change Detection**
- Add change detection in ModifyEntity, ApproveReview, ApproveStatus to skip status/review creation when user didn't change anything
- Expose `hasChanges()` from useStatusForm and useReviewForm composables
- Fix missing review_change indicator in ApproveStatus
- Requirements: R3
- **Plans:** 3 plans
Plans:
- [x] 84-01-PLAN.md — Add hasChanges to useStatusForm and useReviewForm composables + tests
- [x] 84-02-PLAN.md — Wire change detection into ModifyEntity (status + review forms)
- [x] 84-03-PLAN.md — Add change detection to ApproveReview and ApproveStatus + fix review_change indicator

**Phase 85 — Ghost Entity Cleanup & Prevention**
- Deactivate entities 4469 (GAP43) and 4474 (FGF14) via migration/script
- Integrate atomic entity creation (`svc_entity_create_with_review_status`) to prevent future orphans
- Requirements: R4

## Progress

| Phase Range | Milestone | Status | Shipped |
|-------------|-----------|--------|---------|
| 1-5 | v1.0 Developer Experience | ✅ Complete | 2026-01-21 |
| 6-9 | v2.0 Docker Infrastructure | ✅ Complete | 2026-01-22 |
| 10-17 | v3.0 Frontend Modernization | ✅ Complete | 2026-01-23 |
| 18-24 | v4.0 Backend Overhaul | ✅ Complete | 2026-01-24 |
| 25-27 | v5.0 Analysis Modernization | ✅ Complete | 2026-01-25 |
| 28-33 | v6.0 Admin Panel | ✅ Complete | 2026-01-26 |
| 34-39 | v7.0 Curation Workflows | ✅ Complete | 2026-01-27 |
| 40-46 | v8.0 Gene Page | ✅ Complete | 2026-01-29 |
| 47-54 | v9.0 Production Readiness | ✅ Complete | 2026-01-31 |
| 55-65 | v10.0 Data Quality & AI Insights | ✅ Complete | 2026-02-01 |
| 66-68 | v10.1 Production Deployment Fixes | ✅ Complete | 2026-02-03 |
| 69-72 | v10.2 Performance & Memory Optimization | ✅ Complete | 2026-02-03 |
| 73-75 | v10.3 Bug Fixes & Stabilization | ✅ Complete | 2026-02-06 |
| 76-79 | v10.4 OMIM Optimization & Refactor | ✅ Complete | 2026-02-07 |
| 80-82 | v10.5 Bug Fixes & Data Integrity | ✅ Complete | 2026-02-09 |
| 83-85 | v10.6 Curation UX Fixes & Security | 🔄 In Progress | — |

---
*Roadmap created: 2026-01-20*
*Last updated: 2026-02-10 — Phase 84 complete*
