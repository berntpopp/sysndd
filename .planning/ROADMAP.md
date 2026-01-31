# Roadmap: SysNDD v10.0 Data Quality & AI Insights

**Created:** 2026-01-31
**Milestone:** v10.0 Data Quality & AI Insights
**Phases:** 55-62 (8 phases)
**Requirements:** 34 mapped

---

## Overview

SysNDD v10.0 stabilizes data quality with 8 major bug fixes, enhances literature research tools (Publications, Pubtator), and adds AI-generated cluster summaries using Gemini API. Bugs are fixed first (user priority), followed by view improvements and LLM integration. The milestone concludes with admin updates and GitHub Pages modernization.

---

## Phase 55: Bug Fixes

**Goal:** All 8 major entity and curation bugs resolved, restoring expected behavior

**Dependencies:** None (foundation phase)

**Plans:** 2 plans

Plans:
- [x] 55-01-PLAN.md - Entity update bugs (EIF2AK2, GAP43, MEF2C)
- [x] 55-02-PLAN.md - Curation workflow bugs (viewer profile, PMID deletion, entities over time, disease renaming, re-reviewer identity)

**Requirements:**
- BUG-01: EIF2AK2 entity (sysndd:4375) - Publication 33236446 update completes correctly (#122)
- BUG-02: GAP43 newly created entity is visible in entity list (#115)
- BUG-03: MEF2C entity (sysndd:4512) updates save correctly (#114)
- BUG-04: Viewer status users can view profile without auto-logout
- BUG-05: Adding new PMID during re-review preserves existing PMIDs
- BUG-06: Entities over time by gene displays correct counts (#44)
- BUG-07: Disease renaming requires approval per review concept (#41)
- BUG-08: Re-reviewer identity preserved when changing reviews

**Success Criteria:**
1. EIF2AK2 entity (sysndd:4375) publication 33236446 update completes without error
2. Newly created entities (e.g., GAP43) appear in entity list immediately after creation
3. MEF2C entity (sysndd:4512) updates save all fields correctly
4. Viewer-status users can view their profile page without auto-logout
5. Adding a new PMID during re-review preserves existing PMIDs (no accidental deletion)
6. Entities-over-time chart displays accurate counts matching database
7. Disease renaming triggers approval workflow per review concept
8. Re-reviewer identity preserved when reviews are modified

---

## Phase 56: Variant Correlations & Publications

**Goal:** Navigation links work correctly; publications view has improved usability

**Dependencies:** Phase 55

**Plans:** 2 plans

Plans:
- [x] 56-01-PLAN.md - Variant navigation fixes
- [x] 56-02-PLAN.md - Publications improvements (table UX, API metadata, TimePlot, Stats)

**Requirements:**
- VCOR-01: VariantCorrelations view navigation links work correctly
- VCOR-02: VariantCounts view navigation links work correctly
- PUB-01: Publications table has improved UX (pagination, search, filters)
- PUB-02: Publication metadata fetched from PubMed API (title, journal, abstract)
- PUB-03: PublicationsNDD TimePlot has improved visualization
- PUB-04: PublicationsNDD Stats view displays correctly

**Success Criteria:**
1. VariantCorrelations view navigation links route to correct destinations
2. VariantCounts view navigation links route to correct destinations
3. Publications table supports pagination, search, and column filters
4. Publication detail shows title, journal, and abstract fetched from PubMed API
5. PublicationsNDD TimePlot renders with improved visualization

---

## Phase 57: Pubtator Improvements

**Goal:** Curators can prioritize genes for review; users can explore gene-literature connections

**Dependencies:** Phase 56

**Plans:** 2 plans

Plans:
- [ ] 57-01-PLAN.md - Pubtator Stats fix and documentation
- [ ] 57-02-PLAN.md - Gene prioritization and research tools

**Requirements:**
- PUBT-01: PubtatorNDD Stats page displays correctly (fix broken)
- PUBT-02: Gene prioritization list ranks genes by publication count, recency, coverage gap
- PUBT-03: Novel gene alerts highlight Pubtator genes not in SysNDD entities
- PUBT-04: User can explore gene-literature connections for research
- PUBT-05: Curator can export prioritized gene list for offline planning
- PUBT-06: Pubtator concept and purpose documented in views

**Success Criteria:**
1. PubtatorNDD Stats page displays without errors
2. Curator can view gene prioritization list ranked by publication count, recency, and coverage gap
3. Curator can see novel gene alerts highlighting Pubtator genes not in SysNDD entities
4. User can explore gene-literature connections for research purposes
5. Curator can export prioritized gene list as CSV/Excel for offline curation planning

---

## Phase 58: LLM Foundation

**Goal:** Gemini API integrated with structured output and entity validation

**Dependencies:** Phase 55 (bug fixes complete before new features)

**Plans:** 2 plans

Plans:
- [ ] 58-01-PLAN.md - Gemini API client with ellmer
- [ ] 58-02-PLAN.md - Entity validation pipeline

**Requirements:**
- LLM-01: Gemini API client integrated using ellmer package
- LLM-02: API key stored securely in environment variable (GEMINI_API_KEY)
- LLM-03: Cluster summaries use structured JSON output schema
- LLM-04: Entity validation checks all gene names exist in database

**Success Criteria:**
1. Gemini API calls work via ellmer package with Gemini 2.0 Flash model
2. API key stored in GEMINI_API_KEY environment variable (not in code)
3. Cluster summaries use structured JSON schema (summary, genes, pathways, confidence)
4. All gene symbols in LLM output validated against non_alt_loci_set before storage

---

## Phase 59: LLM Batch & Caching

**Goal:** Summaries pre-generated via background jobs; cached with hash-based invalidation

**Dependencies:** Phase 58

**Plans:** 2 plans

Plans:
- [ ] 59-01-PLAN.md - Batch generation job
- [ ] 59-02-PLAN.md - Database caching with invalidation

**Requirements:**
- LLM-05: Batch pre-generation job runs via mirai async system
- LLM-06: Summaries cached in database with hash-based invalidation

**Success Criteria:**
1. Batch generation job runs via mirai async system with progress tracking
2. Job checkpoints allow resume after failure
3. Summaries stored in database with cluster hash for invalidation
4. Changed cluster composition triggers re-generation on next batch run

---

## Phase 60: LLM Display

**Goal:** Cluster summaries visible on analysis pages with clear AI provenance

**Dependencies:** Phase 59

**Plans:** 1 plan

Plans:
- [ ] 60-01-PLAN.md - Cluster summary display components

**Requirements:**
- LLM-07: Phenotype cluster summaries generated and displayed
- LLM-08: Functional cluster summaries generated and displayed
- LLM-12: Summaries show "AI-generated" badge with validation status

**Success Criteria:**
1. Phenotype cluster pages display generated summaries
2. Functional cluster pages display generated summaries
3. Summaries show "AI-generated" badge visible to users
4. Badge includes validation status (pending, validated, rejected)

---

## Phase 61: LLM Validation

**Goal:** Quality control via LLM-as-judge and human approval workflow

**Dependencies:** Phase 60

**Plans:** 2 plans

Plans:
- [ ] 61-01-PLAN.md - LLM-as-judge and confidence scoring
- [ ] 61-02-PLAN.md - Admin validation panel

**Requirements:**
- LLM-09: LLM-as-judge validates summary accuracy
- LLM-10: Confidence scoring flags low-confidence summaries
- LLM-11: Admin panel for summary review and approval

**Success Criteria:**
1. LLM-as-judge validates summary accuracy against source data
2. Confidence scores assigned (high/medium/low) with threshold flagging
3. Low-confidence summaries hidden from public view until approved
4. Admin panel displays pending summaries for review and approval/rejection

---

## Phase 62: Admin & Infrastructure

**Goal:** Admin comparisons updated; GitHub Pages deploys via Actions workflow

**Dependencies:** Phase 55 (can run parallel to LLM phases after bugs fixed)

**Plans:** 2 plans

Plans:
- [ ] 62-01-PLAN.md - Admin comparisons update
- [ ] 62-02-PLAN.md - GitHub Pages Actions deployment

**Requirements:**
- ADMIN-01: Admin comparisons functionality updated
- INFRA-01: GitHub Pages deployed via GitHub Actions workflow (not gh-pages branch)

**Success Criteria:**
1. Admin comparisons functionality works correctly
2. GitHub Pages site deploys via GitHub Actions workflow
3. Deployment triggers on push to main and manual dispatch

---

## Progress

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 55 | Bug Fixes | BUG-01 to BUG-08 | ✓ Complete |
| 56 | Variant Correlations & Publications | VCOR-01, VCOR-02, PUB-01 to PUB-04 | ✓ Complete |
| 57 | Pubtator Improvements | PUBT-01 to PUBT-06 | Not started |
| 58 | LLM Foundation | LLM-01 to LLM-04 | Not started |
| 59 | LLM Batch & Caching | LLM-05, LLM-06 | Not started |
| 60 | LLM Display | LLM-07, LLM-08, LLM-12 | Not started |
| 61 | LLM Validation | LLM-09, LLM-10, LLM-11 | Not started |
| 62 | Admin & Infrastructure | ADMIN-01, INFRA-01 | Not started |

**Coverage:** 34/34 requirements mapped (100%)

---

## Dependency Graph

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

---

## Previous Milestones

<details>
<summary>v9.0 Production Readiness (Phases 47-54) - SHIPPED 2026-01-31</summary>

### Phase 47: Migration System Foundation
**Status:** Complete
**Requirements:** MIGR-01, MIGR-02, MIGR-03, MIGR-05
**Plans:** 47-01, 47-02

### Phase 48: Migration Auto-Run & Health
**Status:** Complete
**Requirements:** MIGR-04, MIGR-06
**Plans:** 48-01, 48-02

### Phase 49: Backup API Layer
**Status:** Complete
**Requirements:** BKUP-01, BKUP-03, BKUP-05, BKUP-06
**Plans:** 49-01, 49-02

### Phase 50: Backup Admin UI
**Status:** Complete
**Requirements:** BKUP-02, BKUP-04
**Plans:** 50-01, 50-02

### Phase 51: SMTP Testing Infrastructure
**Status:** Complete
**Requirements:** SMTP-01, SMTP-02
**Plans:** 51-01, 51-02

### Phase 52: User Lifecycle E2E
**Status:** Complete
**Requirements:** SMTP-03, SMTP-04, SMTP-05
**Plans:** 52-01, 52-02

### Phase 53: Production Docker Validation
**Status:** Complete
**Requirements:** PROD-01, PROD-02, PROD-03, PROD-04
**Plans:** 53-01, 53-02

### Phase 54: Docker Infrastructure Hardening
**Status:** Complete
**Requirements:** DOCKER-01 to DOCKER-08
**Plans:** 54-01, 54-02

**Post-Milestone Enhancements:**
- Batch assignment email notification (2026-01-31)
- Self-service profile editing (2026-01-31)

</details>

---

*Roadmap created: 2026-01-31*
*Last updated: 2026-01-31*
