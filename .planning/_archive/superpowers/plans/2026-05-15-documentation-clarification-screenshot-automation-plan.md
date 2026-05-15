# Documentation Clarification And Screenshot Automation Implementation Plan

Status: Completed and archived on 2026-05-15 after PR #340 merged as `e08550fd`.

Completion notes:

- Phases 1-5 were implemented and verified in PR #340.
- Phase 6 optional CI integration was intentionally not implemented and remains gated on explicit approval.
- Issues #49, #50, #51, #52, and #140 were closed after the merge.
- Local Playwright screenshot generation, teardown, Quarto render, and generated screenshot verification passed before merge.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clarify SysNDD documentation for issues #49, #50, #51, #52, and #140 while preserving curation policy and adding a local-first generated screenshot lane.

**Architecture:** Keep the Quarto book as the published documentation framework. Separate content clarification from screenshot automation, store generated documentation screenshots under `documentation/static/img/generated/`, and use a dedicated Playwright docs-screenshot config so generated documentation assets never mix with E2E failure artifacts or visual-regression baselines.

**Tech Stack:** Quarto, Vue 3, TypeScript, Vite, Bootstrap 5, Bootstrap-Vue-Next, Playwright, Node scripts, Docker Compose SysNDD app/API/MySQL/Traefik stack, R/Plumber API.

---

## Source Of Truth And Guardrails

- Approved spec: `.planning/superpowers/specs/2026-05-15-documentation-clarification-screenshot-automation-design.md`.
- Audit context: `.planning/docs/2026-05-15-documentation-screenshot-automation-audit-plan.md`.
- Repository instructions: `AGENTS.md`.
- Do not change SysNDD curation principles, thresholds, evidence category meanings, NDD scope, or existing ontology terms.
- For #51 and #52, write explanatory prose and examples only. Do not add curation categories, ontology terms, thresholds, or decision rules.
- Treat screenshot automation as a separate phase from content clarification.
- Treat documentation screenshots as generated documentation assets, not Playwright failure screenshots and not `toHaveScreenshot()` baselines.
- Adapt the useful VarLens ideas only: named docs screenshot command, stable slugs, deterministic setup, DOM overlays, generated assets, and later artifact handoff. Do not copy the Electron launch model, VitePress paths, or CI-first strategy.

## File Map

### Phase 1: Issue-Driven Documentation Clarifications

- Modify: `documentation/02-web-tool.qmd`
  - Expand the bug-reporting section for #49.
- Modify: `documentation/06-re-review-instructions.qmd`
  - Add GeneReviews PMID lookup guidance for #50.
  - Add source-based variant ontology curation guidance for #51.
- Modify: `documentation/04-database-structure.qmd`
  - Add a cross-reference from the variant ontology source list to the reviewer-facing workflow in `06-re-review-instructions.qmd`.
- Modify: `documentation/05-curation-criteria.qmd`
  - Expand the existing `n.a.` explanation for #52 without changing the rule.

### Phase 2: Content Freshness Update

- Modify: `documentation/02-web-tool.qmd`
  - Update current frontend stack wording.
  - Replace the empty NDD Publications subsection.
  - Update mobile/PWA/performance wording where current facts are already verifiable from the repository.
- Modify: `documentation/03-api.qmd`
  - Update R/Plumber, Docker, Traefik, modular source tree, OpenAPI, and authentication wording.
- Modify: `documentation/04-database-structure.qmd`
  - Update MySQL runtime wording and schema diagram freshness policy.
- Modify: `documentation/08-development.qmd`
  - Add local documentation screenshot generation commands after the screenshot lane exists.
- Modify: `documentation/09-deployment.qmd`
  - Add operator-facing documentation build/screenshot notes only if CI or deployment behavior changes.
- Modify: `documentation/README.md`
  - Add the local render and generated-screenshot verifier command after those commands exist.

### Phase 3: First Screenshot Automation Lane

- Modify: `app/playwright.config.ts`
  - Add explicit exclusion for `tests/docs-screenshots/**` from the default suite.
- Create: `app/playwright.docs-screenshots.config.ts`
  - Dedicated Playwright config for docs screenshots.
- Modify: `app/package.json`
  - Add `docs:screenshots`.
  - Add `sharp` as a dev dependency through `npm install --save-dev sharp` if image optimization or dimension inspection is implemented in Node instead of shelling out.
- Modify: `app/package-lock.json`
  - Commit dependency lock changes from npm.
- Create: `app/tests/docs-screenshots/manifest.ts`
  - Typed screenshot manifest with stable slugs, doc refs, SPA routes, non-SPA/API URLs, auth roles, setup helpers, actions, viewport, masks, capture mode, and annotations.
- Create: `app/tests/docs-screenshots/helpers.ts`
  - Named setup helpers and serializable action executor for pages, modals, and Swagger state.
- Create: `app/tests/docs-screenshots/overlays.ts`
  - DOM overlay helpers for boxes, dots, callouts, masks, and cleanup.
- Create: `app/tests/docs-screenshots/provenance.ts`
  - Provenance writer for generated screenshot metadata.
- Create: `app/tests/docs-screenshots/docs-screenshots.spec.ts`
  - Playwright runner that iterates the manifest and writes generated screenshots.
- Create: `scripts/documentation/verify-doc-screenshots.mjs`
  - Verifies generated outputs, provenance, image references, and orphans.
- Modify: `Makefile`
  - Add `docs-screenshots`, `docs-screenshots-down`, and `verify-doc-screenshots` targets.
- Generate during implementation, not by hand:
  - `documentation/static/img/generated/*.png`
  - `documentation/static/img/generated/raw/*.png` if raw/final split is retained
  - `documentation/static/img/generated/screenshot-manifest.generated.json`

### Phase 4: Screenshot Migration

- Modify: `documentation/02-web-tool.qmd`
- Modify: `documentation/03-api.qmd`
- Modify: `documentation/06-re-review-instructions.qmd`
- Modify: `documentation/static/img/generated/screenshot-manifest.generated.json`
- Remove legacy screenshots from `documentation/static/img/` only after the corresponding Quarto references have moved to generated assets and the verifier reports no remaining references.

### Phase 5: Documentation Design Overhaul

- Modify: `documentation/styles.css`
  - Align Quarto presentation with the quiet clinical design direction.
- Modify: `documentation/_quarto.yml`
  - Adjust navigation labels, footer, and out-of-nav guide references as needed.
- Modify: `documentation/README.md`
  - Point to `documentation/10-visual-design-guide.md` and `documentation/11-admin-visual-review.md` if they remain outside Quarto navigation.
- Modify: `documentation/02-web-tool.qmd`, `documentation/03-api.qmd`, `documentation/04-database-structure.qmd`, `documentation/05-curation-criteria.qmd`, and `documentation/06-re-review-instructions.qmd`
  - Normalize image wrappers, captions, and redundant horizontal rules only after content and screenshots are stable.

### Phase 6: Optional CI Integration

- Modify: `.github/workflows/gh-pages.yml`
  - Add a manual docs screenshot artifact path only after local generation is stable.
- Do not add auto-commit behavior for screenshots.
- Do not schedule screenshot generation until manual `workflow_dispatch` has proven stable.

---

## Phase 1: Issue-Driven Documentation Clarifications (#49-#52)

### Task 1.1: Preserve Current Curation Policy Text Before Editing

**Files:**
- Read: `documentation/05-curation-criteria.qmd`
- Read: `documentation/06-re-review-instructions.qmd`

- [ ] Record the current curation threshold lines before editing:

```bash
rg -n ">= 10|>= 5|>= 3|>= 2|20%|Special case: non-NDD|n\\.a\\.|Category 1|Category 2|Category 3|Refuted|Variation Ontology|GeneReviews" documentation/05-curation-criteria.qmd documentation/06-re-review-instructions.qmd
```

