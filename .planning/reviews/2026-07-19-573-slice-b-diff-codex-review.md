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
session id: 019f7976-0d5c-7ca3-897b-bc7a771a066d
--------
user
# Adversarial diff review — #573 Slice B (analysis-snapshot release UI)

You are a staff-level adversarial reviewer. Review the frontend changes on this branch that add the
public + Administrator UI for immutable analysis-snapshot releases. Be skeptical and thorough — hunt
for real correctness bugs, contract mismatches against the R/Plumber backend, security issues, and
weak tests. Expand scope to adjacent same-class issues you find.

## The diff to review
Run and review exactly:
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
(24 files, all under `app/src/`, plus `documentation/09-deployment.qmd`, `AGENTS.md`, `CHANGELOG.md`,
and version files.) This is a Vue 3 + TypeScript SPA (`app/`) talking to an R/Plumber REST API
(`api/`). You may read any file in the repo for context — the backend routes live in
`api/endpoints/analysis_endpoints.R` and `api/endpoints/admin_analysis_snapshot_endpoints.R`, the
services in `api/services/analysis-snapshot-release-service.R`, and the repository/manifest helpers
in `api/functions/analysis-snapshot-release*.R`. Repo conventions are in `AGENTS.md`.

## What this change does
- `app/src/api/analysis_releases.ts` — PUBLIC typed client (re-exported from `analysis.ts`):
  `listReleases`, `getLatestRelease`, `getRelease`, `downloadReleaseBundle`,
  `downloadReleaseManifest`, `downloadReleaseFile`.
- `app/src/api/admin_analysis_release.ts` — ADMIN typed client: `buildRelease`, `listAdminReleases`,
  `getAdminRelease`, `publishRelease`, `recordReleaseDoi`, `deleteDraftRelease`,
  `fetchSnapshotStatus`, `RELEASE_LAYER_TYPES`.
- `app/src/views/analyses/DataReleases.vue` (+ `ReleaseManifestPanel.vue`, `dataReleaseTable.ts`) —
  public page: releases table + manifest provenance card + downloads + "how to verify" disclosure.
- `app/src/views/admin/ManageAnalysisReleases.vue` (+ `useAnalysisReleaseAdmin.ts`) — admin page:
  build / publish / record-DOI / delete-draft.
- routing + nav registration + a decorative `meta.sitemap`.

## LOCKED decisions (do NOT flag these as defects; DO flag any code that violates them)
1. **Public head is a fixed 14-field allowlist** + `zenodo{record_url,version_doi,concept_doi}` +
   conditional `layers`/`manifest`. It NEVER includes `created_by_user_id` or `last_error_message`.
   The public `ReleaseHead` type must not carry those; the ADMIN `AdminReleaseHead` intentionally does
   (flat DOI columns, not nested `zenodo`). The two types are deliberately different.
2. **`release_version` is a reserved `VARCHAR(32) DEFAULT NULL`** the builder always inserts as `NULL`
   (`api/functions/analysis-snapshot-release.R:409,467`); `title` is nullable too. Both are typed
   `string | null`; the UI must not render an always-empty Version column and must fall back to
   `release_id` when `title` is null.
3. **`reproducibility.json` hashes EXACTLY to `reproducibility_hash`**; each file has its own
   `content_sha256`; `payload_hash`/`input_hash`/`snapshot_id` are LINEAGE ANCHORS cross-checkable
   against the live `/api/analysis/*` `meta.snapshot`, NOT a hash of the release's own `payload.json`.
   The "How to verify" copy must state this correctly and must NOT claim `sha256(payload.json) ==
   payload_hash`.
4. **`GET .../releases/<id>/file?path=<file_path>` uses a query param**, not a URL path segment.
5. **`manifest` + `files[]` appear ONLY on the detail/`latest` routes**; the LIST route carries a
   light per-head `layers` (`{analysis_type, snapshot_id, payload_hash}`). The manifest panel must
   fetch the DETAIL route.
6. **Admin build**: 201 = created, 200 = idempotent duplicate, 503 `release_lock_unavailable`
   (Retry-After) = sources mid-refresh (surface DISTINCTLY), 400 = one of 5 gate classes
   (`release_snapshot_not_available`, `release_source_incoherent`, `release_reproducibility_missing`,
   `release_source_version_mismatch`, `release_dependency_lineage_mismatch`). The build is synchronous
   and DB-only (no async job).
7. **Build must be disabled unless all three release layers are `available`**: exactly
   `functional_clusters`, `phenotype_clusters`, `phenotype_functional_correlations` (the status
   endpoint also returns `phenotype_correlations` + `gene_network_edges` — those must be IGNORED for
   the gate).
8. **"Publish immediately" defaults to UNCHECKED** (build a draft; publish is a deliberate second step).
9. Repo footguns (flag violations): typed clients only (no raw axios in views/components, no
   `localStorage.token`/`localStorage.user`); BootstrapVueNext `BTable` cannot render a dotted field
   key (flatten `zenodo.*` → `zenodo_*`); `v-b-tooltip` is reactive to the binding VALUE not `:title`;
   Plumber JSON scalars may come back array-wrapped on default-serialized endpoints (the release
   admin routes use `unboxedJSON`, so scalars are plain there); problem+json errors are read via
   `extractApiErrorMessage`.

## Focus your adversarial energy on
- **Contract fidelity**: does each client call the exact route/verb/param the R endpoint expects?
  Does `recordReleaseDoi` send ONLY the supplied DOI fields (an empty/omitted field must be left
  unchanged server-side, never nulled)? Does `buildRelease`'s `validateStatus` correctly let
  200/201/503 resolve while 400/404 throw?
- **Rendering correctness & XSS**: release data (title, hashes, DOI values, file paths, `record_url`)
  is server-controlled but admin-authored — are DOI/`record_url` links safe (no `javascript:` scheme
  injection into `href`), and is any `v-html`/dynamic-attribute usage safe? Is the dotted-key BTable
  trap actually avoided in BOTH tables (public + admin)?
- **Resource leaks**: every blob download must create AND revoke its object URL and clean up the
  transient anchor.
- **State/edge cases**: empty state (no published release → `getLatestRelease` 404), a release with a
  `null` title or `null` reproducibility_hash (correlation layer), the `canBuild` gate when a release
  layer is `stale`/`missing`/absent, concurrent build clicks (double-submit), and the 503-vs-400
  branch not being conflated.
- **Test quality**: are the vitest specs asserting real behavior, or shallow truthiness? Is the
  failure path (a rejected publish/DOI/delete) covered and shown near the control? Do MSW mocks model
  the real wire shapes (problem+json uses `detail`, not `message`)?
- **Accessibility**: copy buttons, download buttons, and form inputs have accessible labels; no
  blocking `window.confirm`.
- **File size**: any handwritten source file > 600 lines (soft ceiling).

## Output
List findings grouped by severity: **BLOCKER**, **HIGH**, **MEDIUM**, **LOW**. For each: the file:line,
the concrete failure scenario (inputs → wrong behavior), and a fix direction. Then end with an explicit
verdict line: `VERDICT: SHIP` or `VERDICT: NO-SHIP` (with the blocking items). If you find nothing
ship-blocking, say so plainly — do not manufacture issues.
codex
I’m reviewing the specified branch diff against the live frontend and Plumber contracts, with extra scrutiny on security, error handling, and tests. I’ll keep the review read-only and report only evidence-backed findings.
exec
/bin/bash -lc "pwd && sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && sed -n '1,260p' /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-security-bug-scan/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-frontend-integration/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
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

codex
I’m using the SysNDD frontend-integration and security review guides because this touches typed API boundaries, BootstrapVueNext tables, and a public data surface. The diff-analysis guide also applies; the workspace is read-only, so I’ll inspect its graph if present but won’t create its optional overlay file.
exec
/bin/bash -lc "sed -n '1,260p' .agents/skills/sysndd-code-quality/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-visual-design/SKILL.md && git diff --name-only origin/master...HEAD -- ':(exclude).planning/**' && git diff --stat origin/master...HEAD -- ':(exclude).planning/**' && test -f .understand-anything/knowledge-graph.json && rg -n -m 6 '\"project\"|app/src/(api/(analysis_releases|admin_analysis_release)|views/(analyses/DataReleases|admin/ManageAnalysisReleases))' .understand-anything/knowledge-graph.json || true" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
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
name: sysndd-visual-design
description: Use when changing SysNDD UI, UX, visual design, page layouts, tables, mobile rows, design tokens, authenticated admin/curation surfaces, or public data views
---

# SysNDD Visual Design

Use this skill before editing any SysNDD frontend surface that changes how the app looks or feels.

## Required Reference

Read `documentation/10-visual-design-guide.md` before making UI edits. Treat it as the source of truth for visual positioning, tokens, layout patterns, component rules, and route-specific debt.

## Operating Rules

- Keep SysNDD compact, clinical, table-first, and quiet.
- Prefer existing `AuthenticatedPageShell`, `TableShell`, mobile-row, chip, token, and form patterns.
- Do not introduce marketing-style hero layouts, decorative gradients, nested card stacks, or new one-off palettes.
- Use purpose-built mobile record rows for complex tables instead of stacked Bootstrap table output.
- Keep cards at 8px radius or less unless an existing component contract requires otherwise.
- Use existing design tokens for color, spacing, typography, and radius.
- Preserve footer-safe scrolling and avoid horizontal overflow.

## Verification

For authenticated admin/curation visual changes, run:

```bash
cd app && PLAYWRIGHT_BASE_URL=http://localhost:5173 npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts --project=chromium-desktop
```

Before handoff, choose the repo verification lane appropriate to the change from `AGENTS.md`.
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
app/src/views/admin/ManageAnalysisReleases.spec.ts
app/src/views/admin/ManageAnalysisReleases.vue
app/src/views/admin/useAnalysisReleaseAdmin.spec.ts
app/src/views/admin/useAnalysisReleaseAdmin.ts
app/src/views/analyses/DataReleases.spec.ts
app/src/views/analyses/DataReleases.vue
documentation/09-deployment.qmd
 AGENTS.md                                          |   1 +
 CHANGELOG.md                                       |  50 +++
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 app/src/api/admin_analysis_release.spec.ts         | 261 +++++++++++
 app/src/api/admin_analysis_release.ts              | 332 ++++++++++++++
 app/src/api/analysis.spec.ts                       | 269 ++++++++++++
 app/src/api/analysis.ts                            |  11 +
 app/src/api/analysis_releases.ts                   | 285 ++++++++++++
 app/src/assets/js/constants/main_nav_constants.ts  |   6 +
 .../analyses/ReleaseManifestPanel.spec.ts          | 159 +++++++
 .../components/analyses/ReleaseManifestPanel.vue   | 409 ++++++++++++++++++
 .../components/analyses/dataReleaseTable.spec.ts   | 150 +++++++
 app/src/components/analyses/dataReleaseTable.ts    | 124 ++++++
 app/src/router/routes.datareleases.spec.ts         |  51 +++
 app/src/router/routes.ts                           |  12 +
 app/src/views/admin/ManageAnalysisReleases.spec.ts | 334 ++++++++++++++
 app/src/views/admin/ManageAnalysisReleases.vue     | 479 +++++++++++++++++++++
 .../views/admin/useAnalysisReleaseAdmin.spec.ts    | 349 +++++++++++++++
 app/src/views/admin/useAnalysisReleaseAdmin.ts     | 220 ++++++++++
 app/src/views/analyses/DataReleases.spec.ts        | 167 +++++++
 app/src/views/analyses/DataReleases.vue            | 361 ++++++++++++++++
 documentation/09-deployment.qmd                    |   2 +
 24 files changed, 4036 insertions(+), 4 deletions(-)

exec
/bin/bash -lc "sed -n '1,260p' documentation/10-visual-design-guide.md && git diff origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
# SysNDD Visual Guide

Date: 2026-05-14

Scope: recent curation/admin design refactor plus reference public table/home surfaces

Evidence: fresh Playwright review against `http://localhost:5173`

## Visual Positioning

SysNDD should feel like a clinical research operations tool: compact, trustworthy, table-first, and quiet. The product should avoid marketing-style decoration, oversized cards, and expressive gradients. The strongest current direction is already visible in the home page, public tables, authenticated page shell, `TableShell`, and curation review surfaces.

Use the interface to help expert users scan, compare, and act. Do not make them read decorative explanations before they can use the data.

## Current Reference Surfaces

Use these routes as the current visual baseline when reviewing design changes:

- Home: `/`
- Public table: `/Entities?sort=%2Bentity_id&page_size=10`
- Gene table: `/Genes?sort=%2Bsymbol&page_size=10`
- Wizard: `/CreateEntity`
- Review operations: `/ApproveReview` and `/ManageReReview`
- Mobile records: `/ManageOntology` and `/ManageUser`
- CMS/admin debt example: `/ManageAbout`

Generated screenshot captures belong under `.planning/screenshots/` and are intentionally ignored when they are PNG files.

## Design Tokens

### Color

Primary brand/action blue:

- `--medical-blue-700: #0d47a1`
- `--medical-blue-600: #1e88e5`
- Use for primary navigation, focused active state, primary links, and selected pagination.

Secondary operational accent:

- `--medical-teal-600: #00897b`
- Use sparingly for secondary positive actions and system accents.

Status colors:

- Success: `--status-success: #2e7d32`
- Warning: `--status-warning: #f57c00`
- Danger: `--status-danger: #c62828`
- Info: `--status-info: #0277bd`

Neutral foundation:

- Text: `--neutral-900: #212121`
- Secondary text: `--neutral-600: #757575`
- Surface backgrounds: white and near-white neutrals
- Borders: pale neutral/blue-gray lines with low visual weight
- Canonical surface border token: `--border-subtle: #d9e0ea` (the app-wide low-weight panel/card border used by the home page, public tables, and the user/analyses/curation surfaces). Use this token for card and panel borders; never use a heavy dark Bootstrap card border (`border-variant="dark"` / `.border-dark`). On a Bootstrap `BCard`, add the `.border-subtle` utility class instead of a dark variant.

Rules:

- Do not create a one-hue blue-only screen. Use blue for action and navigation, green/teal for biological identifiers or positive state, amber/red only for status.
- Never rely on color alone for status. Pair color with icons, labels, or both.
- Avoid dark cards and heavy bordered Bootstrap panels in admin/curation pages.

### Typography

Base stack: system sans (`-apple-system`, `Segoe UI`, Roboto, Arial).

Identifier stack: `--font-family-mono` for IDs, gene symbols, protein names, and compact scientific values.

Recommended scale:

- Page title: 18-22px, semibold, compact line height.
- Section title: 16-18px, semibold.
- Table headers and control labels: 12-14px, semibold.
- Body/table text: 14-16px.
- Helper/meta text: 12-14px.

Rules:

- Keep headings tight inside operational tools. Hero-scale type belongs only on true public-facing hero areas.
- Gene names and stable identifiers should be scannable, preferably using existing badge/mono conventions.
- Avoid negative letter spacing. It weakens dense table readability.

### Shape And Density

Radius:

- Default cards/panels: `--radius-md` to `--radius-lg` (`6-8px`).
- Pills/chips: `--radius-full`.
- Avoid `12-16px` cards for normal operational surfaces.

Spacing:

- Dense table controls: 8px gaps.
- Default form groups: 12px.
- Section spacing: 24-32px.
- Mobile row internal spacing: 8-12px.

Rules:

- Prefer one bounded surface per task area.
- Do not put UI cards inside other UI cards unless the inner card is a repeated data record.
- A page can be dense, but it must maintain stable alignment and clear grouping.

## Layout System

### Public Data Pages

Use public table pages as the table reference:

- Single table shell.
- Compact header with entity count and loaded count.
- Search and pagination in predictable rows.
- Filters directly above columns.
- Data chips for identifiers and classification.
- Actions aligned at the far right.

Do:

- Keep table controls close to the data they affect.
- Preserve column alignment and stable pagination width.
- Use compact badges for category, NDD state, inheritance, and identifiers.

Do not:

- Hide core table controls in distant page headers.
- Use large descriptive cards where a tight toolbar is enough.
- Let badges become visually heavier than the data itself.

### Authenticated Operation Pages

Use `AuthenticatedPageShell` for curation/admin routes.

Required structure:

1. Shell title and one-line description.
2. Optional KPI/stat row.
3. Primary operation or table surface.
4. Secondary tools in collapsed or lower-priority panels.
5. Footer-safe scroll area.

Rules:

- Exactly one route-level `h1`.
- Shell actions belong in the header when they affect the whole page.
- Dangerous actions should be visually separated from routine actions.
- Avoid duplicated route titles inside child cards.

### Tables

Use `TableShell` or match it closely.

Desktop:

- Toolbar first, table second.
- Column filters sit immediately above column headers.
- Row actions form a stable icon/action cluster.
- Empty, loading, and error states occupy the table body, not a separate detached card.

Mobile:

- Replace stacked Bootstrap table output with purpose-built record rows.
- Each row should have a primary identity line, secondary detail line, chip row, and action cluster.
- Keep row actions fixed in placement across records.

## Component Patterns

### Page Shell

Good pattern:

- White surface
- Thin border
- Compact header
- Subtle shadow
- Footer-safe bottom spacing

Avoid:

- Full-page stacks of unrelated cards
- Duplicate headings
- Heavy black/dark borders
- Centered narrow admin tools on desktop when the workflow is table-driven

### Wizard

The Create Entity wizard is a good baseline:

- Horizontal desktop stepper
- Short labels
- One focused step body
- Primary next action at bottom-right
- Toggle-style binary input for NDD phenotype

Improve next:

- On mobile, ensure step navigation does not become a cramped horizontal strip.
- Make required/optional field rhythm consistent across all steps.
- Keep review/submit summary visually closer to table/detail page conventions.

### Chips And Badges

Use chips for:

- Entity IDs
- Gene symbols
- Disease names
- Inheritance mode
- Category/classification
- Review/user/status labels

Rules:

- Chips should be compact, readable, and semantically colored.
- Avoid mixing several unrelated chip styles on one row.
- Use icons only where they improve recognition. Icon-only controls need accessible labels/tooltips.

Shared chip classes (added 2026-06): use the token-based, AA-verified classes in
`app/src/assets/scss/partials/_chips.scss` — `.sysndd-chip` plus a tone modifier
`--blue` / `--teal` / `--neutral` / `--success` / `--warning` / `--danger` / `--info`
(add `--mono` for identifiers). Do **not** reintroduce per-component pastel chip
palettes or Bootstrap blue (`#0d6efd`); those failed AA (e.g. `#0d6efd` on `#e7f1ff`
≈ 3:1). The `--info` tone uses a darkened ink (`#01579b`) because `--status-info`
on its tinted background fell just under 4.5:1.

### Forms

Forms should be dense but not cryptic.

Rules:

- Labels above controls for normal forms.
- Inline controls only when the relationship is obvious and the row remains scannable.
- Primary action belongs at the end of the flow.
- Secondary actions should be outline/neutral.
- Destructive actions should be red outline or danger-confirmed, not placed next to primary success actions without separation.

## Findings From Fresh Review

Playwright audit:

- 30 authenticated design checks passed across desktop and mobile.
- Fresh screenshots captured for 13 representative routes at `1440x900` and `390x844`.
- No captured route had document or main horizontal overflow.
- Authenticated routes consistently used the authenticated shell in the tested design spec.

Measured remaining debt:

| Surface | Evidence | Recommendation |
|---|---|---|
| `ManageOntology` mobile | `5183px` captured main scroll height | Keep compact rows, but reduce toolbar vertical stack and compress pagination/filter controls. |
| `ManageUser` mobile | `4400px` captured main scroll height | Move quick filters and pagination into denser segmented/filter rows; keep user rows compact. |
| `AdminStatistics` mobile | `3764px` captured main scroll height | Convert date controls and chart mode toggles into a tighter responsive control bar. |
| `ManageReReview` | `68` visible buttons on desktop capture | Reduce simultaneous action exposure; progressive disclosure is correct, but action density remains high. |
| `ManageAbout` | `16` card elements and nested publication sections | Convert to a true CMS layout: section list plus editor/preview pane, not repeated collapsible cards. |
| `ManageLLM` | `14` card elements | Keep dashboard intent but flatten nested card chrome. |

## Design Priorities

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
diff --git a/app/package-lock.json b/app/package-lock.json
index bcc638de..576baa20 100644
--- a/app/package-lock.json
+++ b/app/package-lock.json
@@ -1,12 +1,12 @@
 {
   "name": "sysndd",
-  "version": "0.30.0",
+  "version": "0.30.2",
   "lockfileVersion": 3,
   "requires": true,
   "packages": {
     "": {
       "name": "sysndd",
-      "version": "0.30.0",
+      "version": "0.30.2",
       "dependencies": {
         "@popperjs/core": "^2.11.8",
         "@unhead/vue": "^3.1.8",
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
diff --git a/app/src/api/admin_analysis_release.spec.ts b/app/src/api/admin_analysis_release.spec.ts
new file mode 100644
index 00000000..0a3f8a73
--- /dev/null
+++ b/app/src/api/admin_analysis_release.spec.ts
@@ -0,0 +1,261 @@
+import { afterEach, describe, expect, it } from 'vitest';
+import { http, HttpResponse } from 'msw';
+import { server } from '@/test-utils/mocks/server';
+import { primeAuth } from '@/test-utils/primeAuth';
+import { isApiError } from './client';
+import { extractApiErrorMessage } from '@/utils/api-errors';
+import {
+  buildRelease,
+  deleteDraftRelease,
+  fetchSnapshotStatus,
+  getAdminRelease,
+  listAdminReleases,
+  publishRelease,
+  recordReleaseDoi,
+  RELEASE_LAYER_TYPES,
+  type AdminReleaseHead,
+} from './admin_analysis_release';
+
+function makeHead(overrides: Partial<AdminReleaseHead> = {}): AdminReleaseHead {
+  return {
+    release_id: 'asr_abc1234567890def',
+    release_version: null,
+    title: 'Analysis snapshot release',
+    status: 'published',
+    manifest_schema_version: '1.0',
+    content_digest: 'a'.repeat(64),
+    source_data_version: '2026-07-19',
+    db_release_version: null,
+    db_release_commit: null,
+    manifest_sha256: 'b'.repeat(64),
+    bundle_sha256: 'c'.repeat(64),
+    license: 'CC-BY-4.0',
+    file_count: 10,
+    total_bytes: 1024,
+    created_by_user_id: 1,
+    created_at: '2026-07-19T00:00:00Z',
+    published_at: '2026-07-19T00:00:00Z',
+    updated_at: '2026-07-19T00:00:00Z',
+    zenodo_record_id: null,
+    zenodo_record_url: null,
+    version_doi: null,
+    concept_doi: null,
+    last_error_message: null,
+    ...overrides,
+  };
+}
+
+describe('admin_analysis_release api client', () => {
+  afterEach(() => server.resetHandlers());
+
+  describe('buildRelease', () => {
+    it('returns outcome:"created" on a 201 head', async () => {
+      primeAuth();
+      const head = makeHead({ status: 'published' });
+      server.use(
+        http.post('/api/admin/analysis/releases', () => HttpResponse.json(head, { status: 201 }))
+      );
+
+      const result = await buildRelease({});
+      expect(result).toEqual({ outcome: 'created', release: head });
+    });
+
+    it('returns outcome:"exists" on a 200 head (content-identical idempotent dup)', async () => {
+      primeAuth();
+      const head = makeHead();
+      server.use(
+        http.post('/api/admin/analysis/releases', () => HttpResponse.json(head, { status: 200 }))
+      );
+
+      const result = await buildRelease({});
+      expect(result).toEqual({ outcome: 'exists', release: head });
+    });
+
+    it('returns outcome:"locked" with retryAfter from the Retry-After header on a 503', async () => {
+      primeAuth();
+      server.use(
+        http.post('/api/admin/analysis/releases', () =>
+          HttpResponse.json(
+            { error: 'release_lock_unavailable', message: 'sources are mid-refresh' },
+            { status: 503, headers: { 'Retry-After': '5' } }
+          )
+        )
+      );
+
+      const result = await buildRelease({});
+      expect(result).toEqual({
+        outcome: 'locked',
+        retryAfter: 5,
+        message: 'sources are mid-refresh',
+      });
+    });
+
+    it('rejects with an ApiError on a 400 gate failure, extractable via extractApiErrorMessage', async () => {
+      primeAuth();
+      // Faithful RFC 9457 problem+json shape, as actually emitted by the
+      // real backend errorHandler (`make_problem_response()`,
+      // api/core/filters.R) — the reason lives under `detail`, never a
+      // top-level `message`.
+      server.use(
+        http.post('/api/admin/analysis/releases', () =>
+          HttpResponse.json(
+            {
+              type: 'https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400',
+              title: 'Bad Request',
+              status: 400,
+              detail: 'functional_clusters snapshot is not available',
+            },
+            { status: 400 }
+          )
+        )
+      );
+
+      await expect(buildRelease({})).rejects.toSatisfy((err: unknown) => {
+        expect(isApiError(err)).toBe(true);
+        expect(extractApiErrorMessage(err, 'fallback')).toBe(
+          'functional_clusters snapshot is not available'
+        );
+        return true;
+      });
+    });
+
+    it('sends the genuine nested JSON body (layers/title/scope_statement/license/publish)', async () => {
+      primeAuth();
+      let payload: unknown;
+      server.use(
+        http.post('/api/admin/analysis/releases', async ({ request }) => {
+          payload = await request.json();
+          return HttpResponse.json(makeHead(), { status: 201 });
+        })
+      );
+
+      await buildRelease({
+        layers: [{ analysis_type: 'functional_clusters' }],
+        title: 'My release',
+        scope_statement: 'scope',
+        license: 'CC0-1.0',
+        publish: false,
+      });
+
+      expect(payload).toEqual({
+        layers: [{ analysis_type: 'functional_clusters' }],
+        title: 'My release',
+        scope_statement: 'scope',
+        license: 'CC0-1.0',
+        publish: false,
+      });
+    });
+  });
+
+  it('listAdminReleases returns {releases, pagination}', async () => {
+    primeAuth();
+    const head = makeHead();
+    server.use(
+      http.get('/api/admin/analysis/releases', () =>
+        HttpResponse.json({ releases: [head], pagination: { limit: 50, offset: 0, count: 1 } })
+      )
+    );
+
+    const result = await listAdminReleases();
+    expect(result.releases).toEqual([head]);
+    expect(result.pagination).toEqual({ limit: 50, offset: 0, count: 1 });
+  });
+
+  it('getAdminRelease returns the bare head', async () => {
+    primeAuth();
+    const head = makeHead({ status: 'draft' });
+    server.use(
+      http.get('/api/admin/analysis/releases/asr_abc1234567890def', () => HttpResponse.json(head))
+    );
+
+    const result = await getAdminRelease('asr_abc1234567890def');
+    expect(result).toEqual(head);
+  });
+
+  it('publishRelease posts to /publish and returns the published head', async () => {
+    primeAuth();
+    const head = makeHead({ status: 'published' });
+    server.use(
+      http.post('/api/admin/analysis/releases/asr_abc1234567890def/publish', () =>
+        HttpResponse.json(head)
+      )
+    );
+
+    const result = await publishRelease('asr_abc1234567890def');
+    expect(result).toEqual(head);
+  });
+
+  describe('recordReleaseDoi', () => {
+    it('sends ONLY the supplied fields as query params', async () => {
+      primeAuth();
+      let requestUrl: URL | undefined;
+      const head = makeHead({ version_doi: '10.5281/zenodo.123' });
+      server.use(
+        http.patch('/api/admin/analysis/releases/asr_abc1234567890def/doi', ({ request }) => {
+          requestUrl = new URL(request.url);
+          return HttpResponse.json(head);
+        })
+      );
+
+      const result = await recordReleaseDoi('asr_abc1234567890def', {
+        version_doi: '10.5281/zenodo.123',
+      });
+
+      expect(result).toEqual(head);
+      expect(requestUrl?.searchParams.get('version_doi')).toBe('10.5281/zenodo.123');
+      expect(requestUrl?.searchParams.has('zenodo_record_id')).toBe(false);
+      expect(requestUrl?.searchParams.has('zenodo_record_url')).toBe(false);
+      expect(requestUrl?.searchParams.has('concept_doi')).toBe(false);
+    });
+  });
+
+  it('deleteDraftRelease issues a DELETE to the right URL', async () => {
+    primeAuth();
+    let called = false;
+    server.use(
+      http.delete('/api/admin/analysis/releases/asr_abc1234567890def', () => {
+        called = true;
+        return HttpResponse.json({ deleted: true });
+      })
+    );
+
+    await deleteDraftRelease('asr_abc1234567890def');
+    expect(called).toBe(true);
+  });
+
+  it('fetchSnapshotStatus returns {presets, summary}', async () => {
+    primeAuth();
+    server.use(
+      http.get('/api/admin/analysis/snapshots/status', () =>
+        HttpResponse.json({
+          presets: [
+            {
+              analysis_type: 'functional_clusters',
+              parameter_hash: 'ph1',
+              state: 'available',
+              generated_at: '2026-07-19T00:00:00Z',
+              activated_at: '2026-07-19T00:00:00Z',
+              stale_after: '2026-07-26T00:00:00Z',
+              source_data_version: '2026-07-19',
+              row_counts: { clusters: 5 },
+            },
+          ],
+          summary: { total: 5, available: 3, missing: 1, stale: 1, mismatch: 0 },
+        })
+      )
+    );
+
+    const result = await fetchSnapshotStatus();
+    expect(result.presets).toHaveLength(1);
+    expect(result.presets[0].analysis_type).toBe('functional_clusters');
+    expect(result.summary).toEqual({ total: 5, available: 3, missing: 1, stale: 1, mismatch: 0 });
+  });
+
+  it('exposes RELEASE_LAYER_TYPES as the single source of truth for release layers', () => {
+    expect(RELEASE_LAYER_TYPES).toEqual([
+      'functional_clusters',
+      'phenotype_clusters',
+      'phenotype_functional_correlations',
+    ]);
+  });
+});
diff --git a/app/src/api/admin_analysis_release.ts b/app/src/api/admin_analysis_release.ts
new file mode 100644
index 00000000..68ee8556
--- /dev/null
+++ b/app/src/api/admin_analysis_release.ts
@@ -0,0 +1,332 @@
+// app/src/api/admin_analysis_release.ts
+//
+// Administrator-only typed API client for analysis-snapshot RELEASE
+// management (#573 Slice B, Task B4a).
+//
+// Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (mounted at
+// /api/admin/analysis) — the release-management routes appended by #573
+// Slice A / Task A7. Every route here requires the Administrator role
+// (enforced server-side; `apiClient`'s interceptor supplies the bearer
+// token) and uses `@serializer unboxedJSON`, so response scalars are
+// plain JSON values, NOT array-wrapped — `unwrapScalar` is not needed here
+// (contrast `nddscore_admin.ts`, which reads a default-serialized route).
+//
+// The admin `/DataReleases` management VIEW that consumes this client is a
+// separate task (B4b) — this file is client-only, no view/composable/route.
+
+import type { AxiosRequestConfig } from 'axios';
+import { apiClient } from './client';
+
+// ---------------------------------------------------------------------------
+// Types
+// ---------------------------------------------------------------------------
+
+/**
+ * Light per-layer identity, as it appears in `layers[]` on each head from
+ * the admin LIST route (`GET /releases`) — mirrors `ReleaseHeadLayer` in the
+ * public `analysis_releases.ts`, duplicated here so this file has no
+ * dependency on that public-only module (see the `AdminReleaseHead` note
+ * below for why the two head shapes are intentionally separate types).
+ */
+export interface AdminReleaseLayer {
+  analysis_type: string;
+  snapshot_id: number;
+  payload_hash: string;
+}
+
+/**
+ * RAW `analysis_snapshot_release` head, as returned by the admin routes
+ * (`analysis_release_list()` / `analysis_release_get()`,
+ * api/functions/analysis-snapshot-release-repository.R). This is
+ * DELIBERATELY a SEPARATE type from the public `ReleaseHead` in
+ * `analysis_releases.ts` — the public projection nests DOI fields under
+ * `zenodo` and omits `created_by_user_id`/`last_error_message`; the admin
+ * surface returns the flat DOI columns plus those two operational fields.
+ * Do not import or reuse the public type here.
+ */
+export interface AdminReleaseHead {
+  release_id: string;
+  /**
+   * Reserved string column (`VARCHAR(32)`, migration 045) — always `null`
+   * today; the builder never populates it (`api/functions/analysis-snapshot-
+   * release.R`). Not a number, and not guaranteed non-null.
+   */
+  release_version: string | null;
+  title: string | null;
+  status: string;
+  manifest_schema_version: string;
+  content_digest: string;
+  source_data_version: string;
+  db_release_version: string | null;
+  db_release_commit: string | null;
+  manifest_sha256: string;
+  bundle_sha256: string;
+  license: string;
+  file_count: number;
+  total_bytes: number;
+  created_by_user_id: number | null;
+  created_at: string;
+  published_at: string | null;
+  updated_at: string;
+  zenodo_record_id: string | null;
+  zenodo_record_url: string | null;
+  version_doi: string | null;
+  concept_doi: string | null;
+  last_error_message: string | null;
+  /** Light per-layer summary (list route only). */
+  layers?: AdminReleaseLayer[];
+  [key: string]: unknown;
+}
+
+export interface AdminReleaseListParams {
+  limit?: number;
+  offset?: number;
+}
+
+export interface AdminReleaseListResponse {
+  releases: AdminReleaseHead[];
+  pagination: {
+    limit: number;
+    offset: number;
+    count: number;
+  };
+}
+
+export interface BuildReleaseRequest {
+  /** Optional layer-registry override; omit for the fixed default registry. */
+  layers?: unknown[];
+  title?: string;
+  scope_statement?: string;
+  /** Defaults server-side to `"CC-BY-4.0"`. */
+  license?: string;
+  /** Defaults server-side to `true`. */
+  publish?: boolean;
+}
+
+export interface RecordReleaseDoiFields {
+  zenodo_record_id?: string;
+  zenodo_record_url?: string;
+  version_doi?: string;
+  concept_doi?: string;
+}
+
+/**
+ * Discriminated build outcome so a caller (B4b's view) can distinguish a
+ * genuinely-new release (201), a content-identical idempotent dup (200),
+ * and a transient "sources are mid-refresh" lock (503) — three DIFFERENT
+ * non-error outcomes the backend deliberately does not throw for. A 400
+ * gate failure (`release_snapshot_not_available`,
+ * `release_source_incoherent`, `release_reproducibility_missing`,
+ * `release_source_version_mismatch`, `release_dependency_lineage_mismatch`)
+ * still rejects as an `ApiError`; the caller reads its message via
+ * `extractApiErrorMessage`.
+ */
+export type BuildReleaseResult =
+  | { outcome: 'created'; release: AdminReleaseHead }
+  | { outcome: 'exists'; release: AdminReleaseHead }
+  | { outcome: 'locked'; retryAfter: number; message: string };
+
+interface ReleaseLockUnavailableBody {
+  error: 'release_lock_unavailable';
+  message: string;
+}
+
+/**
+ * Per-preset manifest state, as returned by `GET /snapshots/status`
+ * (`service_analysis_snapshot_status()`). The endpoint reports every
+ * supported analysis preset — including `phenotype_correlations` and
+ * `gene_network_edges`, which are NOT analysis-snapshot-release layers.
+ * `RELEASE_LAYER_TYPES` below is the single source of truth for the subset
+ * a release build actually consumes.
+ */
+export interface SnapshotPresetState {
+  analysis_type: string;
+  parameter_hash: string;
+  state: 'available' | 'stale' | 'source_version_mismatch' | 'missing';
+  generated_at: string | null;
+  activated_at: string | null;
+  stale_after: string | null;
+  source_data_version: string | null;
+  row_counts: Record<string, unknown> | null;
+  [key: string]: unknown;
+}
+
+export interface SnapshotStatusSummary {
+  total: number;
+  available: number;
+  missing: number;
+  stale: number;
+  mismatch: number;
+}
+
+export interface SnapshotStatusResponse {
+  presets: SnapshotPresetState[];
+  summary: SnapshotStatusSummary;
+}
+
+/**
+ * The three analysis types an analysis-snapshot release actually freezes
+ * (`analysis_snapshot_release_layers()`, api/functions/analysis-snapshot-
+ * release.R). Single source of truth for filtering `GET /snapshots/status`'s
+ * broader preset list down to the layers B4b's "disable Build" gate cares
+ * about.
+ */
+export const RELEASE_LAYER_TYPES = [
+  'functional_clusters',
+  'phenotype_clusters',
+  'phenotype_functional_correlations',
+] as const;
+
+// ---------------------------------------------------------------------------
+// Helpers
+// ---------------------------------------------------------------------------
+
+/**
+ * POST /api/admin/analysis/releases
+ * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@post /releases`).
+ *
+ * Administrator-only. Loads the currently active public-ready snapshots,
+ * gates them, and persists an immutable, content-addressed release. Uses
+ * `apiClient.raw.post` with a widened `validateStatus` so 200 (idempotent
+ * dup), 201 (new content), and 503 (`release_lock_unavailable`, sources
+ * mid-refresh) all resolve instead of throwing — only those three plus any
+ * 4xx/5xx the caller opts into are distinguishable from a throw. 400 (any
+ * of the 5 gate-failure classes) and 404 (never actually returned by this
+ * route) still throw as `AxiosError`; the caller reads the message via
+ * `extractApiErrorMessage`.
+ */
+export async function buildRelease(
+  body: BuildReleaseRequest,
+  config?: AxiosRequestConfig
+): Promise<BuildReleaseResult> {
+  const response = await apiClient.raw.post<AdminReleaseHead | ReleaseLockUnavailableBody>(
+    '/api/admin/analysis/releases',
+    body,
+    {
+      ...config,
+      validateStatus: (status) => (status >= 200 && status < 300) || status === 503,
+    }
+  );
+
+  if (response.status === 503) {
+    const locked = response.data as ReleaseLockUnavailableBody;
+    const retryAfterHeader = response.headers?.['retry-after'];
+    const retryAfter = Number.parseInt(String(retryAfterHeader ?? '5'), 10);
+    return {
+      outcome: 'locked',
+      retryAfter: Number.isFinite(retryAfter) ? retryAfter : 5,
+      message: locked.message,
+    };
+  }
+
+  const release = response.data as AdminReleaseHead;
+  return {
+    outcome: response.status === 201 ? 'created' : 'exists',
+    release,
+  };
+}
+
+/**
+ * GET /api/admin/analysis/releases
+ * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /releases`).
+ *
+ * Administrator-only. Lists ALL releases (draft + published + failed),
+ * newest first — unlike the public `GET /api/analysis/releases`
+ * (published-only).
+ */
+export async function listAdminReleases(
+  params: AdminReleaseListParams = {},
+  config?: AxiosRequestConfig
+): Promise<AdminReleaseListResponse> {
+  return apiClient.get<AdminReleaseListResponse>('/api/admin/analysis/releases', {
+    ...config,
+    params: { ...(config?.params as object | undefined), ...params },
+  });
+}
+
+/**
+ * GET /api/admin/analysis/releases/<release_id>
+ * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /releases/<release_id>`).
+ *
+ * Administrator-only. Resolves a draft release too (`include_draft = true`).
+ * Throws AxiosError 404 for an unknown id.
+ */
+export async function getAdminRelease(
+  releaseId: string,
+  config?: AxiosRequestConfig
+): Promise<AdminReleaseHead> {
+  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}`;
+  return apiClient.get<AdminReleaseHead>(path, config);
+}
+
+/**
+ * POST /api/admin/analysis/releases/<release_id>/publish
+ * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@post /releases/<release_id>/publish`).
+ *
+ * Administrator-only. Throws AxiosError 404 for an unknown id; an
+ * already-published release is an idempotent no-op that still returns the
+ * current head.
+ */
+export async function publishRelease(
+  releaseId: string,
+  config?: AxiosRequestConfig
+): Promise<AdminReleaseHead> {
+  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}/publish`;
+  return apiClient.post<AdminReleaseHead>(path, undefined, config);
+}
+
+/**
+ * PATCH /api/admin/analysis/releases/<release_id>/doi
+ * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@patch /releases/<release_id>/doi`).
+ *
+ * Administrator-only. The four DOI fields are Plumber named args read from
+ * the query string, so ONLY the keys actually present in `fields` are
+ * forwarded as `config.params` — an omitted field must stay unchanged
+ * server-side, never nulled out by an unfiltered pass-through.
+ */
+export async function recordReleaseDoi(
+  releaseId: string,
+  fields: RecordReleaseDoiFields,
+  config?: AxiosRequestConfig
+): Promise<AdminReleaseHead> {
+  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}/doi`;
+  const params: Record<string, string> = {};
+  for (const [key, value] of Object.entries(fields)) {
+    if (value !== undefined && value !== null && value !== '') {
+      params[key] = value;
+    }
+  }
+  return apiClient.patch<AdminReleaseHead>(path, undefined, {
+    ...config,
+    params: { ...(config?.params as object | undefined), ...params },
+  });
+}
+
+/**
+ * DELETE /api/admin/analysis/releases/<release_id>
+ * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@delete /releases/<release_id>`).
+ *
+ * Administrator-only. Deletes a DRAFT release only. Throws AxiosError 400
+ * if the release is already published, 404 for an unknown id.
+ */
+export async function deleteDraftRelease(
+  releaseId: string,
+  config?: AxiosRequestConfig
+): Promise<void> {
+  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}`;
+  await apiClient.delete<unknown>(path, config);
+}
+
+/**
+ * GET /api/admin/analysis/snapshots/status
+ * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /snapshots/status`).
+ *
+ * Administrator-only. Per-preset manifest state for every supported
+ * analysis preset (not just the three release layers — see
+ * `RELEASE_LAYER_TYPES`).
+ */
+export async function fetchSnapshotStatus(
+  config?: AxiosRequestConfig
+): Promise<SnapshotStatusResponse> {
+  return apiClient.get<SnapshotStatusResponse>('/api/admin/analysis/snapshots/status', config);
+}
diff --git a/app/src/api/analysis.spec.ts b/app/src/api/analysis.spec.ts
index c3808224..a45c889d 100644
--- a/app/src/api/analysis.spec.ts
+++ b/app/src/api/analysis.spec.ts
@@ -13,14 +13,23 @@ import {
   getFunctionalClusterSummary,
   getPhenotypeClusterSummary,
   isSnapshotPreparingError,
+  listReleases,
+  getLatestRelease,
+  getRelease,
+  downloadReleaseManifest,
+  downloadReleaseFile,
+  downloadReleaseBundle,
   type FunctionalClusteringResponse,
   type PhenotypeCluster,
   type PhenotypeClusteringResponse,
   type CorrelationResponse,
   type NetworkEdgesResponse,
   type ClusterSummary,
+  type ReleaseHead,
+  type ReleaseDetail,
 } from './analysis';
 import { isApiError } from './client';
