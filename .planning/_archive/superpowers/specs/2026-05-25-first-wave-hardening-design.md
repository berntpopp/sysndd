# First-Wave Hardening Design

Date: 2026-05-25

Source review: `.planning/reviews/2026-05-24-codebase-review.md`

Understand orientation:

- `.understand-anything/meta.json` reports 843 analyzed files from `2026-05-24T19:02:00Z`.
- `knowledge-graph.json` identifies the relevant layers as API runtime/bootstrap, API endpoints, API services, API repository/helpers, infrastructure/deployment, MCP sidecar, and frontend API/client/composables.
- Line-level findings below were verified directly in source, not taken only from the graph.

## Decomposition And Recommended Order

The first wave spans six independently testable boundaries, but they are small enough to ship as one hardening program if each task is committed and verified separately.

Recommended order:

1. Lock down PubTator mutation routes.
2. Stop baking real `api/config.yml` into API images and keep CI smoke building from a fresh checkout.
3. Retire `deployment.sh` and remove documentation that advertises it.
4. Fix About/CMS response normalization and default-content autosave safety.
5. Make migration manifest absence fatal in non-test startup and readiness.
6. Make MCP phenotype analysis cache-hit-only, especially phenotype correlations.

This order removes unauthenticated mutation and secret-image risk first, then removes unsafe operator automation, then handles the data-loss UI bug, then tightens startup and MCP analysis behavior.

## Approaches Considered

### Recommended: One First-Wave Hardening Spec With Six Task Commits

This keeps the highest-priority review items together while preserving narrow verification per subsystem. The risks are independent, but all are production/security correctness fixes and share the same deployment window.

### Alternative: Six Separate Specs

This would reduce per-PR blast radius, but it adds coordination overhead and delays lower P1 items behind repeated planning. Use this only if the implementation owner cannot run the broad verification lane locally.

### Alternative: Security-Only First, Functional Fixes Later

This would ship PubTator, Docker config, and `deployment.sh` first, then leave CMS, migrations, and MCP for another wave. It is safer for emergency response, but the migration and MCP issues are also production correctness risks. If time is constrained, use this split.

## Scope

### 1. PubTator Mutations

Verified source:

- `AUTH_ALLOWLIST` includes PubTator write paths in `api/core/middleware.R:41-45`.
- `require_auth()` forwards allowlisted paths before auth in `api/core/middleware.R:91-95`.
- Mutation handlers are `POST /pubtator/backfill-genes` at `api/endpoints/publication_endpoints.R:684`, `POST /pubtator/update` at `:850`, `POST /pubtator/update/submit` at `:986`, and `POST /pubtator/clear-cache` at `:1113`.
- No `require_role()` call exists in `api/endpoints/publication_endpoints.R`.

Design:

- Remove the four PubTator write routes from `AUTH_ALLOWLIST`.
- Keep only read-only PubTator status/list/search routes public.
- Add `require_role(req, res, "Administrator")` at the start of each PubTator mutation handler before parameter validation or DB/external work.
- Add a structural endpoint test and a running-API unauthenticated POST regression test. The integration test must prove unauthenticated POSTs return `401` before side effects.

### 2. API Image Runtime Config

Verified source:

- `api/config.yml` is gitignored in `api/.gitignore:1-4`.
- `api/.dockerignore` does not exclude `config.yml`.
- `api/Dockerfile:196` copies `config.yml` into the image.
- `scripts/ci-smoke.sh:30-37` documents the build-time dependency and seeds `api/config.yml` only when missing.
- `.github/workflows/ci.yml:591-604` builds the API image before running `ci-smoke.sh`, so a fresh checkout currently depends on Dockerfile behavior and not the smoke seed.
- Compose bind-mounts runtime config over the image for API, worker, and MCP at `docker-compose.yml:158`, `:265`, and `:338`.

Design:

- Add `config.yml` and local backup variants to `api/.dockerignore`.
- Remove `COPY --chown=apiuser:api config.yml config.yml` from `api/Dockerfile`.
- Keep runtime config injection through Compose mounts. Make the API and worker `api/config.yml` mounts read-only in the same narrow change, matching the existing MCP mount.
- Leave `scripts/ci-smoke.sh` seeding `api/config.yml` for runtime Compose, but update comments so it no longer claims Docker builds require the file.
- Update `api/config.yml.example` comments to remove the outdated Dockerfile-copy rationale.
- Do not introduce independent frontend defaults or bake a generated runtime config into image layers.

### 3. Unsafe Legacy `deployment.sh`

Verified source:

- `deployment.sh:23-27` can stop compose and delete `sysndd/`.
- `deployment.sh:31` downloads with `wget --no-check-certificate`.
- `deployment.sh:34` extracts unverified tar content in-place.
- `deployment.sh:41-42` executes archive-provided shell.
- `deployment.sh:47` calls `docker-compose.sh`, which is not present in the current repo.
- `README.md:33-37` still advertises this script.