Expected: output includes the existing NDD definition, Category 1/2/3 thresholds, HPO 20% phenotype guidance, the `n.a.` paragraph, GeneReviews PMID instruction, and current variant wording.

- [ ] Keep this command output available while reviewing the final Phase 1 diff.

### Task 1.2: Add Minimal Problem Report And Chromium Console Workflow For #49

**Files:**
- Modify: `documentation/02-web-tool.qmd`

- [ ] In `documentation/02-web-tool.qmd`, replace the short paragraph under `## Reporting bugs, problems and making feature requests` with practical user-support prose that keeps the support email and existing screenshots.

Use this content shape:

```markdown
If you have technical problems using SysNDD or requests regarding the data or functionality, please contact us at support [at] sysndd.org.

When reporting a technical problem, include a minimal problem report:

- page URL or route;
- date, time, and browser;
- logged-in role, if the problem happened after login;
- exact steps that reproduce the problem;
- expected result;
- observed result;
- visible error message, if present;
- console errors or a saved console log, if available;
- whether the problem repeats after reloading the page.

Avoid sending passwords, authentication tokens, personal identifiers, unpublished patient-level details, or other sensitive material in screenshots or console logs.
```

- [ ] Keep the existing `02_33-error-message.png` reference after the problem-report list.

- [ ] Add a Chromium console workflow after the error-message screenshot and before the existing `02_34-save-console-logs.png` reference:

```markdown
For Chromium-based browsers such as Chrome or Edge:

1. Open Developer Tools with `F12`, `Ctrl+Shift+J`, or the browser menu.
2. Select the Console tab.
3. Reproduce the problem.
4. Right-click in the Console and save or copy the console output.
5. Send the saved log with the minimal problem report.
```

- [ ] Do not ask users to inspect network payloads or browser storage.

### Task 1.3: Add GeneReviews PMID Lookup Guidance For #50

**Files:**
- Modify: `documentation/06-re-review-instructions.qmd`

- [ ] In `documentation/06-re-review-instructions.qmd`, keep the existing `**GeneReviews**` help item and add a subsection immediately after the help item block and before `**Comment**`.

Use this subsection:

```markdown
#### Finding the PMID for a GeneReviews article

GeneReviews chapters are hosted in NCBI Bookshelf and may have chapter-specific PubMed records. Use the chapter-specific PMID when one exists. Do not substitute the general GeneReviews collection PMID for a chapter-specific citation.

Two practical lookup workflows are available:

1. From GeneReviews or NCBI Bookshelf, open the chapter and check the citation or metadata area near the chapter title or footer. Record the PubMed PMID when it is shown.
2. From PubMed, search the condition name plus `GeneReviews`, open the matching chapter record, and copy the PMID from that PubMed record.

If no chapter-specific PMID can be found, note this in the review comment instead of forcing an unrelated PMID.
```

- [ ] Keep the wording reviewer-facing and concise.

### Task 1.4: Add Source-Based Variant Ontology Guidance For #51

**Files:**
- Modify: `documentation/06-re-review-instructions.qmd`
- Modify: `documentation/04-database-structure.qmd`

- [ ] In `documentation/06-re-review-instructions.qmd`, add a new subsection after the synopsis examples and before `**Phenotypes**`.

Use this subsection:

```markdown
#### Variant ontology curation

Variant ontology curation standardizes the molecular consequence or mechanism already supported by the source text so that variants can be compared across entities and analyses.

Use a source-based workflow:

- read the publication, GeneReviews chapter, OMIM entry, or other accepted source text;
- identify the variant class or mechanism explicitly supported by that source;
- select the closest existing SysNDD variation ontology term;
- prefer a more specific existing term only when the source is explicit;
- use broader wording or a curator comment when sources are heterogeneous or ambiguous;
- do not infer a mechanism beyond the source text.

Examples:

- recurrent missense variants with an explicitly reported gain-of-function mechanism can be captured with the matching existing mechanism or effect term if present;
- truncating variants reported as causing loss of function can be captured with the matching existing loss-of-function or truncating concept if present;
- mixed missense and truncating reports without a proven common mechanism should be described conservatively in the synopsis or comment rather than forced into an over-specific ontology assignment.

The authoritative term list is the existing SysNDD variation ontology list, with VariO and OLS as external references. This documentation does not add or rename terms.
```

- [ ] In `documentation/04-database-structure.qmd`, add one cross-reference sentence after the existing variation ontology source list:

```markdown
Reviewer-facing guidance for choosing among existing variation ontology terms is described in the re-review instructions.
```

- [ ] Do not introduce any new variation ontology term names beyond the illustrative mechanism/effect wording in the approved spec.

### Task 1.5: Expand The `n.a.` Explanation For #52

**Files:**
- Modify: `documentation/05-curation-criteria.qmd`

- [ ] Replace only the paragraph under `### Special case: non-NDD entities` with expanded explanatory text.

Use this content shape:

```markdown
Some genes are associated with multiple entities. Among these entities, some may be well-established disorders without intellectual disability or another neurodevelopmental disorder as a clinical feature. These non-NDD entities can be retained in SysNDD for gene context, but they are outside the SysNDD NDD classification scope. They are not classified into Category 1, 2, or 3. Instead, they are tagged with `n.a.` (not applicable).

`n.a.` is not a lower evidence category and is not equivalent to "Limited" or "Refuted". Category 1, 2, and 3 ask how strong the evidence is for an NDD entity. `n.a.` says that the retained entity itself is outside the NDD classification scope. "Refuted" says that evidence argues against retaining the proposed association.

Examples:

- A gene has one entity with early-onset developmental delay or intellectual disability and another well-established entity without cognitive impairment. The non-NDD entity may be retained for gene context and tagged `n.a.`.
- A disorder is mainly adult-onset or organ-specific and the literature does not show intellectual disability or neurodevelopmental disorder in a significant fraction. If retained as a separate entity, it may be tagged `n.a.`.
- A disorder includes motor delay only, with no evidence for cognitive impairment or early neurodevelopmental disorder. The issue may be scope rather than weak NDD evidence.
- Do not use `n.a.` when there is weak but plausible NDD evidence. Apply Category 2 or Category 3 according to the existing criteria.
- Do not use `n.a.` when newer evidence contradicts the old association. Consider "Refuted" according to the existing criteria.
```

- [ ] Confirm that the NDD definition at the top of `documentation/05-curation-criteria.qmd` is unchanged.

### Task 1.6: Verify Phase 1

**Files:**
- Verify: `documentation/02-web-tool.qmd`
- Verify: `documentation/04-database-structure.qmd`
- Verify: `documentation/05-curation-criteria.qmd`
- Verify: `documentation/06-re-review-instructions.qmd`

- [ ] Render the Quarto book:

```bash
quarto render documentation
```

Expected: Quarto renders the book without errors.

- [ ] Check that no policy thresholds were edited:

```bash
git diff -- documentation/05-curation-criteria.qmd documentation/06-re-review-instructions.qmd
```

Expected: the diff adds explanatory text for GeneReviews, variant ontology, and `n.a.` only. Existing thresholds and category meanings remain intact.

- [ ] Check issue coverage:

```bash
rg -n "minimal problem report|Console tab|chapter-specific PMID|variant ontology curation|outside the SysNDD NDD classification scope|not a lower evidence category" documentation/02-web-tool.qmd documentation/05-curation-criteria.qmd documentation/06-re-review-instructions.qmd
```

Expected: each phrase appears in the relevant documentation chapter.

- [ ] Commit Phase 1:

```bash
git add documentation/02-web-tool.qmd documentation/04-database-structure.qmd documentation/05-curation-criteria.qmd documentation/06-re-review-instructions.qmd
git commit -m "docs: clarify reviewer and support guidance"
```

