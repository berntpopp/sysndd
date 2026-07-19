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
session id: 019f77ac-72f4-7763-97d4-f408255ea990
--------
user
You previously reviewed feature #574 (category-selected gene universes for functional clustering) on this branch and returned NO-SHIP with 2 HIGH, 1 MEDIUM, 1 LOW findings. Those have been addressed in new commits. Re-review the CURRENT diff of the branch vs master: run `git diff origin/master...HEAD -- ':(exclude).planning/**'`. Read touched files in full.

## The 4 findings that were supposed to be fixed — VERIFY each is actually fixed (and correctly):
1. **HIGH** — `{"genes":[], "category_filter":["X"]}` must now 400 (mutual exclusion on genes KEY present, not just non-empty). Verify an empty `genes` array + a category is rejected, while `{"genes":[]}` ALONE still falls through to the all-NDD default (must NOT have regressed), and `{"genes":["HGNC:1"]}` alone is still explicit.
2. **HIGH** — `clustering_cached_source_data_version()` must be fail-closed: an `NA`/empty/non-scalar source version must NOT be cached or returned; it must throw so the service returns 503. Verify both the fetched-value and any cached-value paths validate, and that a transient invalid value doesn't poison the cache for the TTL.
3. **MEDIUM** — `resolved_gene_count` must equal the distinct-gene count (consistent with `gene_list_sha256`'s sorted-unique), WITHOUT deduping the payload `genes` list (explicit payload `genes` must stay byte-identical to today).
4. **LOW** — the integration test's `pool` rebinding must use `base::get(..., envir=)` (config::get masks bare get).

## Then do a FRESH adversarial pass on the whole #574 diff for anything you did NOT flag before — especially:
- New asymmetries introduced by the fixes (e.g. the mutual-exclusion change breaking a valid request shape; the count change diverging between the cache-hit meta and the create_job payload).
- The test-file split (`test-unit-job-endpoint-services.R` → a new sibling file): did any test get dropped, weakened, or duplicated in the split? Are both files coherent and under 600 lines?
- The fail-closed source-version validator: any path where an exception escapes as a raw 500 instead of the intended 503 `PROVENANCE_UNAVAILABLE`?
- Re-confirm the locked contract from the first review (entity-level resolution; NULL/absent→default cache parity; supplied-empty→400; <2 genes→400; allowed set in the error MESSAGE; selector-aware dedup additive-only; provenance shape incl. effective_fingerprint on both cache-hit and worker paths; never public_ready; dbplyr `%in%` not string interpolation; `dplyr::`/`base::get` namespacing).

## Output
For each finding: severity (BLOCKER / HIGH / MEDIUM / LOW), file:line, concrete failure scenario, and fix. Confirm explicitly whether each of the 4 prior findings is now resolved. Final line: **VERDICT: SHIP** (zero BLOCKER/HIGH) or **VERDICT: NO-SHIP** with the count.
codex
I’ll re-review the live branch diff against `origin/master`, validate each prior finding with the relevant tests and implementation paths, then run a separate adversarial pass for regressions. I’m using the repository’s code-quality, API-testing, and security review guides because this change spans API validation, durable-job provenance, and test coverage.
exec
/bin/bash -lc "pwd && sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-code-quality/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-api-testing/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-security-bug-scan/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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

exec
/bin/bash -lc "sed -n '1,260p' .agents/skills/sysndd-async-jobs/SKILL.md && sed -n '1,240p' /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md && git status --short && git diff --check origin/master...HEAD -- ':(exclude).planning/**' && git diff --stat origin/master...HEAD -- ':(exclude).planning/**' && git diff --name-status origin/master...HEAD -- ':(exclude).planning/**' && git diff --find-renames --find-copies --no-ext-diff origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
---
name: sysndd-async-jobs
description: Use when adding or changing durable async jobs, worker-executed code, job handlers, queue lanes or priorities in SysNDD — or diagnosing why a submitted job never runs, stays queued, or fails with "No durable async job handler registered"
---

# SysNDD Async Jobs & Workers

Use this skill before touching any durable background job or worker-executed code. Jobs are durable and MySQL-backed: the web API submits and serves status; a separate **worker** claims and executes. Worker code is sourced **once at worker startup** — a change is not live until the worker restarts.

## Mental Model

- Submit: `create_job()` → `async_job_service_submit()` inserts a row. `job_type` is `VARCHAR(64)` with **no enum and no submit-side allowlist** — a typo or unregistered type inserts fine and only fails later, at execution.
- Execute: the worker claims by `priority ASC, scheduled_at ASC`, then looks the type up in `async_job_handler_registry` (`async-job-handlers.R`). **Unregistered type → the claimed job hard-fails** with "No durable async job handler registered for '<type>'".
- Two lanes (#486): `default` (interactive) and `maintenance` (heavy/bulk/external), drained by the `worker` and `worker-maintenance` containers respectively.

## Adding a Durable Job Type

1. **Define the executor** (e.g. `widget_refresh_async(params)`) in a `functions/` file.
2. **Register the file in `bootstrap/load_modules.R`** (`function_files`). This single loader is used by both the API and the durable worker (`start_async_worker.R`). Adding it only to `setup_workers.R` (mirai legacy parity) is **not** enough — durable jobs do not run on the mirai pool.
3. **Register the handler** in `async_job_handler_registry`: `run = .async_job_run_passthrough("widget_refresh_async")` (lazy-resolves by name, like `comparisons_update`) or a dedicated runner, plus a `cancel_mode` and `after_success`.
4. **Route the lane/priority** in `async-job-service.R`: add heavy/external types to `ASYNC_MAINTENANCE_JOB_TYPES` (→ `maintenance` queue, priority 50). Interactive types get priority 10 in `async_job_priority_for_type()`. Lane/priority are resolved at **submit time**, so the submitter must run new code too.
5. **External calls** inside the job must go through `external_proxy_budget()` / `make_external_request()` (enforced by `test-unit-external-budget-guard.R`) — never a hardcoded `req_timeout()`. An external-heavy **batch** must reset the per-request accumulator per call (see `.pubtatornidd_reset_external_budget()`), and the worker resets it per job (`external_proxy_request_reset()` in `async-job-worker.R`).
6. **Secrets** used by the job must be added to the `worker` **and** `worker-maintenance` `environment:` maps in `docker-compose.yml`. Compose uses explicit env maps — a bare `.env` value is invisible to the container otherwise.

## Operational — Restart the Worker

After changing worker-executed code (handlers, executors, `load_modules.R`): **restart `worker` and `worker-maintenance`**. Bind-mounted `.R` files are not hot-reloaded inside a running worker. Restart the `api`/submitter too when lane routing or a submit endpoint changed. Local dev runs one `worker` draining `default,maintenance` (`docker-compose.override.yml`); prod keeps the two containers as a deliberate mirror — only `ASYNC_JOB_QUEUES` differs.

## Verify

Submit a job; confirm the worker logs claim it on the expected lane and it completes (not `failed` with the "no handler" message). The two most-missed steps are **registering the handler** and **restarting the worker**.

## Common Mistakes

| Symptom | Cause |
|---|---|
| Job inserts but immediately `failed` | Handler not in `async_job_handler_registry` |
| Handler exists but old behavior runs | Worker not restarted after code change |
| Function-not-found at run time | New file not added to `bootstrap/load_modules.R` |
| Heavy job blocks interactive work | Type missing from `ASYNC_MAINTENANCE_JOB_TYPES` (stuck on `default`) |
| External calls 503 mid-batch | Per-call budget not reset in a batch job |
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
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-review.md
 AGENTS.md                                          |   2 +
 CHANGELOG.md                                       |  47 +++
 api/bootstrap/load_modules.R                       |   6 +
 api/endpoints/jobs_endpoints.R                     |  35 +-
 api/functions/async-job-handlers.R                 |  35 +-
 api/functions/clustering-gene-universe.R           | 157 ++++++++
 api/services/job-functional-submission-service.R   | 179 ++++++++--
 .../testthat/job-endpoint-services-fixtures.R      |  10 +
 .../test-integration-clustering-category-submit.R  | 206 +++++++++++
 api/tests/testthat/test-unit-async-job-handlers.R  |   4 +
 api/tests/testthat/test-unit-async-job-worker.R    |   3 +
 .../testthat/test-unit-clustering-gene-universe.R  | 278 +++++++++++++++
 .../testthat/test-unit-clustering-handler-meta.R   | 145 ++++++++
 .../test-unit-job-endpoint-services-phenotype.R    | 223 ++++++++++++
 .../testthat/test-unit-job-endpoint-services.R     | 393 +++++++++++++--------
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 documentation/08-development.qmd                   |  15 +
 19 files changed, 1543 insertions(+), 203 deletions(-)
M	AGENTS.md
M	CHANGELOG.md
M	api/bootstrap/load_modules.R
M	api/endpoints/jobs_endpoints.R
M	api/functions/async-job-handlers.R
A	api/functions/clustering-gene-universe.R
M	api/services/job-functional-submission-service.R
M	api/tests/testthat/job-endpoint-services-fixtures.R
A	api/tests/testthat/test-integration-clustering-category-submit.R
M	api/tests/testthat/test-unit-async-job-handlers.R
M	api/tests/testthat/test-unit-async-job-worker.R
A	api/tests/testthat/test-unit-clustering-gene-universe.R
A	api/tests/testthat/test-unit-clustering-handler-meta.R
A	api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
M	api/tests/testthat/test-unit-job-endpoint-services.R
M	api/version_spec.json
M	app/package-lock.json
M	app/package.json
M	documentation/08-development.qmd
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
diff --git a/api/bootstrap/load_modules.R b/api/bootstrap/load_modules.R
index 512a3065..09f44069 100644
--- a/api/bootstrap/load_modules.R
+++ b/api/bootstrap/load_modules.R
@@ -134,6 +134,12 @@ bootstrap_load_modules <- function() {
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
diff --git a/api/endpoints/jobs_endpoints.R b/api/endpoints/jobs_endpoints.R
index 4ffad4c5..b4ef4f08 100644
--- a/api/endpoints/jobs_endpoints.R
+++ b/api/endpoints/jobs_endpoints.R
@@ -24,11 +24,44 @@
 
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
diff --git a/api/functions/async-job-handlers.R b/api/functions/async-job-handlers.R
index d3691475..9eccf745 100644
--- a/api/functions/async-job-handlers.R
+++ b/api/functions/async-job-handlers.R
@@ -19,6 +19,10 @@
 #     publication refresh/backfill)
 # Restart the worker container after changing any of these (worker-executed
 # code is sourced once at startup).
+# NOTE: .async_job_run_clustering assembles its result meta via
+# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
+# worker/API entrypoint sources that module via bootstrap_load_modules() before
+# this file; a direct-source test env must source it too (as the async-job tests do).
 
 .async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
   invisible(result)
@@ -96,6 +100,11 @@
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
@@ -108,14 +117,30 @@
 
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
+  meta <- clustering_result_meta(
+    list(
+      algorithm = algorithm,
+      gene_count = length(genes),
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
index 150c61e0..7c20f0a9 100644
--- a/api/services/job-functional-submission-service.R
+++ b/api/services/job-functional-submission-service.R
@@ -24,8 +24,16 @@
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
@@ -41,10 +49,26 @@ svc_job_submit_functional_clustering <- function(req, res) {
 
   # Extract request data before durable submission.
 
-  # Connection objects cannot cross process boundaries
-  genes_list <- NULL
-  if (!is.null(req$argsBody$genes)) {
-    genes_list <- req$argsBody$genes
+  # Connection objects cannot cross process boundaries. `genes` and
+  # `category_filter` are mutually exclusive gene-universe selectors (#574):
+  # an explicit gene list, a curated-category selection, or (both absent) the
+  # existing default all-NDD-genes universe. Presence is decided from the RAW
+  # request field, not a length check, so an explicitly-empty category_filter
+  # still reaches (and is rejected by) the resolver instead of silently
+  # falling through to the all-NDD default.
+  genes_in <- req$argsBody$genes
+  category_supplied <- !is.null(req$argsBody$category_filter)
+  # Mutual exclusion is gated on KEY PRESENCE (`genes_supplied`), not a length
+  # check -- `{"genes":[], "category_filter":["X"]}` supplies BOTH keys and
+  # must 400 even though the `genes` array is empty (Codex review fix: an
+  # empty-but-present `genes` array previously bypassed this guard because
+  # `has_genes` -- used below for the LATER branch-selection decision, kept
+  # unchanged -- is also FALSE on an empty array).
+  genes_supplied <- !is.null(genes_in)
+  has_genes <- !is.null(genes_in) && length(genes_in) > 0
+
+  if (genes_supplied && category_supplied) {
+    stop_for_bad_request("Provide either genes or category_filter, not both")
   }
 
   # Extract algorithm parameter (default: leiden)
@@ -62,17 +86,24 @@ svc_job_submit_functional_clustering <- function(req, res) {
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
+  } else if (category_supplied) {
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
@@ -83,8 +114,14 @@ svc_job_submit_functional_clustering <- function(req, res) {
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
@@ -96,6 +133,54 @@ svc_job_submit_functional_clustering <- function(req, res) {
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
@@ -150,24 +235,41 @@ svc_job_submit_functional_clustering <- function(req, res) {
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
@@ -209,14 +311,19 @@ svc_job_submit_functional_clustering <- function(req, res) {
   }
 
   # Cache miss - create async job
+  job_params <- list(
+    genes = genes_list,
+    algorithm = algorithm,
+    category_links = category_links,
+    string_id_table = string_id_table,
+    provenance = provenance
+  )
+  if (!is.null(selector_chr)) {
+    job_params$category_filter <- selector_chr
+  }
   result <- create_job(
     operation = "clustering",
-    params = list(
-      genes = genes_list,
-      algorithm = algorithm,
-      category_links = category_links,
-      string_id_table = string_id_table
-    )
+    params = job_params
   )
 
   # Check capacity
diff --git a/api/tests/testthat/job-endpoint-services-fixtures.R b/api/tests/testthat/job-endpoint-services-fixtures.R
index 103f4621..d2deaae1 100644
--- a/api/tests/testthat/job-endpoint-services-fixtures.R
+++ b/api/tests/testthat/job-endpoint-services-fixtures.R
@@ -22,9 +22,19 @@ library(tidyr)
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
diff --git a/api/tests/testthat/test-unit-clustering-gene-universe.R b/api/tests/testthat/test-unit-clustering-gene-universe.R
new file mode 100644
index 00000000..ec0c4bc5
--- /dev/null
+++ b/api/tests/testthat/test-unit-clustering-gene-universe.R
@@ -0,0 +1,278 @@
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
+test_that("supplied-but-empty selector is 400 (NOT the all-NDD default)", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+
+  expect_error(e$clustering_resolve_category_universe(list(), conn = con), class = "error_400")
+  expect_error(e$clustering_resolve_category_universe(list("   "), conn = con), class = "error_400")
+})
+
+test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job)", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+
+  expect_error(e$clustering_resolve_category_universe("Refuted", conn = con), class = "error_400") # 0 genes
+  expect_error(e$clustering_resolve_category_universe("Moderate", conn = con), class = "error_400") # 1 gene
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
index 00000000..0bdbf7fa
--- /dev/null
+++ b/api/tests/testthat/test-unit-clustering-handler-meta.R
@@ -0,0 +1,145 @@
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
diff --git a/api/tests/testthat/test-unit-job-endpoint-services.R b/api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
similarity index 56%
copy from api/tests/testthat/test-unit-job-endpoint-services.R
copy to api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
index 3bb4b43f..e9e69f6b 100644
--- a/api/tests/testthat/test-unit-job-endpoint-services.R
+++ b/api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
@@ -1,20 +1,20 @@
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
@@ -30,163 +30,6 @@ if (exists("get_api_dir")) {
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
diff --git a/api/tests/testthat/test-unit-job-endpoint-services.R b/api/tests/testthat/test-unit-job-endpoint-services.R
index 3bb4b43f..d998316d 100644
--- a/api/tests/testthat/test-unit-job-endpoint-services.R
+++ b/api/tests/testthat/test-unit-job-endpoint-services.R
@@ -1,13 +1,16 @@
 # tests/testthat/test-unit-job-endpoint-services.R
 #
-# Host-runnable unit tests for the PUBLIC clustering submission services extracted
+# Host-runnable unit tests for the PUBLIC clustering submission service extracted
 # from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
-# submission-service.R and job-phenotype-submission-service.R. The maintenance-
-# submission (job-maintenance-submission-service.R) and query-endpoint
-# (job-query-endpoint-service.R) services are covered in the sibling
+# submission-service.R. The sibling job-phenotype-submission-service.R coverage
+# lives in test-unit-job-endpoint-services-phenotype.R (split out here, #574
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
@@ -48,6 +51,30 @@ job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
   job_endpoint_fake_pool(env, tables)
 }
 
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
 test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
   env <- job_endpoint_source_service("job-functional-submission-service.R")
   env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
@@ -55,6 +82,7 @@ test_that("functional clustering: default genes are drawn from ndd_entity_view w
     hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
     ndd_phenotype = c(1L, 0L, 1L)
   ))
+  job_endpoint_stub_all_ndd_universe(env)
   captured <- NULL
   env$check_duplicate_job <- function(operation, params) {
     captured <<- params
@@ -97,8 +125,14 @@ test_that("functional clustering: cache hit stores a completed job without calli
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
@@ -121,6 +155,15 @@ test_that("functional clustering: cache hit stores a completed job without calli
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
 })
 
 test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
@@ -128,6 +171,7 @@ test_that("functional clustering: capacity guard (503) then a cache miss under c
 
   env <- job_endpoint_source_service("job-functional-submission-service.R")
   env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
   env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   env$async_job_capacity_exceeded <- function(...) TRUE
   env$async_job_active_count <- function(...) 99L
@@ -153,8 +197,11 @@ test_that("functional clustering: capacity guard (503) then a cache miss under c
   expect_equal(create_job_operation, "clustering")
   expect_setequal(
     names(create_job_params),
-    c("genes", "algorithm", "category_links", "string_id_table")
+    # #574 D2: every submit path now carries a `provenance` block; explicit/
+    # no-arg submits still omit `category_filter` (asserted separately below).
+    c("genes", "algorithm", "category_links", "string_id_table", "provenance")
   )
+  expect_false("category_filter" %in% names(create_job_params))
 })
 
 test_that("functional clustering: admission throttle runs FIRST, before any DB/cache work", {
@@ -188,193 +235,225 @@ test_that("functional clustering: admission throttle runs FIRST, before any DB/c
 })
 
 ## -------------------------------------------------------------------##
-## job-phenotype-submission-service.R
+## job-functional-submission-service.R: category_filter (#574 D2)
 ## -------------------------------------------------------------------##
 
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
   res <- job_endpoint_fake_res()
 
-  env$svc_job_submit_phenotype_clustering(req, res)
+  expect_error(
+    env$svc_job_submit_functional_clustering(req, res),
+    class = "error_400"
+  )
+})
 
-  # Only review_id 1 (primary + approved) survives the gather step; review 2
-  # (unapproved) and review 3 (not primary) must never reach the clustering
-  # input, even though review 2 is attached to the same (otherwise-included)
-  # entity_id as review 1.
-  expect_equal(captured_params$ndd_entity_review_tbl$review_id, 1L)
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
 })
 
-test_that("phenotype clustering: duplicate job returns 409 with Location", {
-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
-  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
-  env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = "dup-pheno")
-  req <- list(user = list(user_id = NULL))
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
   res <- job_endpoint_fake_res()
 
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
+  out <- env$svc_job_submit_functional_clustering(req, res)
 
+  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   expect_equal(res$status, 409)
   expect_equal(out$error, "DUPLICATE_JOB")
-  expect_match(res$headers[["Location"]], "/api/jobs/dup-pheno/status")
 })
 
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
+test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
+  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
+    expect_identical(category_filter, list("Definitive"))
+    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
   }
-  store_args <- NULL
-  env$async_job_service_store_completed <- function(...) {
-    store_args <<- list(...)
-    tibble::tibble(job_id = "cached-pheno-1")
+  env$check_duplicate_job <- function(operation, params) {
+    expect_true("category_filter" %in% names(params))
+    expect_identical(params$category_filter, "Definitive")
+    list(duplicate = FALSE)
   }
-  create_job_called <- FALSE
-  env$create_job <- function(...) create_job_called <<- TRUE
-  req <- list(user = list(user_id = 7L))
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  env$async_job_active_count <- function(...) 0L
+  captured <- NULL
+  env$create_job <- function(operation, params) {
+    captured <<- params
+    list(job_id = "j1", status = "accepted", estimated_seconds = 5)
+  }
+  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
 
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
+  out <- env$svc_job_submit_functional_clustering(req, res)
 
-  expect_false(create_job_called)
   expect_equal(res$status, 202)
-  expect_equal(out$job_id, "cached-pheno-1")
-  expect_equal(store_args$submitted_by, 7L)
+  expect_identical(captured$category_filter, "Definitive")
+  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
+  expect_identical(captured$provenance$selector$kind, "category")
+  expect_identical(captured$provenance$selector$category_filter, "Definitive")
+  expect_true(all(
+    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
+      names(captured$provenance)
+  ))
 })
 
-test_that("phenotype clustering: capacity guard (503) then a cache miss under capacity (202)", {
-  req <- list(user = list(user_id = NULL))
-
-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
-  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
+test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
+  # Explicit genes.
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
   env$check_duplicate_job <- function(...) list(duplicate = FALSE)
-  env$async_job_capacity_exceeded <- function(...) TRUE
-  env$async_job_active_count <- function(...) 5L
-  res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
-  expect_equal(res$status, 503)
-  expect_equal(res$headers[["Retry-After"]], "60")
-  expect_equal(out$error, "CAPACITY_EXCEEDED")
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  env$async_job_active_count <- function(...) 0L
+  captured_explicit <- NULL
+  env$create_job <- function(operation, params) {
+    captured_explicit <<- params
+    list(job_id = "j2", status = "accepted", estimated_seconds = 5)
+  }
+  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
+  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
+
+  expect_false("category_filter" %in% names(captured_explicit))
+  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
+  expect_null(captured_explicit$provenance$selector$category_filter)
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
+  env2$create_job <- function(operation, params) {
+    captured_no_arg <<- params
+    list(job_id = "j3", status = "accepted", estimated_seconds = 5)
+  }
+  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
+  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
+
+  expect_false("category_filter" %in% names(captured_no_arg))
+  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
+  expect_null(captured_no_arg$provenance$selector$category_filter)
+})
 
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
   env$async_job_capacity_exceeded <- function(...) FALSE
-  create_job_params <- NULL
+  env$async_job_active_count <- function(...) 0L
+  captured <- NULL
   env$create_job <- function(operation, params) {
-    create_job_params <<- params
-    list(job_id = "new-pheno-1", status = "accepted", estimated_seconds = 30)
+    captured <<- params
+    list(job_id = "j-dup-genes", status = "accepted", estimated_seconds = 5)
   }
+  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
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
+
+  env$svc_job_submit_functional_clustering(req, res)
+
+  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
+  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
 })
 
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
   }
