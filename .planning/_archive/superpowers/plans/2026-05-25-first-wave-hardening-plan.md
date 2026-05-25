# First-Wave Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the six highest-priority first-wave security and correctness findings from `.planning/reviews/2026-05-24-codebase-review.md`.

**Architecture:** Keep fixes local to their boundaries: Plumber auth and endpoint guards, Docker build context/runtime config, operator docs, typed About/CMS API client usage, startup migration manifest validation, and MCP cache-hit-only analysis reads. Avoid broad production bind-mount cleanup, JWT token-purpose enforcement, TRUNCATE refactors, backup hardening, and unrelated frontend client migrations.

**Tech Stack:** R/Plumber, testthat, DBI/pool, Docker/Compose, Bash, Vue 3, TypeScript, Vite/Vitest/MSW, MCP sidecar services.

---

## File Map

- Modify `api/core/middleware.R`: remove PubTator mutation paths from `AUTH_ALLOWLIST`; keep `/api/publication/pubtator/cache-status` public.
- Modify `api/endpoints/publication_endpoints.R`: add Administrator role guards to four PubTator mutation handlers.
- Modify `api/tests/testthat/test-endpoint-publication.R`: structural route and allowlist tests.
- Create `api/tests/testthat/test-integration-pubtator-auth.R`: running-API unauthenticated POST regression tests that skip when no API is running.
- Modify `api/Dockerfile`: remove real runtime config copy.
- Modify `api/.dockerignore`: exclude `config.yml` and local config backups.
- Modify `docker-compose.yml`: make `api/config.yml` mounts read-only for API and worker.
- Modify `api/tests/testthat/test-network-layout-packaging.R`: static packaging tests for runtime config.
- Modify `scripts/ci-smoke.sh`: update comments to runtime seeding, not build seeding.
- Modify `api/config.yml.example`: update template comments.
- Delete `deployment.sh`: retire unsafe legacy script.
- Modify `README.md`: remove `deployment.sh` quick start.
- Modify `documentation/09-deployment.qmd`: document maintained Compose deployment and runtime config policy.
- Create `scripts/tests/test-deployment-retirement.sh`: stale deployment script regression check.
- Modify `app/src/api/about.ts`: centralize About section normalization and use the app CMS section type.
- Modify `app/src/api/about.spec.ts`: cover bare-array and legacy envelope normalization with full CMS section fixtures.
- Modify `app/src/composables/useCmsContent.ts`: use typed About API helpers, remove raw axios, and normalize loaded sections.
- Modify `app/src/composables/useCmsContent.spec.ts`: test bare-array load, legacy envelope compatibility, and write helpers.
- Modify `app/src/views/admin/ManageAbout.vue`: prevent default-preview content from autosaving on mount/unmount.
- Create `app/src/views/admin/ManageAbout.spec.ts`: regression tests for no default overwrite.
- Modify `api/functions/migration-runner.R`: add strict migration manifest validation helpers/constants.
- Modify `api/bootstrap/run_migrations.R`: validate the manifest before fast-path pending checks and include manifest status.
- Modify `api/endpoints/health_endpoints.R`: require manifest status in readiness.
- Modify `api/tests/testthat/test-unit-migration-runner.R`: strict manifest tests.
- Create: `api/tests/testthat/test-endpoint-health.R`: structural readiness manifest test.
- Modify `api/bootstrap/init_cache.R`: add memoised phenotype correlation wrapper.
- Modify `api/endpoints/phenotype_endpoints.R`: warm phenotype correlation cache through the API path.
- Modify `api/functions/mcp-analysis-cache-repository.R`: add phenotype-correlation cache-hit/read helpers.
- Modify `api/functions/mcp-analysis-repository.R`: make phenotype correlations cache-hit-only.
- Modify `api/services/mcp-analysis-service.R`: report phenotype analysis as cache-hit-only and return `temporarily_unavailable` on miss.
- Modify `api/services/mcp-research-context-service.R`: base phenotype correlation dry-run status on cache hit, not function existence.
- Modify `api/tests/testthat/test-mcp-cache-bootstrap.R`: memoised wrapper binding test.
- Modify `api/tests/testthat/test-mcp-analysis-repository.R`: cold-run prevention and cache-hit behavior tests.
- Modify `api/tests/testthat/test-mcp-analysis-service.R`: service-level unavailable/dry-run tests.
- Modify `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd`: durable behavior docs.

---

### Task 1: PubTator Mutation Authorization

**Files:**
- Modify: `api/core/middleware.R`
- Modify: `api/endpoints/publication_endpoints.R`
- Modify: `api/tests/testthat/test-endpoint-publication.R`
- Create: `api/tests/testthat/test-integration-pubtator-auth.R`

- [ ] **Step 1: Add failing structural tests for PubTator mutation auth**

In `api/tests/testthat/test-endpoint-publication.R`, replace the current placeholder-style mutation route test with these expectations:

```r
test_that("PubTator mutation routes require Administrator role", {
  with_test_db_transaction({
    mutation_routes <- c(
      "^#\\*\\s+@post\\s+/pubtator/backfill-genes\\s*$",
      "^#\\*\\s+@post\\s+/pubtator/update\\s*$",
      "^#\\*\\s+@post\\s+/pubtator/update/submit\\s*$",
      "^#\\*\\s+@post\\s+/pubtator/clear-cache\\s*$"
    )
    for (route in mutation_routes) {
      body <- publication_body_blob(route)
      expect_match(body, 'require_role\\(req, res, "Administrator"\\)')
    }
  })
})

test_that("PubTator mutation routes are not globally allowlisted", {
  source(file.path(get_api_dir(), "core", "middleware.R"), local = TRUE)
  forbidden <- c(
    "/api/publication/pubtator/backfill-genes",
    "/api/publication/pubtator/update",
    "/api/publication/pubtator/update/submit",
    "/api/publication/pubtator/clear-cache"
  )
  expect_false(any(forbidden %in% AUTH_ALLOWLIST))
  expect_true("/api/publication/pubtator/cache-status" %in% AUTH_ALLOWLIST)
})
```

