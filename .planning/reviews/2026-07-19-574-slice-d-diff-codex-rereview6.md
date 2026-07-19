Reading additional input from stdin...
OpenAI Codex v0.144.5
--------
workdir: /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
model: gpt-5.6-terra
provider: openai
approval: never
sandbox: read-only
reasoning effort: high
reasoning summaries: none
session id: 019f77e6-3de8-7a81-a639-fcf44eb3c37f
--------
user
Sixth-pass review of feature #574 (category-selected gene universes for functional clustering). Run `git diff origin/master...HEAD -- ':(exclude).planning/**'`. Read touched files in full.

Round 5 HIGH is fixed: every category-validation 400 message now names the allowed active-category set. `clustering_resolve_category_universe()` fetches the active category list right after the absent-selector default branch, and includes `Allowed active categories: …` in the supplied-empty, unknown, AND `<2`-genes messages. The service's present-but-null `category_filter` case now COERCES the null value to an empty selector and delegates to the resolver (single validation source), instead of raising its own message.

VERIFY:
- `{"category_filter":null}`, `{"category_filter":[]}`, an unknown category, and a valid category resolving to `<2` genes all return 400 AND every message contains the allowed active-category set.
- The absent-selector default branch (`clustering_resolve_category_universe(NULL)`) still does NOT fetch the active list (no extra DB query — cache parity preserved).
- The service present-but-null delegation is correct: `{"category_filter":null}` → resolver called with an empty selector → 400.

Then a FINAL adversarial pass. This is round 6; prior rounds resolved genes/category key-presence mutual exclusion, the fail-closed source-version cache, distinct gene counts, the provenance-out-of-dedup-hash fix (with create_job keeping its 2-arg contract), and the allowed-set-in-messages fix. Report ONLY findings tied to a concrete failure scenario (specific inputs → wrong output/crash/contract violation) — NO speculative or stylistic nits, and do not re-raise anything already resolved. Re-confirm the full locked contract holds.

Output: for each finding, severity (BLOCKER/HIGH/MEDIUM/LOW), file:line, concrete failure scenario, fix. Final line: **VERDICT: SHIP** (zero BLOCKER/HIGH) or **VERDICT: NO-SHIP** with the count.
codex
I’ll review the requested diff as an adversarial, read-only pass, first checking the repository’s required review workflow and then tracing every touched path and its tests.
exec
/bin/bash -lc "sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && printf '\\n--- review skill ---\\n' && sed -n '1,260p' /home/bernt-popp/.codex/superpowers/skills/requesting-code-review/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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

--- review skill ---
---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch superpowers:code-reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code-reviewer subagent:**

Use Task tool with superpowers:code-reviewer type, fill template at `code-reviewer.md`

**Placeholders:**
- `{WHAT_WAS_IMPLEMENTED}` - What you just built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit
- `{DESCRIPTION}` - Brief summary

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch superpowers:code-reviewer subagent]
  WHAT_WAS_IMPLEMENTED: Verification and repair functions for conversation index
  PLAN_OR_REQUIREMENTS: Task 2 from docs/superpowers/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each batch (3 tasks)
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: requesting-code-review/code-reviewer.md

codex
I’m using the repository’s code-quality and security review guides because this is a targeted adversarial review of a SysNDD behavior change; I’ll apply their concrete-failure criteria rather than report style concerns.
exec
/bin/bash -lc "sed -n '1,260p' .agents/skills/sysndd-code-quality/SKILL.md && printf '\\n--- security ---\\n' && sed -n '1,300p' .agents/skills/sysndd-security-bug-scan/SKILL.md && printf '\\n--- diff skill ---\\n' && sed -n '1,260p' /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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

--- security ---
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

--- diff skill ---
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

exec
/bin/bash -lc "git diff --name-status origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
M	AGENTS.md
M	CHANGELOG.md
M	api/bootstrap/load_modules.R
M	api/endpoints/jobs_endpoints.R
M	api/functions/async-job-handlers.R
M	api/functions/async-job-service.R
A	api/functions/clustering-gene-universe.R
M	api/services/job-functional-submission-service.R
M	api/tests/testthat/job-endpoint-services-fixtures.R
A	api/tests/testthat/test-integration-clustering-category-submit.R
M	api/tests/testthat/test-unit-async-job-handlers.R
M	api/tests/testthat/test-unit-async-job-service.R
M	api/tests/testthat/test-unit-async-job-worker.R
A	api/tests/testthat/test-unit-clustering-gene-universe.R
A	api/tests/testthat/test-unit-clustering-handler-meta.R
A	api/tests/testthat/test-unit-job-endpoint-services-category.R
A	api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
M	api/tests/testthat/test-unit-job-endpoint-services.R
M	api/version_spec.json
M	app/package-lock.json
M	app/package.json
M	documentation/08-development.qmd

exec
/bin/bash -lc "git diff --check origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
exec
/bin/bash -lc 'git status --short && git rev-parse origin/master && git rev-parse HEAD' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-reconciliation.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview3-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview3.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview4-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview4.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview5-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview5.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview6-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview6.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-review.md
d1a5a71add74a11b82c80b45dee3b13bc801e2eb
9621ff2267cfd8f49d496e72deca90fe61e8f94d

exec
/bin/bash -lc "git diff --numstat origin/master...HEAD -- ':(exclude).planning/**'; git diff --name-only origin/master...HEAD -- ':(exclude).planning/**' | xargs -r wc -l" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
2	0	AGENTS.md
47	0	CHANGELOG.md
6	0	api/bootstrap/load_modules.R
34	1	api/endpoints/jobs_endpoints.R
36	5	api/functions/async-job-handlers.R
20	4	api/functions/async-job-service.R
165	0	api/functions/clustering-gene-universe.R
188	50	api/services/job-functional-submission-service.R
59	3	api/tests/testthat/job-endpoint-services-fixtures.R
206	0	api/tests/testthat/test-integration-clustering-category-submit.R
4	0	api/tests/testthat/test-unit-async-job-handlers.R
62	0	api/tests/testthat/test-unit-async-job-service.R
1	0	api/tests/testthat/test-unit-async-job-worker.R
305	0	api/tests/testthat/test-unit-clustering-gene-universe.R
171	0	api/tests/testthat/test-unit-clustering-handler-meta.R
402	0	api/tests/testthat/test-unit-job-endpoint-services-category.R
223	0	api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
82	225	api/tests/testthat/test-unit-job-endpoint-services.R
1	1	api/version_spec.json
2	2	app/package-lock.json
1	1	app/package.json
15	0	documentation/08-development.qmd
    284 AGENTS.md
   1272 CHANGELOG.md
    288 api/bootstrap/load_modules.R
    174 api/endpoints/jobs_endpoints.R
    398 api/functions/async-job-handlers.R
    517 api/functions/async-job-service.R
    165 api/functions/clustering-gene-universe.R
    378 api/services/job-functional-submission-service.R
    106 api/tests/testthat/job-endpoint-services-fixtures.R
    206 api/tests/testthat/test-integration-clustering-category-submit.R
    266 api/tests/testthat/test-unit-async-job-handlers.R
    361 api/tests/testthat/test-unit-async-job-service.R
    752 api/tests/testthat/test-unit-async-job-worker.R
    305 api/tests/testthat/test-unit-clustering-gene-universe.R
    171 api/tests/testthat/test-unit-clustering-handler-meta.R
    402 api/tests/testthat/test-unit-job-endpoint-services-category.R
    223 api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
    237 api/tests/testthat/test-unit-job-endpoint-services.R
     14 api/version_spec.json
  20508 app/package-lock.json
    135 app/package.json
    458 documentation/08-development.qmd
  27620 total

codex
The change spans the category resolver, submission service, async job provenance, endpoint wiring, and focused test coverage. The diff is whitespace-clean; I’m now reading the complete changed implementations and tests, then will execute the narrow verification cases.
exec
/bin/bash -lc "git diff --find-renames --find-copies --unified=80 origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
diff --git a/AGENTS.md b/AGENTS.md
index 7aa9b3e1..e9647c88 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -46,160 +46,162 @@ Focused, cross-LLM skill guides live under `.agents/skills/<name>/SKILL.md`. Rea
 - DB-only stack: `make docker-dev-db`
 - API tests: `make test-api`
 - Fast API PR gate: `make test-api-fast`
 - API lint: `make lint-api`
 - Frontend lint: `make lint-app`
 - Frontend type-check: `cd app && npm run type-check`
 - Frontend strict-scope type-check: `cd app && npm run type-check:strict`
 - Frontend unit tests: `cd app && npm run test:unit`
 - Frontend public-route bundle budget: `make verify-app-bundle-budget`
 - Frontend SEO prerender gate: `make verify-seo-app`
 - Frontend E2E (Playwright, **local-only**): `make playwright-stack && cd app && npx playwright test && cd .. && make playwright-stack-down`. The isolated stack serves the app/API at `http://localhost:8088` by default, and `app/playwright.config.ts` uses that default when `PLAYWRIGHT_BASE_URL` is unset. There is no Playwright CI workflow — the spec files in `app/tests/e2e/` exist for ad-hoc local regression checks. The official lane (lint, type-check, vitest, R API, smoke) is the automated coverage.
 
 Single-test shortcuts:
 
 ```bash
 # R — single file (host)
 cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-entity-creation.R')"
 
 # R — single file (inside the running container; tests/ is NOT bind-mounted)
 docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-xyz.R')"
 
 # Frontend — single spec or test name
 cd app && npx vitest run src/components/AppFooter.spec.ts
 cd app && npx vitest run -t "match name pattern"
 ```
 
 ## Architecture Invariants
 
 ### API bootstrap and source order
 
 `api/start_sysndd_api.R` sources the runtime into the global environment. Source order matters:
 
 1. `functions/*` and repository helpers
 2. `core/*`
 3. `services/*`
 4. `endpoints/*`
 
 Service functions must keep their `svc_` or `service_` prefixes. If a service function drops that prefix and collides with a repository function name, it can silently shadow the repository implementation in the global environment.
 
 ### Admin curation metadata vocabularies
 
 The Administrator `/ManageMetadata` page (`app/src/views/admin/ManageMetadata.vue`) administers the small SysNDD-managed curation controlled vocabularies through `/api/metadata` (`api/endpoints/metadata_endpoints.R` -> `services/metadata-vocabulary-service.R` -> `functions/metadata-vocabulary-repository.R`). The vocabulary catalog and editability tiers live in `metadata_vocabulary_registry()`; keep it the single source of truth for which tables/columns the admin surface can touch.
 
 Editability is tiered on purpose. `modifier_list` and `ndd_entity_status_categories_list` are fully editable (create / update / soft-delete) because they are SysNDD-managed and never refreshed from an external source. `mode_of_inheritance_list` (HPO) and `variation_ontology_list` (VariO) are `"anchored"`: curated display fields and the `is_active` flag are editable, but terms cannot be created or deleted because they are sourced from an external ontology and may be overwritten on refresh. Ontology-derived tables (`phenotype_list`, `disease_ontology_set`, `non_alt_loci_set`) are never writable here; they are refreshed via `api/functions/metadata-refresh.R` and the admin annotation jobs.
 
 Deletes are soft-deletes (`is_active = 0`) guarded by an in-use reference check: a value still referenced by curation data (`metadata_vocabulary_usage_count()`) fails fast with a 400 instead of being removed. There are no enforced DB foreign keys to these lookup tables, so this application-level guard is the only protection — keep the `usage` reference list in the registry in sync when a new table starts referencing a vocabulary. Migration `033_add_metadata_lookup_admin_columns.sql` added the `is_active`/`sort` columns the two SysNDD-managed lookups needed.
 
 ### Background jobs
 
 Async jobs are durable and MySQL-backed. The web API submits jobs and serves status/history; the separate worker service claims and executes them. Worker-executed code is sourced once when the worker starts. If you change worker-executed code, restart the worker container before assuming the change is live.
 
 Durable job handlers must resolve DB credentials from the worker's **runtime** config, never from the job payload (#535 P1-1). The web API and the worker both hold the same `dw` config object, so `async_job_worker_db_config()` (`api/functions/async-job-db-config.R`, `base::get` on `.GlobalEnv` to dodge the `config::get` mask) returns byte-identical connection config at run time — a job payload never needs to carry `db_config`/`password`, which would otherwise persist in `async_jobs.request_payload_json`. The **backup** family is fully migrated: `svc_backup_create/restore` submit credential-free params, the durable `.async_job_run_backup_create/restore` handlers resolve via the resolver, and `execute_mysqldump`/`execute_restore` pass the password to the MySQL CLIs through a per-invocation **mode-0600 `--defaults-extra-file`** (never `-p<pw>` argv or a `system()` shell string). Historical terminal backup payloads are redacted (and their password-derived `request_hash` recomputed) idempotently by `async_job_scrub_payload_credentials()` — best-effort at API startup, after each restore, and via `api/scripts/scrub-job-payload-credentials.R`. **All** durable families now resolve DB credentials at run time via `async_job_worker_db_config()` / `async_job_db_connect()` (backup, plus publication_refresh/date_backfill, hgnc/comparisons/omim/force_apply_ontology, provider handlers, pubtator_update/pubtatornidd_nightly, and llm_generation — #535 S2b): no job payload carries `db_config`/`password`. The static guard `api/tests/testthat/test-unit-job-payload-credential-guard.R` freezes the offender set at **empty** (backup must never reappear), asserts every migrated handler opens its connection via `async_job_db_connect()`, and fails if any handler reads `payload$db_config`. The historical-payload scrub `async_job_payload_scrub_statement()` is now **job-type agnostic** and redacts **both** `$.db_config.password` and `$.db_config.db_password` (via `JSON_REPLACE`, which never creates an absent key) for terminal, non-retryable rows — best-effort at API startup, after each restore, and via `api/scripts/scrub-job-payload-credentials.R`. The destructive full-table-replace maintenance families (hgnc/comparisons/omim) dedupe via **job-type single-flight** (`async_job_service_duplicate_by_type()`), not a payload hash, so a payload-schema change (dropping `db_config`) cannot open a deploy-window with two concurrent replaces. Because prior payloads/backups/logs may already contain the password, **rotating the DB credential after deploy is an operator step** (the code stops new leakage and scrubs old rows; it cannot rewrite old backup files); a manual maintenance-job drain before deploy is prudent (see `documentation/09-deployment.qmd`).
 
 The worker must have outbound network egress for external providers used inside jobs, including Gemini, PubMed, and PubTator. Keep it attached to both the internal `backend` network for database access and the egress-capable `proxy` network; attaching it only to `backend` breaks DNS/API calls because `backend` is `internal: true`.
 
 Durable jobs run on two lanes so a heavy maintenance job never head-of-line blocks latency-sensitive interactive work (#486). `api/functions/async-job-service.R` is the single source of truth for lane + priority: `async_job_queue_for_type()` routes heavy/bulk/external maintenance job types (`ASYNC_MAINTENANCE_JOB_TYPES`: `publication_date_backfill`, `publication_refresh`, `pubtator_update`, `pubtator_enrichment_refresh`, `pubtatornidd_nightly`, `omim_update`, `hgnc_update`, `comparisons_update`, `ontology_update`, `force_apply_ontology`, `disease_ontology_mapping_refresh`, `nddscore_import`, `backup_create`, `backup_restore`) to the `maintenance` queue and everything else to `default`, while `async_job_priority_for_type()` gives interactive types (`clustering`, `phenotype_clustering`, `llm_generation`, `analysis_snapshot_refresh`, `network_layout_prewarm`) the lowest priority number (10), maintenance types 50, and anything else 100 (the claim query orders `priority ASC`, so lower is claimed first — this also corrects the previous inversion where the batch backfill submitted at priority 50 outranked interactive jobs left at the default 100). `async_job_service_submit()` defaults `queue_name`/`priority` from these helpers when the caller passes neither (`NULL`); explicit overrides are still honored, so the few call sites that intentionally pin a lane/priority (e.g. `analysis-snapshot-refresh-service.R`, `disease-ontology-mapping-service.R`) keep their values. In Compose, the interactive `worker` container drains `ASYNC_JOB_QUEUES=default` and a second `worker-maintenance` container (a deliberate mirror of `worker` — same image, command, volumes, env, restart, `depends_on`, and BOTH the `backend` and `proxy` networks) drains `ASYNC_JOB_QUEUES=maintenance`. The two prod services must stay in sync; only `ASYNC_JOB_QUEUES` differs. Local dev does not run a second container: `docker-compose.override.yml` sets the single `worker` to `ASYNC_JOB_QUEUES=default,maintenance` and profile-gates `worker-maintenance` out of the dev stack (`profiles: [prod-maintenance-worker]`, never activated), so dev still drains both lanes from one worker.
 
 The worker resets the per-request external-time accumulator (`external_proxy_request_reset()`, #344) at the **start of each job**, mirroring the API preroute hook (`api/functions/async-job-worker.R`, just before `handler$run`). Without this the accumulator never resets in the worker, so external time accrues monotonically across the worker's lifetime; once it crosses `EXTERNAL_PROXY_REQUEST_MAX_SECONDS` (default 15s) every subsequent external call in every job short-circuits to a degraded 503 (`request_budget_exceeded`). A legitimately external-heavy **batch** job (one that makes many independent provider calls, e.g. the PubtatorNDD enrichment refresh fetching a background count per gene) must additionally reset the accumulator **per external call** so the per-request ceiling — designed for public request paths — does not cap the back half of the batch; see `.pubtatornidd_reset_external_budget()` in `api/functions/pubtator-enrichment-collector.R` (each call keeps its own per-call timeout/retry via `external_proxy_budget()`).
 
 The `/pubtator/genes` listing reads a precomputed flat per-gene table `pubtator_gene_summary` (migration `035`) via `pubtator_genes_summary_base()` instead of collecting the whole `pubtator_human_gene_entity_view` and nesting it in R per request (the old path was ~800ms — the cost was the R `tidyr::nest`, not SQL; the endpoint is now ~100ms). The table is materialized by `pubtator_gene_summary_refresh()` (one `GROUP BY` swap, shared SELECT with the cold-start fallback) which the nightly orchestrator calls after the enrichment refresh; the endpoint falls back to the identical aggregation computed live (read-only) when the table is empty (cold start), so correctness never depends on it being populated. The summary uses `COUNT(DISTINCT ...)`, which also fixed a latent double-count: the view fans out one row per (gene × publication × entity), so the old R `nrow()` counts reported e.g. `publication_count=86` for a gene with 43 distinct PMIDs and 2 entities; `publication_count` is now the distinct-PMID count (consistent with the `pmids` list) and `entities_count` the distinct-entity count. The nested `publications`/`entities` columns were dropped from the `/pubtator/genes` response (the frontend never consumed them — it lazy-fetches per-gene publications via `/pubtator/table` on row expand).
 
 PubtatorNDD updates run automatically every night. A dumb `pubtatornidd-cron` Compose sidecar (modeled on `log-cleanup`; DB-only, no egress) enqueues one durable `pubtatornidd_nightly` job per night via `api/scripts/pubtatornidd_nightly_enqueue.R`; the worker claims it and runs the orchestrator in `api/functions/pubtatornidd-nightly.R`. The orchestrator single-flights via a non-blocking `GET_LOCK('pubtatornidd_nightly', 0)`, resolves the standing query (payload → `PUBTATORNDD_NIGHTLY_QUERY` env → most-recent `pubtator_query_cache` row), incrementally fetches new publications (`pubtator_db_update_async`, soft page-watermark, ≤3 req/s), refreshes the enrichment snapshot, refreshes the precomputed gene-summary table when that layer exists (guarded extension point), and returns a structured run summary (persisted in the job `result_json`). A benign skip (lock held / no standing query) completes successfully; a failed refresh step marks the job failed so it is observable in job history. The PubtatorNDD enrichment NDD-corpus probe is `@DISEASE_Neurodevelopmental_Disorders` (the resolvable PubTator concept; `@DISEASE_neurodevelopmental` silently returns count=0); the `*` total-corpus probe also returns 0 so `total_corpus_size` uses the flagged `PUBTATOR_FALLBACK_TOTAL_CORPUS`. The `/pubtator/genes` `meta` exposes `enrichmentStatus` (`current`/`missing`) + `enrichmentRefreshedAt`, and when no snapshot exists the listing falls back to a deterministic `-publication_count` order via `pubtator_resolve_genes_sort()` instead of sorting on all-NULL enrichment columns.
 
 GeneNetworks display layouts are derived analysis artifacts. To preserve the current fCoSE compound-graph representation without browser main-thread stalls, workers precompute Cytoscape/fCoSE positions for the exact displayed network and the frontend renders them with Cytoscape `preset`. Public API requests must not run fCoSE synchronously; missing artifacts fall back to browser fCoSE. Keep layout cache keys data-aware: include displayed node/edge set, `cluster_type`, `min_confidence`, `max_edges`, layout options, and Cytoscape/fCoSE versions.
 
 Public analysis endpoints read durable public-ready snapshots from `analysis_snapshot_*` tables. Supported parameter presets are fixed in `analysis-snapshot-presets.R` until a worker/admin refresh precomputes more; unsupported parameters fail fast as `unsupported_parameter`, while supported presets without an active current public-ready row report snapshot diagnostics such as `snapshot_missing`, `snapshot_stale`, or `source_version_mismatch`. Snapshot refresh jobs must use approved-public input gates only, and activation is scoped by exactly one public-ready row per `(analysis_type, parameter_hash)`. MCP analysis reads the same public-ready snapshots only; it must not compute heavy analysis, fCoSE layouts, external calls, or Gemini/LLM summaries on miss.
 
 ### Analysis-snapshot releases (#573)
 
 Analysis-snapshot **releases** are immutable, content-addressed, frozen exports of the public-ready snapshots above (functional clusters, phenotype clusters, phenotype-functional correlation) — the same durable-artifact pattern as the NDDScore/Zenodo release layer, applied to derived analysis. Migration `045_add_analysis_snapshot_release.sql` adds three tables (`analysis_snapshot_release` head + `_member` pinned-snapshot lineage + `_file` per-file gzipped content) and bumped `EXPECTED_LATEST_MIGRATION`/`EXPECTED_MIGRATION_COUNT` in `api/functions/migration-manifest.R`. A release stores its **own** frozen copies (canonical-JSON payloads, raw reproducibility bytes, README, manifest, checksums, a pre-built `bundle.tar.gz`) — never a reference to the source snapshot rows — so it survives snapshot pruning/refresh byte-identically.
 
 - **Content-addressing.** `content_digest` (`analysis_release_content_digest()`, `analysis-snapshot-release-manifest.R`) is a SHA-256 over the invariant scientific content only — `manifest_schema_version`, `source_data_version`, and each layer's `{analysis_type, input_hash, payload_hash, reproducibility_hash, dependencies}` — and deliberately **excludes** `created_at`, `title`, and DOI, so recording provenance metadata never changes release identity. `release_id = "asr_" + content_digest[:16]`; the full 64-char digest is stored and insert is guarded against a same-id/different-digest collision (fails loudly rather than colliding).
 - **Public surface is retrieval-only and DB-only.** `GET /api/analysis/releases`, `.../releases/latest`, `.../releases/<release_id>`, `.../releases/<release_id>/manifest.json`, `.../releases/<release_id>/file?path=<file_path>`, and `.../releases/<release_id>/bundle` are unauthenticated, make no external calls, and are covered by the same cheap-route/external-budget isolation guards as the rest of `/api/analysis`. `.../file` resolves by an **exact `(release_id, file_path)` primary-key lookup** — there is no filesystem access and no path-traversal surface; anything not in `analysis_snapshot_release_file` is a 404. Every public read is pinned to `status = 'published'`, so an unknown release id and a draft release id are indistinguishable (both 404) — drafts are never public. `latest` is declared **before** the dynamic `<release_id>` route (the `/status/_list` shadowing lesson applies here too).
 - **The build is a fail-closed 400 gate**, not a best-effort export (`analysis_snapshot_release_build()`, `functions/analysis-snapshot-release.R`). In order: (1) each registry layer must be `status_code == "available"` from `analysis_snapshot_get_public()`; (2) a **hard** partition-coherence re-check (`analysis_snapshot_assert_partition_coherent(..., require_coherence = TRUE)`) runs on every cluster layer regardless of the `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` env downgrade — `available` only proves freshness/schema/source-version, not #514 coherence, so a release can never freeze an incoherent-but-`public_ready` snapshot; (3) each cluster layer must have a stored reproducibility bundle (the snapshot builder makes it best-effort, the release makes it mandatory); (4) all layers must share one `source_data_version`, and the correlation layer's dependency lineage must match the pinned functional + phenotype `snapshot_id`+`payload_hash` (the #571/#572 dependency gate); (5) a **TOCTOU guard** — the same per-preset advisory lock the axis refresh holds, plus a fresh pre-insert re-read of every layer immediately before persisting — closes the race between the initial read and the insert. Any gate failure is `stop_for_bad_request()` (400; there is no 409 class), naming the failing layer/reason. A rebuild whose content is **identical** to an existing release is not an error: it returns the existing head idempotently (200, no duplicate row); a genuinely new content set is 201.
 - **Hashing facts, precisely.** Every file carries its **own** `content_sha256`. For each cluster layer, `sha256(reproducibility.json) == reproducibility_hash` **exactly** — this uses the raw pre-gzip bundle bytes (`analysis_reproducibility_decode_raw()`, `memDecompress(..., asChar = TRUE)`), never `analysis_reproducibility_decode()`, whose `jsonlite::fromJSON()` + re-serialize round-trip drops the bundle's full-precision (`digits = NA`) contract and breaks the equality. By contrast, `payload_hash`/`input_hash`/`snapshot_id` are recorded in the manifest as cross-checkable **lineage anchors** against the live `meta.snapshot.{payload_hash,input_hash,snapshot_id}` on the corresponding `/api/analysis/*` endpoint — they are **not** equal to a hash of the release's own `payload.json` file (the stored payload round-trips through `DECIMAL(8,7)`/`DECIMAL(8,5)` DB columns before the release freezes it, so a reconstructed byte-for-byte match is neither guaranteed nor attempted).
 - **DOI is additive, outside the hash.** `PATCH /api/admin/analysis/releases/<id>/doi` (Administrator) records `{zenodo_record_id, zenodo_record_url, version_doi, concept_doi}` — any subset, an omitted field is left unchanged, never nulled out — and never touches `content_digest`/`manifest_sha256`; recording a DOI after publish changes zero release bytes.
 - **Never pruned.** A published release is permanent; `DELETE /api/admin/analysis/releases/<id>` only works on a `draft`. `analysis_snapshot_prune()` (`analysis-snapshot-repository.R`) now skips any `snapshot_id` still referenced by an `analysis_snapshot_release_member` row (`analysis_release_referenced_snapshot_ids()`), so a snapshot pinned by a release keeps serving its live reproducibility endpoint too — even though release integrity never depends on the source snapshot surviving (each release is self-contained).
 - **Build is synchronous, admin, DB-only — the worker is NOT required.** Unlike snapshot refresh, `POST /api/admin/analysis/releases` runs inline on the API request (`analysis_snapshot_release_build()` is called directly from the endpoint, not submitted as an async job): no clustering recompute, no external calls, no LLM, no cache writes. A release can be built even if the worker is down, as long as public-ready snapshots already exist.
 - **`GET .../releases/<release_id>/file?path=<file_path>` uses a query param, not a nested path segment**, because Plumber 1.3.2 has no `<path:.*>` wildcard — only named, typed, single-segment path params (`<id>`, `<id:int>`) exist, so a nested archive path (e.g. `functional_clusters/payload.json`) cannot be expressed as a URL path segment. The manifest's `files[].path` values are the caller's index into this route.
 
+`POST /api/jobs/clustering/submit` can resolve its clustering gene universe from a curated confidence category instead of an explicit gene list (#574). `clustering_resolve_category_universe()` (`api/functions/clustering-gene-universe.R`) does entity-level resolution: a gene qualifies if it has >=1 `ndd_phenotype == 1` entity whose `category` is in the selector, filtered directly against `ndd_entity_view` — **never** `select_network_gene_category()` (the gene-level display-label aggregator used for node coloring only, not a universe filter). `category_filter` absent → the byte-identical existing default (`generate_ndd_hgnc_ids()`, cache parity preserved); supplied-but-empty → 400; validated live against `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded category strings, no interpolated SQL) with the allowed active set named in the error **message**; a resolved universe under 2 genes → 400. `genes` and a non-empty `category_filter` are mutually exclusive (400). The durable job payload gains a normalized `category_filter` key — and the dedup identity becomes selector-aware — **only** for category selectors, so explicit-genes and no-arg submits keep byte-identical `request_hash`/payload shape to pre-#574. Every submit records provenance — `selector` (`kind`: `explicit`|`category`|`all_ndd`), `resolved_gene_count`, `gene_list_sha256`, an **intended** fingerprint (STRING cache fingerprint + score threshold + algorithm + seed), and a cached fail-closed `source_data_version` — in the payload; the result `meta` additionally carries an **effective** `effective_fingerprint` (the STRING `weight_channel` the computed result actually used), on both a cache-hit response (`svc_job_submit_functional_clustering()`) and a worker-run job (`.async_job_run_clustering()` in `async-job-handlers.R`), so a silent exp+db→combined-score fallback is visible either way. Results from this endpoint (category-filtered or not) are ephemeral job results and are **never** `public_ready` — distinct from the public `analysis_snapshot_*` layer above.
+
 ### Cluster-analysis statistical soundness (#508–#512)
 
 The two-axis cluster analysis (phenotype MCA/HCPC and functional STRING/Leiden) and the served "function is modular, phenotype is a continuum" cross-axis interpretation are made mathematically sound and self-reproducing. `validation_schema_version` is `"2.0"`, `ANALYSIS_SNAPSHOT_SCHEMA_VERSION` is `"1.2"`. The **key lever**: `analysis_snapshot_payload_hash` deliberately excludes `partition_validation` (`analysis-snapshot-builder.R`), so everything in the validation block is **additive** — new metrics never change `cluster_hash` and never invalidate LLM summaries. Only changes to cluster **membership** (the #508 MCA filter, the #509 `kk=Inf` consolidation, the #510 channel switch) change `cluster_hash` and therefore require a coordinated forced snapshot refresh + LLM regeneration.
 
 - **Common cross-axis footing (#511)** lives in `api/functions/analysis-null-models.R` (worker/heavy-path only; registered in `bootstrap/load_modules.R`). Both axes report a **unit-free, null-calibrated `separation_z`** so the contrast is like-for-like instead of raw-silhouette-vs-raw-modularity: functional = **modularity z-score** vs a **degree-preserving configuration-model null** (`modularity_null_zscore`: `igraph::rewire(keeping_degseq)` + permuted weight multiset, re-restricting **both** the observed graph and every replicate to the largest connected component, and **re-detecting communities with the identical seeded Leiden on each replicate** — the Guimerà/Sales-Pardo/Amaral re-optimized null, so `modularity_z` benchmarks against the modularity a degree-matched random graph genuinely reaches rather than being a near-tautological Q-vs-0 test; **never** revert this to carrying the observed labels onto the null, which inflates the z by orders of magnitude); phenotype = **silhouette z-score** vs a **label-permutation null** (`silhouette_null_zscore`). The `modularity_null_zscore` `recluster` argument selects the flavour: the functional axis passes a Leiden closure (re-optimized, `null_model = "…_reoptimized"`), while the phenotype `shared_modularity_z` passes **none** and holds the external MCA/HCPC labels **fixed** on the kNN null (`"…_fixed_labels"`) because the graph cannot re-derive that partition (it is an attribute-assortativity test). Additionally a **dip test of unimodality** (`dip_unimodality`, Hartigan; optional `diptest` dependency — degrades to `NA` if absent) is reported on both axes' pairwise-distance distributions as a **corroborating** continuum-vs-modular signal (`dip_p` small → discrete; large → continuum); the functional dip runs on **continuous weighted shortest-path distances** (edge distance `1 - combined_score/1000`), NOT integer hop counts, so it is not a discreteness artifact, and because pairwise distances are mutually dependent `dip_p` corroborates rather than strictly proves. The SAME modularity-z index is also reported for phenotype on a mutual-kNN graph of the MCA coords (`knn_similarity_graph` → `shared_modularity_z`). Never resurrect a direct silhouette-vs-modularity comparison.
 - **Functional axis is text-mining-free (#510).** `build_string_subgraph` (`analyses-functions.R`) prefers a graph whose weights are recombined from the STRING **experimental + database** channels only (STRING's probabilistic-OR formula in `analysis-string-channels.R`, `string_recompute_score`/`string_expdb_subgraph`), dropping the text-mining/co-mention channel that would make a "molecular pathways organize NDD" claim partly restate co-study structure (≈540 of ~3200 NDD genes had STRING edges **only** via text-mining). The exp+db score is carried in the existing `combined_score` edge attribute (so the weighted-Leiden/modularity plumbing is unchanged) plus a `weight_channel` graph attribute; it **falls back** to the STRINGdb combined graph when the compact edge file is absent, so a fresh checkout still functions. That file, `data/9606.protein.links.expdb.v11.5.min400.txt.gz`, is a gitignored runtime artifact built by `api/scripts/build-string-expdb.R` from the ~115 MB `9606.protein.links.detailed.v11.5.txt.gz` download; the **worker needs `data.table` and this file**. STRING lists every undirected pair in **both** directions, so `string_expdb_subgraph()` **`simplify()`-es** the induced graph at read (and the builder writes only the canonical `protein1 < protein2` half) — otherwise every edge is double-counted (2× `giant_component$n_edges`, a doubled reproducibility edge list, and disagreement with the simple STRINGdb-combined fallback); weighted Leiden/modularity are invariant to the uniform duplication, so the partition is unchanged. The **headline `modularity`** is the full-partition Q; its **z-score, degree-preserving null, giant-component counts** (`giant_component`: isolates/components/retention), and the reconcilable **`modularity_lcc`** (the exact Q the z is computed on) are all on the **largest connected component** (disconnected fragments are trivial "perfect communities" that inflate Q); an env-gated (`ANALYSIS_REPORT_COMBINED_SENSITIVITY`) `modularity_combined_score` reports how much Q changes with text-mining included.
 - **Phenotype MCA feature hygiene + real consolidation (#508/#509).** The shared helper `phenotype_mca_prep_matrix()` (`analysis-phenotype-mca-prep.R`) applies the hygiene once, and **every** phenotype-matrix path calls it — `generate_phenotype_cluster_input` (served snapshot + validator) **and** `.async_job_phenotype_matrix` (the interactive/durable `/api/jobs/phenotype_clustering` job) — so the interactive product can never diverge from the public snapshot (keep them on the one helper; do not re-inline the prep). It drops the HPO subtree root `HP:0000118` and any organ-system term outside the prevalence band (`PHENOTYPE_MCA_PREVALENCE_MIN`/`MAX`, default 0.05–0.95 — near-universal/near-rare terms add null/outlier MCA dimensions that mechanically depress separation) and recodes presence from `{"yes",NA}` to explicit `{absent,present}` factors (an all-NA character column is **not** treated as a presence column, so a fully-missing supplementary column can't be misclassified and shift the `quali.sup`/`quanti.sup` indices). `gen_mca_clust_obj` uses `HCPC(kk = Inf, consol = TRUE)` because FactoMineR ≥2.13 **silently disables consolidation when `kk != Inf`** (`if ((kk != Inf) & (consol == TRUE)) { warning(...); consol <- FALSE }`) — the old `kk = 50` claimed consolidation but never ran it; do **not** reintroduce a finite `kk` while asserting consolidation. The `k_selection_curve` re-runs the exact served procedure (`gen_mca_clust_obj(cutpoint = k)`, which re-seeds internally) at each k and anchors at the true data-driven HCPC k (exposed via an attribute), so `k_selection_curve[hcpc_nb_clust] == mean_silhouette` by construction; `k_decision_curve` reports the relative within-cluster inertia loss HCPC actually uses to pick k (so it is explicit k was not chosen by silhouette), and `silhouette_interpretation` bands the value honestly (≤0.25 Kaufman–Rousseeuw → `no_substantial_structure_continuum`).
 - **Reproducibility bundle (#512).** Migration `041_add_analysis_reproducibility.sql` adds `analysis_snapshot_reproducibility` (gzip canonical-JSON bundle + SHA-256 `reproducibility_hash`). `analysis-reproducibility.R` builds/decodes/persists the bundle (functional: full LCC edge list + complete membership incl. sub-`min_size`; phenotype: MCA coords + assignment + params) and the builder attaches it (also excluded from `payload_hash`). Two DB-only public routes — `GET /api/analysis/functional_clustering/reproducibility` and `.../phenotype_clustering/reproducibility` (routes in `analysis_endpoints.R`, handler `analysis_reproducibility_endpoint`) — let a consumer recompute modularity/silhouette from published artifacts. **Wave-2 activation runbook** (after these membership-changing changes deploy): restart the worker (worker-executed code changed), `POST /api/admin/analysis/snapshots/refresh?analysis_type=functional_clusters&force=true` and `…phenotype_clusters&force=true`, then `POST /api/llm/regenerate?cluster_type=functional&force=true` and `…phenotype&force=true` (cluster hashes changed, so summaries must regenerate). Spec/plan: `.planning/superpowers/specs|plans/2026-07-05-cluster-soundness-508-512-*.md`.
 
 ### Cluster-snapshot cache coherence & self-healing analysis deploys (#514)
 
 The heavy clustering functions (`gen_string_clust_obj`, `gen_network_edges`, `gen_mca_clust_obj`) are memoised onto a disk cache that lives on a **named volume and survives redeploys** (`api/bootstrap/init_cache.R`). Historically the memoise key was only the call args, so a methodology change (the #510 exp+db graph, #508/#509 MCA hygiene) did **not** change the key: the snapshot builder read **membership** from a stale disk-cache hit (`gen_string_clust_obj_mem`) while the **validator** (`validate_functional_clusters`, not memoised) recomputed fresh on the new graph, and the integer-`cluster_id` join then left real clusters with `n/a` stability — a **stale, internally-incoherent** snapshot that still activated as `public_ready`. Three coupled mechanisms now prevent AND catch this; keep them together.
 
 - **Self-invalidating fingerprint (the fix).** `api/functions/analysis-cache-fingerprint.R` defines `CLUSTER_LOGIC_VERSION` (bump on ANY clustering input/algorithm change) plus `analysis_string_cache_fingerprint()` (version + STRING channel + exp+db file `size:mtime`) and `analysis_phenotype_cache_fingerprint()` (version + MCA prevalence band). Each clustering function carries a trailing **`.cache_fingerprint`** formal whose **call-time** default is the relevant fingerprint (memoise 2.0.1 hashes call-time default args — verified), so the fingerprint enters the memoise key with **zero call-site changes** and the body ignores it. Evaluation is at **call time, not boot**, so adding/rebuilding the exp+db artifact self-invalidates the relevant entries **without a restart** (the exact prod scenario). The default is `exists()`-guarded so minimal/test envs degrade to a NULL key component instead of erroring. A code change → bump `CLUSTER_LOGIC_VERSION`; a data/channel/prevalence change self-invalidates. This **supersedes** the manual `CACHE_VERSION` bump for clustering caches (`CACHE_VERSION` still governs other memoised return-shape changes). Registered in `bootstrap/load_modules.R` (API + durable worker + MCP sidecar) and `bootstrap/setup_workers.R` (mirai parity). **Never** revert the memoise key to args-only.
 - **Snapshot integrity gate.** `api/functions/analysis-snapshot-coherence.R` — the builder joins validation onto membership through `analysis_snapshot_join_validated_clusters()`, which first calls `analysis_snapshot_assert_partition_coherent()`. It **refuses to publish** (throws → refresh fails → prior `public_ready` retained, new row `failed`) when the visible membership cluster set ≠ the validation cluster set, any visible cluster lacks a stability score, the membership channel ≠ the validation channel, **or** any shared cluster-id's served member set ≠ the validated reference member set (a **same-partition proof**, not just same labels — the validators return `reference_members`, STRING ids for functional / entity ids for phenotype, keyed by cluster_id, so a stale membership whose labels happen to coincide is still caught). `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` (default `true`) is the hard gate; `false` downgrades to a warning. The builder joins **only** through this helper — do not reintroduce a bare `left_join(clusters, val$per_cluster)`.
 - **Channel observability.** `gen_string_clust_obj` records the channel the served membership was actually clustered on (`attr(subgraph, "weight_channel")`) and carries it on the tibble (survives the RDS memoise round-trip); the builder exposes it additively as `partition_validation$membership_weight_channel` (excluded from `payload_hash`, so no `cluster_hash` churn) and the gate compares it to the validator's `weight_channel`. `build_string_subgraph` now emits a **`warning()`** (not just a `message()`) when an intended exp+db graph falls back to the text-mining `combined_score` graph, and `GET /api/health` exposes `analysis.expdb_edges_file_present` + `analysis.cluster_logic_version` so a missing data-prep artifact is visible at a glance.
 - **exp+db artifact is required for the #510 methodology.** `data/9606.protein.links.expdb.v11.5.min400.txt.gz` is a gitignored runtime artifact built by `api/scripts/build-string-expdb.R`; api/worker/worker-maintenance already bind-mount `./api/data`, and the `mcp` service now mounts it **read-only** so the MCP cache-probe fingerprint matches the writer's (a mismatch only makes MCP **miss**, never serve stale). A fresh deploy still functions without it (combined fallback), but functional clustering is then **not** text-mining-free — the health flag + fallback warning make that loud.
 - **Methodology-deploy runbook (`documentation/09-deployment.qmd`):** ensure the exp+db artifact exists → bump `CLUSTER_LOGIC_VERSION` when the algorithm/inputs changed → restart worker (worker-executed code) → `POST /api/admin/analysis/snapshots/refresh?...&force=true` for both clustering presets → verify `GET /api/analysis/functional_clustering` shows agreeing membership + metrics and `weight_channel = experimental_database`. Guards: `api/tests/testthat/test-unit-analysis-cache-fingerprint.R`, `test-unit-analysis-snapshot-coherence.R`, `test-unit-string-expdb-subgraph.R`.
 
 LLM cluster summaries must match the SAME published snapshot the public serves (#485/#488/#490). The summary cache key is the snapshot's per-cluster `cluster_hash` **plus** a code/prompt version: `LLM_SUMMARY_PROMPT_VERSION` (`api/functions/llm-summary-config.R`, currently `1.0`) is written on every `save_summary_to_cache()` and bound into every lookup (`get_cached_summary()`, `mcp_analysis_repo_get_cached_llm_summaries()`); bump it when the summary/judge prompt or generation logic changes so unchanged-membership clusters regenerate instead of serving pre-deploy summaries. On snapshot refresh, `analysis_snapshot_trigger_llm_generation()` also calls `retire_orphan_cluster_summaries(cluster_type, payload$clusters$cluster_hash)` to drop `is_current` rows whose hash left the snapshot — retirement is by hash membership only, never by status (a rejected-but-live snapshot hash is kept on purpose). The Administrator `POST /api/llm/regenerate` is snapshot-driven: it reads the published snapshot's clusters via `service_analysis_snapshot_shape_clusters()` and never recomputes clustering (recomputing produced non-matching hashes that corrupted the served set); a missing public-ready snapshot returns 409, and `force=true` is threaded through `trigger_llm_batch_generation()` → `llm_batch_executor` (see `llm_should_skip_cached()`) instead of being a no-op. A judge-rejected current summary is a **terminal** serving state, not "still generating": `get_cluster_summary()` returns HTTP 200 `{summary_available:false, validation_status:"rejected", reason}` (frontend renders an explicit "could not be validated" card), the judge reason is persisted to `llm_generation_log` (`status="validation_failed"`) with the authoritative snapshot hash, and MCP/public reads stay validated-only (`require_validated=TRUE`).
 
 The phenotype LLM-judge must ground against the SAME enriched/depleted phenotype set the generator saw (#495). `build_phenotype_judge_prompt()` (`api/functions/llm-judge-prompts.R`) previously truncated its grounding to the **top-15 phenotypes by `|v.test|`**; for the largest phenotype cluster (the ~1000-entity "pure/isolated intellectual disability + seizures" cluster) the `|v.test|` ranking is dominated by strong **depletions** (heart, genitourinary, skeletal, metabolic — all *absent*), so genuinely **enriched**, cluster-defining phenotypes (Seizures `+8.2`, ID-profound `+8.2`, Behavioral `+7.7`, Microcephaly `+4.1`) fell to rank #17+ and disappeared from the judge's "authoritative source". The judge then flagged the generator's correctly-grounded mentions of them as "fabricated specific phenotypes" and hard-rejected every attempt (#490's retry cap made this a terminal `rejected`). The generator (`build_phenotype_cluster_prompt()`, all `|v.test| > 2`) was always producing a grounded summary — this was a **judge false-rejection from grounding-set truncation, not a generation hallucination** (confirmed by a live Gemini A/B on the real cluster: same summary, old top-15 judge → `reject`, new judge → `accept`; independently corroborated by Claude and Codex judging the full data). The fix lists **ENRICHED and DEPLETED separately** (both `|v.test| > 2`, each capped at 30, mirroring the generator) so an enriched term is never crowded out. This is a **judge-only** change, so `LLM_SUMMARY_PROMPT_VERSION` is deliberately **not** bumped (a more-lenient judge keeps prior `validated` rows correct; bumping would gratuitously blank clusters 1 & 3). Recovery for an already-cached terminal-`rejected` cluster is a forced regeneration — `POST /api/admin/analysis/snapshots/refresh?analysis_type=phenotype_clusters&force=true` (or `POST /api/llm/regenerate?cluster_type=phenotype&force=true`) after restarting the worker (worker-executed judge code changed) — because a non-forced refresh short-circuits on the existing `is_current` rejected row (`llm_should_skip_cached()`). Static guard: `api/tests/testthat/test-unit-llm-judge-grounding-symmetry.R`.
 
 Snapshots auto-bootstrap on API startup (#420) so a fresh deploy heals on its own instead of serving `snapshot_missing` until an operator runs the Make target. `analysis_snapshot_bootstrap_on_startup()` runs after migrations in `start_sysndd_api.R` (mirroring the #421 pubtatornidd bootstrap): gated by `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP` (default on), idempotent (only enqueues presets that are not already *current* via the `analysis_snapshot_public_current()` probe, so a restart with fresh snapshots present enqueues nothing), dedup-safe, and never crashes boot. The skip probe is staleness-aware on purpose: `analysis_snapshot_public_current()` returns TRUE only when the active public-ready row's computed `status_code` is `"available"`, so a snapshot that has aged past `stale_after` (default 7 days, env `ANALYSIS_SNAPSHOT_STALE_AFTER_DAYS`) or whose `source_data_version` no longer matches is treated as needing refresh and re-enqueued — it self-heals on the next restart instead of serving a permanent `snapshot_stale`/`source_version_mismatch` 503. The earlier `analysis_snapshot_public_exists()` probe only checked the row's existence (ignoring staleness), so stale snapshots never healed; do not revert the default skip predicate in `service_analysis_snapshot_submit_refresh()` back to it (guarded by `api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R`). All three submit paths — the startup hook, the new Administrator endpoints, and the operator script `scripts/refresh-analysis-snapshots.R` (which forces a rebuild) — share one function, `service_analysis_snapshot_submit_refresh()`; keep it the single source of submission logic. The Administrator-only HTTP triggers are `POST /api/admin/analysis/snapshots/refresh` (optional `analysis_type`, optional `force`) and `GET /api/admin/analysis/snapshots/status` (per-preset state), in `endpoints/admin_analysis_snapshot_endpoints.R` mounted at `/api/admin/analysis` **before** `/api/admin` so the more-specific prefix wins; they let an operator rebuild/inspect snapshots without SSH or `docker exec`. The **startup** bootstrap staggers heavy builds to reduce first-start contention (#447): presets carry a `weight` (`analysis_snapshot_preset_weight()`; `functional_clusters` and `phenotype_clusters` are `"heavy"` — both run subsampling cluster-validation), and the bootstrap calls `service_analysis_snapshot_submit_refresh(stagger = TRUE)` so heavy presets get a `scheduled_at` offset (`ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS`, default 120s; `0` disables) while the light presets stay immediately claim-eligible. The PubtatorNDD startup bootstrap is likewise offset (`PUBTATORNIDD_BOOTSTRAP_STAGGER_SECONDS`, default 240s) so it does not co-launch with the snapshot bootstrap. Only the startup path staggers — the operator/admin `force` refresh and the operator script submit at `now`, so a manual rebuild is never delayed. Staggering relies only on the existing `async_jobs.scheduled_at` claim gate (no schema change); the worker still claims by `priority ASC, scheduled_at ASC`.
 
 ### Curation-comparison sources & refresh
 
 The cross-database comparator (`ndd_database_comparison` table, `ndd_database_comparison_view`, `/api/comparisons/*`, and the `/CurationComparisons` page) is refreshed by the durable `comparisons_update` async job. `create_job()` submits only its operation and payload as a **durable System B job**; its passthrough handler resolves the executor via `base::get("comparisons_update_async")`, so the write-path functions must be sourced into the durable worker, not just the mirai pool. `api/bootstrap/load_modules.R` is the single loader (`bootstrap_load_modules()`, called by both the API in `start_sysndd_api.R` and the durable worker in `start_async_worker.R`): it sources `omim-functions.R` → `comparisons-sources.R` → `comparisons-parsers.R` → `comparisons-omim.R` → `comparisons-functions.R` in that order — register any new comparisons file there. (`setup_workers.R`'s mirai `everywhere()` block still sources the same files for legacy parity, but comparisons no longer runs on the mirai pool, so registering there alone is not enough.) The per-source parsers + `standardize_comparison_data` live in `api/functions/comparisons-parsers.R`, the OMIM-NDD adapter/sweep in `api/functions/comparisons-omim.R`, and download + HGNC resolution + the orchestrator in `api/functions/comparisons-functions.R` (which guard-sources the parsers so direct-source tests work); the split keeps every file < 600 lines. **Restart the worker container** (durable job code is sourced at worker startup) after changing comparisons code before a refresh reflects it.
 
 Source URLs live in the `comparisons_config` table (seeded by migration `007`, patched by later migrations). Active source keys: `radboudumc_ID`, `gene2phenotype` (EBI G2P API `.../api/panel/DD/download`, migration `013`), `panelapp`, `sfari`, `ndd_genehub`, `orphanet_id`; OMIM (`omim_ndd`) is handled out-of-band (`download_genemap2` + `download_phenotype_to_genes`, needs `OMIM_DOWNLOAD_KEY`, so it is skipped as `partial` when the key is absent). The old **geisinger_DBD** source was repointed to NDD GeneHub (`https://nddgenehub.org/files/Full-Data.csv`, migration `038`) after `dbd.geisingeradmi.org` was retired, then renamed `geisinger_DBD` → `ndd_genehub` everywhere (migration `040`: source key, the `list` value, parser, exports, and frontend column keys) to drop the stale identifier. `parse_ndd_genehub_csv()` aggregates the case-level `Full-Data.csv` per gene (phenotype union, distinct PubMed IDs — whose per-gene lists reach ~1 KB, which is why migration `039` widened `publication_id` — derived inheritance). The per-gene `category` is the NDD GeneHub **evidence tier** (`AR` / `Tier 1`–`Tier 4` / `Missense`, else `Unclassified`), looked up by `ndd_genehub_category_lookup()` from the two sibling exports `Full-LoF-Table-Data.csv` (LoF `Tier` 1–4 or `AR`) and `Full-Missense-Table-Data.csv` — `Full-Data.csv` itself has no tier column, and LoF tier wins over Missense when a gene is in both.
 
 The refresh is **resilient, not all-or-nothing** (previously one dead upstream froze every comparator): each source downloads/parses independently, a failed source is recorded and *keeps its previous rows* via a **per-list replace** (`DELETE ... WHERE list IN (<refreshed lists>)` then insert; `comparison_id` is left to AUTO_INCREMENT so retained rows never collide). `comparisons_refresh_outcome()` (`comparisons-sources.R`) is the single decision point: 0 succeeded → abort without touching the table; all succeeded → `success`; some failed → commit + `partial` with the failed sources named in `comparisons_metadata.last_refresh_error`. A `dbWriteTable`-style DB restore silently drifts the `ndd_database_comparison` schema (narrow auto-sized VARCHARs, `comparison_id` recreated as a `DOUBLE` primary key without AUTO_INCREMENT, dropped `granularity` column) — which fails the refresh with "Data too long" or a PK violation because the per-list re-insert relies on AUTO_INCREMENT; migration `039` idempotently re-asserts the migration-009/012 schema (re-adds `granularity`, converts `comparison_id` to `INT AUTO_INCREMENT`, widens the text columns). The frontend reads refresh status from `GET /api/comparisons/metadata` and the live source list / download URLs / last-update date from `GET /api/comparisons/sources` (both DB-only, driven by `comparisons_config` + `comparisons_metadata`; `CurationSourcesPopover.vue` renders the provenance panel from `/sources` instead of hardcoded, drift-prone text).
 
 The OMIM-NDD comparator NDD seed is configurable (#502): `adapt_genemap2_for_comparisons(seed_term = "HP:0012759")`, and `omim_ndd_seed_sweep()` produces a per-seed sensitivity summary (gene-set size + SysNDD coverage gap). **NDD membership = the seed term OR ANY OF ITS DESCENDANTS**, and the descendant set must be expanded **explicitly** — HPO's `phenotype_to_genes.txt` is **NOT** upward-propagated, so a disease annotated only with a specific descendant (e.g. `HP:0001249` "Intellectual disability") does NOT also carry the ancestor seed, and filtering the single seed silently drops it (~600 OMIM diseases for the default seed, including ~25 intellectual-disability entries). `omim_ndd_resolve_terms()` expands the seed via the JAX ontology API `/descendants` (`hpo_all_children_from_term_api()`, a bounded `httr2` request — `req_timeout` + one retry — so a stalled ontology API cannot hang the worker); the adapter then filters `hpo_id %in% ndd_terms`. Resolution failure degrades to seed-only but is **observable**: `hpo_all_children_from_term_api()` `warning()`s on any fetch error or empty/malformed response (a silent fall-back would re-introduce the under-capture bug). This mirrors the kidney-genetics pipeline and the db-side data-prep script `db/11_Rcommands_...comparisons.R`, which builds the same set with `HPO_all_children_from_term()` and filters `hpo_id %in% ndd_phenotypes` (keep the API and db-side in sync). The seed is `OMIM_NDD_SEED_TERM` (default `HP:0012759`) resolved through the single helper `omim_ndd_seed_term()`, used by **both** the durable refresh (`comparisons-functions.R`) and the `/comparisons/sources` provenance so they never advertise a seed the refresh did not use; the db-side reads the same env var. Do NOT revert to a single-term `hpo_id == seed_term` filter, and do NOT let the refresh fall back to a hardcoded seed while provenance reads the env.
 
 HPO term data (db-prep helpers, and the unused API variants in `api/functions/hpo-functions.R`) now targets the JAX ontology API `https://ontology.jax.org/api/hp/terms/{id}` (`hpo_term_api_base` in `db/config/db_config.R`); the legacy `hpo.jax.org/api/hpo/term` was retired and its JSON shape changed (flat `name`/`definition`; `/children` and `/descendants` sub-paths). Descendant computation uses the single `/descendants` call instead of a recursive per-term walk. HPO term browse outlinks moved to `https://hpo.jax.org/browse/term/{id}` (the `/app/` prefix was dropped in the site rebuild).
 
 ### NDDScore prediction layer
 
 NDDScore lives in the four `nddscore_*` tables and three current-release views added by migration `023_add_nddscore_prediction_release.sql`. It is a model-derived prediction layer, separate from curated SysNDD evidence. It must never be represented as a curation status or as changing curated SysNDD classifications; use copy such as `ML prediction`, `Model-derived`, `Prediction layer`, `Separate from curated SysNDD evidence`, and `Not an evidence tier`.
 
 NDDScore imports run through the durable `nddscore_import` System B async job registered in `async_job_handler_registry`. The worker executes the job and needs outbound egress for Zenodo. Imports are serialized with the `nddscore_import` MySQL advisory lock, and activation switches atomically through the generated-column unique key on `active_release_slot`; a currently active release cannot be re-imported as active. The upstream `nddscore_release.json` `is_active` value is ignored because active release state is SysNDD-controlled.
 
 The default NDDScore Zenodo source is deployment-configurable. Prefer `NDDSCORE_ZENODO_RECORD_ID` and `NDDSCORE_ZENODO_API_BASE_URL` in the deployed `.env`; `api/config.yml` carries the same defaults for local/test fallback. Do not reintroduce independent frontend defaults for the record ID.
 
 ### Read-only MCP sidecar
 
 `api/start_sysndd_mcp.R` runs the MCP server as a separate sidecar/process, not inside Plumber. The Phase 0 spike proved `mcptools` HTTP initialize -> `tools/list` -> `tools/call`, `GET 405`, no required session header, and JSON-serialized text output; v1 tools should keep stable JSON text with `schema_version` as the compatibility contract. The sidecar also patches `mcptools` to advertise output schemas, read-only tool annotations, static schema resources, and tool-visible recoverable errors. MCP prompts are disabled by default because agentic clients such as Claude Code surface them as user-invoked slash commands, not automatically discovered LLM workflows; enable them explicitly with `MCP_ENABLE_PROMPTS=true` only when slash-command prompts are wanted.
 
 The MCP container healthcheck must stay cheap and data-independent: use `api/scripts/mcp-healthcheck.R` for `initialize` + `tools/list` liveness only. Keep `api/scripts/mcp-smoke.R` as the heavier developer/CI verification probe because it exercises real tools and approved public DB content.
 
 MCP analysis cache access is read-only. The sidecar binds the same memoised wrapper names as the API and mounts `api_cache` read-only so it can inspect and read already-warmed derived-analysis cache entries. It must not initialize cache versions, clear cache files, compute STRING/phenotype clusters, or write cache entries; API endpoints or worker/admin jobs remain responsible for prewarming derived analysis data.
 
 Phenotype correlations served through MCP are cache-hit-only; MCP must not call `generate_phenotype_correlations()` directly on a cache miss.
 
 MCP v1 is private/internal by default in Compose. Do not expose public unauthenticated `/mcp`; any route must be private or static-bearer protected at the proxy/service boundary.
 
 The frontend owns a public `/mcp` information page for browser `GET text/html` requests. In development, Vite may proxy MCP protocol traffic on the same path to the sidecar; browser navigation must continue to render the information page. In production, only add a real `/mcp` transport route when it is protected and method/header-scoped so normal browser visits still reach the informational page.
 
 MCP client ergonomics are part of the contract. Keep initialize instructions SysNDD-specific but concise, with the gene -> entity -> publication workflow, the entity model, deferred-tool loading guidance, cheap-path payload controls, resource semantics, and read-only constraints. `MCP_SCHEMA_VERSION` is `1.2`. `get_sysndd_capabilities` is the longer in-band guide for workflows, limits, payload modes, citation rules, resources, prompt opt-in status, errors, and v1 exclusions. Keep `resources/list` / `resources/read` aligned with distinct `sysndd://schema/overview` and `sysndd://schema/tool-guide` content; record-like `sysndd://gene`, `sysndd://entity`, and `sysndd://publication` URIs are stable identifiers, not v1 parameterized resources. Publication outputs are citation-friendly (`recommended_citation`), expose `publication_date_sysndd_record` with a `publication_date_confidence` flag (`pubmed_verified`, `pubmed_partial`, `unverified`) sourced from the `publication.publication_date_source` column, distinguish that date from `sysndd_curation_date`, expose `abstract_available` when abstract text is requested or metadata mode is selected, and omit `abstract_excerpt` unless `abstract_mode = "excerpt"`. `recommended_citation` omits the year when the date is unverified. Historical rows remain unverified until the one-off PubMed backfill is applied.
 
 MCP 1.2 analysis tools expose only the analysis catalog, gene research context, NDDScore context, curation comparison context, phenotype analysis context, and gene network context. All analysis payloads must label their data class as `curated_sysndd_evidence`, `curated_derived_analysis`, `ml_prediction`, `llm_generated_summary`, `external_reference_identifier`, or `operational_metadata`. NDDScore is always an ML prediction layer, separate from curated SysNDD evidence, not an evidence tier, and must not alter curated classifications. LLM summaries exposed through MCP are current, validated, admin-generated cache reads only; MCP must not expose LLM prompts/queries or trigger Gemini/LLM generation. MCP must not call live external gene providers; stored external IDs may be shown only as `external_reference_identifier`. Large analysis tools default to `response_mode = "compact"` and `max_response_chars = "auto"`, expose `budget` metadata with `dropped_summary`, support `dry_run`/`diagnostics` where broad results are possible, and guide clients through the low-token path: catalog first, gene research dry-run/compact second, focused follow-up tools third.
 
 Recoverable MCP validation failures should return a JSON tool result with `schema_version`, `error.code`, and `isError = true`, not raw R errors or JSON-RPC `-32603`. Do not keep hidden parameter aliases; clients should use the advertised schema. Include short examples and boolean defaults in tool descriptions, default `get_gene_context(include_comparisons = false)` for the cheap path, use `response_mode = "minimal"` for structure-first retrieval, use `get_gene_context(expand = "entities")` for one-call gene detail when the caller opts into it, cap that detailed expansion at the 20-ID batch limit, and use `get_genes_context`, `get_entities_context(dedupe_publications = true)` / `get_publications_context` to avoid avoidable fan-out and duplicate abstracts. Entity phenotypes are compacted as modifier-keyed HPO ID arrays, and batch payloads should keep `schema_version` only at the outer envelope.
 
 MCP tools and prompts are strictly read-only and limited to approved public data. They must not write to the DB, call write routes, execute raw SQL/R, call Gemini/LLM generation, call live external providers, or expose draft reviews, re-review workflows, admin/user/log/job data, curation comments, or broad export payloads. Enforce approved public data in repository queries: active records from `ndd_entity_view`, and review-derived synopsis/phenotype/variation/publication data only from primary approved reviews (`is_primary = 1` and `review_approved = 1`).
 
 ### Migrations
 
 `db/migrations/*.sql` are applied at API startup by the migration runner using MySQL advisory locks. Migration failures are supposed to crash startup. Do not work around a failing migration by weakening startup checks.
 
 Startup validates the migration manifest before the fast path. In non-test startup the directory must exist, contain SQL files, have `EXPECTED_LATEST_MIGRATION` as the actual sorted latest migration, and meet the expected minimum file count. Missing, empty, or stale mounts are fatal and should be fixed at packaging/deployment time.
 
 ### Container mount boundary
 
 In the dev/prod containers, source directories such as `api/functions`, `api/services`, `api/endpoints`, and `db/migrations` are bind-mounted live. `api/tests/` is not bind-mounted. To run tests inside the running API container, copy them in or rebuild.
 
 The API image must not bake real `api/config.yml` into image layers. Provide runtime configuration through the Compose read-only mount, an operator secret, or an equivalent deployment-specific config injection mechanism; do not re-add `COPY config.yml config.yml` to `api/Dockerfile`.
 
 ### Disease cross-ontology mappings
diff --git a/CHANGELOG.md b/CHANGELOG.md
index 48651d8b..d3058047 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -1,88 +1,135 @@
 # Changelog
 
 All notable changes to SysNDD are documented in this file.
 
 The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (loosely, in the `0.x` line — additive changes land as patch bumps while the public API still stabilises).
 
 ## [Unreleased]
 
+## [0.30.1] — 2026-07-19
+
+Category-selected gene universes for functional clustering (#574). The public
+clustering submit endpoint can now resolve its gene universe from a curated
+SysNDD confidence category instead of an explicit gene list, with an auditable
+provenance record on every job.
+
+### Added
+
+- **`category_filter` on `POST /api/jobs/clustering/submit`**: an optional JSON
+  body array (e.g. `["Definitive"]`) selecting the clustering gene universe
+  from curated confidence categories. Resolution is **entity-level** against
+  `ndd_entity_view` — a gene qualifies if it has ≥1 `ndd_phenotype = 1` entity
+  whose status `category` is in the selector — via the new
+  `clustering_resolve_category_universe()`
+  (`api/functions/clustering-gene-universe.R`). Omitting the selector keeps the
+  byte-identical pre-#574 default (all NDD genes via `generate_ndd_hgnc_ids()`,
+  cache parity preserved); supplying both `genes` and `category_filter` is a
+  400.
+- **Provenance on every clustering job**: each submit records a `selector`
+  (`kind`: `explicit` / `category` / `all_ndd`), `resolved_gene_count`,
+  a sort-order-independent `gene_list_sha256`, an **intended** analysis
+  fingerprint (STRING cache fingerprint + score threshold + algorithm + seed),
+  and a cached, fail-closed `source_data_version` in the durable payload; the
+  result `meta` additionally carries an **effective** `effective_fingerprint`
+  (the STRING `weight_channel` the computed result actually used), on both the
+  cache-hit response and a worker-run job, so a silent exp+db→combined-score
+  fallback is observable either way.
+
+### Changed
+
+- Clustering-job **dedup identity is now selector-aware**: the normalized
+  `category_filter` enters the durable payload and preflight dedup key **only**
+  for category selectors, so `["Definitive"]` and `["Definitive","Moderate"]`
+  that happen to resolve to the same current genes are not collapsed, while
+  explicit-`genes` and no-arg submits keep a byte-identical `request_hash` and
+  payload shape to pre-#574. Category-filtered results remain ephemeral job
+  results and are **never** `public_ready`.
+
+### Validated
+
+- The selector is validated live against
+  `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded
+  category strings, no interpolated SQL): an unknown/inactive category, a
+  supplied-but-empty selector, or a resolved universe under 2 genes is a 400
+  naming the allowed active categories in the error message.
+
 ## [0.30.0] — 2026-07-18
 
 Immutable public analysis-snapshot releases (#573, Slice A). SysNDD's derived
 cluster analyses (functional STRING/Leiden clusters, phenotype MCA/HCPC
 clusters, and the phenotype-functional cross-cluster correlation) can now be
 frozen into content-addressed, independently-verifiable releases — the same
 "immutable dataset release" pattern already used for NDDScore/Zenodo, applied
 to the analysis layer.
 
 ### Added
 
 - **Content-addressed release identity**: `content_digest` is a SHA-256 over
   the invariant scientific content only (each pinned layer's `input_hash` /
   `payload_hash` / `reproducibility_hash` plus the shared source-data
   version) and deliberately **excludes** `created_at`, `title`, and DOI, so
   release identity is a pure function of the underlying data. The public
   handle is `release_id = "asr_" + content_digest[:16]`; the full 64-char
   digest is stored and collision-checked on insert.
 - **Public retrieval-only routes** (DB-only, unauthenticated) under
   `/api/analysis`: `GET /releases` (published, newest first), `GET
   /releases/latest`, `GET /releases/<release_id>`, `GET
   /releases/<release_id>/manifest.json` (the exact stored manifest bytes),
   `GET /releases/<release_id>/file?path=<file_path>` (an exact
   `(release_id, file_path)` lookup — no filesystem access, no path
   traversal), and `GET /releases/<release_id>/bundle` (streams the frozen
   `bundle.tar.gz` verbatim). A draft release is indistinguishable from an
   unknown release id on every public route (plain 404).
 - **Admin build/publish/DOI routes** (Administrator) under
   `/api/admin/analysis`: `POST /releases` builds (and, by default,
   publishes) a release from the currently active public-ready snapshots —
   201 for a genuinely new release, 200 for an idempotent rebuild of
   identical content, 400 naming the failing layer/reason otherwise; `GET
   /releases` (including drafts), `GET /releases/<id>`, `POST
   /releases/<id>/publish`, `PATCH /releases/<id>/doi` (additive Zenodo/DOI
   provenance, outside the content hash), and `DELETE /releases/<id>`
   (draft-only — a published release can never be deleted).
 - **Fail-closed build gate**: a release is only ever minted from sources that
   are available, pass a hard partition-coherence re-check (ignoring any
   local coherence-gate downgrade), carry a stored reproducibility bundle,
   share one source-data version, and — for the correlation layer — pin the
   exact dependency lineage (`snapshot_id` + `payload_hash`) of both cluster
   axes. A TOCTOU advisory lock plus a fresh pre-insert re-read close the race
   between reading sources and persisting the release.
 - **Verifiable checksums and lineage**: every file carries its own
   `content_sha256`; `sha256(reproducibility.json) == reproducibility_hash`
   exactly (raw bundle bytes, not a re-serialized parse); and
   `payload_hash`/`input_hash`/`snapshot_id` are recorded as cross-checkable
   lineage anchors against the live `meta.snapshot` on the corresponding
   public analysis endpoint — not equal to a hash of the release's own
   `payload.json` file, since the payload round-trips through DB column
   types before storage.
 - **Immutability and retention**: published releases are never auto-pruned;
   a later snapshot refresh mints a new release with a new
   `content_digest`/`release_id` while every prior release stays
   byte-identical (each holds its own frozen, self-contained copy). The
   snapshot prune guard now skips any `snapshot_id` still referenced by a
   release member, so a pinned snapshot's live reproducibility endpoint keeps
   working too.
 - Migration `045_add_analysis_snapshot_release.sql` adds the three backing
   tables (`analysis_snapshot_release`, `_member`, `_file`).
 
 ## [0.29.12] — 2026-07-18
 
 Routine dependency maintenance — consolidates six Dependabot updates into a
 single, fully-tested patch release. No runtime behaviour changes. All frontend
 CI gates (ESLint, `type-check`, `type-check:strict`, Vitest, production build +
 public-route bundle budget, SEO prerender) were verified green against the
 combined dependency tree before release.
 
 ### Changed
 
 - Frontend production dependencies (production-minor-patch group, #565):
   `@unhead/vue` 3.1.7 → 3.1.8, `bootstrap-vue-next` 0.45.7 → 0.45.8,
   `dompurify` 3.4.11 → 3.4.12, `vue-chartjs` 5.3.3 → 5.3.4.
 - Frontend dev dependencies (dev-dependencies group, #566): `@types/node`
   26.1.0 → 26.1.1, `eslint` 10.6.0 → 10.7.0, `msw` 2.14.6 → 2.15.0, `postcss`
   8.5.16 → 8.5.19, `prettier` 3.9.4 → 3.9.5, `typescript-eslint` 8.62.1 →
   8.63.0, `vue-tsc` 3.3.6 → 3.3.7.
 - CI: `actions/setup-node` 6 → 7 (#570).
 - Dev/Playwright mail sink: `axllent/mailpit` v1.30.3 → v1.30.4 (#568).
diff --git a/api/bootstrap/load_modules.R b/api/bootstrap/load_modules.R
index 512a3065..09f44069 100644
--- a/api/bootstrap/load_modules.R
+++ b/api/bootstrap/load_modules.R
@@ -57,160 +57,166 @@ bootstrap_load_modules <- function() {
   function_files <- c(
     "functions/config-functions.R",
     "functions/logging-functions.R",
     "functions/db-helpers.R",
     "functions/db-version.R",
     "functions/metadata-refresh.R",
     "functions/ontology-status-service.R",
     "functions/async-job-repository.R",
     "functions/async-job-db-config.R",
     "functions/async-job-payload-scrub.R",
     "functions/async-job-service.R",
     "functions/per-caller-throttle.R",
     "functions/clustering-submit-throttle.R",
     "functions/auth-endpoint-throttle.R",
     "functions/analysis-snapshot-presets.R",
     "functions/analysis-snapshot-repository.R",
     "functions/analysis-snapshot-prune-helpers.R",
     "functions/analysis-snapshot-coherence.R",
     "functions/analysis-snapshot-dependencies.R",
     "functions/analysis-snapshot-builder.R",
     "functions/analysis-reproducibility.R",
     # Immutable, content-addressed public analysis-snapshot releases (#573
     # Slice A). Synchronous admin/API-only build path (svc_release_build(),
     # called directly from the admin endpoint) -- NOT a durable async-job
     # handler and NOT a mirai daemon job, so (unlike the sibling
     # analysis-snapshot-*.R files above) these are intentionally absent from
     # bootstrap/setup_workers.R's mirai everywhere() block. Registered here
     # only, which still covers the durable worker (start_async_worker.R) and
     # the MCP sidecar (start_sysndd_mcp.R) via this shared loader. Order:
     # manifest (content digest / canonical JSON / tar.gz) -> repository (DB
     # CRUD) -> materialize (coherence assertions + file/README building) ->
     # release (orchestrator, depends on all three).
     "functions/analysis-snapshot-release-manifest.R",
     "functions/analysis-snapshot-release-repository.R",
     "functions/analysis-snapshot-release-materialize.R",
     "functions/analysis-snapshot-release.R",
     "functions/async-job-analysis-snapshot-handlers.R",
     "functions/async-job-network-layout-handlers.R",
     "functions/nddscore-import.R",
     "functions/nddscore-repository.R",
     "functions/nddscore-admin-endpoint-helpers.R",
     "functions/entity-repository.R",
     "functions/review-repository.R",
     "functions/status-repository.R",
     "functions/re-review-sync.R",
     "functions/publication-repository.R",
     "functions/phenotype-repository.R",
     "functions/ontology-repository.R",
     "functions/mcp-search-repository.R",
     "functions/mcp-repository.R",
     "functions/mcp-analysis-cache-repository.R",
     "functions/mcp-analysis-repository.R",
     "functions/user-repository.R",
     "functions/user-endpoint-helpers.R",
     "functions/hash-repository.R",
     "functions/metadata-vocabulary-repository.R",
     "functions/category-normalization.R",
     "functions/phenotype-endpoint-functions.R",
     "functions/panels-endpoint-functions.R",
     "functions/endpoint-functions.R",
     "functions/comparisons-list.R",
     # Comparisons refresh write-path (durable `comparisons_update` job). These
     # were historically only loaded into the mirai daemon pool via
     # setup_workers.R, but create_job() now submits comparisons_update as a
     # durable System B job, so the async worker (which loads via this list) must
     # define comparisons_update_async() and its helpers too. Order: sources +
     # parsers + omim before comparisons-functions.R (which uses them).
     "functions/omim-functions.R",
     "functions/comparisons-sources.R",
     "functions/comparisons-parsers.R",
     "functions/comparisons-omim.R",
     "functions/comparisons-functions.R",
     "functions/publication-endpoint-helpers.R",
     "functions/pubmed-xml-parser.R",
     "functions/publication-functions.R",
     "functions/publication-date-backfill.R",
     "functions/genereviews-functions.R",
     "functions/analysis-string-channels.R",
     "functions/analysis-cache-fingerprint.R",
     "functions/analyses-functions.R",
+    # Category-selected clustering gene-universe resolver (#574). Depends on
+    # generate_ndd_hgnc_ids() (analyses-functions.R, above) and
+    # stop_for_bad_request() (core/errors.R, sourced after function_files by
+    # this same bootstrap_load_modules() call) -- registered before the
+    # submission service that will consume it.
+    "functions/clustering-gene-universe.R",
     "functions/analysis-phenotype-mca-prep.R",
     "functions/analysis-phenotype-functions.R",
     "functions/analysis-null-models.R",
     "functions/analysis-cluster-validation.R",
     "functions/analysis-network-layout-functions.R",
     "functions/analysis-network-functions.R",
     "functions/account-helpers.R",
     "functions/data-helpers.R",
     "functions/entity-helpers.R",
     "functions/response-helpers.R",
     "functions/response-fields-helpers.R",
     "functions/email-templates.R",
     "functions/pagination-helpers.R",
     "functions/external-proxy-functions.R",
     "functions/external-proxy-gnomad.R",
     "functions/external-proxy-gnomad-batch.R",
     "functions/external-proxy-uniprot.R",
     "functions/external-proxy-ensembl.R",
     "functions/external-proxy-alphafold.R",
     "functions/external-proxy-mgi.R",
     "functions/external-proxy-rgd.R",
     "functions/genereviews-lookup.R",
     "functions/file-functions.R",
     "functions/hpo-functions.R",
     "functions/hgnc-functions.R",
     "functions/hgnc-enrichment-gnomad.R",
     "functions/llm-summary-config.R",
     "functions/llm-cache-repository.R",
     "functions/llm-cache-admin-repository.R",
     "functions/llm-validation.R",
     "functions/llm-model-config.R",
     "functions/llm-client.R",
     "functions/llm-rate-limiter.R",
     "functions/llm-types.R",
     "functions/llm-prompt-template-repository.R",
     "functions/llm-service.R",
     "functions/llm-judge-prompts.R",
     "functions/llm-judge.R",
     "functions/llm-batch-cluster-data.R",
     "functions/llm-batch-generator.R",
     "functions/llm-regenerate-helpers.R",
     "functions/mondo-index-builder.R",
     "functions/disease-ontology-mapping-builder.R",
     "functions/disease-ontology-mapping-repository.R",
     "functions/disease-ontology-mapping-refresh.R",
     "functions/ontology-functions.R",
     "functions/ontology-object.R",
     "functions/pubtator-client.R",
     "functions/pubtator-parser.R",
     "functions/pubtator-functions.R",
     "functions/pubtator-enrichment-metrics.R",
     "functions/pubtator-enrichment-collector.R",
     "functions/pubtator-gene-summary.R",
     "functions/pubtatornidd-nightly.R",
     "functions/ensembl-functions.R",
     "functions/job-manager.R",
     "functions/job-progress.R",
     "functions/backup-functions.R",
     "functions/ols-functions.R",
     "functions/openapi-helpers.R",
     "functions/migration-manifest.R",
     "functions/migration-runner.R"
   )
   # --- end source list ---
 
   core_files <- c(
     "core/security.R",
     "core/errors.R",
     "core/responses.R",
     "core/logging_sanitizer.R",
     "core/middleware.R",
     "core/filters.R"
   )
 
   service_files <- c(
     "services/auth-service.R",
     "services/user-service.R",
     "services/status-service.R",
     "services/metadata-vocabulary-service.R",
     "services/search-service.R",
diff --git a/api/endpoints/jobs_endpoints.R b/api/endpoints/jobs_endpoints.R
index 4ffad4c5..b4ef4f08 100644
--- a/api/endpoints/jobs_endpoints.R
+++ b/api/endpoints/jobs_endpoints.R
@@ -1,111 +1,144 @@
 # api/endpoints/jobs_endpoints.R
 #
 # Async job submission and status polling endpoints.
 # Submits durable worker jobs and returns HTTP 202 Accepted for long-running operations.
 #
 # Endpoints:
 #   POST /api/jobs/clustering/submit - Submit functional clustering job
 #   POST /api/jobs/phenotype_clustering/submit - Submit phenotype clustering job
 #   GET /api/jobs/<job_id>/status - Poll job status and retrieve results
 #
 # Dependencies:
 #   - pool (global database connection pool)
 #   - create_job, get_job_status, check_duplicate_job (from job-manager.R)
 #   - durable handlers registered in functions/async-job-handlers.R
 #
 # Handler bodies were extracted to services/job-*-service.R (issue #346, Wave
 # 3, Task 5) to keep this file a thin route table. Each shell below keeps its
 # original decorators, formals, and role gate, and delegates the rest to the
 # matching svc_ function.
 
 ## -------------------------------------------------------------------##
 ## Job Submission Endpoints
 ## -------------------------------------------------------------------##
 
 #* Submit Functional Clustering Job
 #*
-#* Submits an async job to compute functional clustering via STRING-db.
+#* Submits an async job to compute functional clustering via STRING-db. The
+#* clustering gene universe (#574) is resolved from one of three mutually
+#* exclusive JSON body selectors:
+#*   - `genes`: an explicit array of HGNC ids to cluster.
+#*   - `category_filter`: an array of curated SysNDD confidence categories
+#*     (e.g. `["Definitive"]`); resolved entity-level (>=1 NDD entity in a
+#*     selected category, `ndd_phenotype = 1`) against the live
+#*     `ndd_entity_view`, validated against the live active
+#*     `ndd_entity_status_categories_list`. A category run rejects with 400
+#*     when `category_filter` is empty, contains an unknown/inactive value
+#*     (the allowed active set is named in the error), or resolves fewer
+#*     than 2 genes.
+#*   - neither: the existing default all-NDD-genes universe.
+#* Supplying both `genes` and a non-empty `category_filter` is a 400.
+#*
+#* Every submit records selector/fingerprint provenance -- `selector`
+#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
+#* category runs), `resolved_gene_count`, `gene_list_sha256`,
+#* `intended_fingerprint`, and `source_data_version` -- in the durable job
+#* payload; the job result `meta` additionally carries `effective_fingerprint`
+#* (the STRING `weight_channel` actually observed on the computed result),
+#* recorded on both a cache-hit (immediate) response and a worker-run
+#* (cache-miss) job.
+#*
+#* Results from this endpoint (including category-filtered runs) are never
+#* `public_ready` -- they are ephemeral job results, distinct from the public
+#* `analysis_snapshot_*` layer.
+#*
 #* Returns immediately with job ID for status polling.
 #*
 #* @tag jobs
 #* @serializer json list(na="string")
+#* @param genes Optional JSON array of explicit HGNC ids. Mutually exclusive
+#*   with `category_filter`.
+#* @param category_filter Optional JSON array of curated SysNDD confidence
+#*   categories (e.g. `["Definitive"]`). Mutually exclusive with `genes`.
+#* @param algorithm Optional clustering algorithm string, `"leiden"`
+#*   (default) or `"walktrap"`.
 #* @post /clustering/submit
 function(req, res) {
   svc_job_submit_functional_clustering(req, res)
 }
 
 ## -------------------------------------------------------------------##
 ## Phenotype Clustering Submission
 ## -------------------------------------------------------------------##
 
 #* Submit Phenotype Clustering Job
 #*
 #* Submits an async job to compute phenotype clustering via MCA.
 #* Returns immediately with job ID for status polling.
 #*
 #* @tag jobs
 #* @serializer json list(na="string")
 #* @post /phenotype_clustering/submit
 function(req, res) {
   svc_job_submit_phenotype_clustering(req, res)
 }
 
 ## -------------------------------------------------------------------##
 ## Ontology Update Submission
 ## -------------------------------------------------------------------##
 
 #* Submit Ontology Update Job
 #*
 #* Submits an async job to update disease ontology data from MONDO and OMIM sources.
 #* Requires Administrator role.
 #* Returns immediately with job ID for status polling.
 #*
 #* @tag jobs
 #* @serializer json list(na="string")
 #* @post /ontology_update/submit
 function(req, res) {
   require_role(req, res, "Administrator")
   svc_job_submit_ontology_update(res)
 }
 
 ## -------------------------------------------------------------------##
 ## HGNC Data Update Submission
 ## -------------------------------------------------------------------##
 
 #* Submit HGNC Data Update Job
 #*
 #* Submits an async job to download and update HGNC gene data.
 #* Requires Administrator role.
 #* Returns immediately with job ID for status polling.
 #*
 #* @tag jobs
 #* @serializer json list(na="string")
 #* @post /hgnc_update/submit
 function(req, res) {
   require_role(req, res, "Administrator")
   svc_job_submit_hgnc_update(res)
 }
 
 ## -------------------------------------------------------------------##
 ## Comparisons Data Update Submission
 ## -------------------------------------------------------------------##
 
 #* Submit Comparisons Data Update Job
 #*
 #* Submits an async job to refresh the comparisons data from all external
 #* NDD databases (Radboud, Gene2Phenotype, PanelApp, SFARI, Geisinger,
 #* OMIM NDD, Orphanet).
 #*
 #* Requires Administrator role.
 #* Returns immediately with job ID for status polling.
 #*
 #* @tag jobs
 #* @serializer json list(na="string")
 #* @post /comparisons_update/submit
 function(req, res) {
   require_role(req, res, "Administrator")
   svc_job_submit_comparisons_update(res)
 }
 
 ## -------------------------------------------------------------------##
 ## Job History
diff --git a/api/functions/async-job-handlers.R b/api/functions/async-job-handlers.R
index d3691475..184b62c0 100644
--- a/api/functions/async-job-handlers.R
+++ b/api/functions/async-job-handlers.R
@@ -1,198 +1,229 @@
 # api/functions/async-job-handlers.R
 #
 # Durable async job handler shell (#346 Wave 4 split): common
 # payload/progress/clustering helpers, the legacy-executor passthrough
 # factory, the `async_job_handler_registry` list, and the
 # `async_job_get_handler()` lookup.
 #
 # Family-specific handler definitions live in sibling files sourced BEFORE
 # this one at every worker entrypoint, because the registry list below
 # references handler functions by bare symbol and R evaluates a list()
 # literal's elements eagerly at construction time:
 #   - functions/async-job-network-layout-handlers.R (network_layout_prewarm)
 #   - functions/async-job-analysis-snapshot-handlers.R (analysis_snapshot_refresh)
 #   - functions/async-job-omim-apply.R (OMIM DB-write / additive-terms helpers)
 #   - functions/async-job-force-apply-payload.R (force-apply payload-shape helpers)
 #   - functions/async-job-provider-handlers.R (HGNC, PubTator, NDDScore,
 #     disease-ontology mapping, OMIM update, force-apply-ontology)
 #   - functions/async-job-maintenance-handlers.R (backup create/restore,
 #     publication refresh/backfill)
 # Restart the worker container after changing any of these (worker-executed
 # code is sourced once at startup).
+# NOTE: .async_job_run_clustering assembles its result meta via
+# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
+# worker/API entrypoint sources that module via bootstrap_load_modules() before
+# this file; a direct-source test env must source it too (as the async-job tests do).
 
 .async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
   invisible(result)
 }
 .async_job_or <- function(value, fallback) {
   if (is.null(value) || length(value) == 0) {
     return(fallback)
   }
 
   value
 }
 .async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
   if (!exists("create_async_job_progress_reporter", mode = "function")) {
     stop("create_async_job_progress_reporter() is required for durable async job handlers", call. = FALSE)
   }
 
   create_async_job_progress_reporter(job_id, throttle_seconds = throttle_seconds)
 }
 .async_job_payload_field <- function(payload, field, required = TRUE, default = NULL) {
   value <- payload[[field]]
 
   if (is.null(value)) {
     if (isTRUE(required)) {
       stop(sprintf("Async job payload is missing required field '%s'", field), call. = FALSE)
     }
 
     return(default)
   }
 
   value
 }
 .async_job_payload_scalar <- function(payload, field, required = TRUE, default = NULL) {
   value <- .async_job_payload_field(payload, field, required = required, default = default)
 
   if (is.null(value)) {
     return(value)
   }
 
   if (is.list(value)) {
     value <- value[[1]]
   }
 
   value[[1]]
 }
 
 .async_job_add_job_id <- function(payload, job) {
   payload$.__job_id__ <- job$job_id[[1]]
   payload
 }
 
 .async_job_functional_categories <- function(clusters, category_links) {
   categories <- clusters |>
     dplyr::select(term_enrichment) |>
     tidyr::unnest(cols = c(term_enrichment)) |>
     dplyr::select(category) |>
     unique() |>
     dplyr::arrange(category) |>
     dplyr::mutate(
       text = dplyr::case_when(
         nchar(category) <= 5 ~ category,
         nchar(category) > 5 ~ stringr::str_to_sentence(category)
       )
     ) |>
     dplyr::select(value = category, text)
 
   if (!is.null(category_links)) {
     categories <- dplyr::left_join(categories, category_links, by = c("value"))
   }
 
   categories
 }
 
 .async_job_run_clustering <- function(job, payload, state, worker_config) {
   genes <- .async_job_payload_field(payload, "genes")
   algorithm <- .async_job_payload_scalar(payload, "algorithm")
   string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
   category_links <- .async_job_payload_field(payload, "category_links", required = FALSE)
+  # #574 D3: the cheap-path selector/fingerprint provenance the submit
+  # service (job-functional-submission-service.R) recorded in the payload.
+  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
+  # FALSE) so a worker-run job for those still completes normally.
+  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
   progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
 
   progress("cluster", "Running functional clustering...", current = 0, total = 1)
 
   clusters <- gen_string_clust_obj(
     genes,
     algorithm = algorithm,
     string_id_table = string_id_table
   )
 
   progress("complete", "Functional clustering complete", current = 1, total = 1)
 
+  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
+  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
+  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
+  # path), then the request's cheap-path `provenance` (selector/
+  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
+  # source_data_version) when present, then the `effective_fingerprint` --
+  # only knowable now that `clusters` has actually been computed -- so a
+  # silent exp+db -> combined-score STRING fallback on a worker-run job is
+  # visible in the stored result too, not just a cache hit's.
+  # gene_count is the DISTINCT gene count, matching the cache-hit path's
+  # `resolved_count <- length(unique(genes_list))` (job-functional-submission-
+  # service.R) -- for `["HGNC:1","HGNC:1"]` a raw `length(genes)` reported 2
+  # here while the cache-hit path reported 1 for the identical payload
+  # (Codex round-2 review fix). This never dedups the payload `genes` list
+  # itself or changes `nrow(clusters)`, only the reported count.
+  meta <- clustering_result_meta(
+    list(
+      algorithm = algorithm,
+      gene_count = length(unique(genes)),
+      cluster_count = nrow(clusters),
+      cache_hit = FALSE
+    ),
+    provenance,
+    attr(clusters, "weight_channel")
+  )
+
   list(
     clusters = clusters,
     categories = .async_job_functional_categories(clusters, category_links),
-    meta = list(
-      algorithm = algorithm,
-      gene_count = length(genes),
-      cluster_count = nrow(clusters)
-    )
+    meta = meta
   )
 }
 
 .async_job_chain_llm <- function(result, job, cluster_type) {
   if (!exists("trigger_llm_batch_generation", mode = "function")) {
     return(invisible(result))
   }
 
   llm_clusters <- result
 
   if (is.list(result) && "clusters" %in% names(result) && !is.null(result[["clusters"]])) {
     llm_clusters <- result[["clusters"]]
   }
 
   trigger_llm_batch_generation(
     clusters = llm_clusters,
     cluster_type = cluster_type,
     parent_job_id = job$job_id[[1]]
   )
 
   invisible(result)
 }
 
 .async_job_phenotype_matrix <- function(payload) {
   sysndd_db_phenotypes <- payload$ndd_entity_view_tbl |>
     dplyr::left_join(payload$ndd_review_phenotype_connect_tbl, by = "entity_id") |>
     dplyr::left_join(payload$modifier_list_tbl, by = "modifier_id") |>
     dplyr::left_join(payload$phenotype_list_tbl, by = "phenotype_id") |>
     dplyr::mutate(ndd_phenotype = dplyr::case_when(
       ndd_phenotype == 1 ~ "Yes",
       ndd_phenotype == 0 ~ "No",
       TRUE ~ ndd_phenotype
     )) |>
     dplyr::filter(ndd_phenotype == "Yes") |>
     dplyr::filter(category %in% payload$categories) |>
     dplyr::filter(modifier_name == "present") |>
     dplyr::filter(review_id %in% payload$ndd_entity_review_tbl$review_id) |>
     dplyr::select(
       entity_id, hpo_mode_of_inheritance_term_name, phenotype_id,
       HPO_term, hgnc_id
     ) |>
     dplyr::group_by(entity_id) |>
     dplyr::mutate(
       phenotype_non_id_count = sum(!(phenotype_id %in% payload$id_phenotype_ids)),
       phenotype_id_count = sum(phenotype_id %in% payload$id_phenotype_ids)
     ) |>
     dplyr::ungroup() |>
     unique()
 
   sysndd_db_phenotypes_wider <- sysndd_db_phenotypes |>
     dplyr::mutate(present = "yes") |>
     dplyr::select(-phenotype_id) |>
     tidyr::pivot_wider(names_from = HPO_term, values_from = present) |>
     dplyr::group_by(hgnc_id) |>
     dplyr::mutate(gene_entity_count = dplyr::n()) |>
     dplyr::ungroup() |>
     dplyr::relocate(gene_entity_count, .after = phenotype_id_count) |>
     dplyr::select(-hgnc_id)
 
   phenotype_df <- sysndd_db_phenotypes_wider |>
     dplyr::select(-entity_id) |>
     as.data.frame()
   row.names(phenotype_df) <- sysndd_db_phenotypes_wider$entity_id
 
   # #508 MCA feature hygiene via the shared helper (same as
   # generate_phenotype_cluster_input) so the interactive/durable clustering job
   # produces the cleaned partition and can't diverge from the public snapshot.
   phenotype_df <- phenotype_mca_prep_matrix(
     phenotype_df,
     hpo_lookup = dplyr::select(payload$phenotype_list_tbl, HPO_term, phenotype_id)
   )
 
   phenotype_df
 }
 
 .async_job_run_phenotype_clustering <- function(job, payload, state, worker_config) {
   progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
 
   progress("prepare_matrix", "Preparing phenotype matrix...", current = 0, total = 2)
   phenotype_matrix <- .async_job_phenotype_matrix(payload)
diff --git a/api/functions/async-job-service.R b/api/functions/async-job-service.R
index 37b6ec99..f3d655dc 100644
--- a/api/functions/async-job-service.R
+++ b/api/functions/async-job-service.R
@@ -137,267 +137,283 @@ async_job_priority_for_type <- function(job_type) {
 .async_job_service_abort <- function(message, class = "async_job_service_validation_error", ...) {
   rlang::abort(message = message, class = class, ...)
 }
 
 .async_job_service_non_empty_string <- function(value, field) {
   scalar <- .async_job_service_scalar(value, NULL)
 
   if (is.null(scalar)) {
     .async_job_service_abort(sprintf("%s is required", field))
   }
 
   scalar <- as.character(scalar)
   if (!nzchar(trimws(scalar))) {
     .async_job_service_abort(sprintf("%s is required", field))
   }
 
   scalar
 }
 
 async_job_service_payload_json <- function(request_payload) {
   if (is.character(request_payload) && length(request_payload) == 1L) {
     return(request_payload[[1]])
   }
 
   as.character(
     jsonlite::toJSON(
       request_payload,
       auto_unbox = TRUE,
       null = "null",
       dataframe = "rows",
       POSIXt = "ISO8601"
     )
   )
 }
 
 async_job_service_request_hash <- function(job_type, request_payload_json) {
   digest::digest(
     paste0(
       .async_job_service_non_empty_string(job_type, "job_type"),
       ":",
       as.character(.async_job_service_scalar(request_payload_json, ""))
     ),
     algo = "sha256",
     serialize = FALSE
   )
 }
 
 .async_job_service_duplicate_row <- function(error, conn = NULL) {
   duplicate_job <- error$duplicate_job
   if (is.null(duplicate_job)) {
     duplicate_job <- tibble::tibble()
   }
 
   if (nrow(duplicate_job) > 0) {
     return(duplicate_job)
   }
 
   job_id <- error$job_id
   if (is.null(job_id)) {
     return(tibble::tibble())
   }
 
   async_job_repository_get(job_id, conn = conn)
 }
 
 #' Submit a durable async job and return its stored row
 #'
 #' @param job_type Character durable job type.
 #' @param request_payload Named list or JSON payload string.
 #' @param submitted_by Optional user id.
 #' @param queue_name Character queue name. `NULL` (default) routes by job type via
 #'   `async_job_queue_for_type()` (maintenance lane for heavy jobs, else default);
 #'   an explicit value is honored as-is.
 #' @param priority Integer queue priority. `NULL` (default) resolves by job type
 #'   via `async_job_priority_for_type()` (interactive < maintenance < default); an
 #'   explicit value is honored as-is.
 #' @param max_attempts Integer maximum attempts.
 #' @param scheduled_at Optional schedule time.
 #' @param job_id Optional explicit job id for tests.
 #' @param conn Optional DB connection or pool.
+#' @param hash_payload Optional named list or JSON payload string. When
+#'   supplied, the dedup `request_hash` is computed over THIS payload instead
+#'   of `request_payload`, while `request_payload_json` (the durably stored
+#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
+#'   `request_payload` exactly as before, so existing callers are unaffected.
+#'   Used by clustering submits (#574) to exclude time-varying `provenance`
+#'   metadata from the dedup identity while still persisting it.
 #'
 #' @return List containing the stored job row and duplicate/create flags.
 #' @export
 async_job_service_submit <- function(
   job_type,
   request_payload,
   submitted_by = NULL,
   queue_name = NULL,
   priority = NULL,
   max_attempts = 1L,
   scheduled_at = Sys.time(),
   job_id = uuid::UUIDgenerate(),
-  conn = NULL
+  conn = NULL,
+  hash_payload = NULL
 ) {
   job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   # Default the lane + priority from the job type so heavy maintenance jobs never
   # head-of-line block interactive jobs (#486). Explicit overrides are honored.
   if (is.null(queue_name)) {
     queue_name <- async_job_queue_for_type(job_type)
   }
   if (is.null(priority)) {
     priority <- async_job_priority_for_type(job_type)
   }
   queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   payload_json <- async_job_service_payload_json(request_payload)
-  request_hash <- async_job_service_request_hash(job_type, payload_json)
+  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
+  request_hash <- async_job_service_request_hash(job_type, hash_payload_json)
   submitted_at <- Sys.time()
 
   stored_job <- tryCatch(
     {
       async_job_repository_create(
         list(
           job_id = job_id,
           job_type = job_type,
           queue_name = queue_name,
           priority = as.integer(priority),
           request_hash = request_hash,
           request_payload_json = payload_json,
           submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
           submitted_at = submitted_at,
           scheduled_at = scheduled_at,
           max_attempts = as.integer(max_attempts)
         ),
         conn = conn
       )
 
       async_job_repository_get(job_id, conn = conn)
     },
     async_job_duplicate_error = function(error) {
       .async_job_service_duplicate_row(error, conn = conn)
     }
   )
 
   is_duplicate <- nrow(stored_job) > 0 && !identical(stored_job$job_id[[1]], job_id)
 
   list(
     job = stored_job,
     duplicate = is_duplicate,
     created = !is_duplicate
   )
 }
 
 #' Persist an already-completed durable async job row
 #'
 #' Used for cache-hit fast paths that should still return a normal durable
 #' job id without enqueueing worker execution.
 #'
 #' @param job_type Character durable job type.
 #' @param request_payload Named list or JSON payload string.
 #' @param result Completed handler result payload.
 #' @param submitted_by Optional user id.
 #' @param queue_name Character queue name.
 #' @param priority Integer queue priority.
 #' @param job_id Optional explicit job id.
 #' @param submitted_at Optional submission timestamp.
 #' @param completed_at Optional completion timestamp.
 #' @param conn Optional DB connection or pool.
+#' @param hash_payload Optional named list or JSON payload string. When
+#'   supplied, the dedup `request_hash` is computed over THIS payload instead
+#'   of `request_payload`, while `request_payload_json` (the durably stored
+#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
+#'   `request_payload` exactly as before, so existing callers are unaffected.
 #'
 #' @return Tibble with the stored completed job row.
 #' @export
 async_job_service_store_completed <- function(
   job_type,
   request_payload,
   result,
   submitted_by = NULL,
   queue_name = "default",
   priority = 100L,
   job_id = uuid::UUIDgenerate(),
   submitted_at = Sys.time(),
   completed_at = submitted_at,
-  conn = NULL
+  conn = NULL,
+  hash_payload = NULL
 ) {
   job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   payload_json <- async_job_service_payload_json(request_payload)
+  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
   result_json <- async_job_service_payload_json(result)
 
   async_job_repository_create(
     list(
       job_id = job_id,
       job_type = job_type,
       queue_name = queue_name,
       priority = as.integer(priority),
       status = "completed",
-      request_hash = async_job_service_request_hash(job_type, payload_json),
+      request_hash = async_job_service_request_hash(job_type, hash_payload_json),
       request_payload_json = payload_json,
       submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
       submitted_at = submitted_at,
       scheduled_at = submitted_at,
       started_at = submitted_at,
       completed_at = completed_at,
       progress_pct = 100,
       result_json = result_json
     ),
     conn = conn
   )
 
   async_job_repository_get(job_id, include_result = TRUE, conn = conn)
 }
 
 #' Find an active duplicate for a durable async job request
 #'
 #' @param job_type Character durable job type.
 #' @param request_payload Named list or JSON payload string.
 #' @param conn Optional DB connection or pool.
 #'
 #' @return Tibble with zero or one active duplicate row.
 #' @export
 async_job_service_find_duplicate <- function(job_type, request_payload, conn = NULL) {
   job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   payload_json <- async_job_service_payload_json(request_payload)
 
   async_job_repository_find_active_duplicate(
     job_type = job_type,
     request_hash = async_job_service_request_hash(job_type, payload_json),
     conn = conn
   )
 }
 
 #' Read current durable async job status
 #'
 #' @param job_id Character job id.
 #' @param include_result Logical; include result_json when TRUE.
 #' @param conn Optional DB connection or pool.
 #'
 #' @return Tibble with zero or one durable job row.
 #' @export
 async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
   async_job_repository_get(
     job_id = .async_job_service_non_empty_string(job_id, "job_id"),
     include_result = isTRUE(include_result),
     conn = conn
   )
 }
 
 #' Return durable async job history
 #'
 #' @param limit Integer history limit.
 #' @param include_result Logical; include result_json in history rows.
 #' @param conn Optional DB connection or pool.
 #'
 #' @return Tibble of recent durable jobs.
 #' @export
 async_job_service_history <- function(limit = 20L, include_result = FALSE, conn = NULL) {
   args <- list(
     limit = max(1L, as.integer(.async_job_service_scalar(limit, 20L))),
     conn = conn
   )
   if (isTRUE(include_result)) {
     args$include_result <- TRUE
   }
   do.call(async_job_repository_history, args)
 }
 
 #' Request durable async job cancellation and return the refreshed row
 #'
 #' @param job_id Character job id.
 #' @param cancelled_by Optional user id.
 #' @param conn Optional DB connection or pool.
 #'
 #' @return Tibble with zero or one durable job row after cancellation.
 #' @export
 async_job_service_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
   job_id <- .async_job_service_non_empty_string(job_id, "job_id")
 
diff --git a/api/functions/clustering-gene-universe.R b/api/functions/clustering-gene-universe.R
new file mode 100644
index 00000000..a212d398
--- /dev/null
+++ b/api/functions/clustering-gene-universe.R
@@ -0,0 +1,165 @@
+# api/functions/clustering-gene-universe.R
+#
+# Category-selected clustering gene-universe resolver (#574 D1).
+#
+# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
+# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
+# universe from curated SysNDD confidence categories instead of the default
+# "all NDD genes" set. This file builds ONLY the resolver + provenance
+# helpers; the submit service and durable handler wiring is done later.
+#
+# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
+# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
+# same gene also has OTHER-category entities. This mirrors
+# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
+# added `category %in% selector` filter -- it deliberately does NOT use
+# `select_network_gene_category()`, which is a gene-level display-label
+# aggregator for node coloring, not a universe filter.
+#
+# Category validation is live against `ndd_entity_status_categories_list
+# WHERE is_active = 1` -- no hardcoded category strings, and no category
+# string is interpolated into SQL (dbplyr `%in%` + an allowlist pre-check).
+
+# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
+# selector returns character(0), which the resolver rejects with 400 -- it must
+# never fall through to the all-NDD default.
+clustering_normalize_category_filter <- function(category_filter) {
+  if (is.null(category_filter)) return(NULL)
+  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
+  vals <- vals[nzchar(vals)]
+  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
+  sort(unique(vals))
+}
+
+clustering_gene_list_sha256 <- function(hgnc_ids) {
+  digest::digest(
+    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
+    algo = "sha256", serialize = FALSE
+  )
+}
+
+clustering_resolve_category_universe <- function(category_filter, conn = pool) {
+  selector <- clustering_normalize_category_filter(category_filter)
+
+  if (is.null(selector)) {
+    # Absent -> preserve the exact current default ordering for cache parity.
+    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
+    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
+  }
+
+  # Any PRESENT selector (including supplied-but-empty) needs the allowed
+  # active-category set for its 400 message, so this fetch runs for every
+  # present-selector path -- not just the unknown-category branch below.
+  active <- conn %>%
+    dplyr::tbl("ndd_entity_status_categories_list") %>%
+    dplyr::filter(is_active == 1) %>%
+    dplyr::select(category) %>%
+    dplyr::collect() %>%
+    dplyr::pull(category)
+
+  if (length(selector) == 0L) {
+    stop_for_bad_request(sprintf(
+      "category_filter was supplied but empty; provide at least one active category. Allowed active categories: %s",
+      paste(sort(active), collapse = ", ")
+    ))
+  }
+
+  unknown <- setdiff(selector, active)
+  if (length(unknown) > 0L) {
+    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
+    stop_for_bad_request(sprintf(
+      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
+      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
+    ))
+  }
+
+  hgnc_ids <- conn %>%
+    dplyr::tbl("ndd_entity_view") %>%
+    dplyr::arrange(entity_id) %>%
+    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
+    dplyr::select(hgnc_id) %>%
+    dplyr::collect() %>%
+    unique() %>%
+    dplyr::pull(hgnc_id)
+
+  if (length(hgnc_ids) < 2L) {
+    stop_for_bad_request(sprintf(
+      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2. Allowed active categories: %s",
+      paste(selector, collapse = ","), length(hgnc_ids), paste(sort(active), collapse = ", ")
+    ))
+  }
+  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
+}
+
+# Module-level (survives across requests within the same process) cache for
+# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
+# public tables and changes rarely (only when the snapshot builder's source
+# view moves), so a short-TTL process cache avoids paying that cost on every
+# clustering submit while still self-refreshing.
+.clustering_source_data_version_cache <- new.env(parent = emptyenv())
+
+#' Predicate: is `v` a valid source-data-version value?
+#'
+#' The fail-closed contract requires a single non-NA, non-empty character
+#' scalar. Anything else (`NULL`, `NA_character_`, `""`, a non-character
+#' value, or a non-scalar) must never be cached or served as provenance
+#' (Codex review fix -- the TTL cache previously cached/returned an invalid
+#' underlying value verbatim).
+.clustering_valid_source_version <- function(v) {
+  is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
+}
+
+#' Cached, fail-closed read of the current analysis source-data version.
+#'
+#' D2 (#574) provenance helper: the clustering submit service calls this
+#' AFTER admission/dedup, only when it is actually about to build a durable
+#' payload. Refetches once `ttl_seconds` has elapsed since the last
+#' successful read. Deliberately does NOT wrap
+#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
+#' PROPAGATES to the caller (never cached, never coerced to NA), so a
+#' transient DB problem fails the submit closed (503) instead of recording
+#' broken provenance. The fetched value is additionally validated by
+#' `.clustering_valid_source_version()`: an invalid value (NA/empty/
+#' non-scalar) is likewise NEVER cached or returned -- it `stop()`s instead,
+#' so the caller's `tryCatch` maps it to the same 503 PROVENANCE_UNAVAILABLE
+#' path as a hard fetch error.
+#'
+#' @param conn DB connection/pool. Defaults to the package-global `pool`.
+#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
+#' @return character(1) source data version.
+#' @export
+clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
+  now <- Sys.time()
+  cached_at <- .clustering_source_data_version_cache$cached_at
+  cached_value <- .clustering_source_data_version_cache$value
+  if (!is.null(cached_at) && .clustering_valid_source_version(cached_value) &&
+        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
+    return(cached_value)
+  }
+
+  value <- analysis_snapshot_source_data_version(conn = conn)
+
+  if (!.clustering_valid_source_version(value)) {
+    stop(
+      "clustering_cached_source_data_version: analysis_snapshot_source_data_version() ",
+      "returned an invalid (NULL/NA/empty/non-scalar) value; refusing to cache or serve it"
+    )
+  }
+
+  .clustering_source_data_version_cache$value <- value
+  .clustering_source_data_version_cache$cached_at <- now
+  value
+}
+
+# Assemble the clustering result `meta`: base fields + the cheap-path provenance
+# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
+# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
+# observed post-compute. Shared by the cache-hit path
+# (job-functional-submission-service.R) and the worker-run/durable handler
+# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
+# shapes cannot drift apart by hand-copied edits.
+clustering_result_meta <- function(base, provenance, weight_channel) {
+  c(base,
+    if (!is.null(provenance)) provenance else list(),
+    list(effective_fingerprint = list(weight_channel = weight_channel)))
+}
diff --git a/api/services/job-functional-submission-service.R b/api/services/job-functional-submission-service.R
index 150c61e0..a4f259b7 100644
--- a/api/services/job-functional-submission-service.R
+++ b/api/services/job-functional-submission-service.R
@@ -1,240 +1,378 @@
 # api/services/job-functional-submission-service.R
 #
 # Body of `POST /api/jobs/clustering/submit`, extracted from
 # endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5). Public endpoint —
 # no role gate. The endpoint shell delegates the entire handler body here;
 # `svc_job_submit_functional_clustering()` mutates `res` (status + headers)
 # exactly as the inline handler used to, and returns the JSON payload.
 #
 # The durable handler receives serialized input, not a database connection, so
 # all values it needs are fetched from `pool` before `create_job()` is called.
 #
 # This is an ENDPOINT service: it is sourced by the shared bootstrap loader
 # (api/bootstrap/load_modules.R) like any other services/* file. The worker
 # executes the registered `clustering` durable handler, never this submitter.
 
 #' Submit a functional (STRING-db) clustering job.
 #'
 #' Cache-first: if the memoised `gen_string_clust_obj_mem()` already has a
 #' result for the resolved gene list + algorithm, the result is persisted as
 #' an already-completed durable job via `async_job_service_store_completed()`
 #' so the response shape matches a freshly-submitted job (this keeps LLM batch
 #' generation on the same job/result hashes as the API-served table). A cache
 #' miss falls through the public queue-depth capacity guard
 #' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
 #' new durable job via `create_job()`.
 #'
-#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm` and
-#'   `req$user$user_id`).
+#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
+#' curated-category selection via `category_filter` (resolved through
+#' `clustering_resolve_category_universe()`), or -- when neither is supplied
+#' -- the existing default all-NDD-genes universe. `genes` and
+#' `category_filter` are mutually exclusive (400 if both are present). Every
+#' submit records selector + fingerprint provenance in the durable payload
+#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
+#'
+#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
+#'   `category_filter` and `req$user$user_id`).
 #' @param res Plumber response, mutated in place (status + headers).
 #' @return List payload for the `json` serializer.
 #' @export
 svc_job_submit_functional_clustering <- function(req, res) {
   # Guard FIRST (#535 S6): per-caller submit admission throttle, applied before any
   # DB/cache/duplicate work so an abusive caller is rejected before it can do — or
   # provoke — expensive work (a cache hit still writes a completed job row, and the
   # duplicate/data fetch below touch the DB). Layered on the global capacity cap.
   admission <- async_job_submit_admission_guard(req, res)
   if (!isTRUE(admission$admitted)) {
     return(admission$response)
   }
 
   # Extract request data before durable submission.
 
-  # Connection objects cannot cross process boundaries
-  genes_list <- NULL
-  if (!is.null(req$argsBody$genes)) {
-    genes_list <- req$argsBody$genes
+  # Connection objects cannot cross process boundaries. `genes` and
+  # `category_filter` are mutually exclusive gene-universe selectors (#574):
+  # an explicit gene list, a curated-category selection, or (both absent) the
+  # existing default all-NDD-genes universe.
+  genes_in <- req$argsBody$genes
+  has_genes <- !is.null(genes_in) && length(genes_in) > 0
+
+  # Selector presence is gated on JSON KEY PRESENCE (`names(req$argsBody)`), not
+  # value-nullness or length: `!is.null()` cannot distinguish an ABSENT key from
+  # an explicit JSON `null` (both parse to NULL in R). So a present `genes` key
+  # (`{"genes":null,...}` / `{"genes":[],...}`) and a present `category_filter`
+  # key each drive their guard regardless of value (Codex rounds 2 & 4). Mutual
+  # exclusion 400s when BOTH keys are present; a present-but-null/empty
+  # `category_filter` is a supplied-empty 400 (in the branch below), never a
+  # silent fall-through to the all-NDD default. `has_genes` (value-based,
+  # non-empty) still selects the explicit-genes branch.
+  body_names <- names(req$argsBody)
+  genes_key <- "genes" %in% body_names
+  category_key <- "category_filter" %in% body_names
+
+  if (genes_key && category_key) {
+    stop_for_bad_request("Provide either genes or category_filter, not both")
   }
 
   # Extract algorithm parameter (default: leiden)
   # Ensure we get a scalar value (JSON may pass arrays)
   algorithm <- "leiden"
   if (!is.null(req$argsBody$algorithm)) {
     algo_input <- req$argsBody$algorithm
     # Handle array input - always take first element if vector
     if (is.list(algo_input) || length(algo_input) >= 1) {
       algo_input <- algo_input[[1]]
     }
     algorithm <- tolower(as.character(algo_input))
     if (!algorithm %in% c("leiden", "walktrap")) {
       algorithm <- "leiden"
     }
   }
 
-  # If no genes provided, use default (all NDD genes)
-  # This matches current functional_clustering endpoint behavior
-  if (is.null(genes_list) || length(genes_list) == 0) {
-    genes_list <- pool %>%
-      dplyr::tbl("ndd_entity_view") %>%
-      dplyr::arrange(entity_id) %>%
-      dplyr::filter(ndd_phenotype == 1) %>%
-      dplyr::select(hgnc_id) %>%
-      dplyr::collect() %>%
-      unique() %>%
-      dplyr::pull(hgnc_id)
+  # Resolve the clustering gene universe + selector provenance (#574). The
+  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
+  # from before this feature: `clustering_resolve_category_universe(NULL)`
+  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
+  # so cache parity (memoise key = gene set + algorithm) is preserved.
+  selector_chr <- NULL
+  if (has_genes) {
+    genes_list <- as.character(unlist(genes_in))
+    kind <- "explicit"
+  } else if (category_key) {
+    # A present category_filter key means a category run. A present-but-null
+    # value is supplied-but-empty (a NULL would otherwise hit the resolver's
+    # absent->default branch), so it is coerced to an empty selector here and
+    # delegated to the resolver -- the resolver's supplied-empty branch 400s
+    # it (with the allowed active-category set in the message), keeping the
+    # 400 message construction in the single resolver source of truth.
+    cf <- req$argsBody$category_filter
+    if (is.null(cf)) cf <- list()
+    universe <- clustering_resolve_category_universe(cf)
+    genes_list <- universe$hgnc_ids
+    selector_chr <- universe$selector
+    kind <- "category"
+  } else {
+    universe <- clustering_resolve_category_universe(NULL)
+    genes_list <- universe$hgnc_ids
+    kind <- "all_ndd"
   }
 
   # Pre-fetch the STRING ID table because DB connections cannot cross the
   # durable worker boundary.
   string_id_table <- pool %>%
     dplyr::tbl("non_alt_loci_set") %>%
     dplyr::filter(!is.na(STRING_id)) %>%
     dplyr::select(symbol, hgnc_id, STRING_id) %>%
     dplyr::collect()
 
-  # Check for duplicate job (include algorithm in check)
-  dup_check <- check_duplicate_job("clustering", list(genes = genes_list, algorithm = algorithm))
+  # Check for duplicate job (include algorithm in check). The selector is
+  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
+  # submits keep the pre-#574 dedup identity byte-identical.
+  dup_params <- list(genes = genes_list, algorithm = algorithm)
+  if (!is.null(selector_chr)) {
+    dup_params$category_filter <- selector_chr
+  }
+  dup_check <- check_duplicate_job("clustering", dup_params)
   if (dup_check$duplicate) {
     res$status <- 409
     res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
     return(list(
       error = "DUPLICATE_JOB",
       message = "Identical job already running",
       existing_job_id = dup_check$existing_job_id,
       status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
     ))
   }
 
+  # Cheap-path provenance (no expensive query yet). `selector_obj` records
+  # WHICH universe was resolved; `intended_fingerprint` records the STRING
+  # cache identity + fixed clustering params this submit intends to run
+  # with. The *effective* fingerprint (e.g. the STRING weight channel a
+  # computed result actually used) is only knowable from a computed result,
+  # so it is recorded separately in the cache-hit result meta below.
+  selector_obj <- list(kind = kind, category_filter = selector_chr)
+  intended_fingerprint <- list(
+    string_cache_fingerprint = analysis_string_cache_fingerprint(),
+    score_threshold = 400L,
+    algorithm = algorithm,
+    seed = 42L
+  )
+  gene_sha <- clustering_gene_list_sha256(genes_list)
+  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
+  # count must agree with it, so it is computed from the SAME dedup -- an
+  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
+  # not report a resolved count that disagrees with a singleton sha256. This
+  # never dedups the payload `genes` list itself (`genes_list` stays
+  # byte-identical to the raw request) -- only the reported COUNT (Codex
+  # review fix).
+  resolved_count <- length(unique(genes_list))
+
+  # Source-data version: a CACHED, fail-closed read, fetched only now that a
+  # payload is actually about to be built -- its backing view runs global
+  # counts/joins, so it must never run before admission/dedup. A lookup
+  # failure must never silently record NA/broken provenance; fail the
+  # request closed instead.
+  src_ver <- tryCatch(
+    clustering_cached_source_data_version(conn = pool),
+    error = function(e) e
+  )
+  if (inherits(src_ver, "error")) {
+    res$status <- 503L
+    return(list(
+      error = "PROVENANCE_UNAVAILABLE",
+      message = "Snapshot source-data version unavailable; retry shortly."
+    ))
+  }
+
+  provenance <- list(
+    selector = selector_obj,
+    resolved_gene_count = resolved_count,
+    gene_list_sha256 = gene_sha,
+    intended_fingerprint = intended_fingerprint,
+    source_data_version = src_ver
+  )
+
   # Define category links (needed for result)
   category_links <- tibble::tibble(
     value = c(
       "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
       "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
       "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
     ),
     link = c(
       "https://www.ebi.ac.uk/QuickGO/term/",
       "https://www.ebi.ac.uk/QuickGO/term/",
       "https://disease-ontology.org/term/",
       "https://www.ebi.ac.uk/QuickGO/term/",
       "https://hpo.jax.org/browse/term/",
       "http://www.ebi.ac.uk/interpro/entry/InterPro/",
       "https://www.genome.jp/dbget-bin/www_bget?",
       "https://www.uniprot.org/keywords/",
       "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
       "https://www.ebi.ac.uk/interpro/entry/pfam/",
       "https://www.ncbi.nlm.nih.gov/search/all/?term=",
       "https://www.ebi.ac.uk/QuickGO/term/",
       "https://reactome.org/content/detail/R-",
       "http://www.ebi.ac.uk/interpro/entry/smart/",
       "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
       "https://www.wikipathways.org/index.php/Pathway:"
     )
   )
 
   # Cache-first: if the memoized function already has a cached result,
   # return it immediately without submitting a durable worker job.
   # The network_edges endpoint (graph) warms this cache on first load,
   # so subsequent table requests resolve instantly.
   cache_hit <- tryCatch(
     memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
     error = function(e) FALSE
   )
 
   if (cache_hit) {
     cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
 
     categories <- cached_clusters %>%
       dplyr::select(term_enrichment) %>%
       tidyr::unnest(cols = c(term_enrichment)) %>%
       dplyr::select(category) %>%
       unique() %>%
       dplyr::arrange(category) %>%
       dplyr::mutate(
         text = dplyr::case_when(
           nchar(category) <= 5 ~ category,
           nchar(category) > 5 ~ stringr::str_to_sentence(category)
         )
       ) %>%
       dplyr::select(value = category, text) %>%
       dplyr::left_join(category_links, by = c("value"))
 
+    # Splice the base cache-hit fields with `provenance` (already assembled
+    # above as selector/resolved_gene_count/gene_list_sha256/
+    # intended_fingerprint/source_data_version) via the shared
+    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
+    # re-listing the same fields as duplicate literals -- keeps this shape in
+    # lockstep with the worker-run handler's result meta by construction.
+    # `effective_fingerprint` is only knowable from the computed result
+    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
     cache_result <- list(
       clusters = cached_clusters,
       categories = categories,
-      meta = list(
-        algorithm = algorithm,
-        gene_count = length(genes_list),
-        cluster_count = nrow(cached_clusters),
-        cache_hit = TRUE
+      meta = clustering_result_meta(
+        list(
+          algorithm = algorithm,
+          gene_count = resolved_count,
+          cluster_count = nrow(cached_clusters),
+          cache_hit = TRUE
+        ),
+        provenance,
+        attr(cached_clusters, "weight_channel")
       )
     )
+    cache_request_payload <- list(
+      genes = genes_list,
+      algorithm = algorithm,
+      category_links = category_links,
+      string_id_table = string_id_table,
+      provenance = provenance
+    )
+    if (!is.null(selector_chr)) {
+      cache_request_payload$category_filter <- selector_chr
+    }
+    # Dedup identity EXCLUDES provenance (Codex round 3): `provenance`
+    # carries a time-varying `source_data_version` and STRING cache
+    # `intended_fingerprint`, so hashing the full payload would make the
+    # active-job uniqueness guard admit duplicate concurrent clustering work
+    # across a deploy/cache-TTL change and break the byte-identical
+    # explicit/no-arg `request_hash` contract predating #574. Removing the
+    # `provenance` key preserves the leading `genes, algorithm,
+    # category_links, string_id_table[, category_filter]` key order -- it was
+    # appended last, so deleting it does not reorder the rest.
+    cache_hash_payload <- cache_request_payload
+    cache_hash_payload$provenance <- NULL
     completed_job <- async_job_service_store_completed(
       job_type = "clustering",
-      request_payload = list(
-        genes = genes_list,
-        algorithm = algorithm,
-        category_links = category_links,
-        string_id_table = string_id_table
-      ),
+      request_payload = cache_request_payload,
       result = cache_result,
       submitted_by = req$user$user_id %||% NULL,
       queue_name = "analysis",
-      priority = 50L
+      priority = 50L,
+      hash_payload = cache_hash_payload
     )
     job_id <- completed_job$job_id[[1]]
 
     res$status <- 202
     res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
     res$setHeader("Retry-After", "0")
 
     return(list(
       job_id = job_id,
       status = "accepted",
       estimated_seconds = 0,
       status_url = paste0("/api/jobs/", job_id, "/status"),
       meta = list(llm_generation = "snapshot_refresh_owned")
     ))
   }
 
   # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   if (async_job_capacity_exceeded(
         tryCatch(
           async_job_active_count("default"),
           error = function(e) {
             log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
             0L
           }
         )
       )) {
     res$status <- 503
     res$setHeader("Retry-After", "60")
     return(list(
       error = "CAPACITY_EXCEEDED",
       message = "Analysis queue is at capacity. Please retry shortly.",
       retry_after = 60
     ))
   }
 
   # Cache miss - create async job
-  result <- create_job(
-    operation = "clustering",
-    params = list(
-      genes = genes_list,
-      algorithm = algorithm,
-      category_links = category_links,
-      string_id_table = string_id_table
-    )
+  job_params <- list(
+    genes = genes_list,
+    algorithm = algorithm,
+    category_links = category_links,
+    string_id_table = string_id_table,
+    provenance = provenance
   )
-
-  # Check capacity
-  if (!is.null(result$error)) {
-    res$status <- 503
-    res$setHeader("Retry-After", as.character(result$retry_after))
-    return(result)
+  if (!is.null(selector_chr)) {
+    job_params$category_filter <- selector_chr
   }
+  # See the cache-hit branch above: dedup identity EXCLUDES provenance so the
+  # active-job uniqueness guard is not defeated by its time-varying fields,
+  # and explicit/no-arg submits stay byte-identical to pre-#574.
+  #
+  # `create_job()` carries a deliberately guarded 2-arg contract
+  # (`operation`, `params`) -- it cannot take a hash override. This path
+  # calls `async_job_service_submit()` directly instead (mirroring the
+  # cache-hit branch above, which already calls
+  # `async_job_service_store_completed()` directly for the same reason), so
+  # `hash_payload` can diverge from the stored `request_payload` without
+  # touching `create_job()`'s contract.
+  hash_params <- job_params
+  hash_params$provenance <- NULL
+  submitted <- async_job_service_submit(
+    job_type = "clustering",
+    request_payload = job_params,
+    hash_payload = hash_params,
+    submitted_by = req$user$user_id %||% NULL
+  )
+  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL
 
   # Success - return HTTP 202 Accepted
   res$status <- 202
-  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
+  res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   res$setHeader("Retry-After", "5")
 
   list(
-    job_id = result$job_id,
-    status = result$status,
-    estimated_seconds = result$estimated_seconds,
-    status_url = paste0("/api/jobs/", result$job_id, "/status")
+    job_id = job_id,
+    status = "accepted",
+    estimated_seconds = 30,
+    status_url = paste0("/api/jobs/", job_id, "/status")
   )
 }
diff --git a/api/tests/testthat/job-endpoint-services-fixtures.R b/api/tests/testthat/job-endpoint-services-fixtures.R
index 103f4621..03b7df8c 100644
--- a/api/tests/testthat/job-endpoint-services-fixtures.R
+++ b/api/tests/testthat/job-endpoint-services-fixtures.R
@@ -1,50 +1,106 @@
 # tests/testthat/job-endpoint-services-fixtures.R
 #
-# Shared fixtures for the job-endpoint-service unit tests, split across two files
+# Shared fixtures for the job-endpoint-service unit tests, split across four files
 # to keep each under the 600-line ceiling:
-#   - test-unit-job-endpoint-services.R              (functional + phenotype submission)
+#   - test-unit-job-endpoint-services.R              (functional submission)
+#   - test-unit-job-endpoint-services-category.R     (functional submission:
+#                                                      category_filter, #574 D2)
+#   - test-unit-job-endpoint-services-phenotype.R    (phenotype submission)
 #   - test-unit-job-endpoint-services-maintenance.R  (maintenance submission + query)
-# Both files EXPLICITLY source() this file at the top so they run standalone under a
+# All four files EXPLICITLY source() this file at the top so they run standalone under a
 # single-file `testthat::test_file()` (a plain helper-*.R auto-load is not guaranteed
 # to run there); mirrors the pubmed-xml-fixtures.R convention.
 #
 # `pool %>% dplyr::tbl(name)` is faked with a small S3 dispatch trick: a "fake_pool"
 # object wrapping a named list of tibbles, plus one `tbl.fake_pool` method registered in
 # the environment the service was sourced into (S3 dispatch finds it there). This needs
 # no test DB / RSQLite, so every test is a real PASS on host R.
 
 library(dplyr)
 library(tidyr)
 
 #' Source a service file into a fresh child-of-globalenv environment.
 #'
 #' The two public clustering submit services now call `async_job_submit_admission_guard()`
 #' FIRST (#535 S6) before any DB/cache work; stub it to "admit" by default so these
 #' isolated tests exercise the downstream request/response logic. A test can override
 #' `env$async_job_submit_admission_guard` to exercise the throttle-block path.
+#'
+#' Also sources `functions/clustering-gene-universe.R` (#574 D1/D3) into `env` so
+#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
+#' `job-functional-submission-service.R`'s cache-hit path -- is available for real
+#' (a pure list-assembly function, safe to source unstubbed). Individual tests still
+#' stub the DB/cache-touching siblings from that same file
+#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
+#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
+#' this sourcing only supplies defaults those stubs override.
 job_endpoint_source_service <- function(filename) {
   env <- new.env(parent = globalenv())
   env$async_job_submit_admission_guard <- function(req, res) list(admitted = TRUE)
+  sys.source(file.path(get_api_dir(), "functions", "clustering-gene-universe.R"), envir = env)
   sys.source(file.path(get_api_dir(), "services", filename), envir = env)
   env
 }
 
 #' Register `tbl.fake_pool` in `env` and build a fake pool over `tables`.
 job_endpoint_fake_pool <- function(env, tables) {
   env$tbl.fake_pool <- function(src, from, ...) src$tables[[from]]
   structure(list(tables = tables), class = "fake_pool")
 }
 
+#' Fake pool for job-functional-submission-service.R tests: always includes
+#' `non_alt_loci_set` (the STRING-id pre-fetch table every submit path reads),
+#' and optionally an `ndd_entity_view` for tests that exercise the all-NDD
+#' default universe. Shared by test-unit-job-endpoint-services.R and
+#' test-unit-job-endpoint-services-category.R.
+job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
+  tables <- list(
+    non_alt_loci_set = tibble::tibble(
+      symbol = c("A", "B"),
+      hgnc_id = c("HGNC:1", "HGNC:3"),
+      STRING_id = c("9606.P1", "9606.P2")
+    )
+  )
+  if (!is.null(ndd_entity_view)) {
+    tables$ndd_entity_view <- ndd_entity_view
+  }
+  job_endpoint_fake_pool(env, tables)
+}
+
+#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
+#' (#574 D2): reads `ndd_phenotype == 1` rows straight off `env$pool`'s fake
+#' `ndd_entity_view`, mirroring what the real resolver's NULL branch
+#' (`generate_ndd_hgnc_ids()`) would compute -- without needing the real
+#' function (and its DB-query internals) sourced into these isolated envs.
+job_endpoint_stub_all_ndd_universe <- function(env) {
+  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
+    testthat::expect_null(category_filter)
+    tbl <- env$pool$tables$ndd_entity_view
+    hgnc_ids <- unique(dplyr::pull(dplyr::filter(tbl, ndd_phenotype == 1), hgnc_id))
+    list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids))
+  }
+}
+
+#' Cheap provenance stubs (#574 D2): every submit path that reaches past dedup
+#' now computes `intended_fingerprint`/`gene_list_sha256`/`source_data_version`
+#' regardless of selector kind, so any test reaching that far needs these
+#' three bare globals stubbed even when it does not care about their values.
+job_endpoint_stub_clustering_provenance <- function(env) {
+  env$analysis_string_cache_fingerprint <- function() "fp-test"
+  env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
+  env$clustering_cached_source_data_version <- function(...) "srcv-test"
+}
+
 #' Minimal Plumber-response stand-in: an environment with `$status` and a
 #' `$setHeader()` that records every header set (mirrors the `res_env`
 #' pattern in test-unit-pubtator-enrichment.R).
 job_endpoint_fake_res <- function() {
   res <- new.env()
   res$status <- NULL
   res$headers <- list()
   res$setHeader <- function(name, value) {
     res$headers[[name]] <- value
     invisible(NULL)
   }
   res
 }
diff --git a/api/tests/testthat/test-integration-clustering-category-submit.R b/api/tests/testthat/test-integration-clustering-category-submit.R
new file mode 100644
index 00000000..37e174c6
--- /dev/null
+++ b/api/tests/testthat/test-integration-clustering-category-submit.R
@@ -0,0 +1,206 @@
+# api/tests/testthat/test-integration-clustering-category-submit.R
+#
+# Real-MySQL integration coverage for the category-selected clustering
+# gene-universe resolver (`clustering_resolve_category_universe()`,
+# api/functions/clustering-gene-universe.R, #574 D1/D3). Complements the
+# DB-free unit tests in test-unit-clustering-gene-universe.R (which use an
+# in-memory RSQLite fixture) with assertions against the REAL `sysndd_db_test`
+# MySQL `ndd_entity_view` -- proving entity-level resolution with no
+# client-side filter and correct MySQL translation of the dbplyr pipeline.
+#
+# ---------------------------------------------------------------------------
+# Deviation from the D3 plan brief, and why (documented per the task's own
+# instructions):
+#
+# The plan brief's literal Step 1 asked this file to seed D1's fixture
+# entities (incl. a 2nd "Definitive" gene) directly into `ndd_entity_view`'s
+# base tables on the empty test DB. `ndd_entity_view` joins ~7 tables
+# (ndd_entity + ndd_entity_status + ndd_entity_status_categories_list +
+# boolean_list + disease_ontology_set + mode_of_inheritance_list +
+# non_alt_loci_set) with a specific column/FK contract; self-seeding that
+# chain here would be fragile, easy to silently drift from the real view
+# definition, and largely redundant with the mandated live-container
+# end-to-end verification (submitting `category_filter` against the running
+# dev stack), which the controller performs separately.
+#
+# Instead, this file is SKIP-GUARDED on a populated view: it probes the live
+# `ndd_entity_view` for a real, currently-active category with >=2 distinct
+# NDD (`ndd_phenotype = 1`) genes, and only then runs. On a fresh/empty test
+# DB (CI default) every test here SKIPs cleanly. When the test DB is a
+# populated clone (a local/staging run), this file exercises the resolver
+# against the true view for real -- genuine resolver-vs-real-MySQL-view
+# coverage without fragile fixture seeding.
+# ---------------------------------------------------------------------------
+
+library(testthat)
+library(DBI)
+
+source_api_file("core/errors.R", local = FALSE)
+source_api_file("functions/clustering-gene-universe.R", local = FALSE)
+# The resolver's `is.null(selector)` (NULL/default) branch calls
+# `generate_ndd_hgnc_ids()` directly (it does NOT take `conn` on that path --
+# see clustering-gene-universe.R), so it must be sourced here too, or Test 3
+# below throws "could not find function" instead of exercising the branch.
+source_api_file("functions/analyses-functions.R", local = FALSE)
+
+#' Probe the live `ndd_entity_view` for one real, currently-active category
+#' with >=2 distinct NDD (`ndd_phenotype = 1`) genes.
+#'
+#' Joins against `ndd_entity_status_categories_list WHERE is_active = 1` so
+#' the returned category is guaranteed to pass
+#' `clustering_resolve_category_universe()`'s own live allowlist check --
+#' never returns a category that the resolver itself would reject as
+#' unknown/inactive.
+#'
+#' @param conn DBI connection to the test database.
+#' @return character(1) category name, or NULL if no such category exists
+#'   (e.g. an empty/fresh test DB, or `ndd_entity_view` is absent).
+.clustering_category_probe <- function(conn) {
+  if (!DBI::dbExistsTable(conn, "ndd_entity_view")) {
+    return(NULL)
+  }
+  if (!DBI::dbExistsTable(conn, "ndd_entity_status_categories_list")) {
+    return(NULL)
+  }
+
+  counts <- tryCatch(
+    DBI::dbGetQuery(
+      conn,
+      paste(
+        "SELECT v.category AS category, COUNT(DISTINCT v.hgnc_id) AS gene_count",
+        "FROM ndd_entity_view v",
+        "INNER JOIN ndd_entity_status_categories_list c",
+        "  ON c.category = v.category AND c.is_active = 1",
+        "WHERE v.ndd_phenotype = 1",
+        "GROUP BY v.category",
+        "ORDER BY gene_count DESC"
+      )
+    ),
+    error = function(e) NULL
+  )
+  if (is.null(counts) || nrow(counts) == 0L) {
+    return(NULL)
+  }
+
+  eligible <- counts[counts$gene_count >= 2, , drop = FALSE]
+  if (nrow(eligible) == 0L) {
+    return(NULL)
+  }
+
+  as.character(eligible$category[[1]])
+}
+
+test_that("clustering_resolve_category_universe matches a direct MySQL query on the real ndd_entity_view", {
+  with_test_db_transaction({
+    conn <- getOption(".test_db_con")
+    probe_category <- .clustering_category_probe(conn)
+    skip_if(
+      is.null(probe_category),
+      "no populated ndd_entity_view category with >=2 distinct NDD genes (empty/fresh test DB)"
+    )
+
+    resolved <- clustering_resolve_category_universe(probe_category, conn = conn)
+
+    direct <- DBI::dbGetQuery(
+      conn,
+      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1 AND category = ?",
+      params = list(probe_category)
+    )$hgnc_id
+
+    # Entity-level resolution, no client-side filter: the resolver's
+    # dbplyr-generated SQL must select exactly the same gene set as a direct
+    # equivalent query against the same live view.
+    expect_setequal(resolved$hgnc_ids, direct)
+    expect_identical(resolved$selector, probe_category)
+    expect_identical(resolved$resolved_gene_count, length(direct))
+  })
+})
+
+test_that("clustering_resolve_category_universe rejects an unknown category, naming the allowed set in the message", {
+  with_test_db_transaction({
+    conn <- getOption(".test_db_con")
+    probe_category <- .clustering_category_probe(conn)
+    skip_if(
+      is.null(probe_category),
+      "no populated ndd_entity_view category with >=2 distinct NDD genes (empty/fresh test DB)"
+    )
+
+    err <- tryCatch(
+      clustering_resolve_category_universe("Definative", conn = conn),
+      error = function(e) e
+    )
+
+    expect_s3_class(err, "error_400")
+    # The allowed active-category set is named in the MESSAGE (core/filters.R
+    # serializes conditionMessage(err), not a separate `detail` field), and a
+    # real currently-active category (the probe result) must appear in it.
+    expect_match(conditionMessage(err), "Unknown or inactive")
+    expect_match(conditionMessage(err), probe_category, fixed = TRUE)
+  })
+})
+
+test_that("clustering_resolve_category_universe(NULL) matches the default all-NDD-genes SELECT", {
+  with_test_db_transaction({
+    conn <- getOption(".test_db_con")
+    probe_category <- .clustering_category_probe(conn)
+    skip_if(
+      is.null(probe_category),
+      "no populated ndd_entity_view category with >=2 distinct NDD genes (empty/fresh test DB)"
+    )
+
+    # `generate_ndd_hgnc_ids()` (analyses-functions.R) reads the package-global
+    # `pool` directly -- the resolver's `is.null(selector)` branch does NOT
+    # forward `conn` to it (see clustering-gene-universe.R). Bind the global
+    # `pool` to this transaction's connection for the duration of the call so
+    # the NULL/default branch is exercised for real against the live view,
+    # then restore whatever `pool` held before (mirrors the
+    # test-unit-panels-endpoint.R / test-unit-endpoint-functions.R idiom).
+    # base::get(), not bare get(): a fully-loaded API/worker R session has
+    # `config::get` masking `get` (no `envir` argument there), which would
+    # error "unused argument (envir = .GlobalEnv)" (Codex review fix; see
+    # AGENTS.md "config::get masks base::get").
+    old_pool <- if (exists("pool", envir = .GlobalEnv)) base::get("pool", envir = .GlobalEnv) else NULL
+    assign("pool", conn, envir = .GlobalEnv)
+    withr::defer({
+      if (is.null(old_pool)) {
+        if (exists("pool", envir = .GlobalEnv)) rm(pool, envir = .GlobalEnv)
+      } else {
+        assign("pool", old_pool, envir = .GlobalEnv)
+      }
+    })
+
+    resolved <- clustering_resolve_category_universe(NULL, conn = conn)
+
+    # Meaningful, not tautological: compares against a DIRECT query against
+    # the real view, not against calling generate_ndd_hgnc_ids() a second
+    # time -- proves the NULL/default branch resolves the all-NDD universe
+    # correctly, independent of the resolver's own implementation.
+    direct <- DBI::dbGetQuery(
+      conn,
+      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1"
+    )$hgnc_id
+
+    expect_setequal(resolved$hgnc_ids, direct)
+    expect_null(resolved$selector)
+    expect_identical(resolved$resolved_gene_count, length(direct))
+  })
+})
+
+test_that("pool lookup uses base::get() so config::get masking (loaded API/worker env) cannot break it", {
+  # Static source guard, not a runtime probe -- reproducing the mask requires
+  # `library(config)` attached ahead of base on the search path (only true
+  # inside a fully-booted API/worker R session, not host `testthat`; see
+  # AGENTS.md "config::get masks base::get"). This file's own NULL-branch
+  # `pool` swap (three tests above) must always use the masking-safe form
+  # (Codex review fix: previously a bare `get("pool", envir = .GlobalEnv)`).
+  # Targets the specific `old_pool <-` assignment line only -- not the whole
+  # file body -- so this guard cannot accidentally match its own literals.
+  src <- readLines(
+    file.path(get_api_dir(), "tests", "testthat", "test-integration-clustering-category-submit.R"),
+    warn = FALSE
+  )
+  pool_swap_line <- src[grepl("old_pool <-.*envir = \\.GlobalEnv", src)]
+
+  expect_length(pool_swap_line, 1L)
+  expect_match(pool_swap_line, "base::get\\(", fixed = FALSE)
+})
diff --git a/api/tests/testthat/test-unit-async-job-handlers.R b/api/tests/testthat/test-unit-async-job-handlers.R
index 30f63cef..dd50b54d 100644
--- a/api/tests/testthat/test-unit-async-job-handlers.R
+++ b/api/tests/testthat/test-unit-async-job-handlers.R
@@ -1,84 +1,88 @@
 library(testthat)
 
 source_api_file("functions/async-job-force-apply-payload.R", local = FALSE)
 source_api_file("functions/async-job-omim-apply.R", local = FALSE)
+# .async_job_run_clustering assembles its result meta via clustering_result_meta()
+# (clustering-gene-universe.R, #574); source it so the handler resolves it here as
+# it does in the worker (bootstrap_load_modules sources it before the handlers).
+source_api_file("functions/clustering-gene-universe.R", local = FALSE)
 # The eagerly-built async_job_handler_registry list() references provider and
 # maintenance handler functions by bare symbol (#346 Wave 4 split), so both
 # extracted modules must be sourced BEFORE async-job-handlers.R or the list()
 # construction fails with "object '...' not found".
 source_api_file("functions/async-job-provider-handlers.R", local = FALSE)
 source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE)
 source_api_file("functions/async-job-handlers.R", local = FALSE)
 
 handler_body <- function(fn) {
   paste(deparse(body(fn)), collapse = "\n")
 }
 
 test_that(".async_job_omim_db_write uses the shared ontology refresh helper", {
   body_txt <- handler_body(.async_job_omim_db_write)
 
   expect_match(body_txt, "refresh_disease_ontology_set")
   expect_false(grepl("\\bTRUNCATE\\b", body_txt, ignore.case = TRUE))
   expect_false(grepl("DBI::dbBegin|DBI::dbCommit|DBI::dbRollback", body_txt))
 })
 
 test_that(".async_job_run_force_apply_ontology uses helper-managed transaction lifecycle", {
   body_txt <- handler_body(.async_job_run_force_apply_ontology)
 
   expect_match(body_txt, "refresh_disease_ontology_set")
   expect_false(grepl("\\bTRUNCATE\\b", body_txt, ignore.case = TRUE))
   expect_false(grepl("DBI::dbRollback\\(sysndd_db\\)", body_txt))
 })
 
 test_that(".async_job_run_omim_update forces a fresh combined ontology build", {
   body_txt <- handler_body(.async_job_run_omim_update)
 
   expect_match(body_txt, "process_combine_ontology")
   expect_match(body_txt, "max_file_age\\s*=\\s*0")
 })
 
 test_that("disease_ontology_mapping_refresh handler is registered and callable", {
   entry <- async_job_get_handler("disease_ontology_mapping_refresh")
 
   expect_type(entry, "list")
   expect_true(is.function(entry$run))
   expect_identical(entry$cancel_mode, "non_interruptible")
   expect_true(is.function(entry$after_success))
 
   body_txt <- handler_body(.async_job_run_disease_ontology_mapping_refresh)
   expect_match(body_txt, "disease_ontology_mapping_refresh_run")
 })
 
 test_that(".async_job_run_omim_update applies additive terms best-effort on block", {
   handler_txt <- handler_body(.async_job_run_omim_update)
   expect_match(handler_txt, "apply_additive_terms_on_block")
   expect_match(handler_txt, "additive_applied")
 
   helper_txt <- handler_body(apply_additive_terms_on_block)
   expect_match(helper_txt, "extract_additive_ontology_terms")
   expect_match(helper_txt, "apply_additive_ontology_terms")
   expect_match(helper_txt, "tryCatch")
   expect_match(helper_txt, "async_job_chain_ontology_mapping_refresh")
 })
 
 # ---------------------------------------------------------------------------
 # Force-apply payload-shape regression
 #
 # The blocked omim_update result builds critical_entities / auto_fixes as
 # purrr::transpose() lists of records, but get_job_status(result_mode = "full")
 # and the worker both decode with jsonlite::fromJSON(simplifyVector = TRUE),
 # which collapses an array of uniform objects into a data.frame. The previous
 # helpers iterated with vapply(table, \(x) x$field) — over a data.frame that
 # walks COLUMNS, so the column access crashed Force Apply with
 # "$ operator is invalid for atomic vectors". These tests pin the realistic
 # runtime shapes so the regression cannot return silently.
 # ---------------------------------------------------------------------------
 
 # Reproduce the JSON round-trip get_job_status()/the worker apply to the blocked
 # result before the force-apply helpers see it.
 .force_apply_roundtrip <- function(records) {
   json <- jsonlite::toJSON(records, auto_unbox = TRUE)
   jsonlite::fromJSON(json, simplifyVector = TRUE)
 }
 
 .force_apply_auto_fix_records <- function() {
diff --git a/api/tests/testthat/test-unit-async-job-service.R b/api/tests/testthat/test-unit-async-job-service.R
index 77c3b488..10dedfe6 100644
--- a/api/tests/testthat/test-unit-async-job-service.R
+++ b/api/tests/testthat/test-unit-async-job-service.R
@@ -197,103 +197,165 @@ test_that("async_job_service_cancel returns the refreshed durable job row", {
 
   runtime$async_job_repository_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
     cancel_call <<- list(job_id = job_id, cancelled_by = cancelled_by)
     1L
   }
 
   runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
     tibble::tibble(job_id = job_id, status = "cancel_requested", cancelled_by = 9L)
   }
 
   cancelled <- runtime$async_job_service_cancel("job-cancel", cancelled_by = 9L)
 
   expect_equal(cancel_call, list(job_id = "job-cancel", cancelled_by = 9L))
   expect_equal(cancelled$status[[1]], "cancel_requested")
   expect_equal(cancelled$cancelled_by[[1]], 9L)
 })
 
 # --- #486: queue routing + priority by job type ----------------------------
 
 test_that("async_job_queue_for_type routes heavy maintenance jobs to the maintenance lane", {
   runtime <- load_async_job_service_runtime()
 
   expect_equal(runtime$async_job_queue_for_type("publication_date_backfill"), "maintenance")
   expect_equal(runtime$async_job_queue_for_type("omim_update"), "maintenance")
   expect_equal(runtime$async_job_queue_for_type("disease_ontology_mapping_refresh"), "maintenance")
   expect_equal(runtime$async_job_queue_for_type("nddscore_import"), "maintenance")
 
   expect_equal(runtime$async_job_queue_for_type("llm_generation"), "default")
   expect_equal(runtime$async_job_queue_for_type("clustering"), "default")
   expect_equal(runtime$async_job_queue_for_type("phenotype_clustering"), "default")
   # Unknown / unclassified job types default to the interactive lane.
   expect_equal(runtime$async_job_queue_for_type("some_new_job"), "default")
 })
 
 test_that("interactive jobs outrank maintenance jobs in claim priority", {
   runtime <- load_async_job_service_runtime()
 
   interactive <- runtime$async_job_priority_for_type("llm_generation")
   maintenance <- runtime$async_job_priority_for_type("publication_date_backfill")
   other <- runtime$async_job_priority_for_type("some_new_job")
 
   # Lower number = claimed first (claim query orders priority ASC).
   expect_lt(interactive, maintenance)
   expect_lt(maintenance, other)
   expect_equal(runtime$async_job_priority_for_type("clustering"), interactive)
   expect_equal(runtime$async_job_priority_for_type("omim_update"), maintenance)
 })
 
 test_that("async_job_service_submit defaults queue + priority from the job type", {
   runtime <- load_async_job_service_runtime()
   created_job <- NULL
 
   runtime$async_job_repository_create <- function(job, conn = NULL) {
     created_job <<- job
     job$job_id
   }
   runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
     tibble::tibble(job_id = job_id, queue_name = created_job$queue_name,
                    priority = created_job$priority)
   }
 
   # publication_date_backfill (maintenance) with no explicit queue/priority.
   runtime$async_job_service_submit(
     job_type = "publication_date_backfill",
     request_payload = list(dry_run = FALSE),
     job_id = "job-maint"
   )
   expect_equal(created_job$queue_name, "maintenance")
   expect_equal(created_job$priority, 50L)
 
   # llm_generation (interactive) with no explicit queue/priority.
   runtime$async_job_service_submit(
     job_type = "llm_generation",
     request_payload = list(cluster = 1L),
     job_id = "job-llm"
   )
   expect_equal(created_job$queue_name, "default")
   expect_equal(created_job$priority, 10L)
 })
 
+test_that("async_job_service_submit hashes hash_payload when supplied, not the full payload (#574 Codex round 3)", {
+  runtime <- load_async_job_service_runtime()
+  created_job <- NULL
+
+  runtime$async_job_repository_create <- function(job, conn = NULL) {
+    created_job <<- job
+    job$job_id
+  }
+  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
+    tibble::tibble(job_id = job_id, request_hash = created_job$request_hash,
+                   request_payload_json = created_job$request_payload_json)
+  }
+
+  full_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden",
+                       provenance = list(source_data_version = "2026-07-18T00:00:00Z"))
+  subset_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden")
+
+  runtime$async_job_service_submit(
+    job_type = "clustering",
+    request_payload = full_payload,
+    hash_payload = subset_payload,
+    job_id = "job-hash-override"
+  )
+
+  # request_hash is computed over hash_payload (the subset), not the full payload.
+  expect_equal(
+    created_job$request_hash,
+    runtime$async_job_service_request_hash(
+      "clustering",
+      runtime$async_job_service_payload_json(subset_payload)
+    )
+  )
+  expect_false(identical(
+    created_job$request_hash,
+    runtime$async_job_service_request_hash(
+      "clustering",
+      runtime$async_job_service_payload_json(full_payload)
+    )
+  ))
+
+  # request_payload_json (the DURABLY STORED payload) is always the FULL payload,
+  # provenance included -- only the dedup hash excludes it.
+  expect_equal(
+    jsonlite::fromJSON(created_job$request_payload_json, simplifyVector = TRUE)$provenance$source_data_version,
+    "2026-07-18T00:00:00Z"
+  )
+
+  # Default behavior (no hash_payload) is unchanged: hash the full payload.
+  runtime$async_job_service_submit(
+    job_type = "clustering",
+    request_payload = full_payload,
+    job_id = "job-hash-default"
+  )
+  expect_equal(
+    created_job$request_hash,
+    runtime$async_job_service_request_hash(
+      "clustering",
+      runtime$async_job_service_payload_json(full_payload)
+    )
+  )
+})
+
 test_that("async_job_service_submit still honors explicit queue + priority overrides", {
   runtime <- load_async_job_service_runtime()
   created_job <- NULL
 
   runtime$async_job_repository_create <- function(job, conn = NULL) {
     created_job <<- job
     job$job_id
   }
   runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
     tibble::tibble(job_id = job_id, queue_name = created_job$queue_name,
                    priority = created_job$priority)
   }
 
   runtime$async_job_service_submit(
     job_type = "publication_date_backfill",
     request_payload = list(dry_run = FALSE),
     queue_name = "analysis",
     priority = 5L,
     job_id = "job-explicit"
   )
   expect_equal(created_job$queue_name, "analysis")
   expect_equal(created_job$priority, 5L)
 })
diff --git a/api/tests/testthat/test-unit-async-job-worker.R b/api/tests/testthat/test-unit-async-job-worker.R
index 792903e1..30a2565d 100644
--- a/api/tests/testthat/test-unit-async-job-worker.R
+++ b/api/tests/testthat/test-unit-async-job-worker.R
@@ -1,98 +1,99 @@
 library(testthat)
 library(withr)
 library(jsonlite)
 library(tibble)
 
 async_job_worker_runtime_paths <- function() {
   api_dir <- get_api_dir()
   c(
     file.path(api_dir, "functions", "async-job-progress.R"),
     # .async_job_phenotype_matrix() calls phenotype_mca_prep_matrix() (#508 MCA hygiene);
     # load it here so the durable phenotype-clustering handler test resolves it the way
     # load_modules.R does in production (prep is sourced before async-job-handlers.R).
     file.path(api_dir, "functions", "analysis-phenotype-mca-prep.R"),
     # #346 Wave 4: async_job_handler_registry binds provider/maintenance handler
     # functions by bare symbol inside an eagerly-evaluated list(), so both
     # extracted modules must be sourced before async-job-handlers.R here too.
     file.path(api_dir, "functions", "async-job-provider-handlers.R"),
     file.path(api_dir, "functions", "async-job-maintenance-handlers.R"),
+    file.path(api_dir, "functions", "clustering-gene-universe.R"),
     file.path(api_dir, "functions", "async-job-handlers.R"),
     file.path(api_dir, "functions", "async-job-worker.R"),
     file.path(api_dir, "functions", "job-progress.R")
   )
 }
 
 load_async_job_worker_runtime <- function() {
   runtime_env <- new.env(parent = globalenv())
   runtime_paths <- async_job_worker_runtime_paths()
 
   missing <- runtime_paths[!file.exists(runtime_paths)]
   if (length(missing) > 0) {
     stop(
       "async-job worker runtime files are missing: ",
       paste(basename(missing), collapse = ", ")
     )
   }
 
   for (path in runtime_paths) {
     sys.source(path, envir = runtime_env)
   }
 
   runtime_env
 }
 
 test_that("async_job_worker_config_from_env reads bounded worker settings", {
   runtime <- load_async_job_worker_runtime()
 
   withr::local_envvar(c(
     ASYNC_JOB_LEASE_SECONDS = "75",
     ASYNC_JOB_RUN_LEASE_SECONDS = "600",
     ASYNC_JOB_IDLE_SLEEP_SECONDS = "1.5",
     MAX_JOBS_PER_WORKER = "7",
     MAX_WORKER_LIFETIME = "900",
     ASYNC_JOB_QUEUES = "default,bulk",
     ASYNC_JOB_DRAIN_FILE = "/tmp/sysndd-test-drain"
   ))
 
   config <- runtime$async_job_worker_config_from_env()
 
   expect_true(is.character(config$worker_id))
   expect_true(nzchar(config$worker_id))
   expect_true(is.character(config$hostname))
   expect_true(nzchar(config$hostname))
   expect_equal(config$lease_seconds, 75L)
   expect_equal(config$job_run_lease_seconds, 600L)
   expect_equal(config$idle_sleep_seconds, 1.5)
   expect_equal(config$max_jobs_per_worker, 7L)
   expect_equal(config$max_worker_lifetime_seconds, 900L)
   expect_equal(config$queues, c("default", "bulk"))
   expect_equal(config$drain_file, "/tmp/sysndd-test-drain")
 })
 
 test_that("create_async_job_progress_reporter updates durable row progress and throttles interim writes", {
   runtime <- load_async_job_worker_runtime()
   calls <- list()
   heartbeat_calls <- list()
 
   runtime$async_job_repository_update_progress <- function(job_id, progress_pct = NULL, progress_message = NULL, claim_token, conn = NULL) { # nolint: line_length_linter
     calls[[length(calls) + 1L]] <<- list(
       job_id = job_id,
       progress_pct = progress_pct,
       progress_message = progress_message,
       claim_token = claim_token
     )
     1L
   }
   runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
     heartbeat_calls[[length(heartbeat_calls) + 1L]] <<- list(
       job_id = job_id,
       lease_seconds = lease_seconds,
       claim_token = claim_token
     )
     1L
   }
 
   runtime$async_job_worker_set_claim_context(
     list(
       job_id = "job-progress",
       claim_token = "claim-progress"
diff --git a/api/tests/testthat/test-unit-clustering-gene-universe.R b/api/tests/testthat/test-unit-clustering-gene-universe.R
new file mode 100644
index 00000000..5930bb0b
--- /dev/null
+++ b/api/tests/testthat/test-unit-clustering-gene-universe.R
@@ -0,0 +1,305 @@
+# Unit tests for the category-selected clustering gene-universe resolver (#574 D1).
+#
+# `clustering_resolve_category_universe()` resolves the gene set a clustering
+# job runs on: either the current default (all NDD genes, via
+# `generate_ndd_hgnc_ids()`) or a curated-category selection
+# (`ndd_entity_view` entity rows filtered by `category %in% selector`, then
+# distinct `hgnc_id`). This file is DB-free: the default branch's dependency
+# (`generate_ndd_hgnc_ids()`) is overridden in a child environment, and the
+# category branch's `conn` is a real in-memory RSQLite connection so the
+# dbplyr pipeline (`tbl()` / `filter()` / `select()` / `collect()`) is
+# exercised for real rather than mocked.
+#
+# Trap: do NOT stub `generate_ndd_hgnc_ids` via
+# `testthat::local_mocked_bindings(..., .env = globalenv())` -- under
+# testthat 3.3.2 that aborts with "No packages loaded with pkgload" because
+# globalenv() has no package namespace. A child-env override sidesteps this.
+
+## -------------------------------------------------------------------------##
+## clustering_cached_source_data_version() TTL cache (#574 D2 review fix)
+## -------------------------------------------------------------------------##
+#
+# These tests stub `analysis_snapshot_source_data_version()` directly -- no DB
+# connection is ever opened -- so they are placed BEFORE the file-wide
+# `skip_if_not_installed("RSQLite")` gate below and run unconditionally, even
+# when {RSQLite} is unavailable.
+
+# Sources ONLY core/errors.R + the module under test into a fresh child env.
+# A fresh env means a fresh `.clustering_source_data_version_cache` (it is
+# created top-level by the sourced file), so there is nothing left over from
+# a prior test -- `.reset_source_data_version_cache()` below is still applied
+# defensively so the reset mechanism itself stays covered/documented.
+.source_data_version_env <- function() {
+  e <- new.env(parent = globalenv())
+  source_api_file("core/errors.R", local = FALSE, envir = e)
+  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
+  e
+}
+
+# Clears the module-level TTL cache env so cached state never leaks across
+# assertions sharing the same sourced env `e`.
+.reset_source_data_version_cache <- function(e) {
+  cache_env <- e$.clustering_source_data_version_cache
+  keys <- ls(cache_env, all.names = TRUE)
+  if (length(keys) > 0L) rm(list = keys, envir = cache_env)
+}
+
+test_that("clustering_cached_source_data_version: TTL hit avoids a second underlying fetch", {
+  e <- .source_data_version_env()
+  .reset_source_data_version_cache(e)
+  calls <- 0L
+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
+    calls <<- calls + 1L
+    "v1"
+  }
+
+  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
+  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
+
+  expect_identical(first, "v1")
+  expect_identical(second, "v1")
+  expect_identical(calls, 1L) # second call served from cache, underlying fn NOT re-invoked
+})
+
+test_that("clustering_cached_source_data_version: TTL expiry (ttl_seconds = 0) forces a refetch", {
+  # `diff < ttl_seconds` is the staleness check; `diff` (elapsed seconds since
+  # the last successful fetch) is always >= 0, so `ttl_seconds = 0` makes
+  # `diff < 0` FALSE on every subsequent call -- deterministically always-stale,
+  # regardless of clock resolution between the two calls.
+  e <- .source_data_version_env()
+  .reset_source_data_version_cache(e)
+  calls <- 0L
+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
+    calls <<- calls + 1L
+    paste0("v", calls)
+  }
+
+  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
+  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
+
+  expect_identical(first, "v1")
+  expect_identical(second, "v2")
+  expect_identical(calls, 2L) # both calls hit the underlying fn -- cache never served a hit
+})
+
+test_that("clustering_cached_source_data_version: an error propagates and never poisons the cache", {
+  e <- .source_data_version_env()
+  .reset_source_data_version_cache(e)
+  e$analysis_snapshot_source_data_version <- function(conn = NULL) stop("boom")
+
+  expect_error(
+    e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300),
+    "boom"
+  )
+  # Nothing was written to the cache by the failed call.
+  expect_null(e$.clustering_source_data_version_cache$value)
+  expect_null(e$.clustering_source_data_version_cache$cached_at)
+
+  # Swap to a success stub: the NEXT call must refetch (not serve a stale/NA
+  # value left over from the failed attempt) and the cache must now work.
+  .reset_source_data_version_cache(e)
+  calls <- 0L
+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
+    calls <<- calls + 1L
+    "v-success"
+  }
+
+  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
+
+  expect_identical(result, "v-success")
+  expect_identical(calls, 1L)
+})
+
+test_that("clustering_cached_source_data_version: NA_character_ from the underlying fetch is rejected and never cached (Codex review fix)", {
+  # Fail-closed contract: the TTL cache must never cache/return NA. A
+  # malformed underlying value must stop() (mapped to 503 by the caller's
+  # tryCatch), exactly like a hard fetch error above -- not be cached and
+  # served as broken provenance.
+  e <- .source_data_version_env()
+  .reset_source_data_version_cache(e)
+  calls <- 0L
+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
+    calls <<- calls + 1L
+    NA_character_
+  }
+
+  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
+  # Nothing was written to the cache by the invalid-value call.
+  expect_null(e$.clustering_source_data_version_cache$value)
+  expect_null(e$.clustering_source_data_version_cache$cached_at)
+
+  # Swap to a now-valid stub: the NEXT call must refetch (never serve the
+  # invalid value from a poisoned cache) and the counter must increment.
+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
+    calls <<- calls + 1L
+    "v-valid"
+  }
+  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
+
+  expect_identical(result, "v-valid")
+  expect_identical(calls, 2L)
+})
+
+test_that("clustering_cached_source_data_version: an empty string from the underlying fetch is rejected and never cached (Codex review fix)", {
+  e <- .source_data_version_env()
+  .reset_source_data_version_cache(e)
+  e$analysis_snapshot_source_data_version <- function(conn = NULL) ""
+
+  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
+  expect_null(e$.clustering_source_data_version_cache$value)
+  expect_null(e$.clustering_source_data_version_cache$cached_at)
+})
+
+testthat::skip_if_not_installed("RSQLite")
+
+# Source the code under test into a child env so the NULL-branch dependency
+# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
+# globalenv() or any other test file's bindings.
+.gene_universe_env <- function() {
+  e <- new.env(parent = globalenv())
+  source_api_file("core/errors.R", local = FALSE, envir = e)
+  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
+  e
+}
+
+# In-memory RSQLite fixture standing in for `pool`/a real DB connection.
+# `ev` = ndd_entity_view rows, `cats` = ndd_entity_status_categories_list rows.
+fake_conn <- function(ev, cats) {
+  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
+  DBI::dbWriteTable(con, "ndd_entity_view", as.data.frame(ev))
+  DBI::dbWriteTable(con, "ndd_entity_status_categories_list", as.data.frame(cats))
+  con
+}
+
+# Fixture: entity rows (one row per entity). TWO Definitive NDD genes so the
+# ["Definitive"] universe passes the >=2 guard.
+ev <- tibble::tribble(
+  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
+  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
+  2L,        "HGNC:1",   1L,             "Limited",
+  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
+  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
+  5L,        "HGNC:4",   1L,             "Moderate",     # gene 4: Moderate NDD (single -> too-small alone)
+  6L,        "HGNC:5",   1L,             "Definitive"    # gene 5: second Definitive NDD gene
+)
+cats <- tibble::tibble(
+  category = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
+  is_active = 1L
+)
+
+test_that("Definitive selects genes with any Definitive NDD entity (multi-entity gene included)", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+
+  r <- e$clustering_resolve_category_universe("Definitive", conn = con)
+
+  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5")) # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
+  expect_identical(r$selector, "Definitive")
+  expect_identical(r$resolved_gene_count, 2L)
+})
+
+test_that("multi-value selector is a union across categories", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+
+  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)
+
+  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5", "HGNC:4"))
+})
+
+test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+  e$generate_ndd_hgnc_ids <- function() {
+    tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5"))
+  }
+
+  r <- e$clustering_resolve_category_universe(NULL, conn = con)
+
+  expect_identical(r$hgnc_ids, c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5")) # arrange(entity_id)+distinct, ndd_phenotype==1
+  expect_null(r$selector)
+})
+
+test_that("unknown token is rejected 400 with the allowed set in the MESSAGE (not detail)", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+
+  err <- tryCatch(
+    e$clustering_resolve_category_universe("Definative", conn = con),
+    error = function(err) err
+  )
+
+  expect_s3_class(err, "error_400")
+  expect_match(conditionMessage(err), "Definitive") # allowed set is in the message so it reaches clients
+})
+
+test_that("supplied-but-empty selector is 400 (NOT the all-NDD default) with the allowed set in the message", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+
+  err_empty <- tryCatch(
+    e$clustering_resolve_category_universe(list(), conn = con),
+    error = function(err) err
+  )
+  err_blank <- tryCatch(
+    e$clustering_resolve_category_universe(list("   "), conn = con),
+    error = function(err) err
+  )
+
+  expect_s3_class(err_empty, "error_400")
+  expect_s3_class(err_blank, "error_400")
+  # The locked contract: EVERY category-validation 400 names the allowed set.
+  expect_match(conditionMessage(err_empty), "Allowed active categories")
+  expect_match(conditionMessage(err_empty), "Definitive")
+  expect_match(conditionMessage(err_blank), "Allowed active categories")
+  expect_match(conditionMessage(err_blank), "Definitive")
+})
+
+test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job) with the allowed set in the message", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+
+  err_zero <- tryCatch(
+    e$clustering_resolve_category_universe("Refuted", conn = con), # 0 genes
+    error = function(err) err
+  )
+  err_one <- tryCatch(
+    e$clustering_resolve_category_universe("Moderate", conn = con), # 1 gene
+    error = function(err) err
+  )
+
+  expect_s3_class(err_zero, "error_400")
+  expect_s3_class(err_one, "error_400")
+  expect_match(conditionMessage(err_zero), "Allowed active categories")
+  expect_match(conditionMessage(err_zero), "Definitive")
+  expect_match(conditionMessage(err_one), "Allowed active categories")
+  expect_match(conditionMessage(err_one), "Definitive")
+})
+
+test_that("gene_list_sha256 is sort-order independent", {
+  e <- .gene_universe_env()
+
+  expect_identical(
+    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
+    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
+  )
+})
+
+test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
+  e <- .gene_universe_env()
+
+  expect_null(e$clustering_normalize_category_filter(NULL))
+  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
+  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
+  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
+  expect_identical(
+    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
+    c("Definitive", "Moderate")
+  )
+})
diff --git a/api/tests/testthat/test-unit-clustering-handler-meta.R b/api/tests/testthat/test-unit-clustering-handler-meta.R
new file mode 100644
index 00000000..8ea0b5ca
--- /dev/null
+++ b/api/tests/testthat/test-unit-clustering-handler-meta.R
@@ -0,0 +1,171 @@
+# Unit tests for the durable clustering handler's result `meta` (#574 D3).
+#
+# `.async_job_run_clustering()` (api/functions/async-job-handlers.R) is the
+# worker-run (cache-miss) counterpart to the cache-hit path in
+# `svc_job_submit_functional_clustering()` (job-functional-submission-service.R,
+# #574 D2). D2 already stitches the request's cheap-path `provenance` list
+# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
+# source_data_version) plus an `effective_fingerprint` (the STRING
+# `weight_channel` actually observed on the computed result) into the
+# cache-hit result `meta`. D3 makes the durable handler mirror that SAME
+# shape for a worker-run job, so a silent exp+db -> combined-score STRING
+# fallback is visible in a freshly-computed job's stored result too, not
+# just a cache hit's.
+#
+# DB-free: `gen_string_clust_obj` and its category-enrichment/progress-reporter
+# collaborators are stubbed in a child environment. This file never opens a
+# DB connection and always runs (no skip guard).
+#
+# Trap (documented in test-unit-clustering-gene-universe.R and repeated here):
+# do NOT stub via `testthat::local_mocked_bindings(..., .env = globalenv())`
+# -- under testthat 3.3.2 that aborts with "No packages loaded with
+# pkgload" because globalenv() has no package namespace. A child-env
+# override (source into a fresh `new.env(parent = globalenv())`, then
+# reassign bindings on that env) sidesteps this entirely.
+
+.clustering_handler_env <- function() {
+  e <- new.env(parent = globalenv())
+  # async-job-handlers.R's eagerly-built async_job_handler_registry list()
+  # references handler functions from these sibling modules by bare symbol
+  # (#346 Wave 4 split; see the file's own header comment), so they must be
+  # sourced first or the list() construction fails with "object '...' not
+  # found" -- mirrors test-unit-async-job-handlers.R.
+  source_api_file("functions/async-job-force-apply-payload.R", local = FALSE, envir = e)
+  source_api_file("functions/async-job-omim-apply.R", local = FALSE, envir = e)
+  source_api_file("functions/async-job-provider-handlers.R", local = FALSE, envir = e)
+  source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE, envir = e)
+  source_api_file("functions/async-job-network-layout-handlers.R", local = FALSE, envir = e)
+  source_api_file("functions/async-job-analysis-snapshot-handlers.R", local = FALSE, envir = e)
+  # `.async_job_run_clustering()`'s result-`meta` assembly calls
+  # `clustering_result_meta()` (#574 D3 fix wave 1), the shared helper defined
+  # in clustering-gene-universe.R -- source it too or the handler errors with
+  # "could not find function".
+  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
+  source_api_file("functions/async-job-handlers.R", local = FALSE, envir = e)
+
+  # Stub the heavy clustering computation: returns a minimal tibble carrying
+  # the SAME `weight_channel` attribute contract `gen_string_clust_obj` sets
+  # (analyses-functions.R:351) so the handler's `effective_fingerprint`
+  # extraction is exercised for real.
+  e$gen_string_clust_obj <- function(genes, algorithm, string_id_table) {
+    x <- tibble::tibble(cluster = 1L)
+    attr(x, "weight_channel") <- "experimental_database"
+    x
+  }
+
+  # `.async_job_functional_categories(clusters, category_links)` is called
+  # unconditionally by the handler; stub it out so this test does not also
+  # have to fabricate a `term_enrichment` column on the stub clusters tibble.
+  e$.async_job_functional_categories <- function(clusters, category_links) {
+    tibble::tibble()
+  }
+
+  # Bypasses `create_async_job_progress_reporter()` (a separate, unsourced
+  # module in this DB-free test) -- see file header trap note.
+  e$.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
+    function(...) invisible(NULL)
+  }
+
+  e
+}
+
+test_that(".async_job_run_clustering echoes payload provenance + effective_fingerprint into result meta", {
+  e <- .clustering_handler_env()
+
+  payload <- list(
+    genes = c("HGNC:1", "HGNC:5"),
+    algorithm = "leiden",
+    string_id_table = NULL,
+    category_links = NULL,
+    provenance = list(
+      selector = list(kind = "category", category_filter = "Definitive"),
+      resolved_gene_count = 2L,
+      gene_list_sha256 = "abc",
+      intended_fingerprint = list(string_cache_fingerprint = "fp"),
+      source_data_version = "srcv-1"
+    )
+  )
+
+  result <- e$.async_job_run_clustering(
+    job = list(job_id = "j1"),
+    payload = payload,
+    state = NULL,
+    worker_config = NULL
+  )
+
+  meta <- result$meta
+
+  expect_identical(meta$algorithm, "leiden")
+  expect_identical(meta$gene_count, 2L)
+  expect_identical(meta$cluster_count, 1L)
+  # Shape parity with the cache-hit path's meta (job-functional-submission-
+  # service.R), which always carries cache_hit = TRUE: a worker-run job must
+  # carry cache_hit = FALSE so callers can distinguish the two without an
+  # absent-field check.
+  expect_identical(meta$cache_hit, FALSE)
+  expect_identical(meta$selector$kind, "category")
+  expect_identical(meta$gene_list_sha256, "abc")
+  expect_identical(meta$source_data_version, "srcv-1")
+  expect_identical(meta$intended_fingerprint$string_cache_fingerprint, "fp")
+  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
+})
+
+test_that(".async_job_run_clustering: gene_count is the DISTINCT gene count, matching the cache-hit path (Codex round-2 review fix)", {
+  # Bug: the worker handler reported `gene_count = length(genes)` (raw),
+  # while the cache-hit path (job-functional-submission-service.R) reports
+  # `resolved_count <- length(unique(genes_list))` (distinct) -- for
+  # `["HGNC:1","HGNC:1"]` the cache-hit path reports gene_count=1 but the
+  # worker reported gene_count=2 for the identical payload. Both paths must
+  # agree.
+  e <- .clustering_handler_env()
+
+  payload <- list(
+    genes = c("HGNC:1", "HGNC:1"),
+    algorithm = "leiden",
+    string_id_table = NULL,
+    category_links = NULL
+  )
+
+  result <- e$.async_job_run_clustering(
+    job = list(job_id = "j-dup-genes"),
+    payload = payload,
+    state = NULL,
+    worker_config = NULL
+  )
+
+  expect_identical(result$meta$gene_count, 1L)
+})
+
+test_that(".async_job_run_clustering: legacy payload with no provenance still returns a valid meta (backward compat)", {
+  e <- .clustering_handler_env()
+
+  payload <- list(
+    genes = c("HGNC:1", "HGNC:5", "HGNC:9"),
+    algorithm = "walktrap",
+    string_id_table = NULL,
+    category_links = NULL
+    # No `provenance` field -- mirrors an explicit/no-arg pre-#574 submit.
+  )
+
+  result <- NULL
+  expect_no_error({
+    result <- e$.async_job_run_clustering(
+      job = list(job_id = "j2"),
+      payload = payload,
+      state = NULL,
+      worker_config = NULL
+    )
+  })
+
+  meta <- result$meta
+
+  expect_identical(meta$algorithm, "walktrap")
+  expect_identical(meta$gene_count, 3L)
+  expect_identical(meta$cluster_count, 1L)
+  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
+  # No provenance fields leaked in when the payload never carried them.
+  expect_null(meta$selector)
+  expect_null(meta$gene_list_sha256)
+  expect_null(meta$source_data_version)
+  expect_null(meta$intended_fingerprint)
+})
diff --git a/api/tests/testthat/test-unit-job-endpoint-services-category.R b/api/tests/testthat/test-unit-job-endpoint-services-category.R
new file mode 100644
index 00000000..ff142b78
--- /dev/null
+++ b/api/tests/testthat/test-unit-job-endpoint-services-category.R
@@ -0,0 +1,402 @@
+# tests/testthat/test-unit-job-endpoint-services-category.R
+#
+# Host-runnable unit tests for the #574 (D2) category_filter / provenance /
+# dedup-hash-payload coverage of job-functional-submission-service.R, split
+# out of test-unit-job-endpoint-services.R (which keeps the base functional-
+# clustering submit coverage) to keep both files under the 600-line ceiling
+# after the #574 Codex-review-fix rounds grew this coverage. Shared fixtures
+# live in job-endpoint-services-fixtures.R (explicitly sourced below,
+# mirroring the sibling files). See test-unit-job-endpoint-services.R's
+# header for the full split rationale (phenotype submission coverage lives in
+# test-unit-job-endpoint-services-phenotype.R; maintenance-submission +
+# query-endpoint services are covered in
+# test-unit-job-endpoint-services-maintenance.R).
+#
+# Each service is sourced directly into an isolated environment via sys.source()
+# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
+# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
+# async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
+# gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
+# exercise pure request/response logic without a live DB or mirai daemon pool.
+
+# Resolve api_dir robustly so the file runs both under the full suite and a single-file
+# testthat::test_file(), then source the shared fixtures.
+if (exists("get_api_dir")) {
+  api_dir <- get_api_dir()
+} else {
+  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
+  if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
+    api_dir <- normalizePath(getwd(), mustWork = FALSE)
+  }
+}
+# local = TRUE keeps the shared helpers in this test file's environment (as if defined
+# inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
+source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)
+
+## -------------------------------------------------------------------##
+## job-functional-submission-service.R: category_filter (#574 D2)
+## -------------------------------------------------------------------##
+
+test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  # stop_for_bad_request() lives in core/errors.R, not sourced by the isolated
+  # service env by default -- source it here so the real (non-stubbed)
+  # mutual-exclusion guard in the service body can raise it.
+  source_api_file("core/errors.R", local = FALSE, envir = env)
+  env$pool <- job_endpoint_functional_pool(env)
+  req <- list(
+    argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive")),
+    user = list(user_id = NULL)
+  )
+  res <- job_endpoint_fake_res()
+
+  expect_error(
+    env$svc_job_submit_functional_clustering(req, res),
+    class = "error_400"
+  )
+})
+
+test_that("functional clustering: an EMPTY genes array + category_filter still triggers mutual exclusion -> error_400 (Codex review fix)", {
+  # Bug: mutual exclusion was previously gated on `has_genes` (a LENGTH
+  # check), so `{"genes":[], "category_filter":["Definitive"]}` bypassed it
+  # -- an empty-but-PRESENT `genes` key must still 400 when a category_filter
+  # is also present. Presence (`genes_supplied <- !is.null(genes_in)`), not
+  # length, is what mutual exclusion must gate on.
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  source_api_file("core/errors.R", local = FALSE, envir = env)
+  env$pool <- job_endpoint_functional_pool(env)
+  req <- list(
+    argsBody = list(genes = list(), category_filter = list("Definitive")),
+    user = list(user_id = NULL)
+  )
+  res <- job_endpoint_fake_res()
+
+  expect_error(
+    env$svc_job_submit_functional_clustering(req, res),
+    class = "error_400"
+  )
+})
+
+test_that("functional clustering: an explicit-null genes KEY + category_filter still triggers mutual exclusion -> error_400 (Codex round-2 review fix)", {
+  # Bug: mutual exclusion was gated on `!is.null(genes_in)`, which cannot
+  # distinguish an ABSENT `genes` key from an explicit JSON `null` (both
+  # parse to a NULL `req$argsBody$genes`) -- so
+  # `{"genes":null, "category_filter":["Definitive"]}` bypassed the guard and
+  # a category job was silently accepted. `list(genes = NULL)` in base R
+  # KEEPS the `genes` name with a NULL value (verified:
+  # "genes" %in% names(list(genes = NULL)) is TRUE), so gating on
+  # `names(req$argsBody)` instead of value-nullness catches this.
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  source_api_file("core/errors.R", local = FALSE, envir = env)
+  env$pool <- job_endpoint_functional_pool(env)
+  req <- list(
+    argsBody = list(genes = NULL, category_filter = list("Definitive")),
+    user = list(user_id = NULL)
+  )
+  res <- job_endpoint_fake_res()
+
+  expect_true("genes" %in% names(req$argsBody)) # pin the base-R name-retention fact this test relies on
+  expect_error(
+    env$svc_job_submit_functional_clustering(req, res),
+    class = "error_400"
+  )
+})
+
+test_that("functional clustering: an explicit-null genes KEY ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
+  # Regression guard for the fix above: gating mutual exclusion on JSON key
+  # presence must NOT change the pre-existing behavior for a null `genes`
+  # value with no `category_filter` at all -- it must still fall through to
+  # the all-NDD default exactly as before.
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
+    entity_id = 1:3,
+    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
+    ndd_phenotype = c(1L, 0L, 1L)
+  ))
+  job_endpoint_stub_all_ndd_universe(env)
+  captured <- NULL
+  env$check_duplicate_job <- function(operation, params) {
+    captured <<- params
+    list(duplicate = TRUE, existing_job_id = "dup-null-genes")
+  }
+  req <- list(argsBody = list(genes = NULL), user = list(user_id = NULL))
+  res <- job_endpoint_fake_res()
+
+  out <- env$svc_job_submit_functional_clustering(req, res)
+
+  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
+  expect_equal(res$status, 409)
+  expect_equal(out$error, "DUPLICATE_JOB")
+})
+
+test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
+  # Regression guard for the fix above: gating mutual exclusion on
+  # `genes_supplied` (key presence) must NOT change the pre-existing
+  # behavior for an empty `genes` array with no `category_filter` at all --
+  # it must still fall through to the all-NDD default exactly as before.
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
+    entity_id = 1:3,
+    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
+    ndd_phenotype = c(1L, 0L, 1L)
+  ))
+  job_endpoint_stub_all_ndd_universe(env)
+  captured <- NULL
+  env$check_duplicate_job <- function(operation, params) {
+    captured <<- params
+    list(duplicate = TRUE, existing_job_id = "dup-empty-genes")
+  }
+  req <- list(argsBody = list(genes = list()), user = list(user_id = NULL))
+  res <- job_endpoint_fake_res()
+
+  out <- env$svc_job_submit_functional_clustering(req, res)
+
+  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
+  expect_equal(res$status, 409)
+  expect_equal(out$error, "DUPLICATE_JOB")
+})
+
+test_that("functional clustering: an explicit-null category_filter KEY (no genes) coerces to an empty selector and delegates to the resolver (Codex round-5 review fix)", {
+  # Bug: the branch used `category_supplied <- !is.null(category_filter)`, so a
+  # present-but-null `category_filter` key (`{"category_filter":null}`) was
+  # treated as ABSENT and silently resolved the all-NDD default instead of the
+  # required supplied-empty 400 -- the category-side symmetry of the genes-null
+  # fix. The branch now keys off `"category_filter" %in% names(req$argsBody)`.
+  #
+  # Round 5: the service no longer raises its own standalone 400 for this case
+  # (that duplicated the resolver's message and omitted the allowed active-
+  # category set). It now coerces the NULL to an empty selector (`list()`) and
+  # DELEGATES to `clustering_resolve_category_universe()`, which 400s a
+  # supplied-but-empty selector with the allowed set in the message (covered
+  # by test-unit-clustering-gene-universe.R). This test proves the DELEGATION
+  # (empty selector reaches the resolver), not the 400 itself.
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  source_api_file("core/errors.R", local = FALSE, envir = env)
+  env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
+  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  env$async_job_active_count <- function(...) 0L
+  env$async_job_service_submit <- function(...) list(job = tibble::tibble(job_id = "j-null-cf"))
+  captured_cf <- "not-called"
+  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
+    captured_cf <<- category_filter
+    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "x", resolved_gene_count = 2L)
+  }
+  req <- list(
+    argsBody = list(category_filter = NULL),
+    user = list(user_id = NULL)
+  )
+  res <- job_endpoint_fake_res()
+
+  expect_true("category_filter" %in% names(req$argsBody))
+  env$svc_job_submit_functional_clustering(req, res)
+
+  expect_equal(length(captured_cf), 0L) # NULL coerced to an empty selector, not skipped
+})
+
+test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
+  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
+    expect_identical(category_filter, list("Definitive"))
+    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
+  }
+  env$check_duplicate_job <- function(operation, params) {
+    expect_true("category_filter" %in% names(params))
+    expect_identical(params$category_filter, "Definitive")
+    list(duplicate = FALSE)
+  }
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  env$async_job_active_count <- function(...) 0L
+  captured <- NULL
+  captured_hash_params <- NULL
+  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
+                                            submitted_by = NULL, ...) {
+    captured <<- request_payload
+    captured_hash_params <<- hash_payload
+    list(job = tibble::tibble(job_id = "j1"))
+  }
+  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
+  res <- job_endpoint_fake_res()
+
+  out <- env$svc_job_submit_functional_clustering(req, res)
+
+  expect_equal(res$status, 202)
+  expect_identical(captured$category_filter, "Definitive")
+  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
+  expect_identical(captured$provenance$selector$kind, "category")
+  expect_identical(captured$provenance$selector$category_filter, "Definitive")
+  expect_true(all(
+    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
+      names(captured$provenance)
+  ))
+
+  # Codex round-3 fix: a category run's hash payload keeps `category_filter`
+  # (selector-aware dedup) but still excludes `provenance`.
+  expect_true("category_filter" %in% names(captured_hash_params))
+  expect_identical(captured_hash_params$category_filter, "Definitive")
+  expect_false("provenance" %in% names(captured_hash_params))
+})
+
+test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
+  # Explicit genes.
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
+  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  env$async_job_active_count <- function(...) 0L
+  captured_explicit <- NULL
+  captured_explicit_hash_params <- NULL
+  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
+                                            submitted_by = NULL, ...) {
+    captured_explicit <<- request_payload
+    captured_explicit_hash_params <<- hash_payload
+    list(job = tibble::tibble(job_id = "j2"))
+  }
+  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
+  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
+
+  expect_false("category_filter" %in% names(captured_explicit))
+  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
+  expect_null(captured_explicit$provenance$selector$category_filter)
+  expect_false("provenance" %in% names(captured_explicit_hash_params))
+  expect_false("category_filter" %in% names(captured_explicit_hash_params))
+
+  # No-arg (all-NDD default).
+  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
+  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
+    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
+  ))
+  job_endpoint_stub_clustering_provenance(env2)
+  job_endpoint_stub_all_ndd_universe(env2)
+  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
+  env2$async_job_capacity_exceeded <- function(...) FALSE
+  env2$async_job_active_count <- function(...) 0L
+  captured_no_arg <- NULL
+  captured_no_arg_hash_params <- NULL
+  env2$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
+                                             submitted_by = NULL, ...) {
+    captured_no_arg <<- request_payload
+    captured_no_arg_hash_params <<- hash_payload
+    list(job = tibble::tibble(job_id = "j3"))
+  }
+  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
+  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
+
+  expect_false("category_filter" %in% names(captured_no_arg))
+  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
+  expect_null(captured_no_arg$provenance$selector$category_filter)
+  expect_false("provenance" %in% names(captured_no_arg_hash_params))
+  expect_false("category_filter" %in% names(captured_no_arg_hash_params))
+})
+
+test_that("functional clustering: two explicit submits with different provenance source_data_version produce the SAME hash_params (Codex round 3)", {
+  # The whole point of the fix: `source_data_version` (and the STRING cache
+  # fingerprint) are time-varying provenance fields, so two otherwise-
+  # identical submits observed at different moments (e.g. across a snapshot
+  # refresh / deploy) must resolve to the IDENTICAL dedup identity -- only the
+  # STORED payload (`provenance`) is allowed to differ.
+  submit_and_capture <- function(source_data_version) {
+    env <- job_endpoint_source_service("job-functional-submission-service.R")
+    env$pool <- job_endpoint_functional_pool(env)
+    env$analysis_string_cache_fingerprint <- function() "fp-test"
+    env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
+    env$clustering_cached_source_data_version <- function(...) source_data_version
+    env$check_duplicate_job <- function(...) list(duplicate = FALSE)
+    env$async_job_capacity_exceeded <- function(...) FALSE
+    env$async_job_active_count <- function(...) 0L
+    captured_hash_params <- NULL
+    captured_provenance <- NULL
+    env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
+                                              submitted_by = NULL, ...) {
+      captured_hash_params <<- hash_payload
+      captured_provenance <<- request_payload$provenance
+      list(job = tibble::tibble(job_id = "j-provenance"))
+    }
+    req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
+    env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
+    list(hash_params = captured_hash_params, provenance = captured_provenance)
+  }
+
+  run_a <- submit_and_capture("2026-01-01T00:00:00Z")
+  run_b <- submit_and_capture("2026-07-18T00:00:00Z")
+
+  # Different STORED provenance...
+  expect_false(identical(run_a$provenance$source_data_version, run_b$provenance$source_data_version))
+  # ...but IDENTICAL dedup hash payload (provenance excluded).
+  expect_identical(run_a$hash_params, run_b$hash_params)
+})
+
+test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
+  # `gene_list_sha256` hashes sort(unique(...)), so `resolved_gene_count` must
+  # be computed the same way -- otherwise a duplicate-gene payload
+  # (`["HGNC:1","HGNC:1"]`) reports resolved_gene_count=2 alongside a
+  # singleton sha256. The payload `genes` list itself must stay
+  # byte-identical to the raw request (never deduped) -- only the COUNT
+  # field changes.
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
+  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  env$async_job_active_count <- function(...) 0L
+  captured <- NULL
+  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
+                                            submitted_by = NULL, ...) {
+    captured <<- request_payload
+    list(job = tibble::tibble(job_id = "j-dup-genes"))
+  }
+  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
+  res <- job_endpoint_fake_res()
+
+  env$svc_job_submit_functional_clustering(req, res)
+
+  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
+  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
+})
+
+test_that("functional clustering: request_hash is selector-aware for category_filter", {
+  # Pure-function coverage of the underlying dedup identity: sourced directly
+  # (not via the service env) since these are free functions in
+  # functions/async-job-service.R, not bare globals the service references.
+  hash_env <- new.env(parent = globalenv())
+  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)
+
+  h <- function(genes, algo, cf) {
+    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
+    hash_env$async_job_service_request_hash(
+      "clustering",
+      hash_env$async_job_service_payload_json(payload)
+    )
+  }
+  g <- c("HGNC:1", "HGNC:5")
+
+  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
+  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
+  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
+})
+
+test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  env$analysis_string_cache_fingerprint <- function() "fp-test"
+  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
+  env$clustering_cached_source_data_version <- function(...) stop("boom")
+  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
+  submit_called <- FALSE
+  env$async_job_service_submit <- function(...) {
+    submit_called <<- TRUE
+    NULL
+  }
+  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
+  res <- job_endpoint_fake_res()
+
+  out <- env$svc_job_submit_functional_clustering(req, res)
+
+  expect_equal(res$status, 503L)
+  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
+  expect_false(submit_called)
+})
diff --git a/api/tests/testthat/test-unit-job-endpoint-services.R b/api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
similarity index 56%
copy from api/tests/testthat/test-unit-job-endpoint-services.R
copy to api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
index 3bb4b43f..e9e69f6b 100644
--- a/api/tests/testthat/test-unit-job-endpoint-services.R
+++ b/api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
@@ -1,269 +1,112 @@
-# tests/testthat/test-unit-job-endpoint-services.R
+# tests/testthat/test-unit-job-endpoint-services-phenotype.R
 #
-# Host-runnable unit tests for the PUBLIC clustering submission services extracted
-# from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
-# submission-service.R and job-phenotype-submission-service.R. The maintenance-
-# submission (job-maintenance-submission-service.R) and query-endpoint
-# (job-query-endpoint-service.R) services are covered in the sibling
-# test-unit-job-endpoint-services-maintenance.R. Shared fixtures live in
-# job-endpoint-services-fixtures.R (explicitly sourced below). Split this way to keep
-# every file under the 600-line ceiling (#535 S6).
+# Host-runnable unit tests for job-phenotype-submission-service.R, split out of
+# test-unit-job-endpoint-services.R (which covers job-functional-submission-service.R)
+# to keep both files under the 600-line ceiling (#535 S6) after the #574 Codex-review
+# fixes added coverage to the functional side. Shared fixtures live in
+# job-endpoint-services-fixtures.R (explicitly sourced below, mirroring the sibling
+# file). See test-unit-job-endpoint-services.R's header for the full split rationale
+# (maintenance-submission + query-endpoint services are covered in
+# test-unit-job-endpoint-services-maintenance.R).
 #
 # Each service is sourced directly into an isolated environment via sys.source()
 # (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
 # body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
-# async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
-# gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
-# exercise pure request/response logic without a live DB or mirai daemon pool.
+# async_job_active_count, async_job_service_store_completed, gen_mca_clust_obj_mem,
+# log_warn, ...) is stubbed in that environment, so the tests exercise pure
+# request/response logic without a live DB or mirai daemon pool.
 
 # Resolve api_dir robustly so the file runs both under the full suite and a single-file
 # testthat::test_file(), then source the shared fixtures.
 if (exists("get_api_dir")) {
   api_dir <- get_api_dir()
 } else {
   api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
   if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
     api_dir <- normalizePath(getwd(), mustWork = FALSE)
   }
 }
 # local = TRUE keeps the shared helpers in this test file's environment (as if defined
 # inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
 source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)
 
-## -------------------------------------------------------------------##
-## job-functional-submission-service.R
-## -------------------------------------------------------------------##
-
-job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
-  tables <- list(
-    non_alt_loci_set = tibble::tibble(
-      symbol = c("A", "B"),
-      hgnc_id = c("HGNC:1", "HGNC:3"),
-      STRING_id = c("9606.P1", "9606.P2")
-    )
-  )
-  if (!is.null(ndd_entity_view)) {
-    tables$ndd_entity_view <- ndd_entity_view
-  }
-  job_endpoint_fake_pool(env, tables)
-}
-
-test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
-  env <- job_endpoint_source_service("job-functional-submission-service.R")
-  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
-    entity_id = 1:3,
-    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
-    ndd_phenotype = c(1L, 0L, 1L)
-  ))
-  captured <- NULL
-  env$check_duplicate_job <- function(operation, params) {
-    captured <<- params
-    list(duplicate = TRUE, existing_job_id = "dup-1")
-  }
-  req <- list(argsBody = list(), user = list(user_id = NULL))
-  res <- job_endpoint_fake_res()
-
-  out <- env$svc_job_submit_functional_clustering(req, res)
-
-  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
-  expect_equal(captured$algorithm, "leiden")
-  expect_equal(res$status, 409)
-  expect_equal(out$error, "DUPLICATE_JOB")
-  expect_match(res$headers[["Location"]], "/api/jobs/dup-1/status")
-})
-
-job_endpoint_capture_functional_algorithm <- function(algorithm_body) {
-  env <- job_endpoint_source_service("job-functional-submission-service.R")
-  env$pool <- job_endpoint_functional_pool(env)
-  captured <- NULL
-  env$check_duplicate_job <- function(operation, params) {
-    captured <<- params
-    list(duplicate = TRUE, existing_job_id = "dup-1")
-  }
-  req <- list(argsBody = list(genes = list("HGNC:9"), algorithm = algorithm_body), user = list(user_id = NULL))
-  env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
-  captured$algorithm
-}
-
-test_that("functional clustering: algorithm input is coerced to a lowercase scalar, invalid falls back to leiden", {
-  expect_equal(job_endpoint_capture_functional_algorithm(list("WALKTRAP", "ignored")), "walktrap")
-  expect_equal(job_endpoint_capture_functional_algorithm("bogus"), "leiden")
-})
-
-test_that("functional clustering: cache hit stores a completed job without calling create_job", {
-  local_mocked_bindings(
-    has_cache = function(f) function(...) TRUE,
-    .package = "memoise"
-  )
-  env <- job_endpoint_source_service("job-functional-submission-service.R")
-  env$pool <- job_endpoint_functional_pool(env)
-  env$gen_string_clust_obj_mem <- function(genes, algorithm = "leiden") {
-    tibble::tibble(term_enrichment = list(tibble::tibble(category = "HPO")))
-  }
-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
-  store_args <- NULL
-  env$async_job_service_store_completed <- function(...) {
-    store_args <<- list(...)
-    tibble::tibble(job_id = "cached-job-1")
-  }
-  create_job_called <- FALSE
-  env$create_job <- function(...) {
-    create_job_called <<- TRUE
-  }
-  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = 42L))
-  res <- job_endpoint_fake_res()
-
-  out <- env$svc_job_submit_functional_clustering(req, res)
-
-  expect_false(create_job_called)
-  expect_equal(res$status, 202)
-  expect_equal(res$headers[["Retry-After"]], "0")
-  expect_equal(out$job_id, "cached-job-1")
-  expect_equal(out$meta$llm_generation, "snapshot_refresh_owned")
-  expect_equal(store_args$submitted_by, 42L)
-})
-
-test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
-  req <- list(argsBody = list(genes = list("HGNC:1"), algorithm = "walktrap"), user = list(user_id = NULL))
-
-  env <- job_endpoint_source_service("job-functional-submission-service.R")
-  env$pool <- job_endpoint_functional_pool(env)
-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
-  env$async_job_capacity_exceeded <- function(...) TRUE
-  env$async_job_active_count <- function(...) 99L
-  res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_functional_clustering(req, res)
-  expect_equal(res$status, 503)
-  expect_equal(res$headers[["Retry-After"]], "60")
-  expect_equal(out$error, "CAPACITY_EXCEEDED")
-
-  env$async_job_capacity_exceeded <- function(...) FALSE
-  create_job_operation <- NULL
-  create_job_params <- NULL
-  env$create_job <- function(operation, params) {
-    create_job_operation <<- operation
-    create_job_params <<- params
-    list(job_id = "new-job-1", status = "accepted", estimated_seconds = 30)
-  }
-  res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_functional_clustering(req, res)
-  expect_equal(res$status, 202)
-  expect_equal(res$headers[["Retry-After"]], "5")
-  expect_equal(out$job_id, "new-job-1")
-  expect_equal(create_job_operation, "clustering")
-  expect_setequal(
-    names(create_job_params),
-    c("genes", "algorithm", "category_links", "string_id_table")
-  )
-})
-
-test_that("functional clustering: admission throttle runs FIRST, before any DB/cache work", {
-  # #535 S6 BLOCKER fix: a throttle block must short-circuit before the cache/dup/DB
-  # path so an abusive caller cannot bypass the limit or grow async_jobs via cache
-  # hits. The guard returning admitted=FALSE must return its response and touch nothing.
-  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = NULL))
-  env <- job_endpoint_source_service("job-functional-submission-service.R")
-  pool_touched <- FALSE
-  env$pool <- structure(list(), class = "trap_pool")
-  env$tbl.trap_pool <- function(src, from, ...) {
-    pool_touched <<- TRUE
-    stop("DB must not be touched when the throttle blocks")
-  }
-  create_job_called <- FALSE
-  env$create_job <- function(...) {
-    create_job_called <<- TRUE
-    NULL
-  }
-  env$async_job_submit_admission_guard <- function(req, res) {
-    res$status <- 429
-    res$setHeader("Retry-After", "42")
-    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
-  }
-  res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_functional_clustering(req, res)
-  expect_equal(res$status, 429)
-  expect_equal(out$error, "RATE_LIMITED")
-  expect_false(pool_touched)
-  expect_false(create_job_called)
-})
-
 ## -------------------------------------------------------------------##
 ## job-phenotype-submission-service.R
 ## -------------------------------------------------------------------##
 
 job_endpoint_phenotype_single_entity_pool <- function(env) {
   job_endpoint_fake_pool(env, list(
     ndd_entity_view = tibble::tibble(
       entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1",
       ndd_phenotype = 1L, category = "Definitive"
     ),
     ndd_entity_review = tibble::tibble(
       review_id = 1L, entity_id = 1L, is_primary = 1L, review_approved = 1L
     ),
     ndd_review_phenotype_connect = tibble::tibble(
       review_id = 1L, entity_id = 1L, modifier_id = 1L,
       phenotype_id = "HP:0000001", hpo_mode_of_inheritance_term_name = "AD"
     ),
     modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
     phenotype_list = tibble::tibble(phenotype_id = "HP:0000001", HPO_term = "Term1")
   ))
 }
 
 test_that("phenotype clustering: review set is gated on is_primary AND review_approved", {
   env <- job_endpoint_source_service("job-phenotype-submission-service.R")
   env$pool <- job_endpoint_fake_pool(env, list(
     ndd_entity_view = tibble::tibble(
       entity_id = c(1L, 2L), hgnc_id = c("HGNC:1", "HGNC:2"), symbol = c("GENE1", "GENE2"),
       ndd_phenotype = c(1L, 1L), category = c("Definitive", "Definitive")
     ),
     # review_id 1: primary + approved (kept). review_id 2: primary but NOT
     # approved (must be dropped). review_id 3: approved but NOT primary
     # (must be dropped) — the #3/Codex-PR-2 guard this test protects.
     ndd_entity_review = tibble::tibble(
       review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L),
       is_primary = c(1L, 1L, 0L), review_approved = c(1L, 0L, 1L)
     ),
     ndd_review_phenotype_connect = tibble::tibble(
       review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L), modifier_id = c(1L, 1L, 1L),
       phenotype_id = c("HP:0000001", "HP:0000002", "HP:0000001"),
       hpo_mode_of_inheritance_term_name = c("AD", "AD", "AD")
     ),
     modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
     phenotype_list = tibble::tibble(
       phenotype_id = c("HP:0000001", "HP:0000002"), HPO_term = c("Term1", "Term2")
     )
   ))
   env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   env$async_job_capacity_exceeded <- function(...) FALSE
   env$async_job_active_count <- function(...) 0L
   captured_params <- NULL
   env$create_job <- function(operation, params) {
     captured_params <<- params
     list(job_id = "job-x", status = "accepted", estimated_seconds = 30)
   }
   req <- list(user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
 
   env$svc_job_submit_phenotype_clustering(req, res)
 
   # Only review_id 1 (primary + approved) survives the gather step; review 2
   # (unapproved) and review 3 (not primary) must never reach the clustering
   # input, even though review 2 is attached to the same (otherwise-included)
   # entity_id as review 1.
   expect_equal(captured_params$ndd_entity_review_tbl$review_id, 1L)
 })
 
 test_that("phenotype clustering: duplicate job returns 409 with Location", {
   env <- job_endpoint_source_service("job-phenotype-submission-service.R")
   env$pool <- job_endpoint_phenotype_single_entity_pool(env)
   env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = "dup-pheno")
   req <- list(user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
 
   out <- env$svc_job_submit_phenotype_clustering(req, res)
 
   expect_equal(res$status, 409)
   expect_equal(out$error, "DUPLICATE_JOB")
   expect_match(res$headers[["Location"]], "/api/jobs/dup-pheno/status")
 })
 
diff --git a/api/tests/testthat/test-unit-job-endpoint-services.R b/api/tests/testthat/test-unit-job-endpoint-services.R
index 3bb4b43f..944d1c5b 100644
--- a/api/tests/testthat/test-unit-job-endpoint-services.R
+++ b/api/tests/testthat/test-unit-job-endpoint-services.R
@@ -1,380 +1,237 @@
 # tests/testthat/test-unit-job-endpoint-services.R
 #
-# Host-runnable unit tests for the PUBLIC clustering submission services extracted
+# Host-runnable unit tests for the PUBLIC clustering submission service extracted
 # from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
-# submission-service.R and job-phenotype-submission-service.R. The maintenance-
-# submission (job-maintenance-submission-service.R) and query-endpoint
-# (job-query-endpoint-service.R) services are covered in the sibling
+# submission-service.R (base coverage only). Its category_filter / provenance /
+# dedup-hash-payload coverage (#574 D2) was split out to
+# test-unit-job-endpoint-services-category.R to keep both files under the
+# 600-line ceiling after the #574 Codex-review-fix rounds grew that coverage.
+# The sibling job-phenotype-submission-service.R coverage lives in
+# test-unit-job-endpoint-services-phenotype.R (split out here, #574
+# Codex-review-fix pass, to keep both files under the 600-line ceiling after this
+# file gained empty-genes/dedup-provenance coverage). The maintenance-submission
+# (job-maintenance-submission-service.R) and query-endpoint
+# (job-query-endpoint-service.R) services are covered in
 # test-unit-job-endpoint-services-maintenance.R. Shared fixtures live in
-# job-endpoint-services-fixtures.R (explicitly sourced below). Split this way to keep
-# every file under the 600-line ceiling (#535 S6).
+# job-endpoint-services-fixtures.R (explicitly sourced below by every file in this
+# family). Split this way to keep every file under the 600-line ceiling (#535 S6).
 #
 # Each service is sourced directly into an isolated environment via sys.source()
 # (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
 # body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
 # async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
 # gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
 # exercise pure request/response logic without a live DB or mirai daemon pool.
 
 # Resolve api_dir robustly so the file runs both under the full suite and a single-file
 # testthat::test_file(), then source the shared fixtures.
 if (exists("get_api_dir")) {
   api_dir <- get_api_dir()
 } else {
   api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
   if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
     api_dir <- normalizePath(getwd(), mustWork = FALSE)
   }
 }
 # local = TRUE keeps the shared helpers in this test file's environment (as if defined
 # inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
 source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)
 
 ## -------------------------------------------------------------------##
 ## job-functional-submission-service.R
 ## -------------------------------------------------------------------##
 
-job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
-  tables <- list(
-    non_alt_loci_set = tibble::tibble(
-      symbol = c("A", "B"),
-      hgnc_id = c("HGNC:1", "HGNC:3"),
-      STRING_id = c("9606.P1", "9606.P2")
-    )
-  )
-  if (!is.null(ndd_entity_view)) {
-    tables$ndd_entity_view <- ndd_entity_view
-  }
-  job_endpoint_fake_pool(env, tables)
-}
-
 test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
   env <- job_endpoint_source_service("job-functional-submission-service.R")
   env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
     entity_id = 1:3,
     hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
     ndd_phenotype = c(1L, 0L, 1L)
   ))
+  job_endpoint_stub_all_ndd_universe(env)
   captured <- NULL
   env$check_duplicate_job <- function(operation, params) {
     captured <<- params
     list(duplicate = TRUE, existing_job_id = "dup-1")
   }
   req <- list(argsBody = list(), user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
 
   out <- env$svc_job_submit_functional_clustering(req, res)
 
   expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   expect_equal(captured$algorithm, "leiden")
   expect_equal(res$status, 409)
   expect_equal(out$error, "DUPLICATE_JOB")
   expect_match(res$headers[["Location"]], "/api/jobs/dup-1/status")
 })
 
 job_endpoint_capture_functional_algorithm <- function(algorithm_body) {
   env <- job_endpoint_source_service("job-functional-submission-service.R")
   env$pool <- job_endpoint_functional_pool(env)
   captured <- NULL
   env$check_duplicate_job <- function(operation, params) {
     captured <<- params
     list(duplicate = TRUE, existing_job_id = "dup-1")
   }
   req <- list(argsBody = list(genes = list("HGNC:9"), algorithm = algorithm_body), user = list(user_id = NULL))
   env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
   captured$algorithm
 }
 
 test_that("functional clustering: algorithm input is coerced to a lowercase scalar, invalid falls back to leiden", {
   expect_equal(job_endpoint_capture_functional_algorithm(list("WALKTRAP", "ignored")), "walktrap")
   expect_equal(job_endpoint_capture_functional_algorithm("bogus"), "leiden")
 })
 
 test_that("functional clustering: cache hit stores a completed job without calling create_job", {
   local_mocked_bindings(
     has_cache = function(f) function(...) TRUE,
     .package = "memoise"
   )
   env <- job_endpoint_source_service("job-functional-submission-service.R")
   env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
   env$gen_string_clust_obj_mem <- function(genes, algorithm = "leiden") {
-    tibble::tibble(term_enrichment = list(tibble::tibble(category = "HPO")))
+    clusters <- tibble::tibble(term_enrichment = list(tibble::tibble(category = "HPO")))
+    # Set on the served membership, mirroring what the real STRING resolver
+    # attaches (#514 channel observability) -- the cache-hit meta must carry
+    # this through as `effective_fingerprint$weight_channel`.
+    attr(clusters, "weight_channel") <- "experimental_database"
+    clusters
   }
   env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   store_args <- NULL
   env$async_job_service_store_completed <- function(...) {
     store_args <<- list(...)
     tibble::tibble(job_id = "cached-job-1")
   }
   create_job_called <- FALSE
   env$create_job <- function(...) {
     create_job_called <<- TRUE
   }
   req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = 42L))
   res <- job_endpoint_fake_res()
 
   out <- env$svc_job_submit_functional_clustering(req, res)
 
   expect_false(create_job_called)
   expect_equal(res$status, 202)
   expect_equal(res$headers[["Retry-After"]], "0")
   expect_equal(out$job_id, "cached-job-1")
   expect_equal(out$meta$llm_generation, "snapshot_refresh_owned")
   expect_equal(store_args$submitted_by, 42L)
+
+  # #574 D2 review fix: the cache-hit `result` (the job's stored, served
+  # payload -- distinct from `out`, the submit response) must carry the full
+  # provenance block through `meta`, not just the two fields asserted above.
+  result_meta <- store_args$result$meta
+  expect_equal(result_meta$effective_fingerprint$weight_channel, "experimental_database")
+  expect_equal(result_meta$selector$kind, "explicit")
+  expect_equal(result_meta$gene_list_sha256, "sha-1") # job_endpoint_stub_clustering_provenance: paste0("sha-", length(genes))
+  expect_equal(result_meta$source_data_version, "srcv-test") # job_endpoint_stub_clustering_provenance stub token
+
+  # Codex round-3 fix: the cache-hit path also derives a provenance-free
+  # `hash_payload` for the dedup identity, while `request_payload` (asserted
+  # above via `result_meta`) keeps `provenance` in the STORED payload.
+  expect_true("provenance" %in% names(store_args$request_payload))
+  expect_false("provenance" %in% names(store_args$hash_payload))
+  expect_false("category_filter" %in% names(store_args$hash_payload))
 })
 
 test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
   req <- list(argsBody = list(genes = list("HGNC:1"), algorithm = "walktrap"), user = list(user_id = NULL))
 
   env <- job_endpoint_source_service("job-functional-submission-service.R")
   env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
   env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   env$async_job_capacity_exceeded <- function(...) TRUE
   env$async_job_active_count <- function(...) 99L
   res <- job_endpoint_fake_res()
   out <- env$svc_job_submit_functional_clustering(req, res)
   expect_equal(res$status, 503)
   expect_equal(res$headers[["Retry-After"]], "60")
   expect_equal(out$error, "CAPACITY_EXCEEDED")
 
   env$async_job_capacity_exceeded <- function(...) FALSE
-  create_job_operation <- NULL
-  create_job_params <- NULL
-  env$create_job <- function(operation, params) {
-    create_job_operation <<- operation
-    create_job_params <<- params
-    list(job_id = "new-job-1", status = "accepted", estimated_seconds = 30)
+  captured <- NULL
+  # Cache-miss path calls `async_job_service_submit()` directly (not
+  # `create_job()`, which is arity-guarded at exactly `(operation, params)`)
+  # so it can thread a provenance-free `hash_payload` override alongside the
+  # full `request_payload`.
+  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
+                                            submitted_by = NULL, ...) {
+    captured <<- list(
+      job_type = job_type,
+      request_payload = request_payload,
+      hash_payload = hash_payload
+    )
+    list(job = tibble::tibble(job_id = "new-job-1"))
   }
   res <- job_endpoint_fake_res()
   out <- env$svc_job_submit_functional_clustering(req, res)
   expect_equal(res$status, 202)
   expect_equal(res$headers[["Retry-After"]], "5")
   expect_equal(out$job_id, "new-job-1")
-  expect_equal(create_job_operation, "clustering")
+  expect_equal(captured$job_type, "clustering")
   expect_setequal(
-    names(create_job_params),
-    c("genes", "algorithm", "category_links", "string_id_table")
+    names(captured$request_payload),
+    # #574 D2: every submit path now carries a `provenance` block; explicit/
+    # no-arg submits still omit `category_filter` (asserted separately below).
+    c("genes", "algorithm", "category_links", "string_id_table", "provenance")
+  )
+  expect_false("category_filter" %in% names(captured$request_payload))
+
+  # Codex round-3 fix: the dedup HASH payload must exclude `provenance` (and
+  # any absent `category_filter`) so the dedup identity stays byte-identical
+  # to pre-#574, even though the STORED request payload
+  # (`captured$request_payload`, asserted above) still carries `provenance`.
+  expect_false("provenance" %in% names(captured$hash_payload))
+  expect_false("category_filter" %in% names(captured$hash_payload))
+  expect_identical(
+    captured$hash_payload,
+    list(
+      genes = captured$request_payload$genes,
+      algorithm = captured$request_payload$algorithm,
+      category_links = captured$request_payload$category_links,
+      string_id_table = captured$request_payload$string_id_table
+    )
   )
 })
 
 test_that("functional clustering: admission throttle runs FIRST, before any DB/cache work", {
   # #535 S6 BLOCKER fix: a throttle block must short-circuit before the cache/dup/DB
   # path so an abusive caller cannot bypass the limit or grow async_jobs via cache
   # hits. The guard returning admitted=FALSE must return its response and touch nothing.
   req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = NULL))
   env <- job_endpoint_source_service("job-functional-submission-service.R")
   pool_touched <- FALSE
   env$pool <- structure(list(), class = "trap_pool")
   env$tbl.trap_pool <- function(src, from, ...) {
     pool_touched <<- TRUE
     stop("DB must not be touched when the throttle blocks")
   }
-  create_job_called <- FALSE
-  env$create_job <- function(...) {
-    create_job_called <<- TRUE
+  submit_called <- FALSE
+  env$async_job_service_submit <- function(...) {
+    submit_called <<- TRUE
     NULL
   }
   env$async_job_submit_admission_guard <- function(req, res) {
     res$status <- 429
     res$setHeader("Retry-After", "42")
     list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
   }
   res <- job_endpoint_fake_res()
   out <- env$svc_job_submit_functional_clustering(req, res)
   expect_equal(res$status, 429)
   expect_equal(out$error, "RATE_LIMITED")
   expect_false(pool_touched)
-  expect_false(create_job_called)
-})
-
-## -------------------------------------------------------------------##
-## job-phenotype-submission-service.R
-## -------------------------------------------------------------------##
-
-job_endpoint_phenotype_single_entity_pool <- function(env) {
-  job_endpoint_fake_pool(env, list(
-    ndd_entity_view = tibble::tibble(
-      entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1",
-      ndd_phenotype = 1L, category = "Definitive"
-    ),
-    ndd_entity_review = tibble::tibble(
-      review_id = 1L, entity_id = 1L, is_primary = 1L, review_approved = 1L
-    ),
-    ndd_review_phenotype_connect = tibble::tibble(
-      review_id = 1L, entity_id = 1L, modifier_id = 1L,
-      phenotype_id = "HP:0000001", hpo_mode_of_inheritance_term_name = "AD"
-    ),
-    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
-    phenotype_list = tibble::tibble(phenotype_id = "HP:0000001", HPO_term = "Term1")
-  ))
-}
-
-test_that("phenotype clustering: review set is gated on is_primary AND review_approved", {
-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
-  env$pool <- job_endpoint_fake_pool(env, list(
-    ndd_entity_view = tibble::tibble(
-      entity_id = c(1L, 2L), hgnc_id = c("HGNC:1", "HGNC:2"), symbol = c("GENE1", "GENE2"),
-      ndd_phenotype = c(1L, 1L), category = c("Definitive", "Definitive")
-    ),
-    # review_id 1: primary + approved (kept). review_id 2: primary but NOT
-    # approved (must be dropped). review_id 3: approved but NOT primary
-    # (must be dropped) — the #3/Codex-PR-2 guard this test protects.
-    ndd_entity_review = tibble::tibble(
-      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L),
-      is_primary = c(1L, 1L, 0L), review_approved = c(1L, 0L, 1L)
-    ),
-    ndd_review_phenotype_connect = tibble::tibble(
-      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L), modifier_id = c(1L, 1L, 1L),
-      phenotype_id = c("HP:0000001", "HP:0000002", "HP:0000001"),
-      hpo_mode_of_inheritance_term_name = c("AD", "AD", "AD")
-    ),
-    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
-    phenotype_list = tibble::tibble(
-      phenotype_id = c("HP:0000001", "HP:0000002"), HPO_term = c("Term1", "Term2")
-    )
-  ))
-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
-  env$async_job_capacity_exceeded <- function(...) FALSE
-  env$async_job_active_count <- function(...) 0L
-  captured_params <- NULL
-  env$create_job <- function(operation, params) {
-    captured_params <<- params
-    list(job_id = "job-x", status = "accepted", estimated_seconds = 30)
-  }
-  req <- list(user = list(user_id = NULL))
-  res <- job_endpoint_fake_res()
-
-  env$svc_job_submit_phenotype_clustering(req, res)
-
-  # Only review_id 1 (primary + approved) survives the gather step; review 2
-  # (unapproved) and review 3 (not primary) must never reach the clustering
-  # input, even though review 2 is attached to the same (otherwise-included)
-  # entity_id as review 1.
-  expect_equal(captured_params$ndd_entity_review_tbl$review_id, 1L)
-})
-
-test_that("phenotype clustering: duplicate job returns 409 with Location", {
-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
-  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
-  env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = "dup-pheno")
-  req <- list(user = list(user_id = NULL))
-  res <- job_endpoint_fake_res()
-
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
-
-  expect_equal(res$status, 409)
-  expect_equal(out$error, "DUPLICATE_JOB")
-  expect_match(res$headers[["Location"]], "/api/jobs/dup-pheno/status")
-})
-
-test_that("phenotype clustering: cache hit stores a completed job without calling create_job", {
-  local_mocked_bindings(
-    has_cache = function(f) function(...) TRUE,
-    .package = "memoise"
-  )
-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
-  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
-  env$gen_mca_clust_obj_mem <- function(df) {
-    tibble::tibble(cluster = 1L, identifiers = list(tibble::tibble(entity_id = "1")))
-  }
-  store_args <- NULL
-  env$async_job_service_store_completed <- function(...) {
-    store_args <<- list(...)
-    tibble::tibble(job_id = "cached-pheno-1")
-  }
-  create_job_called <- FALSE
-  env$create_job <- function(...) create_job_called <<- TRUE
-  req <- list(user = list(user_id = 7L))
-  res <- job_endpoint_fake_res()
-
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
-
-  expect_false(create_job_called)
-  expect_equal(res$status, 202)
-  expect_equal(out$job_id, "cached-pheno-1")
-  expect_equal(store_args$submitted_by, 7L)
+  expect_false(submit_called)
 })
 
-test_that("phenotype clustering: capacity guard (503) then a cache miss under capacity (202)", {
-  req <- list(user = list(user_id = NULL))
-
-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
-  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
-  env$async_job_capacity_exceeded <- function(...) TRUE
-  env$async_job_active_count <- function(...) 5L
-  res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
-  expect_equal(res$status, 503)
-  expect_equal(res$headers[["Retry-After"]], "60")
-  expect_equal(out$error, "CAPACITY_EXCEEDED")
-
-  env$async_job_capacity_exceeded <- function(...) FALSE
-  create_job_params <- NULL
-  env$create_job <- function(operation, params) {
-    create_job_params <<- params
-    list(job_id = "new-pheno-1", status = "accepted", estimated_seconds = 30)
-  }
-  res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
-  expect_equal(res$status, 202)
-  expect_equal(res$headers[["Retry-After"]], "5")
-  expect_equal(out$job_id, "new-pheno-1")
-  # estimated_seconds is hardcoded to 60 for the new-submit response (matches
-  # the original handler, which does not thread through create_job's value).
-  expect_equal(out$estimated_seconds, 60)
-  expect_setequal(
-    names(create_job_params),
-    c(
-      "ndd_entity_view_tbl", "ndd_entity_review_tbl",
-      "ndd_review_phenotype_connect_tbl", "modifier_list_tbl",
-      "phenotype_list_tbl", "id_phenotype_ids", "categories"
-    )
-  )
-})
-
-test_that("phenotype clustering service source keeps is_primary filters paired with review_approved", {
-  # Defense-in-depth mirror of test-unit-phenotype-clustering-approved-guard.R
-  # (which scans endpoints/jobs_endpoints.R) now that the logic lives here.
-  src <- readLines(file.path(get_api_dir(), "services", "job-phenotype-submission-service.R"), warn = FALSE)
-  body <- paste(src, collapse = "\n")
-  matches <- gregexpr("filter\\([^)]*is_primary[^)]*\\)", body)[[1]]
-  if (matches[1] != -1) {
-    lens <- attr(matches, "match.length")
-    for (i in seq_along(matches)) {
-      frag <- substr(body, matches[i], matches[i] + lens[i] - 1)
-      expect_true(grepl("review_approved", frag),
-                  info = paste("is_primary filter without review_approved:", frag))
-    }
-  }
-  succeed()
-})
-
-test_that("phenotype clustering: admission throttle runs FIRST, before collecting tables", {
-  # #535 S6 BLOCKER fix: the phenotype path otherwise collects five whole tables and
-  # builds the MCA matrix before admission. A blocked caller must touch nothing.
-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
-  pool_touched <- FALSE
-  env$pool <- structure(list(), class = "trap_pool")
-  env$tbl.trap_pool <- function(src, from, ...) {
-    pool_touched <<- TRUE
-    stop("DB must not be touched when the throttle blocks")
-  }
-  create_job_called <- FALSE
-  env$create_job <- function(...) {
-    create_job_called <<- TRUE
-    NULL
-  }
-  env$async_job_submit_admission_guard <- function(req, res) {
-    res$status <- 429
-    res$setHeader("Retry-After", "42")
-    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
-  }
-  res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_phenotype_clustering(list(user = list(user_id = NULL)), res)
-  expect_equal(res$status, 429)
-  expect_equal(out$error, "RATE_LIMITED")
-  expect_false(pool_touched)
-  expect_false(create_job_called)
-})
+# job-functional-submission-service.R's category_filter / provenance / dedup
+# coverage (#574 D2) lives in test-unit-job-endpoint-services-category.R, and
+# job-phenotype-submission-service.R coverage lives in
+# test-unit-job-endpoint-services-phenotype.R (both split out to keep this
+# file under the 600-line ceiling, #574 Codex-review-fix pass).
diff --git a/api/version_spec.json b/api/version_spec.json
index 86e2b6e6..5efd7ddc 100644
--- a/api/version_spec.json
+++ b/api/version_spec.json
@@ -1,14 +1,14 @@
 {
   "title": "SysNDD API",
   "description": "This is the API powering the SysNDD website, allowing programmatic access to the database contents.",
-  "version": "0.30.0",
+  "version": "0.30.1",
   "contact": {
     "name": "API Support",
     "url": "https://berntpopp.github.io/sysndd/api.html",
     "email": "support@sysndd.org"
   },
   "license": {
     "name": "CC BY 4.0",
     "url": "https://creativecommons.org/licenses/by/4.0/"
   }
 }
diff --git a/app/package-lock.json b/app/package-lock.json
index bcc638de..73e3f535 100644
--- a/app/package-lock.json
+++ b/app/package-lock.json
@@ -1,89 +1,89 @@
 {
   "name": "sysndd",
-  "version": "0.30.0",
+  "version": "0.30.1",
   "lockfileVersion": 3,
   "requires": true,
   "packages": {
     "": {
       "name": "sysndd",
-      "version": "0.30.0",
+      "version": "0.30.1",
       "dependencies": {
         "@popperjs/core": "^2.11.8",
         "@unhead/vue": "^3.1.8",
         "@upsetjs/bundle": "^1.11.0",
         "@vee-validate/rules": "^4.15.1",
         "@vueuse/core": "^14.3.0",
         "bootstrap": "^5.3.8",
         "bootstrap-icons": "^1.13.1",
         "bootstrap-vue-next": "^0.45.8",
         "chart.js": "^4.5.1",
         "cytoscape": "^3.34.0",
         "cytoscape-fcose": "^2.2.0",
         "cytoscape-svg": "^0.4.0",
         "d3": "^7.4.2",
         "date-fns": "^4.4.0",
         "dompurify": "^3.4.12",
         "exceljs": "^4.4.0",
         "file-saver": "^2.0.5",
         "gsap": "^3.15.0",
         "html2canvas": "^1.4.1",
         "markdown-it": "^14.3.0",
         "ngl": "^2.4.0",
         "pinia": "^3.0.4",
         "splitpanes": "^4.1.2",
         "swagger-ui": "^5.32.8",
         "swagger-ui-dist": "^5.32.8",
         "vee-validate": "^4.15.1",
         "vue": "^3.5.39",
         "vue-chartjs": "^5.3.4",
         "vue-dompurify-html": "^5.3.0",
         "vue-router": "^5.1.0",
         "vuedraggable": "^4.1.0"
       },
       "devDependencies": {
         "@axe-core/playwright": "^4.12.1",
         "@eslint/js": "^9.39.2",
         "@playwright/test": "^1.61.1",
         "@testing-library/dom": "^10.4.1",
         "@testing-library/user-event": "^14.6.1",
         "@testing-library/vue": "^8.1.0",
         "@types/cytoscape": "^3.31.0",
         "@types/d3": "^7.4.3",
         "@types/dompurify": "^3.2.0",
         "@types/markdown-it": "^14.1.2",
         "@types/node": "^26.1.1",
         "@vitejs/plugin-vue": "^6.0.7",
         "@vitest/coverage-v8": "^4.1.10",
         "@vitest/ui": "^4.0.18",
         "@vue/compiler-sfc": "^3.5.39",
         "@vue/test-utils": "^2.4.11",
         "@vue/tsconfig": "^0.9.0",
         "axios": "^1.18.1",
         "cssnano": "^8.0.2",
         "eslint": "^10.7.0",
         "eslint-config-prettier": "^10.1.8",
         "eslint-plugin-vue": "^10.9.2",
         "globals": "^17.7.0",
         "husky": "^9.1.7",
         "jsdom": "^29.1.1",
         "lint-staged": "^17.0.8",
         "msw": "^2.15.0",
         "postcss": "^8.5.19",
         "prettier": "^3.9.5",
         "rollup-plugin-visualizer": "^7.0.1",
         "sass": "^1.101.0",
         "typescript": "^6.0.3",
         "typescript-eslint": "^8.63.0",
         "vite": "^7.3.6",
         "vite-plugin-pwa": "^1.3.0",
         "vitest": "^4.0.18",
         "vitest-axe": "^0.1.0",
         "vue-eslint-parser": "^10.4.1",
         "vue-tsc": "^3.3.7",
         "workbox-window": "^7.4.1"
       }
     },
     "node_modules/@asamuzakjp/css-color": {
       "version": "5.1.11",
       "resolved": "https://registry.npmjs.org/@asamuzakjp/css-color/-/css-color-5.1.11.tgz",
       "integrity": "sha512-KVw6qIiCTUQhByfTd78h2yD1/00waTmm9uy/R7Ck/ctUyAPj+AEDLkQIdJW0T8+qGgj3j5bpNKK7Q3G+LedJWg==",
diff --git a/app/package.json b/app/package.json
index ea8dbd91..5004dbe1 100644
--- a/app/package.json
+++ b/app/package.json
@@ -1,83 +1,83 @@
 {
   "name": "sysndd",
-  "version": "0.30.0",
+  "version": "0.30.1",
   "private": true,
   "type": "module",
   "scripts": {
     "dev": "vite",
     "build": "vue-tsc --noEmit && vite build",
     "preview": "vite preview",
     "dev:docker": "vite --mode docker",
     "build:docker": "vite build --mode docker",
     "build:production": "vite build --mode production",
     "test:route-bundle-budget": "node --test scripts/verify-route-bundle-budget.test.mjs",
     "verify:route-bundle-budget": "node scripts/verify-route-bundle-budget.mjs",
     "build:bundle-budget": "npm run test:route-bundle-budget && BUNDLE_BUDGET=true npm run build:production && npm run verify:route-bundle-budget",
     "seo:generate:fixture": "node scripts/generate-seo-pages.mjs --fixture scripts/fixtures/seo --out dist --base-url https://sysndd.dbmr.unibe.ch",
     "seo:generate": "node scripts/generate-seo-pages.mjs --out dist",
     "seo:verify": "node scripts/verify-seo-build.mjs dist",
     "build:seo": "npm run build:production && npm run seo:generate:fixture",
     "type-check": "vue-tsc --noEmit",
     "type-check:strict": "node scripts/type-check-strict.js",
     "lint": "eslint . --ext .vue,.js,.ts,.tsx",
     "lint:fix": "eslint . --ext .vue,.js,.ts,.tsx --fix",
     "format": "prettier --write \"src/**/*.{js,ts,vue,json,css,scss}\"",
     "format:check": "prettier --check \"src/**/*.{js,ts,vue,json,css,scss}\"",
     "prepare": "husky",
     "test:unit": "vitest run",
     "test:watch": "vitest watch",
     "test:ui": "vitest --ui",
     "test:coverage": "vitest run --coverage",
     "test:e2e": "playwright test",
     "test:e2e:ui": "playwright test --ui",
     "test:e2e:codegen": "playwright codegen http://localhost:5173",
     "docs:screenshots": "playwright test --config=playwright.docs-screenshots.config.ts"
   },
   "dependencies": {
     "@popperjs/core": "^2.11.8",
     "@unhead/vue": "^3.1.8",
     "@upsetjs/bundle": "^1.11.0",
     "@vee-validate/rules": "^4.15.1",
     "@vueuse/core": "^14.3.0",
     "bootstrap": "^5.3.8",
     "bootstrap-icons": "^1.13.1",
     "bootstrap-vue-next": "^0.45.8",
     "chart.js": "^4.5.1",
     "cytoscape": "^3.34.0",
     "cytoscape-fcose": "^2.2.0",
     "cytoscape-svg": "^0.4.0",
     "d3": "^7.4.2",
     "date-fns": "^4.4.0",
     "dompurify": "^3.4.12",
     "exceljs": "^4.4.0",
     "file-saver": "^2.0.5",
     "gsap": "^3.15.0",
     "html2canvas": "^1.4.1",
     "markdown-it": "^14.3.0",
     "ngl": "^2.4.0",
     "pinia": "^3.0.4",
     "splitpanes": "^4.1.2",
     "swagger-ui": "^5.32.8",
     "swagger-ui-dist": "^5.32.8",
     "vee-validate": "^4.15.1",
     "vue": "^3.5.39",
     "vue-chartjs": "^5.3.4",
     "vue-dompurify-html": "^5.3.0",
     "vue-router": "^5.1.0",
     "vuedraggable": "^4.1.0"
   },
   "devDependencies": {
     "@axe-core/playwright": "^4.12.1",
     "@eslint/js": "^9.39.2",
     "@playwright/test": "^1.61.1",
     "@testing-library/dom": "^10.4.1",
     "@testing-library/user-event": "^14.6.1",
     "@testing-library/vue": "^8.1.0",
     "@types/cytoscape": "^3.31.0",
     "@types/d3": "^7.4.3",
     "@types/dompurify": "^3.2.0",
     "@types/markdown-it": "^14.1.2",
     "@types/node": "^26.1.1",
     "@vitejs/plugin-vue": "^6.0.7",
     "@vitest/coverage-v8": "^4.1.10",
     "@vitest/ui": "^4.0.18",
diff --git a/documentation/08-development.qmd b/documentation/08-development.qmd
index c56d803e..1c553653 100644
--- a/documentation/08-development.qmd
+++ b/documentation/08-development.qmd
@@ -115,160 +115,175 @@ cd api
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-db-version.R')"
 cd ../app && npx vitest run src/api/version.spec.ts src/components/AppVersionInfo.spec.ts
 ```
 
 ### Public Analysis Snapshots
 
 When adding a snapshot table or shape change, create a numbered migration under `db/migrations/`, update `api/functions/migration-manifest.R`, and add or update the migration and preset tests. Snapshot presets live in `api/functions/analysis-snapshot-presets.R`; unsupported public parameters should fail there before any repository or analysis work starts.
 
 Run focused snapshot checks while iterating:
 
 ```bash
 cd api
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-migration.R')"
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-presets.R')"
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-repository.R')"
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-builder.R')"
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-analysis-snapshot-read.R')"
 ```
 
 To refresh a snapshot in a local API or worker R session with DB configuration loaded, submit the durable worker job:
 
 ```r
 async_job_service_submit(
   job_type = "analysis_snapshot_refresh",
   request_payload = list(
     analysis_type = "functional_clusters",
     params = list(algorithm = "leiden")
   ),
   queue_name = "analysis"
 )
 ```
 
 Use `analysis_snapshot_refresh("functional_clusters", list(algorithm = "leiden"))` only for a deliberate local one-off where the R session owns a valid DB connection. After snapshot or MCP analysis changes, run `make test-mcp-smoke` against a running MCP sidecar in addition to the focused MCP unit tests.
 
 ### Analysis-Snapshot Releases (#573)
 
 Analysis-snapshot **releases** (`api/functions/analysis-snapshot-release*.R`, `api/services/analysis-snapshot-release-service.R`, migration `045_add_analysis_snapshot_release.sql`) freeze the currently active public-ready snapshots above into an immutable, content-addressed, independently-downloadable artifact. They are a separate layer on top of snapshots, not a replacement — building one requires snapshots to already be `available`.
 
 Run focused release checks while iterating:
 
 ```bash
 cd api
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-release-migration.R')"
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-release-manifest.R')"
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-release-service.R')"
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-analysis-snapshot-release-build.R')"
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-analysis-release-admin-endpoints.R')"
 Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-analysis-release-endpoints.R')"
 ```
 
 **Building a release locally.** Once `make dev` has current public-ready snapshots (see above), mint one with the admin build endpoint (Administrator token):
 
 ```bash
 curl -sS -X POST http://localhost/api/admin/analysis/releases \
   -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" \
   -d '{"title": "local dev release", "publish": true}'
 ```
 
 A gate failure (a layer not `available`, missing its reproducibility bundle, incoherent, or with mismatched source-data version/dependency lineage) returns a 400 naming the failing layer — that is expected until every source snapshot is genuinely `available` and coherent, not a bug in the release build itself.
 
 **Verifying a bundle end-to-end.** This is the same recipe a public consumer runs, and it is worth exercising after touching any release code:
 
 ```bash
 release_id=asr_<...>   # from the build response above
 curl -sS "http://localhost/api/analysis/releases/$release_id/manifest.json" -o manifest.json
 curl -sS "http://localhost/api/analysis/releases/$release_id/bundle" -o bundle.tar.gz
 sha256sum manifest.json bundle.tar.gz
 mkdir -p /tmp/asr-verify && tar -xzf bundle.tar.gz -C /tmp/asr-verify
 (cd /tmp/asr-verify && sha256sum -c checksums.sha256)
 ```
 
 `sha256sum -c checksums.sha256` must report every extracted file as `OK`; the standalone `manifest.json` download's own SHA-256 must equal the release head's `manifest_sha256` field.
 
 **Manifest schema summary** (`manifest_schema_version` `"1.0"`, built by `analysis_release_build_manifest()` in `api/functions/analysis-snapshot-release-manifest.R`): `release_id`, `release_version`, `title`, `created_at`, `license`, `scope_statement`, `generator` (API/schema/cluster-logic versions), `source` (`source_data_version` + DB release label), `layers[]` (one entry per pinned snapshot: `analysis_type`, `snapshot_id`, `parameter_hash`, `schema_version`, `input_hash`, `payload_hash`, `reproducibility_hash`, and — for the correlation layer — `dependencies` naming both cluster axes' `snapshot_id`/`payload_hash`), `files[]` (`path`, `sha256`, `bytes`, excluding `manifest.json` and `checksums.sha256` themselves, which cannot describe their own checksum), and `content_digest`.
 
 **Two hashing facts that are easy to get backwards:**
 
 - `sha256(reproducibility.json)` (each cluster layer's file) equals its `reproducibility_hash` **exactly** — this is the raw pre-gzip bundle bytes read via `analysis_reproducibility_decode_raw()`, never the parsing `analysis_reproducibility_decode()`, whose `jsonlite::fromJSON()` round-trip drops the bundle's full-precision contract and breaks the equality.
 - `payload_hash` (and `input_hash`, `snapshot_id`) recorded per layer in the manifest is a **lineage anchor**, cross-checkable against the live `meta.snapshot.{payload_hash,input_hash,snapshot_id}` block on the corresponding `/api/analysis/*` endpoint — it is **not** the SHA-256 of that layer's own `payload.json` file in the bundle (that file has its own, separately-computed `content_sha256` in `files[]`). The stored payload round-trips through DB column types before a release freezes it, so a byte-for-byte reconstruction of the original in-memory payload is neither guaranteed nor attempted.
 
+### Category-Selected Clustering (#574)
+
+`POST /api/jobs/clustering/submit` accepts an optional `category_filter` JSON body array (e.g. `["Definitive"]`) as an alternative gene-universe selector to the existing `genes` array; supplying neither keeps the pre-#574 default all-NDD-genes universe, and supplying both is a 400. A category run resolves entity-level against the live `ndd_entity_view` (any gene with >=1 `ndd_phenotype = 1` entity in a selected category qualifies) and validates the selector against the live active `ndd_entity_status_categories_list` — an unknown/inactive category or a universe under 2 genes is a 400 naming the allowed active categories. Category runs are NOT `public_ready`; they are the same ephemeral job-result mechanism as an explicit-`genes` submit, just with a curated-category-derived universe.
+
+Every submit (cache-hit or worker-run) records selector/fingerprint provenance in the durable job payload and result `meta` — see `api/functions/clustering-gene-universe.R` (resolver), `api/services/job-functional-submission-service.R` (cache-hit meta), and `.async_job_run_clustering()` in `api/functions/async-job-handlers.R` (worker-run meta) for the exact shape. Focused checks while iterating:
+
+```bash
+cd api
+Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-clustering-gene-universe.R')"
+Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-clustering-handler-meta.R')"
+Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-endpoint-services.R')"
+```
+
+`test-integration-clustering-category-submit.R` exercises the resolver against a real, populated `sysndd_db_test` `ndd_entity_view` and skips cleanly on the empty CI/local default test DB.
+
 ### LLM Model Configuration
 
 Local Gemini summary generation uses `gemini-3.5-flash` by default. Set `GEMINI_MODEL` to override the runtime model for API and worker processes; if it is unset, the API reads `gemini_model` from `api/config.yml`, then falls back to the built-in default.
 
 Unknown model IDs are rejected before any Gemini call. During local provider rollout testing, add comma-separated IDs to `GEMINI_ALLOWED_MODELS_EXTRA`; those models are accepted with an operator warning in the admin LLM configuration panel. Do not use the allowlist for shut-down catalog models such as `gemini-3-pro-preview`.
 
 ### GeneNetworks fCoSE Layout Prewarm
 
 The GeneNetworks browser graph uses precomputed Cytoscape/fCoSE display positions when available. The worker computes the layout artifact with the Node helper in `api/layout/` and stores it under `/app/cache/network_layouts`.
 
 For local verification:
 
 ```bash
 cd api/layout && npm test
 make dev
 curl -sS 'http://localhost/api/analysis/network_edges?cluster_type=clusters&max_edges=10000' | jq '.metadata.display_layout_status'
 ```
 
 If the status is `missing`, `invalid`, or `error`, the frontend falls back to browser fCoSE. The frontend only uses Cytoscape `preset` when the API reports `display_layout_status = "available"` and every displayed gene node has finite artifact coordinates.
 
 ### PubtatorNDD Gene-Count Enrichment Normalization
 
 The PubtatorNDD gene-prioritization table normalizes raw NDD co-occurrence counts for research-popularity bias (issue #175). The raw count conflates true NDD relevance with how heavily a gene is studied, so heavily-studied genes (TP53, APP, MAPT, APOE) surface in the top 10 with no specific NDD role. Each gene's NDD co-occurrence count is normalized by its total PubTator publication count and scored with three metrics:
 
 - **Enrichment ratio** — `observed / (ndd_corpus_size * background_count / total_corpus_size)` (fold change).
 - **NPMI** — Normalized Pointwise Mutual Information, bounded `[-1, 1]`.
 - **Fisher exact p-value** (one-sided, enrichment) + **Benjamini-Hochberg FDR** across all genes.
 
 The metric math lives in `api/functions/pubtator-enrichment-metrics.R` (pure, unit-tested in `tests/testthat/test-unit-pubtator-enrichment.R`). Background-count collection and DB persistence live in `api/functions/pubtator-enrichment-collector.R`.
 
 Collection makes one external PubTator call per gene plus two corpus-size probes, so it runs only in the durable async worker (`pubtator_enrichment_refresh` job; needs PubTator egress), never on a public request. The external fetcher uses `memoise_external_success_only()` (7-day cache, transient errors not cached). Intended cadence: monthly. Snapshots are stored in `pubtator_corpus_stats` / `pubtator_gene_enrichment` (migration `027`) with exactly one current row; the API serves them via `pubtator_gene_enrichment_view`, LEFT-joined onto the gene listing so genes without a metric yet still appear.
 
 Admins submit a refresh and read status with:
 
 ```bash
 curl -sS -X POST 'http://localhost/api/publication/pubtator/enrichment/refresh' -H "Authorization: Bearer <admin-token>"
 curl -sS 'http://localhost/api/publication/pubtator/enrichment/status' | jq
 ```
 
 Or, in a worker/API R session with a DB connection:
 
 ```r
 async_job_service_submit(job_type = "pubtator_enrichment_refresh", request_payload = list(refresh = "all"))
 ```
 
 The default gene-table sort is `-enrichment_ratio,-npmi,publication_count`; the raw NDD publication count remains sortable. Restart the worker container after changing `api/functions/pubtator-enrichment-*.R` or `api/functions/async-job-handlers.R` before testing job behavior in Docker.
 
 ### Disease Cross-Ontology Mappings
 
 Disease cross-ontology mappings are derived from MONDO (`mondo.obo` + `mondo.sssom.tsv`) and stored in the `mondo_term`, `mondo_xref`, `disease_ontology_mapping`, and `disease_ontology_mapping_meta` tables (migration `036`). Denormalized projection columns (`UMLS`, `MedGen`, `NCIT`, `GARD`, `ontology_mapping_release`) on `disease_ontology_set` hold the best CURIE per prefix.
 
 **To trigger a refresh locally (dev stack running):**
 
 ```bash
 # Via admin HTTP endpoint (Administrator token required):
 curl -sS -X POST 'http://localhost/api/admin/ontology/mappings/refresh' \
   -H "Authorization: Bearer <admin-token>" \
   -H "Content-Type: application/json" \
   -d '{"force": true}'
 
 # Check status:
 curl -sS 'http://localhost/api/admin/ontology/mappings/status' \
   -H "Authorization: Bearer <admin-token>" | jq
 
 # Or via the enqueue script inside the api container:
 docker exec sysndd-api-1 Rscript /app/scripts/ontology_mapping_refresh_enqueue.R
 ```
 
 The worker picks up the job and runs the orchestrator (`api/functions/disease-ontology-mapping-refresh.R`). It downloads `mondo.obo` (~50 MB) and `mondo.sssom.tsv` (~80 MB) via budgeted conditional GET requests. On repeated runs with no changes (HTTP 304 from the upstream), the job records `status = "skipped"` in `disease_ontology_mapping_meta` — no rebuild occurs.
 
 **Fixtures for tests** live in `api/tests/testthat/fixtures/`:
 - `mondo-mini.obo` — minimal OBO with a handful of MONDO terms.
 - `mondo-mini.sssom.tsv` — matching SSSOM rows for the mini term set.
 
 Unit tests consume these fixtures directly (no network). Integration tests stub the download functions with fixture paths so no real MONDO download occurs.
 
 **Running the mapping tests:**
 
 Host-side R (no RMariaDB required for unit tests):
 ```bash

exec
/bin/bash -lc "for task_file in api/functions/clustering-gene-universe.R api/services/job-functional-submission-service.R api/functions/async-job-handlers.R api/functions/async-job-service.R api/endpoints/jobs_endpoints.R api/bootstrap/load_modules.R; do printf '\\n===== %s =====\\n' \""'$task_file"; nl -ba "$task_file"; done' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:

===== api/functions/clustering-gene-universe.R =====
     1	# api/functions/clustering-gene-universe.R
     2	#
     3	# Category-selected clustering gene-universe resolver (#574 D1).
     4	#
     5	# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
     6	# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
     7	# universe from curated SysNDD confidence categories instead of the default
     8	# "all NDD genes" set. This file builds ONLY the resolver + provenance
     9	# helpers; the submit service and durable handler wiring is done later.
    10	#
    11	# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
    12	# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
    13	# same gene also has OTHER-category entities. This mirrors
    14	# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
    15	# added `category %in% selector` filter -- it deliberately does NOT use
    16	# `select_network_gene_category()`, which is a gene-level display-label
    17	# aggregator for node coloring, not a universe filter.
    18	#
    19	# Category validation is live against `ndd_entity_status_categories_list
    20	# WHERE is_active = 1` -- no hardcoded category strings, and no category
    21	# string is interpolated into SQL (dbplyr `%in%` + an allowlist pre-check).
    22	
    23	# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
    24	# selector returns character(0), which the resolver rejects with 400 -- it must
    25	# never fall through to the all-NDD default.
    26	clustering_normalize_category_filter <- function(category_filter) {
    27	  if (is.null(category_filter)) return(NULL)
    28	  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
    29	  vals <- vals[nzchar(vals)]
    30	  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
    31	  sort(unique(vals))
    32	}
    33	
    34	clustering_gene_list_sha256 <- function(hgnc_ids) {
    35	  digest::digest(
    36	    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
    37	    algo = "sha256", serialize = FALSE
    38	  )
    39	}
    40	
    41	clustering_resolve_category_universe <- function(category_filter, conn = pool) {
    42	  selector <- clustering_normalize_category_filter(category_filter)
    43	
    44	  if (is.null(selector)) {
    45	    # Absent -> preserve the exact current default ordering for cache parity.
    46	    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
    47	    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
    48	  }
    49	
    50	  # Any PRESENT selector (including supplied-but-empty) needs the allowed
    51	  # active-category set for its 400 message, so this fetch runs for every
    52	  # present-selector path -- not just the unknown-category branch below.
    53	  active <- conn %>%
    54	    dplyr::tbl("ndd_entity_status_categories_list") %>%
    55	    dplyr::filter(is_active == 1) %>%
    56	    dplyr::select(category) %>%
    57	    dplyr::collect() %>%
    58	    dplyr::pull(category)
    59	
    60	  if (length(selector) == 0L) {
    61	    stop_for_bad_request(sprintf(
    62	      "category_filter was supplied but empty; provide at least one active category. Allowed active categories: %s",
    63	      paste(sort(active), collapse = ", ")
    64	    ))
    65	  }
    66	
    67	  unknown <- setdiff(selector, active)
    68	  if (length(unknown) > 0L) {
    69	    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
    70	    stop_for_bad_request(sprintf(
    71	      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
    72	      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
    73	    ))
    74	  }
    75	
    76	  hgnc_ids <- conn %>%
    77	    dplyr::tbl("ndd_entity_view") %>%
    78	    dplyr::arrange(entity_id) %>%
    79	    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
    80	    dplyr::select(hgnc_id) %>%
    81	    dplyr::collect() %>%
    82	    unique() %>%
    83	    dplyr::pull(hgnc_id)
    84	
    85	  if (length(hgnc_ids) < 2L) {
    86	    stop_for_bad_request(sprintf(
    87	      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2. Allowed active categories: %s",
    88	      paste(selector, collapse = ","), length(hgnc_ids), paste(sort(active), collapse = ", ")
    89	    ))
    90	  }
    91	  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
    92	}
    93	
    94	# Module-level (survives across requests within the same process) cache for
    95	# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
    96	# public tables and changes rarely (only when the snapshot builder's source
    97	# view moves), so a short-TTL process cache avoids paying that cost on every
    98	# clustering submit while still self-refreshing.
    99	.clustering_source_data_version_cache <- new.env(parent = emptyenv())
   100	
   101	#' Predicate: is `v` a valid source-data-version value?
   102	#'
   103	#' The fail-closed contract requires a single non-NA, non-empty character
   104	#' scalar. Anything else (`NULL`, `NA_character_`, `""`, a non-character
   105	#' value, or a non-scalar) must never be cached or served as provenance
   106	#' (Codex review fix -- the TTL cache previously cached/returned an invalid
   107	#' underlying value verbatim).
   108	.clustering_valid_source_version <- function(v) {
   109	  is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
   110	}
   111	
   112	#' Cached, fail-closed read of the current analysis source-data version.
   113	#'
   114	#' D2 (#574) provenance helper: the clustering submit service calls this
   115	#' AFTER admission/dedup, only when it is actually about to build a durable
   116	#' payload. Refetches once `ttl_seconds` has elapsed since the last
   117	#' successful read. Deliberately does NOT wrap
   118	#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
   119	#' PROPAGATES to the caller (never cached, never coerced to NA), so a
   120	#' transient DB problem fails the submit closed (503) instead of recording
   121	#' broken provenance. The fetched value is additionally validated by
   122	#' `.clustering_valid_source_version()`: an invalid value (NA/empty/
   123	#' non-scalar) is likewise NEVER cached or returned -- it `stop()`s instead,
   124	#' so the caller's `tryCatch` maps it to the same 503 PROVENANCE_UNAVAILABLE
   125	#' path as a hard fetch error.
   126	#'
   127	#' @param conn DB connection/pool. Defaults to the package-global `pool`.
   128	#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
   129	#' @return character(1) source data version.
   130	#' @export
   131	clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
   132	  now <- Sys.time()
   133	  cached_at <- .clustering_source_data_version_cache$cached_at
   134	  cached_value <- .clustering_source_data_version_cache$value
   135	  if (!is.null(cached_at) && .clustering_valid_source_version(cached_value) &&
   136	        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
   137	    return(cached_value)
   138	  }
   139	
   140	  value <- analysis_snapshot_source_data_version(conn = conn)
   141	
   142	  if (!.clustering_valid_source_version(value)) {
   143	    stop(
   144	      "clustering_cached_source_data_version: analysis_snapshot_source_data_version() ",
   145	      "returned an invalid (NULL/NA/empty/non-scalar) value; refusing to cache or serve it"
   146	    )
   147	  }
   148	
   149	  .clustering_source_data_version_cache$value <- value
   150	  .clustering_source_data_version_cache$cached_at <- now
   151	  value
   152	}
   153	
   154	# Assemble the clustering result `meta`: base fields + the cheap-path provenance
   155	# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
   156	# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
   157	# observed post-compute. Shared by the cache-hit path
   158	# (job-functional-submission-service.R) and the worker-run/durable handler
   159	# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
   160	# shapes cannot drift apart by hand-copied edits.
   161	clustering_result_meta <- function(base, provenance, weight_channel) {
   162	  c(base,
   163	    if (!is.null(provenance)) provenance else list(),
   164	    list(effective_fingerprint = list(weight_channel = weight_channel)))
   165	}

===== api/services/job-functional-submission-service.R =====
     1	# api/services/job-functional-submission-service.R
     2	#
     3	# Body of `POST /api/jobs/clustering/submit`, extracted from
     4	# endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5). Public endpoint —
     5	# no role gate. The endpoint shell delegates the entire handler body here;
     6	# `svc_job_submit_functional_clustering()` mutates `res` (status + headers)
     7	# exactly as the inline handler used to, and returns the JSON payload.
     8	#
     9	# The durable handler receives serialized input, not a database connection, so
    10	# all values it needs are fetched from `pool` before `create_job()` is called.
    11	#
    12	# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
    13	# (api/bootstrap/load_modules.R) like any other services/* file. The worker
    14	# executes the registered `clustering` durable handler, never this submitter.
    15	
    16	#' Submit a functional (STRING-db) clustering job.
    17	#'
    18	#' Cache-first: if the memoised `gen_string_clust_obj_mem()` already has a
    19	#' result for the resolved gene list + algorithm, the result is persisted as
    20	#' an already-completed durable job via `async_job_service_store_completed()`
    21	#' so the response shape matches a freshly-submitted job (this keeps LLM batch
    22	#' generation on the same job/result hashes as the API-served table). A cache
    23	#' miss falls through the public queue-depth capacity guard
    24	#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
    25	#' new durable job via `create_job()`.
    26	#'
    27	#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
    28	#' curated-category selection via `category_filter` (resolved through
    29	#' `clustering_resolve_category_universe()`), or -- when neither is supplied
    30	#' -- the existing default all-NDD-genes universe. `genes` and
    31	#' `category_filter` are mutually exclusive (400 if both are present). Every
    32	#' submit records selector + fingerprint provenance in the durable payload
    33	#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
    34	#'
    35	#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
    36	#'   `category_filter` and `req$user$user_id`).
    37	#' @param res Plumber response, mutated in place (status + headers).
    38	#' @return List payload for the `json` serializer.
    39	#' @export
    40	svc_job_submit_functional_clustering <- function(req, res) {
    41	  # Guard FIRST (#535 S6): per-caller submit admission throttle, applied before any
    42	  # DB/cache/duplicate work so an abusive caller is rejected before it can do — or
    43	  # provoke — expensive work (a cache hit still writes a completed job row, and the
    44	  # duplicate/data fetch below touch the DB). Layered on the global capacity cap.
    45	  admission <- async_job_submit_admission_guard(req, res)
    46	  if (!isTRUE(admission$admitted)) {
    47	    return(admission$response)
    48	  }
    49	
    50	  # Extract request data before durable submission.
    51	
    52	  # Connection objects cannot cross process boundaries. `genes` and
    53	  # `category_filter` are mutually exclusive gene-universe selectors (#574):
    54	  # an explicit gene list, a curated-category selection, or (both absent) the
    55	  # existing default all-NDD-genes universe.
    56	  genes_in <- req$argsBody$genes
    57	  has_genes <- !is.null(genes_in) && length(genes_in) > 0
    58	
    59	  # Selector presence is gated on JSON KEY PRESENCE (`names(req$argsBody)`), not
    60	  # value-nullness or length: `!is.null()` cannot distinguish an ABSENT key from
    61	  # an explicit JSON `null` (both parse to NULL in R). So a present `genes` key
    62	  # (`{"genes":null,...}` / `{"genes":[],...}`) and a present `category_filter`
    63	  # key each drive their guard regardless of value (Codex rounds 2 & 4). Mutual
    64	  # exclusion 400s when BOTH keys are present; a present-but-null/empty
    65	  # `category_filter` is a supplied-empty 400 (in the branch below), never a
    66	  # silent fall-through to the all-NDD default. `has_genes` (value-based,
    67	  # non-empty) still selects the explicit-genes branch.
    68	  body_names <- names(req$argsBody)
    69	  genes_key <- "genes" %in% body_names
    70	  category_key <- "category_filter" %in% body_names
    71	
    72	  if (genes_key && category_key) {
    73	    stop_for_bad_request("Provide either genes or category_filter, not both")
    74	  }
    75	
    76	  # Extract algorithm parameter (default: leiden)
    77	  # Ensure we get a scalar value (JSON may pass arrays)
    78	  algorithm <- "leiden"
    79	  if (!is.null(req$argsBody$algorithm)) {
    80	    algo_input <- req$argsBody$algorithm
    81	    # Handle array input - always take first element if vector
    82	    if (is.list(algo_input) || length(algo_input) >= 1) {
    83	      algo_input <- algo_input[[1]]
    84	    }
    85	    algorithm <- tolower(as.character(algo_input))
    86	    if (!algorithm %in% c("leiden", "walktrap")) {
    87	      algorithm <- "leiden"
    88	    }
    89	  }
    90	
    91	  # Resolve the clustering gene universe + selector provenance (#574). The
    92	  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
    93	  # from before this feature: `clustering_resolve_category_universe(NULL)`
    94	  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
    95	  # so cache parity (memoise key = gene set + algorithm) is preserved.
    96	  selector_chr <- NULL
    97	  if (has_genes) {
    98	    genes_list <- as.character(unlist(genes_in))
    99	    kind <- "explicit"
   100	  } else if (category_key) {
   101	    # A present category_filter key means a category run. A present-but-null
   102	    # value is supplied-but-empty (a NULL would otherwise hit the resolver's
   103	    # absent->default branch), so it is coerced to an empty selector here and
   104	    # delegated to the resolver -- the resolver's supplied-empty branch 400s
   105	    # it (with the allowed active-category set in the message), keeping the
   106	    # 400 message construction in the single resolver source of truth.
   107	    cf <- req$argsBody$category_filter
   108	    if (is.null(cf)) cf <- list()
   109	    universe <- clustering_resolve_category_universe(cf)
   110	    genes_list <- universe$hgnc_ids
   111	    selector_chr <- universe$selector
   112	    kind <- "category"
   113	  } else {
   114	    universe <- clustering_resolve_category_universe(NULL)
   115	    genes_list <- universe$hgnc_ids
   116	    kind <- "all_ndd"
   117	  }
   118	
   119	  # Pre-fetch the STRING ID table because DB connections cannot cross the
   120	  # durable worker boundary.
   121	  string_id_table <- pool %>%
   122	    dplyr::tbl("non_alt_loci_set") %>%
   123	    dplyr::filter(!is.na(STRING_id)) %>%
   124	    dplyr::select(symbol, hgnc_id, STRING_id) %>%
   125	    dplyr::collect()
   126	
   127	  # Check for duplicate job (include algorithm in check). The selector is
   128	  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
   129	  # submits keep the pre-#574 dedup identity byte-identical.
   130	  dup_params <- list(genes = genes_list, algorithm = algorithm)
   131	  if (!is.null(selector_chr)) {
   132	    dup_params$category_filter <- selector_chr
   133	  }
   134	  dup_check <- check_duplicate_job("clustering", dup_params)
   135	  if (dup_check$duplicate) {
   136	    res$status <- 409
   137	    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
   138	    return(list(
   139	      error = "DUPLICATE_JOB",
   140	      message = "Identical job already running",
   141	      existing_job_id = dup_check$existing_job_id,
   142	      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
   143	    ))
   144	  }
   145	
   146	  # Cheap-path provenance (no expensive query yet). `selector_obj` records
   147	  # WHICH universe was resolved; `intended_fingerprint` records the STRING
   148	  # cache identity + fixed clustering params this submit intends to run
   149	  # with. The *effective* fingerprint (e.g. the STRING weight channel a
   150	  # computed result actually used) is only knowable from a computed result,
   151	  # so it is recorded separately in the cache-hit result meta below.
   152	  selector_obj <- list(kind = kind, category_filter = selector_chr)
   153	  intended_fingerprint <- list(
   154	    string_cache_fingerprint = analysis_string_cache_fingerprint(),
   155	    score_threshold = 400L,
   156	    algorithm = algorithm,
   157	    seed = 42L
   158	  )
   159	  gene_sha <- clustering_gene_list_sha256(genes_list)
   160	  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
   161	  # count must agree with it, so it is computed from the SAME dedup -- an
   162	  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
   163	  # not report a resolved count that disagrees with a singleton sha256. This
   164	  # never dedups the payload `genes` list itself (`genes_list` stays
   165	  # byte-identical to the raw request) -- only the reported COUNT (Codex
   166	  # review fix).
   167	  resolved_count <- length(unique(genes_list))
   168	
   169	  # Source-data version: a CACHED, fail-closed read, fetched only now that a
   170	  # payload is actually about to be built -- its backing view runs global
   171	  # counts/joins, so it must never run before admission/dedup. A lookup
   172	  # failure must never silently record NA/broken provenance; fail the
   173	  # request closed instead.
   174	  src_ver <- tryCatch(
   175	    clustering_cached_source_data_version(conn = pool),
   176	    error = function(e) e
   177	  )
   178	  if (inherits(src_ver, "error")) {
   179	    res$status <- 503L
   180	    return(list(
   181	      error = "PROVENANCE_UNAVAILABLE",
   182	      message = "Snapshot source-data version unavailable; retry shortly."
   183	    ))
   184	  }
   185	
   186	  provenance <- list(
   187	    selector = selector_obj,
   188	    resolved_gene_count = resolved_count,
   189	    gene_list_sha256 = gene_sha,
   190	    intended_fingerprint = intended_fingerprint,
   191	    source_data_version = src_ver
   192	  )
   193	
   194	  # Define category links (needed for result)
   195	  category_links <- tibble::tibble(
   196	    value = c(
   197	      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
   198	      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
   199	      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
   200	    ),
   201	    link = c(
   202	      "https://www.ebi.ac.uk/QuickGO/term/",
   203	      "https://www.ebi.ac.uk/QuickGO/term/",
   204	      "https://disease-ontology.org/term/",
   205	      "https://www.ebi.ac.uk/QuickGO/term/",
   206	      "https://hpo.jax.org/browse/term/",
   207	      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
   208	      "https://www.genome.jp/dbget-bin/www_bget?",
   209	      "https://www.uniprot.org/keywords/",
   210	      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
   211	      "https://www.ebi.ac.uk/interpro/entry/pfam/",
   212	      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
   213	      "https://www.ebi.ac.uk/QuickGO/term/",
   214	      "https://reactome.org/content/detail/R-",
   215	      "http://www.ebi.ac.uk/interpro/entry/smart/",
   216	      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
   217	      "https://www.wikipathways.org/index.php/Pathway:"
   218	    )
   219	  )
   220	
   221	  # Cache-first: if the memoized function already has a cached result,
   222	  # return it immediately without submitting a durable worker job.
   223	  # The network_edges endpoint (graph) warms this cache on first load,
   224	  # so subsequent table requests resolve instantly.
   225	  cache_hit <- tryCatch(
   226	    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
   227	    error = function(e) FALSE
   228	  )
   229	
   230	  if (cache_hit) {
   231	    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
   232	
   233	    categories <- cached_clusters %>%
   234	      dplyr::select(term_enrichment) %>%
   235	      tidyr::unnest(cols = c(term_enrichment)) %>%
   236	      dplyr::select(category) %>%
   237	      unique() %>%
   238	      dplyr::arrange(category) %>%
   239	      dplyr::mutate(
   240	        text = dplyr::case_when(
   241	          nchar(category) <= 5 ~ category,
   242	          nchar(category) > 5 ~ stringr::str_to_sentence(category)
   243	        )
   244	      ) %>%
   245	      dplyr::select(value = category, text) %>%
   246	      dplyr::left_join(category_links, by = c("value"))
   247	
   248	    # Splice the base cache-hit fields with `provenance` (already assembled
   249	    # above as selector/resolved_gene_count/gene_list_sha256/
   250	    # intended_fingerprint/source_data_version) via the shared
   251	    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
   252	    # re-listing the same fields as duplicate literals -- keeps this shape in
   253	    # lockstep with the worker-run handler's result meta by construction.
   254	    # `effective_fingerprint` is only knowable from the computed result
   255	    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
   256	    cache_result <- list(
   257	      clusters = cached_clusters,
   258	      categories = categories,
   259	      meta = clustering_result_meta(
   260	        list(
   261	          algorithm = algorithm,
   262	          gene_count = resolved_count,
   263	          cluster_count = nrow(cached_clusters),
   264	          cache_hit = TRUE
   265	        ),
   266	        provenance,
   267	        attr(cached_clusters, "weight_channel")
   268	      )
   269	    )
   270	    cache_request_payload <- list(
   271	      genes = genes_list,
   272	      algorithm = algorithm,
   273	      category_links = category_links,
   274	      string_id_table = string_id_table,
   275	      provenance = provenance
   276	    )
   277	    if (!is.null(selector_chr)) {
   278	      cache_request_payload$category_filter <- selector_chr
   279	    }
   280	    # Dedup identity EXCLUDES provenance (Codex round 3): `provenance`
   281	    # carries a time-varying `source_data_version` and STRING cache
   282	    # `intended_fingerprint`, so hashing the full payload would make the
   283	    # active-job uniqueness guard admit duplicate concurrent clustering work
   284	    # across a deploy/cache-TTL change and break the byte-identical
   285	    # explicit/no-arg `request_hash` contract predating #574. Removing the
   286	    # `provenance` key preserves the leading `genes, algorithm,
   287	    # category_links, string_id_table[, category_filter]` key order -- it was
   288	    # appended last, so deleting it does not reorder the rest.
   289	    cache_hash_payload <- cache_request_payload
   290	    cache_hash_payload$provenance <- NULL
   291	    completed_job <- async_job_service_store_completed(
   292	      job_type = "clustering",
   293	      request_payload = cache_request_payload,
   294	      result = cache_result,
   295	      submitted_by = req$user$user_id %||% NULL,
   296	      queue_name = "analysis",
   297	      priority = 50L,
   298	      hash_payload = cache_hash_payload
   299	    )
   300	    job_id <- completed_job$job_id[[1]]
   301	
   302	    res$status <- 202
   303	    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   304	    res$setHeader("Retry-After", "0")
   305	
   306	    return(list(
   307	      job_id = job_id,
   308	      status = "accepted",
   309	      estimated_seconds = 0,
   310	      status_url = paste0("/api/jobs/", job_id, "/status"),
   311	      meta = list(llm_generation = "snapshot_refresh_owned")
   312	    ))
   313	  }
   314	
   315	  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   316	  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   317	  if (async_job_capacity_exceeded(
   318	        tryCatch(
   319	          async_job_active_count("default"),
   320	          error = function(e) {
   321	            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
   322	            0L
   323	          }
   324	        )
   325	      )) {
   326	    res$status <- 503
   327	    res$setHeader("Retry-After", "60")
   328	    return(list(
   329	      error = "CAPACITY_EXCEEDED",
   330	      message = "Analysis queue is at capacity. Please retry shortly.",
   331	      retry_after = 60
   332	    ))
   333	  }
   334	
   335	  # Cache miss - create async job
   336	  job_params <- list(
   337	    genes = genes_list,
   338	    algorithm = algorithm,
   339	    category_links = category_links,
   340	    string_id_table = string_id_table,
   341	    provenance = provenance
   342	  )
   343	  if (!is.null(selector_chr)) {
   344	    job_params$category_filter <- selector_chr
   345	  }
   346	  # See the cache-hit branch above: dedup identity EXCLUDES provenance so the
   347	  # active-job uniqueness guard is not defeated by its time-varying fields,
   348	  # and explicit/no-arg submits stay byte-identical to pre-#574.
   349	  #
   350	  # `create_job()` carries a deliberately guarded 2-arg contract
   351	  # (`operation`, `params`) -- it cannot take a hash override. This path
   352	  # calls `async_job_service_submit()` directly instead (mirroring the
   353	  # cache-hit branch above, which already calls
   354	  # `async_job_service_store_completed()` directly for the same reason), so
   355	  # `hash_payload` can diverge from the stored `request_payload` without
   356	  # touching `create_job()`'s contract.
   357	  hash_params <- job_params
   358	  hash_params$provenance <- NULL
   359	  submitted <- async_job_service_submit(
   360	    job_type = "clustering",
   361	    request_payload = job_params,
   362	    hash_payload = hash_params,
   363	    submitted_by = req$user$user_id %||% NULL
   364	  )
   365	  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL
   366	
   367	  # Success - return HTTP 202 Accepted
   368	  res$status <- 202
   369	  res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   370	  res$setHeader("Retry-After", "5")
   371	
   372	  list(
   373	    job_id = job_id,
   374	    status = "accepted",
   375	    estimated_seconds = 30,
   376	    status_url = paste0("/api/jobs/", job_id, "/status")
   377	  )
   378	}

===== api/functions/async-job-handlers.R =====
     1	# api/functions/async-job-handlers.R
     2	#
     3	# Durable async job handler shell (#346 Wave 4 split): common
     4	# payload/progress/clustering helpers, the legacy-executor passthrough
     5	# factory, the `async_job_handler_registry` list, and the
     6	# `async_job_get_handler()` lookup.
     7	#
     8	# Family-specific handler definitions live in sibling files sourced BEFORE
     9	# this one at every worker entrypoint, because the registry list below
    10	# references handler functions by bare symbol and R evaluates a list()
    11	# literal's elements eagerly at construction time:
    12	#   - functions/async-job-network-layout-handlers.R (network_layout_prewarm)
    13	#   - functions/async-job-analysis-snapshot-handlers.R (analysis_snapshot_refresh)
    14	#   - functions/async-job-omim-apply.R (OMIM DB-write / additive-terms helpers)
    15	#   - functions/async-job-force-apply-payload.R (force-apply payload-shape helpers)
    16	#   - functions/async-job-provider-handlers.R (HGNC, PubTator, NDDScore,
    17	#     disease-ontology mapping, OMIM update, force-apply-ontology)
    18	#   - functions/async-job-maintenance-handlers.R (backup create/restore,
    19	#     publication refresh/backfill)
    20	# Restart the worker container after changing any of these (worker-executed
    21	# code is sourced once at startup).
    22	# NOTE: .async_job_run_clustering assembles its result meta via
    23	# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
    24	# worker/API entrypoint sources that module via bootstrap_load_modules() before
    25	# this file; a direct-source test env must source it too (as the async-job tests do).
    26	
    27	.async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
    28	  invisible(result)
    29	}
    30	.async_job_or <- function(value, fallback) {
    31	  if (is.null(value) || length(value) == 0) {
    32	    return(fallback)
    33	  }
    34	
    35	  value
    36	}
    37	.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
    38	  if (!exists("create_async_job_progress_reporter", mode = "function")) {
    39	    stop("create_async_job_progress_reporter() is required for durable async job handlers", call. = FALSE)
    40	  }
    41	
    42	  create_async_job_progress_reporter(job_id, throttle_seconds = throttle_seconds)
    43	}
    44	.async_job_payload_field <- function(payload, field, required = TRUE, default = NULL) {
    45	  value <- payload[[field]]
    46	
    47	  if (is.null(value)) {
    48	    if (isTRUE(required)) {
    49	      stop(sprintf("Async job payload is missing required field '%s'", field), call. = FALSE)
    50	    }
    51	
    52	    return(default)
    53	  }
    54	
    55	  value
    56	}
    57	.async_job_payload_scalar <- function(payload, field, required = TRUE, default = NULL) {
    58	  value <- .async_job_payload_field(payload, field, required = required, default = default)
    59	
    60	  if (is.null(value)) {
    61	    return(value)
    62	  }
    63	
    64	  if (is.list(value)) {
    65	    value <- value[[1]]
    66	  }
    67	
    68	  value[[1]]
    69	}
    70	
    71	.async_job_add_job_id <- function(payload, job) {
    72	  payload$.__job_id__ <- job$job_id[[1]]
    73	  payload
    74	}
    75	
    76	.async_job_functional_categories <- function(clusters, category_links) {
    77	  categories <- clusters |>
    78	    dplyr::select(term_enrichment) |>
    79	    tidyr::unnest(cols = c(term_enrichment)) |>
    80	    dplyr::select(category) |>
    81	    unique() |>
    82	    dplyr::arrange(category) |>
    83	    dplyr::mutate(
    84	      text = dplyr::case_when(
    85	        nchar(category) <= 5 ~ category,
    86	        nchar(category) > 5 ~ stringr::str_to_sentence(category)
    87	      )
    88	    ) |>
    89	    dplyr::select(value = category, text)
    90	
    91	  if (!is.null(category_links)) {
    92	    categories <- dplyr::left_join(categories, category_links, by = c("value"))
    93	  }
    94	
    95	  categories
    96	}
    97	
    98	.async_job_run_clustering <- function(job, payload, state, worker_config) {
    99	  genes <- .async_job_payload_field(payload, "genes")
   100	  algorithm <- .async_job_payload_scalar(payload, "algorithm")
   101	  string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
   102	  category_links <- .async_job_payload_field(payload, "category_links", required = FALSE)
   103	  # #574 D3: the cheap-path selector/fingerprint provenance the submit
   104	  # service (job-functional-submission-service.R) recorded in the payload.
   105	  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
   106	  # FALSE) so a worker-run job for those still completes normally.
   107	  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
   108	  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
   109	
   110	  progress("cluster", "Running functional clustering...", current = 0, total = 1)
   111	
   112	  clusters <- gen_string_clust_obj(
   113	    genes,
   114	    algorithm = algorithm,
   115	    string_id_table = string_id_table
   116	  )
   117	
   118	  progress("complete", "Functional clustering complete", current = 1, total = 1)
   119	
   120	  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
   121	  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
   122	  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
   123	  # path), then the request's cheap-path `provenance` (selector/
   124	  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
   125	  # source_data_version) when present, then the `effective_fingerprint` --
   126	  # only knowable now that `clusters` has actually been computed -- so a
   127	  # silent exp+db -> combined-score STRING fallback on a worker-run job is
   128	  # visible in the stored result too, not just a cache hit's.
   129	  # gene_count is the DISTINCT gene count, matching the cache-hit path's
   130	  # `resolved_count <- length(unique(genes_list))` (job-functional-submission-
   131	  # service.R) -- for `["HGNC:1","HGNC:1"]` a raw `length(genes)` reported 2
   132	  # here while the cache-hit path reported 1 for the identical payload
   133	  # (Codex round-2 review fix). This never dedups the payload `genes` list
   134	  # itself or changes `nrow(clusters)`, only the reported count.
   135	  meta <- clustering_result_meta(
   136	    list(
   137	      algorithm = algorithm,
   138	      gene_count = length(unique(genes)),
   139	      cluster_count = nrow(clusters),
   140	      cache_hit = FALSE
   141	    ),
   142	    provenance,
   143	    attr(clusters, "weight_channel")
   144	  )
   145	
   146	  list(
   147	    clusters = clusters,
   148	    categories = .async_job_functional_categories(clusters, category_links),
   149	    meta = meta
   150	  )
   151	}
   152	
   153	.async_job_chain_llm <- function(result, job, cluster_type) {
   154	  if (!exists("trigger_llm_batch_generation", mode = "function")) {
   155	    return(invisible(result))
   156	  }
   157	
   158	  llm_clusters <- result
   159	
   160	  if (is.list(result) && "clusters" %in% names(result) && !is.null(result[["clusters"]])) {
   161	    llm_clusters <- result[["clusters"]]
   162	  }
   163	
   164	  trigger_llm_batch_generation(
   165	    clusters = llm_clusters,
   166	    cluster_type = cluster_type,
   167	    parent_job_id = job$job_id[[1]]
   168	  )
   169	
   170	  invisible(result)
   171	}
   172	
   173	.async_job_phenotype_matrix <- function(payload) {
   174	  sysndd_db_phenotypes <- payload$ndd_entity_view_tbl |>
   175	    dplyr::left_join(payload$ndd_review_phenotype_connect_tbl, by = "entity_id") |>
   176	    dplyr::left_join(payload$modifier_list_tbl, by = "modifier_id") |>
   177	    dplyr::left_join(payload$phenotype_list_tbl, by = "phenotype_id") |>
   178	    dplyr::mutate(ndd_phenotype = dplyr::case_when(
   179	      ndd_phenotype == 1 ~ "Yes",
   180	      ndd_phenotype == 0 ~ "No",
   181	      TRUE ~ ndd_phenotype
   182	    )) |>
   183	    dplyr::filter(ndd_phenotype == "Yes") |>
   184	    dplyr::filter(category %in% payload$categories) |>
   185	    dplyr::filter(modifier_name == "present") |>
   186	    dplyr::filter(review_id %in% payload$ndd_entity_review_tbl$review_id) |>
   187	    dplyr::select(
   188	      entity_id, hpo_mode_of_inheritance_term_name, phenotype_id,
   189	      HPO_term, hgnc_id
   190	    ) |>
   191	    dplyr::group_by(entity_id) |>
   192	    dplyr::mutate(
   193	      phenotype_non_id_count = sum(!(phenotype_id %in% payload$id_phenotype_ids)),
   194	      phenotype_id_count = sum(phenotype_id %in% payload$id_phenotype_ids)
   195	    ) |>
   196	    dplyr::ungroup() |>
   197	    unique()
   198	
   199	  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes |>
   200	    dplyr::mutate(present = "yes") |>
   201	    dplyr::select(-phenotype_id) |>
   202	    tidyr::pivot_wider(names_from = HPO_term, values_from = present) |>
   203	    dplyr::group_by(hgnc_id) |>
   204	    dplyr::mutate(gene_entity_count = dplyr::n()) |>
   205	    dplyr::ungroup() |>
   206	    dplyr::relocate(gene_entity_count, .after = phenotype_id_count) |>
   207	    dplyr::select(-hgnc_id)
   208	
   209	  phenotype_df <- sysndd_db_phenotypes_wider |>
   210	    dplyr::select(-entity_id) |>
   211	    as.data.frame()
   212	  row.names(phenotype_df) <- sysndd_db_phenotypes_wider$entity_id
   213	
   214	  # #508 MCA feature hygiene via the shared helper (same as
   215	  # generate_phenotype_cluster_input) so the interactive/durable clustering job
   216	  # produces the cleaned partition and can't diverge from the public snapshot.
   217	  phenotype_df <- phenotype_mca_prep_matrix(
   218	    phenotype_df,
   219	    hpo_lookup = dplyr::select(payload$phenotype_list_tbl, HPO_term, phenotype_id)
   220	  )
   221	
   222	  phenotype_df
   223	}
   224	
   225	.async_job_run_phenotype_clustering <- function(job, payload, state, worker_config) {
   226	  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
   227	
   228	  progress("prepare_matrix", "Preparing phenotype matrix...", current = 0, total = 2)
   229	  phenotype_matrix <- .async_job_phenotype_matrix(payload)
   230	  progress("cluster", "Running phenotype clustering...", current = 1, total = 2)
   231	  phenotype_clusters <- gen_mca_clust_obj(phenotype_matrix)
   232	  progress("complete", "Phenotype clustering complete", current = 2, total = 2)
   233	
   234	  identifiers <- payload$ndd_entity_view_tbl |>
   235	    dplyr::select(entity_id, hgnc_id, symbol)
   236	
   237	  phenotype_clusters |>
   238	    tidyr::unnest(identifiers) |>
   239	    dplyr::mutate(entity_id = as.integer(entity_id)) |>
   240	    dplyr::left_join(identifiers, by = "entity_id") |>
   241	    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
   242	}
   243	
   244	.async_job_run_ontology_update <- function(job, payload, state, worker_config) {
   245	  progress <- .async_job_progress_reporter(job$job_id[[1]])
   246	
   247	  progress("init", "Preparing ontology update", current = 0, total = 4)
   248	  disease_ontology_set <- process_combine_ontology(
   249	    hgnc_list = payload$hgnc_list,
   250	    mode_of_inheritance_list = payload$mode_of_inheritance_list,
   251	    max_file_age = 0,
   252	    output_path = "data/",
   253	    progress_callback = progress
   254	  )
   255	  progress("complete", "Ontology update complete", current = 4, total = 4)
   256	
   257	  list(
   258	    status = "completed",
   259	    rows_processed = nrow(disease_ontology_set),
   260	    sources = c("MONDO", "OMIM"),
   261	    output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
   262	  )
   263	}
   264	
   265	.async_job_run_passthrough <- function(fn_name) {
   266	  force(fn_name)
   267	
   268	  function(job, payload, state, worker_config) {
   269	    fn <- base::get(fn_name, mode = "function")
   270	    fn(.async_job_add_job_id(payload, job))
   271	  }
   272	}
   273	
   274	async_job_handler_registry <- list(
   275	  clustering = list(
   276	    cancel_mode = "best_effort",
   277	    run = .async_job_run_clustering,
   278	    after_success = function(result, job, payload, state, worker_config) {
   279	      .async_job_chain_llm(result, job, cluster_type = "functional")
   280	    }
   281	  ),
   282	  phenotype_clustering = list(
   283	    cancel_mode = "best_effort",
   284	    run = .async_job_run_phenotype_clustering,
   285	    after_success = function(result, job, payload, state, worker_config) {
   286	      .async_job_chain_llm(result, job, cluster_type = "phenotype")
   287	    }
   288	  ),
   289	  ontology_update = list(
   290	    cancel_mode = "non_interruptible",
   291	    run = .async_job_run_ontology_update,
   292	    after_success = .async_job_after_success_noop
   293	  ),
   294	  hgnc_update = list(
   295	    cancel_mode = "non_interruptible",
   296	    run = .async_job_run_hgnc_update,
   297	    after_success = .async_job_after_success_noop
   298	  ),
   299	  comparisons_update = list(
   300	    cancel_mode = "non_interruptible",
   301	    run = .async_job_run_passthrough("comparisons_update_async"),
   302	    after_success = .async_job_after_success_noop
   303	  ),
   304	  pubtator_update = list(
   305	    cancel_mode = "best_effort",
   306	    run = .async_job_run_pubtator,
   307	    after_success = .async_job_after_success_noop
   308	  ),
   309	  pubtator_enrichment_refresh = list(
   310	    cancel_mode = "best_effort",
   311	    run = .async_job_run_pubtator_enrichment,
   312	    after_success = .async_job_after_success_noop
   313	  ),
   314	  pubtatornidd_nightly = list(
   315	    cancel_mode = "non_interruptible",
   316	    run = .async_job_run_pubtatornidd_nightly,
   317	    after_success = .async_job_after_success_noop
   318	  ),
   319	  disease_ontology_mapping_refresh = list(
   320	    cancel_mode = "non_interruptible",
   321	    run = .async_job_run_disease_ontology_mapping_refresh,
   322	    after_success = .async_job_after_success_noop
   323	  ),
   324	  nddscore_import = list(
   325	    cancel_mode = "non_interruptible",
   326	    run = .async_job_run_nddscore_import,
   327	    after_success = .async_job_after_success_noop
   328	  ),
   329	  llm_generation = list(
   330	    cancel_mode = "best_effort",
   331	    run = .async_job_run_passthrough("llm_batch_executor"),
   332	    after_success = .async_job_after_success_noop
   333	  ),
   334	  network_layout_prewarm = list(
   335	    cancel_mode = "best_effort",
   336	    run = function(...) .async_job_run_network_layout_prewarm(...),
   337	    after_success = .async_job_after_success_noop
   338	  ),
   339	  analysis_snapshot_refresh = list(
   340	    cancel_mode = "best_effort",
   341	    run = function(...) .async_job_run_analysis_snapshot_refresh(...),
   342	    after_success = .async_job_after_success_noop
   343	  ),
   344	  backup_create = list(
   345	    cancel_mode = "non_interruptible",
   346	    run = .async_job_run_backup_create,
   347	    after_success = .async_job_after_success_noop
   348	  ),
   349	  backup_restore = list(
   350	    cancel_mode = "non_interruptible",
   351	    run = .async_job_run_backup_restore,
   352	    after_success = .async_job_after_success_noop
   353	  ),
   354	  omim_update = list(
   355	    cancel_mode = "non_interruptible",
   356	    run = .async_job_run_omim_update,
   357	    after_success = .async_job_after_success_noop
   358	  ),
   359	  force_apply_ontology = list(
   360	    cancel_mode = "non_interruptible",
   361	    run = .async_job_run_force_apply_ontology,
   362	    after_success = .async_job_after_success_noop
   363	  ),
   364	  publication_refresh = list(
   365	    cancel_mode = "best_effort",
   366	    run = .async_job_run_publication_refresh,
   367	    after_success = .async_job_after_success_noop
   368	  ),
   369	  publication_date_backfill = list(
   370	    cancel_mode = "non_interruptible",
   371	    run = .async_job_run_publication_date_backfill,
   372	    after_success = .async_job_after_success_noop
   373	  )
   374	)
   375	
   376	#' Resolve a durable async job handler definition
   377	#' @param job_type Character async job type.
   378	#' @param registry Named handler registry.
   379	#'
   380	#' @return Registry entry with run/cancel metadata.
   381	#' @export
   382	async_job_get_handler <- function(job_type, registry = async_job_handler_registry) {
   383	  entry <- registry[[job_type]]
   384	
   385	  if (is.null(entry)) {
   386	    stop(sprintf("No durable async job handler registered for '%s'", job_type), call. = FALSE)
   387	  }
   388	
   389	  if (!is.function(entry$run)) {
   390	    stop(sprintf("Handler registry entry for '%s' is missing a callable run function", job_type), call. = FALSE)
   391	  }
   392	
   393	  if (is.null(entry$after_success)) {
   394	    entry$after_success <- .async_job_after_success_noop
   395	  }
   396	
   397	  entry
   398	}

===== api/functions/async-job-service.R =====
     1	# ---------------------------------------------------------------------------
     2	# Queue-depth capacity cap
     3	# ---------------------------------------------------------------------------
     4	
     5	# Max simultaneously queued+running jobs allowed on the public submit queue.
     6	# Read once at source/startup time; changing the env var requires an API
     7	# restart to take effect. An INVALID value (e.g. "abc") must not parse to NA:
     8	# `async_job_capacity_exceeded()` isTRUE-wraps its comparison, so an NA cap would
     9	# silently disable this DB-backed backstop entirely. Floor at 1, default 8.
    10	ASYNC_PUBLIC_JOB_CAP <- local({
    11	  raw <- trimws(Sys.getenv("ASYNC_PUBLIC_JOB_CAP", "8"))
    12	  value <- suppressWarnings(as.integer(raw))
    13	  if (is.na(value) || value < 1L) 8L else value
    14	})
    15	
    16	#' TRUE when the active (queued+running) job count is at or over the cap.
    17	#'
    18	#' Soft cap: the check-then-submit sequence in the endpoints is not atomic, so
    19	#' two concurrent requests may both pass and transiently push the queue one or
    20	#' two over the cap. That is acceptable for a back-pressure guard.
    21	#'
    22	#' @param active_count Integer count of currently in-flight jobs.
    23	#' @param cap Integer maximum allowed. Defaults to ASYNC_PUBLIC_JOB_CAP.
    24	#' @return Logical.
    25	#' @export
    26	async_job_capacity_exceeded <- function(active_count, cap = ASYNC_PUBLIC_JOB_CAP) {
    27	  cap <- suppressWarnings(as.integer(cap))
    28	  if (length(cap) != 1L || is.na(cap) || cap < 1L) {
    29	    cap <- 8L # never let an invalid cap silently disable the backstop
    30	  }
    31	  isTRUE(as.integer(active_count) >= cap)
    32	}
    33	
    34	#' Count queued+running jobs for a given queue.
    35	#'
    36	#' @param queue_name Character queue name to inspect.
    37	#' @param conn Optional DB connection or pool. NULL uses global pool.
    38	#' @return Integer count of active (queued / running / cancel_requested) jobs.
    39	#' @export
    40	async_job_active_count <- function(queue_name = "default", conn = NULL) {
    41	  sql <- paste(
    42	    "SELECT COUNT(*) AS n FROM async_jobs",
    43	    "WHERE queue_name = ? AND status IN ('queued', 'running', 'cancel_requested')"
    44	  )
    45	  row <- db_execute_query(sql, params = list(queue_name), conn = conn)
    46	  if (nrow(row) == 0) 0L else as.integer(row$n[[1]])
    47	}
    48	
    49	# ---------------------------------------------------------------------------
    50	# Queue routing + priority by job type (#486)
    51	#
    52	# One serial worker draining one shared "default" queue lets a long-running,
    53	# non-interruptible maintenance job (e.g. publication_date_backfill) head-of-line
    54	# block latency-sensitive interactive jobs (clustering / phenotype_clustering /
    55	# llm_generation and the snapshot -> LLM deploy chain). These helpers are the
    56	# single source of truth for which lane and priority a job type defaults to; the
    57	# `worker-maintenance` container drains the "maintenance" lane so heavy jobs run
    58	# in parallel with the interactive worker instead of blocking it.
    59	# ---------------------------------------------------------------------------
    60	
    61	# Heavy / bulk / external maintenance job types, routed to the "maintenance" lane.
    62	ASYNC_MAINTENANCE_JOB_TYPES <- c(
    63	  "publication_date_backfill",
    64	  "publication_refresh",
    65	  "pubtator_update",
    66	  "pubtator_enrichment_refresh",
    67	  "pubtatornidd_nightly",
    68	  "omim_update",
    69	  "hgnc_update",
    70	  "comparisons_update",
    71	  "ontology_update",
    72	  "force_apply_ontology",
    73	  "disease_ontology_mapping_refresh",
    74	  "nddscore_import",
    75	  "backup_create",
    76	  "backup_restore"
    77	)
    78	
    79	# Latency-sensitive / user-visible interactive job types. They stay on the
    80	# "default" lane but get the LOWEST priority number so a worker claims them ahead
    81	# of any maintenance job that happens to share the queue.
    82	ASYNC_INTERACTIVE_JOB_TYPES <- c(
    83	  "clustering",
    84	  "phenotype_clustering",
    85	  "llm_generation",
    86	  "analysis_snapshot_refresh",
    87	  "network_layout_prewarm"
    88	)
    89	
    90	# Priority tiers (lower number = claimed first; the claim query orders
    91	# `priority ASC`). interactive < maintenance < everything-else default.
    92	ASYNC_PRIORITY_INTERACTIVE <- 10L
    93	ASYNC_PRIORITY_MAINTENANCE <- 50L
    94	ASYNC_PRIORITY_DEFAULT <- 100L
    95	
    96	#' Resolve the durable queue lane for a job type.
    97	#'
    98	#' @param job_type Character durable job type.
    99	#' @return "maintenance" for heavy/bulk/external maintenance job types, else
   100	#'   "default".
   101	#' @export
   102	async_job_queue_for_type <- function(job_type) {
   103	  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
   104	  if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) "maintenance" else "default"
   105	}
   106	
   107	#' Resolve the default claim priority for a job type.
   108	#'
   109	#' @param job_type Character durable job type.
   110	#' @return Integer priority: interactive (10) < maintenance (50) < default (100).
   111	#' @export
   112	async_job_priority_for_type <- function(job_type) {
   113	  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
   114	  if (jt %in% ASYNC_INTERACTIVE_JOB_TYPES) {
   115	    ASYNC_PRIORITY_INTERACTIVE
   116	  } else if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) {
   117	    ASYNC_PRIORITY_MAINTENANCE
   118	  } else {
   119	    ASYNC_PRIORITY_DEFAULT
   120	  }
   121	}
   122	
   123	# ---------------------------------------------------------------------------
   124	
   125	.async_job_service_scalar <- function(value, default = NULL) {
   126	  if (is.null(value) || length(value) == 0) {
   127	    return(default)
   128	  }
   129	
   130	  if (is.list(value)) {
   131	    return(value[[1]])
   132	  }
   133	
   134	  value[[1]]
   135	}
   136	
   137	.async_job_service_abort <- function(message, class = "async_job_service_validation_error", ...) {
   138	  rlang::abort(message = message, class = class, ...)
   139	}
   140	
   141	.async_job_service_non_empty_string <- function(value, field) {
   142	  scalar <- .async_job_service_scalar(value, NULL)
   143	
   144	  if (is.null(scalar)) {
   145	    .async_job_service_abort(sprintf("%s is required", field))
   146	  }
   147	
   148	  scalar <- as.character(scalar)
   149	  if (!nzchar(trimws(scalar))) {
   150	    .async_job_service_abort(sprintf("%s is required", field))
   151	  }
   152	
   153	  scalar
   154	}
   155	
   156	async_job_service_payload_json <- function(request_payload) {
   157	  if (is.character(request_payload) && length(request_payload) == 1L) {
   158	    return(request_payload[[1]])
   159	  }
   160	
   161	  as.character(
   162	    jsonlite::toJSON(
   163	      request_payload,
   164	      auto_unbox = TRUE,
   165	      null = "null",
   166	      dataframe = "rows",
   167	      POSIXt = "ISO8601"
   168	    )
   169	  )
   170	}
   171	
   172	async_job_service_request_hash <- function(job_type, request_payload_json) {
   173	  digest::digest(
   174	    paste0(
   175	      .async_job_service_non_empty_string(job_type, "job_type"),
   176	      ":",
   177	      as.character(.async_job_service_scalar(request_payload_json, ""))
   178	    ),
   179	    algo = "sha256",
   180	    serialize = FALSE
   181	  )
   182	}
   183	
   184	.async_job_service_duplicate_row <- function(error, conn = NULL) {
   185	  duplicate_job <- error$duplicate_job
   186	  if (is.null(duplicate_job)) {
   187	    duplicate_job <- tibble::tibble()
   188	  }
   189	
   190	  if (nrow(duplicate_job) > 0) {
   191	    return(duplicate_job)
   192	  }
   193	
   194	  job_id <- error$job_id
   195	  if (is.null(job_id)) {
   196	    return(tibble::tibble())
   197	  }
   198	
   199	  async_job_repository_get(job_id, conn = conn)
   200	}
   201	
   202	#' Submit a durable async job and return its stored row
   203	#'
   204	#' @param job_type Character durable job type.
   205	#' @param request_payload Named list or JSON payload string.
   206	#' @param submitted_by Optional user id.
   207	#' @param queue_name Character queue name. `NULL` (default) routes by job type via
   208	#'   `async_job_queue_for_type()` (maintenance lane for heavy jobs, else default);
   209	#'   an explicit value is honored as-is.
   210	#' @param priority Integer queue priority. `NULL` (default) resolves by job type
   211	#'   via `async_job_priority_for_type()` (interactive < maintenance < default); an
   212	#'   explicit value is honored as-is.
   213	#' @param max_attempts Integer maximum attempts.
   214	#' @param scheduled_at Optional schedule time.
   215	#' @param job_id Optional explicit job id for tests.
   216	#' @param conn Optional DB connection or pool.
   217	#' @param hash_payload Optional named list or JSON payload string. When
   218	#'   supplied, the dedup `request_hash` is computed over THIS payload instead
   219	#'   of `request_payload`, while `request_payload_json` (the durably stored
   220	#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
   221	#'   `request_payload` exactly as before, so existing callers are unaffected.
   222	#'   Used by clustering submits (#574) to exclude time-varying `provenance`
   223	#'   metadata from the dedup identity while still persisting it.
   224	#'
   225	#' @return List containing the stored job row and duplicate/create flags.
   226	#' @export
   227	async_job_service_submit <- function(
   228	  job_type,
   229	  request_payload,
   230	  submitted_by = NULL,
   231	  queue_name = NULL,
   232	  priority = NULL,
   233	  max_attempts = 1L,
   234	  scheduled_at = Sys.time(),
   235	  job_id = uuid::UUIDgenerate(),
   236	  conn = NULL,
   237	  hash_payload = NULL
   238	) {
   239	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   240	  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   241	  # Default the lane + priority from the job type so heavy maintenance jobs never
   242	  # head-of-line block interactive jobs (#486). Explicit overrides are honored.
   243	  if (is.null(queue_name)) {
   244	    queue_name <- async_job_queue_for_type(job_type)
   245	  }
   246	  if (is.null(priority)) {
   247	    priority <- async_job_priority_for_type(job_type)
   248	  }
   249	  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   250	  payload_json <- async_job_service_payload_json(request_payload)
   251	  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
   252	  request_hash <- async_job_service_request_hash(job_type, hash_payload_json)
   253	  submitted_at <- Sys.time()
   254	
   255	  stored_job <- tryCatch(
   256	    {
   257	      async_job_repository_create(
   258	        list(
   259	          job_id = job_id,
   260	          job_type = job_type,
   261	          queue_name = queue_name,
   262	          priority = as.integer(priority),
   263	          request_hash = request_hash,
   264	          request_payload_json = payload_json,
   265	          submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
   266	          submitted_at = submitted_at,
   267	          scheduled_at = scheduled_at,
   268	          max_attempts = as.integer(max_attempts)
   269	        ),
   270	        conn = conn
   271	      )
   272	
   273	      async_job_repository_get(job_id, conn = conn)
   274	    },
   275	    async_job_duplicate_error = function(error) {
   276	      .async_job_service_duplicate_row(error, conn = conn)
   277	    }
   278	  )
   279	
   280	  is_duplicate <- nrow(stored_job) > 0 && !identical(stored_job$job_id[[1]], job_id)
   281	
   282	  list(
   283	    job = stored_job,
   284	    duplicate = is_duplicate,
   285	    created = !is_duplicate
   286	  )
   287	}
   288	
   289	#' Persist an already-completed durable async job row
   290	#'
   291	#' Used for cache-hit fast paths that should still return a normal durable
   292	#' job id without enqueueing worker execution.
   293	#'
   294	#' @param job_type Character durable job type.
   295	#' @param request_payload Named list or JSON payload string.
   296	#' @param result Completed handler result payload.
   297	#' @param submitted_by Optional user id.
   298	#' @param queue_name Character queue name.
   299	#' @param priority Integer queue priority.
   300	#' @param job_id Optional explicit job id.
   301	#' @param submitted_at Optional submission timestamp.
   302	#' @param completed_at Optional completion timestamp.
   303	#' @param conn Optional DB connection or pool.
   304	#' @param hash_payload Optional named list or JSON payload string. When
   305	#'   supplied, the dedup `request_hash` is computed over THIS payload instead
   306	#'   of `request_payload`, while `request_payload_json` (the durably stored
   307	#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
   308	#'   `request_payload` exactly as before, so existing callers are unaffected.
   309	#'
   310	#' @return Tibble with the stored completed job row.
   311	#' @export
   312	async_job_service_store_completed <- function(
   313	  job_type,
   314	  request_payload,
   315	  result,
   316	  submitted_by = NULL,
   317	  queue_name = "default",
   318	  priority = 100L,
   319	  job_id = uuid::UUIDgenerate(),
   320	  submitted_at = Sys.time(),
   321	  completed_at = submitted_at,
   322	  conn = NULL,
   323	  hash_payload = NULL
   324	) {
   325	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   326	  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   327	  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   328	  payload_json <- async_job_service_payload_json(request_payload)
   329	  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
   330	  result_json <- async_job_service_payload_json(result)
   331	
   332	  async_job_repository_create(
   333	    list(
   334	      job_id = job_id,
   335	      job_type = job_type,
   336	      queue_name = queue_name,
   337	      priority = as.integer(priority),
   338	      status = "completed",
   339	      request_hash = async_job_service_request_hash(job_type, hash_payload_json),
   340	      request_payload_json = payload_json,
   341	      submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
   342	      submitted_at = submitted_at,
   343	      scheduled_at = submitted_at,
   344	      started_at = submitted_at,
   345	      completed_at = completed_at,
   346	      progress_pct = 100,
   347	      result_json = result_json
   348	    ),
   349	    conn = conn
   350	  )
   351	
   352	  async_job_repository_get(job_id, include_result = TRUE, conn = conn)
   353	}
   354	
   355	#' Find an active duplicate for a durable async job request
   356	#'
   357	#' @param job_type Character durable job type.
   358	#' @param request_payload Named list or JSON payload string.
   359	#' @param conn Optional DB connection or pool.
   360	#'
   361	#' @return Tibble with zero or one active duplicate row.
   362	#' @export
   363	async_job_service_find_duplicate <- function(job_type, request_payload, conn = NULL) {
   364	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   365	  payload_json <- async_job_service_payload_json(request_payload)
   366	
   367	  async_job_repository_find_active_duplicate(
   368	    job_type = job_type,
   369	    request_hash = async_job_service_request_hash(job_type, payload_json),
   370	    conn = conn
   371	  )
   372	}
   373	
   374	#' Read current durable async job status
   375	#'
   376	#' @param job_id Character job id.
   377	#' @param include_result Logical; include result_json when TRUE.
   378	#' @param conn Optional DB connection or pool.
   379	#'
   380	#' @return Tibble with zero or one durable job row.
   381	#' @export
   382	async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
   383	  async_job_repository_get(
   384	    job_id = .async_job_service_non_empty_string(job_id, "job_id"),
   385	    include_result = isTRUE(include_result),
   386	    conn = conn
   387	  )
   388	}
   389	
   390	#' Return durable async job history
   391	#'
   392	#' @param limit Integer history limit.
   393	#' @param include_result Logical; include result_json in history rows.
   394	#' @param conn Optional DB connection or pool.
   395	#'
   396	#' @return Tibble of recent durable jobs.
   397	#' @export
   398	async_job_service_history <- function(limit = 20L, include_result = FALSE, conn = NULL) {
   399	  args <- list(
   400	    limit = max(1L, as.integer(.async_job_service_scalar(limit, 20L))),
   401	    conn = conn
   402	  )
   403	  if (isTRUE(include_result)) {
   404	    args$include_result <- TRUE
   405	  }
   406	  do.call(async_job_repository_history, args)
   407	}
   408	
   409	#' Request durable async job cancellation and return the refreshed row
   410	#'
   411	#' @param job_id Character job id.
   412	#' @param cancelled_by Optional user id.
   413	#' @param conn Optional DB connection or pool.
   414	#'
   415	#' @return Tibble with zero or one durable job row after cancellation.
   416	#' @export
   417	async_job_service_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
   418	  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   419	
   420	  async_job_repository_cancel(
   421	    job_id = job_id,
   422	    cancelled_by = if (is.null(cancelled_by)) NULL else as.integer(cancelled_by),
   423	    conn = conn
   424	  )
   425	
   426	  async_job_repository_get(job_id, conn = conn)
   427	}
   428	
   429	#' Legacy duplicate response wrapper for endpoints not migrated yet
   430	#'
   431	#' @inheritParams async_job_service_find_duplicate
   432	#'
   433	#' @return List shaped like the previous duplicate helper.
   434	#' @export
   435	async_job_service_duplicate <- function(job_type, request_payload, conn = NULL) {
   436	  duplicate <- async_job_service_find_duplicate(
   437	    job_type = job_type,
   438	    request_payload = request_payload,
   439	    conn = conn
   440	  )
   441	
   442	  if (nrow(duplicate) == 0) {
   443	    return(list(duplicate = FALSE))
   444	  }
   445	
   446	  list(
   447	    duplicate = TRUE,
   448	    existing_job_id = duplicate$job_id[[1]]
   449	  )
   450	}
   451	
   452	#' Find an active job of a given type (job-type single-flight).
   453	#'
   454	#' @param job_type Character job type.
   455	#' @param conn Optional DB connection or pool.
   456	#' @return Tibble with zero or one active duplicate row of that job_type.
   457	#' @export
   458	async_job_service_find_active_by_type <- function(job_type, conn = NULL) {
   459	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   460	  async_job_repository_find_active_by_type(job_type = job_type, conn = conn)
   461	}
   462	
   463	#' Job-type single-flight duplicate check (#535 S2b HIGH-4).
   464	#'
   465	#' Unlike `async_job_service_duplicate()` (which keys on the payload hash and so
   466	#' cannot dedupe across a payload-schema change), this dedupes on job_type alone,
   467	#' so a destructive full-table-replace maintenance job (hgnc/comparisons/omim/
   468	#' force_apply) resubmitted while one is in flight gets a clean 409 even across
   469	#' the deploy that drops db_config from its payload.
   470	#'
   471	#' NOTE (scope): this is a **best-effort, submit-time** guard — the check and the
   472	#' subsequent insert are NOT atomic, so a rare concurrent double-submit can still
   473	#' enqueue two jobs. That is acceptable because the durable **maintenance lane
   474	#' runs on a single worker** (`async_job_worker_main` claims+runs jobs
   475	#' sequentially; Compose runs one `worker-maintenance` container), so two
   476	#' destructive jobs never execute concurrently regardless of dedup. A hard,
   477	#' atomic **cross-type conflict-group mutex** (e.g. an advisory lock covering
   478	#' check+insert, or a generated conflict-key unique index grouping
   479	#' omim_update/force_apply_ontology and pubtator_enrichment_refresh/
   480	#' pubtatornidd_nightly) is defense-in-depth needed only if the maintenance lane
   481	#' is ever scaled beyond one worker — tracked as a follow-up, not part of this
   482	#' credential fix.
   483	#'
   484	#' @param job_type Character job type.
   485	#' @param conn Optional DB connection or pool.
   486	#' @return list(duplicate = FALSE) or list(duplicate = TRUE, existing_job_id = ...).
   487	#' @export
   488	async_job_service_duplicate_by_type <- function(job_type, conn = NULL) {
   489	  active <- async_job_service_find_active_by_type(job_type, conn = conn)
   490	  if (nrow(active) == 0) {
   491	    return(list(duplicate = FALSE))
   492	  }
   493	  list(duplicate = TRUE, existing_job_id = active$job_id[[1]])
   494	}
   495	
   496	#' Legacy cancellation wrapper for endpoints not migrated yet
   497	#'
   498	#' @inheritParams async_job_service_cancel
   499	#'
   500	#' @return List describing cancellation outcome.
   501	#' @export
   502	async_job_service_request_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
   503	  cancelled <- async_job_service_cancel(
   504	    job_id = job_id,
   505	    cancelled_by = cancelled_by,
   506	    conn = conn
   507	  )
   508	
   509	  if (nrow(cancelled) == 0) {
   510	    return(list(
   511	      error = "JOB_NOT_FOUND",
   512	      message = "Job ID not found"
   513	    ))
   514	  }
   515	
   516	  list(job_id = job_id, status = cancelled$status[[1]])
   517	}

===== api/endpoints/jobs_endpoints.R =====
     1	# api/endpoints/jobs_endpoints.R
     2	#
     3	# Async job submission and status polling endpoints.
     4	# Submits durable worker jobs and returns HTTP 202 Accepted for long-running operations.
     5	#
     6	# Endpoints:
     7	#   POST /api/jobs/clustering/submit - Submit functional clustering job
     8	#   POST /api/jobs/phenotype_clustering/submit - Submit phenotype clustering job
     9	#   GET /api/jobs/<job_id>/status - Poll job status and retrieve results
    10	#
    11	# Dependencies:
    12	#   - pool (global database connection pool)
    13	#   - create_job, get_job_status, check_duplicate_job (from job-manager.R)
    14	#   - durable handlers registered in functions/async-job-handlers.R
    15	#
    16	# Handler bodies were extracted to services/job-*-service.R (issue #346, Wave
    17	# 3, Task 5) to keep this file a thin route table. Each shell below keeps its
    18	# original decorators, formals, and role gate, and delegates the rest to the
    19	# matching svc_ function.
    20	
    21	## -------------------------------------------------------------------##
    22	## Job Submission Endpoints
    23	## -------------------------------------------------------------------##
    24	
    25	#* Submit Functional Clustering Job
    26	#*
    27	#* Submits an async job to compute functional clustering via STRING-db. The
    28	#* clustering gene universe (#574) is resolved from one of three mutually
    29	#* exclusive JSON body selectors:
    30	#*   - `genes`: an explicit array of HGNC ids to cluster.
    31	#*   - `category_filter`: an array of curated SysNDD confidence categories
    32	#*     (e.g. `["Definitive"]`); resolved entity-level (>=1 NDD entity in a
    33	#*     selected category, `ndd_phenotype = 1`) against the live
    34	#*     `ndd_entity_view`, validated against the live active
    35	#*     `ndd_entity_status_categories_list`. A category run rejects with 400
    36	#*     when `category_filter` is empty, contains an unknown/inactive value
    37	#*     (the allowed active set is named in the error), or resolves fewer
    38	#*     than 2 genes.
    39	#*   - neither: the existing default all-NDD-genes universe.
    40	#* Supplying both `genes` and a non-empty `category_filter` is a 400.
    41	#*
    42	#* Every submit records selector/fingerprint provenance -- `selector`
    43	#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
    44	#* category runs), `resolved_gene_count`, `gene_list_sha256`,
    45	#* `intended_fingerprint`, and `source_data_version` -- in the durable job
    46	#* payload; the job result `meta` additionally carries `effective_fingerprint`
    47	#* (the STRING `weight_channel` actually observed on the computed result),
    48	#* recorded on both a cache-hit (immediate) response and a worker-run
    49	#* (cache-miss) job.
    50	#*
    51	#* Results from this endpoint (including category-filtered runs) are never
    52	#* `public_ready` -- they are ephemeral job results, distinct from the public
    53	#* `analysis_snapshot_*` layer.
    54	#*
    55	#* Returns immediately with job ID for status polling.
    56	#*
    57	#* @tag jobs
    58	#* @serializer json list(na="string")
    59	#* @param genes Optional JSON array of explicit HGNC ids. Mutually exclusive
    60	#*   with `category_filter`.
    61	#* @param category_filter Optional JSON array of curated SysNDD confidence
    62	#*   categories (e.g. `["Definitive"]`). Mutually exclusive with `genes`.
    63	#* @param algorithm Optional clustering algorithm string, `"leiden"`
    64	#*   (default) or `"walktrap"`.
    65	#* @post /clustering/submit
    66	function(req, res) {
    67	  svc_job_submit_functional_clustering(req, res)
    68	}
    69	
    70	## -------------------------------------------------------------------##
    71	## Phenotype Clustering Submission
    72	## -------------------------------------------------------------------##
    73	
    74	#* Submit Phenotype Clustering Job
    75	#*
    76	#* Submits an async job to compute phenotype clustering via MCA.
    77	#* Returns immediately with job ID for status polling.
    78	#*
    79	#* @tag jobs
    80	#* @serializer json list(na="string")
    81	#* @post /phenotype_clustering/submit
    82	function(req, res) {
    83	  svc_job_submit_phenotype_clustering(req, res)
    84	}
    85	
    86	## -------------------------------------------------------------------##
    87	## Ontology Update Submission
    88	## -------------------------------------------------------------------##
    89	
    90	#* Submit Ontology Update Job
    91	#*
    92	#* Submits an async job to update disease ontology data from MONDO and OMIM sources.
    93	#* Requires Administrator role.
    94	#* Returns immediately with job ID for status polling.
    95	#*
    96	#* @tag jobs
    97	#* @serializer json list(na="string")
    98	#* @post /ontology_update/submit
    99	function(req, res) {
   100	  require_role(req, res, "Administrator")
   101	  svc_job_submit_ontology_update(res)
   102	}
   103	
   104	## -------------------------------------------------------------------##
   105	## HGNC Data Update Submission
   106	## -------------------------------------------------------------------##
   107	
   108	#* Submit HGNC Data Update Job
   109	#*
   110	#* Submits an async job to download and update HGNC gene data.
   111	#* Requires Administrator role.
   112	#* Returns immediately with job ID for status polling.
   113	#*
   114	#* @tag jobs
   115	#* @serializer json list(na="string")
   116	#* @post /hgnc_update/submit
   117	function(req, res) {
   118	  require_role(req, res, "Administrator")
   119	  svc_job_submit_hgnc_update(res)
   120	}
   121	
   122	## -------------------------------------------------------------------##
   123	## Comparisons Data Update Submission
   124	## -------------------------------------------------------------------##
   125	
   126	#* Submit Comparisons Data Update Job
   127	#*
   128	#* Submits an async job to refresh the comparisons data from all external
   129	#* NDD databases (Radboud, Gene2Phenotype, PanelApp, SFARI, Geisinger,
   130	#* OMIM NDD, Orphanet).
   131	#*
   132	#* Requires Administrator role.
   133	#* Returns immediately with job ID for status polling.
   134	#*
   135	#* @tag jobs
   136	#* @serializer json list(na="string")
   137	#* @post /comparisons_update/submit
   138	function(req, res) {
   139	  require_role(req, res, "Administrator")
   140	  svc_job_submit_comparisons_update(res)
   141	}
   142	
   143	## -------------------------------------------------------------------##
   144	## Job History
   145	## -------------------------------------------------------------------##
   146	
   147	#* Get Job History
   148	#*
   149	#* Returns a list of recent jobs for admin review.
   150	#* Requires Administrator role.
   151	#*
   152	#* @tag jobs
   153	#* @serializer json list(na="string")
   154	#* @get /history
   155	function(req, res, limit = 20) {
   156	  require_role(req, res, "Administrator")
   157	  svc_job_get_history(limit)
   158	}
   159	
   160	## -------------------------------------------------------------------##
   161	## Job Status Polling
   162	## -------------------------------------------------------------------##
   163	
   164	#* Get Job Status
   165	#*
   166	#* Poll job status and retrieve results when complete.
   167	#* Returns Retry-After header for running jobs.
   168	#*
   169	#* @tag jobs
   170	#* @serializer json list(na="string", auto_unbox=TRUE)
   171	#* @get /<job_id>/status
   172	function(job_id, result_mode = "summary", req, res) {
   173	  svc_job_get_status(job_id, result_mode, req, res)
   174	}

===== api/bootstrap/load_modules.R =====
     1	## -------------------------------------------------------------------##
     2	# api/bootstrap/load_modules.R
     3	#
     4	# Part of the Phase D.D6 extract-bootstrap refactor.
     5	#
     6	# Loads every R source file required by the running API into the
     7	# global environment, in the correct order:
     8	#   1. functions/* (repositories, helpers, clients, etc.)
     9	#   2. core/* (security, errors, responses, middleware, filters)
    10	#   3. services/* (transactional orchestration)
    11	#
    12	# Source order matters. Repository functions are loaded BEFORE
    13	# services so that any `svc_`/`service_`-prefixed function in
    14	# services/* can still call the underlying repository helpers.
    15	# (A service that accidentally drops its prefix will shadow the
    16	# repository function — see CLAUDE.md.)
    17	#
    18	# Mirai daemon workers do NOT use this module. They re-source a
    19	# hand-picked subset of functions/* via `everywhere({...})` in
    20	# api/bootstrap/setup_workers.R. Changes here do not automatically
    21	# propagate to workers — update setup_workers.R as well when a
    22	# function file is needed inside a daemon.
    23	## -------------------------------------------------------------------##
    24	
    25	#' Source a file into .GlobalEnv with a helpful error if missing.
    26	#'
    27	#' `source(..., local = FALSE)` puts the bindings into the global
    28	#' environment — that is what endpoint files expect at runtime.
    29	#' Top-level `source("...", local = TRUE)` in start_sysndd_api.R
    30	#' previously had the same effect by accident of being at the top
    31	#' level of the script; here we make the intent explicit.
    32	#'
    33	#' @param path Relative path from api/ to the source file.
    34	#' @noRd
    35	.bootstrap_source <- function(path) {
    36	  if (!file.exists(path)) {
    37	    stop(sprintf("bootstrap: source file not found: %s", path))
    38	  }
    39	  source(path, local = FALSE)
    40	  invisible(NULL)
    41	}
    42	
    43	#' Load the full API source tree into the global environment.
    44	#'
    45	#' This is the explicit, auditable source list that used to live
    46	#' inline in start_sysndd_api.R between the markers
    47	#' `# --- function source list (v11.0) ---` and
    48	#' `# --- end source list ---`.
    49	#'
    50	#' @return A list describing which file groups were loaded (used
    51	#'   for logging / diagnostics). The side effect is that every
    52	#'   listed file is sourced into .GlobalEnv.
    53	#' @export
    54	bootstrap_load_modules <- function() {
    55	
    56	  # --- function source list (v11.0) ---
    57	  function_files <- c(
    58	    "functions/config-functions.R",
    59	    "functions/logging-functions.R",
    60	    "functions/db-helpers.R",
    61	    "functions/db-version.R",
    62	    "functions/metadata-refresh.R",
    63	    "functions/ontology-status-service.R",
    64	    "functions/async-job-repository.R",
    65	    "functions/async-job-db-config.R",
    66	    "functions/async-job-payload-scrub.R",
    67	    "functions/async-job-service.R",
    68	    "functions/per-caller-throttle.R",
    69	    "functions/clustering-submit-throttle.R",
    70	    "functions/auth-endpoint-throttle.R",
    71	    "functions/analysis-snapshot-presets.R",
    72	    "functions/analysis-snapshot-repository.R",
    73	    "functions/analysis-snapshot-prune-helpers.R",
    74	    "functions/analysis-snapshot-coherence.R",
    75	    "functions/analysis-snapshot-dependencies.R",
    76	    "functions/analysis-snapshot-builder.R",
    77	    "functions/analysis-reproducibility.R",
    78	    # Immutable, content-addressed public analysis-snapshot releases (#573
    79	    # Slice A). Synchronous admin/API-only build path (svc_release_build(),
    80	    # called directly from the admin endpoint) -- NOT a durable async-job
    81	    # handler and NOT a mirai daemon job, so (unlike the sibling
    82	    # analysis-snapshot-*.R files above) these are intentionally absent from
    83	    # bootstrap/setup_workers.R's mirai everywhere() block. Registered here
    84	    # only, which still covers the durable worker (start_async_worker.R) and
    85	    # the MCP sidecar (start_sysndd_mcp.R) via this shared loader. Order:
    86	    # manifest (content digest / canonical JSON / tar.gz) -> repository (DB
    87	    # CRUD) -> materialize (coherence assertions + file/README building) ->
    88	    # release (orchestrator, depends on all three).
    89	    "functions/analysis-snapshot-release-manifest.R",
    90	    "functions/analysis-snapshot-release-repository.R",
    91	    "functions/analysis-snapshot-release-materialize.R",
    92	    "functions/analysis-snapshot-release.R",
    93	    "functions/async-job-analysis-snapshot-handlers.R",
    94	    "functions/async-job-network-layout-handlers.R",
    95	    "functions/nddscore-import.R",
    96	    "functions/nddscore-repository.R",
    97	    "functions/nddscore-admin-endpoint-helpers.R",
    98	    "functions/entity-repository.R",
    99	    "functions/review-repository.R",
   100	    "functions/status-repository.R",
   101	    "functions/re-review-sync.R",
   102	    "functions/publication-repository.R",
   103	    "functions/phenotype-repository.R",
   104	    "functions/ontology-repository.R",
   105	    "functions/mcp-search-repository.R",
   106	    "functions/mcp-repository.R",
   107	    "functions/mcp-analysis-cache-repository.R",
   108	    "functions/mcp-analysis-repository.R",
   109	    "functions/user-repository.R",
   110	    "functions/user-endpoint-helpers.R",
   111	    "functions/hash-repository.R",
   112	    "functions/metadata-vocabulary-repository.R",
   113	    "functions/category-normalization.R",
   114	    "functions/phenotype-endpoint-functions.R",
   115	    "functions/panels-endpoint-functions.R",
   116	    "functions/endpoint-functions.R",
   117	    "functions/comparisons-list.R",
   118	    # Comparisons refresh write-path (durable `comparisons_update` job). These
   119	    # were historically only loaded into the mirai daemon pool via
   120	    # setup_workers.R, but create_job() now submits comparisons_update as a
   121	    # durable System B job, so the async worker (which loads via this list) must
   122	    # define comparisons_update_async() and its helpers too. Order: sources +
   123	    # parsers + omim before comparisons-functions.R (which uses them).
   124	    "functions/omim-functions.R",
   125	    "functions/comparisons-sources.R",
   126	    "functions/comparisons-parsers.R",
   127	    "functions/comparisons-omim.R",
   128	    "functions/comparisons-functions.R",
   129	    "functions/publication-endpoint-helpers.R",
   130	    "functions/pubmed-xml-parser.R",
   131	    "functions/publication-functions.R",
   132	    "functions/publication-date-backfill.R",
   133	    "functions/genereviews-functions.R",
   134	    "functions/analysis-string-channels.R",
   135	    "functions/analysis-cache-fingerprint.R",
   136	    "functions/analyses-functions.R",
   137	    # Category-selected clustering gene-universe resolver (#574). Depends on
   138	    # generate_ndd_hgnc_ids() (analyses-functions.R, above) and
   139	    # stop_for_bad_request() (core/errors.R, sourced after function_files by
   140	    # this same bootstrap_load_modules() call) -- registered before the
   141	    # submission service that will consume it.
   142	    "functions/clustering-gene-universe.R",
   143	    "functions/analysis-phenotype-mca-prep.R",
   144	    "functions/analysis-phenotype-functions.R",
   145	    "functions/analysis-null-models.R",
   146	    "functions/analysis-cluster-validation.R",
   147	    "functions/analysis-network-layout-functions.R",
   148	    "functions/analysis-network-functions.R",
   149	    "functions/account-helpers.R",
   150	    "functions/data-helpers.R",
   151	    "functions/entity-helpers.R",
   152	    "functions/response-helpers.R",
   153	    "functions/response-fields-helpers.R",
   154	    "functions/email-templates.R",
   155	    "functions/pagination-helpers.R",
   156	    "functions/external-proxy-functions.R",
   157	    "functions/external-proxy-gnomad.R",
   158	    "functions/external-proxy-gnomad-batch.R",
   159	    "functions/external-proxy-uniprot.R",
   160	    "functions/external-proxy-ensembl.R",
   161	    "functions/external-proxy-alphafold.R",
   162	    "functions/external-proxy-mgi.R",
   163	    "functions/external-proxy-rgd.R",
   164	    "functions/genereviews-lookup.R",
   165	    "functions/file-functions.R",
   166	    "functions/hpo-functions.R",
   167	    "functions/hgnc-functions.R",
   168	    "functions/hgnc-enrichment-gnomad.R",
   169	    "functions/llm-summary-config.R",
   170	    "functions/llm-cache-repository.R",
   171	    "functions/llm-cache-admin-repository.R",
   172	    "functions/llm-validation.R",
   173	    "functions/llm-model-config.R",
   174	    "functions/llm-client.R",
   175	    "functions/llm-rate-limiter.R",
   176	    "functions/llm-types.R",
   177	    "functions/llm-prompt-template-repository.R",
   178	    "functions/llm-service.R",
   179	    "functions/llm-judge-prompts.R",
   180	    "functions/llm-judge.R",
   181	    "functions/llm-batch-cluster-data.R",
   182	    "functions/llm-batch-generator.R",
   183	    "functions/llm-regenerate-helpers.R",
   184	    "functions/mondo-index-builder.R",
   185	    "functions/disease-ontology-mapping-builder.R",
   186	    "functions/disease-ontology-mapping-repository.R",
   187	    "functions/disease-ontology-mapping-refresh.R",
   188	    "functions/ontology-functions.R",
   189	    "functions/ontology-object.R",
   190	    "functions/pubtator-client.R",
   191	    "functions/pubtator-parser.R",
   192	    "functions/pubtator-functions.R",
   193	    "functions/pubtator-enrichment-metrics.R",
   194	    "functions/pubtator-enrichment-collector.R",
   195	    "functions/pubtator-gene-summary.R",
   196	    "functions/pubtatornidd-nightly.R",
   197	    "functions/ensembl-functions.R",
   198	    "functions/job-manager.R",
   199	    "functions/job-progress.R",
   200	    "functions/backup-functions.R",
   201	    "functions/ols-functions.R",
   202	    "functions/openapi-helpers.R",
   203	    "functions/migration-manifest.R",
   204	    "functions/migration-runner.R"
   205	  )
   206	  # --- end source list ---
   207	
   208	  core_files <- c(
   209	    "core/security.R",
   210	    "core/errors.R",
   211	    "core/responses.R",
   212	    "core/logging_sanitizer.R",
   213	    "core/middleware.R",
   214	    "core/filters.R"
   215	  )
   216	
   217	  service_files <- c(
   218	    "services/auth-service.R",
   219	    "services/user-service.R",
   220	    "services/status-service.R",
   221	    "services/metadata-vocabulary-service.R",
   222	    "services/search-service.R",
   223	    "services/entity-service.R",
   224	    "services/entity-creation-service.R",
   225	    "services/entity-rename-service.R",
   226	    "services/review-service.R",
   227	    "services/genereviews-service.R",
   228	    "services/approval-service.R",
   229	    "services/re-review-selection-service.R",
   230	    "services/re-review-service.R",
   231	    "services/re-review-refusal-service.R",
   232	    "services/seo-service.R",
   233	    "services/analysis-snapshot-service.R",
   234	    "services/analysis-snapshot-refresh-service.R",
   235	    "services/analysis-snapshot-release-service.R",
   236	    "services/disease-ontology-mapping-service.R",
   237	    "services/mcp-service.R",
   238	    "services/mcp-analysis-shaping.R",
   239	    "services/mcp-query-service.R",
   240	    "services/mcp-record-service.R",
   241	    "services/mcp-analysis-service.R",
   242	    "services/mcp-analysis-llm-cache-service.R",
   243	    "services/mcp-research-context-service.R",
   244	    "services/mcp-capabilities-service.R",
   245	    "services/mcp-tool-core.R",
   246	    "services/mcp-tool-resources.R",
   247	    "services/mcp-tools.R",
   248	    "services/mcp-tool-analysis-registry.R",
   249	    "services/mcp-tool-registry.R",
   250	    # --- #346 Wave 3: endpoint-delegation services (svc_-prefixed). These are
   251	    # sourced by the API and the durable worker via this shared loader, but are
   252	    # never registered as job handlers or called by worker execution. They only
   253	    # depend on functions/* and the domain services above, so they are appended
   254	    # last (definition order is irrelevant; none call each other at source time).
   255	    "services/publication-query-endpoint-service.R",
   256	    "services/publication-admin-endpoint-service.R",
   257	    "services/user-read-endpoint-service.R",
   258	    "services/user-account-endpoint-service.R",
   259	    "services/user-password-profile-endpoint-service.R",
   260	    "services/user-bulk-endpoint-service.R",
   261	    "services/admin-ontology-endpoint-service.R",
   262	    "services/admin-diagnostics-endpoint-service.R",
   263	    "services/admin-nddscore-endpoint-service.R",
   264	    "services/admin-publication-refresh-endpoint-service.R",
   265	    "services/job-functional-submission-service.R",
   266	    "services/job-phenotype-submission-service.R",
   267	    "services/job-maintenance-submission-service.R",
   268	    "services/job-query-endpoint-service.R",
   269	    "services/re-review-query-endpoint-service.R",
   270	    "services/re-review-workflow-endpoint-service.R",
   271	    "services/entity-read-endpoint-service.R",
   272	    "services/entity-submission-endpoint-service.R",
   273	    "services/statistics-public-endpoint-service.R",
   274	    "services/statistics-admin-endpoint-service.R",
   275	    "services/llm-admin-endpoint-service.R",
   276	    "services/backup-endpoint-service.R"
   277	  )
   278	
   279	  for (path in function_files) .bootstrap_source(path)
   280	  for (path in core_files) .bootstrap_source(path)
   281	  for (path in service_files) .bootstrap_source(path)
   282	
   283	  list(
   284	    functions = length(function_files),
   285	    core = length(core_files),
   286	    services = length(service_files)
   287	  )
   288	}

exec
/bin/bash -lc "nl -ba api/services/job-functional-submission-service.R | sed -n '1,220p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# api/services/job-functional-submission-service.R
     2	#
     3	# Body of `POST /api/jobs/clustering/submit`, extracted from
     4	# endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5). Public endpoint —
     5	# no role gate. The endpoint shell delegates the entire handler body here;
     6	# `svc_job_submit_functional_clustering()` mutates `res` (status + headers)
     7	# exactly as the inline handler used to, and returns the JSON payload.
     8	#
     9	# The durable handler receives serialized input, not a database connection, so
    10	# all values it needs are fetched from `pool` before `create_job()` is called.
    11	#
    12	# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
    13	# (api/bootstrap/load_modules.R) like any other services/* file. The worker
    14	# executes the registered `clustering` durable handler, never this submitter.
    15	
    16	#' Submit a functional (STRING-db) clustering job.
    17	#'
    18	#' Cache-first: if the memoised `gen_string_clust_obj_mem()` already has a
    19	#' result for the resolved gene list + algorithm, the result is persisted as
    20	#' an already-completed durable job via `async_job_service_store_completed()`
    21	#' so the response shape matches a freshly-submitted job (this keeps LLM batch
    22	#' generation on the same job/result hashes as the API-served table). A cache
    23	#' miss falls through the public queue-depth capacity guard
    24	#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
    25	#' new durable job via `create_job()`.
    26	#'
    27	#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
    28	#' curated-category selection via `category_filter` (resolved through
    29	#' `clustering_resolve_category_universe()`), or -- when neither is supplied
    30	#' -- the existing default all-NDD-genes universe. `genes` and
    31	#' `category_filter` are mutually exclusive (400 if both are present). Every
    32	#' submit records selector + fingerprint provenance in the durable payload
    33	#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
    34	#'
    35	#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
    36	#'   `category_filter` and `req$user$user_id`).
    37	#' @param res Plumber response, mutated in place (status + headers).
    38	#' @return List payload for the `json` serializer.
    39	#' @export
    40	svc_job_submit_functional_clustering <- function(req, res) {
    41	  # Guard FIRST (#535 S6): per-caller submit admission throttle, applied before any
    42	  # DB/cache/duplicate work so an abusive caller is rejected before it can do — or
    43	  # provoke — expensive work (a cache hit still writes a completed job row, and the
    44	  # duplicate/data fetch below touch the DB). Layered on the global capacity cap.
    45	  admission <- async_job_submit_admission_guard(req, res)
    46	  if (!isTRUE(admission$admitted)) {
    47	    return(admission$response)
    48	  }
    49	
    50	  # Extract request data before durable submission.
    51	
    52	  # Connection objects cannot cross process boundaries. `genes` and
    53	  # `category_filter` are mutually exclusive gene-universe selectors (#574):
    54	  # an explicit gene list, a curated-category selection, or (both absent) the
    55	  # existing default all-NDD-genes universe.
    56	  genes_in <- req$argsBody$genes
    57	  has_genes <- !is.null(genes_in) && length(genes_in) > 0
    58	
    59	  # Selector presence is gated on JSON KEY PRESENCE (`names(req$argsBody)`), not
    60	  # value-nullness or length: `!is.null()` cannot distinguish an ABSENT key from
    61	  # an explicit JSON `null` (both parse to NULL in R). So a present `genes` key
    62	  # (`{"genes":null,...}` / `{"genes":[],...}`) and a present `category_filter`
    63	  # key each drive their guard regardless of value (Codex rounds 2 & 4). Mutual
    64	  # exclusion 400s when BOTH keys are present; a present-but-null/empty
    65	  # `category_filter` is a supplied-empty 400 (in the branch below), never a
    66	  # silent fall-through to the all-NDD default. `has_genes` (value-based,
    67	  # non-empty) still selects the explicit-genes branch.
    68	  body_names <- names(req$argsBody)
    69	  genes_key <- "genes" %in% body_names
    70	  category_key <- "category_filter" %in% body_names
    71	
    72	  if (genes_key && category_key) {
    73	    stop_for_bad_request("Provide either genes or category_filter, not both")
    74	  }
    75	
    76	  # Extract algorithm parameter (default: leiden)
    77	  # Ensure we get a scalar value (JSON may pass arrays)
    78	  algorithm <- "leiden"
    79	  if (!is.null(req$argsBody$algorithm)) {
    80	    algo_input <- req$argsBody$algorithm
    81	    # Handle array input - always take first element if vector
    82	    if (is.list(algo_input) || length(algo_input) >= 1) {
    83	      algo_input <- algo_input[[1]]
    84	    }
    85	    algorithm <- tolower(as.character(algo_input))
    86	    if (!algorithm %in% c("leiden", "walktrap")) {
    87	      algorithm <- "leiden"
    88	    }
    89	  }
    90	
    91	  # Resolve the clustering gene universe + selector provenance (#574). The
    92	  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
    93	  # from before this feature: `clustering_resolve_category_universe(NULL)`
    94	  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
    95	  # so cache parity (memoise key = gene set + algorithm) is preserved.
    96	  selector_chr <- NULL
    97	  if (has_genes) {
    98	    genes_list <- as.character(unlist(genes_in))
    99	    kind <- "explicit"
   100	  } else if (category_key) {
   101	    # A present category_filter key means a category run. A present-but-null
   102	    # value is supplied-but-empty (a NULL would otherwise hit the resolver's
   103	    # absent->default branch), so it is coerced to an empty selector here and
   104	    # delegated to the resolver -- the resolver's supplied-empty branch 400s
   105	    # it (with the allowed active-category set in the message), keeping the
   106	    # 400 message construction in the single resolver source of truth.
   107	    cf <- req$argsBody$category_filter
   108	    if (is.null(cf)) cf <- list()
   109	    universe <- clustering_resolve_category_universe(cf)
   110	    genes_list <- universe$hgnc_ids
   111	    selector_chr <- universe$selector
   112	    kind <- "category"
   113	  } else {
   114	    universe <- clustering_resolve_category_universe(NULL)
   115	    genes_list <- universe$hgnc_ids
   116	    kind <- "all_ndd"
   117	  }
   118	
   119	  # Pre-fetch the STRING ID table because DB connections cannot cross the
   120	  # durable worker boundary.
   121	  string_id_table <- pool %>%
   122	    dplyr::tbl("non_alt_loci_set") %>%
   123	    dplyr::filter(!is.na(STRING_id)) %>%
   124	    dplyr::select(symbol, hgnc_id, STRING_id) %>%
   125	    dplyr::collect()
   126	
   127	  # Check for duplicate job (include algorithm in check). The selector is
   128	  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
   129	  # submits keep the pre-#574 dedup identity byte-identical.
   130	  dup_params <- list(genes = genes_list, algorithm = algorithm)
   131	  if (!is.null(selector_chr)) {
   132	    dup_params$category_filter <- selector_chr
   133	  }
   134	  dup_check <- check_duplicate_job("clustering", dup_params)
   135	  if (dup_check$duplicate) {
   136	    res$status <- 409
   137	    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
   138	    return(list(
   139	      error = "DUPLICATE_JOB",
   140	      message = "Identical job already running",
   141	      existing_job_id = dup_check$existing_job_id,
   142	      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
   143	    ))
   144	  }
   145	
   146	  # Cheap-path provenance (no expensive query yet). `selector_obj` records
   147	  # WHICH universe was resolved; `intended_fingerprint` records the STRING
   148	  # cache identity + fixed clustering params this submit intends to run
   149	  # with. The *effective* fingerprint (e.g. the STRING weight channel a
   150	  # computed result actually used) is only knowable from a computed result,
   151	  # so it is recorded separately in the cache-hit result meta below.
   152	  selector_obj <- list(kind = kind, category_filter = selector_chr)
   153	  intended_fingerprint <- list(
   154	    string_cache_fingerprint = analysis_string_cache_fingerprint(),
   155	    score_threshold = 400L,
   156	    algorithm = algorithm,
   157	    seed = 42L
   158	  )
   159	  gene_sha <- clustering_gene_list_sha256(genes_list)
   160	  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
   161	  # count must agree with it, so it is computed from the SAME dedup -- an
   162	  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
   163	  # not report a resolved count that disagrees with a singleton sha256. This
   164	  # never dedups the payload `genes` list itself (`genes_list` stays
   165	  # byte-identical to the raw request) -- only the reported COUNT (Codex
   166	  # review fix).
   167	  resolved_count <- length(unique(genes_list))
   168	
   169	  # Source-data version: a CACHED, fail-closed read, fetched only now that a
   170	  # payload is actually about to be built -- its backing view runs global
   171	  # counts/joins, so it must never run before admission/dedup. A lookup
   172	  # failure must never silently record NA/broken provenance; fail the
   173	  # request closed instead.
   174	  src_ver <- tryCatch(
   175	    clustering_cached_source_data_version(conn = pool),
   176	    error = function(e) e
   177	  )
   178	  if (inherits(src_ver, "error")) {
   179	    res$status <- 503L
   180	    return(list(
   181	      error = "PROVENANCE_UNAVAILABLE",
   182	      message = "Snapshot source-data version unavailable; retry shortly."
   183	    ))
   184	  }
   185	
   186	  provenance <- list(
   187	    selector = selector_obj,
   188	    resolved_gene_count = resolved_count,
   189	    gene_list_sha256 = gene_sha,
   190	    intended_fingerprint = intended_fingerprint,
   191	    source_data_version = src_ver
   192	  )
   193	
   194	  # Define category links (needed for result)
   195	  category_links <- tibble::tibble(
   196	    value = c(
   197	      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
   198	      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
   199	      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
   200	    ),
   201	    link = c(
   202	      "https://www.ebi.ac.uk/QuickGO/term/",
   203	      "https://www.ebi.ac.uk/QuickGO/term/",
   204	      "https://disease-ontology.org/term/",
   205	      "https://www.ebi.ac.uk/QuickGO/term/",
   206	      "https://hpo.jax.org/browse/term/",
   207	      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
   208	      "https://www.genome.jp/dbget-bin/www_bget?",
   209	      "https://www.uniprot.org/keywords/",
   210	      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
   211	      "https://www.ebi.ac.uk/interpro/entry/pfam/",
   212	      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
   213	      "https://www.ebi.ac.uk/QuickGO/term/",
   214	      "https://reactome.org/content/detail/R-",
   215	      "http://www.ebi.ac.uk/interpro/entry/smart/",
   216	      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
   217	      "https://www.wikipathways.org/index.php/Pathway:"
   218	    )
   219	  )
   220	

exec
/bin/bash -lc "nl -ba api/services/job-functional-submission-service.R | sed -n '221,440p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
   221	  # Cache-first: if the memoized function already has a cached result,
   222	  # return it immediately without submitting a durable worker job.
   223	  # The network_edges endpoint (graph) warms this cache on first load,
   224	  # so subsequent table requests resolve instantly.
   225	  cache_hit <- tryCatch(
   226	    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
   227	    error = function(e) FALSE
   228	  )
   229	
   230	  if (cache_hit) {
   231	    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
   232	
   233	    categories <- cached_clusters %>%
   234	      dplyr::select(term_enrichment) %>%
   235	      tidyr::unnest(cols = c(term_enrichment)) %>%
   236	      dplyr::select(category) %>%
   237	      unique() %>%
   238	      dplyr::arrange(category) %>%
   239	      dplyr::mutate(
   240	        text = dplyr::case_when(
   241	          nchar(category) <= 5 ~ category,
   242	          nchar(category) > 5 ~ stringr::str_to_sentence(category)
   243	        )
   244	      ) %>%
   245	      dplyr::select(value = category, text) %>%
   246	      dplyr::left_join(category_links, by = c("value"))
   247	
   248	    # Splice the base cache-hit fields with `provenance` (already assembled
   249	    # above as selector/resolved_gene_count/gene_list_sha256/
   250	    # intended_fingerprint/source_data_version) via the shared
   251	    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
   252	    # re-listing the same fields as duplicate literals -- keeps this shape in
   253	    # lockstep with the worker-run handler's result meta by construction.
   254	    # `effective_fingerprint` is only knowable from the computed result
   255	    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
   256	    cache_result <- list(
   257	      clusters = cached_clusters,
   258	      categories = categories,
   259	      meta = clustering_result_meta(
   260	        list(
   261	          algorithm = algorithm,
   262	          gene_count = resolved_count,
   263	          cluster_count = nrow(cached_clusters),
   264	          cache_hit = TRUE
   265	        ),
   266	        provenance,
   267	        attr(cached_clusters, "weight_channel")
   268	      )
   269	    )
   270	    cache_request_payload <- list(
   271	      genes = genes_list,
   272	      algorithm = algorithm,
   273	      category_links = category_links,
   274	      string_id_table = string_id_table,
   275	      provenance = provenance
   276	    )
   277	    if (!is.null(selector_chr)) {
   278	      cache_request_payload$category_filter <- selector_chr
   279	    }
   280	    # Dedup identity EXCLUDES provenance (Codex round 3): `provenance`
   281	    # carries a time-varying `source_data_version` and STRING cache
   282	    # `intended_fingerprint`, so hashing the full payload would make the
   283	    # active-job uniqueness guard admit duplicate concurrent clustering work
   284	    # across a deploy/cache-TTL change and break the byte-identical
   285	    # explicit/no-arg `request_hash` contract predating #574. Removing the
   286	    # `provenance` key preserves the leading `genes, algorithm,
   287	    # category_links, string_id_table[, category_filter]` key order -- it was
   288	    # appended last, so deleting it does not reorder the rest.
   289	    cache_hash_payload <- cache_request_payload
   290	    cache_hash_payload$provenance <- NULL
   291	    completed_job <- async_job_service_store_completed(
   292	      job_type = "clustering",
   293	      request_payload = cache_request_payload,
   294	      result = cache_result,
   295	      submitted_by = req$user$user_id %||% NULL,
   296	      queue_name = "analysis",
   297	      priority = 50L,
   298	      hash_payload = cache_hash_payload
   299	    )
   300	    job_id <- completed_job$job_id[[1]]
   301	
   302	    res$status <- 202
   303	    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   304	    res$setHeader("Retry-After", "0")
   305	
   306	    return(list(
   307	      job_id = job_id,
   308	      status = "accepted",
   309	      estimated_seconds = 0,
   310	      status_url = paste0("/api/jobs/", job_id, "/status"),
   311	      meta = list(llm_generation = "snapshot_refresh_owned")
   312	    ))
   313	  }
   314	
   315	  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   316	  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   317	  if (async_job_capacity_exceeded(
   318	        tryCatch(
   319	          async_job_active_count("default"),
   320	          error = function(e) {
   321	            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
   322	            0L
   323	          }
   324	        )
   325	      )) {
   326	    res$status <- 503
   327	    res$setHeader("Retry-After", "60")
   328	    return(list(
   329	      error = "CAPACITY_EXCEEDED",
   330	      message = "Analysis queue is at capacity. Please retry shortly.",
   331	      retry_after = 60
   332	    ))
   333	  }
   334	
   335	  # Cache miss - create async job
   336	  job_params <- list(
   337	    genes = genes_list,
   338	    algorithm = algorithm,
   339	    category_links = category_links,
   340	    string_id_table = string_id_table,
   341	    provenance = provenance
   342	  )
   343	  if (!is.null(selector_chr)) {
   344	    job_params$category_filter <- selector_chr
   345	  }
   346	  # See the cache-hit branch above: dedup identity EXCLUDES provenance so the
   347	  # active-job uniqueness guard is not defeated by its time-varying fields,
   348	  # and explicit/no-arg submits stay byte-identical to pre-#574.
   349	  #
   350	  # `create_job()` carries a deliberately guarded 2-arg contract
   351	  # (`operation`, `params`) -- it cannot take a hash override. This path
   352	  # calls `async_job_service_submit()` directly instead (mirroring the
   353	  # cache-hit branch above, which already calls
   354	  # `async_job_service_store_completed()` directly for the same reason), so
   355	  # `hash_payload` can diverge from the stored `request_payload` without
   356	  # touching `create_job()`'s contract.
   357	  hash_params <- job_params
   358	  hash_params$provenance <- NULL
   359	  submitted <- async_job_service_submit(
   360	    job_type = "clustering",
   361	    request_payload = job_params,
   362	    hash_payload = hash_params,
   363	    submitted_by = req$user$user_id %||% NULL
   364	  )
   365	  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL
   366	
   367	  # Success - return HTTP 202 Accepted
   368	  res$status <- 202
   369	  res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   370	  res$setHeader("Retry-After", "5")
   371	
   372	  list(
   373	    job_id = job_id,
   374	    status = "accepted",
   375	    estimated_seconds = 30,
   376	    status_url = paste0("/api/jobs/", job_id, "/status")
   377	  )
   378	}

exec
/bin/bash -lc "nl -ba api/functions/async-job-handlers.R | sed -n '1,240p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# api/functions/async-job-handlers.R
     2	#
     3	# Durable async job handler shell (#346 Wave 4 split): common
     4	# payload/progress/clustering helpers, the legacy-executor passthrough
     5	# factory, the `async_job_handler_registry` list, and the
     6	# `async_job_get_handler()` lookup.
     7	#
     8	# Family-specific handler definitions live in sibling files sourced BEFORE
     9	# this one at every worker entrypoint, because the registry list below
    10	# references handler functions by bare symbol and R evaluates a list()
    11	# literal's elements eagerly at construction time:
    12	#   - functions/async-job-network-layout-handlers.R (network_layout_prewarm)
    13	#   - functions/async-job-analysis-snapshot-handlers.R (analysis_snapshot_refresh)
    14	#   - functions/async-job-omim-apply.R (OMIM DB-write / additive-terms helpers)
    15	#   - functions/async-job-force-apply-payload.R (force-apply payload-shape helpers)
    16	#   - functions/async-job-provider-handlers.R (HGNC, PubTator, NDDScore,
    17	#     disease-ontology mapping, OMIM update, force-apply-ontology)
    18	#   - functions/async-job-maintenance-handlers.R (backup create/restore,
    19	#     publication refresh/backfill)
    20	# Restart the worker container after changing any of these (worker-executed
    21	# code is sourced once at startup).
    22	# NOTE: .async_job_run_clustering assembles its result meta via
    23	# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
    24	# worker/API entrypoint sources that module via bootstrap_load_modules() before
    25	# this file; a direct-source test env must source it too (as the async-job tests do).
    26	
    27	.async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
    28	  invisible(result)
    29	}
    30	.async_job_or <- function(value, fallback) {
    31	  if (is.null(value) || length(value) == 0) {
    32	    return(fallback)
    33	  }
    34	
    35	  value
    36	}
    37	.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
    38	  if (!exists("create_async_job_progress_reporter", mode = "function")) {
    39	    stop("create_async_job_progress_reporter() is required for durable async job handlers", call. = FALSE)
    40	  }
    41	
    42	  create_async_job_progress_reporter(job_id, throttle_seconds = throttle_seconds)
    43	}
    44	.async_job_payload_field <- function(payload, field, required = TRUE, default = NULL) {
    45	  value <- payload[[field]]
    46	
    47	  if (is.null(value)) {
    48	    if (isTRUE(required)) {
    49	      stop(sprintf("Async job payload is missing required field '%s'", field), call. = FALSE)
    50	    }
    51	
    52	    return(default)
    53	  }
    54	
    55	  value
    56	}
    57	.async_job_payload_scalar <- function(payload, field, required = TRUE, default = NULL) {
    58	  value <- .async_job_payload_field(payload, field, required = required, default = default)
    59	
    60	  if (is.null(value)) {
    61	    return(value)
    62	  }
    63	
    64	  if (is.list(value)) {
    65	    value <- value[[1]]
    66	  }
    67	
    68	  value[[1]]
    69	}
    70	
    71	.async_job_add_job_id <- function(payload, job) {
    72	  payload$.__job_id__ <- job$job_id[[1]]
    73	  payload
    74	}
    75	
    76	.async_job_functional_categories <- function(clusters, category_links) {
    77	  categories <- clusters |>
    78	    dplyr::select(term_enrichment) |>
    79	    tidyr::unnest(cols = c(term_enrichment)) |>
    80	    dplyr::select(category) |>
    81	    unique() |>
    82	    dplyr::arrange(category) |>
    83	    dplyr::mutate(
    84	      text = dplyr::case_when(
    85	        nchar(category) <= 5 ~ category,
    86	        nchar(category) > 5 ~ stringr::str_to_sentence(category)
    87	      )
    88	    ) |>
    89	    dplyr::select(value = category, text)
    90	
    91	  if (!is.null(category_links)) {
    92	    categories <- dplyr::left_join(categories, category_links, by = c("value"))
    93	  }
    94	
    95	  categories
    96	}
    97	
    98	.async_job_run_clustering <- function(job, payload, state, worker_config) {
    99	  genes <- .async_job_payload_field(payload, "genes")
   100	  algorithm <- .async_job_payload_scalar(payload, "algorithm")
   101	  string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
   102	  category_links <- .async_job_payload_field(payload, "category_links", required = FALSE)
   103	  # #574 D3: the cheap-path selector/fingerprint provenance the submit
   104	  # service (job-functional-submission-service.R) recorded in the payload.
   105	  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
   106	  # FALSE) so a worker-run job for those still completes normally.
   107	  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
   108	  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
   109	
   110	  progress("cluster", "Running functional clustering...", current = 0, total = 1)
   111	
   112	  clusters <- gen_string_clust_obj(
   113	    genes,
   114	    algorithm = algorithm,
   115	    string_id_table = string_id_table
   116	  )
   117	
   118	  progress("complete", "Functional clustering complete", current = 1, total = 1)
   119	
   120	  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
   121	  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
   122	  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
   123	  # path), then the request's cheap-path `provenance` (selector/
   124	  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
   125	  # source_data_version) when present, then the `effective_fingerprint` --
   126	  # only knowable now that `clusters` has actually been computed -- so a
   127	  # silent exp+db -> combined-score STRING fallback on a worker-run job is
   128	  # visible in the stored result too, not just a cache hit's.
   129	  # gene_count is the DISTINCT gene count, matching the cache-hit path's
   130	  # `resolved_count <- length(unique(genes_list))` (job-functional-submission-
   131	  # service.R) -- for `["HGNC:1","HGNC:1"]` a raw `length(genes)` reported 2
   132	  # here while the cache-hit path reported 1 for the identical payload
   133	  # (Codex round-2 review fix). This never dedups the payload `genes` list
   134	  # itself or changes `nrow(clusters)`, only the reported count.
   135	  meta <- clustering_result_meta(
   136	    list(
   137	      algorithm = algorithm,
   138	      gene_count = length(unique(genes)),
   139	      cluster_count = nrow(clusters),
   140	      cache_hit = FALSE
   141	    ),
   142	    provenance,
   143	    attr(clusters, "weight_channel")
   144	  )
   145	
   146	  list(
   147	    clusters = clusters,
   148	    categories = .async_job_functional_categories(clusters, category_links),
   149	    meta = meta
   150	  )
   151	}
   152	
   153	.async_job_chain_llm <- function(result, job, cluster_type) {
   154	  if (!exists("trigger_llm_batch_generation", mode = "function")) {
   155	    return(invisible(result))
   156	  }
   157	
   158	  llm_clusters <- result
   159	
   160	  if (is.list(result) && "clusters" %in% names(result) && !is.null(result[["clusters"]])) {
   161	    llm_clusters <- result[["clusters"]]
   162	  }
   163	
   164	  trigger_llm_batch_generation(
   165	    clusters = llm_clusters,
   166	    cluster_type = cluster_type,
   167	    parent_job_id = job$job_id[[1]]
   168	  )
   169	
   170	  invisible(result)
   171	}
   172	
   173	.async_job_phenotype_matrix <- function(payload) {
   174	  sysndd_db_phenotypes <- payload$ndd_entity_view_tbl |>
   175	    dplyr::left_join(payload$ndd_review_phenotype_connect_tbl, by = "entity_id") |>
   176	    dplyr::left_join(payload$modifier_list_tbl, by = "modifier_id") |>
   177	    dplyr::left_join(payload$phenotype_list_tbl, by = "phenotype_id") |>
   178	    dplyr::mutate(ndd_phenotype = dplyr::case_when(
   179	      ndd_phenotype == 1 ~ "Yes",
   180	      ndd_phenotype == 0 ~ "No",
   181	      TRUE ~ ndd_phenotype
   182	    )) |>
   183	    dplyr::filter(ndd_phenotype == "Yes") |>
   184	    dplyr::filter(category %in% payload$categories) |>
   185	    dplyr::filter(modifier_name == "present") |>
   186	    dplyr::filter(review_id %in% payload$ndd_entity_review_tbl$review_id) |>
   187	    dplyr::select(
   188	      entity_id, hpo_mode_of_inheritance_term_name, phenotype_id,
   189	      HPO_term, hgnc_id
   190	    ) |>
   191	    dplyr::group_by(entity_id) |>
   192	    dplyr::mutate(
   193	      phenotype_non_id_count = sum(!(phenotype_id %in% payload$id_phenotype_ids)),
   194	      phenotype_id_count = sum(phenotype_id %in% payload$id_phenotype_ids)
   195	    ) |>
   196	    dplyr::ungroup() |>
   197	    unique()
   198	
   199	  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes |>
   200	    dplyr::mutate(present = "yes") |>
   201	    dplyr::select(-phenotype_id) |>
   202	    tidyr::pivot_wider(names_from = HPO_term, values_from = present) |>
   203	    dplyr::group_by(hgnc_id) |>
   204	    dplyr::mutate(gene_entity_count = dplyr::n()) |>
   205	    dplyr::ungroup() |>
   206	    dplyr::relocate(gene_entity_count, .after = phenotype_id_count) |>
   207	    dplyr::select(-hgnc_id)
   208	
   209	  phenotype_df <- sysndd_db_phenotypes_wider |>
   210	    dplyr::select(-entity_id) |>
   211	    as.data.frame()
   212	  row.names(phenotype_df) <- sysndd_db_phenotypes_wider$entity_id
   213	
   214	  # #508 MCA feature hygiene via the shared helper (same as
   215	  # generate_phenotype_cluster_input) so the interactive/durable clustering job
   216	  # produces the cleaned partition and can't diverge from the public snapshot.
   217	  phenotype_df <- phenotype_mca_prep_matrix(
   218	    phenotype_df,
   219	    hpo_lookup = dplyr::select(payload$phenotype_list_tbl, HPO_term, phenotype_id)
   220	  )
   221	
   222	  phenotype_df
   223	}
   224	
   225	.async_job_run_phenotype_clustering <- function(job, payload, state, worker_config) {
   226	  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
   227	
   228	  progress("prepare_matrix", "Preparing phenotype matrix...", current = 0, total = 2)
   229	  phenotype_matrix <- .async_job_phenotype_matrix(payload)
   230	  progress("cluster", "Running phenotype clustering...", current = 1, total = 2)
   231	  phenotype_clusters <- gen_mca_clust_obj(phenotype_matrix)
   232	  progress("complete", "Phenotype clustering complete", current = 2, total = 2)
   233	
   234	  identifiers <- payload$ndd_entity_view_tbl |>
   235	    dplyr::select(entity_id, hgnc_id, symbol)
   236	
   237	  phenotype_clusters |>
   238	    tidyr::unnest(identifiers) |>
   239	    dplyr::mutate(entity_id = as.integer(entity_id)) |>
   240	    dplyr::left_join(identifiers, by = "entity_id") |>

exec
/bin/bash -lc "nl -ba api/functions/async-job-handlers.R | sed -n '241,520p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
   241	    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
   242	}
   243	
   244	.async_job_run_ontology_update <- function(job, payload, state, worker_config) {
   245	  progress <- .async_job_progress_reporter(job$job_id[[1]])
   246	
   247	  progress("init", "Preparing ontology update", current = 0, total = 4)
   248	  disease_ontology_set <- process_combine_ontology(
   249	    hgnc_list = payload$hgnc_list,
   250	    mode_of_inheritance_list = payload$mode_of_inheritance_list,
   251	    max_file_age = 0,
   252	    output_path = "data/",
   253	    progress_callback = progress
   254	  )
   255	  progress("complete", "Ontology update complete", current = 4, total = 4)
   256	
   257	  list(
   258	    status = "completed",
   259	    rows_processed = nrow(disease_ontology_set),
   260	    sources = c("MONDO", "OMIM"),
   261	    output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
   262	  )
   263	}
   264	
   265	.async_job_run_passthrough <- function(fn_name) {
   266	  force(fn_name)
   267	
   268	  function(job, payload, state, worker_config) {
   269	    fn <- base::get(fn_name, mode = "function")
   270	    fn(.async_job_add_job_id(payload, job))
   271	  }
   272	}
   273	
   274	async_job_handler_registry <- list(
   275	  clustering = list(
   276	    cancel_mode = "best_effort",
   277	    run = .async_job_run_clustering,
   278	    after_success = function(result, job, payload, state, worker_config) {
   279	      .async_job_chain_llm(result, job, cluster_type = "functional")
   280	    }
   281	  ),
   282	  phenotype_clustering = list(
   283	    cancel_mode = "best_effort",
   284	    run = .async_job_run_phenotype_clustering,
   285	    after_success = function(result, job, payload, state, worker_config) {
   286	      .async_job_chain_llm(result, job, cluster_type = "phenotype")
   287	    }
   288	  ),
   289	  ontology_update = list(
   290	    cancel_mode = "non_interruptible",
   291	    run = .async_job_run_ontology_update,
   292	    after_success = .async_job_after_success_noop
   293	  ),
   294	  hgnc_update = list(
   295	    cancel_mode = "non_interruptible",
   296	    run = .async_job_run_hgnc_update,
   297	    after_success = .async_job_after_success_noop
   298	  ),
   299	  comparisons_update = list(
   300	    cancel_mode = "non_interruptible",
   301	    run = .async_job_run_passthrough("comparisons_update_async"),
   302	    after_success = .async_job_after_success_noop
   303	  ),
   304	  pubtator_update = list(
   305	    cancel_mode = "best_effort",
   306	    run = .async_job_run_pubtator,
   307	    after_success = .async_job_after_success_noop
   308	  ),
   309	  pubtator_enrichment_refresh = list(
   310	    cancel_mode = "best_effort",
   311	    run = .async_job_run_pubtator_enrichment,
   312	    after_success = .async_job_after_success_noop
   313	  ),
   314	  pubtatornidd_nightly = list(
   315	    cancel_mode = "non_interruptible",
   316	    run = .async_job_run_pubtatornidd_nightly,
   317	    after_success = .async_job_after_success_noop
   318	  ),
   319	  disease_ontology_mapping_refresh = list(
   320	    cancel_mode = "non_interruptible",
   321	    run = .async_job_run_disease_ontology_mapping_refresh,
   322	    after_success = .async_job_after_success_noop
   323	  ),
   324	  nddscore_import = list(
   325	    cancel_mode = "non_interruptible",
   326	    run = .async_job_run_nddscore_import,
   327	    after_success = .async_job_after_success_noop
   328	  ),
   329	  llm_generation = list(
   330	    cancel_mode = "best_effort",
   331	    run = .async_job_run_passthrough("llm_batch_executor"),
   332	    after_success = .async_job_after_success_noop
   333	  ),
   334	  network_layout_prewarm = list(
   335	    cancel_mode = "best_effort",
   336	    run = function(...) .async_job_run_network_layout_prewarm(...),
   337	    after_success = .async_job_after_success_noop
   338	  ),
   339	  analysis_snapshot_refresh = list(
   340	    cancel_mode = "best_effort",
   341	    run = function(...) .async_job_run_analysis_snapshot_refresh(...),
   342	    after_success = .async_job_after_success_noop
   343	  ),
   344	  backup_create = list(
   345	    cancel_mode = "non_interruptible",
   346	    run = .async_job_run_backup_create,
   347	    after_success = .async_job_after_success_noop
   348	  ),
   349	  backup_restore = list(
   350	    cancel_mode = "non_interruptible",
   351	    run = .async_job_run_backup_restore,
   352	    after_success = .async_job_after_success_noop
   353	  ),
   354	  omim_update = list(
   355	    cancel_mode = "non_interruptible",
   356	    run = .async_job_run_omim_update,
   357	    after_success = .async_job_after_success_noop
   358	  ),
   359	  force_apply_ontology = list(
   360	    cancel_mode = "non_interruptible",
   361	    run = .async_job_run_force_apply_ontology,
   362	    after_success = .async_job_after_success_noop
   363	  ),
   364	  publication_refresh = list(
   365	    cancel_mode = "best_effort",
   366	    run = .async_job_run_publication_refresh,
   367	    after_success = .async_job_after_success_noop
   368	  ),
   369	  publication_date_backfill = list(
   370	    cancel_mode = "non_interruptible",
   371	    run = .async_job_run_publication_date_backfill,
   372	    after_success = .async_job_after_success_noop
   373	  )
   374	)
   375	
   376	#' Resolve a durable async job handler definition
   377	#' @param job_type Character async job type.
   378	#' @param registry Named handler registry.
   379	#'
   380	#' @return Registry entry with run/cancel metadata.
   381	#' @export
   382	async_job_get_handler <- function(job_type, registry = async_job_handler_registry) {
   383	  entry <- registry[[job_type]]
   384	
   385	  if (is.null(entry)) {
   386	    stop(sprintf("No durable async job handler registered for '%s'", job_type), call. = FALSE)
   387	  }
   388	
   389	  if (!is.function(entry$run)) {
   390	    stop(sprintf("Handler registry entry for '%s' is missing a callable run function", job_type), call. = FALSE)
   391	  }
   392	
   393	  if (is.null(entry$after_success)) {
   394	    entry$after_success <- .async_job_after_success_noop
   395	  }
   396	
   397	  entry
   398	}

exec
/bin/bash -lc 'nl -ba api/functions/async-job-service.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# ---------------------------------------------------------------------------
     2	# Queue-depth capacity cap
     3	# ---------------------------------------------------------------------------
     4	
     5	# Max simultaneously queued+running jobs allowed on the public submit queue.
     6	# Read once at source/startup time; changing the env var requires an API
     7	# restart to take effect. An INVALID value (e.g. "abc") must not parse to NA:
     8	# `async_job_capacity_exceeded()` isTRUE-wraps its comparison, so an NA cap would
     9	# silently disable this DB-backed backstop entirely. Floor at 1, default 8.
    10	ASYNC_PUBLIC_JOB_CAP <- local({
    11	  raw <- trimws(Sys.getenv("ASYNC_PUBLIC_JOB_CAP", "8"))
    12	  value <- suppressWarnings(as.integer(raw))
    13	  if (is.na(value) || value < 1L) 8L else value
    14	})
    15	
    16	#' TRUE when the active (queued+running) job count is at or over the cap.
    17	#'
    18	#' Soft cap: the check-then-submit sequence in the endpoints is not atomic, so
    19	#' two concurrent requests may both pass and transiently push the queue one or
    20	#' two over the cap. That is acceptable for a back-pressure guard.
    21	#'
    22	#' @param active_count Integer count of currently in-flight jobs.
    23	#' @param cap Integer maximum allowed. Defaults to ASYNC_PUBLIC_JOB_CAP.
    24	#' @return Logical.
    25	#' @export
    26	async_job_capacity_exceeded <- function(active_count, cap = ASYNC_PUBLIC_JOB_CAP) {
    27	  cap <- suppressWarnings(as.integer(cap))
    28	  if (length(cap) != 1L || is.na(cap) || cap < 1L) {
    29	    cap <- 8L # never let an invalid cap silently disable the backstop
    30	  }
    31	  isTRUE(as.integer(active_count) >= cap)
    32	}
    33	
    34	#' Count queued+running jobs for a given queue.
    35	#'
    36	#' @param queue_name Character queue name to inspect.
    37	#' @param conn Optional DB connection or pool. NULL uses global pool.
    38	#' @return Integer count of active (queued / running / cancel_requested) jobs.
    39	#' @export
    40	async_job_active_count <- function(queue_name = "default", conn = NULL) {
    41	  sql <- paste(
    42	    "SELECT COUNT(*) AS n FROM async_jobs",
    43	    "WHERE queue_name = ? AND status IN ('queued', 'running', 'cancel_requested')"
    44	  )
    45	  row <- db_execute_query(sql, params = list(queue_name), conn = conn)
    46	  if (nrow(row) == 0) 0L else as.integer(row$n[[1]])
    47	}
    48	
    49	# ---------------------------------------------------------------------------
    50	# Queue routing + priority by job type (#486)
    51	#
    52	# One serial worker draining one shared "default" queue lets a long-running,
    53	# non-interruptible maintenance job (e.g. publication_date_backfill) head-of-line
    54	# block latency-sensitive interactive jobs (clustering / phenotype_clustering /
    55	# llm_generation and the snapshot -> LLM deploy chain). These helpers are the
    56	# single source of truth for which lane and priority a job type defaults to; the
    57	# `worker-maintenance` container drains the "maintenance" lane so heavy jobs run
    58	# in parallel with the interactive worker instead of blocking it.
    59	# ---------------------------------------------------------------------------
    60	
    61	# Heavy / bulk / external maintenance job types, routed to the "maintenance" lane.
    62	ASYNC_MAINTENANCE_JOB_TYPES <- c(
    63	  "publication_date_backfill",
    64	  "publication_refresh",
    65	  "pubtator_update",
    66	  "pubtator_enrichment_refresh",
    67	  "pubtatornidd_nightly",
    68	  "omim_update",
    69	  "hgnc_update",
    70	  "comparisons_update",
    71	  "ontology_update",
    72	  "force_apply_ontology",
    73	  "disease_ontology_mapping_refresh",
    74	  "nddscore_import",
    75	  "backup_create",
    76	  "backup_restore"
    77	)
    78	
    79	# Latency-sensitive / user-visible interactive job types. They stay on the
    80	# "default" lane but get the LOWEST priority number so a worker claims them ahead
    81	# of any maintenance job that happens to share the queue.
    82	ASYNC_INTERACTIVE_JOB_TYPES <- c(
    83	  "clustering",
    84	  "phenotype_clustering",
    85	  "llm_generation",
    86	  "analysis_snapshot_refresh",
    87	  "network_layout_prewarm"
    88	)
    89	
    90	# Priority tiers (lower number = claimed first; the claim query orders
    91	# `priority ASC`). interactive < maintenance < everything-else default.
    92	ASYNC_PRIORITY_INTERACTIVE <- 10L
    93	ASYNC_PRIORITY_MAINTENANCE <- 50L
    94	ASYNC_PRIORITY_DEFAULT <- 100L
    95	
    96	#' Resolve the durable queue lane for a job type.
    97	#'
    98	#' @param job_type Character durable job type.
    99	#' @return "maintenance" for heavy/bulk/external maintenance job types, else
   100	#'   "default".
   101	#' @export
   102	async_job_queue_for_type <- function(job_type) {
   103	  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
   104	  if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) "maintenance" else "default"
   105	}
   106	
   107	#' Resolve the default claim priority for a job type.
   108	#'
   109	#' @param job_type Character durable job type.
   110	#' @return Integer priority: interactive (10) < maintenance (50) < default (100).
   111	#' @export
   112	async_job_priority_for_type <- function(job_type) {
   113	  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
   114	  if (jt %in% ASYNC_INTERACTIVE_JOB_TYPES) {
   115	    ASYNC_PRIORITY_INTERACTIVE
   116	  } else if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) {
   117	    ASYNC_PRIORITY_MAINTENANCE
   118	  } else {
   119	    ASYNC_PRIORITY_DEFAULT
   120	  }
   121	}
   122	
   123	# ---------------------------------------------------------------------------
   124	
   125	.async_job_service_scalar <- function(value, default = NULL) {
   126	  if (is.null(value) || length(value) == 0) {
   127	    return(default)
   128	  }
   129	
   130	  if (is.list(value)) {
   131	    return(value[[1]])
   132	  }
   133	
   134	  value[[1]]
   135	}
   136	
   137	.async_job_service_abort <- function(message, class = "async_job_service_validation_error", ...) {
   138	  rlang::abort(message = message, class = class, ...)
   139	}
   140	
   141	.async_job_service_non_empty_string <- function(value, field) {
   142	  scalar <- .async_job_service_scalar(value, NULL)
   143	
   144	  if (is.null(scalar)) {
   145	    .async_job_service_abort(sprintf("%s is required", field))
   146	  }
   147	
   148	  scalar <- as.character(scalar)
   149	  if (!nzchar(trimws(scalar))) {
   150	    .async_job_service_abort(sprintf("%s is required", field))
   151	  }
   152	
   153	  scalar
   154	}
   155	
   156	async_job_service_payload_json <- function(request_payload) {
   157	  if (is.character(request_payload) && length(request_payload) == 1L) {
   158	    return(request_payload[[1]])
   159	  }
   160	
   161	  as.character(
   162	    jsonlite::toJSON(
   163	      request_payload,
   164	      auto_unbox = TRUE,
   165	      null = "null",
   166	      dataframe = "rows",
   167	      POSIXt = "ISO8601"
   168	    )
   169	  )
   170	}
   171	
   172	async_job_service_request_hash <- function(job_type, request_payload_json) {
   173	  digest::digest(
   174	    paste0(
   175	      .async_job_service_non_empty_string(job_type, "job_type"),
   176	      ":",
   177	      as.character(.async_job_service_scalar(request_payload_json, ""))
   178	    ),
   179	    algo = "sha256",
   180	    serialize = FALSE
   181	  )
   182	}
   183	
   184	.async_job_service_duplicate_row <- function(error, conn = NULL) {
   185	  duplicate_job <- error$duplicate_job
   186	  if (is.null(duplicate_job)) {
   187	    duplicate_job <- tibble::tibble()
   188	  }
   189	
   190	  if (nrow(duplicate_job) > 0) {
   191	    return(duplicate_job)
   192	  }
   193	
   194	  job_id <- error$job_id
   195	  if (is.null(job_id)) {
   196	    return(tibble::tibble())
   197	  }
   198	
   199	  async_job_repository_get(job_id, conn = conn)
   200	}
   201	
   202	#' Submit a durable async job and return its stored row
   203	#'
   204	#' @param job_type Character durable job type.
   205	#' @param request_payload Named list or JSON payload string.
   206	#' @param submitted_by Optional user id.
   207	#' @param queue_name Character queue name. `NULL` (default) routes by job type via
   208	#'   `async_job_queue_for_type()` (maintenance lane for heavy jobs, else default);
   209	#'   an explicit value is honored as-is.
   210	#' @param priority Integer queue priority. `NULL` (default) resolves by job type
   211	#'   via `async_job_priority_for_type()` (interactive < maintenance < default); an
   212	#'   explicit value is honored as-is.
   213	#' @param max_attempts Integer maximum attempts.
   214	#' @param scheduled_at Optional schedule time.
   215	#' @param job_id Optional explicit job id for tests.
   216	#' @param conn Optional DB connection or pool.
   217	#' @param hash_payload Optional named list or JSON payload string. When
   218	#'   supplied, the dedup `request_hash` is computed over THIS payload instead
   219	#'   of `request_payload`, while `request_payload_json` (the durably stored
   220	#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
   221	#'   `request_payload` exactly as before, so existing callers are unaffected.
   222	#'   Used by clustering submits (#574) to exclude time-varying `provenance`
   223	#'   metadata from the dedup identity while still persisting it.
   224	#'
   225	#' @return List containing the stored job row and duplicate/create flags.
   226	#' @export
   227	async_job_service_submit <- function(
   228	  job_type,
   229	  request_payload,
   230	  submitted_by = NULL,
   231	  queue_name = NULL,
   232	  priority = NULL,
   233	  max_attempts = 1L,
   234	  scheduled_at = Sys.time(),
   235	  job_id = uuid::UUIDgenerate(),
   236	  conn = NULL,
   237	  hash_payload = NULL
   238	) {
   239	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   240	  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   241	  # Default the lane + priority from the job type so heavy maintenance jobs never
   242	  # head-of-line block interactive jobs (#486). Explicit overrides are honored.
   243	  if (is.null(queue_name)) {
   244	    queue_name <- async_job_queue_for_type(job_type)
   245	  }
   246	  if (is.null(priority)) {
   247	    priority <- async_job_priority_for_type(job_type)
   248	  }
   249	  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   250	  payload_json <- async_job_service_payload_json(request_payload)
   251	  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
   252	  request_hash <- async_job_service_request_hash(job_type, hash_payload_json)
   253	  submitted_at <- Sys.time()
   254	
   255	  stored_job <- tryCatch(
   256	    {
   257	      async_job_repository_create(
   258	        list(
   259	          job_id = job_id,
   260	          job_type = job_type,
   261	          queue_name = queue_name,
   262	          priority = as.integer(priority),
   263	          request_hash = request_hash,
   264	          request_payload_json = payload_json,
   265	          submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
   266	          submitted_at = submitted_at,
   267	          scheduled_at = scheduled_at,
   268	          max_attempts = as.integer(max_attempts)
   269	        ),
   270	        conn = conn
   271	      )
   272	
   273	      async_job_repository_get(job_id, conn = conn)
   274	    },
   275	    async_job_duplicate_error = function(error) {
   276	      .async_job_service_duplicate_row(error, conn = conn)
   277	    }
   278	  )
   279	
   280	  is_duplicate <- nrow(stored_job) > 0 && !identical(stored_job$job_id[[1]], job_id)
   281	
   282	  list(
   283	    job = stored_job,
   284	    duplicate = is_duplicate,
   285	    created = !is_duplicate
   286	  )
   287	}
   288	
   289	#' Persist an already-completed durable async job row
   290	#'
   291	#' Used for cache-hit fast paths that should still return a normal durable
   292	#' job id without enqueueing worker execution.
   293	#'
   294	#' @param job_type Character durable job type.
   295	#' @param request_payload Named list or JSON payload string.
   296	#' @param result Completed handler result payload.
   297	#' @param submitted_by Optional user id.
   298	#' @param queue_name Character queue name.
   299	#' @param priority Integer queue priority.
   300	#' @param job_id Optional explicit job id.
   301	#' @param submitted_at Optional submission timestamp.
   302	#' @param completed_at Optional completion timestamp.
   303	#' @param conn Optional DB connection or pool.
   304	#' @param hash_payload Optional named list or JSON payload string. When
   305	#'   supplied, the dedup `request_hash` is computed over THIS payload instead
   306	#'   of `request_payload`, while `request_payload_json` (the durably stored
   307	#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
   308	#'   `request_payload` exactly as before, so existing callers are unaffected.
   309	#'
   310	#' @return Tibble with the stored completed job row.
   311	#' @export
   312	async_job_service_store_completed <- function(
   313	  job_type,
   314	  request_payload,
   315	  result,
   316	  submitted_by = NULL,
   317	  queue_name = "default",
   318	  priority = 100L,
   319	  job_id = uuid::UUIDgenerate(),
   320	  submitted_at = Sys.time(),
   321	  completed_at = submitted_at,
   322	  conn = NULL,
   323	  hash_payload = NULL
   324	) {
   325	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   326	  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   327	  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   328	  payload_json <- async_job_service_payload_json(request_payload)
   329	  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
   330	  result_json <- async_job_service_payload_json(result)
   331	
   332	  async_job_repository_create(
   333	    list(
   334	      job_id = job_id,
   335	      job_type = job_type,
   336	      queue_name = queue_name,
   337	      priority = as.integer(priority),
   338	      status = "completed",
   339	      request_hash = async_job_service_request_hash(job_type, hash_payload_json),
   340	      request_payload_json = payload_json,
   341	      submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
   342	      submitted_at = submitted_at,
   343	      scheduled_at = submitted_at,
   344	      started_at = submitted_at,
   345	      completed_at = completed_at,
   346	      progress_pct = 100,
   347	      result_json = result_json
   348	    ),
   349	    conn = conn
   350	  )
   351	
   352	  async_job_repository_get(job_id, include_result = TRUE, conn = conn)
   353	}
   354	
   355	#' Find an active duplicate for a durable async job request
   356	#'
   357	#' @param job_type Character durable job type.
   358	#' @param request_payload Named list or JSON payload string.
   359	#' @param conn Optional DB connection or pool.
   360	#'
   361	#' @return Tibble with zero or one active duplicate row.
   362	#' @export
   363	async_job_service_find_duplicate <- function(job_type, request_payload, conn = NULL) {
   364	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   365	  payload_json <- async_job_service_payload_json(request_payload)
   366	
   367	  async_job_repository_find_active_duplicate(
   368	    job_type = job_type,
   369	    request_hash = async_job_service_request_hash(job_type, payload_json),
   370	    conn = conn
   371	  )
   372	}
   373	
   374	#' Read current durable async job status
   375	#'
   376	#' @param job_id Character job id.
   377	#' @param include_result Logical; include result_json when TRUE.
   378	#' @param conn Optional DB connection or pool.
   379	#'
   380	#' @return Tibble with zero or one durable job row.
   381	#' @export
   382	async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
   383	  async_job_repository_get(
   384	    job_id = .async_job_service_non_empty_string(job_id, "job_id"),
   385	    include_result = isTRUE(include_result),
   386	    conn = conn
   387	  )
   388	}
   389	
   390	#' Return durable async job history
   391	#'
   392	#' @param limit Integer history limit.
   393	#' @param include_result Logical; include result_json in history rows.
   394	#' @param conn Optional DB connection or pool.
   395	#'
   396	#' @return Tibble of recent durable jobs.
   397	#' @export
   398	async_job_service_history <- function(limit = 20L, include_result = FALSE, conn = NULL) {
   399	  args <- list(
   400	    limit = max(1L, as.integer(.async_job_service_scalar(limit, 20L))),
   401	    conn = conn
   402	  )
   403	  if (isTRUE(include_result)) {
   404	    args$include_result <- TRUE
   405	  }
   406	  do.call(async_job_repository_history, args)
   407	}
   408	
   409	#' Request durable async job cancellation and return the refreshed row
   410	#'
   411	#' @param job_id Character job id.
   412	#' @param cancelled_by Optional user id.
   413	#' @param conn Optional DB connection or pool.
   414	#'
   415	#' @return Tibble with zero or one durable job row after cancellation.
   416	#' @export
   417	async_job_service_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
   418	  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   419	
   420	  async_job_repository_cancel(
   421	    job_id = job_id,
   422	    cancelled_by = if (is.null(cancelled_by)) NULL else as.integer(cancelled_by),
   423	    conn = conn
   424	  )
   425	
   426	  async_job_repository_get(job_id, conn = conn)
   427	}
   428	
   429	#' Legacy duplicate response wrapper for endpoints not migrated yet
   430	#'
   431	#' @inheritParams async_job_service_find_duplicate
   432	#'
   433	#' @return List shaped like the previous duplicate helper.
   434	#' @export
   435	async_job_service_duplicate <- function(job_type, request_payload, conn = NULL) {
   436	  duplicate <- async_job_service_find_duplicate(
   437	    job_type = job_type,
   438	    request_payload = request_payload,
   439	    conn = conn
   440	  )
   441	
   442	  if (nrow(duplicate) == 0) {
   443	    return(list(duplicate = FALSE))
   444	  }
   445	
   446	  list(
   447	    duplicate = TRUE,
   448	    existing_job_id = duplicate$job_id[[1]]
   449	  )
   450	}
   451	
   452	#' Find an active job of a given type (job-type single-flight).
   453	#'
   454	#' @param job_type Character job type.
   455	#' @param conn Optional DB connection or pool.
   456	#' @return Tibble with zero or one active duplicate row of that job_type.
   457	#' @export
   458	async_job_service_find_active_by_type <- function(job_type, conn = NULL) {
   459	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   460	  async_job_repository_find_active_by_type(job_type = job_type, conn = conn)
   461	}
   462	
   463	#' Job-type single-flight duplicate check (#535 S2b HIGH-4).
   464	#'
   465	#' Unlike `async_job_service_duplicate()` (which keys on the payload hash and so
   466	#' cannot dedupe across a payload-schema change), this dedupes on job_type alone,
   467	#' so a destructive full-table-replace maintenance job (hgnc/comparisons/omim/
   468	#' force_apply) resubmitted while one is in flight gets a clean 409 even across
   469	#' the deploy that drops db_config from its payload.
   470	#'
   471	#' NOTE (scope): this is a **best-effort, submit-time** guard — the check and the
   472	#' subsequent insert are NOT atomic, so a rare concurrent double-submit can still
   473	#' enqueue two jobs. That is acceptable because the durable **maintenance lane
   474	#' runs on a single worker** (`async_job_worker_main` claims+runs jobs
   475	#' sequentially; Compose runs one `worker-maintenance` container), so two
   476	#' destructive jobs never execute concurrently regardless of dedup. A hard,
   477	#' atomic **cross-type conflict-group mutex** (e.g. an advisory lock covering
   478	#' check+insert, or a generated conflict-key unique index grouping
   479	#' omim_update/force_apply_ontology and pubtator_enrichment_refresh/
   480	#' pubtatornidd_nightly) is defense-in-depth needed only if the maintenance lane
   481	#' is ever scaled beyond one worker — tracked as a follow-up, not part of this
   482	#' credential fix.
   483	#'
   484	#' @param job_type Character job type.
   485	#' @param conn Optional DB connection or pool.
   486	#' @return list(duplicate = FALSE) or list(duplicate = TRUE, existing_job_id = ...).
   487	#' @export
   488	async_job_service_duplicate_by_type <- function(job_type, conn = NULL) {
   489	  active <- async_job_service_find_active_by_type(job_type, conn = conn)
   490	  if (nrow(active) == 0) {
   491	    return(list(duplicate = FALSE))
   492	  }
   493	  list(duplicate = TRUE, existing_job_id = active$job_id[[1]])
   494	}
   495	
   496	#' Legacy cancellation wrapper for endpoints not migrated yet
   497	#'
   498	#' @inheritParams async_job_service_cancel
   499	#'
   500	#' @return List describing cancellation outcome.
   501	#' @export
   502	async_job_service_request_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
   503	  cancelled <- async_job_service_cancel(
   504	    job_id = job_id,
   505	    cancelled_by = cancelled_by,
   506	    conn = conn
   507	  )
   508	
   509	  if (nrow(cancelled) == 0) {
   510	    return(list(
   511	      error = "JOB_NOT_FOUND",
   512	      message = "Job ID not found"
   513	    ))
   514	  }
   515	
   516	  list(job_id = job_id, status = cancelled$status[[1]])
   517	}

exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-unit-clustering-gene-universe.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# Unit tests for the category-selected clustering gene-universe resolver (#574 D1).
     2	#
     3	# `clustering_resolve_category_universe()` resolves the gene set a clustering
     4	# job runs on: either the current default (all NDD genes, via
     5	# `generate_ndd_hgnc_ids()`) or a curated-category selection
     6	# (`ndd_entity_view` entity rows filtered by `category %in% selector`, then
     7	# distinct `hgnc_id`). This file is DB-free: the default branch's dependency
     8	# (`generate_ndd_hgnc_ids()`) is overridden in a child environment, and the
     9	# category branch's `conn` is a real in-memory RSQLite connection so the
    10	# dbplyr pipeline (`tbl()` / `filter()` / `select()` / `collect()`) is
    11	# exercised for real rather than mocked.
    12	#
    13	# Trap: do NOT stub `generate_ndd_hgnc_ids` via
    14	# `testthat::local_mocked_bindings(..., .env = globalenv())` -- under
    15	# testthat 3.3.2 that aborts with "No packages loaded with pkgload" because
    16	# globalenv() has no package namespace. A child-env override sidesteps this.
    17	
    18	## -------------------------------------------------------------------------##
    19	## clustering_cached_source_data_version() TTL cache (#574 D2 review fix)
    20	## -------------------------------------------------------------------------##
    21	#
    22	# These tests stub `analysis_snapshot_source_data_version()` directly -- no DB
    23	# connection is ever opened -- so they are placed BEFORE the file-wide
    24	# `skip_if_not_installed("RSQLite")` gate below and run unconditionally, even
    25	# when {RSQLite} is unavailable.
    26	
    27	# Sources ONLY core/errors.R + the module under test into a fresh child env.
    28	# A fresh env means a fresh `.clustering_source_data_version_cache` (it is
    29	# created top-level by the sourced file), so there is nothing left over from
    30	# a prior test -- `.reset_source_data_version_cache()` below is still applied
    31	# defensively so the reset mechanism itself stays covered/documented.
    32	.source_data_version_env <- function() {
    33	  e <- new.env(parent = globalenv())
    34	  source_api_file("core/errors.R", local = FALSE, envir = e)
    35	  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
    36	  e
    37	}
    38	
    39	# Clears the module-level TTL cache env so cached state never leaks across
    40	# assertions sharing the same sourced env `e`.
    41	.reset_source_data_version_cache <- function(e) {
    42	  cache_env <- e$.clustering_source_data_version_cache
    43	  keys <- ls(cache_env, all.names = TRUE)
    44	  if (length(keys) > 0L) rm(list = keys, envir = cache_env)
    45	}
    46	
    47	test_that("clustering_cached_source_data_version: TTL hit avoids a second underlying fetch", {
    48	  e <- .source_data_version_env()
    49	  .reset_source_data_version_cache(e)
    50	  calls <- 0L
    51	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
    52	    calls <<- calls + 1L
    53	    "v1"
    54	  }
    55	
    56	  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
    57	  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
    58	
    59	  expect_identical(first, "v1")
    60	  expect_identical(second, "v1")
    61	  expect_identical(calls, 1L) # second call served from cache, underlying fn NOT re-invoked
    62	})
    63	
    64	test_that("clustering_cached_source_data_version: TTL expiry (ttl_seconds = 0) forces a refetch", {
    65	  # `diff < ttl_seconds` is the staleness check; `diff` (elapsed seconds since
    66	  # the last successful fetch) is always >= 0, so `ttl_seconds = 0` makes
    67	  # `diff < 0` FALSE on every subsequent call -- deterministically always-stale,
    68	  # regardless of clock resolution between the two calls.
    69	  e <- .source_data_version_env()
    70	  .reset_source_data_version_cache(e)
    71	  calls <- 0L
    72	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
    73	    calls <<- calls + 1L
    74	    paste0("v", calls)
    75	  }
    76	
    77	  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
    78	  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
    79	
    80	  expect_identical(first, "v1")
    81	  expect_identical(second, "v2")
    82	  expect_identical(calls, 2L) # both calls hit the underlying fn -- cache never served a hit
    83	})
    84	
    85	test_that("clustering_cached_source_data_version: an error propagates and never poisons the cache", {
    86	  e <- .source_data_version_env()
    87	  .reset_source_data_version_cache(e)
    88	  e$analysis_snapshot_source_data_version <- function(conn = NULL) stop("boom")
    89	
    90	  expect_error(
    91	    e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300),
    92	    "boom"
    93	  )
    94	  # Nothing was written to the cache by the failed call.
    95	  expect_null(e$.clustering_source_data_version_cache$value)
    96	  expect_null(e$.clustering_source_data_version_cache$cached_at)
    97	
    98	  # Swap to a success stub: the NEXT call must refetch (not serve a stale/NA
    99	  # value left over from the failed attempt) and the cache must now work.
   100	  .reset_source_data_version_cache(e)
   101	  calls <- 0L
   102	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
   103	    calls <<- calls + 1L
   104	    "v-success"
   105	  }
   106	
   107	  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
   108	
   109	  expect_identical(result, "v-success")
   110	  expect_identical(calls, 1L)
   111	})
   112	
   113	test_that("clustering_cached_source_data_version: NA_character_ from the underlying fetch is rejected and never cached (Codex review fix)", {
   114	  # Fail-closed contract: the TTL cache must never cache/return NA. A
   115	  # malformed underlying value must stop() (mapped to 503 by the caller's
   116	  # tryCatch), exactly like a hard fetch error above -- not be cached and
   117	  # served as broken provenance.
   118	  e <- .source_data_version_env()
   119	  .reset_source_data_version_cache(e)
   120	  calls <- 0L
   121	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
   122	    calls <<- calls + 1L
   123	    NA_character_
   124	  }
   125	
   126	  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
   127	  # Nothing was written to the cache by the invalid-value call.
   128	  expect_null(e$.clustering_source_data_version_cache$value)
   129	  expect_null(e$.clustering_source_data_version_cache$cached_at)
   130	
   131	  # Swap to a now-valid stub: the NEXT call must refetch (never serve the
   132	  # invalid value from a poisoned cache) and the counter must increment.
   133	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
   134	    calls <<- calls + 1L
   135	    "v-valid"
   136	  }
   137	  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
   138	
   139	  expect_identical(result, "v-valid")
   140	  expect_identical(calls, 2L)
   141	})
   142	
   143	test_that("clustering_cached_source_data_version: an empty string from the underlying fetch is rejected and never cached (Codex review fix)", {
   144	  e <- .source_data_version_env()
   145	  .reset_source_data_version_cache(e)
   146	  e$analysis_snapshot_source_data_version <- function(conn = NULL) ""
   147	
   148	  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
   149	  expect_null(e$.clustering_source_data_version_cache$value)
   150	  expect_null(e$.clustering_source_data_version_cache$cached_at)
   151	})
   152	
   153	testthat::skip_if_not_installed("RSQLite")
   154	
   155	# Source the code under test into a child env so the NULL-branch dependency
   156	# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
   157	# globalenv() or any other test file's bindings.
   158	.gene_universe_env <- function() {
   159	  e <- new.env(parent = globalenv())
   160	  source_api_file("core/errors.R", local = FALSE, envir = e)
   161	  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
   162	  e
   163	}
   164	
   165	# In-memory RSQLite fixture standing in for `pool`/a real DB connection.
   166	# `ev` = ndd_entity_view rows, `cats` = ndd_entity_status_categories_list rows.
   167	fake_conn <- function(ev, cats) {
   168	  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
   169	  DBI::dbWriteTable(con, "ndd_entity_view", as.data.frame(ev))
   170	  DBI::dbWriteTable(con, "ndd_entity_status_categories_list", as.data.frame(cats))
   171	  con
   172	}
   173	
   174	# Fixture: entity rows (one row per entity). TWO Definitive NDD genes so the
   175	# ["Definitive"] universe passes the >=2 guard.
   176	ev <- tibble::tribble(
   177	  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
   178	  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
   179	  2L,        "HGNC:1",   1L,             "Limited",
   180	  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
   181	  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
   182	  5L,        "HGNC:4",   1L,             "Moderate",     # gene 4: Moderate NDD (single -> too-small alone)
   183	  6L,        "HGNC:5",   1L,             "Definitive"    # gene 5: second Definitive NDD gene
   184	)
   185	cats <- tibble::tibble(
   186	  category = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
   187	  is_active = 1L
   188	)
   189	
   190	test_that("Definitive selects genes with any Definitive NDD entity (multi-entity gene included)", {
   191	  e <- .gene_universe_env()
   192	  con <- fake_conn(ev, cats)
   193	  withr::defer(DBI::dbDisconnect(con))
   194	
   195	  r <- e$clustering_resolve_category_universe("Definitive", conn = con)
   196	
   197	  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5")) # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
   198	  expect_identical(r$selector, "Definitive")
   199	  expect_identical(r$resolved_gene_count, 2L)
   200	})
   201	
   202	test_that("multi-value selector is a union across categories", {
   203	  e <- .gene_universe_env()
   204	  con <- fake_conn(ev, cats)
   205	  withr::defer(DBI::dbDisconnect(con))
   206	
   207	  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)
   208	
   209	  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5", "HGNC:4"))
   210	})
   211	
   212	test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
   213	  e <- .gene_universe_env()
   214	  con <- fake_conn(ev, cats)
   215	  withr::defer(DBI::dbDisconnect(con))
   216	  e$generate_ndd_hgnc_ids <- function() {
   217	    tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5"))
   218	  }
   219	
   220	  r <- e$clustering_resolve_category_universe(NULL, conn = con)
   221	
   222	  expect_identical(r$hgnc_ids, c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5")) # arrange(entity_id)+distinct, ndd_phenotype==1
   223	  expect_null(r$selector)
   224	})
   225	
   226	test_that("unknown token is rejected 400 with the allowed set in the MESSAGE (not detail)", {
   227	  e <- .gene_universe_env()
   228	  con <- fake_conn(ev, cats)
   229	  withr::defer(DBI::dbDisconnect(con))
   230	
   231	  err <- tryCatch(
   232	    e$clustering_resolve_category_universe("Definative", conn = con),
   233	    error = function(err) err
   234	  )
   235	
   236	  expect_s3_class(err, "error_400")
   237	  expect_match(conditionMessage(err), "Definitive") # allowed set is in the message so it reaches clients
   238	})
   239	
   240	test_that("supplied-but-empty selector is 400 (NOT the all-NDD default) with the allowed set in the message", {
   241	  e <- .gene_universe_env()
   242	  con <- fake_conn(ev, cats)
   243	  withr::defer(DBI::dbDisconnect(con))
   244	
   245	  err_empty <- tryCatch(
   246	    e$clustering_resolve_category_universe(list(), conn = con),
   247	    error = function(err) err
   248	  )
   249	  err_blank <- tryCatch(
   250	    e$clustering_resolve_category_universe(list("   "), conn = con),
   251	    error = function(err) err
   252	  )
   253	
   254	  expect_s3_class(err_empty, "error_400")
   255	  expect_s3_class(err_blank, "error_400")
   256	  # The locked contract: EVERY category-validation 400 names the allowed set.
   257	  expect_match(conditionMessage(err_empty), "Allowed active categories")
   258	  expect_match(conditionMessage(err_empty), "Definitive")
   259	  expect_match(conditionMessage(err_blank), "Allowed active categories")
   260	  expect_match(conditionMessage(err_blank), "Definitive")
   261	})
   262	
   263	test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job) with the allowed set in the message", {
   264	  e <- .gene_universe_env()
   265	  con <- fake_conn(ev, cats)
   266	  withr::defer(DBI::dbDisconnect(con))
   267	
   268	  err_zero <- tryCatch(
   269	    e$clustering_resolve_category_universe("Refuted", conn = con), # 0 genes
   270	    error = function(err) err
   271	  )
   272	  err_one <- tryCatch(
   273	    e$clustering_resolve_category_universe("Moderate", conn = con), # 1 gene
   274	    error = function(err) err
   275	  )
   276	
   277	  expect_s3_class(err_zero, "error_400")
   278	  expect_s3_class(err_one, "error_400")
   279	  expect_match(conditionMessage(err_zero), "Allowed active categories")
   280	  expect_match(conditionMessage(err_zero), "Definitive")
   281	  expect_match(conditionMessage(err_one), "Allowed active categories")
   282	  expect_match(conditionMessage(err_one), "Definitive")
   283	})
   284	
   285	test_that("gene_list_sha256 is sort-order independent", {
   286	  e <- .gene_universe_env()
   287	
   288	  expect_identical(
   289	    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
   290	    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
   291	  )
   292	})
   293	
   294	test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
   295	  e <- .gene_universe_env()
   296	
   297	  expect_null(e$clustering_normalize_category_filter(NULL))
   298	  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
   299	  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
   300	  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
   301	  expect_identical(
   302	    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
   303	    c("Definitive", "Moderate")
   304	  )
   305	})

exec
/bin/bash -lc 'nl -ba api/endpoints/jobs_endpoints.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# api/endpoints/jobs_endpoints.R
     2	#
     3	# Async job submission and status polling endpoints.
     4	# Submits durable worker jobs and returns HTTP 202 Accepted for long-running operations.
     5	#
     6	# Endpoints:
     7	#   POST /api/jobs/clustering/submit - Submit functional clustering job
     8	#   POST /api/jobs/phenotype_clustering/submit - Submit phenotype clustering job
     9	#   GET /api/jobs/<job_id>/status - Poll job status and retrieve results
    10	#
    11	# Dependencies:
    12	#   - pool (global database connection pool)
    13	#   - create_job, get_job_status, check_duplicate_job (from job-manager.R)
    14	#   - durable handlers registered in functions/async-job-handlers.R
    15	#
    16	# Handler bodies were extracted to services/job-*-service.R (issue #346, Wave
    17	# 3, Task 5) to keep this file a thin route table. Each shell below keeps its
    18	# original decorators, formals, and role gate, and delegates the rest to the
    19	# matching svc_ function.
    20	
    21	## -------------------------------------------------------------------##
    22	## Job Submission Endpoints
    23	## -------------------------------------------------------------------##
    24	
    25	#* Submit Functional Clustering Job
    26	#*
    27	#* Submits an async job to compute functional clustering via STRING-db. The
    28	#* clustering gene universe (#574) is resolved from one of three mutually
    29	#* exclusive JSON body selectors:
    30	#*   - `genes`: an explicit array of HGNC ids to cluster.
    31	#*   - `category_filter`: an array of curated SysNDD confidence categories
    32	#*     (e.g. `["Definitive"]`); resolved entity-level (>=1 NDD entity in a
    33	#*     selected category, `ndd_phenotype = 1`) against the live
    34	#*     `ndd_entity_view`, validated against the live active
    35	#*     `ndd_entity_status_categories_list`. A category run rejects with 400
    36	#*     when `category_filter` is empty, contains an unknown/inactive value
    37	#*     (the allowed active set is named in the error), or resolves fewer
    38	#*     than 2 genes.
    39	#*   - neither: the existing default all-NDD-genes universe.
    40	#* Supplying both `genes` and a non-empty `category_filter` is a 400.
    41	#*
    42	#* Every submit records selector/fingerprint provenance -- `selector`
    43	#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
    44	#* category runs), `resolved_gene_count`, `gene_list_sha256`,
    45	#* `intended_fingerprint`, and `source_data_version` -- in the durable job
    46	#* payload; the job result `meta` additionally carries `effective_fingerprint`
    47	#* (the STRING `weight_channel` actually observed on the computed result),
    48	#* recorded on both a cache-hit (immediate) response and a worker-run
    49	#* (cache-miss) job.
    50	#*
    51	#* Results from this endpoint (including category-filtered runs) are never
    52	#* `public_ready` -- they are ephemeral job results, distinct from the public
    53	#* `analysis_snapshot_*` layer.
    54	#*
    55	#* Returns immediately with job ID for status polling.
    56	#*
    57	#* @tag jobs
    58	#* @serializer json list(na="string")
    59	#* @param genes Optional JSON array of explicit HGNC ids. Mutually exclusive
    60	#*   with `category_filter`.
    61	#* @param category_filter Optional JSON array of curated SysNDD confidence
    62	#*   categories (e.g. `["Definitive"]`). Mutually exclusive with `genes`.
    63	#* @param algorithm Optional clustering algorithm string, `"leiden"`
    64	#*   (default) or `"walktrap"`.
    65	#* @post /clustering/submit
    66	function(req, res) {
    67	  svc_job_submit_functional_clustering(req, res)
    68	}
    69	
    70	## -------------------------------------------------------------------##
    71	## Phenotype Clustering Submission
    72	## -------------------------------------------------------------------##
    73	
    74	#* Submit Phenotype Clustering Job
    75	#*
    76	#* Submits an async job to compute phenotype clustering via MCA.
    77	#* Returns immediately with job ID for status polling.
    78	#*
    79	#* @tag jobs
    80	#* @serializer json list(na="string")
    81	#* @post /phenotype_clustering/submit
    82	function(req, res) {
    83	  svc_job_submit_phenotype_clustering(req, res)
    84	}
    85	
    86	## -------------------------------------------------------------------##
    87	## Ontology Update Submission
    88	## -------------------------------------------------------------------##
    89	
    90	#* Submit Ontology Update Job
    91	#*
    92	#* Submits an async job to update disease ontology data from MONDO and OMIM sources.
    93	#* Requires Administrator role.
    94	#* Returns immediately with job ID for status polling.
    95	#*
    96	#* @tag jobs
    97	#* @serializer json list(na="string")
    98	#* @post /ontology_update/submit
    99	function(req, res) {
   100	  require_role(req, res, "Administrator")
   101	  svc_job_submit_ontology_update(res)
   102	}
   103	
   104	## -------------------------------------------------------------------##
   105	## HGNC Data Update Submission
   106	## -------------------------------------------------------------------##
   107	
   108	#* Submit HGNC Data Update Job
   109	#*
   110	#* Submits an async job to download and update HGNC gene data.
   111	#* Requires Administrator role.
   112	#* Returns immediately with job ID for status polling.
   113	#*
   114	#* @tag jobs
   115	#* @serializer json list(na="string")
   116	#* @post /hgnc_update/submit
   117	function(req, res) {
   118	  require_role(req, res, "Administrator")
   119	  svc_job_submit_hgnc_update(res)
   120	}
   121	
   122	## -------------------------------------------------------------------##
   123	## Comparisons Data Update Submission
   124	## -------------------------------------------------------------------##
   125	
   126	#* Submit Comparisons Data Update Job
   127	#*
   128	#* Submits an async job to refresh the comparisons data from all external
   129	#* NDD databases (Radboud, Gene2Phenotype, PanelApp, SFARI, Geisinger,
   130	#* OMIM NDD, Orphanet).
   131	#*
   132	#* Requires Administrator role.
   133	#* Returns immediately with job ID for status polling.
   134	#*
   135	#* @tag jobs
   136	#* @serializer json list(na="string")
   137	#* @post /comparisons_update/submit
   138	function(req, res) {
   139	  require_role(req, res, "Administrator")
   140	  svc_job_submit_comparisons_update(res)
   141	}
   142	
   143	## -------------------------------------------------------------------##
   144	## Job History
   145	## -------------------------------------------------------------------##
   146	
   147	#* Get Job History
   148	#*
   149	#* Returns a list of recent jobs for admin review.
   150	#* Requires Administrator role.
   151	#*
   152	#* @tag jobs
   153	#* @serializer json list(na="string")
   154	#* @get /history
   155	function(req, res, limit = 20) {
   156	  require_role(req, res, "Administrator")
   157	  svc_job_get_history(limit)
   158	}
   159	
   160	## -------------------------------------------------------------------##
   161	## Job Status Polling
   162	## -------------------------------------------------------------------##
   163	
   164	#* Get Job Status
   165	#*
   166	#* Poll job status and retrieve results when complete.
   167	#* Returns Retry-After header for running jobs.
   168	#*
   169	#* @tag jobs
   170	#* @serializer json list(na="string", auto_unbox=TRUE)
   171	#* @get /<job_id>/status
   172	function(job_id, result_mode = "summary", req, res) {
   173	  svc_job_get_status(job_id, result_mode, req, res)
   174	}

exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-unit-job-endpoint-services-category.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# tests/testthat/test-unit-job-endpoint-services-category.R
     2	#
     3	# Host-runnable unit tests for the #574 (D2) category_filter / provenance /
     4	# dedup-hash-payload coverage of job-functional-submission-service.R, split
     5	# out of test-unit-job-endpoint-services.R (which keeps the base functional-
     6	# clustering submit coverage) to keep both files under the 600-line ceiling
     7	# after the #574 Codex-review-fix rounds grew this coverage. Shared fixtures
     8	# live in job-endpoint-services-fixtures.R (explicitly sourced below,
     9	# mirroring the sibling files). See test-unit-job-endpoint-services.R's
    10	# header for the full split rationale (phenotype submission coverage lives in
    11	# test-unit-job-endpoint-services-phenotype.R; maintenance-submission +
    12	# query-endpoint services are covered in
    13	# test-unit-job-endpoint-services-maintenance.R).
    14	#
    15	# Each service is sourced directly into an isolated environment via sys.source()
    16	# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
    17	# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
    18	# async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
    19	# gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
    20	# exercise pure request/response logic without a live DB or mirai daemon pool.
    21	
    22	# Resolve api_dir robustly so the file runs both under the full suite and a single-file
    23	# testthat::test_file(), then source the shared fixtures.
    24	if (exists("get_api_dir")) {
    25	  api_dir <- get_api_dir()
    26	} else {
    27	  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
    28	  if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
    29	    api_dir <- normalizePath(getwd(), mustWork = FALSE)
    30	  }
    31	}
    32	# local = TRUE keeps the shared helpers in this test file's environment (as if defined
    33	# inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
    34	source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)
    35	
    36	## -------------------------------------------------------------------##
    37	## job-functional-submission-service.R: category_filter (#574 D2)
    38	## -------------------------------------------------------------------##
    39	
    40	test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
    41	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    42	  # stop_for_bad_request() lives in core/errors.R, not sourced by the isolated
    43	  # service env by default -- source it here so the real (non-stubbed)
    44	  # mutual-exclusion guard in the service body can raise it.
    45	  source_api_file("core/errors.R", local = FALSE, envir = env)
    46	  env$pool <- job_endpoint_functional_pool(env)
    47	  req <- list(
    48	    argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive")),
    49	    user = list(user_id = NULL)
    50	  )
    51	  res <- job_endpoint_fake_res()
    52	
    53	  expect_error(
    54	    env$svc_job_submit_functional_clustering(req, res),
    55	    class = "error_400"
    56	  )
    57	})
    58	
    59	test_that("functional clustering: an EMPTY genes array + category_filter still triggers mutual exclusion -> error_400 (Codex review fix)", {
    60	  # Bug: mutual exclusion was previously gated on `has_genes` (a LENGTH
    61	  # check), so `{"genes":[], "category_filter":["Definitive"]}` bypassed it
    62	  # -- an empty-but-PRESENT `genes` key must still 400 when a category_filter
    63	  # is also present. Presence (`genes_supplied <- !is.null(genes_in)`), not
    64	  # length, is what mutual exclusion must gate on.
    65	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    66	  source_api_file("core/errors.R", local = FALSE, envir = env)
    67	  env$pool <- job_endpoint_functional_pool(env)
    68	  req <- list(
    69	    argsBody = list(genes = list(), category_filter = list("Definitive")),
    70	    user = list(user_id = NULL)
    71	  )
    72	  res <- job_endpoint_fake_res()
    73	
    74	  expect_error(
    75	    env$svc_job_submit_functional_clustering(req, res),
    76	    class = "error_400"
    77	  )
    78	})
    79	
    80	test_that("functional clustering: an explicit-null genes KEY + category_filter still triggers mutual exclusion -> error_400 (Codex round-2 review fix)", {
    81	  # Bug: mutual exclusion was gated on `!is.null(genes_in)`, which cannot
    82	  # distinguish an ABSENT `genes` key from an explicit JSON `null` (both
    83	  # parse to a NULL `req$argsBody$genes`) -- so
    84	  # `{"genes":null, "category_filter":["Definitive"]}` bypassed the guard and
    85	  # a category job was silently accepted. `list(genes = NULL)` in base R
    86	  # KEEPS the `genes` name with a NULL value (verified:
    87	  # "genes" %in% names(list(genes = NULL)) is TRUE), so gating on
    88	  # `names(req$argsBody)` instead of value-nullness catches this.
    89	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    90	  source_api_file("core/errors.R", local = FALSE, envir = env)
    91	  env$pool <- job_endpoint_functional_pool(env)
    92	  req <- list(
    93	    argsBody = list(genes = NULL, category_filter = list("Definitive")),
    94	    user = list(user_id = NULL)
    95	  )
    96	  res <- job_endpoint_fake_res()
    97	
    98	  expect_true("genes" %in% names(req$argsBody)) # pin the base-R name-retention fact this test relies on
    99	  expect_error(
   100	    env$svc_job_submit_functional_clustering(req, res),
   101	    class = "error_400"
   102	  )
   103	})
   104	
   105	test_that("functional clustering: an explicit-null genes KEY ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
   106	  # Regression guard for the fix above: gating mutual exclusion on JSON key
   107	  # presence must NOT change the pre-existing behavior for a null `genes`
   108	  # value with no `category_filter` at all -- it must still fall through to
   109	  # the all-NDD default exactly as before.
   110	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   111	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
   112	    entity_id = 1:3,
   113	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
   114	    ndd_phenotype = c(1L, 0L, 1L)
   115	  ))
   116	  job_endpoint_stub_all_ndd_universe(env)
   117	  captured <- NULL
   118	  env$check_duplicate_job <- function(operation, params) {
   119	    captured <<- params
   120	    list(duplicate = TRUE, existing_job_id = "dup-null-genes")
   121	  }
   122	  req <- list(argsBody = list(genes = NULL), user = list(user_id = NULL))
   123	  res <- job_endpoint_fake_res()
   124	
   125	  out <- env$svc_job_submit_functional_clustering(req, res)
   126	
   127	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   128	  expect_equal(res$status, 409)
   129	  expect_equal(out$error, "DUPLICATE_JOB")
   130	})
   131	
   132	test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
   133	  # Regression guard for the fix above: gating mutual exclusion on
   134	  # `genes_supplied` (key presence) must NOT change the pre-existing
   135	  # behavior for an empty `genes` array with no `category_filter` at all --
   136	  # it must still fall through to the all-NDD default exactly as before.
   137	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   138	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
   139	    entity_id = 1:3,
   140	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
   141	    ndd_phenotype = c(1L, 0L, 1L)
   142	  ))
   143	  job_endpoint_stub_all_ndd_universe(env)
   144	  captured <- NULL
   145	  env$check_duplicate_job <- function(operation, params) {
   146	    captured <<- params
   147	    list(duplicate = TRUE, existing_job_id = "dup-empty-genes")
   148	  }
   149	  req <- list(argsBody = list(genes = list()), user = list(user_id = NULL))
   150	  res <- job_endpoint_fake_res()
   151	
   152	  out <- env$svc_job_submit_functional_clustering(req, res)
   153	
   154	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   155	  expect_equal(res$status, 409)
   156	  expect_equal(out$error, "DUPLICATE_JOB")
   157	})
   158	
   159	test_that("functional clustering: an explicit-null category_filter KEY (no genes) coerces to an empty selector and delegates to the resolver (Codex round-5 review fix)", {
   160	  # Bug: the branch used `category_supplied <- !is.null(category_filter)`, so a
   161	  # present-but-null `category_filter` key (`{"category_filter":null}`) was
   162	  # treated as ABSENT and silently resolved the all-NDD default instead of the
   163	  # required supplied-empty 400 -- the category-side symmetry of the genes-null
   164	  # fix. The branch now keys off `"category_filter" %in% names(req$argsBody)`.
   165	  #
   166	  # Round 5: the service no longer raises its own standalone 400 for this case
   167	  # (that duplicated the resolver's message and omitted the allowed active-
   168	  # category set). It now coerces the NULL to an empty selector (`list()`) and
   169	  # DELEGATES to `clustering_resolve_category_universe()`, which 400s a
   170	  # supplied-but-empty selector with the allowed set in the message (covered
   171	  # by test-unit-clustering-gene-universe.R). This test proves the DELEGATION
   172	  # (empty selector reaches the resolver), not the 400 itself.
   173	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   174	  source_api_file("core/errors.R", local = FALSE, envir = env)
   175	  env$pool <- job_endpoint_functional_pool(env)
   176	  job_endpoint_stub_clustering_provenance(env)
   177	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   178	  env$async_job_capacity_exceeded <- function(...) FALSE
   179	  env$async_job_active_count <- function(...) 0L
   180	  env$async_job_service_submit <- function(...) list(job = tibble::tibble(job_id = "j-null-cf"))
   181	  captured_cf <- "not-called"
   182	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
   183	    captured_cf <<- category_filter
   184	    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "x", resolved_gene_count = 2L)
   185	  }
   186	  req <- list(
   187	    argsBody = list(category_filter = NULL),
   188	    user = list(user_id = NULL)
   189	  )
   190	  res <- job_endpoint_fake_res()
   191	
   192	  expect_true("category_filter" %in% names(req$argsBody))
   193	  env$svc_job_submit_functional_clustering(req, res)
   194	
   195	  expect_equal(length(captured_cf), 0L) # NULL coerced to an empty selector, not skipped
   196	})
   197	
   198	test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
   199	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   200	  env$pool <- job_endpoint_functional_pool(env)
   201	  job_endpoint_stub_clustering_provenance(env)
   202	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
   203	    expect_identical(category_filter, list("Definitive"))
   204	    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
   205	  }
   206	  env$check_duplicate_job <- function(operation, params) {
   207	    expect_true("category_filter" %in% names(params))
   208	    expect_identical(params$category_filter, "Definitive")
   209	    list(duplicate = FALSE)
   210	  }
   211	  env$async_job_capacity_exceeded <- function(...) FALSE
   212	  env$async_job_active_count <- function(...) 0L
   213	  captured <- NULL
   214	  captured_hash_params <- NULL
   215	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   216	                                            submitted_by = NULL, ...) {
   217	    captured <<- request_payload
   218	    captured_hash_params <<- hash_payload
   219	    list(job = tibble::tibble(job_id = "j1"))
   220	  }
   221	  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
   222	  res <- job_endpoint_fake_res()
   223	
   224	  out <- env$svc_job_submit_functional_clustering(req, res)
   225	
   226	  expect_equal(res$status, 202)
   227	  expect_identical(captured$category_filter, "Definitive")
   228	  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
   229	  expect_identical(captured$provenance$selector$kind, "category")
   230	  expect_identical(captured$provenance$selector$category_filter, "Definitive")
   231	  expect_true(all(
   232	    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
   233	      names(captured$provenance)
   234	  ))
   235	
   236	  # Codex round-3 fix: a category run's hash payload keeps `category_filter`
   237	  # (selector-aware dedup) but still excludes `provenance`.
   238	  expect_true("category_filter" %in% names(captured_hash_params))
   239	  expect_identical(captured_hash_params$category_filter, "Definitive")
   240	  expect_false("provenance" %in% names(captured_hash_params))
   241	})
   242	
   243	test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
   244	  # Explicit genes.
   245	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   246	  env$pool <- job_endpoint_functional_pool(env)
   247	  job_endpoint_stub_clustering_provenance(env)
   248	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   249	  env$async_job_capacity_exceeded <- function(...) FALSE
   250	  env$async_job_active_count <- function(...) 0L
   251	  captured_explicit <- NULL
   252	  captured_explicit_hash_params <- NULL
   253	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   254	                                            submitted_by = NULL, ...) {
   255	    captured_explicit <<- request_payload
   256	    captured_explicit_hash_params <<- hash_payload
   257	    list(job = tibble::tibble(job_id = "j2"))
   258	  }
   259	  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   260	  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
   261	
   262	  expect_false("category_filter" %in% names(captured_explicit))
   263	  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
   264	  expect_null(captured_explicit$provenance$selector$category_filter)
   265	  expect_false("provenance" %in% names(captured_explicit_hash_params))
   266	  expect_false("category_filter" %in% names(captured_explicit_hash_params))
   267	
   268	  # No-arg (all-NDD default).
   269	  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
   270	  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
   271	    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
   272	  ))
   273	  job_endpoint_stub_clustering_provenance(env2)
   274	  job_endpoint_stub_all_ndd_universe(env2)
   275	  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
   276	  env2$async_job_capacity_exceeded <- function(...) FALSE
   277	  env2$async_job_active_count <- function(...) 0L
   278	  captured_no_arg <- NULL
   279	  captured_no_arg_hash_params <- NULL
   280	  env2$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   281	                                             submitted_by = NULL, ...) {
   282	    captured_no_arg <<- request_payload
   283	    captured_no_arg_hash_params <<- hash_payload
   284	    list(job = tibble::tibble(job_id = "j3"))
   285	  }
   286	  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
   287	  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
   288	
   289	  expect_false("category_filter" %in% names(captured_no_arg))
   290	  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
   291	  expect_null(captured_no_arg$provenance$selector$category_filter)
   292	  expect_false("provenance" %in% names(captured_no_arg_hash_params))
   293	  expect_false("category_filter" %in% names(captured_no_arg_hash_params))
   294	})
   295	
   296	test_that("functional clustering: two explicit submits with different provenance source_data_version produce the SAME hash_params (Codex round 3)", {
   297	  # The whole point of the fix: `source_data_version` (and the STRING cache
   298	  # fingerprint) are time-varying provenance fields, so two otherwise-
   299	  # identical submits observed at different moments (e.g. across a snapshot
   300	  # refresh / deploy) must resolve to the IDENTICAL dedup identity -- only the
   301	  # STORED payload (`provenance`) is allowed to differ.
   302	  submit_and_capture <- function(source_data_version) {
   303	    env <- job_endpoint_source_service("job-functional-submission-service.R")
   304	    env$pool <- job_endpoint_functional_pool(env)
   305	    env$analysis_string_cache_fingerprint <- function() "fp-test"
   306	    env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
   307	    env$clustering_cached_source_data_version <- function(...) source_data_version
   308	    env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   309	    env$async_job_capacity_exceeded <- function(...) FALSE
   310	    env$async_job_active_count <- function(...) 0L
   311	    captured_hash_params <- NULL
   312	    captured_provenance <- NULL
   313	    env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   314	                                              submitted_by = NULL, ...) {
   315	      captured_hash_params <<- hash_payload
   316	      captured_provenance <<- request_payload$provenance
   317	      list(job = tibble::tibble(job_id = "j-provenance"))
   318	    }
   319	    req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   320	    env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
   321	    list(hash_params = captured_hash_params, provenance = captured_provenance)
   322	  }
   323	
   324	  run_a <- submit_and_capture("2026-01-01T00:00:00Z")
   325	  run_b <- submit_and_capture("2026-07-18T00:00:00Z")
   326	
   327	  # Different STORED provenance...
   328	  expect_false(identical(run_a$provenance$source_data_version, run_b$provenance$source_data_version))
   329	  # ...but IDENTICAL dedup hash payload (provenance excluded).
   330	  expect_identical(run_a$hash_params, run_b$hash_params)
   331	})
   332	
   333	test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
   334	  # `gene_list_sha256` hashes sort(unique(...)), so `resolved_gene_count` must
   335	  # be computed the same way -- otherwise a duplicate-gene payload
   336	  # (`["HGNC:1","HGNC:1"]`) reports resolved_gene_count=2 alongside a
   337	  # singleton sha256. The payload `genes` list itself must stay
   338	  # byte-identical to the raw request (never deduped) -- only the COUNT
   339	  # field changes.
   340	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   341	  env$pool <- job_endpoint_functional_pool(env)
   342	  job_endpoint_stub_clustering_provenance(env)
   343	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   344	  env$async_job_capacity_exceeded <- function(...) FALSE
   345	  env$async_job_active_count <- function(...) 0L
   346	  captured <- NULL
   347	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   348	                                            submitted_by = NULL, ...) {
   349	    captured <<- request_payload
   350	    list(job = tibble::tibble(job_id = "j-dup-genes"))
   351	  }
   352	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
   353	  res <- job_endpoint_fake_res()
   354	
   355	  env$svc_job_submit_functional_clustering(req, res)
   356	
   357	  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
   358	  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
   359	})
   360	
   361	test_that("functional clustering: request_hash is selector-aware for category_filter", {
   362	  # Pure-function coverage of the underlying dedup identity: sourced directly
   363	  # (not via the service env) since these are free functions in
   364	  # functions/async-job-service.R, not bare globals the service references.
   365	  hash_env <- new.env(parent = globalenv())
   366	  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)
   367	
   368	  h <- function(genes, algo, cf) {
   369	    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
   370	    hash_env$async_job_service_request_hash(
   371	      "clustering",
   372	      hash_env$async_job_service_payload_json(payload)
   373	    )
   374	  }
   375	  g <- c("HGNC:1", "HGNC:5")
   376	
   377	  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
   378	  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
   379	  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
   380	})
   381	
   382	test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
   383	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   384	  env$pool <- job_endpoint_functional_pool(env)
   385	  env$analysis_string_cache_fingerprint <- function() "fp-test"
   386	  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
   387	  env$clustering_cached_source_data_version <- function(...) stop("boom")
   388	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   389	  submit_called <- FALSE
   390	  env$async_job_service_submit <- function(...) {
   391	    submit_called <<- TRUE
   392	    NULL
   393	  }
   394	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   395	  res <- job_endpoint_fake_res()
   396	
   397	  out <- env$svc_job_submit_functional_clustering(req, res)
   398	
   399	  expect_equal(res$status, 503L)
   400	  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   401	  expect_false(submit_called)
   402	})

exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-unit-job-endpoint-services-category.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# tests/testthat/test-unit-job-endpoint-services-category.R
     2	#
     3	# Host-runnable unit tests for the #574 (D2) category_filter / provenance /
     4	# dedup-hash-payload coverage of job-functional-submission-service.R, split
     5	# out of test-unit-job-endpoint-services.R (which keeps the base functional-
     6	# clustering submit coverage) to keep both files under the 600-line ceiling
     7	# after the #574 Codex-review-fix rounds grew this coverage. Shared fixtures
     8	# live in job-endpoint-services-fixtures.R (explicitly sourced below,
     9	# mirroring the sibling files). See test-unit-job-endpoint-services.R's
    10	# header for the full split rationale (phenotype submission coverage lives in
    11	# test-unit-job-endpoint-services-phenotype.R; maintenance-submission +
    12	# query-endpoint services are covered in
    13	# test-unit-job-endpoint-services-maintenance.R).
    14	#
    15	# Each service is sourced directly into an isolated environment via sys.source()
    16	# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
    17	# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
    18	# async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
    19	# gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
    20	# exercise pure request/response logic without a live DB or mirai daemon pool.
    21	
    22	# Resolve api_dir robustly so the file runs both under the full suite and a single-file
    23	# testthat::test_file(), then source the shared fixtures.
    24	if (exists("get_api_dir")) {
    25	  api_dir <- get_api_dir()
    26	} else {
    27	  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
    28	  if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
    29	    api_dir <- normalizePath(getwd(), mustWork = FALSE)
    30	  }
    31	}
    32	# local = TRUE keeps the shared helpers in this test file's environment (as if defined
    33	# inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
    34	source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)
    35	
    36	## -------------------------------------------------------------------##
    37	## job-functional-submission-service.R: category_filter (#574 D2)
    38	## -------------------------------------------------------------------##
    39	
    40	test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
    41	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    42	  # stop_for_bad_request() lives in core/errors.R, not sourced by the isolated
    43	  # service env by default -- source it here so the real (non-stubbed)
    44	  # mutual-exclusion guard in the service body can raise it.
    45	  source_api_file("core/errors.R", local = FALSE, envir = env)
    46	  env$pool <- job_endpoint_functional_pool(env)
    47	  req <- list(
    48	    argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive")),
    49	    user = list(user_id = NULL)
    50	  )
    51	  res <- job_endpoint_fake_res()
    52	
    53	  expect_error(
    54	    env$svc_job_submit_functional_clustering(req, res),
    55	    class = "error_400"
    56	  )
    57	})
    58	
    59	test_that("functional clustering: an EMPTY genes array + category_filter still triggers mutual exclusion -> error_400 (Codex review fix)", {
    60	  # Bug: mutual exclusion was previously gated on `has_genes` (a LENGTH
    61	  # check), so `{"genes":[], "category_filter":["Definitive"]}` bypassed it
    62	  # -- an empty-but-PRESENT `genes` key must still 400 when a category_filter
    63	  # is also present. Presence (`genes_supplied <- !is.null(genes_in)`), not
    64	  # length, is what mutual exclusion must gate on.
    65	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    66	  source_api_file("core/errors.R", local = FALSE, envir = env)
    67	  env$pool <- job_endpoint_functional_pool(env)
    68	  req <- list(
    69	    argsBody = list(genes = list(), category_filter = list("Definitive")),
    70	    user = list(user_id = NULL)
    71	  )
    72	  res <- job_endpoint_fake_res()
    73	
    74	  expect_error(
    75	    env$svc_job_submit_functional_clustering(req, res),
    76	    class = "error_400"
    77	  )
    78	})
    79	
    80	test_that("functional clustering: an explicit-null genes KEY + category_filter still triggers mutual exclusion -> error_400 (Codex round-2 review fix)", {
    81	  # Bug: mutual exclusion was gated on `!is.null(genes_in)`, which cannot
    82	  # distinguish an ABSENT `genes` key from an explicit JSON `null` (both
    83	  # parse to a NULL `req$argsBody$genes`) -- so
    84	  # `{"genes":null, "category_filter":["Definitive"]}` bypassed the guard and
    85	  # a category job was silently accepted. `list(genes = NULL)` in base R
    86	  # KEEPS the `genes` name with a NULL value (verified:
    87	  # "genes" %in% names(list(genes = NULL)) is TRUE), so gating on
    88	  # `names(req$argsBody)` instead of value-nullness catches this.
    89	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    90	  source_api_file("core/errors.R", local = FALSE, envir = env)
    91	  env$pool <- job_endpoint_functional_pool(env)
    92	  req <- list(
    93	    argsBody = list(genes = NULL, category_filter = list("Definitive")),
    94	    user = list(user_id = NULL)
    95	  )
    96	  res <- job_endpoint_fake_res()
    97	
    98	  expect_true("genes" %in% names(req$argsBody)) # pin the base-R name-retention fact this test relies on
    99	  expect_error(
   100	    env$svc_job_submit_functional_clustering(req, res),
   101	    class = "error_400"
   102	  )
   103	})
   104	
   105	test_that("functional clustering: an explicit-null genes KEY ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
   106	  # Regression guard for the fix above: gating mutual exclusion on JSON key
   107	  # presence must NOT change the pre-existing behavior for a null `genes`
   108	  # value with no `category_filter` at all -- it must still fall through to
   109	  # the all-NDD default exactly as before.
   110	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   111	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
   112	    entity_id = 1:3,
   113	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
   114	    ndd_phenotype = c(1L, 0L, 1L)
   115	  ))
   116	  job_endpoint_stub_all_ndd_universe(env)
   117	  captured <- NULL
   118	  env$check_duplicate_job <- function(operation, params) {
   119	    captured <<- params
   120	    list(duplicate = TRUE, existing_job_id = "dup-null-genes")
   121	  }
   122	  req <- list(argsBody = list(genes = NULL), user = list(user_id = NULL))
   123	  res <- job_endpoint_fake_res()
   124	
   125	  out <- env$svc_job_submit_functional_clustering(req, res)
   126	
   127	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   128	  expect_equal(res$status, 409)
   129	  expect_equal(out$error, "DUPLICATE_JOB")
   130	})
   131	
   132	test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
   133	  # Regression guard for the fix above: gating mutual exclusion on
   134	  # `genes_supplied` (key presence) must NOT change the pre-existing
   135	  # behavior for an empty `genes` array with no `category_filter` at all --
   136	  # it must still fall through to the all-NDD default exactly as before.
   137	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   138	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
   139	    entity_id = 1:3,
   140	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
   141	    ndd_phenotype = c(1L, 0L, 1L)
   142	  ))
   143	  job_endpoint_stub_all_ndd_universe(env)
   144	  captured <- NULL
   145	  env$check_duplicate_job <- function(operation, params) {
   146	    captured <<- params
   147	    list(duplicate = TRUE, existing_job_id = "dup-empty-genes")
   148	  }
   149	  req <- list(argsBody = list(genes = list()), user = list(user_id = NULL))
   150	  res <- job_endpoint_fake_res()
   151	
   152	  out <- env$svc_job_submit_functional_clustering(req, res)
   153	
   154	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   155	  expect_equal(res$status, 409)
   156	  expect_equal(out$error, "DUPLICATE_JOB")
   157	})
   158	
   159	test_that("functional clustering: an explicit-null category_filter KEY (no genes) coerces to an empty selector and delegates to the resolver (Codex round-5 review fix)", {
   160	  # Bug: the branch used `category_supplied <- !is.null(category_filter)`, so a
   161	  # present-but-null `category_filter` key (`{"category_filter":null}`) was
   162	  # treated as ABSENT and silently resolved the all-NDD default instead of the
   163	  # required supplied-empty 400 -- the category-side symmetry of the genes-null
   164	  # fix. The branch now keys off `"category_filter" %in% names(req$argsBody)`.
   165	  #
   166	  # Round 5: the service no longer raises its own standalone 400 for this case
   167	  # (that duplicated the resolver's message and omitted the allowed active-
   168	  # category set). It now coerces the NULL to an empty selector (`list()`) and
   169	  # DELEGATES to `clustering_resolve_category_universe()`, which 400s a
   170	  # supplied-but-empty selector with the allowed set in the message (covered
   171	  # by test-unit-clustering-gene-universe.R). This test proves the DELEGATION
   172	  # (empty selector reaches the resolver), not the 400 itself.
   173	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   174	  source_api_file("core/errors.R", local = FALSE, envir = env)
   175	  env$pool <- job_endpoint_functional_pool(env)
   176	  job_endpoint_stub_clustering_provenance(env)
   177	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   178	  env$async_job_capacity_exceeded <- function(...) FALSE
   179	  env$async_job_active_count <- function(...) 0L
   180	  env$async_job_service_submit <- function(...) list(job = tibble::tibble(job_id = "j-null-cf"))
   181	  captured_cf <- "not-called"
   182	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
   183	    captured_cf <<- category_filter
   184	    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "x", resolved_gene_count = 2L)
   185	  }
   186	  req <- list(
   187	    argsBody = list(category_filter = NULL),
   188	    user = list(user_id = NULL)
   189	  )
   190	  res <- job_endpoint_fake_res()
   191	
   192	  expect_true("category_filter" %in% names(req$argsBody))
   193	  env$svc_job_submit_functional_clustering(req, res)
   194	
   195	  expect_equal(length(captured_cf), 0L) # NULL coerced to an empty selector, not skipped
   196	})
   197	
   198	test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
   199	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   200	  env$pool <- job_endpoint_functional_pool(env)
   201	  job_endpoint_stub_clustering_provenance(env)
   202	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
   203	    expect_identical(category_filter, list("Definitive"))
   204	    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
   205	  }
   206	  env$check_duplicate_job <- function(operation, params) {
   207	    expect_true("category_filter" %in% names(params))
   208	    expect_identical(params$category_filter, "Definitive")
   209	    list(duplicate = FALSE)
   210	  }
   211	  env$async_job_capacity_exceeded <- function(...) FALSE
   212	  env$async_job_active_count <- function(...) 0L
   213	  captured <- NULL
   214	  captured_hash_params <- NULL
   215	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   216	                                            submitted_by = NULL, ...) {
   217	    captured <<- request_payload
   218	    captured_hash_params <<- hash_payload
   219	    list(job = tibble::tibble(job_id = "j1"))
   220	  }
   221	  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
   222	  res <- job_endpoint_fake_res()
   223	
   224	  out <- env$svc_job_submit_functional_clustering(req, res)
   225	
   226	  expect_equal(res$status, 202)
   227	  expect_identical(captured$category_filter, "Definitive")
   228	  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
   229	  expect_identical(captured$provenance$selector$kind, "category")
   230	  expect_identical(captured$provenance$selector$category_filter, "Definitive")
   231	  expect_true(all(
   232	    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
   233	      names(captured$provenance)
   234	  ))
   235	
   236	  # Codex round-3 fix: a category run's hash payload keeps `category_filter`
   237	  # (selector-aware dedup) but still excludes `provenance`.
   238	  expect_true("category_filter" %in% names(captured_hash_params))
   239	  expect_identical(captured_hash_params$category_filter, "Definitive")
   240	  expect_false("provenance" %in% names(captured_hash_params))
   241	})
   242	
   243	test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
   244	  # Explicit genes.
   245	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   246	  env$pool <- job_endpoint_functional_pool(env)
   247	  job_endpoint_stub_clustering_provenance(env)
   248	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   249	  env$async_job_capacity_exceeded <- function(...) FALSE
   250	  env$async_job_active_count <- function(...) 0L
   251	  captured_explicit <- NULL
   252	  captured_explicit_hash_params <- NULL
   253	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   254	                                            submitted_by = NULL, ...) {
   255	    captured_explicit <<- request_payload
   256	    captured_explicit_hash_params <<- hash_payload
   257	    list(job = tibble::tibble(job_id = "j2"))
   258	  }
   259	  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   260	  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
   261	
   262	  expect_false("category_filter" %in% names(captured_explicit))
   263	  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
   264	  expect_null(captured_explicit$provenance$selector$category_filter)
   265	  expect_false("provenance" %in% names(captured_explicit_hash_params))
   266	  expect_false("category_filter" %in% names(captured_explicit_hash_params))
   267	
   268	  # No-arg (all-NDD default).
   269	  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
   270	  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
   271	    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
   272	  ))
   273	  job_endpoint_stub_clustering_provenance(env2)
   274	  job_endpoint_stub_all_ndd_universe(env2)
   275	  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
   276	  env2$async_job_capacity_exceeded <- function(...) FALSE
   277	  env2$async_job_active_count <- function(...) 0L
   278	  captured_no_arg <- NULL
   279	  captured_no_arg_hash_params <- NULL
   280	  env2$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   281	                                             submitted_by = NULL, ...) {
   282	    captured_no_arg <<- request_payload
   283	    captured_no_arg_hash_params <<- hash_payload
   284	    list(job = tibble::tibble(job_id = "j3"))
   285	  }
   286	  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
   287	  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
   288	
   289	  expect_false("category_filter" %in% names(captured_no_arg))
   290	  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
   291	  expect_null(captured_no_arg$provenance$selector$category_filter)
   292	  expect_false("provenance" %in% names(captured_no_arg_hash_params))
   293	  expect_false("category_filter" %in% names(captured_no_arg_hash_params))
   294	})
   295	
   296	test_that("functional clustering: two explicit submits with different provenance source_data_version produce the SAME hash_params (Codex round 3)", {
   297	  # The whole point of the fix: `source_data_version` (and the STRING cache
   298	  # fingerprint) are time-varying provenance fields, so two otherwise-
   299	  # identical submits observed at different moments (e.g. across a snapshot
   300	  # refresh / deploy) must resolve to the IDENTICAL dedup identity -- only the
   301	  # STORED payload (`provenance`) is allowed to differ.
   302	  submit_and_capture <- function(source_data_version) {
   303	    env <- job_endpoint_source_service("job-functional-submission-service.R")
   304	    env$pool <- job_endpoint_functional_pool(env)
   305	    env$analysis_string_cache_fingerprint <- function() "fp-test"
   306	    env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
   307	    env$clustering_cached_source_data_version <- function(...) source_data_version
   308	    env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   309	    env$async_job_capacity_exceeded <- function(...) FALSE
   310	    env$async_job_active_count <- function(...) 0L
   311	    captured_hash_params <- NULL
   312	    captured_provenance <- NULL
   313	    env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   314	                                              submitted_by = NULL, ...) {
   315	      captured_hash_params <<- hash_payload
   316	      captured_provenance <<- request_payload$provenance
   317	      list(job = tibble::tibble(job_id = "j-provenance"))
   318	    }
   319	    req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   320	    env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
   321	    list(hash_params = captured_hash_params, provenance = captured_provenance)
   322	  }
   323	
   324	  run_a <- submit_and_capture("2026-01-01T00:00:00Z")
   325	  run_b <- submit_and_capture("2026-07-18T00:00:00Z")
   326	
   327	  # Different STORED provenance...
   328	  expect_false(identical(run_a$provenance$source_data_version, run_b$provenance$source_data_version))
   329	  # ...but IDENTICAL dedup hash payload (provenance excluded).
   330	  expect_identical(run_a$hash_params, run_b$hash_params)
   331	})
   332	
   333	test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
   334	  # `gene_list_sha256` hashes sort(unique(...)), so `resolved_gene_count` must
   335	  # be computed the same way -- otherwise a duplicate-gene payload
   336	  # (`["HGNC:1","HGNC:1"]`) reports resolved_gene_count=2 alongside a
   337	  # singleton sha256. The payload `genes` list itself must stay
   338	  # byte-identical to the raw request (never deduped) -- only the COUNT
   339	  # field changes.
   340	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   341	  env$pool <- job_endpoint_functional_pool(env)
   342	  job_endpoint_stub_clustering_provenance(env)
   343	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   344	  env$async_job_capacity_exceeded <- function(...) FALSE
   345	  env$async_job_active_count <- function(...) 0L
   346	  captured <- NULL
   347	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   348	                                            submitted_by = NULL, ...) {
   349	    captured <<- request_payload
   350	    list(job = tibble::tibble(job_id = "j-dup-genes"))
   351	  }
   352	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
   353	  res <- job_endpoint_fake_res()
   354	
   355	  env$svc_job_submit_functional_clustering(req, res)
   356	
   357	  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
   358	  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
   359	})
   360	
   361	test_that("functional clustering: request_hash is selector-aware for category_filter", {
   362	  # Pure-function coverage of the underlying dedup identity: sourced directly
   363	  # (not via the service env) since these are free functions in
   364	  # functions/async-job-service.R, not bare globals the service references.
   365	  hash_env <- new.env(parent = globalenv())
   366	  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)
   367	
   368	  h <- function(genes, algo, cf) {
   369	    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
   370	    hash_env$async_job_service_request_hash(
   371	      "clustering",
   372	      hash_env$async_job_service_payload_json(payload)
   373	    )
   374	  }
   375	  g <- c("HGNC:1", "HGNC:5")
   376	
   377	  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
   378	  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
   379	  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
   380	})
   381	
   382	test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
   383	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   384	  env$pool <- job_endpoint_functional_pool(env)
   385	  env$analysis_string_cache_fingerprint <- function() "fp-test"
   386	  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
   387	  env$clustering_cached_source_data_version <- function(...) stop("boom")
   388	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   389	  submit_called <- FALSE
   390	  env$async_job_service_submit <- function(...) {
   391	    submit_called <<- TRUE
   392	    NULL
   393	  }
   394	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   395	  res <- job_endpoint_fake_res()
   396	
   397	  out <- env$svc_job_submit_functional_clustering(req, res)
   398	
   399	  expect_equal(res$status, 503L)
   400	  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   401	  expect_false(submit_called)
   402	})

exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-unit-clustering-gene-universe.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# Unit tests for the category-selected clustering gene-universe resolver (#574 D1).
     2	#
     3	# `clustering_resolve_category_universe()` resolves the gene set a clustering
     4	# job runs on: either the current default (all NDD genes, via
     5	# `generate_ndd_hgnc_ids()`) or a curated-category selection
     6	# (`ndd_entity_view` entity rows filtered by `category %in% selector`, then
     7	# distinct `hgnc_id`). This file is DB-free: the default branch's dependency
     8	# (`generate_ndd_hgnc_ids()`) is overridden in a child environment, and the
     9	# category branch's `conn` is a real in-memory RSQLite connection so the
    10	# dbplyr pipeline (`tbl()` / `filter()` / `select()` / `collect()`) is
    11	# exercised for real rather than mocked.
    12	#
    13	# Trap: do NOT stub `generate_ndd_hgnc_ids` via
    14	# `testthat::local_mocked_bindings(..., .env = globalenv())` -- under
    15	# testthat 3.3.2 that aborts with "No packages loaded with pkgload" because
    16	# globalenv() has no package namespace. A child-env override sidesteps this.
    17	
    18	## -------------------------------------------------------------------------##
    19	## clustering_cached_source_data_version() TTL cache (#574 D2 review fix)
    20	## -------------------------------------------------------------------------##
    21	#
    22	# These tests stub `analysis_snapshot_source_data_version()` directly -- no DB
    23	# connection is ever opened -- so they are placed BEFORE the file-wide
    24	# `skip_if_not_installed("RSQLite")` gate below and run unconditionally, even
    25	# when {RSQLite} is unavailable.
    26	
    27	# Sources ONLY core/errors.R + the module under test into a fresh child env.
    28	# A fresh env means a fresh `.clustering_source_data_version_cache` (it is
    29	# created top-level by the sourced file), so there is nothing left over from
    30	# a prior test -- `.reset_source_data_version_cache()` below is still applied
    31	# defensively so the reset mechanism itself stays covered/documented.
    32	.source_data_version_env <- function() {
    33	  e <- new.env(parent = globalenv())
    34	  source_api_file("core/errors.R", local = FALSE, envir = e)
    35	  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
    36	  e
    37	}
    38	
    39	# Clears the module-level TTL cache env so cached state never leaks across
    40	# assertions sharing the same sourced env `e`.
    41	.reset_source_data_version_cache <- function(e) {
    42	  cache_env <- e$.clustering_source_data_version_cache
    43	  keys <- ls(cache_env, all.names = TRUE)
    44	  if (length(keys) > 0L) rm(list = keys, envir = cache_env)
    45	}
    46	
    47	test_that("clustering_cached_source_data_version: TTL hit avoids a second underlying fetch", {
    48	  e <- .source_data_version_env()
    49	  .reset_source_data_version_cache(e)
    50	  calls <- 0L
    51	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
    52	    calls <<- calls + 1L
    53	    "v1"
    54	  }
    55	
    56	  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
    57	  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
    58	
    59	  expect_identical(first, "v1")
    60	  expect_identical(second, "v1")
    61	  expect_identical(calls, 1L) # second call served from cache, underlying fn NOT re-invoked
    62	})
    63	
    64	test_that("clustering_cached_source_data_version: TTL expiry (ttl_seconds = 0) forces a refetch", {
    65	  # `diff < ttl_seconds` is the staleness check; `diff` (elapsed seconds since
    66	  # the last successful fetch) is always >= 0, so `ttl_seconds = 0` makes
    67	  # `diff < 0` FALSE on every subsequent call -- deterministically always-stale,
    68	  # regardless of clock resolution between the two calls.
    69	  e <- .source_data_version_env()
    70	  .reset_source_data_version_cache(e)
    71	  calls <- 0L
    72	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
    73	    calls <<- calls + 1L
    74	    paste0("v", calls)
    75	  }
    76	
    77	  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
    78	  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
    79	
    80	  expect_identical(first, "v1")
    81	  expect_identical(second, "v2")
    82	  expect_identical(calls, 2L) # both calls hit the underlying fn -- cache never served a hit
    83	})
    84	
    85	test_that("clustering_cached_source_data_version: an error propagates and never poisons the cache", {
    86	  e <- .source_data_version_env()
    87	  .reset_source_data_version_cache(e)
    88	  e$analysis_snapshot_source_data_version <- function(conn = NULL) stop("boom")
    89	
    90	  expect_error(
    91	    e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300),
    92	    "boom"
    93	  )
    94	  # Nothing was written to the cache by the failed call.
    95	  expect_null(e$.clustering_source_data_version_cache$value)
    96	  expect_null(e$.clustering_source_data_version_cache$cached_at)
    97	
    98	  # Swap to a success stub: the NEXT call must refetch (not serve a stale/NA
    99	  # value left over from the failed attempt) and the cache must now work.
   100	  .reset_source_data_version_cache(e)
   101	  calls <- 0L
   102	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
   103	    calls <<- calls + 1L
   104	    "v-success"
   105	  }
   106	
   107	  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
   108	
   109	  expect_identical(result, "v-success")
   110	  expect_identical(calls, 1L)
   111	})
   112	
   113	test_that("clustering_cached_source_data_version: NA_character_ from the underlying fetch is rejected and never cached (Codex review fix)", {
   114	  # Fail-closed contract: the TTL cache must never cache/return NA. A
   115	  # malformed underlying value must stop() (mapped to 503 by the caller's
   116	  # tryCatch), exactly like a hard fetch error above -- not be cached and
   117	  # served as broken provenance.
   118	  e <- .source_data_version_env()
   119	  .reset_source_data_version_cache(e)
   120	  calls <- 0L
   121	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
   122	    calls <<- calls + 1L
   123	    NA_character_
   124	  }
   125	
   126	  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
   127	  # Nothing was written to the cache by the invalid-value call.
   128	  expect_null(e$.clustering_source_data_version_cache$value)
   129	  expect_null(e$.clustering_source_data_version_cache$cached_at)
   130	
   131	  # Swap to a now-valid stub: the NEXT call must refetch (never serve the
   132	  # invalid value from a poisoned cache) and the counter must increment.
   133	  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
   134	    calls <<- calls + 1L
   135	    "v-valid"
   136	  }
   137	  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
   138	
   139	  expect_identical(result, "v-valid")
   140	  expect_identical(calls, 2L)
   141	})
   142	
   143	test_that("clustering_cached_source_data_version: an empty string from the underlying fetch is rejected and never cached (Codex review fix)", {
   144	  e <- .source_data_version_env()
   145	  .reset_source_data_version_cache(e)
   146	  e$analysis_snapshot_source_data_version <- function(conn = NULL) ""
   147	
   148	  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
   149	  expect_null(e$.clustering_source_data_version_cache$value)
   150	  expect_null(e$.clustering_source_data_version_cache$cached_at)
   151	})
   152	
   153	testthat::skip_if_not_installed("RSQLite")
   154	
   155	# Source the code under test into a child env so the NULL-branch dependency
   156	# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
   157	# globalenv() or any other test file's bindings.
   158	.gene_universe_env <- function() {
   159	  e <- new.env(parent = globalenv())
   160	  source_api_file("core/errors.R", local = FALSE, envir = e)
   161	  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
   162	  e
   163	}
   164	
   165	# In-memory RSQLite fixture standing in for `pool`/a real DB connection.
   166	# `ev` = ndd_entity_view rows, `cats` = ndd_entity_status_categories_list rows.
   167	fake_conn <- function(ev, cats) {
   168	  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
   169	  DBI::dbWriteTable(con, "ndd_entity_view", as.data.frame(ev))
   170	  DBI::dbWriteTable(con, "ndd_entity_status_categories_list", as.data.frame(cats))
   171	  con
   172	}
   173	
   174	# Fixture: entity rows (one row per entity). TWO Definitive NDD genes so the
   175	# ["Definitive"] universe passes the >=2 guard.
   176	ev <- tibble::tribble(
   177	  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
   178	  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
   179	  2L,        "HGNC:1",   1L,             "Limited",
   180	  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
   181	  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
   182	  5L,        "HGNC:4",   1L,             "Moderate",     # gene 4: Moderate NDD (single -> too-small alone)
   183	  6L,        "HGNC:5",   1L,             "Definitive"    # gene 5: second Definitive NDD gene
   184	)
   185	cats <- tibble::tibble(
   186	  category = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
   187	  is_active = 1L
   188	)
   189	
   190	test_that("Definitive selects genes with any Definitive NDD entity (multi-entity gene included)", {
   191	  e <- .gene_universe_env()
   192	  con <- fake_conn(ev, cats)
   193	  withr::defer(DBI::dbDisconnect(con))
   194	
   195	  r <- e$clustering_resolve_category_universe("Definitive", conn = con)
   196	
   197	  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5")) # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
   198	  expect_identical(r$selector, "Definitive")
   199	  expect_identical(r$resolved_gene_count, 2L)
   200	})
   201	
   202	test_that("multi-value selector is a union across categories", {
   203	  e <- .gene_universe_env()
   204	  con <- fake_conn(ev, cats)
   205	  withr::defer(DBI::dbDisconnect(con))
   206	
   207	  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)
   208	
   209	  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5", "HGNC:4"))
   210	})
   211	
   212	test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
   213	  e <- .gene_universe_env()
   214	  con <- fake_conn(ev, cats)
   215	  withr::defer(DBI::dbDisconnect(con))
   216	  e$generate_ndd_hgnc_ids <- function() {
   217	    tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5"))
   218	  }
   219	
   220	  r <- e$clustering_resolve_category_universe(NULL, conn = con)
   221	
   222	  expect_identical(r$hgnc_ids, c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5")) # arrange(entity_id)+distinct, ndd_phenotype==1
   223	  expect_null(r$selector)
   224	})
   225	
   226	test_that("unknown token is rejected 400 with the allowed set in the MESSAGE (not detail)", {
   227	  e <- .gene_universe_env()
   228	  con <- fake_conn(ev, cats)
   229	  withr::defer(DBI::dbDisconnect(con))
   230	
   231	  err <- tryCatch(
   232	    e$clustering_resolve_category_universe("Definative", conn = con),
   233	    error = function(err) err
   234	  )
   235	
   236	  expect_s3_class(err, "error_400")
   237	  expect_match(conditionMessage(err), "Definitive") # allowed set is in the message so it reaches clients
   238	})
   239	
   240	test_that("supplied-but-empty selector is 400 (NOT the all-NDD default) with the allowed set in the message", {
   241	  e <- .gene_universe_env()
   242	  con <- fake_conn(ev, cats)
   243	  withr::defer(DBI::dbDisconnect(con))
   244	
   245	  err_empty <- tryCatch(
   246	    e$clustering_resolve_category_universe(list(), conn = con),
   247	    error = function(err) err
   248	  )
   249	  err_blank <- tryCatch(
   250	    e$clustering_resolve_category_universe(list("   "), conn = con),
   251	    error = function(err) err
   252	  )
   253	
   254	  expect_s3_class(err_empty, "error_400")
   255	  expect_s3_class(err_blank, "error_400")
   256	  # The locked contract: EVERY category-validation 400 names the allowed set.
   257	  expect_match(conditionMessage(err_empty), "Allowed active categories")
   258	  expect_match(conditionMessage(err_empty), "Definitive")
   259	  expect_match(conditionMessage(err_blank), "Allowed active categories")
   260	  expect_match(conditionMessage(err_blank), "Definitive")
   261	})
   262	
   263	test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job) with the allowed set in the message", {
   264	  e <- .gene_universe_env()
   265	  con <- fake_conn(ev, cats)
   266	  withr::defer(DBI::dbDisconnect(con))
   267	
   268	  err_zero <- tryCatch(
   269	    e$clustering_resolve_category_universe("Refuted", conn = con), # 0 genes
   270	    error = function(err) err
   271	  )
   272	  err_one <- tryCatch(
   273	    e$clustering_resolve_category_universe("Moderate", conn = con), # 1 gene
   274	    error = function(err) err
   275	  )
   276	
   277	  expect_s3_class(err_zero, "error_400")
   278	  expect_s3_class(err_one, "error_400")
   279	  expect_match(conditionMessage(err_zero), "Allowed active categories")
   280	  expect_match(conditionMessage(err_zero), "Definitive")
   281	  expect_match(conditionMessage(err_one), "Allowed active categories")
   282	  expect_match(conditionMessage(err_one), "Definitive")
   283	})
   284	
   285	test_that("gene_list_sha256 is sort-order independent", {
   286	  e <- .gene_universe_env()
   287	
   288	  expect_identical(
   289	    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
   290	    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
   291	  )
   292	})
   293	
   294	test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
   295	  e <- .gene_universe_env()
   296	
   297	  expect_null(e$clustering_normalize_category_filter(NULL))
   298	  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
   299	  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
   300	  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
   301	  expect_identical(
   302	    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
   303	    c("Definitive", "Moderate")
   304	  )
   305	})

exec
/bin/bash -lc 'nl -ba api/tests/testthat/job-endpoint-services-fixtures.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# tests/testthat/job-endpoint-services-fixtures.R
     2	#
     3	# Shared fixtures for the job-endpoint-service unit tests, split across four files
     4	# to keep each under the 600-line ceiling:
     5	#   - test-unit-job-endpoint-services.R              (functional submission)
     6	#   - test-unit-job-endpoint-services-category.R     (functional submission:
     7	#                                                      category_filter, #574 D2)
     8	#   - test-unit-job-endpoint-services-phenotype.R    (phenotype submission)
     9	#   - test-unit-job-endpoint-services-maintenance.R  (maintenance submission + query)
    10	# All four files EXPLICITLY source() this file at the top so they run standalone under a
    11	# single-file `testthat::test_file()` (a plain helper-*.R auto-load is not guaranteed
    12	# to run there); mirrors the pubmed-xml-fixtures.R convention.
    13	#
    14	# `pool %>% dplyr::tbl(name)` is faked with a small S3 dispatch trick: a "fake_pool"
    15	# object wrapping a named list of tibbles, plus one `tbl.fake_pool` method registered in
    16	# the environment the service was sourced into (S3 dispatch finds it there). This needs
    17	# no test DB / RSQLite, so every test is a real PASS on host R.
    18	
    19	library(dplyr)
    20	library(tidyr)
    21	
    22	#' Source a service file into a fresh child-of-globalenv environment.
    23	#'
    24	#' The two public clustering submit services now call `async_job_submit_admission_guard()`
    25	#' FIRST (#535 S6) before any DB/cache work; stub it to "admit" by default so these
    26	#' isolated tests exercise the downstream request/response logic. A test can override
    27	#' `env$async_job_submit_admission_guard` to exercise the throttle-block path.
    28	#'
    29	#' Also sources `functions/clustering-gene-universe.R` (#574 D1/D3) into `env` so
    30	#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
    31	#' `job-functional-submission-service.R`'s cache-hit path -- is available for real
    32	#' (a pure list-assembly function, safe to source unstubbed). Individual tests still
    33	#' stub the DB/cache-touching siblings from that same file
    34	#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
    35	#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
    36	#' this sourcing only supplies defaults those stubs override.
    37	job_endpoint_source_service <- function(filename) {
    38	  env <- new.env(parent = globalenv())
    39	  env$async_job_submit_admission_guard <- function(req, res) list(admitted = TRUE)
    40	  sys.source(file.path(get_api_dir(), "functions", "clustering-gene-universe.R"), envir = env)
    41	  sys.source(file.path(get_api_dir(), "services", filename), envir = env)
    42	  env
    43	}
    44	
    45	#' Register `tbl.fake_pool` in `env` and build a fake pool over `tables`.
    46	job_endpoint_fake_pool <- function(env, tables) {
    47	  env$tbl.fake_pool <- function(src, from, ...) src$tables[[from]]
    48	  structure(list(tables = tables), class = "fake_pool")
    49	}
    50	
    51	#' Fake pool for job-functional-submission-service.R tests: always includes
    52	#' `non_alt_loci_set` (the STRING-id pre-fetch table every submit path reads),
    53	#' and optionally an `ndd_entity_view` for tests that exercise the all-NDD
    54	#' default universe. Shared by test-unit-job-endpoint-services.R and
    55	#' test-unit-job-endpoint-services-category.R.
    56	job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
    57	  tables <- list(
    58	    non_alt_loci_set = tibble::tibble(
    59	      symbol = c("A", "B"),
    60	      hgnc_id = c("HGNC:1", "HGNC:3"),
    61	      STRING_id = c("9606.P1", "9606.P2")
    62	    )
    63	  )
    64	  if (!is.null(ndd_entity_view)) {
    65	    tables$ndd_entity_view <- ndd_entity_view
    66	  }
    67	  job_endpoint_fake_pool(env, tables)
    68	}
    69	
    70	#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
    71	#' (#574 D2): reads `ndd_phenotype == 1` rows straight off `env$pool`'s fake
    72	#' `ndd_entity_view`, mirroring what the real resolver's NULL branch
    73	#' (`generate_ndd_hgnc_ids()`) would compute -- without needing the real
    74	#' function (and its DB-query internals) sourced into these isolated envs.
    75	job_endpoint_stub_all_ndd_universe <- function(env) {
    76	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
    77	    testthat::expect_null(category_filter)
    78	    tbl <- env$pool$tables$ndd_entity_view
    79	    hgnc_ids <- unique(dplyr::pull(dplyr::filter(tbl, ndd_phenotype == 1), hgnc_id))
    80	    list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids))
    81	  }
    82	}
    83	
    84	#' Cheap provenance stubs (#574 D2): every submit path that reaches past dedup
    85	#' now computes `intended_fingerprint`/`gene_list_sha256`/`source_data_version`
    86	#' regardless of selector kind, so any test reaching that far needs these
    87	#' three bare globals stubbed even when it does not care about their values.
    88	job_endpoint_stub_clustering_provenance <- function(env) {
    89	  env$analysis_string_cache_fingerprint <- function() "fp-test"
    90	  env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
    91	  env$clustering_cached_source_data_version <- function(...) "srcv-test"
    92	}
    93	
    94	#' Minimal Plumber-response stand-in: an environment with `$status` and a
    95	#' `$setHeader()` that records every header set (mirrors the `res_env`
    96	#' pattern in test-unit-pubtator-enrichment.R).
    97	job_endpoint_fake_res <- function() {
    98	  res <- new.env()
    99	  res$status <- NULL
   100	  res$headers <- list()
   101	  res$setHeader <- function(name, value) {
   102	    res$headers[[name]] <- value
   103	    invisible(NULL)
   104	  }
   105	  res
   106	}

exec
/bin/bash -lc "cd api && Rscript --no-init-file -e \"testthat::test_file('tests/testthat/test-unit-clustering-gene-universe.R'); testthat::test_file('tests/testthat/test-unit-job-endpoint-services-category.R')\"" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 exited 2 in 0ms:
Fatal error: creating temporary file for '-e' failed

codex
The focused test command is blocked by the read-only sandbox because R cannot create its temporary `-e` script. I’ll still verify the paths by static execution tracing and the committed unit/integration assertions, and will clearly distinguish that from a runnable test result.
exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-integration-clustering-category-submit.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# api/tests/testthat/test-integration-clustering-category-submit.R
     2	#
     3	# Real-MySQL integration coverage for the category-selected clustering
     4	# gene-universe resolver (`clustering_resolve_category_universe()`,
     5	# api/functions/clustering-gene-universe.R, #574 D1/D3). Complements the
     6	# DB-free unit tests in test-unit-clustering-gene-universe.R (which use an
     7	# in-memory RSQLite fixture) with assertions against the REAL `sysndd_db_test`
     8	# MySQL `ndd_entity_view` -- proving entity-level resolution with no
     9	# client-side filter and correct MySQL translation of the dbplyr pipeline.
    10	#
    11	# ---------------------------------------------------------------------------
    12	# Deviation from the D3 plan brief, and why (documented per the task's own
    13	# instructions):
    14	#
    15	# The plan brief's literal Step 1 asked this file to seed D1's fixture
    16	# entities (incl. a 2nd "Definitive" gene) directly into `ndd_entity_view`'s
    17	# base tables on the empty test DB. `ndd_entity_view` joins ~7 tables
    18	# (ndd_entity + ndd_entity_status + ndd_entity_status_categories_list +
    19	# boolean_list + disease_ontology_set + mode_of_inheritance_list +
    20	# non_alt_loci_set) with a specific column/FK contract; self-seeding that
    21	# chain here would be fragile, easy to silently drift from the real view
    22	# definition, and largely redundant with the mandated live-container
    23	# end-to-end verification (submitting `category_filter` against the running
    24	# dev stack), which the controller performs separately.
    25	#
    26	# Instead, this file is SKIP-GUARDED on a populated view: it probes the live
    27	# `ndd_entity_view` for a real, currently-active category with >=2 distinct
    28	# NDD (`ndd_phenotype = 1`) genes, and only then runs. On a fresh/empty test
    29	# DB (CI default) every test here SKIPs cleanly. When the test DB is a
    30	# populated clone (a local/staging run), this file exercises the resolver
    31	# against the true view for real -- genuine resolver-vs-real-MySQL-view
    32	# coverage without fragile fixture seeding.
    33	# ---------------------------------------------------------------------------
    34	
    35	library(testthat)
    36	library(DBI)
    37	
    38	source_api_file("core/errors.R", local = FALSE)
    39	source_api_file("functions/clustering-gene-universe.R", local = FALSE)
    40	# The resolver's `is.null(selector)` (NULL/default) branch calls
    41	# `generate_ndd_hgnc_ids()` directly (it does NOT take `conn` on that path --
    42	# see clustering-gene-universe.R), so it must be sourced here too, or Test 3
    43	# below throws "could not find function" instead of exercising the branch.
    44	source_api_file("functions/analyses-functions.R", local = FALSE)
    45	
    46	#' Probe the live `ndd_entity_view` for one real, currently-active category
    47	#' with >=2 distinct NDD (`ndd_phenotype = 1`) genes.
    48	#'
    49	#' Joins against `ndd_entity_status_categories_list WHERE is_active = 1` so
    50	#' the returned category is guaranteed to pass
    51	#' `clustering_resolve_category_universe()`'s own live allowlist check --
    52	#' never returns a category that the resolver itself would reject as
    53	#' unknown/inactive.
    54	#'
    55	#' @param conn DBI connection to the test database.
    56	#' @return character(1) category name, or NULL if no such category exists
    57	#'   (e.g. an empty/fresh test DB, or `ndd_entity_view` is absent).
    58	.clustering_category_probe <- function(conn) {
    59	  if (!DBI::dbExistsTable(conn, "ndd_entity_view")) {
    60	    return(NULL)
    61	  }
    62	  if (!DBI::dbExistsTable(conn, "ndd_entity_status_categories_list")) {
    63	    return(NULL)
    64	  }
    65	
    66	  counts <- tryCatch(
    67	    DBI::dbGetQuery(
    68	      conn,
    69	      paste(
    70	        "SELECT v.category AS category, COUNT(DISTINCT v.hgnc_id) AS gene_count",
    71	        "FROM ndd_entity_view v",
    72	        "INNER JOIN ndd_entity_status_categories_list c",
    73	        "  ON c.category = v.category AND c.is_active = 1",
    74	        "WHERE v.ndd_phenotype = 1",
    75	        "GROUP BY v.category",
    76	        "ORDER BY gene_count DESC"
    77	      )
    78	    ),
    79	    error = function(e) NULL
    80	  )
    81	  if (is.null(counts) || nrow(counts) == 0L) {
    82	    return(NULL)
    83	  }
    84	
    85	  eligible <- counts[counts$gene_count >= 2, , drop = FALSE]
    86	  if (nrow(eligible) == 0L) {
    87	    return(NULL)
    88	  }
    89	
    90	  as.character(eligible$category[[1]])
    91	}
    92	
    93	test_that("clustering_resolve_category_universe matches a direct MySQL query on the real ndd_entity_view", {
    94	  with_test_db_transaction({
    95	    conn <- getOption(".test_db_con")
    96	    probe_category <- .clustering_category_probe(conn)
    97	    skip_if(
    98	      is.null(probe_category),
    99	      "no populated ndd_entity_view category with >=2 distinct NDD genes (empty/fresh test DB)"
   100	    )
   101	
   102	    resolved <- clustering_resolve_category_universe(probe_category, conn = conn)
   103	
   104	    direct <- DBI::dbGetQuery(
   105	      conn,
   106	      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1 AND category = ?",
   107	      params = list(probe_category)
   108	    )$hgnc_id
   109	
   110	    # Entity-level resolution, no client-side filter: the resolver's
   111	    # dbplyr-generated SQL must select exactly the same gene set as a direct
   112	    # equivalent query against the same live view.
   113	    expect_setequal(resolved$hgnc_ids, direct)
   114	    expect_identical(resolved$selector, probe_category)
   115	    expect_identical(resolved$resolved_gene_count, length(direct))
   116	  })
   117	})
   118	
   119	test_that("clustering_resolve_category_universe rejects an unknown category, naming the allowed set in the message", {
   120	  with_test_db_transaction({
   121	    conn <- getOption(".test_db_con")
   122	    probe_category <- .clustering_category_probe(conn)
   123	    skip_if(
   124	      is.null(probe_category),
   125	      "no populated ndd_entity_view category with >=2 distinct NDD genes (empty/fresh test DB)"
   126	    )
   127	
   128	    err <- tryCatch(
   129	      clustering_resolve_category_universe("Definative", conn = conn),
   130	      error = function(e) e
   131	    )
   132	
   133	    expect_s3_class(err, "error_400")
   134	    # The allowed active-category set is named in the MESSAGE (core/filters.R
   135	    # serializes conditionMessage(err), not a separate `detail` field), and a
   136	    # real currently-active category (the probe result) must appear in it.
   137	    expect_match(conditionMessage(err), "Unknown or inactive")
   138	    expect_match(conditionMessage(err), probe_category, fixed = TRUE)
   139	  })
   140	})
   141	
   142	test_that("clustering_resolve_category_universe(NULL) matches the default all-NDD-genes SELECT", {
   143	  with_test_db_transaction({
   144	    conn <- getOption(".test_db_con")
   145	    probe_category <- .clustering_category_probe(conn)
   146	    skip_if(
   147	      is.null(probe_category),
   148	      "no populated ndd_entity_view category with >=2 distinct NDD genes (empty/fresh test DB)"
   149	    )
   150	
   151	    # `generate_ndd_hgnc_ids()` (analyses-functions.R) reads the package-global
   152	    # `pool` directly -- the resolver's `is.null(selector)` branch does NOT
   153	    # forward `conn` to it (see clustering-gene-universe.R). Bind the global
   154	    # `pool` to this transaction's connection for the duration of the call so
   155	    # the NULL/default branch is exercised for real against the live view,
   156	    # then restore whatever `pool` held before (mirrors the
   157	    # test-unit-panels-endpoint.R / test-unit-endpoint-functions.R idiom).
   158	    # base::get(), not bare get(): a fully-loaded API/worker R session has
   159	    # `config::get` masking `get` (no `envir` argument there), which would
   160	    # error "unused argument (envir = .GlobalEnv)" (Codex review fix; see
   161	    # AGENTS.md "config::get masks base::get").
   162	    old_pool <- if (exists("pool", envir = .GlobalEnv)) base::get("pool", envir = .GlobalEnv) else NULL
   163	    assign("pool", conn, envir = .GlobalEnv)
   164	    withr::defer({
   165	      if (is.null(old_pool)) {
   166	        if (exists("pool", envir = .GlobalEnv)) rm(pool, envir = .GlobalEnv)
   167	      } else {
   168	        assign("pool", old_pool, envir = .GlobalEnv)
   169	      }
   170	    })
   171	
   172	    resolved <- clustering_resolve_category_universe(NULL, conn = conn)
   173	
   174	    # Meaningful, not tautological: compares against a DIRECT query against
   175	    # the real view, not against calling generate_ndd_hgnc_ids() a second
   176	    # time -- proves the NULL/default branch resolves the all-NDD universe
   177	    # correctly, independent of the resolver's own implementation.
   178	    direct <- DBI::dbGetQuery(
   179	      conn,
   180	      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1"
   181	    )$hgnc_id
   182	
   183	    expect_setequal(resolved$hgnc_ids, direct)
   184	    expect_null(resolved$selector)
   185	    expect_identical(resolved$resolved_gene_count, length(direct))
   186	  })
   187	})
   188	
   189	test_that("pool lookup uses base::get() so config::get masking (loaded API/worker env) cannot break it", {
   190	  # Static source guard, not a runtime probe -- reproducing the mask requires
   191	  # `library(config)` attached ahead of base on the search path (only true
   192	  # inside a fully-booted API/worker R session, not host `testthat`; see
   193	  # AGENTS.md "config::get masks base::get"). This file's own NULL-branch
   194	  # `pool` swap (three tests above) must always use the masking-safe form
   195	  # (Codex review fix: previously a bare `get("pool", envir = .GlobalEnv)`).
   196	  # Targets the specific `old_pool <-` assignment line only -- not the whole
   197	  # file body -- so this guard cannot accidentally match its own literals.
   198	  src <- readLines(
   199	    file.path(get_api_dir(), "tests", "testthat", "test-integration-clustering-category-submit.R"),
   200	    warn = FALSE
   201	  )
   202	  pool_swap_line <- src[grepl("old_pool <-.*envir = \\.GlobalEnv", src)]
   203	
   204	  expect_length(pool_swap_line, 1L)
   205	  expect_match(pool_swap_line, "base::get\\(", fixed = FALSE)
   206	})

exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-unit-async-job-service.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-unit-clustering-handler-meta.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# Unit tests for the durable clustering handler's result `meta` (#574 D3).
     2	#
     3	# `.async_job_run_clustering()` (api/functions/async-job-handlers.R) is the
     4	# worker-run (cache-miss) counterpart to the cache-hit path in
     5	# `svc_job_submit_functional_clustering()` (job-functional-submission-service.R,
     6	# #574 D2). D2 already stitches the request's cheap-path `provenance` list
     7	# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
     8	# source_data_version) plus an `effective_fingerprint` (the STRING
     9	# `weight_channel` actually observed on the computed result) into the
    10	# cache-hit result `meta`. D3 makes the durable handler mirror that SAME
    11	# shape for a worker-run job, so a silent exp+db -> combined-score STRING
    12	# fallback is visible in a freshly-computed job's stored result too, not
    13	# just a cache hit's.
    14	#
    15	# DB-free: `gen_string_clust_obj` and its category-enrichment/progress-reporter
    16	# collaborators are stubbed in a child environment. This file never opens a
    17	# DB connection and always runs (no skip guard).
    18	#
    19	# Trap (documented in test-unit-clustering-gene-universe.R and repeated here):
    20	# do NOT stub via `testthat::local_mocked_bindings(..., .env = globalenv())`
    21	# -- under testthat 3.3.2 that aborts with "No packages loaded with
    22	# pkgload" because globalenv() has no package namespace. A child-env
    23	# override (source into a fresh `new.env(parent = globalenv())`, then
    24	# reassign bindings on that env) sidesteps this entirely.
    25	
    26	.clustering_handler_env <- function() {
    27	  e <- new.env(parent = globalenv())
    28	  # async-job-handlers.R's eagerly-built async_job_handler_registry list()
    29	  # references handler functions from these sibling modules by bare symbol
    30	  # (#346 Wave 4 split; see the file's own header comment), so they must be
    31	  # sourced first or the list() construction fails with "object '...' not
    32	  # found" -- mirrors test-unit-async-job-handlers.R.
    33	  source_api_file("functions/async-job-force-apply-payload.R", local = FALSE, envir = e)
    34	  source_api_file("functions/async-job-omim-apply.R", local = FALSE, envir = e)
    35	  source_api_file("functions/async-job-provider-handlers.R", local = FALSE, envir = e)
    36	  source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE, envir = e)
    37	  source_api_file("functions/async-job-network-layout-handlers.R", local = FALSE, envir = e)
    38	  source_api_file("functions/async-job-analysis-snapshot-handlers.R", local = FALSE, envir = e)
    39	  # `.async_job_run_clustering()`'s result-`meta` assembly calls
    40	  # `clustering_result_meta()` (#574 D3 fix wave 1), the shared helper defined
    41	  # in clustering-gene-universe.R -- source it too or the handler errors with
    42	  # "could not find function".
    43	  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
    44	  source_api_file("functions/async-job-handlers.R", local = FALSE, envir = e)
    45	
    46	  # Stub the heavy clustering computation: returns a minimal tibble carrying
    47	  # the SAME `weight_channel` attribute contract `gen_string_clust_obj` sets
    48	  # (analyses-functions.R:351) so the handler's `effective_fingerprint`
    49	  # extraction is exercised for real.
    50	  e$gen_string_clust_obj <- function(genes, algorithm, string_id_table) {
    51	    x <- tibble::tibble(cluster = 1L)
    52	    attr(x, "weight_channel") <- "experimental_database"
    53	    x
    54	  }
    55	
    56	  # `.async_job_functional_categories(clusters, category_links)` is called
    57	  # unconditionally by the handler; stub it out so this test does not also
    58	  # have to fabricate a `term_enrichment` column on the stub clusters tibble.
    59	  e$.async_job_functional_categories <- function(clusters, category_links) {
    60	    tibble::tibble()
    61	  }
    62	
    63	  # Bypasses `create_async_job_progress_reporter()` (a separate, unsourced
    64	  # module in this DB-free test) -- see file header trap note.
    65	  e$.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
    66	    function(...) invisible(NULL)
    67	  }
    68	
    69	  e
    70	}
    71	
    72	test_that(".async_job_run_clustering echoes payload provenance + effective_fingerprint into result meta", {
    73	  e <- .clustering_handler_env()
    74	
    75	  payload <- list(
    76	    genes = c("HGNC:1", "HGNC:5"),
    77	    algorithm = "leiden",
    78	    string_id_table = NULL,
    79	    category_links = NULL,
    80	    provenance = list(
    81	      selector = list(kind = "category", category_filter = "Definitive"),
    82	      resolved_gene_count = 2L,
    83	      gene_list_sha256 = "abc",
    84	      intended_fingerprint = list(string_cache_fingerprint = "fp"),
    85	      source_data_version = "srcv-1"
    86	    )
    87	  )
    88	
    89	  result <- e$.async_job_run_clustering(
    90	    job = list(job_id = "j1"),
    91	    payload = payload,
    92	    state = NULL,
    93	    worker_config = NULL
    94	  )
    95	
    96	  meta <- result$meta
    97	
    98	  expect_identical(meta$algorithm, "leiden")
    99	  expect_identical(meta$gene_count, 2L)
   100	  expect_identical(meta$cluster_count, 1L)
   101	  # Shape parity with the cache-hit path's meta (job-functional-submission-
   102	  # service.R), which always carries cache_hit = TRUE: a worker-run job must
   103	  # carry cache_hit = FALSE so callers can distinguish the two without an
   104	  # absent-field check.
   105	  expect_identical(meta$cache_hit, FALSE)
   106	  expect_identical(meta$selector$kind, "category")
   107	  expect_identical(meta$gene_list_sha256, "abc")
   108	  expect_identical(meta$source_data_version, "srcv-1")
   109	  expect_identical(meta$intended_fingerprint$string_cache_fingerprint, "fp")
   110	  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
   111	})
   112	
   113	test_that(".async_job_run_clustering: gene_count is the DISTINCT gene count, matching the cache-hit path (Codex round-2 review fix)", {
   114	  # Bug: the worker handler reported `gene_count = length(genes)` (raw),
   115	  # while the cache-hit path (job-functional-submission-service.R) reports
   116	  # `resolved_count <- length(unique(genes_list))` (distinct) -- for
   117	  # `["HGNC:1","HGNC:1"]` the cache-hit path reports gene_count=1 but the
   118	  # worker reported gene_count=2 for the identical payload. Both paths must
   119	  # agree.
   120	  e <- .clustering_handler_env()
   121	
   122	  payload <- list(
   123	    genes = c("HGNC:1", "HGNC:1"),
   124	    algorithm = "leiden",
   125	    string_id_table = NULL,
   126	    category_links = NULL
   127	  )
   128	
   129	  result <- e$.async_job_run_clustering(
   130	    job = list(job_id = "j-dup-genes"),
   131	    payload = payload,
   132	    state = NULL,
   133	    worker_config = NULL
   134	  )
   135	
   136	  expect_identical(result$meta$gene_count, 1L)
   137	})
   138	
   139	test_that(".async_job_run_clustering: legacy payload with no provenance still returns a valid meta (backward compat)", {
   140	  e <- .clustering_handler_env()
   141	
   142	  payload <- list(
   143	    genes = c("HGNC:1", "HGNC:5", "HGNC:9"),
   144	    algorithm = "walktrap",
   145	    string_id_table = NULL,
   146	    category_links = NULL
   147	    # No `provenance` field -- mirrors an explicit/no-arg pre-#574 submit.
   148	  )
   149	
   150	  result <- NULL
   151	  expect_no_error({
   152	    result <- e$.async_job_run_clustering(
   153	      job = list(job_id = "j2"),
   154	      payload = payload,
   155	      state = NULL,
   156	      worker_config = NULL
   157	    )
   158	  })
   159	
   160	  meta <- result$meta
   161	
   162	  expect_identical(meta$algorithm, "walktrap")
   163	  expect_identical(meta$gene_count, 3L)
   164	  expect_identical(meta$cluster_count, 1L)
   165	  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
   166	  # No provenance fields leaked in when the payload never carried them.
   167	  expect_null(meta$selector)
   168	  expect_null(meta$gene_list_sha256)
   169	  expect_null(meta$source_data_version)
   170	  expect_null(meta$intended_fingerprint)
   171	})

 succeeded in 0ms:
     1	library(testthat)
     2	library(tibble)
     3	library(jsonlite)
     4	
     5	async_job_service_runtime_path <- function() {
     6	  file.path(get_api_dir(), "functions", "async-job-service.R")
     7	}
     8	
     9	load_async_job_service_runtime <- function() {
    10	  runtime_path <- async_job_service_runtime_path()
    11	  if (!file.exists(runtime_path)) {
    12	    stop("async-job service file is missing: ", runtime_path)
    13	  }
    14	
    15	  runtime_env <- new.env(parent = globalenv())
    16	  sys.source(runtime_path, envir = runtime_env)
    17	  runtime_env
    18	}
    19	
    20	test_that("async_job_service_submit creates a durable job and returns the stored row", {
    21	  runtime <- load_async_job_service_runtime()
    22	  created_job <- NULL
    23	  get_call <- NULL
    24	  scheduled_at <- as.POSIXct("2026-04-23 10:15:00", tz = "UTC")
    25	
    26	  runtime$async_job_repository_create <- function(job, conn = NULL) {
    27	    created_job <<- job
    28	    job$job_id
    29	  }
    30	
    31	  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
    32	    get_call <<- list(job_id = job_id, include_result = include_result)
    33	    tibble::tibble(
    34	      job_id = job_id,
    35	      job_type = created_job$job_type,
    36	      queue_name = created_job$queue_name,
    37	      priority = created_job$priority,
    38	      status = "queued",
    39	      request_hash = created_job$request_hash,
    40	      request_payload_json = created_job$request_payload_json,
    41	      submitted_by = created_job$submitted_by,
    42	      submitted_at = created_job$submitted_at,
    43	      scheduled_at = created_job$scheduled_at,
    44	      attempt_count = 0L,
    45	      max_attempts = created_job$max_attempts
    46	    )
    47	  }
    48	
    49	  result <- runtime$async_job_service_submit(
    50	    job_type = "comparisons_update",
    51	    request_payload = list(genes = c("GENE1", "GENE2"), algorithm = "walktrap"),
    52	    submitted_by = 42L,
    53	    queue_name = "bulk",
    54	    priority = 5L,
    55	    max_attempts = 3L,
    56	    scheduled_at = scheduled_at,
    57	    job_id = "job-submit"
    58	  )
    59	
    60	  expect_false(result$duplicate)
    61	  expect_true(result$created)
    62	  expect_equal(result$job$job_id[[1]], "job-submit")
    63	  expect_equal(created_job$job_type, "comparisons_update")
    64	  expect_equal(created_job$queue_name, "bulk")
    65	  expect_equal(created_job$priority, 5L)
    66	  expect_equal(created_job$submitted_by, 42L)
    67	  expect_equal(created_job$max_attempts, 3L)
    68	  expect_equal(created_job$scheduled_at, scheduled_at)
    69	  expect_equal(
    70	    jsonlite::fromJSON(created_job$request_payload_json, simplifyVector = TRUE),
    71	    list(genes = c("GENE1", "GENE2"), algorithm = "walktrap")
    72	  )
    73	  expect_equal(
    74	    created_job$request_hash,
    75	    runtime$async_job_service_request_hash(
    76	      "comparisons_update",
    77	      created_job$request_payload_json
    78	    )
    79	  )
    80	  expect_equal(get_call, list(job_id = "job-submit", include_result = FALSE))
    81	})
    82	
    83	test_that("async_job_service_submit returns the duplicate job when the repository rejects a concurrent create", {
    84	  runtime <- load_async_job_service_runtime()
    85	  duplicate_row <- tibble::tibble(job_id = "job-duplicate", status = "queued")
    86	
    87	  runtime$async_job_repository_create <- function(job, conn = NULL) {
    88	    rlang::abort(
    89	      "duplicate",
    90	      class = "async_job_duplicate_error",
    91	      job_id = "job-duplicate",
    92	      duplicate_job = duplicate_row
    93	    )
    94	  }
    95	
    96	  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
    97	    stop("status lookup should not be needed when duplicate row is attached")
    98	  }
    99	
   100	  result <- runtime$async_job_service_submit(
   101	    job_type = "hgnc_update",
   102	    request_payload = list(refresh = TRUE),
   103	    job_id = "job-new"
   104	  )
   105	
   106	  expect_true(result$duplicate)
   107	  expect_false(result$created)
   108	  expect_equal(result$job, duplicate_row)
   109	})
   110	
   111	test_that("async_job_service_find_duplicate hashes the request payload before querying the repository", {
   112	  runtime <- load_async_job_service_runtime()
   113	  captured <- NULL
   114	
   115	  runtime$async_job_repository_find_active_duplicate <- function(job_type, request_hash, conn = NULL) {
   116	    captured <<- list(job_type = job_type, request_hash = request_hash)
   117	    tibble::tibble(job_id = "job-existing", status = "running")
   118	  }
   119	
   120	  result <- runtime$async_job_service_find_duplicate(
   121	    job_type = "clustering",
   122	    request_payload = list(genes = c("A", "B"), algorithm = "leiden")
   123	  )
   124	
   125	  expect_equal(result$job_id[[1]], "job-existing")
   126	  expect_equal(captured$job_type, "clustering")
   127	  expect_equal(
   128	    captured$request_hash,
   129	    runtime$async_job_service_request_hash(
   130	      "clustering",
   131	      runtime$async_job_service_payload_json(
   132	        list(genes = c("A", "B"), algorithm = "leiden")
   133	      )
   134	    )
   135	  )
   136	})
   137	
   138	test_that("find_active_by_type is job-type scoped and payload-hash independent (#535 S2b HIGH-4)", {
   139	  runtime <- load_async_job_service_runtime()
   140	  captured <- NULL
   141	
   142	  # Job-type single-flight must not hash a payload: destructive maintenance jobs
   143	  # dedupe on job_type alone, so a payload-schema change (dropping db_config)
   144	  # cannot open a deploy-window where two concurrent full-table-replace jobs run.
   145	  expect_true(is.function(runtime$async_job_service_find_active_by_type))
   146	  expect_equal(names(formals(runtime$async_job_service_find_active_by_type)),
   147	               c("job_type", "conn"))
   148	
   149	  runtime$async_job_repository_find_active_by_type <- function(job_type, conn = NULL) {
   150	    captured <<- list(job_type = job_type)
   151	    tibble::tibble(job_id = "job-active", status = "running")
   152	  }
   153	
   154	  dup <- runtime$async_job_service_duplicate_by_type("hgnc_update")
   155	  expect_true(dup$duplicate)
   156	  expect_equal(dup$existing_job_id, "job-active")
   157	  expect_equal(captured$job_type, "hgnc_update")
   158	})
   159	
   160	test_that("duplicate_by_type reports no duplicate when no active job of that type exists", {
   161	  runtime <- load_async_job_service_runtime()
   162	  runtime$async_job_repository_find_active_by_type <- function(job_type, conn = NULL) {
   163	    tibble::tibble()
   164	  }
   165	  dup <- runtime$async_job_service_duplicate_by_type("comparisons_update")
   166	  expect_false(dup$duplicate)
   167	  expect_null(dup$existing_job_id)
   168	})
   169	
   170	test_that("async_job_service_status and history delegate to the durable repository helpers", {
   171	  runtime <- load_async_job_service_runtime()
   172	  status_call <- NULL
   173	  history_call <- NULL
   174	
   175	  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
   176	    status_call <<- list(job_id = job_id, include_result = include_result)
   177	    tibble::tibble(job_id = job_id, status = "completed", result_json = "{\"ok\":true}")
   178	  }
   179	
   180	  runtime$async_job_repository_history <- function(limit = 20L, conn = NULL) {
   181	    history_call <<- list(limit = limit)
   182	    tibble::tibble(job_id = c("job-2", "job-1"), status = c("completed", "failed"))
   183	  }
   184	
   185	  status <- runtime$async_job_service_status("job-status", include_result = TRUE)
   186	  history <- runtime$async_job_service_history(limit = 0)
   187	
   188	  expect_equal(status$job_id[[1]], "job-status")
   189	  expect_equal(status_call, list(job_id = "job-status", include_result = TRUE))
   190	  expect_equal(history$job_id, c("job-2", "job-1"))
   191	  expect_equal(history_call$limit, 1L)
   192	})
   193	
   194	test_that("async_job_service_cancel returns the refreshed durable job row", {
   195	  runtime <- load_async_job_service_runtime()
   196	  cancel_call <- NULL
   197	
   198	  runtime$async_job_repository_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
   199	    cancel_call <<- list(job_id = job_id, cancelled_by = cancelled_by)
   200	    1L
   201	  }
   202	
   203	  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
   204	    tibble::tibble(job_id = job_id, status = "cancel_requested", cancelled_by = 9L)
   205	  }
   206	
   207	  cancelled <- runtime$async_job_service_cancel("job-cancel", cancelled_by = 9L)
   208	
   209	  expect_equal(cancel_call, list(job_id = "job-cancel", cancelled_by = 9L))
   210	  expect_equal(cancelled$status[[1]], "cancel_requested")
   211	  expect_equal(cancelled$cancelled_by[[1]], 9L)
   212	})
   213	
   214	# --- #486: queue routing + priority by job type ----------------------------
   215	
   216	test_that("async_job_queue_for_type routes heavy maintenance jobs to the maintenance lane", {
   217	  runtime <- load_async_job_service_runtime()
   218	
   219	  expect_equal(runtime$async_job_queue_for_type("publication_date_backfill"), "maintenance")
   220	  expect_equal(runtime$async_job_queue_for_type("omim_update"), "maintenance")
   221	  expect_equal(runtime$async_job_queue_for_type("disease_ontology_mapping_refresh"), "maintenance")
   222	  expect_equal(runtime$async_job_queue_for_type("nddscore_import"), "maintenance")
   223	
   224	  expect_equal(runtime$async_job_queue_for_type("llm_generation"), "default")
   225	  expect_equal(runtime$async_job_queue_for_type("clustering"), "default")
   226	  expect_equal(runtime$async_job_queue_for_type("phenotype_clustering"), "default")
   227	  # Unknown / unclassified job types default to the interactive lane.
   228	  expect_equal(runtime$async_job_queue_for_type("some_new_job"), "default")
   229	})
   230	
   231	test_that("interactive jobs outrank maintenance jobs in claim priority", {
   232	  runtime <- load_async_job_service_runtime()
   233	
   234	  interactive <- runtime$async_job_priority_for_type("llm_generation")
   235	  maintenance <- runtime$async_job_priority_for_type("publication_date_backfill")
   236	  other <- runtime$async_job_priority_for_type("some_new_job")
   237	
   238	  # Lower number = claimed first (claim query orders priority ASC).
   239	  expect_lt(interactive, maintenance)
   240	  expect_lt(maintenance, other)
   241	  expect_equal(runtime$async_job_priority_for_type("clustering"), interactive)
   242	  expect_equal(runtime$async_job_priority_for_type("omim_update"), maintenance)
   243	})
   244	
   245	test_that("async_job_service_submit defaults queue + priority from the job type", {
   246	  runtime <- load_async_job_service_runtime()
   247	  created_job <- NULL
   248	
   249	  runtime$async_job_repository_create <- function(job, conn = NULL) {
   250	    created_job <<- job
   251	    job$job_id
   252	  }
   253	  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
   254	    tibble::tibble(job_id = job_id, queue_name = created_job$queue_name,
   255	                   priority = created_job$priority)
   256	  }
   257	
   258	  # publication_date_backfill (maintenance) with no explicit queue/priority.
   259	  runtime$async_job_service_submit(
   260	    job_type = "publication_date_backfill",
   261	    request_payload = list(dry_run = FALSE),
   262	    job_id = "job-maint"
   263	  )
   264	  expect_equal(created_job$queue_name, "maintenance")
   265	  expect_equal(created_job$priority, 50L)
   266	
   267	  # llm_generation (interactive) with no explicit queue/priority.
   268	  runtime$async_job_service_submit(
   269	    job_type = "llm_generation",
   270	    request_payload = list(cluster = 1L),
   271	    job_id = "job-llm"
   272	  )
   273	  expect_equal(created_job$queue_name, "default")
   274	  expect_equal(created_job$priority, 10L)
   275	})
   276	
   277	test_that("async_job_service_submit hashes hash_payload when supplied, not the full payload (#574 Codex round 3)", {
   278	  runtime <- load_async_job_service_runtime()
   279	  created_job <- NULL
   280	
   281	  runtime$async_job_repository_create <- function(job, conn = NULL) {
   282	    created_job <<- job
   283	    job$job_id
   284	  }
   285	  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
   286	    tibble::tibble(job_id = job_id, request_hash = created_job$request_hash,
   287	                   request_payload_json = created_job$request_payload_json)
   288	  }
   289	
   290	  full_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden",
   291	                       provenance = list(source_data_version = "2026-07-18T00:00:00Z"))
   292	  subset_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden")
   293	
   294	  runtime$async_job_service_submit(
   295	    job_type = "clustering",
   296	    request_payload = full_payload,
   297	    hash_payload = subset_payload,
   298	    job_id = "job-hash-override"
   299	  )
   300	
   301	  # request_hash is computed over hash_payload (the subset), not the full payload.
   302	  expect_equal(
   303	    created_job$request_hash,
   304	    runtime$async_job_service_request_hash(
   305	      "clustering",
   306	      runtime$async_job_service_payload_json(subset_payload)
   307	    )
   308	  )
   309	  expect_false(identical(
   310	    created_job$request_hash,
   311	    runtime$async_job_service_request_hash(
   312	      "clustering",
   313	      runtime$async_job_service_payload_json(full_payload)
   314	    )
   315	  ))
   316	
   317	  # request_payload_json (the DURABLY STORED payload) is always the FULL payload,
   318	  # provenance included -- only the dedup hash excludes it.
   319	  expect_equal(
   320	    jsonlite::fromJSON(created_job$request_payload_json, simplifyVector = TRUE)$provenance$source_data_version,
   321	    "2026-07-18T00:00:00Z"
   322	  )
   323	
   324	  # Default behavior (no hash_payload) is unchanged: hash the full payload.
   325	  runtime$async_job_service_submit(
   326	    job_type = "clustering",
   327	    request_payload = full_payload,
   328	    job_id = "job-hash-default"
   329	  )
   330	  expect_equal(
   331	    created_job$request_hash,
   332	    runtime$async_job_service_request_hash(
   333	      "clustering",
   334	      runtime$async_job_service_payload_json(full_payload)
   335	    )
   336	  )
   337	})
   338	
   339	test_that("async_job_service_submit still honors explicit queue + priority overrides", {
   340	  runtime <- load_async_job_service_runtime()
   341	  created_job <- NULL
   342	
   343	  runtime$async_job_repository_create <- function(job, conn = NULL) {
   344	    created_job <<- job
   345	    job$job_id
   346	  }
   347	  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
   348	    tibble::tibble(job_id = job_id, queue_name = created_job$queue_name,
   349	                   priority = created_job$priority)
   350	  }
   351	
   352	  runtime$async_job_service_submit(
   353	    job_type = "publication_date_backfill",
   354	    request_payload = list(dry_run = FALSE),
   355	    queue_name = "analysis",
   356	    priority = 5L,
   357	    job_id = "job-explicit"
   358	  )
   359	  expect_equal(created_job$queue_name, "analysis")
   360	  expect_equal(created_job$priority, 5L)
   361	})

exec
/bin/bash -lc 'git diff --unified=20 origin/master...HEAD -- api/functions/async-job-service.R api/tests/testthat/test-unit-async-job-service.R api/tests/testthat/test-unit-async-job-worker.R api/tests/testthat/test-unit-async-job-handlers.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
diff --git a/api/functions/async-job-service.R b/api/functions/async-job-service.R
index 37b6ec99..f3d655dc 100644
--- a/api/functions/async-job-service.R
+++ b/api/functions/async-job-service.R
@@ -197,67 +197,76 @@ async_job_service_request_hash <- function(job_type, request_payload_json) {
   }
 
   async_job_repository_get(job_id, conn = conn)
 }
 
 #' Submit a durable async job and return its stored row
 #'
 #' @param job_type Character durable job type.
 #' @param request_payload Named list or JSON payload string.
 #' @param submitted_by Optional user id.
 #' @param queue_name Character queue name. `NULL` (default) routes by job type via
 #'   `async_job_queue_for_type()` (maintenance lane for heavy jobs, else default);
 #'   an explicit value is honored as-is.
 #' @param priority Integer queue priority. `NULL` (default) resolves by job type
 #'   via `async_job_priority_for_type()` (interactive < maintenance < default); an
 #'   explicit value is honored as-is.
 #' @param max_attempts Integer maximum attempts.
 #' @param scheduled_at Optional schedule time.
 #' @param job_id Optional explicit job id for tests.
 #' @param conn Optional DB connection or pool.
+#' @param hash_payload Optional named list or JSON payload string. When
+#'   supplied, the dedup `request_hash` is computed over THIS payload instead
+#'   of `request_payload`, while `request_payload_json` (the durably stored
+#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
+#'   `request_payload` exactly as before, so existing callers are unaffected.
+#'   Used by clustering submits (#574) to exclude time-varying `provenance`
+#'   metadata from the dedup identity while still persisting it.
 #'
 #' @return List containing the stored job row and duplicate/create flags.
 #' @export
 async_job_service_submit <- function(
   job_type,
   request_payload,
   submitted_by = NULL,
   queue_name = NULL,
   priority = NULL,
   max_attempts = 1L,
   scheduled_at = Sys.time(),
   job_id = uuid::UUIDgenerate(),
-  conn = NULL
+  conn = NULL,
+  hash_payload = NULL
 ) {
   job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   # Default the lane + priority from the job type so heavy maintenance jobs never
   # head-of-line block interactive jobs (#486). Explicit overrides are honored.
   if (is.null(queue_name)) {
     queue_name <- async_job_queue_for_type(job_type)
   }
   if (is.null(priority)) {
     priority <- async_job_priority_for_type(job_type)
   }
   queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   payload_json <- async_job_service_payload_json(request_payload)
-  request_hash <- async_job_service_request_hash(job_type, payload_json)
+  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
+  request_hash <- async_job_service_request_hash(job_type, hash_payload_json)
   submitted_at <- Sys.time()
 
   stored_job <- tryCatch(
     {
       async_job_repository_create(
         list(
           job_id = job_id,
           job_type = job_type,
           queue_name = queue_name,
           priority = as.integer(priority),
           request_hash = request_hash,
           request_payload_json = payload_json,
           submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
           submitted_at = submitted_at,
           scheduled_at = scheduled_at,
           max_attempts = as.integer(max_attempts)
         ),
         conn = conn
       )
 
@@ -275,69 +284,76 @@ async_job_service_submit <- function(
     duplicate = is_duplicate,
     created = !is_duplicate
   )
 }
 
 #' Persist an already-completed durable async job row
 #'
 #' Used for cache-hit fast paths that should still return a normal durable
 #' job id without enqueueing worker execution.
 #'
 #' @param job_type Character durable job type.
 #' @param request_payload Named list or JSON payload string.
 #' @param result Completed handler result payload.
 #' @param submitted_by Optional user id.
 #' @param queue_name Character queue name.
 #' @param priority Integer queue priority.
 #' @param job_id Optional explicit job id.
 #' @param submitted_at Optional submission timestamp.
 #' @param completed_at Optional completion timestamp.
 #' @param conn Optional DB connection or pool.
+#' @param hash_payload Optional named list or JSON payload string. When
+#'   supplied, the dedup `request_hash` is computed over THIS payload instead
+#'   of `request_payload`, while `request_payload_json` (the durably stored
+#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
+#'   `request_payload` exactly as before, so existing callers are unaffected.
 #'
 #' @return Tibble with the stored completed job row.
 #' @export
 async_job_service_store_completed <- function(
   job_type,
   request_payload,
   result,
   submitted_by = NULL,
   queue_name = "default",
   priority = 100L,
   job_id = uuid::UUIDgenerate(),
   submitted_at = Sys.time(),
   completed_at = submitted_at,
-  conn = NULL
+  conn = NULL,
+  hash_payload = NULL
 ) {
   job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   payload_json <- async_job_service_payload_json(request_payload)
+  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
   result_json <- async_job_service_payload_json(result)
 
   async_job_repository_create(
     list(
       job_id = job_id,
       job_type = job_type,
       queue_name = queue_name,
       priority = as.integer(priority),
       status = "completed",
-      request_hash = async_job_service_request_hash(job_type, payload_json),
+      request_hash = async_job_service_request_hash(job_type, hash_payload_json),
       request_payload_json = payload_json,
       submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
       submitted_at = submitted_at,
       scheduled_at = submitted_at,
       started_at = submitted_at,
       completed_at = completed_at,
       progress_pct = 100,
       result_json = result_json
     ),
     conn = conn
   )
 
   async_job_repository_get(job_id, include_result = TRUE, conn = conn)
 }
 
 #' Find an active duplicate for a durable async job request
 #'
 #' @param job_type Character durable job type.
 #' @param request_payload Named list or JSON payload string.
 #' @param conn Optional DB connection or pool.
diff --git a/api/tests/testthat/test-unit-async-job-handlers.R b/api/tests/testthat/test-unit-async-job-handlers.R
index 30f63cef..dd50b54d 100644
--- a/api/tests/testthat/test-unit-async-job-handlers.R
+++ b/api/tests/testthat/test-unit-async-job-handlers.R
@@ -1,24 +1,28 @@
 library(testthat)
 
 source_api_file("functions/async-job-force-apply-payload.R", local = FALSE)
 source_api_file("functions/async-job-omim-apply.R", local = FALSE)
+# .async_job_run_clustering assembles its result meta via clustering_result_meta()
+# (clustering-gene-universe.R, #574); source it so the handler resolves it here as
+# it does in the worker (bootstrap_load_modules sources it before the handlers).
+source_api_file("functions/clustering-gene-universe.R", local = FALSE)
 # The eagerly-built async_job_handler_registry list() references provider and
 # maintenance handler functions by bare symbol (#346 Wave 4 split), so both
 # extracted modules must be sourced BEFORE async-job-handlers.R or the list()
 # construction fails with "object '...' not found".
 source_api_file("functions/async-job-provider-handlers.R", local = FALSE)
 source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE)
 source_api_file("functions/async-job-handlers.R", local = FALSE)
 
 handler_body <- function(fn) {
   paste(deparse(body(fn)), collapse = "\n")
 }
 
 test_that(".async_job_omim_db_write uses the shared ontology refresh helper", {
   body_txt <- handler_body(.async_job_omim_db_write)
 
   expect_match(body_txt, "refresh_disease_ontology_set")
   expect_false(grepl("\\bTRUNCATE\\b", body_txt, ignore.case = TRUE))
   expect_false(grepl("DBI::dbBegin|DBI::dbCommit|DBI::dbRollback", body_txt))
 })
 
diff --git a/api/tests/testthat/test-unit-async-job-service.R b/api/tests/testthat/test-unit-async-job-service.R
index 77c3b488..10dedfe6 100644
--- a/api/tests/testthat/test-unit-async-job-service.R
+++ b/api/tests/testthat/test-unit-async-job-service.R
@@ -257,40 +257,102 @@ test_that("async_job_service_submit defaults queue + priority from the job type"
 
   # publication_date_backfill (maintenance) with no explicit queue/priority.
   runtime$async_job_service_submit(
     job_type = "publication_date_backfill",
     request_payload = list(dry_run = FALSE),
     job_id = "job-maint"
   )
   expect_equal(created_job$queue_name, "maintenance")
   expect_equal(created_job$priority, 50L)
 
   # llm_generation (interactive) with no explicit queue/priority.
   runtime$async_job_service_submit(
     job_type = "llm_generation",
     request_payload = list(cluster = 1L),
     job_id = "job-llm"
   )
   expect_equal(created_job$queue_name, "default")
   expect_equal(created_job$priority, 10L)
 })
 
+test_that("async_job_service_submit hashes hash_payload when supplied, not the full payload (#574 Codex round 3)", {
+  runtime <- load_async_job_service_runtime()
+  created_job <- NULL
+
+  runtime$async_job_repository_create <- function(job, conn = NULL) {
+    created_job <<- job
+    job$job_id
+  }
+  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
+    tibble::tibble(job_id = job_id, request_hash = created_job$request_hash,
+                   request_payload_json = created_job$request_payload_json)
+  }
+
+  full_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden",
+                       provenance = list(source_data_version = "2026-07-18T00:00:00Z"))
+  subset_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden")
+
+  runtime$async_job_service_submit(
+    job_type = "clustering",
+    request_payload = full_payload,
+    hash_payload = subset_payload,
+    job_id = "job-hash-override"
+  )
+
+  # request_hash is computed over hash_payload (the subset), not the full payload.
+  expect_equal(
+    created_job$request_hash,
+    runtime$async_job_service_request_hash(
+      "clustering",
+      runtime$async_job_service_payload_json(subset_payload)
+    )
+  )
+  expect_false(identical(
+    created_job$request_hash,
+    runtime$async_job_service_request_hash(
+      "clustering",
+      runtime$async_job_service_payload_json(full_payload)
+    )
+  ))
+
+  # request_payload_json (the DURABLY STORED payload) is always the FULL payload,
+  # provenance included -- only the dedup hash excludes it.
+  expect_equal(
+    jsonlite::fromJSON(created_job$request_payload_json, simplifyVector = TRUE)$provenance$source_data_version,
+    "2026-07-18T00:00:00Z"
+  )
+
+  # Default behavior (no hash_payload) is unchanged: hash the full payload.
+  runtime$async_job_service_submit(
+    job_type = "clustering",
+    request_payload = full_payload,
+    job_id = "job-hash-default"
+  )
+  expect_equal(
+    created_job$request_hash,
+    runtime$async_job_service_request_hash(
+      "clustering",
+      runtime$async_job_service_payload_json(full_payload)
+    )
+  )
+})
+
 test_that("async_job_service_submit still honors explicit queue + priority overrides", {
   runtime <- load_async_job_service_runtime()
   created_job <- NULL
 
   runtime$async_job_repository_create <- function(job, conn = NULL) {
     created_job <<- job
     job$job_id
   }
   runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
     tibble::tibble(job_id = job_id, queue_name = created_job$queue_name,
                    priority = created_job$priority)
   }
 
   runtime$async_job_service_submit(
     job_type = "publication_date_backfill",
     request_payload = list(dry_run = FALSE),
     queue_name = "analysis",
     priority = 5L,
     job_id = "job-explicit"
   )
diff --git a/api/tests/testthat/test-unit-async-job-worker.R b/api/tests/testthat/test-unit-async-job-worker.R
index 792903e1..30a2565d 100644
--- a/api/tests/testthat/test-unit-async-job-worker.R
+++ b/api/tests/testthat/test-unit-async-job-worker.R
@@ -1,38 +1,39 @@
 library(testthat)
 library(withr)
 library(jsonlite)
 library(tibble)
 
 async_job_worker_runtime_paths <- function() {
   api_dir <- get_api_dir()
   c(
     file.path(api_dir, "functions", "async-job-progress.R"),
     # .async_job_phenotype_matrix() calls phenotype_mca_prep_matrix() (#508 MCA hygiene);
     # load it here so the durable phenotype-clustering handler test resolves it the way
     # load_modules.R does in production (prep is sourced before async-job-handlers.R).
     file.path(api_dir, "functions", "analysis-phenotype-mca-prep.R"),
     # #346 Wave 4: async_job_handler_registry binds provider/maintenance handler
     # functions by bare symbol inside an eagerly-evaluated list(), so both
     # extracted modules must be sourced before async-job-handlers.R here too.
     file.path(api_dir, "functions", "async-job-provider-handlers.R"),
     file.path(api_dir, "functions", "async-job-maintenance-handlers.R"),
+    file.path(api_dir, "functions", "clustering-gene-universe.R"),
     file.path(api_dir, "functions", "async-job-handlers.R"),
     file.path(api_dir, "functions", "async-job-worker.R"),
     file.path(api_dir, "functions", "job-progress.R")
   )
 }
 
 load_async_job_worker_runtime <- function() {
   runtime_env <- new.env(parent = globalenv())
   runtime_paths <- async_job_worker_runtime_paths()
 
   missing <- runtime_paths[!file.exists(runtime_paths)]
   if (length(missing) > 0) {
     stop(
       "async-job worker runtime files are missing: ",
       paste(basename(missing), collapse = ", ")
     )
   }
 
   for (path in runtime_paths) {
     sys.source(path, envir = runtime_env)

exec
/bin/bash -lc 'git diff --unified=30 origin/master...HEAD -- api/services/job-functional-submission-service.R api/functions/clustering-gene-universe.R api/functions/async-job-handlers.R api/endpoints/jobs_endpoints.R api/bootstrap/load_modules.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
diff --git a/api/bootstrap/load_modules.R b/api/bootstrap/load_modules.R
index 512a3065..09f44069 100644
--- a/api/bootstrap/load_modules.R
+++ b/api/bootstrap/load_modules.R
@@ -107,60 +107,66 @@ bootstrap_load_modules <- function() {
     "functions/mcp-analysis-cache-repository.R",
     "functions/mcp-analysis-repository.R",
     "functions/user-repository.R",
     "functions/user-endpoint-helpers.R",
     "functions/hash-repository.R",
     "functions/metadata-vocabulary-repository.R",
     "functions/category-normalization.R",
     "functions/phenotype-endpoint-functions.R",
     "functions/panels-endpoint-functions.R",
     "functions/endpoint-functions.R",
     "functions/comparisons-list.R",
     # Comparisons refresh write-path (durable `comparisons_update` job). These
     # were historically only loaded into the mirai daemon pool via
     # setup_workers.R, but create_job() now submits comparisons_update as a
     # durable System B job, so the async worker (which loads via this list) must
     # define comparisons_update_async() and its helpers too. Order: sources +
     # parsers + omim before comparisons-functions.R (which uses them).
     "functions/omim-functions.R",
     "functions/comparisons-sources.R",
     "functions/comparisons-parsers.R",
     "functions/comparisons-omim.R",
     "functions/comparisons-functions.R",
     "functions/publication-endpoint-helpers.R",
     "functions/pubmed-xml-parser.R",
     "functions/publication-functions.R",
     "functions/publication-date-backfill.R",
     "functions/genereviews-functions.R",
     "functions/analysis-string-channels.R",
     "functions/analysis-cache-fingerprint.R",
     "functions/analyses-functions.R",
+    # Category-selected clustering gene-universe resolver (#574). Depends on
+    # generate_ndd_hgnc_ids() (analyses-functions.R, above) and
+    # stop_for_bad_request() (core/errors.R, sourced after function_files by
+    # this same bootstrap_load_modules() call) -- registered before the
+    # submission service that will consume it.
+    "functions/clustering-gene-universe.R",
     "functions/analysis-phenotype-mca-prep.R",
     "functions/analysis-phenotype-functions.R",
     "functions/analysis-null-models.R",
     "functions/analysis-cluster-validation.R",
     "functions/analysis-network-layout-functions.R",
     "functions/analysis-network-functions.R",
     "functions/account-helpers.R",
     "functions/data-helpers.R",
     "functions/entity-helpers.R",
     "functions/response-helpers.R",
     "functions/response-fields-helpers.R",
     "functions/email-templates.R",
     "functions/pagination-helpers.R",
     "functions/external-proxy-functions.R",
     "functions/external-proxy-gnomad.R",
     "functions/external-proxy-gnomad-batch.R",
     "functions/external-proxy-uniprot.R",
     "functions/external-proxy-ensembl.R",
     "functions/external-proxy-alphafold.R",
     "functions/external-proxy-mgi.R",
     "functions/external-proxy-rgd.R",
     "functions/genereviews-lookup.R",
     "functions/file-functions.R",
     "functions/hpo-functions.R",
     "functions/hgnc-functions.R",
     "functions/hgnc-enrichment-gnomad.R",
     "functions/llm-summary-config.R",
     "functions/llm-cache-repository.R",
     "functions/llm-cache-admin-repository.R",
     "functions/llm-validation.R",
diff --git a/api/endpoints/jobs_endpoints.R b/api/endpoints/jobs_endpoints.R
index 4ffad4c5..b4ef4f08 100644
--- a/api/endpoints/jobs_endpoints.R
+++ b/api/endpoints/jobs_endpoints.R
@@ -1,61 +1,94 @@
 # api/endpoints/jobs_endpoints.R
 #
 # Async job submission and status polling endpoints.
 # Submits durable worker jobs and returns HTTP 202 Accepted for long-running operations.
 #
 # Endpoints:
 #   POST /api/jobs/clustering/submit - Submit functional clustering job
 #   POST /api/jobs/phenotype_clustering/submit - Submit phenotype clustering job
 #   GET /api/jobs/<job_id>/status - Poll job status and retrieve results
 #
 # Dependencies:
 #   - pool (global database connection pool)
 #   - create_job, get_job_status, check_duplicate_job (from job-manager.R)
 #   - durable handlers registered in functions/async-job-handlers.R
 #
 # Handler bodies were extracted to services/job-*-service.R (issue #346, Wave
 # 3, Task 5) to keep this file a thin route table. Each shell below keeps its
 # original decorators, formals, and role gate, and delegates the rest to the
 # matching svc_ function.
 
 ## -------------------------------------------------------------------##
 ## Job Submission Endpoints
 ## -------------------------------------------------------------------##
 
 #* Submit Functional Clustering Job
 #*
-#* Submits an async job to compute functional clustering via STRING-db.
+#* Submits an async job to compute functional clustering via STRING-db. The
+#* clustering gene universe (#574) is resolved from one of three mutually
+#* exclusive JSON body selectors:
+#*   - `genes`: an explicit array of HGNC ids to cluster.
+#*   - `category_filter`: an array of curated SysNDD confidence categories
+#*     (e.g. `["Definitive"]`); resolved entity-level (>=1 NDD entity in a
+#*     selected category, `ndd_phenotype = 1`) against the live
+#*     `ndd_entity_view`, validated against the live active
+#*     `ndd_entity_status_categories_list`. A category run rejects with 400
+#*     when `category_filter` is empty, contains an unknown/inactive value
+#*     (the allowed active set is named in the error), or resolves fewer
+#*     than 2 genes.
+#*   - neither: the existing default all-NDD-genes universe.
+#* Supplying both `genes` and a non-empty `category_filter` is a 400.
+#*
+#* Every submit records selector/fingerprint provenance -- `selector`
+#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
+#* category runs), `resolved_gene_count`, `gene_list_sha256`,
+#* `intended_fingerprint`, and `source_data_version` -- in the durable job
+#* payload; the job result `meta` additionally carries `effective_fingerprint`
+#* (the STRING `weight_channel` actually observed on the computed result),
+#* recorded on both a cache-hit (immediate) response and a worker-run
+#* (cache-miss) job.
+#*
+#* Results from this endpoint (including category-filtered runs) are never
+#* `public_ready` -- they are ephemeral job results, distinct from the public
+#* `analysis_snapshot_*` layer.
+#*
 #* Returns immediately with job ID for status polling.
 #*
 #* @tag jobs
 #* @serializer json list(na="string")
+#* @param genes Optional JSON array of explicit HGNC ids. Mutually exclusive
+#*   with `category_filter`.
+#* @param category_filter Optional JSON array of curated SysNDD confidence
+#*   categories (e.g. `["Definitive"]`). Mutually exclusive with `genes`.
+#* @param algorithm Optional clustering algorithm string, `"leiden"`
+#*   (default) or `"walktrap"`.
 #* @post /clustering/submit
 function(req, res) {
   svc_job_submit_functional_clustering(req, res)
 }
 
 ## -------------------------------------------------------------------##
 ## Phenotype Clustering Submission
 ## -------------------------------------------------------------------##
 
 #* Submit Phenotype Clustering Job
 #*
 #* Submits an async job to compute phenotype clustering via MCA.
 #* Returns immediately with job ID for status polling.
 #*
 #* @tag jobs
 #* @serializer json list(na="string")
 #* @post /phenotype_clustering/submit
 function(req, res) {
   svc_job_submit_phenotype_clustering(req, res)
 }
 
 ## -------------------------------------------------------------------##
 ## Ontology Update Submission
 ## -------------------------------------------------------------------##
 
 #* Submit Ontology Update Job
 #*
 #* Submits an async job to update disease ontology data from MONDO and OMIM sources.
 #* Requires Administrator role.
 #* Returns immediately with job ID for status polling.
diff --git a/api/functions/async-job-handlers.R b/api/functions/async-job-handlers.R
index d3691475..184b62c0 100644
--- a/api/functions/async-job-handlers.R
+++ b/api/functions/async-job-handlers.R
@@ -1,51 +1,55 @@
 # api/functions/async-job-handlers.R
 #
 # Durable async job handler shell (#346 Wave 4 split): common
 # payload/progress/clustering helpers, the legacy-executor passthrough
 # factory, the `async_job_handler_registry` list, and the
 # `async_job_get_handler()` lookup.
 #
 # Family-specific handler definitions live in sibling files sourced BEFORE
 # this one at every worker entrypoint, because the registry list below
 # references handler functions by bare symbol and R evaluates a list()
 # literal's elements eagerly at construction time:
 #   - functions/async-job-network-layout-handlers.R (network_layout_prewarm)
 #   - functions/async-job-analysis-snapshot-handlers.R (analysis_snapshot_refresh)
 #   - functions/async-job-omim-apply.R (OMIM DB-write / additive-terms helpers)
 #   - functions/async-job-force-apply-payload.R (force-apply payload-shape helpers)
 #   - functions/async-job-provider-handlers.R (HGNC, PubTator, NDDScore,
 #     disease-ontology mapping, OMIM update, force-apply-ontology)
 #   - functions/async-job-maintenance-handlers.R (backup create/restore,
 #     publication refresh/backfill)
 # Restart the worker container after changing any of these (worker-executed
 # code is sourced once at startup).
+# NOTE: .async_job_run_clustering assembles its result meta via
+# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
+# worker/API entrypoint sources that module via bootstrap_load_modules() before
+# this file; a direct-source test env must source it too (as the async-job tests do).
 
 .async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
   invisible(result)
 }
 .async_job_or <- function(value, fallback) {
   if (is.null(value) || length(value) == 0) {
     return(fallback)
   }
 
   value
 }
 .async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
   if (!exists("create_async_job_progress_reporter", mode = "function")) {
     stop("create_async_job_progress_reporter() is required for durable async job handlers", call. = FALSE)
   }
 
   create_async_job_progress_reporter(job_id, throttle_seconds = throttle_seconds)
 }
 .async_job_payload_field <- function(payload, field, required = TRUE, default = NULL) {
   value <- payload[[field]]
 
   if (is.null(value)) {
     if (isTRUE(required)) {
       stop(sprintf("Async job payload is missing required field '%s'", field), call. = FALSE)
     }
 
     return(default)
   }
 
   value
@@ -69,80 +73,107 @@
   payload
 }
 
 .async_job_functional_categories <- function(clusters, category_links) {
   categories <- clusters |>
     dplyr::select(term_enrichment) |>
     tidyr::unnest(cols = c(term_enrichment)) |>
     dplyr::select(category) |>
     unique() |>
     dplyr::arrange(category) |>
     dplyr::mutate(
       text = dplyr::case_when(
         nchar(category) <= 5 ~ category,
         nchar(category) > 5 ~ stringr::str_to_sentence(category)
       )
     ) |>
     dplyr::select(value = category, text)
 
   if (!is.null(category_links)) {
     categories <- dplyr::left_join(categories, category_links, by = c("value"))
   }
 
   categories
 }
 
 .async_job_run_clustering <- function(job, payload, state, worker_config) {
   genes <- .async_job_payload_field(payload, "genes")
   algorithm <- .async_job_payload_scalar(payload, "algorithm")
   string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
   category_links <- .async_job_payload_field(payload, "category_links", required = FALSE)
+  # #574 D3: the cheap-path selector/fingerprint provenance the submit
+  # service (job-functional-submission-service.R) recorded in the payload.
+  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
+  # FALSE) so a worker-run job for those still completes normally.
+  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
   progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
 
   progress("cluster", "Running functional clustering...", current = 0, total = 1)
 
   clusters <- gen_string_clust_obj(
     genes,
     algorithm = algorithm,
     string_id_table = string_id_table
   )
 
   progress("complete", "Functional clustering complete", current = 1, total = 1)
 
+  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
+  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
+  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
+  # path), then the request's cheap-path `provenance` (selector/
+  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
+  # source_data_version) when present, then the `effective_fingerprint` --
+  # only knowable now that `clusters` has actually been computed -- so a
+  # silent exp+db -> combined-score STRING fallback on a worker-run job is
+  # visible in the stored result too, not just a cache hit's.
+  # gene_count is the DISTINCT gene count, matching the cache-hit path's
+  # `resolved_count <- length(unique(genes_list))` (job-functional-submission-
+  # service.R) -- for `["HGNC:1","HGNC:1"]` a raw `length(genes)` reported 2
+  # here while the cache-hit path reported 1 for the identical payload
+  # (Codex round-2 review fix). This never dedups the payload `genes` list
+  # itself or changes `nrow(clusters)`, only the reported count.
+  meta <- clustering_result_meta(
+    list(
+      algorithm = algorithm,
+      gene_count = length(unique(genes)),
+      cluster_count = nrow(clusters),
+      cache_hit = FALSE
+    ),
+    provenance,
+    attr(clusters, "weight_channel")
+  )
+
   list(
     clusters = clusters,
     categories = .async_job_functional_categories(clusters, category_links),
-    meta = list(
-      algorithm = algorithm,
-      gene_count = length(genes),
-      cluster_count = nrow(clusters)
-    )
+    meta = meta
   )
 }
 
 .async_job_chain_llm <- function(result, job, cluster_type) {
   if (!exists("trigger_llm_batch_generation", mode = "function")) {
     return(invisible(result))
   }
 
   llm_clusters <- result
 
   if (is.list(result) && "clusters" %in% names(result) && !is.null(result[["clusters"]])) {
     llm_clusters <- result[["clusters"]]
   }
 
   trigger_llm_batch_generation(
     clusters = llm_clusters,
     cluster_type = cluster_type,
     parent_job_id = job$job_id[[1]]
   )
 
   invisible(result)
 }
 
 .async_job_phenotype_matrix <- function(payload) {
   sysndd_db_phenotypes <- payload$ndd_entity_view_tbl |>
     dplyr::left_join(payload$ndd_review_phenotype_connect_tbl, by = "entity_id") |>
     dplyr::left_join(payload$modifier_list_tbl, by = "modifier_id") |>
     dplyr::left_join(payload$phenotype_list_tbl, by = "phenotype_id") |>
     dplyr::mutate(ndd_phenotype = dplyr::case_when(
       ndd_phenotype == 1 ~ "Yes",
diff --git a/api/functions/clustering-gene-universe.R b/api/functions/clustering-gene-universe.R
new file mode 100644
index 00000000..a212d398
--- /dev/null
+++ b/api/functions/clustering-gene-universe.R
@@ -0,0 +1,165 @@
+# api/functions/clustering-gene-universe.R
+#
+# Category-selected clustering gene-universe resolver (#574 D1).
+#
+# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
+# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
+# universe from curated SysNDD confidence categories instead of the default
+# "all NDD genes" set. This file builds ONLY the resolver + provenance
+# helpers; the submit service and durable handler wiring is done later.
+#
+# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
+# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
+# same gene also has OTHER-category entities. This mirrors
+# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
+# added `category %in% selector` filter -- it deliberately does NOT use
+# `select_network_gene_category()`, which is a gene-level display-label
+# aggregator for node coloring, not a universe filter.
+#
+# Category validation is live against `ndd_entity_status_categories_list
+# WHERE is_active = 1` -- no hardcoded category strings, and no category
+# string is interpolated into SQL (dbplyr `%in%` + an allowlist pre-check).
+
+# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
+# selector returns character(0), which the resolver rejects with 400 -- it must
+# never fall through to the all-NDD default.
+clustering_normalize_category_filter <- function(category_filter) {
+  if (is.null(category_filter)) return(NULL)
+  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
+  vals <- vals[nzchar(vals)]
+  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
+  sort(unique(vals))
+}
+
+clustering_gene_list_sha256 <- function(hgnc_ids) {
+  digest::digest(
+    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
+    algo = "sha256", serialize = FALSE
+  )
+}
+
+clustering_resolve_category_universe <- function(category_filter, conn = pool) {
+  selector <- clustering_normalize_category_filter(category_filter)
+
+  if (is.null(selector)) {
+    # Absent -> preserve the exact current default ordering for cache parity.
+    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
+    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
+  }
+
+  # Any PRESENT selector (including supplied-but-empty) needs the allowed
+  # active-category set for its 400 message, so this fetch runs for every
+  # present-selector path -- not just the unknown-category branch below.
+  active <- conn %>%
+    dplyr::tbl("ndd_entity_status_categories_list") %>%
+    dplyr::filter(is_active == 1) %>%
+    dplyr::select(category) %>%
+    dplyr::collect() %>%
+    dplyr::pull(category)
+
+  if (length(selector) == 0L) {
+    stop_for_bad_request(sprintf(
+      "category_filter was supplied but empty; provide at least one active category. Allowed active categories: %s",
+      paste(sort(active), collapse = ", ")
+    ))
+  }
+
+  unknown <- setdiff(selector, active)
+  if (length(unknown) > 0L) {
+    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
+    stop_for_bad_request(sprintf(
+      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
+      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
+    ))
+  }
+
+  hgnc_ids <- conn %>%
+    dplyr::tbl("ndd_entity_view") %>%
+    dplyr::arrange(entity_id) %>%
+    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
+    dplyr::select(hgnc_id) %>%
+    dplyr::collect() %>%
+    unique() %>%
+    dplyr::pull(hgnc_id)
+
+  if (length(hgnc_ids) < 2L) {
+    stop_for_bad_request(sprintf(
+      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2. Allowed active categories: %s",
+      paste(selector, collapse = ","), length(hgnc_ids), paste(sort(active), collapse = ", ")
+    ))
+  }
+  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
+}
+
+# Module-level (survives across requests within the same process) cache for
+# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
+# public tables and changes rarely (only when the snapshot builder's source
+# view moves), so a short-TTL process cache avoids paying that cost on every
+# clustering submit while still self-refreshing.
+.clustering_source_data_version_cache <- new.env(parent = emptyenv())
+
+#' Predicate: is `v` a valid source-data-version value?
+#'
+#' The fail-closed contract requires a single non-NA, non-empty character
+#' scalar. Anything else (`NULL`, `NA_character_`, `""`, a non-character
+#' value, or a non-scalar) must never be cached or served as provenance
+#' (Codex review fix -- the TTL cache previously cached/returned an invalid
+#' underlying value verbatim).
+.clustering_valid_source_version <- function(v) {
+  is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
+}
+
+#' Cached, fail-closed read of the current analysis source-data version.
+#'
+#' D2 (#574) provenance helper: the clustering submit service calls this
+#' AFTER admission/dedup, only when it is actually about to build a durable
+#' payload. Refetches once `ttl_seconds` has elapsed since the last
+#' successful read. Deliberately does NOT wrap
+#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
+#' PROPAGATES to the caller (never cached, never coerced to NA), so a
+#' transient DB problem fails the submit closed (503) instead of recording
+#' broken provenance. The fetched value is additionally validated by
+#' `.clustering_valid_source_version()`: an invalid value (NA/empty/
+#' non-scalar) is likewise NEVER cached or returned -- it `stop()`s instead,
+#' so the caller's `tryCatch` maps it to the same 503 PROVENANCE_UNAVAILABLE
+#' path as a hard fetch error.
+#'
+#' @param conn DB connection/pool. Defaults to the package-global `pool`.
+#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
+#' @return character(1) source data version.
+#' @export
+clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
+  now <- Sys.time()
+  cached_at <- .clustering_source_data_version_cache$cached_at
+  cached_value <- .clustering_source_data_version_cache$value
+  if (!is.null(cached_at) && .clustering_valid_source_version(cached_value) &&
+        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
+    return(cached_value)
+  }
+
+  value <- analysis_snapshot_source_data_version(conn = conn)
+
+  if (!.clustering_valid_source_version(value)) {
+    stop(
+      "clustering_cached_source_data_version: analysis_snapshot_source_data_version() ",
+      "returned an invalid (NULL/NA/empty/non-scalar) value; refusing to cache or serve it"
+    )
+  }
+
+  .clustering_source_data_version_cache$value <- value
+  .clustering_source_data_version_cache$cached_at <- now
+  value
+}
+
+# Assemble the clustering result `meta`: base fields + the cheap-path provenance
+# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
+# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
+# observed post-compute. Shared by the cache-hit path
+# (job-functional-submission-service.R) and the worker-run/durable handler
+# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
+# shapes cannot drift apart by hand-copied edits.
+clustering_result_meta <- function(base, provenance, weight_channel) {
+  c(base,
+    if (!is.null(provenance)) provenance else list(),
+    list(effective_fingerprint = list(weight_channel = weight_channel)))
+}
diff --git a/api/services/job-functional-submission-service.R b/api/services/job-functional-submission-service.R
index 150c61e0..a4f259b7 100644
--- a/api/services/job-functional-submission-service.R
+++ b/api/services/job-functional-submission-service.R
@@ -1,240 +1,378 @@
 # api/services/job-functional-submission-service.R
 #
 # Body of `POST /api/jobs/clustering/submit`, extracted from
 # endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5). Public endpoint —
 # no role gate. The endpoint shell delegates the entire handler body here;
 # `svc_job_submit_functional_clustering()` mutates `res` (status + headers)
 # exactly as the inline handler used to, and returns the JSON payload.
 #
 # The durable handler receives serialized input, not a database connection, so
 # all values it needs are fetched from `pool` before `create_job()` is called.
 #
 # This is an ENDPOINT service: it is sourced by the shared bootstrap loader
 # (api/bootstrap/load_modules.R) like any other services/* file. The worker
 # executes the registered `clustering` durable handler, never this submitter.
 
 #' Submit a functional (STRING-db) clustering job.
 #'
 #' Cache-first: if the memoised `gen_string_clust_obj_mem()` already has a
 #' result for the resolved gene list + algorithm, the result is persisted as
 #' an already-completed durable job via `async_job_service_store_completed()`
 #' so the response shape matches a freshly-submitted job (this keeps LLM batch
 #' generation on the same job/result hashes as the API-served table). A cache
 #' miss falls through the public queue-depth capacity guard
 #' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
 #' new durable job via `create_job()`.
 #'
-#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm` and
-#'   `req$user$user_id`).
+#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
+#' curated-category selection via `category_filter` (resolved through
+#' `clustering_resolve_category_universe()`), or -- when neither is supplied
+#' -- the existing default all-NDD-genes universe. `genes` and
+#' `category_filter` are mutually exclusive (400 if both are present). Every
+#' submit records selector + fingerprint provenance in the durable payload
+#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
+#'
+#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
+#'   `category_filter` and `req$user$user_id`).
 #' @param res Plumber response, mutated in place (status + headers).
 #' @return List payload for the `json` serializer.
 #' @export
 svc_job_submit_functional_clustering <- function(req, res) {
   # Guard FIRST (#535 S6): per-caller submit admission throttle, applied before any
   # DB/cache/duplicate work so an abusive caller is rejected before it can do — or
   # provoke — expensive work (a cache hit still writes a completed job row, and the
   # duplicate/data fetch below touch the DB). Layered on the global capacity cap.
   admission <- async_job_submit_admission_guard(req, res)
   if (!isTRUE(admission$admitted)) {
     return(admission$response)
   }
 
   # Extract request data before durable submission.
 
-  # Connection objects cannot cross process boundaries
-  genes_list <- NULL
-  if (!is.null(req$argsBody$genes)) {
-    genes_list <- req$argsBody$genes
+  # Connection objects cannot cross process boundaries. `genes` and
+  # `category_filter` are mutually exclusive gene-universe selectors (#574):
+  # an explicit gene list, a curated-category selection, or (both absent) the
+  # existing default all-NDD-genes universe.
+  genes_in <- req$argsBody$genes
+  has_genes <- !is.null(genes_in) && length(genes_in) > 0
+
+  # Selector presence is gated on JSON KEY PRESENCE (`names(req$argsBody)`), not
+  # value-nullness or length: `!is.null()` cannot distinguish an ABSENT key from
+  # an explicit JSON `null` (both parse to NULL in R). So a present `genes` key
+  # (`{"genes":null,...}` / `{"genes":[],...}`) and a present `category_filter`
+  # key each drive their guard regardless of value (Codex rounds 2 & 4). Mutual
+  # exclusion 400s when BOTH keys are present; a present-but-null/empty
+  # `category_filter` is a supplied-empty 400 (in the branch below), never a
+  # silent fall-through to the all-NDD default. `has_genes` (value-based,
+  # non-empty) still selects the explicit-genes branch.
+  body_names <- names(req$argsBody)
+  genes_key <- "genes" %in% body_names
+  category_key <- "category_filter" %in% body_names
+
+  if (genes_key && category_key) {
+    stop_for_bad_request("Provide either genes or category_filter, not both")
   }
 
   # Extract algorithm parameter (default: leiden)
   # Ensure we get a scalar value (JSON may pass arrays)
   algorithm <- "leiden"
   if (!is.null(req$argsBody$algorithm)) {
     algo_input <- req$argsBody$algorithm
     # Handle array input - always take first element if vector
     if (is.list(algo_input) || length(algo_input) >= 1) {
       algo_input <- algo_input[[1]]
     }
     algorithm <- tolower(as.character(algo_input))
     if (!algorithm %in% c("leiden", "walktrap")) {
       algorithm <- "leiden"
     }
   }
 
-  # If no genes provided, use default (all NDD genes)
-  # This matches current functional_clustering endpoint behavior
-  if (is.null(genes_list) || length(genes_list) == 0) {
-    genes_list <- pool %>%
-      dplyr::tbl("ndd_entity_view") %>%
-      dplyr::arrange(entity_id) %>%
-      dplyr::filter(ndd_phenotype == 1) %>%
-      dplyr::select(hgnc_id) %>%
-      dplyr::collect() %>%
-      unique() %>%
-      dplyr::pull(hgnc_id)
+  # Resolve the clustering gene universe + selector provenance (#574). The
+  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
+  # from before this feature: `clustering_resolve_category_universe(NULL)`
+  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
+  # so cache parity (memoise key = gene set + algorithm) is preserved.
+  selector_chr <- NULL
+  if (has_genes) {
+    genes_list <- as.character(unlist(genes_in))
+    kind <- "explicit"
+  } else if (category_key) {
+    # A present category_filter key means a category run. A present-but-null
+    # value is supplied-but-empty (a NULL would otherwise hit the resolver's
+    # absent->default branch), so it is coerced to an empty selector here and
+    # delegated to the resolver -- the resolver's supplied-empty branch 400s
+    # it (with the allowed active-category set in the message), keeping the
+    # 400 message construction in the single resolver source of truth.
+    cf <- req$argsBody$category_filter
+    if (is.null(cf)) cf <- list()
+    universe <- clustering_resolve_category_universe(cf)
+    genes_list <- universe$hgnc_ids
+    selector_chr <- universe$selector
+    kind <- "category"
+  } else {
+    universe <- clustering_resolve_category_universe(NULL)
+    genes_list <- universe$hgnc_ids
+    kind <- "all_ndd"
   }
 
   # Pre-fetch the STRING ID table because DB connections cannot cross the
   # durable worker boundary.
   string_id_table <- pool %>%
     dplyr::tbl("non_alt_loci_set") %>%
     dplyr::filter(!is.na(STRING_id)) %>%
     dplyr::select(symbol, hgnc_id, STRING_id) %>%
     dplyr::collect()
 
-  # Check for duplicate job (include algorithm in check)
-  dup_check <- check_duplicate_job("clustering", list(genes = genes_list, algorithm = algorithm))
+  # Check for duplicate job (include algorithm in check). The selector is
+  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
+  # submits keep the pre-#574 dedup identity byte-identical.
+  dup_params <- list(genes = genes_list, algorithm = algorithm)
+  if (!is.null(selector_chr)) {
+    dup_params$category_filter <- selector_chr
+  }
+  dup_check <- check_duplicate_job("clustering", dup_params)
   if (dup_check$duplicate) {
     res$status <- 409
     res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
     return(list(
       error = "DUPLICATE_JOB",
       message = "Identical job already running",
       existing_job_id = dup_check$existing_job_id,
       status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
     ))
   }
 
+  # Cheap-path provenance (no expensive query yet). `selector_obj` records
+  # WHICH universe was resolved; `intended_fingerprint` records the STRING
+  # cache identity + fixed clustering params this submit intends to run
+  # with. The *effective* fingerprint (e.g. the STRING weight channel a
+  # computed result actually used) is only knowable from a computed result,
+  # so it is recorded separately in the cache-hit result meta below.
+  selector_obj <- list(kind = kind, category_filter = selector_chr)
+  intended_fingerprint <- list(
+    string_cache_fingerprint = analysis_string_cache_fingerprint(),
+    score_threshold = 400L,
+    algorithm = algorithm,
+    seed = 42L
+  )
+  gene_sha <- clustering_gene_list_sha256(genes_list)
+  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
+  # count must agree with it, so it is computed from the SAME dedup -- an
+  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
+  # not report a resolved count that disagrees with a singleton sha256. This
+  # never dedups the payload `genes` list itself (`genes_list` stays
+  # byte-identical to the raw request) -- only the reported COUNT (Codex
+  # review fix).
+  resolved_count <- length(unique(genes_list))
+
+  # Source-data version: a CACHED, fail-closed read, fetched only now that a
+  # payload is actually about to be built -- its backing view runs global
+  # counts/joins, so it must never run before admission/dedup. A lookup
+  # failure must never silently record NA/broken provenance; fail the
+  # request closed instead.
+  src_ver <- tryCatch(
+    clustering_cached_source_data_version(conn = pool),
+    error = function(e) e
+  )
+  if (inherits(src_ver, "error")) {
+    res$status <- 503L
+    return(list(
+      error = "PROVENANCE_UNAVAILABLE",
+      message = "Snapshot source-data version unavailable; retry shortly."
+    ))
+  }
+
+  provenance <- list(
+    selector = selector_obj,
+    resolved_gene_count = resolved_count,
+    gene_list_sha256 = gene_sha,
+    intended_fingerprint = intended_fingerprint,
+    source_data_version = src_ver
+  )
+
   # Define category links (needed for result)
   category_links <- tibble::tibble(
     value = c(
       "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
       "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
       "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
     ),
     link = c(
       "https://www.ebi.ac.uk/QuickGO/term/",
       "https://www.ebi.ac.uk/QuickGO/term/",
       "https://disease-ontology.org/term/",
       "https://www.ebi.ac.uk/QuickGO/term/",
       "https://hpo.jax.org/browse/term/",
       "http://www.ebi.ac.uk/interpro/entry/InterPro/",
       "https://www.genome.jp/dbget-bin/www_bget?",
       "https://www.uniprot.org/keywords/",
       "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
       "https://www.ebi.ac.uk/interpro/entry/pfam/",
       "https://www.ncbi.nlm.nih.gov/search/all/?term=",
       "https://www.ebi.ac.uk/QuickGO/term/",
       "https://reactome.org/content/detail/R-",
       "http://www.ebi.ac.uk/interpro/entry/smart/",
       "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
       "https://www.wikipathways.org/index.php/Pathway:"
     )
   )
 
   # Cache-first: if the memoized function already has a cached result,
   # return it immediately without submitting a durable worker job.
   # The network_edges endpoint (graph) warms this cache on first load,
   # so subsequent table requests resolve instantly.
   cache_hit <- tryCatch(
     memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
     error = function(e) FALSE
   )
 
   if (cache_hit) {
     cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
 
     categories <- cached_clusters %>%
       dplyr::select(term_enrichment) %>%
       tidyr::unnest(cols = c(term_enrichment)) %>%
       dplyr::select(category) %>%
       unique() %>%
       dplyr::arrange(category) %>%
       dplyr::mutate(
         text = dplyr::case_when(
           nchar(category) <= 5 ~ category,
           nchar(category) > 5 ~ stringr::str_to_sentence(category)
         )
       ) %>%
       dplyr::select(value = category, text) %>%
       dplyr::left_join(category_links, by = c("value"))
 
+    # Splice the base cache-hit fields with `provenance` (already assembled
+    # above as selector/resolved_gene_count/gene_list_sha256/
+    # intended_fingerprint/source_data_version) via the shared
+    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
+    # re-listing the same fields as duplicate literals -- keeps this shape in
+    # lockstep with the worker-run handler's result meta by construction.
+    # `effective_fingerprint` is only knowable from the computed result
+    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
     cache_result <- list(
       clusters = cached_clusters,
       categories = categories,
-      meta = list(
-        algorithm = algorithm,
-        gene_count = length(genes_list),
-        cluster_count = nrow(cached_clusters),
-        cache_hit = TRUE
+      meta = clustering_result_meta(
+        list(
+          algorithm = algorithm,
+          gene_count = resolved_count,
+          cluster_count = nrow(cached_clusters),
+          cache_hit = TRUE
+        ),
+        provenance,
+        attr(cached_clusters, "weight_channel")
       )
     )
+    cache_request_payload <- list(
+      genes = genes_list,
+      algorithm = algorithm,
+      category_links = category_links,
+      string_id_table = string_id_table,
+      provenance = provenance
+    )
+    if (!is.null(selector_chr)) {
+      cache_request_payload$category_filter <- selector_chr
+    }
+    # Dedup identity EXCLUDES provenance (Codex round 3): `provenance`
+    # carries a time-varying `source_data_version` and STRING cache
+    # `intended_fingerprint`, so hashing the full payload would make the
+    # active-job uniqueness guard admit duplicate concurrent clustering work
+    # across a deploy/cache-TTL change and break the byte-identical
+    # explicit/no-arg `request_hash` contract predating #574. Removing the
+    # `provenance` key preserves the leading `genes, algorithm,
+    # category_links, string_id_table[, category_filter]` key order -- it was
+    # appended last, so deleting it does not reorder the rest.
+    cache_hash_payload <- cache_request_payload
+    cache_hash_payload$provenance <- NULL
     completed_job <- async_job_service_store_completed(
       job_type = "clustering",
-      request_payload = list(
-        genes = genes_list,
-        algorithm = algorithm,
-        category_links = category_links,
-        string_id_table = string_id_table
-      ),
+      request_payload = cache_request_payload,
       result = cache_result,
       submitted_by = req$user$user_id %||% NULL,
       queue_name = "analysis",
-      priority = 50L
+      priority = 50L,
+      hash_payload = cache_hash_payload
     )
     job_id <- completed_job$job_id[[1]]
 
     res$status <- 202
     res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
     res$setHeader("Retry-After", "0")
 
     return(list(
       job_id = job_id,
       status = "accepted",
       estimated_seconds = 0,
       status_url = paste0("/api/jobs/", job_id, "/status"),
       meta = list(llm_generation = "snapshot_refresh_owned")
     ))
   }
 
   # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   if (async_job_capacity_exceeded(
         tryCatch(
           async_job_active_count("default"),
           error = function(e) {
             log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
             0L
           }
         )
       )) {
     res$status <- 503
     res$setHeader("Retry-After", "60")
     return(list(
       error = "CAPACITY_EXCEEDED",
       message = "Analysis queue is at capacity. Please retry shortly.",
       retry_after = 60
     ))
   }
 
   # Cache miss - create async job
-  result <- create_job(
-    operation = "clustering",
-    params = list(
-      genes = genes_list,
-      algorithm = algorithm,
-      category_links = category_links,
-      string_id_table = string_id_table
-    )
+  job_params <- list(
+    genes = genes_list,
+    algorithm = algorithm,
+    category_links = category_links,
+    string_id_table = string_id_table,
+    provenance = provenance
   )
-
-  # Check capacity
-  if (!is.null(result$error)) {
-    res$status <- 503
-    res$setHeader("Retry-After", as.character(result$retry_after))
-    return(result)
+  if (!is.null(selector_chr)) {
+    job_params$category_filter <- selector_chr
   }
+  # See the cache-hit branch above: dedup identity EXCLUDES provenance so the
+  # active-job uniqueness guard is not defeated by its time-varying fields,
+  # and explicit/no-arg submits stay byte-identical to pre-#574.
+  #
+  # `create_job()` carries a deliberately guarded 2-arg contract
+  # (`operation`, `params`) -- it cannot take a hash override. This path
+  # calls `async_job_service_submit()` directly instead (mirroring the
+  # cache-hit branch above, which already calls
+  # `async_job_service_store_completed()` directly for the same reason), so
+  # `hash_payload` can diverge from the stored `request_payload` without
+  # touching `create_job()`'s contract.
+  hash_params <- job_params
+  hash_params$provenance <- NULL
+  submitted <- async_job_service_submit(
+    job_type = "clustering",
+    request_payload = job_params,
+    hash_payload = hash_params,
+    submitted_by = req$user$user_id %||% NULL
+  )
+  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL
 
   # Success - return HTTP 202 Accepted
   res$status <- 202
-  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
+  res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   res$setHeader("Retry-After", "5")
 
   list(
-    job_id = result$job_id,
-    status = result$status,
-    estimated_seconds = result$estimated_seconds,
-    status_url = paste0("/api/jobs/", result$job_id, "/status")
+    job_id = job_id,
+    status = "accepted",
+    estimated_seconds = 30,
+    status_url = paste0("/api/jobs/", job_id, "/status")
   )
 }

exec
/bin/bash -lc "rg -n -C 3 'create_job\\(|check_duplicate_job\\(|async_job_service_submit\\(' api/functions api/services api/tests/testthat | head -n 360" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/services/job-maintenance-submission-service.R-18-# dedupe via job-type single-flight (`async_job_service_duplicate_by_type()`),
api/services/job-maintenance-submission-service.R-19-# not a payload hash, so a full-table-replace maintenance job never runs
api/services/job-maintenance-submission-service.R-20-# concurrently — including across a deploy that changes its payload schema.
api/services/job-maintenance-submission-service.R:21:# `create_job()` submits only the operation and payload; registered durable
api/services/job-maintenance-submission-service.R-22-# handlers execute the work.
api/services/job-maintenance-submission-service.R-23-#
api/services/job-maintenance-submission-service.R-24-# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
api/services/job-maintenance-submission-service.R-25-# (api/bootstrap/load_modules.R) like any other services/* file, and only ever
api/services/job-maintenance-submission-service.R:26:# submits durable jobs (`async_job_service_submit()`); the worker executes the
api/services/job-maintenance-submission-service.R-27-# registered handlers, never these svc_ functions.
api/services/job-maintenance-submission-service.R-28-
api/services/job-maintenance-submission-service.R-29-#' Submit a disease ontology update job (MONDO + OMIM).
--
api/services/job-maintenance-submission-service.R-49-    dplyr::collect()
api/services/job-maintenance-submission-service.R-50-
api/services/job-maintenance-submission-service.R-51-  # Check for duplicate job (ontology update has no params variation)
api/services/job-maintenance-submission-service.R:52:  dup_check <- check_duplicate_job("ontology_update", list(operation = "ontology_update"))
api/services/job-maintenance-submission-service.R-53-  if (dup_check$duplicate) {
api/services/job-maintenance-submission-service.R-54-    res$status <- 409
api/services/job-maintenance-submission-service.R-55-    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
--
api/services/job-maintenance-submission-service.R-62-  }
api/services/job-maintenance-submission-service.R-63-
api/services/job-maintenance-submission-service.R-64-  # Create async job
api/services/job-maintenance-submission-service.R:65:  result <- create_job(
api/services/job-maintenance-submission-service.R-66-    operation = "ontology_update",
api/services/job-maintenance-submission-service.R-67-    params = list(
api/services/job-maintenance-submission-service.R-68-      hgnc_list = hgnc_list,
--
api/services/job-maintenance-submission-service.R-114-
api/services/job-maintenance-submission-service.R-115-  # Create async job for HGNC update pipeline
api/services/job-maintenance-submission-service.R-116-  # gnomAD enrichment now uses bulk TSV download (~10s), Ensembl/STRINGdb are the bottleneck
api/services/job-maintenance-submission-service.R:117:  result <- create_job(
api/services/job-maintenance-submission-service.R-118-    operation = "hgnc_update",
api/services/job-maintenance-submission-service.R-119-    params = list()
api/services/job-maintenance-submission-service.R-120-  )
--
api/services/job-maintenance-submission-service.R-163-
api/services/job-maintenance-submission-service.R-164-  # Create async job for comparisons update
api/services/job-maintenance-submission-service.R-165-  # Downloads from 7+ sources can take 5-30 minutes depending on network
api/services/job-maintenance-submission-service.R:166:  result <- create_job(
api/services/job-maintenance-submission-service.R-167-    operation = "comparisons_update",
api/services/job-maintenance-submission-service.R-168-    params = list()
api/services/job-maintenance-submission-service.R-169-  )
--
api/services/admin-ontology-endpoint-service.R-6-# Endpoint shells keep their `require_role(req, res, "Administrator")` gate,
api/services/admin-ontology-endpoint-service.R-7-# route decorators, and formals byte-identical; the route bodies below are
api/services/admin-ontology-endpoint-service.R-8-# unchanged logic, only relocated. `force_apply_ontology`'s cheap
api/services/admin-ontology-endpoint-service.R:9:# `blocked_job_id` presence guard and the final `create_job()` submission stay
api/services/admin-ontology-endpoint-service.R-10-# inline in the endpoint (test-endpoint-admin.R asserts those substrings
api/services/admin-ontology-endpoint-service.R-11-# directly against admin_endpoints.R's source); this service supplies the
api/services/admin-ontology-endpoint-service.R-12-# heavier blocked-job lookup/validation between them.
--
api/services/admin-ontology-endpoint-service.R-79-#'
api/services/admin-ontology-endpoint-service.R-80-#' @return List with either `early_return` (a body the caller must return
api/services/admin-ontology-endpoint-service.R-81-#'   as-is, with `res$status` already set) or `params` (ready for
api/services/admin-ontology-endpoint-service.R:82:#'   `create_job(operation = "force_apply_ontology", params = ...)`).
api/services/admin-ontology-endpoint-service.R-83-#' @export
api/services/admin-ontology-endpoint-service.R-84-svc_admin_force_apply_ontology_prepare <- function(req, res, blocked_job_id, assigned_user_id,
api/services/admin-ontology-endpoint-service.R-85-                                                     pool, job_status_fn = get_job_status) {
--
api/services/disease-ontology-mapping-service.R-124-    sched <- now + stagger_seconds
api/services/disease-ontology-mapping-service.R-125-  }
api/services/disease-ontology-mapping-service.R-126-
api/services/disease-ontology-mapping-service.R:127:  # queue_name intentionally omitted so async_job_service_submit() routes this
api/services/disease-ontology-mapping-service.R-128-  # heavy external MONDO refresh to the "maintenance" lane by job type (#486); it
api/services/disease-ontology-mapping-service.R-129-  # is a maintenance-classified job and must not run on the interactive lane.
api/services/disease-ontology-mapping-service.R-130-  outcome <- submit_fn(
--
api/services/backup-endpoint-service.R-12-# functions/job-progress.R (create_progress_reporter), and
api/services/backup-endpoint-service.R-13-# functions/backup-functions.R (list_backup_files, get_backup_metadata,
api/services/backup-endpoint-service.R-14-# is_valid_backup_filename). These svc_ functions only SUBMIT durable jobs:
api/services/backup-endpoint-service.R:15:# create_job() enqueues a durable async job that the worker executes via the
api/services/backup-endpoint-service.R-16-# registered handlers .async_job_run_backup_create /
api/services/backup-endpoint-service.R-17-# .async_job_run_backup_restore (functions/async-job-maintenance-handlers.R).
api/services/backup-endpoint-service.R-18-# The job payload carries NO DB credential (#535 P1-1); the worker resolves it
api/services/backup-endpoint-service.R-19-# at run time via async_job_worker_db_config().
api/services/backup-endpoint-service.R-20-
api/services/backup-endpoint-service.R-21-#' Shared 202/503 response shaping for the /create and /restore job
api/services/backup-endpoint-service.R:22:#' submissions, which differ only in the create_job() operation/params.
api/services/backup-endpoint-service.R-23-.svc_backup_job_response <- function(res, result) {
api/services/backup-endpoint-service.R-24-  if (!is.null(result$error)) {
api/services/backup-endpoint-service.R-25-    res$status <- 503
--
api/services/backup-endpoint-service.R-125-}
api/services/backup-endpoint-service.R-126-
api/services/backup-endpoint-service.R-127-# ---- Backup Creation: POST /create ----
api/services/backup-endpoint-service.R:128:# Submits a durable `backup_create` job via create_job(); 409 when a backup is
api/services/backup-endpoint-service.R-129-# already in progress, 503 when job capacity is exceeded.
api/services/backup-endpoint-service.R-130-svc_backup_create <- function(req, res) {
api/services/backup-endpoint-service.R:131:  dup_check <- check_duplicate_job("backup_create", list())
api/services/backup-endpoint-service.R-132-  if (dup_check$duplicate) {
api/services/backup-endpoint-service.R-133-    res$status <- 409
api/services/backup-endpoint-service.R-134-    return(list(
--
api/services/backup-endpoint-service.R-143-  # No DB credential in the job payload (#535 P1-1): the durable handler
api/services/backup-endpoint-service.R-144-  # .async_job_run_backup_create resolves it from runtime config; execution is
api/services/backup-endpoint-service.R-145-  # delegated to the registered durable handler.
api/services/backup-endpoint-service.R:146:  result <- create_job(
api/services/backup-endpoint-service.R-147-    operation = "backup_create",
api/services/backup-endpoint-service.R-148-    params = list(
api/services/backup-endpoint-service.R-149-      backup_dir = "/backup",
--
api/services/backup-endpoint-service.R-188-  }
api/services/backup-endpoint-service.R-189-
api/services/backup-endpoint-service.R-190-  # Check for duplicate restore job
api/services/backup-endpoint-service.R:191:  dup_check <- check_duplicate_job("backup_restore", list(filename = filename))
api/services/backup-endpoint-service.R-192-  if (dup_check$duplicate) {
api/services/backup-endpoint-service.R-193-    res$status <- 409
api/services/backup-endpoint-service.R-194-    return(list(
--
api/services/backup-endpoint-service.R-202-  # .async_job_run_backup_restore resolves it from runtime config and performs
api/services/backup-endpoint-service.R-203-  # the pre-restore safety backup (BKUP-05); execution is delegated to the
api/services/backup-endpoint-service.R-204-  # registered durable handler.
api/services/backup-endpoint-service.R:205:  result <- create_job(
api/services/backup-endpoint-service.R-206-    operation = "backup_restore",
api/services/backup-endpoint-service.R-207-    params = list(
api/services/backup-endpoint-service.R-208-      restore_file = backup_path,
--
api/services/publication-admin-endpoint-service.R-289-#' Submit an async PubTator update job (`POST /pubtator/update/submit`, Administrator).
api/services/publication-admin-endpoint-service.R-290-#'
api/services/publication-admin-endpoint-service.R-291-#' `require_role()`, the `query == ""` 400 check, and the duplicate-job 409
api/services/publication-admin-endpoint-service.R:292:#' short-circuit (`check_duplicate_job()`) all stay in the endpoint shell;
api/services/publication-admin-endpoint-service.R-293-#' this covers job creation and the capacity-503 / accepted-202 response.
api/services/publication-admin-endpoint-service.R-294-#'
api/services/publication-admin-endpoint-service.R-295-#' @param req,res Plumber request/response.
--
api/services/publication-admin-endpoint-service.R-297-#' @param max_pages Maximum pages to fetch (already coerced to integer).
api/services/publication-admin-endpoint-service.R-298-#' @param clear_old Hard update flag (already coerced to logical).
api/services/publication-admin-endpoint-service.R-299-#' @param q_hash Precomputed query hash (from the shell's duplicate check).
api/services/publication-admin-endpoint-service.R:300:#' @param submit_fn Injectable job submitter (default [create_job()]).
api/services/publication-admin-endpoint-service.R-301-#' @return List with job_id/status/etc (202), or the capacity error body (503).
api/services/publication-admin-endpoint-service.R-302-#' @export
api/services/publication-admin-endpoint-service.R-303-svc_publication_pubtator_update_submit <- function(req, res, query, max_pages, clear_old, q_hash,
--
api/services/admin-publication-refresh-endpoint-service.R-3-# Service layer for POST /admin/publications/refresh, extracted from
api/services/admin-publication-refresh-endpoint-service.R-4-# api/endpoints/admin_endpoints.R (issue #346, Wave 3).
api/services/admin-publication-refresh-endpoint-service.R-5-#
api/services/admin-publication-refresh-endpoint-service.R:6:# `create_job()` (functions/job-manager.R) is a durable-job compatibility
api/services/admin-publication-refresh-endpoint-service.R:7:# facade: it routes through `async_job_service_submit(job_type = operation,
api/services/admin-publication-refresh-endpoint-service.R-8-# request_payload = params)`. The real, currently-executed handler is
api/services/admin-publication-refresh-endpoint-service.R-9-# `.async_job_run_publication_refresh()` in functions/async-job-handlers.R
api/services/admin-publication-refresh-endpoint-service.R-10-# (registered in `async_job_handler_registry`), which already has the
--
api/services/job-functional-submission-service.R-7-# exactly as the inline handler used to, and returns the JSON payload.
api/services/job-functional-submission-service.R-8-#
api/services/job-functional-submission-service.R-9-# The durable handler receives serialized input, not a database connection, so
api/services/job-functional-submission-service.R:10:# all values it needs are fetched from `pool` before `create_job()` is called.
api/services/job-functional-submission-service.R-11-#
api/services/job-functional-submission-service.R-12-# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
api/services/job-functional-submission-service.R-13-# (api/bootstrap/load_modules.R) like any other services/* file. The worker
--
api/services/job-functional-submission-service.R-22-#' generation on the same job/result hashes as the API-served table). A cache
api/services/job-functional-submission-service.R-23-#' miss falls through the public queue-depth capacity guard
api/services/job-functional-submission-service.R-24-#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
api/services/job-functional-submission-service.R:25:#' new durable job via `create_job()`.
api/services/job-functional-submission-service.R-26-#'
api/services/job-functional-submission-service.R-27-#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
api/services/job-functional-submission-service.R-28-#' curated-category selection via `category_filter` (resolved through
--
api/services/job-functional-submission-service.R-131-  if (!is.null(selector_chr)) {
api/services/job-functional-submission-service.R-132-    dup_params$category_filter <- selector_chr
api/services/job-functional-submission-service.R-133-  }
api/services/job-functional-submission-service.R:134:  dup_check <- check_duplicate_job("clustering", dup_params)
api/services/job-functional-submission-service.R-135-  if (dup_check$duplicate) {
api/services/job-functional-submission-service.R-136-    res$status <- 409
api/services/job-functional-submission-service.R-137-    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
--
api/services/job-functional-submission-service.R-313-  }
api/services/job-functional-submission-service.R-314-
api/services/job-functional-submission-service.R-315-  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
api/services/job-functional-submission-service.R:316:  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
api/services/job-functional-submission-service.R-317-  if (async_job_capacity_exceeded(
api/services/job-functional-submission-service.R-318-        tryCatch(
api/services/job-functional-submission-service.R-319-          async_job_active_count("default"),
--
api/services/job-functional-submission-service.R-347-  # active-job uniqueness guard is not defeated by its time-varying fields,
api/services/job-functional-submission-service.R-348-  # and explicit/no-arg submits stay byte-identical to pre-#574.
api/services/job-functional-submission-service.R-349-  #
api/services/job-functional-submission-service.R:350:  # `create_job()` carries a deliberately guarded 2-arg contract
api/services/job-functional-submission-service.R-351-  # (`operation`, `params`) -- it cannot take a hash override. This path
api/services/job-functional-submission-service.R:352:  # calls `async_job_service_submit()` directly instead (mirroring the
api/services/job-functional-submission-service.R-353-  # cache-hit branch above, which already calls
api/services/job-functional-submission-service.R-354-  # `async_job_service_store_completed()` directly for the same reason), so
api/services/job-functional-submission-service.R-355-  # `hash_payload` can diverge from the stored `request_payload` without
api/services/job-functional-submission-service.R:356:  # touching `create_job()`'s contract.
api/services/job-functional-submission-service.R-357-  hash_params <- job_params
api/services/job-functional-submission-service.R-358-  hash_params$provenance <- NULL
api/services/job-functional-submission-service.R:359:  submitted <- async_job_service_submit(
api/services/job-functional-submission-service.R-360-    job_type = "clustering",
api/services/job-functional-submission-service.R-361-    request_payload = job_params,
api/services/job-functional-submission-service.R-362-    hash_payload = hash_params,
--
api/functions/job-manager.R-28-#'
api/functions/job-manager.R-29-#' @examples
api/functions/job-manager.R-30-#' \dontrun{
api/functions/job-manager.R:31:#' result <- create_job(
api/functions/job-manager.R-32-#'   operation = "clustering",
api/functions/job-manager.R-33-#'   params = list(genes = c("BRCA1", "TP53"))
api/functions/job-manager.R-34-#' )
api/functions/job-manager.R-35-#' }
api/functions/job-manager.R-36-create_job <- function(operation, params) {
api/functions/job-manager.R:37:  submitted <- async_job_service_submit(
api/functions/job-manager.R-38-    job_type = operation,
api/functions/job-manager.R-39-    request_payload = params
api/functions/job-manager.R-40-  )
--
api/functions/job-manager.R-218-#'
api/functions/job-manager.R-219-#' @examples
api/functions/job-manager.R-220-#' \dontrun{
api/functions/job-manager.R:221:#' dup <- check_duplicate_job("clustering", list(genes = c("BRCA1")))
api/functions/job-manager.R-222-#' if (dup$duplicate) {
api/functions/job-manager.R-223-#'   return_existing_job(dup$existing_job_id)
api/functions/job-manager.R-224-#' }
--
api/functions/job-manager.R-229-
api/functions/job-manager.R-230-#' Job-type single-flight duplicate check for destructive maintenance jobs.
api/functions/job-manager.R-231-#'
api/functions/job-manager.R:232:#' Same `(operation, params)` shape as [check_duplicate_job()] so it is a
api/functions/job-manager.R-233-#' drop-in `duplicate_check_fn` seam, but dedupes on job_type alone rather than
api/functions/job-manager.R-234-#' the payload hash (#535 S2b HIGH-4): a full-table-replace maintenance job must
api/functions/job-manager.R-235-#' never run concurrently, including across a deploy that changes its payload
--
api/functions/job-manager.R-343-## -------------------------------------------------------------------##
api/functions/job-manager.R-344-
api/functions/job-manager.R-345-# Load LLM batch generator - must be AFTER create_job definition
api/functions/job-manager.R:346:# because trigger_llm_batch_generation() calls create_job()
api/functions/job-manager.R-347-if (file.exists("functions/llm-batch-generator.R")) {
api/functions/job-manager.R-348-  message("[job-manager] Loading llm-batch-generator.R...")
api/functions/job-manager.R-349-  tryCatch(
--
api/services/job-phenotype-submission-service.R-7-# exactly as the inline handler used to, and returns the JSON payload.
api/services/job-phenotype-submission-service.R-8-#
api/services/job-phenotype-submission-service.R-9-# The durable handler receives serialized input, not a database connection, so
api/services/job-phenotype-submission-service.R:10:# all values it needs are fetched from `pool` before `create_job()` is called.
api/services/job-phenotype-submission-service.R-11-#
api/services/job-phenotype-submission-service.R-12-# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
api/services/job-phenotype-submission-service.R-13-# (api/bootstrap/load_modules.R) like any other services/* file. The worker
--
api/services/job-phenotype-submission-service.R-28-#' the LLM batch generator uses the same job/result hashes as the API-served
api/services/job-phenotype-submission-service.R-29-#' table. A cache miss falls through the public queue-depth capacity guard
api/services/job-phenotype-submission-service.R-30-#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
api/services/job-phenotype-submission-service.R:31:#' new durable job via `create_job()`.
api/services/job-phenotype-submission-service.R-32-#'
api/services/job-phenotype-submission-service.R-33-#' @param req Plumber request (reads `req$user$user_id`).
api/services/job-phenotype-submission-service.R-34-#' @param res Plumber response, mutated in place (status + headers).
--
api/services/job-phenotype-submission-service.R-85-  )
api/services/job-phenotype-submission-service.R-86-
api/services/job-phenotype-submission-service.R-87-  # Check for duplicate
api/services/job-phenotype-submission-service.R:88:  dup_check <- check_duplicate_job("phenotype_clustering", params_hash_input)
api/services/job-phenotype-submission-service.R-89-  if (dup_check$duplicate) {
api/services/job-phenotype-submission-service.R-90-    res$status <- 409
api/services/job-phenotype-submission-service.R-91-    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
--
api/services/job-phenotype-submission-service.R-187-  }
api/services/job-phenotype-submission-service.R-188-
api/services/job-phenotype-submission-service.R-189-  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
api/services/job-phenotype-submission-service.R:190:  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
api/services/job-phenotype-submission-service.R-191-  if (async_job_capacity_exceeded(
api/services/job-phenotype-submission-service.R-192-        tryCatch(
api/services/job-phenotype-submission-service.R-193-          async_job_active_count("default"),
--
api/services/job-phenotype-submission-service.R-207-  }
api/services/job-phenotype-submission-service.R-208-
api/services/job-phenotype-submission-service.R-209-  # Cache miss - create async job with pre-built data frame
api/services/job-phenotype-submission-service.R:210:  result <- create_job(
api/services/job-phenotype-submission-service.R-211-    operation = "phenotype_clustering",
api/services/job-phenotype-submission-service.R-212-    params = list(
api/services/job-phenotype-submission-service.R-213-      ndd_entity_view_tbl = ndd_entity_view_tbl,
--
api/functions/llm-batch-generator.R-8-# - Retry logic with exponential backoff and jitter
api/functions/llm-batch-generator.R-9-# - Per-cluster progress reporting
api/functions/llm-batch-generator.R-10-# - Graceful failure (failed clusters don't stop batch)
api/functions/llm-batch-generator.R:11:# - Integration with job-manager via create_job()
api/functions/llm-batch-generator.R-12-
api/functions/llm-batch-generator.R-13-require(logger)
api/functions/llm-batch-generator.R-14-# Make ellmer optional - LLM features require it but basic API functions don't
--
api/functions/llm-batch-generator.R-177-  # async_job_db_connect() (#535 S2b) — no db_config in the payload.
api/functions/llm-batch-generator.R-178-  tryCatch(
api/functions/llm-batch-generator.R-179-    {
api/functions/llm-batch-generator.R:180:      result <- create_job(
api/functions/llm-batch-generator.R-181-        operation = "llm_generation",
api/functions/llm-batch-generator.R-182-        params = list(
api/functions/llm-batch-generator.R-183-          clusters = clusters,
--
api/tests/testthat/test-nddscore-endpoints.R-89-    }, envir = parent.frame())
api/tests/testthat/test-nddscore-endpoints.R-90-
api/tests/testthat/test-nddscore-endpoints.R-91-    source_api_file("functions/async-job-service.R", local = FALSE)
api/tests/testthat/test-nddscore-endpoints.R:92:    submitted <- async_job_service_submit(
api/tests/testthat/test-nddscore-endpoints.R-93-      job_type = "nddscore_import",
api/tests/testthat/test-nddscore-endpoints.R-94-      request_payload = list(record_id = "20258027", validate_only = TRUE),
api/tests/testthat/test-nddscore-endpoints.R-95-      submitted_by = NULL)
--
api/functions/comparisons-functions.R-19-#   - resolve_hgnc_symbols(symbols, conn): Batch lookup HGNC IDs
api/functions/comparisons-functions.R-20-#
api/functions/comparisons-functions.R-21-# Usage:
api/functions/comparisons-functions.R:22:#   Submitted via jobs_endpoints.R -> create_job(); run by the durable worker
api/functions/comparisons-functions.R-23-
api/functions/comparisons-functions.R-24-library(DBI)
api/functions/comparisons-functions.R-25-library(dplyr)
--
api/functions/comparisons-functions.R-239-#' Comparisons Update Async
api/functions/comparisons-functions.R-240-#'
api/functions/comparisons-functions.R-241-#' Main async entry point for the comparisons data refresh job.
api/functions/comparisons-functions.R:242:#' Submitted via create_job(); executed by the durable async worker.
api/functions/comparisons-functions.R-243-#'
api/functions/comparisons-functions.R-244-#' Downloads all active sources, parses, standardizes, resolves HGNC IDs,
api/functions/comparisons-functions.R-245-#' merges, and atomically updates the database.
--
api/tests/testthat/test-unit-backup-endpoint-service.R-307-#
api/tests/testthat/test-unit-backup-endpoint-service.R-308-# Backup jobs execute in the durable handlers .async_job_run_backup_create /
api/tests/testthat/test-unit-backup-endpoint-service.R-309-# .async_job_run_backup_restore (registered in async_job_handler_registry);
api/tests/testthat/test-unit-backup-endpoint-service.R:310:# create_job() submits the durable payload. The submit params must therefore carry NO
api/tests/testthat/test-unit-backup-endpoint-service.R-311-# database credential — the worker resolves it from runtime config via
api/tests/testthat/test-unit-backup-endpoint-service.R-312-# async_job_worker_db_config(). The restore-ordering / pre-backup-abort safety
api/tests/testthat/test-unit-backup-endpoint-service.R-313-# contract is now verified against the real durable handler in
--
api/tests/testthat/test-unit-async-job-service.R-46-    )
api/tests/testthat/test-unit-async-job-service.R-47-  }
api/tests/testthat/test-unit-async-job-service.R-48-
api/tests/testthat/test-unit-async-job-service.R:49:  result <- runtime$async_job_service_submit(
api/tests/testthat/test-unit-async-job-service.R-50-    job_type = "comparisons_update",
api/tests/testthat/test-unit-async-job-service.R-51-    request_payload = list(genes = c("GENE1", "GENE2"), algorithm = "walktrap"),
api/tests/testthat/test-unit-async-job-service.R-52-    submitted_by = 42L,
--
api/tests/testthat/test-unit-async-job-service.R-97-    stop("status lookup should not be needed when duplicate row is attached")
api/tests/testthat/test-unit-async-job-service.R-98-  }
api/tests/testthat/test-unit-async-job-service.R-99-
api/tests/testthat/test-unit-async-job-service.R:100:  result <- runtime$async_job_service_submit(
api/tests/testthat/test-unit-async-job-service.R-101-    job_type = "hgnc_update",
api/tests/testthat/test-unit-async-job-service.R-102-    request_payload = list(refresh = TRUE),
api/tests/testthat/test-unit-async-job-service.R-103-    job_id = "job-new"
--
api/tests/testthat/test-unit-async-job-service.R-256-  }
api/tests/testthat/test-unit-async-job-service.R-257-
api/tests/testthat/test-unit-async-job-service.R-258-  # publication_date_backfill (maintenance) with no explicit queue/priority.
api/tests/testthat/test-unit-async-job-service.R:259:  runtime$async_job_service_submit(
api/tests/testthat/test-unit-async-job-service.R-260-    job_type = "publication_date_backfill",
api/tests/testthat/test-unit-async-job-service.R-261-    request_payload = list(dry_run = FALSE),
api/tests/testthat/test-unit-async-job-service.R-262-    job_id = "job-maint"
--
api/tests/testthat/test-unit-async-job-service.R-265-  expect_equal(created_job$priority, 50L)
api/tests/testthat/test-unit-async-job-service.R-266-
api/tests/testthat/test-unit-async-job-service.R-267-  # llm_generation (interactive) with no explicit queue/priority.
api/tests/testthat/test-unit-async-job-service.R:268:  runtime$async_job_service_submit(
api/tests/testthat/test-unit-async-job-service.R-269-    job_type = "llm_generation",
api/tests/testthat/test-unit-async-job-service.R-270-    request_payload = list(cluster = 1L),
api/tests/testthat/test-unit-async-job-service.R-271-    job_id = "job-llm"
--
api/tests/testthat/test-unit-async-job-service.R-291-                       provenance = list(source_data_version = "2026-07-18T00:00:00Z"))
api/tests/testthat/test-unit-async-job-service.R-292-  subset_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden")
api/tests/testthat/test-unit-async-job-service.R-293-
api/tests/testthat/test-unit-async-job-service.R:294:  runtime$async_job_service_submit(
api/tests/testthat/test-unit-async-job-service.R-295-    job_type = "clustering",
api/tests/testthat/test-unit-async-job-service.R-296-    request_payload = full_payload,
api/tests/testthat/test-unit-async-job-service.R-297-    hash_payload = subset_payload,
--
api/tests/testthat/test-unit-async-job-service.R-322-  )

exec
/bin/bash -lc "rg -n -C 3 'async-job-handlers|bootstrap_load_modules|clustering-gene-universe' api/start_async_worker.R api/bootstrap api/functions api/scripts | head -n 240" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/start_async_worker.R-3-source("bootstrap/load_modules.R", local = FALSE)
api/start_async_worker.R-4-
api/start_async_worker.R-5-bootstrap_init_libraries()
api/start_async_worker.R:6:bootstrap_load_modules()
api/start_async_worker.R-7-source("bootstrap/init_cache.R", local = FALSE)
api/start_async_worker.R-8-bootstrap_init_cache_version()
api/start_async_worker.R-9-bootstrap_bind_memoised(envir = .GlobalEnv)
--
api/start_async_worker.R-12-source("functions/async-job-force-apply-payload.R", local = FALSE)
api/start_async_worker.R-13-source("functions/async-job-provider-handlers.R", local = FALSE)
api/start_async_worker.R-14-source("functions/async-job-maintenance-handlers.R", local = FALSE)
api/start_async_worker.R:15:source("functions/async-job-handlers.R", local = FALSE)
api/start_async_worker.R-16-source("functions/async-job-worker.R", local = FALSE)
api/start_async_worker.R-17-
api/start_async_worker.R-18-env_mode <- Sys.getenv("ENVIRONMENT", "local")
--
api/bootstrap/run_migrations.R-5-#
api/bootstrap/run_migrations.R-6-# Runs the double-checked-locking migration startup dance using
api/bootstrap/run_migrations.R-7-# functions defined in functions/migration-runner.R (which must be
api/bootstrap/run_migrations.R:8:# sourced earlier by bootstrap_load_modules()).
api/bootstrap/run_migrations.R-9-#
api/bootstrap/run_migrations.R-10-# Returns the migration status list that is exposed via
api/bootstrap/run_migrations.R-11-# /api/health/ready.
--
api/bootstrap/setup_workers.R-135-    source("/app/functions/async-job-force-apply-payload.R", local = FALSE)
api/bootstrap/setup_workers.R-136-    source("/app/functions/async-job-provider-handlers.R", local = FALSE)
api/bootstrap/setup_workers.R-137-    source("/app/functions/async-job-maintenance-handlers.R", local = FALSE)
api/bootstrap/setup_workers.R:138:    source("/app/functions/async-job-handlers.R", local = FALSE)
api/bootstrap/setup_workers.R-139-    source("/app/functions/async-job-worker.R", local = FALSE)
api/bootstrap/setup_workers.R-140-    # Source transitional progress shim for legacy mirai async code paths
api/bootstrap/setup_workers.R-141-    source("/app/functions/job-progress.R", local = FALSE)
--
api/bootstrap/load_modules.R-51-#'   for logging / diagnostics). The side effect is that every
api/bootstrap/load_modules.R-52-#'   listed file is sourced into .GlobalEnv.
api/bootstrap/load_modules.R-53-#' @export
api/bootstrap/load_modules.R:54:bootstrap_load_modules <- function() {
api/bootstrap/load_modules.R-55-
api/bootstrap/load_modules.R-56-  # --- function source list (v11.0) ---
api/bootstrap/load_modules.R-57-  function_files <- c(
--
api/bootstrap/load_modules.R-137-    # Category-selected clustering gene-universe resolver (#574). Depends on
api/bootstrap/load_modules.R-138-    # generate_ndd_hgnc_ids() (analyses-functions.R, above) and
api/bootstrap/load_modules.R-139-    # stop_for_bad_request() (core/errors.R, sourced after function_files by
api/bootstrap/load_modules.R:140:    # this same bootstrap_load_modules() call) -- registered before the
api/bootstrap/load_modules.R-141-    # submission service that will consume it.
api/bootstrap/load_modules.R:142:    "functions/clustering-gene-universe.R",
api/bootstrap/load_modules.R-143-    "functions/analysis-phenotype-mca-prep.R",
api/bootstrap/load_modules.R-144-    "functions/analysis-phenotype-functions.R",
api/bootstrap/load_modules.R-145-    "functions/analysis-null-models.R",
--
api/scripts/scrub-job-payload-credentials.R-12-source("bootstrap/init_libraries.R", local = FALSE)
api/scripts/scrub-job-payload-credentials.R-13-bootstrap_init_libraries()
api/scripts/scrub-job-payload-credentials.R-14-source("bootstrap/load_modules.R", local = FALSE)
api/scripts/scrub-job-payload-credentials.R:15:bootstrap_load_modules()
api/scripts/scrub-job-payload-credentials.R-16-source("bootstrap/create_pool.R", local = FALSE)
api/scripts/scrub-job-payload-credentials.R-17-
api/scripts/scrub-job-payload-credentials.R-18-# Resolve the config section exactly like start_sysndd_api.R: Compose passes
--
api/scripts/refresh-analysis-snapshots.R-35-source("bootstrap/create_pool.R", local = FALSE)
api/scripts/refresh-analysis-snapshots.R-36-source("bootstrap/load_modules.R", local = FALSE)
api/scripts/refresh-analysis-snapshots.R-37-bootstrap_init_libraries()
api/scripts/refresh-analysis-snapshots.R:38:bootstrap_load_modules()
api/scripts/refresh-analysis-snapshots.R-39-
api/scripts/refresh-analysis-snapshots.R-40-env_mode <- Sys.getenv("ENVIRONMENT", "local")
api/scripts/refresh-analysis-snapshots.R-41-api_config <- if (tolower(env_mode) == "production") {
--
api/scripts/analysis-validation/phenotype-approximation-ari.R-26-source("bootstrap/create_pool.R", local = FALSE)
api/scripts/analysis-validation/phenotype-approximation-ari.R-27-source("bootstrap/load_modules.R", local = FALSE)
api/scripts/analysis-validation/phenotype-approximation-ari.R-28-bootstrap_init_libraries()
api/scripts/analysis-validation/phenotype-approximation-ari.R:29:bootstrap_load_modules()
api/scripts/analysis-validation/phenotype-approximation-ari.R-30-
api/scripts/analysis-validation/phenotype-approximation-ari.R-31-env_mode <- Sys.getenv("ENVIRONMENT", "local")
api/scripts/analysis-validation/phenotype-approximation-ari.R-32-api_config <- if (tolower(env_mode) == "production") {
--
api/scripts/analysis-validation/functional-resolution-sweep.R-23-source("bootstrap/create_pool.R", local = FALSE)
api/scripts/analysis-validation/functional-resolution-sweep.R-24-source("bootstrap/load_modules.R", local = FALSE)
api/scripts/analysis-validation/functional-resolution-sweep.R-25-bootstrap_init_libraries()
api/scripts/analysis-validation/functional-resolution-sweep.R:26:bootstrap_load_modules()
api/scripts/analysis-validation/functional-resolution-sweep.R-27-
api/scripts/analysis-validation/functional-resolution-sweep.R-28-env_mode <- Sys.getenv("ENVIRONMENT", "local")
api/scripts/analysis-validation/functional-resolution-sweep.R-29-api_config <- if (tolower(env_mode) == "production") {
--
api/functions/clustering-gene-universe.R:1:# api/functions/clustering-gene-universe.R
api/functions/clustering-gene-universe.R-2-#
api/functions/clustering-gene-universe.R-3-# Category-selected clustering gene-universe resolver (#574 D1).
api/functions/clustering-gene-universe.R-4-#
--
api/functions/clustering-gene-universe.R-156-# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
api/functions/clustering-gene-universe.R-157-# observed post-compute. Shared by the cache-hit path
api/functions/clustering-gene-universe.R-158-# (job-functional-submission-service.R) and the worker-run/durable handler
api/functions/clustering-gene-universe.R:159:# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
api/functions/clustering-gene-universe.R-160-# shapes cannot drift apart by hand-copied edits.
api/functions/clustering-gene-universe.R-161-clustering_result_meta <- function(base, provenance, weight_channel) {
api/functions/clustering-gene-universe.R-162-  c(base,
--
api/functions/async-job-omim-apply.R-1-# api/functions/async-job-omim-apply.R
api/functions/async-job-omim-apply.R:2:# OMIM-apply helpers extracted from async-job-handlers.R (#470).
api/functions/async-job-omim-apply.R-3-
api/functions/async-job-omim-apply.R-4-.async_job_omim_db_write <- function(disease_ontology_set_update, safeguard) {
api/functions/async-job-omim-apply.R-5-  # Resolve DB creds from the worker runtime config at run time (#535 S2b),
--
api/functions/async-job-worker.R-73-  }
api/functions/async-job-worker.R-74-
api/functions/async-job-worker.R-75-  handler_candidates <- c(
api/functions/async-job-worker.R:76:    "functions/async-job-handlers.R",
api/functions/async-job-worker.R:77:    "/app/functions/async-job-handlers.R"
api/functions/async-job-worker.R-78-  )
api/functions/async-job-worker.R-79-
api/functions/async-job-worker.R-80-  for (path in handler_candidates) {
--
api/functions/async-job-force-apply-payload.R-1-# api/functions/async-job-force-apply-payload.R
api/functions/async-job-force-apply-payload.R-2-#
api/functions/async-job-force-apply-payload.R:3:# Force-apply payload-shape helpers, extracted from async-job-handlers.R to keep
api/functions/async-job-force-apply-payload.R-4-# that oversized file from growing (AGENTS.md soft 600-line ceiling).
api/functions/async-job-force-apply-payload.R-5-#
api/functions/async-job-force-apply-payload.R-6-# These normalize the `auto_fixes` / `critical_entities` tables carried in a
--
api/functions/async-job-maintenance-handlers.R-3-# Durable async job handlers for maintenance/operational refresh families:
api/functions/async-job-maintenance-handlers.R-4-# database backup create/restore and publication metadata refresh/backfill.
api/functions/async-job-maintenance-handlers.R-5-#
api/functions/async-job-maintenance-handlers.R:6:# Worker-executed code (#346 Wave 4 split of async-job-handlers.R). The
api/functions/async-job-maintenance-handlers.R:7:# `async_job_handler_registry` list in functions/async-job-handlers.R
api/functions/async-job-maintenance-handlers.R-8-# references these handler functions by bare symbol, and R evaluates a
api/functions/async-job-maintenance-handlers.R-9-# list() literal's elements eagerly at construction time — so this file
api/functions/async-job-maintenance-handlers.R:10:# MUST be sourced BEFORE functions/async-job-handlers.R at every worker
api/functions/async-job-maintenance-handlers.R-11-# entrypoint (API bootstrap does not need it; the API never dispatches
api/functions/async-job-maintenance-handlers.R-12-# handlers, only submits jobs).
api/functions/async-job-maintenance-handlers.R-13-
--
api/functions/async-job-provider-handlers.R-4-# HGNC, PubTator/PubTatorNDD, NDDScore import, disease-ontology mapping
api/functions/async-job-provider-handlers.R-5-# refresh, OMIM ontology update, and the OMIM force-apply write path.
api/functions/async-job-provider-handlers.R-6-#
api/functions/async-job-provider-handlers.R:7:# Worker-executed code (#346 Wave 4 split of async-job-handlers.R). The
api/functions/async-job-provider-handlers.R:8:# `async_job_handler_registry` list in functions/async-job-handlers.R
api/functions/async-job-provider-handlers.R-9-# references these handler functions by bare symbol, and R evaluates a
api/functions/async-job-provider-handlers.R-10-# list() literal's elements eagerly at construction time — so this file
api/functions/async-job-provider-handlers.R:11:# MUST be sourced BEFORE functions/async-job-handlers.R at every worker
api/functions/async-job-provider-handlers.R-12-# entrypoint (API bootstrap does not need it; the API never dispatches
api/functions/async-job-provider-handlers.R-13-# handlers, only submits jobs). It also depends on
api/functions/async-job-provider-handlers.R-14-# functions/async-job-omim-apply.R (.async_job_omim_db_write,
--
api/functions/pubtator-enrichment-collector.R-4-# normalization (GitHub issue #175). The web API must never run this on a
api/functions/pubtator-enrichment-collector.R-5-# public request: it makes one external PubTator call per gene plus two
api/functions/pubtator-enrichment-collector.R-6-# corpus-size calls, so it runs inside the durable async worker
api/functions/pubtator-enrichment-collector.R:7:# (`pubtator_enrichment_refresh` job; see functions/async-job-handlers.R).
api/functions/pubtator-enrichment-collector.R-8-#
api/functions/pubtator-enrichment-collector.R-9-# Split of concerns:
api/functions/pubtator-enrichment-collector.R-10-#   * pubtator-enrichment-metrics.R  -- pure math (no I/O), unit-tested.
--
api/functions/pubtator-enrichment-collector.R-383-#' Durable worker entrypoint for the `pubtator_enrichment_refresh` job
api/functions/pubtator-enrichment-collector.R-384-#'
api/functions/pubtator-enrichment-collector.R-385-#' Checks out a connection from the global pool, runs the refresh, and shapes the
api/functions/pubtator-enrichment-collector.R:386:#' job result. Kept here (not in async-job-handlers.R) so the oversized handler
api/functions/pubtator-enrichment-collector.R-387-#' registry file does not grow.
api/functions/pubtator-enrichment-collector.R-388-#'
api/functions/pubtator-enrichment-collector.R-389-#' @param job The durable job row (provides `job_id`, `submitted_by`).
--
api/functions/async-job-handlers.R:1:# api/functions/async-job-handlers.R
api/functions/async-job-handlers.R-2-#
api/functions/async-job-handlers.R-3-# Durable async job handler shell (#346 Wave 4 split): common
api/functions/async-job-handlers.R-4-# payload/progress/clustering helpers, the legacy-executor passthrough
--
api/functions/async-job-handlers.R-20-# Restart the worker container after changing any of these (worker-executed
api/functions/async-job-handlers.R-21-# code is sourced once at startup).
api/functions/async-job-handlers.R-22-# NOTE: .async_job_run_clustering assembles its result meta via
api/functions/async-job-handlers.R:23:# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
api/functions/async-job-handlers.R:24:# worker/API entrypoint sources that module via bootstrap_load_modules() before
api/functions/async-job-handlers.R-25-# this file; a direct-source test env must source it too (as the async-job tests do).
api/functions/async-job-handlers.R-26-
api/functions/async-job-handlers.R-27-.async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
--
api/functions/async-job-handlers.R-118-  progress("complete", "Functional clustering complete", current = 1, total = 1)
api/functions/async-job-handlers.R-119-
api/functions/async-job-handlers.R-120-  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
api/functions/async-job-handlers.R:121:  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
api/functions/async-job-handlers.R-122-  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
api/functions/async-job-handlers.R-123-  # path), then the request's cheap-path `provenance` (selector/
api/functions/async-job-handlers.R-124-  # resolved_gene_count/gene_list_sha256/intended_fingerprint/

exec
/bin/bash -lc "nl -ba api/bootstrap/setup_workers.R | sed -n '1,190p'; nl -ba api/functions/async-job-worker.R | sed -n '1,125p'; rg -n 'setup_workers\\(|get_async_job_handler|\\.async_job_run_clustering|async_job_handler_registry' api -g '*.R'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	## -------------------------------------------------------------------##
     2	# api/bootstrap/setup_workers.R
     3	#
     4	# Part of the Phase D.D6 extract-bootstrap refactor.
     5	#
     6	# Initialises the mirai daemon pool and pre-loads every package /
     7	# source file that background jobs (HGNC/PubTator/ontology/LLM)
     8	# need to execute standalone.
     9	#
    10	# IMPORTANT (from CLAUDE.md): mirai workers have no access to the
    11	# main process's application context. Each daemon sources the
    12	# files listed here ONCE at daemon start-up. If code run inside a
    13	# daemon changes, the api container must be restarted so the
    14	# daemon re-sources the updated file from disk.
    15	#
    16	# IMPORTANT (package order): Load packages that mask dplyr::select
    17	# FIRST (STRINGdb, biomaRt → AnnotationDbi), then dplyr/tidyverse
    18	# LAST so their functions win. Do NOT reorder the everywhere({...})
    19	# block — the ordering is a deliberate workaround for a long-
    20	# standing namespace-shadowing bug documented in CLAUDE.md.
    21	## -------------------------------------------------------------------##
    22	
    23	#' Start the mirai daemon pool and pre-source worker dependencies.
    24	#'
    25	#' `MIRAI_WORKERS` governs daemon count (default 2, clamped 1–8).
    26	#' Tune for host RAM — see CLAUDE.md "Memory / Worker Tuning".
    27	#'
    28	#' @return A list describing the worker configuration (for
    29	#'   logging / diagnostics): `count` (daemon count) and
    30	#'   `dispatcher` (TRUE when dispatcher mode is enabled).
    31	#' @export
    32	bootstrap_setup_workers <- function() {
    33	  worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
    34	
    35	  # Handle NA from invalid input (e.g., "abc")
    36	  if (is.na(worker_count)) worker_count <- 2L
    37	
    38	  # Validate bounds (minimum 1, maximum 8)
    39	  worker_count <- max(1L, min(worker_count, 8L))
    40	
    41	  mirai::daemons(
    42	    n = worker_count,
    43	    dispatcher = TRUE, # Enable for variable-length jobs
    44	    autoexit = tools::SIGINT
    45	  )
    46	  message(sprintf(
    47	    "[%s] Started mirai daemon pool with %d workers",
    48	    Sys.time(), worker_count
    49	  ))
    50	
    51	  # Export required packages and functions to all daemons.
    52	  # NOTE: Load packages that mask dplyr::select FIRST (STRINGdb, biomaRt
    53	  # load AnnotationDbi), then load dplyr/tidyverse LAST so their
    54	  # functions win. Do not reorder — see module header.
    55	  mirai::everywhere({
    56	    library(DBI)
    57	    library(RMariaDB)
    58	    library(STRINGdb)
    59	    library(biomaRt)
    60	    library(FactoMineR)
    61	    library(factoextra)
    62	    library(cluster)
    63	    library(igraph)
    64	    library(digest)
    65	    library(jsonlite)
    66	    library(openssl)
    67	    library(httr2)
    68	    library(memoise)
    69	    library(cachem)
    70	    library(dplyr)
    71	    library(tidyr)
    72	    library(tibble)
    73	    library(stringr)
    74	    library(purrr)
    75	    library(readr)
    76	    library(logger)
    77	    # Load ellmer for LLM functionality (optional - graceful degradation if not available)
    78	    if (requireNamespace("ellmer", quietly = TRUE)) {
    79	      library(ellmer)
    80	    }
    81	    # Load pdftools for PDF parsing in comparisons update (optional)
    82	    if (requireNamespace("pdftools", quietly = TRUE)) {
    83	      library(pdftools)
    84	    }
    85	    # Source data-helpers (generate_panel_hash, generate_json_hash, generate_function_hash, etc.)
    86	    source("/app/functions/data-helpers.R", local = FALSE)
    87	    # Source entity-helpers (nest_gene_tibble, nest_pubtator_gene_tibble, etc.)
    88	    source("/app/functions/entity-helpers.R", local = FALSE)
    89	    # Source file functions (check_file_age, get_newest_file)
    90	    source("/app/functions/file-functions.R", local = FALSE)
    91	    # Source the analysis functions (gen_string_clust_obj, gen_mca_clust_obj)
    92	    source("/app/functions/analysis-string-channels.R", local = FALSE)
    93	    source("/app/functions/analysis-cache-fingerprint.R", local = FALSE)
    94	    source("/app/functions/analyses-functions.R", local = FALSE)
    95	    source("/app/functions/analysis-phenotype-mca-prep.R", local = FALSE)
    96	    source("/app/functions/analysis-phenotype-functions.R", local = FALSE)
    97	    source("/app/functions/analysis-null-models.R", local = FALSE)
    98	    source("/app/functions/analysis-cluster-validation.R", local = FALSE)
    99	    source("/app/functions/analysis-network-functions.R", local = FALSE)
   100	    # Source shared external proxy infrastructure (validate_gene_symbol, cache backends, throttle)
   101	    source("/app/functions/external-proxy-functions.R", local = FALSE)
   102	    # Source gnomAD proxy functions (fetch_gnomad_constraints + memoised wrapper)
   103	    source("/app/functions/external-proxy-gnomad.R", local = FALSE)
   104	    # Source batched gnomAD GraphQL fallback (used by HGNC enrichment for chrX/Y/M genes
   105	    # absent from the autosomes-only bulk constraint TSV). Load order: depends on
   106	    # external-proxy-functions.R (cache_static, validate_gene_symbol) sourced earlier.
   107	    source("/app/functions/external-proxy-gnomad-batch.R", local = FALSE)
   108	    # Source gnomAD/AlphaFold enrichment functions for HGNC update pipeline
   109	    source("/app/functions/hgnc-enrichment-gnomad.R", local = FALSE)
   110	    # Source HGNC functions (update_process_hgnc_data)
   111	    source("/app/functions/hgnc-functions.R", local = FALSE)
   112	    # Source Ensembl functions (gene_coordinates_from_ensembl, gene_coordinates_from_symbol)
   113	    source("/app/functions/ensembl-functions.R", local = FALSE)
   114	    # Source db-helpers for parameterized queries
   115	    source("/app/functions/db-helpers.R", local = FALSE)
   116	    # Source metadata refresh helpers for rollback-safe table replacement
   117	    source("/app/functions/metadata-refresh.R", local = FALSE)
   118	    # Source durable async-job repository for worker-side lease/progress operations
   119	    source("/app/functions/async-job-repository.R", local = FALSE)
   120	    # Runtime DB-credential resolver + historical-payload scrub (#535 P1-1):
   121	    # handlers resolve creds from runtime `dw`, never from the job payload.
   122	    source("/app/functions/async-job-db-config.R", local = FALSE)
   123	    source("/app/functions/async-job-payload-scrub.R", local = FALSE)
   124	    # Source durable async-job runtime helpers before the compatibility shim
   125	    source("/app/functions/async-job-progress.R", local = FALSE)
   126	    source("/app/functions/async-job-network-layout-handlers.R", local = FALSE)
   127	    source("/app/functions/analysis-snapshot-presets.R", local = FALSE)
   128	    source("/app/functions/analysis-snapshot-repository.R", local = FALSE)
   129	    source("/app/functions/analysis-snapshot-prune-helpers.R", local = FALSE)
   130	    source("/app/functions/analysis-snapshot-dependencies.R", local = FALSE)
   131	    source("/app/functions/analysis-snapshot-builder.R", local = FALSE)
   132	    source("/app/functions/analysis-reproducibility.R", local = FALSE)
   133	    source("/app/functions/async-job-analysis-snapshot-handlers.R", local = FALSE)
   134	    source("/app/functions/async-job-omim-apply.R", local = FALSE)
   135	    source("/app/functions/async-job-force-apply-payload.R", local = FALSE)
   136	    source("/app/functions/async-job-provider-handlers.R", local = FALSE)
   137	    source("/app/functions/async-job-maintenance-handlers.R", local = FALSE)
   138	    source("/app/functions/async-job-handlers.R", local = FALSE)
   139	    source("/app/functions/async-job-worker.R", local = FALSE)
   140	    # Source transitional progress shim for legacy mirai async code paths
   141	    source("/app/functions/job-progress.R", local = FALSE)
   142	    # Source PubTator functions for async update jobs (client + parser before orchestrator)
   143	    source("/app/functions/pubtator-client.R", local = FALSE)
   144	    source("/app/functions/pubtator-parser.R", local = FALSE)
   145	    source("/app/functions/pubtator-functions.R", local = FALSE)
   146	    # Source OMIM functions (download_genemap2, parse_genemap2, download_hpoa) for comparisons
   147	    source("/app/functions/omim-functions.R", local = FALSE)
   148	    # Source comparisons functions for async comparisons update jobs
   149	    source("/app/functions/comparisons-sources.R", local = FALSE)
   150	    source("/app/functions/comparisons-parsers.R", local = FALSE)
   151	    source("/app/functions/comparisons-omim.R", local = FALSE)
   152	    source("/app/functions/comparisons-functions.R", local = FALSE)
   153	    # Source LLM-related functions for async LLM batch generation jobs
   154	    source("/app/functions/llm-summary-config.R", local = FALSE)
   155	    source("/app/functions/llm-cache-repository.R", local = FALSE)
   156	    source("/app/functions/llm-validation.R", local = FALSE)
   157	    source("/app/functions/llm-rate-limiter.R", local = FALSE)
   158	    source("/app/functions/llm-types.R", local = FALSE)
   159	    source("/app/functions/llm-model-config.R", local = FALSE)
   160	    source("/app/functions/llm-client.R", local = FALSE)
   161	    source("/app/functions/llm-service.R", local = FALSE)
   162	    source("/app/functions/llm-judge.R", local = FALSE)
   163	    source("/app/functions/llm-batch-cluster-data.R", local = FALSE)
   164	    source("/app/functions/llm-batch-generator.R", local = FALSE)
   165	  })
   166	  message(sprintf(
   167	    "[%s] Exported packages and functions to mirai daemons",
   168	    Sys.time()
   169	  ))
   170	
   171	  list(count = worker_count, dispatcher = TRUE)
   172	}
     1	if (!exists("create_async_job_progress_reporter", mode = "function")) {
     2	  progress_candidates <- c(
     3	    "functions/async-job-progress.R",
     4	    "/app/functions/async-job-progress.R"
     5	  )
     6	
     7	  for (path in progress_candidates) {
     8	    if (file.exists(path)) {
     9	      source(path, local = FALSE)
    10	      break
    11	    }
    12	  }
    13	}
    14	
    15	if (!exists("async_job_get_handler", mode = "function")) {
    16	  network_layout_handler_candidates <- c(
    17	    "functions/async-job-network-layout-handlers.R",
    18	    "/app/functions/async-job-network-layout-handlers.R"
    19	  )
    20	  for (path in network_layout_handler_candidates) {
    21	    if (file.exists(path)) {
    22	      source(path, local = FALSE)
    23	      break
    24	    }
    25	  }
    26	
    27	  omim_apply_candidates <- c(
    28	    "functions/async-job-omim-apply.R",
    29	    "/app/functions/async-job-omim-apply.R"
    30	  )
    31	
    32	  for (path in omim_apply_candidates) {
    33	    if (file.exists(path)) {
    34	      source(path, local = FALSE)
    35	      break
    36	    }
    37	  }
    38	
    39	  force_apply_payload_candidates <- c(
    40	    "functions/async-job-force-apply-payload.R",
    41	    "/app/functions/async-job-force-apply-payload.R"
    42	  )
    43	
    44	  for (path in force_apply_payload_candidates) {
    45	    if (file.exists(path)) {
    46	      source(path, local = FALSE)
    47	      break
    48	    }
    49	  }
    50	
    51	  provider_handler_candidates <- c(
    52	    "functions/async-job-provider-handlers.R",
    53	    "/app/functions/async-job-provider-handlers.R"
    54	  )
    55	
    56	  for (path in provider_handler_candidates) {
    57	    if (file.exists(path)) {
    58	      source(path, local = FALSE)
    59	      break
    60	    }
    61	  }
    62	
    63	  maintenance_handler_candidates <- c(
    64	    "functions/async-job-maintenance-handlers.R",
    65	    "/app/functions/async-job-maintenance-handlers.R"
    66	  )
    67	
    68	  for (path in maintenance_handler_candidates) {
    69	    if (file.exists(path)) {
    70	      source(path, local = FALSE)
    71	      break
    72	    }
    73	  }
    74	
    75	  handler_candidates <- c(
    76	    "functions/async-job-handlers.R",
    77	    "/app/functions/async-job-handlers.R"
    78	  )
    79	
    80	  for (path in handler_candidates) {
    81	    if (file.exists(path)) {
    82	      source(path, local = FALSE)
    83	      break
    84	    }
    85	  }
    86	}
    87	
    88	.async_job_worker_uuid <- function() {
    89	  if (requireNamespace("uuid", quietly = TRUE)) {
    90	    return(uuid::UUIDgenerate())
    91	  }
    92	
    93	  paste(
    94	    as.integer(as.numeric(Sys.time())),
    95	    sprintf("%06d", sample.int(999999, 1)),
    96	    sep = "-"
    97	  )
    98	}
    99	
   100	.async_job_worker_int_env <- function(name, default) {
   101	  value <- suppressWarnings(as.integer(Sys.getenv(name, default)))
   102	  if (is.na(value)) {
   103	    return(as.integer(default))
   104	  }
   105	
   106	  value
   107	}
   108	
   109	.async_job_worker_num_env <- function(name, default) {
   110	  value <- suppressWarnings(as.numeric(Sys.getenv(name, default)))
   111	  if (is.na(value)) {
   112	    return(as.numeric(default))
   113	  }
   114	
   115	  value
   116	}
   117	
   118	.async_job_worker_job_field <- function(claimed_job, field) {
   119	  value <- claimed_job[[field]]
   120	
   121	  if (is.null(value) || length(value) == 0) {
   122	    return(NULL)
   123	  }
   124	
   125	  if (is.list(value)) {
api/start_sysndd_api.R:131:worker_context <- bootstrap_setup_workers()
api/services/admin-publication-refresh-endpoint-service.R:10:# (registered in `async_job_handler_registry`), which already has the
api/functions/async-job-maintenance-handlers.R:7:# `async_job_handler_registry` list in functions/async-job-handlers.R
api/functions/clustering-gene-universe.R:159:# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
api/functions/async-job-handlers.R:5:# factory, the `async_job_handler_registry` list, and the
api/functions/async-job-handlers.R:22:# NOTE: .async_job_run_clustering assembles its result meta via
api/functions/async-job-handlers.R:98:.async_job_run_clustering <- function(job, payload, state, worker_config) {
api/functions/async-job-handlers.R:274:async_job_handler_registry <- list(
api/functions/async-job-handlers.R:277:    run = .async_job_run_clustering,
api/functions/async-job-handlers.R:382:async_job_get_handler <- function(job_type, registry = async_job_handler_registry) {
api/tests/testthat/test-unit-publication-date-backfill.R:123:  expect_true("publication_date_backfill" %in% names(async_job_handler_registry))
api/functions/async-job-worker.R:394:  registry = async_job_handler_registry,
api/functions/async-job-worker.R:534:  registry = async_job_handler_registry,
api/functions/async-job-provider-handlers.R:8:# `async_job_handler_registry` list in functions/async-job-handlers.R
api/tests/testthat/test-unit-async-job-worker.R:14:    # #346 Wave 4: async_job_handler_registry binds provider/maintenance handler
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R:33:# #346 Wave 4: async_job_handler_registry binds provider/maintenance handler
api/tests/testthat/test-publication-refresh.R:173:# (registered in async_job_handler_registry) -- these checks now target that
api/tests/testthat/test-unit-async-job-handlers.R:5:# .async_job_run_clustering assembles its result meta via clustering_result_meta()
api/tests/testthat/test-unit-async-job-handlers.R:9:# The eagerly-built async_job_handler_registry list() references provider and
api/tests/testthat/test-unit-async-job-handlers.R:159:test_that("async_job_handler_registry has the exact expected job-type set", {
api/tests/testthat/test-unit-async-job-handlers.R:169:  expect_equal(sort(names(async_job_handler_registry)), sort(expected_job_types))
api/tests/testthat/test-unit-async-job-handlers.R:174:    clustering = .async_job_run_clustering,
api/tests/testthat/test-unit-async-job-handlers.R:193:      async_job_handler_registry[[job_type]]$run,
api/tests/testthat/test-unit-async-job-handlers.R:203:    expect_true(is.function(async_job_handler_registry[[job_type]]$run), info = job_type)
api/tests/testthat/test-unit-async-job-handlers.R:232:      async_job_handler_registry[[job_type]]$cancel_mode,
api/tests/testthat/test-unit-async-job-handlers.R:251:      async_job_handler_registry[[job_type]]$after_success,
api/tests/testthat/test-unit-async-job-handlers.R:260:    expect_true(is.function(async_job_handler_registry[[job_type]]$after_success), info = job_type)
api/tests/testthat/test-unit-async-job-handlers.R:262:      identical(async_job_handler_registry[[job_type]]$after_success, .async_job_after_success_noop),
api/tests/testthat/test-unit-clustering-handler-meta.R:3:# `.async_job_run_clustering()` (api/functions/async-job-handlers.R) is the
api/tests/testthat/test-unit-clustering-handler-meta.R:28:  # async-job-handlers.R's eagerly-built async_job_handler_registry list()
api/tests/testthat/test-unit-clustering-handler-meta.R:39:  # `.async_job_run_clustering()`'s result-`meta` assembly calls
api/tests/testthat/test-unit-clustering-handler-meta.R:72:test_that(".async_job_run_clustering echoes payload provenance + effective_fingerprint into result meta", {
api/tests/testthat/test-unit-clustering-handler-meta.R:89:  result <- e$.async_job_run_clustering(
api/tests/testthat/test-unit-clustering-handler-meta.R:113:test_that(".async_job_run_clustering: gene_count is the DISTINCT gene count, matching the cache-hit path (Codex round-2 review fix)", {
api/tests/testthat/test-unit-clustering-handler-meta.R:129:  result <- e$.async_job_run_clustering(
api/tests/testthat/test-unit-clustering-handler-meta.R:139:test_that(".async_job_run_clustering: legacy payload with no provenance still returns a valid meta (backward compat)", {
api/tests/testthat/test-unit-clustering-handler-meta.R:152:    result <- e$.async_job_run_clustering(
api/tests/testthat/test-unit-backup-endpoint-service.R:309:# .async_job_run_backup_restore (registered in async_job_handler_registry);
api/tests/testthat/test-unit-pubtatornidd-nightly.R:93:  entry <- async_job_handler_registry[["pubtatornidd_nightly"]]

exec
/bin/bash -lc "rg -n -C 3 'mirai::|async_job_worker_run|async_job_worker_loop|async_job_worker_once|\\.async_job_run_clustering' api --glob '*.R' | head -n 500; nl -ba api/start_sysndd_api.R | sed -n '110,145p'; git log --oneline --all -- api/bootstrap/setup_workers.R | head -n 20" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/bootstrap/mount_endpoints.R-37-      plumber::pr_hook("exit", function() {
api/bootstrap/mount_endpoints.R-38-        pool::poolClose(pool)
api/bootstrap/mount_endpoints.R-39-        message("Disconnected from DB")
api/bootstrap/mount_endpoints.R:40:        mirai::daemons(0) # Shutdown mirai daemon pool
api/bootstrap/mount_endpoints.R-41-        message("Shutdown mirai daemon pool")
api/bootstrap/mount_endpoints.R-42-      })
api/bootstrap/mount_endpoints.R-43-  }
--
api/bootstrap/setup_workers.R-38-  # Validate bounds (minimum 1, maximum 8)
api/bootstrap/setup_workers.R-39-  worker_count <- max(1L, min(worker_count, 8L))
api/bootstrap/setup_workers.R-40-
api/bootstrap/setup_workers.R:41:  mirai::daemons(
api/bootstrap/setup_workers.R-42-    n = worker_count,
api/bootstrap/setup_workers.R-43-    dispatcher = TRUE, # Enable for variable-length jobs
api/bootstrap/setup_workers.R-44-    autoexit = tools::SIGINT
--
api/bootstrap/setup_workers.R-52-  # NOTE: Load packages that mask dplyr::select FIRST (STRINGdb, biomaRt
api/bootstrap/setup_workers.R-53-  # load AnnotationDbi), then load dplyr/tidyverse LAST so their
api/bootstrap/setup_workers.R-54-  # functions win. Do not reorder — see module header.
api/bootstrap/setup_workers.R:55:  mirai::everywhere({
api/bootstrap/setup_workers.R-56-    library(DBI)
api/bootstrap/setup_workers.R-57-    library(RMariaDB)
api/bootstrap/setup_workers.R-58-    library(STRINGdb)
--
api/endpoints/health_endpoints.R-233-  # Check worker pool status via mirai
api/endpoints/health_endpoints.R-234-  worker_status <- tryCatch(
api/endpoints/health_endpoints.R-235-    {
api/endpoints/health_endpoints.R:236:      status <- mirai::status()
api/endpoints/health_endpoints.R-237-      list(
api/endpoints/health_endpoints.R-238-        configured = configured_workers,
api/endpoints/health_endpoints.R-239-        connections = status$connections,
--
api/functions/clustering-gene-universe.R-156-# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
api/functions/clustering-gene-universe.R-157-# observed post-compute. Shared by the cache-hit path
api/functions/clustering-gene-universe.R-158-# (job-functional-submission-service.R) and the worker-run/durable handler
api/functions/clustering-gene-universe.R:159:# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
api/functions/clustering-gene-universe.R-160-# shapes cannot drift apart by hand-copied edits.
api/functions/clustering-gene-universe.R-161-clustering_result_meta <- function(base, provenance, weight_channel) {
api/functions/clustering-gene-universe.R-162-  c(base,
--
api/functions/async-job-handlers.R-19-#     publication refresh/backfill)
api/functions/async-job-handlers.R-20-# Restart the worker container after changing any of these (worker-executed
api/functions/async-job-handlers.R-21-# code is sourced once at startup).
api/functions/async-job-handlers.R:22:# NOTE: .async_job_run_clustering assembles its result meta via
api/functions/async-job-handlers.R-23-# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
api/functions/async-job-handlers.R-24-# worker/API entrypoint sources that module via bootstrap_load_modules() before
api/functions/async-job-handlers.R-25-# this file; a direct-source test env must source it too (as the async-job tests do).
--
api/functions/async-job-handlers.R-95-  categories
api/functions/async-job-handlers.R-96-}
api/functions/async-job-handlers.R-97-
api/functions/async-job-handlers.R:98:.async_job_run_clustering <- function(job, payload, state, worker_config) {
api/functions/async-job-handlers.R-99-  genes <- .async_job_payload_field(payload, "genes")
api/functions/async-job-handlers.R-100-  algorithm <- .async_job_payload_scalar(payload, "algorithm")
api/functions/async-job-handlers.R-101-  string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
--
api/functions/async-job-handlers.R-274-async_job_handler_registry <- list(
api/functions/async-job-handlers.R-275-  clustering = list(
api/functions/async-job-handlers.R-276-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:277:    run = .async_job_run_clustering,
api/functions/async-job-handlers.R-278-    after_success = function(result, job, payload, state, worker_config) {
api/functions/async-job-handlers.R-279-      .async_job_chain_llm(result, job, cluster_type = "functional")
api/functions/async-job-handlers.R-280-    }
--
api/functions/async-job-worker.R-387-#'
api/functions/async-job-worker.R-388-#' @return Invisibly returns TRUE on success, FALSE on failure.
api/functions/async-job-worker.R-389-#' @export
api/functions/async-job-worker.R:390:async_job_worker_run_claimed_job <- function(
api/functions/async-job-worker.R-391-  claimed_job,
api/functions/async-job-worker.R-392-  state,
api/functions/async-job-worker.R-393-  worker_config,
--
api/functions/async-job-worker.R-559-      next
api/functions/async-job-worker.R-560-    }
api/functions/async-job-worker.R-561-
api/functions/async-job-worker.R:562:    async_job_worker_run_claimed_job(
api/functions/async-job-worker.R-563-      claimed_job = claimed_job,
api/functions/async-job-worker.R-564-      state = state,
api/functions/async-job-worker.R-565-      worker_config = worker_config,
--
api/tests/testthat/test-unit-async-job-worker.R-3-library(jsonlite)
api/tests/testthat/test-unit-async-job-worker.R-4-library(tibble)
api/tests/testthat/test-unit-async-job-worker.R-5-
api/tests/testthat/test-unit-async-job-worker.R:6:async_job_worker_runtime_paths <- function() {
api/tests/testthat/test-unit-async-job-worker.R-7-  api_dir <- get_api_dir()
api/tests/testthat/test-unit-async-job-worker.R-8-  c(
api/tests/testthat/test-unit-async-job-worker.R-9-    file.path(api_dir, "functions", "async-job-progress.R"),
--
api/tests/testthat/test-unit-async-job-worker.R-23-  )
api/tests/testthat/test-unit-async-job-worker.R-24-}
api/tests/testthat/test-unit-async-job-worker.R-25-
api/tests/testthat/test-unit-async-job-worker.R:26:load_async_job_worker_runtime <- function() {
api/tests/testthat/test-unit-async-job-worker.R-27-  runtime_env <- new.env(parent = globalenv())
api/tests/testthat/test-unit-async-job-worker.R:28:  runtime_paths <- async_job_worker_runtime_paths()
api/tests/testthat/test-unit-async-job-worker.R-29-
api/tests/testthat/test-unit-async-job-worker.R-30-  missing <- runtime_paths[!file.exists(runtime_paths)]
api/tests/testthat/test-unit-async-job-worker.R-31-  if (length(missing) > 0) {
--
api/tests/testthat/test-unit-async-job-worker.R-43-}
api/tests/testthat/test-unit-async-job-worker.R-44-
api/tests/testthat/test-unit-async-job-worker.R-45-test_that("async_job_worker_config_from_env reads bounded worker settings", {
api/tests/testthat/test-unit-async-job-worker.R:46:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-47-
api/tests/testthat/test-unit-async-job-worker.R-48-  withr::local_envvar(c(
api/tests/testthat/test-unit-async-job-worker.R-49-    ASYNC_JOB_LEASE_SECONDS = "75",
--
api/tests/testthat/test-unit-async-job-worker.R-71-})
api/tests/testthat/test-unit-async-job-worker.R-72-
api/tests/testthat/test-unit-async-job-worker.R-73-test_that("create_async_job_progress_reporter updates durable row progress and throttles interim writes", {
api/tests/testthat/test-unit-async-job-worker.R:74:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-75-  calls <- list()
api/tests/testthat/test-unit-async-job-worker.R-76-  heartbeat_calls <- list()
api/tests/testthat/test-unit-async-job-worker.R-77-
--
api/tests/testthat/test-unit-async-job-worker.R-124-})
api/tests/testthat/test-unit-async-job-worker.R-125-
api/tests/testthat/test-unit-async-job-worker.R-126-test_that("async_job_worker_claim_once skips claims during drain and uses repository claim API otherwise", {
api/tests/testthat/test-unit-async-job-worker.R:127:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-128-  state <- runtime$async_job_worker_state()
api/tests/testthat/test-unit-async-job-worker.R-129-
api/tests/testthat/test-unit-async-job-worker.R-130-  worker_config <- list(
--
api/tests/testthat/test-unit-async-job-worker.R-177-})
api/tests/testthat/test-unit-async-job-worker.R-178-
api/tests/testthat/test-unit-async-job-worker.R-179-test_that("async_job_worker_heartbeat extends the lease with the current claim token", {
api/tests/testthat/test-unit-async-job-worker.R:180:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-181-  heartbeat_call <- NULL
api/tests/testthat/test-unit-async-job-worker.R-182-
api/tests/testthat/test-unit-async-job-worker.R-183-  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
--
api/tests/testthat/test-unit-async-job-worker.R-200-  expect_equal(heartbeat_call$claim_token, "claim-heartbeat")
api/tests/testthat/test-unit-async-job-worker.R-201-})
api/tests/testthat/test-unit-async-job-worker.R-202-
api/tests/testthat/test-unit-async-job-worker.R:203:test_that("async_job_worker_run_claimed_job dispatches the matching handler and persists completion", {
api/tests/testthat/test-unit-async-job-worker.R:204:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-205-  events <- character(0)
api/tests/testthat/test-unit-async-job-worker.R-206-  completed <- NULL
api/tests/testthat/test-unit-async-job-worker.R-207-  call_order <- character(0)
--
api/tests/testthat/test-unit-async-job-worker.R-266-    1L
api/tests/testthat/test-unit-async-job-worker.R-267-  }
api/tests/testthat/test-unit-async-job-worker.R-268-
api/tests/testthat/test-unit-async-job-worker.R:269:  runtime$async_job_worker_run_claimed_job(
api/tests/testthat/test-unit-async-job-worker.R-270-    claimed_job = claimed,
api/tests/testthat/test-unit-async-job-worker.R-271-    state = runtime$async_job_worker_state(),
api/tests/testthat/test-unit-async-job-worker.R-272-    worker_config = list(
--
api/tests/testthat/test-unit-async-job-worker.R-292-  expect_equal(call_order, c("complete", "after_success"))
api/tests/testthat/test-unit-async-job-worker.R-293-})
api/tests/testthat/test-unit-async-job-worker.R-294-
api/tests/testthat/test-unit-async-job-worker.R:295:test_that("async_job_worker_run_claimed_job treats event writes as best-effort", {
api/tests/testthat/test-unit-async-job-worker.R:296:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-297-  completed <- NULL
api/tests/testthat/test-unit-async-job-worker.R-298-  fail_calls <- list()
api/tests/testthat/test-unit-async-job-worker.R-299-
--
api/tests/testthat/test-unit-async-job-worker.R-321-    1L
api/tests/testthat/test-unit-async-job-worker.R-322-  }
api/tests/testthat/test-unit-async-job-worker.R-323-
api/tests/testthat/test-unit-async-job-worker.R:324:  result <- runtime$async_job_worker_run_claimed_job(
api/tests/testthat/test-unit-async-job-worker.R-325-    claimed_job = tibble(
api/tests/testthat/test-unit-async-job-worker.R-326-      job_id = "job-safe-events",
api/tests/testthat/test-unit-async-job-worker.R-327-      job_type = "hgnc_update",
--
api/tests/testthat/test-unit-async-job-worker.R-347-  expect_length(fail_calls, 0L)
api/tests/testthat/test-unit-async-job-worker.R-348-})
api/tests/testthat/test-unit-async-job-worker.R-349-
api/tests/testthat/test-unit-async-job-worker.R:350:test_that("async_job_worker_run_claimed_job fails malformed job rows instead of crashing", {
api/tests/testthat/test-unit-async-job-worker.R:351:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-352-  fail_calls <- list()
api/tests/testthat/test-unit-async-job-worker.R-353-  completed_calls <- 0L
api/tests/testthat/test-unit-async-job-worker.R-354-
--
api/tests/testthat/test-unit-async-job-worker.R-372-    1L
api/tests/testthat/test-unit-async-job-worker.R-373-  }
api/tests/testthat/test-unit-async-job-worker.R-374-
api/tests/testthat/test-unit-async-job-worker.R:375:  unknown_result <- runtime$async_job_worker_run_claimed_job(
api/tests/testthat/test-unit-async-job-worker.R-376-    claimed_job = tibble(
api/tests/testthat/test-unit-async-job-worker.R-377-      job_id = "job-unknown-handler",
api/tests/testthat/test-unit-async-job-worker.R-378-      job_type = "unknown_job_type",
--
api/tests/testthat/test-unit-async-job-worker.R-384-    registry = list()
api/tests/testthat/test-unit-async-job-worker.R-385-  )
api/tests/testthat/test-unit-async-job-worker.R-386-
api/tests/testthat/test-unit-async-job-worker.R:387:  invalid_json_result <- runtime$async_job_worker_run_claimed_job(
api/tests/testthat/test-unit-async-job-worker.R-388-    claimed_job = tibble(
api/tests/testthat/test-unit-async-job-worker.R-389-      job_id = "job-invalid-json",
api/tests/testthat/test-unit-async-job-worker.R-390-      job_type = "hgnc_update",
--
api/tests/testthat/test-unit-async-job-worker.R-411-})
api/tests/testthat/test-unit-async-job-worker.R-412-
api/tests/testthat/test-unit-async-job-worker.R-413-test_that("async_job_worker_sync_drain_signal flips the worker into shutdown mode", {
api/tests/testthat/test-unit-async-job-worker.R:414:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-415-  state <- runtime$async_job_worker_state()
api/tests/testthat/test-unit-async-job-worker.R-416-  drain_file <- tempfile("async-job-worker-drain-")
api/tests/testthat/test-unit-async-job-worker.R-417-
--
api/tests/testthat/test-unit-async-job-worker.R-428-})
api/tests/testthat/test-unit-async-job-worker.R-429-
api/tests/testthat/test-unit-async-job-worker.R-430-test_that("worker main exits cleanly when drain is requested or lifetime bounds are reached", {
api/tests/testthat/test-unit-async-job-worker.R:431:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-432-
api/tests/testthat/test-unit-async-job-worker.R-433-  drain_state <- runtime$async_job_worker_state()
api/tests/testthat/test-unit-async-job-worker.R-434-  drain_state$draining <- TRUE
--
api/tests/testthat/test-unit-async-job-worker.R-497-})
api/tests/testthat/test-unit-async-job-worker.R-498-
api/tests/testthat/test-unit-async-job-worker.R-499-test_that("worker main reaps stale jobs before attempting new claims", {
api/tests/testthat/test-unit-async-job-worker.R:500:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-501-  state <- runtime$async_job_worker_state()
api/tests/testthat/test-unit-async-job-worker.R-502-  call_order <- character(0)
api/tests/testthat/test-unit-async-job-worker.R-503-
--
api/tests/testthat/test-unit-async-job-worker.R-536-  skip_if_not_installed("tidyr")
api/tests/testthat/test-unit-async-job-worker.R-537-  skip_if_not_installed("stringr")
api/tests/testthat/test-unit-async-job-worker.R-538-
api/tests/testthat/test-unit-async-job-worker.R:539:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-540-  progress_calls <- list()
api/tests/testthat/test-unit-async-job-worker.R-541-
api/tests/testthat/test-unit-async-job-worker.R-542-  clusters <- tibble::tibble(
--
api/tests/testthat/test-unit-async-job-worker.R-621-  skip_if_not_installed("dplyr")
api/tests/testthat/test-unit-async-job-worker.R-622-  skip_if_not_installed("tidyr")
api/tests/testthat/test-unit-async-job-worker.R-623-
api/tests/testthat/test-unit-async-job-worker.R:624:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-625-  progress_calls <- list()
api/tests/testthat/test-unit-async-job-worker.R-626-
api/tests/testthat/test-unit-async-job-worker.R-627-  runtime$gen_mca_clust_obj <- function(data_frame) {
--
api/tests/testthat/test-unit-async-job-worker.R-717-})
api/tests/testthat/test-unit-async-job-worker.R-718-
api/tests/testthat/test-unit-async-job-worker.R-719-test_that("legacy durable handlers inject the current durable job id into reused executors", {
api/tests/testthat/test-unit-async-job-worker.R:720:  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-721-
api/tests/testthat/test-unit-async-job-worker.R-722-  comparisons_params <- NULL
api/tests/testthat/test-unit-async-job-worker.R-723-  runtime$comparisons_update_async <- function(params) {
--
api/tests/testthat/test-unit-async-job-handlers.R-2-
api/tests/testthat/test-unit-async-job-handlers.R-3-source_api_file("functions/async-job-force-apply-payload.R", local = FALSE)
api/tests/testthat/test-unit-async-job-handlers.R-4-source_api_file("functions/async-job-omim-apply.R", local = FALSE)
api/tests/testthat/test-unit-async-job-handlers.R:5:# .async_job_run_clustering assembles its result meta via clustering_result_meta()
api/tests/testthat/test-unit-async-job-handlers.R-6-# (clustering-gene-universe.R, #574); source it so the handler resolves it here as
api/tests/testthat/test-unit-async-job-handlers.R-7-# it does in the worker (bootstrap_load_modules sources it before the handlers).
api/tests/testthat/test-unit-async-job-handlers.R-8-source_api_file("functions/clustering-gene-universe.R", local = FALSE)
--
api/tests/testthat/test-unit-async-job-handlers.R-171-
api/tests/testthat/test-unit-async-job-handlers.R-172-test_that("registry entries bind the exact expected handler function by identity", {
api/tests/testthat/test-unit-async-job-handlers.R-173-  bare_symbol_handlers <- list(
api/tests/testthat/test-unit-async-job-handlers.R:174:    clustering = .async_job_run_clustering,
api/tests/testthat/test-unit-async-job-handlers.R-175-    phenotype_clustering = .async_job_run_phenotype_clustering,
api/tests/testthat/test-unit-async-job-handlers.R-176-    ontology_update = .async_job_run_ontology_update,
api/tests/testthat/test-unit-async-job-handlers.R-177-    hgnc_update = .async_job_run_hgnc_update,
--
api/tests/testthat/test-unit-clustering-handler-meta.R-1-# Unit tests for the durable clustering handler's result `meta` (#574 D3).
api/tests/testthat/test-unit-clustering-handler-meta.R-2-#
api/tests/testthat/test-unit-clustering-handler-meta.R:3:# `.async_job_run_clustering()` (api/functions/async-job-handlers.R) is the
api/tests/testthat/test-unit-clustering-handler-meta.R-4-# worker-run (cache-miss) counterpart to the cache-hit path in
api/tests/testthat/test-unit-clustering-handler-meta.R-5-# `svc_job_submit_functional_clustering()` (job-functional-submission-service.R,
api/tests/testthat/test-unit-clustering-handler-meta.R-6-# #574 D2). D2 already stitches the request's cheap-path `provenance` list
--
api/tests/testthat/test-unit-clustering-handler-meta.R-36-  source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-handler-meta.R-37-  source_api_file("functions/async-job-network-layout-handlers.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-handler-meta.R-38-  source_api_file("functions/async-job-analysis-snapshot-handlers.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-handler-meta.R:39:  # `.async_job_run_clustering()`'s result-`meta` assembly calls
api/tests/testthat/test-unit-clustering-handler-meta.R-40-  # `clustering_result_meta()` (#574 D3 fix wave 1), the shared helper defined
api/tests/testthat/test-unit-clustering-handler-meta.R-41-  # in clustering-gene-universe.R -- source it too or the handler errors with
api/tests/testthat/test-unit-clustering-handler-meta.R-42-  # "could not find function".
--
api/tests/testthat/test-unit-clustering-handler-meta.R-69-  e
api/tests/testthat/test-unit-clustering-handler-meta.R-70-}
api/tests/testthat/test-unit-clustering-handler-meta.R-71-
api/tests/testthat/test-unit-clustering-handler-meta.R:72:test_that(".async_job_run_clustering echoes payload provenance + effective_fingerprint into result meta", {
api/tests/testthat/test-unit-clustering-handler-meta.R-73-  e <- .clustering_handler_env()
api/tests/testthat/test-unit-clustering-handler-meta.R-74-
api/tests/testthat/test-unit-clustering-handler-meta.R-75-  payload <- list(
--
api/tests/testthat/test-unit-clustering-handler-meta.R-86-    )
api/tests/testthat/test-unit-clustering-handler-meta.R-87-  )
api/tests/testthat/test-unit-clustering-handler-meta.R-88-
api/tests/testthat/test-unit-clustering-handler-meta.R:89:  result <- e$.async_job_run_clustering(
api/tests/testthat/test-unit-clustering-handler-meta.R-90-    job = list(job_id = "j1"),
api/tests/testthat/test-unit-clustering-handler-meta.R-91-    payload = payload,
api/tests/testthat/test-unit-clustering-handler-meta.R-92-    state = NULL,
--
api/tests/testthat/test-unit-clustering-handler-meta.R-110-  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
api/tests/testthat/test-unit-clustering-handler-meta.R-111-})
api/tests/testthat/test-unit-clustering-handler-meta.R-112-
api/tests/testthat/test-unit-clustering-handler-meta.R:113:test_that(".async_job_run_clustering: gene_count is the DISTINCT gene count, matching the cache-hit path (Codex round-2 review fix)", {
api/tests/testthat/test-unit-clustering-handler-meta.R-114-  # Bug: the worker handler reported `gene_count = length(genes)` (raw),
api/tests/testthat/test-unit-clustering-handler-meta.R-115-  # while the cache-hit path (job-functional-submission-service.R) reports
api/tests/testthat/test-unit-clustering-handler-meta.R-116-  # `resolved_count <- length(unique(genes_list))` (distinct) -- for
--
api/tests/testthat/test-unit-clustering-handler-meta.R-126-    category_links = NULL
api/tests/testthat/test-unit-clustering-handler-meta.R-127-  )
api/tests/testthat/test-unit-clustering-handler-meta.R-128-
api/tests/testthat/test-unit-clustering-handler-meta.R:129:  result <- e$.async_job_run_clustering(
api/tests/testthat/test-unit-clustering-handler-meta.R-130-    job = list(job_id = "j-dup-genes"),
api/tests/testthat/test-unit-clustering-handler-meta.R-131-    payload = payload,
api/tests/testthat/test-unit-clustering-handler-meta.R-132-    state = NULL,
--
api/tests/testthat/test-unit-clustering-handler-meta.R-136-  expect_identical(result$meta$gene_count, 1L)
api/tests/testthat/test-unit-clustering-handler-meta.R-137-})
api/tests/testthat/test-unit-clustering-handler-meta.R-138-
api/tests/testthat/test-unit-clustering-handler-meta.R:139:test_that(".async_job_run_clustering: legacy payload with no provenance still returns a valid meta (backward compat)", {
api/tests/testthat/test-unit-clustering-handler-meta.R-140-  e <- .clustering_handler_env()
api/tests/testthat/test-unit-clustering-handler-meta.R-141-
api/tests/testthat/test-unit-clustering-handler-meta.R-142-  payload <- list(
--
api/tests/testthat/test-unit-clustering-handler-meta.R-149-
api/tests/testthat/test-unit-clustering-handler-meta.R-150-  result <- NULL
api/tests/testthat/test-unit-clustering-handler-meta.R-151-  expect_no_error({
api/tests/testthat/test-unit-clustering-handler-meta.R:152:    result <- e$.async_job_run_clustering(
api/tests/testthat/test-unit-clustering-handler-meta.R-153-      job = list(job_id = "j2"),
api/tests/testthat/test-unit-clustering-handler-meta.R-154-      payload = payload,
api/tests/testthat/test-unit-clustering-handler-meta.R-155-      state = NULL,
   110	## -------------------------------------------------------------------##
   111	# 7) Disk-backed memoise cache (see documentation/09-deployment.qmd for CACHE_VERSION).
   112	## -------------------------------------------------------------------##
   113	bootstrap_init_cache_version()
   114	
   115	memoised <- bootstrap_init_memoised()
   116	generate_stat_tibble_mem       <- memoised$generate_stat_tibble_mem
   117	generate_gene_news_tibble_mem  <- memoised$generate_gene_news_tibble_mem
   118	nest_gene_tibble_mem           <- memoised$nest_gene_tibble_mem
   119	generate_tibble_fspec_mem      <- memoised$generate_tibble_fspec_mem
   120	gen_string_clust_obj_mem       <- memoised$gen_string_clust_obj_mem
   121	gen_mca_clust_obj_mem          <- memoised$gen_mca_clust_obj_mem
   122	gen_network_edges_mem          <- memoised$gen_network_edges_mem
   123	generate_phenotype_correlations_mem <-
   124	  memoised$generate_phenotype_correlations_mem
   125	read_log_files_mem             <- memoised$read_log_files_mem
   126	nest_pubtator_gene_tibble_mem  <- memoised$nest_pubtator_gene_tibble_mem
   127	
   128	## -------------------------------------------------------------------##
   129	# 8) Mirai daemon pool + worker-side source files.
   130	## -------------------------------------------------------------------##
   131	worker_context <- bootstrap_setup_workers()
   132	
   133	# Hourly job cleanup (schedule_cleanup defined in functions/job-manager.R).
   134	schedule_cleanup(3600)
   135	
   136	## -------------------------------------------------------------------##
   137	# 9) Mount endpoints + filters onto the root router.
   138	## -------------------------------------------------------------------##
   139	root <- bootstrap_mount_endpoints(api_spec, pool, logging_temp_file)
   140	
   141	## -------------------------------------------------------------------##
   142	# 9b) Bootstrap PubtatorNDD enrichment if no current snapshot exists (#421):
   143	#     a fresh deploy gets enrichment + the gene-summary table populated without
   144	#     waiting for the nightly cron. Idempotent + dedup-safe; never crashes boot.
   145	## -------------------------------------------------------------------##
8765302c refactor(api): extract analysis_snapshot_prune to keep repository under 600 lines (#573)
5cabf13a fix: bind phenotype-functional snapshots to cluster axes
6ded0588 fix(security): fold confirming Codex review — unbreak image build, honest scrub observability, guard/parity polish (#535 P1-1)
df99b229 feat(api): add async_job_worker_db_config() runtime credential resolver (#535 P1-1)
d478e5e0 refactor(api): Wave 4 — services/functions/workers under 600 lines (#346) (#529)
9bd9e816 fix(analysis): self-healing cluster cache + snapshot coherence gate (#514)
f96251da fix(analysis): code-review follow-ups on cluster soundness (#508–#512)
baaca9e1 feat(comparisons): map NDD GeneHub evidence tiers (AR/Tier 1-4/Missense) as category
4651aba4 fix(comparisons): repair geisinger source, resilient refresh, configurable NDD seed (#502)
1f3f03d4 fix(llm): keep cluster summaries consistent with the published snapshot (#485,#488,#490)
88eb0281 fix(api): force-apply ontology survives the simplifyVector data.frame payload (#476)
fa2677cb fix(api): source omim-apply helper in worker daemons; parse ISO job timestamps; test status IO wrapper (#470)
e6b6e041 fix: address analysis snapshot review findings
6eaf5c20 feat: add analysis snapshot refresh pipeline
4b1fb24c Make metadata refreshes rollback-safe (#364)
e7dc489c [codex] GeneNetworks fCoSE layout artifacts (#362)
a72e728f [codex] Add MCP analysis research context tools (#345)
f9a7baa1 feat(api): gnomAD chrX/Y/M constraint fallback via batched GraphQL (#313)
90b46bb9 feat(async-jobs): add worker runtime and durable progress
1057b193 feat(async-jobs): add durable job schema and repository

exec
/bin/bash -lc "rg -n -C 5 '"'^create_job|create_job <-|check_duplicate_job <-'"' api/functions api/services; nl -ba api/functions/job-manager.R | sed -n '1,280p'; nl -ba api/functions/job-manager.R | sed -n '280,620p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/functions/job-manager.R-31-#' result <- create_job(
api/functions/job-manager.R-32-#'   operation = "clustering",
api/functions/job-manager.R-33-#'   params = list(genes = c("BRCA1", "TP53"))
api/functions/job-manager.R-34-#' )
api/functions/job-manager.R-35-#' }
api/functions/job-manager.R:36:create_job <- function(operation, params) {
api/functions/job-manager.R-37-  submitted <- async_job_service_submit(
api/functions/job-manager.R-38-    job_type = operation,
api/functions/job-manager.R-39-    request_payload = params
api/functions/job-manager.R-40-  )
api/functions/job-manager.R-41-
--
api/functions/job-manager.R-221-#' dup <- check_duplicate_job("clustering", list(genes = c("BRCA1")))
api/functions/job-manager.R-222-#' if (dup$duplicate) {
api/functions/job-manager.R-223-#'   return_existing_job(dup$existing_job_id)
api/functions/job-manager.R-224-#' }
api/functions/job-manager.R-225-#' }
api/functions/job-manager.R:226:check_duplicate_job <- function(operation, params) {
api/functions/job-manager.R-227-  async_job_service_duplicate(operation, params)
api/functions/job-manager.R-228-}
api/functions/job-manager.R-229-
api/functions/job-manager.R-230-#' Job-type single-flight duplicate check for destructive maintenance jobs.
api/functions/job-manager.R-231-#'
     1	#' Job Manager Module
     2	#'
     3	#' Legacy compatibility facade for async API operations.
     4	#' Public job submission, status, and history now route through the
     5	#' durable async job service instead of process-local state.
     6	#'
     7	#' @name job-manager
     8	#' @author SysNDD Team
     9	
    10	# Load required packages for this module
    11	# Note: uuid, digest, and durable async-job helpers are loaded at bootstrap.
    12	
    13	# NOTE: LLM batch generator loaded at END of file (after create_job is defined)
    14	
    15	## -------------------------------------------------------------------##
    16	# Core Functions
    17	## -------------------------------------------------------------------##
    18	
    19	#' Create a new async job
    20	#'
    21	#' Submits a durable job for execution by its registered worker handler.
    22	#'
    23	#' @param operation Character string identifying the operation type
    24	#'   (e.g., "clustering", "phenotype_clustering", "ontology_update")
    25	#' @param params List of payload parameters for the registered handler.
    26	#'
    27	#' @return List with job_id, status="accepted", and estimated_seconds=30.
    28	#'
    29	#' @examples
    30	#' \dontrun{
    31	#' result <- create_job(
    32	#'   operation = "clustering",
    33	#'   params = list(genes = c("BRCA1", "TP53"))
    34	#' )
    35	#' }
    36	create_job <- function(operation, params) {
    37	  submitted <- async_job_service_submit(
    38	    job_type = operation,
    39	    request_payload = params
    40	  )
    41	
    42	  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL
    43	
    44	  list(
    45	    job_id = job_id,
    46	    status = "accepted",
    47	    estimated_seconds = 30
    48	  )
    49	}
    50	
    51	#' Get the status of a job
    52	#'
    53	#' Reads the persisted durable-job state and returns the polling response.
    54	#'
    55	#' @param job_id Character string - the UUID of the job
    56	#' @param result_mode Character string - "summary" omits stored result JSON,
    57	#'   "full" includes and parses it.
    58	#'
    59	#' @return List with either:
    60	#'   - Not found: error="JOB_NOT_FOUND"
    61	#'   - Running: status, step, estimated_seconds, retry_after=5
    62	#'   - Completed: status, completed_at, result or error
    63	#'
    64	#' @examples
    65	#' \dontrun{
    66	#' status <- get_job_status("550e8400-e29b-41d4-a716-446655440000")
    67	#' }
    68	get_job_status <- function(job_id, result_mode = "summary") {
    69	  result_mode <- as.character(result_mode[[1]] %||% "summary")
    70	  if (!result_mode %in% c("summary", "full")) {
    71	    stop("result_mode must be one of: summary, full", call. = FALSE)
    72	  }
    73	
    74	  job <- async_job_service_status(
    75	    job_id,
    76	    include_result = identical(result_mode, "full")
    77	  )
    78	
    79	  if (nrow(job) == 0) {
    80	    return(list(
    81	      error = "JOB_NOT_FOUND",
    82	      message = "Job ID not found"
    83	    ))
    84	  }
    85	
    86	  durable_status <- job$status[[1]]
    87	
    88	  if (durable_status %in% c("queued", "running", "cancel_requested")) {
    89	    submitted_at <- job$submitted_at[[1]]
    90	    elapsed <- as.numeric(difftime(Sys.time(), submitted_at, units = "secs"))
    91	    remaining <- max(0, 1800 - elapsed)
    92	    progress_pct <- suppressWarnings(as.numeric(job$progress_pct[[1]]))
    93	
    94	    progress_data <- NULL
    95	    if (!is.na(progress_pct)) {
    96	      progress_data <- list(
    97	        current = as.integer(round(progress_pct)),
    98	        total = 100L
    99	      )
   100	    }
   101	
   102	    return(list(
   103	      job_id = job_id,
   104	      status = "running",
   105	      step = job$progress_message[[1]] %||% get_progress_message(job$job_type[[1]]),
   106	      progress = progress_data,
   107	      estimated_seconds = round(remaining),
   108	      retry_after = 5
   109	    ))
   110	  }
   111	
   112	  if (durable_status == "completed") {
   113	    result <- NULL
   114	    error <- NULL
   115	    if (identical(result_mode, "full") &&
   116	        "result_json" %in% names(job) &&
   117	        !is.na(job$result_json[[1]])) {
   118	      result <- tryCatch(
   119	        jsonlite::fromJSON(job$result_json[[1]], simplifyVector = TRUE),
   120	        error = function(e) {
   121	          error <<- list(
   122	            code = "RESULT_PARSE_FAILED",
   123	            message = conditionMessage(e)
   124	          )
   125	          NULL
   126	        }
   127	      )
   128	    }
   129	
   130	    return(list(
   131	      job_id = job_id,
   132	      status = "completed",
   133	      completed_at = if (!is.na(job$completed_at[[1]])) {
   134	        format(job$completed_at[[1]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
   135	      } else {
   136	        NULL
   137	      },
   138	      result = result,
   139	      result_mode = result_mode,
   140	      error = error
   141	    ))
   142	  }
   143	
   144	  if (durable_status == "cancelled") {
   145	    return(list(
   146	      job_id = job_id,
   147	      status = "cancelled",
   148	      completed_at = if (!is.na(job$completed_at[[1]])) {
   149	        format(job$completed_at[[1]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
   150	      } else {
   151	        NULL
   152	      },
   153	      result = NULL,
   154	      error = list(
   155	        code = "CANCELLED",
   156	        message = job$last_error_message[[1]] %||% "Job was cancelled"
   157	      )
   158	    ))
   159	  }
   160	
   161	  list(
   162	    job_id = job_id,
   163	    status = "failed",
   164	    completed_at = if (!is.na(job$completed_at[[1]])) {
   165	      format(job$completed_at[[1]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
   166	    } else {
   167	      NULL
   168	    },
   169	    result = NULL,
   170	    error = list(
   171	      code = job$last_error_code[[1]] %||% "EXECUTION_ERROR",
   172	      message = job$last_error_message[[1]] %||% "Job execution failed"
   173	    )
   174	  )
   175	}
   176	
   177	#' Get operation-specific progress message
   178	#'
   179	#' Returns a user-friendly message describing what the job is doing.
   180	#'
   181	#' @param operation Character string identifying the operation type
   182	#'
   183	#' @return Character string with progress message
   184	#'
   185	#' @examples
   186	#' \dontrun{
   187	#' msg <- get_progress_message("clustering")
   188	#' # Returns: "Fetching interaction data from STRING-db..."
   189	#' }
   190	get_progress_message <- function(operation) {
   191	  messages <- list(
   192	    clustering = "Fetching interaction data from STRING-db...",
   193	    phenotype_clustering = "Running Multiple Correspondence Analysis...",
   194	    ontology_update = "Downloading and processing ontology data from MONDO/OMIM...",
   195	    omim_update = "Updating OMIM annotations from mim2gene.txt + JAX API...",
   196	    hgnc_update = "Downloading HGNC data and enriching with gnomAD constraints...",
   197	    backup_create = "Creating database backup...",
   198	    backup_restore = "Restoring database from backup...",
   199	    pubtator_update = "Fetching publications from PubTator API...",
   200	    llm_generation = "Generating LLM summaries for clusters...",
   201	    comparisons_update = "Refreshing comparisons data from external NDD databases..."
   202	  )
   203	
   204	  messages[[operation]] %||% "Processing request..."
   205	}
   206	
   207	#' Check for duplicate running jobs
   208	#'
   209	#' Scans active jobs for one with matching operation and parameters.
   210	#' Prevents duplicate expensive computations.
   211	#'
   212	#' @param operation Character string identifying the operation type
   213	#' @param params List of parameters to check against
   214	#'
   215	#' @return List with:
   216	#'   - duplicate=TRUE, existing_job_id: if duplicate found
   217	#'   - duplicate=FALSE: if no duplicate
   218	#'
   219	#' @examples
   220	#' \dontrun{
   221	#' dup <- check_duplicate_job("clustering", list(genes = c("BRCA1")))
   222	#' if (dup$duplicate) {
   223	#'   return_existing_job(dup$existing_job_id)
   224	#' }
   225	#' }
   226	check_duplicate_job <- function(operation, params) {
   227	  async_job_service_duplicate(operation, params)
   228	}
   229	
   230	#' Job-type single-flight duplicate check for destructive maintenance jobs.
   231	#'
   232	#' Same `(operation, params)` shape as [check_duplicate_job()] so it is a
   233	#' drop-in `duplicate_check_fn` seam, but dedupes on job_type alone rather than
   234	#' the payload hash (#535 S2b HIGH-4): a full-table-replace maintenance job must
   235	#' never run concurrently, including across a deploy that changes its payload
   236	#' schema. `params` is ignored.
   237	#'
   238	#' @param operation Character job type.
   239	#' @param params Ignored (present for seam compatibility).
   240	#' @return list(duplicate = FALSE) or list(duplicate = TRUE, existing_job_id).
   241	#' @export
   242	check_active_job_by_type <- function(operation, params = NULL) {
   243	  async_job_service_duplicate_by_type(operation)
   244	}
   245	
   246	#' Compatibility no-op for the removed in-memory cleanup cycle
   247	#'
   248	#' @return Integer count of removed jobs (invisible).
   249	#' @export
   250	cleanup_old_jobs <- function() {
   251	  invisible(0L)
   252	}
   253	
   254	#' Compatibility no-op for the removed in-memory cleanup scheduler
   255	#'
   256	#' @param interval_seconds Interval between cleanup runs in seconds
   257	#' @export
   258	schedule_cleanup <- function(interval_seconds = 3600) {
   259	  invisible(interval_seconds)
   260	}
   261	
   262	#' Get Job History
   263	#'
   264	#' Returns recent durable jobs, sorted by submission time (newest first).
   265	#'
   266	#' @param limit Integer maximum number of jobs to return (default 20)
   267	#' @return Data frame of job records with: job_id, operation, status,
   268	#'   submitted_at, completed_at, duration_seconds, error_message
   269	#'
   270	#' @examples
   271	#' \dontrun{
   272	#' history <- get_job_history(20)
   273	#' }
   274	#' @export
   275	get_job_history <- function(limit = 20) {
   276	  jobs <- async_job_service_history(limit)
   277	
   278	  if (nrow(jobs) == 0) {
   279	    return(data.frame(
   280	      job_id = character(0),
   280	      job_id = character(0),
   281	      operation = character(0),
   282	      status = character(0),
   283	      submitted_at = character(0),
   284	      completed_at = character(0),
   285	      duration_seconds = integer(0),
   286	      error_message = character(0),
   287	      stringsAsFactors = FALSE
   288	    ))
   289	  }
   290	
   291	  result <- data.frame(
   292	    job_id = unname(as.character(jobs$job_id)),
   293	    operation = unname(as.character(jobs$job_type)),
   294	    status = unname(as.character(jobs$status)),
   295	    submitted_at = vapply(
   296	      jobs$submitted_at,
   297	      function(value) unname(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
   298	      character(1)
   299	    ),
   300	    completed_at = vapply(
   301	      jobs$completed_at,
   302	      function(value) {
   303	        if (is.na(value)) {
   304	          NA_character_
   305	        } else {
   306	          unname(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
   307	        }
   308	      },
   309	      character(1)
   310	    ),
   311	    duration_seconds = vapply(
   312	      seq_len(nrow(jobs)),
   313	      function(i) {
   314	        completed_at <- jobs$completed_at[[i]]
   315	        if (is.na(completed_at)) {
   316	          completed_at <- Sys.time()
   317	        }
   318	        as.integer(round(as.numeric(difftime(completed_at, jobs$submitted_at[[i]], units = "secs"))))
   319	      },
   320	      integer(1)
   321	    ),
   322	    error_message = vapply(
   323	      jobs$last_error_message,
   324	      function(value) {
   325	        if (is.na(value)) {
   326	          NA_character_
   327	        } else {
   328	          unname(as.character(value))
   329	        }
   330	      },
   331	      character(1)
   332	    ),
   333	    stringsAsFactors = FALSE,
   334	    row.names = NULL
   335	  )
   336	
   337	  rownames(result) <- NULL
   338	  result
   339	}
   340	
   341	## -------------------------------------------------------------------##
   342	# Load LLM Batch Generator (AFTER create_job is defined)
   343	## -------------------------------------------------------------------##
   344	
   345	# Load LLM batch generator - must be AFTER create_job definition
   346	# because trigger_llm_batch_generation() calls create_job()
   347	if (file.exists("functions/llm-batch-generator.R")) {
   348	  message("[job-manager] Loading llm-batch-generator.R...")
   349	  tryCatch(
   350	    {
   351	      source("functions/llm-batch-generator.R", local = FALSE)
   352	      message("[job-manager] llm-batch-generator.R loaded successfully")
   353	      message(
   354	        "[job-manager] trigger_llm_batch_generation exists: ",
   355	        exists("trigger_llm_batch_generation", mode = "function")
   356	      )
   357	      message("[job-manager] llm_batch_executor exists: ", exists("llm_batch_executor", mode = "function"))
   358	    },
   359	    error = function(e) {
   360	      message("[job-manager] ERROR loading llm-batch-generator.R: ", conditionMessage(e))
   361	    }
   362	  )
   363	} else {
   364	  message("[job-manager] llm-batch-generator.R NOT FOUND")
   365	}
   366	
   367	## -------------------------------------------------------------------##
   368	# Job-Result Access Predicate
   369	## -------------------------------------------------------------------##
   370	
   371	# Job operations whose full result JSON is safe for anonymous retrieval
   372	# (public, user-initiated analysis that returns the caller's own output).
   373	PUBLIC_FULL_RESULT_JOB_TYPES <- c("clustering", "phenotype_clustering")
   374	
   375	#' May this requester read the full result JSON for a job of `job_type`?
   376	#'
   377	#' Anonymous/Viewer callers may read full results only for public-operation
   378	#' jobs; Reviewer and above may read any job's full result.
   379	#'
   380	#' @param job_type Character job operation/type.
   381	#' @param user_role Character role from req$user_role, or NULL if anonymous.
   382	#' @return Logical.
   383	# Heavy/admin maintenance job results can carry operational detail (backup
   384	# paths, import diagnostics, standing queries, corpus IDs, upstream errors), so
   385	# their full result_json is Administrator-only even for otherwise-privileged
   386	# Reviewer/Curator roles (LOW-1). This must mirror the canonical maintenance set
   387	# ASYNC_MAINTENANCE_JOB_TYPES (async-job-service.R); the static list is the
   388	# complete fallback for minimal/test envs where that constant is not sourced.
   389	ADMIN_ONLY_RESULT_JOB_TYPES <- c(
   390	  "publication_date_backfill", "publication_refresh", "pubtator_update",
   391	  "pubtator_enrichment_refresh", "pubtatornidd_nightly", "omim_update",
   392	  "hgnc_update", "comparisons_update", "ontology_update", "force_apply_ontology",
   393	  "disease_ontology_mapping_refresh", "nddscore_import", "backup_create",
   394	  "backup_restore"
   395	)
   396	
   397	# Reference the canonical maintenance set at CALL time so the two never drift
   398	# (async-job-service.R is sourced before job-manager.R), unioned with the static
   399	# fallback above for envs that source job-manager.R alone (tests).
   400	admin_only_result_job_types <- function() {
   401	  if (exists("ASYNC_MAINTENANCE_JOB_TYPES", mode = "character")) {
   402	    return(base::union(ADMIN_ONLY_RESULT_JOB_TYPES, ASYNC_MAINTENANCE_JOB_TYPES))
   403	  }
   404	  ADMIN_ONLY_RESULT_JOB_TYPES
   405	}
   406	
   407	can_read_full_job_result <- function(job_type, user_role = NULL) {
   408	  is_admin <- identical(user_role, "Administrator")
   409	  if (!is.null(job_type) && job_type %in% admin_only_result_job_types()) {
   410	    return(is_admin)
   411	  }
   412	  privileged <- !is.null(user_role) &&
   413	    user_role %in% c("Reviewer", "Curator", "Administrator")
   414	  if (privileged) {
   415	    return(TRUE)
   416	  }
   417	  !is.null(job_type) && job_type %in% PUBLIC_FULL_RESULT_JOB_TYPES
   418	}

exec
/bin/bash -lc "rg -n -A 40 -B 8 'generate_ndd_hgnc_ids <-' api/functions/analyses-functions.R; rg -n 'category_filter|clustering_resolve_category_universe|clustering_cached_source_data_version|clustering_result_meta' api/tests/testthat api -g '*.R'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
372-    select(-ncbiTaxonId, -inputGenes, -preferredNames) %>%
373-    arrange(fdr)
374-
375-  # return result
376-  return(enrichment_tibble)
377-}
378-
379-
380:generate_ndd_hgnc_ids <- function() {
381-  pool %>%
382-    dplyr::tbl("ndd_entity_view") %>%
383-    dplyr::arrange(entity_id) %>%
384-    dplyr::filter(ndd_phenotype == 1) %>%
385-    dplyr::select(hgnc_id) %>%
386-    dplyr::collect() %>%
387-    unique()
388-}
389-
390-
391-generate_functional_clusters <- function(algorithm = "leiden") {
392-  genes_from_entity_table <- generate_ndd_hgnc_ids()
393-  gen_string_clust_obj_mem(
394-    genes_from_entity_table$hgnc_id,
395-    algorithm = algorithm
396-  )
397-}
398-
399-
400-generate_functional_cluster_membership <- function(algorithm = "leiden") {
401-  functional_clusters <- generate_functional_clusters(algorithm = algorithm)
402-  if (is.null(functional_clusters) || nrow(functional_clusters) == 0L) {
403-    return(tibble::tibble(cluster = character(), hgnc_id = character()))
404-  }
405-
406-  functional_clusters %>%
407-    dplyr::select(cluster, identifiers) %>%
408-    tidyr::unnest(identifiers) %>%
409-    dplyr::mutate(cluster = paste0("fc_", cluster)) %>%
410-    dplyr::select(cluster, hgnc_id)
411-}
api/tests/testthat/job-endpoint-services-fixtures.R:7:#                                                      category_filter, #574 D2)
api/tests/testthat/job-endpoint-services-fixtures.R:30:#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
api/tests/testthat/job-endpoint-services-fixtures.R:34:#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
api/tests/testthat/job-endpoint-services-fixtures.R:35:#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
api/tests/testthat/job-endpoint-services-fixtures.R:70:#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
api/tests/testthat/job-endpoint-services-fixtures.R:76:  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
api/tests/testthat/job-endpoint-services-fixtures.R:77:    testthat::expect_null(category_filter)
api/tests/testthat/job-endpoint-services-fixtures.R:91:  env$clustering_cached_source_data_version <- function(...) "srcv-test"
api/tests/testthat/test-unit-job-endpoint-services.R:5:# submission-service.R (base coverage only). Its category_filter / provenance /
api/tests/testthat/test-unit-job-endpoint-services.R:139:  expect_false("category_filter" %in% names(store_args$hash_payload))
api/tests/testthat/test-unit-job-endpoint-services.R:181:    # no-arg submits still omit `category_filter` (asserted separately below).
api/tests/testthat/test-unit-job-endpoint-services.R:184:  expect_false("category_filter" %in% names(captured$request_payload))
api/tests/testthat/test-unit-job-endpoint-services.R:187:  # any absent `category_filter`) so the dedup identity stays byte-identical
api/tests/testthat/test-unit-job-endpoint-services.R:191:  expect_false("category_filter" %in% names(captured$hash_payload))
api/tests/testthat/test-unit-job-endpoint-services.R:233:# job-functional-submission-service.R's category_filter / provenance / dedup
api/tests/testthat/test-unit-async-job-handlers.R:5:# .async_job_run_clustering assembles its result meta via clustering_result_meta()
api/tests/testthat/test-unit-clustering-gene-universe.R:3:# `clustering_resolve_category_universe()` resolves the gene set a clustering
api/tests/testthat/test-unit-clustering-gene-universe.R:19:## clustering_cached_source_data_version() TTL cache (#574 D2 review fix)
api/tests/testthat/test-unit-clustering-gene-universe.R:47:test_that("clustering_cached_source_data_version: TTL hit avoids a second underlying fetch", {
api/tests/testthat/test-unit-clustering-gene-universe.R:56:  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R:57:  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R:64:test_that("clustering_cached_source_data_version: TTL expiry (ttl_seconds = 0) forces a refetch", {
api/tests/testthat/test-unit-clustering-gene-universe.R:77:  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
api/tests/testthat/test-unit-clustering-gene-universe.R:78:  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
api/tests/testthat/test-unit-clustering-gene-universe.R:85:test_that("clustering_cached_source_data_version: an error propagates and never poisons the cache", {
api/tests/testthat/test-unit-clustering-gene-universe.R:91:    e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300),
api/tests/testthat/test-unit-clustering-gene-universe.R:107:  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R:113:test_that("clustering_cached_source_data_version: NA_character_ from the underlying fetch is rejected and never cached (Codex review fix)", {
api/tests/testthat/test-unit-clustering-gene-universe.R:126:  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
api/tests/testthat/test-unit-clustering-gene-universe.R:137:  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R:143:test_that("clustering_cached_source_data_version: an empty string from the underlying fetch is rejected and never cached (Codex review fix)", {
api/tests/testthat/test-unit-clustering-gene-universe.R:148:  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
api/tests/testthat/test-unit-clustering-gene-universe.R:195:  r <- e$clustering_resolve_category_universe("Definitive", conn = con)
api/tests/testthat/test-unit-clustering-gene-universe.R:207:  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)
api/tests/testthat/test-unit-clustering-gene-universe.R:220:  r <- e$clustering_resolve_category_universe(NULL, conn = con)
api/tests/testthat/test-unit-clustering-gene-universe.R:232:    e$clustering_resolve_category_universe("Definative", conn = con),
api/tests/testthat/test-unit-clustering-gene-universe.R:246:    e$clustering_resolve_category_universe(list(), conn = con),
api/tests/testthat/test-unit-clustering-gene-universe.R:250:    e$clustering_resolve_category_universe(list("   "), conn = con),
api/tests/testthat/test-unit-clustering-gene-universe.R:269:    e$clustering_resolve_category_universe("Refuted", conn = con), # 0 genes
api/tests/testthat/test-unit-clustering-gene-universe.R:273:    e$clustering_resolve_category_universe("Moderate", conn = con), # 1 gene
api/tests/testthat/test-unit-clustering-gene-universe.R:294:test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
api/tests/testthat/test-unit-clustering-gene-universe.R:297:  expect_null(e$clustering_normalize_category_filter(NULL))
api/tests/testthat/test-unit-clustering-gene-universe.R:298:  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
api/tests/testthat/test-unit-clustering-gene-universe.R:299:  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
api/tests/testthat/test-unit-clustering-gene-universe.R:300:  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
api/tests/testthat/test-unit-clustering-gene-universe.R:302:    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
api/tests/testthat/test-unit-clustering-handler-meta.R:40:  # `clustering_result_meta()` (#574 D3 fix wave 1), the shared helper defined
api/tests/testthat/test-unit-clustering-handler-meta.R:81:      selector = list(kind = "category", category_filter = "Definitive"),
api/tests/testthat/test-integration-clustering-category-submit.R:4:# gene-universe resolver (`clustering_resolve_category_universe()`,
api/tests/testthat/test-integration-clustering-category-submit.R:23:# end-to-end verification (submitting `category_filter` against the running
api/tests/testthat/test-integration-clustering-category-submit.R:51:#' `clustering_resolve_category_universe()`'s own live allowlist check --
api/tests/testthat/test-integration-clustering-category-submit.R:93:test_that("clustering_resolve_category_universe matches a direct MySQL query on the real ndd_entity_view", {
api/tests/testthat/test-integration-clustering-category-submit.R:102:    resolved <- clustering_resolve_category_universe(probe_category, conn = conn)
api/tests/testthat/test-integration-clustering-category-submit.R:119:test_that("clustering_resolve_category_universe rejects an unknown category, naming the allowed set in the message", {
api/tests/testthat/test-integration-clustering-category-submit.R:129:      clustering_resolve_category_universe("Definative", conn = conn),
api/tests/testthat/test-integration-clustering-category-submit.R:142:test_that("clustering_resolve_category_universe(NULL) matches the default all-NDD-genes SELECT", {
api/tests/testthat/test-integration-clustering-category-submit.R:172:    resolved <- clustering_resolve_category_universe(NULL, conn = conn)
api/tests/testthat/test-unit-job-endpoint-services-category.R:3:# Host-runnable unit tests for the #574 (D2) category_filter / provenance /
api/tests/testthat/test-unit-job-endpoint-services-category.R:37:## job-functional-submission-service.R: category_filter (#574 D2)
api/tests/testthat/test-unit-job-endpoint-services-category.R:40:test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:48:    argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive")),
api/tests/testthat/test-unit-job-endpoint-services-category.R:59:test_that("functional clustering: an EMPTY genes array + category_filter still triggers mutual exclusion -> error_400 (Codex review fix)", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:61:  # check), so `{"genes":[], "category_filter":["Definitive"]}` bypassed it
api/tests/testthat/test-unit-job-endpoint-services-category.R:62:  # -- an empty-but-PRESENT `genes` key must still 400 when a category_filter
api/tests/testthat/test-unit-job-endpoint-services-category.R:69:    argsBody = list(genes = list(), category_filter = list("Definitive")),
api/tests/testthat/test-unit-job-endpoint-services-category.R:80:test_that("functional clustering: an explicit-null genes KEY + category_filter still triggers mutual exclusion -> error_400 (Codex round-2 review fix)", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:84:  # `{"genes":null, "category_filter":["Definitive"]}` bypassed the guard and
api/tests/testthat/test-unit-job-endpoint-services-category.R:93:    argsBody = list(genes = NULL, category_filter = list("Definitive")),
api/tests/testthat/test-unit-job-endpoint-services-category.R:105:test_that("functional clustering: an explicit-null genes KEY ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:108:  # value with no `category_filter` at all -- it must still fall through to
api/tests/testthat/test-unit-job-endpoint-services-category.R:132:test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:135:  # behavior for an empty `genes` array with no `category_filter` at all --
api/tests/testthat/test-unit-job-endpoint-services-category.R:159:test_that("functional clustering: an explicit-null category_filter KEY (no genes) coerces to an empty selector and delegates to the resolver (Codex round-5 review fix)", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:160:  # Bug: the branch used `category_supplied <- !is.null(category_filter)`, so a
api/tests/testthat/test-unit-job-endpoint-services-category.R:161:  # present-but-null `category_filter` key (`{"category_filter":null}`) was
api/tests/testthat/test-unit-job-endpoint-services-category.R:164:  # fix. The branch now keys off `"category_filter" %in% names(req$argsBody)`.
api/tests/testthat/test-unit-job-endpoint-services-category.R:169:  # DELEGATES to `clustering_resolve_category_universe()`, which 400s a
api/tests/testthat/test-unit-job-endpoint-services-category.R:182:  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
api/tests/testthat/test-unit-job-endpoint-services-category.R:183:    captured_cf <<- category_filter
api/tests/testthat/test-unit-job-endpoint-services-category.R:187:    argsBody = list(category_filter = NULL),
api/tests/testthat/test-unit-job-endpoint-services-category.R:192:  expect_true("category_filter" %in% names(req$argsBody))
api/tests/testthat/test-unit-job-endpoint-services-category.R:198:test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:202:  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
api/tests/testthat/test-unit-job-endpoint-services-category.R:203:    expect_identical(category_filter, list("Definitive"))
api/tests/testthat/test-unit-job-endpoint-services-category.R:207:    expect_true("category_filter" %in% names(params))
api/tests/testthat/test-unit-job-endpoint-services-category.R:208:    expect_identical(params$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services-category.R:221:  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
api/tests/testthat/test-unit-job-endpoint-services-category.R:227:  expect_identical(captured$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services-category.R:230:  expect_identical(captured$provenance$selector$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services-category.R:236:  # Codex round-3 fix: a category run's hash payload keeps `category_filter`
api/tests/testthat/test-unit-job-endpoint-services-category.R:238:  expect_true("category_filter" %in% names(captured_hash_params))
api/tests/testthat/test-unit-job-endpoint-services-category.R:239:  expect_identical(captured_hash_params$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services-category.R:243:test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:262:  expect_false("category_filter" %in% names(captured_explicit))
api/tests/testthat/test-unit-job-endpoint-services-category.R:264:  expect_null(captured_explicit$provenance$selector$category_filter)
api/tests/testthat/test-unit-job-endpoint-services-category.R:266:  expect_false("category_filter" %in% names(captured_explicit_hash_params))
api/tests/testthat/test-unit-job-endpoint-services-category.R:289:  expect_false("category_filter" %in% names(captured_no_arg))
api/tests/testthat/test-unit-job-endpoint-services-category.R:291:  expect_null(captured_no_arg$provenance$selector$category_filter)
api/tests/testthat/test-unit-job-endpoint-services-category.R:293:  expect_false("category_filter" %in% names(captured_no_arg_hash_params))
api/tests/testthat/test-unit-job-endpoint-services-category.R:307:    env$clustering_cached_source_data_version <- function(...) source_data_version
api/tests/testthat/test-unit-job-endpoint-services-category.R:361:test_that("functional clustering: request_hash is selector-aware for category_filter", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:369:    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
api/tests/testthat/test-unit-job-endpoint-services-category.R:387:  env$clustering_cached_source_data_version <- function(...) stop("boom")
api/functions/clustering-gene-universe.R:6:# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
api/functions/clustering-gene-universe.R:26:clustering_normalize_category_filter <- function(category_filter) {
api/functions/clustering-gene-universe.R:27:  if (is.null(category_filter)) return(NULL)
api/functions/clustering-gene-universe.R:28:  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
api/functions/clustering-gene-universe.R:41:clustering_resolve_category_universe <- function(category_filter, conn = pool) {
api/functions/clustering-gene-universe.R:42:  selector <- clustering_normalize_category_filter(category_filter)
api/functions/clustering-gene-universe.R:62:      "category_filter was supplied but empty; provide at least one active category. Allowed active categories: %s",
api/functions/clustering-gene-universe.R:71:      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
api/functions/clustering-gene-universe.R:87:      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2. Allowed active categories: %s",
api/functions/clustering-gene-universe.R:131:clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
api/functions/clustering-gene-universe.R:144:      "clustering_cached_source_data_version: analysis_snapshot_source_data_version() ",
api/functions/clustering-gene-universe.R:161:clustering_result_meta <- function(base, provenance, weight_channel) {
api/endpoints/jobs_endpoints.R:31:#*   - `category_filter`: an array of curated SysNDD confidence categories
api/endpoints/jobs_endpoints.R:36:#*     when `category_filter` is empty, contains an unknown/inactive value
api/endpoints/jobs_endpoints.R:40:#* Supplying both `genes` and a non-empty `category_filter` is a 400.
api/endpoints/jobs_endpoints.R:43:#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
api/endpoints/jobs_endpoints.R:60:#*   with `category_filter`.
api/endpoints/jobs_endpoints.R:61:#* @param category_filter Optional JSON array of curated SysNDD confidence
api/tests/testthat/job-endpoint-services-fixtures.R:7:#                                                      category_filter, #574 D2)
api/tests/testthat/job-endpoint-services-fixtures.R:30:#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
api/tests/testthat/job-endpoint-services-fixtures.R:34:#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
api/tests/testthat/job-endpoint-services-fixtures.R:35:#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
api/tests/testthat/job-endpoint-services-fixtures.R:70:#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
api/tests/testthat/job-endpoint-services-fixtures.R:76:  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
api/tests/testthat/job-endpoint-services-fixtures.R:77:    testthat::expect_null(category_filter)
api/tests/testthat/job-endpoint-services-fixtures.R:91:  env$clustering_cached_source_data_version <- function(...) "srcv-test"
api/tests/testthat/test-unit-job-endpoint-services.R:5:# submission-service.R (base coverage only). Its category_filter / provenance /
api/tests/testthat/test-unit-job-endpoint-services.R:139:  expect_false("category_filter" %in% names(store_args$hash_payload))
api/tests/testthat/test-unit-job-endpoint-services.R:181:    # no-arg submits still omit `category_filter` (asserted separately below).
api/tests/testthat/test-unit-job-endpoint-services.R:184:  expect_false("category_filter" %in% names(captured$request_payload))
api/tests/testthat/test-unit-job-endpoint-services.R:187:  # any absent `category_filter`) so the dedup identity stays byte-identical
api/tests/testthat/test-unit-job-endpoint-services.R:191:  expect_false("category_filter" %in% names(captured$hash_payload))
api/tests/testthat/test-unit-job-endpoint-services.R:233:# job-functional-submission-service.R's category_filter / provenance / dedup
api/tests/testthat/test-unit-async-job-handlers.R:5:# .async_job_run_clustering assembles its result meta via clustering_result_meta()
api/tests/testthat/test-unit-clustering-handler-meta.R:40:  # `clustering_result_meta()` (#574 D3 fix wave 1), the shared helper defined
api/tests/testthat/test-unit-clustering-handler-meta.R:81:      selector = list(kind = "category", category_filter = "Definitive"),
api/tests/testthat/test-integration-clustering-category-submit.R:4:# gene-universe resolver (`clustering_resolve_category_universe()`,
api/tests/testthat/test-integration-clustering-category-submit.R:23:# end-to-end verification (submitting `category_filter` against the running
api/tests/testthat/test-integration-clustering-category-submit.R:51:#' `clustering_resolve_category_universe()`'s own live allowlist check --
api/tests/testthat/test-integration-clustering-category-submit.R:93:test_that("clustering_resolve_category_universe matches a direct MySQL query on the real ndd_entity_view", {
api/tests/testthat/test-integration-clustering-category-submit.R:102:    resolved <- clustering_resolve_category_universe(probe_category, conn = conn)
api/tests/testthat/test-integration-clustering-category-submit.R:119:test_that("clustering_resolve_category_universe rejects an unknown category, naming the allowed set in the message", {
api/tests/testthat/test-integration-clustering-category-submit.R:129:      clustering_resolve_category_universe("Definative", conn = conn),
api/tests/testthat/test-integration-clustering-category-submit.R:142:test_that("clustering_resolve_category_universe(NULL) matches the default all-NDD-genes SELECT", {
api/tests/testthat/test-integration-clustering-category-submit.R:172:    resolved <- clustering_resolve_category_universe(NULL, conn = conn)
api/functions/async-job-handlers.R:23:# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
api/functions/async-job-handlers.R:121:  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
api/functions/async-job-handlers.R:135:  meta <- clustering_result_meta(
api/tests/testthat/test-unit-job-endpoint-services-category.R:3:# Host-runnable unit tests for the #574 (D2) category_filter / provenance /
api/tests/testthat/test-unit-job-endpoint-services-category.R:37:## job-functional-submission-service.R: category_filter (#574 D2)
api/tests/testthat/test-unit-job-endpoint-services-category.R:40:test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:48:    argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive")),
api/tests/testthat/test-unit-job-endpoint-services-category.R:59:test_that("functional clustering: an EMPTY genes array + category_filter still triggers mutual exclusion -> error_400 (Codex review fix)", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:61:  # check), so `{"genes":[], "category_filter":["Definitive"]}` bypassed it
api/tests/testthat/test-unit-job-endpoint-services-category.R:62:  # -- an empty-but-PRESENT `genes` key must still 400 when a category_filter
api/tests/testthat/test-unit-job-endpoint-services-category.R:69:    argsBody = list(genes = list(), category_filter = list("Definitive")),
api/tests/testthat/test-unit-job-endpoint-services-category.R:80:test_that("functional clustering: an explicit-null genes KEY + category_filter still triggers mutual exclusion -> error_400 (Codex round-2 review fix)", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:84:  # `{"genes":null, "category_filter":["Definitive"]}` bypassed the guard and
api/tests/testthat/test-unit-job-endpoint-services-category.R:93:    argsBody = list(genes = NULL, category_filter = list("Definitive")),
api/tests/testthat/test-unit-job-endpoint-services-category.R:105:test_that("functional clustering: an explicit-null genes KEY ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:108:  # value with no `category_filter` at all -- it must still fall through to
api/tests/testthat/test-unit-job-endpoint-services-category.R:132:test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:135:  # behavior for an empty `genes` array with no `category_filter` at all --
api/tests/testthat/test-unit-job-endpoint-services-category.R:159:test_that("functional clustering: an explicit-null category_filter KEY (no genes) coerces to an empty selector and delegates to the resolver (Codex round-5 review fix)", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:160:  # Bug: the branch used `category_supplied <- !is.null(category_filter)`, so a
api/tests/testthat/test-unit-job-endpoint-services-category.R:161:  # present-but-null `category_filter` key (`{"category_filter":null}`) was
api/tests/testthat/test-unit-job-endpoint-services-category.R:164:  # fix. The branch now keys off `"category_filter" %in% names(req$argsBody)`.
api/tests/testthat/test-unit-job-endpoint-services-category.R:169:  # DELEGATES to `clustering_resolve_category_universe()`, which 400s a
api/tests/testthat/test-unit-job-endpoint-services-category.R:182:  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
api/tests/testthat/test-unit-job-endpoint-services-category.R:183:    captured_cf <<- category_filter
api/tests/testthat/test-unit-job-endpoint-services-category.R:187:    argsBody = list(category_filter = NULL),
api/tests/testthat/test-unit-job-endpoint-services-category.R:192:  expect_true("category_filter" %in% names(req$argsBody))
api/tests/testthat/test-unit-job-endpoint-services-category.R:198:test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:202:  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
api/tests/testthat/test-unit-job-endpoint-services-category.R:203:    expect_identical(category_filter, list("Definitive"))
api/tests/testthat/test-unit-job-endpoint-services-category.R:207:    expect_true("category_filter" %in% names(params))
api/tests/testthat/test-unit-job-endpoint-services-category.R:208:    expect_identical(params$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services-category.R:221:  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
api/tests/testthat/test-unit-job-endpoint-services-category.R:227:  expect_identical(captured$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services-category.R:230:  expect_identical(captured$provenance$selector$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services-category.R:236:  # Codex round-3 fix: a category run's hash payload keeps `category_filter`
api/tests/testthat/test-unit-job-endpoint-services-category.R:238:  expect_true("category_filter" %in% names(captured_hash_params))
api/tests/testthat/test-unit-job-endpoint-services-category.R:239:  expect_identical(captured_hash_params$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services-category.R:243:test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:262:  expect_false("category_filter" %in% names(captured_explicit))
api/tests/testthat/test-unit-job-endpoint-services-category.R:264:  expect_null(captured_explicit$provenance$selector$category_filter)
api/tests/testthat/test-unit-job-endpoint-services-category.R:266:  expect_false("category_filter" %in% names(captured_explicit_hash_params))
api/tests/testthat/test-unit-job-endpoint-services-category.R:289:  expect_false("category_filter" %in% names(captured_no_arg))
api/tests/testthat/test-unit-job-endpoint-services-category.R:291:  expect_null(captured_no_arg$provenance$selector$category_filter)
api/tests/testthat/test-unit-job-endpoint-services-category.R:293:  expect_false("category_filter" %in% names(captured_no_arg_hash_params))
api/tests/testthat/test-unit-job-endpoint-services-category.R:307:    env$clustering_cached_source_data_version <- function(...) source_data_version
api/tests/testthat/test-unit-job-endpoint-services-category.R:361:test_that("functional clustering: request_hash is selector-aware for category_filter", {
api/tests/testthat/test-unit-job-endpoint-services-category.R:369:    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
api/tests/testthat/test-unit-job-endpoint-services-category.R:387:  env$clustering_cached_source_data_version <- function(...) stop("boom")
api/services/job-functional-submission-service.R:28:#' curated-category selection via `category_filter` (resolved through
api/services/job-functional-submission-service.R:29:#' `clustering_resolve_category_universe()`), or -- when neither is supplied
api/services/job-functional-submission-service.R:31:#' `category_filter` are mutually exclusive (400 if both are present). Every
api/services/job-functional-submission-service.R:36:#'   `category_filter` and `req$user$user_id`).
api/services/job-functional-submission-service.R:53:  # `category_filter` are mutually exclusive gene-universe selectors (#574):
api/services/job-functional-submission-service.R:62:  # (`{"genes":null,...}` / `{"genes":[],...}`) and a present `category_filter`
api/services/job-functional-submission-service.R:65:  # `category_filter` is a supplied-empty 400 (in the branch below), never a
api/services/job-functional-submission-service.R:70:  category_key <- "category_filter" %in% body_names
api/services/job-functional-submission-service.R:73:    stop_for_bad_request("Provide either genes or category_filter, not both")
api/services/job-functional-submission-service.R:93:  # from before this feature: `clustering_resolve_category_universe(NULL)`
api/services/job-functional-submission-service.R:101:    # A present category_filter key means a category run. A present-but-null
api/services/job-functional-submission-service.R:107:    cf <- req$argsBody$category_filter
api/services/job-functional-submission-service.R:109:    universe <- clustering_resolve_category_universe(cf)
api/services/job-functional-submission-service.R:114:    universe <- clustering_resolve_category_universe(NULL)
api/services/job-functional-submission-service.R:132:    dup_params$category_filter <- selector_chr
api/services/job-functional-submission-service.R:152:  selector_obj <- list(kind = kind, category_filter = selector_chr)
api/services/job-functional-submission-service.R:175:    clustering_cached_source_data_version(conn = pool),
api/services/job-functional-submission-service.R:251:    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
api/services/job-functional-submission-service.R:259:      meta = clustering_result_meta(
api/services/job-functional-submission-service.R:278:      cache_request_payload$category_filter <- selector_chr
api/services/job-functional-submission-service.R:287:    # category_links, string_id_table[, category_filter]` key order -- it was
api/services/job-functional-submission-service.R:344:    job_params$category_filter <- selector_chr
api/tests/testthat/test-unit-clustering-gene-universe.R:3:# `clustering_resolve_category_universe()` resolves the gene set a clustering
api/tests/testthat/test-unit-clustering-gene-universe.R:19:## clustering_cached_source_data_version() TTL cache (#574 D2 review fix)
api/tests/testthat/test-unit-clustering-gene-universe.R:47:test_that("clustering_cached_source_data_version: TTL hit avoids a second underlying fetch", {
api/tests/testthat/test-unit-clustering-gene-universe.R:56:  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R:57:  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R:64:test_that("clustering_cached_source_data_version: TTL expiry (ttl_seconds = 0) forces a refetch", {
api/tests/testthat/test-unit-clustering-gene-universe.R:77:  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
api/tests/testthat/test-unit-clustering-gene-universe.R:78:  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
api/tests/testthat/test-unit-clustering-gene-universe.R:85:test_that("clustering_cached_source_data_version: an error propagates and never poisons the cache", {
api/tests/testthat/test-unit-clustering-gene-universe.R:91:    e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300),
api/tests/testthat/test-unit-clustering-gene-universe.R:107:  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R:113:test_that("clustering_cached_source_data_version: NA_character_ from the underlying fetch is rejected and never cached (Codex review fix)", {
api/tests/testthat/test-unit-clustering-gene-universe.R:126:  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
api/tests/testthat/test-unit-clustering-gene-universe.R:137:  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R:143:test_that("clustering_cached_source_data_version: an empty string from the underlying fetch is rejected and never cached (Codex review fix)", {
api/tests/testthat/test-unit-clustering-gene-universe.R:148:  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
api/tests/testthat/test-unit-clustering-gene-universe.R:195:  r <- e$clustering_resolve_category_universe("Definitive", conn = con)
api/tests/testthat/test-unit-clustering-gene-universe.R:207:  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)
api/tests/testthat/test-unit-clustering-gene-universe.R:220:  r <- e$clustering_resolve_category_universe(NULL, conn = con)
api/tests/testthat/test-unit-clustering-gene-universe.R:232:    e$clustering_resolve_category_universe("Definative", conn = con),
api/tests/testthat/test-unit-clustering-gene-universe.R:246:    e$clustering_resolve_category_universe(list(), conn = con),
api/tests/testthat/test-unit-clustering-gene-universe.R:250:    e$clustering_resolve_category_universe(list("   "), conn = con),
api/tests/testthat/test-unit-clustering-gene-universe.R:269:    e$clustering_resolve_category_universe("Refuted", conn = con), # 0 genes
api/tests/testthat/test-unit-clustering-gene-universe.R:273:    e$clustering_resolve_category_universe("Moderate", conn = con), # 1 gene
api/tests/testthat/test-unit-clustering-gene-universe.R:294:test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
api/tests/testthat/test-unit-clustering-gene-universe.R:297:  expect_null(e$clustering_normalize_category_filter(NULL))
api/tests/testthat/test-unit-clustering-gene-universe.R:298:  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
api/tests/testthat/test-unit-clustering-gene-universe.R:299:  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
api/tests/testthat/test-unit-clustering-gene-universe.R:300:  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
api/tests/testthat/test-unit-clustering-gene-universe.R:302:    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),

exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-unit-job-endpoint-services.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# tests/testthat/test-unit-job-endpoint-services.R
     2	#
     3	# Host-runnable unit tests for the PUBLIC clustering submission service extracted
     4	# from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
     5	# submission-service.R (base coverage only). Its category_filter / provenance /
     6	# dedup-hash-payload coverage (#574 D2) was split out to
     7	# test-unit-job-endpoint-services-category.R to keep both files under the
     8	# 600-line ceiling after the #574 Codex-review-fix rounds grew that coverage.
     9	# The sibling job-phenotype-submission-service.R coverage lives in
    10	# test-unit-job-endpoint-services-phenotype.R (split out here, #574
    11	# Codex-review-fix pass, to keep both files under the 600-line ceiling after this
    12	# file gained empty-genes/dedup-provenance coverage). The maintenance-submission
    13	# (job-maintenance-submission-service.R) and query-endpoint
    14	# (job-query-endpoint-service.R) services are covered in
    15	# test-unit-job-endpoint-services-maintenance.R. Shared fixtures live in
    16	# job-endpoint-services-fixtures.R (explicitly sourced below by every file in this
    17	# family). Split this way to keep every file under the 600-line ceiling (#535 S6).
    18	#
    19	# Each service is sourced directly into an isolated environment via sys.source()
    20	# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
    21	# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
    22	# async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
    23	# gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
    24	# exercise pure request/response logic without a live DB or mirai daemon pool.
    25	
    26	# Resolve api_dir robustly so the file runs both under the full suite and a single-file
    27	# testthat::test_file(), then source the shared fixtures.
    28	if (exists("get_api_dir")) {
    29	  api_dir <- get_api_dir()
    30	} else {
    31	  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
    32	  if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
    33	    api_dir <- normalizePath(getwd(), mustWork = FALSE)
    34	  }
    35	}
    36	# local = TRUE keeps the shared helpers in this test file's environment (as if defined
    37	# inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
    38	source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)
    39	
    40	## -------------------------------------------------------------------##
    41	## job-functional-submission-service.R
    42	## -------------------------------------------------------------------##
    43	
    44	test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
    45	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    46	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
    47	    entity_id = 1:3,
    48	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    49	    ndd_phenotype = c(1L, 0L, 1L)
    50	  ))
    51	  job_endpoint_stub_all_ndd_universe(env)
    52	  captured <- NULL
    53	  env$check_duplicate_job <- function(operation, params) {
    54	    captured <<- params
    55	    list(duplicate = TRUE, existing_job_id = "dup-1")
    56	  }
    57	  req <- list(argsBody = list(), user = list(user_id = NULL))
    58	  res <- job_endpoint_fake_res()
    59	
    60	  out <- env$svc_job_submit_functional_clustering(req, res)
    61	
    62	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
    63	  expect_equal(captured$algorithm, "leiden")
    64	  expect_equal(res$status, 409)
    65	  expect_equal(out$error, "DUPLICATE_JOB")
    66	  expect_match(res$headers[["Location"]], "/api/jobs/dup-1/status")
    67	})
    68	
    69	job_endpoint_capture_functional_algorithm <- function(algorithm_body) {
    70	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    71	  env$pool <- job_endpoint_functional_pool(env)
    72	  captured <- NULL
    73	  env$check_duplicate_job <- function(operation, params) {
    74	    captured <<- params
    75	    list(duplicate = TRUE, existing_job_id = "dup-1")
    76	  }
    77	  req <- list(argsBody = list(genes = list("HGNC:9"), algorithm = algorithm_body), user = list(user_id = NULL))
    78	  env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
    79	  captured$algorithm
    80	}
    81	
    82	test_that("functional clustering: algorithm input is coerced to a lowercase scalar, invalid falls back to leiden", {
    83	  expect_equal(job_endpoint_capture_functional_algorithm(list("WALKTRAP", "ignored")), "walktrap")
    84	  expect_equal(job_endpoint_capture_functional_algorithm("bogus"), "leiden")
    85	})
    86	
    87	test_that("functional clustering: cache hit stores a completed job without calling create_job", {
    88	  local_mocked_bindings(
    89	    has_cache = function(f) function(...) TRUE,
    90	    .package = "memoise"
    91	  )
    92	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    93	  env$pool <- job_endpoint_functional_pool(env)
    94	  job_endpoint_stub_clustering_provenance(env)
    95	  env$gen_string_clust_obj_mem <- function(genes, algorithm = "leiden") {
    96	    clusters <- tibble::tibble(term_enrichment = list(tibble::tibble(category = "HPO")))
    97	    # Set on the served membership, mirroring what the real STRING resolver
    98	    # attaches (#514 channel observability) -- the cache-hit meta must carry
    99	    # this through as `effective_fingerprint$weight_channel`.
   100	    attr(clusters, "weight_channel") <- "experimental_database"
   101	    clusters
   102	  }
   103	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   104	  store_args <- NULL
   105	  env$async_job_service_store_completed <- function(...) {
   106	    store_args <<- list(...)
   107	    tibble::tibble(job_id = "cached-job-1")
   108	  }
   109	  create_job_called <- FALSE
   110	  env$create_job <- function(...) {
   111	    create_job_called <<- TRUE
   112	  }
   113	  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = 42L))
   114	  res <- job_endpoint_fake_res()
   115	
   116	  out <- env$svc_job_submit_functional_clustering(req, res)
   117	
   118	  expect_false(create_job_called)
   119	  expect_equal(res$status, 202)
   120	  expect_equal(res$headers[["Retry-After"]], "0")
   121	  expect_equal(out$job_id, "cached-job-1")
   122	  expect_equal(out$meta$llm_generation, "snapshot_refresh_owned")
   123	  expect_equal(store_args$submitted_by, 42L)
   124	
   125	  # #574 D2 review fix: the cache-hit `result` (the job's stored, served
   126	  # payload -- distinct from `out`, the submit response) must carry the full
   127	  # provenance block through `meta`, not just the two fields asserted above.
   128	  result_meta <- store_args$result$meta
   129	  expect_equal(result_meta$effective_fingerprint$weight_channel, "experimental_database")
   130	  expect_equal(result_meta$selector$kind, "explicit")
   131	  expect_equal(result_meta$gene_list_sha256, "sha-1") # job_endpoint_stub_clustering_provenance: paste0("sha-", length(genes))
   132	  expect_equal(result_meta$source_data_version, "srcv-test") # job_endpoint_stub_clustering_provenance stub token
   133	
   134	  # Codex round-3 fix: the cache-hit path also derives a provenance-free
   135	  # `hash_payload` for the dedup identity, while `request_payload` (asserted
   136	  # above via `result_meta`) keeps `provenance` in the STORED payload.
   137	  expect_true("provenance" %in% names(store_args$request_payload))
   138	  expect_false("provenance" %in% names(store_args$hash_payload))
   139	  expect_false("category_filter" %in% names(store_args$hash_payload))
   140	})
   141	
   142	test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
   143	  req <- list(argsBody = list(genes = list("HGNC:1"), algorithm = "walktrap"), user = list(user_id = NULL))
   144	
   145	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   146	  env$pool <- job_endpoint_functional_pool(env)
   147	  job_endpoint_stub_clustering_provenance(env)
   148	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   149	  env$async_job_capacity_exceeded <- function(...) TRUE
   150	  env$async_job_active_count <- function(...) 99L
   151	  res <- job_endpoint_fake_res()
   152	  out <- env$svc_job_submit_functional_clustering(req, res)
   153	  expect_equal(res$status, 503)
   154	  expect_equal(res$headers[["Retry-After"]], "60")
   155	  expect_equal(out$error, "CAPACITY_EXCEEDED")
   156	
   157	  env$async_job_capacity_exceeded <- function(...) FALSE
   158	  captured <- NULL
   159	  # Cache-miss path calls `async_job_service_submit()` directly (not
   160	  # `create_job()`, which is arity-guarded at exactly `(operation, params)`)
   161	  # so it can thread a provenance-free `hash_payload` override alongside the
   162	  # full `request_payload`.
   163	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   164	                                            submitted_by = NULL, ...) {
   165	    captured <<- list(
   166	      job_type = job_type,
   167	      request_payload = request_payload,
   168	      hash_payload = hash_payload
   169	    )
   170	    list(job = tibble::tibble(job_id = "new-job-1"))
   171	  }
   172	  res <- job_endpoint_fake_res()
   173	  out <- env$svc_job_submit_functional_clustering(req, res)
   174	  expect_equal(res$status, 202)
   175	  expect_equal(res$headers[["Retry-After"]], "5")
   176	  expect_equal(out$job_id, "new-job-1")
   177	  expect_equal(captured$job_type, "clustering")
   178	  expect_setequal(
   179	    names(captured$request_payload),
   180	    # #574 D2: every submit path now carries a `provenance` block; explicit/
   181	    # no-arg submits still omit `category_filter` (asserted separately below).
   182	    c("genes", "algorithm", "category_links", "string_id_table", "provenance")
   183	  )
   184	  expect_false("category_filter" %in% names(captured$request_payload))
   185	
   186	  # Codex round-3 fix: the dedup HASH payload must exclude `provenance` (and
   187	  # any absent `category_filter`) so the dedup identity stays byte-identical
   188	  # to pre-#574, even though the STORED request payload
   189	  # (`captured$request_payload`, asserted above) still carries `provenance`.
   190	  expect_false("provenance" %in% names(captured$hash_payload))
   191	  expect_false("category_filter" %in% names(captured$hash_payload))
   192	  expect_identical(
   193	    captured$hash_payload,
   194	    list(
   195	      genes = captured$request_payload$genes,
   196	      algorithm = captured$request_payload$algorithm,
   197	      category_links = captured$request_payload$category_links,
   198	      string_id_table = captured$request_payload$string_id_table
   199	    )
   200	  )
   201	})
   202	
   203	test_that("functional clustering: admission throttle runs FIRST, before any DB/cache work", {
   204	  # #535 S6 BLOCKER fix: a throttle block must short-circuit before the cache/dup/DB
   205	  # path so an abusive caller cannot bypass the limit or grow async_jobs via cache
   206	  # hits. The guard returning admitted=FALSE must return its response and touch nothing.
   207	  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = NULL))
   208	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   209	  pool_touched <- FALSE
   210	  env$pool <- structure(list(), class = "trap_pool")
   211	  env$tbl.trap_pool <- function(src, from, ...) {
   212	    pool_touched <<- TRUE
   213	    stop("DB must not be touched when the throttle blocks")
   214	  }
   215	  submit_called <- FALSE
   216	  env$async_job_service_submit <- function(...) {
   217	    submit_called <<- TRUE
   218	    NULL
   219	  }
   220	  env$async_job_submit_admission_guard <- function(req, res) {
   221	    res$status <- 429
   222	    res$setHeader("Retry-After", "42")
   223	    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
   224	  }
   225	  res <- job_endpoint_fake_res()
   226	  out <- env$svc_job_submit_functional_clustering(req, res)
   227	  expect_equal(res$status, 429)
   228	  expect_equal(out$error, "RATE_LIMITED")
   229	  expect_false(pool_touched)
   230	  expect_false(submit_called)
   231	})
   232	
   233	# job-functional-submission-service.R's category_filter / provenance / dedup
   234	# coverage (#574 D2) lives in test-unit-job-endpoint-services-category.R, and
   235	# job-phenotype-submission-service.R coverage lives in
   236	# test-unit-job-endpoint-services-phenotype.R (both split out to keep this
   237	# file under the 600-line ceiling, #574 Codex-review-fix pass).

exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-unit-job-endpoint-services-phenotype.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# tests/testthat/test-unit-job-endpoint-services-phenotype.R
     2	#
     3	# Host-runnable unit tests for job-phenotype-submission-service.R, split out of
     4	# test-unit-job-endpoint-services.R (which covers job-functional-submission-service.R)
     5	# to keep both files under the 600-line ceiling (#535 S6) after the #574 Codex-review
     6	# fixes added coverage to the functional side. Shared fixtures live in
     7	# job-endpoint-services-fixtures.R (explicitly sourced below, mirroring the sibling
     8	# file). See test-unit-job-endpoint-services.R's header for the full split rationale
     9	# (maintenance-submission + query-endpoint services are covered in
    10	# test-unit-job-endpoint-services-maintenance.R).
    11	#
    12	# Each service is sourced directly into an isolated environment via sys.source()
    13	# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
    14	# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
    15	# async_job_active_count, async_job_service_store_completed, gen_mca_clust_obj_mem,
    16	# log_warn, ...) is stubbed in that environment, so the tests exercise pure
    17	# request/response logic without a live DB or mirai daemon pool.
    18	
    19	# Resolve api_dir robustly so the file runs both under the full suite and a single-file
    20	# testthat::test_file(), then source the shared fixtures.
    21	if (exists("get_api_dir")) {
    22	  api_dir <- get_api_dir()
    23	} else {
    24	  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
    25	  if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
    26	    api_dir <- normalizePath(getwd(), mustWork = FALSE)
    27	  }
    28	}
    29	# local = TRUE keeps the shared helpers in this test file's environment (as if defined
    30	# inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
    31	source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)
    32	
    33	## -------------------------------------------------------------------##
    34	## job-phenotype-submission-service.R
    35	## -------------------------------------------------------------------##
    36	
    37	job_endpoint_phenotype_single_entity_pool <- function(env) {
    38	  job_endpoint_fake_pool(env, list(
    39	    ndd_entity_view = tibble::tibble(
    40	      entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1",
    41	      ndd_phenotype = 1L, category = "Definitive"
    42	    ),
    43	    ndd_entity_review = tibble::tibble(
    44	      review_id = 1L, entity_id = 1L, is_primary = 1L, review_approved = 1L
    45	    ),
    46	    ndd_review_phenotype_connect = tibble::tibble(
    47	      review_id = 1L, entity_id = 1L, modifier_id = 1L,
    48	      phenotype_id = "HP:0000001", hpo_mode_of_inheritance_term_name = "AD"
    49	    ),
    50	    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
    51	    phenotype_list = tibble::tibble(phenotype_id = "HP:0000001", HPO_term = "Term1")
    52	  ))
    53	}
    54	
    55	test_that("phenotype clustering: review set is gated on is_primary AND review_approved", {
    56	  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
    57	  env$pool <- job_endpoint_fake_pool(env, list(
    58	    ndd_entity_view = tibble::tibble(
    59	      entity_id = c(1L, 2L), hgnc_id = c("HGNC:1", "HGNC:2"), symbol = c("GENE1", "GENE2"),
    60	      ndd_phenotype = c(1L, 1L), category = c("Definitive", "Definitive")
    61	    ),
    62	    # review_id 1: primary + approved (kept). review_id 2: primary but NOT
    63	    # approved (must be dropped). review_id 3: approved but NOT primary
    64	    # (must be dropped) — the #3/Codex-PR-2 guard this test protects.
    65	    ndd_entity_review = tibble::tibble(
    66	      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L),
    67	      is_primary = c(1L, 1L, 0L), review_approved = c(1L, 0L, 1L)
    68	    ),
    69	    ndd_review_phenotype_connect = tibble::tibble(
    70	      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L), modifier_id = c(1L, 1L, 1L),
    71	      phenotype_id = c("HP:0000001", "HP:0000002", "HP:0000001"),
    72	      hpo_mode_of_inheritance_term_name = c("AD", "AD", "AD")
    73	    ),
    74	    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
    75	    phenotype_list = tibble::tibble(
    76	      phenotype_id = c("HP:0000001", "HP:0000002"), HPO_term = c("Term1", "Term2")
    77	    )
    78	  ))
    79	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
    80	  env$async_job_capacity_exceeded <- function(...) FALSE
    81	  env$async_job_active_count <- function(...) 0L
    82	  captured_params <- NULL
    83	  env$create_job <- function(operation, params) {
    84	    captured_params <<- params
    85	    list(job_id = "job-x", status = "accepted", estimated_seconds = 30)
    86	  }
    87	  req <- list(user = list(user_id = NULL))
    88	  res <- job_endpoint_fake_res()
    89	
    90	  env$svc_job_submit_phenotype_clustering(req, res)
    91	
    92	  # Only review_id 1 (primary + approved) survives the gather step; review 2
    93	  # (unapproved) and review 3 (not primary) must never reach the clustering
    94	  # input, even though review 2 is attached to the same (otherwise-included)
    95	  # entity_id as review 1.
    96	  expect_equal(captured_params$ndd_entity_review_tbl$review_id, 1L)
    97	})
    98	
    99	test_that("phenotype clustering: duplicate job returns 409 with Location", {
   100	  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
   101	  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
   102	  env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = "dup-pheno")
   103	  req <- list(user = list(user_id = NULL))
   104	  res <- job_endpoint_fake_res()
   105	
   106	  out <- env$svc_job_submit_phenotype_clustering(req, res)
   107	
   108	  expect_equal(res$status, 409)
   109	  expect_equal(out$error, "DUPLICATE_JOB")
   110	  expect_match(res$headers[["Location"]], "/api/jobs/dup-pheno/status")
   111	})
   112	
   113	test_that("phenotype clustering: cache hit stores a completed job without calling create_job", {
   114	  local_mocked_bindings(
   115	    has_cache = function(f) function(...) TRUE,
   116	    .package = "memoise"
   117	  )
   118	  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
   119	  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
   120	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   121	  env$gen_mca_clust_obj_mem <- function(df) {
   122	    tibble::tibble(cluster = 1L, identifiers = list(tibble::tibble(entity_id = "1")))
   123	  }
   124	  store_args <- NULL
   125	  env$async_job_service_store_completed <- function(...) {
   126	    store_args <<- list(...)
   127	    tibble::tibble(job_id = "cached-pheno-1")
   128	  }
   129	  create_job_called <- FALSE
   130	  env$create_job <- function(...) create_job_called <<- TRUE
   131	  req <- list(user = list(user_id = 7L))
   132	  res <- job_endpoint_fake_res()
   133	
   134	  out <- env$svc_job_submit_phenotype_clustering(req, res)
   135	
   136	  expect_false(create_job_called)
   137	  expect_equal(res$status, 202)
   138	  expect_equal(out$job_id, "cached-pheno-1")
   139	  expect_equal(store_args$submitted_by, 7L)
   140	})
   141	
   142	test_that("phenotype clustering: capacity guard (503) then a cache miss under capacity (202)", {
   143	  req <- list(user = list(user_id = NULL))
   144	
   145	  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
   146	  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
   147	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   148	  env$async_job_capacity_exceeded <- function(...) TRUE
   149	  env$async_job_active_count <- function(...) 5L
   150	  res <- job_endpoint_fake_res()
   151	  out <- env$svc_job_submit_phenotype_clustering(req, res)
   152	  expect_equal(res$status, 503)
   153	  expect_equal(res$headers[["Retry-After"]], "60")
   154	  expect_equal(out$error, "CAPACITY_EXCEEDED")
   155	
   156	  env$async_job_capacity_exceeded <- function(...) FALSE
   157	  create_job_params <- NULL
   158	  env$create_job <- function(operation, params) {
   159	    create_job_params <<- params
   160	    list(job_id = "new-pheno-1", status = "accepted", estimated_seconds = 30)
   161	  }
   162	  res <- job_endpoint_fake_res()
   163	  out <- env$svc_job_submit_phenotype_clustering(req, res)
   164	  expect_equal(res$status, 202)
   165	  expect_equal(res$headers[["Retry-After"]], "5")
   166	  expect_equal(out$job_id, "new-pheno-1")
   167	  # estimated_seconds is hardcoded to 60 for the new-submit response (matches
   168	  # the original handler, which does not thread through create_job's value).
   169	  expect_equal(out$estimated_seconds, 60)
   170	  expect_setequal(
   171	    names(create_job_params),
   172	    c(
   173	      "ndd_entity_view_tbl", "ndd_entity_review_tbl",
   174	      "ndd_review_phenotype_connect_tbl", "modifier_list_tbl",
   175	      "phenotype_list_tbl", "id_phenotype_ids", "categories"
   176	    )
   177	  )
   178	})
   179	
   180	test_that("phenotype clustering service source keeps is_primary filters paired with review_approved", {
   181	  # Defense-in-depth mirror of test-unit-phenotype-clustering-approved-guard.R
   182	  # (which scans endpoints/jobs_endpoints.R) now that the logic lives here.
   183	  src <- readLines(file.path(get_api_dir(), "services", "job-phenotype-submission-service.R"), warn = FALSE)
   184	  body <- paste(src, collapse = "\n")
   185	  matches <- gregexpr("filter\\([^)]*is_primary[^)]*\\)", body)[[1]]
   186	  if (matches[1] != -1) {
   187	    lens <- attr(matches, "match.length")
   188	    for (i in seq_along(matches)) {
   189	      frag <- substr(body, matches[i], matches[i] + lens[i] - 1)
   190	      expect_true(grepl("review_approved", frag),
   191	                  info = paste("is_primary filter without review_approved:", frag))
   192	    }
   193	  }
   194	  succeed()
   195	})
   196	
   197	test_that("phenotype clustering: admission throttle runs FIRST, before collecting tables", {
   198	  # #535 S6 BLOCKER fix: the phenotype path otherwise collects five whole tables and
   199	  # builds the MCA matrix before admission. A blocked caller must touch nothing.
   200	  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
   201	  pool_touched <- FALSE
   202	  env$pool <- structure(list(), class = "trap_pool")
   203	  env$tbl.trap_pool <- function(src, from, ...) {
   204	    pool_touched <<- TRUE
   205	    stop("DB must not be touched when the throttle blocks")
   206	  }
   207	  create_job_called <- FALSE
   208	  env$create_job <- function(...) {
   209	    create_job_called <<- TRUE
   210	    NULL
   211	  }
   212	  env$async_job_submit_admission_guard <- function(req, res) {
   213	    res$status <- 429
   214	    res$setHeader("Retry-After", "42")
   215	    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
   216	  }
   217	  res <- job_endpoint_fake_res()
   218	  out <- env$svc_job_submit_phenotype_clustering(list(user = list(user_id = NULL)), res)
   219	  expect_equal(res$status, 429)
   220	  expect_equal(out$error, "RATE_LIMITED")
   221	  expect_false(pool_touched)
   222	  expect_false(create_job_called)
   223	})

exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-async-job-handlers.R; nl -ba api/tests/testthat/test-unit-async-job-worker.R | sed -n '1,180p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	library(testthat)
     2	
     3	source_api_file("functions/async-job-force-apply-payload.R", local = FALSE)
     4	source_api_file("functions/async-job-omim-apply.R", local = FALSE)
     5	# .async_job_run_clustering assembles its result meta via clustering_result_meta()
     6	# (clustering-gene-universe.R, #574); source it so the handler resolves it here as
     7	# it does in the worker (bootstrap_load_modules sources it before the handlers).
     8	source_api_file("functions/clustering-gene-universe.R", local = FALSE)
     9	# The eagerly-built async_job_handler_registry list() references provider and
    10	# maintenance handler functions by bare symbol (#346 Wave 4 split), so both
    11	# extracted modules must be sourced BEFORE async-job-handlers.R or the list()
    12	# construction fails with "object '...' not found".
    13	source_api_file("functions/async-job-provider-handlers.R", local = FALSE)
    14	source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE)
    15	source_api_file("functions/async-job-handlers.R", local = FALSE)
    16	
    17	handler_body <- function(fn) {
    18	  paste(deparse(body(fn)), collapse = "\n")
    19	}
    20	
    21	test_that(".async_job_omim_db_write uses the shared ontology refresh helper", {
    22	  body_txt <- handler_body(.async_job_omim_db_write)
    23	
    24	  expect_match(body_txt, "refresh_disease_ontology_set")
    25	  expect_false(grepl("\\bTRUNCATE\\b", body_txt, ignore.case = TRUE))
    26	  expect_false(grepl("DBI::dbBegin|DBI::dbCommit|DBI::dbRollback", body_txt))
    27	})
    28	
    29	test_that(".async_job_run_force_apply_ontology uses helper-managed transaction lifecycle", {
    30	  body_txt <- handler_body(.async_job_run_force_apply_ontology)
    31	
    32	  expect_match(body_txt, "refresh_disease_ontology_set")
    33	  expect_false(grepl("\\bTRUNCATE\\b", body_txt, ignore.case = TRUE))
    34	  expect_false(grepl("DBI::dbRollback\\(sysndd_db\\)", body_txt))
    35	})
    36	
    37	test_that(".async_job_run_omim_update forces a fresh combined ontology build", {
    38	  body_txt <- handler_body(.async_job_run_omim_update)
    39	
    40	  expect_match(body_txt, "process_combine_ontology")
    41	  expect_match(body_txt, "max_file_age\\s*=\\s*0")
    42	})
    43	
    44	test_that("disease_ontology_mapping_refresh handler is registered and callable", {
    45	  entry <- async_job_get_handler("disease_ontology_mapping_refresh")
    46	
    47	  expect_type(entry, "list")
    48	  expect_true(is.function(entry$run))
    49	  expect_identical(entry$cancel_mode, "non_interruptible")
    50	  expect_true(is.function(entry$after_success))
    51	
    52	  body_txt <- handler_body(.async_job_run_disease_ontology_mapping_refresh)
    53	  expect_match(body_txt, "disease_ontology_mapping_refresh_run")
    54	})
    55	
    56	test_that(".async_job_run_omim_update applies additive terms best-effort on block", {
    57	  handler_txt <- handler_body(.async_job_run_omim_update)
    58	  expect_match(handler_txt, "apply_additive_terms_on_block")
    59	  expect_match(handler_txt, "additive_applied")
    60	
    61	  helper_txt <- handler_body(apply_additive_terms_on_block)
    62	  expect_match(helper_txt, "extract_additive_ontology_terms")
    63	  expect_match(helper_txt, "apply_additive_ontology_terms")
    64	  expect_match(helper_txt, "tryCatch")
    65	  expect_match(helper_txt, "async_job_chain_ontology_mapping_refresh")
    66	})
    67	
    68	# ---------------------------------------------------------------------------
    69	# Force-apply payload-shape regression
    70	#
    71	# The blocked omim_update result builds critical_entities / auto_fixes as
    72	# purrr::transpose() lists of records, but get_job_status(result_mode = "full")
    73	# and the worker both decode with jsonlite::fromJSON(simplifyVector = TRUE),
    74	# which collapses an array of uniform objects into a data.frame. The previous
    75	# helpers iterated with vapply(table, \(x) x$field) — over a data.frame that
    76	# walks COLUMNS, so the column access crashed Force Apply with
    77	# "$ operator is invalid for atomic vectors". These tests pin the realistic
    78	# runtime shapes so the regression cannot return silently.
    79	# ---------------------------------------------------------------------------
    80	
    81	# Reproduce the JSON round-trip get_job_status()/the worker apply to the blocked
    82	# result before the force-apply helpers see it.
    83	.force_apply_roundtrip <- function(records) {
    84	  json <- jsonlite::toJSON(records, auto_unbox = TRUE)
    85	  jsonlite::fromJSON(json, simplifyVector = TRUE)
    86	}
    87	
    88	.force_apply_auto_fix_records <- function() {
    89	  tibble::tibble(
    90	    old_version = c("OMIM:125310", "OMIM:244200", "OMIM:305400_1"),
    91	    new_version = c("OMIM:125310_1", "OMIM:244200_1", "OMIM:305400"),
    92	    fix_type = c("id_fingerprint", "name_fingerprint", "name_fingerprint"),
    93	    disease_ontology_name = c("Disease A", "Disease B", "Disease C"),
    94	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    95	    hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0000007", "HP:0001419")
    96	  ) |>
    97	    as.list() |>
    98	    purrr::transpose()
    99	}
   100	
   101	test_that(".async_job_force_apply_auto_fixes handles the simplifyVector data.frame shape", {
   102	  raw <- .force_apply_roundtrip(.force_apply_auto_fix_records())
   103	  # Pin the realistic runtime shape: simplifyVector turns the array of records
   104	  # into a data.frame, which is exactly what crashed the old vapply() helper.
   105	  expect_s3_class(raw, "data.frame")
   106	
   107	  out <- .async_job_force_apply_auto_fixes(raw)
   108	  expect_equal(out$old_version, c("OMIM:125310", "OMIM:244200", "OMIM:305400_1"))
   109	  expect_equal(out$new_version, c("OMIM:125310_1", "OMIM:244200_1", "OMIM:305400"))
   110	})
   111	
   112	test_that(".async_job_force_apply_auto_fixes handles the transpose list-of-records shape", {
   113	  out <- .async_job_force_apply_auto_fixes(.force_apply_auto_fix_records())
   114	  expect_equal(out$old_version, c("OMIM:125310", "OMIM:244200", "OMIM:305400_1"))
   115	  expect_equal(out$new_version, c("OMIM:125310_1", "OMIM:244200_1", "OMIM:305400"))
   116	})
   117	
   118	test_that(".async_job_force_apply_auto_fixes handles empty / null input", {
   119	  out_list <- .async_job_force_apply_auto_fixes(list())
   120	  out_null <- .async_job_force_apply_auto_fixes(NULL)
   121	  expect_equal(nrow(out_list), 0)
   122	  expect_equal(nrow(out_null), 0)
   123	  expect_named(out_list, c("old_version", "new_version"))
   124	})
   125	
   126	test_that(".async_job_force_apply_critical_versions handles the simplifyVector data.frame shape", {
   127	  records <- tibble::tibble(
   128	    disease_ontology_id_version = c("OMIM:169500", "OMIM:301058_1", "OMIM:619701"),
   129	    disease_ontology_name = c("Leukodystrophy", "DEE 90", "Yoon-Bellen syndrome"),
   130	    hgnc_id = c("HGNC:6637", "HGNC:3670", "HGNC:25590"),
   131	    hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0001419", "HP:0000007")
   132	  ) |>
   133	    as.list() |>
   134	    purrr::transpose()
   135	  raw <- .force_apply_roundtrip(records)
   136	  expect_s3_class(raw, "data.frame")
   137	
   138	  out <- .async_job_force_apply_critical_versions(raw)
   139	  expect_equal(out, c("OMIM:169500", "OMIM:301058_1", "OMIM:619701"))
   140	})
   141	
   142	test_that(".async_job_force_apply_critical_versions handles empty / null input", {
   143	  expect_equal(.async_job_force_apply_critical_versions(list()), character(0))
   144	  expect_equal(.async_job_force_apply_critical_versions(NULL), character(0))
   145	})
   146	
   147	# ---------------------------------------------------------------------------
   148	# #346 Wave 4 registry regression: the handler-family split (provider vs.
   149	# maintenance vs. shell) must not change the registered job-type set, which
   150	# handler function backs each job type, its cancel_mode, or its after_success
   151	# hook. Bare-symbol entries are asserted by identity (proves the shell's
   152	# registry list binds the SAME function object the extracted module defines,
   153	# not a re-implemented/forward-declared copy); wrapper-closure entries
   154	# (network_layout_prewarm, analysis_snapshot_refresh, and the passthrough
   155	# factory job types) are asserted by callable shape only, since they are
   156	# intentionally not bare symbols.
   157	# ---------------------------------------------------------------------------
   158	
   159	test_that("async_job_handler_registry has the exact expected job-type set", {
   160	  expected_job_types <- c(
   161	    "clustering", "phenotype_clustering", "ontology_update", "hgnc_update",
   162	    "comparisons_update", "pubtator_update", "pubtator_enrichment_refresh",
   163	    "pubtatornidd_nightly", "disease_ontology_mapping_refresh", "nddscore_import",
   164	    "llm_generation", "network_layout_prewarm", "analysis_snapshot_refresh",
   165	    "backup_create", "backup_restore", "omim_update", "force_apply_ontology",
   166	    "publication_refresh", "publication_date_backfill"
   167	  )
   168	
   169	  expect_equal(sort(names(async_job_handler_registry)), sort(expected_job_types))
   170	})
   171	
   172	test_that("registry entries bind the exact expected handler function by identity", {
   173	  bare_symbol_handlers <- list(
   174	    clustering = .async_job_run_clustering,
   175	    phenotype_clustering = .async_job_run_phenotype_clustering,
   176	    ontology_update = .async_job_run_ontology_update,
   177	    hgnc_update = .async_job_run_hgnc_update,
   178	    pubtator_update = .async_job_run_pubtator,
   179	    pubtator_enrichment_refresh = .async_job_run_pubtator_enrichment,
   180	    pubtatornidd_nightly = .async_job_run_pubtatornidd_nightly,
   181	    disease_ontology_mapping_refresh = .async_job_run_disease_ontology_mapping_refresh,
   182	    nddscore_import = .async_job_run_nddscore_import,
   183	    backup_create = .async_job_run_backup_create,
   184	    backup_restore = .async_job_run_backup_restore,
   185	    omim_update = .async_job_run_omim_update,
   186	    force_apply_ontology = .async_job_run_force_apply_ontology,
   187	    publication_refresh = .async_job_run_publication_refresh,
   188	    publication_date_backfill = .async_job_run_publication_date_backfill
   189	  )
   190	
   191	  for (job_type in names(bare_symbol_handlers)) {
   192	    expect_identical(
   193	      async_job_handler_registry[[job_type]]$run,
   194	      bare_symbol_handlers[[job_type]],
   195	      info = job_type
   196	    )
   197	  }
   198	
   199	  # Wrapper-closure / passthrough-factory job types: callable, not bare-symbol.
   200	  for (job_type in c(
   201	    "comparisons_update", "llm_generation", "network_layout_prewarm", "analysis_snapshot_refresh"
   202	  )) {
   203	    expect_true(is.function(async_job_handler_registry[[job_type]]$run), info = job_type)
   204	  }
   205	})
   206	
   207	test_that("registry entries have the exact expected cancel_mode", {
   208	  expected_cancel_modes <- c(
   209	    clustering = "best_effort",
   210	    phenotype_clustering = "best_effort",
   211	    ontology_update = "non_interruptible",
   212	    hgnc_update = "non_interruptible",
   213	    comparisons_update = "non_interruptible",
   214	    pubtator_update = "best_effort",
   215	    pubtator_enrichment_refresh = "best_effort",
   216	    pubtatornidd_nightly = "non_interruptible",
   217	    disease_ontology_mapping_refresh = "non_interruptible",
   218	    nddscore_import = "non_interruptible",
   219	    llm_generation = "best_effort",
   220	    network_layout_prewarm = "best_effort",
   221	    analysis_snapshot_refresh = "best_effort",
   222	    backup_create = "non_interruptible",
   223	    backup_restore = "non_interruptible",
   224	    omim_update = "non_interruptible",
   225	    force_apply_ontology = "non_interruptible",
   226	    publication_refresh = "best_effort",
   227	    publication_date_backfill = "non_interruptible"
   228	  )
   229	
   230	  for (job_type in names(expected_cancel_modes)) {
   231	    expect_identical(
   232	      async_job_handler_registry[[job_type]]$cancel_mode,
   233	      unname(expected_cancel_modes[job_type]),
   234	      info = job_type
   235	    )
   236	  }
   237	})
   238	
   239	test_that("registry entries have the exact expected after_success hook", {
   240	  noop_job_types <- c(
   241	    "ontology_update", "hgnc_update", "comparisons_update", "pubtator_update",
   242	    "pubtator_enrichment_refresh", "pubtatornidd_nightly",
   243	    "disease_ontology_mapping_refresh", "nddscore_import", "llm_generation",
   244	    "network_layout_prewarm", "analysis_snapshot_refresh", "backup_create",
   245	    "backup_restore", "omim_update", "force_apply_ontology", "publication_refresh",
   246	    "publication_date_backfill"
   247	  )
   248	
   249	  for (job_type in noop_job_types) {
   250	    expect_identical(
   251	      async_job_handler_registry[[job_type]]$after_success,
   252	      .async_job_after_success_noop,
   253	      info = job_type
   254	    )
   255	  }
   256	
   257	  # clustering / phenotype_clustering chain LLM generation via a custom closure,
   258	  # not the noop.
   259	  for (job_type in c("clustering", "phenotype_clustering")) {
   260	    expect_true(is.function(async_job_handler_registry[[job_type]]$after_success), info = job_type)
   261	    expect_false(
   262	      identical(async_job_handler_registry[[job_type]]$after_success, .async_job_after_success_noop),
   263	      info = job_type
   264	    )
   265	  }
   266	})
     1	library(testthat)
     2	library(withr)
     3	library(jsonlite)
     4	library(tibble)
     5	
     6	async_job_worker_runtime_paths <- function() {
     7	  api_dir <- get_api_dir()
     8	  c(
     9	    file.path(api_dir, "functions", "async-job-progress.R"),
    10	    # .async_job_phenotype_matrix() calls phenotype_mca_prep_matrix() (#508 MCA hygiene);
    11	    # load it here so the durable phenotype-clustering handler test resolves it the way
    12	    # load_modules.R does in production (prep is sourced before async-job-handlers.R).
    13	    file.path(api_dir, "functions", "analysis-phenotype-mca-prep.R"),
    14	    # #346 Wave 4: async_job_handler_registry binds provider/maintenance handler
    15	    # functions by bare symbol inside an eagerly-evaluated list(), so both
    16	    # extracted modules must be sourced before async-job-handlers.R here too.
    17	    file.path(api_dir, "functions", "async-job-provider-handlers.R"),
    18	    file.path(api_dir, "functions", "async-job-maintenance-handlers.R"),
    19	    file.path(api_dir, "functions", "clustering-gene-universe.R"),
    20	    file.path(api_dir, "functions", "async-job-handlers.R"),
    21	    file.path(api_dir, "functions", "async-job-worker.R"),
    22	    file.path(api_dir, "functions", "job-progress.R")
    23	  )
    24	}
    25	
    26	load_async_job_worker_runtime <- function() {
    27	  runtime_env <- new.env(parent = globalenv())
    28	  runtime_paths <- async_job_worker_runtime_paths()
    29	
    30	  missing <- runtime_paths[!file.exists(runtime_paths)]
    31	  if (length(missing) > 0) {
    32	    stop(
    33	      "async-job worker runtime files are missing: ",
    34	      paste(basename(missing), collapse = ", ")
    35	    )
    36	  }
    37	
    38	  for (path in runtime_paths) {
    39	    sys.source(path, envir = runtime_env)
    40	  }
    41	
    42	  runtime_env
    43	}
    44	
    45	test_that("async_job_worker_config_from_env reads bounded worker settings", {
    46	  runtime <- load_async_job_worker_runtime()
    47	
    48	  withr::local_envvar(c(
    49	    ASYNC_JOB_LEASE_SECONDS = "75",
    50	    ASYNC_JOB_RUN_LEASE_SECONDS = "600",
    51	    ASYNC_JOB_IDLE_SLEEP_SECONDS = "1.5",
    52	    MAX_JOBS_PER_WORKER = "7",
    53	    MAX_WORKER_LIFETIME = "900",
    54	    ASYNC_JOB_QUEUES = "default,bulk",
    55	    ASYNC_JOB_DRAIN_FILE = "/tmp/sysndd-test-drain"
    56	  ))
    57	
    58	  config <- runtime$async_job_worker_config_from_env()
    59	
    60	  expect_true(is.character(config$worker_id))
    61	  expect_true(nzchar(config$worker_id))
    62	  expect_true(is.character(config$hostname))
    63	  expect_true(nzchar(config$hostname))
    64	  expect_equal(config$lease_seconds, 75L)
    65	  expect_equal(config$job_run_lease_seconds, 600L)
    66	  expect_equal(config$idle_sleep_seconds, 1.5)
    67	  expect_equal(config$max_jobs_per_worker, 7L)
    68	  expect_equal(config$max_worker_lifetime_seconds, 900L)
    69	  expect_equal(config$queues, c("default", "bulk"))
    70	  expect_equal(config$drain_file, "/tmp/sysndd-test-drain")
    71	})
    72	
    73	test_that("create_async_job_progress_reporter updates durable row progress and throttles interim writes", {
    74	  runtime <- load_async_job_worker_runtime()
    75	  calls <- list()
    76	  heartbeat_calls <- list()
    77	
    78	  runtime$async_job_repository_update_progress <- function(job_id, progress_pct = NULL, progress_message = NULL, claim_token, conn = NULL) { # nolint: line_length_linter
    79	    calls[[length(calls) + 1L]] <<- list(
    80	      job_id = job_id,
    81	      progress_pct = progress_pct,
    82	      progress_message = progress_message,
    83	      claim_token = claim_token
    84	    )
    85	    1L
    86	  }
    87	  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
    88	    heartbeat_calls[[length(heartbeat_calls) + 1L]] <<- list(
    89	      job_id = job_id,
    90	      lease_seconds = lease_seconds,
    91	      claim_token = claim_token
    92	    )
    93	    1L
    94	  }
    95	
    96	  runtime$async_job_worker_set_claim_context(
    97	    list(
    98	      job_id = "job-progress",
    99	      claim_token = "claim-progress"
   100	    ),
   101	    worker_config = list(lease_seconds = 90L, job_run_lease_seconds = 300L)
   102	  )
   103	  on.exit(runtime$async_job_worker_clear_claim_context(), add = TRUE)
   104	
   105	  reporter <- runtime$create_async_job_progress_reporter(
   106	    "job-progress",
   107	    throttle_seconds = 60
   108	  )
   109	
   110	  reporter("download", "Downloading source", current = 1, total = 4)
   111	  reporter("download", "Throttled update", current = 2, total = 4)
   112	  reporter("download", "Download complete", current = 4, total = 4)
   113	
   114	  expect_length(calls, 2L)
   115	  expect_equal(calls[[1]]$job_id, "job-progress")
   116	  expect_equal(calls[[1]]$claim_token, "claim-progress")
   117	  expect_equal(calls[[1]]$progress_pct, 25)
   118	  expect_equal(calls[[1]]$progress_message, "Downloading source")
   119	  expect_equal(calls[[2]]$progress_pct, 100)
   120	  expect_equal(calls[[2]]$progress_message, "Download complete")
   121	  expect_length(heartbeat_calls, 2L)
   122	  expect_equal(heartbeat_calls[[1]]$lease_seconds, 300L)
   123	  expect_equal(heartbeat_calls[[1]]$claim_token, "claim-progress")
   124	})
   125	
   126	test_that("async_job_worker_claim_once skips claims during drain and uses repository claim API otherwise", {
   127	  runtime <- load_async_job_worker_runtime()
   128	  state <- runtime$async_job_worker_state()
   129	
   130	  worker_config <- list(
   131	    worker_id = "worker-a",
   132	    hostname = "host-a",
   133	    lease_seconds = 60L,
   134	    idle_sleep_seconds = 0.1,
   135	    max_jobs_per_worker = 5L,
   136	    max_worker_lifetime_seconds = 600L,
   137	    queues = c("default", "bulk")
   138	  )
   139	
   140	  state$draining <- TRUE
   141	  expect_null(runtime$async_job_worker_claim_once(
   142	    state = state,
   143	    worker_config = worker_config,
   144	    claim_fn = function(...) {
   145	      stop("claim should not run while draining")
   146	    }
   147	  ))
   148	
   149	  claim_args <- NULL
   150	  state$draining <- FALSE
   151	  claimed <- runtime$async_job_worker_claim_once(
   152	    state = state,
   153	    worker_config = worker_config,
   154	    claim_fn = function(worker_id, worker_hostname, worker_pid, lease_seconds, queues, conn = NULL) {
   155	      claim_args <<- list(
   156	        worker_id = worker_id,
   157	        worker_hostname = worker_hostname,
   158	        worker_pid = worker_pid,
   159	        lease_seconds = lease_seconds,
   160	        queues = queues
   161	      )
   162	      tibble(
   163	        job_id = "job-claim",
   164	        job_type = "hgnc_update",
   165	        request_payload_json = "{}",
   166	        claim_token = "claim-claim"
   167	      )
   168	    }
   169	  )
   170	
   171	  expect_equal(claimed$job_id[[1]], "job-claim")
   172	  expect_equal(claim_args$worker_id, "worker-a")
   173	  expect_equal(claim_args$worker_hostname, "host-a")
   174	  expect_type(claim_args$worker_pid, "integer")
   175	  expect_equal(claim_args$lease_seconds, 60L)
   176	  expect_equal(claim_args$queues, c("default", "bulk"))
   177	})
   178	
   179	test_that("async_job_worker_heartbeat extends the lease with the current claim token", {
   180	  runtime <- load_async_job_worker_runtime()

exec
/bin/bash -lc "node -e \"const fs=require('fs'); for (const f of ['app/package.json','app/package-lock.json','api/version_spec.json']) JSON.parse(fs.readFileSync(f)); console.log('valid JSON: package.json, package-lock.json, version_spec.json')\"; git diff --word-diff=plain origin/master...HEAD -- app/package.json app/package-lock.json api/version_spec.json; git diff --unified=10 origin/master...HEAD -- AGENTS.md CHANGELOG.md documentation/08-development.qmd" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
valid JSON: package.json, package-lock.json, version_spec.json
diff --git a/api/version_spec.json b/api/version_spec.json
index 86e2b6e6..5efd7ddc 100644
--- a/api/version_spec.json
+++ b/api/version_spec.json
@@ -1,7 +1,7 @@
{
  "title": "SysNDD API",
  "description": "This is the API powering the SysNDD website, allowing programmatic access to the database contents.",
  "version": [-"0.30.0",-]{+"0.30.1",+}
  "contact": {
    "name": "API Support",
    "url": "https://berntpopp.github.io/sysndd/api.html",
diff --git a/app/package-lock.json b/app/package-lock.json
index bcc638de..73e3f535 100644
--- a/app/package-lock.json
+++ b/app/package-lock.json
@@ -1,12 +1,12 @@
{
  "name": "sysndd",
  "version": [-"0.30.0",-]{+"0.30.1",+}
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "sysndd",
      "version": [-"0.30.0",-]{+"0.30.1",+}
      "dependencies": {
        "@popperjs/core": "^2.11.8",
        "@unhead/vue": "^3.1.8",
diff --git a/app/package.json b/app/package.json
index ea8dbd91..5004dbe1 100644
--- a/app/package.json
+++ b/app/package.json
@@ -1,6 +1,6 @@
{
  "name": "sysndd",
  "version": [-"0.30.0",-]{+"0.30.1",+}
  "private": true,
  "type": "module",
  "scripts": {
diff --git a/AGENTS.md b/AGENTS.md
index 7aa9b3e1..e9647c88 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -116,20 +116,22 @@ Analysis-snapshot **releases** are immutable, content-addressed, frozen exports
 
 - **Content-addressing.** `content_digest` (`analysis_release_content_digest()`, `analysis-snapshot-release-manifest.R`) is a SHA-256 over the invariant scientific content only — `manifest_schema_version`, `source_data_version`, and each layer's `{analysis_type, input_hash, payload_hash, reproducibility_hash, dependencies}` — and deliberately **excludes** `created_at`, `title`, and DOI, so recording provenance metadata never changes release identity. `release_id = "asr_" + content_digest[:16]`; the full 64-char digest is stored and insert is guarded against a same-id/different-digest collision (fails loudly rather than colliding).
 - **Public surface is retrieval-only and DB-only.** `GET /api/analysis/releases`, `.../releases/latest`, `.../releases/<release_id>`, `.../releases/<release_id>/manifest.json`, `.../releases/<release_id>/file?path=<file_path>`, and `.../releases/<release_id>/bundle` are unauthenticated, make no external calls, and are covered by the same cheap-route/external-budget isolation guards as the rest of `/api/analysis`. `.../file` resolves by an **exact `(release_id, file_path)` primary-key lookup** — there is no filesystem access and no path-traversal surface; anything not in `analysis_snapshot_release_file` is a 404. Every public read is pinned to `status = 'published'`, so an unknown release id and a draft release id are indistinguishable (both 404) — drafts are never public. `latest` is declared **before** the dynamic `<release_id>` route (the `/status/_list` shadowing lesson applies here too).
 - **The build is a fail-closed 400 gate**, not a best-effort export (`analysis_snapshot_release_build()`, `functions/analysis-snapshot-release.R`). In order: (1) each registry layer must be `status_code == "available"` from `analysis_snapshot_get_public()`; (2) a **hard** partition-coherence re-check (`analysis_snapshot_assert_partition_coherent(..., require_coherence = TRUE)`) runs on every cluster layer regardless of the `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` env downgrade — `available` only proves freshness/schema/source-version, not #514 coherence, so a release can never freeze an incoherent-but-`public_ready` snapshot; (3) each cluster layer must have a stored reproducibility bundle (the snapshot builder makes it best-effort, the release makes it mandatory); (4) all layers must share one `source_data_version`, and the correlation layer's dependency lineage must match the pinned functional + phenotype `snapshot_id`+`payload_hash` (the #571/#572 dependency gate); (5) a **TOCTOU guard** — the same per-preset advisory lock the axis refresh holds, plus a fresh pre-insert re-read of every layer immediately before persisting — closes the race between the initial read and the insert. Any gate failure is `stop_for_bad_request()` (400; there is no 409 class), naming the failing layer/reason. A rebuild whose content is **identical** to an existing release is not an error: it returns the existing head idempotently (200, no duplicate row); a genuinely new content set is 201.
 - **Hashing facts, precisely.** Every file carries its **own** `content_sha256`. For each cluster layer, `sha256(reproducibility.json) == reproducibility_hash` **exactly** — this uses the raw pre-gzip bundle bytes (`analysis_reproducibility_decode_raw()`, `memDecompress(..., asChar = TRUE)`), never `analysis_reproducibility_decode()`, whose `jsonlite::fromJSON()` + re-serialize round-trip drops the bundle's full-precision (`digits = NA`) contract and breaks the equality. By contrast, `payload_hash`/`input_hash`/`snapshot_id` are recorded in the manifest as cross-checkable **lineage anchors** against the live `meta.snapshot.{payload_hash,input_hash,snapshot_id}` on the corresponding `/api/analysis/*` endpoint — they are **not** equal to a hash of the release's own `payload.json` file (the stored payload round-trips through `DECIMAL(8,7)`/`DECIMAL(8,5)` DB columns before the release freezes it, so a reconstructed byte-for-byte match is neither guaranteed nor attempted).
 - **DOI is additive, outside the hash.** `PATCH /api/admin/analysis/releases/<id>/doi` (Administrator) records `{zenodo_record_id, zenodo_record_url, version_doi, concept_doi}` — any subset, an omitted field is left unchanged, never nulled out — and never touches `content_digest`/`manifest_sha256`; recording a DOI after publish changes zero release bytes.
 - **Never pruned.** A published release is permanent; `DELETE /api/admin/analysis/releases/<id>` only works on a `draft`. `analysis_snapshot_prune()` (`analysis-snapshot-repository.R`) now skips any `snapshot_id` still referenced by an `analysis_snapshot_release_member` row (`analysis_release_referenced_snapshot_ids()`), so a snapshot pinned by a release keeps serving its live reproducibility endpoint too — even though release integrity never depends on the source snapshot surviving (each release is self-contained).
 - **Build is synchronous, admin, DB-only — the worker is NOT required.** Unlike snapshot refresh, `POST /api/admin/analysis/releases` runs inline on the API request (`analysis_snapshot_release_build()` is called directly from the endpoint, not submitted as an async job): no clustering recompute, no external calls, no LLM, no cache writes. A release can be built even if the worker is down, as long as public-ready snapshots already exist.
 - **`GET .../releases/<release_id>/file?path=<file_path>` uses a query param, not a nested path segment**, because Plumber 1.3.2 has no `<path:.*>` wildcard — only named, typed, single-segment path params (`<id>`, `<id:int>`) exist, so a nested archive path (e.g. `functional_clusters/payload.json`) cannot be expressed as a URL path segment. The manifest's `files[].path` values are the caller's index into this route.
 
+`POST /api/jobs/clustering/submit` can resolve its clustering gene universe from a curated confidence category instead of an explicit gene list (#574). `clustering_resolve_category_universe()` (`api/functions/clustering-gene-universe.R`) does entity-level resolution: a gene qualifies if it has >=1 `ndd_phenotype == 1` entity whose `category` is in the selector, filtered directly against `ndd_entity_view` — **never** `select_network_gene_category()` (the gene-level display-label aggregator used for node coloring only, not a universe filter). `category_filter` absent → the byte-identical existing default (`generate_ndd_hgnc_ids()`, cache parity preserved); supplied-but-empty → 400; validated live against `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded category strings, no interpolated SQL) with the allowed active set named in the error **message**; a resolved universe under 2 genes → 400. `genes` and a non-empty `category_filter` are mutually exclusive (400). The durable job payload gains a normalized `category_filter` key — and the dedup identity becomes selector-aware — **only** for category selectors, so explicit-genes and no-arg submits keep byte-identical `request_hash`/payload shape to pre-#574. Every submit records provenance — `selector` (`kind`: `explicit`|`category`|`all_ndd`), `resolved_gene_count`, `gene_list_sha256`, an **intended** fingerprint (STRING cache fingerprint + score threshold + algorithm + seed), and a cached fail-closed `source_data_version` — in the payload; the result `meta` additionally carries an **effective** `effective_fingerprint` (the STRING `weight_channel` the computed result actually used), on both a cache-hit response (`svc_job_submit_functional_clustering()`) and a worker-run job (`.async_job_run_clustering()` in `async-job-handlers.R`), so a silent exp+db→combined-score fallback is visible either way. Results from this endpoint (category-filtered or not) are ephemeral job results and are **never** `public_ready` — distinct from the public `analysis_snapshot_*` layer above.
+
 ### Cluster-analysis statistical soundness (#508–#512)
 
 The two-axis cluster analysis (phenotype MCA/HCPC and functional STRING/Leiden) and the served "function is modular, phenotype is a continuum" cross-axis interpretation are made mathematically sound and self-reproducing. `validation_schema_version` is `"2.0"`, `ANALYSIS_SNAPSHOT_SCHEMA_VERSION` is `"1.2"`. The **key lever**: `analysis_snapshot_payload_hash` deliberately excludes `partition_validation` (`analysis-snapshot-builder.R`), so everything in the validation block is **additive** — new metrics never change `cluster_hash` and never invalidate LLM summaries. Only changes to cluster **membership** (the #508 MCA filter, the #509 `kk=Inf` consolidation, the #510 channel switch) change `cluster_hash` and therefore require a coordinated forced snapshot refresh + LLM regeneration.
 
 - **Common cross-axis footing (#511)** lives in `api/functions/analysis-null-models.R` (worker/heavy-path only; registered in `bootstrap/load_modules.R`). Both axes report a **unit-free, null-calibrated `separation_z`** so the contrast is like-for-like instead of raw-silhouette-vs-raw-modularity: functional = **modularity z-score** vs a **degree-preserving configuration-model null** (`modularity_null_zscore`: `igraph::rewire(keeping_degseq)` + permuted weight multiset, re-restricting **both** the observed graph and every replicate to the largest connected component, and **re-detecting communities with the identical seeded Leiden on each replicate** — the Guimerà/Sales-Pardo/Amaral re-optimized null, so `modularity_z` benchmarks against the modularity a degree-matched random graph genuinely reaches rather than being a near-tautological Q-vs-0 test; **never** revert this to carrying the observed labels onto the null, which inflates the z by orders of magnitude); phenotype = **silhouette z-score** vs a **label-permutation null** (`silhouette_null_zscore`). The `modularity_null_zscore` `recluster` argument selects the flavour: the functional axis passes a Leiden closure (re-optimized, `null_model = "…_reoptimized"`), while the phenotype `shared_modularity_z` passes **none** and holds the external MCA/HCPC labels **fixed** on the kNN null (`"…_fixed_labels"`) because the graph cannot re-derive that partition (it is an attribute-assortativity test). Additionally a **dip test of unimodality** (`dip_unimodality`, Hartigan; optional `diptest` dependency — degrades to `NA` if absent) is reported on both axes' pairwise-distance distributions as a **corroborating** continuum-vs-modular signal (`dip_p` small → discrete; large → continuum); the functional dip runs on **continuous weighted shortest-path distances** (edge distance `1 - combined_score/1000`), NOT integer hop counts, so it is not a discreteness artifact, and because pairwise distances are mutually dependent `dip_p` corroborates rather than strictly proves. The SAME modularity-z index is also reported for phenotype on a mutual-kNN graph of the MCA coords (`knn_similarity_graph` → `shared_modularity_z`). Never resurrect a direct silhouette-vs-modularity comparison.
 - **Functional axis is text-mining-free (#510).** `build_string_subgraph` (`analyses-functions.R`) prefers a graph whose weights are recombined from the STRING **experimental + database** channels only (STRING's probabilistic-OR formula in `analysis-string-channels.R`, `string_recompute_score`/`string_expdb_subgraph`), dropping the text-mining/co-mention channel that would make a "molecular pathways organize NDD" claim partly restate co-study structure (≈540 of ~3200 NDD genes had STRING edges **only** via text-mining). The exp+db score is carried in the existing `combined_score` edge attribute (so the weighted-Leiden/modularity plumbing is unchanged) plus a `weight_channel` graph attribute; it **falls back** to the STRINGdb combined graph when the compact edge file is absent, so a fresh checkout still functions. That file, `data/9606.protein.links.expdb.v11.5.min400.txt.gz`, is a gitignored runtime artifact built by `api/scripts/build-string-expdb.R` from the ~115 MB `9606.protein.links.detailed.v11.5.txt.gz` download; the **worker needs `data.table` and this file**. STRING lists every undirected pair in **both** directions, so `string_expdb_subgraph()` **`simplify()`-es** the induced graph at read (and the builder writes only the canonical `protein1 < protein2` half) — otherwise every edge is double-counted (2× `giant_component$n_edges`, a doubled reproducibility edge list, and disagreement with the simple STRINGdb-combined fallback); weighted Leiden/modularity are invariant to the uniform duplication, so the partition is unchanged. The **headline `modularity`** is the full-partition Q; its **z-score, degree-preserving null, giant-component counts** (`giant_component`: isolates/components/retention), and the reconcilable **`modularity_lcc`** (the exact Q the z is computed on) are all on the **largest connected component** (disconnected fragments are trivial "perfect communities" that inflate Q); an env-gated (`ANALYSIS_REPORT_COMBINED_SENSITIVITY`) `modularity_combined_score` reports how much Q changes with text-mining included.
 - **Phenotype MCA feature hygiene + real consolidation (#508/#509).** The shared helper `phenotype_mca_prep_matrix()` (`analysis-phenotype-mca-prep.R`) applies the hygiene once, and **every** phenotype-matrix path calls it — `generate_phenotype_cluster_input` (served snapshot + validator) **and** `.async_job_phenotype_matrix` (the interactive/durable `/api/jobs/phenotype_clustering` job) — so the interactive product can never diverge from the public snapshot (keep them on the one helper; do not re-inline the prep). It drops the HPO subtree root `HP:0000118` and any organ-system term outside the prevalence band (`PHENOTYPE_MCA_PREVALENCE_MIN`/`MAX`, default 0.05–0.95 — near-universal/near-rare terms add null/outlier MCA dimensions that mechanically depress separation) and recodes presence from `{"yes",NA}` to explicit `{absent,present}` factors (an all-NA character column is **not** treated as a presence column, so a fully-missing supplementary column can't be misclassified and shift the `quali.sup`/`quanti.sup` indices). `gen_mca_clust_obj` uses `HCPC(kk = Inf, consol = TRUE)` because FactoMineR ≥2.13 **silently disables consolidation when `kk != Inf`** (`if ((kk != Inf) & (consol == TRUE)) { warning(...); consol <- FALSE }`) — the old `kk = 50` claimed consolidation but never ran it; do **not** reintroduce a finite `kk` while asserting consolidation. The `k_selection_curve` re-runs the exact served procedure (`gen_mca_clust_obj(cutpoint = k)`, which re-seeds internally) at each k and anchors at the true data-driven HCPC k (exposed via an attribute), so `k_selection_curve[hcpc_nb_clust] == mean_silhouette` by construction; `k_decision_curve` reports the relative within-cluster inertia loss HCPC actually uses to pick k (so it is explicit k was not chosen by silhouette), and `silhouette_interpretation` bands the value honestly (≤0.25 Kaufman–Rousseeuw → `no_substantial_structure_continuum`).
 - **Reproducibility bundle (#512).** Migration `041_add_analysis_reproducibility.sql` adds `analysis_snapshot_reproducibility` (gzip canonical-JSON bundle + SHA-256 `reproducibility_hash`). `analysis-reproducibility.R` builds/decodes/persists the bundle (functional: full LCC edge list + complete membership incl. sub-`min_size`; phenotype: MCA coords + assignment + params) and the builder attaches it (also excluded from `payload_hash`). Two DB-only public routes — `GET /api/analysis/functional_clustering/reproducibility` and `.../phenotype_clustering/reproducibility` (routes in `analysis_endpoints.R`, handler `analysis_reproducibility_endpoint`) — let a consumer recompute modularity/silhouette from published artifacts. **Wave-2 activation runbook** (after these membership-changing changes deploy): restart the worker (worker-executed code changed), `POST /api/admin/analysis/snapshots/refresh?analysis_type=functional_clusters&force=true` and `…phenotype_clusters&force=true`, then `POST /api/llm/regenerate?cluster_type=functional&force=true` and `…phenotype&force=true` (cluster hashes changed, so summaries must regenerate). Spec/plan: `.planning/superpowers/specs|plans/2026-07-05-cluster-soundness-508-512-*.md`.
 
 ### Cluster-snapshot cache coherence & self-healing analysis deploys (#514)
diff --git a/CHANGELOG.md b/CHANGELOG.md
index 48651d8b..d3058047 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -1,18 +1,65 @@
 # Changelog
 
 All notable changes to SysNDD are documented in this file.
 
 The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (loosely, in the `0.x` line — additive changes land as patch bumps while the public API still stabilises).
 
 ## [Unreleased]
 
+## [0.30.1] — 2026-07-19
+
+Category-selected gene universes for functional clustering (#574). The public
+clustering submit endpoint can now resolve its gene universe from a curated
+SysNDD confidence category instead of an explicit gene list, with an auditable
+provenance record on every job.
+
+### Added
+
+- **`category_filter` on `POST /api/jobs/clustering/submit`**: an optional JSON
+  body array (e.g. `["Definitive"]`) selecting the clustering gene universe
+  from curated confidence categories. Resolution is **entity-level** against
+  `ndd_entity_view` — a gene qualifies if it has ≥1 `ndd_phenotype = 1` entity
+  whose status `category` is in the selector — via the new
+  `clustering_resolve_category_universe()`
+  (`api/functions/clustering-gene-universe.R`). Omitting the selector keeps the
+  byte-identical pre-#574 default (all NDD genes via `generate_ndd_hgnc_ids()`,
+  cache parity preserved); supplying both `genes` and `category_filter` is a
+  400.
+- **Provenance on every clustering job**: each submit records a `selector`
+  (`kind`: `explicit` / `category` / `all_ndd`), `resolved_gene_count`,
+  a sort-order-independent `gene_list_sha256`, an **intended** analysis
+  fingerprint (STRING cache fingerprint + score threshold + algorithm + seed),
+  and a cached, fail-closed `source_data_version` in the durable payload; the
+  result `meta` additionally carries an **effective** `effective_fingerprint`
+  (the STRING `weight_channel` the computed result actually used), on both the
+  cache-hit response and a worker-run job, so a silent exp+db→combined-score
+  fallback is observable either way.
+
+### Changed
+
+- Clustering-job **dedup identity is now selector-aware**: the normalized
+  `category_filter` enters the durable payload and preflight dedup key **only**
+  for category selectors, so `["Definitive"]` and `["Definitive","Moderate"]`
+  that happen to resolve to the same current genes are not collapsed, while
+  explicit-`genes` and no-arg submits keep a byte-identical `request_hash` and
+  payload shape to pre-#574. Category-filtered results remain ephemeral job
+  results and are **never** `public_ready`.
+
+### Validated
+
+- The selector is validated live against
+  `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded
+  category strings, no interpolated SQL): an unknown/inactive category, a
+  supplied-but-empty selector, or a resolved universe under 2 genes is a 400
+  naming the allowed active categories in the error message.
+
 ## [0.30.0] — 2026-07-18
 
 Immutable public analysis-snapshot releases (#573, Slice A). SysNDD's derived
 cluster analyses (functional STRING/Leiden clusters, phenotype MCA/HCPC
 clusters, and the phenotype-functional cross-cluster correlation) can now be
 frozen into content-addressed, independently-verifiable releases — the same
 "immutable dataset release" pattern already used for NDDScore/Zenodo, applied
 to the analysis layer.
 
 ### Added
diff --git a/documentation/08-development.qmd b/documentation/08-development.qmd
index c56d803e..1c553653 100644
--- a/documentation/08-development.qmd
+++ b/documentation/08-development.qmd
@@ -185,20 +185,35 @@ mkdir -p /tmp/asr-verify && tar -xzf bundle.tar.gz -C /tmp/asr-verify
 
 `sha256sum -c checksums.sha256` must report every extracted file as `OK`; the standalone `manifest.json` download's own SHA-256 must equal the release head's `manifest_sha256` field.
 
 **Manifest schema summary** (`manifest_schema_version` `"1.0"`, built by `analysis_release_build_manifest()` in `api/functions/analysis-snapshot-release-manifest.R`): `release_id`, `release_version`, `title`, `created_at`, `license`, `scope_statement`, `generator` (API/schema/cluster-logic versions), `source` (`source_data_version` + DB release label), `layers[]` (one entry per pinned snapshot: `analysis_type`, `snapshot_id`, `parameter_hash`, `schema_version`, `input_hash`, `payload_hash`, `reproducibility_hash`, and — for the correlation layer — `dependencies` naming both cluster axes' `snapshot_id`/`payload_hash`), `files[]` (`path`, `sha256`, `bytes`, excluding `manifest.json` and `checksums.sha256` themselves, which cannot describe their own checksum), and `content_digest`.
 
 **Two hashing facts that are easy to get backwards:**
 
 - `sha256(reproducibility.json)` (each cluster layer's file) equals its `reproducibility_hash` **exactly** — this is the raw pre-gzip bundle bytes read via `analysis_reproducibility_decode_raw()`, never the parsing `analysis_reproducibility_decode()`, whose `jsonlite::fromJSON()` round-trip drops the bundle's full-precision contract and breaks the equality.
 - `payload_hash` (and `input_hash`, `snapshot_id`) recorded per layer in the manifest is a **lineage anchor**, cross-checkable against the live `meta.snapshot.{payload_hash,input_hash,snapshot_id}` block on the corresponding `/api/analysis/*` endpoint — it is **not** the SHA-256 of that layer's own `payload.json` file in the bundle (that file has its own, separately-computed `content_sha256` in `files[]`). The stored payload round-trips through DB column types before a release freezes it, so a byte-for-byte reconstruction of the original in-memory payload is neither guaranteed nor attempted.
 
+### Category-Selected Clustering (#574)
+
+`POST /api/jobs/clustering/submit` accepts an optional `category_filter` JSON body array (e.g. `["Definitive"]`) as an alternative gene-universe selector to the existing `genes` array; supplying neither keeps the pre-#574 default all-NDD-genes universe, and supplying both is a 400. A category run resolves entity-level against the live `ndd_entity_view` (any gene with >=1 `ndd_phenotype = 1` entity in a selected category qualifies) and validates the selector against the live active `ndd_entity_status_categories_list` — an unknown/inactive category or a universe under 2 genes is a 400 naming the allowed active categories. Category runs are NOT `public_ready`; they are the same ephemeral job-result mechanism as an explicit-`genes` submit, just with a curated-category-derived universe.
+
+Every submit (cache-hit or worker-run) records selector/fingerprint provenance in the durable job payload and result `meta` — see `api/functions/clustering-gene-universe.R` (resolver), `api/services/job-functional-submission-service.R` (cache-hit meta), and `.async_job_run_clustering()` in `api/functions/async-job-handlers.R` (worker-run meta) for the exact shape. Focused checks while iterating:
+
+```bash
+cd api
+Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-clustering-gene-universe.R')"
+Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-clustering-handler-meta.R')"
+Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-endpoint-services.R')"
+```
+
+`test-integration-clustering-category-submit.R` exercises the resolver against a real, populated `sysndd_db_test` `ndd_entity_view` and skips cleanly on the empty CI/local default test DB.
+
 ### LLM Model Configuration
 
 Local Gemini summary generation uses `gemini-3.5-flash` by default. Set `GEMINI_MODEL` to override the runtime model for API and worker processes; if it is unset, the API reads `gemini_model` from `api/config.yml`, then falls back to the built-in default.
 
 Unknown model IDs are rejected before any Gemini call. During local provider rollout testing, add comma-separated IDs to `GEMINI_ALLOWED_MODELS_EXTRA`; those models are accepted with an operator warning in the admin LLM configuration panel. Do not use the allowlist for shut-down catalog models such as `gemini-3-pro-preview`.
 
 ### GeneNetworks fCoSE Layout Prewarm
 
 The GeneNetworks browser graph uses precomputed Cytoscape/fCoSE display positions when available. The worker computes the layout artifact with the Node helper in `api/layout/` and stores it under `/app/cache/network_layouts`.
 

exec
/bin/bash -lc "git diff --unified=0 origin/master...HEAD -- ':(exclude).planning/**' | rg -n '"'^'"\\+["'^+]|''^-[''^-]'"' | sed -n '1,1400p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
6:+`POST /api/jobs/clustering/submit` can resolve its clustering gene universe from a curated confidence category instead of an explicit gene list (#574). `clustering_resolve_category_universe()` (`api/functions/clustering-gene-universe.R`) does entity-level resolution: a gene qualifies if it has >=1 `ndd_phenotype == 1` entity whose `category` is in the selector, filtered directly against `ndd_entity_view` — **never** `select_network_gene_category()` (the gene-level display-label aggregator used for node coloring only, not a universe filter). `category_filter` absent → the byte-identical existing default (`generate_ndd_hgnc_ids()`, cache parity preserved); supplied-but-empty → 400; validated live against `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded category strings, no interpolated SQL) with the allowed active set named in the error **message**; a resolved universe under 2 genes → 400. `genes` and a non-empty `category_filter` are mutually exclusive (400). The durable job payload gains a normalized `category_filter` key — and the dedup identity becomes selector-aware — **only** for category selectors, so explicit-genes and no-arg submits keep byte-identical `request_hash`/payload shape to pre-#574. Every submit records provenance — `selector` (`kind`: `explicit`|`category`|`all_ndd`), `resolved_gene_count`, `gene_list_sha256`, an **intended** fingerprint (STRING cache fingerprint + score threshold + algorithm + seed), and a cached fail-closed `source_data_version` — in the payload; the result `meta` additionally carries an **effective** `effective_fingerprint` (the STRING `weight_channel` the computed result actually used), on both a cache-hit response (`svc_job_submit_functional_clustering()`) and a worker-run job (`.async_job_run_clustering()` in `async-job-handlers.R`), so a silent exp+db→combined-score fallback is visible either way. Results from this endpoint (category-filtered or not) are ephemeral job results and are **never** `public_ready` — distinct from the public `analysis_snapshot_*` layer above.
13:+## [0.30.1] — 2026-07-19
15:+Category-selected gene universes for functional clustering (#574). The public
16:+clustering submit endpoint can now resolve its gene universe from a curated
17:+SysNDD confidence category instead of an explicit gene list, with an auditable
18:+provenance record on every job.
20:+### Added
22:+- **`category_filter` on `POST /api/jobs/clustering/submit`**: an optional JSON
23:+  body array (e.g. `["Definitive"]`) selecting the clustering gene universe
24:+  from curated confidence categories. Resolution is **entity-level** against
25:+  `ndd_entity_view` — a gene qualifies if it has ≥1 `ndd_phenotype = 1` entity
26:+  whose status `category` is in the selector — via the new
27:+  `clustering_resolve_category_universe()`
28:+  (`api/functions/clustering-gene-universe.R`). Omitting the selector keeps the
29:+  byte-identical pre-#574 default (all NDD genes via `generate_ndd_hgnc_ids()`,
30:+  cache parity preserved); supplying both `genes` and `category_filter` is a
31:+  400.
32:+- **Provenance on every clustering job**: each submit records a `selector`
33:+  (`kind`: `explicit` / `category` / `all_ndd`), `resolved_gene_count`,
34:+  a sort-order-independent `gene_list_sha256`, an **intended** analysis
35:+  fingerprint (STRING cache fingerprint + score threshold + algorithm + seed),
36:+  and a cached, fail-closed `source_data_version` in the durable payload; the
37:+  result `meta` additionally carries an **effective** `effective_fingerprint`
38:+  (the STRING `weight_channel` the computed result actually used), on both the
39:+  cache-hit response and a worker-run job, so a silent exp+db→combined-score
40:+  fallback is observable either way.
42:+### Changed
44:+- Clustering-job **dedup identity is now selector-aware**: the normalized
45:+  `category_filter` enters the durable payload and preflight dedup key **only**
46:+  for category selectors, so `["Definitive"]` and `["Definitive","Moderate"]`
47:+  that happen to resolve to the same current genes are not collapsed, while
48:+  explicit-`genes` and no-arg submits keep a byte-identical `request_hash` and
49:+  payload shape to pre-#574. Category-filtered results remain ephemeral job
50:+  results and are **never** `public_ready`.
52:+### Validated
54:+- The selector is validated live against
55:+  `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded
56:+  category strings, no interpolated SQL): an unknown/inactive category, a
57:+  supplied-but-empty selector, or a resolved universe under 2 genes is a 400
58:+  naming the allowed active categories in the error message.
65:+    # Category-selected clustering gene-universe resolver (#574). Depends on
66:+    # generate_ndd_hgnc_ids() (analyses-functions.R, above) and
67:+    # stop_for_bad_request() (core/errors.R, sourced after function_files by
68:+    # this same bootstrap_load_modules() call) -- registered before the
69:+    # submission service that will consume it.
70:+    "functions/clustering-gene-universe.R",
76:-#* Submits an async job to compute functional clustering via STRING-db.
77:+#* Submits an async job to compute functional clustering via STRING-db. The
78:+#* clustering gene universe (#574) is resolved from one of three mutually
79:+#* exclusive JSON body selectors:
80:+#*   - `genes`: an explicit array of HGNC ids to cluster.
81:+#*   - `category_filter`: an array of curated SysNDD confidence categories
82:+#*     (e.g. `["Definitive"]`); resolved entity-level (>=1 NDD entity in a
83:+#*     selected category, `ndd_phenotype = 1`) against the live
84:+#*     `ndd_entity_view`, validated against the live active
85:+#*     `ndd_entity_status_categories_list`. A category run rejects with 400
86:+#*     when `category_filter` is empty, contains an unknown/inactive value
87:+#*     (the allowed active set is named in the error), or resolves fewer
88:+#*     than 2 genes.
89:+#*   - neither: the existing default all-NDD-genes universe.
90:+#* Supplying both `genes` and a non-empty `category_filter` is a 400.
91:+#*
92:+#* Every submit records selector/fingerprint provenance -- `selector`
93:+#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
94:+#* category runs), `resolved_gene_count`, `gene_list_sha256`,
95:+#* `intended_fingerprint`, and `source_data_version` -- in the durable job
96:+#* payload; the job result `meta` additionally carries `effective_fingerprint`
97:+#* (the STRING `weight_channel` actually observed on the computed result),
98:+#* recorded on both a cache-hit (immediate) response and a worker-run
99:+#* (cache-miss) job.
100:+#*
101:+#* Results from this endpoint (including category-filtered runs) are never
102:+#* `public_ready` -- they are ephemeral job results, distinct from the public
103:+#* `analysis_snapshot_*` layer.
104:+#*
106:+#* @param genes Optional JSON array of explicit HGNC ids. Mutually exclusive
107:+#*   with `category_filter`.
108:+#* @param category_filter Optional JSON array of curated SysNDD confidence
109:+#*   categories (e.g. `["Definitive"]`). Mutually exclusive with `genes`.
110:+#* @param algorithm Optional clustering algorithm string, `"leiden"`
111:+#*   (default) or `"walktrap"`.
117:+# NOTE: .async_job_run_clustering assembles its result meta via
118:+# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
119:+# worker/API entrypoint sources that module via bootstrap_load_modules() before
120:+# this file; a direct-source test env must source it too (as the async-job tests do).
122:+  # #574 D3: the cheap-path selector/fingerprint provenance the submit
123:+  # service (job-functional-submission-service.R) recorded in the payload.
124:+  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
125:+  # FALSE) so a worker-run job for those still completes normally.
126:+  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
128:+  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
129:+  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
130:+  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
131:+  # path), then the request's cheap-path `provenance` (selector/
132:+  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
133:+  # source_data_version) when present, then the `effective_fingerprint` --
134:+  # only knowable now that `clusters` has actually been computed -- so a
135:+  # silent exp+db -> combined-score STRING fallback on a worker-run job is
136:+  # visible in the stored result too, not just a cache hit's.
137:+  # gene_count is the DISTINCT gene count, matching the cache-hit path's
138:+  # `resolved_count <- length(unique(genes_list))` (job-functional-submission-
139:+  # service.R) -- for `["HGNC:1","HGNC:1"]` a raw `length(genes)` reported 2
140:+  # here while the cache-hit path reported 1 for the identical payload
141:+  # (Codex round-2 review fix). This never dedups the payload `genes` list
142:+  # itself or changes `nrow(clusters)`, only the reported count.
143:+  meta <- clustering_result_meta(
144:+    list(
145:+      algorithm = algorithm,
146:+      gene_count = length(unique(genes)),
147:+      cluster_count = nrow(clusters),
148:+      cache_hit = FALSE
149:+    ),
150:+    provenance,
151:+    attr(clusters, "weight_channel")
152:+  )
155:-    meta = list(
156:-      algorithm = algorithm,
157:-      gene_count = length(genes),
158:-      cluster_count = nrow(clusters)
159:-    )
160:+    meta = meta
166:+#' @param hash_payload Optional named list or JSON payload string. When
167:+#'   supplied, the dedup `request_hash` is computed over THIS payload instead
168:+#'   of `request_payload`, while `request_payload_json` (the durably stored
169:+#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
170:+#'   `request_payload` exactly as before, so existing callers are unaffected.
171:+#'   Used by clustering submits (#574) to exclude time-varying `provenance`
172:+#'   metadata from the dedup identity while still persisting it.
174:-  conn = NULL
175:+  conn = NULL,
176:+  hash_payload = NULL
178:-  request_hash <- async_job_service_request_hash(job_type, payload_json)
179:+  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
180:+  request_hash <- async_job_service_request_hash(job_type, hash_payload_json)
182:+#' @param hash_payload Optional named list or JSON payload string. When
183:+#'   supplied, the dedup `request_hash` is computed over THIS payload instead
184:+#'   of `request_payload`, while `request_payload_json` (the durably stored
185:+#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
186:+#'   `request_payload` exactly as before, so existing callers are unaffected.
188:-  conn = NULL
189:+  conn = NULL,
190:+  hash_payload = NULL
192:+  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
194:-      request_hash = async_job_service_request_hash(job_type, payload_json),
195:+      request_hash = async_job_service_request_hash(job_type, hash_payload_json),
202:+# api/functions/clustering-gene-universe.R
203:+#
204:+# Category-selected clustering gene-universe resolver (#574 D1).
205:+#
206:+# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
207:+# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
208:+# universe from curated SysNDD confidence categories instead of the default
209:+# "all NDD genes" set. This file builds ONLY the resolver + provenance
210:+# helpers; the submit service and durable handler wiring is done later.
211:+#
212:+# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
213:+# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
214:+# same gene also has OTHER-category entities. This mirrors
215:+# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
216:+# added `category %in% selector` filter -- it deliberately does NOT use
217:+# `select_network_gene_category()`, which is a gene-level display-label
218:+# aggregator for node coloring, not a universe filter.
219:+#
220:+# Category validation is live against `ndd_entity_status_categories_list
221:+# WHERE is_active = 1` -- no hardcoded category strings, and no category
222:+# string is interpolated into SQL (dbplyr `%in%` + an allowlist pre-check).
224:+# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
225:+# selector returns character(0), which the resolver rejects with 400 -- it must
226:+# never fall through to the all-NDD default.
227:+clustering_normalize_category_filter <- function(category_filter) {
228:+  if (is.null(category_filter)) return(NULL)
229:+  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
230:+  vals <- vals[nzchar(vals)]
231:+  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
232:+  sort(unique(vals))
233:+}
235:+clustering_gene_list_sha256 <- function(hgnc_ids) {
236:+  digest::digest(
237:+    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
238:+    algo = "sha256", serialize = FALSE
239:+  )
240:+}
242:+clustering_resolve_category_universe <- function(category_filter, conn = pool) {
243:+  selector <- clustering_normalize_category_filter(category_filter)
245:+  if (is.null(selector)) {
246:+    # Absent -> preserve the exact current default ordering for cache parity.
247:+    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
248:+    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
249:+  }
251:+  # Any PRESENT selector (including supplied-but-empty) needs the allowed
252:+  # active-category set for its 400 message, so this fetch runs for every
253:+  # present-selector path -- not just the unknown-category branch below.
254:+  active <- conn %>%
255:+    dplyr::tbl("ndd_entity_status_categories_list") %>%
256:+    dplyr::filter(is_active == 1) %>%
257:+    dplyr::select(category) %>%
258:+    dplyr::collect() %>%
259:+    dplyr::pull(category)
261:+  if (length(selector) == 0L) {
262:+    stop_for_bad_request(sprintf(
263:+      "category_filter was supplied but empty; provide at least one active category. Allowed active categories: %s",
264:+      paste(sort(active), collapse = ", ")
265:+    ))
266:+  }
268:+  unknown <- setdiff(selector, active)
269:+  if (length(unknown) > 0L) {
270:+    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
271:+    stop_for_bad_request(sprintf(
272:+      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
273:+      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
274:+    ))
275:+  }
277:+  hgnc_ids <- conn %>%
278:+    dplyr::tbl("ndd_entity_view") %>%
279:+    dplyr::arrange(entity_id) %>%
280:+    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
281:+    dplyr::select(hgnc_id) %>%
282:+    dplyr::collect() %>%
283:+    unique() %>%
284:+    dplyr::pull(hgnc_id)
286:+  if (length(hgnc_ids) < 2L) {
287:+    stop_for_bad_request(sprintf(
288:+      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2. Allowed active categories: %s",
289:+      paste(selector, collapse = ","), length(hgnc_ids), paste(sort(active), collapse = ", ")
290:+    ))
291:+  }
292:+  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
293:+}
295:+# Module-level (survives across requests within the same process) cache for
296:+# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
297:+# public tables and changes rarely (only when the snapshot builder's source
298:+# view moves), so a short-TTL process cache avoids paying that cost on every
299:+# clustering submit while still self-refreshing.
300:+.clustering_source_data_version_cache <- new.env(parent = emptyenv())
302:+#' Predicate: is `v` a valid source-data-version value?
303:+#'
304:+#' The fail-closed contract requires a single non-NA, non-empty character
305:+#' scalar. Anything else (`NULL`, `NA_character_`, `""`, a non-character
306:+#' value, or a non-scalar) must never be cached or served as provenance
307:+#' (Codex review fix -- the TTL cache previously cached/returned an invalid
308:+#' underlying value verbatim).
309:+.clustering_valid_source_version <- function(v) {
310:+  is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
311:+}
313:+#' Cached, fail-closed read of the current analysis source-data version.
314:+#'
315:+#' D2 (#574) provenance helper: the clustering submit service calls this
316:+#' AFTER admission/dedup, only when it is actually about to build a durable
317:+#' payload. Refetches once `ttl_seconds` has elapsed since the last
318:+#' successful read. Deliberately does NOT wrap
319:+#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
320:+#' PROPAGATES to the caller (never cached, never coerced to NA), so a
321:+#' transient DB problem fails the submit closed (503) instead of recording
322:+#' broken provenance. The fetched value is additionally validated by
323:+#' `.clustering_valid_source_version()`: an invalid value (NA/empty/
324:+#' non-scalar) is likewise NEVER cached or returned -- it `stop()`s instead,
325:+#' so the caller's `tryCatch` maps it to the same 503 PROVENANCE_UNAVAILABLE
326:+#' path as a hard fetch error.
327:+#'
328:+#' @param conn DB connection/pool. Defaults to the package-global `pool`.
329:+#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
330:+#' @return character(1) source data version.
331:+#' @export
332:+clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
333:+  now <- Sys.time()
334:+  cached_at <- .clustering_source_data_version_cache$cached_at
335:+  cached_value <- .clustering_source_data_version_cache$value
336:+  if (!is.null(cached_at) && .clustering_valid_source_version(cached_value) &&
337:+        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
338:+    return(cached_value)
339:+  }
341:+  value <- analysis_snapshot_source_data_version(conn = conn)
343:+  if (!.clustering_valid_source_version(value)) {
344:+    stop(
345:+      "clustering_cached_source_data_version: analysis_snapshot_source_data_version() ",
346:+      "returned an invalid (NULL/NA/empty/non-scalar) value; refusing to cache or serve it"
347:+    )
348:+  }
350:+  .clustering_source_data_version_cache$value <- value
351:+  .clustering_source_data_version_cache$cached_at <- now
352:+  value
353:+}
355:+# Assemble the clustering result `meta`: base fields + the cheap-path provenance
356:+# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
357:+# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
358:+# observed post-compute. Shared by the cache-hit path
359:+# (job-functional-submission-service.R) and the worker-run/durable handler
360:+# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
361:+# shapes cannot drift apart by hand-copied edits.
362:+clustering_result_meta <- function(base, provenance, weight_channel) {
363:+  c(base,
364:+    if (!is.null(provenance)) provenance else list(),
365:+    list(effective_fingerprint = list(weight_channel = weight_channel)))
366:+}
372:-#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm` and
373:-#'   `req$user$user_id`).
374:+#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
375:+#' curated-category selection via `category_filter` (resolved through
376:+#' `clustering_resolve_category_universe()`), or -- when neither is supplied
377:+#' -- the existing default all-NDD-genes universe. `genes` and
378:+#' `category_filter` are mutually exclusive (400 if both are present). Every
379:+#' submit records selector + fingerprint provenance in the durable payload
380:+#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
381:+#'
382:+#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
383:+#'   `category_filter` and `req$user$user_id`).
385:-  # Connection objects cannot cross process boundaries
386:-  genes_list <- NULL
387:-  if (!is.null(req$argsBody$genes)) {
388:-    genes_list <- req$argsBody$genes
389:+  # Connection objects cannot cross process boundaries. `genes` and
390:+  # `category_filter` are mutually exclusive gene-universe selectors (#574):
391:+  # an explicit gene list, a curated-category selection, or (both absent) the
392:+  # existing default all-NDD-genes universe.
393:+  genes_in <- req$argsBody$genes
394:+  has_genes <- !is.null(genes_in) && length(genes_in) > 0
396:+  # Selector presence is gated on JSON KEY PRESENCE (`names(req$argsBody)`), not
397:+  # value-nullness or length: `!is.null()` cannot distinguish an ABSENT key from
398:+  # an explicit JSON `null` (both parse to NULL in R). So a present `genes` key
399:+  # (`{"genes":null,...}` / `{"genes":[],...}`) and a present `category_filter`
400:+  # key each drive their guard regardless of value (Codex rounds 2 & 4). Mutual
401:+  # exclusion 400s when BOTH keys are present; a present-but-null/empty
402:+  # `category_filter` is a supplied-empty 400 (in the branch below), never a
403:+  # silent fall-through to the all-NDD default. `has_genes` (value-based,
404:+  # non-empty) still selects the explicit-genes branch.
405:+  body_names <- names(req$argsBody)
406:+  genes_key <- "genes" %in% body_names
407:+  category_key <- "category_filter" %in% body_names
409:+  if (genes_key && category_key) {
410:+    stop_for_bad_request("Provide either genes or category_filter, not both")
412:-  # If no genes provided, use default (all NDD genes)
413:-  # This matches current functional_clustering endpoint behavior
414:-  if (is.null(genes_list) || length(genes_list) == 0) {
415:-    genes_list <- pool %>%
416:-      dplyr::tbl("ndd_entity_view") %>%
417:-      dplyr::arrange(entity_id) %>%
418:-      dplyr::filter(ndd_phenotype == 1) %>%
419:-      dplyr::select(hgnc_id) %>%
420:-      dplyr::collect() %>%
421:-      unique() %>%
422:-      dplyr::pull(hgnc_id)
423:+  # Resolve the clustering gene universe + selector provenance (#574). The
424:+  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
425:+  # from before this feature: `clustering_resolve_category_universe(NULL)`
426:+  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
427:+  # so cache parity (memoise key = gene set + algorithm) is preserved.
428:+  selector_chr <- NULL
429:+  if (has_genes) {
430:+    genes_list <- as.character(unlist(genes_in))
431:+    kind <- "explicit"
432:+  } else if (category_key) {
433:+    # A present category_filter key means a category run. A present-but-null
434:+    # value is supplied-but-empty (a NULL would otherwise hit the resolver's
435:+    # absent->default branch), so it is coerced to an empty selector here and
436:+    # delegated to the resolver -- the resolver's supplied-empty branch 400s
437:+    # it (with the allowed active-category set in the message), keeping the
438:+    # 400 message construction in the single resolver source of truth.
439:+    cf <- req$argsBody$category_filter
440:+    if (is.null(cf)) cf <- list()
441:+    universe <- clustering_resolve_category_universe(cf)
442:+    genes_list <- universe$hgnc_ids
443:+    selector_chr <- universe$selector
444:+    kind <- "category"
445:+  } else {
446:+    universe <- clustering_resolve_category_universe(NULL)
447:+    genes_list <- universe$hgnc_ids
448:+    kind <- "all_ndd"
450:-  # Check for duplicate job (include algorithm in check)
451:-  dup_check <- check_duplicate_job("clustering", list(genes = genes_list, algorithm = algorithm))
452:+  # Check for duplicate job (include algorithm in check). The selector is
453:+  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
454:+  # submits keep the pre-#574 dedup identity byte-identical.
455:+  dup_params <- list(genes = genes_list, algorithm = algorithm)
456:+  if (!is.null(selector_chr)) {
457:+    dup_params$category_filter <- selector_chr
458:+  }
459:+  dup_check <- check_duplicate_job("clustering", dup_params)
461:+  # Cheap-path provenance (no expensive query yet). `selector_obj` records
462:+  # WHICH universe was resolved; `intended_fingerprint` records the STRING
463:+  # cache identity + fixed clustering params this submit intends to run
464:+  # with. The *effective* fingerprint (e.g. the STRING weight channel a
465:+  # computed result actually used) is only knowable from a computed result,
466:+  # so it is recorded separately in the cache-hit result meta below.
467:+  selector_obj <- list(kind = kind, category_filter = selector_chr)
468:+  intended_fingerprint <- list(
469:+    string_cache_fingerprint = analysis_string_cache_fingerprint(),
470:+    score_threshold = 400L,
471:+    algorithm = algorithm,
472:+    seed = 42L
473:+  )
474:+  gene_sha <- clustering_gene_list_sha256(genes_list)
475:+  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
476:+  # count must agree with it, so it is computed from the SAME dedup -- an
477:+  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
478:+  # not report a resolved count that disagrees with a singleton sha256. This
479:+  # never dedups the payload `genes` list itself (`genes_list` stays
480:+  # byte-identical to the raw request) -- only the reported COUNT (Codex
481:+  # review fix).
482:+  resolved_count <- length(unique(genes_list))
484:+  # Source-data version: a CACHED, fail-closed read, fetched only now that a
485:+  # payload is actually about to be built -- its backing view runs global
486:+  # counts/joins, so it must never run before admission/dedup. A lookup
487:+  # failure must never silently record NA/broken provenance; fail the
488:+  # request closed instead.
489:+  src_ver <- tryCatch(
490:+    clustering_cached_source_data_version(conn = pool),
491:+    error = function(e) e
492:+  )
493:+  if (inherits(src_ver, "error")) {
494:+    res$status <- 503L
495:+    return(list(
496:+      error = "PROVENANCE_UNAVAILABLE",
497:+      message = "Snapshot source-data version unavailable; retry shortly."
498:+    ))
499:+  }
501:+  provenance <- list(
502:+    selector = selector_obj,
503:+    resolved_gene_count = resolved_count,
504:+    gene_list_sha256 = gene_sha,
505:+    intended_fingerprint = intended_fingerprint,
506:+    source_data_version = src_ver
507:+  )
510:+    # Splice the base cache-hit fields with `provenance` (already assembled
511:+    # above as selector/resolved_gene_count/gene_list_sha256/
512:+    # intended_fingerprint/source_data_version) via the shared
513:+    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
514:+    # re-listing the same fields as duplicate literals -- keeps this shape in
515:+    # lockstep with the worker-run handler's result meta by construction.
516:+    # `effective_fingerprint` is only knowable from the computed result
517:+    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
519:-      meta = list(
520:-        algorithm = algorithm,
521:-        gene_count = length(genes_list),
522:-        cluster_count = nrow(cached_clusters),
523:-        cache_hit = TRUE
524:+      meta = clustering_result_meta(
525:+        list(
526:+          algorithm = algorithm,
527:+          gene_count = resolved_count,
528:+          cluster_count = nrow(cached_clusters),
529:+          cache_hit = TRUE
530:+        ),
531:+        provenance,
532:+        attr(cached_clusters, "weight_channel")
534:+    cache_request_payload <- list(
535:+      genes = genes_list,
536:+      algorithm = algorithm,
537:+      category_links = category_links,
538:+      string_id_table = string_id_table,
539:+      provenance = provenance
540:+    )
541:+    if (!is.null(selector_chr)) {
542:+      cache_request_payload$category_filter <- selector_chr
543:+    }
544:+    # Dedup identity EXCLUDES provenance (Codex round 3): `provenance`
545:+    # carries a time-varying `source_data_version` and STRING cache
546:+    # `intended_fingerprint`, so hashing the full payload would make the
547:+    # active-job uniqueness guard admit duplicate concurrent clustering work
548:+    # across a deploy/cache-TTL change and break the byte-identical
549:+    # explicit/no-arg `request_hash` contract predating #574. Removing the
550:+    # `provenance` key preserves the leading `genes, algorithm,
551:+    # category_links, string_id_table[, category_filter]` key order -- it was
552:+    # appended last, so deleting it does not reorder the rest.
553:+    cache_hash_payload <- cache_request_payload
554:+    cache_hash_payload$provenance <- NULL
556:-      request_payload = list(
557:-        genes = genes_list,
558:-        algorithm = algorithm,
559:-        category_links = category_links,
560:-        string_id_table = string_id_table
561:-      ),
562:+      request_payload = cache_request_payload,
564:-      priority = 50L
565:+      priority = 50L,
566:+      hash_payload = cache_hash_payload
568:-  result <- create_job(
569:-    operation = "clustering",
570:-    params = list(
571:-      genes = genes_list,
572:-      algorithm = algorithm,
573:-      category_links = category_links,
574:-      string_id_table = string_id_table
575:-    )
576:+  job_params <- list(
577:+    genes = genes_list,
578:+    algorithm = algorithm,
579:+    category_links = category_links,
580:+    string_id_table = string_id_table,
581:+    provenance = provenance
584:-  # Check capacity
585:-  if (!is.null(result$error)) {
586:-    res$status <- 503
587:-    res$setHeader("Retry-After", as.character(result$retry_after))
588:-    return(result)
589:+  if (!is.null(selector_chr)) {
590:+    job_params$category_filter <- selector_chr
592:+  # See the cache-hit branch above: dedup identity EXCLUDES provenance so the
593:+  # active-job uniqueness guard is not defeated by its time-varying fields,
594:+  # and explicit/no-arg submits stay byte-identical to pre-#574.
595:+  #
596:+  # `create_job()` carries a deliberately guarded 2-arg contract
597:+  # (`operation`, `params`) -- it cannot take a hash override. This path
598:+  # calls `async_job_service_submit()` directly instead (mirroring the
599:+  # cache-hit branch above, which already calls
600:+  # `async_job_service_store_completed()` directly for the same reason), so
601:+  # `hash_payload` can diverge from the stored `request_payload` without
602:+  # touching `create_job()`'s contract.
603:+  hash_params <- job_params
604:+  hash_params$provenance <- NULL
605:+  submitted <- async_job_service_submit(
606:+    job_type = "clustering",
607:+    request_payload = job_params,
608:+    hash_payload = hash_params,
609:+    submitted_by = req$user$user_id %||% NULL
610:+  )
611:+  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL
613:-  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
614:+  res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
616:-    job_id = result$job_id,
617:-    status = result$status,
618:-    estimated_seconds = result$estimated_seconds,
619:-    status_url = paste0("/api/jobs/", result$job_id, "/status")
620:+    job_id = job_id,
621:+    status = "accepted",
622:+    estimated_seconds = 30,
623:+    status_url = paste0("/api/jobs/", job_id, "/status")
629:-# Shared fixtures for the job-endpoint-service unit tests, split across two files
630:+# Shared fixtures for the job-endpoint-service unit tests, split across four files
632:-#   - test-unit-job-endpoint-services.R              (functional + phenotype submission)
633:+#   - test-unit-job-endpoint-services.R              (functional submission)
634:+#   - test-unit-job-endpoint-services-category.R     (functional submission:
635:+#                                                      category_filter, #574 D2)
636:+#   - test-unit-job-endpoint-services-phenotype.R    (phenotype submission)
638:-# Both files EXPLICITLY source() this file at the top so they run standalone under a
639:+# All four files EXPLICITLY source() this file at the top so they run standalone under a
641:+#'
642:+#' Also sources `functions/clustering-gene-universe.R` (#574 D1/D3) into `env` so
643:+#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
644:+#' `job-functional-submission-service.R`'s cache-hit path -- is available for real
645:+#' (a pure list-assembly function, safe to source unstubbed). Individual tests still
646:+#' stub the DB/cache-touching siblings from that same file
647:+#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
648:+#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
649:+#' this sourcing only supplies defaults those stubs override.
651:+  sys.source(file.path(get_api_dir(), "functions", "clustering-gene-universe.R"), envir = env)
653:+#' Fake pool for job-functional-submission-service.R tests: always includes
654:+#' `non_alt_loci_set` (the STRING-id pre-fetch table every submit path reads),
655:+#' and optionally an `ndd_entity_view` for tests that exercise the all-NDD
656:+#' default universe. Shared by test-unit-job-endpoint-services.R and
657:+#' test-unit-job-endpoint-services-category.R.
658:+job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
659:+  tables <- list(
660:+    non_alt_loci_set = tibble::tibble(
661:+      symbol = c("A", "B"),
662:+      hgnc_id = c("HGNC:1", "HGNC:3"),
663:+      STRING_id = c("9606.P1", "9606.P2")
664:+    )
665:+  )
666:+  if (!is.null(ndd_entity_view)) {
667:+    tables$ndd_entity_view <- ndd_entity_view
668:+  }
669:+  job_endpoint_fake_pool(env, tables)
670:+}
672:+#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
673:+#' (#574 D2): reads `ndd_phenotype == 1` rows straight off `env$pool`'s fake
674:+#' `ndd_entity_view`, mirroring what the real resolver's NULL branch
675:+#' (`generate_ndd_hgnc_ids()`) would compute -- without needing the real
676:+#' function (and its DB-query internals) sourced into these isolated envs.
677:+job_endpoint_stub_all_ndd_universe <- function(env) {
678:+  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
679:+    testthat::expect_null(category_filter)
680:+    tbl <- env$pool$tables$ndd_entity_view
681:+    hgnc_ids <- unique(dplyr::pull(dplyr::filter(tbl, ndd_phenotype == 1), hgnc_id))
682:+    list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids))
683:+  }
684:+}
686:+#' Cheap provenance stubs (#574 D2): every submit path that reaches past dedup
687:+#' now computes `intended_fingerprint`/`gene_list_sha256`/`source_data_version`
688:+#' regardless of selector kind, so any test reaching that far needs these
689:+#' three bare globals stubbed even when it does not care about their values.
690:+job_endpoint_stub_clustering_provenance <- function(env) {
691:+  env$analysis_string_cache_fingerprint <- function() "fp-test"
692:+  env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
693:+  env$clustering_cached_source_data_version <- function(...) "srcv-test"
694:+}
702:+# api/tests/testthat/test-integration-clustering-category-submit.R
703:+#
704:+# Real-MySQL integration coverage for the category-selected clustering
705:+# gene-universe resolver (`clustering_resolve_category_universe()`,
706:+# api/functions/clustering-gene-universe.R, #574 D1/D3). Complements the
707:+# DB-free unit tests in test-unit-clustering-gene-universe.R (which use an
708:+# in-memory RSQLite fixture) with assertions against the REAL `sysndd_db_test`
709:+# MySQL `ndd_entity_view` -- proving entity-level resolution with no
710:+# client-side filter and correct MySQL translation of the dbplyr pipeline.
711:+#
712:+# ---------------------------------------------------------------------------
713:+# Deviation from the D3 plan brief, and why (documented per the task's own
714:+# instructions):
715:+#
716:+# The plan brief's literal Step 1 asked this file to seed D1's fixture
717:+# entities (incl. a 2nd "Definitive" gene) directly into `ndd_entity_view`'s
718:+# base tables on the empty test DB. `ndd_entity_view` joins ~7 tables
719:+# (ndd_entity + ndd_entity_status + ndd_entity_status_categories_list +
720:+# boolean_list + disease_ontology_set + mode_of_inheritance_list +
721:+# non_alt_loci_set) with a specific column/FK contract; self-seeding that
722:+# chain here would be fragile, easy to silently drift from the real view
723:+# definition, and largely redundant with the mandated live-container
724:+# end-to-end verification (submitting `category_filter` against the running
725:+# dev stack), which the controller performs separately.
726:+#
727:+# Instead, this file is SKIP-GUARDED on a populated view: it probes the live
728:+# `ndd_entity_view` for a real, currently-active category with >=2 distinct
729:+# NDD (`ndd_phenotype = 1`) genes, and only then runs. On a fresh/empty test
730:+# DB (CI default) every test here SKIPs cleanly. When the test DB is a
731:+# populated clone (a local/staging run), this file exercises the resolver
732:+# against the true view for real -- genuine resolver-vs-real-MySQL-view
733:+# coverage without fragile fixture seeding.
734:+# ---------------------------------------------------------------------------
736:+library(testthat)
737:+library(DBI)
739:+source_api_file("core/errors.R", local = FALSE)
740:+source_api_file("functions/clustering-gene-universe.R", local = FALSE)
741:+# The resolver's `is.null(selector)` (NULL/default) branch calls
742:+# `generate_ndd_hgnc_ids()` directly (it does NOT take `conn` on that path --
743:+# see clustering-gene-universe.R), so it must be sourced here too, or Test 3
744:+# below throws "could not find function" instead of exercising the branch.
745:+source_api_file("functions/analyses-functions.R", local = FALSE)
747:+#' Probe the live `ndd_entity_view` for one real, currently-active category
748:+#' with >=2 distinct NDD (`ndd_phenotype = 1`) genes.
749:+#'
750:+#' Joins against `ndd_entity_status_categories_list WHERE is_active = 1` so
751:+#' the returned category is guaranteed to pass
752:+#' `clustering_resolve_category_universe()`'s own live allowlist check --
753:+#' never returns a category that the resolver itself would reject as
754:+#' unknown/inactive.
755:+#'
756:+#' @param conn DBI connection to the test database.
757:+#' @return character(1) category name, or NULL if no such category exists
758:+#'   (e.g. an empty/fresh test DB, or `ndd_entity_view` is absent).
759:+.clustering_category_probe <- function(conn) {
760:+  if (!DBI::dbExistsTable(conn, "ndd_entity_view")) {
761:+    return(NULL)
762:+  }
763:+  if (!DBI::dbExistsTable(conn, "ndd_entity_status_categories_list")) {
764:+    return(NULL)
765:+  }
767:+  counts <- tryCatch(
768:+    DBI::dbGetQuery(
769:+      conn,
770:+      paste(
771:+        "SELECT v.category AS category, COUNT(DISTINCT v.hgnc_id) AS gene_count",
772:+        "FROM ndd_entity_view v",
773:+        "INNER JOIN ndd_entity_status_categories_list c",
774:+        "  ON c.category = v.category AND c.is_active = 1",
775:+        "WHERE v.ndd_phenotype = 1",
776:+        "GROUP BY v.category",
777:+        "ORDER BY gene_count DESC"
778:+      )
779:+    ),
780:+    error = function(e) NULL
781:+  )
782:+  if (is.null(counts) || nrow(counts) == 0L) {
783:+    return(NULL)
784:+  }
786:+  eligible <- counts[counts$gene_count >= 2, , drop = FALSE]
787:+  if (nrow(eligible) == 0L) {
788:+    return(NULL)
789:+  }
791:+  as.character(eligible$category[[1]])
792:+}
794:+test_that("clustering_resolve_category_universe matches a direct MySQL query on the real ndd_entity_view", {
795:+  with_test_db_transaction({
796:+    conn <- getOption(".test_db_con")
797:+    probe_category <- .clustering_category_probe(conn)
798:+    skip_if(
799:+      is.null(probe_category),
800:+      "no populated ndd_entity_view category with >=2 distinct NDD genes (empty/fresh test DB)"
801:+    )
803:+    resolved <- clustering_resolve_category_universe(probe_category, conn = conn)
805:+    direct <- DBI::dbGetQuery(
806:+      conn,
807:+      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1 AND category = ?",
808:+      params = list(probe_category)
809:+    )$hgnc_id
811:+    # Entity-level resolution, no client-side filter: the resolver's
812:+    # dbplyr-generated SQL must select exactly the same gene set as a direct
813:+    # equivalent query against the same live view.
814:+    expect_setequal(resolved$hgnc_ids, direct)
815:+    expect_identical(resolved$selector, probe_category)
816:+    expect_identical(resolved$resolved_gene_count, length(direct))
817:+  })
818:+})
820:+test_that("clustering_resolve_category_universe rejects an unknown category, naming the allowed set in the message", {
821:+  with_test_db_transaction({
822:+    conn <- getOption(".test_db_con")
823:+    probe_category <- .clustering_category_probe(conn)
824:+    skip_if(
825:+      is.null(probe_category),
826:+      "no populated ndd_entity_view category with >=2 distinct NDD genes (empty/fresh test DB)"
827:+    )
829:+    err <- tryCatch(
830:+      clustering_resolve_category_universe("Definative", conn = conn),
831:+      error = function(e) e
832:+    )
834:+    expect_s3_class(err, "error_400")
835:+    # The allowed active-category set is named in the MESSAGE (core/filters.R
836:+    # serializes conditionMessage(err), not a separate `detail` field), and a
837:+    # real currently-active category (the probe result) must appear in it.
838:+    expect_match(conditionMessage(err), "Unknown or inactive")
839:+    expect_match(conditionMessage(err), probe_category, fixed = TRUE)
840:+  })
841:+})
843:+test_that("clustering_resolve_category_universe(NULL) matches the default all-NDD-genes SELECT", {
844:+  with_test_db_transaction({
845:+    conn <- getOption(".test_db_con")
846:+    probe_category <- .clustering_category_probe(conn)
847:+    skip_if(
848:+      is.null(probe_category),
849:+      "no populated ndd_entity_view category with >=2 distinct NDD genes (empty/fresh test DB)"
850:+    )
852:+    # `generate_ndd_hgnc_ids()` (analyses-functions.R) reads the package-global
853:+    # `pool` directly -- the resolver's `is.null(selector)` branch does NOT
854:+    # forward `conn` to it (see clustering-gene-universe.R). Bind the global
855:+    # `pool` to this transaction's connection for the duration of the call so
856:+    # the NULL/default branch is exercised for real against the live view,
857:+    # then restore whatever `pool` held before (mirrors the
858:+    # test-unit-panels-endpoint.R / test-unit-endpoint-functions.R idiom).
859:+    # base::get(), not bare get(): a fully-loaded API/worker R session has
860:+    # `config::get` masking `get` (no `envir` argument there), which would
861:+    # error "unused argument (envir = .GlobalEnv)" (Codex review fix; see
862:+    # AGENTS.md "config::get masks base::get").
863:+    old_pool <- if (exists("pool", envir = .GlobalEnv)) base::get("pool", envir = .GlobalEnv) else NULL
864:+    assign("pool", conn, envir = .GlobalEnv)
865:+    withr::defer({
866:+      if (is.null(old_pool)) {
867:+        if (exists("pool", envir = .GlobalEnv)) rm(pool, envir = .GlobalEnv)
868:+      } else {
869:+        assign("pool", old_pool, envir = .GlobalEnv)
870:+      }
871:+    })
873:+    resolved <- clustering_resolve_category_universe(NULL, conn = conn)
875:+    # Meaningful, not tautological: compares against a DIRECT query against
876:+    # the real view, not against calling generate_ndd_hgnc_ids() a second
877:+    # time -- proves the NULL/default branch resolves the all-NDD universe
878:+    # correctly, independent of the resolver's own implementation.
879:+    direct <- DBI::dbGetQuery(
880:+      conn,
881:+      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1"
882:+    )$hgnc_id
884:+    expect_setequal(resolved$hgnc_ids, direct)
885:+    expect_null(resolved$selector)
886:+    expect_identical(resolved$resolved_gene_count, length(direct))
887:+  })
888:+})
890:+test_that("pool lookup uses base::get() so config::get masking (loaded API/worker env) cannot break it", {
891:+  # Static source guard, not a runtime probe -- reproducing the mask requires
892:+  # `library(config)` attached ahead of base on the search path (only true
893:+  # inside a fully-booted API/worker R session, not host `testthat`; see
894:+  # AGENTS.md "config::get masks base::get"). This file's own NULL-branch
895:+  # `pool` swap (three tests above) must always use the masking-safe form
896:+  # (Codex review fix: previously a bare `get("pool", envir = .GlobalEnv)`).
897:+  # Targets the specific `old_pool <-` assignment line only -- not the whole
898:+  # file body -- so this guard cannot accidentally match its own literals.
899:+  src <- readLines(
900:+    file.path(get_api_dir(), "tests", "testthat", "test-integration-clustering-category-submit.R"),
901:+    warn = FALSE
902:+  )
903:+  pool_swap_line <- src[grepl("old_pool <-.*envir = \\.GlobalEnv", src)]
905:+  expect_length(pool_swap_line, 1L)
906:+  expect_match(pool_swap_line, "base::get\\(", fixed = FALSE)
907:+})
913:+# .async_job_run_clustering assembles its result meta via clustering_result_meta()
914:+# (clustering-gene-universe.R, #574); source it so the handler resolves it here as
915:+# it does in the worker (bootstrap_load_modules sources it before the handlers).
916:+source_api_file("functions/clustering-gene-universe.R", local = FALSE)
922:+test_that("async_job_service_submit hashes hash_payload when supplied, not the full payload (#574 Codex round 3)", {
923:+  runtime <- load_async_job_service_runtime()
924:+  created_job <- NULL
926:+  runtime$async_job_repository_create <- function(job, conn = NULL) {
927:+    created_job <<- job
928:+    job$job_id
929:+  }
930:+  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
931:+    tibble::tibble(job_id = job_id, request_hash = created_job$request_hash,
932:+                   request_payload_json = created_job$request_payload_json)
933:+  }
935:+  full_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden",
936:+                       provenance = list(source_data_version = "2026-07-18T00:00:00Z"))
937:+  subset_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden")
939:+  runtime$async_job_service_submit(
940:+    job_type = "clustering",
941:+    request_payload = full_payload,
942:+    hash_payload = subset_payload,
943:+    job_id = "job-hash-override"
944:+  )
946:+  # request_hash is computed over hash_payload (the subset), not the full payload.
947:+  expect_equal(
948:+    created_job$request_hash,
949:+    runtime$async_job_service_request_hash(
950:+      "clustering",
951:+      runtime$async_job_service_payload_json(subset_payload)
952:+    )
953:+  )
954:+  expect_false(identical(
955:+    created_job$request_hash,
956:+    runtime$async_job_service_request_hash(
957:+      "clustering",
958:+      runtime$async_job_service_payload_json(full_payload)
959:+    )
960:+  ))
962:+  # request_payload_json (the DURABLY STORED payload) is always the FULL payload,
963:+  # provenance included -- only the dedup hash excludes it.
964:+  expect_equal(
965:+    jsonlite::fromJSON(created_job$request_payload_json, simplifyVector = TRUE)$provenance$source_data_version,
966:+    "2026-07-18T00:00:00Z"
967:+  )
969:+  # Default behavior (no hash_payload) is unchanged: hash the full payload.
970:+  runtime$async_job_service_submit(
971:+    job_type = "clustering",
972:+    request_payload = full_payload,
973:+    job_id = "job-hash-default"
974:+  )
975:+  expect_equal(
976:+    created_job$request_hash,
977:+    runtime$async_job_service_request_hash(
978:+      "clustering",
979:+      runtime$async_job_service_payload_json(full_payload)
980:+    )
981:+  )
982:+})
989:+    file.path(api_dir, "functions", "clustering-gene-universe.R"),
996:+# Unit tests for the category-selected clustering gene-universe resolver (#574 D1).
997:+#
998:+# `clustering_resolve_category_universe()` resolves the gene set a clustering
999:+# job runs on: either the current default (all NDD genes, via
1000:+# `generate_ndd_hgnc_ids()`) or a curated-category selection
1001:+# (`ndd_entity_view` entity rows filtered by `category %in% selector`, then
1002:+# distinct `hgnc_id`). This file is DB-free: the default branch's dependency
1003:+# (`generate_ndd_hgnc_ids()`) is overridden in a child environment, and the
1004:+# category branch's `conn` is a real in-memory RSQLite connection so the
1005:+# dbplyr pipeline (`tbl()` / `filter()` / `select()` / `collect()`) is
1006:+# exercised for real rather than mocked.
1007:+#
1008:+# Trap: do NOT stub `generate_ndd_hgnc_ids` via
1009:+# `testthat::local_mocked_bindings(..., .env = globalenv())` -- under
1010:+# testthat 3.3.2 that aborts with "No packages loaded with pkgload" because
1011:+# globalenv() has no package namespace. A child-env override sidesteps this.
1013:+## -------------------------------------------------------------------------##
1014:+## clustering_cached_source_data_version() TTL cache (#574 D2 review fix)
1015:+## -------------------------------------------------------------------------##
1016:+#
1017:+# These tests stub `analysis_snapshot_source_data_version()` directly -- no DB
1018:+# connection is ever opened -- so they are placed BEFORE the file-wide
1019:+# `skip_if_not_installed("RSQLite")` gate below and run unconditionally, even
1020:+# when {RSQLite} is unavailable.
1022:+# Sources ONLY core/errors.R + the module under test into a fresh child env.
1023:+# A fresh env means a fresh `.clustering_source_data_version_cache` (it is
1024:+# created top-level by the sourced file), so there is nothing left over from
1025:+# a prior test -- `.reset_source_data_version_cache()` below is still applied
1026:+# defensively so the reset mechanism itself stays covered/documented.
1027:+.source_data_version_env <- function() {
1028:+  e <- new.env(parent = globalenv())
1029:+  source_api_file("core/errors.R", local = FALSE, envir = e)
1030:+  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
1031:+  e
1032:+}
1034:+# Clears the module-level TTL cache env so cached state never leaks across
1035:+# assertions sharing the same sourced env `e`.
1036:+.reset_source_data_version_cache <- function(e) {
1037:+  cache_env <- e$.clustering_source_data_version_cache
1038:+  keys <- ls(cache_env, all.names = TRUE)
1039:+  if (length(keys) > 0L) rm(list = keys, envir = cache_env)
1040:+}
1042:+test_that("clustering_cached_source_data_version: TTL hit avoids a second underlying fetch", {
1043:+  e <- .source_data_version_env()
1044:+  .reset_source_data_version_cache(e)
1045:+  calls <- 0L
1046:+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
1047:+    calls <<- calls + 1L
1048:+    "v1"
1049:+  }
1051:+  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
1052:+  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
1054:+  expect_identical(first, "v1")
1055:+  expect_identical(second, "v1")
1056:+  expect_identical(calls, 1L) # second call served from cache, underlying fn NOT re-invoked
1057:+})
1059:+test_that("clustering_cached_source_data_version: TTL expiry (ttl_seconds = 0) forces a refetch", {
1060:+  # `diff < ttl_seconds` is the staleness check; `diff` (elapsed seconds since
1061:+  # the last successful fetch) is always >= 0, so `ttl_seconds = 0` makes
1062:+  # `diff < 0` FALSE on every subsequent call -- deterministically always-stale,
1063:+  # regardless of clock resolution between the two calls.
1064:+  e <- .source_data_version_env()
1065:+  .reset_source_data_version_cache(e)
1066:+  calls <- 0L
1067:+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
1068:+    calls <<- calls + 1L
1069:+    paste0("v", calls)
1070:+  }
1072:+  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
1073:+  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
1075:+  expect_identical(first, "v1")
1076:+  expect_identical(second, "v2")
1077:+  expect_identical(calls, 2L) # both calls hit the underlying fn -- cache never served a hit
1078:+})
1080:+test_that("clustering_cached_source_data_version: an error propagates and never poisons the cache", {
1081:+  e <- .source_data_version_env()
1082:+  .reset_source_data_version_cache(e)
1083:+  e$analysis_snapshot_source_data_version <- function(conn = NULL) stop("boom")
1085:+  expect_error(
1086:+    e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300),
1087:+    "boom"
1088:+  )
1089:+  # Nothing was written to the cache by the failed call.
1090:+  expect_null(e$.clustering_source_data_version_cache$value)
1091:+  expect_null(e$.clustering_source_data_version_cache$cached_at)
1093:+  # Swap to a success stub: the NEXT call must refetch (not serve a stale/NA
1094:+  # value left over from the failed attempt) and the cache must now work.
1095:+  .reset_source_data_version_cache(e)
1096:+  calls <- 0L
1097:+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
1098:+    calls <<- calls + 1L
1099:+    "v-success"
1100:+  }
1102:+  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
1104:+  expect_identical(result, "v-success")
1105:+  expect_identical(calls, 1L)
1106:+})
1108:+test_that("clustering_cached_source_data_version: NA_character_ from the underlying fetch is rejected and never cached (Codex review fix)", {
1109:+  # Fail-closed contract: the TTL cache must never cache/return NA. A
1110:+  # malformed underlying value must stop() (mapped to 503 by the caller's
1111:+  # tryCatch), exactly like a hard fetch error above -- not be cached and
1112:+  # served as broken provenance.
1113:+  e <- .source_data_version_env()
1114:+  .reset_source_data_version_cache(e)
1115:+  calls <- 0L
1116:+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
1117:+    calls <<- calls + 1L
1118:+    NA_character_
1119:+  }
1121:+  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
1122:+  # Nothing was written to the cache by the invalid-value call.
1123:+  expect_null(e$.clustering_source_data_version_cache$value)
1124:+  expect_null(e$.clustering_source_data_version_cache$cached_at)
1126:+  # Swap to a now-valid stub: the NEXT call must refetch (never serve the
1127:+  # invalid value from a poisoned cache) and the counter must increment.
1128:+  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
1129:+    calls <<- calls + 1L
1130:+    "v-valid"
1131:+  }
1132:+  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
1134:+  expect_identical(result, "v-valid")
1135:+  expect_identical(calls, 2L)
1136:+})
1138:+test_that("clustering_cached_source_data_version: an empty string from the underlying fetch is rejected and never cached (Codex review fix)", {
1139:+  e <- .source_data_version_env()
1140:+  .reset_source_data_version_cache(e)
1141:+  e$analysis_snapshot_source_data_version <- function(conn = NULL) ""
1143:+  expect_error(e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300))
1144:+  expect_null(e$.clustering_source_data_version_cache$value)
1145:+  expect_null(e$.clustering_source_data_version_cache$cached_at)
1146:+})
1148:+testthat::skip_if_not_installed("RSQLite")
1150:+# Source the code under test into a child env so the NULL-branch dependency
1151:+# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
1152:+# globalenv() or any other test file's bindings.
1153:+.gene_universe_env <- function() {
1154:+  e <- new.env(parent = globalenv())
1155:+  source_api_file("core/errors.R", local = FALSE, envir = e)
1156:+  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
1157:+  e
1158:+}
1160:+# In-memory RSQLite fixture standing in for `pool`/a real DB connection.
1161:+# `ev` = ndd_entity_view rows, `cats` = ndd_entity_status_categories_list rows.
1162:+fake_conn <- function(ev, cats) {
1163:+  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
1164:+  DBI::dbWriteTable(con, "ndd_entity_view", as.data.frame(ev))
1165:+  DBI::dbWriteTable(con, "ndd_entity_status_categories_list", as.data.frame(cats))
1166:+  con
1167:+}
1169:+# Fixture: entity rows (one row per entity). TWO Definitive NDD genes so the
1170:+# ["Definitive"] universe passes the >=2 guard.
1171:+ev <- tibble::tribble(
1172:+  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
1173:+  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
1174:+  2L,        "HGNC:1",   1L,             "Limited",
1175:+  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
1176:+  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
1177:+  5L,        "HGNC:4",   1L,             "Moderate",     # gene 4: Moderate NDD (single -> too-small alone)
1178:+  6L,        "HGNC:5",   1L,             "Definitive"    # gene 5: second Definitive NDD gene
1179:+)
1180:+cats <- tibble::tibble(
1181:+  category = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
1182:+  is_active = 1L
1183:+)
1185:+test_that("Definitive selects genes with any Definitive NDD entity (multi-entity gene included)", {
1186:+  e <- .gene_universe_env()
1187:+  con <- fake_conn(ev, cats)
1188:+  withr::defer(DBI::dbDisconnect(con))
1190:+  r <- e$clustering_resolve_category_universe("Definitive", conn = con)
1192:+  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5")) # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
1193:+  expect_identical(r$selector, "Definitive")
1194:+  expect_identical(r$resolved_gene_count, 2L)
1195:+})
1197:+test_that("multi-value selector is a union across categories", {
1198:+  e <- .gene_universe_env()
1199:+  con <- fake_conn(ev, cats)
1200:+  withr::defer(DBI::dbDisconnect(con))
1202:+  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)
1204:+  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5", "HGNC:4"))
1205:+})
1207:+test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
1208:+  e <- .gene_universe_env()
1209:+  con <- fake_conn(ev, cats)
1210:+  withr::defer(DBI::dbDisconnect(con))
1211:+  e$generate_ndd_hgnc_ids <- function() {
1212:+    tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5"))
1213:+  }
1215:+  r <- e$clustering_resolve_category_universe(NULL, conn = con)
1217:+  expect_identical(r$hgnc_ids, c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5")) # arrange(entity_id)+distinct, ndd_phenotype==1
1218:+  expect_null(r$selector)
1219:+})
1221:+test_that("unknown token is rejected 400 with the allowed set in the MESSAGE (not detail)", {
1222:+  e <- .gene_universe_env()
1223:+  con <- fake_conn(ev, cats)
1224:+  withr::defer(DBI::dbDisconnect(con))
1226:+  err <- tryCatch(
1227:+    e$clustering_resolve_category_universe("Definative", conn = con),
1228:+    error = function(err) err
1229:+  )
1231:+  expect_s3_class(err, "error_400")
1232:+  expect_match(conditionMessage(err), "Definitive") # allowed set is in the message so it reaches clients
1233:+})
1235:+test_that("supplied-but-empty selector is 400 (NOT the all-NDD default) with the allowed set in the message", {
1236:+  e <- .gene_universe_env()
1237:+  con <- fake_conn(ev, cats)
1238:+  withr::defer(DBI::dbDisconnect(con))
1240:+  err_empty <- tryCatch(
1241:+    e$clustering_resolve_category_universe(list(), conn = con),
1242:+    error = function(err) err
1243:+  )
1244:+  err_blank <- tryCatch(
1245:+    e$clustering_resolve_category_universe(list("   "), conn = con),
1246:+    error = function(err) err
1247:+  )
1249:+  expect_s3_class(err_empty, "error_400")
1250:+  expect_s3_class(err_blank, "error_400")
1251:+  # The locked contract: EVERY category-validation 400 names the allowed set.
1252:+  expect_match(conditionMessage(err_empty), "Allowed active categories")
1253:+  expect_match(conditionMessage(err_empty), "Definitive")
1254:+  expect_match(conditionMessage(err_blank), "Allowed active categories")
1255:+  expect_match(conditionMessage(err_blank), "Definitive")
1256:+})
1258:+test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job) with the allowed set in the message", {
1259:+  e <- .gene_universe_env()
1260:+  con <- fake_conn(ev, cats)
1261:+  withr::defer(DBI::dbDisconnect(con))
1263:+  err_zero <- tryCatch(
1264:+    e$clustering_resolve_category_universe("Refuted", conn = con), # 0 genes
1265:+    error = function(err) err
1266:+  )
1267:+  err_one <- tryCatch(
1268:+    e$clustering_resolve_category_universe("Moderate", conn = con), # 1 gene
1269:+    error = function(err) err
1270:+  )
1272:+  expect_s3_class(err_zero, "error_400")
1273:+  expect_s3_class(err_one, "error_400")
1274:+  expect_match(conditionMessage(err_zero), "Allowed active categories")
1275:+  expect_match(conditionMessage(err_zero), "Definitive")
1276:+  expect_match(conditionMessage(err_one), "Allowed active categories")
1277:+  expect_match(conditionMessage(err_one), "Definitive")
1278:+})
1280:+test_that("gene_list_sha256 is sort-order independent", {
1281:+  e <- .gene_universe_env()
1283:+  expect_identical(
1284:+    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
1285:+    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
1286:+  )
1287:+})
1289:+test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
1290:+  e <- .gene_universe_env()
1292:+  expect_null(e$clustering_normalize_category_filter(NULL))
1293:+  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
1294:+  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
1295:+  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
1296:+  expect_identical(
1297:+    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
1298:+    c("Definitive", "Moderate")
1299:+  )
1300:+})
1307:+# Unit tests for the durable clustering handler's result `meta` (#574 D3).
1308:+#
1309:+# `.async_job_run_clustering()` (api/functions/async-job-handlers.R) is the
1310:+# worker-run (cache-miss) counterpart to the cache-hit path in
1311:+# `svc_job_submit_functional_clustering()` (job-functional-submission-service.R,
1312:+# #574 D2). D2 already stitches the request's cheap-path `provenance` list
1313:+# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
1314:+# source_data_version) plus an `effective_fingerprint` (the STRING
1315:+# `weight_channel` actually observed on the computed result) into the
1316:+# cache-hit result `meta`. D3 makes the durable handler mirror that SAME
1317:+# shape for a worker-run job, so a silent exp+db -> combined-score STRING
1318:+# fallback is visible in a freshly-computed job's stored result too, not
1319:+# just a cache hit's.
1320:+#
1321:+# DB-free: `gen_string_clust_obj` and its category-enrichment/progress-reporter
1322:+# collaborators are stubbed in a child environment. This file never opens a
1323:+# DB connection and always runs (no skip guard).
1324:+#
1325:+# Trap (documented in test-unit-clustering-gene-universe.R and repeated here):
1326:+# do NOT stub via `testthat::local_mocked_bindings(..., .env = globalenv())`
1327:+# -- under testthat 3.3.2 that aborts with "No packages loaded with
1328:+# pkgload" because globalenv() has no package namespace. A child-env
1329:+# override (source into a fresh `new.env(parent = globalenv())`, then
1330:+# reassign bindings on that env) sidesteps this entirely.
1332:+.clustering_handler_env <- function() {
1333:+  e <- new.env(parent = globalenv())
1334:+  # async-job-handlers.R's eagerly-built async_job_handler_registry list()
1335:+  # references handler functions from these sibling modules by bare symbol
1336:+  # (#346 Wave 4 split; see the file's own header comment), so they must be
1337:+  # sourced first or the list() construction fails with "object '...' not
1338:+  # found" -- mirrors test-unit-async-job-handlers.R.
1339:+  source_api_file("functions/async-job-force-apply-payload.R", local = FALSE, envir = e)
1340:+  source_api_file("functions/async-job-omim-apply.R", local = FALSE, envir = e)
1341:+  source_api_file("functions/async-job-provider-handlers.R", local = FALSE, envir = e)
1342:+  source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE, envir = e)
1343:+  source_api_file("functions/async-job-network-layout-handlers.R", local = FALSE, envir = e)
1344:+  source_api_file("functions/async-job-analysis-snapshot-handlers.R", local = FALSE, envir = e)
1345:+  # `.async_job_run_clustering()`'s result-`meta` assembly calls
1346:+  # `clustering_result_meta()` (#574 D3 fix wave 1), the shared helper defined
1347:+  # in clustering-gene-universe.R -- source it too or the handler errors with
1348:+  # "could not find function".
1349:+  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
1350:+  source_api_file("functions/async-job-handlers.R", local = FALSE, envir = e)
1352:+  # Stub the heavy clustering computation: returns a minimal tibble carrying
1353:+  # the SAME `weight_channel` attribute contract `gen_string_clust_obj` sets
1354:+  # (analyses-functions.R:351) so the handler's `effective_fingerprint`
1355:+  # extraction is exercised for real.
1356:+  e$gen_string_clust_obj <- function(genes, algorithm, string_id_table) {
1357:+    x <- tibble::tibble(cluster = 1L)
1358:+    attr(x, "weight_channel") <- "experimental_database"
1359:+    x
1360:+  }
1362:+  # `.async_job_functional_categories(clusters, category_links)` is called
1363:+  # unconditionally by the handler; stub it out so this test does not also
1364:+  # have to fabricate a `term_enrichment` column on the stub clusters tibble.
1365:+  e$.async_job_functional_categories <- function(clusters, category_links) {
1366:+    tibble::tibble()
1367:+  }
1369:+  # Bypasses `create_async_job_progress_reporter()` (a separate, unsourced
1370:+  # module in this DB-free test) -- see file header trap note.
1371:+  e$.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
1372:+    function(...) invisible(NULL)
1373:+  }
1375:+  e
1376:+}
1378:+test_that(".async_job_run_clustering echoes payload provenance + effective_fingerprint into result meta", {
1379:+  e <- .clustering_handler_env()
1381:+  payload <- list(
1382:+    genes = c("HGNC:1", "HGNC:5"),
1383:+    algorithm = "leiden",
1384:+    string_id_table = NULL,
1385:+    category_links = NULL,
1386:+    provenance = list(
1387:+      selector = list(kind = "category", category_filter = "Definitive"),
1388:+      resolved_gene_count = 2L,
1389:+      gene_list_sha256 = "abc",
1390:+      intended_fingerprint = list(string_cache_fingerprint = "fp"),
1391:+      source_data_version = "srcv-1"
1392:+    )
1393:+  )
1395:+  result <- e$.async_job_run_clustering(
1396:+    job = list(job_id = "j1"),
1397:+    payload = payload,
1398:+    state = NULL,
1399:+    worker_config = NULL
1400:+  )
1402:+  meta <- result$meta
1404:+  expect_identical(meta$algorithm, "leiden")
1405:+  expect_identical(meta$gene_count, 2L)
1406:+  expect_identical(meta$cluster_count, 1L)
1407:+  # Shape parity with the cache-hit path's meta (job-functional-submission-
1408:+  # service.R), which always carries cache_hit = TRUE: a worker-run job must
1409:+  # carry cache_hit = FALSE so callers can distinguish the two without an
1410:+  # absent-field check.
1411:+  expect_identical(meta$cache_hit, FALSE)
1412:+  expect_identical(meta$selector$kind, "category")
1413:+  expect_identical(meta$gene_list_sha256, "abc")
1414:+  expect_identical(meta$source_data_version, "srcv-1")
1415:+  expect_identical(meta$intended_fingerprint$string_cache_fingerprint, "fp")
1416:+  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
1417:+})
1419:+test_that(".async_job_run_clustering: gene_count is the DISTINCT gene count, matching the cache-hit path (Codex round-2 review fix)", {
1420:+  # Bug: the worker handler reported `gene_count = length(genes)` (raw),
1421:+  # while the cache-hit path (job-functional-submission-service.R) reports
1422:+  # `resolved_count <- length(unique(genes_list))` (distinct) -- for
1423:+  # `["HGNC:1","HGNC:1"]` the cache-hit path reports gene_count=1 but the
1424:+  # worker reported gene_count=2 for the identical payload. Both paths must
1425:+  # agree.
1426:+  e <- .clustering_handler_env()
1428:+  payload <- list(
1429:+    genes = c("HGNC:1", "HGNC:1"),
1430:+    algorithm = "leiden",
1431:+    string_id_table = NULL,
1432:+    category_links = NULL
1433:+  )
1435:+  result <- e$.async_job_run_clustering(
1436:+    job = list(job_id = "j-dup-genes"),
1437:+    payload = payload,
1438:+    state = NULL,
1439:+    worker_config = NULL
1440:+  )
1442:+  expect_identical(result$meta$gene_count, 1L)
1443:+})
1445:+test_that(".async_job_run_clustering: legacy payload with no provenance still returns a valid meta (backward compat)", {
1446:+  e <- .clustering_handler_env()
1448:+  payload <- list(
1449:+    genes = c("HGNC:1", "HGNC:5", "HGNC:9"),
1450:+    algorithm = "walktrap",
1451:+    string_id_table = NULL,
1452:+    category_links = NULL
1453:+    # No `provenance` field -- mirrors an explicit/no-arg pre-#574 submit.
1454:+  )
1456:+  result <- NULL
1457:+  expect_no_error({
1458:+    result <- e$.async_job_run_clustering(
1459:+      job = list(job_id = "j2"),
1460:+      payload = payload,
1461:+      state = NULL,
1462:+      worker_config = NULL
1463:+    )
1464:+  })
1466:+  meta <- result$meta
1468:+  expect_identical(meta$algorithm, "walktrap")
1469:+  expect_identical(meta$gene_count, 3L)
1470:+  expect_identical(meta$cluster_count, 1L)
1471:+  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
1472:+  # No provenance fields leaked in when the payload never carried them.
1473:+  expect_null(meta$selector)
1474:+  expect_null(meta$gene_list_sha256)
1475:+  expect_null(meta$source_data_version)
1476:+  expect_null(meta$intended_fingerprint)
1477:+})
1484:+# tests/testthat/test-unit-job-endpoint-services-category.R
1485:+#
1486:+# Host-runnable unit tests for the #574 (D2) category_filter / provenance /
1487:+# dedup-hash-payload coverage of job-functional-submission-service.R, split
1488:+# out of test-unit-job-endpoint-services.R (which keeps the base functional-
1489:+# clustering submit coverage) to keep both files under the 600-line ceiling
1490:+# after the #574 Codex-review-fix rounds grew this coverage. Shared fixtures
1491:+# live in job-endpoint-services-fixtures.R (explicitly sourced below,
1492:+# mirroring the sibling files). See test-unit-job-endpoint-services.R's
1493:+# header for the full split rationale (phenotype submission coverage lives in
1494:+# test-unit-job-endpoint-services-phenotype.R; maintenance-submission +
1495:+# query-endpoint services are covered in
1496:+# test-unit-job-endpoint-services-maintenance.R).
1497:+#
1498:+# Each service is sourced directly into an isolated environment via sys.source()
1499:+# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
1500:+# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
1501:+# async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
1502:+# gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
1503:+# exercise pure request/response logic without a live DB or mirai daemon pool.
1505:+# Resolve api_dir robustly so the file runs both under the full suite and a single-file
1506:+# testthat::test_file(), then source the shared fixtures.
1507:+if (exists("get_api_dir")) {
1508:+  api_dir <- get_api_dir()
1509:+} else {
1510:+  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
1511:+  if (!file.exists(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"))) {
1512:+    api_dir <- normalizePath(getwd(), mustWork = FALSE)
1513:+  }
1514:+}
1515:+# local = TRUE keeps the shared helpers in this test file's environment (as if defined
1516:+# inline) so `job_endpoint_source_service()` can still see the auto-loaded `get_api_dir`.
1517:+source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R"), local = TRUE)
1519:+## -------------------------------------------------------------------##
1520:+## job-functional-submission-service.R: category_filter (#574 D2)
1521:+## -------------------------------------------------------------------##
1523:+test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
1524:+  env <- job_endpoint_source_service("job-functional-submission-service.R")
1525:+  # stop_for_bad_request() lives in core/errors.R, not sourced by the isolated
1526:+  # service env by default -- source it here so the real (non-stubbed)
1527:+  # mutual-exclusion guard in the service body can raise it.
1528:+  source_api_file("core/errors.R", local = FALSE, envir = env)
1529:+  env$pool <- job_endpoint_functional_pool(env)
1530:+  req <- list(
1531:+    argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive")),
1532:+    user = list(user_id = NULL)
1533:+  )
1534:+  res <- job_endpoint_fake_res()
1536:+  expect_error(
1537:+    env$svc_job_submit_functional_clustering(req, res),
1538:+    class = "error_400"
1539:+  )
1540:+})
1542:+test_that("functional clustering: an EMPTY genes array + category_filter still triggers mutual exclusion -> error_400 (Codex review fix)", {
1543:+  # Bug: mutual exclusion was previously gated on `has_genes` (a LENGTH
1544:+  # check), so `{"genes":[], "category_filter":["Definitive"]}` bypassed it
1545:+  # -- an empty-but-PRESENT `genes` key must still 400 when a category_filter
1546:+  # is also present. Presence (`genes_supplied <- !is.null(genes_in)`), not
1547:+  # length, is what mutual exclusion must gate on.
1548:+  env <- job_endpoint_source_service("job-functional-submission-service.R")
1549:+  source_api_file("core/errors.R", local = FALSE, envir = env)
1550:+  env$pool <- job_endpoint_functional_pool(env)
1551:+  req <- list(
1552:+    argsBody = list(genes = list(), category_filter = list("Definitive")),
1553:+    user = list(user_id = NULL)
1554:+  )
1555:+  res <- job_endpoint_fake_res()
1557:+  expect_error(
1558:+    env$svc_job_submit_functional_clustering(req, res),
1559:+    class = "error_400"
1560:+  )
1561:+})
1563:+test_that("functional clustering: an explicit-null genes KEY + category_filter still triggers mutual exclusion -> error_400 (Codex round-2 review fix)", {
1564:+  # Bug: mutual exclusion was gated on `!is.null(genes_in)`, which cannot
1565:+  # distinguish an ABSENT `genes` key from an explicit JSON `null` (both
1566:+  # parse to a NULL `req$argsBody$genes`) -- so
1567:+  # `{"genes":null, "category_filter":["Definitive"]}` bypassed the guard and
1568:+  # a category job was silently accepted. `list(genes = NULL)` in base R
1569:+  # KEEPS the `genes` name with a NULL value (verified:
1570:+  # "genes" %in% names(list(genes = NULL)) is TRUE), so gating on
1571:+  # `names(req$argsBody)` instead of value-nullness catches this.
1572:+  env <- job_endpoint_source_service("job-functional-submission-service.R")
1573:+  source_api_file("core/errors.R", local = FALSE, envir = env)
1574:+  env$pool <- job_endpoint_functional_pool(env)
1575:+  req <- list(
1576:+    argsBody = list(genes = NULL, category_filter = list("Definitive")),
1577:+    user = list(user_id = NULL)
1578:+  )
1579:+  res <- job_endpoint_fake_res()
1581:+  expect_true("genes" %in% names(req$argsBody)) # pin the base-R name-retention fact this test relies on
1582:+  expect_error(
1583:+    env$svc_job_submit_functional_clustering(req, res),
1584:+    class = "error_400"
1585:+  )
1586:+})
1588:+test_that("functional clustering: an explicit-null genes KEY ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
1589:+  # Regression guard for the fix above: gating mutual exclusion on JSON key
1590:+  # presence must NOT change the pre-existing behavior for a null `genes`
1591:+  # value with no `category_filter` at all -- it must still fall through to
1592:+  # the all-NDD default exactly as before.
1593:+  env <- job_endpoint_source_service("job-functional-submission-service.R")
1594:+  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
1595:+    entity_id = 1:3,
1596:+    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
1597:+    ndd_phenotype = c(1L, 0L, 1L)
1598:+  ))
1599:+  job_endpoint_stub_all_ndd_universe(env)
1600:+  captured <- NULL
1601:+  env$check_duplicate_job <- function(operation, params) {
1602:+    captured <<- params
1603:+    list(duplicate = TRUE, existing_job_id = "dup-null-genes")
1604:+  }
1605:+  req <- list(argsBody = list(genes = NULL), user = list(user_id = NULL))
1606:+  res <- job_endpoint_fake_res()
1608:+  out <- env$svc_job_submit_functional_clustering(req, res)
1610:+  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
1611:+  expect_equal(res$status, 409)
1612:+  expect_equal(out$error, "DUPLICATE_JOB")
1613:+})
1615:+test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
1616:+  # Regression guard for the fix above: gating mutual exclusion on
1617:+  # `genes_supplied` (key presence) must NOT change the pre-existing
1618:+  # behavior for an empty `genes` array with no `category_filter` at all --
1619:+  # it must still fall through to the all-NDD default exactly as before.
1620:+  env <- job_endpoint_source_service("job-functional-submission-service.R")
1621:+  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
1622:+    entity_id = 1:3,
1623:+    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
1624:+    ndd_phenotype = c(1L, 0L, 1L)
1625:+  ))
1626:+  job_endpoint_stub_all_ndd_universe(env)
1627:+  captured <- NULL
1628:+  env$check_duplicate_job <- function(operation, params) {
1629:+    captured <<- params
1630:+    list(duplicate = TRUE, existing_job_id = "dup-empty-genes")
1631:+  }
1632:+  req <- list(argsBody = list(genes = list()), user = list(user_id = NULL))
1633:+  res <- job_endpoint_fake_res()
1635:+  out <- env$svc_job_submit_functional_clustering(req, res)
1637:+  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
1638:+  expect_equal(res$status, 409)
1639:+  expect_equal(out$error, "DUPLICATE_JOB")
1640:+})
1642:+test_that("functional clustering: an explicit-null category_filter KEY (no genes) coerces to an empty selector and delegates to the resolver (Codex round-5 review fix)", {
1643:+  # Bug: the branch used `category_supplied <- !is.null(category_filter)`, so a
1644:+  # present-but-null `category_filter` key (`{"category_filter":null}`) was
1645:+  # treated as ABSENT and silently resolved the all-NDD default instead of the
1646:+  # required supplied-empty 400 -- the category-side symmetry of the genes-null
1647:+  # fix. The branch now keys off `"category_filter" %in% names(req$argsBody)`.
1648:+  #
1649:+  # Round 5: the service no longer raises its own standalone 400 for this case
1650:+  # (that duplicated the resolver's message and omitted the allowed active-
1651:+  # category set). It now coerces the NULL to an empty selector (`list()`) and
1652:+  # DELEGATES to `clustering_resolve_category_universe()`, which 400s a
1653:+  # supplied-but-empty selector with the allowed set in the message (covered
1654:+  # by test-unit-clustering-gene-universe.R). This test proves the DELEGATION
1655:+  # (empty selector reaches the resolver), not the 400 itself.
1656:+  env <- job_endpoint_source_service("job-functional-submission-service.R")

exec
/bin/bash -lc "git diff --check origin/master...HEAD -- ':(exclude).planning/**' && git diff --exit-code --quiet origin/master...HEAD -- app/package-lock.json; printf 'package-lock changed=%s\\n' \""'$?"; git diff --word-diff=porcelain origin/master...HEAD -- app/package-lock.json | sed -n '"'1,80p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
package-lock changed=1
diff --git a/app/package-lock.json b/app/package-lock.json
index bcc638de..73e3f535 100644
--- a/app/package-lock.json
+++ b/app/package-lock.json
@@ -1,12 +1,12 @@
 {
~
   "name": "sysndd",
~
   "version": 
-"0.30.0",
+"0.30.1",
~
   "lockfileVersion": 3,
~
   "requires": true,
~
   "packages": {
~
     "": {
~
       "name": "sysndd",
~
       "version": 
-"0.30.0",
+"0.30.1",
~
       "dependencies": {
~
         "@popperjs/core": "^2.11.8",
~
         "@unhead/vue": "^3.1.8",
~

exec
/bin/bash -lc "rg -n -C 12 'async_job_repository_create <-|async_job_duplicate_error|request_hash' api/functions/async-job-repository.R db api/tests/testthat/test-unit-async-job-repository.R | head -n 500; rg -n -C 6 'async_job_service_submit\\(' api/tests/testthat | rg -n -C 4 'duplicate|clustering|hash_payload' | head -n 400" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/tests/testthat/test-unit-async-job-repository.R-147-
api/tests/testthat/test-unit-async-job-repository.R-148-  force(code)
api/tests/testthat/test-unit-async-job-repository.R-149-}
api/tests/testthat/test-unit-async-job-repository.R-150-
api/tests/testthat/test-unit-async-job-repository.R-151-seed_async_job <- function(conn, ...) {
api/tests/testthat/test-unit-async-job-repository.R-152-  job <- utils::modifyList(
api/tests/testthat/test-unit-async-job-repository.R-153-    list(
api/tests/testthat/test-unit-async-job-repository.R-154-      job_id = paste0("job-", substr(uuid::UUIDgenerate(), 1, 8)),
api/tests/testthat/test-unit-async-job-repository.R-155-      job_type = "hgnc_update",
api/tests/testthat/test-unit-async-job-repository.R-156-      queue_name = "default",
api/tests/testthat/test-unit-async-job-repository.R-157-      priority = 100L,
api/tests/testthat/test-unit-async-job-repository.R-158-      request_payload_json = "{\"operation\":\"hgnc_update\"}",
api/tests/testthat/test-unit-async-job-repository.R:159:      request_hash = paste0("hash-", substr(uuid::UUIDgenerate(), 1, 12)),
api/tests/testthat/test-unit-async-job-repository.R-160-      submitted_by = NULL,
api/tests/testthat/test-unit-async-job-repository.R-161-      scheduled_at = Sys.time(),
api/tests/testthat/test-unit-async-job-repository.R-162-      max_attempts = 1L
api/tests/testthat/test-unit-async-job-repository.R-163-    ),
api/tests/testthat/test-unit-async-job-repository.R-164-    list(...)
api/tests/testthat/test-unit-async-job-repository.R-165-  )
api/tests/testthat/test-unit-async-job-repository.R-166-
api/tests/testthat/test-unit-async-job-repository.R-167-  async_job_repository_create(
api/tests/testthat/test-unit-async-job-repository.R-168-    job,
api/tests/testthat/test-unit-async-job-repository.R-169-    conn = conn
api/tests/testthat/test-unit-async-job-repository.R-170-  )
api/tests/testthat/test-unit-async-job-repository.R-171-}
--
api/tests/testthat/test-unit-async-job-repository.R-179-  on.exit(DBI::dbDisconnect(conn), add = TRUE)
api/tests/testthat/test-unit-async-job-repository.R-180-
api/tests/testthat/test-unit-async-job-repository.R-181-  async_job_columns <- DBI::dbGetQuery(conn, "SHOW COLUMNS FROM async_jobs")$Field
api/tests/testthat/test-unit-async-job-repository.R-182-  event_columns <- DBI::dbGetQuery(conn, "SHOW COLUMNS FROM async_job_events")$Field
api/tests/testthat/test-unit-async-job-repository.R-183-  create_sql <- DBI::dbGetQuery(conn, "SHOW CREATE TABLE async_jobs")$`Create Table`[1]
api/tests/testthat/test-unit-async-job-repository.R-184-
api/tests/testthat/test-unit-async-job-repository.R-185-  expect_true(all(c(
api/tests/testthat/test-unit-async-job-repository.R-186-    "job_id",
api/tests/testthat/test-unit-async-job-repository.R-187-    "job_type",
api/tests/testthat/test-unit-async-job-repository.R-188-    "queue_name",
api/tests/testthat/test-unit-async-job-repository.R-189-    "priority",
api/tests/testthat/test-unit-async-job-repository.R-190-    "status",
api/tests/testthat/test-unit-async-job-repository.R:191:    "request_hash",
api/tests/testthat/test-unit-async-job-repository.R-192-    "request_payload_json",
api/tests/testthat/test-unit-async-job-repository.R-193-    "submitted_by",
api/tests/testthat/test-unit-async-job-repository.R-194-    "scheduled_at",
api/tests/testthat/test-unit-async-job-repository.R-195-    "claim_token",
api/tests/testthat/test-unit-async-job-repository.R-196-    "worker_hostname",
api/tests/testthat/test-unit-async-job-repository.R-197-    "worker_pid",
api/tests/testthat/test-unit-async-job-repository.R-198-    "last_heartbeat_at",
api/tests/testthat/test-unit-async-job-repository.R-199-    "claim_expires_at",
api/tests/testthat/test-unit-async-job-repository.R-200-    "next_attempt_at",
api/tests/testthat/test-unit-async-job-repository.R-201-    "progress_pct",
api/tests/testthat/test-unit-async-job-repository.R-202-    "progress_message",
api/tests/testthat/test-unit-async-job-repository.R-203-    "cancelled_by",
--
api/tests/testthat/test-unit-async-job-repository.R-216-
api/tests/testthat/test-unit-async-job-repository.R-217-  with_async_job_test_connection({
api/tests/testthat/test-unit-async-job-repository.R-218-    conn <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-repository.R-219-    submitted_at <- as.POSIXct("2026-04-23 09:00:00", tz = "UTC")
api/tests/testthat/test-unit-async-job-repository.R-220-
api/tests/testthat/test-unit-async-job-repository.R-221-    job_id <- async_job_repository_create(
api/tests/testthat/test-unit-async-job-repository.R-222-      list(
api/tests/testthat/test-unit-async-job-repository.R-223-        job_id = "job-create-get",
api/tests/testthat/test-unit-async-job-repository.R-224-        job_type = "comparisons_update",
api/tests/testthat/test-unit-async-job-repository.R-225-        queue_name = "bulk",
api/tests/testthat/test-unit-async-job-repository.R-226-        priority = 10L,
api/tests/testthat/test-unit-async-job-repository.R-227-        request_payload_json = "{\"operation\":\"comparisons_update\"}",
api/tests/testthat/test-unit-async-job-repository.R:228:        request_hash = "hash-create-get",
api/tests/testthat/test-unit-async-job-repository.R-229-        submitted_by = NULL,
api/tests/testthat/test-unit-async-job-repository.R-230-        submitted_at = submitted_at,
api/tests/testthat/test-unit-async-job-repository.R-231-        scheduled_at = submitted_at,
api/tests/testthat/test-unit-async-job-repository.R-232-        max_attempts = 3L
api/tests/testthat/test-unit-async-job-repository.R-233-      ),
api/tests/testthat/test-unit-async-job-repository.R-234-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-235-    )
api/tests/testthat/test-unit-async-job-repository.R-236-
api/tests/testthat/test-unit-async-job-repository.R-237-    stored_poll <- async_job_repository_get(job_id, conn = conn)
api/tests/testthat/test-unit-async-job-repository.R-238-    stored_full <- async_job_repository_get(job_id, include_result = TRUE, conn = conn)
api/tests/testthat/test-unit-async-job-repository.R-239-
api/tests/testthat/test-unit-async-job-repository.R-240-    expect_equal(job_id, "job-create-get")
--
api/tests/testthat/test-unit-async-job-repository.R-249-
api/tests/testthat/test-unit-async-job-repository.R-250-test_that("async_job_repository_find_active_duplicate ignores terminal jobs", {
api/tests/testthat/test-unit-async-job-repository.R-251-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-repository.R-252-  ensure_async_job_repository_loaded()
api/tests/testthat/test-unit-async-job-repository.R-253-  ensure_async_job_schema()
api/tests/testthat/test-unit-async-job-repository.R-254-
api/tests/testthat/test-unit-async-job-repository.R-255-  with_async_job_test_connection({
api/tests/testthat/test-unit-async-job-repository.R-256-    conn <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-repository.R-257-
api/tests/testthat/test-unit-async-job-repository.R-258-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-259-      conn,
api/tests/testthat/test-unit-async-job-repository.R-260-      job_id = "job-duplicate-completed",
api/tests/testthat/test-unit-async-job-repository.R:261:      request_hash = "dup-hash",
api/tests/testthat/test-unit-async-job-repository.R-262-      status = "completed"
api/tests/testthat/test-unit-async-job-repository.R-263-    )
api/tests/testthat/test-unit-async-job-repository.R-264-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-265-      conn,
api/tests/testthat/test-unit-async-job-repository.R-266-      job_id = "job-duplicate-running",
api/tests/testthat/test-unit-async-job-repository.R:267:      request_hash = "dup-hash",
api/tests/testthat/test-unit-async-job-repository.R-268-      status = "running",
api/tests/testthat/test-unit-async-job-repository.R-269-      claimed_by_worker = "worker-a",
api/tests/testthat/test-unit-async-job-repository.R-270-      claim_token = "claim-duplicate-running",
api/tests/testthat/test-unit-async-job-repository.R-271-      worker_hostname = "host-a",
api/tests/testthat/test-unit-async-job-repository.R-272-      worker_pid = 1001L,
api/tests/testthat/test-unit-async-job-repository.R-273-      started_at = Sys.time(),
api/tests/testthat/test-unit-async-job-repository.R-274-      last_heartbeat_at = Sys.time(),
api/tests/testthat/test-unit-async-job-repository.R-275-      claim_expires_at = Sys.time() + 60
api/tests/testthat/test-unit-async-job-repository.R-276-    )
api/tests/testthat/test-unit-async-job-repository.R-277-
api/tests/testthat/test-unit-async-job-repository.R-278-    duplicate <- async_job_repository_find_active_duplicate(
api/tests/testthat/test-unit-async-job-repository.R-279-      job_type = "hgnc_update",
api/tests/testthat/test-unit-async-job-repository.R:280:      request_hash = "dup-hash",
api/tests/testthat/test-unit-async-job-repository.R-281-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-282-    )
api/tests/testthat/test-unit-async-job-repository.R-283-
api/tests/testthat/test-unit-async-job-repository.R-284-    expect_equal(duplicate$job_id[[1]], "job-duplicate-running")
api/tests/testthat/test-unit-async-job-repository.R-285-    expect_equal(duplicate$status[[1]], "running")
api/tests/testthat/test-unit-async-job-repository.R-286-
api/tests/testthat/test-unit-async-job-repository.R-287-    async_job_repository_fail(
api/tests/testthat/test-unit-async-job-repository.R-288-      job_id = "job-duplicate-running",
api/tests/testthat/test-unit-async-job-repository.R-289-      error_code = "RETRY",
api/tests/testthat/test-unit-async-job-repository.R-290-      error_message = "Retry later",
api/tests/testthat/test-unit-async-job-repository.R-291-      claim_token = duplicate$claim_token[[1]],
api/tests/testthat/test-unit-async-job-repository.R-292-      next_attempt_at = Sys.time() + 60,
api/tests/testthat/test-unit-async-job-repository.R-293-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-294-    )
api/tests/testthat/test-unit-async-job-repository.R-295-
api/tests/testthat/test-unit-async-job-repository.R-296-    retry_duplicate <- async_job_repository_find_active_duplicate(
api/tests/testthat/test-unit-async-job-repository.R-297-      job_type = "hgnc_update",
api/tests/testthat/test-unit-async-job-repository.R:298:      request_hash = "dup-hash",
api/tests/testthat/test-unit-async-job-repository.R-299-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-300-    )
api/tests/testthat/test-unit-async-job-repository.R-301-
api/tests/testthat/test-unit-async-job-repository.R-302-    expect_equal(retry_duplicate$job_id[[1]], "job-duplicate-running")
api/tests/testthat/test-unit-async-job-repository.R-303-    expect_equal(retry_duplicate$status[[1]], "failed")
api/tests/testthat/test-unit-async-job-repository.R-304-  })
api/tests/testthat/test-unit-async-job-repository.R-305-})
api/tests/testthat/test-unit-async-job-repository.R-306-
api/tests/testthat/test-unit-async-job-repository.R-307-test_that("async_job_repository_create raises durable duplicate error for concurrent active hash", {
api/tests/testthat/test-unit-async-job-repository.R-308-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-repository.R-309-  ensure_async_job_repository_loaded()
api/tests/testthat/test-unit-async-job-repository.R-310-  ensure_async_job_schema()
api/tests/testthat/test-unit-async-job-repository.R-311-
api/tests/testthat/test-unit-async-job-repository.R-312-  with_async_job_test_connection({
api/tests/testthat/test-unit-async-job-repository.R-313-    conn <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-repository.R-314-
api/tests/testthat/test-unit-async-job-repository.R-315-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-316-      conn,
api/tests/testthat/test-unit-async-job-repository.R-317-      job_id = "job-duplicate-existing",
api/tests/testthat/test-unit-async-job-repository.R:318:      request_hash = "durable-dup-hash",
api/tests/testthat/test-unit-async-job-repository.R-319-      status = "queued"
api/tests/testthat/test-unit-async-job-repository.R-320-    )
api/tests/testthat/test-unit-async-job-repository.R-321-
api/tests/testthat/test-unit-async-job-repository.R-322-    expect_error(
api/tests/testthat/test-unit-async-job-repository.R-323-      async_job_repository_create(
api/tests/testthat/test-unit-async-job-repository.R-324-        list(
api/tests/testthat/test-unit-async-job-repository.R-325-          job_id = "job-duplicate-new",
api/tests/testthat/test-unit-async-job-repository.R-326-          job_type = "hgnc_update",
api/tests/testthat/test-unit-async-job-repository.R-327-          queue_name = "default",
api/tests/testthat/test-unit-async-job-repository.R-328-          priority = 100L,
api/tests/testthat/test-unit-async-job-repository.R-329-          request_payload_json = "{\"operation\":\"hgnc_update\"}",
api/tests/testthat/test-unit-async-job-repository.R:330:          request_hash = "durable-dup-hash",
api/tests/testthat/test-unit-async-job-repository.R-331-          scheduled_at = Sys.time(),
api/tests/testthat/test-unit-async-job-repository.R-332-          max_attempts = 1L
api/tests/testthat/test-unit-async-job-repository.R-333-        ),
api/tests/testthat/test-unit-async-job-repository.R-334-        conn = conn
api/tests/testthat/test-unit-async-job-repository.R-335-      ),
api/tests/testthat/test-unit-async-job-repository.R:336:      class = "async_job_duplicate_error"
api/tests/testthat/test-unit-async-job-repository.R-337-    )
api/tests/testthat/test-unit-async-job-repository.R-338-  })
api/tests/testthat/test-unit-async-job-repository.R-339-})
api/tests/testthat/test-unit-async-job-repository.R-340-
api/tests/testthat/test-unit-async-job-repository.R-341-test_that("async_job_repository_claim_next claims one eligible job and marks it running", {
api/tests/testthat/test-unit-async-job-repository.R-342-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-repository.R-343-  ensure_async_job_repository_loaded()
api/tests/testthat/test-unit-async-job-repository.R-344-  ensure_async_job_schema()
api/tests/testthat/test-unit-async-job-repository.R-345-
api/tests/testthat/test-unit-async-job-repository.R-346-  with_async_job_test_connection({
api/tests/testthat/test-unit-async-job-repository.R-347-    conn <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-repository.R-348-
api/tests/testthat/test-unit-async-job-repository.R-349-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-350-      conn,
api/tests/testthat/test-unit-async-job-repository.R-351-      job_id = "job-claim-queued",
api/tests/testthat/test-unit-async-job-repository.R-352-      queue_name = "default",
api/tests/testthat/test-unit-async-job-repository.R-353-      priority = 5L,
api/tests/testthat/test-unit-async-job-repository.R:354:      request_hash = "claim-hash-queued",
api/tests/testthat/test-unit-async-job-repository.R-355-      scheduled_at = as.POSIXct("2026-04-23 08:59:00", tz = "UTC"),
api/tests/testthat/test-unit-async-job-repository.R-356-      max_attempts = 2L
api/tests/testthat/test-unit-async-job-repository.R-357-    )
api/tests/testthat/test-unit-async-job-repository.R-358-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-359-      conn,
api/tests/testthat/test-unit-async-job-repository.R-360-      job_id = "job-claim-retry",
api/tests/testthat/test-unit-async-job-repository.R:361:      request_hash = "claim-hash-retry",
api/tests/testthat/test-unit-async-job-repository.R-362-      priority = 5L,
api/tests/testthat/test-unit-async-job-repository.R-363-      status = "failed",
api/tests/testthat/test-unit-async-job-repository.R-364-      attempt_count = 1L,
api/tests/testthat/test-unit-async-job-repository.R-365-      max_attempts = 3L,
api/tests/testthat/test-unit-async-job-repository.R-366-      next_attempt_at = as.POSIXct("2026-04-23 08:58:00", tz = "UTC"),
api/tests/testthat/test-unit-async-job-repository.R-367-      scheduled_at = as.POSIXct("2026-04-23 08:50:00", tz = "UTC")
api/tests/testthat/test-unit-async-job-repository.R-368-    )
api/tests/testthat/test-unit-async-job-repository.R-369-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-370-      conn,
api/tests/testthat/test-unit-async-job-repository.R-371-      job_id = "job-claim-later",
api/tests/testthat/test-unit-async-job-repository.R:372:      request_hash = "claim-hash-later",
api/tests/testthat/test-unit-async-job-repository.R-373-      priority = 1L,
api/tests/testthat/test-unit-async-job-repository.R-374-      scheduled_at = Sys.time() + 3600
api/tests/testthat/test-unit-async-job-repository.R-375-    )
api/tests/testthat/test-unit-async-job-repository.R-376-
api/tests/testthat/test-unit-async-job-repository.R-377-    claimed <- async_job_repository_claim_next(
api/tests/testthat/test-unit-async-job-repository.R-378-      worker_id = "worker-a",
api/tests/testthat/test-unit-async-job-repository.R-379-      worker_hostname = "host-a",
api/tests/testthat/test-unit-async-job-repository.R-380-      worker_pid = 4242L,
api/tests/testthat/test-unit-async-job-repository.R-381-      lease_seconds = 60L,
api/tests/testthat/test-unit-async-job-repository.R-382-      queues = "default",
api/tests/testthat/test-unit-async-job-repository.R-383-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-384-    )
--
api/tests/testthat/test-unit-async-job-repository.R-398-      worker_pid = 4343L,
api/tests/testthat/test-unit-async-job-repository.R-399-      lease_seconds = 60L,
api/tests/testthat/test-unit-async-job-repository.R-400-      queues = "default",
api/tests/testthat/test-unit-async-job-repository.R-401-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-402-    )
api/tests/testthat/test-unit-async-job-repository.R-403-
api/tests/testthat/test-unit-async-job-repository.R-404-    expect_equal(second_claim$job_id[[1]], "job-claim-queued")
api/tests/testthat/test-unit-async-job-repository.R-405-    expect_equal(second_claim$attempt_count[[1]], 1L)
api/tests/testthat/test-unit-async-job-repository.R-406-
api/tests/testthat/test-unit-async-job-repository.R-407-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-408-      conn,
api/tests/testthat/test-unit-async-job-repository.R-409-      job_id = "job-claim-retry-earlier",
api/tests/testthat/test-unit-async-job-repository.R:410:      request_hash = "claim-hash-retry-earlier",
api/tests/testthat/test-unit-async-job-repository.R-411-      priority = 5L,
api/tests/testthat/test-unit-async-job-repository.R-412-      status = "failed",
api/tests/testthat/test-unit-async-job-repository.R-413-      attempt_count = 1L,
api/tests/testthat/test-unit-async-job-repository.R-414-      max_attempts = 3L,
api/tests/testthat/test-unit-async-job-repository.R-415-      next_attempt_at = as.POSIXct("2026-04-23 08:55:00", tz = "UTC"),
api/tests/testthat/test-unit-async-job-repository.R-416-      scheduled_at = as.POSIXct("2026-04-23 08:59:30", tz = "UTC")
api/tests/testthat/test-unit-async-job-repository.R-417-    )
api/tests/testthat/test-unit-async-job-repository.R-418-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-419-      conn,
api/tests/testthat/test-unit-async-job-repository.R-420-      job_id = "job-claim-retry-later",
api/tests/testthat/test-unit-async-job-repository.R:421:      request_hash = "claim-hash-retry-later",
api/tests/testthat/test-unit-async-job-repository.R-422-      priority = 5L,
api/tests/testthat/test-unit-async-job-repository.R-423-      status = "failed",
api/tests/testthat/test-unit-async-job-repository.R-424-      attempt_count = 1L,
api/tests/testthat/test-unit-async-job-repository.R-425-      max_attempts = 3L,
api/tests/testthat/test-unit-async-job-repository.R-426-      next_attempt_at = as.POSIXct("2026-04-23 08:57:00", tz = "UTC"),
api/tests/testthat/test-unit-async-job-repository.R-427-      scheduled_at = as.POSIXct("2026-04-23 08:40:00", tz = "UTC")
api/tests/testthat/test-unit-async-job-repository.R-428-    )
api/tests/testthat/test-unit-async-job-repository.R-429-
api/tests/testthat/test-unit-async-job-repository.R-430-    retry_order_claim <- async_job_repository_claim_next(
api/tests/testthat/test-unit-async-job-repository.R-431-      worker_id = "worker-c",
api/tests/testthat/test-unit-async-job-repository.R-432-      worker_hostname = "host-c",
api/tests/testthat/test-unit-async-job-repository.R-433-      worker_pid = 4444L,
--
api/tests/testthat/test-unit-async-job-repository.R-448-  with_async_job_test_connection({
api/tests/testthat/test-unit-async-job-repository.R-449-    conn <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-repository.R-450-
api/tests/testthat/test-unit-async-job-repository.R-451-    # Mirrors the routing async_job_service_submit() now applies: heavy
api/tests/testthat/test-unit-async-job-repository.R-452-    # publication_date_backfill -> "maintenance" lane; interactive llm_generation
api/tests/testthat/test-unit-async-job-repository.R-453-    # -> "default" lane.
api/tests/testthat/test-unit-async-job-repository.R-454-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-455-      conn,
api/tests/testthat/test-unit-async-job-repository.R-456-      job_id = "job-lane-llm",
api/tests/testthat/test-unit-async-job-repository.R-457-      job_type = "llm_generation",
api/tests/testthat/test-unit-async-job-repository.R-458-      queue_name = "default",
api/tests/testthat/test-unit-async-job-repository.R-459-      priority = 10L,
api/tests/testthat/test-unit-async-job-repository.R:460:      request_hash = "lane-hash-llm"
api/tests/testthat/test-unit-async-job-repository.R-461-    )
api/tests/testthat/test-unit-async-job-repository.R-462-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-463-      conn,
api/tests/testthat/test-unit-async-job-repository.R-464-      job_id = "job-lane-backfill",
api/tests/testthat/test-unit-async-job-repository.R-465-      job_type = "publication_date_backfill",
api/tests/testthat/test-unit-async-job-repository.R-466-      queue_name = "maintenance",
api/tests/testthat/test-unit-async-job-repository.R-467-      priority = 50L,
api/tests/testthat/test-unit-async-job-repository.R:468:      request_hash = "lane-hash-backfill"
api/tests/testthat/test-unit-async-job-repository.R-469-    )
api/tests/testthat/test-unit-async-job-repository.R-470-
api/tests/testthat/test-unit-async-job-repository.R-471-    # The interactive worker (default lane) claims llm_generation ...
api/tests/testthat/test-unit-async-job-repository.R-472-    default_claim <- async_job_repository_claim_next(
api/tests/testthat/test-unit-async-job-repository.R-473-      worker_id = "worker-default",
api/tests/testthat/test-unit-async-job-repository.R-474-      worker_hostname = "host-default",
api/tests/testthat/test-unit-async-job-repository.R-475-      worker_pid = 7001L,
api/tests/testthat/test-unit-async-job-repository.R-476-      lease_seconds = 60L,
api/tests/testthat/test-unit-async-job-repository.R-477-      queues = "default",
api/tests/testthat/test-unit-async-job-repository.R-478-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-479-    )
api/tests/testthat/test-unit-async-job-repository.R-480-    expect_equal(default_claim$job_id[[1]], "job-lane-llm")
--
api/tests/testthat/test-unit-async-job-repository.R-512-  with_async_job_test_connection({
api/tests/testthat/test-unit-async-job-repository.R-513-    conn <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-repository.R-514-
api/tests/testthat/test-unit-async-job-repository.R-515-    # Both on the same lane: the lower interactive priority number must win even
api/tests/testthat/test-unit-async-job-repository.R-516-    # when the backfill was submitted first (belt-and-suspenders for the inverted
api/tests/testthat/test-unit-async-job-repository.R-517-    # priority the routing fix corrects).
api/tests/testthat/test-unit-async-job-repository.R-518-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-519-      conn,
api/tests/testthat/test-unit-async-job-repository.R-520-      job_id = "job-prio-backfill",
api/tests/testthat/test-unit-async-job-repository.R-521-      job_type = "publication_date_backfill",
api/tests/testthat/test-unit-async-job-repository.R-522-      queue_name = "default",
api/tests/testthat/test-unit-async-job-repository.R-523-      priority = 50L,
api/tests/testthat/test-unit-async-job-repository.R:524:      request_hash = "prio-hash-backfill",
api/tests/testthat/test-unit-async-job-repository.R-525-      scheduled_at = as.POSIXct("2026-07-03 10:00:00", tz = "UTC")
api/tests/testthat/test-unit-async-job-repository.R-526-    )
api/tests/testthat/test-unit-async-job-repository.R-527-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-528-      conn,
api/tests/testthat/test-unit-async-job-repository.R-529-      job_id = "job-prio-llm",
api/tests/testthat/test-unit-async-job-repository.R-530-      job_type = "llm_generation",
api/tests/testthat/test-unit-async-job-repository.R-531-      queue_name = "default",
api/tests/testthat/test-unit-async-job-repository.R-532-      priority = 10L,
api/tests/testthat/test-unit-async-job-repository.R:533:      request_hash = "prio-hash-llm",
api/tests/testthat/test-unit-async-job-repository.R-534-      scheduled_at = as.POSIXct("2026-07-03 10:05:00", tz = "UTC")
api/tests/testthat/test-unit-async-job-repository.R-535-    )
api/tests/testthat/test-unit-async-job-repository.R-536-
api/tests/testthat/test-unit-async-job-repository.R-537-    claim <- async_job_repository_claim_next(
api/tests/testthat/test-unit-async-job-repository.R-538-      worker_id = "worker-prio",
api/tests/testthat/test-unit-async-job-repository.R-539-      worker_hostname = "host-prio",
api/tests/testthat/test-unit-async-job-repository.R-540-      worker_pid = 7003L,
api/tests/testthat/test-unit-async-job-repository.R-541-      lease_seconds = 60L,
api/tests/testthat/test-unit-async-job-repository.R-542-      queues = "default",
api/tests/testthat/test-unit-async-job-repository.R-543-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-544-    )
api/tests/testthat/test-unit-async-job-repository.R-545-    expect_equal(claim$job_id[[1]], "job-prio-llm")
api/tests/testthat/test-unit-async-job-repository.R-546-  })
api/tests/testthat/test-unit-async-job-repository.R-547-})
api/tests/testthat/test-unit-async-job-repository.R-548-
api/tests/testthat/test-unit-async-job-repository.R-549-test_that("async job repository updates progress, appends events, heartbeats, and completes", {
api/tests/testthat/test-unit-async-job-repository.R-550-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-repository.R-551-  ensure_async_job_repository_loaded()
api/tests/testthat/test-unit-async-job-repository.R-552-  ensure_async_job_schema()
api/tests/testthat/test-unit-async-job-repository.R-553-
api/tests/testthat/test-unit-async-job-repository.R-554-  with_async_job_test_connection({
api/tests/testthat/test-unit-async-job-repository.R-555-    conn <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-repository.R-556-
api/tests/testthat/test-unit-async-job-repository.R:557:    seed_async_job(conn, job_id = "job-progress", request_hash = "progress-hash")
api/tests/testthat/test-unit-async-job-repository.R-558-    claimed <- async_job_repository_claim_next(
api/tests/testthat/test-unit-async-job-repository.R-559-      worker_id = "worker-progress",
api/tests/testthat/test-unit-async-job-repository.R-560-      worker_hostname = "host-progress",
api/tests/testthat/test-unit-async-job-repository.R-561-      worker_pid = 5151L,
api/tests/testthat/test-unit-async-job-repository.R-562-      lease_seconds = 30L,
api/tests/testthat/test-unit-async-job-repository.R-563-      queues = "default",
api/tests/testthat/test-unit-async-job-repository.R-564-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-565-    )
api/tests/testthat/test-unit-async-job-repository.R-566-
api/tests/testthat/test-unit-async-job-repository.R-567-    async_job_repository_update_progress(
api/tests/testthat/test-unit-async-job-repository.R-568-      job_id = "job-progress",
api/tests/testthat/test-unit-async-job-repository.R-569-      progress_pct = 55.5,
--
api/tests/testthat/test-unit-async-job-repository.R-609-    expect_equal(events$event_message[[1]], "Milestone reached")
api/tests/testthat/test-unit-async-job-repository.R-610-  })
api/tests/testthat/test-unit-async-job-repository.R-611-})
api/tests/testthat/test-unit-async-job-repository.R-612-
api/tests/testthat/test-unit-async-job-repository.R-613-test_that("async job repository mutators reject stale claim tokens", {
api/tests/testthat/test-unit-async-job-repository.R-614-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-repository.R-615-  ensure_async_job_repository_loaded()
api/tests/testthat/test-unit-async-job-repository.R-616-  ensure_async_job_schema()
api/tests/testthat/test-unit-async-job-repository.R-617-
api/tests/testthat/test-unit-async-job-repository.R-618-  with_async_job_test_connection({
api/tests/testthat/test-unit-async-job-repository.R-619-    conn <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-repository.R-620-
api/tests/testthat/test-unit-async-job-repository.R:621:    seed_async_job(conn, job_id = "job-stale-token", request_hash = "stale-token-hash")
api/tests/testthat/test-unit-async-job-repository.R-622-    claimed <- async_job_repository_claim_next(
api/tests/testthat/test-unit-async-job-repository.R-623-      worker_id = "worker-token",
api/tests/testthat/test-unit-async-job-repository.R-624-      worker_hostname = "host-token",
api/tests/testthat/test-unit-async-job-repository.R-625-      worker_pid = 6060L,
api/tests/testthat/test-unit-async-job-repository.R-626-      lease_seconds = 30L,
api/tests/testthat/test-unit-async-job-repository.R-627-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-628-    )
api/tests/testthat/test-unit-async-job-repository.R-629-
api/tests/testthat/test-unit-async-job-repository.R-630-    progress_rows <- async_job_repository_update_progress(
api/tests/testthat/test-unit-async-job-repository.R-631-      job_id = "job-stale-token",
api/tests/testthat/test-unit-async-job-repository.R-632-      progress_pct = 10,
api/tests/testthat/test-unit-async-job-repository.R-633-      progress_message = "stale",
--
api/tests/testthat/test-unit-async-job-repository.R-657-    expect_equal(stored$claim_token[[1]], claimed$claim_token[[1]])
api/tests/testthat/test-unit-async-job-repository.R-658-  })
api/tests/testthat/test-unit-async-job-repository.R-659-})
api/tests/testthat/test-unit-async-job-repository.R-660-
api/tests/testthat/test-unit-async-job-repository.R-661-test_that("async job repository fail, cancel, and stale recovery follow durable status rules", {
api/tests/testthat/test-unit-async-job-repository.R-662-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-repository.R-663-  ensure_async_job_repository_loaded()
api/tests/testthat/test-unit-async-job-repository.R-664-  ensure_async_job_schema()
api/tests/testthat/test-unit-async-job-repository.R-665-
api/tests/testthat/test-unit-async-job-repository.R-666-  with_async_job_test_connection({
api/tests/testthat/test-unit-async-job-repository.R-667-    conn <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-repository.R-668-
api/tests/testthat/test-unit-async-job-repository.R:669:    seed_async_job(conn, job_id = "job-fail", request_hash = "fail-hash", max_attempts = 3L)
api/tests/testthat/test-unit-async-job-repository.R-670-    claimed_fail <- async_job_repository_claim_next(
api/tests/testthat/test-unit-async-job-repository.R-671-      worker_id = "worker-fail",
api/tests/testthat/test-unit-async-job-repository.R-672-      worker_hostname = "host-fail",
api/tests/testthat/test-unit-async-job-repository.R-673-      worker_pid = 6161L,
api/tests/testthat/test-unit-async-job-repository.R-674-      lease_seconds = 30L,
api/tests/testthat/test-unit-async-job-repository.R-675-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-676-    )
api/tests/testthat/test-unit-async-job-repository.R-677-    retry_at <- as.POSIXct("2026-04-23 09:05:00", tz = "UTC")
api/tests/testthat/test-unit-async-job-repository.R-678-    async_job_repository_fail(
api/tests/testthat/test-unit-async-job-repository.R-679-      job_id = "job-fail",
api/tests/testthat/test-unit-async-job-repository.R-680-      error_code = "TRANSIENT",
api/tests/testthat/test-unit-async-job-repository.R-681-      error_message = "Retry later",
--
api/tests/testthat/test-unit-async-job-repository.R-688-    expect_equal(failed$status[[1]], "failed")
api/tests/testthat/test-unit-async-job-repository.R-689-    expect_equal(failed$last_error_code[[1]], "TRANSIENT")
api/tests/testthat/test-unit-async-job-repository.R-690-    expect_equal(as.character(failed$next_attempt_at[[1]]), as.character(retry_at))
api/tests/testthat/test-unit-async-job-repository.R-691-
api/tests/testthat/test-unit-async-job-repository.R-692-    expect_error(
api/tests/testthat/test-unit-async-job-repository.R-693-      async_job_repository_create(
api/tests/testthat/test-unit-async-job-repository.R-694-        list(
api/tests/testthat/test-unit-async-job-repository.R-695-          job_id = "job-fail",
api/tests/testthat/test-unit-async-job-repository.R-696-          job_type = "hgnc_update",
api/tests/testthat/test-unit-async-job-repository.R-697-          queue_name = "default",
api/tests/testthat/test-unit-async-job-repository.R-698-          priority = 100L,
api/tests/testthat/test-unit-async-job-repository.R-699-          request_payload_json = "{\"operation\":\"hgnc_update\"}",
api/tests/testthat/test-unit-async-job-repository.R:700:          request_hash = "different-hash",
api/tests/testthat/test-unit-async-job-repository.R-701-          scheduled_at = Sys.time(),
api/tests/testthat/test-unit-async-job-repository.R-702-          max_attempts = 1L
api/tests/testthat/test-unit-async-job-repository.R-703-        ),
api/tests/testthat/test-unit-async-job-repository.R-704-        conn = conn
api/tests/testthat/test-unit-async-job-repository.R-705-      ),
api/tests/testthat/test-unit-async-job-repository.R-706-      class = "db_statement_error"
api/tests/testthat/test-unit-async-job-repository.R-707-    )
api/tests/testthat/test-unit-async-job-repository.R-708-
api/tests/testthat/test-unit-async-job-repository.R-709-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-710-      conn,
api/tests/testthat/test-unit-async-job-repository.R-711-      job_id = "job-cancel-running",
api/tests/testthat/test-unit-async-job-repository.R:712:      request_hash = "cancel-running-hash",
api/tests/testthat/test-unit-async-job-repository.R-713-      status = "running",
api/tests/testthat/test-unit-async-job-repository.R-714-      claimed_by_worker = "worker-cancel",
api/tests/testthat/test-unit-async-job-repository.R-715-      claim_token = "claim-cancel-running",
api/tests/testthat/test-unit-async-job-repository.R-716-      worker_hostname = "host-cancel",
api/tests/testthat/test-unit-async-job-repository.R-717-      worker_pid = 7171L,
api/tests/testthat/test-unit-async-job-repository.R-718-      started_at = Sys.time() - 30,
api/tests/testthat/test-unit-async-job-repository.R-719-      last_heartbeat_at = Sys.time() - 5,
api/tests/testthat/test-unit-async-job-repository.R-720-      claim_expires_at = Sys.time() + 30
api/tests/testthat/test-unit-async-job-repository.R-721-    )
api/tests/testthat/test-unit-async-job-repository.R-722-    async_job_repository_cancel("job-cancel-running", cancelled_by = NULL, conn = conn)
api/tests/testthat/test-unit-async-job-repository.R-723-    cancelled_request <- async_job_repository_get("job-cancel-running", conn = conn)
api/tests/testthat/test-unit-async-job-repository.R-724-    expect_equal(cancelled_request$status[[1]], "cancel_requested")
api/tests/testthat/test-unit-async-job-repository.R-725-    heartbeat_rows <- async_job_repository_heartbeat(
api/tests/testthat/test-unit-async-job-repository.R-726-      job_id = "job-cancel-running",
api/tests/testthat/test-unit-async-job-repository.R-727-      lease_seconds = 60L,
api/tests/testthat/test-unit-async-job-repository.R-728-      claim_token = "claim-cancel-running",
api/tests/testthat/test-unit-async-job-repository.R-729-      conn = conn
api/tests/testthat/test-unit-async-job-repository.R-730-    )
api/tests/testthat/test-unit-async-job-repository.R-731-    expect_equal(heartbeat_rows, 1L)
api/tests/testthat/test-unit-async-job-repository.R-732-
api/tests/testthat/test-unit-async-job-repository.R:733:    seed_async_job(conn, job_id = "job-cancel-queued", request_hash = "cancel-queued-hash")
api/tests/testthat/test-unit-async-job-repository.R-734-    async_job_repository_cancel("job-cancel-queued", cancelled_by = NULL, conn = conn)
api/tests/testthat/test-unit-async-job-repository.R-735-    cancelled <- async_job_repository_get("job-cancel-queued", conn = conn)
api/tests/testthat/test-unit-async-job-repository.R-736-    expect_equal(cancelled$status[[1]], "cancelled")
api/tests/testthat/test-unit-async-job-repository.R-737-    expect_false(is.na(cancelled$completed_at[[1]]))
api/tests/testthat/test-unit-async-job-repository.R-738-
api/tests/testthat/test-unit-async-job-repository.R-739-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-740-      conn,
api/tests/testthat/test-unit-async-job-repository.R-741-      job_id = "job-cancel-completed",
api/tests/testthat/test-unit-async-job-repository.R:742:      request_hash = "cancel-completed-hash",
api/tests/testthat/test-unit-async-job-repository.R-743-      status = "completed",
api/tests/testthat/test-unit-async-job-repository.R-744-      completed_at = Sys.time()
api/tests/testthat/test-unit-async-job-repository.R-745-    )
api/tests/testthat/test-unit-async-job-repository.R-746-    async_job_repository_cancel("job-cancel-completed", cancelled_by = 42L, conn = conn)
api/tests/testthat/test-unit-async-job-repository.R-747-    completed_after_cancel <- async_job_repository_get("job-cancel-completed", conn = conn)
api/tests/testthat/test-unit-async-job-repository.R-748-    expect_equal(completed_after_cancel$status[[1]], "completed")
api/tests/testthat/test-unit-async-job-repository.R-749-    expect_true(is.na(completed_after_cancel$cancelled_by[[1]]))
api/tests/testthat/test-unit-async-job-repository.R-750-
api/tests/testthat/test-unit-async-job-repository.R-751-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-752-      conn,
api/tests/testthat/test-unit-async-job-repository.R-753-      job_id = "job-stale-retry",
api/tests/testthat/test-unit-async-job-repository.R:754:      request_hash = "stale-retry-hash",
api/tests/testthat/test-unit-async-job-repository.R-755-      status = "running",
api/tests/testthat/test-unit-async-job-repository.R-756-      attempt_count = 1L,
api/tests/testthat/test-unit-async-job-repository.R-757-      max_attempts = 3L,
api/tests/testthat/test-unit-async-job-repository.R-758-      claimed_by_worker = "worker-stale",
api/tests/testthat/test-unit-async-job-repository.R-759-      worker_hostname = "host-stale",
api/tests/testthat/test-unit-async-job-repository.R-760-      worker_pid = 8181L,
api/tests/testthat/test-unit-async-job-repository.R-761-      started_at = Sys.time() - 300,
api/tests/testthat/test-unit-async-job-repository.R-762-      last_heartbeat_at = Sys.time() - 300,
api/tests/testthat/test-unit-async-job-repository.R-763-      claim_expires_at = Sys.time() - 120
api/tests/testthat/test-unit-async-job-repository.R-764-    )
api/tests/testthat/test-unit-async-job-repository.R-765-    seed_async_job(
api/tests/testthat/test-unit-async-job-repository.R-766-      conn,
api/tests/testthat/test-unit-async-job-repository.R-767-      job_id = "job-stale-terminal",
api/tests/testthat/test-unit-async-job-repository.R:768:      request_hash = "stale-terminal-hash",
api/tests/testthat/test-unit-async-job-repository.R-769-      status = "running",
api/tests/testthat/test-unit-async-job-repository.R-770-      attempt_count = 1L,
api/tests/testthat/test-unit-async-job-repository.R-771-      max_attempts = 1L,
api/tests/testthat/test-unit-async-job-repository.R-772-      claimed_by_worker = "worker-terminal",
api/tests/testthat/test-unit-async-job-repository.R-773-      worker_hostname = "host-terminal",
api/tests/testthat/test-unit-async-job-repository.R-774-      worker_pid = 9191L,
api/tests/testthat/test-unit-async-job-repository.R-775-      started_at = Sys.time() - 300,
api/tests/testthat/test-unit-async-job-repository.R-776-      last_heartbeat_at = Sys.time() - 300,
api/tests/testthat/test-unit-async-job-repository.R-777-      claim_expires_at = Sys.time() - 120
api/tests/testthat/test-unit-async-job-repository.R-778-    )
api/tests/testthat/test-unit-async-job-repository.R-779-
api/tests/testthat/test-unit-async-job-repository.R-780-    recovered <- async_job_repository_recover_stale(now = Sys.time(), conn = conn)
--
api/tests/testthat/test-unit-async-job-repository.R-786-    expect_equal(stale_retry$status[[1]], "queued")
api/tests/testthat/test-unit-async-job-repository.R-787-    expect_true(is.na(stale_retry$next_attempt_at[[1]]))
api/tests/testthat/test-unit-async-job-repository.R-788-    expect_false(is.na(stale_retry$scheduled_at[[1]]))
api/tests/testthat/test-unit-async-job-repository.R-789-    expect_true(is.na(stale_retry$completed_at[[1]]))
api/tests/testthat/test-unit-async-job-repository.R-790-    expect_true(is.na(stale_retry$claimed_by_worker[[1]]))
api/tests/testthat/test-unit-async-job-repository.R-791-    expect_equal(stale_terminal$status[[1]], "failed")
api/tests/testthat/test-unit-async-job-repository.R-792-    expect_true(is.na(stale_terminal$next_attempt_at[[1]]))
api/tests/testthat/test-unit-async-job-repository.R-793-    expect_equal(stale_terminal$last_error_code[[1]], "LEASE_EXPIRED")
api/tests/testthat/test-unit-async-job-repository.R-794-
7-api/tests/testthat/test-nddscore-endpoints.R:92:    submitted <- async_job_service_submit(
8-api/tests/testthat/test-nddscore-endpoints.R-93-      job_type = "nddscore_import",
9-api/tests/testthat/test-nddscore-endpoints.R-94-      request_payload = list(record_id = "20258027", validate_only = TRUE),
10-api/tests/testthat/test-nddscore-endpoints.R-95-      submitted_by = NULL)
11:api/tests/testthat/test-nddscore-endpoints.R-96-    expect_true(submitted$created || submitted$duplicate)
12-api/tests/testthat/test-nddscore-endpoints.R-97-    expect_equal(submitted$job$job_type[[1]], "nddscore_import")
13-api/tests/testthat/test-nddscore-endpoints.R-98-  })
14---
15-api/tests/testthat/test-unit-async-job-service.R-43-      scheduled_at = created_job$scheduled_at,
--
28---
29-api/tests/testthat/test-unit-async-job-service.R-94-  }
30-api/tests/testthat/test-unit-async-job-service.R-95-
31-api/tests/testthat/test-unit-async-job-service.R-96-  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
32:api/tests/testthat/test-unit-async-job-service.R-97-    stop("status lookup should not be needed when duplicate row is attached")
33-api/tests/testthat/test-unit-async-job-service.R-98-  }
34-api/tests/testthat/test-unit-async-job-service.R-99-
35-api/tests/testthat/test-unit-async-job-service.R:100:  result <- runtime$async_job_service_submit(
36-api/tests/testthat/test-unit-async-job-service.R-101-    job_type = "hgnc_update",
37-api/tests/testthat/test-unit-async-job-service.R-102-    request_payload = list(refresh = TRUE),
38-api/tests/testthat/test-unit-async-job-service.R-103-    job_id = "job-new"
39-api/tests/testthat/test-unit-async-job-service.R-104-  )
40-api/tests/testthat/test-unit-async-job-service.R-105-
41:api/tests/testthat/test-unit-async-job-service.R-106-  expect_true(result$duplicate)
42---
43-api/tests/testthat/test-unit-async-job-service.R-253-  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
44-api/tests/testthat/test-unit-async-job-service.R-254-    tibble::tibble(job_id = job_id, queue_name = created_job$queue_name,
45-api/tests/testthat/test-unit-async-job-service.R-255-                   priority = created_job$priority)
--
69-api/tests/testthat/test-unit-async-job-service.R-291-                       provenance = list(source_data_version = "2026-07-18T00:00:00Z"))
70-api/tests/testthat/test-unit-async-job-service.R-292-  subset_payload <- list(genes = c("HGNC:1", "HGNC:5"), algorithm = "leiden")
71-api/tests/testthat/test-unit-async-job-service.R-293-
72-api/tests/testthat/test-unit-async-job-service.R:294:  runtime$async_job_service_submit(
73:api/tests/testthat/test-unit-async-job-service.R-295-    job_type = "clustering",
74-api/tests/testthat/test-unit-async-job-service.R-296-    request_payload = full_payload,
75:api/tests/testthat/test-unit-async-job-service.R-297-    hash_payload = subset_payload,
76-api/tests/testthat/test-unit-async-job-service.R-298-    job_id = "job-hash-override"
77-api/tests/testthat/test-unit-async-job-service.R-299-  )
78-api/tests/testthat/test-unit-async-job-service.R-300-
79---
--
81-api/tests/testthat/test-unit-async-job-service.R-320-    jsonlite::fromJSON(created_job$request_payload_json, simplifyVector = TRUE)$provenance$source_data_version,
82-api/tests/testthat/test-unit-async-job-service.R-321-    "2026-07-18T00:00:00Z"
83-api/tests/testthat/test-unit-async-job-service.R-322-  )
84-api/tests/testthat/test-unit-async-job-service.R-323-
85:api/tests/testthat/test-unit-async-job-service.R-324-  # Default behavior (no hash_payload) is unchanged: hash the full payload.
86-api/tests/testthat/test-unit-async-job-service.R:325:  runtime$async_job_service_submit(
87:api/tests/testthat/test-unit-async-job-service.R-326-    job_type = "clustering",
88-api/tests/testthat/test-unit-async-job-service.R-327-    request_payload = full_payload,
89-api/tests/testthat/test-unit-async-job-service.R-328-    job_id = "job-hash-default"
90-api/tests/testthat/test-unit-async-job-service.R-329-  )
91-api/tests/testthat/test-unit-async-job-service.R-330-  expect_equal(
--
126-api/tests/testthat/test-unit-job-endpoint-services.R-157-  env$async_job_capacity_exceeded <- function(...) FALSE
127-api/tests/testthat/test-unit-job-endpoint-services.R-158-  captured <- NULL
128-api/tests/testthat/test-unit-job-endpoint-services.R:159:  # Cache-miss path calls `async_job_service_submit()` directly (not
129-api/tests/testthat/test-unit-job-endpoint-services.R-160-  # `create_job()`, which is arity-guarded at exactly `(operation, params)`)
130:api/tests/testthat/test-unit-job-endpoint-services.R-161-  # so it can thread a provenance-free `hash_payload` override alongside the
131-api/tests/testthat/test-unit-job-endpoint-services.R-162-  # full `request_payload`.
132:api/tests/testthat/test-unit-job-endpoint-services.R-163-  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
133-api/tests/testthat/test-unit-job-endpoint-services.R-164-                                            submitted_by = NULL, ...) {
134-api/tests/testthat/test-unit-job-endpoint-services.R-165-    captured <<- list(
135---
136-api/tests/testthat/test-publication-refresh.R-164-

codex
I completed the adversarial trace. The requested 400 paths and absent-selector no-query branch are correct in the normal API/worker boot path; I found one nonstandard worker-loader wiring gap that can crash a directly loaded durable worker.
codex
MEDIUM — [api/functions/async-job-worker.R:15](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/functions/async-job-worker.R:15): loading this worker module directly triggers its fallback loader, which sources `async-job-handlers.R` but not `clustering-gene-universe.R`. A claimed `clustering` job then crashes at `clustering_result_meta()` with “could not find function.” Fix: source `clustering-gene-universe.R` before the handler fallback (and mirror it in `bootstrap/setup_workers.R` if that path can dispatch handlers).

Reconfirmed: all four category-validation inputs route to 400s containing `Allowed active categories: …`; absent `NULL` returns before the active-category query; present-null is coerced to an empty selector and delegated to the resolver. Normal API and dedicated-worker bootstrap wiring is correct.

`git diff --check` passed; JSON files parse. Target R tests and code-quality audit could not run because the read-only sandbox prevents temporary-file creation.

**VERDICT: SHIP** (0 BLOCKER/HIGH)
tokens used
179,367
MEDIUM — [api/functions/async-job-worker.R:15](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/functions/async-job-worker.R:15): loading this worker module directly triggers its fallback loader, which sources `async-job-handlers.R` but not `clustering-gene-universe.R`. A claimed `clustering` job then crashes at `clustering_result_meta()` with “could not find function.” Fix: source `clustering-gene-universe.R` before the handler fallback (and mirror it in `bootstrap/setup_workers.R` if that path can dispatch handlers).

Reconfirmed: all four category-validation inputs route to 400s containing `Allowed active categories: …`; absent `NULL` returns before the active-category query; present-null is coerced to an empty selector and delegated to the resolver. Normal API and dedicated-worker bootstrap wiring is correct.

`git diff --check` passed; JSON files parse. Target R tests and code-quality audit could not run because the read-only sandbox prevents temporary-file creation.

**VERDICT: SHIP** (0 BLOCKER/HIGH)