+import { extractApiErrorMessage } from '@/utils/api-errors';
 import { server } from '@/test-utils/mocks/server';

 describe('api/analysis — getFunctionalClustering', () => {
@@ -249,3 +258,263 @@ describe('isSnapshotPreparingError', () => {
     expect(isSnapshotPreparingError(new Error('boom'))).toBe(false);
   });
 });
+
+// ---------------------------------------------------------------------------
+// Analysis-snapshot releases (#573 Slice B, Task B1)
+// ---------------------------------------------------------------------------
+
+function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
+  return {
+    release_id: 'asr_0123456789abcdef',
+    release_version: null,
+    title: 'SysNDD analysis-snapshot release',
+    status: 'published',
+    content_digest: 'a'.repeat(64),
+    created_at: '2026-07-01T00:00:00Z',
+    published_at: '2026-07-01T00:05:00Z',
+    source_data_version: '2026-07-01',
+    db_release_version: '11.4.0',
+    db_release_commit: 'deadbeef',
+    manifest_sha256: 'b'.repeat(64),
+    bundle_sha256: 'c'.repeat(64),
+    license: 'CC-BY-4.0',
+    file_count: 10,
+    total_bytes: 123456,
+    zenodo: { record_url: null, version_doi: null, concept_doi: null },
+    ...overrides,
+  };
+}
+
+describe('api/analysis — listReleases', () => {
+  it('returns the releases envelope on 200', async () => {
+    server.use(
+      http.get('/api/analysis/releases', () =>
+        HttpResponse.json({
+          releases: [makeReleaseHead()],
+          pagination: { limit: 50, offset: 0, count: 1 },
+        })
+      )
+    );
+    const result = await listReleases();
+    expect(result.releases).toHaveLength(1);
+    expect(result.releases[0].release_id).toBe('asr_0123456789abcdef');
+    expect(result.pagination.count).toBe(1);
+    // Public head allowlist: admin-only fields must never be present.
+    expect(result.releases[0]).not.toHaveProperty('created_by_user_id');
+    expect(result.releases[0]).not.toHaveProperty('last_error_message');
+  });
+
+  it('forwards limit/offset query params', async () => {
+    let observedQuery: URLSearchParams | null = null;
+    server.use(
+      http.get('/api/analysis/releases', ({ request }) => {
+        observedQuery = new URL(request.url).searchParams;
+        return HttpResponse.json({
+          releases: [],
+          pagination: { limit: 10, offset: 5, count: 0 },
+        });
+      })
+    );
+    await listReleases({ limit: 10, offset: 5 });
+    const q = observedQuery as unknown as URLSearchParams;
+    expect(q.get('limit')).toBe('10');
+    expect(q.get('offset')).toBe('5');
+  });
+
+  it('throws AxiosError on non-2xx', async () => {
+    server.use(
+      http.get('/api/analysis/releases', () =>
+        HttpResponse.json({ message: 'boom' }, { status: 500 })
+      )
+    );
+    let caught: unknown;
+    try {
+      await listReleases();
+    } catch (err) {
+      caught = err;
+    }
+    expect(isApiError(caught)).toBe(true);
+    expect(extractApiErrorMessage(caught, 'fallback')).toBe('boom');
+  });
+});
+
+describe('api/analysis — getLatestRelease', () => {
+  it('returns the head + manifest on 200', async () => {
+    const detail: ReleaseDetail = {
+      ...makeReleaseHead(),
+      manifest: {
+        release_id: 'asr_0123456789abcdef',
+        release_version: null,
+        title: 'SysNDD analysis-snapshot release',
+        created_at: '2026-07-01T00:00:00Z',
+        license: 'CC-BY-4.0',
+        scope_statement: 'Public derived analysis only.',
+        generator: 'sysndd-api',
+        source: 'sysndd',
+        layers: [],
+        files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
+        content_digest: 'a'.repeat(64),
+      },
+    };
+    server.use(http.get('/api/analysis/releases/latest', () => HttpResponse.json(detail)));
+    const result = await getLatestRelease();
+    expect(result.release_id).toBe('asr_0123456789abcdef');
+    expect(result.manifest.files).toHaveLength(1);
+  });
+
+  it('throws AxiosError 404 when no published release exists', async () => {
+    server.use(
+      http.get('/api/analysis/releases/latest', () =>
+        HttpResponse.json({ message: 'No published analysis-snapshot release exists yet' }, { status: 404 })
+      )
+    );
+    let caught: unknown;
+    try {
+      await getLatestRelease();
+    } catch (err) {
+      caught = err;
+    }
+    expect(isApiError(caught)).toBe(true);
+    if (isApiError(caught)) {
+      expect(caught.response?.status).toBe(404);
+    }
+  });
+});
+
+describe('api/analysis — getRelease', () => {
+  it('returns the head + manifest on 200 and encodes the release id', async () => {
+    let observedPath = '';
+    const detail: ReleaseDetail = {
+      ...makeReleaseHead({ release_id: 'asr_abc123' }),
+      manifest: {
+        release_id: 'asr_abc123',
+        release_version: null,
+        title: 'SysNDD analysis-snapshot release',
+        created_at: '2026-07-01T00:00:00Z',
+        license: 'CC-BY-4.0',
+        scope_statement: 'Public derived analysis only.',
+        generator: 'sysndd-api',
+        source: 'sysndd',
+        layers: [],
+        files: [],
+        content_digest: 'a'.repeat(64),
+      },
+    };
+    server.use(
+      http.get('/api/analysis/releases/:releaseId', ({ request, params }) => {
+        observedPath = new URL(request.url).pathname;
+        expect(params.releaseId).toBe('asr_abc123');
+        return HttpResponse.json(detail);
+      })
+    );
+    const result = await getRelease('asr_abc123');
+    expect(result.release_id).toBe('asr_abc123');
+    expect(observedPath).toBe('/api/analysis/releases/asr_abc123');
+  });
+
+  it('throws AxiosError 404 for an unknown/draft release id', async () => {
+    server.use(
+      http.get('/api/analysis/releases/:releaseId', () =>
+        HttpResponse.json({ message: 'not found' }, { status: 404 })
+      )
+    );
+    let caught: unknown;
+    try {
+      await getRelease('asr_unknown');
+    } catch (err) {
+      caught = err;
+    }
+    expect(isApiError(caught)).toBe(true);
+    if (isApiError(caught)) {
+      expect(caught.response?.status).toBe(404);
+    }
+  });
+});
+
+describe('api/analysis — downloadReleaseManifest', () => {
+  it('returns the manifest.json bytes as a Blob', async () => {
+    server.use(
+      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
+        HttpResponse.json({ release_id: 'asr_abc123' })
+      )
+    );
+    const blob = await downloadReleaseManifest('asr_abc123');
+    expect(blob).toBeInstanceOf(Blob);
+  });
+
+  it('throws AxiosError on non-2xx', async () => {
+    server.use(
+      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
+        HttpResponse.json({ message: 'not found' }, { status: 404 })
+      )
+    );
+    let caught: unknown;
+    try {
+      await downloadReleaseManifest('asr_unknown');
+    } catch (err) {
+      caught = err;
+    }
+    expect(isApiError(caught)).toBe(true);
+  });
+});
+
+describe('api/analysis — downloadReleaseFile', () => {
+  it('forwards the file path as a query param and returns a Blob', async () => {
+    let observedQuery: URLSearchParams | null = null;
+    server.use(
+      http.get('/api/analysis/releases/:releaseId/file', ({ request }) => {
+        observedQuery = new URL(request.url).searchParams;
+        return HttpResponse.json({ ok: true });
+      })
+    );
+    const blob = await downloadReleaseFile('asr_abc123', 'functional_clusters/payload.json');
+    expect(blob).toBeInstanceOf(Blob);
+    const q = observedQuery as unknown as URLSearchParams;
+    expect(q.get('path')).toBe('functional_clusters/payload.json');
+  });
+
+  it('throws AxiosError on non-2xx (unknown file path)', async () => {
+    server.use(
+      http.get('/api/analysis/releases/:releaseId/file', () =>
+        HttpResponse.json({ message: 'not found' }, { status: 404 })
+      )
+    );
+    let caught: unknown;
+    try {
+      await downloadReleaseFile('asr_abc123', 'nope.json');
+    } catch (err) {
+      caught = err;
+    }
+    expect(isApiError(caught)).toBe(true);
+    if (isApiError(caught)) {
+      expect(caught.response?.status).toBe(404);
+    }
+  });
+});
+
+describe('api/analysis — downloadReleaseBundle', () => {
+  it('returns the bundle.tar.gz bytes as a Blob', async () => {
+    server.use(
+      http.get('/api/analysis/releases/:releaseId/bundle', () =>
+        HttpResponse.json({ ok: true })
+      )
+    );
+    const blob = await downloadReleaseBundle('asr_abc123');
+    expect(blob).toBeInstanceOf(Blob);
+  });
+
+  it('throws AxiosError on non-2xx', async () => {
+    server.use(
+      http.get('/api/analysis/releases/:releaseId/bundle', () =>
+        HttpResponse.json({ message: 'not found' }, { status: 404 })
+      )
+    );
+    let caught: unknown;
+    try {
+      await downloadReleaseBundle('asr_unknown');
+    } catch (err) {
+      caught = err;
+    }
+    expect(isApiError(caught)).toBe(true);
+  });
+});
diff --git a/app/src/api/analysis.ts b/app/src/api/analysis.ts
index 8df6a19d..3213ce6d 100644
--- a/app/src/api/analysis.ts
+++ b/app/src/api/analysis.ts
@@ -422,3 +422,14 @@ export async function getPhenotypeClusterSummary(
     params: { ...(config?.params as object | undefined), ...params },
   });
 }
+
+// ---------------------------------------------------------------------------
+// Analysis-snapshot releases (#573)
+//
+// Split into `analysis_releases.ts` (a cohesive sub-domain: immutable release
+// types + the `releases/*` routes) to keep this file under the repo's
+// 600-line soft ceiling. Re-exported here so `@/api/analysis` stays the
+// single import surface for analysis resources.
+// ---------------------------------------------------------------------------
+
+export * from './analysis_releases';
diff --git a/app/src/api/analysis_releases.ts b/app/src/api/analysis_releases.ts
new file mode 100644
index 00000000..3592854e
--- /dev/null
+++ b/app/src/api/analysis_releases.ts
@@ -0,0 +1,285 @@
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
+  scope_statement: string;
+  generator: string;
+  source: string;
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
diff --git a/app/src/assets/js/constants/main_nav_constants.ts b/app/src/assets/js/constants/main_nav_constants.ts
index fdb868f5..5235fec0 100644
--- a/app/src/assets/js/constants/main_nav_constants.ts
+++ b/app/src/assets/js/constants/main_nav_constants.ts
@@ -66,6 +66,7 @@ const MAIN_NAV = {
         { text: 'NDD Publications', path: '/PublicationsNDD' },
         { text: 'PubTator Analysis', path: '/PubtatorNDD' },
         { text: 'Functional clusters', path: '/GeneNetworks' },
+        { text: 'Data releases', path: '/DataReleases' },
         { text: 'Phenotype–function correlation', path: '/PhenotypeFunctionalCorrelation' },
       ],
     },
@@ -116,6 +117,11 @@ const MAIN_NAV = {
         { text: 'Manage PubTator', path: '/ManagePubtator', icons: ['gear', 'journal-medical'] },
         { text: 'LLM Management', path: '/ManageLLM', icons: ['gear', 'robot'] },
         { text: 'Manage NDDScore', path: '/ManageNDDScore', icons: ['gear', 'graph-up-arrow'] },
+        {
+          text: 'Manage releases',
+          path: '/ManageAnalysisReleases',
+          icons: ['gear', 'archive'],
+        },
         { text: 'Manage metadata', path: '/ManageMetadata', icons: ['gear', 'list-check'] },
         {
           text: 'Manage ontology mappings',
diff --git a/app/src/components/analyses/ReleaseManifestPanel.spec.ts b/app/src/components/analyses/ReleaseManifestPanel.spec.ts
new file mode 100644
index 00000000..ce5daf37
--- /dev/null
+++ b/app/src/components/analyses/ReleaseManifestPanel.spec.ts
@@ -0,0 +1,159 @@
+import { mount } from '@vue/test-utils';
+import { describe, expect, it, vi } from 'vitest';
+import ReleaseManifestPanel from './ReleaseManifestPanel.vue';
+import type { ReleaseDetail } from '@/api/analysis';
+
+function makeReleaseDetail(): ReleaseDetail {
+  return {
+    release_id: 'asr_0123456789abcdef',
+    release_version: null,
+    title: 'SysNDD analysis-snapshot release',
+    status: 'published',
+    content_digest: 'a'.repeat(64),
+    created_at: '2026-07-01T00:00:00Z',
+    published_at: '2026-07-01T00:05:00Z',
+    source_data_version: '2026-07-01',
+    db_release_version: '11.4.0',
+    db_release_commit: 'deadbeef',
+    manifest_sha256: 'b'.repeat(64),
+    bundle_sha256: 'c'.repeat(64),
+    license: 'CC-BY-4.0',
+    file_count: 10,
+    total_bytes: 1258291,
+    zenodo: {
+      record_url: 'https://zenodo.org/records/1234',
+      version_doi: '10.5281/zenodo.1234',
+      concept_doi: '10.5281/zenodo.1233',
+    },
+    manifest: {
+      release_id: 'asr_0123456789abcdef',
+      release_version: null,
+      title: 'SysNDD analysis-snapshot release',
+      created_at: '2026-07-01T00:00:00Z',
+      license: 'CC-BY-4.0',
+      scope_statement: 'Public derived analysis only.',
+      generator: 'sysndd-api',
+      source: 'sysndd',
+      layers: [
+        {
+          analysis_type: 'functional_clusters',
+          parameter_hash: 'fp-hash',
+          snapshot_id: 101,
+          input_hash: 'in-func',
+          payload_hash: 'pay-func',
+          schema_version: '1.2',
+          reproducibility_hash: 'repro-func',
+          dependencies: null,
+        },
+        {
+          analysis_type: 'phenotype_clusters',
+          parameter_hash: 'pp-hash',
+          snapshot_id: 202,
+          input_hash: 'in-pheno',
+          payload_hash: 'pay-pheno',
+          schema_version: '1.2',
+          reproducibility_hash: 'repro-pheno',
+          dependencies: null,
+        },
+        {
+          analysis_type: 'phenotype_functional_correlations',
+          parameter_hash: 'cp-hash',
+          snapshot_id: 303,
+          input_hash: 'in-corr',
+          payload_hash: 'pay-corr',
+          schema_version: '1.2',
+          reproducibility_hash: null,
+          dependencies: {
+            functional_clusters: { snapshot_id: 101, payload_hash: 'pay-func' },
+            phenotype_clusters: { snapshot_id: 202, payload_hash: 'pay-pheno' },
+          },
+        },
+      ],
+      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
+      content_digest: 'a'.repeat(64),
+    },
+  };
+}
+
+describe('ReleaseManifestPanel', () => {
+  it('renders all three integrity hashes', () => {
+    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
+    const text = wrapper.text();
+    expect(text).toContain('a'.repeat(64)); // content_digest
+    expect(text).toContain('b'.repeat(64)); // manifest_sha256
+    expect(text).toContain('c'.repeat(64)); // bundle_sha256
+  });
+
+  it('shows the correlation layer dependency lineage and its "n/a" reproducibility hash', () => {
+    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
+    const text = wrapper.text();
+    expect(text).toContain('n/a (not reproducible)');
+    expect(text).toContain('Dependency lineage');
+    expect(text).toContain('pay-func');
+    expect(text).toContain('pay-pheno');
+    expect(text).toContain('101');
+    expect(text).toContain('202');
+  });
+
+  it('renders the version DOI as a doi.org link', () => {
+    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
+    const link = wrapper.find('a[href="https://doi.org/10.5281/zenodo.1234"]');
+    expect(link.exists()).toBe(true);
+    expect(link.text()).toBe('10.5281/zenodo.1234');
+  });
+
+  it('shows "not yet assigned" when a DOI is null', () => {
+    const release = makeReleaseDetail();
+    release.zenodo = { record_url: null, version_doi: null, concept_doi: null };
+    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
+    expect(wrapper.text()).toContain('not yet assigned');
+  });
+
+  it('omits the Version row when release_version is null (the current, always-null default)', () => {
+    const release = makeReleaseDetail();
+    expect(release.release_version).toBeNull();
+    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
+    const dts = wrapper.findAll('dt').map((dt) => dt.text());
+    expect(dts).not.toContain('Version');
+  });
+
+  it('shows the Version row when release_version is populated', () => {
+    const release = makeReleaseDetail();
+    release.release_version = '1.0';
+    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
+    const dts = wrapper.findAll('dt').map((dt) => dt.text());
+    expect(dts).toContain('Version');
+    expect(wrapper.text()).toContain('1.0');
+  });
+
+  it('falls back to release_id for the title when title is null', () => {
+    const release = makeReleaseDetail();
+    release.title = null;
+    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
+    expect(wrapper.find('#release-manifest-panel-title').text()).toBe('asr_0123456789abcdef');
+    const dts = wrapper.findAll('dt').map((dt) => dt.text());
+    const titleDd = wrapper.findAll('dt').find((dt) => dt.text() === 'Title')?.element.nextElementSibling;
+    expect(dts).toContain('Title');
+    expect(titleDd?.textContent).toBe('asr_0123456789abcdef');
+  });
+
+  it('copies a hash to the clipboard when its copy button is clicked', async () => {
+    const writeText = vi.fn().mockResolvedValue(undefined);
+    Object.defineProperty(navigator, 'clipboard', {
+      configurable: true,
+      value: { writeText },
+    });
+
+    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
+    const button = wrapper
+      .findAll('button')
+      .find((btn) => btn.attributes('aria-label') === 'Copy Content digest to clipboard');
+    expect(button).toBeTruthy();
+
+    await button!.trigger('click');
+    await wrapper.vm.$nextTick();
+
+    expect(writeText).toHaveBeenCalledWith('a'.repeat(64));
+    expect(button!.text()).toContain('Copied');
+  });
+});
diff --git a/app/src/components/analyses/ReleaseManifestPanel.vue b/app/src/components/analyses/ReleaseManifestPanel.vue
new file mode 100644
index 00000000..5ef9d461
--- /dev/null
+++ b/app/src/components/analyses/ReleaseManifestPanel.vue
@@ -0,0 +1,409 @@
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
+              v-if="release.zenodo.version_doi"
+              :href="doiUrl(release.zenodo.version_doi)"
+              target="_blank"
+              rel="noopener noreferrer"
+            >
+              {{ release.zenodo.version_doi }}
+            </a>
+            <span v-else class="text-muted">not yet assigned</span>
+          </dd>
+        </div>
+        <div>
+          <dt>Concept DOI</dt>
+          <dd>
+            <a
+              v-if="release.zenodo.concept_doi"
+              :href="doiUrl(release.zenodo.concept_doi)"
+              target="_blank"
+              rel="noopener noreferrer"
+            >
+              {{ release.zenodo.concept_doi }}
+            </a>
+            <span v-else class="text-muted">not yet assigned</span>
+          </dd>
+        </div>
+        <div>
+          <dt>Zenodo record</dt>
+          <dd>
+            <a
+              v-if="release.zenodo.record_url"
+              :href="release.zenodo.record_url"
+              target="_blank"
+              rel="noopener noreferrer"
+            >
+              Record
+            </a>
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
diff --git a/app/src/components/analyses/dataReleaseTable.spec.ts b/app/src/components/analyses/dataReleaseTable.spec.ts
new file mode 100644
index 00000000..a21eb64e
--- /dev/null
+++ b/app/src/components/analyses/dataReleaseTable.spec.ts
@@ -0,0 +1,150 @@
+import { describe, it, expect } from 'vitest';
+import {
+  formatReleaseBytes,
+  normalizeReleaseRows,
+  RELEASE_TABLE_FIELDS,
+  DOI_UNASSIGNED,
+} from './dataReleaseTable';
+import type { ReleaseHead } from '@/api/analysis_releases';
+
+function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
+  return {
+    release_id: 'asr_0123456789abcdef',
+    release_version: null,
+    title: 'SysNDD analysis-snapshot release',
+    status: 'published',
+    content_digest: 'a'.repeat(64),
+    created_at: '2026-07-01T00:00:00Z',
+    published_at: '2026-07-01T00:05:00Z',
+    source_data_version: '2026-07-01',
+    db_release_version: '11.4.0',
+    db_release_commit: 'deadbeef',
+    manifest_sha256: 'b'.repeat(64),
+    bundle_sha256: 'c'.repeat(64),
+    license: 'CC-BY-4.0',
+    file_count: 10,
+    total_bytes: 1258291,
+    zenodo: { record_url: null, version_doi: null, concept_doi: null },
+    ...overrides,
+  };
+}
+
+describe('formatReleaseBytes', () => {
+  it('formats a sub-KB byte count without a decimal', () => {
+    expect(formatReleaseBytes(500)).toBe('500 B');
+  });
+
+  it('formats a KB boundary', () => {
+    expect(formatReleaseBytes(1536)).toBe('1.5 KB');
+  });
+
+  it('formats an MB value', () => {
+    expect(formatReleaseBytes(1258291)).toBe('1.2 MB');
+  });
+
+  it('guards the zero boundary', () => {
+    expect(formatReleaseBytes(0)).toBe('0 B');
+  });
+
+  it('guards negative input', () => {
+    expect(formatReleaseBytes(-5)).toBe('0 B');
+  });
+
+  it('guards non-finite input (NaN, Infinity)', () => {
+    expect(formatReleaseBytes(NaN)).toBe('0 B');
+    expect(formatReleaseBytes(Infinity)).toBe('0 B');
+    expect(formatReleaseBytes(-Infinity)).toBe('0 B');
+  });
+});
+
+describe('RELEASE_TABLE_FIELDS', () => {
+  it('uses only flat keys (no dots — the BVN BTable trap)', () => {
+    for (const field of RELEASE_TABLE_FIELDS) {
+      expect(field.key).not.toContain('.');
+    }
+  });
+
+  it('surfaces the documented release columns (no Version column — release_version is always null)', () => {
+    const keys = RELEASE_TABLE_FIELDS.map((f) => f.key);
+    expect(keys).toEqual([
+      'release_id',
+      'published_at',
+      'source_data_version',
+      'file_count',
+      'total_bytes_display',
+      'license',
+      'zenodo_version_doi',
+      'actions',
+    ]);
+    expect(keys).not.toContain('release_version');
+  });
+});
+
+describe('normalizeReleaseRows', () => {
+  it('flattens zenodo.* into flat zenodo_* keys with no dotted keys', () => {
+    const rows = normalizeReleaseRows([
+      makeReleaseHead({
+        zenodo: {
+          record_url: 'https://zenodo.org/records/1234',
+          version_doi: '10.5281/zenodo.1234',
+          concept_doi: '10.5281/zenodo.1233',
+        },
+      }),
+    ]);
+    expect(rows).toHaveLength(1);
+    const row = rows[0] as unknown as Record<string, unknown>;
+    expect(row.zenodo_version_doi).toBe('10.5281/zenodo.1234');
+    expect(row.zenodo_concept_doi).toBe('10.5281/zenodo.1233');
+    expect(row.zenodo_record_url).toBe('https://zenodo.org/records/1234');
+    expect(Object.keys(row).some((key) => key.includes('.'))).toBe(false);
+  });
+
+  it('formats total_bytes_display via formatReleaseBytes', () => {
+    const rows = normalizeReleaseRows([makeReleaseHead({ total_bytes: 1258291 })]);
+    expect(rows[0].total_bytes_display).toBe('1.2 MB');
+    expect(rows[0].total_bytes).toBe(1258291);
+  });
+
+  it('maps a null zenodo.version_doi to the DOI_UNASSIGNED sentinel', () => {
+    const rows = normalizeReleaseRows([
+      makeReleaseHead({ zenodo: { record_url: null, version_doi: null, concept_doi: null } }),
+    ]);
+    expect(rows[0].zenodo_version_doi).toBe(DOI_UNASSIGNED);
+    expect(rows[0].zenodo_concept_doi).toBe(DOI_UNASSIGNED);
+    expect(rows[0].zenodo_record_url).toBe(DOI_UNASSIGNED);
+  });
+
+  it('falls back to created_at when published_at is null', () => {
+    const rows = normalizeReleaseRows([
+      makeReleaseHead({ published_at: null, created_at: '2026-06-15T00:00:00Z' }),
+    ]);
+    expect(rows[0].published_at).toBe('2026-06-15T00:00:00Z');
+  });
+
+  it('carries release_id, title, status, license, file_count through unchanged', () => {
+    const rows = normalizeReleaseRows([
+      makeReleaseHead({ release_id: 'asr_abc123', file_count: 42 }),
+    ]);
+    expect(rows[0].release_id).toBe('asr_abc123');
+    expect(rows[0].title).toBe('SysNDD analysis-snapshot release');
+    expect(rows[0].status).toBe('published');
+    expect(rows[0].license).toBe('CC-BY-4.0');
+    expect(rows[0].file_count).toBe(42);
+  });
+
+  it('falls back to release_id when title is null (release_version is always null too)', () => {
+    const rows = normalizeReleaseRows([
+      makeReleaseHead({ release_id: 'asr_no_title', title: null }),
+    ]);
+    expect(rows[0].title).toBe('asr_no_title');
+    expect(rows[0]).not.toHaveProperty('release_version');
+  });
+
+  it('does not mutate the input and tolerates null/undefined', () => {
+    const input = [makeReleaseHead()];
+    const rows = normalizeReleaseRows(input);
+    expect(rows).not.toBe(input);
+    expect(normalizeReleaseRows(null)).toEqual([]);
+    expect(normalizeReleaseRows(undefined)).toEqual([]);
+  });
+});
diff --git a/app/src/components/analyses/dataReleaseTable.ts b/app/src/components/analyses/dataReleaseTable.ts
new file mode 100644
index 00000000..7f188760
--- /dev/null
+++ b/app/src/components/analyses/dataReleaseTable.ts
@@ -0,0 +1,124 @@
+// src/components/analyses/dataReleaseTable.ts
+//
+// Pure client-side table transform for the public /DataReleases page (#573
+// Slice B, Task B2). Flattens the release LIST envelope (`ReleaseHead[]`)
+// into flat rows for the `GenericTable` wrapper.
+//
+// Mirrors the dotted-key-flatten pattern of `normalizePhenotypeClusterRows()`
+// in `phenotypeClusterTable.ts`: BootstrapVueNext's BTable renders a BLANK
+// cell for any field key containing a dot (see the AGENTS.md BVN gotcha), and
+// the release head's `zenodo` sub-object would otherwise force dotted access
+// (`zenodo.version_doi`) that can't be bound as a flat field key. There is no
+// dotted source key here (unlike the MCA stats), but the same flatten
+// discipline applies to the nested `zenodo` object.
+//
+// Display-string formatting (byte size, the DOI "not assigned" sentinel) is
+// baked directly into the row here rather than via a BTable `field.formatter`
+// — `GenericDesktopTable.vue` only exposes custom cell slots for a fixed,
+// hardcoded set of field keys (none of which are the release columns), so a
+// per-field formatter would silently never run. Pre-formatting the row is
+// the same convention already used for `ndd_score`/`percentile` in the
+// NDDScore gene table.
+
+import type { ReleaseHead } from '@/api/analysis_releases';
+
+/** `GenericTable` fields config entry (flat keys only — see file header). */
+export interface ReleaseTableField {
+  key: string;
+  label: string;
+  sortable?: boolean;
+}
+
+/** Flat table row for one release (LIST route head — no manifest). */
+export interface ReleaseTableRow {
+  release_id: string;
+  /** `title`, falling back to `release_id` when the reserved `title` column is null. */
+  title: string;
+  status: string;
+  /** `published_at`, falling back to `created_at` when not yet published-dated. */
+  published_at: string;
+  source_data_version: string;
+  file_count: number;
+  total_bytes: number;
+  /** Human-readable `total_bytes` (e.g. "1.2 MB"), via `formatReleaseBytes()`. */
+  total_bytes_display: string;
+  license: string;
+  /** Flattened `zenodo.version_doi`; the DOI_UNASSIGNED sentinel when null. */
+  zenodo_version_doi: string;
+  /** Flattened `zenodo.concept_doi`; the DOI_UNASSIGNED sentinel when null. */
+  zenodo_concept_doi: string;
+  /** Flattened `zenodo.record_url`; the DOI_UNASSIGNED sentinel when null. */
+  zenodo_record_url: string;
+}
+
+const BYTE_UNITS = ['B', 'KB', 'MB', 'GB', 'TB'] as const;
+
+/** Sentinel shown for a `zenodo` field that has not been recorded yet (#573 DOI is additive). */
+export const DOI_UNASSIGNED = '—';
+
+/**
+ * Human-readable byte size (e.g. "1.2 MB", "512 B", "1.5 KB"). Non-finite
+ * (`NaN`/`Infinity`) and non-positive input degrade to "0 B" rather than
+ * rendering "NaN" or indexing past the unit table.
+ */
+export function formatReleaseBytes(bytes: number): string {
+  if (!Number.isFinite(bytes) || bytes <= 0) {
+    return '0 B';
+  }
+  const exponent = Math.min(
+    Math.floor(Math.log(bytes) / Math.log(1024)),
+    BYTE_UNITS.length - 1
+  );
+  const value = parseFloat((bytes / 1024 ** exponent).toFixed(1));
+  return `${value} ${BYTE_UNITS[exponent]}`;
+}
+
+/** Flattens a possibly-null zenodo field to a display string. */
+function doiOrDash(value: string | null | undefined): string {
+  return value ? value : DOI_UNASSIGNED;
+}
+
+/**
+ * `GenericTable` fields config for the releases list. Columns: Release,
+ * Published, Source data version, Files, Size, License, Version DOI, plus a
+ * `Manifest` actions column (row selection — see
+ * `views/analyses/DataReleases.vue`). No `Version` column: `release_version`
+ * is a reserved, currently-unpopulated string column (always `null` today),
+ * so displaying it would be pure noise. No column is wired to client-side
+ * sorting (the LIST route already returns newest-first); `sortable` is kept
+ * optional on the type so a future column can opt in without a shape change.
+ */
+export const RELEASE_TABLE_FIELDS: ReleaseTableField[] = [
+  { key: 'release_id', label: 'Release' },
+  { key: 'published_at', label: 'Published' },
+  { key: 'source_data_version', label: 'Source data version' },
+  { key: 'file_count', label: 'Files' },
+  { key: 'total_bytes_display', label: 'Size' },
+  { key: 'license', label: 'License' },
+  { key: 'zenodo_version_doi', label: 'Version DOI' },
+  { key: 'actions', label: 'Manifest' },
+];
+
+/**
+ * Flattens the public LIST envelope's release heads into `GenericTable` rows.
+ * Returns a new array; input heads are not mutated. Tolerates null/undefined
+ * input (renders as an empty table rather than throwing).
+ */
+export function normalizeReleaseRows(
+  releases: ReleaseHead[] | null | undefined
+): ReleaseTableRow[] {
+  return (releases || []).map((release) => ({
+    release_id: release.release_id,
+    title: release.title || release.release_id,
+    status: release.status,
+    published_at: release.published_at || release.created_at,
+    source_data_version: release.source_data_version,
+    file_count: release.file_count,
+    total_bytes: release.total_bytes,
+    total_bytes_display: formatReleaseBytes(release.total_bytes),
+    license: release.license,
+    zenodo_version_doi: doiOrDash(release.zenodo?.version_doi),
+    zenodo_concept_doi: doiOrDash(release.zenodo?.concept_doi),
+    zenodo_record_url: doiOrDash(release.zenodo?.record_url),
+  }));
+}
diff --git a/app/src/router/routes.datareleases.spec.ts b/app/src/router/routes.datareleases.spec.ts
new file mode 100644
index 00000000..7d1db994
--- /dev/null
+++ b/app/src/router/routes.datareleases.spec.ts
@@ -0,0 +1,51 @@
+import { describe, expect, it, vi } from 'vitest';
+
+vi.mock('@/composables/useAuth', () => ({
+  useAuth: () => ({
+    isAuthenticated: { value: true },
+    isExpired: { value: false },
+    hasRole: (role: string) => role === 'Administrator',
+  }),
+}));
+
+import { routes } from './routes';
+import {
+  DROPDOWN_ITEMS_LEFT,
+  DROPDOWN_ITEMS_RIGHT,
+} from '@/assets/js/constants/main_nav_constants';
+
+describe('Data releases navigation + routes', () => {
+  it('adds a Data releases item to the public Analyses dropdown', () => {
+    const analyses = DROPDOWN_ITEMS_LEFT.find((d) => d.id === 'analyses_dropdown');
+
+    expect(
+      analyses?.items.some((i) => i.text === 'Data releases' && i.path === '/DataReleases')
+    ).toBe(true);
+  });
+
+  it('registers a public /DataReleases route', () => {
+    const dataReleases = routes.find((r) => r.path === '/DataReleases');
+
+    expect(dataReleases).toBeDefined();
+    expect(dataReleases?.name).toBe('DataReleases');
+    expect(dataReleases?.beforeEnter).toBeUndefined();
+    expect(dataReleases?.component).toBeDefined();
+    expect(dataReleases?.meta?.sitemap).toEqual({ priority: 0.7, changefreq: 'monthly' });
+  });
+
+  it('registers an Administrator-guarded /ManageAnalysisReleases route', () => {
+    const manage = routes.find((r) => r.path === '/ManageAnalysisReleases');
+    expect(manage).toBeDefined();
+    expect(typeof manage?.beforeEnter).toBe('function');
+  });
+
+  it('adds a Manage releases item to the Administration dropdown', () => {
+    const administration = DROPDOWN_ITEMS_RIGHT.find((d) => d.id === 'administration_dropdown');
+
+    expect(
+      administration?.items.some(
+        (i) => i.text === 'Manage releases' && i.path === '/ManageAnalysisReleases'
+      )
+    ).toBe(true);
+  });
+});
diff --git a/app/src/router/routes.ts b/app/src/router/routes.ts
index f28ede24..30038f20 100644
--- a/app/src/router/routes.ts
+++ b/app/src/router/routes.ts
@@ -274,6 +274,17 @@ export const routes: RouteRecordRaw[] = [
       },
     },
   },