- [ ] **Step 2: Add a running-API unauthenticated regression test**

Create `api/tests/testthat/test-integration-pubtator-auth.R`:

```r
library(testthat)
library(httr2)

skip_if_no_api <- function() {
  api_url <- Sys.getenv("API_URL", "http://localhost:7778")
  tryCatch({
    resp <- httr2::request(paste0(api_url, "/health/")) |>
      httr2::req_timeout(5) |>
      httr2::req_perform()
    if (httr2::resp_status(resp) != 200) {
      skip("API not responding")
    }
  }, error = function(e) {
    skip(paste("API not available:", conditionMessage(e)))
  })
}

test_that("unauthenticated PubTator mutation POSTs are rejected before side effects", {
  skip_if_no_api()
  api_url <- Sys.getenv("API_URL", "http://localhost:7778")
  paths <- c(
    "/api/publication/pubtator/backfill-genes",
    "/api/publication/pubtator/update",
    "/api/publication/pubtator/update/submit",
    "/api/publication/pubtator/clear-cache"
  )

  for (path in paths) {
    resp <- httr2::request(paste0(api_url, path)) |>
      httr2::req_method("POST") |>
      httr2::req_body_json(list(query = "BRCA1", max_pages = 1L, clear_old = FALSE)) |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 401L, info = path)
  }
})
```

- [ ] **Step 3: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"
```

Expected: FAIL because the PubTator mutation route bodies lack `require_role(...)` and the allowlist still contains write paths.

The integration test can be run later with an API stack:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-pubtator-auth.R')"
```

Expected before implementation with a running API: FAIL with status `200`, `202`, `400`, `409`, or `500` instead of `401` for at least one route.

- [ ] **Step 4: Remove PubTator write paths from the global allowlist**

In `api/core/middleware.R`, remove only these entries:

```r
  "/api/publication/pubtator/update",
  "/api/publication/pubtator/update/submit",
  "/api/publication/pubtator/clear-cache",
  "/api/publication/pubtator/backfill-genes",
```

Keep:

```r
  "/api/publication/pubtator/cache-status",
```

- [ ] **Step 5: Add Administrator role guards to each mutation handler**

In `api/endpoints/publication_endpoints.R`, add this as the first executable line of each affected handler:

```r
  require_role(req, res, "Administrator")
```

Affected handlers:

- `@post /pubtator/backfill-genes`
- `@post /pubtator/update`
- `@post /pubtator/update/submit`
- `@post /pubtator/clear-cache`

- [ ] **Step 6: Re-run targeted tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"
```

Expected: PASS.

With API running:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-pubtator-auth.R')"
```

Expected: PASS or SKIP when no API is available.

- [ ] **Step 7: Commit checkpoint**

```bash
git add api/core/middleware.R api/endpoints/publication_endpoints.R api/tests/testthat/test-endpoint-publication.R api/tests/testthat/test-integration-pubtator-auth.R
git commit -m "fix(api): require admin auth for PubTator mutations"
```

---

### Task 2: Remove Runtime Config From API Docker Images

**Files:**
- Modify: `api/Dockerfile`
- Modify: `api/.dockerignore`
- Modify: `docker-compose.yml`
- Modify: `api/tests/testthat/test-network-layout-packaging.R`
- Modify: `scripts/ci-smoke.sh`
- Modify: `api/config.yml.example`
- Modify: `documentation/09-deployment.qmd`
- Modify: `AGENTS.md`

- [ ] **Step 1: Add failing packaging tests**

Append to `api/tests/testthat/test-network-layout-packaging.R`:

```r
test_that("API Docker image does not copy real runtime config.yml", {
  dockerfile <- paste(readLines(file.path(get_api_dir(), "Dockerfile"), warn = FALSE), collapse = "\n")

  expect_false(grepl("COPY .*config\\.yml config\\.yml", dockerfile))
})

test_that("API Docker build context excludes real runtime config files", {
  dockerignore <- readLines(file.path(get_api_dir(), ".dockerignore"), warn = FALSE)

  expect_true(any(grepl("^config[.]yml$", dockerignore)))
  expect_true(any(grepl("^config[.]yml[.]devbackup$", dockerignore)))
})

test_that("compose mounts API runtime config read-only", {
  compose <- readLines(file.path(dirname(get_api_dir()), "docker-compose.yml"), warn = FALSE)

  service_block <- function(service) {
    start <- grep(paste0("^  ", service, ":"), compose)
    next_service <- grep("^  [a-zA-Z0-9_-]+:", compose)
    end <- min(next_service[next_service > start], length(compose) + 1L) - 1L
    compose[start:end]
  }

  for (service in c("api", "worker", "mcp")) {
    block <- service_block(service)
    expect_true(any(grepl("./api/config.yml:/app/config.yml:ro", block, fixed = TRUE)), info = service)
  }
})
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-network-layout-packaging.R')"
```

Expected: FAIL because Dockerfile still copies `config.yml`, `.dockerignore` does not exclude it, and API/worker mounts are not read-only.

- [ ] **Step 3: Remove the Dockerfile config copy**

Delete this line from `api/Dockerfile`:

```dockerfile
COPY --chown=apiuser:api config.yml config.yml
```

Do not replace it with `config.yml.example` as `/app/config.yml`. Runtime config must be mounted or injected outside image layers.

- [ ] **Step 4: Exclude real runtime config from Docker build context**

Add to `api/.dockerignore` under the development files section:

```dockerignore
config.yml
config.yml.devbackup
```

- [ ] **Step 5: Make runtime config mounts read-only**

In `docker-compose.yml`, change API and worker mounts from:

```yaml
      - ./api/config.yml:/app/config.yml
```

to:

```yaml
      - ./api/config.yml:/app/config.yml:ro
```

The MCP service already uses `:ro`; leave it unchanged.

- [ ] **Step 6: Update smoke/config comments**

In `scripts/ci-smoke.sh`, replace the stale comment block at lines 30-37 with wording that says:

```bash
# Seed gitignored runtime files from committed templates if missing. The API
# image no longer bakes api/config.yml into image layers; this seed exists so
# docker compose can satisfy the runtime /app/config.yml bind mount on fresh CI
# checkouts and local smoke runs.
```

In `api/config.yml.example`, replace lines 9-13 with wording that says:

```yaml
## The API image must not bake real api/config.yml into image layers. This
## template is used only to create a runtime api/config.yml for local/CI stacks
## when no operator-specific file exists.
```

- [ ] **Step 7: Update durable deployment docs**

In `documentation/09-deployment.qmd`, add under "Key Runtime Settings":

```markdown
### `api/config.yml`

The production API image does not include `api/config.yml`. Provide runtime
configuration through the Compose read-only mount, an operator secret, or an
equivalent deployment-specific config injection mechanism. Never re-add
`COPY config.yml config.yml` to `api/Dockerfile`; local credentials can otherwise
be baked into image layers.
```

In `AGENTS.md`, add a short note under "Container mount boundary" with the same invariant.

- [ ] **Step 8: Re-run targeted tests and smoke harness**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-network-layout-packaging.R')"
bash scripts/tests/test-ci-smoke.sh
```

Expected: both PASS.

- [ ] **Step 9: Build image from a clean config-free API context**

Run from repo root:

```bash
docker build -f api/Dockerfile api --target production --tag sysndd-api:config-free-check
```

Expected: build succeeds without reading `api/config.yml`.

- [ ] **Step 10: Commit checkpoint**

```bash
git add api/Dockerfile api/.dockerignore docker-compose.yml api/tests/testthat/test-network-layout-packaging.R scripts/ci-smoke.sh api/config.yml.example documentation/09-deployment.qmd AGENTS.md
git commit -m "fix(docker): keep runtime config out of API images"
```

---

### Task 3: Retire `deployment.sh`

**Files:**
- Delete: `deployment.sh`
- Modify: `README.md`
- Modify: `documentation/09-deployment.qmd`
- Create: `scripts/tests/test-deployment-retirement.sh`

- [ ] **Step 1: Add the regression check**

Create `scripts/tests/test-deployment-retirement.sh`:

```bash
#!/usr/bin/env bash
set -eu

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if [ -e deployment.sh ]; then
  fail "deployment.sh must remain retired; use documentation/09-deployment.qmd"
fi

if rg -n 'deployment[.]sh|no-check-certificate|copy_files[.]sh|docker-compose[.]sh' README.md documentation/09-deployment.qmd >/tmp/sysndd-deployment-retirement.matches; then
  cat /tmp/sysndd-deployment-retirement.matches >&2
  fail "stale unsafe deployment script reference found"
fi

