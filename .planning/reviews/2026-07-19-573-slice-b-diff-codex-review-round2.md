Reading additional input from stdin...
OpenAI Codex v0.144.5
--------
workdir: /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
model: gpt-5.6-terra
provider: openai
approval: never
sandbox: read-only
reasoning effort: high
reasoning summaries: none
session id: 019f7985-a145-79c2-9cb5-0ba22740520e
--------
user
# Adversarial diff review ROUND 2 — #573 Slice B (analysis-snapshot release UI)

You reviewed this branch in round 1 and returned NO-SHIP with one HIGH, two MEDIUM, two LOW. Those
findings have now been addressed in commit `401abf17`. This is a fresh, independent re-review of the
CURRENT full branch diff. Do two things:

1. **Verify each round-1 finding is genuinely resolved** (not papered over):
   - HIGH: `zenodo.record_url` rendered into a public `:href` with no scheme validation. Fix: a new
     `app/src/utils/safe-url.ts` `safeHttpUrl()` helper gates the record_url (and the DOI-constructed
     hrefs) so a `javascript:`/`data:` scheme renders as PLAIN TEXT, not a clickable link. Confirm a
     `javascript:` record_url can no longer become a clickable `<a href="javascript:...">` on
     `/DataReleases`, and the test proves it.
   - MEDIUM: `ReleaseManifest.generator`/`source` were typed as `string` but the backend serializes
     nested objects. Fix: real nested interfaces matching `api/functions/analysis-snapshot-release.R`,
     `scope_statement` made nullable, fixtures updated. Confirm the exported type now matches the wire
     shape.
   - MEDIUM: stale-response race in `DataReleases.vue`. Fix: a monotonic `detailRequestSeq` token
     discards a superseded detail response. Confirm a late `getLatestRelease` can no longer overwrite
     a newer `getRelease(id)` selection.
   - LOW: error mocks used `{message}` instead of RFC 9457 `{detail}` — converted.
   - LOW: added failure-path coverage for rejected DOI-save and draft-deletion.

2. **Hunt for any NEW or adjacent issues** the fixes may have introduced or that remain — same
   adversarial rigor as round 1 (contract fidelity vs the R/Plumber backend, security, resource
   leaks, race conditions, weak tests, accessibility, file size).

## The diff to review
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
Backend routes: `api/endpoints/analysis_endpoints.R`, `api/endpoints/admin_analysis_snapshot_endpoints.R`.
Backend helpers: `api/functions/analysis-snapshot-release*.R`, service in
`api/services/analysis-snapshot-release-service.R`. Conventions: `AGENTS.md`.

## Locked decisions (do NOT flag as defects; flag violations)
Public head = fixed 14-field allowlist + `zenodo{record_url,version_doi,concept_doi}` + conditional
`layers`/`manifest`, NEVER `created_by_user_id`/`last_error_message`. `release_version` is a reserved
always-NULL string. `reproducibility.json` hashes exactly to `reproducibility_hash`;
`payload_hash`/`input_hash`/`snapshot_id` are lineage anchors, NOT a hash of `payload.json`. `/file`
uses a `path` query param. Build: 201 created / 200 dup / 503 lock (distinct) / 400 five gate classes;
synchronous DB-only. Build disabled unless the 3 release layers are `available` (ignore
`phenotype_correlations`/`gene_network_edges`). "Publish immediately" defaults to draft. Typed clients
only; BTable can't render dotted field keys; problem+json via `extractApiErrorMessage`; no blocking
`window.confirm`.

Note: `NddScoreModelCard.vue` has a pre-existing identical unguarded-href pattern that is explicitly
OUT OF SCOPE for this PR (a separate follow-up) — do not count it against this branch.

## Output
Findings grouped by **BLOCKER / HIGH / MEDIUM / LOW**, each with file:line + concrete failure scenario
+ fix direction. Then a final `VERDICT: SHIP` or `VERDICT: NO-SHIP` line. If the round-1 findings are
resolved and nothing new is ship-blocking, say `VERDICT: SHIP` plainly.
codex
I’m performing a fresh, read-only adversarial review of the current branch diff. I’ll verify each prior finding directly against the code and tests, then inspect the public/admin API contracts and UI edge cases for regressions.
exec
/bin/bash -lc "sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-security-bug-scan/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-code-quality/SKILL.md && sed -n '1,240p' .agents/skills/sysndd-frontend-integration/SKILL.md && sed -n '1,220p' /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## Instruction Priority

Superpowers skills override default system prompt behavior, but **user instructions always take precedence**:

1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) — highest priority
2. **Superpowers skills** — override default system behavior where they conflict
3. **Default system prompt** — lowest priority

If CLAUDE.md, GEMINI.md, or AGENTS.md says "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you—follow it directly. Never use the Read tool on skill files.

**In Copilot CLI:** Use the `skill` tool. Skills are auto-discovered from installed plugins. The `skill` tool works the same as Claude Code's `Skill` tool.

**In Gemini CLI:** Skills activate via the `activate_skill` tool. Gemini loads skill metadata at session start and activates the full content on demand.

**In other environments:** Check your platform's documentation for how skills are loaded.

## Platform Adaptation

Skills use Claude Code tool names. Non-CC platforms: see `references/copilot-tools.md` (Copilot CLI), `references/codex-tools.md` (Codex) for tool equivalents. Gemini CLI users get the tool mapping loaded automatically via GEMINI.md.

# Using Skills

## The Rule

**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means that you should invoke the skill to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.

```dot
digraph skill_flow {
    "User message received" [shape=doublecircle];
    "About to EnterPlanMode?" [shape=doublecircle];
    "Already brainstormed?" [shape=diamond];
    "Invoke brainstorming skill" [shape=box];
    "Might any skill apply?" [shape=diamond];
    "Invoke Skill tool" [shape=box];
    "Announce: 'Using [skill] to [purpose]'" [shape=box];
    "Has checklist?" [shape=diamond];
    "Create TodoWrite todo per item" [shape=box];
    "Follow skill exactly" [shape=box];
    "Respond (including clarifications)" [shape=doublecircle];

    "About to EnterPlanMode?" -> "Already brainstormed?";
    "Already brainstormed?" -> "Invoke brainstorming skill" [label="no"];
    "Already brainstormed?" -> "Might any skill apply?" [label="yes"];
    "Invoke brainstorming skill" -> "Might any skill apply?";

    "User message received" -> "Might any skill apply?";
    "Might any skill apply?" -> "Invoke Skill tool" [label="yes, even 1%"];
    "Might any skill apply?" -> "Respond (including clarifications)" [label="definitely not"];
    "Invoke Skill tool" -> "Announce: 'Using [skill] to [purpose]'";
    "Announce: 'Using [skill] to [purpose]'" -> "Has checklist?";
    "Has checklist?" -> "Create TodoWrite todo per item" [label="yes"];
    "Has checklist?" -> "Follow skill exactly" [label="no"];
    "Create TodoWrite todo per item" -> "Follow skill exactly";
}
```

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

## Skill Priority

When multiple skills could apply, use this order:

1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach the task
2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution

"Let's build X" → brainstorming first, then implementation skills.
"Fix this bug" → debugging first, then domain-specific skills.

## Skill Types

**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.

**Flexible** (patterns): Adapt principles to context.

The skill itself tells you which.

## User Instructions

Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.
---
name: sysndd-security-bug-scan
description: Use when reviewing or writing SysNDD code for security vulnerabilities or correctness bugs — authorization/role gates, SQL/expression injection, credential and secret handling, data exposure through public or MCP surfaces, resource-exhaustion/DoS from external calls, error/info leakage, and the repo's known R/Plumber footguns — especially before merging a diff or PR
---

# SysNDD Security & Bug Scan

A focused **defect + vulnerability** review pass over a diff or PR. Distinct from `sysndd-code-quality` (maintainability) — this hunts for exploitable and correctness-breaking defects. It complements the generic `/security-review` and `/code-review` by encoding SysNDD's specific gates, helpers, and footguns.

Core insight: almost every SysNDD vulnerability is **"bypassed a safe helper that already exists."** For each finding, prefer the in-repo helper over a hand-rolled fix.

## Workflow

1. Scope the diff. For each new/changed **endpoint, DB query, external call, or auth path**, run the relevant checks below.
2. Flag any hand-rolled code that a listed helper already covers.
3. Run the guard tests for the touched areas (see Verify) — a failing guard test usually means the change is wrong, not the guard.
4. Report findings by severity with `file:line` and the concrete in-repo fix; separate must-fix from optional.

## Security Checks

### Authorization & privilege escalation
- Every write / admin / curation endpoint must call `require_role(req, res, "<Role>")`. Auth is **per-endpoint** (no global deny filter) — a handler with no gate is reachable **unauthenticated**.
- `direct_approval` escalates the gate to **Curator** server-side; never trust the client flag (re-checked in `svc_status_apply_direct_approval` / `review_apply_direct_approval`). The frontend `hasMinRole` is UX, not a control.
- Attribution is server-set: `status_user_id <- req$user_id`. Never accept `*_user_id` from the request body.

### Injection (SQL / expression / RCE)
- User `filter` / `sort` tokens must pass through `validate_query_column()` via `generate_filter_expressions()` / `generate_sort_expressions()` with `allowed_columns_for_view()`. **Never `paste0()` or raw input into `rlang::parse_exprs()`** — over a dbplyr `tbl` that is SQL injection **and** R-side RCE (local partial-eval runs `system(...)` etc.).
- Parameterize SQL with `?` placeholders + `DBI::dbBind(stmt, unname(params))`. No string-interpolated values.
- URL-encode external path/query segments: `utils::URLencode(x, reserved = TRUE)`.

### Data exposure (public / MCP)
- MCP and public reads are **approved-public only**: reviews gated `is_primary = 1 AND review_approved = 1`; records from `ndd_entity_view` (active only). A query dropping these leaks **draft/unapproved** curation. See `sysndd-mcp-readonly`.
- MCP must not write, generate LLM summaries, or call live external providers.

### Secrets & credentials
- Auth-sensitive inputs (`/auth/signup`, `/auth/authenticate`, password change) are **JSON body only** — never query string (leaks into access/Traefik logs, browser history).
- Log through `sanitize_request()` / `sanitize_object()` (`SENSITIVE_FIELDS` redaction in `core/logging_sanitizer.R`); never log tokens, passwords, or secrets.
- Do not bake `config.yml` / secrets into image layers (no `COPY config.yml` in `api/Dockerfile`; use the runtime mount).
- Passwords use Argon2id/sodium (`hash_password` / `verify_password` in `core/security.R`); never plaintext comparison.

### Resource exhaustion / DoS
- Every external HTTP call derives its timeout/retry from `external_proxy_budget()` or `make_external_request()` — **no hardcoded `req_timeout(<n>)`** (enforced by `test-unit-external-budget-guard.R`). Wrap fetchers in `memoise_external_success_only(source = "<provider>")`.
- Cheap routes (`/health`, `/auth`, `/statistics`) must never call an external fetcher (`test-unit-cheap-route-isolation.R`).
- Public expensive operations are throttled or cache-only (async submit cap; LLM generation is Curator+ only).

### Error / info leakage
- Mount every endpoint sub-router via `mount_endpoint()` (attaches the RFC 9457 `errorHandler` + `notFoundHandler`). A bare `plumber::pr_mount(...)` leaks opaque `500`s with internal detail and drops correct status codes. Throw classed errors (`stop_for_bad_request` / `stop_for_unauthorized` / …), not bare `stop()`.

## Correctness Footguns (SysNDD-specific)

- `DBI::dbBind()` with `?` placeholders needs `unname(params)`; named lists fail silently.
- `dplyr::select` / `filter` are masked (biomaRt/AnnotationDbi) — namespace them explicitly.
- `config::get` masks `base::get` in the loaded API/worker env — bare `get(x, mode = "function")` errors "unused argument (mode)"; use `base::get` or direct dispatch (`test-unit-base-exists-get-guard.R`).
- Plumber returns JSON scalars as arrays — unwrap before feeding back into params.
- Use `inherits(x, "Date")`, not `is.Date()`.
- Worker-executed code is sourced at worker start — a change is not live until the worker restarts.

## Verify

Run the guard tests for the touched areas, then `make lint-api` and the appropriate test lane:

`test-unit-security.R`, `test-unit-filter-column-allowlist.R`, `test-unit-endpoint-error-handler.R`, `test-endpoint-auth.R` / `test-integration-auth.R`, `test-unit-*-endpoint-guard.R`, `test-unit-external-budget-guard.R`, `test-unit-cheap-route-isolation.R`.

Lead with findings ordered by severity, each with `file:line` and the in-repo fix. If nothing is found, say so and list the checks run plus residual risk.
---
name: sysndd-code-quality
description: Use when reviewing or changing SysNDD code for maintainability, modularity, file size, duplication, simplicity, typed boundaries, tests, or architecture quality before handoff
---

# SysNDD Code Quality

Use this skill as a focused review pass before handoff, during refactors, or when touching large or shared SysNDD files.

## Review Workflow

1. Inspect the diff and the nearby implementation patterns before judging the change.
2. Run deterministic checks first when they are relevant: `make code-quality-audit`, `git diff --check`, targeted tests, `make lint-api`, `make lint-app`, `cd app && npm run type-check`, `cd app && npm run type-check:strict`, or the smallest useful single-test command from `AGENTS.md`.
3. Review the changed files for the quality risks below.
4. Report concrete findings with file and line references. Distinguish must-fix issues from optional cleanup.

## Quality Checks

- **Modularity:** each file/module should have one clear responsibility and a readable public surface. Prefer cohesive helpers, composables, services, or repository functions over adding another mode to an already broad file.
- **600-line soft ceiling:** flag handwritten source files that exceed or approach 600 lines when the change makes them larger. `make code-quality-audit` enforces the deterministic ratchet: new oversized files fail, and baseline oversized files may not grow. Tests, migrations, fixtures, generated files, and tightly coupled implementations may exceed the ceiling when splitting would reduce clarity.
- **KISS:** prefer direct, local solutions that match existing patterns. Push back on speculative abstractions, new dependencies, clever generic utilities, and cross-layer shortcuts.
- **DRY:** remove meaningful duplicated business logic, API normalization, query construction, or UI state handling. Do not extract tiny one-off code if it makes call flow harder to follow.
- **SOLID, pragmatically:** apply dependency direction and single-responsibility thinking, but do not introduce class-heavy architecture just to satisfy a slogan.
- **Frontend boundaries:** views and components should use typed clients from `app/src/api/*`; do not add raw axios calls or direct `localStorage.token` / `localStorage.user` access.
- **API boundaries:** endpoint files should stay thin and delegate reusable logic to services/repositories/helpers without dropping required `svc_` or `service_` prefixes.
- **Tests:** behavior changes need targeted tests or a documented deterministic check. API integration tests that write DB state should use `with_test_db_transaction()` or document why rollback is not possible.
- **Docs:** update durable docs when behavior, commands, runtime assumptions, or contributor expectations change.

## Output

Lead with findings ordered by severity. If there are no findings, say that and list any checks run plus residual risk.
---
name: sysndd-frontend-integration
description: Use when wiring a SysNDD Vue 3 view or component to the backend API, adding a typed API client, handling API errors, or binding backend data into BootstrapVueNext tables and tooltips — especially around Plumber response shapes and BVN table/tooltip quirks
---

# SysNDD Frontend Integration Boundaries

Use this skill when connecting the frontend to the API or binding backend data into the UI. These are the boundary rules and BootstrapVueNext (BVN) quirks that repeatedly bite. For visual/layout work, use `sysndd-visual-design` instead.

## API Access Goes Through Typed Clients

All backend access goes through the typed clients in `app/src/api/*` (`client.ts` is the shared base). **Do not** add raw `axios` calls in views/components, and **do not** read `localStorage.token` / `localStorage.user` directly. Add or extend a typed client method (with its `.spec.ts`) instead.

## Plumber Response Shapes

- **JSON scalars come back as arrays.** Plumber serializes a scalar as `["abc"]`. Unwrap with `unwrapValue` before feeding a value back into `axios` params — otherwise axios encodes `param[]=value`, which Plumber won't match (e.g. an async `job_id`).
- **Errors are RFC 9457 problem+json.** Read them via `extractApiErrorMessage(err, fallback)` (`app/src/utils/api-errors.ts`, which prefers `detail` → `title`). Don't hand-parse error response shapes.

## BootstrapVueNext Table & Tooltip Traps

- **Dotted field keys render blank.** BVN `BTable` (and the `GenericTable` wrapper) cannot display a field whose `key` contains a dot: the cell resolver renders blank, and a `#cell-a.b` slot parses as `cell-a` + `.b` modifier. Alias dotted source columns (e.g. MCA stats `p.value`, `v.test`) to flat keys (`p_value`, `v_test`) before binding them as field keys — see `normalizePhenotypeClusterRows()` in `app/src/components/analyses/phenotypeClusterTable.ts`. Keep the original dotted keys on the row if the Excel export header map still reads them.
- **`v-b-tooltip` is reactive to its binding *value*, not a bound `:title`.** For a tooltip whose text changes (e.g. faceted "filtered/total" counts), bind through the directive value — `v-b-tooltip.hover.bottom="getTooltipText(field)"` — never `:title="getTooltipText(field)"` (that patches `data-original-title` but never re-renders the popover). Static `:title` tooltips whose text never changes are fine. Guard: `app/src/components/tables/columnHeaderTooltipReactivity.spec.ts`.

## Performance

Importing composables from the `@/composables` barrel drags `ngl`/`markdown`/`d3` (~600 KB) onto a route's critical path. On perf-sensitive routes, import composables by their **direct path**, not the barrel.

## Verify

```bash
cd app && npm run type-check          # (+ npm run type-check:strict for touched scope)
cd app && npm run test:unit           # or: npx vitest run <spec> / -t "<name>"
make lint-app                         # ESLint + MSW↔OpenAPI drift check
```
---
name: understand-diff
description: Use when you need to analyze git diffs or pull requests to understand what changed, affected components, and risks
---

# /understand-diff

Analyze the current code changes against the knowledge graph at `.understand-anything/knowledge-graph.json`.

## Graph Structure Reference

The knowledge graph JSON has this structure:
- `project` — {name, description, languages, frameworks, analyzedAt, gitCommitHash}
- `nodes[]` — each has {id, type, name, filePath?, summary, tags[], complexity, languageNotes?}
  - Code node types: file, function, class, module, concept
  - Non-code node types: config, document, service, table, endpoint, pipeline, schema, resource
  - Domain/knowledge node types: domain, flow, step, article, entity, topic, claim, source
  - IDs use the node type as prefix, e.g. `file:path`, `function:path:name`, `config:path`, `article:path`
- `edges[]` — each has {source, target, type, direction, weight}
  - Key types: imports, contains, calls, depends_on, configures, documents, deploys, triggers, contains_flow, flow_step, related, cites
- `layers[]` — each has {id, name, description, nodeIds[]}
- `tour[]` — each has {order, title, description, nodeIds[]}

## How to Read Efficiently

1. Use Grep to search within the JSON for relevant entries BEFORE reading the full file
2. Only read sections you need — don't dump the entire graph into context
3. Node names and summaries are the most useful fields for understanding
4. Edges tell you how components connect — follow imports and calls for dependency chains

## Instructions

1. Check that `.understand-anything/knowledge-graph.json` exists. If not, tell the user to run `/understand` first.

2. **Get the changed files list** (do NOT read the graph yet):
   - If on a branch with uncommitted changes: `git diff --name-only`
   - If on a feature branch: `git diff main...HEAD --name-only` (or the base branch)
   - If the user specifies a PR number: get the diff from that PR

3. **Read project metadata only** — use Grep or Read with a line limit to extract just the `"project"` section for context.

4. **Find nodes for changed files** — for each changed file path, use Grep to search the knowledge graph for:
   - Nodes with matching `"filePath"` values (e.g., `grep "changed/file/path"`)
   - This finds file-level nodes (including non-code types) AND function/class nodes defined in those files
   - Note the `id` values of all matched nodes

5. **Find connected edges (1-hop)** — for each matched node ID, Grep for that ID in the edges to find:
   - What imports or depends on the changed nodes (upstream callers)
   - What the changed nodes import or call (downstream dependencies)
   - These are the "affected components" — things that might break or need updating

6. **Identify affected layers** — Grep for the matched node IDs in the `"layers"` section to determine which architectural layers are touched.

7. **Provide structured analysis**:
   - **Changed Components**: What was directly modified (with summaries from matched nodes)
   - **Affected Components**: What might be impacted (from 1-hop edges)
   - **Affected Layers**: Which architectural layers are touched and cross-layer concerns
   - **Risk Assessment**: Based on node `complexity` values, number of cross-layer edges, and blast radius (number of affected components)
   - Suggest what to review carefully and any potential issues

8. **Write diff overlay for dashboard** — after producing the analysis, write the diff data to `.understand-anything/diff-overlay.json` so the dashboard can visualize changed and affected components. The file contains:
   ```json
   {
     "version": "1.0.0",
     "baseBranch": "<the base branch used>",
     "generatedAt": "<ISO timestamp>",
     "changedFiles": ["<list of changed file paths>"],
     "changedNodeIds": ["<node IDs from step 4>"],
     "affectedNodeIds": ["<node IDs from step 5, excluding changedNodeIds>"]
   }
   ```
   After writing, tell the user they can run `/understand-anything:understand-dashboard` to see the diff overlay visually.

codex
I’m using the repository’s security, code-quality, and frontend-integration review guides to check the public route, typed-client wire contract, and UI lifecycle behavior. The diff-analysis guide also applies; the workspace is read-only, so I’ll use it for impact tracing but cannot create its optional dashboard overlay.
exec
/bin/bash -lc "git status --short && git diff --check origin/master...HEAD && git diff --stat origin/master...HEAD -- ':(exclude).planning/**' && git diff --name-only origin/master...HEAD -- ':(exclude).planning/**' && if [ -f .understand-anything/knowledge-graph.json ]; then rg -n -m 4 '\"project\"|analysis_releases|DataReleases|analysis-snapshot-release' .understand-anything/knowledge-graph.json; else echo 'NO_KNOWLEDGE_GRAPH'; fi" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
?? .planning/reviews/2026-07-19-573-slice-b-diff-codex-prompt-round2.md
?? .planning/reviews/2026-07-19-573-slice-b-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-573-slice-b-diff-codex-review-round2.md
?? .planning/reviews/2026-07-19-573-slice-b-diff-codex-review.md
 AGENTS.md                                          |   1 +
 CHANGELOG.md                                       |  50 +++
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 app/src/api/admin_analysis_release.spec.ts         | 261 +++++++++++
 app/src/api/admin_analysis_release.ts              | 332 ++++++++++++++
 app/src/api/analysis.spec.ts                       | 312 ++++++++++++++
 app/src/api/analysis.ts                            |  11 +
 app/src/api/analysis_releases.ts                   | 319 ++++++++++++++
 app/src/assets/js/constants/main_nav_constants.ts  |   6 +
 .../analyses/ReleaseManifestPanel.spec.ts          | 212 +++++++++
 .../components/analyses/ReleaseManifestPanel.vue   | 433 +++++++++++++++++++
 .../components/analyses/dataReleaseTable.spec.ts   | 150 +++++++
 app/src/components/analyses/dataReleaseTable.ts    | 124 ++++++
 app/src/router/routes.datareleases.spec.ts         |  51 +++
 app/src/router/routes.ts                           |  12 +
 app/src/utils/safe-url.spec.ts                     |  59 +++
 app/src/utils/safe-url.ts                          |  22 +
 app/src/views/admin/ManageAnalysisReleases.spec.ts | 412 ++++++++++++++++++
 app/src/views/admin/ManageAnalysisReleases.vue     | 479 +++++++++++++++++++++
 .../views/admin/useAnalysisReleaseAdmin.spec.ts    | 349 +++++++++++++++
 app/src/views/admin/useAnalysisReleaseAdmin.ts     | 220 ++++++++++
 app/src/views/analyses/DataReleases.spec.ts        | 228 ++++++++++
 app/src/views/analyses/DataReleases.vue            | 376 ++++++++++++++++
 documentation/09-deployment.qmd                    |   2 +
 26 files changed, 4425 insertions(+), 4 deletions(-)
AGENTS.md
CHANGELOG.md
api/version_spec.json
app/package-lock.json
app/package.json
app/src/api/admin_analysis_release.spec.ts
app/src/api/admin_analysis_release.ts
app/src/api/analysis.spec.ts
app/src/api/analysis.ts
app/src/api/analysis_releases.ts
app/src/assets/js/constants/main_nav_constants.ts
app/src/components/analyses/ReleaseManifestPanel.spec.ts
app/src/components/analyses/ReleaseManifestPanel.vue
app/src/components/analyses/dataReleaseTable.spec.ts
app/src/components/analyses/dataReleaseTable.ts
app/src/router/routes.datareleases.spec.ts
app/src/router/routes.ts
app/src/utils/safe-url.spec.ts
app/src/utils/safe-url.ts
app/src/views/admin/ManageAnalysisReleases.spec.ts
app/src/views/admin/ManageAnalysisReleases.vue
app/src/views/admin/useAnalysisReleaseAdmin.spec.ts
app/src/views/admin/useAnalysisReleaseAdmin.ts
app/src/views/analyses/DataReleases.spec.ts
app/src/views/analyses/DataReleases.vue
documentation/09-deployment.qmd
NO_KNOWLEDGE_GRAPH

exec
/bin/bash -lc 'nl -ba app/src/utils/safe-url.ts && nl -ba app/src/utils/safe-url.spec.ts && nl -ba app/src/api/analysis_releases.ts && nl -ba app/src/api/admin_analysis_release.ts && nl -ba app/src/views/analyses/DataReleases.vue' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
     1	// app/src/utils/safe-url.ts
     2	//
     3	// Guards a bound `:href` against scheme injection (#573 Slice B, Codex round-1
     4	// review, HIGH). Vue does not sanitize `javascript:`/`data:`/etc. schemes on a
     5	// bound `:href` — if any admin-authored or upstream string ever reaches a
     6	// public anchor's `href` unvalidated (e.g. `zenodo.record_url`, recorded via
     7	// `PATCH /api/admin/analysis/releases/<id>/doi` with no URL validation on the
     8	// backend), an unauthenticated visitor gets a clickable script URL.
     9
    10	/**
    11	 * Return the URL only if it parses as an http(s) URL; otherwise null.
    12	 * Guards against javascript:/data:/etc. scheme injection in bound hrefs.
    13	 */
    14	export function safeHttpUrl(value: unknown): string | null {
    15	  if (typeof value !== 'string' || value.trim() === '') return null;
    16	  try {
    17	    const u = new URL(value, window.location.origin);
    18	    return u.protocol === 'http:' || u.protocol === 'https:' ? value : null;
    19	  } catch {
    20	    return null;
    21	  }
    22	}
     1	// app/src/utils/safe-url.spec.ts
     2	import { describe, expect, it } from 'vitest';
     3	import { safeHttpUrl } from './safe-url';
     4
     5	describe('safeHttpUrl', () => {
     6	  it('returns an https URL unchanged', () => {
     7	    expect(safeHttpUrl('https://zenodo.org/records/1234')).toBe(
     8	      'https://zenodo.org/records/1234'
     9	    );
    10	  });
    11
    12	  it('returns an http URL unchanged', () => {
    13	    expect(safeHttpUrl('http://example.org/path')).toBe('http://example.org/path');
    14	  });
    15
    16	  it('rejects a javascript: scheme (returns null)', () => {
    17	    expect(safeHttpUrl('javascript:alert(document.cookie)')).toBeNull();
    18	  });
    19
    20	  it('rejects a data: scheme (returns null)', () => {
    21	    expect(safeHttpUrl('data:text/html,<script>alert(1)</script>')).toBeNull();
    22	  });
    23
    24	  it('rejects a vbscript: scheme (returns null)', () => {
    25	    expect(safeHttpUrl('vbscript:msgbox(1)')).toBeNull();
    26	  });
    27
    28	  it('returns null for an empty string', () => {
    29	    expect(safeHttpUrl('')).toBeNull();
    30	  });
    31
    32	  it('returns null for a whitespace-only string', () => {
    33	    expect(safeHttpUrl('   ')).toBeNull();
    34	  });
    35
    36	  it('returns null for null', () => {
    37	    expect(safeHttpUrl(null)).toBeNull();
    38	  });
    39
    40	  it('returns null for undefined', () => {
    41	    expect(safeHttpUrl(undefined)).toBeNull();
    42	  });
    43
    44	  it('returns null for a non-string value', () => {
    45	    expect(safeHttpUrl(42)).toBeNull();
    46	    expect(safeHttpUrl({ href: 'https://evil.example' })).toBeNull();
    47	  });
    48
    49	  it('resolves a relative path against the current origin and returns the original value', () => {
    50	    // A relative path has no explicit scheme, so it resolves against
    51	    // window.location.origin (http: in the jsdom test env) and is allowed —
    52	    // the returned value is the ORIGINAL string, not the resolved absolute URL.
    53	    expect(safeHttpUrl('/some/path')).toBe('/some/path');
    54	  });
    55
    56	  it('rejects a malformed URL that fails to parse even against the origin base', () => {
    57	    expect(safeHttpUrl('http://')).toBeNull();
    58	  });
    59	});
     1	// app/src/api/analysis_releases.ts
     2	//
     3	// Analysis-snapshot release resource helpers (#573).
     4	//
     5	// Immutable, content-addressed frozen exports of the public-ready analysis
     6	// snapshots (functional clusters, phenotype clusters, phenotype-functional
     7	// correlation) — mirrors the release-specific routes in
     8	// api/endpoints/analysis_endpoints.R (mounted at /api/analysis). Split out
     9	// of `analysis.ts` as a cohesive sub-domain to keep that file under the
    10	// repo's 600-line soft ceiling; re-exported from `analysis.ts` so
    11	// `@/api/analysis` stays the single import surface for analysis resources.
    12	//
    13	// All routes here are public/unauthenticated, DB-only, published-releases-only
    14	// (draft releases are never served). See
    15	// api/functions/analysis-snapshot-release-repository.R
    16	// (`analysis_release_public_head()`) for the exact PUBLIC allowlist these
    17	// types mirror.
    18
    19	import type { AxiosRequestConfig } from 'axios';
    20	import { apiClient } from './client';
    21
    22	// ---------------------------------------------------------------------------
    23	// Types
    24	// ---------------------------------------------------------------------------
    25
    26	/**
    27	 * Zenodo DOI metadata attached to a release head. Additive-only (#573):
    28	 * fields are `null` until an admin records them via
    29	 * `PATCH /api/admin/analysis/releases/<id>/doi`; they never affect
    30	 * `content_digest`.
    31	 */
    32	export interface ReleaseZenodo {
    33	  record_url: string | null;
    34	  version_doi: string | null;
    35	  concept_doi: string | null;
    36	}
    37
    38	/**
    39	 * Correlation-layer dependency lineage: pinned source cluster snapshots.
    40	 *
    41	 * The phenotype-functional correlation layer is derived FROM the functional
    42	 * + phenotype cluster layers, so its manifest entry pins exactly which
    43	 * snapshot (by id + payload hash) it was built against (#571/#572 dependency
    44	 * gate) — this is what a consumer cross-checks to confirm the correlation
    45	 * layer is internally consistent with its two source layers.
    46	 */
    47	export interface ReleaseLayerDependency {
    48	  snapshot_id: number;
    49	  payload_hash: string;
    50	}
    51
    52	export interface ReleaseLayerDependencies {
    53	  functional_clusters?: ReleaseLayerDependency;
    54	  phenotype_clusters?: ReleaseLayerDependency;
    55	}
    56
    57	/**
    58	 * Full per-layer identity, as it appears in `manifest.layers[]` on the
    59	 * detail (`GET /releases/<id>`) and `latest` routes. `reproducibility_hash`
    60	 * is `null` for the `phenotype_functional_correlations` layer (that layer
    61	 * has no reproducibility bundle); `dependencies` is non-null ONLY for that
    62	 * same layer.
    63	 */
    64	export interface ReleaseManifestLayer {
    65	  analysis_type: string;
    66	  parameter_hash: string;
    67	  snapshot_id: number;
    68	  input_hash: string | null;
    69	  payload_hash: string | null;
    70	  schema_version: string;
    71	  reproducibility_hash: string | null;
    72	  dependencies: ReleaseLayerDependencies | null;
    73	}
    74
    75	/**
    76	 * Light per-layer summary, as it appears in `layers[]` on each head from the
    77	 * LIST route (`GET /releases`) only — the list route intentionally omits the
    78	 * full manifest (and therefore the fuller `ReleaseManifestLayer` shape) to
    79	 * keep the listing payload cheap.
    80	 */
    81	export interface ReleaseHeadLayer {
    82	  analysis_type: string;
    83	  snapshot_id: number;
    84	  payload_hash: string;
    85	}
    86
    87	/**
    88	 * PUBLIC projection of an `analysis_snapshot_release` head, as returned by
    89	 * `analysis_release_public_head()` (api/functions/analysis-snapshot-release-repository.R).
    90	 *
    91	 * This is a FIXED 14-field allowlist + `zenodo` + conditional `layers`
    92	 * (list route) / `manifest` (detail + latest routes). Admin-only columns
    93	 * (`created_by_user_id`, `last_error_message`, `updated_at`) are NEVER part
    94	 * of this type — do not widen it to match the raw admin head shape in
    95	 * `admin_analysis_release.ts` (a separate, intentionally different type).
    96	 */
    97	export interface ReleaseHead {
    98	  release_id: string;
    99	  /**
   100	   * Reserved string column (`VARCHAR(32)`, migration 045) — always `null`
   101	   * today; the builder never populates it (`api/functions/analysis-snapshot-
   102	   * release.R`). Not a number, and not guaranteed non-null.
   103	   */
   104	  release_version: string | null;
   105	  title: string | null;
   106	  status: string;
   107	  content_digest: string;
   108	  created_at: string;
   109	  published_at: string | null;
   110	  source_data_version: string;
   111	  db_release_version: string | null;
   112	  db_release_commit: string | null;
   113	  manifest_sha256: string;
   114	  bundle_sha256: string;
   115	  license: string;
   116	  file_count: number;
   117	  total_bytes: number;
   118	  zenodo: ReleaseZenodo;
   119	  /** Light per-layer identity (list route only): analysis_type, snapshot_id, payload_hash. */
   120	  layers?: ReleaseHeadLayer[];
   121	}
   122
   123	export interface ReleaseManifestFile {
   124	  path: string;
   125	  sha256: string;
   126	  bytes: number;
   127	}
   128
   129	/**
   130	 * Build provenance recorded on `manifest.generator`
   131	 * (api/functions/analysis-snapshot-release.R, the `analysis_release_build_manifest()`
   132	 * call site). `reproducibility_schema_version` is absent/`null` if the
   133	 * `ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION` constant is not defined at build
   134	 * time.
   135	 */
   136	export interface ReleaseManifestGenerator {
   137	  name: string;
   138	  manifest_schema_version: string;
   139	  reproducibility_schema_version: string | null;
   140	}
   141
   142	/** `manifest.source.db_release`: the DB release identity pinned at build time, if known. */
   143	export interface ReleaseManifestSourceDbRelease {
   144	  version: string | null;
   145	  commit: string | null;
   146	}
   147
   148	/** One entry of `manifest.source.snapshots[]` — the pinned source snapshot per layer. */
   149	export interface ReleaseManifestSourceSnapshot {
   150	  analysis_type: string;
   151	  snapshot_id: number;
   152	  parameter_hash: string;
   153	}
   154
   155	/** `manifest.source`: the shared source-data identity every layer in the release was built from. */
   156	export interface ReleaseManifestSource {
   157	  source_data_version: string;
   158	  db_release: ReleaseManifestSourceDbRelease;
   159	  snapshots: ReleaseManifestSourceSnapshot[];
   160	}
   161
   162	/**
   163	 * The release `manifest.json` shape, built by
   164	 * `analysis_release_build_manifest()` (api/functions/analysis-snapshot-release-manifest.R).
   165	 * Present on the detail (`GET /releases/<id>`) and `latest` routes only —
   166	 * NOT on the list route, which carries the lighter `layers` array on each
   167	 * head instead.
   168	 */
   169	export interface ReleaseManifest {
   170	  release_id: string;
   171	  /** Reserved, currently-unpopulated string column — always `null` today (see `ReleaseHead.release_version`). */
   172	  release_version: string | null;
   173	  title: string | null;
   174	  created_at: string;
   175	  license: string;
   176	  /** Nullable — the build param defaults to `NULL` when the caller omits a scope statement. */
   177	  scope_statement: string | null;
   178	  generator: ReleaseManifestGenerator;
   179	  source: ReleaseManifestSource;
   180	  layers: ReleaseManifestLayer[];
   181	  files: ReleaseManifestFile[];
   182	  content_digest: string;
   183	}
   184
   185	/** `GET /releases/<id>` and `GET /releases/latest`: head + parsed manifest. */
   186	export interface ReleaseDetail extends ReleaseHead {
   187	  manifest: ReleaseManifest;
   188	}
   189
   190	export interface ListReleasesParams {
   191	  limit?: number;
   192	  offset?: number;
   193	}
   194
   195	export interface ListReleasesResponse {
   196	  releases: ReleaseHead[];
   197	  pagination: {
   198	    limit: number;
   199	    offset: number;
   200	    count: number;
   201	  };
   202	}
   203
   204	// ---------------------------------------------------------------------------
   205	// Helpers
   206	// ---------------------------------------------------------------------------
   207
   208	/**
   209	 * GET /api/analysis/releases
   210	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases`).
   211	 *
   212	 * Public, unauthenticated. Lists published analysis-snapshot releases
   213	 * (newest first). `pagination` echoes the CLAMPED effective `limit`/`offset`
   214	 * the service actually queried, not necessarily the caller's raw values.
   215	 */
   216	export async function listReleases(
   217	  params: ListReleasesParams = {},
   218	  config?: AxiosRequestConfig
   219	): Promise<ListReleasesResponse> {
   220	  return apiClient.get<ListReleasesResponse>('/api/analysis/releases', {
   221	    ...config,
   222	    params: { ...(config?.params as object | undefined), ...params },
   223	  });
   224	}
   225
   226	/**
   227	 * GET /api/analysis/releases/latest
   228	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/latest`).
   229	 *
   230	 * Public, unauthenticated. Returns the newest published release's head +
   231	 * manifest (same shape as the detail route).
   232	 *
   233	 * Throws AxiosError 404 when no published release exists yet.
   234	 */
   235	export async function getLatestRelease(config?: AxiosRequestConfig): Promise<ReleaseDetail> {
   236	  return apiClient.get<ReleaseDetail>('/api/analysis/releases/latest', config);
   237	}
   238
   239	/**
   240	 * GET /api/analysis/releases/<release_id>
   241	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>`).
   242	 *
   243	 * Public, unauthenticated. Returns the release head + manifest. An unknown
   244	 * id and a draft id are indistinguishable — both 404 (drafts are never
   245	 * public).
   246	 */
   247	export async function getRelease(
   248	  releaseId: string,
   249	  config?: AxiosRequestConfig
   250	): Promise<ReleaseDetail> {
   251	  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}`;
   252	  return apiClient.get<ReleaseDetail>(path, config);
   253	}
   254
   255	/**
   256	 * GET /api/analysis/releases/<release_id>/manifest.json
   257	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/manifest.json`).
   258	 *
   259	 * Public, unauthenticated. Returns the EXACT stored `manifest.json` bytes
   260	 * verbatim (never re-serialized), so `sha256(bytes) == manifest_sha256` on
   261	 * the release head. Returned as a `Blob` (the R handler uses `@serializer
   262	 * octet application/json`).
   263	 */
   264	export async function downloadReleaseManifest(
   265	  releaseId: string,
   266	  config?: AxiosRequestConfig
   267	): Promise<Blob> {
   268	  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}/manifest.json`;
   269	  const response = await apiClient.raw.get<Blob>(path, {
   270	    ...config,
   271	    responseType: 'blob',
   272	  });
   273	  return response.data;
   274	}
   275
   276	/**
   277	 * GET /api/analysis/releases/<release_id>/file?path=<file_path>
   278	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/file`).
   279	 *
   280	 * Public, unauthenticated. `path` is a QUERY param, not a URL path segment —
   281	 * Plumber 1.3.2 has no `<path:.*>` wildcard, so a nested archive path (e.g.
   282	 * `functional_clusters/payload.json`) cannot be expressed as a path segment.
   283	 * Resolved by an exact `(release_id, file_path)` primary-key lookup; an
   284	 * unknown path is a 404 (there is no filesystem access, so no path-traversal
   285	 * surface). Returned as a `Blob`.
   286	 */
   287	export async function downloadReleaseFile(
   288	  releaseId: string,
   289	  path: string,
   290	  config?: AxiosRequestConfig
   291	): Promise<Blob> {
   292	  const url = `/api/analysis/releases/${encodeURIComponent(releaseId)}/file`;
   293	  const response = await apiClient.raw.get<Blob>(url, {
   294	    ...config,
   295	    params: { ...(config?.params as object | undefined), path },
   296	    responseType: 'blob',
   297	  });
   298	  return response.data;
   299	}
   300
   301	/**
   302	 * GET /api/analysis/releases/<release_id>/bundle
   303	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/bundle`).
   304	 *
   305	 * Public, unauthenticated. Returns the release's pre-built `bundle.tar.gz`
   306	 * verbatim (the R handler uses `@serializer octet application/gzip` and sets
   307	 * `Content-Disposition: attachment`). Returned as a `Blob`.
   308	 */
   309	export async function downloadReleaseBundle(
   310	  releaseId: string,
   311	  config?: AxiosRequestConfig
   312	): Promise<Blob> {
   313	  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}/bundle`;
   314	  const response = await apiClient.raw.get<Blob>(path, {
   315	    ...config,
   316	    responseType: 'blob',
   317	  });
   318	  return response.data;
   319	}
     1	// app/src/api/admin_analysis_release.ts
     2	//
     3	// Administrator-only typed API client for analysis-snapshot RELEASE
     4	// management (#573 Slice B, Task B4a).
     5	//
     6	// Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (mounted at
     7	// /api/admin/analysis) — the release-management routes appended by #573
     8	// Slice A / Task A7. Every route here requires the Administrator role
     9	// (enforced server-side; `apiClient`'s interceptor supplies the bearer
    10	// token) and uses `@serializer unboxedJSON`, so response scalars are
    11	// plain JSON values, NOT array-wrapped — `unwrapScalar` is not needed here
    12	// (contrast `nddscore_admin.ts`, which reads a default-serialized route).
    13	//
    14	// The admin `/DataReleases` management VIEW that consumes this client is a
    15	// separate task (B4b) — this file is client-only, no view/composable/route.
    16
    17	import type { AxiosRequestConfig } from 'axios';
    18	import { apiClient } from './client';
    19
    20	// ---------------------------------------------------------------------------
    21	// Types
    22	// ---------------------------------------------------------------------------
    23
    24	/**
    25	 * Light per-layer identity, as it appears in `layers[]` on each head from
    26	 * the admin LIST route (`GET /releases`) — mirrors `ReleaseHeadLayer` in the
    27	 * public `analysis_releases.ts`, duplicated here so this file has no
    28	 * dependency on that public-only module (see the `AdminReleaseHead` note
    29	 * below for why the two head shapes are intentionally separate types).
    30	 */
    31	export interface AdminReleaseLayer {
    32	  analysis_type: string;
    33	  snapshot_id: number;
    34	  payload_hash: string;
    35	}
    36
    37	/**
    38	 * RAW `analysis_snapshot_release` head, as returned by the admin routes
    39	 * (`analysis_release_list()` / `analysis_release_get()`,
    40	 * api/functions/analysis-snapshot-release-repository.R). This is
    41	 * DELIBERATELY a SEPARATE type from the public `ReleaseHead` in
    42	 * `analysis_releases.ts` — the public projection nests DOI fields under
    43	 * `zenodo` and omits `created_by_user_id`/`last_error_message`; the admin
    44	 * surface returns the flat DOI columns plus those two operational fields.
    45	 * Do not import or reuse the public type here.
    46	 */
    47	export interface AdminReleaseHead {
    48	  release_id: string;
    49	  /**
    50	   * Reserved string column (`VARCHAR(32)`, migration 045) — always `null`
    51	   * today; the builder never populates it (`api/functions/analysis-snapshot-
    52	   * release.R`). Not a number, and not guaranteed non-null.
    53	   */
    54	  release_version: string | null;
    55	  title: string | null;
    56	  status: string;
    57	  manifest_schema_version: string;
    58	  content_digest: string;
    59	  source_data_version: string;
    60	  db_release_version: string | null;
    61	  db_release_commit: string | null;
    62	  manifest_sha256: string;
    63	  bundle_sha256: string;
    64	  license: string;
    65	  file_count: number;
    66	  total_bytes: number;
    67	  created_by_user_id: number | null;
    68	  created_at: string;
    69	  published_at: string | null;
    70	  updated_at: string;
    71	  zenodo_record_id: string | null;
    72	  zenodo_record_url: string | null;
    73	  version_doi: string | null;
    74	  concept_doi: string | null;
    75	  last_error_message: string | null;
    76	  /** Light per-layer summary (list route only). */
    77	  layers?: AdminReleaseLayer[];
    78	  [key: string]: unknown;
    79	}
    80
    81	export interface AdminReleaseListParams {
    82	  limit?: number;
    83	  offset?: number;
    84	}
    85
    86	export interface AdminReleaseListResponse {
    87	  releases: AdminReleaseHead[];
    88	  pagination: {
    89	    limit: number;
    90	    offset: number;
    91	    count: number;
    92	  };
    93	}
    94
    95	export interface BuildReleaseRequest {
    96	  /** Optional layer-registry override; omit for the fixed default registry. */
    97	  layers?: unknown[];
    98	  title?: string;
    99	  scope_statement?: string;
   100	  /** Defaults server-side to `"CC-BY-4.0"`. */
   101	  license?: string;
   102	  /** Defaults server-side to `true`. */
   103	  publish?: boolean;
   104	}
   105
   106	export interface RecordReleaseDoiFields {
   107	  zenodo_record_id?: string;
   108	  zenodo_record_url?: string;
   109	  version_doi?: string;
   110	  concept_doi?: string;
   111	}
   112
   113	/**
   114	 * Discriminated build outcome so a caller (B4b's view) can distinguish a
   115	 * genuinely-new release (201), a content-identical idempotent dup (200),
   116	 * and a transient "sources are mid-refresh" lock (503) — three DIFFERENT
   117	 * non-error outcomes the backend deliberately does not throw for. A 400
   118	 * gate failure (`release_snapshot_not_available`,
   119	 * `release_source_incoherent`, `release_reproducibility_missing`,
   120	 * `release_source_version_mismatch`, `release_dependency_lineage_mismatch`)
   121	 * still rejects as an `ApiError`; the caller reads its message via
   122	 * `extractApiErrorMessage`.
   123	 */
   124	export type BuildReleaseResult =
   125	  | { outcome: 'created'; release: AdminReleaseHead }
   126	  | { outcome: 'exists'; release: AdminReleaseHead }
   127	  | { outcome: 'locked'; retryAfter: number; message: string };
   128
   129	interface ReleaseLockUnavailableBody {
   130	  error: 'release_lock_unavailable';
   131	  message: string;
   132	}
   133
   134	/**
   135	 * Per-preset manifest state, as returned by `GET /snapshots/status`
   136	 * (`service_analysis_snapshot_status()`). The endpoint reports every
   137	 * supported analysis preset — including `phenotype_correlations` and
   138	 * `gene_network_edges`, which are NOT analysis-snapshot-release layers.
   139	 * `RELEASE_LAYER_TYPES` below is the single source of truth for the subset
   140	 * a release build actually consumes.
   141	 */
   142	export interface SnapshotPresetState {
   143	  analysis_type: string;
   144	  parameter_hash: string;
   145	  state: 'available' | 'stale' | 'source_version_mismatch' | 'missing';
   146	  generated_at: string | null;
   147	  activated_at: string | null;
   148	  stale_after: string | null;
   149	  source_data_version: string | null;
   150	  row_counts: Record<string, unknown> | null;
   151	  [key: string]: unknown;
   152	}
   153
   154	export interface SnapshotStatusSummary {
   155	  total: number;
   156	  available: number;
   157	  missing: number;
   158	  stale: number;
   159	  mismatch: number;
   160	}
   161
   162	export interface SnapshotStatusResponse {
   163	  presets: SnapshotPresetState[];
   164	  summary: SnapshotStatusSummary;
   165	}
   166
   167	/**
   168	 * The three analysis types an analysis-snapshot release actually freezes
   169	 * (`analysis_snapshot_release_layers()`, api/functions/analysis-snapshot-
   170	 * release.R). Single source of truth for filtering `GET /snapshots/status`'s
   171	 * broader preset list down to the layers B4b's "disable Build" gate cares
   172	 * about.
   173	 */
   174	export const RELEASE_LAYER_TYPES = [
   175	  'functional_clusters',
   176	  'phenotype_clusters',
   177	  'phenotype_functional_correlations',
   178	] as const;
   179
   180	// ---------------------------------------------------------------------------
   181	// Helpers
   182	// ---------------------------------------------------------------------------
   183
   184	/**
   185	 * POST /api/admin/analysis/releases
   186	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@post /releases`).
   187	 *
   188	 * Administrator-only. Loads the currently active public-ready snapshots,
   189	 * gates them, and persists an immutable, content-addressed release. Uses
   190	 * `apiClient.raw.post` with a widened `validateStatus` so 200 (idempotent
   191	 * dup), 201 (new content), and 503 (`release_lock_unavailable`, sources
   192	 * mid-refresh) all resolve instead of throwing — only those three plus any
   193	 * 4xx/5xx the caller opts into are distinguishable from a throw. 400 (any
   194	 * of the 5 gate-failure classes) and 404 (never actually returned by this
   195	 * route) still throw as `AxiosError`; the caller reads the message via
   196	 * `extractApiErrorMessage`.
   197	 */
   198	export async function buildRelease(
   199	  body: BuildReleaseRequest,
   200	  config?: AxiosRequestConfig
   201	): Promise<BuildReleaseResult> {
   202	  const response = await apiClient.raw.post<AdminReleaseHead | ReleaseLockUnavailableBody>(
   203	    '/api/admin/analysis/releases',
   204	    body,
   205	    {
   206	      ...config,
   207	      validateStatus: (status) => (status >= 200 && status < 300) || status === 503,
   208	    }
   209	  );
   210
   211	  if (response.status === 503) {
   212	    const locked = response.data as ReleaseLockUnavailableBody;
   213	    const retryAfterHeader = response.headers?.['retry-after'];
   214	    const retryAfter = Number.parseInt(String(retryAfterHeader ?? '5'), 10);
   215	    return {
   216	      outcome: 'locked',
   217	      retryAfter: Number.isFinite(retryAfter) ? retryAfter : 5,
   218	      message: locked.message,
   219	    };
   220	  }
   221
   222	  const release = response.data as AdminReleaseHead;
   223	  return {
   224	    outcome: response.status === 201 ? 'created' : 'exists',
   225	    release,
   226	  };
   227	}
   228
   229	/**
   230	 * GET /api/admin/analysis/releases
   231	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /releases`).
   232	 *
   233	 * Administrator-only. Lists ALL releases (draft + published + failed),
   234	 * newest first — unlike the public `GET /api/analysis/releases`
   235	 * (published-only).
   236	 */
   237	export async function listAdminReleases(
   238	  params: AdminReleaseListParams = {},
   239	  config?: AxiosRequestConfig
   240	): Promise<AdminReleaseListResponse> {
   241	  return apiClient.get<AdminReleaseListResponse>('/api/admin/analysis/releases', {
   242	    ...config,
   243	    params: { ...(config?.params as object | undefined), ...params },
   244	  });
   245	}
   246
   247	/**
   248	 * GET /api/admin/analysis/releases/<release_id>
   249	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /releases/<release_id>`).
   250	 *
   251	 * Administrator-only. Resolves a draft release too (`include_draft = true`).
   252	 * Throws AxiosError 404 for an unknown id.
   253	 */
   254	export async function getAdminRelease(
   255	  releaseId: string,
   256	  config?: AxiosRequestConfig
   257	): Promise<AdminReleaseHead> {
   258	  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}`;
   259	  return apiClient.get<AdminReleaseHead>(path, config);
   260	}
   261
   262	/**
   263	 * POST /api/admin/analysis/releases/<release_id>/publish
   264	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@post /releases/<release_id>/publish`).
   265	 *
   266	 * Administrator-only. Throws AxiosError 404 for an unknown id; an
   267	 * already-published release is an idempotent no-op that still returns the
   268	 * current head.
   269	 */
   270	export async function publishRelease(
   271	  releaseId: string,
   272	  config?: AxiosRequestConfig
   273	): Promise<AdminReleaseHead> {
   274	  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}/publish`;
   275	  return apiClient.post<AdminReleaseHead>(path, undefined, config);
   276	}
   277
   278	/**
   279	 * PATCH /api/admin/analysis/releases/<release_id>/doi
   280	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@patch /releases/<release_id>/doi`).
   281	 *
   282	 * Administrator-only. The four DOI fields are Plumber named args read from
   283	 * the query string, so ONLY the keys actually present in `fields` are
   284	 * forwarded as `config.params` — an omitted field must stay unchanged
   285	 * server-side, never nulled out by an unfiltered pass-through.
   286	 */
   287	export async function recordReleaseDoi(
   288	  releaseId: string,
   289	  fields: RecordReleaseDoiFields,
   290	  config?: AxiosRequestConfig
   291	): Promise<AdminReleaseHead> {
   292	  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}/doi`;
   293	  const params: Record<string, string> = {};
   294	  for (const [key, value] of Object.entries(fields)) {
   295	    if (value !== undefined && value !== null && value !== '') {
   296	      params[key] = value;
   297	    }
   298	  }
   299	  return apiClient.patch<AdminReleaseHead>(path, undefined, {
   300	    ...config,
   301	    params: { ...(config?.params as object | undefined), ...params },
   302	  });
   303	}
   304
   305	/**
   306	 * DELETE /api/admin/analysis/releases/<release_id>
   307	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@delete /releases/<release_id>`).
   308	 *
   309	 * Administrator-only. Deletes a DRAFT release only. Throws AxiosError 400
   310	 * if the release is already published, 404 for an unknown id.
   311	 */
   312	export async function deleteDraftRelease(
   313	  releaseId: string,
   314	  config?: AxiosRequestConfig
   315	): Promise<void> {
   316	  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}`;
   317	  await apiClient.delete<unknown>(path, config);
   318	}
   319
   320	/**
   321	 * GET /api/admin/analysis/snapshots/status
   322	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /snapshots/status`).
   323	 *
   324	 * Administrator-only. Per-preset manifest state for every supported
   325	 * analysis preset (not just the three release layers — see
   326	 * `RELEASE_LAYER_TYPES`).
   327	 */
   328	export async function fetchSnapshotStatus(
   329	  config?: AxiosRequestConfig
   330	): Promise<SnapshotStatusResponse> {
   331	  return apiClient.get<SnapshotStatusResponse>('/api/admin/analysis/snapshots/status', config);
   332	}
     1	<!-- src/views/analyses/DataReleases.vue -->
     2	<!--
     3	  Public, unauthenticated page for analysis-snapshot releases (#573 Slice B,
     4	  Task B2): immutable, content-addressed exports of the derived-analysis
     5	  public snapshots (functional clusters, phenotype clusters, phenotype-
     6	  functional correlation). Composes:
     7	    - AnalysisShell (title/subtitle chrome, matches every other analysis view)
     8	    - a releases table (GenericTable, fields from dataReleaseTable.ts)
     9	    - the selected release's manifest/provenance card (ReleaseManifestPanel)
    10	    - download actions (bundle.tar.gz, manifest.json, per-file) and a
    11	      factual "how to verify" disclosure.
    12
    13	  Data flow: `listReleases()` populates the table; `getLatestRelease()`
    14	  populates the initial manifest panel; selecting a row re-fetches via
    15	  `getRelease(release_id)`. `getLatestRelease()` 404s when no release has
    16	  been published yet — that is NOT an error, it is the "no releases yet"
    17	  empty state (SectionCard's `empty` prop collapses to nothing per its own
    18	  contract, so the empty message is rendered from the default slot instead,
    19	  via the existing `ui/EmptyState.vue`).
    20	-->
    21	<template>
    22	  <AnalysisShell
    23	    title="Analysis-snapshot releases"
    24	    subtitle="Immutable, content-addressed exports of SysNDD's public derived analysis (functional clusters, phenotype clusters, and their correlation) — download and independently verify what you get."
    25	  >
    26	    <SectionCard
    27	      title="Published releases"
    28	      :loading="listLoading"
    29	      :empty="false"
    30	      :error="listError"
    31	    >
    32	      <GenericTable :items="releaseRows" :fields="RELEASE_TABLE_FIELDS">
    33	        <template #cell-actions="{ row }">
    34	          <BButton
    35	            size="sm"
    36	            variant="outline-primary"
    37	            :aria-label="`View manifest for release ${row.release_id}`"
    38	            @click="selectRelease(row.release_id)"
    39	          >
    40	            View manifest
    41	          </BButton>
    42	        </template>
    43	      </GenericTable>
    44	    </SectionCard>
    45
    46	    <SectionCard
    47	      title="Release manifest & verification"
    48	      class="data-releases__manifest-card"
    49	      :loading="detailLoading"
    50	      :empty="false"
    51	      :error="detailError"
    52	    >
    53	      <template v-if="selectedRelease">
    54	        <ReleaseManifestPanel :release="selectedRelease" />
    55
    56	        <section class="data-releases__downloads" aria-label="Downloads">
    57	          <h3 class="data-releases__section-title">Downloads</h3>
    58	          <div class="data-releases__download-buttons">
    59	            <BButton
    60	              size="sm"
    61	              variant="primary"
    62	              data-testid="download-bundle-button"
    63	              @click="handleDownloadBundle"
    64	            >
    65	              <i class="bi bi-file-earmark-zip" aria-hidden="true" />
    66	              Download bundle.tar.gz
    67	            </BButton>
    68	            <BButton
    69	              size="sm"
    70	              variant="outline-secondary"
    71	              data-testid="download-manifest-button"
    72	              @click="handleDownloadManifest"
    73	            >
    74	              <i class="bi bi-file-earmark-code" aria-hidden="true" />
    75	              Download manifest.json
    76	            </BButton>
    77	          </div>
    78
    79	          <div v-if="selectedRelease.manifest.files.length" class="data-releases__files">
    80	            <h4 class="data-releases__section-subtitle">Individual files</h4>
    81	            <ul class="data-releases__file-list">
    82	              <li v-for="file in selectedRelease.manifest.files" :key="file.path">
    83	                <button
    84	                  type="button"
    85	                  class="data-releases__file-link"
    86	                  @click="handleDownloadFile(file.path)"
    87	                >
    88	                  {{ file.path }}
    89	                </button>
    90	                <span class="data-releases__file-size">({{ formatReleaseBytes(file.bytes) }})</span>
    91	              </li>
    92	            </ul>
    93	          </div>
    94	        </section>
    95
    96	        <details class="data-releases__verify">
    97	          <summary>How to verify a download</summary>
    98	          <ul>
    99	            <li>
   100	              Recompute the SHA-256 of each downloaded file and compare it against
   101	              <code>manifest.files[].sha256</code> (or the top-level <code>checksums.sha256</code>
   102	              file in the bundle).
   103	            </li>
   104	            <li>
   105	              For the functional and phenotype cluster layers,
   106	              <code>sha256(reproducibility.json)</code> matches that layer's
   107	              <code>reproducibility_hash</code> exactly — the phenotype-functional correlation
   108	              layer has no reproducibility bundle (<code>reproducibility_hash</code> is
   109	              <code>null</code>).
   110	            </li>
   111	            <li>
   112	              <code>payload_hash</code>, <code>input_hash</code>, and <code>snapshot_id</code> are
   113	              lineage anchors: cross-check them against the live <code>meta.snapshot</code> block
   114	              on the matching <code>/api/analysis/*</code> endpoint. They are
   115	              <strong>not</strong> a hash of this release's own <code>payload.json</code> — the
   116	              values round-trip through <code>DECIMAL</code> database columns before the release
   117	              freezes them, so a byte-for-byte match of the payload file is neither guaranteed nor
   118	              attempted.
   119	            </li>
   120	          </ul>
   121	        </details>
   122	      </template>
   123	      <EmptyState
   124	        v-else-if="!detailLoading && !detailError"
   125	        icon="archive"
   126	        title="No releases published yet"
   127	        message="Analysis-snapshot releases are published periodically once public snapshots are available. Check back soon."
   128	      />
   129	    </SectionCard>
   130	  </AnalysisShell>
   131	</template>
   132
   133	<script setup lang="ts">
   134	import { onMounted, ref } from 'vue';
   135	import { useHead } from '@unhead/vue';
   136	import { BButton } from 'bootstrap-vue-next';
   137	import AnalysisShell from '@/components/analyses/AnalysisShell.vue';
   138	import SectionCard from '@/components/ui/SectionCard.vue';
   139	import EmptyState from '@/components/ui/EmptyState.vue';
   140	import GenericTable from '@/components/small/GenericTable.vue';
   141	import ReleaseManifestPanel from '@/components/analyses/ReleaseManifestPanel.vue';
   142	import {
   143	  normalizeReleaseRows,
   144	  formatReleaseBytes,
   145	  RELEASE_TABLE_FIELDS,
   146	  type ReleaseTableRow,
   147	} from '@/components/analyses/dataReleaseTable';
   148	import {
   149	  listReleases,
   150	  getLatestRelease,
   151	  getRelease,
   152	  downloadReleaseBundle,
   153	  downloadReleaseManifest,
   154	  downloadReleaseFile,
   155	  type ReleaseDetail,
   156	} from '@/api/analysis';
   157	import { isApiError } from '@/api/client';
   158	import { extractApiErrorMessage } from '@/utils/api-errors';
   159	import useToast from '@/composables/useToast';
   160
   161	defineOptions({
   162	  name: 'DataReleases',
   163	});
   164
   165	useHead({
   166	  title: 'Analysis-snapshot releases',
   167	  meta: [
   168	    {
   169	      name: 'description',
   170	      content:
   171	        "Download and independently verify SysNDD's immutable, content-addressed analysis-snapshot releases: functional gene clusters, phenotype clusters, and their correlation.",
   172	    },
   173	  ],
   174	});
   175
   176	const { makeToast } = useToast();
   177
   178	const releaseRows = ref<ReleaseTableRow[]>([]);
   179	const listLoading = ref(true);
   180	const listError = ref<string | null>(null);
   181
   182	const selectedRelease = ref<ReleaseDetail | null>(null);
   183	const detailLoading = ref(true);
   184	const detailError = ref<string | null>(null);
   185
   186	/**
   187	 * MEDIUM (#573 Slice B Codex round-1 review): monotonic request token
   188	 * guarding against a stale-response race. If the mount-time
   189	 * `getLatestRelease()` resolves AFTER the user has since clicked "View
   190	 * manifest" on another row (a newer `getRelease(id)` request), the late
   191	 * response must not overwrite `selectedRelease` with the wrong release.
   192	 */
   193	let detailRequestSeq = 0;
   194
   195	async function loadList(): Promise<void> {
   196	  listLoading.value = true;
   197	  listError.value = null;
   198	  try {
   199	    const response = await listReleases();
   200	    releaseRows.value = normalizeReleaseRows(response.releases);
   201	  } catch (err) {
   202	    listError.value = extractApiErrorMessage(err, 'Failed to load analysis-snapshot releases.');
   203	  } finally {
   204	    listLoading.value = false;
   205	  }
   206	}
   207
   208	/**
   209	 * Loads a release detail (head + manifest) via the given fetcher. A 404 is
   210	 * the "no published release" empty state, not an error — see the file
   211	 * header for why that renders through the default slot rather than
   212	 * SectionCard's `empty` prop.
   213	 */
   214	async function loadDetail(fetcher: () => Promise<ReleaseDetail>): Promise<void> {
   215	  const token = ++detailRequestSeq;
   216	  detailLoading.value = true;
   217	  detailError.value = null;
   218	  try {
   219	    const result = await fetcher();
   220	    if (token !== detailRequestSeq) return; // a newer request has since started; discard
   221	    selectedRelease.value = result;
   222	  } catch (err) {
   223	    if (token !== detailRequestSeq) return; // a newer request has since started; discard
   224	    selectedRelease.value = null;
   225	    if (!(isApiError(err) && err.response?.status === 404)) {
   226	      detailError.value = extractApiErrorMessage(err, 'Failed to load the release manifest.');
   227	    }
   228	  } finally {
   229	    if (token === detailRequestSeq) {
   230	      detailLoading.value = false;
   231	    }
   232	  }
   233	}
   234
   235	function selectRelease(releaseId: string): void {
   236	  void loadDetail(() => getRelease(releaseId));
   237	}
   238
   239	/** Triggers a browser download for a Blob via a transient object-URL anchor. */
   240	function triggerBlobDownload(blob: Blob, filename: string): void {
   241	  const url = window.URL.createObjectURL(blob);
   242	  const link = document.createElement('a');
   243	  link.href = url;
   244	  link.setAttribute('download', filename);
   245	  document.body.appendChild(link);
   246	  link.click();
   247	  document.body.removeChild(link);
   248	  window.URL.revokeObjectURL(url);
   249	}
   250
   251	async function handleDownloadBundle(): Promise<void> {
   252	  const release = selectedRelease.value;
   253	  if (!release) return;
   254	  try {
   255	    const blob = await downloadReleaseBundle(release.release_id);
   256	    triggerBlobDownload(blob, `${release.release_id}_bundle.tar.gz`);
   257	  } catch (err) {
   258	    makeToast(extractApiErrorMessage(err, 'Bundle download failed.'), 'Error', 'danger');
   259	  }
   260	}
   261
   262	async function handleDownloadManifest(): Promise<void> {
   263	  const release = selectedRelease.value;
   264	  if (!release) return;
   265	  try {
   266	    const blob = await downloadReleaseManifest(release.release_id);
   267	    triggerBlobDownload(blob, `${release.release_id}_manifest.json`);
   268	  } catch (err) {
   269	    makeToast(extractApiErrorMessage(err, 'Manifest download failed.'), 'Error', 'danger');
   270	  }
   271	}
   272
   273	async function handleDownloadFile(path: string): Promise<void> {
   274	  const release = selectedRelease.value;
   275	  if (!release) return;
   276	  try {
   277	    const blob = await downloadReleaseFile(release.release_id, path);
   278	    triggerBlobDownload(blob, path.split('/').pop() || path);
   279	  } catch (err) {
   280	    makeToast(extractApiErrorMessage(err, 'File download failed.'), 'Error', 'danger');
   281	  }
   282	}
   283
   284	onMounted(() => {
   285	  void loadList();
   286	  void loadDetail(() => getLatestRelease());
   287	});
   288	</script>
   289
   290	<style scoped>
   291	.data-releases__manifest-card {
   292	  margin-top: 1rem;
   293	}
   294
   295	.data-releases__section-title {
   296	  margin: 0 0 0.5rem;
   297	  color: var(--neutral-700, #616161);
   298	  font-size: 0.8125rem;
   299	  font-weight: 700;
   300	  text-transform: uppercase;
   301	  letter-spacing: 0.02em;
   302	}
   303
   304	.data-releases__section-subtitle {
   305	  margin: 0.75rem 0 0.35rem;
   306	  color: var(--neutral-700, #616161);
   307	  font-size: 0.8125rem;
   308	  font-weight: 700;
   309	}
   310
   311	.data-releases__downloads {
   312	  margin-top: 0.85rem;
   313	  padding-top: 0.85rem;
   314	  border-top: 1px solid var(--border-subtle, #e1e7ef);
   315	}
   316
   317	.data-releases__download-buttons {
   318	  display: flex;
   319	  flex-wrap: wrap;
   320	  gap: 0.5rem;
   321	}
   322
   323	.data-releases__file-list {
   324	  margin: 0;
   325	  padding-left: 1.1rem;
   326	  font-size: 0.8125rem;
   327	}
   328
   329	.data-releases__file-list li {
   330	  margin-bottom: 0.2rem;
   331	}
   332
   333	.data-releases__file-link {
   334	  border: none;
   335	  background: none;
   336	  padding: 0;
   337	  color: var(--medical-blue-700, #0d47a1);
   338	  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
   339	  text-decoration: underline;
   340	  cursor: pointer;
   341	}
   342
   343	.data-releases__file-size {
   344	  margin-left: 0.35rem;
   345	  color: var(--neutral-600, #757575);
   346	}
   347
   348	.data-releases__verify {
   349	  margin-top: 0.85rem;
   350	  padding-top: 0.85rem;
   351	  border-top: 1px solid var(--border-subtle, #e1e7ef);
   352	  font-size: 0.85rem;
   353	  color: var(--neutral-700, #4b5563);
   354	}
   355
   356	.data-releases__verify summary {
   357	  cursor: pointer;
   358	  font-weight: 700;
   359	  color: var(--neutral-900, #212121);
   360	}
   361
   362	.data-releases__verify ul {
   363	  margin: 0.5rem 0 0;
   364	  padding-left: 1.1rem;
   365	}
   366
   367	.data-releases__verify li {
   368	  margin-bottom: 0.4rem;
   369	  line-height: 1.5;
   370	}
   371
   372	.data-releases__verify code {
   373	  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
   374	  font-size: 0.8em;
   375	}
   376	</style>

exec
/bin/bash -lc 'nl -ba app/src/components/analyses/ReleaseManifestPanel.vue && nl -ba app/src/components/analyses/ReleaseManifestPanel.spec.ts && nl -ba app/src/views/analyses/DataReleases.spec.ts && nl -ba app/src/api/analysis.spec.ts' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
     1	<!-- src/components/analyses/ReleaseManifestPanel.vue -->
     2	<!--
     3	  Provenance card for one analysis-snapshot release (#573 Slice B, Task B2):
     4	  identity, integrity hashes (copy-to-clipboard), per-layer manifest detail,
     5	  the correlation layer's dependency lineage, and Zenodo DOI links.
     6
     7	  Styled to mirror `nddscore/NddScoreModelCard.vue` (dl-grid provenance
     8	  layout, `displayValue`/`doiUrl` local helpers, mono hash styling). The
     9	  clipboard "Copy"/"Copied" idiom mirrors `small/GenericTableDetails.vue`
    10	  (transient state + a reset timer, guarded for jsdom/no-Clipboard-API envs).
    11	-->
    12	<template>
    13	  <section class="release-manifest-panel" aria-labelledby="release-manifest-panel-title">
    14	    <header class="release-manifest-panel__header">
    15	      <div>
    16	        <h2 id="release-manifest-panel-title" class="release-manifest-panel__title">
    17	          {{ displayTitle }}
    18	        </h2>
    19	        <p class="release-manifest-panel__subtitle">
    20	          Immutable, content-addressed export. Verify a download against the hashes below.
    21	        </p>
    22	      </div>
    23	      <BBadge variant="info" class="release-manifest-panel__badge">
    24	        {{ release.release_id }}
    25	      </BBadge>
    26	    </header>
    27
    28	    <section aria-label="Identity">
    29	      <h3 class="release-manifest-panel__section-title">Identity</h3>
    30	      <dl class="release-manifest-panel__grid">
    31	        <div>
    32	          <dt>Release ID</dt>
    33	          <dd class="release-manifest-panel__mono">{{ release.release_id }}</dd>
    34	        </div>
    35	        <div v-if="release.release_version">
    36	          <dt>Version</dt>
    37	          <dd>{{ release.release_version }}</dd>
    38	        </div>
    39	        <div>
    40	          <dt>Title</dt>
    41	          <dd>{{ displayTitle }}</dd>
    42	        </div>
    43	        <div>
    44	          <dt>Status</dt>
    45	          <dd>{{ release.status }}</dd>
    46	        </div>
    47	        <div>
    48	          <dt>Source data version</dt>
    49	          <dd>{{ release.source_data_version }}</dd>
    50	        </div>
    51	        <div>
    52	          <dt>DB release version</dt>
    53	          <dd>{{ displayValue(release.db_release_version) }}</dd>
    54	        </div>
    55	        <div>
    56	          <dt>DB release commit</dt>
    57	          <dd class="release-manifest-panel__mono">
    58	            {{ displayValue(release.db_release_commit) }}
    59	          </dd>
    60	        </div>
    61	        <div>
    62	          <dt>Created</dt>
    63	          <dd>{{ release.created_at }}</dd>
    64	        </div>
    65	        <div>
    66	          <dt>Published</dt>
    67	          <dd>{{ displayValue(release.published_at) }}</dd>
    68	        </div>
    69	      </dl>
    70	    </section>
    71
    72	    <section aria-label="Integrity hashes">
    73	      <h3 class="release-manifest-panel__section-title">Integrity hashes</h3>
    74	      <dl class="release-manifest-panel__grid release-manifest-panel__grid--hashes">
    75	        <div v-for="hash in integrityHashes" :key="hash.key">
    76	          <dt>{{ hash.label }}</dt>
    77	          <dd class="release-manifest-panel__hash-value">
    78	            <span class="release-manifest-panel__mono">{{ hash.value }}</span>
    79	            <button
    80	              type="button"
    81	              class="release-manifest-panel__copy-button"
    82	              :aria-label="`Copy ${hash.label} to clipboard`"
    83	              @click="copyValue(hash.key, hash.value)"
    84	            >
    85	              <i class="bi bi-clipboard" aria-hidden="true" />
    86	              {{ copiedKey === hash.key ? 'Copied' : 'Copy' }}
    87	            </button>
    88	          </dd>
    89	        </div>
    90	      </dl>
    91	    </section>
    92
    93	    <section aria-label="Layers">
    94	      <h3 class="release-manifest-panel__section-title">Layers</h3>
    95	      <div
    96	        v-for="layer in release.manifest.layers"
    97	        :key="layer.analysis_type"
    98	        class="release-manifest-panel__layer"
    99	      >
   100	        <h4 class="release-manifest-panel__layer-title">{{ layer.analysis_type }}</h4>
   101	        <dl class="release-manifest-panel__grid">
   102	          <div>
   103	            <dt>Snapshot ID</dt>
   104	            <dd>{{ layer.snapshot_id }}</dd>
   105	          </div>
   106	          <div>
   107	            <dt>Payload hash</dt>
   108	            <dd class="release-manifest-panel__mono">{{ displayValue(layer.payload_hash) }}</dd>
   109	          </div>
   110	          <div>
   111	            <dt>Input hash</dt>
   112	            <dd class="release-manifest-panel__mono">{{ displayValue(layer.input_hash) }}</dd>
   113	          </div>
   114	          <div>
   115	            <dt>Reproducibility hash</dt>
   116	            <dd class="release-manifest-panel__mono">
   117	              <span v-if="layer.reproducibility_hash">{{ layer.reproducibility_hash }}</span>
   118	              <span v-else class="text-muted">n/a (not reproducible)</span>
   119	            </dd>
   120	          </div>
   121	        </dl>
   122	      </div>
   123	    </section>
   124
   125	    <section v-if="dependencyLayer" aria-label="Dependency lineage">
   126	      <h3 class="release-manifest-panel__section-title">Dependency lineage</h3>
   127	      <p class="release-manifest-panel__hint">
   128	        {{ dependencyLayer.analysis_type }} is derived from these pinned source-layer snapshots.
   129	      </p>
   130	      <dl class="release-manifest-panel__grid">
   131	        <div v-if="dependencyLayer.dependencies?.functional_clusters">
   132	          <dt>Functional clusters</dt>
   133	          <dd>
   134	            snapshot {{ dependencyLayer.dependencies.functional_clusters.snapshot_id }}
   135	            &middot;
   136	            <span class="release-manifest-panel__mono">{{
   137	              dependencyLayer.dependencies.functional_clusters.payload_hash
   138	            }}</span>
   139	          </dd>
   140	        </div>
   141	        <div v-if="dependencyLayer.dependencies?.phenotype_clusters">
   142	          <dt>Phenotype clusters</dt>
   143	          <dd>
   144	            snapshot {{ dependencyLayer.dependencies.phenotype_clusters.snapshot_id }}
   145	            &middot;
   146	            <span class="release-manifest-panel__mono">{{
   147	              dependencyLayer.dependencies.phenotype_clusters.payload_hash
   148	            }}</span>
   149	          </dd>
   150	        </div>
   151	      </dl>
   152	    </section>
   153
   154	    <section aria-label="DOI">
   155	      <h3 class="release-manifest-panel__section-title">DOI</h3>
   156	      <dl class="release-manifest-panel__grid">
   157	        <div>
   158	          <dt>Version DOI</dt>
   159	          <dd>
   160	            <a
   161	              v-if="safeVersionDoiHref"
   162	              :href="safeVersionDoiHref"
   163	              target="_blank"
   164	              rel="noopener noreferrer"
   165	            >
   166	              {{ release.zenodo.version_doi }}
   167	            </a>
   168	            <span v-else-if="release.zenodo.version_doi">{{ release.zenodo.version_doi }}</span>
   169	            <span v-else class="text-muted">not yet assigned</span>
   170	          </dd>
   171	        </div>
   172	        <div>
   173	          <dt>Concept DOI</dt>
   174	          <dd>
   175	            <a
   176	              v-if="safeConceptDoiHref"
   177	              :href="safeConceptDoiHref"
   178	              target="_blank"
   179	              rel="noopener noreferrer"
   180	            >
   181	              {{ release.zenodo.concept_doi }}
   182	            </a>
   183	            <span v-else-if="release.zenodo.concept_doi">{{ release.zenodo.concept_doi }}</span>
   184	            <span v-else class="text-muted">not yet assigned</span>
   185	          </dd>
   186	        </div>
   187	        <div>
   188	          <dt>Zenodo record</dt>
   189	          <dd>
   190	            <!--
   191	              HIGH (#573 Slice B Codex round-1): `zenodo.record_url` is an
   192	              admin-authored string with no backend URL validation, so it is
   193	              never bound to `:href` unguarded — `safeHttpUrl` only allows
   194	              http(s), rendering anything else (e.g. `javascript:...`) as
   195	              inert plain text instead of a clickable anchor.
   196	            -->
   197	            <a
   198	              v-if="safeRecordUrl"
   199	              :href="safeRecordUrl"
   200	              target="_blank"
   201	              rel="noopener noreferrer"
   202	            >
   203	              Record
   204	            </a>
   205	            <span v-else-if="release.zenodo.record_url">{{ release.zenodo.record_url }}</span>
   206	            <span v-else class="text-muted">not yet assigned</span>
   207	          </dd>
   208	        </div>
   209	      </dl>
   210	    </section>
   211	  </section>
   212	</template>
   213
   214	<script setup lang="ts">
   215	import { computed, onBeforeUnmount, ref } from 'vue';
   216	import { BBadge } from 'bootstrap-vue-next';
   217	import type { ReleaseDetail, ReleaseManifestLayer } from '@/api/analysis';
   218	import { safeHttpUrl } from '@/utils/safe-url';
   219
   220	defineOptions({
   221	  name: 'ReleaseManifestPanel',
   222	});
   223
   224	const props = defineProps<{
   225	  release: ReleaseDetail;
   226	}>();
   227
   228	function displayValue(value: string | number | null | undefined): string {
   229	  return value === null || value === undefined || value === '' ? '—' : String(value);
   230	}
   231
   232	/** `title`, falling back to `release_id` when the reserved `title` column is null. */
   233	const displayTitle = computed(() => props.release.title || props.release.release_id);
   234
   235	function doiUrl(doi: string): string {
   236	  return `https://doi.org/${doi}`;
   237	}
   238
   239	// HIGH (#573 Slice B Codex round-1): `zenodo.record_url` is admin-authored
   240	// and unvalidated by the backend, so it is guarded before ever reaching a
   241	// bound `:href` (see the template note above). The `doiUrl(...)`-constructed
   242	// DOI hrefs are guarded too, defensively — belt-and-suspenders, since the
   243	// scheme there is currently always the hardcoded `https://doi.org/` prefix.
   244	const safeRecordUrl = computed<string | null>(() => safeHttpUrl(props.release.zenodo.record_url));
   245	const safeVersionDoiHref = computed<string | null>(() =>
   246	  props.release.zenodo.version_doi ? safeHttpUrl(doiUrl(props.release.zenodo.version_doi)) : null
   247	);
   248	const safeConceptDoiHref = computed<string | null>(() =>
   249	  props.release.zenodo.concept_doi ? safeHttpUrl(doiUrl(props.release.zenodo.concept_doi)) : null
   250	);
   251
   252	const integrityHashes = computed(() => [
   253	  { key: 'content_digest', label: 'Content digest', value: props.release.content_digest },
   254	  { key: 'manifest_sha256', label: 'Manifest SHA-256', value: props.release.manifest_sha256 },
   255	  { key: 'bundle_sha256', label: 'Bundle SHA-256', value: props.release.bundle_sha256 },
   256	]);
   257
   258	/** The one manifest layer with pinned source-layer dependencies (the correlation layer), if any. */
   259	const dependencyLayer = computed<ReleaseManifestLayer | null>(
   260	  () => props.release.manifest.layers.find((layer) => layer.dependencies != null) ?? null
   261	);
   262
   263	// --- Copy-to-clipboard: mirrors small/GenericTableDetails.vue's transient
   264	// "Copy" -> "Copied" state + reset-timer lifecycle. ---
   265	const copiedKey = ref<string | null>(null);
   266	let copyResetTimer: ReturnType<typeof setTimeout> | null = null;
   267
   268	async function copyValue(key: string, value: string): Promise<void> {
   269	  if (!value || !navigator.clipboard?.writeText) {
   270	    return;
   271	  }
   272	  try {
   273	    await navigator.clipboard.writeText(value);
   274	    copiedKey.value = key;
   275	    if (copyResetTimer) {
   276	      clearTimeout(copyResetTimer);
   277	    }
   278	    copyResetTimer = setTimeout(() => {
   279	      copiedKey.value = null;
   280	      copyResetTimer = null;
   281	    }, 1600);
   282	  } catch {
   283	    copiedKey.value = null;
   284	  }
   285	}
   286
   287	onBeforeUnmount(() => {
   288	  if (copyResetTimer) {
   289	    clearTimeout(copyResetTimer);
   290	    copyResetTimer = null;
   291	  }
   292	});
   293	</script>
   294
   295	<style scoped>
   296	.release-manifest-panel {
   297	  display: grid;
   298	  gap: 1rem;
   299	  padding: 1rem;
   300	  border: 1px solid #d7dee8;
   301	  border-radius: var(--radius-lg, 8px);
   302	  background: #fff;
   303	  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
   304	}
   305
   306	.release-manifest-panel__header {
   307	  display: flex;
   308	  flex-wrap: wrap;
   309	  align-items: flex-start;
   310	  justify-content: space-between;
   311	  gap: 0.75rem;
   312	}
   313
   314	.release-manifest-panel__title {
   315	  margin: 0;
   316	  color: var(--neutral-900, #212121);
   317	  font-size: 1rem;
   318	  font-weight: 700;
   319	  line-height: 1.25;
   320	}
   321
   322	.release-manifest-panel__subtitle {
   323	  margin: 0.15rem 0 0;
   324	  color: var(--neutral-600, #757575);
   325	  font-size: 0.875rem;
   326	  line-height: 1.45;
   327	}
   328
   329	.release-manifest-panel__badge {
   330	  max-width: 100%;
   331	  overflow-wrap: anywhere;
   332	  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
   333	}
   334
   335	.release-manifest-panel__section-title {
   336	  margin: 0 0 0.4rem;
   337	  color: var(--neutral-700, #616161);
   338	  font-size: 0.8125rem;
   339	  font-weight: 700;
   340	  text-transform: uppercase;
   341	  letter-spacing: 0.02em;
   342	}
   343
   344	.release-manifest-panel__grid {
   345	  display: grid;
   346	  grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
   347	  gap: 0.5rem 0.75rem;
   348	  margin: 0;
   349	}
   350
   351	.release-manifest-panel__grid div {
   352	  min-width: 0;
   353	}
   354
   355	.release-manifest-panel__grid dt {
   356	  margin: 0;
   357	  color: var(--neutral-700, #616161);
   358	  font-size: 0.75rem;
   359	  font-weight: 700;
   360	}
   361
   362	.release-manifest-panel__grid dd {
   363	  margin: 0.1rem 0 0;
   364	  color: var(--neutral-900, #212121);
   365	  font-size: 0.8125rem;
   366	  overflow-wrap: anywhere;
   367	}
   368
   369	.release-manifest-panel__grid a {
   370	  color: var(--medical-blue-700, #0d47a1);
   371	}
   372
   373	.release-manifest-panel__mono {
   374	  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
   375	}
   376
   377	.release-manifest-panel__grid--hashes dd.release-manifest-panel__hash-value {
   378	  display: flex;
   379	  flex-wrap: wrap;
   380	  align-items: center;
   381	  gap: 0.5rem;
   382	}
   383
   384	.release-manifest-panel__grid--hashes .release-manifest-panel__mono {
   385	  word-break: break-all;
   386	}
   387
   388	.release-manifest-panel__copy-button {
   389	  display: inline-flex;
   390	  flex: 0 0 auto;
   391	  align-items: center;
   392	  gap: 0.25rem;
   393	  padding: 0.08rem 0.4rem;
   394	  border: 1px solid #0a58ca;
   395	  border-radius: var(--radius-md, 6px);
   396	  background: #fff;
   397	  color: #0a58ca;
   398	  font-size: 0.72rem;
   399	  line-height: 1.6;
   400	  white-space: nowrap;
   401	}
   402
   403	.release-manifest-panel__copy-button:hover,
   404	.release-manifest-panel__copy-button:focus {
   405	  border-color: #084298;
   406	  background-color: #0a58ca;
   407	  color: #fff;
   408	}
   409
   410	.release-manifest-panel__layer {
   411	  padding: 0.5rem 0.65rem;
   412	  border: 1px solid #e1e7ef;
   413	  border-radius: var(--radius-md, 6px);
   414	  background: #f8fafc;
   415	}
   416
   417	.release-manifest-panel__layer + .release-manifest-panel__layer {
   418	  margin-top: 0.5rem;
   419	}
   420
   421	.release-manifest-panel__layer-title {
   422	  margin: 0 0 0.35rem;
   423	  color: var(--neutral-900, #212121);
   424	  font-size: 0.875rem;
   425	  font-weight: 700;
   426	}
   427
   428	.release-manifest-panel__hint {
   429	  margin: 0 0 0.5rem;
   430	  color: var(--neutral-600, #757575);
   431	  font-size: 0.8125rem;
   432	}
   433	</style>
     1	import { mount } from '@vue/test-utils';
     2	import { describe, expect, it, vi } from 'vitest';
     3	import ReleaseManifestPanel from './ReleaseManifestPanel.vue';
     4	import type { ReleaseDetail } from '@/api/analysis';
     5
     6	function makeReleaseDetail(): ReleaseDetail {
     7	  return {
     8	    release_id: 'asr_0123456789abcdef',
     9	    release_version: null,
    10	    title: 'SysNDD analysis-snapshot release',
    11	    status: 'published',
    12	    content_digest: 'a'.repeat(64),
    13	    created_at: '2026-07-01T00:00:00Z',
    14	    published_at: '2026-07-01T00:05:00Z',
    15	    source_data_version: '2026-07-01',
    16	    db_release_version: '11.4.0',
    17	    db_release_commit: 'deadbeef',
    18	    manifest_sha256: 'b'.repeat(64),
    19	    bundle_sha256: 'c'.repeat(64),
    20	    license: 'CC-BY-4.0',
    21	    file_count: 10,
    22	    total_bytes: 1258291,
    23	    zenodo: {
    24	      record_url: 'https://zenodo.org/records/1234',
    25	      version_doi: '10.5281/zenodo.1234',
    26	      concept_doi: '10.5281/zenodo.1233',
    27	    },
    28	    manifest: {
    29	      release_id: 'asr_0123456789abcdef',
    30	      release_version: null,
    31	      title: 'SysNDD analysis-snapshot release',
    32	      created_at: '2026-07-01T00:00:00Z',
    33	      license: 'CC-BY-4.0',
    34	      scope_statement: 'Public derived analysis only.',
    35	      generator: {
    36	        name: 'sysndd-analysis-snapshot-release-build',
    37	        manifest_schema_version: '1.0',
    38	        reproducibility_schema_version: '1.2',
    39	      },
    40	      source: {
    41	        source_data_version: '2026-07-01',
    42	        db_release: { version: '11.4.0', commit: 'deadbeef' },
    43	        snapshots: [
    44	          { analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp-hash' },
    45	          { analysis_type: 'phenotype_clusters', snapshot_id: 202, parameter_hash: 'pp-hash' },
    46	        ],
    47	      },
    48	      layers: [
    49	        {
    50	          analysis_type: 'functional_clusters',
    51	          parameter_hash: 'fp-hash',
    52	          snapshot_id: 101,
    53	          input_hash: 'in-func',
    54	          payload_hash: 'pay-func',
    55	          schema_version: '1.2',
    56	          reproducibility_hash: 'repro-func',
    57	          dependencies: null,
    58	        },
    59	        {
    60	          analysis_type: 'phenotype_clusters',
    61	          parameter_hash: 'pp-hash',
    62	          snapshot_id: 202,
    63	          input_hash: 'in-pheno',
    64	          payload_hash: 'pay-pheno',
    65	          schema_version: '1.2',
    66	          reproducibility_hash: 'repro-pheno',
    67	          dependencies: null,
    68	        },
    69	        {
    70	          analysis_type: 'phenotype_functional_correlations',
    71	          parameter_hash: 'cp-hash',
    72	          snapshot_id: 303,
    73	          input_hash: 'in-corr',
    74	          payload_hash: 'pay-corr',
    75	          schema_version: '1.2',
    76	          reproducibility_hash: null,
    77	          dependencies: {
    78	            functional_clusters: { snapshot_id: 101, payload_hash: 'pay-func' },
    79	            phenotype_clusters: { snapshot_id: 202, payload_hash: 'pay-pheno' },
    80	          },
    81	        },
    82	      ],
    83	      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
    84	      content_digest: 'a'.repeat(64),
    85	    },
    86	  };
    87	}
    88
    89	describe('ReleaseManifestPanel', () => {
    90	  it('renders all three integrity hashes', () => {
    91	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
    92	    const text = wrapper.text();
    93	    expect(text).toContain('a'.repeat(64)); // content_digest
    94	    expect(text).toContain('b'.repeat(64)); // manifest_sha256
    95	    expect(text).toContain('c'.repeat(64)); // bundle_sha256
    96	  });
    97
    98	  it('shows the correlation layer dependency lineage and its "n/a" reproducibility hash', () => {
    99	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   100	    const text = wrapper.text();
   101	    expect(text).toContain('n/a (not reproducible)');
   102	    expect(text).toContain('Dependency lineage');
   103	    expect(text).toContain('pay-func');
   104	    expect(text).toContain('pay-pheno');
   105	    expect(text).toContain('101');
   106	    expect(text).toContain('202');
   107	  });
   108
   109	  it('renders the version DOI as a doi.org link', () => {
   110	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   111	    const link = wrapper.find('a[href="https://doi.org/10.5281/zenodo.1234"]');
   112	    expect(link.exists()).toBe(true);
   113	    expect(link.text()).toBe('10.5281/zenodo.1234');
   114	  });
   115
   116	  it('shows "not yet assigned" when a DOI is null', () => {
   117	    const release = makeReleaseDetail();
   118	    release.zenodo = { record_url: null, version_doi: null, concept_doi: null };
   119	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   120	    expect(wrapper.text()).toContain('not yet assigned');
   121	  });
   122
   123	  // HIGH (#573 Slice B Codex round-1 review): the DOI PATCH endpoint stores
   124	  // `zenodo.record_url` with no backend URL validation, so an admin-authored
   125	  // `javascript:` string must never become a clickable `<a href>` for an
   126	  // unauthenticated /DataReleases visitor.
   127	  it('does not render a clickable link for a javascript:-scheme record_url (renders plain text instead)', () => {
   128	    const release = makeReleaseDetail();
   129	    release.zenodo = {
   130	      ...release.zenodo,
   131	      record_url: 'javascript:alert(document.cookie)',
   132	    };
   133	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   134
   135	    const maliciousAnchor = wrapper
   136	      .findAll('a')
   137	      .find((anchor) => (anchor.attributes('href') ?? '').startsWith('javascript:'));
   138	    expect(maliciousAnchor).toBeUndefined();
   139
   140	    // The value itself is not lost — it is still shown, just as inert text.
   141	    expect(wrapper.text()).toContain('javascript:alert(document.cookie)');
   142	  });
   143
   144	  it('does not render a clickable link for a data:-scheme record_url either', () => {
   145	    const release = makeReleaseDetail();
   146	    release.zenodo = {
   147	      ...release.zenodo,
   148	      record_url: 'data:text/html,<script>alert(1)</script>',
   149	    };
   150	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   151
   152	    const dataAnchor = wrapper
   153	      .findAll('a')
   154	      .find((anchor) => (anchor.attributes('href') ?? '').startsWith('data:'));
   155	    expect(dataAnchor).toBeUndefined();
   156	  });
   157
   158	  it('still renders a normal https record_url as a clickable link', () => {
   159	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   160	    const link = wrapper.find('a[href="https://zenodo.org/records/1234"]');
   161	    expect(link.exists()).toBe(true);
   162	    expect(link.text()).toBe('Record');
   163	  });
   164
   165	  it('omits the Version row when release_version is null (the current, always-null default)', () => {
   166	    const release = makeReleaseDetail();
   167	    expect(release.release_version).toBeNull();
   168	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   169	    const dts = wrapper.findAll('dt').map((dt) => dt.text());
   170	    expect(dts).not.toContain('Version');
   171	  });
   172
   173	  it('shows the Version row when release_version is populated', () => {
   174	    const release = makeReleaseDetail();
   175	    release.release_version = '1.0';
   176	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   177	    const dts = wrapper.findAll('dt').map((dt) => dt.text());
   178	    expect(dts).toContain('Version');
   179	    expect(wrapper.text()).toContain('1.0');
   180	  });
   181
   182	  it('falls back to release_id for the title when title is null', () => {
   183	    const release = makeReleaseDetail();
   184	    release.title = null;
   185	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   186	    expect(wrapper.find('#release-manifest-panel-title').text()).toBe('asr_0123456789abcdef');
   187	    const dts = wrapper.findAll('dt').map((dt) => dt.text());
   188	    const titleDd = wrapper.findAll('dt').find((dt) => dt.text() === 'Title')?.element.nextElementSibling;
   189	    expect(dts).toContain('Title');
   190	    expect(titleDd?.textContent).toBe('asr_0123456789abcdef');
   191	  });
   192
   193	  it('copies a hash to the clipboard when its copy button is clicked', async () => {
   194	    const writeText = vi.fn().mockResolvedValue(undefined);
   195	    Object.defineProperty(navigator, 'clipboard', {
   196	      configurable: true,
   197	      value: { writeText },
   198	    });
   199
   200	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   201	    const button = wrapper
   202	      .findAll('button')
   203	      .find((btn) => btn.attributes('aria-label') === 'Copy Content digest to clipboard');
   204	    expect(button).toBeTruthy();
   205
   206	    await button!.trigger('click');
   207	    await wrapper.vm.$nextTick();
   208
   209	    expect(writeText).toHaveBeenCalledWith('a'.repeat(64));
   210	    expect(button!.text()).toContain('Copied');
   211	  });
   212	});
     1	import { mount, flushPromises } from '@vue/test-utils';
     2	import { describe, expect, it, vi, beforeEach } from 'vitest';
     3	import type { ReleaseDetail, ReleaseHead } from '@/api/analysis_releases';
     4
     5	vi.mock('@unhead/vue', () => ({
     6	  useHead: vi.fn(),
     7	}));
     8
     9	vi.mock('@/composables/useToast', () => ({
    10	  default: () => ({ makeToast: vi.fn() }),
    11	}));
    12
    13	const listReleasesMock = vi.fn();
    14	const getLatestReleaseMock = vi.fn();
    15	const getReleaseMock = vi.fn();
    16	const downloadReleaseBundleMock = vi.fn();
    17	const downloadReleaseManifestMock = vi.fn();
    18	const downloadReleaseFileMock = vi.fn();
    19
    20	vi.mock('@/api/analysis', () => ({
    21	  listReleases: (...args: unknown[]) => listReleasesMock(...args),
    22	  getLatestRelease: (...args: unknown[]) => getLatestReleaseMock(...args),
    23	  getRelease: (...args: unknown[]) => getReleaseMock(...args),
    24	  downloadReleaseBundle: (...args: unknown[]) => downloadReleaseBundleMock(...args),
    25	  downloadReleaseManifest: (...args: unknown[]) => downloadReleaseManifestMock(...args),
    26	  downloadReleaseFile: (...args: unknown[]) => downloadReleaseFileMock(...args),
    27	}));
    28
    29	import DataReleases from './DataReleases.vue';
    30
    31	function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
    32	  return {
    33	    release_id: 'asr_0123456789abcdef',
    34	    release_version: null,
    35	    title: 'SysNDD analysis-snapshot release',
    36	    status: 'published',
    37	    content_digest: 'a'.repeat(64),
    38	    created_at: '2026-07-01T00:00:00Z',
    39	    published_at: '2026-07-01T00:05:00Z',
    40	    source_data_version: '2026-07-01',
    41	    db_release_version: '11.4.0',
    42	    db_release_commit: 'deadbeef',
    43	    manifest_sha256: 'b'.repeat(64),
    44	    bundle_sha256: 'c'.repeat(64),
    45	    license: 'CC-BY-4.0',
    46	    file_count: 1,
    47	    total_bytes: 1258291,
    48	    zenodo: { record_url: null, version_doi: null, concept_doi: null },
    49	    ...overrides,
    50	  };
    51	}
    52
    53	function makeReleaseDetail(overrides: Partial<ReleaseHead> = {}): ReleaseDetail {
    54	  return {
    55	    ...makeReleaseHead(overrides),
    56	    manifest: {
    57	      release_id: overrides.release_id ?? 'asr_0123456789abcdef',
    58	      release_version: null,
    59	      title: 'SysNDD analysis-snapshot release',
    60	      created_at: '2026-07-01T00:00:00Z',
    61	      license: 'CC-BY-4.0',
    62	      scope_statement: 'Public derived analysis only.',
    63	      // `manifest.generator`/`manifest.source` are nested objects on the wire
    64	      // (api/functions/analysis-snapshot-release.R), not strings.
    65	      generator: {
    66	        name: 'sysndd-analysis-snapshot-release-build',
    67	        manifest_schema_version: '1.0',
    68	        reproducibility_schema_version: '1.2',
    69	      },
    70	      source: {
    71	        source_data_version: '2026-07-01',
    72	        db_release: { version: '11.4.0', commit: 'deadbeef' },
    73	        snapshots: [
    74	          { analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp-hash' },
    75	        ],
    76	      },
    77	      layers: [
    78	        {
    79	          analysis_type: 'functional_clusters',
    80	          parameter_hash: 'fp-hash',
    81	          snapshot_id: 101,
    82	          input_hash: 'in-func',
    83	          payload_hash: 'pay-func',
    84	          schema_version: '1.2',
    85	          reproducibility_hash: 'repro-func',
    86	          dependencies: null,
    87	        },
    88	      ],
    89	      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
    90	      content_digest: 'a'.repeat(64),
    91	    },
    92	  };
    93	}
    94
    95	function notFoundError() {
    96	  return Object.assign(new Error('Not found'), {
    97	    isAxiosError: true,
    98	    response: {
    99	      status: 404,
   100	      data: {
   101	        type: 'about:blank',
   102	        title: 'Not Found',
   103	        status: 404,
   104	        detail: 'No published analysis-snapshot release exists yet',
   105	      },
   106	    },
   107	  });
   108	}
   109
   110	describe('DataReleases', () => {
   111	  beforeEach(() => {
   112	    vi.clearAllMocks();
   113	    // jsdom has no real object-URL / anchor-download support.
   114	    window.URL.createObjectURL = vi.fn(() => 'blob:mock-url');
   115	    window.URL.revokeObjectURL = vi.fn();
   116	  });
   117
   118	  it('renders the release table row and the manifest panel for the latest release', async () => {
   119	    listReleasesMock.mockResolvedValue({
   120	      releases: [makeReleaseHead()],
   121	      pagination: { limit: 50, offset: 0, count: 1 },
   122	    });
   123	    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
   124
   125	    const wrapper = mount(DataReleases);
   126	    await flushPromises();
   127
   128	    expect(listReleasesMock).toHaveBeenCalled();
   129	    expect(getLatestReleaseMock).toHaveBeenCalled();
   130	    const text = wrapper.text();
   131	    expect(text).toContain('asr_0123456789abcdef');
   132	    expect(text).toContain('Integrity hashes');
   133	    expect(text).toContain('a'.repeat(64));
   134	  });
   135
   136	  it('re-fetches the detail for a different release when its "View manifest" button is clicked', async () => {
   137	    listReleasesMock.mockResolvedValue({
   138	      releases: [makeReleaseHead({ release_id: 'asr_other' })],
   139	      pagination: { limit: 50, offset: 0, count: 1 },
   140	    });
   141	    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
   142	    getReleaseMock.mockResolvedValue(makeReleaseDetail({ release_id: 'asr_other' }));
   143
   144	    const wrapper = mount(DataReleases);
   145	    await flushPromises();
   146
   147	    const button = wrapper
   148	      .findAll('button')
   149	      .find((btn) => btn.text().includes('View manifest'));
   150	    expect(button).toBeTruthy();
   151	    await button!.trigger('click');
   152	    await flushPromises();
   153
   154	    expect(getReleaseMock).toHaveBeenCalledWith('asr_other');
   155	  });
   156
   157	  // MEDIUM (#573 Slice B Codex round-1 review): a slow mount-time
   158	  // `getLatestRelease()` must not clobber a later, already-resolved
   159	  // `getRelease(id)` selection when it finally settles. Regression-guards the
   160	  // monotonic request token in `loadDetail()`.
   161	  it('discards a stale getLatestRelease response that resolves after a later "View manifest" selection', async () => {
   162	    listReleasesMock.mockResolvedValue({
   163	      releases: [makeReleaseHead({ release_id: 'asr_other' })],
   164	      pagination: { limit: 50, offset: 0, count: 1 },
   165	    });
   166
   167	    let resolveLatest: (value: ReleaseDetail) => void = () => {};
   168	    getLatestReleaseMock.mockReturnValue(
   169	      new Promise<ReleaseDetail>((resolve) => {
   170	        resolveLatest = resolve;
   171	      })
   172	    );
   173	    getReleaseMock.mockResolvedValue(makeReleaseDetail({ release_id: 'asr_other' }));
   174
   175	    const wrapper = mount(DataReleases);
   176	    // The list resolves; the mount-time getLatestRelease() request is still pending.
   177	    await flushPromises();
   178
   179	    const button = wrapper
   180	      .findAll('button')
   181	      .find((btn) => btn.text().includes('View manifest'));
   182	    expect(button).toBeTruthy();
   183	    await button!.trigger('click');
   184	    await flushPromises();
   185
   186	    // The later request (getRelease) resolved first and is now shown.
   187	    expect(wrapper.text()).toContain('asr_other');
   188
   189	    // The stale, earlier-started getLatestRelease request finally settles with
   190	    // a DIFFERENT release. It must be discarded, not overwrite the selection.
   191	    resolveLatest(makeReleaseDetail({ release_id: 'asr_0123456789abcdef' }));
   192	    await flushPromises();
   193
   194	    expect(wrapper.text()).toContain('asr_other');
   195	    expect(wrapper.text()).not.toContain('asr_0123456789abcdef');
   196	  });
   197
   198	  it('downloads the bundle when the download-bundle button is clicked', async () => {
   199	    listReleasesMock.mockResolvedValue({
   200	      releases: [makeReleaseHead()],
   201	      pagination: { limit: 50, offset: 0, count: 1 },
   202	    });
   203	    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
   204	    downloadReleaseBundleMock.mockResolvedValue(new Blob(['bundle-bytes']));
   205
   206	    const wrapper = mount(DataReleases);
   207	    await flushPromises();
   208
   209	    await wrapper.find('[data-testid="download-bundle-button"]').trigger('click');
   210	    await flushPromises();
   211
   212	    expect(downloadReleaseBundleMock).toHaveBeenCalledWith('asr_0123456789abcdef');
   213	  });
   214
   215	  it('shows the "No releases published yet" empty state on a 404 from getLatestRelease, not a raw error', async () => {
   216	    listReleasesMock.mockResolvedValue({
   217	      releases: [],
   218	      pagination: { limit: 50, offset: 0, count: 0 },
   219	    });
   220	    getLatestReleaseMock.mockRejectedValue(notFoundError());
   221
   222	    const wrapper = mount(DataReleases);
   223	    await flushPromises();
   224
   225	    expect(wrapper.text()).toContain('No releases published yet');
   226	    expect(wrapper.find('[data-testid="section-card-error"]').exists()).toBe(false);
   227	  });
   228	});
     1	// app/src/api/analysis.spec.ts
     2	//
     3	// Vitest + MSW spec for the typed analysis helpers (W3.3).
     4
     5	import { describe, it, expect } from 'vitest';
     6	import { http, HttpResponse } from 'msw';
     7
     8	import {
     9	  getFunctionalClustering,
    10	  getPhenotypeClustering,
    11	  getPhenotypeFunctionalCorrelation,
    12	  getNetworkEdges,
    13	  getFunctionalClusterSummary,
    14	  getPhenotypeClusterSummary,
    15	  isSnapshotPreparingError,
    16	  listReleases,
    17	  getLatestRelease,
    18	  getRelease,
    19	  downloadReleaseManifest,
    20	  downloadReleaseFile,
    21	  downloadReleaseBundle,
    22	  type FunctionalClusteringResponse,
    23	  type PhenotypeCluster,
    24	  type PhenotypeClusteringResponse,
    25	  type CorrelationResponse,
    26	  type NetworkEdgesResponse,
    27	  type ClusterSummary,
    28	  type ReleaseHead,
    29	  type ReleaseDetail,
    30	} from './analysis';
    31	import { isApiError } from './client';
    32	import { extractApiErrorMessage } from '@/utils/api-errors';
    33	import { server } from '@/test-utils/mocks/server';
    34
    35	describe('api/analysis — getFunctionalClustering', () => {
    36	  it('forwards pagination params for the public Leiden preset', async () => {
    37	    let observedQuery: URLSearchParams | null = null;
    38	    const ok: FunctionalClusteringResponse = {
    39	      categories: [],
    40	      clusters: [],
    41	      pagination: {
    42	        page_size: 10,
    43	        page_after: '',
    44	        next_cursor: null,
    45	        total_count: 0,
    46	        has_more: false,
    47	      },
    48	      meta: {
    49	        algorithm: 'leiden',
    50	        elapsed_seconds: 0.1,
    51	        gene_count: 0,
    52	        cluster_count: 0,
    53	      },
    54	    };
    55	    server.use(
    56	      http.get('/api/analysis/functional_clustering', ({ request }) => {
    57	        observedQuery = new URL(request.url).searchParams;
    58	        return HttpResponse.json(ok);
    59	      })
    60	    );
    61
    62	    await getFunctionalClustering({
    63	      page_size: '25',
    64	      page_after: 'abc',
    65	    });
    66
    67	    expect(observedQuery).not.toBeNull();
    68	    const q = observedQuery as unknown as URLSearchParams;
    69	    expect(q.get('page_size')).toBe('25');
    70	    expect(q.has('algorithm')).toBe(false);
    71	    expect(q.get('page_after')).toBe('abc');
    72	  });
    73
    74	  it('returns the cursor-paginated envelope on 200', async () => {
    75	    server.use(
    76	      http.get('/api/analysis/functional_clustering', () =>
    77	        HttpResponse.json<FunctionalClusteringResponse>({
    78	          categories: [{ value: 'KEGG', text: 'KEGG' }],
    79	          clusters: [],
    80	          pagination: {
    81	            page_size: 10,
    82	            page_after: '',
    83	            next_cursor: null,
    84	            total_count: 0,
    85	            has_more: false,
    86	          },
    87	          meta: {
    88	            algorithm: 'leiden',
    89	            elapsed_seconds: 0.05,
    90	            gene_count: 0,
    91	            cluster_count: 0,
    92	          },
    93	        })
    94	      )
    95	    );
    96	    const result = await getFunctionalClustering();
    97	    expect(result.meta.algorithm).toBe('leiden');
    98	  });
    99	});
   100
   101	describe('api/analysis — getPhenotypeClustering', () => {
   102	  it('returns the cluster envelope on 200', async () => {
   103	    const clusters: PhenotypeCluster[] = [
   104	      { cluster: 1, identifiers: [{ entity_id: 1, hgnc_id: 'HGNC:1', symbol: 'A1BG' }] },
   105	    ];
   106	    const response: PhenotypeClusteringResponse = {
   107	      clusters,
   108	      meta: {
   109	        snapshot: {
   110	          analysis_type: 'phenotype_clusters',
   111	        },
   112	      },
   113	    };
   114	    server.use(http.get('/api/analysis/phenotype_clustering', () => HttpResponse.json(response)));
   115	    const result = await getPhenotypeClustering();
   116	    expect(result.clusters).toHaveLength(1);
   117	    expect(result.clusters[0].identifiers[0].symbol).toBe('A1BG');
   118	    expect(result.meta.snapshot?.analysis_type).toBe('phenotype_clusters');
   119	  });
   120	});
   121
   122	describe('api/analysis — getPhenotypeFunctionalCorrelation', () => {
   123	  it('returns the correlation envelope on 200', async () => {
   124	    const ok: CorrelationResponse = {
   125	      correlation_matrix: [
   126	        [1.0, 0.2],
   127	        [0.2, 1.0],
   128	      ],
   129	      correlation_melted: [{ x: 'pc_1', y: 'fc_1', value: 0.2 }],
   130	    };
   131	    server.use(
   132	      http.get('/api/analysis/phenotype_functional_cluster_correlation', () =>
   133	        HttpResponse.json(ok)
   134	      )
   135	    );
   136	    const result = await getPhenotypeFunctionalCorrelation();
   137	    expect(result.correlation_melted).toHaveLength(1);
   138	  });
   139	});
   140
   141	describe('api/analysis — getNetworkEdges', () => {
   142	  it('forwards network params and returns display layout coordinates', async () => {
   143	    let observedQuery: URLSearchParams | null = null;
   144	    const ok: NetworkEdgesResponse = {
   145	      nodes: [{ hgnc_id: 'HGNC:1', symbol: 'AAA', cluster: 1, degree: 4, x: 10, y: 20 }],
   146	      edges: [],
   147	      metadata: {
   148	        node_count: 1,
   149	        edge_count: 0,
   150	        cluster_count: 1,
   151	        total_edges: 0,
   152	        edges_filtered: false,
   153	        elapsed_seconds: 0,
   154	        display_layout_status: 'available',
   155	        snapshot: {
   156	          analysis_type: 'gene_network_edges',
   157	        },
   158	      },
   159	    };
   160	    server.use(
   161	      http.get('/api/analysis/network_edges', ({ request }) => {
   162	        observedQuery = new URL(request.url).searchParams;
   163	        return HttpResponse.json(ok);
   164	      })
   165	    );
   166
   167	    const result = await getNetworkEdges({
   168	      cluster_type: 'clusters',
   169	      min_confidence: '400',
   170	      max_edges: '10000',
   171	    });
   172	    expect(observedQuery).not.toBeNull();
   173	    const q = observedQuery as unknown as URLSearchParams;
   174	    expect(q.get('cluster_type')).toBe('clusters');
   175	    expect(q.get('min_confidence')).toBe('400');
   176	    expect(q.get('max_edges')).toBe('10000');
   177	    expect(result.nodes[0].x).toBe(10);
   178	    expect(result.nodes[0].y).toBe(20);
   179	    expect(result.metadata.snapshot?.analysis_type).toBe('gene_network_edges');
   180	  });
   181	});
   182
   183	describe('api/analysis — getFunctionalClusterSummary', () => {
   184	  it('forwards cluster_hash + cluster_number params', async () => {
   185	    let observedQuery: URLSearchParams | null = null;
   186	    const ok: ClusterSummary = {
   187	      cluster_hash: 'abc',
   188	      cluster_number: 1,
   189	      summary_json: { summary: 'A short summary.' },
   190	    };
   191	    server.use(
   192	      http.get('/api/analysis/functional_cluster_summary', ({ request }) => {
   193	        observedQuery = new URL(request.url).searchParams;
   194	        return HttpResponse.json(ok);
   195	      })
   196	    );
   197
   198	    await getFunctionalClusterSummary({ cluster_hash: 'abc', cluster_number: '1' });
   199	    const q = observedQuery as unknown as URLSearchParams;
   200	    expect(q?.get('cluster_hash')).toBe('abc');
   201	    expect(q?.get('cluster_number')).toBe('1');
   202	  });
   203
   204	  it('throws AxiosError on 503 (LLM not configured)', async () => {
   205	    server.use(
   206	      http.get('/api/analysis/functional_cluster_summary', () =>
   207	        HttpResponse.json({ error: 'LLM not configured' }, { status: 503 })
   208	      )
   209	    );
   210
   211	    let caught: unknown;
   212	    try {
   213	      await getFunctionalClusterSummary({ cluster_hash: 'x', cluster_number: '1' });
   214	    } catch (err) {
   215	      caught = err;
   216	    }
   217	    expect(isApiError(caught)).toBe(true);
   218	    if (isApiError(caught)) {
   219	      expect(caught.response?.status).toBe(503);
   220	    }
   221	  });
   222	});
   223
   224	describe('api/analysis — getPhenotypeClusterSummary', () => {
   225	  it('returns the summary on 200', async () => {
   226	    const ok: ClusterSummary = {
   227	      cluster_hash: 'def',
   228	      cluster_number: 2,
   229	      summary_json: { themes: ['ID', 'epilepsy'] },
   230	    };
   231	    server.use(http.get('/api/analysis/phenotype_cluster_summary', () => HttpResponse.json(ok)));
   232	    const result = await getPhenotypeClusterSummary({ cluster_hash: 'def', cluster_number: '2' });
   233	    expect(result.cluster_hash).toBe('def');
   234	  });
   235	});
   236
   237	describe('isSnapshotPreparingError', () => {
   238	  it('is true for a 503 snapshot_missing problem', () => {
   239	    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'snapshot_missing' } } })).toBe(true);
   240	  });
   241	  it('is true when code is a 1-element array (R/Plumber scalar serialisation) (#440)', () => {
   242	    // The real API serialises the problem code as ["snapshot_missing"], not a
   243	    // bare string — the "being prepared" state must still trigger.
   244	    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: ['snapshot_missing'] } } })).toBe(true);
   245	    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: ['snapshot_stale'] } } })).toBe(true);
   246	  });
   247	  it('is true for snapshot_stale and source_version_mismatch', () => {
   248	    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'snapshot_stale' } } })).toBe(true);
   249	    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'source_version_mismatch' } } })).toBe(true);
   250	  });
   251	  it('is false for a non-503 error', () => {
   252	    expect(isSnapshotPreparingError({ response: { status: 500, data: { code: 'snapshot_missing' } } })).toBe(false);
   253	  });
   254	  it('is false for a 503 with an unrelated code', () => {
   255	    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'CAPACITY_EXCEEDED' } } })).toBe(false);
   256	  });
   257	  it('is false for a plain error', () => {
   258	    expect(isSnapshotPreparingError(new Error('boom'))).toBe(false);
   259	  });
   260	});
   261
   262	// ---------------------------------------------------------------------------
   263	// Analysis-snapshot releases (#573 Slice B, Task B1)
   264	// ---------------------------------------------------------------------------
   265
   266	function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
   267	  return {
   268	    release_id: 'asr_0123456789abcdef',
   269	    release_version: null,
   270	    title: 'SysNDD analysis-snapshot release',
   271	    status: 'published',
   272	    content_digest: 'a'.repeat(64),
   273	    created_at: '2026-07-01T00:00:00Z',
   274	    published_at: '2026-07-01T00:05:00Z',
   275	    source_data_version: '2026-07-01',
   276	    db_release_version: '11.4.0',
   277	    db_release_commit: 'deadbeef',
   278	    manifest_sha256: 'b'.repeat(64),
   279	    bundle_sha256: 'c'.repeat(64),
   280	    license: 'CC-BY-4.0',
   281	    file_count: 10,
   282	    total_bytes: 123456,
   283	    zenodo: { record_url: null, version_doi: null, concept_doi: null },
   284	    ...overrides,
   285	  };
   286	}
   287
   288	/**
   289	 * `manifest.generator`/`manifest.source` are nested objects on the wire
   290	 * (api/functions/analysis-snapshot-release.R), not strings — see the
   291	 * `ReleaseManifestGenerator`/`ReleaseManifestSource` types.
   292	 */
   293	function makeManifestGeneratorSource() {
   294	  return {
   295	    generator: {
   296	      name: 'sysndd-analysis-snapshot-release-build',
   297	      manifest_schema_version: '1.0',
   298	      reproducibility_schema_version: '1.2',
   299	    },
   300	    source: {
   301	      source_data_version: '2026-07-01',
   302	      db_release: { version: '11.4.0', commit: 'deadbeef' },
   303	      snapshots: [
   304	        { analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp-hash' },
   305	      ],
   306	    },
   307	  };
   308	}
   309
   310	describe('api/analysis — listReleases', () => {
   311	  it('returns the releases envelope on 200', async () => {
   312	    server.use(
   313	      http.get('/api/analysis/releases', () =>
   314	        HttpResponse.json({
   315	          releases: [makeReleaseHead()],
   316	          pagination: { limit: 50, offset: 0, count: 1 },
   317	        })
   318	      )
   319	    );
   320	    const result = await listReleases();
   321	    expect(result.releases).toHaveLength(1);
   322	    expect(result.releases[0].release_id).toBe('asr_0123456789abcdef');
   323	    expect(result.pagination.count).toBe(1);
   324	    // Public head allowlist: admin-only fields must never be present.
   325	    expect(result.releases[0]).not.toHaveProperty('created_by_user_id');
   326	    expect(result.releases[0]).not.toHaveProperty('last_error_message');
   327	  });
   328
   329	  it('forwards limit/offset query params', async () => {
   330	    let observedQuery: URLSearchParams | null = null;
   331	    server.use(
   332	      http.get('/api/analysis/releases', ({ request }) => {
   333	        observedQuery = new URL(request.url).searchParams;
   334	        return HttpResponse.json({
   335	          releases: [],
   336	          pagination: { limit: 10, offset: 5, count: 0 },
   337	        });
   338	      })
   339	    );
   340	    await listReleases({ limit: 10, offset: 5 });
   341	    const q = observedQuery as unknown as URLSearchParams;
   342	    expect(q.get('limit')).toBe('10');
   343	    expect(q.get('offset')).toBe('5');
   344	  });
   345
   346	  it('throws AxiosError on non-2xx', async () => {
   347	    server.use(
   348	      http.get('/api/analysis/releases', () =>
   349	        HttpResponse.json(
   350	          { type: 'about:blank', title: 'Internal Server Error', status: 500, detail: 'boom' },
   351	          { status: 500 }
   352	        )
   353	      )
   354	    );
   355	    let caught: unknown;
   356	    try {
   357	      await listReleases();
   358	    } catch (err) {
   359	      caught = err;
   360	    }
   361	    expect(isApiError(caught)).toBe(true);
   362	    expect(extractApiErrorMessage(caught, 'fallback')).toBe('boom');
   363	  });
   364	});
   365
   366	describe('api/analysis — getLatestRelease', () => {
   367	  it('returns the head + manifest on 200', async () => {
   368	    const detail: ReleaseDetail = {
   369	      ...makeReleaseHead(),
   370	      manifest: {
   371	        release_id: 'asr_0123456789abcdef',
   372	        release_version: null,
   373	        title: 'SysNDD analysis-snapshot release',
   374	        created_at: '2026-07-01T00:00:00Z',
   375	        license: 'CC-BY-4.0',
   376	        scope_statement: 'Public derived analysis only.',
   377	        ...makeManifestGeneratorSource(),
   378	        layers: [],
   379	        files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
   380	        content_digest: 'a'.repeat(64),
   381	      },
   382	    };
   383	    server.use(http.get('/api/analysis/releases/latest', () => HttpResponse.json(detail)));
   384	    const result = await getLatestRelease();
   385	    expect(result.release_id).toBe('asr_0123456789abcdef');
   386	    expect(result.manifest.files).toHaveLength(1);
   387	  });
   388
   389	  it('throws AxiosError 404 when no published release exists', async () => {
   390	    server.use(
   391	      http.get('/api/analysis/releases/latest', () =>
   392	        HttpResponse.json(
   393	          {
   394	            type: 'about:blank',
   395	            title: 'Not Found',
   396	            status: 404,
   397	            detail: 'No published analysis-snapshot release exists yet',
   398	          },
   399	          { status: 404 }
   400	        )
   401	      )
   402	    );
   403	    let caught: unknown;
   404	    try {
   405	      await getLatestRelease();
   406	    } catch (err) {
   407	      caught = err;
   408	    }
   409	    expect(isApiError(caught)).toBe(true);
   410	    if (isApiError(caught)) {
   411	      expect(caught.response?.status).toBe(404);
   412	    }
   413	  });
   414	});
   415
   416	describe('api/analysis — getRelease', () => {
   417	  it('returns the head + manifest on 200 and encodes the release id', async () => {
   418	    let observedPath = '';
   419	    const detail: ReleaseDetail = {
   420	      ...makeReleaseHead({ release_id: 'asr_abc123' }),
   421	      manifest: {
   422	        release_id: 'asr_abc123',
   423	        release_version: null,
   424	        title: 'SysNDD analysis-snapshot release',
   425	        created_at: '2026-07-01T00:00:00Z',
   426	        license: 'CC-BY-4.0',
   427	        scope_statement: 'Public derived analysis only.',
   428	        ...makeManifestGeneratorSource(),
   429	        layers: [],
   430	        files: [],
   431	        content_digest: 'a'.repeat(64),
   432	      },
   433	    };
   434	    server.use(
   435	      http.get('/api/analysis/releases/:releaseId', ({ request, params }) => {
   436	        observedPath = new URL(request.url).pathname;
   437	        expect(params.releaseId).toBe('asr_abc123');
   438	        return HttpResponse.json(detail);
   439	      })
   440	    );
   441	    const result = await getRelease('asr_abc123');
   442	    expect(result.release_id).toBe('asr_abc123');
   443	    expect(observedPath).toBe('/api/analysis/releases/asr_abc123');
   444	  });
   445
   446	  it('throws AxiosError 404 for an unknown/draft release id', async () => {
   447	    server.use(
   448	      http.get('/api/analysis/releases/:releaseId', () =>
   449	        HttpResponse.json(
   450	          { type: 'about:blank', title: 'Not Found', status: 404, detail: 'not found' },
   451	          { status: 404 }
   452	        )
   453	      )
   454	    );
   455	    let caught: unknown;
   456	    try {
   457	      await getRelease('asr_unknown');
   458	    } catch (err) {
   459	      caught = err;
   460	    }
   461	    expect(isApiError(caught)).toBe(true);
   462	    if (isApiError(caught)) {
   463	      expect(caught.response?.status).toBe(404);
   464	    }
   465	  });
   466	});
   467
   468	describe('api/analysis — downloadReleaseManifest', () => {
   469	  it('returns the manifest.json bytes as a Blob', async () => {
   470	    server.use(
   471	      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
   472	        HttpResponse.json({ release_id: 'asr_abc123' })
   473	      )
   474	    );
   475	    const blob = await downloadReleaseManifest('asr_abc123');
   476	    expect(blob).toBeInstanceOf(Blob);
   477	  });
   478
   479	  it('throws AxiosError on non-2xx', async () => {
   480	    server.use(
   481	      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
   482	        HttpResponse.json(
   483	          { type: 'about:blank', title: 'Not Found', status: 404, detail: 'not found' },
   484	          { status: 404 }
   485	        )
   486	      )
   487	    );
   488	    let caught: unknown;
   489	    try {
   490	      await downloadReleaseManifest('asr_unknown');
   491	    } catch (err) {
   492	      caught = err;
   493	    }
   494	    expect(isApiError(caught)).toBe(true);
   495	  });
   496	});
   497
   498	describe('api/analysis — downloadReleaseFile', () => {
   499	  it('forwards the file path as a query param and returns a Blob', async () => {
   500	    let observedQuery: URLSearchParams | null = null;
   501	    server.use(
   502	      http.get('/api/analysis/releases/:releaseId/file', ({ request }) => {
   503	        observedQuery = new URL(request.url).searchParams;
   504	        return HttpResponse.json({ ok: true });
   505	      })
   506	    );
   507	    const blob = await downloadReleaseFile('asr_abc123', 'functional_clusters/payload.json');
   508	    expect(blob).toBeInstanceOf(Blob);
   509	    const q = observedQuery as unknown as URLSearchParams;
   510	    expect(q.get('path')).toBe('functional_clusters/payload.json');
   511	  });
   512
   513	  it('throws AxiosError on non-2xx (unknown file path)', async () => {
   514	    server.use(
   515	      http.get('/api/analysis/releases/:releaseId/file', () =>
   516	        HttpResponse.json(
   517	          { type: 'about:blank', title: 'Not Found', status: 404, detail: 'not found' },
   518	          { status: 404 }
   519	        )
   520	      )
   521	    );
   522	    let caught: unknown;
   523	    try {
   524	      await downloadReleaseFile('asr_abc123', 'nope.json');
   525	    } catch (err) {
   526	      caught = err;
   527	    }
   528	    expect(isApiError(caught)).toBe(true);
   529	    if (isApiError(caught)) {
   530	      expect(caught.response?.status).toBe(404);
   531	    }
   532	  });
   533	});
   534
   535	describe('api/analysis — downloadReleaseBundle', () => {
   536	  it('returns the bundle.tar.gz bytes as a Blob', async () => {
   537	    server.use(
   538	      http.get('/api/analysis/releases/:releaseId/bundle', () =>
   539	        HttpResponse.json({ ok: true })
   540	      )
   541	    );
   542	    const blob = await downloadReleaseBundle('asr_abc123');
   543	    expect(blob).toBeInstanceOf(Blob);
   544	  });
   545
   546	  it('throws AxiosError on non-2xx', async () => {
   547	    server.use(
   548	      http.get('/api/analysis/releases/:releaseId/bundle', () =>
   549	        HttpResponse.json(
   550	          { type: 'about:blank', title: 'Not Found', status: 404, detail: 'not found' },
   551	          { status: 404 }
   552	        )
   553	      )
   554	    );
   555	    let caught: unknown;
   556	    try {
   557	      await downloadReleaseBundle('asr_unknown');
   558	    } catch (err) {
   559	      caught = err;
   560	    }
   561	    expect(isApiError(caught)).toBe(true);
   562	  });
   563	});

exec
/bin/bash -lc "rg -n -C 5 'analysis_release_build_manifest|generator|scope_statement|db_release|snapshots|public_head|analysis_release_public' api/functions/analysis-snapshot-release*.R api/services/analysis-snapshot-release-service.R api/endpoints/analysis_endpoints.R api/endpoints/admin_analysis_snapshot_endpoints.R && nl -ba app/src/views/analyses/DataReleases.spec.ts && nl -ba app/src/components/analyses/ReleaseManifestPanel.spec.ts" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
api/endpoints/admin_analysis_snapshot_endpoints.R-1-## -------------------------------------------------------------------##
api/endpoints/admin_analysis_snapshot_endpoints.R-2-# api/endpoints/admin_analysis_snapshot_endpoints.R
api/endpoints/admin_analysis_snapshot_endpoints.R-3-#
api/endpoints/admin_analysis_snapshot_endpoints.R:4:# Administrator-only HTTP triggers for the durable public analysis snapshots that
api/endpoints/admin_analysis_snapshot_endpoints.R-5-# the /api/analysis/* read endpoints serve. Mounted at /api/admin/analysis, so:
api/endpoints/admin_analysis_snapshot_endpoints.R:6:#   POST /api/admin/analysis/snapshots/refresh  (submit refresh jobs)
api/endpoints/admin_analysis_snapshot_endpoints.R:7:#   GET  /api/admin/analysis/snapshots/status   (per-preset manifest state)
api/endpoints/admin_analysis_snapshot_endpoints.R-8-#
api/endpoints/admin_analysis_snapshot_endpoints.R-9-# All three snapshot submit paths (startup hook, this endpoint, and the operator
api/endpoints/admin_analysis_snapshot_endpoints.R:10:# script scripts/refresh-analysis-snapshots.R) share one function,
api/endpoints/admin_analysis_snapshot_endpoints.R-11-# service_analysis_snapshot_submit_refresh(), so submission logic is not
api/endpoints/admin_analysis_snapshot_endpoints.R-12-# duplicated. Spec: .planning/superpowers/specs/2026-06-14-analysis-snapshot-bootstrap-design.md
api/endpoints/admin_analysis_snapshot_endpoints.R-13-#
api/endpoints/admin_analysis_snapshot_endpoints.R-14-# #573 Slice A / Task A7 appends 6 Administrator-only routes for immutable,
api/endpoints/admin_analysis_snapshot_endpoints.R-15-# content-addressed public analysis-snapshot RELEASES: build/list/detail/
--
api/endpoints/admin_analysis_snapshot_endpoints.R-31-}
api/endpoints/admin_analysis_snapshot_endpoints.R-32-
api/endpoints/admin_analysis_snapshot_endpoints.R-33-#* Submit analysis snapshot refresh jobs (Administrator only)
api/endpoints/admin_analysis_snapshot_endpoints.R-34-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-35-#* Idempotently submits `analysis_snapshot_refresh` jobs so the worker rebuilds +
api/endpoints/admin_analysis_snapshot_endpoints.R:36:#* activates the durable public-ready snapshots. By default only presets without a
api/endpoints/admin_analysis_snapshot_endpoints.R-37-#* current public-ready snapshot are submitted; pass `force=true` to rebuild all.
api/endpoints/admin_analysis_snapshot_endpoints.R-38-#* Re-submitting a queued/running refresh returns the existing job (dedup).
api/endpoints/admin_analysis_snapshot_endpoints.R-39-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-40-#* @tag admin
api/endpoints/admin_analysis_snapshot_endpoints.R-41-#* @serializer unboxedJSON
api/endpoints/admin_analysis_snapshot_endpoints.R-42-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-43-#* @param analysis_type:str Optional single preset (e.g. "gene_network_edges"). Omit for all supported presets.
api/endpoints/admin_analysis_snapshot_endpoints.R-44-#* @param force:bool Optional; rebuild even when a current snapshot exists. Default false.
api/endpoints/admin_analysis_snapshot_endpoints.R-45-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:46:#* @post /snapshots/refresh
api/endpoints/admin_analysis_snapshot_endpoints.R-47-function(req, res, analysis_type = NULL, force = FALSE) {
api/endpoints/admin_analysis_snapshot_endpoints.R-48-  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-49-
api/endpoints/admin_analysis_snapshot_endpoints.R-50-  at <- if (is.null(analysis_type) || !nzchar(as.character(analysis_type[[1]]))) {
api/endpoints/admin_analysis_snapshot_endpoints.R-51-    NULL
--
api/endpoints/admin_analysis_snapshot_endpoints.R-70-#* access.
api/endpoints/admin_analysis_snapshot_endpoints.R-71-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-72-#* @tag admin
api/endpoints/admin_analysis_snapshot_endpoints.R-73-#* @serializer unboxedJSON
api/endpoints/admin_analysis_snapshot_endpoints.R-74-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:75:#* @get /snapshots/status
api/endpoints/admin_analysis_snapshot_endpoints.R-76-function(req, res) {
api/endpoints/admin_analysis_snapshot_endpoints.R-77-  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-78-  service_analysis_snapshot_status()
api/endpoints/admin_analysis_snapshot_endpoints.R-79-}
api/endpoints/admin_analysis_snapshot_endpoints.R-80-
--
api/endpoints/admin_analysis_snapshot_endpoints.R-132-  if (is.na(parsed)) default else parsed
api/endpoints/admin_analysis_snapshot_endpoints.R-133-}
api/endpoints/admin_analysis_snapshot_endpoints.R-134-
api/endpoints/admin_analysis_snapshot_endpoints.R-135-#* Build (and, by default, publish) a new analysis-snapshot release (Administrator only)
api/endpoints/admin_analysis_snapshot_endpoints.R-136-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:137:#* Loads the currently active public-ready snapshots for the fixed layer
api/endpoints/admin_analysis_snapshot_endpoints.R-138-#* registry (or a caller-supplied `layers` override -- see the JSON body
api/endpoints/admin_analysis_snapshot_endpoints.R-139-#* shape below), gates them (available + hard coherence + reproducibility
api/endpoints/admin_analysis_snapshot_endpoints.R-140-#* presence + shared source-data version + dependency lineage), materializes
api/endpoints/admin_analysis_snapshot_endpoints.R-141-#* the release files, and persists an immutable, content-addressed release.
api/endpoints/admin_analysis_snapshot_endpoints.R-142-#* A rebuild whose content is IDENTICAL to an existing release is idempotent
--
api/endpoints/admin_analysis_snapshot_endpoints.R-144-#* 201. A gate failure (a layer not available / incoherent / missing its
api/endpoints/admin_analysis_snapshot_endpoints.R-145-#* reproducibility bundle / mismatched source version or dependency lineage)
api/endpoints/admin_analysis_snapshot_endpoints.R-146-#* is 400, naming the failing layer.
api/endpoints/admin_analysis_snapshot_endpoints.R-147-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-148-#* JSON body (all fields optional): `{ layers?: [...], title?,
api/endpoints/admin_analysis_snapshot_endpoints.R:149:#* scope_statement?, license?, publish? }`. `publish` defaults to `true`;
api/endpoints/admin_analysis_snapshot_endpoints.R-150-#* `false` stages a draft for review before a Zenodo run. `license` defaults
api/endpoints/admin_analysis_snapshot_endpoints.R-151-#* to `"CC-BY-4.0"`. Omitting `layers` uses the fixed default registry
api/endpoints/admin_analysis_snapshot_endpoints.R-152-#* (`analysis_snapshot_release_layers()`).
api/endpoints/admin_analysis_snapshot_endpoints.R-153-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-154-#* @tag admin
--
api/endpoints/admin_analysis_snapshot_endpoints.R-173-
api/endpoints/admin_analysis_snapshot_endpoints.R-174-  svc_release_build(
api/endpoints/admin_analysis_snapshot_endpoints.R-175-    res,
api/endpoints/admin_analysis_snapshot_endpoints.R-176-    layers = body$layers,
api/endpoints/admin_analysis_snapshot_endpoints.R-177-    title = body$title,
api/endpoints/admin_analysis_snapshot_endpoints.R:178:    scope_statement = body$scope_statement,
api/endpoints/admin_analysis_snapshot_endpoints.R-179-    license = body$license %||% "CC-BY-4.0",
api/endpoints/admin_analysis_snapshot_endpoints.R-180-    publish = publish_flag,
api/endpoints/admin_analysis_snapshot_endpoints.R-181-    created_by = req$user_id,
api/endpoints/admin_analysis_snapshot_endpoints.R-182-    conn = conn
api/endpoints/admin_analysis_snapshot_endpoints.R-183-  )
--
api/services/analysis-snapshot-release-service.R-59-#'
api/services/analysis-snapshot-release-service.R-60-#' @param res Plumber response, mutated in place (`$status`).
api/services/analysis-snapshot-release-service.R-61-#' @param layers Optional layer registry override; when `NULL` the
api/services/analysis-snapshot-release-service.R-62-#'   orchestrator's own default (`analysis_snapshot_release_layers()`) is
api/services/analysis-snapshot-release-service.R-63-#'   used — `layers` is only forwarded when the caller supplies one.
api/services/analysis-snapshot-release-service.R:64:#' @param title,scope_statement,license Presentation metadata.
api/services/analysis-snapshot-release-service.R-65-#' @param publish Whether to flip the inserted draft to `published`.
api/services/analysis-snapshot-release-service.R-66-#' @param created_by Optional user id recorded on the head row.
api/services/analysis-snapshot-release-service.R-67-#' @param conn A real DBIConnection (the orchestrator persists via A3).
api/services/analysis-snapshot-release-service.R-68-#' @return The release head (a named list).
api/services/analysis-snapshot-release-service.R-69-#' @export
api/services/analysis-snapshot-release-service.R-70-svc_release_build <- function(res,
api/services/analysis-snapshot-release-service.R-71-                               layers = NULL,
api/services/analysis-snapshot-release-service.R-72-                               title = NULL,
api/services/analysis-snapshot-release-service.R:73:                               scope_statement = NULL,
api/services/analysis-snapshot-release-service.R-74-                               license = "CC-BY-4.0",
api/services/analysis-snapshot-release-service.R-75-                               publish = TRUE,
api/services/analysis-snapshot-release-service.R-76-                               created_by = NULL,
api/services/analysis-snapshot-release-service.R-77-                               conn = NULL) {
api/services/analysis-snapshot-release-service.R-78-  build_args <- list(
api/services/analysis-snapshot-release-service.R-79-    title = title,
api/services/analysis-snapshot-release-service.R:80:    scope_statement = scope_statement,
api/services/analysis-snapshot-release-service.R-81-    license = license,
api/services/analysis-snapshot-release-service.R-82-    publish = publish,
api/services/analysis-snapshot-release-service.R-83-    created_by = created_by,
api/services/analysis-snapshot-release-service.R-84-    conn = conn
api/services/analysis-snapshot-release-service.R-85-  )
--
api/services/analysis-snapshot-release-service.R-186-#' List published releases (newest first).
api/services/analysis-snapshot-release-service.R-187-#'
api/services/analysis-snapshot-release-service.R-188-#' `limit` is clamped to `[1, 100]` and `offset` to `>= 0` (L1: public
api/services/analysis-snapshot-release-service.R-189-#' pagination must never be unbounded or negative — this is the single source of
api/services/analysis-snapshot-release-service.R-190-#' the clamp). Each returned head is projected to the PUBLIC allowlist
api/services/analysis-snapshot-release-service.R:191:#' (`analysis_release_public_head`) so operational columns never leak.
api/services/analysis-snapshot-release-service.R-192-#'
api/services/analysis-snapshot-release-service.R-193-#' @param limit,offset Pagination (clamped).
api/services/analysis-snapshot-release-service.R-194-#' @param conn A real DBIConnection.
api/services/analysis-snapshot-release-service.R-195-#' @return A list of public-projected release-head-plus-layers entries; never
api/services/analysis-snapshot-release-service.R-196-#'   includes drafts.
api/services/analysis-snapshot-release-service.R-197-#' @export
api/services/analysis-snapshot-release-service.R-198-svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
api/services/analysis-snapshot-release-service.R-199-  limit <- svc_release_clamp_limit(limit)
api/services/analysis-snapshot-release-service.R-200-  offset <- svc_release_clamp_offset(offset)
api/services/analysis-snapshot-release-service.R-201-  rows <- analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
api/services/analysis-snapshot-release-service.R:202:  lapply(rows, analysis_release_public_head)
api/services/analysis-snapshot-release-service.R-203-}
api/services/analysis-snapshot-release-service.R-204-
api/services/analysis-snapshot-release-service.R-205-#' Clamp a public list `limit` into `[1, 100]` (non-numeric -> default 50).
api/services/analysis-snapshot-release-service.R-206-#' @noRd
api/services/analysis-snapshot-release-service.R-207-svc_release_clamp_limit <- function(limit) {
--
api/services/analysis-snapshot-release-service.R-235-svc_release_get <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R-236-  head <- analysis_release_get(release_id, include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R-237-  if (is.null(head)) {
api/services/analysis-snapshot-release-service.R-238-    stop_for_not_found("Release not found")
api/services/analysis-snapshot-release-service.R-239-  }
api/services/analysis-snapshot-release-service.R:240:  analysis_release_public_head(head)
api/services/analysis-snapshot-release-service.R-241-}
api/services/analysis-snapshot-release-service.R-242-
api/services/analysis-snapshot-release-service.R-243-#' Fetch a published release's stored `manifest.json` file.
api/services/analysis-snapshot-release-service.R-244-#'
api/services/analysis-snapshot-release-service.R-245-#' @param release_id Release id.
--
api/functions/analysis-snapshot-release.R-1-# functions/analysis-snapshot-release.R
api/functions/analysis-snapshot-release.R-2-#
api/functions/analysis-snapshot-release.R-3-# Build orchestrator for immutable, content-addressed public analysis-snapshot
api/functions/analysis-snapshot-release.R-4-# RELEASES (#573 Slice A / Task A4). This is the correctness-critical layer: it
api/functions/analysis-snapshot-release.R:5:# LOADS the active public snapshots, GATES them (available + hard coherence +
api/functions/analysis-snapshot-release.R-6-# reproducibility presence + shared source-data version + dependency lineage +
api/functions/analysis-snapshot-release.R-7-# TOCTOU), MATERIALIZES the release files, computes the content-addressed
api/functions/analysis-snapshot-release.R-8-# identity, and PERSISTS via the A3 repository.
api/functions/analysis-snapshot-release.R-9-#
api/functions/analysis-snapshot-release.R-10-# Reuses (sourced by callers before this file / registered in load_modules):
--
api/functions/analysis-snapshot-release.R-171-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release.R-172-
api/functions/analysis-snapshot-release.R-173-#' Build (and optionally publish) an immutable analysis-snapshot release.
api/functions/analysis-snapshot-release.R-174-#'
api/functions/analysis-snapshot-release.R-175-#' @param layers Layer registry (default `analysis_snapshot_release_layers()`).
api/functions/analysis-snapshot-release.R:176:#' @param title,scope_statement,license Presentation metadata (excluded from the
api/functions/analysis-snapshot-release.R-177-#'   content digest / release identity).
api/functions/analysis-snapshot-release.R-178-#' @param publish If TRUE the inserted draft is flipped to `published`.
api/functions/analysis-snapshot-release.R-179-#' @param created_by Optional user id recorded on the head row.
api/functions/analysis-snapshot-release.R-180-#' @param conn A real DBIConnection (required for persistence; A5 checks one out).
api/functions/analysis-snapshot-release.R-181-#' @param layers Optional SELECTION of layers to include (NULL = full registry);
--
api/functions/analysis-snapshot-release.R-187-#'   persists the head/members/files.
api/functions/analysis-snapshot-release.R-188-#' @return `list(release = <head>, created = TRUE|FALSE)`.
api/functions/analysis-snapshot-release.R-189-#' @export
api/functions/analysis-snapshot-release.R-190-analysis_snapshot_release_build <- function(layers = NULL,
api/functions/analysis-snapshot-release.R-191-                                            title = NULL,
api/functions/analysis-snapshot-release.R:192:                                            scope_statement = NULL,
api/functions/analysis-snapshot-release.R-193-                                            license = "CC-BY-4.0",
api/functions/analysis-snapshot-release.R-194-                                            publish = TRUE,
api/functions/analysis-snapshot-release.R-195-                                            created_by = NULL,
api/functions/analysis-snapshot-release.R-196-                                            conn = NULL,
api/functions/analysis-snapshot-release.R-197-                                            loader = analysis_snapshot_get_public,
--
api/functions/analysis-snapshot-release.R-233-    )
api/functions/analysis-snapshot-release.R-234-  }
api/functions/analysis-snapshot-release.R-235-  if (!isTRUE(lock_state$ok)) {
api/functions/analysis-snapshot-release.R-236-    stop(.analysis_release_condition(
api/functions/analysis-snapshot-release.R-237-      "release_lock_unavailable",
api/functions/analysis-snapshot-release.R:238:      "source analysis snapshots are being refreshed; retry the release build shortly"
api/functions/analysis-snapshot-release.R-239-    ))
api/functions/analysis-snapshot-release.R-240-  }
api/functions/analysis-snapshot-release.R-241-
api/functions/analysis-snapshot-release.R-242-  # --- Step 1/1b/1c: load + gate each layer --------------------------------
api/functions/analysis-snapshot-release.R-243-  loaded <- list()
--
api/functions/analysis-snapshot-release.R-314-  ))[[1]]
api/functions/analysis-snapshot-release.R-315-
api/functions/analysis-snapshot-release.R-316-  # M1/M2: DB release provenance — carried on each pinned snapshot manifest.
api/functions/analysis-snapshot-release.R-317-  # strict = TRUE: distinct non-empty values that DISAGREE across layers reject
api/functions/analysis-snapshot-release.R-318-  # the build (release_source_version_mismatch -> 400), like source_data_version.
api/functions/analysis-snapshot-release.R:319:  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version", strict = TRUE)
api/functions/analysis-snapshot-release.R:320:  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit", strict = TRUE)
api/functions/analysis-snapshot-release.R-321-
api/functions/analysis-snapshot-release.R-322-  # For the correlation layer, pin the actual dependency lineage into its entry.
api/functions/analysis-snapshot-release.R-323-  corr <- loaded[["phenotype_functional_correlations"]]
api/functions/analysis-snapshot-release.R-324-  if (!is.null(corr)) {
api/functions/analysis-snapshot-release.R-325-    loaded[["phenotype_functional_correlations"]]$dependencies <-
--
api/functions/analysis-snapshot-release.R-391-    ), call. = FALSE)
api/functions/analysis-snapshot-release.R-392-  }
api/functions/analysis-snapshot-release.R-393-
api/functions/analysis-snapshot-release.R-394-  # README carries the resolved release_id now that it is known.
api/functions/analysis-snapshot-release.R-395-  readme_bytes <- .analysis_release_readme_bytes(
api/functions/analysis-snapshot-release.R:396:    release_id, title, scope_statement, license, shared_source_version, layer_entries
api/functions/analysis-snapshot-release.R-397-  )
api/functions/analysis-snapshot-release.R-398-  artifacts <- c(
api/functions/analysis-snapshot-release.R-399-    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
api/functions/analysis-snapshot-release.R-400-    artifacts
api/functions/analysis-snapshot-release.R-401-  )
api/functions/analysis-snapshot-release.R-402-
api/functions/analysis-snapshot-release.R-403-  created_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
api/functions/analysis-snapshot-release.R-404-
api/functions/analysis-snapshot-release.R-405-  # --- Step 7: manifest.json (files[] excludes manifest + checksums) -------
api/functions/analysis-snapshot-release.R-406-  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
api/functions/analysis-snapshot-release.R:407:  manifest_obj <- analysis_release_build_manifest(list(
api/functions/analysis-snapshot-release.R-408-    release_id = release_id,
api/functions/analysis-snapshot-release.R-409-    release_version = NULL,
api/functions/analysis-snapshot-release.R-410-    title = title,
api/functions/analysis-snapshot-release.R-411-    created_at = created_at,
api/functions/analysis-snapshot-release.R-412-    license = license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release.R:413:    scope_statement = scope_statement,
api/functions/analysis-snapshot-release.R:414:    generator = list(
api/functions/analysis-snapshot-release.R-415-      name = "sysndd-analysis-snapshot-release-build",
api/functions/analysis-snapshot-release.R-416-      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
api/functions/analysis-snapshot-release.R-417-      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
api/functions/analysis-snapshot-release.R-418-        ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION
api/functions/analysis-snapshot-release.R-419-      } else {
api/functions/analysis-snapshot-release.R-420-        NULL
api/functions/analysis-snapshot-release.R-421-      }
api/functions/analysis-snapshot-release.R-422-    ),
api/functions/analysis-snapshot-release.R-423-    source = list(
api/functions/analysis-snapshot-release.R-424-      source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R:425:      db_release = list(
api/functions/analysis-snapshot-release.R:426:        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R:427:        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
api/functions/analysis-snapshot-release.R-428-      ),
api/functions/analysis-snapshot-release.R:429:      snapshots = lapply(layer_entries, function(e) {
api/functions/analysis-snapshot-release.R-430-        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
api/functions/analysis-snapshot-release.R-431-      })
api/functions/analysis-snapshot-release.R-432-    ),
api/functions/analysis-snapshot-release.R-433-    layers = layer_entries,
api/functions/analysis-snapshot-release.R-434-    files = content_files,
--
api/functions/analysis-snapshot-release.R-470-    content_digest = content_digest,
api/functions/analysis-snapshot-release.R-471-    manifest_sha256 = manifest_sha256,
api/functions/analysis-snapshot-release.R-472-    bundle_sha256 = bundle_sha256,
api/functions/analysis-snapshot-release.R-473-    bundle_gzip = bundle_gzip,
api/functions/analysis-snapshot-release.R-474-    source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R:475:    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R:476:    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
api/functions/analysis-snapshot-release.R:477:    scope_statement = scope_statement,
api/functions/analysis-snapshot-release.R-478-    license = license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release.R-479-    created_by_user_id = created_by
api/functions/analysis-snapshot-release.R-480-  )
api/functions/analysis-snapshot-release.R-481-
api/functions/analysis-snapshot-release.R-482-  members <- lapply(layer_entries, function(e) {
--
api/endpoints/analysis_endpoints.R-375-
api/endpoints/analysis_endpoints.R-376-## -------------------------------------------------------------------##
api/endpoints/analysis_endpoints.R-377-## Analysis-snapshot RELEASES: public read routes (#573 Slice A / Task A6)
api/endpoints/analysis_endpoints.R-378-## -------------------------------------------------------------------##
api/endpoints/analysis_endpoints.R-379-#
api/endpoints/analysis_endpoints.R:380:# Immutable, content-addressed public releases of the analysis snapshots
api/endpoints/analysis_endpoints.R-381-# above (see services/analysis-snapshot-release-service.R for the full
api/endpoints/analysis_endpoints.R-382-# contract). DB-only, published-only: every svc_release_* read is pinned to
api/endpoints/analysis_endpoints.R-383-# status = "published", so an unknown release id and a draft release id are
api/endpoints/analysis_endpoints.R-384-# indistinguishable to the caller -- both resolve to a plain 404. `conn =
api/endpoints/analysis_endpoints.R-385-# pool` mirrors the established global-pool endpoint pattern (see
--
api/functions/analysis-snapshot-release-manifest.R-189-#' `list(path, sha256, bytes)` entry per archive member). Neither
api/functions/analysis-snapshot-release-manifest.R-190-#' `manifest.json` nor `checksums.sha256` can describe their own checksum, so
api/functions/analysis-snapshot-release-manifest.R-191-#' both are excluded from the `files[]` array in the built manifest.
api/functions/analysis-snapshot-release-manifest.R-192-#'
api/functions/analysis-snapshot-release-manifest.R-193-#' @param fields list with elements `release_id`, `release_version`, `title`,
api/functions/analysis-snapshot-release-manifest.R:194:#'   `created_at`, `license`, `scope_statement`, `generator`, `source`,
api/functions/analysis-snapshot-release-manifest.R-195-#'   `layers`, `files`, `content_digest`.
api/functions/analysis-snapshot-release-manifest.R-196-#' @return list, the manifest ready for `analysis_snapshot_canonical_json()`.
api/functions/analysis-snapshot-release-manifest.R:197:analysis_release_build_manifest <- function(fields) {
api/functions/analysis-snapshot-release-manifest.R-198-  self_describing_paths <- c("manifest.json", "checksums.sha256")
api/functions/analysis-snapshot-release-manifest.R-199-  files <- Filter(function(f) !(f$path %in% self_describing_paths), fields$files)
api/functions/analysis-snapshot-release-manifest.R-200-
api/functions/analysis-snapshot-release-manifest.R-201-  list(
api/functions/analysis-snapshot-release-manifest.R-202-    release_id = fields$release_id,
api/functions/analysis-snapshot-release-manifest.R-203-    release_version = fields$release_version,
api/functions/analysis-snapshot-release-manifest.R-204-    title = fields$title,
api/functions/analysis-snapshot-release-manifest.R-205-    created_at = fields$created_at,
api/functions/analysis-snapshot-release-manifest.R-206-    license = fields$license,
api/functions/analysis-snapshot-release-manifest.R:207:    scope_statement = fields$scope_statement,
api/functions/analysis-snapshot-release-manifest.R:208:    generator = fields$generator,
api/functions/analysis-snapshot-release-manifest.R-209-    source = fields$source,
api/functions/analysis-snapshot-release-manifest.R-210-    layers = fields$layers,
api/functions/analysis-snapshot-release-manifest.R-211-    files = files,
api/functions/analysis-snapshot-release-manifest.R-212-    content_digest = fields$content_digest
api/functions/analysis-snapshot-release-manifest.R-213-  )
--
api/functions/analysis-snapshot-release-materialize.R-198-  per_cluster <- tibble::tibble(cluster_id = valid_ids)
api/functions/analysis-snapshot-release-materialize.R-199-
api/functions/analysis-snapshot-release-materialize.R-200-  validation <- .analysis_release_parse_validation_json(snapshot$manifest)
api/functions/analysis-snapshot-release-materialize.R-201-
api/functions/analysis-snapshot-release-materialize.R-202-  # Channel match (functional axis only): both channels live in validation_json;
api/functions/analysis-snapshot-release-materialize.R:203:  # when both are present they must agree. Absent/older snapshots skip this
api/functions/analysis-snapshot-release-materialize.R-204-  # comparison (assert_partition_coherent only fires channel_mismatch when BOTH
api/functions/analysis-snapshot-release-materialize.R-205-  # membership_channel and validation_channel are non-NULL).
api/functions/analysis-snapshot-release-materialize.R-206-  membership_channel <- NULL
api/functions/analysis-snapshot-release-materialize.R-207-  validation_channel <- NULL
api/functions/analysis-snapshot-release-materialize.R-208-  if (identical(kind, "functional")) {
--
api/functions/analysis-snapshot-release-materialize.R-326-    if (!ok) {
api/functions/analysis-snapshot-release-materialize.R-327-      stop(.analysis_release_condition(
api/functions/analysis-snapshot-release-materialize.R-328-        "release_dependency_lineage_mismatch",
api/functions/analysis-snapshot-release-materialize.R-329-        paste(
api/functions/analysis-snapshot-release-materialize.R-330-          "correlation snapshot dependency lineage does not match the pinned",
api/functions/analysis-snapshot-release-materialize.R:331:          "functional/phenotype cluster snapshots (a cluster axis was refreshed",
api/functions/analysis-snapshot-release-materialize.R-332-          "after the correlation was computed)"
api/functions/analysis-snapshot-release-materialize.R-333-        )
api/functions/analysis-snapshot-release-materialize.R-334-      ))
api/functions/analysis-snapshot-release-materialize.R-335-    }
api/functions/analysis-snapshot-release-materialize.R-336-  }
--
api/functions/analysis-snapshot-release-materialize.R-374-  )
api/functions/analysis-snapshot-release-materialize.R-375-}
api/functions/analysis-snapshot-release-materialize.R-376-
api/functions/analysis-snapshot-release-materialize.R-377-#' README.md content bytes (scope + independent-verification recipe).
api/functions/analysis-snapshot-release-materialize.R-378-#' @noRd
api/functions/analysis-snapshot-release-materialize.R:379:.analysis_release_readme_bytes <- function(release_id, title, scope_statement, license,
api/functions/analysis-snapshot-release-materialize.R-380-                                           source_data_version, layer_entries) {
api/functions/analysis-snapshot-release-materialize.R-381-  layer_lines <- vapply(
api/functions/analysis-snapshot-release-materialize.R-382-    layer_entries,
api/functions/analysis-snapshot-release-materialize.R-383-    function(e) {
api/functions/analysis-snapshot-release-materialize.R-384-      sprintf(
--
api/functions/analysis-snapshot-release-materialize.R-395-    sprintf("License: %s", license %||% "CC-BY-4.0"),
api/functions/analysis-snapshot-release-materialize.R-396-    sprintf("Source data version: %s", source_data_version %||% "unknown"),
api/functions/analysis-snapshot-release-materialize.R-397-    "",
api/functions/analysis-snapshot-release-materialize.R-398-    "## Scope",
api/functions/analysis-snapshot-release-materialize.R-399-    "",
api/functions/analysis-snapshot-release-materialize.R:400:    scope_statement %||% paste(
api/functions/analysis-snapshot-release-materialize.R-401-      "Immutable, content-addressed public export of the curated derived",
api/functions/analysis-snapshot-release-materialize.R:402:      "cluster-analysis snapshots served by the SysNDD analysis API."
api/functions/analysis-snapshot-release-materialize.R-403-    ),
api/functions/analysis-snapshot-release-materialize.R-404-    "",
api/functions/analysis-snapshot-release-materialize.R-405-    "## Layers",
api/functions/analysis-snapshot-release-materialize.R-406-    "",
api/functions/analysis-snapshot-release-materialize.R-407-    layer_lines,
--
api/functions/analysis-snapshot-release-repository.R-60-#' for via `analysis_release_get_bundle()`).
api/functions/analysis-snapshot-release-repository.R-61-#' @noRd
api/functions/analysis-snapshot-release-repository.R-62-.analysis_release_head_columns <- paste(
api/functions/analysis-snapshot-release-repository.R-63-  "release_id, release_version, title, status, manifest_schema_version,",
api/functions/analysis-snapshot-release-repository.R-64-  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
api/functions/analysis-snapshot-release-repository.R:65:  "source_data_version, db_release_version, db_release_commit, scope_statement,",
api/functions/analysis-snapshot-release-repository.R-66-  "license, file_count, total_bytes, created_by_user_id, created_at,",
api/functions/analysis-snapshot-release-repository.R-67-  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
api/functions/analysis-snapshot-release-repository.R-68-  "version_doi, concept_doi, last_error_message"
api/functions/analysis-snapshot-release-repository.R-69-)
api/functions/analysis-snapshot-release-repository.R-70-
--
api/functions/analysis-snapshot-release-repository.R-82-#' Insert a release head + its members + its files in ONE transaction.
api/functions/analysis-snapshot-release-repository.R-83-#'
api/functions/analysis-snapshot-release-repository.R-84-#' `release_head` is a named list with (at least) `release_id`,
api/functions/analysis-snapshot-release-repository.R-85-#' `manifest_schema_version`, `content_digest`, `manifest_sha256`,
api/functions/analysis-snapshot-release-repository.R-86-#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
api/functions/analysis-snapshot-release-repository.R:87:#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
api/functions/analysis-snapshot-release-repository.R:88:#' `scope_statement`, `license` (defaults `"CC-BY-4.0"`),
api/functions/analysis-snapshot-release-repository.R-89-#' `created_by_user_id`. Always inserted with `status = 'draft'` —
api/functions/analysis-snapshot-release-repository.R-90-#' `analysis_release_publish()` is the only way to flip it.
api/functions/analysis-snapshot-release-repository.R-91-#'
api/functions/analysis-snapshot-release-repository.R-92-#' `bundle_bytes`, `file_count`, `total_bytes` are derived here (not trusted
api/functions/analysis-snapshot-release-repository.R-93-#' from the caller) from `bundle_gzip`/`files` directly, so they can never
--
api/functions/analysis-snapshot-release-repository.R-120-    DBI::dbExecute(
api/functions/analysis-snapshot-release-repository.R-121-      conn,
api/functions/analysis-snapshot-release-repository.R-122-      "INSERT INTO analysis_snapshot_release (
api/functions/analysis-snapshot-release-repository.R-123-         release_id, release_version, title, status, manifest_schema_version,
api/functions/analysis-snapshot-release-repository.R-124-         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
api/functions/analysis-snapshot-release-repository.R:125:         source_data_version, db_release_version, db_release_commit, scope_statement,
api/functions/analysis-snapshot-release-repository.R-126-         license, file_count, total_bytes, created_by_user_id
api/functions/analysis-snapshot-release-repository.R-127-       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
api/functions/analysis-snapshot-release-repository.R-128-      params = unname(list(
api/functions/analysis-snapshot-release-repository.R-129-        release_id,
api/functions/analysis-snapshot-release-repository.R-130-        .analysis_release_chr(release_head$release_version),
--
api/functions/analysis-snapshot-release-repository.R-134-        .analysis_release_chr(release_head$manifest_sha256),
api/functions/analysis-snapshot-release-repository.R-135-        .analysis_release_chr(release_head$bundle_sha256),
api/functions/analysis-snapshot-release-repository.R-136-        list(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-137-        length(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-138-        .analysis_release_chr(release_head$source_data_version),
api/functions/analysis-snapshot-release-repository.R:139:        .analysis_release_chr(release_head$db_release_version),
api/functions/analysis-snapshot-release-repository.R:140:        .analysis_release_chr(release_head$db_release_commit),
api/functions/analysis-snapshot-release-repository.R:141:        .analysis_release_chr(release_head$scope_statement),
api/functions/analysis-snapshot-release-repository.R-142-        release_head$license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release-repository.R-143-        as.integer(file_count),
api/functions/analysis-snapshot-release-repository.R-144-        as.numeric(total_bytes),
api/functions/analysis-snapshot-release-repository.R-145-        if (is.null(release_head$created_by_user_id)) NA_integer_ else as.integer(release_head$created_by_user_id)
api/functions/analysis-snapshot-release-repository.R-146-      ))
--
api/functions/analysis-snapshot-release-repository.R-202-#' are carried through when present. The ADMIN surface keeps the raw head.
api/functions/analysis-snapshot-release-repository.R-203-#'
api/functions/analysis-snapshot-release-repository.R-204-#' @param head A named list (a raw head from the repository read functions), or NULL.
api/functions/analysis-snapshot-release-repository.R-205-#' @return The projected named list, or NULL when `head` is NULL.
api/functions/analysis-snapshot-release-repository.R-206-#' @export
api/functions/analysis-snapshot-release-repository.R:207:analysis_release_public_head <- function(head) {
api/functions/analysis-snapshot-release-repository.R-208-  if (is.null(head)) {
api/functions/analysis-snapshot-release-repository.R-209-    return(NULL)
api/functions/analysis-snapshot-release-repository.R-210-  }
api/functions/analysis-snapshot-release-repository.R-211-  nullify <- function(x) if (is.null(x) || (length(x) == 1L && is.na(x))) NULL else x
api/functions/analysis-snapshot-release-repository.R-212-
api/functions/analysis-snapshot-release-repository.R-213-  allowlist <- c(
api/functions/analysis-snapshot-release-repository.R-214-    "release_id", "release_version", "title", "status", "content_digest",
api/functions/analysis-snapshot-release-repository.R-215-    "created_at", "published_at", "source_data_version",
api/functions/analysis-snapshot-release-repository.R:216:    "db_release_version", "db_release_commit", "manifest_sha256",
api/functions/analysis-snapshot-release-repository.R-217-    "bundle_sha256", "license", "file_count", "total_bytes"
api/functions/analysis-snapshot-release-repository.R-218-  )
api/functions/analysis-snapshot-release-repository.R-219-  projected <- head[intersect(allowlist, names(head))]
api/functions/analysis-snapshot-release-repository.R-220-  projected$zenodo <- list(
api/functions/analysis-snapshot-release-repository.R-221-    record_url = nullify(head$zenodo_record_url),
     1	import { mount, flushPromises } from '@vue/test-utils';
     2	import { describe, expect, it, vi, beforeEach } from 'vitest';
     3	import type { ReleaseDetail, ReleaseHead } from '@/api/analysis_releases';
     4
     5	vi.mock('@unhead/vue', () => ({
     6	  useHead: vi.fn(),
     7	}));
     8
     9	vi.mock('@/composables/useToast', () => ({
    10	  default: () => ({ makeToast: vi.fn() }),
    11	}));
    12
    13	const listReleasesMock = vi.fn();
    14	const getLatestReleaseMock = vi.fn();
    15	const getReleaseMock = vi.fn();
    16	const downloadReleaseBundleMock = vi.fn();
    17	const downloadReleaseManifestMock = vi.fn();
    18	const downloadReleaseFileMock = vi.fn();
    19
    20	vi.mock('@/api/analysis', () => ({
    21	  listReleases: (...args: unknown[]) => listReleasesMock(...args),
    22	  getLatestRelease: (...args: unknown[]) => getLatestReleaseMock(...args),
    23	  getRelease: (...args: unknown[]) => getReleaseMock(...args),
    24	  downloadReleaseBundle: (...args: unknown[]) => downloadReleaseBundleMock(...args),
    25	  downloadReleaseManifest: (...args: unknown[]) => downloadReleaseManifestMock(...args),
    26	  downloadReleaseFile: (...args: unknown[]) => downloadReleaseFileMock(...args),
    27	}));
    28
    29	import DataReleases from './DataReleases.vue';
    30
    31	function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
    32	  return {
    33	    release_id: 'asr_0123456789abcdef',
    34	    release_version: null,
    35	    title: 'SysNDD analysis-snapshot release',
    36	    status: 'published',
    37	    content_digest: 'a'.repeat(64),
    38	    created_at: '2026-07-01T00:00:00Z',
    39	    published_at: '2026-07-01T00:05:00Z',
    40	    source_data_version: '2026-07-01',
    41	    db_release_version: '11.4.0',
    42	    db_release_commit: 'deadbeef',
    43	    manifest_sha256: 'b'.repeat(64),
    44	    bundle_sha256: 'c'.repeat(64),
    45	    license: 'CC-BY-4.0',
    46	    file_count: 1,
    47	    total_bytes: 1258291,
    48	    zenodo: { record_url: null, version_doi: null, concept_doi: null },
    49	    ...overrides,
    50	  };
    51	}
    52
    53	function makeReleaseDetail(overrides: Partial<ReleaseHead> = {}): ReleaseDetail {
    54	  return {
    55	    ...makeReleaseHead(overrides),
    56	    manifest: {
    57	      release_id: overrides.release_id ?? 'asr_0123456789abcdef',
    58	      release_version: null,
    59	      title: 'SysNDD analysis-snapshot release',
    60	      created_at: '2026-07-01T00:00:00Z',
    61	      license: 'CC-BY-4.0',
    62	      scope_statement: 'Public derived analysis only.',
    63	      // `manifest.generator`/`manifest.source` are nested objects on the wire
    64	      // (api/functions/analysis-snapshot-release.R), not strings.
    65	      generator: {
    66	        name: 'sysndd-analysis-snapshot-release-build',
    67	        manifest_schema_version: '1.0',
    68	        reproducibility_schema_version: '1.2',
    69	      },
    70	      source: {
    71	        source_data_version: '2026-07-01',
    72	        db_release: { version: '11.4.0', commit: 'deadbeef' },
    73	        snapshots: [
    74	          { analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp-hash' },
    75	        ],
    76	      },
    77	      layers: [
    78	        {
    79	          analysis_type: 'functional_clusters',
    80	          parameter_hash: 'fp-hash',
    81	          snapshot_id: 101,
    82	          input_hash: 'in-func',
    83	          payload_hash: 'pay-func',
    84	          schema_version: '1.2',
    85	          reproducibility_hash: 'repro-func',
    86	          dependencies: null,
    87	        },
    88	      ],
    89	      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
    90	      content_digest: 'a'.repeat(64),
    91	    },
    92	  };
    93	}
    94
    95	function notFoundError() {
    96	  return Object.assign(new Error('Not found'), {
    97	    isAxiosError: true,
    98	    response: {
    99	      status: 404,
   100	      data: {
   101	        type: 'about:blank',
   102	        title: 'Not Found',
   103	        status: 404,
   104	        detail: 'No published analysis-snapshot release exists yet',
   105	      },
   106	    },
   107	  });
   108	}
   109
   110	describe('DataReleases', () => {
   111	  beforeEach(() => {
   112	    vi.clearAllMocks();
   113	    // jsdom has no real object-URL / anchor-download support.
   114	    window.URL.createObjectURL = vi.fn(() => 'blob:mock-url');
   115	    window.URL.revokeObjectURL = vi.fn();
   116	  });
   117
   118	  it('renders the release table row and the manifest panel for the latest release', async () => {
   119	    listReleasesMock.mockResolvedValue({
   120	      releases: [makeReleaseHead()],
   121	      pagination: { limit: 50, offset: 0, count: 1 },
   122	    });
   123	    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
   124
   125	    const wrapper = mount(DataReleases);
   126	    await flushPromises();
   127
   128	    expect(listReleasesMock).toHaveBeenCalled();
   129	    expect(getLatestReleaseMock).toHaveBeenCalled();
   130	    const text = wrapper.text();
   131	    expect(text).toContain('asr_0123456789abcdef');
   132	    expect(text).toContain('Integrity hashes');
   133	    expect(text).toContain('a'.repeat(64));
   134	  });
   135
   136	  it('re-fetches the detail for a different release when its "View manifest" button is clicked', async () => {
   137	    listReleasesMock.mockResolvedValue({
   138	      releases: [makeReleaseHead({ release_id: 'asr_other' })],
   139	      pagination: { limit: 50, offset: 0, count: 1 },
   140	    });
   141	    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
   142	    getReleaseMock.mockResolvedValue(makeReleaseDetail({ release_id: 'asr_other' }));
   143
   144	    const wrapper = mount(DataReleases);
   145	    await flushPromises();
   146
   147	    const button = wrapper
   148	      .findAll('button')
   149	      .find((btn) => btn.text().includes('View manifest'));
   150	    expect(button).toBeTruthy();
   151	    await button!.trigger('click');
   152	    await flushPromises();
   153
   154	    expect(getReleaseMock).toHaveBeenCalledWith('asr_other');
   155	  });
   156
   157	  // MEDIUM (#573 Slice B Codex round-1 review): a slow mount-time
   158	  // `getLatestRelease()` must not clobber a later, already-resolved
   159	  // `getRelease(id)` selection when it finally settles. Regression-guards the
   160	  // monotonic request token in `loadDetail()`.
   161	  it('discards a stale getLatestRelease response that resolves after a later "View manifest" selection', async () => {
   162	    listReleasesMock.mockResolvedValue({
   163	      releases: [makeReleaseHead({ release_id: 'asr_other' })],
   164	      pagination: { limit: 50, offset: 0, count: 1 },
   165	    });
   166
   167	    let resolveLatest: (value: ReleaseDetail) => void = () => {};
   168	    getLatestReleaseMock.mockReturnValue(
   169	      new Promise<ReleaseDetail>((resolve) => {
   170	        resolveLatest = resolve;
   171	      })
   172	    );
   173	    getReleaseMock.mockResolvedValue(makeReleaseDetail({ release_id: 'asr_other' }));
   174
   175	    const wrapper = mount(DataReleases);
   176	    // The list resolves; the mount-time getLatestRelease() request is still pending.
   177	    await flushPromises();
   178
   179	    const button = wrapper
   180	      .findAll('button')
   181	      .find((btn) => btn.text().includes('View manifest'));
   182	    expect(button).toBeTruthy();
   183	    await button!.trigger('click');
   184	    await flushPromises();
   185
   186	    // The later request (getRelease) resolved first and is now shown.
   187	    expect(wrapper.text()).toContain('asr_other');
   188
   189	    // The stale, earlier-started getLatestRelease request finally settles with
   190	    // a DIFFERENT release. It must be discarded, not overwrite the selection.
   191	    resolveLatest(makeReleaseDetail({ release_id: 'asr_0123456789abcdef' }));
   192	    await flushPromises();
   193
   194	    expect(wrapper.text()).toContain('asr_other');
   195	    expect(wrapper.text()).not.toContain('asr_0123456789abcdef');
   196	  });
   197
   198	  it('downloads the bundle when the download-bundle button is clicked', async () => {
   199	    listReleasesMock.mockResolvedValue({
   200	      releases: [makeReleaseHead()],
   201	      pagination: { limit: 50, offset: 0, count: 1 },
   202	    });
   203	    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
   204	    downloadReleaseBundleMock.mockResolvedValue(new Blob(['bundle-bytes']));
   205
   206	    const wrapper = mount(DataReleases);
   207	    await flushPromises();
   208
   209	    await wrapper.find('[data-testid="download-bundle-button"]').trigger('click');
   210	    await flushPromises();
   211
   212	    expect(downloadReleaseBundleMock).toHaveBeenCalledWith('asr_0123456789abcdef');
   213	  });
   214
   215	  it('shows the "No releases published yet" empty state on a 404 from getLatestRelease, not a raw error', async () => {
   216	    listReleasesMock.mockResolvedValue({
   217	      releases: [],
   218	      pagination: { limit: 50, offset: 0, count: 0 },
   219	    });
   220	    getLatestReleaseMock.mockRejectedValue(notFoundError());
   221
   222	    const wrapper = mount(DataReleases);
   223	    await flushPromises();
   224
   225	    expect(wrapper.text()).toContain('No releases published yet');
   226	    expect(wrapper.find('[data-testid="section-card-error"]').exists()).toBe(false);
   227	  });
   228	});
     1	import { mount } from '@vue/test-utils';
     2	import { describe, expect, it, vi } from 'vitest';
     3	import ReleaseManifestPanel from './ReleaseManifestPanel.vue';
     4	import type { ReleaseDetail } from '@/api/analysis';
     5
     6	function makeReleaseDetail(): ReleaseDetail {
     7	  return {
     8	    release_id: 'asr_0123456789abcdef',
     9	    release_version: null,
    10	    title: 'SysNDD analysis-snapshot release',
    11	    status: 'published',
    12	    content_digest: 'a'.repeat(64),
    13	    created_at: '2026-07-01T00:00:00Z',
    14	    published_at: '2026-07-01T00:05:00Z',
    15	    source_data_version: '2026-07-01',
    16	    db_release_version: '11.4.0',
    17	    db_release_commit: 'deadbeef',
    18	    manifest_sha256: 'b'.repeat(64),
    19	    bundle_sha256: 'c'.repeat(64),
    20	    license: 'CC-BY-4.0',
    21	    file_count: 10,
    22	    total_bytes: 1258291,
    23	    zenodo: {
    24	      record_url: 'https://zenodo.org/records/1234',
    25	      version_doi: '10.5281/zenodo.1234',
    26	      concept_doi: '10.5281/zenodo.1233',
    27	    },
    28	    manifest: {
    29	      release_id: 'asr_0123456789abcdef',
    30	      release_version: null,
    31	      title: 'SysNDD analysis-snapshot release',
    32	      created_at: '2026-07-01T00:00:00Z',
    33	      license: 'CC-BY-4.0',
    34	      scope_statement: 'Public derived analysis only.',
    35	      generator: {
    36	        name: 'sysndd-analysis-snapshot-release-build',
    37	        manifest_schema_version: '1.0',
    38	        reproducibility_schema_version: '1.2',
    39	      },
    40	      source: {
    41	        source_data_version: '2026-07-01',
    42	        db_release: { version: '11.4.0', commit: 'deadbeef' },
    43	        snapshots: [
    44	          { analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp-hash' },
    45	          { analysis_type: 'phenotype_clusters', snapshot_id: 202, parameter_hash: 'pp-hash' },
    46	        ],
    47	      },
    48	      layers: [
    49	        {
    50	          analysis_type: 'functional_clusters',
    51	          parameter_hash: 'fp-hash',
    52	          snapshot_id: 101,
    53	          input_hash: 'in-func',
    54	          payload_hash: 'pay-func',
    55	          schema_version: '1.2',
    56	          reproducibility_hash: 'repro-func',
    57	          dependencies: null,
    58	        },
    59	        {
    60	          analysis_type: 'phenotype_clusters',
    61	          parameter_hash: 'pp-hash',
    62	          snapshot_id: 202,
    63	          input_hash: 'in-pheno',
    64	          payload_hash: 'pay-pheno',
    65	          schema_version: '1.2',
    66	          reproducibility_hash: 'repro-pheno',
    67	          dependencies: null,
    68	        },
    69	        {
    70	          analysis_type: 'phenotype_functional_correlations',
    71	          parameter_hash: 'cp-hash',
    72	          snapshot_id: 303,
    73	          input_hash: 'in-corr',
    74	          payload_hash: 'pay-corr',
    75	          schema_version: '1.2',
    76	          reproducibility_hash: null,
    77	          dependencies: {
    78	            functional_clusters: { snapshot_id: 101, payload_hash: 'pay-func' },
    79	            phenotype_clusters: { snapshot_id: 202, payload_hash: 'pay-pheno' },
    80	          },
    81	        },
    82	      ],
    83	      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
    84	      content_digest: 'a'.repeat(64),
    85	    },
    86	  };
    87	}
    88
    89	describe('ReleaseManifestPanel', () => {
    90	  it('renders all three integrity hashes', () => {
    91	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
    92	    const text = wrapper.text();
    93	    expect(text).toContain('a'.repeat(64)); // content_digest
    94	    expect(text).toContain('b'.repeat(64)); // manifest_sha256
    95	    expect(text).toContain('c'.repeat(64)); // bundle_sha256
    96	  });
    97
    98	  it('shows the correlation layer dependency lineage and its "n/a" reproducibility hash', () => {
    99	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   100	    const text = wrapper.text();
   101	    expect(text).toContain('n/a (not reproducible)');
   102	    expect(text).toContain('Dependency lineage');
   103	    expect(text).toContain('pay-func');
   104	    expect(text).toContain('pay-pheno');
   105	    expect(text).toContain('101');
   106	    expect(text).toContain('202');
   107	  });
   108
   109	  it('renders the version DOI as a doi.org link', () => {
   110	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   111	    const link = wrapper.find('a[href="https://doi.org/10.5281/zenodo.1234"]');
   112	    expect(link.exists()).toBe(true);
   113	    expect(link.text()).toBe('10.5281/zenodo.1234');
   114	  });
   115
   116	  it('shows "not yet assigned" when a DOI is null', () => {
   117	    const release = makeReleaseDetail();
   118	    release.zenodo = { record_url: null, version_doi: null, concept_doi: null };
   119	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   120	    expect(wrapper.text()).toContain('not yet assigned');
   121	  });
   122
   123	  // HIGH (#573 Slice B Codex round-1 review): the DOI PATCH endpoint stores
   124	  // `zenodo.record_url` with no backend URL validation, so an admin-authored
   125	  // `javascript:` string must never become a clickable `<a href>` for an
   126	  // unauthenticated /DataReleases visitor.
   127	  it('does not render a clickable link for a javascript:-scheme record_url (renders plain text instead)', () => {
   128	    const release = makeReleaseDetail();
   129	    release.zenodo = {
   130	      ...release.zenodo,
   131	      record_url: 'javascript:alert(document.cookie)',
   132	    };
   133	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   134
   135	    const maliciousAnchor = wrapper
   136	      .findAll('a')
   137	      .find((anchor) => (anchor.attributes('href') ?? '').startsWith('javascript:'));
   138	    expect(maliciousAnchor).toBeUndefined();
   139
   140	    // The value itself is not lost — it is still shown, just as inert text.
   141	    expect(wrapper.text()).toContain('javascript:alert(document.cookie)');
   142	  });
   143
   144	  it('does not render a clickable link for a data:-scheme record_url either', () => {
   145	    const release = makeReleaseDetail();
   146	    release.zenodo = {
   147	      ...release.zenodo,
   148	      record_url: 'data:text/html,<script>alert(1)</script>',
   149	    };
   150	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   151
   152	    const dataAnchor = wrapper
   153	      .findAll('a')
   154	      .find((anchor) => (anchor.attributes('href') ?? '').startsWith('data:'));
   155	    expect(dataAnchor).toBeUndefined();
   156	  });
   157
   158	  it('still renders a normal https record_url as a clickable link', () => {
   159	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   160	    const link = wrapper.find('a[href="https://zenodo.org/records/1234"]');
   161	    expect(link.exists()).toBe(true);
   162	    expect(link.text()).toBe('Record');
   163	  });
   164
   165	  it('omits the Version row when release_version is null (the current, always-null default)', () => {
   166	    const release = makeReleaseDetail();
   167	    expect(release.release_version).toBeNull();
   168	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   169	    const dts = wrapper.findAll('dt').map((dt) => dt.text());
   170	    expect(dts).not.toContain('Version');
   171	  });
   172
   173	  it('shows the Version row when release_version is populated', () => {
   174	    const release = makeReleaseDetail();
   175	    release.release_version = '1.0';
   176	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   177	    const dts = wrapper.findAll('dt').map((dt) => dt.text());
   178	    expect(dts).toContain('Version');
   179	    expect(wrapper.text()).toContain('1.0');
   180	  });
   181
   182	  it('falls back to release_id for the title when title is null', () => {
   183	    const release = makeReleaseDetail();
   184	    release.title = null;
   185	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   186	    expect(wrapper.find('#release-manifest-panel-title').text()).toBe('asr_0123456789abcdef');
   187	    const dts = wrapper.findAll('dt').map((dt) => dt.text());
   188	    const titleDd = wrapper.findAll('dt').find((dt) => dt.text() === 'Title')?.element.nextElementSibling;
   189	    expect(dts).toContain('Title');
   190	    expect(titleDd?.textContent).toBe('asr_0123456789abcdef');
   191	  });
   192
   193	  it('copies a hash to the clipboard when its copy button is clicked', async () => {
   194	    const writeText = vi.fn().mockResolvedValue(undefined);
   195	    Object.defineProperty(navigator, 'clipboard', {
   196	      configurable: true,
   197	      value: { writeText },
   198	    });
   199
   200	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   201	    const button = wrapper
   202	      .findAll('button')
   203	      .find((btn) => btn.attributes('aria-label') === 'Copy Content digest to clipboard');
   204	    expect(button).toBeTruthy();
   205
   206	    await button!.trigger('click');
   207	    await wrapper.vm.$nextTick();
   208
   209	    expect(writeText).toHaveBeenCalledWith('a'.repeat(64));
   210	    expect(button!.text()).toContain('Copied');
   211	  });
   212	});

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release.R | sed -n '400,520p'; nl -ba api/functions/analysis-snapshot-release-manifest.R | sed -n '1,260p'; nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '180,245p'; nl -ba api/endpoints/analysis_endpoints.R | sed -n '400,580p'; nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '135,360p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
   400	    artifacts
   401	  )
   402
   403	  created_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
   404
   405	  # --- Step 7: manifest.json (files[] excludes manifest + checksums) -------
   406	  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
   407	  manifest_obj <- analysis_release_build_manifest(list(
   408	    release_id = release_id,
   409	    release_version = NULL,
   410	    title = title,
   411	    created_at = created_at,
   412	    license = license %||% "CC-BY-4.0",
   413	    scope_statement = scope_statement,
   414	    generator = list(
   415	      name = "sysndd-analysis-snapshot-release-build",
   416	      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   417	      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
   418	        ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION
   419	      } else {
   420	        NULL
   421	      }
   422	    ),
   423	    source = list(
   424	      source_data_version = shared_source_version,
   425	      db_release = list(
   426	        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
   427	        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
   428	      ),
   429	      snapshots = lapply(layer_entries, function(e) {
   430	        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
   431	      })
   432	    ),
   433	    layers = layer_entries,
   434	    files = content_files,
   435	    content_digest = content_digest
   436	  ))
   437	  manifest_bytes <- analysis_release_canonical_bytes(manifest_obj)
   438	  manifest_artifact <- .analysis_release_artifact("manifest.json", manifest_bytes, "application/json")
   439	  manifest_sha256 <- manifest_artifact$sha256
   440	  artifacts[[length(artifacts) + 1L]] <- manifest_artifact
   441
   442	  # --- Step 8: checksums.sha256 (all files incl. manifest, excl. checksums)-
   443	  checksum_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256))
   444	  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
   445	  artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   446	    "checksums.sha256", checksums_bytes, "text/plain"
   447	  )
   448
   449	  # --- Step 9: bundle.tar.gz (all files) -----------------------------------
   450	  named_raw <- stats::setNames(
   451	    lapply(artifacts, function(a) a$bytes),
   452	    vapply(artifacts, function(a) a$path, character(1))
   453	  )
   454	  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
   455	  bundle_sha256 <- analysis_release_sha256(bundle_gzip)
   456
   457	  # --- Step 2 (re-assert immediately before insert) ------------------------
   458	  # A FRESH DB re-read via the loader seam (not the cached `loaded`) so a source
   459	  # snapshot that was refreshed between the first read and now is caught. Combined
   460	  # with the per-preset locks above, this closes the TOCTOU window.
   461	  .analysis_release_assert_lineage(loaded)
   462	  .analysis_release_verify_lineage_unchanged(layer_specs, loaded, loader, conn)
   463
   464	  # --- Step 10: persist ----------------------------------------------------
   465	  release_head <- list(
   466	    release_id = release_id,
   467	    release_version = NULL,
   468	    title = title,
   469	    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   470	    content_digest = content_digest,
   471	    manifest_sha256 = manifest_sha256,
   472	    bundle_sha256 = bundle_sha256,
   473	    bundle_gzip = bundle_gzip,
   474	    source_data_version = shared_source_version,
   475	    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
   476	    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
   477	    scope_statement = scope_statement,
   478	    license = license %||% "CC-BY-4.0",
   479	    created_by_user_id = created_by
   480	  )
   481
   482	  members <- lapply(layer_entries, function(e) {
   483	    list(
   484	      analysis_type = e$analysis_type,
   485	      parameter_hash = e$parameter_hash,
   486	      snapshot_id = e$snapshot_id,
   487	      input_hash = e$input_hash,
   488	      payload_hash = e$payload_hash,
   489	      schema_version = e$schema_version,
   490	      reproducibility_hash = e$reproducibility_hash,
   491	      role = "layer"
   492	    )
   493	  })
   494
   495	  insert_files <- lapply(artifacts, function(a) {
   496	    list(
   497	      file_path = a$path,
   498	      content_sha256 = a$sha256,
   499	      byte_size = a$byte_size,
   500	      media_type = a$media_type,
   501	      content_gzip = memCompress(a$bytes, type = "gzip")
   502	    )
   503	  })
   504
   505	  # H3(b): a concurrent identical build can win the insert race (both passed the
   506	  # step-6 idempotency probe). On a DB duplicate-key error, re-read by release_id:
   507	  # if the stored content_digest matches, this build is a no-op (idempotent 200);
   508	  # otherwise it is a genuine identity anomaly (re-raise -> 500).
   509	  insert_created <- tryCatch(
   510	    {
   511	      inserter(release_head, members, insert_files, conn)
   512	      TRUE
   513	    },
   514	    error = function(e) {
   515	      if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
   516	        existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   517	        if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
   518	          return(FALSE) # idempotent: the concurrent winner stored the identical release
   519	        }
   520	      }
     1	# Pure, DB-free helpers for immutable public analysis-snapshot RELEASES
     2	# (#573 Slice A / Task A2): the layer registry, content-address identity
     3	# (content_digest / release_id), the manifest.json / checksums.sha256
     4	# builders, and the deterministic tar.gz archive writer.
     5	#
     6	# These functions define release IDENTITY and file contracts consumed by
     7	# later tasks (repository persistence, build orchestrator). They must stay
     8	# pure: no DB access, no network, no side effects beyond a scratch tempdir
     9	# used internally by `analysis_release_build_tar_gz()`.
    10	#
    11	# Reuses the EXISTING canonical JSON serializer from
    12	# `analysis-snapshot-presets.R` (`analysis_snapshot_canonical_json()`, sourced
    13	# by callers before this file) so release file bytes hash identically to the
    14	# bytes the public snapshot API already serves. Do not reimplement it here.
    15
    16	ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION <- "1.0"
    17
    18	#' Default analysis layers bundled into a release.
    19	#'
    20	#' Registry-driven (a list, single source of truth): which analysis types are
    21	#' included, the locked snapshot params used to select their source snapshot,
    22	#' the archive path prefix for that layer's files, and whether a
    23	#' reproducibility bundle is expected for it.
    24	#'
    25	#' @return list of `list(analysis_type, params, files_prefix,
    26	#'   has_reproducibility)`.
    27	analysis_snapshot_release_layers <- function() {
    28	  list(
    29	    list(
    30	      analysis_type = "functional_clusters",
    31	      params = list(algorithm = "leiden"),
    32	      files_prefix = "functional_clusters",
    33	      has_reproducibility = TRUE
    34	    ),
    35	    list(
    36	      analysis_type = "phenotype_clusters",
    37	      params = list(),
    38	      files_prefix = "phenotype_clusters",
    39	      has_reproducibility = TRUE
    40	    ),
    41	    list(
    42	      analysis_type = "phenotype_functional_correlations",
    43	      params = list(algorithm = "leiden"),
    44	      files_prefix = "phenotype_functional_correlations",
    45	      has_reproducibility = FALSE
    46	    )
    47	  )
    48	}
    49
    50	#' Resolve a caller-supplied `layers` request to authoritative REGISTRY entries.
    51	#'
    52	#' `layers` in a build request is a SELECTION, never a policy redefinition: each
    53	#' requested entry is read ONLY for its `analysis_type` (accepting either a bare
    54	#' string or a `{analysis_type, ...}` object), matched against the authoritative
    55	#' `analysis_snapshot_release_layers()` registry, and the REGISTRY entry is
    56	#' returned — so the caller can never override `params`, `files_prefix`, or the
    57	#' gate-controlling `has_reproducibility` (which would let an Admin skip the hard
    58	#' coherence / reproducibility gates, or path-traverse via `files_prefix`).
    59	#'
    60	#' NULL/absent `requested` -> the full registry unchanged. An unknown or
    61	#' duplicated `analysis_type` -> 400 (`stop_for_bad_request`).
    62	#'
    63	#' @param requested NULL, or a list of selectors (strings or `{analysis_type}`).
    64	#' @return list of registry layer entries (a subset of the registry, in request
    65	#'   order).
    66	analysis_snapshot_release_resolve_layers <- function(requested = NULL) {
    67	  registry <- analysis_snapshot_release_layers()
    68	  if (is.null(requested) || length(requested) == 0L) {
    69	    return(registry)
    70	  }
    71
    72	  registry_types <- vapply(registry, function(layer) layer$analysis_type, character(1))
    73	  registry_by_type <- stats::setNames(registry, registry_types)
    74
    75	  seen <- character(0)
    76	  lapply(requested, function(entry) {
    77	    analysis_type <- if (is.list(entry)) entry$analysis_type else entry
    78	    analysis_type <- as.character(analysis_type %||% "")[[1]]
    79	    if (!nzchar(analysis_type)) {
    80	      stop_for_bad_request("release layer selector is missing analysis_type")
    81	    }
    82	    if (analysis_type %in% seen) {
    83	      stop_for_bad_request(sprintf("duplicate release layer: %s", analysis_type))
    84	    }
    85	    seen <<- c(seen, analysis_type)
    86	    match <- registry_by_type[[analysis_type]]
    87	    if (is.null(match)) {
    88	      stop_for_bad_request(sprintf("unknown release layer: %s", analysis_type))
    89	    }
    90	    match
    91	  })
    92	}
    93
    94	#' Reject an archive-relative file path that could escape the archive root.
    95	#'
    96	#' Defense-in-depth against path traversal: rejects any path that is empty,
    97	#' absolute (leading `/` or a Windows drive), contains a backslash separator, or
    98	#' contains a `..` segment. Called for every materialized file path AND every
    99	#' path written into the tar archive (`analysis_release_build_tar_gz`).
   100	#'
   101	#' @param path chr, an archive-relative file path.
   102	#' @return invisibly TRUE; throws on an unsafe path.
   103	.analysis_release_assert_safe_path <- function(path) {
   104	  p <- as.character(path)[[1]]
   105	  segments <- strsplit(p, "/", fixed = TRUE)[[1]]
   106	  if (!nzchar(p) ||
   107	    startsWith(p, "/") ||
   108	    grepl("^[A-Za-z]:[\\\\/]", p) ||
   109	    grepl("\\\\", p) ||
   110	    any(segments == "..")) {
   111	    stop(sprintf("unsafe release file path: %s", p), call. = FALSE)
   112	  }
   113	  invisible(TRUE)
   114	}
   115
   116	#' UTF-8 raw bytes of the canonical JSON serialization of `obj`.
   117	#'
   118	#' Uses the SAME serializer as the public snapshot API
   119	#' (`analysis_snapshot_canonical_json()`), so release file bytes hash
   120	#' identically to the corresponding public API response bytes.
   121	#'
   122	#' @param obj Any value accepted by `analysis_snapshot_canonical_json()`.
   123	#' @return raw vector.
   124	analysis_release_canonical_bytes <- function(obj) {
   125	  charToRaw(enc2utf8(analysis_snapshot_canonical_json(obj)))
   126	}
   127
   128	#' SHA-256 hex digest of raw bytes or a character string.
   129	#'
   130	#' Repo-wide convention: `digest::digest(x, algo = "sha256", serialize =
   131	#' FALSE)`. With `serialize = FALSE`, a raw vector is hashed as its bytes
   132	#' directly and a character string is hashed as its string content, so this
   133	#' accepts either without branching.
   134	#'
   135	#' @param raw_or_chr raw vector or a length-1 character string.
   136	#' @return chr, a 64-character lowercase hex sha256 digest.
   137	analysis_release_sha256 <- function(raw_or_chr) {
   138	  digest::digest(raw_or_chr, algo = "sha256", serialize = FALSE)
   139	}
   140
   141	#' Order-independent content digest: the identity basis for a release.
   142	#'
   143	#' Deliberately excludes `created_at`, `title`, and any DOI — release
   144	#' identity is pure scientific content (each layer's input/payload/
   145	#' reproducibility hashes and dependencies, plus the source data version and
   146	#' manifest schema version), never presentation metadata. `layer_entries` is
   147	#' sorted by `analysis_type` before hashing so caller-supplied ordering never
   148	#' changes the digest.
   149	#'
   150	#' @param layer_entries list of list(analysis_type, input_hash, payload_hash,
   151	#'   reproducibility_hash, dependencies).
   152	#' @param source_data_version chr.
   153	#' @param manifest_schema_version chr.
   154	#' @return chr, a 64-character lowercase hex sha256 digest.
   155	analysis_release_content_digest <- function(layer_entries, source_data_version, manifest_schema_version) {
   156	  analysis_types <- vapply(layer_entries, function(entry) entry$analysis_type, character(1))
   157	  # method = "radix" is locale-invariant: the content identity must not depend on
   158	  # the builder's LC_COLLATE (de-risks cross-host #574 reproducibility).
   159	  sorted_entries <- layer_entries[order(analysis_types, method = "radix")]
   160
   161	  identity_layers <- lapply(sorted_entries, function(entry) {
   162	    entry[c("analysis_type", "input_hash", "payload_hash", "reproducibility_hash", "dependencies")]
   163	  })
   164
   165	  identity_obj <- list(
   166	    manifest_schema_version = manifest_schema_version,
   167	    source_data_version = source_data_version,
   168	    layers = identity_layers
   169	  )
   170
   171	  analysis_release_sha256(analysis_release_canonical_bytes(identity_obj))
   172	}
   173
   174	#' Short, readable release handle derived from the content digest.
   175	#'
   176	#' The first 16 hex characters (64 bits) of the content digest, prefixed
   177	#' `asr_`. This is a human/URL-facing handle only; the full content digest is
   178	#' the authoritative identity value and is stored separately by later tasks.
   179	#'
   180	#' @param content_digest chr, as returned by `analysis_release_content_digest()`.
   181	#' @return chr, matching `^asr_[0-9a-f]{16}$` for a well-formed digest.
   182	analysis_release_id <- function(content_digest) {
   183	  paste0("asr_", substr(content_digest, 1, 16))
   184	}
   185
   186	#' Build the release `manifest.json` R list.
   187	#'
   188	#' `fields$files` is the caller-computed flat file list (one
   189	#' `list(path, sha256, bytes)` entry per archive member). Neither
   190	#' `manifest.json` nor `checksums.sha256` can describe their own checksum, so
   191	#' both are excluded from the `files[]` array in the built manifest.
   192	#'
   193	#' @param fields list with elements `release_id`, `release_version`, `title`,
   194	#'   `created_at`, `license`, `scope_statement`, `generator`, `source`,
   195	#'   `layers`, `files`, `content_digest`.
   196	#' @return list, the manifest ready for `analysis_snapshot_canonical_json()`.
   197	analysis_release_build_manifest <- function(fields) {
   198	  self_describing_paths <- c("manifest.json", "checksums.sha256")
   199	  files <- Filter(function(f) !(f$path %in% self_describing_paths), fields$files)
   200
   201	  list(
   202	    release_id = fields$release_id,
   203	    release_version = fields$release_version,
   204	    title = fields$title,
   205	    created_at = fields$created_at,
   206	    license = fields$license,
   207	    scope_statement = fields$scope_statement,
   208	    generator = fields$generator,
   209	    source = fields$source,
   210	    layers = fields$layers,
   211	    files = files,
   212	    content_digest = fields$content_digest
   213	  )
   214	}
   215
   216	#' Build the `checksums.sha256` file content.
   217	#'
   218	#' One `"<sha256>  <path>\n"` line per file (the classic `sha256sum` format),
   219	#' excluding `checksums.sha256` itself since a file cannot list its own
   220	#' checksum.
   221	#'
   222	#' @param files list of `list(path, sha256, bytes)`.
   223	#' @return chr, the full checksums file text (empty string if `files` yields
   224	#'   no lines after exclusion).
   225	analysis_release_checksums_text <- function(files) {
   226	  files <- Filter(function(f) f$path != "checksums.sha256", files)
   227	  if (length(files) == 0) {
   228	    return("")
   229	  }
   230	  lines <- vapply(files, function(f) paste0(f$sha256, "  ", f$path), character(1))
   231	  paste0(paste(lines, collapse = "\n"), "\n")
   232	}
   233
   234	#' Build a gzip-compressed tar archive from named raw vectors.
   235	#'
   236	#' `named_raw_list` is a named list of `path = raw_bytes`; each name becomes
   237	#' a (possibly nested, e.g. `"functional_clusters/reproducibility.json.gz"`)
   238	#' relative file path inside the archive. Built ONCE at release-build time
   239	#' and stored/served verbatim thereafter, so byte-level rebuild determinism
   240	#' is NOT required here — per-file `checksums.sha256` entries plus the
   241	#' manifest are the verification anchors for individual file contents. Paths
   242	#' are sorted purely for a stable, readable archive listing order.
   243	#'
   244	#' @param named_raw_list named list of raw vectors, keyed by archive-relative
   245	#'   path.
   246	#' @return raw vector, the gzip-compressed tar archive bytes.
   247	analysis_release_build_tar_gz <- function(named_raw_list) {
   248	  paths <- names(named_raw_list)
   249	  stopifnot(
   250	    "named_raw_list must be a non-empty named list" = length(paths) > 0 && all(nzchar(paths))
   251	  )
   252	  # Containment: refuse any path that could escape the archive root before it is
   253	  # written under the scratch dir with file.path(src_dir, path).
   254	  for (path in paths) {
   255	    .analysis_release_assert_safe_path(path)
   256	  }
   257	  paths <- sort(paths)
   258
   259	  src_dir <- tempfile("analysis-release-src-")
   260	  dir.create(src_dir, recursive = TRUE)
   180	          as.integer(f$byte_size),
   181	          f$media_type %||% "application/json",
   182	          list(f$content_gzip)
   183	        ))
   184	      )
   185	    }
   186	  })
   187
   188	  release_id
   189	}
   190
   191	# --------------------------------------------------------------------------- #
   192	# Public projection
   193	# --------------------------------------------------------------------------- #
   194
   195	#' Project a release head to the PUBLIC allowlist (#573 H1).
   196	#'
   197	#' The raw head carries operational columns — `created_by_user_id`,
   198	#' `last_error_message`, `updated_at` — that must never reach the public
   199	#' list/detail/latest surface. This projects to an explicit allowlist and groups
   200	#' the DOI fields under `zenodo`. Public-safe derived members (`layers` from
   201	#' `analysis_release_list()`, the parsed `manifest` from `analysis_release_get()`)
   202	#' are carried through when present. The ADMIN surface keeps the raw head.
   203	#'
   204	#' @param head A named list (a raw head from the repository read functions), or NULL.
   205	#' @return The projected named list, or NULL when `head` is NULL.
   206	#' @export
   207	analysis_release_public_head <- function(head) {
   208	  if (is.null(head)) {
   209	    return(NULL)
   210	  }
   211	  nullify <- function(x) if (is.null(x) || (length(x) == 1L && is.na(x))) NULL else x
   212
   213	  allowlist <- c(
   214	    "release_id", "release_version", "title", "status", "content_digest",
   215	    "created_at", "published_at", "source_data_version",
   216	    "db_release_version", "db_release_commit", "manifest_sha256",
   217	    "bundle_sha256", "license", "file_count", "total_bytes"
   218	  )
   219	  projected <- head[intersect(allowlist, names(head))]
   220	  projected$zenodo <- list(
   221	    record_url = nullify(head$zenodo_record_url),
   222	    version_doi = nullify(head$version_doi),
   223	    concept_doi = nullify(head$concept_doi)
   224	  )
   225	  if (!is.null(head$layers)) {
   226	    projected$layers <- head$layers
   227	  }
   228	  if (!is.null(head$manifest)) {
   229	    projected$manifest <- head$manifest
   230	  }
   231	  projected
   232	}
   233
   234	# --------------------------------------------------------------------------- #
   235	# Read
   236	# --------------------------------------------------------------------------- #
   237
   238	#' Fetch a release head (+ parsed manifest.json, if stored) by id.
   239	#'
   240	#' Draft rows are hidden unless `include_draft = TRUE` — the visibility
   241	#' filter is applied in SQL (`AND status = 'published'`), not by fetching and
   242	#' discarding in R.
   243	#'
   244	#' @return A named list (head columns + `$manifest`, the parsed manifest.json
   245	#'   as a plain R list via `jsonlite::fromJSON(simplifyVector = FALSE)`), or
   400	  if (is.na(parsed)) default else parsed
   401	}
   402
   403	#* List published analysis-snapshot releases
   404	#*
   405	#* Immutable, content-addressed public releases (newest first). Draft
   406	#* releases are never returned.
   407	#*
   408	#* @tag analysis
   409	#* @serializer json list(na="string", auto_unbox=TRUE)
   410	#* @param limit:str Max releases to return (default "50")
   411	#* @param offset:str Offset into the published list (default "0")
   412	#*
   413	#* @response 200 OK. Returns { releases, pagination }.
   414	#*
   415	#* @get releases
   416	function(limit = "50", offset = "0", res) {
   417	  limit_int <- analysis_release_query_int(limit, 50L)
   418	  offset_int <- analysis_release_query_int(offset, 0L)
   419	  releases <- svc_release_list(limit = limit_int, offset = offset_int, conn = pool)
   420	  # L2: echo the EFFECTIVE (clamped) pagination the service actually queried,
   421	  # not the caller's raw values (svc_release_clamp_* is the single clamp source).
   422	  list(
   423	    releases = releases,
   424	    pagination = list(
   425	      limit = svc_release_clamp_limit(limit_int),
   426	      offset = svc_release_clamp_offset(offset_int),
   427	      count = length(releases)
   428	    )
   429	  )
   430	}
   431
   432
   433	#* Get the newest published analysis-snapshot release
   434	#*
   435	#* MUST stay declared before `releases/<release_id>` (see the ordering note
   436	#* above this section).
   437	#*
   438	#* @tag analysis
   439	#* @serializer json list(na="string", auto_unbox=TRUE)
   440	#*
   441	#* @response 200 OK. Returns the release head + `manifest` (same shape as the detail route).
   442	#* @response 404 Not Found. No published release exists yet.
   443	#*
   444	#* @get releases/latest
   445	function(res) {
   446	  newest <- svc_release_list(limit = 1, offset = 0, conn = pool)
   447	  if (length(newest) == 0L) {
   448	    stop_for_not_found("No published analysis-snapshot release exists yet")
   449	  }
   450	  svc_release_get(as.character(newest[[1]]$release_id), conn = pool)
   451	}
   452
   453
   454	#* Get one published analysis-snapshot release
   455	#*
   456	#* @tag analysis
   457	#* @serializer json list(na="string", auto_unbox=TRUE)
   458	#* @param release_id Release id (`asr_<16 hex>`).
   459	#*
   460	#* @response 200 OK. Returns the release head + `manifest`.
   461	#* @response 404 Not Found. Unknown release id, or the release is still a draft.
   462	#*
   463	#* @get releases/<release_id>
   464	function(release_id, res) {
   465	  svc_release_get(release_id, conn = pool)
   466	}
   467
   468
   469	#* Get a published release's stored `manifest.json` bytes verbatim
   470	#*
   471	#* Serves the EXACT stored bytes (never re-serialized), so
   472	#* `sha256(bytes) == manifest_sha256` on the release head.
   473	#*
   474	#* @tag analysis
   475	#* @serializer octet list(type = "application/json")
   476	#* @param release_id Release id.
   477	#*
   478	#* @response 200 OK. Raw manifest.json bytes, Content-Type application/json.
   479	#* @response 404 Not Found. Unknown release id, or the release is still a draft.
   480	#*
   481	#* @get releases/<release_id>/manifest.json
   482	function(release_id, res) {
   483	  content <- svc_release_manifest(release_id, conn = pool)
   484	  # Content-Type is set by the octet serializer (application/json) -- do NOT also
   485	  # res$setHeader() it, which would emit a duplicate Content-Type header.
   486	  content$bytes
   487	}
   488
   489
   490	#* Get one content file from a published release by its exact archive path
   491	#*
   492	#* `path` is a QUERY parameter, not a path segment -- Plumber 1.3.2 has no
   493	#* `<path:.*>` multi-segment param type, so a nested path segment would 404.
   494	#* Resolved by an exact `(release_id, file_path)` primary-key lookup, so
   495	#* there is no path-traversal surface.
   496	#*
   497	#* @tag analysis
   498	#* @serializer octet
   499	#* @param release_id Release id.
   500	#* @param path:str Exact archive-relative file path, e.g. "functional_clusters/payload.json".
   501	#*
   502	#* @response 200 OK. Raw file bytes, Content-Type from the stored file's media type.
   503	#* @response 404 Not Found. Unknown release id, draft release, or unknown file path.
   504	#*
   505	#* @get releases/<release_id>/file
   506	function(release_id, path = "", res) {
   507	  file_path <- analysis_endpoint_scalar(path, "")
   508	  content <- svc_release_file(release_id, file_path, conn = pool)
   509	  # The stored media type is per-file (usually application/json), so set the
   510	  # serializer's type dynamically rather than res$setHeader()-ing a second
   511	  # Content-Type alongside the octet serializer's default.
   512	  res$serializer <- plumber::serializer_octet(type = content$media_type)
   513	  content$bytes
   514	}
   515
   516
   517	#* Download a published release's whole archive (`bundle.tar.gz`) verbatim
   518	#*
   519	#* @tag analysis
   520	#* @serializer octet list(type = "application/gzip")
   521	#* @param release_id Release id.
   522	#*
   523	#* @response 200 OK. Raw gzip tar bytes, served as an attachment download.
   524	#* @response 404 Not Found. Unknown release id, or the release is still a draft.
   525	#*
   526	#* @get releases/<release_id>/bundle
   527	function(release_id, res) {
   528	  bundle <- svc_release_bundle(release_id, conn = pool)
   529	  # Content-Type (application/gzip) is set by the octet serializer -- do NOT also
   530	  # res$setHeader() it (duplicate header). Content-Disposition/Length are distinct.
   531	  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', bundle$filename))
   532	  res$setHeader("Content-Length", as.character(length(bundle$bytes)))
   533	  bundle$bytes
   534	}
   535
   536	## Analyses endpoints
   537	## -------------------------------------------------------------------##
   135	#* Build (and, by default, publish) a new analysis-snapshot release (Administrator only)
   136	#*
   137	#* Loads the currently active public-ready snapshots for the fixed layer
   138	#* registry (or a caller-supplied `layers` override -- see the JSON body
   139	#* shape below), gates them (available + hard coherence + reproducibility
   140	#* presence + shared source-data version + dependency lineage), materializes
   141	#* the release files, and persists an immutable, content-addressed release.
   142	#* A rebuild whose content is IDENTICAL to an existing release is idempotent
   143	#* (200, same release_id, no duplicate row); a genuinely new content set is
   144	#* 201. A gate failure (a layer not available / incoherent / missing its
   145	#* reproducibility bundle / mismatched source version or dependency lineage)
   146	#* is 400, naming the failing layer.
   147	#*
   148	#* JSON body (all fields optional): `{ layers?: [...], title?,
   149	#* scope_statement?, license?, publish? }`. `publish` defaults to `true`;
   150	#* `false` stages a draft for review before a Zenodo run. `license` defaults
   151	#* to `"CC-BY-4.0"`. Omitting `layers` uses the fixed default registry
   152	#* (`analysis_snapshot_release_layers()`).
   153	#*
   154	#* @tag admin
   155	#* @serializer unboxedJSON
   156	#*
   157	#* @post /releases
   158	function(req, res) {
   159	  require_role(req, res, "Administrator")
   160
   161	  body <- .admin_release_parse_json_body(req)
   162	  publish_flag <- if (is.null(body$publish)) TRUE else isTRUE(body$publish)
   163
   164	  # analysis_snapshot_release_build() ultimately calls
   165	  # analysis_release_insert(), which wraps its writes in ONE
   166	  # DBI::dbWithTransaction() and binds blob params via list(<raw>) -- both
   167	  # need a real DBIConnection, never the global `pool` Pool object directly
   168	  # (see functions/analysis-snapshot-release-repository.R's file header).
   169	  # The other 5 admin routes below issue single non-transactional
   170	  # dbExecute()/dbGetQuery() calls, which pool::Pool supports directly.
   171	  conn <- pool::poolCheckout(pool)
   172	  on.exit(pool::poolReturn(conn), add = TRUE)
   173
   174	  svc_release_build(
   175	    res,
   176	    layers = body$layers,
   177	    title = body$title,
   178	    scope_statement = body$scope_statement,
   179	    license = body$license %||% "CC-BY-4.0",
   180	    publish = publish_flag,
   181	    created_by = req$user_id,
   182	    conn = conn
   183	  )
   184	}
   185
   186	#* List ALL analysis-snapshot releases, including drafts (Administrator only)
   187	#*
   188	#* Unlike the public `GET /api/analysis/releases` (published-only, see
   189	#* `svc_release_list()`), this admin listing includes draft rows so an
   190	#* operator can see an in-progress/failed build before it is published or
   191	#* deleted.
   192	#*
   193	#* @tag admin
   194	#* @serializer unboxedJSON
   195	#*
   196	#* @param limit:int Optional page size. Default 50.
   197	#* @param offset:int Optional page offset. Default 0.
   198	#*
   199	#* @get /releases
   200	function(req, res, limit = NULL, offset = NULL) {
   201	  require_role(req, res, "Administrator")
   202
   203	  limit_int <- .admin_release_query_int(limit, 50L)
   204	  offset_int <- .admin_release_query_int(offset, 0L)
   205	  releases <- analysis_release_list(status = NULL, limit = limit_int, offset = offset_int, conn = pool)
   206
   207	  list(
   208	    releases = releases,
   209	    pagination = list(limit = limit_int, offset = offset_int, count = length(releases))
   210	  )
   211	}
   212
   213	#* Fetch one analysis-snapshot release, including a draft (Administrator only)
   214	#*
   215	#* Unlike the public `GET /api/analysis/releases/<id>` (published-only, see
   216	#* `svc_release_get()`), this admin detail resolves a draft release too.
   217	#*
   218	#* @tag admin
   219	#* @serializer unboxedJSON
   220	#*
   221	#* @get /releases/<release_id>
   222	function(req, res, release_id) {
   223	  require_role(req, res, "Administrator")
   224
   225	  head <- analysis_release_get(release_id, include_draft = TRUE, conn = pool)
   226	  if (is.null(head)) {
   227	    stop_for_not_found("Release not found")
   228	  }
   229	  head
   230	}
   231
   232	#* Publish a draft analysis-snapshot release (Administrator only)
   233	#*
   234	#* Unknown release id -> 404. Publishing an already-published release is an
   235	#* idempotent no-op. Returns the (published) release head.
   236	#*
   237	#* @tag admin
   238	#* @serializer unboxedJSON
   239	#*
   240	#* @post /releases/<release_id>/publish
   241	function(req, res, release_id) {
   242	  require_role(req, res, "Administrator")
   243	  svc_release_publish(release_id, conn = pool)
   244	}
   245
   246	#* Record external Zenodo/DOI provenance on a release (Administrator only)
   247	#*
   248	#* Additive metadata only; NEVER touches the release's `content_digest` /
   249	#* `manifest_sha256` (release scientific identity is immutable once minted).
   250	#* Any subset of the four fields may be supplied -- an omitted field is left
   251	#* unchanged, it is never cleared/nulled out.
   252	#*
   253	#* @tag admin
   254	#* @serializer unboxedJSON
   255	#*
   256	#* @param zenodo_record_id:str Optional.
   257	#* @param zenodo_record_url:str Optional.
   258	#* @param version_doi:str Optional.
   259	#* @param concept_doi:str Optional.
   260	#*
   261	#* @patch /releases/<release_id>/doi
   262	function(req, res, release_id, zenodo_record_id = NULL, zenodo_record_url = NULL,
   263	         version_doi = NULL, concept_doi = NULL) {
   264	  require_role(req, res, "Administrator")
   265
   266	  doi_fields <- list(
   267	    zenodo_record_id = zenodo_record_id,
   268	    zenodo_record_url = zenodo_record_url,
   269	    version_doi = version_doi,
   270	    concept_doi = concept_doi
   271	  )
   272	  # Only forward fields the caller actually supplied -- list(a = NULL) still
   273	  # keeps the name "a", so an unfiltered pass-through would overwrite every
   274	  # omitted field to NULL instead of leaving it unchanged.
   275	  doi_fields <- doi_fields[!vapply(doi_fields, is.null, logical(1))]
   276
   277	  svc_release_set_doi(release_id, doi_fields = doi_fields, conn = pool)
   278	}
   279
   280	#* Delete a draft analysis-snapshot release (Administrator only)
   281	#*
   282	#* Unknown release id -> 404. Refuses (400) once the release is published --
   283	#* releases are retained indefinitely once published; only a draft (e.g. a
   284	#* failed/aborted build) can be discarded.
   285	#*
   286	#* @tag admin
   287	#* @serializer unboxedJSON
   288	#*
   289	#* @delete /releases/<release_id>
   290	function(req, res, release_id) {
   291	  require_role(req, res, "Administrator")
   292	  svc_release_delete_draft(release_id, conn = pool)
   293	}

exec
/bin/bash -lc 'nl -ba app/src/api/admin_analysis_release.ts; nl -ba app/src/views/admin/useAnalysisReleaseAdmin.ts; nl -ba app/src/views/admin/ManageAnalysisReleases.vue; nl -ba app/src/views/admin/useAnalysisReleaseAdmin.spec.ts; nl -ba app/src/views/admin/ManageAnalysisReleases.spec.ts' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
     1	// app/src/api/admin_analysis_release.ts
     2	//
     3	// Administrator-only typed API client for analysis-snapshot RELEASE
     4	// management (#573 Slice B, Task B4a).
     5	//
     6	// Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (mounted at
     7	// /api/admin/analysis) — the release-management routes appended by #573
     8	// Slice A / Task A7. Every route here requires the Administrator role
     9	// (enforced server-side; `apiClient`'s interceptor supplies the bearer
    10	// token) and uses `@serializer unboxedJSON`, so response scalars are
    11	// plain JSON values, NOT array-wrapped — `unwrapScalar` is not needed here
    12	// (contrast `nddscore_admin.ts`, which reads a default-serialized route).
    13	//
    14	// The admin `/DataReleases` management VIEW that consumes this client is a
    15	// separate task (B4b) — this file is client-only, no view/composable/route.
    16
    17	import type { AxiosRequestConfig } from 'axios';
    18	import { apiClient } from './client';
    19
    20	// ---------------------------------------------------------------------------
    21	// Types
    22	// ---------------------------------------------------------------------------
    23
    24	/**
    25	 * Light per-layer identity, as it appears in `layers[]` on each head from
    26	 * the admin LIST route (`GET /releases`) — mirrors `ReleaseHeadLayer` in the
    27	 * public `analysis_releases.ts`, duplicated here so this file has no
    28	 * dependency on that public-only module (see the `AdminReleaseHead` note
    29	 * below for why the two head shapes are intentionally separate types).
    30	 */
    31	export interface AdminReleaseLayer {
    32	  analysis_type: string;
    33	  snapshot_id: number;
    34	  payload_hash: string;
    35	}
    36
    37	/**
    38	 * RAW `analysis_snapshot_release` head, as returned by the admin routes
    39	 * (`analysis_release_list()` / `analysis_release_get()`,
    40	 * api/functions/analysis-snapshot-release-repository.R). This is
    41	 * DELIBERATELY a SEPARATE type from the public `ReleaseHead` in
    42	 * `analysis_releases.ts` — the public projection nests DOI fields under
    43	 * `zenodo` and omits `created_by_user_id`/`last_error_message`; the admin
    44	 * surface returns the flat DOI columns plus those two operational fields.
    45	 * Do not import or reuse the public type here.
    46	 */
    47	export interface AdminReleaseHead {
    48	  release_id: string;
    49	  /**
    50	   * Reserved string column (`VARCHAR(32)`, migration 045) — always `null`
    51	   * today; the builder never populates it (`api/functions/analysis-snapshot-
    52	   * release.R`). Not a number, and not guaranteed non-null.
    53	   */
    54	  release_version: string | null;
    55	  title: string | null;
    56	  status: string;
    57	  manifest_schema_version: string;
    58	  content_digest: string;
    59	  source_data_version: string;
    60	  db_release_version: string | null;
    61	  db_release_commit: string | null;
    62	  manifest_sha256: string;
    63	  bundle_sha256: string;
    64	  license: string;
    65	  file_count: number;
    66	  total_bytes: number;
    67	  created_by_user_id: number | null;
    68	  created_at: string;
    69	  published_at: string | null;
    70	  updated_at: string;
    71	  zenodo_record_id: string | null;
    72	  zenodo_record_url: string | null;
    73	  version_doi: string | null;
    74	  concept_doi: string | null;
    75	  last_error_message: string | null;
    76	  /** Light per-layer summary (list route only). */
    77	  layers?: AdminReleaseLayer[];
    78	  [key: string]: unknown;
    79	}
    80
    81	export interface AdminReleaseListParams {
    82	  limit?: number;
    83	  offset?: number;
    84	}
    85
    86	export interface AdminReleaseListResponse {
    87	  releases: AdminReleaseHead[];
    88	  pagination: {
    89	    limit: number;
    90	    offset: number;
    91	    count: number;
    92	  };
    93	}
    94
    95	export interface BuildReleaseRequest {
    96	  /** Optional layer-registry override; omit for the fixed default registry. */
    97	  layers?: unknown[];
    98	  title?: string;
    99	  scope_statement?: string;
   100	  /** Defaults server-side to `"CC-BY-4.0"`. */
   101	  license?: string;
   102	  /** Defaults server-side to `true`. */
   103	  publish?: boolean;
   104	}
   105
   106	export interface RecordReleaseDoiFields {
   107	  zenodo_record_id?: string;
   108	  zenodo_record_url?: string;
   109	  version_doi?: string;
   110	  concept_doi?: string;
   111	}
   112
   113	/**
   114	 * Discriminated build outcome so a caller (B4b's view) can distinguish a
   115	 * genuinely-new release (201), a content-identical idempotent dup (200),
   116	 * and a transient "sources are mid-refresh" lock (503) — three DIFFERENT
   117	 * non-error outcomes the backend deliberately does not throw for. A 400
   118	 * gate failure (`release_snapshot_not_available`,
   119	 * `release_source_incoherent`, `release_reproducibility_missing`,
   120	 * `release_source_version_mismatch`, `release_dependency_lineage_mismatch`)
   121	 * still rejects as an `ApiError`; the caller reads its message via
   122	 * `extractApiErrorMessage`.
   123	 */
   124	export type BuildReleaseResult =
   125	  | { outcome: 'created'; release: AdminReleaseHead }
   126	  | { outcome: 'exists'; release: AdminReleaseHead }
   127	  | { outcome: 'locked'; retryAfter: number; message: string };
   128
   129	interface ReleaseLockUnavailableBody {
   130	  error: 'release_lock_unavailable';
   131	  message: string;
   132	}
   133
   134	/**
   135	 * Per-preset manifest state, as returned by `GET /snapshots/status`
   136	 * (`service_analysis_snapshot_status()`). The endpoint reports every
   137	 * supported analysis preset — including `phenotype_correlations` and
   138	 * `gene_network_edges`, which are NOT analysis-snapshot-release layers.
   139	 * `RELEASE_LAYER_TYPES` below is the single source of truth for the subset
   140	 * a release build actually consumes.
   141	 */
   142	export interface SnapshotPresetState {
   143	  analysis_type: string;
   144	  parameter_hash: string;
   145	  state: 'available' | 'stale' | 'source_version_mismatch' | 'missing';
   146	  generated_at: string | null;
   147	  activated_at: string | null;
   148	  stale_after: string | null;
   149	  source_data_version: string | null;
   150	  row_counts: Record<string, unknown> | null;
   151	  [key: string]: unknown;
   152	}
   153
   154	export interface SnapshotStatusSummary {
   155	  total: number;
   156	  available: number;
   157	  missing: number;
   158	  stale: number;
   159	  mismatch: number;
   160	}
   161
   162	export interface SnapshotStatusResponse {
   163	  presets: SnapshotPresetState[];
   164	  summary: SnapshotStatusSummary;
   165	}
   166
   167	/**
   168	 * The three analysis types an analysis-snapshot release actually freezes
   169	 * (`analysis_snapshot_release_layers()`, api/functions/analysis-snapshot-
   170	 * release.R). Single source of truth for filtering `GET /snapshots/status`'s
   171	 * broader preset list down to the layers B4b's "disable Build" gate cares
   172	 * about.
   173	 */
   174	export const RELEASE_LAYER_TYPES = [
   175	  'functional_clusters',
   176	  'phenotype_clusters',
   177	  'phenotype_functional_correlations',
   178	] as const;
   179
   180	// ---------------------------------------------------------------------------
   181	// Helpers
   182	// ---------------------------------------------------------------------------
   183
   184	/**
   185	 * POST /api/admin/analysis/releases
   186	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@post /releases`).
   187	 *
   188	 * Administrator-only. Loads the currently active public-ready snapshots,
   189	 * gates them, and persists an immutable, content-addressed release. Uses
   190	 * `apiClient.raw.post` with a widened `validateStatus` so 200 (idempotent
   191	 * dup), 201 (new content), and 503 (`release_lock_unavailable`, sources
   192	 * mid-refresh) all resolve instead of throwing — only those three plus any
   193	 * 4xx/5xx the caller opts into are distinguishable from a throw. 400 (any
   194	 * of the 5 gate-failure classes) and 404 (never actually returned by this
   195	 * route) still throw as `AxiosError`; the caller reads the message via
   196	 * `extractApiErrorMessage`.
   197	 */
   198	export async function buildRelease(
   199	  body: BuildReleaseRequest,
   200	  config?: AxiosRequestConfig
   201	): Promise<BuildReleaseResult> {
   202	  const response = await apiClient.raw.post<AdminReleaseHead | ReleaseLockUnavailableBody>(
   203	    '/api/admin/analysis/releases',
   204	    body,
   205	    {
   206	      ...config,
   207	      validateStatus: (status) => (status >= 200 && status < 300) || status === 503,
   208	    }
   209	  );
   210
   211	  if (response.status === 503) {
   212	    const locked = response.data as ReleaseLockUnavailableBody;
   213	    const retryAfterHeader = response.headers?.['retry-after'];
   214	    const retryAfter = Number.parseInt(String(retryAfterHeader ?? '5'), 10);
   215	    return {
   216	      outcome: 'locked',
   217	      retryAfter: Number.isFinite(retryAfter) ? retryAfter : 5,
   218	      message: locked.message,
   219	    };
   220	  }
   221
   222	  const release = response.data as AdminReleaseHead;
   223	  return {
   224	    outcome: response.status === 201 ? 'created' : 'exists',
   225	    release,
   226	  };
   227	}
   228
   229	/**
   230	 * GET /api/admin/analysis/releases
   231	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /releases`).
   232	 *
   233	 * Administrator-only. Lists ALL releases (draft + published + failed),
   234	 * newest first — unlike the public `GET /api/analysis/releases`
   235	 * (published-only).
   236	 */
   237	export async function listAdminReleases(
   238	  params: AdminReleaseListParams = {},
   239	  config?: AxiosRequestConfig
   240	): Promise<AdminReleaseListResponse> {
   241	  return apiClient.get<AdminReleaseListResponse>('/api/admin/analysis/releases', {
   242	    ...config,
   243	    params: { ...(config?.params as object | undefined), ...params },
   244	  });
   245	}
   246
   247	/**
   248	 * GET /api/admin/analysis/releases/<release_id>
   249	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /releases/<release_id>`).
   250	 *
   251	 * Administrator-only. Resolves a draft release too (`include_draft = true`).
   252	 * Throws AxiosError 404 for an unknown id.
   253	 */
   254	export async function getAdminRelease(
   255	  releaseId: string,
   256	  config?: AxiosRequestConfig
   257	): Promise<AdminReleaseHead> {
   258	  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}`;
   259	  return apiClient.get<AdminReleaseHead>(path, config);
   260	}
   261
   262	/**
   263	 * POST /api/admin/analysis/releases/<release_id>/publish
   264	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@post /releases/<release_id>/publish`).
   265	 *
   266	 * Administrator-only. Throws AxiosError 404 for an unknown id; an
   267	 * already-published release is an idempotent no-op that still returns the
   268	 * current head.
   269	 */
   270	export async function publishRelease(
   271	  releaseId: string,
   272	  config?: AxiosRequestConfig
   273	): Promise<AdminReleaseHead> {
   274	  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}/publish`;
   275	  return apiClient.post<AdminReleaseHead>(path, undefined, config);
   276	}
   277
   278	/**
   279	 * PATCH /api/admin/analysis/releases/<release_id>/doi
   280	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@patch /releases/<release_id>/doi`).
   281	 *
   282	 * Administrator-only. The four DOI fields are Plumber named args read from
   283	 * the query string, so ONLY the keys actually present in `fields` are
   284	 * forwarded as `config.params` — an omitted field must stay unchanged
   285	 * server-side, never nulled out by an unfiltered pass-through.
   286	 */
   287	export async function recordReleaseDoi(
   288	  releaseId: string,
   289	  fields: RecordReleaseDoiFields,
   290	  config?: AxiosRequestConfig
   291	): Promise<AdminReleaseHead> {
   292	  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}/doi`;
   293	  const params: Record<string, string> = {};
   294	  for (const [key, value] of Object.entries(fields)) {
   295	    if (value !== undefined && value !== null && value !== '') {
   296	      params[key] = value;
   297	    }
   298	  }
   299	  return apiClient.patch<AdminReleaseHead>(path, undefined, {
   300	    ...config,
   301	    params: { ...(config?.params as object | undefined), ...params },
   302	  });
   303	}
   304
   305	/**
   306	 * DELETE /api/admin/analysis/releases/<release_id>
   307	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@delete /releases/<release_id>`).
   308	 *
   309	 * Administrator-only. Deletes a DRAFT release only. Throws AxiosError 400
   310	 * if the release is already published, 404 for an unknown id.
   311	 */
   312	export async function deleteDraftRelease(
   313	  releaseId: string,
   314	  config?: AxiosRequestConfig
   315	): Promise<void> {
   316	  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}`;
   317	  await apiClient.delete<unknown>(path, config);
   318	}
   319
   320	/**
   321	 * GET /api/admin/analysis/snapshots/status
   322	 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /snapshots/status`).
   323	 *
   324	 * Administrator-only. Per-preset manifest state for every supported
   325	 * analysis preset (not just the three release layers — see
   326	 * `RELEASE_LAYER_TYPES`).
   327	 */
   328	export async function fetchSnapshotStatus(
   329	  config?: AxiosRequestConfig
   330	): Promise<SnapshotStatusResponse> {
   331	  return apiClient.get<SnapshotStatusResponse>('/api/admin/analysis/snapshots/status', config);
   332	}
     1	// app/src/views/admin/useAnalysisReleaseAdmin.ts
     2	//
     3	// Co-located composable for the `ManageAnalysisReleases.vue` Administrator
     4	// view (#573 Slice B, Task B4b). Owns every client call from the typed
     5	// admin release client (`@/api/admin_analysis_release`, Task B4a) plus the
     6	// reactive state the view renders, so the `.vue` stays a thin template.
     7	// Mirrors the `./useNddScoreAdminDerivedRows` co-location convention.
     8	//
     9	// The build is SYNCHRONOUS and DB-only (no async job/worker involved) —
    10	// `build()` is a single request/response round trip, not a job poll.
    11
    12	import { computed, ref, type ComputedRef, type Ref } from 'vue';
    13	import {
    14	  buildRelease,
    15	  deleteDraftRelease,
    16	  fetchSnapshotStatus,
    17	  listAdminReleases,
    18	  publishRelease,
    19	  recordReleaseDoi,
    20	  RELEASE_LAYER_TYPES,
    21	  type AdminReleaseHead,
    22	  type BuildReleaseRequest,
    23	  type BuildReleaseResult,
    24	  type RecordReleaseDoiFields,
    25	  type SnapshotPresetState,
    26	  type SnapshotStatusResponse,
    27	} from '@/api/admin_analysis_release';
    28	import { extractApiErrorMessage } from '@/utils/api-errors';
    29
    30	/** Human-readable label for each release layer, keyed by `analysis_type`. */
    31	const RELEASE_LAYER_LABELS: Record<(typeof RELEASE_LAYER_TYPES)[number], string> = {
    32	  functional_clusters: 'Functional clusters',
    33	  phenotype_clusters: 'Phenotype clusters',
    34	  phenotype_functional_correlations: 'Phenotype-functional correlation',
    35	};
    36
    37	export interface LayerReadinessItem {
    38	  analysis_type: (typeof RELEASE_LAYER_TYPES)[number];
    39	  label: string;
    40	  /** `'missing'` when the preset is absent from the status response entirely. */
    41	  state: SnapshotPresetState['state'] | 'missing';
    42	}
    43
    44	/** Build-form fields the view collects — the fixed default layer registry is always used. */
    45	export type BuildReleaseFormInput = Omit<BuildReleaseRequest, 'layers'>;
    46
    47	export interface UseAnalysisReleaseAdmin {
    48	  releases: Ref<AdminReleaseHead[]>;
    49	  status: Ref<SnapshotStatusResponse | null>;
    50	  loading: Ref<boolean>;
    51	  buildError: Ref<string | null>;
    52	  building: Ref<boolean>;
    53	  lastBuildOutcome: Ref<BuildReleaseResult | null>;
    54	  actionError: Ref<string | null>;
    55	  actionMessage: Ref<string | null>;
    56	  canBuild: ComputedRef<boolean>;
    57	  layerReadiness: ComputedRef<LayerReadinessItem[]>;
    58	  loadReleases: () => Promise<void>;
    59	  loadStatus: () => Promise<void>;
    60	  refreshAll: () => Promise<void>;
    61	  build: (input: BuildReleaseFormInput) => Promise<void>;
    62	  publish: (releaseId: string) => Promise<void>;
    63	  recordDoi: (releaseId: string, fields: RecordReleaseDoiFields) => Promise<void>;
    64	  deleteDraft: (releaseId: string) => Promise<void>;
    65	}
    66
    67	/** Drops undefined/null/empty-string values so the client only receives filled DOI fields. */
    68	function nonEmptyDoiFields(fields: RecordReleaseDoiFields): RecordReleaseDoiFields {
    69	  const result: RecordReleaseDoiFields = {};
    70	  (Object.keys(fields) as (keyof RecordReleaseDoiFields)[]).forEach((key) => {
    71	    const value = fields[key];
    72	    if (value !== undefined && value !== null && value !== '') {
    73	      result[key] = value;
    74	    }
    75	  });
    76	  return result;
    77	}
    78
    79	export function useAnalysisReleaseAdmin(): UseAnalysisReleaseAdmin {
    80	  const releases = ref<AdminReleaseHead[]>([]);
    81	  const status = ref<SnapshotStatusResponse | null>(null);
    82	  const loading = ref(false);
    83	  const buildError = ref<string | null>(null);
    84	  const building = ref(false);
    85	  const lastBuildOutcome = ref<BuildReleaseResult | null>(null);
    86	  const actionError = ref<string | null>(null);
    87	  const actionMessage = ref<string | null>(null);
    88
    89	  const canBuild = computed<boolean>(() => {
    90	    const current = status.value;
    91	    if (!current) return false;
    92	    return RELEASE_LAYER_TYPES.every(
    93	      (type) => current.presets.find((preset) => preset.analysis_type === type)?.state === 'available'
    94	    );
    95	  });
    96
    97	  const layerReadiness = computed<LayerReadinessItem[]>(() =>
    98	    RELEASE_LAYER_TYPES.map((type) => ({
    99	      analysis_type: type,
   100	      label: RELEASE_LAYER_LABELS[type],
   101	      state: status.value?.presets.find((preset) => preset.analysis_type === type)?.state ?? 'missing',
   102	    }))
   103	  );
   104
   105	  async function loadReleases(): Promise<void> {
   106	    try {
   107	      const response = await listAdminReleases();
   108	      releases.value = response.releases;
   109	    } catch (err) {
   110	      actionError.value = extractApiErrorMessage(
   111	        err,
   112	        'Failed to load analysis-snapshot releases.'
   113	      );
   114	    }
   115	  }
   116
   117	  async function loadStatus(): Promise<void> {
   118	    try {
   119	      status.value = await fetchSnapshotStatus();
   120	    } catch (err) {
   121	      actionError.value = extractApiErrorMessage(
   122	        err,
   123	        'Failed to load snapshot readiness status.'
   124	      );
   125	    }
   126	  }
   127
   128	  async function refreshAll(): Promise<void> {
   129	    loading.value = true;
   130	    try {
   131	      await Promise.all([loadReleases(), loadStatus()]);
   132	    } finally {
   133	      loading.value = false;
   134	    }
   135	  }
   136
   137	  async function build(input: BuildReleaseFormInput): Promise<void> {
   138	    buildError.value = null;
   139	    lastBuildOutcome.value = null;
   140	    building.value = true;
   141	    try {
   142	      const { license, ...rest } = input;
   143	      const payload: BuildReleaseRequest = { ...rest, publish: input.publish ?? false };
   144	      // The endpoint only substitutes its "CC-BY-4.0" default on a missing/NULL
   145	      // `license`, not on an empty string — so a cleared license input must omit
   146	      // the key entirely (not forward `""`) for the server default to apply.
   147	      if (license?.trim()) {
   148	        payload.license = license;
   149	      }
   150	      const outcome = await buildRelease(payload);
   151	      lastBuildOutcome.value = outcome;
   152	      if (outcome.outcome === 'created' || outcome.outcome === 'exists') {
   153	        await loadReleases();
   154	      }
   155	    } catch (err) {
   156	      buildError.value = extractApiErrorMessage(
   157	        err,
   158	        'Failed to build the analysis-snapshot release.'
   159	      );
   160	    } finally {
   161	      building.value = false;
   162	    }
   163	  }
   164
   165	  async function publish(releaseId: string): Promise<void> {
   166	    actionError.value = null;
   167	    actionMessage.value = null;
   168	    try {
   169	      const updated = await publishRelease(releaseId);
   170	      actionMessage.value = `Release ${updated.release_id} published.`;
   171	      await loadReleases();
   172	    } catch (err) {
   173	      actionError.value = extractApiErrorMessage(err, 'Failed to publish the release.');
   174	    }
   175	  }
   176
   177	  async function recordDoi(releaseId: string, fields: RecordReleaseDoiFields): Promise<void> {
   178	    actionError.value = null;
   179	    actionMessage.value = null;
   180	    try {
   181	      await recordReleaseDoi(releaseId, nonEmptyDoiFields(fields));
   182	      actionMessage.value = 'DOI metadata recorded.';
   183	      await loadReleases();
   184	    } catch (err) {
   185	      actionError.value = extractApiErrorMessage(err, 'Failed to record DOI metadata.');
   186	    }
   187	  }
   188
   189	  async function deleteDraft(releaseId: string): Promise<void> {
   190	    actionError.value = null;
   191	    actionMessage.value = null;
   192	    try {
   193	      await deleteDraftRelease(releaseId);
   194	      actionMessage.value = 'Draft release deleted.';
   195	      await loadReleases();
   196	    } catch (err) {
   197	      actionError.value = extractApiErrorMessage(err, 'Failed to delete the draft release.');
   198	    }
   199	  }
   200
   201	  return {
   202	    releases,
   203	    status,
   204	    loading,
   205	    buildError,
   206	    building,
   207	    lastBuildOutcome,
   208	    actionError,
   209	    actionMessage,
   210	    canBuild,
   211	    layerReadiness,
   212	    loadReleases,
   213	    loadStatus,
   214	    refreshAll,
   215	    build,
   216	    publish,
   217	    recordDoi,
   218	    deleteDraft,
   219	  };
   220	}
     1	<!-- app/src/views/admin/ManageAnalysisReleases.vue -->
     2	<!--
     3	  Administrator page to build/publish/DOI-tag analysis-snapshot releases
     4	  (#573 Slice B, Task B4b): immutable, content-addressed frozen exports of
     5	  the public-ready analysis snapshots (functional clusters, phenotype
     6	  clusters, phenotype-functional correlation). The build itself is
     7	  SYNCHRONOUS and DB-only — there is no async job/worker involved, so this
     8	  view never polls a job status (contrast ManageNDDScore.vue's import job).
     9
    10	  Kept thin: every client call and reactive state lives in the co-located
    11	  `useAnalysisReleaseAdmin` composable; this file is template + light local
    12	  UI-only state (the build form fields, the per-row DOI form drafts, and the
    13	  two-step "Delete draft" confirm — an in-page affordance, never a blocking
    14	  native `window.confirm`/dialog).
    15	-->
    16	<template>
    17	  <AuthenticatedPageShell
    18	    title="Manage analysis-snapshot releases"
    19	    description="Build, publish, and DOI-tag immutable, content-addressed exports of SysNDD's public-ready analysis snapshots (functional clusters, phenotype clusters, and their correlation). Each release freezes its own copy of the data and survives snapshot pruning or refresh byte-identically."
    20	    content-class="authenticated-route-content"
    21	    full-width
    22	  >
    23	    <BContainer fluid class="analysis-release-admin">
    24	      <AdminOperationPanel
    25	        title="Snapshot readiness"
    26	        description="A release build requires every release layer below to be available from the currently active public-ready snapshots."
    27	        icon="bi-clipboard-data"
    28	        :aria-busy="loading ? 'true' : 'false'"
    29	      >
    30	        <div class="layer-readiness-grid" data-testid="layer-readiness-grid">
    31	          <div
    32	            v-for="item in admin.layerReadiness.value"
    33	            :key="item.analysis_type"
    34	            class="layer-readiness-item"
    35	            :class="{ 'layer-readiness-item--ready': item.state === 'available' }"
    36	            :data-testid="`layer-readiness-${item.analysis_type}`"
    37	          >
    38	            <i
    39	              :class="[
    40	                'bi',
    41	                item.state === 'available' ? 'bi-check-circle-fill' : 'bi-x-circle-fill',
    42	              ]"
    43	              aria-hidden="true"
    44	            />
    45	            <div>
    46	              <strong>{{ item.label }}</strong>
    47	              <span class="layer-readiness-state">{{ item.state }}</span>
    48	            </div>
    49	          </div>
    50	        </div>
    51
    52	        <p v-if="!admin.canBuild.value" class="layer-readiness-hint mb-0">
    53	          Build is disabled until every release layer above reports
    54	          <strong>available</strong>. Snapshots self-heal automatically (stale or missing
    55	          snapshots re-enqueue on the next API restart), or an operator can force a refresh via
    56	          <code>POST /api/admin/analysis/snapshots/refresh</code>.
    57	        </p>
    58	      </AdminOperationPanel>
    59
    60	      <AdminOperationPanel
    61	        title="Build a release"
    62	        description="Freezes the currently active public-ready snapshots into a new immutable release. Building as a draft (the default) lets you review and record a DOI before publishing."
    63	        icon="bi-box-arrow-in-down"
    64	        heading-tag="h2"
    65	        :aria-busy="building ? 'true' : 'false'"
    66	      >
    67	        <BAlert v-if="admin.buildError.value" variant="danger" show class="mb-3" data-testid="build-error">
    68	          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
    69	          {{ admin.buildError.value }}
    70	        </BAlert>
    71
    72	        <BAlert
    73	          v-if="lockedOutcome"
    74	          variant="warning"
    75	          show
    76	          class="mb-3"
    77	          data-testid="build-locked"
    78	        >
    79	          <i class="bi bi-hourglass-split me-1" aria-hidden="true" />
    80	          Snapshot sources are refreshing, retry in {{ lockedOutcome.retryAfter }}s.
    81	          {{ lockedOutcome.message }}
    82	        </BAlert>
    83
    84	        <BAlert
    85	          v-else-if="createdOrExistingOutcome"
    86	          variant="success"
    87	          show
    88	          class="mb-3"
    89	          data-testid="build-success"
    90	        >
    91	          <i class="bi bi-check-circle-fill me-1" aria-hidden="true" />
    92	          Release <strong>{{ createdOrExistingOutcome.release.release_id }}</strong>
    93	          {{ createdOrExistingOutcome.outcome === 'created' ? 'created' : 'already existed (identical content)' }}
    94	          — status <strong>{{ createdOrExistingOutcome.release.status }}</strong>.
    95	        </BAlert>
    96
    97	        <form class="build-form" @submit.prevent="handleBuild">
    98	          <div class="build-form__field">
    99	            <label for="release-title" class="form-label fw-semibold">Title</label>
   100	            <BFormInput id="release-title" v-model="buildForm.title" data-testid="build-title" />
   101	          </div>
   102	          <div class="build-form__field">
   103	            <label for="release-scope" class="form-label fw-semibold">Scope statement</label>
   104	            <BFormTextarea
   105	              id="release-scope"
   106	              v-model="buildForm.scope_statement"
   107	              rows="2"
   108	              data-testid="build-scope"
   109	            />
   110	          </div>
   111	          <div class="build-form__field">
   112	            <label for="release-license" class="form-label fw-semibold">License</label>
   113	            <BFormInput id="release-license" v-model="buildForm.license" data-testid="build-license" />
   114	          </div>
   115	          <div class="build-form__field build-form__field--checkbox form-check">
   116	            <input
   117	              id="release-publish"
   118	              v-model="buildForm.publish"
   119	              class="form-check-input"
   120	              type="checkbox"
   121	              data-testid="build-publish-checkbox"
   122	            />
   123	            <label class="form-check-label" for="release-publish">
   124	              Publish immediately (unchecked builds a draft for review)
   125	            </label>
   126	          </div>
   127	          <BButton
   128	            type="submit"
   129	            variant="primary"
   130	            data-testid="build-release-btn"
   131	            :disabled="!admin.canBuild.value || building"
   132	          >
   133	            <BSpinner v-if="building" small class="me-1" />
   134	            <i v-else class="bi bi-hammer me-1" aria-hidden="true" />
   135	            Build release
   136	          </BButton>
   137	        </form>
   138	      </AdminOperationPanel>
   139
   140	      <AdminOperationPanel
   141	        title="Releases"
   142	        description="All releases, including drafts. Publishing and DOI recording never change a release's content digest."
   143	        icon="bi-archive"
   144	        heading-tag="h2"
   145	        :aria-busy="loading ? 'true' : 'false'"
   146	      >
   147	        <BAlert v-if="admin.actionError.value" variant="danger" show class="mb-3" data-testid="action-error">
   148	          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
   149	          {{ admin.actionError.value }}
   150	        </BAlert>
   151	        <BAlert v-if="admin.actionMessage.value" variant="info" show class="mb-3" data-testid="action-message">
   152	          <i class="bi bi-info-circle-fill me-1" aria-hidden="true" />
   153	          {{ admin.actionMessage.value }}
   154	        </BAlert>
   155
   156	        <GenericTable :items="releaseRows" :fields="RELEASE_ADMIN_TABLE_FIELDS" :is-busy="loading">
   157	          <template #cell-status="{ row }">
   158	            <BBadge :variant="row.status === 'published' ? 'success' : 'secondary'">
   159	              {{ row.status }}
   160	            </BBadge>
   161	          </template>
   162	          <template #cell-actions="{ row, expansionShowing, toggleExpansion }">
   163	            <div class="release-actions">
   164	              <BButton
   165	                v-if="row.status === 'draft'"
   166	                size="sm"
   167	                variant="outline-primary"
   168	                :data-testid="`publish-${row.release_id}`"
   169	                @click="admin.publish(row.release_id)"
   170	              >
   171	                Publish
   172	              </BButton>
   173	              <BButton
   174	                size="sm"
   175	                variant="outline-secondary"
   176	                :data-testid="`toggle-doi-${row.release_id}`"
   177	                @click="toggleExpansion?.()"
   178	              >
   179	                {{ expansionShowing ? 'Hide DOI form' : 'Record DOI' }}
   180	              </BButton>
   181	              <template v-if="row.status === 'draft'">
   182	                <BButton
   183	                  v-if="pendingDeleteId !== row.release_id"
   184	                  size="sm"
   185	                  variant="outline-danger"
   186	                  :data-testid="`delete-${row.release_id}`"
   187	                  @click="pendingDeleteId = row.release_id"
   188	                >
   189	                  Delete draft
   190	                </BButton>
   191	                <template v-else>
   192	                  <BButton
   193	                    size="sm"
   194	                    variant="danger"
   195	                    :data-testid="`confirm-delete-${row.release_id}`"
   196	                    @click="handleConfirmDelete(row.release_id)"
   197	                  >
   198	                    Confirm delete
   199	                  </BButton>
   200	                  <BButton size="sm" variant="outline-secondary" @click="pendingDeleteId = null">
   201	                    Cancel
   202	                  </BButton>
   203	                </template>
   204	              </template>
   205	            </div>
   206	          </template>
   207	          <template #row-expansion="{ row, toggle }">
   208	            <div class="doi-form" :data-testid="`doi-form-${row.release_id}`">
   209	              <div class="doi-form__grid">
   210	                <div class="doi-form__field">
   211	                  <label :for="`doi-version-${row.release_id}`" class="form-label fw-semibold">
   212	                    Version DOI
   213	                  </label>
   214	                  <BFormInput
   215	                    :id="`doi-version-${row.release_id}`"
   216	                    v-model="doiFormFor(row.release_id).version_doi"
   217	                    :data-testid="`doi-version-input-${row.release_id}`"
   218	                  />
   219	                </div>
   220	                <div class="doi-form__field">
   221	                  <label :for="`doi-concept-${row.release_id}`" class="form-label fw-semibold">
   222	                    Concept DOI
   223	                  </label>
   224	                  <BFormInput
   225	                    :id="`doi-concept-${row.release_id}`"
   226	                    v-model="doiFormFor(row.release_id).concept_doi"
   227	                  />
   228	                </div>
   229	                <div class="doi-form__field">
   230	                  <label :for="`doi-zenodo-id-${row.release_id}`" class="form-label fw-semibold">
   231	                    Zenodo record ID
   232	                  </label>
   233	                  <BFormInput
   234	                    :id="`doi-zenodo-id-${row.release_id}`"
   235	                    v-model="doiFormFor(row.release_id).zenodo_record_id"
   236	                  />
   237	                </div>
   238	                <div class="doi-form__field">
   239	                  <label :for="`doi-zenodo-url-${row.release_id}`" class="form-label fw-semibold">
   240	                    Zenodo record URL
   241	                  </label>
   242	                  <BFormInput
   243	                    :id="`doi-zenodo-url-${row.release_id}`"
   244	                    v-model="doiFormFor(row.release_id).zenodo_record_url"
   245	                  />
   246	                </div>
   247	              </div>
   248	              <BButton
   249	                size="sm"
   250	                variant="primary"
   251	                class="mt-2"
   252	                :data-testid="`save-doi-${row.release_id}`"
   253	                @click="handleSaveDoi(row.release_id, toggle)"
   254	              >
   255	                Save DOI
   256	              </BButton>
   257	            </div>
   258	          </template>
   259	        </GenericTable>
   260
   261	        <p v-if="!loading && admin.releases.value.length === 0" class="text-muted small mb-0 mt-2">
   262	          No releases yet.
   263	        </p>
   264	      </AdminOperationPanel>
   265	    </BContainer>
   266	  </AuthenticatedPageShell>
   267	</template>
   268
   269	<script setup lang="ts">
   270	import { computed, onMounted, reactive, ref } from 'vue';
   271	import { useHead } from '@unhead/vue';
   272	import { BAlert, BBadge, BButton, BContainer, BFormInput, BFormTextarea, BSpinner } from 'bootstrap-vue-next';
   273	import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
   274	import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
   275	import GenericTable from '@/components/small/GenericTable.vue';
   276	import type { RecordReleaseDoiFields } from '@/api/admin_analysis_release';
   277	import { useAnalysisReleaseAdmin, type BuildReleaseFormInput } from './useAnalysisReleaseAdmin';
   278
   279	useHead({ title: 'Manage analysis-snapshot releases' });
   280
   281	const RELEASE_ADMIN_TABLE_FIELDS = [
   282	  { key: 'release_id', label: 'Release' },
   283	  { key: 'status', label: 'Status' },
   284	  { key: 'source_data_version', label: 'Source data version' },
   285	  { key: 'created_at', label: 'Created' },
   286	  { key: 'published_at', label: 'Published' },
   287	  { key: 'file_count', label: 'Files' },
   288	  { key: 'version_doi', label: 'Version DOI' },
   289	  { key: 'actions', label: 'Actions' },
   290	];
   291
   292	/**
   293	 * Flat display row for the releases table. `GenericDesktopTable.vue` only
   294	 * wires custom `#cell(<key>)` slots for a fixed, hardcoded set of field keys
   295	 * (`status` and `actions` here, notably NOT `created_at`/`published_at`/
   296	 * `version_doi`) — the same BVN gotcha `dataReleaseTable.ts` documents for
   297	 * the public /DataReleases table. A `field.formatter` silently never runs
   298	 * either, so display formatting (dates, the DOI dash sentinel) is baked
   299	 * into the row here rather than attempted via a cell slot or formatter for
   300	 * an unwired key.
   301	 */
   302	interface AdminReleaseTableRow {
   303	  release_id: string;
   304	  status: string;
   305	  source_data_version: string;
   306	  created_at: string;
   307	  published_at: string;
   308	  file_count: number;
   309	  version_doi: string;
   310	}
   311
   312	const admin = useAnalysisReleaseAdmin();
   313	const { loading, building } = admin;
   314
   315	const releaseRows = computed<AdminReleaseTableRow[]>(() =>
   316	  admin.releases.value.map((release) => ({
   317	    release_id: release.release_id,
   318	    status: release.status,
   319	    source_data_version: release.source_data_version,
   320	    created_at: formatDate(release.created_at),
   321	    published_at: formatDate(release.published_at),
   322	    file_count: release.file_count,
   323	    version_doi: release.version_doi || '—',
   324	  }))
   325	);
   326
   327	const buildForm = reactive<BuildReleaseFormInput>({
   328	  title: '',
   329	  scope_statement: '',
   330	  license: 'CC-BY-4.0',
   331	  // Safe operator flow: build as a draft by default, review, then publish explicitly.
   332	  publish: false,
   333	});
   334
   335	const lockedOutcome = computed(() =>
   336	  admin.lastBuildOutcome.value?.outcome === 'locked' ? admin.lastBuildOutcome.value : null
   337	);
   338	const createdOrExistingOutcome = computed(() => {
   339	  const outcome = admin.lastBuildOutcome.value;
   340	  return outcome && outcome.outcome !== 'locked' ? outcome : null;
   341	});
   342
   343	/** Two-step "Delete draft" confirm state — an in-page affordance, never a native dialog. */
   344	const pendingDeleteId = ref<string | null>(null);
   345
   346	/** Per-row DOI draft form values, lazily created and kept across expand/collapse. */
   347	const doiForms = reactive<Record<string, RecordReleaseDoiFields>>({});
   348	function doiFormFor(releaseId: string): RecordReleaseDoiFields {
   349	  if (!doiForms[releaseId]) {
   350	    doiForms[releaseId] = {
   351	      version_doi: '',
   352	      concept_doi: '',
   353	      zenodo_record_id: '',
   354	      zenodo_record_url: '',
   355	    };
   356	  }
   357	  return doiForms[releaseId];
   358	}
   359
   360	function formatDate(value: string | null | undefined): string {
   361	  if (!value) return '—';
   362	  const parsed = new Date(value);
   363	  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleString();
   364	}
   365
   366	async function handleBuild(): Promise<void> {
   367	  await admin.build({ ...buildForm });
   368	}
   369
   370	async function handleConfirmDelete(releaseId: string): Promise<void> {
   371	  await admin.deleteDraft(releaseId);
   372	  pendingDeleteId.value = null;
   373	}
   374
   375	async function handleSaveDoi(releaseId: string, toggle: () => void): Promise<void> {
   376	  await admin.recordDoi(releaseId, { ...doiFormFor(releaseId) });
   377	  if (!admin.actionError.value) {
   378	    toggle();
   379	  }
   380	}
   381
   382	onMounted(() => {
   383	  void admin.refreshAll();
   384	});
   385	</script>
   386
   387	<style scoped>
   388	.analysis-release-admin {
   389	  padding: 0;
   390	}
   391
   392	.layer-readiness-grid {
   393	  display: grid;
   394	  grid-template-columns: repeat(3, minmax(0, 1fr));
   395	  gap: 0.75rem;
   396	}
   397
   398	.layer-readiness-item {
   399	  display: flex;
   400	  align-items: center;
   401	  gap: 0.6rem;
   402	  padding: 0.625rem 0.75rem;
   403	  border: 1px solid rgba(198, 40, 40, 0.28);
   404	  border-radius: var(--radius-md, 0.375rem);
   405	  background: #fff5f5;
   406	  color: var(--status-danger, #c62828);
   407	}
   408
   409	.layer-readiness-item--ready {
   410	  border-color: rgba(46, 125, 50, 0.28);
   411	  background: #f3fbf4;
   412	  color: var(--status-success, #2e7d32);
   413	}
   414
   415	.layer-readiness-item strong {
   416	  display: block;
   417	  color: var(--neutral-900, #212121);
   418	  font-size: 0.875rem;
   419	}
   420
   421	.layer-readiness-state {
   422	  display: block;
   423	  font-size: 0.75rem;
   424	  text-transform: capitalize;
   425	}
   426
   427	.layer-readiness-hint {
   428	  margin-top: 0.85rem;
   429	  color: var(--neutral-600, #757575);
   430	  font-size: 0.8125rem;
   431	}
   432
   433	.layer-readiness-hint code {
   434	  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
   435	  font-size: 0.8em;
   436	}
   437
   438	.build-form {
   439	  display: grid;
   440	  gap: 0.85rem;
   441	  max-width: 32rem;
   442	}
   443
   444	.build-form__field--checkbox {
   445	  display: flex;
   446	  align-items: center;
   447	  gap: 0.5rem;
   448	}
   449
   450	.release-actions {
   451	  display: flex;
   452	  flex-wrap: wrap;
   453	  gap: 0.4rem;
   454	  justify-content: flex-end;
   455	}
   456
   457	.doi-form {
   458	  padding: 0.75rem;
   459	  border: 1px solid rgba(15, 23, 42, 0.08);
   460	  border-radius: var(--radius-md, 0.375rem);
   461	  background: #f8fafc;
   462	}
   463
   464	.doi-form__grid {
   465	  display: grid;
   466	  grid-template-columns: repeat(2, minmax(0, 1fr));
   467	  gap: 0.75rem;
   468	}
   469
   470	@media (max-width: 767.98px) {
   471	  .layer-readiness-grid {
   472	    grid-template-columns: 1fr;
   473	  }
   474
   475	  .doi-form__grid {
   476	    grid-template-columns: 1fr;
   477	  }
   478	}
   479	</style>
     1	// app/src/views/admin/useAnalysisReleaseAdmin.spec.ts
     2	//
     3	// Unit tests for the ManageAnalysisReleases composable (#573 Slice B, Task
     4	// B4b). Mocks the typed admin client (Task B4a) entirely so these assert
     5	// composable behavior only: the `canBuild` release-layer gate, the
     6	// discriminated build outcome handling (created/exists/locked/400-throw),
     7	// and that publish/recordDoi/deleteDraft forward the right arguments.
     8
     9	import { describe, expect, it, vi, beforeEach } from 'vitest';
    10	import type {
    11	  AdminReleaseHead,
    12	  SnapshotStatusResponse,
    13	} from '@/api/admin_analysis_release';
    14
    15	vi.mock('@/api/admin_analysis_release', async () => {
    16	  const actual = await vi.importActual<typeof import('@/api/admin_analysis_release')>(
    17	    '@/api/admin_analysis_release'
    18	  );
    19	  return {
    20	    ...actual,
    21	    buildRelease: vi.fn(),
    22	    listAdminReleases: vi.fn(),
    23	    getAdminRelease: vi.fn(),
    24	    publishRelease: vi.fn(),
    25	    recordReleaseDoi: vi.fn(),
    26	    deleteDraftRelease: vi.fn(),
    27	    fetchSnapshotStatus: vi.fn(),
    28	  };
    29	});
    30
    31	import {
    32	  buildRelease,
    33	  listAdminReleases,
    34	  publishRelease,
    35	  recordReleaseDoi,
    36	  deleteDraftRelease,
    37	  fetchSnapshotStatus,
    38	} from '@/api/admin_analysis_release';
    39	import { useAnalysisReleaseAdmin } from './useAnalysisReleaseAdmin';
    40
    41	function makeRelease(overrides: Partial<AdminReleaseHead> = {}): AdminReleaseHead {
    42	  return {
    43	    release_id: 'asr_abc123',
    44	    release_version: null,
    45	    title: 'Test release',
    46	    status: 'draft',
    47	    manifest_schema_version: '1.0',
    48	    content_digest: 'a'.repeat(64),
    49	    source_data_version: 'v1',
    50	    db_release_version: null,
    51	    db_release_commit: null,
    52	    manifest_sha256: 'b'.repeat(64),
    53	    bundle_sha256: 'c'.repeat(64),
    54	    license: 'CC-BY-4.0',
    55	    file_count: 5,
    56	    total_bytes: 1024,
    57	    created_by_user_id: 1,
    58	    created_at: '2026-07-01T00:00:00Z',
    59	    published_at: null,
    60	    updated_at: '2026-07-01T00:00:00Z',
    61	    zenodo_record_id: null,
    62	    zenodo_record_url: null,
    63	    version_doi: null,
    64	    concept_doi: null,
    65	    last_error_message: null,
    66	    ...overrides,
    67	  };
    68	}
    69
    70	function makeStatus(states: Record<string, string>): SnapshotStatusResponse {
    71	  return {
    72	    presets: Object.entries(states).map(([analysis_type, state]) => ({
    73	      analysis_type,
    74	      parameter_hash: 'hash',
    75	      state: state as SnapshotStatusResponse['presets'][number]['state'],
    76	      generated_at: null,
    77	      activated_at: null,
    78	      stale_after: null,
    79	      source_data_version: null,
    80	      row_counts: null,
    81	    })),
    82	    summary: { total: 0, available: 0, missing: 0, stale: 0, mismatch: 0 },
    83	  };
    84	}
    85
    86	const ALL_AVAILABLE = makeStatus({
    87	  functional_clusters: 'available',
    88	  phenotype_clusters: 'available',
    89	  phenotype_functional_correlations: 'available',
    90	  phenotype_correlations: 'missing',
    91	  gene_network_edges: 'missing',
    92	});
    93
    94	describe('useAnalysisReleaseAdmin', () => {
    95	  beforeEach(() => {
    96	    vi.clearAllMocks();
    97	  });
    98
    99	  describe('canBuild', () => {
   100	    it('is false while status has not loaded', () => {
   101	      const admin = useAnalysisReleaseAdmin();
   102	      expect(admin.canBuild.value).toBe(false);
   103	    });
   104
   105	    it('is false when a release layer is not available', async () => {
   106	      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(
   107	        makeStatus({
   108	          functional_clusters: 'available',
   109	          phenotype_clusters: 'stale',
   110	          phenotype_functional_correlations: 'available',
   111	        })
   112	      );
   113	      const admin = useAnalysisReleaseAdmin();
   114	      await admin.loadStatus();
   115	      expect(admin.canBuild.value).toBe(false);
   116	    });
   117
   118	    it('is true when all three release layers are available, ignoring non-release presets', async () => {
   119	      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(ALL_AVAILABLE);
   120	      const admin = useAnalysisReleaseAdmin();
   121	      await admin.loadStatus();
   122	      expect(admin.canBuild.value).toBe(true);
   123	    });
   124
   125	    it('is false when a release layer preset is entirely absent from the response', async () => {
   126	      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(
   127	        makeStatus({
   128	          functional_clusters: 'available',
   129	          phenotype_clusters: 'available',
   130	        })
   131	      );
   132	      const admin = useAnalysisReleaseAdmin();
   133	      await admin.loadStatus();
   134	      expect(admin.canBuild.value).toBe(false);
   135	    });
   136	  });
   137
   138	  describe('layerReadiness', () => {
   139	    it('reports the three release-layer states, "missing" when absent', async () => {
   140	      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(
   141	        makeStatus({ functional_clusters: 'available' })
   142	      );
   143	      const admin = useAnalysisReleaseAdmin();
   144	      await admin.loadStatus();
   145	      const byType = Object.fromEntries(
   146	        admin.layerReadiness.value.map((item) => [item.analysis_type, item.state])
   147	      );
   148	      expect(byType.functional_clusters).toBe('available');
   149	      expect(byType.phenotype_clusters).toBe('missing');
   150	      expect(byType.phenotype_functional_correlations).toBe('missing');
   151	    });
   152	  });
   153
   154	  describe('build', () => {
   155	    it('sets lastBuildOutcome and reloads releases on a created outcome', async () => {
   156	      const release = makeRelease({ status: 'draft' });
   157	      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
   158	        outcome: 'created',
   159	        release,
   160	      });
   161	      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
   162	        releases: [release],
   163	        pagination: { limit: 50, offset: 0, count: 1 },
   164	      });
   165
   166	      const admin = useAnalysisReleaseAdmin();
   167	      await admin.build({ title: 'My release', publish: false });
   168
   169	      expect(admin.lastBuildOutcome.value).toEqual({ outcome: 'created', release });
   170	      expect(admin.buildError.value).toBeNull();
   171	      expect(listAdminReleases).toHaveBeenCalledTimes(1);
   172	      expect(admin.releases.value).toEqual([release]);
   173	    });
   174
   175	    it('reloads releases on an exists outcome too', async () => {
   176	      const release = makeRelease({ status: 'published' });
   177	      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
   178	        outcome: 'exists',
   179	        release,
   180	      });
   181	      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
   182	        releases: [release],
   183	        pagination: { limit: 50, offset: 0, count: 1 },
   184	      });
   185
   186	      const admin = useAnalysisReleaseAdmin();
   187	      await admin.build({});
   188
   189	      expect(admin.lastBuildOutcome.value?.outcome).toBe('exists');
   190	      expect(listAdminReleases).toHaveBeenCalledTimes(1);
   191	    });
   192
   193	    it('sets a locked outcome with retryAfter and does NOT set buildError or reload', async () => {
   194	      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
   195	        outcome: 'locked',
   196	        retryAfter: 7,
   197	        message: 'Snapshot sources are refreshing.',
   198	      });
   199
   200	      const admin = useAnalysisReleaseAdmin();
   201	      await admin.build({});
   202
   203	      expect(admin.lastBuildOutcome.value).toEqual({
   204	        outcome: 'locked',
   205	        retryAfter: 7,
   206	        message: 'Snapshot sources are refreshing.',
   207	      });
   208	      expect(admin.buildError.value).toBeNull();
   209	      expect(listAdminReleases).not.toHaveBeenCalled();
   210	    });
   211
   212	    it('sets buildError to the extracted message on a thrown 400 gate failure', async () => {
   213	      (buildRelease as ReturnType<typeof vi.fn>).mockRejectedValue({
   214	        response: { data: { detail: 'release_snapshot_not_available: functional_clusters' } },
   215	      });
   216
   217	      const admin = useAnalysisReleaseAdmin();
   218	      await admin.build({});
   219
   220	      expect(admin.buildError.value).toBe(
   221	        'release_snapshot_not_available: functional_clusters'
   222	      );
   223	      expect(admin.lastBuildOutcome.value).toBeNull();
   224	    });
   225
   226	    it('omits a blank license so the server default ("CC-BY-4.0") applies, but forwards a non-empty license as-is', async () => {
   227	      const release = makeRelease();
   228	      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
   229	        outcome: 'created',
   230	        release,
   231	      });
   232	      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
   233	        releases: [release],
   234	        pagination: { limit: 50, offset: 0, count: 1 },
   235	      });
   236
   237	      const admin = useAnalysisReleaseAdmin();
   238
   239	      await admin.build({ title: 'Blank license', license: '   ', publish: false });
   240	      const blankLicensePayload = (buildRelease as ReturnType<typeof vi.fn>).mock.calls[0][0];
   241	      expect(blankLicensePayload).not.toHaveProperty('license');
   242
   243	      await admin.build({ title: 'Explicit license', license: 'MIT', publish: false });
   244	      const explicitLicensePayload = (buildRelease as ReturnType<typeof vi.fn>).mock.calls[1][0];
   245	      expect(explicitLicensePayload.license).toBe('MIT');
   246	    });
   247
   248	    it('clears a prior buildError when a new build call starts', async () => {
   249	      (buildRelease as ReturnType<typeof vi.fn>).mockRejectedValueOnce({
   250	        response: { data: { detail: 'first failure' } },
   251	      });
   252	      const admin = useAnalysisReleaseAdmin();
   253	      await admin.build({});
   254	      expect(admin.buildError.value).toBe('first failure');
   255
   256	      const release = makeRelease();
   257	      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
   258	        outcome: 'created',
   259	        release,
   260	      });
   261	      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
   262	        releases: [release],
   263	        pagination: { limit: 50, offset: 0, count: 1 },
   264	      });
   265	      await admin.build({});
   266	      expect(admin.buildError.value).toBeNull();
   267	    });
   268	  });
   269
   270	  describe('publish / recordDoi / deleteDraft', () => {
   271	    it('publish calls publishRelease with the release id and reloads', async () => {
   272	      const release = makeRelease({ status: 'published' });
   273	      (publishRelease as ReturnType<typeof vi.fn>).mockResolvedValue(release);
   274	      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
   275	        releases: [release],
   276	        pagination: { limit: 50, offset: 0, count: 1 },
   277	      });
   278
   279	      const admin = useAnalysisReleaseAdmin();
   280	      await admin.publish('asr_abc123');
   281
   282	      expect(publishRelease).toHaveBeenCalledWith('asr_abc123');
   283	      expect(listAdminReleases).toHaveBeenCalledTimes(1);
   284	    });
   285
   286	    it('publish surfaces the extracted error message on failure', async () => {
   287	      (publishRelease as ReturnType<typeof vi.fn>).mockRejectedValue({
   288	        response: { data: { detail: 'release not found' } },
   289	      });
   290	      const admin = useAnalysisReleaseAdmin();
   291	      await admin.publish('asr_missing');
   292	      expect(admin.actionError.value).toBe('release not found');
   293	    });
   294
   295	    it('recordDoi calls recordReleaseDoi with only the filled fields', async () => {
   296	      const release = makeRelease({ version_doi: '10.5281/zenodo.1' });
   297	      (recordReleaseDoi as ReturnType<typeof vi.fn>).mockResolvedValue(release);
   298	      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
   299	        releases: [release],
   300	        pagination: { limit: 50, offset: 0, count: 1 },
   301	      });
   302
   303	      const admin = useAnalysisReleaseAdmin();
   304	      await admin.recordDoi('asr_abc123', {
   305	        version_doi: '10.5281/zenodo.1',
   306	        concept_doi: '',
   307	        zenodo_record_id: undefined,
   308	        zenodo_record_url: '',
   309	      });
   310
   311	      expect(recordReleaseDoi).toHaveBeenCalledWith('asr_abc123', {
   312	        version_doi: '10.5281/zenodo.1',
   313	      });
   314	    });
   315
   316	    it('deleteDraft calls deleteDraftRelease with the release id and reloads', async () => {
   317	      (deleteDraftRelease as ReturnType<typeof vi.fn>).mockResolvedValue(undefined);
   318	      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
   319	        releases: [],
   320	        pagination: { limit: 50, offset: 0, count: 0 },
   321	      });
   322
   323	      const admin = useAnalysisReleaseAdmin();
   324	      await admin.deleteDraft('asr_draft1');
   325
   326	      expect(deleteDraftRelease).toHaveBeenCalledWith('asr_draft1');
   327	      expect(listAdminReleases).toHaveBeenCalledTimes(1);
   328	    });
   329	  });
   330
   331	  describe('refreshAll', () => {
   332	    it('loads both releases and status, toggling loading', async () => {
   333	      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
   334	        releases: [makeRelease()],
   335	        pagination: { limit: 50, offset: 0, count: 1 },
   336	      });
   337	      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(ALL_AVAILABLE);
   338
   339	      const admin = useAnalysisReleaseAdmin();
   340	      expect(admin.loading.value).toBe(false);
   341	      const promise = admin.refreshAll();
   342	      expect(admin.loading.value).toBe(true);
   343	      await promise;
   344	      expect(admin.loading.value).toBe(false);
   345	      expect(admin.releases.value).toHaveLength(1);
   346	      expect(admin.canBuild.value).toBe(true);
   347	    });
   348	  });
   349	});
     1	// app/src/views/admin/ManageAnalysisReleases.spec.ts
     2	//
     3	// Component tests for the Administrator analysis-snapshot-release page
     4	// (#573 Slice B, Task B4b). Mocks the typed admin client
     5	// (`@/api/admin_analysis_release`) directly so these exercise the real
     6	// composable + view wiring end-to-end (mirrors DataReleases.spec.ts).
     7	//
     8	// `GenericTable` is stubbed with a tiny hand-rolled template that forwards
     9	// the same slot names/props the real `GenericDesktopTable`/BTable wiring
    10	// exposes (`cell-status`, `cell-actions` with `expansion-showing`/
    11	// `toggle-expansion`, `row-expansion` with `toggle`) — the same technique
    12	// `ApprovalTableView.spec.ts`/`PubtatorNDDGenes.spec.ts` use to test
    13	// row-expansion consumers deterministically without depending on
    14	// BootstrapVueNext's internal BTable expansion implementation.
    15
    16	import { mount, flushPromises } from '@vue/test-utils';
    17	import { defineComponent } from 'vue';
    18	import { describe, expect, it, vi, beforeEach } from 'vitest';
    19	import type { AdminReleaseHead, SnapshotStatusResponse } from '@/api/admin_analysis_release';
    20
    21	vi.mock('@unhead/vue', () => ({
    22	  useHead: vi.fn(),
    23	}));
    24
    25	const buildReleaseMock = vi.fn();
    26	const listAdminReleasesMock = vi.fn();
    27	const publishReleaseMock = vi.fn();
    28	const recordReleaseDoiMock = vi.fn();
    29	const deleteDraftReleaseMock = vi.fn();
    30	const fetchSnapshotStatusMock = vi.fn();
    31
    32	vi.mock('@/api/admin_analysis_release', async () => {
    33	  const actual = await vi.importActual<typeof import('@/api/admin_analysis_release')>(
    34	    '@/api/admin_analysis_release'
    35	  );
    36	  return {
    37	    ...actual,
    38	    buildRelease: (...args: unknown[]) => buildReleaseMock(...args),
    39	    listAdminReleases: (...args: unknown[]) => listAdminReleasesMock(...args),
    40	    getAdminRelease: vi.fn(),
    41	    publishRelease: (...args: unknown[]) => publishReleaseMock(...args),
    42	    recordReleaseDoi: (...args: unknown[]) => recordReleaseDoiMock(...args),
    43	    deleteDraftRelease: (...args: unknown[]) => deleteDraftReleaseMock(...args),
    44	    fetchSnapshotStatus: (...args: unknown[]) => fetchSnapshotStatusMock(...args),
    45	  };
    46	});
    47
    48	import ManageAnalysisReleases from './ManageAnalysisReleases.vue';
    49
    50	const GenericTableStub = defineComponent({
    51	  props: ['items', 'fields', 'isBusy'],
    52	  data() {
    53	    return { expanded: {} as Record<string, boolean> };
    54	  },
    55	  methods: {
    56	    toggleRow(id: string) {
    57	      this.expanded[id] = !this.expanded[id];
    58	    },
    59	  },
    60	  template: `
    61	    <div data-testid="generic-table-stub">
    62	      <div v-for="item in items" :key="item.release_id" class="stub-row">
    63	        <span>{{ item.release_id }}</span>
    64	        <slot name="cell-status" :row="item" />
    65	        <slot
    66	          name="cell-actions"
    67	          :row="item"
    68	          :expansion-showing="!!expanded[item.release_id]"
    69	          :toggle-expansion="() => toggleRow(item.release_id)"
    70	        />
    71	        <div v-if="expanded[item.release_id]">
    72	          <slot name="row-expansion" :row="item" :toggle="() => toggleRow(item.release_id)" />
    73	        </div>
    74	      </div>
    75	    </div>
    76	  `,
    77	});
    78
    79	function makeRelease(overrides: Partial<AdminReleaseHead> = {}): AdminReleaseHead {
    80	  return {
    81	    release_id: 'asr_abc123',
    82	    release_version: null,
    83	    title: 'Test release',
    84	    status: 'draft',
    85	    manifest_schema_version: '1.0',
    86	    content_digest: 'a'.repeat(64),
    87	    source_data_version: 'v1',
    88	    db_release_version: null,
    89	    db_release_commit: null,
    90	    manifest_sha256: 'b'.repeat(64),
    91	    bundle_sha256: 'c'.repeat(64),
    92	    license: 'CC-BY-4.0',
    93	    file_count: 5,
    94	    total_bytes: 1024,
    95	    created_by_user_id: 1,
    96	    created_at: '2026-07-01T00:00:00Z',
    97	    published_at: null,
    98	    updated_at: '2026-07-01T00:00:00Z',
    99	    zenodo_record_id: null,
   100	    zenodo_record_url: null,
   101	    version_doi: null,
   102	    concept_doi: null,
   103	    last_error_message: null,
   104	    ...overrides,
   105	  };
   106	}
   107
   108	function makeStatus(states: Record<string, string>): SnapshotStatusResponse {
   109	  return {
   110	    presets: Object.entries(states).map(([analysis_type, state]) => ({
   111	      analysis_type,
   112	      parameter_hash: 'hash',
   113	      state: state as SnapshotStatusResponse['presets'][number]['state'],
   114	      generated_at: null,
   115	      activated_at: null,
   116	      stale_after: null,
   117	      source_data_version: null,
   118	      row_counts: null,
   119	    })),
   120	    summary: { total: 0, available: 0, missing: 0, stale: 0, mismatch: 0 },
   121	  };
   122	}
   123
   124	const ALL_AVAILABLE = makeStatus({
   125	  functional_clusters: 'available',
   126	  phenotype_clusters: 'available',
   127	  phenotype_functional_correlations: 'available',
   128	});
   129
   130	function mountView() {
   131	  return mount(ManageAnalysisReleases, {
   132	    global: {
   133	      stubs: { AdminOperationPanel: false, GenericTable: GenericTableStub },
   134	    },
   135	  });
   136	}
   137
   138	describe('ManageAnalysisReleases.vue', () => {
   139	  beforeEach(() => {
   140	    vi.clearAllMocks();
   141	    listAdminReleasesMock.mockResolvedValue({
   142	      releases: [],
   143	      pagination: { limit: 50, offset: 0, count: 0 },
   144	    });
   145	    fetchSnapshotStatusMock.mockResolvedValue(
   146	      makeStatus({
   147	        functional_clusters: 'missing',
   148	        phenotype_clusters: 'missing',
   149	        phenotype_functional_correlations: 'missing',
   150	      })
   151	    );
   152	  });
   153
   154	  it('disables the Build button when a release layer is not available', async () => {
   155	    const wrapper = mountView();
   156	    await flushPromises();
   157
   158	    const button = wrapper.find('[data-testid="build-release-btn"]');
   159	    expect(button.exists()).toBe(true);
   160	    expect(button.attributes('disabled')).toBeDefined();
   161	  });
   162
   163	  it('enables the Build button and invokes buildRelease when all three release layers are available', async () => {
   164	    fetchSnapshotStatusMock.mockResolvedValue(ALL_AVAILABLE);
   165	    const release = makeRelease({ status: 'draft' });
   166	    buildReleaseMock.mockResolvedValue({ outcome: 'created', release });
   167
   168	    const wrapper = mountView();
   169	    await flushPromises();
   170
   171	    const button = wrapper.find('[data-testid="build-release-btn"]');
   172	    expect(button.attributes('disabled')).toBeUndefined();
   173
   174	    await wrapper.find('form.build-form').trigger('submit');
   175	    await flushPromises();
   176
   177	    expect(buildReleaseMock).toHaveBeenCalledTimes(1);
   178	    expect(wrapper.find('[data-testid="build-success"]').exists()).toBe(true);
   179	  });
   180
   181	  it('shows a distinct retry warning (not a gate error) when the build is locked', async () => {
   182	    fetchSnapshotStatusMock.mockResolvedValue(ALL_AVAILABLE);
   183	    buildReleaseMock.mockResolvedValue({
   184	      outcome: 'locked',
   185	      retryAfter: 9,
   186	      message: 'Snapshot sources are refreshing.',
   187	    });
   188
   189	    const wrapper = mountView();
   190	    await flushPromises();
   191
   192	    await wrapper.find('form.build-form').trigger('submit');
   193	    await flushPromises();
   194
   195	    const locked = wrapper.find('[data-testid="build-locked"]');
   196	    expect(locked.exists()).toBe(true);
   197	    expect(locked.text()).toContain('retry in 9s');
   198	    expect(wrapper.find('[data-testid="build-error"]').exists()).toBe(false);
   199	  });
   200
   201	  it('sets the build error alert (not the locked warning) on a thrown 400 gate failure', async () => {
   202	    fetchSnapshotStatusMock.mockResolvedValue(ALL_AVAILABLE);
   203	    buildReleaseMock.mockRejectedValue({
   204	      response: { data: { detail: 'release_snapshot_not_available: functional_clusters' } },
   205	    });
   206
   207	    const wrapper = mountView();
   208	    await flushPromises();
   209
   210	    await wrapper.find('form.build-form').trigger('submit');
   211	    await flushPromises();
   212
   213	    const errorAlert = wrapper.find('[data-testid="build-error"]');
   214	    expect(errorAlert.exists()).toBe(true);
   215	    expect(errorAlert.text()).toContain('release_snapshot_not_available');
   216	    expect(wrapper.find('[data-testid="build-locked"]').exists()).toBe(false);
   217	  });
   218
   219	  it('renders a mocked draft row with a Publish action that calls publishRelease', async () => {
   220	    const release = makeRelease({ release_id: 'asr_draft1', status: 'draft' });
   221	    listAdminReleasesMock.mockResolvedValue({
   222	      releases: [release],
   223	      pagination: { limit: 50, offset: 0, count: 1 },
   224	    });
   225	    publishReleaseMock.mockResolvedValue({ ...release, status: 'published' });
   226
   227	    const wrapper = mountView();
   228	    await flushPromises();
   229
   230	    expect(wrapper.text()).toContain('asr_draft1');
   231	    const publishBtn = wrapper.find('[data-testid="publish-asr_draft1"]');
   232	    expect(publishBtn.exists()).toBe(true);
   233
   234	    await publishBtn.trigger('click');
   235	    await flushPromises();
   236
   237	    expect(publishReleaseMock).toHaveBeenCalledWith('asr_draft1');
   238	  });
   239
   240	  it('does not render a Publish action for an already-published release', async () => {
   241	    const release = makeRelease({ release_id: 'asr_pub1', status: 'published' });
   242	    listAdminReleasesMock.mockResolvedValue({
   243	      releases: [release],
   244	      pagination: { limit: 50, offset: 0, count: 1 },
   245	    });
   246
   247	    const wrapper = mountView();
   248	    await flushPromises();
   249
   250	    expect(wrapper.find('[data-testid="publish-asr_pub1"]').exists()).toBe(false);
   251	  });
   252
   253	  it('the Record-DOI control calls recordReleaseDoi with only the filled fields', async () => {
   254	    const release = makeRelease({ release_id: 'asr_doi1', status: 'published' });
   255	    listAdminReleasesMock.mockResolvedValue({
   256	      releases: [release],
   257	      pagination: { limit: 50, offset: 0, count: 1 },
   258	    });
   259	    recordReleaseDoiMock.mockResolvedValue({ ...release, version_doi: '10.5281/zenodo.99' });
   260
   261	    const wrapper = mountView();
   262	    await flushPromises();
   263
   264	    await wrapper.find('[data-testid="toggle-doi-asr_doi1"]').trigger('click');
   265	    await flushPromises();
   266
   267	    const versionInput = wrapper.find('[data-testid="doi-version-input-asr_doi1"]');
   268	    expect(versionInput.exists()).toBe(true);
   269	    await versionInput.setValue('10.5281/zenodo.99');
   270
   271	    await wrapper.find('[data-testid="save-doi-asr_doi1"]').trigger('click');
   272	    await flushPromises();
   273
   274	    expect(recordReleaseDoiMock).toHaveBeenCalledWith('asr_doi1', {
   275	      version_doi: '10.5281/zenodo.99',
   276	    });
   277	  });
   278
   279	  it('surfaces a failed Publish action error co-located in the Releases panel, not the readiness panel', async () => {
   280	    const release = makeRelease({ release_id: 'asr_fail1', status: 'draft' });
   281	    listAdminReleasesMock.mockResolvedValue({
   282	      releases: [release],
   283	      pagination: { limit: 50, offset: 0, count: 1 },
   284	    });
   285	    publishReleaseMock.mockRejectedValue({
   286	      response: { data: { detail: 'release not found' } },
   287	    });
   288
   289	    const wrapper = mountView();
   290	    await flushPromises();
   291
   292	    await wrapper.find('[data-testid="publish-asr_fail1"]').trigger('click');
   293	    await flushPromises();
   294
   295	    const panels = wrapper.findAll('[data-testid="admin-operation-panel"]');
   296	    expect(panels).toHaveLength(3);
   297	    const [readinessPanel, , releasesPanel] = panels;
   298
   299	    const errorInReleasesPanel = releasesPanel.find('[data-testid="action-error"]');
   300	    expect(errorInReleasesPanel.exists()).toBe(true);
   301	    expect(errorInReleasesPanel.text()).toContain('release not found');
   302
   303	    // The regression this guards: actionError used to render in the
   304	    // Snapshot-readiness panel, far from the row action that triggered it.
   305	    expect(readinessPanel.find('[data-testid="action-error"]').exists()).toBe(false);
   306	  });
   307
   308	  // LOW (#573 Slice B Codex round-1 review): the rejected-Publish test above
   309	  // was the only DOI-save/delete failure-path coverage. Add the missing two.
   310	  it('surfaces a failed DOI-save action error co-located in the Releases panel and keeps the DOI form open', async () => {
   311	    const release = makeRelease({ release_id: 'asr_doifail', status: 'published' });
   312	    listAdminReleasesMock.mockResolvedValue({
   313	      releases: [release],
   314	      pagination: { limit: 50, offset: 0, count: 1 },
   315	    });
   316	    recordReleaseDoiMock.mockRejectedValue({
   317	      response: { data: { detail: 'invalid DOI format' } },
   318	    });
   319
   320	    const wrapper = mountView();
   321	    await flushPromises();
   322
   323	    await wrapper.find('[data-testid="toggle-doi-asr_doifail"]').trigger('click');
   324	    await flushPromises();
   325
   326	    const versionInput = wrapper.find('[data-testid="doi-version-input-asr_doifail"]');
   327	    expect(versionInput.exists()).toBe(true);
   328	    await versionInput.setValue('not-a-real-doi');
   329
   330	    await wrapper.find('[data-testid="save-doi-asr_doifail"]').trigger('click');
   331	    await flushPromises();
   332
   333	    expect(recordReleaseDoiMock).toHaveBeenCalledWith('asr_doifail', {
   334	      version_doi: 'not-a-real-doi',
   335	    });
   336
   337	    const panels = wrapper.findAll('[data-testid="admin-operation-panel"]');
   338	    const releasesPanel = panels[2];
   339	    const errorInReleasesPanel = releasesPanel.find('[data-testid="action-error"]');
   340	    expect(errorInReleasesPanel.exists()).toBe(true);
   341	    expect(errorInReleasesPanel.text()).toContain('invalid DOI format');
   342
   343	    // A failed save must not silently collapse the form the operator was
   344	    // editing — the row stays expanded so the error is visible next to it.
   345	    expect(wrapper.find('[data-testid="doi-form-asr_doifail"]').exists()).toBe(true);
   346	  });
   347
   348	  it('surfaces a failed draft-deletion action error and resets the confirm state without removing the row', async () => {
   349	    const release = makeRelease({ release_id: 'asr_delfail', status: 'draft' });
   350	    listAdminReleasesMock.mockResolvedValue({
   351	      releases: [release],
   352	      pagination: { limit: 50, offset: 0, count: 1 },
   353	    });
   354	    deleteDraftReleaseMock.mockRejectedValue({
   355	      response: { data: { detail: 'release has published dependents' } },
   356	    });
   357
   358	    const wrapper = mountView();
   359	    await flushPromises();
   360
   361	    await wrapper.find('[data-testid="delete-asr_delfail"]').trigger('click');
   362	    await flushPromises();
   363	    expect(wrapper.find('[data-testid="confirm-delete-asr_delfail"]').exists()).toBe(true);
   364
   365	    await wrapper.find('[data-testid="confirm-delete-asr_delfail"]').trigger('click');
   366	    await flushPromises();
   367
   368	    expect(deleteDraftReleaseMock).toHaveBeenCalledWith('asr_delfail');
   369
   370	    const panels = wrapper.findAll('[data-testid="admin-operation-panel"]');
   371	    const releasesPanel = panels[2];
   372	    const errorInReleasesPanel = releasesPanel.find('[data-testid="action-error"]');
   373	    expect(errorInReleasesPanel.exists()).toBe(true);
   374	    expect(errorInReleasesPanel.text()).toContain('release has published dependents');
   375
   376	    // Sane failure handling: the confirm flow resets to the initial
   377	    // "Delete draft" affordance (not stuck showing "Confirm delete" forever)
   378	    // AND the row is not silently removed (loadReleases() only re-runs on a
   379	    // successful delete) — the operator sees the error next to a
   380	    // still-present, retryable row, not a vanished one.
   381	    expect(wrapper.find('[data-testid="confirm-delete-asr_delfail"]').exists()).toBe(false);
   382	    expect(wrapper.find('[data-testid="delete-asr_delfail"]').exists()).toBe(true);
   383	    expect(wrapper.text()).toContain('asr_delfail');
   384	  });
   385
   386	  it('deletes a draft only after the two-step in-page confirm, never via a blocking dialog', async () => {
   387	    const confirmSpy = vi.spyOn(window, 'confirm');
   388	    const release = makeRelease({ release_id: 'asr_draft2', status: 'draft' });
   389	    listAdminReleasesMock.mockResolvedValue({
   390	      releases: [release],
   391	      pagination: { limit: 50, offset: 0, count: 1 },
   392	    });
   393	    deleteDraftReleaseMock.mockResolvedValue(undefined);
   394
   395	    const wrapper = mountView();
   396	    await flushPromises();
   397
   398	    expect(wrapper.find('[data-testid="confirm-delete-asr_draft2"]').exists()).toBe(false);
   399
   400	    await wrapper.find('[data-testid="delete-asr_draft2"]').trigger('click');
   401	    await flushPromises();
   402
   403	    expect(deleteDraftReleaseMock).not.toHaveBeenCalled();
   404	    expect(confirmSpy).not.toHaveBeenCalled();
   405
   406	    await wrapper.find('[data-testid="confirm-delete-asr_draft2"]').trigger('click');
   407	    await flushPromises();
   408
   409	    expect(deleteDraftReleaseMock).toHaveBeenCalledWith('asr_draft2');
   410	    expect(confirmSpy).not.toHaveBeenCalled();
   411	  });
   412	});

exec
/bin/bash -lc "nl -ba app/src/views/admin/useAnalysisReleaseAdmin.ts | sed -n '100,260p'; nl -ba app/src/views/admin/ManageAnalysisReleases.vue | sed -n '1,540p'; nl -ba app/src/components/analyses/dataReleaseTable.ts; nl -ba app/src/router/routes.ts | sed -n '1,220p'; nl -ba app/src/assets/js/constants/main_nav_constants.ts | sed -n '1,160p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
   100	      label: RELEASE_LAYER_LABELS[type],
   101	      state: status.value?.presets.find((preset) => preset.analysis_type === type)?.state ?? 'missing',
   102	    }))
   103	  );
   104
   105	  async function loadReleases(): Promise<void> {
   106	    try {
   107	      const response = await listAdminReleases();
   108	      releases.value = response.releases;
   109	    } catch (err) {
   110	      actionError.value = extractApiErrorMessage(
   111	        err,
   112	        'Failed to load analysis-snapshot releases.'
   113	      );
   114	    }
   115	  }
   116
   117	  async function loadStatus(): Promise<void> {
   118	    try {
   119	      status.value = await fetchSnapshotStatus();
   120	    } catch (err) {
   121	      actionError.value = extractApiErrorMessage(
   122	        err,
   123	        'Failed to load snapshot readiness status.'
   124	      );
   125	    }
   126	  }
   127
   128	  async function refreshAll(): Promise<void> {
   129	    loading.value = true;
   130	    try {
   131	      await Promise.all([loadReleases(), loadStatus()]);
   132	    } finally {
   133	      loading.value = false;
   134	    }
   135	  }
   136
   137	  async function build(input: BuildReleaseFormInput): Promise<void> {
   138	    buildError.value = null;
   139	    lastBuildOutcome.value = null;
   140	    building.value = true;
   141	    try {
   142	      const { license, ...rest } = input;
   143	      const payload: BuildReleaseRequest = { ...rest, publish: input.publish ?? false };
   144	      // The endpoint only substitutes its "CC-BY-4.0" default on a missing/NULL
   145	      // `license`, not on an empty string — so a cleared license input must omit
   146	      // the key entirely (not forward `""`) for the server default to apply.
   147	      if (license?.trim()) {
   148	        payload.license = license;
   149	      }
   150	      const outcome = await buildRelease(payload);
   151	      lastBuildOutcome.value = outcome;
   152	      if (outcome.outcome === 'created' || outcome.outcome === 'exists') {
   153	        await loadReleases();
   154	      }
   155	    } catch (err) {
   156	      buildError.value = extractApiErrorMessage(
   157	        err,
   158	        'Failed to build the analysis-snapshot release.'
   159	      );
   160	    } finally {
   161	      building.value = false;
   162	    }
   163	  }
   164
   165	  async function publish(releaseId: string): Promise<void> {
   166	    actionError.value = null;
   167	    actionMessage.value = null;
   168	    try {
   169	      const updated = await publishRelease(releaseId);
   170	      actionMessage.value = `Release ${updated.release_id} published.`;
   171	      await loadReleases();
   172	    } catch (err) {
   173	      actionError.value = extractApiErrorMessage(err, 'Failed to publish the release.');
   174	    }
   175	  }
   176
   177	  async function recordDoi(releaseId: string, fields: RecordReleaseDoiFields): Promise<void> {
   178	    actionError.value = null;
   179	    actionMessage.value = null;
   180	    try {
   181	      await recordReleaseDoi(releaseId, nonEmptyDoiFields(fields));
   182	      actionMessage.value = 'DOI metadata recorded.';
   183	      await loadReleases();
   184	    } catch (err) {
   185	      actionError.value = extractApiErrorMessage(err, 'Failed to record DOI metadata.');
   186	    }
   187	  }
   188
   189	  async function deleteDraft(releaseId: string): Promise<void> {
   190	    actionError.value = null;
   191	    actionMessage.value = null;
   192	    try {
   193	      await deleteDraftRelease(releaseId);
   194	      actionMessage.value = 'Draft release deleted.';
   195	      await loadReleases();
   196	    } catch (err) {
   197	      actionError.value = extractApiErrorMessage(err, 'Failed to delete the draft release.');
   198	    }
   199	  }
   200
   201	  return {
   202	    releases,
   203	    status,
   204	    loading,
   205	    buildError,
   206	    building,
   207	    lastBuildOutcome,
   208	    actionError,
   209	    actionMessage,
   210	    canBuild,
   211	    layerReadiness,
   212	    loadReleases,
   213	    loadStatus,
   214	    refreshAll,
   215	    build,
   216	    publish,
   217	    recordDoi,
   218	    deleteDraft,
   219	  };
   220	}
     1	<!-- app/src/views/admin/ManageAnalysisReleases.vue -->
     2	<!--
     3	  Administrator page to build/publish/DOI-tag analysis-snapshot releases
     4	  (#573 Slice B, Task B4b): immutable, content-addressed frozen exports of
     5	  the public-ready analysis snapshots (functional clusters, phenotype
     6	  clusters, phenotype-functional correlation). The build itself is
     7	  SYNCHRONOUS and DB-only — there is no async job/worker involved, so this
     8	  view never polls a job status (contrast ManageNDDScore.vue's import job).
     9
    10	  Kept thin: every client call and reactive state lives in the co-located
    11	  `useAnalysisReleaseAdmin` composable; this file is template + light local
    12	  UI-only state (the build form fields, the per-row DOI form drafts, and the
    13	  two-step "Delete draft" confirm — an in-page affordance, never a blocking
    14	  native `window.confirm`/dialog).
    15	-->
    16	<template>
    17	  <AuthenticatedPageShell
    18	    title="Manage analysis-snapshot releases"
    19	    description="Build, publish, and DOI-tag immutable, content-addressed exports of SysNDD's public-ready analysis snapshots (functional clusters, phenotype clusters, and their correlation). Each release freezes its own copy of the data and survives snapshot pruning or refresh byte-identically."
    20	    content-class="authenticated-route-content"
    21	    full-width
    22	  >
    23	    <BContainer fluid class="analysis-release-admin">
    24	      <AdminOperationPanel
    25	        title="Snapshot readiness"
    26	        description="A release build requires every release layer below to be available from the currently active public-ready snapshots."
    27	        icon="bi-clipboard-data"
    28	        :aria-busy="loading ? 'true' : 'false'"
    29	      >
    30	        <div class="layer-readiness-grid" data-testid="layer-readiness-grid">
    31	          <div
    32	            v-for="item in admin.layerReadiness.value"
    33	            :key="item.analysis_type"
    34	            class="layer-readiness-item"
    35	            :class="{ 'layer-readiness-item--ready': item.state === 'available' }"
    36	            :data-testid="`layer-readiness-${item.analysis_type}`"
    37	          >
    38	            <i
    39	              :class="[
    40	                'bi',
    41	                item.state === 'available' ? 'bi-check-circle-fill' : 'bi-x-circle-fill',
    42	              ]"
    43	              aria-hidden="true"
    44	            />
    45	            <div>
    46	              <strong>{{ item.label }}</strong>
    47	              <span class="layer-readiness-state">{{ item.state }}</span>
    48	            </div>
    49	          </div>
    50	        </div>
    51
    52	        <p v-if="!admin.canBuild.value" class="layer-readiness-hint mb-0">
    53	          Build is disabled until every release layer above reports
    54	          <strong>available</strong>. Snapshots self-heal automatically (stale or missing
    55	          snapshots re-enqueue on the next API restart), or an operator can force a refresh via
    56	          <code>POST /api/admin/analysis/snapshots/refresh</code>.
    57	        </p>
    58	      </AdminOperationPanel>
    59
    60	      <AdminOperationPanel
    61	        title="Build a release"
    62	        description="Freezes the currently active public-ready snapshots into a new immutable release. Building as a draft (the default) lets you review and record a DOI before publishing."
    63	        icon="bi-box-arrow-in-down"
    64	        heading-tag="h2"
    65	        :aria-busy="building ? 'true' : 'false'"
    66	      >
    67	        <BAlert v-if="admin.buildError.value" variant="danger" show class="mb-3" data-testid="build-error">
    68	          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
    69	          {{ admin.buildError.value }}
    70	        </BAlert>
    71
    72	        <BAlert
    73	          v-if="lockedOutcome"
    74	          variant="warning"
    75	          show
    76	          class="mb-3"
    77	          data-testid="build-locked"
    78	        >
    79	          <i class="bi bi-hourglass-split me-1" aria-hidden="true" />
    80	          Snapshot sources are refreshing, retry in {{ lockedOutcome.retryAfter }}s.
    81	          {{ lockedOutcome.message }}
    82	        </BAlert>
    83
    84	        <BAlert
    85	          v-else-if="createdOrExistingOutcome"
    86	          variant="success"
    87	          show
    88	          class="mb-3"
    89	          data-testid="build-success"
    90	        >
    91	          <i class="bi bi-check-circle-fill me-1" aria-hidden="true" />
    92	          Release <strong>{{ createdOrExistingOutcome.release.release_id }}</strong>
    93	          {{ createdOrExistingOutcome.outcome === 'created' ? 'created' : 'already existed (identical content)' }}
    94	          — status <strong>{{ createdOrExistingOutcome.release.status }}</strong>.
    95	        </BAlert>
    96
    97	        <form class="build-form" @submit.prevent="handleBuild">
    98	          <div class="build-form__field">
    99	            <label for="release-title" class="form-label fw-semibold">Title</label>
   100	            <BFormInput id="release-title" v-model="buildForm.title" data-testid="build-title" />
   101	          </div>
   102	          <div class="build-form__field">
   103	            <label for="release-scope" class="form-label fw-semibold">Scope statement</label>
   104	            <BFormTextarea
   105	              id="release-scope"
   106	              v-model="buildForm.scope_statement"
   107	              rows="2"
   108	              data-testid="build-scope"
   109	            />
   110	          </div>
   111	          <div class="build-form__field">
   112	            <label for="release-license" class="form-label fw-semibold">License</label>
   113	            <BFormInput id="release-license" v-model="buildForm.license" data-testid="build-license" />
   114	          </div>
   115	          <div class="build-form__field build-form__field--checkbox form-check">
   116	            <input
   117	              id="release-publish"
   118	              v-model="buildForm.publish"
   119	              class="form-check-input"
   120	              type="checkbox"
   121	              data-testid="build-publish-checkbox"
   122	            />
   123	            <label class="form-check-label" for="release-publish">
   124	              Publish immediately (unchecked builds a draft for review)
   125	            </label>
   126	          </div>
   127	          <BButton
   128	            type="submit"
   129	            variant="primary"
   130	            data-testid="build-release-btn"
   131	            :disabled="!admin.canBuild.value || building"
   132	          >
   133	            <BSpinner v-if="building" small class="me-1" />
   134	            <i v-else class="bi bi-hammer me-1" aria-hidden="true" />
   135	            Build release
   136	          </BButton>
   137	        </form>
   138	      </AdminOperationPanel>
   139
   140	      <AdminOperationPanel
   141	        title="Releases"
   142	        description="All releases, including drafts. Publishing and DOI recording never change a release's content digest."
   143	        icon="bi-archive"
   144	        heading-tag="h2"
   145	        :aria-busy="loading ? 'true' : 'false'"
   146	      >
   147	        <BAlert v-if="admin.actionError.value" variant="danger" show class="mb-3" data-testid="action-error">
   148	          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
   149	          {{ admin.actionError.value }}
   150	        </BAlert>
   151	        <BAlert v-if="admin.actionMessage.value" variant="info" show class="mb-3" data-testid="action-message">
   152	          <i class="bi bi-info-circle-fill me-1" aria-hidden="true" />
   153	          {{ admin.actionMessage.value }}
   154	        </BAlert>
   155
   156	        <GenericTable :items="releaseRows" :fields="RELEASE_ADMIN_TABLE_FIELDS" :is-busy="loading">
   157	          <template #cell-status="{ row }">
   158	            <BBadge :variant="row.status === 'published' ? 'success' : 'secondary'">
   159	              {{ row.status }}
   160	            </BBadge>
   161	          </template>
   162	          <template #cell-actions="{ row, expansionShowing, toggleExpansion }">
   163	            <div class="release-actions">
   164	              <BButton
   165	                v-if="row.status === 'draft'"
   166	                size="sm"
   167	                variant="outline-primary"
   168	                :data-testid="`publish-${row.release_id}`"
   169	                @click="admin.publish(row.release_id)"
   170	              >
   171	                Publish
   172	              </BButton>
   173	              <BButton
   174	                size="sm"
   175	                variant="outline-secondary"
   176	                :data-testid="`toggle-doi-${row.release_id}`"
   177	                @click="toggleExpansion?.()"
   178	              >
   179	                {{ expansionShowing ? 'Hide DOI form' : 'Record DOI' }}
   180	              </BButton>
   181	              <template v-if="row.status === 'draft'">
   182	                <BButton
   183	                  v-if="pendingDeleteId !== row.release_id"
   184	                  size="sm"
   185	                  variant="outline-danger"
   186	                  :data-testid="`delete-${row.release_id}`"
   187	                  @click="pendingDeleteId = row.release_id"
   188	                >
   189	                  Delete draft
   190	                </BButton>
   191	                <template v-else>
   192	                  <BButton
   193	                    size="sm"
   194	                    variant="danger"
   195	                    :data-testid="`confirm-delete-${row.release_id}`"
   196	                    @click="handleConfirmDelete(row.release_id)"
   197	                  >
   198	                    Confirm delete
   199	                  </BButton>
   200	                  <BButton size="sm" variant="outline-secondary" @click="pendingDeleteId = null">
   201	                    Cancel
   202	                  </BButton>
   203	                </template>
   204	              </template>
   205	            </div>
   206	          </template>
   207	          <template #row-expansion="{ row, toggle }">
   208	            <div class="doi-form" :data-testid="`doi-form-${row.release_id}`">
   209	              <div class="doi-form__grid">
   210	                <div class="doi-form__field">
   211	                  <label :for="`doi-version-${row.release_id}`" class="form-label fw-semibold">
   212	                    Version DOI
   213	                  </label>
   214	                  <BFormInput
   215	                    :id="`doi-version-${row.release_id}`"
   216	                    v-model="doiFormFor(row.release_id).version_doi"
   217	                    :data-testid="`doi-version-input-${row.release_id}`"
   218	                  />
   219	                </div>
   220	                <div class="doi-form__field">
   221	                  <label :for="`doi-concept-${row.release_id}`" class="form-label fw-semibold">
   222	                    Concept DOI
   223	                  </label>
   224	                  <BFormInput
   225	                    :id="`doi-concept-${row.release_id}`"
   226	                    v-model="doiFormFor(row.release_id).concept_doi"
   227	                  />
   228	                </div>
   229	                <div class="doi-form__field">
   230	                  <label :for="`doi-zenodo-id-${row.release_id}`" class="form-label fw-semibold">
   231	                    Zenodo record ID
   232	                  </label>
   233	                  <BFormInput
   234	                    :id="`doi-zenodo-id-${row.release_id}`"
   235	                    v-model="doiFormFor(row.release_id).zenodo_record_id"
   236	                  />
   237	                </div>
   238	                <div class="doi-form__field">
   239	                  <label :for="`doi-zenodo-url-${row.release_id}`" class="form-label fw-semibold">
   240	                    Zenodo record URL
   241	                  </label>
   242	                  <BFormInput
   243	                    :id="`doi-zenodo-url-${row.release_id}`"
   244	                    v-model="doiFormFor(row.release_id).zenodo_record_url"
   245	                  />
   246	                </div>
   247	              </div>
   248	              <BButton
   249	                size="sm"
   250	                variant="primary"
   251	                class="mt-2"
   252	                :data-testid="`save-doi-${row.release_id}`"
   253	                @click="handleSaveDoi(row.release_id, toggle)"
   254	              >
   255	                Save DOI
   256	              </BButton>
   257	            </div>
   258	          </template>
   259	        </GenericTable>
   260
   261	        <p v-if="!loading && admin.releases.value.length === 0" class="text-muted small mb-0 mt-2">
   262	          No releases yet.
   263	        </p>
   264	      </AdminOperationPanel>
   265	    </BContainer>
   266	  </AuthenticatedPageShell>
   267	</template>
   268
   269	<script setup lang="ts">
   270	import { computed, onMounted, reactive, ref } from 'vue';
   271	import { useHead } from '@unhead/vue';
   272	import { BAlert, BBadge, BButton, BContainer, BFormInput, BFormTextarea, BSpinner } from 'bootstrap-vue-next';
   273	import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
   274	import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
   275	import GenericTable from '@/components/small/GenericTable.vue';
   276	import type { RecordReleaseDoiFields } from '@/api/admin_analysis_release';
   277	import { useAnalysisReleaseAdmin, type BuildReleaseFormInput } from './useAnalysisReleaseAdmin';
   278
   279	useHead({ title: 'Manage analysis-snapshot releases' });
   280
   281	const RELEASE_ADMIN_TABLE_FIELDS = [
   282	  { key: 'release_id', label: 'Release' },
   283	  { key: 'status', label: 'Status' },
   284	  { key: 'source_data_version', label: 'Source data version' },
   285	  { key: 'created_at', label: 'Created' },
   286	  { key: 'published_at', label: 'Published' },
   287	  { key: 'file_count', label: 'Files' },
   288	  { key: 'version_doi', label: 'Version DOI' },
   289	  { key: 'actions', label: 'Actions' },
   290	];
   291
   292	/**
   293	 * Flat display row for the releases table. `GenericDesktopTable.vue` only
   294	 * wires custom `#cell(<key>)` slots for a fixed, hardcoded set of field keys
   295	 * (`status` and `actions` here, notably NOT `created_at`/`published_at`/
   296	 * `version_doi`) — the same BVN gotcha `dataReleaseTable.ts` documents for
   297	 * the public /DataReleases table. A `field.formatter` silently never runs
   298	 * either, so display formatting (dates, the DOI dash sentinel) is baked
   299	 * into the row here rather than attempted via a cell slot or formatter for
   300	 * an unwired key.
   301	 */
   302	interface AdminReleaseTableRow {
   303	  release_id: string;
   304	  status: string;
   305	  source_data_version: string;
   306	  created_at: string;
   307	  published_at: string;
   308	  file_count: number;
   309	  version_doi: string;
   310	}
   311
   312	const admin = useAnalysisReleaseAdmin();
   313	const { loading, building } = admin;
   314
   315	const releaseRows = computed<AdminReleaseTableRow[]>(() =>
   316	  admin.releases.value.map((release) => ({
   317	    release_id: release.release_id,
   318	    status: release.status,
   319	    source_data_version: release.source_data_version,
   320	    created_at: formatDate(release.created_at),
   321	    published_at: formatDate(release.published_at),
   322	    file_count: release.file_count,
   323	    version_doi: release.version_doi || '—',
   324	  }))
   325	);
   326
   327	const buildForm = reactive<BuildReleaseFormInput>({
   328	  title: '',
   329	  scope_statement: '',
   330	  license: 'CC-BY-4.0',
   331	  // Safe operator flow: build as a draft by default, review, then publish explicitly.
   332	  publish: false,
   333	});
   334
   335	const lockedOutcome = computed(() =>
   336	  admin.lastBuildOutcome.value?.outcome === 'locked' ? admin.lastBuildOutcome.value : null
   337	);
   338	const createdOrExistingOutcome = computed(() => {
   339	  const outcome = admin.lastBuildOutcome.value;
   340	  return outcome && outcome.outcome !== 'locked' ? outcome : null;
   341	});
   342
   343	/** Two-step "Delete draft" confirm state — an in-page affordance, never a native dialog. */
   344	const pendingDeleteId = ref<string | null>(null);
   345
   346	/** Per-row DOI draft form values, lazily created and kept across expand/collapse. */
   347	const doiForms = reactive<Record<string, RecordReleaseDoiFields>>({});
   348	function doiFormFor(releaseId: string): RecordReleaseDoiFields {
   349	  if (!doiForms[releaseId]) {
   350	    doiForms[releaseId] = {
   351	      version_doi: '',
   352	      concept_doi: '',
   353	      zenodo_record_id: '',
   354	      zenodo_record_url: '',
   355	    };
   356	  }
   357	  return doiForms[releaseId];
   358	}
   359
   360	function formatDate(value: string | null | undefined): string {
   361	  if (!value) return '—';
   362	  const parsed = new Date(value);
   363	  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleString();
   364	}
   365
   366	async function handleBuild(): Promise<void> {
   367	  await admin.build({ ...buildForm });
   368	}
   369
   370	async function handleConfirmDelete(releaseId: string): Promise<void> {
   371	  await admin.deleteDraft(releaseId);
   372	  pendingDeleteId.value = null;
   373	}
   374
   375	async function handleSaveDoi(releaseId: string, toggle: () => void): Promise<void> {
   376	  await admin.recordDoi(releaseId, { ...doiFormFor(releaseId) });
   377	  if (!admin.actionError.value) {
   378	    toggle();
   379	  }
   380	}
   381
   382	onMounted(() => {
   383	  void admin.refreshAll();
   384	});
   385	</script>
   386
   387	<style scoped>
   388	.analysis-release-admin {
   389	  padding: 0;
   390	}
   391
   392	.layer-readiness-grid {
   393	  display: grid;
   394	  grid-template-columns: repeat(3, minmax(0, 1fr));
   395	  gap: 0.75rem;
   396	}
   397
   398	.layer-readiness-item {
   399	  display: flex;
   400	  align-items: center;
   401	  gap: 0.6rem;
   402	  padding: 0.625rem 0.75rem;
   403	  border: 1px solid rgba(198, 40, 40, 0.28);
   404	  border-radius: var(--radius-md, 0.375rem);
   405	  background: #fff5f5;
   406	  color: var(--status-danger, #c62828);
   407	}
   408
   409	.layer-readiness-item--ready {
   410	  border-color: rgba(46, 125, 50, 0.28);
   411	  background: #f3fbf4;
   412	  color: var(--status-success, #2e7d32);
   413	}
   414
   415	.layer-readiness-item strong {
   416	  display: block;
   417	  color: var(--neutral-900, #212121);
   418	  font-size: 0.875rem;
   419	}
   420
   421	.layer-readiness-state {
   422	  display: block;
   423	  font-size: 0.75rem;
   424	  text-transform: capitalize;
   425	}
   426
   427	.layer-readiness-hint {
   428	  margin-top: 0.85rem;
   429	  color: var(--neutral-600, #757575);
   430	  font-size: 0.8125rem;
   431	}
   432
   433	.layer-readiness-hint code {
   434	  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
   435	  font-size: 0.8em;
   436	}
   437
   438	.build-form {
   439	  display: grid;
   440	  gap: 0.85rem;
   441	  max-width: 32rem;
   442	}
   443
   444	.build-form__field--checkbox {
   445	  display: flex;
   446	  align-items: center;
   447	  gap: 0.5rem;
   448	}
   449
   450	.release-actions {
   451	  display: flex;
   452	  flex-wrap: wrap;
   453	  gap: 0.4rem;
   454	  justify-content: flex-end;
   455	}
   456
   457	.doi-form {
   458	  padding: 0.75rem;
   459	  border: 1px solid rgba(15, 23, 42, 0.08);
   460	  border-radius: var(--radius-md, 0.375rem);
   461	  background: #f8fafc;
   462	}
   463
   464	.doi-form__grid {
   465	  display: grid;
   466	  grid-template-columns: repeat(2, minmax(0, 1fr));
   467	  gap: 0.75rem;
   468	}
   469
   470	@media (max-width: 767.98px) {
   471	  .layer-readiness-grid {
   472	    grid-template-columns: 1fr;
   473	  }
   474
   475	  .doi-form__grid {
   476	    grid-template-columns: 1fr;
   477	  }
   478	}
   479	</style>
     1	// src/components/analyses/dataReleaseTable.ts
     2	//
     3	// Pure client-side table transform for the public /DataReleases page (#573
     4	// Slice B, Task B2). Flattens the release LIST envelope (`ReleaseHead[]`)
     5	// into flat rows for the `GenericTable` wrapper.
     6	//
     7	// Mirrors the dotted-key-flatten pattern of `normalizePhenotypeClusterRows()`
     8	// in `phenotypeClusterTable.ts`: BootstrapVueNext's BTable renders a BLANK
     9	// cell for any field key containing a dot (see the AGENTS.md BVN gotcha), and
    10	// the release head's `zenodo` sub-object would otherwise force dotted access
    11	// (`zenodo.version_doi`) that can't be bound as a flat field key. There is no
    12	// dotted source key here (unlike the MCA stats), but the same flatten
    13	// discipline applies to the nested `zenodo` object.
    14	//
    15	// Display-string formatting (byte size, the DOI "not assigned" sentinel) is
    16	// baked directly into the row here rather than via a BTable `field.formatter`
    17	// — `GenericDesktopTable.vue` only exposes custom cell slots for a fixed,
    18	// hardcoded set of field keys (none of which are the release columns), so a
    19	// per-field formatter would silently never run. Pre-formatting the row is
    20	// the same convention already used for `ndd_score`/`percentile` in the
    21	// NDDScore gene table.
    22
    23	import type { ReleaseHead } from '@/api/analysis_releases';
    24
    25	/** `GenericTable` fields config entry (flat keys only — see file header). */
    26	export interface ReleaseTableField {
    27	  key: string;
    28	  label: string;
    29	  sortable?: boolean;
    30	}
    31
    32	/** Flat table row for one release (LIST route head — no manifest). */
    33	export interface ReleaseTableRow {
    34	  release_id: string;
    35	  /** `title`, falling back to `release_id` when the reserved `title` column is null. */
    36	  title: string;
    37	  status: string;
    38	  /** `published_at`, falling back to `created_at` when not yet published-dated. */
    39	  published_at: string;
    40	  source_data_version: string;
    41	  file_count: number;
    42	  total_bytes: number;
    43	  /** Human-readable `total_bytes` (e.g. "1.2 MB"), via `formatReleaseBytes()`. */
    44	  total_bytes_display: string;
    45	  license: string;
    46	  /** Flattened `zenodo.version_doi`; the DOI_UNASSIGNED sentinel when null. */
    47	  zenodo_version_doi: string;
    48	  /** Flattened `zenodo.concept_doi`; the DOI_UNASSIGNED sentinel when null. */
    49	  zenodo_concept_doi: string;
    50	  /** Flattened `zenodo.record_url`; the DOI_UNASSIGNED sentinel when null. */
    51	  zenodo_record_url: string;
    52	}
    53
    54	const BYTE_UNITS = ['B', 'KB', 'MB', 'GB', 'TB'] as const;
    55
    56	/** Sentinel shown for a `zenodo` field that has not been recorded yet (#573 DOI is additive). */
    57	export const DOI_UNASSIGNED = '—';
    58
    59	/**
    60	 * Human-readable byte size (e.g. "1.2 MB", "512 B", "1.5 KB"). Non-finite
    61	 * (`NaN`/`Infinity`) and non-positive input degrade to "0 B" rather than
    62	 * rendering "NaN" or indexing past the unit table.
    63	 */
    64	export function formatReleaseBytes(bytes: number): string {
    65	  if (!Number.isFinite(bytes) || bytes <= 0) {
    66	    return '0 B';
    67	  }
    68	  const exponent = Math.min(
    69	    Math.floor(Math.log(bytes) / Math.log(1024)),
    70	    BYTE_UNITS.length - 1
    71	  );
    72	  const value = parseFloat((bytes / 1024 ** exponent).toFixed(1));
    73	  return `${value} ${BYTE_UNITS[exponent]}`;
    74	}
    75
    76	/** Flattens a possibly-null zenodo field to a display string. */
    77	function doiOrDash(value: string | null | undefined): string {
    78	  return value ? value : DOI_UNASSIGNED;
    79	}
    80
    81	/**
    82	 * `GenericTable` fields config for the releases list. Columns: Release,
    83	 * Published, Source data version, Files, Size, License, Version DOI, plus a
    84	 * `Manifest` actions column (row selection — see
    85	 * `views/analyses/DataReleases.vue`). No `Version` column: `release_version`
    86	 * is a reserved, currently-unpopulated string column (always `null` today),
    87	 * so displaying it would be pure noise. No column is wired to client-side
    88	 * sorting (the LIST route already returns newest-first); `sortable` is kept
    89	 * optional on the type so a future column can opt in without a shape change.
    90	 */
    91	export const RELEASE_TABLE_FIELDS: ReleaseTableField[] = [
    92	  { key: 'release_id', label: 'Release' },
    93	  { key: 'published_at', label: 'Published' },
    94	  { key: 'source_data_version', label: 'Source data version' },
    95	  { key: 'file_count', label: 'Files' },
    96	  { key: 'total_bytes_display', label: 'Size' },
    97	  { key: 'license', label: 'License' },
    98	  { key: 'zenodo_version_doi', label: 'Version DOI' },
    99	  { key: 'actions', label: 'Manifest' },
   100	];
   101
   102	/**
   103	 * Flattens the public LIST envelope's release heads into `GenericTable` rows.
   104	 * Returns a new array; input heads are not mutated. Tolerates null/undefined
   105	 * input (renders as an empty table rather than throwing).
   106	 */
   107	export function normalizeReleaseRows(
   108	  releases: ReleaseHead[] | null | undefined
   109	): ReleaseTableRow[] {
   110	  return (releases || []).map((release) => ({
   111	    release_id: release.release_id,
   112	    title: release.title || release.release_id,
   113	    status: release.status,
   114	    published_at: release.published_at || release.created_at,
   115	    source_data_version: release.source_data_version,
   116	    file_count: release.file_count,
   117	    total_bytes: release.total_bytes,
   118	    total_bytes_display: formatReleaseBytes(release.total_bytes),
   119	    license: release.license,
   120	    zenodo_version_doi: doiOrDash(release.zenodo?.version_doi),
   121	    zenodo_concept_doi: doiOrDash(release.zenodo?.concept_doi),
   122	    zenodo_record_url: doiOrDash(release.zenodo?.record_url),
   123	  }));
   124	}
     1	// src/router/routes.ts
     2
     3	import type { RouteRecordRaw, RouteLocationNormalized } from 'vue-router';
     4	import {
     5	  createAuthGuard,
     6	  lazyRouteComponent,
     7	  nddScoreComponents,
     8	  adminViews,
     9	} from './guards';
    10
    11	// Most admin views are simple Administrator-guarded, sitemap-ignored routes
    12	// that differ only by name. Generating them keeps routes.ts DRY (and under the
    13	// file-size ratchet) while preserving the exact per-route shape tests assert.
    14	const simpleAdminRoute = (name: string): RouteRecordRaw => ({
    15	  path: `/${name}`,
    16	  name,
    17	  component: lazyRouteComponent(adminViews, `../views/admin/${name}.vue`),
    18	  meta: { sitemap: { ignoreRoute: true } },
    19	  beforeEnter: createAuthGuard(['Administrator']),
    20	});
    21
    22	export const routes: RouteRecordRaw[] = [
    23	  {
    24	    path: '/',
    25	    name: 'Home',
    26	    component: () => import('@/views/HomeView.vue'),
    27	    meta: {
    28	      sitemap: {
    29	        priority: 1.0,
    30	        changefreq: 'monthly',
    31	      },
    32	    },
    33	  },
    34	  {
    35	    path: '/Entities',
    36	    name: 'Entities',
    37	    component: () => import('@/views/tables/EntitiesTable.vue'),
    38	    props: (route) => ({
    39	      sort: route.query.sort || undefined,
    40	      filter: route.query.filter || undefined,
    41	      fields: route.query.fields || undefined,
    42	      pageAfter: route.query.page_after || undefined,
    43	      pageSize: route.query.page_size || undefined,
    44	      fspec: route.query.fspec || undefined,
    45	    }),
    46	    meta: {
    47	      sitemap: {
    48	        priority: 0.9,
    49	        changefreq: 'monthly',
    50	      },
    51	    },
    52	  },
    53	  {
    54	    path: '/Genes',
    55	    name: 'Genes',
    56	    component: () => import('@/views/tables/GenesTable.vue'),
    57	    props: (route) => ({
    58	      sort: route.query.sort || undefined,
    59	      filter: route.query.filter || undefined,
    60	      fields: route.query.fields || undefined,
    61	      pageAfter: route.query.page_after || undefined,
    62	      pageSize: route.query.page_size || undefined,
    63	      fspec: route.query.fspec || undefined,
    64	    }),
    65	    meta: {
    66	      sitemap: {
    67	        priority: 0.9,
    68	        changefreq: 'monthly',
    69	      },
    70	    },
    71	  },
    72	  {
    73	    path: '/Phenotypes',
    74	    name: 'Phenotypes',
    75	    component: () => import('@/views/tables/PhenotypesTable.vue'),
    76	    props: (route) => ({
    77	      sort: route.query.sort || undefined,
    78	      filter: route.query.filter || undefined,
    79	      fields: route.query.fields || undefined,
    80	      pageAfter: route.query.page_after || undefined,
    81	      pageSize: route.query.page_size || undefined,
    82	      fspec: route.query.fspec || undefined,
    83	    }),
    84	    meta: {
    85	      sitemap: {
    86	        priority: 0.9,
    87	        changefreq: 'monthly',
    88	      },
    89	    },
    90	  },
    91	  {
    92	    path: '/CurationComparisons',
    93	    component: () => import('@/views/analyses/CurationComparisons.vue'),
    94	    children: [
    95	      {
    96	        path: '',
    97	        component: () => import('@/components/analyses/AnalysesCurationUpset.vue'),
    98	        name: 'CurationComparisons',
    99	      },
   100	      {
   101	        path: 'Similarity',
   102	        name: 'CurationComparisonsSimilarity',
   103	        component: () => import('@/components/analyses/AnalysesCurationMatrixPlot.vue'),
   104	      },
   105	      {
   106	        path: 'Table',
   107	        name: 'CurationComparisonsTable',
   108	        component: () => import('@/components/analyses/AnalysesCurationComparisonsTable.vue'),
   109	      },
   110	    ],
   111	    meta: {
   112	      sitemap: {
   113	        priority: 0.8,
   114	        changefreq: 'monthly',
   115	      },
   116	    },
   117	  },
   118	  {
   119	    path: '/PhenotypeCorrelations',
   120	    component: () => import('@/views/analyses/PhenotypeCorrelations.vue'),
   121	    children: [
   122	      {
   123	        path: '',
   124	        component: () => import('@/components/analyses/AnalysesPhenotypeCorrelogram.vue'),
   125	        name: 'PhenotypeCorrelations',
   126	      },
   127	      {
   128	        path: 'PhenotypeCounts',
   129	        component: () => import('@/components/analyses/AnalysesPhenotypeCounts.vue'),
   130	      },
   131	      {
   132	        path: 'PhenotypeClusters',
   133	        component: () => import('@/components/analyses/AnalysesPhenotypeClusters.vue'),
   134	      },
   135	    ],
   136	    meta: {
   137	      sitemap: {
   138	        priority: 0.7,
   139	        changefreq: 'monthly',
   140	      },
   141	    },
   142	  },
   143	  // ─────────────────────────────────────────────────────────────────────────────
   144	  // UNIFIED ANALYSIS VIEW (Combines Phenotype Clusters, Gene Networks, Correlation)
   145	  // ─────────────────────────────────────────────────────────────────────────────
   146	  {
   147	    path: '/Analysis',
   148	    name: 'Analysis',
   149	    component: () => import('@/views/AnalysisView.vue'),
   150	    meta: {
   151	      sitemap: {
   152	        priority: 0.8,
   153	        changefreq: 'monthly',
   154	      },
   155	    },
   156	  },
   157	  // ─────────────────────────────────────────────────────────────────────────────
   158	  // NEW ROUTE FOR PHENO-FUNC CORRELATION
   159	  // ─────────────────────────────────────────────────────────────────────────────
   160	  {
   161	    path: '/PhenotypeFunctionalCorrelation',
   162	    name: 'PhenotypeFunctionalCorrelation',
   163	    component: () => import('@/views/analyses/PhenotypeFunctionalCorrelation.vue'),
   164	    meta: {
   165	      sitemap: {
   166	        priority: 0.8,
   167	        changefreq: 'monthly',
   168	      },
   169	    },
   170	  },
   171	  // ─────────────────────────────────────────────────────────────────────────────
   172	  {
   173	    path: '/VariantCorrelations',
   174	    component: () => import('@/views/analyses/VariantCorrelations.vue'),
   175	    children: [
   176	      {
   177	        path: '',
   178	        component: () => import('@/components/analyses/AnalysesVariantCorrelogram.vue'),
   179	        name: 'VariantCorrelations',
   180	      },
   181	      {
   182	        path: 'VariantCounts',
   183	        component: () => import('@/components/analyses/AnalysesVariantCounts.vue'),
   184	      },
   185	    ],
   186	    meta: {
   187	      sitemap: {
   188	        priority: 0.7,
   189	        changefreq: 'monthly',
   190	      },
   191	    },
   192	  },
   193	  {
   194	    path: '/EntriesOverTime',
   195	    name: 'EntriesOverTime',
   196	    component: () => import('@/views/analyses/EntriesOverTime.vue'),
   197	    meta: {
   198	      sitemap: {
   199	        priority: 0.7,
   200	        changefreq: 'monthly',
   201	      },
   202	    },
   203	  },
   204	  {
   205	    path: '/PublicationsNDD',
   206	    component: () => import('@/views/analyses/PublicationsNDD.vue'),
   207	    children: [
   208	      // 1) The "All" publications table from DB
   209	      {
   210	        path: '',
   211	        name: 'PublicationsNDDTable',
   212	        component: () => import('@/components/analyses/PublicationsNDDTable.vue'),
   213	        props: (route) => ({
   214	          sortInput: route.query.sort || '+publication_id',
   215	          filterInput: route.query.filter || null,
   216	          fieldsInput: route.query.fields || null,
   217	          pageAfterInput: route.query.page_after || '0',
   218	          pageSizeInput: Number(route.query.page_size) || 10,
   219	        }),
   220	      },
     1	// main_nav_constants.ts
     2
     3	/**
     4	 * Constants for main navigation elements.
     5	 */
     6
     7	/** Navigation menu item with optional path or action */
     8	export interface NavMenuItem {
     9	  /** Display text for the menu item */
    10	  text: string;
    11	  /** Navigation path (for route links) */
    12	  path?: string;
    13	  /** Action method name (for function calls) */
    14	  action?: string;
    15	  /** Bootstrap icons to display */
    16	  icons?: string[];
    17	  /** Component to render alongside the item */
    18	  component?: string;
    19	}
    20
    21	/** Dropdown menu configuration */
    22	export interface NavDropdown {
    23	  /** Unique identifier for the dropdown */
    24	  id: string;
    25	  /** Title displayed in the navbar */
    26	  title: string;
    27	  /** Required permissions to view this dropdown */
    28	  required: string[];
    29	  /** Dropdown alignment */
    30	  align: 'left' | 'right';
    31	  /** Menu items in the dropdown */
    32	  items: NavMenuItem[];
    33	}
    34
    35	/**
    36	 * Main navigation configuration
    37	 */
    38	const MAIN_NAV = {
    39	  /**
    40	   * Left-aligned dropdown menus (public sections)
    41	   */
    42	  DROPDOWN_ITEMS_LEFT: [
    43	    {
    44	      id: 'tables_dropdown',
    45	      title: 'Tables',
    46	      required: [''],
    47	      align: 'left',
    48	      items: [
    49	        { text: 'Entities', path: '/Entities' },
    50	        { text: 'Genes', path: '/Genes' },
    51	        { text: 'Phenotypes', path: '/Phenotypes' },
    52	        { text: 'Panels', path: '/Panels' },
    53	      ],
    54	    },
    55	    {
    56	      id: 'analyses_dropdown',
    57	      title: 'Analyses',
    58	      required: [''],
    59	      align: 'left',
    60	      items: [
    61	        { text: 'Compare curations', path: '/CurationComparisons' },
    62	        { text: 'Curation matrix', path: '/CurationComparisons/Similarity' },
    63	        { text: 'Correlate phenotypes', path: '/PhenotypeCorrelations' },
    64	        { text: 'Correlate variants', path: '/VariantCorrelations' },
    65	        { text: 'Entries over time', path: '/EntriesOverTime' },
    66	        { text: 'NDD Publications', path: '/PublicationsNDD' },
    67	        { text: 'PubTator Analysis', path: '/PubtatorNDD' },
    68	        { text: 'Functional clusters', path: '/GeneNetworks' },
    69	        { text: 'Data releases', path: '/DataReleases' },
    70	        { text: 'Phenotype–function correlation', path: '/PhenotypeFunctionalCorrelation' },
    71	      ],
    72	    },
    73	    {
    74	      id: 'ndd_score_dropdown',
    75	      title: 'NDDScore',
    76	      required: [''],
    77	      align: 'left',
    78	      items: [
    79	        { text: 'Gene predictions', path: '/NDDScore', icons: ['cpu', 'list-ol'] },
    80	        { text: 'Model card', path: '/NDDScore/ModelCard', icons: ['cpu', 'card-text'] },
    81	      ],
    82	    },
    83	    {
    84	      id: 'help_dropdown',
    85	      title: 'Help',
    86	      required: [''],
    87	      align: 'left',
    88	      items: [
    89	        { text: 'About', path: '/About' },
    90	        { text: 'Docs and FAQ', path: '/Documentation' },
    91	        { text: 'MCP', path: '/mcp', icons: ['hdd-network'] },
    92	      ],
    93	    },
    94	  ] satisfies NavDropdown[],
    95
    96	  /**
    97	   * Right-aligned dropdown menus (role-based sections)
    98	   */
    99	  DROPDOWN_ITEMS_RIGHT: [
   100	    {
   101	      id: 'administration_dropdown',
   102	      title: 'Administration',
   103	      required: ['admin'],
   104	      align: 'right',
   105	      items: [
   106	        { text: 'Manage user', path: '/ManageUser', icons: ['gear', 'person-circle'] },
   107	        { text: 'Manage annotations', path: '/ManageAnnotations', icons: ['gear', 'table'] },
   108	        { text: 'Manage ontology', path: '/ManageOntology', icons: ['gear', 'list-nested'] },
   109	        { text: 'Manage about', path: '/ManageAbout', icons: ['gear', 'question-circle-fill'] },
   110	        {
   111	          text: 'Admin statistics',
   112	          path: '/AdminStatistics',
   113	          icons: ['bar-chart-line', 'clipboard-check'],
   114	        },
   115	        { text: 'View logs', path: '/ViewLogs', icons: ['eye', 'clipboard-plus'] },
   116	        { text: 'Manage backups', path: '/ManageBackups', icons: ['gear', 'database'] },
   117	        { text: 'Manage PubTator', path: '/ManagePubtator', icons: ['gear', 'journal-medical'] },
   118	        { text: 'LLM Management', path: '/ManageLLM', icons: ['gear', 'robot'] },
   119	        { text: 'Manage NDDScore', path: '/ManageNDDScore', icons: ['gear', 'graph-up-arrow'] },
   120	        {
   121	          text: 'Manage releases',
   122	          path: '/ManageAnalysisReleases',
   123	          icons: ['gear', 'archive'],
   124	        },
   125	        { text: 'Manage metadata', path: '/ManageMetadata', icons: ['gear', 'list-check'] },
   126	        {
   127	          text: 'Manage ontology mappings',
   128	          path: '/ManageOntologyMappings',
   129	          icons: ['gear', 'diagram-3'],
   130	        },
   131	      ],
   132	    },
   133	    {
   134	      id: 'curation_dropdown',
   135	      title: 'Curation',
   136	      required: ['curate'],
   137	      align: 'right',
   138	      items: [
   139	        { text: 'Create entity', path: '/CreateEntity', icons: ['plus-square', 'link'] },
   140	        { text: 'Modify entity', path: '/ModifyEntity', icons: ['pen', 'link'] },
   141	        { text: 'Approve review', path: '/ApproveReview', icons: ['check', 'clipboard-plus'] },
   142	        { text: 'Approve status', path: '/ApproveStatus', icons: ['check', 'stoplights'] },
   143	        { text: 'Approve user', path: '/ApproveUser', icons: ['check', 'person-circle'] },
   144	        { text: 'Manage re-review', path: '/ManageReReview', icons: ['gear', 'clipboard-check'] },
   145	        { text: 'GeneReviews coverage', path: '/GeneReviews', icons: ['journal-medical', 'link'] },
   146	      ],
   147	    },
   148	    {
   149	      id: 'review_dropdown',
   150	      title: 'Review',
   151	      required: ['review'],
   152	      align: 'right',
   153	      items: [
   154	        { text: 'Instructions', path: '/ReviewInstructions', icons: ['check', 'book-fill'] },
   155	        { text: 'Re-Review', path: '/Review', icons: ['pen', 'clipboard-plus'] },
   156	      ],
   157	    },
   158	    {
   159	      id: 'user_dropdown',
   160	      title: 'User',

exec
/bin/bash -lc "nl -ba app/src/views/admin/ManageAnalysisReleases.vue | sed -n '300,540p'; rg -n -C 3 'DataReleases|ManageAnalysisReleases' app/src/router/routes.ts; nl -ba app/src/components/analyses/dataReleaseTable.spec.ts; nl -ba app/src/api/admin_analysis_release.spec.ts" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
   300	 * an unwired key.
   301	 */
   302	interface AdminReleaseTableRow {
   303	  release_id: string;
   304	  status: string;
   305	  source_data_version: string;
   306	  created_at: string;
   307	  published_at: string;
   308	  file_count: number;
   309	  version_doi: string;
   310	}
   311
   312	const admin = useAnalysisReleaseAdmin();
   313	const { loading, building } = admin;
   314
   315	const releaseRows = computed<AdminReleaseTableRow[]>(() =>
   316	  admin.releases.value.map((release) => ({
   317	    release_id: release.release_id,
   318	    status: release.status,
   319	    source_data_version: release.source_data_version,
   320	    created_at: formatDate(release.created_at),
   321	    published_at: formatDate(release.published_at),
   322	    file_count: release.file_count,
   323	    version_doi: release.version_doi || '—',
   324	  }))
   325	);
   326
   327	const buildForm = reactive<BuildReleaseFormInput>({
   328	  title: '',
   329	  scope_statement: '',
   330	  license: 'CC-BY-4.0',
   331	  // Safe operator flow: build as a draft by default, review, then publish explicitly.
   332	  publish: false,
   333	});
   334
   335	const lockedOutcome = computed(() =>
   336	  admin.lastBuildOutcome.value?.outcome === 'locked' ? admin.lastBuildOutcome.value : null
   337	);
   338	const createdOrExistingOutcome = computed(() => {
   339	  const outcome = admin.lastBuildOutcome.value;
   340	  return outcome && outcome.outcome !== 'locked' ? outcome : null;
   341	});
   342
   343	/** Two-step "Delete draft" confirm state — an in-page affordance, never a native dialog. */
   344	const pendingDeleteId = ref<string | null>(null);
   345
   346	/** Per-row DOI draft form values, lazily created and kept across expand/collapse. */
   347	const doiForms = reactive<Record<string, RecordReleaseDoiFields>>({});
   348	function doiFormFor(releaseId: string): RecordReleaseDoiFields {
   349	  if (!doiForms[releaseId]) {
   350	    doiForms[releaseId] = {
   351	      version_doi: '',
   352	      concept_doi: '',
   353	      zenodo_record_id: '',
   354	      zenodo_record_url: '',
   355	    };
   356	  }
   357	  return doiForms[releaseId];
   358	}
   359
   360	function formatDate(value: string | null | undefined): string {
   361	  if (!value) return '—';
   362	  const parsed = new Date(value);
   363	  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleString();
   364	}
   365
   366	async function handleBuild(): Promise<void> {
   367	  await admin.build({ ...buildForm });
   368	}
   369
   370	async function handleConfirmDelete(releaseId: string): Promise<void> {
   371	  await admin.deleteDraft(releaseId);
   372	  pendingDeleteId.value = null;
   373	}
   374
   375	async function handleSaveDoi(releaseId: string, toggle: () => void): Promise<void> {
   376	  await admin.recordDoi(releaseId, { ...doiFormFor(releaseId) });
   377	  if (!admin.actionError.value) {
   378	    toggle();
   379	  }
   380	}
   381
   382	onMounted(() => {
   383	  void admin.refreshAll();
   384	});
   385	</script>
   386
   387	<style scoped>
   388	.analysis-release-admin {
   389	  padding: 0;
   390	}
   391
   392	.layer-readiness-grid {
   393	  display: grid;
   394	  grid-template-columns: repeat(3, minmax(0, 1fr));
   395	  gap: 0.75rem;
   396	}
   397
   398	.layer-readiness-item {
   399	  display: flex;
   400	  align-items: center;
   401	  gap: 0.6rem;
   402	  padding: 0.625rem 0.75rem;
   403	  border: 1px solid rgba(198, 40, 40, 0.28);
   404	  border-radius: var(--radius-md, 0.375rem);
   405	  background: #fff5f5;
   406	  color: var(--status-danger, #c62828);
   407	}
   408
   409	.layer-readiness-item--ready {
   410	  border-color: rgba(46, 125, 50, 0.28);
   411	  background: #f3fbf4;
   412	  color: var(--status-success, #2e7d32);
   413	}
   414
   415	.layer-readiness-item strong {
   416	  display: block;
   417	  color: var(--neutral-900, #212121);
   418	  font-size: 0.875rem;
   419	}
   420
   421	.layer-readiness-state {
   422	  display: block;
   423	  font-size: 0.75rem;
   424	  text-transform: capitalize;
   425	}
   426
   427	.layer-readiness-hint {
   428	  margin-top: 0.85rem;
   429	  color: var(--neutral-600, #757575);
   430	  font-size: 0.8125rem;
   431	}
   432
   433	.layer-readiness-hint code {
   434	  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
   435	  font-size: 0.8em;
   436	}
   437
   438	.build-form {
   439	  display: grid;
   440	  gap: 0.85rem;
   441	  max-width: 32rem;
   442	}
   443
   444	.build-form__field--checkbox {
   445	  display: flex;
   446	  align-items: center;
   447	  gap: 0.5rem;
   448	}
   449
   450	.release-actions {
   451	  display: flex;
   452	  flex-wrap: wrap;
   453	  gap: 0.4rem;
   454	  justify-content: flex-end;
   455	}
   456
   457	.doi-form {
   458	  padding: 0.75rem;
   459	  border: 1px solid rgba(15, 23, 42, 0.08);
   460	  border-radius: var(--radius-md, 0.375rem);
   461	  background: #f8fafc;
   462	}
   463
   464	.doi-form__grid {
   465	  display: grid;
   466	  grid-template-columns: repeat(2, minmax(0, 1fr));
   467	  gap: 0.75rem;
   468	}
   469
   470	@media (max-width: 767.98px) {
   471	  .layer-readiness-grid {
   472	    grid-template-columns: 1fr;
   473	  }
   474
   475	  .doi-form__grid {
   476	    grid-template-columns: 1fr;
   477	  }
   478	}
   479	</style>
275-    },
276-  },
277-  {
278:    path: '/DataReleases',
279:    name: 'DataReleases',
280:    component: () => import('@/views/analyses/DataReleases.vue'),
281-    meta: {
282-      sitemap: {
283-        priority: 0.7,
--
501-    'ManageNDDScore',
502-    'ManageMetadata',
503-    'ManageOntologyMappings',
504:    'ManageAnalysisReleases',
505-  ].map(simpleAdminRoute),
506-  {
507-    path: '/Entities/:entity_id',
     1	import { describe, it, expect } from 'vitest';
     2	import {
     3	  formatReleaseBytes,
     4	  normalizeReleaseRows,
     5	  RELEASE_TABLE_FIELDS,
     6	  DOI_UNASSIGNED,
     7	} from './dataReleaseTable';
     8	import type { ReleaseHead } from '@/api/analysis_releases';
     9
    10	function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
    11	  return {
    12	    release_id: 'asr_0123456789abcdef',
    13	    release_version: null,
    14	    title: 'SysNDD analysis-snapshot release',
    15	    status: 'published',
    16	    content_digest: 'a'.repeat(64),
    17	    created_at: '2026-07-01T00:00:00Z',
    18	    published_at: '2026-07-01T00:05:00Z',
    19	    source_data_version: '2026-07-01',
    20	    db_release_version: '11.4.0',
    21	    db_release_commit: 'deadbeef',
    22	    manifest_sha256: 'b'.repeat(64),
    23	    bundle_sha256: 'c'.repeat(64),
    24	    license: 'CC-BY-4.0',
    25	    file_count: 10,
    26	    total_bytes: 1258291,
    27	    zenodo: { record_url: null, version_doi: null, concept_doi: null },
    28	    ...overrides,
    29	  };
    30	}
    31
    32	describe('formatReleaseBytes', () => {
    33	  it('formats a sub-KB byte count without a decimal', () => {
    34	    expect(formatReleaseBytes(500)).toBe('500 B');
    35	  });
    36
    37	  it('formats a KB boundary', () => {
    38	    expect(formatReleaseBytes(1536)).toBe('1.5 KB');
    39	  });
    40
    41	  it('formats an MB value', () => {
    42	    expect(formatReleaseBytes(1258291)).toBe('1.2 MB');
    43	  });
    44
    45	  it('guards the zero boundary', () => {
    46	    expect(formatReleaseBytes(0)).toBe('0 B');
    47	  });
    48
    49	  it('guards negative input', () => {
    50	    expect(formatReleaseBytes(-5)).toBe('0 B');
    51	  });
    52
    53	  it('guards non-finite input (NaN, Infinity)', () => {
    54	    expect(formatReleaseBytes(NaN)).toBe('0 B');
    55	    expect(formatReleaseBytes(Infinity)).toBe('0 B');
    56	    expect(formatReleaseBytes(-Infinity)).toBe('0 B');
    57	  });
    58	});
    59
    60	describe('RELEASE_TABLE_FIELDS', () => {
    61	  it('uses only flat keys (no dots — the BVN BTable trap)', () => {
    62	    for (const field of RELEASE_TABLE_FIELDS) {
    63	      expect(field.key).not.toContain('.');
    64	    }
    65	  });
    66
    67	  it('surfaces the documented release columns (no Version column — release_version is always null)', () => {
    68	    const keys = RELEASE_TABLE_FIELDS.map((f) => f.key);
    69	    expect(keys).toEqual([
    70	      'release_id',
    71	      'published_at',
    72	      'source_data_version',
    73	      'file_count',
    74	      'total_bytes_display',
    75	      'license',
    76	      'zenodo_version_doi',
    77	      'actions',
    78	    ]);
    79	    expect(keys).not.toContain('release_version');
    80	  });
    81	});
    82
    83	describe('normalizeReleaseRows', () => {
    84	  it('flattens zenodo.* into flat zenodo_* keys with no dotted keys', () => {
    85	    const rows = normalizeReleaseRows([
    86	      makeReleaseHead({
    87	        zenodo: {
    88	          record_url: 'https://zenodo.org/records/1234',
    89	          version_doi: '10.5281/zenodo.1234',
    90	          concept_doi: '10.5281/zenodo.1233',
    91	        },
    92	      }),
    93	    ]);
    94	    expect(rows).toHaveLength(1);
    95	    const row = rows[0] as unknown as Record<string, unknown>;
    96	    expect(row.zenodo_version_doi).toBe('10.5281/zenodo.1234');
    97	    expect(row.zenodo_concept_doi).toBe('10.5281/zenodo.1233');
    98	    expect(row.zenodo_record_url).toBe('https://zenodo.org/records/1234');
    99	    expect(Object.keys(row).some((key) => key.includes('.'))).toBe(false);
   100	  });
   101
   102	  it('formats total_bytes_display via formatReleaseBytes', () => {
   103	    const rows = normalizeReleaseRows([makeReleaseHead({ total_bytes: 1258291 })]);
   104	    expect(rows[0].total_bytes_display).toBe('1.2 MB');
   105	    expect(rows[0].total_bytes).toBe(1258291);
   106	  });
   107
   108	  it('maps a null zenodo.version_doi to the DOI_UNASSIGNED sentinel', () => {
   109	    const rows = normalizeReleaseRows([
   110	      makeReleaseHead({ zenodo: { record_url: null, version_doi: null, concept_doi: null } }),
   111	    ]);
   112	    expect(rows[0].zenodo_version_doi).toBe(DOI_UNASSIGNED);
   113	    expect(rows[0].zenodo_concept_doi).toBe(DOI_UNASSIGNED);
   114	    expect(rows[0].zenodo_record_url).toBe(DOI_UNASSIGNED);
   115	  });
   116
   117	  it('falls back to created_at when published_at is null', () => {
   118	    const rows = normalizeReleaseRows([
   119	      makeReleaseHead({ published_at: null, created_at: '2026-06-15T00:00:00Z' }),
   120	    ]);
   121	    expect(rows[0].published_at).toBe('2026-06-15T00:00:00Z');
   122	  });
   123
   124	  it('carries release_id, title, status, license, file_count through unchanged', () => {
   125	    const rows = normalizeReleaseRows([
   126	      makeReleaseHead({ release_id: 'asr_abc123', file_count: 42 }),
   127	    ]);
   128	    expect(rows[0].release_id).toBe('asr_abc123');
   129	    expect(rows[0].title).toBe('SysNDD analysis-snapshot release');
   130	    expect(rows[0].status).toBe('published');
   131	    expect(rows[0].license).toBe('CC-BY-4.0');
   132	    expect(rows[0].file_count).toBe(42);
   133	  });
   134
   135	  it('falls back to release_id when title is null (release_version is always null too)', () => {
   136	    const rows = normalizeReleaseRows([
   137	      makeReleaseHead({ release_id: 'asr_no_title', title: null }),
   138	    ]);
   139	    expect(rows[0].title).toBe('asr_no_title');
   140	    expect(rows[0]).not.toHaveProperty('release_version');
   141	  });
   142
   143	  it('does not mutate the input and tolerates null/undefined', () => {
   144	    const input = [makeReleaseHead()];
   145	    const rows = normalizeReleaseRows(input);
   146	    expect(rows).not.toBe(input);
   147	    expect(normalizeReleaseRows(null)).toEqual([]);
   148	    expect(normalizeReleaseRows(undefined)).toEqual([]);
   149	  });
   150	});
     1	import { afterEach, describe, expect, it } from 'vitest';
     2	import { http, HttpResponse } from 'msw';
     3	import { server } from '@/test-utils/mocks/server';
     4	import { primeAuth } from '@/test-utils/primeAuth';
     5	import { isApiError } from './client';
     6	import { extractApiErrorMessage } from '@/utils/api-errors';
     7	import {
     8	  buildRelease,
     9	  deleteDraftRelease,
    10	  fetchSnapshotStatus,
    11	  getAdminRelease,
    12	  listAdminReleases,
    13	  publishRelease,
    14	  recordReleaseDoi,
    15	  RELEASE_LAYER_TYPES,
    16	  type AdminReleaseHead,
    17	} from './admin_analysis_release';
    18
    19	function makeHead(overrides: Partial<AdminReleaseHead> = {}): AdminReleaseHead {
    20	  return {
    21	    release_id: 'asr_abc1234567890def',
    22	    release_version: null,
    23	    title: 'Analysis snapshot release',
    24	    status: 'published',
    25	    manifest_schema_version: '1.0',
    26	    content_digest: 'a'.repeat(64),
    27	    source_data_version: '2026-07-19',
    28	    db_release_version: null,
    29	    db_release_commit: null,
    30	    manifest_sha256: 'b'.repeat(64),
    31	    bundle_sha256: 'c'.repeat(64),
    32	    license: 'CC-BY-4.0',
    33	    file_count: 10,
    34	    total_bytes: 1024,
    35	    created_by_user_id: 1,
    36	    created_at: '2026-07-19T00:00:00Z',
    37	    published_at: '2026-07-19T00:00:00Z',
    38	    updated_at: '2026-07-19T00:00:00Z',
    39	    zenodo_record_id: null,
    40	    zenodo_record_url: null,
    41	    version_doi: null,
    42	    concept_doi: null,
    43	    last_error_message: null,
    44	    ...overrides,
    45	  };
    46	}
    47
    48	describe('admin_analysis_release api client', () => {
    49	  afterEach(() => server.resetHandlers());
    50
    51	  describe('buildRelease', () => {
    52	    it('returns outcome:"created" on a 201 head', async () => {
    53	      primeAuth();
    54	      const head = makeHead({ status: 'published' });
    55	      server.use(
    56	        http.post('/api/admin/analysis/releases', () => HttpResponse.json(head, { status: 201 }))
    57	      );
    58
    59	      const result = await buildRelease({});
    60	      expect(result).toEqual({ outcome: 'created', release: head });
    61	    });
    62
    63	    it('returns outcome:"exists" on a 200 head (content-identical idempotent dup)', async () => {
    64	      primeAuth();
    65	      const head = makeHead();
    66	      server.use(
    67	        http.post('/api/admin/analysis/releases', () => HttpResponse.json(head, { status: 200 }))
    68	      );
    69
    70	      const result = await buildRelease({});
    71	      expect(result).toEqual({ outcome: 'exists', release: head });
    72	    });
    73
    74	    it('returns outcome:"locked" with retryAfter from the Retry-After header on a 503', async () => {
    75	      primeAuth();
    76	      server.use(
    77	        http.post('/api/admin/analysis/releases', () =>
    78	          HttpResponse.json(
    79	            { error: 'release_lock_unavailable', message: 'sources are mid-refresh' },
    80	            { status: 503, headers: { 'Retry-After': '5' } }
    81	          )
    82	        )
    83	      );
    84
    85	      const result = await buildRelease({});
    86	      expect(result).toEqual({
    87	        outcome: 'locked',
    88	        retryAfter: 5,
    89	        message: 'sources are mid-refresh',
    90	      });
    91	    });
    92
    93	    it('rejects with an ApiError on a 400 gate failure, extractable via extractApiErrorMessage', async () => {
    94	      primeAuth();
    95	      // Faithful RFC 9457 problem+json shape, as actually emitted by the
    96	      // real backend errorHandler (`make_problem_response()`,
    97	      // api/core/filters.R) — the reason lives under `detail`, never a
    98	      // top-level `message`.
    99	      server.use(
   100	        http.post('/api/admin/analysis/releases', () =>
   101	          HttpResponse.json(
   102	            {
   103	              type: 'https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400',
   104	              title: 'Bad Request',
   105	              status: 400,
   106	              detail: 'functional_clusters snapshot is not available',
   107	            },
   108	            { status: 400 }
   109	          )
   110	        )
   111	      );
   112
   113	      await expect(buildRelease({})).rejects.toSatisfy((err: unknown) => {
   114	        expect(isApiError(err)).toBe(true);
   115	        expect(extractApiErrorMessage(err, 'fallback')).toBe(
   116	          'functional_clusters snapshot is not available'
   117	        );
   118	        return true;
   119	      });
   120	    });
   121
   122	    it('sends the genuine nested JSON body (layers/title/scope_statement/license/publish)', async () => {
   123	      primeAuth();
   124	      let payload: unknown;
   125	      server.use(
   126	        http.post('/api/admin/analysis/releases', async ({ request }) => {
   127	          payload = await request.json();
   128	          return HttpResponse.json(makeHead(), { status: 201 });
   129	        })
   130	      );
   131
   132	      await buildRelease({
   133	        layers: [{ analysis_type: 'functional_clusters' }],
   134	        title: 'My release',
   135	        scope_statement: 'scope',
   136	        license: 'CC0-1.0',
   137	        publish: false,
   138	      });
   139
   140	      expect(payload).toEqual({
   141	        layers: [{ analysis_type: 'functional_clusters' }],
   142	        title: 'My release',
   143	        scope_statement: 'scope',
   144	        license: 'CC0-1.0',
   145	        publish: false,
   146	      });
   147	    });
   148	  });
   149
   150	  it('listAdminReleases returns {releases, pagination}', async () => {
   151	    primeAuth();
   152	    const head = makeHead();
   153	    server.use(
   154	      http.get('/api/admin/analysis/releases', () =>
   155	        HttpResponse.json({ releases: [head], pagination: { limit: 50, offset: 0, count: 1 } })
   156	      )
   157	    );
   158
   159	    const result = await listAdminReleases();
   160	    expect(result.releases).toEqual([head]);
   161	    expect(result.pagination).toEqual({ limit: 50, offset: 0, count: 1 });
   162	  });
   163
   164	  it('getAdminRelease returns the bare head', async () => {
   165	    primeAuth();
   166	    const head = makeHead({ status: 'draft' });
   167	    server.use(
   168	      http.get('/api/admin/analysis/releases/asr_abc1234567890def', () => HttpResponse.json(head))
   169	    );
   170
   171	    const result = await getAdminRelease('asr_abc1234567890def');
   172	    expect(result).toEqual(head);
   173	  });
   174
   175	  it('publishRelease posts to /publish and returns the published head', async () => {
   176	    primeAuth();
   177	    const head = makeHead({ status: 'published' });
   178	    server.use(
   179	      http.post('/api/admin/analysis/releases/asr_abc1234567890def/publish', () =>
   180	        HttpResponse.json(head)
   181	      )
   182	    );
   183
   184	    const result = await publishRelease('asr_abc1234567890def');
   185	    expect(result).toEqual(head);
   186	  });
   187
   188	  describe('recordReleaseDoi', () => {
   189	    it('sends ONLY the supplied fields as query params', async () => {
   190	      primeAuth();
   191	      let requestUrl: URL | undefined;
   192	      const head = makeHead({ version_doi: '10.5281/zenodo.123' });
   193	      server.use(
   194	        http.patch('/api/admin/analysis/releases/asr_abc1234567890def/doi', ({ request }) => {
   195	          requestUrl = new URL(request.url);
   196	          return HttpResponse.json(head);
   197	        })
   198	      );
   199
   200	      const result = await recordReleaseDoi('asr_abc1234567890def', {
   201	        version_doi: '10.5281/zenodo.123',
   202	      });
   203
   204	      expect(result).toEqual(head);
   205	      expect(requestUrl?.searchParams.get('version_doi')).toBe('10.5281/zenodo.123');
   206	      expect(requestUrl?.searchParams.has('zenodo_record_id')).toBe(false);
   207	      expect(requestUrl?.searchParams.has('zenodo_record_url')).toBe(false);
   208	      expect(requestUrl?.searchParams.has('concept_doi')).toBe(false);
   209	    });
   210	  });
   211
   212	  it('deleteDraftRelease issues a DELETE to the right URL', async () => {
   213	    primeAuth();
   214	    let called = false;
   215	    server.use(
   216	      http.delete('/api/admin/analysis/releases/asr_abc1234567890def', () => {
   217	        called = true;
   218	        return HttpResponse.json({ deleted: true });
   219	      })
   220	    );
   221
   222	    await deleteDraftRelease('asr_abc1234567890def');
   223	    expect(called).toBe(true);
   224	  });
   225
   226	  it('fetchSnapshotStatus returns {presets, summary}', async () => {
   227	    primeAuth();
   228	    server.use(
   229	      http.get('/api/admin/analysis/snapshots/status', () =>
   230	        HttpResponse.json({
   231	          presets: [
   232	            {
   233	              analysis_type: 'functional_clusters',
   234	              parameter_hash: 'ph1',
   235	              state: 'available',
   236	              generated_at: '2026-07-19T00:00:00Z',
   237	              activated_at: '2026-07-19T00:00:00Z',
   238	              stale_after: '2026-07-26T00:00:00Z',
   239	              source_data_version: '2026-07-19',
   240	              row_counts: { clusters: 5 },
   241	            },
   242	          ],
   243	          summary: { total: 5, available: 3, missing: 1, stale: 1, mismatch: 0 },
   244	        })
   245	      )
   246	    );
   247
   248	    const result = await fetchSnapshotStatus();
   249	    expect(result.presets).toHaveLength(1);
   250	    expect(result.presets[0].analysis_type).toBe('functional_clusters');
   251	    expect(result.summary).toEqual({ total: 5, available: 3, missing: 1, stale: 1, mismatch: 0 });
   252	  });
   253
   254	  it('exposes RELEASE_LAYER_TYPES as the single source of truth for release layers', () => {
   255	    expect(RELEASE_LAYER_TYPES).toEqual([
   256	      'functional_clusters',
   257	      'phenotype_clusters',
   258	      'phenotype_functional_correlations',
   259	    ]);
   260	  });
   261	});

exec
/bin/bash -lc "rg -n -U \"(response:\\s*\\{["'^}]*data:'"\\s*\\{[\\s\\S]{0,240}?message:|HttpResponse\\.json\\(\\s*\\{["'^}]*message:|data:'"\\s*\\{\\s*message:)\" app/src/{api,views,components}/**/*.{spec.ts,test.ts} || true; rg -n ':href|href=' app/src/{views/analyses/DataReleases.vue,components/analyses/ReleaseManifestPanel.vue,utils/safe-url.ts}; rg -n 'safeHttpUrl|record_url|doiUrl' app/src/components/analyses/ReleaseManifestPanel.* app/src/utils/safe-url.*; git diff origin/master...HEAD -- app/src/components/analyses/ReleaseManifestPanel.vue app/src/api/analysis_releases.ts app/src/views/analyses/DataReleases.vue app/src/views/admin/ManageAnalysisReleases.vue app/src/views/admin/useAnalysisReleaseAdmin.ts" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
rg: app/src/api/**/*.spec.ts: No such file or directory (os error 2)
rg: app/src/api/**/*.test.ts: No such file or directory (os error 2)
rg: app/src/views/**/*.test.ts: No such file or directory (os error 2)
rg: app/src/components/**/*.test.ts: No such file or directory (os error 2)
app/src/views/admin/ManageUser.spec.ts:172:        return HttpResponse.json({ message: 'User successfully updated.' });
app/src/views/admin/ManageUser.spec.ts:451:        return HttpResponse.json({ message: 'Deleted' });
app/src/views/admin/ManageUser.spec.ts:471:        return HttpResponse.json({ message: 'Updated' });
app/src/views/admin/ManageUser.spec.ts:490:        return HttpResponse.json({ message: 'Password updated' });
app/src/views/admin/ManageOntology.spec.ts:527:        return HttpResponse.json({ message: 'Updated' });
app/src/views/curate/ApproveUser.spec.ts:209:        return HttpResponse.json({ message: 'Approved' });
app/src/views/curate/ApproveUser.spec.ts:232:        return HttpResponse.json({ message: 'Role updated' });
app/src/views/curate/ApproveUser.spec.ts:314:        return HttpResponse.json({ message: 'Role updated' });
app/src/views/curate/ApproveUser.spec.ts:318:        return HttpResponse.json({ message: 'Approved' });
app/src/views/admin/ManageBackups.spec.ts:179:        return HttpResponse.json({ message: 'Deleted' });
app/src/views/admin/ManageBackups.spec.ts:249:        HttpResponse.json({ message: 'Backup file not found' }, { status: 404 })
app/src/views/admin/ManageBackups.spec.ts:278:        return HttpResponse.json({ message: 'Deleted' });
app/src/views/admin/ManageBackups.spec.ts:301:        HttpResponse.json({ message: 'A backup operation is already running' }, { status: 409 })
app/src/views/admin/ManageBackups.spec.ts:325:        HttpResponse.json({ message: 'A backup is already running' }, { status: 409 })
app/src/views/admin/ManageBackups.spec.ts:341:        HttpResponse.json({ message: 'Restore is temporarily unavailable' }, { status: 503 })
app/src/views/curate/ModifyEntity.spec.ts:125:        data: { message: 'Entity successfully renamed.', entity_id: 501 },
app/src/views/curate/ModifyEntity.spec.ts:264:          return HttpResponse.json(
app/src/views/curate/ModifyEntity.spec.ts:265:            { message: 'Entity successfully renamed.', entity_id: 501 },
app/src/views/curate/ModifyEntity.spec.ts:356:          return HttpResponse.json({ message: 'ok', entity_id: 501 });
app/src/views/curate/ModifyEntity.spec.ts:375:          return HttpResponse.json({ message: 'ok' });
app/src/views/curate/ModifyEntity.spec.ts:402:          return HttpResponse.json({ message: 'ok' });
app/src/views/review/Review.spec.ts:554:    axiosMock.put.mockResolvedValue({ data: { message: 'Review successfully updated.' } });
app/src/views/review/Review.spec.ts:700:    axiosMock.put.mockResolvedValue({ data: { message: 'ok' } });
app/src/views/review/Review.spec.ts:766:    axiosMock.put.mockResolvedValue({ data: { message: 'refused' } });
app/src/views/review/Review.spec.ts:1027:    axiosMock.put.mockResolvedValue({ data: { message: 'ok' } });
app/src/views/review/Review.spec.ts:1060:    axiosMock.put.mockResolvedValue({ data: { message: 'ok' } });
app/src/views/review/Review.spec.ts:1100:    axiosMock.put.mockResolvedValue({ data: { message: 'ok' } });
app/src/views/admin/ManageAnnotations.spec.ts:120:      HttpResponse.json({
app/src/views/admin/ManageAnnotations.spec.ts:121:        deprecated_count: [0],
app/src/views/admin/ManageAnnotations.spec.ts:122:        affected_entity_count: [0],
app/src/views/admin/ManageAnnotations.spec.ts:123:        affected_entities: [],
app/src/views/admin/ManageAnnotations.spec.ts:124:        mim2gene_date: [null],
app/src/views/admin/ManageAnnotations.spec.ts:125:        message: [null],
app/src/views/admin/ManageAnnotations.spec.ts:377:        HttpResponse.json({
app/src/views/admin/ManageAnnotations.spec.ts:378:          data: [
app/src/views/admin/ManageAnnotations.spec.ts:379:            {
app/src/views/admin/ManageAnnotations.spec.ts:380:              job_id: ['hgnc-update-2025-07-01'],
app/src/views/admin/ManageAnnotations.spec.ts:381:              job_type: ['hgnc_update'],
app/src/views/admin/ManageAnnotations.spec.ts:382:              operation: ['hgnc_update'],
app/src/views/admin/ManageAnnotations.spec.ts:383:              status: ['completed'],
app/src/views/admin/ManageAnnotations.spec.ts:384:              submitted_at: ['2025-07-01 00:00:00'],
app/src/views/admin/ManageAnnotations.spec.ts:385:              completed_at: ['2025-07-01 00:05:12'],
app/src/views/admin/ManageAnnotations.spec.ts:386:              duration_seconds: [312],
app/src/views/admin/ManageAnnotations.spec.ts:387:              error_message: [null],
app/src/views/admin/ManageAnnotations.spec.ts:483:        HttpResponse.json({
app/src/views/admin/ManageAnnotations.spec.ts:484:          message: 'Ontology update job submitted.',
app/src/views/admin/ManageAnnotations.spec.ts:722:        HttpResponse.json({
app/src/views/admin/ManageAnnotations.spec.ts:723:          message: 'Ontology update job submitted.',
app/src/views/admin/ManageAnnotations.spec.ts:786:        return HttpResponse.json({
app/src/views/admin/ManageAnnotations.spec.ts:787:          message: 'Force-apply job submitted.',
app/src/views/admin/ManageAbout.spec.ts:48:        return HttpResponse.json({ message: 'saved' });
app/src/views/admin/ManageAbout.spec.ts:67:        return HttpResponse.json({ message: 'saved' });
app/src/utils/safe-url.ts:3:// Guards a bound `:href` against scheme injection (#573 Slice B, Codex round-1
app/src/utils/safe-url.ts:5:// bound `:href` — if any admin-authored or upstream string ever reaches a
app/src/components/analyses/ReleaseManifestPanel.vue:162:              :href="safeVersionDoiHref"
app/src/components/analyses/ReleaseManifestPanel.vue:177:              :href="safeConceptDoiHref"
app/src/components/analyses/ReleaseManifestPanel.vue:193:              never bound to `:href` unguarded — `safeHttpUrl` only allows
app/src/components/analyses/ReleaseManifestPanel.vue:199:              :href="safeRecordUrl"
app/src/components/analyses/ReleaseManifestPanel.vue:241:// bound `:href` (see the template note above). The `doiUrl(...)`-constructed
app/src/utils/safe-url.ts:6:// public anchor's `href` unvalidated (e.g. `zenodo.record_url`, recorded via
app/src/utils/safe-url.ts:14:export function safeHttpUrl(value: unknown): string | null {
app/src/components/analyses/ReleaseManifestPanel.vue:8:  layout, `displayValue`/`doiUrl` local helpers, mono hash styling). The
app/src/components/analyses/ReleaseManifestPanel.vue:191:              HIGH (#573 Slice B Codex round-1): `zenodo.record_url` is an
app/src/components/analyses/ReleaseManifestPanel.vue:193:              never bound to `:href` unguarded — `safeHttpUrl` only allows
app/src/components/analyses/ReleaseManifestPanel.vue:205:            <span v-else-if="release.zenodo.record_url">{{ release.zenodo.record_url }}</span>
app/src/components/analyses/ReleaseManifestPanel.vue:218:import { safeHttpUrl } from '@/utils/safe-url';
app/src/components/analyses/ReleaseManifestPanel.vue:235:function doiUrl(doi: string): string {
app/src/components/analyses/ReleaseManifestPanel.vue:239:// HIGH (#573 Slice B Codex round-1): `zenodo.record_url` is admin-authored
app/src/components/analyses/ReleaseManifestPanel.vue:241:// bound `:href` (see the template note above). The `doiUrl(...)`-constructed
app/src/components/analyses/ReleaseManifestPanel.vue:244:const safeRecordUrl = computed<string | null>(() => safeHttpUrl(props.release.zenodo.record_url));
app/src/components/analyses/ReleaseManifestPanel.vue:246:  props.release.zenodo.version_doi ? safeHttpUrl(doiUrl(props.release.zenodo.version_doi)) : null
app/src/components/analyses/ReleaseManifestPanel.vue:249:  props.release.zenodo.concept_doi ? safeHttpUrl(doiUrl(props.release.zenodo.concept_doi)) : null
app/src/utils/safe-url.spec.ts:3:import { safeHttpUrl } from './safe-url';
app/src/utils/safe-url.spec.ts:5:describe('safeHttpUrl', () => {
app/src/utils/safe-url.spec.ts:7:    expect(safeHttpUrl('https://zenodo.org/records/1234')).toBe(
app/src/utils/safe-url.spec.ts:13:    expect(safeHttpUrl('http://example.org/path')).toBe('http://example.org/path');
app/src/utils/safe-url.spec.ts:17:    expect(safeHttpUrl('javascript:alert(document.cookie)')).toBeNull();
app/src/utils/safe-url.spec.ts:21:    expect(safeHttpUrl('data:text/html,<script>alert(1)</script>')).toBeNull();
app/src/utils/safe-url.spec.ts:25:    expect(safeHttpUrl('vbscript:msgbox(1)')).toBeNull();
app/src/utils/safe-url.spec.ts:29:    expect(safeHttpUrl('')).toBeNull();
app/src/utils/safe-url.spec.ts:33:    expect(safeHttpUrl('   ')).toBeNull();
app/src/utils/safe-url.spec.ts:37:    expect(safeHttpUrl(null)).toBeNull();
app/src/utils/safe-url.spec.ts:41:    expect(safeHttpUrl(undefined)).toBeNull();
app/src/utils/safe-url.spec.ts:45:    expect(safeHttpUrl(42)).toBeNull();
app/src/utils/safe-url.spec.ts:46:    expect(safeHttpUrl({ href: 'https://evil.example' })).toBeNull();
app/src/utils/safe-url.spec.ts:53:    expect(safeHttpUrl('/some/path')).toBe('/some/path');
app/src/utils/safe-url.spec.ts:57:    expect(safeHttpUrl('http://')).toBeNull();
app/src/components/analyses/ReleaseManifestPanel.spec.ts:24:      record_url: 'https://zenodo.org/records/1234',
app/src/components/analyses/ReleaseManifestPanel.spec.ts:118:    release.zenodo = { record_url: null, version_doi: null, concept_doi: null };
app/src/components/analyses/ReleaseManifestPanel.spec.ts:124:  // `zenodo.record_url` with no backend URL validation, so an admin-authored
app/src/components/analyses/ReleaseManifestPanel.spec.ts:127:  it('does not render a clickable link for a javascript:-scheme record_url (renders plain text instead)', () => {
app/src/components/analyses/ReleaseManifestPanel.spec.ts:131:      record_url: 'javascript:alert(document.cookie)',
app/src/components/analyses/ReleaseManifestPanel.spec.ts:144:  it('does not render a clickable link for a data:-scheme record_url either', () => {
app/src/components/analyses/ReleaseManifestPanel.spec.ts:148:      record_url: 'data:text/html,<script>alert(1)</script>',
app/src/components/analyses/ReleaseManifestPanel.spec.ts:158:  it('still renders a normal https record_url as a clickable link', () => {
diff --git a/app/src/api/analysis_releases.ts b/app/src/api/analysis_releases.ts
new file mode 100644
index 00000000..625bb83e
--- /dev/null
+++ b/app/src/api/analysis_releases.ts
@@ -0,0 +1,319 @@
+// app/src/api/analysis_releases.ts
+//
+// Analysis-snapshot release resource helpers (#573).
+//
+// Immutable, content-addressed frozen exports of the public-ready analysis
+// snapshots (functional clusters, phenotype clusters, phenotype-functional
+// correlation) — mirrors the release-specific routes in
+// api/endpoints/analysis_endpoints.R (mounted at /api/analysis). Split out
+// of `analysis.ts` as a cohesive sub-domain to keep that file under the
+// repo's 600-line soft ceiling; re-exported from `analysis.ts` so
+// `@/api/analysis` stays the single import surface for analysis resources.
+//
+// All routes here are public/unauthenticated, DB-only, published-releases-only
+// (draft releases are never served). See
+// api/functions/analysis-snapshot-release-repository.R
+// (`analysis_release_public_head()`) for the exact PUBLIC allowlist these
+// types mirror.
+
+import type { AxiosRequestConfig } from 'axios';
+import { apiClient } from './client';
+
+// ---------------------------------------------------------------------------
+// Types
+// ---------------------------------------------------------------------------
+
+/**
+ * Zenodo DOI metadata attached to a release head. Additive-only (#573):
+ * fields are `null` until an admin records them via
+ * `PATCH /api/admin/analysis/releases/<id>/doi`; they never affect
+ * `content_digest`.
+ */
+export interface ReleaseZenodo {
+  record_url: string | null;
+  version_doi: string | null;
+  concept_doi: string | null;
+}
+
+/**
+ * Correlation-layer dependency lineage: pinned source cluster snapshots.
+ *
+ * The phenotype-functional correlation layer is derived FROM the functional
+ * + phenotype cluster layers, so its manifest entry pins exactly which
+ * snapshot (by id + payload hash) it was built against (#571/#572 dependency
+ * gate) — this is what a consumer cross-checks to confirm the correlation
+ * layer is internally consistent with its two source layers.
+ */
+export interface ReleaseLayerDependency {
+  snapshot_id: number;
+  payload_hash: string;
+}
+
+export interface ReleaseLayerDependencies {
+  functional_clusters?: ReleaseLayerDependency;
+  phenotype_clusters?: ReleaseLayerDependency;
+}
+
+/**
+ * Full per-layer identity, as it appears in `manifest.layers[]` on the
+ * detail (`GET /releases/<id>`) and `latest` routes. `reproducibility_hash`
+ * is `null` for the `phenotype_functional_correlations` layer (that layer
+ * has no reproducibility bundle); `dependencies` is non-null ONLY for that
+ * same layer.
+ */
+export interface ReleaseManifestLayer {
+  analysis_type: string;
+  parameter_hash: string;
+  snapshot_id: number;
+  input_hash: string | null;
+  payload_hash: string | null;
+  schema_version: string;
+  reproducibility_hash: string | null;
+  dependencies: ReleaseLayerDependencies | null;
+}
+
+/**
+ * Light per-layer summary, as it appears in `layers[]` on each head from the
+ * LIST route (`GET /releases`) only — the list route intentionally omits the
+ * full manifest (and therefore the fuller `ReleaseManifestLayer` shape) to
+ * keep the listing payload cheap.
+ */
+export interface ReleaseHeadLayer {
+  analysis_type: string;
+  snapshot_id: number;
+  payload_hash: string;
+}
+
+/**
+ * PUBLIC projection of an `analysis_snapshot_release` head, as returned by
+ * `analysis_release_public_head()` (api/functions/analysis-snapshot-release-repository.R).
+ *
+ * This is a FIXED 14-field allowlist + `zenodo` + conditional `layers`
+ * (list route) / `manifest` (detail + latest routes). Admin-only columns
+ * (`created_by_user_id`, `last_error_message`, `updated_at`) are NEVER part
+ * of this type — do not widen it to match the raw admin head shape in
+ * `admin_analysis_release.ts` (a separate, intentionally different type).
+ */
+export interface ReleaseHead {
+  release_id: string;
+  /**
+   * Reserved string column (`VARCHAR(32)`, migration 045) — always `null`
+   * today; the builder never populates it (`api/functions/analysis-snapshot-
+   * release.R`). Not a number, and not guaranteed non-null.
+   */
+  release_version: string | null;
+  title: string | null;
+  status: string;
+  content_digest: string;
+  created_at: string;
+  published_at: string | null;
+  source_data_version: string;
+  db_release_version: string | null;
+  db_release_commit: string | null;
+  manifest_sha256: string;
+  bundle_sha256: string;
+  license: string;
+  file_count: number;
+  total_bytes: number;
+  zenodo: ReleaseZenodo;
+  /** Light per-layer identity (list route only): analysis_type, snapshot_id, payload_hash. */
+  layers?: ReleaseHeadLayer[];
+}
+
+export interface ReleaseManifestFile {
+  path: string;
+  sha256: string;
+  bytes: number;
+}
+
+/**
+ * Build provenance recorded on `manifest.generator`
+ * (api/functions/analysis-snapshot-release.R, the `analysis_release_build_manifest()`
+ * call site). `reproducibility_schema_version` is absent/`null` if the
+ * `ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION` constant is not defined at build
+ * time.
+ */
+export interface ReleaseManifestGenerator {
+  name: string;
+  manifest_schema_version: string;
+  reproducibility_schema_version: string | null;
+}
+
+/** `manifest.source.db_release`: the DB release identity pinned at build time, if known. */
+export interface ReleaseManifestSourceDbRelease {
+  version: string | null;
+  commit: string | null;
+}
+
+/** One entry of `manifest.source.snapshots[]` — the pinned source snapshot per layer. */
+export interface ReleaseManifestSourceSnapshot {
+  analysis_type: string;
+  snapshot_id: number;
+  parameter_hash: string;
+}
+
+/** `manifest.source`: the shared source-data identity every layer in the release was built from. */
+export interface ReleaseManifestSource {
+  source_data_version: string;
+  db_release: ReleaseManifestSourceDbRelease;
+  snapshots: ReleaseManifestSourceSnapshot[];
+}
+
+/**
+ * The release `manifest.json` shape, built by
+ * `analysis_release_build_manifest()` (api/functions/analysis-snapshot-release-manifest.R).
+ * Present on the detail (`GET /releases/<id>`) and `latest` routes only —
+ * NOT on the list route, which carries the lighter `layers` array on each
+ * head instead.
+ */
+export interface ReleaseManifest {
+  release_id: string;
+  /** Reserved, currently-unpopulated string column — always `null` today (see `ReleaseHead.release_version`). */
+  release_version: string | null;
+  title: string | null;
+  created_at: string;
+  license: string;
+  /** Nullable — the build param defaults to `NULL` when the caller omits a scope statement. */
+  scope_statement: string | null;
+  generator: ReleaseManifestGenerator;
+  source: ReleaseManifestSource;
+  layers: ReleaseManifestLayer[];
+  files: ReleaseManifestFile[];
+  content_digest: string;
+}
+
+/** `GET /releases/<id>` and `GET /releases/latest`: head + parsed manifest. */
+export interface ReleaseDetail extends ReleaseHead {
+  manifest: ReleaseManifest;
+}
+
+export interface ListReleasesParams {
+  limit?: number;
+  offset?: number;
+}
+
+export interface ListReleasesResponse {
+  releases: ReleaseHead[];
+  pagination: {
+    limit: number;
+    offset: number;
+    count: number;
+  };
+}
+
+// ---------------------------------------------------------------------------
+// Helpers
+// ---------------------------------------------------------------------------
+
+/**
+ * GET /api/analysis/releases
+ * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases`).
+ *
+ * Public, unauthenticated. Lists published analysis-snapshot releases
+ * (newest first). `pagination` echoes the CLAMPED effective `limit`/`offset`
+ * the service actually queried, not necessarily the caller's raw values.
+ */
+export async function listReleases(
+  params: ListReleasesParams = {},
+  config?: AxiosRequestConfig
+): Promise<ListReleasesResponse> {
+  return apiClient.get<ListReleasesResponse>('/api/analysis/releases', {
+    ...config,
+    params: { ...(config?.params as object | undefined), ...params },
+  });
+}
+
+/**
+ * GET /api/analysis/releases/latest
+ * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/latest`).
+ *
+ * Public, unauthenticated. Returns the newest published release's head +
+ * manifest (same shape as the detail route).
+ *
+ * Throws AxiosError 404 when no published release exists yet.
+ */
+export async function getLatestRelease(config?: AxiosRequestConfig): Promise<ReleaseDetail> {
+  return apiClient.get<ReleaseDetail>('/api/analysis/releases/latest', config);
+}
+
+/**
+ * GET /api/analysis/releases/<release_id>
+ * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>`).
+ *
+ * Public, unauthenticated. Returns the release head + manifest. An unknown
+ * id and a draft id are indistinguishable — both 404 (drafts are never
+ * public).
+ */
+export async function getRelease(
+  releaseId: string,
+  config?: AxiosRequestConfig
+): Promise<ReleaseDetail> {
+  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}`;
+  return apiClient.get<ReleaseDetail>(path, config);
+}
+
+/**
+ * GET /api/analysis/releases/<release_id>/manifest.json
+ * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/manifest.json`).
+ *
+ * Public, unauthenticated. Returns the EXACT stored `manifest.json` bytes
+ * verbatim (never re-serialized), so `sha256(bytes) == manifest_sha256` on
+ * the release head. Returned as a `Blob` (the R handler uses `@serializer
+ * octet application/json`).
+ */
+export async function downloadReleaseManifest(
+  releaseId: string,
+  config?: AxiosRequestConfig
+): Promise<Blob> {
+  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}/manifest.json`;
+  const response = await apiClient.raw.get<Blob>(path, {
+    ...config,
+    responseType: 'blob',
+  });
+  return response.data;
+}
+
+/**
+ * GET /api/analysis/releases/<release_id>/file?path=<file_path>
+ * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/file`).
+ *
+ * Public, unauthenticated. `path` is a QUERY param, not a URL path segment —
+ * Plumber 1.3.2 has no `<path:.*>` wildcard, so a nested archive path (e.g.
+ * `functional_clusters/payload.json`) cannot be expressed as a path segment.
+ * Resolved by an exact `(release_id, file_path)` primary-key lookup; an
+ * unknown path is a 404 (there is no filesystem access, so no path-traversal
+ * surface). Returned as a `Blob`.
+ */
+export async function downloadReleaseFile(
+  releaseId: string,
+  path: string,
+  config?: AxiosRequestConfig
+): Promise<Blob> {
+  const url = `/api/analysis/releases/${encodeURIComponent(releaseId)}/file`;
+  const response = await apiClient.raw.get<Blob>(url, {
+    ...config,
+    params: { ...(config?.params as object | undefined), path },
+    responseType: 'blob',
+  });
+  return response.data;
+}
+
+/**
+ * GET /api/analysis/releases/<release_id>/bundle
+ * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/bundle`).
+ *
+ * Public, unauthenticated. Returns the release's pre-built `bundle.tar.gz`
+ * verbatim (the R handler uses `@serializer octet application/gzip` and sets
+ * `Content-Disposition: attachment`). Returned as a `Blob`.
+ */
+export async function downloadReleaseBundle(
+  releaseId: string,
+  config?: AxiosRequestConfig
+): Promise<Blob> {
+  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}/bundle`;
+  const response = await apiClient.raw.get<Blob>(path, {
+    ...config,
+    responseType: 'blob',
+  });
+  return response.data;
+}
diff --git a/app/src/components/analyses/ReleaseManifestPanel.vue b/app/src/components/analyses/ReleaseManifestPanel.vue
new file mode 100644
index 00000000..70313c10
--- /dev/null
+++ b/app/src/components/analyses/ReleaseManifestPanel.vue
@@ -0,0 +1,433 @@
+<!-- src/components/analyses/ReleaseManifestPanel.vue -->
+<!--
+  Provenance card for one analysis-snapshot release (#573 Slice B, Task B2):
+  identity, integrity hashes (copy-to-clipboard), per-layer manifest detail,
+  the correlation layer's dependency lineage, and Zenodo DOI links.
+
+  Styled to mirror `nddscore/NddScoreModelCard.vue` (dl-grid provenance
+  layout, `displayValue`/`doiUrl` local helpers, mono hash styling). The
+  clipboard "Copy"/"Copied" idiom mirrors `small/GenericTableDetails.vue`
+  (transient state + a reset timer, guarded for jsdom/no-Clipboard-API envs).
+-->
+<template>
+  <section class="release-manifest-panel" aria-labelledby="release-manifest-panel-title">
+    <header class="release-manifest-panel__header">
+      <div>
+        <h2 id="release-manifest-panel-title" class="release-manifest-panel__title">
+          {{ displayTitle }}
+        </h2>
+        <p class="release-manifest-panel__subtitle">
+          Immutable, content-addressed export. Verify a download against the hashes below.
+        </p>
+      </div>
+      <BBadge variant="info" class="release-manifest-panel__badge">
+        {{ release.release_id }}
+      </BBadge>
+    </header>
+
+    <section aria-label="Identity">
+      <h3 class="release-manifest-panel__section-title">Identity</h3>
+      <dl class="release-manifest-panel__grid">
+        <div>
+          <dt>Release ID</dt>
+          <dd class="release-manifest-panel__mono">{{ release.release_id }}</dd>
+        </div>
+        <div v-if="release.release_version">
+          <dt>Version</dt>
+          <dd>{{ release.release_version }}</dd>
+        </div>
+        <div>
+          <dt>Title</dt>
+          <dd>{{ displayTitle }}</dd>
+        </div>
+        <div>
+          <dt>Status</dt>
+          <dd>{{ release.status }}</dd>
+        </div>
+        <div>
+          <dt>Source data version</dt>
+          <dd>{{ release.source_data_version }}</dd>
+        </div>
+        <div>
+          <dt>DB release version</dt>
+          <dd>{{ displayValue(release.db_release_version) }}</dd>
+        </div>
+        <div>
+          <dt>DB release commit</dt>
+          <dd class="release-manifest-panel__mono">
+            {{ displayValue(release.db_release_commit) }}
+          </dd>
+        </div>
+        <div>
+          <dt>Created</dt>
+          <dd>{{ release.created_at }}</dd>
+        </div>
+        <div>
+          <dt>Published</dt>
+          <dd>{{ displayValue(release.published_at) }}</dd>
+        </div>
+      </dl>
+    </section>
+
+    <section aria-label="Integrity hashes">
+      <h3 class="release-manifest-panel__section-title">Integrity hashes</h3>
+      <dl class="release-manifest-panel__grid release-manifest-panel__grid--hashes">
+        <div v-for="hash in integrityHashes" :key="hash.key">
+          <dt>{{ hash.label }}</dt>
+          <dd class="release-manifest-panel__hash-value">
+            <span class="release-manifest-panel__mono">{{ hash.value }}</span>
+            <button
+              type="button"
+              class="release-manifest-panel__copy-button"
+              :aria-label="`Copy ${hash.label} to clipboard`"
+              @click="copyValue(hash.key, hash.value)"
+            >
+              <i class="bi bi-clipboard" aria-hidden="true" />
+              {{ copiedKey === hash.key ? 'Copied' : 'Copy' }}
+            </button>
+          </dd>
+        </div>
+      </dl>
+    </section>
+
+    <section aria-label="Layers">
+      <h3 class="release-manifest-panel__section-title">Layers</h3>
+      <div
+        v-for="layer in release.manifest.layers"
+        :key="layer.analysis_type"
+        class="release-manifest-panel__layer"
+      >
+        <h4 class="release-manifest-panel__layer-title">{{ layer.analysis_type }}</h4>
+        <dl class="release-manifest-panel__grid">
+          <div>
+            <dt>Snapshot ID</dt>
+            <dd>{{ layer.snapshot_id }}</dd>
+          </div>
+          <div>
+            <dt>Payload hash</dt>
+            <dd class="release-manifest-panel__mono">{{ displayValue(layer.payload_hash) }}</dd>
+          </div>
+          <div>
+            <dt>Input hash</dt>
+            <dd class="release-manifest-panel__mono">{{ displayValue(layer.input_hash) }}</dd>
+          </div>
+          <div>
+            <dt>Reproducibility hash</dt>
+            <dd class="release-manifest-panel__mono">
+              <span v-if="layer.reproducibility_hash">{{ layer.reproducibility_hash }}</span>
+              <span v-else class="text-muted">n/a (not reproducible)</span>
+            </dd>
+          </div>
+        </dl>
+      </div>
+    </section>
+
+    <section v-if="dependencyLayer" aria-label="Dependency lineage">
+      <h3 class="release-manifest-panel__section-title">Dependency lineage</h3>
+      <p class="release-manifest-panel__hint">
+        {{ dependencyLayer.analysis_type }} is derived from these pinned source-layer snapshots.
+      </p>
+      <dl class="release-manifest-panel__grid">
+        <div v-if="dependencyLayer.dependencies?.functional_clusters">
+          <dt>Functional clusters</dt>
+          <dd>
+            snapshot {{ dependencyLayer.dependencies.functional_clusters.snapshot_id }}
+            &middot;
+            <span class="release-manifest-panel__mono">{{
+              dependencyLayer.dependencies.functional_clusters.payload_hash
+            }}</span>
+          </dd>
+        </div>
+        <div v-if="dependencyLayer.dependencies?.phenotype_clusters">
+          <dt>Phenotype clusters</dt>
+          <dd>
+            snapshot {{ dependencyLayer.dependencies.phenotype_clusters.snapshot_id }}
+            &middot;
+            <span class="release-manifest-panel__mono">{{
+              dependencyLayer.dependencies.phenotype_clusters.payload_hash
+            }}</span>
+          </dd>
+        </div>
+      </dl>
+    </section>
+
+    <section aria-label="DOI">
+      <h3 class="release-manifest-panel__section-title">DOI</h3>
+      <dl class="release-manifest-panel__grid">
+        <div>
+          <dt>Version DOI</dt>
+          <dd>
+            <a
+              v-if="safeVersionDoiHref"
+              :href="safeVersionDoiHref"
+              target="_blank"
+              rel="noopener noreferrer"
+            >
+              {{ release.zenodo.version_doi }}
+            </a>
+            <span v-else-if="release.zenodo.version_doi">{{ release.zenodo.version_doi }}</span>
+            <span v-else class="text-muted">not yet assigned</span>
+          </dd>
+        </div>
+        <div>
+          <dt>Concept DOI</dt>
+          <dd>
+            <a
+              v-if="safeConceptDoiHref"
+              :href="safeConceptDoiHref"
+              target="_blank"
+              rel="noopener noreferrer"
+            >
+              {{ release.zenodo.concept_doi }}
+            </a>
+            <span v-else-if="release.zenodo.concept_doi">{{ release.zenodo.concept_doi }}</span>
+            <span v-else class="text-muted">not yet assigned</span>
+          </dd>
+        </div>
+        <div>
+          <dt>Zenodo record</dt>
+          <dd>
+            <!--
+              HIGH (#573 Slice B Codex round-1): `zenodo.record_url` is an
+              admin-authored string with no backend URL validation, so it is
+              never bound to `:href` unguarded — `safeHttpUrl` only allows
+              http(s), rendering anything else (e.g. `javascript:...`) as
+              inert plain text instead of a clickable anchor.
+            -->
+            <a
+              v-if="safeRecordUrl"
+              :href="safeRecordUrl"
+              target="_blank"
+              rel="noopener noreferrer"
+            >
+              Record
+            </a>
+            <span v-else-if="release.zenodo.record_url">{{ release.zenodo.record_url }}</span>
+            <span v-else class="text-muted">not yet assigned</span>
+          </dd>
+        </div>
+      </dl>
+    </section>
+  </section>
+</template>
+
+<script setup lang="ts">
+import { computed, onBeforeUnmount, ref } from 'vue';
+import { BBadge } from 'bootstrap-vue-next';
+import type { ReleaseDetail, ReleaseManifestLayer } from '@/api/analysis';
+import { safeHttpUrl } from '@/utils/safe-url';
+
+defineOptions({
+  name: 'ReleaseManifestPanel',
+});
+
+const props = defineProps<{
+  release: ReleaseDetail;
+}>();
+
+function displayValue(value: string | number | null | undefined): string {
+  return value === null || value === undefined || value === '' ? '—' : String(value);
+}
+
+/** `title`, falling back to `release_id` when the reserved `title` column is null. */
+const displayTitle = computed(() => props.release.title || props.release.release_id);
+
+function doiUrl(doi: string): string {
+  return `https://doi.org/${doi}`;
+}
+
+// HIGH (#573 Slice B Codex round-1): `zenodo.record_url` is admin-authored
+// and unvalidated by the backend, so it is guarded before ever reaching a
+// bound `:href` (see the template note above). The `doiUrl(...)`-constructed
+// DOI hrefs are guarded too, defensively — belt-and-suspenders, since the
+// scheme there is currently always the hardcoded `https://doi.org/` prefix.
+const safeRecordUrl = computed<string | null>(() => safeHttpUrl(props.release.zenodo.record_url));
+const safeVersionDoiHref = computed<string | null>(() =>
+  props.release.zenodo.version_doi ? safeHttpUrl(doiUrl(props.release.zenodo.version_doi)) : null
+);
+const safeConceptDoiHref = computed<string | null>(() =>
+  props.release.zenodo.concept_doi ? safeHttpUrl(doiUrl(props.release.zenodo.concept_doi)) : null
+);
+
+const integrityHashes = computed(() => [
+  { key: 'content_digest', label: 'Content digest', value: props.release.content_digest },
+  { key: 'manifest_sha256', label: 'Manifest SHA-256', value: props.release.manifest_sha256 },
+  { key: 'bundle_sha256', label: 'Bundle SHA-256', value: props.release.bundle_sha256 },
+]);
+
+/** The one manifest layer with pinned source-layer dependencies (the correlation layer), if any. */
+const dependencyLayer = computed<ReleaseManifestLayer | null>(
+  () => props.release.manifest.layers.find((layer) => layer.dependencies != null) ?? null
+);
+
+// --- Copy-to-clipboard: mirrors small/GenericTableDetails.vue's transient
+// "Copy" -> "Copied" state + reset-timer lifecycle. ---
+const copiedKey = ref<string | null>(null);
+let copyResetTimer: ReturnType<typeof setTimeout> | null = null;
+
+async function copyValue(key: string, value: string): Promise<void> {
+  if (!value || !navigator.clipboard?.writeText) {
+    return;
+  }
+  try {
+    await navigator.clipboard.writeText(value);
+    copiedKey.value = key;
+    if (copyResetTimer) {
+      clearTimeout(copyResetTimer);
+    }
+    copyResetTimer = setTimeout(() => {
+      copiedKey.value = null;
+      copyResetTimer = null;
+    }, 1600);
+  } catch {
+    copiedKey.value = null;
+  }
+}
+
+onBeforeUnmount(() => {
+  if (copyResetTimer) {
+    clearTimeout(copyResetTimer);
+    copyResetTimer = null;
+  }
+});
+</script>
+
+<style scoped>
+.release-manifest-panel {
+  display: grid;
+  gap: 1rem;
+  padding: 1rem;
+  border: 1px solid #d7dee8;
+  border-radius: var(--radius-lg, 8px);
+  background: #fff;
+  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
+}
+
+.release-manifest-panel__header {
+  display: flex;
+  flex-wrap: wrap;
+  align-items: flex-start;
+  justify-content: space-between;
+  gap: 0.75rem;
+}
+
+.release-manifest-panel__title {
+  margin: 0;
+  color: var(--neutral-900, #212121);
+  font-size: 1rem;
+  font-weight: 700;
+  line-height: 1.25;
+}
+
+.release-manifest-panel__subtitle {
+  margin: 0.15rem 0 0;
+  color: var(--neutral-600, #757575);
+  font-size: 0.875rem;
+  line-height: 1.45;
+}
+
+.release-manifest-panel__badge {
+  max-width: 100%;
+  overflow-wrap: anywhere;
+  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
+}
+
+.release-manifest-panel__section-title {
+  margin: 0 0 0.4rem;
+  color: var(--neutral-700, #616161);
+  font-size: 0.8125rem;
+  font-weight: 700;
+  text-transform: uppercase;
+  letter-spacing: 0.02em;
+}
+
+.release-manifest-panel__grid {
+  display: grid;
+  grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
+  gap: 0.5rem 0.75rem;
+  margin: 0;
+}
+
+.release-manifest-panel__grid div {
+  min-width: 0;
+}
+
+.release-manifest-panel__grid dt {
+  margin: 0;
+  color: var(--neutral-700, #616161);
+  font-size: 0.75rem;
+  font-weight: 700;
+}
+
+.release-manifest-panel__grid dd {
+  margin: 0.1rem 0 0;
+  color: var(--neutral-900, #212121);
+  font-size: 0.8125rem;
+  overflow-wrap: anywhere;
+}
+
+.release-manifest-panel__grid a {
+  color: var(--medical-blue-700, #0d47a1);
+}
+
+.release-manifest-panel__mono {
+  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
+}
+
+.release-manifest-panel__grid--hashes dd.release-manifest-panel__hash-value {
+  display: flex;
+  flex-wrap: wrap;
+  align-items: center;
+  gap: 0.5rem;
+}
+
+.release-manifest-panel__grid--hashes .release-manifest-panel__mono {
+  word-break: break-all;
+}
+
+.release-manifest-panel__copy-button {
+  display: inline-flex;
+  flex: 0 0 auto;
+  align-items: center;
+  gap: 0.25rem;
+  padding: 0.08rem 0.4rem;
+  border: 1px solid #0a58ca;
+  border-radius: var(--radius-md, 6px);
+  background: #fff;
+  color: #0a58ca;
+  font-size: 0.72rem;
+  line-height: 1.6;
+  white-space: nowrap;
+}
+
+.release-manifest-panel__copy-button:hover,
+.release-manifest-panel__copy-button:focus {
+  border-color: #084298;
+  background-color: #0a58ca;
+  color: #fff;
+}
+
+.release-manifest-panel__layer {
+  padding: 0.5rem 0.65rem;
+  border: 1px solid #e1e7ef;
+  border-radius: var(--radius-md, 6px);
+  background: #f8fafc;
+}
+
+.release-manifest-panel__layer + .release-manifest-panel__layer {
+  margin-top: 0.5rem;
+}
+
+.release-manifest-panel__layer-title {
+  margin: 0 0 0.35rem;
+  color: var(--neutral-900, #212121);
+  font-size: 0.875rem;
+  font-weight: 700;
+}
+
+.release-manifest-panel__hint {
+  margin: 0 0 0.5rem;
+  color: var(--neutral-600, #757575);
+  font-size: 0.8125rem;
+}
+</style>
diff --git a/app/src/views/admin/ManageAnalysisReleases.vue b/app/src/views/admin/ManageAnalysisReleases.vue
new file mode 100644
index 00000000..70c5cb6e
--- /dev/null
+++ b/app/src/views/admin/ManageAnalysisReleases.vue
@@ -0,0 +1,479 @@
+<!-- app/src/views/admin/ManageAnalysisReleases.vue -->
+<!--
+  Administrator page to build/publish/DOI-tag analysis-snapshot releases
+  (#573 Slice B, Task B4b): immutable, content-addressed frozen exports of
+  the public-ready analysis snapshots (functional clusters, phenotype
+  clusters, phenotype-functional correlation). The build itself is
+  SYNCHRONOUS and DB-only — there is no async job/worker involved, so this
+  view never polls a job status (contrast ManageNDDScore.vue's import job).
+
+  Kept thin: every client call and reactive state lives in the co-located
+  `useAnalysisReleaseAdmin` composable; this file is template + light local
+  UI-only state (the build form fields, the per-row DOI form drafts, and the
+  two-step "Delete draft" confirm — an in-page affordance, never a blocking
+  native `window.confirm`/dialog).
+-->
+<template>
+  <AuthenticatedPageShell
+    title="Manage analysis-snapshot releases"
+    description="Build, publish, and DOI-tag immutable, content-addressed exports of SysNDD's public-ready analysis snapshots (functional clusters, phenotype clusters, and their correlation). Each release freezes its own copy of the data and survives snapshot pruning or refresh byte-identically."
+    content-class="authenticated-route-content"
+    full-width
+  >
+    <BContainer fluid class="analysis-release-admin">
+      <AdminOperationPanel
+        title="Snapshot readiness"
+        description="A release build requires every release layer below to be available from the currently active public-ready snapshots."
+        icon="bi-clipboard-data"
+        :aria-busy="loading ? 'true' : 'false'"
+      >
+        <div class="layer-readiness-grid" data-testid="layer-readiness-grid">
+          <div
+            v-for="item in admin.layerReadiness.value"
+            :key="item.analysis_type"
+            class="layer-readiness-item"
+            :class="{ 'layer-readiness-item--ready': item.state === 'available' }"
+            :data-testid="`layer-readiness-${item.analysis_type}`"
+          >
+            <i
+              :class="[
+                'bi',
+                item.state === 'available' ? 'bi-check-circle-fill' : 'bi-x-circle-fill',
+              ]"
+              aria-hidden="true"
+            />
+            <div>
+              <strong>{{ item.label }}</strong>
+              <span class="layer-readiness-state">{{ item.state }}</span>
+            </div>
+          </div>
+        </div>
+
+        <p v-if="!admin.canBuild.value" class="layer-readiness-hint mb-0">
+          Build is disabled until every release layer above reports
+          <strong>available</strong>. Snapshots self-heal automatically (stale or missing
+          snapshots re-enqueue on the next API restart), or an operator can force a refresh via
+          <code>POST /api/admin/analysis/snapshots/refresh</code>.
+        </p>
+      </AdminOperationPanel>
+
+      <AdminOperationPanel
+        title="Build a release"
+        description="Freezes the currently active public-ready snapshots into a new immutable release. Building as a draft (the default) lets you review and record a DOI before publishing."
+        icon="bi-box-arrow-in-down"
+        heading-tag="h2"
+        :aria-busy="building ? 'true' : 'false'"
+      >
+        <BAlert v-if="admin.buildError.value" variant="danger" show class="mb-3" data-testid="build-error">
+          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
+          {{ admin.buildError.value }}
+        </BAlert>
+
+        <BAlert
+          v-if="lockedOutcome"
+          variant="warning"
+          show
+          class="mb-3"
+          data-testid="build-locked"
+        >
+          <i class="bi bi-hourglass-split me-1" aria-hidden="true" />
+          Snapshot sources are refreshing, retry in {{ lockedOutcome.retryAfter }}s.
+          {{ lockedOutcome.message }}
+        </BAlert>
+
+        <BAlert
+          v-else-if="createdOrExistingOutcome"
+          variant="success"
+          show
+          class="mb-3"
+          data-testid="build-success"
+        >
+          <i class="bi bi-check-circle-fill me-1" aria-hidden="true" />
+          Release <strong>{{ createdOrExistingOutcome.release.release_id }}</strong>
+          {{ createdOrExistingOutcome.outcome === 'created' ? 'created' : 'already existed (identical content)' }}
+          — status <strong>{{ createdOrExistingOutcome.release.status }}</strong>.
+        </BAlert>
+
+        <form class="build-form" @submit.prevent="handleBuild">
+          <div class="build-form__field">
+            <label for="release-title" class="form-label fw-semibold">Title</label>
+            <BFormInput id="release-title" v-model="buildForm.title" data-testid="build-title" />
+          </div>
+          <div class="build-form__field">
+            <label for="release-scope" class="form-label fw-semibold">Scope statement</label>
+            <BFormTextarea
+              id="release-scope"
+              v-model="buildForm.scope_statement"
+              rows="2"
+              data-testid="build-scope"
+            />
+          </div>
+          <div class="build-form__field">
+            <label for="release-license" class="form-label fw-semibold">License</label>
+            <BFormInput id="release-license" v-model="buildForm.license" data-testid="build-license" />
+          </div>
+          <div class="build-form__field build-form__field--checkbox form-check">
+            <input
+              id="release-publish"
+              v-model="buildForm.publish"
+              class="form-check-input"
+              type="checkbox"
+              data-testid="build-publish-checkbox"
+            />
+            <label class="form-check-label" for="release-publish">
+              Publish immediately (unchecked builds a draft for review)
+            </label>
+          </div>
+          <BButton
+            type="submit"
+            variant="primary"
+            data-testid="build-release-btn"
+            :disabled="!admin.canBuild.value || building"
+          >
+            <BSpinner v-if="building" small class="me-1" />
+            <i v-else class="bi bi-hammer me-1" aria-hidden="true" />
+            Build release
+          </BButton>
+        </form>
+      </AdminOperationPanel>
+
+      <AdminOperationPanel
+        title="Releases"
+        description="All releases, including drafts. Publishing and DOI recording never change a release's content digest."
+        icon="bi-archive"
+        heading-tag="h2"
+        :aria-busy="loading ? 'true' : 'false'"
+      >
+        <BAlert v-if="admin.actionError.value" variant="danger" show class="mb-3" data-testid="action-error">
+          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
+          {{ admin.actionError.value }}
+        </BAlert>
+        <BAlert v-if="admin.actionMessage.value" variant="info" show class="mb-3" data-testid="action-message">
+          <i class="bi bi-info-circle-fill me-1" aria-hidden="true" />
+          {{ admin.actionMessage.value }}
+        </BAlert>
+
+        <GenericTable :items="releaseRows" :fields="RELEASE_ADMIN_TABLE_FIELDS" :is-busy="loading">
+          <template #cell-status="{ row }">
+            <BBadge :variant="row.status === 'published' ? 'success' : 'secondary'">
+              {{ row.status }}
+            </BBadge>
+          </template>
+          <template #cell-actions="{ row, expansionShowing, toggleExpansion }">
+            <div class="release-actions">
+              <BButton
+                v-if="row.status === 'draft'"
+                size="sm"
+                variant="outline-primary"
+                :data-testid="`publish-${row.release_id}`"
+                @click="admin.publish(row.release_id)"
+              >
+                Publish
+              </BButton>
+              <BButton
+                size="sm"
+                variant="outline-secondary"
+                :data-testid="`toggle-doi-${row.release_id}`"
+                @click="toggleExpansion?.()"
+              >
+                {{ expansionShowing ? 'Hide DOI form' : 'Record DOI' }}
+              </BButton>
+              <template v-if="row.status === 'draft'">
+                <BButton
+                  v-if="pendingDeleteId !== row.release_id"
+                  size="sm"
+                  variant="outline-danger"
+                  :data-testid="`delete-${row.release_id}`"
+                  @click="pendingDeleteId = row.release_id"
+                >
+                  Delete draft
+                </BButton>
+                <template v-else>
+                  <BButton
+                    size="sm"
+                    variant="danger"
+                    :data-testid="`confirm-delete-${row.release_id}`"
+                    @click="handleConfirmDelete(row.release_id)"
+                  >
+                    Confirm delete
+                  </BButton>
+                  <BButton size="sm" variant="outline-secondary" @click="pendingDeleteId = null">
+                    Cancel
+                  </BButton>
+                </template>
+              </template>
+            </div>
+          </template>
+          <template #row-expansion="{ row, toggle }">
+            <div class="doi-form" :data-testid="`doi-form-${row.release_id}`">
+              <div class="doi-form__grid">
+                <div class="doi-form__field">
+                  <label :for="`doi-version-${row.release_id}`" class="form-label fw-semibold">
+                    Version DOI
+                  </label>
+                  <BFormInput
+                    :id="`doi-version-${row.release_id}`"
+                    v-model="doiFormFor(row.release_id).version_doi"
+                    :data-testid="`doi-version-input-${row.release_id}`"
+                  />
+                </div>
+                <div class="doi-form__field">
+                  <label :for="`doi-concept-${row.release_id}`" class="form-label fw-semibold">
+                    Concept DOI
+                  </label>
+                  <BFormInput
+                    :id="`doi-concept-${row.release_id}`"
+                    v-model="doiFormFor(row.release_id).concept_doi"
+                  />
+                </div>
+                <div class="doi-form__field">
+                  <label :for="`doi-zenodo-id-${row.release_id}`" class="form-label fw-semibold">
+                    Zenodo record ID
+                  </label>
+                  <BFormInput
+                    :id="`doi-zenodo-id-${row.release_id}`"
+                    v-model="doiFormFor(row.release_id).zenodo_record_id"
+                  />
+                </div>
+                <div class="doi-form__field">
+                  <label :for="`doi-zenodo-url-${row.release_id}`" class="form-label fw-semibold">
+                    Zenodo record URL
+                  </label>
+                  <BFormInput
+                    :id="`doi-zenodo-url-${row.release_id}`"
+                    v-model="doiFormFor(row.release_id).zenodo_record_url"
+                  />
+                </div>
+              </div>
+              <BButton
+                size="sm"
+                variant="primary"
+                class="mt-2"
+                :data-testid="`save-doi-${row.release_id}`"
+                @click="handleSaveDoi(row.release_id, toggle)"
+              >
+                Save DOI
+              </BButton>
+            </div>
+          </template>
+        </GenericTable>
+
+        <p v-if="!loading && admin.releases.value.length === 0" class="text-muted small mb-0 mt-2">
+          No releases yet.
+        </p>
+      </AdminOperationPanel>
+    </BContainer>
+  </AuthenticatedPageShell>
+</template>
+
+<script setup lang="ts">
+import { computed, onMounted, reactive, ref } from 'vue';
+import { useHead } from '@unhead/vue';
+import { BAlert, BBadge, BButton, BContainer, BFormInput, BFormTextarea, BSpinner } from 'bootstrap-vue-next';
+import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
+import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
+import GenericTable from '@/components/small/GenericTable.vue';
+import type { RecordReleaseDoiFields } from '@/api/admin_analysis_release';
+import { useAnalysisReleaseAdmin, type BuildReleaseFormInput } from './useAnalysisReleaseAdmin';
+
+useHead({ title: 'Manage analysis-snapshot releases' });
+
+const RELEASE_ADMIN_TABLE_FIELDS = [
+  { key: 'release_id', label: 'Release' },
+  { key: 'status', label: 'Status' },
+  { key: 'source_data_version', label: 'Source data version' },
+  { key: 'created_at', label: 'Created' },
+  { key: 'published_at', label: 'Published' },
+  { key: 'file_count', label: 'Files' },
+  { key: 'version_doi', label: 'Version DOI' },
+  { key: 'actions', label: 'Actions' },
+];
+
+/**
+ * Flat display row for the releases table. `GenericDesktopTable.vue` only
+ * wires custom `#cell(<key>)` slots for a fixed, hardcoded set of field keys
+ * (`status` and `actions` here, notably NOT `created_at`/`published_at`/
+ * `version_doi`) — the same BVN gotcha `dataReleaseTable.ts` documents for
+ * the public /DataReleases table. A `field.formatter` silently never runs
+ * either, so display formatting (dates, the DOI dash sentinel) is baked
+ * into the row here rather than attempted via a cell slot or formatter for
+ * an unwired key.
+ */
+interface AdminReleaseTableRow {
+  release_id: string;
+  status: string;
+  source_data_version: string;
+  created_at: string;
+  published_at: string;
+  file_count: number;
+  version_doi: string;
+}
+
+const admin = useAnalysisReleaseAdmin();
+const { loading, building } = admin;
+
+const releaseRows = computed<AdminReleaseTableRow[]>(() =>
+  admin.releases.value.map((release) => ({
+    release_id: release.release_id,
+    status: release.status,
+    source_data_version: release.source_data_version,
+    created_at: formatDate(release.created_at),
+    published_at: formatDate(release.published_at),
+    file_count: release.file_count,
+    version_doi: release.version_doi || '—',
+  }))
+);
+
+const buildForm = reactive<BuildReleaseFormInput>({
+  title: '',
+  scope_statement: '',
+  license: 'CC-BY-4.0',
+  // Safe operator flow: build as a draft by default, review, then publish explicitly.
+  publish: false,
+});
+
+const lockedOutcome = computed(() =>
+  admin.lastBuildOutcome.value?.outcome === 'locked' ? admin.lastBuildOutcome.value : null
+);
+const createdOrExistingOutcome = computed(() => {
+  const outcome = admin.lastBuildOutcome.value;
+  return outcome && outcome.outcome !== 'locked' ? outcome : null;
+});
+
+/** Two-step "Delete draft" confirm state — an in-page affordance, never a native dialog. */
+const pendingDeleteId = ref<string | null>(null);
+
+/** Per-row DOI draft form values, lazily created and kept across expand/collapse. */
+const doiForms = reactive<Record<string, RecordReleaseDoiFields>>({});
+function doiFormFor(releaseId: string): RecordReleaseDoiFields {
+  if (!doiForms[releaseId]) {
+    doiForms[releaseId] = {
+      version_doi: '',
+      concept_doi: '',
+      zenodo_record_id: '',
+      zenodo_record_url: '',
+    };
+  }
+  return doiForms[releaseId];
+}
+
+function formatDate(value: string | null | undefined): string {
+  if (!value) return '—';
+  const parsed = new Date(value);
+  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleString();
+}
+
+async function handleBuild(): Promise<void> {
+  await admin.build({ ...buildForm });
+}
+
+async function handleConfirmDelete(releaseId: string): Promise<void> {
+  await admin.deleteDraft(releaseId);
+  pendingDeleteId.value = null;
+}
+
+async function handleSaveDoi(releaseId: string, toggle: () => void): Promise<void> {
+  await admin.recordDoi(releaseId, { ...doiFormFor(releaseId) });
+  if (!admin.actionError.value) {
+    toggle();
+  }
+}
+
+onMounted(() => {
+  void admin.refreshAll();
+});
+</script>
+
+<style scoped>
+.analysis-release-admin {
+  padding: 0;
+}
+
+.layer-readiness-grid {
+  display: grid;
+  grid-template-columns: repeat(3, minmax(0, 1fr));
+  gap: 0.75rem;
+}
+
+.layer-readiness-item {
+  display: flex;
+  align-items: center;
+  gap: 0.6rem;
+  padding: 0.625rem 0.75rem;
+  border: 1px solid rgba(198, 40, 40, 0.28);
+  border-radius: var(--radius-md, 0.375rem);
+  background: #fff5f5;
+  color: var(--status-danger, #c62828);
+}
+
+.layer-readiness-item--ready {
+  border-color: rgba(46, 125, 50, 0.28);
+  background: #f3fbf4;
+  color: var(--status-success, #2e7d32);
+}
+
+.layer-readiness-item strong {
+  display: block;
+  color: var(--neutral-900, #212121);
+  font-size: 0.875rem;
+}
+
+.layer-readiness-state {
+  display: block;
+  font-size: 0.75rem;
+  text-transform: capitalize;
+}
+
+.layer-readiness-hint {
+  margin-top: 0.85rem;
+  color: var(--neutral-600, #757575);
+  font-size: 0.8125rem;
+}
+
+.layer-readiness-hint code {
+  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
+  font-size: 0.8em;
+}
+
+.build-form {
+  display: grid;
+  gap: 0.85rem;
+  max-width: 32rem;
+}
+
+.build-form__field--checkbox {
+  display: flex;
+  align-items: center;
+  gap: 0.5rem;
+}
+
+.release-actions {
+  display: flex;
+  flex-wrap: wrap;
+  gap: 0.4rem;
+  justify-content: flex-end;
+}
+
+.doi-form {
+  padding: 0.75rem;
+  border: 1px solid rgba(15, 23, 42, 0.08);
+  border-radius: var(--radius-md, 0.375rem);
+  background: #f8fafc;
+}
+
+.doi-form__grid {
+  display: grid;
+  grid-template-columns: repeat(2, minmax(0, 1fr));
+  gap: 0.75rem;
+}
+
+@media (max-width: 767.98px) {
+  .layer-readiness-grid {
+    grid-template-columns: 1fr;
+  }
+
+  .doi-form__grid {
+    grid-template-columns: 1fr;
+  }
+}
+</style>
diff --git a/app/src/views/admin/useAnalysisReleaseAdmin.ts b/app/src/views/admin/useAnalysisReleaseAdmin.ts
new file mode 100644
index 00000000..c033754a
--- /dev/null
+++ b/app/src/views/admin/useAnalysisReleaseAdmin.ts
@@ -0,0 +1,220 @@
+// app/src/views/admin/useAnalysisReleaseAdmin.ts
+//
+// Co-located composable for the `ManageAnalysisReleases.vue` Administrator
+// view (#573 Slice B, Task B4b). Owns every client call from the typed
+// admin release client (`@/api/admin_analysis_release`, Task B4a) plus the
+// reactive state the view renders, so the `.vue` stays a thin template.
+// Mirrors the `./useNddScoreAdminDerivedRows` co-location convention.
+//
+// The build is SYNCHRONOUS and DB-only (no async job/worker involved) —
+// `build()` is a single request/response round trip, not a job poll.
+
+import { computed, ref, type ComputedRef, type Ref } from 'vue';
+import {
+  buildRelease,
+  deleteDraftRelease,
+  fetchSnapshotStatus,
+  listAdminReleases,
+  publishRelease,
+  recordReleaseDoi,
+  RELEASE_LAYER_TYPES,
+  type AdminReleaseHead,
+  type BuildReleaseRequest,
+  type BuildReleaseResult,
+  type RecordReleaseDoiFields,
+  type SnapshotPresetState,
+  type SnapshotStatusResponse,
+} from '@/api/admin_analysis_release';
+import { extractApiErrorMessage } from '@/utils/api-errors';
+
+/** Human-readable label for each release layer, keyed by `analysis_type`. */
+const RELEASE_LAYER_LABELS: Record<(typeof RELEASE_LAYER_TYPES)[number], string> = {
+  functional_clusters: 'Functional clusters',
+  phenotype_clusters: 'Phenotype clusters',
+  phenotype_functional_correlations: 'Phenotype-functional correlation',
+};
+
+export interface LayerReadinessItem {
+  analysis_type: (typeof RELEASE_LAYER_TYPES)[number];
+  label: string;
+  /** `'missing'` when the preset is absent from the status response entirely. */
+  state: SnapshotPresetState['state'] | 'missing';
+}
+
+/** Build-form fields the view collects — the fixed default layer registry is always used. */
+export type BuildReleaseFormInput = Omit<BuildReleaseRequest, 'layers'>;
+
+export interface UseAnalysisReleaseAdmin {
+  releases: Ref<AdminReleaseHead[]>;
+  status: Ref<SnapshotStatusResponse | null>;
+  loading: Ref<boolean>;
+  buildError: Ref<string | null>;
+  building: Ref<boolean>;
+  lastBuildOutcome: Ref<BuildReleaseResult | null>;
+  actionError: Ref<string | null>;
+  actionMessage: Ref<string | null>;
+  canBuild: ComputedRef<boolean>;
+  layerReadiness: ComputedRef<LayerReadinessItem[]>;
+  loadReleases: () => Promise<void>;
+  loadStatus: () => Promise<void>;
+  refreshAll: () => Promise<void>;
+  build: (input: BuildReleaseFormInput) => Promise<void>;
+  publish: (releaseId: string) => Promise<void>;
+  recordDoi: (releaseId: string, fields: RecordReleaseDoiFields) => Promise<void>;
+  deleteDraft: (releaseId: string) => Promise<void>;
+}
+
+/** Drops undefined/null/empty-string values so the client only receives filled DOI fields. */
+function nonEmptyDoiFields(fields: RecordReleaseDoiFields): RecordReleaseDoiFields {
+  const result: RecordReleaseDoiFields = {};
+  (Object.keys(fields) as (keyof RecordReleaseDoiFields)[]).forEach((key) => {
+    const value = fields[key];
+    if (value !== undefined && value !== null && value !== '') {
+      result[key] = value;
+    }
+  });
+  return result;
+}
+
+export function useAnalysisReleaseAdmin(): UseAnalysisReleaseAdmin {
+  const releases = ref<AdminReleaseHead[]>([]);
+  const status = ref<SnapshotStatusResponse | null>(null);
+  const loading = ref(false);
+  const buildError = ref<string | null>(null);
+  const building = ref(false);
+  const lastBuildOutcome = ref<BuildReleaseResult | null>(null);
+  const actionError = ref<string | null>(null);
+  const actionMessage = ref<string | null>(null);
+
+  const canBuild = computed<boolean>(() => {
+    const current = status.value;
+    if (!current) return false;
+    return RELEASE_LAYER_TYPES.every(
+      (type) => current.presets.find((preset) => preset.analysis_type === type)?.state === 'available'
+    );
+  });
+
+  const layerReadiness = computed<LayerReadinessItem[]>(() =>
+    RELEASE_LAYER_TYPES.map((type) => ({
+      analysis_type: type,
+      label: RELEASE_LAYER_LABELS[type],
+      state: status.value?.presets.find((preset) => preset.analysis_type === type)?.state ?? 'missing',
+    }))
+  );
+
+  async function loadReleases(): Promise<void> {
+    try {
+      const response = await listAdminReleases();
+      releases.value = response.releases;
+    } catch (err) {
+      actionError.value = extractApiErrorMessage(
+        err,
+        'Failed to load analysis-snapshot releases.'
+      );
+    }
+  }
+
+  async function loadStatus(): Promise<void> {
+    try {
+      status.value = await fetchSnapshotStatus();
+    } catch (err) {
+      actionError.value = extractApiErrorMessage(
+        err,
+        'Failed to load snapshot readiness status.'
+      );
+    }
+  }
+
+  async function refreshAll(): Promise<void> {
+    loading.value = true;
+    try {
+      await Promise.all([loadReleases(), loadStatus()]);
+    } finally {
+      loading.value = false;
+    }
+  }
+
+  async function build(input: BuildReleaseFormInput): Promise<void> {
+    buildError.value = null;
+    lastBuildOutcome.value = null;
+    building.value = true;
+    try {
+      const { license, ...rest } = input;
+      const payload: BuildReleaseRequest = { ...rest, publish: input.publish ?? false };
+      // The endpoint only substitutes its "CC-BY-4.0" default on a missing/NULL
+      // `license`, not on an empty string — so a cleared license input must omit
+      // the key entirely (not forward `""`) for the server default to apply.
+      if (license?.trim()) {
+        payload.license = license;
+      }
+      const outcome = await buildRelease(payload);
+      lastBuildOutcome.value = outcome;
+      if (outcome.outcome === 'created' || outcome.outcome === 'exists') {
+        await loadReleases();
+      }
+    } catch (err) {
+      buildError.value = extractApiErrorMessage(
+        err,
+        'Failed to build the analysis-snapshot release.'
+      );
+    } finally {
+      building.value = false;
+    }
+  }
+
+  async function publish(releaseId: string): Promise<void> {
+    actionError.value = null;
+    actionMessage.value = null;
+    try {
+      const updated = await publishRelease(releaseId);
+      actionMessage.value = `Release ${updated.release_id} published.`;
+      await loadReleases();
+    } catch (err) {
+      actionError.value = extractApiErrorMessage(err, 'Failed to publish the release.');
+    }
+  }
+
+  async function recordDoi(releaseId: string, fields: RecordReleaseDoiFields): Promise<void> {
+    actionError.value = null;
+    actionMessage.value = null;
+    try {
+      await recordReleaseDoi(releaseId, nonEmptyDoiFields(fields));
+      actionMessage.value = 'DOI metadata recorded.';
+      await loadReleases();
+    } catch (err) {
+      actionError.value = extractApiErrorMessage(err, 'Failed to record DOI metadata.');
+    }
+  }
+
+  async function deleteDraft(releaseId: string): Promise<void> {
+    actionError.value = null;
+    actionMessage.value = null;
+    try {
+      await deleteDraftRelease(releaseId);
+      actionMessage.value = 'Draft release deleted.';
+      await loadReleases();
+    } catch (err) {
+      actionError.value = extractApiErrorMessage(err, 'Failed to delete the draft release.');
+    }
+  }
+
+  return {
+    releases,
+    status,
+    loading,
+    buildError,
+    building,
+    lastBuildOutcome,
+    actionError,
+    actionMessage,
+    canBuild,
+    layerReadiness,
+    loadReleases,
+    loadStatus,
+    refreshAll,
+    build,
+    publish,
+    recordDoi,
+    deleteDraft,
+  };
+}
diff --git a/app/src/views/analyses/DataReleases.vue b/app/src/views/analyses/DataReleases.vue
new file mode 100644
index 00000000..e6d7bc11
--- /dev/null
+++ b/app/src/views/analyses/DataReleases.vue
@@ -0,0 +1,376 @@
+<!-- src/views/analyses/DataReleases.vue -->
+<!--
+  Public, unauthenticated page for analysis-snapshot releases (#573 Slice B,
+  Task B2): immutable, content-addressed exports of the derived-analysis
+  public snapshots (functional clusters, phenotype clusters, phenotype-
+  functional correlation). Composes:
+    - AnalysisShell (title/subtitle chrome, matches every other analysis view)
+    - a releases table (GenericTable, fields from dataReleaseTable.ts)
+    - the selected release's manifest/provenance card (ReleaseManifestPanel)
+    - download actions (bundle.tar.gz, manifest.json, per-file) and a
+      factual "how to verify" disclosure.
+
+  Data flow: `listReleases()` populates the table; `getLatestRelease()`
+  populates the initial manifest panel; selecting a row re-fetches via
+  `getRelease(release_id)`. `getLatestRelease()` 404s when no release has
+  been published yet — that is NOT an error, it is the "no releases yet"
+  empty state (SectionCard's `empty` prop collapses to nothing per its own
+  contract, so the empty message is rendered from the default slot instead,
+  via the existing `ui/EmptyState.vue`).
+-->
+<template>
+  <AnalysisShell
+    title="Analysis-snapshot releases"
+    subtitle="Immutable, content-addressed exports of SysNDD's public derived analysis (functional clusters, phenotype clusters, and their correlation) — download and independently verify what you get."
+  >
+    <SectionCard
+      title="Published releases"
+      :loading="listLoading"
+      :empty="false"
+      :error="listError"
+    >
+      <GenericTable :items="releaseRows" :fields="RELEASE_TABLE_FIELDS">
+        <template #cell-actions="{ row }">
+          <BButton
+            size="sm"
+            variant="outline-primary"
+            :aria-label="`View manifest for release ${row.release_id}`"
+            @click="selectRelease(row.release_id)"
+          >
+            View manifest
+          </BButton>
+        </template>
+      </GenericTable>
+    </SectionCard>
+
+    <SectionCard
+      title="Release manifest & verification"
+      class="data-releases__manifest-card"
+      :loading="detailLoading"
+      :empty="false"
+      :error="detailError"
+    >
+      <template v-if="selectedRelease">
+        <ReleaseManifestPanel :release="selectedRelease" />
+
+        <section class="data-releases__downloads" aria-label="Downloads">
+          <h3 class="data-releases__section-title">Downloads</h3>
+          <div class="data-releases__download-buttons">
+            <BButton
+              size="sm"
+              variant="primary"
+              data-testid="download-bundle-button"
+              @click="handleDownloadBundle"
+            >
+              <i class="bi bi-file-earmark-zip" aria-hidden="true" />
+              Download bundle.tar.gz
+            </BButton>
+            <BButton
+              size="sm"
+              variant="outline-secondary"
+              data-testid="download-manifest-button"
+              @click="handleDownloadManifest"
+            >
+              <i class="bi bi-file-earmark-code" aria-hidden="true" />
+              Download manifest.json
+            </BButton>
+          </div>
+
+          <div v-if="selectedRelease.manifest.files.length" class="data-releases__files">
+            <h4 class="data-releases__section-subtitle">Individual files</h4>
+            <ul class="data-releases__file-list">
+              <li v-for="file in selectedRelease.manifest.files" :key="file.path">
+                <button
+                  type="button"
+                  class="data-releases__file-link"
+                  @click="handleDownloadFile(file.path)"
+                >
+                  {{ file.path }}
+                </button>
+                <span class="data-releases__file-size">({{ formatReleaseBytes(file.bytes) }})</span>
+              </li>
+            </ul>
+          </div>
+        </section>
+
+        <details class="data-releases__verify">
+          <summary>How to verify a download</summary>
+          <ul>
+            <li>
+              Recompute the SHA-256 of each downloaded file and compare it against
+              <code>manifest.files[].sha256</code> (or the top-level <code>checksums.sha256</code>
+              file in the bundle).
+            </li>
+            <li>
+              For the functional and phenotype cluster layers,
+              <code>sha256(reproducibility.json)</code> matches that layer's
+              <code>reproducibility_hash</code> exactly — the phenotype-functional correlation
+              layer has no reproducibility bundle (<code>reproducibility_hash</code> is
+              <code>null</code>).
+            </li>
+            <li>
+              <code>payload_hash</code>, <code>input_hash</code>, and <code>snapshot_id</code> are
+              lineage anchors: cross-check them against the live <code>meta.snapshot</code> block
+              on the matching <code>/api/analysis/*</code> endpoint. They are
+              <strong>not</strong> a hash of this release's own <code>payload.json</code> — the
+              values round-trip through <code>DECIMAL</code> database columns before the release
+              freezes them, so a byte-for-byte match of the payload file is neither guaranteed nor
+              attempted.
+            </li>
+          </ul>
+        </details>
+      </template>
+      <EmptyState
+        v-else-if="!detailLoading && !detailError"
+        icon="archive"
+        title="No releases published yet"
+        message="Analysis-snapshot releases are published periodically once public snapshots are available. Check back soon."
+      />
+    </SectionCard>
+  </AnalysisShell>
+</template>
+
+<script setup lang="ts">
+import { onMounted, ref } from 'vue';
+import { useHead } from '@unhead/vue';
+import { BButton } from 'bootstrap-vue-next';
+import AnalysisShell from '@/components/analyses/AnalysisShell.vue';
+import SectionCard from '@/components/ui/SectionCard.vue';
+import EmptyState from '@/components/ui/EmptyState.vue';
+import GenericTable from '@/components/small/GenericTable.vue';
+import ReleaseManifestPanel from '@/components/analyses/ReleaseManifestPanel.vue';
+import {
+  normalizeReleaseRows,
+  formatReleaseBytes,
+  RELEASE_TABLE_FIELDS,
+  type ReleaseTableRow,
+} from '@/components/analyses/dataReleaseTable';
+import {
+  listReleases,
+  getLatestRelease,
+  getRelease,
+  downloadReleaseBundle,
+  downloadReleaseManifest,
+  downloadReleaseFile,
+  type ReleaseDetail,
+} from '@/api/analysis';
+import { isApiError } from '@/api/client';
+import { extractApiErrorMessage } from '@/utils/api-errors';
+import useToast from '@/composables/useToast';
+
+defineOptions({
+  name: 'DataReleases',
+});
+
+useHead({
+  title: 'Analysis-snapshot releases',
+  meta: [
+    {
+      name: 'description',
+      content:
+        "Download and independently verify SysNDD's immutable, content-addressed analysis-snapshot releases: functional gene clusters, phenotype clusters, and their correlation.",
+    },
+  ],
+});
+
+const { makeToast } = useToast();
+
+const releaseRows = ref<ReleaseTableRow[]>([]);
+const listLoading = ref(true);
+const listError = ref<string | null>(null);
+
+const selectedRelease = ref<ReleaseDetail | null>(null);
+const detailLoading = ref(true);
+const detailError = ref<string | null>(null);
+
+/**
+ * MEDIUM (#573 Slice B Codex round-1 review): monotonic request token
+ * guarding against a stale-response race. If the mount-time
+ * `getLatestRelease()` resolves AFTER the user has since clicked "View
+ * manifest" on another row (a newer `getRelease(id)` request), the late
+ * response must not overwrite `selectedRelease` with the wrong release.
+ */
+let detailRequestSeq = 0;
+
+async function loadList(): Promise<void> {
+  listLoading.value = true;
+  listError.value = null;
+  try {
+    const response = await listReleases();
+    releaseRows.value = normalizeReleaseRows(response.releases);
+  } catch (err) {
+    listError.value = extractApiErrorMessage(err, 'Failed to load analysis-snapshot releases.');
+  } finally {
+    listLoading.value = false;
+  }
+}
+
+/**
+ * Loads a release detail (head + manifest) via the given fetcher. A 404 is
+ * the "no published release" empty state, not an error — see the file
+ * header for why that renders through the default slot rather than
+ * SectionCard's `empty` prop.
+ */
+async function loadDetail(fetcher: () => Promise<ReleaseDetail>): Promise<void> {
+  const token = ++detailRequestSeq;
+  detailLoading.value = true;
+  detailError.value = null;
+  try {
+    const result = await fetcher();
+    if (token !== detailRequestSeq) return; // a newer request has since started; discard
+    selectedRelease.value = result;
+  } catch (err) {
+    if (token !== detailRequestSeq) return; // a newer request has since started; discard
+    selectedRelease.value = null;
+    if (!(isApiError(err) && err.response?.status === 404)) {
+      detailError.value = extractApiErrorMessage(err, 'Failed to load the release manifest.');
+    }
+  } finally {
+    if (token === detailRequestSeq) {
+      detailLoading.value = false;
+    }
+  }
+}
+
+function selectRelease(releaseId: string): void {
+  void loadDetail(() => getRelease(releaseId));
+}
+
+/** Triggers a browser download for a Blob via a transient object-URL anchor. */
+function triggerBlobDownload(blob: Blob, filename: string): void {
+  const url = window.URL.createObjectURL(blob);
+  const link = document.createElement('a');
+  link.href = url;
+  link.setAttribute('download', filename);
+  document.body.appendChild(link);
+  link.click();
+  document.body.removeChild(link);
+  window.URL.revokeObjectURL(url);
+}
+
+async function handleDownloadBundle(): Promise<void> {
+  const release = selectedRelease.value;
+  if (!release) return;
+  try {
+    const blob = await downloadReleaseBundle(release.release_id);
+    triggerBlobDownload(blob, `${release.release_id}_bundle.tar.gz`);
+  } catch (err) {
+    makeToast(extractApiErrorMessage(err, 'Bundle download failed.'), 'Error', 'danger');
+  }
+}
+
+async function handleDownloadManifest(): Promise<void> {
+  const release = selectedRelease.value;
+  if (!release) return;
+  try {
+    const blob = await downloadReleaseManifest(release.release_id);
+    triggerBlobDownload(blob, `${release.release_id}_manifest.json`);
+  } catch (err) {
+    makeToast(extractApiErrorMessage(err, 'Manifest download failed.'), 'Error', 'danger');
+  }
+}
+
+async function handleDownloadFile(path: string): Promise<void> {
+  const release = selectedRelease.value;
+  if (!release) return;
+  try {
+    const blob = await downloadReleaseFile(release.release_id, path);
+    triggerBlobDownload(blob, path.split('/').pop() || path);
+  } catch (err) {
+    makeToast(extractApiErrorMessage(err, 'File download failed.'), 'Error', 'danger');
+  }
+}
+
+onMounted(() => {
+  void loadList();
+  void loadDetail(() => getLatestRelease());
+});
+</script>
+
+<style scoped>
+.data-releases__manifest-card {
+  margin-top: 1rem;
+}
+
+.data-releases__section-title {
+  margin: 0 0 0.5rem;
+  color: var(--neutral-700, #616161);
+  font-size: 0.8125rem;
+  font-weight: 700;
+  text-transform: uppercase;
+  letter-spacing: 0.02em;
+}
+
+.data-releases__section-subtitle {
+  margin: 0.75rem 0 0.35rem;
+  color: var(--neutral-700, #616161);
+  font-size: 0.8125rem;
+  font-weight: 700;
+}
+
+.data-releases__downloads {
+  margin-top: 0.85rem;
+  padding-top: 0.85rem;
+  border-top: 1px solid var(--border-subtle, #e1e7ef);
+}
+
+.data-releases__download-buttons {
+  display: flex;
+  flex-wrap: wrap;
+  gap: 0.5rem;
+}
+
+.data-releases__file-list {
+  margin: 0;
+  padding-left: 1.1rem;
+  font-size: 0.8125rem;
+}
+
+.data-releases__file-list li {
+  margin-bottom: 0.2rem;
+}
+
+.data-releases__file-link {
+  border: none;
+  background: none;
+  padding: 0;
+  color: var(--medical-blue-700, #0d47a1);
+  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
+  text-decoration: underline;
+  cursor: pointer;
+}
+
+.data-releases__file-size {
+  margin-left: 0.35rem;
+  color: var(--neutral-600, #757575);
+}
+
+.data-releases__verify {
+  margin-top: 0.85rem;
+  padding-top: 0.85rem;
+  border-top: 1px solid var(--border-subtle, #e1e7ef);
+  font-size: 0.85rem;
+  color: var(--neutral-700, #4b5563);
+}
+
+.data-releases__verify summary {
+  cursor: pointer;
+  font-weight: 700;
+  color: var(--neutral-900, #212121);
+}
+
+.data-releases__verify ul {
+  margin: 0.5rem 0 0;
+  padding-left: 1.1rem;
+}
+
+.data-releases__verify li {
+  margin-bottom: 0.4rem;
+  line-height: 1.5;
+}
+
+.data-releases__verify code {
+  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
+  font-size: 0.8em;
+}
+</style>

exec
/bin/bash -lc "nl -ba api/services/analysis-snapshot-release-service.R | sed -n '1,190p'; rg -n -C 5 'release_lock_unavailable|Retry-After|analysis_release_condition|make_problem_response' api/functions api/services api/core api/endpoints | head -n 240; rg -n -C 4 'function\\(.*errorHandler|errorHandler|mount_endpoint' api/start_sysndd_api.R api/core api/functions | head -n 260; rg -n 'safeHttpUrl|ReleaseManifestGenerator|detailRequestSeq|failed DOI-save|failed draft-deletion' app/src" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
     1	# services/analysis-snapshot-release-service.R
     2	#
     3	# Service layer for immutable, content-addressed public analysis-snapshot
     4	# RELEASES (#573 Slice A / Task A5). Shapes the A4 build orchestrator
     5	# (`functions/analysis-snapshot-release.R`) and the A3 repository
     6	# (`functions/analysis-snapshot-release-repository.R`) into problem+json HTTP
     7	# semantics for the endpoint layer (wired into `bootstrap/load_modules.R` by
     8	# Task A8).
     9	#
    10	# ERROR CONTRACT. Only the FOUR existing error classes exist in this repo:
    11	# 400 (`stop_for_bad_request`), 401, 403 (`stop_for_forbidden`, enforced by
    12	# the endpoint's `require_role()`, not here), and 404 (`stop_for_not_found`).
    13	# There is deliberately NO 409 class — a "sources not ready" build rejection
    14	# is a 400, not a conflict. The mounted errorHandler (`core/filters.R`)
    15	# serializes `conditionMessage(err)` (the classed condition's `message`) into
    16	# the problem+json body, NOT `detail` — so every user-facing reason is passed
    17	# as the `message` argument to `stop_for_*()`, never `detail`.
    18	#
    19	# BUILD MAPPING. `svc_release_build()` calls the A4 orchestrator inside a
    20	# `tryCatch()` that maps its five classed `release_*` conditions
    21	# (`release_snapshot_not_available`, `release_source_incoherent`,
    22	# `release_reproducibility_missing`, `release_source_version_mismatch`,
    23	# `release_dependency_lineage_mismatch`) to `stop_for_bad_request()`, passing
    24	# the ORIGINAL `conditionMessage()` through verbatim (it already names the
    25	# failing layer/analysis_type and the concrete reason). Any OTHER error is
    26	# left to propagate unmapped (falls through to the generic 500 path). A
    27	# DUPLICATE/idempotent build (`created = FALSE`) is NOT an error: the caller
    28	# gets 200 + the existing head instead of 201 + the new head.
    29	#
    30	# PUBLIC SURFACE. `svc_release_list/get/manifest/file/bundle()` are the
    31	# published-only public read surface: every repository call is pinned to
    32	# `status = "published"` / `include_draft = FALSE`, so a draft release (or an
    33	# unknown release id, or an unknown archive file path) is indistinguishable
    34	# from the caller's point of view — both resolve to a plain 404. Drafts are
    35	# NEVER returned publicly.
    36	#
    37	# ADMIN SURFACE. `svc_release_build/publish/set_doi/delete_draft()` are
    38	# admin-only from the caller's perspective (the endpoint layer is expected to
    39	# gate with `require_role(req, res, "Administrator")` before calling in, the
    40	# same pattern as the other `svc_*` admin services in this directory); this
    41	# file does not itself check roles.
    42	#
    43	# `svc_` prefix avoids shadowing the `analysis_release_*`/
    44	# `analysis_snapshot_release_build` repository/orchestrator functions in the
    45	# global search path (AGENTS.md service-prefix invariant).
    46
    47	# --------------------------------------------------------------------------- #
    48	# Admin
    49	# --------------------------------------------------------------------------- #
    50
    51	#' Build (and, by default, publish) a new analysis-snapshot release.
    52	#'
    53	#' Thin problem+json shim over `analysis_snapshot_release_build()`. On
    54	#' success mutates `res$status` (201 for a newly-created release, 200 for an
    55	#' idempotent duplicate) and returns the release head. On a gate failure
    56	#' (any of the five classed `release_*` conditions), raises a 400 whose
    57	#' message is the original `conditionMessage()` verbatim. Any other error
    58	#' propagates unmapped.
    59	#'
    60	#' @param res Plumber response, mutated in place (`$status`).
    61	#' @param layers Optional layer registry override; when `NULL` the
    62	#'   orchestrator's own default (`analysis_snapshot_release_layers()`) is
    63	#'   used — `layers` is only forwarded when the caller supplies one.
    64	#' @param title,scope_statement,license Presentation metadata.
    65	#' @param publish Whether to flip the inserted draft to `published`.
    66	#' @param created_by Optional user id recorded on the head row.
    67	#' @param conn A real DBIConnection (the orchestrator persists via A3).
    68	#' @return The release head (a named list).
    69	#' @export
    70	svc_release_build <- function(res,
    71	                               layers = NULL,
    72	                               title = NULL,
    73	                               scope_statement = NULL,
    74	                               license = "CC-BY-4.0",
    75	                               publish = TRUE,
    76	                               created_by = NULL,
    77	                               conn = NULL) {
    78	  build_args <- list(
    79	    title = title,
    80	    scope_statement = scope_statement,
    81	    license = license,
    82	    publish = publish,
    83	    created_by = created_by,
    84	    conn = conn
    85	  )
    86	  if (!is.null(layers)) {
    87	    build_args$layers <- layers
    88	  }
    89
    90	  result <- tryCatch(
    91	    do.call(analysis_snapshot_release_build, build_args),
    92	    # `release_lock_unavailable` (H3): sources are mid-refresh — a transient 503
    93	    # with Retry-After, NOT a 400. Handled here (like the public capacity guard)
    94	    # via a direct res mutation because there is no 5xx classed error helper.
    95	    release_lock_unavailable = function(e) {
    96	      res$status <- 503L
    97	      res$setHeader("Retry-After", "5")
    98	      list(
    99	        error = "release_lock_unavailable",
   100	        message = conditionMessage(e)
   101	      )
   102	    },
   103	    release_snapshot_not_available = function(e) stop_for_bad_request(conditionMessage(e)),
   104	    release_source_incoherent = function(e) stop_for_bad_request(conditionMessage(e)),
   105	    release_reproducibility_missing = function(e) stop_for_bad_request(conditionMessage(e)),
   106	    release_source_version_mismatch = function(e) stop_for_bad_request(conditionMessage(e)),
   107	    release_dependency_lineage_mismatch = function(e) stop_for_bad_request(conditionMessage(e))
   108	  )
   109
   110	  # The 503 handler already set res$status + body; return it verbatim.
   111	  if (!is.null(res$status) && identical(as.integer(res$status), 503L)) {
   112	    return(result)
   113	  }
   114
   115	  res$status <- if (isTRUE(result$created)) 201L else 200L
   116	  result$release
   117	}
   118
   119	#' Publish a draft release.
   120	#'
   121	#' Publishing an unknown release id is the only failure mode (404).
   122	#' Publishing an already-published release is an idempotent no-op (the
   123	#' repository's `analysis_release_publish()` already no-ops when the row is
   124	#' not currently a draft) — either way the caller gets the current head back.
   125	#'
   126	#' @param release_id Release id (`asr_<16 hex>`).
   127	#' @param conn A real DBIConnection.
   128	#' @return The (published) release head.
   129	#' @export
   130	svc_release_publish <- function(release_id, conn = NULL) {
   131	  analysis_release_publish(release_id, conn = conn)
   132	  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   133	  if (is.null(head)) {
   134	    stop_for_not_found(sprintf("Release '%s' not found", release_id))
   135	  }
   136	  head
   137	}
   138
   139	#' Record external Zenodo/DOI provenance on an existing release.
   140	#'
   141	#' Additive metadata only (forwarded verbatim to the repository, which never
   142	#' touches `content_digest`/`manifest_sha256` — release scientific identity
   143	#' is immutable once minted). Unknown release id -> 404.
   144	#'
   145	#' @param release_id Release id.
   146	#' @param doi_fields Named list, any subset of `zenodo_record_id`,
   147	#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
   148	#' @param conn A real DBIConnection.
   149	#' @return The updated release head.
   150	#' @export
   151	svc_release_set_doi <- function(release_id, doi_fields, conn = NULL) {
   152	  analysis_release_set_doi(release_id, doi_fields = doi_fields, conn = conn)
   153	  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   154	  if (is.null(head)) {
   155	    stop_for_not_found(sprintf("Release '%s' not found", release_id))
   156	  }
   157	  head
   158	}
   159
   160	#' Delete a draft release (e.g. a failed/aborted build).
   161	#'
   162	#' Unknown release id -> 404. A published release is immutable/retained
   163	#' indefinitely -> 400 (only drafts are deletable). A draft is deleted and
   164	#' `list(deleted = TRUE, release_id = release_id)` is returned.
   165	#'
   166	#' @param release_id Release id.
   167	#' @param conn A real DBIConnection.
   168	#' @return `list(deleted = TRUE, release_id = release_id)`.
   169	#' @export
   170	svc_release_delete_draft <- function(release_id, conn = NULL) {
   171	  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   172	  if (is.null(head)) {
   173	    stop_for_not_found(sprintf("Release '%s' not found", release_id))
   174	  }
   175	  if (!identical(as.character(head$status), "draft")) {
   176	    stop_for_bad_request("Cannot delete a published release; only drafts are deletable")
   177	  }
   178	  analysis_release_delete_draft(release_id, conn = conn)
   179	  list(deleted = TRUE, release_id = release_id)
   180	}
   181
   182	# --------------------------------------------------------------------------- #
   183	# Public (published-only)
   184	# --------------------------------------------------------------------------- #
   185
   186	#' List published releases (newest first).
   187	#'
   188	#' `limit` is clamped to `[1, 100]` and `offset` to `>= 0` (L1: public
   189	#' pagination must never be unbounded or negative — this is the single source of
   190	#' the clamp). Each returned head is projected to the PUBLIC allowlist
api/endpoints/analysis_endpoints.R-18-
api/endpoints/analysis_endpoints.R-19-analysis_snapshot_endpoint_response <- function(snapshot_result, res) {
api/endpoints/analysis_endpoints.R-20-  if (!is.null(snapshot_result$status) && snapshot_result$status >= 400L) {
api/endpoints/analysis_endpoints.R-21-    res$status <- snapshot_result$status
api/endpoints/analysis_endpoints.R-22-    if (!is.null(snapshot_result$retry_after)) {
api/endpoints/analysis_endpoints.R:23:      res$setHeader("Retry-After", as.character(snapshot_result$retry_after))
api/endpoints/analysis_endpoints.R-24-    }
api/endpoints/analysis_endpoints.R-25-    return(snapshot_result$body)
api/endpoints/analysis_endpoints.R-26-  }
api/endpoints/analysis_endpoints.R-27-
api/endpoints/analysis_endpoints.R-28-  snapshot_result$body
--
api/endpoints/jobs_endpoints.R-129-## -------------------------------------------------------------------##
api/endpoints/jobs_endpoints.R-130-
api/endpoints/jobs_endpoints.R-131-#* Get Job Status
api/endpoints/jobs_endpoints.R-132-#*
api/endpoints/jobs_endpoints.R-133-#* Poll job status and retrieve results when complete.
api/endpoints/jobs_endpoints.R:134:#* Returns Retry-After header for running jobs.
api/endpoints/jobs_endpoints.R-135-#*
api/endpoints/jobs_endpoints.R-136-#* @tag jobs
api/endpoints/jobs_endpoints.R-137-#* @serializer json list(na="string", auto_unbox=TRUE)
api/endpoints/jobs_endpoints.R-138-#* @get /<job_id>/status
api/endpoints/jobs_endpoints.R-139-function(job_id, result_mode = "summary", req, res) {
--
api/endpoints/jobs_network_layout_endpoints.R-46-  job_id <- job$job_id[[1]]
api/endpoints/jobs_network_layout_endpoints.R-47-  status_url <- paste0("/api/jobs/", job_id, "/status")
api/endpoints/jobs_network_layout_endpoints.R-48-
api/endpoints/jobs_network_layout_endpoints.R-49-  res$status <- if (isTRUE(submitted$duplicate)) 409L else 202L
api/endpoints/jobs_network_layout_endpoints.R-50-  res$setHeader("Location", status_url)
api/endpoints/jobs_network_layout_endpoints.R:51:  res$setHeader("Retry-After", "10")
api/endpoints/jobs_network_layout_endpoints.R-52-
api/endpoints/jobs_network_layout_endpoints.R-53-  list(
api/endpoints/jobs_network_layout_endpoints.R-54-    job_id = job_id,
api/endpoints/jobs_network_layout_endpoints.R-55-    status = if (isTRUE(submitted$duplicate)) "already_running" else "accepted",
api/endpoints/jobs_network_layout_endpoints.R-56-    job_status = job$status[[1]],
--
api/core/filters.R-253-  # Get request path for 'instance' field (RFC 9457)
api/core/filters.R-254-  instance <- tryCatch(req$PATH_INFO, error = function(e) NULL)
api/core/filters.R-255-
api/core/filters.R-256-  # Helper to create RFC 9457 problem response
api/core/filters.R-257-  # Uses unbox() wrapper for proper scalar serialization
api/core/filters.R:258:  make_problem_response <- function(title, status_code, detail_msg) {
api/core/filters.R-259-    res$status <- status_code
api/core/filters.R-260-    # serializer_unboxed_json sets Content-Type to problem+json exactly once;
api/core/filters.R-261-    # a manual setHeader plus the serializer's own type yields a duplicate header.
api/core/filters.R-262-    res$serializer <- plumber::serializer_unboxed_json(type = "application/problem+json")
api/core/filters.R-263-    list(
--
api/core/filters.R-270-  }
api/core/filters.R-271-
api/core/filters.R-272-  # Handle custom classed errors from core/errors.R
api/core/filters.R-273-  # Create RFC 9457 problem details directly based on error class
api/core/filters.R-274-  if (inherits(err, "error_400")) {
api/core/filters.R:275:    return(make_problem_response("Bad Request", 400, err_msg))
api/core/filters.R-276-  }
api/core/filters.R-277-
api/core/filters.R-278-  if (inherits(err, "error_401")) {
api/core/filters.R:279:    return(make_problem_response("Unauthorized", 401, err_msg))
api/core/filters.R-280-  }
api/core/filters.R-281-
api/core/filters.R-282-  if (inherits(err, "error_403")) {
api/core/filters.R:283:    return(make_problem_response("Forbidden", 403, err_msg))
api/core/filters.R-284-  }
api/core/filters.R-285-
api/core/filters.R-286-  if (inherits(err, "error_404")) {
api/core/filters.R:287:    return(make_problem_response("Not Found", 404, err_msg))
api/core/filters.R-288-  }
api/core/filters.R-289-
api/core/filters.R-290-  # Unhandled exception = 500 Internal Server Error
api/core/filters.R-291-  # Don't expose internal details to client
api/core/filters.R:292:  return(make_problem_response("Internal Server Error", 500, "An unexpected error occurred"))
api/core/filters.R-293-}
--
api/services/analysis-snapshot-release-service.R-87-    build_args$layers <- layers
api/services/analysis-snapshot-release-service.R-88-  }
api/services/analysis-snapshot-release-service.R-89-
api/services/analysis-snapshot-release-service.R-90-  result <- tryCatch(
api/services/analysis-snapshot-release-service.R-91-    do.call(analysis_snapshot_release_build, build_args),
api/services/analysis-snapshot-release-service.R:92:    # `release_lock_unavailable` (H3): sources are mid-refresh — a transient 503
api/services/analysis-snapshot-release-service.R:93:    # with Retry-After, NOT a 400. Handled here (like the public capacity guard)
api/services/analysis-snapshot-release-service.R-94-    # via a direct res mutation because there is no 5xx classed error helper.
api/services/analysis-snapshot-release-service.R:95:    release_lock_unavailable = function(e) {
api/services/analysis-snapshot-release-service.R-96-      res$status <- 503L
api/services/analysis-snapshot-release-service.R:97:      res$setHeader("Retry-After", "5")
api/services/analysis-snapshot-release-service.R-98-      list(
api/services/analysis-snapshot-release-service.R:99:        error = "release_lock_unavailable",
api/services/analysis-snapshot-release-service.R-100-        message = conditionMessage(e)
api/services/analysis-snapshot-release-service.R-101-      )
api/services/analysis-snapshot-release-service.R-102-    },
api/services/analysis-snapshot-release-service.R-103-    release_snapshot_not_available = function(e) stop_for_bad_request(conditionMessage(e)),
api/services/analysis-snapshot-release-service.R-104-    release_source_incoherent = function(e) stop_for_bad_request(conditionMessage(e)),
--
api/services/job-functional-submission-service.R-19-#' result for the resolved gene list + algorithm, the result is persisted as
api/services/job-functional-submission-service.R-20-#' an already-completed durable job via `async_job_service_store_completed()`
api/services/job-functional-submission-service.R-21-#' so the response shape matches a freshly-submitted job (this keeps LLM batch
api/services/job-functional-submission-service.R-22-#' generation on the same job/result hashes as the API-served table). A cache
api/services/job-functional-submission-service.R-23-#' miss falls through the public queue-depth capacity guard
api/services/job-functional-submission-service.R:24:#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
api/services/job-functional-submission-service.R-25-#' new durable job via `create_job()`.
api/services/job-functional-submission-service.R-26-#'
api/services/job-functional-submission-service.R-27-#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm` and
api/services/job-functional-submission-service.R-28-#'   `req$user$user_id`).
api/services/job-functional-submission-service.R-29-#' @param res Plumber response, mutated in place (status + headers).
--
api/services/job-functional-submission-service.R-175-    )
api/services/job-functional-submission-service.R-176-    job_id <- completed_job$job_id[[1]]
api/services/job-functional-submission-service.R-177-
api/services/job-functional-submission-service.R-178-    res$status <- 202
api/services/job-functional-submission-service.R-179-    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
api/services/job-functional-submission-service.R:180:    res$setHeader("Retry-After", "0")
api/services/job-functional-submission-service.R-181-
api/services/job-functional-submission-service.R-182-    return(list(
api/services/job-functional-submission-service.R-183-      job_id = job_id,
api/services/job-functional-submission-service.R-184-      status = "accepted",
api/services/job-functional-submission-service.R-185-      estimated_seconds = 0,
--
api/services/job-functional-submission-service.R-198-            0L
api/services/job-functional-submission-service.R-199-          }
api/services/job-functional-submission-service.R-200-        )
api/services/job-functional-submission-service.R-201-      )) {
api/services/job-functional-submission-service.R-202-    res$status <- 503
api/services/job-functional-submission-service.R:203:    res$setHeader("Retry-After", "60")
api/services/job-functional-submission-service.R-204-    return(list(
api/services/job-functional-submission-service.R-205-      error = "CAPACITY_EXCEEDED",
api/services/job-functional-submission-service.R-206-      message = "Analysis queue is at capacity. Please retry shortly.",
api/services/job-functional-submission-service.R-207-      retry_after = 60
api/services/job-functional-submission-service.R-208-    ))
--
api/services/job-functional-submission-service.R-220-  )
api/services/job-functional-submission-service.R-221-
api/services/job-functional-submission-service.R-222-  # Check capacity
api/services/job-functional-submission-service.R-223-  if (!is.null(result$error)) {
api/services/job-functional-submission-service.R-224-    res$status <- 503
api/services/job-functional-submission-service.R:225:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/job-functional-submission-service.R-226-    return(result)
api/services/job-functional-submission-service.R-227-  }
api/services/job-functional-submission-service.R-228-
api/services/job-functional-submission-service.R-229-  # Success - return HTTP 202 Accepted
api/services/job-functional-submission-service.R-230-  res$status <- 202
api/services/job-functional-submission-service.R-231-  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
api/services/job-functional-submission-service.R:232:  res$setHeader("Retry-After", "5")
api/services/job-functional-submission-service.R-233-
api/services/job-functional-submission-service.R-234-  list(
api/services/job-functional-submission-service.R-235-    job_id = result$job_id,
api/services/job-functional-submission-service.R-236-    status = result$status,
api/services/job-functional-submission-service.R-237-    estimated_seconds = result$estimated_seconds,
--
api/services/job-maintenance-submission-service.R-71-  )
api/services/job-maintenance-submission-service.R-72-
api/services/job-maintenance-submission-service.R-73-  # Check capacity
api/services/job-maintenance-submission-service.R-74-  if (!is.null(result$error)) {
api/services/job-maintenance-submission-service.R-75-    res$status <- 503
api/services/job-maintenance-submission-service.R:76:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/job-maintenance-submission-service.R-77-    return(result)
api/services/job-maintenance-submission-service.R-78-  }
api/services/job-maintenance-submission-service.R-79-
api/services/job-maintenance-submission-service.R-80-  # Success - return HTTP 202 Accepted
api/services/job-maintenance-submission-service.R-81-  res$status <- 202
api/services/job-maintenance-submission-service.R-82-  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
api/services/job-maintenance-submission-service.R:83:  res$setHeader("Retry-After", "30") # Longer polling interval for ontology update
api/services/job-maintenance-submission-service.R-84-
api/services/job-maintenance-submission-service.R-85-  list(
api/services/job-maintenance-submission-service.R-86-    job_id = result$job_id,
api/services/job-maintenance-submission-service.R-87-    status = result$status,
api/services/job-maintenance-submission-service.R-88-    estimated_seconds = 300, # Ontology update is slow (5+ minutes)
--
api/services/job-maintenance-submission-service.R-120-  )
api/services/job-maintenance-submission-service.R-121-
api/services/job-maintenance-submission-service.R-122-  # Check capacity
api/services/job-maintenance-submission-service.R-123-  if (!is.null(result$error)) {
api/services/job-maintenance-submission-service.R-124-    res$status <- 503
api/services/job-maintenance-submission-service.R:125:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/job-maintenance-submission-service.R-126-    return(result)
api/services/job-maintenance-submission-service.R-127-  }
api/services/job-maintenance-submission-service.R-128-
api/services/job-maintenance-submission-service.R-129-  # Success - return HTTP 202 Accepted
api/services/job-maintenance-submission-service.R-130-  res$status <- 202
api/services/job-maintenance-submission-service.R-131-  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
api/services/job-maintenance-submission-service.R:132:  res$setHeader("Retry-After", "60") # Long-running job: poll every minute
api/services/job-maintenance-submission-service.R-133-
api/services/job-maintenance-submission-service.R-134-  list(
api/services/job-maintenance-submission-service.R-135-    job_id = result$job_id,
api/services/job-maintenance-submission-service.R-136-    status = result$status,
api/services/job-maintenance-submission-service.R-137-    estimated_seconds = 300, # ~5 min typical (Ensembl BioMart is the bottleneck)
--
api/services/job-maintenance-submission-service.R-169-  )
api/services/job-maintenance-submission-service.R-170-
api/services/job-maintenance-submission-service.R-171-  # Check capacity
api/services/job-maintenance-submission-service.R-172-  if (!is.null(result$error)) {
api/services/job-maintenance-submission-service.R-173-    res$status <- 503
api/services/job-maintenance-submission-service.R:174:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/job-maintenance-submission-service.R-175-    return(result)
api/services/job-maintenance-submission-service.R-176-  }
api/services/job-maintenance-submission-service.R-177-
api/services/job-maintenance-submission-service.R-178-  # Success - return HTTP 202 Accepted
api/services/job-maintenance-submission-service.R-179-  res$status <- 202
api/services/job-maintenance-submission-service.R-180-  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
api/services/job-maintenance-submission-service.R:181:  res$setHeader("Retry-After", "30") # Long-running job: poll every 30 seconds
api/services/job-maintenance-submission-service.R-182-
api/services/job-maintenance-submission-service.R-183-  list(
api/services/job-maintenance-submission-service.R-184-    job_id = result$job_id,
api/services/job-maintenance-submission-service.R-185-    status = result$status,
api/services/job-maintenance-submission-service.R-186-    estimated_seconds = 300, # ~5 min typical
--
api/services/admin-nddscore-endpoint-service.R-124-  job_id <- job$job_id[[1]]
api/services/admin-nddscore-endpoint-service.R-125-  status_url <- .nddscore_admin_job_status_url(job_id)
api/services/admin-nddscore-endpoint-service.R-126-
api/services/admin-nddscore-endpoint-service.R-127-  res$status <- if (isTRUE(submitted$duplicate)) 409L else 202L
api/services/admin-nddscore-endpoint-service.R-128-  res$setHeader("Location", status_url)
api/services/admin-nddscore-endpoint-service.R:129:  res$setHeader("Retry-After", "5")
api/services/admin-nddscore-endpoint-service.R-130-
api/services/admin-nddscore-endpoint-service.R-131-  list(
api/services/admin-nddscore-endpoint-service.R-132-    job_id = job_id,
api/services/admin-nddscore-endpoint-service.R-133-    status = if (isTRUE(submitted$duplicate)) "already_running" else "accepted",
api/services/admin-nddscore-endpoint-service.R-134-    job_status = job$status[[1]],
--
api/services/job-phenotype-submission-service.R-25-#' Cache-first: if the memoised `gen_mca_clust_obj_mem()` already has a result
api/services/job-phenotype-submission-service.R-26-#' for the resolved phenotype-by-entity matrix, the result is persisted as an
api/services/job-phenotype-submission-service.R-27-#' already-completed durable job via `async_job_service_store_completed()` so
api/services/job-phenotype-submission-service.R-28-#' the LLM batch generator uses the same job/result hashes as the API-served
api/services/job-phenotype-submission-service.R-29-#' table. A cache miss falls through the public queue-depth capacity guard
api/services/job-phenotype-submission-service.R:30:#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
api/services/job-phenotype-submission-service.R-31-#' new durable job via `create_job()`.
api/services/job-phenotype-submission-service.R-32-#'
api/services/job-phenotype-submission-service.R-33-#' @param req Plumber request (reads `req$user$user_id`).
api/services/job-phenotype-submission-service.R-34-#' @param res Plumber response, mutated in place (status + headers).
api/services/job-phenotype-submission-service.R-35-#' @return List payload for the `json` serializer.
--
api/services/job-phenotype-submission-service.R-173-    )
api/services/job-phenotype-submission-service.R-174-    job_id <- completed_job$job_id[[1]]
api/services/job-phenotype-submission-service.R-175-
api/services/job-phenotype-submission-service.R-176-    res$status <- 202
api/services/job-phenotype-submission-service.R-177-    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
api/services/job-phenotype-submission-service.R:178:    res$setHeader("Retry-After", "0")
api/services/job-phenotype-submission-service.R-179-
api/services/job-phenotype-submission-service.R-180-    return(list(
api/services/job-phenotype-submission-service.R-181-      job_id = job_id,
api/services/job-phenotype-submission-service.R-182-      status = "accepted",
api/services/job-phenotype-submission-service.R-183-      estimated_seconds = 0,
--
api/start_sysndd_api.R-32-source("bootstrap/run_migrations.R",  local = FALSE)
api/start_sysndd_api.R-33-source("bootstrap/init_globals.R",    local = FALSE)
api/start_sysndd_api.R-34-source("bootstrap/init_cache.R",      local = FALSE)
api/start_sysndd_api.R-35-source("bootstrap/setup_workers.R",   local = FALSE)
api/start_sysndd_api.R:36:source("bootstrap/mount_endpoints.R", local = FALSE)
api/start_sysndd_api.R-37-
api/start_sysndd_api.R-38-bootstrap_init_libraries()
api/start_sysndd_api.R-39-
api/start_sysndd_api.R-40-## -------------------------------------------------------------------##
--
api/start_sysndd_api.R-135-
api/start_sysndd_api.R-136-## -------------------------------------------------------------------##
api/start_sysndd_api.R-137-# 9) Mount endpoints + filters onto the root router.
api/start_sysndd_api.R-138-## -------------------------------------------------------------------##
api/start_sysndd_api.R:139:root <- bootstrap_mount_endpoints(api_spec, pool, logging_temp_file)
api/start_sysndd_api.R-140-
api/start_sysndd_api.R-141-## -------------------------------------------------------------------##
api/start_sysndd_api.R-142-# 9b) Bootstrap PubtatorNDD enrichment if no current snapshot exists (#421):
api/start_sysndd_api.R-143-#     a fresh deploy gets enrichment + the gene-summary table populated without
--
api/core/filters.R-4-# Part of the Phase D.D6 extract-bootstrap refactor.
api/core/filters.R-5-#
api/core/filters.R-6-# Hosts the named Plumber filter functions that used to live inline
api/core/filters.R-7-# in start_sysndd_api.R. `corsFilter` and `checkSignInFilter` are
api/core/filters.R:8:# attached to the root router in api/bootstrap/mount_endpoints.R via
api/core/filters.R-9-# pr_filter().
api/core/filters.R-10-#
api/core/filters.R-11-# NOTE: `checkSignInFilter` is the legacy pre-require_auth filter.
api/core/filters.R-12-# It is kept here for the transitional migration path but is not
--
api/core/filters.R-228-#' @param req Plumber request object
api/core/filters.R-229-#' @param res Plumber response object
api/core/filters.R-230-#' @param err Condition raised by the endpoint
api/core/filters.R-231-#' @return RFC 9457 problem details response
api/core/filters.R:232:errorHandler <- function(req, res, err) {
api/core/filters.R-233-  # Get error message safely
api/core/filters.R-234-  err_msg <- tryCatch(
api/core/filters.R-235-    conditionMessage(err),
api/core/filters.R-236-    error = function(e) "An error occurred"
--
api/functions/data-helpers.R-223-  # The old sort step called parse_exprs(colnames[1]) inside dplyr's arrange
api/functions/data-helpers.R-224-  # call, evaluating the first JSON key as an R expression via dplyr
api/functions/data-helpers.R-225-  # data-masking -> authenticated RCE.
api/functions/data-helpers.R-226-  # hash_validate_columns() raises `hash_column_validation_error` (rlang::abort),
api/functions/data-helpers.R:227:  # which errorHandler does NOT map -> wrap to a classed 400 (Codex review).
api/functions/data-helpers.R-228-  tryCatch(
api/functions/data-helpers.R-229-    hash_validate_columns(colnames(json_tibble), allowed_col_list),
api/functions/data-helpers.R-230-    hash_column_validation_error = function(e) stop_for_bad_request(conditionMessage(e))
api/functions/data-helpers.R-231-  )
--
api/functions/response-fields-helpers.R-65-    selection_tibble <- selection_tibble %>%
api/functions/response-fields-helpers.R-66-      dplyr::select(all_of(fields_requested))
api/functions/response-fields-helpers.R-67-  } else {
api/functions/response-fields-helpers.R-68-    # A request for fields the queried view/tibble does not expose is a client
api/functions/response-fields-helpers.R:69:    # error (400), not a server fault (500). With mount_endpoints.R now routing
api/functions/response-fields-helpers.R:70:    # every sub-router through errorHandler, this error_400 maps to a proper
api/functions/response-fields-helpers.R-71-    # 400 + problem+json. Name the offending columns so a frontend/view schema
api/functions/response-fields-helpers.R-72-    # mismatch is debuggable.
api/functions/response-fields-helpers.R-73-    missing_fields <- setdiff(fields_requested, tibble_colnames)
api/functions/response-fields-helpers.R-74-    stop_for_bad_request(sprintf(
app/src/utils/safe-url.ts:14:export function safeHttpUrl(value: unknown): string | null {
app/src/utils/safe-url.spec.ts:3:import { safeHttpUrl } from './safe-url';
app/src/utils/safe-url.spec.ts:5:describe('safeHttpUrl', () => {
app/src/utils/safe-url.spec.ts:7:    expect(safeHttpUrl('https://zenodo.org/records/1234')).toBe(
app/src/utils/safe-url.spec.ts:13:    expect(safeHttpUrl('http://example.org/path')).toBe('http://example.org/path');
app/src/utils/safe-url.spec.ts:17:    expect(safeHttpUrl('javascript:alert(document.cookie)')).toBeNull();
app/src/utils/safe-url.spec.ts:21:    expect(safeHttpUrl('data:text/html,<script>alert(1)</script>')).toBeNull();
app/src/utils/safe-url.spec.ts:25:    expect(safeHttpUrl('vbscript:msgbox(1)')).toBeNull();
app/src/utils/safe-url.spec.ts:29:    expect(safeHttpUrl('')).toBeNull();
app/src/utils/safe-url.spec.ts:33:    expect(safeHttpUrl('   ')).toBeNull();
app/src/utils/safe-url.spec.ts:37:    expect(safeHttpUrl(null)).toBeNull();
app/src/utils/safe-url.spec.ts:41:    expect(safeHttpUrl(undefined)).toBeNull();
app/src/utils/safe-url.spec.ts:45:    expect(safeHttpUrl(42)).toBeNull();
app/src/utils/safe-url.spec.ts:46:    expect(safeHttpUrl({ href: 'https://evil.example' })).toBeNull();
app/src/utils/safe-url.spec.ts:53:    expect(safeHttpUrl('/some/path')).toBe('/some/path');
app/src/utils/safe-url.spec.ts:57:    expect(safeHttpUrl('http://')).toBeNull();
app/src/api/analysis_releases.ts:136:export interface ReleaseManifestGenerator {
app/src/api/analysis_releases.ts:178:  generator: ReleaseManifestGenerator;
app/src/api/analysis.spec.ts:291: * `ReleaseManifestGenerator`/`ReleaseManifestSource` types.
app/src/components/analyses/ReleaseManifestPanel.vue:193:              never bound to `:href` unguarded — `safeHttpUrl` only allows
app/src/components/analyses/ReleaseManifestPanel.vue:218:import { safeHttpUrl } from '@/utils/safe-url';
app/src/components/analyses/ReleaseManifestPanel.vue:244:const safeRecordUrl = computed<string | null>(() => safeHttpUrl(props.release.zenodo.record_url));
app/src/components/analyses/ReleaseManifestPanel.vue:246:  props.release.zenodo.version_doi ? safeHttpUrl(doiUrl(props.release.zenodo.version_doi)) : null
app/src/components/analyses/ReleaseManifestPanel.vue:249:  props.release.zenodo.concept_doi ? safeHttpUrl(doiUrl(props.release.zenodo.concept_doi)) : null
app/src/views/admin/ManageAnalysisReleases.spec.ts:310:  it('surfaces a failed DOI-save action error co-located in the Releases panel and keeps the DOI form open', async () => {
app/src/views/admin/ManageAnalysisReleases.spec.ts:348:  it('surfaces a failed draft-deletion action error and resets the confirm state without removing the row', async () => {
app/src/views/analyses/DataReleases.vue:193:let detailRequestSeq = 0;
app/src/views/analyses/DataReleases.vue:215:  const token = ++detailRequestSeq;
app/src/views/analyses/DataReleases.vue:220:    if (token !== detailRequestSeq) return; // a newer request has since started; discard
app/src/views/analyses/DataReleases.vue:223:    if (token !== detailRequestSeq) return; // a newer request has since started; discard
app/src/views/analyses/DataReleases.vue:229:    if (token === detailRequestSeq) {

codex
The prior fixes are present in the live code, not just described in comments: the public anchor is conditionally rendered through the URL helper, the manifest interfaces model the backend’s nested objects, and the request-sequence guard has a regression test that resolves the stale request last. I’m completing targeted type/unit verification and checking less obvious contract and lifecycle edges.
exec
/bin/bash -lc 'git show --format=fuller --stat 401abf17 && git diff --unified=80 401abf17''^ 401abf17 -- app/src/utils/safe-url.ts app/src/utils/safe-url.spec.ts app/src/components/analyses/ReleaseManifestPanel.vue app/src/components/analyses/ReleaseManifestPanel.spec.ts app/src/api/analysis_releases.ts app/src/api/analysis.spec.ts app/src/views/analyses/DataReleases.vue app/src/views/analyses/DataReleases.spec.ts app/src/views/admin/ManageAnalysisReleases.spec.ts && git diff origin/master...HEAD -- AGENTS.md CHANGELOG.md api/version_spec.json documentation/09-deployment.qmd app/package.json && find app/src -type f '"\\( -name '*.ts' -o -name '*.vue' \\) -printf '%s %p\\n' | sort -nr | head -n 25" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
commit 401abf1781dc3962dbe51aac565d876fca0b567f
Author:     Bernt Popp <bernt.popp@gmail.com>
AuthorDate: Sun Jul 19 10:35:49 2026 +0200
Commit:     Bernt Popp <bernt.popp@gmail.com>
CommitDate: Sun Jul 19 10:35:49 2026 +0200

    fix(app): address Codex round-1 review findings on analysis-release UI (#573)

    Reconcile the adversarial Codex + Claude final review (NO-SHIP: 1 HIGH,
    2 MEDIUM, 2 LOW) on the #573 Slice B analysis-snapshot release UI:

    - HIGH: guard against javascript:/data:-scheme href injection via the
      admin-authored, backend-unvalidated zenodo.record_url on the public
      /DataReleases page. Adds a reusable safeHttpUrl() helper and applies it
      (defensively) to the DOI links too.
    - MEDIUM: retype ReleaseManifest.generator/source from string to the real
      nested wire shape the backend serializes, plus nullable scope_statement.
    - MEDIUM: fix a stale-response race in DataReleases.vue with a monotonic
      request token so a slow initial getLatestRelease() can't clobber a later
      row selection.
    - LOW: convert release-client error-mock fixtures from {message} to the
      real RFC 9457 {detail} problem+json shape.
    - LOW: add failure-path test coverage for a rejected DOI save and a
      rejected draft deletion.

    Claude-Session: https://claude.ai/code/session_01Shab9CYtSFmHhb7yzqBGNn

 app/src/api/analysis.spec.ts                       | 63 ++++++++++++++---
 app/src/api/analysis_releases.ts                   | 40 ++++++++++-
 .../analyses/ReleaseManifestPanel.spec.ts          | 57 +++++++++++++++-
 .../components/analyses/ReleaseManifestPanel.vue   | 36 ++++++++--
 app/src/utils/safe-url.spec.ts                     | 59 ++++++++++++++++
 app/src/utils/safe-url.ts                          | 22 ++++++
 app/src/views/admin/ManageAnalysisReleases.spec.ts | 78 ++++++++++++++++++++++
 app/src/views/analyses/DataReleases.spec.ts        | 69 +++++++++++++++++--
 app/src/views/analyses/DataReleases.vue            | 19 +++++-
 9 files changed, 416 insertions(+), 27 deletions(-)
diff --git a/app/src/api/analysis.spec.ts b/app/src/api/analysis.spec.ts
index a45c889d..74462739 100644
--- a/app/src/api/analysis.spec.ts
+++ b/app/src/api/analysis.spec.ts
@@ -208,313 +208,356 @@ describe('api/analysis — getFunctionalClusterSummary', () => {
       )
     );

     let caught: unknown;
     try {
       await getFunctionalClusterSummary({ cluster_hash: 'x', cluster_number: '1' });
     } catch (err) {
       caught = err;
     }
     expect(isApiError(caught)).toBe(true);
     if (isApiError(caught)) {
       expect(caught.response?.status).toBe(503);
     }
   });
 });

 describe('api/analysis — getPhenotypeClusterSummary', () => {
   it('returns the summary on 200', async () => {
     const ok: ClusterSummary = {
       cluster_hash: 'def',
       cluster_number: 2,
       summary_json: { themes: ['ID', 'epilepsy'] },
     };
     server.use(http.get('/api/analysis/phenotype_cluster_summary', () => HttpResponse.json(ok)));
     const result = await getPhenotypeClusterSummary({ cluster_hash: 'def', cluster_number: '2' });
     expect(result.cluster_hash).toBe('def');
   });
 });

 describe('isSnapshotPreparingError', () => {
   it('is true for a 503 snapshot_missing problem', () => {
     expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'snapshot_missing' } } })).toBe(true);
   });
   it('is true when code is a 1-element array (R/Plumber scalar serialisation) (#440)', () => {
     // The real API serialises the problem code as ["snapshot_missing"], not a
     // bare string — the "being prepared" state must still trigger.
     expect(isSnapshotPreparingError({ response: { status: 503, data: { code: ['snapshot_missing'] } } })).toBe(true);
     expect(isSnapshotPreparingError({ response: { status: 503, data: { code: ['snapshot_stale'] } } })).toBe(true);
   });
   it('is true for snapshot_stale and source_version_mismatch', () => {
     expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'snapshot_stale' } } })).toBe(true);
     expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'source_version_mismatch' } } })).toBe(true);
   });
   it('is false for a non-503 error', () => {
     expect(isSnapshotPreparingError({ response: { status: 500, data: { code: 'snapshot_missing' } } })).toBe(false);
   });
   it('is false for a 503 with an unrelated code', () => {
     expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'CAPACITY_EXCEEDED' } } })).toBe(false);
   });
   it('is false for a plain error', () => {
     expect(isSnapshotPreparingError(new Error('boom'))).toBe(false);
   });
 });

 // ---------------------------------------------------------------------------
 // Analysis-snapshot releases (#573 Slice B, Task B1)
 // ---------------------------------------------------------------------------

 function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
   return {
     release_id: 'asr_0123456789abcdef',
     release_version: null,
     title: 'SysNDD analysis-snapshot release',
     status: 'published',
     content_digest: 'a'.repeat(64),
     created_at: '2026-07-01T00:00:00Z',
     published_at: '2026-07-01T00:05:00Z',
     source_data_version: '2026-07-01',
     db_release_version: '11.4.0',
     db_release_commit: 'deadbeef',
     manifest_sha256: 'b'.repeat(64),
     bundle_sha256: 'c'.repeat(64),
     license: 'CC-BY-4.0',
     file_count: 10,
     total_bytes: 123456,
     zenodo: { record_url: null, version_doi: null, concept_doi: null },
     ...overrides,
   };
 }

+/**
+ * `manifest.generator`/`manifest.source` are nested objects on the wire
+ * (api/functions/analysis-snapshot-release.R), not strings — see the
+ * `ReleaseManifestGenerator`/`ReleaseManifestSource` types.
+ */
+function makeManifestGeneratorSource() {
+  return {
+    generator: {
+      name: 'sysndd-analysis-snapshot-release-build',
+      manifest_schema_version: '1.0',
+      reproducibility_schema_version: '1.2',
+    },
+    source: {
+      source_data_version: '2026-07-01',
+      db_release: { version: '11.4.0', commit: 'deadbeef' },
+      snapshots: [
+        { analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp-hash' },
+      ],
+    },
+  };
+}
+
 describe('api/analysis — listReleases', () => {
   it('returns the releases envelope on 200', async () => {
     server.use(
       http.get('/api/analysis/releases', () =>
         HttpResponse.json({
           releases: [makeReleaseHead()],
           pagination: { limit: 50, offset: 0, count: 1 },
         })
       )
     );
     const result = await listReleases();
     expect(result.releases).toHaveLength(1);
     expect(result.releases[0].release_id).toBe('asr_0123456789abcdef');
     expect(result.pagination.count).toBe(1);
     // Public head allowlist: admin-only fields must never be present.
     expect(result.releases[0]).not.toHaveProperty('created_by_user_id');
     expect(result.releases[0]).not.toHaveProperty('last_error_message');
   });

   it('forwards limit/offset query params', async () => {
     let observedQuery: URLSearchParams | null = null;
     server.use(
       http.get('/api/analysis/releases', ({ request }) => {
         observedQuery = new URL(request.url).searchParams;
         return HttpResponse.json({
           releases: [],
           pagination: { limit: 10, offset: 5, count: 0 },
         });
       })
     );
     await listReleases({ limit: 10, offset: 5 });
     const q = observedQuery as unknown as URLSearchParams;
     expect(q.get('limit')).toBe('10');
     expect(q.get('offset')).toBe('5');
   });

   it('throws AxiosError on non-2xx', async () => {
     server.use(
       http.get('/api/analysis/releases', () =>
-        HttpResponse.json({ message: 'boom' }, { status: 500 })
+        HttpResponse.json(
+          { type: 'about:blank', title: 'Internal Server Error', status: 500, detail: 'boom' },
+          { status: 500 }
+        )
       )
     );
     let caught: unknown;
     try {
       await listReleases();
     } catch (err) {
       caught = err;
     }
     expect(isApiError(caught)).toBe(true);
     expect(extractApiErrorMessage(caught, 'fallback')).toBe('boom');
   });
 });

 describe('api/analysis — getLatestRelease', () => {
   it('returns the head + manifest on 200', async () => {
     const detail: ReleaseDetail = {
       ...makeReleaseHead(),
       manifest: {
         release_id: 'asr_0123456789abcdef',
         release_version: null,
         title: 'SysNDD analysis-snapshot release',
         created_at: '2026-07-01T00:00:00Z',
         license: 'CC-BY-4.0',
         scope_statement: 'Public derived analysis only.',
-        generator: 'sysndd-api',
-        source: 'sysndd',
+        ...makeManifestGeneratorSource(),
         layers: [],
         files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
         content_digest: 'a'.repeat(64),
       },
     };
     server.use(http.get('/api/analysis/releases/latest', () => HttpResponse.json(detail)));
     const result = await getLatestRelease();
     expect(result.release_id).toBe('asr_0123456789abcdef');
     expect(result.manifest.files).toHaveLength(1);
   });

   it('throws AxiosError 404 when no published release exists', async () => {
     server.use(
       http.get('/api/analysis/releases/latest', () =>
-        HttpResponse.json({ message: 'No published analysis-snapshot release exists yet' }, { status: 404 })
+        HttpResponse.json(
+          {
+            type: 'about:blank',
+            title: 'Not Found',
+            status: 404,
+            detail: 'No published analysis-snapshot release exists yet',
+          },
+          { status: 404 }
+        )
       )
     );
     let caught: unknown;
     try {
       await getLatestRelease();
     } catch (err) {
       caught = err;
     }
     expect(isApiError(caught)).toBe(true);
     if (isApiError(caught)) {
       expect(caught.response?.status).toBe(404);
     }
   });
 });

 describe('api/analysis — getRelease', () => {
   it('returns the head + manifest on 200 and encodes the release id', async () => {
     let observedPath = '';
     const detail: ReleaseDetail = {
       ...makeReleaseHead({ release_id: 'asr_abc123' }),
       manifest: {
         release_id: 'asr_abc123',
         release_version: null,
         title: 'SysNDD analysis-snapshot release',
         created_at: '2026-07-01T00:00:00Z',
         license: 'CC-BY-4.0',
         scope_statement: 'Public derived analysis only.',
-        generator: 'sysndd-api',
-        source: 'sysndd',
+        ...makeManifestGeneratorSource(),
         layers: [],
         files: [],
         content_digest: 'a'.repeat(64),
       },
     };
     server.use(
       http.get('/api/analysis/releases/:releaseId', ({ request, params }) => {
         observedPath = new URL(request.url).pathname;
         expect(params.releaseId).toBe('asr_abc123');
         return HttpResponse.json(detail);
       })
     );
     const result = await getRelease('asr_abc123');
     expect(result.release_id).toBe('asr_abc123');
     expect(observedPath).toBe('/api/analysis/releases/asr_abc123');
   });

   it('throws AxiosError 404 for an unknown/draft release id', async () => {
     server.use(
       http.get('/api/analysis/releases/:releaseId', () =>
-        HttpResponse.json({ message: 'not found' }, { status: 404 })
+        HttpResponse.json(
+          { type: 'about:blank', title: 'Not Found', status: 404, detail: 'not found' },
+          { status: 404 }
+        )
       )
     );
     let caught: unknown;
     try {
       await getRelease('asr_unknown');
     } catch (err) {
       caught = err;
     }
     expect(isApiError(caught)).toBe(true);
     if (isApiError(caught)) {
       expect(caught.response?.status).toBe(404);
     }
   });
 });

 describe('api/analysis — downloadReleaseManifest', () => {
   it('returns the manifest.json bytes as a Blob', async () => {
     server.use(
       http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
         HttpResponse.json({ release_id: 'asr_abc123' })
       )
     );
     const blob = await downloadReleaseManifest('asr_abc123');
     expect(blob).toBeInstanceOf(Blob);
   });

   it('throws AxiosError on non-2xx', async () => {
     server.use(
       http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
-        HttpResponse.json({ message: 'not found' }, { status: 404 })
+        HttpResponse.json(
+          { type: 'about:blank', title: 'Not Found', status: 404, detail: 'not found' },
+          { status: 404 }
+        )
       )
     );
     let caught: unknown;
     try {
       await downloadReleaseManifest('asr_unknown');
     } catch (err) {
       caught = err;
     }
     expect(isApiError(caught)).toBe(true);
   });
 });

 describe('api/analysis — downloadReleaseFile', () => {
   it('forwards the file path as a query param and returns a Blob', async () => {
     let observedQuery: URLSearchParams | null = null;
     server.use(
       http.get('/api/analysis/releases/:releaseId/file', ({ request }) => {
         observedQuery = new URL(request.url).searchParams;
         return HttpResponse.json({ ok: true });
       })
     );
     const blob = await downloadReleaseFile('asr_abc123', 'functional_clusters/payload.json');
     expect(blob).toBeInstanceOf(Blob);
     const q = observedQuery as unknown as URLSearchParams;
     expect(q.get('path')).toBe('functional_clusters/payload.json');
   });

   it('throws AxiosError on non-2xx (unknown file path)', async () => {
     server.use(
       http.get('/api/analysis/releases/:releaseId/file', () =>
-        HttpResponse.json({ message: 'not found' }, { status: 404 })
+        HttpResponse.json(
+          { type: 'about:blank', title: 'Not Found', status: 404, detail: 'not found' },
+          { status: 404 }
+        )
       )
     );
     let caught: unknown;
     try {
       await downloadReleaseFile('asr_abc123', 'nope.json');
     } catch (err) {
       caught = err;
     }
     expect(isApiError(caught)).toBe(true);
     if (isApiError(caught)) {
       expect(caught.response?.status).toBe(404);
     }
   });
 });

 describe('api/analysis — downloadReleaseBundle', () => {
   it('returns the bundle.tar.gz bytes as a Blob', async () => {
     server.use(
       http.get('/api/analysis/releases/:releaseId/bundle', () =>
         HttpResponse.json({ ok: true })
       )
     );
     const blob = await downloadReleaseBundle('asr_abc123');
     expect(blob).toBeInstanceOf(Blob);
   });

   it('throws AxiosError on non-2xx', async () => {
     server.use(
       http.get('/api/analysis/releases/:releaseId/bundle', () =>
-        HttpResponse.json({ message: 'not found' }, { status: 404 })
+        HttpResponse.json(
+          { type: 'about:blank', title: 'Not Found', status: 404, detail: 'not found' },
+          { status: 404 }
+        )
       )
     );
     let caught: unknown;
     try {
       await downloadReleaseBundle('asr_unknown');
     } catch (err) {
       caught = err;
     }
     expect(isApiError(caught)).toBe(true);
   });
 });
diff --git a/app/src/api/analysis_releases.ts b/app/src/api/analysis_releases.ts
index 3592854e..625bb83e 100644
--- a/app/src/api/analysis_releases.ts
+++ b/app/src/api/analysis_releases.ts
@@ -49,177 +49,211 @@ export interface ReleaseLayerDependency {
   payload_hash: string;
 }

 export interface ReleaseLayerDependencies {
   functional_clusters?: ReleaseLayerDependency;
   phenotype_clusters?: ReleaseLayerDependency;
 }

 /**
  * Full per-layer identity, as it appears in `manifest.layers[]` on the
  * detail (`GET /releases/<id>`) and `latest` routes. `reproducibility_hash`
  * is `null` for the `phenotype_functional_correlations` layer (that layer
  * has no reproducibility bundle); `dependencies` is non-null ONLY for that
  * same layer.
  */
 export interface ReleaseManifestLayer {
   analysis_type: string;
   parameter_hash: string;
   snapshot_id: number;
   input_hash: string | null;
   payload_hash: string | null;
   schema_version: string;
   reproducibility_hash: string | null;
   dependencies: ReleaseLayerDependencies | null;
 }

 /**
  * Light per-layer summary, as it appears in `layers[]` on each head from the
  * LIST route (`GET /releases`) only — the list route intentionally omits the
  * full manifest (and therefore the fuller `ReleaseManifestLayer` shape) to
  * keep the listing payload cheap.
  */
 export interface ReleaseHeadLayer {
   analysis_type: string;
   snapshot_id: number;
   payload_hash: string;
 }

 /**
  * PUBLIC projection of an `analysis_snapshot_release` head, as returned by
  * `analysis_release_public_head()` (api/functions/analysis-snapshot-release-repository.R).
  *
  * This is a FIXED 14-field allowlist + `zenodo` + conditional `layers`
  * (list route) / `manifest` (detail + latest routes). Admin-only columns
  * (`created_by_user_id`, `last_error_message`, `updated_at`) are NEVER part
  * of this type — do not widen it to match the raw admin head shape in
  * `admin_analysis_release.ts` (a separate, intentionally different type).
  */
 export interface ReleaseHead {
   release_id: string;
   /**
    * Reserved string column (`VARCHAR(32)`, migration 045) — always `null`
    * today; the builder never populates it (`api/functions/analysis-snapshot-
    * release.R`). Not a number, and not guaranteed non-null.
    */
   release_version: string | null;
   title: string | null;
   status: string;
   content_digest: string;
   created_at: string;
   published_at: string | null;
   source_data_version: string;
   db_release_version: string | null;
   db_release_commit: string | null;
   manifest_sha256: string;
   bundle_sha256: string;
   license: string;
   file_count: number;
   total_bytes: number;
   zenodo: ReleaseZenodo;
   /** Light per-layer identity (list route only): analysis_type, snapshot_id, payload_hash. */
   layers?: ReleaseHeadLayer[];
 }

 export interface ReleaseManifestFile {
   path: string;
   sha256: string;
   bytes: number;
 }

+/**
+ * Build provenance recorded on `manifest.generator`
+ * (api/functions/analysis-snapshot-release.R, the `analysis_release_build_manifest()`
+ * call site). `reproducibility_schema_version` is absent/`null` if the
+ * `ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION` constant is not defined at build
+ * time.
+ */
+export interface ReleaseManifestGenerator {
+  name: string;
+  manifest_schema_version: string;
+  reproducibility_schema_version: string | null;
+}
+
+/** `manifest.source.db_release`: the DB release identity pinned at build time, if known. */
+export interface ReleaseManifestSourceDbRelease {
+  version: string | null;
+  commit: string | null;
+}
+
+/** One entry of `manifest.source.snapshots[]` — the pinned source snapshot per layer. */
+export interface ReleaseManifestSourceSnapshot {
+  analysis_type: string;
+  snapshot_id: number;
+  parameter_hash: string;
+}
+
+/** `manifest.source`: the shared source-data identity every layer in the release was built from. */
+export interface ReleaseManifestSource {
+  source_data_version: string;
+  db_release: ReleaseManifestSourceDbRelease;
+  snapshots: ReleaseManifestSourceSnapshot[];
+}
+
 /**
  * The release `manifest.json` shape, built by
  * `analysis_release_build_manifest()` (api/functions/analysis-snapshot-release-manifest.R).
  * Present on the detail (`GET /releases/<id>`) and `latest` routes only —
  * NOT on the list route, which carries the lighter `layers` array on each
  * head instead.
  */
 export interface ReleaseManifest {
   release_id: string;
   /** Reserved, currently-unpopulated string column — always `null` today (see `ReleaseHead.release_version`). */
   release_version: string | null;
   title: string | null;
   created_at: string;
   license: string;
-  scope_statement: string;
-  generator: string;
-  source: string;
+  /** Nullable — the build param defaults to `NULL` when the caller omits a scope statement. */
+  scope_statement: string | null;
+  generator: ReleaseManifestGenerator;
+  source: ReleaseManifestSource;
   layers: ReleaseManifestLayer[];
   files: ReleaseManifestFile[];
   content_digest: string;
 }

 /** `GET /releases/<id>` and `GET /releases/latest`: head + parsed manifest. */
 export interface ReleaseDetail extends ReleaseHead {
   manifest: ReleaseManifest;
 }

 export interface ListReleasesParams {
   limit?: number;
   offset?: number;
 }

 export interface ListReleasesResponse {
   releases: ReleaseHead[];
   pagination: {
     limit: number;
     offset: number;
     count: number;
   };
 }

 // ---------------------------------------------------------------------------
 // Helpers
 // ---------------------------------------------------------------------------

 /**
  * GET /api/analysis/releases
  * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases`).
  *
  * Public, unauthenticated. Lists published analysis-snapshot releases
  * (newest first). `pagination` echoes the CLAMPED effective `limit`/`offset`
  * the service actually queried, not necessarily the caller's raw values.
  */
 export async function listReleases(
   params: ListReleasesParams = {},
   config?: AxiosRequestConfig
 ): Promise<ListReleasesResponse> {
   return apiClient.get<ListReleasesResponse>('/api/analysis/releases', {
     ...config,
     params: { ...(config?.params as object | undefined), ...params },
   });
 }

 /**
  * GET /api/analysis/releases/latest
  * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/latest`).
  *
  * Public, unauthenticated. Returns the newest published release's head +
  * manifest (same shape as the detail route).
  *
  * Throws AxiosError 404 when no published release exists yet.
  */
 export async function getLatestRelease(config?: AxiosRequestConfig): Promise<ReleaseDetail> {
   return apiClient.get<ReleaseDetail>('/api/analysis/releases/latest', config);
 }

 /**
  * GET /api/analysis/releases/<release_id>
  * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>`).
  *
  * Public, unauthenticated. Returns the release head + manifest. An unknown
  * id and a draft id are indistinguishable — both 404 (drafts are never
  * public).
  */
 export async function getRelease(
   releaseId: string,
   config?: AxiosRequestConfig
 ): Promise<ReleaseDetail> {
   const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}`;
   return apiClient.get<ReleaseDetail>(path, config);
 }

 /**
  * GET /api/analysis/releases/<release_id>/manifest.json
  * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/manifest.json`).
  *
  * Public, unauthenticated. Returns the EXACT stored `manifest.json` bytes
diff --git a/app/src/components/analyses/ReleaseManifestPanel.spec.ts b/app/src/components/analyses/ReleaseManifestPanel.spec.ts
index ce5daf37..7a954d36 100644
--- a/app/src/components/analyses/ReleaseManifestPanel.spec.ts
+++ b/app/src/components/analyses/ReleaseManifestPanel.spec.ts
@@ -1,159 +1,212 @@
 import { mount } from '@vue/test-utils';
 import { describe, expect, it, vi } from 'vitest';
 import ReleaseManifestPanel from './ReleaseManifestPanel.vue';
 import type { ReleaseDetail } from '@/api/analysis';

 function makeReleaseDetail(): ReleaseDetail {
   return {
     release_id: 'asr_0123456789abcdef',
     release_version: null,
     title: 'SysNDD analysis-snapshot release',
     status: 'published',
     content_digest: 'a'.repeat(64),
     created_at: '2026-07-01T00:00:00Z',
     published_at: '2026-07-01T00:05:00Z',
     source_data_version: '2026-07-01',
     db_release_version: '11.4.0',
     db_release_commit: 'deadbeef',
     manifest_sha256: 'b'.repeat(64),
     bundle_sha256: 'c'.repeat(64),
     license: 'CC-BY-4.0',
     file_count: 10,
     total_bytes: 1258291,
     zenodo: {
       record_url: 'https://zenodo.org/records/1234',
       version_doi: '10.5281/zenodo.1234',
       concept_doi: '10.5281/zenodo.1233',
     },
     manifest: {
       release_id: 'asr_0123456789abcdef',
       release_version: null,
       title: 'SysNDD analysis-snapshot release',
       created_at: '2026-07-01T00:00:00Z',
       license: 'CC-BY-4.0',
       scope_statement: 'Public derived analysis only.',
-      generator: 'sysndd-api',
-      source: 'sysndd',
+      generator: {
+        name: 'sysndd-analysis-snapshot-release-build',
+        manifest_schema_version: '1.0',
+        reproducibility_schema_version: '1.2',
+      },
+      source: {
+        source_data_version: '2026-07-01',
+        db_release: { version: '11.4.0', commit: 'deadbeef' },
+        snapshots: [
+          { analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp-hash' },
+          { analysis_type: 'phenotype_clusters', snapshot_id: 202, parameter_hash: 'pp-hash' },
+        ],
+      },
       layers: [
         {
           analysis_type: 'functional_clusters',
           parameter_hash: 'fp-hash',
           snapshot_id: 101,
           input_hash: 'in-func',
           payload_hash: 'pay-func',
           schema_version: '1.2',
           reproducibility_hash: 'repro-func',
           dependencies: null,
         },
         {
           analysis_type: 'phenotype_clusters',
           parameter_hash: 'pp-hash',
           snapshot_id: 202,
           input_hash: 'in-pheno',
           payload_hash: 'pay-pheno',
           schema_version: '1.2',
           reproducibility_hash: 'repro-pheno',
           dependencies: null,
         },
         {
           analysis_type: 'phenotype_functional_correlations',
           parameter_hash: 'cp-hash',
           snapshot_id: 303,
           input_hash: 'in-corr',
           payload_hash: 'pay-corr',
           schema_version: '1.2',
           reproducibility_hash: null,
           dependencies: {
             functional_clusters: { snapshot_id: 101, payload_hash: 'pay-func' },
             phenotype_clusters: { snapshot_id: 202, payload_hash: 'pay-pheno' },
           },
         },
       ],
       files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
       content_digest: 'a'.repeat(64),
     },
   };
 }

 describe('ReleaseManifestPanel', () => {
   it('renders all three integrity hashes', () => {
     const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
     const text = wrapper.text();
     expect(text).toContain('a'.repeat(64)); // content_digest
     expect(text).toContain('b'.repeat(64)); // manifest_sha256
     expect(text).toContain('c'.repeat(64)); // bundle_sha256
   });

   it('shows the correlation layer dependency lineage and its "n/a" reproducibility hash', () => {
     const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
     const text = wrapper.text();
     expect(text).toContain('n/a (not reproducible)');
     expect(text).toContain('Dependency lineage');
     expect(text).toContain('pay-func');
     expect(text).toContain('pay-pheno');
     expect(text).toContain('101');
     expect(text).toContain('202');
   });

   it('renders the version DOI as a doi.org link', () => {
     const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
     const link = wrapper.find('a[href="https://doi.org/10.5281/zenodo.1234"]');
     expect(link.exists()).toBe(true);
     expect(link.text()).toBe('10.5281/zenodo.1234');
   });

   it('shows "not yet assigned" when a DOI is null', () => {
     const release = makeReleaseDetail();
     release.zenodo = { record_url: null, version_doi: null, concept_doi: null };
     const wrapper = mount(ReleaseManifestPanel, { props: { release } });
     expect(wrapper.text()).toContain('not yet assigned');
   });

+  // HIGH (#573 Slice B Codex round-1 review): the DOI PATCH endpoint stores
+  // `zenodo.record_url` with no backend URL validation, so an admin-authored
+  // `javascript:` string must never become a clickable `<a href>` for an
+  // unauthenticated /DataReleases visitor.
+  it('does not render a clickable link for a javascript:-scheme record_url (renders plain text instead)', () => {
+    const release = makeReleaseDetail();
+    release.zenodo = {
+      ...release.zenodo,
+      record_url: 'javascript:alert(document.cookie)',
+    };
+    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
+
+    const maliciousAnchor = wrapper
+      .findAll('a')
+      .find((anchor) => (anchor.attributes('href') ?? '').startsWith('javascript:'));
+    expect(maliciousAnchor).toBeUndefined();
+
+    // The value itself is not lost — it is still shown, just as inert text.
+    expect(wrapper.text()).toContain('javascript:alert(document.cookie)');
+  });
+
+  it('does not render a clickable link for a data:-scheme record_url either', () => {
+    const release = makeReleaseDetail();
+    release.zenodo = {
+      ...release.zenodo,
+      record_url: 'data:text/html,<script>alert(1)</script>',
+    };
+    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
+
+    const dataAnchor = wrapper
+      .findAll('a')
+      .find((anchor) => (anchor.attributes('href') ?? '').startsWith('data:'));
+    expect(dataAnchor).toBeUndefined();
+  });
+
+  it('still renders a normal https record_url as a clickable link', () => {
+    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
+    const link = wrapper.find('a[href="https://zenodo.org/records/1234"]');
+    expect(link.exists()).toBe(true);
+    expect(link.text()).toBe('Record');
+  });
+
   it('omits the Version row when release_version is null (the current, always-null default)', () => {
     const release = makeReleaseDetail();
     expect(release.release_version).toBeNull();
     const wrapper = mount(ReleaseManifestPanel, { props: { release } });
     const dts = wrapper.findAll('dt').map((dt) => dt.text());
     expect(dts).not.toContain('Version');
   });

   it('shows the Version row when release_version is populated', () => {
     const release = makeReleaseDetail();
     release.release_version = '1.0';
     const wrapper = mount(ReleaseManifestPanel, { props: { release } });
     const dts = wrapper.findAll('dt').map((dt) => dt.text());
     expect(dts).toContain('Version');
     expect(wrapper.text()).toContain('1.0');
   });

   it('falls back to release_id for the title when title is null', () => {
     const release = makeReleaseDetail();
     release.title = null;
     const wrapper = mount(ReleaseManifestPanel, { props: { release } });
     expect(wrapper.find('#release-manifest-panel-title').text()).toBe('asr_0123456789abcdef');
     const dts = wrapper.findAll('dt').map((dt) => dt.text());
     const titleDd = wrapper.findAll('dt').find((dt) => dt.text() === 'Title')?.element.nextElementSibling;
     expect(dts).toContain('Title');
     expect(titleDd?.textContent).toBe('asr_0123456789abcdef');
   });

   it('copies a hash to the clipboard when its copy button is clicked', async () => {
     const writeText = vi.fn().mockResolvedValue(undefined);
     Object.defineProperty(navigator, 'clipboard', {
       configurable: true,
       value: { writeText },
     });

     const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
     const button = wrapper
       .findAll('button')
       .find((btn) => btn.attributes('aria-label') === 'Copy Content digest to clipboard');
     expect(button).toBeTruthy();

     await button!.trigger('click');
     await wrapper.vm.$nextTick();

     expect(writeText).toHaveBeenCalledWith('a'.repeat(64));
     expect(button!.text()).toContain('Copied');
   });
 });
diff --git a/app/src/components/analyses/ReleaseManifestPanel.vue b/app/src/components/analyses/ReleaseManifestPanel.vue
index 5ef9d461..70313c10 100644
--- a/app/src/components/analyses/ReleaseManifestPanel.vue
+++ b/app/src/components/analyses/ReleaseManifestPanel.vue
@@ -81,227 +81,251 @@
               class="release-manifest-panel__copy-button"
               :aria-label="`Copy ${hash.label} to clipboard`"
               @click="copyValue(hash.key, hash.value)"
             >
               <i class="bi bi-clipboard" aria-hidden="true" />
               {{ copiedKey === hash.key ? 'Copied' : 'Copy' }}
             </button>
           </dd>
         </div>
       </dl>
     </section>

     <section aria-label="Layers">
       <h3 class="release-manifest-panel__section-title">Layers</h3>
       <div
         v-for="layer in release.manifest.layers"
         :key="layer.analysis_type"
         class="release-manifest-panel__layer"
       >
         <h4 class="release-manifest-panel__layer-title">{{ layer.analysis_type }}</h4>
         <dl class="release-manifest-panel__grid">
           <div>
             <dt>Snapshot ID</dt>
             <dd>{{ layer.snapshot_id }}</dd>
           </div>
           <div>
             <dt>Payload hash</dt>
             <dd class="release-manifest-panel__mono">{{ displayValue(layer.payload_hash) }}</dd>
           </div>
           <div>
             <dt>Input hash</dt>
             <dd class="release-manifest-panel__mono">{{ displayValue(layer.input_hash) }}</dd>
           </div>
           <div>
             <dt>Reproducibility hash</dt>
             <dd class="release-manifest-panel__mono">
               <span v-if="layer.reproducibility_hash">{{ layer.reproducibility_hash }}</span>
               <span v-else class="text-muted">n/a (not reproducible)</span>
             </dd>
           </div>
         </dl>
       </div>
     </section>

     <section v-if="dependencyLayer" aria-label="Dependency lineage">
       <h3 class="release-manifest-panel__section-title">Dependency lineage</h3>
       <p class="release-manifest-panel__hint">
         {{ dependencyLayer.analysis_type }} is derived from these pinned source-layer snapshots.
       </p>
       <dl class="release-manifest-panel__grid">
         <div v-if="dependencyLayer.dependencies?.functional_clusters">
           <dt>Functional clusters</dt>
           <dd>
             snapshot {{ dependencyLayer.dependencies.functional_clusters.snapshot_id }}
             &middot;
             <span class="release-manifest-panel__mono">{{
               dependencyLayer.dependencies.functional_clusters.payload_hash
             }}</span>
           </dd>
         </div>
         <div v-if="dependencyLayer.dependencies?.phenotype_clusters">
           <dt>Phenotype clusters</dt>
           <dd>
             snapshot {{ dependencyLayer.dependencies.phenotype_clusters.snapshot_id }}
             &middot;
             <span class="release-manifest-panel__mono">{{
               dependencyLayer.dependencies.phenotype_clusters.payload_hash
             }}</span>
           </dd>
         </div>
       </dl>
     </section>

     <section aria-label="DOI">
       <h3 class="release-manifest-panel__section-title">DOI</h3>
       <dl class="release-manifest-panel__grid">
         <div>
           <dt>Version DOI</dt>
           <dd>
             <a
-              v-if="release.zenodo.version_doi"
-              :href="doiUrl(release.zenodo.version_doi)"
+              v-if="safeVersionDoiHref"
+              :href="safeVersionDoiHref"
               target="_blank"
               rel="noopener noreferrer"
             >
               {{ release.zenodo.version_doi }}
             </a>
+            <span v-else-if="release.zenodo.version_doi">{{ release.zenodo.version_doi }}</span>
             <span v-else class="text-muted">not yet assigned</span>
           </dd>
         </div>
         <div>
           <dt>Concept DOI</dt>
           <dd>
             <a
-              v-if="release.zenodo.concept_doi"
-              :href="doiUrl(release.zenodo.concept_doi)"
+              v-if="safeConceptDoiHref"
+              :href="safeConceptDoiHref"
               target="_blank"
               rel="noopener noreferrer"
             >
               {{ release.zenodo.concept_doi }}
             </a>
+            <span v-else-if="release.zenodo.concept_doi">{{ release.zenodo.concept_doi }}</span>
             <span v-else class="text-muted">not yet assigned</span>
           </dd>
         </div>
         <div>
           <dt>Zenodo record</dt>
           <dd>
+            <!--
+              HIGH (#573 Slice B Codex round-1): `zenodo.record_url` is an
+              admin-authored string with no backend URL validation, so it is
+              never bound to `:href` unguarded — `safeHttpUrl` only allows
+              http(s), rendering anything else (e.g. `javascript:...`) as
+              inert plain text instead of a clickable anchor.
+            -->
             <a
-              v-if="release.zenodo.record_url"
-              :href="release.zenodo.record_url"
+              v-if="safeRecordUrl"
+              :href="safeRecordUrl"
               target="_blank"
               rel="noopener noreferrer"
             >
               Record
             </a>
+            <span v-else-if="release.zenodo.record_url">{{ release.zenodo.record_url }}</span>
             <span v-else class="text-muted">not yet assigned</span>
           </dd>
         </div>
       </dl>
     </section>
   </section>
 </template>

 <script setup lang="ts">
 import { computed, onBeforeUnmount, ref } from 'vue';
 import { BBadge } from 'bootstrap-vue-next';
 import type { ReleaseDetail, ReleaseManifestLayer } from '@/api/analysis';
+import { safeHttpUrl } from '@/utils/safe-url';

 defineOptions({
   name: 'ReleaseManifestPanel',
 });

 const props = defineProps<{
   release: ReleaseDetail;
 }>();

 function displayValue(value: string | number | null | undefined): string {
   return value === null || value === undefined || value === '' ? '—' : String(value);
 }

 /** `title`, falling back to `release_id` when the reserved `title` column is null. */
 const displayTitle = computed(() => props.release.title || props.release.release_id);

 function doiUrl(doi: string): string {
   return `https://doi.org/${doi}`;
 }

+// HIGH (#573 Slice B Codex round-1): `zenodo.record_url` is admin-authored
+// and unvalidated by the backend, so it is guarded before ever reaching a
+// bound `:href` (see the template note above). The `doiUrl(...)`-constructed
+// DOI hrefs are guarded too, defensively — belt-and-suspenders, since the
+// scheme there is currently always the hardcoded `https://doi.org/` prefix.
+const safeRecordUrl = computed<string | null>(() => safeHttpUrl(props.release.zenodo.record_url));
+const safeVersionDoiHref = computed<string | null>(() =>
+  props.release.zenodo.version_doi ? safeHttpUrl(doiUrl(props.release.zenodo.version_doi)) : null
+);
+const safeConceptDoiHref = computed<string | null>(() =>
+  props.release.zenodo.concept_doi ? safeHttpUrl(doiUrl(props.release.zenodo.concept_doi)) : null
+);
+
 const integrityHashes = computed(() => [
   { key: 'content_digest', label: 'Content digest', value: props.release.content_digest },
   { key: 'manifest_sha256', label: 'Manifest SHA-256', value: props.release.manifest_sha256 },
   { key: 'bundle_sha256', label: 'Bundle SHA-256', value: props.release.bundle_sha256 },
 ]);

 /** The one manifest layer with pinned source-layer dependencies (the correlation layer), if any. */
 const dependencyLayer = computed<ReleaseManifestLayer | null>(
   () => props.release.manifest.layers.find((layer) => layer.dependencies != null) ?? null
 );

 // --- Copy-to-clipboard: mirrors small/GenericTableDetails.vue's transient
 // "Copy" -> "Copied" state + reset-timer lifecycle. ---
 const copiedKey = ref<string | null>(null);
 let copyResetTimer: ReturnType<typeof setTimeout> | null = null;

 async function copyValue(key: string, value: string): Promise<void> {
   if (!value || !navigator.clipboard?.writeText) {
     return;
   }
   try {
     await navigator.clipboard.writeText(value);
     copiedKey.value = key;
     if (copyResetTimer) {
       clearTimeout(copyResetTimer);
     }
     copyResetTimer = setTimeout(() => {
       copiedKey.value = null;
       copyResetTimer = null;
     }, 1600);
   } catch {
     copiedKey.value = null;
   }
 }

 onBeforeUnmount(() => {
   if (copyResetTimer) {
     clearTimeout(copyResetTimer);
     copyResetTimer = null;
   }
 });
 </script>

 <style scoped>
 .release-manifest-panel {
   display: grid;
   gap: 1rem;
   padding: 1rem;
   border: 1px solid #d7dee8;
   border-radius: var(--radius-lg, 8px);
   background: #fff;
   box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
 }

 .release-manifest-panel__header {
   display: flex;
   flex-wrap: wrap;
   align-items: flex-start;
   justify-content: space-between;
   gap: 0.75rem;
 }

 .release-manifest-panel__title {
   margin: 0;
   color: var(--neutral-900, #212121);
   font-size: 1rem;
   font-weight: 700;
   line-height: 1.25;
 }

 .release-manifest-panel__subtitle {
   margin: 0.15rem 0 0;
   color: var(--neutral-600, #757575);
   font-size: 0.875rem;
   line-height: 1.45;
 }

 .release-manifest-panel__badge {
   max-width: 100%;
   overflow-wrap: anywhere;
diff --git a/app/src/utils/safe-url.spec.ts b/app/src/utils/safe-url.spec.ts
new file mode 100644
index 00000000..b25970db
--- /dev/null
+++ b/app/src/utils/safe-url.spec.ts
@@ -0,0 +1,59 @@
+// app/src/utils/safe-url.spec.ts
+import { describe, expect, it } from 'vitest';
+import { safeHttpUrl } from './safe-url';
+
+describe('safeHttpUrl', () => {
+  it('returns an https URL unchanged', () => {
+    expect(safeHttpUrl('https://zenodo.org/records/1234')).toBe(
+      'https://zenodo.org/records/1234'
+    );
+  });
+
+  it('returns an http URL unchanged', () => {
+    expect(safeHttpUrl('http://example.org/path')).toBe('http://example.org/path');
+  });
+
+  it('rejects a javascript: scheme (returns null)', () => {
+    expect(safeHttpUrl('javascript:alert(document.cookie)')).toBeNull();
+  });
+
+  it('rejects a data: scheme (returns null)', () => {
+    expect(safeHttpUrl('data:text/html,<script>alert(1)</script>')).toBeNull();
+  });
+
+  it('rejects a vbscript: scheme (returns null)', () => {
+    expect(safeHttpUrl('vbscript:msgbox(1)')).toBeNull();
+  });
+
+  it('returns null for an empty string', () => {
+    expect(safeHttpUrl('')).toBeNull();
+  });
+
+  it('returns null for a whitespace-only string', () => {
+    expect(safeHttpUrl('   ')).toBeNull();
+  });
+
+  it('returns null for null', () => {
+    expect(safeHttpUrl(null)).toBeNull();
+  });
+
+  it('returns null for undefined', () => {
+    expect(safeHttpUrl(undefined)).toBeNull();
+  });
+
+  it('returns null for a non-string value', () => {
+    expect(safeHttpUrl(42)).toBeNull();
+    expect(safeHttpUrl({ href: 'https://evil.example' })).toBeNull();
+  });
+
+  it('resolves a relative path against the current origin and returns the original value', () => {
+    // A relative path has no explicit scheme, so it resolves against
+    // window.location.origin (http: in the jsdom test env) and is allowed —
+    // the returned value is the ORIGINAL string, not the resolved absolute URL.
+    expect(safeHttpUrl('/some/path')).toBe('/some/path');
+  });
+
+  it('rejects a malformed URL that fails to parse even against the origin base', () => {
+    expect(safeHttpUrl('http://')).toBeNull();
+  });
+});
diff --git a/app/src/utils/safe-url.ts b/app/src/utils/safe-url.ts
new file mode 100644
index 00000000..24af04b6
--- /dev/null
+++ b/app/src/utils/safe-url.ts
@@ -0,0 +1,22 @@
+// app/src/utils/safe-url.ts
+//
+// Guards a bound `:href` against scheme injection (#573 Slice B, Codex round-1
+// review, HIGH). Vue does not sanitize `javascript:`/`data:`/etc. schemes on a
+// bound `:href` — if any admin-authored or upstream string ever reaches a
+// public anchor's `href` unvalidated (e.g. `zenodo.record_url`, recorded via
+// `PATCH /api/admin/analysis/releases/<id>/doi` with no URL validation on the
+// backend), an unauthenticated visitor gets a clickable script URL.
+
+/**
+ * Return the URL only if it parses as an http(s) URL; otherwise null.
+ * Guards against javascript:/data:/etc. scheme injection in bound hrefs.
+ */
+export function safeHttpUrl(value: unknown): string | null {
+  if (typeof value !== 'string' || value.trim() === '') return null;
+  try {
+    const u = new URL(value, window.location.origin);
+    return u.protocol === 'http:' || u.protocol === 'https:' ? value : null;
+  } catch {
+    return null;
+  }
+}
diff --git a/app/src/views/admin/ManageAnalysisReleases.spec.ts b/app/src/views/admin/ManageAnalysisReleases.spec.ts
index e011799a..6322c573 100644
--- a/app/src/views/admin/ManageAnalysisReleases.spec.ts
+++ b/app/src/views/admin/ManageAnalysisReleases.spec.ts
@@ -228,107 +228,185 @@ describe('ManageAnalysisReleases.vue', () => {
     await flushPromises();

     expect(wrapper.text()).toContain('asr_draft1');
     const publishBtn = wrapper.find('[data-testid="publish-asr_draft1"]');
     expect(publishBtn.exists()).toBe(true);

     await publishBtn.trigger('click');
     await flushPromises();

     expect(publishReleaseMock).toHaveBeenCalledWith('asr_draft1');
   });

   it('does not render a Publish action for an already-published release', async () => {
     const release = makeRelease({ release_id: 'asr_pub1', status: 'published' });
     listAdminReleasesMock.mockResolvedValue({
       releases: [release],
       pagination: { limit: 50, offset: 0, count: 1 },
     });

     const wrapper = mountView();
     await flushPromises();

     expect(wrapper.find('[data-testid="publish-asr_pub1"]').exists()).toBe(false);
   });

   it('the Record-DOI control calls recordReleaseDoi with only the filled fields', async () => {
     const release = makeRelease({ release_id: 'asr_doi1', status: 'published' });
     listAdminReleasesMock.mockResolvedValue({
       releases: [release],
       pagination: { limit: 50, offset: 0, count: 1 },
     });
     recordReleaseDoiMock.mockResolvedValue({ ...release, version_doi: '10.5281/zenodo.99' });

     const wrapper = mountView();
     await flushPromises();

     await wrapper.find('[data-testid="toggle-doi-asr_doi1"]').trigger('click');
     await flushPromises();

     const versionInput = wrapper.find('[data-testid="doi-version-input-asr_doi1"]');
     expect(versionInput.exists()).toBe(true);
     await versionInput.setValue('10.5281/zenodo.99');

     await wrapper.find('[data-testid="save-doi-asr_doi1"]').trigger('click');
     await flushPromises();

     expect(recordReleaseDoiMock).toHaveBeenCalledWith('asr_doi1', {
       version_doi: '10.5281/zenodo.99',
     });
   });

   it('surfaces a failed Publish action error co-located in the Releases panel, not the readiness panel', async () => {
     const release = makeRelease({ release_id: 'asr_fail1', status: 'draft' });
     listAdminReleasesMock.mockResolvedValue({
       releases: [release],
       pagination: { limit: 50, offset: 0, count: 1 },
     });
     publishReleaseMock.mockRejectedValue({
       response: { data: { detail: 'release not found' } },
     });

     const wrapper = mountView();
     await flushPromises();

     await wrapper.find('[data-testid="publish-asr_fail1"]').trigger('click');
     await flushPromises();

     const panels = wrapper.findAll('[data-testid="admin-operation-panel"]');
     expect(panels).toHaveLength(3);
     const [readinessPanel, , releasesPanel] = panels;

     const errorInReleasesPanel = releasesPanel.find('[data-testid="action-error"]');
     expect(errorInReleasesPanel.exists()).toBe(true);
     expect(errorInReleasesPanel.text()).toContain('release not found');

     // The regression this guards: actionError used to render in the
     // Snapshot-readiness panel, far from the row action that triggered it.
     expect(readinessPanel.find('[data-testid="action-error"]').exists()).toBe(false);
   });

+  // LOW (#573 Slice B Codex round-1 review): the rejected-Publish test above
+  // was the only DOI-save/delete failure-path coverage. Add the missing two.
+  it('surfaces a failed DOI-save action error co-located in the Releases panel and keeps the DOI form open', async () => {
+    const release = makeRelease({ release_id: 'asr_doifail', status: 'published' });
+    listAdminReleasesMock.mockResolvedValue({
+      releases: [release],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+    recordReleaseDoiMock.mockRejectedValue({
+      response: { data: { detail: 'invalid DOI format' } },
+    });
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    await wrapper.find('[data-testid="toggle-doi-asr_doifail"]').trigger('click');
+    await flushPromises();
+
+    const versionInput = wrapper.find('[data-testid="doi-version-input-asr_doifail"]');
+    expect(versionInput.exists()).toBe(true);
+    await versionInput.setValue('not-a-real-doi');
+
+    await wrapper.find('[data-testid="save-doi-asr_doifail"]').trigger('click');
+    await flushPromises();
+
+    expect(recordReleaseDoiMock).toHaveBeenCalledWith('asr_doifail', {
+      version_doi: 'not-a-real-doi',
+    });
+
+    const panels = wrapper.findAll('[data-testid="admin-operation-panel"]');
+    const releasesPanel = panels[2];
+    const errorInReleasesPanel = releasesPanel.find('[data-testid="action-error"]');
+    expect(errorInReleasesPanel.exists()).toBe(true);
+    expect(errorInReleasesPanel.text()).toContain('invalid DOI format');
+
+    // A failed save must not silently collapse the form the operator was
+    // editing — the row stays expanded so the error is visible next to it.
+    expect(wrapper.find('[data-testid="doi-form-asr_doifail"]').exists()).toBe(true);
+  });
+
+  it('surfaces a failed draft-deletion action error and resets the confirm state without removing the row', async () => {
+    const release = makeRelease({ release_id: 'asr_delfail', status: 'draft' });
+    listAdminReleasesMock.mockResolvedValue({
+      releases: [release],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+    deleteDraftReleaseMock.mockRejectedValue({
+      response: { data: { detail: 'release has published dependents' } },
+    });
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    await wrapper.find('[data-testid="delete-asr_delfail"]').trigger('click');
+    await flushPromises();
+    expect(wrapper.find('[data-testid="confirm-delete-asr_delfail"]').exists()).toBe(true);
+
+    await wrapper.find('[data-testid="confirm-delete-asr_delfail"]').trigger('click');
+    await flushPromises();
+
+    expect(deleteDraftReleaseMock).toHaveBeenCalledWith('asr_delfail');
+
+    const panels = wrapper.findAll('[data-testid="admin-operation-panel"]');
+    const releasesPanel = panels[2];
+    const errorInReleasesPanel = releasesPanel.find('[data-testid="action-error"]');
+    expect(errorInReleasesPanel.exists()).toBe(true);
+    expect(errorInReleasesPanel.text()).toContain('release has published dependents');
+
+    // Sane failure handling: the confirm flow resets to the initial
+    // "Delete draft" affordance (not stuck showing "Confirm delete" forever)
+    // AND the row is not silently removed (loadReleases() only re-runs on a
+    // successful delete) — the operator sees the error next to a
+    // still-present, retryable row, not a vanished one.
+    expect(wrapper.find('[data-testid="confirm-delete-asr_delfail"]').exists()).toBe(false);
+    expect(wrapper.find('[data-testid="delete-asr_delfail"]').exists()).toBe(true);
+    expect(wrapper.text()).toContain('asr_delfail');
+  });
+
   it('deletes a draft only after the two-step in-page confirm, never via a blocking dialog', async () => {
     const confirmSpy = vi.spyOn(window, 'confirm');
     const release = makeRelease({ release_id: 'asr_draft2', status: 'draft' });
     listAdminReleasesMock.mockResolvedValue({
       releases: [release],
       pagination: { limit: 50, offset: 0, count: 1 },
     });
     deleteDraftReleaseMock.mockResolvedValue(undefined);

     const wrapper = mountView();
     await flushPromises();

     expect(wrapper.find('[data-testid="confirm-delete-asr_draft2"]').exists()).toBe(false);

     await wrapper.find('[data-testid="delete-asr_draft2"]').trigger('click');
     await flushPromises();

     expect(deleteDraftReleaseMock).not.toHaveBeenCalled();
     expect(confirmSpy).not.toHaveBeenCalled();

     await wrapper.find('[data-testid="confirm-delete-asr_draft2"]').trigger('click');
     await flushPromises();

     expect(deleteDraftReleaseMock).toHaveBeenCalledWith('asr_draft2');
     expect(confirmSpy).not.toHaveBeenCalled();
   });
 });
diff --git a/app/src/views/analyses/DataReleases.spec.ts b/app/src/views/analyses/DataReleases.spec.ts
index b164668b..3a4f373e 100644
--- a/app/src/views/analyses/DataReleases.spec.ts
+++ b/app/src/views/analyses/DataReleases.spec.ts
@@ -1,167 +1,228 @@
 import { mount, flushPromises } from '@vue/test-utils';
 import { describe, expect, it, vi, beforeEach } from 'vitest';
 import type { ReleaseDetail, ReleaseHead } from '@/api/analysis_releases';

 vi.mock('@unhead/vue', () => ({
   useHead: vi.fn(),
 }));

 vi.mock('@/composables/useToast', () => ({
   default: () => ({ makeToast: vi.fn() }),
 }));

 const listReleasesMock = vi.fn();
 const getLatestReleaseMock = vi.fn();
 const getReleaseMock = vi.fn();
 const downloadReleaseBundleMock = vi.fn();
 const downloadReleaseManifestMock = vi.fn();
 const downloadReleaseFileMock = vi.fn();

 vi.mock('@/api/analysis', () => ({
   listReleases: (...args: unknown[]) => listReleasesMock(...args),
   getLatestRelease: (...args: unknown[]) => getLatestReleaseMock(...args),
   getRelease: (...args: unknown[]) => getReleaseMock(...args),
   downloadReleaseBundle: (...args: unknown[]) => downloadReleaseBundleMock(...args),
   downloadReleaseManifest: (...args: unknown[]) => downloadReleaseManifestMock(...args),
   downloadReleaseFile: (...args: unknown[]) => downloadReleaseFileMock(...args),
 }));

 import DataReleases from './DataReleases.vue';

 function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
   return {
     release_id: 'asr_0123456789abcdef',
     release_version: null,
     title: 'SysNDD analysis-snapshot release',
     status: 'published',
     content_digest: 'a'.repeat(64),
     created_at: '2026-07-01T00:00:00Z',
     published_at: '2026-07-01T00:05:00Z',
     source_data_version: '2026-07-01',
     db_release_version: '11.4.0',
     db_release_commit: 'deadbeef',
     manifest_sha256: 'b'.repeat(64),
     bundle_sha256: 'c'.repeat(64),
     license: 'CC-BY-4.0',
     file_count: 1,
     total_bytes: 1258291,
     zenodo: { record_url: null, version_doi: null, concept_doi: null },
     ...overrides,
   };
 }

 function makeReleaseDetail(overrides: Partial<ReleaseHead> = {}): ReleaseDetail {
   return {
     ...makeReleaseHead(overrides),
     manifest: {
-      release_id: 'asr_0123456789abcdef',
+      release_id: overrides.release_id ?? 'asr_0123456789abcdef',
       release_version: null,
       title: 'SysNDD analysis-snapshot release',
       created_at: '2026-07-01T00:00:00Z',
       license: 'CC-BY-4.0',
       scope_statement: 'Public derived analysis only.',
-      generator: 'sysndd-api',
-      source: 'sysndd',
+      // `manifest.generator`/`manifest.source` are nested objects on the wire
+      // (api/functions/analysis-snapshot-release.R), not strings.
+      generator: {
+        name: 'sysndd-analysis-snapshot-release-build',
+        manifest_schema_version: '1.0',
+        reproducibility_schema_version: '1.2',
+      },
+      source: {
+        source_data_version: '2026-07-01',
+        db_release: { version: '11.4.0', commit: 'deadbeef' },
+        snapshots: [
+          { analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp-hash' },
+        ],
+      },
       layers: [
         {
           analysis_type: 'functional_clusters',
           parameter_hash: 'fp-hash',
           snapshot_id: 101,
           input_hash: 'in-func',
           payload_hash: 'pay-func',
           schema_version: '1.2',
           reproducibility_hash: 'repro-func',
           dependencies: null,
         },
       ],
       files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
       content_digest: 'a'.repeat(64),
     },
   };
 }

 function notFoundError() {
   return Object.assign(new Error('Not found'), {
     isAxiosError: true,
-    response: { status: 404, data: { message: 'No published analysis-snapshot release exists yet' } },
+    response: {
+      status: 404,
+      data: {
+        type: 'about:blank',
+        title: 'Not Found',
+        status: 404,
+        detail: 'No published analysis-snapshot release exists yet',
+      },
+    },
   });
 }

 describe('DataReleases', () => {
   beforeEach(() => {
     vi.clearAllMocks();
     // jsdom has no real object-URL / anchor-download support.
     window.URL.createObjectURL = vi.fn(() => 'blob:mock-url');
     window.URL.revokeObjectURL = vi.fn();
   });

   it('renders the release table row and the manifest panel for the latest release', async () => {
     listReleasesMock.mockResolvedValue({
       releases: [makeReleaseHead()],
       pagination: { limit: 50, offset: 0, count: 1 },
     });
     getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());

     const wrapper = mount(DataReleases);
     await flushPromises();

     expect(listReleasesMock).toHaveBeenCalled();
     expect(getLatestReleaseMock).toHaveBeenCalled();
     const text = wrapper.text();
     expect(text).toContain('asr_0123456789abcdef');
     expect(text).toContain('Integrity hashes');
     expect(text).toContain('a'.repeat(64));
   });

   it('re-fetches the detail for a different release when its "View manifest" button is clicked', async () => {
     listReleasesMock.mockResolvedValue({
       releases: [makeReleaseHead({ release_id: 'asr_other' })],
       pagination: { limit: 50, offset: 0, count: 1 },
     });
     getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
     getReleaseMock.mockResolvedValue(makeReleaseDetail({ release_id: 'asr_other' }));

     const wrapper = mount(DataReleases);
     await flushPromises();

     const button = wrapper
       .findAll('button')
       .find((btn) => btn.text().includes('View manifest'));
     expect(button).toBeTruthy();
     await button!.trigger('click');
     await flushPromises();

     expect(getReleaseMock).toHaveBeenCalledWith('asr_other');
   });

+  // MEDIUM (#573 Slice B Codex round-1 review): a slow mount-time
+  // `getLatestRelease()` must not clobber a later, already-resolved
+  // `getRelease(id)` selection when it finally settles. Regression-guards the
+  // monotonic request token in `loadDetail()`.
+  it('discards a stale getLatestRelease response that resolves after a later "View manifest" selection', async () => {
+    listReleasesMock.mockResolvedValue({
+      releases: [makeReleaseHead({ release_id: 'asr_other' })],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+
+    let resolveLatest: (value: ReleaseDetail) => void = () => {};
+    getLatestReleaseMock.mockReturnValue(
+      new Promise<ReleaseDetail>((resolve) => {
+        resolveLatest = resolve;
+      })
+    );
+    getReleaseMock.mockResolvedValue(makeReleaseDetail({ release_id: 'asr_other' }));
+
+    const wrapper = mount(DataReleases);
+    // The list resolves; the mount-time getLatestRelease() request is still pending.
+    await flushPromises();
+
+    const button = wrapper
+      .findAll('button')
+      .find((btn) => btn.text().includes('View manifest'));
+    expect(button).toBeTruthy();
+    await button!.trigger('click');
+    await flushPromises();
+
+    // The later request (getRelease) resolved first and is now shown.
+    expect(wrapper.text()).toContain('asr_other');
+
+    // The stale, earlier-started getLatestRelease request finally settles with
+    // a DIFFERENT release. It must be discarded, not overwrite the selection.
+    resolveLatest(makeReleaseDetail({ release_id: 'asr_0123456789abcdef' }));
+    await flushPromises();
+
+    expect(wrapper.text()).toContain('asr_other');
+    expect(wrapper.text()).not.toContain('asr_0123456789abcdef');
+  });
+
   it('downloads the bundle when the download-bundle button is clicked', async () => {
     listReleasesMock.mockResolvedValue({
       releases: [makeReleaseHead()],
       pagination: { limit: 50, offset: 0, count: 1 },
     });
     getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
     downloadReleaseBundleMock.mockResolvedValue(new Blob(['bundle-bytes']));

     const wrapper = mount(DataReleases);
     await flushPromises();

     await wrapper.find('[data-testid="download-bundle-button"]').trigger('click');
     await flushPromises();

     expect(downloadReleaseBundleMock).toHaveBeenCalledWith('asr_0123456789abcdef');
   });

   it('shows the "No releases published yet" empty state on a 404 from getLatestRelease, not a raw error', async () => {
     listReleasesMock.mockResolvedValue({
       releases: [],
       pagination: { limit: 50, offset: 0, count: 0 },
     });
     getLatestReleaseMock.mockRejectedValue(notFoundError());

     const wrapper = mount(DataReleases);
     await flushPromises();

     expect(wrapper.text()).toContain('No releases published yet');
     expect(wrapper.find('[data-testid="section-card-error"]').exists()).toBe(false);
   });
 });
diff --git a/app/src/views/analyses/DataReleases.vue b/app/src/views/analyses/DataReleases.vue
index fca7b433..e6d7bc11 100644
--- a/app/src/views/analyses/DataReleases.vue
+++ b/app/src/views/analyses/DataReleases.vue
@@ -106,191 +106,206 @@
               <code>sha256(reproducibility.json)</code> matches that layer's
               <code>reproducibility_hash</code> exactly — the phenotype-functional correlation
               layer has no reproducibility bundle (<code>reproducibility_hash</code> is
               <code>null</code>).
             </li>
             <li>
               <code>payload_hash</code>, <code>input_hash</code>, and <code>snapshot_id</code> are
               lineage anchors: cross-check them against the live <code>meta.snapshot</code> block
               on the matching <code>/api/analysis/*</code> endpoint. They are
               <strong>not</strong> a hash of this release's own <code>payload.json</code> — the
               values round-trip through <code>DECIMAL</code> database columns before the release
               freezes them, so a byte-for-byte match of the payload file is neither guaranteed nor
               attempted.
             </li>
           </ul>
         </details>
       </template>
       <EmptyState
         v-else-if="!detailLoading && !detailError"
         icon="archive"
         title="No releases published yet"
         message="Analysis-snapshot releases are published periodically once public snapshots are available. Check back soon."
       />
     </SectionCard>
   </AnalysisShell>
 </template>

 <script setup lang="ts">
 import { onMounted, ref } from 'vue';
 import { useHead } from '@unhead/vue';
 import { BButton } from 'bootstrap-vue-next';
 import AnalysisShell from '@/components/analyses/AnalysisShell.vue';
 import SectionCard from '@/components/ui/SectionCard.vue';
 import EmptyState from '@/components/ui/EmptyState.vue';
 import GenericTable from '@/components/small/GenericTable.vue';
 import ReleaseManifestPanel from '@/components/analyses/ReleaseManifestPanel.vue';
 import {
   normalizeReleaseRows,
   formatReleaseBytes,
   RELEASE_TABLE_FIELDS,
   type ReleaseTableRow,
 } from '@/components/analyses/dataReleaseTable';
 import {
   listReleases,
   getLatestRelease,
   getRelease,
   downloadReleaseBundle,
   downloadReleaseManifest,
   downloadReleaseFile,
   type ReleaseDetail,
 } from '@/api/analysis';
 import { isApiError } from '@/api/client';
 import { extractApiErrorMessage } from '@/utils/api-errors';
 import useToast from '@/composables/useToast';

 defineOptions({
   name: 'DataReleases',
 });

 useHead({
   title: 'Analysis-snapshot releases',
   meta: [
     {
       name: 'description',
       content:
         "Download and independently verify SysNDD's immutable, content-addressed analysis-snapshot releases: functional gene clusters, phenotype clusters, and their correlation.",
     },
   ],
 });

 const { makeToast } = useToast();

 const releaseRows = ref<ReleaseTableRow[]>([]);
 const listLoading = ref(true);
 const listError = ref<string | null>(null);

 const selectedRelease = ref<ReleaseDetail | null>(null);
 const detailLoading = ref(true);
 const detailError = ref<string | null>(null);

+/**
+ * MEDIUM (#573 Slice B Codex round-1 review): monotonic request token
+ * guarding against a stale-response race. If the mount-time
+ * `getLatestRelease()` resolves AFTER the user has since clicked "View
+ * manifest" on another row (a newer `getRelease(id)` request), the late
+ * response must not overwrite `selectedRelease` with the wrong release.
+ */
+let detailRequestSeq = 0;
+
 async function loadList(): Promise<void> {
   listLoading.value = true;
   listError.value = null;
   try {
     const response = await listReleases();
     releaseRows.value = normalizeReleaseRows(response.releases);
   } catch (err) {
     listError.value = extractApiErrorMessage(err, 'Failed to load analysis-snapshot releases.');
   } finally {
     listLoading.value = false;
   }
 }

 /**
  * Loads a release detail (head + manifest) via the given fetcher. A 404 is
  * the "no published release" empty state, not an error — see the file
  * header for why that renders through the default slot rather than
  * SectionCard's `empty` prop.
  */
 async function loadDetail(fetcher: () => Promise<ReleaseDetail>): Promise<void> {
+  const token = ++detailRequestSeq;
   detailLoading.value = true;
   detailError.value = null;
   try {
-    selectedRelease.value = await fetcher();
+    const result = await fetcher();
+    if (token !== detailRequestSeq) return; // a newer request has since started; discard
+    selectedRelease.value = result;
   } catch (err) {
+    if (token !== detailRequestSeq) return; // a newer request has since started; discard
     selectedRelease.value = null;
     if (!(isApiError(err) && err.response?.status === 404)) {
       detailError.value = extractApiErrorMessage(err, 'Failed to load the release manifest.');
     }
   } finally {
-    detailLoading.value = false;
+    if (token === detailRequestSeq) {
+      detailLoading.value = false;
+    }
   }
 }

 function selectRelease(releaseId: string): void {
   void loadDetail(() => getRelease(releaseId));
 }

 /** Triggers a browser download for a Blob via a transient object-URL anchor. */
 function triggerBlobDownload(blob: Blob, filename: string): void {
   const url = window.URL.createObjectURL(blob);
   const link = document.createElement('a');
   link.href = url;
   link.setAttribute('download', filename);
   document.body.appendChild(link);
   link.click();
   document.body.removeChild(link);
   window.URL.revokeObjectURL(url);
 }

 async function handleDownloadBundle(): Promise<void> {
   const release = selectedRelease.value;
   if (!release) return;
   try {
     const blob = await downloadReleaseBundle(release.release_id);
     triggerBlobDownload(blob, `${release.release_id}_bundle.tar.gz`);
   } catch (err) {
     makeToast(extractApiErrorMessage(err, 'Bundle download failed.'), 'Error', 'danger');
   }
 }

 async function handleDownloadManifest(): Promise<void> {
   const release = selectedRelease.value;
   if (!release) return;
   try {
     const blob = await downloadReleaseManifest(release.release_id);
     triggerBlobDownload(blob, `${release.release_id}_manifest.json`);
   } catch (err) {
     makeToast(extractApiErrorMessage(err, 'Manifest download failed.'), 'Error', 'danger');
   }
 }

 async function handleDownloadFile(path: string): Promise<void> {
   const release = selectedRelease.value;
   if (!release) return;
   try {
     const blob = await downloadReleaseFile(release.release_id, path);
     triggerBlobDownload(blob, path.split('/').pop() || path);
   } catch (err) {
     makeToast(extractApiErrorMessage(err, 'File download failed.'), 'Error', 'danger');
   }
 }

 onMounted(() => {
   void loadList();
   void loadDetail(() => getLatestRelease());
 });
 </script>

 <style scoped>
 .data-releases__manifest-card {
   margin-top: 1rem;
 }

 .data-releases__section-title {
   margin: 0 0 0.5rem;
   color: var(--neutral-700, #616161);
   font-size: 0.8125rem;
   font-weight: 700;
   text-transform: uppercase;
   letter-spacing: 0.02em;
 }

 .data-releases__section-subtitle {
   margin: 0.75rem 0 0.35rem;
   color: var(--neutral-700, #616161);
   font-size: 0.8125rem;
   font-weight: 700;
 }

 .data-releases__downloads {
diff --git a/AGENTS.md b/AGENTS.md
index 7aa9b3e1..81a7f545 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -122,6 +122,7 @@ Analysis-snapshot **releases** are immutable, content-addressed, frozen exports
 - **Never pruned.** A published release is permanent; `DELETE /api/admin/analysis/releases/<id>` only works on a `draft`. `analysis_snapshot_prune()` (`analysis-snapshot-repository.R`) now skips any `snapshot_id` still referenced by an `analysis_snapshot_release_member` row (`analysis_release_referenced_snapshot_ids()`), so a snapshot pinned by a release keeps serving its live reproducibility endpoint too — even though release integrity never depends on the source snapshot surviving (each release is self-contained).
 - **Build is synchronous, admin, DB-only — the worker is NOT required.** Unlike snapshot refresh, `POST /api/admin/analysis/releases` runs inline on the API request (`analysis_snapshot_release_build()` is called directly from the endpoint, not submitted as an async job): no clustering recompute, no external calls, no LLM, no cache writes. A release can be built even if the worker is down, as long as public-ready snapshots already exist.
 - **`GET .../releases/<release_id>/file?path=<file_path>` uses a query param, not a nested path segment**, because Plumber 1.3.2 has no `<path:.*>` wildcard — only named, typed, single-segment path params (`<id>`, `<id:int>`) exist, so a nested archive path (e.g. `functional_clusters/payload.json`) cannot be expressed as a URL path segment. The manifest's `files[].path` values are the caller's index into this route.
+- **Frontend surfaces (Slice B).** Two typed clients mirror the routes above: the public `app/src/api/analysis_releases.ts` (re-exported from `analysis.ts` — the single `@/api/analysis` import surface) and the Administrator-only `app/src/api/admin_analysis_release.ts`. They are deliberately DIFFERENT types: the public `ReleaseHead` mirrors the 14-field allowlist + nested `zenodo{}` and NEVER carries `created_by_user_id`/`last_error_message`; the admin `AdminReleaseHead` is the raw head with FLAT DOI columns (`version_doi`/`concept_doi`/`zenodo_record_id`/`zenodo_record_url`) and those operational columns. `release_version` is a reserved `VARCHAR` the builder always inserts as `NULL`, so both clients type it `string | null` (not a number) and the UI never shows an always-empty "Version" column — the release label falls back to `release_id` when `title` is null. The public `/DataReleases` page (`views/analyses/DataReleases.vue`, Analyses navbar) lists releases and renders a `ReleaseManifestPanel` provenance card + download/verify affordances; it fetches the DETAIL route (`getLatestRelease`/`getRelease`) for `manifest`+`files[]` because the LIST route carries only light per-layer `layers`. The Administrator `/ManageAnalysisReleases` page (`views/admin/ManageAnalysisReleases.vue` + `useAnalysisReleaseAdmin` composable) does the synchronous build/publish/DOI/delete-draft flow, disables Build until all three release layers report `available` (from `GET /snapshots/status`, ignoring the non-release presets), and surfaces the 503 `release_lock_unavailable` distinctly from the 400 gate classes. When binding release rows into `GenericTable`, flatten any dotted keys (`zenodo.version_doi` → `zenodo_version_doi`) — BootstrapVueNext's `BTable` renders a blank cell for a dotted field key.

 ### Cluster-analysis statistical soundness (#508–#512)

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 48651d8b..ed80ad6d 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -6,6 +6,56 @@ The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),

 ## [Unreleased]

+## [0.30.2] — 2026-07-19
+
+Public + Administrator UI for the immutable analysis-snapshot releases added in
+0.30.0 (#573, Slice B). The frozen, content-addressed release artifacts are now
+browsable, downloadable, and verifiable from the app, and an operator can build,
+publish, and DOI-tag them without SSH or `docker exec`.
+
+> Note: 0.30.1 is reserved for the category-selected clustering universes work
+> (#574, Slice D); this Slice-B UI release assumes that lands first.
+
+### Added
+
+- **Public `/DataReleases` page** (`views/analyses/DataReleases.vue`,
+  discoverable from the Analyses navbar dropdown): lists published releases in a
+  table (with the dotted `zenodo.*` keys flattened to flat field keys so
+  BootstrapVueNext's `BTable` can render them), and shows a
+  `ReleaseManifestPanel` provenance card (styled like the NDDScore model card)
+  with the release identity, the three integrity hashes (`content_digest`,
+  `manifest_sha256`, `bundle_sha256`) with copy buttons, per-layer
+  `snapshot_id`/`payload_hash`/`input_hash`/`reproducibility_hash`, the
+  correlation layer's pinned dependency lineage, and DOI links. Download buttons
+  for the whole `bundle.tar.gz`, the exact `manifest.json` bytes, and each
+  individual manifest file, plus a "How to verify" disclosure explaining the
+  hashing model (including that `payload_hash`/`input_hash`/`snapshot_id` are
+  cross-checkable lineage anchors, not a hash of the release's own
+  `payload.json`).
+- **Administrator `Manage releases` page**
+  (`views/admin/ManageAnalysisReleases.vue`): synchronous, DB-only build /
+  publish / record-DOI / delete-draft flows over a co-located
+  `useAnalysisReleaseAdmin` composable. The Build action is disabled unless all
+  three release layers (`functional_clusters`, `phenotype_clusters`,
+  `phenotype_functional_correlations`) report `available` from the snapshot
+  status endpoint, and the transient `release_lock_unavailable` (HTTP 503,
+  sources mid-refresh) response is surfaced distinctly from the 400 gate
+  failures.
+- **Typed API clients** for the release surface: the public
+  `analysis_releases.ts` (re-exported from `analysis.ts`) and the
+  Administrator-only `admin_analysis_release.ts`, both mirroring the exact
+  backend contracts (the public 14-field head allowlist that never exposes
+  `created_by_user_id`/`last_error_message`; the admin raw head with flat DOI
+  columns).
+
+### Fixed
+
+- `release_version`/`title` are typed as nullable everywhere in the release
+  clients — `release_version` is a reserved `VARCHAR` the builder currently
+  always inserts as `NULL`, so the always-empty "Version" column was dropped
+  from the public table and made conditional in the manifest panel, and the
+  release label falls back to `release_id` when the title is null.
+
 ## [0.30.0] — 2026-07-18

 Immutable public analysis-snapshot releases (#573, Slice A). SysNDD's derived
diff --git a/api/version_spec.json b/api/version_spec.json
index 86e2b6e6..b533ef2c 100644
--- a/api/version_spec.json
+++ b/api/version_spec.json
@@ -1,7 +1,7 @@
 {
   "title": "SysNDD API",
   "description": "This is the API powering the SysNDD website, allowing programmatic access to the database contents.",
-  "version": "0.30.0",
+  "version": "0.30.2",
   "contact": {
     "name": "API Support",
     "url": "https://berntpopp.github.io/sysndd/api.html",
diff --git a/app/package.json b/app/package.json
index ea8dbd91..731cacc1 100644
--- a/app/package.json
+++ b/app/package.json
@@ -1,6 +1,6 @@
 {
   "name": "sysndd",
-  "version": "0.30.0",
+  "version": "0.30.2",
   "private": true,
   "type": "module",
   "scripts": {
diff --git a/documentation/09-deployment.qmd b/documentation/09-deployment.qmd
index ff2dc9b5..3f69e4ed 100644
--- a/documentation/09-deployment.qmd
+++ b/documentation/09-deployment.qmd
@@ -309,6 +309,8 @@ curl -sS -X PATCH https://<host>/api/admin/analysis/releases/<release_id>/doi \

 **Retention.** Published releases are immutable and retained indefinitely; there is no automatic pruning, and `DELETE /api/admin/analysis/releases/<id>` only accepts a `draft` (a failed/aborted build). A later snapshot refresh followed by a fresh build mints a **new** release with a new `content_digest`/`release_id`; every prior release stays byte-identical because each holds its own frozen, self-contained copy — it does not depend on the source snapshot still existing. `analysis_snapshot_prune()` additionally skips any snapshot still referenced by a release member, so a pinned snapshot's live reproducibility endpoint keeps working for as long as any release cites it.

+**UI alternative (#573 Slice B).** Every operator step above is also available in the browser, so no SSH/`curl` is required. The Administrator **Manage releases** page (`/ManageAnalysisReleases`, in the Administration navbar dropdown) builds (with a "Publish immediately" toggle that defaults to *draft* so you can review first), publishes, records a DOI, and deletes drafts. It disables the Build action until all three release layers (`functional_clusters`, `phenotype_clusters`, `phenotype_functional_correlations`) report `available`, and surfaces the transient `release_lock_unavailable` (HTTP 503, sources mid-refresh) response distinctly from the 400 gate failures. The public, unauthenticated **Data releases** page (`/DataReleases`, in the Analyses navbar dropdown) lists published releases and lets any visitor download the `bundle.tar.gz` / `manifest.json` / individual files and read the integrity hashes, per-layer lineage, and DOI links needed to verify a release independently.
+
 **Reproducibility boundary.** A release reproduces the served separation metrics (functional modularity, phenotype silhouette) and the phenotype-functional cross-cluster correlation from the bundled reproducibility inputs — recompute them per the "Verify" instructions in the release's own `README.md`. LLM cluster summaries and precomputed fCoSE network-layout coordinates are **served-only** and are intentionally excluded from releases; they are not part of the reproducible scientific content.

 **Public download surface** (no auth): `GET /api/analysis/releases/<release_id>/manifest.json` returns the exact stored manifest bytes (`sha256(bytes) == manifest_sha256` on the release head); `GET /api/analysis/releases/<release_id>/file?path=<file_path>` returns one content-addressed file by its exact manifest path (e.g. `path=functional_clusters/payload.json`); `GET /api/analysis/releases/<release_id>/bundle` streams the whole frozen `bundle.tar.gz`.
54095 app/src/views/review/Review.spec.ts
43524 app/src/views/pages/__tests__/EntityView.spec.ts
35919 app/src/test-utils/mocks/handlers.ts
33231 app/src/views/admin/ManageAnnotations.spec.ts
32624 app/src/views/curate/ApproveReview.spec.ts
28625 app/src/composables/useAuth.spec.ts
25240 app/src/views/curate/ModifyEntity.spec.ts
25150 app/src/views/help/AboutView.vue
24758 app/src/views/curate/ApproveStatus.spec.ts
24636 app/src/composables/useTableMethods.spec.ts
23933 app/src/test-utils/mocks/handlers.spec.ts
23796 app/src/views/admin/ManageUser.spec.ts
23067 app/src/views/curate/composables/useManageReReview.spec.ts
23058 app/src/composables/useAuth.ts
22780 app/src/views/curate/ApproveUser.vue
22090 app/src/views/admin/ManageOntology.spec.ts
21666 app/src/views/LoginView.spec.ts
21140 app/src/components/ApprovalTableView.vue
20986 app/src/components/tables/TablesEntities.spec.ts
20618 app/src/composables/useEntityForm.spec.ts
20557 app/src/views/review/Review.vue
20147 app/src/views/curate/ModifyEntity.vue
19904 app/src/components/tables/TablesGenes.spec.ts
19829 app/src/components/tables/useLogTable.ts
19512 app/src/views/curate/composables/useApproveReviewController.ts

exec
/bin/bash -lc 'cd app && npx vitest run src/utils/safe-url.spec.ts src/components/analyses/ReleaseManifestPanel.spec.ts src/views/analyses/DataReleases.spec.ts src/api/analysis.spec.ts src/api/admin_analysis_release.spec.ts src/views/admin/useAnalysisReleaseAdmin.spec.ts src/views/admin/ManageAnalysisReleases.spec.ts src/components/analyses/dataReleaseTable.spec.ts && npm run type-check:strict' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 exited 1 in 197ms:
failed to load config from /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/vitest.config.ts

⎯⎯⎯⎯⎯⎯⎯ Startup Error ⎯⎯⎯⎯⎯⎯⎯⎯
Error: EROFS: read-only file system, open '/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/.vite-temp/vitest.config.ts.timestamp-1784450326323-ecbaabd4e056b.mjs'
    at async open (node:internal/fs/promises:640:25)
    at async Object.writeFile (node:internal/fs/promises:1257:14)
    at async loadConfigFromBundledFile (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vite/dist/node/chunks/config.js:35994:3)
    at async bundleAndLoadConfigFile (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vite/dist/node/chunks/config.js:35884:17)
    at async loadConfigFromFile (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vite/dist/node/chunks/config.js:35851:42)
    at async resolveConfig (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vite/dist/node/chunks/config.js:35500:22)
    at async _createServer (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vite/dist/node/chunks/config.js:25441:67)
    at async createViteServer (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vitest/dist/chunks/cli-api.BK8pd4xc.js:8835:17)
    at async createVitest (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vitest/dist/chunks/cli-api.BK8pd4xc.js:14221:18)
    at async prepareVitest (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vitest/dist/chunks/cli-api.BK8pd4xc.js:14588:14) {
  errno: -30,
  code: 'EROFS',
  syscall: 'open',
  path: '/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/.vite-temp/vitest.config.ts.timestamp-1784450326323-ecbaabd4e056b.mjs'
}




exec
/bin/bash -lc 'cd app && npm run type-check:strict' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 exited 1 in 38877ms:
[type-check:strict] router: SPAWN FAILED — spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
Error: spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
    at Object.spawnSync (node:internal/child_process:1143:20)
    at spawnSync (node:child_process:911:24)
    at file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/scripts/type-check-strict.js:156:18
    at ModuleJob.run (node:internal/modules/esm/module_job:437:25)
    at async node:internal/modules/esm/loader:639:26
    at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)
[type-check:strict] api: SPAWN FAILED — spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
Error: spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
    at Object.spawnSync (node:internal/child_process:1143:20)
    at spawnSync (node:child_process:911:24)
    at file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/scripts/type-check-strict.js:156:18
    at ModuleJob.run (node:internal/modules/esm/module_job:437:25)
    at async node:internal/modules/esm/loader:639:26
    at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)
[type-check:strict] types: SPAWN FAILED — spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
Error: spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
    at Object.spawnSync (node:internal/child_process:1143:20)
    at spawnSync (node:child_process:911:24)
    at file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/scripts/type-check-strict.js:156:18
    at ModuleJob.run (node:internal/modules/esm/module_job:437:25)
    at async node:internal/modules/esm/loader:639:26
    at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)
[type-check:strict] composables-auth: SPAWN FAILED — spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
Error: spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
    at Object.spawnSync (node:internal/child_process:1143:20)
    at spawnSync (node:child_process:911:24)
    at file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/scripts/type-check-strict.js:156:18
    at ModuleJob.run (node:internal/modules/esm/module_job:437:25)
    at async node:internal/modules/esm/loader:639:26
    at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)
[type-check:strict] plugins-axios: SPAWN FAILED — spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
Error: spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
    at Object.spawnSync (node:internal/child_process:1143:20)
    at spawnSync (node:child_process:911:24)
    at file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/scripts/type-check-strict.js:156:18
    at ModuleJob.run (node:internal/modules/esm/module_job:437:25)
    at async node:internal/modules/esm/loader:639:26
    at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)
[type-check:strict] views-review: SPAWN FAILED — spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
Error: spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
    at Object.spawnSync (node:internal/child_process:1143:20)
    at spawnSync (node:child_process:911:24)
    at file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/scripts/type-check-strict.js:156:18
    at ModuleJob.run (node:internal/modules/esm/module_job:437:25)
    at async node:internal/modules/esm/loader:639:26
    at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)
[type-check:strict] global: SPAWN FAILED — spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
Error: spawnSync /home/bernt-popp/.nvm/versions/node/v24.15.0/bin/node EPERM
    at Object.spawnSync (node:internal/child_process:1143:20)
    at spawnSync (node:child_process:911:24)
    at file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/scripts/type-check-strict.js:156:18
    at ModuleJob.run (node:internal/modules/esm/module_job:437:25)
    at async node:internal/modules/esm/loader:639:26
    at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)

exec
/bin/bash -lc "rg -n 'prerender|renderToString|SSR|ssr|DataReleases|safeHttpUrl|window\\.location' app scripts .github Makefile package.json app/package.json | head -n 320; rg -n \"function analysis_release_get|analysis_release_list|manifest <-|fromJSON\" api/functions/analysis-snapshot-release-repository.R; nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '240,480p'; nl -ba app/src/api/analysis.ts | sed -n '1,120p'; nl -ba app/src/router/routes.datareleases.spec.ts" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
rg: package.json: No such file or directory (os error 2)
Makefile:199:	@printf "$(CYAN)==> Verifying prerendered SEO output...$(RESET)\n"
app/Dockerfile:36:# Optionally prerender crawlable public route HTML into dist/.
app/src/env.d.ts:14:  readonly SSR: boolean;
app/src/assets/js/constants/main_nav_constants.ts:69:        { text: 'Data releases', path: '/DataReleases' },
app/vitest.setup.ts:35:  axios.defaults.baseURL = window.location.origin;
app/src/composables/useAuth.ts:2:// SPA-only context; localStorage is always available at module load (Vite SPA, no SSR).
app/package-lock.json:6779:        "@vue/compiler-ssr": "3.5.39",
app/package-lock.json:6787:    "node_modules/@vue/compiler-ssr": {
app/package-lock.json:6789:      "resolved": "https://registry.npmjs.org/@vue/compiler-ssr/-/compiler-ssr-3.5.39.tgz",
app/package-lock.json:6898:        "@vue/compiler-ssr": "3.5.39",
app/package-lock.json:19012:      "integrity": "sha512-vIYxrBCC/N/K+Js3qSN88go7kIfNPssr/hHCesKCQNAjmgvYS2oqr69kIufEG+O4+PfezOH4EbIeHCfFov8ZgQ==",
app/src/views/admin/ManageAnalysisReleases.spec.ts:6:// composable + view wiring end-to-end (mirrors DataReleases.spec.ts).
app/src/composables/annotations/useJobHistoryPanel.ts:135:      .writeText(window.location.href)
app/src/views/admin/composables/useOntologyAdminTable.ts:185:    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
app/src/views/admin/composables/useOntologyAdminTable.ts:402:    const urlParams = new URLSearchParams(window.location.search);
app/src/composables/annotations/useJobHistoryUrlState.ts:89:    const url = new URL(window.location.href);
app/src/views/admin/composables/useUserData.ts:279:    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
app/src/views/admin/composables/useManageUserPage.ts:132:    const urlParams = new URLSearchParams(window.location.search);
app/src/views/help/McpInfoView.spec.ts:29:    expect(wrapper.text()).toContain(`${window.location.origin}/mcp`);
app/src/views/help/McpInfoView.vue:233:const resolveMcpUrl = () => `${window.location.origin.replace(/\/$/, '')}/mcp`;
app/src/views/analyses/DataReleases.vue:1:<!-- src/views/analyses/DataReleases.vue -->
app/src/views/analyses/DataReleases.vue:162:  name: 'DataReleases',
app/src/views/analyses/DataReleases.spec.ts:29:import DataReleases from './DataReleases.vue';
app/src/views/analyses/DataReleases.spec.ts:110:describe('DataReleases', () => {
app/src/views/analyses/DataReleases.spec.ts:125:    const wrapper = mount(DataReleases);
app/src/views/analyses/DataReleases.spec.ts:144:    const wrapper = mount(DataReleases);
app/src/views/analyses/DataReleases.spec.ts:175:    const wrapper = mount(DataReleases);
app/src/views/analyses/DataReleases.spec.ts:206:    const wrapper = mount(DataReleases);
app/src/views/analyses/DataReleases.spec.ts:222:    const wrapper = mount(DataReleases);
app/src/views/nddscore/NDDScore.vue:36: *  Guard against undefined route.name in test/SSR contexts where the router may be absent. */
app/src/views/admin/useLlmAdminTabs.ts:39:    activeTab.value = tabFromHash(window.location.hash);
app/src/components/tables/TablesGenes.spec.ts:409:    const expectedReturnTo = `${window.location.pathname}${window.location.search}`;
app/src/components/tables/useEntitiesTable.ts:168:    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
app/src/components/tables/useEntitiesTable.ts:384:      `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`
app/src/components/tables/usePhenotypeEntitiesTable.ts:184:    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
app/src/components/tables/usePhenotypeEntitiesTable.ts:191:      `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`
app/src/views/admin/ManageAnalysisReleases.vue:297: * the public /DataReleases table. A `field.formatter` silently never runs
app/src/components/tables/useLogTable.ts:300:    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
app/src/components/tables/useGenesTable.ts:159:    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
app/src/components/tables/useGenesTable.ts:288:      `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`
app/src/utils/safe-url.ts:14:export function safeHttpUrl(value: unknown): string | null {
app/src/utils/safe-url.ts:17:    const u = new URL(value, window.location.origin);
app/src/utils/safe-url.spec.ts:3:import { safeHttpUrl } from './safe-url';
app/src/utils/safe-url.spec.ts:5:describe('safeHttpUrl', () => {
app/src/utils/safe-url.spec.ts:7:    expect(safeHttpUrl('https://zenodo.org/records/1234')).toBe(
app/src/utils/safe-url.spec.ts:13:    expect(safeHttpUrl('http://example.org/path')).toBe('http://example.org/path');
app/src/utils/safe-url.spec.ts:17:    expect(safeHttpUrl('javascript:alert(document.cookie)')).toBeNull();
app/src/utils/safe-url.spec.ts:21:    expect(safeHttpUrl('data:text/html,<script>alert(1)</script>')).toBeNull();
app/src/utils/safe-url.spec.ts:25:    expect(safeHttpUrl('vbscript:msgbox(1)')).toBeNull();
app/src/utils/safe-url.spec.ts:29:    expect(safeHttpUrl('')).toBeNull();
app/src/utils/safe-url.spec.ts:33:    expect(safeHttpUrl('   ')).toBeNull();
app/src/utils/safe-url.spec.ts:37:    expect(safeHttpUrl(null)).toBeNull();
app/src/utils/safe-url.spec.ts:41:    expect(safeHttpUrl(undefined)).toBeNull();
app/src/utils/safe-url.spec.ts:45:    expect(safeHttpUrl(42)).toBeNull();
app/src/utils/safe-url.spec.ts:46:    expect(safeHttpUrl({ href: 'https://evil.example' })).toBeNull();
app/src/utils/safe-url.spec.ts:51:    // window.location.origin (http: in the jsdom test env) and is allowed —
app/src/utils/safe-url.spec.ts:53:    expect(safeHttpUrl('/some/path')).toBe('/some/path');
app/src/utils/safe-url.spec.ts:57:    expect(safeHttpUrl('http://')).toBeNull();
app/src/utils/returnNavigation.ts:13:  return `${window.location.pathname}${window.location.search}`;
app/src/composables/useTableMethods.spec.ts:75:    originalPathname = window.location.pathname;
app/src/composables/useTableMethods.ts:100:    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
app/src/composables/useTableMethods.ts:138:      `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`
app/src/components/nddscore/NddScoreGeneTable.spec.ts:136:    expect(decodeURIComponent(window.location.search)).toContain(
app/src/components/nddscore/NddScoreGeneTable.spec.ts:151:    expect(decodeURIComponent(window.location.search)).toContain('equals(model_split,unseen)');
app/src/components/analyses/dataReleaseTable.ts:3:// Pure client-side table transform for the public /DataReleases page (#573
app/src/components/analyses/dataReleaseTable.ts:85: * `views/analyses/DataReleases.vue`). No `Version` column: `release_version`
app/src/router/routes.datareleases.spec.ts:22:      analyses?.items.some((i) => i.text === 'Data releases' && i.path === '/DataReleases')
app/src/router/routes.datareleases.spec.ts:26:  it('registers a public /DataReleases route', () => {
app/src/router/routes.datareleases.spec.ts:27:    const dataReleases = routes.find((r) => r.path === '/DataReleases');
app/src/router/routes.datareleases.spec.ts:30:    expect(dataReleases?.name).toBe('DataReleases');
app/src/router/routes.ts:278:    path: '/DataReleases',
app/src/router/routes.ts:279:    name: 'DataReleases',
app/src/router/routes.ts:280:    component: () => import('@/views/analyses/DataReleases.vue'),
app/src/components/nddscore/useNddScoreGeneTable.ts:253:    await navigator.clipboard?.writeText(window.location.href);
app/src/components/nddscore/useNddScoreGeneTable.ts:309:    const nextUrl = query ? `${window.location.pathname}?${query}` : window.location.pathname;
app/src/components/nddscore/useNddScoreGeneTable.ts:323:    const params = new URLSearchParams(window.location.search);
app/src/api/admin_analysis_release.ts:14:// The admin `/DataReleases` management VIEW that consumes this client is a
app/src/components/analyses/ReleaseManifestPanel.vue:193:              never bound to `:href` unguarded — `safeHttpUrl` only allows
app/src/components/analyses/ReleaseManifestPanel.vue:218:import { safeHttpUrl } from '@/utils/safe-url';
app/src/components/analyses/ReleaseManifestPanel.vue:244:const safeRecordUrl = computed<string | null>(() => safeHttpUrl(props.release.zenodo.record_url));
app/src/components/analyses/ReleaseManifestPanel.vue:246:  props.release.zenodo.version_doi ? safeHttpUrl(doiUrl(props.release.zenodo.version_doi)) : null
app/src/components/analyses/ReleaseManifestPanel.vue:249:  props.release.zenodo.concept_doi ? safeHttpUrl(doiUrl(props.release.zenodo.concept_doi)) : null
app/src/components/analyses/usePublicationsTable.ts:150:    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
app/src/components/analyses/ReleaseManifestPanel.spec.ts:126:  // unauthenticated /DataReleases visitor.
app/public/sitemap.xml:18091:		<loc>https://sysndd.dbmr.unibe.ch/Genes/SSR4</loc>
201:#' `analysis_release_list()`, the parsed `manifest` from `analysis_release_get()`)
229:    projected$manifest <- head$manifest
245:#'   as a plain R list via `jsonlite::fromJSON(simplifyVector = FALSE)`), or
267:  head$manifest <- if (is.null(manifest_file)) {
271:      jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE),
288:analysis_release_list <- function(status = "published", limit = 50L, offset = 0L, conn) {
   240	#' Draft rows are hidden unless `include_draft = TRUE` — the visibility
   241	#' filter is applied in SQL (`AND status = 'published'`), not by fetching and
   242	#' discarding in R.
   243	#'
   244	#' @return A named list (head columns + `$manifest`, the parsed manifest.json
   245	#'   as a plain R list via `jsonlite::fromJSON(simplifyVector = FALSE)`), or
   246	#'   `NULL` if no matching (visible) row exists.
   247	#' @export
   248	analysis_release_get <- function(release_id, include_draft = FALSE, conn) {
   249	  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
   250	  sql <- paste0(
   251	    "SELECT ", .analysis_release_head_columns, "
   252	       FROM analysis_snapshot_release
   253	      WHERE release_id = ?", status_clause, "
   254	      LIMIT 1"
   255	  )
   256	  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
   257	  if (nrow(rows) == 0L) {
   258	    return(NULL)
   259	  }
   260
   261	  head <- .analysis_release_row_to_list(rows)
   262
   263	  manifest_file <- analysis_release_get_file(
   264	    release_id, "manifest.json",
   265	    include_draft = include_draft, conn = conn
   266	  )
   267	  head$manifest <- if (is.null(manifest_file)) {
   268	    NULL
   269	  } else {
   270	    tryCatch(
   271	      jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE),
   272	      error = function(e) NULL
   273	    )
   274	  }
   275
   276	  head
   277	}
   278
   279	#' List release heads (newest first), each with a `layers` member summary.
   280	#'
   281	#' `status = NULL` returns releases of every status; otherwise filters to the
   282	#' given status (e.g. `"published"`, `"draft"`) in SQL.
   283	#'
   284	#' @return A list of named lists (head columns + `$layers`, a list of
   285	#'   `list(analysis_type, snapshot_id, payload_hash)` for `role = 'layer'`
   286	#'   members). Empty list if no rows match.
   287	#' @export
   288	analysis_release_list <- function(status = "published", limit = 50L, offset = 0L, conn) {
   289	  where_clause <- ""
   290	  params <- list()
   291	  if (!is.null(status)) {
   292	    where_clause <- " WHERE status = ?"
   293	    params <- list(as.character(status))
   294	  }
   295	  sql <- paste0(
   296	    "SELECT ", .analysis_release_head_columns, "
   297	       FROM analysis_snapshot_release",
   298	    where_clause,
   299	    " ORDER BY created_at DESC LIMIT ? OFFSET ?"
   300	  )
   301	  params <- c(params, list(as.integer(limit), as.integer(offset)))
   302	  rows <- DBI::dbGetQuery(conn, sql, params = unname(params))
   303	  if (nrow(rows) == 0L) {
   304	    return(list())
   305	  }
   306
   307	  release_ids <- as.character(rows$release_id)
   308	  placeholders <- paste(rep("?", length(release_ids)), collapse = ",")
   309	  members <- DBI::dbGetQuery(
   310	    conn,
   311	    paste0(
   312	      "SELECT release_id, analysis_type, snapshot_id, payload_hash
   313	         FROM analysis_snapshot_release_member
   314	        WHERE role = 'layer' AND release_id IN (", placeholders, ")
   315	        ORDER BY release_id, analysis_type"
   316	    ),
   317	    params = unname(as.list(release_ids))
   318	  )
   319
   320	  lapply(seq_len(nrow(rows)), function(i) {
   321	    head <- .analysis_release_row_to_list(rows, i)
   322	    rid <- as.character(head$release_id)
   323	    layer_rows <- members[members$release_id == rid, , drop = FALSE]
   324	    head$layers <- lapply(seq_len(nrow(layer_rows)), function(j) {
   325	      list(
   326	        analysis_type = as.character(layer_rows$analysis_type[[j]]),
   327	        snapshot_id = layer_rows$snapshot_id[[j]],
   328	        payload_hash = as.character(layer_rows$payload_hash[[j]])
   329	      )
   330	    })
   331	    head
   332	  })
   333	}
   334
   335	#' Fetch one archive file's bytes by its exact (release_id, file_path) key.
   336	#'
   337	#' PK lookup only — no path building/concatenation. Draft-release files are
   338	#' hidden unless `include_draft = TRUE` (a SQL join against the head table's
   339	#' `status`, applied before any blob is fetched).
   340	#'
   341	#' @return `list(bytes = <raw, decompressed>, media_type = chr,
   342	#'   content_sha256 = chr)`, or `NULL` if no matching (visible) row exists.
   343	#' @export
   344	analysis_release_get_file <- function(release_id, file_path, include_draft = FALSE, conn) {
   345	  status_clause <- if (isTRUE(include_draft)) "" else " AND r.status = 'published'"
   346	  sql <- paste0(
   347	    "SELECT f.content_gzip, f.media_type, f.content_sha256
   348	       FROM analysis_snapshot_release_file f
   349	       JOIN analysis_snapshot_release r ON r.release_id = f.release_id
   350	      WHERE f.release_id = ? AND f.file_path = ?", status_clause, "
   351	      LIMIT 1"
   352	  )
   353	  rows <- DBI::dbGetQuery(
   354	    conn, sql,
   355	    params = unname(list(as.character(release_id), as.character(file_path)))
   356	  )
   357	  if (nrow(rows) == 0L) {
   358	    return(NULL)
   359	  }
   360
   361	  gz <- .analysis_release_blob(rows$content_gzip[[1]])
   362	  list(
   363	    bytes = memDecompress(gz, type = "gzip"),
   364	    media_type = as.character(rows$media_type[[1]]),
   365	    content_sha256 = as.character(rows$content_sha256[[1]])
   366	  )
   367	}
   368
   369	#' Fetch the whole release archive (`bundle_gzip`) verbatim.
   370	#'
   371	#' `bundle_gzip` is stored already-gzipped and served as-is — this does NOT
   372	#' decompress it (unlike `analysis_release_get_file()`, which stores each
   373	#' file's gzip as a transport-only encoding of JSON content). Draft releases
   374	#' are hidden unless `include_draft = TRUE`, filtered in SQL.
   375	#'
   376	#' @return `list(bytes = <raw, verbatim gzip tar>, sha256 = chr, filename =
   377	#'   "<release_id>.tar.gz")`, or `NULL` if no matching (visible) row exists.
   378	#' @export
   379	analysis_release_get_bundle <- function(release_id, include_draft = FALSE, conn) {
   380	  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
   381	  sql <- paste0(
   382	    "SELECT bundle_gzip, bundle_sha256
   383	       FROM analysis_snapshot_release
   384	      WHERE release_id = ?", status_clause, "
   385	      LIMIT 1"
   386	  )
   387	  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
   388	  if (nrow(rows) == 0L) {
   389	    return(NULL)
   390	  }
   391
   392	  list(
   393	    bytes = .analysis_release_blob(rows$bundle_gzip[[1]]),
   394	    sha256 = as.character(rows$bundle_sha256[[1]]),
   395	    filename = paste0(as.character(release_id), ".tar.gz")
   396	  )
   397	}
   398
   399	#' Check whether a release id exists (any status) — for idempotent creation.
   400	#' @return logical(1).
   401	#' @export
   402	analysis_release_exists <- function(release_id, conn) {
   403	  rows <- DBI::dbGetQuery(
   404	    conn,
   405	    "SELECT 1 AS found FROM analysis_snapshot_release WHERE release_id = ? LIMIT 1",
   406	    params = unname(list(as.character(release_id)))
   407	  )
   408	  nrow(rows) > 0L
   409	}
   410
   411	#' Distinct snapshot ids referenced by any release member (the later prune
   412	#' guard uses this to never delete a snapshot a release still points to).
   413	#' @return integer vector (possibly empty).
   414	#' @export
   415	analysis_release_referenced_snapshot_ids <- function(conn) {
   416	  rows <- DBI::dbGetQuery(
   417	    conn,
   418	    "SELECT DISTINCT snapshot_id FROM analysis_snapshot_release_member"
   419	  )
   420	  as.integer(rows$snapshot_id)
   421	}
   422
   423	# --------------------------------------------------------------------------- #
   424	# Update / delete
   425	# --------------------------------------------------------------------------- #
   426
   427	#' Publish a draft release (no-op if it is not currently a draft).
   428	#' @return logical(1), TRUE iff the row flipped to published.
   429	#' @export
   430	analysis_release_publish <- function(release_id, conn) {
   431	  affected <- DBI::dbExecute(
   432	    conn,
   433	    "UPDATE analysis_snapshot_release
   434	        SET status = 'published', published_at = NOW(6)
   435	      WHERE release_id = ? AND status = 'draft'",
   436	    params = unname(list(as.character(release_id)))
   437	  )
   438	  affected > 0L
   439	}
   440
   441	#' Record external Zenodo/DOI provenance on an existing release.
   442	#'
   443	#' Additive metadata only — updates whichever of `zenodo_record_id`,
   444	#' `zenodo_record_url`, `version_doi`, `concept_doi` are present in
   445	#' `doi_fields`; never touches `content_digest`/`manifest_sha256` (release
   446	#' scientific identity is immutable once minted).
   447	#'
   448	#' @param doi_fields Named list, any subset of `zenodo_record_id`,
   449	#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
   450	#' @return logical(1), TRUE iff a row was updated.
   451	#' @export
   452	analysis_release_set_doi <- function(release_id, doi_fields = list(), conn) {
   453	  allowed <- c("zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi")
   454	  present <- intersect(names(doi_fields), allowed)
   455	  if (length(present) == 0L) {
   456	    return(FALSE)
   457	  }
   458
   459	  set_clause <- paste(paste0(present, " = ?"), collapse = ", ")
   460	  value_params <- lapply(present, function(k) .analysis_release_chr(doi_fields[[k]]))
   461	  affected <- DBI::dbExecute(
   462	    conn,
   463	    paste0("UPDATE analysis_snapshot_release SET ", set_clause, " WHERE release_id = ?"),
   464	    params = unname(c(value_params, list(as.character(release_id))))
   465	  )
   466	  affected > 0L
   467	}
   468
   469	#' Delete a release ONLY while it is still a draft (children cascade via FK).
   470	#'
   471	#' Refuses (returns FALSE, no-op) once a release is published — releases are
   472	#' immutable/retained-indefinitely once published; only an unpublished draft
   473	#' can be discarded (e.g. a failed/aborted build).
   474	#'
   475	#' @return logical(1), TRUE iff a draft row was deleted.
   476	#' @export
   477	analysis_release_delete_draft <- function(release_id, conn) {
   478	  affected <- DBI::dbExecute(
   479	    conn,
   480	    "DELETE FROM analysis_snapshot_release WHERE release_id = ? AND status = 'draft'",
     1	// app/src/api/analysis.ts
     2	//
     3	// Analysis resource helpers (clustering, correlation, network).
     4	//
     5	// Mirrors api/endpoints/analysis_endpoints.R (mounted at /api/analysis).
     6	// Phase E.E2: filled during v11.1 Wave 1a (W3).
     7	//
     8	// Most analysis endpoints are heavy synchronous tibble-shaped responses. The
     9	// async equivalents (`POST /api/jobs/clustering/submit`,
    10	// `POST /api/jobs/phenotype_clustering/submit`) live in `jobs.ts`.
    11
    12	import type { AxiosRequestConfig } from 'axios';
    13	import { apiClient } from './client';
    14
    15	// ---------------------------------------------------------------------------
    16	// Snapshot "being prepared" classification
    17	// ---------------------------------------------------------------------------
    18
    19	/**
    20	 * Problem codes the analysis-snapshot endpoints return (HTTP 503) while a
    21	 * snapshot is being (re)built rather than on a hard failure. The frontend shows
    22	 * a friendly "being prepared" state for these instead of a raw error. (#420)
    23	 */
    24	export const SNAPSHOT_PREPARING_CODES = [
    25	  'snapshot_missing',
    26	  'snapshot_stale',
    27	  'source_version_mismatch',
    28	  'schema_version_mismatch',
    29	] as const;
    30
    31	/**
    32	 * Returns true when an error is an analysis-snapshot "being prepared" 503
    33	 * (snapshot missing/stale/mismatch), false for any other error.
    34	 *
    35	 * The API rejects with a raw AxiosError (the typed `apiClient` only unwraps
    36	 * `response.data` on success), so the status code lives at
    37	 * `err.response.status` and the RFC 9457 problem code at
    38	 * `err.response.data.code` — the same access path `networkDataError()` already
    39	 * uses in `useNetworkData.ts`.
    40	 */
    41	export function isSnapshotPreparingError(err: unknown): boolean {
    42	  const problem = (err as { response?: { status?: number; data?: { code?: string | string[] } } })
    43	    ?.response;
    44	  if (!problem || problem.status !== 503) return false;
    45	  // R/Plumber serialises a bare scalar as a 1-element array, so the problem
    46	  // `code` arrives as either "snapshot_missing" or ["snapshot_missing"] over
    47	  // the wire (see `unwrapScalar` in @/api/client). Accept both shapes so the
    48	  // "being prepared" state actually triggers against the real API (#440).
    49	  const raw = problem.data?.code;
    50	  const code = Array.isArray(raw) ? raw[0] : raw;
    51	  return typeof code === 'string' && (SNAPSHOT_PREPARING_CODES as readonly string[]).includes(code);
    52	}
    53
    54	// ---------------------------------------------------------------------------
    55	// Types
    56	// ---------------------------------------------------------------------------
    57
    58	export type ClusteringAlgorithm = 'leiden';
    59
    60	export interface FunctionalClusteringParams {
    61	  page_after?: string;
    62	  page_size?: string;
    63	  algorithm?: ClusteringAlgorithm;
    64	}
    65
    66	export interface ClusterCategory {
    67	  value: string;
    68	  text: string;
    69	  link?: string;
    70	}
    71
    72	/**
    73	 * One cluster row from `gen_string_clust_obj_mem()`. The full shape includes
    74	 * nested tibbles (`identifiers`, `term_enrichment`) that round-trip via JSON
    75	 * as nested arrays/objects — we surface them as `unknown` so consumers can
    76	 * narrow as needed.
    77	 */
    78	export interface FunctionalCluster {
    79	  cluster: string | number;
    80	  hash_filter: string;
    81	  identifiers?: unknown;
    82	  term_enrichment?: unknown;
    83	  // Per-cluster stability joined in by the snapshot builder (scalar-or-array).
    84	  cluster_size?: number | number[];
    85	  jaccard_mean?: number | number[];
    86	  jaccard_n_resamples?: number | number[];
    87	  [key: string]: unknown;
    88	}
    89
    90	export interface PaginationMeta {
    91	  page_size: number;
    92	  page_after: string;
    93	  next_cursor: string | null;
    94	  total_count: number;
    95	  has_more: boolean;
    96	}
    97
    98	/**
    99	 * Partition-level cluster-validation metrics persisted on the snapshot manifest
   100	 * (#457–459). The functional (Leiden) and phenotype (MCA/HCPC) presets populate
   101	 * different subsets; all fields are optional. Values arrive as Plumber
   102	 * scalar-arrays, so read them through the unwrap helpers in
   103	 * `components/analyses/clusterValidation.ts`.
   104	 */
   105	export interface ClusterValidation {
   106	  validation_schema_version?: string | string[];
   107	  algorithm?: string | string[];
   108	  // functional (leiden)
   109	  weighted?: boolean | boolean[];
   110	  modularity?: number | number[];
   111	  modularity_scope?: string | string[];
   112	  resolution_parameter?: number | number[];
   113	  n_iterations?: number | number[];
   114	  n_clusters?: number | number[];
   115	  n_dropped_below_min_size?: number | number[];
   116	  // phenotype (mca_hcpc)
   117	  k?: number | number[];
   118	  k_selection_metric?: string | string[];
   119	  mean_silhouette?: number | number[];
   120	  silhouette_status?: string | string[];
     1	import { describe, expect, it, vi } from 'vitest';
     2
     3	vi.mock('@/composables/useAuth', () => ({
     4	  useAuth: () => ({
     5	    isAuthenticated: { value: true },
     6	    isExpired: { value: false },
     7	    hasRole: (role: string) => role === 'Administrator',
     8	  }),
     9	}));
    10
    11	import { routes } from './routes';
    12	import {
    13	  DROPDOWN_ITEMS_LEFT,
    14	  DROPDOWN_ITEMS_RIGHT,
    15	} from '@/assets/js/constants/main_nav_constants';
    16
    17	describe('Data releases navigation + routes', () => {
    18	  it('adds a Data releases item to the public Analyses dropdown', () => {
    19	    const analyses = DROPDOWN_ITEMS_LEFT.find((d) => d.id === 'analyses_dropdown');
    20
    21	    expect(
    22	      analyses?.items.some((i) => i.text === 'Data releases' && i.path === '/DataReleases')
    23	    ).toBe(true);
    24	  });
    25
    26	  it('registers a public /DataReleases route', () => {
    27	    const dataReleases = routes.find((r) => r.path === '/DataReleases');
    28
    29	    expect(dataReleases).toBeDefined();
    30	    expect(dataReleases?.name).toBe('DataReleases');
    31	    expect(dataReleases?.beforeEnter).toBeUndefined();
    32	    expect(dataReleases?.component).toBeDefined();
    33	    expect(dataReleases?.meta?.sitemap).toEqual({ priority: 0.7, changefreq: 'monthly' });
    34	  });
    35
    36	  it('registers an Administrator-guarded /ManageAnalysisReleases route', () => {
    37	    const manage = routes.find((r) => r.path === '/ManageAnalysisReleases');
    38	    expect(manage).toBeDefined();
    39	    expect(typeof manage?.beforeEnter).toBe('function');
    40	  });
    41
    42	  it('adds a Manage releases item to the Administration dropdown', () => {
    43	    const administration = DROPDOWN_ITEMS_RIGHT.find((d) => d.id === 'administration_dropdown');
    44
    45	    expect(
    46	      administration?.items.some(
    47	        (i) => i.text === 'Manage releases' && i.path === '/ManageAnalysisReleases'
    48	      )
    49	    ).toBe(true);
    50	  });
    51	});

exec
/bin/bash -lc "nl -ba app/Dockerfile | sed -n '1,100p'; rg -n -C 4 'prerender' app/scripts app/package.json Makefile .github 2>/dev/null; find app -maxdepth 3 -type f \\( -iname '*prerender*' -o -iname '*seo*' \\) -print" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
     1	# Build arguments
     2	ARG NODE_VERSION=24
     3	ARG NGINX_VERSION=1.27.4
     4	ARG VUE_MODE=production
     5	ARG SEO_GENERATE=false
     6	ARG SEO_API_BASE_URL=
     7	ARG SEO_PUBLIC_BASE_URL=https://sysndd.dbmr.unibe.ch
     8
     9	# Stage 1: Build Vue.js application with Vite
    10	FROM node:${NODE_VERSION}-alpine AS builder
    11
    12	# Build mode: docker (default), production, development
    13	ARG VUE_MODE
    14	ARG SEO_GENERATE
    15	ARG SEO_API_BASE_URL
    16	ARG SEO_PUBLIC_BASE_URL
    17
    18	# Set working directory
    19	WORKDIR /app
    20
    21	# Copy dependency manifests (cache optimization layer)
    22	COPY package*.json ./
    23
    24	# Install dependencies with BuildKit cache mount
    25	# --legacy-peer-deps required by existing package.json
    26	RUN --mount=type=cache,target=/root/.npm \
    27	    npm ci --no-audit --no-fund --legacy-peer-deps
    28
    29	# Copy application source
    30	COPY . .
    31
    32	# Build production bundle with Vite
    33	# Uses build:docker for docker mode, build:production for production mode
    34	RUN npm run build:${VUE_MODE}
    35
    36	# Optionally prerender crawlable public route HTML into dist/.
    37	RUN if [ "${SEO_GENERATE}" = "true" ]; then \
    38	      if [ -n "${SEO_API_BASE_URL}" ]; then \
    39	        SEO_API_BASE_URL="${SEO_API_BASE_URL}" SEO_PUBLIC_BASE_URL="${SEO_PUBLIC_BASE_URL}" npm run seo:generate; \
    40	      else \
    41	        node scripts/generate-seo-pages.mjs --fixture scripts/fixtures/seo --out dist --base-url "${SEO_PUBLIC_BASE_URL}"; \
    42	      fi; \
    43	    fi
    44
    45	# Stage 2: Production nginx server (using pre-built brotli image)
    46	# fholzer/nginx-brotli has brotli pre-compiled - no 5 min compilation!
    47	# Source: https://hub.docker.com/r/fholzer/nginx-brotli
    48	# Pin to specific version for reproducible builds and supply chain security
    49	FROM fholzer/nginx-brotli:v1.31.2 AS production
    50
    51	# Configure for non-root operation (similar to nginx-unprivileged)
    52	# Create nginx user if not exists and set permissions
    53	RUN sed -i 's/listen\s*80;/listen 8080;/g' /etc/nginx/conf.d/default.conf 2>/dev/null || true \
    54	    && sed -i 's/pid\s*\/var\/run\/nginx.pid;/pid \/tmp\/nginx.pid;/g' /etc/nginx/nginx.conf \
    55	    && mkdir -p /var/cache/nginx /var/log/nginx /tmp \
    56	    && chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx/conf.d /usr/share/nginx/html
    57
    58	# Copy nginx configuration (overwrites defaults)
    59	COPY --chown=nginx:nginx ./docker/nginx/local.conf /etc/nginx/conf.d/default.conf
    60	COPY --chown=nginx:nginx ./docker/nginx/nginx.conf /etc/nginx/nginx.conf
    61	COPY --chown=nginx:nginx ./docker/nginx/security-headers.conf /etc/nginx/security-headers.conf
    62
    63	# Set working directory to nginx asset directory
    64	WORKDIR /usr/share/nginx/html
    65
    66	# Remove default nginx static assets
    67	RUN rm -rf ./*
    68
    69	# Copy static assets from builder stage
    70	COPY --chown=nginx:nginx --from=builder /app/dist .
    71
    72	# #535 belt-and-suspenders: never ship source maps, analyzer reports, or
    73	# build-only bundle-attribution metadata, even if a build config regresses.
    74	# Runs as root before `USER nginx`.
    75	RUN find . -name '*.map' -delete && rm -rf .vite && rm -f stats.html
    76
    77	# Health check using wget (included in Alpine)
    78	HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    79	    CMD wget --spider --tries=1 --no-verbose http://localhost:8080/ || exit 1
    80
    81	# Expose non-privileged port
    82	EXPOSE 8080
    83
    84	# Switch to non-root user
    85	USER nginx
    86
    87	# Run nginx
    88	ENTRYPOINT ["nginx", "-g", "daemon off;"]
Makefile-195-	@printf "$(CYAN)==> Building frontend for SEO verification...$(RESET)\n"
Makefile-196-	@cd $(ROOT_DIR)/app && npm run build:production -- --emptyOutDir=false
Makefile-197-	@printf "$(CYAN)==> Generating fixture SEO pages...$(RESET)\n"
Makefile-198-	@cd $(ROOT_DIR)/app && npm run seo:generate:fixture
Makefile:199:	@printf "$(CYAN)==> Verifying prerendered SEO output...$(RESET)\n"
Makefile-200-	@cd $(ROOT_DIR)/app && npm run seo:verify && \
Makefile-201-		printf "$(GREEN)✓ verify-seo-app complete$(RESET)\n" || \
Makefile-202-		(printf "$(RED)✗ verify-seo-app failed$(RESET)\n" && exit 1)
Makefile-203-
app/src/seo/seoTypes.ts
app/src/seo/seoMeta.ts
app/src/eslint-closeout-guard.spec.ts
app/node_modules/lodash-es/_baseOrderBy.js
app/node_modules/lodash/_baseOrderBy.js
app/scripts/verify-seo-build.mjs
app/scripts/generate-seo-pages.mjs

exec
/bin/bash -lc "rg -n 'scope_statement' app/src/{api,components,views} | head -n 120; nl -ba app/scripts/generate-seo-pages.mjs | sed -n '1,100p'; nl -ba app/scripts/verify-seo-build.mjs | sed -n '1,100p'; git diff --check origin/master...HEAD; git status --short" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
app/src/api/analysis_releases.ts:177:  scope_statement: string | null;
app/src/api/analysis.spec.ts:376:        scope_statement: 'Public derived analysis only.',
app/src/api/analysis.spec.ts:427:        scope_statement: 'Public derived analysis only.',
app/src/api/admin_analysis_release.ts:99:  scope_statement?: string;
app/src/api/admin_analysis_release.spec.ts:122:    it('sends the genuine nested JSON body (layers/title/scope_statement/license/publish)', async () => {
app/src/api/admin_analysis_release.spec.ts:135:        scope_statement: 'scope',
app/src/api/admin_analysis_release.spec.ts:143:        scope_statement: 'scope',
app/src/views/admin/ManageAnalysisReleases.vue:106:              v-model="buildForm.scope_statement"
app/src/views/admin/ManageAnalysisReleases.vue:329:  scope_statement: '',
app/src/views/analyses/DataReleases.spec.ts:62:      scope_statement: 'Public derived analysis only.',
app/src/components/analyses/ReleaseManifestPanel.spec.ts:34:      scope_statement: 'Public derived analysis only.',
     1	#!/usr/bin/env node
     2
     3	import { mkdir, readFile, writeFile } from 'node:fs/promises';
     4	import path from 'node:path';
     5	import process from 'node:process';
     6	import { setTimeout as delay } from 'node:timers/promises';
     7
     8	const DESCRIPTION_MAX_LENGTH = 160;
     9	const REQUIRED_PATTERNS = [
    10	  /<title>[\s\S]*?<\/title>/i,
    11	  /<meta\s+name=["']description["'][^>]*>/i,
    12	  /<link\s+rel=["']canonical["'][^>]*>/i,
    13	  /<meta\s+property=["']og:title["'][^>]*>/i,
    14	  /<meta\s+property=["']og:description["'][^>]*>/i,
    15	  /<meta\s+property=["']og:url["'][^>]*>/i,
    16	  /<meta\s+name=["']twitter:title["'][^>]*>/i,
    17	  /<meta\s+name=["']twitter:description["'][^>]*>/i,
    18	  /<script\s+type=["']application\/ld\+json["'][^>]*>[\s\S]*?<\/script>/i,
    19	  /<div\s+id=["']app["']><\/div>/i,
    20	];
    21
    22	main().catch((error) => {
    23	  console.error(error.message);
    24	  process.exitCode = 1;
    25	});
    26
    27	async function main() {
    28	  const args = parseArgs(process.argv.slice(2));
    29	  const outDir = args.out ?? 'dist';
    30	  const baseUrl =
    31	    args['base-url'] ?? process.env.SEO_PUBLIC_BASE_URL ?? 'https://sysndd.dbmr.unibe.ch';
    32	  const source = args.fixture
    33	    ? await readFixtureSource(args.fixture)
    34	    : await readApiSource(
    35	        args['api-base'] ?? process.env.SEO_API_BASE_URL ?? 'http://localhost/api'
    36	      );
    37
    38	  const template = await readFile(path.join(outDir, 'index.html'), 'utf8');
    39	  assertTemplateReady(template);
    40
    41	  const geneRoutes = [];
    42	  for (const route of source.routes.genes ?? []) {
    43	    const payload = await source.gene(route.symbol);
    44	    const seo = buildGeneSeo(payload, baseUrl);
    45	    await writeRoute(outDir, `/Genes/${payload.symbol}`, renderHtml(template, seo));
    46	    geneRoutes.push({
    47	      path: `/Genes/${payload.symbol}`,
    48	      lastModified: payload.lastModified ?? route.lastModified,
    49	    });
    50	  }
    51
    52	  const entityRoutes = [];
    53	  for (const route of source.routes.entities ?? []) {
    54	    const payload = await source.entity(route.entityId);
    55	    const seo = buildEntitySeo(payload, baseUrl);
    56	    await writeRoute(outDir, `/Entities/${payload.entityId}`, renderHtml(template, seo));
    57	    entityRoutes.push({
    58	      path: `/Entities/${payload.entityId}`,
    59	      lastModified: payload.lastModified ?? route.lastModified,
    60	    });
    61	  }
    62
    63	  const staticRoutes = source.routes.static ?? [];
    64	  await writeFile(
    65	    path.join(outDir, 'sitemap.xml'),
    66	    buildSitemapIndex(baseUrl, [
    67	      { path: '/sitemap-static.xml', lastModified: newestLastModified(staticRoutes) },
    68	      { path: '/sitemap-genes.xml', lastModified: newestLastModified(geneRoutes) },
    69	      { path: '/sitemap-entities.xml', lastModified: newestLastModified(entityRoutes) },
    70	    ])
    71	  );
    72	  await writeFile(path.join(outDir, 'sitemap-static.xml'), buildUrlSet(baseUrl, staticRoutes));
    73	  await writeFile(path.join(outDir, 'sitemap-genes.xml'), buildUrlSet(baseUrl, geneRoutes));
    74	  await writeFile(path.join(outDir, 'sitemap-entities.xml'), buildUrlSet(baseUrl, entityRoutes));
    75	}
    76
    77	function parseArgs(argv) {
    78	  const parsed = {};
    79	  for (let index = 0; index < argv.length; index += 1) {
    80	    const arg = argv[index];
    81	    if (!arg.startsWith('--')) continue;
    82	    const key = arg.slice(2);
    83	    const next = argv[index + 1];
    84	    parsed[key] = next && !next.startsWith('--') ? next : 'true';
    85	    if (parsed[key] === next) index += 1;
    86	  }
    87	  return parsed;
    88	}
    89
    90	async function readFixtureSource(fixtureDir) {
    91	  const routes = JSON.parse(await readFile(path.join(fixtureDir, 'routes.json'), 'utf8'));
    92	  return {
    93	    routes,
    94	    gene: (symbol) => readJson(path.join(fixtureDir, 'genes', `${symbol}.json`)),
    95	    entity: (entityId) => readJson(path.join(fixtureDir, 'entities', `${entityId}.json`)),
    96	  };
    97	}
    98
    99	async function readApiSource(apiBase) {
   100	  const base = apiBase.replace(/\/$/, '');
     1	#!/usr/bin/env node
     2
     3	import { readFile } from 'node:fs/promises';
     4	import path from 'node:path';
     5	import process from 'node:process';
     6
     7	const REQUIRED_PAGES = [
     8	  {
     9	    file: path.join('Genes', 'CHD8', 'index.html'),
    10	    text: 'CHD8',
    11	  },
    12	  {
    13	    file: path.join('Entities', '123', 'index.html'),
    14	    text: 'autism',
    15	  },
    16	];
    17
    18	main().catch((error) => {
    19	  console.error(error.message);
    20	  process.exitCode = 1;
    21	});
    22
    23	async function main() {
    24	  const dist = process.argv[2] ?? 'dist';
    25	  const failures = [];
    26
    27	  for (const page of REQUIRED_PAGES) {
    28	    const html = await readFile(path.join(dist, page.file), 'utf8');
    29	    failures.push(...verifyHtmlPage(page.file, html, page.text));
    30	  }
    31
    32	  const sitemap = await readFile(path.join(dist, 'sitemap.xml'), 'utf8');
    33	  failures.push(...verifySitemap(sitemap));
    34
    35	  if (failures.length > 0) {
    36	    throw new Error(
    37	      `SEO verification failed:\n${failures.map((failure) => `- ${failure}`).join('\n')}`
    38	    );
    39	  }
    40
    41	  console.log(`SEO verification passed for ${dist}`);
    42	}
    43
    44	function verifyHtmlPage(file, html, routeText) {
    45	  const checks = [
    46	    [/<title>(?!SysNDD<\/title>)[^<]+<\/title>/i, `${file}: non-generic title`],
    47	    [
    48	      /<meta\s+name=["']description["']\s+content=["'][^"']{40,}["'][^>]*>/i,
    49	      `${file}: meta description`,
    50	    ],
    51	    [
    52	      /<link\s+rel=["']canonical["']\s+href=["']https:\/\/sysndd\.dbmr\.unibe\.ch\/[^"']+["'][^>]*>/i,
    53	      `${file}: canonical link`,
    54	    ],
    55	    [/<h1>[^<]+<\/h1>/i, `${file}: H1`],
    56	    [/<script\s+type=["']application\/ld\+json["'][^>]*>[\s\S]+?<\/script>/i, `${file}: JSON-LD`],
    57	    [new RegExp(escapeRegExp(routeText)), `${file}: visible route-specific text`],
    58	  ];
    59
    60	  return checks.filter(([pattern]) => !pattern.test(html)).map(([, label]) => label);
    61	}
    62
    63	function verifySitemap(sitemap) {
    64	  const failures = [];
    65	  if (!sitemap.includes('sitemap-genes.xml')) failures.push('sitemap.xml: gene sitemap link');
    66	  if (!sitemap.includes('sitemap-entities.xml')) failures.push('sitemap.xml: entity sitemap link');
    67	  if (/\/(?:Login|Register)(?:<|\/|\?)/.test(sitemap))
    68	    failures.push('sitemap.xml: auth routes excluded');
    69	  return failures;
    70	}
    71
    72	function escapeRegExp(value) {
    73	  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    74	}
?? .planning/reviews/2026-07-19-573-slice-b-diff-codex-prompt-round2.md
?? .planning/reviews/2026-07-19-573-slice-b-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-573-slice-b-diff-codex-review-round2.md
?? .planning/reviews/2026-07-19-573-slice-b-diff-codex-review.md
?? .planning/reviews/2026-07-19-573-slice-b-reconciliation.md

codex
Round-1 findings verified resolved:

- HIGH: `ReleaseManifestPanel.vue:197` only renders `record_url` through `safeHttpUrl`; `javascript:`/`data:` render as plain text. Regression tests cover both at `ReleaseManifestPanel.spec.ts:127` and `:144`.
- MEDIUM: `ReleaseManifest` now models nested `generator` and `source` objects at `analysis_releases.ts:136-183`, matching the backend manifest builder; `scope_statement` is nullable.
- MEDIUM: `DataReleases.vue:214-231` uses a monotonic request token; the stale-latest regression test is at `DataReleases.spec.ts:161`.
- LOW: release-client error mocks now use RFC 9457 `detail`.
- LOW: rejected DOI save and draft deletion are covered at `ManageAnalysisReleases.spec.ts:310` and `:348`.

BLOCKER: None.

HIGH: None.

MEDIUM: None.

LOW: None.

I also found no new public-data exposure, href-scheme bypass, backend-contract mismatch, request race, accessibility, or file-size issue. `git diff --check` passed. Targeted Vitest/type-check execution was blocked by the read-only sandbox preventing Vite temp-file creation and child-process spawning.

VERDICT: SHIP
tokens used
152,419
Round-1 findings verified resolved:

- HIGH: `ReleaseManifestPanel.vue:197` only renders `record_url` through `safeHttpUrl`; `javascript:`/`data:` render as plain text. Regression tests cover both at `ReleaseManifestPanel.spec.ts:127` and `:144`.
- MEDIUM: `ReleaseManifest` now models nested `generator` and `source` objects at `analysis_releases.ts:136-183`, matching the backend manifest builder; `scope_statement` is nullable.
- MEDIUM: `DataReleases.vue:214-231` uses a monotonic request token; the stale-latest regression test is at `DataReleases.spec.ts:161`.
- LOW: release-client error mocks now use RFC 9457 `detail`.
- LOW: rejected DOI save and draft deletion are covered at `ManageAnalysisReleases.spec.ts:310` and `:348`.

BLOCKER: None.

HIGH: None.

MEDIUM: None.

LOW: None.

I also found no new public-data exposure, href-scheme bypass, backend-contract mismatch, request race, accessibility, or file-size issue. `git diff --check` passed. Targeted Vitest/type-check execution was blocked by the read-only sandbox preventing Vite temp-file creation and child-process spawning.

VERDICT: SHIP