---

## Phase 2: Content Freshness Update

### Task 2.1: Reconfirm Current Stack Facts From Source Files

**Files:**
- Read: `app/package.json`
- Read: `api/Dockerfile`
- Read: `docker-compose.yml`
- Read: `api/bootstrap/mount_endpoints.R`
- Read: `app/src/router/routes.ts`

- [ ] Run:

```bash
rg -n "\"vue\"|\"vite\"|\"bootstrap\"|\"bootstrap-vue-next\"|\"typescript\"|\"swagger-ui\"" app/package.json
rg -n "FROM rocker/r-ver|traefik:v|mysql:" api/Dockerfile docker-compose.yml
rg -n "pr_mount\\(\"/api|pr_set_api_spec|/__docs__|/__swagger__" api/bootstrap/mount_endpoints.R
rg -n "path: '/PublicationsNDD'|path: '/GeneNetworks'|path: '/Analysis'|path: '/Entities'|path: '/Genes'" app/src/router/routes.ts
```

Expected: current facts include Vue 3, TypeScript, Vite, Bootstrap 5, Bootstrap-Vue-Next, Swagger UI dependency, `rocker/r-ver:4.6.0`, Traefik v3.7, MySQL 8.4.9, modular `/api/<subpath>` endpoint mounting, `/PublicationsNDD`, `/GeneNetworks`, `/Entities`, and `/Genes`.

### Task 2.2: Update Web Tool Stack And Analysis Wording

**Files:**
- Modify: `documentation/02-web-tool.qmd`

- [ ] Replace the stale Vue 2 / BootstrapVue / Bootstrap 4 sentence near the top with:

```markdown
The web tool is a Vue 3 single-page application written in TypeScript and built with Vite. It uses Bootstrap 5 and Bootstrap-Vue-Next for the component layer.
```

- [ ] Replace the landing-page sentence `The landing page is designed as simple Bootstrap v4 website with:` with:

```markdown
The landing page provides:
```

- [ ] Replace the `### NDD Publications` body with:

```markdown
The *NDD Publications* view summarizes publications relevant to neurodevelopmental disorder gene curation. It provides a searchable publication table and companion analysis tabs for publication activity over time and source statistics. The view helps curators and users inspect how publication evidence is distributed across the SysNDD literature corpus.
```

- [ ] Update the mobile section so it describes responsive SysNDD views instead of old generic Bootstrap stacked tables:

```markdown
The Vue 3 application uses responsive layouts so SysNDD remains usable on smaller screens. Navigation and footer controls collapse at mobile widths, and table-heavy views use compact mobile rows or reduced controls where the current view supports them.
```

- [ ] Keep PWA content factual and fix spelling in the touched section: `macOS`, `JavaScript`, and `Chrome`.

### Task 2.3: Update API Chapter Runtime And Endpoint Wording

**Files:**
- Modify: `documentation/03-api.qmd`

- [ ] Replace the stale runtime/load-balancer/rate-limit paragraph with source-confirmed wording:

```markdown
The API is written in R using the [plumber package](https://www.rplumber.io/) and runs in Docker from the repository API image based on `rocker/r-ver`. In the current Compose deployment, Traefik routes web traffic to the API service under `/api`.

Runtime and rate-limit behavior can change with deployment configuration. Operator-facing deployment details are maintained in the deployment chapter.
```

- [ ] Replace the stale single-script endpoint sentence with:

```markdown
The runtime is composed by `api/start_sysndd_api.R`, which sources helpers, core modules, services, and endpoint files through the bootstrap layer. Endpoint files are mounted under `/api/<subpath>` by `api/bootstrap/mount_endpoints.R`.
```

- [ ] Update "externala nd internal", "api", "Swagger/ OpenAPI", and "ressources" spelling/capitalization in touched paragraphs to "external and internal", "API", "Swagger/OpenAPI", and "resources".

- [ ] For the Swagger/OpenAPI URL, verify the local path in Phase 3 before making screenshot references. Use `http://localhost/api` as the stable API base in local commands and keep production-facing text consistent with the path that actually resolves in the current stack.

### Task 2.4: Update Database Runtime And Schema Diagram Policy

**Files:**
- Modify: `documentation/04-database-structure.qmd`

- [ ] Replace the MySQL 8.0 / 8.0.29 wording with:

```markdown
SysNDD currently uses the open-source [MySQL](https://dev.mysql.com/doc/) relational database management system. The repository Compose stack uses the official MySQL Docker image, currently `mysql:8.4.9`.
```

- [ ] Replace the dated schema sentence with:

```markdown
The diagram below is a documentation snapshot. The versioned schema source of truth is the migration history under `db/migrations/` and the current database initialized by the migration runner.
```

- [ ] Keep the DB Designer link unless a separate schema export pipeline is implemented.

### Task 2.5: Add Development Documentation For The Future Screenshot Lane

**Files:**
- Modify after Phase 3 files exist: `documentation/08-development.qmd`
- Modify after Phase 3 files exist: `documentation/README.md`

- [ ] In `documentation/08-development.qmd`, add a "Documentation screenshots" subsection near existing Playwright instructions:

````markdown
### Documentation screenshots

Generated documentation screenshots are produced from a dedicated Playwright lane, separate from E2E failure screenshots. They are written under `documentation/static/img/generated/` and accompanied by provenance metadata.

Local generation uses the Docker-backed Playwright stack:

```bash
make playwright-stack
cd app && PLAYWRIGHT_BASE_URL=http://localhost npm run docs:screenshots
cd ..
node scripts/documentation/verify-doc-screenshots.mjs
make playwright-stack-down
```

Use `make playwright-stack-down` after a failed run to restore the local API config and remove Playwright volumes.
````

- [ ] In `documentation/README.md`, add the render and verifier commands:

````markdown
Render and verify documentation assets from the repository root:

```bash
quarto render documentation
node scripts/documentation/verify-doc-screenshots.mjs
```
````

### Task 2.6: Verify Phase 2

**Files:**
- Verify: `documentation/02-web-tool.qmd`
- Verify: `documentation/03-api.qmd`
- Verify: `documentation/04-database-structure.qmd`
- Verify: `documentation/08-development.qmd`
- Verify: `documentation/README.md`

- [ ] Render the Quarto book:

```bash
quarto render documentation
```

Expected: Quarto renders the book without errors.

- [ ] Check stale phrases are gone from touched sections:

```bash
rg -n "Vue\\.js.*v2\\.6|Bootstrap v4|BootstrapVue|rocker/tidyverse|4\\.2\\.0|HAProxy|NGINX|one api script|externala nd|ressources|8\\.0\\.29|content coming soon" documentation/02-web-tool.qmd documentation/03-api.qmd documentation/04-database-structure.qmd
```

Expected: no matches for stale wording.

- [ ] Commit Phase 2:

```bash
git add documentation/02-web-tool.qmd documentation/03-api.qmd documentation/04-database-structure.qmd documentation/08-development.qmd documentation/README.md
git commit -m "docs: refresh stack and analysis descriptions"
```

---

## Phase 3: First Screenshot Automation Lane

### Task 3.1: Install Image Processing Dependency If Needed

**Files:**
- Modify: `app/package.json`
- Modify: `app/package-lock.json`

- [ ] If the implementation uses Sharp for PNG metadata, optimization, or post-processing, run:

```bash
cd app && npm install --save-dev sharp
```

Expected: `app/package.json` gains `sharp` in `devDependencies` and `app/package-lock.json` records the resolved package.

- [ ] If the implementation uses Playwright DOM overlays only and Node's built-in filesystem APIs for verification, skip the Sharp install and record that decision in the Phase 3 PR description.