-  succeed()
+  g <- c("HGNC:1", "HGNC:5")
+
+  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
+  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
+  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
 })
 
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
+test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  env$analysis_string_cache_fingerprint <- function() "fp-test"
+  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
+  env$clustering_cached_source_data_version <- function(...) stop("boom")
+  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   create_job_called <- FALSE
   env$create_job <- function(...) {
     create_job_called <<- TRUE
     NULL
   }
-  env$async_job_submit_admission_guard <- function(req, res) {
-    res$status <- 429
-    res$setHeader("Retry-After", "42")
-    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
-  }
+  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_phenotype_clustering(list(user = list(user_id = NULL)), res)
-  expect_equal(res$status, 429)
-  expect_equal(out$error, "RATE_LIMITED")
-  expect_false(pool_touched)
+
+  out <- env$svc_job_submit_functional_clustering(req, res)
+
+  expect_equal(res$status, 503L)
+  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   expect_false(create_job_called)
 })
+
+# job-phenotype-submission-service.R coverage lives in
+# test-unit-job-endpoint-services-phenotype.R (split out to keep this file under
+# the 600-line ceiling, #574 Codex-review-fix pass).
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

codex
The diff is scoped to 19 files and is clean under `git diff --check`. I’m now reading every touched file in its current form and comparing the pre-split test file from `origin/master`, so the test coverage assessment is based on the actual post-fix tree rather than the commit summary.
exec
/bin/bash -lc 'wc -l AGENTS.md CHANGELOG.md api/bootstrap/load_modules.R api/endpoints/jobs_endpoints.R api/functions/async-job-handlers.R api/functions/clustering-gene-universe.R api/services/job-functional-submission-service.R api/tests/testthat/job-endpoint-services-fixtures.R api/tests/testthat/test-integration-clustering-category-submit.R api/tests/testthat/test-unit-async-job-handlers.R api/tests/testthat/test-unit-async-job-worker.R api/tests/testthat/test-unit-clustering-gene-universe.R api/tests/testthat/test-unit-clustering-handler-meta.R api/tests/testthat/test-unit-job-endpoint-services-phenotype.R api/tests/testthat/test-unit-job-endpoint-services.R api/version_spec.json app/package-lock.json app/package.json documentation/08-development.qmd && nl -ba api/functions/clustering-gene-universe.R && nl -ba api/services/job-functional-submission-service.R && nl -ba api/endpoints/jobs_endpoints.R && nl -ba api/functions/async-job-handlers.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
    284 AGENTS.md
   1272 CHANGELOG.md
    288 api/bootstrap/load_modules.R
    174 api/endpoints/jobs_endpoints.R
    392 api/functions/async-job-handlers.R
    157 api/functions/clustering-gene-universe.R
    347 api/services/job-functional-submission-service.R
     60 api/tests/testthat/job-endpoint-services-fixtures.R
    206 api/tests/testthat/test-integration-clustering-category-submit.R
    266 api/tests/testthat/test-unit-async-job-handlers.R
    754 api/tests/testthat/test-unit-async-job-worker.R
    278 api/tests/testthat/test-unit-clustering-gene-universe.R
    145 api/tests/testthat/test-unit-clustering-handler-meta.R
    223 api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
    459 api/tests/testthat/test-unit-job-endpoint-services.R
     14 api/version_spec.json
  20508 app/package-lock.json
    135 app/package.json
    458 documentation/08-development.qmd
  26420 total
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
    55	  # existing default all-NDD-genes universe. Presence is decided from the RAW
    56	  # request field, not a length check, so an explicitly-empty category_filter
    57	  # still reaches (and is rejected by) the resolver instead of silently
    58	  # falling through to the all-NDD default.
    59	  genes_in <- req$argsBody$genes
    60	  category_supplied <- !is.null(req$argsBody$category_filter)
    61	  # Mutual exclusion is gated on KEY PRESENCE (`genes_supplied`), not a length
    62	  # check -- `{"genes":[], "category_filter":["X"]}` supplies BOTH keys and
    63	  # must 400 even though the `genes` array is empty (Codex review fix: an
    64	  # empty-but-present `genes` array previously bypassed this guard because
    65	  # `has_genes` -- used below for the LATER branch-selection decision, kept
    66	  # unchanged -- is also FALSE on an empty array).
    67	  genes_supplied <- !is.null(genes_in)
    68	  has_genes <- !is.null(genes_in) && length(genes_in) > 0
    69	
    70	  if (genes_supplied && category_supplied) {
    71	    stop_for_bad_request("Provide either genes or category_filter, not both")
    72	  }
    73	
    74	  # Extract algorithm parameter (default: leiden)
    75	  # Ensure we get a scalar value (JSON may pass arrays)
    76	  algorithm <- "leiden"
    77	  if (!is.null(req$argsBody$algorithm)) {
    78	    algo_input <- req$argsBody$algorithm
    79	    # Handle array input - always take first element if vector
    80	    if (is.list(algo_input) || length(algo_input) >= 1) {
    81	      algo_input <- algo_input[[1]]
    82	    }
    83	    algorithm <- tolower(as.character(algo_input))
    84	    if (!algorithm %in% c("leiden", "walktrap")) {
    85	      algorithm <- "leiden"
    86	    }
    87	  }
    88	
    89	  # Resolve the clustering gene universe + selector provenance (#574). The
    90	  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
    91	  # from before this feature: `clustering_resolve_category_universe(NULL)`
    92	  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
    93	  # so cache parity (memoise key = gene set + algorithm) is preserved.
    94	  selector_chr <- NULL
    95	  if (has_genes) {
    96	    genes_list <- as.character(unlist(genes_in))
    97	    kind <- "explicit"
    98	  } else if (category_supplied) {
    99	    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
   100	    genes_list <- universe$hgnc_ids
   101	    selector_chr <- universe$selector
   102	    kind <- "category"
   103	  } else {
   104	    universe <- clustering_resolve_category_universe(NULL)
   105	    genes_list <- universe$hgnc_ids
   106	    kind <- "all_ndd"
   107	  }
   108	
   109	  # Pre-fetch the STRING ID table because DB connections cannot cross the
   110	  # durable worker boundary.
   111	  string_id_table <- pool %>%
   112	    dplyr::tbl("non_alt_loci_set") %>%
   113	    dplyr::filter(!is.na(STRING_id)) %>%
   114	    dplyr::select(symbol, hgnc_id, STRING_id) %>%
   115	    dplyr::collect()
   116	
   117	  # Check for duplicate job (include algorithm in check). The selector is
   118	  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
   119	  # submits keep the pre-#574 dedup identity byte-identical.
   120	  dup_params <- list(genes = genes_list, algorithm = algorithm)
   121	  if (!is.null(selector_chr)) {
   122	    dup_params$category_filter <- selector_chr
   123	  }
   124	  dup_check <- check_duplicate_job("clustering", dup_params)
   125	  if (dup_check$duplicate) {
   126	    res$status <- 409
   127	    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
   128	    return(list(
   129	      error = "DUPLICATE_JOB",
   130	      message = "Identical job already running",
   131	      existing_job_id = dup_check$existing_job_id,
   132	      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
   133	    ))
   134	  }
   135	
   136	  # Cheap-path provenance (no expensive query yet). `selector_obj` records
   137	  # WHICH universe was resolved; `intended_fingerprint` records the STRING
   138	  # cache identity + fixed clustering params this submit intends to run
   139	  # with. The *effective* fingerprint (e.g. the STRING weight channel a
   140	  # computed result actually used) is only knowable from a computed result,
   141	  # so it is recorded separately in the cache-hit result meta below.
   142	  selector_obj <- list(kind = kind, category_filter = selector_chr)
   143	  intended_fingerprint <- list(
   144	    string_cache_fingerprint = analysis_string_cache_fingerprint(),
   145	    score_threshold = 400L,
   146	    algorithm = algorithm,
   147	    seed = 42L
   148	  )
   149	  gene_sha <- clustering_gene_list_sha256(genes_list)
   150	  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
   151	  # count must agree with it, so it is computed from the SAME dedup -- an
   152	  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
   153	  # not report a resolved count that disagrees with a singleton sha256. This
   154	  # never dedups the payload `genes` list itself (`genes_list` stays
   155	  # byte-identical to the raw request) -- only the reported COUNT (Codex
   156	  # review fix).
   157	  resolved_count <- length(unique(genes_list))
   158	
   159	  # Source-data version: a CACHED, fail-closed read, fetched only now that a
   160	  # payload is actually about to be built -- its backing view runs global
   161	  # counts/joins, so it must never run before admission/dedup. A lookup
   162	  # failure must never silently record NA/broken provenance; fail the
   163	  # request closed instead.
   164	  src_ver <- tryCatch(
   165	    clustering_cached_source_data_version(conn = pool),
   166	    error = function(e) e
   167	  )
   168	  if (inherits(src_ver, "error")) {
   169	    res$status <- 503L
   170	    return(list(
   171	      error = "PROVENANCE_UNAVAILABLE",
   172	      message = "Snapshot source-data version unavailable; retry shortly."
   173	    ))
   174	  }
   175	
   176	  provenance <- list(
   177	    selector = selector_obj,
   178	    resolved_gene_count = resolved_count,
   179	    gene_list_sha256 = gene_sha,
   180	    intended_fingerprint = intended_fingerprint,
   181	    source_data_version = src_ver
   182	  )
   183	
   184	  # Define category links (needed for result)
   185	  category_links <- tibble::tibble(
   186	    value = c(
   187	      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
   188	      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
   189	      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
   190	    ),
   191	    link = c(
   192	      "https://www.ebi.ac.uk/QuickGO/term/",
   193	      "https://www.ebi.ac.uk/QuickGO/term/",
   194	      "https://disease-ontology.org/term/",
   195	      "https://www.ebi.ac.uk/QuickGO/term/",
   196	      "https://hpo.jax.org/browse/term/",
   197	      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
   198	      "https://www.genome.jp/dbget-bin/www_bget?",
   199	      "https://www.uniprot.org/keywords/",
   200	      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
   201	      "https://www.ebi.ac.uk/interpro/entry/pfam/",
   202	      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
   203	      "https://www.ebi.ac.uk/QuickGO/term/",
   204	      "https://reactome.org/content/detail/R-",
   205	      "http://www.ebi.ac.uk/interpro/entry/smart/",
   206	      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
   207	      "https://www.wikipathways.org/index.php/Pathway:"
   208	    )
   209	  )
   210	
   211	  # Cache-first: if the memoized function already has a cached result,
   212	  # return it immediately without submitting a durable worker job.
   213	  # The network_edges endpoint (graph) warms this cache on first load,
   214	  # so subsequent table requests resolve instantly.
   215	  cache_hit <- tryCatch(
   216	    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
   217	    error = function(e) FALSE
   218	  )
   219	
   220	  if (cache_hit) {
   221	    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
   222	
   223	    categories <- cached_clusters %>%
   224	      dplyr::select(term_enrichment) %>%
   225	      tidyr::unnest(cols = c(term_enrichment)) %>%
   226	      dplyr::select(category) %>%
   227	      unique() %>%
   228	      dplyr::arrange(category) %>%
   229	      dplyr::mutate(
   230	        text = dplyr::case_when(
   231	          nchar(category) <= 5 ~ category,
   232	          nchar(category) > 5 ~ stringr::str_to_sentence(category)
   233	        )
   234	      ) %>%
   235	      dplyr::select(value = category, text) %>%
   236	      dplyr::left_join(category_links, by = c("value"))
   237	
   238	    # Splice the base cache-hit fields with `provenance` (already assembled
   239	    # above as selector/resolved_gene_count/gene_list_sha256/
   240	    # intended_fingerprint/source_data_version) via the shared
   241	    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
   242	    # re-listing the same fields as duplicate literals -- keeps this shape in
   243	    # lockstep with the worker-run handler's result meta by construction.
   244	    # `effective_fingerprint` is only knowable from the computed result
   245	    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
   246	    cache_result <- list(
   247	      clusters = cached_clusters,
   248	      categories = categories,
   249	      meta = clustering_result_meta(
   250	        list(
   251	          algorithm = algorithm,
   252	          gene_count = resolved_count,
   253	          cluster_count = nrow(cached_clusters),
   254	          cache_hit = TRUE
   255	        ),
   256	        provenance,
   257	        attr(cached_clusters, "weight_channel")
   258	      )
   259	    )
   260	    cache_request_payload <- list(
   261	      genes = genes_list,
   262	      algorithm = algorithm,
   263	      category_links = category_links,
   264	      string_id_table = string_id_table,
   265	      provenance = provenance
   266	    )
   267	    if (!is.null(selector_chr)) {
   268	      cache_request_payload$category_filter <- selector_chr
   269	    }
   270	    completed_job <- async_job_service_store_completed(
   271	      job_type = "clustering",
   272	      request_payload = cache_request_payload,
   273	      result = cache_result,
   274	      submitted_by = req$user$user_id %||% NULL,
   275	      queue_name = "analysis",
   276	      priority = 50L
   277	    )
   278	    job_id <- completed_job$job_id[[1]]
   279	
   280	    res$status <- 202
   281	    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   282	    res$setHeader("Retry-After", "0")
   283	
   284	    return(list(
   285	      job_id = job_id,
   286	      status = "accepted",
   287	      estimated_seconds = 0,
   288	      status_url = paste0("/api/jobs/", job_id, "/status"),
   289	      meta = list(llm_generation = "snapshot_refresh_owned")
   290	    ))
   291	  }
   292	
   293	  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   294	  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   295	  if (async_job_capacity_exceeded(
   296	        tryCatch(
   297	          async_job_active_count("default"),
   298	          error = function(e) {
   299	            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
   300	            0L
   301	          }
   302	        )
   303	      )) {
   304	    res$status <- 503
   305	    res$setHeader("Retry-After", "60")
   306	    return(list(
   307	      error = "CAPACITY_EXCEEDED",
   308	      message = "Analysis queue is at capacity. Please retry shortly.",
   309	      retry_after = 60
   310	    ))
   311	  }
   312	
   313	  # Cache miss - create async job
   314	  job_params <- list(
   315	    genes = genes_list,
   316	    algorithm = algorithm,
   317	    category_links = category_links,
   318	    string_id_table = string_id_table,
   319	    provenance = provenance
   320	  )
   321	  if (!is.null(selector_chr)) {
   322	    job_params$category_filter <- selector_chr
   323	  }
   324	  result <- create_job(
   325	    operation = "clustering",
   326	    params = job_params
   327	  )
   328	
   329	  # Check capacity
   330	  if (!is.null(result$error)) {
   331	    res$status <- 503
   332	    res$setHeader("Retry-After", as.character(result$retry_after))
   333	    return(result)
   334	  }
   335	
   336	  # Success - return HTTP 202 Accepted
   337	  res$status <- 202
   338	  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
   339	  res$setHeader("Retry-After", "5")
   340	
   341	  list(
   342	    job_id = result$job_id,
   343	    status = result$status,
   344	    estimated_seconds = result$estimated_seconds,
   345	    status_url = paste0("/api/jobs/", result$job_id, "/status")
   346	  )
   347	}
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
   129	  meta <- clustering_result_meta(
   130	    list(
   131	      algorithm = algorithm,
   132	      gene_count = length(genes),
   133	      cluster_count = nrow(clusters),
   134	      cache_hit = FALSE
   135	    ),
   136	    provenance,
   137	    attr(clusters, "weight_channel")
   138	  )
   139	
   140	  list(
   141	    clusters = clusters,
   142	    categories = .async_job_functional_categories(clusters, category_links),
   143	    meta = meta
   144	  )
   145	}
   146	
   147	.async_job_chain_llm <- function(result, job, cluster_type) {
   148	  if (!exists("trigger_llm_batch_generation", mode = "function")) {
   149	    return(invisible(result))
   150	  }
   151	
   152	  llm_clusters <- result
   153	
   154	  if (is.list(result) && "clusters" %in% names(result) && !is.null(result[["clusters"]])) {
   155	    llm_clusters <- result[["clusters"]]
   156	  }
   157	
   158	  trigger_llm_batch_generation(
   159	    clusters = llm_clusters,
   160	    cluster_type = cluster_type,
   161	    parent_job_id = job$job_id[[1]]
   162	  )
   163	
   164	  invisible(result)
   165	}
   166	
   167	.async_job_phenotype_matrix <- function(payload) {
   168	  sysndd_db_phenotypes <- payload$ndd_entity_view_tbl |>
   169	    dplyr::left_join(payload$ndd_review_phenotype_connect_tbl, by = "entity_id") |>
   170	    dplyr::left_join(payload$modifier_list_tbl, by = "modifier_id") |>
   171	    dplyr::left_join(payload$phenotype_list_tbl, by = "phenotype_id") |>
   172	    dplyr::mutate(ndd_phenotype = dplyr::case_when(
   173	      ndd_phenotype == 1 ~ "Yes",
   174	      ndd_phenotype == 0 ~ "No",
   175	      TRUE ~ ndd_phenotype
   176	    )) |>
   177	    dplyr::filter(ndd_phenotype == "Yes") |>
   178	    dplyr::filter(category %in% payload$categories) |>
   179	    dplyr::filter(modifier_name == "present") |>
   180	    dplyr::filter(review_id %in% payload$ndd_entity_review_tbl$review_id) |>
   181	    dplyr::select(
   182	      entity_id, hpo_mode_of_inheritance_term_name, phenotype_id,
   183	      HPO_term, hgnc_id
   184	    ) |>
   185	    dplyr::group_by(entity_id) |>
   186	    dplyr::mutate(
   187	      phenotype_non_id_count = sum(!(phenotype_id %in% payload$id_phenotype_ids)),
   188	      phenotype_id_count = sum(phenotype_id %in% payload$id_phenotype_ids)
   189	    ) |>
   190	    dplyr::ungroup() |>
   191	    unique()
   192	
   193	  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes |>
   194	    dplyr::mutate(present = "yes") |>
   195	    dplyr::select(-phenotype_id) |>
   196	    tidyr::pivot_wider(names_from = HPO_term, values_from = present) |>
   197	    dplyr::group_by(hgnc_id) |>
   198	    dplyr::mutate(gene_entity_count = dplyr::n()) |>
   199	    dplyr::ungroup() |>
   200	    dplyr::relocate(gene_entity_count, .after = phenotype_id_count) |>
   201	    dplyr::select(-hgnc_id)
   202	
   203	  phenotype_df <- sysndd_db_phenotypes_wider |>
   204	    dplyr::select(-entity_id) |>
   205	    as.data.frame()
   206	  row.names(phenotype_df) <- sysndd_db_phenotypes_wider$entity_id
   207	
   208	  # #508 MCA feature hygiene via the shared helper (same as
   209	  # generate_phenotype_cluster_input) so the interactive/durable clustering job
   210	  # produces the cleaned partition and can't diverge from the public snapshot.
   211	  phenotype_df <- phenotype_mca_prep_matrix(
   212	    phenotype_df,
   213	    hpo_lookup = dplyr::select(payload$phenotype_list_tbl, HPO_term, phenotype_id)
   214	  )
   215	
   216	  phenotype_df
   217	}
   218	
   219	.async_job_run_phenotype_clustering <- function(job, payload, state, worker_config) {
   220	  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
   221	
   222	  progress("prepare_matrix", "Preparing phenotype matrix...", current = 0, total = 2)
   223	  phenotype_matrix <- .async_job_phenotype_matrix(payload)
   224	  progress("cluster", "Running phenotype clustering...", current = 1, total = 2)
   225	  phenotype_clusters <- gen_mca_clust_obj(phenotype_matrix)
   226	  progress("complete", "Phenotype clustering complete", current = 2, total = 2)
   227	
   228	  identifiers <- payload$ndd_entity_view_tbl |>
   229	    dplyr::select(entity_id, hgnc_id, symbol)
   230	
   231	  phenotype_clusters |>
   232	    tidyr::unnest(identifiers) |>
   233	    dplyr::mutate(entity_id = as.integer(entity_id)) |>
   234	    dplyr::left_join(identifiers, by = "entity_id") |>
   235	    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
   236	}
   237	
   238	.async_job_run_ontology_update <- function(job, payload, state, worker_config) {
   239	  progress <- .async_job_progress_reporter(job$job_id[[1]])
   240	
   241	  progress("init", "Preparing ontology update", current = 0, total = 4)
   242	  disease_ontology_set <- process_combine_ontology(
   243	    hgnc_list = payload$hgnc_list,
   244	    mode_of_inheritance_list = payload$mode_of_inheritance_list,
   245	    max_file_age = 0,
   246	    output_path = "data/",
   247	    progress_callback = progress
   248	  )
   249	  progress("complete", "Ontology update complete", current = 4, total = 4)
   250	
   251	  list(
   252	    status = "completed",
   253	    rows_processed = nrow(disease_ontology_set),
   254	    sources = c("MONDO", "OMIM"),
   255	    output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
   256	  )
   257	}
   258	
   259	.async_job_run_passthrough <- function(fn_name) {
   260	  force(fn_name)
   261	
   262	  function(job, payload, state, worker_config) {
   263	    fn <- base::get(fn_name, mode = "function")
   264	    fn(.async_job_add_job_id(payload, job))
   265	  }
   266	}
   267	
   268	async_job_handler_registry <- list(
   269	  clustering = list(
   270	    cancel_mode = "best_effort",
   271	    run = .async_job_run_clustering,
   272	    after_success = function(result, job, payload, state, worker_config) {
   273	      .async_job_chain_llm(result, job, cluster_type = "functional")
   274	    }
   275	  ),
   276	  phenotype_clustering = list(
   277	    cancel_mode = "best_effort",
   278	    run = .async_job_run_phenotype_clustering,
   279	    after_success = function(result, job, payload, state, worker_config) {
   280	      .async_job_chain_llm(result, job, cluster_type = "phenotype")
   281	    }
   282	  ),
   283	  ontology_update = list(
   284	    cancel_mode = "non_interruptible",
   285	    run = .async_job_run_ontology_update,
   286	    after_success = .async_job_after_success_noop
   287	  ),
   288	  hgnc_update = list(
   289	    cancel_mode = "non_interruptible",
   290	    run = .async_job_run_hgnc_update,
   291	    after_success = .async_job_after_success_noop
   292	  ),
   293	  comparisons_update = list(
   294	    cancel_mode = "non_interruptible",
   295	    run = .async_job_run_passthrough("comparisons_update_async"),
   296	    after_success = .async_job_after_success_noop
   297	  ),
   298	  pubtator_update = list(
   299	    cancel_mode = "best_effort",
   300	    run = .async_job_run_pubtator,
   301	    after_success = .async_job_after_success_noop
   302	  ),
   303	  pubtator_enrichment_refresh = list(
   304	    cancel_mode = "best_effort",
   305	    run = .async_job_run_pubtator_enrichment,
   306	    after_success = .async_job_after_success_noop
   307	  ),
   308	  pubtatornidd_nightly = list(
   309	    cancel_mode = "non_interruptible",
   310	    run = .async_job_run_pubtatornidd_nightly,
   311	    after_success = .async_job_after_success_noop
   312	  ),
   313	  disease_ontology_mapping_refresh = list(
   314	    cancel_mode = "non_interruptible",
   315	    run = .async_job_run_disease_ontology_mapping_refresh,
   316	    after_success = .async_job_after_success_noop
   317	  ),
   318	  nddscore_import = list(
   319	    cancel_mode = "non_interruptible",
   320	    run = .async_job_run_nddscore_import,
   321	    after_success = .async_job_after_success_noop
   322	  ),
   323	  llm_generation = list(
   324	    cancel_mode = "best_effort",
   325	    run = .async_job_run_passthrough("llm_batch_executor"),
   326	    after_success = .async_job_after_success_noop
   327	  ),
   328	  network_layout_prewarm = list(
   329	    cancel_mode = "best_effort",
   330	    run = function(...) .async_job_run_network_layout_prewarm(...),
   331	    after_success = .async_job_after_success_noop
   332	  ),
   333	  analysis_snapshot_refresh = list(
   334	    cancel_mode = "best_effort",
   335	    run = function(...) .async_job_run_analysis_snapshot_refresh(...),
   336	    after_success = .async_job_after_success_noop
   337	  ),
   338	  backup_create = list(
   339	    cancel_mode = "non_interruptible",
   340	    run = .async_job_run_backup_create,
   341	    after_success = .async_job_after_success_noop
   342	  ),
   343	  backup_restore = list(
   344	    cancel_mode = "non_interruptible",
   345	    run = .async_job_run_backup_restore,
   346	    after_success = .async_job_after_success_noop
   347	  ),
   348	  omim_update = list(
   349	    cancel_mode = "non_interruptible",
   350	    run = .async_job_run_omim_update,
   351	    after_success = .async_job_after_success_noop
   352	  ),
   353	  force_apply_ontology = list(
   354	    cancel_mode = "non_interruptible",
   355	    run = .async_job_run_force_apply_ontology,
   356	    after_success = .async_job_after_success_noop
   357	  ),
   358	  publication_refresh = list(
   359	    cancel_mode = "best_effort",
   360	    run = .async_job_run_publication_refresh,
   361	    after_success = .async_job_after_success_noop
   362	  ),
   363	  publication_date_backfill = list(
   364	    cancel_mode = "non_interruptible",
   365	    run = .async_job_run_publication_date_backfill,
   366	    after_success = .async_job_after_success_noop
   367	  )
   368	)
   369	
   370	#' Resolve a durable async job handler definition
   371	#' @param job_type Character async job type.
   372	#' @param registry Named handler registry.
   373	#'
   374	#' @return Registry entry with run/cancel metadata.
   375	#' @export
   376	async_job_get_handler <- function(job_type, registry = async_job_handler_registry) {
   377	  entry <- registry[[job_type]]
   378	
   379	  if (is.null(entry)) {
   380	    stop(sprintf("No durable async job handler registered for '%s'", job_type), call. = FALSE)
   381	  }
   382	
   383	  if (!is.function(entry$run)) {
   384	    stop(sprintf("Handler registry entry for '%s' is missing a callable run function", job_type), call. = FALSE)
   385	  }
   386	
   387	  if (is.null(entry$after_success)) {
   388	    entry$after_success <- .async_job_after_success_noop
   389	  }
   390	
   391	  entry
   392	}