+  {
+    path: '/DataReleases',
+    name: 'DataReleases',
+    component: () => import('@/views/analyses/DataReleases.vue'),
+    meta: {
+      sitemap: {
+        priority: 0.7,
+        changefreq: 'monthly',
+      },
+    },
+  },
   {
     path: '/NDDScore',
     component: () => import('@/views/nddscore/NDDScore.vue'),
@@ -490,6 +501,7 @@ export const routes: RouteRecordRaw[] = [
     'ManageNDDScore',
     'ManageMetadata',
     'ManageOntologyMappings',
+    'ManageAnalysisReleases',
   ].map(simpleAdminRoute),
   {
     path: '/Entities/:entity_id',
diff --git a/app/src/views/admin/ManageAnalysisReleases.spec.ts b/app/src/views/admin/ManageAnalysisReleases.spec.ts
new file mode 100644
index 00000000..e011799a
--- /dev/null
+++ b/app/src/views/admin/ManageAnalysisReleases.spec.ts
@@ -0,0 +1,334 @@
+// app/src/views/admin/ManageAnalysisReleases.spec.ts
+//
+// Component tests for the Administrator analysis-snapshot-release page
+// (#573 Slice B, Task B4b). Mocks the typed admin client
+// (`@/api/admin_analysis_release`) directly so these exercise the real
+// composable + view wiring end-to-end (mirrors DataReleases.spec.ts).
+//
+// `GenericTable` is stubbed with a tiny hand-rolled template that forwards
+// the same slot names/props the real `GenericDesktopTable`/BTable wiring
+// exposes (`cell-status`, `cell-actions` with `expansion-showing`/
+// `toggle-expansion`, `row-expansion` with `toggle`) — the same technique
+// `ApprovalTableView.spec.ts`/`PubtatorNDDGenes.spec.ts` use to test
+// row-expansion consumers deterministically without depending on
+// BootstrapVueNext's internal BTable expansion implementation.
+
+import { mount, flushPromises } from '@vue/test-utils';
+import { defineComponent } from 'vue';
+import { describe, expect, it, vi, beforeEach } from 'vitest';
+import type { AdminReleaseHead, SnapshotStatusResponse } from '@/api/admin_analysis_release';
+
+vi.mock('@unhead/vue', () => ({
+  useHead: vi.fn(),
+}));
+
+const buildReleaseMock = vi.fn();
+const listAdminReleasesMock = vi.fn();
+const publishReleaseMock = vi.fn();
+const recordReleaseDoiMock = vi.fn();
+const deleteDraftReleaseMock = vi.fn();
+const fetchSnapshotStatusMock = vi.fn();
+
+vi.mock('@/api/admin_analysis_release', async () => {
+  const actual = await vi.importActual<typeof import('@/api/admin_analysis_release')>(
+    '@/api/admin_analysis_release'
+  );
+  return {
+    ...actual,
+    buildRelease: (...args: unknown[]) => buildReleaseMock(...args),
+    listAdminReleases: (...args: unknown[]) => listAdminReleasesMock(...args),
+    getAdminRelease: vi.fn(),
+    publishRelease: (...args: unknown[]) => publishReleaseMock(...args),
+    recordReleaseDoi: (...args: unknown[]) => recordReleaseDoiMock(...args),
+    deleteDraftRelease: (...args: unknown[]) => deleteDraftReleaseMock(...args),
+    fetchSnapshotStatus: (...args: unknown[]) => fetchSnapshotStatusMock(...args),
+  };
+});
+
+import ManageAnalysisReleases from './ManageAnalysisReleases.vue';
+
+const GenericTableStub = defineComponent({
+  props: ['items', 'fields', 'isBusy'],
+  data() {
+    return { expanded: {} as Record<string, boolean> };
+  },
+  methods: {
+    toggleRow(id: string) {
+      this.expanded[id] = !this.expanded[id];
+    },
+  },
+  template: `
+    <div data-testid="generic-table-stub">
+      <div v-for="item in items" :key="item.release_id" class="stub-row">
+        <span>{{ item.release_id }}</span>
+        <slot name="cell-status" :row="item" />
+        <slot
+          name="cell-actions"
+          :row="item"
+          :expansion-showing="!!expanded[item.release_id]"
+          :toggle-expansion="() => toggleRow(item.release_id)"
+        />
+        <div v-if="expanded[item.release_id]">
+          <slot name="row-expansion" :row="item" :toggle="() => toggleRow(item.release_id)" />
+        </div>
+      </div>
+    </div>
+  `,
+});
+
+function makeRelease(overrides: Partial<AdminReleaseHead> = {}): AdminReleaseHead {
+  return {
+    release_id: 'asr_abc123',
+    release_version: null,
+    title: 'Test release',
+    status: 'draft',
+    manifest_schema_version: '1.0',
+    content_digest: 'a'.repeat(64),
+    source_data_version: 'v1',
+    db_release_version: null,
+    db_release_commit: null,
+    manifest_sha256: 'b'.repeat(64),
+    bundle_sha256: 'c'.repeat(64),
+    license: 'CC-BY-4.0',
+    file_count: 5,
+    total_bytes: 1024,
+    created_by_user_id: 1,
+    created_at: '2026-07-01T00:00:00Z',
+    published_at: null,
+    updated_at: '2026-07-01T00:00:00Z',
+    zenodo_record_id: null,
+    zenodo_record_url: null,
+    version_doi: null,
+    concept_doi: null,
+    last_error_message: null,
+    ...overrides,
+  };
+}
+
+function makeStatus(states: Record<string, string>): SnapshotStatusResponse {
+  return {
+    presets: Object.entries(states).map(([analysis_type, state]) => ({
+      analysis_type,
+      parameter_hash: 'hash',
+      state: state as SnapshotStatusResponse['presets'][number]['state'],
+      generated_at: null,
+      activated_at: null,
+      stale_after: null,
+      source_data_version: null,
+      row_counts: null,
+    })),
+    summary: { total: 0, available: 0, missing: 0, stale: 0, mismatch: 0 },
+  };
+}
+
+const ALL_AVAILABLE = makeStatus({
+  functional_clusters: 'available',
+  phenotype_clusters: 'available',
+  phenotype_functional_correlations: 'available',
+});
+
+function mountView() {
+  return mount(ManageAnalysisReleases, {
+    global: {
+      stubs: { AdminOperationPanel: false, GenericTable: GenericTableStub },
+    },
+  });
+}
+
+describe('ManageAnalysisReleases.vue', () => {
+  beforeEach(() => {
+    vi.clearAllMocks();
+    listAdminReleasesMock.mockResolvedValue({
+      releases: [],
+      pagination: { limit: 50, offset: 0, count: 0 },
+    });
+    fetchSnapshotStatusMock.mockResolvedValue(
+      makeStatus({
+        functional_clusters: 'missing',
+        phenotype_clusters: 'missing',
+        phenotype_functional_correlations: 'missing',
+      })
+    );
+  });
+
+  it('disables the Build button when a release layer is not available', async () => {
+    const wrapper = mountView();
+    await flushPromises();
+
+    const button = wrapper.find('[data-testid="build-release-btn"]');
+    expect(button.exists()).toBe(true);
+    expect(button.attributes('disabled')).toBeDefined();
+  });
+
+  it('enables the Build button and invokes buildRelease when all three release layers are available', async () => {
+    fetchSnapshotStatusMock.mockResolvedValue(ALL_AVAILABLE);
+    const release = makeRelease({ status: 'draft' });
+    buildReleaseMock.mockResolvedValue({ outcome: 'created', release });
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    const button = wrapper.find('[data-testid="build-release-btn"]');
+    expect(button.attributes('disabled')).toBeUndefined();
+
+    await wrapper.find('form.build-form').trigger('submit');
+    await flushPromises();
+
+    expect(buildReleaseMock).toHaveBeenCalledTimes(1);
+    expect(wrapper.find('[data-testid="build-success"]').exists()).toBe(true);
+  });
+
+  it('shows a distinct retry warning (not a gate error) when the build is locked', async () => {
+    fetchSnapshotStatusMock.mockResolvedValue(ALL_AVAILABLE);
+    buildReleaseMock.mockResolvedValue({
+      outcome: 'locked',
+      retryAfter: 9,
+      message: 'Snapshot sources are refreshing.',
+    });
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    await wrapper.find('form.build-form').trigger('submit');
+    await flushPromises();
+
+    const locked = wrapper.find('[data-testid="build-locked"]');
+    expect(locked.exists()).toBe(true);
+    expect(locked.text()).toContain('retry in 9s');
+    expect(wrapper.find('[data-testid="build-error"]').exists()).toBe(false);
+  });
+
+  it('sets the build error alert (not the locked warning) on a thrown 400 gate failure', async () => {
+    fetchSnapshotStatusMock.mockResolvedValue(ALL_AVAILABLE);
+    buildReleaseMock.mockRejectedValue({
+      response: { data: { detail: 'release_snapshot_not_available: functional_clusters' } },
+    });
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    await wrapper.find('form.build-form').trigger('submit');
+    await flushPromises();
+
+    const errorAlert = wrapper.find('[data-testid="build-error"]');
+    expect(errorAlert.exists()).toBe(true);
+    expect(errorAlert.text()).toContain('release_snapshot_not_available');
+    expect(wrapper.find('[data-testid="build-locked"]').exists()).toBe(false);
+  });
+
+  it('renders a mocked draft row with a Publish action that calls publishRelease', async () => {
+    const release = makeRelease({ release_id: 'asr_draft1', status: 'draft' });
+    listAdminReleasesMock.mockResolvedValue({
+      releases: [release],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+    publishReleaseMock.mockResolvedValue({ ...release, status: 'published' });
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    expect(wrapper.text()).toContain('asr_draft1');
+    const publishBtn = wrapper.find('[data-testid="publish-asr_draft1"]');
+    expect(publishBtn.exists()).toBe(true);
+
+    await publishBtn.trigger('click');
+    await flushPromises();
+
+    expect(publishReleaseMock).toHaveBeenCalledWith('asr_draft1');
+  });
+
+  it('does not render a Publish action for an already-published release', async () => {
+    const release = makeRelease({ release_id: 'asr_pub1', status: 'published' });
+    listAdminReleasesMock.mockResolvedValue({
+      releases: [release],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    expect(wrapper.find('[data-testid="publish-asr_pub1"]').exists()).toBe(false);
+  });
+
+  it('the Record-DOI control calls recordReleaseDoi with only the filled fields', async () => {
+    const release = makeRelease({ release_id: 'asr_doi1', status: 'published' });
+    listAdminReleasesMock.mockResolvedValue({
+      releases: [release],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+    recordReleaseDoiMock.mockResolvedValue({ ...release, version_doi: '10.5281/zenodo.99' });
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    await wrapper.find('[data-testid="toggle-doi-asr_doi1"]').trigger('click');
+    await flushPromises();
+
+    const versionInput = wrapper.find('[data-testid="doi-version-input-asr_doi1"]');
+    expect(versionInput.exists()).toBe(true);
+    await versionInput.setValue('10.5281/zenodo.99');
+
+    await wrapper.find('[data-testid="save-doi-asr_doi1"]').trigger('click');
+    await flushPromises();
+
+    expect(recordReleaseDoiMock).toHaveBeenCalledWith('asr_doi1', {
+      version_doi: '10.5281/zenodo.99',
+    });
+  });
+
+  it('surfaces a failed Publish action error co-located in the Releases panel, not the readiness panel', async () => {
+    const release = makeRelease({ release_id: 'asr_fail1', status: 'draft' });
+    listAdminReleasesMock.mockResolvedValue({
+      releases: [release],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+    publishReleaseMock.mockRejectedValue({
+      response: { data: { detail: 'release not found' } },
+    });
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    await wrapper.find('[data-testid="publish-asr_fail1"]').trigger('click');
+    await flushPromises();
+
+    const panels = wrapper.findAll('[data-testid="admin-operation-panel"]');
+    expect(panels).toHaveLength(3);
+    const [readinessPanel, , releasesPanel] = panels;
+
+    const errorInReleasesPanel = releasesPanel.find('[data-testid="action-error"]');
+    expect(errorInReleasesPanel.exists()).toBe(true);
+    expect(errorInReleasesPanel.text()).toContain('release not found');
+
+    // The regression this guards: actionError used to render in the
+    // Snapshot-readiness panel, far from the row action that triggered it.
+    expect(readinessPanel.find('[data-testid="action-error"]').exists()).toBe(false);
+  });
+
+  it('deletes a draft only after the two-step in-page confirm, never via a blocking dialog', async () => {
+    const confirmSpy = vi.spyOn(window, 'confirm');
+    const release = makeRelease({ release_id: 'asr_draft2', status: 'draft' });
+    listAdminReleasesMock.mockResolvedValue({
+      releases: [release],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+    deleteDraftReleaseMock.mockResolvedValue(undefined);
+
+    const wrapper = mountView();
+    await flushPromises();
+
+    expect(wrapper.find('[data-testid="confirm-delete-asr_draft2"]').exists()).toBe(false);
+
+    await wrapper.find('[data-testid="delete-asr_draft2"]').trigger('click');
+    await flushPromises();
+
+    expect(deleteDraftReleaseMock).not.toHaveBeenCalled();
+    expect(confirmSpy).not.toHaveBeenCalled();
+
+    await wrapper.find('[data-testid="confirm-delete-asr_draft2"]').trigger('click');
+    await flushPromises();
+
+    expect(deleteDraftReleaseMock).toHaveBeenCalledWith('asr_draft2');
+    expect(confirmSpy).not.toHaveBeenCalled();
+  });
+});
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
diff --git a/app/src/views/admin/useAnalysisReleaseAdmin.spec.ts b/app/src/views/admin/useAnalysisReleaseAdmin.spec.ts
new file mode 100644
index 00000000..0a41e7c6
--- /dev/null
+++ b/app/src/views/admin/useAnalysisReleaseAdmin.spec.ts
@@ -0,0 +1,349 @@
+// app/src/views/admin/useAnalysisReleaseAdmin.spec.ts
+//
+// Unit tests for the ManageAnalysisReleases composable (#573 Slice B, Task
+// B4b). Mocks the typed admin client (Task B4a) entirely so these assert
+// composable behavior only: the `canBuild` release-layer gate, the
+// discriminated build outcome handling (created/exists/locked/400-throw),
+// and that publish/recordDoi/deleteDraft forward the right arguments.
+
+import { describe, expect, it, vi, beforeEach } from 'vitest';
+import type {
+  AdminReleaseHead,
+  SnapshotStatusResponse,
+} from '@/api/admin_analysis_release';
+
+vi.mock('@/api/admin_analysis_release', async () => {
+  const actual = await vi.importActual<typeof import('@/api/admin_analysis_release')>(
+    '@/api/admin_analysis_release'
+  );
+  return {
+    ...actual,
+    buildRelease: vi.fn(),
+    listAdminReleases: vi.fn(),
+    getAdminRelease: vi.fn(),
+    publishRelease: vi.fn(),
+    recordReleaseDoi: vi.fn(),
+    deleteDraftRelease: vi.fn(),
+    fetchSnapshotStatus: vi.fn(),
+  };
+});
+
+import {
+  buildRelease,
+  listAdminReleases,
+  publishRelease,
+  recordReleaseDoi,
+  deleteDraftRelease,
+  fetchSnapshotStatus,
+} from '@/api/admin_analysis_release';
+import { useAnalysisReleaseAdmin } from './useAnalysisReleaseAdmin';
+
+function makeRelease(overrides: Partial<AdminReleaseHead> = {}): AdminReleaseHead {
+  return {
+    release_id: 'asr_abc123',
+    release_version: null,
+    title: 'Test release',
+    status: 'draft',
+    manifest_schema_version: '1.0',
+    content_digest: 'a'.repeat(64),
+    source_data_version: 'v1',
+    db_release_version: null,
+    db_release_commit: null,
+    manifest_sha256: 'b'.repeat(64),
+    bundle_sha256: 'c'.repeat(64),
+    license: 'CC-BY-4.0',
+    file_count: 5,
+    total_bytes: 1024,
+    created_by_user_id: 1,
+    created_at: '2026-07-01T00:00:00Z',
+    published_at: null,
+    updated_at: '2026-07-01T00:00:00Z',
+    zenodo_record_id: null,
+    zenodo_record_url: null,
+    version_doi: null,
+    concept_doi: null,
+    last_error_message: null,
+    ...overrides,
+  };
+}
+
+function makeStatus(states: Record<string, string>): SnapshotStatusResponse {
+  return {
+    presets: Object.entries(states).map(([analysis_type, state]) => ({
+      analysis_type,
+      parameter_hash: 'hash',
+      state: state as SnapshotStatusResponse['presets'][number]['state'],
+      generated_at: null,
+      activated_at: null,
+      stale_after: null,
+      source_data_version: null,
+      row_counts: null,
+    })),
+    summary: { total: 0, available: 0, missing: 0, stale: 0, mismatch: 0 },
+  };
+}
+
+const ALL_AVAILABLE = makeStatus({
+  functional_clusters: 'available',
+  phenotype_clusters: 'available',
+  phenotype_functional_correlations: 'available',
+  phenotype_correlations: 'missing',
+  gene_network_edges: 'missing',
+});
+
+describe('useAnalysisReleaseAdmin', () => {
+  beforeEach(() => {
+    vi.clearAllMocks();
+  });
+
+  describe('canBuild', () => {
+    it('is false while status has not loaded', () => {
+      const admin = useAnalysisReleaseAdmin();
+      expect(admin.canBuild.value).toBe(false);
+    });
+
+    it('is false when a release layer is not available', async () => {
+      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(
+        makeStatus({
+          functional_clusters: 'available',
+          phenotype_clusters: 'stale',
+          phenotype_functional_correlations: 'available',
+        })
+      );
+      const admin = useAnalysisReleaseAdmin();
+      await admin.loadStatus();
+      expect(admin.canBuild.value).toBe(false);
+    });
+
+    it('is true when all three release layers are available, ignoring non-release presets', async () => {
+      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(ALL_AVAILABLE);
+      const admin = useAnalysisReleaseAdmin();
+      await admin.loadStatus();
+      expect(admin.canBuild.value).toBe(true);
+    });
+
+    it('is false when a release layer preset is entirely absent from the response', async () => {
+      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(
+        makeStatus({
+          functional_clusters: 'available',
+          phenotype_clusters: 'available',
+        })
+      );
+      const admin = useAnalysisReleaseAdmin();
+      await admin.loadStatus();
+      expect(admin.canBuild.value).toBe(false);
+    });
+  });
+
+  describe('layerReadiness', () => {
+    it('reports the three release-layer states, "missing" when absent', async () => {
+      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(
+        makeStatus({ functional_clusters: 'available' })
+      );
+      const admin = useAnalysisReleaseAdmin();
+      await admin.loadStatus();
+      const byType = Object.fromEntries(
+        admin.layerReadiness.value.map((item) => [item.analysis_type, item.state])
+      );
+      expect(byType.functional_clusters).toBe('available');
+      expect(byType.phenotype_clusters).toBe('missing');
+      expect(byType.phenotype_functional_correlations).toBe('missing');
+    });
+  });
+
+  describe('build', () => {
+    it('sets lastBuildOutcome and reloads releases on a created outcome', async () => {
+      const release = makeRelease({ status: 'draft' });
+      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
+        outcome: 'created',
+        release,
+      });
+      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
+        releases: [release],
+        pagination: { limit: 50, offset: 0, count: 1 },
+      });
+
+      const admin = useAnalysisReleaseAdmin();
+      await admin.build({ title: 'My release', publish: false });
+
+      expect(admin.lastBuildOutcome.value).toEqual({ outcome: 'created', release });
+      expect(admin.buildError.value).toBeNull();
+      expect(listAdminReleases).toHaveBeenCalledTimes(1);
+      expect(admin.releases.value).toEqual([release]);
+    });
+
+    it('reloads releases on an exists outcome too', async () => {
+      const release = makeRelease({ status: 'published' });
+      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
+        outcome: 'exists',
+        release,
+      });
+      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
+        releases: [release],
+        pagination: { limit: 50, offset: 0, count: 1 },
+      });
+
+      const admin = useAnalysisReleaseAdmin();
+      await admin.build({});
+
+      expect(admin.lastBuildOutcome.value?.outcome).toBe('exists');
+      expect(listAdminReleases).toHaveBeenCalledTimes(1);
+    });
+
+    it('sets a locked outcome with retryAfter and does NOT set buildError or reload', async () => {
+      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
+        outcome: 'locked',
+        retryAfter: 7,
+        message: 'Snapshot sources are refreshing.',
+      });
+
+      const admin = useAnalysisReleaseAdmin();
+      await admin.build({});
+
+      expect(admin.lastBuildOutcome.value).toEqual({
+        outcome: 'locked',
+        retryAfter: 7,
+        message: 'Snapshot sources are refreshing.',
+      });
+      expect(admin.buildError.value).toBeNull();
+      expect(listAdminReleases).not.toHaveBeenCalled();
+    });
+
+    it('sets buildError to the extracted message on a thrown 400 gate failure', async () => {
+      (buildRelease as ReturnType<typeof vi.fn>).mockRejectedValue({
+        response: { data: { detail: 'release_snapshot_not_available: functional_clusters' } },
+      });
+
+      const admin = useAnalysisReleaseAdmin();
+      await admin.build({});
+
+      expect(admin.buildError.value).toBe(
+        'release_snapshot_not_available: functional_clusters'
+      );
+      expect(admin.lastBuildOutcome.value).toBeNull();
+    });
+
+    it('omits a blank license so the server default ("CC-BY-4.0") applies, but forwards a non-empty license as-is', async () => {
+      const release = makeRelease();
+      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
+        outcome: 'created',
+        release,
+      });
+      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
+        releases: [release],
+        pagination: { limit: 50, offset: 0, count: 1 },
+      });
+
+      const admin = useAnalysisReleaseAdmin();
+
+      await admin.build({ title: 'Blank license', license: '   ', publish: false });
+      const blankLicensePayload = (buildRelease as ReturnType<typeof vi.fn>).mock.calls[0][0];
+      expect(blankLicensePayload).not.toHaveProperty('license');
+
+      await admin.build({ title: 'Explicit license', license: 'MIT', publish: false });
+      const explicitLicensePayload = (buildRelease as ReturnType<typeof vi.fn>).mock.calls[1][0];
+      expect(explicitLicensePayload.license).toBe('MIT');
+    });
+
+    it('clears a prior buildError when a new build call starts', async () => {
+      (buildRelease as ReturnType<typeof vi.fn>).mockRejectedValueOnce({
+        response: { data: { detail: 'first failure' } },
+      });
+      const admin = useAnalysisReleaseAdmin();
+      await admin.build({});
+      expect(admin.buildError.value).toBe('first failure');
+
+      const release = makeRelease();
+      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
+        outcome: 'created',
+        release,
+      });
+      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
+        releases: [release],
+        pagination: { limit: 50, offset: 0, count: 1 },
+      });
+      await admin.build({});
+      expect(admin.buildError.value).toBeNull();
+    });
+  });
+
+  describe('publish / recordDoi / deleteDraft', () => {
+    it('publish calls publishRelease with the release id and reloads', async () => {
+      const release = makeRelease({ status: 'published' });
+      (publishRelease as ReturnType<typeof vi.fn>).mockResolvedValue(release);
+      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
+        releases: [release],
+        pagination: { limit: 50, offset: 0, count: 1 },
+      });
+
+      const admin = useAnalysisReleaseAdmin();
+      await admin.publish('asr_abc123');
+
+      expect(publishRelease).toHaveBeenCalledWith('asr_abc123');
+      expect(listAdminReleases).toHaveBeenCalledTimes(1);
+    });
+
+    it('publish surfaces the extracted error message on failure', async () => {
+      (publishRelease as ReturnType<typeof vi.fn>).mockRejectedValue({
+        response: { data: { detail: 'release not found' } },
+      });
+      const admin = useAnalysisReleaseAdmin();
+      await admin.publish('asr_missing');
+      expect(admin.actionError.value).toBe('release not found');
+    });
+
+    it('recordDoi calls recordReleaseDoi with only the filled fields', async () => {
+      const release = makeRelease({ version_doi: '10.5281/zenodo.1' });
+      (recordReleaseDoi as ReturnType<typeof vi.fn>).mockResolvedValue(release);
+      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
+        releases: [release],
+        pagination: { limit: 50, offset: 0, count: 1 },
+      });
+
+      const admin = useAnalysisReleaseAdmin();
+      await admin.recordDoi('asr_abc123', {
+        version_doi: '10.5281/zenodo.1',
+        concept_doi: '',
+        zenodo_record_id: undefined,
+        zenodo_record_url: '',
+      });
+
+      expect(recordReleaseDoi).toHaveBeenCalledWith('asr_abc123', {
+        version_doi: '10.5281/zenodo.1',
+      });
+    });
+
+    it('deleteDraft calls deleteDraftRelease with the release id and reloads', async () => {
+      (deleteDraftRelease as ReturnType<typeof vi.fn>).mockResolvedValue(undefined);
+      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
+        releases: [],
+        pagination: { limit: 50, offset: 0, count: 0 },
+      });
+
+      const admin = useAnalysisReleaseAdmin();
+      await admin.deleteDraft('asr_draft1');
+
+      expect(deleteDraftRelease).toHaveBeenCalledWith('asr_draft1');
+      expect(listAdminReleases).toHaveBeenCalledTimes(1);
+    });
+  });
+
+  describe('refreshAll', () => {
+    it('loads both releases and status, toggling loading', async () => {
+      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
+        releases: [makeRelease()],
+        pagination: { limit: 50, offset: 0, count: 1 },
+      });
+      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(ALL_AVAILABLE);
+
+      const admin = useAnalysisReleaseAdmin();
+      expect(admin.loading.value).toBe(false);
+      const promise = admin.refreshAll();
+      expect(admin.loading.value).toBe(true);
+      await promise;
+      expect(admin.loading.value).toBe(false);
+      expect(admin.releases.value).toHaveLength(1);
+      expect(admin.canBuild.value).toBe(true);
+    });
+  });
+});
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
diff --git a/app/src/views/analyses/DataReleases.spec.ts b/app/src/views/analyses/DataReleases.spec.ts
new file mode 100644
index 00000000..b164668b
--- /dev/null
+++ b/app/src/views/analyses/DataReleases.spec.ts
@@ -0,0 +1,167 @@
+import { mount, flushPromises } from '@vue/test-utils';
+import { describe, expect, it, vi, beforeEach } from 'vitest';
+import type { ReleaseDetail, ReleaseHead } from '@/api/analysis_releases';
+
+vi.mock('@unhead/vue', () => ({
+  useHead: vi.fn(),
+}));
+
+vi.mock('@/composables/useToast', () => ({
+  default: () => ({ makeToast: vi.fn() }),
+}));
+
+const listReleasesMock = vi.fn();
+const getLatestReleaseMock = vi.fn();
+const getReleaseMock = vi.fn();
+const downloadReleaseBundleMock = vi.fn();
+const downloadReleaseManifestMock = vi.fn();
+const downloadReleaseFileMock = vi.fn();
+
+vi.mock('@/api/analysis', () => ({
+  listReleases: (...args: unknown[]) => listReleasesMock(...args),
+  getLatestRelease: (...args: unknown[]) => getLatestReleaseMock(...args),
+  getRelease: (...args: unknown[]) => getReleaseMock(...args),
+  downloadReleaseBundle: (...args: unknown[]) => downloadReleaseBundleMock(...args),
+  downloadReleaseManifest: (...args: unknown[]) => downloadReleaseManifestMock(...args),
+  downloadReleaseFile: (...args: unknown[]) => downloadReleaseFileMock(...args),
+}));
+
+import DataReleases from './DataReleases.vue';
+
+function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
+  return {
+    release_id: 'asr_0123456789abcdef',
+    release_version: null,
+    title: 'SysNDD analysis-snapshot release',
+    status: 'published',
+    content_digest: 'a'.repeat(64),
+    created_at: '2026-07-01T00:00:00Z',
+    published_at: '2026-07-01T00:05:00Z',
+    source_data_version: '2026-07-01',
+    db_release_version: '11.4.0',
+    db_release_commit: 'deadbeef',
+    manifest_sha256: 'b'.repeat(64),
+    bundle_sha256: 'c'.repeat(64),
+    license: 'CC-BY-4.0',
+    file_count: 1,
+    total_bytes: 1258291,
+    zenodo: { record_url: null, version_doi: null, concept_doi: null },
+    ...overrides,
+  };
+}
+
+function makeReleaseDetail(overrides: Partial<ReleaseHead> = {}): ReleaseDetail {
+  return {
+    ...makeReleaseHead(overrides),
+    manifest: {
+      release_id: 'asr_0123456789abcdef',
+      release_version: null,
+      title: 'SysNDD analysis-snapshot release',
+      created_at: '2026-07-01T00:00:00Z',
+      license: 'CC-BY-4.0',
+      scope_statement: 'Public derived analysis only.',
+      generator: 'sysndd-api',
+      source: 'sysndd',
+      layers: [
+        {
+          analysis_type: 'functional_clusters',
+          parameter_hash: 'fp-hash',
+          snapshot_id: 101,
+          input_hash: 'in-func',
+          payload_hash: 'pay-func',
+          schema_version: '1.2',
+          reproducibility_hash: 'repro-func',
+          dependencies: null,
+        },
+      ],
+      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
+      content_digest: 'a'.repeat(64),
+    },
+  };
+}
+
+function notFoundError() {
+  return Object.assign(new Error('Not found'), {
+    isAxiosError: true,
+    response: { status: 404, data: { message: 'No published analysis-snapshot release exists yet' } },
+  });
+}
+
+describe('DataReleases', () => {
+  beforeEach(() => {
+    vi.clearAllMocks();
+    // jsdom has no real object-URL / anchor-download support.
+    window.URL.createObjectURL = vi.fn(() => 'blob:mock-url');
+    window.URL.revokeObjectURL = vi.fn();
+  });
+
+  it('renders the release table row and the manifest panel for the latest release', async () => {
+    listReleasesMock.mockResolvedValue({
+      releases: [makeReleaseHead()],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
+
+    const wrapper = mount(DataReleases);
+    await flushPromises();
+
+    expect(listReleasesMock).toHaveBeenCalled();
+    expect(getLatestReleaseMock).toHaveBeenCalled();
+    const text = wrapper.text();
+    expect(text).toContain('asr_0123456789abcdef');
+    expect(text).toContain('Integrity hashes');
+    expect(text).toContain('a'.repeat(64));
+  });
+
+  it('re-fetches the detail for a different release when its "View manifest" button is clicked', async () => {
+    listReleasesMock.mockResolvedValue({
+      releases: [makeReleaseHead({ release_id: 'asr_other' })],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
+    getReleaseMock.mockResolvedValue(makeReleaseDetail({ release_id: 'asr_other' }));
+
+    const wrapper = mount(DataReleases);
+    await flushPromises();
+
+    const button = wrapper
+      .findAll('button')
+      .find((btn) => btn.text().includes('View manifest'));
+    expect(button).toBeTruthy();
+    await button!.trigger('click');
+    await flushPromises();
+
+    expect(getReleaseMock).toHaveBeenCalledWith('asr_other');
+  });
+
+  it('downloads the bundle when the download-bundle button is clicked', async () => {
+    listReleasesMock.mockResolvedValue({
+      releases: [makeReleaseHead()],
+      pagination: { limit: 50, offset: 0, count: 1 },
+    });
+    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
+    downloadReleaseBundleMock.mockResolvedValue(new Blob(['bundle-bytes']));
+
+    const wrapper = mount(DataReleases);
+    await flushPromises();
+
+    await wrapper.find('[data-testid="download-bundle-button"]').trigger('click');
+    await flushPromises();
+
+    expect(downloadReleaseBundleMock).toHaveBeenCalledWith('asr_0123456789abcdef');
+  });
+
+  it('shows the "No releases published yet" empty state on a 404 from getLatestRelease, not a raw error', async () => {
+    listReleasesMock.mockResolvedValue({
+      releases: [],
+      pagination: { limit: 50, offset: 0, count: 0 },
+    });
+    getLatestReleaseMock.mockRejectedValue(notFoundError());
+
+    const wrapper = mount(DataReleases);
+    await flushPromises();
+
+    expect(wrapper.text()).toContain('No releases published yet');
+    expect(wrapper.find('[data-testid="section-card-error"]').exists()).toBe(false);
+  });
+});
diff --git a/app/src/views/analyses/DataReleases.vue b/app/src/views/analyses/DataReleases.vue
new file mode 100644
index 00000000..fca7b433
--- /dev/null
+++ b/app/src/views/analyses/DataReleases.vue
@@ -0,0 +1,361 @@
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
+  detailLoading.value = true;
+  detailError.value = null;
+  try {
+    selectedRelease.value = await fetcher();
+  } catch (err) {
+    selectedRelease.value = null;
+    if (!(isApiError(err) && err.response?.status === 404)) {
+      detailError.value = extractApiErrorMessage(err, 'Failed to load the release manifest.');
+    }
+  } finally {
+    detailLoading.value = false;
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

exec
/bin/bash -lc "nl -ba app/src/api/analysis_releases.ts | sed -n '1,360p'
nl -ba app/src/api/admin_analysis_release.ts | sed -n '1,400p'
nl -ba api/endpoints/analysis_endpoints.R | sed -n '1,360p'
nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '1,360p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
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
   130	 * The release `manifest.json` shape, built by
   131	 * `analysis_release_build_manifest()` (api/functions/analysis-snapshot-release-manifest.R).
   132	 * Present on the detail (`GET /releases/<id>`) and `latest` routes only —
   133	 * NOT on the list route, which carries the lighter `layers` array on each
   134	 * head instead.
   135	 */
   136	export interface ReleaseManifest {
   137	  release_id: string;
   138	  /** Reserved, currently-unpopulated string column — always `null` today (see `ReleaseHead.release_version`). */
   139	  release_version: string | null;
   140	  title: string | null;
   141	  created_at: string;
   142	  license: string;
   143	  scope_statement: string;
   144	  generator: string;
   145	  source: string;
   146	  layers: ReleaseManifestLayer[];
   147	  files: ReleaseManifestFile[];
   148	  content_digest: string;
   149	}
   150
   151	/** `GET /releases/<id>` and `GET /releases/latest`: head + parsed manifest. */
   152	export interface ReleaseDetail extends ReleaseHead {
   153	  manifest: ReleaseManifest;
   154	}
   155
   156	export interface ListReleasesParams {
   157	  limit?: number;
   158	  offset?: number;
   159	}
   160
   161	export interface ListReleasesResponse {
   162	  releases: ReleaseHead[];
   163	  pagination: {
   164	    limit: number;
   165	    offset: number;
   166	    count: number;
   167	  };
   168	}
   169
   170	// ---------------------------------------------------------------------------
   171	// Helpers
   172	// ---------------------------------------------------------------------------
   173
   174	/**
   175	 * GET /api/analysis/releases
   176	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases`).
   177	 *
   178	 * Public, unauthenticated. Lists published analysis-snapshot releases
   179	 * (newest first). `pagination` echoes the CLAMPED effective `limit`/`offset`
   180	 * the service actually queried, not necessarily the caller's raw values.
   181	 */
   182	export async function listReleases(
   183	  params: ListReleasesParams = {},
   184	  config?: AxiosRequestConfig
   185	): Promise<ListReleasesResponse> {
   186	  return apiClient.get<ListReleasesResponse>('/api/analysis/releases', {
   187	    ...config,
   188	    params: { ...(config?.params as object | undefined), ...params },
   189	  });
   190	}
   191
   192	/**
   193	 * GET /api/analysis/releases/latest
   194	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/latest`).
   195	 *
   196	 * Public, unauthenticated. Returns the newest published release's head +
   197	 * manifest (same shape as the detail route).
   198	 *
   199	 * Throws AxiosError 404 when no published release exists yet.
   200	 */
   201	export async function getLatestRelease(config?: AxiosRequestConfig): Promise<ReleaseDetail> {
   202	  return apiClient.get<ReleaseDetail>('/api/analysis/releases/latest', config);
   203	}
   204
   205	/**
   206	 * GET /api/analysis/releases/<release_id>
   207	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>`).
   208	 *
   209	 * Public, unauthenticated. Returns the release head + manifest. An unknown
   210	 * id and a draft id are indistinguishable — both 404 (drafts are never
   211	 * public).
   212	 */
   213	export async function getRelease(
   214	  releaseId: string,
   215	  config?: AxiosRequestConfig
   216	): Promise<ReleaseDetail> {
   217	  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}`;
   218	  return apiClient.get<ReleaseDetail>(path, config);
   219	}
   220
   221	/**
   222	 * GET /api/analysis/releases/<release_id>/manifest.json
   223	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/manifest.json`).
   224	 *
   225	 * Public, unauthenticated. Returns the EXACT stored `manifest.json` bytes
   226	 * verbatim (never re-serialized), so `sha256(bytes) == manifest_sha256` on
   227	 * the release head. Returned as a `Blob` (the R handler uses `@serializer
   228	 * octet application/json`).
   229	 */
   230	export async function downloadReleaseManifest(
   231	  releaseId: string,
   232	  config?: AxiosRequestConfig
   233	): Promise<Blob> {
   234	  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}/manifest.json`;
   235	  const response = await apiClient.raw.get<Blob>(path, {
   236	    ...config,
   237	    responseType: 'blob',
   238	  });
   239	  return response.data;
   240	}
   241
   242	/**
   243	 * GET /api/analysis/releases/<release_id>/file?path=<file_path>
   244	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/file`).
   245	 *
   246	 * Public, unauthenticated. `path` is a QUERY param, not a URL path segment —
   247	 * Plumber 1.3.2 has no `<path:.*>` wildcard, so a nested archive path (e.g.
   248	 * `functional_clusters/payload.json`) cannot be expressed as a path segment.
   249	 * Resolved by an exact `(release_id, file_path)` primary-key lookup; an
   250	 * unknown path is a 404 (there is no filesystem access, so no path-traversal
   251	 * surface). Returned as a `Blob`.
   252	 */
   253	export async function downloadReleaseFile(
   254	  releaseId: string,
   255	  path: string,
   256	  config?: AxiosRequestConfig
   257	): Promise<Blob> {
   258	  const url = `/api/analysis/releases/${encodeURIComponent(releaseId)}/file`;
   259	  const response = await apiClient.raw.get<Blob>(url, {
   260	    ...config,
   261	    params: { ...(config?.params as object | undefined), path },
   262	    responseType: 'blob',
   263	  });
   264	  return response.data;
   265	}
   266
   267	/**
   268	 * GET /api/analysis/releases/<release_id>/bundle
   269	 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/bundle`).
   270	 *
   271	 * Public, unauthenticated. Returns the release's pre-built `bundle.tar.gz`
   272	 * verbatim (the R handler uses `@serializer octet application/gzip` and sets
   273	 * `Content-Disposition: attachment`). Returned as a `Blob`.
   274	 */
   275	export async function downloadReleaseBundle(
   276	  releaseId: string,
   277	  config?: AxiosRequestConfig
   278	): Promise<Blob> {
   279	  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}/bundle`;
   280	  const response = await apiClient.raw.get<Blob>(path, {
   281	    ...config,
   282	    responseType: 'blob',
   283	  });
   284	  return response.data;
   285	}
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
     1	# api/endpoints/analysis_endpoints.R
     2	#
     3	# This file contains all Analysis-related endpoints, extracted from the
     4	# original sysndd_plumber.R. It follows the Google R Style Guide conventions
     5	# where possible (e.g., two-space indentation, meaningful function names, etc.).
     6	#
     7	# Be sure to source any required helper files at the top (e.g.,
     8	# source("functions/database-functions.R", local = TRUE)) if needed.
     9	#
    10	# Note: For long-running operations, consider using async endpoints:
    11	#   POST /api/jobs/clustering/submit - Async functional clustering
    12	#   POST /api/jobs/phenotype_clustering/submit - Async phenotype clustering
    13	#   GET /api/jobs/<job_id>/status - Poll job status
    14
    15	## -------------------------------------------------------------------##
    16	## Analyses endpoints
    17	## -------------------------------------------------------------------##
    18
    19	analysis_snapshot_endpoint_response <- function(snapshot_result, res) {
    20	  if (!is.null(snapshot_result$status) && snapshot_result$status >= 400L) {
    21	    res$status <- snapshot_result$status
    22	    if (!is.null(snapshot_result$retry_after)) {
    23	      res$setHeader("Retry-After", as.character(snapshot_result$retry_after))
    24	    }
    25	    return(snapshot_result$body)
    26	  }
    27
    28	  snapshot_result$body
    29	}
    30
    31	analysis_endpoint_scalar <- function(value, default = NULL) {
    32	  if (is.null(value) || length(value) == 0L) {
    33	    return(default)
    34	  }
    35	  value[[1]]
    36	}
    37
    38	analysis_paginate_snapshot_clusters <- function(body, page_after_clean, page_size_int, res = NULL) {
    39	  clusters <- tibble::as_tibble(body$clusters %||% tibble::tibble())
    40	  if (nrow(clusters) == 0L) {
    41	    body$clusters <- clusters
    42	    body$pagination <- list(
    43	      page_size = page_size_int,
    44	      page_after = page_after_clean,
    45	      next_cursor = NULL,
    46	      total_count = 0L,
    47	      has_more = FALSE
    48	    )
    49	    return(body)
    50	  }
    51
    52	  required_columns <- c("cluster", "hash_filter")
    53	  missing_columns <- setdiff(required_columns, names(clusters))
    54	  if (length(missing_columns) > 0L) {
    55	    if (!is.null(res)) {
    56	      res$status <- 500L
    57	    }
    58	    return(list(
    59	      code = "snapshot_payload_invalid",
    60	      message = "Functional cluster snapshot payload is missing required pagination fields.",
    61	      details = list(missing_columns = missing_columns)
    62	    ))
    63	  }
    64
    65	  clusters_sorted <- clusters %>%
    66	    dplyr::arrange(cluster) %>%
    67	    dplyr::mutate(row_num = dplyr::row_number())
    68
    69	  if (page_after_clean == "") {
    70	    start_idx <- 1L
    71	  } else {
    72	    cursor_pos <- which(clusters_sorted$hash_filter == page_after_clean)
    73	    start_idx <- if (length(cursor_pos) > 0L) cursor_pos[[1]] + 1L else 1L
    74	  }
    75
    76	  if (start_idx > nrow(clusters_sorted)) {
    77	    body$clusters <- clusters_sorted[0L, setdiff(names(clusters_sorted), "row_num"), drop = FALSE]
    78	    body$pagination <- list(
    79	      page_size = page_size_int,
    80	      page_after = page_after_clean,
    81	      next_cursor = NULL,
    82	      total_count = nrow(clusters_sorted),
    83	      has_more = FALSE
    84	    )
    85	    return(body)
    86	  }
    87
    88	  end_idx <- min(start_idx + page_size_int - 1L, nrow(clusters_sorted))
    89	  clusters_page <- clusters_sorted %>%
    90	    dplyr::slice(start_idx:end_idx) %>%
    91	    dplyr::select(-row_num)
    92
    93	  next_cursor <- if (end_idx < nrow(clusters_sorted)) {
    94	    clusters_page %>%
    95	      dplyr::slice(dplyr::n()) %>%
    96	      dplyr::pull(hash_filter)
    97	  } else {
    98	    NULL
    99	  }
   100
   101	  body$clusters <- clusters_page
   102	  body$pagination <- list(
   103	    page_size = page_size_int,
   104	    page_after = page_after_clean,
   105	    next_cursor = next_cursor,
   106	    total_count = nrow(clusters_sorted),
   107	    has_more = !is.null(next_cursor)
   108	  )
   109	  body
   110	}
   111
   112	#* Retrieve Functional Clustering Data with Pagination
   113	#*
   114	#* This endpoint fetches functional clustering data for genes with NDD phenotype.
   115	#* Results are paginated to reduce response size and improve performance.
   116	#*
   117	#* # `Details`
   118	#* - Returns clusters sorted by cluster number for stable pagination
   119	#* - Use `page_after` cursor to fetch subsequent pages
   120	#* - Default page size is 10 clusters, maximum is 50
   121	#* - Categories are returned in full (small dataset, not paginated)
   122	#*
   123	#* # `Pagination`
   124	#* - First page: omit `page_after` or pass empty string
   125	#* - Next page: use `next_cursor` from previous response as `page_after`
   126	#* - Last page: `has_more` will be `false` and `next_cursor` will be `null`
   127	#*
   128	#* # `Return`
   129	#* Returns categories, paginated clusters, and pagination metadata.
   130	#*
   131	#* @tag analysis
   132	#* @serializer json list(na="string")
   133	#* @param page_after:str Cursor for pagination (hash_filter of last item, empty for first page)
   134	#* @param page_size:str Number of clusters per page (default "10", max "50")
   135	#* @param algorithm:str Supported public preset algorithm: "leiden" (default)
   136	#*
   137	#* @response 200 OK. Returns object with:
   138	#*   - categories: Full list of enrichment categories with links
   139	#*   - clusters: Array of cluster objects (paginated)
   140	#*   - pagination: {page_size, page_after, next_cursor, total_count, has_more}
   141	#*   - meta: {algorithm, cache_hit}
   142	#*
   143	#* @get functional_clustering
   144	function(page_after = "", page_size = "10", algorithm = "leiden", res) {
   145	  # NOTE: Backward compatibility
   146	  # - Clients not using pagination get first 10 clusters (was all clusters)
   147	  # - To get all clusters, iterate using next_cursor until has_more=false
   148	  # - Categories still returned in full (not paginated)
   149
   150	  # Validate and parse pagination parameters
   151	  n <- suppressWarnings(as.integer(page_size))
   152	  if (is.na(n)) n <- 10L
   153	  page_size_int <- min(max(n, 1L), 50L)
   154	  page_after_clean <- if (is.null(page_after) || page_after == "") "" else page_after
   155
   156	  algorithm_clean <- tolower(as.character(analysis_endpoint_scalar(algorithm, "leiden")))
   157
   158	  snapshot_result <- service_analysis_snapshot_read(
   159	    "functional_clusters",
   160	    list(algorithm = algorithm_clean)
   161	  )
   162	  body <- analysis_snapshot_endpoint_response(snapshot_result, res)
   163	  if (!is.null(snapshot_result$status) && snapshot_result$status >= 400L) {
   164	    return(body)
   165	  }
   166
   167	  analysis_paginate_snapshot_clusters(body, page_after_clean, page_size_int, res = res)
   168	}
   169
   170
   171	#* Retrieve Phenotype Clustering Data
   172	#*
   173	#* This endpoint fetches data clusters of entities based on phenotypes
   174	#* using Multiple Correspondence Analysis (MCA) and Hierarchical Clustering.
   175	#*
   176	#* # `Details`
   177	#* Retrieves phenotype-based clusters of entities.
   178	#*
   179	#* # `Return`
   180	#* Returns a list of entities grouped by phenotype clusters.
   181	#*
   182	#* @tag analysis
   183	#* @serializer json list(na="string")
   184	#*
   185	#* @response 200 OK. Returns phenotype clustering data.
   186	#*
   187	#* @get phenotype_clustering
   188	function(res) {
   189	  snapshot_result <- service_analysis_snapshot_read("phenotype_clusters", list())
   190	  analysis_snapshot_endpoint_response(snapshot_result, res)
   191	}
   192
   193
   194	#* Correlation of Phenotype & Functional Clusters
   195	#*
   196	#* This endpoint calculates the correlation between:
   197	#*   - Phenotype-based clusters (MCA)
   198	#*   - Functional clusters (STRING-db based)
   199	#*   - Optionally, SFARI genes
   200	#*
   201	#* It returns a JSON object containing:
   202	#*   - "correlation_matrix": a matrix of Pearson correlation coefficients
   203	#*   - "correlation_melted": the melted version (x, y, value)
   204	#*
   205	#* @tag analysis
   206	#* @serializer json list(na="string")
   207	#*
   208	#* @response 200 OK. Returns correlation data among clusters.
   209	#*
   210	#* @get phenotype_functional_cluster_correlation
   211	function(res) {
   212	  snapshot_result <- service_analysis_snapshot_read("phenotype_functional_correlations", list())
   213	  analysis_snapshot_endpoint_response(snapshot_result, res)
   214	}
   215
   216
   217	#* Retrieve Network Edges for Cytoscape.js Visualization
   218	#*
   219	#* Returns protein-protein interaction edges from STRINGdb in Cytoscape.js format.
   220	#* Nodes include gene identifiers and cluster membership.
   221	#* Edges include STRING confidence scores.
   222	#*
   223	#* # `Details`
   224	#* - Nodes contain hgnc_id, symbol, cluster assignment, and degree (connection count)
   225	#* - Edges contain source, target (HGNC IDs), and confidence (0-1 normalized)
   226	#* - Metadata includes node_count, edge_count, cluster_count, string_version
   227	#* - Results are read from the fixed public snapshot preset
   228	#*
   229	#* # `Parameters`
   230	#* - cluster_type: "clusters" fixed public preset
   231	#* - min_confidence: "400" fixed public preset
   232	#* - max_edges: "10000" fixed public preset
   233	#*
   234	#* @tag analysis
   235	#* @serializer json list(na="string", auto_unbox=TRUE)
   236	#* @param cluster_type:str Fixed public preset cluster type: "clusters"
   237	#* @param min_confidence:str Fixed public preset STRING confidence: "400"
   238	#* @param max_edges:str Fixed public preset maximum edges: "10000"
   239	#*
   240	#* @response 200 OK. Returns nodes, edges, and metadata
   241	#*
   242	#* @get network_edges
   243	function(cluster_type = "clusters", min_confidence = "400", max_edges = "10000", res) {
   244	  cluster_type_clean <- tolower(as.character(analysis_endpoint_scalar(cluster_type, "clusters")))
   245	  min_confidence_value <- as.character(analysis_endpoint_scalar(min_confidence, "400"))
   246	  max_edges_value <- as.character(analysis_endpoint_scalar(max_edges, "10000"))
   247
   248	  snapshot_result <- service_analysis_snapshot_read(
   249	    "gene_network_edges",
   250	    list(
   251	      cluster_type = cluster_type_clean,
   252	      min_confidence = min_confidence_value,
   253	      max_edges = max_edges_value
   254	    )
   255	  )
   256	  analysis_snapshot_endpoint_response(snapshot_result, res)
   257	}
   258
   259
   260	#* Get LLM Summary for Functional Cluster
   261	#*
   262	#* Retrieves or generates an LLM summary for a functional gene cluster.
   263	#* First checks cache, then generates on-demand if not found.
   264	#*
   265	#* # `Details`
   266	#* - Looks up cached summary by cluster_hash (SHA256 hash of cluster composition)
   267	#* - If not cached, generates new summary via Gemini API
   268	#* - Excludes rejected summaries (validation_status = 'rejected')
   269	#* - Returns summary_json with structured content (summary, key_themes, pathways, etc.)
   270	#*
   271	#* @tag analysis
   272	#* @serializer json list(na="string")
   273	#* @param cluster_hash:str SHA256 hash of cluster composition (or equals(hash,...) format)
   274	#* @param cluster_number:str Cluster number (integer as string)
   275	#*
   276	#* @response 200 OK. Returns summary with metadata
   277	#* @response 400 Bad Request. Missing required parameters
   278	#* @response 404 Not Found. Cluster not found, summary rejected, or not cached (generation needs Curator+)
   279	#* @response 500 Internal Server Error. Generation failed
   280	#* @response 503 Service Unavailable. LLM not configured
   281	#*
   282	#* @get functional_cluster_summary
   283	function(cluster_hash = NULL, cluster_number = NULL, req, res) {
   284	  source("functions/llm-endpoint-helpers.R", local = TRUE)
   285	  allow_gen <- !is.null(req$user_role) && req$user_role %in% c("Curator", "Administrator")
   286	  get_cluster_summary(cluster_hash, cluster_number, "functional", res, allow_generation = allow_gen)
   287	}
   288
   289
   290	#* Get LLM Summary for Phenotype Cluster
   291	#*
   292	#* Retrieves or generates an LLM summary for a phenotype cluster.
   293	#* First checks cache, then generates on-demand if not found.
   294	#*
   295	#* # `Details`
   296	#* - Looks up cached summary by cluster_hash (SHA256 hash of cluster composition)
   297	#* - If not cached, generates new summary via Gemini API
   298	#* - Excludes rejected summaries (validation_status = 'rejected')
   299	#* - Returns summary_json with structured content (summary, key_themes, pathways, etc.)
   300	#*
   301	#* @tag analysis
   302	#* @serializer json list(na="string")
   303	#* @param cluster_hash:str SHA256 hash of cluster composition (or equals(hash,...) format)
   304	#* @param cluster_number:str Cluster number (integer as string)
   305	#*
   306	#* @response 200 OK. Returns summary with metadata
   307	#* @response 400 Bad Request. Missing required parameters
   308	#* @response 404 Not Found. Cluster not found, summary rejected, or not cached (generation needs Curator+)
   309	#* @response 500 Internal Server Error. Generation failed
   310	#* @response 503 Service Unavailable. LLM not configured
   311	#*
   312	#* @get phenotype_cluster_summary
   313	function(cluster_hash = NULL, cluster_number = NULL, req, res) {
   314	  source("functions/llm-endpoint-helpers.R", local = TRUE)
   315	  allow_gen <- !is.null(req$user_role) && req$user_role %in% c("Curator", "Administrator")
   316	  get_cluster_summary(cluster_hash, cluster_number, "phenotype", res, allow_generation = allow_gen)
   317	}
   318
   319
   320	#* Functional Clustering Reproducibility Bundle
   321	#*
   322	#* Read-only sibling of `/functional_clustering` (#512). Returns the inputs
   323	#* needed to INDEPENDENTLY recompute the served functional modularity: the
   324	#* largest-connected-component STRING edge list, the complete Leiden membership,
   325	#* the served modularity, params, and a SHA-256 reproducibility hash.
   326	#*
   327	#* # `Details`
   328	#* - DB-only read from the current public snapshot's reproducibility row.
   329	#* - Approved-public data only (the snapshot is built from approved public data).
   330	#* - The `bundle` is the decompressed, parsed JSON of the stored gzip blob.
   331	#*
   332	#* NOTE: These reproducibility routes live in this file (not a separate mounted
   333	#* sub-router) on purpose. Plumber cannot mount a second router at `/api/analysis`
   334	#* (a duplicate mount replaces the first) and a sub-router 404 does not fall
   335	#* through to other mounts, so the only way to serve the documented sibling path
   336	#* `/api/analysis/functional_clustering/reproducibility` is as a route inside the
   337	#* same analysis sub-router. The endpoint logic is kept thin (delegated to
   338	#* `analysis_reproducibility_endpoint()` in functions/analysis-reproducibility.R).
   339	#*
   340	#* @tag analysis
   341	#* @serializer json list(na="string", auto_unbox=TRUE)
   342	#*
   343	#* @response 200 OK. Returns { reproducibility_hash, kind, byte_size, snapshot_id, bundle }.
   344	#* @response 404 Not Found. No public snapshot or no reproducibility bundle yet.
   345	#*
   346	#* @get functional_clustering/reproducibility
   347	function(res) {
   348	  analysis_reproducibility_endpoint("functional_clusters", res)
   349	}
   350
   351
   352	#* Phenotype Clustering Reproducibility Bundle
   353	#*
   354	#* Read-only sibling of `/phenotype_clustering` (#512). Returns the inputs needed
   355	#* to INDEPENDENTLY recompute the served phenotype silhouette: the MCA coordinate
   356	#* matrix, the cluster membership, the served silhouette, params, and a SHA-256
   357	#* reproducibility hash.
   358	#*
   359	#* # `Details`
   360	#* - DB-only read from the current public snapshot's reproducibility row.
     1	## -------------------------------------------------------------------##
     2	# api/endpoints/admin_analysis_snapshot_endpoints.R
     3	#
     4	# Administrator-only HTTP triggers for the durable public analysis snapshots that
     5	# the /api/analysis/* read endpoints serve. Mounted at /api/admin/analysis, so:
     6	#   POST /api/admin/analysis/snapshots/refresh  (submit refresh jobs)
     7	#   GET  /api/admin/analysis/snapshots/status   (per-preset manifest state)
     8	#
     9	# All three snapshot submit paths (startup hook, this endpoint, and the operator
    10	# script scripts/refresh-analysis-snapshots.R) share one function,
    11	# service_analysis_snapshot_submit_refresh(), so submission logic is not
    12	# duplicated. Spec: .planning/superpowers/specs/2026-06-14-analysis-snapshot-bootstrap-design.md
    13	#
    14	# #573 Slice A / Task A7 appends 6 Administrator-only routes for immutable,
    15	# content-addressed public analysis-snapshot RELEASES: build/list/detail/
    16	# publish/record-DOI/delete-draft. The mutating routes (build, publish, set
    17	# DOI, delete draft) thinly delegate to the A5 service layer
    18	# (services/analysis-snapshot-release-service.R, `svc_release_*`); the two
    19	# admin READS that must see DRAFT rows call the A3 repository
    20	# (functions/analysis-snapshot-release-repository.R) directly with
    21	# `include_draft = TRUE` / `status = NULL` -- the sibling
    22	# svc_release_list()/svc_release_get() in the service layer are
    23	# PUBLISHED-ONLY by design (the public routes in analysis_endpoints.R use
    24	# those), so this file bypasses them for the two admin listings. The service
    25	# file and the four release function files are wired into
    26	# bootstrap/load_modules.R by Task A8, so these routes are live.
    27	## -------------------------------------------------------------------##
    28
    29	if (!exists("%||%", mode = "function")) {
    30	  `%||%` <- function(x, y) if (is.null(x)) y else x
    31	}
    32
    33	#* Submit analysis snapshot refresh jobs (Administrator only)
    34	#*
    35	#* Idempotently submits `analysis_snapshot_refresh` jobs so the worker rebuilds +
    36	#* activates the durable public-ready snapshots. By default only presets without a
    37	#* current public-ready snapshot are submitted; pass `force=true` to rebuild all.
    38	#* Re-submitting a queued/running refresh returns the existing job (dedup).
    39	#*
    40	#* @tag admin
    41	#* @serializer unboxedJSON
    42	#*
    43	#* @param analysis_type:str Optional single preset (e.g. "gene_network_edges"). Omit for all supported presets.
    44	#* @param force:bool Optional; rebuild even when a current snapshot exists. Default false.
    45	#*
    46	#* @post /snapshots/refresh
    47	function(req, res, analysis_type = NULL, force = FALSE) {
    48	  require_role(req, res, "Administrator")
    49
    50	  at <- if (is.null(analysis_type) || !nzchar(as.character(analysis_type[[1]]))) {
    51	    NULL
    52	  } else {
    53	    as.character(analysis_type[[1]])
    54	  }
    55	  force_flag <- isTRUE(force) ||
    56	    identical(tolower(as.character(force)[[1]]), "true") ||
    57	    identical(as.character(force)[[1]], "1")
    58
    59	  summary <- service_analysis_snapshot_submit_refresh(analysis_type = at, force = force_flag)
    60
    61	  res$status <- 202L
    62	  summary
    63	}
    64
    65	#* Per-preset analysis snapshot status (Administrator only)
    66	#*
    67	#* Returns the manifest state (missing / available / stale /
    68	#* source_version_mismatch) for each supported analysis preset, with timestamps
    69	#* and stored row counts, so an operator can watch a rebuild progress without DB
    70	#* access.
    71	#*
    72	#* @tag admin
    73	#* @serializer unboxedJSON
    74	#*
    75	#* @get /snapshots/status
    76	function(req, res) {
    77	  require_role(req, res, "Administrator")
    78	  service_analysis_snapshot_status()
    79	}
    80
    81	## -------------------------------------------------------------------##
    82	## Analysis-snapshot RELEASES: admin routes (#573 Slice A / Task A7)
    83	## -------------------------------------------------------------------##
    84
    85	#' Parse a POST/PATCH JSON request body with `jsonlite::fromJSON(simplifyVector
    86	#' = FALSE)`, NOT Plumber's default `req$argsBody` (`plumber:::safeFromJSON`,
    87	#' which parses with `simplifyVector = TRUE`).
    88	#'
    89	#' This matters specifically for `POST /releases`'s optional `layers` array
    90	#' override. Verified live: `simplifyVector = TRUE` collapses a JSON array of
    91	#' layer-override objects into a *data.frame* -- and a nested object field
    92	#' (e.g. `params`) collapses into its OWN nested data.frame column when every
    93	#' layer shares the same param keys. `analysis_snapshot_release_build()`
    94	#' iterates its `layers` argument with `lapply(layers, function(layer)
    95	#' layer$analysis_type[[1]])`; iterating a data.frame with `lapply()` walks
    96	#' the data.frame's COLUMNS (atomic vectors), the same "$ operator is invalid
    97	#' for atomic vectors" trap AGENTS.md documents for the force-apply payload
    98	#' helpers (`functions/async-job-force-apply-payload.R`). Re-parsing the raw
    99	#' body text with `simplifyVector = FALSE` instead -- the same call
   100	#' `core/logging_sanitizer.R`'s `sanitize_post_body_for_log()` already makes
   101	#' on `req$postBody` -- yields the EXACT list-of-named-lists shape
   102	#' `analysis_snapshot_release_layers()` itself returns (each layer's `params`
   103	#' comes back as a genuine named list too), so a caller-supplied `layers`
   104	#' override needs no further normalization before being forwarded to
   105	#' `svc_release_build()`. `req$postBody` is populated by Plumber's default
   106	#' `bodyFilter` for every request with a body, independent of any `@parser`
   107	#' annotation on this route.
   108	#'
   109	#' @noRd
   110	.admin_release_parse_json_body <- function(req) {
   111	  raw <- tryCatch(req$postBody, error = function(e) NULL)
   112	  if (is.null(raw) || !nzchar(raw)) {
   113	    return(list())
   114	  }
   115	  tryCatch(
   116	    jsonlite::fromJSON(raw, simplifyVector = FALSE),
   117	    error = function(e) stop_for_bad_request("Malformed JSON request body")
   118	  )
   119	}
   120
   121	#' Defensively parse a query-string integer with a default.
   122	#'
   123	#' A file-local duplicate of the identically-named helper in
   124	#' `endpoints/analysis_endpoints.R`: each endpoints file is mounted as its
   125	#' OWN Plumber sub-router / environment (`plumber::pr(file)`), so a top-level
   126	#' helper defined in a sibling endpoints file is not visible here.
   127	#'
   128	#' @noRd
   129	.admin_release_query_int <- function(value, default) {
   130	  scalar <- if (is.null(value)) default else value[[1]]
   131	  parsed <- suppressWarnings(as.integer(scalar))
   132	  if (is.na(parsed)) default else parsed
   133	}
   134
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
/bin/bash -lc "nl -ba app/src/api/admin_analysis_release.ts | sed -n '180,360p'
rg -n -C 6 'Analysis-snapshot release|@get releases|@get releases/latest|manifest.json|/file|/bundle' api/endpoints/analysis_endpoints.R
nl -ba api/endpoints/analysis_endpoints.R | sed -n '470,700p'
nl -ba api/services/analysis-snapshot-release-service.R | sed -n '1,320p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
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
409-#* @serializer json list(na="string", auto_unbox=TRUE)
410-#* @param limit:str Max releases to return (default "50")
411-#* @param offset:str Offset into the published list (default "0")
412-#*
413-#* @response 200 OK. Returns { releases, pagination }.
414-#*
415:#* @get releases
416-function(limit = "50", offset = "0", res) {
417-  limit_int <- analysis_release_query_int(limit, 50L)
418-  offset_int <- analysis_release_query_int(offset, 0L)
419-  releases <- svc_release_list(limit = limit_int, offset = offset_int, conn = pool)
420-  # L2: echo the EFFECTIVE (clamped) pagination the service actually queried,
421-  # not the caller's raw values (svc_release_clamp_* is the single clamp source).
--
438-#* @tag analysis
439-#* @serializer json list(na="string", auto_unbox=TRUE)
440-#*
441-#* @response 200 OK. Returns the release head + `manifest` (same shape as the detail route).
442-#* @response 404 Not Found. No published release exists yet.
443-#*
444:#* @get releases/latest
445-function(res) {
446-  newest <- svc_release_list(limit = 1, offset = 0, conn = pool)
447-  if (length(newest) == 0L) {
448-    stop_for_not_found("No published analysis-snapshot release exists yet")
449-  }
450-  svc_release_get(as.character(newest[[1]]$release_id), conn = pool)
--
457-#* @serializer json list(na="string", auto_unbox=TRUE)
458-#* @param release_id Release id (`asr_<16 hex>`).
459-#*
460-#* @response 200 OK. Returns the release head + `manifest`.
461-#* @response 404 Not Found. Unknown release id, or the release is still a draft.
462-#*
463:#* @get releases/<release_id>
464-function(release_id, res) {
465-  svc_release_get(release_id, conn = pool)
466-}
467-
468-
469:#* Get a published release's stored `manifest.json` bytes verbatim
470-#*
471-#* Serves the EXACT stored bytes (never re-serialized), so
472-#* `sha256(bytes) == manifest_sha256` on the release head.
473-#*
474-#* @tag analysis
475-#* @serializer octet list(type = "application/json")
476-#* @param release_id Release id.
477-#*
478:#* @response 200 OK. Raw manifest.json bytes, Content-Type application/json.
479-#* @response 404 Not Found. Unknown release id, or the release is still a draft.
480-#*
481:#* @get releases/<release_id>/manifest.json
482-function(release_id, res) {
483-  content <- svc_release_manifest(release_id, conn = pool)
484-  # Content-Type is set by the octet serializer (application/json) -- do NOT also
485-  # res$setHeader() it, which would emit a duplicate Content-Type header.
486-  content$bytes
487-}
--
499-#* @param release_id Release id.
500-#* @param path:str Exact archive-relative file path, e.g. "functional_clusters/payload.json".
501-#*
502-#* @response 200 OK. Raw file bytes, Content-Type from the stored file's media type.
503-#* @response 404 Not Found. Unknown release id, draft release, or unknown file path.
504-#*
505:#* @get releases/<release_id>/file
506-function(release_id, path = "", res) {
507-  file_path <- analysis_endpoint_scalar(path, "")
508-  content <- svc_release_file(release_id, file_path, conn = pool)
509-  # The stored media type is per-file (usually application/json), so set the
510-  # serializer's type dynamically rather than res$setHeader()-ing a second
511-  # Content-Type alongside the octet serializer's default.
--
520-#* @serializer octet list(type = "application/gzip")
521-#* @param release_id Release id.
522-#*
523-#* @response 200 OK. Raw gzip tar bytes, served as an attachment download.
524-#* @response 404 Not Found. Unknown release id, or the release is still a draft.
525-#*
526:#* @get releases/<release_id>/bundle
527-function(release_id, res) {
528-  bundle <- svc_release_bundle(release_id, conn = pool)
529-  # Content-Type (application/gzip) is set by the octet serializer -- do NOT also
530-  # res$setHeader() it (duplicate header). Content-Disposition/Length are distinct.
531-  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', bundle$filename))
532-  res$setHeader("Content-Length", as.character(length(bundle$bytes)))
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
   191	#' (`analysis_release_public_head`) so operational columns never leak.
   192	#'
   193	#' @param limit,offset Pagination (clamped).
   194	#' @param conn A real DBIConnection.
   195	#' @return A list of public-projected release-head-plus-layers entries; never
   196	#'   includes drafts.
   197	#' @export
   198	svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
   199	  limit <- svc_release_clamp_limit(limit)
   200	  offset <- svc_release_clamp_offset(offset)
   201	  rows <- analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
   202	  lapply(rows, analysis_release_public_head)
   203	}
   204
   205	#' Clamp a public list `limit` into `[1, 100]` (non-numeric -> default 50).
   206	#' @noRd
   207	svc_release_clamp_limit <- function(limit) {
   208	  value <- suppressWarnings(as.integer(limit))
   209	  if (length(value) == 0L || is.na(value)) {
   210	    value <- 50L
   211	  }
   212	  min(100L, max(1L, value))
   213	}
   214
   215	#' Clamp a public list `offset` to `>= 0` (non-numeric -> 0).
   216	#' @noRd
   217	svc_release_clamp_offset <- function(offset) {
   218	  value <- suppressWarnings(as.integer(offset))
   219	  if (length(value) == 0L || is.na(value)) {
   220	    value <- 0L
   221	  }
   222	  max(0L, value)
   223	}
   224
   225	#' Fetch one published release's head + parsed manifest.
   226	#'
   227	#' Unknown id OR a draft release -> 404 (indistinguishable to the caller;
   228	#' `include_draft = FALSE` makes the repository's own SQL filter the only
   229	#' source of truth for visibility).
   230	#'
   231	#' @param release_id Release id.
   232	#' @param conn A real DBIConnection.
   233	#' @return The release head (+ `$manifest`).
   234	#' @export
   235	svc_release_get <- function(release_id, conn = NULL) {
   236	  head <- analysis_release_get(release_id, include_draft = FALSE, conn = conn)
   237	  if (is.null(head)) {
   238	    stop_for_not_found("Release not found")
   239	  }
   240	  analysis_release_public_head(head)
   241	}
   242
   243	#' Fetch a published release's stored `manifest.json` file.
   244	#'
   245	#' @param release_id Release id.
   246	#' @param conn A real DBIConnection.
   247	#' @return `list(bytes, media_type = "application/json", content_sha256)`.
   248	#' @export
   249	svc_release_manifest <- function(release_id, conn = NULL) {
   250	  file <- analysis_release_get_file(release_id, "manifest.json", include_draft = FALSE, conn = conn)
   251	  if (is.null(file)) {
   252	    stop_for_not_found("Release not found")
   253	  }
   254	  list(bytes = file$bytes, media_type = "application/json", content_sha256 = file$content_sha256)
   255	}
   256
   257	#' Fetch one archive file's bytes from a published release by exact path.
   258	#'
   259	#' Unknown release, a draft release, or an unknown `file_path` all resolve to
   260	#' the same 404 (never distinguished for the caller).
   261	#'
   262	#' @param release_id Release id.
   263	#' @param file_path Exact archive-relative path (e.g. `"README.md"`,
   264	#'   `"functional_clusters/payload.json"`).
   265	#' @param conn A real DBIConnection.
   266	#' @return `list(bytes, media_type, content_sha256)`.
   267	#' @export
   268	svc_release_file <- function(release_id, file_path, conn = NULL) {
   269	  file <- analysis_release_get_file(release_id, file_path, include_draft = FALSE, conn = conn)
   270	  if (is.null(file)) {
   271	    stop_for_not_found(sprintf("Release file not found: %s", file_path))
   272	  }
   273	  list(bytes = file$bytes, media_type = file$media_type, content_sha256 = file$content_sha256)
   274	}
   275
   276	#' Fetch a published release's whole archive (`bundle.tar.gz`) verbatim.
   277	#'
   278	#' @param release_id Release id.
   279	#' @param conn A real DBIConnection.
   280	#' @return `list(bytes, sha256, filename)`.
   281	#' @export
   282	svc_release_bundle <- function(release_id, conn = NULL) {
   283	  bundle <- analysis_release_get_bundle(release_id, include_draft = FALSE, conn = conn)
   284	  if (is.null(bundle)) {
   285	    stop_for_not_found("Release not found")
   286	  }
   287	  list(bytes = bundle$bytes, sha256 = bundle$sha256, filename = bundle$filename)
   288	}

codex
The public and admin client routes align with the endpoint paths and verbs on first pass. I’m now tracing the view state transitions and link rendering, where the more consequential issues are likely to surface.
exec
/bin/bash -lc "nl -ba app/src/views/admin/useAnalysisReleaseAdmin.ts | sed -n '1,320p'
nl -ba app/src/views/admin/ManageAnalysisReleases.vue | sed -n '1,560p'
nl -ba app/src/components/analyses/ReleaseManifestPanel.vue | sed -n '1,500p'
nl -ba app/src/components/analyses/dataReleaseTable.ts | sed -n '1,220p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
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
   161	              v-if="release.zenodo.version_doi"
   162	              :href="doiUrl(release.zenodo.version_doi)"
   163	              target="_blank"
   164	              rel="noopener noreferrer"
   165	            >
   166	              {{ release.zenodo.version_doi }}
   167	            </a>
   168	            <span v-else class="text-muted">not yet assigned</span>
   169	          </dd>
   170	        </div>
   171	        <div>
   172	          <dt>Concept DOI</dt>
   173	          <dd>
   174	            <a
   175	              v-if="release.zenodo.concept_doi"
   176	              :href="doiUrl(release.zenodo.concept_doi)"
   177	              target="_blank"
   178	              rel="noopener noreferrer"
   179	            >
   180	              {{ release.zenodo.concept_doi }}
   181	            </a>
   182	            <span v-else class="text-muted">not yet assigned</span>
   183	          </dd>
   184	        </div>
   185	        <div>
   186	          <dt>Zenodo record</dt>
   187	          <dd>
   188	            <a
   189	              v-if="release.zenodo.record_url"
   190	              :href="release.zenodo.record_url"
   191	              target="_blank"
   192	              rel="noopener noreferrer"
   193	            >
   194	              Record
   195	            </a>
   196	            <span v-else class="text-muted">not yet assigned</span>
   197	          </dd>
   198	        </div>
   199	      </dl>
   200	    </section>
   201	  </section>
   202	</template>
   203
   204	<script setup lang="ts">
   205	import { computed, onBeforeUnmount, ref } from 'vue';
   206	import { BBadge } from 'bootstrap-vue-next';
   207	import type { ReleaseDetail, ReleaseManifestLayer } from '@/api/analysis';
   208
   209	defineOptions({
   210	  name: 'ReleaseManifestPanel',
   211	});
   212
   213	const props = defineProps<{
   214	  release: ReleaseDetail;
   215	}>();
   216
   217	function displayValue(value: string | number | null | undefined): string {
   218	  return value === null || value === undefined || value === '' ? '—' : String(value);
   219	}
   220
   221	/** `title`, falling back to `release_id` when the reserved `title` column is null. */
   222	const displayTitle = computed(() => props.release.title || props.release.release_id);
   223
   224	function doiUrl(doi: string): string {
   225	  return `https://doi.org/${doi}`;
   226	}
   227
   228	const integrityHashes = computed(() => [
   229	  { key: 'content_digest', label: 'Content digest', value: props.release.content_digest },
   230	  { key: 'manifest_sha256', label: 'Manifest SHA-256', value: props.release.manifest_sha256 },
   231	  { key: 'bundle_sha256', label: 'Bundle SHA-256', value: props.release.bundle_sha256 },
   232	]);
   233
   234	/** The one manifest layer with pinned source-layer dependencies (the correlation layer), if any. */
   235	const dependencyLayer = computed<ReleaseManifestLayer | null>(
   236	  () => props.release.manifest.layers.find((layer) => layer.dependencies != null) ?? null
   237	);
   238
   239	// --- Copy-to-clipboard: mirrors small/GenericTableDetails.vue's transient
   240	// "Copy" -> "Copied" state + reset-timer lifecycle. ---
   241	const copiedKey = ref<string | null>(null);
   242	let copyResetTimer: ReturnType<typeof setTimeout> | null = null;
   243
   244	async function copyValue(key: string, value: string): Promise<void> {
   245	  if (!value || !navigator.clipboard?.writeText) {
   246	    return;
   247	  }
   248	  try {
   249	    await navigator.clipboard.writeText(value);
   250	    copiedKey.value = key;
   251	    if (copyResetTimer) {
   252	      clearTimeout(copyResetTimer);
   253	    }
   254	    copyResetTimer = setTimeout(() => {
   255	      copiedKey.value = null;
   256	      copyResetTimer = null;
   257	    }, 1600);
   258	  } catch {
   259	    copiedKey.value = null;
   260	  }
   261	}
   262
   263	onBeforeUnmount(() => {
   264	  if (copyResetTimer) {
   265	    clearTimeout(copyResetTimer);
   266	    copyResetTimer = null;
   267	  }
   268	});
   269	</script>
   270
   271	<style scoped>
   272	.release-manifest-panel {
   273	  display: grid;
   274	  gap: 1rem;
   275	  padding: 1rem;
   276	  border: 1px solid #d7dee8;
   277	  border-radius: var(--radius-lg, 8px);
   278	  background: #fff;
   279	  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
   280	}
   281
   282	.release-manifest-panel__header {
   283	  display: flex;
   284	  flex-wrap: wrap;
   285	  align-items: flex-start;
   286	  justify-content: space-between;
   287	  gap: 0.75rem;
   288	}
   289
   290	.release-manifest-panel__title {
   291	  margin: 0;
   292	  color: var(--neutral-900, #212121);
   293	  font-size: 1rem;
   294	  font-weight: 700;
   295	  line-height: 1.25;
   296	}
   297
   298	.release-manifest-panel__subtitle {
   299	  margin: 0.15rem 0 0;
   300	  color: var(--neutral-600, #757575);
   301	  font-size: 0.875rem;
   302	  line-height: 1.45;
   303	}
   304
   305	.release-manifest-panel__badge {
   306	  max-width: 100%;
   307	  overflow-wrap: anywhere;
   308	  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
   309	}
   310
   311	.release-manifest-panel__section-title {
   312	  margin: 0 0 0.4rem;
   313	  color: var(--neutral-700, #616161);
   314	  font-size: 0.8125rem;
   315	  font-weight: 700;
   316	  text-transform: uppercase;
   317	  letter-spacing: 0.02em;
   318	}
   319
   320	.release-manifest-panel__grid {
   321	  display: grid;
   322	  grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
   323	  gap: 0.5rem 0.75rem;
   324	  margin: 0;
   325	}
   326
   327	.release-manifest-panel__grid div {
   328	  min-width: 0;
   329	}
   330
   331	.release-manifest-panel__grid dt {
   332	  margin: 0;
   333	  color: var(--neutral-700, #616161);
   334	  font-size: 0.75rem;
   335	  font-weight: 700;
   336	}
   337
   338	.release-manifest-panel__grid dd {
   339	  margin: 0.1rem 0 0;
   340	  color: var(--neutral-900, #212121);
   341	  font-size: 0.8125rem;
   342	  overflow-wrap: anywhere;
   343	}
   344
   345	.release-manifest-panel__grid a {
   346	  color: var(--medical-blue-700, #0d47a1);
   347	}
   348
   349	.release-manifest-panel__mono {
   350	  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
   351	}
   352
   353	.release-manifest-panel__grid--hashes dd.release-manifest-panel__hash-value {
   354	  display: flex;
   355	  flex-wrap: wrap;
   356	  align-items: center;
   357	  gap: 0.5rem;
   358	}
   359
   360	.release-manifest-panel__grid--hashes .release-manifest-panel__mono {
   361	  word-break: break-all;
   362	}
   363
   364	.release-manifest-panel__copy-button {
   365	  display: inline-flex;
   366	  flex: 0 0 auto;
   367	  align-items: center;
   368	  gap: 0.25rem;
   369	  padding: 0.08rem 0.4rem;
   370	  border: 1px solid #0a58ca;
   371	  border-radius: var(--radius-md, 6px);
   372	  background: #fff;
   373	  color: #0a58ca;
   374	  font-size: 0.72rem;
   375	  line-height: 1.6;
   376	  white-space: nowrap;
   377	}
   378
   379	.release-manifest-panel__copy-button:hover,
   380	.release-manifest-panel__copy-button:focus {
   381	  border-color: #084298;
   382	  background-color: #0a58ca;
   383	  color: #fff;
   384	}
   385
   386	.release-manifest-panel__layer {
   387	  padding: 0.5rem 0.65rem;
   388	  border: 1px solid #e1e7ef;
   389	  border-radius: var(--radius-md, 6px);
   390	  background: #f8fafc;
   391	}
   392
   393	.release-manifest-panel__layer + .release-manifest-panel__layer {
   394	  margin-top: 0.5rem;
   395	}
   396
   397	.release-manifest-panel__layer-title {
   398	  margin: 0 0 0.35rem;
   399	  color: var(--neutral-900, #212121);
   400	  font-size: 0.875rem;
   401	  font-weight: 700;
   402	}
   403
   404	.release-manifest-panel__hint {
   405	  margin: 0 0 0.5rem;
   406	  color: var(--neutral-600, #757575);
   407	  font-size: 0.8125rem;
   408	}
   409	</style>
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

exec
/bin/bash -lc "nl -ba app/src/views/admin/ManageAnalysisReleases.vue | sed -n '150,540p'
nl -ba app/src/components/analyses/ReleaseManifestPanel.vue | sed -n '1,280p'
rg -n -C 5 'analysis_release_set_doi|zenodo_record_url|version_doi|concept_doi' api/functions/analysis-snapshot-release* api/services/analysis-snapshot-release-service.R
rg -n 'v-html|:href' app/src/{views/admin/ManageAnalysisReleases.vue,views/analyses/DataReleases.vue,components/analyses/ReleaseManifestPanel.vue}" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
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
   161	              v-if="release.zenodo.version_doi"
   162	              :href="doiUrl(release.zenodo.version_doi)"
   163	              target="_blank"
   164	              rel="noopener noreferrer"
   165	            >
   166	              {{ release.zenodo.version_doi }}
   167	            </a>
   168	            <span v-else class="text-muted">not yet assigned</span>
   169	          </dd>
   170	        </div>
   171	        <div>
   172	          <dt>Concept DOI</dt>
   173	          <dd>
   174	            <a
   175	              v-if="release.zenodo.concept_doi"
   176	              :href="doiUrl(release.zenodo.concept_doi)"
   177	              target="_blank"
   178	              rel="noopener noreferrer"
   179	            >
   180	              {{ release.zenodo.concept_doi }}
   181	            </a>
   182	            <span v-else class="text-muted">not yet assigned</span>
   183	          </dd>
   184	        </div>
   185	        <div>
   186	          <dt>Zenodo record</dt>
   187	          <dd>
   188	            <a
   189	              v-if="release.zenodo.record_url"
   190	              :href="release.zenodo.record_url"
   191	              target="_blank"
   192	              rel="noopener noreferrer"
   193	            >
   194	              Record
   195	            </a>
   196	            <span v-else class="text-muted">not yet assigned</span>
   197	          </dd>
   198	        </div>
   199	      </dl>
   200	    </section>
   201	  </section>
   202	</template>
   203
   204	<script setup lang="ts">
   205	import { computed, onBeforeUnmount, ref } from 'vue';
   206	import { BBadge } from 'bootstrap-vue-next';
   207	import type { ReleaseDetail, ReleaseManifestLayer } from '@/api/analysis';
   208
   209	defineOptions({
   210	  name: 'ReleaseManifestPanel',
   211	});
   212
   213	const props = defineProps<{
   214	  release: ReleaseDetail;
   215	}>();
   216
   217	function displayValue(value: string | number | null | undefined): string {
   218	  return value === null || value === undefined || value === '' ? '—' : String(value);
   219	}
   220
   221	/** `title`, falling back to `release_id` when the reserved `title` column is null. */
   222	const displayTitle = computed(() => props.release.title || props.release.release_id);
   223
   224	function doiUrl(doi: string): string {
   225	  return `https://doi.org/${doi}`;
   226	}
   227
   228	const integrityHashes = computed(() => [
   229	  { key: 'content_digest', label: 'Content digest', value: props.release.content_digest },
   230	  { key: 'manifest_sha256', label: 'Manifest SHA-256', value: props.release.manifest_sha256 },
   231	  { key: 'bundle_sha256', label: 'Bundle SHA-256', value: props.release.bundle_sha256 },
   232	]);
   233
   234	/** The one manifest layer with pinned source-layer dependencies (the correlation layer), if any. */
   235	const dependencyLayer = computed<ReleaseManifestLayer | null>(
   236	  () => props.release.manifest.layers.find((layer) => layer.dependencies != null) ?? null
   237	);
   238
   239	// --- Copy-to-clipboard: mirrors small/GenericTableDetails.vue's transient
   240	// "Copy" -> "Copied" state + reset-timer lifecycle. ---
   241	const copiedKey = ref<string | null>(null);
   242	let copyResetTimer: ReturnType<typeof setTimeout> | null = null;
   243
   244	async function copyValue(key: string, value: string): Promise<void> {
   245	  if (!value || !navigator.clipboard?.writeText) {
   246	    return;
   247	  }
   248	  try {
   249	    await navigator.clipboard.writeText(value);
   250	    copiedKey.value = key;
   251	    if (copyResetTimer) {
   252	      clearTimeout(copyResetTimer);
   253	    }
   254	    copyResetTimer = setTimeout(() => {
   255	      copiedKey.value = null;
   256	      copyResetTimer = null;
   257	    }, 1600);
   258	  } catch {
   259	    copiedKey.value = null;
   260	  }
   261	}
   262
   263	onBeforeUnmount(() => {
   264	  if (copyResetTimer) {
   265	    clearTimeout(copyResetTimer);
   266	    copyResetTimer = null;
   267	  }
   268	});
   269	</script>
   270
   271	<style scoped>
   272	.release-manifest-panel {
   273	  display: grid;
   274	  gap: 1rem;
   275	  padding: 1rem;
   276	  border: 1px solid #d7dee8;
   277	  border-radius: var(--radius-lg, 8px);
   278	  background: #fff;
   279	  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
   280	}
api/services/analysis-snapshot-release-service.R-142-#' touches `content_digest`/`manifest_sha256` — release scientific identity
api/services/analysis-snapshot-release-service.R-143-#' is immutable once minted). Unknown release id -> 404.
api/services/analysis-snapshot-release-service.R-144-#'
api/services/analysis-snapshot-release-service.R-145-#' @param release_id Release id.
api/services/analysis-snapshot-release-service.R-146-#' @param doi_fields Named list, any subset of `zenodo_record_id`,
api/services/analysis-snapshot-release-service.R:147:#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
api/services/analysis-snapshot-release-service.R-148-#' @param conn A real DBIConnection.
api/services/analysis-snapshot-release-service.R-149-#' @return The updated release head.
api/services/analysis-snapshot-release-service.R-150-#' @export
api/services/analysis-snapshot-release-service.R-151-svc_release_set_doi <- function(release_id, doi_fields, conn = NULL) {
api/services/analysis-snapshot-release-service.R:152:  analysis_release_set_doi(release_id, doi_fields = doi_fields, conn = conn)
api/services/analysis-snapshot-release-service.R-153-  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R-154-  if (is.null(head)) {
api/services/analysis-snapshot-release-service.R-155-    stop_for_not_found(sprintf("Release '%s' not found", release_id))
api/services/analysis-snapshot-release-service.R-156-  }
api/services/analysis-snapshot-release-service.R-157-  head
--
api/functions/analysis-snapshot-release-repository.R-62-.analysis_release_head_columns <- paste(
api/functions/analysis-snapshot-release-repository.R-63-  "release_id, release_version, title, status, manifest_schema_version,",
api/functions/analysis-snapshot-release-repository.R-64-  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
api/functions/analysis-snapshot-release-repository.R-65-  "source_data_version, db_release_version, db_release_commit, scope_statement,",
api/functions/analysis-snapshot-release-repository.R-66-  "license, file_count, total_bytes, created_by_user_id, created_at,",
api/functions/analysis-snapshot-release-repository.R:67:  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
api/functions/analysis-snapshot-release-repository.R:68:  "version_doi, concept_doi, last_error_message"
api/functions/analysis-snapshot-release-repository.R-69-)
api/functions/analysis-snapshot-release-repository.R-70-
api/functions/analysis-snapshot-release-repository.R-71-#' Convert a single-row data.frame (as returned by dbGetQuery) into a plain
api/functions/analysis-snapshot-release-repository.R-72-#' named list, one element per column.
api/functions/analysis-snapshot-release-repository.R-73-#' @noRd
--
api/functions/analysis-snapshot-release-repository.R-216-    "db_release_version", "db_release_commit", "manifest_sha256",
api/functions/analysis-snapshot-release-repository.R-217-    "bundle_sha256", "license", "file_count", "total_bytes"
api/functions/analysis-snapshot-release-repository.R-218-  )
api/functions/analysis-snapshot-release-repository.R-219-  projected <- head[intersect(allowlist, names(head))]
api/functions/analysis-snapshot-release-repository.R-220-  projected$zenodo <- list(
api/functions/analysis-snapshot-release-repository.R:221:    record_url = nullify(head$zenodo_record_url),
api/functions/analysis-snapshot-release-repository.R:222:    version_doi = nullify(head$version_doi),
api/functions/analysis-snapshot-release-repository.R:223:    concept_doi = nullify(head$concept_doi)
api/functions/analysis-snapshot-release-repository.R-224-  )
api/functions/analysis-snapshot-release-repository.R-225-  if (!is.null(head$layers)) {
api/functions/analysis-snapshot-release-repository.R-226-    projected$layers <- head$layers
api/functions/analysis-snapshot-release-repository.R-227-  }
api/functions/analysis-snapshot-release-repository.R-228-  if (!is.null(head$manifest)) {
--
api/functions/analysis-snapshot-release-repository.R-439-}
api/functions/analysis-snapshot-release-repository.R-440-
api/functions/analysis-snapshot-release-repository.R-441-#' Record external Zenodo/DOI provenance on an existing release.
api/functions/analysis-snapshot-release-repository.R-442-#'
api/functions/analysis-snapshot-release-repository.R-443-#' Additive metadata only — updates whichever of `zenodo_record_id`,
api/functions/analysis-snapshot-release-repository.R:444:#' `zenodo_record_url`, `version_doi`, `concept_doi` are present in
api/functions/analysis-snapshot-release-repository.R-445-#' `doi_fields`; never touches `content_digest`/`manifest_sha256` (release
api/functions/analysis-snapshot-release-repository.R-446-#' scientific identity is immutable once minted).
api/functions/analysis-snapshot-release-repository.R-447-#'
api/functions/analysis-snapshot-release-repository.R-448-#' @param doi_fields Named list, any subset of `zenodo_record_id`,
api/functions/analysis-snapshot-release-repository.R:449:#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
api/functions/analysis-snapshot-release-repository.R-450-#' @return logical(1), TRUE iff a row was updated.
api/functions/analysis-snapshot-release-repository.R-451-#' @export
api/functions/analysis-snapshot-release-repository.R:452:analysis_release_set_doi <- function(release_id, doi_fields = list(), conn) {
api/functions/analysis-snapshot-release-repository.R:453:  allowed <- c("zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi")
api/functions/analysis-snapshot-release-repository.R-454-  present <- intersect(names(doi_fields), allowed)
api/functions/analysis-snapshot-release-repository.R-455-  if (length(present) == 0L) {
api/functions/analysis-snapshot-release-repository.R-456-    return(FALSE)
api/functions/analysis-snapshot-release-repository.R-457-  }
api/functions/analysis-snapshot-release-repository.R-458-
app/src/components/analyses/ReleaseManifestPanel.vue:162:              :href="doiUrl(release.zenodo.version_doi)"
app/src/components/analyses/ReleaseManifestPanel.vue:176:              :href="doiUrl(release.zenodo.concept_doi)"
app/src/components/analyses/ReleaseManifestPanel.vue:190:              :href="release.zenodo.record_url"

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '430,500p'
nl -ba app/src/views/admin/ManageAnalysisReleases.spec.ts | sed -n '1,430p'
nl -ba app/src/views/admin/useAnalysisReleaseAdmin.spec.ts | sed -n '1,430p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
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
   481	    params = unname(list(as.character(release_id)))
   482	  )
   483	  affected > 0L
   484	}
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
   308	  it('deletes a draft only after the two-step in-page confirm, never via a blocking dialog', async () => {
   309	    const confirmSpy = vi.spyOn(window, 'confirm');
   310	    const release = makeRelease({ release_id: 'asr_draft2', status: 'draft' });
   311	    listAdminReleasesMock.mockResolvedValue({
   312	      releases: [release],
   313	      pagination: { limit: 50, offset: 0, count: 1 },
   314	    });
   315	    deleteDraftReleaseMock.mockResolvedValue(undefined);
   316
   317	    const wrapper = mountView();
   318	    await flushPromises();
   319
   320	    expect(wrapper.find('[data-testid="confirm-delete-asr_draft2"]').exists()).toBe(false);
   321
   322	    await wrapper.find('[data-testid="delete-asr_draft2"]').trigger('click');
   323	    await flushPromises();
   324
   325	    expect(deleteDraftReleaseMock).not.toHaveBeenCalled();
   326	    expect(confirmSpy).not.toHaveBeenCalled();
   327
   328	    await wrapper.find('[data-testid="confirm-delete-asr_draft2"]').trigger('click');
   329	    await flushPromises();
   330
   331	    expect(deleteDraftReleaseMock).toHaveBeenCalledWith('asr_draft2');
   332	    expect(confirmSpy).not.toHaveBeenCalled();
   333	  });
   334	});
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

exec
/bin/bash -lc "nl -ba app/src/api/client.ts | sed -n '1,360p'
nl -ba app/src/api/analysis_releases.spec.ts | sed -n '1,380p'
nl -ba app/src/api/admin_analysis_release.spec.ts | sed -n '1,340p'
nl -ba app/src/api/analysis.ts | sed -n '1,360p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
     1	// app/src/api/client.ts
     2	/**
     3	 * Typed wrapper over the central axios singleton at `@/plugins/axios`.
     4	 *
     5	 * Phase E.E1 (exit criterion #14, `.planning/_archive/legacy-plans/v11.0/phase-e.md` §3) introduces a
     6	 * cohesive `api/` module as the single surface for HTTP calls. This file is
     7	 * that surface: call-sites in views/components/composables will migrate to
     8	 * `apiClient.get(...)` over E3–E10 instead of reaching for `axios.get(...)`
     9	 * directly.
    10	 *
    11	 * IMPORTANT: we do NOT instantiate a new axios instance here. The plugin in
    12	 * `@/plugins/axios` configures the default instance (`baseURL`, the
    13	 * `Authorization` header, and the 401 response interceptor). Creating a
    14	 * separate `axios.create({...})` would skip that interceptor chain and
    15	 * silently bypass the login-redirect behaviour. Every method below delegates
    16	 * to the configured default instance so the wrapper inherits all of it.
    17	 *
    18	 * `withCredentials` is NOT enabled by default on the shared singleton
    19	 * (`@/plugins/axios` does not set `axios.defaults.withCredentials`). The vast
    20	 * majority of endpoints are Bearer-authenticated and do not need cookies.
    21	 * Durable async job polling now reads DB-backed state, so it no longer needs
    22	 * sticky-session routing to hit a specific API replica. Opt into
    23	 * `withCredentials: true` only for endpoints that genuinely need cookie-based
    24	 * behaviour.
    25	 */
    26
    27	import axios, {
    28	  AxiosError,
    29	  AxiosHeaders,
    30	  type AxiosRequestConfig,
    31	  type AxiosResponse,
    32	} from 'axios';
    33
    34	// Re-export the configured singleton from the existing plugin so anyone who
    35	// imports it via `@/api/client` ends up on the same instance as `@/plugins/
    36	// axios` consumers.  Importing the plugin here ensures its initialisation
    37	// side-effects (baseURL, 401 interceptor) have run before any
    38	// api/ call site fires.
    39	import '@/plugins/axios';
    40
    41	// v11.0 closeout F1: single injection point for the Authorization header
    42	// on authenticated app-session requests. The interceptor reads
    43	// `useAuth().token.value` on every outbound call, so mutations to
    44	// `axios.defaults.headers.common.Authorization` are forbidden outside
    45	// the two enumerated exceptions (§3.4: LoginView bootstrap handshake and
    46	// PasswordResetView route-param JWT).
    47	//
    48	// Import cycle note: `useAuth` imports `@/api/auth` (for refresh) which
    49	// imports `apiClient` from this file. That cycle is resolved at runtime
    50	// because `useAuth()` is only called inside the interceptor callback —
    51	// never at this module's top-level evaluation. When a request fires,
    52	// both modules are fully initialised.
    53	import { useAuth } from '@/composables/useAuth';
    54
    55	// Does the request config already carry an `Authorization` header?
    56	// Handles both `AxiosHeaders` and plain-object shapes, matches the
    57	// header name case-insensitively (HTTP headers are case-insensitive and
    58	// axios normalises on flight, but a call site may write any case).
    59	function hasAuthorizationHeader(headers: AxiosRequestConfig['headers']): boolean {
    60	  if (!headers) {
    61	    return false;
    62	  }
    63	  if (headers instanceof AxiosHeaders) {
    64	    return headers.has('Authorization');
    65	  }
    66	  return Object.keys(headers).some((key) => key.toLowerCase() === 'authorization');
    67	}
    68
    69	axios.interceptors.request.use((config) => {
    70	  // Preserve any explicit per-request `Authorization` header (for example,
    71	  // the closeout's enumerated exception flows — `LoginView` bootstrap
    72	  // handshake and `PasswordResetView` route-param JWT — which must supply
    73	  // their own Bearer token). Only inject the app-session token when the
    74	  // call site did not already specify one.
    75	  if (hasAuthorizationHeader(config.headers)) {
    76	    return config;
    77	  }
    78	  const auth = useAuth();
    79	  const token = auth.token.value;
    80	  if (token) {
    81	    // Axios v1 normalises `config.headers` to `AxiosHeaders` before the
    82	    // interceptor fires, but the type annotation allows `undefined`. Use
    83	    // the `AxiosHeaders.set` API so the header survives the downstream
    84	    // transformRequest pass without depending on the Record-cast escape
    85	    // hatch.
    86	    if (!config.headers) {
    87	      config.headers = new AxiosHeaders();
    88	    }
    89	    if (config.headers instanceof AxiosHeaders) {
    90	      config.headers.set('Authorization', `Bearer ${token}`);
    91	    } else {
    92	      (config.headers as Record<string, string>).Authorization = `Bearer ${token}`;
    93	    }
    94	  }
    95	  return config;
    96	});
    97
    98	// ---------------------------------------------------------------------------
    99	// Public API
   100	// ---------------------------------------------------------------------------
   101
   102	/**
   103	 * Typed HTTP verb helpers that resolve with `response.data` instead of the
   104	 * full `AxiosResponse`. Reach for `apiClient.raw.*` when a call site needs
   105	 * the status code, headers, or config object.
   106	 */
   107	export interface ApiClient {
   108	  get<T>(path: string, config?: AxiosRequestConfig): Promise<T>;
   109	  post<T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig): Promise<T>;
   110	  put<T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig): Promise<T>;
   111	  patch<T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig): Promise<T>;
   112	  delete<T>(path: string, config?: AxiosRequestConfig): Promise<T>;
   113	  /**
   114	   * Escape hatch: returns the full AxiosResponse<T> for call sites that need
   115	   * status codes, response headers, or to detect 201 vs 200 differentiation.
   116	   */
   117	  raw: {
   118	    get<T>(path: string, config?: AxiosRequestConfig): Promise<AxiosResponse<T>>;
   119	    post<T, B = unknown>(
   120	      path: string,
   121	      body?: B,
   122	      config?: AxiosRequestConfig
   123	    ): Promise<AxiosResponse<T>>;
   124	    put<T, B = unknown>(
   125	      path: string,
   126	      body?: B,
   127	      config?: AxiosRequestConfig
   128	    ): Promise<AxiosResponse<T>>;
   129	    patch<T, B = unknown>(
   130	      path: string,
   131	      body?: B,
   132	      config?: AxiosRequestConfig
   133	    ): Promise<AxiosResponse<T>>;
   134	    delete<T>(path: string, config?: AxiosRequestConfig): Promise<AxiosResponse<T>>;
   135	  };
   136	}
   137
   138	export const apiClient: ApiClient = {
   139	  get: async <T>(path: string, config?: AxiosRequestConfig): Promise<T> => {
   140	    const response = await axios.get<T>(path, config);
   141	    return response.data;
   142	  },
   143	  post: async <T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig): Promise<T> => {
   144	    const response = await axios.post<T>(path, body, config);
   145	    return response.data;
   146	  },
   147	  put: async <T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig): Promise<T> => {
   148	    const response = await axios.put<T>(path, body, config);
   149	    return response.data;
   150	  },
   151	  patch: async <T, B = unknown>(
   152	    path: string,
   153	    body?: B,
   154	    config?: AxiosRequestConfig
   155	  ): Promise<T> => {
   156	    const response = await axios.patch<T>(path, body, config);
   157	    return response.data;
   158	  },
   159	  delete: async <T>(path: string, config?: AxiosRequestConfig): Promise<T> => {
   160	    const response = await axios.delete<T>(path, config);
   161	    return response.data;
   162	  },
   163	  raw: {
   164	    get: <T>(path: string, config?: AxiosRequestConfig) => axios.get<T>(path, config),
   165	    post: <T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig) =>
   166	      axios.post<T>(path, body, config),
   167	    put: <T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig) =>
   168	      axios.put<T>(path, body, config),
   169	    patch: <T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig) =>
   170	      axios.patch<T>(path, body, config),
   171	    delete: <T>(path: string, config?: AxiosRequestConfig) => axios.delete<T>(path, config),
   172	  },
   173	};
   174
   175	// ---------------------------------------------------------------------------
   176	// Error helpers
   177	// ---------------------------------------------------------------------------
   178
   179	/**
   180	 * Type guard narrowing an unknown value to `AxiosError<T>`. Wraps
   181	 * `axios.isAxiosError` so call sites don't have to import `axios` directly.
   182	 *
   183	 * Note: the 401 interceptor in `@/plugins/axios` replaces the original
   184	 * AxiosError with a tagged plain Error (`__handled401: true`) to coalesce
   185	 * concurrent login redirects. For 401s, this guard will correctly return
   186	 * `false` — the call site should treat a 401-originated rejection as
   187	 * already handled by the redirect and skip toasts.
   188	 */
   189	export function isApiError<T = unknown>(err: unknown): err is AxiosError<T> {
   190	  return axios.isAxiosError(err);
   191	}
   192
   193	export { AxiosError };
   194
   195	// ---------------------------------------------------------------------------
   196	// R/Plumber scalar unwrapper
   197	// ---------------------------------------------------------------------------
   198
   199	/**
   200	 * R/Plumber serialises bare JSON scalars as 1-element arrays (see the gotcha
   201	 * in the repo-root `CLAUDE.md`). This helper collapses `[x]` to `x` for call
   202	 * sites that need the scalar shape; leaves everything else untouched.
   203	 *
   204	 * Multi-element arrays are real arrays, not scalar wrappers, so the helper
   205	 * returns them unchanged.
   206	 */
   207	export function unwrapScalar<T>(value: T | [T]): T {
   208	  if (Array.isArray(value) && value.length === 1) {
   209	    return value[0] as T;
   210	  }
   211	  return value as T;
   212	}
   213
   214	export default apiClient;
nl: app/src/api/analysis_releases.spec.ts: No such file or directory
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
   121	  n_entities_assigned?: number | number[];
   122	  n_entities_dropped?: number | number[];
   123	  // shared
   124	  partition_scope?: string | string[];
   125	  resampling_scheme?: string | string[];
   126	  subsample_fraction?: number | number[];
   127	  n_resamples?: number | number[];
   128	  n_resamples_effective?: number | number[];
   129	  // Null-calibrated separation statistics (validation schema >= 2.0, #510/#511).
   130	  // Additive + optional so pre-refresh snapshots still type-check; values may
   131	  // arrive Plumber-wrapped as 1-element arrays.
   132	  // — both axes —
   133	  separation_z?: number | number[];
   134	  null_model?: string | string[];
   135	  dip_statistic?: number | number[];
   136	  dip_p?: number | number[];
   137	  dip_interpretation?: string | string[];
   138	  // — functional (leiden) —
   139	  modularity_lcc?: number | number[]; // LCC Q the z is computed on (reconciles with modularity_z)
   140	  modularity_z?: number | number[];
   141	  modularity_p_empirical?: number | number[];
   142	  modularity_null_mean?: number | number[];
   143	  modularity_null_sd?: number | number[];
   144	  modularity_combined_score?: number | number[];
   145	  weight_channel?: string | string[];
   146	  giant_component?: {
   147	    n_nodes?: number | number[];
   148	    n_edges?: number | number[];
   149	    n_isolates?: number | number[];
   150	    n_components?: number | number[];
   151	    node_retention?: number | number[];
   152	    edge_retention?: number | number[];
   153	  };
   154	  // — phenotype (mca_hcpc) —
   155	  silhouette_z?: number | number[];
   156	  silhouette_p_empirical?: number | number[];
   157	  shared_modularity_z?: number | number[];
   158	  k_decision_curve?: Record<string, number | number[]>;
   159	  k_selected?: number | number[];
   160	  silhouette_interpretation?: string | string[];
   161	  consolidation?: boolean | boolean[];
   162	  [key: string]: unknown;
   163	}
   164
   165	export interface AnalysisSnapshotMeta {
   166	  snapshot_id?: number;
   167	  analysis_type?: string;
   168	  parameter_hash?: string;
   169	  schema_version?: string;
   170	  data_class?: string;
   171	  generated_at?: string;
   172	  stale_after?: string;
   173	  source_data_version?: string;
   174	  // Cluster-validation surface (#457–459). `validation` is an empty array/object
   175	  // for snapshots built before validation existed; the card hides itself then.
   176	  validation?: ClusterValidation | unknown[];
   177	  validation_hash?: string | string[];
   178	  db_release?: { version?: string | string[]; commit?: string | string[] };
   179	}
   180
   181	export interface ClusteringMeta {
   182	  algorithm: string;
   183	  elapsed_seconds: number;
   184	  gene_count: number;
   185	  cluster_count: number;
   186	  cache_hit?: boolean;
   187	  snapshot?: AnalysisSnapshotMeta;
   188	}
   189
   190	export interface FunctionalClusteringResponse {
   191	  categories: ClusterCategory[];
   192	  clusters: FunctionalCluster[];
   193	  pagination: PaginationMeta;
   194	  meta: ClusteringMeta;
   195	}
   196
   197	/**
   198	 * One phenotype cluster row returned in the `GET /api/analysis/phenotype_clustering`
   199	 * envelope.
   200	 */
   201	export interface PhenotypeCluster {
   202	  cluster: string | number;
   203	  identifiers: Array<{ entity_id: number; hgnc_id: string; symbol: string }>;
   204	  // Per-cluster stability joined in by the snapshot builder (scalar-or-array).
   205	  cluster_size?: number | number[];
   206	  jaccard_mean?: number | number[];
   207	  jaccard_n_resamples?: number | number[];
   208	  silhouette_mean?: number | number[];
   209	  [key: string]: unknown;
   210	}
   211
   212	export interface PhenotypeClusteringResponse {
   213	  clusters: PhenotypeCluster[];
   214	  meta: {
   215	    snapshot?: AnalysisSnapshotMeta;
   216	    [key: string]: unknown;
   217	  };
   218	}
   219
   220	/**
   221	 * One row of the melted correlation matrix.
   222	 */
   223	export interface CorrelationCell {
   224	  x: string;
   225	  y: string;
   226	  value: number;
   227	}
   228
   229	export interface CorrelationResponse {
   230	  /** Square matrix of Pearson correlation coefficients. */
   231	  correlation_matrix: number[][];
   232	  correlation_melted: CorrelationCell[];
   233	}
   234
   235	export type ClusterType = 'clusters';
   236
   237	export interface NetworkEdgesParams {
   238	  cluster_type?: 'clusters';
   239	  min_confidence?: '400';
   240	  max_edges?: '10000';
   241	}
   242
   243	export interface NetworkNode {
   244	  hgnc_id: string;
   245	  symbol: string;
   246	  cluster: string | number;
   247	  degree: number;
   248	  category?: string;
   249	  x?: number;
   250	  y?: number;
   251	  layout_x?: number;
   252	  layout_y?: number;
   253	  igraph_x?: number;
   254	  igraph_y?: number;
   255	  [key: string]: unknown;
   256	}
   257
   258	export interface NetworkEdge {
   259	  source: string;
   260	  target: string;
   261	  confidence: number;
   262	}
   263
   264	export interface NetworkMetadata {
   265	  node_count: number;
   266	  edge_count: number;
   267	  cluster_count: number;
   268	  total_edges: number;
   269	  edges_filtered: boolean;
   270	  string_version?: string;
   271	  min_confidence?: number;
   272	  elapsed_seconds: number;
   273	  category_counts?: Record<string, number>;
   274	  layout_algorithm?: string;
   275	  layout_engine?: string;
   276	  display_layout_status?: 'available' | 'missing' | 'invalid' | 'error';
   277	  display_layout_key?: string;
   278	  display_layout_version?: number;
   279	  display_layout_duration_ms?: number;
   280	  display_layout_node_count?: number;
   281	  display_layout_edge_count?: number;
   282	  layout_time_seconds?: number;
   283	  total_ndd_genes?: number;
   284	  genes_with_string?: number;
   285	  genes_in_clusters?: number;
   286	  snapshot?: AnalysisSnapshotMeta;
   287	  [key: string]: unknown;
   288	}
   289
   290	export interface NetworkEdgesResponse {
   291	  nodes: NetworkNode[];
   292	  edges: NetworkEdge[];
   293	  metadata: NetworkMetadata;
   294	}
   295
   296	export type NetworkResponse = NetworkEdgesResponse;
   297
   298	export interface ClusterSummaryParams {
   299	  cluster_hash: string;
   300	  cluster_number: string;
   301	}
   302
   303	/**
   304	 * Response shape from `get_cluster_summary()` (functional + phenotype). The
   305	 * `summary_json` field is an opaque structured blob produced by the LLM.
   306	 */
   307	export interface ClusterSummary {
   308	  cluster_hash: string;
   309	  cluster_number: number | string;
   310	  summary_json: Record<string, unknown>;
   311	  validation_status?: string;
   312	  generated_at?: string;
   313	  /**
   314	   * Terminal "could not be validated" state (#490). When the judge rejected the
   315	   * cluster's summary the API returns HTTP 200 with `summary_available = false`,
   316	   * `validation_status = 'rejected'`, and a `reason` — distinct from a 404 "not
   317	   * yet generated". Plumber may array-wrap these scalars.
   318	   */
   319	  summary_available?: boolean | boolean[];
   320	  reason?: string | string[];
   321	  [key: string]: unknown;
   322	}
   323
   324	// ---------------------------------------------------------------------------
   325	// Helpers
   326	// ---------------------------------------------------------------------------
   327
   328	/**
   329	 * GET /api/analysis/functional_clustering
   330	 * Mirrors api/endpoints/analysis_endpoints.R:51 (handler `@get functional_clustering`).
   331	 *
   332	 * Cursor-paginated public functional clusters (STRINGdb + Leiden preset).
   333	 * Public — no auth.
   334	 */
   335	export async function getFunctionalClustering(
   336	  params: FunctionalClusteringParams = {},
   337	  config?: AxiosRequestConfig
   338	): Promise<FunctionalClusteringResponse> {
   339	  return apiClient.get<FunctionalClusteringResponse>('/api/analysis/functional_clustering', {
   340	    ...config,
   341	    params: { ...(config?.params as object | undefined), ...params },
   342	  });
   343	}
   344
   345	/**
   346	 * GET /api/analysis/phenotype_clustering
   347	 * Mirrors api/endpoints/analysis_endpoints.R:236 (handler `@get phenotype_clustering`).
   348	 *
   349	 * MCA + hierarchical clustering of entities by phenotype.
   350	 */
   351	export async function getPhenotypeClustering(
   352	  config?: AxiosRequestConfig
   353	): Promise<PhenotypeClusteringResponse> {
   354	  return apiClient.get<PhenotypeClusteringResponse>('/api/analysis/phenotype_clustering', config);
   355	}
   356
   357	/**
   358	 * GET /api/analysis/phenotype_functional_cluster_correlation
   359	 * Mirrors api/endpoints/analysis_endpoints.R:356 (handler `@get phenotype_functional_cluster_correlation`).
   360	 *

exec
/bin/bash -lc "rg -n -C 5 'service_analysis_snapshot_status|analysis_snapshot_status' api
rg -n -C 5 'analysis_snapshot_release_layers' api/functions/analysis-snapshot-release.R api/functions/analysis-snapshot-release-*.R
nl -ba app/src/views/analyses/DataReleases.spec.ts | sed -n '1,320p'
nl -ba app/src/components/analyses/ReleaseManifestPanel.spec.ts | sed -n '1,280p'
nl -ba app/src/components/analyses/dataReleaseTable.spec.ts | sed -n '1,240p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
api/functions/analysis-snapshot-repository.R-333-  if (!is.null(current_source_data_version)) {
api/functions/analysis-snapshot-repository.R-334-    manifest$current_source_data_version <- as.character(current_source_data_version)[1]
api/functions/analysis-snapshot-repository.R-335-  }
api/functions/analysis-snapshot-repository.R-336-
api/functions/analysis-snapshot-repository.R-337-  manifest <- manifest[1, , drop = FALSE]
api/functions/analysis-snapshot-repository.R:338:  status_code <- analysis_snapshot_status_code(manifest)
api/functions/analysis-snapshot-repository.R-339-  if (identical(status_code, "available") &&
api/functions/analysis-snapshot-repository.R-340-      identical(as.character(analysis_type[[1]]), "phenotype_functional_correlations")) {
api/functions/analysis-snapshot-repository.R-341-    if (!exists("analysis_snapshot_dependency_status_code", mode = "function")) {
api/functions/analysis-snapshot-repository.R-342-      status_code <- "dependency_snapshot_mismatch"
api/functions/analysis-snapshot-repository.R-343-    } else {
--
api/functions/analysis-snapshot-repository.R-385-      conn = conn
api/functions/analysis-snapshot-repository.R-386-    )
api/functions/analysis-snapshot-repository.R-387-  )
api/functions/analysis-snapshot-repository.R-388-}
api/functions/analysis-snapshot-repository.R-389-
api/functions/analysis-snapshot-repository.R:390:analysis_snapshot_status_code <- function(row) {
api/functions/analysis-snapshot-repository.R-391-  if (is.null(row) || length(row) == 0L || (is.data.frame(row) && nrow(row) == 0L)) {
api/functions/analysis-snapshot-repository.R-392-    return("snapshot_missing")
api/functions/analysis-snapshot-repository.R-393-  }
api/functions/analysis-snapshot-repository.R-394-
api/functions/analysis-snapshot-repository.R-395-  # Source-data version is the primary freshness signal (more informative when
--
api/functions/analysis-snapshot-repository.R-495-
api/functions/analysis-snapshot-repository.R-496-  manifest <- manifest[1, , drop = FALSE]
api/functions/analysis-snapshot-repository.R-497-  if (!is.null(current_source_data_version)) {
api/functions/analysis-snapshot-repository.R-498-    manifest$current_source_data_version <- as.character(current_source_data_version)[1]
api/functions/analysis-snapshot-repository.R-499-  }
api/functions/analysis-snapshot-repository.R:500:  manifest$status_code <- analysis_snapshot_status_code(manifest)
api/functions/analysis-snapshot-repository.R-501-  manifest
api/functions/analysis-snapshot-repository.R-502-}
api/functions/analysis-snapshot-repository.R-503-
api/functions/analysis-snapshot-repository.R-504-#' Cheap "is the active public snapshot CURRENT?" probe.
api/functions/analysis-snapshot-repository.R-505-#'
--
api/endpoints/admin_analysis_snapshot_endpoints.R-73-#* @serializer unboxedJSON
api/endpoints/admin_analysis_snapshot_endpoints.R-74-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-75-#* @get /snapshots/status
api/endpoints/admin_analysis_snapshot_endpoints.R-76-function(req, res) {
api/endpoints/admin_analysis_snapshot_endpoints.R-77-  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R:78:  service_analysis_snapshot_status()
api/endpoints/admin_analysis_snapshot_endpoints.R-79-}
api/endpoints/admin_analysis_snapshot_endpoints.R-80-
api/endpoints/admin_analysis_snapshot_endpoints.R-81-## -------------------------------------------------------------------##
api/endpoints/admin_analysis_snapshot_endpoints.R-82-## Analysis-snapshot RELEASES: admin routes (#573 Slice A / Task A7)
api/endpoints/admin_analysis_snapshot_endpoints.R-83-## -------------------------------------------------------------------##
--
api/services/analysis-snapshot-refresh-service.R-206-#' @param presets Optional preset list (defaults to the supported presets).
api/services/analysis-snapshot-refresh-service.R-207-#' @param manifest_fn Injectable manifest read (default `analysis_snapshot_public_manifest`).
api/services/analysis-snapshot-refresh-service.R-208-#' @param conn Optional DB connection/pool.
api/services/analysis-snapshot-refresh-service.R-209-#' @return list(presets = list(per-preset state), summary = counts).
api/services/analysis-snapshot-refresh-service.R-210-#' @export
api/services/analysis-snapshot-refresh-service.R:211:service_analysis_snapshot_status <- function(presets = NULL,
api/services/analysis-snapshot-refresh-service.R-212-                                             manifest_fn = analysis_snapshot_public_manifest,
api/services/analysis-snapshot-refresh-service.R-213-                                             conn = NULL) {
api/services/analysis-snapshot-refresh-service.R-214-  if (is.null(presets)) {
api/services/analysis-snapshot-refresh-service.R-215-    presets <- analysis_snapshot_supported_presets()
api/services/analysis-snapshot-refresh-service.R-216-  }
--
api/services/analysis-snapshot-service.R-53-
api/services/analysis-snapshot-service.R-54-  status_code <- snapshot$status_code %||% "available"
api/services/analysis-snapshot-service.R-55-  if (!identical(status_code, "available")) {
api/services/analysis-snapshot-service.R-56-    return(service_analysis_snapshot_problem(
api/services/analysis-snapshot-service.R-57-      code = status_code,
api/services/analysis-snapshot-service.R:58:      message = service_analysis_snapshot_status_message(status_code),
api/services/analysis-snapshot-service.R-59-      status = 503L,
api/services/analysis-snapshot-service.R-60-      analysis_type = normalized$analysis_type,
api/services/analysis-snapshot-service.R-61-      retry_after = 60L
api/services/analysis-snapshot-service.R-62-    ))
api/services/analysis-snapshot-service.R-63-  }
--
api/services/analysis-snapshot-service.R-72-  )
api/services/analysis-snapshot-service.R-73-
api/services/analysis-snapshot-service.R-74-  list(status = 200L, body = body)
api/services/analysis-snapshot-service.R-75-}
api/services/analysis-snapshot-service.R-76-
api/services/analysis-snapshot-service.R:77:service_analysis_snapshot_status_message <- function(status_code) {
api/services/analysis-snapshot-service.R-78-  switch(status_code,
api/services/analysis-snapshot-service.R-79-    snapshot_stale = "The active public analysis snapshot is stale and should be refreshed before serving.",
api/services/analysis-snapshot-service.R-80-    source_version_mismatch = paste(
api/services/analysis-snapshot-service.R-81-      "The active public analysis snapshot was built from a different",
api/services/analysis-snapshot-service.R-82-      "public source-data version and should be refreshed before serving."
--
api/services/mcp-analysis-service.R-282-    budget = trimmed$budget,
api/services/mcp-analysis-service.R-283-    notice = "Comparison sources are cross-references and do not alter curated SysNDD classifications."
api/services/mcp-analysis-service.R-284-  ))
api/services/mcp-analysis-service.R-285-}
api/services/mcp-analysis-service.R-286-
api/services/mcp-analysis-service.R:287:mcp_analysis_snapshot_status <- function(analysis_type, params = list()) {
api/services/mcp-analysis-service.R-288-  status <- if (exists("mcp_analysis_repo_public_snapshot_status", mode = "function")) {
api/services/mcp-analysis-service.R-289-    tryCatch(
api/services/mcp-analysis-service.R-290-      mcp_analysis_repo_public_snapshot_status(analysis_type, params),
api/services/mcp-analysis-service.R-291-      error = function(e) "snapshot_missing"
api/services/mcp-analysis-service.R-292-    )
--
api/services/mcp-analysis-service.R-376-    "public-ready analysis snapshots",
api/services/mcp-analysis-service.R-377-    "snapshot_worker"
api/services/mcp-analysis-service.R-378-  )
api/services/mcp-analysis-service.R-379-  snapshot_status <- switch(
api/services/mcp-analysis-service.R-380-    mode,
api/services/mcp-analysis-service.R:381:    correlations = mcp_analysis_snapshot_status("phenotype_correlations", list()),
api/services/mcp-analysis-service.R:382:    clusters = mcp_analysis_snapshot_status("phenotype_clusters", list()),
api/services/mcp-analysis-service.R:383:    phenotype_functional_correlations = mcp_analysis_snapshot_status("phenotype_functional_correlations", list()),
api/services/mcp-analysis-service.R-384-    "snapshot_missing"
api/services/mcp-analysis-service.R-385-  )
api/services/mcp-analysis-service.R-386-  snapshot_available <- identical(snapshot_status, "available")
api/services/mcp-analysis-service.R-387-
api/services/mcp-analysis-service.R-388-  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
--
api/services/mcp-analysis-service.R-520-    "curated_derived_analysis",
api/services/mcp-analysis-service.R-521-    "SysNDD STRING-derived network analysis",
api/services/mcp-analysis-service.R-522-    "public-ready analysis snapshots",
api/services/mcp-analysis-service.R-523-    "snapshot_worker"
api/services/mcp-analysis-service.R-524-  )
api/services/mcp-analysis-service.R:525:  snapshot_status <- mcp_analysis_snapshot_status(
api/services/mcp-analysis-service.R-526-    "gene_network_edges",
api/services/mcp-analysis-service.R-527-    list(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L)
api/services/mcp-analysis-service.R-528-  )
api/services/mcp-analysis-service.R-529-  snapshot_available <- identical(snapshot_status, "available")
api/services/mcp-analysis-service.R-530-  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
--
api/tests/testthat/test-unit-analysis-snapshot-repository.R-46-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-47-test_that("snapshot status helpers classify missing and stale rows", {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-48-  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-49-  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-50-
api/tests/testthat/test-unit-analysis-snapshot-repository.R:51:  expect_equal(analysis_snapshot_status_code(NULL), "snapshot_missing")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-52-  stale <- list(stale_after = Sys.time() - 60)
api/tests/testthat/test-unit-analysis-snapshot-repository.R:53:  expect_equal(analysis_snapshot_status_code(stale), "snapshot_stale")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-54-  fresh <- list(stale_after = Sys.time() + 60)
api/tests/testthat/test-unit-analysis-snapshot-repository.R:55:  expect_equal(analysis_snapshot_status_code(fresh), "available")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-56-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-57-  # #483: a fresh, source-current manifest built under an OLDER snapshot schema
api/tests/testthat/test-unit-analysis-snapshot-repository.R-58-  # must be flagged for rebuild (was ignored -> served the old-schema snapshot).
api/tests/testthat/test-unit-analysis-snapshot-repository.R-59-  old_schema <- list(stale_after = Sys.time() + 60, schema_version = "1.0")
api/tests/testthat/test-unit-analysis-snapshot-repository.R:60:  expect_equal(analysis_snapshot_status_code(old_schema), "schema_version_mismatch")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-61-  current_schema <- list(
api/tests/testthat/test-unit-analysis-snapshot-repository.R-62-    stale_after = Sys.time() + 60,
api/tests/testthat/test-unit-analysis-snapshot-repository.R-63-    schema_version = ANALYSIS_SNAPSHOT_SCHEMA_VERSION
api/tests/testthat/test-unit-analysis-snapshot-repository.R-64-  )
api/tests/testthat/test-unit-analysis-snapshot-repository.R:65:  expect_equal(analysis_snapshot_status_code(current_schema), "available")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-66-})
api/tests/testthat/test-unit-analysis-snapshot-repository.R-67-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-68-test_that("analysis_snapshot_public_current is TRUE only for a current (available) snapshot", {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-69-  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-70-  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)
--
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-205-  )
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-206-  expect_true(res)
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-207-})
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-208-
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-209-test_that("status maps a missing manifest to state=missing for all presets", {
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R:210:  summary <- service_analysis_snapshot_status(manifest_fn = function(...) NULL)
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-211-  expect_equal(summary$summary$total, 5L)
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-212-  expect_equal(summary$summary$missing, 5L)
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-213-  expect_equal(summary$summary$available, 0L)
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-214-  expect_true(all(vapply(summary$presets, function(p) identical(p$state, "missing"), logical(1))))
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-215-})
--
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-224-      source_data_version = "abc123",
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-225-      row_counts_json = "{\"network_node\":10}",
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-226-      stringsAsFactors = FALSE
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-227-    )
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-228-  }
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R:229:  summary <- service_analysis_snapshot_status(manifest_fn = fake_manifest)
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-230-  expect_equal(summary$summary$available, 5L)
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-231-  expect_equal(summary$summary$missing, 0L)
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-232-  expect_equal(summary$presets[[1]]$state, "available")
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-233-  expect_equal(summary$presets[[1]]$source_data_version, "abc123")
api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R-234-})
api/functions/analysis-snapshot-release-manifest.R-22-#' the archive path prefix for that layer's files, and whether a
api/functions/analysis-snapshot-release-manifest.R-23-#' reproducibility bundle is expected for it.
api/functions/analysis-snapshot-release-manifest.R-24-#'
api/functions/analysis-snapshot-release-manifest.R-25-#' @return list of `list(analysis_type, params, files_prefix,
api/functions/analysis-snapshot-release-manifest.R-26-#'   has_reproducibility)`.
api/functions/analysis-snapshot-release-manifest.R:27:analysis_snapshot_release_layers <- function() {
api/functions/analysis-snapshot-release-manifest.R-28-  list(
api/functions/analysis-snapshot-release-manifest.R-29-    list(
api/functions/analysis-snapshot-release-manifest.R-30-      analysis_type = "functional_clusters",
api/functions/analysis-snapshot-release-manifest.R-31-      params = list(algorithm = "leiden"),
api/functions/analysis-snapshot-release-manifest.R-32-      files_prefix = "functional_clusters",
--
api/functions/analysis-snapshot-release-manifest.R-50-#' Resolve a caller-supplied `layers` request to authoritative REGISTRY entries.
api/functions/analysis-snapshot-release-manifest.R-51-#'
api/functions/analysis-snapshot-release-manifest.R-52-#' `layers` in a build request is a SELECTION, never a policy redefinition: each
api/functions/analysis-snapshot-release-manifest.R-53-#' requested entry is read ONLY for its `analysis_type` (accepting either a bare
api/functions/analysis-snapshot-release-manifest.R-54-#' string or a `{analysis_type, ...}` object), matched against the authoritative
api/functions/analysis-snapshot-release-manifest.R:55:#' `analysis_snapshot_release_layers()` registry, and the REGISTRY entry is
api/functions/analysis-snapshot-release-manifest.R-56-#' returned — so the caller can never override `params`, `files_prefix`, or the
api/functions/analysis-snapshot-release-manifest.R-57-#' gate-controlling `has_reproducibility` (which would let an Admin skip the hard
api/functions/analysis-snapshot-release-manifest.R-58-#' coherence / reproducibility gates, or path-traverse via `files_prefix`).
api/functions/analysis-snapshot-release-manifest.R-59-#'
api/functions/analysis-snapshot-release-manifest.R-60-#' NULL/absent `requested` -> the full registry unchanged. An unknown or
--
api/functions/analysis-snapshot-release-manifest.R-62-#'
api/functions/analysis-snapshot-release-manifest.R-63-#' @param requested NULL, or a list of selectors (strings or `{analysis_type}`).
api/functions/analysis-snapshot-release-manifest.R-64-#' @return list of registry layer entries (a subset of the registry, in request
api/functions/analysis-snapshot-release-manifest.R-65-#'   order).
api/functions/analysis-snapshot-release-manifest.R-66-analysis_snapshot_release_resolve_layers <- function(requested = NULL) {
api/functions/analysis-snapshot-release-manifest.R:67:  registry <- analysis_snapshot_release_layers()
api/functions/analysis-snapshot-release-manifest.R-68-  if (is.null(requested) || length(requested) == 0L) {
api/functions/analysis-snapshot-release-manifest.R-69-    return(registry)
api/functions/analysis-snapshot-release-manifest.R-70-  }
api/functions/analysis-snapshot-release-manifest.R-71-
api/functions/analysis-snapshot-release-manifest.R-72-  registry_types <- vapply(registry, function(layer) layer$analysis_type, character(1))
--
api/functions/analysis-snapshot-release.R-170-# Orchestrator
api/functions/analysis-snapshot-release.R-171-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release.R-172-
api/functions/analysis-snapshot-release.R-173-#' Build (and optionally publish) an immutable analysis-snapshot release.
api/functions/analysis-snapshot-release.R-174-#'
api/functions/analysis-snapshot-release.R:175:#' @param layers Layer registry (default `analysis_snapshot_release_layers()`).
api/functions/analysis-snapshot-release.R-176-#' @param title,scope_statement,license Presentation metadata (excluded from the
api/functions/analysis-snapshot-release.R-177-#'   content digest / release identity).
api/functions/analysis-snapshot-release.R-178-#' @param publish If TRUE the inserted draft is flipped to `published`.
api/functions/analysis-snapshot-release.R-179-#' @param created_by Optional user id recorded on the head row.
api/functions/analysis-snapshot-release.R-180-#' @param conn A real DBIConnection (required for persistence; A5 checks one out).
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
    57	      release_id: 'asr_0123456789abcdef',
    58	      release_version: null,
    59	      title: 'SysNDD analysis-snapshot release',
    60	      created_at: '2026-07-01T00:00:00Z',
    61	      license: 'CC-BY-4.0',
    62	      scope_statement: 'Public derived analysis only.',
    63	      generator: 'sysndd-api',
    64	      source: 'sysndd',
    65	      layers: [
    66	        {
    67	          analysis_type: 'functional_clusters',
    68	          parameter_hash: 'fp-hash',
    69	          snapshot_id: 101,
    70	          input_hash: 'in-func',
    71	          payload_hash: 'pay-func',
    72	          schema_version: '1.2',
    73	          reproducibility_hash: 'repro-func',
    74	          dependencies: null,
    75	        },
    76	      ],
    77	      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
    78	      content_digest: 'a'.repeat(64),
    79	    },
    80	  };
    81	}
    82
    83	function notFoundError() {
    84	  return Object.assign(new Error('Not found'), {
    85	    isAxiosError: true,
    86	    response: { status: 404, data: { message: 'No published analysis-snapshot release exists yet' } },
    87	  });
    88	}
    89
    90	describe('DataReleases', () => {
    91	  beforeEach(() => {
    92	    vi.clearAllMocks();
    93	    // jsdom has no real object-URL / anchor-download support.
    94	    window.URL.createObjectURL = vi.fn(() => 'blob:mock-url');
    95	    window.URL.revokeObjectURL = vi.fn();
    96	  });
    97
    98	  it('renders the release table row and the manifest panel for the latest release', async () => {
    99	    listReleasesMock.mockResolvedValue({
   100	      releases: [makeReleaseHead()],
   101	      pagination: { limit: 50, offset: 0, count: 1 },
   102	    });
   103	    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
   104
   105	    const wrapper = mount(DataReleases);
   106	    await flushPromises();
   107
   108	    expect(listReleasesMock).toHaveBeenCalled();
   109	    expect(getLatestReleaseMock).toHaveBeenCalled();
   110	    const text = wrapper.text();
   111	    expect(text).toContain('asr_0123456789abcdef');
   112	    expect(text).toContain('Integrity hashes');
   113	    expect(text).toContain('a'.repeat(64));
   114	  });
   115
   116	  it('re-fetches the detail for a different release when its "View manifest" button is clicked', async () => {
   117	    listReleasesMock.mockResolvedValue({
   118	      releases: [makeReleaseHead({ release_id: 'asr_other' })],
   119	      pagination: { limit: 50, offset: 0, count: 1 },
   120	    });
   121	    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
   122	    getReleaseMock.mockResolvedValue(makeReleaseDetail({ release_id: 'asr_other' }));
   123
   124	    const wrapper = mount(DataReleases);
   125	    await flushPromises();
   126
   127	    const button = wrapper
   128	      .findAll('button')
   129	      .find((btn) => btn.text().includes('View manifest'));
   130	    expect(button).toBeTruthy();
   131	    await button!.trigger('click');
   132	    await flushPromises();
   133
   134	    expect(getReleaseMock).toHaveBeenCalledWith('asr_other');
   135	  });
   136
   137	  it('downloads the bundle when the download-bundle button is clicked', async () => {
   138	    listReleasesMock.mockResolvedValue({
   139	      releases: [makeReleaseHead()],
   140	      pagination: { limit: 50, offset: 0, count: 1 },
   141	    });
   142	    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
   143	    downloadReleaseBundleMock.mockResolvedValue(new Blob(['bundle-bytes']));
   144
   145	    const wrapper = mount(DataReleases);
   146	    await flushPromises();
   147
   148	    await wrapper.find('[data-testid="download-bundle-button"]').trigger('click');
   149	    await flushPromises();
   150
   151	    expect(downloadReleaseBundleMock).toHaveBeenCalledWith('asr_0123456789abcdef');
   152	  });
   153
   154	  it('shows the "No releases published yet" empty state on a 404 from getLatestRelease, not a raw error', async () => {
   155	    listReleasesMock.mockResolvedValue({
   156	      releases: [],
   157	      pagination: { limit: 50, offset: 0, count: 0 },
   158	    });
   159	    getLatestReleaseMock.mockRejectedValue(notFoundError());
   160
   161	    const wrapper = mount(DataReleases);
   162	    await flushPromises();
   163
   164	    expect(wrapper.text()).toContain('No releases published yet');
   165	    expect(wrapper.find('[data-testid="section-card-error"]').exists()).toBe(false);
   166	  });
   167	});
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
    35	      generator: 'sysndd-api',
    36	      source: 'sysndd',
    37	      layers: [
    38	        {
    39	          analysis_type: 'functional_clusters',
    40	          parameter_hash: 'fp-hash',
    41	          snapshot_id: 101,
    42	          input_hash: 'in-func',
    43	          payload_hash: 'pay-func',
    44	          schema_version: '1.2',
    45	          reproducibility_hash: 'repro-func',
    46	          dependencies: null,
    47	        },
    48	        {
    49	          analysis_type: 'phenotype_clusters',
    50	          parameter_hash: 'pp-hash',
    51	          snapshot_id: 202,
    52	          input_hash: 'in-pheno',
    53	          payload_hash: 'pay-pheno',
    54	          schema_version: '1.2',
    55	          reproducibility_hash: 'repro-pheno',
    56	          dependencies: null,
    57	        },
    58	        {
    59	          analysis_type: 'phenotype_functional_correlations',
    60	          parameter_hash: 'cp-hash',
    61	          snapshot_id: 303,
    62	          input_hash: 'in-corr',
    63	          payload_hash: 'pay-corr',
    64	          schema_version: '1.2',
    65	          reproducibility_hash: null,
    66	          dependencies: {
    67	            functional_clusters: { snapshot_id: 101, payload_hash: 'pay-func' },
    68	            phenotype_clusters: { snapshot_id: 202, payload_hash: 'pay-pheno' },
    69	          },
    70	        },
    71	      ],
    72	      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
    73	      content_digest: 'a'.repeat(64),
    74	    },
    75	  };
    76	}
    77
    78	describe('ReleaseManifestPanel', () => {
    79	  it('renders all three integrity hashes', () => {
    80	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
    81	    const text = wrapper.text();
    82	    expect(text).toContain('a'.repeat(64)); // content_digest
    83	    expect(text).toContain('b'.repeat(64)); // manifest_sha256
    84	    expect(text).toContain('c'.repeat(64)); // bundle_sha256
    85	  });
    86
    87	  it('shows the correlation layer dependency lineage and its "n/a" reproducibility hash', () => {
    88	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
    89	    const text = wrapper.text();
    90	    expect(text).toContain('n/a (not reproducible)');
    91	    expect(text).toContain('Dependency lineage');
    92	    expect(text).toContain('pay-func');
    93	    expect(text).toContain('pay-pheno');
    94	    expect(text).toContain('101');
    95	    expect(text).toContain('202');
    96	  });
    97
    98	  it('renders the version DOI as a doi.org link', () => {
    99	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   100	    const link = wrapper.find('a[href="https://doi.org/10.5281/zenodo.1234"]');
   101	    expect(link.exists()).toBe(true);
   102	    expect(link.text()).toBe('10.5281/zenodo.1234');
   103	  });
   104
   105	  it('shows "not yet assigned" when a DOI is null', () => {
   106	    const release = makeReleaseDetail();
   107	    release.zenodo = { record_url: null, version_doi: null, concept_doi: null };
   108	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   109	    expect(wrapper.text()).toContain('not yet assigned');
   110	  });
   111
   112	  it('omits the Version row when release_version is null (the current, always-null default)', () => {
   113	    const release = makeReleaseDetail();
   114	    expect(release.release_version).toBeNull();
   115	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   116	    const dts = wrapper.findAll('dt').map((dt) => dt.text());
   117	    expect(dts).not.toContain('Version');
   118	  });
   119
   120	  it('shows the Version row when release_version is populated', () => {
   121	    const release = makeReleaseDetail();
   122	    release.release_version = '1.0';
   123	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   124	    const dts = wrapper.findAll('dt').map((dt) => dt.text());
   125	    expect(dts).toContain('Version');
   126	    expect(wrapper.text()).toContain('1.0');
   127	  });
   128
   129	  it('falls back to release_id for the title when title is null', () => {
   130	    const release = makeReleaseDetail();
   131	    release.title = null;
   132	    const wrapper = mount(ReleaseManifestPanel, { props: { release } });
   133	    expect(wrapper.find('#release-manifest-panel-title').text()).toBe('asr_0123456789abcdef');
   134	    const dts = wrapper.findAll('dt').map((dt) => dt.text());
   135	    const titleDd = wrapper.findAll('dt').find((dt) => dt.text() === 'Title')?.element.nextElementSibling;
   136	    expect(dts).toContain('Title');
   137	    expect(titleDd?.textContent).toBe('asr_0123456789abcdef');
   138	  });
   139
   140	  it('copies a hash to the clipboard when its copy button is clicked', async () => {
   141	    const writeText = vi.fn().mockResolvedValue(undefined);
   142	    Object.defineProperty(navigator, 'clipboard', {
   143	      configurable: true,
   144	      value: { writeText },
   145	    });
   146
   147	    const wrapper = mount(ReleaseManifestPanel, { props: { release: makeReleaseDetail() } });
   148	    const button = wrapper
   149	      .findAll('button')
   150	      .find((btn) => btn.attributes('aria-label') === 'Copy Content digest to clipboard');
   151	    expect(button).toBeTruthy();
   152
   153	    await button!.trigger('click');
   154	    await wrapper.vm.$nextTick();
   155
   156	    expect(writeText).toHaveBeenCalledWith('a'.repeat(64));
   157	    expect(button!.text()).toContain('Copied');
   158	  });
   159	});
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

exec
/bin/bash -lc "rg -n -C 4 'listReleases|downloadReleaseFile|ReleaseHead|release' app/src/api/analysis.spec.ts
nl -ba api/services/analysis-snapshot-refresh-service.R | sed -n '200,290p'
nl -ba api/functions/analysis-snapshot-release-manifest.R | sed -n '1,80p'
nl -ba app/src/router/routes.ts | sed -n '1,260p'
nl -ba app/src/assets/js/constants/main_nav_constants.ts | sed -n '1,320p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
12-  getNetworkEdges,
13-  getFunctionalClusterSummary,
14-  getPhenotypeClusterSummary,
15-  isSnapshotPreparingError,
16:  listReleases,
17-  getLatestRelease,
18-  getRelease,
19-  downloadReleaseManifest,
20:  downloadReleaseFile,
21-  downloadReleaseBundle,
22-  type FunctionalClusteringResponse,
23-  type PhenotypeCluster,
24-  type PhenotypeClusteringResponse,
25-  type CorrelationResponse,
26-  type NetworkEdgesResponse,
27-  type ClusterSummary,
28:  type ReleaseHead,
29-  type ReleaseDetail,
30-} from './analysis';
31-import { isApiError } from './client';
32-import { extractApiErrorMessage } from '@/utils/api-errors';
--
259-  });
260-});
261-
262-// ---------------------------------------------------------------------------
263:// Analysis-snapshot releases (#573 Slice B, Task B1)
264-// ---------------------------------------------------------------------------
265-
266:function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
267-  return {
268:    release_id: 'asr_0123456789abcdef',
269:    release_version: null,
270:    title: 'SysNDD analysis-snapshot release',
271-    status: 'published',
272-    content_digest: 'a'.repeat(64),
273-    created_at: '2026-07-01T00:00:00Z',
274-    published_at: '2026-07-01T00:05:00Z',
275-    source_data_version: '2026-07-01',
276:    db_release_version: '11.4.0',
277:    db_release_commit: 'deadbeef',
278-    manifest_sha256: 'b'.repeat(64),
279-    bundle_sha256: 'c'.repeat(64),
280-    license: 'CC-BY-4.0',
281-    file_count: 10,
--
284-    ...overrides,
285-  };
286-}
287-
288:describe('api/analysis — listReleases', () => {
289:  it('returns the releases envelope on 200', async () => {
290-    server.use(
291:      http.get('/api/analysis/releases', () =>
292-        HttpResponse.json({
293:          releases: [makeReleaseHead()],
294-          pagination: { limit: 50, offset: 0, count: 1 },
295-        })
296-      )
297-    );
298:    const result = await listReleases();
299:    expect(result.releases).toHaveLength(1);
300:    expect(result.releases[0].release_id).toBe('asr_0123456789abcdef');
301-    expect(result.pagination.count).toBe(1);
302-    // Public head allowlist: admin-only fields must never be present.
303:    expect(result.releases[0]).not.toHaveProperty('created_by_user_id');
304:    expect(result.releases[0]).not.toHaveProperty('last_error_message');
305-  });
306-
307-  it('forwards limit/offset query params', async () => {
308-    let observedQuery: URLSearchParams | null = null;
309-    server.use(
310:      http.get('/api/analysis/releases', ({ request }) => {
311-        observedQuery = new URL(request.url).searchParams;
312-        return HttpResponse.json({
313:          releases: [],
314-          pagination: { limit: 10, offset: 5, count: 0 },
315-        });
316-      })
317-    );
318:    await listReleases({ limit: 10, offset: 5 });
319-    const q = observedQuery as unknown as URLSearchParams;
320-    expect(q.get('limit')).toBe('10');
321-    expect(q.get('offset')).toBe('5');
322-  });
323-
324-  it('throws AxiosError on non-2xx', async () => {
325-    server.use(
326:      http.get('/api/analysis/releases', () =>
327-        HttpResponse.json({ message: 'boom' }, { status: 500 })
328-      )
329-    );
330-    let caught: unknown;
331-    try {
332:      await listReleases();
333-    } catch (err) {
334-      caught = err;
335-    }
336-    expect(isApiError(caught)).toBe(true);
--
340-
341-describe('api/analysis — getLatestRelease', () => {
342-  it('returns the head + manifest on 200', async () => {
343-    const detail: ReleaseDetail = {
344:      ...makeReleaseHead(),
345-      manifest: {
346:        release_id: 'asr_0123456789abcdef',
347:        release_version: null,
348:        title: 'SysNDD analysis-snapshot release',
349-        created_at: '2026-07-01T00:00:00Z',
350-        license: 'CC-BY-4.0',
351-        scope_statement: 'Public derived analysis only.',
352-        generator: 'sysndd-api',
--
355-        files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
356-        content_digest: 'a'.repeat(64),
357-      },
358-    };
359:    server.use(http.get('/api/analysis/releases/latest', () => HttpResponse.json(detail)));
360-    const result = await getLatestRelease();
361:    expect(result.release_id).toBe('asr_0123456789abcdef');
362-    expect(result.manifest.files).toHaveLength(1);
363-  });
364-
365:  it('throws AxiosError 404 when no published release exists', async () => {
366-    server.use(
367:      http.get('/api/analysis/releases/latest', () =>
368:        HttpResponse.json({ message: 'No published analysis-snapshot release exists yet' }, { status: 404 })
369-      )
370-    );
371-    let caught: unknown;
372-    try {
--
381-  });
382-});
383-
384-describe('api/analysis — getRelease', () => {
385:  it('returns the head + manifest on 200 and encodes the release id', async () => {
386-    let observedPath = '';
387-    const detail: ReleaseDetail = {
388:      ...makeReleaseHead({ release_id: 'asr_abc123' }),
389-      manifest: {
390:        release_id: 'asr_abc123',
391:        release_version: null,
392:        title: 'SysNDD analysis-snapshot release',
393-        created_at: '2026-07-01T00:00:00Z',
394-        license: 'CC-BY-4.0',
395-        scope_statement: 'Public derived analysis only.',
396-        generator: 'sysndd-api',
--
400-        content_digest: 'a'.repeat(64),
401-      },
402-    };
403-    server.use(
404:      http.get('/api/analysis/releases/:releaseId', ({ request, params }) => {
405-        observedPath = new URL(request.url).pathname;
406:        expect(params.releaseId).toBe('asr_abc123');
407-        return HttpResponse.json(detail);
408-      })
409-    );
410-    const result = await getRelease('asr_abc123');
411:    expect(result.release_id).toBe('asr_abc123');
412:    expect(observedPath).toBe('/api/analysis/releases/asr_abc123');
413-  });
414-
415:  it('throws AxiosError 404 for an unknown/draft release id', async () => {
416-    server.use(
417:      http.get('/api/analysis/releases/:releaseId', () =>
418-        HttpResponse.json({ message: 'not found' }, { status: 404 })
419-      )
420-    );
421-    let caught: unknown;
--
433-
434-describe('api/analysis — downloadReleaseManifest', () => {
435-  it('returns the manifest.json bytes as a Blob', async () => {
436-    server.use(
437:      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
438:        HttpResponse.json({ release_id: 'asr_abc123' })
439-      )
440-    );
441-    const blob = await downloadReleaseManifest('asr_abc123');
442-    expect(blob).toBeInstanceOf(Blob);
443-  });
444-
445-  it('throws AxiosError on non-2xx', async () => {
446-    server.use(
447:      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
448-        HttpResponse.json({ message: 'not found' }, { status: 404 })
449-      )
450-    );
451-    let caught: unknown;
--
457-    expect(isApiError(caught)).toBe(true);
458-  });
459-});
460-
461:describe('api/analysis — downloadReleaseFile', () => {
462-  it('forwards the file path as a query param and returns a Blob', async () => {
463-    let observedQuery: URLSearchParams | null = null;
464-    server.use(
465:      http.get('/api/analysis/releases/:releaseId/file', ({ request }) => {
466-        observedQuery = new URL(request.url).searchParams;
467-        return HttpResponse.json({ ok: true });
468-      })
469-    );
470:    const blob = await downloadReleaseFile('asr_abc123', 'functional_clusters/payload.json');
471-    expect(blob).toBeInstanceOf(Blob);
472-    const q = observedQuery as unknown as URLSearchParams;
473-    expect(q.get('path')).toBe('functional_clusters/payload.json');
474-  });
475-
476-  it('throws AxiosError on non-2xx (unknown file path)', async () => {
477-    server.use(
478:      http.get('/api/analysis/releases/:releaseId/file', () =>
479-        HttpResponse.json({ message: 'not found' }, { status: 404 })
480-      )
481-    );
482-    let caught: unknown;
483-    try {
484:      await downloadReleaseFile('asr_abc123', 'nope.json');
485-    } catch (err) {
486-      caught = err;
487-    }
488-    expect(isApiError(caught)).toBe(true);
--
494-
495-describe('api/analysis — downloadReleaseBundle', () => {
496-  it('returns the bundle.tar.gz bytes as a Blob', async () => {
497-    server.use(
498:      http.get('/api/analysis/releases/:releaseId/bundle', () =>
499-        HttpResponse.json({ ok: true })
500-      )
501-    );
502-    const blob = await downloadReleaseBundle('asr_abc123');
--
504-  });
505-
506-  it('throws AxiosError on non-2xx', async () => {
507-    server.use(
508:      http.get('/api/analysis/releases/:releaseId/bundle', () =>
509-        HttpResponse.json({ message: 'not found' }, { status: 404 })
510-      )
511-    );
512-    let caught: unknown;
   200	    results = results
   201	  )
   202	}
   203
   204	#' Per-preset public snapshot status overview.
   205	#'
   206	#' @param presets Optional preset list (defaults to the supported presets).
   207	#' @param manifest_fn Injectable manifest read (default `analysis_snapshot_public_manifest`).
   208	#' @param conn Optional DB connection/pool.
   209	#' @return list(presets = list(per-preset state), summary = counts).
   210	#' @export
   211	service_analysis_snapshot_status <- function(presets = NULL,
   212	                                             manifest_fn = analysis_snapshot_public_manifest,
   213	                                             conn = NULL) {
   214	  if (is.null(presets)) {
   215	    presets <- analysis_snapshot_supported_presets()
   216	  }
   217	  preset_states <- list()
   218	  total <- 0L
   219	  available <- 0L
   220	  missing <- 0L
   221	  stale <- 0L
   222	  mismatch <- 0L
   223
   224	  for (preset in presets) {
   225	    normalized <- analysis_snapshot_normalize_params(preset$analysis_type, preset$params)
   226	    at <- normalized$analysis_type
   227	    ph <- normalized$parameter_hash
   228	    manifest <- tryCatch(manifest_fn(at, ph, conn = conn), error = function(e) NULL)
   229	    total <- total + 1L
   230
   231	    if (is.null(manifest)) {
   232	      missing <- missing + 1L
   233	      preset_states[[length(preset_states) + 1L]] <- list(
   234	        analysis_type = at, parameter_hash = ph, state = "missing",
   235	        generated_at = NA_character_, activated_at = NA_character_,
   236	        stale_after = NA_character_, source_data_version = NA_character_,
   237	        row_counts = NULL
   238	      )
   239	      next
   240	    }
   241
   242	    status_code <- service_analysis_snapshot_scalar_value(manifest$status_code, "available")
   243	    state <- switch(status_code,
   244	      available = "available",
   245	      snapshot_stale = "stale",
   246	      source_version_mismatch = "source_version_mismatch",
   247	      snapshot_missing = "missing",
   248	      status_code
   249	    )
   250	    if (identical(state, "available")) {
   251	      available <- available + 1L
   252	    } else if (identical(state, "stale")) {
   253	      stale <- stale + 1L
   254	    } else if (identical(state, "source_version_mismatch")) {
   255	      mismatch <- mismatch + 1L
   256	    } else if (identical(state, "missing")) {
   257	      missing <- missing + 1L
   258	    }
   259
   260	    preset_states[[length(preset_states) + 1L]] <- list(
   261	      analysis_type = at,
   262	      parameter_hash = ph,
   263	      state = state,
   264	      generated_at = service_analysis_snapshot_time_string(
   265	        service_analysis_snapshot_scalar_value(manifest$generated_at)
   266	      ),
   267	      activated_at = service_analysis_snapshot_time_string(
   268	        service_analysis_snapshot_scalar_value(manifest$activated_at)
   269	      ),
   270	      stale_after = service_analysis_snapshot_time_string(
   271	        service_analysis_snapshot_scalar_value(manifest$stale_after)
   272	      ),
   273	      source_data_version = service_analysis_snapshot_scalar_value(
   274	        manifest$source_data_version, NA_character_
   275	      ),
   276	      row_counts = service_analysis_snapshot_record_counts(manifest)
   277	    )
   278	  }
   279
   280	  list(
   281	    presets = preset_states,
   282	    summary = list(
   283	      total = total, available = available, missing = missing,
   284	      stale = stale, mismatch = mismatch
   285	    )
   286	  )
   287	}
   288
   289	#' Startup bootstrap: enqueue refresh jobs for missing presets (idempotent).
   290	#'
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
   221	      // 2) The time plot
   222	      {
   223	        path: 'TimePlot',
   224	        name: 'PublicationsNDDTimePlot',
   225	        component: () => import('@/components/analyses/PublicationsNDDTimePlot.vue'),
   226	      },
   227	      // 3) The stats bar plot
   228	      {
   229	        path: 'Stats',
   230	        name: 'PublicationsNDDStats',
   231	        component: () => import('@/components/analyses/PublicationsNDDStats.vue'),
   232	      },
   233	    ],
   234	    meta: {
   235	      sitemap: {
   236	        priority: 0.7,
   237	        changefreq: 'monthly',
   238	      },
   239	    },
   240	  },
   241	  {
   242	    path: '/PubtatorNDD',
   243	    component: () => import('@/views/analyses/PubtatorNDD.vue'),
   244	    // Example children: your table, genes, stats, etc. Expand as needed:
   245	    children: [
   246	      {
   247	        path: '',
   248	        name: 'PubtatorNDDTable',
   249	        component: () => import('@/components/analyses/PubtatorNDDTable.vue'),
   250	      },
   251	      {
   252	        path: 'PubtatorNDDGenes',
   253	        name: 'PubtatorNDDGenes',
   254	        component: () => import('@/components/analyses/PubtatorNDDGenes.vue'),
   255	      },
   256	      {
   257	        path: 'Stats',
   258	        name: 'PubtatorNDDStats',
   259	        component: () => import('@/components/analyses/PubtatorNDDStats.vue'),
   260	      },
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
   161	      required: ['view'],
   162	      align: 'right',
   163	      items: [
   164	        { text: 'View profile', path: '/User', icons: ['person-circle'] },
   165	        {
   166	          text: 'Token',
   167	          action: 'refreshWithJWT',
   168	          icons: ['arrow-repeat'],
   169	          component: 'LogoutCountdownBadge',
   170	        },
   171	        { text: 'Sign out', action: 'doUserLogOut', icons: ['x-circle'] },
   172	      ],
   173	    },
   174	  ] satisfies NavDropdown[],
   175	} as const;
   176
   177	export default MAIN_NAV;
   178
   179	export const { DROPDOWN_ITEMS_LEFT, DROPDOWN_ITEMS_RIGHT } = MAIN_NAV;
   180
   181	/** Type for accessing main navigation configuration */
   182	export type MainNavConfig = typeof MAIN_NAV;

exec
/bin/bash -lc "rg -n -C 5 'DataReleases|ManageAnalysisReleases' app/src/router/routes.ts
nl -ba app/src/api/analysis.spec.ts | sed -n '250,550p'
nl -ba app/src/utils/api-errors.ts | sed -n '1,240p'
git diff --check origin/master...HEAD -- ':(exclude).planning/**'
find app/src -type f \\( -name '*.ts' -o -name '*.vue' \\) -printf '%s %p\\n' | sort -nr | head -30" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
273-        changefreq: 'monthly',
274-      },
275-    },
276-  },
277-  {
278:    path: '/DataReleases',
279:    name: 'DataReleases',
280:    component: () => import('@/views/analyses/DataReleases.vue'),
281-    meta: {
282-      sitemap: {
283-        priority: 0.7,
284-        changefreq: 'monthly',
285-      },
--
499-    'ManagePubtator',
500-    'ManageLLM',
501-    'ManageNDDScore',
502-    'ManageMetadata',
503-    'ManageOntologyMappings',
504:    'ManageAnalysisReleases',
505-  ].map(simpleAdminRoute),
506-  {
507-    path: '/Entities/:entity_id',
508-    name: 'Entity',
509-    component: () => import('@/views/pages/EntityView.vue'),
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
   288	describe('api/analysis — listReleases', () => {
   289	  it('returns the releases envelope on 200', async () => {
   290	    server.use(
   291	      http.get('/api/analysis/releases', () =>
   292	        HttpResponse.json({
   293	          releases: [makeReleaseHead()],
   294	          pagination: { limit: 50, offset: 0, count: 1 },
   295	        })
   296	      )
   297	    );
   298	    const result = await listReleases();
   299	    expect(result.releases).toHaveLength(1);
   300	    expect(result.releases[0].release_id).toBe('asr_0123456789abcdef');
   301	    expect(result.pagination.count).toBe(1);
   302	    // Public head allowlist: admin-only fields must never be present.
   303	    expect(result.releases[0]).not.toHaveProperty('created_by_user_id');
   304	    expect(result.releases[0]).not.toHaveProperty('last_error_message');
   305	  });
   306
   307	  it('forwards limit/offset query params', async () => {
   308	    let observedQuery: URLSearchParams | null = null;
   309	    server.use(
   310	      http.get('/api/analysis/releases', ({ request }) => {
   311	        observedQuery = new URL(request.url).searchParams;
   312	        return HttpResponse.json({
   313	          releases: [],
   314	          pagination: { limit: 10, offset: 5, count: 0 },
   315	        });
   316	      })
   317	    );
   318	    await listReleases({ limit: 10, offset: 5 });
   319	    const q = observedQuery as unknown as URLSearchParams;
   320	    expect(q.get('limit')).toBe('10');
   321	    expect(q.get('offset')).toBe('5');
   322	  });
   323
   324	  it('throws AxiosError on non-2xx', async () => {
   325	    server.use(
   326	      http.get('/api/analysis/releases', () =>
   327	        HttpResponse.json({ message: 'boom' }, { status: 500 })
   328	      )
   329	    );
   330	    let caught: unknown;
   331	    try {
   332	      await listReleases();
   333	    } catch (err) {
   334	      caught = err;
   335	    }
   336	    expect(isApiError(caught)).toBe(true);
   337	    expect(extractApiErrorMessage(caught, 'fallback')).toBe('boom');
   338	  });
   339	});
   340
   341	describe('api/analysis — getLatestRelease', () => {
   342	  it('returns the head + manifest on 200', async () => {
   343	    const detail: ReleaseDetail = {
   344	      ...makeReleaseHead(),
   345	      manifest: {
   346	        release_id: 'asr_0123456789abcdef',
   347	        release_version: null,
   348	        title: 'SysNDD analysis-snapshot release',
   349	        created_at: '2026-07-01T00:00:00Z',
   350	        license: 'CC-BY-4.0',
   351	        scope_statement: 'Public derived analysis only.',
   352	        generator: 'sysndd-api',
   353	        source: 'sysndd',
   354	        layers: [],
   355	        files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
   356	        content_digest: 'a'.repeat(64),
   357	      },
   358	    };
   359	    server.use(http.get('/api/analysis/releases/latest', () => HttpResponse.json(detail)));
   360	    const result = await getLatestRelease();
   361	    expect(result.release_id).toBe('asr_0123456789abcdef');
   362	    expect(result.manifest.files).toHaveLength(1);
   363	  });
   364
   365	  it('throws AxiosError 404 when no published release exists', async () => {
   366	    server.use(
   367	      http.get('/api/analysis/releases/latest', () =>
   368	        HttpResponse.json({ message: 'No published analysis-snapshot release exists yet' }, { status: 404 })
   369	      )
   370	    );
   371	    let caught: unknown;
   372	    try {
   373	      await getLatestRelease();
   374	    } catch (err) {
   375	      caught = err;
   376	    }
   377	    expect(isApiError(caught)).toBe(true);
   378	    if (isApiError(caught)) {
   379	      expect(caught.response?.status).toBe(404);
   380	    }
   381	  });
   382	});
   383
   384	describe('api/analysis — getRelease', () => {
   385	  it('returns the head + manifest on 200 and encodes the release id', async () => {
   386	    let observedPath = '';
   387	    const detail: ReleaseDetail = {
   388	      ...makeReleaseHead({ release_id: 'asr_abc123' }),
   389	      manifest: {
   390	        release_id: 'asr_abc123',
   391	        release_version: null,
   392	        title: 'SysNDD analysis-snapshot release',
   393	        created_at: '2026-07-01T00:00:00Z',
   394	        license: 'CC-BY-4.0',
   395	        scope_statement: 'Public derived analysis only.',
   396	        generator: 'sysndd-api',
   397	        source: 'sysndd',
   398	        layers: [],
   399	        files: [],
   400	        content_digest: 'a'.repeat(64),
   401	      },
   402	    };
   403	    server.use(
   404	      http.get('/api/analysis/releases/:releaseId', ({ request, params }) => {
   405	        observedPath = new URL(request.url).pathname;
   406	        expect(params.releaseId).toBe('asr_abc123');
   407	        return HttpResponse.json(detail);
   408	      })
   409	    );
   410	    const result = await getRelease('asr_abc123');
   411	    expect(result.release_id).toBe('asr_abc123');
   412	    expect(observedPath).toBe('/api/analysis/releases/asr_abc123');
   413	  });
   414
   415	  it('throws AxiosError 404 for an unknown/draft release id', async () => {
   416	    server.use(
   417	      http.get('/api/analysis/releases/:releaseId', () =>
   418	        HttpResponse.json({ message: 'not found' }, { status: 404 })
   419	      )
   420	    );
   421	    let caught: unknown;
   422	    try {
   423	      await getRelease('asr_unknown');
   424	    } catch (err) {
   425	      caught = err;
   426	    }
   427	    expect(isApiError(caught)).toBe(true);
   428	    if (isApiError(caught)) {
   429	      expect(caught.response?.status).toBe(404);
   430	    }
   431	  });
   432	});
   433
   434	describe('api/analysis — downloadReleaseManifest', () => {
   435	  it('returns the manifest.json bytes as a Blob', async () => {
   436	    server.use(
   437	      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
   438	        HttpResponse.json({ release_id: 'asr_abc123' })
   439	      )
   440	    );
   441	    const blob = await downloadReleaseManifest('asr_abc123');
   442	    expect(blob).toBeInstanceOf(Blob);
   443	  });
   444
   445	  it('throws AxiosError on non-2xx', async () => {
   446	    server.use(
   447	      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
   448	        HttpResponse.json({ message: 'not found' }, { status: 404 })
   449	      )
   450	    );
   451	    let caught: unknown;
   452	    try {
   453	      await downloadReleaseManifest('asr_unknown');
   454	    } catch (err) {
   455	      caught = err;
   456	    }
   457	    expect(isApiError(caught)).toBe(true);
   458	  });
   459	});
   460
   461	describe('api/analysis — downloadReleaseFile', () => {
   462	  it('forwards the file path as a query param and returns a Blob', async () => {
   463	    let observedQuery: URLSearchParams | null = null;
   464	    server.use(
   465	      http.get('/api/analysis/releases/:releaseId/file', ({ request }) => {
   466	        observedQuery = new URL(request.url).searchParams;
   467	        return HttpResponse.json({ ok: true });
   468	      })
   469	    );
   470	    const blob = await downloadReleaseFile('asr_abc123', 'functional_clusters/payload.json');
   471	    expect(blob).toBeInstanceOf(Blob);
   472	    const q = observedQuery as unknown as URLSearchParams;
   473	    expect(q.get('path')).toBe('functional_clusters/payload.json');
   474	  });
   475
   476	  it('throws AxiosError on non-2xx (unknown file path)', async () => {
   477	    server.use(
   478	      http.get('/api/analysis/releases/:releaseId/file', () =>
   479	        HttpResponse.json({ message: 'not found' }, { status: 404 })
   480	      )
   481	    );
   482	    let caught: unknown;
   483	    try {
   484	      await downloadReleaseFile('asr_abc123', 'nope.json');
   485	    } catch (err) {
   486	      caught = err;
   487	    }
   488	    expect(isApiError(caught)).toBe(true);
   489	    if (isApiError(caught)) {
   490	      expect(caught.response?.status).toBe(404);
   491	    }
   492	  });
   493	});
   494
   495	describe('api/analysis — downloadReleaseBundle', () => {
   496	  it('returns the bundle.tar.gz bytes as a Blob', async () => {
   497	    server.use(
   498	      http.get('/api/analysis/releases/:releaseId/bundle', () =>
   499	        HttpResponse.json({ ok: true })
   500	      )
   501	    );
   502	    const blob = await downloadReleaseBundle('asr_abc123');
   503	    expect(blob).toBeInstanceOf(Blob);
   504	  });
   505
   506	  it('throws AxiosError on non-2xx', async () => {
   507	    server.use(
   508	      http.get('/api/analysis/releases/:releaseId/bundle', () =>
   509	        HttpResponse.json({ message: 'not found' }, { status: 404 })
   510	      )
   511	    );
   512	    let caught: unknown;
   513	    try {
   514	      await downloadReleaseBundle('asr_unknown');
   515	    } catch (err) {
   516	      caught = err;
   517	    }
   518	    expect(isApiError(caught)).toBe(true);
   519	  });
   520	});
     1	interface AxiosLikeError {
     2	  response?: {
     3	    data?: {
     4	      message?: unknown;
     5	      error?: unknown;
     6	      // RFC 9457 problem+json (application/problem+json) returned by the API's
     7	      // errorHandler for thrown errors — these carry no message/error key.
     8	      detail?: unknown;
     9	      title?: unknown;
    10	    };
    11	  };
    12	  message?: unknown;
    13	}
    14
    15	function unwrapMessageValue(value: unknown): string | undefined {
    16	  if (typeof value === 'string') {
    17	    return value;
    18	  }
    19
    20	  if (Array.isArray(value)) {
    21	    return value.find((item): item is string => typeof item === 'string');
    22	  }
    23
    24	  return undefined;
    25	}
    26
    27	function isObject(value: unknown): value is Record<string, unknown> {
    28	  return typeof value === 'object' && value !== null;
    29	}
    30
    31	export function extractApiErrorMessage(err: unknown, fallback: string): string {
    32	  if (!isObject(err)) {
    33	    return fallback;
    34	  }
    35
    36	  const apiError = err as AxiosLikeError;
    37
    38	  return (
    39	    unwrapMessageValue(apiError.response?.data?.message) ??
    40	    unwrapMessageValue(apiError.response?.data?.error) ??
    41	    unwrapMessageValue(apiError.response?.data?.detail) ??
    42	    unwrapMessageValue(apiError.response?.data?.title) ??
    43	    unwrapMessageValue(apiError.message) ??
    44	    fallback
    45	  );
    46	}
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
19461 app/src/components/analyses/AnalysesCurationUpset.vue
19130 app/src/views/admin/ManageBackups.vue
19115 app/src/views/curate/composables/useManageReReview.ts
19091 app/src/views/admin/ManageAnnotations.vue
18759 app/src/components/small/GenericDesktopTable.vue