### Task 3.2: Explicitly Isolate Docs Screenshots From The Default Playwright Suite

**Files:**
- Modify: `app/playwright.config.ts`
- Create: `app/playwright.docs-screenshots.config.ts`
- Modify: `app/package.json`

- [ ] In `app/playwright.config.ts`, add a default-suite ignore for docs screenshots:

```ts
  testIgnore: ['docs-screenshots/**'],
```

Place it inside the `defineConfig({ ... })` object next to `testMatch`.

- [ ] Create `app/playwright.docs-screenshots.config.ts`:

```ts
import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost';

export default defineConfig({
  testDir: './tests/docs-screenshots',
  testMatch: ['**/*.spec.ts'],
  fullyParallel: false,
  globalSetup: './tests/e2e/global-setup.ts',
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: 'list',

  use: {
    baseURL,
    trace: 'retain-on-failure',
    video: 'off',
    screenshot: 'off',
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
  },

  projects: [
    {
      name: 'chromium-docs',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
  ],

  expect: {
    timeout: 10_000,
  },

  outputDir: 'tests/docs-screenshots/.playwright-output',
});
```

- [ ] In `app/package.json`, add:

```json
"docs:screenshots": "playwright test --config=playwright.docs-screenshots.config.ts"
```

- [ ] Verify default collection remains isolated:

```bash
cd app && npx playwright test --list
cd app && npm run docs:screenshots -- --list
```

Expected: the default list includes `tests/e2e/**/*.spec.ts` and no `tests/docs-screenshots` specs. The docs command lists only `tests/docs-screenshots/docs-screenshots.spec.ts` after that file exists.

### Task 3.3: Add Typed Manifest Model

**Files:**
- Create: `app/tests/docs-screenshots/manifest.ts`

- [ ] Create `app/tests/docs-screenshots/manifest.ts` with these exported types and first capture set:

```ts
export type DocsScreenshotAction =
  | { type: 'click'; selector: string }
  | { type: 'fill'; selector: string; value: string; sensitive?: boolean }
  | { type: 'press'; key: string }
  | { type: 'hover'; selector: string }
  | { type: 'waitFor'; selector: string }
  | { type: 'callHelper'; name: string; args?: Record<string, unknown> };

export type DocsScreenshotAnnotation = {
  selector: string;
  mode: 'box' | 'dot' | 'callout';
  label?: string;
  number?: number;
};

export type DocsScreenshot = {
  slug: string;
  output: string;
  docRefs: string[];
  route?: string;
  url?: string;
  baseURL?: 'app' | 'api' | string;
  viewport: { width: number; height: number };
  authRole?: 'admin' | 'curator' | 'reviewer' | 'user';
  setup?: string;
  actions?: DocsScreenshotAction[];
  waitFor?: string;
  locator?: string;
  fullPage?: boolean;
  clip?: { x: number; y: number; width: number; height: number };
  maskSelectors?: string[];
  annotations?: DocsScreenshotAnnotation[];
};

export const docsScreenshots: DocsScreenshot[] = [
  {
    slug: 'home',
    output: 'documentation/static/img/generated/home.png',
    docRefs: ['documentation/02-web-tool.qmd#landing-page'],
    route: '/',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'entities-table',
    output: 'documentation/static/img/generated/entities-table.png',
    docRefs: ['documentation/02-web-tool.qmd#entities-table'],
    route: '/Entities',
    viewport: { width: 1440, height: 900 },
    waitFor: 'table',
    fullPage: true,
  },
  {
    slug: 'genes-table',
    output: 'documentation/static/img/generated/genes-table.png',
    docRefs: ['documentation/02-web-tool.qmd#genes-table'],
    route: '/Genes',
    viewport: { width: 1440, height: 900 },
    waitFor: 'table',
    fullPage: true,
  },
  {
    slug: 'gene-detail-chd8',
    output: 'documentation/static/img/generated/gene-detail-chd8.png',
    docRefs: ['documentation/02-web-tool.qmd#gene-page'],
    route: '/Genes/CHD8',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'entity-detail-123',
    output: 'documentation/static/img/generated/entity-detail-123.png',
    docRefs: ['documentation/02-web-tool.qmd#entity-page'],
    route: '/Entities/123',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'curation-comparisons-overview',
    output: 'documentation/static/img/generated/curation-comparisons-overview.png',
    docRefs: ['documentation/02-web-tool.qmd#compare-curations'],
    route: '/CurationComparisons',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'publications-ndd',
    output: 'documentation/static/img/generated/publications-ndd.png',
    docRefs: ['documentation/02-web-tool.qmd#ndd-publications'],
    route: '/PublicationsNDD',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'functional-clusters',
    output: 'documentation/static/img/generated/functional-clusters.png',
    docRefs: ['documentation/02-web-tool.qmd#functional-clusters'],
    route: '/GeneNetworks',
    viewport: { width: 1440, height: 900 },
    waitFor: 'main',
    fullPage: true,
  },
  {
    slug: 'login-page',
    output: 'documentation/static/img/generated/login-page.png',
    docRefs: ['documentation/02-web-tool.qmd#login-page', 'documentation/06-re-review-instructions.qmd#login'],
    route: '/Login',
    viewport: { width: 1280, height: 900 },
    waitFor: 'form',
    fullPage: true,
  },
  {
    slug: 'reviewer-review-page',
    output: 'documentation/static/img/generated/reviewer-review-page.png',
    docRefs: ['documentation/06-re-review-instructions.qmd#review-page'],
    route: '/Review',
    viewport: { width: 1440, height: 900 },
    authRole: 'reviewer',
    setup: 'reviewerReviewPage',
    waitFor: 'table',
    fullPage: true,
  },
  {
    slug: 'reviewer-modify-review-modal',
    output: 'documentation/static/img/generated/reviewer-modify-review-modal.png',
    docRefs: ['documentation/06-re-review-instructions.qmd#new-review-edit'],
    route: '/Review',
    viewport: { width: 1440, height: 900 },
    authRole: 'reviewer',
    setup: 'reviewerReviewPage',
    actions: [{ type: 'callHelper', name: 'openFirstReviewEditModal' }],
    waitFor: '.modal.show',
    fullPage: false,
    locator: '.modal.show',
  },
  {
    slug: 'api-swagger-auth',
    output: 'documentation/static/img/generated/api-swagger-auth.png',
    docRefs: ['documentation/03-api.qmd#authentication-and-authorization'],
    baseURL: 'api',
    url: '/__docs__/',
    viewport: { width: 1440, height: 900 },
    setup: 'swaggerAuthScreen',
    waitFor: '.swagger-ui',
    fullPage: true,
  },
];
```

- [ ] If the local Swagger URL resolves under `/api/__docs__/` instead of `/__docs__/`, keep `baseURL: 'app'`, set `url: '/api/__docs__/'`, and update the Phase 3 provenance output accordingly.

### Task 3.4: Add Setup Helpers And Action Executor

**Files:**
- Create: `app/tests/docs-screenshots/helpers.ts`

- [ ] Create named helpers that keep setup/action logic out of the runner:

```ts
import type { Page } from '@playwright/test';
import type { DocsScreenshot, DocsScreenshotAction } from './manifest';

type SetupContext = {
  page: Page;
  entry: DocsScreenshot;
};

type SetupHelper = (context: SetupContext) => Promise<void>;

export const setupHelpers: Record<string, SetupHelper> = {
  async reviewerReviewPage({ page }) {
    await page.waitForSelector('table', { timeout: 30_000 });
  },

  async swaggerAuthScreen({ page }) {
    await page.waitForSelector('.swagger-ui', { timeout: 30_000 });
    const authorizeButton = page.getByRole('button', { name: /authorize/i }).first();
    if (await authorizeButton.isVisible().catch(() => false)) {
      await authorizeButton.click();
      await page.waitForSelector('.modal-ux', { timeout: 10_000 }).catch(() => undefined);
    }
  },
};

export const actionHelpers: Record<string, (page: Page, args?: Record<string, unknown>) => Promise<void>> = {
  async openFirstReviewEditModal(page) {
    const editButton = page
      .getByRole('button', { name: /edit review|review/i })
      .first();
    await editButton.click();
    await page.waitForSelector('.modal.show', { timeout: 10_000 });
  },
};

export async function runAction(page: Page, action: DocsScreenshotAction): Promise<void> {
  if (action.type === 'click') {
    await page.locator(action.selector).click();
    return;
  }
  if (action.type === 'fill') {
    await page.locator(action.selector).fill(action.value);
    return;
  }
  if (action.type === 'press') {
    await page.keyboard.press(action.key);
    return;
  }
  if (action.type === 'hover') {
    await page.locator(action.selector).hover();
    return;
  }
  if (action.type === 'waitFor') {
    await page.waitForSelector(action.selector, { timeout: 30_000 });
    return;
  }
  const helper = actionHelpers[action.name];
  if (!helper) {
    throw new Error(`Unknown docs screenshot action helper: ${action.name}`);
  }
  await helper(page, action.args);
}
```

- [ ] Replace selectors during implementation only when the first local run proves that the accessible button names differ. Keep replacements role/accessibility based where possible.

### Task 3.5: Add DOM Overlay Helpers

**Files:**
- Create: `app/tests/docs-screenshots/overlays.ts`

- [ ] Create overlay helpers:

```ts
import type { Page } from '@playwright/test';
import type { DocsScreenshotAnnotation } from './manifest';

export async function hideVolatileElements(page: Page, selectors: string[] = []): Promise<void> {
  if (selectors.length === 0) return;
  await page.addStyleTag({
    content: selectors.map((selector) => `${selector} { visibility: hidden !important; }`).join('\n'),
  });
}

export async function addAnnotations(page: Page, annotations: DocsScreenshotAnnotation[] = []): Promise<void> {
  for (const annotation of annotations) {
    await page.evaluate((item) => {
      const target = document.querySelector(item.selector);
      if (!target) return;
      const rect = target.getBoundingClientRect();
      const marker = document.createElement('div');
      marker.className = 'sysndd-docs-screenshot-annotation';
      marker.setAttribute('data-mode', item.mode);
      marker.style.position = 'fixed';
      marker.style.pointerEvents = 'none';
      marker.style.zIndex = '2147483647';
      marker.style.boxSizing = 'border-box';
      marker.style.fontFamily = 'Arial, sans-serif';

      if (item.mode === 'box') {
        marker.style.top = `${rect.top - 4}px`;
        marker.style.left = `${rect.left - 4}px`;
        marker.style.width = `${rect.width + 8}px`;
        marker.style.height = `${rect.height + 8}px`;
        marker.style.border = '3px solid #1f6f8b';
        marker.style.borderRadius = '6px';
      } else {
        marker.style.top = `${rect.top - 10}px`;
        marker.style.left = `${rect.right - 10}px`;
        marker.style.width = '24px';
        marker.style.height = '24px';
        marker.style.borderRadius = '999px';
        marker.style.background = '#1f6f8b';
        marker.style.color = '#ffffff';
        marker.style.display = 'flex';
        marker.style.alignItems = 'center';
        marker.style.justifyContent = 'center';
        marker.style.fontWeight = '700';
        marker.textContent = item.number ? String(item.number) : item.label ?? '';
      }

      document.body.appendChild(marker);
    }, annotation);
  }
}

export async function clearAnnotations(page: Page): Promise<void> {
  await page.evaluate(() => {
    document.querySelectorAll('.sysndd-docs-screenshot-annotation').forEach((node) => node.remove());
  });
}
```

### Task 3.6: Add Provenance Writer

**Files:**
- Create: `app/tests/docs-screenshots/provenance.ts`

- [ ] Create provenance support:

```ts
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import type { Browser, Page } from '@playwright/test';
import type { DocsScreenshot } from './manifest';

type ProvenanceEntry = {
  slug: string;
  output: string;
  docRefs: string[];
  route?: string;
  url?: string;
  baseURL?: string;
  viewport: { width: number; height: number };
  authRole?: string;
  setup?: string;
  actions?: unknown[];
  waitFor?: string;
  captureMode: 'page' | 'locator' | 'clip';
  annotations?: unknown[];
  gitSha: string | null;
  capturedAt: string;
  browserName: string;
  browserVersion: string;
};

function gitSha(): string | null {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
  } catch {
    return null;
  }
}

function redactActions(actions: DocsScreenshot['actions']): unknown[] | undefined {
  return actions?.map((action) => {
    if (action.type === 'fill' && action.sensitive) {
      return { ...action, value: '[redacted]' };
    }
    return action;
  });
}

export class ProvenanceWriter {
  private entries: ProvenanceEntry[] = [];

  add(entry: DocsScreenshot, page: Page, browser: Browser): void {
    this.entries.push({
      slug: entry.slug,
      output: entry.output,
      docRefs: entry.docRefs,
      route: entry.route,
      url: entry.url,
      baseURL: typeof entry.baseURL === 'string' ? entry.baseURL : undefined,
      viewport: entry.viewport,
      authRole: entry.authRole,
      setup: entry.setup,
      actions: redactActions(entry.actions),
      waitFor: entry.waitFor,
      captureMode: entry.locator ? 'locator' : entry.clip ? 'clip' : 'page',
      annotations: entry.annotations,
      gitSha: gitSha(),
      capturedAt: new Date().toISOString(),
      browserName: browser.browserType().name(),
      browserVersion: browser.version(),
    });
  }

  write(outputPath = 'documentation/static/img/generated/screenshot-manifest.generated.json'): void {
    const absoluteOutput = resolve(process.cwd(), '..', outputPath);
    mkdirSync(dirname(absoluteOutput), { recursive: true });
    writeFileSync(absoluteOutput, `${JSON.stringify({ screenshots: this.entries }, null, 2)}\n`);
  }
}
```

### Task 3.7: Add Docs Screenshot Runner

**Files:**
- Create: `app/tests/docs-screenshots/docs-screenshots.spec.ts`

- [ ] Create the runner using the existing auth fixture so disclaimer acknowledgment and roles match E2E behavior:

```ts
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { test, expect } from '../e2e/fixtures/auth';
import { docsScreenshots, type DocsScreenshot } from './manifest';
import { runAction, setupHelpers } from './helpers';
import { addAnnotations, clearAnnotations, hideVolatileElements } from './overlays';
import { ProvenanceWriter } from './provenance';

const provenance = new ProvenanceWriter();

function targetUrl(entry: DocsScreenshot, baseURL: string): string {
  const rawBase = entry.baseURL === 'api'
    ? process.env.PLAYWRIGHT_API_BASE_URL ?? 'http://localhost'
    : baseURL;
  const path = entry.url ?? entry.route ?? '/';
  return new URL(path, rawBase).toString();
}

test.describe.configure({ mode: 'serial' });

for (const entry of docsScreenshots) {
  test(`docs screenshot: ${entry.slug}`, async ({ page, browser, loggedInAs }, testInfo) => {
    const activePage = entry.authRole ? await loggedInAs(entry.authRole) : page;
    const baseURL = testInfo.project.use.baseURL as string;

    await activePage.setViewportSize(entry.viewport);
    await activePage.goto(targetUrl(entry, baseURL), { waitUntil: 'domcontentloaded' });

    if (entry.waitFor) {
      await activePage.waitForSelector(entry.waitFor, { timeout: 30_000 });
    }

    if (entry.setup) {
      const setup = setupHelpers[entry.setup];
      if (!setup) {
        throw new Error(`Unknown docs screenshot setup helper: ${entry.setup}`);
      }
      await setup({ page: activePage, entry });
    }

    for (const action of entry.actions ?? []) {
      await runAction(activePage, action);
    }

    await hideVolatileElements(activePage, entry.maskSelectors);
    await addAnnotations(activePage, entry.annotations);

    const outputPath = resolve(process.cwd(), '..', entry.output);
    mkdirSync(dirname(outputPath), { recursive: true });

    if (entry.locator) {
      await expect(activePage.locator(entry.locator)).toBeVisible();
      await activePage.locator(entry.locator).screenshot({ path: outputPath });
    } else {
      await activePage.screenshot({
        path: outputPath,
        fullPage: entry.fullPage ?? false,
        clip: entry.clip,
      });
    }

    provenance.add(entry, activePage, browser);
    await clearAnnotations(activePage);
  });
}

test.afterAll(async () => {
  provenance.write();
});
```