Design:

- Retire by deleting `deployment.sh`.
- Remove README quick-start instructions that call it.
- Point operators to the maintained `documentation/09-deployment.qmd` flow: clone, copy `.env.example`, provide `api/config.yml`, and `docker compose up -d`.
- Add a lightweight regression check that `deployment.sh` and stale script references do not reappear.

Reasoning: rewriting the script would require release artifact pinning, checksum/signature verification, safe temp-dir extraction, and explicit config-copy semantics. The current docs already contain a simpler Compose deployment path, so deletion is the safest first wave.

### 4. Admin About/CMS Response Shape And Autosave

Verified source:

- Backend `/api/about/draft` returns a bare sections array or `list()` in `api/endpoints/about_endpoints.R:34-62`.
- Backend `/api/about/published` also returns a bare sections array or `list()` in `api/endpoints/about_endpoints.R:248-262`.
- Typed frontend client models the bare array in `app/src/api/about.ts:55` and `:110`.
- `useCmsContent.loadDraft()` bypasses the typed client with raw `axios.get<AboutContent>()` in `app/src/composables/useCmsContent.ts:47` and expects `response.data.sections` in `:52`.
- `ManageAbout.vue` installs hardcoded defaults when loading yields no sections in `app/src/views/admin/ManageAbout.vue:283-288`.
- `ManageAbout.vue` autosaves on unmount whenever API is available and sections are nonempty in `:291-295`.

Design:

- Make `app/src/api/about.ts` the only HTTP boundary for About/CMS.
- Keep the canonical API contract as `AboutSection[]`, matching the backend and typed client tests.
- Add a typed normalization helper in `app/src/api/about.ts` that accepts a bare array and defensively accepts a legacy `{ sections }` envelope, returning `AboutSection[]`.
- Update `useCmsContent` to call `getAboutDraft`, `saveAboutDraft`, `publishAbout`, and `getPublishedAbout`; remove raw `axios` and `VITE_API_URL` construction from the composable.
- Prevent default preview content from being autosaved on mount/unmount. Default sections are preview/seed content only until the admin explicitly edits or saves.
- Add tests for the real bare-array response, a legacy envelope response, and the no-autosave default preview path.

### 5. Missing Or Empty Migrations

Verified source:

- `list_migration_files()` returns `character(0)` for a missing migration directory in `api/functions/migration-runner.R:90-93`.
- It returns `character(0)` for an empty directory in `api/functions/migration-runner.R:95-100`.
- `get_pending_migrations()` converts zero files into zero pending migrations in `api/functions/migration-runner.R:607-610`.
- `run_migrations()` treats no files as a successful no-op in `api/functions/migration-runner.R:677-684`.
- `bootstrap_run_migrations()` takes the no-lock fast path when pending is zero in `api/bootstrap/run_migrations.R:38-58`.
- Readiness trusts `pending == 0` in `api/endpoints/health_endpoints.R:91-107`.
- The current repo has 24 SQL migrations through `023_add_nddscore_prediction_release.sql`.

Design:

- Keep `list_migration_files()` tolerant for unit-test fixtures and low-level callers.
- Add an explicit strict migration manifest validation layer for startup/readiness.
- The manifest must require:
  - migration directory exists,
  - at least one `*.sql` file exists,
  - the expected latest migration `023_add_nddscore_prediction_release.sql` is present,
  - the SQL file count is at least the expected count for this repo state, currently `24`.
- `bootstrap_run_migrations()` must validate the manifest before computing pending migrations. Failure should populate `migration_status$error` and crash startup using the existing fatal path.
- `/health/ready` should require `migration_status$manifest$ok == TRUE` in addition to `pending == 0`. If startup ever survives with a bad manifest, readiness must return `503`.
- Tests may opt into empty fixture directories explicitly by calling validation with `allow_empty = TRUE`; non-test startup must not silently allow empty directories.

### 6. MCP Phenotype Analysis Cache-Hit-Only

Verified source:

- AGENTS.md requires MCP analysis cache access to be read-only and already warmed.
- Catalog currently advertises phenotype analysis as `local_analysis_or_cache` in `api/services/mcp-analysis-service.R:45-49`.
- Normal phenotype analysis dispatches to the repository without a cache-hit check in `api/services/mcp-analysis-service.R:393-403`.
- `mcp_analysis_repo_get_phenotype_correlations()` directly calls `generate_phenotype_correlations()` in `api/functions/mcp-analysis-repository.R:175-188`.
- `generate_phenotype_correlations()` collects broad phenotype/review tables before limits in `api/functions/analysis-phenotype-functions.R:240-261`.
- Gene research dry-run reports correlations as available based only on function existence in `api/services/mcp-research-context-service.R:34-41`.
- `api/bootstrap/init_cache.R:92-101` has memoised wrappers for cluster/network helpers, but not phenotype correlations.

Design:

- Add a memoised wrapper for phenotype correlations in `bootstrap_init_memoised()`, for example `generate_phenotype_correlations_mem`.
- Make the public API phenotype correlation endpoint use that memoised wrapper when available. This lets the API path warm cache entries; MCP remains read-only.
- Add an MCP cache-hit helper for the default phenotype correlation filter. It should check memoise/cachem state and, where possible, disk payloads without invoking cold analysis.
- Change MCP phenotype correlations so they return `temporarily_unavailable` on cache miss instead of calling `generate_phenotype_correlations()` directly.
- Update dry-run/diagnostics status and the analysis catalog to report `cache_hit_only` for phenotype analysis.
- Keep existing data class labels as `curated_derived_analysis`.

## Non-Goals

- TRUNCATE rollback safety for metadata refreshes.
- JWT token purpose enforcement for password-reset tokens.
- Query-string error logging redaction.
- Backup/restore credential and exit-code hardening.
- Dev MySQL loopback-only port binding.
- Broad production bind-mount cleanup beyond the narrow `api/config.yml:ro` runtime config mount.
- Full typed-client migration for unrelated composables.
- Search URL encoding and `TermSearch` `v-html`.
- Strict TypeScript global ratchet cleanup.

## Risks And Mitigations

- PubTator admin UI may depend on unauthenticated local calls. Mitigation: the fix should rely on the existing authenticated frontend API stack; failing tests should point to missing token propagation.
- Removing `config.yml` from the Docker image can break standalone `docker run sysndd-api`. Mitigation: document that runtime config is required through Compose, an operator secret, or a read-only mount.
- CI smoke prebuild could fail if Dockerfile still references `config.yml` after `.dockerignore` changes. Mitigation: update Dockerfile first and add static packaging tests.
- Deleting `deployment.sh` can break legacy operator muscle memory. Mitigation: README and deployment docs must show the maintained Compose path.
- About/CMS default-preview logic can suppress legitimate saves if dirty-state tracking is too broad. Mitigation: only block autosave for default-preview content loaded due to empty/unavailable content; explicit Save/Publish after user edits must still work.
- Migration expected-count constants become a maintenance obligation. Mitigation: put the constants next to migration-runner code and document that adding a migration requires updating them.
- MCP phenotype correlations may become unavailable until warmed by API/admin usage. Mitigation: dry-run and `temporarily_unavailable` recovery should tell clients to warm the API/admin phenotype analysis path.

## Test Strategy

Targeted checks:

- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-pubtator-auth.R')"` with API running; skips when unavailable.
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-network-layout-packaging.R')"`
- `bash scripts/tests/test-ci-smoke.sh`
- `bash scripts/tests/test-deployment-retirement.sh`
- `cd app && npx vitest run src/api/about.spec.ts src/composables/useCmsContent.spec.ts src/views/admin/ManageAbout.spec.ts`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-migration-runner.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-cache-bootstrap.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"`

Broad checks before handoff:

- `make code-quality-audit`
- `git diff --check`
- `make pre-commit`
- `make ci-local` if local Docker/R/Node availability permits.

## Rollback And Deployment Notes

- PubTator auth: restart the API service after deploy. Worker restart is not required for route auth, but a normal stack restart is acceptable.
- Image config: rebuild API-derived images. Confirm runtime `api/config.yml` is mounted or provided before starting API, worker, and MCP. Rotate any credentials that may have been present in images built on machines with a real `api/config.yml`.
- Deployment script retirement: communicate that `deployment.sh` is gone and the supported path is `documentation/09-deployment.qmd`.
- About/CMS: deploy frontend. If defaults were previously autosaved over content, restore from `about_content` published history or database backup before editing further.
- Migrations: a bad migration mount now crashes startup or returns readiness `503`. Rollback is to fix the mount/image packaging, not to weaken the check.
- MCP phenotype analysis: clients may see `temporarily_unavailable` until cache is warmed. Warm through the API/admin analysis path, not through MCP.

## Documentation Updates

- `AGENTS.md`: keep guidance aligned with config image policy, strict migration manifest checks, and MCP phenotype analysis cache-hit-only behavior.
- `documentation/08-development.qmd`: mention warming phenotype correlations as cache-backed MCP analysis.
- `documentation/09-deployment.qmd`: document runtime config injection, no `api/config.yml` in images, removed `deployment.sh`, and MCP cache-hit-only phenotype analysis behavior.
- `README.md`: remove `deployment.sh` quick start and link to maintained deployment docs.
- `api/config.yml.example`: update comments so the template is runtime config guidance, not a Docker build requirement.

## Primary References

- OWASP API broken function-level authorization guidance: https://owasp.org/API-Security/editions/2019/en/0xa5-broken-function-level-authorization/
- Docker build context and `.dockerignore` documentation: https://docs.docker.com/build/building/context/
- Docker Compose secrets/configs documentation: https://docs.docker.com/compose/how-tos/use-secrets/
- OWASP logging guidance for sensitive data: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