exec
/bin/bash -lc "git diff --name-only origin/master...HEAD -- ':(exclude).planning/**' | rg '"'^app/src/.*'"\\.(ts|vue)"'$'"' | xargs -r wc -l
cd app && npm run type-check:strict" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 exited 1 in 38463ms:
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
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release.R | sed -n '170,500p'
rg -n -C 4 'title =|scope_statement' api/functions/analysis-snapshot-release-repository.R api/functions/analysis-snapshot-release.R
rg -n -C 3 'analysis_release_insert' api/functions/analysis-snapshot-release-repository.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
   170	# Orchestrator
   171	# --------------------------------------------------------------------------- #
   172
   173	#' Build (and optionally publish) an immutable analysis-snapshot release.
   174	#'
   175	#' @param layers Layer registry (default `analysis_snapshot_release_layers()`).
   176	#' @param title,scope_statement,license Presentation metadata (excluded from the
   177	#'   content digest / release identity).
   178	#' @param publish If TRUE the inserted draft is flipped to `published`.
   179	#' @param created_by Optional user id recorded on the head row.
   180	#' @param conn A real DBIConnection (required for persistence; A5 checks one out).
   181	#' @param layers Optional SELECTION of layers to include (NULL = full registry);
   182	#'   resolved to authoritative registry entries by
   183	#'   `analysis_snapshot_release_resolve_layers()` (caller cannot override policy).
   184	#' @param loader,reproducibility_loader,coherence_assert,lock_acquire,inserter
   185	#'   Injectable seams (see file header); call-time defaults are the real
   186	#'   functions. `lock_acquire` returns `list(ok, acquired, skipped)`; `inserter`
   187	#'   persists the head/members/files.
   188	#' @return `list(release = <head>, created = TRUE|FALSE)`.
   189	#' @export
   190	analysis_snapshot_release_build <- function(layers = NULL,
   191	                                            title = NULL,
   192	                                            scope_statement = NULL,
   193	                                            license = "CC-BY-4.0",
   194	                                            publish = TRUE,
   195	                                            created_by = NULL,
   196	                                            conn = NULL,
   197	                                            loader = analysis_snapshot_get_public,
   198	                                            reproducibility_loader = analysis_snapshot_get_reproducibility,
   199	                                            coherence_assert = analysis_snapshot_release_assert_coherent,
   200	                                            lock_acquire = .analysis_release_acquire_preset_locks,
   201	                                            inserter = analysis_release_insert) {
   202	  # B1: a caller `layers` request is a SELECTION, never a policy redefinition —
   203	  # resolve each selector to the AUTHORITATIVE registry entry (params /
   204	  # files_prefix / has_reproducibility come from the registry, never the caller).
   205	  layers <- analysis_snapshot_release_resolve_layers(layers)
   206
   207	  # Resolve (analysis_type, parameter_hash) per layer once (pure; validates params).
   208	  layer_specs <- lapply(layers, function(layer) {
   209	    at <- as.character(layer$analysis_type[[1]])
   210	    list(
   211	      analysis_type = at,
   212	      layer = layer,
   213	      parameter_hash = analysis_snapshot_normalize_params(at, layer$params %||% list())$parameter_hash
   214	    )
   215	  })
   216
   217	  # --- Step 0: per-preset TOCTOU advisory locks ----------------------------
   218	  # Acquire the SAME per-preset lock the axis refresh holds, so a mid-flight
   219	  # refresh of a source preset serializes against this read. On a REAL
   220	  # DBIConnection a failed acquisition MUST NOT proceed unlocked (H3): it raises
   221	  # `release_lock_unavailable`, which the service maps to 503 + Retry-After.
   222	  # A non-DBI/test conn skips the lock (lock_state$skipped).
   223	  lock_names <- vapply(
   224	    layer_specs,
   225	    function(spec) .analysis_release_preset_lock_name(spec$analysis_type, spec$parameter_hash),
   226	    character(1)
   227	  )
   228	  lock_state <- lock_acquire(conn, lock_names)
   229	  if (length(lock_state$acquired %||% character(0)) > 0L) {
   230	    on.exit(
   231	      for (lock_name in lock_state$acquired) .analysis_release_release_named_lock(conn, lock_name),
   232	      add = TRUE
   233	    )
   234	  }
   235	  if (!isTRUE(lock_state$ok)) {
   236	    stop(.analysis_release_condition(
   237	      "release_lock_unavailable",
   238	      "source analysis snapshots are being refreshed; retry the release build shortly"
   239	    ))
   240	  }
   241
   242	  # --- Step 1/1b/1c: load + gate each layer --------------------------------
   243	  loaded <- list()
   244	  for (spec in layer_specs) {
   245	    layer <- spec$layer
   246	    at <- spec$analysis_type
   247	    parameter_hash <- spec$parameter_hash
   248
   249	    snapshot <- loader(at, parameter_hash, conn = conn)
   250	    status_code <- if (is.null(snapshot)) "snapshot_missing" else (snapshot$status_code %||% "snapshot_missing")
   251	    if (!identical(status_code, "available")) {
   252	      stop(.analysis_release_condition(
   253	        "release_snapshot_not_available",
   254	        sprintf("layer %s is not available for release: %s", at, status_code),
   255	        analysis_type = at, status_code = status_code
   256	      ))
   257	    }
   258
   259	    manifest <- snapshot$manifest
   260	    entry <- list(
   261	      analysis_type = at,
   262	      kind = .analysis_release_layer_kind(at),
   263	      layer = layer,
   264	      snapshot = snapshot,
   265	      manifest = manifest,
   266	      snapshot_id = .analysis_release_manifest_scalar(manifest, "snapshot_id"),
   267	      payload_hash = as.character(.analysis_release_manifest_scalar(manifest, "payload_hash", NA_character_)),
   268	      input_hash = as.character(.analysis_release_manifest_scalar(manifest, "input_hash", NA_character_)),
   269	      schema_version = as.character(.analysis_release_manifest_scalar(manifest, "schema_version", NA_character_)),
   270	      source_data_version = as.character(
   271	        .analysis_release_manifest_scalar(manifest, "source_data_version", NA_character_)
   272	      ),
   273	      parameter_hash = parameter_hash,
   274	      reproducibility_hash = NULL,
   275	      dependencies = NULL,
   276	      reproducibility_bundle = NULL
   277	    )
   278
   279	    if (isTRUE(layer$has_reproducibility)) {
   280	      # 1b: HARD coherence re-check (any failure -> release_source_incoherent).
   281	      tryCatch(
   282	        coherence_assert(snapshot, entry$kind),
   283	        release_source_incoherent = function(e) stop(e),
   284	        error = function(e) {
   285	          stop(.analysis_release_condition(
   286	            "release_source_incoherent",
   287	            sprintf("layer %s failed the hard coherence re-check: %s", at, conditionMessage(e)),
   288	            analysis_type = at
   289	          ))
   290	        }
   291	      )
   292
   293	      # 1c: reproducibility bundle presence.
   294	      repro <- reproducibility_loader(entry$snapshot_id, conn = conn)
   295	      repro_hash <- .analysis_release_repro_hash(repro)
   296	      if (is.na(repro_hash) || !nzchar(repro_hash)) {
   297	        stop(.analysis_release_condition(
   298	          "release_reproducibility_missing",
   299	          sprintf("layer %s has no reproducibility bundle; the release requires one", at),
   300	          analysis_type = at
   301	        ))
   302	      }
   303	      entry$reproducibility_hash <- repro_hash
   304	      entry$reproducibility_bundle <- repro$bundle_gzip_json
   305	    }
   306
   307	    loaded[[at]] <- entry
   308	  }
   309
   310	  # --- Step 2: shared source version + correlation dependency lineage ------
   311	  .analysis_release_assert_lineage(loaded)
   312	  shared_source_version <- unique(vapply(
   313	    loaded, function(e) as.character(e$source_data_version), character(1)
   314	  ))[[1]]
   315
   316	  # M1/M2: DB release provenance — carried on each pinned snapshot manifest.
   317	  # strict = TRUE: distinct non-empty values that DISAGREE across layers reject
   318	  # the build (release_source_version_mismatch -> 400), like source_data_version.
   319	  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version", strict = TRUE)
   320	  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit", strict = TRUE)
   321
   322	  # For the correlation layer, pin the actual dependency lineage into its entry.
   323	  corr <- loaded[["phenotype_functional_correlations"]]
   324	  if (!is.null(corr)) {
   325	    loaded[["phenotype_functional_correlations"]]$dependencies <-
   326	      analysis_snapshot_manifest_dependencies(corr$manifest)
   327	  }
   328
   329	  # --- Step 3/4/5: materialize per-layer files + README, build layer_entries
   330	  artifacts <- list()
   331	  layer_entries <- list()
   332
   333	  for (layer in layers) {
   334	    at <- as.character(layer$analysis_type[[1]])
   335	    entry <- loaded[[at]]
   336	    prefix <- layer$files_prefix %||% at
   337
   338	    payload_bytes <- analysis_release_canonical_bytes(.analysis_release_layer_payload(entry$snapshot, layer))
   339	    artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   340	      paste0(prefix, "/payload.json"), payload_bytes, "application/json"
   341	    )
   342
   343	    if (isTRUE(layer$has_reproducibility)) {
   344	      repro_bytes <- charToRaw(analysis_reproducibility_decode_raw(entry$reproducibility_bundle))
   345	      # H2: the LOCKED equality `sha256(reproducibility.json) == reproducibility_hash`
   346	      # must HOLD, not merely be present — verify the decoded bytes hash to the
   347	      # stored hash (a corrupt/restored bundle whose bytes drifted from its hash
   348	      # is rejected, not published).
   349	      computed_repro_hash <- analysis_release_sha256(repro_bytes)
   350	      if (!identical(computed_repro_hash, entry$reproducibility_hash)) {
   351	        stop(.analysis_release_condition(
   352	          "release_reproducibility_missing",
   353	          sprintf(
   354	            "layer %s reproducibility bytes do not hash to the stored reproducibility_hash (bundle corrupt)",
   355	            at
   356	          ),
   357	          analysis_type = at
   358	        ))
   359	      }
   360	      artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   361	        paste0(prefix, "/reproducibility.json"), repro_bytes, "application/json"
   362	      )
   363	    }
   364
   365	    layer_entries[[length(layer_entries) + 1L]] <- list(
   366	      analysis_type = at,
   367	      parameter_hash = entry$parameter_hash,
   368	      snapshot_id = entry$snapshot_id,
   369	      input_hash = entry$input_hash,
   370	      payload_hash = entry$payload_hash,
   371	      schema_version = entry$schema_version,
   372	      reproducibility_hash = entry$reproducibility_hash,
   373	      dependencies = entry$dependencies
   374	    )
   375	  }
   376
   377	  # --- Step 6: content_digest -> release_id + idempotency ------------------
   378	  content_digest <- analysis_release_content_digest(
   379	    layer_entries, shared_source_version, ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION
   380	  )
   381	  release_id <- analysis_release_id(content_digest)
   382
   383	  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
   384	    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   385	    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
   386	      return(list(release = existing, created = FALSE))
   387	    }
   388	    stop(sprintf(
   389	      "release id %s already exists with a different content_digest (identity anomaly)",
   390	      release_id
   391	    ), call. = FALSE)
   392	  }
   393
   394	  # README carries the resolved release_id now that it is known.
   395	  readme_bytes <- .analysis_release_readme_bytes(
   396	    release_id, title, scope_statement, license, shared_source_version, layer_entries
   397	  )
   398	  artifacts <- c(
   399	    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
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
api/functions/analysis-snapshot-release.R-172-
api/functions/analysis-snapshot-release.R-173-#' Build (and optionally publish) an immutable analysis-snapshot release.
api/functions/analysis-snapshot-release.R-174-#'
api/functions/analysis-snapshot-release.R-175-#' @param layers Layer registry (default `analysis_snapshot_release_layers()`).
api/functions/analysis-snapshot-release.R:176:#' @param title,scope_statement,license Presentation metadata (excluded from the
api/functions/analysis-snapshot-release.R-177-#'   content digest / release identity).
api/functions/analysis-snapshot-release.R-178-#' @param publish If TRUE the inserted draft is flipped to `published`.
api/functions/analysis-snapshot-release.R-179-#' @param created_by Optional user id recorded on the head row.
api/functions/analysis-snapshot-release.R-180-#' @param conn A real DBIConnection (required for persistence; A5 checks one out).
--
api/functions/analysis-snapshot-release.R-187-#'   persists the head/members/files.
api/functions/analysis-snapshot-release.R-188-#' @return `list(release = <head>, created = TRUE|FALSE)`.
api/functions/analysis-snapshot-release.R-189-#' @export
api/functions/analysis-snapshot-release.R-190-analysis_snapshot_release_build <- function(layers = NULL,
api/functions/analysis-snapshot-release.R:191:                                            title = NULL,
api/functions/analysis-snapshot-release.R:192:                                            scope_statement = NULL,
api/functions/analysis-snapshot-release.R-193-                                            license = "CC-BY-4.0",
api/functions/analysis-snapshot-release.R-194-                                            publish = TRUE,
api/functions/analysis-snapshot-release.R-195-                                            created_by = NULL,
api/functions/analysis-snapshot-release.R-196-                                            conn = NULL,
--
api/functions/analysis-snapshot-release.R-392-  }
api/functions/analysis-snapshot-release.R-393-
api/functions/analysis-snapshot-release.R-394-  # README carries the resolved release_id now that it is known.
api/functions/analysis-snapshot-release.R-395-  readme_bytes <- .analysis_release_readme_bytes(
api/functions/analysis-snapshot-release.R:396:    release_id, title, scope_statement, license, shared_source_version, layer_entries
api/functions/analysis-snapshot-release.R-397-  )
api/functions/analysis-snapshot-release.R-398-  artifacts <- c(
api/functions/analysis-snapshot-release.R-399-    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
api/functions/analysis-snapshot-release.R-400-    artifacts
--
api/functions/analysis-snapshot-release.R-406-  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
api/functions/analysis-snapshot-release.R-407-  manifest_obj <- analysis_release_build_manifest(list(
api/functions/analysis-snapshot-release.R-408-    release_id = release_id,
api/functions/analysis-snapshot-release.R-409-    release_version = NULL,
api/functions/analysis-snapshot-release.R:410:    title = title,
api/functions/analysis-snapshot-release.R-411-    created_at = created_at,
api/functions/analysis-snapshot-release.R-412-    license = license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release.R:413:    scope_statement = scope_statement,
api/functions/analysis-snapshot-release.R-414-    generator = list(
api/functions/analysis-snapshot-release.R-415-      name = "sysndd-analysis-snapshot-release-build",
api/functions/analysis-snapshot-release.R-416-      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
api/functions/analysis-snapshot-release.R-417-      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
--
api/functions/analysis-snapshot-release.R-464-  # --- Step 10: persist ----------------------------------------------------
api/functions/analysis-snapshot-release.R-465-  release_head <- list(
api/functions/analysis-snapshot-release.R-466-    release_id = release_id,
api/functions/analysis-snapshot-release.R-467-    release_version = NULL,
api/functions/analysis-snapshot-release.R:468:    title = title,
api/functions/analysis-snapshot-release.R-469-    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
api/functions/analysis-snapshot-release.R-470-    content_digest = content_digest,
api/functions/analysis-snapshot-release.R-471-    manifest_sha256 = manifest_sha256,
api/functions/analysis-snapshot-release.R-472-    bundle_sha256 = bundle_sha256,
api/functions/analysis-snapshot-release.R-473-    bundle_gzip = bundle_gzip,
api/functions/analysis-snapshot-release.R-474-    source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R-475-    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R-476-    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
api/functions/analysis-snapshot-release.R:477:    scope_statement = scope_statement,
api/functions/analysis-snapshot-release.R-478-    license = license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release.R-479-    created_by_user_id = created_by
api/functions/analysis-snapshot-release.R-480-  )
api/functions/analysis-snapshot-release.R-481-
--
api/functions/analysis-snapshot-release-repository.R-61-#' @noRd
api/functions/analysis-snapshot-release-repository.R-62-.analysis_release_head_columns <- paste(
api/functions/analysis-snapshot-release-repository.R-63-  "release_id, release_version, title, status, manifest_schema_version,",
api/functions/analysis-snapshot-release-repository.R-64-  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
api/functions/analysis-snapshot-release-repository.R:65:  "source_data_version, db_release_version, db_release_commit, scope_statement,",
api/functions/analysis-snapshot-release-repository.R-66-  "license, file_count, total_bytes, created_by_user_id, created_at,",
api/functions/analysis-snapshot-release-repository.R-67-  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
api/functions/analysis-snapshot-release-repository.R-68-  "version_doi, concept_doi, last_error_message"
api/functions/analysis-snapshot-release-repository.R-69-)
--
api/functions/analysis-snapshot-release-repository.R-84-#' `release_head` is a named list with (at least) `release_id`,
api/functions/analysis-snapshot-release-repository.R-85-#' `manifest_schema_version`, `content_digest`, `manifest_sha256`,
api/functions/analysis-snapshot-release-repository.R-86-#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
api/functions/analysis-snapshot-release-repository.R-87-#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
api/functions/analysis-snapshot-release-repository.R:88:#' `scope_statement`, `license` (defaults `"CC-BY-4.0"`),
api/functions/analysis-snapshot-release-repository.R-89-#' `created_by_user_id`. Always inserted with `status = 'draft'` —
api/functions/analysis-snapshot-release-repository.R-90-#' `analysis_release_publish()` is the only way to flip it.
api/functions/analysis-snapshot-release-repository.R-91-#'
api/functions/analysis-snapshot-release-repository.R-92-#' `bundle_bytes`, `file_count`, `total_bytes` are derived here (not trusted
--
api/functions/analysis-snapshot-release-repository.R-121-      conn,
api/functions/analysis-snapshot-release-repository.R-122-      "INSERT INTO analysis_snapshot_release (
api/functions/analysis-snapshot-release-repository.R-123-         release_id, release_version, title, status, manifest_schema_version,
api/functions/analysis-snapshot-release-repository.R-124-         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
api/functions/analysis-snapshot-release-repository.R:125:         source_data_version, db_release_version, db_release_commit, scope_statement,
api/functions/analysis-snapshot-release-repository.R-126-         license, file_count, total_bytes, created_by_user_id
api/functions/analysis-snapshot-release-repository.R-127-       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
api/functions/analysis-snapshot-release-repository.R-128-      params = unname(list(
api/functions/analysis-snapshot-release-repository.R-129-        release_id,
--
api/functions/analysis-snapshot-release-repository.R-137-        length(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-138-        .analysis_release_chr(release_head$source_data_version),
api/functions/analysis-snapshot-release-repository.R-139-        .analysis_release_chr(release_head$db_release_version),
api/functions/analysis-snapshot-release-repository.R-140-        .analysis_release_chr(release_head$db_release_commit),
api/functions/analysis-snapshot-release-repository.R:141:        .analysis_release_chr(release_head$scope_statement),
api/functions/analysis-snapshot-release-repository.R-142-        release_head$license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release-repository.R-143-        as.integer(file_count),
api/functions/analysis-snapshot-release-repository.R-144-        as.numeric(total_bytes),
api/functions/analysis-snapshot-release-repository.R-145-        if (is.null(release_head$created_by_user_id)) NA_integer_ else as.integer(release_head$created_by_user_id)
19-#
20-# `conn` is a REQUIRED, explicit DBI connection on every function here (no
21-# `conn = NULL` global-pool fallback like the sibling
22:# `analysis-snapshot-repository.R`). Two reasons: (1) `analysis_release_insert()`
23-# wraps its writes in one `DBI::dbWithTransaction(conn, {...})`, which needs a
24-# real `DBIConnection`, not a `Pool`; and (2) blob binding via
25-# `list(<raw vector>)` needs the same. Callers (services, later tasks) are
26-# responsible for resolving/checking out a real connection before calling in.
27-#
28-# IMPORTANT test/caller trap (verified live against RMariaDB): calling
29:# `analysis_release_insert()` on a connection that already has an open
30-# transaction raises "Nested transactions not supported" (RMariaDB's
31-# `dbBegin()` rejects it) — the same trap documented in
32-# `test-integration-additive-ontology-terms.R` /
--
103-#'
104-#' @return chr, the inserted `release_id`.
105-#' @export
106:analysis_release_insert <- function(release_head, members = list(), files = list(), conn) {
107-  release_id <- .analysis_release_chr(release_head$release_id)
108-  if (is.na(release_id) || !nzchar(release_id)) {
109-    stop("release_head$release_id is required", call. = FALSE)

exec
/bin/bash -lc "rg -n -C 6 'analysis_release_build_manifest' api/functions/analysis-snapshot-release-manifest.R
nl -ba api/functions/analysis-snapshot-release-manifest.R | sed -n '120,260p'
rg -n -C 3 'generator|source' api/tests/testthat/test-*-analysis-snapshot-release* api/tests/testthat/test-*-release* 2>/dev/null | head -300
rg -n -C 3 'manifest\\.generator|manifest\\.source|generator:' app/src api | head -240" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
191-#' both are excluded from the `files[]` array in the built manifest.
192-#'
193-#' @param fields list with elements `release_id`, `release_version`, `title`,
194-#'   `created_at`, `license`, `scope_statement`, `generator`, `source`,
195-#'   `layers`, `files`, `content_digest`.
196-#' @return list, the manifest ready for `analysis_snapshot_canonical_json()`.
197:analysis_release_build_manifest <- function(fields) {
198-  self_describing_paths <- c("manifest.json", "checksums.sha256")
199-  files <- Filter(function(f) !(f$path %in% self_describing_paths), fields$files)
200-
201-  list(
202-    release_id = fields$release_id,
203-    release_version = fields$release_version,
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
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-5-#
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-6-# ARCHITECTURE: the orchestrator has three dependency-injection seams so the
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-7-# correctness-critical GATES are deterministically unit-testable WITHOUT seeding
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:8:# the (very complex) analysis_snapshot_* source tables:
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-9-#   - loader(analysis_type, parameter_hash, conn)  (default analysis_snapshot_get_public)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-10-#   - reproducibility_loader(snapshot_id, conn)    (default analysis_snapshot_get_reproducibility)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-11-#   - coherence_assert(snapshot, kind)             (default analysis_snapshot_release_assert_coherent)
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-25-setwd(get_api_dir())
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-26-withr::defer(setwd(release_build_test_wd), testthat::teardown_env())
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-27-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:28:source(file.path("core", "errors.R"), local = TRUE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:29:source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:30:source(file.path("functions", "analysis-snapshot-dependencies.R"), local = TRUE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:31:source(file.path("functions", "analysis-snapshot-coherence.R"), local = TRUE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:32:source(file.path("functions", "analysis-reproducibility.R"), local = TRUE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:33:source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:34:source(file.path("functions", "analysis-snapshot-release-repository.R"), local = TRUE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:35:source(file.path("functions", "analysis-snapshot-release-materialize.R"), local = TRUE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:36:source(file.path("functions", "analysis-snapshot-release.R"), local = TRUE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-37-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-38-# --------------------------------------------------------------------------- #
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-39-# Fixtures: fake loaded snapshots mirroring analysis_snapshot_get_public()'s
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-52-DB_RELEASE_COMMIT <- "abc1234"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-53-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-54-make_manifest <- function(analysis_type, snapshot_id, payload_hash,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:55:                          source_data_version = SRC_V,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-56-                          input_hash = analysis_release_sha256(paste0(analysis_type, "-input")),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-57-                          schema_version = "1.2",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:58:                          source_versions_json = NA_character_,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-59-                          db_release_version = DB_RELEASE_VERSION,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-60-                          db_release_commit = DB_RELEASE_COMMIT) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-61-  data.frame(
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-63-    snapshot_id = as.integer(snapshot_id),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-64-    payload_hash = payload_hash,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-65-    input_hash = input_hash,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:66:    source_data_version = source_data_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-67-    schema_version = schema_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:68:    source_versions_json = source_versions_json,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-69-    db_release_version = db_release_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-70-    db_release_commit = db_release_commit,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-71-    stringsAsFactors = FALSE
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-73-}
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-74-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-75-make_cluster_snap <- function(analysis_type, kind, snapshot_id, payload_hash,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:76:                              source_data_version = SRC_V, status_code = "available",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-77-                              stability_ok = TRUE) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-78-  meta <- if (stability_ok) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-79-    c('{"jaccard_mean":0.82,"jaccard_n_resamples":50}', '{"jaccard_mean":0.61,"jaccard_n_resamples":50}')
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-100-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-101-  list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-102-    status_code = status_code,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:103:    manifest = make_manifest(analysis_type, snapshot_id, payload_hash, source_data_version),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-104-    clusters = clusters,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-105-    cluster_members = members
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-106-  )
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-108-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-109-make_corr_snap <- function(func_id = FUNC_ID, func_hash = FUNC_HASH,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-110-                           phen_id = PHEN_ID, phen_hash = PHEN_HASH,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:111:                           source_data_version = SRC_V, status_code = "available") {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-112-  deps_json <- analysis_snapshot_canonical_json(list(dependencies = list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-113-    functional_clusters = list(snapshot_id = func_id, payload_hash = func_hash),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-114-    phenotype_clusters = list(snapshot_id = phen_id, payload_hash = phen_hash)
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-126-  list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-127-    status_code = status_code,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-128-    manifest = make_manifest("phenotype_functional_correlations", CORR_ID, CORR_HASH,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:129:      source_data_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:130:      source_versions_json = deps_json
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-131-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-132-    correlations = correlations
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-133-  )
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-137-  payload <- if (identical(kind, "functional")) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-138-    list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-139-      edges = data.frame(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:140:        source = c("1", "2"), target = c("2", "3"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-141-        combined_score = c(0.987654321098765, 0.6543210987654321),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-142-        stringsAsFactors = FALSE
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-143-      ),
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-260-      loader = make_loader(), reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-261-      coherence_assert = throwing_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-262-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:263:    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-264-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-265-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-266-
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-281-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-282-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-283-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:284:test_that("build refuses layers that do not share one source_data_version", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-285-  loader <- make_loader(list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-286-    phenotype_clusters = make_cluster_snap(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-287-      "phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:288:      source_data_version = "srcv-DIFFERENT"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-289-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-290-  ))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-291-  expect_error(
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-294-      loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-295-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-296-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:297:    class = "release_source_version_mismatch"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-298-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-299-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-300-
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-345-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-346-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-347-test_that("build refuses to proceed unlocked when the advisory lock cannot be acquired (H3a)", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:348:  # Inject a lock seam that reports acquisition FAILED (a source preset is mid-refresh).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-349-  failing_lock <- function(conn, lock_names) list(ok = FALSE, acquired = character(0), skipped = FALSE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-350-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-351-    analysis_snapshot_release_build(
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-371-      loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-372-      coherence_assert = analysis_snapshot_release_assert_coherent # the REAL default
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-373-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:374:    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-375-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-376-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-377-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-378-# --------------------------------------------------------------------------- #
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-379-# Real default coherence seam: pass when internally consistent, throw
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:380:# release_source_incoherent when a visible cluster lacks a stability score.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-381-# --------------------------------------------------------------------------- #
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-382-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-383-test_that("analysis_snapshot_release_assert_coherent gates stored-snapshot integrity", {
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-390-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-391-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-392-    analysis_snapshot_release_assert_coherent(incoherent, "functional"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:393:    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-394-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-395-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-396-
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-409-  withr::with_envvar(list(ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE = "false"), {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-410-    expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-411-      analysis_snapshot_release_assert_coherent(make_functional_snap_with_reference(incoherent_ref), "functional"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:412:      class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-413-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-414-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-415-
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-424-test_that("a PARTIAL/incomplete reference attestation is treated as incoherent, not degraded (MC2)", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-425-  # served cluster_members have clusters 1 AND 2; the attestation omits cluster 2.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-426-  # It must NOT slip through the intersection-only proof as "legacy-absent" — a
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:427:  # present-but-partial attestation is INCOHERENT (release_source_incoherent).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-428-  partial_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:3")) # missing served cluster "2"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-429-  snap <- make_functional_snap_with_reference(partial_ref)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-430-  # If it were mis-treated as legacy-absent it would degrade + PASS; expect_error
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-431-  # proves it hard-fails instead.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-432-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-433-    analysis_snapshot_release_assert_coherent(snap, "functional"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:434:    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-435-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-436-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-437-
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-448-        loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-449-        coherence_assert = analysis_snapshot_release_assert_coherent # REAL default
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-450-      ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:451:      class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-452-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-453-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-454-})
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-463-      loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-464-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-465-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:466:    class = "release_source_version_mismatch"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-467-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-468-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-469-
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-475-  mismatched <- make_functional_snap_with_channels("combined_score", "experimental_database")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-476-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-477-    analysis_snapshot_release_assert_coherent(mismatched, "functional"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:478:    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-479-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-480-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-481-  # No validation_json -> channel comparison skipped (older snapshots still pass).
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-525-    expect_identical(rf$content_sha256, FUNC_BUNDLE$reproducibility_hash)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-526-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-527-    # manifest per-layer payload_hash is the cross-checkable LINEAGE ANCHOR
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:528:    # (== the source snapshot's payload_hash), NOT the payload.json file hash.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-529-    manifest_file <- analysis_release_get_file(release_id, "manifest.json", include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-530-    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-531-    fc <- Filter(function(l) identical(l$analysis_type, "functional_clusters"), manifest$layers)[[1]]
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-555-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-556-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-557-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:558:test_that("build is idempotent by content: same sources -> same release_id, no duplicate row", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-559-  with_release_build_db(function(conn) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-560-    args <- list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-561-      conn = conn, publish = TRUE,
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-575-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-576-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-577-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:578:test_that("pre-insert re-read catches a source snapshot refreshed mid-build (fresh, not tautological)", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-579-  with_release_build_db(function(conn) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-580-    # The stateful loader returns snapshot_id 101 on the first functional read but
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-581-    # snapshot_id 999 on the pre-insert re-read: if the re-read were tautological
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-594-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-595-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-596-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:597:test_that("build head + manifest carry the DB release provenance from the source snapshots (M1)", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-598-  with_release_build_db(function(conn) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-599-    result <- analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-600-      conn = conn, publish = TRUE,
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-606-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-607-    manifest_file <- analysis_release_get_file(result$release$release_id, "manifest.json", include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-608-    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:609:    expect_equal(manifest$source$db_release$version, DB_RELEASE_VERSION)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:610:    expect_equal(manifest$source$db_release$commit, DB_RELEASE_COMMIT)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-611-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-612-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-613-
--
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-28-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-29-apply_analysis_snapshot_release_migration <- function(conn) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-30-  if (!exists("split_sql_statements", mode = "function")) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:31:    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-32-  }
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-33-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-34-  migration_path <- analysis_snapshot_release_migration_path()
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-6-# Pure unit tests, NO DATABASE. The A4 build orchestrator
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-7-# (`analysis_snapshot_release_build`) and the A3 repository functions
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-8-# (`analysis_release_list/get/get_file/get_bundle/publish/set_doi/
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:9:# delete_draft`) are entirely STUBBED: this file never sources
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-10-# `functions/analysis-snapshot-release.R` or
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-11-# `functions/analysis-snapshot-release-repository.R`, it only defines
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-12-# minimal stand-ins for the names the service calls, then reassigns them
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-13-# per-test via `with_release_mocks()`. This mirrors the established
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:14:# `test-unit-metadata-vocabulary-service.R` mocking pattern: source
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:15:# core/errors.R + the service with `source_api_file(local = FALSE)`, look up
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-16-# `environment(<a service fn>)` to find where the service's free-variable
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-17-# lookups resolve, then temporarily reassign bindings there.
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-18-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-19-library(testthat)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-20-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:21:source_api_file("core/errors.R", local = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-22-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-23-# Minimal stand-ins for the A3/A4 functions the service calls, so the service
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:24:# file sources cleanly (its body only looks these names up at CALL time, but
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-25-# defining them up front keeps `with_release_mocks()`'s get/assign symmetric
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-26-# and self-documenting about the service's full dependency surface).
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-27-analysis_snapshot_release_build <- function(...) stop("stub: analysis_snapshot_release_build not mocked")
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-37-# service tests only verify svc_release_list/get ROUTE through it.
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-38-analysis_release_public_head <- function(head) head
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-39-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:40:source_api_file("services/analysis-snapshot-release-service.R", local = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-41-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-42-# The environment the service functions were defined in (same top-level frame
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:43:# the stand-ins above and core/errors.R were sourced into).
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-44-release_svc_env <- environment(svc_release_build)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-45-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-46-#' Temporarily reassign a set of names in `release_svc_env`, restoring the
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-143-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-144-release_build_condition_cases <- list(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-145-  release_snapshot_not_available = "layer functional_clusters is not available for release: snapshot_missing",
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:146:  release_source_incoherent = "layer functional_clusters failed the hard coherence re-check: boom",
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-147-  release_reproducibility_missing = "layer phenotype_clusters has no reproducibility bundle; the release requires one",
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:148:  release_source_version_mismatch = "shared source_data_version mismatch across layers: v1 vs v2",
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-149-  release_dependency_lineage_mismatch = "layer phenotype_functional_correlations snapshot changed between read and insert"
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-150-)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-151-
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-163-  )
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-164-})
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-165-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:166:test_that("build maps release_source_incoherent to a 400 carrying the reason", {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-167-  res <- release_fake_res()
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:168:  msg <- release_build_condition_cases$release_source_incoherent
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-169-  with_release_mocks(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:170:    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_source_incoherent", msg))),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-171-    {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-172-      err <- tryCatch(svc_release_build(res), error = function(e) e)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-173-      expect_s3_class(err, "error_400")
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-191-  )
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-192-})
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-193-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:194:test_that("build maps release_source_version_mismatch to a 400 carrying the reason", {
app/src/api/analysis_releases.ts-141-  created_at: string;
app/src/api/analysis_releases.ts-142-  license: string;
app/src/api/analysis_releases.ts-143-  scope_statement: string;
app/src/api/analysis_releases.ts:144:  generator: string;
app/src/api/analysis_releases.ts-145-  source: string;
app/src/api/analysis_releases.ts-146-  layers: ReleaseManifestLayer[];
app/src/api/analysis_releases.ts-147-  files: ReleaseManifestFile[];
--
app/src/api/analysis.spec.ts-349-        created_at: '2026-07-01T00:00:00Z',
app/src/api/analysis.spec.ts-350-        license: 'CC-BY-4.0',
app/src/api/analysis.spec.ts-351-        scope_statement: 'Public derived analysis only.',
app/src/api/analysis.spec.ts:352:        generator: 'sysndd-api',
app/src/api/analysis.spec.ts-353-        source: 'sysndd',
app/src/api/analysis.spec.ts-354-        layers: [],
app/src/api/analysis.spec.ts-355-        files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
--
app/src/api/analysis.spec.ts-393-        created_at: '2026-07-01T00:00:00Z',
app/src/api/analysis.spec.ts-394-        license: 'CC-BY-4.0',
app/src/api/analysis.spec.ts-395-        scope_statement: 'Public derived analysis only.',
app/src/api/analysis.spec.ts:396:        generator: 'sysndd-api',
app/src/api/analysis.spec.ts-397-        source: 'sysndd',
app/src/api/analysis.spec.ts-398-        layers: [],
app/src/api/analysis.spec.ts-399-        files: [],
--
app/src/views/analyses/DataReleases.spec.ts-60-      created_at: '2026-07-01T00:00:00Z',
app/src/views/analyses/DataReleases.spec.ts-61-      license: 'CC-BY-4.0',
app/src/views/analyses/DataReleases.spec.ts-62-      scope_statement: 'Public derived analysis only.',
app/src/views/analyses/DataReleases.spec.ts:63:      generator: 'sysndd-api',
app/src/views/analyses/DataReleases.spec.ts-64-      source: 'sysndd',
app/src/views/analyses/DataReleases.spec.ts-65-      layers: [
app/src/views/analyses/DataReleases.spec.ts-66-        {
--
app/src/components/analyses/ReleaseManifestPanel.spec.ts-32-      created_at: '2026-07-01T00:00:00Z',
app/src/components/analyses/ReleaseManifestPanel.spec.ts-33-      license: 'CC-BY-4.0',
app/src/components/analyses/ReleaseManifestPanel.spec.ts-34-      scope_statement: 'Public derived analysis only.',
app/src/components/analyses/ReleaseManifestPanel.spec.ts:35:      generator: 'sysndd-api',
app/src/components/analyses/ReleaseManifestPanel.spec.ts-36-      source: 'sysndd',
app/src/components/analyses/ReleaseManifestPanel.spec.ts-37-      layers: [
app/src/components/analyses/ReleaseManifestPanel.spec.ts-38-        {

codex
Two concrete issues have emerged so far: the public provenance card directly trusts an admin-provided external URL, and its manifest client types do not match the nested JSON the release builder actually emits. I’m validating the remaining interaction and test coverage paths before finalizing severity.
exec
/bin/bash -lc 'cd app && npx vitest run src/api/analysis.spec.ts src/api/admin_analysis_release.spec.ts src/components/analyses/ReleaseManifestPanel.spec.ts src/components/analyses/dataReleaseTable.spec.ts src/views/analyses/DataReleases.spec.ts src/views/admin/useAnalysisReleaseAdmin.spec.ts src/views/admin/ManageAnalysisReleases.spec.ts --pool=threads --poolOptions.threads.singleThread=true' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 exited 1 in 0ms:
file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vitest/dist/chunks/cac.DdICfEr1.js:406
          throw new CACError(`Unknown option \`${name.length > 1 ? `--${name}` : `-${name}`}\``);
                ^

CACError: Unknown option `--poolOptions`
    at Command.checkUnknownOptions (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vitest/dist/chunks/cac.DdICfEr1.js:406:17)
    at CAC.runMatchedCommand (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vitest/dist/chunks/cac.DdICfEr1.js:606:13)
    at CAC.parse (file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vitest/dist/chunks/cac.DdICfEr1.js:547:12)
    at file:///home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/vitest/dist/cli.js:11:13
    at ModuleJob.run (node:internal/modules/esm/module_job:437:25)
    at async node:internal/modules/esm/loader:639:26
    at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)

Node.js v24.15.0

exec
/bin/bash -lc 'cd app && npx vitest run src/api/analysis.spec.ts src/api/admin_analysis_release.spec.ts src/components/analyses/ReleaseManifestPanel.spec.ts src/components/analyses/dataReleaseTable.spec.ts src/views/analyses/DataReleases.spec.ts src/views/admin/useAnalysisReleaseAdmin.spec.ts src/views/admin/ManageAnalysisReleases.spec.ts --pool=threads' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 exited 1 in 183ms:
failed to load config from /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/vitest.config.ts

⎯⎯⎯⎯⎯⎯⎯ Startup Error ⎯⎯⎯⎯⎯⎯⎯⎯
Error: EROFS: read-only file system, open '/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/.vite-temp/vitest.config.ts.timestamp-1784449419049-4e13dea4f7d688.mjs'
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
  path: '/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/node_modules/.vite-temp/vitest.config.ts.timestamp-1784449419049-4e13dea4f7d688.mjs'
}




exec
/bin/bash -lc "git diff origin/master...HEAD -- ':(exclude).planning/**' -- app/src | rg -n '("'^'"\\+.*\\baxios\\b|"'^'"\\+.*localStorage\\.(token|user)|"'^'"\\+.*v-html|"'^'"\\+.*window\\.confirm)' || true
rg -n 'analysis_snapshot_release|analysis-snapshot release' api/tests/testthat | head -20
rg -n 'release_lock_unavailable|zenodo_record_url|generator.*source' app/src --glob '*spec.ts' --glob '*.vue' --glob '*.ts'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573
 succeeded in 0ms:
290:+import type { AxiosRequestConfig } from 'axios';
941:+import type { AxiosRequestConfig } from 'axios';
2544:+  native `window.confirm`/dialog).
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:7:# (`analysis_snapshot_release_build`) and the A3 repository functions
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:27:analysis_snapshot_release_build <- function(...) stop("stub: analysis_snapshot_release_build not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:93:    list(analysis_snapshot_release_build = function(...) list(release = head, created = TRUE)),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:106:    list(analysis_snapshot_release_build = function(...) list(release = head, created = FALSE)),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:119:    list(analysis_snapshot_release_build = function(...) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:156:    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_snapshot_not_available", msg))),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:170:    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_source_incoherent", msg))),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:184:    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_reproducibility_missing", msg))),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:198:    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_source_version_mismatch", msg))),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:211:    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_dependency_lineage_mismatch", msg))),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:224:    list(analysis_snapshot_release_build = function(...) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:240:    list(analysis_snapshot_release_build = function(...) stop("boom: unexpected DB error")),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:22:  expect_identical(analysis_snapshot_release_resolve_layers(NULL), analysis_snapshot_release_layers())
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:23:  expect_identical(analysis_snapshot_release_resolve_layers(list()), analysis_snapshot_release_layers())
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:27:  registry <- analysis_snapshot_release_layers()
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:31:  resolved <- analysis_snapshot_release_resolve_layers(list(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:41:  resolved <- analysis_snapshot_release_resolve_layers(list("phenotype_clusters", "functional_clusters"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:50:    analysis_snapshot_release_resolve_layers(list(list(analysis_type = "not_a_layer"))),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:54:    analysis_snapshot_release_resolve_layers(list("functional_clusters", "functional_clusters")),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:73:  expect_true(exists("analysis_snapshot_release_layers", mode = "function"))
app/src/api/admin_analysis_release.ts:72:  zenodo_record_url: string | null;
app/src/api/admin_analysis_release.ts:108:  zenodo_record_url?: string;
app/src/api/admin_analysis_release.ts:130:  error: 'release_lock_unavailable';
app/src/api/admin_analysis_release.ts:191: * dup), 201 (new content), and 503 (`release_lock_unavailable`, sources
app/src/api/admin_analysis_release.spec.ts:40:    zenodo_record_url: null,
app/src/api/admin_analysis_release.spec.ts:79:            { error: 'release_lock_unavailable', message: 'sources are mid-refresh' },
app/src/api/admin_analysis_release.spec.ts:207:      expect(requestUrl?.searchParams.has('zenodo_record_url')).toBe(false);
app/src/components/analyses/dataReleaseTable.ts:51:  zenodo_record_url: string;
app/src/components/analyses/dataReleaseTable.ts:122:    zenodo_record_url: doiOrDash(release.zenodo?.record_url),
app/src/components/nddscore/NddScoreModelCard.spec.ts:11:    zenodo_record_url: 'https://zenodo.org/records/20258027',
app/src/views/admin/ManageAnalysisReleases.spec.ts:100:    zenodo_record_url: null,
app/src/views/admin/useAnalysisReleaseAdmin.spec.ts:62:    zenodo_record_url: null,
app/src/views/admin/useAnalysisReleaseAdmin.spec.ts:308:        zenodo_record_url: '',
app/src/components/analyses/dataReleaseTable.spec.ts:98:    expect(row.zenodo_record_url).toBe('https://zenodo.org/records/1234');
app/src/components/analyses/dataReleaseTable.spec.ts:114:    expect(rows[0].zenodo_record_url).toBe(DOI_UNASSIGNED);
app/src/views/admin/ManageAnalysisReleases.vue:244:                    v-model="doiFormFor(row.release_id).zenodo_record_url"
app/src/views/admin/ManageAnalysisReleases.vue:354:      zenodo_record_url: '',
app/src/components/nddscore/NddScoreModelCard.vue:114:  zenodo_record_url?: unknown;
app/src/components/nddscore/NddScoreModelCard.vue:125:const zenodoRecordUrl = computed(() => scalarString(release.value?.zenodo_record_url));

codex
## BLOCKER

None.

## HIGH

- [ReleaseManifestPanel.vue:189](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/components/analyses/ReleaseManifestPanel.vue:189) renders the admin-authored `zenodo.record_url` directly into `href`. The DOI endpoint accepts and persists arbitrary strings without URL validation ([repository:452](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/api/functions/analysis-snapshot-release-repository.R:452)). An Administrator can store `javascript:...`; every public visitor then receives a clickable script URL. Validate/allowlist canonical `https://zenodo.org/...` URLs server-side and defensively render a link only for an approved HTTPS URL. Add a malicious-scheme component test.

## MEDIUM

- [analysis_releases.ts:136](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/api/analysis_releases.ts:136) declares `manifest.generator` and `manifest.source` as strings, but the backend serializes both as nested objects ([builder:414](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/api/functions/analysis-snapshot-release.R:414), [manifest helper:208](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/api/functions/analysis-snapshot-release-manifest.R:208)). The current panel happens not to consume them, but the exported typed client is already contractually false and will break or require unsafe casts for provenance consumers. Define the nested generator/source interfaces (and make nullable manifest fields such as `scope_statement` nullable); update fixtures to the real wire shape.

- [DataReleases.vue:195](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/views/analyses/DataReleases.vue:195) has no stale-response guard. If the initial slow `getLatestRelease()` resolves after the user selects another table row, its completion overwrites `selectedRelease` at line 201, showing and downloading the wrong release. Use an incrementing request token or cancel the previous request with `AbortController`, and test the out-of-order response case.

## LOW

- [analysis.spec.ts:324](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/api/analysis.spec.ts:324) and several adjacent release-client error mocks use `{ message: ... }`, despite the actual RFC 9457 API contract using `detail`. The 404 fixture in [DataReleases.spec.ts:83](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/views/analyses/DataReleases.spec.ts:83) does the same. This leaves real error-copy behavior under-tested; use problem+json `detail` fixtures.

- Failure UI coverage exists for Publish, but not rejected DOI save or rejected draft deletion ([ManageAnalysisReleases.spec.ts:279](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/views/admin/ManageAnalysisReleases.spec.ts:279)). Add tests confirming each error remains co-located in the Releases panel and that failed deletion does not misleadingly complete its confirmation flow.

Checks: `git diff --check` was clean; all changed handwritten frontend files are below 600 lines. Type-check and Vitest could not run because this review workspace is read-only and their tooling needs to create temporary files.

VERDICT: NO-SHIP — fix the public `javascript:` URL injection before shipping.
tokens used
157,471
## BLOCKER

None.

## HIGH

- [ReleaseManifestPanel.vue:189](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/components/analyses/ReleaseManifestPanel.vue:189) renders the admin-authored `zenodo.record_url` directly into `href`. The DOI endpoint accepts and persists arbitrary strings without URL validation ([repository:452](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/api/functions/analysis-snapshot-release-repository.R:452)). An Administrator can store `javascript:...`; every public visitor then receives a clickable script URL. Validate/allowlist canonical `https://zenodo.org/...` URLs server-side and defensively render a link only for an approved HTTPS URL. Add a malicious-scheme component test.

## MEDIUM

- [analysis_releases.ts:136](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/api/analysis_releases.ts:136) declares `manifest.generator` and `manifest.source` as strings, but the backend serializes both as nested objects ([builder:414](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/api/functions/analysis-snapshot-release.R:414), [manifest helper:208](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/api/functions/analysis-snapshot-release-manifest.R:208)). The current panel happens not to consume them, but the exported typed client is already contractually false and will break or require unsafe casts for provenance consumers. Define the nested generator/source interfaces (and make nullable manifest fields such as `scope_statement` nullable); update fixtures to the real wire shape.

- [DataReleases.vue:195](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/views/analyses/DataReleases.vue:195) has no stale-response guard. If the initial slow `getLatestRelease()` resolves after the user selects another table row, its completion overwrites `selectedRelease` at line 201, showing and downloading the wrong release. Use an incrementing request token or cancel the previous request with `AbortController`, and test the out-of-order response case.

## LOW

- [analysis.spec.ts:324](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/api/analysis.spec.ts:324) and several adjacent release-client error mocks use `{ message: ... }`, despite the actual RFC 9457 API contract using `detail`. The 404 fixture in [DataReleases.spec.ts:83](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/views/analyses/DataReleases.spec.ts:83) does the same. This leaves real error-copy behavior under-tested; use problem+json `detail` fixtures.

- Failure UI coverage exists for Publish, but not rejected DOI save or rejected draft deletion ([ManageAnalysisReleases.spec.ts:279](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-b-573/app/src/views/admin/ManageAnalysisReleases.spec.ts:279)). Add tests confirming each error remains co-located in the Releases panel and that failed deletion does not misleadingly complete its confirmation flow.

Checks: `git diff --check` was clean; all changed handwritten frontend files are below 600 lines. Type-check and Vitest could not run because this review workspace is read-only and their tooling needs to create temporary files.

VERDICT: NO-SHIP — fix the public `javascript:` URL injection before shipping.