- [ ] Confirm generated screenshots go to `documentation/static/img/generated/`, not `app/tests/e2e/.playwright-output/`.

### Task 3.8: Add Verifier

**Files:**
- Create: `scripts/documentation/verify-doc-screenshots.mjs`

- [ ] Create a Node verifier that checks generated outputs, references, and orphans:

```js
#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { extname, join, normalize, relative } from 'node:path';

const root = process.cwd();
const docsDir = join(root, 'documentation');
const imgDir = join(docsDir, 'static', 'img');
const generatedDir = join(imgDir, 'generated');
const provenancePath = join(generatedDir, 'screenshot-manifest.generated.json');

function walk(dir, predicate, out = []) {
  if (!existsSync(dir)) return out;
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    const stats = statSync(path);
    if (stats.isDirectory()) {
      walk(path, predicate, out);
    } else if (predicate(path)) {
      out.push(path);
    }
  }
  return out;
}

function markdownImageRefs(file) {
  const text = readFileSync(file, 'utf8');
  const refs = [];
  const markdownPattern = /!\[[^\]]*\]\(([^)]+)\)/g;
  const quartoPattern = /!\[[^\]]*\]\(([^)]+)\)\{[^}]*\}/g;
  for (const pattern of [markdownPattern, quartoPattern]) {
    let match;
    while ((match = pattern.exec(text)) !== null) {
      const ref = match[1].split(/\s+/)[0];
      if (!ref.startsWith('http://') && !ref.startsWith('https://')) {
        refs.push({ file, ref });
      }
    }
  }
  return refs;
}

const qmdFiles = walk(docsDir, (path) => extname(path) === '.qmd');
const refs = qmdFiles.flatMap(markdownImageRefs);
const missingRefs = refs.filter(({ file, ref }) => {
  const resolved = normalize(join(file, '..', ref));
  return !existsSync(resolved);
});

const provenance = existsSync(provenancePath)
  ? JSON.parse(readFileSync(provenancePath, 'utf8'))
  : { screenshots: [] };

const manifestOutputs = new Set(
  provenance.screenshots.map((entry) => normalize(join(root, entry.output)))
);
const generatedPngs = walk(generatedDir, (path) => extname(path).toLowerCase() === '.png');
const missingGenerated = [...manifestOutputs].filter((path) => !existsSync(path));
const unmanifestedGenerated = generatedPngs.filter((path) => !manifestOutputs.has(normalize(path)));

const referencedImages = new Set(
  refs.map(({ file, ref }) => normalize(join(file, '..', ref)))
);
const legacyImages = walk(imgDir, (path) => {
  const normalized = normalize(path);
  return extname(path).toLowerCase() === '.png' && !normalized.includes(`${normalize(generatedDir)}/`);
});
const orphanedLegacy = legacyImages.filter((path) => !referencedImages.has(normalize(path)));

let failed = false;

if (missingRefs.length > 0) {
  failed = true;
  console.error('Missing documentation image references:');
  for (const item of missingRefs) {
    console.error(`- ${relative(root, item.file)} -> ${item.ref}`);
  }
}

if (missingGenerated.length > 0) {
  failed = true;
  console.error('Generated manifest entries without output files:');
  for (const path of missingGenerated) console.error(`- ${relative(root, path)}`);
}

if (unmanifestedGenerated.length > 0) {
  failed = true;
  console.error('Generated PNG files missing provenance entries:');
  for (const path of unmanifestedGenerated) console.error(`- ${relative(root, path)}`);
}

if (orphanedLegacy.length > 0) {
  console.warn('Orphaned legacy screenshots:');
  for (const path of orphanedLegacy) console.warn(`- ${relative(root, path)}`);
}

if (failed) process.exit(1);
console.log('Documentation screenshot verification passed');
```

- [ ] Make the verifier executable:

```bash
chmod +x scripts/documentation/verify-doc-screenshots.mjs
```

Expected: the verifier fails on missing generated files after the manifest exists but before generation, passes after generation, and reports orphaned legacy screenshots as warnings during migration.

### Task 3.9: Add Make Targets

**Files:**
- Modify: `Makefile`

- [ ] Add `docs-screenshots`, `docs-screenshots-down`, and `verify-doc-screenshots` to `.PHONY`.

- [ ] Add targets near the existing Playwright stack section:

```make
docs-screenshots: playwright-stack ## [docs] Generate documentation screenshots locally
	cd app && PLAYWRIGHT_BASE_URL=http://localhost PLAYWRIGHT_API_BASE_URL=http://localhost npm run docs:screenshots
	node scripts/documentation/verify-doc-screenshots.mjs
	@printf "\n$(CYAN)Documentation screenshots generated under documentation/static/img/generated/$(RESET)\n"
	@printf "  Tear down: make docs-screenshots-down\n"

docs-screenshots-down: playwright-stack-down ## [docs] Tear down docs screenshot Playwright stack

verify-doc-screenshots: ## [docs] Verify documentation image references and generated screenshot provenance
	node scripts/documentation/verify-doc-screenshots.mjs
```

- [ ] Keep teardown explicit for the first version so failed captures are debuggable.

### Task 3.10: Generate The First Capture Set Locally

**Files:**
- Generate: `documentation/static/img/generated/*.png`
- Generate: `documentation/static/img/generated/screenshot-manifest.generated.json`

- [ ] Run the local-first sequence:

```bash
make playwright-stack
cd app && PLAYWRIGHT_BASE_URL=http://localhost PLAYWRIGHT_API_BASE_URL=http://localhost npm run docs:screenshots
cd ..
node scripts/documentation/verify-doc-screenshots.mjs
make playwright-stack-down
```

Expected: generated screenshots are written under `documentation/static/img/generated/`; provenance metadata is written to `documentation/static/img/generated/screenshot-manifest.generated.json`; verifier passes for generated outputs and reports legacy orphans as warnings.

- [ ] If the Swagger screenshot fails because the current stack exposes Swagger at a different path, run:

```bash
make playwright-stack
curl -I -H "Host: localhost" http://localhost/__docs__/
curl -I -H "Host: localhost" http://localhost/api/__docs__/
curl -I -H "Host: localhost" http://localhost/API
make playwright-stack-down
```

Expected: exactly one verified URL is selected for `api-swagger-auth` and then recorded in `app/tests/docs-screenshots/manifest.ts`, `documentation/03-api.qmd`, and the provenance manifest generated by the next run.

### Task 3.11: Verify Phase 3

**Files:**
- Verify: `app/playwright.config.ts`
- Verify: `app/playwright.docs-screenshots.config.ts`
- Verify: `app/tests/docs-screenshots/*`
- Verify: `scripts/documentation/verify-doc-screenshots.mjs`
- Verify: `Makefile`
- Verify: `documentation/static/img/generated/*`