printf 'OK: legacy deployment script is retired.\n'
```

Make it executable:

```bash
chmod +x scripts/tests/test-deployment-retirement.sh
```

- [ ] **Step 2: Run the check and verify it fails**

Run:

```bash
bash scripts/tests/test-deployment-retirement.sh
```

Expected: FAIL because `deployment.sh` exists and `README.md` references it.

- [ ] **Step 3: Delete the unsafe script**

Run:

```bash
rm deployment.sh
```

- [ ] **Step 4: Update README quick start**

Replace the `README.md` Docker Deployment block with:

````markdown
### Docker Deployment

Use the maintained operator workflow in
[documentation/09-deployment.qmd](documentation/09-deployment.qmd):

```bash
git clone https://github.com/berntpopp/sysndd.git
cd sysndd
cp .env.example .env
# edit .env and provide api/config.yml from your deployment secret source
docker compose up -d
```
````

- [ ] **Step 5: Update deployment docs**

In `documentation/09-deployment.qmd`, add this sentence after the Quick Start:

```markdown
Legacy archive-downloader deployment scripts are not part of the supported
deployment path; do not use unverified downloaded shell to provision runtime
configuration.
```

- [ ] **Step 6: Re-run the regression check**

Run:

```bash
bash scripts/tests/test-deployment-retirement.sh
```

Expected: PASS.

- [ ] **Step 7: Commit checkpoint**

```bash
git add README.md documentation/09-deployment.qmd scripts/tests/test-deployment-retirement.sh
git rm deployment.sh
git commit -m "chore(deploy): retire unsafe legacy deployment script"
```

---

### Task 4: Fix About/CMS Response Shape And Default Autosave

**Files:**
- Modify: `app/src/api/about.ts`
- Modify: `app/src/api/about.spec.ts`
- Modify: `app/src/composables/useCmsContent.ts`
- Modify: `app/src/composables/useCmsContent.spec.ts`
- Modify: `app/src/views/admin/ManageAbout.vue`
- Create: `app/src/views/admin/ManageAbout.spec.ts`

- [ ] **Step 1: Add failing typed-client normalization tests**

In `app/src/api/about.spec.ts`, replace `sampleSections` with full CMS-shaped rows:

```ts
const sampleSections: AboutSection[] = [
  { section_id: 'welcome', title: 'Welcome', icon: 'bi-info-circle', content: 'About SysNDD', sort_order: 0 },
  { section_id: 'methods', title: 'Methods', icon: 'bi-book', content: 'A short methodological note.', sort_order: 1 },
];
```

Add a legacy envelope compatibility test:

```ts
it('normalizes a legacy draft envelope to sections', async () => {
  server.use(http.get('/api/about/draft', () => HttpResponse.json({ sections: sampleSections })));
  const sections = await getAboutDraft();
  expect(sections).toEqual(sampleSections);
});
```

- [ ] **Step 2: Add failing composable tests for real bare arrays**

In `app/src/composables/useCmsContent.spec.ts`, update the existing `loadDraft` handler to return `sampleSections` as a bare array instead of `{ status, version, sections }`. Add this sibling envelope test:

```ts
it('loadDraft preserves the backend bare sections array', async () => {
  const { token } = primeAuth('bare-array-token');
  const sampleSections = [
    { section_id: 'welcome', title: 'Welcome', icon: 'bi-info-circle', content: 'Body', sort_order: 0 },
  ];
  server.use(
    http.get('*/api/about/draft', ({ request }) => {
      expectBearerHeader(request, token);
      return HttpResponse.json(sampleSections);
    })
  );

  const cms = useCmsContent();
  const ok = await cms.loadDraft();
  expect(ok).toBe(true);
  expect(cms.sections.value).toEqual(sampleSections);
});
```

- [ ] **Step 3: Add failing admin view tests for no default overwrite**

Create `app/src/views/admin/ManageAbout.spec.ts` with two focused cases:

```ts
import { afterEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import '@/api/client';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import ManageAbout from './ManageAbout.vue';

const stubs = {
  SectionList: { template: '<div data-testid="section-list" />' },
  MarkdownPreview: { template: '<div />' },
  RouterLink: { template: '<a><slot /></a>' },
};

const sampleSections = [
  { section_id: 'welcome', title: 'Welcome', icon: 'bi-info-circle', content: 'Existing content', sort_order: 0 },
];

describe('ManageAbout CMS load/autosave safety', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('does not replace a bare-array draft with defaults on unmount', async () => {
    primeAuth('about-admin-token');
    let savedBody: unknown = null;
    server.use(
      http.get('*/api/about/draft', () => HttpResponse.json(sampleSections)),
      http.put('*/api/about/draft', async ({ request }) => {
        savedBody = await request.json();
        return HttpResponse.json({ message: 'saved' });
      })
    );

    const wrapper = mount(ManageAbout, { global: { stubs } });
    await flushPromises();
    wrapper.unmount();
    await flushPromises();

    expect(savedBody).toEqual({ sections: sampleSections });
  });

  it('does not autosave default preview sections when the API returns an empty array', async () => {
    primeAuth('empty-about-admin-token');
    let putCount = 0;
    server.use(
      http.get('*/api/about/draft', () => HttpResponse.json([])),
      http.put('*/api/about/draft', () => {
        putCount += 1;
        return HttpResponse.json({ message: 'saved' });
      })
    );

    const wrapper = mount(ManageAbout, { global: { stubs } });
    await flushPromises();
    wrapper.unmount();
    await flushPromises();

    expect(putCount).toBe(0);
  });
});
```

The first test keeps the current behavior that a real loaded draft may be autosaved unchanged on unmount. The second test is the data-loss guard: defaults from an empty API response must not be persisted on unmount.

- [ ] **Step 4: Run tests and verify they fail**

Run:

```bash
cd app && npx vitest run src/api/about.spec.ts src/composables/useCmsContent.spec.ts src/views/admin/ManageAbout.spec.ts
```

Expected: FAIL because `useCmsContent` expects an envelope and `ManageAbout` autosaves defaults.

- [ ] **Step 5: Centralize About section normalization in typed client**

In `app/src/api/about.ts`, import the app CMS type and add helpers:

```ts
import type { AboutSection } from '@/types';

type AboutSectionsPayload = AboutSection[] | { sections?: AboutSection[] | null };

export function normalizeAboutSections(payload: AboutSectionsPayload | null | undefined): AboutSection[] {
  if (Array.isArray(payload)) {
    return payload;
  }
  if (payload && Array.isArray(payload.sections)) {
    return payload.sections;
  }
  return [];
}
```

Update `getAboutDraft()` and `getPublishedAbout()` to request `AboutSectionsPayload` and return `normalizeAboutSections(...)`:

```ts
export async function getAboutDraft(config?: AxiosRequestConfig): Promise<AboutSection[]> {
  const payload = await apiClient.get<AboutSectionsPayload>('/api/about/draft', config);
  return normalizeAboutSections(payload);
}

export async function getPublishedAbout(config?: AxiosRequestConfig): Promise<AboutSection[]> {
  const payload = await apiClient.get<AboutSectionsPayload>('/api/about/published', config);
  return normalizeAboutSections(payload);
}
```

- [ ] **Step 6: Move `useCmsContent` to typed API helpers**

In `app/src/composables/useCmsContent.ts`, remove:

```ts
import axios from 'axios';
import type { AboutSection, AboutContent } from '@/types';

const API_URL = import.meta.env.VITE_API_URL || '';
```

Replace with:

```ts
import type { AboutSection } from '@/types';
import { getAboutDraft, getPublishedAbout, publishAbout, saveAboutDraft } from '@/api/about';
```

Use the typed helpers:

```ts
const loadedSections = await getAboutDraft({ timeout: 5000, withCredentials: true });
sections.value = loadedSections;
isDraft.value = true;
lastSavedAt.value = loadedSections.length > 0 ? new Date() : null;
```

For saves:

```ts
await saveAboutDraft(sections.value, { withCredentials: true });
```

For publish:

```ts
const response = await publishAbout(sections.value, { withCredentials: true });
currentVersion.value = response.version ?? null;
```

For published content:

```ts
return getPublishedAbout({ withCredentials: true });
```

- [ ] **Step 7: Prevent default preview autosave**

In `app/src/views/admin/ManageAbout.vue`, add:

```ts
const defaultPreviewActive = ref(false);
```

On mount:

```ts
onMounted(async () => {
  const loaded = await loadDraft();
  if (!loaded || sections.value.length === 0) {
    sections.value = [...defaultSections];
    defaultPreviewActive.value = true;
  } else {
    defaultPreviewActive.value = false;
  }
});
```

Guard unmount and blur autosave:

```ts
onBeforeUnmount(async () => {
  if (apiAvailable.value && sections.value.length > 0 && !defaultPreviewActive.value) {
    await saveDraft();
  }
});

