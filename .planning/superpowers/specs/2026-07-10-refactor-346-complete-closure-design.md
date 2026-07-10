# Refactor #346 Complete Closure Design

Date: 2026-07-10
Issue: #346 “Refactor oversized source files toward the 600-line soft ceiling”
Status: approved for implementation

## Context

The repository already shipped the original top-ten pass, Sprint 1, and all nine
workpackages from the 2026-05-19 and 2026-06-11 plans. Those changes reduced the
legacy baseline substantially, but issue #346 remained open as an ongoing ratchet
tracker.

The current audit found:

- 39 handwritten files over 600 lines;
- one documented exception,
  `db/C_Rcommands_set-table-connections.R` at 793 lines;
- 38 non-exempt refactoring candidates;
- 20 stale baseline allowances, including seven files now at or below 600;
- no unbaselined oversized handwritten source file;
- 28 additional files between 550 and 600 lines that need headroom protection;
- `master` CI failing independently in the password-reset mailer unit test.

The earlier plans are historical evidence, not an executable plan for the
remaining debt. This design defines the objective closure state for #346.

## Decision

Complete the ratchet program instead of closing the issue after another partial
sprint. Every non-exempt handwritten source file must be at or below 600 lines.
The documented sequential DB bootstrap exception remains unchanged and explicitly
allowlisted. Baseline entries may only move downward or disappear.

This is a behavior-preserving architecture refactor. It does not authorize route,
response, permission, database-schema, curation-rule, analysis-methodology, or UI
behavior changes.

## Completion Criteria

The work is complete only when all of the following are true on merged `master`:

1. `scripts/code-quality-file-size-baseline.tsv` contains exactly the approved DB
   bootstrap exception and no non-exempt source file.
2. Every non-exempt handwritten production source file is at or below 600 lines.
3. No extracted handwritten source file exceeds 600 lines; new modules should
   normally target 450 lines or fewer to preserve growth headroom.
4. Public Vue props, emits, routes, typed API client contracts, Plumber paths,
   response envelopes, auth gates, worker job types, queue routing, and DB behavior
   remain unchanged.
5. Targeted tests, relevant lint/type checks, `make code-quality-audit`,
   `make pre-commit`, and required GitHub checks pass.
6. The pre-existing password-reset CI failure is repaired and independently
   verified before final merge.
7. Claude Code adversarially reviews the implementation plans before execution and
   reviews every implementation PR; Codex performs an independent diff/security/
   quality review and resolves all material findings.
8. The completed program is released as patch version `0.29.6`, with
   `app/package.json`, both root version fields in `app/package-lock.json`,
   `api/version_spec.json`, and `CHANGELOG.md` aligned.
9. All closure PRs are merged, #346 receives an evidence comment, and #346 is
   closed.

## Architecture

### Cohesive extraction rule

Refactor by responsibility, never by arbitrary line ranges. Existing public entry
files remain stable composition shells:

- Vue views/components keep their public names, props, emits, route placement, and
  visible behavior. Extract pure configuration/formatters, stateful composables,
  focused child controls, and genuinely separable scoped styles.
- Plumber endpoint files keep decorators and mount behavior stable. Extract payload
  normalization, orchestration, and query helpers into existing service/function
  layers. A route may move to a sub-router only when mount ordering, error handlers,
  auth gates, OpenAPI output, and exact paths are pinned by tests first.
- R services/functions split into domain modules with explicit `svc_`/`service_`
  naming and source registration at every runtime boundary. Worker-executed modules
  retain lane, priority, handler-registration, and external-budget behavior.
- The DB bootstrap script is not split. Its documented sequential/mirroring
  invariant is stronger than the soft ceiling.

### Delivery waves

The program is divided into independently reviewable waves. Parallel work is
allowed only when agents own disjoint files and tests.

#### Wave 0 — trustworthy baseline and green parent

- Repair the password-reset mailer test failure on a focused prerequisite branch.
- Rewrite the size baseline to current actuals and confirm every change is
  downward.
- Remove the seven already-compliant entries and tighten the thirteen stale
  oversized maxima.

#### Wave 1 — frontend analyses and visualization

Targets:

- `NetworkVisualization.vue`
- `PublicationsNDDTable.vue`
- `PubtatorNDDTable.vue`
- `PubtatorNDDGenes.vue`
- `AnalyseGeneClusters.vue`
- `AnalysesCurationUpset.vue` and `AnalysesPhenotypeClusters.vue` only if still
  baselined after Wave 0
- `GeneStructurePlotWithVariants.vue`
- `ProteinDomainLollipopPlot.vue`

Boundaries: control/legend components, graph hydration/search composables, table
configuration, response normalization, export helpers, and D3 presentation helpers.
Cytoscape lifecycle ownership remains explicit in one module.

#### Wave 2 — frontend curation, tables, and admin

Targets:

- `ManageReReview.vue`
- `ApproveUser.vue`, `ApproveReview.vue`, `EntityView.vue`
- `TablesEntities.vue`, `TablesPhenotypes.vue`, `TablesGenes.vue`, `GenericTable.vue`
- `BatchCriteriaForm.vue`, `ApprovalTableView.vue`, `NddScoreGeneTable.vue`
- `ManageOntology.vue`, `ManageUser.vue`, `ManageAnnotations.vue`,
  `ManageNDDScore.vue` when still oversized after Wave 0

Boundaries: workflow panels/dialogs, table column/filter configuration, request and
mutation composables, option loaders, validation helpers, and focused scoped styles.
Typed clients remain the only frontend HTTP boundary.

#### Wave 3 — API endpoints

Targets:

- `publication_endpoints.R`, `user_endpoints.R`, `admin_endpoints.R`
- `jobs_endpoints.R`, `re_review_endpoints.R`, `entity_endpoints.R`
- `statistics_endpoints.R`, `llm_admin_endpoints.R`, `backup_endpoints.R`

Boundaries: endpoint payload/response helpers and prefixed services. Endpoint source
files remain mounted in their existing order unless route-level tests prove a safe
sub-router extraction.

#### Wave 4 — API services, functions, and workers

Targets:

- `entity-service.R`, `re-review-service.R`, `llm-service.R`
- `async-job-handlers.R`, `async-job-repository.R`
- `omim-functions.R`, `nddscore-import.R`, `migration-runner.R`,
  `endpoint-functions.R`
- any LLM module still baselined after Wave 0

Boundaries: entity create/rename orchestration, re-review lifecycle families, async
handler families, provider parse/cache/import layers, migration discovery/execution,
and legacy compatibility wrappers. Source order and global-environment naming are
treated as public runtime contracts.

#### Wave 5 — integration, release, and closure

- Regenerate the final baseline and prove only the DB exception remains.
- Run full deterministic and stack-appropriate verification.
- Perform Claude and Codex reviews and fix all material findings.
- Merge closure PRs in dependency order.
- Apply and verify release `0.29.6`.
- Comment on and close #346 with line-count, test, review, PR, and release evidence.

## Parallel-Agent Strategy

Use the least expensive capable worker for each role:

- fast/cheap agents for inventory refreshes, pure helper extraction, style/config
  moves, and mechanical test updates with exact specifications;
- standard agents for Vue composables, endpoint helper extraction, and isolated R
  service splits;
- strongest available model for cross-runtime source-order changes, architecture
  review, merge integration, and adversarial review.

Implementation agents work in isolated branches/worktrees or disjoint file scopes.
They must not edit the shared baseline independently; the integration owner rewrites
it after each accepted wave. Each task receives its exact file ownership, invariants,
targeted tests, and expected line-count outcome. A separate spec reviewer checks
behavioral scope before a code-quality reviewer examines maintainability.

## Testing and Verification

### Test-first rule

Before moving stateful or externally observable behavior, add or strengthen a test
that pins the current contract. Pure, verbatim moves may use characterization tests
at the extracted seam, but must demonstrate failure before the new module exists.

### Per-task checks

- Vue: targeted Vitest, `npm run type-check`, strict type-check when the touched
  scope participates, and focused ESLint.
- API: targeted `testthat` inside the documented host/container boundary and
  focused lint/source-registration guards.
- Worker: handler registry/preload tests plus a worker restart for runtime checks.
- All tasks: `git diff --check` and current line counts.

### Per-wave checks

- `make code-quality-audit`
- `make lint-app` or `make lint-api` as applicable
- frontend unit/type checks or API fast tests as applicable
- `make pre-commit` before publishing the PR
- required GitHub Actions checks after publishing

### Final checks

- fresh oversized-file inventory independent of the committed baseline;
- `make code-quality-audit` and its harness;
- `make ci-local` when the local stack supports it;
- GitHub required/official lanes green on the merged result;
- version-source equality check;
- issue and PR state verification through GitHub.

## Failure Handling

- A failed extraction retains the previous public shell and is reduced or reverted
  at the task level; checks are never weakened and baseline limits are never raised.
- If an agent crosses file ownership or introduces behavior changes, reject the
  patch and re-dispatch with a smaller boundary.
- If source order, route mounting, worker registration, or transaction behavior is
  uncertain, add a deterministic guard before proceeding.
- If a wave cannot safely reach 600 in one extraction, use several cohesive commits
  in the same thematic PR; do not create arbitrary fragments merely to satisfy the
  counter.
- Existing unrelated user work is preserved. Every branch starts from a verified
  clean `master` or the explicitly declared prior wave.

## Non-goals

- No visual redesign or copy rewrite.
- No API, database, job, curation, security-policy, or analysis-methodology change.
- No new framework or broad dependency.
- No generated/minified/vendor/test/fixture/migration line-count cleanup.
- No splitting of the documented DB bootstrap exception.

## Release and Merge Strategy

Use small thematic PRs rather than one mega-diff. Each PR references #346, reports
before/after line counts, lists checks, and is reviewed by Claude Code and Codex.
Merge only after findings are resolved and CI is green. The final release PR/commit
bumps all source version surfaces to `0.29.6`, records the complete closure in the
changelog, and closes #346 only after the merged-state completion audit succeeds.
