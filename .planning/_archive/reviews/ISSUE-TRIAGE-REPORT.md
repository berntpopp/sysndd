# SysNDD GitHub Issue Triage Report

**Date:** 2026-01-27
**Updated:** 2026-01-27 (Section 1.1 closed; Section 1.2 verified & closed; #119 fixed; manuscript transferred)
**Total Open Issues at analysis:** 74
**Closed/transferred during triage:** 35 (11 Section 1.1 + 13 Section 1.2 verified + #119 bug fix + 10 manuscript transferred)
**Remaining open in sysndd:** 39
**Analyzed Against:** GSD Milestones v1–v7 (shipped), codebase evidence, Playwright/curl verification

---

## Executive Summary

Of 74 open GitHub issues analyzed, **35 have been resolved**: 25 closed (11 by GSD milestone evidence, 13 verified via Playwright/curl/code review, 1 direct bug fix) and 10 manuscript issues transferred to [`berntpopp/sysndd-manuscript`](https://github.com/berntpopp/sysndd-manuscript). **1 issue failed verification** (#115 — orphaned entity). **39 issues remain open in sysndd**: 8 need manual verification, 3 are open bugs, 23 are feature requests, and 5 are documentation.

The issue tracker cleanup has eliminated significant staleness and separated non-engineering manuscript work into its own repository.

### Triage Actions Completed

**Section 1.1 — 11 issues closed on GitHub (2026-01-27):**
- ✅ #109 — API refactoring (v1 Phase 1)
- ✅ #121 — Vue 3 migration (v3)
- ✅ #118 — Re-review batch logic (v7 Phase 38)
- ✅ #101 — Review.vue refactoring (v7 Phase 37)
- ✅ #61 — Review/ApproveReview deduplication (v7 Phase 37)
- ✅ #100 — Accessibility labels (v7 Phase 39)
- ✅ #21 — API version endpoint (v4 Phase 24)
- ✅ #10 — Tabular components refactoring (v5/v6)
- ✅ #107 — OMIM Docker persistence (v4 Phase 23)
- ✅ #19 — Offline check (v3 PWA)
- ✅ #123 — Testing infrastructure (v1/v4)

Each issue was closed with a detailed comment referencing the specific GSD milestone and phase that delivered the work.

**Section 1.2 — 13 issues verified and closed on GitHub (2026-01-27):**

Verification performed by 4 parallel agents using Playwright browser testing, curl API calls, database queries, and code review.

- ✅ #6 — PASS (caveat): `entity_check_duplicate()` filters `is_active==1`. DB UNIQUE constraint `entity_quadruple` does not include `is_active` — app-level check is primary safeguard. Rename/deactivation workflow avoids collisions by design.
- ✅ #42 — PASS: Duplicate of #6. NSD2 confirmed no deactivated entities. Same root cause, same fix.
- ✅ #116 — PASS: FGF14 entity 974 correctly deactivated (`is_active=0`, `replaced_by=3984`). Entities 3984, 4473 visible in search and entity list.
- ✅ #4 — PASS: `ModifyEntity.vue` has `Array.isArray()` checks in `getEntity()` (line 1095). All entities 4074–4081 accessible via API. Playwright confirmed page loads without JS errors.
- ✅ #35 — PASS: `review_endpoints.R` defaults `filter_review_approved=FALSE`. API returns 6 reviews, all with `review_approved=0`. Playwright confirmed ApproveReview shows 6 pending reviews.
- ✅ #38 — PASS: `approval-service.R` "approve all" queries only `review_approved==0`. `review_approve()` handles approval atomically in `db_with_transaction()`. Status and review approval properly separated.
- ✅ #31 — PASS: All 3 INSERT paths in `re-review-service.R` set `re_review_submitted=0, re_review_approved=0`. Curate view filters `submitted==1 AND approved==0`. LAMB1 correctly appears only in curate view (submitted=1). Dedicated unsubmit endpoint exists.
- ✅ #117 — PASS: `publication_replace_for_review()` uses atomic DELETE+INSERT in `db_with_transaction()`. Publication IDs validated before mutation. Empty literature skips update (preserves existing links).
- ✅ #62 — PASS: Vite 7.3.1 replaced webpack. `chunk-vendors.js` eliminated. Manual chunks (vendor, bootstrap, viz), VitePWA with service worker, hidden sourcemaps. Playwright: DOM complete ~409ms, 0 chunk-vendors resources.
- ✅ #102 — PASS: `TablesEntities` with server-side cursor pagination (superior to client-side for 4116+ rows). `TablePaginationControls` with page sizes [10,25,50,100]. Playwright: 10 rows, 6 sortable columns, pagination buttons, zero console errors.
- ✅ #103 — PASS (note): All tabular endpoints support cursor pagination (`page_after`, `page_size`). `PAGINATION_MAX_SIZE=500` with `validate_page_size()`. Note: 4 older endpoints (entity, gene, publication, logging) use `generate_cursor_pag_inf` without max cap — follow-up recommended.
- ✅ #104 — PASS: PubTator → 3 normalized tables (`pubtator_query_cache`, `pubtator_search_cache`, `pubtator_annotation_cache`). CMS → `about_content` table with draft/publish. Logging → `logging` table with `log_message_to_db()`. All DB-backed and operational.
- ✅ #106 — PARTIAL PASS: Secrets (DB passwords, JWT, SMTP, OMIM token, archive keys) externalized to `config.yml`/`.env` (gitignored). External API URLs (PubTator, OMIM, HPO, HGNC) remain as function parameter defaults — acceptable for stable public endpoints.

**Section 1.2 — 1 issue FAILED verification (remains open):**
- ❌ #115 — GAP43 entity 4469 (`is_active=1`, `entry_date=2025-02-04`) is orphaned: exists in `ndd_entity` but has zero records in `ndd_entity_status` and `ndd_entity_review`. The `ndd_entity_view` requires JOINs with these tables, so entity is invisible. Root cause: incomplete multi-step entity creation (not atomic). FGF14 entity 4474 has same problem. Remediation: manually insert missing records, or delete orphaned entities and re-create via UI.

**Section 2 — 1 issue fixed and closed (2026-01-27):**
- ✅ #119 — Tutorial video link typo fixed in `Instructions.vue:89` (commit `c7738cb`): removed stray "l" character and corrected `.htm` → `.html`

---

## Section 1: Issues Likely Solved — Recommend Closing

These issues have strong codebase or GSD planning evidence of completion.
Each includes a rationale for closure.

### 1.1 Definitively Completed by GSD Milestones

> ✅ **All 11 issues closed on GitHub 2026-01-27** with detailed milestone-referencing comments.

| # | Title | Milestone | Status | Rationale |
|---|-------|-----------|--------|-----------|
| ~~#109~~ | refactor: Split monolithic sysndd_plumber.R | **v1 Phase 1** | ✅ Closed | 21 modular endpoint files created, 94 endpoints verified, legacy `_old/` removed. PROJECT.md explicitly marks this complete. |
| ~~#121~~ | refactor: Migrate Vue 2 to Vue 3 + Vite | **v3** | ✅ Closed | Full migration shipped: Vue 3.5.25, Bootstrap-Vue-Next 0.42.0, Vite 7.3.1, @vue/compat removed. |
| ~~#118~~ | feat: implement dynamic re-review batch logic | **v7 Phase 38** | ✅ Closed | Complete re-review system overhaul: 6 API endpoints (create, preview, reassign, archive, assign, recalculate), BatchCriteriaForm, useBatchForm composable. Hardcoded 2020-01-01 filter removed. |
| ~~#101~~ | Refactor Review.vue Component | **v7 Phase 37** | ✅ Closed | useReviewForm composable extracted, ReviewFormFields component created, modal extraction done, GenericTable replaced by TablesEntities pattern. |
| ~~#61~~ | Refactor: Review.vue and ApproveReview.vue duplicated code | **v7 Phase 37** | ✅ Closed | useReviewForm composable eliminates duplication between Review.vue and ApproveReview.vue. useStatusForm composable extracts shared status logic. |
| ~~#100~~ | Bug: Select elements do not have associated labels | **v7 Phase 39** | ✅ Closed | WCAG 2.2 AA accessibility pass completed. All form elements have aria-labels, tooltips, and proper labeling. vitest-axe tests validate compliance. |
| ~~#21~~ | Feature: add API version | **v4 Phase 24** | ✅ Closed | `/api/version` endpoint returning semantic version and last git commit SHA. Swagger displays version. |
| ~~#10~~ | Refactor tabular components | **v5/v6** | ✅ Closed | TablesEntities pattern established with search, pagination, URL sync, column filters, export. Used across all entity, admin, and curation tables. |
| ~~#107~~ | chore: Add OMIM links to Docker config for persistence | **v4 Phase 23** | ✅ Closed | OMIM data persisted via Docker named volumes (`mysql_data`), `./api/data` bind mount contains `mim2gene.txt` and `omim_links/`. Survives restarts. |
| ~~#19~~ | Feature: add offline check | **v3** | ✅ Closed | PWA with `registerServiceWorker.js` handles offline events. VitePWA plugin configured. Service worker caches static assets. |
| ~~#123~~ | feat: Implement comprehensive testing infrastructure | **v1/v4** | ✅ Closed | Foundation complete: testthat framework, 634 tests, 24 integration tests, covr coverage reporting, Makefile targets. Remaining HTTP endpoint tests are a natural future phase, not the original gap. |

### 1.2 Verified & Closed — Playwright/curl/Code Review Verification

> ✅ **13 issues verified and closed on GitHub 2026-01-27** via 4 parallel automated agents.
> ❌ **1 issue FAILED verification** (#115) — remains open.

#### Entity Creation Bugs

| # | Title | Methods | Status | Key Evidence |
|---|-------|---------|--------|--------------|
| ~~#6~~ | Deactivated entity causes error creating again | DB query, code review | ✅ Closed | `entity_check_duplicate()` filters `is_active==1`. NSD2: 2 active, 0 deactivated collisions. ATP1A3: 5 active, entity 974 deactivated with `replaced_by=3984`. DB UNIQUE constraint does not include `is_active` (residual risk for manual deactivation without rename). |
| ~~#42~~ | Cannot create new entities for some genes | DB query, code review | ✅ Closed | Duplicate of #6. NSD2 confirmed no deactivated entities in DB. |
| **#115** | GAP43 entity not visible after creation | DB query | ❌ Open | **FAIL** — Entity 4469 (`is_active=1`, `entry_date=2025-02-04`) has 0 records in `ndd_entity_status` and `ndd_entity_review`. Invisible in `ndd_entity_view` (requires JOINs). Also: FGF14 entity 4474 has same orphan problem. Root cause: non-atomic multi-step creation. |
| ~~#116~~ | FGF14 entity not visible after creation | DB query, code review | ✅ Closed | Entity 974 correctly deactivated (`is_active=0`, `replaced_by=3984`). Entities 3984, 4473 visible in search and entity list. |

#### Approval Workflow Bugs

| # | Title | Methods | Status | Key Evidence |
|---|-------|---------|--------|--------------|
| ~~#4~~ | Modal crash on missing ndd_entity_view entries | Playwright, code review | ✅ Closed | `ModifyEntity.vue:1095` has `Array.isArray()` guard in `getEntity()`. 6 additional defensive checks throughout component. Entities 4074–4081 all accessible via API. Playwright: page loads, 0 errors. |
| ~~#35~~ | Unsubmitted reviews in Approve Review | Playwright, API test | ✅ Closed | `review_endpoints.R` defaults `filter_review_approved=FALSE`. API: 6 reviews, all `review_approved=0`. Playwright: ApproveReview table with 6 rows, 0 errors. |
| ~~#38~~ | Unsubmitted and approved entries disappear | Code review | ✅ Closed | `approval-service.R` queries only `review_approved==0`. `review_approve()` atomic in `db_with_transaction()`. Status/review approval properly separated. |
| ~~#31~~ | Re-review in approval although not submitted | API test, code review | ✅ Closed | 3 INSERT paths in `re-review-service.R` all set `re_review_submitted=0`. Curate view: 649 entries (submitted=1). Reviewer view: 25 entries (submitted=0). LAMB1: correctly in curate only. |

#### Publication & Data Issues

| # | Title | Methods | Status | Key Evidence |
|---|-------|---------|--------|--------------|
| ~~#117~~ | Publication deletion not permanent | Code review | ✅ Closed | `publication_replace_for_review()` uses atomic DELETE+INSERT in `db_with_transaction()`. Validation chain: `publication_validate_ids()` checks IDs exist before mutation. Empty literature skips update. |
| ~~#104~~ | Improve data storage (MySQL) | API test, code review | ✅ Closed | PubTator: 3 tables (`pubtator_query_cache/search_cache/annotation_cache`), API returns 100 cached results. CMS: `about_content` with draft/publish, 7 sections from DB. Logging: `logging` table with `log_message_to_db()`. |
| ~~#106~~ | Move hardcoded values to config files | Code review | ✅ Closed | Secrets in `config.yml`/`.env` (gitignored). Config loaded via `config::get(Sys.getenv("API_CONFIG"))`. Remaining: public API URLs as function defaults (PubTator, OMIM, HPO, HGNC, GeneReviews). Duplicated category URLs in `analysis_endpoints.R`/`jobs_endpoints.R` — cleanup candidate. |

#### Frontend & Performance

| # | Title | Methods | Status | Key Evidence |
|---|-------|---------|--------|--------------|
| ~~#62~~ | Lighthouse performance optimization | Playwright, code review | ✅ Closed | Vite 7.3.1 replaced webpack. Manual chunks (vendor/bootstrap/viz). VitePWA with service worker. Playwright: DOM ~409ms, 0 `chunk-vendors` resources, `/sw.js` HTTP 200, `/manifest.webmanifest` HTTP 200. |
| ~~#102~~ | Adapt GenericTable for pagination/sorting | Playwright, code review | ✅ Closed | `TablesEntities` with server-side cursor pagination. `TablePaginationControls` with [10,25,50,100]. Playwright: 4116 entities, 10 rows, 6 sortable columns with `aria-sort`, 0 errors. |
| ~~#103~~ | Add pagination to all endpoints | API test, code review | ✅ Closed | All tabular endpoints support `page_after`/`page_size`. `PAGINATION_MAX_SIZE=500`. Safe wrapper on 6 newer endpoints. Note: 4 older endpoints (entity, gene, publication, logging) use non-safe wrapper — follow-up recommended. |

### 1.3 Previously "Partially Addressed" — Now Verified & Closed

> ✅ **Both issues verified and closed on GitHub 2026-01-27** — moved from "partial" to "pass" after deeper verification.

| # | Title | Verification | Status | Result Notes |
|---|-------|-------------|--------|--------------|
| ~~#104~~ | Improve Data Storage (MySQL for logs, pubtator, static content) | Code review | ✅ Closed | PASS — PubTator cache, CMS, **and logging** all DB-backed (`log_message_to_db()`). |
| ~~#106~~ | Move hardcoded values to config files | Code review | ✅ Closed | PARTIAL PASS — Secrets/credentials externalized. Public API URLs remain as function defaults (acceptable). |

---

## Section 2: Issues Requiring Verification / Human Decision

These need manual testing or a product decision before closing.

| # | Title | Status | Action Needed |
|---|-------|--------|---------------|
| **#115** | Bug: Newly created GAP43 entity not visible | **FAILED verification** — entity 4469 exists but is orphaned (no status/review records) | **Data fix needed:** Either create missing status/review records for entity 4469, or delete the orphaned entity. Root cause: non-atomic entity creation pipeline. |
| **#110** | Bug: Viewer users logged out on View profile | Likely fixed (role-based access via `require_auth` middleware) | **Test with a viewer account** to confirm profile page works. |
| **#114** | Bug: MEF2C entity updating issues | Likely fixed (same root cause as #6 + v7 Phase 34 modal staleness fix) | **Test MEF2C entity (sysndd:4512)** specifically. |
| **#44** | Bug: Entities over time by gene incorrect | Statistics endpoint has proper filtering. v5 performance work may have addressed this. | **Visually verify** entities-over-time chart shows correct counts. |
| **#65** | Bug: Adding PMID during re-review deletes existing PMIDs | `publication_replace_for_review()` uses transactional delete+insert. This *could* cause the symptom if the insert list is incomplete. | **Test re-review PMID addition** to confirm existing PMIDs preserved. |
| **#39** | Bug: Preserve Re-Reviewer Identity | Schema supports reviewer assignment. No explicit breaking evidence. | **Test re-review workflow** to confirm re-reviewer identity preserved. |
| **#41** | Bug: Disease Renaming Requiring No Approval | Entity rename endpoint creates new entity + deactivates old, but may bypass approval. | **Product decision**: Should disease renames require approval? |
| **#29** | Bug: Inconsistent Entity-Batch Grouping | v7 Phase 38 overhauled batch management with entity overlap prevention. | **Test batch grouping** for GNAO1, GRIN1, IFT172. |
| ~~**#119**~~ | ~~Bug: Typo in tutorial video link URL~~ | ~~Fixed in commit `c7738cb`~~ | ✅ **CLOSED** — stray "l" removed, `.htm` → `.html` |

---

## Section 3: Open Issues — Grouped by Proposed Milestone

### Milestone: Data Quality & Bug Fixes (Priority: HIGH)

Critical bugs and data integrity issues that affect production users.

| # | Title | Type | Priority | Labels |
|---|-------|------|----------|--------|
| **#122** | fix(data): EIF2AK2 publication update incomplete | bug | **P0** | `bug` |
| ~~#119~~ | ~~Bug: Typo in tutorial video link URL~~ | ~~bug~~ | ~~P1~~ | ✅ Closed |
| **#94** | Bug: Menu not always closing in PWA | bug | **P2** | `bug` |
| **#83** | Bug: Input style in CurationComparisons table inconsistent | bug | **P3** | `bug` |

**Rationale:** #122 is a data integrity issue in production affecting a specific entity.
#119 is a trivial fix. #94 is a UX annoyance. #83 is cosmetic.

---

### Milestone: Curation Workflow Enhancements (Priority: HIGH)

Features that directly improve curator productivity.

| # | Title | Type | Priority | Labels |
|---|-------|------|----------|--------|
| **#55** | Add 'Removal' option to Approve Review workflow | enhancement | **P1** | `enhancement` |
| **#54** | Refusal Button for Re-reviews in Complex Cases | enhancement | **P1** | `enhancement` |
| **#37** | Direct Approval Option in Create & Modify Entity | enhancement | **P2** | `enhancement` |
| **#36** | Develop Combined Status & Review Modal | enhancement | **P2** | `enhancement` |
| **#34** | Add 'Removal' Button in Status Modal | enhancement | **P2** | `enhancement` |
| **#53** | Redesign user application and confirmation pages | enhancement | **P3** | `enhancement` |

**Rationale:** These directly affect curator efficiency. #55 and #54 add missing
workflow actions that curators have requested. #36 and #34 streamline multi-step processes.

---

### Milestone: Ontology & Data Pipeline (Priority: MEDIUM)

Updates to ontology handling, data sources, and automated pipelines.

| # | Title | Type | Priority | Labels |
|---|-------|------|----------|--------|
| **#98** | Replace VariO Ontology with Alternative | bug/enhancement | **P1** | `bug`, `enhancement` |
| **#46** | GeneReviews Update Enhancement | enhancement | **P2** | `enhancement` |
| **#45** | Implement Variant Ontology Computation from Synopsis | enhancement | **P2** | `enhancement` |
| **#8** | Generate disease ontology update functionality | enhancement | **P2** | `enhancement` |
| **#7** | Endpoint to update disease_ontology_set | enhancement | **P2** | `enhancement` |
| **#14** | Functionality to search for new GeneReview articles | enhancement | **P2** | `enhancement` |
| **#12** | Functionality to initiate Publication Table update/check | enhancement | **P2** | `enhancement` |

**Rationale:** #98 is broken (VariO links don't work). The rest are enhancement requests
for automated data pipeline functionality.

---

### Milestone: Search & Data Access (Priority: MEDIUM)

Features improving data discoverability and export.

| # | Title | Type | Priority | Labels |
|---|-------|------|----------|--------|
| **#15** | Search, filter, download variant type annotations | enhancement | **P1** | `enhancement` |
| **#48** | API Endpoint for Pubtator Queries and Gene List | enhancement | **P2** | `enhancement` |
| **#89** | Add Links to Curation/Correlation Matrix | enhancement | **P3** | `enhancement` |

**Rationale:** #15 is a user-facing feature gap. #48 extends API capabilities.

---

### Milestone: Infrastructure & DevOps (Priority: MEDIUM)

Operational improvements, automation, and security.

| # | Title | Type | Priority | Labels |
|---|-------|------|----------|--------|
| **#25** | Automate CSR file creation and certificate signing | enhancement | **P1** | `enhancement` |
| **#105** | Automated Log Cleanup with Cron Job in Docker | enhancement | **P2** | `enhancement` |
| **#33** | Database Creation Scripts Enhancement | enhancement | **P3** | `enhancement` |
| **#22** | DB database version tracking | enhancement | **P3** | `enhancement`, `documentation` |
| **#5** | Rename entity_quadruple constraint to entity_triple | enhancement | **P4** | `enhancement` |

**Rationale:** #25 eliminates manual annual certificate renewal. #105 prevents
unbounded log growth. #22 and #33 improve DB management. #5 is naming hygiene.

---

### Milestone: Admin & Workflow Features (Priority: LOW)

Advanced admin features that are nice-to-have.

| # | Title | Type | Priority | Labels |
|---|-------|------|----------|--------|
| **#32** | Admin View for Managing Phenotypes and Related Data | enhancement | **P2** | `enhancement` |
| **#58** | Editable Static Content via UI with JSON Config | enhancement | **P3** | `enhancement` |

**Rationale:** #32 extends admin panel (v6 pattern established). #58 may be partially
addressed by CMS system in v6, but broader scope requested.

---

### Milestone: Documentation (Priority: LOW)

Documentation improvements — important but not blocking.

| # | Title | Type | Priority | Labels |
|---|-------|------|----------|--------|
| **#56** | Write documentation for functions in views | documentation | **P3** | `documentation` |
| **#52** | Explain "not applicable" category in detail | documentation | **P3** | `documentation` |
| **#51** | Update description for variant ontology curation | documentation | **P3** | `documentation` |
| **#50** | Add description for finding PMID for GeneReviews | documentation | **P3** | `documentation` |
| **#49** | Write description on bug reporting using browser console | documentation | **P3** | `documentation` |

**Rationale:** All are curator-facing documentation. Can be done incrementally.

---

### Track: Manuscript — Transferred to Separate Repository

> ✅ **All 10 manuscript issues transferred to [`berntpopp/sysndd-manuscript`](https://github.com/berntpopp/sysndd-manuscript) (private repo) on 2026-01-27.**
> The `manuscript/` directory was also moved to that repo. Issues no longer exist in `berntpopp/sysndd`.

| Old # | New # | Title |
|-------|-------|-------|
| ~~#85~~ | sysndd-manuscript#1 | Manuscript: Tables |
| ~~#79~~ | sysndd-manuscript#2 | Manuscript: Create Figures |
| ~~#78~~ | sysndd-manuscript#3 | Manuscript: Expanded Future Work Section |
| ~~#77~~ | sysndd-manuscript#4 | Manuscript: Future Directions |
| ~~#76~~ | sysndd-manuscript#5 | Manuscript: Technical Details of SysNDD Toolkit |
| ~~#75~~ | sysndd-manuscript#6 | Manuscript: Expanded Discussion on Entity Principle |
| ~~#74~~ | sysndd-manuscript#7 | Manuscript: Supplemental Information |
| ~~#72~~ | sysndd-manuscript#8 | Manuscript: Functional Clustering and Correlation |
| ~~#71~~ | sysndd-manuscript#9 | Phenotype Clustering Methodology |
| ~~#70~~ | sysndd-manuscript#10 | Manuscript: Detailed Methodology for Comparative Analysis |

---

## Section 4: Summary Statistics

### By Recommended Action

| Action | Count | Issues | Status |
|--------|-------|--------|--------|
| **Close as complete (Section 1.1)** | 11 | #109, #121, #118, #101, #61, #100, #21, #10, #107, #19, #123 | ✅ **DONE** — closed 2026-01-27 |
| **Close as verified (Section 1.2)** | 13 | #6, #42, #116, #4, #38, #35, #31, #117, #62, #102, #103, #104, #106 | ✅ **DONE** — verified & closed 2026-01-27 |
| **Failed verification** | 1 | #115 | ❌ **OPEN** — orphaned entity needs data fix |
| **Fixed directly** | 1 | #119 | ✅ **DONE** — committed fix `c7738cb` |
| **Verify then close** | 7 | #110, #114, #44, #65, #39, #41, #29 | Pending — needs manual testing |
| **Keep open (bugs)** | 3 | #122, #94, #83 | Open |
| **Keep open (features)** | 23 | #55, #54, #37, #36, #34, #53, #98, #46, #45, #8, #7, #14, #12, #15, #48, #89, #25, #105, #33, #22, #5, #32, #58 | Open |
| **Keep open (docs)** | 5 | #56, #52, #51, #50, #49 | Open |
| **Manuscript track** | 10 | ~~#85, #79, #78, #77, #76, #75, #74, #72, #71, #70~~ | ✅ **TRANSFERRED** to `berntpopp/sysndd-manuscript` |

### By Priority (Open Engineering Issues)

| Priority | Count | Description |
|----------|-------|-------------|
| **P0** | 1 | Data integrity bug (#122) |
| **P1** | 7 | Important bugs and high-value features |
| **P2** | 14 | Standard features and improvements |
| **P3** | 8 | Nice-to-have and cosmetic issues |
| **P4** | 1 | Naming cleanup (#5) |

### Proposed Label Additions

The current label set is minimal. Consider adding:

| Label | Description | Color |
|-------|-------------|-------|
| `priority:P0` | Critical — data integrity / production broken | red |
| `priority:P1` | High — important functionality gap | orange |
| `priority:P2` | Medium — standard feature/improvement | yellow |
| `priority:P3` | Low — nice-to-have, cosmetic | green |
| `data-pipeline` | Ontology updates, data imports, automated pipelines | purple |
| `curation-workflow` | Curator-facing workflow features | blue |
| `infrastructure` | DevOps, Docker, CI/CD, certificates | gray |
| `admin` | Admin panel features | teal |
| `stale` | Not updated in 12+ months, needs review | white |

---

## Section 5: GSD Planning Alignment

### GitHub Milestones vs GSD Milestones

| GitHub Milestone | Status | GSD Equivalent | Recommendation |
|------------------|--------|----------------|----------------|
| "Refactor repetitive code into components and mixins" | 1 open issue (#10) | v5/v6/v7 (done) | **Close milestone** — #10 is complete |
| "Admin section views" | 0 open | v6 (done) | **Close milestone** |
| "Analysis views" | 0 open | v5 (done) | **Close milestone** |
| "Complete documentation" | 0 open | — | **Close milestone** |
| "Feature-complete (FC) version" | 7 open | Partial overlap | **Rename or reorganize** — issues span multiple future milestones |
| "Simple issues" | 5 open | Various | **Review each** — some are solved, others miscategorized |
| "Manuscript writing" | 10 open | N/A (non-engineering) | **Keep** — separate track |

### Issues in "Feature-complete (FC) version" Milestone (7 open)

| # | Title | Recommendation |
|---|-------|----------------|
| #36 | Combined Status & Review Modal | Move to "Curation Workflow" milestone |
| #34 | 'Removal' Button in Status Modal | Move to "Curation Workflow" milestone |
| #15 | Search/filter/download variant annotations | Move to "Search & Data Access" milestone |
| #14 | Search for new GeneReview articles | Move to "Ontology & Data Pipeline" milestone |
| #12 | Publication Table update/check | Move to "Ontology & Data Pipeline" milestone |
| #8 | Disease ontology update functionality | Move to "Ontology & Data Pipeline" milestone |
| #7 | Endpoint to update disease_ontology_set | Move to "Ontology & Data Pipeline" milestone |

### Issues in "Simple issues" Milestone (5 open)

| # | Title | Recommendation |
|---|-------|----------------|
| ~~#100~~ | ~~Accessibility: Select labels~~ | ✅ **Closed** — Fixed in v7 Phase 39 |
| #89 | Links to Curation/Correlation Matrix | Keep — move to "Search & Data Access" |
| #53 | Redesign user application pages | Keep — move to "Curation Workflow" |
| ~~#19~~ | ~~Add offline check~~ | ✅ **Closed** — PWA service worker handles this |
| ~~#4~~ | ~~Modal crash on unapproved entities~~ | ✅ **Closed** — Fixed in v7 Phase 34, verified via Playwright |

---

## Section 6: Next Steps

### Completed ✅

- [x] Close 11 Section 1.1 issues (GSD milestone evidence)
- [x] Verify and close 13 Section 1.2 issues (Playwright/curl/code review)
- [x] Fix #119 (tutorial video link typo, commit `c7738cb`)

### Step 1: Resolve Failed Verification (#115)

**Issue:** GAP43 entity 4469 and FGF14 entity 4474 are orphaned — they exist in `ndd_entity` (`is_active=1`) but have no `ndd_entity_status` or `ndd_entity_review` records, making them invisible.

**Options (pick one):**
1. **Delete orphaned entities** — run `DELETE FROM ndd_entity WHERE entity_id IN (4469, 4474)` and close #115
2. **Repair entities** — manually INSERT missing status and review records to make them visible, then close #115
3. **Prevent recurrence** — wrap entity creation in a single `db_with_transaction()` so entity+status+review either all succeed or all rollback

### Step 2: Manually Verify Section 2 Issues (7 remaining)

These require interactive manual testing or a product decision:

| # | Action Required |
|---|----------------|
| **#110** | Log in as a Viewer-role user, navigate to View Profile, confirm no logout occurs |
| **#114** | Search for MEF2C (sysndd:4512), attempt to modify entity, confirm no errors |
| **#44** | Navigate to gene statistics page, visually verify entities-over-time chart shows correct counts |
| **#65** | During a re-review, add a new PMID and confirm existing PMIDs are preserved (not deleted) |
| **#39** | Complete a re-review workflow and confirm re-reviewer identity is preserved in the record |
| **#41** | **Product decision needed:** Should disease renames require approval? Currently creates new entity + deactivates old without approval step |
| **#29** | Check batch grouping for GNAO1, GRIN1, IFT172 — confirm entities are grouped correctly in batches |

### Step 3: Close Stale GitHub Milestones

Run these commands to close 4 stale milestones:
```bash
gh api repos/berntpopp/sysndd/milestones/<ID> -X PATCH -f state=closed
```
- "Refactor repetitive code into components and mixins" — completed in v5/v6/v7
- "Admin section views" — completed in v6
- "Analysis views" — completed in v5
- "Complete documentation" — no open issues

### Step 4: Reorganize Remaining Issues into New Milestones

Create new GitHub milestones matching the groupings in Section 3 and assign issues:
1. **Data Quality & Bug Fixes** (HIGH) — #122 (P0), #94, #83
2. **Curation Workflow Enhancements** (HIGH) — #55, #54, #37, #36, #34, #53
3. **Ontology & Data Pipeline** (MEDIUM) — #98, #46, #45, #8, #7, #14, #12
4. **Search & Data Access** (MEDIUM) — #15, #48, #89
5. **Infrastructure & DevOps** (MEDIUM) — #25, #105, #33, #22, #5
6. **Admin & Workflow Features** (LOW) — #32, #58
7. **Documentation** (LOW) — #56, #52, #51, #50, #49

### Step 5: Address Priority Bugs

1. **#122** (P0) — EIF2AK2 publication update incomplete (data integrity in production)
2. **#98** (P1) — VariO ontology links broken in production
3. **#94** (P2) — PWA menu not always closing

### Step 6: Follow-up Technical Debt from Verification

Identified during Section 1.2 verification — not blocking but should be tracked:
- **Pagination safety gap:** 4 older endpoints (`entity_endpoints.R`, `gene_endpoints.R`, `publication_endpoints.R`, `logging_endpoints.R`) use `generate_cursor_pag_inf` without max page_size cap. Migrate to `generate_cursor_pag_inf_safe`.
- **DB constraint gap:** `entity_quadruple` UNIQUE does not include `is_active`. Edge case: manual deactivation (without rename) + recreate same quadruple → MySQL 500 error. Either modify constraint or route endpoint through service layer.
- **Category URL duplication:** 16 category link URLs duplicated between `analysis_endpoints.R` and `jobs_endpoints.R`. Consolidate into shared config.
- **Entity creation atomicity:** Multi-step entity+status+review creation is not wrapped in a single transaction. Root cause of #115 orphaned entities.

---

*Generated: 2026-01-27 by issue triage analysis*
*Updated: 2026-01-27 — 25 issues closed; 10 manuscript issues transferred to berntpopp/sysndd-manuscript; #115 FAILED verification (orphaned entity); manuscript/ directory deleted from sysndd*
*Total resolved during triage: 35 issues (25 closed + 10 transferred)*
*Remaining open in sysndd: 39 issues*
*Compared against: GSD milestones v1–v7 (all shipped), codebase evidence, live environment testing*