async function handleAutosave() {
  if (apiAvailable.value && sections.value.length > 0 && !defaultPreviewActive.value) {
    await saveDraft();
  }
}
```

When the user edits the preview defaults, clear the guard:

```ts
function handleSectionsUpdate(updated: AboutSection[]) {
  sections.value = updated;
  defaultPreviewActive.value = false;
}
```

In the current source, `handleSectionsUpdate()` is the edit path that receives section list changes; clearing `defaultPreviewActive` there is sufficient for this task.

- [ ] **Step 8: Re-run frontend tests**

Run:

```bash
cd app && npx vitest run src/api/about.spec.ts src/composables/useCmsContent.spec.ts src/views/admin/ManageAbout.spec.ts
cd app && npm run type-check:strict
```

Expected: PASS.

- [ ] **Step 9: Commit checkpoint**

```bash
git add app/src/api/about.ts app/src/api/about.spec.ts app/src/composables/useCmsContent.ts app/src/composables/useCmsContent.spec.ts app/src/views/admin/ManageAbout.vue app/src/views/admin/ManageAbout.spec.ts
git commit -m "fix(app): preserve About CMS content when loading drafts"
```

---

### Task 5: Strict Migration Manifest In Startup And Readiness

**Files:**
- Modify: `api/functions/migration-runner.R`
- Modify: `api/bootstrap/run_migrations.R`
- Modify: `api/endpoints/health_endpoints.R`
- Modify: `api/tests/testthat/test-unit-migration-runner.R`
- Create: `api/tests/testthat/test-endpoint-health.R`
- Modify: `db/migrations/README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Add failing manifest validation tests**

Append to `api/tests/testthat/test-unit-migration-runner.R`:

```r
describe("validate_migration_manifest", {
  it("fails for a missing migration directory in strict mode", {
    expect_error(
      validate_migration_manifest("/path/that/does/not/exist", allow_empty = FALSE),
      "Migrations directory does not exist"
    )
  })

  it("fails for an empty migration directory in strict mode", {
    withr::with_tempdir({
      dir.create("empty_migrations")
      expect_error(
        validate_migration_manifest("empty_migrations", allow_empty = FALSE),
        "No migration files found"
      )
    })
  })

  it("allows empty fixture directories only when explicitly requested", {
    withr::with_tempdir({
      dir.create("empty_migrations")
      result <- validate_migration_manifest("empty_migrations", allow_empty = TRUE)
      expect_false(result$ok)
      expect_true(result$allowed_empty)
    })
  })

  it("reports the current repository migration manifest", {
    migrations_dir <- file.path(api_dir, "..", "db", "migrations")
    result <- validate_migration_manifest(migrations_dir)
    expect_true(result$ok)
    expect_equal(result$expected_latest, "023_add_nddscore_prediction_release.sql")
    expect_true(result$count >= 24L)
  })
})
```

Create `api/tests/testthat/test-endpoint-health.R` with this structural readiness test:

```r
test_that("readiness depends on migration manifest health", {
  health_src <- paste(readLines(file.path(get_api_dir(), "endpoints", "health_endpoints.R"), warn = FALSE), collapse = "\n")
  expect_match(health_src, "manifest_ok")
  expect_match(health_src, "migrations_ok <- .*manifest_ok")
})
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-migration-runner.R')"
```

Expected: FAIL because `validate_migration_manifest()` does not exist.

- [ ] **Step 3: Add manifest constants and validator**

In `api/functions/migration-runner.R`, near `MIGRATION_RENAMES`, add:

```r
EXPECTED_LATEST_MIGRATION <- "023_add_nddscore_prediction_release.sql"
EXPECTED_MIGRATION_COUNT <- 24L

validate_migration_manifest <- function(migrations_dir = "db/migrations",
                                        expected_latest = EXPECTED_LATEST_MIGRATION,
                                        expected_min_count = EXPECTED_MIGRATION_COUNT,
                                        allow_empty = FALSE) {
  if (!fs::dir_exists(migrations_dir)) {
    if (isTRUE(allow_empty)) {
      return(list(ok = FALSE, allowed_empty = TRUE, reason = "missing_directory", count = 0L))
    }
    stop(sprintf("Migrations directory does not exist: %s", migrations_dir))
  }

  files <- list_migration_files(migrations_dir)
  count <- length(files)

  if (count == 0L) {
    if (isTRUE(allow_empty)) {
      return(list(ok = FALSE, allowed_empty = TRUE, reason = "empty_directory", count = 0L))
    }
    stop(sprintf("No migration files found in: %s", migrations_dir))
  }

  if (!expected_latest %in% files) {
    stop(sprintf("Expected latest migration is missing: %s", expected_latest))
  }

  if (count < expected_min_count) {
    stop(sprintf("Migration file count too low: found %d, expected at least %d", count, expected_min_count))
  }

  list(
    ok = TRUE,
    allowed_empty = FALSE,
    count = count,
    expected_latest = expected_latest,
    latest = utils::tail(files, 1L)[[1L]]
  )
}
```

- [ ] **Step 4: Validate manifest during startup**

In `api/bootstrap/run_migrations.R`, before `get_pending_migrations(...)`, add:

```r
manifest <- validate_migration_manifest(migrations_dir = migrations_dir, allow_empty = FALSE)
```

Include `manifest = manifest` in every success status list returned by `bootstrap_run_migrations()`.

In the error status list, include:

```r
manifest = list(ok = FALSE)
```

- [ ] **Step 5: Require manifest health in readiness**

In `api/endpoints/health_endpoints.R`, compute:

```r
manifest_ok <- FALSE
```