exec
/bin/bash -lc "nl -ba api/services/job-functional-submission-service.R | sed -n '150,380p'
nl -ba api/endpoints/jobs_endpoints.R | sed -n '1,190p'
nl -ba api/bootstrap/load_modules.R | sed -n '110,185p'
nl -ba api/tests/testthat/job-endpoint-services-fixtures.R
nl -ba api/tests/testthat/test-unit-clustering-gene-universe.R
nl -ba api/tests/testthat/test-unit-clustering-handler-meta.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
   150	  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
   151	  # count must agree with it, so it is computed from the SAME dedup -- an
   152	  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
   153	  # not report a resolved count that disagrees with a singleton sha256. This
   154	  # never dedups the payload `genes` list itself (`genes_list` stays
   155	  # byte-identical to the raw request) -- only the reported COUNT (Codex
   156	  # review fix).
   157	  resolved_count <- length(unique(genes_list))
   158	
   159	  # Source-data version: a CACHED, fail-closed read, fetched only now that a
   160	  # payload is actually about to be built -- its backing view runs global
   161	  # counts/joins, so it must never run before admission/dedup. A lookup
   162	  # failure must never silently record NA/broken provenance; fail the
   163	  # request closed instead.
   164	  src_ver <- tryCatch(
   165	    clustering_cached_source_data_version(conn = pool),
   166	    error = function(e) e
   167	  )
   168	  if (inherits(src_ver, "error")) {
   169	    res$status <- 503L
   170	    return(list(
   171	      error = "PROVENANCE_UNAVAILABLE",
   172	      message = "Snapshot source-data version unavailable; retry shortly."
   173	    ))
   174	  }
   175	
   176	  provenance <- list(
   177	    selector = selector_obj,
   178	    resolved_gene_count = resolved_count,
   179	    gene_list_sha256 = gene_sha,
   180	    intended_fingerprint = intended_fingerprint,
   181	    source_data_version = src_ver
   182	  )
   183	
   184	  # Define category links (needed for result)
   185	  category_links <- tibble::tibble(
   186	    value = c(
   187	      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
   188	      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
   189	      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
   190	    ),
   191	    link = c(
   192	      "https://www.ebi.ac.uk/QuickGO/term/",
   193	      "https://www.ebi.ac.uk/QuickGO/term/",
   194	      "https://disease-ontology.org/term/",
   195	      "https://www.ebi.ac.uk/QuickGO/term/",
   196	      "https://hpo.jax.org/browse/term/",
   197	      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
   198	      "https://www.genome.jp/dbget-bin/www_bget?",
   199	      "https://www.uniprot.org/keywords/",
   200	      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
   201	      "https://www.ebi.ac.uk/interpro/entry/pfam/",
   202	      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
   203	      "https://www.ebi.ac.uk/QuickGO/term/",
   204	      "https://reactome.org/content/detail/R-",
   205	      "http://www.ebi.ac.uk/interpro/entry/smart/",
   206	      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
   207	      "https://www.wikipathways.org/index.php/Pathway:"
   208	    )
   209	  )
   210	
   211	  # Cache-first: if the memoized function already has a cached result,
   212	  # return it immediately without submitting a durable worker job.
   213	  # The network_edges endpoint (graph) warms this cache on first load,
   214	  # so subsequent table requests resolve instantly.
   215	  cache_hit <- tryCatch(
   216	    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
   217	    error = function(e) FALSE
   218	  )
   219	
   220	  if (cache_hit) {
   221	    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
   222	
   223	    categories <- cached_clusters %>%
   224	      dplyr::select(term_enrichment) %>%
   225	      tidyr::unnest(cols = c(term_enrichment)) %>%
   226	      dplyr::select(category) %>%
   227	      unique() %>%
   228	      dplyr::arrange(category) %>%
   229	      dplyr::mutate(
   230	        text = dplyr::case_when(
   231	          nchar(category) <= 5 ~ category,
   232	          nchar(category) > 5 ~ stringr::str_to_sentence(category)
   233	        )
   234	      ) %>%
   235	      dplyr::select(value = category, text) %>%
   236	      dplyr::left_join(category_links, by = c("value"))
   237	
   238	    # Splice the base cache-hit fields with `provenance` (already assembled
   239	    # above as selector/resolved_gene_count/gene_list_sha256/
   240	    # intended_fingerprint/source_data_version) via the shared
   241	    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
   242	    # re-listing the same fields as duplicate literals -- keeps this shape in
   243	    # lockstep with the worker-run handler's result meta by construction.
   244	    # `effective_fingerprint` is only knowable from the computed result
   245	    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
   246	    cache_result <- list(
   247	      clusters = cached_clusters,
   248	      categories = categories,
   249	      meta = clustering_result_meta(
   250	        list(
   251	          algorithm = algorithm,
   252	          gene_count = resolved_count,
   253	          cluster_count = nrow(cached_clusters),
   254	          cache_hit = TRUE
   255	        ),
   256	        provenance,
   257	        attr(cached_clusters, "weight_channel")
   258	      )
   259	    )
   260	    cache_request_payload <- list(
   261	      genes = genes_list,
   262	      algorithm = algorithm,
   263	      category_links = category_links,
   264	      string_id_table = string_id_table,
   265	      provenance = provenance
   266	    )
   267	    if (!is.null(selector_chr)) {
   268	      cache_request_payload$category_filter <- selector_chr
   269	    }
   270	    completed_job <- async_job_service_store_completed(
   271	      job_type = "clustering",
   272	      request_payload = cache_request_payload,
   273	      result = cache_result,
   274	      submitted_by = req$user$user_id %||% NULL,
   275	      queue_name = "analysis",
   276	      priority = 50L
   277	    )
   278	    job_id <- completed_job$job_id[[1]]
   279	
   280	    res$status <- 202
   281	    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   282	    res$setHeader("Retry-After", "0")
   283	
   284	    return(list(
   285	      job_id = job_id,
   286	      status = "accepted",
   287	      estimated_seconds = 0,
   288	      status_url = paste0("/api/jobs/", job_id, "/status"),
   289	      meta = list(llm_generation = "snapshot_refresh_owned")
   290	    ))
   291	  }
   292	
   293	  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   294	  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   295	  if (async_job_capacity_exceeded(
   296	        tryCatch(
   297	          async_job_active_count("default"),
   298	          error = function(e) {
   299	            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
   300	            0L
   301	          }
   302	        )
   303	      )) {
   304	    res$status <- 503
   305	    res$setHeader("Retry-After", "60")
   306	    return(list(
   307	      error = "CAPACITY_EXCEEDED",
   308	      message = "Analysis queue is at capacity. Please retry shortly.",
   309	      retry_after = 60
   310	    ))
   311	  }
   312	
   313	  # Cache miss - create async job
   314	  job_params <- list(
   315	    genes = genes_list,
   316	    algorithm = algorithm,
   317	    category_links = category_links,
   318	    string_id_table = string_id_table,
   319	    provenance = provenance
   320	  )
   321	  if (!is.null(selector_chr)) {
   322	    job_params$category_filter <- selector_chr
   323	  }
   324	  result <- create_job(
   325	    operation = "clustering",
   326	    params = job_params
   327	  )
   328	
   329	  # Check capacity
   330	  if (!is.null(result$error)) {
   331	    res$status <- 503
   332	    res$setHeader("Retry-After", as.character(result$retry_after))
   333	    return(result)
   334	  }
   335	
   336	  # Success - return HTTP 202 Accepted
   337	  res$status <- 202
   338	  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
   339	  res$setHeader("Retry-After", "5")
   340	
   341	  list(
   342	    job_id = result$job_id,
   343	    status = result$status,
   344	    estimated_seconds = result$estimated_seconds,
   345	    status_url = paste0("/api/jobs/", result$job_id, "/status")
   346	  )
   347	}
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
     1	# tests/testthat/job-endpoint-services-fixtures.R
     2	#
     3	# Shared fixtures for the job-endpoint-service unit tests, split across two files
     4	# to keep each under the 600-line ceiling:
     5	#   - test-unit-job-endpoint-services.R              (functional + phenotype submission)
     6	#   - test-unit-job-endpoint-services-maintenance.R  (maintenance submission + query)
     7	# Both files EXPLICITLY source() this file at the top so they run standalone under a
     8	# single-file `testthat::test_file()` (a plain helper-*.R auto-load is not guaranteed
     9	# to run there); mirrors the pubmed-xml-fixtures.R convention.
    10	#
    11	# `pool %>% dplyr::tbl(name)` is faked with a small S3 dispatch trick: a "fake_pool"
    12	# object wrapping a named list of tibbles, plus one `tbl.fake_pool` method registered in
    13	# the environment the service was sourced into (S3 dispatch finds it there). This needs
    14	# no test DB / RSQLite, so every test is a real PASS on host R.
    15	
    16	library(dplyr)
    17	library(tidyr)
    18	
    19	#' Source a service file into a fresh child-of-globalenv environment.
    20	#'
    21	#' The two public clustering submit services now call `async_job_submit_admission_guard()`
    22	#' FIRST (#535 S6) before any DB/cache work; stub it to "admit" by default so these
    23	#' isolated tests exercise the downstream request/response logic. A test can override
    24	#' `env$async_job_submit_admission_guard` to exercise the throttle-block path.
    25	#'
    26	#' Also sources `functions/clustering-gene-universe.R` (#574 D1/D3) into `env` so
    27	#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
    28	#' `job-functional-submission-service.R`'s cache-hit path -- is available for real
    29	#' (a pure list-assembly function, safe to source unstubbed). Individual tests still
    30	#' stub the DB/cache-touching siblings from that same file
    31	#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
    32	#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
    33	#' this sourcing only supplies defaults those stubs override.
    34	job_endpoint_source_service <- function(filename) {
    35	  env <- new.env(parent = globalenv())
    36	  env$async_job_submit_admission_guard <- function(req, res) list(admitted = TRUE)
    37	  sys.source(file.path(get_api_dir(), "functions", "clustering-gene-universe.R"), envir = env)
    38	  sys.source(file.path(get_api_dir(), "services", filename), envir = env)
    39	  env
    40	}
    41	
    42	#' Register `tbl.fake_pool` in `env` and build a fake pool over `tables`.
    43	job_endpoint_fake_pool <- function(env, tables) {
    44	  env$tbl.fake_pool <- function(src, from, ...) src$tables[[from]]
    45	  structure(list(tables = tables), class = "fake_pool")
    46	}
    47	
    48	#' Minimal Plumber-response stand-in: an environment with `$status` and a
    49	#' `$setHeader()` that records every header set (mirrors the `res_env`
    50	#' pattern in test-unit-pubtator-enrichment.R).
    51	job_endpoint_fake_res <- function() {
    52	  res <- new.env()
    53	  res$status <- NULL
    54	  res$headers <- list()
    55	  res$setHeader <- function(name, value) {
    56	    res$headers[[name]] <- value
    57	    invisible(NULL)
    58	  }
    59	  res
    60	}
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
   113	test_that(".async_job_run_clustering: legacy payload with no provenance still returns a valid meta (backward compat)", {
   114	  e <- .clustering_handler_env()
   115	
   116	  payload <- list(
   117	    genes = c("HGNC:1", "HGNC:5", "HGNC:9"),
   118	    algorithm = "walktrap",
   119	    string_id_table = NULL,
   120	    category_links = NULL
   121	    # No `provenance` field -- mirrors an explicit/no-arg pre-#574 submit.
   122	  )
   123	
   124	  result <- NULL
   125	  expect_no_error({
   126	    result <- e$.async_job_run_clustering(
   127	      job = list(job_id = "j2"),
   128	      payload = payload,
   129	      state = NULL,
   130	      worker_config = NULL
   131	    )
   132	  })
   133	
   134	  meta <- result$meta
   135	
   136	  expect_identical(meta$algorithm, "walktrap")
   137	  expect_identical(meta$gene_count, 3L)
   138	  expect_identical(meta$cluster_count, 1L)
   139	  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
   140	  # No provenance fields leaked in when the payload never carried them.
   141	  expect_null(meta$selector)
   142	  expect_null(meta$gene_list_sha256)
   143	  expect_null(meta$source_data_version)
   144	  expect_null(meta$intended_fingerprint)
   145	})

exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-job-endpoint-services.R
nl -ba api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
nl -ba api/tests/testthat/test-integration-clustering-category-submit.R
printf '%s\\n' '--- test names: base vs current ---'
git show origin/master:api/tests/testthat/test-unit-job-endpoint-services.R | rg -n '"'^test_that'"\\('
printf '%s\\n' '--- current functional test names ---'
rg -n '"'^test_that'"\\(' api/tests/testthat/test-unit-job-endpoint-services.R
printf '%s\\n' '--- current phenotype test names ---'
rg -n '"'^test_that'"\\(' api/tests/testthat/test-unit-job-endpoint-services-phenotype.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# tests/testthat/test-unit-job-endpoint-services.R
     2	#
     3	# Host-runnable unit tests for the PUBLIC clustering submission service extracted
     4	# from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
     5	# submission-service.R. The sibling job-phenotype-submission-service.R coverage
     6	# lives in test-unit-job-endpoint-services-phenotype.R (split out here, #574
     7	# Codex-review-fix pass, to keep both files under the 600-line ceiling after this
     8	# file gained empty-genes/dedup-provenance coverage). The maintenance-submission
     9	# (job-maintenance-submission-service.R) and query-endpoint
    10	# (job-query-endpoint-service.R) services are covered in
    11	# test-unit-job-endpoint-services-maintenance.R. Shared fixtures live in
    12	# job-endpoint-services-fixtures.R (explicitly sourced below by every file in this
    13	# family). Split this way to keep every file under the 600-line ceiling (#535 S6).
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
    37	## job-functional-submission-service.R
    38	## -------------------------------------------------------------------##
    39	
    40	job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
    41	  tables <- list(
    42	    non_alt_loci_set = tibble::tibble(
    43	      symbol = c("A", "B"),
    44	      hgnc_id = c("HGNC:1", "HGNC:3"),
    45	      STRING_id = c("9606.P1", "9606.P2")
    46	    )
    47	  )
    48	  if (!is.null(ndd_entity_view)) {
    49	    tables$ndd_entity_view <- ndd_entity_view
    50	  }
    51	  job_endpoint_fake_pool(env, tables)
    52	}
    53	
    54	#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
    55	#' (#574 D2): reads `ndd_phenotype == 1` rows straight off `env$pool`'s fake
    56	#' `ndd_entity_view`, mirroring what the real resolver's NULL branch
    57	#' (`generate_ndd_hgnc_ids()`) would compute -- without needing the real
    58	#' function (and its DB-query internals) sourced into these isolated envs.
    59	job_endpoint_stub_all_ndd_universe <- function(env) {
    60	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
    61	    testthat::expect_null(category_filter)
    62	    tbl <- env$pool$tables$ndd_entity_view
    63	    hgnc_ids <- unique(dplyr::pull(dplyr::filter(tbl, ndd_phenotype == 1), hgnc_id))
    64	    list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids))
    65	  }
    66	}
    67	
    68	#' Cheap provenance stubs (#574 D2): every submit path that reaches past dedup
    69	#' now computes `intended_fingerprint`/`gene_list_sha256`/`source_data_version`
    70	#' regardless of selector kind, so any test reaching that far needs these
    71	#' three bare globals stubbed even when it does not care about their values.
    72	job_endpoint_stub_clustering_provenance <- function(env) {
    73	  env$analysis_string_cache_fingerprint <- function() "fp-test"
    74	  env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
    75	  env$clustering_cached_source_data_version <- function(...) "srcv-test"
    76	}
    77	
    78	test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
    79	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    80	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
    81	    entity_id = 1:3,
    82	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    83	    ndd_phenotype = c(1L, 0L, 1L)
    84	  ))
    85	  job_endpoint_stub_all_ndd_universe(env)
    86	  captured <- NULL
    87	  env$check_duplicate_job <- function(operation, params) {
    88	    captured <<- params
    89	    list(duplicate = TRUE, existing_job_id = "dup-1")
    90	  }
    91	  req <- list(argsBody = list(), user = list(user_id = NULL))
    92	  res <- job_endpoint_fake_res()
    93	
    94	  out <- env$svc_job_submit_functional_clustering(req, res)
    95	
    96	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
    97	  expect_equal(captured$algorithm, "leiden")
    98	  expect_equal(res$status, 409)
    99	  expect_equal(out$error, "DUPLICATE_JOB")
   100	  expect_match(res$headers[["Location"]], "/api/jobs/dup-1/status")
   101	})
   102	
   103	job_endpoint_capture_functional_algorithm <- function(algorithm_body) {
   104	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   105	  env$pool <- job_endpoint_functional_pool(env)
   106	  captured <- NULL
   107	  env$check_duplicate_job <- function(operation, params) {
   108	    captured <<- params
   109	    list(duplicate = TRUE, existing_job_id = "dup-1")
   110	  }
   111	  req <- list(argsBody = list(genes = list("HGNC:9"), algorithm = algorithm_body), user = list(user_id = NULL))
   112	  env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
   113	  captured$algorithm
   114	}
   115	
   116	test_that("functional clustering: algorithm input is coerced to a lowercase scalar, invalid falls back to leiden", {
   117	  expect_equal(job_endpoint_capture_functional_algorithm(list("WALKTRAP", "ignored")), "walktrap")
   118	  expect_equal(job_endpoint_capture_functional_algorithm("bogus"), "leiden")
   119	})
   120	
   121	test_that("functional clustering: cache hit stores a completed job without calling create_job", {
   122	  local_mocked_bindings(
   123	    has_cache = function(f) function(...) TRUE,
   124	    .package = "memoise"
   125	  )
   126	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   127	  env$pool <- job_endpoint_functional_pool(env)
   128	  job_endpoint_stub_clustering_provenance(env)
   129	  env$gen_string_clust_obj_mem <- function(genes, algorithm = "leiden") {
   130	    clusters <- tibble::tibble(term_enrichment = list(tibble::tibble(category = "HPO")))
   131	    # Set on the served membership, mirroring what the real STRING resolver
   132	    # attaches (#514 channel observability) -- the cache-hit meta must carry
   133	    # this through as `effective_fingerprint$weight_channel`.
   134	    attr(clusters, "weight_channel") <- "experimental_database"
   135	    clusters
   136	  }
   137	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   138	  store_args <- NULL
   139	  env$async_job_service_store_completed <- function(...) {
   140	    store_args <<- list(...)
   141	    tibble::tibble(job_id = "cached-job-1")
   142	  }
   143	  create_job_called <- FALSE
   144	  env$create_job <- function(...) {
   145	    create_job_called <<- TRUE
   146	  }
   147	  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = 42L))
   148	  res <- job_endpoint_fake_res()
   149	
   150	  out <- env$svc_job_submit_functional_clustering(req, res)
   151	
   152	  expect_false(create_job_called)
   153	  expect_equal(res$status, 202)
   154	  expect_equal(res$headers[["Retry-After"]], "0")
   155	  expect_equal(out$job_id, "cached-job-1")
   156	  expect_equal(out$meta$llm_generation, "snapshot_refresh_owned")
   157	  expect_equal(store_args$submitted_by, 42L)
   158	
   159	  # #574 D2 review fix: the cache-hit `result` (the job's stored, served
   160	  # payload -- distinct from `out`, the submit response) must carry the full
   161	  # provenance block through `meta`, not just the two fields asserted above.
   162	  result_meta <- store_args$result$meta
   163	  expect_equal(result_meta$effective_fingerprint$weight_channel, "experimental_database")
   164	  expect_equal(result_meta$selector$kind, "explicit")
   165	  expect_equal(result_meta$gene_list_sha256, "sha-1") # job_endpoint_stub_clustering_provenance: paste0("sha-", length(genes))
   166	  expect_equal(result_meta$source_data_version, "srcv-test") # job_endpoint_stub_clustering_provenance stub token
   167	})
   168	
   169	test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
   170	  req <- list(argsBody = list(genes = list("HGNC:1"), algorithm = "walktrap"), user = list(user_id = NULL))
   171	
   172	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   173	  env$pool <- job_endpoint_functional_pool(env)
   174	  job_endpoint_stub_clustering_provenance(env)
   175	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   176	  env$async_job_capacity_exceeded <- function(...) TRUE
   177	  env$async_job_active_count <- function(...) 99L
   178	  res <- job_endpoint_fake_res()
   179	  out <- env$svc_job_submit_functional_clustering(req, res)
   180	  expect_equal(res$status, 503)
   181	  expect_equal(res$headers[["Retry-After"]], "60")
   182	  expect_equal(out$error, "CAPACITY_EXCEEDED")
   183	
   184	  env$async_job_capacity_exceeded <- function(...) FALSE
   185	  create_job_operation <- NULL
   186	  create_job_params <- NULL
   187	  env$create_job <- function(operation, params) {
   188	    create_job_operation <<- operation
   189	    create_job_params <<- params
   190	    list(job_id = "new-job-1", status = "accepted", estimated_seconds = 30)
   191	  }
   192	  res <- job_endpoint_fake_res()
   193	  out <- env$svc_job_submit_functional_clustering(req, res)
   194	  expect_equal(res$status, 202)
   195	  expect_equal(res$headers[["Retry-After"]], "5")
   196	  expect_equal(out$job_id, "new-job-1")
   197	  expect_equal(create_job_operation, "clustering")
   198	  expect_setequal(
   199	    names(create_job_params),
   200	    # #574 D2: every submit path now carries a `provenance` block; explicit/
   201	    # no-arg submits still omit `category_filter` (asserted separately below).
   202	    c("genes", "algorithm", "category_links", "string_id_table", "provenance")
   203	  )
   204	  expect_false("category_filter" %in% names(create_job_params))
   205	})
   206	
   207	test_that("functional clustering: admission throttle runs FIRST, before any DB/cache work", {
   208	  # #535 S6 BLOCKER fix: a throttle block must short-circuit before the cache/dup/DB
   209	  # path so an abusive caller cannot bypass the limit or grow async_jobs via cache
   210	  # hits. The guard returning admitted=FALSE must return its response and touch nothing.
   211	  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = NULL))
   212	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   213	  pool_touched <- FALSE
   214	  env$pool <- structure(list(), class = "trap_pool")
   215	  env$tbl.trap_pool <- function(src, from, ...) {
   216	    pool_touched <<- TRUE
   217	    stop("DB must not be touched when the throttle blocks")
   218	  }
   219	  create_job_called <- FALSE
   220	  env$create_job <- function(...) {
   221	    create_job_called <<- TRUE
   222	    NULL
   223	  }
   224	  env$async_job_submit_admission_guard <- function(req, res) {
   225	    res$status <- 429
   226	    res$setHeader("Retry-After", "42")
   227	    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
   228	  }
   229	  res <- job_endpoint_fake_res()
   230	  out <- env$svc_job_submit_functional_clustering(req, res)
   231	  expect_equal(res$status, 429)
   232	  expect_equal(out$error, "RATE_LIMITED")
   233	  expect_false(pool_touched)
   234	  expect_false(create_job_called)
   235	})
   236	
   237	## -------------------------------------------------------------------##
   238	## job-functional-submission-service.R: category_filter (#574 D2)
   239	## -------------------------------------------------------------------##
   240	
   241	test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
   242	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   243	  # stop_for_bad_request() lives in core/errors.R, not sourced by the isolated
   244	  # service env by default -- source it here so the real (non-stubbed)
   245	  # mutual-exclusion guard in the service body can raise it.
   246	  source_api_file("core/errors.R", local = FALSE, envir = env)
   247	  env$pool <- job_endpoint_functional_pool(env)
   248	  req <- list(
   249	    argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive")),
   250	    user = list(user_id = NULL)
   251	  )
   252	  res <- job_endpoint_fake_res()
   253	
   254	  expect_error(
   255	    env$svc_job_submit_functional_clustering(req, res),
   256	    class = "error_400"
   257	  )
   258	})
   259	
   260	test_that("functional clustering: an EMPTY genes array + category_filter still triggers mutual exclusion -> error_400 (Codex review fix)", {
   261	  # Bug: mutual exclusion was previously gated on `has_genes` (a LENGTH
   262	  # check), so `{"genes":[], "category_filter":["Definitive"]}` bypassed it
   263	  # -- an empty-but-PRESENT `genes` key must still 400 when a category_filter
   264	  # is also present. Presence (`genes_supplied <- !is.null(genes_in)`), not
   265	  # length, is what mutual exclusion must gate on.
   266	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   267	  source_api_file("core/errors.R", local = FALSE, envir = env)
   268	  env$pool <- job_endpoint_functional_pool(env)
   269	  req <- list(
   270	    argsBody = list(genes = list(), category_filter = list("Definitive")),
   271	    user = list(user_id = NULL)
   272	  )
   273	  res <- job_endpoint_fake_res()
   274	
   275	  expect_error(
   276	    env$svc_job_submit_functional_clustering(req, res),
   277	    class = "error_400"
   278	  )
   279	})
   280	
   281	test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
   282	  # Regression guard for the fix above: gating mutual exclusion on
   283	  # `genes_supplied` (key presence) must NOT change the pre-existing
   284	  # behavior for an empty `genes` array with no `category_filter` at all --
   285	  # it must still fall through to the all-NDD default exactly as before.
   286	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   287	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
   288	    entity_id = 1:3,
   289	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
   290	    ndd_phenotype = c(1L, 0L, 1L)
   291	  ))
   292	  job_endpoint_stub_all_ndd_universe(env)
   293	  captured <- NULL
   294	  env$check_duplicate_job <- function(operation, params) {
   295	    captured <<- params
   296	    list(duplicate = TRUE, existing_job_id = "dup-empty-genes")
   297	  }
   298	  req <- list(argsBody = list(genes = list()), user = list(user_id = NULL))
   299	  res <- job_endpoint_fake_res()
   300	
   301	  out <- env$svc_job_submit_functional_clustering(req, res)
   302	
   303	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   304	  expect_equal(res$status, 409)
   305	  expect_equal(out$error, "DUPLICATE_JOB")
   306	})
   307	
   308	test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
   309	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   310	  env$pool <- job_endpoint_functional_pool(env)
   311	  job_endpoint_stub_clustering_provenance(env)
   312	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
   313	    expect_identical(category_filter, list("Definitive"))
   314	    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
   315	  }
   316	  env$check_duplicate_job <- function(operation, params) {
   317	    expect_true("category_filter" %in% names(params))
   318	    expect_identical(params$category_filter, "Definitive")
   319	    list(duplicate = FALSE)
   320	  }
   321	  env$async_job_capacity_exceeded <- function(...) FALSE
   322	  env$async_job_active_count <- function(...) 0L
   323	  captured <- NULL
   324	  env$create_job <- function(operation, params) {
   325	    captured <<- params
   326	    list(job_id = "j1", status = "accepted", estimated_seconds = 5)
   327	  }
   328	  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
   329	  res <- job_endpoint_fake_res()
   330	
   331	  out <- env$svc_job_submit_functional_clustering(req, res)
   332	
   333	  expect_equal(res$status, 202)
   334	  expect_identical(captured$category_filter, "Definitive")
   335	  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
   336	  expect_identical(captured$provenance$selector$kind, "category")
   337	  expect_identical(captured$provenance$selector$category_filter, "Definitive")
   338	  expect_true(all(
   339	    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
   340	      names(captured$provenance)
   341	  ))
   342	})
   343	
   344	test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
   345	  # Explicit genes.
   346	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   347	  env$pool <- job_endpoint_functional_pool(env)
   348	  job_endpoint_stub_clustering_provenance(env)
   349	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   350	  env$async_job_capacity_exceeded <- function(...) FALSE
   351	  env$async_job_active_count <- function(...) 0L
   352	  captured_explicit <- NULL
   353	  env$create_job <- function(operation, params) {
   354	    captured_explicit <<- params
   355	    list(job_id = "j2", status = "accepted", estimated_seconds = 5)
   356	  }
   357	  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   358	  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
   359	
   360	  expect_false("category_filter" %in% names(captured_explicit))
   361	  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
   362	  expect_null(captured_explicit$provenance$selector$category_filter)
   363	
   364	  # No-arg (all-NDD default).
   365	  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
   366	  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
   367	    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
   368	  ))
   369	  job_endpoint_stub_clustering_provenance(env2)
   370	  job_endpoint_stub_all_ndd_universe(env2)
   371	  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
   372	  env2$async_job_capacity_exceeded <- function(...) FALSE
   373	  env2$async_job_active_count <- function(...) 0L
   374	  captured_no_arg <- NULL
   375	  env2$create_job <- function(operation, params) {
   376	    captured_no_arg <<- params
   377	    list(job_id = "j3", status = "accepted", estimated_seconds = 5)
   378	  }
   379	  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
   380	  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
   381	
   382	  expect_false("category_filter" %in% names(captured_no_arg))
   383	  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
   384	  expect_null(captured_no_arg$provenance$selector$category_filter)
   385	})
   386	
   387	test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
   388	  # `gene_list_sha256` hashes sort(unique(...)), so `resolved_gene_count` must
   389	  # be computed the same way -- otherwise a duplicate-gene payload
   390	  # (`["HGNC:1","HGNC:1"]`) reports resolved_gene_count=2 alongside a
   391	  # singleton sha256. The payload `genes` list itself must stay
   392	  # byte-identical to the raw request (never deduped) -- only the COUNT
   393	  # field changes.
   394	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   395	  env$pool <- job_endpoint_functional_pool(env)
   396	  job_endpoint_stub_clustering_provenance(env)
   397	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   398	  env$async_job_capacity_exceeded <- function(...) FALSE
   399	  env$async_job_active_count <- function(...) 0L
   400	  captured <- NULL
   401	  env$create_job <- function(operation, params) {
   402	    captured <<- params
   403	    list(job_id = "j-dup-genes", status = "accepted", estimated_seconds = 5)
   404	  }
   405	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
   406	  res <- job_endpoint_fake_res()
   407	
   408	  env$svc_job_submit_functional_clustering(req, res)
   409	
   410	  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
   411	  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
   412	})
   413	
   414	test_that("functional clustering: request_hash is selector-aware for category_filter", {
   415	  # Pure-function coverage of the underlying dedup identity: sourced directly
   416	  # (not via the service env) since these are free functions in
   417	  # functions/async-job-service.R, not bare globals the service references.
   418	  hash_env <- new.env(parent = globalenv())
   419	  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)
   420	
   421	  h <- function(genes, algo, cf) {
   422	    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
   423	    hash_env$async_job_service_request_hash(
   424	      "clustering",
   425	      hash_env$async_job_service_payload_json(payload)
   426	    )
   427	  }
   428	  g <- c("HGNC:1", "HGNC:5")
   429	
   430	  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
   431	  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
   432	  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
   433	})
   434	
   435	test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
   436	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   437	  env$pool <- job_endpoint_functional_pool(env)
   438	  env$analysis_string_cache_fingerprint <- function() "fp-test"
   439	  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
   440	  env$clustering_cached_source_data_version <- function(...) stop("boom")
   441	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   442	  create_job_called <- FALSE
   443	  env$create_job <- function(...) {
   444	    create_job_called <<- TRUE
   445	    NULL
   446	  }
   447	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   448	  res <- job_endpoint_fake_res()
   449	
   450	  out <- env$svc_job_submit_functional_clustering(req, res)
   451	
   452	  expect_equal(res$status, 503L)
   453	  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   454	  expect_false(create_job_called)
   455	})
   456	
   457	# job-phenotype-submission-service.R coverage lives in
   458	# test-unit-job-endpoint-services-phenotype.R (split out to keep this file under
   459	# the 600-line ceiling, #574 Codex-review-fix pass).
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
--- test names: base vs current ---
51:test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
88:test_that("functional clustering: algorithm input is coerced to a lowercase scalar, invalid falls back to leiden", {
93:test_that("functional clustering: cache hit stores a completed job without calling create_job", {
126:test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
160:test_that("functional clustering: admission throttle runs FIRST, before any DB/cache work", {
212:test_that("phenotype clustering: review set is gated on is_primary AND review_approved", {
256:test_that("phenotype clustering: duplicate job returns 409 with Location", {
270:test_that("phenotype clustering: cache hit stores a completed job without calling create_job", {
299:test_that("phenotype clustering: capacity guard (503) then a cache miss under capacity (202)", {
337:test_that("phenotype clustering service source keeps is_primary filters paired with review_approved", {
354:test_that("phenotype clustering: admission throttle runs FIRST, before collecting tables", {
--- current functional test names ---
78:test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
116:test_that("functional clustering: algorithm input is coerced to a lowercase scalar, invalid falls back to leiden", {
121:test_that("functional clustering: cache hit stores a completed job without calling create_job", {
169:test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
207:test_that("functional clustering: admission throttle runs FIRST, before any DB/cache work", {
241:test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
260:test_that("functional clustering: an EMPTY genes array + category_filter still triggers mutual exclusion -> error_400 (Codex review fix)", {
281:test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
308:test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
344:test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
387:test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
414:test_that("functional clustering: request_hash is selector-aware for category_filter", {
435:test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
--- current phenotype test names ---
55:test_that("phenotype clustering: review set is gated on is_primary AND review_approved", {
99:test_that("phenotype clustering: duplicate job returns 409 with Location", {
113:test_that("phenotype clustering: cache hit stores a completed job without calling create_job", {
142:test_that("phenotype clustering: capacity guard (503) then a cache miss under capacity (202)", {
180:test_that("phenotype clustering service source keeps is_primary filters paired with review_approved", {
197:test_that("phenotype clustering: admission throttle runs FIRST, before collecting tables", {

exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-job-endpoint-services.R | sed -n '360,480p'
nl -ba api/tests/testthat/test-unit-job-endpoint-services-phenotype.R | sed -n '1,240p'
nl -ba api/tests/testthat/test-unit-clustering-gene-universe.R | sed -n '1,170p'
nl -ba api/tests/testthat/test-unit-async-job-handlers.R | sed -n '1,290p'
nl -ba api/tests/testthat/test-unit-async-job-worker.R | sed -n '1,100p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
   360	  expect_false("category_filter" %in% names(captured_explicit))
   361	  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
   362	  expect_null(captured_explicit$provenance$selector$category_filter)
   363	
   364	  # No-arg (all-NDD default).
   365	  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
   366	  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
   367	    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
   368	  ))
   369	  job_endpoint_stub_clustering_provenance(env2)
   370	  job_endpoint_stub_all_ndd_universe(env2)
   371	  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
   372	  env2$async_job_capacity_exceeded <- function(...) FALSE
   373	  env2$async_job_active_count <- function(...) 0L
   374	  captured_no_arg <- NULL
   375	  env2$create_job <- function(operation, params) {
   376	    captured_no_arg <<- params
   377	    list(job_id = "j3", status = "accepted", estimated_seconds = 5)
   378	  }
   379	  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
   380	  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
   381	
   382	  expect_false("category_filter" %in% names(captured_no_arg))
   383	  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
   384	  expect_null(captured_no_arg$provenance$selector$category_filter)
   385	})
   386	
   387	test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
   388	  # `gene_list_sha256` hashes sort(unique(...)), so `resolved_gene_count` must
   389	  # be computed the same way -- otherwise a duplicate-gene payload
   390	  # (`["HGNC:1","HGNC:1"]`) reports resolved_gene_count=2 alongside a
   391	  # singleton sha256. The payload `genes` list itself must stay
   392	  # byte-identical to the raw request (never deduped) -- only the COUNT
   393	  # field changes.
   394	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   395	  env$pool <- job_endpoint_functional_pool(env)
   396	  job_endpoint_stub_clustering_provenance(env)
   397	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   398	  env$async_job_capacity_exceeded <- function(...) FALSE
   399	  env$async_job_active_count <- function(...) 0L
   400	  captured <- NULL
   401	  env$create_job <- function(operation, params) {
   402	    captured <<- params
   403	    list(job_id = "j-dup-genes", status = "accepted", estimated_seconds = 5)
   404	  }
   405	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
   406	  res <- job_endpoint_fake_res()
   407	
   408	  env$svc_job_submit_functional_clustering(req, res)
   409	
   410	  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
   411	  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
   412	})
   413	
   414	test_that("functional clustering: request_hash is selector-aware for category_filter", {
   415	  # Pure-function coverage of the underlying dedup identity: sourced directly
   416	  # (not via the service env) since these are free functions in
   417	  # functions/async-job-service.R, not bare globals the service references.
   418	  hash_env <- new.env(parent = globalenv())
   419	  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)
   420	
   421	  h <- function(genes, algo, cf) {
   422	    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
   423	    hash_env$async_job_service_request_hash(
   424	      "clustering",
   425	      hash_env$async_job_service_payload_json(payload)
   426	    )
   427	  }
   428	  g <- c("HGNC:1", "HGNC:5")
   429	
   430	  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
   431	  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
   432	  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
   433	})
   434	
   435	test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
   436	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   437	  env$pool <- job_endpoint_functional_pool(env)
   438	  env$analysis_string_cache_fingerprint <- function() "fp-test"
   439	  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
   440	  env$clustering_cached_source_data_version <- function(...) stop("boom")
   441	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   442	  create_job_called <- FALSE
   443	  env$create_job <- function(...) {
   444	    create_job_called <<- TRUE
   445	    NULL
   446	  }
   447	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   448	  res <- job_endpoint_fake_res()
   449	
   450	  out <- env$svc_job_submit_functional_clustering(req, res)
   451	
   452	  expect_equal(res$status, 503L)
   453	  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   454	  expect_false(create_job_called)
   455	})
   456	
   457	# job-phenotype-submission-service.R coverage lives in
   458	# test-unit-job-endpoint-services-phenotype.R (split out to keep this file under
   459	# the 600-line ceiling, #574 Codex-review-fix pass).
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
    81	    calls[[length(calls) + 1L]] <<- list(
    82	      job_id = job_id,
    83	      progress_pct = progress_pct,
    84	      progress_message = progress_message,
    85	      claim_token = claim_token
    86	    )
    87	    1L
    88	  }
    89	  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
    90	    heartbeat_calls[[length(heartbeat_calls) + 1L]] <<- list(
    91	      job_id = job_id,
    92	      lease_seconds = lease_seconds,
    93	      claim_token = claim_token
    94	    )
    95	    1L
    96	  }
    97	
    98	  runtime$async_job_worker_set_claim_context(
    99	    list(
   100	      job_id = "job-progress",

exec
/bin/bash -lc "nl -ba api/tests/testthat/job-endpoint-services-fixtures.R
nl -ba api/bootstrap/load_modules.R | sed -n '1,310p'
nl -ba AGENTS.md | sed -n '110,145p'
nl -ba CHANGELOG.md | sed -n '1,85p'
nl -ba documentation/08-development.qmd | sed -n '180,230p'
nl -ba api/version_spec.json
nl -ba app/package.json | sed -n '1,150p'
git diff --unified=80 origin/master...HEAD -- app/package-lock.json" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# tests/testthat/job-endpoint-services-fixtures.R
     2	#
     3	# Shared fixtures for the job-endpoint-service unit tests, split across two files
     4	# to keep each under the 600-line ceiling:
     5	#   - test-unit-job-endpoint-services.R              (functional + phenotype submission)
     6	#   - test-unit-job-endpoint-services-maintenance.R  (maintenance submission + query)
     7	# Both files EXPLICITLY source() this file at the top so they run standalone under a
     8	# single-file `testthat::test_file()` (a plain helper-*.R auto-load is not guaranteed
     9	# to run there); mirrors the pubmed-xml-fixtures.R convention.
    10	#
    11	# `pool %>% dplyr::tbl(name)` is faked with a small S3 dispatch trick: a "fake_pool"
    12	# object wrapping a named list of tibbles, plus one `tbl.fake_pool` method registered in
    13	# the environment the service was sourced into (S3 dispatch finds it there). This needs
    14	# no test DB / RSQLite, so every test is a real PASS on host R.
    15	
    16	library(dplyr)
    17	library(tidyr)
    18	
    19	#' Source a service file into a fresh child-of-globalenv environment.
    20	#'
    21	#' The two public clustering submit services now call `async_job_submit_admission_guard()`
    22	#' FIRST (#535 S6) before any DB/cache work; stub it to "admit" by default so these
    23	#' isolated tests exercise the downstream request/response logic. A test can override
    24	#' `env$async_job_submit_admission_guard` to exercise the throttle-block path.
    25	#'
    26	#' Also sources `functions/clustering-gene-universe.R` (#574 D1/D3) into `env` so
    27	#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
    28	#' `job-functional-submission-service.R`'s cache-hit path -- is available for real
    29	#' (a pure list-assembly function, safe to source unstubbed). Individual tests still
    30	#' stub the DB/cache-touching siblings from that same file
    31	#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
    32	#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
    33	#' this sourcing only supplies defaults those stubs override.
    34	job_endpoint_source_service <- function(filename) {
    35	  env <- new.env(parent = globalenv())
    36	  env$async_job_submit_admission_guard <- function(req, res) list(admitted = TRUE)
    37	  sys.source(file.path(get_api_dir(), "functions", "clustering-gene-universe.R"), envir = env)
    38	  sys.source(file.path(get_api_dir(), "services", filename), envir = env)
    39	  env
    40	}
    41	
    42	#' Register `tbl.fake_pool` in `env` and build a fake pool over `tables`.
    43	job_endpoint_fake_pool <- function(env, tables) {
    44	  env$tbl.fake_pool <- function(src, from, ...) src$tables[[from]]
    45	  structure(list(tables = tables), class = "fake_pool")
    46	}
    47	
    48	#' Minimal Plumber-response stand-in: an environment with `$status` and a
    49	#' `$setHeader()` that records every header set (mirrors the `res_env`
    50	#' pattern in test-unit-pubtator-enrichment.R).
    51	job_endpoint_fake_res <- function() {
    52	  res <- new.env()
    53	  res$status <- NULL
    54	  res$headers <- list()
    55	  res$setHeader <- function(name, value) {
    56	    res$headers[[name]] <- value
    57	    invisible(NULL)
    58	  }
    59	  res
    60	}
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
   110	
   111	Public analysis endpoints read durable public-ready snapshots from `analysis_snapshot_*` tables. Supported parameter presets are fixed in `analysis-snapshot-presets.R` until a worker/admin refresh precomputes more; unsupported parameters fail fast as `unsupported_parameter`, while supported presets without an active current public-ready row report snapshot diagnostics such as `snapshot_missing`, `snapshot_stale`, or `source_version_mismatch`. Snapshot refresh jobs must use approved-public input gates only, and activation is scoped by exactly one public-ready row per `(analysis_type, parameter_hash)`. MCP analysis reads the same public-ready snapshots only; it must not compute heavy analysis, fCoSE layouts, external calls, or Gemini/LLM summaries on miss.
   112	
   113	### Analysis-snapshot releases (#573)
   114	
   115	Analysis-snapshot **releases** are immutable, content-addressed, frozen exports of the public-ready snapshots above (functional clusters, phenotype clusters, phenotype-functional correlation) — the same durable-artifact pattern as the NDDScore/Zenodo release layer, applied to derived analysis. Migration `045_add_analysis_snapshot_release.sql` adds three tables (`analysis_snapshot_release` head + `_member` pinned-snapshot lineage + `_file` per-file gzipped content) and bumped `EXPECTED_LATEST_MIGRATION`/`EXPECTED_MIGRATION_COUNT` in `api/functions/migration-manifest.R`. A release stores its **own** frozen copies (canonical-JSON payloads, raw reproducibility bytes, README, manifest, checksums, a pre-built `bundle.tar.gz`) — never a reference to the source snapshot rows — so it survives snapshot pruning/refresh byte-identically.
   116	
   117	- **Content-addressing.** `content_digest` (`analysis_release_content_digest()`, `analysis-snapshot-release-manifest.R`) is a SHA-256 over the invariant scientific content only — `manifest_schema_version`, `source_data_version`, and each layer's `{analysis_type, input_hash, payload_hash, reproducibility_hash, dependencies}` — and deliberately **excludes** `created_at`, `title`, and DOI, so recording provenance metadata never changes release identity. `release_id = "asr_" + content_digest[:16]`; the full 64-char digest is stored and insert is guarded against a same-id/different-digest collision (fails loudly rather than colliding).
   118	- **Public surface is retrieval-only and DB-only.** `GET /api/analysis/releases`, `.../releases/latest`, `.../releases/<release_id>`, `.../releases/<release_id>/manifest.json`, `.../releases/<release_id>/file?path=<file_path>`, and `.../releases/<release_id>/bundle` are unauthenticated, make no external calls, and are covered by the same cheap-route/external-budget isolation guards as the rest of `/api/analysis`. `.../file` resolves by an **exact `(release_id, file_path)` primary-key lookup** — there is no filesystem access and no path-traversal surface; anything not in `analysis_snapshot_release_file` is a 404. Every public read is pinned to `status = 'published'`, so an unknown release id and a draft release id are indistinguishable (both 404) — drafts are never public. `latest` is declared **before** the dynamic `<release_id>` route (the `/status/_list` shadowing lesson applies here too).
   119	- **The build is a fail-closed 400 gate**, not a best-effort export (`analysis_snapshot_release_build()`, `functions/analysis-snapshot-release.R`). In order: (1) each registry layer must be `status_code == "available"` from `analysis_snapshot_get_public()`; (2) a **hard** partition-coherence re-check (`analysis_snapshot_assert_partition_coherent(..., require_coherence = TRUE)`) runs on every cluster layer regardless of the `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` env downgrade — `available` only proves freshness/schema/source-version, not #514 coherence, so a release can never freeze an incoherent-but-`public_ready` snapshot; (3) each cluster layer must have a stored reproducibility bundle (the snapshot builder makes it best-effort, the release makes it mandatory); (4) all layers must share one `source_data_version`, and the correlation layer's dependency lineage must match the pinned functional + phenotype `snapshot_id`+`payload_hash` (the #571/#572 dependency gate); (5) a **TOCTOU guard** — the same per-preset advisory lock the axis refresh holds, plus a fresh pre-insert re-read of every layer immediately before persisting — closes the race between the initial read and the insert. Any gate failure is `stop_for_bad_request()` (400; there is no 409 class), naming the failing layer/reason. A rebuild whose content is **identical** to an existing release is not an error: it returns the existing head idempotently (200, no duplicate row); a genuinely new content set is 201.
   120	- **Hashing facts, precisely.** Every file carries its **own** `content_sha256`. For each cluster layer, `sha256(reproducibility.json) == reproducibility_hash` **exactly** — this uses the raw pre-gzip bundle bytes (`analysis_reproducibility_decode_raw()`, `memDecompress(..., asChar = TRUE)`), never `analysis_reproducibility_decode()`, whose `jsonlite::fromJSON()` + re-serialize round-trip drops the bundle's full-precision (`digits = NA`) contract and breaks the equality. By contrast, `payload_hash`/`input_hash`/`snapshot_id` are recorded in the manifest as cross-checkable **lineage anchors** against the live `meta.snapshot.{payload_hash,input_hash,snapshot_id}` on the corresponding `/api/analysis/*` endpoint — they are **not** equal to a hash of the release's own `payload.json` file (the stored payload round-trips through `DECIMAL(8,7)`/`DECIMAL(8,5)` DB columns before the release freezes it, so a reconstructed byte-for-byte match is neither guaranteed nor attempted).
   121	- **DOI is additive, outside the hash.** `PATCH /api/admin/analysis/releases/<id>/doi` (Administrator) records `{zenodo_record_id, zenodo_record_url, version_doi, concept_doi}` — any subset, an omitted field is left unchanged, never nulled out — and never touches `content_digest`/`manifest_sha256`; recording a DOI after publish changes zero release bytes.
   122	- **Never pruned.** A published release is permanent; `DELETE /api/admin/analysis/releases/<id>` only works on a `draft`. `analysis_snapshot_prune()` (`analysis-snapshot-repository.R`) now skips any `snapshot_id` still referenced by an `analysis_snapshot_release_member` row (`analysis_release_referenced_snapshot_ids()`), so a snapshot pinned by a release keeps serving its live reproducibility endpoint too — even though release integrity never depends on the source snapshot surviving (each release is self-contained).
   123	- **Build is synchronous, admin, DB-only — the worker is NOT required.** Unlike snapshot refresh, `POST /api/admin/analysis/releases` runs inline on the API request (`analysis_snapshot_release_build()` is called directly from the endpoint, not submitted as an async job): no clustering recompute, no external calls, no LLM, no cache writes. A release can be built even if the worker is down, as long as public-ready snapshots already exist.
   124	- **`GET .../releases/<release_id>/file?path=<file_path>` uses a query param, not a nested path segment**, because Plumber 1.3.2 has no `<path:.*>` wildcard — only named, typed, single-segment path params (`<id>`, `<id:int>`) exist, so a nested archive path (e.g. `functional_clusters/payload.json`) cannot be expressed as a URL path segment. The manifest's `files[].path` values are the caller's index into this route.
   125	
   126	`POST /api/jobs/clustering/submit` can resolve its clustering gene universe from a curated confidence category instead of an explicit gene list (#574). `clustering_resolve_category_universe()` (`api/functions/clustering-gene-universe.R`) does entity-level resolution: a gene qualifies if it has >=1 `ndd_phenotype == 1` entity whose `category` is in the selector, filtered directly against `ndd_entity_view` — **never** `select_network_gene_category()` (the gene-level display-label aggregator used for node coloring only, not a universe filter). `category_filter` absent → the byte-identical existing default (`generate_ndd_hgnc_ids()`, cache parity preserved); supplied-but-empty → 400; validated live against `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded category strings, no interpolated SQL) with the allowed active set named in the error **message**; a resolved universe under 2 genes → 400. `genes` and a non-empty `category_filter` are mutually exclusive (400). The durable job payload gains a normalized `category_filter` key — and the dedup identity becomes selector-aware — **only** for category selectors, so explicit-genes and no-arg submits keep byte-identical `request_hash`/payload shape to pre-#574. Every submit records provenance — `selector` (`kind`: `explicit`|`category`|`all_ndd`), `resolved_gene_count`, `gene_list_sha256`, an **intended** fingerprint (STRING cache fingerprint + score threshold + algorithm + seed), and a cached fail-closed `source_data_version` — in the payload; the result `meta` additionally carries an **effective** `effective_fingerprint` (the STRING `weight_channel` the computed result actually used), on both a cache-hit response (`svc_job_submit_functional_clustering()`) and a worker-run job (`.async_job_run_clustering()` in `async-job-handlers.R`), so a silent exp+db→combined-score fallback is visible either way. Results from this endpoint (category-filtered or not) are ephemeral job results and are **never** `public_ready` — distinct from the public `analysis_snapshot_*` layer above.
   127	
   128	### Cluster-analysis statistical soundness (#508–#512)
   129	
   130	The two-axis cluster analysis (phenotype MCA/HCPC and functional STRING/Leiden) and the served "function is modular, phenotype is a continuum" cross-axis interpretation are made mathematically sound and self-reproducing. `validation_schema_version` is `"2.0"`, `ANALYSIS_SNAPSHOT_SCHEMA_VERSION` is `"1.2"`. The **key lever**: `analysis_snapshot_payload_hash` deliberately excludes `partition_validation` (`analysis-snapshot-builder.R`), so everything in the validation block is **additive** — new metrics never change `cluster_hash` and never invalidate LLM summaries. Only changes to cluster **membership** (the #508 MCA filter, the #509 `kk=Inf` consolidation, the #510 channel switch) change `cluster_hash` and therefore require a coordinated forced snapshot refresh + LLM regeneration.
   131	
   132	- **Common cross-axis footing (#511)** lives in `api/functions/analysis-null-models.R` (worker/heavy-path only; registered in `bootstrap/load_modules.R`). Both axes report a **unit-free, null-calibrated `separation_z`** so the contrast is like-for-like instead of raw-silhouette-vs-raw-modularity: functional = **modularity z-score** vs a **degree-preserving configuration-model null** (`modularity_null_zscore`: `igraph::rewire(keeping_degseq)` + permuted weight multiset, re-restricting **both** the observed graph and every replicate to the largest connected component, and **re-detecting communities with the identical seeded Leiden on each replicate** — the Guimerà/Sales-Pardo/Amaral re-optimized null, so `modularity_z` benchmarks against the modularity a degree-matched random graph genuinely reaches rather than being a near-tautological Q-vs-0 test; **never** revert this to carrying the observed labels onto the null, which inflates the z by orders of magnitude); phenotype = **silhouette z-score** vs a **label-permutation null** (`silhouette_null_zscore`). The `modularity_null_zscore` `recluster` argument selects the flavour: the functional axis passes a Leiden closure (re-optimized, `null_model = "…_reoptimized"`), while the phenotype `shared_modularity_z` passes **none** and holds the external MCA/HCPC labels **fixed** on the kNN null (`"…_fixed_labels"`) because the graph cannot re-derive that partition (it is an attribute-assortativity test). Additionally a **dip test of unimodality** (`dip_unimodality`, Hartigan; optional `diptest` dependency — degrades to `NA` if absent) is reported on both axes' pairwise-distance distributions as a **corroborating** continuum-vs-modular signal (`dip_p` small → discrete; large → continuum); the functional dip runs on **continuous weighted shortest-path distances** (edge distance `1 - combined_score/1000`), NOT integer hop counts, so it is not a discreteness artifact, and because pairwise distances are mutually dependent `dip_p` corroborates rather than strictly proves. The SAME modularity-z index is also reported for phenotype on a mutual-kNN graph of the MCA coords (`knn_similarity_graph` → `shared_modularity_z`). Never resurrect a direct silhouette-vs-modularity comparison.
   133	- **Functional axis is text-mining-free (#510).** `build_string_subgraph` (`analyses-functions.R`) prefers a graph whose weights are recombined from the STRING **experimental + database** channels only (STRING's probabilistic-OR formula in `analysis-string-channels.R`, `string_recompute_score`/`string_expdb_subgraph`), dropping the text-mining/co-mention channel that would make a "molecular pathways organize NDD" claim partly restate co-study structure (≈540 of ~3200 NDD genes had STRING edges **only** via text-mining). The exp+db score is carried in the existing `combined_score` edge attribute (so the weighted-Leiden/modularity plumbing is unchanged) plus a `weight_channel` graph attribute; it **falls back** to the STRINGdb combined graph when the compact edge file is absent, so a fresh checkout still functions. That file, `data/9606.protein.links.expdb.v11.5.min400.txt.gz`, is a gitignored runtime artifact built by `api/scripts/build-string-expdb.R` from the ~115 MB `9606.protein.links.detailed.v11.5.txt.gz` download; the **worker needs `data.table` and this file**. STRING lists every undirected pair in **both** directions, so `string_expdb_subgraph()` **`simplify()`-es** the induced graph at read (and the builder writes only the canonical `protein1 < protein2` half) — otherwise every edge is double-counted (2× `giant_component$n_edges`, a doubled reproducibility edge list, and disagreement with the simple STRINGdb-combined fallback); weighted Leiden/modularity are invariant to the uniform duplication, so the partition is unchanged. The **headline `modularity`** is the full-partition Q; its **z-score, degree-preserving null, giant-component counts** (`giant_component`: isolates/components/retention), and the reconcilable **`modularity_lcc`** (the exact Q the z is computed on) are all on the **largest connected component** (disconnected fragments are trivial "perfect communities" that inflate Q); an env-gated (`ANALYSIS_REPORT_COMBINED_SENSITIVITY`) `modularity_combined_score` reports how much Q changes with text-mining included.
   134	- **Phenotype MCA feature hygiene + real consolidation (#508/#509).** The shared helper `phenotype_mca_prep_matrix()` (`analysis-phenotype-mca-prep.R`) applies the hygiene once, and **every** phenotype-matrix path calls it — `generate_phenotype_cluster_input` (served snapshot + validator) **and** `.async_job_phenotype_matrix` (the interactive/durable `/api/jobs/phenotype_clustering` job) — so the interactive product can never diverge from the public snapshot (keep them on the one helper; do not re-inline the prep). It drops the HPO subtree root `HP:0000118` and any organ-system term outside the prevalence band (`PHENOTYPE_MCA_PREVALENCE_MIN`/`MAX`, default 0.05–0.95 — near-universal/near-rare terms add null/outlier MCA dimensions that mechanically depress separation) and recodes presence from `{"yes",NA}` to explicit `{absent,present}` factors (an all-NA character column is **not** treated as a presence column, so a fully-missing supplementary column can't be misclassified and shift the `quali.sup`/`quanti.sup` indices). `gen_mca_clust_obj` uses `HCPC(kk = Inf, consol = TRUE)` because FactoMineR ≥2.13 **silently disables consolidation when `kk != Inf`** (`if ((kk != Inf) & (consol == TRUE)) { warning(...); consol <- FALSE }`) — the old `kk = 50` claimed consolidation but never ran it; do **not** reintroduce a finite `kk` while asserting consolidation. The `k_selection_curve` re-runs the exact served procedure (`gen_mca_clust_obj(cutpoint = k)`, which re-seeds internally) at each k and anchors at the true data-driven HCPC k (exposed via an attribute), so `k_selection_curve[hcpc_nb_clust] == mean_silhouette` by construction; `k_decision_curve` reports the relative within-cluster inertia loss HCPC actually uses to pick k (so it is explicit k was not chosen by silhouette), and `silhouette_interpretation` bands the value honestly (≤0.25 Kaufman–Rousseeuw → `no_substantial_structure_continuum`).
   135	- **Reproducibility bundle (#512).** Migration `041_add_analysis_reproducibility.sql` adds `analysis_snapshot_reproducibility` (gzip canonical-JSON bundle + SHA-256 `reproducibility_hash`). `analysis-reproducibility.R` builds/decodes/persists the bundle (functional: full LCC edge list + complete membership incl. sub-`min_size`; phenotype: MCA coords + assignment + params) and the builder attaches it (also excluded from `payload_hash`). Two DB-only public routes — `GET /api/analysis/functional_clustering/reproducibility` and `.../phenotype_clustering/reproducibility` (routes in `analysis_endpoints.R`, handler `analysis_reproducibility_endpoint`) — let a consumer recompute modularity/silhouette from published artifacts. **Wave-2 activation runbook** (after these membership-changing changes deploy): restart the worker (worker-executed code changed), `POST /api/admin/analysis/snapshots/refresh?analysis_type=functional_clusters&force=true` and `…phenotype_clusters&force=true`, then `POST /api/llm/regenerate?cluster_type=functional&force=true` and `…phenotype&force=true` (cluster hashes changed, so summaries must regenerate). Spec/plan: `.planning/superpowers/specs|plans/2026-07-05-cluster-soundness-508-512-*.md`.
   136	
   137	### Cluster-snapshot cache coherence & self-healing analysis deploys (#514)
   138	
   139	The heavy clustering functions (`gen_string_clust_obj`, `gen_network_edges`, `gen_mca_clust_obj`) are memoised onto a disk cache that lives on a **named volume and survives redeploys** (`api/bootstrap/init_cache.R`). Historically the memoise key was only the call args, so a methodology change (the #510 exp+db graph, #508/#509 MCA hygiene) did **not** change the key: the snapshot builder read **membership** from a stale disk-cache hit (`gen_string_clust_obj_mem`) while the **validator** (`validate_functional_clusters`, not memoised) recomputed fresh on the new graph, and the integer-`cluster_id` join then left real clusters with `n/a` stability — a **stale, internally-incoherent** snapshot that still activated as `public_ready`. Three coupled mechanisms now prevent AND catch this; keep them together.
   140	
   141	- **Self-invalidating fingerprint (the fix).** `api/functions/analysis-cache-fingerprint.R` defines `CLUSTER_LOGIC_VERSION` (bump on ANY clustering input/algorithm change) plus `analysis_string_cache_fingerprint()` (version + STRING channel + exp+db file `size:mtime`) and `analysis_phenotype_cache_fingerprint()` (version + MCA prevalence band). Each clustering function carries a trailing **`.cache_fingerprint`** formal whose **call-time** default is the relevant fingerprint (memoise 2.0.1 hashes call-time default args — verified), so the fingerprint enters the memoise key with **zero call-site changes** and the body ignores it. Evaluation is at **call time, not boot**, so adding/rebuilding the exp+db artifact self-invalidates the relevant entries **without a restart** (the exact prod scenario). The default is `exists()`-guarded so minimal/test envs degrade to a NULL key component instead of erroring. A code change → bump `CLUSTER_LOGIC_VERSION`; a data/channel/prevalence change self-invalidates. This **supersedes** the manual `CACHE_VERSION` bump for clustering caches (`CACHE_VERSION` still governs other memoised return-shape changes). Registered in `bootstrap/load_modules.R` (API + durable worker + MCP sidecar) and `bootstrap/setup_workers.R` (mirai parity). **Never** revert the memoise key to args-only.
   142	- **Snapshot integrity gate.** `api/functions/analysis-snapshot-coherence.R` — the builder joins validation onto membership through `analysis_snapshot_join_validated_clusters()`, which first calls `analysis_snapshot_assert_partition_coherent()`. It **refuses to publish** (throws → refresh fails → prior `public_ready` retained, new row `failed`) when the visible membership cluster set ≠ the validation cluster set, any visible cluster lacks a stability score, the membership channel ≠ the validation channel, **or** any shared cluster-id's served member set ≠ the validated reference member set (a **same-partition proof**, not just same labels — the validators return `reference_members`, STRING ids for functional / entity ids for phenotype, keyed by cluster_id, so a stale membership whose labels happen to coincide is still caught). `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` (default `true`) is the hard gate; `false` downgrades to a warning. The builder joins **only** through this helper — do not reintroduce a bare `left_join(clusters, val$per_cluster)`.
   143	- **Channel observability.** `gen_string_clust_obj` records the channel the served membership was actually clustered on (`attr(subgraph, "weight_channel")`) and carries it on the tibble (survives the RDS memoise round-trip); the builder exposes it additively as `partition_validation$membership_weight_channel` (excluded from `payload_hash`, so no `cluster_hash` churn) and the gate compares it to the validator's `weight_channel`. `build_string_subgraph` now emits a **`warning()`** (not just a `message()`) when an intended exp+db graph falls back to the text-mining `combined_score` graph, and `GET /api/health` exposes `analysis.expdb_edges_file_present` + `analysis.cluster_logic_version` so a missing data-prep artifact is visible at a glance.
   144	- **exp+db artifact is required for the #510 methodology.** `data/9606.protein.links.expdb.v11.5.min400.txt.gz` is a gitignored runtime artifact built by `api/scripts/build-string-expdb.R`; api/worker/worker-maintenance already bind-mount `./api/data`, and the `mcp` service now mounts it **read-only** so the MCP cache-probe fingerprint matches the writer's (a mismatch only makes MCP **miss**, never serve stale). A fresh deploy still functions without it (combined fallback), but functional clustering is then **not** text-mining-free — the health flag + fallback warning make that loud.
   145	- **Methodology-deploy runbook (`documentation/09-deployment.qmd`):** ensure the exp+db artifact exists → bump `CLUSTER_LOGIC_VERSION` when the algorithm/inputs changed → restart worker (worker-executed code) → `POST /api/admin/analysis/snapshots/refresh?...&force=true` for both clustering presets → verify `GET /api/analysis/functional_clustering` shows agreeing membership + metrics and `weight_channel = experimental_database`. Guards: `api/tests/testthat/test-unit-analysis-cache-fingerprint.R`, `test-unit-analysis-snapshot-coherence.R`, `test-unit-string-expdb-subgraph.R`.
     1	# Changelog
     2	
     3	All notable changes to SysNDD are documented in this file.
     4	
     5	The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (loosely, in the `0.x` line — additive changes land as patch bumps while the public API still stabilises).
     6	
     7	## [Unreleased]
     8	
     9	## [0.30.1] — 2026-07-19
    10	
    11	Category-selected gene universes for functional clustering (#574). The public
    12	clustering submit endpoint can now resolve its gene universe from a curated
    13	SysNDD confidence category instead of an explicit gene list, with an auditable
    14	provenance record on every job.
    15	
    16	### Added
    17	
    18	- **`category_filter` on `POST /api/jobs/clustering/submit`**: an optional JSON
    19	  body array (e.g. `["Definitive"]`) selecting the clustering gene universe
    20	  from curated confidence categories. Resolution is **entity-level** against
    21	  `ndd_entity_view` — a gene qualifies if it has ≥1 `ndd_phenotype = 1` entity
    22	  whose status `category` is in the selector — via the new
    23	  `clustering_resolve_category_universe()`
    24	  (`api/functions/clustering-gene-universe.R`). Omitting the selector keeps the
    25	  byte-identical pre-#574 default (all NDD genes via `generate_ndd_hgnc_ids()`,
    26	  cache parity preserved); supplying both `genes` and `category_filter` is a
    27	  400.
    28	- **Provenance on every clustering job**: each submit records a `selector`
    29	  (`kind`: `explicit` / `category` / `all_ndd`), `resolved_gene_count`,
    30	  a sort-order-independent `gene_list_sha256`, an **intended** analysis
    31	  fingerprint (STRING cache fingerprint + score threshold + algorithm + seed),
    32	  and a cached, fail-closed `source_data_version` in the durable payload; the
    33	  result `meta` additionally carries an **effective** `effective_fingerprint`
    34	  (the STRING `weight_channel` the computed result actually used), on both the
    35	  cache-hit response and a worker-run job, so a silent exp+db→combined-score
    36	  fallback is observable either way.
    37	
    38	### Changed
    39	
    40	- Clustering-job **dedup identity is now selector-aware**: the normalized
    41	  `category_filter` enters the durable payload and preflight dedup key **only**
    42	  for category selectors, so `["Definitive"]` and `["Definitive","Moderate"]`
    43	  that happen to resolve to the same current genes are not collapsed, while
    44	  explicit-`genes` and no-arg submits keep a byte-identical `request_hash` and
    45	  payload shape to pre-#574. Category-filtered results remain ephemeral job
    46	  results and are **never** `public_ready`.
    47	
    48	### Validated
    49	
    50	- The selector is validated live against
    51	  `ndd_entity_status_categories_list WHERE is_active = 1` (no hardcoded
    52	  category strings, no interpolated SQL): an unknown/inactive category, a
    53	  supplied-but-empty selector, or a resolved universe under 2 genes is a 400
    54	  naming the allowed active categories in the error message.
    55	
    56	## [0.30.0] — 2026-07-18
    57	
    58	Immutable public analysis-snapshot releases (#573, Slice A). SysNDD's derived
    59	cluster analyses (functional STRING/Leiden clusters, phenotype MCA/HCPC
    60	clusters, and the phenotype-functional cross-cluster correlation) can now be
    61	frozen into content-addressed, independently-verifiable releases — the same
    62	"immutable dataset release" pattern already used for NDDScore/Zenodo, applied
    63	to the analysis layer.
    64	
    65	### Added
    66	
    67	- **Content-addressed release identity**: `content_digest` is a SHA-256 over
    68	  the invariant scientific content only (each pinned layer's `input_hash` /
    69	  `payload_hash` / `reproducibility_hash` plus the shared source-data
    70	  version) and deliberately **excludes** `created_at`, `title`, and DOI, so
    71	  release identity is a pure function of the underlying data. The public
    72	  handle is `release_id = "asr_" + content_digest[:16]`; the full 64-char
    73	  digest is stored and collision-checked on insert.
    74	- **Public retrieval-only routes** (DB-only, unauthenticated) under
    75	  `/api/analysis`: `GET /releases` (published, newest first), `GET
    76	  /releases/latest`, `GET /releases/<release_id>`, `GET
    77	  /releases/<release_id>/manifest.json` (the exact stored manifest bytes),
    78	  `GET /releases/<release_id>/file?path=<file_path>` (an exact
    79	  `(release_id, file_path)` lookup — no filesystem access, no path
    80	  traversal), and `GET /releases/<release_id>/bundle` (streams the frozen
    81	  `bundle.tar.gz` verbatim). A draft release is indistinguishable from an
    82	  unknown release id on every public route (plain 404).
    83	- **Admin build/publish/DOI routes** (Administrator) under
    84	  `/api/admin/analysis`: `POST /releases` builds (and, by default,
    85	  publishes) a release from the currently active public-ready snapshots —
   180	curl -sS "http://localhost/api/analysis/releases/$release_id/bundle" -o bundle.tar.gz
   181	sha256sum manifest.json bundle.tar.gz
   182	mkdir -p /tmp/asr-verify && tar -xzf bundle.tar.gz -C /tmp/asr-verify
   183	(cd /tmp/asr-verify && sha256sum -c checksums.sha256)
   184	```
   185	
   186	`sha256sum -c checksums.sha256` must report every extracted file as `OK`; the standalone `manifest.json` download's own SHA-256 must equal the release head's `manifest_sha256` field.
   187	
   188	**Manifest schema summary** (`manifest_schema_version` `"1.0"`, built by `analysis_release_build_manifest()` in `api/functions/analysis-snapshot-release-manifest.R`): `release_id`, `release_version`, `title`, `created_at`, `license`, `scope_statement`, `generator` (API/schema/cluster-logic versions), `source` (`source_data_version` + DB release label), `layers[]` (one entry per pinned snapshot: `analysis_type`, `snapshot_id`, `parameter_hash`, `schema_version`, `input_hash`, `payload_hash`, `reproducibility_hash`, and — for the correlation layer — `dependencies` naming both cluster axes' `snapshot_id`/`payload_hash`), `files[]` (`path`, `sha256`, `bytes`, excluding `manifest.json` and `checksums.sha256` themselves, which cannot describe their own checksum), and `content_digest`.
   189	
   190	**Two hashing facts that are easy to get backwards:**
   191	
   192	- `sha256(reproducibility.json)` (each cluster layer's file) equals its `reproducibility_hash` **exactly** — this is the raw pre-gzip bundle bytes read via `analysis_reproducibility_decode_raw()`, never the parsing `analysis_reproducibility_decode()`, whose `jsonlite::fromJSON()` round-trip drops the bundle's full-precision contract and breaks the equality.
   193	- `payload_hash` (and `input_hash`, `snapshot_id`) recorded per layer in the manifest is a **lineage anchor**, cross-checkable against the live `meta.snapshot.{payload_hash,input_hash,snapshot_id}` block on the corresponding `/api/analysis/*` endpoint — it is **not** the SHA-256 of that layer's own `payload.json` file in the bundle (that file has its own, separately-computed `content_sha256` in `files[]`). The stored payload round-trips through DB column types before a release freezes it, so a byte-for-byte reconstruction of the original in-memory payload is neither guaranteed nor attempted.
   194	
   195	### Category-Selected Clustering (#574)
   196	
   197	`POST /api/jobs/clustering/submit` accepts an optional `category_filter` JSON body array (e.g. `["Definitive"]`) as an alternative gene-universe selector to the existing `genes` array; supplying neither keeps the pre-#574 default all-NDD-genes universe, and supplying both is a 400. A category run resolves entity-level against the live `ndd_entity_view` (any gene with >=1 `ndd_phenotype = 1` entity in a selected category qualifies) and validates the selector against the live active `ndd_entity_status_categories_list` — an unknown/inactive category or a universe under 2 genes is a 400 naming the allowed active categories. Category runs are NOT `public_ready`; they are the same ephemeral job-result mechanism as an explicit-`genes` submit, just with a curated-category-derived universe.
   198	
   199	Every submit (cache-hit or worker-run) records selector/fingerprint provenance in the durable job payload and result `meta` — see `api/functions/clustering-gene-universe.R` (resolver), `api/services/job-functional-submission-service.R` (cache-hit meta), and `.async_job_run_clustering()` in `api/functions/async-job-handlers.R` (worker-run meta) for the exact shape. Focused checks while iterating:
   200	
   201	```bash
   202	cd api
   203	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-clustering-gene-universe.R')"
   204	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-clustering-handler-meta.R')"
   205	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-endpoint-services.R')"
   206	```
   207	
   208	`test-integration-clustering-category-submit.R` exercises the resolver against a real, populated `sysndd_db_test` `ndd_entity_view` and skips cleanly on the empty CI/local default test DB.
   209	
   210	### LLM Model Configuration
   211	
   212	Local Gemini summary generation uses `gemini-3.5-flash` by default. Set `GEMINI_MODEL` to override the runtime model for API and worker processes; if it is unset, the API reads `gemini_model` from `api/config.yml`, then falls back to the built-in default.
   213	
   214	Unknown model IDs are rejected before any Gemini call. During local provider rollout testing, add comma-separated IDs to `GEMINI_ALLOWED_MODELS_EXTRA`; those models are accepted with an operator warning in the admin LLM configuration panel. Do not use the allowlist for shut-down catalog models such as `gemini-3-pro-preview`.
   215	
   216	### GeneNetworks fCoSE Layout Prewarm
   217	
   218	The GeneNetworks browser graph uses precomputed Cytoscape/fCoSE display positions when available. The worker computes the layout artifact with the Node helper in `api/layout/` and stores it under `/app/cache/network_layouts`.
   219	
   220	For local verification:
   221	
   222	```bash
   223	cd api/layout && npm test
   224	make dev
   225	curl -sS 'http://localhost/api/analysis/network_edges?cluster_type=clusters&max_edges=10000' | jq '.metadata.display_layout_status'
   226	```
   227	
   228	If the status is `missing`, `invalid`, or `error`, the frontend falls back to browser fCoSE. The frontend only uses Cytoscape `preset` when the API reports `display_layout_status = "available"` and every displayed gene node has finite artifact coordinates.
   229	
   230	### PubtatorNDD Gene-Count Enrichment Normalization
     1	{
     2	  "title": "SysNDD API",
     3	  "description": "This is the API powering the SysNDD website, allowing programmatic access to the database contents.",
     4	  "version": "0.30.1",
     5	  "contact": {
     6	    "name": "API Support",
     7	    "url": "https://berntpopp.github.io/sysndd/api.html",
     8	    "email": "support@sysndd.org"
     9	  },
    10	  "license": {
    11	    "name": "CC BY 4.0",
    12	    "url": "https://creativecommons.org/licenses/by/4.0/"
    13	  }
    14	}
     1	{
     2	  "name": "sysndd",
     3	  "version": "0.30.1",
     4	  "private": true,
     5	  "type": "module",
     6	  "scripts": {
     7	    "dev": "vite",
     8	    "build": "vue-tsc --noEmit && vite build",
     9	    "preview": "vite preview",
    10	    "dev:docker": "vite --mode docker",
    11	    "build:docker": "vite build --mode docker",
    12	    "build:production": "vite build --mode production",
    13	    "test:route-bundle-budget": "node --test scripts/verify-route-bundle-budget.test.mjs",
    14	    "verify:route-bundle-budget": "node scripts/verify-route-bundle-budget.mjs",
    15	    "build:bundle-budget": "npm run test:route-bundle-budget && BUNDLE_BUDGET=true npm run build:production && npm run verify:route-bundle-budget",
    16	    "seo:generate:fixture": "node scripts/generate-seo-pages.mjs --fixture scripts/fixtures/seo --out dist --base-url https://sysndd.dbmr.unibe.ch",
    17	    "seo:generate": "node scripts/generate-seo-pages.mjs --out dist",
    18	    "seo:verify": "node scripts/verify-seo-build.mjs dist",
    19	    "build:seo": "npm run build:production && npm run seo:generate:fixture",
    20	    "type-check": "vue-tsc --noEmit",
    21	    "type-check:strict": "node scripts/type-check-strict.js",
    22	    "lint": "eslint . --ext .vue,.js,.ts,.tsx",
    23	    "lint:fix": "eslint . --ext .vue,.js,.ts,.tsx --fix",
    24	    "format": "prettier --write \"src/**/*.{js,ts,vue,json,css,scss}\"",
    25	    "format:check": "prettier --check \"src/**/*.{js,ts,vue,json,css,scss}\"",
    26	    "prepare": "husky",
    27	    "test:unit": "vitest run",
    28	    "test:watch": "vitest watch",
    29	    "test:ui": "vitest --ui",
    30	    "test:coverage": "vitest run --coverage",
    31	    "test:e2e": "playwright test",
    32	    "test:e2e:ui": "playwright test --ui",
    33	    "test:e2e:codegen": "playwright codegen http://localhost:5173",
    34	    "docs:screenshots": "playwright test --config=playwright.docs-screenshots.config.ts"
    35	  },
    36	  "dependencies": {
    37	    "@popperjs/core": "^2.11.8",
    38	    "@unhead/vue": "^3.1.8",
    39	    "@upsetjs/bundle": "^1.11.0",
    40	    "@vee-validate/rules": "^4.15.1",
    41	    "@vueuse/core": "^14.3.0",
    42	    "bootstrap": "^5.3.8",
    43	    "bootstrap-icons": "^1.13.1",
    44	    "bootstrap-vue-next": "^0.45.8",
    45	    "chart.js": "^4.5.1",
    46	    "cytoscape": "^3.34.0",
    47	    "cytoscape-fcose": "^2.2.0",
    48	    "cytoscape-svg": "^0.4.0",
    49	    "d3": "^7.4.2",
    50	    "date-fns": "^4.4.0",
    51	    "dompurify": "^3.4.12",
    52	    "exceljs": "^4.4.0",
    53	    "file-saver": "^2.0.5",
    54	    "gsap": "^3.15.0",
    55	    "html2canvas": "^1.4.1",
    56	    "markdown-it": "^14.3.0",
    57	    "ngl": "^2.4.0",
    58	    "pinia": "^3.0.4",
    59	    "splitpanes": "^4.1.2",
    60	    "swagger-ui": "^5.32.8",
    61	    "swagger-ui-dist": "^5.32.8",
    62	    "vee-validate": "^4.15.1",
    63	    "vue": "^3.5.39",
    64	    "vue-chartjs": "^5.3.4",
    65	    "vue-dompurify-html": "^5.3.0",
    66	    "vue-router": "^5.1.0",
    67	    "vuedraggable": "^4.1.0"
    68	  },
    69	  "devDependencies": {
    70	    "@axe-core/playwright": "^4.12.1",
    71	    "@eslint/js": "^9.39.2",
    72	    "@playwright/test": "^1.61.1",
    73	    "@testing-library/dom": "^10.4.1",
    74	    "@testing-library/user-event": "^14.6.1",
    75	    "@testing-library/vue": "^8.1.0",
    76	    "@types/cytoscape": "^3.31.0",
    77	    "@types/d3": "^7.4.3",
    78	    "@types/dompurify": "^3.2.0",
    79	    "@types/markdown-it": "^14.1.2",
    80	    "@types/node": "^26.1.1",
    81	    "@vitejs/plugin-vue": "^6.0.7",
    82	    "@vitest/coverage-v8": "^4.1.10",
    83	    "@vitest/ui": "^4.0.18",
    84	    "@vue/compiler-sfc": "^3.5.39",
    85	    "@vue/test-utils": "^2.4.11",
    86	    "@vue/tsconfig": "^0.9.0",
    87	    "axios": "^1.18.1",
    88	    "cssnano": "^8.0.2",
    89	    "eslint": "^10.7.0",
    90	    "eslint-config-prettier": "^10.1.8",
    91	    "eslint-plugin-vue": "^10.9.2",
    92	    "globals": "^17.7.0",
    93	    "husky": "^9.1.7",
    94	    "jsdom": "^29.1.1",
    95	    "lint-staged": "^17.0.8",
    96	    "msw": "^2.15.0",
    97	    "postcss": "^8.5.19",
    98	    "prettier": "^3.9.5",
    99	    "rollup-plugin-visualizer": "^7.0.1",
   100	    "sass": "^1.101.0",
   101	    "typescript": "^6.0.3",
   102	    "typescript-eslint": "^8.63.0",
   103	    "vite": "^7.3.6",
   104	    "vite-plugin-pwa": "^1.3.0",
   105	    "vitest": "^4.0.18",
   106	    "vitest-axe": "^0.1.0",
   107	    "vue-eslint-parser": "^10.4.1",
   108	    "vue-tsc": "^3.3.7",
   109	    "workbox-window": "^7.4.1"
   110	  },
   111	  "overrides": {
   112	    "serialize-javascript": "^7.0.5",
   113	    "js-cookie": "3.0.7",
   114	    "qs": "6.15.2",
   115	    "uuid": "11.1.1"
   116	  },
   117	  "browserslist": [
   118	    "> 1%",
   119	    "last 2 versions",
   120	    "not dead"
   121	  ],
   122	  "lint-staged": {
   123	    "*.{ts,tsx,vue}": [
   124	      "eslint --fix --max-warnings=50",
   125	      "prettier --write"
   126	    ],
   127	    "*.{js}": [
   128	      "eslint --fix --max-warnings=50",
   129	      "prettier --write"
   130	    ],
   131	    "*.{json,md,yml,yaml,css,scss}": [
   132	      "prettier --write"
   133	    ]
   134	  }
   135	}
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

codex
The four intended fixes are present in the ordinary array paths: empty `genes: []` with a category is rejected; empty `genes: []` alone still selects the default; invalid source-version fetches are not committed to the TTL cache; and the integration test uses `base::get`. I’ve also found two boundary conditions worth validating in the targeted test run: JSON `null` key-presence and duplicate-gene result-meta consistency across cache-hit versus worker paths.
exec
/bin/bash -lc "rg -n -C 4 \"analysis_snapshot_source_data_version|clustering_cached_source_data_version|clustering_result_meta|resolved_gene_count|category_filter\" api --glob '*.R' | sed -n '1,260p'
printf '%s\\n' '--- full current #574 hunks only ---'
git diff --unified=12 origin/master...HEAD -- api/bootstrap/load_modules.R api/endpoints/jobs_endpoints.R api/functions/async-job-handlers.R api/functions/clustering-gene-universe.R api/services/job-functional-submission-service.R api/tests/testthat/job-endpoint-services-fixtures.R api/tests/testthat/test-integration-clustering-category-submit.R api/tests/testthat/test-unit-async-job-handlers.R api/tests/testthat/test-unit-async-job-worker.R api/tests/testthat/test-unit-clustering-gene-universe.R api/tests/testthat/test-unit-clustering-handler-meta.R api/tests/testthat/test-unit-job-endpoint-services-phenotype.R api/tests/testthat/test-unit-job-endpoint-services.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/tests/testthat/test-unit-analysis-snapshot-repository.R-121-      ))
api/tests/testthat/test-unit-analysis-snapshot-repository.R-122-    }
api/tests/testthat/test-unit-analysis-snapshot-repository.R-123-    tibble::tibble()
api/tests/testthat/test-unit-analysis-snapshot-repository.R-124-  }
api/tests/testthat/test-unit-analysis-snapshot-repository.R:125:  env$analysis_snapshot_source_data_version <- function(conn = NULL) "new-source"
api/tests/testthat/test-unit-analysis-snapshot-repository.R-126-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-127-  snapshot <- env$analysis_snapshot_get_public("phenotype_clusters", "hash")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-128-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-129-  expect_equal(snapshot$status_code, "source_version_mismatch")
--
api/tests/testthat/test-unit-async-job-worker.R-15-    # functions by bare symbol inside an eagerly-evaluated list(), so both
api/tests/testthat/test-unit-async-job-worker.R-16-    # extracted modules must be sourced before async-job-handlers.R here too.
api/tests/testthat/test-unit-async-job-worker.R-17-    file.path(api_dir, "functions", "async-job-provider-handlers.R"),
api/tests/testthat/test-unit-async-job-worker.R-18-    file.path(api_dir, "functions", "async-job-maintenance-handlers.R"),
api/tests/testthat/test-unit-async-job-worker.R:19:    # .async_job_run_clustering assembles its result meta via clustering_result_meta()
api/tests/testthat/test-unit-async-job-worker.R-20-    # (#574); source it before async-job-handlers.R as load_modules.R does in production.
api/tests/testthat/test-unit-async-job-worker.R-21-    file.path(api_dir, "functions", "clustering-gene-universe.R"),
api/tests/testthat/test-unit-async-job-worker.R-22-    file.path(api_dir, "functions", "async-job-handlers.R"),
api/tests/testthat/test-unit-async-job-worker.R-23-    file.path(api_dir, "functions", "async-job-worker.R"),
--
api/tests/testthat/test-unit-analysis-snapshot-builder.R-123-  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-124-    record_conn("release", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-125-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-126-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R:127:  env$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-128-    record_conn("source_version", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-129-    "source-v1"
api/tests/testthat/test-unit-analysis-snapshot-builder.R-130-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-131-  env$analysis_snapshot_build_payload <- function(analysis_type, params, conn = NULL) {
--
api/tests/testthat/test-unit-analysis-snapshot-builder.R-232-  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-233-    record_conn("release", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-234-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-235-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R:236:  env$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-237-    record_conn("source_version", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-238-    "source-v1"
api/tests/testthat/test-unit-analysis-snapshot-builder.R-239-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-240-  env$analysis_snapshot_build_payload <- function(analysis_type, params, conn = NULL) {
--
api/tests/testthat/test-unit-analysis-snapshot-builder.R-299-  env$get_db_connection <- function() refresh_conn
api/tests/testthat/test-unit-analysis-snapshot-builder.R-300-  env$db_with_transaction <- function(code, pool_obj = NULL) code(pool_obj)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-301-  env$analysis_snapshot_acquire_lock <- function(...) TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-302-  env$analysis_snapshot_release_lock <- function(...) TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R:303:  env$analysis_snapshot_source_data_version <- function(...) "source-v1"
api/tests/testthat/test-unit-analysis-snapshot-builder.R-304-  env$analysis_snapshot_build_payload <- function(...) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-305-    list(
api/tests/testthat/test-unit-analysis-snapshot-builder.R-306-      kind = "clusters",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-307-      raw = clusters,
--
api/tests/testthat/job-endpoint-services-fixtures.R-23-#' isolated tests exercise the downstream request/response logic. A test can override
api/tests/testthat/job-endpoint-services-fixtures.R-24-#' `env$async_job_submit_admission_guard` to exercise the throttle-block path.
api/tests/testthat/job-endpoint-services-fixtures.R-25-#'
api/tests/testthat/job-endpoint-services-fixtures.R-26-#' Also sources `functions/clustering-gene-universe.R` (#574 D1/D3) into `env` so
api/tests/testthat/job-endpoint-services-fixtures.R:27:#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
api/tests/testthat/job-endpoint-services-fixtures.R-28-#' `job-functional-submission-service.R`'s cache-hit path -- is available for real
api/tests/testthat/job-endpoint-services-fixtures.R-29-#' (a pure list-assembly function, safe to source unstubbed). Individual tests still
api/tests/testthat/job-endpoint-services-fixtures.R-30-#' stub the DB/cache-touching siblings from that same file
api/tests/testthat/job-endpoint-services-fixtures.R-31-#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
api/tests/testthat/job-endpoint-services-fixtures.R:32:#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
api/tests/testthat/job-endpoint-services-fixtures.R-33-#' this sourcing only supplies defaults those stubs override.
api/tests/testthat/job-endpoint-services-fixtures.R-34-job_endpoint_source_service <- function(filename) {
api/tests/testthat/job-endpoint-services-fixtures.R-35-  env <- new.env(parent = globalenv())
api/tests/testthat/job-endpoint-services-fixtures.R-36-  env$async_job_submit_admission_guard <- function(req, res) list(admitted = TRUE)
--
api/functions/clustering-gene-universe.R-2-#
api/functions/clustering-gene-universe.R-3-# Category-selected clustering gene-universe resolver (#574 D1).
api/functions/clustering-gene-universe.R-4-#
api/functions/clustering-gene-universe.R-5-# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
api/functions/clustering-gene-universe.R:6:# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
api/functions/clustering-gene-universe.R-7-# universe from curated SysNDD confidence categories instead of the default
api/functions/clustering-gene-universe.R-8-# "all NDD genes" set. This file builds ONLY the resolver + provenance
api/functions/clustering-gene-universe.R-9-# helpers; the submit service and durable handler wiring is done later.
api/functions/clustering-gene-universe.R-10-#
--
api/functions/clustering-gene-universe.R-22-
api/functions/clustering-gene-universe.R-23-# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
api/functions/clustering-gene-universe.R-24-# selector returns character(0), which the resolver rejects with 400 -- it must
api/functions/clustering-gene-universe.R-25-# never fall through to the all-NDD default.
api/functions/clustering-gene-universe.R:26:clustering_normalize_category_filter <- function(category_filter) {
api/functions/clustering-gene-universe.R:27:  if (is.null(category_filter)) return(NULL)
api/functions/clustering-gene-universe.R:28:  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
api/functions/clustering-gene-universe.R-29-  vals <- vals[nzchar(vals)]
api/functions/clustering-gene-universe.R-30-  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
api/functions/clustering-gene-universe.R-31-  sort(unique(vals))
api/functions/clustering-gene-universe.R-32-}
--
api/functions/clustering-gene-universe.R-37-    algo = "sha256", serialize = FALSE
api/functions/clustering-gene-universe.R-38-  )
api/functions/clustering-gene-universe.R-39-}
api/functions/clustering-gene-universe.R-40-
api/functions/clustering-gene-universe.R:41:clustering_resolve_category_universe <- function(category_filter, conn = pool) {
api/functions/clustering-gene-universe.R:42:  selector <- clustering_normalize_category_filter(category_filter)
api/functions/clustering-gene-universe.R-43-
api/functions/clustering-gene-universe.R-44-  if (is.null(selector)) {
api/functions/clustering-gene-universe.R-45-    # Absent -> preserve the exact current default ordering for cache parity.
api/functions/clustering-gene-universe.R-46-    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
api/functions/clustering-gene-universe.R:47:    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
api/functions/clustering-gene-universe.R-48-  }
api/functions/clustering-gene-universe.R-49-  if (length(selector) == 0L) {
api/functions/clustering-gene-universe.R:50:    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
api/functions/clustering-gene-universe.R-51-  }
api/functions/clustering-gene-universe.R-52-
api/functions/clustering-gene-universe.R-53-  active <- conn %>%
api/functions/clustering-gene-universe.R-54-    dplyr::tbl("ndd_entity_status_categories_list") %>%
--
api/functions/clustering-gene-universe.R-59-  unknown <- setdiff(selector, active)
api/functions/clustering-gene-universe.R-60-  if (length(unknown) > 0L) {
api/functions/clustering-gene-universe.R-61-    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
api/functions/clustering-gene-universe.R-62-    stop_for_bad_request(sprintf(
api/functions/clustering-gene-universe.R:63:      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
api/functions/clustering-gene-universe.R-64-      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
api/functions/clustering-gene-universe.R-65-    ))
api/functions/clustering-gene-universe.R-66-  }
api/functions/clustering-gene-universe.R-67-
--
api/functions/clustering-gene-universe.R-75-    dplyr::pull(hgnc_id)
api/functions/clustering-gene-universe.R-76-
api/functions/clustering-gene-universe.R-77-  if (length(hgnc_ids) < 2L) {
api/functions/clustering-gene-universe.R-78-    stop_for_bad_request(sprintf(
api/functions/clustering-gene-universe.R:79:      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
api/functions/clustering-gene-universe.R-80-      paste(selector, collapse = ","), length(hgnc_ids)
api/functions/clustering-gene-universe.R-81-    ))
api/functions/clustering-gene-universe.R-82-  }
api/functions/clustering-gene-universe.R:83:  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
api/functions/clustering-gene-universe.R-84-}
api/functions/clustering-gene-universe.R-85-
api/functions/clustering-gene-universe.R-86-# Module-level (survives across requests within the same process) cache for
api/functions/clustering-gene-universe.R:87:# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
api/functions/clustering-gene-universe.R-88-# public tables and changes rarely (only when the snapshot builder's source
api/functions/clustering-gene-universe.R-89-# view moves), so a short-TTL process cache avoids paying that cost on every
api/functions/clustering-gene-universe.R-90-# clustering submit while still self-refreshing.
api/functions/clustering-gene-universe.R-91-.clustering_source_data_version_cache <- new.env(parent = emptyenv())
--
api/functions/clustering-gene-universe.R-106-#' D2 (#574) provenance helper: the clustering submit service calls this
api/functions/clustering-gene-universe.R-107-#' AFTER admission/dedup, only when it is actually about to build a durable
api/functions/clustering-gene-universe.R-108-#' payload. Refetches once `ttl_seconds` has elapsed since the last
api/functions/clustering-gene-universe.R-109-#' successful read. Deliberately does NOT wrap
api/functions/clustering-gene-universe.R:110:#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
api/functions/clustering-gene-universe.R-111-#' PROPAGATES to the caller (never cached, never coerced to NA), so a
api/functions/clustering-gene-universe.R-112-#' transient DB problem fails the submit closed (503) instead of recording
api/functions/clustering-gene-universe.R-113-#' broken provenance. The fetched value is additionally validated by
api/functions/clustering-gene-universe.R-114-#' `.clustering_valid_source_version()`: an invalid value (NA/empty/
--
api/functions/clustering-gene-universe.R-119-#' @param conn DB connection/pool. Defaults to the package-global `pool`.
api/functions/clustering-gene-universe.R-120-#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
api/functions/clustering-gene-universe.R-121-#' @return character(1) source data version.
api/functions/clustering-gene-universe.R-122-#' @export
api/functions/clustering-gene-universe.R:123:clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
api/functions/clustering-gene-universe.R-124-  now <- Sys.time()
api/functions/clustering-gene-universe.R-125-  cached_at <- .clustering_source_data_version_cache$cached_at
api/functions/clustering-gene-universe.R-126-  cached_value <- .clustering_source_data_version_cache$value
api/functions/clustering-gene-universe.R-127-  if (!is.null(cached_at) && .clustering_valid_source_version(cached_value) &&
api/functions/clustering-gene-universe.R-128-        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
api/functions/clustering-gene-universe.R-129-    return(cached_value)
api/functions/clustering-gene-universe.R-130-  }
api/functions/clustering-gene-universe.R-131-
api/functions/clustering-gene-universe.R:132:  value <- analysis_snapshot_source_data_version(conn = conn)
api/functions/clustering-gene-universe.R-133-
api/functions/clustering-gene-universe.R-134-  if (!.clustering_valid_source_version(value)) {
api/functions/clustering-gene-universe.R-135-    stop(
api/functions/clustering-gene-universe.R:136:      "clustering_cached_source_data_version: analysis_snapshot_source_data_version() ",
api/functions/clustering-gene-universe.R-137-      "returned an invalid (NULL/NA/empty/non-scalar) value; refusing to cache or serve it"
api/functions/clustering-gene-universe.R-138-    )
api/functions/clustering-gene-universe.R-139-  }
api/functions/clustering-gene-universe.R-140-
--
api/functions/clustering-gene-universe.R-143-  value
api/functions/clustering-gene-universe.R-144-}
api/functions/clustering-gene-universe.R-145-
api/functions/clustering-gene-universe.R-146-# Assemble the clustering result `meta`: base fields + the cheap-path provenance
api/functions/clustering-gene-universe.R:147:# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
api/functions/clustering-gene-universe.R-148-# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
api/functions/clustering-gene-universe.R-149-# observed post-compute. Shared by the cache-hit path
api/functions/clustering-gene-universe.R-150-# (job-functional-submission-service.R) and the worker-run/durable handler
api/functions/clustering-gene-universe.R-151-# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
api/functions/clustering-gene-universe.R-152-# shapes cannot drift apart by hand-copied edits.
api/functions/clustering-gene-universe.R:153:clustering_result_meta <- function(base, provenance, weight_channel) {
api/functions/clustering-gene-universe.R-154-  c(base,
api/functions/clustering-gene-universe.R-155-    if (!is.null(provenance)) provenance else list(),
api/functions/clustering-gene-universe.R-156-    list(effective_fingerprint = list(weight_channel = weight_channel)))
api/functions/clustering-gene-universe.R-157-}
--
api/tests/testthat/test-mcp-analysis-repository.R-22-    tibble::tibble(source_data_version = "source-v1")
api/tests/testthat/test-mcp-analysis-repository.R-23-  }, envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-repository.R-24-  withr::defer(restore_mcp_binding("db_execute_query", old_query))
api/tests/testthat/test-mcp-analysis-repository.R-25-
api/tests/testthat/test-mcp-analysis-repository.R:26:  expect_equal(analysis_snapshot_source_data_version(), "source-v1")
api/tests/testthat/test-mcp-analysis-repository.R-27-  expect_true(any(grepl("mcp_public_analysis_source_version", sql_seen, fixed = TRUE)))
api/tests/testthat/test-mcp-analysis-repository.R-28-  expect_false(any(grepl("ndd_entity_view|ndd_entity_review", sql_seen)))
api/tests/testthat/test-mcp-analysis-repository.R-29-})
api/tests/testthat/test-mcp-analysis-repository.R-30-
--
api/tests/testthat/test-unit-async-job-handlers.R-1-library(testthat)
api/tests/testthat/test-unit-async-job-handlers.R-2-
api/tests/testthat/test-unit-async-job-handlers.R-3-source_api_file("functions/async-job-force-apply-payload.R", local = FALSE)
api/tests/testthat/test-unit-async-job-handlers.R-4-source_api_file("functions/async-job-omim-apply.R", local = FALSE)
api/tests/testthat/test-unit-async-job-handlers.R:5:# .async_job_run_clustering assembles its result meta via clustering_result_meta()
api/tests/testthat/test-unit-async-job-handlers.R-6-# (clustering-gene-universe.R, #574); source it so the handler resolves it here as
api/tests/testthat/test-unit-async-job-handlers.R-7-# it does in the worker (bootstrap_load_modules sources it before the handlers).
api/tests/testthat/test-unit-async-job-handlers.R-8-source_api_file("functions/clustering-gene-universe.R", local = FALSE)
api/tests/testthat/test-unit-async-job-handlers.R-9-# The eagerly-built async_job_handler_registry list() references provider and
--
api/endpoints/jobs_endpoints.R-27-#* Submits an async job to compute functional clustering via STRING-db. The
api/endpoints/jobs_endpoints.R-28-#* clustering gene universe (#574) is resolved from one of three mutually
api/endpoints/jobs_endpoints.R-29-#* exclusive JSON body selectors:
api/endpoints/jobs_endpoints.R-30-#*   - `genes`: an explicit array of HGNC ids to cluster.
api/endpoints/jobs_endpoints.R:31:#*   - `category_filter`: an array of curated SysNDD confidence categories
api/endpoints/jobs_endpoints.R-32-#*     (e.g. `["Definitive"]`); resolved entity-level (>=1 NDD entity in a
api/endpoints/jobs_endpoints.R-33-#*     selected category, `ndd_phenotype = 1`) against the live
api/endpoints/jobs_endpoints.R-34-#*     `ndd_entity_view`, validated against the live active
api/endpoints/jobs_endpoints.R-35-#*     `ndd_entity_status_categories_list`. A category run rejects with 400
api/endpoints/jobs_endpoints.R:36:#*     when `category_filter` is empty, contains an unknown/inactive value
api/endpoints/jobs_endpoints.R-37-#*     (the allowed active set is named in the error), or resolves fewer
api/endpoints/jobs_endpoints.R-38-#*     than 2 genes.
api/endpoints/jobs_endpoints.R-39-#*   - neither: the existing default all-NDD-genes universe.
api/endpoints/jobs_endpoints.R:40:#* Supplying both `genes` and a non-empty `category_filter` is a 400.
api/endpoints/jobs_endpoints.R-41-#*
api/endpoints/jobs_endpoints.R-42-#* Every submit records selector/fingerprint provenance -- `selector`
api/endpoints/jobs_endpoints.R:43:#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
api/endpoints/jobs_endpoints.R:44:#* category runs), `resolved_gene_count`, `gene_list_sha256`,
api/endpoints/jobs_endpoints.R-45-#* `intended_fingerprint`, and `source_data_version` -- in the durable job
api/endpoints/jobs_endpoints.R-46-#* payload; the job result `meta` additionally carries `effective_fingerprint`
api/endpoints/jobs_endpoints.R-47-#* (the STRING `weight_channel` actually observed on the computed result),
api/endpoints/jobs_endpoints.R-48-#* recorded on both a cache-hit (immediate) response and a worker-run
--
api/endpoints/jobs_endpoints.R-56-#*
api/endpoints/jobs_endpoints.R-57-#* @tag jobs
api/endpoints/jobs_endpoints.R-58-#* @serializer json list(na="string")
api/endpoints/jobs_endpoints.R-59-#* @param genes Optional JSON array of explicit HGNC ids. Mutually exclusive
api/endpoints/jobs_endpoints.R:60:#*   with `category_filter`.
api/endpoints/jobs_endpoints.R:61:#* @param category_filter Optional JSON array of curated SysNDD confidence
api/endpoints/jobs_endpoints.R-62-#*   categories (e.g. `["Definitive"]`). Mutually exclusive with `genes`.
api/endpoints/jobs_endpoints.R-63-#* @param algorithm Optional clustering algorithm string, `"leiden"`
api/endpoints/jobs_endpoints.R-64-#*   (default) or `"walktrap"`.
api/endpoints/jobs_endpoints.R-65-#* @post /clustering/submit
--
api/tests/testthat/test-mcp-analysis-service.R-346-  source_mcp_analysis_repository()
api/tests/testthat/test-mcp-analysis-service.R-347-
api/tests/testthat/test-mcp-analysis-service.R-348-  old_db <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
api/tests/testthat/test-mcp-analysis-service.R-349-  old_get_public <- get0("analysis_snapshot_get_public", envir = .GlobalEnv, ifnotfound = NULL)
api/tests/testthat/test-mcp-analysis-service.R:350:  old_source_version <- get0("analysis_snapshot_source_data_version", envir = .GlobalEnv, ifnotfound = NULL)
api/tests/testthat/test-mcp-analysis-service.R-351-  seen_query <- NULL
api/tests/testthat/test-mcp-analysis-service.R-352-  assign("db_execute_query", function(query, params = list(), conn = NULL) {
api/tests/testthat/test-mcp-analysis-service.R-353-    seen_query <<- query
api/tests/testthat/test-mcp-analysis-service.R-354-    expect_equal(params[[1]], "phenotype_correlations")
api/tests/testthat/test-mcp-analysis-service.R-355-    tibble::tibble(snapshot_id = 1L, source_data_version = "source-v1", stale_after = Sys.time() + 3600)
api/tests/testthat/test-mcp-analysis-service.R-356-  }, envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-service.R-357-  assign("analysis_snapshot_get_public", function(...) stop("full snapshot getter called"), envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-service.R:358:  assign("analysis_snapshot_source_data_version", function(...) NULL, envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-service.R-359-  withr::defer({
api/tests/testthat/test-mcp-analysis-service.R-360-    if (is.null(old_db)) {
api/tests/testthat/test-mcp-analysis-service.R-361-      rm("db_execute_query", envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-service.R-362-    } else {
--
api/tests/testthat/test-mcp-analysis-service.R-367-    } else {
api/tests/testthat/test-mcp-analysis-service.R-368-      assign("analysis_snapshot_get_public", old_get_public, envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-service.R-369-    }
api/tests/testthat/test-mcp-analysis-service.R-370-    if (is.null(old_source_version)) {
api/tests/testthat/test-mcp-analysis-service.R:371:      rm("analysis_snapshot_source_data_version", envir = .GlobalEnv)
--- full current #574 hunks only ---
diff --git a/api/bootstrap/load_modules.R b/api/bootstrap/load_modules.R
index 512a3065..09f44069 100644
--- a/api/bootstrap/load_modules.R
+++ b/api/bootstrap/load_modules.R
@@ -125,24 +125,30 @@ bootstrap_load_modules <- function() {
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
diff --git a/api/endpoints/jobs_endpoints.R b/api/endpoints/jobs_endpoints.R
index 4ffad4c5..b4ef4f08 100644
--- a/api/endpoints/jobs_endpoints.R
+++ b/api/endpoints/jobs_endpoints.R
@@ -15,29 +15,62 @@
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
diff --git a/api/functions/async-job-handlers.R b/api/functions/async-job-handlers.R
index d3691475..9eccf745 100644
--- a/api/functions/async-job-handlers.R
+++ b/api/functions/async-job-handlers.R
@@ -10,24 +10,28 @@
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
@@ -87,44 +91,65 @@
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
+  meta <- clustering_result_meta(
+    list(
+      algorithm = algorithm,
+      gene_count = length(genes),
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
index 150c61e0..7c20f0a9 100644
--- a/api/services/job-functional-submission-service.R
+++ b/api/services/job-functional-submission-service.R
@@ -15,96 +15,181 @@
 
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
+  # existing default all-NDD-genes universe. Presence is decided from the RAW
+  # request field, not a length check, so an explicitly-empty category_filter
+  # still reaches (and is rejected by) the resolver instead of silently
+  # falling through to the all-NDD default.
+  genes_in <- req$argsBody$genes
+  category_supplied <- !is.null(req$argsBody$category_filter)
+  # Mutual exclusion is gated on KEY PRESENCE (`genes_supplied`), not a length
+  # check -- `{"genes":[], "category_filter":["X"]}` supplies BOTH keys and
+  # must 400 even though the `genes` array is empty (Codex review fix: an
+  # empty-but-present `genes` array previously bypassed this guard because
+  # `has_genes` -- used below for the LATER branch-selection decision, kept
+  # unchanged -- is also FALSE on an empty array).
+  genes_supplied <- !is.null(genes_in)
+  has_genes <- !is.null(genes_in) && length(genes_in) > 0
+
+  if (genes_supplied && category_supplied) {
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
+  } else if (category_supplied) {
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
@@ -141,42 +226,59 @@ svc_job_submit_functional_clustering <- function(req, res) {
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
       priority = 50L
     )
     job_id <- completed_job$job_id[[1]]
 
     res$status <- 202
     res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
     res$setHeader("Retry-After", "0")
 
     return(list(
@@ -200,32 +302,37 @@ svc_job_submit_functional_clustering <- function(req, res) {
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
+  job_params <- list(
+    genes = genes_list,
+    algorithm = algorithm,
+    category_links = category_links,
+    string_id_table = string_id_table,
+    provenance = provenance
+  )
+  if (!is.null(selector_chr)) {
+    job_params$category_filter <- selector_chr
+  }
   result <- create_job(
     operation = "clustering",
-    params = list(
-      genes = genes_list,
-      algorithm = algorithm,
-      category_links = category_links,
-      string_id_table = string_id_table
-    )
+    params = job_params
   )
 
   # Check capacity
   if (!is.null(result$error)) {
     res$status <- 503
     res$setHeader("Retry-After", as.character(result$retry_after))
     return(result)
   }
 
   # Success - return HTTP 202 Accepted
   res$status <- 202
   res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
diff --git a/api/tests/testthat/job-endpoint-services-fixtures.R b/api/tests/testthat/job-endpoint-services-fixtures.R
index 103f4621..d2deaae1 100644
--- a/api/tests/testthat/job-endpoint-services-fixtures.R
+++ b/api/tests/testthat/job-endpoint-services-fixtures.R
@@ -13,27 +13,37 @@
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
 
 #' Minimal Plumber-response stand-in: an environment with `$status` and a
 #' `$setHeader()` that records every header set (mirrors the `res_env`
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
@@ -1,16 +1,20 @@
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
 
diff --git a/api/tests/testthat/test-unit-async-job-worker.R b/api/tests/testthat/test-unit-async-job-worker.R
index 792903e1..237528a0 100644
--- a/api/tests/testthat/test-unit-async-job-worker.R
+++ b/api/tests/testthat/test-unit-async-job-worker.R
@@ -7,24 +7,27 @@ async_job_worker_runtime_paths <- function() {
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
+    # .async_job_run_clustering assembles its result meta via clustering_result_meta()
+    # (#574); source it before async-job-handlers.R as load_modules.R does in production.
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
diff --git a/api/tests/testthat/test-unit-clustering-gene-universe.R b/api/tests/testthat/test-unit-clustering-gene-universe.R
new file mode 100644
index 00000000..ec0c4bc5
--- /dev/null
+++ b/api/tests/testthat/test-unit-clustering-gene-universe.R
@@ -0,0 +1,278 @@
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
+test_that("supplied-but-empty selector is 400 (NOT the all-NDD default)", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+
+  expect_error(e$clustering_resolve_category_universe(list(), conn = con), class = "error_400")
+  expect_error(e$clustering_resolve_category_universe(list("   "), conn = con), class = "error_400")
+})
+
+test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job)", {
+  e <- .gene_universe_env()
+  con <- fake_conn(ev, cats)
+  withr::defer(DBI::dbDisconnect(con))
+
+  expect_error(e$clustering_resolve_category_universe("Refuted", conn = con), class = "error_400") # 0 genes
+  expect_error(e$clustering_resolve_category_universe("Moderate", conn = con), class = "error_400") # 1 gene
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
index 00000000..0bdbf7fa
--- /dev/null
+++ b/api/tests/testthat/test-unit-clustering-handler-meta.R
@@ -0,0 +1,145 @@
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
index 3bb4b43f..d998316d 100644
--- a/api/tests/testthat/test-unit-job-endpoint-services.R
+++ b/api/tests/testthat/test-unit-job-endpoint-services.R
@@ -1,22 +1,25 @@
 # tests/testthat/test-unit-job-endpoint-services.R
 #
-# Host-runnable unit tests for the PUBLIC clustering submission services extracted
+# Host-runnable unit tests for the PUBLIC clustering submission service extracted
 # from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
-# submission-service.R and job-phenotype-submission-service.R. The maintenance-
-# submission (job-maintenance-submission-service.R) and query-endpoint
-# (job-query-endpoint-service.R) services are covered in the sibling
+# submission-service.R. The sibling job-phenotype-submission-service.R coverage
+# lives in test-unit-job-endpoint-services-phenotype.R (split out here, #574
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
@@ -39,31 +42,56 @@ job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
     non_alt_loci_set = tibble::tibble(
       symbol = c("A", "B"),
       hgnc_id = c("HGNC:1", "HGNC:3"),
       STRING_id = c("9606.P1", "9606.P2")
     )
   )
   if (!is.null(ndd_entity_view)) {
     tables$ndd_entity_view <- ndd_entity_view
   }
   job_endpoint_fake_pool(env, tables)
 }
 
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
@@ -88,55 +116,71 @@ job_endpoint_capture_functional_algorithm <- function(algorithm_body) {
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
   create_job_operation <- NULL
   create_job_params <- NULL
@@ -144,26 +188,29 @@ test_that("functional clustering: capacity guard (503) then a cache miss under c
     create_job_operation <<- operation
     create_job_params <<- params
     list(job_id = "new-job-1", status = "accepted", estimated_seconds = 30)
   }
   res <- job_endpoint_fake_res()
   out <- env$svc_job_submit_functional_clustering(req, res)
   expect_equal(res$status, 202)
   expect_equal(res$headers[["Retry-After"]], "5")
   expect_equal(out$job_id, "new-job-1")
   expect_equal(create_job_operation, "clustering")
   expect_setequal(
     names(create_job_params),
-    c("genes", "algorithm", "category_links", "string_id_table")
+    # #574 D2: every submit path now carries a `provenance` block; explicit/
+    # no-arg submits still omit `category_filter` (asserted separately below).
+    c("genes", "algorithm", "category_links", "string_id_table", "provenance")
   )
+  expect_false("category_filter" %in% names(create_job_params))
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
@@ -179,202 +226,234 @@ test_that("functional clustering: admission throttle runs FIRST, before any DB/c
     res$setHeader("Retry-After", "42")
     list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
   }
   res <- job_endpoint_fake_res()
   out <- env$svc_job_submit_functional_clustering(req, res)
   expect_equal(res$status, 429)
   expect_equal(out$error, "RATE_LIMITED")
   expect_false(pool_touched)
   expect_false(create_job_called)
 })
 
 ## -------------------------------------------------------------------##
-## job-phenotype-submission-service.R
+## job-functional-submission-service.R: category_filter (#574 D2)
 ## -------------------------------------------------------------------##
 
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
   res <- job_endpoint_fake_res()
 
-  env$svc_job_submit_phenotype_clustering(req, res)
+  expect_error(
+    env$svc_job_submit_functional_clustering(req, res),
+    class = "error_400"
+  )
+})
 
-  # Only review_id 1 (primary + approved) survives the gather step; review 2
-  # (unapproved) and review 3 (not primary) must never reach the clustering
-  # input, even though review 2 is attached to the same (otherwise-included)
-  # entity_id as review 1.
-  expect_equal(captured_params$ndd_entity_review_tbl$review_id, 1L)
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
 })
 
-test_that("phenotype clustering: duplicate job returns 409 with Location", {
-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
-  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
-  env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = "dup-pheno")
-  req <- list(user = list(user_id = NULL))
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
   res <- job_endpoint_fake_res()
 
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
+  out <- env$svc_job_submit_functional_clustering(req, res)
 
+  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   expect_equal(res$status, 409)
   expect_equal(out$error, "DUPLICATE_JOB")
-  expect_match(res$headers[["Location"]], "/api/jobs/dup-pheno/status")
 })
 
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
+test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
+  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
+    expect_identical(category_filter, list("Definitive"))
+    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
   }
-  store_args <- NULL
-  env$async_job_service_store_completed <- function(...) {
-    store_args <<- list(...)
-    tibble::tibble(job_id = "cached-pheno-1")
+  env$check_duplicate_job <- function(operation, params) {
+    expect_true("category_filter" %in% names(params))
+    expect_identical(params$category_filter, "Definitive")
+    list(duplicate = FALSE)
   }
-  create_job_called <- FALSE
-  env$create_job <- function(...) create_job_called <<- TRUE
-  req <- list(user = list(user_id = 7L))
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  env$async_job_active_count <- function(...) 0L
+  captured <- NULL
+  env$create_job <- function(operation, params) {
+    captured <<- params
+    list(job_id = "j1", status = "accepted", estimated_seconds = 5)
+  }
+  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
 
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
+  out <- env$svc_job_submit_functional_clustering(req, res)
 
-  expect_false(create_job_called)
   expect_equal(res$status, 202)
-  expect_equal(out$job_id, "cached-pheno-1")
-  expect_equal(store_args$submitted_by, 7L)
+  expect_identical(captured$category_filter, "Definitive")
+  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
+  expect_identical(captured$provenance$selector$kind, "category")
+  expect_identical(captured$provenance$selector$category_filter, "Definitive")
+  expect_true(all(
+    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
+      names(captured$provenance)
+  ))
 })
 
-test_that("phenotype clustering: capacity guard (503) then a cache miss under capacity (202)", {
-  req <- list(user = list(user_id = NULL))
-
-  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
-  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
+test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
+  # Explicit genes.
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  job_endpoint_stub_clustering_provenance(env)
   env$check_duplicate_job <- function(...) list(duplicate = FALSE)
-  env$async_job_capacity_exceeded <- function(...) TRUE
-  env$async_job_active_count <- function(...) 5L
-  res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_phenotype_clustering(req, res)
-  expect_equal(res$status, 503)
-  expect_equal(res$headers[["Retry-After"]], "60")
-  expect_equal(out$error, "CAPACITY_EXCEEDED")
+  env$async_job_capacity_exceeded <- function(...) FALSE
+  env$async_job_active_count <- function(...) 0L
+  captured_explicit <- NULL
+  env$create_job <- function(operation, params) {
+    captured_explicit <<- params
+    list(job_id = "j2", status = "accepted", estimated_seconds = 5)
+  }
+  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
+  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
+
+  expect_false("category_filter" %in% names(captured_explicit))
+  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
+  expect_null(captured_explicit$provenance$selector$category_filter)
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
+  env2$create_job <- function(operation, params) {
+    captured_no_arg <<- params
+    list(job_id = "j3", status = "accepted", estimated_seconds = 5)
+  }
+  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
+  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
+
+  expect_false("category_filter" %in% names(captured_no_arg))
+  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
+  expect_null(captured_no_arg$provenance$selector$category_filter)
+})
 
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
   env$async_job_capacity_exceeded <- function(...) FALSE
-  create_job_params <- NULL
+  env$async_job_active_count <- function(...) 0L
+  captured <- NULL
   env$create_job <- function(operation, params) {
-    create_job_params <<- params
-    list(job_id = "new-pheno-1", status = "accepted", estimated_seconds = 30)
+    captured <<- params
+    list(job_id = "j-dup-genes", status = "accepted", estimated_seconds = 5)
   }
+  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
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
+
+  env$svc_job_submit_functional_clustering(req, res)
+
+  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
+  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
 })
 
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
   }
-  succeed()
+  g <- c("HGNC:1", "HGNC:5")
+
+  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
+  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
+  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
 })
 
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
+test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
+  env <- job_endpoint_source_service("job-functional-submission-service.R")
+  env$pool <- job_endpoint_functional_pool(env)
+  env$analysis_string_cache_fingerprint <- function() "fp-test"
+  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
+  env$clustering_cached_source_data_version <- function(...) stop("boom")
+  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   create_job_called <- FALSE
   env$create_job <- function(...) {
     create_job_called <<- TRUE
     NULL
   }
-  env$async_job_submit_admission_guard <- function(req, res) {
-    res$status <- 429
-    res$setHeader("Retry-After", "42")
-    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
-  }
+  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
-  out <- env$svc_job_submit_phenotype_clustering(list(user = list(user_id = NULL)), res)
-  expect_equal(res$status, 429)
-  expect_equal(out$error, "RATE_LIMITED")
-  expect_false(pool_touched)
+
+  out <- env$svc_job_submit_functional_clustering(req, res)
+
+  expect_equal(res$status, 503L)
+  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   expect_false(create_job_called)
 })
+
+# job-phenotype-submission-service.R coverage lives in
+# test-unit-job-endpoint-services-phenotype.R (split out to keep this file under
+# the 600-line ceiling, #574 Codex-review-fix pass).

codex
Findings:

- HIGH — [job-functional-submission-service.R:60-71](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:60): JSON `{"genes":null,"category_filter":["Definitive"]}` bypasses mutual exclusion. `genes_in` is `NULL`, so `genes_supplied` is false despite the `genes` key being present; the category request is accepted. Fix: determine selector presence from `names(req$argsBody)`, not value nullness, and reject an explicitly null `category_filter` rather than treating it as absent.

- MEDIUM — [job-functional-submission-service.R:252](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:252), [async-job-handlers.R:132](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/functions/async-job-handlers.R:132): duplicate explicit genes produce inconsistent result metadata. For `["HGNC:1","HGNC:1"]`, a cache hit reports `meta.gene_count = 1`, while a worker-run result reports `meta.gene_count = 2`; both carry `resolved_gene_count = 1`. Fix: have the worker compute `gene_count` using the same sorted/unique convention (or centralize the count helper), without changing the payload `genes` list.

Prior findings:

1. HIGH mutual exclusion: partially fixed. `genes: []` plus a category now correctly returns 400; `genes: []` alone still defaults; non-empty `genes` remains explicit. However, it is not fully key-presence-correct for JSON `null`, so this remains HIGH.
2. HIGH source-version cache: resolved. Both fetched and cached values are validated; invalid fetched values are not written, and service-level error handling returns 503 `PROVENANCE_UNAVAILABLE`.
3. MEDIUM distinct `resolved_gene_count`: resolved for the provenance field and payload preservation. The new cache-hit/worker `gene_count` asymmetry above is a separate regression.
4. LOW `base::get`: resolved at [test-integration-clustering-category-submit.R:162](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/tests/testthat/test-integration-clustering-category-submit.R:162).

The split retained all 11 original tests exactly once: 5 functional tests remain in the original file and 6 phenotype tests moved to the sibling. Both are under 600 lines and coherent. Entity-level resolution, live allowlist validation, dbplyr `%in%`, selector-aware category dedup, provenance/effective-fingerprint paths, and no-public-ready behavior remain correct.

`git diff --check` passed. Targeted R tests and `make code-quality-audit` could not run because this read-only sandbox cannot create temporary files.

**VERDICT: NO-SHIP — 1 HIGH, 1 MEDIUM**
tokens used
115,827
Findings:

- HIGH — [job-functional-submission-service.R:60-71](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:60): JSON `{"genes":null,"category_filter":["Definitive"]}` bypasses mutual exclusion. `genes_in` is `NULL`, so `genes_supplied` is false despite the `genes` key being present; the category request is accepted. Fix: determine selector presence from `names(req$argsBody)`, not value nullness, and reject an explicitly null `category_filter` rather than treating it as absent.

- MEDIUM — [job-functional-submission-service.R:252](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:252), [async-job-handlers.R:132](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/functions/async-job-handlers.R:132): duplicate explicit genes produce inconsistent result metadata. For `["HGNC:1","HGNC:1"]`, a cache hit reports `meta.gene_count = 1`, while a worker-run result reports `meta.gene_count = 2`; both carry `resolved_gene_count = 1`. Fix: have the worker compute `gene_count` using the same sorted/unique convention (or centralize the count helper), without changing the payload `genes` list.

Prior findings:

1. HIGH mutual exclusion: partially fixed. `genes: []` plus a category now correctly returns 400; `genes: []` alone still defaults; non-empty `genes` remains explicit. However, it is not fully key-presence-correct for JSON `null`, so this remains HIGH.
2. HIGH source-version cache: resolved. Both fetched and cached values are validated; invalid fetched values are not written, and service-level error handling returns 503 `PROVENANCE_UNAVAILABLE`.
3. MEDIUM distinct `resolved_gene_count`: resolved for the provenance field and payload preservation. The new cache-hit/worker `gene_count` asymmetry above is a separate regression.
4. LOW `base::get`: resolved at [test-integration-clustering-category-submit.R:162](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/tests/testthat/test-integration-clustering-category-submit.R:162).

The split retained all 11 original tests exactly once: 5 functional tests remain in the original file and 6 phenotype tests moved to the sibling. Both are under 600 lines and coherent. Entity-level resolution, live allowlist validation, dbplyr `%in%`, selector-aware category dedup, provenance/effective-fingerprint paths, and no-public-ready behavior remain correct.

`git diff --check` passed. Targeted R tests and `make code-quality-audit` could not run because this read-only sandbox cannot create temporary files.

**VERDICT: NO-SHIP — 1 HIGH, 1 MEDIUM**