- [ ] Confirm docs screenshots are isolated:

```bash
cd app && npx playwright test --list
cd app && npm run docs:screenshots -- --list
```

Expected: default list has no `tests/docs-screenshots` specs; docs list has only docs screenshot specs.

- [ ] Run the generated-output verifier:

```bash
node scripts/documentation/verify-doc-screenshots.mjs
```

Expected: missing references and missing generated files fail; legacy orphans are warnings while migration is incomplete.

- [ ] Run TypeScript check:

```bash
cd app && npm run type-check
```

Expected: type-check passes.

- [ ] Commit Phase 3:

```bash
git add app/playwright.config.ts app/playwright.docs-screenshots.config.ts app/package.json app/package-lock.json app/tests/docs-screenshots scripts/documentation/verify-doc-screenshots.mjs Makefile documentation/static/img/generated
git commit -m "docs: add generated screenshot lane"
```

---

## Phase 4: Screenshot Migration

### Task 4.1: Re-Inventory Image References Before Editing

**Files:**
- Read: `documentation/*.qmd`
- Read: `documentation/static/img/`

- [ ] Run:

```bash
rg -n "static/img/" documentation/*.qmd documentation/_quarto.yml
find documentation/static/img -maxdepth 2 -type f
node scripts/documentation/verify-doc-screenshots.mjs
```

Expected: current legacy references are visible, generated files have provenance, and orphaned legacy screenshots are reported.

### Task 4.2: Migrate The First Generated Screenshot References

**Files:**
- Modify: `documentation/02-web-tool.qmd`
- Modify: `documentation/03-api.qmd`
- Modify: `documentation/06-re-review-instructions.qmd`

- [ ] Replace legacy references for the first capture set with generated paths:

```markdown
![Landing page](./static/img/generated/home.png)
![Entities table](./static/img/generated/entities-table.png)
![Genes table](./static/img/generated/genes-table.png)
![Gene page](./static/img/generated/gene-detail-chd8.png)
![Entity page](./static/img/generated/entity-detail-123.png)
![Compare curations overview](./static/img/generated/curation-comparisons-overview.png)
![NDD Publications view](./static/img/generated/publications-ndd.png)
![Functional clusters view](./static/img/generated/functional-clusters.png)
![Login page](./static/img/generated/login-page.png)
![Review page](./static/img/generated/reviewer-review-page.png)
![Review edit modal](./static/img/generated/reviewer-modify-review-modal.png)
![Swagger authorization screen](./static/img/generated/api-swagger-auth.png)
```

- [ ] Update captions so each describes the task or UI state shown, not the legacy filename.

- [ ] Leave legacy screenshots in `documentation/static/img/` until verifier output confirms they are no longer referenced.

### Task 4.3: Migrate Section By Section

**Files:**
- Modify: `app/tests/docs-screenshots/manifest.ts`
- Modify: `documentation/02-web-tool.qmd`
- Modify: `documentation/03-api.qmd`
- Modify: `documentation/06-re-review-instructions.qmd`
- Generate: `documentation/static/img/generated/*.png`
- Generate: `documentation/static/img/generated/screenshot-manifest.generated.json`

- [ ] For each remaining web-tool section, add a manifest entry before changing the Quarto reference.

- [ ] For each remaining API screenshot, prefer a generated Swagger or API UI state over manual screenshots of copied tokens.

- [ ] For each remaining re-review screenshot, use `authRole: 'reviewer'` or `authRole: 'curator'` and named setup/action helpers. Do not put reviewer credentials in the manifest.

- [ ] For PWA install screenshots, keep one representative generated app/mobile screenshot and replace browser/OS-specific install sequences with prose unless a current browser capture is required for the task.

- [ ] For tiny icon crops such as `edit_review_button.png`, `edit_status_button.png`, and `submit_re-review_button.png`, prefer full-context generated modal or review-table screenshots unless the tiny crop remains clearer.

### Task 4.4: Remove Or Explicitly Retain Legacy Images

**Files:**
- Modify: `documentation/static/img/`

- [ ] After a section's references are migrated, run:

```bash
node scripts/documentation/verify-doc-screenshots.mjs
rg -n "02_18-sysndd.dbmr.unibe.ch_NDDpublications|02_01-landing-page|03_03-api-authorize-a|modal_modify_review|sysndd_review_page" documentation/*.qmd
```

Expected: no references remain for migrated legacy screenshots.

- [ ] Remove legacy screenshots only when they are unreferenced and not brand assets:

```bash
git rm documentation/static/img/02_18-sysndd.dbmr.unibe.ch_NDDpublications.png
```

Use additional `git rm` commands only for files confirmed unreferenced by the verifier. Do not remove `documentation/static/img/android-chrome-192x192.png` or `documentation/static/img/SysNDD_brain-dna-magnifying-glass_dall-e_logo.webp`.

### Task 4.5: Verify Phase 4

**Files:**
- Verify: `documentation/*.qmd`
- Verify: `documentation/static/img/generated/*`
- Verify: `documentation/static/img/`

- [ ] Regenerate screenshots:

```bash
make docs-screenshots
make docs-screenshots-down
```

Expected: generated outputs and provenance are refreshed.

- [ ] Verify references:

```bash
node scripts/documentation/verify-doc-screenshots.mjs
quarto render documentation
```

Expected: generated outputs resolve, migrated Quarto image references resolve, Quarto renders, and orphaned legacy screenshots are either removed or listed for a later migration batch.

- [ ] Commit Phase 4:

```bash
git add documentation app/tests/docs-screenshots documentation/static/img Makefile scripts/documentation/verify-doc-screenshots.mjs
git commit -m "docs: migrate screenshots to generated assets"
```

---

## Phase 5: Documentation Design Overhaul

### Task 5.1: Apply Quiet Clinical Quarto Styles

**Files:**
- Modify: `documentation/styles.css`

- [ ] Replace Bootstrap default blue/dark-gray dominance with restrained documentation tokens:

```css
/* SysNDD Documentation Styles */

:root {
  --sysndd-doc-text: #24323a;
  --sysndd-doc-muted: #63717a;
  --sysndd-doc-border: #d8e0e5;
  --sysndd-doc-surface: #f7fafb;
  --sysndd-doc-primary: #1f6f8b;
  --sysndd-doc-primary-dark: #164f64;
  --sysndd-doc-accent: #7a5c26;
  --bs-primary: var(--sysndd-doc-primary);
}

body {
  color: var(--sysndd-doc-text);
}

a {
  color: var(--sysndd-doc-primary-dark);
}

.sidebar {
  border-right: 1px solid var(--sysndd-doc-border);
}

.page-footer {
  background-color: #24323a;
  color: #ffffff;
  padding: 1rem;
}

.page-footer a {
  color: #d9edf3;
}

pre {
  background-color: var(--sysndd-doc-surface);
  border: 1px solid var(--sysndd-doc-border);
  border-radius: 0.25rem;
}

table {
  width: 100%;
  margin-bottom: 1rem;
  border-collapse: collapse;
}

table th,
table td {
  padding: 0.75rem;
  border: 1px solid var(--sysndd-doc-border);
}

table th {
  background-color: var(--sysndd-doc-surface);
}

p.caption,
.figure-caption {
  color: var(--sysndd-doc-muted);
  margin-top: 0.5rem;
}

.doc-screenshot {
  max-width: 100%;
  margin: 1rem 0 1.5rem;
}

.doc-screenshot img {
  max-width: 100%;
  height: auto;
  border: 1px solid var(--sysndd-doc-border);
}

mark {
  display: inline-block;
  line-height: 1;
  padding: 0.1em 0.25em;
  font-weight: 700;
  background-color: #f2d78c;
}

div[style*="max-width"] img {
  max-width: 100%;
  height: auto;
}
```