Inside the `migration_status` block:

```r
manifest_ok <- isTRUE(status$manifest$ok)
```

Change the healthy condition from pending-only to:

```r
migrations_ok <- !is.null(pending) && !is.na(pending) && pending == 0 && manifest_ok
```

Add manifest fields to `migration_info`:

```r
manifest_ok = manifest_ok,
expected_latest = status$manifest$expected_latest %||% NA,
migration_file_count = status$manifest$count %||% NA
```

- [ ] **Step 6: Update migration docs**

In `db/migrations/README.md`, add to the startup section:

```markdown
Startup validates the migration manifest before the fast path. In non-test
startup the directory must exist, contain SQL files, include the expected latest
migration, and meet the expected minimum file count. Missing or empty mounts are
fatal and should be fixed at packaging/deployment time.
```

In `AGENTS.md`, add the same invariant under "Migrations".

- [ ] **Step 7: Re-run targeted tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-migration-runner.R')"
```

Expected: PASS.

With API running:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-health.R')"
```

Expected: PASS and `/health/ready` includes migration manifest details.

- [ ] **Step 8: Commit checkpoint**

```bash
git add api/functions/migration-runner.R api/bootstrap/run_migrations.R api/endpoints/health_endpoints.R api/tests/testthat/test-unit-migration-runner.R api/tests/testthat/test-endpoint-health.R db/migrations/README.md AGENTS.md
git commit -m "fix(api): fail startup on missing migration manifests"
```

---

### Task 6: MCP Phenotype Analysis Cache-Hit-Only

**Files:**
- Modify: `api/bootstrap/init_cache.R`
- Modify: `api/endpoints/phenotype_endpoints.R`
- Modify: `api/functions/mcp-analysis-cache-repository.R`
- Modify: `api/functions/mcp-analysis-repository.R`
- Modify: `api/services/mcp-analysis-service.R`
- Modify: `api/services/mcp-research-context-service.R`
- Modify: `api/tests/testthat/test-mcp-cache-bootstrap.R`
- Modify: `api/tests/testthat/test-mcp-analysis-repository.R`
- Modify: `api/tests/testthat/test-mcp-analysis-service.R`
- Modify: `documentation/08-development.qmd`
- Modify: `documentation/09-deployment.qmd`
- Modify: `AGENTS.md`

- [ ] **Step 1: Add failing cache wrapper binding test**

In `api/tests/testthat/test-mcp-cache-bootstrap.R`, add a stub and expectation:

```r
test_env$generate_phenotype_correlations <- function(filter = "", min_abs_correlation = NULL) {
  tibble::tibble(x = "Seizure", x_id = "HP:0001250", y = "Ataxia", y_id = "HP:0001251", value = 0.42)
}
```

Then assert:

```r
expect_true(memoise::is.memoised(test_env$generate_phenotype_correlations_mem))
```

- [ ] **Step 2: Add failing repository cold-run prevention tests**

In `api/tests/testthat/test-mcp-analysis-repository.R`, add:

```r
test_that("MCP phenotype correlations return NULL instead of cold-running analysis on cache miss", {
  source_mcp_analysis_repository()

  old_hit <- get0("mcp_analysis_repo_phenotype_correlations_cache_hit", envir = .GlobalEnv, ifnotfound = NULL)
  old_mem <- get0("generate_phenotype_correlations_mem", envir = .GlobalEnv, ifnotfound = NULL)
  old_live <- get0("generate_phenotype_correlations", envir = .GlobalEnv, ifnotfound = NULL)

  assign("mcp_analysis_repo_phenotype_correlations_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  assign("generate_phenotype_correlations", function(...) stop("cold phenotype correlations should not run"), envir = .GlobalEnv)
  if (!is.null(old_mem)) rm("generate_phenotype_correlations_mem", envir = .GlobalEnv)

  withr::defer({
    if (is.null(old_hit)) rm("mcp_analysis_repo_phenotype_correlations_cache_hit", envir = .GlobalEnv) else assign("mcp_analysis_repo_phenotype_correlations_cache_hit", old_hit, envir = .GlobalEnv)
    if (is.null(old_mem)) rm("generate_phenotype_correlations_mem", envir = .GlobalEnv) else assign("generate_phenotype_correlations_mem", old_mem, envir = .GlobalEnv)
    if (is.null(old_live)) rm("generate_phenotype_correlations", envir = .GlobalEnv) else assign("generate_phenotype_correlations", old_live, envir = .GlobalEnv)
  })

  expect_null(mcp_analysis_repo_get_phenotype_correlations())
})
```

Add a cache-hit test using a stubbed memoised wrapper:

```r
test_that("MCP phenotype correlations read from memoised cache hit and apply limits", {
  source_mcp_analysis_repository()

  old_hit <- get0("mcp_analysis_repo_phenotype_correlations_cache_hit", envir = .GlobalEnv, ifnotfound = NULL)
  old_mem <- get0("generate_phenotype_correlations_mem", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_phenotype_correlations_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("generate_phenotype_correlations_mem", function(...) {
    tibble::tibble(
      x = c("Seizure", "Hypotonia"),
      x_id = c("HP:0001250", "HP:0001252"),
      y = c("Ataxia", "Seizure"),
      y_id = c("HP:0001251", "HP:0001250"),
      value = c(0.42, 0.1)
    )
  }, envir = .GlobalEnv)
  withr::defer({
    if (is.null(old_hit)) rm("mcp_analysis_repo_phenotype_correlations_cache_hit", envir = .GlobalEnv) else assign("mcp_analysis_repo_phenotype_correlations_cache_hit", old_hit, envir = .GlobalEnv)
    if (is.null(old_mem)) rm("generate_phenotype_correlations_mem", envir = .GlobalEnv) else assign("generate_phenotype_correlations_mem", old_mem, envir = .GlobalEnv)
  })

  result <- mcp_analysis_repo_get_phenotype_correlations(phenotype = "HP:0001250", min_abs_correlation = 0.3, limit = 10L)

  expect_equal(nrow(result), 1L)
  expect_equal(result$x_id[[1]], "HP:0001250")
})
```

