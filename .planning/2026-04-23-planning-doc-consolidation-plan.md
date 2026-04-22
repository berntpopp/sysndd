# Planning Doc Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate `.planning/`, `.plans/`, and `.plan/` into a single repo-owned planning home at `.planning/` with a small live surface, normalized archive buckets, and a README that documents the structure and Superpowers boundary.

**Architecture:** Keep the live planning surface explicit and small, move all historical material under `.planning/_archive/`, and eliminate duplicate root planning directories. Preserve historical artifacts by moving rather than deleting, including legacy plans, reviews, and retained data payloads.

**Tech Stack:** Markdown, shell filesystem moves, repository documentation conventions.

---

### Task 1: Create The Target Archive Skeleton

**Files:**
- Create: `.planning/_archive/milestones/`
- Create: `.planning/_archive/legacy-plans/`
- Create: `.planning/_archive/research/`
- Create: `.planning/_archive/codebase/`
- Create: `.planning/_archive/reviews/`
- Create: `.planning/_archive/one-offs/`
- Create: `.planning/_archive/data/`

- [ ] **Step 1: Create the archive directories**

Run:

```bash
mkdir -p \
  .planning/_archive/milestones \
  .planning/_archive/legacy-plans \
  .planning/_archive/research \
  .planning/_archive/codebase \
  .planning/_archive/reviews \
  .planning/_archive/one-offs \
  .planning/_archive/data
```

- [ ] **Step 2: Verify the directories exist**

Run:

```bash
find .planning/_archive -maxdepth 1 -type d | sort
```

Expected: the archive root plus the seven target subdirectories.

### Task 2: Move Historical Material Out Of The Live Surface

**Files:**
- Modify: `.planning/`
- Move: `.planning/milestones/**`
- Move: `.planning/research/**`
- Move: `.planning/codebase/**`

- [ ] **Step 1: Move milestone history into the milestone archive**

Run:

```bash
mv .planning/milestones .planning/_archive/milestones/history
```

- [ ] **Step 2: Move research material into the research archive**

Run:

```bash
mv .planning/research .planning/_archive/research/history
```

- [ ] **Step 3: Move stale codebase snapshots into the codebase archive**

Run:

```bash
mv .planning/codebase .planning/_archive/codebase/history
```

- [ ] **Step 4: Verify the live surface no longer contains those directories**

Run:

```bash
find .planning -maxdepth 1 -mindepth 1 | sort
```

Expected: no top-level `.planning/milestones`, `.planning/research`, or `.planning/codebase`.

### Task 3: Normalize Existing Archived One-Offs

**Files:**
- Modify: `.planning/_archive/`
- Move: `.planning/_archive/bugs-resolved-v10.5/`
- Move: `.planning/_archive/pubtator-gene-normalization-report.md`
- Move: `.planning/_archive/v9.0-PR-DESCRIPTION.md`

- [ ] **Step 1: Move the v10.5 bug-resolution cluster under one-offs**

Run:

```bash
mv .planning/_archive/bugs-resolved-v10.5 .planning/_archive/one-offs/bugs-resolved-v10.5
```

- [ ] **Step 2: Move standalone archived markdown files under one-offs**

Run:

```bash
mv .planning/_archive/pubtator-gene-normalization-report.md .planning/_archive/one-offs/pubtator-gene-normalization-report.md
mv .planning/_archive/v9.0-PR-DESCRIPTION.md .planning/_archive/one-offs/v9.0-PR-DESCRIPTION.md
```

- [ ] **Step 3: Verify the old mixed archive root is now normalized**

Run:

```bash
find .planning/_archive -maxdepth 2 | sort
```

Expected: one-offs now contains the migrated historical items.

### Task 4: Fold `.plans/` Into The Archive

**Files:**
- Move: `.plans/v11.0/**`
- Modify: `.planning/_archive/legacy-plans/`

- [ ] **Step 1: Move the historical v11.0 plan cluster**

Run:

```bash
mv .plans/v11.0 .planning/_archive/legacy-plans/v11.0
```