- [ ] Keep the result operational and readable. Do not add marketing hero sections, decorative gradients, or card-heavy page sections.

### Task 5.2: Normalize Image Wrappers And Captions

**Files:**
- Modify: `documentation/02-web-tool.qmd`
- Modify: `documentation/03-api.qmd`
- Modify: `documentation/04-database-structure.qmd`
- Modify: `documentation/06-re-review-instructions.qmd`

- [ ] Replace inline `::: {style="max-width:1000px;"}` wrappers for migrated generated screenshots with a class wrapper:

```markdown
::: {.doc-screenshot}
![Entities table with search, filters, sorting, and pagination controls.](./static/img/generated/entities-table.png)
:::
```

- [ ] Use captions that describe the shown workflow or state.

- [ ] Keep small-width wrappers only for genuinely narrow mobile screenshots until they are migrated or intentionally retained.

### Task 5.3: Clean Redundant Front-Matter Horizontal Rules

**Files:**
- Modify: `documentation/02-web-tool.qmd`
- Modify: `documentation/03-api.qmd`
- Modify: `documentation/04-database-structure.qmd`
- Modify: `documentation/05-curation-criteria.qmd`
- Modify: `documentation/06-re-review-instructions.qmd`

- [ ] Remove the extra `---` line that appears immediately after YAML front matter in touched chapters.

- [ ] Do not change headings, curation thresholds, or category wording while doing this cleanup.

### Task 5.4: Align Out-Of-Nav Design Documentation Pointers

**Files:**
- Modify: `documentation/_quarto.yml`
- Modify: `documentation/README.md`
- Modify: `documentation/08-development.qmd`

- [ ] Choose one of these two concrete treatments and apply it consistently:

1. Include `10-visual-design-guide.md` and `11-admin-visual-review.md` in a "Design" appendix part of `documentation/_quarto.yml`.
2. Keep both files outside Quarto navigation and reference them from `documentation/README.md` and `documentation/08-development.qmd` as internal design-review materials.

- [ ] If including them in Quarto navigation, add:

```yaml
    - part: "Design"
      chapters:
        - 10-visual-design-guide.md
        - 11-admin-visual-review.md
```

- [ ] If keeping them outside navigation, add this sentence to `documentation/README.md`:

```markdown
Design guidance for UI and documentation review lives in `10-visual-design-guide.md` and `11-admin-visual-review.md`; these files are maintained as developer-facing references unless they are intentionally added to Quarto navigation.
```

### Task 5.5: Verify Phase 5

**Files:**
- Verify: `documentation/styles.css`
- Verify: `documentation/_quarto.yml`
- Verify: `documentation/*.qmd`

- [ ] Render the Quarto book:

```bash
quarto render documentation
```

Expected: Quarto renders without errors.

- [ ] Verify image references:

```bash
node scripts/documentation/verify-doc-screenshots.mjs
```

Expected: all referenced images resolve and generated images have provenance.

- [ ] Check that no disallowed visual patterns were added:

```bash
rg -n "hero|gradient|orb|marketing|card-heavy|linear-gradient|radial-gradient" documentation/styles.css documentation/*.qmd
```

Expected: no new marketing-style or decorative-gradient language/styles in documentation changes.

- [ ] Commit Phase 5:

```bash
git add documentation/styles.css documentation/_quarto.yml documentation/README.md documentation/08-development.qmd documentation/*.qmd
git commit -m "docs: align Quarto presentation with SysNDD design"
```

---

## Phase 6: Optional CI Integration

### Task 6.1: Add Manual Screenshot Artifact Job Only After Local Stability

**Files:**
- Modify: `.github/workflows/gh-pages.yml`

- [ ] Add workflow input:

```yaml
      generate_screenshots:
        description: 'Generate documentation screenshots before rendering'
        required: false
        default: 'false'
        type: boolean
```

- [ ] Add a `build-screenshots` job guarded by the manual input:

```yaml
  build-screenshots:
    name: Build Documentation Screenshots
    if: github.event_name == 'workflow_dispatch' && inputs.generate_screenshots == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version-file: app/.nvmrc
          cache: npm
          cache-dependency-path: app/package-lock.json

      - name: Install app dependencies
        working-directory: app
        run: npm ci

      - name: Install Playwright browsers
        working-directory: app
        run: npx playwright install --with-deps chromium

      - name: Generate documentation screenshots
        run: |
          make playwright-stack
          cd app
          PLAYWRIGHT_BASE_URL=http://localhost PLAYWRIGHT_API_BASE_URL=http://localhost npm run docs:screenshots
          cd ..
          node scripts/documentation/verify-doc-screenshots.mjs
          make playwright-stack-down

      - name: Upload generated screenshots
        uses: actions/upload-artifact@v4
        with:
          name: documentation-generated-screenshots
          path: |
            documentation/static/img/generated/*.png
            documentation/static/img/generated/screenshot-manifest.generated.json
          retention-days: 3
```

- [ ] Add `needs: [build-screenshots]` only if the guarded job is structured so skipped jobs do not block normal documentation builds. If GitHub Actions skipped-job semantics block the build, keep the screenshot job separate and use manual artifact download in a later PR.

- [ ] Do not add a scheduled trigger.

- [ ] Do not add an auto-commit step.

### Task 6.2: Build Quarto From Downloaded Artifacts When Enabled

**Files:**
- Modify: `.github/workflows/gh-pages.yml`

- [ ] In the existing `build` job, add an artifact download step guarded by the same input:

```yaml
      - name: Download generated screenshots
        if: github.event_name == 'workflow_dispatch' && inputs.generate_screenshots == 'true'
        uses: actions/download-artifact@v4
        with:
          name: documentation-generated-screenshots
          path: documentation/static/img/generated
```

- [ ] Run the verifier before Quarto render when generated screenshots are downloaded:

```yaml
      - name: Verify documentation screenshots
        if: github.event_name == 'workflow_dispatch' && inputs.generate_screenshots == 'true'
        run: node scripts/documentation/verify-doc-screenshots.mjs
```

### Task 6.3: Verify Phase 6

**Files:**
- Verify: `.github/workflows/gh-pages.yml`

- [ ] Validate workflow syntax locally if `act` is available:

```bash
act -l
```

Expected: workflow parses and lists jobs.

- [ ] Push to a test branch and run the documentation workflow manually with `generate_screenshots=true`.

Expected: screenshot job uploads generated PNGs and provenance as artifacts; Quarto build consumes downloaded artifacts; no CI job commits generated screenshots.

- [ ] Commit Phase 6:

```bash
git add .github/workflows/gh-pages.yml
git commit -m "ci: add manual docs screenshot artifact lane"
```

---

## Final Verification Before Handoff

- [ ] Run the local screenshot sequence:

```bash
make playwright-stack
cd app && PLAYWRIGHT_BASE_URL=http://localhost PLAYWRIGHT_API_BASE_URL=http://localhost npm run docs:screenshots
cd ..
node scripts/documentation/verify-doc-screenshots.mjs
make playwright-stack-down
```

- [ ] Render documentation:

```bash
quarto render documentation
```

- [ ] Run frontend checks touched by automation:

```bash
make lint-app
cd app && npm run type-check
```

- [ ] If API/deployment docs were materially changed, run:

```bash
make pre-commit
```

- [ ] Before closing issues, manually check:
  - #49 minimal problem report and console workflow are present.
  - #50 GeneReviews PMID lookup distinguishes chapter-specific PMIDs from collection-level records.
  - #51 variant ontology guidance remains source-based and uses existing terms only.
  - #52 `n.a.` remains a scope tag, not an evidence category.
  - #140 generated screenshots are reproducible, provenance-backed, and separate from Playwright failure artifacts.
