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
session id: 019f77da-e925-7713-88ad-4663239bdaa2
--------
user
Fifth-pass review of feature #574 (category-selected gene universes for functional clustering). Run `git diff origin/master...HEAD -- ':(exclude).planning/**'`. Read touched files in full.

Prior rounds are resolved:
- Round 2 HIGH (genes:null mutual-exclusion bypass) — fixed via `names(req$argsBody)` key-presence.
- Round 3 HIGH (provenance in dedup hash) — fixed via an optional `hash_payload`/`hash_params` (default NULL → hash full payload; other callers unaffected); the clustering submit hashes the payload MINUS provenance. `create_job` KEPT its guarded 2-arg `(operation, params)` contract; the clustering cache-miss path now calls `async_job_service_submit(..., hash_payload = ...)` directly (like the cache-hit path already calls `async_job_service_store_completed` directly).
- Round 4 HIGH (category_filter:null silently defaulted) — fixed: the branch now keys off `"category_filter" %in% names(req$argsBody)` and rejects a present-but-null value as supplied-empty (400). Symmetric with the genes-null fix.

VERIFY each of the three is resolved and mutually consistent:
- `{"category_filter":null}` alone → 400 (supplied-empty); `{"category_filter":[]}` → 400; `{"category_filter":["Definitive"]}` → category; `{}` / `{"genes":["X"]}` unchanged; both keys present (any values incl. null/empty) → 400 mutual exclusion.
- The dedup hash for explicit/no-arg is byte-identical to pre-#574 (provenance excluded; hash over genes/algorithm/category_links/string_id_table), category adds category_filter; provenance still STORED in request_payload_json for the worker echo; all other async-job callers unaffected by the default-NULL hash_payload.
- `create_job` is still exactly `(operation, params)`.

Then a FINAL adversarial pass. Report ONLY findings tied to a concrete failure scenario (specific inputs → wrong output/crash/contract violation) — no speculative or stylistic nits. Re-confirm the full locked contract (entity-level dbplyr resolution; NULL/absent→default cache parity; supplied-empty/<2-genes→400 with the allowed set in the MESSAGE; mutual exclusion via key-presence; provenance + effective_fingerprint on both cache-hit and worker paths; fail-closed source_data_version never NA/503; never public_ready; `dplyr::`/`base::get` namespacing; all touched files < 600 lines).

Output: for each finding, severity (BLOCKER/HIGH/MEDIUM/LOW), file:line, concrete failure scenario, fix. Final line: **VERDICT: SHIP** (zero BLOCKER/HIGH) or **VERDICT: NO-SHIP** with the count.
exec
/bin/bash -lc "sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-code-quality/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-security-bug-scan/SKILL.md && sed -n '1,260p' /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
I’m using the repository’s code-quality, security, and diff-review guides to make this an adversarial, contract-level review. I’ll inspect the exact merge-base diff and every touched file in full; the workspace is read-only, so I will not create the optional diff-dashboard overlay.
exec
/bin/bash -lc "git diff --name-only origin/master...HEAD -- ':(exclude).planning/**' && git diff --stat origin/master...HEAD -- ':(exclude).planning/**' && git diff --check origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
AGENTS.md
CHANGELOG.md
api/bootstrap/load_modules.R
api/endpoints/jobs_endpoints.R
api/functions/async-job-handlers.R
api/functions/async-job-service.R
api/functions/clustering-gene-universe.R
api/services/job-functional-submission-service.R
api/tests/testthat/job-endpoint-services-fixtures.R
api/tests/testthat/test-integration-clustering-category-submit.R
api/tests/testthat/test-unit-async-job-handlers.R
api/tests/testthat/test-unit-async-job-service.R
api/tests/testthat/test-unit-async-job-worker.R
api/tests/testthat/test-unit-clustering-gene-universe.R
api/tests/testthat/test-unit-clustering-handler-meta.R
api/tests/testthat/test-unit-job-endpoint-services-category.R
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
api/tests/testthat/test-unit-job-endpoint-services.R
api/version_spec.json
app/package-lock.json
app/package.json
documentation/08-development.qmd
 AGENTS.md                                          |   2 +
 CHANGELOG.md                                       |  47 +++
 api/bootstrap/load_modules.R                       |   6 +
 api/endpoints/jobs_endpoints.R                     |  35 +-
 api/functions/async-job-handlers.R                 |  41 ++-
 api/functions/async-job-service.R                  |  24 +-
 api/functions/clustering-gene-universe.R           | 157 +++++++++
 api/services/job-functional-submission-service.R   | 238 ++++++++++---
 .../testthat/job-endpoint-services-fixtures.R      |  62 +++-
 .../test-integration-clustering-category-submit.R  | 206 +++++++++++
 api/tests/testthat/test-unit-async-job-handlers.R  |   4 +
 api/tests/testthat/test-unit-async-job-service.R   |  62 ++++
 api/tests/testthat/test-unit-async-job-worker.R    |   3 +
 .../testthat/test-unit-clustering-gene-universe.R  | 278 +++++++++++++++
 .../testthat/test-unit-clustering-handler-meta.R   | 171 +++++++++
 .../test-unit-job-endpoint-services-category.R     | 387 +++++++++++++++++++++
 .../test-unit-job-endpoint-services-phenotype.R    | 223 ++++++++++++
 .../testthat/test-unit-job-endpoint-services.R     | 307 +++++-----------
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 documentation/08-development.qmd                   |  15 +
 22 files changed, 1984 insertions(+), 292 deletions(-)

exec
/bin/bash -lc "wc -l AGENTS.md CHANGELOG.md api/bootstrap/load_modules.R api/endpoints/jobs_endpoints.R api/functions/async-job-handlers.R api/functions/async-job-service.R api/functions/clustering-gene-universe.R api/services/job-functional-submission-service.R api/version_spec.json app/package.json documentation/08-development.qmd && sed -n '1,999p' AGENTS.md && sed -n '1,999p' CHANGELOG.md && sed -n '1,999p' api/bootstrap/load_modules.R && sed -n '1,999p' api/endpoints/jobs_endpoints.R && sed -n '1,999p' api/functions/async-job-handlers.R && sed -n '1,999p' api/functions/async-job-service.R && sed -n '1,999p' api/functions/clustering-gene-universe.R && sed -n '1,999p' api/services/job-functional-submission-service.R && sed -n '1,999p' api/version_spec.json && sed -n '1,999p' app/package.json && sed -n '1,999p' documentation/08-development.qmd" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
   284 AGENTS.md
  1272 CHANGELOG.md
   288 api/bootstrap/load_modules.R
   174 api/endpoints/jobs_endpoints.R
   398 api/functions/async-job-handlers.R
   517 api/functions/async-job-service.R
   157 api/functions/clustering-gene-universe.R
   378 api/services/job-functional-submission-service.R
    14 api/version_spec.json
   135 app/package.json
   458 documentation/08-development.qmd
  4075 total
# AGENTS.md

This is the canonical agent-facing instruction file for this repository. SysNDD is a neurodevelopmental disorder gene-disease database with three main code trees:

- `api/` — R/Plumber REST API with `renv`
- `app/` — Vue 3 + TypeScript SPA built with Vite
- `db/` — MySQL schema, data-prep scripts, and versioned migrations

## Code Organization

- Write modular, focused code with one clear responsibility per file or module, so humans and LLM agents can read, test, and edit it in a single context.
- Keep handwritten source files under 600 lines when practical. Treat this as a soft ceiling: if a file approaches it, extract cohesive helpers, components, composables, or services before adding more behavior.
- Do not split code mechanically. Tests, migrations, generated files, snapshots, fixtures, and tightly coupled implementations may exceed 600 lines when splitting would reduce clarity.
- Documented size exceptions (WP9 / #346): `db/C_Rcommands_set-table-connections.R` is an intentional exception to the 600-line ceiling. It is an out-of-band, sequential schema-bootstrap DB-prep script (ALTER TABLE / FK / index DDL plus ~10 large inlined `CREATE OR REPLACE VIEW` definitions) that must read top-to-bottom in dependency order, and its `ndd_entity_view` body must stay mirrored byte-for-byte (modulo the `sysndd_db.` schema prefix and the migration's `ALGORITHM`/`SQL SECURITY INVOKER` clause) with the latest `CREATE OR REPLACE VIEW ndd_entity_view` migration (currently `db/migrations/026_add_entity_last_update.sql`, the source of truth); splitting it would reduce clarity and risk the mirror. The exception is recorded here and allowlisted in `scripts/code-quality-file-size-baseline.tsv`; the script itself is left untouched so its baseline does not ratchet up. `db/11_Rcommands_sysndd_db_table_database_comparisons.R` was instead brought under the ceiling by extracting its cohesive HGNC/HPO helper block into `db/11_Rcommands_sysndd_db_table_database_comparisons_helpers.R`, `source()`d after `db_bootstrap()`.

## Code Quality

- Start from nearby patterns and existing helpers before adding new abstractions, dependencies, or cross-layer shortcuts.
- Pair behavior changes with targeted tests or deterministic checks. Run the smallest useful check first, then `make pre-commit` or `make ci-local` when the scope warrants it.
- When touching files already over the 600-line soft ceiling, avoid making them larger by default. Extract cohesive code from the area being changed, but leave broad legacy splits for planned refactors. `make code-quality-audit` enforces this as a fast file-size ratchet.
- Frontend API access should go through typed clients in `app/src/api/*`; do not add raw axios calls in views/components or direct `localStorage.token` / `localStorage.user` access.
- API integration tests that write database state should use `with_test_db_transaction()` or document why rollback is not possible.
- Use `.agents/skills/sysndd-code-quality/SKILL.md` for maintainability, modularity, file-size, DRY/KISS/SOLID, and anti-pattern review passes.

## Repository Skills

Focused, cross-LLM skill guides live under `.agents/skills/<name>/SKILL.md`. Read the relevant one before working in its area — each distills the invariants and traps for that subsystem so you do not have to reconstruct them from this file or the code.

- `sysndd-code-quality` — maintainability, modularity, file-size ceiling, DRY/KISS/SOLID, typed boundaries, anti-pattern review passes.
- `sysndd-visual-design` — UI/UX, layouts, tables, mobile rows, design tokens, admin/curation and public data surfaces.
- `sysndd-api-testing` — writing/running R API tests: the container boundary (`tests/` not bind-mounted), `with_test_db_transaction()`, SKIP-vs-PASS, helper/path resolution, mocking external providers, and the static guard tests.
- `sysndd-async-jobs` — durable MySQL-backed jobs and workers: handler registration, `bootstrap/load_modules.R`, lane/priority routing, the restart-the-worker rule, and external budgets.
- `sysndd-analysis-snapshots` — clustering, the snapshot builder/validator, the survives-redeploy memoise cache, `CLUSTER_LOGIC_VERSION`, the coherence gate, LLM summaries, and the membership-change deploy runbook.
- `sysndd-mcp-readonly` — the read-only MCP sidecar contract: approved-public-only reads, no writes/LLM-generation/external calls, `data_class` labels, and the schema-version contract.
- `sysndd-security-bug-scan` — security + correctness review pass: authorization/role gates, SQL/expression injection, credential and secret handling, public/MCP data exposure, external-call DoS, error/info leakage, and the repo's R/Plumber footguns.
- `sysndd-migrations-db` — DB migrations and SQL views: the startup migration runner + manifest (`EXPECTED_LATEST_MIGRATION`), advisory locks, `ndd_entity_view`/core-view mirroring, restore drift, and rollback-safe metadata refresh.
- `sysndd-external-proxy` — outbound provider calls: `external_proxy_budget()`/`make_external_request()`, `memoise_external_success_only`, the per-request time ceiling, batch per-call resets, and cheap-route isolation.
- `sysndd-frontend-integration` — Vue↔API boundary: typed clients only, Plumber array unwrap, problem+json error extraction, and the BVN dotted-key / tooltip-reactivity table traps.

## Verify Before Handoff

- Fast deterministic code-quality audit: `make code-quality-audit`
- Full-repo check: `make ci-local`
- Fast pre-push check: `make pre-commit`
- Full dev stack: `make dev`
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

`POST /api/jobs/clustering/submit` can resolve its clustering gene universe from a curated confidence category instead of an explicit gene list (#574). `clustering_resolve_category_universe()` (`api/functions/clustering-gene-universe.R`) does entity-level resolution: a gene qualifies if it has >=1 `ndd_phenotype == 1` entity whose `category` is in the selector, filtered directly against `ndd_entity_view` — **never** `select_network_gene_category()` (the gene-level display-label aggregator used for node coloring only, not a universe filter). `category_filter` absent → the byte-identical existing default (`generate_ndd_hgnc_ids()`, cache parity preserved); supplied-but-empty → 400; validated live against `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded category strings, no interpolated SQL) with the allowed active set named in the error **message**; a resolved universe under 2 genes → 400. `genes` and a non-empty `category_filter` are mutually exclusive (400). The durable job payload gains a normalized `category_filter` key — and the dedup identity becomes selector-aware — **only** for category selectors, so explicit-genes and no-arg submits keep byte-identical `request_hash`/payload shape to pre-#574. Every submit records provenance — `selector` (`kind`: `explicit`|`category`|`all_ndd`), `resolved_gene_count`, `gene_list_sha256`, an **intended** fingerprint (STRING cache fingerprint + score threshold + algorithm + seed), and a cached fail-closed `source_data_version` — in the payload; the result `meta` additionally carries an **effective** `effective_fingerprint` (the STRING `weight_channel` the computed result actually used), on both a cache-hit response (`svc_job_submit_functional_clustering()`) and a worker-run job (`.async_job_run_clustering()` in `async-job-handlers.R`), so a silent exp+db→combined-score fallback is visible either way. Results from this endpoint (category-filtered or not) are ephemeral job results and are **never** `public_ready` — distinct from the public `analysis_snapshot_*` layer above.

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

Disease provenance references are ingested from the MONDO ontology releases (`mondo.obo` + full `mondo.sssom.tsv`) using MONDO-as-hub. Four new tables added by migration `036_add_disease_ontology_mappings.sql` store the index and derived mappings: `mondo_term`, `mondo_xref`, `disease_ontology_mapping`, `disease_ontology_mapping_meta`. Five denormalized projection columns (`UMLS`, `MedGen`, `NCIT`, `GARD`, `ontology_mapping_release`) on `disease_ontology_set` enable cheap downstream joins. `ndd_entity_view` is intentionally untouched; the frontend reads mappings from the new `/api/disease/mappings` endpoint.

The refresh pipeline is a durable `disease_ontology_mapping_refresh` async job (advisory lock `disease_ontology_mapping_refresh`, non-blocking `GET_LOCK`) executed by the worker. A `ontology-mapping-cron` Compose sidecar (DB-only network, no egress) enqueues one job per week (env vars `ONTOLOGY_MAPPING_REFRESH_AT`, `ONTOLOGY_MAPPING_REFRESH_DOW`). Startup auto-bootstraps via `disease_ontology_mapping_bootstrap_on_startup()` (gated by `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP`, default `true`), staggered `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_STAGGER_SECONDS` (default `360`s) after the API starts to avoid first-boot contention. Admin endpoints (`POST/GET /api/admin/ontology/mappings/*`) let operators trigger and inspect refreshes without SSH; they are mounted **before** `/api/admin` so the more-specific prefix wins.

The public read endpoint `GET /api/disease/mappings?entity_id=<int>|disease_ontology_id=<CURIE>` is cheap (DB-only). It resolves entities through `ndd_entity_view` (public surface only) — an entity absent from `ndd_entity_view` returns `status:"missing"` and never leaks mappings. Response fields: `disease_ontology_id`, `disease_ontology_name`, `mondo_id`, `release_version`, `status`, and `mappings` (a prefix-keyed object of `{id,label,predicate,source}` arrays). No `ontology_mapping_release` field in the response. Frontend outlink helpers and prefix metadata live in `app/src/ontology_links.ts` (single source for all CURIE→URL logic); the `useEntityMappings` composable and `LinkedOntologies.vue` component consume it.

**Binding rules:**
- An operator ontology refresh (`refresh_disease_ontology_set()`) wipes and rebuilds `disease_ontology_set` rows, erasing the projection columns. A successful `ontology_update`/`force_apply_ontology` job MUST chain a `disease_ontology_mapping_refresh(force=TRUE)` afterward to re-derive projections and normalized mappings. This is wired in `api/functions/admin-ontology-refresh.R`.
- `OMIMPS` is NEVER canonicalized to OMIM and is dropped in v1 (phenotypic-series IDs would mislink to a gene OMIM entry page).
- `target_id` is always a full CURIE (e.g. `UMLS:C1234567`) — never a bare accession.
- New source files are registered in `api/bootstrap/load_modules.R` via `bootstrap_load_modules()`. This covers both the API and the durable async worker (`start_async_worker.R` calls the same function), so a single list update suffices. Restart the worker container after deploy to pick up new job handlers or function changes.
- `disease_ontology_mapping.disease_ontology_id` is declared `CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci` to match the `disease_ontology_set` join key — never change this collation or the projection `UPDATE … JOIN` will raise "Illegal mix of collations".
- MONDO download budgets are tunable via `EXTERNAL_PROXY_MONDO_*` env vars (default timeout 120s / max 300s / 3 tries for the ~50–80MB artifacts).
- Additional env vars: `DISEASE_ONTOLOGY_MONDO_OBO_URL`, `DISEASE_ONTOLOGY_MONDO_SSSOM_URL`.
- When an `omim_update` job is blocked by critical entity-referenced changes, it first additively inserts all brand-new, entity-unreferenced terms via `extract_additive_ontology_terms()` + `apply_additive_ontology_terms()` (live anti-join inside the FK-disabled transaction; idempotent; best-effort — an insert failure is logged as `additive_error` and never turns the blocked job into a job failure). A successful additive insert triggers the usual `disease_ontology_mapping_refresh` chain. Only entity-referenced critical changes gate the full apply.
- `GET /api/admin/ontology/dictionary-status` (Administrator; `/api/admin/ontology` router, mounted before `/api/admin`) reports blocked/stale state derived from async job history — not from `MAX(update_date)`, which additive auto-apply stamps fresh each cycle even when staged critical changes remain. `blocked` requires a fresh (≤48 h) pending CSV; `stale` uses `ONTOLOGY_DICTIONARY_STALE_AFTER_DAYS` (default 30 days).
- A recurring `blocked` status is an intentional standing-review flag, **not a freeze**: the dictionary continues to grow each cycle via additive auto-apply. Resolve the flagged critical entity-referenced changes via Force Apply (`PUT /api/admin/force_apply_ontology?blocked_job_id=<id>`, or Admin → Manage Annotations → Force Apply).
- Force Apply carries the blocked job's `critical_entities` and `auto_fixes` tables forward as its payload. Those are built as `purrr::transpose()` lists of records, but they round-trip through `jsonlite::fromJSON(simplifyVector = TRUE)` **twice** — once in `get_job_status(result_mode = "full")` reading the blocked `result_json`, and again in the worker decoding the force-apply payload — which collapses each array-of-objects into a **`data.frame`**. The force-apply payload helpers therefore live in `api/functions/async-job-force-apply-payload.R` (`.async_job_force_apply_table` / `_auto_fixes` / `_critical_versions`) and normalize *any* shape (data.frame, list-of-records, NULL/empty) before column access. Never iterate these tables with `vapply(table, \(x) x$field, ...)`: over a data.frame that walks **columns** (atomic vectors) and crashes the job with `$ operator is invalid for atomic vectors`. The module is sourced before `async-job-handlers.R` at every worker entrypoint (`start_async_worker.R`, `bootstrap/setup_workers.R`, `async-job-worker.R`) and in `test-unit-async-job-handlers.R`; restart the worker after changing it. Regression guard: the data.frame/list/empty-shape tests in `api/tests/testthat/test-unit-async-job-handlers.R`.
- The blocked-ontology banner (`app/src/components/annotations/OntologyAnnotationsCard.vue`) renders both tables with `disease_ontology_id_version` / `old_version` / `new_version` cells as OMIM outlinks via `OmimVersionLink.vue` → `ontologyOutlink('OMIM', id)` (single CURIE→URL source in `app/src/assets/js/constants/ontology_links.ts`), which strips the `_N` version suffix from the URL while keeping the full id as the label. Keep the auto-fixable table's `disease_ontology_name` (Disease) column.

### Public SEO prerendering

Public SEO pages are generated by the frontend prerender pipeline. If public route content, canonical URL policy, sitemap behavior, or SEO payload endpoints change, run `make verify-seo-app` and update `documentation/08-development.qmd` / `documentation/09-deployment.qmd`.

## Stack-Specific Gotchas

- Namespace `dplyr::select(...)` and similar verbs explicitly in API code. Several loaded packages mask them.
- Loaded packages also mask **base** functions in the API/worker global search path, so a bare base call can fail at runtime even though it parses fine. The `config` package (loaded for DB config) masks `base::get` with a signature `get(value, config, file, use_parent)` that has **no `mode` argument** — so `get(name, mode = "function")` raises `unused argument (mode = "function")` (note `exists(name, mode = "function")` is *not* masked, so the two are asymmetric). Use `base::get(...)` explicitly, or dispatch to the concrete function by name instead of `get()`. This failed **every** cluster-snapshot refresh in #514 and was only caught by live end-to-end verification (host R did not mask it — it manifests only in the fully-loaded API/worker env). Same family as the masked `merge()` (use `dplyr::*_join`) and `biomaRt::select` shadowing `dplyr::select`.
- Use `inherits(x, "Date")`, not `is.Date(x)`, in library-light contexts.
- Plumber may return JSON scalars as arrays. Frontend callers should unwrap values before feeding them back into axios params.
- BootstrapVueNext `BTable` (and the `GenericTable` wrapper) cannot display a field whose `key` contains a dot: its cell value resolver renders a blank cell, and Vue also parses a `#cell-a.b` slot name as `cell-a` + a `.b` modifier, so neither the column nor a custom cell slot can show the value. When source data has dotted column names (e.g. the MCA stats `p.value`, `v.test` from the phenotype-clustering snapshot), alias them to flat keys (`p_value`, `v_test`) before binding them as field keys — see `normalizePhenotypeClusterRows()` in `app/src/components/analyses/phenotypeClusterTable.ts` (regression-guarded by its spec and `AnalysesPhenotypeClusters.spec.ts`). Keep the original dotted keys on the row if other consumers (e.g. the Excel export header map) still read them.
- BootstrapVueNext's `v-b-tooltip` directive is only reactive to its **binding value**, not to a bound `:title` attribute. `hasBindingChanged()` compares `JSON.stringify([binding.modifiers, binding.value])`, so once the floating popover element exists, changing a reactive `:title` patches `data-original-title` but never re-renders the popover body. Faceted-table column headers (Entities/Genes/Phenotypes/PubtatorNDDGenes/CurationComparisons) bind the distinct-count tooltip through the directive **value** — `v-b-tooltip.hover.bottom="getTooltipText(field)"`, never `:title="getTooltipText(field)"` — so the "unique filtered/total" counts update when a filter changes `count_filtered`. Symptom of the bug: tooltip shows the global `count/count` (e.g. `4200/4200`) after an interactive filter instead of `count_filtered/count` (`1997/4200`); it only looked right on a fresh page-load because the popover was created once with the already-filtered value. Static guard: `app/src/components/tables/columnHeaderTooltipReactivity.spec.ts` (exercises the real bvn directive both ways). Static `:title` tooltips (e.g. NddScoreGeneTable column help, ReviewTable header label) are unaffected because their text never changes.
- Plumber does not propagate a router's error handler to mounted sub-routers. Every endpoint file is mounted as its own sub-router in `api/bootstrap/mount_endpoints.R`, so each must be wrapped with the `mount_endpoint()` helper (which attaches the RFC 9457 `errorHandler` from `api/core/filters.R`). Without it, a thrown classed error (e.g. `stop_for_bad_request()` → `error_400`) falls back to plumber's opaque default `{"error":"500 ..."}` instead of mapping to the correct status + `application/problem+json`. Never reintroduce a bare `plumber::pr_mount("/api/x", plumber::pr("endpoints/x.R"))`; route it through `mount_endpoint()`, which attaches both `pr_set_error(errorHandler)` and `pr_set_404(notFoundHandler)`. Only `error_400/401/403/404/500` classes exist. The frontend reads problem+json via `extractApiErrorMessage` (`app/src/utils/api-errors.ts`, `detail` → `title`). Static guard: `api/tests/testthat/test-unit-endpoint-error-handler.R`.
- `DBI::dbBind()` with `?` placeholders needs `unname(params)`; named lists can fail silently.
- Auth-sensitive inputs are body-only: use JSON request bodies for `POST /api/auth/signup`, `POST /api/auth/authenticate`, and password-change endpoints; do not reintroduce query-string transport or raw query-string logging for these flows.
- User-supplied `filter`/`sort` column tokens are allowlisted before they reach `rlang::parse_exprs()`. `generate_filter_expressions()` / `generate_sort_expressions()` in `api/functions/response-helpers.R` take an `allowed_columns` argument and call `validate_query_column()`, which rejects any non-bare-identifier or non-allowlisted column with a 400 (`stop_for_bad_request`). List endpoints derive the allowlist from the queried view via `allowed_columns_for_view("<view>")` (fails open to `NULL` on a DB error, so legacy behavior still applies). Never reintroduce raw `paste0(column, ...)` into `parse_exprs` without routing the column through `validate_query_column`. Static guard: `api/tests/testthat/test-unit-filter-column-allowlist.R`.
- Public expensive/external operations are throttled or cache-only by design. The public clustering submit routes (`/api/jobs/clustering/submit`, `/api/jobs/phenotype_clustering/submit`) enforce a queue-depth cap via `async_job_capacity_exceeded()` / `async_job_active_count("default")` (env `ASYNC_PUBLIC_JOB_CAP`, default 8 → 503 + `Retry-After`). The public LLM cluster-summary endpoints are cache-hit-only: `get_cluster_summary(..., allow_generation = ...)` only runs Gemini when the caller is Curator+. Do not reintroduce synchronous Gemini generation or uncapped worker submission on a public path.
- The Gemini model default is centralized in `api/functions/llm-model-config.R`. There is exactly one in-code default (`LLM_DEFAULT_GEMINI_MODEL`, currently `gemini-3.5-flash`), resolved through `get_default_gemini_model()` with precedence `GEMINI_MODEL` env → `config.yml` `gemini_model` → in-code default. Every generation entry point (`generate_cluster_summary()`, `get_or_generate_summary()`, `validate_with_llm_judge()`) must default `model = NULL` and resolve via `get_default_gemini_model()`; never hardcode a model literal as a default or `%||%` fallback. Requested/configured models are validated by `llm_model_config_validate()` against `llm_model_catalog()` before any Gemini call (recoverable `llm_model_invalid`, not a raw stop); shut-down models such as `gemini-3-pro-preview` (retired 2026-03-09) stay in the catalog only as historical, disallowed metadata. Unknown models are accepted only when listed in `GEMINI_ALLOWED_MODELS_EXTRA` (operator override, surfaced with a warning). Static guard: `api/tests/testthat/test-unit-llm-model-default-guard.R`.
- Access-token lifetime is driven by `config$token_expiry` (default 3600s) for both the JWT `exp` claim (`auth_generate_token`) and the reported `expires_in` (`auth_signin`); keep them on the same source. `config$refresh` is now only the password-reset link TTL (`user_endpoints.R`), not the access-token lifetime.
- Token refresh is DB-backed and revocable (#535 P0-2). Every JWT carries the user's `session_epoch` (migration `043`) as a `sepoch` claim. `auth_refresh()` reads the current user under `SELECT … FOR UPDATE` inside one transaction (pooled API path uses `pool::poolCheckout` + `DBI::dbWithTransaction`; the raw-connection branch is **test-only** and assumes a caller-owned transaction), requires `approved == 1` and `sepoch == user.session_epoch`, and mints role/claims **from the DB row** while the lock is held (so read-check-sign serializes against mutations — no TOCTOU). A token with **no `sepoch`** (pre-#535) is **rejected** to force one post-deploy sign-in (prevents indefinite renewal of a legacy/compromised token). Every privilege/state mutation increments `session_epoch` **in the same SQL statement** — `user_update()` on `user_role`/`approved`, `user_update_password()`, and the bulk `user_role` UPDATEs in `user-service.R` (both gained/keep an optional `conn` for atomic, transaction-testable writes). A privilege change therefore rejects the user's outstanding refresh (force re-login). **Sole exemption:** `upgrade_password()` (progressive Argon2id rehash) does **not** bump — it re-stores the same verified secret mid-sign-in, and bumping would invalidate the token `auth_signin()` is about to issue. Residuals (deferred **S1b**): the current access token stays valid until `config$token_expiry` (~1h) — immediate access revocation would need an epoch check in `require_auth`; distinct rotating refresh tokens for theft resistance; and the pre-existing `user-service.R` bulk-approve `account_status`/`approving_user_id` schema mismatch (the real column is `approved`) is un-bumped and unreachable, tracked separately.
- `/api/review` and `/api/status` draft-exposing GET routes are **Reviewer+** (#535 P0-1) — anonymous GETs are forwarded by `require_auth`, so each handler self-gates with `require_role(req, res, "Reviewer")`; detail/subresource handlers were widened to `function(req, res, <id>)` for it. Only `GET /api/status/_list` (status-category vocabulary) is public, and it **must** be declared **before** the dynamic `/<status_id_requested>` route (plumber matches in declaration order) or it is shadowed and 403s — locked by a regression test.
- Core read views (`ndd_entity_view`, `users_view`, `search_non_alt_loci_view`, `search_disease_ontology_set`) are codified in migration `db/migrations/025_create_core_views.sql` with `SQL SECURITY INVOKER`, so a pristine DB boots. They are no longer only in the out-of-band `db/C_Rcommands_set-table-connections.R`; keep the migration and that script in sync if a view definition changes. `ndd_entity_view` is later rebuilt by `026_add_entity_last_update.sql` to add the derived `last_update` freshness column (`GREATEST(entry_date, approved status_date, primary-approved review_date)`); the latest `CREATE OR REPLACE VIEW ndd_entity_view` migration is the source of truth and must stay mirrored in the C_Rcommands script.
- Metadata refreshes that need rollback semantics must not use MySQL `TRUNCATE` inside transaction code because `TRUNCATE` is DDL and auto-commits. Use `refresh_disease_ontology_set()` or `metadata_with_foreign_key_checks_disabled()` from `api/functions/metadata-refresh.R`; both restore `FOREIGN_KEY_CHECKS` with immediate cleanup. The static guard `api/tests/testthat/test-unit-metadata-refresh-patterns.R` enforces this for `disease_ontology_set` and `non_alt_loci_set`; extend it when adding new metadata tables.
- `make ci-local` is the closest local CI parity check and should be preferred before handoff.
- `make pre-commit` now uses the fast API PR gate to keep local iteration close to pull-request CI; use `make ci-local` before handoff and `make test-api` when you need the full API suite locally.
- Host-side R quality targets in `Makefile` use `Rscript --no-init-file` to avoid Conda/miniforge bootstrap interference before the repo's own script entrypoints run.
- On Conda/miniforge R installs, `Makefile` derives `HOST_R_LD_LIBRARY_PATH` from `R RHOME` and prepends the sibling `mariadb/` runtime directory so `RMariaDB` can load successfully. Override `HOST_R_LD_LIBRARY_PATH` if the MariaDB client runtime lives elsewhere.
- External proxy fetchers must use `memoise_external_success_only()` rather than raw `memoise::memoise()`. Successful and true not-found responses may be cached, but `list(error = TRUE, ...)` transient upstream failures must not poison the 7/14/30-day external caches. Pass `source = "<provider>"` to the wrapper so it emits one structured `[external-proxy] ... event=complete status=... elapsed_ms=... cache=hit|miss` timing log per call (used by `gnomad`/`ensembl`/`uniprot`/`alphafold`); `mgi`/`rgd` instead log via the inline `external_proxy_with_timing()` wrapper inside the fetcher, so they omit the memoise `source` to avoid double-logging. Per-request budgets fast-fail a slow upstream so a single request cannot occupy a worker for tens of seconds; true heavy/light worker-pool isolation is tracked in #154. Every external HTTP call must derive its timeout/retry window from `external_proxy_budget(api_name, ...)` (which accepts tunable `default_timeout`/`default_max`/`default_tries`) or go through `make_external_request()` — never a hardcoded `req_timeout(<n>)`/`max_seconds=<n>` literal. This is enforced by `api/tests/testthat/test-unit-external-budget-guard.R` (a bypass was reintroduced once via GeneReviews in #389, hence the guard). A request-scoped external-time ceiling (`EXTERNAL_PROXY_REQUEST_MAX_SECONDS`, default 15s) is wired into both universal wrappers (`memoise_external_success_only` and `external_proxy_with_timing`): once a request's accumulated external time crosses it, further external calls short-circuit to a degraded 503 (`request_budget_exceeded = TRUE`) without contacting the upstream. The accumulator is reset per request in the `preroute` hook (`api/bootstrap/mount_endpoints.R`), and the `postroute` hook emits a structured `[request-timing] method=… path=… status=… duration_ms=… external_ms=… slow=…` line (slow over `API_SLOW_REQUEST_MS`, default 2000) so a slow request can be attributed to external time. Cheap routes (`/health`, `/auth`, `/statistics`) must never call an external fetcher — enforced by `api/tests/testthat/test-unit-cheap-route-isolation.R`. Static guards: `api/tests/testthat/test-unit-external-proxy-budgets.R`, `test-unit-external-slow-provider.R`, `test-unit-external-budget-guard.R`, `test-unit-cheap-route-isolation.R`, and the router-level `test-integration-slow-provider-isolation.R`. Frontend resilience (gene page renders while providers stall) is locked by the local-only `app/tests/e2e/slow-provider-resilience.spec.ts`.
- API publication ingestion uses direct NCBI E-utilities helpers (`pubmed_esearch_count()` and `pubmed_fetch_xml()`). Tests that mock PubMed should stub those helpers. Both helpers route their query params through `pubmed_eutils_query()` (`api/functions/publication-functions.R`), which appends `tool`, and — when set in env — `email` (`NCBI_EUTILS_EMAIL`) and `api_key` (`NCBI_API_KEY`), mirroring the sibling `genereviews_eutils_query()`. An NCBI API key raises the per-IP EUtils cap from the anonymous 3 req/s to 10 req/s; without it the `publication_date_backfill` 429s large EFetch batches into a whole-job systemic outage (#494), because the per-PMID fallback then hammers a throttled endpoint (shared with the pubtator cron on the same IP) and every PMID errors. The backfill self-throttles at `pubmed_min_request_interval()` (key-aware: ~3 req/s anonymous, faster with a key). Set `NCBI_API_KEY` in the deployed worker `.env` and restart `worker-maintenance`. This path deliberately keeps raw `httr2` retry (429 in `is_transient`, Retry-After honored) and does NOT route through the per-request `external_proxy_budget()` ceiling (it is a batch job with its own pacing), so `publication-functions.R` is intentionally outside the `test-unit-external-budget-guard.R` scan set. The shared PubMed EFetch XML parser was extracted into `api/functions/pubmed-xml-parser.R` (registered in `bootstrap/load_modules.R` **before** `publication-functions.R`, which guard-sources it for direct-source tests) and parses **both** `<PubmedArticle>` and `<PubmedBookArticle>` (GeneReviews / NCBI Bookshelf) records; book records get a date via `table_book_articles_from_xml()` using a `ContributionDate` → `PubMedPubDate[@PubStatus='pubmed']` → `Book/PubDate` ladder (reusing the `pubmed`/`pubmed_partial` `publication_date_source` vocabulary — no new value), so GeneReviews chapters can finally get a verified date instead of being permanently "not retrievable" (#500). The `publication_date_backfill` classifies per-PMID failures as `unresolved` (parse-empty / `publication_fetch_error` — a data condition) vs `failed` (transport/HTTP/timeout — infra) and fires the systemic-outage guard only when `failed_count >= targeted`; an all-unresolvable target set (e.g. all GeneReviews) now completes as a success with `unresolved`/`unresolved_skip_count` counted instead of false-failing with 0 writes (`info_from_pmid()`'s strict abort is unchanged, so entity creation stays strict). `NCBI_API_KEY`/`NCBI_EUTILS_EMAIL` must be mapped into the `api`, `worker`, and `worker-maintenance` compose `environment:` blocks (#499) — compose uses explicit env maps, so a bare `.env` value is otherwise invisible to the containers; `pubtatornidd-cron` is excluded (backend-only, DB-only enqueue, no egress). The parser tests live in `test-unit-pubmed-xml-parser*.R` with shared builders in `pubmed-xml-fixtures.R`; `test-unit-publication-functions.R` keeps the `check_pmid`/`info_from_pmid` tests.
- `batch_preview()` and `batch_create()` in `api/services/re-review-service.R` use a **soft LIMIT** (gene-atomic): the returned entity count may exceed `batch_size` to keep all entities for a partially-included gene in the same batch. Callers that assumed strict LIMIT for sizing UI elements must read the response length, not the requested cap. The `boundary_gene` field on the preview response is non-null when the soft-LIMIT engaged.
- Genes / Entities detail pages (v11.3) use an in-house SWR composable layer (`app/src/composables/useResource.ts` + Pinia `cacheStore`) and ~12 per-source hooks. Each card on the page is a `<SectionCard>` with skeleton + hide-when-empty. `<TablesEntities>` mounts on the URL-derived filter (HGNC id or symbol) — no gating on the gene record. There is a Playwright perf + axe bench at `app/tests/perf/genes-entities.bench.spec.ts` (local-only). Historical design docs are archived at `.planning/_archive/superpowers/specs/2026-04-26-v11.3-genes-entities-perf-ux-design.md` and `.planning/_archive/superpowers/plans/2026-04-26-v11.3-genes-entities-perf-ux-plan.md`.
- Modify-path direct approval (`ModifyEntity.vue`) mirrors the entity-create `direct_approval` flow. `POST/PUT /api/status/create|update` and `/api/review/create|update` accept `?direct_approval=true`; the handler escalates the role gate to **Curator** before approving (Reviewer callers requesting direct approval get 403) and reuses `svc_approval_status_approve` / `svc_approval_review_approve` (via `svc_status_apply_direct_approval` / `review_apply_direct_approval` in `api/services/approval-service.R`) so the sibling-reset semantics match the `/approve` endpoints. Never trust the client flag — it is re-checked server-side. The frontend gates toggle visibility with `useAuth().hasMinRole('Curator')` (hierarchy-aware: Administrator passes; unlike the exact-match `hasRole`). The combined Status & Review modal (#36) submits review-before-status via `useCombinedStatusReview`; the view stays a thin shell by delegating to `useModifyEntityWorkflows` / `useModifyEntityLookups`.

## Environment Notes

- Node major is pinned in `app/.nvmrc` and should match CI.
- Host-side API work may require overriding `HOST_R_LD_LIBRARY_PATH` if the MariaDB client runtime is not next to `R RHOME`; see `documentation/08-development.qmd`.
- `lintr` is not installed in the production API container; lint from the host.

## Documentation Contract

When repository behavior changes, update the durable docs in the same change:

- `AGENTS.md` for persistent agent-facing repository guidance
- `documentation/08-development.qmd` for human development workflow and onboarding
- `documentation/09-deployment.qmd` for deployment and operator-facing behavior
- `README.md` or `CONTRIBUTING.md` when entrypoints or contributor expectations change

## Deeper Docs

- Start with `documentation/08-development.qmd` for human developer onboarding.
- Use `documentation/09-deployment.qmd` for deployment and production operations.
- Use `documentation/10-visual-design-guide.md` for SysNDD UI/UX visual standards before changing public tables, authenticated admin/curation pages, mobile table rows, or design tokens.
- Cross-LLM visual-design enforcement lives in `.agents/skills/sysndd-visual-design/SKILL.md`, `.cursor/rules/sysndd-visual-design.mdc`, `.windsurf/rules/sysndd-visual-design.md`, and `GEMINI.md`; keep those pointers aligned with the visual guide.
- See `db/migrations/README.md` for migration-specific details.
- Planning, specs, reviews, and LLM workflow docs live under `.planning/`.
# Changelog

All notable changes to SysNDD are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (loosely, in the `0.x` line — additive changes land as patch bumps while the public API still stabilises).

## [Unreleased]

## [0.30.1] — 2026-07-19

Category-selected gene universes for functional clustering (#574). The public
clustering submit endpoint can now resolve its gene universe from a curated
SysNDD confidence category instead of an explicit gene list, with an auditable
provenance record on every job.

### Added

- **`category_filter` on `POST /api/jobs/clustering/submit`**: an optional JSON
  body array (e.g. `["Definitive"]`) selecting the clustering gene universe
  from curated confidence categories. Resolution is **entity-level** against
  `ndd_entity_view` — a gene qualifies if it has ≥1 `ndd_phenotype = 1` entity
  whose status `category` is in the selector — via the new
  `clustering_resolve_category_universe()`
  (`api/functions/clustering-gene-universe.R`). Omitting the selector keeps the
  byte-identical pre-#574 default (all NDD genes via `generate_ndd_hgnc_ids()`,
  cache parity preserved); supplying both `genes` and `category_filter` is a
  400.
- **Provenance on every clustering job**: each submit records a `selector`
  (`kind`: `explicit` / `category` / `all_ndd`), `resolved_gene_count`,
  a sort-order-independent `gene_list_sha256`, an **intended** analysis
  fingerprint (STRING cache fingerprint + score threshold + algorithm + seed),
  and a cached, fail-closed `source_data_version` in the durable payload; the
  result `meta` additionally carries an **effective** `effective_fingerprint`
  (the STRING `weight_channel` the computed result actually used), on both the
  cache-hit response and a worker-run job, so a silent exp+db→combined-score
  fallback is observable either way.

### Changed

- Clustering-job **dedup identity is now selector-aware**: the normalized
  `category_filter` enters the durable payload and preflight dedup key **only**
  for category selectors, so `["Definitive"]` and `["Definitive","Moderate"]`
  that happen to resolve to the same current genes are not collapsed, while
  explicit-`genes` and no-arg submits keep a byte-identical `request_hash` and
  payload shape to pre-#574. Category-filtered results remain ephemeral job
  results and are **never** `public_ready`.

### Validated

- The selector is validated live against
  `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded
  category strings, no interpolated SQL): an unknown/inactive category, a
  supplied-but-empty selector, or a resolved universe under 2 genes is a 400
  naming the allowed active categories in the error message.

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
- Frontend runtime image base: `fholzer/nginx-brotli` v1.31.1 → v1.31.2 (#569).

### Not included

- Dependabot #567 (`typescript` 6.0.3 → 7.0.2) is intentionally held back.
  TypeScript 7 is the native-port major line; it removes the `typescript/lib/tsc`
  export subpath that `vue-tsc` requires (breaking `type-check` and `build`), and
  no published `typescript-eslint` yet supports it (peer `typescript <6.1.0`).
  It will be picked up once the Vue/ESLint toolchain ships TS 7 support.

## [0.29.11] — 2026-07-13

Security hardening (#535), final accepted wave. Public authentication now has
bounded per-caller admission control, MCP runs behind a dedicated attested
SELECT-only database principal, remaining frontend request-ownership races are
closed, and performance-sensitive routes no longer pull the composables barrel.
The two topology/scale-contingent proposals were explicitly closed as not
planned for this release.

### Security

- Rate-limit signup, authentication, and password-reset requests per caller with
  a bounded store, trusted-proxy-aware rightmost-untrusted X-Forwarded-For
  handling, fail-closed configuration, and `429`/`Retry-After` responses (#550).
- Isolate the MCP sidecar behind fixed `sysndd_mcp@%` credentials generated by a
  serialized operator provisioner and injected only by owner-only file. Migration
  044 adds 23 filtered `SQL SECURITY DEFINER` public projections; startup attests
  identity, exact grants, roles, and projection definitions before serving. Live
  MySQL 8.4 verification proves approved reads and all 18 MCP tools succeed while
  raw-table reads and DML fail (#552).

### Fixed

- Close remaining whole-workflow and read-composable request-ownership races so
  stale asynchronous results cannot overwrite current frontend state (#553).

### Changed

- Remove the dead `executor_fn` and `timeout_ms` arguments from `create_job()`
  and all call sites while preserving durable handler execution (#551).
- Replace composables-barrel imports on performance-sensitive routes with direct
  imports and enforce the public-route bundle budget (#555).

### Not planned

- Authenticated streamed backup download remains deferred because the installed
  Plumber/httpuv stack requires an explicitly approved protected sidecar topology
  to stream without buffering (#554).
- A cross-type maintenance mutex remains deferred while one maintenance worker
  executes jobs sequentially; revisit only if the lane scales beyond one
  effective consumer (#556).

## [0.29.10] — 2026-07-12

Security hardening (#535), wave 2 — the remaining frontend and API hardening slices from the adversarial repository audit. Each slice received a fresh multi-round adversarial diff review (which surfaced real credential-leak and request-ownership defects beyond the original scope), and the per-caller clustering-submit throttle was verified live against the running stack (independent per-client `X-Forwarded-For` fingerprint, non-spoofable rightmost trusted-proxy hop, `429` + `Retry-After`). Umbrella #535 remains open (design-only slices S1b and S3 are still pending human decisions).

### Security

- Admission-throttle the public clustering submit routes (`/api/jobs/clustering/submit`, `/api/jobs/phenotype_clustering/submit`): each caller — identified by a non-spoofable client fingerprint taken from the rightmost trusted-proxy `X-Forwarded-For` hop — is limited to a configurable number of submits per sliding window, returning `429` with `Retry-After` beyond it. The admission check runs first (a cache hit can no longer bypass the limit), the tracking store is bounded against a fingerprint-rotation memory DoS, the shared guard fails closed, and Traefik strips client-supplied `X-Forwarded-For` underscore aliases so the fingerprint cannot be spoofed (#547, #535 S6).
- Keep credentials out of account emails: stop blind-copying password-reset links and plaintext temporary passwords to no-reply/curator mailboxes, generate temporary passwords with a bias-free CSPRNG, and HTML-escape every user-controlled field rendered into account-email HTML; additionally reject control characters in account fields and tighten email-address validation against header/log injection (#545, #535 S8).

### Fixed

- Request/response ownership for the in-house SWR and polling composables (`useResource`, `useAsyncJob`, `useUserData`, `useMetadataAdmin`): a stale, out-of-order, superseded, or cancelled async response can no longer overwrite a newer result or write into the wrong cache slot, closing per-slot and same-parameter cache-poisoning races during rapid navigation, filtering, and polling (#544, #535 S5b).

### Added

- Retention prune of terminal `async_jobs` rows via a fully-parameterized, batched, lock-safe delete wired into the log-cleanup sidecar (runs before the legacy log prune). It deletes only terminal, non-retryable rows (`active_request_hash IS NULL`) older than both age gates, fails closed on zero/negative/malformed/unset retention windows (default 90 days), and clamps batch size (≤1000) and lock-wait (≤30s) so a misconfiguration cannot widen the blast radius (#548, #535 S7).

## [0.29.9] — 2026-07-12

Security hardening (#535) — remediation of an adversarial repository audit. This release closes credential-exposure, authorization, and token-revocation gaps and hardens the production build and database restore. Verified end-to-end against the running stack (endpoint authorization, live token-refresh revocation, durable-job payload credential-safety, and job-type single-flight) plus an independent adversarial security review.

### Security

- Gate the draft-exposing `/api/review` routes (list, detail, phenotypes, variation, publications) and the `/api/status/<id>` detail route at Reviewer+; anonymous requests now receive `403` with no draft rows or curator identities in the body. The public `/api/status/_list` status-category vocabulary stays open by design (#537, #535 P0-1).
- Revocable, role-current token refresh via a per-user `session_epoch` (migration `043`). Every issued JWT carries the epoch; privilege and state mutations increment it atomically in the same SQL statement; and `auth_refresh` reads current account state under a row lock and mints claims from the database row. Demotion, deactivation, password change, deletion, or a pre-deploy (epoch-less) token therefore lose refresh capability immediately (#538, #535 P0-2).
- Keep database credentials out of durable backup jobs — no credentials in process arguments, shell, or the persisted job payload — and scrub credentials from terminal job payloads (#539, #535 P1-1).
- Resolve database credentials at run time for all durable job families instead of persisting them in job payloads, and add job-type single-flight for destructive maintenance jobs (HGNC, comparisons, OMIM, force-apply) (#542, #535 S2b).
- Never emit production source maps or the bundle-analyzer report, and make the database restore path fail-closed (#540, #535 S4).

### Fixed

- Generation-based request ownership for faceted tables and search suggestions, preventing stale or out-of-order responses from overwriting current results during rapid filter, sort, and pagination changes (#541, #535 S5).

### Added

- Security-hardening specification, implementation plans, and adversarial code-review records under `.planning/` (#536).

## [0.29.8] — 2026-07-11

Bugfix — a pre-existing, app-wide cursor-pagination bug that silently dropped one row on the first→second page transition of every cursor-paginated table. This is an intentional behavior change (it flips the buggy cursor value), verified live against the running dev stack across multiple tables, not only in unit tests.

### Fixed

- **Cursor pagination no longer skips the row at position `page_size + 1` on the page 1 → page 2 transition (app-wide).** `generate_cursor_pag_inf()` in `api/functions/response-fields-helpers.R` — the shared cursor helper behind ~10 list endpoints (`/api/list/{status,phenotype,inheritance,variation_ontology}`, gene, ontology, status, entity-read, logging subsequent-pages, re-review, user-read) — set page 1's `nextItemID` to the id of row `(page_size + 1)`, one row **past** the last row actually shown, while every subsequent page correctly used the last shown row. Because the client's next request filters strictly greater-than the cursor id, the row at position `(page_size + 1)` appeared on **neither** page 1 nor page 2. Confirmed live at `page_size = 25`: `VariO:0026` (Manage Ontology / `variation_ontology`) and `HP:0002270` (`/api/list/phenotype`) existed but were lost in the natural page 1 → page 2 walk. The fix unifies the first- and subsequent-page rule: `nextItemID` is the id of the last row shown on the page (`page_after_row + page_size`), and is a null cursor on the final page (`page_after_row + page_size >= total`). The `>= total` guard also prevents a phantom trailing empty page that a naive "drop the `+ 1`" fix would introduce when the total is an exact multiple of `page_size`. `prev`/`last`/`currentPage`/`totalPages`/`self` and the `page_size = "all"` path are unchanged, so this matches the independent, already-correct SQL reference `get_logs_first_page()`. This is a **pre-existing** production data-loss bug (every cursor-paginated table skipped row `page_size + 1`); it was newly *exposed* for the Manage Ontology admin table by the #531 pagination fix (which first made that table paginate), **not introduced by it**. Verified end-to-end by walking every page of `/api/list/phenotype`, `/api/list/variation_ontology` (495 rows / 20 pages), and the Administrator-gated `/api/ontology/variant/table` (495 rows / 20 pages) — each with no gaps, no duplicates, identical order, and the previously-skipped rows present. Guard: a regression test in `api/tests/testthat/test-unit-helper-functions.R` walks page 1 → last following `nextItemID` and asserts the union equals the full ordered id set exactly (no gaps, no duplicates, expected page count, null final cursor, no empty page) across a non-divisor total, an exact divisor, `page_size == total`, and `page_size > total`, for both string and numeric cursor columns (it fails on the pre-fix code).

## [0.29.7] — 2026-07-11

Bugfix — two pre-existing pagination bugs fixed end-to-end in one change. Both are intentional behavior changes (they flip buggy behavior), so the tests that locked the old behavior were updated. Each was verified live against the running dev stack, not only in unit tests.

### Fixed

- **Admin → Manage Ontology pagination no longer stuck on page 1 (#531).** Clicking next / previous / last always reloaded page 1 and never updated the URL's `page_after`. Two coupled defects: (1) `handlePageChange()` in `app/src/views/admin/composables/useOntologyAdminTable.ts` computed the direction-appropriate cursor and then called `filtered()`, whose unconditional `currentItemID = 0` reset (kept on purpose for real filter/sort/per-page changes) clobbered the cursor back to `0`; (2) the table paginates on **string** VariO cursors (e.g. `VariO:0026`), but the composable coerced every cursor with `Number()` → `NaN` → `0`. Fixes: `handlePageChange()` loads directly with the raw cursor; the cursor refs are widened to `Ref<string | number>`; `applyApiResponse()` preserves string cursors via a `cursorOrZero()` helper; `updateBrowserUrl()` emits `page_after` for string cursors; and URL-init keeps the raw `page_after` so a bookmarked page restores. This mirrors the existing `usePublicationsTable` PMID-cursor handling. Filter/sort/per-page changes still reset to page 1 (unchanged). Verified live: next/previous/last now load distinct rows and the URL reflects the real `VariO:*` cursor. Guard: `app/src/views/admin/ManageOntology.spec.ts` (rewritten from asserting the old always-0 behavior to the corrected string-cursor behavior, plus an `applyApiResponse` cursor-preservation test).
- **`GET /api/llm/cache/summaries` and `/api/llm/logs` no longer 500 on the `limit`/`offset` alias (#532).** When `page`/`per_page` were omitted (Administrator calling `?limit=10&offset=0`), they arrived `NULL`; `as.integer(NULL)` is a length-0 `integer(0)`, which poisoned the `is.na(x) || x < 1L` short-circuit in `.svc_llm_admin_resolve_pagination()` and returned HTTP 500 before the limit/offset fallback ran. Fix: a `.svc_llm_admin_coerce_int()` helper normalizes any non-length-1 coercion to `NA_integer_`, so an omitted `page`/`per_page` falls through to the `limit`/`offset` alias exactly like a present-but-blank `""`. The numeric `page`/`per_page` happy path and the `floor(offset / per_page) + 1` math are unchanged. Verified live (500 → 200 with the `{data, total, page, per_page}` envelope on both routes). Guard: `api/tests/testthat/test-unit-llm-admin-endpoint-service.R` (the test that documented the crash now asserts the corrected limit/offset-only behavior).

## [0.29.6] — 2026-07-11

Maintainability — completed the #346 file-size ratchet program. Every non-exempt handwritten source file is now at or below the 600-line soft ceiling; the only file that remains larger is the documented DB-bootstrap exception (`db/C_Rcommands_set-table-connections.R`), which is intentionally allowlisted. This is a behavior-preserving architecture refactor: no route, response, prop/emit, auth, schema, job, queue, or analysis behavior changed.

### Changed

- **#346 closed — 38 oversized source files brought under 600 lines across four thematic PRs (#526–#529).** Cohesive responsibilities were extracted into focused child components, composables, `svc_`-prefixed services, and function modules, leaving the original files as thin composition/delegation shells.
  - **Wave 1 (#526) — frontend analyses/visualization (7 files):** `NetworkVisualization` (1326→294) split into a single Cytoscape-lifecycle controller + stateless control/legend components + pure presentation helpers; `PublicationsNDDTable`, `PubtatorNDDTable`, `PubtatorNDDGenes` extracted request/state controllers; `AnalyseGeneClusters`, `GeneStructurePlotWithVariants`, `ProteinDomainLollipopPlot` extracted panels/controls.
  - **Wave 2 (#527) — frontend curation/tables/admin (13 files):** `GenericTable` (926→115) decomposed with a byte-identical public slot/prop/emit surface; `ManageReReview` (1514→517), `TablesEntities/Genes/Phenotypes`, `NddScoreGeneTable`, `ApproveUser/ApproveReview`, `ManageOntology/ManageUser`, `EntityView`, `ApprovalTableView`, `BatchCriteriaForm` extracted controllers/config/child components; the three data tables dropped injected Axios for the typed API clients.
  - **Wave 3 (#528) — API Plumber endpoints (9 files, 8093→2725 lines):** handler bodies moved into `svc_`-prefixed endpoint services with byte-identical decorators, formals, `require_role()` gates, and response envelopes.
  - **Wave 4 (#529) — API services/functions/workers (9 files):** `entity-service`, `re-review-service`, `async-job-handlers`, `async-job-repository`, `omim-functions`, `nddscore-import`, `migration-runner`, `endpoint-functions`, `llm-service` split into cohesive modules registered in the runtime source lists; durable async handlers verified via live job smoke (default + maintenance lanes) after the split.
- **Size baseline `scripts/code-quality-file-size-baseline.tsv` now contains only the documented DB-bootstrap exception.**

## [0.29.5] — 2026-07-07

Bugfix — a locked-out curator reported that "Reset Password" returned an error. Root-caused end-to-end against the dev stack.

### Fixed

- **Password reset no longer 500s when the email send fails (#-reset-smtp).** `POST /api/user/password/reset/request` called `send_noreply_email()` without a `tryCatch`, so a production SMTP failure (Strato) propagated as an opaque HTTP 500 — the error the user saw. Signup (#470) and admin approval already wrap their sends best-effort; the reset flow was the one email path never hardened (it works in dev only because dev uses Mailpit). The flow is extracted into a testable helper `process_password_reset_request()`: email delivery is now best-effort (a failure is logged loudly as `[password-reset] … delivery FAILED for user_id=N` and swallowed so the endpoint returns `200`), the response is identical whether or not the address matches an account (anti-enumeration), and two latent bugs are fixed — a case-sensitive lookup and a vector-valued JWT claim on a case-only email collision. Reset-token semantics are byte-identical, so the sibling `reset/change` endpoint still validates tokens. Guard: `api/tests/testthat/test-unit-password-reset-request.R`. Note: this stops the crash and makes SMTP failures observable; it does not itself repair a down mail relay.

## [0.29.4] — 2026-07-07

Frontend dependency maintenance — grouped Dependabot updates (#518, #519).

### Changed

- **Production dependencies (#518).** `@unhead/vue` 3.1.6 → 3.1.7 and `markdown-it` 14.2.0 → 14.3.0.
- **Dev dependencies (#519).** `@types/node` 26.0.1 → 26.1.0, `@vitest/coverage-v8` / `@vitest/ui` / `vitest` 4.1.9 → 4.1.10, `prettier` 3.9.3 → 3.9.4, `typescript-eslint` 8.62.0 → 8.62.1, and `vue-tsc` 3.3.5 → 3.3.6.

## [0.29.3] — 2026-07-07

Security hardening — the MEDIUM + LOW follow-up to the v0.29.2 hotfix (defense-in-depth allowlists, authorization gaps, DoS bounding, and info-leak fixes), plus the adjacent paths a Codex high-effort review surfaced.

### Security

- **Allowlisted the `user_update` and `review_update` SET clauses (#4, LOW-8).** Both built their `UPDATE ... SET` from caller-supplied field names; restrict to writable columns (`setdiff` membership + `validate_query_column`) so injection / mass-assignment of non-updatable columns is rejected with a 400.
- **A Curator can no longer modify Administrator accounts (#5).** All role-mutation paths (`change_role`, bulk role-assign, `user_update_role`) blocked *assigning* the Administrator role but never checked the *target's current* role, so a Curator could demote any Administrator. `assert_not_targeting_admin()` re-checks the target's current role server-side (403), and it also guards the `/user/approval` and `/user/bulk_approve` paths (a Curator could otherwise activate/delete a pending Administrator).
- **Public PubTator calls are budget-bounded (#6).** `/pubtator/search` and `/pubtator/cache-status` made live PubTator calls with raw fetchers (internal retry-with-sleep, no budget), so a slow upstream could occupy a worker. Both now cap retries, derive their timeout from `external_proxy_budget('pubtator')`, enforce the per-request external-time ceiling, and surface a NULL upstream result as a degraded 503; `/pubtator/cache-status` is additionally gated to Curator+.
- **Public LLM cluster summaries are validated-only (#7).** The public serve path served `pending` (un-judge-validated) summaries; it now serves only judge-validated summaries (a pending row reads as "being prepared"), while the terminal `rejected` card is preserved.
- **Public phenotype-clustering jobs use approved input only (#3).** The public `/api/jobs/phenotype_clustering/submit` path built its review set on `is_primary` alone, so a public clustering job — and the per-cluster phenotype stats in its result — could be derived from unapproved curation. It now gates `review_approved = 1`, matching the served-snapshot path.
- **Maintenance job results are Administrator-only (LOW-1).** Full `result_json` for the maintenance/external job types (backups, imports, refreshes — including `publication_date_backfill`, `pubtator_enrichment_refresh`, `pubtatornidd_nightly`) is now Administrator-only, kept in sync with `ASYNC_MAINTENANCE_JOB_TYPES`.
- **Logging sanitizer hardened (LOW-3).** Sensitive field names are matched by substring (`access_token`, `refresh_token`, `password_hash`, `api_key`, …) and the raw request query string is never retained in logs.
- **Constant-time legacy password comparison (LOW-4).** The legacy plaintext-verify path uses a fixed-length digest compare instead of `==`.
- **URL-encode external URL segments (LOW-5).** HGNC / OxO fetchers URL-encode interpolated identifier segments.

### Fixed

- **MONDO SSSOM download timeout (LOW-6).** `download_mondo_sssom()` derives its timeout/retry from `external_proxy_budget('mondo')` (it previously had no request timeout).
- **`metadata-refresh.R` masked-`get` (LOW-7).** Dispatch `log_warn` via `base::get` so the `config::get` mask does not silently degrade the warning.

## [0.29.2] — 2026-07-07

Security hotfix — authenticated RCE, SQL injection, and public exposure of unapproved curation, plus the adjacent higher-severity paths a Codex high-effort review surfaced.

### Security

- **Closed an authenticated RCE in the hash-create endpoint (#1).** `post_db_hash()` sorted the request tibble with `arrange(!!!rlang::parse_exprs(colnames[1]))`, evaluating the first JSON body key as an R expression via dplyr data-masking — arbitrary code execution for any authenticated user. Column tokens are now validated against the allowlist **before** any evaluation, and the sort uses a column **reference** (`across(all_of(...))`) that can never be parsed as code.
- **Closed an unauthenticated RCE/SQLi via filter and hash values.** `generate_filter_expressions()` pasted raw filter values — and attacker-stored hash values — into R source that reaches `parse_exprs()`, which public list endpoints then evaluate **in R** after `collect()`. Values are now escaped for the string-literal context (`escape_r_string_literal()`), stored hash column names are validated as bare identifiers, and the direct-path value strip also removes backslashes so a trailing backslash cannot escape the closing quote.
- **Allowlisted the re-review submit SET clause (#2).** `PUT /api/re_review/submit` interpolated JSON body keys raw as SQL identifiers, allowing identifier injection and mass-assignment of `re_review_approved` / `approving_user_id`. The writable set is now restricted to `re_review_submitted` (explicit membership + bare-identifier backstop); an empty field set is rejected with a 400 instead of malformed SQL.
- **Public reads are approved-only (#3).** The entity list and `/entity/<id>/{phenotypes,variation,review,publications}` (both `current_review` modes) gated reviews on `is_primary`/`is_active`/`is_reviewed` alone, leaking unapproved in-place review edits (`review_approved = 0, is_primary = 1`). All paths now source rows through a shared `primary_approved_reviews()` helper (`is_primary = 1 AND review_approved = 1`); `/status` adds `status_approved = 1`.
- **SEO payloads expose approved-primary reviews only.** The public `/api/seo/*` HPO-term, variation-term, and PMID queries gated on `is_active`/`is_reviewed` alone; each now joins `ndd_entity_review` on the approved-primary review.
- **Phenotype/variant connect views gate `review_approved` (migration 042).** `ndd_review_phenotype_connect_view` and `ndd_review_variant_connect_view` — consumed by the public phenotype/variant browse, count, and correlation endpoints and the entity-list vario filter — filtered `is_active + is_primary` but not `review_approved`. Migration 042 rebuilds both with the approved gate; the `C_Rcommands` mirror is updated in sync.

## [0.29.1] — 2026-07-06

Cluster-snapshot cache coherence & self-healing analysis deploys (#514) — a production follow-up to the v0.29.0 methodology deploy.

### Fixed

- **Cluster caches self-invalidate on a methodology change (#514).** After the v0.29.0 deploy, production served **stale, internally-incoherent** functional-cluster snapshots: the displayed **partition** was the pre-#510 text-mining clustering (a stale disk-cache hit) while the **validation metrics** in the same snapshot were the new text-mining-free (exp+db) computation, so real clusters showed `n/a` stability and prod ≠ a fresh checkout. Root cause: the memoise disk cache (on a named volume, survives redeploys) keyed only on call args, so an algorithm/graph change did not invalidate it. Each clustering function now folds a **call-time fingerprint** into its memoise key — `CLUSTER_LOGIC_VERSION` + STRING channel + exp+db file identity (functional) / MCA prevalence band (phenotype) — so a code, data, or channel change self-invalidates the relevant entries with **no manual `CACHE_VERSION` bump and no restart** (adding the exp+db artifact self-heals immediately).
- **Snapshot integrity gate.** The builder now refuses to publish a clustering snapshot whose served membership and validation describe different partitions (or disagree on channel), keeping the prior public-ready snapshot and marking the new refresh failed (`ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE`, default on).
- **Observable exp+db fallback.** `build_string_subgraph` now emits a `warning()` (not just a `message()`) when functional clustering silently falls back to the text-mining `combined_score` graph; the served snapshot exposes the membership channel next to the validation channel; and `GET /api/health` reports `analysis.expdb_edges_file_present` / `cluster_logic_version` / `functional_weight_channels`. The `mcp` service mounts `./api/data` read-only so its cache-probe fingerprint matches the writer's.
- Synced the `NetworkVisualization.vue` file-size baseline to its merged (v0.29.0) size so `make code-quality-audit` is green.

## [0.29.0] — 2026-07-05

Cluster-analysis statistical soundness & reproducibility (#508–#512), plus a deep multi-reviewer code-review pass and GeneNetworks cluster-display fixes.

### Added

- **Self-reproducing cluster snapshots (#512)**: two read-only endpoints, `GET /api/analysis/functional_clustering/reproducibility` and `.../phenotype_clustering/reproducibility`, publish the exact inputs (functional: full largest-connected-component edge list + complete membership; phenotype: MCA coordinates + assignment + params) plus a SHA-256 `reproducibility_hash`, so anyone can recompute the served modularity/silhouette. Stored as a gzipped canonical-JSON bundle (migration `041`).
- **Unit-free, null-calibrated separation on both axes (#511)**: a common `separation_z` — functional = modularity z-score vs a degree-preserving configuration-model null; phenotype = silhouette z-score vs a label-permutation null — plus a dip test of unimodality as a corroborating continuum-vs-modular signal, and the same modularity-z index on a mutual-kNN graph of the MCA embedding.
- **Text-mining-free functional clustering (#510)**: STRING weights are recombined from the experimental + database channels only (probabilistic-OR), dropping the co-mention channel that would let literature co-study restate "molecular" structure; giant-component (isolate/component) counts are reported.

### Fixed

- **Modularity null re-optimizes per replicate**: `modularity_null_zscore` now re-detects communities on each rewired null (the Guimerà/Sales-Pardo/Amaral configuration-model benchmark) instead of stranding the observed labels on the null, which had inflated `separation_z` by orders of magnitude; the observed graph is restricted to its largest connected component so observed and null share a substrate, and `modularity_lcc` is exposed to reconcile the z.
- **Phenotype MCA hygiene & real consolidation (#508/#509)**: near-constant/root HPO terms are filtered out of the active MCA set and presence is recoded to explicit `{absent, present}`; HCPC runs with `kk = Inf` so k-means consolidation actually executes (FactoMineR ≥2.13 silently disables it for finite `kk`); the k-selection curve re-runs the served procedure per k. The prep is a single shared helper applied to both the served snapshot and the interactive clustering job so they cannot diverge.
- **STRING exp+db edges are de-duplicated** (`simplify()`), so edge counts and the reproducibility export are the true undirected counts (partition unchanged); the functional dip test runs on continuous weighted distances, not integer hop counts.
- **GeneNetworks cluster selector** shows all real clusters (not a fabricated top-10 that broke click-to-filter), explains the non-consecutive cluster IDs in-UI, and makes an active category/cluster filter visibly discernible (funnel badge + a reactive, filter-aware tooltip) so a reduced gene count reads as filtered, not missing.
- Additional review follow-ups: mirai worker-pool sources the new analysis modules; the reproducibility endpoint gates on snapshot staleness; MCP no longer double-labels separation fields; all-NA character columns are no longer misclassified as HPO presence columns.

## [0.28.2] — 2026-07-04

Hardening follow-ups to the v0.28.1 OMIM-NDD descendant expansion, from a deep code review.

### Fixed

- **Durable OMIM-NDD refresh now honors `OMIM_NDD_SEED_TERM`**: the refresh path (`comparisons-functions.R`) called `adapt_genemap2_for_comparisons()` with the hardcoded default seed, while the db-prep script and the `GET /api/comparisons/sources` provenance both read the `OMIM_NDD_SEED_TERM` env var — so an operator who set a non-default seed got provenance that disagreed with the imported set. Both paths now resolve the seed through a single helper, `omim_ndd_seed_term()`.
- **Descendant-resolution failure is now observable**: `hpo_all_children_from_term_api()` (the JAX `/descendants` fetch behind `omim_ndd_resolve_terms()`) previously swallowed network/parse errors and silently returned seed-only — re-introducing the exact under-capture bug v0.28.1 fixed. It now emits a `warning()` on any fetch error or empty/malformed response, so a degraded refresh shows up in worker logs. It also normalizes term ids (trim/`NA`/blank) before filtering.
- **Bounded the JAX request**: the fetch used raw `jsonlite::fromJSON()` (only the global 60 s connection timeout) inside a durable worker job; it now uses a bounded `httr2` request (`req_timeout` + one retry) so a stalled ontology API fails fast instead of tying up a worker.

### Added

- Offline unit tests for the seed/descendant resolution chain (`omim_ndd_seed_term`, `omim_ndd_resolve_terms`, `hpo_all_children_from_term_api`) covering success, empty/malformed, and failure branches with mocked `httr2` (`test-unit-omim-ndd-descendants.R`).

## [0.28.1] — 2026-07-04

Follow-ups to the v0.28.0 comparison work.

### Fixed

- **OMIM-NDD comparator now includes the seed term's HPO descendants, not just the exact seed** (follow-up to #502): `adapt_genemap2_for_comparisons()` filtered `hpo_id == seed_term` on HPO's `phenotype_to_genes.txt`, on the assumption that the file is upward-propagated. It is not — a disease annotated only with a specific descendant term (e.g. `HP:0001249` "Intellectual disability") does **not** also carry the ancestor seed `HP:0012759` "Neurodevelopmental abnormality", so the single-seed filter silently dropped it. Measured against the current HPO release, the seed-only filter matched 2216 OMIM diseases while the seed + its 48 descendants match 2844 — ~628 NDD diseases (including ~25 annotated with intellectual disability) were missing. The adapter now expands the seed to its full descendant set via `omim_ndd_resolve_terms()` (JAX ontology `/descendants` API via `hpo_all_children_from_term_api()`, degrading to seed-only on failure) and filters `hpo_id %in% ndd_terms` — matching the kidney-genetics pipeline and this repo's own db-side data-prep script, which already did `HPO_all_children_from_term()` + `filter(hpo_id %in% ndd_phenotypes)` (only the API side was out of sync). `omim_ndd_seed_sweep()` inherits the fix (each seed expands to its subtree). Regression-guarded by a descendant-only fixture case in `test-unit-comparisons-functions.R`. Worker-executed; restart the worker after deploy.
- **`normalize_comparison_categories()` ndd_genehub docstring** corrected to spell out the actual differentiated Tier→ClinGen mapping (Tier 1/AR→Definitive, Tier 2→Moderate, Tier 3/4/Missense/Unclassified→Limited) instead of the stale "all entries → Definitive" (#504).

## [0.28.0] — 2026-07-04

Curation-comparison source repair + refresh hardening, and the upstream half of #502 (configurable OMIM-NDD seed). The single dead comparison source (`geisinger_DBD`) had been blocking every production comparison refresh; the refresh is now resilient so no single dead upstream can freeze the comparator again.

### Fixed

- **`geisinger_DBD` comparison source repaired** (was a hard production blocker): the Developmental Brain Disorders database moved from the now-404 `dbd.geisingeradmi.org` CSV to NDD GeneHub. Migration `038_update_geisinger_dbd_source.sql` repoints the source to `https://nddgenehub.org/files/Full-Data.csv`, and the parser (`parse_ndd_genehub_csv()`) was rewritten to aggregate that canonical case-level export per gene (phenotype union, distinct PubMed IDs, derived inheritance). Because the historical refresh was all-or-nothing, this one 404 had been aborting the whole refresh. Verified end-to-end against the live 4.9 MB file.
- **Dead HPO term API replaced across the codebase**: the retired `hpo.jax.org/api/hpo/term` endpoint (and its old nested JSON shape) is replaced by the JAX ontology API `https://ontology.jax.org/api/hp/terms/{id}` in `db/config/db_config.R` (`hpo_term_api_base`), the db-prep HPO helpers, and the (unused) `api/functions/hpo-functions.R` variants. Descendant sets now come from a single `/descendants` call instead of a recursive per-term walk. HPO term browse outlinks moved to `https://hpo.jax.org/browse/term/{id}` (the `/app/` prefix was dropped in the HPO site rebuild); updated in `jobs_endpoints.R`, `analysis-snapshot-service.R`, and `EntityView.vue`.
- **`comparisons_update_async` not found on the durable worker**: `create_job()` submits `comparisons_update` as a durable System B job, but the comparisons/OMIM write-path functions were only sourced into the mirai daemon pool (`setup_workers.R`), never into the durable worker's `bootstrap_load_modules()` list. The passthrough handler's `base::get("comparisons_update_async")` therefore always failed with "object … not found", so the refresh never ran. `omim-functions.R`, `comparisons-sources.R`, `comparisons-parsers.R`, and `comparisons-functions.R` are now registered in `api/bootstrap/load_modules.R` (loaded by both the API and the durable worker). Restart the worker after deploy.
- **`ndd_database_comparison` schema drift on restored databases** (migration `039`): a `dbWriteTable`-style restore recreates the table with `comparison_id` as a `DOUBLE` PRIMARY KEY (no AUTO_INCREMENT), narrow auto-sized VARCHARs (`version(34)`, `publication_id(341)`, …), and a dropped `granularity` column — so the refresh fails with "Data too long for column 'version'" or a PK violation (the new per-list re-insert relies on AUTO_INCREMENT). Migration `039` idempotently re-asserts the intended migration-009/012 schema (re-adds `granularity`, converts `comparison_id` to `INT AUTO_INCREMENT`, widens the text columns). Verified end-to-end: a full Administrator-triggered refresh imported 18,668 rows from 7 sources with the rewritten geisinger parser (whose per-gene PubMed-ID lists reach ~1 KB, which is exactly why the `publication_id` TEXT widening was required).
- **`test-external-pubmed.R` sources the PubMed XML parser explicitly** (pre-existing gap surfaced by running the full `make ci-local` gate): the guard-source inside `publication-functions.R` uses base `source(local = TRUE)`, which does not surface `table_articles_from_xml` into the `test_that` scope, so the three parser unit tests errored under the full R lane after the #500 parser split. The test now sources `functions/pubmed-xml-parser.R` via `source_api_file(local = FALSE)`, mirroring how it already sources `genereviews-functions.R`. Test-only; no runtime change.

### Changed

- **Comparison refresh is resilient (per-list replace), not all-or-nothing**: each source downloads/parses independently; a failed source keeps its previously-imported rows and is named in `comparisons_metadata.last_refresh_error`, and the job reports `partial` (some failed) or `success` (all OK), only failing outright when every source fails. `comparisons_refresh_outcome()` is the single decision point. `comparison_id` is left to AUTO_INCREMENT so retained rows never collide with the per-list re-insert. The durable worker sources comparisons code at worker startup, so restart the worker before a refresh reflects code changes.
- **`comparisons-functions.R` split**: the per-source parsers + `standardize_comparison_data` were extracted into `api/functions/comparisons-parsers.R` and the OMIM-NDD adapter/sweep into `api/functions/comparisons-omim.R` (all registered in `api/bootstrap/load_modules.R`, guard-sourced from `comparisons-functions.R`) so every file stays under the 600-line ceiling.

### Added

- **Live source-provenance panel + `geisinger_DBD` → `ndd_genehub` rename**: the curation-comparison table's provenance popover (source list, download URLs, and the "last update" date) is now populated from a new `GET /api/comparisons/sources` endpoint (driven by `comparisons_config` + `comparisons_metadata`) instead of hardcoded, drift-prone text — so it always shows the current URLs and refresh date. The source is surfaced everywhere as **NDD GeneHub**, and the internal source key/`list` value was renamed `geisinger_DBD` → `ndd_genehub` (migration `040`, parser, dispatch, and frontend columns) to remove the stale "geisinger" identifier from the API `list` field, exports, and column keys.
- **Configurable OMIM-NDD seed + sensitivity sweep (#502)**: `adapt_genemap2_for_comparisons(seed_term = "HP:0012759")` makes the NDD definition a documented parameter (default reproduces the published set), and `omim_ndd_seed_sweep()` produces a per-seed report (gene-set size + SysNDD coverage gap) over narrow/default/broad seeds. The db-prep script reads the same seed from `OMIM_NDD_SEED_TERM`. Downstream API exposure of the variant sets remains a separate follow-up per #502.
- **NDD GeneHub evidence tiers surfaced as the comparison `category`**: `parse_ndd_genehub_csv()` now labels each gene with its NDD GeneHub evidence tier (`AR` / `Tier 1`–`Tier 4` / `Missense`, else `Unclassified`) instead of a flat placeholder, via `ndd_genehub_category_lookup()` reading the two sibling exports `Full-LoF-Table-Data.csv` (LoF tier 1–4 / `AR`) and `Full-Missense-Table-Data.csv` — the case-level `Full-Data.csv` has no tier column, and the LoF tier wins over Missense when a gene is in both. Verified live against the current NDD GeneHub tables (e.g. 612 Missense, 286 AR, 262 Tier 1, 192 Tier 4, 128 Tier 3, 96 Tier 2).

## [0.27.3] — 2026-07-03

Post-deploy fix release completing the `publication_date_backfill` work from #494. Closes #499. Closes #500.

### Fixed

- **NCBI API key now reaches the containers** (#499, follow-on to #494/#496): `docker-compose.yml` uses explicit `environment:` maps, so `NCBI_API_KEY`/`NCBI_EUTILS_EMAIL` in `.env` were never visible inside `api`, `worker`, or `worker-maintenance` — the backfill still ran anonymous (3 req/s). The two vars are now mapped into all three egress services (mirroring `GEMINI_API_KEY`). `pubtatornidd-cron` is intentionally excluded (backend-only network, DB-only enqueue, no egress). Set `NCBI_API_KEY` in the deployed `.env` and restart the workers.
- **GeneReviews publication dates can finally be verified** (#500, real cause behind #494): the shared PubMed EFetch parser matched `//PubmedArticle` only, so GeneReviews chapters — returned by EFetch as `<PubmedBookArticle>/<BookDocument>` and a large, permanent share of SysNDD references (~393 of ~553 unverified) — yielded 0 rows and were permanently "not retrievable". Once the non-book targets were verified, every subsequent run targeted only the unresolvable book records and the systemic-outage guard failed the whole job with 0 writes, on every run. The parser (now in `api/functions/pubmed-xml-parser.R`) parses book records with a `ContributionDate` → `PubMedPubDate[@PubStatus='pubmed']` → `Book/PubDate` date ladder (reusing the `pubmed`/`pubmed_partial` vocabulary), and the backfill now distinguishes `unresolved` (parse-empty data condition) from `failed` (transport/infra), firing the systemic-outage guard only on wholesale transport failure. Worker-executed code changed — restart `worker`/`worker-maintenance` after deploy.

## [0.27.2] — 2026-07-03

Post-deploy fix release resolving two production issues found while verifying v0.27.1. Closes #494, #495.

### Fixed

- **`publication_date_backfill` no longer 429s itself into a whole-job "systemic outage"** (#494, follow-on to #489): the PubMed EUtils helpers (`pubmed_fetch_xml`/`pubmed_esearch_count`) now route their query params through `pubmed_eutils_query()`, which attaches an NCBI `api_key` (plus optional `email`/`tool`) from `NCBI_API_KEY`/`NCBI_EUTILS_EMAIL` when set — raising the per-IP EUtils cap from the anonymous 3 req/s to 10 req/s — and the backfill self-throttles at a key-aware `pubmed_min_request_interval()`. Without a key the previous 200-id EFetch batch 429'd, the per-PMID fallback hammered a throttled endpoint (shared with the pubtator cron on the same IP), every PMID errored, and the systemic-outage guard failed the run with nothing written. Set `NCBI_API_KEY` in the worker `.env` and restart `worker-maintenance`.
- **The largest phenotype cluster's AI summary validates again** (#495, follow-on to #490): the phenotype LLM-judge grounded against only the top-15 phenotypes by `|v.test|`; for the ~1000-entity "pure/isolated intellectual disability + seizures" cluster the top-15 are dominated by strong depletions (heart, genitourinary, skeletal — all *absent*), so genuinely enriched, cluster-defining phenotypes (Seizures +8.2, ID-profound +8.2, Behavioral +7.7, Microcephaly +4.1) fell out of the judge's view and it hard-rejected the generator's correctly-grounded mentions of them as "fabricated". `build_phenotype_judge_prompt()` now lists ENRICHED and DEPLETED phenotypes separately (both `|v.test| > 2`, mirroring the generator) so an enriched term is never crowded out. Verified with a live Gemini A/B on the real cluster (old top-15 judge → reject, new judge → accept) and corroborated by independent Claude and Codex judging of the full data. Judge-only change — `LLM_SUMMARY_PROMPT_VERSION` intentionally unchanged; recover a cached terminal-`rejected` cluster with `POST /api/admin/analysis/snapshots/refresh?analysis_type=phenotype_clusters&force=true` after restarting the worker.

## [0.27.1] — 2026-07-03

Post-deploy fix release resolving the batch of issues the deployment agent filed against the v0.27.0 analysis-snapshot / clustering / LLM-summary work. Closes #483, #484, #485, #486, #488, #489, #490.

### Fixed

- **Analysis snapshots now rebuild on a snapshot-schema bump** (#483): `analysis_snapshot_status_code()` classifies a stored `schema_version` other than the code's `ANALYSIS_SNAPSHOT_SCHEMA_VERSION` as `schema_version_mismatch` (checked after `source_version_mismatch`), so the auto-bootstrap / admin refresh re-enqueue the preset and it self-heals on the next deploy instead of silently serving the old schema.
- **`publication_date_backfill` persists dates again** (#489): removed the SAVEPOINT-probe transaction detection that false-positived on a fresh autocommit connection (throwing `SAVEPOINT ... does not exist` and failing the whole job after fetching every PMID). Verified dates are now written in committed batches (`backfill_write_updates`, `write_batch_size`/`manage_transaction`), so partial progress persists across a mid-run outage and re-runs resume idempotently; `max_attempts` raised 1 → 2.
- **Heavy maintenance jobs no longer head-of-line block interactive work** (#486): `async-job-service.R` routes bulk/external maintenance job types to a dedicated `maintenance` queue lane (drained by a new `worker-maintenance` container; dev runs one combined worker) and corrects an inverted priority (batch backfill previously outranked interactive `llm_generation`/`clustering`). Interactive < maintenance < default priority tiers.
- **LLM cluster summaries stay consistent with the published snapshot** (#485, #488): the summary cache is now keyed on `cluster_hash` **plus** `LLM_SUMMARY_PROMPT_VERSION` so a future summary-prompt change invalidates unchanged-membership clusters instead of serving them stale (the version stays `1.0` this release — only the judge changed, so existing validated summaries remain accurate and keep serving), orphaned `is_current` rows whose hash left the snapshot are retired on refresh, and Administrator `POST /api/llm/regenerate` is driven from the published snapshot (reads `service_analysis_snapshot_shape_clusters` instead of recomputing clustering, which had produced non-matching hashes that blanked every cluster) with a real `force` path and a 409 when no public snapshot exists.
- **Judge-rejected cluster summaries are a distinct terminal state, not "being prepared" forever** (#490): `get_cluster_summary()` returns HTTP 200 `{summary_available:false, validation_status:"rejected", reason}`, both the phenotype and functional analysis views render an explicit "AI summary could not be validated for this cluster" card, the judge reason is persisted to `llm_generation_log`, and very large heterogeneous clusters get a relaxed gestalt judge instruction.
- **Corrected `refresh-analysis-snapshots.R` operator usage comment** (#484): documented the working `make refresh-analysis-snapshots` / stdin form instead of a `docker exec … /app/scripts/…` path that cannot exist (`scripts/` is excluded from the image and the container is non-root).

## [0.27.0] — 2026-07-03

Feature release: verifiable literature publication dates, scientifically-corrected + validated gene/phenotype clustering surfaced by a new in-app **Cluster validation** card, plus base-image/dependency bumps. Closes #457, #458, #459, #460.

### Added

- **Cluster validation card** on the functional (`/GeneNetworks`, `/Analysis`) and phenotype (`/PhenotypeCorrelations/PhenotypeClusters`) analysis pages: shows the partition metrics (weighted **modularity** for functional Leiden / **mean silhouette + data-driven k** for phenotype MCA-HCPC) and per-cluster **bootstrap-Jaccard stability** bands (`stable ≥0.75 · doubtful · weak · dissolved <0.5`) with the DB release label. Accessible (band label + numeric value, never colour-only); hides itself for snapshots built before validation existed. Frontend-only — the metrics were already served by the API. (#457, #458, #459)
- **Verified publication dates** end-to-end: the `publication_refresh` async job persists `publication_date_source`; a durable `publication_date_backfill` async job plus Administrator endpoints (`POST`/`GET /api/admin/publications/verify-dates[/status]`) let an operator run + inspect the one-time backfill; MCP publication outputs carry a `pubmed_verified` confidence flag and a year-bearing `recommended_citation`. (#460)
- **Cluster-validation metrics persisted in analysis snapshots** (migration `037_add_analysis_snapshot_validation.sql`): weighted-modularity + per-cluster Jaccard (functional), silhouette + data-driven k + per-cluster Jaccard (phenotype), and a human-facing DB release label, exposed read-only through the API (`meta.snapshot.validation`, a serve-time `validation_hash`, `db_release`) and MCP. (#457, #458, #459)

### Changed

- Functional Leiden now optimises **weighted** modularity on STRING `combined_score` and runs to convergence (`n_iterations = -1`); phenotype HCPC selects **k from the data** (was a hardcoded `k = 5`) and enforces `min_size`. (#457, #458)
- Bumped `rocker/r-ver` **4.6.0 → 4.6.1** (API base image; Ubuntu 24.04 noble unchanged) and `axllent/mailpit` **v1.30.2 → v1.30.3** (dev + Playwright compose mail sink). Supersedes #480, #481.
- Refactored the functional and phenotype cluster views under the 600-line ceiling — extracted `FunctionalClusterTablePanel.vue` / `PhenotypeClusterVariableTable.vue` table panels, `useFunctionalClusterTable` / `usePhenotypeClusterTable` composables, and a shared `useClusterSummary` composable — with no behaviour change.

### Fixed

- Verified-date backfill now **fails observably** on a systemic PubMed/worker outage (classed `publication_backfill_systemic_failure` when every targeted PMID errors) instead of a false "success"; surfaces `skipped_count`/`skipped_pmids`/`skipped_errors`. (#460)
- `cluster_max_jaccard()` returns `NA` (not `-Inf`) when a reference cluster is absent from a subsample, and per-cluster Jaccard counts only effective (non-NA) resamples. (#457, #458, #459)
- A serve-time `validation_hash` binds the served partition-validation metadata (which `payload_hash` intentionally excludes) so clients can detect a validation-only change; the Compose `CACHE_VERSION` default was bumped `2 → 3` so a redeploy invalidates the memoised cluster partitions from the old algorithms. (#457, #458, #459)

## [0.26.7] — 2026-06-30

Patch release: faceted-table column-header tooltips now show the correct "unique filtered/total" counts after an interactive filter (Entities, Genes, Phenotypes, PubtatorNDD genes, curation comparisons).

### Fixed

- **Column-header distinct-count tooltips were stuck at the global total after filtering**: applying a filter (e.g. Category → Definitive on `/Entities`) left the header tooltip showing `4200/4200` (and `3215/3215` for genes) instead of `count_filtered/count` (`1997/4200`, `1802/3215`). The data was correct end-to-end — the API returned the right `count_filtered` and the component's `fields` held it — but the rendered tooltip body never updated. Root cause: bootstrap-vue-next's `v-b-tooltip` directive only re-renders its floating popover body when `binding.value` changes (`hasBindingChanged` compares `[modifiers, value]`); the tables bound the text via the reactive `:title` **attribute**, so `binding.value` stayed `undefined` and the popover body froze at its first render (which is why a fresh page-load with the filter already in the URL looked fine). The five faceted count tables now bind the tooltip through the directive **value** (`v-b-tooltip.hover.bottom="getTooltipText(field)"`), so the counts update reactively. Guarded by `app/src/components/tables/columnHeaderTooltipReactivity.spec.ts`, which exercises the real directive both ways.

## [0.26.6] — 2026-06-30

Patch release: Force Apply on a blocked OMIM dictionary update no longer crashes with `$ operator is invalid for atomic vectors`, and the blocked-ontology banner now explains its two tables and links every version out to OMIM (#476, follow-up to #470/#474).

### Fixed

- **Force Apply crashed with `$ operator is invalid for atomic vectors`**: a blocked `omim_update` result carries `critical_entities`/`auto_fixes` as `purrr::transpose()` arrays, but `get_job_status(result_mode="full")` and the async worker both decode with `jsonlite::fromJSON(simplifyVector=TRUE)`, which collapses each array-of-objects into a **data.frame**. The force-apply payload helpers iterated those with `vapply(table, \(x) x$field, ...)` — over a data.frame that walks **columns** (atomic vectors), so the job died before the database write ever ran. The helpers were extracted to `api/functions/async-job-force-apply-payload.R` and now normalize any shape (data.frame, list-of-records, or empty) into a uniform tibble before column access, with data-shape regression tests covering the gap that let this ship.

### Changed

- **Blocked-ontology banner UX** (`ManageAnnotations` → Updating Ontology Annotations): the banner now explains why it shows two tables (critical entities need manual review; auto-fixable remappings are applied automatically on Force Apply), adds a **Disease** column to the auto-fixable table, and renders every version cell in both tables as an OMIM outlink (via the central `ontologyOutlink()` helper) with the `_N` version suffix stripped from the URL while the full versioned id stays visible as the label. The e2e fixture and admin blocked-banner spec were enriched to cover the new UI.

## [0.26.5] — 2026-06-30

Patch release: security update — four vulnerable transitive npm dependencies in the frontend lockfile are bumped to their patched versions, closing nine Dependabot alerts. Lockfile-only; no source, public-API, or behavioural changes.

### Security

- **Patched four vulnerable transitive npm dependencies** flagged by Dependabot (`app/package-lock.json` only — each parent's existing semver range already permitted the patched release, so no `package.json` change was needed and `npm update` resolves them):
  - **`undici` 7.25.0 → 7.28.0** — closes six alerts, including high-severity cross-origin request routing via SOCKS5 proxy pool reuse (GHSA-hm92-r4w5-c3mj) and TLS certificate-validation bypass in the SOCKS5 ProxyAgent (GHSA-vmh5-mc38-953g), plus Set-Cookie and cache-related issues. Dev/test only (pulled in by jsdom via vitest).
  - **`form-data` 4.0.5 → 4.0.6** — high-severity CRLF injection via unescaped multipart field names and filenames (GHSA-hmw2-7cc7-3qxx). Runtime, via axios.
  - **`@babel/core` 7.29.0 → 7.29.7** — arbitrary file read via `sourceMappingURL` comment (GHSA-4x5r-pxfx-6jf8). Build only, via vite-plugin-pwa → workbox-build.
  - **`esbuild` 0.27.7 → 0.28.1** — arbitrary file read when running the dev server on Windows (GHSA-g7r4-m6w7-qqqr). Build only, via vite.
- `npm audit` now reports **0 vulnerabilities**. Verified against the bumped lockfile with the production build, `type-check`/`type-check:strict`, vitest (1651 pass), eslint (0 errors), and the MSW↔OpenAPI verifier.

## [0.26.4] — 2026-06-30

Patch release: a blocked OMIM dictionary update no longer freezes the disease dictionary — brand-new terms are applied additively each cycle while critical entity-referenced changes await Force Apply — plus correctness fixes for Force Apply and the blocked-dictionary status banner (#470, #474).

### Added

- **Additive auto-apply for blocked OMIM dictionary updates** (#470): when an `omim_update` job is blocked by critical, entity-referenced changes, all brand-new, entity-unreferenced terms are now inserted additively (idempotent live anti-join inside the FK-disabled transaction; best-effort — an insert failure is logged and never turns the blocked job into a job failure) so the dictionary keeps growing each night instead of freezing. A successful additive insert chains the disease cross-ontology mapping refresh. A recurring `blocked` status is a standing-review flag, **not** a freeze; resolve the flagged entity-referenced changes via Force Apply.

### Fixed

- **Force Apply could never resolve a blocked OMIM update**: `PUT /api/admin/force_apply_ontology` looked up the blocked job with `get_job_status()` in summary mode, which omits the parsed `result_json`, so the "was the job blocked?" check always failed with `409 Referenced job was not blocked`. It now reads the job in `full` mode.
- **The blocked-dictionary banner stayed "blocked" after a successful Force Apply**: a resolved block kept re-asserting `blocked`/`stale` on every `/ManageAnnotations` load while its pending CSV lingered on disk (≤ 48 h). `derive_ontology_dictionary_status()` now excludes blocked jobs at or before the most recent successful apply.
- **`max_omim_id` could report a non-OMIM identifier**: a plain lexical `MAX()` over the mixed-prefix `disease_ontology_set` ranked `Orphanet:…` above `OMIM:…`; the lookup is now scoped to OMIM ids.
- **Additive apply no longer leaves a transaction open on the empty-insert branch** (a `return()` inside the `dbWithTransaction` block bypassed the commit on a shared connection), and the additive integration tests now actually run against a real connection instead of skipping/erroring on a nested transaction.
- **The MSW↔OpenAPI verifier (`make lint-app`) failed** on the `/api/admin/ontology/dictionary-status` handler because its mount map lacked the `/api/admin/ontology` and `/api/admin/analysis` sub-routers; both are now mapped before `/api/admin`.

## [0.26.3] — 2026-06-29

Patch release: analysis snapshots self-heal when stale, and the phenotype-cluster p-value / v-test columns render again.

### Fixed

- **Public analysis pages got permanently stuck on "This analysis is being prepared…" / `503` once their snapshot aged past 7 days** (GeneNetworks, Phenotype Clustering, Phenotype–Functional Correlation, and the other analysis presets): the startup self-heal (#420/#440) only re-built snapshots that were *missing*. Its skip probe, `analysis_snapshot_public_exists()`, returned TRUE for *any* public-ready row — including a `snapshot_stale` or `source_version_mismatch` one — so a stale snapshot was treated as "already present" and never re-enqueued, serving a 503 forever until an operator forced a rebuild. The bootstrap (and the non-`force` admin refresh) now use a staleness-aware probe, `analysis_snapshot_public_current()`, which only skips a preset whose active snapshot is genuinely current (`status_code == "available"`). Stale / version-mismatched snapshots now self-heal on the next API restart, exactly like missing ones. Regression-guarded by `test-unit-analysis-snapshot-repository.R` and `test-unit-analysis-snapshot-bootstrap.R`.
- **Phenotype Clustering "p-value" and "v-test" columns rendered blank**: the MCA stats arrive with dotted keys (`p.value`, `v.test`), and BootstrapVueNext's `BTable` renders an empty cell for a dotted field key (and Vue parses a `#cell-p.value` slot name as `cell-p` + a `value` modifier), so neither the column nor a custom cell slot could show the values. The rows are now normalized to flat aliases (`p_value`, `v_test`) via `normalizePhenotypeClusterRows()` before they reach the table, with the original dotted keys preserved for the Excel export. Regression-guarded by `phenotypeClusterTable.spec.ts` and `AnalysesPhenotypeClusters.spec.ts`.
- **The Phenotype–Functional Correlation page showed a raw "Request failed with status code 503" toast** while its snapshot was being prepared, instead of the friendly "being prepared" panel + retry shown by its sibling analysis pages. It now classifies the snapshot-preparing 503 via `isSnapshotPreparingError()` and renders the same graceful state. Covered by a new `AnalysesPhenotypeFunctionalCorrelation.spec.ts`.

### Dependencies

- Bumped the app production-minor-patch group (#472): `@unhead/vue` 3.1.4 → 3.1.6, `swagger-ui` / `swagger-ui-dist` 5.32.7 → 5.32.8, `vue` 3.5.35 → 3.5.39.
- Bumped the app dev-dependencies group (#473, 11 updates): `@axe-core/playwright` 4.11.3 → 4.12.1, `@playwright/test` 1.61.0 → 1.61.1, `@types/node` 26.0.0 → 26.0.1, `@vue/compiler-sfc` 3.5.35 → 3.5.39, `axios` 1.18.0 → 1.18.1, `eslint` 10.5.0 → 10.6.0, `globals` 17.6.0 → 17.7.0, `postcss` 8.5.15 → 8.5.16, `prettier` 3.8.4 → 3.9.3, `typescript-eslint` 8.61.1 → 8.62.0, `vite` 7.3.5 → 7.3.6.

## [0.26.2] — 2026-06-29

Patch release: restore the column-statistics header tooltips across all public tables and make the underlying counts correct everywhere.

### Fixed

- **Phenotypes / Genes column-header hover tooltips were missing** (regression surfaced after the v0.26.1 filter fixes): bootstrap-vue-next renders the `v-b-tooltip` popover as a child *inside* the `<th>`, and fixed-layout tables set `overflow: hidden` on header cells (for label ellipsis), which clipped the popover invisible. Only the Entities table escaped this, via an override scoped to `.entities-table`. The un-clip rule now lives once in `_tables.scss` and covers every public surface (`:is(.entities-table, .public-data-table) th.b-table-sortable-column`), so Phenotypes, Genes and the PubTator gene table show their "unique filtered/total values" hover again. The redundant per-component override was removed.
- **Curation comparisons table showed `0/<total>` for every column**: the `/api/comparisons` endpoint computed each column's total distinct `count` but never `count_filtered`, so the filtered side of the tooltip was always 0. A shared `fspec_merge_filtered_counts()` helper now computes `count_filtered` (distinct values after the active filter, joined by key) and is applied consistently across the entity, gene, phenotype, variant and comparisons endpoints — replacing four duplicated, position-based assignments (which also carried a latent ordering risk).
- **Curation comparisons column labels rendered with wrong casing** ("Sysndd", "Panelapp", "Omim ndd"): the component overwrote its curated labels with the backend's generic `str_to_sentence(key)` labels. The curated source labels (SysNDD, Gene2Phenotype, PanelApp, SFARI, OMIM NDD, …) are now re-applied over the backend field spec while keeping its count facets.
- **Some host-run R unit tests could not load the split helper modules** (`test-unit-endpoint-functions.R`: was `FAIL 9`): the `helper-functions.R` compatibility shim relied on a test helper that is out of scope when the shim is sourced into `globalenv`. It now resolves its sibling modules relative to its own file location, independent of caller environment or working directory (`FAIL 0 | PASS 57`).

### Changed

- Frontend column-header tooltip text is generated by the shared `useColumnTooltip` composable on all faceted tables (standard `getTooltipText`; guarded `getCompactTooltipText` for analysis tables whose columns may lack counts), removing duplicated inline expressions.
- Extracted `generate_comparisons_list()` into `api/functions/comparisons-list.R` (registered in `load_modules.R`), keeping `endpoint-functions.R` well under the file-size ceiling.

## [0.26.1] — 2026-06-29

Patch release: public table filter fixes and dependency maintenance.

### Fixed

- **Phenotypes table froze when filtering by Category** (#466): `filtered()` reassigned `this.filter` to a fresh object (via `applyPhenotypeLogicMode()`), which re-fired the deep `filter` watcher → `filtered()` → reassign → an infinite "Maximum recursive updates" loop that hung the page on any filter change. The AND/OR logic mode is now applied in place (idempotent), so the object reference is stable and the watcher settles. Regression test added.
- **Curation comparisons Table filters reverted to stale results** (#467): the table applied every browse response with no guard, so a slow earlier (unfiltered) request could resolve after a newer filtered one and clobber it ("filter to a gene, then it reverts"). The load now carries a monotonic serial id and drops superseded responses (the same lightweight guard `PanelsTable` uses). Regression test added. The same stale-response race was also swept across the other server-paginated tables: `PublicationsNDDTable` and the admin `ManageOntology` table had hand-rolled per-params dedup but no stale guard — both were migrated to the shared `createTableRequestCoordinator` (dedupe + `isCurrent` stale-drop), which also removed their bespoke dedup. `TablesEntities`/`TablesGenes`/`TablesPhenotypes` already used the coordinator; `PanelsTable` already had a serial guard. (`PubtatorNDDTable` is the remaining gap, deferred to a dedicated refactor so its 900+-line SFC can be modularised first rather than grown.)

### Added

- **Administrator view "Manage Ontology Mappings"** (`/ManageOntologyMappings`): an admin surface to monitor and trigger the disease cross-ontology mapping refresh. Shows the latest build provenance (MONDO release, term/xref/mapping/disease counts, status, duration) from `GET /api/admin/ontology/mappings/status`, a prominent cold-start warning when no build exists yet, and a "Refresh now" button (`POST /api/admin/ontology/mappings/refresh?force=true`) with live job progress. The mappings still populate automatically on startup (bootstrap), weekly (cron), and after an operator ontology refresh — this view adds operator visibility and a manual trigger.

### Dependencies

- Bumped the production-minor-patch app dependency group (4 updates, #461), the dev-dependencies app group (2 updates, #462), `@types/node` 25 → 26 (#463), the Docker Compose images group (mysql 8.4.9 → 8.4.10, mailpit v1.30.1 → v1.30.2, #464), and `actions/checkout` 6 → 7 in CI (#465).

## [0.26.0] — 2026-06-20

Minor release: disease cross-ontology mappings (MONDO / Orphanet / OMIM / DOID / UMLS / MedGen / NCIT / GARD / EFO) across database, API, and frontend, in lockstep across app, API, and DB schema versions.

### Added

- **Disease cross-ontology mappings** (#454): every SysNDD disease now carries provenance-tracked cross-references to external disease ontologies, anchored on MONDO as the hub (a disease's OMIM id resolves to MONDO via SSSOM, and MONDO's xrefs supply Orphanet/DOID/UMLS/etc.).
  - **Database** (migration `036`): a normalized `disease_ontology_mapping` store (source of truth, with `predicate`/`source`/`release_version`), a local `mondo_term`/`mondo_xref` index, a build-provenance table, and refreshed projection columns (`UMLS`/`MedGen`/`NCIT`/`GARD`/`ontology_mapping_release`) on `disease_ontology_set`. The cross-charset join key is utf8mb3-pinned; `ndd_entity_view` is intentionally untouched.
  - **Ingestion & refresh**: a durable `disease_ontology_mapping_refresh` async job (single-flight `GET_LOCK`, transactional rebuild, conditional-GET no-op, provenance meta rows); Administrator endpoints `POST/GET /api/admin/ontology/mappings/*`; a weekly `ontology-mapping-cron` sidecar; a staggered startup bootstrap; and a re-trigger after operator ontology refreshes so the projection columns can't drift. Validated end-to-end on real MONDO data (release 2026-06-02, ~40,645 mappings across ~6,766 diseases).
  - **Read API**: a cheap, public, DB-only `GET /api/disease/mappings?entity_id=|disease_ontology_id=` that resolves entities through `ndd_entity_view` (public surface only). `/api/ontology` also now returns the new columns.
  - **Frontend**: the Entities list row expansion gains an inline ontology outlink strip, and the Entity detail page gains a "Linked disease ontologies" card (`EntityOntologiesCard`), both rendering external outlinks via a central URL-template module (`ontology_links.ts`) and a typed client that normalizes the API's array-wrapped scalars.

### Operational

- New env vars: `DISEASE_ONTOLOGY_MONDO_OBO_URL` / `_SSSOM_URL`, `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP` (default true), `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_STAGGER_SECONDS` (default 360), `ONTOLOGY_MAPPING_REFRESH_AT` / `_DOW`, and `EXTERNAL_PROXY_MONDO_*` budget tuning for the ~50–80 MB MONDO artifacts. The worker must be restarted on deploy to source the new job handler; the cron sidecar is DB-only while the worker (which runs the job) needs egress.
- **Database schema version → 0.26.0** (ships migration `036`): set `DB_VERSION=0.26.0` on deploy (`./db/scripts/update-db-version.sh 0.26.0 >> .env`) so the App and `/api/version` report the deployed schema version.

## [0.25.2] — 2026-06-16

Patch release: LLM cluster-summary judge robustness and startup job scheduling.

### Fixed

- **Phenotype judge permanently rejecting legitimate clusters** (#448): a sparse, depletion-defined cluster (e.g. the "mild, predominantly non-syndromic" phenotype cluster) had no correction path — the judge prompt treated any grounded clinical synthesis beyond the verbatim enriched terms as fabrication, and the verdict could never correct the main summary text, so the row was rejected forever. The verdict type now carries an optional `corrected_summary`, applied via `apply_judge_corrections()`, so isolated molecular phrasing or a single over-reaching label is salvaged via `accept_with_corrections` instead of `reject`. The phenotype judge prompt now explicitly allows grounded clinical synthesis of the listed phenotypes while preserving the hard-reject rules (fundamentally molecular summaries, direction inversion, fabricated specific phenotypes, and < 50% grounding) — no grounding threshold is loosened. The admin LLM cache view now surfaces the judge verdict, reasoning, and applied corrections (badge column + detail panel), reading both the top-level (accepted) and nested `validation` (rejected) persisted shapes. `llm-judge.R` was brought back under the file-size ceiling by extracting the prompt builders to `functions/llm-judge-prompts.R`.

### Performance

- **Staggered startup analysis-snapshot bootstrap** (#447): on a fresh start the bootstrap enqueued all snapshot presets plus the PubtatorNDD nightly as claim-eligible at the same instant, so the heavy `functional_clusters` build (recursive STRING enrichment) contended for the shared DB pool / CPU and could outrun its worker lease. The startup bootstrap now staggers heavy builds using the existing `async_jobs.scheduled_at` claim gate: heavy presets get a `scheduled_at` offset (`ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS`, default 120s; `0` disables) while light presets stay immediately eligible, and the PubtatorNDD nightly bootstrap is offset separately (`PUBTATORNIDD_BOOTSTRAP_STAGGER_SECONDS`, default 240s). Only the automatic startup path staggers — the admin `force` refresh and the operator script submit immediately. No schema change and no extra worker.

## [0.25.1] — 2026-06-15

Patch release: reliability and UX fixes for the analysis-snapshot subsystem (GeneNetworks / phenotype clusters) and the LLM cluster summaries.

### Fixed

- **GeneNetworks cluster selection** (#441): selecting a functional cluster showed neither its AI summary nor its enrichment table. The snapshot endpoint serialises `cluster` as a string (`"1"`) while the network graph emits numeric ids (`[1]`), so the strict-equality lookups never matched and the summary fetch never fired. Cluster-id comparisons now coerce both sides; the same hardening is applied to the phenotype clusters view.
- **Analysis snapshots could fail permanently after a deploy** (#440): heavy snapshot builds (e.g. `functional_clusters`' recursive STRING enrichment) could outrun the worker lease under startup contention and were reaped to `LEASE_EXPIRED` with no retry, so the page 503'd indefinitely. Snapshot refresh jobs are now retryable (`max_attempts = 3`) and the stale-lease reaper requeues them — the startup bootstrap self-heals.
- **"Analysis being prepared" state for GeneNetworks** (#440): a `snapshot_missing` 503 now renders a friendly "being prepared / Check again" panel instead of a raw error toast, matching the network graph and phenotype views. Also fixed `isSnapshotPreparingError`, which only matched a bare-string problem `code` and never the real `["snapshot_missing"]` array shape — so the preparing state previously never triggered against the live API.
- **Rejected LLM cluster summaries are now debuggable** (#443): the LLM-as-judge's verdict and reasoning are persisted on the rejected cache row (internal QA metadata embedded in `summary_json`) instead of being discarded, so a persistently-rejected cluster can be diagnosed.

## [0.25.0] — 2026-06-14

Minor release: surface the read-only SysNDD MCP service in the UI — a footer icon beside the API/Swagger link and an expanded `/mcp` information page with client setup instructions.

### Added

- **MCP footer icon** beside the API/Swagger icon in the footer, linking to the `/mcp` information page. Uses the official Model Context Protocol logomark (MIT / public-domain geometric mark, recolored to the SysNDD brand) served from `/img/mcp.svg`.
- **Expanded `/mcp` information page**: per-client setup for coding clients (Claude Code `claude mcp add --transport http`, Claude Desktop, Cursor) and browser chatbots (Claude.ai custom connectors, ChatGPT developer-mode connectors), a read-only tool catalog, recommended workflow, and clearer transport/safety notes.

### Fixed

- **MCP footer asset path collision**: the footer logo is served from `/img/mcp.svg` instead of `/mcp.svg`. The dev Vite `/mcp` proxy (and production `/mcp` routing) forwards the `/mcp` prefix to the MCP transport, which returns `405` on a `GET`, so the icon silently fell back to the app icon.

## [0.24.0] — 2026-06-14

Minor release: public analysis snapshots now auto-bootstrap on startup so a fresh deploy heals on its own, plus Administrator refresh/status endpoints and a friendlier "being prepared" frontend state (#420).

### Added

- **Startup auto-bootstrap for analysis snapshots** (#420): after migrations, `analysis_snapshot_bootstrap_on_startup()` idempotently enqueues `analysis_snapshot_refresh` jobs for any supported preset lacking an active public-ready snapshot, so `/GeneNetworks` and `/PhenotypeClusters` heal automatically after a fresh deploy instead of serving 503 `snapshot_missing`. Gated by `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP` (default on), existence-checked (a restart with snapshots already present enqueues nothing), dedup-safe, and never crashes boot. Mirrors the #421 PubtatorNDD bootstrap pattern.
- **Administrator snapshot endpoints** (#420): `POST /api/admin/analysis/snapshots/refresh` (optional `analysis_type`, optional `force`) submits the refresh jobs and returns their ids; `GET /api/admin/analysis/snapshots/status` reports per-preset state (missing / available / stale / source_version_mismatch) with timestamps and row counts — letting an operator rebuild/inspect snapshots without SSH or `docker exec`. Non-admin callers get 403.
- **Frontend "analysis is being prepared" state** (#420): GeneNetworks and PhenotypeClusters now render a friendly retry panel when the API returns a snapshot 503, instead of a raw `AxiosError` and an empty page.

### Changed

- All three snapshot submit paths — the startup hook, the new admin endpoint, and the operator script `scripts/refresh-analysis-snapshots.R` (now `force=TRUE`) — share one `service_analysis_snapshot_submit_refresh()` function. The shared submit/status/bootstrap functions live in a focused new `services/analysis-snapshot-refresh-service.R` to keep the service files under the 600-line ceiling.

## [0.23.0] — 2026-06-14

Minor release: Administrator-views UX hardening and maintainability (audit follow-through to >9/10).

### Added

- **Per-view document titles** on the Administrator views (ManageUser/Ontology/Annotations/About/Backups/Pubtator/LLM/NDDScore/Metadata/AdminStatistics), via `useHead` — they previously rendered the generic "SysNDD |". Renders e.g. "Manage Users | SysNDD …".
- **Confirmation modals** replace native browser dialogs in the app's modal language: a `SavePresetModal` for naming a filter preset (was `window.prompt()` in ManageUser), a reusable `ConfirmActionModal` for the large-log-export gate (was `window.confirm()` in the logs table), and a confirmation gate (`useConfirmGate`) before the four heavy/irreversible ManageAnnotations operations (ontology update, force-apply, comparisons refresh, refresh-all).
- **Server-side "refresh all" for publications** — `POST /api/admin/publications/refresh` accepts `all=true` to enumerate the whole corpus server-side; the client no longer pulls every PMID. An empty request still 400s (safety guard).

### Changed

- **Gemini cost estimate is no longer hardcoded.** The LLM-admin cache cost estimate is centralized in the model catalog (`llm_model_pricing()` with per-model `price_input/output_per_million`) and keyed off the active model (`get_default_gemini_model()`), removing the stale "Gemini 2.0 Flash" rate.

### Fixed

- **Developer-reference version display** (`/API`) rendered the API and Database versions as raw Plumber 1-element arrays (`v[ "0.22.0" ]`) with a stray `[ "unknown" ]` commit badge (the badge guard `!== 'unknown'` never matched the array). The `/api/version` client now unwraps the array-wrapped scalars, so the versions render as plain `v0.22.0` / `v1.0.0` with the commit badge correctly hidden when unknown.

### Internal

- **`TablesLogs.vue` split** (1160 → 378 lines) into a `useLogTable` composable + `LogFilterToolbar` child + `logTableConfig`; file-size baseline ratcheted down.
- Job-status watchers in ManageAnnotations extracted to `useAnnotationJobReactions`; preset state moved into `useUserData` — both to keep oversized SFCs under the file-size baseline while adding behaviour.
- Documented that a durable HTTP job-cancel route is absent (the service layer supports cancellation but no endpoint exposes it) — recorded as a future change.

## [0.22.0] — 2026-06-14

Minor release: PubTatorNDD performance, stability, and automatic nightly updates.

- **Performance** — precomputed `pubtator_gene_summary` table (migration 035) replaces per-request `collect()`+`tidyr::nest()`; `/pubtator/genes` drops from ~800ms to ~100ms (Stats path 83ms) and the payload shrinks ~3×. Missing annotation/search-cache indexes added (migration 034).
- **Stability / bug fixes** — repaired the enrichment refresh (the NDD-corpus probe `@DISEASE_neurodevelopmental` silently returned 0; now `@DISEASE_Neurodevelopmental_Disorders`); fixed the worker external-time budget never resetting per job (which broke every external-calling job after the first); corrected the `publication_count`/`entities_count` double-count from the view's gene×publication×entity fan-out (now distinct counts, consistent with `pmids`).
- **Automatic updates** — new `pubtatornidd-cron` Compose sidecar enqueues a durable `pubtatornidd_nightly` job that incrementally fetches new publications, refreshes enrichment, and refreshes the summary table; single-flighted via a MySQL advisory lock.
- **Gene listing** — graceful degradation with a deterministic `-publication_count` fallback and an `enrichmentStatus` meta flag when no enrichment snapshot exists.
- **Frontend** — PubTatorNDD annotation-parse + gene-symbol caches are now bounded LRU; Stats chart re-render debounced; stale per-gene publication cache cleared on filter/sort; component split under the size baseline.

## [0.21.9] — 2026-06-14

Patch release: home-page performance — keep heavy libraries off the landing-page critical path.

### Changed

- **Home page no longer downloads ~600 KB of unused code.** `HomeView.vue` imported from the `@/composables` barrel, which statically re-exports heavy composables (`use3DStructure` → `ngl` 1.3 MB, `useMarkdownRenderer` 0.7 MB, `useCytoscape`/`useNetworkData` → d3, exceljs). Rollup cannot tree-shake the barrel, so the home route chunk eagerly pulled all of that in. Importing the two light composables (`useToast`, `useText`) directly bypasses the barrel; home JS payload dropped 740 → 211 KiB (−71%) and main-thread blocking from those modules executing went to ~0. This directly targets the mobile-Lighthouse LCP and TBT losses.
- **`gsap` is loaded lazily** (and split out of the `viz` chunk) — it is only needed for the home count-up animation that runs after statistics load, so it no longer sits on the first-load critical path; it degrades gracefully to instant numbers if not yet ready.
- **Leaner PWA precache.** The service worker no longer precaches the largest route-only chunks (`ngl`, `exceljs`, Swagger/`ApiView`, markdown) on first visit; they are runtime-cached on demand instead. First-visit background precache dropped 8.59 → 4.76 MB (−45%).

### Internal

- `app/.gitignore` now robustly ignores build output (`dist`, `dist-*`, `stats.html`, `*.tsbuildinfo`, `.lighthouseci`).

## [0.21.8] — 2026-06-13

Patch release: a public-page design + accessibility pass, plus review fixes.

### Changed

- **Accessibility lifted across all public pages (Lighthouse a11y mean 96.6 → 99.8; 23/25 pages now score 100; best-practices and SEO 100 on all 25).** Root-caused and fixed app-wide issues via shared components: the `heading-order` failure (the first-visit `DisclaimerDialog` used `h5`/`h6` → now `h2`/`h3`); `td-has-header` on every data table (filter-row cells marked `role="presentation"`); `select-name` and `button-name` on filter/page-size selects and icon controls; and `aria-prohibited-attr` (636 instances) on the gene-detail protein-domain lollipop SVG. The shared `TableShell`/`AnalysisShell` were moved onto the design tokens (neutral/`--border-subtle`/radius/shadow/brand blue) and each public page now has exactly one route-level `<h1>` (`TableShell` gained a `heading-level` prop, default `2`).
- **Low-contrast chips replaced with an AA token system.** Ad-hoc pastel chips that failed WCAG AA (e.g. Bootstrap blue `#0d6efd` on `#e7f1ff` ≈ 3:1, ~29 instances on PubTator) were replaced with shared `.sysndd-chip--*` classes in `app/src/assets/scss/partials/_chips.scss`; the app-wide `.text-muted` was aligned to `--neutral-700`.
- **Analyses menu:** the "Correlation matrix" entry was renamed to **"Phenotype–function correlation"** and moved to the end of the Analyses dropdown, and the page is now standalone (its misleading cross-link tabs, which navigated away to the phenotype correlogram, were removed).

### Fixed

- **Detail-page section cards size to their content again.** A layout-stability change had reserved a large fixed `min-height` on resolved cards, which made sparse cards (e.g. a Phenotypes card with one term) render as tall empty boxes with uneven heights; the reservation now applies only to the loading skeleton, so cards adapt to content (e.g. a Phenotypes card on `/Entities/1317` dropped from 288px to 107px).
- **The analysis correlation/matrix charts render again.** An attempted responsive-width change computed the SVG size before its container was laid out, so the D3 matrices (Curation similarity, phenotype/variant correlograms, time plot, phenotype–function correlation) rendered no SVG or at the wrong size; the chart sizing was reverted to its working approach.

### Internal

- Recorded the justified file-size growth from the accessibility/token additions in `scripts/code-quality-file-size-baseline.tsv` (added lines are necessary ARIA labels, roles, token styles, and chip classes rather than new behavior). Full audit, spec, plan, and before/after evidence live under `.planning/audits/2026-06-13-frontend-audit/`.

## [0.21.7] — 2026-06-13

Patch release removing the floating help/feedback widget and its backing "Cite" endpoint.

### Removed

- **The floating smiley help/feedback widget (`HelperBadge`) is gone from every page.** A fixed bottom-right green circle with a `bi-emoji-smile` icon opened a dropdown of Cite / Like / Improve / Docs / Help actions. It was lightly used and clashed with SysNDD's quiet, table-first visual direction, so it has been removed from the global app shell (`App.vue`) and deleted. Documentation and Help destinations remain reachable from the footer.
- **The `internet_archive` "Cite" endpoint and all of its supporting code are removed.** The widget's *Cite* action called `GET /api/external/internet_archive`, which forwarded the current page URL to archive.org's SPN2 (Save Page Now) API. With the widget gone the endpoint had no remaining caller, so the route (`api/endpoints/external_endpoints.R`), its backing functions (`api/functions/external-functions.R` — `post_url_archive` / `is_valid_archive_url`), the typed frontend client (`createInternetArchiveSnapshot` in `app/src/api/external.ts`) and its tests, the `test-unit-archive-url.R` unit test, the endpoint-checklist row, the docs section, and the now-unused `archive_access_key` / `archive_secret_key` / `archive_base_url` config keys have all been removed. The gnomAD / UniProt / Ensembl / AlphaFold / MGI / RGD external-proxy endpoints are unaffected. Verified in a restarted stack: `GET /api/external/internet_archive` returns `404` while the kept proxy endpoints still return `200`.

## [0.21.6] — 2026-06-13

Patch release unifying the Genes/Entities detail-page card borders with the rest of the app.

### Fixed

- **Detail-page cards no longer use a heavy black border.** The Genes (`/Genes/:symbol`) and Entities (`/Entities/:entity_id`) detail pages — plus the Ontology view (`/Ontology/:disease_term`) and the admin Job History card — wrapped their cards in `border-variant="dark"`, which rendered a heavy near-black Bootstrap border (`#212529`) that clashed with the home page and the public `/Entities`/`/Genes` tables. They now use the app-wide subtle surface border (pale blue-gray, `#d9e0ea`), so the detail/admin cards match the home hero/panels and the reference tables. This aligns with the visual design guide ("borders: pale neutral/blue-gray lines with low visual weight"; "avoid heavy black/dark borders"). The change is presentation-only — verified with Playwright at `1440px` and `390px`, every visible detail-page card border now computes to `rgb(217, 224, 234)` (`#d9e0ea`) with no remaining visible dark card borders.

### Changed

- **Introduced a canonical `--border-subtle` design token (`#d9e0ea`) and a `.border-subtle` utility class.** The ~30 component stylesheets that previously hard-coded the `1px solid #d9e0ea` panel border (home, user, analyses, curation, and form/wizard surfaces) now reference the token, giving the subtle surface border a single source of truth. The migration is value-identical; no surface changes appearance except the detail/admin cards described above.

## [0.21.5] — 2026-06-13

Patch release making the global search input look consistent between the home hero and the navbar.

### Fixed

- **The global search input now looks the same on every page.** The shared `SearchCombobox` rendered with two divergent looks: the home (`/`) hero variant used a heavy black input border (`border-dark`) and a dark/neutral action button (`btn-outline-dark`), while the navbar variant (shown on `/Entities`, `/Genes`, and all non-home routes) used the medical-blue action button but was passed a literal `placeholder-string="..."`, so it displayed a broken `...` placeholder instead of helpful text. Both variants now converge on one design-token-aligned treatment — the global low-weight `.form-control` neutral border with a medical-blue focus ring, the medical-blue `btn-outline-primary` action button, and the `Search genes, diseases, IDs` placeholder — differing only by size (default in the hero, `sm` in the navbar). This aligns with the visual design guide ("use blue for action and navigation"; "borders: pale neutral/blue-gray lines with low visual weight"). Suggestions, submit, and keyboard navigation are unchanged.

## [0.21.4] — 2026-06-13

Patch release fixing the NDDScore gene-predictions table on mobile.

### Fixed

- **NDDScore predictions are readable on mobile again.** The `/NDDScore` gene table rendered its 10-column fixed-layout `b-table` directly on small screens, crushing every column to ~28px so values truncated to `0..`, `Ve`, `Kn` with overlapping headers — the "stacked Bootstrap table" anti-pattern the visual design guide warns against. It now follows the same responsive pattern as the reference `/Entities` and `/Genes` tables: the desktop table is hidden below the `md` breakpoint (`d-none d-md-block`) and a purpose-built `NddScoreGeneMobileRows` record-card list renders instead (`d-md-none`). Each card shows gene + rank + an ML-prediction score / risk-tier / confidence / Known-vs-New chip row, with an expandable details panel for HGNC, percentile, top inheritance, model split, and predicted HPO. No horizontal overflow at 390px; the desktop table is unchanged. The "model-derived prediction, separate from curated SysNDD evidence" framing is preserved.

## [0.21.3] — 2026-06-13

Patch release hardening the API against slow external/analysis endpoints blocking cheap routes (#344), fixing the gene-page request-ordering regression that made our own "Associated" data load last, and repairing two latent defects that made it impossible for any public analysis snapshot (GeneNetworks, clustering, correlations) to be built.

### Fixed

- **Slow external/analysis endpoints can no longer block cheap routes (#344).** Three external HTTP calls that bypassed the central per-provider budget are now bounded: the UniProt step-2 features fetch (previously `req_timeout(30)` + `max_seconds=120`, a ~120s worker-occupying window) now goes through `make_external_request()`; the GeneReviews E-utilities call (a budget bypass reintroduced in #389) and the worker-only gnomAD-batch chunk request now derive their timeout/retry from `external_proxy_budget()`.
- **"Associated" entities (our own data) no longer load after the external enrichment cards on gene pages (#344).** `GeneView` fired its five external-provider fetches synchronously in `setup()` (via `useResource`'s immediate watcher) before the child entities table dispatched its request, so on the single-threaded API the cheap entity request queued behind up to six slow upstream calls and finished last (measured 4041ms on a symbol URL). External activation is now deferred to a post-mount macrotask so own-data is requested first (entity completion 4041ms → 391ms).
- **Public analysis snapshots can now be built — GeneNetworks/analysis pages are no longer permanently `snapshot_missing` (#344).** Two latent defects made `analysis_snapshot_refresh` impossible to complete: (1) the MySQL `GET_LOCK` advisory-lock name was 109–124 chars while MySQL caps it at 64 (errno 4163), and (2) the builder wrote each cluster's `equals(hash,…)` filter expression into `cluster_hash CHAR(64)`, overflowing it (errno 1406) and rolling back the refresh. Both fixed; after deploy, run `make refresh-analysis-snapshots` once to populate the public-ready snapshots.

### Added

- **Per-request external-time ceiling + observability (#344).** A request-scoped accumulator (`EXTERNAL_PROXY_REQUEST_MAX_SECONDS`, default 15s), wired into both universal proxy wrappers, short-circuits further external work once a single request's accumulated external time crosses the ceiling — covering single-endpoint paths the 12s aggregate budget never governed. The `postroute` hook now logs `[request-timing] … duration_ms=… external_ms=… slow=…` (slow over `API_SLOW_REQUEST_MS`, default 2000), attributing slow requests to external time. New tunable env knobs: `EXTERNAL_PROXY_GENEREVIEWS_*`, `EXTERNAL_PROXY_GNOMAD_BATCH_*` (20/30/3 defaults).
- **Regression guards + tests (#344).** `test-unit-external-budget-guard.R` fails CI on any hardcoded external timeout literal; `test-unit-cheap-route-isolation.R` keeps `/health`, `/auth`, `/statistics` free of external-fetcher coupling; `test-integration-slow-provider-isolation.R` proves a slow provider fast-fails while a cheap read stays bounded; and the local-only `app/tests/e2e/slow-provider-resilience.spec.ts` + `gene-page-own-data-priority.spec.ts` lock in gene-page resilience and own-data request ordering. Worker-pool isolation remains tracked in #154.
- **Operator tooling to build analysis snapshots (#344).** `api/scripts/refresh-analysis-snapshots.R` and `make refresh-analysis-snapshots` submit `analysis_snapshot_refresh` jobs for every supported preset; previously no trigger existed (it is intentionally admin/operator-only and heavy).

## [0.21.2] — 2026-06-13

Patch release for Sprint 2 of the continuous oversized-file refactor (#346) — all nine workpackages (#394–#402, WP1–WP9), each landed as a behavior-preserving PR (#404–#412) and merged after integration validation (type-check, strict type-check, full Vitest suite, ESLint/MSW, SEO, R API unit tests, and a Playwright E2E parity check against `master`). Every reduction moves the file-size ratchet baseline downward only.

### Changed

- **WP1 — D3/visualization (#406).** `GeneStructurePlotWithVariants.vue` 1306→680 via a new `components/gene/gene-structure-plot/` module directory (context/render/tooltip/export); `GenomicVisualizationTabs`, `ProteinDomainLollipopPlot`, `VariantPanel`, and `useCytoscape` also reduced (four under the 600-line ceiling), with new unit tests for the extracted pure transforms.
- **WP2 — tables (#409).** `TablesPhenotypes.vue` 1153→873 via a new `PhenotypeFilterToolbar.vue`; the duplicated `normalizeSelectOptions` copies migrate onto the shared `utils/selectOptions.ts`; `TablesLogs` cancel-path hardening.
- **WP3 — analyses (#410).** Six pure-logic modules extracted (`usePubtatorParser`, publications/gene-cluster/curation-comparison/upset/phenotype-cluster helpers), each with specs; `NetworkVisualization` left untouched to preserve the GeneNetworks preset-layout invariant.
- **WP4 — NDDScore + LLM (#412).** `ManageLLM`, `ManageNDDScore`, `LlmSummaryCard`, and `NddScoreGeneDetail` drop under 600 via composables (`useLlm*`, `useNddScore*`) and a new `LlmOverviewPanel.vue`; the "ML prediction, separate from curated evidence" copy invariants are preserved.
- **WP5 — curation views (#411).** `CreateEntity.vue` 637→540 via `useEntityCreateOptions`; `ManageReReview.vue` 1579→1514 via static `reReviewTableConfig` extraction (no workflow/soft-LIMIT/batch logic touched). Deeper Options→composition decomposition of the curation views is deferred to a dedicated follow-up.
- **WP6 — admin views (#408).** `ManageBackups.vue` 1115→579 and `ManagePubtator.vue` under the ceiling via job-polling/upload/confirm-modal composables reusing `useAsyncJob` and the `LogDeleteModal` confirm pattern.
- **WP7 — API endpoints (#405).** `publication_endpoints.R` 1234→1141 (shared `collect_with_filter_pushdown`/`build_cursor_meta`/`build_cursor_links` helpers) and `user_endpoints.R` 1128→1117 (DRY'd password-complexity rule), with paired `test-unit-*-endpoint-helpers.R`.
- **WP8 — API services/functions (#407).** `response-helpers.R` 860→535 and `logging-repository.R` 744→237, splitting cohesive query-builder/field-selection layers into sibling files registered in `load_modules.R`.

### Documented

- **WP9 — DB prep scripts (#404).** `db/11_Rcommands_..._comparisons.R` 636→474 via a sourced helper file; `db/C_Rcommands_set-table-connections.R` recorded in `AGENTS.md` as an intentional size exception (its `ndd_entity_view` body must stay mirrored with migration 026).

## [0.21.1] — 2026-06-11

Patch release for Sprint 1 of the continuous oversized-file refactor (#346, PR #403).

### Changed

- **Oversized-file refactor program structured.** Issue #346 is broken into nine workpackage sub-issues (#394–#402) with a sprint plan; the file-size ratchet baseline is tightened to current actuals (three entries removed, ~14 lowered) and only moves downward.
- **`useD3Lollipop` split into a module directory.** The 1125-line composable now lives in `app/src/composables/d3-lollipop/` (context/helpers/tooltip/render/export modules, largest 388 lines) with unchanged public API and new unit tests for the pure helpers.
- **`TablesLogs` slimmed.** The delete-confirmation modal is extracted to `LogDeleteModal.vue` (with component tests) and the duplicated select-option normalizer is centralized in `app/src/utils/selectOptions.ts`.
- **Strict type-check D3 cohort retired.** `@types/d3` is installed; the d3-lollipop modules, `useD3GeneStructure.ts`, `ProteinDomainLollipopPlot.vue`, and `PubtatorNDDStats.vue` are now strict-clean and removed from the strict-scope exclusion lists.

### Fixed

- **Log delete-modal state reset.** The modal stays mounted so the hidden lifecycle reliably resets the confirmation text and delete mode on every close path (previously the reset handler never fired under `v-if`, leaving the mode stale).
- **`log-cleanup` container no longer reports unhealthy.** The service inherited the API image's Plumber-port healthcheck it could never satisfy; the healthcheck is disabled for the scheduler-only container.

## [0.21.0] — 2026-06-11

Feature release integrating 16 pull requests across the API, app, and database (issues #14, #22, #25, #32, #33, #36, #37, #46, #54, #89, #98, #105, #175, #344, #347, #348, #353, #360).

### Added

- **Curation and correlation matrix navigation links.** The curation matrix and phenotype correlation matrix are now discoverable from the Analyses navigation and cross-linked between related analysis pages (#89).
- **Scheduled database log cleanup.** A `log-cleanup` Compose service prunes old rows from the operational `logging` table on a daily, configurable schedule (`LOG_RETENTION_DAYS`, `LOG_CLEANUP_AT`, dry-run), reusing the API image (#105).
- **Research-popularity-normalized PubtatorNDD ranking.** Gene NDD co-occurrence counts are normalized with enrichment ratio, NPMI, and Fisher's exact test + Benjamini-Hochberg FDR, with the table defaulting to the enrichment ranking (migration 027, #175).
- **Semantic database version.** A single-row `db_version` table tracks the semantic DB version and last `db/`-folder commit, surfaced in `GET /api/version` and on the About page (migration 028, #22).
- **Re-review refusal action.** Re-reviewers can decline a complex / out-of-scope entry, flagging it for specialist attention as a distinct state surfaced to curators (migration 029, #54).
- **Analysis snapshot provenance lineage.** The `meta.snapshot` block returned by public REST and MCP analysis reads now includes `input_hash`, `payload_hash`, and `record_counts`, completing the provenance/FAIR output contract from issue #347.
- **External-provider isolation coverage.** Added a slow-provider regression test asserting cheap routes stay responsive, and structured per-provider timing logs (upstream duration, timeout, cache hit/miss, status); deep worker-pool isolation remains tracked in #154 (#344).
- **Combined status & review modal with role-gated direct approval.** Modify Entity gains a single status+review workflow and a Curator+ direct-approval toggle enforced on both the client and the API (#36, #37).
- **Admin metadata vocabulary management.** A new Administrator `/ManageMetadata` view administers SysNDD-managed curation vocabularies with tiered editability and in-use-protected soft deletes (migration 033, #32).
- **GeneReviews coverage.** A curator view looks up GeneReviews availability per gene via NCBI E-utilities, attaches chapters to entities, and exports coverage; flags genes lacking a chapter (#14, #46).
- **Centralized Gemini model configuration.** Model selection resolves through a single validated source of truth, dropping the shut-down `gemini-3-pro-preview` default in favor of a current Gemini 3.x model (#348).
- **CSR / certificate renewal automation design.** An ADR plus a dry-run-safe CSR-generation skeleton and operator runbook (ACME vs scripted-CSR), pending the institutional CA decision (#25).
- **Reproducible database-creation scripts.** The `db/` data-prep scripts are config-ized (no hardcoded URLs/secrets), working-directory independent, orchestrated by a master runner, documented, and support a reproducible SQLite SysID source (#33).

### Fixed

- **VariO ontology links repaired.** Broken VariO term links now resolve via EBI OLS4 and the base URL is configurable; the larger ontology data migration is documented for curator sign-off (#98).
- **MCP search and analysis defects.** Fixed `publication_type` aggregation, `null` serialization in `structuredContent`, zero-result query echo, and snapshot-unavailable status mapping in the read-only MCP layer, with a spec/plan for the remaining benchmark items (#353).

### Changed

- **Quieter local CI.** `make ci-local` no longer prints an alarming expected MySQL access error on the success path and emits a classified skip summary, with verification strength unchanged (#360).

## [0.19.1] — 2026-05-15

Patch bump for the GeneNetworks cluster-selection UX.

### Added

- **Functional cluster parent nodes are selectable.** Clicking a Cytoscape compound cluster parent filters the graph and table to that cluster while gene-node clicks continue to open the gene page.
- **All-clusters summary cue.** The GeneNetworks table shows a compact AI-summary cue in all-clusters mode with a direct action to focus the first available cluster.

### Fixed

- **Cluster selection can be cleared from the graph.** Clicking the empty network background returns the graph and table to the all-clusters view.
- **Stale AI summary requests no longer replace the active cluster summary.** Rapid cluster changes now ignore older summary responses once a newer cluster selection is active.

## [0.19.0] — 2026-05-14

Minor bump for PR #338's admin visual-design pass, log-table performance work, LLM regeneration feedback fixes, and worker egress correction.

### Added

- **Canonical SysNDD visual guide.** Added `documentation/10-visual-design-guide.md`, admin visual ratings, and cross-agent/editor pointers for future UI work.
- **Shared admin operation surface.** Added `AdminOperationPanel` and migrated multiple admin/annotation views away from dark Bootstrap card chrome.

### Changed

- **Admin operation pages are more consistent.** Refined ManageLLM, ManagePubtator, ManageBackups, AdminStatistics, ViewLogs, and Entities table layouts toward the compact table-first visual guide.
- **Worker egress is explicit.** The async worker remains on the internal backend network and is also attached to the egress-capable proxy network for Gemini, PubMed, PubTator, and similar provider calls.

### Fixed

- **Logs first page loads faster without breaking cursor semantics.** The first-page SQL fast path preserves `page_size=all`, returns a last-page cursor, and uses stable `id` tie-breaking for non-unique sort columns.
- **LLM regeneration tracking is visible and durable across page navigation.** ManageLLM now tracks child jobs per cluster type and restores active browser-session job cards after returning to the page.
- **Character phenotype cluster IDs no longer break LLM progress messages.** Cluster progress formatting now accepts descriptive cluster labels.

## [0.16.5] — 2026-05-09

Fix bump for entity detail clipboard resiliency after PR #328 feedback.

### Fixed

- **Clinical synopsis copy is now reliable.** The copy button in the Clinical Synopsis card only shows “Copied” when clipboard access succeeds, and resets correctly on failure or when permission/secure-context constraints prevent copying.
- **Clipboard side effects are scoped cleanly.** The copy timeout is now canceled on navigation/unmount, preventing stale timers and copy-label flicker.

## [0.16.4] — 2026-05-09

Patch bump for the gene detail UI/UX density and ClinVar summary improvements in PR #327.

### Changed

- **Gene detail external evidence cards are denser and more readable.** Tightens gnomAD constraint, ClinVar, Model Organisms, and protein/gene visualization presentation while preserving the Vue 3 + TypeScript + Bootstrap Vue Next architecture.
- **Associated entities embed no longer shows the global table search row.** Adds a `showSearchInput` option to `TablesEntities` and disables it only for the gene-detail Associated table.
- **ClinVar summary is richer without loading the full variant list into the card.** The `summary=true` gnomAD ClinVar response now includes compact consequence and per-class breakdowns, and the card renders keyboard-accessible dense chips with popover breakdowns.

### Fixed

- **Gene detail contrast and spacing regressions.** Improves compact label contrast, no-data states, card density, and protein panel overflow behavior.
- **Gene page accessibility issues.** Addresses page heading semantics, decorative SVG ARIA, model-organism badge accessible names, and navbar list semantics touched by the gene detail audit.

## [0.16.2] — 2026-05-08

Patch bump for the consolidated dependency refresh in PR #321, combining Dependabot PRs #316, #317, and #312.

### Changed

- **Frontend production dependencies refreshed.** Updates `@unhead/vue`, `@vueuse/core`, `bootstrap-vue-next`, `cytoscape`, `dompurify`, `swagger-ui`, and `swagger-ui-dist`.
- **Frontend development dependencies refreshed.** Updates test/build tooling including `@vue/test-utils`, `axios`, `eslint`, `jsdom`, `msw`, `postcss`, `typescript-eslint`, `vue-tsc`, and related tooling packages.
- **API Docker base image refreshed.** Updates `rocker/r-ver` from `4.5.3` to `4.6.0` with a matching R 4.6 / Bioconductor 3.23 API lockfile refresh.
- **API CI runners aligned with R 4.6.0.** Updates R-based GitHub Actions jobs so `setup-renv` restores against the same R minor recorded in `api/renv.lock`.
- **R 4.6 restore compatibility fixed.** Updates stale API package pins that failed from source under R 4.6/GCC 13 (`lazyeval`, `rex`, `RMariaDB`, `base64enc`, and `S7`), drops the obsolete `plogr` lockfile entry, adds the host CI system libraries required by `textshaping`, and serializes the `tseries` restore before `forecast` on cold API dependency installs.

### Fixed

- **Production CSP allows bundled fonts.** Adds `font-src 'self'` so self-hosted SPA font assets are not blocked by `default-src 'none'`.
- **PubMed parser keeps articles with one-part first-author names.** `table_articles_from_xml()` now treats a missing first-author `ForeName` as an empty string instead of collapsing the parsed PMID row.

## [0.16.1] — 2026-05-08

Patch bump for the atomic entity rename and PubMed validation fix in PR #319.

### Fixed

- **Entity rename is atomic.** `POST /api/entity/rename` now delegates to `svc_entity_rename_full`, carrying source approval/status state to the replacement entity and rolling back all rename writes on failure.
- **Unresolvable PMIDs fail before partial writes.** PubMed misses now raise `publication_fetch_error`, list the offending `PMID:` values, and return HTTP 400 at entity/review endpoints instead of creating partial publication/entity state.
- **Curator error toasts show API messages.** Entity mutation failures now surface structured API error text instead of object-shaped toast content.
- **Rename edge cases are guarded.** Malformed rename payloads, missing active source status, and stale source deactivation are rejected before or inside the transaction.

## [0.11.14] — 2026-04-24

Patch bump for the durable async job hard cut in PR #305. This replaces process-local async job ownership with a MySQL-backed durable queue/state model, a dedicated worker service, and CI smoke/bootstrap fixes required to verify the new architecture on pristine environments.

### Fixed

- **Pristine DB smoke startup no longer fails before foundational schema exists.** Added a bootstrap migration so a fresh MySQL instance creates the base tables needed by later migrations before content and durable async schema migrations run.
- **Production-style smoke verification now matches real stack readiness.** The smoke script retries SPA readiness before asserting security headers, and local prod-stack compose starts rebuild fresh images so stale dev-built images do not produce false failures.
- **Durable async job status reporting preserves terminal semantics.** Cancelled jobs now report as `cancelled` instead of generic execution failures, and worker progress/lease updates are persisted so long-running jobs do not look stale while still executing.

### Changed

- **Async jobs are now durable and worker-owned.** Canonical async state lives in MySQL, the worker service claims and executes jobs independently of the API process, and frontend polling no longer depends on sticky-session correctness.
- **Worker deployment model is explicit.** Operator docs now describe the separate worker service, durable queue semantics, and worker-health expectations rather than the old API-process `mirai` ownership model.

## [0.11.13] — 2026-04-23

Patch bump for the auth query-string hard cut in PR #304, plus a follow-up CI fast-path refactor so normal review cycles no longer wait on the full API suite and environment bootstrap checks.

### Fixed

- **Auth-sensitive inputs are hard-cut to body-only transport.** `POST /api/auth/signup`, `POST /api/auth/authenticate`, and password-update flows no longer accept query-string payloads. Runtime request logging keeps auth-sensitive query strings redacted, and the DB cleanup migration scrubs persisted historical values.
- **Auth endpoint validation now fails closed on malformed JSON bodies.** Signup and password-update handlers reject nested or non-scalar required fields with `400` before downstream coercion or tibble/pivot work.
- **Auth review regressions are locked in.** E2E auth lifecycle tests now target the mounted `/api/auth/*` routes, and endpoint-auth tests assert unique source decorators before slicing source windows.

### Changed

- **PR CI now has a fast API gate.** Pull requests run `Test R API (fast PR gate)` against a repo-owned file selection, while non-PR CI keeps the full API suite. This preserves full confidence coverage off the PR critical path.
- **Tooling-heavy PR checks are conditional.** `make doctor` and `Smoke Test (prod stack)` only stay in the PR path when workflow, tooling, or boot-path files change; they still run outside PRs.
- **Local fast-loop mirrors PR CI.** `make test-api-fast` now exists as the local equivalent of the PR-fast API gate, and `make pre-commit` uses it. `make ci-local` remains the full local parity gate.

## [0.11.12] — 2026-04-22

Patch bump for the consolidated dependency + security sweep in #298 (subsumes #288, #289, #291, #292, #293, #295, #297). Also lands two CI stability guardrails introduced during review.

### Fixed

- **Master CI break — `@testing-library/dom` peer-dep drift.** Vitest suites were failing with `Cannot find package '@testing-library/dom'` because `npm ci --legacy-peer-deps --prefer-offline` stopped hoisting it under `@testing-library/user-event`. Pinned as an explicit `devDependency` so the package is guaranteed at the root of `node_modules`. Seventeen previously failing test files now pass.
- **nginx: security headers silently dropped.** Headers declared at `http{}` level were being discarded by every `location{}` block because those blocks define their own `add_header Cache-Control` (nginx inheritance rule: a child `add_header` erases the parent's). Moved the full OWASP / UniBE header set into `app/docker/nginx/security-headers.conf` and `include` it inside every location — closes #296.
- **nginx: server version leak.** Added `server_tokens off` so the `Server:` header no longer advertises the exact nginx build.
- **API crashloop — `mirai 2.5.3` / `nanonext 1.8.2` mismatch.** PPM pruned `nanonext 1.7.2`, `mirai`'s `Imports: nanonext (>= 1.7.2)` floor was satisfied by the 1.8.2 release which no longer exports `.read_header`, and `renv::restore` silently upgraded on rebuild. Date-pinned the PPM snapshot URL (`/cran/2026-04-22`) in both `api/Dockerfile` and `api/renv.lock`, and bumped to `mirai 2.6.1` + `nanonext 1.8.2`. Closes #294.

### Changed

- **Dependency bumps (prod):** `@unhead/vue 3.0.3→3.0.4`, `bootstrap-vue-next 0.44.2→0.44.6`, `dompurify 3.3.2→3.4.0` (mXSS + prototype-pollution fixes), `swagger-ui` / `swagger-ui-dist 5.32.0→5.32.4`.
- **Dependency bumps (dev):** `axios 1.13.6→1.15.1` (header-injection + CRLF hardening), `eslint 10.0.2→10.2.1`, `msw 2.12.10→2.13.4`, `postcss 8.5.8→8.5.10`, `prettier 3.8.2→3.8.3`, `typescript 6.0.2→6.0.3`, `typescript-eslint 8.58.2→8.59.0`, `vue-tsc 3.2.5→3.2.7`.
- **Docker image bumps:** `mysql 8.4.8→8.4.9` (prod + both dev DBs), `axllent/mailpit v1.29.6→v1.29.7`, `fholzer/nginx-brotli v1.29.8→v1.30.0`.
- **HSTS policy.** Rewrote the header set. `Strict-Transport-Security` now ships `max-age=63072000; includeSubDomains; preload` (2 years). **Preload submission is deliberately deferred** — see #300 before adding the domain to the browser preload list. Dropped legacy `X-XSS-Protection`, `X-Download-Options`, `X-Permitted-Cross-Domain-Policies`, and the duplicate `X-Content-Security-Policy` header (all obsolete per modern browser guidance).

### Added

- **CI smoke-test asserts SPA security headers.** `scripts/ci-smoke.sh` step 4 curls the running prod stack and grep-asserts presence of `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, `Content-Security-Policy`, plus absence of a `Server: nginx/<version>` leak. Guards against a future `location{}` block forgetting the `include` or a `server_tokens` regression.
- **Dependabot: group container-image bumps.** Weekly runs now open at most one Dockerfile PR and one compose PR (matching the existing `actions` group pattern) instead of one PR per image.
- **Dependabot: ignore Vite semver-major.** Vite 8 has real breaking changes (`manualChunks` type moved from object to function, `vitest.config.ts` factory API changed). Dropped here; reopen when we schedule a migration. Closes #290 (the standing dependabot PR).

### Follow-ups (opened, not in this release)

- #299 — CSP tightening (drop `'unsafe-inline'` / `'unsafe-eval'`); needs Report-Only probe + swagger-ui audit.
- #300 — HSTS preload-submission decision (one-way door, needs UniBE ICT sign-off).

## [0.11.8] — 2026-04-12

Closes Phase D of the v11.0 test foundation initiative by landing D6 (`extract-bootstrap`), plus a reinforcing Phase B worktree that closes six MSW handler-table gaps Phase C batch review identified. **No new runtime behavior**; D6 is a pure structural refactor of the startup path and reinforcing-B adds test-only MSW stubs.

### Changed

- **D6 — Extract `api/start_sysndd_api.R` into `api/bootstrap/` module set.** Rewrote the 992-LoC startup script with 21 `<<-` super-assignments into a 137-LoC thin composer over 8 bootstrap modules. Every `<<-` is eliminated — `bootstrap_*()` functions return their results and the composer binds them at the top level of `start_sysndd_api.R` (which IS `.GlobalEnv`), so endpoint handlers, filters, and middleware that still look up `pool` / `serializers` / `migration_status` / `root` / etc. as globals keep working unchanged.
  - `api/bootstrap/init_libraries.R` (76 LoC) — `library()` attachment order (STRINGdb/biomaRt first so `dplyr`'s masks win).
  - `api/bootstrap/load_modules.R` (144 LoC) — sources repositories → services → core → filters in the order the Phase C source-order test expects.
  - `api/bootstrap/create_pool.R` (50 LoC) — builds the DBI pool, returns it.
  - `api/bootstrap/run_migrations.R` (159 LoC) — runs pending migrations, returns status list.
  - `api/bootstrap/init_globals.R` (63 LoC) — serializers, inheritance/output/user allow-lists, `version_json` / `sysndd_api_version`.
  - `api/bootstrap/init_cache.R` (103 LoC) — disk-backed `memoise` cache + 9 memoised helpers.
  - `api/bootstrap/setup_workers.R` (132 LoC) — mirai daemon pool + `everywhere({...})` worker-side source block (unchanged function set and order, verified against the pre-D6 block).
  - `api/bootstrap/mount_endpoints.R` (191 LoC) — all `pr_mount()` calls + filter wiring, returns the root router.
  - `api/core/filters.R` (294 LoC, new) — extracted Plumber filter definitions (cors, auth, logging, error handler) from `start_sysndd_api.R`.
  - `api/Dockerfile` — added `COPY services/` (pre-existing gap — container was relying on bind-mount alone, which would break production builds) and `COPY bootstrap/` lines so the built image includes the new module directory.
  - `docker-compose.yml` — added `./api/bootstrap:/app/bootstrap` bind-mount and a matching `docker compose watch` sync target.

### Added

- **Reinforcing Phase B — 13 new MSW handlers covering six B1 gaps Phase C specs worked around via per-test `installAuxHandlers` stubs.** These are test-infrastructure-only changes; Phase E rewriting agents can now rely on shared mocks instead of duplicating per-spec stubs.
  - Gap 1: `GET /api/entity?filter=...` (Review.vue step 1).
  - Gap 2-4: `GET /api/list/entity`, `/list/gene`, `/list/disease` (dropdown stubs — these routes are Phase E contracts that `list_endpoints.R` doesn't implement yet; handler shapes follow the `{id, label}` tree-mode convention).
  - Gap 5: `GET /api/re_review/table` (cursor envelope mirroring `re_review_endpoints.R @get table`).
  - Gap 6: `ManageAnnotations.vue` aux endpoints — `GET /api/admin/annotation_dates`, `/admin/deprecated_entities` (with Viewer 403 branch); `PUT /api/admin/update_ontology_async` (Viewer 403 branch), `/admin/force_apply_ontology` (400 when `blocked_job_id` missing); `POST /api/admin/publications/refresh` (400 when body missing); `GET /api/publication/stats`, `/publication`, `/publication/pubtator/genes`, `/publication/pubtator/table`, `/comparisons/metadata`.
  - New fixture files under `app/src/test-utils/mocks/data/`: `lists.ts`, `re_review.ts`, `annotations.ts`.
  - No existing B1 handlers modified; 33 test files still pass (439 passed + 6 todo).

### Verified

- `wc -l api/start_sysndd_api.R` → **137** (plan target ≤200).
- `grep -c "<<-" api/start_sysndd_api.R` → **0**.
- `grep -rn "<<-" api/start_sysndd_api.R api/bootstrap/` → **0 hits**.
- `Rscript --no-init-file api/scripts/lint-check.R` → 90 files, 0 issues.
- Full backend test suite inside the api container: **70 files, 0 failures, 2338 passed, 247 skipped** (the skips are the documented DB-gated / slow tests).
- `docker compose restart api` → boots in 3 attempts, zero "could not find function" or fatal-error entries in startup logs.
- Critical endpoints all return 200: `/api/health/ready`, `/api/version/`, `/api/llm/prompts` (D1-regression guard), `/api/backup/list?page=1` (D5-shape guard), `/api/search/CUL1?helper=true`.
- CI on PR #256 (D6): `Detect Changes`, `make doctor`, `Smoke Test (prod stack)`, `Lint R API`, `Test R API` all SUCCESS; frontend jobs correctly skipped (no frontend changes).

### Phase D gate (§8) — all green

- Local and remote `v11.0/phase-d/*` branches: **0**.
- Legacy wrapper file (`api/functions/legacy-wrappers.R`): **deleted**.
- All D1/D2/D3 split-file size targets met; the two documented overruns (`response-helpers.R` 762 LoC, `llm-service.R` orchestrator 724 LoC) remain because splitting further would fragment cohesive logic.

## [0.11.7] — 2026-04-12

Phase D of the v11.0 test foundation initiative — backend structural refactors protected by the Phase C test net. Five parallel worktree units (D1–D5) consolidated here; D6 (`extract-bootstrap`) follows in a subsequent PR. **No new runtime behavior**; this is exclusively source-structure refactoring protected by pre-existing Phase C tests.

### Changed

- **D1 — Split `api/functions/llm-service.R` (1,748 LoC) into focused modules.**
  - `llm-client.R` (318 LoC) — Gemini HTTP/SDK calls: `get_default_gemini_model()`, `generate_cluster_summary()`, `is_gemini_configured()`, `list_gemini_models()`.
  - `llm-types.R` (572 LoC) — ellmer `type_object` specs + prompt builders.
  - `llm-rate-limiter.R` (184 LoC) — `GEMINI_RATE_LIMIT` config + `calculate_derived_confidence()`.
  - `llm-service.R` (726 LoC orchestrator) — `get_or_generate_summary()`, cluster data fetchers, prompt template CRUD.
  - Conditional source guards let the orchestrator load its dependencies when sourced standalone (e.g., from `test-llm-batch.R`). `get_api_dir()` fallback handles testthat's working-directory switches.
- **D2 — Split `api/functions/helper-functions.R` (1,440 LoC) into 4 focused modules.**
  - `account-helpers.R` (194 LoC) — `random_password`, `is_valid_email`, `generate_initials`, `send_noreply_email`.
  - `entity-helpers.R` (222 LoC) — `nest_gene_tibble`, `nest_pubtator_gene_tibble`, `extract_vario_filter`, `get_entity_ids_by_vario`.
  - `response-helpers.R` (766 LoC) — `generate_sort_expressions`, `generate_filter_expressions`, `select_tibble_fields`, `generate_cursor_pag_inf`, `generate_tibble_fspec`. Exceeds the 500 LoC target because `generate_filter_expressions()` alone is ~340 LoC; splitting it would fragment cohesive dispatch-table logic.
  - `data-helpers.R` (291 LoC) — `generate_panel_hash`, `generate_json_hash`, `generate_function_hash`, `generate_xlsx_bin`, `post_db_hash`.
  - `helper-functions.R` retained as a 14-line compatibility shim — pre-existing tests source it directly; shim conditionally loads the 4 split modules.
- **D3 — Split `api/functions/pubtator-functions.R` (1,269 LoC) into 3 focused modules.**
  - `pubtator-client.R` (351 LoC) — BioCJSON API calls + rate limiting (`pubtator_rate_limited_call`, `pubtator_v3_*`).
  - `pubtator-parser.R` (380 LoC) — JSON parsing + 3-approach gene-symbol computation (`pubtator_parse_biocjson`, `compute_pubtator_gene_symbols`, flatteners, `generate_query_hash`).
  - `pubtator-functions.R` (548 LoC orchestrator) — `pubtator_db_update()` (sync) + `pubtator_db_update_async()` (mirai workers).
- **D4 — Deleted `api/functions/legacy-wrappers.R` (630 LoC).** All 10 wrapper functions migrated to their natural service layer homes with their original names preserved (endpoint handlers and Phase C test sandboxes reference them by name):
  - `put_post_db_review`, `put_post_db_pub_con`, `put_post_db_phen_con`, `put_post_db_var_ont_con` → `api/services/review-service.R`.
  - `put_post_db_status` → `api/services/status-service.R`.
  - `post_db_entity`, `put_db_entity_deactivation` → `api/services/entity-service.R`.
## -------------------------------------------------------------------##
# api/bootstrap/load_modules.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Loads every R source file required by the running API into the
# global environment, in the correct order:
#   1. functions/* (repositories, helpers, clients, etc.)
#   2. core/* (security, errors, responses, middleware, filters)
#   3. services/* (transactional orchestration)
#
# Source order matters. Repository functions are loaded BEFORE
# services so that any `svc_`/`service_`-prefixed function in
# services/* can still call the underlying repository helpers.
# (A service that accidentally drops its prefix will shadow the
# repository function — see CLAUDE.md.)
#
# Mirai daemon workers do NOT use this module. They re-source a
# hand-picked subset of functions/* via `everywhere({...})` in
# api/bootstrap/setup_workers.R. Changes here do not automatically
# propagate to workers — update setup_workers.R as well when a
# function file is needed inside a daemon.
## -------------------------------------------------------------------##

#' Source a file into .GlobalEnv with a helpful error if missing.
#'
#' `source(..., local = FALSE)` puts the bindings into the global
#' environment — that is what endpoint files expect at runtime.
#' Top-level `source("...", local = TRUE)` in start_sysndd_api.R
#' previously had the same effect by accident of being at the top
#' level of the script; here we make the intent explicit.
#'
#' @param path Relative path from api/ to the source file.
#' @noRd
.bootstrap_source <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("bootstrap: source file not found: %s", path))
  }
  source(path, local = FALSE)
  invisible(NULL)
}

#' Load the full API source tree into the global environment.
#'
#' This is the explicit, auditable source list that used to live
#' inline in start_sysndd_api.R between the markers
#' `# --- function source list (v11.0) ---` and
#' `# --- end source list ---`.
#'
#' @return A list describing which file groups were loaded (used
#'   for logging / diagnostics). The side effect is that every
#'   listed file is sourced into .GlobalEnv.
#' @export
bootstrap_load_modules <- function() {

  # --- function source list (v11.0) ---
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
    # Category-selected clustering gene-universe resolver (#574). Depends on
    # generate_ndd_hgnc_ids() (analyses-functions.R, above) and
    # stop_for_bad_request() (core/errors.R, sourced after function_files by
    # this same bootstrap_load_modules() call) -- registered before the
    # submission service that will consume it.
    "functions/clustering-gene-universe.R",
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
    "services/entity-service.R",
    "services/entity-creation-service.R",
    "services/entity-rename-service.R",
    "services/review-service.R",
    "services/genereviews-service.R",
    "services/approval-service.R",
    "services/re-review-selection-service.R",
    "services/re-review-service.R",
    "services/re-review-refusal-service.R",
    "services/seo-service.R",
    "services/analysis-snapshot-service.R",
    "services/analysis-snapshot-refresh-service.R",
    "services/analysis-snapshot-release-service.R",
    "services/disease-ontology-mapping-service.R",
    "services/mcp-service.R",
    "services/mcp-analysis-shaping.R",
    "services/mcp-query-service.R",
    "services/mcp-record-service.R",
    "services/mcp-analysis-service.R",
    "services/mcp-analysis-llm-cache-service.R",
    "services/mcp-research-context-service.R",
    "services/mcp-capabilities-service.R",
    "services/mcp-tool-core.R",
    "services/mcp-tool-resources.R",
    "services/mcp-tools.R",
    "services/mcp-tool-analysis-registry.R",
    "services/mcp-tool-registry.R",
    # --- #346 Wave 3: endpoint-delegation services (svc_-prefixed). These are
    # sourced by the API and the durable worker via this shared loader, but are
    # never registered as job handlers or called by worker execution. They only
    # depend on functions/* and the domain services above, so they are appended
    # last (definition order is irrelevant; none call each other at source time).
    "services/publication-query-endpoint-service.R",
    "services/publication-admin-endpoint-service.R",
    "services/user-read-endpoint-service.R",
    "services/user-account-endpoint-service.R",
    "services/user-password-profile-endpoint-service.R",
    "services/user-bulk-endpoint-service.R",
    "services/admin-ontology-endpoint-service.R",
    "services/admin-diagnostics-endpoint-service.R",
    "services/admin-nddscore-endpoint-service.R",
    "services/admin-publication-refresh-endpoint-service.R",
    "services/job-functional-submission-service.R",
    "services/job-phenotype-submission-service.R",
    "services/job-maintenance-submission-service.R",
    "services/job-query-endpoint-service.R",
    "services/re-review-query-endpoint-service.R",
    "services/re-review-workflow-endpoint-service.R",
    "services/entity-read-endpoint-service.R",
    "services/entity-submission-endpoint-service.R",
    "services/statistics-public-endpoint-service.R",
    "services/statistics-admin-endpoint-service.R",
    "services/llm-admin-endpoint-service.R",
    "services/backup-endpoint-service.R"
  )

  for (path in function_files) .bootstrap_source(path)
  for (path in core_files) .bootstrap_source(path)
  for (path in service_files) .bootstrap_source(path)

  list(
    functions = length(function_files),
    core = length(core_files),
    services = length(service_files)
  )
}
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
#* Submits an async job to compute functional clustering via STRING-db. The
#* clustering gene universe (#574) is resolved from one of three mutually
#* exclusive JSON body selectors:
#*   - `genes`: an explicit array of HGNC ids to cluster.
#*   - `category_filter`: an array of curated SysNDD confidence categories
#*     (e.g. `["Definitive"]`); resolved entity-level (>=1 NDD entity in a
#*     selected category, `ndd_phenotype = 1`) against the live
#*     `ndd_entity_view`, validated against the live active
#*     `ndd_entity_status_categories_list`. A category run rejects with 400
#*     when `category_filter` is empty, contains an unknown/inactive value
#*     (the allowed active set is named in the error), or resolves fewer
#*     than 2 genes.
#*   - neither: the existing default all-NDD-genes universe.
#* Supplying both `genes` and a non-empty `category_filter` is a 400.
#*
#* Every submit records selector/fingerprint provenance -- `selector`
#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
#* category runs), `resolved_gene_count`, `gene_list_sha256`,
#* `intended_fingerprint`, and `source_data_version` -- in the durable job
#* payload; the job result `meta` additionally carries `effective_fingerprint`
#* (the STRING `weight_channel` actually observed on the computed result),
#* recorded on both a cache-hit (immediate) response and a worker-run
#* (cache-miss) job.
#*
#* Results from this endpoint (including category-filtered runs) are never
#* `public_ready` -- they are ephemeral job results, distinct from the public
#* `analysis_snapshot_*` layer.
#*
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @param genes Optional JSON array of explicit HGNC ids. Mutually exclusive
#*   with `category_filter`.
#* @param category_filter Optional JSON array of curated SysNDD confidence
#*   categories (e.g. `["Definitive"]`). Mutually exclusive with `genes`.
#* @param algorithm Optional clustering algorithm string, `"leiden"`
#*   (default) or `"walktrap"`.
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
## -------------------------------------------------------------------##

#* Get Job History
#*
#* Returns a list of recent jobs for admin review.
#* Requires Administrator role.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @get /history
function(req, res, limit = 20) {
  require_role(req, res, "Administrator")
  svc_job_get_history(limit)
}

## -------------------------------------------------------------------##
## Job Status Polling
## -------------------------------------------------------------------##

#* Get Job Status
#*
#* Poll job status and retrieve results when complete.
#* Returns Retry-After header for running jobs.
#*
#* @tag jobs
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @get /<job_id>/status
function(job_id, result_mode = "summary", req, res) {
  svc_job_get_status(job_id, result_mode, req, res)
}
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
# NOTE: .async_job_run_clustering assembles its result meta via
# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
# worker/API entrypoint sources that module via bootstrap_load_modules() before
# this file; a direct-source test env must source it too (as the async-job tests do).

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
  # #574 D3: the cheap-path selector/fingerprint provenance the submit
  # service (job-functional-submission-service.R) recorded in the payload.
  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
  # FALSE) so a worker-run job for those still completes normally.
  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)

  progress("cluster", "Running functional clustering...", current = 0, total = 1)

  clusters <- gen_string_clust_obj(
    genes,
    algorithm = algorithm,
    string_id_table = string_id_table
  )

  progress("complete", "Functional clustering complete", current = 1, total = 1)

  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
  # path), then the request's cheap-path `provenance` (selector/
  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
  # source_data_version) when present, then the `effective_fingerprint` --
  # only knowable now that `clusters` has actually been computed -- so a
  # silent exp+db -> combined-score STRING fallback on a worker-run job is
  # visible in the stored result too, not just a cache hit's.
  # gene_count is the DISTINCT gene count, matching the cache-hit path's
  # `resolved_count <- length(unique(genes_list))` (job-functional-submission-
  # service.R) -- for `["HGNC:1","HGNC:1"]` a raw `length(genes)` reported 2
  # here while the cache-hit path reported 1 for the identical payload
  # (Codex round-2 review fix). This never dedups the payload `genes` list
  # itself or changes `nrow(clusters)`, only the reported count.
  meta <- clustering_result_meta(
    list(
      algorithm = algorithm,
      gene_count = length(unique(genes)),
      cluster_count = nrow(clusters),
      cache_hit = FALSE
    ),
    provenance,
    attr(clusters, "weight_channel")
  )

  list(
    clusters = clusters,
    categories = .async_job_functional_categories(clusters, category_links),
    meta = meta
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
  progress("cluster", "Running phenotype clustering...", current = 1, total = 2)
  phenotype_clusters <- gen_mca_clust_obj(phenotype_matrix)
  progress("complete", "Phenotype clustering complete", current = 2, total = 2)

  identifiers <- payload$ndd_entity_view_tbl |>
    dplyr::select(entity_id, hgnc_id, symbol)

  phenotype_clusters |>
    tidyr::unnest(identifiers) |>
    dplyr::mutate(entity_id = as.integer(entity_id)) |>
    dplyr::left_join(identifiers, by = "entity_id") |>
    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
}

.async_job_run_ontology_update <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])

  progress("init", "Preparing ontology update", current = 0, total = 4)
  disease_ontology_set <- process_combine_ontology(
    hgnc_list = payload$hgnc_list,
    mode_of_inheritance_list = payload$mode_of_inheritance_list,
    max_file_age = 0,
    output_path = "data/",
    progress_callback = progress
  )
  progress("complete", "Ontology update complete", current = 4, total = 4)

  list(
    status = "completed",
    rows_processed = nrow(disease_ontology_set),
    sources = c("MONDO", "OMIM"),
    output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
  )
}

.async_job_run_passthrough <- function(fn_name) {
  force(fn_name)

  function(job, payload, state, worker_config) {
    fn <- base::get(fn_name, mode = "function")
    fn(.async_job_add_job_id(payload, job))
  }
}

async_job_handler_registry <- list(
  clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_run_clustering,
    after_success = function(result, job, payload, state, worker_config) {
      .async_job_chain_llm(result, job, cluster_type = "functional")
    }
  ),
  phenotype_clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_run_phenotype_clustering,
    after_success = function(result, job, payload, state, worker_config) {
      .async_job_chain_llm(result, job, cluster_type = "phenotype")
    }
  ),
  ontology_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_ontology_update,
    after_success = .async_job_after_success_noop
  ),
  hgnc_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_hgnc_update,
    after_success = .async_job_after_success_noop
  ),
  comparisons_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_passthrough("comparisons_update_async"),
    after_success = .async_job_after_success_noop
  ),
  pubtator_update = list(
    cancel_mode = "best_effort",
    run = .async_job_run_pubtator,
    after_success = .async_job_after_success_noop
  ),
  pubtator_enrichment_refresh = list(
    cancel_mode = "best_effort",
    run = .async_job_run_pubtator_enrichment,
    after_success = .async_job_after_success_noop
  ),
  pubtatornidd_nightly = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_pubtatornidd_nightly,
    after_success = .async_job_after_success_noop
  ),
  disease_ontology_mapping_refresh = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_disease_ontology_mapping_refresh,
    after_success = .async_job_after_success_noop
  ),
  nddscore_import = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_nddscore_import,
    after_success = .async_job_after_success_noop
  ),
  llm_generation = list(
    cancel_mode = "best_effort",
    run = .async_job_run_passthrough("llm_batch_executor"),
    after_success = .async_job_after_success_noop
  ),
  network_layout_prewarm = list(
    cancel_mode = "best_effort",
    run = function(...) .async_job_run_network_layout_prewarm(...),
    after_success = .async_job_after_success_noop
  ),
  analysis_snapshot_refresh = list(
    cancel_mode = "best_effort",
    run = function(...) .async_job_run_analysis_snapshot_refresh(...),
    after_success = .async_job_after_success_noop
  ),
  backup_create = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_backup_create,
    after_success = .async_job_after_success_noop
  ),
  backup_restore = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_backup_restore,
    after_success = .async_job_after_success_noop
  ),
  omim_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_omim_update,
    after_success = .async_job_after_success_noop
  ),
  force_apply_ontology = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_force_apply_ontology,
    after_success = .async_job_after_success_noop
  ),
  publication_refresh = list(
    cancel_mode = "best_effort",
    run = .async_job_run_publication_refresh,
    after_success = .async_job_after_success_noop
  ),
  publication_date_backfill = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_publication_date_backfill,
    after_success = .async_job_after_success_noop
  )
)

#' Resolve a durable async job handler definition
#' @param job_type Character async job type.
#' @param registry Named handler registry.
#'
#' @return Registry entry with run/cancel metadata.
#' @export
async_job_get_handler <- function(job_type, registry = async_job_handler_registry) {
  entry <- registry[[job_type]]

  if (is.null(entry)) {
    stop(sprintf("No durable async job handler registered for '%s'", job_type), call. = FALSE)
  }

  if (!is.function(entry$run)) {
    stop(sprintf("Handler registry entry for '%s' is missing a callable run function", job_type), call. = FALSE)
  }

  if (is.null(entry$after_success)) {
    entry$after_success <- .async_job_after_success_noop
  }

  entry
}
# ---------------------------------------------------------------------------
# Queue-depth capacity cap
# ---------------------------------------------------------------------------

# Max simultaneously queued+running jobs allowed on the public submit queue.
# Read once at source/startup time; changing the env var requires an API
# restart to take effect. An INVALID value (e.g. "abc") must not parse to NA:
# `async_job_capacity_exceeded()` isTRUE-wraps its comparison, so an NA cap would
# silently disable this DB-backed backstop entirely. Floor at 1, default 8.
ASYNC_PUBLIC_JOB_CAP <- local({
  raw <- trimws(Sys.getenv("ASYNC_PUBLIC_JOB_CAP", "8"))
  value <- suppressWarnings(as.integer(raw))
  if (is.na(value) || value < 1L) 8L else value
})

#' TRUE when the active (queued+running) job count is at or over the cap.
#'
#' Soft cap: the check-then-submit sequence in the endpoints is not atomic, so
#' two concurrent requests may both pass and transiently push the queue one or
#' two over the cap. That is acceptable for a back-pressure guard.
#'
#' @param active_count Integer count of currently in-flight jobs.
#' @param cap Integer maximum allowed. Defaults to ASYNC_PUBLIC_JOB_CAP.
#' @return Logical.
#' @export
async_job_capacity_exceeded <- function(active_count, cap = ASYNC_PUBLIC_JOB_CAP) {
  cap <- suppressWarnings(as.integer(cap))
  if (length(cap) != 1L || is.na(cap) || cap < 1L) {
    cap <- 8L # never let an invalid cap silently disable the backstop
  }
  isTRUE(as.integer(active_count) >= cap)
}

#' Count queued+running jobs for a given queue.
#'
#' @param queue_name Character queue name to inspect.
#' @param conn Optional DB connection or pool. NULL uses global pool.
#' @return Integer count of active (queued / running / cancel_requested) jobs.
#' @export
async_job_active_count <- function(queue_name = "default", conn = NULL) {
  sql <- paste(
    "SELECT COUNT(*) AS n FROM async_jobs",
    "WHERE queue_name = ? AND status IN ('queued', 'running', 'cancel_requested')"
  )
  row <- db_execute_query(sql, params = list(queue_name), conn = conn)
  if (nrow(row) == 0) 0L else as.integer(row$n[[1]])
}

# ---------------------------------------------------------------------------
# Queue routing + priority by job type (#486)
#
# One serial worker draining one shared "default" queue lets a long-running,
# non-interruptible maintenance job (e.g. publication_date_backfill) head-of-line
# block latency-sensitive interactive jobs (clustering / phenotype_clustering /
# llm_generation and the snapshot -> LLM deploy chain). These helpers are the
# single source of truth for which lane and priority a job type defaults to; the
# `worker-maintenance` container drains the "maintenance" lane so heavy jobs run
# in parallel with the interactive worker instead of blocking it.
# ---------------------------------------------------------------------------

# Heavy / bulk / external maintenance job types, routed to the "maintenance" lane.
ASYNC_MAINTENANCE_JOB_TYPES <- c(
  "publication_date_backfill",
  "publication_refresh",
  "pubtator_update",
  "pubtator_enrichment_refresh",
  "pubtatornidd_nightly",
  "omim_update",
  "hgnc_update",
  "comparisons_update",
  "ontology_update",
  "force_apply_ontology",
  "disease_ontology_mapping_refresh",
  "nddscore_import",
  "backup_create",
  "backup_restore"
)

# Latency-sensitive / user-visible interactive job types. They stay on the
# "default" lane but get the LOWEST priority number so a worker claims them ahead
# of any maintenance job that happens to share the queue.
ASYNC_INTERACTIVE_JOB_TYPES <- c(
  "clustering",
  "phenotype_clustering",
  "llm_generation",
  "analysis_snapshot_refresh",
  "network_layout_prewarm"
)

# Priority tiers (lower number = claimed first; the claim query orders
# `priority ASC`). interactive < maintenance < everything-else default.
ASYNC_PRIORITY_INTERACTIVE <- 10L
ASYNC_PRIORITY_MAINTENANCE <- 50L
ASYNC_PRIORITY_DEFAULT <- 100L

#' Resolve the durable queue lane for a job type.
#'
#' @param job_type Character durable job type.
#' @return "maintenance" for heavy/bulk/external maintenance job types, else
#'   "default".
#' @export
async_job_queue_for_type <- function(job_type) {
  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
  if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) "maintenance" else "default"
}

#' Resolve the default claim priority for a job type.
#'
#' @param job_type Character durable job type.
#' @return Integer priority: interactive (10) < maintenance (50) < default (100).
#' @export
async_job_priority_for_type <- function(job_type) {
  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
  if (jt %in% ASYNC_INTERACTIVE_JOB_TYPES) {
    ASYNC_PRIORITY_INTERACTIVE
  } else if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) {
    ASYNC_PRIORITY_MAINTENANCE
  } else {
    ASYNC_PRIORITY_DEFAULT
  }
}

# ---------------------------------------------------------------------------

.async_job_service_scalar <- function(value, default = NULL) {
  if (is.null(value) || length(value) == 0) {
    return(default)
  }

  if (is.list(value)) {
    return(value[[1]])
  }

  value[[1]]
}

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
#' @param hash_payload Optional named list or JSON payload string. When
#'   supplied, the dedup `request_hash` is computed over THIS payload instead
#'   of `request_payload`, while `request_payload_json` (the durably stored
#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
#'   `request_payload` exactly as before, so existing callers are unaffected.
#'   Used by clustering submits (#574) to exclude time-varying `provenance`
#'   metadata from the dedup identity while still persisting it.
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
  conn = NULL,
  hash_payload = NULL
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
  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
  request_hash <- async_job_service_request_hash(job_type, hash_payload_json)
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
#' @param hash_payload Optional named list or JSON payload string. When
#'   supplied, the dedup `request_hash` is computed over THIS payload instead
#'   of `request_payload`, while `request_payload_json` (the durably stored
#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
#'   `request_payload` exactly as before, so existing callers are unaffected.
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
  conn = NULL,
  hash_payload = NULL
) {
  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
  payload_json <- async_job_service_payload_json(request_payload)
  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
  result_json <- async_job_service_payload_json(result)

  async_job_repository_create(
    list(
      job_id = job_id,
      job_type = job_type,
      queue_name = queue_name,
      priority = as.integer(priority),
      status = "completed",
      request_hash = async_job_service_request_hash(job_type, hash_payload_json),
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

  async_job_repository_cancel(
    job_id = job_id,
    cancelled_by = if (is.null(cancelled_by)) NULL else as.integer(cancelled_by),
    conn = conn
  )

  async_job_repository_get(job_id, conn = conn)
}

#' Legacy duplicate response wrapper for endpoints not migrated yet
#'
#' @inheritParams async_job_service_find_duplicate
#'
#' @return List shaped like the previous duplicate helper.
#' @export
async_job_service_duplicate <- function(job_type, request_payload, conn = NULL) {
  duplicate <- async_job_service_find_duplicate(
    job_type = job_type,
    request_payload = request_payload,
    conn = conn
  )

  if (nrow(duplicate) == 0) {
    return(list(duplicate = FALSE))
  }

  list(
    duplicate = TRUE,
    existing_job_id = duplicate$job_id[[1]]
  )
}

#' Find an active job of a given type (job-type single-flight).
#'
#' @param job_type Character job type.
#' @param conn Optional DB connection or pool.
#' @return Tibble with zero or one active duplicate row of that job_type.
#' @export
async_job_service_find_active_by_type <- function(job_type, conn = NULL) {
  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
  async_job_repository_find_active_by_type(job_type = job_type, conn = conn)
}

#' Job-type single-flight duplicate check (#535 S2b HIGH-4).
#'
#' Unlike `async_job_service_duplicate()` (which keys on the payload hash and so
#' cannot dedupe across a payload-schema change), this dedupes on job_type alone,
#' so a destructive full-table-replace maintenance job (hgnc/comparisons/omim/
#' force_apply) resubmitted while one is in flight gets a clean 409 even across
#' the deploy that drops db_config from its payload.
#'
#' NOTE (scope): this is a **best-effort, submit-time** guard — the check and the
#' subsequent insert are NOT atomic, so a rare concurrent double-submit can still
#' enqueue two jobs. That is acceptable because the durable **maintenance lane
#' runs on a single worker** (`async_job_worker_main` claims+runs jobs
#' sequentially; Compose runs one `worker-maintenance` container), so two
#' destructive jobs never execute concurrently regardless of dedup. A hard,
#' atomic **cross-type conflict-group mutex** (e.g. an advisory lock covering
#' check+insert, or a generated conflict-key unique index grouping
#' omim_update/force_apply_ontology and pubtator_enrichment_refresh/
#' pubtatornidd_nightly) is defense-in-depth needed only if the maintenance lane
#' is ever scaled beyond one worker — tracked as a follow-up, not part of this
#' credential fix.
#'
#' @param job_type Character job type.
#' @param conn Optional DB connection or pool.
#' @return list(duplicate = FALSE) or list(duplicate = TRUE, existing_job_id = ...).
#' @export
async_job_service_duplicate_by_type <- function(job_type, conn = NULL) {
  active <- async_job_service_find_active_by_type(job_type, conn = conn)
  if (nrow(active) == 0) {
    return(list(duplicate = FALSE))
  }
  list(duplicate = TRUE, existing_job_id = active$job_id[[1]])
}

#' Legacy cancellation wrapper for endpoints not migrated yet
#'
#' @inheritParams async_job_service_cancel
#'
#' @return List describing cancellation outcome.
#' @export
async_job_service_request_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
  cancelled <- async_job_service_cancel(
    job_id = job_id,
    cancelled_by = cancelled_by,
    conn = conn
  )

  if (nrow(cancelled) == 0) {
    return(list(
      error = "JOB_NOT_FOUND",
      message = "Job ID not found"
    ))
  }

  list(job_id = job_id, status = cancelled$status[[1]])
}
# api/functions/clustering-gene-universe.R
#
# Category-selected clustering gene-universe resolver (#574 D1).
#
# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
# universe from curated SysNDD confidence categories instead of the default
# "all NDD genes" set. This file builds ONLY the resolver + provenance
# helpers; the submit service and durable handler wiring is done later.
#
# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
# same gene also has OTHER-category entities. This mirrors
# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
# added `category %in% selector` filter -- it deliberately does NOT use
# `select_network_gene_category()`, which is a gene-level display-label
# aggregator for node coloring, not a universe filter.
#
# Category validation is live against `ndd_entity_status_categories_list
# WHERE is_active = 1` -- no hardcoded category strings, and no category
# string is interpolated into SQL (dbplyr `%in%` + an allowlist pre-check).

# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
# selector returns character(0), which the resolver rejects with 400 -- it must
# never fall through to the all-NDD default.
clustering_normalize_category_filter <- function(category_filter) {
  if (is.null(category_filter)) return(NULL)
  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
  vals <- vals[nzchar(vals)]
  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
  sort(unique(vals))
}

clustering_gene_list_sha256 <- function(hgnc_ids) {
  digest::digest(
    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
    algo = "sha256", serialize = FALSE
  )
}

clustering_resolve_category_universe <- function(category_filter, conn = pool) {
  selector <- clustering_normalize_category_filter(category_filter)

  if (is.null(selector)) {
    # Absent -> preserve the exact current default ordering for cache parity.
    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
  }
  if (length(selector) == 0L) {
    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
  }

  active <- conn %>%
    dplyr::tbl("ndd_entity_status_categories_list") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::select(category) %>%
    dplyr::collect() %>%
    dplyr::pull(category)
  unknown <- setdiff(selector, active)
  if (length(unknown) > 0L) {
    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
    stop_for_bad_request(sprintf(
      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
    ))
  }

  hgnc_ids <- conn %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::arrange(entity_id) %>%
    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
    dplyr::select(hgnc_id) %>%
    dplyr::collect() %>%
    unique() %>%
    dplyr::pull(hgnc_id)

  if (length(hgnc_ids) < 2L) {
    stop_for_bad_request(sprintf(
      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
      paste(selector, collapse = ","), length(hgnc_ids)
    ))
  }
  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
}

# Module-level (survives across requests within the same process) cache for
# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
# public tables and changes rarely (only when the snapshot builder's source
# view moves), so a short-TTL process cache avoids paying that cost on every
# clustering submit while still self-refreshing.
.clustering_source_data_version_cache <- new.env(parent = emptyenv())

#' Predicate: is `v` a valid source-data-version value?
#'
#' The fail-closed contract requires a single non-NA, non-empty character
#' scalar. Anything else (`NULL`, `NA_character_`, `""`, a non-character
#' value, or a non-scalar) must never be cached or served as provenance
#' (Codex review fix -- the TTL cache previously cached/returned an invalid
#' underlying value verbatim).
.clustering_valid_source_version <- function(v) {
  is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
}

#' Cached, fail-closed read of the current analysis source-data version.
#'
#' D2 (#574) provenance helper: the clustering submit service calls this
#' AFTER admission/dedup, only when it is actually about to build a durable
#' payload. Refetches once `ttl_seconds` has elapsed since the last
#' successful read. Deliberately does NOT wrap
#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
#' PROPAGATES to the caller (never cached, never coerced to NA), so a
#' transient DB problem fails the submit closed (503) instead of recording
#' broken provenance. The fetched value is additionally validated by
#' `.clustering_valid_source_version()`: an invalid value (NA/empty/
#' non-scalar) is likewise NEVER cached or returned -- it `stop()`s instead,
#' so the caller's `tryCatch` maps it to the same 503 PROVENANCE_UNAVAILABLE
#' path as a hard fetch error.
#'
#' @param conn DB connection/pool. Defaults to the package-global `pool`.
#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
#' @return character(1) source data version.
#' @export
clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
  now <- Sys.time()
  cached_at <- .clustering_source_data_version_cache$cached_at
  cached_value <- .clustering_source_data_version_cache$value
  if (!is.null(cached_at) && .clustering_valid_source_version(cached_value) &&
        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
    return(cached_value)
  }

  value <- analysis_snapshot_source_data_version(conn = conn)

  if (!.clustering_valid_source_version(value)) {
    stop(
      "clustering_cached_source_data_version: analysis_snapshot_source_data_version() ",
      "returned an invalid (NULL/NA/empty/non-scalar) value; refusing to cache or serve it"
    )
  }

  .clustering_source_data_version_cache$value <- value
  .clustering_source_data_version_cache$cached_at <- now
  value
}

# Assemble the clustering result `meta`: base fields + the cheap-path provenance
# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
# observed post-compute. Shared by the cache-hit path
# (job-functional-submission-service.R) and the worker-run/durable handler
# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
# shapes cannot drift apart by hand-copied edits.
clustering_result_meta <- function(base, provenance, weight_channel) {
  c(base,
    if (!is.null(provenance)) provenance else list(),
    list(effective_fingerprint = list(weight_channel = weight_channel)))
}
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
#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
#' curated-category selection via `category_filter` (resolved through
#' `clustering_resolve_category_universe()`), or -- when neither is supplied
#' -- the existing default all-NDD-genes universe. `genes` and
#' `category_filter` are mutually exclusive (400 if both are present). Every
#' submit records selector + fingerprint provenance in the durable payload
#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
#'
#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
#'   `category_filter` and `req$user$user_id`).
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

  # Connection objects cannot cross process boundaries. `genes` and
  # `category_filter` are mutually exclusive gene-universe selectors (#574):
  # an explicit gene list, a curated-category selection, or (both absent) the
  # existing default all-NDD-genes universe.
  genes_in <- req$argsBody$genes
  has_genes <- !is.null(genes_in) && length(genes_in) > 0

  # Selector presence is gated on JSON KEY PRESENCE (`names(req$argsBody)`), not
  # value-nullness or length: `!is.null()` cannot distinguish an ABSENT key from
  # an explicit JSON `null` (both parse to NULL in R). So a present `genes` key
  # (`{"genes":null,...}` / `{"genes":[],...}`) and a present `category_filter`
  # key each drive their guard regardless of value (Codex rounds 2 & 4). Mutual
  # exclusion 400s when BOTH keys are present; a present-but-null/empty
  # `category_filter` is a supplied-empty 400 (in the branch below), never a
  # silent fall-through to the all-NDD default. `has_genes` (value-based,
  # non-empty) still selects the explicit-genes branch.
  body_names <- names(req$argsBody)
  genes_key <- "genes" %in% body_names
  category_key <- "category_filter" %in% body_names

  if (genes_key && category_key) {
    stop_for_bad_request("Provide either genes or category_filter, not both")
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

  # Resolve the clustering gene universe + selector provenance (#574). The
  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
  # from before this feature: `clustering_resolve_category_universe(NULL)`
  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
  # so cache parity (memoise key = gene set + algorithm) is preserved.
  selector_chr <- NULL
  if (has_genes) {
    genes_list <- as.character(unlist(genes_in))
    kind <- "explicit"
  } else if (category_key) {
    # A present category_filter key means a category run. A present-but-null
    # value is supplied-but-empty (the resolver 400s on []/[""], but a NULL would
    # otherwise hit its absent->default branch), so reject it explicitly here.
    if (is.null(req$argsBody$category_filter)) {
      stop_for_bad_request(
        "category_filter was supplied but empty; provide at least one active category"
      )
    }
    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
    genes_list <- universe$hgnc_ids
    selector_chr <- universe$selector
    kind <- "category"
  } else {
    universe <- clustering_resolve_category_universe(NULL)
    genes_list <- universe$hgnc_ids
    kind <- "all_ndd"
  }

  # Pre-fetch the STRING ID table because DB connections cannot cross the
  # durable worker boundary.
  string_id_table <- pool %>%
    dplyr::tbl("non_alt_loci_set") %>%
    dplyr::filter(!is.na(STRING_id)) %>%
    dplyr::select(symbol, hgnc_id, STRING_id) %>%
    dplyr::collect()

  # Check for duplicate job (include algorithm in check). The selector is
  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
  # submits keep the pre-#574 dedup identity byte-identical.
  dup_params <- list(genes = genes_list, algorithm = algorithm)
  if (!is.null(selector_chr)) {
    dup_params$category_filter <- selector_chr
  }
  dup_check <- check_duplicate_job("clustering", dup_params)
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

  # Cheap-path provenance (no expensive query yet). `selector_obj` records
  # WHICH universe was resolved; `intended_fingerprint` records the STRING
  # cache identity + fixed clustering params this submit intends to run
  # with. The *effective* fingerprint (e.g. the STRING weight channel a
  # computed result actually used) is only knowable from a computed result,
  # so it is recorded separately in the cache-hit result meta below.
  selector_obj <- list(kind = kind, category_filter = selector_chr)
  intended_fingerprint <- list(
    string_cache_fingerprint = analysis_string_cache_fingerprint(),
    score_threshold = 400L,
    algorithm = algorithm,
    seed = 42L
  )
  gene_sha <- clustering_gene_list_sha256(genes_list)
  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
  # count must agree with it, so it is computed from the SAME dedup -- an
  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
  # not report a resolved count that disagrees with a singleton sha256. This
  # never dedups the payload `genes` list itself (`genes_list` stays
  # byte-identical to the raw request) -- only the reported COUNT (Codex
  # review fix).
  resolved_count <- length(unique(genes_list))

  # Source-data version: a CACHED, fail-closed read, fetched only now that a
  # payload is actually about to be built -- its backing view runs global
  # counts/joins, so it must never run before admission/dedup. A lookup
  # failure must never silently record NA/broken provenance; fail the
  # request closed instead.
  src_ver <- tryCatch(
    clustering_cached_source_data_version(conn = pool),
    error = function(e) e
  )
  if (inherits(src_ver, "error")) {
    res$status <- 503L
    return(list(
      error = "PROVENANCE_UNAVAILABLE",
      message = "Snapshot source-data version unavailable; retry shortly."
    ))
  }

  provenance <- list(
    selector = selector_obj,
    resolved_gene_count = resolved_count,
    gene_list_sha256 = gene_sha,
    intended_fingerprint = intended_fingerprint,
    source_data_version = src_ver
  )

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

    # Splice the base cache-hit fields with `provenance` (already assembled
    # above as selector/resolved_gene_count/gene_list_sha256/
    # intended_fingerprint/source_data_version) via the shared
    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
    # re-listing the same fields as duplicate literals -- keeps this shape in
    # lockstep with the worker-run handler's result meta by construction.
    # `effective_fingerprint` is only knowable from the computed result
    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
    cache_result <- list(
      clusters = cached_clusters,
      categories = categories,
      meta = clustering_result_meta(
        list(
          algorithm = algorithm,
          gene_count = resolved_count,
          cluster_count = nrow(cached_clusters),
          cache_hit = TRUE
        ),
        provenance,
        attr(cached_clusters, "weight_channel")
      )
    )
    cache_request_payload <- list(
      genes = genes_list,
      algorithm = algorithm,
      category_links = category_links,
      string_id_table = string_id_table,
      provenance = provenance
    )
    if (!is.null(selector_chr)) {
      cache_request_payload$category_filter <- selector_chr
    }
    # Dedup identity EXCLUDES provenance (Codex round 3): `provenance`
    # carries a time-varying `source_data_version` and STRING cache
    # `intended_fingerprint`, so hashing the full payload would make the
    # active-job uniqueness guard admit duplicate concurrent clustering work
    # across a deploy/cache-TTL change and break the byte-identical
    # explicit/no-arg `request_hash` contract predating #574. Removing the
    # `provenance` key preserves the leading `genes, algorithm,
    # category_links, string_id_table[, category_filter]` key order -- it was
    # appended last, so deleting it does not reorder the rest.
    cache_hash_payload <- cache_request_payload
    cache_hash_payload$provenance <- NULL
    completed_job <- async_job_service_store_completed(
      job_type = "clustering",
      request_payload = cache_request_payload,
      result = cache_result,
      submitted_by = req$user$user_id %||% NULL,
      queue_name = "analysis",
      priority = 50L,
      hash_payload = cache_hash_payload
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
  job_params <- list(
    genes = genes_list,
    algorithm = algorithm,
    category_links = category_links,
    string_id_table = string_id_table,
    provenance = provenance
  )
  if (!is.null(selector_chr)) {
    job_params$category_filter <- selector_chr
  }
  # See the cache-hit branch above: dedup identity EXCLUDES provenance so the
  # active-job uniqueness guard is not defeated by its time-varying fields,
  # and explicit/no-arg submits stay byte-identical to pre-#574.
  #
  # `create_job()` carries a deliberately guarded 2-arg contract
  # (`operation`, `params`) -- it cannot take a hash override. This path
  # calls `async_job_service_submit()` directly instead (mirroring the
  # cache-hit branch above, which already calls
  # `async_job_service_store_completed()` directly for the same reason), so
  # `hash_payload` can diverge from the stored `request_payload` without
  # touching `create_job()`'s contract.
  hash_params <- job_params
  hash_params$provenance <- NULL
  submitted <- async_job_service_submit(
    job_type = "clustering",
    request_payload = job_params,
    hash_payload = hash_params,
    submitted_by = req$user$user_id %||% NULL
  )
  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
  res$setHeader("Retry-After", "5")

  list(
    job_id = job_id,
    status = "accepted",
    estimated_seconds = 30,
    status_url = paste0("/api/jobs/", job_id, "/status")
  )
}
{
  "title": "SysNDD API",
  "description": "This is the API powering the SysNDD website, allowing programmatic access to the database contents.",
  "version": "0.30.1",
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
{
  "name": "sysndd",
  "version": "0.30.1",
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
  },
  "overrides": {
    "serialize-javascript": "^7.0.5",
    "js-cookie": "3.0.7",
    "qs": "6.15.2",
    "uuid": "11.1.1"
  },
  "browserslist": [
    "> 1%",
    "last 2 versions",
    "not dead"
  ],
  "lint-staged": {
    "*.{ts,tsx,vue}": [
      "eslint --fix --max-warnings=50",
      "prettier --write"
    ],
    "*.{js}": [
      "eslint --fix --max-warnings=50",
      "prettier --write"
    ],
    "*.{json,md,yml,yaml,css,scss}": [
      "prettier --write"
    ]
  }
}
---
title: "Development"
---

# Development

This page is the concise human-facing entry point for local SysNDD development.

## Requirements

- Docker with Compose v2
- Git
- GNU Make
- Node.js matching `app/.nvmrc`
- R 4.5.x for host-side API work

Helpful extras:

- `jq`
- `gh`
- a MySQL client such as `mysql` or `mycli`

## Quickstart

```bash
git clone https://github.com/berntpopp/sysndd.git
cd sysndd
make install-dev
make doctor
make dev
```

After `make dev`:

- App: `http://localhost`
- App (Vite): `http://localhost:5173`
- API: `http://localhost/api`
- API (direct): `http://localhost:7778`
- Traefik dashboard: `http://localhost:8090`
- MySQL dev: `localhost:7654`
- MySQL test: `localhost:7655`

Stop the stack with:

```bash
make docker-down
```

## Daily Commands

```bash
make dev
make docker-dev-db
make serve-app
make code-quality-audit
make pre-commit
make test-api-fast
make ci-local
```

Frontend-only verification:

```bash
cd app
npm run lint
npm run type-check
npm run test:unit
```

SEO prerender verification:

```bash
make verify-seo-app
cd app
npm run seo:generate:fixture
SEO_API_BASE_URL=http://localhost/api SEO_PUBLIC_BASE_URL=https://sysndd.dbmr.unibe.ch npm run seo:generate
npm run seo:verify
```

The fixture generator is deterministic and does not require the API. API-backed generation reads `/api/seo/routes`, `/api/seo/gene/:symbol`, and `/api/seo/entity/:id`; run it after `make dev` or against another healthy SysNDD API. The generator writes route-specific HTML and sitemap files into `app/dist`.

API-only verification:

```bash
make lint-api
make test-api-fast
make test-api
```

MCP analysis verification:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"
cd ..
make test-api-fast
```

For MCP 1.2 analysis changes, also check that the analysis tools remain read-only and bounded: `get_sysndd_analysis_catalog` -> `get_gene_research_context(dry_run = TRUE, response_mode = "compact")` -> focused follow-up tools. Analysis responses should use compact defaults, `max_response_chars = "auto"`, `budget` metadata, and `dry_run`/`diagnostics` recovery hints for broad result sets. Cached LLM summaries are validated admin-generated cache reads only, NDDScore is an ML prediction layer rather than a curated evidence tier, and stored external IDs should be treated only as `external_reference_identifier`.

Public and MCP analysis sections such as phenotype correlations, phenotype clusters, and STRING-derived gene networks require current public-ready analysis snapshots. Public REST and MCP paths report snapshot diagnostics such as `snapshot_missing`, `snapshot_stale`, or `source_version_mismatch`; they do not compute heavy analysis or read draft/admin data on miss.

### Database Version (issue #22)

The human-facing DB semantic version lives in the single-row `db_version` table (migration `028_add_db_version.sql`) and is read by `api/functions/db-version.R`. It is exposed in the `database` block of `GET /api/version` and rendered on the About page via `app/src/components/AppVersionInfo.vue` (typed client `app/src/api/version.ts`).

- Bump the seeded semantic version in a new numbered migration when the DB schema or core seed data changes meaningfully; do not edit an applied migration.
- At release time, capture the last `db/`-folder git commit and the version with `./db/scripts/update-db-version.sh` and inject `DB_VERSION` / `DB_COMMIT` into the API container; `db_version_sync_from_env()` updates the row at startup (non-fatal no-op when unset). See `documentation/09-deployment.qmd`.
- Run focused checks while iterating:

```bash
cd api
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

### Category-Selected Clustering (#574)

`POST /api/jobs/clustering/submit` accepts an optional `category_filter` JSON body array (e.g. `["Definitive"]`) as an alternative gene-universe selector to the existing `genes` array; supplying neither keeps the pre-#574 default all-NDD-genes universe, and supplying both is a 400. A category run resolves entity-level against the live `ndd_entity_view` (any gene with >=1 `ndd_phenotype = 1` entity in a selected category qualifies) and validates the selector against the live active `ndd_entity_status_categories_list` — an unknown/inactive category or a universe under 2 genes is a 400 naming the allowed active categories. Category runs are NOT `public_ready`; they are the same ephemeral job-result mechanism as an explicit-`genes` submit, just with a curated-category-derived universe.

Every submit (cache-hit or worker-run) records selector/fingerprint provenance in the durable job payload and result `meta` — see `api/functions/clustering-gene-universe.R` (resolver), `api/services/job-functional-submission-service.R` (cache-hit meta), and `.async_job_run_clustering()` in `api/functions/async-job-handlers.R` (worker-run meta) for the exact shape. Focused checks while iterating:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-clustering-gene-universe.R')"
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-clustering-handler-meta.R')"
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-endpoint-services.R')"
```

`test-integration-clustering-category-submit.R` exercises the resolver against a real, populated `sysndd_db_test` `ndd_entity_view` and skips cleanly on the empty CI/local default test DB.

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
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-disease-ontology-mapping-builder.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-ontology-mapping-refresh.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-ontology-mapping-service.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-admin-ontology-mapping-endpoints.R')"
```

Integration tests require a DB (note: `api/tests/` is NOT bind-mounted into the API container; see container mount notes):
```bash
# In-container against the dev DB (substitute dev DB creds):
docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-integration-ontology-mapping-refresh.R')"
# Or with provisioned test DB in CI: make test-api
```

## End-to-End Tests (Playwright)

The Playwright suite is **local-only**, used for ad-hoc pre-PR regression sanity checks against a real API+DB stack via a Docker Compose overlay isolated from `make dev`. There is no Playwright CI workflow — the official lane (lint, type-check, vitest, R API, smoke) covers automated regression. The Playwright spec files live in `app/tests/e2e/` for manual invocation when a refactor warrants a full-flow check.

### Local run

```bash
make playwright-stack          # bring up traefik + api + db + app on the playwright project
cd app && PLAYWRIGHT_BASE_URL=http://localhost:8088 npx playwright test  # run all specs
make playwright-stack-down     # tear down + remove volumes
```

The Playwright stack provisions four deterministic test users (`pw_admin`, `pw_curator`, `pw_reviewer`, `pw_user`) from `db/fixtures/playwright_users.sql`. Plaintext passwords for these accounts are committed in `app/tests/e2e/fixtures/test-users.ts` because the accounts exist only in the isolated `playwright` compose project.

### Slow-route / external-provider isolation (#344)

The API guarantee is that no single request can occupy a Plumber worker for tens of seconds. Backend coverage is host-runnable (pure tests, no DB/network):

```bash
cd api && Rscript --no-init-file -e "for (f in c(
  'test-unit-external-proxy-budgets.R','test-unit-external-slow-provider.R',
  'test-unit-external-budget-guard.R','test-unit-cheap-route-isolation.R',
  'test-integration-slow-provider-isolation.R'
)) testthat::test_file(file.path('tests/testthat', f))"
```

`test-unit-external-budget-guard.R` fails if any external fetcher hardcodes a `req_timeout(<n>)`/`max_seconds=<n>` literal instead of `external_proxy_budget()`; `test-unit-cheap-route-isolation.R` fails if a cheap route (`/health`, `/auth`, `/statistics`) references an external fetcher. The matching frontend check (gene page renders while every `/api/external/**` response is stalled 20s) is the local-only spec `app/tests/e2e/slow-provider-resilience.spec.ts` — note the gene record/entities table read `/api/entity` & `/api/gene`, so it needs a **seeded** stack (the Playwright `8088` stack is schema-only; run against the seeded dev Vite server, e.g. `cd app && PLAYWRIGHT_BASE_URL=http://localhost:5173 npx playwright test tests/e2e/slow-provider-resilience.spec.ts`).

### Documentation screenshots

Documentation screenshots use a dedicated Playwright config and manifest under `app/tests/docs-screenshots/`. They are generated documentation assets, separate from E2E failure screenshots and visual-regression baselines, and are written under `documentation/static/img/generated/` with a generated provenance manifest.

UI and documentation design review guidance lives in `documentation/10-visual-design-guide.md` and `documentation/11-admin-visual-review.md`. These files are developer-facing references unless they are intentionally added to the Quarto navigation.

Recommended local sequence:

```bash
make docs-screenshots
make docs-screenshots-down
```

The `make docs-screenshots` target runs the stack, seeds the screenshot fixture data, runs the dedicated screenshot command, and verifies generated assets. For step-by-step debugging, run `make playwright-stack`, then `make _playwright-seed-docs-data`, then the `npm run docs:screenshots` command shown in `Makefile`, then `node scripts/documentation/verify-doc-screenshots.mjs`, and finally `make playwright-stack-down`. The Playwright stack uses `http://localhost:8088` by default; override `PLAYWRIGHT_HOST_PORT` if that port is already in use. Always run `make docs-screenshots-down` or `make playwright-stack-down` before handing off.

### Authoring a new spec

Use the auth fixture for non-auth tests:

```ts
import { test, expect } from './fixtures/auth';

test('something', async ({ loggedInAs }) => {
  const page = await loggedInAs('curator');
  await page.goto('/SomeRoute');
  // ...
});
```

Use `uniqueName('prefix')` from `fixtures/data.ts` for any server-side state created by the test. Tests must be order-independent — Playwright runs them in parallel by default.

### Screenshots

Specs do **not** write artifact screenshots by default. Playwright's `screenshot: 'only-on-failure'` (see `app/playwright.config.ts`) still captures debugging shots on failure into `app/tests/e2e/.playwright-output/`. If you want before/after comparison artifacts for a specific UI change, add an ad-hoc `await page.screenshot({ path: 'tests/e2e/screenshots/...' })` line locally for that run; do not commit it.

### Selectors

The recommended workflow for selector discovery is `npx playwright codegen http://localhost:80/Path`. Prefer role + accessible-name selectors (`getByRole`, `getByLabel`) over CSS selectors.

### Perf benchmarks (v11.3)

`/Genes/:symbol` and `/Entities/:entity_id` ship a Playwright perf + axe bench under `app/tests/perf/`. It is **local-only** — there is no CI workflow.

```bash
make cache-clear              # cold-pass: wipe API memoise caches, including external proxy caches
make playwright-stack         # or `make dev` if the playwright stack lacks views/data
cd app && npx playwright test tests/perf/genes-entities.bench.spec.ts --workers=1
cd .. && make playwright-stack-down   # or `make docker-down` if you used `make dev`
```

The bench writes `.planning/perf/after-${date}.json` and screenshots into `.planning/screenshots/after-*.png`. Spec §8 lists the gates the harness asserts. If you regress an assertion, look at the diff between the new JSON and `.planning/perf/baseline-5-genes-fullnav.json`.

The bench requires `@axe-core/playwright` (a dev dep). If `npm install` complains about a missing peer, re-run from `app/`. Use `--workers=1` so the per-probe `persistResult()` writes are sequential.

### Running an NDDScore import locally

Use the administrator `/ManageNDDScore` page for local NDDScore release checks. The intended flow is: **Check Zenodo**, then **Download & validate**, then **Import & activate latest release**. The validation action submits `validate_only = true` and downloads, verifies, parses, and validates the archive without switching the active release. The import action submits `validate_only = false`; the previous active release keeps serving until the final activation step succeeds.

NDDScore import work runs in the worker service. Restart the worker container after changing `api/functions/nddscore-*.R` or `api/functions/async-job-handlers.R` before testing job behavior in Docker.

The default Zenodo source is configured through the same environment-file path as other deployment settings. `NDDSCORE_ZENODO_RECORD_ID` defaults to `20258027`, and `NDDSCORE_ZENODO_API_BASE_URL` defaults to `https://zenodo.org/api/records`. If those environment variables are absent, the API falls back to `api/config.yml`; the built-in literal defaults are only a final safety net for tests and local development.

### Managing curation metadata vocabularies

Use the administrator `/ManageMetadata` page to administer the small SysNDD-managed curation controlled vocabularies (status categories, modifiers) and to curate display fields on the ontology-anchored sets (inheritance modes, variation ontology). The page renders one tab and table per vocabulary backed by `/api/metadata`.

Editability is tiered deliberately: status categories and modifiers support full create / edit / deactivate; inheritance modes and variation-ontology terms expose curated-field edits and activation toggles only, because their terms are sourced from HPO and VariO and may be overwritten on the next ontology refresh. HPO phenotypes, the disease ontology, and gene nomenclature are refreshed from source elsewhere and are not editable here.

Deletes are soft-deletes: an entry still referenced by curation data is blocked with a clear error and must be deactivated rather than removed. The vocabulary catalog, editability tiers, and in-use reference lists are defined in `metadata_vocabulary_registry()` (`api/functions/metadata-vocabulary-repository.R`); extend that registry when adding a managed vocabulary or a new referencing table.

Offline importer fixtures live under `api/tests/testthat/fixtures/nddscore/`. The committed fixture generator, `make-fixture-archive.R`, rebuilds the small `.tar.gz` archives used by tests; those generated archives are ignored because they can be regenerated on demand.

## Common Gotchas

- Start the DB stack before host-side API work.
- `make code-quality-audit` is the fast deterministic quality ratchet. It allows the committed oversized-file baseline in `scripts/code-quality-file-size-baseline.tsv`, but fails if a new handwritten source file exceeds 600 lines or an existing oversized source file grows.
- `make pre-commit` is the fast local mirror of the pull-request gate. Use `make ci-local` before handoff, and `make test-api` when you want the full API suite locally.
- Restart the worker container after changing code used by background jobs. The API submits durable jobs; the worker service executes them.
- Namespace masked R functions such as `dplyr::select(...)`.
- Auth/signup/password-sensitive API inputs are body-only. Use JSON request bodies for `POST /api/auth/signup`, `POST /api/auth/authenticate`, and password-change flows; do not send those values in query strings or persist raw query strings in request logs.
- Host-side API quality targets use `Rscript --no-init-file` under the hood to avoid Conda/miniforge bootstrap interference before the repo's own R script entrypoints run.
- On Conda/miniforge R installs, `Makefile` derives `HOST_R_LD_LIBRARY_PATH` from `R RHOME` and prepends the sibling `mariadb/` runtime directory so `RMariaDB` can load. Override `HOST_R_LD_LIBRARY_PATH` when the MariaDB client runtime lives elsewhere.
- External proxy cache tests should use `memoise_external_success_only()` when adding new cached source fetchers. It keeps successes cached but evicts transient `error = TRUE` payloads immediately so one upstream timeout does not affect local development for days.
- Curation-comparison sources: URLs live in the `comparisons_config` table (patched by migrations, e.g. `013` for gene2phenotype, `038` for geisinger→NDD GeneHub, `040` for the `geisinger_DBD`→`ndd_genehub` key rename), and the per-source parsers live in `api/functions/comparisons-parsers.R`. The refresh is resilient (a failed source keeps its previous rows via per-list replace; status `partial` vs `success`), so verify a source URL end-to-end (real content, not an HTML error page) before wiring it in. `comparisons_update` runs as a **durable async job on the worker** — its write-path files (`comparisons-sources.R`/`-parsers.R`/`-omim.R`/`-functions.R` and `omim-functions.R`) are registered in `api/bootstrap/load_modules.R` (shared by the API and worker); register any new comparisons file there and restart the `worker` container (not the API) to pick up changes. The `ndd_genehub` source's `category` is the NDD GeneHub evidence tier (`AR` / `Tier 1`–`Tier 4` / `Missense`), from `ndd_genehub_category_lookup()`. HPO term data now uses the JAX ontology API `https://ontology.jax.org/api/hp/terms/{id}` (the legacy `hpo.jax.org` term API was retired and its JSON shape changed; use the single `/descendants` call for descendant sets). The OMIM-NDD seed is configurable — `adapt_genemap2_for_comparisons(seed_term = ...)` / `omim_ndd_seed_sweep()` (#502).

### Interpreting `make ci-local` output

`make ci-local` mirrors the GitHub Actions lanes (lint, type-check, full R API
tests with a DB). A successful run ends with the `CI-LOCAL PASSED` banner. The
verdict is the banner and the per-step `✓` lines — not the absence of every
warning. Some output is expected in the default local profile and is **not** a
sign that anything needs fixing:

- **Test DB reset.** The reset step tries `root` first (to `GRANT` to the
  `bernt` test user) and falls back to the regular `MYSQL_USER`. In the default
  local profile the `root`-over-TCP attempt is expected to be denied; the
  fallback succeeds. The harness now suppresses that expected `ERROR 1045`
  access-denied line when the fallback works, and only prints reset diagnostics
  (and fails) when **both** attempts fail. A genuine DB connectivity or
  permission failure still surfaces and still fails the run.
- **Expected skips.** Optional R packages (`ellmer`, `mcptools`,
  `ontologyIndex`, `tidyverse`), `RUN_SLOW_TESTS`-gated tests, and tests that
  need live services (the SysNDD API, Mailpit), seeded auth/fixtures, or
  external credentials are skipped locally. These run in the full/nightly
  GitHub Actions lanes instead. The R test runner prints a classified
  **"CI test skip summary"** at the end that buckets these as *expected
  local-profile skips* and lists anything else under *Unexpected skips (review
  these)*. The bucketing lives in `api/scripts/ci-test-summary.R`; the
  fail/pass decision is unchanged (`api/scripts/run-ci-tests.R` still exits
  non-zero on any failure or error).
- **Warnings from negative-path tests.** Some unit tests deliberately exercise
  error/warning branches, so warning text in the per-test output is normal as
  long as the test passes.

This is output hygiene only: real lint/type/test failures still fail
`make ci-local` exactly as before.

### Publication-date provenance

`publication.publication_date_source` records how each `Publication_date` was derived (`pubmed`, `pubmed_partial`, `medline_date`, `unknown`). New ingestions set it automatically. To correct historical rows ingested before this fix, run the one-off backfill: `Rscript db/updates/backfill_publication_dates.R --dry-run --limit=25` for a small rehearsal, `--dry-run` to preview the full run, then `--apply`. It re-fetches PubMed metadata, so it needs network egress. The script is dry-run by default, uses an advisory lock, limits PubMed fallback requests with `NCBI_REQUEST_DELAY_SECONDS`, and commits DB writes in batches controlled by `BACKFILL_UPDATE_BATCH_SIZE`.

### GeneReviews coverage (curator)

The curator GeneReviews coverage page (`/GeneReviews`, Curator+) lists active entities with their gene and whether a GeneReviews reference is already linked, lets curators attach a GeneReviews chapter to an entity, and exports the gene→GeneReviews coverage as CSV (issues #14, #46). It is served by `api/endpoints/genereviews_endpoints.R` (mounted at `/api/genereviews`), backed by `api/services/genereviews-service.R` and the cached lookup in `api/functions/genereviews-lookup.R`.

GeneReviews availability is resolved through NCBI E-utilities (`esearch`/`esummary` against the `books` database, filtered to the GeneReviews book) rather than HTML scraping. The lookup is wrapped with `memoise_external_success_only()` (30-day static cache) so transient NCBI failures are never cached. The default coverage view is cheap (already-linked references only, no external calls); the live availability pass is opt-in via `include_live=true` and is intended for occasional curator use, not high-frequency public traffic. Attaching reuses the existing publication model: the GeneReviews chapter PMID is registered in `publication` (type `gene_review`) and linked to the entity's primary review in `ndd_review_publication_join`. NCBI credentials are optional and read from `NCBI_API_KEY` / `NCBI_EUTILS_EMAIL`; anonymous low-volume use works without them. The frontend uses the typed client `app/src/api/genereviews.ts` (no raw axios).

For repository-specific agent guidance and deeper runtime quirks, see the root `AGENTS.md`.

exec
/bin/bash -lc "sed -n '1,220p' api/endpoints/jobs_endpoints.R; sed -n '1,430p' api/functions/async-job-handlers.R; sed -n '1,560p' api/functions/async-job-service.R; sed -n '1,220p' api/functions/clustering-gene-universe.R; sed -n '1,430p' api/services/job-functional-submission-service.R; sed -n '1,330p' api/bootstrap/load_modules.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
#* Submits an async job to compute functional clustering via STRING-db. The
#* clustering gene universe (#574) is resolved from one of three mutually
#* exclusive JSON body selectors:
#*   - `genes`: an explicit array of HGNC ids to cluster.
#*   - `category_filter`: an array of curated SysNDD confidence categories
#*     (e.g. `["Definitive"]`); resolved entity-level (>=1 NDD entity in a
#*     selected category, `ndd_phenotype = 1`) against the live
#*     `ndd_entity_view`, validated against the live active
#*     `ndd_entity_status_categories_list`. A category run rejects with 400
#*     when `category_filter` is empty, contains an unknown/inactive value
#*     (the allowed active set is named in the error), or resolves fewer
#*     than 2 genes.
#*   - neither: the existing default all-NDD-genes universe.
#* Supplying both `genes` and a non-empty `category_filter` is a 400.
#*
#* Every submit records selector/fingerprint provenance -- `selector`
#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
#* category runs), `resolved_gene_count`, `gene_list_sha256`,
#* `intended_fingerprint`, and `source_data_version` -- in the durable job
#* payload; the job result `meta` additionally carries `effective_fingerprint`
#* (the STRING `weight_channel` actually observed on the computed result),
#* recorded on both a cache-hit (immediate) response and a worker-run
#* (cache-miss) job.
#*
#* Results from this endpoint (including category-filtered runs) are never
#* `public_ready` -- they are ephemeral job results, distinct from the public
#* `analysis_snapshot_*` layer.
#*
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @param genes Optional JSON array of explicit HGNC ids. Mutually exclusive
#*   with `category_filter`.
#* @param category_filter Optional JSON array of curated SysNDD confidence
#*   categories (e.g. `["Definitive"]`). Mutually exclusive with `genes`.
#* @param algorithm Optional clustering algorithm string, `"leiden"`
#*   (default) or `"walktrap"`.
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
## -------------------------------------------------------------------##

#* Get Job History
#*
#* Returns a list of recent jobs for admin review.
#* Requires Administrator role.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @get /history
function(req, res, limit = 20) {
  require_role(req, res, "Administrator")
  svc_job_get_history(limit)
}

## -------------------------------------------------------------------##
## Job Status Polling
## -------------------------------------------------------------------##

#* Get Job Status
#*
#* Poll job status and retrieve results when complete.
#* Returns Retry-After header for running jobs.
#*
#* @tag jobs
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @get /<job_id>/status
function(job_id, result_mode = "summary", req, res) {
  svc_job_get_status(job_id, result_mode, req, res)
}
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
# NOTE: .async_job_run_clustering assembles its result meta via
# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
# worker/API entrypoint sources that module via bootstrap_load_modules() before
# this file; a direct-source test env must source it too (as the async-job tests do).

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
  # #574 D3: the cheap-path selector/fingerprint provenance the submit
  # service (job-functional-submission-service.R) recorded in the payload.
  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
  # FALSE) so a worker-run job for those still completes normally.
  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)

  progress("cluster", "Running functional clustering...", current = 0, total = 1)

  clusters <- gen_string_clust_obj(
    genes,
    algorithm = algorithm,
    string_id_table = string_id_table
  )

  progress("complete", "Functional clustering complete", current = 1, total = 1)

  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
  # path), then the request's cheap-path `provenance` (selector/
  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
  # source_data_version) when present, then the `effective_fingerprint` --
  # only knowable now that `clusters` has actually been computed -- so a
  # silent exp+db -> combined-score STRING fallback on a worker-run job is
  # visible in the stored result too, not just a cache hit's.
  # gene_count is the DISTINCT gene count, matching the cache-hit path's
  # `resolved_count <- length(unique(genes_list))` (job-functional-submission-
  # service.R) -- for `["HGNC:1","HGNC:1"]` a raw `length(genes)` reported 2
  # here while the cache-hit path reported 1 for the identical payload
  # (Codex round-2 review fix). This never dedups the payload `genes` list
  # itself or changes `nrow(clusters)`, only the reported count.
  meta <- clustering_result_meta(
    list(
      algorithm = algorithm,
      gene_count = length(unique(genes)),
      cluster_count = nrow(clusters),
      cache_hit = FALSE
    ),
    provenance,
    attr(clusters, "weight_channel")
  )

  list(
    clusters = clusters,
    categories = .async_job_functional_categories(clusters, category_links),
    meta = meta
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
  progress("cluster", "Running phenotype clustering...", current = 1, total = 2)
  phenotype_clusters <- gen_mca_clust_obj(phenotype_matrix)
  progress("complete", "Phenotype clustering complete", current = 2, total = 2)

  identifiers <- payload$ndd_entity_view_tbl |>
    dplyr::select(entity_id, hgnc_id, symbol)

  phenotype_clusters |>
    tidyr::unnest(identifiers) |>
    dplyr::mutate(entity_id = as.integer(entity_id)) |>
    dplyr::left_join(identifiers, by = "entity_id") |>
    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
}

.async_job_run_ontology_update <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])

  progress("init", "Preparing ontology update", current = 0, total = 4)
  disease_ontology_set <- process_combine_ontology(
    hgnc_list = payload$hgnc_list,
    mode_of_inheritance_list = payload$mode_of_inheritance_list,
    max_file_age = 0,
    output_path = "data/",
    progress_callback = progress
  )
  progress("complete", "Ontology update complete", current = 4, total = 4)

  list(
    status = "completed",
    rows_processed = nrow(disease_ontology_set),
    sources = c("MONDO", "OMIM"),
    output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
  )
}

.async_job_run_passthrough <- function(fn_name) {
  force(fn_name)

  function(job, payload, state, worker_config) {
    fn <- base::get(fn_name, mode = "function")
    fn(.async_job_add_job_id(payload, job))
  }
}

async_job_handler_registry <- list(
  clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_run_clustering,
    after_success = function(result, job, payload, state, worker_config) {
      .async_job_chain_llm(result, job, cluster_type = "functional")
    }
  ),
  phenotype_clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_run_phenotype_clustering,
    after_success = function(result, job, payload, state, worker_config) {
      .async_job_chain_llm(result, job, cluster_type = "phenotype")
    }
  ),
  ontology_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_ontology_update,
    after_success = .async_job_after_success_noop
  ),
  hgnc_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_hgnc_update,
    after_success = .async_job_after_success_noop
  ),
  comparisons_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_passthrough("comparisons_update_async"),
    after_success = .async_job_after_success_noop
  ),
  pubtator_update = list(
    cancel_mode = "best_effort",
    run = .async_job_run_pubtator,
    after_success = .async_job_after_success_noop
  ),
  pubtator_enrichment_refresh = list(
    cancel_mode = "best_effort",
    run = .async_job_run_pubtator_enrichment,
    after_success = .async_job_after_success_noop
  ),
  pubtatornidd_nightly = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_pubtatornidd_nightly,
    after_success = .async_job_after_success_noop
  ),
  disease_ontology_mapping_refresh = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_disease_ontology_mapping_refresh,
    after_success = .async_job_after_success_noop
  ),
  nddscore_import = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_nddscore_import,
    after_success = .async_job_after_success_noop
  ),
  llm_generation = list(
    cancel_mode = "best_effort",
    run = .async_job_run_passthrough("llm_batch_executor"),
    after_success = .async_job_after_success_noop
  ),
  network_layout_prewarm = list(
    cancel_mode = "best_effort",
    run = function(...) .async_job_run_network_layout_prewarm(...),
    after_success = .async_job_after_success_noop
  ),
  analysis_snapshot_refresh = list(
    cancel_mode = "best_effort",
    run = function(...) .async_job_run_analysis_snapshot_refresh(...),
    after_success = .async_job_after_success_noop
  ),
  backup_create = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_backup_create,
    after_success = .async_job_after_success_noop
  ),
  backup_restore = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_backup_restore,
    after_success = .async_job_after_success_noop
  ),
  omim_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_omim_update,
    after_success = .async_job_after_success_noop
  ),
  force_apply_ontology = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_force_apply_ontology,
    after_success = .async_job_after_success_noop
  ),
  publication_refresh = list(
    cancel_mode = "best_effort",
    run = .async_job_run_publication_refresh,
    after_success = .async_job_after_success_noop
  ),
  publication_date_backfill = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_publication_date_backfill,
    after_success = .async_job_after_success_noop
  )
)

#' Resolve a durable async job handler definition
#' @param job_type Character async job type.
#' @param registry Named handler registry.
#'
#' @return Registry entry with run/cancel metadata.
#' @export
async_job_get_handler <- function(job_type, registry = async_job_handler_registry) {
  entry <- registry[[job_type]]

  if (is.null(entry)) {
    stop(sprintf("No durable async job handler registered for '%s'", job_type), call. = FALSE)
  }

  if (!is.function(entry$run)) {
    stop(sprintf("Handler registry entry for '%s' is missing a callable run function", job_type), call. = FALSE)
  }

  if (is.null(entry$after_success)) {
    entry$after_success <- .async_job_after_success_noop
  }

  entry
}
# ---------------------------------------------------------------------------
# Queue-depth capacity cap
# ---------------------------------------------------------------------------

# Max simultaneously queued+running jobs allowed on the public submit queue.
# Read once at source/startup time; changing the env var requires an API
# restart to take effect. An INVALID value (e.g. "abc") must not parse to NA:
# `async_job_capacity_exceeded()` isTRUE-wraps its comparison, so an NA cap would
# silently disable this DB-backed backstop entirely. Floor at 1, default 8.
ASYNC_PUBLIC_JOB_CAP <- local({
  raw <- trimws(Sys.getenv("ASYNC_PUBLIC_JOB_CAP", "8"))
  value <- suppressWarnings(as.integer(raw))
  if (is.na(value) || value < 1L) 8L else value
})

#' TRUE when the active (queued+running) job count is at or over the cap.
#'
#' Soft cap: the check-then-submit sequence in the endpoints is not atomic, so
#' two concurrent requests may both pass and transiently push the queue one or
#' two over the cap. That is acceptable for a back-pressure guard.
#'
#' @param active_count Integer count of currently in-flight jobs.
#' @param cap Integer maximum allowed. Defaults to ASYNC_PUBLIC_JOB_CAP.
#' @return Logical.
#' @export
async_job_capacity_exceeded <- function(active_count, cap = ASYNC_PUBLIC_JOB_CAP) {
  cap <- suppressWarnings(as.integer(cap))
  if (length(cap) != 1L || is.na(cap) || cap < 1L) {
    cap <- 8L # never let an invalid cap silently disable the backstop
  }
  isTRUE(as.integer(active_count) >= cap)
}

#' Count queued+running jobs for a given queue.
#'
#' @param queue_name Character queue name to inspect.
#' @param conn Optional DB connection or pool. NULL uses global pool.
#' @return Integer count of active (queued / running / cancel_requested) jobs.
#' @export
async_job_active_count <- function(queue_name = "default", conn = NULL) {
  sql <- paste(
    "SELECT COUNT(*) AS n FROM async_jobs",
    "WHERE queue_name = ? AND status IN ('queued', 'running', 'cancel_requested')"
  )
  row <- db_execute_query(sql, params = list(queue_name), conn = conn)
  if (nrow(row) == 0) 0L else as.integer(row$n[[1]])
}

# ---------------------------------------------------------------------------
# Queue routing + priority by job type (#486)
#
# One serial worker draining one shared "default" queue lets a long-running,
# non-interruptible maintenance job (e.g. publication_date_backfill) head-of-line
# block latency-sensitive interactive jobs (clustering / phenotype_clustering /
# llm_generation and the snapshot -> LLM deploy chain). These helpers are the
# single source of truth for which lane and priority a job type defaults to; the
# `worker-maintenance` container drains the "maintenance" lane so heavy jobs run
# in parallel with the interactive worker instead of blocking it.
# ---------------------------------------------------------------------------

# Heavy / bulk / external maintenance job types, routed to the "maintenance" lane.
ASYNC_MAINTENANCE_JOB_TYPES <- c(
  "publication_date_backfill",
  "publication_refresh",
  "pubtator_update",
  "pubtator_enrichment_refresh",
  "pubtatornidd_nightly",
  "omim_update",
  "hgnc_update",
  "comparisons_update",
  "ontology_update",
  "force_apply_ontology",
  "disease_ontology_mapping_refresh",
  "nddscore_import",
  "backup_create",
  "backup_restore"
)

# Latency-sensitive / user-visible interactive job types. They stay on the
# "default" lane but get the LOWEST priority number so a worker claims them ahead
# of any maintenance job that happens to share the queue.
ASYNC_INTERACTIVE_JOB_TYPES <- c(
  "clustering",
  "phenotype_clustering",
  "llm_generation",
  "analysis_snapshot_refresh",
  "network_layout_prewarm"
)

# Priority tiers (lower number = claimed first; the claim query orders
# `priority ASC`). interactive < maintenance < everything-else default.
ASYNC_PRIORITY_INTERACTIVE <- 10L
ASYNC_PRIORITY_MAINTENANCE <- 50L
ASYNC_PRIORITY_DEFAULT <- 100L

#' Resolve the durable queue lane for a job type.
#'
#' @param job_type Character durable job type.
#' @return "maintenance" for heavy/bulk/external maintenance job types, else
#'   "default".
#' @export
async_job_queue_for_type <- function(job_type) {
  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
  if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) "maintenance" else "default"
}

#' Resolve the default claim priority for a job type.
#'
#' @param job_type Character durable job type.
#' @return Integer priority: interactive (10) < maintenance (50) < default (100).
#' @export
async_job_priority_for_type <- function(job_type) {
  jt <- if (length(job_type) >= 1L) as.character(job_type)[[1]] else ""
  if (jt %in% ASYNC_INTERACTIVE_JOB_TYPES) {
    ASYNC_PRIORITY_INTERACTIVE
  } else if (jt %in% ASYNC_MAINTENANCE_JOB_TYPES) {
    ASYNC_PRIORITY_MAINTENANCE
  } else {
    ASYNC_PRIORITY_DEFAULT
  }
}

# ---------------------------------------------------------------------------

.async_job_service_scalar <- function(value, default = NULL) {
  if (is.null(value) || length(value) == 0) {
    return(default)
  }

  if (is.list(value)) {
    return(value[[1]])
  }

  value[[1]]
}

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
#' @param hash_payload Optional named list or JSON payload string. When
#'   supplied, the dedup `request_hash` is computed over THIS payload instead
#'   of `request_payload`, while `request_payload_json` (the durably stored
#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
#'   `request_payload` exactly as before, so existing callers are unaffected.
#'   Used by clustering submits (#574) to exclude time-varying `provenance`
#'   metadata from the dedup identity while still persisting it.
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
  conn = NULL,
  hash_payload = NULL
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
  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
  request_hash <- async_job_service_request_hash(job_type, hash_payload_json)
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
#' @param hash_payload Optional named list or JSON payload string. When
#'   supplied, the dedup `request_hash` is computed over THIS payload instead
#'   of `request_payload`, while `request_payload_json` (the durably stored
#'   payload) is always the FULL `request_payload`. `NULL` (default) hashes
#'   `request_payload` exactly as before, so existing callers are unaffected.
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
  conn = NULL,
  hash_payload = NULL
) {
  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
  payload_json <- async_job_service_payload_json(request_payload)
  hash_payload_json <- if (is.null(hash_payload)) payload_json else async_job_service_payload_json(hash_payload)
  result_json <- async_job_service_payload_json(result)

  async_job_repository_create(
    list(
      job_id = job_id,
      job_type = job_type,
      queue_name = queue_name,
      priority = as.integer(priority),
      status = "completed",
      request_hash = async_job_service_request_hash(job_type, hash_payload_json),
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

  async_job_repository_cancel(
    job_id = job_id,
    cancelled_by = if (is.null(cancelled_by)) NULL else as.integer(cancelled_by),
    conn = conn
  )

  async_job_repository_get(job_id, conn = conn)
}

#' Legacy duplicate response wrapper for endpoints not migrated yet
#'
#' @inheritParams async_job_service_find_duplicate
#'
#' @return List shaped like the previous duplicate helper.
#' @export
async_job_service_duplicate <- function(job_type, request_payload, conn = NULL) {
  duplicate <- async_job_service_find_duplicate(
    job_type = job_type,
    request_payload = request_payload,
    conn = conn
  )

  if (nrow(duplicate) == 0) {
    return(list(duplicate = FALSE))
  }

  list(
    duplicate = TRUE,
    existing_job_id = duplicate$job_id[[1]]
  )
}

#' Find an active job of a given type (job-type single-flight).
#'
#' @param job_type Character job type.
#' @param conn Optional DB connection or pool.
#' @return Tibble with zero or one active duplicate row of that job_type.
#' @export
async_job_service_find_active_by_type <- function(job_type, conn = NULL) {
  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
  async_job_repository_find_active_by_type(job_type = job_type, conn = conn)
}

#' Job-type single-flight duplicate check (#535 S2b HIGH-4).
#'
#' Unlike `async_job_service_duplicate()` (which keys on the payload hash and so
#' cannot dedupe across a payload-schema change), this dedupes on job_type alone,
#' so a destructive full-table-replace maintenance job (hgnc/comparisons/omim/
#' force_apply) resubmitted while one is in flight gets a clean 409 even across
#' the deploy that drops db_config from its payload.
#'
#' NOTE (scope): this is a **best-effort, submit-time** guard — the check and the
#' subsequent insert are NOT atomic, so a rare concurrent double-submit can still
#' enqueue two jobs. That is acceptable because the durable **maintenance lane
#' runs on a single worker** (`async_job_worker_main` claims+runs jobs
#' sequentially; Compose runs one `worker-maintenance` container), so two
#' destructive jobs never execute concurrently regardless of dedup. A hard,
#' atomic **cross-type conflict-group mutex** (e.g. an advisory lock covering
#' check+insert, or a generated conflict-key unique index grouping
#' omim_update/force_apply_ontology and pubtator_enrichment_refresh/
#' pubtatornidd_nightly) is defense-in-depth needed only if the maintenance lane
#' is ever scaled beyond one worker — tracked as a follow-up, not part of this
#' credential fix.
#'
#' @param job_type Character job type.
#' @param conn Optional DB connection or pool.
#' @return list(duplicate = FALSE) or list(duplicate = TRUE, existing_job_id = ...).
#' @export
async_job_service_duplicate_by_type <- function(job_type, conn = NULL) {
  active <- async_job_service_find_active_by_type(job_type, conn = conn)
  if (nrow(active) == 0) {
    return(list(duplicate = FALSE))
  }
  list(duplicate = TRUE, existing_job_id = active$job_id[[1]])
}

#' Legacy cancellation wrapper for endpoints not migrated yet
#'
#' @inheritParams async_job_service_cancel
#'
#' @return List describing cancellation outcome.
#' @export
async_job_service_request_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
  cancelled <- async_job_service_cancel(
    job_id = job_id,
    cancelled_by = cancelled_by,
    conn = conn
  )

  if (nrow(cancelled) == 0) {
    return(list(
      error = "JOB_NOT_FOUND",
      message = "Job ID not found"
    ))
  }

  list(job_id = job_id, status = cancelled$status[[1]])
}
# api/functions/clustering-gene-universe.R
#
# Category-selected clustering gene-universe resolver (#574 D1).
#
# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
# universe from curated SysNDD confidence categories instead of the default
# "all NDD genes" set. This file builds ONLY the resolver + provenance
# helpers; the submit service and durable handler wiring is done later.
#
# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
# same gene also has OTHER-category entities. This mirrors
# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
# added `category %in% selector` filter -- it deliberately does NOT use
# `select_network_gene_category()`, which is a gene-level display-label
# aggregator for node coloring, not a universe filter.
#
# Category validation is live against `ndd_entity_status_categories_list
# WHERE is_active = 1` -- no hardcoded category strings, and no category
# string is interpolated into SQL (dbplyr `%in%` + an allowlist pre-check).

# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
# selector returns character(0), which the resolver rejects with 400 -- it must
# never fall through to the all-NDD default.
clustering_normalize_category_filter <- function(category_filter) {
  if (is.null(category_filter)) return(NULL)
  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
  vals <- vals[nzchar(vals)]
  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
  sort(unique(vals))
}

clustering_gene_list_sha256 <- function(hgnc_ids) {
  digest::digest(
    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
    algo = "sha256", serialize = FALSE
  )
}

clustering_resolve_category_universe <- function(category_filter, conn = pool) {
  selector <- clustering_normalize_category_filter(category_filter)

  if (is.null(selector)) {
    # Absent -> preserve the exact current default ordering for cache parity.
    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
  }
  if (length(selector) == 0L) {
    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
  }

  active <- conn %>%
    dplyr::tbl("ndd_entity_status_categories_list") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::select(category) %>%
    dplyr::collect() %>%
    dplyr::pull(category)
  unknown <- setdiff(selector, active)
  if (length(unknown) > 0L) {
    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
    stop_for_bad_request(sprintf(
      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
    ))
  }

  hgnc_ids <- conn %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::arrange(entity_id) %>%
    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
    dplyr::select(hgnc_id) %>%
    dplyr::collect() %>%
    unique() %>%
    dplyr::pull(hgnc_id)

  if (length(hgnc_ids) < 2L) {
    stop_for_bad_request(sprintf(
      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
      paste(selector, collapse = ","), length(hgnc_ids)
    ))
  }
  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
}

# Module-level (survives across requests within the same process) cache for
# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
# public tables and changes rarely (only when the snapshot builder's source
# view moves), so a short-TTL process cache avoids paying that cost on every
# clustering submit while still self-refreshing.
.clustering_source_data_version_cache <- new.env(parent = emptyenv())

#' Predicate: is `v` a valid source-data-version value?
#'
#' The fail-closed contract requires a single non-NA, non-empty character
#' scalar. Anything else (`NULL`, `NA_character_`, `""`, a non-character
#' value, or a non-scalar) must never be cached or served as provenance
#' (Codex review fix -- the TTL cache previously cached/returned an invalid
#' underlying value verbatim).
.clustering_valid_source_version <- function(v) {
  is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
}

#' Cached, fail-closed read of the current analysis source-data version.
#'
#' D2 (#574) provenance helper: the clustering submit service calls this
#' AFTER admission/dedup, only when it is actually about to build a durable
#' payload. Refetches once `ttl_seconds` has elapsed since the last
#' successful read. Deliberately does NOT wrap
#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
#' PROPAGATES to the caller (never cached, never coerced to NA), so a
#' transient DB problem fails the submit closed (503) instead of recording
#' broken provenance. The fetched value is additionally validated by
#' `.clustering_valid_source_version()`: an invalid value (NA/empty/
#' non-scalar) is likewise NEVER cached or returned -- it `stop()`s instead,
#' so the caller's `tryCatch` maps it to the same 503 PROVENANCE_UNAVAILABLE
#' path as a hard fetch error.
#'
#' @param conn DB connection/pool. Defaults to the package-global `pool`.
#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
#' @return character(1) source data version.
#' @export
clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
  now <- Sys.time()
  cached_at <- .clustering_source_data_version_cache$cached_at
  cached_value <- .clustering_source_data_version_cache$value
  if (!is.null(cached_at) && .clustering_valid_source_version(cached_value) &&
        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
    return(cached_value)
  }

  value <- analysis_snapshot_source_data_version(conn = conn)

  if (!.clustering_valid_source_version(value)) {
    stop(
      "clustering_cached_source_data_version: analysis_snapshot_source_data_version() ",
      "returned an invalid (NULL/NA/empty/non-scalar) value; refusing to cache or serve it"
    )
  }

  .clustering_source_data_version_cache$value <- value
  .clustering_source_data_version_cache$cached_at <- now
  value
}

# Assemble the clustering result `meta`: base fields + the cheap-path provenance
# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
# observed post-compute. Shared by the cache-hit path
# (job-functional-submission-service.R) and the worker-run/durable handler
# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
# shapes cannot drift apart by hand-copied edits.
clustering_result_meta <- function(base, provenance, weight_channel) {
  c(base,
    if (!is.null(provenance)) provenance else list(),
    list(effective_fingerprint = list(weight_channel = weight_channel)))
}
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
#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
#' curated-category selection via `category_filter` (resolved through
#' `clustering_resolve_category_universe()`), or -- when neither is supplied
#' -- the existing default all-NDD-genes universe. `genes` and
#' `category_filter` are mutually exclusive (400 if both are present). Every
#' submit records selector + fingerprint provenance in the durable payload
#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
#'
#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
#'   `category_filter` and `req$user$user_id`).
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

  # Connection objects cannot cross process boundaries. `genes` and
  # `category_filter` are mutually exclusive gene-universe selectors (#574):
  # an explicit gene list, a curated-category selection, or (both absent) the
  # existing default all-NDD-genes universe.
  genes_in <- req$argsBody$genes
  has_genes <- !is.null(genes_in) && length(genes_in) > 0

  # Selector presence is gated on JSON KEY PRESENCE (`names(req$argsBody)`), not
  # value-nullness or length: `!is.null()` cannot distinguish an ABSENT key from
  # an explicit JSON `null` (both parse to NULL in R). So a present `genes` key
  # (`{"genes":null,...}` / `{"genes":[],...}`) and a present `category_filter`
  # key each drive their guard regardless of value (Codex rounds 2 & 4). Mutual
  # exclusion 400s when BOTH keys are present; a present-but-null/empty
  # `category_filter` is a supplied-empty 400 (in the branch below), never a
  # silent fall-through to the all-NDD default. `has_genes` (value-based,
  # non-empty) still selects the explicit-genes branch.
  body_names <- names(req$argsBody)
  genes_key <- "genes" %in% body_names
  category_key <- "category_filter" %in% body_names

  if (genes_key && category_key) {
    stop_for_bad_request("Provide either genes or category_filter, not both")
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

  # Resolve the clustering gene universe + selector provenance (#574). The
  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
  # from before this feature: `clustering_resolve_category_universe(NULL)`
  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
  # so cache parity (memoise key = gene set + algorithm) is preserved.
  selector_chr <- NULL
  if (has_genes) {
    genes_list <- as.character(unlist(genes_in))
    kind <- "explicit"
  } else if (category_key) {
    # A present category_filter key means a category run. A present-but-null
    # value is supplied-but-empty (the resolver 400s on []/[""], but a NULL would
    # otherwise hit its absent->default branch), so reject it explicitly here.
    if (is.null(req$argsBody$category_filter)) {
      stop_for_bad_request(
        "category_filter was supplied but empty; provide at least one active category"
      )
    }
    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
    genes_list <- universe$hgnc_ids
    selector_chr <- universe$selector
    kind <- "category"
  } else {
    universe <- clustering_resolve_category_universe(NULL)
    genes_list <- universe$hgnc_ids
    kind <- "all_ndd"
  }

  # Pre-fetch the STRING ID table because DB connections cannot cross the
  # durable worker boundary.
  string_id_table <- pool %>%
    dplyr::tbl("non_alt_loci_set") %>%
    dplyr::filter(!is.na(STRING_id)) %>%
    dplyr::select(symbol, hgnc_id, STRING_id) %>%
    dplyr::collect()

  # Check for duplicate job (include algorithm in check). The selector is
  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
  # submits keep the pre-#574 dedup identity byte-identical.
  dup_params <- list(genes = genes_list, algorithm = algorithm)
  if (!is.null(selector_chr)) {
    dup_params$category_filter <- selector_chr
  }
  dup_check <- check_duplicate_job("clustering", dup_params)
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

  # Cheap-path provenance (no expensive query yet). `selector_obj` records
  # WHICH universe was resolved; `intended_fingerprint` records the STRING
  # cache identity + fixed clustering params this submit intends to run
  # with. The *effective* fingerprint (e.g. the STRING weight channel a
  # computed result actually used) is only knowable from a computed result,
  # so it is recorded separately in the cache-hit result meta below.
  selector_obj <- list(kind = kind, category_filter = selector_chr)
  intended_fingerprint <- list(
    string_cache_fingerprint = analysis_string_cache_fingerprint(),
    score_threshold = 400L,
    algorithm = algorithm,
    seed = 42L
  )
  gene_sha <- clustering_gene_list_sha256(genes_list)
  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
  # count must agree with it, so it is computed from the SAME dedup -- an
  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
  # not report a resolved count that disagrees with a singleton sha256. This
  # never dedups the payload `genes` list itself (`genes_list` stays
  # byte-identical to the raw request) -- only the reported COUNT (Codex
  # review fix).
  resolved_count <- length(unique(genes_list))

  # Source-data version: a CACHED, fail-closed read, fetched only now that a
  # payload is actually about to be built -- its backing view runs global
  # counts/joins, so it must never run before admission/dedup. A lookup
  # failure must never silently record NA/broken provenance; fail the
  # request closed instead.
  src_ver <- tryCatch(
    clustering_cached_source_data_version(conn = pool),
    error = function(e) e
  )
  if (inherits(src_ver, "error")) {
    res$status <- 503L
    return(list(
      error = "PROVENANCE_UNAVAILABLE",
      message = "Snapshot source-data version unavailable; retry shortly."
    ))
  }

  provenance <- list(
    selector = selector_obj,
    resolved_gene_count = resolved_count,
    gene_list_sha256 = gene_sha,
    intended_fingerprint = intended_fingerprint,
    source_data_version = src_ver
  )

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

    # Splice the base cache-hit fields with `provenance` (already assembled
    # above as selector/resolved_gene_count/gene_list_sha256/
    # intended_fingerprint/source_data_version) via the shared
    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
    # re-listing the same fields as duplicate literals -- keeps this shape in
    # lockstep with the worker-run handler's result meta by construction.
    # `effective_fingerprint` is only knowable from the computed result
    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
    cache_result <- list(
      clusters = cached_clusters,
      categories = categories,
      meta = clustering_result_meta(
        list(
          algorithm = algorithm,
          gene_count = resolved_count,
          cluster_count = nrow(cached_clusters),
          cache_hit = TRUE
        ),
        provenance,
        attr(cached_clusters, "weight_channel")
      )
    )
    cache_request_payload <- list(
      genes = genes_list,
      algorithm = algorithm,
      category_links = category_links,
      string_id_table = string_id_table,
      provenance = provenance
    )
    if (!is.null(selector_chr)) {
      cache_request_payload$category_filter <- selector_chr
    }
    # Dedup identity EXCLUDES provenance (Codex round 3): `provenance`
    # carries a time-varying `source_data_version` and STRING cache
    # `intended_fingerprint`, so hashing the full payload would make the
    # active-job uniqueness guard admit duplicate concurrent clustering work
    # across a deploy/cache-TTL change and break the byte-identical
    # explicit/no-arg `request_hash` contract predating #574. Removing the
    # `provenance` key preserves the leading `genes, algorithm,
    # category_links, string_id_table[, category_filter]` key order -- it was
    # appended last, so deleting it does not reorder the rest.
    cache_hash_payload <- cache_request_payload
    cache_hash_payload$provenance <- NULL
    completed_job <- async_job_service_store_completed(
      job_type = "clustering",
      request_payload = cache_request_payload,
      result = cache_result,
      submitted_by = req$user$user_id %||% NULL,
      queue_name = "analysis",
      priority = 50L,
      hash_payload = cache_hash_payload
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
  job_params <- list(
    genes = genes_list,
    algorithm = algorithm,
    category_links = category_links,
    string_id_table = string_id_table,
    provenance = provenance
  )
  if (!is.null(selector_chr)) {
    job_params$category_filter <- selector_chr
  }
  # See the cache-hit branch above: dedup identity EXCLUDES provenance so the
  # active-job uniqueness guard is not defeated by its time-varying fields,
  # and explicit/no-arg submits stay byte-identical to pre-#574.
  #
  # `create_job()` carries a deliberately guarded 2-arg contract
  # (`operation`, `params`) -- it cannot take a hash override. This path
  # calls `async_job_service_submit()` directly instead (mirroring the
  # cache-hit branch above, which already calls
  # `async_job_service_store_completed()` directly for the same reason), so
  # `hash_payload` can diverge from the stored `request_payload` without
  # touching `create_job()`'s contract.
  hash_params <- job_params
  hash_params$provenance <- NULL
  submitted <- async_job_service_submit(
    job_type = "clustering",
    request_payload = job_params,
    hash_payload = hash_params,
    submitted_by = req$user$user_id %||% NULL
  )
  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
  res$setHeader("Retry-After", "5")

  list(
    job_id = job_id,
    status = "accepted",
    estimated_seconds = 30,
    status_url = paste0("/api/jobs/", job_id, "/status")
  )
}
## -------------------------------------------------------------------##
# api/bootstrap/load_modules.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Loads every R source file required by the running API into the
# global environment, in the correct order:
#   1. functions/* (repositories, helpers, clients, etc.)
#   2. core/* (security, errors, responses, middleware, filters)
#   3. services/* (transactional orchestration)
#
# Source order matters. Repository functions are loaded BEFORE
# services so that any `svc_`/`service_`-prefixed function in
# services/* can still call the underlying repository helpers.
# (A service that accidentally drops its prefix will shadow the
# repository function — see CLAUDE.md.)
#
# Mirai daemon workers do NOT use this module. They re-source a
# hand-picked subset of functions/* via `everywhere({...})` in
# api/bootstrap/setup_workers.R. Changes here do not automatically
# propagate to workers — update setup_workers.R as well when a
# function file is needed inside a daemon.
## -------------------------------------------------------------------##

#' Source a file into .GlobalEnv with a helpful error if missing.
#'
#' `source(..., local = FALSE)` puts the bindings into the global
#' environment — that is what endpoint files expect at runtime.
#' Top-level `source("...", local = TRUE)` in start_sysndd_api.R
#' previously had the same effect by accident of being at the top
#' level of the script; here we make the intent explicit.
#'
#' @param path Relative path from api/ to the source file.
#' @noRd
.bootstrap_source <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("bootstrap: source file not found: %s", path))
  }
  source(path, local = FALSE)
  invisible(NULL)
}

#' Load the full API source tree into the global environment.
#'
#' This is the explicit, auditable source list that used to live
#' inline in start_sysndd_api.R between the markers
#' `# --- function source list (v11.0) ---` and
#' `# --- end source list ---`.
#'
#' @return A list describing which file groups were loaded (used
#'   for logging / diagnostics). The side effect is that every
#'   listed file is sourced into .GlobalEnv.
#' @export
bootstrap_load_modules <- function() {

  # --- function source list (v11.0) ---
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
    # Category-selected clustering gene-universe resolver (#574). Depends on
    # generate_ndd_hgnc_ids() (analyses-functions.R, above) and
    # stop_for_bad_request() (core/errors.R, sourced after function_files by
    # this same bootstrap_load_modules() call) -- registered before the
    # submission service that will consume it.
    "functions/clustering-gene-universe.R",
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
    "services/entity-service.R",
    "services/entity-creation-service.R",
    "services/entity-rename-service.R",
    "services/review-service.R",
    "services/genereviews-service.R",
    "services/approval-service.R",
    "services/re-review-selection-service.R",
    "services/re-review-service.R",
    "services/re-review-refusal-service.R",
    "services/seo-service.R",
    "services/analysis-snapshot-service.R",
    "services/analysis-snapshot-refresh-service.R",
    "services/analysis-snapshot-release-service.R",
    "services/disease-ontology-mapping-service.R",
    "services/mcp-service.R",
    "services/mcp-analysis-shaping.R",
    "services/mcp-query-service.R",
    "services/mcp-record-service.R",
    "services/mcp-analysis-service.R",
    "services/mcp-analysis-llm-cache-service.R",
    "services/mcp-research-context-service.R",
    "services/mcp-capabilities-service.R",
    "services/mcp-tool-core.R",
    "services/mcp-tool-resources.R",
    "services/mcp-tools.R",
    "services/mcp-tool-analysis-registry.R",
    "services/mcp-tool-registry.R",
    # --- #346 Wave 3: endpoint-delegation services (svc_-prefixed). These are
    # sourced by the API and the durable worker via this shared loader, but are
    # never registered as job handlers or called by worker execution. They only
    # depend on functions/* and the domain services above, so they are appended
    # last (definition order is irrelevant; none call each other at source time).
    "services/publication-query-endpoint-service.R",
    "services/publication-admin-endpoint-service.R",
    "services/user-read-endpoint-service.R",
    "services/user-account-endpoint-service.R",
    "services/user-password-profile-endpoint-service.R",
    "services/user-bulk-endpoint-service.R",
    "services/admin-ontology-endpoint-service.R",
    "services/admin-diagnostics-endpoint-service.R",
    "services/admin-nddscore-endpoint-service.R",
    "services/admin-publication-refresh-endpoint-service.R",
    "services/job-functional-submission-service.R",
    "services/job-phenotype-submission-service.R",
    "services/job-maintenance-submission-service.R",
    "services/job-query-endpoint-service.R",
    "services/re-review-query-endpoint-service.R",
    "services/re-review-workflow-endpoint-service.R",
    "services/entity-read-endpoint-service.R",
    "services/entity-submission-endpoint-service.R",
    "services/statistics-public-endpoint-service.R",
    "services/statistics-admin-endpoint-service.R",
    "services/llm-admin-endpoint-service.R",
    "services/backup-endpoint-service.R"
  )

  for (path in function_files) .bootstrap_source(path)
  for (path in core_files) .bootstrap_source(path)
  for (path in service_files) .bootstrap_source(path)

  list(
    functions = length(function_files),
    core = length(core_files),
    services = length(service_files)
  )
}

exec
/bin/bash -lc 'nl -ba api/functions/clustering-gene-universe.R && nl -ba api/services/job-functional-submission-service.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
    49	  if (length(selector) == 0L) {
    50	    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
    51	  }
    52	
    53	  active <- conn %>%
    54	    dplyr::tbl("ndd_entity_status_categories_list") %>%
    55	    dplyr::filter(is_active == 1) %>%
    56	    dplyr::select(category) %>%
    57	    dplyr::collect() %>%
    58	    dplyr::pull(category)
    59	  unknown <- setdiff(selector, active)
    60	  if (length(unknown) > 0L) {
    61	    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
    62	    stop_for_bad_request(sprintf(
    63	      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
    64	      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
    65	    ))
    66	  }
    67	
    68	  hgnc_ids <- conn %>%
    69	    dplyr::tbl("ndd_entity_view") %>%
    70	    dplyr::arrange(entity_id) %>%
    71	    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
    72	    dplyr::select(hgnc_id) %>%
    73	    dplyr::collect() %>%
    74	    unique() %>%
    75	    dplyr::pull(hgnc_id)
    76	
    77	  if (length(hgnc_ids) < 2L) {
    78	    stop_for_bad_request(sprintf(
    79	      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
    80	      paste(selector, collapse = ","), length(hgnc_ids)
    81	    ))
    82	  }
    83	  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
    84	}
    85	
    86	# Module-level (survives across requests within the same process) cache for
    87	# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
    88	# public tables and changes rarely (only when the snapshot builder's source
    89	# view moves), so a short-TTL process cache avoids paying that cost on every
    90	# clustering submit while still self-refreshing.
    91	.clustering_source_data_version_cache <- new.env(parent = emptyenv())
    92	
    93	#' Predicate: is `v` a valid source-data-version value?
    94	#'
    95	#' The fail-closed contract requires a single non-NA, non-empty character
    96	#' scalar. Anything else (`NULL`, `NA_character_`, `""`, a non-character
    97	#' value, or a non-scalar) must never be cached or served as provenance
    98	#' (Codex review fix -- the TTL cache previously cached/returned an invalid
    99	#' underlying value verbatim).
   100	.clustering_valid_source_version <- function(v) {
   101	  is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
   102	}
   103	
   104	#' Cached, fail-closed read of the current analysis source-data version.
   105	#'
   106	#' D2 (#574) provenance helper: the clustering submit service calls this
   107	#' AFTER admission/dedup, only when it is actually about to build a durable
   108	#' payload. Refetches once `ttl_seconds` has elapsed since the last
   109	#' successful read. Deliberately does NOT wrap
   110	#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
   111	#' PROPAGATES to the caller (never cached, never coerced to NA), so a
   112	#' transient DB problem fails the submit closed (503) instead of recording
   113	#' broken provenance. The fetched value is additionally validated by
   114	#' `.clustering_valid_source_version()`: an invalid value (NA/empty/
   115	#' non-scalar) is likewise NEVER cached or returned -- it `stop()`s instead,
   116	#' so the caller's `tryCatch` maps it to the same 503 PROVENANCE_UNAVAILABLE
   117	#' path as a hard fetch error.
   118	#'
   119	#' @param conn DB connection/pool. Defaults to the package-global `pool`.
   120	#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
   121	#' @return character(1) source data version.
   122	#' @export
   123	clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
   124	  now <- Sys.time()
   125	  cached_at <- .clustering_source_data_version_cache$cached_at
   126	  cached_value <- .clustering_source_data_version_cache$value
   127	  if (!is.null(cached_at) && .clustering_valid_source_version(cached_value) &&
   128	        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
   129	    return(cached_value)
   130	  }
   131	
   132	  value <- analysis_snapshot_source_data_version(conn = conn)
   133	
   134	  if (!.clustering_valid_source_version(value)) {
   135	    stop(
   136	      "clustering_cached_source_data_version: analysis_snapshot_source_data_version() ",
   137	      "returned an invalid (NULL/NA/empty/non-scalar) value; refusing to cache or serve it"
   138	    )
   139	  }
   140	
   141	  .clustering_source_data_version_cache$value <- value
   142	  .clustering_source_data_version_cache$cached_at <- now
   143	  value
   144	}
   145	
   146	# Assemble the clustering result `meta`: base fields + the cheap-path provenance
   147	# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
   148	# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
   149	# observed post-compute. Shared by the cache-hit path
   150	# (job-functional-submission-service.R) and the worker-run/durable handler
   151	# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
   152	# shapes cannot drift apart by hand-copied edits.
   153	clustering_result_meta <- function(base, provenance, weight_channel) {
   154	  c(base,
   155	    if (!is.null(provenance)) provenance else list(),
   156	    list(effective_fingerprint = list(weight_channel = weight_channel)))
   157	}
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
   102	    # value is supplied-but-empty (the resolver 400s on []/[""], but a NULL would
   103	    # otherwise hit its absent->default branch), so reject it explicitly here.
   104	    if (is.null(req$argsBody$category_filter)) {
   105	      stop_for_bad_request(
   106	        "category_filter was supplied but empty; provide at least one active category"
   107	      )
   108	    }
   109	    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
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

exec
/bin/bash -lc "nl -ba api/functions/async-job-service.R | sed -n '1,560p'; nl -ba api/functions/async-job-handlers.R | sed -n '1,430p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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

codex
The three stated prior-round fixes are present in the implementation: key-presence mutual exclusion, a separate hash payload that retains full stored provenance, and the unchanged two-argument `create_job` boundary. I’m now checking the regression coverage and runtime behavior around those exact paths.
exec
/bin/bash -lc "sed -n '1,300p' .agents/skills/sysndd-api-testing/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
---
name: sysndd-api-testing
description: Use when writing, running, or fixing SysNDD R/Plumber API tests (testthat) — including database-writing tests, running a single test inside the API container, mocking external providers, or diagnosing SKIP-vs-PASS, helper-loading, or path-resolution issues
---

# SysNDD API Testing

Use this skill before adding or running R API tests under `api/tests/testthat/`. The suite is large (200+ files) and has non-obvious container, database, and helper conventions. The authoritative helpers are `helper-db.R`, `helper-paths.R`, and `setup.R`.

## Run Lanes

- `make test-api-fast` — fast PR gate (also what `make pre-commit` runs).
- `make test-api` — full suite locally.
- `make ci-local` — closest local mirror of CI (lint + tests with DB). Prefer before handoff.
- Single file (host): `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-foo.R')"`
- Single file (running container): `docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-foo.R')"`

## Container Boundary (the #1 trap)

`api/tests/` is **not** bind-mounted (only `functions/`, `services/`, `endpoints/`, `core/` are). A new or edited test must be copied in or the image rebuilt:

```bash
docker cp api/tests/testthat/test-foo.R sysndd-api-1:/app/tests/testthat/test-foo.R
```

Inside the container the default `sysndd_db_test` config points at a host-published port that the container can't reach, so `skip_if_no_test_db()` **SKIPs**. `get_test_config()` prefers `MYSQL_*` env when `MYSQL_HOST` is set, so pass DB creds to reach the DB service:

```bash
docker exec -e MYSQL_HOST=mysql -e MYSQL_DATABASE=sysndd_db_test \
  -e MYSQL_USER=<u> -e MYSQL_PASSWORD=<p> sysndd-api-1 \
  Rscript -e "testthat::test_file('/app/tests/testthat/test-foo.R')"
```

**SKIP is not PASS.** Read the summary: `[ FAIL 0 | SKIP 1 ]` means the DB test did not run. Only `PASS n` with `SKIP 0` is a real green.

## Patterns

- **Load code under test:** `source_api_file("services/foo-service.R", local = FALSE)` — resolves `/app` in-container via `get_api_dir()`. `helper-*.R` auto-load through `setup.R`.
- **DB-writing tests:** wrap in `with_test_db_transaction({ conn <- getOption(".test_db_con"); ... })` — always rolls back. It calls `skip_if_no_test_db()` for you. See AGENTS.md: prefer this or document why rollback is impossible.
- **Schema setup goes OUTSIDE the transaction.** `CREATE TABLE`/`TRUNCATE` are DDL and auto-commit — they break rollback isolation. Create fixtures on a separate connection first (mirror `ensure_test_user_table()`).
- **`DBI::dbBind()` with `?` placeholders needs `unname(params)`** (named lists fail silently); positional `params = list(x)` is safe.
- **Mock external providers**, not `httr2`: PubMed tests stub `pubmed_esearch_count()` / `pubmed_fetch_xml()`; see `helper-mock-apis.R` and `dittodb`.

## Don't Trip the Static Guards

Behavior changes must not break the guard tests that encode invariants: `test-unit-filter-column-allowlist.R`, `test-unit-endpoint-error-handler.R`, `test-unit-external-budget-guard.R`, `test-unit-cheap-route-isolation.R`, `test-unit-analysis-snapshot-coherence.R`, `test-unit-llm-model-default-guard.R`. If your change makes one fail, the change is likely wrong — not the guard.

## Output

Report which lane you ran and paste the real summary line. Never claim green on a run that only SKIPped.

exec
/bin/bash -lc 'nl -ba api/tests/testthat/test-unit-clustering-gene-universe.R; nl -ba api/tests/testthat/test-unit-job-endpoint-services-category.R; nl -ba api/tests/testthat/test-integration-clustering-category-submit.R; nl -ba api/tests/testthat/test-unit-clustering-handler-meta.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
   240	test_that("supplied-but-empty selector is 400 (NOT the all-NDD default)", {
   241	  e <- .gene_universe_env()
   242	  con <- fake_conn(ev, cats)
   243	  withr::defer(DBI::dbDisconnect(con))
   244	
   245	  expect_error(e$clustering_resolve_category_universe(list(), conn = con), class = "error_400")
   246	  expect_error(e$clustering_resolve_category_universe(list("   "), conn = con), class = "error_400")
   247	})
   248	
   249	test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job)", {
   250	  e <- .gene_universe_env()
   251	  con <- fake_conn(ev, cats)
   252	  withr::defer(DBI::dbDisconnect(con))
   253	
   254	  expect_error(e$clustering_resolve_category_universe("Refuted", conn = con), class = "error_400") # 0 genes
   255	  expect_error(e$clustering_resolve_category_universe("Moderate", conn = con), class = "error_400") # 1 gene
   256	})
   257	
   258	test_that("gene_list_sha256 is sort-order independent", {
   259	  e <- .gene_universe_env()
   260	
   261	  expect_identical(
   262	    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
   263	    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
   264	  )
   265	})
   266	
   267	test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
   268	  e <- .gene_universe_env()
   269	
   270	  expect_null(e$clustering_normalize_category_filter(NULL))
   271	  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
   272	  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
   273	  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
   274	  expect_identical(
   275	    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
   276	    c("Definitive", "Moderate")
   277	  )
   278	})
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
   159	test_that("functional clustering: an explicit-null category_filter KEY (no genes) is supplied-but-empty -> error_400 (Codex round-4 review fix)", {
   160	  # Bug: the branch used `category_supplied <- !is.null(category_filter)`, so a
   161	  # present-but-null `category_filter` key (`{"category_filter":null}`) was
   162	  # treated as ABSENT and silently resolved the all-NDD default instead of the
   163	  # required supplied-empty 400 -- the category-side symmetry of the genes-null
   164	  # fix. The branch now keys off `"category_filter" %in% names(req$argsBody)`
   165	  # and rejects a NULL value explicitly. `list(category_filter = NULL)` KEEPS
   166	  # the name (verified: "category_filter" %in% names(list(category_filter = NULL))).
   167	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   168	  source_api_file("core/errors.R", local = FALSE, envir = env)
   169	  env$pool <- job_endpoint_functional_pool(env)
   170	  req <- list(
   171	    argsBody = list(category_filter = NULL),
   172	    user = list(user_id = NULL)
   173	  )
   174	  res <- job_endpoint_fake_res()
   175	
   176	  expect_true("category_filter" %in% names(req$argsBody))
   177	  expect_error(
   178	    env$svc_job_submit_functional_clustering(req, res),
   179	    class = "error_400"
   180	  )
   181	})
   182	
   183	test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
   184	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   185	  env$pool <- job_endpoint_functional_pool(env)
   186	  job_endpoint_stub_clustering_provenance(env)
   187	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
   188	    expect_identical(category_filter, list("Definitive"))
   189	    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
   190	  }
   191	  env$check_duplicate_job <- function(operation, params) {
   192	    expect_true("category_filter" %in% names(params))
   193	    expect_identical(params$category_filter, "Definitive")
   194	    list(duplicate = FALSE)
   195	  }
   196	  env$async_job_capacity_exceeded <- function(...) FALSE
   197	  env$async_job_active_count <- function(...) 0L
   198	  captured <- NULL
   199	  captured_hash_params <- NULL
   200	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   201	                                            submitted_by = NULL, ...) {
   202	    captured <<- request_payload
   203	    captured_hash_params <<- hash_payload
   204	    list(job = tibble::tibble(job_id = "j1"))
   205	  }
   206	  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
   207	  res <- job_endpoint_fake_res()
   208	
   209	  out <- env$svc_job_submit_functional_clustering(req, res)
   210	
   211	  expect_equal(res$status, 202)
   212	  expect_identical(captured$category_filter, "Definitive")
   213	  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
   214	  expect_identical(captured$provenance$selector$kind, "category")
   215	  expect_identical(captured$provenance$selector$category_filter, "Definitive")
   216	  expect_true(all(
   217	    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
   218	      names(captured$provenance)
   219	  ))
   220	
   221	  # Codex round-3 fix: a category run's hash payload keeps `category_filter`
   222	  # (selector-aware dedup) but still excludes `provenance`.
   223	  expect_true("category_filter" %in% names(captured_hash_params))
   224	  expect_identical(captured_hash_params$category_filter, "Definitive")
   225	  expect_false("provenance" %in% names(captured_hash_params))
   226	})
   227	
   228	test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
   229	  # Explicit genes.
   230	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   231	  env$pool <- job_endpoint_functional_pool(env)
   232	  job_endpoint_stub_clustering_provenance(env)
   233	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   234	  env$async_job_capacity_exceeded <- function(...) FALSE
   235	  env$async_job_active_count <- function(...) 0L
   236	  captured_explicit <- NULL
   237	  captured_explicit_hash_params <- NULL
   238	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   239	                                            submitted_by = NULL, ...) {
   240	    captured_explicit <<- request_payload
   241	    captured_explicit_hash_params <<- hash_payload
   242	    list(job = tibble::tibble(job_id = "j2"))
   243	  }
   244	  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   245	  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
   246	
   247	  expect_false("category_filter" %in% names(captured_explicit))
   248	  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
   249	  expect_null(captured_explicit$provenance$selector$category_filter)
   250	  expect_false("provenance" %in% names(captured_explicit_hash_params))
   251	  expect_false("category_filter" %in% names(captured_explicit_hash_params))
   252	
   253	  # No-arg (all-NDD default).
   254	  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
   255	  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
   256	    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
   257	  ))
   258	  job_endpoint_stub_clustering_provenance(env2)
   259	  job_endpoint_stub_all_ndd_universe(env2)
   260	  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
   261	  env2$async_job_capacity_exceeded <- function(...) FALSE
   262	  env2$async_job_active_count <- function(...) 0L
   263	  captured_no_arg <- NULL
   264	  captured_no_arg_hash_params <- NULL
   265	  env2$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   266	                                             submitted_by = NULL, ...) {
   267	    captured_no_arg <<- request_payload
   268	    captured_no_arg_hash_params <<- hash_payload
   269	    list(job = tibble::tibble(job_id = "j3"))
   270	  }
   271	  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
   272	  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
   273	
   274	  expect_false("category_filter" %in% names(captured_no_arg))
   275	  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
   276	  expect_null(captured_no_arg$provenance$selector$category_filter)
   277	  expect_false("provenance" %in% names(captured_no_arg_hash_params))
   278	  expect_false("category_filter" %in% names(captured_no_arg_hash_params))
   279	})
   280	
   281	test_that("functional clustering: two explicit submits with different provenance source_data_version produce the SAME hash_params (Codex round 3)", {
   282	  # The whole point of the fix: `source_data_version` (and the STRING cache
   283	  # fingerprint) are time-varying provenance fields, so two otherwise-
   284	  # identical submits observed at different moments (e.g. across a snapshot
   285	  # refresh / deploy) must resolve to the IDENTICAL dedup identity -- only the
   286	  # STORED payload (`provenance`) is allowed to differ.
   287	  submit_and_capture <- function(source_data_version) {
   288	    env <- job_endpoint_source_service("job-functional-submission-service.R")
   289	    env$pool <- job_endpoint_functional_pool(env)
   290	    env$analysis_string_cache_fingerprint <- function() "fp-test"
   291	    env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
   292	    env$clustering_cached_source_data_version <- function(...) source_data_version
   293	    env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   294	    env$async_job_capacity_exceeded <- function(...) FALSE
   295	    env$async_job_active_count <- function(...) 0L
   296	    captured_hash_params <- NULL
   297	    captured_provenance <- NULL
   298	    env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   299	                                              submitted_by = NULL, ...) {
   300	      captured_hash_params <<- hash_payload
   301	      captured_provenance <<- request_payload$provenance
   302	      list(job = tibble::tibble(job_id = "j-provenance"))
   303	    }
   304	    req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   305	    env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
   306	    list(hash_params = captured_hash_params, provenance = captured_provenance)
   307	  }
   308	
   309	  run_a <- submit_and_capture("2026-01-01T00:00:00Z")
   310	  run_b <- submit_and_capture("2026-07-18T00:00:00Z")
   311	
   312	  # Different STORED provenance...
   313	  expect_false(identical(run_a$provenance$source_data_version, run_b$provenance$source_data_version))
   314	  # ...but IDENTICAL dedup hash payload (provenance excluded).
   315	  expect_identical(run_a$hash_params, run_b$hash_params)
   316	})
   317	
   318	test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
   319	  # `gene_list_sha256` hashes sort(unique(...)), so `resolved_gene_count` must
   320	  # be computed the same way -- otherwise a duplicate-gene payload
   321	  # (`["HGNC:1","HGNC:1"]`) reports resolved_gene_count=2 alongside a
   322	  # singleton sha256. The payload `genes` list itself must stay
   323	  # byte-identical to the raw request (never deduped) -- only the COUNT
   324	  # field changes.
   325	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   326	  env$pool <- job_endpoint_functional_pool(env)
   327	  job_endpoint_stub_clustering_provenance(env)
   328	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   329	  env$async_job_capacity_exceeded <- function(...) FALSE
   330	  env$async_job_active_count <- function(...) 0L
   331	  captured <- NULL
   332	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   333	                                            submitted_by = NULL, ...) {
   334	    captured <<- request_payload
   335	    list(job = tibble::tibble(job_id = "j-dup-genes"))
   336	  }
   337	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
   338	  res <- job_endpoint_fake_res()
   339	
   340	  env$svc_job_submit_functional_clustering(req, res)
   341	
   342	  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
   343	  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
   344	})
   345	
   346	test_that("functional clustering: request_hash is selector-aware for category_filter", {
   347	  # Pure-function coverage of the underlying dedup identity: sourced directly
   348	  # (not via the service env) since these are free functions in
   349	  # functions/async-job-service.R, not bare globals the service references.
   350	  hash_env <- new.env(parent = globalenv())
   351	  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)
   352	
   353	  h <- function(genes, algo, cf) {
   354	    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
   355	    hash_env$async_job_service_request_hash(
   356	      "clustering",
   357	      hash_env$async_job_service_payload_json(payload)
   358	    )
   359	  }
   360	  g <- c("HGNC:1", "HGNC:5")
   361	
   362	  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
   363	  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
   364	  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
   365	})
   366	
   367	test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
   368	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   369	  env$pool <- job_endpoint_functional_pool(env)
   370	  env$analysis_string_cache_fingerprint <- function() "fp-test"
   371	  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
   372	  env$clustering_cached_source_data_version <- function(...) stop("boom")
   373	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   374	  submit_called <- FALSE
   375	  env$async_job_service_submit <- function(...) {
   376	    submit_called <<- TRUE
   377	    NULL
   378	  }
   379	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   380	  res <- job_endpoint_fake_res()
   381	
   382	  out <- env$svc_job_submit_functional_clustering(req, res)
   383	
   384	  expect_equal(res$status, 503L)
   385	  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   386	  expect_false(submit_called)
   387	})
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

exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-job-endpoint-services-category.R | sed -n '1,410p'; nl -ba api/tests/testthat/job-endpoint-services-fixtures.R | sed -n '1,130p'; nl -ba api/tests/testthat/test-unit-async-job-service.R | sed -n '1,100p'; nl -ba api/tests/testthat/test-unit-async-job-handlers.R | sed -n '1,80p'; nl -ba api/tests/testthat/test-unit-async-job-worker.R | sed -n '1,80p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
   159	test_that("functional clustering: an explicit-null category_filter KEY (no genes) is supplied-but-empty -> error_400 (Codex round-4 review fix)", {
   160	  # Bug: the branch used `category_supplied <- !is.null(category_filter)`, so a
   161	  # present-but-null `category_filter` key (`{"category_filter":null}`) was
   162	  # treated as ABSENT and silently resolved the all-NDD default instead of the
   163	  # required supplied-empty 400 -- the category-side symmetry of the genes-null
   164	  # fix. The branch now keys off `"category_filter" %in% names(req$argsBody)`
   165	  # and rejects a NULL value explicitly. `list(category_filter = NULL)` KEEPS
   166	  # the name (verified: "category_filter" %in% names(list(category_filter = NULL))).
   167	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   168	  source_api_file("core/errors.R", local = FALSE, envir = env)
   169	  env$pool <- job_endpoint_functional_pool(env)
   170	  req <- list(
   171	    argsBody = list(category_filter = NULL),
   172	    user = list(user_id = NULL)
   173	  )
   174	  res <- job_endpoint_fake_res()
   175	
   176	  expect_true("category_filter" %in% names(req$argsBody))
   177	  expect_error(
   178	    env$svc_job_submit_functional_clustering(req, res),
   179	    class = "error_400"
   180	  )
   181	})
   182	
   183	test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
   184	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   185	  env$pool <- job_endpoint_functional_pool(env)
   186	  job_endpoint_stub_clustering_provenance(env)
   187	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
   188	    expect_identical(category_filter, list("Definitive"))
   189	    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
   190	  }
   191	  env$check_duplicate_job <- function(operation, params) {
   192	    expect_true("category_filter" %in% names(params))
   193	    expect_identical(params$category_filter, "Definitive")
   194	    list(duplicate = FALSE)
   195	  }
   196	  env$async_job_capacity_exceeded <- function(...) FALSE
   197	  env$async_job_active_count <- function(...) 0L
   198	  captured <- NULL
   199	  captured_hash_params <- NULL
   200	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   201	                                            submitted_by = NULL, ...) {
   202	    captured <<- request_payload
   203	    captured_hash_params <<- hash_payload
   204	    list(job = tibble::tibble(job_id = "j1"))
   205	  }
   206	  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
   207	  res <- job_endpoint_fake_res()
   208	
   209	  out <- env$svc_job_submit_functional_clustering(req, res)
   210	
   211	  expect_equal(res$status, 202)
   212	  expect_identical(captured$category_filter, "Definitive")
   213	  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
   214	  expect_identical(captured$provenance$selector$kind, "category")
   215	  expect_identical(captured$provenance$selector$category_filter, "Definitive")
   216	  expect_true(all(
   217	    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
   218	      names(captured$provenance)
   219	  ))
   220	
   221	  # Codex round-3 fix: a category run's hash payload keeps `category_filter`
   222	  # (selector-aware dedup) but still excludes `provenance`.
   223	  expect_true("category_filter" %in% names(captured_hash_params))
   224	  expect_identical(captured_hash_params$category_filter, "Definitive")
   225	  expect_false("provenance" %in% names(captured_hash_params))
   226	})
   227	
   228	test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
   229	  # Explicit genes.
   230	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   231	  env$pool <- job_endpoint_functional_pool(env)
   232	  job_endpoint_stub_clustering_provenance(env)
   233	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   234	  env$async_job_capacity_exceeded <- function(...) FALSE
   235	  env$async_job_active_count <- function(...) 0L
   236	  captured_explicit <- NULL
   237	  captured_explicit_hash_params <- NULL
   238	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   239	                                            submitted_by = NULL, ...) {
   240	    captured_explicit <<- request_payload
   241	    captured_explicit_hash_params <<- hash_payload
   242	    list(job = tibble::tibble(job_id = "j2"))
   243	  }
   244	  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   245	  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
   246	
   247	  expect_false("category_filter" %in% names(captured_explicit))
   248	  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
   249	  expect_null(captured_explicit$provenance$selector$category_filter)
   250	  expect_false("provenance" %in% names(captured_explicit_hash_params))
   251	  expect_false("category_filter" %in% names(captured_explicit_hash_params))
   252	
   253	  # No-arg (all-NDD default).
   254	  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
   255	  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
   256	    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
   257	  ))
   258	  job_endpoint_stub_clustering_provenance(env2)
   259	  job_endpoint_stub_all_ndd_universe(env2)
   260	  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
   261	  env2$async_job_capacity_exceeded <- function(...) FALSE
   262	  env2$async_job_active_count <- function(...) 0L
   263	  captured_no_arg <- NULL
   264	  captured_no_arg_hash_params <- NULL
   265	  env2$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   266	                                             submitted_by = NULL, ...) {
   267	    captured_no_arg <<- request_payload
   268	    captured_no_arg_hash_params <<- hash_payload
   269	    list(job = tibble::tibble(job_id = "j3"))
   270	  }
   271	  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
   272	  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
   273	
   274	  expect_false("category_filter" %in% names(captured_no_arg))
   275	  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
   276	  expect_null(captured_no_arg$provenance$selector$category_filter)
   277	  expect_false("provenance" %in% names(captured_no_arg_hash_params))
   278	  expect_false("category_filter" %in% names(captured_no_arg_hash_params))
   279	})
   280	
   281	test_that("functional clustering: two explicit submits with different provenance source_data_version produce the SAME hash_params (Codex round 3)", {
   282	  # The whole point of the fix: `source_data_version` (and the STRING cache
   283	  # fingerprint) are time-varying provenance fields, so two otherwise-
   284	  # identical submits observed at different moments (e.g. across a snapshot
   285	  # refresh / deploy) must resolve to the IDENTICAL dedup identity -- only the
   286	  # STORED payload (`provenance`) is allowed to differ.
   287	  submit_and_capture <- function(source_data_version) {
   288	    env <- job_endpoint_source_service("job-functional-submission-service.R")
   289	    env$pool <- job_endpoint_functional_pool(env)
   290	    env$analysis_string_cache_fingerprint <- function() "fp-test"
   291	    env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
   292	    env$clustering_cached_source_data_version <- function(...) source_data_version
   293	    env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   294	    env$async_job_capacity_exceeded <- function(...) FALSE
   295	    env$async_job_active_count <- function(...) 0L
   296	    captured_hash_params <- NULL
   297	    captured_provenance <- NULL
   298	    env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   299	                                              submitted_by = NULL, ...) {
   300	      captured_hash_params <<- hash_payload
   301	      captured_provenance <<- request_payload$provenance
   302	      list(job = tibble::tibble(job_id = "j-provenance"))
   303	    }
   304	    req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   305	    env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
   306	    list(hash_params = captured_hash_params, provenance = captured_provenance)
   307	  }
   308	
   309	  run_a <- submit_and_capture("2026-01-01T00:00:00Z")
   310	  run_b <- submit_and_capture("2026-07-18T00:00:00Z")
   311	
   312	  # Different STORED provenance...
   313	  expect_false(identical(run_a$provenance$source_data_version, run_b$provenance$source_data_version))
   314	  # ...but IDENTICAL dedup hash payload (provenance excluded).
   315	  expect_identical(run_a$hash_params, run_b$hash_params)
   316	})
   317	
   318	test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
   319	  # `gene_list_sha256` hashes sort(unique(...)), so `resolved_gene_count` must
   320	  # be computed the same way -- otherwise a duplicate-gene payload
   321	  # (`["HGNC:1","HGNC:1"]`) reports resolved_gene_count=2 alongside a
   322	  # singleton sha256. The payload `genes` list itself must stay
   323	  # byte-identical to the raw request (never deduped) -- only the COUNT
   324	  # field changes.
   325	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   326	  env$pool <- job_endpoint_functional_pool(env)
   327	  job_endpoint_stub_clustering_provenance(env)
   328	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   329	  env$async_job_capacity_exceeded <- function(...) FALSE
   330	  env$async_job_active_count <- function(...) 0L
   331	  captured <- NULL
   332	  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
   333	                                            submitted_by = NULL, ...) {
   334	    captured <<- request_payload
   335	    list(job = tibble::tibble(job_id = "j-dup-genes"))
   336	  }
   337	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
   338	  res <- job_endpoint_fake_res()
   339	
   340	  env$svc_job_submit_functional_clustering(req, res)
   341	
   342	  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
   343	  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
   344	})
   345	
   346	test_that("functional clustering: request_hash is selector-aware for category_filter", {
   347	  # Pure-function coverage of the underlying dedup identity: sourced directly
   348	  # (not via the service env) since these are free functions in
   349	  # functions/async-job-service.R, not bare globals the service references.
   350	  hash_env <- new.env(parent = globalenv())
   351	  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)
   352	
   353	  h <- function(genes, algo, cf) {
   354	    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
   355	    hash_env$async_job_service_request_hash(
   356	      "clustering",
   357	      hash_env$async_job_service_payload_json(payload)
   358	    )
   359	  }
   360	  g <- c("HGNC:1", "HGNC:5")
   361	
   362	  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
   363	  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
   364	  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
   365	})
   366	
   367	test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
   368	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   369	  env$pool <- job_endpoint_functional_pool(env)
   370	  env$analysis_string_cache_fingerprint <- function() "fp-test"
   371	  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
   372	  env$clustering_cached_source_data_version <- function(...) stop("boom")
   373	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   374	  submit_called <- FALSE
   375	  env$async_job_service_submit <- function(...) {
   376	    submit_called <<- TRUE
   377	    NULL
   378	  }
   379	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   380	  res <- job_endpoint_fake_res()
   381	
   382	  out <- env$svc_job_submit_functional_clustering(req, res)
   383	
   384	  expect_equal(res$status, 503L)
   385	  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   386	  expect_false(submit_called)
   387	})
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
    19	    # .async_job_run_clustering assembles its result meta via clustering_result_meta()
    20	    # (#574); source it before async-job-handlers.R as load_modules.R does in production.
    21	    file.path(api_dir, "functions", "clustering-gene-universe.R"),
    22	    file.path(api_dir, "functions", "async-job-handlers.R"),
    23	    file.path(api_dir, "functions", "async-job-worker.R"),
    24	    file.path(api_dir, "functions", "job-progress.R")
    25	  )
    26	}
    27	
    28	load_async_job_worker_runtime <- function() {
    29	  runtime_env <- new.env(parent = globalenv())
    30	  runtime_paths <- async_job_worker_runtime_paths()
    31	
    32	  missing <- runtime_paths[!file.exists(runtime_paths)]
    33	  if (length(missing) > 0) {
    34	    stop(
    35	      "async-job worker runtime files are missing: ",
    36	      paste(basename(missing), collapse = ", ")
    37	    )
    38	  }
    39	
    40	  for (path in runtime_paths) {
    41	    sys.source(path, envir = runtime_env)
    42	  }
    43	
    44	  runtime_env
    45	}
    46	
    47	test_that("async_job_worker_config_from_env reads bounded worker settings", {
    48	  runtime <- load_async_job_worker_runtime()
    49	
    50	  withr::local_envvar(c(
    51	    ASYNC_JOB_LEASE_SECONDS = "75",
    52	    ASYNC_JOB_RUN_LEASE_SECONDS = "600",
    53	    ASYNC_JOB_IDLE_SLEEP_SECONDS = "1.5",
    54	    MAX_JOBS_PER_WORKER = "7",
    55	    MAX_WORKER_LIFETIME = "900",
    56	    ASYNC_JOB_QUEUES = "default,bulk",
    57	    ASYNC_JOB_DRAIN_FILE = "/tmp/sysndd-test-drain"
    58	  ))
    59	
    60	  config <- runtime$async_job_worker_config_from_env()
    61	
    62	  expect_true(is.character(config$worker_id))
    63	  expect_true(nzchar(config$worker_id))
    64	  expect_true(is.character(config$hostname))
    65	  expect_true(nzchar(config$hostname))
    66	  expect_equal(config$lease_seconds, 75L)
    67	  expect_equal(config$job_run_lease_seconds, 600L)
    68	  expect_equal(config$idle_sleep_seconds, 1.5)
    69	  expect_equal(config$max_jobs_per_worker, 7L)
    70	  expect_equal(config$max_worker_lifetime_seconds, 900L)
    71	  expect_equal(config$queues, c("default", "bulk"))
    72	  expect_equal(config$drain_file, "/tmp/sysndd-test-drain")
    73	})
    74	
    75	test_that("create_async_job_progress_reporter updates durable row progress and throttles interim writes", {
    76	  runtime <- load_async_job_worker_runtime()
    77	  calls <- list()
    78	  heartbeat_calls <- list()
    79	
    80	  runtime$async_job_repository_update_progress <- function(job_id, progress_pct = NULL, progress_message = NULL, claim_token, conn = NULL) { # nolint: line_length_linter

exec
/bin/bash -lc "git show origin/master:api/endpoints/jobs_endpoints.R | nl -ba | sed -n '1,190p'; git show origin/master:api/functions/async-job-service.R | nl -ba | sed -n '195,355p'; git diff --unified=80 origin/master...HEAD -- api/services/job-functional-submission-service.R api/functions/clustering-gene-universe.R api/functions/async-job-service.R api/functions/async-job-handlers.R api/bootstrap/load_modules.R api/endpoints/jobs_endpoints.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
    27	#* Submits an async job to compute functional clustering via STRING-db.
    28	#* Returns immediately with job ID for status polling.
    29	#*
    30	#* @tag jobs
    31	#* @serializer json list(na="string")
    32	#* @post /clustering/submit
    33	function(req, res) {
    34	  svc_job_submit_functional_clustering(req, res)
    35	}
    36	
    37	## -------------------------------------------------------------------##
    38	## Phenotype Clustering Submission
    39	## -------------------------------------------------------------------##
    40	
    41	#* Submit Phenotype Clustering Job
    42	#*
    43	#* Submits an async job to compute phenotype clustering via MCA.
    44	#* Returns immediately with job ID for status polling.
    45	#*
    46	#* @tag jobs
    47	#* @serializer json list(na="string")
    48	#* @post /phenotype_clustering/submit
    49	function(req, res) {
    50	  svc_job_submit_phenotype_clustering(req, res)
    51	}
    52	
    53	## -------------------------------------------------------------------##
    54	## Ontology Update Submission
    55	## -------------------------------------------------------------------##
    56	
    57	#* Submit Ontology Update Job
    58	#*
    59	#* Submits an async job to update disease ontology data from MONDO and OMIM sources.
    60	#* Requires Administrator role.
    61	#* Returns immediately with job ID for status polling.
    62	#*
    63	#* @tag jobs
    64	#* @serializer json list(na="string")
    65	#* @post /ontology_update/submit
    66	function(req, res) {
    67	  require_role(req, res, "Administrator")
    68	  svc_job_submit_ontology_update(res)
    69	}
    70	
    71	## -------------------------------------------------------------------##
    72	## HGNC Data Update Submission
    73	## -------------------------------------------------------------------##
    74	
    75	#* Submit HGNC Data Update Job
    76	#*
    77	#* Submits an async job to download and update HGNC gene data.
    78	#* Requires Administrator role.
    79	#* Returns immediately with job ID for status polling.
    80	#*
    81	#* @tag jobs
    82	#* @serializer json list(na="string")
    83	#* @post /hgnc_update/submit
    84	function(req, res) {
    85	  require_role(req, res, "Administrator")
    86	  svc_job_submit_hgnc_update(res)
    87	}
    88	
    89	## -------------------------------------------------------------------##
    90	## Comparisons Data Update Submission
    91	## -------------------------------------------------------------------##
    92	
    93	#* Submit Comparisons Data Update Job
    94	#*
    95	#* Submits an async job to refresh the comparisons data from all external
    96	#* NDD databases (Radboud, Gene2Phenotype, PanelApp, SFARI, Geisinger,
    97	#* OMIM NDD, Orphanet).
    98	#*
    99	#* Requires Administrator role.
   100	#* Returns immediately with job ID for status polling.
   101	#*
   102	#* @tag jobs
   103	#* @serializer json list(na="string")
   104	#* @post /comparisons_update/submit
   105	function(req, res) {
   106	  require_role(req, res, "Administrator")
   107	  svc_job_submit_comparisons_update(res)
   108	}
   109	
   110	## -------------------------------------------------------------------##
   111	## Job History
   112	## -------------------------------------------------------------------##
   113	
   114	#* Get Job History
   115	#*
   116	#* Returns a list of recent jobs for admin review.
   117	#* Requires Administrator role.
   118	#*
   119	#* @tag jobs
   120	#* @serializer json list(na="string")
   121	#* @get /history
   122	function(req, res, limit = 20) {
   123	  require_role(req, res, "Administrator")
   124	  svc_job_get_history(limit)
   125	}
   126	
   127	## -------------------------------------------------------------------##
   128	## Job Status Polling
   129	## -------------------------------------------------------------------##
   130	
   131	#* Get Job Status
   132	#*
   133	#* Poll job status and retrieve results when complete.
   134	#* Returns Retry-After header for running jobs.
   135	#*
   136	#* @tag jobs
   137	#* @serializer json list(na="string", auto_unbox=TRUE)
   138	#* @get /<job_id>/status
   139	function(job_id, result_mode = "summary", req, res) {
   140	  svc_job_get_status(job_id, result_mode, req, res)
   141	}
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
   217	#'
   218	#' @return List containing the stored job row and duplicate/create flags.
   219	#' @export
   220	async_job_service_submit <- function(
   221	  job_type,
   222	  request_payload,
   223	  submitted_by = NULL,
   224	  queue_name = NULL,
   225	  priority = NULL,
   226	  max_attempts = 1L,
   227	  scheduled_at = Sys.time(),
   228	  job_id = uuid::UUIDgenerate(),
   229	  conn = NULL
   230	) {
   231	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   232	  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   233	  # Default the lane + priority from the job type so heavy maintenance jobs never
   234	  # head-of-line block interactive jobs (#486). Explicit overrides are honored.
   235	  if (is.null(queue_name)) {
   236	    queue_name <- async_job_queue_for_type(job_type)
   237	  }
   238	  if (is.null(priority)) {
   239	    priority <- async_job_priority_for_type(job_type)
   240	  }
   241	  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   242	  payload_json <- async_job_service_payload_json(request_payload)
   243	  request_hash <- async_job_service_request_hash(job_type, payload_json)
   244	  submitted_at <- Sys.time()
   245	
   246	  stored_job <- tryCatch(
   247	    {
   248	      async_job_repository_create(
   249	        list(
   250	          job_id = job_id,
   251	          job_type = job_type,
   252	          queue_name = queue_name,
   253	          priority = as.integer(priority),
   254	          request_hash = request_hash,
   255	          request_payload_json = payload_json,
   256	          submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
   257	          submitted_at = submitted_at,
   258	          scheduled_at = scheduled_at,
   259	          max_attempts = as.integer(max_attempts)
   260	        ),
   261	        conn = conn
   262	      )
   263	
   264	      async_job_repository_get(job_id, conn = conn)
   265	    },
   266	    async_job_duplicate_error = function(error) {
   267	      .async_job_service_duplicate_row(error, conn = conn)
   268	    }
   269	  )
   270	
   271	  is_duplicate <- nrow(stored_job) > 0 && !identical(stored_job$job_id[[1]], job_id)
   272	
   273	  list(
   274	    job = stored_job,
   275	    duplicate = is_duplicate,
   276	    created = !is_duplicate
   277	  )
   278	}
   279	
   280	#' Persist an already-completed durable async job row
   281	#'
   282	#' Used for cache-hit fast paths that should still return a normal durable
   283	#' job id without enqueueing worker execution.
   284	#'
   285	#' @param job_type Character durable job type.
   286	#' @param request_payload Named list or JSON payload string.
   287	#' @param result Completed handler result payload.
   288	#' @param submitted_by Optional user id.
   289	#' @param queue_name Character queue name.
   290	#' @param priority Integer queue priority.
   291	#' @param job_id Optional explicit job id.
   292	#' @param submitted_at Optional submission timestamp.
   293	#' @param completed_at Optional completion timestamp.
   294	#' @param conn Optional DB connection or pool.
   295	#'
   296	#' @return Tibble with the stored completed job row.
   297	#' @export
   298	async_job_service_store_completed <- function(
   299	  job_type,
   300	  request_payload,
   301	  result,
   302	  submitted_by = NULL,
   303	  queue_name = "default",
   304	  priority = 100L,
   305	  job_id = uuid::UUIDgenerate(),
   306	  submitted_at = Sys.time(),
   307	  completed_at = submitted_at,
   308	  conn = NULL
   309	) {
   310	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   311	  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   312	  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
   313	  payload_json <- async_job_service_payload_json(request_payload)
   314	  result_json <- async_job_service_payload_json(result)
   315	
   316	  async_job_repository_create(
   317	    list(
   318	      job_id = job_id,
   319	      job_type = job_type,
   320	      queue_name = queue_name,
   321	      priority = as.integer(priority),
   322	      status = "completed",
   323	      request_hash = async_job_service_request_hash(job_type, payload_json),
   324	      request_payload_json = payload_json,
   325	      submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
   326	      submitted_at = submitted_at,
   327	      scheduled_at = submitted_at,
   328	      started_at = submitted_at,
   329	      completed_at = completed_at,
   330	      progress_pct = 100,
   331	      result_json = result_json
   332	    ),
   333	    conn = conn
   334	  )
   335	
   336	  async_job_repository_get(job_id, include_result = TRUE, conn = conn)
   337	}
   338	
   339	#' Find an active duplicate for a durable async job request
   340	#'
   341	#' @param job_type Character durable job type.
   342	#' @param request_payload Named list or JSON payload string.
   343	#' @param conn Optional DB connection or pool.
   344	#'
   345	#' @return Tibble with zero or one active duplicate row.
   346	#' @export
   347	async_job_service_find_duplicate <- function(job_type, request_payload, conn = NULL) {
   348	  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
   349	  payload_json <- async_job_service_payload_json(request_payload)
   350	
   351	  async_job_repository_find_active_duplicate(
   352	    job_type = job_type,
   353	    request_hash = async_job_service_request_hash(job_type, payload_json),
   354	    conn = conn
   355	  )
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
index 00000000..3cace74d
--- /dev/null
+++ b/api/functions/clustering-gene-universe.R
@@ -0,0 +1,157 @@
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
+  if (length(selector) == 0L) {
+    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
+  }
+
+  active <- conn %>%
+    dplyr::tbl("ndd_entity_status_categories_list") %>%
+    dplyr::filter(is_active == 1) %>%
+    dplyr::select(category) %>%
+    dplyr::collect() %>%
+    dplyr::pull(category)
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
+      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
+      paste(selector, collapse = ","), length(hgnc_ids)
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
index 150c61e0..f5ec6768 100644
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
+    # value is supplied-but-empty (the resolver 400s on []/[""], but a NULL would
+    # otherwise hit its absent->default branch), so reject it explicitly here.
+    if (is.null(req$argsBody$category_filter)) {
+      stop_for_bad_request(
+        "category_filter was supplied but empty; provide at least one active category"
+      )
+    }
+    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
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
/bin/bash -lc "rg -n -C 8 '"'^create_job'"\\s*<-|create_job\\s*<-\\s*function|create_job\\(' api/functions/job-manager.R api/tests/testthat/test-unit-job-endpoint-services*.R && git diff origin/master...HEAD -- api/tests/testthat/test-unit-job-endpoint-services.R api/tests/testthat/test-unit-job-endpoint-services-phenotype.R api/tests/testthat/job-endpoint-services-fixtures.R api/tests/testthat/test-unit-async-job-service.R api/tests/testthat/test-unit-async-job-handlers.R api/tests/testthat/test-unit-async-job-worker.R app/package.json app/package-lock.json api/version_spec.json CHANGELOG.md documentation/08-development.qmd AGENTS.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/tests/testthat/test-unit-job-endpoint-services.R-102-  }
api/tests/testthat/test-unit-job-endpoint-services.R-103-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
api/tests/testthat/test-unit-job-endpoint-services.R-104-  store_args <- NULL
api/tests/testthat/test-unit-job-endpoint-services.R-105-  env$async_job_service_store_completed <- function(...) {
api/tests/testthat/test-unit-job-endpoint-services.R-106-    store_args <<- list(...)
api/tests/testthat/test-unit-job-endpoint-services.R-107-    tibble::tibble(job_id = "cached-job-1")
api/tests/testthat/test-unit-job-endpoint-services.R-108-  }
api/tests/testthat/test-unit-job-endpoint-services.R-109-  create_job_called <- FALSE
api/tests/testthat/test-unit-job-endpoint-services.R:110:  env$create_job <- function(...) {
api/tests/testthat/test-unit-job-endpoint-services.R-111-    create_job_called <<- TRUE
api/tests/testthat/test-unit-job-endpoint-services.R-112-  }
api/tests/testthat/test-unit-job-endpoint-services.R-113-  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = 42L))
api/tests/testthat/test-unit-job-endpoint-services.R-114-  res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services.R-115-
api/tests/testthat/test-unit-job-endpoint-services.R-116-  out <- env$svc_job_submit_functional_clustering(req, res)
api/tests/testthat/test-unit-job-endpoint-services.R-117-
api/tests/testthat/test-unit-job-endpoint-services.R-118-  expect_false(create_job_called)
--
api/tests/testthat/test-unit-job-endpoint-services.R-152-  out <- env$svc_job_submit_functional_clustering(req, res)
api/tests/testthat/test-unit-job-endpoint-services.R-153-  expect_equal(res$status, 503)
api/tests/testthat/test-unit-job-endpoint-services.R-154-  expect_equal(res$headers[["Retry-After"]], "60")
api/tests/testthat/test-unit-job-endpoint-services.R-155-  expect_equal(out$error, "CAPACITY_EXCEEDED")
api/tests/testthat/test-unit-job-endpoint-services.R-156-
api/tests/testthat/test-unit-job-endpoint-services.R-157-  env$async_job_capacity_exceeded <- function(...) FALSE
api/tests/testthat/test-unit-job-endpoint-services.R-158-  captured <- NULL
api/tests/testthat/test-unit-job-endpoint-services.R-159-  # Cache-miss path calls `async_job_service_submit()` directly (not
api/tests/testthat/test-unit-job-endpoint-services.R:160:  # `create_job()`, which is arity-guarded at exactly `(operation, params)`)
api/tests/testthat/test-unit-job-endpoint-services.R-161-  # so it can thread a provenance-free `hash_payload` override alongside the
api/tests/testthat/test-unit-job-endpoint-services.R-162-  # full `request_payload`.
api/tests/testthat/test-unit-job-endpoint-services.R-163-  env$async_job_service_submit <- function(job_type, request_payload, hash_payload = NULL,
api/tests/testthat/test-unit-job-endpoint-services.R-164-                                            submitted_by = NULL, ...) {
api/tests/testthat/test-unit-job-endpoint-services.R-165-    captured <<- list(
api/tests/testthat/test-unit-job-endpoint-services.R-166-      job_type = job_type,
api/tests/testthat/test-unit-job-endpoint-services.R-167-      request_payload = request_payload,
api/tests/testthat/test-unit-job-endpoint-services.R-168-      hash_payload = hash_payload
--
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-75-    phenotype_list = tibble::tibble(
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-76-      phenotype_id = c("HP:0000001", "HP:0000002"), HPO_term = c("Term1", "Term2")
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-77-    )
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-78-  ))
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-79-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-80-  env$async_job_capacity_exceeded <- function(...) FALSE
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-81-  env$async_job_active_count <- function(...) 0L
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-82-  captured_params <- NULL
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R:83:  env$create_job <- function(operation, params) {
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-84-    captured_params <<- params
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-85-    list(job_id = "job-x", status = "accepted", estimated_seconds = 30)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-86-  }
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-87-  req <- list(user = list(user_id = NULL))
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-88-  res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-89-
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-90-  env$svc_job_submit_phenotype_clustering(req, res)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-91-
--
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-122-    tibble::tibble(cluster = 1L, identifiers = list(tibble::tibble(entity_id = "1")))
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-123-  }
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-124-  store_args <- NULL
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-125-  env$async_job_service_store_completed <- function(...) {
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-126-    store_args <<- list(...)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-127-    tibble::tibble(job_id = "cached-pheno-1")
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-128-  }
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-129-  create_job_called <- FALSE
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R:130:  env$create_job <- function(...) create_job_called <<- TRUE
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-131-  req <- list(user = list(user_id = 7L))
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-132-  res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-133-
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-134-  out <- env$svc_job_submit_phenotype_clustering(req, res)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-135-
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-136-  expect_false(create_job_called)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-137-  expect_equal(res$status, 202)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-138-  expect_equal(out$job_id, "cached-pheno-1")
--
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-150-  res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-151-  out <- env$svc_job_submit_phenotype_clustering(req, res)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-152-  expect_equal(res$status, 503)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-153-  expect_equal(res$headers[["Retry-After"]], "60")
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-154-  expect_equal(out$error, "CAPACITY_EXCEEDED")
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-155-
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-156-  env$async_job_capacity_exceeded <- function(...) FALSE
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-157-  create_job_params <- NULL
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R:158:  env$create_job <- function(operation, params) {
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-159-    create_job_params <<- params
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-160-    list(job_id = "new-pheno-1", status = "accepted", estimated_seconds = 30)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-161-  }
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-162-  res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-163-  out <- env$svc_job_submit_phenotype_clustering(req, res)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-164-  expect_equal(res$status, 202)
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-165-  expect_equal(res$headers[["Retry-After"]], "5")
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-166-  expect_equal(out$job_id, "new-pheno-1")
--
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-200-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-201-  pool_touched <- FALSE
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-202-  env$pool <- structure(list(), class = "trap_pool")
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-203-  env$tbl.trap_pool <- function(src, from, ...) {
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-204-    pool_touched <<- TRUE
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-205-    stop("DB must not be touched when the throttle blocks")
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-206-  }
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-207-  create_job_called <- FALSE
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R:208:  env$create_job <- function(...) {
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-209-    create_job_called <<- TRUE
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-210-    NULL
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-211-  }
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-212-  env$async_job_submit_admission_guard <- function(req, res) {
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-213-    res$status <- 429
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-214-    res$setHeader("Retry-After", "42")
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-215-    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R-216-  }
--
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-84-  })
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-85-
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-86-  test_that(paste(job_endpoint_spec$op, ": new submit returns 202 with the expected Retry-After"), {
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-87-    env <- job_endpoint_maintenance_env(job_endpoint_spec$needs_pool)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-88-    env$check_duplicate_job <- function(...) list(duplicate = FALSE)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-89-    new_job_id <- paste0(job_endpoint_spec$op, "-1")
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-90-    create_job_operation <- NULL
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-91-    create_job_params <- NULL
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:92:    env$create_job <- function(operation, params) {
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-93-      create_job_operation <<- operation
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-94-      create_job_params <<- params
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-95-      list(job_id = new_job_id, status = "accepted", estimated_seconds = 30)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-96-    }
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-97-
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-98-    out <- {
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-99-      res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-100-      env[[job_endpoint_spec$fn]](res)
--
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-108-    if (is.null(actual_payload_names)) actual_payload_names <- character()
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-109-    expect_setequal(actual_payload_names, job_endpoint_spec$payload_names)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-110-  })
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-111-}
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-112-
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-113-test_that("ontology update: create_job error surfaces as 503 with Retry-After", {
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-114-  env <- job_endpoint_maintenance_env(needs_pool = TRUE)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-115-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:116:  env$create_job <- function(...) list(error = "CAPACITY_EXCEEDED", retry_after = 60)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-117-  res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-118-
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-119-  out <- env$svc_job_submit_ontology_update(res)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-120-
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-121-  expect_equal(res$status, 503)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-122-  expect_equal(res$headers[["Retry-After"]], "60")
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-123-  expect_equal(out$error, "CAPACITY_EXCEEDED")
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R-124-})
--
api/functions/job-manager.R-23-#' @param operation Character string identifying the operation type
api/functions/job-manager.R-24-#'   (e.g., "clustering", "phenotype_clustering", "ontology_update")
api/functions/job-manager.R-25-#' @param params List of payload parameters for the registered handler.
api/functions/job-manager.R-26-#'
api/functions/job-manager.R-27-#' @return List with job_id, status="accepted", and estimated_seconds=30.
api/functions/job-manager.R-28-#'
api/functions/job-manager.R-29-#' @examples
api/functions/job-manager.R-30-#' \dontrun{
api/functions/job-manager.R:31:#' result <- create_job(
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
api/functions/job-manager.R-42-  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL
api/functions/job-manager.R-43-
api/functions/job-manager.R-44-  list(
--
api/functions/job-manager.R-338-  result
api/functions/job-manager.R-339-}
api/functions/job-manager.R-340-
api/functions/job-manager.R-341-## -------------------------------------------------------------------##
api/functions/job-manager.R-342-# Load LLM Batch Generator (AFTER create_job is defined)
api/functions/job-manager.R-343-## -------------------------------------------------------------------##
api/functions/job-manager.R-344-
api/functions/job-manager.R-345-# Load LLM batch generator - must be AFTER create_job definition
api/functions/job-manager.R:346:# because trigger_llm_batch_generation() calls create_job()
api/functions/job-manager.R-347-if (file.exists("functions/llm-batch-generator.R")) {
api/functions/job-manager.R-348-  message("[job-manager] Loading llm-batch-generator.R...")
api/functions/job-manager.R-349-  tryCatch(
api/functions/job-manager.R-350-    {
api/functions/job-manager.R-351-      source("functions/llm-batch-generator.R", local = FALSE)
api/functions/job-manager.R-352-      message("[job-manager] llm-batch-generator.R loaded successfully")
api/functions/job-manager.R-353-      message(
api/functions/job-manager.R-354-        "[job-manager] trigger_llm_batch_generation exists: ",
diff --git a/AGENTS.md b/AGENTS.md
index 7aa9b3e1..e9647c88 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -123,6 +123,8 @@ Analysis-snapshot **releases** are immutable, content-addressed, frozen exports
 - **Build is synchronous, admin, DB-only — the worker is NOT required.** Unlike snapshot refresh, `POST /api/admin/analysis/releases` runs inline on the API request (`analysis_snapshot_release_build()` is called directly from the endpoint, not submitted as an async job): no clustering recompute, no external calls, no LLM, no cache writes. A release can be built even if the worker is down, as long as public-ready snapshots already exist.
 - **`GET .../releases/<release_id>/file?path=<file_path>` uses a query param, not a nested path segment**, because Plumber 1.3.2 has no `<path:.*>` wildcard — only named, typed, single-segment path params (`<id>`, `<id:int>`) exist, so a nested archive path (e.g. `functional_clusters/payload.json`) cannot be expressed as a URL path segment. The manifest's `files[].path` values are the caller's index into this route.
 
+`POST /api/jobs/clustering/submit` can resolve its clustering gene universe from a curated confidence category instead of an explicit gene list (#574). `clustering_resolve_category_universe()` (`api/functions/clustering-gene-universe.R`) does entity-level resolution: a gene qualifies if it has >=1 `ndd_phenotype == 1` entity whose `category` is in the selector, filtered directly against `ndd_entity_view` — **never** `select_network_gene_category()` (the gene-level display-label aggregator used for node coloring only, not a universe filter). `category_filter` absent → the byte-identical existing default (`generate_ndd_hgnc_ids()`, cache parity preserved); supplied-but-empty → 400; validated live against `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded category strings, no interpolated SQL) with the allowed active set named in the error **message**; a resolved universe under 2 genes → 400. `genes` and a non-empty `category_filter` are mutually exclusive (400). The durable job payload gains a normalized `category_filter` key — and the dedup identity becomes selector-aware — **only** for category selectors, so explicit-genes and no-arg submits keep byte-identical `request_hash`/payload shape to pre-#574. Every submit records provenance — `selector` (`kind`: `explicit`|`category`|`all_ndd`), `resolved_gene_count`, `gene_list_sha256`, an **intended** fingerprint (STRING cache fingerprint + score threshold + algorithm + seed), and a cached fail-closed `source_data_version` — in the payload; the result `meta` additionally carries an **effective** `effective_fingerprint` (the STRING `weight_channel` the computed result actually used), on both a cache-hit response (`svc_job_submit_functional_clustering()`) and a worker-run job (`.async_job_run_clustering()` in `async-job-handlers.R`), so a silent exp+db→combined-score fallback is visible either way. Results from this endpoint (category-filtered or not) are ephemeral job results and are **never** `public_ready` — distinct from the public `analysis_snapshot_*` layer above.
+
 ### Cluster-analysis statistical soundness (#508–#512)
 
 The two-axis cluster analysis (phenotype MCA/HCPC and functional STRING/Leiden) and the served "function is modular, phenotype is a continuum" cross-axis interpretation are made mathematically sound and self-reproducing. `validation_schema_version` is `"2.0"`, `ANALYSIS_SNAPSHOT_SCHEMA_VERSION` is `"1.2"`. The **key lever**: `analysis_snapshot_payload_hash` deliberately excludes `partition_validation` (`analysis-snapshot-builder.R`), so everything in the validation block is **additive** — new metrics never change `cluster_hash` and never invalidate LLM summaries. Only changes to cluster **membership** (the #508 MCA filter, the #509 `kk=Inf` consolidation, the #510 channel switch) change `cluster_hash` and therefore require a coordinated forced snapshot refresh + LLM regeneration.
diff --git a/CHANGELOG.md b/CHANGELOG.md
index 48651d8b..d3058047 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -6,6 +6,53 @@ The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
 
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
diff --git a/api/tests/testthat/job-endpoint-services-fixtures.R b/api/tests/testthat/job-endpoint-services-fixtures.R
index 103f4621..03b7df8c 100644
--- a/api/tests/testthat/job-endpoint-services-fixtures.R
+++ b/api/tests/testthat/job-endpoint-services-fixtures.R
@@ -1,10 +1,13 @@
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
@@ -22,9 +25,19 @@ library(tidyr)
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
@@ -35,6 +48,49 @@ job_endpoint_fake_pool <- function(env, tables) {
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
diff --git a/api/tests/testthat/test-unit-async-job-handlers.R b/api/tests/testthat/test-unit-async-job-handlers.R
index 30f63cef..dd50b54d 100644
--- a/api/tests/testthat/test-unit-async-job-handlers.R
+++ b/api/tests/testthat/test-unit-async-job-handlers.R
@@ -2,6 +2,10 @@ library(testthat)
 
 source_api_file("functions/async-job-force-apply-payload.R", local = FALSE)
 source_api_file("functions/async-job-omim-apply.R", local = FALSE)
+# .async_job_run_clustering assembles its result meta via clustering_result_meta()
+# (clustering-gene-universe.R, #574); source it so the handler resolves it here as
+# it does in the worker (bootstrap_load_modules sources it before the handlers).
+source_api_file("functions/clustering-gene-universe.R", local = FALSE)
 # The eagerly-built async_job_handler_registry list() references provider and
 # maintenance handler functions by bare symbol (#346 Wave 4 split), so both
 # extracted modules must be sourced BEFORE async-job-handlers.R or the list()
diff --git a/api/tests/testthat/test-unit-async-job-service.R b/api/tests/testthat/test-unit-async-job-service.R
index 77c3b488..10dedfe6 100644
--- a/api/tests/testthat/test-unit-async-job-service.R
+++ b/api/tests/testthat/test-unit-async-job-service.R
@@ -274,6 +274,68 @@ test_that("async_job_service_submit defaults queue + priority from the job type"
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
diff --git a/api/tests/testthat/test-unit-async-job-worker.R b/api/tests/testthat/test-unit-async-job-worker.R
index 792903e1..237528a0 100644
--- a/api/tests/testthat/test-unit-async-job-worker.R
+++ b/api/tests/testthat/test-unit-async-job-worker.R
@@ -16,6 +16,9 @@ async_job_worker_runtime_paths <- function() {
     # extracted modules must be sourced before async-job-handlers.R here too.
     file.path(api_dir, "functions", "async-job-provider-handlers.R"),
     file.path(api_dir, "functions", "async-job-maintenance-handlers.R"),
+    # .async_job_run_clustering assembles its result meta via clustering_result_meta()
+    # (#574); source it before async-job-handlers.R as load_modules.R does in production.
+    file.path(api_dir, "functions", "clustering-gene-universe.R"),
     file.path(api_dir, "functions", "async-job-handlers.R"),
     file.path(api_dir, "functions", "async-job-worker.R"),
     file.path(api_dir, "functions", "job-progress.R")
diff --git a/api/tests/testthat/test-unit-job-endpoint-services-phenotype.R b/api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
new file mode 100644
index 00000000..e9e69f6b
--- /dev/null
+++ b/api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
@@ -0,0 +1,223 @@
+# tests/testthat/test-unit-job-endpoint-services-phenotype.R
+#
+# Host-runnable unit tests for job-phenotype-submission-service.R, split out of
+# test-unit-job-endpoint-services.R (which covers job-functional-submission-service.R)
+# to keep both files under the 600-line ceiling (#535 S6) after the #574 Codex-review
+# fixes added coverage to the functional side. Shared fixtures live in
+# job-endpoint-services-fixtures.R (explicitly sourced below, mirroring the sibling
+# file). See test-unit-job-endpoint-services.R's header for the full split rationale
+# (maintenance-submission + query-endpoint services are covered in
+# test-unit-job-endpoint-services-maintenance.R).
+#
+# Each service is sourced directly into an isolated environment via sys.source()
+# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
+# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
+# async_job_active_count, async_job_service_store_completed, gen_mca_clust_obj_mem,
+# log_warn, ...) is stubbed in that environment, so the tests exercise pure
+# request/response logic without a live DB or mirai daemon pool.
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
+## job-phenotype-submission-service.R
+## -------------------------------------------------------------------##
+
+job_endpoint_phenotype_single_entity_pool <- function(env) {
+  job_endpoint_fake_pool(env, list(
+    ndd_entity_view = tibble::tibble(
+      entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1",
+      ndd_phenotype = 1L, category = "Definitive"
+    ),
+    ndd_entity_review = tibble::tibble(
+      review_id = 1L, entity_id = 1L, is_primary = 1L, review_approved = 1L
+    ),
+    ndd_review_phenotype_connect = tibble::tibble(
+      review_id = 1L, entity_id = 1L, modifier_id = 1L,
+      phenotype_id = "HP:0000001", hpo_mode_of_inheritance_term_name = "AD"
+    ),
+    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
+    phenotype_list = tibble::tibble(phenotype_id = "HP:0000001", HPO_term = "Term1")
+  ))
+}
+
+test_that("phenotype clustering: review set is gated on is_primary AND review_approved", {
+  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
+  env$pool <- job_endpoint_fake_pool(env, list(
+    ndd_entity_view = tibble::tibble(
+      entity_id = c(1L, 2L), hgnc_id = c("HGNC:1", "HGNC:2"), symbol = c("GENE1", "GENE2"),
+      ndd_phenotype = c(1L, 1L), category = c("Definitive", "Definitive")
+    ),
+    # review_id 1: primary + approved (kept). review_id 2: primary but NOT
+    # approved (must be dropped). review_id 3: approved but NOT primary
+    # (must be dropped) — the #3/Codex-PR-2 guard this test protects.
+    ndd_entity_review = tibble::tibble(
+      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L),
+      is_primary = c(1L, 1L, 0L), review_approved = c(1L, 0L, 1L)
+    ),
+    ndd_review_phenotype_connect = tibble::tibble(
+      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L), modifier_id = c(1L, 1L, 1L),
+      phenotype_id = c("HP:0000001", "HP:0000002", "HP:0000001"),
+      hpo_mode_of_inheritance_term_name = c("AD", "AD", "AD")
+    ),
+    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
+    phenotype_list = tibble::tibble(
+      phenotype_id = c("HP:0000001", "HP:0000002"), HPO_term = c("Term1", "Term2")
+    )
+  ))
+  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  env$async_job_active_count <- function(...) 0L
+  captured_params <- NULL
+  env$create_job <- function(operation, params) {
+    captured_params <<- params
+    list(job_id = "job-x", status = "accepted", estimated_seconds = 30)
+  }
+  req <- list(user = list(user_id = NULL))
+  res <- job_endpoint_fake_res()
+
+  env$svc_job_submit_phenotype_clustering(req, res)
+
+  # Only review_id 1 (primary + approved) survives the gather step; review 2
+  # (unapproved) and review 3 (not primary) must never reach the clustering
+  # input, even though review 2 is attached to the same (otherwise-included)
+  # entity_id as review 1.
+  expect_equal(captured_params$ndd_entity_review_tbl$review_id, 1L)
+})
+
+test_that("phenotype clustering: duplicate job returns 409 with Location", {
+  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
+  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
+  env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = "dup-pheno")
+  req <- list(user = list(user_id = NULL))
+  res <- job_endpoint_fake_res()
+
+  out <- env$svc_job_submit_phenotype_clustering(req, res)
+
+  expect_equal(res$status, 409)
+  expect_equal(out$error, "DUPLICATE_JOB")
+  expect_match(res$headers[["Location"]], "/api/jobs/dup-pheno/status")
+})
+
+test_that("phenotype clustering: cache hit stores a completed job without calling create_job", {
+  local_mocked_bindings(
+    has_cache = function(f) function(...) TRUE,
+    .package = "memoise"
+  )
+  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
+  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
+  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
+  env$gen_mca_clust_obj_mem <- function(df) {
+    tibble::tibble(cluster = 1L, identifiers = list(tibble::tibble(entity_id = "1")))
+  }
+  store_args <- NULL
+  env$async_job_service_store_completed <- function(...) {
+    store_args <<- list(...)
+    tibble::tibble(job_id = "cached-pheno-1")
+  }
+  create_job_called <- FALSE
+  env$create_job <- function(...) create_job_called <<- TRUE
+  req <- list(user = list(user_id = 7L))
+  res <- job_endpoint_fake_res()
+
+  out <- env$svc_job_submit_phenotype_clustering(req, res)
+
+  expect_false(create_job_called)
+  expect_equal(res$status, 202)
+  expect_equal(out$job_id, "cached-pheno-1")
+  expect_equal(store_args$submitted_by, 7L)
+})
+
+test_that("phenotype clustering: capacity guard (503) then a cache miss under capacity (202)", {
+  req <- list(user = list(user_id = NULL))
+
+  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
+  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
+  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
+  env$async_job_capacity_exceeded <- function(...) TRUE
+  env$async_job_active_count <- function(...) 5L
+  res <- job_endpoint_fake_res()
+  out <- env$svc_job_submit_phenotype_clustering(req, res)
+  expect_equal(res$status, 503)
+  expect_equal(res$headers[["Retry-After"]], "60")
+  expect_equal(out$error, "CAPACITY_EXCEEDED")
+
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  create_job_params <- NULL
+  env$create_job <- function(operation, params) {
+    create_job_params <<- params
+    list(job_id = "new-pheno-1", status = "accepted", estimated_seconds = 30)
+  }
+  res <- job_endpoint_fake_res()
+  out <- env$svc_job_submit_phenotype_clustering(req, res)
+  expect_equal(res$status, 202)
+  expect_equal(res$headers[["Retry-After"]], "5")
+  expect_equal(out$job_id, "new-pheno-1")
+  # estimated_seconds is hardcoded to 60 for the new-submit response (matches
+  # the original handler, which does not thread through create_job's value).
+  expect_equal(out$estimated_seconds, 60)
+  expect_setequal(
+    names(create_job_params),
+    c(
+      "ndd_entity_view_tbl", "ndd_entity_review_tbl",
+      "ndd_review_phenotype_connect_tbl", "modifier_list_tbl",
+      "phenotype_list_tbl", "id_phenotype_ids", "categories"
+    )
+  )
+})
+
+test_that("phenotype clustering service source keeps is_primary filters paired with review_approved", {
+  # Defense-in-depth mirror of test-unit-phenotype-clustering-approved-guard.R
+  # (which scans endpoints/jobs_endpoints.R) now that the logic lives here.
+  src <- readLines(file.path(get_api_dir(), "services", "job-phenotype-submission-service.R"), warn = FALSE)
+  body <- paste(src, collapse = "\n")
+  matches <- gregexpr("filter\\([^)]*is_primary[^)]*\\)", body)[[1]]
+  if (matches[1] != -1) {
+    lens <- attr(matches, "match.length")
+    for (i in seq_along(matches)) {
+      frag <- substr(body, matches[i], matches[i] + lens[i] - 1)
+      expect_true(grepl("review_approved", frag),
+                  info = paste("is_primary filter without review_approved:", frag))
+    }
+  }
+  succeed()
+})
+
+test_that("phenotype clustering: admission throttle runs FIRST, before collecting tables", {
+  # #535 S6 BLOCKER fix: the phenotype path otherwise collects five whole tables and
+  # builds the MCA matrix before admission. A blocked caller must touch nothing.
+  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
+  pool_touched <- FALSE
+  env$pool <- structure(list(), class = "trap_pool")
+  env$tbl.trap_pool <- function(src, from, ...) {
+    pool_touched <<- TRUE
+    stop("DB must not be touched when the throttle blocks")
+  }
+  create_job_called <- FALSE
+  env$create_job <- function(...) {
+    create_job_called <<- TRUE
+    NULL
+  }
+  env$async_job_submit_admission_guard <- function(req, res) {
+    res$status <- 429
+    res$setHeader("Retry-After", "42")
+    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
+  }
+  res <- job_endpoint_fake_res()
+  out <- env$svc_job_submit_phenotype_clustering(list(user = list(user_id = NULL)), res)
+  expect_equal(res$status, 429)
+  expect_equal(out$error, "RATE_LIMITED")
+  expect_false(pool_touched)
+  expect_false(create_job_called)
+})
diff --git a/api/tests/testthat/test-unit-job-endpoint-services.R b/api/tests/testthat/test-unit-job-endpoint-services.R
index 3bb4b43f..944d1c5b 100644
--- a/api/tests/testthat/test-unit-job-endpoint-services.R
+++ b/api/tests/testthat/test-unit-job-endpoint-services.R
@@ -1,13 +1,20 @@
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
@@ -34,20 +41,6 @@ source(file.path(api_dir, "tests", "testthat", "job-endpoint-services-fixtures.R
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
@@ -55,6 +48,7 @@ test_that("functional clustering: default genes are drawn from ndd_entity_view w
     hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
     ndd_phenotype = c(1L, 0L, 1L)
   ))
+  job_endpoint_stub_all_ndd_universe(env)
   captured <- NULL
   env$check_duplicate_job <- function(operation, params) {
     captured <<- params
@@ -97,8 +91,14 @@ test_that("functional clustering: cache hit stores a completed job without calli
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
@@ -121,6 +121,22 @@ test_that("functional clustering: cache hit stores a completed job without calli
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
@@ -128,6 +144,7 @@ test_that("functional clustering: capacity guard (503) then a cache miss under c
 
   env <- job_endpoint_source_service("job-functional-submission-service.R")
   env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
   env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   env$async_job_capacity_exceeded <- function(...) TRUE
   env$async_job_active_count <- function(...) 99L
@@ -138,22 +155,48 @@ test_that("functional clustering: capacity guard (503) then a cache miss under c
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
 
@@ -169,9 +212,9 @@ test_that("functional clustering: admission throttle runs FIRST, before any DB/c
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
@@ -184,197 +227,11 @@ test_that("functional clustering: admission throttle runs FIRST, before any DB/c
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
@@ -1,7 +1,7 @@
 {
   "title": "SysNDD API",
   "description": "This is the API powering the SysNDD website, allowing programmatic access to the database contents.",
-  "version": "0.30.0",
+  "version": "0.30.1",
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
diff --git a/app/package.json b/app/package.json
index ea8dbd91..5004dbe1 100644
--- a/app/package.json
+++ b/app/package.json
@@ -1,6 +1,6 @@
 {
   "name": "sysndd",
-  "version": "0.30.0",
+  "version": "0.30.1",
   "private": true,
   "type": "module",
   "scripts": {
diff --git a/documentation/08-development.qmd b/documentation/08-development.qmd
index c56d803e..1c553653 100644
--- a/documentation/08-development.qmd
+++ b/documentation/08-development.qmd
@@ -192,6 +192,21 @@ mkdir -p /tmp/asr-verify && tar -xzf bundle.tar.gz -C /tmp/asr-verify
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

exec
/bin/bash -lc "rg -n -C 12 'generate_ndd_hgnc_ids|analysis_snapshot_source_data_version|check_duplicate_job' api/functions api/services | head -n 300 && nl -ba api/tests/testthat/test-unit-job-endpoint-services.R | sed -n '1,340p' && nl -ba api/tests/testthat/test-unit-async-job-service.R | sed -n '1,500p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/services/job-maintenance-submission-service.R-40-    dplyr::tbl("non_alt_loci_set") %>%
api/services/job-maintenance-submission-service.R-41-    dplyr::select(symbol, hgnc_id) %>%
api/services/job-maintenance-submission-service.R-42-    dplyr::collect()
api/services/job-maintenance-submission-service.R-43-
api/services/job-maintenance-submission-service.R-44-  # Get mode of inheritance list
api/services/job-maintenance-submission-service.R-45-  mode_of_inheritance_list <- pool %>%
api/services/job-maintenance-submission-service.R-46-    dplyr::tbl("mode_of_inheritance_list") %>%
api/services/job-maintenance-submission-service.R-47-    dplyr::filter(is_active == 1) %>%
api/services/job-maintenance-submission-service.R-48-    dplyr::select(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name) %>%
api/services/job-maintenance-submission-service.R-49-    dplyr::collect()
api/services/job-maintenance-submission-service.R-50-
api/services/job-maintenance-submission-service.R-51-  # Check for duplicate job (ontology update has no params variation)
api/services/job-maintenance-submission-service.R:52:  dup_check <- check_duplicate_job("ontology_update", list(operation = "ontology_update"))
api/services/job-maintenance-submission-service.R-53-  if (dup_check$duplicate) {
api/services/job-maintenance-submission-service.R-54-    res$status <- 409
api/services/job-maintenance-submission-service.R-55-    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
api/services/job-maintenance-submission-service.R-56-    return(list(
api/services/job-maintenance-submission-service.R-57-      error = "DUPLICATE_JOB",
api/services/job-maintenance-submission-service.R-58-      message = "Ontology update job already running",
api/services/job-maintenance-submission-service.R-59-      existing_job_id = dup_check$existing_job_id,
api/services/job-maintenance-submission-service.R-60-      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
api/services/job-maintenance-submission-service.R-61-    ))
api/services/job-maintenance-submission-service.R-62-  }
api/services/job-maintenance-submission-service.R-63-
api/services/job-maintenance-submission-service.R-64-  # Create async job
--
api/services/backup-endpoint-service.R-1-# api/services/backup-endpoint-service.R
api/services/backup-endpoint-service.R-2-#
api/services/backup-endpoint-service.R-3-# Service layer for the backup management endpoints (#346 Wave 3 Task 9).
api/services/backup-endpoint-service.R-4-# api/endpoints/backup_endpoints.R stays a thin authorization/delegation
api/services/backup-endpoint-service.R-5-# shell; every svc_backup_* function here is the exact handler body, moved
api/services/backup-endpoint-service.R-6-# verbatim except for `require_role()`, which stays in the shell next to
api/services/backup-endpoint-service.R-7-# its route decorator. Callers MUST run that gate before calling any
api/services/backup-endpoint-service.R-8-# function below.
api/services/backup-endpoint-service.R-9-#
api/services/backup-endpoint-service.R-10-# Sourced by api/bootstrap/load_modules.R after functions/db-helpers.R (dw),
api/services/backup-endpoint-service.R:11:# functions/job-manager.R (create_job, check_duplicate_job),
api/services/backup-endpoint-service.R-12-# functions/job-progress.R (create_progress_reporter), and
api/services/backup-endpoint-service.R-13-# functions/backup-functions.R (list_backup_files, get_backup_metadata,
api/services/backup-endpoint-service.R-14-# is_valid_backup_filename). These svc_ functions only SUBMIT durable jobs:
api/services/backup-endpoint-service.R-15-# create_job() enqueues a durable async job that the worker executes via the
api/services/backup-endpoint-service.R-16-# registered handlers .async_job_run_backup_create /
api/services/backup-endpoint-service.R-17-# .async_job_run_backup_restore (functions/async-job-maintenance-handlers.R).
api/services/backup-endpoint-service.R-18-# The job payload carries NO DB credential (#535 P1-1); the worker resolves it
api/services/backup-endpoint-service.R-19-# at run time via async_job_worker_db_config().
api/services/backup-endpoint-service.R-20-
api/services/backup-endpoint-service.R-21-#' Shared 202/503 response shaping for the /create and /restore job
api/services/backup-endpoint-service.R-22-#' submissions, which differ only in the create_job() operation/params.
api/services/backup-endpoint-service.R-23-.svc_backup_job_response <- function(res, result) {
--
api/services/backup-endpoint-service.R-119-        error = "BACKUP_LIST_FAILED",
api/services/backup-endpoint-service.R-120-        message = "Failed to retrieve backup list",
api/services/backup-endpoint-service.R-121-        details = e$message
api/services/backup-endpoint-service.R-122-      )
api/services/backup-endpoint-service.R-123-    }
api/services/backup-endpoint-service.R-124-  )
api/services/backup-endpoint-service.R-125-}
api/services/backup-endpoint-service.R-126-
api/services/backup-endpoint-service.R-127-# ---- Backup Creation: POST /create ----
api/services/backup-endpoint-service.R-128-# Submits a durable `backup_create` job via create_job(); 409 when a backup is
api/services/backup-endpoint-service.R-129-# already in progress, 503 when job capacity is exceeded.
api/services/backup-endpoint-service.R-130-svc_backup_create <- function(req, res) {
api/services/backup-endpoint-service.R:131:  dup_check <- check_duplicate_job("backup_create", list())
api/services/backup-endpoint-service.R-132-  if (dup_check$duplicate) {
api/services/backup-endpoint-service.R-133-    res$status <- 409
api/services/backup-endpoint-service.R-134-    return(list(
api/services/backup-endpoint-service.R-135-      error = "BACKUP_IN_PROGRESS",
api/services/backup-endpoint-service.R-136-      message = "A backup operation is already running",
api/services/backup-endpoint-service.R-137-      existing_job_id = dup_check$existing_job_id
api/services/backup-endpoint-service.R-138-    ))
api/services/backup-endpoint-service.R-139-  }
api/services/backup-endpoint-service.R-140-
api/services/backup-endpoint-service.R-141-  backup_filename <- sprintf("manual_%s.sql", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"))
api/services/backup-endpoint-service.R-142-
api/services/backup-endpoint-service.R-143-  # No DB credential in the job payload (#535 P1-1): the durable handler
--
api/services/backup-endpoint-service.R-179-  }
api/services/backup-endpoint-service.R-180-
api/services/backup-endpoint-service.R-181-  backup_path <- file.path("/backup", filename)
api/services/backup-endpoint-service.R-182-  if (!file.exists(backup_path)) {
api/services/backup-endpoint-service.R-183-    res$status <- 404
api/services/backup-endpoint-service.R-184-    return(list(
api/services/backup-endpoint-service.R-185-      error = "BACKUP_NOT_FOUND",
api/services/backup-endpoint-service.R-186-      message = sprintf("Backup file '%s' not found", filename)
api/services/backup-endpoint-service.R-187-    ))
api/services/backup-endpoint-service.R-188-  }
api/services/backup-endpoint-service.R-189-
api/services/backup-endpoint-service.R-190-  # Check for duplicate restore job
api/services/backup-endpoint-service.R:191:  dup_check <- check_duplicate_job("backup_restore", list(filename = filename))
api/services/backup-endpoint-service.R-192-  if (dup_check$duplicate) {
api/services/backup-endpoint-service.R-193-    res$status <- 409
api/services/backup-endpoint-service.R-194-    return(list(
api/services/backup-endpoint-service.R-195-      error = "RESTORE_IN_PROGRESS",
api/services/backup-endpoint-service.R-196-      message = "A restore operation is already running for this backup",
api/services/backup-endpoint-service.R-197-      existing_job_id = dup_check$existing_job_id
api/services/backup-endpoint-service.R-198-    ))
api/services/backup-endpoint-service.R-199-  }
api/services/backup-endpoint-service.R-200-
api/services/backup-endpoint-service.R-201-  # No DB credential in the job payload (#535 P1-1): the durable handler
api/services/backup-endpoint-service.R-202-  # .async_job_run_backup_restore resolves it from runtime config and performs
api/services/backup-endpoint-service.R-203-  # the pre-restore safety backup (BKUP-05); execution is delegated to the
--
api/services/publication-admin-endpoint-service.R-280-    },
api/services/publication-admin-endpoint-service.R-281-    error = function(e) {
api/services/publication-admin-endpoint-service.R-282-      log_error("PubTator update failed: {e$message}")
api/services/publication-admin-endpoint-service.R-283-      res$status <- 500
api/services/publication-admin-endpoint-service.R-284-      list(success = FALSE, error = e$message)
api/services/publication-admin-endpoint-service.R-285-    }
api/services/publication-admin-endpoint-service.R-286-  )
api/services/publication-admin-endpoint-service.R-287-}
api/services/publication-admin-endpoint-service.R-288-
api/services/publication-admin-endpoint-service.R-289-#' Submit an async PubTator update job (`POST /pubtator/update/submit`, Administrator).
api/services/publication-admin-endpoint-service.R-290-#'
api/services/publication-admin-endpoint-service.R-291-#' `require_role()`, the `query == ""` 400 check, and the duplicate-job 409
api/services/publication-admin-endpoint-service.R:292:#' short-circuit (`check_duplicate_job()`) all stay in the endpoint shell;
api/services/publication-admin-endpoint-service.R-293-#' this covers job creation and the capacity-503 / accepted-202 response.
api/services/publication-admin-endpoint-service.R-294-#'
api/services/publication-admin-endpoint-service.R-295-#' @param req,res Plumber request/response.
api/services/publication-admin-endpoint-service.R-296-#' @param query The search query for PubTator.
api/services/publication-admin-endpoint-service.R-297-#' @param max_pages Maximum pages to fetch (already coerced to integer).
api/services/publication-admin-endpoint-service.R-298-#' @param clear_old Hard update flag (already coerced to logical).
api/services/publication-admin-endpoint-service.R-299-#' @param q_hash Precomputed query hash (from the shell's duplicate check).
api/services/publication-admin-endpoint-service.R-300-#' @param submit_fn Injectable job submitter (default [create_job()]).
api/services/publication-admin-endpoint-service.R-301-#' @return List with job_id/status/etc (202), or the capacity error body (503).
api/services/publication-admin-endpoint-service.R-302-#' @export
api/services/publication-admin-endpoint-service.R-303-svc_publication_pubtator_update_submit <- function(req, res, query, max_pages, clear_old, q_hash,
api/services/publication-admin-endpoint-service.R-304-                                                     submit_fn = create_job) {
--
api/functions/job-manager.R-209-#' Scans active jobs for one with matching operation and parameters.
api/functions/job-manager.R-210-#' Prevents duplicate expensive computations.
api/functions/job-manager.R-211-#'
api/functions/job-manager.R-212-#' @param operation Character string identifying the operation type
api/functions/job-manager.R-213-#' @param params List of parameters to check against
api/functions/job-manager.R-214-#'
api/functions/job-manager.R-215-#' @return List with:
api/functions/job-manager.R-216-#'   - duplicate=TRUE, existing_job_id: if duplicate found
api/functions/job-manager.R-217-#'   - duplicate=FALSE: if no duplicate
api/functions/job-manager.R-218-#'
api/functions/job-manager.R-219-#' @examples
api/functions/job-manager.R-220-#' \dontrun{
api/functions/job-manager.R:221:#' dup <- check_duplicate_job("clustering", list(genes = c("BRCA1")))
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
api/functions/job-manager.R:232:#' Same `(operation, params)` shape as [check_duplicate_job()] so it is a
api/functions/job-manager.R-233-#' drop-in `duplicate_check_fn` seam, but dedupes on job_type alone rather than
api/functions/job-manager.R-234-#' the payload hash (#535 S2b HIGH-4): a full-table-replace maintenance job must
api/functions/job-manager.R-235-#' never run concurrently, including across a deploy that changes its payload
api/functions/job-manager.R-236-#' schema. `params` is ignored.
api/functions/job-manager.R-237-#'
api/functions/job-manager.R-238-#' @param operation Character job type.
api/functions/job-manager.R-239-#' @param params Ignored (present for seam compatibility).
api/functions/job-manager.R-240-#' @return list(duplicate = FALSE) or list(duplicate = TRUE, existing_job_id).
api/functions/job-manager.R-241-#' @export
api/functions/job-manager.R-242-check_active_job_by_type <- function(operation, params = NULL) {
api/functions/job-manager.R-243-  async_job_service_duplicate_by_type(operation)
api/functions/job-manager.R-244-}
--
api/services/admin-publication-refresh-endpoint-service.R-100-
api/services/admin-publication-refresh-endpoint-service.R-101-#' POST /admin/publications/refresh body.
api/services/admin-publication-refresh-endpoint-service.R-102-#'
api/services/admin-publication-refresh-endpoint-service.R-103-#' Supports three modes: explicit `pmids`, a `not_updated_since` date filter,
api/services/admin-publication-refresh-endpoint-service.R-104-#' or opt-in `all=true` full-corpus refresh. Submits the durable
api/services/admin-publication-refresh-endpoint-service.R-105-#' `publication_refresh` job (202) unless a duplicate is already running,
api/services/admin-publication-refresh-endpoint-service.R-106-#' capacity is exceeded (503, surfaced by `create_job_fn`), or no PMIDs
api/services/admin-publication-refresh-endpoint-service.R-107-#' resolve (400/200 per the original contract).
api/services/admin-publication-refresh-endpoint-service.R-108-#'
api/services/admin-publication-refresh-endpoint-service.R-109-#' @export
api/services/admin-publication-refresh-endpoint-service.R-110-svc_admin_publication_refresh_submit <- function(req, res,
api/services/admin-publication-refresh-endpoint-service.R-111-                                                   query_fn = db_execute_query,
api/services/admin-publication-refresh-endpoint-service.R:112:                                                   duplicate_check_fn = check_duplicate_job,
api/services/admin-publication-refresh-endpoint-service.R-113-                                                   create_job_fn = create_job) {
api/services/admin-publication-refresh-endpoint-service.R-114-  # CRITICAL: Extract request body BEFORE any async submission -- the request
api/services/admin-publication-refresh-endpoint-service.R-115-  # object cannot cross process/worker boundaries.
api/services/admin-publication-refresh-endpoint-service.R-116-  body <- req$body
api/services/admin-publication-refresh-endpoint-service.R-117-  pmids <- body$pmids
api/services/admin-publication-refresh-endpoint-service.R-118-  not_updated_since <- body$not_updated_since
api/services/admin-publication-refresh-endpoint-service.R-119-  refresh_all <- isTRUE(body$all)
api/services/admin-publication-refresh-endpoint-service.R-120-
api/services/admin-publication-refresh-endpoint-service.R-121-  date_check <- svc_admin_publication_refresh_validate_date(not_updated_since)
api/services/admin-publication-refresh-endpoint-service.R-122-  if (!date_check$valid) {
api/services/admin-publication-refresh-endpoint-service.R-123-    res$status <- 400
api/services/admin-publication-refresh-endpoint-service.R-124-    return(list(error = date_check$error))
--
api/services/job-functional-submission-service.R-82-    if (is.list(algo_input) || length(algo_input) >= 1) {
api/services/job-functional-submission-service.R-83-      algo_input <- algo_input[[1]]
api/services/job-functional-submission-service.R-84-    }
api/services/job-functional-submission-service.R-85-    algorithm <- tolower(as.character(algo_input))
api/services/job-functional-submission-service.R-86-    if (!algorithm %in% c("leiden", "walktrap")) {
api/services/job-functional-submission-service.R-87-      algorithm <- "leiden"
api/services/job-functional-submission-service.R-88-    }
api/services/job-functional-submission-service.R-89-  }
api/services/job-functional-submission-service.R-90-
api/services/job-functional-submission-service.R-91-  # Resolve the clustering gene universe + selector provenance (#574). The
api/services/job-functional-submission-service.R-92-  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
api/services/job-functional-submission-service.R-93-  # from before this feature: `clustering_resolve_category_universe(NULL)`
api/services/job-functional-submission-service.R:94:  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
api/services/job-functional-submission-service.R-95-  # so cache parity (memoise key = gene set + algorithm) is preserved.
api/services/job-functional-submission-service.R-96-  selector_chr <- NULL
api/services/job-functional-submission-service.R-97-  if (has_genes) {
api/services/job-functional-submission-service.R-98-    genes_list <- as.character(unlist(genes_in))
api/services/job-functional-submission-service.R-99-    kind <- "explicit"
api/services/job-functional-submission-service.R-100-  } else if (category_key) {
api/services/job-functional-submission-service.R-101-    # A present category_filter key means a category run. A present-but-null
api/services/job-functional-submission-service.R-102-    # value is supplied-but-empty (the resolver 400s on []/[""], but a NULL would
api/services/job-functional-submission-service.R-103-    # otherwise hit its absent->default branch), so reject it explicitly here.
api/services/job-functional-submission-service.R-104-    if (is.null(req$argsBody$category_filter)) {
api/services/job-functional-submission-service.R-105-      stop_for_bad_request(
api/services/job-functional-submission-service.R-106-        "category_filter was supplied but empty; provide at least one active category"
--
api/services/job-functional-submission-service.R-122-    dplyr::tbl("non_alt_loci_set") %>%
api/services/job-functional-submission-service.R-123-    dplyr::filter(!is.na(STRING_id)) %>%
api/services/job-functional-submission-service.R-124-    dplyr::select(symbol, hgnc_id, STRING_id) %>%
api/services/job-functional-submission-service.R-125-    dplyr::collect()
api/services/job-functional-submission-service.R-126-
api/services/job-functional-submission-service.R-127-  # Check for duplicate job (include algorithm in check). The selector is
api/services/job-functional-submission-service.R-128-  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
api/services/job-functional-submission-service.R-129-  # submits keep the pre-#574 dedup identity byte-identical.
api/services/job-functional-submission-service.R-130-  dup_params <- list(genes = genes_list, algorithm = algorithm)
api/services/job-functional-submission-service.R-131-  if (!is.null(selector_chr)) {
api/services/job-functional-submission-service.R-132-    dup_params$category_filter <- selector_chr
api/services/job-functional-submission-service.R-133-  }
api/services/job-functional-submission-service.R:134:  dup_check <- check_duplicate_job("clustering", dup_params)
api/services/job-functional-submission-service.R-135-  if (dup_check$duplicate) {
api/services/job-functional-submission-service.R-136-    res$status <- 409
api/services/job-functional-submission-service.R-137-    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
api/services/job-functional-submission-service.R-138-    return(list(
api/services/job-functional-submission-service.R-139-      error = "DUPLICATE_JOB",
api/services/job-functional-submission-service.R-140-      message = "Identical job already running",
api/services/job-functional-submission-service.R-141-      existing_job_id = dup_check$existing_job_id,
api/services/job-functional-submission-service.R-142-      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
api/services/job-functional-submission-service.R-143-    ))
api/services/job-functional-submission-service.R-144-  }
api/services/job-functional-submission-service.R-145-
api/services/job-functional-submission-service.R-146-  # Cheap-path provenance (no expensive query yet). `selector_obj` records
--
api/functions/clustering-gene-universe.R-2-#
api/functions/clustering-gene-universe.R-3-# Category-selected clustering gene-universe resolver (#574 D1).
api/functions/clustering-gene-universe.R-4-#
api/functions/clustering-gene-universe.R-5-# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
api/functions/clustering-gene-universe.R-6-# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
api/functions/clustering-gene-universe.R-7-# universe from curated SysNDD confidence categories instead of the default
api/functions/clustering-gene-universe.R-8-# "all NDD genes" set. This file builds ONLY the resolver + provenance
api/functions/clustering-gene-universe.R-9-# helpers; the submit service and durable handler wiring is done later.
api/functions/clustering-gene-universe.R-10-#
api/functions/clustering-gene-universe.R-11-# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
api/functions/clustering-gene-universe.R-12-# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
api/functions/clustering-gene-universe.R-13-# same gene also has OTHER-category entities. This mirrors
api/functions/clustering-gene-universe.R:14:# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
api/functions/clustering-gene-universe.R-15-# added `category %in% selector` filter -- it deliberately does NOT use
api/functions/clustering-gene-universe.R-16-# `select_network_gene_category()`, which is a gene-level display-label
api/functions/clustering-gene-universe.R-17-# aggregator for node coloring, not a universe filter.
api/functions/clustering-gene-universe.R-18-#
api/functions/clustering-gene-universe.R-19-# Category validation is live against `ndd_entity_status_categories_list
api/functions/clustering-gene-universe.R-20-# WHERE is_active = 1` -- no hardcoded category strings, and no category
api/functions/clustering-gene-universe.R-21-# string is interpolated into SQL (dbplyr `%in%` + an allowlist pre-check).
api/functions/clustering-gene-universe.R-22-
api/functions/clustering-gene-universe.R-23-# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
api/functions/clustering-gene-universe.R-24-# selector returns character(0), which the resolver rejects with 400 -- it must
api/functions/clustering-gene-universe.R-25-# never fall through to the all-NDD default.
api/functions/clustering-gene-universe.R-26-clustering_normalize_category_filter <- function(category_filter) {
--
api/functions/clustering-gene-universe.R-34-clustering_gene_list_sha256 <- function(hgnc_ids) {
api/functions/clustering-gene-universe.R-35-  digest::digest(
api/functions/clustering-gene-universe.R-36-    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
api/functions/clustering-gene-universe.R-37-    algo = "sha256", serialize = FALSE
api/functions/clustering-gene-universe.R-38-  )
api/functions/clustering-gene-universe.R-39-}
api/functions/clustering-gene-universe.R-40-
api/functions/clustering-gene-universe.R-41-clustering_resolve_category_universe <- function(category_filter, conn = pool) {
api/functions/clustering-gene-universe.R-42-  selector <- clustering_normalize_category_filter(category_filter)
api/functions/clustering-gene-universe.R-43-
api/functions/clustering-gene-universe.R-44-  if (is.null(selector)) {
api/functions/clustering-gene-universe.R-45-    # Absent -> preserve the exact current default ordering for cache parity.
api/functions/clustering-gene-universe.R:46:    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
api/functions/clustering-gene-universe.R-47-    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
api/functions/clustering-gene-universe.R-48-  }
api/functions/clustering-gene-universe.R-49-  if (length(selector) == 0L) {
api/functions/clustering-gene-universe.R-50-    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
api/functions/clustering-gene-universe.R-51-  }
api/functions/clustering-gene-universe.R-52-
api/functions/clustering-gene-universe.R-53-  active <- conn %>%
api/functions/clustering-gene-universe.R-54-    dplyr::tbl("ndd_entity_status_categories_list") %>%
api/functions/clustering-gene-universe.R-55-    dplyr::filter(is_active == 1) %>%
api/functions/clustering-gene-universe.R-56-    dplyr::select(category) %>%
api/functions/clustering-gene-universe.R-57-    dplyr::collect() %>%
api/functions/clustering-gene-universe.R-58-    dplyr::pull(category)
--
api/functions/clustering-gene-universe.R-75-    dplyr::pull(hgnc_id)
api/functions/clustering-gene-universe.R-76-
api/functions/clustering-gene-universe.R-77-  if (length(hgnc_ids) < 2L) {
api/functions/clustering-gene-universe.R-78-    stop_for_bad_request(sprintf(
api/functions/clustering-gene-universe.R-79-      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
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
/bin/bash -lc "rg -n -C 10 'async_job_repository_create|request_hash|async_job_duplicate_error|UNIQUE' api/functions/async-job-repository.R db/migrations | head -n 500 && rg -n -C 8 'generate_ndd_hgnc_ids <-|analysis_snapshot_source_data_version <-' api/functions" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/functions/async-job-repository.R-36-  }
api/functions/async-job-repository.R-37-}
api/functions/async-job-repository.R-38-
api/functions/async-job-repository.R-39-#' Create a durable async job row
api/functions/async-job-repository.R-40-#'
api/functions/async-job-repository.R-41-#' @param job Named list with job metadata and payload.
api/functions/async-job-repository.R-42-#' @param conn Optional connection or pool for dependency injection.
api/functions/async-job-repository.R-43-#'
api/functions/async-job-repository.R-44-#' @return Character job_id.
api/functions/async-job-repository.R-45-#' @export
api/functions/async-job-repository.R:46:async_job_repository_create <- function(job, conn = NULL) {
api/functions/async-job-repository.R-47-  .async_job_require_fields(
api/functions/async-job-repository.R-48-    job,
api/functions/async-job-repository.R:49:    c("job_id", "job_type", "request_payload_json", "request_hash")
api/functions/async-job-repository.R-50-  )
api/functions/async-job-repository.R-51-
api/functions/async-job-repository.R-52-  submitted_at <- .async_job_scalar(job$submitted_at, Sys.time())
api/functions/async-job-repository.R-53-  scheduled_at <- .async_job_scalar(job$scheduled_at, submitted_at)
api/functions/async-job-repository.R-54-
api/functions/async-job-repository.R-55-  insert_values <- list(
api/functions/async-job-repository.R-56-    job_id = .async_job_scalar(job$job_id),
api/functions/async-job-repository.R-57-    job_type = .async_job_scalar(job$job_type),
api/functions/async-job-repository.R-58-    queue_name = .async_job_scalar(job$queue_name, "default"),
api/functions/async-job-repository.R-59-    priority = as.integer(.async_job_scalar(job$priority, 100L)),
api/functions/async-job-repository.R-60-    status = .async_job_scalar(job$status, "queued"),
api/functions/async-job-repository.R:61:    request_hash = .async_job_scalar(job$request_hash),
api/functions/async-job-repository.R-62-    request_payload_json = .async_job_scalar(job$request_payload_json),
api/functions/async-job-repository.R-63-    submitted_at = submitted_at,
api/functions/async-job-repository.R-64-    scheduled_at = scheduled_at,
api/functions/async-job-repository.R-65-    attempt_count = as.integer(.async_job_scalar(job$attempt_count, 0L)),
api/functions/async-job-repository.R-66-    max_attempts = as.integer(.async_job_scalar(job$max_attempts, 1L))
api/functions/async-job-repository.R-67-  )
api/functions/async-job-repository.R-68-
api/functions/async-job-repository.R-69-  optional_fields <- c(
api/functions/async-job-repository.R-70-    "submitted_by",
api/functions/async-job-repository.R-71-    "started_at",
--
api/functions/async-job-repository.R-108-  )
api/functions/async-job-repository.R-109-
api/functions/async-job-repository.R-110-  params <- .async_job_normalize_params(insert_values)
api/functions/async-job-repository.R-111-
api/functions/async-job-repository.R-112-  tryCatch(
api/functions/async-job-repository.R-113-    {
api/functions/async-job-repository.R-114-      db_execute_statement(sql, params, conn = conn)
api/functions/async-job-repository.R-115-    },
api/functions/async-job-repository.R-116-    db_statement_error = function(e) {
api/functions/async-job-repository.R-117-      is_duplicate <- grepl(
api/functions/async-job-repository.R:118:        "idx_async_jobs_active_request_hash",
api/functions/async-job-repository.R-119-        e$message,
api/functions/async-job-repository.R-120-        fixed = TRUE
api/functions/async-job-repository.R-121-      )
api/functions/async-job-repository.R-122-      if (!is_duplicate) {
api/functions/async-job-repository.R-123-        stop(e)
api/functions/async-job-repository.R-124-      }
api/functions/async-job-repository.R-125-
api/functions/async-job-repository.R-126-      duplicate <- async_job_repository_find_active_duplicate(
api/functions/async-job-repository.R-127-        job_type = .async_job_scalar(job$job_type),
api/functions/async-job-repository.R:128:        request_hash = .async_job_scalar(job$request_hash),
api/functions/async-job-repository.R-129-        conn = conn
api/functions/async-job-repository.R-130-      )
api/functions/async-job-repository.R-131-
api/functions/async-job-repository.R-132-      abort(
api/functions/async-job-repository.R-133-        message = "Active async job with matching request hash already exists",
api/functions/async-job-repository.R:134:        class = "async_job_duplicate_error",
api/functions/async-job-repository.R-135-        job_id = if (nrow(duplicate) > 0) duplicate$job_id[[1]] else NULL,
api/functions/async-job-repository.R-136-        duplicate_job = duplicate
api/functions/async-job-repository.R-137-      )
api/functions/async-job-repository.R-138-    }
api/functions/async-job-repository.R-139-  )
api/functions/async-job-repository.R-140-
api/functions/async-job-repository.R-141-  .async_job_scalar(job$job_id)
api/functions/async-job-repository.R-142-}
api/functions/async-job-repository.R-143-
api/functions/async-job-repository.R-144-#' Get a durable async job row
--
api/functions/async-job-repository.R-154-    .async_job_build_select(include_result),
api/functions/async-job-repository.R-155-    "FROM async_jobs WHERE job_id = ? LIMIT 1"
api/functions/async-job-repository.R-156-  )
api/functions/async-job-repository.R-157-
api/functions/async-job-repository.R-158-  db_execute_query(sql, list(job_id), conn = conn)
api/functions/async-job-repository.R-159-}
api/functions/async-job-repository.R-160-
api/functions/async-job-repository.R-161-#' Find an active duplicate by job_type and durable request hash
api/functions/async-job-repository.R-162-#'
api/functions/async-job-repository.R-163-#' @param job_type Character job type.
api/functions/async-job-repository.R:164:#' @param request_hash Character durable request hash.
api/functions/async-job-repository.R-165-#' @param conn Optional connection or pool for dependency injection.
api/functions/async-job-repository.R-166-#'
api/functions/async-job-repository.R-167-#' @return Tibble with zero or one active duplicate row.
api/functions/async-job-repository.R-168-#' @export
api/functions/async-job-repository.R-169-# "Active" = in-flight OR retryable-failed. Shared by the hash-keyed duplicate
api/functions/async-job-repository.R-170-# lookup and the job-type single-flight lookup so they stay identical.
api/functions/async-job-repository.R-171-.async_job_active_status_sql <- paste(
api/functions/async-job-repository.R-172-  "(status IN ('queued', 'running', 'cancel_requested')",
api/functions/async-job-repository.R-173-  "OR (status = 'failed' AND attempt_count < max_attempts AND next_attempt_at IS NOT NULL))"
api/functions/async-job-repository.R-174-)
api/functions/async-job-repository.R-175-
api/functions/async-job-repository.R:176:async_job_repository_find_active_duplicate <- function(job_type, request_hash, conn = NULL) {
api/functions/async-job-repository.R-177-  sql <- paste(
api/functions/async-job-repository.R-178-    .async_job_build_select(FALSE),
api/functions/async-job-repository.R:179:    "FROM async_jobs WHERE job_type = ? AND request_hash = ?",
api/functions/async-job-repository.R-180-    "AND", .async_job_active_status_sql,
api/functions/async-job-repository.R-181-    "ORDER BY submitted_at DESC LIMIT 1"
api/functions/async-job-repository.R-182-  )
api/functions/async-job-repository.R-183-
api/functions/async-job-repository.R:184:  db_execute_query(sql, list(job_type, request_hash), conn = conn)
api/functions/async-job-repository.R-185-}
api/functions/async-job-repository.R-186-
api/functions/async-job-repository.R-187-#' Find an active job of a given type, independent of request payload/hash.
api/functions/async-job-repository.R-188-#'
api/functions/async-job-repository.R-189-#' Job-type single-flight for destructive maintenance families (#535 S2b): a
api/functions/async-job-repository.R-190-#' new submission must dedupe against ANY in-flight (or retryable-failed) job of
api/functions/async-job-repository.R-191-#' the same type, even across a payload-schema change (e.g. dropping db_config),
api/functions/async-job-repository.R-192-#' which the hash-based `find_active_duplicate` cannot do because the hash
api/functions/async-job-repository.R-193-#' changes with the payload.
api/functions/async-job-repository.R-194-#'
--
db/migrations/027_add_pubtator_gene_enrichment.sql-35-  `ndd_corpus_size` INT NOT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-36-  `total_corpus_size` BIGINT NOT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-37-  `total_is_fallback` TINYINT NOT NULL DEFAULT 0,
db/migrations/027_add_pubtator_gene_enrichment.sql-38-  `genes_scored` INT NOT NULL DEFAULT 0,
db/migrations/027_add_pubtator_gene_enrichment.sql-39-  `refreshed_by` INT DEFAULT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-40-  `is_current` TINYINT NOT NULL DEFAULT 0,
db/migrations/027_add_pubtator_gene_enrichment.sql-41-  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
db/migrations/027_add_pubtator_gene_enrichment.sql-42-  `is_current_slot` TINYINT
db/migrations/027_add_pubtator_gene_enrichment.sql-43-      GENERATED ALWAYS AS (CASE WHEN `is_current` = 1 THEN 1 ELSE NULL END) STORED,
db/migrations/027_add_pubtator_gene_enrichment.sql-44-  PRIMARY KEY (`corpus_stats_id`),
db/migrations/027_add_pubtator_gene_enrichment.sql:45:  UNIQUE KEY `idx_pubtator_corpus_stats_current` (`is_current_slot`),
db/migrations/027_add_pubtator_gene_enrichment.sql-46-  KEY `idx_pubtator_corpus_stats_created` (`created_at`),
db/migrations/027_add_pubtator_gene_enrichment.sql-47-  CONSTRAINT `fk_pubtator_corpus_stats_refreshed_by`
db/migrations/027_add_pubtator_gene_enrichment.sql-48-      FOREIGN KEY (`refreshed_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
db/migrations/027_add_pubtator_gene_enrichment.sql-49-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
db/migrations/027_add_pubtator_gene_enrichment.sql-50-
db/migrations/027_add_pubtator_gene_enrichment.sql-51--- ---------------------------------------------------------------------------
db/migrations/027_add_pubtator_gene_enrichment.sql-52--- Per-gene normalized metrics for the current snapshot.
db/migrations/027_add_pubtator_gene_enrichment.sql-53---   observed         -- NDD-corpus publications mentioning the gene
db/migrations/027_add_pubtator_gene_enrichment.sql-54---   background_count -- total PubTator publications mentioning the gene
db/migrations/027_add_pubtator_gene_enrichment.sql-55---   enrichment_ratio -- observed / (ndd_corpus * background / total_corpus)
--
db/migrations/027_add_pubtator_gene_enrichment.sql-63-  `hgnc_id` VARCHAR(20) DEFAULT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-64-  `gene_symbol` VARCHAR(64) NOT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-65-  `observed` INT NOT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-66-  `background_count` INT DEFAULT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-67-  `enrichment_ratio` DOUBLE DEFAULT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-68-  `npmi` DOUBLE DEFAULT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-69-  `fisher_p` DOUBLE DEFAULT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-70-  `fdr_bh` DOUBLE DEFAULT NULL,
db/migrations/027_add_pubtator_gene_enrichment.sql-71-  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
db/migrations/027_add_pubtator_gene_enrichment.sql-72-  PRIMARY KEY (`gene_enrichment_id`),
db/migrations/027_add_pubtator_gene_enrichment.sql:73:  UNIQUE KEY `idx_pubtator_gene_enrichment_symbol` (`gene_symbol`),
db/migrations/027_add_pubtator_gene_enrichment.sql-74-  KEY `idx_pubtator_gene_enrichment_hgnc` (`hgnc_id`),
db/migrations/027_add_pubtator_gene_enrichment.sql-75-  KEY `idx_pubtator_gene_enrichment_corpus` (`corpus_stats_id`),
db/migrations/027_add_pubtator_gene_enrichment.sql-76-  KEY `idx_pubtator_gene_enrichment_ratio` (`enrichment_ratio`),
db/migrations/027_add_pubtator_gene_enrichment.sql-77-  KEY `idx_pubtator_gene_enrichment_npmi` (`npmi`),
db/migrations/027_add_pubtator_gene_enrichment.sql-78-  CONSTRAINT `fk_pubtator_gene_enrichment_corpus`
db/migrations/027_add_pubtator_gene_enrichment.sql-79-      FOREIGN KEY (`corpus_stats_id`) REFERENCES `pubtator_corpus_stats` (`corpus_stats_id`)
db/migrations/027_add_pubtator_gene_enrichment.sql-80-      ON DELETE CASCADE
db/migrations/027_add_pubtator_gene_enrichment.sql-81-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
db/migrations/027_add_pubtator_gene_enrichment.sql-82-
db/migrations/027_add_pubtator_gene_enrichment.sql-83--- ---------------------------------------------------------------------------
--
db/migrations/024_add_public_analysis_snapshots.sql-24-  `algorithm_name` VARCHAR(64) DEFAULT NULL,
db/migrations/024_add_public_analysis_snapshots.sql-25-  `algorithm_version` VARCHAR(64) DEFAULT NULL,
db/migrations/024_add_public_analysis_snapshots.sql-26-  `package_versions_json` JSON DEFAULT NULL,
db/migrations/024_add_public_analysis_snapshots.sql-27-  `row_counts_json` JSON DEFAULT NULL,
db/migrations/024_add_public_analysis_snapshots.sql-28-  `warnings_json` JSON DEFAULT NULL,
db/migrations/024_add_public_analysis_snapshots.sql-29-  `last_error_message` TEXT DEFAULT NULL,
db/migrations/024_add_public_analysis_snapshots.sql-30-  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
db/migrations/024_add_public_analysis_snapshots.sql-31-  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
db/migrations/024_add_public_analysis_snapshots.sql-32-      ON UPDATE CURRENT_TIMESTAMP(6),
db/migrations/024_add_public_analysis_snapshots.sql-33-  PRIMARY KEY (`snapshot_id`),
db/migrations/024_add_public_analysis_snapshots.sql:34:  UNIQUE KEY `idx_analysis_snapshot_public_ready`
db/migrations/024_add_public_analysis_snapshots.sql-35-      (`analysis_type`, `parameter_hash`, `public_ready_slot`),
db/migrations/024_add_public_analysis_snapshots.sql-36-  KEY `idx_analysis_snapshot_lookup`
db/migrations/024_add_public_analysis_snapshots.sql-37-      (`analysis_type`, `parameter_hash`, `public_ready`, `status`),
db/migrations/024_add_public_analysis_snapshots.sql-38-  KEY `idx_analysis_snapshot_generated_at` (`analysis_type`, `generated_at`)
db/migrations/024_add_public_analysis_snapshots.sql-39-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
db/migrations/024_add_public_analysis_snapshots.sql-40-
db/migrations/024_add_public_analysis_snapshots.sql-41-CREATE TABLE IF NOT EXISTS `analysis_snapshot_network_node` (
db/migrations/024_add_public_analysis_snapshots.sql-42-  `snapshot_id` BIGINT NOT NULL,
db/migrations/024_add_public_analysis_snapshots.sql-43-  `hgnc_id` VARCHAR(10) NOT NULL,
db/migrations/024_add_public_analysis_snapshots.sql-44-  `symbol` VARCHAR(50) DEFAULT NULL,
--
db/migrations/036_add_disease_ontology_mappings.sql-32-  `mondo_id`            varchar(20)  DEFAULT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-33-  `target_prefix`       varchar(20)  NOT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-34-  `target_id`           varchar(64)  NOT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-35-  `target_label`        varchar(1000) DEFAULT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-36-  `predicate`           varchar(20)  DEFAULT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-37-  `source`              varchar(40)  NOT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-38-  `release_version`     varchar(32)  DEFAULT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-39-  `is_active`           tinyint(1)   NOT NULL DEFAULT 1,
db/migrations/036_add_disease_ontology_mappings.sql-40-  `update_date`         timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/036_add_disease_ontology_mappings.sql-41-  PRIMARY KEY (`id`),
db/migrations/036_add_disease_ontology_mappings.sql:42:  UNIQUE KEY `uq_disease_target` (`disease_ontology_id`,`target_prefix`,`target_id`),
db/migrations/036_add_disease_ontology_mappings.sql-43-  KEY `idx_dom_disease` (`disease_ontology_id`),
db/migrations/036_add_disease_ontology_mappings.sql-44-  KEY `idx_dom_target` (`target_prefix`,`target_id`)
db/migrations/036_add_disease_ontology_mappings.sql-45-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
db/migrations/036_add_disease_ontology_mappings.sql-46-
db/migrations/036_add_disease_ontology_mappings.sql-47-CREATE TABLE IF NOT EXISTS `disease_ontology_mapping_meta` (
db/migrations/036_add_disease_ontology_mappings.sql-48-  `id`                    int          NOT NULL AUTO_INCREMENT,
db/migrations/036_add_disease_ontology_mappings.sql-49-  `mondo_release_version` varchar(32)  DEFAULT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-50-  `mondo_obo_url`         varchar(500) DEFAULT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-51-  `mondo_sssom_url`       varchar(500) DEFAULT NULL,
db/migrations/036_add_disease_ontology_mappings.sql-52-  `source_validators`     json         DEFAULT NULL,
--
db/migrations/007_comparisons_config.sql-18-CREATE PROCEDURE IF NOT EXISTS migrate_007_comparisons_config()
db/migrations/007_comparisons_config.sql-19-BEGIN
db/migrations/007_comparisons_config.sql-20-    -- Create comparisons_config table if not exists
db/migrations/007_comparisons_config.sql-21-    IF NOT EXISTS (
db/migrations/007_comparisons_config.sql-22-        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
db/migrations/007_comparisons_config.sql-23-        WHERE TABLE_SCHEMA = DATABASE()
db/migrations/007_comparisons_config.sql-24-          AND TABLE_NAME = 'comparisons_config'
db/migrations/007_comparisons_config.sql-25-    ) THEN
db/migrations/007_comparisons_config.sql-26-        CREATE TABLE comparisons_config (
db/migrations/007_comparisons_config.sql-27-            id INT AUTO_INCREMENT PRIMARY KEY,
db/migrations/007_comparisons_config.sql:28:            source_name VARCHAR(50) NOT NULL UNIQUE COMMENT 'Identifier matching list column in ndd_database_comparison',
db/migrations/007_comparisons_config.sql-29-            source_url TEXT NOT NULL COMMENT 'Full URL for data download',
db/migrations/007_comparisons_config.sql-30-            file_format VARCHAR(10) NOT NULL COMMENT 'Parser type: pdf, csv, csv.gz, tsv, json, txt',
db/migrations/007_comparisons_config.sql-31-            is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Whether to include in refresh',
db/migrations/007_comparisons_config.sql-32-            last_updated DATETIME NULL COMMENT 'Last successful download timestamp',
db/migrations/007_comparisons_config.sql-33-            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/007_comparisons_config.sql-34-            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
db/migrations/007_comparisons_config.sql-35-            INDEX idx_source_name (source_name),
db/migrations/007_comparisons_config.sql-36-            INDEX idx_is_active (is_active)
db/migrations/007_comparisons_config.sql-37-        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
db/migrations/007_comparisons_config.sql-38-
--
db/migrations/008_add_llm_prompt_templates.sql-27-            template_id INT AUTO_INCREMENT PRIMARY KEY,
db/migrations/008_add_llm_prompt_templates.sql-28-            prompt_type ENUM('functional_generation', 'functional_judge',
db/migrations/008_add_llm_prompt_templates.sql-29-                            'phenotype_generation', 'phenotype_judge') NOT NULL,
db/migrations/008_add_llm_prompt_templates.sql-30-            version VARCHAR(20) NOT NULL DEFAULT '1.0',
db/migrations/008_add_llm_prompt_templates.sql-31-            template_text TEXT NOT NULL,
db/migrations/008_add_llm_prompt_templates.sql-32-            description TEXT,
db/migrations/008_add_llm_prompt_templates.sql-33-            is_active BOOLEAN NOT NULL DEFAULT TRUE,
db/migrations/008_add_llm_prompt_templates.sql-34-            created_by INT NULL COMMENT 'user_id of creator, NULL for system defaults',
db/migrations/008_add_llm_prompt_templates.sql-35-            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/008_add_llm_prompt_templates.sql-36-            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
db/migrations/008_add_llm_prompt_templates.sql:37:            UNIQUE KEY idx_prompt_type_version (prompt_type, version),
db/migrations/008_add_llm_prompt_templates.sql-38-            INDEX idx_is_active (is_active),
db/migrations/008_add_llm_prompt_templates.sql-39-            INDEX idx_prompt_type_active (prompt_type, is_active)
db/migrations/008_add_llm_prompt_templates.sql-40-        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
db/migrations/008_add_llm_prompt_templates.sql-41-
db/migrations/008_add_llm_prompt_templates.sql-42-        -- Seed default prompts (v1.0) for all 4 prompt types
db/migrations/008_add_llm_prompt_templates.sql-43-        -- These are the actual prompts used in production, extracted from llm-service.R
db/migrations/008_add_llm_prompt_templates.sql-44-        INSERT INTO llm_prompt_templates (prompt_type, version, template_text, description, is_active) VALUES
db/migrations/008_add_llm_prompt_templates.sql-45-        ('functional_generation', '1.0',
db/migrations/008_add_llm_prompt_templates.sql-46-         'You are a genomics expert analyzing gene clusters associated with neurodevelopmental disorders.
db/migrations/008_add_llm_prompt_templates.sql-47-
--
db/migrations/023_add_nddscore_prediction_release.sql-42-  `import_started_at` DATETIME(6) DEFAULT NULL,
db/migrations/023_add_nddscore_prediction_release.sql-43-  `import_completed_at` DATETIME(6) DEFAULT NULL,
db/migrations/023_add_nddscore_prediction_release.sql-44-  `activated_at` DATETIME(6) DEFAULT NULL,
db/migrations/023_add_nddscore_prediction_release.sql-45-  `last_error_message` TEXT DEFAULT NULL,
db/migrations/023_add_nddscore_prediction_release.sql-46-  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
db/migrations/023_add_nddscore_prediction_release.sql-47-  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
db/migrations/023_add_nddscore_prediction_release.sql-48-      ON UPDATE CURRENT_TIMESTAMP(6),
db/migrations/023_add_nddscore_prediction_release.sql-49-  `active_release_slot` TINYINT
db/migrations/023_add_nddscore_prediction_release.sql-50-      GENERATED ALWAYS AS (CASE WHEN `is_active` = 1 THEN 1 ELSE NULL END) STORED,
db/migrations/023_add_nddscore_prediction_release.sql-51-  PRIMARY KEY (`release_id`),
db/migrations/023_add_nddscore_prediction_release.sql:52:  UNIQUE KEY `idx_nddscore_release_active_slot` (`active_release_slot`),
db/migrations/023_add_nddscore_prediction_release.sql-53-  KEY `idx_nddscore_release_status` (`import_status`),
db/migrations/023_add_nddscore_prediction_release.sql-54-  CONSTRAINT `fk_nddscore_release_imported_by`
db/migrations/023_add_nddscore_prediction_release.sql-55-      FOREIGN KEY (`imported_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
db/migrations/023_add_nddscore_prediction_release.sql-56-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
db/migrations/023_add_nddscore_prediction_release.sql-57-
db/migrations/023_add_nddscore_prediction_release.sql-58-CREATE TABLE IF NOT EXISTS `nddscore_gene_prediction` (
db/migrations/023_add_nddscore_prediction_release.sql-59-  `release_id` VARCHAR(64) NOT NULL,
db/migrations/023_add_nddscore_prediction_release.sql-60-  `hgnc_id` VARCHAR(10) NOT NULL,
db/migrations/023_add_nddscore_prediction_release.sql-61-  `gene_symbol` VARCHAR(50) NOT NULL,
db/migrations/023_add_nddscore_prediction_release.sql-62-  `ensembl_gene_id` VARCHAR(20) DEFAULT NULL,
--
db/migrations/041_add_analysis_reproducibility.sql-1--- Migration: 041_add_analysis_reproducibility
db/migrations/041_add_analysis_reproducibility.sql-2--- Description: Per-clustering-snapshot reproducibility bundle (#512). Stores the
db/migrations/041_add_analysis_reproducibility.sql-3---   gzipped canonical JSON of the inputs needed to INDEPENDENTLY recompute the
db/migrations/041_add_analysis_reproducibility.sql-4---   served separation metric (functional modularity / phenotype silhouette):
db/migrations/041_add_analysis_reproducibility.sql-5---   the full LCC edge list + complete membership (functional) or the MCA
db/migrations/041_add_analysis_reproducibility.sql-6---   coordinate matrix + membership (phenotype), plus params, the served metric,
db/migrations/041_add_analysis_reproducibility.sql-7---   and a SHA-256 reproducibility_hash over the canonical pre-gzip JSON.
db/migrations/041_add_analysis_reproducibility.sql-8---
db/migrations/041_add_analysis_reproducibility.sql:9:-- One row per clustering snapshot (UNIQUE on snapshot_id). Cascades on delete of
db/migrations/041_add_analysis_reproducibility.sql-10--- the parent manifest row. `snapshot_id` is BIGINT to match
db/migrations/041_add_analysis_reproducibility.sql-11--- `analysis_snapshot_manifest.snapshot_id` (an INT reference would fail with
db/migrations/041_add_analysis_reproducibility.sql-12--- errno 1215 "Cannot add foreign key constraint").
db/migrations/041_add_analysis_reproducibility.sql-13-
db/migrations/041_add_analysis_reproducibility.sql-14-CREATE TABLE IF NOT EXISTS `analysis_snapshot_reproducibility` (
db/migrations/041_add_analysis_reproducibility.sql-15-  `reproducibility_id`   INT NOT NULL AUTO_INCREMENT,
db/migrations/041_add_analysis_reproducibility.sql-16-  `snapshot_id`          BIGINT NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql-17-  `kind`                 VARCHAR(32) NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql-18-  `bundle_gzip_json`     LONGBLOB NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql-19-  `reproducibility_hash` CHAR(64) NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql-20-  `byte_size`            INT NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql-21-  `created_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/041_add_analysis_reproducibility.sql-22-  PRIMARY KEY (`reproducibility_id`),
db/migrations/041_add_analysis_reproducibility.sql:23:  UNIQUE KEY `uq_repro_snapshot` (`snapshot_id`),
db/migrations/041_add_analysis_reproducibility.sql-24-  KEY `idx_repro_hash` (`reproducibility_hash`),
db/migrations/041_add_analysis_reproducibility.sql-25-  CONSTRAINT `fk_repro_snapshot`
db/migrations/041_add_analysis_reproducibility.sql-26-    FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
db/migrations/041_add_analysis_reproducibility.sql-27-    ON DELETE CASCADE
db/migrations/041_add_analysis_reproducibility.sql-28-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
--
db/migrations/020_add_async_job_schema.sql-1--- Migration: 020_add_async_job_schema
db/migrations/020_add_async_job_schema.sql-2--- Description: Adds durable async job and event storage for MySQL-backed workers
db/migrations/020_add_async_job_schema.sql-3-
db/migrations/020_add_async_job_schema.sql-4-CREATE TABLE async_jobs (
db/migrations/020_add_async_job_schema.sql-5-    job_id CHAR(36) NOT NULL PRIMARY KEY,
db/migrations/020_add_async_job_schema.sql-6-    job_type VARCHAR(64) NOT NULL,
db/migrations/020_add_async_job_schema.sql-7-    queue_name VARCHAR(64) NOT NULL DEFAULT 'default',
db/migrations/020_add_async_job_schema.sql-8-    priority INT NOT NULL DEFAULT 100,
db/migrations/020_add_async_job_schema.sql-9-    status ENUM('queued', 'running', 'completed', 'failed', 'cancel_requested', 'cancelled') NOT NULL DEFAULT 'queued',
db/migrations/020_add_async_job_schema.sql:10:    request_hash CHAR(64) NOT NULL,
db/migrations/020_add_async_job_schema.sql-11-    request_payload_json JSON NOT NULL,
db/migrations/020_add_async_job_schema.sql-12-    submitted_by INT NULL,
db/migrations/020_add_async_job_schema.sql-13-    submitted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
db/migrations/020_add_async_job_schema.sql-14-    scheduled_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
db/migrations/020_add_async_job_schema.sql-15-    started_at DATETIME(6) NULL,
db/migrations/020_add_async_job_schema.sql-16-    completed_at DATETIME(6) NULL,
db/migrations/020_add_async_job_schema.sql-17-    claimed_by_worker VARCHAR(128) NULL,
db/migrations/020_add_async_job_schema.sql-18-    claim_token CHAR(36) NULL,
db/migrations/020_add_async_job_schema.sql-19-    worker_hostname VARCHAR(255) NULL,
db/migrations/020_add_async_job_schema.sql-20-    worker_pid INT NULL,
db/migrations/020_add_async_job_schema.sql-21-    last_heartbeat_at DATETIME(6) NULL,
db/migrations/020_add_async_job_schema.sql-22-    claim_expires_at DATETIME(6) NULL,
db/migrations/020_add_async_job_schema.sql-23-    attempt_count INT NOT NULL DEFAULT 0,
db/migrations/020_add_async_job_schema.sql-24-    max_attempts INT NOT NULL DEFAULT 1,
db/migrations/020_add_async_job_schema.sql-25-    next_attempt_at DATETIME(6) NULL,
db/migrations/020_add_async_job_schema.sql-26-    progress_pct DECIMAL(5, 2) NULL,
db/migrations/020_add_async_job_schema.sql-27-    progress_message TEXT NULL,
db/migrations/020_add_async_job_schema.sql-28-    last_error_code VARCHAR(128) NULL,
db/migrations/020_add_async_job_schema.sql-29-    last_error_message TEXT NULL,
db/migrations/020_add_async_job_schema.sql-30-    cancelled_by INT NULL,
db/migrations/020_add_async_job_schema.sql:31:    active_request_hash CHAR(64)
db/migrations/020_add_async_job_schema.sql-32-        GENERATED ALWAYS AS (
db/migrations/020_add_async_job_schema.sql-33-            CASE
db/migrations/020_add_async_job_schema.sql:34:                WHEN status IN ('queued', 'running', 'cancel_requested') THEN request_hash
db/migrations/020_add_async_job_schema.sql-35-                WHEN status = 'failed'
db/migrations/020_add_async_job_schema.sql-36-                     AND attempt_count < max_attempts
db/migrations/020_add_async_job_schema.sql:37:                     AND next_attempt_at IS NOT NULL THEN request_hash
db/migrations/020_add_async_job_schema.sql-38-                ELSE NULL
db/migrations/020_add_async_job_schema.sql-39-            END
db/migrations/020_add_async_job_schema.sql-40-        ) STORED,
db/migrations/020_add_async_job_schema.sql-41-    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
db/migrations/020_add_async_job_schema.sql-42-    result_json JSON NULL,
db/migrations/020_add_async_job_schema.sql-43-    KEY idx_async_jobs_claim (status, queue_name, priority, scheduled_at, next_attempt_at, submitted_at),
db/migrations/020_add_async_job_schema.sql-44-    KEY idx_async_jobs_claim_expiry (status, claim_expires_at),
db/migrations/020_add_async_job_schema.sql-45-    KEY idx_async_jobs_history (submitted_at),
db/migrations/020_add_async_job_schema.sql:46:    UNIQUE KEY idx_async_jobs_active_request_hash (job_type, active_request_hash),
db/migrations/020_add_async_job_schema.sql-47-    CONSTRAINT fk_async_jobs_submitted_by
db/migrations/020_add_async_job_schema.sql-48-        FOREIGN KEY (submitted_by) REFERENCES user(user_id) ON DELETE RESTRICT
db/migrations/020_add_async_job_schema.sql-49-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
db/migrations/020_add_async_job_schema.sql-50-
db/migrations/020_add_async_job_schema.sql-51-CREATE TABLE async_job_events (
db/migrations/020_add_async_job_schema.sql-52-    event_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
db/migrations/020_add_async_job_schema.sql-53-    job_id CHAR(36) NOT NULL,
db/migrations/020_add_async_job_schema.sql-54-    event_type VARCHAR(64) NOT NULL,
db/migrations/020_add_async_job_schema.sql-55-    event_message TEXT NULL,
db/migrations/020_add_async_job_schema.sql-56-    event_payload_json JSON NULL,
--
db/migrations/000_initialize_base_schema.sql-269-  PRIMARY KEY (`results_file_id`)
db/migrations/000_initialize_base_schema.sql-270-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
db/migrations/000_initialize_base_schema.sql-271-
db/migrations/000_initialize_base_schema.sql-272-CREATE TABLE IF NOT EXISTS `table_hash` (
db/migrations/000_initialize_base_schema.sql-273-  `hash_id` int NOT NULL AUTO_INCREMENT,
db/migrations/000_initialize_base_schema.sql-274-  `hash_256` varchar(64) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-275-  `json_text` text,
db/migrations/000_initialize_base_schema.sql-276-  `target_endpoint` varchar(100) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-277-  `entry_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/000_initialize_base_schema.sql-278-  PRIMARY KEY (`hash_id`),
db/migrations/000_initialize_base_schema.sql:279:  UNIQUE KEY `hash_256_UNIQUE` (`hash_256`)
db/migrations/000_initialize_base_schema.sql-280-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
db/migrations/000_initialize_base_schema.sql-281-
db/migrations/000_initialize_base_schema.sql-282-CREATE TABLE IF NOT EXISTS `user` (
db/migrations/000_initialize_base_schema.sql-283-  `user_id` int NOT NULL AUTO_INCREMENT,
db/migrations/000_initialize_base_schema.sql-284-  `user_name` varchar(50) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-285-  `password` varchar(50) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-286-  `email` varchar(50) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-287-  `orcid` varchar(50) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-288-  `abbreviation` varchar(50) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-289-  `first_name` varchar(100) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-290-  `family_name` varchar(100) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-291-  `user_role` char(15) NOT NULL DEFAULT 'Viewer',
db/migrations/000_initialize_base_schema.sql-292-  `comment` varchar(250) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-293-  `terms_agreed` tinyint DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-294-  `approved` tinyint DEFAULT '0',
db/migrations/000_initialize_base_schema.sql-295-  `rereview_request` tinyint DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-296-  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/000_initialize_base_schema.sql-297-  `password_reset_date` timestamp NULL DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-298-  PRIMARY KEY (`user_id`),
db/migrations/000_initialize_base_schema.sql:299:  UNIQUE KEY `user_name` (`user_name`),
db/migrations/000_initialize_base_schema.sql:300:  UNIQUE KEY `orcid` (`orcid`),
db/migrations/000_initialize_base_schema.sql:301:  UNIQUE KEY `email` (`email`)
db/migrations/000_initialize_base_schema.sql-302-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
db/migrations/000_initialize_base_schema.sql-303-
db/migrations/000_initialize_base_schema.sql-304-CREATE TABLE IF NOT EXISTS `variation_ontology_list` (
db/migrations/000_initialize_base_schema.sql-305-  `vario_id` varchar(10) NOT NULL,
db/migrations/000_initialize_base_schema.sql-306-  `vario_name` varchar(100) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-307-  `definition` varchar(1000) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-308-  `obsolete` tinyint DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-309-  `is_active` tinyint DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-310-  `sort` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-311-  `update_date` timestamp NULL DEFAULT NULL,
--
db/migrations/000_initialize_base_schema.sql-317-  `hgnc_id` varchar(10) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-318-  `hpo_mode_of_inheritance_term` varchar(10) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-319-  `disease_ontology_id_version` varchar(20) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-320-  `ndd_phenotype` tinyint DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-321-  `entry_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/000_initialize_base_schema.sql-322-  `entry_source` char(100) NOT NULL DEFAULT 'sysndd',
db/migrations/000_initialize_base_schema.sql-323-  `entry_user_id` int NOT NULL,
db/migrations/000_initialize_base_schema.sql-324-  `is_active` tinyint DEFAULT '1',
db/migrations/000_initialize_base_schema.sql-325-  `replaced_by` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-326-  PRIMARY KEY (`entity_id`),
db/migrations/000_initialize_base_schema.sql:327:  UNIQUE KEY `entity_quadruple` (`hgnc_id`, `hpo_mode_of_inheritance_term`, `disease_ontology_id_version`, `ndd_phenotype`),
db/migrations/000_initialize_base_schema.sql-328-  KEY `hpo_mode_of_inheritance_term` (`hpo_mode_of_inheritance_term`),
db/migrations/000_initialize_base_schema.sql-329-  KEY `disease_ontology_id_version` (`disease_ontology_id_version`),
db/migrations/000_initialize_base_schema.sql-330-  KEY `entry_user_id` (`entry_user_id`),
db/migrations/000_initialize_base_schema.sql-331-  KEY `replaced_by` (`replaced_by`),
db/migrations/000_initialize_base_schema.sql-332-  CONSTRAINT `ndd_entity_ibfk_1` FOREIGN KEY (`hgnc_id`) REFERENCES `non_alt_loci_set` (`hgnc_id`),
db/migrations/000_initialize_base_schema.sql-333-  CONSTRAINT `ndd_entity_ibfk_2` FOREIGN KEY (`hpo_mode_of_inheritance_term`) REFERENCES `mode_of_inheritance_list` (`hpo_mode_of_inheritance_term`),
db/migrations/000_initialize_base_schema.sql-334-  CONSTRAINT `ndd_entity_ibfk_3` FOREIGN KEY (`disease_ontology_id_version`) REFERENCES `disease_ontology_set` (`disease_ontology_id_version`),
db/migrations/000_initialize_base_schema.sql-335-  CONSTRAINT `ndd_entity_ibfk_4` FOREIGN KEY (`entry_user_id`) REFERENCES `user` (`user_id`),
db/migrations/000_initialize_base_schema.sql-336-  CONSTRAINT `ndd_entity_ibfk_5` FOREIGN KEY (`replaced_by`) REFERENCES `ndd_entity` (`entity_id`)
db/migrations/000_initialize_base_schema.sql-337-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
--
db/migrations/000_initialize_base_schema.sql-383-
db/migrations/000_initialize_base_schema.sql-384-CREATE TABLE IF NOT EXISTS `ndd_review_phenotype_connect` (
db/migrations/000_initialize_base_schema.sql-385-  `review_phenotype_id` int NOT NULL AUTO_INCREMENT,
db/migrations/000_initialize_base_schema.sql-386-  `review_id` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-387-  `phenotype_id` varchar(10) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-388-  `modifier_id` double DEFAULT '1',
db/migrations/000_initialize_base_schema.sql-389-  `entity_id` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-390-  `phenotype_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/000_initialize_base_schema.sql-391-  `is_active` tinyint DEFAULT '1',
db/migrations/000_initialize_base_schema.sql-392-  PRIMARY KEY (`review_phenotype_id`),
db/migrations/000_initialize_base_schema.sql:393:  UNIQUE KEY `phenotype_quintuple` (`review_id`, `phenotype_id`, `modifier_id`, `entity_id`, `is_active`),
db/migrations/000_initialize_base_schema.sql-394-  KEY `phenotype_id` (`phenotype_id`),
db/migrations/000_initialize_base_schema.sql-395-  CONSTRAINT `ndd_review_phenotype_connect_ibfk_1` FOREIGN KEY (`review_id`) REFERENCES `ndd_entity_review` (`review_id`),
db/migrations/000_initialize_base_schema.sql-396-  CONSTRAINT `ndd_review_phenotype_connect_ibfk_2` FOREIGN KEY (`phenotype_id`) REFERENCES `phenotype_list` (`phenotype_id`)
db/migrations/000_initialize_base_schema.sql-397-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
db/migrations/000_initialize_base_schema.sql-398-
db/migrations/000_initialize_base_schema.sql-399-CREATE TABLE IF NOT EXISTS `ndd_review_publication_join` (
db/migrations/000_initialize_base_schema.sql-400-  `review_publication_id` int NOT NULL AUTO_INCREMENT,
db/migrations/000_initialize_base_schema.sql-401-  `review_id` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-402-  `entity_id` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-403-  `publication_id` varchar(15) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-404-  `publication_type` varchar(50) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-405-  `is_reviewed` tinyint DEFAULT '1',
db/migrations/000_initialize_base_schema.sql-406-  PRIMARY KEY (`review_publication_id`),
db/migrations/000_initialize_base_schema.sql:407:  UNIQUE KEY `review_triple` (`review_id`, `entity_id`, `publication_id`),
db/migrations/000_initialize_base_schema.sql-408-  KEY `publication_id` (`publication_id`),
db/migrations/000_initialize_base_schema.sql-409-  CONSTRAINT `ndd_review_publication_join_ibfk_1` FOREIGN KEY (`review_id`) REFERENCES `ndd_entity_review` (`review_id`),
db/migrations/000_initialize_base_schema.sql-410-  CONSTRAINT `ndd_review_publication_join_ibfk_2` FOREIGN KEY (`publication_id`) REFERENCES `publication` (`publication_id`)
db/migrations/000_initialize_base_schema.sql-411-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
db/migrations/000_initialize_base_schema.sql-412-
db/migrations/000_initialize_base_schema.sql-413-CREATE TABLE IF NOT EXISTS `ndd_review_variation_ontology_connect` (
db/migrations/000_initialize_base_schema.sql-414-  `review_vario_id` int NOT NULL AUTO_INCREMENT,
db/migrations/000_initialize_base_schema.sql-415-  `review_id` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-416-  `vario_id` varchar(10) DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-417-  `modifier_id` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-418-  `entity_id` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-419-  `variation_ontology_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/000_initialize_base_schema.sql-420-  `is_active` tinyint DEFAULT '1',
db/migrations/000_initialize_base_schema.sql-421-  PRIMARY KEY (`review_vario_id`),
db/migrations/000_initialize_base_schema.sql:422:  UNIQUE KEY `phenotype_quintuple` (`review_id`, `vario_id`, `modifier_id`, `entity_id`, `is_active`),
db/migrations/000_initialize_base_schema.sql-423-  KEY `vario_id` (`vario_id`),
db/migrations/000_initialize_base_schema.sql-424-  CONSTRAINT `ndd_review_variation_ontology_connect_ibfk_1` FOREIGN KEY (`review_id`) REFERENCES `ndd_entity_review` (`review_id`),
db/migrations/000_initialize_base_schema.sql-425-  CONSTRAINT `ndd_review_variation_ontology_connect_ibfk_2` FOREIGN KEY (`vario_id`) REFERENCES `variation_ontology_list` (`vario_id`)
db/migrations/000_initialize_base_schema.sql-426-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
db/migrations/000_initialize_base_schema.sql-427-
db/migrations/000_initialize_base_schema.sql-428-CREATE TABLE IF NOT EXISTS `re_review_assignment` (
db/migrations/000_initialize_base_schema.sql-429-  `assignment_id` int NOT NULL AUTO_INCREMENT,
db/migrations/000_initialize_base_schema.sql-430-  `user_id` int NOT NULL,
db/migrations/000_initialize_base_schema.sql-431-  `re_review_batch` int DEFAULT NULL,
db/migrations/000_initialize_base_schema.sql-432-  PRIMARY KEY (`assignment_id`),
api/functions/analyses-functions.R-372-    select(-ncbiTaxonId, -inputGenes, -preferredNames) %>%
api/functions/analyses-functions.R-373-    arrange(fdr)
api/functions/analyses-functions.R-374-
api/functions/analyses-functions.R-375-  # return result
api/functions/analyses-functions.R-376-  return(enrichment_tibble)
api/functions/analyses-functions.R-377-}
api/functions/analyses-functions.R-378-
api/functions/analyses-functions.R-379-
api/functions/analyses-functions.R:380:generate_ndd_hgnc_ids <- function() {
api/functions/analyses-functions.R-381-  pool %>%
api/functions/analyses-functions.R-382-    dplyr::tbl("ndd_entity_view") %>%
api/functions/analyses-functions.R-383-    dplyr::arrange(entity_id) %>%
api/functions/analyses-functions.R-384-    dplyr::filter(ndd_phenotype == 1) %>%
api/functions/analyses-functions.R-385-    dplyr::select(hgnc_id) %>%
api/functions/analyses-functions.R-386-    dplyr::collect() %>%
api/functions/analyses-functions.R-387-    unique()
api/functions/analyses-functions.R-388-}
--
api/functions/analysis-snapshot-repository.R-528-  )
api/functions/analysis-snapshot-repository.R-529-  if (is.null(manifest) ||
api/functions/analysis-snapshot-repository.R-530-    (is.data.frame(manifest) && nrow(manifest) == 0L)) {
api/functions/analysis-snapshot-repository.R-531-    return(FALSE)
api/functions/analysis-snapshot-repository.R-532-  }
api/functions/analysis-snapshot-repository.R-533-  identical(as.character(manifest$status_code)[1], "available")
api/functions/analysis-snapshot-repository.R-534-}
api/functions/analysis-snapshot-repository.R-535-
api/functions/analysis-snapshot-repository.R:536:analysis_snapshot_source_data_version <- function(conn = NULL) {
api/functions/analysis-snapshot-repository.R-537-  result <- db_execute_query(
api/functions/analysis-snapshot-repository.R-538-    "SELECT source_data_version
api/functions/analysis-snapshot-repository.R-539-       FROM mcp_public_analysis_source_version
api/functions/analysis-snapshot-repository.R-540-      LIMIT 1",
api/functions/analysis-snapshot-repository.R-541-    conn = conn
api/functions/analysis-snapshot-repository.R-542-  )
api/functions/analysis-snapshot-repository.R-543-
api/functions/analysis-snapshot-repository.R-544-  as.character(result$source_data_version[[1]])

codex
One contract-level issue has emerged in the validation responses: the required allowed-category set is included for unknown values, but omitted for supplied-empty selectors and for valid selectors resolving to fewer than two genes. I’m doing the final static contract sweep now.
exec
/bin/bash -lc "git diff --check origin/master...HEAD -- ':(exclude).planning/**'
printf '\\nChanged code file line counts (>600):\\n'
for file in "'$(git diff --name-only origin/master...HEAD -- '"':(exclude).planning/**' | rg '"'^(api|app)/.*'"\\.(R|ts|vue|js)"'$'"'); do lines="'$(wc -l < "$file"); if [ "$lines" -gt 600 ]; then printf '"'%s %s\\n' \""'$lines" "$file"; fi; done
printf '"'\\nPotential bare masked calls in added R lines:\\n'
git diff --unified=0 origin/master...HEAD -- 'api/**/*.R' | rg '"'^'"\\+["'^+].*'"\\b(select|filter|arrange|mutate|left_join|get)\\(' || true
printf '\\ncreate_job formal contract:\\n'
sed -n '30,44p' api/functions/job-manager.R
printf '\\n#574 public-ready writes/references in changed API code:\\n'
git diff --unified=0 origin/master...HEAD -- api | rg '"'^'"\\+["'^+].*public_ready'"' || true" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:

Changed code file line counts (>600):
754 api/tests/testthat/test-unit-async-job-worker.R

Potential bare masked calls in added R lines:
+    dplyr::filter(is_active == 1) %>%
+    dplyr::select(category) %>%
+    dplyr::arrange(entity_id) %>%
+    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
+    dplyr::select(hgnc_id) %>%
+    hgnc_ids <- unique(dplyr::pull(dplyr::filter(tbl, ndd_phenotype == 1), hgnc_id))
+    # base::get(), not bare get(): a fully-loaded API/worker R session has
+    old_pool <- if (exists("pool", envir = .GlobalEnv)) base::get("pool", envir = .GlobalEnv) else NULL
+test_that("pool lookup uses base::get() so config::get masking (loaded API/worker env) cannot break it", {
+  # (Codex review fix: previously a bare `get("pool", envir = .GlobalEnv)`).
+# dbplyr pipeline (`tbl()` / `filter()` / `select()` / `collect()`) is
+  expect_identical(r$hgnc_ids, c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5")) # arrange(entity_id)+distinct, ndd_phenotype==1

create_job formal contract:
#' \dontrun{
#' result <- create_job(
#'   operation = "clustering",
#'   params = list(genes = c("BRCA1", "TP53"))
#' )
#' }
create_job <- function(operation, params) {
  submitted <- async_job_service_submit(
    job_type = operation,
    request_payload = params
  )

  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL

  list(

#574 public-ready writes/references in changed API code:
+#* `public_ready` -- they are ephemeral job results, distinct from the public

codex
HIGH — `api/services/job-functional-submission-service.R:104`, `api/functions/clustering-gene-universe.R:49,77`

- `{"category_filter":null}`, `{"category_filter":[]}`, or a valid selector resolving to one gene returns 400, but its message omits the required allowed active-category set. This violates the locked error contract.
- Fix: obtain/pass the active category list for these branches and append `Allowed active categories: …` to each 400 message.

LOW — `api/tests/testthat/test-unit-async-job-worker.R:754`

- The touched test source exceeds the requested 600-line ceiling.
- Fix: extract cohesive runtime-loader/setup coverage into a helper or sibling test file.

**VERDICT: NO-SHIP — 1 HIGH**
tokens used
143,134
HIGH — `api/services/job-functional-submission-service.R:104`, `api/functions/clustering-gene-universe.R:49,77`

- `{"category_filter":null}`, `{"category_filter":[]}`, or a valid selector resolving to one gene returns 400, but its message omits the required allowed active-category set. This violates the locked error contract.
- Fix: obtain/pass the active category list for these branches and append `Allowed active categories: …` to each 400 message.

LOW — `api/tests/testthat/test-unit-async-job-worker.R:754`

- The touched test source exceeds the requested 600-line ceiling.
- Fix: extract cohesive runtime-loader/setup coverage into a helper or sibling test file.

**VERDICT: NO-SHIP — 1 HIGH**