- [ ] **Step 2: Remove the now-empty `.plans/` directory**

Run:

```bash
rmdir .plans
```

- [ ] **Step 3: Verify the legacy plan cluster exists in the archive**

Run:

```bash
find .planning/_archive/legacy-plans/v11.0 -maxdepth 1 -type f | sort
```

Expected: `closeout.md` and `phase-a.md` through `phase-e.md`.

### Task 5: Fold `.plan/` Into The Archive

**Files:**
- Move: `.plan/API_CODE_REVIEW_REPORT*.md`
- Move: `.plan/CURATION-FORMS-UIUX-REVIEW.md`
- Move: `.plan/DOCKER*.md`
- Move: `.plan/FRONTEND*.md`
- Move: `.plan/ISSUE-TRIAGE-REPORT.md`
- Move: `.plan/gene-page-enhancement-plan.md`
- Move: `.plan/data/*`

- [ ] **Step 1: Move review and triage artifacts into the review archive**

Run:

```bash
mv .plan/API_CODE_REVIEW_REPORT.md .planning/_archive/reviews/
mv .plan/API_CODE_REVIEW_REPORT_20260130.md .planning/_archive/reviews/
mv .plan/API_CODE_REVIEW_REPORT_UPDATED.md .planning/_archive/reviews/
mv .plan/CURATION-FORMS-UIUX-REVIEW.md .planning/_archive/reviews/
mv .plan/DOCKER-INFRASTRUCTURE-REVIEW-2026-01-30.md .planning/_archive/reviews/
mv .plan/DOCKER-REVIEW-REPORT-UPDATED.md .planning/_archive/reviews/
mv .plan/DOCKER-REVIEW-REPORT.md .planning/_archive/reviews/
mv .plan/FRONTEND-CODE-REVIEW-2026-01-30.md .planning/_archive/reviews/
mv .plan/FRONTEND-REVIEW-REPORT-UPDATED.md .planning/_archive/reviews/
mv .plan/FRONTEND-REVIEW-REPORT.md .planning/_archive/reviews/
mv .plan/ISSUE-TRIAGE-REPORT.md .planning/_archive/reviews/
```

- [ ] **Step 2: Move the one-off legacy plan**

Run:

```bash
mv .plan/gene-page-enhancement-plan.md .planning/_archive/one-offs/
```

- [ ] **Step 3: Move retained payloads into archive data**

Run:

```bash
mv .plan/data/* .planning/_archive/data/
```

- [ ] **Step 4: Remove the empty `.plan/` tree**

Run:

```bash
rmdir .plan/data
rmdir .plan
```

- [ ] **Step 5: Verify `.plan/` is gone and files landed in archive**

Run:

```bash
test ! -d .plan
find .planning/_archive/reviews -maxdepth 1 -type f | sort
find .planning/_archive/data -maxdepth 1 | sort
```

Expected: `.plan` absent; review docs and data files present in archive.

### Task 6: Verify The Final Planning Surface

**Files:**
- Verify: `.planning/README.md`
- Verify: `.planning/2026-04-23-planning-doc-consolidation-design.md`
- Verify: `.planning/2026-04-23-planning-doc-consolidation-plan.md`

- [ ] **Step 1: Inspect the final root planning layout**

Run:

```bash
find .planning -maxdepth 2 | sort
```

Expected: live files at `.planning/` root, `todos/pending/`, and normalized `_archive/` buckets.

- [ ] **Step 2: Confirm the repo root no longer contains duplicate planning directories**

Run:

```bash
find . -maxdepth 1 \( -name '.planning' -o -name '.plan' -o -name '.plans' \) | sort
```

Expected: only `.planning`.

- [ ] **Step 3: Re-read the README and design doc against the resulting tree**

Run:

```bash
sed -n '1,220p' .planning/README.md
sed -n '1,260p' .planning/2026-04-23-planning-doc-consolidation-design.md
```

Expected: the documented structure matches the actual layout and still states the Superpowers boundary correctly.