- [ ] **Step 3: Add failing service unavailable/dry-run tests**

In `api/tests/testthat/test-mcp-analysis-service.R`, add these tests:

```r
test_that("phenotype correlations raise temporarily_unavailable when cache hit is absent", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_hit <- mcp_analysis_repo_phenotype_correlations_cache_hit
  assign("mcp_analysis_repo_phenotype_correlations_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_phenotype_correlations_cache_hit", old_hit, envir = .GlobalEnv))

  err <- tryCatch(
    mcp_get_phenotype_analysis_context(mode = "correlations"),
    mcp_tool_error = function(e) unclass(e)
  )

  expect_equal(err$error$code, "temporarily_unavailable")
})

test_that("phenotype analysis dry_run reports correlation cache miss as unavailable", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_hit <- mcp_analysis_repo_phenotype_correlations_cache_hit
  assign("mcp_analysis_repo_phenotype_correlations_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_phenotype_correlations_cache_hit", old_hit, envir = .GlobalEnv))

  result <- mcp_get_phenotype_analysis_context(mode = "correlations", dry_run = TRUE)
  expect_equal(result$section_status, "temporarily_unavailable")
  expect_false(result$meta$cache_hit)
})
```

- [ ] **Step 4: Run tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-cache-bootstrap.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: FAIL because the wrapper and cache-hit helper do not exist and correlations still call the live helper.

- [ ] **Step 5: Add phenotype correlation memoised wrapper**

In `api/bootstrap/init_cache.R`, add to the returned list:

```r
    generate_phenotype_correlations_mem = memoise::memoise(generate_phenotype_correlations, cache = cm),
```

Use alignment consistent with the surrounding list.

- [ ] **Step 6: Warm cache through the public API phenotype endpoint**

In `api/endpoints/phenotype_endpoints.R`, change:

```r
  generate_phenotype_correlations(filter = filter)
```

to:

```r
  if (exists("generate_phenotype_correlations_mem", mode = "function")) {
    generate_phenotype_correlations_mem(filter = filter, min_abs_correlation = NULL)
  } else {
    generate_phenotype_correlations(filter = filter, min_abs_correlation = NULL)
  }
```

- [ ] **Step 7: Add cache-hit helper for MCP phenotype correlations**

In `api/functions/mcp-analysis-cache-repository.R`, add:

```r
MCP_PHENOTYPE_CORRELATION_FILTER <- "contains(ndd_phenotype_word,Yes),any(category,Definitive)"

mcp_analysis_repo_phenotype_correlations_cache_hit <- function(filter = MCP_PHENOTYPE_CORRELATION_FILTER) {
  if (!requireNamespace("memoise", quietly = TRUE)) return(FALSE)
  if (!exists("generate_phenotype_correlations_mem", mode = "function")) return(FALSE)
  if (!memoise::is.memoised(generate_phenotype_correlations_mem)) return(FALSE)

  checker <- memoise::has_cache(generate_phenotype_correlations_mem)
  isTRUE(checker(filter = filter, min_abs_correlation = NULL))
}
```

Do not call `generate_phenotype_correlations()` from the cache-hit helper.

- [ ] **Step 8: Make repository correlations cache-hit-only**

In `api/functions/mcp-analysis-repository.R`, rewrite `mcp_analysis_repo_get_phenotype_correlations()` so it checks cache first and calls only the memoised wrapper:

```r
mcp_analysis_repo_get_phenotype_correlations <- function(phenotype = NULL,
                                                         min_abs_correlation = 0.3,
                                                         limit = 25L) {
  filter <- MCP_PHENOTYPE_CORRELATION_FILTER
  if (
    !mcp_analysis_repo_phenotype_correlations_cache_hit(filter = filter) ||
      !exists("generate_phenotype_correlations_mem", mode = "function")
  ) {
    return(NULL)
  }

  limit <- mcp_analysis_repo_limit(limit)
  rows <- tryCatch(
    generate_phenotype_correlations_mem(filter = filter, min_abs_correlation = NULL),
    error = function(e) NULL
  )
  if (is.null(rows) || nrow(rows) == 0L) {
    if (is.null(rows)) return(NULL)
    return(tibble::tibble())
  }

  if (!is.null(min_abs_correlation)) {
    rows <- rows %>% dplyr::filter(abs(value) >= min_abs_correlation)
  }

  if (!is.null(phenotype) && nzchar(trimws(as.character(phenotype)[1]))) {
    phenotype <- trimws(as.character(phenotype)[1])
    rows <- rows %>%
      dplyr::filter(
        x == phenotype |
          y == phenotype |
          x_id == phenotype |
          y_id == phenotype |
          stringr::str_detect(x, stringr::fixed(phenotype, ignore_case = TRUE)) |
          stringr::str_detect(y, stringr::fixed(phenotype, ignore_case = TRUE))
      )
  }

  rows <- rows[order(-abs(rows$value), rows$x, rows$y), , drop = FALSE]
  utils::head(rows, limit)
}
```

- [ ] **Step 9: Update service dry-run and catalog behavior**

In `api/services/mcp-analysis-service.R`, change phenotype catalog availability:

```r
availability = "cache_hit_only",
estimated_latency_class = "fast_on_cache_hit",
```

At the start of `mcp_get_phenotype_analysis_context()`, compute mode-specific cache status:

```r
cache_hit <- switch(
  mode,
  correlations = isTRUE(mcp_analysis_repo_phenotype_correlations_cache_hit()),
  clusters = isTRUE(mcp_analysis_repo_phenotype_cluster_cache_hit()),
  phenotype_functional_correlations = isTRUE(mcp_analysis_repo_functional_cluster_cache_hit(algorithm = "leiden")) &&
    isTRUE(mcp_analysis_repo_phenotype_cluster_cache_hit()),
  FALSE
)
```

