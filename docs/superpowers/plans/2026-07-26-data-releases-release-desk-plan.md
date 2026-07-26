# Data Releases release desk implementation plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the public Data Releases page as a download-first, responsive
release desk while preserving its typed read-only API contract and technical
verification evidence.

**Architecture:** Keep request and download orchestration in `DataReleases.vue`.
Move the chosen-release operational summary and compact archive selection into
small presentational components. Keep the manifest panel as the exact technical
provenance surface behind native disclosure, and harden display normalization at
the UI boundary for malformed runtime DOI values.

**Tech stack:** Vue 3 composition API, TypeScript, BootstrapVueNext, Vitest,
Playwright, existing SysNDD design tokens.

---

### Task 1: Add release-desk normalisation and archive selection tests (RED)

**Files:**
- Modify: `app/src/components/analyses/dataReleaseTable.spec.ts`
- Create: `app/src/components/analyses/ReleaseArchiveList.spec.ts`
- Create: `app/src/components/analyses/ReleaseArchiveList.vue`
- Modify: `app/src/components/analyses/dataReleaseTable.ts`

1. Add a test that passes a malformed non-string DOI runtime value and expects
   the unassigned display value rather than `{}`.
2. Add component tests that select an archive release and assert the emitted
   release id and `aria-current` state.
3. Run the two tests and confirm the new expectations fail.
4. Add a narrow `displayReleaseValue` normalizer and a focused archive component
   with only release id, publication date, file count, size and selected state.
5. Re-run the two tests and confirm they pass.

### Task 2: Build and test the selected-release operational summary (RED/GREEN)

**Files:**
- Create: `app/src/components/analyses/ReleaseDeskSummary.vue`
- Create: `app/src/components/analyses/ReleaseDeskSummary.spec.ts`

1. Write tests for the bundle/manifest emissions, exact release facts, and
   individual-file emission. Use a complete `ReleaseDetail` fixture and do not
   trigger a real download.
2. Run the spec and confirm it fails because the component is absent.
3. Implement the token-based summary with a primary bundle action, secondary
   manifest action, individual files, and 44 px interactive targets.
4. Re-run the component test and confirm it passes.

### Task 3: Compose the release desk and move technical evidence behind disclosure

**Files:**
- Modify: `app/src/views/analyses/DataReleases.vue`
- Modify: `app/src/views/analyses/DataReleases.spec.ts`
- Modify: `app/src/components/analyses/ReleaseManifestPanel.vue`
- Modify: `app/src/components/analyses/ReleaseManifestPanel.spec.ts`

1. Update the view test first to require the operational summary and archive
   selection while retaining stale-response and download contracts.
2. Run the view test and confirm the new expectation fails.
3. Compose the components; retain typed client calls and download handlers.
   Place manifest and verification guidance in labelled native disclosure after
   operational surfaces.
4. Harden DOI display so only non-empty strings can be linked or rendered;
   preserve `safeHttpUrl` and rel attributes.
5. Run changed unit specs; retain explicit hash/provenance tests behind the
   disclosure.

### Task 4: Browser regression coverage and visual verification

**Files:**
- Modify: `app/tests/e2e/analyses.data-releases.spec.ts`

1. Add a read-only Playwright check at 1440×900 and 390×844 that asserts the
   primary bundle action and selected archive release are visible, without
   clicking download or invoking writes.
2. Run targeted unit specs, lint, strict type check, code-quality audit and
   the targeted browser test against the local stack.
3. Capture desktop and mobile screenshots; inspect them against
   `documentation/10-visual-design-guide.md`.
4. Run `impeccable detect --json` for changed frontend sources and rerate the
   surface manually against the Impeccable audit rubric.
5. Review the final diff for API-boundary, authorization, link-safety,
   accessibility, and file-size regressions.