In dry-run/diagnostics output, include:

```r
section_status = if (isTRUE(cache_hit)) "available" else "temporarily_unavailable",
meta = list(
  limit = limit,
  diagnostics_only = TRUE,
  min_abs_correlation = min_abs_correlation,
  include_diagnostics = include_diagnostics,
  cache_hit = cache_hit
)
```

Before repository dispatch, add:

```r
if (!isTRUE(cache_hit)) {
  stop(mcp_error(
    "temporarily_unavailable",
    "Requested phenotype analysis is not available from a warmed cache entry.",
    list(argument = "mode", retry_with = list(dry_run = TRUE, response_mode = "diagnostics"))
  ))
}
```

- [ ] **Step 10: Update gene research dry-run status**

In `api/services/mcp-research-context-service.R`, change correlations status from function-existence to cache-hit:

```r
correlations = if (isTRUE(mcp_analysis_repo_phenotype_correlations_cache_hit())) available else unavailable,
```

- [ ] **Step 11: Update MCP docs**

In `documentation/08-development.qmd` and `documentation/09-deployment.qmd`, update cache-backed analysis wording to mention phenotype correlations as well as clusters and networks.

In `AGENTS.md`, add a sentence under MCP analysis cache access:

```markdown
Phenotype correlations served through MCP are cache-hit-only; MCP must not call
`generate_phenotype_correlations()` directly on a cache miss.
```

- [ ] **Step 12: Re-run targeted MCP tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-cache-bootstrap.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: PASS.

- [ ] **Step 13: Commit checkpoint**

```bash
git add api/bootstrap/init_cache.R api/endpoints/phenotype_endpoints.R api/functions/mcp-analysis-cache-repository.R api/functions/mcp-analysis-repository.R api/services/mcp-analysis-service.R api/services/mcp-research-context-service.R api/tests/testthat/test-mcp-cache-bootstrap.R api/tests/testthat/test-mcp-analysis-repository.R api/tests/testthat/test-mcp-analysis-service.R documentation/08-development.qmd documentation/09-deployment.qmd AGENTS.md
git commit -m "fix(mcp): serve phenotype analysis from cache hits only"
```

---

### Task 7: Full Verification And Code-Quality Review

**Files:**
- Review all changed files from Tasks 1-6.

- [ ] **Step 1: Run targeted tests from all tasks**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-network-layout-packaging.R')"
bash scripts/tests/test-ci-smoke.sh
bash scripts/tests/test-deployment-retirement.sh
cd app && npx vitest run src/api/about.spec.ts src/composables/useCmsContent.spec.ts src/views/admin/ManageAbout.spec.ts
cd app && npm run type-check:strict
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-migration-runner.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-cache-bootstrap.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: all PASS, except `test-integration-pubtator-auth.R` may SKIP unless API is running.

- [ ] **Step 2: Run integration smoke checks when the stack is available**

Run:

```bash
make docker-up
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-pubtator-auth.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-health.R')"
make docker-down
```

Expected: PubTator unauthenticated POSTs return `401`, health readiness returns `200` with manifest details when migrations are present.

- [ ] **Step 3: Run deterministic quality checks**

Run:

```bash
make code-quality-audit
git diff --check
```

Expected: PASS.

- [ ] **Step 4: Run pre-push or local CI lane**

Run:

```bash
make pre-commit
```

Expected: PASS.

If Docker/R/Node resources are available, run:

```bash
make ci-local
```

Expected: PASS.

- [ ] **Step 5: Review code-quality risks**

Check:

- `api/endpoints/publication_endpoints.R` and `api/functions/migration-runner.R` are already over the 600-line soft ceiling. The edits must be minimal and focused. Do not add broad refactors in these files.
- `app/src/composables/useCmsContent.ts` no longer imports raw `axios` or constructs `VITE_API_URL`.
- No source file uses direct `localStorage.token` or `localStorage.user`.
- MCP changes do not call live external providers, write DB/cache files, or call Gemini/LLM generation.
- `api/Dockerfile` has no `COPY config.yml config.yml`.
- `api/.dockerignore` excludes real runtime config.

Suggested scan:

```bash
rg -n "COPY .*config\\.yml config\\.yml|import axios from 'axios'|localStorage\\.(token|user)|generate_phenotype_correlations\\(" api app AGENTS.md documentation README.md
```

Expected:

- No Dockerfile config copy.
- No raw axios import in `app/src/composables/useCmsContent.ts`.
- `generate_phenotype_correlations(` may remain in the API endpoint/live helper/tests, but MCP repository must not call it directly on a cache miss.

- [ ] **Step 6: Final commit or PR**

If each task was committed separately, leave commits as-is. If working in a single branch without commits, commit all first-wave changes:

```bash
git add api app db README.md AGENTS.md documentation docker-compose.yml scripts .github
git commit -m "fix: apply first-wave hardening fixes"
```

Expected: clean working tree except unrelated user files.

---

## Spec Coverage Review

- PubTator unauthenticated mutations: Task 1.
- API image config secret baking: Task 2.
- Unsafe `deployment.sh`: Task 3.
- About/CMS overwrite bug: Task 4.
- Missing/empty migrations fatal in startup/readiness: Task 5.
- MCP phenotype analysis cache-hit-only: Task 6.
- Documentation updates: Tasks 2, 3, 5, and 6.
- Verification and code-quality pass: Task 7.

## Second-Wave Items Explicitly Deferred

- TRUNCATE rollback safety.
- JWT token-purpose enforcement.
- Query-string error logging redaction.
- Backup/restore credential and exit-code hardening.
- Dev DB loopback port binding.
- Broad production source bind-mount cleanup.
